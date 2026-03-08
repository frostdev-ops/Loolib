--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ColorSwatch - Color picker widget with presets and recent colors

    Features:
    - Simple color swatch with picker
    - Preset color palette (common + class colors)
    - Recent colors tracking (saved to SavedVariables)
    - Hex input field with validation
    - Optional alpha/opacity support
    - Click to open Blizzard ColorPickerFrame
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Color Presets
----------------------------------------------------------------------]]

local COMMON_COLORS = {
    { name = "Red", r = 1.0, g = 0.0, b = 0.0 },
    { name = "Green", r = 0.0, g = 1.0, b = 0.0 },
    { name = "Blue", r = 0.0, g = 0.0, b = 1.0 },
    { name = "Yellow", r = 1.0, g = 1.0, b = 0.0 },
    { name = "Orange", r = 1.0, g = 0.5, b = 0.0 },
    { name = "Purple", r = 0.5, g = 0.0, b = 1.0 },
    { name = "White", r = 1.0, g = 1.0, b = 1.0 },
    { name = "Gray", r = 0.5, g = 0.5, b = 0.5 },
}

local CLASS_COLORS = {
    { name = "Warrior", r = 0.78, g = 0.61, b = 0.43 },
    { name = "Paladin", r = 0.96, g = 0.55, b = 0.73 },
    { name = "Hunter", r = 0.67, g = 0.83, b = 0.45 },
    { name = "Rogue", r = 1.00, g = 0.96, b = 0.41 },
    { name = "Priest", r = 1.00, g = 1.00, b = 1.00 },
    { name = "Death Knight", r = 0.77, g = 0.12, b = 0.23 },
    { name = "Shaman", r = 0.00, g = 0.44, b = 0.87 },
    { name = "Mage", r = 0.41, g = 0.80, b = 0.94 },
    { name = "Warlock", r = 0.58, g = 0.51, b = 0.79 },
    { name = "Monk", r = 0.00, g = 1.00, b = 0.59 },
    { name = "Druid", r = 1.00, g = 0.49, b = 0.04 },
    { name = "Demon Hunter", r = 0.64, g = 0.19, b = 0.79 },
    { name = "Evoker", r = 0.20, g = 0.58, b = 0.50 },
}

--[[--------------------------------------------------------------------
    Helper Functions
----------------------------------------------------------------------]]

-- Convert RGB to hex string
local function RGBToHex(r, g, b)
    r = math.floor((r or 0) * 255 + 0.5)
    g = math.floor((g or 0) * 255 + 0.5)
    b = math.floor((b or 0) * 255 + 0.5)
    return string.format("%02X%02X%02X", r, g, b)
end

-- Convert hex string to RGB
-- Returns r, g, b on success or nil, nil, nil on invalid input
local function HexToRGB(hex)
    if not hex or type(hex) ~= "string" then
        return nil, nil, nil
    end

    -- Remove # prefix and whitespace
    hex = hex:gsub("^#", ""):gsub("%s+", ""):upper()

    -- Validate length (must be exactly 6 characters)
    if #hex ~= 6 then
        return nil, nil, nil
    end

    -- Validate hex characters (0-9, A-F)
    if not hex:match("^%x+$") then
        return nil, nil, nil
    end

    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255

    return r, g, b
end

-- Validate hex color string
local function IsValidHex(hex)
    hex = hex:gsub("#", "")
    return #hex == 6 and hex:match("^[0-9A-Fa-f]+$") ~= nil
end

--[[--------------------------------------------------------------------
    LoolibColorSwatchMixin - Simple color swatch
----------------------------------------------------------------------]]

LoolibColorSwatchMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local COLOR_SWATCH_EVENTS = {
    "OnColorChanged",
}

