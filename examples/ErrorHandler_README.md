# ErrorHandler Integration Guide

This guide shows how to integrate the Loolib ErrorHandler module into your WoW addon.

## TOC File Setup

Add the ErrorHandler to your addon's TOC file. Make sure dependencies are loaded first:

```
## Interface: 120000
## Title: MyAddon
## Author: YourName
## Version: 1.0.0
## SavedVariables: MyAddonDB

# LibStub (if not already embedded)
Libs\LibStub\LibStub.lua

# Loolib Core (required dependencies)
Libs\Loolib\Core\Loolib.lua
Libs\Loolib\Core\Mixin.lua
Libs\Loolib\Core\FunctionUtil.lua

# Loolib Events (required for ErrorHandler)
Libs\Loolib\Events\CallbackRegistry.lua
Libs\Loolib\Events\EventRegistry.lua

# Loolib Debug (optional but recommended)
Libs\Loolib\Debug\Logger.lua
Libs\Loolib\Debug\ErrorHandler.lua

# Your addon files
Core\Init.lua
Core\Main.lua
```

## Basic Integration

### Simple Usage (Automatic)

The ErrorHandler starts automatically when loaded. You don't need to do anything to start capturing errors:

```lua
-- In your addon initialization file
local Loolib = LibStub("Loolib")
local ErrorHandler = Loolib:GetModule("ErrorHandler").Handler

-- ErrorHandler is already running and capturing errors!

-- View errors anytime:
local errors = ErrorHandler:GetRecentErrors(10)
```

### With SavedVariables

To persist errors across sessions, integrate with your SavedVariables:

```lua
-- In your addon's main file
local MyAddon = LibStub("Loolib"):NewAddon("MyAddon")
local ErrorHandler = LibStub("Loolib"):GetModule("ErrorHandler").Handler

function MyAddon:OnInitialize()
    -- Initialize database
    self.db = MyAddonDB or {}
    MyAddonDB = self.db

    -- Load saved errors from previous session
    if self.db.errors then
        ErrorHandler:ImportFromSavedVariables(self.db.errors)
        print("Loaded", ErrorHandler:GetErrorStats().currentlyStored, "errors from last session")
    end

    -- Configure ErrorHandler for your addon
    ErrorHandler:SetMaxErrors(150)
    ErrorHandler:SetRetentionDays(14)
end

function MyAddon:OnDisable()
    -- Save errors for next session
    self.db.errors = ErrorHandler:ExportToSavedVariables()
end
```

## Advanced Integration

### Custom Error Recording

Wrap risky operations with error capture:

```lua
local MyAddon = LibStub("Loolib"):NewAddon("MyAddon")
local ErrorHandler = LibStub("Loolib"):GetModule("ErrorHandler").Handler

function MyAddon:LoadConfiguration()
    local success, result = pcall(function()
        -- Parse configuration file
        local config = self:ParseConfig()
        return config
    end)

    if not success then
        ErrorHandler:RecordManualError(result, "CONFIG_LOAD_ERROR")
        -- Return default config
        return self:GetDefaultConfig()
    end

    return result
end

function MyAddon:ProcessUserInput(input)
    -- Wrap the entire function
    local SafeProcess = ErrorHandler:WrapFunction(function(text)
        if not text or text == "" then
            error("Empty input")
        end

        -- Process the input...
    end, "INPUT_PROCESSOR")

    SafeProcess(input)
end
```

### Error Monitoring

Set up periodic error monitoring:

```lua
function MyAddon:OnEnable()
    -- Check for errors every 5 minutes
    self.errorCheckTimer = C_Timer.NewTicker(300, function()
        local stats = ErrorHandler:GetErrorStats()

        -- Alert user if many errors occurred
        if stats.currentlyStored > 50 then
            print(string.format(
                "|cffff0000WARNING:|r MyAddon has recorded %d errors. Type /myaddon errors to view.",
                stats.currentlyStored
            ))
        end
    end)
end
```

### Slash Command Interface

Add commands to view errors:

```lua
SLASH_MYADDON1 = "/myaddon"
SlashCmdList["MYADDON"] = function(msg)
    local command = msg:lower():trim()

    if command == "errors" then
        ErrorHandler:PrintRecentErrors(10)

    elseif command == "errorstats" then
        local stats = ErrorHandler:GetErrorStats()
        print("Total errors:", stats.totalCaptured)
        print("Stored:", stats.currentlyStored)

        for errorType, count in pairs(stats.byType) do
            print(string.format("  %s: %d", errorType, count))
        end

    elseif command == "clearerrors" then
        ErrorHandler:ClearErrors()
        print("All errors cleared")

    else
        print("MyAddon commands:")
        print("  /myaddon errors - Show recent errors")
        print("  /myaddon errorstats - Show error statistics")
        print("  /myaddon clearerrors - Clear all errors")
    end
end
```

## Configuration Options

### Recommended Settings

For development builds:
```lua
ErrorHandler:SetMaxErrors(500)          -- Store more errors
ErrorHandler:SetStackDepth(20)          -- Deeper stack traces
ErrorHandler:SetRetentionDays(30)       -- Keep for a month
ErrorHandler:SetLoggingEnabled(true)    -- Show in chat
```

