# Timer Module

The Timer module provides AceTimer-3.0 compatible timer scheduling for WoW addons. It enables scheduling of one-shot and repeating timers with support for both function and method callbacks.

## Overview

### What It Does

The Timer module wraps WoW's `C_Timer` API to provide:
- One-shot timers that fire once after a delay
- Repeating timers that fire continuously at intervals
- Timer cancellation and cleanup
- Query functions for timer state and time remaining
- Automatic handle management for tracking timers

### Common Use Cases

- **Delayed initialization**: Wait for game systems to load before running code
- **Cooldown management**: Track ability cooldowns and trigger updates
- **Throttling**: Limit how often expensive operations run
- **Periodic updates**: Update UI elements at regular intervals
- **Delayed cleanup**: Clean up resources after a delay

### Key Features

- **Callback flexibility**: Use function references or method names (strings)
- **Argument passing**: Pass arguments to callbacks when scheduling
- **Time queries**: Check remaining time or if a timer is active
- **Batch cleanup**: Cancel all timers at once
- **Memory safe**: Properly handles timer cancellation to prevent leaks

## Quick Start

```lua
-- Mix Timer into your addon
local MyAddon = LoolibCreateFromMixins(LoolibTimerMixin)

-- Schedule a one-shot timer
local handle = MyAddon:ScheduleTimer(function()
    print("5 seconds elapsed!")
end, 5)

-- Schedule a repeating timer
local repeater = MyAddon:ScheduleRepeatingTimer(function()
    print("Tick every 2 seconds")
end, 2)

-- Cancel timers when done
MyAddon:CancelTimer(repeater)

-- Cleanup on addon disable
function MyAddon:OnDisable()
    self:CancelAllTimers()
end
```

## API Reference

### Timer Creation

#### ScheduleTimer(callback, delay, ...)

Schedule a one-shot timer that fires once after the specified delay.

**Parameters:**
- `callback` (function|string): Function to call or method name to invoke
- `delay` (number): Seconds to wait before firing (must be > 0)
- `...`: Optional arguments to pass to the callback

**Returns:**
- `string`: Timer handle for cancellation

**Example:**
```lua
-- Function callback
local handle = self:ScheduleTimer(function(msg)
    print(msg)
end, 3, "Hello after 3 seconds")

-- Method callback (calls self:UpdateDisplay())
local handle = self:ScheduleTimer("UpdateDisplay", 1)

-- Method with arguments (calls self:ShowMessage(msg, color))
local handle = self:ScheduleTimer("ShowMessage", 2, "Warning!", RED_FONT_COLOR)
```

#### ScheduleRepeatingTimer(callback, delay, ...)

Schedule a repeating timer that fires continuously at the specified interval.

**Parameters:**
- `callback` (function|string): Function to call or method name to invoke
- `delay` (number): Seconds between each execution (must be > 0)
- `...`: Optional arguments to pass to the callback

**Returns:**
- `string`: Timer handle for cancellation

**Example:**
```lua
-- Function callback
local handle = self:ScheduleRepeatingTimer(function()
    self:CheckStatus()
end, 5)

-- Method callback (calls self:RefreshUI() every 2 seconds)
local handle = self:ScheduleRepeatingTimer("RefreshUI", 2)

-- Method with arguments
local handle = self:ScheduleRepeatingTimer("UpdateCounter", 1, "myCounter")
```

### Timer Cancellation

#### CancelTimer(handle)

Cancel a scheduled timer by its handle.

**Parameters:**
- `handle` (string): Timer handle returned from ScheduleTimer or ScheduleRepeatingTimer

**Returns:**
- `boolean`: True if cancelled, false if timer not found

**Example:**
```lua
local handle = self:ScheduleTimer(callback, 5)

-- Cancel before it fires
if self:CancelTimer(handle) then
    print("Timer cancelled successfully")
end
```

#### CancelAllTimers()

Cancel all active timers for this object. Essential for cleanup on addon disable or object destruction.

**Parameters:** None

**Returns:** None

**Example:**
```lua
function MyAddon:OnDisable()
    -- Cleanup all timers
    self:CancelAllTimers()
end
```

### Timer Query

#### TimeLeft(handle)

Get the remaining time before a timer fires.

**Parameters:**
- `handle` (string): Timer handle

**Returns:**
- `number|nil`: Seconds remaining (minimum 0), or nil if timer not found

