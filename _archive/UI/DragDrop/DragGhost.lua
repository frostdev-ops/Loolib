--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    DragGhost - Visual ghost/preview frame for drag-and-drop operations

    Provides a visual preview that follows the cursor during drag operations,
    with valid/invalid state indication through color tinting.

    DD-02: Ghost frames are created via factory and reused via singleton.
    The shared ghost (GetShared) is a singleton that is hidden/reset on each
    use rather than destroyed, preventing frame leaks.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local LoolibMixin = assert(Loolib.Mixin, "Loolib.Mixin is required for DragGhost")

-- Local references to globals
local type = type
local error = error
local math_max = math.max

--[[--------------------------------------------------------------------
    LoolibDragGhostMixin

    Mixin for creating drag ghost frames that follow the cursor and
    show visual feedback for valid/invalid drop targets.
----------------------------------------------------------------------]]

---@class LoolibDragGhostMixin : Frame
---@field isShowing boolean
---@field isValid boolean
---@field offsetX number
---@field offsetY number
---@field sourceFrame Frame?
---@field dragData any
---@field validColor table
---@field invalidColor table
---@field validBorderColor table
---@field invalidBorderColor table
---@field background Texture
---@field icon Texture
---@field label FontString
---@field indicator Texture
---@field _loaded boolean
local LoolibDragGhostMixin = {}

-- ============================================================
-- INITIALIZATION
-- ============================================================

--- Initialize the ghost frame.
--- Idempotent: safe to call multiple times.
---@return nil
function LoolibDragGhostMixin:OnLoad()
    if self._loaded then
        return
    end

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

    self._loaded = true
end

-- ============================================================
-- SHOWING/HIDING
-- ============================================================

--- Show ghost for a source frame
---@param sourceFrame Frame The frame being dragged
---@param dragData any? Optional data for the ghost to display
---@return nil
function LoolibDragGhostMixin:ShowFor(sourceFrame, dragData)
    if type(sourceFrame) ~= "table" or not sourceFrame.GetObjectType then
        error("LoolibDragGhost: ShowFor: 'sourceFrame' must be a Frame object", 2)
    end

    self.sourceFrame = sourceFrame
    self.dragData = dragData
    self.isShowing = true
    self.isValid = true

    -- Default size matches source
    local width, height = sourceFrame:GetSize()
    self:SetSize(math_max(width, 60), math_max(height, 24))

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

    -- Apply valid color (force refresh by toggling state)
    self.isValid = false
    self:SetValid(true)

    self:Show()
end

--- Hide the ghost and reset state for reuse (DD-02)
---@return nil
function LoolibDragGhostMixin:HideGhost()
    self.isShowing = false
    self.sourceFrame = nil
    self.dragData = nil
    self.icon:Hide()
    self.label:Hide()
    self.indicator:Hide()
    self:Hide()
end

-- ============================================================
-- POSITION UPDATES
-- ============================================================

--- Update ghost position to follow cursor
---@param x number? Cursor X position (scaled), if nil will get current cursor position
---@param y number? Cursor Y position (scaled), if nil will get current cursor position
---@return nil
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

--- Set position offset from cursor
---@param offsetX number Horizontal offset
---@param offsetY number Vertical offset
---@return nil
function LoolibDragGhostMixin:SetOffset(offsetX, offsetY)
    if type(offsetX) ~= "number" then
        error("LoolibDragGhost: SetOffset: 'offsetX' must be a number", 2)
    end
    if type(offsetY) ~= "number" then
        error("LoolibDragGhost: SetOffset: 'offsetY' must be a number", 2)
    end
    self.offsetX = offsetX
    self.offsetY = offsetY
end

-- ============================================================
-- VALIDITY STATE
-- ============================================================

--- Set valid/invalid visual state
---@param isValid boolean True if current drop target is valid
---@return nil
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

--- Set the ghost icon
---@param icon string|number|nil Texture path or file ID
---@param isAtlas boolean? If true, treat as atlas name (WoW 12.0+)
---@return nil
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

--- Set the ghost label text
---@param text string? Label text to display
---@return nil
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

--- Show validity indicator (checkmark/X)
---@param show boolean Whether to show the indicator
---@return nil
function LoolibDragGhostMixin:ShowIndicator(show)
    if show then
        self.indicator:Show()
        -- Force refresh indicator appearance
        local current = self.isValid
        self.isValid = not current
        self:SetValid(current)
    else
        self.indicator:Hide()
    end
end

--- Set custom colors for valid/invalid states
---@param validColor table? {r, g, b, a} Color for valid state
---@param invalidColor table? {r, g, b, a} Color for invalid state
---@param validBorder table? {r, g, b, a} Border color for valid state
---@param invalidBorder table? {r, g, b, a} Border color for invalid state
---@return nil
function LoolibDragGhostMixin:SetColors(validColor, invalidColor, validBorder, invalidBorder)
    if validColor then self.validColor = validColor end
    if invalidColor then self.invalidColor = invalidColor end
    if validBorder then self.validBorderColor = validBorder end
    if invalidBorder then self.invalidBorderColor = invalidBorder end

    -- Refresh appearance
    if self.isShowing then
        local current = self.isValid
        self.isValid = not current
        self:SetValid(current)
    end
end

--- Update appearance from drag data -- INTERNAL
---@return nil
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

--- Clone the visual appearance of source frame
---@param sourceFrame Frame Frame to copy appearance from
---@return nil
function LoolibDragGhostMixin:CloneAppearance(sourceFrame)
    if type(sourceFrame) ~= "table" or not sourceFrame.GetObjectType then
        error("LoolibDragGhost: CloneAppearance: 'sourceFrame' must be a Frame object", 2)
    end

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

--- OnUpdate handler to automatically follow cursor
---@param elapsed number Frame delta time
---@return nil
function LoolibDragGhostMixin:OnUpdate(elapsed) -- luacheck: ignore 212
    if self.isShowing then
        self:UpdatePosition()
    end
end

-- ============================================================
-- FACTORY FUNCTION
-- ============================================================

--- Create a new drag ghost frame
---@param parent Frame? Parent frame (defaults to UIParent)
---@param name string? Optional global frame name
---@return Frame ghost Ghost frame with LoolibDragGhostMixin
local function LoolibCreateDragGhost(parent, name)
    local ghost = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    LoolibMixin(ghost, LoolibDragGhostMixin)
    ghost:OnLoad()

    -- Set up automatic cursor tracking
    ghost:SetScript("OnUpdate", ghost.OnUpdate)

    return ghost
end

-- ============================================================
-- SHARED SINGLETON (DD-02)
-- ============================================================

-- Global shared ghost (singleton for simple use cases)
-- Created once, reused via HideGhost/ShowFor cycle to prevent frame leaks.
local sharedGhost = nil

--- Get or create shared drag ghost frame.
--- The shared ghost is a singleton that is reused across drag operations.
---@return Frame ghost Shared drag ghost instance
local function LoolibGetSharedDragGhost()
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
local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.DragGhost = DragGhostModule
UI.CreateDragGhost = LoolibCreateDragGhost
UI.GetSharedDragGhost = LoolibGetSharedDragGhost

Loolib:RegisterModule("DragDrop.DragGhost", DragGhostModule)
