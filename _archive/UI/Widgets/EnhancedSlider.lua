--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    EnhancedSlider - Slider Widget with Labels and Value Display

    Enhanced slider widget with value display, min/max labels, step values,
    and fluent API. Builds on WoW's Slider widget with modern conveniences.

    Usage:
        local slider = LoolibCreateEnhancedSlider(parent)
            :Size(200, 20)
            :Point("CENTER")
            :Title("Volume")
            :Range(0, 100)
            :Step(5)
            :SetTo(50)
            :ShowValue("%d%%")
            :ShowLabels("Quiet", "Loud")
            :OnChange(function(self, value, userInput)
                SetVolume(value / 100)
            end)
            :Tooltip("Adjust the volume level")
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local LoolibMixin = assert(Loolib.Mixin, "Loolib.Mixin is required for EnhancedSlider")

--[[--------------------------------------------------------------------
    LoolibEnhancedSliderMixin
----------------------------------------------------------------------]]

---@class LoolibEnhancedSliderMixin : Frame
local LoolibEnhancedSliderMixin = {}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function LoolibEnhancedSliderMixin:OnLoad()
    -- Internal state
    self._minValue = 0
    self._maxValue = 100
    self._step = 1
    self._value = 0
    self._valueFormat = "%d"
    self._showLabels = false
    self._showValue = false
    self._onChangeCallback = nil
    self._minLabelText = nil
    self._maxLabelText = nil

    -- Create child elements
    self:_CreateElements()

    -- Set up slider scripts
    self:SetScript("OnValueChanged", function(self, value, userInput)
        self:_OnValueChanged(value, userInput)
    end)

    -- Mouse wheel support
    self:SetScript("OnMouseWheel", function(self, delta)
        local newValue = self:GetValue() + (delta * self._step)
        self:SetValue(newValue)
    end)

    -- Enable mouse wheel
    self:EnableMouseWheel(true)
end

function LoolibEnhancedSliderMixin:_CreateElements()
    -- Value display (above slider)
    self.valueText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.valueText:SetPoint("BOTTOM", self, "TOP", 0, 2)
    self.valueText:Hide()

    -- Min label (left side for horizontal, bottom for vertical)
    self.minLabel = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.minLabel:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
    self.minLabel:Hide()

    -- Max label (right side for horizontal, top for vertical)
    self.maxLabel = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.maxLabel:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
    self.maxLabel:Hide()

    -- Title/label (above value or slider)
    self.titleText = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.titleText:SetPoint("BOTTOM", self, "TOP", 0, 14)
    self.titleText:Hide()
end

-- ============================================================
-- CONFIGURATION (Fluent API - all return self)
-- ============================================================

--- Set value range
-- @param min number - Minimum value
-- @param max number - Maximum value
-- @return self
function LoolibEnhancedSliderMixin:Range(min, max)
    self._minValue = min
    self._maxValue = max
    self:SetMinMaxValues(min, max)
    self:_UpdateLabels()
    return self
end

--- Get current range
-- @return number min, number max
function LoolibEnhancedSliderMixin:GetRange()
    return self._minValue, self._maxValue
end

--- Set step increment
-- @param step number - Step value
-- @return self
function LoolibEnhancedSliderMixin:Step(step)
    self._step = step
    self:SetValueStep(step)
    self:SetObeyStepOnDrag(true)
    return self
end

--- Get current step value
-- @return number
function LoolibEnhancedSliderMixin:GetStep()
    return self._step
end

--- Set current value
-- @param value number - Value to set
-- @return self
function LoolibEnhancedSliderMixin:SetTo(value)
    self._value = value
    self:SetValue(value)
    return self
end

--- Get current value
-- @return number
function LoolibEnhancedSliderMixin:GetTo()
    return self:GetValue()
end

--- Set change callback
-- @param callback function - Function(self, value, userInput)
-- @return self
function LoolibEnhancedSliderMixin:OnChange(callback)
    self._onChangeCallback = callback
    return self