**Example:**
```lua
local handle = self:ScheduleTimer(callback, 10)

-- Check remaining time
local remaining = self:TimeLeft(handle)
if remaining then
    print(string.format("%.1f seconds remaining", remaining))
end
```

#### IsTimerActive(handle)

Check if a timer exists and is active.

**Parameters:**
- `handle` (string): Timer handle

**Returns:**
- `boolean`: True if timer exists and is active

**Example:**
```lua
if not self:IsTimerActive(handle) then
    -- Timer finished or was cancelled, schedule a new one
    handle = self:ScheduleTimer(callback, 5)
end
```

#### GetActiveTimers()

Get all active timer handles for this object.

**Parameters:** None

**Returns:**
- `table`: Array of timer handles

**Example:**
```lua
local handles = self:GetActiveTimers()
print(string.format("Active timers: %d", #handles))

for _, handle in ipairs(handles) do
    local remaining = self:TimeLeft(handle)
    print(string.format("Timer %s: %.1fs remaining", handle, remaining))
end
```

#### GetTimerCount()

Get the count of active timers.

**Parameters:** None

**Returns:**
- `number`: Number of active timers

**Example:**
```lua
local count = self:GetTimerCount()
if count > 10 then
    print("Warning: Many active timers!")
end
```

## Usage Examples

### One-Shot Timers

```lua
-- Simple delay
self:ScheduleTimer(function()
    print("Ready!")
end, 3)

-- Delayed initialization
function MyAddon:PLAYER_LOGIN()
    -- Wait for UI to load
    self:ScheduleTimer("InitializeUI", 0.5)
end

function MyAddon:InitializeUI()
    -- Safe to create UI now
    self:CreateFrames()
end

-- Delayed cleanup
function MyAddon:OnItemDeleted()
    -- Wait before refreshing to batch multiple deletions
    if self.cleanupTimer then
        self:CancelTimer(self.cleanupTimer)
    end

    self.cleanupTimer = self:ScheduleTimer("RefreshDisplay", 0.2)
end
```

### Repeating Timers

```lua
-- Periodic UI update
function MyAddon:StartMonitoring()
    self.updateTimer = self:ScheduleRepeatingTimer("UpdateDisplay", 1)
end

function MyAddon:StopMonitoring()
    if self.updateTimer then
        self:CancelTimer(self.updateTimer)
        self.updateTimer = nil
    end
end

function MyAddon:UpdateDisplay()
    -- Called every second
    self.frame.text:SetText(GetTime())
end

-- Status checker
function MyAddon:PLAYER_ENTERING_WORLD()
    self:ScheduleRepeatingTimer(function()
        if UnitAffectingCombat("player") then
            self:OnCombatActive()
        end
    end, 0.5)
end
```

### Canceling Timers

```lua
-- Cancel specific timer
function MyAddon:StopCountdown()
    if self.countdownTimer then
        local cancelled = self:CancelTimer(self.countdownTimer)
        if cancelled then
            print("Countdown stopped")
        end
        self.countdownTimer = nil
    end
end

-- Cancel all timers on disable
function MyAddon:OnDisable()
    self:CancelAllTimers()
    print("All timers cleaned up")
end

-- Replace timer pattern
function MyAddon:StartAutoSave()
    -- Cancel existing timer if present
    if self.autoSaveTimer then
        self:CancelTimer(self.autoSaveTimer)
    end

    -- Start new timer
    self.autoSaveTimer = self:ScheduleRepeatingTimer("SaveData", 300)
end
```

### Using TimeLeft()

```lua
-- Display countdown
function MyAddon:ShowCooldown()
    local handle = self:ScheduleTimer("OnCooldownReady", 10)

    self:ScheduleRepeatingTimer(function()
        local remaining = self:TimeLeft(handle)
        if remaining then
            self.cooldownText:SetText(string.format("Ready in %.1fs", remaining))
        else
            self.cooldownText:SetText("Ready!")
        end
    end, 0.1)
end

-- Conditional logic based on time
function MyAddon:CheckTimer()
    local remaining = self:TimeLeft(self.productionTimer)

    if remaining and remaining < 5 then
        print("Production finishing soon!")
        self:PlayWarningSound()
    end
end

-- Progress bar update
function MyAddon:UpdateProgressBar()
    local remaining = self:TimeLeft(self.taskTimer)
    if remaining then
        local progress = 1 - (remaining / self.taskDuration)
        self.progressBar:SetValue(progress)
    end
end
```

