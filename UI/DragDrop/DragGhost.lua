--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    DragGhost - Visual ghost/preview frame for drag-and-drop operations

    Provides a visual preview that follows the cursor during drag operations,
    with valid/invalid state indication through color tinting.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibDragGhostMixin

    Mixin for creating drag ghost frames that follow the cursor and
    show visual feedback for valid/invalid drop targets.
----------------------------------------------------------------------]]

---@class LoolibDragGhostMixin
LoolibDragGhostMixin = {}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function LoolibDragGhostMixin:OnLoad()
    self.isShowing = false
    self.isValid = true
    self.offsetX = 0
    self.offsetY = 0
    self.sourceFrame = nil
    self.dragData = nil

    -- Default appearance colors
    self.validColor = {r = 1, g = 1, b = 1, a = 0.7}
    self.invalidColor = {r = 1, g = 0.3, b = 0.3, a = 0.7}
    self.validBorderColor = {r = 0.3, g = 0.8, b = 0.3, a = 1}
    self.invalidBorderColor = {r = 0.8, g = 0.3, b = 0.3, a = 1}

    -- Set up frame properties
    self:SetFrameStrata("TOOLTIP")
    self:SetFrameLevel(9000)
    self:EnableMouse(false)  -- Ghost shouldn't intercept clicks
    self:Hide()

    -- Create background
    self.background = self:CreateTexture(nil, "BACKGROUND")
    self.background:SetAllPoints()
    self.background:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- Create border using backdrop
    self:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })

    -- Create icon (optional)
    self.icon = self:CreateTexture(nil, "ARTWORK")
    self.icon:SetSize(24, 24)
    self.icon:SetPoint("LEFT", 4, 0)
    self.icon:Hide()

    -- Create text label (optional)
    self.label = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.label:SetPoint("LEFT", self.icon, "RIGHT", 4, 0)
    self.label:SetPoint("RIGHT", -4, 0)
    self.label:SetJustifyH("LEFT")
    self.label:Hide()

    -- Create validity indicator (checkmark/X)
    self.indicator = self:CreateTexture(nil, "OVERLAY")
    self.indicator:SetSize(16, 16)
    self.indicator:SetPoint("TOPRIGHT", 4, 4)
    self.indicator:Hide()
end

-- ============================================================
-- SHOWING/HIDING
-- ============================================================

---Show ghost for a source frame
---@param sourceFrame Frame The frame being dragged
---@param dragData any? Optional data for the ghost to display
function LoolibDragGhostMixin:ShowFor(sourceFrame, dragData)
    self.sourceFrame = sourceFrame
    self.dragData = dragData
    self.isShowing = true
    self.isValid = true

    -- Default size matches source
    local width, height = sourceFrame:GetSize()
    self:SetSize(math.max(width, 60), math.max(height, 24))

    -- Calculate offset from cursor to frame center
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale

    local frameX, frameY = sourceFrame:GetCenter()
    if frameX and frameY then
        self.offsetX = frameX - cursorX
        self.offsetY = frameY - cursorY
    else
        -- Fallback if frame doesn't have a center
        self.offsetX = 0
        self.offsetY = 0
    end

    -- Set up appearance from drag data
    self:_UpdateAppearance()

    -- Initial position
    self:UpdatePosition(cursorX, cursorY)

    -- Apply valid color
    self:SetValid(true)

    self:Show()
end

---Hide the ghost
function LoolibDragGhostMixin:HideGhost()
    self.isShowing = false
    self.sourceFrame = nil
    self.dragData = nil
    self:Hide()
end

-- ============================================================
-- POSITION UPDATES
-- ============================================================

---Update ghost position to follow cursor
---@param x number? Cursor X position (scaled), if nil will get current cursor position
---@param y number? Cursor Y position (scaled), if nil will get current cursor position
function LoolibDragGhostMixin:UpdatePosition(x, y)
    if not self.isShowing then return end

    -- Get cursor position if not provided
    if not x or not y then
        x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        x, y = x / scale, y / scale
    end

    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + self.offsetX, y + self.offsetY)
end

---Set position offset from cursor
---@param offsetX number Horizontal offset
---@param offsetY number Vertical offset
function LoolibDragGhostMixin:SetOffset(offsetX, offsetY)
    self.offsetX = offsetX
    self.offsetY = offsetY
end

-- ============================================================
-- VALIDITY STATE
-- ============================================================

---Set valid/invalid visual state
---@param isValid boolean True if current drop target is valid
function LoolibDragGhostMixin:SetValid(isValid)
    if self.isValid == isValid then return end
    self.isValid = isValid

    if isValid then
        self:SetAlpha(self.validColor.a)
        self:SetBackdropBorderColor(
            self.validBorderColor.r,
            self.validBorderColor.g,
            self.validBorderColor.b,
            self.validBorderColor.a
        )
        self.background:SetColorTexture(0.1, 0.15, 0.1, 0.9)
    else
        self:SetAlpha(self.invalidColor.a)
        self:SetBackdropBorderColor(
            self.invalidBorderColor.r,
            self.invalidBorderColor.g,
            self.invalidBorderColor.b,
            self.invalidBorderColor.a
        )
        self.background:SetColorTexture(0.15, 0.1, 0.1, 0.9)
    end

    -- Update indicator if shown
    if self.indicator:IsShown() then
        if isValid then
            -- Use texture for checkmark (atlas may not be available)
            self.indicator:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            self.indicator:SetVertexColor(0.3, 0.8, 0.3, 1)
        else
            -- Use X texture
            self.indicator:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            self.indicator:SetVertexColor(0.8, 0.3, 0.3, 1)
        end
    end
