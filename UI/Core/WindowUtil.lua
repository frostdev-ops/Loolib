--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    WindowUtil - Window position and scale management

    LibWindow-1.1 equivalent functionality for frame persistence

    Features:
    - Position persistence (anchor point, offset, scale)
    - Draggable frames with auto-save
    - Mouse wheel scaling with Ctrl modifier
    - Alt-to-interact mode (click-through frames)
    - Resolution change handling (prevents frames going off-screen)
    - Screen clamping
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

LoolibWindowUtil = {}

-- Default configuration names
local DEFAULT_KEYS = {
    point = "point",
    relativePoint = "relativePoint",
    relativeTo = "relativeTo",
    xOffset = "xOffset",
    yOffset = "yOffset",
    scale = "scale",
}

-- Track registered frames for cleanup
local registeredFrames = {}

--[[--------------------------------------------------------------------
    Position Saving and Restoration
----------------------------------------------------------------------]]

--- Register a frame for position/scale persistence
-- @param frame Frame - The frame to manage
-- @param storage table - Table where position data is saved (e.g., db.profile.windows)
-- @param names table|nil - Optional custom names for saved keys
--
-- Stores in storage:
-- - point: Anchor point (e.g., "CENTER", "TOPLEFT")
-- - relativePoint: Relative anchor point
-- - relativeTo: Usually nil (means UIParent/screen)
-- - xOffset: Horizontal offset in pixels
-- - yOffset: Vertical offset in pixels
-- - scale: Frame scale (1.0 = 100%)
function LoolibWindowUtil.RegisterConfig(frame, storage, names)
    if not frame or type(frame) ~= "table" or not frame.GetObjectType then
        error("LoolibWindowUtil.RegisterConfig: frame must be a valid frame", 2)
    end

    if not storage or type(storage) ~= "table" then
        error("LoolibWindowUtil.RegisterConfig: storage must be a table", 2)
    end

    -- Store configuration on frame
    frame.windowStorage = storage
    frame.windowKeys = names or DEFAULT_KEYS

    -- Track this frame
    registeredFrames[frame] = true

    -- Restore position if saved
    if storage[frame.windowKeys.point] then
        LoolibWindowUtil.RestorePosition(frame)
    end
end

--- Save current frame position/scale to storage
-- @param frame Frame - The frame to save
function LoolibWindowUtil.SavePosition(frame)
    if not frame or not frame.windowStorage then
        return
    end

    local storage = frame.windowStorage
    local keys = frame.windowKeys or DEFAULT_KEYS

    -- Get current scale
    storage[keys.scale] = frame:GetScale()

    -- Get anchor point
    local numPoints = frame:GetNumPoints()
    if numPoints == 0 then
        return
    end

    -- Use first anchor point
    local point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint(1)

    -- Convert to screen-relative if attached to another frame
    if relativeTo and relativeTo ~= UIParent then
        -- Get absolute position
        local left = frame:GetLeft()
        local bottom = frame:GetBottom()
        local right = frame:GetRight()
        local top = frame:GetTop()

        if left and bottom then
            -- Convert to screen coordinates
            local screenWidth = UIParent:GetWidth()
            local screenHeight = UIParent:GetHeight()
            local scale = frame:GetScale()

            -- Calculate center-based position
            local centerX = (left + right) / 2 / scale
            local centerY = (bottom + top) / 2 / scale

            -- Convert to offset from screen center
            xOffset = centerX - (screenWidth / 2)
            yOffset = centerY - (screenHeight / 2)
            point = "CENTER"
            relativePoint = "CENTER"
            relativeTo = nil
        end
    end

    storage[keys.point] = point
    storage[keys.relativePoint] = relativePoint or point
    storage[keys.relativeTo] = nil  -- Always save as screen-relative
    storage[keys.xOffset] = xOffset
    storage[keys.yOffset] = yOffset
end

--- Restore frame position/scale from storage
-- @param frame Frame - The frame to restore
function LoolibWindowUtil.RestorePosition(frame)
    if not frame or not frame.windowStorage then
        return
    end

    local storage = frame.windowStorage
    local keys = frame.windowKeys or DEFAULT_KEYS

    -- Restore scale
    local scale = storage[keys.scale]
    if scale and scale > 0 then
        frame:SetScale(scale)
    end

    -- Restore position
    local point = storage[keys.point]
    if not point then
        return
    end

    local relativePoint = storage[keys.relativePoint] or point
    local xOffset = storage[keys.xOffset] or 0
    local yOffset = storage[keys.yOffset] or 0

    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, xOffset, yOffset)

    -- Clamp to screen
    LoolibWindowUtil.ClampToScreen(frame)
