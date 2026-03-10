--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    DraggableMixin - Make any frame draggable with optional data transfer

    Integrates with:
    - DragContext for coordinated drag operations
    - WindowUtil for position persistence
    - SavedVariables for storing positions

    Usage:
        local frame = CreateFrame("Frame", nil, UIParent)
        Mixin(frame, LoolibDraggableMixin)
        frame:InitDraggable()
        frame:SetDragEnabled(true)
            :SetSavePosition(myDB, "MyFramePosition")
            :SetDragButton("LeftButton")
            :SetClampToScreen(true)

    Patterns from MRT:
    - MarksBar.lua: Basic window drag with position save
    - ExLib.lua: List item drag with original position restore
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

---@class LoolibDraggableMixin : Frame
---@field dragEnabled boolean
---@field dragData any
---@field dragButton string
---@field dragModifier string?
---@field useGhost boolean
---@field ghostTemplate string?
---@field clampToScreen boolean
---@field savePosition boolean
---@field positionKey string?
---@field savedVarsTable table?
local LoolibDraggableMixin = {}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function LoolibDraggableMixin:InitDraggable()
    self.dragEnabled = false
    self.dragData = nil
    self.dragButton = "LeftButton"
    self.dragModifier = nil  -- nil, "shift", "ctrl", "alt"
    self.useGhost = false
    self.ghostTemplate = nil
    self.clampToScreen = true
    self.savePosition = false
    self.positionKey = nil
    self.savedVarsTable = nil

    -- Internal state
    self._isDragging = false
    self._dragStartX = 0
    self._dragStartY = 0
    self._originalPoints = {}
    self._ghostFrame = nil
end

-- ============================================================
-- CONFIGURATION (Fluent API - all return self)
-- ============================================================

---Enable or disable dragging
---@param enabled boolean
---@return LoolibDraggableMixin
function LoolibDraggableMixin:SetDragEnabled(enabled)
    self.dragEnabled = enabled

    if enabled then
        self:EnableMouse(true)
        self:SetMovable(true)
        self:RegisterForDrag(self.dragButton)

        if self.clampToScreen then
            self:SetClampedToScreen(true)
        end

        -- Set up drag scripts
        self:SetScript("OnDragStart", function(frame)
            frame:_OnDragStart()
        end)

        self:SetScript("OnDragStop", function(frame)
            frame:_OnDragStop()
        end)
    else
        self:SetMovable(false)
        self:RegisterForDrag()
        self:SetScript("OnDragStart", nil)
        self:SetScript("OnDragStop", nil)
    end

    return self
end

---Set data to transfer when dropped
---@param data any
---@return LoolibDraggableMixin
function LoolibDraggableMixin:SetDragData(data)
    self.dragData = data
    return self
end

---Set which mouse button initiates drag
---@param button string "LeftButton", "RightButton", etc.
---@return LoolibDraggableMixin
function LoolibDraggableMixin:SetDragButton(button)
    self.dragButton = button
    if self.dragEnabled then
        self:RegisterForDrag(button)
    end
    return self
end

---Require modifier key for drag
---@param modifier string? "shift", "ctrl", "alt", or nil for none
---@return LoolibDraggableMixin
function LoolibDraggableMixin:SetDragModifier(modifier)
    self.dragModifier = modifier
    return self
end

---Use ghost preview during drag
---@param useGhost boolean
---@param template string? Optional template for ghost frame
---@return LoolibDraggableMixin
function LoolibDraggableMixin:SetUseGhost(useGhost, template)
    self.useGhost = useGhost
    self.ghostTemplate = template
    return self
end

---Clamp to screen bounds
---@param clamp boolean
---@return LoolibDraggableMixin
function LoolibDraggableMixin:SetClampToScreen(clamp)
    self.clampToScreen = clamp
    if self:GetObjectType() then  -- Ensure we're a frame
        self:SetClampedToScreen(clamp)
    end
    return self
end

---Enable position persistence to SavedVariables
---@param savedVarsTable table The SavedVariables table to use
---@param key string Key prefix for position data (e.g., "MainWindow")
---@return LoolibDraggableMixin
function LoolibDraggableMixin:SetSavePosition(savedVarsTable, key)
    self.savePosition = true
    self.savedVarsTable = savedVarsTable
    self.positionKey = key
    return self
end

-- ============================================================
-- INTERNAL DRAG HANDLERS
-- ============================================================

