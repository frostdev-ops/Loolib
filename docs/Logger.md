# Loolib Logger Documentation

## Overview

The **Logger** module (`Debug/Logger.lua`) provides a multi-level logging system for the Loolib addon library. It enables color-coded console output at different severity levels (DEBUG, INFO, WARN, ERROR), making it easy to trace execution and diagnose issues during development and in production.

### Purpose

Logger simplifies debugging by:
- **Filtering messages by severity** - Control verbosity with log levels
- **Color-coded output** - Quickly identify message importance in chat
- **Consistent formatting** - All logs display with a uniform `[Loolib LEVEL]` prefix
- **Minimal overhead** - Only outputs messages at or above the current level
- **Assertions** - Built-in assertion checking with error logging

### When to Use

- **Development**: Set level to DEBUG during active development to see all diagnostic messages
- **Testing**: Set level to INFO to capture normal operation and warnings
- **Production**: Set level to WARN or ERROR to minimize spam while catching problems
- **Bug investigation**: Use DEBUG level to trace execution flow and variable states

---

## Quick Start

### Basic Setup

```lua
-- Get the Logger module
local Loolib = LibStub("Loolib")
local Logger = Loolib:GetModule("Logger")

-- Log at various levels
Logger:Info("Feature initialized")
Logger:Debug("Detailed state:", myVariable)
Logger:Warn("Deprecated function used")
Logger:Error("Something went wrong:", errorMessage)
```

### Setting Log Level

```lua
-- Set level by name
Logger:SetLevel("INFO")  -- Only INFO, WARN, ERROR will show

-- Set level by number (0=DEBUG, 1=INFO, 2=WARN, 3=ERROR)
Logger:SetLevel(1)  -- Same as "INFO"

-- Check current level
local level = Logger:GetLevel()          -- Returns: 1
local levelName = Logger:GetLevelName()  -- Returns: "INFO"
```

---

## API Reference

### Configuration Functions

#### `Logger:SetLevel(level)`
**Description**: Set the current logging level.

**Parameters**:
- `level` (string|number): Log level to set
  - String: `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"` (case-insensitive)
  - Number: `0` (DEBUG), `1` (INFO), `2` (WARN), `3` (ERROR)

**Returns**: None

**Errors**: Raises error if level is invalid

**Example**:
```lua
Logger:SetLevel("DEBUG")  -- Most verbose
Logger:SetLevel(3)        -- ERROR only
```

#### `Logger:GetLevel()`
**Description**: Get the current log level as a number.

**Parameters**: None

**Returns**: number - Current level (0-3)

**Example**:
```lua
if Logger:GetLevel() <= 0 then
    -- We're in DEBUG mode
end
```

#### `Logger:GetLevelName()`
**Description**: Get the current log level as a string name.

**Parameters**: None

**Returns**: string - Level name ("DEBUG", "INFO", "WARN", "ERROR")

**Example**:
```lua
print("Current log level:", Logger:GetLevelName())
```

### Logging Functions

#### `Logger:Debug(...)`
**Description**: Log a message at DEBUG level (most verbose).

**Parameters**:
- `...` (any): Values to log (converted to strings)

**Returns**: None