For release builds:
```lua
ErrorHandler:SetMaxErrors(100)          -- Standard capacity
ErrorHandler:SetStackDepth(10)          -- Normal depth
ErrorHandler:SetRetentionDays(7)        -- Keep for a week
ErrorHandler:SetLoggingEnabled(false)   -- Don't spam chat
```

### Disable for Normal Users

If you only want error tracking for debugging:

```lua
function MyAddon:OnInitialize()
    -- Only enable ErrorHandler in debug mode
    if self.db.profile.debugMode then
        ErrorHandler:RegisterEvents()
        ErrorHandler:SetLoggingEnabled(true)
    else
        ErrorHandler:UnregisterEvents()
    end
end
```

## Error Analysis Patterns

### Find Frequent Issues

```lua
function MyAddon:AnalyzeErrors()
    local errors = ErrorHandler:GetErrors()
    local frequentErrors = {}

    for _, error in ipairs(errors) do
        if error.count >= 10 then
            table.insert(frequentErrors, {
                type = error.type,
                message = error.message,
                count = error.count
            })
        end
    end

    -- Sort by count
    table.sort(frequentErrors, function(a, b)
        return a.count > b.count
    end)

    print("Most frequent errors:")
    for i, error in ipairs(frequentErrors) do
        print(string.format("%d. [%s] %s (x%d)",
            i, error.type, error.message, error.count))
    end
end
```

### Error Rate Calculation

```lua
function MyAddon:GetErrorRate()
    local stats = ErrorHandler:GetErrorStats()

    if not stats.oldestTimestamp or not stats.newestTimestamp then
        return 0
    end

    local timeSpan = stats.newestTimestamp - stats.oldestTimestamp
    if timeSpan == 0 then
        return 0
    end

    -- Errors per minute
    return stats.currentlyStored / (timeSpan / 60)
end
```

### Export for Bug Reports

```lua
function MyAddon:ExportErrorReport()
    local errors = ErrorHandler:GetRecentErrors(20)
    local report = {
        "===== MyAddon Error Report =====",
        string.format("Generated: %s", date("%Y-%m-%d %H:%M:%S")),
        string.format("Version: %s", MyAddon.version),
        "",
        "Recent Errors:",
        ""
    }

    for i, error in ipairs(errors) do
        table.insert(report, string.format("--- Error %d ---", i))
        table.insert(report, ErrorHandler:FormatError(error, true))
        table.insert(report, "")
    end

    return table.concat(report, "\n")
end

-- Usage: Copy to clipboard or save to file
-- /myaddon exporterrors
```

## Best Practices

1. **Always Save to SavedVariables**: Errors that occur during logout might only be captured in SavedVariables

2. **Configure Retention**: Set retention period based on your update cycle. If you release monthly, use 30+ days

3. **Use Meaningful Error Types**: Create custom error types for different systems:
   ```lua
   ErrorHandler:RecordManualError("Invalid item", "INVENTORY_ERROR")
   ErrorHandler:RecordManualError("Network timeout", "NETWORK_ERROR")
   ```

4. **Clean Up Regularly**: In long-running sessions, periodically clean old errors:
   ```lua
   -- Every hour
   C_Timer.NewTicker(3600, function()
       ErrorHandler:CleanupOldErrors()
   end)
   ```

5. **Respect User Privacy**: Don't send error reports without user consent. Provide opt-in:
   ```lua
   if self.db.profile.sendErrorReports then
       -- Send anonymized error data
   end
   ```

## Troubleshooting

### ErrorHandler Not Capturing Errors

Check that dependencies are loaded:
```lua
if not LoolibErrorHandler then
    print("ERROR: LoolibErrorHandler not loaded!")
    return
end
```

### Too Many Errors

If the buffer fills quickly:
```lua
-- Increase capacity
ErrorHandler:SetMaxErrors(500)

-- Or use deduplication more aggressively
ErrorHandler:SetDeduplicationEnabled(true)
```

### Memory Usage

The ErrorHandler stores errors in memory. For very long sessions:
```lua
-- Reduce retention
ErrorHandler:SetRetentionDays(3)

-- Reduce capacity
ErrorHandler:SetMaxErrors(50)

-- Reduce stack depth
ErrorHandler:SetStackDepth(5)
```

## Testing

Test your ErrorHandler integration:

```lua
-- Test manual errors
ErrorHandler:RecordManualError("Test error 1")
ErrorHandler:RecordManualError("Test error 2", "TEST_ERROR")

-- Test function wrapping
local SafeFunc = ErrorHandler:WrapFunction(function()
    error("This should be caught")
end, "TEST_WRAP")
SafeFunc()

-- Verify errors were recorded
local errors = ErrorHandler:GetRecentErrors(5)
print("Captured", #errors, "test errors")

-- Clean up test errors
ErrorHandler:ClearErrorsByType("TEST_ERROR")
ErrorHandler:ClearErrorsByType("TEST_WRAP")
```

## See Also

- [ErrorHandler.md](../docs/ErrorHandler.md) - Full API documentation
- [Logger.md](../docs/Logger.md) - Logging system integration
- [ErrorHandlerExample.lua](ErrorHandlerExample.lua) - Complete working example
