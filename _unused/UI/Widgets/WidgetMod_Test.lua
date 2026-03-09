--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    WidgetMod Test Suite

    This file demonstrates and tests the WidgetMod fluent API.
    Load this file after WidgetMod.lua to run tests.
----------------------------------------------------------------------]]

-- Only run tests if explicitly enabled
if not LOOLIB_RUN_TESTS then
    return
end

local Loolib = LibStub("Loolib")
local WidgetMod = Loolib:GetModule("WidgetMod")

-- Test frame for demonstrations
local TestFrame = CreateFrame("Frame", "LoolibWidgetModTestFrame", UIParent)
TestFrame:SetSize(400, 300)
TestFrame:SetPoint("CENTER")

-- Create a backdrop
if BackdropTemplateMixin then
    Mixin(TestFrame, BackdropTemplateMixin)
    TestFrame:OnBackdropLoaded()
end

TestFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
TestFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)

-- Title
local title = TestFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -15)
title:SetText("WidgetMod Test Suite")

print("Loolib WidgetMod: Running tests...")

-- ============================================================
-- TEST 1: Basic Chaining
-- ============================================================

local test1 = LoolibCreateModFrame("Frame", TestFrame)
    :Size(150, 40)
    :Point("TOPLEFT", 20, -50)
    :Alpha(1.0)

if test1:GetWidth() == 150 and test1:GetHeight() == 40 then
    print("✓ Test 1: Basic chaining (Size, Point, Alpha)")
else
    print("✗ Test 1 FAILED")
end

-- ============================================================
-- TEST 2: Tooltip System
-- ============================================================

local test2Button = LoolibCreateModFrame("Button", TestFrame, "UIPanelButtonTemplate")
    :Size(120, 30)
    :Point("TOPLEFT", test1, "BOTTOMLEFT", 0, -10)
    :Text("Hover for Tooltip")
    :Tooltip("This is a single-line tooltip")

if test2Button.tooltipText == "This is a single-line tooltip" then
    print("✓ Test 2: Single-line tooltip")
else
    print("✗ Test 2 FAILED")
end

-- ============================================================
-- TEST 3: Multi-line Tooltip
-- ============================================================

local test3Button = LoolibCreateModFrame("Button", TestFrame, "UIPanelButtonTemplate")
    :Size(120, 30)
    :Point("TOPLEFT", test2Button, "BOTTOMLEFT", 0, -10)
    :Text("Multi-line Tooltip")
    :Tooltip({
        "Multi-line Tooltip Title",
        "This is line 1",
        "This is line 2",
        "This is line 3",
    })

if test3Button.tooltipLines and #test3Button.tooltipLines == 4 then
    print("✓ Test 3: Multi-line tooltip")
else
    print("✗ Test 3 FAILED")
end

-- ============================================================
-- TEST 4: Script Handlers
-- ============================================================

local test4Clicks = 0
local test4Button = LoolibCreateModFrame("Button", TestFrame, "UIPanelButtonTemplate")
    :Size(120, 30)
    :Point("TOPLEFT", test3Button, "BOTTOMLEFT", 0, -10)
    :Text("Click Me")
    :OnClick(function(self, button)
        test4Clicks = test4Clicks + 1
    end)

-- Simulate click
test4Button:Click()

if test4Clicks == 1 then
    print("✓ Test 4: OnClick handler")
else
    print("✗ Test 4 FAILED")
end

-- ============================================================
-- TEST 5: Run() Method
-- ============================================================

local test5 = LoolibCreateModFrame("Frame", TestFrame)
    :Size(100, 100)
    :Point("TOPRIGHT", -20, -50)
    :Run(function(frame)
        frame.customProperty = "test_value"
        frame.customNumber = 42
    end)

if test5.customProperty == "test_value" and test5.customNumber == 42 then
    print("✓ Test 5: Run() method for custom configuration")
else
    print("✗ Test 5 FAILED")
end

-- ============================================================
-- TEST 6: Point() Argument Patterns
-- ============================================================

local anchor = LoolibCreateModFrame("Frame", TestFrame)
    :Size(50, 50)
    :Point("BOTTOMLEFT", 20, 20)

local test6a = LoolibCreateModFrame("Frame", TestFrame)
    :Size(30, 30)
    :Point("CENTER") -- Pattern: single point

local test6b = LoolibCreateModFrame("Frame", TestFrame)
    :Size(30, 30)
    :Point("BOTTOMLEFT", 100, 100) -- Pattern: point, x, y

local test6c = LoolibCreateModFrame("Frame", TestFrame)
    :Size(30, 30)
    :Point("TOPLEFT", anchor, 5, -5) -- Pattern: point, frame, x, y

local test6d = LoolibCreateModFrame("Frame", TestFrame)
    :Size(30, 30)
    :Point("BOTTOMRIGHT", anchor, "TOPLEFT", -5, 5) -- Pattern: full form

print("✓ Test 6: Point() argument patterns (manual verification required)")

-- ============================================================
-- TEST 7: NewPoint() - Clear and Set
-- ============================================================

local test7 = LoolibCreateModFrame("Frame", TestFrame)
    :Point("CENTER")
    :Point("TOPLEFT", 10, -10)
    :Point("BOTTOMRIGHT", -10, 10)

local numPoints = test7:GetNumPoints()

test7:NewPoint("CENTER")

if test7:GetNumPoints() == 1 then
    print("✓ Test 7: NewPoint() clears all points")
else
    print("✗ Test 7 FAILED (expected 1 point, got " .. test7:GetNumPoints() .. ")")
end

-- ============================================================
-- TEST 8: Shown() Conditional Visibility
-- ============================================================

local test8 = LoolibCreateModFrame("Frame", TestFrame)
    :Size(50, 50)
    :Point("CENTER", 0, -100)
    :Shown(false)

if not test8:IsShown() then
    test8:Shown(true)
    if test8:IsShown() then
        print("✓ Test 8: Shown() conditional visibility")
    else
        print("✗ Test 8 FAILED (show)")
    end
else
    print("✗ Test 8 FAILED (hide)")
end

-- ============================================================
-- TEST 9: Apply to Existing Frame
-- ============================================================

local existingFrame = CreateFrame("Frame", nil, TestFrame)
existingFrame:SetSize(60, 60)

LoolibApplyWidgetMod(existingFrame)
existingFrame:Point("BOTTOMRIGHT", -20, 20):Alpha(0.7)

if existingFrame:GetAlpha() == 0.7 then
    print("✓ Test 9: Apply WidgetMod to existing frame")
else
    print("✗ Test 9 FAILED")
end

-- ============================================================
-- TEST 10: OnShow with skipFirstRun
-- ============================================================

local test10ShowCount = 0
local test10 = LoolibCreateModFrame("Frame", TestFrame)
    :Size(50, 50)
    :Point("TOP", 0, -50)
    :OnShow(function()
        test10ShowCount = test10ShowCount + 1
    end, true) -- skipFirstRun = true

-- Frame is already shown, but shouldn't have run handler yet
if test10ShowCount == 0 then
    test10:Hide()
    test10:Show()
    if test10ShowCount == 1 then
        print("✓ Test 10: OnShow with skipFirstRun")
    else
        print("✗ Test 10 FAILED (wrong count: " .. test10ShowCount .. ")")
    end
else
    print("✗ Test 10 FAILED (ran on first show)")
end

-- ============================================================
-- Summary
-- ============================================================

print("Loolib WidgetMod: Test suite complete")
print("Visual verification: /run LoolibWidgetModTestFrame:Show()")

-- Hide test frame by default
TestFrame:Hide()