end

--- Show value display above slider
-- @param formatString string|nil - Printf format string (default "%d")
-- @return self
function LoolibEnhancedSliderMixin:ShowValue(formatString)
    self._showValue = true
    self._valueFormat = formatString or "%d"
    self.valueText:Show()

    -- Adjust title position if showing value
    if self.titleText:IsShown() then
        self.titleText:ClearAllPoints()
        self.titleText:SetPoint("BOTTOM", self.valueText, "TOP", 0, 2)
    end

    self:_UpdateValueDisplay()
    return self
end

--- Hide value display
-- @return self
function LoolibEnhancedSliderMixin:HideValue()
    self._showValue = false
    self.valueText:Hide()

    -- Reset title position
    if self.titleText:IsShown() then
        self.titleText:ClearAllPoints()
        self.titleText:SetPoint("BOTTOM", self, "TOP", 0, 14)
    end

    return self
end

--- Show min/max labels below slider
-- @param minText string|nil - Text for min (default: min value)
-- @param maxText string|nil - Text for max (default: max value)
-- @return self
function LoolibEnhancedSliderMixin:ShowLabels(minText, maxText)
    self._showLabels = true
    self._minLabelText = minText
    self._maxLabelText = maxText
    self.minLabel:Show()
    self.maxLabel:Show()
    self:_UpdateLabels()
    return self
end

--- Hide min/max labels
-- @return self
function LoolibEnhancedSliderMixin:HideLabels()
    self._showLabels = false
    self.minLabel:Hide()
    self.maxLabel:Hide()
    return self
end

--- Set slider title/label
-- @param title string - Title text
-- @return self
function LoolibEnhancedSliderMixin:Title(title)
    self.titleText:SetText(title)
    self.titleText:Show()

    -- Position title above value if value is shown
    if self._showValue and self.valueText:IsShown() then
        self.titleText:ClearAllPoints()
        self.titleText:SetPoint("BOTTOM", self.valueText, "TOP", 0, 2)
    end

    return self
end

--- Hide title
-- @return self
function LoolibEnhancedSliderMixin:HideTitle()
    self.titleText:Hide()
    return self
end

--- Set value format string
-- @param formatString string - Printf format (e.g., "%d%%", "%.1f", "%d seconds")
-- @return self
function LoolibEnhancedSliderMixin:ValueFormat(formatString)
    self._valueFormat = formatString
    self:_UpdateValueDisplay()
    return self
end

--- Enable or disable the slider
-- @param enabled boolean - True to enable, false to disable
-- @return self
function LoolibEnhancedSliderMixin:SetEnabled(enabled)
    if enabled then
        self:Enable()
        self:SetAlpha(1)
    else
        self:Disable()
        self:SetAlpha(0.5)
    end
    return self
end

--- Set tooltip text
-- Uses HookScript to avoid clobbering existing OnEnter/OnLeave handlers.
-- @param text string|table - Single string or {title, line1, line2, ...}
-- @return self
function LoolibEnhancedSliderMixin:Tooltip(text)
    self.tooltipText = text

    -- INTERNAL: Only hook once; subsequent calls just update tooltipText
    if not self._tooltipHooked then
        self._tooltipHooked = true

        self:HookScript("OnEnter", function(frame)
            if not frame.tooltipText then return end

            GameTooltip:SetOwner(frame, frame.tooltipAnchor or "ANCHOR_RIGHT")

            if type(frame.tooltipText) == "table" then
                -- Multi-line tooltip
                GameTooltip:SetText(frame.tooltipText[1] or "", 1, 1, 1, 1, true)
                for i = 2, #frame.tooltipText do
                    GameTooltip:AddLine(frame.tooltipText[i], 1, 1, 1, true)
                end
            else
                -- Single line tooltip
                GameTooltip:SetText(frame.tooltipText, 1, 1, 1, 1, true)
            end

            GameTooltip:Show()
        end)

        self:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return self
end