end

-- ============================================================
-- APPEARANCE CUSTOMIZATION
-- ============================================================

---Set the ghost icon
---@param icon string|number Texture path or file ID
---@param isAtlas boolean? If true, treat as atlas name (WoW 12.0+)
function LoolibDragGhostMixin:SetIcon(icon, isAtlas)
    if icon then
        if isAtlas then
            -- Try to use atlas if available
            if self.icon.SetAtlas then
                self.icon:SetAtlas(icon)
            else
                self.icon:SetTexture(icon)
            end
        else
            self.icon:SetTexture(icon)
        end
        self.icon:Show()

        -- Adjust label position to make room for icon
        if self.label:IsShown() then
            self.label:SetPoint("LEFT", self.icon, "RIGHT", 4, 0)
        end
    else
        self.icon:Hide()

        -- Adjust label to fill space
        if self.label:IsShown() then
            self.label:SetPoint("LEFT", 4, 0)
        end
    end
end

---Set the ghost label text
---@param text string? Label text to display
function LoolibDragGhostMixin:SetLabel(text)
    if text then
        self.label:SetText(text)
        self.label:Show()

        -- Position depends on whether icon is shown
        if self.icon:IsShown() then
            self.label:SetPoint("LEFT", self.icon, "RIGHT", 4, 0)
        else
            self.label:SetPoint("LEFT", 4, 0)
        end
    else
        self.label:Hide()
    end
end

---Show validity indicator (checkmark/X)
---@param show boolean Whether to show the indicator
function LoolibDragGhostMixin:ShowIndicator(show)
    if show then
        self.indicator:Show()
        self:SetValid(self.isValid)  -- Update indicator appearance
    else
        self.indicator:Hide()
    end
end

---Set custom colors for valid/invalid states
---@param validColor table? {r, g, b, a} Color for valid state
---@param invalidColor table? {r, g, b, a} Color for invalid state
---@param validBorder table? {r, g, b, a} Border color for valid state
---@param invalidBorder table? {r, g, b, a} Border color for invalid state
function LoolibDragGhostMixin:SetColors(validColor, invalidColor, validBorder, invalidBorder)
    if validColor then self.validColor = validColor end
    if invalidColor then self.invalidColor = invalidColor end
    if validBorder then self.validBorderColor = validBorder end
    if invalidBorder then self.invalidBorderColor = invalidBorder end

    -- Refresh appearance
    if self.isShowing then
        self:SetValid(self.isValid)
    end
end

---Update appearance from drag data
function LoolibDragGhostMixin:_UpdateAppearance()
    local data = self.dragData

    if not data then
        self.icon:Hide()
        self.label:Hide()
        return
    end

    -- Handle table data with icon/label fields
    if type(data) == "table" then
        if data.icon then
            self:SetIcon(data.icon, data.iconIsAtlas)
        end
        if data.label or data.name or data.text then
            self:SetLabel(data.label or data.name or data.text)
        end
    elseif type(data) == "string" then
        -- String data becomes the label
        self:SetLabel(data)
    end
end

-- ============================================================
-- CONTENT CLONING (copy visual from source)
-- ============================================================

---Clone the visual appearance of source frame
---@param sourceFrame Frame Frame to copy appearance from
function LoolibDragGhostMixin:CloneAppearance(sourceFrame)
    -- Try to copy backdrop
    if sourceFrame.GetBackdrop then
        local backdrop = sourceFrame:GetBackdrop()
        if backdrop then
            self:SetBackdrop(backdrop)
            local r, g, b, a = sourceFrame:GetBackdropColor()
            if r and g and b then
                self:SetBackdropColor(r, g, b, (a or 1) * 0.8)
            end
        end
    end

    -- Copy size
    local width, height = sourceFrame:GetSize()
    self:SetSize(width, height)
end

-- ============================================================
-- ONUPDATE FOR POSITION TRACKING
-- ============================================================

---OnUpdate handler to automatically follow cursor
function LoolibDragGhostMixin:OnUpdate(elapsed)
    if self.isShowing then
        self:UpdatePosition()
    end
end

-- ============================================================
-- FACTORY FUNCTION
-- ============================================================

---Create a new drag ghost frame
---@param parent Frame? Parent frame (defaults to UIParent)
---@param name string? Optional global frame name
---@return Frame Ghost frame with LoolibDragGhostMixin
function LoolibCreateDragGhost(parent, name)
    local ghost = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    LoolibMixin(ghost, LoolibDragGhostMixin)
    ghost:OnLoad()

    -- Set up automatic cursor tracking
    ghost:SetScript("OnUpdate", ghost.OnUpdate)

    return ghost
end

-- ============================================================
-- SHARED SINGLETON
-- ============================================================

-- Global shared ghost (singleton for simple use cases)
local sharedGhost = nil

---Get or create shared drag ghost frame
---@return Frame Shared drag ghost instance
function LoolibGetSharedDragGhost()
    if not sharedGhost then
        sharedGhost = LoolibCreateDragGhost(UIParent, "LoolibSharedDragGhost")
    end
    return sharedGhost
end

-- ============================================================
-- REGISTER WITH LOOLIB
-- ============================================================

local DragGhostModule = {
    Mixin = LoolibDragGhostMixin,
    Create = LoolibCreateDragGhost,
    GetShared = LoolibGetSharedDragGhost,
}

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.DragGhost = DragGhostModule
UI.CreateDragGhost = LoolibCreateDragGhost
UI.GetSharedDragGhost = LoolibGetSharedDragGhost

Loolib:RegisterModule("DragGhost", DragGhostModule)
