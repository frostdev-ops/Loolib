--[[
================================================================================
Loolib - Canvas Toolbar
================================================================================
This file is part of Loolib, a library for World of Warcraft addons.

File: CanvasToolbar.lua
Description: Tool selection UI for the canvas - buttons for brush, shapes,
             text, icons, images, move tool, color picker, size slider, zoom
             controls, and undo/redo.

Author: James Kueller
License: MIT

Dependencies:
  - Core/Mixin.lua
  - Core/Loolib.lua (LibStub)

Usage:
  local Loolib = LibStub("Loolib")
  local CanvasToolbar = Loolib:GetModule("CanvasToolbar")

  local toolbar = CanvasToolbar.Create()
  toolbar:SetCanvas(myCanvas)
  toolbar:BuildUI(parentFrame)
  toolbar:SetTool(CanvasToolbar.TOOLS.BRUSH)

================================================================================
--]]

-- Tool constants
LOOLIB_CANVAS_TOOLS = {
    BRUSH = "brush",
    SHAPE_LINE = "shape_line",
    SHAPE_ARROW = "shape_arrow",
    SHAPE_CIRCLE = "shape_circle",
    SHAPE_RECTANGLE = "shape_rectangle",
    TEXT = "text",
    ICON = "icon",
    IMAGE = "image",
    MOVE = "move",
    SELECT = "select",
    ERASE = "erase",
}

-- LoolibCanvasToolbarMixin
local LoolibCanvasToolbarMixin = {}

function LoolibCanvasToolbarMixin:OnLoad()
    -- Current tool
    self._currentTool = LOOLIB_CANVAS_TOOLS.BRUSH
    self._currentColor = 4  -- Red
    self._currentSize = 6

    -- UI elements (created on BuildUI)
    self._toolButtons = {}
    self._colorButtons = {}
    self._sizeSlider = nil
    self._sizeLabel = nil
    self._zoomDisplay = nil
    self._undoButton = nil
    self._redoButton = nil
    self._frame = nil

    -- References
    self._canvas = nil  -- Main canvas frame
end

-- Set canvas reference
function LoolibCanvasToolbarMixin:SetCanvas(canvas)
    self._canvas = canvas
    return self
end