### Integration with Events

```lua
-- Delay after event
function MyAddon:BAG_UPDATE()
    -- Cancel pending update
    if self.bagUpdateTimer then
        self:CancelTimer(self.bagUpdateTimer)
    end

    -- Schedule new update after brief delay
    self.bagUpdateTimer = self:ScheduleTimer("ProcessBagChanges", 0.5)
end

-- Timeout pattern
function MyAddon:StartWaiting()
    self.waitingForResponse = true

    self.timeoutTimer = self:ScheduleTimer(function()
        if self.waitingForResponse then
            print("Timed out waiting for response")
            self:OnTimeout()
        end
    end, 30)
end

function MyAddon:OnResponseReceived()
    self.waitingForResponse = false
    self:CancelTimer(self.timeoutTimer)
end
```

## Patterns

### Delayed Initialization

Wait for game systems to be ready before initializing:

```lua
function MyAddon:ADDON_LOADED(addonName)
    if addonName == "MyAddon" then
        -- Wait for saved variables to be stable
        self:ScheduleTimer("LoadSavedData", 0.1)
    end
end

function MyAddon:LoadSavedData()
    -- Safe to access saved variables now
    self.db = MyAddonDB or {}
    self:ApplySettings()
end
```

### Throttling Expensive Operations

Limit how often expensive code runs:

```lua
function MyAddon:OnDataChanged()
    -- Cancel pending update
    if self.updateTimer then
        self:CancelTimer(self.updateTimer)
    end

    -- Schedule update after brief delay
    -- Multiple rapid changes will only trigger one update
    self.updateTimer = self:ScheduleTimer(function()
        self:RecalculateStatistics() -- Expensive operation
        self.updateTimer = nil
    end, 0.5)
end
```

### Batch Processing

Process items in batches over time:

```lua
function MyAddon:ProcessQueueInBatches()
    local BATCH_SIZE = 10
    local BATCH_DELAY = 0.1

    local function ProcessBatch()
        for i = 1, BATCH_SIZE do
            local item = table.remove(self.queue, 1)
            if not item then
                print("Queue processing complete")
                return
            end

            self:ProcessItem(item)
        end

        -- Schedule next batch
        if #self.queue > 0 then
            self:ScheduleTimer(ProcessBatch, BATCH_DELAY)
        end
    end

    ProcessBatch()
end
```

### Cooldown Management

Track and display cooldowns:

```lua
function MyAddon:StartCooldown(duration)
    self.cooldownHandle = self:ScheduleTimer("OnCooldownExpired", duration)

    -- Update display every 0.1 seconds
    self.cooldownDisplayTimer = self:ScheduleRepeatingTimer(function()
        local remaining = self:TimeLeft(self.cooldownHandle)
        if remaining and remaining > 0 then
            self:UpdateCooldownDisplay(remaining)
        else
            self:CancelTimer(self.cooldownDisplayTimer)
        end
    end, 0.1)
end

function MyAddon:OnCooldownExpired()
    self:UpdateCooldownDisplay(0)
    print("Cooldown ready!")
end
```

### Periodic Checks

Monitor game state at intervals:

```lua
function MyAddon:StartMonitoring()
    self.monitorTimer = self:ScheduleRepeatingTimer(function()
        -- Check player state
        if UnitIsDeadOrGhost("player") then
            self:OnPlayerDead()
        end

        -- Check resources
        local mana = UnitPower("player", Enum.PowerType.Mana)
        if mana < 1000 then
            self:OnLowMana()
        end

        -- Check buffs
        local hasBuff = self:PlayerHasBuff("Fortitude")
        if not hasBuff then
            self:OnMissingBuff()
        end
    end, 2)
end
```

## Best Practices

### Timer Cleanup

Always clean up timers to prevent memory leaks:

```lua
-- Store handles for later cleanup
function MyAddon:OnEnable()
    self.updateTimer = self:ScheduleRepeatingTimer("Update", 1)
    self.checkTimer = self:ScheduleRepeatingTimer("Check", 5)
end

function MyAddon:OnDisable()
    -- Cancel all timers
    self:CancelAllTimers()

    -- Clear handles
    self.updateTimer = nil
    self.checkTimer = nil
end
```

### Memory Leaks to Avoid

**Don't:** Create timers without storing handles

```lua
-- BAD: No way to cancel this
function MyAddon:StartBadTimer()
    self:ScheduleRepeatingTimer(function()
        -- This will run forever!
    end, 1)
end
```