end

--- Clamp frame to screen bounds (prevent off-screen positioning)
-- @param frame Frame - The frame to clamp
function LoolibWindowUtil.ClampToScreen(frame)
    if not frame then
        return
    end

    -- Get frame bounds
    local left = frame:GetLeft()
    local right = frame:GetRight()
    local top = frame:GetTop()
    local bottom = frame:GetBottom()

    if not left or not right or not top or not bottom then
        -- Frame has no valid position, center it
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        if frame.windowStorage then
            LoolibWindowUtil.SavePosition(frame)
        end
        return
    end

    -- Get screen bounds
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local scale = frame:GetScale()

    -- Check if frame is off-screen
    local offScreen = false

    if right / scale < 0 or left / scale > screenWidth then
        offScreen = true
    end

    if top / scale < 0 or bottom / scale > screenHeight then
        offScreen = true
    end

    -- If off-screen, re-center
    if offScreen then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        if frame.windowStorage then
            LoolibWindowUtil.SavePosition(frame)
        end
    end
end

--[[--------------------------------------------------------------------
    Scale Management
----------------------------------------------------------------------]]

--- Set frame scale and save to storage
-- @param frame Frame - The frame to scale
-- @param scale number - Scale value (0.5 - 2.0 typical range)
function LoolibWindowUtil.SetScale(frame, scale)
    if not frame then
        return
    end

    -- Clamp scale to reasonable values
    scale = math.max(0.5, math.min(2.0, scale))

    -- Store center position before scaling
    local centerX, centerY = frame:GetCenter()

    -- Apply scale
    frame:SetScale(scale)

    -- Restore center position (compensates for scale changing anchor offset)
    if centerX and centerY then
        frame:ClearAllPoints()
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        local xOffset = centerX - (screenWidth / 2)
        local yOffset = centerY - (screenHeight / 2)
        frame:SetPoint("CENTER", UIParent, "CENTER", xOffset, yOffset)
    end

    -- Save new position and scale
    if frame.windowStorage then
        LoolibWindowUtil.SavePosition(frame)
    end

    -- Clamp to screen after scaling
    LoolibWindowUtil.ClampToScreen(frame)
end

--[[--------------------------------------------------------------------
    Draggable Frames
----------------------------------------------------------------------]]

--- Make frame draggable with auto-save
-- @param frame Frame - The frame to make draggable
-- @param dragHandle Frame|nil - Optional drag handle (defaults to frame itself)
function LoolibWindowUtil.MakeDraggable(frame, dragHandle)
    if not frame then
        return
    end

    dragHandle = dragHandle or frame

    -- Set up dragging
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")

    -- Store original handlers if they exist
    local originalDragStart = dragHandle:GetScript("OnDragStart")
    local originalDragStop = dragHandle:GetScript("OnDragStop")

    dragHandle:SetScript("OnDragStart", function(self)
        frame:StartMoving()
        if originalDragStart then
            originalDragStart(self)
        end
    end)

    dragHandle:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        LoolibWindowUtil.SavePosition(frame)
        if originalDragStop then
            originalDragStop(self)
        end
    end)
end

--[[--------------------------------------------------------------------
    Mouse Wheel Scaling
----------------------------------------------------------------------]]

--- Enable Ctrl+MouseWheel scaling with auto-save
-- @param frame Frame - The frame to enable scaling on
function LoolibWindowUtil.EnableMouseWheelScaling(frame)
    if not frame then
        return
    end

    frame:EnableMouseWheel(true)

    -- Store original handler if it exists
    local originalMouseWheel = frame:GetScript("OnMouseWheel")

    frame:SetScript("OnMouseWheel", function(self, delta)
        if IsControlKeyDown() then
            local currentScale = self:GetScale()
            local newScale = currentScale + (delta * 0.05)
            LoolibWindowUtil.SetScale(self, newScale)
        elseif originalMouseWheel then
            originalMouseWheel(self, delta)
        end
    end)
end

--[[--------------------------------------------------------------------
    Alt-to-Interact Mode
----------------------------------------------------------------------]]

