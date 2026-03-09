--[[--------------------------------------------------------------------
    Loolib ErrorHandler Test Suite

    Basic unit tests for ErrorHandler module functionality.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local ErrorHandler = Loolib:GetModule("ErrorHandler").Handler

-- Test results
local TestResults = {
    passed = 0,
    failed = 0,
    tests = {}
}

-- Simple assertion helper
local function assert_equal(actual, expected, testName)
    if actual == expected then
        TestResults.passed = TestResults.passed + 1
        table.insert(TestResults.tests, {name = testName, passed = true})
        return true
    else
        TestResults.failed = TestResults.failed + 1
        table.insert(TestResults.tests, {
            name = testName,
            passed = false,
            expected = expected,
            actual = actual
        })
        return false
    end
end

local function assert_true(condition, testName)
    return assert_equal(condition == true, true, testName)
end

local function assert_not_nil(value, testName)
    return assert_true(value ~= nil, testName)
end

-- Test suite
local function RunTests()
    print("|cff00ff00=== ErrorHandler Test Suite ===|r")

    -- Clear any existing errors before testing
    ErrorHandler:ClearErrors()

    -- Test 1: Configuration
    print("\n|cffaaaaaa[Test Group: Configuration]|r")

    ErrorHandler:SetMaxErrors(50)
    assert_equal(ErrorHandler:GetMaxErrors(), 50, "SetMaxErrors/GetMaxErrors")

    ErrorHandler:SetStackDepth(5)
    assert_equal(ErrorHandler:GetStackDepth(), 5, "SetStackDepth/GetStackDepth")

    ErrorHandler:SetRetentionDays(14)
    assert_equal(ErrorHandler:GetRetentionDays(), 14, "SetRetentionDays/GetRetentionDays")

    ErrorHandler:SetLoggingEnabled(false)
    assert_equal(ErrorHandler:IsLoggingEnabled(), false, "SetLoggingEnabled/IsLoggingEnabled")

    ErrorHandler:SetPersistenceEnabled(false)
    assert_equal(ErrorHandler:IsPersistenceEnabled(), false, "SetPersistenceEnabled/IsPersistenceEnabled")

    ErrorHandler:SetDeduplicationEnabled(false)
    assert_equal(ErrorHandler:IsDeduplicationEnabled(), false, "SetDeduplicationEnabled/IsDeduplicationEnabled")

    -- Reset to defaults for other tests
    ErrorHandler:SetLoggingEnabled(false) -- Keep quiet during tests
    ErrorHandler:SetDeduplicationEnabled(true)

    -- Test 2: Manual Error Recording
    print("\n|cffaaaaaa[Test Group: Manual Error Recording]|r")

    local beforeCount = ErrorHandler:GetErrorStats().currentlyStored

    ErrorHandler:RecordManualError("Test error 1")
    ErrorHandler:RecordManualError("Test error 2", "CUSTOM_TYPE")

    local afterCount = ErrorHandler:GetErrorStats().currentlyStored
    assert_equal(afterCount, beforeCount + 2, "RecordManualError increases error count")

    local customErrors = ErrorHandler:GetErrorsByType("CUSTOM_TYPE")
    assert_equal(#customErrors, 1, "GetErrorsByType returns correct count")
    assert_equal(customErrors[1].message, "Test error 2", "Error message stored correctly")

    -- Test 3: Error Deduplication
    print("\n|cffaaaaaa[Test Group: Error Deduplication]|r")

    ErrorHandler:ClearErrors()
    ErrorHandler:SetDeduplicationEnabled(true)

    ErrorHandler:RecordManualError("Duplicate error", "DEDUP_TEST")
    ErrorHandler:RecordManualError("Duplicate error", "DEDUP_TEST")
    ErrorHandler:RecordManualError("Duplicate error", "DEDUP_TEST")

    local dedupErrors = ErrorHandler:GetErrorsByType("DEDUP_TEST")
    assert_equal(#dedupErrors, 1, "Deduplication: only one error stored")
    assert_equal(dedupErrors[1].count, 3, "Deduplication: count is 3")

    -- Test 4: Error Retrieval
    print("\n|cffaaaaaa[Test Group: Error Retrieval]|r")

    ErrorHandler:ClearErrors()

    for i = 1, 10 do
        ErrorHandler:RecordManualError("Error " .. i, "RETRIEVAL_TEST")
    end

    local allErrors = ErrorHandler:GetErrors()
    assert_equal(#allErrors, 10, "GetErrors returns all errors")

    local recentErrors = ErrorHandler:GetRecentErrors(5)
    assert_equal(#recentErrors, 5, "GetRecentErrors returns correct count")

    local retrievalErrors = ErrorHandler:GetErrorsByType("RETRIEVAL_TEST")
    assert_equal(#retrievalErrors, 10, "GetErrorsByType returns all matching errors")

    -- Test 5: Error Statistics
    print("\n|cffaaaaaa[Test Group: Error Statistics]|r")

    local stats = ErrorHandler:GetErrorStats()
    assert_true(stats.currentlyStored >= 10, "Stats: currentlyStored is accurate")
    assert_not_nil(stats.byType, "Stats: byType table exists")
    assert_true(stats.byType["RETRIEVAL_TEST"] == 10, "Stats: byType counts are accurate")

    -- Test 6: Stack Traces
    print("\n|cffaaaaaa[Test Group: Stack Traces]|r")

    local function Level3()
        ErrorHandler:RecordManualError("Stack test error", "STACK_TEST")
    end

    local function Level2()
        Level3()
    end

    local function Level1()
        Level2()
    end

    ErrorHandler:ClearErrors()
    Level1()

    local stackErrors = ErrorHandler:GetErrorsByType("STACK_TEST")
    assert_equal(#stackErrors, 1, "Stack test: error recorded")
    assert_true(stackErrors[1].stack ~= nil, "Stack test: stack trace exists")
    assert_true(#stackErrors[1].stack > 0, "Stack test: stack trace has frames")

    -- Test 7: Function Wrapping
    print("\n|cffaaaaaa[Test Group: Function Wrapping]|r")

    ErrorHandler:ClearErrors()

    local testFunc = function(shouldError)
        if shouldError then
            error("Wrapped function error")
        end
        return "success"
    end

    local wrappedFunc = ErrorHandler:WrapFunction(testFunc, "WRAP_TEST")

    -- Should not error
    local result = wrappedFunc(false)
    assert_equal(result, "success", "Wrapped function: success case")

    -- Should capture error
    wrappedFunc(true)
    local wrapErrors = ErrorHandler:GetErrorsByType("WRAP_TEST")
    assert_equal(#wrapErrors, 1, "Wrapped function: error captured")

    -- Test 8: Error Cleanup
    print("\n|cffaaaaaa[Test Group: Error Cleanup]|r")

    ErrorHandler:ClearErrors()

    for i = 1, 20 do
        ErrorHandler:RecordManualError("Cleanup test " .. i, "CLEANUP_TEST")
    end

    local beforeCleanup = ErrorHandler:GetErrorStats().currentlyStored
    assert_equal(beforeCleanup, 20, "Cleanup: 20 errors before cleanup")

    local removed = ErrorHandler:ClearErrorsByType("CLEANUP_TEST")
    assert_equal(removed, 20, "Cleanup: ClearErrorsByType returns correct count")

    local afterCleanup = ErrorHandler:GetErrorStats().currentlyStored
    assert_equal(afterCleanup, 0, "Cleanup: all errors removed")

    -- Test 9: Export/Import
    print("\n|cffaaaaaa[Test Group: Export/Import]|r")

    ErrorHandler:ClearErrors()
    ErrorHandler:SetPersistenceEnabled(true)

    ErrorHandler:RecordManualError("Export test 1", "EXPORT_TEST")
    ErrorHandler:RecordManualError("Export test 2", "EXPORT_TEST")

    local exported = ErrorHandler:ExportToSavedVariables()
    assert_not_nil(exported, "Export: data exported")
    assert_equal(exported.version, 1, "Export: version is correct")

    ErrorHandler:ClearErrors()
    assert_equal(ErrorHandler:GetErrorStats().currentlyStored, 0, "Export: errors cleared")

    local importSuccess = ErrorHandler:ImportFromSavedVariables(exported)
    assert_true(importSuccess, "Import: import succeeded")

    local afterImport = ErrorHandler:GetErrorStats().currentlyStored
    assert_equal(afterImport, 2, "Import: errors restored")

    -- Test 10: Hash Function
    print("\n|cffaaaaaa[Test Group: Hash Function]|r")

    local hash1 = ErrorHandler:HashMessage("test message")
    local hash2 = ErrorHandler:HashMessage("test message")
    local hash3 = ErrorHandler:HashMessage("different message")

    assert_equal(hash1, hash2, "Hash: identical messages produce same hash")
    assert_true(hash1 ~= hash3, "Hash: different messages produce different hashes")

    -- Print results
    print("\n|cff00ff00=== Test Results ===|r")
    print(string.format("Passed: |cff00ff00%d|r", TestResults.passed))
    print(string.format("Failed: |cffff0000%d|r", TestResults.failed))

    if TestResults.failed > 0 then
        print("\n|cffff0000Failed Tests:|r")
        for _, test in ipairs(TestResults.tests) do
            if not test.passed then
                print(string.format("  - %s", test.name))
                if test.expected then
                    print(string.format("    Expected: %s", tostring(test.expected)))
                    print(string.format("    Actual:   %s", tostring(test.actual)))
                end
            end
        end
    end

    -- Clean up after tests
    ErrorHandler:ClearErrors()

    return TestResults.failed == 0
end

-- Slash command to run tests
SLASH_ERRORHANDLERTEST1 = "/errorhandlertest"
SlashCmdList["ERRORHANDLERTEST"] = function()
    local success = RunTests()
    if success then
        print("|cff00ff00All tests passed!|r")
    else
        print("|cffff0000Some tests failed!|r")
    end
end

print("|cff00ff00ErrorHandler Test Suite loaded.|r Type /errorhandlertest to run tests")