**Do:** Store handles and clean up

```lua
-- GOOD: Can be cancelled
function MyAddon:StartGoodTimer()
    self.timer = self:ScheduleRepeatingTimer(function()
        -- Can be stopped
    end, 1)
end

function MyAddon:Stop()
    if self.timer then
        self:CancelTimer(self.timer)
        self.timer = nil
    end
end
```

**Don't:** Forget to cancel replaced timers

```lua
-- BAD: Creates multiple timers
function MyAddon:Restart()
    self.timer = self:ScheduleTimer(callback, 5)
    -- Old timer still running!
    self.timer = self:ScheduleTimer(callback, 5)
end
```

**Do:** Cancel before replacing

```lua
-- GOOD: Cancels old timer first
function MyAddon:Restart()
    if self.timer then
        self:CancelTimer(self.timer)
    end
    self.timer = self:ScheduleTimer(callback, 5)
end
```

### Performance Considerations

**Use appropriate delays:**
- Very short delays (< 0.1s) may impact performance
- Use the longest acceptable delay for your use case
- Consider frame events for sub-second precision

```lua
-- For high-precision updates, use OnUpdate instead
frame:SetScript("OnUpdate", function(self, elapsed)
    -- Called every frame
end)

-- For normal updates, use reasonable timer intervals
self:ScheduleRepeatingTimer("Update", 1) -- 1 second is fine for most cases
```

**Batch rapid events:**

```lua
-- BAD: Timer for every event
function MyAddon:BAG_UPDATE()
    self:ScheduleTimer("UpdateBags", 0.1)
end

-- GOOD: Cancel and reschedule
function MyAddon:BAG_UPDATE()
    if self.bagTimer then
        self:CancelTimer(self.bagTimer)
    end
    self.bagTimer = self:ScheduleTimer("UpdateBags", 0.3)
end
```

**Avoid closures capturing large objects:**

```lua
-- BAD: Captures entire large table
local largeTable = {...} -- Huge data structure
self:ScheduleTimer(function()
    print(largeTable.someValue)
end, 5)

-- GOOD: Capture only what you need
local value = largeTable.someValue
self:ScheduleTimer(function()
    print(value)
end, 5)
```

### When to Use Timers vs Other Solutions

**Use Timers for:**
- Delayed execution
- Periodic updates (1+ seconds)
- Cooldown tracking
- Timeout patterns

**Use Frame OnUpdate for:**
- Very frequent updates (every frame)
- Animation
- Sub-second precision requirements

**Use Events for:**
- Reacting to game state changes
- Immediate response to game events

**Use Buckets for:**
- Batching rapid-fire events
- Throttling event handlers

## Technical Details

### C_Timer Integration

The Timer module wraps WoW's C_Timer API:

- **One-shot timers**: Use `C_Timer.After(delay, callback)`
- **Repeating timers**: Use `C_Timer.NewTicker(delay, callback)`
- **Ticker cancellation**: Call `ticker:Cancel()` on the ticker object

### Handle Management

Timers are tracked using unique handles:

```lua
-- Handle generation
local timerHandleCounter = 0
local function GenerateTimerHandle()
    timerHandleCounter = timerHandleCounter + 1
    return "LoolibTimer" .. timerHandleCounter
end
```

Each timer is stored in `self.timers[handle]` with metadata:
- `handle`: Unique identifier
- `callback`: Function or method name
- `endTime`: GetTime() + delay (for TimeLeft calculation)
- `repeating`: Boolean flag
- `delay`: Interval for repeating timers
- `args`: Captured arguments
- `argCount`: Number of arguments
- `ticker`: C_Timer ticker object (repeating only)

### Callback Execution

**Function callbacks:**
```lua
callback(unpack(args, 1, argCount))
```

**Method callbacks (string):**
```lua
local method = self[callback]
method(self, unpack(args, 1, argCount))
```

### Time Calculations

Time remaining is calculated using `GetTime()`:

```lua
local remaining = timerInfo.endTime - GetTime()
return max(0, remaining) -- Never negative
```

For repeating timers, `endTime` is updated after each execution:
```lua
timerInfo.endTime = GetTime() + delay
```

### Memory Management

- One-shot timers remove themselves from storage before firing
- Repeating timers remain in storage until cancelled
- `CancelAllTimers()` clears the entire timer storage table
- Cancelled timers are checked in callbacks to prevent execution
