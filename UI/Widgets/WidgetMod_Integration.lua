--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    WidgetMod Integration Verification

    This file demonstrates integration with Loolib's other systems.
    Run this to verify WidgetMod works correctly with the framework.
----------------------------------------------------------------------]]

-- Only run if explicitly enabled
if not LOOLIB_INTEGRATION_TEST then
    return
end

local Loolib = LibStub("Loolib")

print("==========================================")
print("Loolib WidgetMod Integration Test")
print("==========================================")

-- ============================================================
-- Test 1: Module Registration
-- ============================================================

local WidgetMod = Loolib:GetModule("WidgetMod")

if WidgetMod then
    print("✓ Module registered successfully")
    print("  - Mixin:", WidgetMod.Mixin ~= nil)
    print("  - Apply:", WidgetMod.Apply ~= nil)
    print("  - Create:", WidgetMod.Create ~= nil)
else
    print("✗ Module registration FAILED")
    return
end

-- ============================================================
-- Test 2: Global Functions Available
-- ============================================================

if type(LoolibApplyWidgetMod) == "function" then
    print("✓ LoolibApplyWidgetMod global function available")
else
    print("✗ LoolibApplyWidgetMod NOT available")
end

if type(LoolibCreateModFrame) == "function" then
    print("✓ LoolibCreateModFrame global function available")
else
    print("✗ LoolibCreateModFrame NOT available")
end

-- ============================================================
-- Test 3: Mixin Dependencies
-- ============================================================

if type(LoolibMixin) == "function" then
    print("✓ LoolibMixin dependency available")
else
    print("✗ LoolibMixin dependency MISSING")
    return
end

-- ============================================================
-- Test 4: Basic Frame Creation
-- ============================================================

local success, testFrame = pcall(function()
    return LoolibCreateModFrame("Frame", UIParent)
end)

if success and testFrame then
    print("✓ Basic frame creation successful")

    -- Verify mixin methods exist
    local methods = {
        "Size", "Width", "Height", "Point", "NewPoint", "ClearPoints",
        "Alpha", "Scale", "Shown", "ShowFrame", "HideFrame",
        "OnClick", "OnEnter", "OnLeave", "OnShow", "OnHide",
        "Tooltip", "TooltipAnchor", "Run", "EnableWidget", "DisableWidget",
    }

    local missingMethods = {}
    for _, method in ipairs(methods) do
        if type(testFrame[method]) ~= "function" then
            table.insert(missingMethods, method)
        end
    end

    if #missingMethods == 0 then
        print("✓ All mixin methods available")
    else
        print("✗ Missing methods:", table.concat(missingMethods, ", "))
    end

    -- Clean up
    testFrame:Hide()
else
    print("✗ Frame creation FAILED:", testFrame)
end

-- ============================================================
-- Test 5: Apply to Existing Frame
-- ============================================================

local existingFrame = CreateFrame("Frame", nil, UIParent)
local applySuccess = pcall(function()
    LoolibApplyWidgetMod(existingFrame)
end)

if applySuccess and type(existingFrame.Size) == "function" then
    print("✓ Apply to existing frame successful")
    existingFrame:Hide()
else
    print("✗ Apply to existing frame FAILED")
end

-- ============================================================
-- Test 6: Chaining Returns Self
-- ============================================================

local chainTest = LoolibCreateModFrame("Frame", UIParent)
local result1 = chainTest:Size(100, 100)
local result2 = result1:Point("CENTER")
local result3 = result2:Alpha(0.5)

if chainTest == result1 and result1 == result2 and result2 == result3 then
    print("✓ Method chaining returns self correctly")
    chainTest:Hide()
else
    print("✗ Method chaining BROKEN")
end

-- ============================================================
-- Test 7: Integration with FrameUtil (if available)
-- ============================================================

local FrameUtil = Loolib:GetModule("FrameUtil")
if FrameUtil then
    local integrationFrame = LoolibCreateModFrame("Frame", UIParent)
        :Size(200, 200)
        :Point("CENTER")
        :Run(function(self)
            -- Use FrameUtil methods
            FrameUtil.MakeMovable(self)
        end)

    if integrationFrame:IsMovable() then
        print("✓ Integration with FrameUtil successful")
    else
        print("⚠ FrameUtil integration may have issues")
    end

    integrationFrame:Hide()
else
    print("⚠ FrameUtil not available (optional)")
end

-- ============================================================
-- Test 8: Point() Argument Patterns
-- ============================================================

local pointTestFrame = LoolibCreateModFrame("Frame", UIParent)
local pointTests = {
    {name = "Single point", args = {"CENTER"}, expected = true},
    {name = "Point with x,y", args = {"TOPLEFT", 10, -10}, expected = true},
    {name = "Point with frame", args = {"CENTER", UIParent}, expected = true},
}

local pointSuccess = true
for _, test in ipairs(pointTests) do
    local ok = pcall(function()
        pointTestFrame:ClearPoints():Point(unpack(test.args))
    end)
    if not ok then
        print("✗ Point pattern failed:", test.name)
        pointSuccess = false
    end
end

if pointSuccess then
    print("✓ All Point() argument patterns work")
end

pointTestFrame:Hide()

-- ============================================================
-- Test 9: Tooltip System
-- ============================================================

local tooltipFrame = LoolibCreateModFrame("Button", UIParent)
    :Size(100, 30)
    :Point("CENTER")
    :Tooltip("Test tooltip")

if tooltipFrame.tooltipText == "Test tooltip" then
    print("✓ Tooltip system configured")
else
    print("✗ Tooltip system FAILED")
end

-- Multi-line tooltip
local multiTooltipFrame = LoolibCreateModFrame("Button", UIParent)
    :Tooltip({"Title", "Line 1", "Line 2"})

if multiTooltipFrame.tooltipLines and #multiTooltipFrame.tooltipLines == 3 then
    print("✓ Multi-line tooltips configured")
else
    print("✗ Multi-line tooltips FAILED")
end

tooltipFrame:Hide()
multiTooltipFrame:Hide()

-- ============================================================
-- Test 10: Script Handler Safety
-- ============================================================

local scriptTestFrame = LoolibCreateModFrame("Frame", UIParent)

-- Test that setting scripts on incompatible frames doesn't error
local scriptSuccess = pcall(function()
    scriptTestFrame:OnClick(function() end)  -- Frame doesn't support OnClick
    scriptTestFrame:OnEnter(function() end)
    scriptTestFrame:OnUpdate(function() end)
end)

if scriptSuccess then
    print("✓ Script handlers safely handle incompatible frame types")
else
    print("✗ Script handler safety FAILED")
end

scriptTestFrame:Hide()

-- ============================================================
-- Summary
-- ============================================================

print("==========================================")
print("Integration Test Complete")
print("==========================================")
print("")
print("If all tests passed, WidgetMod is ready to use!")
print("See /Loolib/docs/WidgetMod.md for documentation")
print("See /Loolib/UI/Widgets/WidgetMod_Examples.lua for usage examples")
