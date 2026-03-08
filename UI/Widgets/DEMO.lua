--[[--------------------------------------------------------------------
    Loolib WidgetMod - Live Demo

    Copy and paste this code into WoW's chat to see WidgetMod in action:

    /run LoadAddOn("Loolib")
    /script LOOLIB_DEMO = true; ReloadUI()

    Or execute sections individually to see specific features.
----------------------------------------------------------------------]]

if not LOOLIB_DEMO then
    return
end

local Loolib = LibStub("Loolib")

print("|cff00ff00Loolib WidgetMod Demo Starting...|r")

-- ============================================================
-- DEMO 1: Simple Panel with Tooltip
-- ============================================================

local demo1 = LoolibCreateModFrame("Frame", UIParent, "BackdropTemplate")
    :Size(250, 150)
    :Point("CENTER", -300, 200)
    :Run(function(self)
        self:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        self:SetBackdropColor(0.1, 0.1, 0.2, 0.95)
        self:SetBackdropBorderColor(0.4, 0.6, 1, 1)
    end)
    :Movable()
    :ClampedToScreen()

local title1 = demo1:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
LoolibApplyWidgetMod(title1)
title1:Point("TOP", 0, -15):Text("Demo 1: Simple Panel")

local text1 = demo1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
LoolibApplyWidgetMod(text1)
text1:Point("CENTER"):Text("Drag me around!\nI'm movable and clamped to screen.")

print("|cffadd8e6Demo 1:|r Simple movable panel created")

-- ============================================================
-- DEMO 2: Interactive Buttons
-- ============================================================

local demo2 = LoolibCreateModFrame("Frame", UIParent, "BackdropTemplate")
    :Size(250, 200)
    :Point("CENTER", 300, 200)
    :Run(function(self)
        self:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        self:SetBackdropColor(0.2, 0.1, 0.1, 0.95)
        self:SetBackdropBorderColor(1, 0.6, 0.4, 1)
    end)
    :Movable()

local title2 = demo2:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
LoolibApplyWidgetMod(title2)
title2:Point("TOP", 0, -15):Text("Demo 2: Buttons")

local clickCount = 0
local counterText = demo2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
LoolibApplyWidgetMod(counterText)
counterText:Point("TOP", 0, -50):Text("Clicks: 0")

local btn1 = LoolibCreateModFrame("Button", demo2, "UIPanelButtonTemplate")
    :Size(120, 30)
    :Point("TOP", 0, -80)
    :Text("Click Me!")
    :Tooltip({
        "Interactive Button",
        "Click to increment counter",
        "Hover shows this tooltip"
    })
    :OnClick(function(self)
        clickCount = clickCount + 1
        counterText:SetText("Clicks: " .. clickCount)
    end)
    :OnEnter(function(self)
        self:SetAlpha(0.7)
    end)
    :OnLeave(function(self)
        self:SetAlpha(1.0)
    end)

local btn2 = LoolibCreateModFrame("Button", demo2, "UIPanelButtonTemplate")
    :Size(120, 30)
    :Point("TOP", btn1, "BOTTOM", 0, -10)
    :Text("Reset")
    :Tooltip("Reset counter to zero")
    :OnClick(function()
        clickCount = 0
        counterText:SetText("Clicks: 0")
    end)

local btn3 = LoolibCreateModFrame("Button", demo2, "UIPanelButtonTemplate")
    :Size(120, 30)
    :Point("TOP", btn2, "BOTTOM", 0, -10)
    :Text("Close All")
    :Tooltip("Hide all demo frames")
    :OnClick(function()
        demo1:Hide()
        demo2:Hide()
        demo3:Hide()
        print("|cffff9900Demo frames hidden|r")
    end)

print("|cffadd8e6Demo 2:|r Interactive buttons created")

-- ============================================================
-- DEMO 3: Slider with Live Preview
-- ============================================================

local demo3 = LoolibCreateModFrame("Frame", UIParent, "BackdropTemplate")
    :Size(300, 250)
    :Point("CENTER", 0, -150)
    :Run(function(self)
        self:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        self:SetBackdropColor(0.1, 0.2, 0.1, 0.95)
        self:SetBackdropBorderColor(0.4, 1, 0.6, 1)
    end)
    :Movable()

local title3 = demo3:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
LoolibApplyWidgetMod(title3)
title3:Point("TOP", 0, -15):Text("Demo 3: Slider")

-- Preview frame
local preview = LoolibCreateModFrame("Frame", demo3, "BackdropTemplate")
    :Size(100, 100)
    :Point("TOP", 0, -50)
    :Run(function(self)
        self:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        self:SetBackdropColor(0, 0.5, 1, 0.8)
    end)

local previewText = preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
LoolibApplyWidgetMod(previewText)
previewText:Point("CENTER"):Text("Preview Box")

-- Alpha slider
local alphaSlider = LoolibCreateModFrame("Slider", demo3, "OptionsSliderTemplate")
    :Size(220, 16)
    :Point("TOP", preview, "BOTTOM", 0, -30)
    :Run(function(self)
        self:SetMinMaxValues(0, 100)
        self:SetValue(80)
        self:SetValueStep(1)
        self:SetObeyStepOnDrag(true)

        -- Create value text
        self.valueText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.valueText:SetPoint("TOP", self, "BOTTOM", 0, -5)
        self.valueText:SetText("80%")
    end)
    :OnValueChanged(function(self, value)
        preview:SetAlpha(value / 100)
        self.valueText:SetText(string.format("%.0f%%", value))
    end)

local alphaLabel = demo3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
LoolibApplyWidgetMod(alphaLabel)
alphaLabel:Point("BOTTOMLEFT", alphaSlider, "TOPLEFT", 0, 5):Text("Opacity")

-- Scale slider
local scaleSlider = LoolibCreateModFrame("Slider", demo3, "OptionsSliderTemplate")
    :Size(220, 16)
    :Point("TOP", alphaSlider, "BOTTOM", 0, -35)
    :Run(function(self)
        self:SetMinMaxValues(50, 200)
        self:SetValue(100)
        self:SetValueStep(5)
        self:SetObeyStepOnDrag(true)

        self.valueText = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.valueText:SetPoint("TOP", self, "BOTTOM", 0, -5)
        self.valueText:SetText("100%")
    end)
    :OnValueChanged(function(self, value)
        preview:SetScale(value / 100)
        self.valueText:SetText(string.format("%.0f%%", value))
    end)

local scaleLabel = demo3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
LoolibApplyWidgetMod(scaleLabel)
scaleLabel:Point("BOTTOMLEFT", scaleSlider, "TOPLEFT", 0, 5):Text("Scale")

print("|cffadd8e6Demo 3:|r Slider controls created")

-- ============================================================
-- Summary
-- ============================================================

print("|cff00ff00All demos created!|r")
print("|cffadd8e6Commands:|r")
print("  /run demo1:Show() - Show simple panel")
print("  /run demo2:Show() - Show button demo")
print("  /run demo3:Show() - Show slider demo")
print("  /run demo1:Hide(); demo2:Hide(); demo3:Hide() - Hide all")
print("|cffadd8e6Features demonstrated:|r")
print("  ✓ Fluent API chaining")
print("  ✓ Size, Point, Alpha, Scale")
print("  ✓ Tooltip system (single & multi-line)")
print("  ✓ OnClick, OnEnter, OnLeave handlers")
print("  ✓ Movable frames")
print("  ✓ Run() for inline configuration")
print("  ✓ Live value updates with sliders")

-- Store references globally for easy access
LOOLIB_DEMO_FRAMES = {
    demo1 = demo1,
    demo2 = demo2,
    demo3 = demo3,
}