--- Make frame only respond to mouse when Alt key is held
-- Useful for click-through overlay frames
-- @param frame Frame - The frame to modify
function LoolibWindowUtil.EnableMouseOnAlt(frame)
    if not frame then
        return
    end

    -- Store whether frame is currently mouse-enabled
    frame.windowAltMode = true
    frame.windowOriginalMouseEnabled = frame:IsMouseEnabled()

    -- Initially disable mouse
    frame:EnableMouse(false)

    -- Set up OnUpdate handler to check Alt key
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not self.windowAltMode then
            return
        end

        local altPressed = IsAltKeyDown()
        local shouldEnableMouse = altPressed or not self.windowOriginalMouseEnabled

        if shouldEnableMouse and not self:IsMouseEnabled() then
            self:EnableMouse(true)
        elseif not shouldEnableMouse and self:IsMouseEnabled() then
            self:EnableMouse(false)
        end
    end)
end

--- Disable Alt-to-interact mode
-- @param frame Frame - The frame to restore
function LoolibWindowUtil.DisableMouseOnAlt(frame)
    if not frame or not frame.windowAltMode then
        return
    end

    frame.windowAltMode = false
    frame:EnableMouse(frame.windowOriginalMouseEnabled or false)

    -- Remove OnUpdate handler if it's ours
    frame:SetScript("OnUpdate", nil)
end

--[[--------------------------------------------------------------------
    Utility Functions
----------------------------------------------------------------------]]

--- Check if a frame is registered
-- @param frame Frame - The frame to check
-- @return boolean
function LoolibWindowUtil.IsRegistered(frame)
    return registeredFrames[frame] ~= nil
end

--- Unregister a frame (stop managing its position)
-- @param frame Frame - The frame to unregister
function LoolibWindowUtil.Unregister(frame)
    if not frame then
        return
    end

    registeredFrames[frame] = nil
    frame.windowStorage = nil
    frame.windowKeys = nil
end

--- Reset frame to default position
-- @param frame Frame - The frame to reset
function LoolibWindowUtil.ResetPosition(frame)
    if not frame or not frame.windowStorage then
        return
    end

    local storage = frame.windowStorage
    local keys = frame.windowKeys or DEFAULT_KEYS

    -- Clear saved position
    storage[keys.point] = nil
    storage[keys.relativePoint] = nil
    storage[keys.relativeTo] = nil
    storage[keys.xOffset] = nil
    storage[keys.yOffset] = nil
    storage[keys.scale] = nil

    -- Reset to center
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetScale(1.0)

    -- Save default position
    LoolibWindowUtil.SavePosition(frame)
end

--- Save all registered frame positions
-- Useful for addon shutdown or profile switching
function LoolibWindowUtil.SaveAllPositions()
    for frame in pairs(registeredFrames) do
        if frame:IsShown() then
            LoolibWindowUtil.SavePosition(frame)
        end
    end
end

--- Restore all registered frame positions
-- Useful after resolution change
function LoolibWindowUtil.RestoreAllPositions()
    for frame in pairs(registeredFrames) do
        LoolibWindowUtil.RestorePosition(frame)
    end
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local WindowUtilModule = {
    RegisterConfig = LoolibWindowUtil.RegisterConfig,
    SavePosition = LoolibWindowUtil.SavePosition,
    RestorePosition = LoolibWindowUtil.RestorePosition,
    ClampToScreen = LoolibWindowUtil.ClampToScreen,
    SetScale = LoolibWindowUtil.SetScale,
    MakeDraggable = LoolibWindowUtil.MakeDraggable,
    EnableMouseWheelScaling = LoolibWindowUtil.EnableMouseWheelScaling,
    EnableMouseOnAlt = LoolibWindowUtil.EnableMouseOnAlt,
    DisableMouseOnAlt = LoolibWindowUtil.DisableMouseOnAlt,
    IsRegistered = LoolibWindowUtil.IsRegistered,
    Unregister = LoolibWindowUtil.Unregister,
    ResetPosition = LoolibWindowUtil.ResetPosition,
    SaveAllPositions = LoolibWindowUtil.SaveAllPositions,
    RestoreAllPositions = LoolibWindowUtil.RestoreAllPositions,
}

local UI = Loolib:GetOrCreateModule("UI")
UI.WindowUtil = WindowUtilModule

Loolib:RegisterModule("WindowUtil", WindowUtilModule)