-- Build toolbar UI
function LoolibCanvasToolbarMixin:BuildUI(parent)
    -- Create toolbar frame
    self._frame = CreateFrame("Frame", nil, parent)
    self._frame:SetSize(40, 400)
    self._frame:SetPoint("LEFT", parent, "LEFT", 5, 0)

    -- Tool section
    local y = -5

    -- Brush tool
    y = self:_CreateToolButton("brush", "Interface\\Icons\\INV_Inscription_Pigment_Grey", y, "Brush")

    -- Shape tools
    y = self:_CreateToolButton("shape_line", "Interface\\Icons\\Spell_Holy_BorrowedTime", y, "Line")
    y = self:_CreateToolButton("shape_arrow", "Interface\\Icons\\Ability_Hunter_AspectOfTheViper", y, "Arrow")
    y = self:_CreateToolButton("shape_circle", "Interface\\Icons\\Spell_Arcane_FocusedPower", y, "Circle")
    y = self:_CreateToolButton("shape_rectangle", "Interface\\Icons\\INV_Misc_Note_01", y, "Rectangle")

    -- Text tool
    y = self:_CreateToolButton("text", "Interface\\Icons\\INV_Misc_Note_06", y, "Text")

    -- Icon tool
    y = self:_CreateToolButton("icon", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", y, "Icon")

    -- Image tool
    y = self:_CreateToolButton("image", "Interface\\Icons\\INV_Misc_Map_01", y, "Image")

    -- Move tool
    y = self:_CreateToolButton("move", "Interface\\Icons\\Spell_ChargePositive", y, "Move")

    -- Select tool
    y = self:_CreateToolButton("select", "Interface\\Icons\\Ability_Ensnare", y, "Select")

    -- Separator
    y = y - 10

    -- Color palette (2 rows of 5)
    y = self:_CreateColorPalette(y)

    -- Size slider
    y = y - 10
    y = self:_CreateSizeSlider(y)

    -- Separator
    y = y - 10

    -- Zoom controls
    y = self:_CreateZoomControls(y)

    -- Undo/Redo
    y = y - 10
    y = self:_CreateUndoRedo(y)

    -- Select default tool
    if self._toolButtons["brush"] then
        self._toolButtons["brush"].selected:Show()
    end

    return self
end

-- Create tool button
function LoolibCanvasToolbarMixin:_CreateToolButton(toolId, icon, y, tooltip)
    local btn = CreateFrame("Button", nil, self._frame)
    btn:SetSize(32, 32)
    btn:SetPoint("TOPLEFT", 4, y)

    -- Background
    btn:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    -- Icon
    local iconTex = btn:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(28, 28)
    iconTex:SetPoint("CENTER")
    iconTex:SetTexture(icon)
    btn.icon = iconTex

    -- Selection highlight
    local selected = btn:CreateTexture(nil, "OVERLAY")
    selected:SetAllPoints()
    selected:SetColorTexture(1, 1, 0, 0.3)
    selected:Hide()
    btn.selected = selected

    -- Click handler
    local toolbar = self
    btn:SetScript("OnClick", function()
        toolbar:SetTool(toolId)
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self._toolButtons[toolId] = btn

    return y - 34
end

-- Create color palette
function LoolibCanvasToolbarMixin:_CreateColorPalette(y)
    local colors = {
        {0, 0, 0},        -- Black
        {1, 0, 0},        -- Red
        {0, 1, 0},        -- Green
        {0, 0, 1},        -- Blue
        {1, 1, 0},        -- Yellow
        {1, 1, 1},        -- White
        {1, 0.5, 0},      -- Orange
        {0.5, 0, 1},      -- Purple
        {0, 1, 1},        -- Cyan
        {1, 0.75, 0.8},   -- Pink
    }

    for i, color in ipairs(colors) do
        local row = math.floor((i - 1) / 5)
        local col = (i - 1) % 5

        local btn = CreateFrame("Button", nil, self._frame)
        btn:SetSize(16, 16)
        btn:SetPoint("TOPLEFT", 4 + col * 17, y - row * 17)

        local tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        tex:SetColorTexture(color[1], color[2], color[3])

        local border = btn:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0.3, 0.3, 0.3)

        local toolbar = self
        btn:SetScript("OnClick", function()
            toolbar:SetColor(i)
        end)

        self._colorButtons[i] = btn
    end

    return y - 40
end

-- Create size slider
function LoolibCanvasToolbarMixin:_CreateSizeSlider(y)
    local label = self._frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 4, y)
    label:SetText("Size: 6")
    self._sizeLabel = label

    local slider = CreateFrame("Slider", nil, self._frame, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 4, y - 15)
    slider:SetSize(85, 16)
    slider:SetMinMaxValues(2, 20)
    slider:SetValue(6)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    local toolbar = self
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        label:SetText("Size: " .. value)
        toolbar:SetSize(value)
    end)

    self._sizeSlider = slider

    return y - 35
end

-- Create zoom controls
function LoolibCanvasToolbarMixin:_CreateZoomControls(y)
    -- Zoom label
    local label = self._frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 4, y)
    label:SetText("Zoom: 1x")
    self._zoomDisplay = label

    local toolbar = self

    -- Zoom out button
    local zoomOut = CreateFrame("Button", nil, self._frame)
    zoomOut:SetSize(20, 20)
    zoomOut:SetPoint("TOPLEFT", 4, y - 15)
    zoomOut:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    zoomOut:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
    zoomOut:SetScript("OnClick", function()
        if toolbar._canvas then
            toolbar._canvas:ZoomOut()
            toolbar:UpdateZoomDisplay()
        end
    end)

    -- Zoom in button
    local zoomIn = CreateFrame("Button", nil, self._frame)
    zoomIn:SetSize(20, 20)
    zoomIn:SetPoint("LEFT", zoomOut, "RIGHT", 5, 0)
    zoomIn:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    zoomIn:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
    zoomIn:SetScript("OnClick", function()
        if toolbar._canvas then
            toolbar._canvas:ZoomIn()
            toolbar:UpdateZoomDisplay()
        end
    end)

    -- Reset zoom
    local resetZoom = CreateFrame("Button", nil, self._frame)
    resetZoom:SetSize(20, 20)
    resetZoom:SetPoint("LEFT", zoomIn, "RIGHT", 5, 0)
    resetZoom:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
    resetZoom:SetScript("OnClick", function()
        if toolbar._canvas then
            toolbar._canvas:ResetZoom()
            toolbar:UpdateZoomDisplay()
        end
    end)

    return y - 40
end