**Color**: Gray (#888888)

**Example**:
```lua
Logger:Debug("Function called with args:", arg1, arg2)
Logger:Debug("Current state:", state, "HP:", health)
```

#### `Logger:Info(...)`
**Description**: Log a message at INFO level (default).

**Parameters**:
- `...` (any): Values to log

**Returns**: None

**Color**: White (#FFFFFF)

**Example**:
```lua
Logger:Info("Addon loaded successfully")
Logger:Info("Player entered zone:", zoneName)
```

#### `Logger:Warn(...)`
**Description**: Log a message at WARN level.

**Parameters**:
- `...` (any): Values to log

**Returns**: None

**Color**: Orange (#FFAA00)

**Example**:
```lua
Logger:Warn("Deprecated API used")
Logger:Warn("Performance impact detected:", timeMs, "ms")
```

#### `Logger:Error(...)`
**Description**: Log a message at ERROR level (least verbose).

**Parameters**:
- `...` (any): Values to log

**Returns**: None

**Color**: Red (#FF0000)

**Example**:
```lua
Logger:Error("Failed to load configuration")
Logger:Error("Invalid argument:", argName, "expected", expectedType)
```

### Assertion Functions

#### `Logger:Assert(condition, message)`
**Description**: Assert that a condition is true. Logs an error and raises an exception if false.

**Parameters**:
- `condition` (boolean): The condition to check
- `message` (string, optional): Custom error message (default: "Assertion failed")

**Returns**: boolean - The condition value (true if passes)

**Errors**: Raises Lua error if condition is false

**Example**:
```lua
-- Simple assertion
Logger:Assert(player ~= nil, "Player not found")

-- Check function arguments
function CreateWidget(parent)
    Logger:Assert(parent, "parent frame required")
    -- ... rest of function
end

-- Validate state
if not initialized then
    Logger:Assert(false, "Module not initialized before use")
end
```

---

## Usage Examples

### Example 1: Feature Development with Progressive Details

```lua
local Loolib = LibStub("Loolib")
local Logger = Loolib:GetModule("Logger")

-- During development
Logger:SetLevel("DEBUG")

function InitializeFeature()
    Logger:Debug("Starting initialization")

    local config = LoadConfig()
    Logger:Debug("Config loaded:", config)

    local success = SetupUI()
    Logger:Debug("UI setup result:", success)

    if success then
        Logger:Info("Feature initialized successfully")
    else
        Logger:Error("Feature initialization failed")
    end
end
```

### Example 2: API Wrapper with Logging

```lua
local Loolib = LibStub("Loolib")
local Logger = Loolib:GetModule("Logger")

local API = {}

function API:GetPlayerData()
    Logger:Debug("Fetching player data")

    local data = {}
    data.name = GetUnitName("player")
    data.health = UnitHealth("player")
    data.maxHealth = UnitHealthMax("player")

    Logger:Debug("Player data retrieved:", data.name,
                 "Health:", data.health .. "/" .. data.maxHealth)

    return data
end

function API:ApplyBuff(unit, buffID)
    Logger:Assert(unit ~= nil, "Unit required")
    Logger:Assert(buffID ~= nil, "Buff ID required")

    Logger:Debug("Applying buff", buffID, "to", unit)

    local result = DoSomething(unit, buffID)

    if result then
        Logger:Info("Buff applied:", buffID)
    else
        Logger:Warn("Buff application may have failed")
    end

    return result
end
```

### Example 3: State Machine with Level-Appropriate Logging

```lua
local Loolib = LibStub("Loolib")
local Logger = Loolib:GetModule("Logger")

local StateMachine = {
    state = "IDLE",
    transitions = {}
}

function StateMachine:TransitionTo(newState)
    Logger:Debug("Transition requested: " .. self.state .. " -> " .. newState)

    if not self.transitions[self.state] then
        Logger:Error("No transitions defined for state:", self.state)
        return false
    end

    if not self.transitions[self.state][newState] then
        Logger:Warn("Invalid transition:", self.state, "->", newState)
        return false
    end

    local oldState = self.state
    self.state = newState

    Logger:Info("State transitioned:", oldState, "->", newState)
    return true
end
```

### Example 4: Toggle Logging During Gameplay

```lua
-- Create a slash command to toggle debug logging
local Loolib = LibStub("Loolib")
local Logger = Loolib:GetModule("Logger")

SLASH_DEBUGLOG1 = "/debuglog"
SlashCmdList["DEBUGLOG"] = function(msg)
    if msg == "on" or msg == "debug" then
        Logger:SetLevel("DEBUG")
        Logger:Info("Debug logging enabled")
    elseif msg == "off" or msg == "info" then
        Logger:SetLevel("INFO")
        Logger:Info("Normal logging enabled")
    else
        local level = Logger:GetLevelName()
        Logger:Info("Current log level:", level)
    end
end
```

### Example 5: Conditional Logging Based on Configuration

```lua
local Loolib = LibStub("Loolib")
local Logger = Loolib:GetModule("Logger")

local Config = {
    debugMode = false,
    verbose = false
}

function Config:UpdateLogging()
    if self.debugMode then
        Logger:SetLevel("DEBUG")
        Logger:Info("Debug mode enabled")
    elseif self.verbose then
        Logger:SetLevel("INFO")
    else
        Logger:SetLevel("WARN")
    end
end

-- Toggle debug from addon command
function EnableDebugMode()
    Config.debugMode = true
    Config:UpdateLogging()
    Logger:Debug("Debug mode is now ACTIVE")
end
```

---

## Best Practices

### Production vs Development

**Development Environment:**
```lua
-- Start with DEBUG to see everything
Logger:SetLevel("DEBUG")
-- This helps trace issues and understand flow

function DebugFeature()
    Logger:Debug("Step 1: Initializing")
    -- ... code ...
    Logger:Debug("Step 2: Processing data")
    -- ... code ...
    Logger:Debug("Step 3: Complete")
end
```

**Production Environment:**
```lua
-- Keep level at WARN or ERROR to minimize spam
Logger:SetLevel("WARN")
-- Only significant issues appear in chat

-- Use DEBUG for known problems only
if encounteringKnownIssue then
    Logger:SetLevel("DEBUG")
    Logger:Debug("Known issue details:", details)
    Logger:SetLevel("WARN")  -- Restore normal level
end
```

### Performance Considerations

1. **Avoid Expensive Operations in Log Arguments**:
   ```lua
   -- BAD: Function call happens even if DEBUG disabled
   Logger:Debug("Result:", ExpensiveFunction())

   -- GOOD: Check level first for expensive operations
   if Logger:GetLevel() <= 0 then  -- DEBUG
       Logger:Debug("Result:", ExpensiveFunction())
   end
   ```

2. **Keep Message Formatting Simple**:
   ```lua
   -- Good: Simple string concatenation
   Logger:Info("Player:", playerName, "at", x, y, z)

   -- Less ideal: Complex string formatting
   Logger:Info(string.format("Player: %s at (%.2f, %.2f, %.2f)",
                            playerName, x, y, z))
   ```

3. **Message Ordering**:
   ```lua
   -- Log in logical order for tracing
   Logger:Debug("Starting operation")
   Logger:Debug("Input validation:", input)
   Logger:Debug("Processing step 1")
   Logger:Debug("Processing step 2")
   Logger:Info("Operation complete")
   ```

### Logging Strategy

**For Tracing Execution**:
```lua
function ComplexOperation(param1, param2)
    Logger:Debug("ComplexOperation called with:", param1, param2)

    local step1 = ProcessStep1(param1)
    Logger:Debug("Step 1 result:", step1)

    local step2 = ProcessStep2(step1, param2)
    Logger:Debug("Step 2 result:", step2)

    Logger:Info("ComplexOperation completed")
    return step2
end
```

**For Critical Errors**:
```lua
function CriticalOperation()
    if not ValidateState() then
        Logger:Error("Critical state validation failed")
        return nil
    end

    local result = DoWork()
    if not result then
        Logger:Error("Critical work operation failed")
        return nil
    end

    return result
end
```

**For Warnings About Unusual Conditions**:
```lua
function LoadData(path)
    if not FileExists(path) then
        Logger:Warn("File not found, using defaults:", path)
        return GetDefaults()
    end

    Logger:Debug("Loading from:", path)
    local data = ReadFile(path)
    Logger:Info("Data loaded successfully")
    return data
end
```

### Color Reference

| Level | Color  | Hex     | Use Case |
|-------|--------|---------|----------|
| DEBUG | Gray   | #888888 | Detailed execution flow, variable values |
| INFO  | White  | #FFFFFF | Normal operation, status changes |
| WARN  | Orange | #FFAA00 | Unusual conditions, performance issues |
| ERROR | Red    | #FF0000 | Failed operations, critical problems |

### Assertion Best Practices

```lua
-- Use assertions to catch programming errors early
function SetupFrame(parent, width, height)
    Logger:Assert(parent, "parent frame is required")
    Logger:Assert(width and width > 0, "width must be positive")
    Logger:Assert(height and height > 0, "height must be positive")

    -- Safe to proceed if we get here
    parent:SetSize(width, height)
end

-- Assertions should validate preconditions
function ProcessQueue()
    Logger:Assert(#queue > 0, "queue must not be empty")

    local item = table.remove(queue, 1)
    return Process(item)
end

-- Use for invariant checking
function CompleteTransaction()
    Logger:Assert(transactionOpen, "transaction must be open")

    CommitTransaction()
    transactionOpen = false
end
```

---

## Common Patterns

### Pattern 1: Initialization Logging
```lua
function OnAddonLoaded(addonName)
    if addonName == "MyAddon" then
        Logger:Info("MyAddon loaded")
        Logger:Debug("Environment setup")
        -- Initialize modules
        Logger:Info("All systems initialized")
    end
end
```

### Pattern 2: Error Handling with Logging
```lua
local success, error = pcall(function()
    return PerformRiskyOperation()
end)

if not success then
    Logger:Error("Operation failed:", error)
else
    Logger:Info("Operation completed successfully")
end
```

### Pattern 3: Conditional Feature Logging
```lua
function EnableFeature(featureName)
    Logger:Debug("Enabling feature:", featureName)

    if IsFeatureSupported(featureName) then
        Features[featureName] = true
        Logger:Info("Feature enabled:", featureName)
    else
        Logger:Warn("Feature not supported:", featureName)
    end
end
```

### Pattern 4: Performance Monitoring
```lua
function MeasurePerformance()
    Logger:Debug("Performance measurement started")

    local startTime = GetTime()
    local result = DoWork()
    local elapsed = GetTime() - startTime

    if elapsed > 0.1 then
        Logger:Warn("Slow operation:", elapsed .. "ms")
    else
        Logger:Debug("Operation time:", elapsed .. "ms")
    end

    return result
end
```

---

## Troubleshooting

### Logs Not Appearing
- **Problem**: Logger output doesn't show in chat
- **Solution**:
  - Verify `DEFAULT_CHAT_FRAME` exists (check after PLAYER_LOGIN event)
  - Check that log level is set to show the message: `Logger:SetLevel("DEBUG")`
  - Verify the Logger module is properly registered: `Loolib:GetModule("Logger")`

### Too Much Output
- **Problem**: Chat flooded with DEBUG messages
- **Solution**: Lower the log level: `Logger:SetLevel("INFO")` or `Logger:SetLevel("WARN")`

### Can't Debug Performance Issue
- **Problem**: Need more details but DEBUG level too noisy
- **Solution**: Check log level before expensive operations:
  ```lua
  if Logger:GetLevel() <= 0 then
      Logger:Debug("Expensive debug info:", ExpensiveCall())
  end
  ```

### Assertion Stopping Addon
- **Problem**: `Logger:Assert()` is breaking the addon flow
- **Solution**: Use conditional assertions only for actual errors:
  ```lua
  -- Only assert for true invariants, not user errors
  Logger:Assert(internalState ~= nil, "State corrupted")  -- Good
  Logger:Assert(userInput ~= nil, "Missing input")        -- Better as a regular check
  ```
