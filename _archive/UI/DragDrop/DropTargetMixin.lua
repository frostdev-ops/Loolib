--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    DropTargetMixin - Make frames accept drag-and-drop

    Provides visual feedback, validation, and event handling for frames
    that receive dragged items.

    Dependencies (must be loaded before this file):
    - Core/Loolib.lua (Loolib namespace)
    - UI/DragDrop/DragContext.lua (DragContext module)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Local references to globals
local type = type
local error = error
local next = next
local select = select

--[[--------------------------------------------------------------------
    LoolibDropTargetMixin

    Apply this mixin to frames that should accept dropped items.
    Provides hover highlighting, validation, and drop event handling.

    Usage:
        local frame = CreateFrame("Frame", nil, UIParent)
        LoolibMixin(frame, LoolibDropTargetMixin)
        frame:InitDropTarget()
        frame:SetDropEnabled(true)
        frame:SetDropValidator(function(data) return data.type == "item" end)
        function frame:OnDropReceived(data, source)
            print("Received drop:", data.name)
        end
----------------------------------------------------------------------]]

---@class LoolibDropTargetMixin : Frame
---@field dropEnabled boolean Whether this target can receive drops
---@field dropValidator function? Custom validation function
---@field dropPriority number Priority for overlapping targets (higher checked first)
---@field highlightOnHover boolean Show visual feedback on hover
---@field highlightColor table Valid drop highlight color {r, g, b, a}
---@field invalidColor table Invalid drop highlight color {r, g, b, a}
---@field acceptedTypes table<string, boolean> Optional type-based filtering
---@field _isHovered boolean Internal hover state
---@field _highlightTexture Texture? Internal highlight texture
---@field _dropEnabled boolean Guard flag for HookScript idempotency
local LoolibDropTargetMixin = {}

--[[--------------------------------------------------------------------
    INITIALIZATION
----------------------------------------------------------------------]]

--- Initialize the drop target.
--- Idempotent: safe to call multiple times.
---@return nil
function LoolibDropTargetMixin:InitDropTarget()
    -- Public configuration
    self.dropEnabled = false
    self.dropValidator = nil
    self.dropPriority = 0
    self.highlightOnHover = true

    -- Highlight colors
    self.highlightColor = {r = 0.3, g = 0.8, b = 0.3, a = 0.3}  -- Green tint
    self.invalidColor = {r = 0.8, g = 0.3, b = 0.3, a = 0.3}    -- Red tint

    -- Type filtering (empty = accept all)
    self.acceptedTypes = {}

    -- Internal state
    self._isHovered = false
    self._highlightTexture = nil
    self._dropEnabled = false
end

--[[--------------------------------------------------------------------
    CONFIGURATION (Fluent API - all return self)
----------------------------------------------------------------------]]

--- Enable or disable drop target functionality
--- When enabled, registers with DragContext to receive drag events.
--- When disabled, unregisters from DragContext.
--- DD-03: Uses DragContext:RegisterDropTarget instead of SetScript("OnReceiveDrag")
--- to avoid overwriting existing handlers.
---@param enabled boolean True to enable drops
---@return LoolibDropTargetMixin self
function LoolibDropTargetMixin:SetDropEnabled(enabled)
    if type(enabled) ~= "boolean" then
        error("LoolibDropTargetMixin: SetDropEnabled: 'enabled' must be a boolean", 2)
    end

    self.dropEnabled = enabled

    local DragContext = Loolib:GetModule("DragDrop.DragContext")
    if not DragContext then
        error("LoolibDropTargetMixin: SetDropEnabled: DragContext module is required", 2)
    end

    if enabled then
        -- Register with DragContext
        -- Validator function checks if this target accepts the dragged data
        DragContext:RegisterDropTarget(self, function(dragData)
            return self:_ValidateDrop(dragData)
        end, self.dropPriority)
    else
        -- Unregister from DragContext
        DragContext:UnregisterDropTarget(self)

        -- Clear any hover state
        if self._isHovered then
            self._isHovered = false
            self:_HideHighlight()
        end
    end

    return self
end

