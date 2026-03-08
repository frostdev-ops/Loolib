--[[--------------------------------------------------------------------
    Loolib ErrorHandler Example

    Demonstrates how to use the ErrorHandler module in your addon.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local ErrorHandler = Loolib:GetModule("ErrorHandler").Handler

-- Example 1: Basic error retrieval and display
local function ShowRecentErrors()
    print("|cff00ff00=== Recent Errors ===|r")

    local errors = ErrorHandler:GetRecentErrors(5)

    if #errors == 0 then
        print("No errors recorded!")
        return
    end

    for i, error in ipairs(errors) do
        print(string.format("|cffffaa00Error %d:|r %s - %s (x%d)",
            i, error.type, error.message, error.count))
    end
end

-- Example 2: Error statistics
local function ShowErrorStats()
    print("|cff00ff00=== Error Statistics ===|r")

    local stats = ErrorHandler:GetErrorStats()

    print("Total captured:", stats.totalCaptured)
    print("Currently stored:", stats.currentlyStored)

    if stats.oldestTimestamp then
        print("Oldest:", date("%Y-%m-%d %H:%M:%S", stats.oldestTimestamp))
    end

    if stats.newestTimestamp then
        print("Newest:", date("%Y-%m-%d %H:%M:%S", stats.newestTimestamp))
    end

    print("\nErrors by type:")
    for errorType, count in pairs(stats.byType) do
        print(string.format("  %s: %d", errorType, count))
    end
end

-- Example 3: Manual error recording
local function TestManualErrors()
    print("|cff00ff00=== Testing Manual Error Recording ===|r")

    -- Record a simple error
    ErrorHandler:RecordManualError("This is a test error")

    -- Record an error with custom type
    ErrorHandler:RecordManualError("Configuration invalid", "CONFIG_ERROR")

    -- Simulate a protected call
    local function RiskyFunction()
        error("Something went wrong!")
    end

    local success, result = pcall(RiskyFunction)
    if not success then
        ErrorHandler:RecordManualError(result, "RISKY_FUNCTION")
    end

    print("Recorded 3 test errors")
end

-- Example 4: Function wrapping
local function TestFunctionWrapping()
    print("|cff00ff00=== Testing Function Wrapping ===|r")

    -- Create a function that might error
    local function ProcessData(data)
        if not data then
            error("Data is nil!")
        end
        if not data.name then
            error("Data missing name field!")
        end
        return "Processed: " .. data.name
    end

    -- Wrap it with error handling
    local SafeProcess = ErrorHandler:WrapFunction(ProcessData, "DATA_PROCESSOR")

    -- These will be caught and logged
    SafeProcess(nil)
    SafeProcess({})

    -- This will succeed
    local result = SafeProcess({name = "Test"})
    if result then
        print("Success:", result)
    end

    -- Check errors
    local errors = ErrorHandler:GetErrorsByType("DATA_PROCESSOR")
    print(string.format("Caught %d errors from wrapped function", #errors))
end

-- Example 5: Error filtering and analysis
local function AnalyzeErrors()
    print("|cff00ff00=== Error Analysis ===|r")

    local errors = ErrorHandler:GetErrors()

    -- Find high-frequency errors
    local frequent = {}
    for _, error in ipairs(errors) do
        if error.count >= 5 then
            table.insert(frequent, error)
        end
    end

    print(string.format("Found %d high-frequency errors (5+ occurrences)", #frequent))

    -- Find recent errors (last hour)
    local now = time()
    local oneHourAgo = now - 3600
    local recent = {}

    for _, error in ipairs(errors) do
        if error.timestamp >= oneHourAgo then
            table.insert(recent, error)
        end
    end

    print(string.format("Found %d errors in the last hour", #recent))
end

-- Example 6: Configuration
local function ConfigureErrorHandler()
    print("|cff00ff00=== Configuring ErrorHandler ===|r")

    -- Increase storage capacity
    ErrorHandler:SetMaxErrors(200)
    print("Max errors:", ErrorHandler:GetMaxErrors())

    -- Increase retention period
    ErrorHandler:SetRetentionDays(14)
    print("Retention days:", ErrorHandler:GetRetentionDays())

    -- Adjust stack depth
    ErrorHandler:SetStackDepth(15)
    print("Stack depth:", ErrorHandler:GetStackDepth())

    -- Toggle features
    print("Logging enabled:", ErrorHandler:IsLoggingEnabled())
    print("Persistence enabled:", ErrorHandler:IsPersistenceEnabled())
    print("Deduplication enabled:", ErrorHandler:IsDeduplicationEnabled())
end

-- Example 7: SavedVariables integration
local ExampleAddonDB = {}

local function SaveErrors()
    print("|cff00ff00=== Saving Errors to SavedVariables ===|r")

    ExampleAddonDB.errors = ErrorHandler:ExportToSavedVariables()

    if ExampleAddonDB.errors then
        print("Errors exported successfully")
        print("Export time:", date("%Y-%m-%d %H:%M:%S", ExampleAddonDB.errors.exportTime))
    end
end

local function LoadErrors()
    print("|cff00ff00=== Loading Errors from SavedVariables ===|r")

    if not ExampleAddonDB.errors then
        print("No saved errors found")
        return
    end

    local success = ErrorHandler:ImportFromSavedVariables(ExampleAddonDB.errors)

    if success then
        print("Errors imported successfully")
        local stats = ErrorHandler:GetErrorStats()
        print("Restored", stats.currentlyStored, "errors")
    else
        print("Failed to import errors")
    end
end

-- Example 8: Cleanup operations
local function CleanupErrors()
    print("|cff00ff00=== Cleanup Operations ===|r")

    -- Get stats before cleanup
    local beforeStats = ErrorHandler:GetErrorStats()
    print("Before cleanup:", beforeStats.currentlyStored, "errors")

    -- Clean old errors
    local removed = ErrorHandler:CleanupOldErrors()
    print("Removed", removed, "old errors")

    -- Clean specific type
    local manualRemoved = ErrorHandler:ClearErrorsByType("MANUAL")
    print("Removed", manualRemoved, "MANUAL errors")

    -- Get stats after cleanup
    local afterStats = ErrorHandler:GetErrorStats()
    print("After cleanup:", afterStats.currentlyStored, "errors")
end

-- Example 9: Formatted output
local function ShowFormattedErrors()
    print("|cff00ff00=== Formatted Error Output ===|r")

    -- Use the built-in formatter
    ErrorHandler:PrintRecentErrors(3)

    -- Or format manually
    local errors = ErrorHandler:GetRecentErrors(1)
    if #errors > 0 then
        print("\n|cff00ff00Custom formatting:|r")
        local formatted = ErrorHandler:FormatError(errors[1], true)
        print(formatted)
    end
end

-- Example 10: Real-world integration
local function IntegrateWithAddon()
    print("|cff00ff00=== Real-World Integration Example ===|r")

    -- Simulate addon initialization
    local MyAddon = {
        name = "ExampleAddon",
        version = "1.0.0",
    }

    function MyAddon:Initialize()
        -- Load saved errors
        if ExampleAddonDB and ExampleAddonDB.errors then
            ErrorHandler:ImportFromSavedVariables(ExampleAddonDB.errors)
        end

        -- Configure for this addon
        ErrorHandler:SetMaxErrors(150)
        ErrorHandler:SetRetentionDays(30)

        print("Addon initialized with ErrorHandler")
    end

    function MyAddon:ProcessCommand(command)
        -- Wrap command processing
        local SafeProcess = ErrorHandler:WrapFunction(function(cmd)
            if cmd == "error" then
                error("Test error command")
            elseif cmd == "stats" then
                ShowErrorStats()
            elseif cmd == "errors" then
                ShowRecentErrors()
            else
                print("Unknown command:", cmd)
            end
        end, "COMMAND_PROCESSOR")

        SafeProcess(command)
    end

    function MyAddon:Shutdown()
        -- Save errors on logout
        ExampleAddonDB = ExampleAddonDB or {}
        ExampleAddonDB.errors = ErrorHandler:ExportToSavedVariables()

        print("Errors saved for next session")
    end

    -- Test the integration
    MyAddon:Initialize()
    MyAddon:ProcessCommand("stats")
    MyAddon:ProcessCommand("error") -- Will be caught
    MyAddon:Shutdown()
end

--[[--------------------------------------------------------------------
    Slash Command Interface
----------------------------------------------------------------------]]

SLASH_ERRORTEST1 = "/errortest"
SlashCmdList["ERRORTEST"] = function(msg)
    local command = msg:lower():trim()

    if command == "stats" then
        ShowErrorStats()
    elseif command == "recent" then
        ShowRecentErrors()
    elseif command == "manual" then
        TestManualErrors()
    elseif command == "wrap" then
        TestFunctionWrapping()
    elseif command == "analyze" then
        AnalyzeErrors()
    elseif command == "config" then
        ConfigureErrorHandler()
    elseif command == "save" then
        SaveErrors()
    elseif command == "load" then
        LoadErrors()
    elseif command == "cleanup" then
        CleanupErrors()
    elseif command == "format" then
        ShowFormattedErrors()
    elseif command == "integrate" then
        IntegrateWithAddon()
    elseif command == "clear" then
        ErrorHandler:ClearErrors()
        print("All errors cleared")
    elseif command == "help" or command == "" then
        print("|cff00ff00ErrorHandler Example Commands:|r")
        print("  /errortest stats - Show error statistics")
        print("  /errortest recent - Show recent errors")
        print("  /errortest manual - Test manual error recording")
        print("  /errortest wrap - Test function wrapping")
        print("  /errortest analyze - Analyze error patterns")
        print("  /errortest config - Show/modify configuration")
        print("  /errortest save - Save errors to SavedVariables")
        print("  /errortest load - Load errors from SavedVariables")
        print("  /errortest cleanup - Test cleanup operations")
        print("  /errortest format - Show formatted output")
        print("  /errortest integrate - Real-world integration example")
        print("  /errortest clear - Clear all errors")
    else
        print("Unknown command. Type /errortest help for commands")
    end
end

print("|cff00ff00Loolib ErrorHandler Example loaded!|r Type /errortest help for commands")
