--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    DragContext - Global drag-and-drop state management singleton

    Manages drag-and-drop operations across the entire UI. Tracks current
    drag state, registered drop targets, and coordinates between draggable
    frames and drop zones.

    Design constraint: Only one drag operation may be active at a time.
    Attempting to start a second drag while one is in progress will cancel
    the first. This is enforced by assertion in StartDrag.

    Usage:
        -- Register a drop target
        LoolibDragContext:RegisterDropTarget(frame, function(dragData)
            return dragData.type == "item"
        end, 10) -- priority 10

        -- Start dragging
        LoolibDragContext:StartDrag(sourceFrame, {type = "item", id = 123}, ghostFrame)

        -- Listen for drag events
        LoolibDragContext:RegisterCallback("OnDragEnd", function(owner, target, dragData, success)
            if success then
                print("Dropped on", target:GetName())
            end
        end, self)

    Dependencies:
    - Core/Loolib.lua (Loolib namespace and module registration)
    - Core/Mixin.lua (LoolibCreateFromMixins)
    - Events/CallbackRegistry.lua (LoolibCallbackRegistryMixin)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local LoolibCreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for DragContext")
local LoolibCallbackRegistryMixin = assert(Loolib.CallbackRegistryMixin, "Loolib.CallbackRegistryMixin is required for DragContext")

-- Local references to globals
local type = type
local error = error
local pairs = pairs
local pcall = pcall
local ipairs = ipairs
local table_insert = table.insert
local table_sort = table.sort
local math_sqrt = math.sqrt

---@diagnostic disable: undefined-field, undefined-doc-name

---@class LoolibDropTargetInfo
---@field validator function
---@field priority number

---@class LoolibDragContextClass : LoolibCallbackRegistryMixin
---@field isDragging boolean
---@field dragData any
---@field sourceFrame Frame?
---@field ghostFrame Frame?
---@field dropTargets table<Frame, LoolibDropTargetInfo>
---@field hoveredTarget Frame?
---@field startX number
---@field startY number
---@field updateFrame Frame?
---@field callbacks LoolibCallbackRegistryMixin
---@field _initialized boolean
local LoolibDragContext = {}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the singleton state
--- Idempotent: safe to call multiple times.
---@return nil
function LoolibDragContext:Initialize()
    if self._initialized then
        return
    end

    self.isDragging = false
    self.dragData = nil
    self.sourceFrame = nil
    self.ghostFrame = nil
    self.dropTargets = {}
    self.hoveredTarget = nil
    self.startX = 0
    self.startY = 0

    -- Set up callback registry for drag events
    self.callbacks = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)
    self.callbacks:OnLoad()
    self.callbacks:GenerateCallbackEvents({
        "OnDragStart",     -- (sourceFrame, dragData)
        "OnDragUpdate",    -- (cursorX, cursorY, dragData)
        "OnDragEnd",       -- (targetFrame, dragData, success)
        "OnDragCancel",    -- (sourceFrame, dragData)
        "OnDropTargetEnter", -- (targetFrame, dragData)
        "OnDropTargetLeave", -- (targetFrame, dragData)
    })

    self._initialized = true
end

--[[--------------------------------------------------------------------
    DROP TARGET REGISTRATION
----------------------------------------------------------------------]]

--- Register a frame as a valid drop target
---@param frame Frame The frame that can receive drops
---@param validator function? Optional function(dragData) -> boolean to validate drops
---@param priority number? Higher priority targets are checked first (default 0)
---@return nil
function LoolibDragContext:RegisterDropTarget(frame, validator, priority)
    if type(frame) ~= "table" or not frame.GetObjectType then
        error("LoolibDragContext: RegisterDropTarget: 'frame' must be a Frame object", 2)
    end
    if validator ~= nil and type(validator) ~= "function" then
        error("LoolibDragContext: RegisterDropTarget: 'validator' must be a function or nil", 2)
    end
    if priority ~= nil and type(priority) ~= "number" then
        error("LoolibDragContext: RegisterDropTarget: 'priority' must be a number or nil", 2)
    end

    self.dropTargets[frame] = {
        validator = validator or function() return true end,
        priority = priority or 0,
    }
end

--- Unregister a drop target
---@param frame Frame The frame to unregister
---@return nil
function LoolibDragContext:UnregisterDropTarget(frame)
    self.dropTargets[frame] = nil

    -- Clear hovered target if it was this frame
    if self.hoveredTarget == frame then
        if self.isDragging then
            self.callbacks:TriggerEvent("OnDropTargetLeave", frame, self.dragData)
            if frame.OnDragLeave then
                frame:OnDragLeave(self.dragData)
            end
        end
        self.hoveredTarget = nil
    end
end

--- Check if a frame is a registered drop target
---@param frame Frame
---@return boolean
function LoolibDragContext:IsDropTarget(frame)
    return self.dropTargets[frame] ~= nil
