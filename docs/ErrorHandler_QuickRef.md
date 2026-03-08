# ErrorHandler Quick Reference

## Setup

```lua
local Loolib = LibStub("Loolib")
local ErrorHandler = Loolib:GetModule("ErrorHandler").Handler
```

## Configuration

```lua
-- Storage
ErrorHandler:SetMaxErrors(200)              -- Default: 100
ErrorHandler:SetRetentionDays(14)           -- Default: 7
ErrorHandler:SetStackDepth(15)              -- Default: 10

-- Features
ErrorHandler:SetLoggingEnabled(true)        -- Default: true
ErrorHandler:SetPersistenceEnabled(true)    -- Default: true
ErrorHandler:SetDeduplicationEnabled(true)  -- Default: true

-- Events
ErrorHandler:RegisterEvents()               -- Start capture
ErrorHandler:UnregisterEvents()             -- Stop capture
```

## Retrieval

```lua
-- Get errors
local all = ErrorHandler:GetErrors()              -- All errors
local sorted = ErrorHandler:GetErrors(true)       -- Sorted by time
local recent = ErrorHandler:GetRecentErrors(10)   -- N most recent
local typed = ErrorHandler:GetErrorsByType("LUA_WARNING")

-- Statistics
local stats = ErrorHandler:GetErrorStats()
-- stats.totalCaptured        - Lifetime count
-- stats.currentlyStored      - In buffer now
-- stats.byType               - Table of counts by type
-- stats.oldestTimestamp      - Unix timestamp
-- stats.newestTimestamp      - Unix timestamp
```

## Manual Recording

```lua
-- Simple
ErrorHandler:RecordManualError("Error message")

-- With type
ErrorHandler:RecordManualError("Config invalid", "CONFIG_ERROR")

-- Protected call
local success, result = pcall(riskyFunc)
if not success then
    ErrorHandler:RecordManualError(result, "RISKY_FUNC")
end

-- Wrap function
local SafeFunc = ErrorHandler:WrapFunction(function()
    -- Your code
end, "WRAPPED_FUNC")
SafeFunc()
```

## Persistence

```lua
-- Export
MyAddonDB.errors = ErrorHandler:ExportToSavedVariables()

-- Import
ErrorHandler:ImportFromSavedVariables(MyAddonDB.errors)
```

## Cleanup

```lua
-- Clear all
ErrorHandler:ClearErrors()

-- Clear by type
local removed = ErrorHandler:ClearErrorsByType("TEST_ERROR")

-- Remove old (older than retention period)
local removed = ErrorHandler:CleanupOldErrors()
```

## Output

```lua
-- Print to chat
ErrorHandler:PrintRecentErrors(5)

-- Format single error
local error = ErrorHandler:GetRecentErrors(1)[1]
local formatted = ErrorHandler:FormatError(error, true)  -- with stack
local formatted = ErrorHandler:FormatError(error, false) -- without stack
```

## Error Record

```lua
{
    type = "ADDON_ACTION_BLOCKED",
    message = "Addon 'X' tried to call protected function 'Y'",
    timestamp = 1701878400,    -- First occurrence
    lastSeen = 1701878460,     -- Last occurrence
    count = 5,                 -- Number of times seen
    stack = {                  -- Stack trace (array of strings)
        "file.lua:123: in function",
        "file2.lua:456: in function"
    }
}
```

## Events Captured

- `ADDON_ACTION_BLOCKED` - Protected function call during combat
- `ADDON_ACTION_FORBIDDEN` - Forbidden function call
- `LUA_WARNING` - Lua runtime warning

## Common Patterns

### SavedVariables Integration

```lua
function Addon:OnInitialize()
    if MyAddonDB.errors then
        ErrorHandler:ImportFromSavedVariables(MyAddonDB.errors)
    end
end

function Addon:OnDisable()
    MyAddonDB.errors = ErrorHandler:ExportToSavedVariables()
end
```

### Error Monitoring

```lua
C_Timer.NewTicker(300, function()
    local stats = ErrorHandler:GetErrorStats()
    if stats.currentlyStored > 50 then
        print("WARNING: Many errors detected!")
    end
end)
```

### Slash Commands

```lua
SLASH_ERRORS1 = "/errors"
SlashCmdList["ERRORS"] = function(msg)
    if msg == "stats" then
        local stats = ErrorHandler:GetErrorStats()
        print("Total:", stats.totalCaptured)
        print("Stored:", stats.currentlyStored)
    elseif msg == "recent" then
        ErrorHandler:PrintRecentErrors(10)
    elseif msg == "clear" then
        ErrorHandler:ClearErrors()
    end
end
```

### Find Frequent Errors

```lua
local function GetFrequentErrors(minCount)
    local errors = ErrorHandler:GetErrors()
    local frequent = {}
    for _, error in ipairs(errors) do
        if error.count >= minCount then
            table.insert(frequent, error)
        end
    end
    return frequent
end
```

### Export for Bug Reports

```lua
local function ExportErrorReport()
    local errors = ErrorHandler:GetRecentErrors(20)
    local lines = {"===== Error Report ====="}

    for _, error in ipairs(errors) do
        table.insert(lines, ErrorHandler:FormatError(error))
    end

    return table.concat(lines, "\n")
end
```

## Performance

- Memory: ~2KB per error (with 10-line stack)
- Default capacity: 100 errors = ~200KB
- Hash lookup: O(1)
- Retrieval: O(n) where n = stored errors

## Tips

1. Use meaningful error types for easy filtering
2. Enable persistence for cross-session debugging
3. Adjust retention based on update cycle
4. Wrap risky functions with WrapFunction()
5. Keep logging disabled in production
6. Clean old errors periodically
7. Check stats regularly for patterns