-- Create undo/redo buttons
function LoolibCanvasToolbarMixin:_CreateUndoRedo(y)
    local toolbar = self

    -- Undo
    local undo = CreateFrame("Button", nil, self._frame)
    undo:SetSize(32, 32)
    undo:SetPoint("TOPLEFT", 4, y)
    undo:SetNormalTexture("Interface\\Icons\\Spell_Shadow_ShadowWordDominate")
    undo:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    undo:SetScript("OnClick", function()
        if toolbar._canvas then
            toolbar._canvas:Undo()
            toolbar:UpdateUndoRedoState()
        end
    end)
    undo:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Undo (Ctrl+Z)")
        GameTooltip:Show()
    end)
    undo:SetScript("OnLeave", GameTooltip_Hide)
    self._undoButton = undo

    -- Redo
    local redo = CreateFrame("Button", nil, self._frame)
    redo:SetSize(32, 32)
    redo:SetPoint("LEFT", undo, "RIGHT", 5, 0)
    redo:SetNormalTexture("Interface\\Icons\\Spell_Holy_BorrowedTime")
    redo:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    redo:SetScript("OnClick", function()
        if toolbar._canvas then
            toolbar._canvas:Redo()
            toolbar:UpdateUndoRedoState()
        end
    end)
    redo:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Redo (Ctrl+Y)")
        GameTooltip:Show()
    end)
    redo:SetScript("OnLeave", GameTooltip_Hide)
    self._redoButton = redo

    return y - 40
end

-- Set current tool
function LoolibCanvasToolbarMixin:SetTool(toolId)
    local oldTool = self._currentTool
    self._currentTool = toolId

    -- Update button visuals
    for id, btn in pairs(self._toolButtons) do
        if id == toolId then
            btn.selected:Show()
        else
            btn.selected:Hide()
        end
    end

    -- Notify canvas
    if self._canvas and self._canvas.SetTool then
        self._canvas:SetTool(toolId)
    end

    if self.TriggerEvent then
        self:TriggerEvent("OnToolChanged", toolId, oldTool)
    end

    return self
end

function LoolibCanvasToolbarMixin:GetTool()
    return self._currentTool
end

-- Set current color
function LoolibCanvasToolbarMixin:SetColor(colorIndex)
    self._currentColor = colorIndex

    -- Notify canvas
    if self._canvas and self._canvas.SetColor then
        self._canvas:SetColor(colorIndex)
    end

    if self.TriggerEvent then
        self:TriggerEvent("OnColorChanged", colorIndex)
    end

    return self
end

function LoolibCanvasToolbarMixin:GetColor()
    return self._currentColor
end

-- Set current size
function LoolibCanvasToolbarMixin:SetSize(size)
    self._currentSize = size

    if self._sizeSlider then
        self._sizeSlider:SetValue(size)
    end

    -- Notify canvas
    if self._canvas and self._canvas.SetBrushSize then
        self._canvas:SetBrushSize(size)
    end

    return self
end

function LoolibCanvasToolbarMixin:GetSize()
    return self._currentSize
end

-- Update zoom display
function LoolibCanvasToolbarMixin:UpdateZoomDisplay()
    if self._zoomDisplay and self._canvas then
        local zoom = self._canvas:GetZoom()
        self._zoomDisplay:SetText(string.format("Zoom: %.1fx", zoom))
    end
end

-- Update undo/redo button states
function LoolibCanvasToolbarMixin:UpdateUndoRedoState()
    if self._canvas then
        if self._undoButton then
            self._undoButton:SetEnabled(self._canvas:CanUndo())
        end
        if self._redoButton then
            self._redoButton:SetEnabled(self._canvas:CanRedo())
        end
    end
end

-- Show/hide toolbar
function LoolibCanvasToolbarMixin:Show()
    if self._frame then
        self._frame:Show()
    end
    return self
end

function LoolibCanvasToolbarMixin:Hide()
    if self._frame then
        self._frame:Hide()
    end
    return self
end

function LoolibCanvasToolbarMixin:IsShown()
    return self._frame and self._frame:IsShown()
end

-- Factory function
local function LoolibCreateCanvasToolbar()
    local toolbar = {}
    LoolibMixin(toolbar, LoolibCanvasToolbarMixin)
    toolbar:OnLoad()
    return toolbar
end

-- Module registration
local Loolib = LibStub("Loolib")
Loolib:RegisterModule("CanvasToolbar", {
    Mixin = LoolibCanvasToolbarMixin,
    TOOLS = LOOLIB_CANVAS_TOOLS,
    Create = LoolibCreateCanvasToolbar,
})