end

--[[--------------------------------------------------------------------
    DRAG OPERATIONS
----------------------------------------------------------------------]]

--- Start a drag operation
--- Only one drag may be active at a time (DD-04). If a drag is already in
--- progress, it is cancelled before starting the new one.
---@param sourceFrame Frame The frame being dragged
---@param dragData any Data to transfer on drop
---@param ghostFrame Frame? Optional ghost/preview frame to show at cursor
---@return nil
function LoolibDragContext:StartDrag(sourceFrame, dragData, ghostFrame)
    if type(sourceFrame) ~= "table" or not sourceFrame.GetObjectType then
        error("LoolibDragContext: StartDrag: 'sourceFrame' must be a Frame object", 2)
    end

    -- DD-04: Single-drag constraint. Cancel any existing drag first.
    if self.isDragging then
        self:CancelDrag()
    end

    self.isDragging = true
    self.sourceFrame = sourceFrame
    self.dragData = dragData
    self.ghostFrame = ghostFrame

    -- Record start position
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self.startX = x / scale
    self.startY = y / scale

    -- Show and position ghost frame if provided
    if ghostFrame then
        ghostFrame:Show()
        ghostFrame:SetFrameStrata("TOOLTIP")
        ghostFrame:SetFrameLevel(9000)
        ghostFrame:ClearAllPoints()
        ghostFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.startX, self.startY)
    end

    -- Start update loop to track cursor and detect targets
    self:_StartUpdateLoop()

    -- Fire drag start event
    self.callbacks:TriggerEvent("OnDragStart", sourceFrame, dragData)
end

--- Update drag position and detect hovered targets -- INTERNAL
--- Called every frame during drag operation.
---@param x number Cursor X position (scaled)
---@param y number Cursor Y position (scaled)
function LoolibDragContext:_UpdateDrag(x, y)
    if not self.isDragging then return end

    -- Update ghost frame position
    if self.ghostFrame then
        self.ghostFrame:ClearAllPoints()
        self.ghostFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    end

    -- Find which drop target (if any) is hovered
    local newTarget = self:_GetHoveredTarget(x, y)

    -- Handle target enter/leave transitions
    if newTarget ~= self.hoveredTarget then
        -- Leave previous target
        if self.hoveredTarget then
            self.callbacks:TriggerEvent("OnDropTargetLeave", self.hoveredTarget, self.dragData)
            -- Call frame's OnDragLeave if it exists
            if self.hoveredTarget.OnDragLeave then
                self.hoveredTarget:OnDragLeave(self.dragData)
            end
        end

        -- Update current target
        self.hoveredTarget = newTarget

        -- Enter new target
        if newTarget then
            self.callbacks:TriggerEvent("OnDropTargetEnter", newTarget, self.dragData)
            -- Call frame's OnDragEnter if it exists
            if newTarget.OnDragEnter then
                newTarget:OnDragEnter(self.dragData)
            end
        end
    end

    -- Fire update event
    self.callbacks:TriggerEvent("OnDragUpdate", x, y, self.dragData)
end

--- End drag operation (drop or release)
--- DD-07: Cleanup is wrapped in pcall to guarantee ghost hide and state reset
--- even if a callback errors.
---@param cancelled boolean? If true, treated as cancel not drop
---@return boolean success Whether drop was successful
function LoolibDragContext:EndDrag(cancelled)
    if not self.isDragging then return false end

    local success = false
    local target = self.hoveredTarget

    -- DD-07: pcall the callback/event phase so cleanup always runs
    local ok, err = pcall(function()
        if cancelled then
            -- Fire cancel event
            self.callbacks:TriggerEvent("OnDragCancel", self.sourceFrame, self.dragData)
        else
            -- Attempt drop on hovered target
            if target then
                local targetInfo = self.dropTargets[target]
                if targetInfo and targetInfo.validator(self.dragData) then
                    -- Call frame's OnDrop handler if it exists
                    if target.OnDrop then
                        target:OnDrop(self.dragData, self.sourceFrame)
                    end
                    success = true
                end
            end

            -- Fire end event
            self.callbacks:TriggerEvent("OnDragEnd", target, self.dragData, success)
        end
    end)

    -- Guaranteed cleanup regardless of callback errors
    self:_StopUpdateLoop()

    -- Hide ghost frame
    if self.ghostFrame then
        self.ghostFrame:Hide()
    end

    -- Reset cursor if WoW API available
    if ResetCursor then
        ResetCursor()
    end

    -- Reset state
    self.isDragging = false
    self.sourceFrame = nil
    self.dragData = nil
    self.ghostFrame = nil
    self.hoveredTarget = nil

    -- Re-raise callback error after cleanup
    if not ok then
        error("LoolibDragContext: EndDrag: callback error: " .. tostring(err), 2)
    end

    return success
end

--- Cancel current drag operation
---@return nil
function LoolibDragContext:CancelDrag()
    self:EndDrag(true)