--- Set tooltip anchor point
-- @param anchor string - Anchor point (e.g., "ANCHOR_RIGHT", "ANCHOR_TOP")
-- @return self
function LoolibEnhancedSliderMixin:TooltipAnchor(anchor)
    self.tooltipAnchor = anchor or "ANCHOR_RIGHT"
    return self
end

--- Set font for all text elements
-- @param font string - Font path
-- @param size number|nil - Font size
-- @param flags string|nil - Font flags
-- @return self
function LoolibEnhancedSliderMixin:Font(font, size, flags)
    if self.valueText then
        self.valueText:SetFont(font, size or 10, flags or "")
    end
    if self.minLabel then
        self.minLabel:SetFont(font, size or 10, flags or "")
    end
    if self.maxLabel then
        self.maxLabel:SetFont(font, size or 10, flags or "")
    end
    if self.titleText then
        local titleFont, titleSize = self.titleText:GetFont()
        self.titleText:SetFont(font, titleSize or 12, flags or "")
    end
    return self
end

--- Set font size for all text elements
-- @param size number - Font size
-- @return self
function LoolibEnhancedSliderMixin:FontSize(size)
    if self.valueText then
        local font, _, flags = self.valueText:GetFont()
        self.valueText:SetFont(font, size, flags)
    end
    if self.minLabel then
        local font, _, flags = self.minLabel:GetFont()
        self.minLabel:SetFont(font, size, flags)
    end
    if self.maxLabel then
        local font, _, flags = self.maxLabel:GetFont()
        self.maxLabel:SetFont(font, size, flags)
    end
    if self.titleText then
        local font, _, flags = self.titleText:GetFont()
        self.titleText:SetFont(font, size + 2, flags) -- Title slightly larger
    end
    return self
end

--- Set text color for labels
-- @param r number - Red (0-1)
-- @param g number - Green (0-1)
-- @param b number - Blue (0-1)
-- @param a number|nil - Alpha (0-1)
-- @return self
function LoolibEnhancedSliderMixin:TextColor(r, g, b, a)
    if self.valueText then
        self.valueText:SetTextColor(r, g, b, a or 1)
    end
    if self.minLabel then
        self.minLabel:SetTextColor(r, g, b, a or 1)
    end
    if self.maxLabel then
        self.maxLabel:SetTextColor(r, g, b, a or 1)
    end
    return self
end

-- ============================================================
-- INTERNAL HANDLERS
-- ============================================================

-- INTERNAL: Called by OnValueChanged script. Wraps callback in pcall so an
-- error in consumer code does not stale the value display or halt the handler.
function LoolibEnhancedSliderMixin:_OnValueChanged(value, userInput)
    self._value = value
    self:_UpdateValueDisplay()

    if self._onChangeCallback then
        local ok, err = pcall(self._onChangeCallback, self, value, userInput)
        if not ok then
            -- Surface the error without halting the slider
            geterrorhandler()(("LoolibEnhancedSlider: OnChange callback error: %s"):format(tostring(err)))
        end
    end
end

-- INTERNAL: Updates the value text above the slider.  Wraps string.format in
-- pcall so a format/value type mismatch (e.g. "%d" with a float NaN) does not
-- throw; falls back to tostring on failure.
function LoolibEnhancedSliderMixin:_UpdateValueDisplay()
    if self._showValue and self.valueText then
        local ok, formatted = pcall(string.format, self._valueFormat, self._value)
        if not ok then
            formatted = tostring(self._value)
        end
        self.valueText:SetText(formatted)
    end
end

function LoolibEnhancedSliderMixin:_UpdateLabels()
    if self._showLabels then
        local minText = self._minLabelText or tostring(self._minValue)
        local maxText = self._maxLabelText or tostring(self._maxValue)
        self.minLabel:SetText(minText)
        self.maxLabel:SetText(maxText)
    end
end

-- ============================================================
-- SIZE/POSITION (inherit from WidgetMod if available)
-- ============================================================

