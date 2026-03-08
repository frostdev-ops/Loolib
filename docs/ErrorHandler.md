# ErrorHandler

A comprehensive error logging and handling system for WoW addons. Automatically captures errors from WoW events, provides stack traces, deduplicates errors, and persists them across sessions.

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Event Capturing](#event-capturing)
- [Error Retrieval](#error-retrieval)
- [Manual Error Recording](#manual-error-recording)
- [Persistence](#persistence)
- [API Reference](#api-reference)

## Features

- **Automatic Event Capture**: Listens for `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, and `LUA_WARNING` events
- **Stack Traces**: Captures stack traces with configurable depth (default: 10 levels)
- **Deduplication**: Automatically deduplicates identical errors with occurrence counting
- **Circular Buffer**: Stores errors in a circular buffer with configurable size (default: 100 entries)
- **Time-based Cleanup**: Automatically removes errors older than retention period (default: 7 days)
- **SavedVariables**: Persists errors across sessions
- **Logger Integration**: Integrates with Loolib's Logger module for real-time output
- **Rich Retrieval APIs**: Query errors by type, time, or get statistics

## Quick Start

### Basic Usage

The ErrorHandler is automatically initialized as a singleton and starts capturing errors on load:

```lua
local Loolib = LibStub("Loolib")
local ErrorHandler = Loolib:GetModule("ErrorHandler").Handler

-- Get recent errors
local errors = ErrorHandler:GetRecentErrors(10)
for _, error in ipairs(errors) do
    print(error.type, error.message, error.count)
end

-- Print errors to chat
ErrorHandler:PrintRecentErrors(5)

-- Get statistics
local stats = ErrorHandler:GetErrorStats()
print("Total errors captured:", stats.totalCaptured)
print("Currently stored:", stats.currentlyStored)
```

### Integration with Your Addon

```lua
local MyAddon = LibStub("Loolib"):NewAddon("MyAddon")
local ErrorHandler = LibStub("Loolib"):GetModule("ErrorHandler").Handler

function MyAddon:OnEnable()
    -- Manually record errors in your code
    local success, result = pcall(SomeRiskyFunction)
    if not success then
        ErrorHandler:RecordManualError(result, "MY_ADDON_ERROR")
    end
end

-- Wrap a function to auto-capture errors
local SafeFunction = ErrorHandler:WrapFunction(function()
    -- Your code that might error
end, "MY_FUNCTION")

SafeFunction() -- Errors will be captured automatically
```

## Configuration

### Error Storage

```lua
-- Set maximum number of errors to store (default: 100)
ErrorHandler:SetMaxErrors(200)

-- Set error retention period in days (default: 7)
ErrorHandler:SetRetentionDays(30)

-- Set stack trace depth (default: 10)
ErrorHandler:SetStackDepth(15)
```

### Feature Toggles

```lua
-- Enable/disable Logger integration (default: true)
ErrorHandler:SetLoggingEnabled(false)

-- Enable/disable SavedVariables persistence (default: true)
ErrorHandler:SetPersistenceEnabled(true)

-- Enable/disable error deduplication (default: true)
ErrorHandler:SetDeduplicationEnabled(true)
```

### Event Management

```lua
-- Stop capturing error events
ErrorHandler:UnregisterEvents()

-- Resume capturing error events
ErrorHandler:RegisterEvents()
```

## Event Capturing

The ErrorHandler automatically captures these WoW events:

### ADDON_ACTION_BLOCKED

Fired when an addon tries to call a protected function during combat or at an inappropriate time.

**Example Error:**
```
[ADDON_ACTION_BLOCKED] Addon 'MyAddon' tried to call protected function 'CastSpell'
```

### ADDON_ACTION_FORBIDDEN

Fired when an addon tries to call a function that addons are not allowed to call.

**Example Error:**
```
[ADDON_ACTION_FORBIDDEN] Addon 'MyAddon' tried to call forbidden function 'RestrictedAPI'
```

### LUA_WARNING

Fired when Lua generates a warning (Lua 5.4+ feature).

**Example Error:**
```
[LUA_WARNING] [Warning Type 2] attempt to index a nil value
```

## Error Retrieval

### Get All Errors

```lua
-- Get all stored errors
local errors = ErrorHandler:GetErrors()

-- Get all errors sorted by timestamp (newest first)
local sorted = ErrorHandler:GetErrors(true)
```

### Get Recent Errors

```lua
-- Get 10 most recent errors
local recent = ErrorHandler:GetRecentErrors(10)

-- Default is 10 if not specified
local recent = ErrorHandler:GetRecentErrors()
```

### Get Errors by Type

```lua
-- Get all ADDON_ACTION_BLOCKED errors
local blocked = ErrorHandler:GetErrorsByType("ADDON_ACTION_BLOCKED")

-- Get all manual errors
local manual = ErrorHandler:GetErrorsByType("MANUAL")
```

### Get Statistics

```lua
local stats = ErrorHandler:GetErrorStats()

print("Total captured:", stats.totalCaptured)       -- Lifetime count
print("Currently stored:", stats.currentlyStored)   -- In buffer
print("Oldest:", stats.oldestTimestamp)             -- Unix timestamp
print("Newest:", stats.newestTimestamp)             -- Unix timestamp

-- Errors by type
for errorType, count in pairs(stats.byType) do
    print(errorType, count)
end
```

## Error Record Structure

Each error record contains:

```lua
{
    type = "ADDON_ACTION_BLOCKED",  -- Error type
    message = "Error message here", -- Error message
    timestamp = 1234567890,         -- Unix timestamp (first occurrence)
    lastSeen = 1234567890,          -- Unix timestamp (last occurrence)
    count = 5,                      -- Number of occurrences
    stack = {                       -- Stack trace (array)
        "MyAddon.lua:123 in OnClick()",
        "ButtonFrame.lua:456 in HandleClick()",
        -- ... more frames
    }
}
```

## Manual Error Recording

### Basic Manual Recording

```lua
-- Record a custom error
ErrorHandler:RecordManualError("Something went wrong!")

-- With custom error type
ErrorHandler:RecordManualError("Invalid configuration", "CONFIG_ERROR")
```

### Function Wrapping

Automatically capture errors from wrapped functions:

```lua
-- Wrap a function
local SafeProcess = ErrorHandler:WrapFunction(function(data)
    -- Process data...
    if not data.valid then
        error("Invalid data")
    end
end, "DATA_PROCESSOR")

-- Errors are captured automatically
SafeProcess(myData)

-- Check if errors occurred
local errors = ErrorHandler:GetErrorsByType("DATA_PROCESSOR")
if #errors > 0 then
    print("Data processing had", #errors, "errors")
end
```

### Protected Calls with Logging

```lua
local function RiskyOperation()
    -- Your code here
end

local success, result = pcall(RiskyOperation)
if not success then
    ErrorHandler:RecordManualError(tostring(result), "RISKY_OP")
end
```

## Persistence

### SavedVariables Setup

In your TOC file:

```
## SavedVariables: MyAddonDB
```

In your addon code:

```lua
local MyAddon = LibStub("Loolib"):NewAddon("MyAddon")
local ErrorHandler = LibStub("Loolib"):GetModule("ErrorHandler").Handler

function MyAddon:OnInitialize()
    -- Create or load database
    MyAddonDB = MyAddonDB or {}
    MyAddonDB.errors = MyAddonDB.errors or {}

    -- Import errors from previous session
    ErrorHandler:ImportFromSavedVariables(MyAddonDB.errors)
end

function MyAddon:OnDisable()
    -- Export errors for next session
    MyAddonDB.errors = ErrorHandler:ExportToSavedVariables()
end
```

### Export/Import

```lua
-- Export to a table (suitable for SavedVariables)
local data = ErrorHandler:ExportToSavedVariables()

-- Import from a table
local success = ErrorHandler:ImportFromSavedVariables(data)
if not success then
    print("Failed to import error data")
end
```

The exported data includes:
- Configuration settings
- All stored errors
- Error counters
- Write index position
- Export timestamp

## Error Cleanup

### Manual Cleanup

```lua
-- Clear all errors
ErrorHandler:ClearErrors()

-- Clear errors by type
local removed = ErrorHandler:ClearErrorsByType("LUA_WARNING")
print("Removed", removed, "warnings")

-- Clean up old errors (older than retention period)
local removed = ErrorHandler:CleanupOldErrors()
print("Removed", removed, "old errors")
```

### Automatic Cleanup

The ErrorHandler automatically removes old errors when:
- Importing from SavedVariables
- The circular buffer wraps around (oldest errors are overwritten)

## Formatted Output

### Print to Chat

```lua
-- Print 5 most recent errors to chat
ErrorHandler:PrintRecentErrors(5)

-- Output format:
-- [Loolib ErrorHandler] Recent errors (5):
-- --- Error 1 ---
-- [ADDON_ACTION_BLOCKED] Addon 'Test' tried to call protected function 'CastSpell'
-- Time: 2025-12-06 15:30:45
-- --- Error 2 ---
-- ...
```

### Format Individual Errors

```lua
local errors = ErrorHandler:GetRecentErrors(1)
local error = errors[1]

-- Format with stack trace
local formatted = ErrorHandler:FormatError(error, true)
print(formatted)

-- Format without stack trace
local formatted = ErrorHandler:FormatError(error, false)
print(formatted)

-- Example output:
-- [ADDON_ACTION_BLOCKED] (x3) Addon 'MyAddon' tried to call protected function 'UseAction'
-- Time: 2025-12-06 15:30:45
-- Last seen: 2025-12-06 15:31:12
-- Stack trace:
--   1: MyAddon/Core.lua:234 in CastSpell()
--   2: MyAddon/UI.lua:567 in OnClick()
--   3: SharedXML/Button.lua:89 in <anonymous>
```

## API Reference

### Configuration Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `SetMaxErrors` | `max: number` | - | Set maximum error storage (1-10000) |
| `GetMaxErrors` | - | `number` | Get maximum error storage |
| `SetStackDepth` | `depth: number` | - | Set stack trace depth (0-50) |
| `GetStackDepth` | - | `number` | Get stack trace depth |
| `SetRetentionDays` | `days: number` | - | Set retention period (1-365) |
| `GetRetentionDays` | - | `number` | Get retention period |
| `SetLoggingEnabled` | `enabled: boolean` | - | Enable/disable Logger integration |
| `IsLoggingEnabled` | - | `boolean` | Check if logging is enabled |
| `SetPersistenceEnabled` | `enabled: boolean` | - | Enable/disable SavedVariables |
| `IsPersistenceEnabled` | - | `boolean` | Check if persistence is enabled |
| `SetDeduplicationEnabled` | `enabled: boolean` | - | Enable/disable deduplication |
| `IsDeduplicationEnabled` | - | `boolean` | Check if deduplication is enabled |

### Event Management

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `RegisterEvents` | - | - | Start capturing error events |
| `UnregisterEvents` | - | - | Stop capturing error events |

### Error Retrieval

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `GetErrors` | `sorted?: boolean` | `table[]` | Get all stored errors |
| `GetRecentErrors` | `count?: number` | `table[]` | Get N most recent errors (default: 10) |
| `GetErrorsByType` | `errorType: string` | `table[]` | Get errors of specific type |
| `GetErrorStats` | - | `table` | Get error statistics |

### Error Recording

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `RecordManualError` | `message: string, errorType?: string` | - | Manually record an error |
| `WrapFunction` | `func: function, errorType?: string` | `function` | Wrap function with error capture |

### Cleanup

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `ClearErrors` | - | - | Clear all errors |
| `ClearErrorsByType` | `errorType: string` | `number` | Clear errors by type, returns count removed |
| `CleanupOldErrors` | - | `number` | Remove old errors, returns count removed |

### Persistence

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `ExportToSavedVariables` | - | `table` | Export errors for SavedVariables |
| `ImportFromSavedVariables` | `data: table` | `boolean` | Import errors, returns success |

### Formatting

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `FormatError` | `error: table, includeStack?: boolean` | `string` | Format error as string |
| `PrintRecentErrors` | `count?: number` | - | Print errors to chat (default: 10) |

### Advanced (Internal)

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `CaptureStackTrace` | `startLevel?: number, maxDepth?: number` | `table` | Capture stack trace |
| `FormatStackTrace` | `stack: table` | `string` | Format stack trace |
| `HashMessage` | `message: string` | `number` | Generate message hash |
| `IsDuplicate` | `errorType: string, message: string` | `boolean, table?` | Check if error is duplicate |
| `RebuildHashTable` | - | - | Rebuild deduplication hash table |

## Advanced Usage

### Custom Error Processing

```lua
local ErrorHandler = LibStub("Loolib"):GetModule("ErrorHandler").Handler

-- Process errors on a schedule
C_Timer.NewTicker(300, function() -- Every 5 minutes
    local errors = ErrorHandler:GetErrors(true)

    -- Count critical errors
    local criticalCount = 0
    for _, error in ipairs(errors) do
        if error.type == "ADDON_ACTION_FORBIDDEN" then
            criticalCount = criticalCount + 1
        end
    end

    if criticalCount > 10 then
        print("|cffff0000WARNING:|r", criticalCount, "critical errors detected!")
    end
end)
```

### Error Rate Monitoring

```lua
local function GetErrorRate()
    local stats = ErrorHandler:GetErrorStats()

    if not stats.oldestTimestamp or not stats.newestTimestamp then
        return 0
    end

    local timeSpan = stats.newestTimestamp - stats.oldestTimestamp
    if timeSpan == 0 then
        return 0
    end

    return stats.currentlyStored / (timeSpan / 60) -- Errors per minute
end

print("Current error rate:", GetErrorRate(), "errors/min")
```

### Error Filtering

```lua
-- Get only high-frequency errors (occurred more than 5 times)
local function GetFrequentErrors()
    local errors = ErrorHandler:GetErrors()
    local frequent = {}

    for _, error in ipairs(errors) do
        if error.count > 5 then
            table.insert(frequent, error)
        end
    end

    return frequent
end
```

### Stack Trace Analysis

```lua
-- Find errors from specific files
local function GetErrorsFromFile(filename)
    local errors = ErrorHandler:GetErrors()
    local matches = {}

    for _, error in ipairs(errors) do
        if error.stack then
            for _, frame in ipairs(error.stack) do
                if string.find(frame, filename) then
                    table.insert(matches, error)
                    break
                end
            end
        end
    end

    return matches
end

local coreErrors = GetErrorsFromFile("Core.lua")
print("Found", #coreErrors, "errors in Core.lua")
```

## Best Practices

1. **Enable Persistence**: Always enable SavedVariables persistence for debugging issues across sessions
2. **Monitor Retention**: Adjust retention period based on your debugging needs (longer for rare issues)
3. **Use Custom Types**: Create meaningful error types for your addon's errors for easy filtering
4. **Check Statistics**: Periodically check error stats to identify systemic issues
5. **Clean Regularly**: Call `CleanupOldErrors()` periodically if you have long retention periods
6. **Wrap Risky Code**: Use `WrapFunction()` for code that might error to ensure capture
7. **Deduplicate**: Keep deduplication enabled to avoid filling the buffer with repeated errors

## See Also

- [Logger.md](Logger.md) - Logging system that ErrorHandler integrates with
- [Dump.md](Dump.md) - Object inspection for debugging error contexts
- [Console.md](Console.md) - Slash commands for error management UI
