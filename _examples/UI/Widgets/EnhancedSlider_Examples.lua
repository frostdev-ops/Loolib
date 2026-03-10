--[[--------------------------------------------------------------------
    EnhancedSlider - Usage Examples

    This file demonstrates various uses of the LoolibEnhancedSlider widget.
    These examples can be used for testing and as a reference.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Wait for PLAYER_LOGIN to ensure UI is ready
local exampleFrame = CreateFrame("Frame")
exampleFrame:RegisterEvent("PLAYER_LOGIN")
exampleFrame:SetScript("OnEvent", function()
    -- Create a container frame for examples
    local container = CreateFrame("Frame", "LoolibSliderExamples", UIParent, "BasicFrameTemplateWithInset")
    container:SetSize(400, 500)
    container:SetPoint("CENTER")
    container:SetFrameStrata("DIALOG")
    container.title = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    container.title:SetPoint("TOP", container.TitleBg, "TOP", 0, -3)
    container.title:SetText("Loolib Enhanced Slider Examples")
    container:Hide()

    -- Slash command to show examples
    SLASH_SLIDEREXAMPLES1 = "/sliderexamples"
    SlashCmdList["SLIDEREXAMPLES"] = function()
        if container:IsShown() then
            container:Hide()
        else
            container:Show()
        end
    end

    local yOffset = -30

    -- ============================================================
    -- EXAMPLE 1: Basic slider with value display
    -- ============================================================
    local slider1 = LoolibCreateEnhancedSlider(container)
        :Size(300, 20)
        :Point("TOP", container, "TOP", 0, yOffset)
        :Title("Basic Slider")
        :Range(0, 100)
        :Step(1)
        :SetTo(50)
        :ShowValue("%d")
        :ShowLabels()
        :OnChange(function(self, value, userInput)
            if userInput then
                print("Slider 1 changed to:", value)
            end
        end)
        :Tooltip("A basic slider with value display")

    yOffset = yOffset - 70

    -- ============================================================
    -- EXAMPLE 2: Percentage slider
    -- ============================================================
    local slider2 = LoolibCreateEnhancedSlider(container)
        :Size(300, 20)
        :Point("TOP", container, "TOP", 0, yOffset)
        :Title("Volume Control")
        :Range(0, 100)
        :Step(5)
        :SetTo(75)
        :ShowValue("%d%%")
        :ShowLabels("Mute", "Max")
        :OnChange(function(self, value, userInput)
            if userInput then
                print(string.format("Volume set to %d%%", value))
            end
        end)
        :Tooltip({
            "Volume Control",
            "Adjust the master volume",
            "Right-click to reset to default"
        })
        :SetDefault(75)

    yOffset = yOffset - 70

    -- ============================================================
    -- EXAMPLE 3: Decimal slider with custom format
    -- ============================================================
    local slider3 = LoolibCreateEnhancedSlider(container)
        :Size(300, 20)
        :Point("TOP", container, "TOP", 0, yOffset)
        :Title("Damage Multiplier")
        :Range(0.5, 2.0)
        :Step(0.1)
        :SetTo(1.0)
        :ShowValue("%.1fx")
        :ShowLabels("0.5x", "2.0x")
        :OnChange(function(self, value, userInput)
            if userInput then
                print(string.format("Damage multiplier: %.1fx", value))
            end
        end)
        :Tooltip("Adjust damage multiplier\n(0.5x to 2.0x)")

    yOffset = yOffset - 70

    -- ============================================================
    -- EXAMPLE 4: Time slider with custom labels
    -- ============================================================
    local slider4 = LoolibCreateEnhancedSlider(container)
        :Size(300, 20)
        :Point("TOP", container, "TOP", 0, yOffset)
        :Title("Countdown Timer")
        :Range(1, 60)
        :Step(1)
        :SetTo(30)
        :ShowValue("%d seconds")
        :ShowLabels("1 sec", "1 min")
        :OnChange(function(self, value, userInput)
            if userInput then
                print(string.format("Timer set to %d seconds", value))
            end
        end)
        :Tooltip("Set countdown duration")

    yOffset = yOffset - 70

    -- ============================================================
    -- EXAMPLE 5: Slider without labels or value display
    -- ============================================================
    local slider5 = LoolibCreateEnhancedSlider(container)
        :Size(300, 20)
        :Point("TOP", container, "TOP", 0, yOffset)
        :Title("Simple Slider")
        :Range(1, 10)
        :Step(1)
        :SetTo(5)
        :OnChange(function(self, value, userInput)
            if userInput then
                print("Simple slider:", value)
            end
        end)
        :Tooltip("A minimal slider without labels")

    yOffset = yOffset - 60

    -- ============================================================
    -- EXAMPLE 6: Disabled slider
    -- ============================================================
    local slider6 = LoolibCreateEnhancedSlider(container)
        :Size(300, 20)
        :Point("TOP", container, "TOP", 0, yOffset)
        :Title("Disabled Slider")
        :Range(0, 100)
        :Step(10)
        :SetTo(30)
        :ShowValue("%d")
        :ShowLabels()
        :SetEnabled(false)
        :Tooltip("This slider is disabled")

    yOffset = yOffset - 70

    -- ============================================================
    -- Example: Toggle slider 6 enable/disable
    -- ============================================================
    local toggleButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    toggleButton:SetSize(150, 25)
    toggleButton:SetPoint("TOP", container, "TOP", 0, yOffset)
    toggleButton:SetText("Toggle Last Slider")
    toggleButton:SetScript("OnClick", function()
        local isEnabled = slider6:IsEnabled()
        slider6:SetEnabled(not isEnabled)
        print("Slider 6 is now:", not isEnabled and "enabled" or "disabled")
    end)

    -- ============================================================
    -- Information text
    -- ============================================================
    local infoText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("BOTTOM", container, "BOTTOM", 0, 10)
    infoText:SetText("Try all sliders! Use mouse wheel to adjust.\nRight-click to reset (where applicable).")
    infoText:SetTextColor(0.8, 0.8, 0.8)

    print("EnhancedSlider examples loaded! Use /sliderexamples to toggle the demo window.")
end)

--[[--------------------------------------------------------------------
    Additional Usage Patterns
----------------------------------------------------------------------]]

--[[ EXAMPLE: Vertical slider
local vSlider = LoolibCreateEnhancedSlider(parent)
    :Size(20, 200)
    :Point("LEFT", 50, 0)
    :Orientation("VERTICAL")
    :Range(0, 100)
    :SetTo(50)
    :ShowValue("%d")
]]

--[[ EXAMPLE: Slider with custom font
local customSlider = LoolibCreateEnhancedSlider(parent)
    :Size(250, 20)
    :Point("CENTER")
    :Title("Custom Font")
    :Range(1, 100)
    :SetTo(50)
    :ShowValue("%d")
    :ShowLabels()
    :Font("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    :TextColor(1, 0.8, 0) -- Gold text
]]

--[[ EXAMPLE: Slider with dynamic value format
local formatSlider = LoolibCreateEnhancedSlider(parent)
    :Size(250, 20)
    :Point("CENTER")
    :Range(0, 3)
    :Step(1)
    :SetTo(1)
    :ShowValue()
    :OnChange(function(self, value, userInput)
        local formats = {
            [0] = "Off",
            [1] = "Low",
            [2] = "Medium",
            [3] = "High"
        }
        self.valueText:SetText(formats[value] or tostring(value))
    end)
]]

--[[ EXAMPLE: Linked sliders (RGB color picker)
local rSlider = LoolibCreateEnhancedSlider(parent)
    :Size(200, 20)
    :Point("TOP", 0, -50)
    :Title("Red")
    :Range(0, 255)
    :Step(1)
    :SetTo(255)
    :ShowValue("%d")
    :OnChange(function(self, value, userInput)
        if userInput then
            local r, g, b = value/255, gSlider:GetValue()/255, bSlider:GetValue()/255
            colorPreview:SetColorTexture(r, g, b)
        end
    end)

local gSlider = LoolibCreateEnhancedSlider(parent)
    :Size(200, 20)
    :Point("TOP", rSlider, "BOTTOM", 0, -40)
    :Title("Green")
    :Range(0, 255)
    :Step(1)
    :SetTo(128)
    :ShowValue("%d")
    :OnChange(function(self, value, userInput)
        if userInput then
            local r, g, b = rSlider:GetValue()/255, value/255, bSlider:GetValue()/255
            colorPreview:SetColorTexture(r, g, b)
        end
    end)

local bSlider = LoolibCreateEnhancedSlider(parent)
    :Size(200, 20)
    :Point("TOP", gSlider, "BOTTOM", 0, -40)
    :Title("Blue")
    :Range(0, 255)
    :Step(1)
    :SetTo(64)
    :ShowValue("%d")
    :OnChange(function(self, value, userInput)
        if userInput then
            local r, g, b = rSlider:GetValue()/255, gSlider:GetValue()/255, value/255
            colorPreview:SetColorTexture(r, g, b)
        end
    end)

local colorPreview = parent:CreateTexture(nil, "OVERLAY")
colorPreview:SetSize(50, 50)
colorPreview:SetPoint("LEFT", rSlider, "RIGHT", 20, 0)
colorPreview:SetColorTexture(1, 0.5, 0.25)
]]