function LoolibEnhancedSliderMixin:Size(width, height)
    self:SetSize(width, height or 16)
    return self
end

function LoolibEnhancedSliderMixin:Point(...)
    self:SetPoint(...)
    return self
end

function LoolibEnhancedSliderMixin:ClearPoints()
    self:ClearAllPoints()
    return self
end

function LoolibEnhancedSliderMixin:NewPoint(...)
    self:ClearAllPoints()
    return self:Point(...)
end

-- ============================================================
-- ADDITIONAL UTILITY METHODS
-- ============================================================

--- Reset slider to default value
-- Uses HookScript to avoid clobbering existing OnMouseDown/OnMouseUp handlers.
-- @param defaultValue number - Default value to reset to
-- @return self
function LoolibEnhancedSliderMixin:SetDefault(defaultValue)
    self._defaultValue = defaultValue

    -- INTERNAL: Only hook once; subsequent calls just update _defaultValue
    if not self._defaultHooked then
        self._defaultHooked = true

        self:HookScript("OnMouseDown", function(frame, button)
            if button == "RightButton" and frame._defaultValue then
                frame.InResetState = frame._defaultValue
                frame:SetValue(frame._defaultValue)
            end
        end)

        self:HookScript("OnMouseUp", function(frame, button)
            if button == "RightButton" then
                frame.InResetState = nil
            end
        end)
    end

    return self
end

--- Set orientation (horizontal or vertical)
-- @param orientation string - "HORIZONTAL" or "VERTICAL"
-- @return self
function LoolibEnhancedSliderMixin:Orientation(orientation)
    self:SetOrientation(orientation)

    -- Adjust label positions for vertical sliders
    if orientation == "VERTICAL" then
        self.minLabel:ClearAllPoints()
        self.minLabel:SetPoint("TOP", self, "BOTTOM", 0, -2)
        self.maxLabel:ClearAllPoints()
        self.maxLabel:SetPoint("BOTTOM", self, "TOP", 0, 2)
        self.valueText:ClearAllPoints()
        self.valueText:SetPoint("LEFT", self, "RIGHT", 4, 0)
    else
        self.minLabel:ClearAllPoints()
        self.minLabel:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        self.maxLabel:ClearAllPoints()
        self.maxLabel:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
        self.valueText:ClearAllPoints()
        self.valueText:SetPoint("BOTTOM", self, "TOP", 0, 2)
    end

    return self
end

--- Set whether to obey step on drag
-- @param obey boolean - True to obey step while dragging
-- @return self
function LoolibEnhancedSliderMixin:ObeyStepOnDrag(obey)
    self:SetObeyStepOnDrag(obey)
    return self
end

--- Execute a function with self and return self
-- @param func function - Function to execute (receives self, ...)
-- @param ... - Additional arguments to pass
-- @return self
function LoolibEnhancedSliderMixin:Run(func, ...)
    func(self, ...)
    return self
end

-- ============================================================
-- FACTORY FUNCTION
-- ============================================================

--- Create an enhanced slider
-- @param parent Frame - Parent frame
-- @param name string|nil - Optional global name
-- @param template string|nil - Optional template (defaults to modern slider)
-- @return Slider
local function LoolibCreateEnhancedSlider(parent, name, template)
    local slider = CreateFrame("Slider", name, parent, template or "MinimalSliderTemplate")

    -- Apply mixins
    LoolibMixin(slider, LoolibEnhancedSliderMixin)

    -- Also apply WidgetMod if available
    local WidgetMod = Loolib:GetModule("WidgetMod")
    if WidgetMod and WidgetMod.Mixin then
        LoolibMixin(slider, WidgetMod.Mixin)
    end

    slider:OnLoad()

    -- Default appearance
    slider:SetSize(150, 16)
    slider:SetOrientation("HORIZONTAL")

    return slider
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib:RegisterModule("Widgets.EnhancedSlider", {
    Mixin = LoolibEnhancedSliderMixin,
    Create = LoolibCreateEnhancedSlider,
})
