--[[--------------------------------------------------------------------
    EnhancedSlider - Unit Tests

    Simple test suite to verify EnhancedSlider functionality.
    Load this file and run /testslider to execute tests.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local testFrame = CreateFrame("Frame")
testFrame:RegisterEvent("PLAYER_LOGIN")
testFrame:SetScript("OnEvent", function()
    local passed = 0
    local failed = 0
    local tests = {}

    -- Test helper
    local function test(name, func)
        table.insert(tests, {name = name, func = func})
    end

    local function assertEquals(actual, expected, message)
        if actual ~= expected then
            error(string.format("%s: Expected %s, got %s", message or "Assertion failed", tostring(expected), tostring(actual)))
        end
    end

    local function assertTrue(condition, message)
        if not condition then
            error(message or "Assertion failed: condition is false")
        end
    end

    local function assertNotNil(value, message)
        if value == nil then
            error(message or "Assertion failed: value is nil")
        end
    end

    -- ============================================================
    -- TESTS
    -- ============================================================

    test("Create slider", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
        assertNotNil(slider, "Slider should be created")
        assertTrue(slider.Range ~= nil, "Slider should have Range method")
        assertTrue(slider.SetTo ~= nil, "Slider should have SetTo method")
        assertTrue(slider.OnChange ~= nil, "Slider should have OnChange method")
    end)

    test("Set and get range", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
        slider:Range(10, 50)
        local min, max = slider:GetRange()
        assertEquals(min, 10, "Min should be 10")
        assertEquals(max, 50, "Max should be 50")
    end)

    test("Set and get value", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
        slider:Range(0, 100):SetTo(75)
        local value = slider:GetTo()
        assertEquals(value, 75, "Value should be 75")
    end)

    test("Step configuration", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
        slider:Step(5)
        local step = slider:GetStep()
        assertEquals(step, 5, "Step should be 5")
    end)

    test("Fluent API chaining", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
            :Size(200, 20)
            :Range(0, 100)
            :Step(10)
            :SetTo(50)

        assertNotNil(slider, "Chaining should return slider")
        assertEquals(slider:GetTo(), 50, "Value should be 50 after chaining")
        local min, max = slider:GetRange()
        assertEquals(min, 0, "Min should be 0 after chaining")
        assertEquals(max, 100, "Max should be 100 after chaining")
    end)

    test("Value display", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
            :Range(0, 100)
            :SetTo(50)
            :ShowValue("%d%%")

        assertNotNil(slider.valueText, "Value text should exist")
        assertTrue(slider.valueText:IsShown(), "Value text should be visible")
        assertEquals(slider.valueText:GetText(), "50%", "Value text should show formatted value")
    end)

    test("Labels display", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
            :Range(0, 100)
            :ShowLabels("Min", "Max")

        assertNotNil(slider.minLabel, "Min label should exist")
        assertNotNil(slider.maxLabel, "Max label should exist")
        assertTrue(slider.minLabel:IsShown(), "Min label should be visible")
        assertTrue(slider.maxLabel:IsShown(), "Max label should be visible")
        assertEquals(slider.minLabel:GetText(), "Min", "Min label text should be 'Min'")
        assertEquals(slider.maxLabel:GetText(), "Max", "Max label text should be 'Max'")
    end)

    test("Default labels", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
            :Range(10, 90)
            :ShowLabels()

        assertEquals(slider.minLabel:GetText(), "10", "Min label should show min value")
        assertEquals(slider.maxLabel:GetText(), "90", "Max label should show max value")
    end)

    test("Title display", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
            :Title("Test Title")

        assertNotNil(slider.titleText, "Title text should exist")
        assertTrue(slider.titleText:IsShown(), "Title should be visible")
        assertEquals(slider.titleText:GetText(), "Test Title", "Title text should be correct")
    end)

    test("OnChange callback", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
        local callbackValue = nil
        local callbackUserInput = nil

        slider:Range(0, 100)
            :OnChange(function(self, value, userInput)
                callbackValue = value
                callbackUserInput = userInput
            end)

        -- Simulate value change
        slider:SetValue(75)

        assertEquals(callbackValue, 75, "Callback should receive value 75")
    end)

    test("Enable/Disable", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)

        slider:SetEnabled(false)
        assertTrue(not slider:IsEnabled(), "Slider should be disabled")

        slider:SetEnabled(true)
        assertTrue(slider:IsEnabled(), "Slider should be enabled")
    end)

    test("Value format change", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
            :Range(0, 100)
            :SetTo(50)
            :ShowValue("%d")

        assertEquals(slider.valueText:GetText(), "50", "Initial format should be integer")

        slider:ValueFormat("%.1f")
        slider:_UpdateValueDisplay()

        assertEquals(slider.valueText:GetText(), "50.0", "Format should change to one decimal")
    end)

    test("Hide and show value", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
            :Range(0, 100)
            :ShowValue()

        assertTrue(slider.valueText:IsShown(), "Value should be shown")

        slider:HideValue()
        assertTrue(not slider.valueText:IsShown(), "Value should be hidden")
    end)

    test("Hide and show labels", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
            :Range(0, 100)
            :ShowLabels()

        assertTrue(slider.minLabel:IsShown(), "Labels should be shown")

        slider:HideLabels()
        assertTrue(not slider.minLabel:IsShown(), "Labels should be hidden")
    end)

    test("Decimal range", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)
            :Range(0.5, 2.0)
            :Step(0.1)
            :SetTo(1.5)

        local min, max = slider:GetRange()
        assertEquals(min, 0.5, "Min should be 0.5")
        assertEquals(max, 2.0, "Max should be 2.0")
        assertEquals(slider:GetTo(), 1.5, "Value should be 1.5")
    end)

    test("WidgetMod integration", function()
        local slider = LoolibCreateEnhancedSlider(UIParent)

        -- These methods come from WidgetMod if available
        if slider.Size then
            slider:Size(250, 25)
            local width = slider:GetWidth()
            assertEquals(width, 250, "Width should be 250 from WidgetMod")
        end
    end)

    -- ============================================================
    -- RUN TESTS
    -- ============================================================

    local function runTests()
        print("|cff00ff00=== Enhanced Slider Tests ===|r")
        passed = 0
        failed = 0

        for i, testCase in ipairs(tests) do
            local success, err = pcall(testCase.func)
            if success then
                passed = passed + 1
                print(string.format("|cff00ff00[PASS]|r %s", testCase.name))
            else
                failed = failed + 1
                print(string.format("|cffff0000[FAIL]|r %s: %s", testCase.name, err))
            end
        end

        print(string.format("\n|cff00ff00Passed: %d|r | |cffff0000Failed: %d|r | Total: %d", passed, failed, passed + failed))

        if failed == 0 then
            print("|cff00ff00All tests passed!|r")
        else
            print("|cffff0000Some tests failed.|r")
        end
    end

    -- Register slash command
    SLASH_TESTSLIDER1 = "/testslider"
    SlashCmdList["TESTSLIDER"] = runTests

    print("|cffffff00EnhancedSlider tests loaded. Use |cff00ff00/testslider|r to run tests.|r")
end)