--- Initialize the color swatch
function LoolibColorSwatchMixin:OnLoad()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(COLOR_SWATCH_EVENTS)

    self.r = 1
    self.g = 1
    self.b = 1
    self.a = 1
    self.hasAlpha = false
    self.callback = nil

    -- Create swatch button
    self.Swatch = CreateFrame("Button", nil, self, "BackdropTemplate")
    self.Swatch:SetSize(24, 24)
    self.Swatch:SetPoint("TOPLEFT")

    -- Background
    self.Swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    self.Swatch:SetBackdropColor(1, 1, 1, 1)
    self.Swatch:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Highlight on hover
    local highlight = self.Swatch:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.2)
    highlight:SetBlendMode("ADD")

    -- Click handler
    self.Swatch:SetScript("OnClick", function()
        self:OpenColorPicker()
    end)

    -- Tooltip
    self.Swatch:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to pick color", 1, 1, 1)
        if self.hasAlpha then
            GameTooltip:AddLine("Current: #" .. RGBToHex(self.r, self.g, self.b) .. string.format(" (%.0f%% opacity)", self.a * 100), 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("Current: #" .. RGBToHex(self.r, self.g, self.b), 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    self.Swatch:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self:SetSize(24, 24)
    self:UpdateDisplay()
end

--- Set the color
-- @param r number - Red (0-1)
-- @param g number - Green (0-1)
-- @param b number - Blue (0-1)
-- @param a number - Alpha (0-1, optional)
function LoolibColorSwatchMixin:SetColor(r, g, b, a)
    self.r = r or 1
    self.g = g or 1
    self.b = b or 1
    self.a = a or 1
    self:UpdateDisplay()
end

--- Get the color
-- @return r, g, b, a
function LoolibColorSwatchMixin:GetColor()
    return self.r, self.g, self.b, self.a
end

--- Set whether alpha is enabled
-- @param hasAlpha boolean
function LoolibColorSwatchMixin:SetHasAlpha(hasAlpha)
    self.hasAlpha = hasAlpha
end

--- Set the callback function
-- @param callback function - Called with (r, g, b, a) on color change
function LoolibColorSwatchMixin:SetCallback(callback)
    self.callback = callback
end

--- Update the swatch display
function LoolibColorSwatchMixin:UpdateDisplay()
    -- Guard against recursive calls
    if self.isUpdating then return end
    self.isUpdating = true

    if self.Swatch then
        self.Swatch:SetBackdropColor(self.r, self.g, self.b, self.a)
    end

    self.isUpdating = nil
end

--- Open the Blizzard color picker
function LoolibColorSwatchMixin:OpenColorPicker()
    local info = {}
    info.r = self.r
    info.g = self.g
    info.b = self.b
    -- NOTE: WoW's ColorPickerFrame uses "opacity" which is inverted from "alpha"
    -- Opacity = 1 - Alpha (e.g., 100% opacity = 1.0 alpha, 0% opacity = 0.0 alpha)
    info.opacity = self.hasAlpha and (1 - self.a) or nil
    info.hasOpacity = self.hasAlpha

    info.swatchFunc = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a = 1
        if self.hasAlpha then
            -- Convert opacity back to alpha: alpha = 1 - opacity
            a = 1 - OpacitySliderFrame:GetValue()
        end
        self:SetColor(r, g, b, a)
        self:TriggerEvent("OnColorChanged", r, g, b, a)
        if self.callback then
            self.callback(r, g, b, a)
        end
    end

    info.opacityFunc = info.swatchFunc

    info.cancelFunc = function()
        -- Convert opacity back to alpha when canceling
        self:SetColor(info.r, info.g, info.b, info.opacity and (1 - info.opacity) or 1)
        self:TriggerEvent("OnColorChanged", self.r, self.g, self.b, self.a)
        if self.callback then
            self.callback(self.r, self.g, self.b, self.a)
        end
    end

    ColorPickerFrame:SetupColorPickerAndShow(info)
end

--[[--------------------------------------------------------------------
    LoolibColorSwatchWithPresetsMixin - Extended version with presets
----------------------------------------------------------------------]]

LoolibColorSwatchWithPresetsMixin = LoolibCreateFromMixins(LoolibColorSwatchMixin)

--- Initialize the color swatch with presets
function LoolibColorSwatchWithPresetsMixin:OnLoad()
    LoolibColorSwatchMixin.OnLoad(self)

    self.recentColorsKey = nil
    self.recentColors = {}
    self.maxRecentColors = 5

    -- Resize container to fit all elements
    self:SetSize(280, 130)

    -- Reposition main swatch
    self.Swatch:ClearAllPoints()
    self.Swatch:SetPoint("TOPLEFT", 0, 0)
    self.Swatch:SetSize(32, 32)

    -- Create hex input label
    local hexLabel = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hexLabel:SetPoint("LEFT", self.Swatch, "RIGHT", 8, 0)
    hexLabel:SetText("Hex:")
    self.HexLabel = hexLabel

    -- Create hex input field
    local hexInput = CreateFrame("EditBox", nil, self, "InputBoxTemplate")
    hexInput:SetSize(80, 20)
    hexInput:SetPoint("LEFT", hexLabel, "RIGHT", 4, 0)
    hexInput:SetAutoFocus(false)
    hexInput:SetMaxLetters(7)
    hexInput:SetScript("OnEnterPressed", function(editBox)
        self:ApplyHexColor(editBox:GetText())
        editBox:ClearFocus()
    end)
    hexInput:SetScript("OnEscapePressed", function(editBox)
        editBox:SetText(RGBToHex(self.r, self.g, self.b))
        editBox:ClearFocus()
    end)
    hexInput:SetScript("OnEditFocusLost", function(editBox)
        editBox:SetText(RGBToHex(self.r, self.g, self.b))
    end)
    self.HexInput = hexInput

    -- Alpha slider (hidden by default)
    local alphaLabel = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    alphaLabel:SetPoint("TOPLEFT", self.Swatch, "BOTTOMLEFT", 0, -8)
    alphaLabel:SetText("Opacity:")
    alphaLabel:Hide()
    self.AlphaLabel = alphaLabel

    local alphaSlider = CreateFrame("Slider", nil, self, "OptionsSliderTemplate")
    alphaSlider:SetPoint("LEFT", alphaLabel, "RIGHT", 4, 0)
    alphaSlider:SetSize(120, 16)
    alphaSlider:SetMinMaxValues(0, 100)
    alphaSlider:SetValueStep(1)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider.Low = alphaSlider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    alphaSlider.Low:SetPoint("TOPLEFT", alphaSlider, "BOTTOMLEFT", 0, 0)
    alphaSlider.Low:SetText("0%")
    alphaSlider.High = alphaSlider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    alphaSlider.High:SetPoint("TOPRIGHT", alphaSlider, "BOTTOMRIGHT", 0, 0)
    alphaSlider.High:SetText("100%")
    alphaSlider:SetScript("OnValueChanged", function(slider, value)
        self.a = value / 100
        self:UpdateDisplay()
        self:TriggerEvent("OnColorChanged", self.r, self.g, self.b, self.a)
        if self.callback then
            self.callback(self.r, self.g, self.b, self.a)
        end
    end)
    alphaSlider:Hide()
    self.AlphaSlider = alphaSlider

    -- Create preset palette container
    local presetLabel = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    presetLabel:SetPoint("TOPLEFT", 0, -40)
    presetLabel:SetText("Presets:")
    self.PresetLabel = presetLabel

    -- Common colors (first row)
    local commonFrame = CreateFrame("Frame", nil, self)
    commonFrame:SetPoint("TOPLEFT", presetLabel, "BOTTOMLEFT", 0, -4)
    commonFrame:SetSize(280, 20)
    self.CommonFrame = commonFrame
    self:CreatePresetSwatches(COMMON_COLORS, commonFrame, 0)

    -- Class colors (second row)
    local classFrame = CreateFrame("Frame", nil, self)
    classFrame:SetPoint("TOPLEFT", commonFrame, "BOTTOMLEFT", 0, -4)
    classFrame:SetSize(280, 20)
    self.ClassFrame = classFrame
    self:CreatePresetSwatches(CLASS_COLORS, classFrame, 8)

    -- Recent colors
    local recentLabel = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recentLabel:SetPoint("TOPLEFT", classFrame, "BOTTOMLEFT", 0, -8)
    recentLabel:SetText("Recent:")
    self.RecentLabel = recentLabel

    local recentFrame = CreateFrame("Frame", nil, self)
    recentFrame:SetPoint("TOPLEFT", recentLabel, "BOTTOMLEFT", 0, -4)
    recentFrame:SetSize(280, 20)
    self.RecentFrame = recentFrame
    self.recentSwatches = {}
    self:CreateRecentSwatches()

    self:UpdateDisplay()
end

--- Create preset color swatches
-- @param colors table - Array of color presets
-- @param parent Frame - Parent frame
-- @param startIndex number - Starting index for grid positioning
function LoolibColorSwatchWithPresetsMixin:CreatePresetSwatches(colors, parent, startIndex)
    for i, colorInfo in ipairs(colors) do
        local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
        swatch:SetSize(18, 18)

        local col = (i - 1) % 8
        local xOffset = col * 20

        swatch:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, 0)

        swatch:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        swatch:SetBackdropColor(colorInfo.r, colorInfo.g, colorInfo.b, 1)
        swatch:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        -- Highlight
        local highlight = swatch:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.3)
        highlight:SetBlendMode("ADD")

        -- Tooltip
        swatch:SetScript("OnEnter", function(button)
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(colorInfo.name, 1, 1, 1)
            GameTooltip:AddLine("#" .. RGBToHex(colorInfo.r, colorInfo.g, colorInfo.b), 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Click handler
        swatch:SetScript("OnClick", function()
            self:ApplyColor(colorInfo.r, colorInfo.g, colorInfo.b, self.a)
        end)
    end
end

--- Create recent color swatches
function LoolibColorSwatchWithPresetsMixin:CreateRecentSwatches()
    for i = 1, self.maxRecentColors do
        local swatch = CreateFrame("Button", nil, self.RecentFrame, "BackdropTemplate")
        swatch:SetSize(18, 18)
        swatch:SetPoint("TOPLEFT", self.RecentFrame, "TOPLEFT", (i - 1) * 20, 0)

        swatch:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        swatch:SetBackdropColor(0.2, 0.2, 0.2, 1)
        swatch:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        -- Highlight
        local highlight = swatch:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.3)
        highlight:SetBlendMode("ADD")

        swatch:Hide()
        self.recentSwatches[i] = swatch
    end
end

--- Update recent colors display
function LoolibColorSwatchWithPresetsMixin:UpdateRecentColors()
    for i, swatch in ipairs(self.recentSwatches) do
        local color = self.recentColors[i]
        if color then
            swatch:SetBackdropColor(color.r, color.g, color.b, 1)

            -- Update tooltip
            swatch:SetScript("OnEnter", function(button)
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetText("Recent Color", 1, 1, 1)
                GameTooltip:AddLine("#" .. RGBToHex(color.r, color.g, color.b), 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)
            swatch:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            -- Click handler
            swatch:SetScript("OnClick", function()
                self:ApplyColor(color.r, color.g, color.b, self.a)
            end)

            swatch:Show()
        else
            swatch:Hide()
        end
    end
end

--- Add a color to recent colors
-- @param r number
-- @param g number
-- @param b number
function LoolibColorSwatchWithPresetsMixin:AddToRecentColors(r, g, b)
    -- Check if color already exists in recent
    for i, color in ipairs(self.recentColors) do
        if math.abs(color.r - r) < 0.01 and math.abs(color.g - g) < 0.01 and math.abs(color.b - b) < 0.01 then
            -- Move to front
            table.remove(self.recentColors, i)
            break
        end
    end

    -- Add to front
    table.insert(self.recentColors, 1, { r = r, g = g, b = b })

    -- Trim to max
    while #self.recentColors > self.maxRecentColors do
        table.remove(self.recentColors)
    end

    -- Save if we have a key
    if self.recentColorsKey then
        self:SaveRecentColors()
    end

    self:UpdateRecentColors()
end

--- Save recent colors to SavedVariables
function LoolibColorSwatchWithPresetsMixin:SaveRecentColors()
    if not self.recentColorsKey then
        return
    end

    -- Initialize SavedVariable if it doesn't exist
    if not LoolibRecentColors then
        LoolibRecentColors = {}
    end

    LoolibRecentColors[self.recentColorsKey] = self.recentColors
end

--- Load recent colors from SavedVariables
function LoolibColorSwatchWithPresetsMixin:LoadRecentColors()
    if not self.recentColorsKey then
        return
    end

    -- Initialize SavedVariable if it doesn't exist
    if not LoolibRecentColors then
        LoolibRecentColors = {}
    end

    -- Load saved colors if they exist
    local saved = LoolibRecentColors[self.recentColorsKey]
    if saved and type(saved) == "table" then
        self.recentColors = {}
        for i, color in ipairs(saved) do
            if i <= self.maxRecentColors and type(color) == "table" and color.r and color.g and color.b then
                self.recentColors[#self.recentColors + 1] = {
                    r = color.r,
                    g = color.g,
                    b = color.b,
                    a = color.a or 1
                }
            end
        end
        self:UpdateRecentColors()
    end
end

--- Set recent colors key (for SavedVariables)
-- @param key string
function LoolibColorSwatchWithPresetsMixin:SetRecentColorsKey(key)
    self.recentColorsKey = key
    self:LoadRecentColors()
end

--- Set whether alpha is enabled
-- @param hasAlpha boolean
function LoolibColorSwatchWithPresetsMixin:SetHasAlpha(hasAlpha)
    self.hasAlpha = hasAlpha

    if hasAlpha then
        self.AlphaLabel:Show()
        self.AlphaSlider:Show()
        self.AlphaSlider:SetValue(self.a * 100)
        -- Adjust height
        self:SetHeight(160)
    else
        self.AlphaLabel:Hide()
        self.AlphaSlider:Hide()
        -- Restore original height
        self:SetHeight(130)
    end
end

--- Apply a color
-- @param r number
-- @param g number
-- @param b number
-- @param a number (optional)
function LoolibColorSwatchWithPresetsMixin:ApplyColor(r, g, b, a)
    self:SetColor(r, g, b, a or self.a)
    self.HexInput:SetText(RGBToHex(r, g, b))
    if self.hasAlpha and self.AlphaSlider then
        self.AlphaSlider:SetValue((a or self.a) * 100)
    end
    self:AddToRecentColors(r, g, b)
    self:TriggerEvent("OnColorChanged", r, g, b, a or self.a)
    if self.callback then
        self.callback(r, g, b, a or self.a)
    end
end

--- Apply hex color from input
-- @param hex string
function LoolibColorSwatchWithPresetsMixin:ApplyHexColor(hex)
    if IsValidHex(hex) then
        local r, g, b = HexToRGB(hex)
        if r then
            self:ApplyColor(r, g, b, self.a)
        end
    else
        -- Reset to current color on invalid input
        self.HexInput:SetText(RGBToHex(self.r, self.g, self.b))
    end
end

--- Update the display
function LoolibColorSwatchWithPresetsMixin:UpdateDisplay()
    -- Guard against recursive calls
    if self.isUpdating then return end
    self.isUpdating = true

    -- Update base swatch (temporarily disable guard in parent call)
    self.isUpdating = nil
    LoolibColorSwatchMixin.UpdateDisplay(self)
    self.isUpdating = true

    if self.HexInput then
        self.HexInput:SetText(RGBToHex(self.r, self.g, self.b))
    end

    if self.hasAlpha and self.AlphaSlider then
        self.AlphaSlider:SetValue(self.a * 100)
    end

    self.isUpdating = nil
end

--[[--------------------------------------------------------------------
    Factory Functions
----------------------------------------------------------------------]]

--- Create a simple color swatch
-- @param parent Frame - Parent frame
-- @param options table - Optional configuration
-- @return Frame
function CreateLoolibColorSwatch(parent, options)
    options = options or {}

    local swatch = CreateFrame("Frame", nil, parent)
    LoolibMixin(swatch, LoolibColorSwatchMixin)
    swatch:OnLoad()

    if options.hasAlpha ~= nil then
        swatch:SetHasAlpha(options.hasAlpha)
    end

    if options.r or options.g or options.b then
        swatch:SetColor(options.r or 1, options.g or 1, options.b or 1, options.a or 1)
    end

    if options.callback then
        swatch:SetCallback(options.callback)
    end

    return swatch
end

--- Create a color swatch with presets
-- @param parent Frame - Parent frame
-- @param options table - Optional configuration
-- @return Frame
function CreateLoolibColorSwatchWithPresets(parent, options)
    options = options or {}

    local swatch = CreateFrame("Frame", nil, parent)
    LoolibMixin(swatch, LoolibColorSwatchWithPresetsMixin)
    swatch:OnLoad()

    if options.hasAlpha ~= nil then
        swatch:SetHasAlpha(options.hasAlpha)
    end

    if options.r or options.g or options.b then
        swatch:SetColor(options.r or 1, options.g or 1, options.b or 1, options.a or 1)
    end

    if options.callback then
        swatch:SetCallback(options.callback)
    end

    if options.recentColorsKey then
        swatch:SetRecentColorsKey(options.recentColorsKey)
    end

    return swatch
end

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

LoolibColorSwatch = {
    Create = CreateLoolibColorSwatch,
}

LoolibColorSwatchWithPresets = {
    Create = CreateLoolibColorSwatchWithPresets,
}

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local ColorSwatchModule = {
    Mixin = LoolibColorSwatchMixin,
    WithPresetsMixin = LoolibColorSwatchWithPresetsMixin,
    Create = CreateLoolibColorSwatch,
    CreateWithPresets = CreateLoolibColorSwatchWithPresets,
}

local UI = Loolib:GetOrCreateModule("UI")
UI.ColorSwatch = ColorSwatchModule
UI.CreateColorSwatch = CreateLoolibColorSwatch
UI.CreateColorSwatchWithPresets = CreateLoolibColorSwatchWithPresets

Loolib:RegisterModule("ColorSwatch", ColorSwatchModule)