--- Set custom validator function
--- The validator receives dragData and returns true/false to accept/reject.
--- Called before OnDragEnter to determine if drop is valid.
---@param validator function? Function(dragData) -> boolean
---@return LoolibDropTargetMixin self
function LoolibDropTargetMixin:SetDropValidator(validator)
    if validator ~= nil and type(validator) ~= "function" then
        error("LoolibDropTargetMixin: SetDropValidator: 'validator' must be a function or nil", 2)
    end

    self.dropValidator = validator
    return self
end

--- Set drop priority for overlapping targets
--- Higher priority targets are checked first when multiple targets overlap.
--- Useful for nested frames where child should receive drop instead of parent.
---@param priority number Priority value (default 0)
---@return LoolibDropTargetMixin self
function LoolibDropTargetMixin:SetDropPriority(priority)
    if type(priority) ~= "number" then
        error("LoolibDropTargetMixin: SetDropPriority: 'priority' must be a number", 2)
    end

    self.dropPriority = priority

    -- Re-register with new priority if currently enabled
    if self.dropEnabled then
        local DragContext = Loolib:GetModule("DragDrop.DragContext")
        if DragContext then
            DragContext:RegisterDropTarget(self, function(dragData)
                return self:_ValidateDrop(dragData)
            end, priority)
        end
    end

    return self
end

--- Enable/disable hover highlight effect
--- When enabled, shows colored overlay when dragged item hovers.
---@param enabled boolean True to show highlights
---@return LoolibDropTargetMixin self
function LoolibDropTargetMixin:SetHighlightOnHover(enabled)
    self.highlightOnHover = enabled

    -- If disabling and currently highlighted, hide it
    if not enabled and self._isHovered then
        self:_HideHighlight()
    end

    return self
end

--- Set highlight colors for valid and invalid drops
---@param validColor table? {r, g, b, a} for valid drops (green by default)
---@param invalidColor table? {r, g, b, a} for invalid drops (red by default)
---@return LoolibDropTargetMixin self
function LoolibDropTargetMixin:SetHighlightColors(validColor, invalidColor)
    if validColor then
        self.highlightColor = validColor
    end
    if invalidColor then
        self.invalidColor = invalidColor
    end
    return self
end

--- Set accepted drag data types (for type-based filtering)
--- If types are specified, only dragData with matching type will be accepted.
--- Leave empty to accept all types.
---@param ... string Type names to accept
---@return LoolibDropTargetMixin self
function LoolibDropTargetMixin:SetAcceptedTypes(...)
    self.acceptedTypes = {}
    for i = 1, select("#", ...) do
        local typeName = select(i, ...)
        if type(typeName) ~= "string" then
            error("LoolibDropTargetMixin: SetAcceptedTypes: all arguments must be strings", 2)
        end
        self.acceptedTypes[typeName] = true
    end
    return self
end

--[[--------------------------------------------------------------------
    INTERNAL VALIDATION
----------------------------------------------------------------------]]

--- Internal validation logic -- INTERNAL
--- Checks enabled state, type filtering, and custom validator.
---@param dragData any The data being dragged
---@return boolean valid True if drop is valid
function LoolibDropTargetMixin:_ValidateDrop(dragData)
    -- Check if drop is enabled
    if not self.dropEnabled then
        return false
    end

    -- Type-based filtering (if types are specified)
    if next(self.acceptedTypes) then
        local dataType = type(dragData) == "table" and dragData.type or nil
        if dataType and not self.acceptedTypes[dataType] then
            return false
        end
    end

    -- Custom validator (if provided)
    if self.dropValidator then
        return self.dropValidator(dragData)
    end

    -- Default: accept all drops
    return true
end

--[[--------------------------------------------------------------------
    VISUAL FEEDBACK
----------------------------------------------------------------------]]

--- Create or get the highlight texture -- INTERNAL
--- Lazy creation on first use.
---@return Texture
function LoolibDropTargetMixin:_CreateHighlight()
    if self._highlightTexture then
        return self._highlightTexture
    end

    local highlight = self:CreateTexture(nil, "OVERLAY")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 1)
    highlight:SetBlendMode("ADD")
    highlight:Hide()

    self._highlightTexture = highlight
    return highlight
end