function LoolibDraggableMixin:_OnDragStart()
    -- Check modifier requirement
    if self.dragModifier then
        local modifierDown = false
        if self.dragModifier == "shift" then
            modifierDown = IsShiftKeyDown()
        elseif self.dragModifier == "ctrl" then
            modifierDown = IsControlKeyDown()
        elseif self.dragModifier == "alt" then
            modifierDown = IsAltKeyDown()
        end

        if not modifierDown then
            return
        end
    end

    if not self.dragEnabled or not self:IsMovable() then
        return
    end

    self._isDragging = true

    -- Save original anchor points (for restoration if needed)
    -- Pattern from ExLib.lua:3851-3854
    self._originalPoints = {}
    for i = 1, self:GetNumPoints() do
        self._originalPoints[i] = {self:GetPoint(i)}
    end

    -- Get start position
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self._dragStartX = x / scale
    self._dragStartY = y / scale

    -- Create ghost if needed
    local ghostFrame = nil
    if self.useGhost then
        ghostFrame = self:_CreateGhost()
    end

    -- Notify DragContext if we have drag data (for drop target detection)
    if self.dragData then
        local DragContext = Loolib:GetModule("DragContext")
        if DragContext then
            DragContext:StartDrag(self, self.dragData, ghostFrame)
        end
    else
        -- Simple window drag - just start moving
        -- Pattern from MarksBar.lua:47-48
        self:StartMoving()
    end

    -- Call override point
    if self.OnDragStart then
        self:OnDragStart()
    end

    -- Hide tooltip during drag (from ExLib.lua:3856)
    GameTooltip:Hide()
end

function LoolibDraggableMixin:_OnDragStop()
    if not self._isDragging then
        return
    end

    self._isDragging = false
    self:StopMovingOrSizing()

    local success = false

    -- End drag context if active
    if self.dragData then
        local DragContext = Loolib:GetModule("DragContext")
        if DragContext and DragContext:IsDragging() then
            success = DragContext:EndDrag()
        end
    end

    -- Save position if enabled
    -- Pattern from MarksBar.lua:52-53
    if self.savePosition and self.savedVarsTable and self.positionKey then
        self:_SavePosition()
    end

    -- Destroy ghost
    if self._ghostFrame then
        self._ghostFrame:Hide()
        self._ghostFrame = nil
    end

    -- Call override point
    if self.OnDragEnd then
        self:OnDragEnd(success)
    end
end

-- ============================================================
-- GHOST FRAME
-- ============================================================

function LoolibDraggableMixin:_CreateGhost()
    if self._ghostFrame then
        return self._ghostFrame
    end

    -- Create ghost frame
    local ghost
    if self.ghostTemplate then
        ghost = CreateFrame("Frame", nil, UIParent, self.ghostTemplate)
    else
        -- Create simple semi-transparent copy
        ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        ghost:SetSize(self:GetSize())
        ghost:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        ghost:SetBackdropColor(0.3, 0.5, 0.8, 0.5)
        ghost:SetBackdropBorderColor(0.5, 0.7, 1.0, 0.8)
    end

    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetFrameLevel(9000)
    ghost:SetAlpha(0.7)

    self._ghostFrame = ghost
    return ghost
end

-- ============================================================
-- POSITION PERSISTENCE
-- ============================================================

function LoolibDraggableMixin:_SavePosition()
    if not self.savedVarsTable or not self.positionKey then
        return
    end

    -- Pattern from MarksBar.lua:52-53
    local left = self:GetLeft()
    local top = self:GetTop()

    if left and top then
        self.savedVarsTable[self.positionKey .. "Left"] = left
        self.savedVarsTable[self.positionKey .. "Top"] = top
    end
end

---Restore saved position
---@return boolean success
function LoolibDraggableMixin:RestorePosition()
    if not self.savedVarsTable or not self.positionKey then
        return false
    end

    local left = self.savedVarsTable[self.positionKey .. "Left"]
    local top = self.savedVarsTable[self.positionKey .. "Top"]

    if left and top then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        return true
    end

    return false
end

---Restore original anchor points (before drag started)
---Used for list reordering when drag is cancelled
---Pattern from ExLib.lua:3883-3886
function LoolibDraggableMixin:RestoreOriginalPoints()
    if not self._originalPoints or #self._originalPoints == 0 then
        return
    end

    self:ClearAllPoints()
    for _, point in ipairs(self._originalPoints) do
        self:SetPoint(unpack(point))
    end
end

---Center on screen (default position)
function LoolibDraggableMixin:CenterOnScreen()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

-- ============================================================
-- QUERY METHODS
-- ============================================================

function LoolibDraggableMixin:IsDragging()
    return self._isDragging
end

function LoolibDraggableMixin:GetDragData()
    return self.dragData
end

-- ============================================================
-- OVERRIDE POINTS (implement in consuming code)
-- ============================================================

-- Override these in your frame to customize behavior:
--
-- function MyFrame:OnDragStart()
--     print("Started dragging!")
-- end
--
-- function MyFrame:OnDragEnd(success)
--     if success then
--         print("Dropped on valid target")
--     else
--         print("Drag cancelled")
--     end
-- end

-- ============================================================
-- REGISTER WITH LOOLIB
-- ============================================================

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.DraggableMixin = LoolibDraggableMixin

Loolib:RegisterModule("DragDrop.DraggableMixin", LoolibDraggableMixin)