end

--[[--------------------------------------------------------------------
    TARGET DETECTION
----------------------------------------------------------------------]]

--- Find the drop target under cursor position -- INTERNAL
--- Sorts by priority (higher first) and returns the first valid target.
---@param x number Cursor X position
---@param y number Cursor Y position
---@return Frame? target The highest priority valid target under cursor
function LoolibDragContext:_GetHoveredTarget(x, y) -- luacheck: ignore 212
    -- Collect all visible targets that are under the cursor
    local sortedTargets = {}
    for frame, info in pairs(self.dropTargets) do
        if frame:IsVisible() and frame:IsMouseOver() then
            table_insert(sortedTargets, {frame = frame, info = info})
        end
    end

    -- Sort by priority (higher first)
    table_sort(sortedTargets, function(a, b)
        return a.info.priority > b.info.priority
    end)

    -- Return first target that validates the drag data
    for _, entry in ipairs(sortedTargets) do
        if entry.info.validator(self.dragData) then
            return entry.frame
        end
    end

    return nil
end

--[[--------------------------------------------------------------------
    UPDATE LOOP
----------------------------------------------------------------------]]

--- Start the OnUpdate loop for tracking cursor during drag -- INTERNAL
function LoolibDragContext:_StartUpdateLoop()
    -- Create update frame if needed
    if not self.updateFrame then
        self.updateFrame = CreateFrame("Frame")
    end

    -- Set OnUpdate script to track cursor and check for cancel
    self.updateFrame:SetScript("OnUpdate", function()
        if self.isDragging then
            -- Get cursor position (scaled)
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            self:_UpdateDrag(x / scale, y / scale)

            -- Right-click to cancel (standard UX pattern)
            if IsMouseButtonDown("RightButton") then
                self:CancelDrag()
            end
        end
    end)
end

--- Stop the OnUpdate loop -- INTERNAL
function LoolibDragContext:_StopUpdateLoop()
    if self.updateFrame then
        self.updateFrame:SetScript("OnUpdate", nil)
    end
end

--[[--------------------------------------------------------------------
    CALLBACK REGISTRATION (pass-through to internal registry)
----------------------------------------------------------------------]]

--- Register a callback for drag events
---@param event string Event name (OnDragStart, OnDragEnd, etc.)
---@param callback function Callback function
---@param owner any Owner for unregistration
---@return any owner Owner (for later unregistration)
function LoolibDragContext:RegisterCallback(event, callback, owner)
    if type(event) ~= "string" then
        error("LoolibDragContext: RegisterCallback: 'event' must be a string", 2)
    end
    if type(callback) ~= "function" then
        error("LoolibDragContext: RegisterCallback: 'callback' must be a function", 2)
    end
    return self.callbacks:RegisterCallback(event, callback, owner)
end

--- Unregister a callback
---@param event string Event name
---@param owner any Owner that registered the callback
---@return boolean removed True if a callback was removed
function LoolibDragContext:UnregisterCallback(event, owner)
    return self.callbacks:UnregisterCallback(event, owner)
end

--- Unregister all callbacks for an owner
---@param owner any Owner to unregister
---@return nil
function LoolibDragContext:UnregisterAllCallbacks(owner)
    return self.callbacks:UnregisterAllCallbacks(owner)
end

--[[--------------------------------------------------------------------
    QUERY METHODS
----------------------------------------------------------------------]]

--- Check if a drag operation is currently in progress
---@return boolean
function LoolibDragContext:IsDragging()
    return self.isDragging
end

--- Get the data being dragged
---@return any dragData The drag data, or nil if not dragging
function LoolibDragContext:GetDragData()
    return self.dragData
end

--- Get the source frame being dragged
---@return Frame? sourceFrame The source frame, or nil if not dragging
function LoolibDragContext:GetSourceFrame()
    return self.sourceFrame
end

--- Get the currently hovered drop target
---@return Frame? hoveredTarget The hovered target, or nil if none
function LoolibDragContext:GetHoveredDropTarget()
    return self.hoveredTarget
end

--- Get the starting cursor position when drag began
---@return number startX
---@return number startY
function LoolibDragContext:GetStartPosition()
    return self.startX, self.startY
end

--- Get the distance the cursor has moved since drag started
---@return number distance Distance in pixels (or 0 if not dragging)
function LoolibDragContext:GetDragDistance()
    if not self.isDragging then return 0 end

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local currentX = x / scale
    local currentY = y / scale

    local dx = currentX - self.startX
    local dy = currentY - self.startY

    return math_sqrt(dx * dx + dy * dy)
end

--[[--------------------------------------------------------------------
    Module Initialization
----------------------------------------------------------------------]]

-- Initialize on load
LoolibDragContext:Initialize()

-- Register with Loolib
Loolib:RegisterModule("DragDrop.DragContext", LoolibDragContext)