--- Show highlight overlay -- INTERNAL
---@param isValid boolean True for valid drop color, false for invalid
function LoolibDropTargetMixin:_ShowHighlight(isValid)
    if not self.highlightOnHover then
        return
    end

    local highlight = self:_CreateHighlight()
    local color = isValid and self.highlightColor or self.invalidColor
    highlight:SetColorTexture(color.r, color.g, color.b, color.a)
    highlight:Show()
end

--- Hide highlight overlay -- INTERNAL
function LoolibDropTargetMixin:_HideHighlight()
    if self._highlightTexture then
        self._highlightTexture:Hide()
    end
end

--[[--------------------------------------------------------------------
    EVENT HANDLERS (called by DragContext)

    These methods are called by DragContext during drag operations.
    Subclasses can override the On* methods for custom behavior.
----------------------------------------------------------------------]]

--- Called when a dragged item enters this target
--- Shows highlight and calls custom OnDropTargetEnter if defined.
---@param dragData any The data being dragged
---@return nil
function LoolibDropTargetMixin:OnDragEnter(dragData)
    self._isHovered = true

    -- Validate drop and show appropriate highlight
    local isValid = self:_ValidateDrop(dragData)
    self:_ShowHighlight(isValid)

    -- Call custom handler if defined
    if self.OnDropTargetEnter then
        self:OnDropTargetEnter(dragData, isValid)
    end
end

--- Called when a dragged item leaves this target
--- Hides highlight and calls custom OnDropTargetLeave if defined.
---@param dragData any The data being dragged
---@return nil
function LoolibDropTargetMixin:OnDragLeave(dragData)
    self._isHovered = false
    self:_HideHighlight()

    -- Call custom handler if defined
    if self.OnDropTargetLeave then
        self:OnDropTargetLeave(dragData)
    end
end

--- Called when an item is dropped on this target
--- Validates drop, hides highlight, and calls custom OnDropReceived if defined.
---@param dragData any The dropped data
---@param sourceFrame Frame The frame that was dragged
---@return boolean accepted True if drop was accepted
function LoolibDropTargetMixin:OnDrop(dragData, sourceFrame)
    self:_HideHighlight()
    self._isHovered = false

    -- Final validation before accepting drop
    if not self:_ValidateDrop(dragData) then
        return false
    end

    -- Call custom handler if defined
    if self.OnDropReceived then
        self:OnDropReceived(dragData, sourceFrame)
        return true
    end

    -- Default: accept drop
    return true
end

--[[--------------------------------------------------------------------
    QUERY METHODS
----------------------------------------------------------------------]]

--- Check if this frame is a drop target
---@return boolean
function LoolibDropTargetMixin:IsDropTarget()
    return self.dropEnabled
end

--- Check if a dragged item is currently hovering
---@return boolean
function LoolibDropTargetMixin:IsHoveredByDrag()
    return self._isHovered
end

--- Check if this target can accept specific drag data
---@param dragData any The data to test
---@return boolean
function LoolibDropTargetMixin:CanAcceptDrop(dragData)
    return self:_ValidateDrop(dragData)
end

--[[--------------------------------------------------------------------
    CLEANUP
----------------------------------------------------------------------]]

--- Disable drop target and unregister from DragContext.
--- Call this when the frame is being destroyed or permanently hidden.
---@return nil
function LoolibDropTargetMixin:DestroyDropTarget()
    if self.dropEnabled then
        self:SetDropEnabled(false)
    end
    self._isHovered = false
    self._highlightTexture = nil
end

--[[--------------------------------------------------------------------
    OVERRIDE POINTS (implement in consuming code)

    These methods are called during drag operations if defined.
    Implement them in your frame to add custom behavior.
----------------------------------------------------------------------]]

-- Called when a dragged item enters this target
-- @param dragData any - The data being dragged
-- @param isValid boolean - True if drop would be accepted
-- function LoolibDropTargetMixin:OnDropTargetEnter(dragData, isValid) end

-- Called when a dragged item leaves this target
-- @param dragData any - The data that was dragged
-- function LoolibDropTargetMixin:OnDropTargetLeave(dragData) end

-- Called when an item is dropped on this target
-- @param dragData any - The dropped data
-- @param sourceFrame Frame - The frame that was dragged
-- function LoolibDropTargetMixin:OnDropReceived(dragData, sourceFrame) end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib:RegisterModule("DragDrop.DropTargetMixin", LoolibDropTargetMixin)
