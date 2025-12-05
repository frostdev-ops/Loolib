# Bucket Module

The Bucket module provides AceBucket-3.0 compatible event and message batching for WoW addons. It throttles rapid-fire events by collecting them over an interval and firing a single callback with aggregated data.

## Overview

### What It Does

The Bucket module collects multiple occurrences of events or messages over a time interval and fires a single callback with aggregated data. This is essential for handling rapid-fire events that would otherwise overwhelm your addon.

Key capabilities:
- Batch WoW game events (like BAG_UPDATE, UNIT_AURA)
- Batch custom messages (via Loolib's EventRegistry)
- Automatic timer management (uses Timer module internally)
- Count tracking per event/message type
- Manual bucket firing for immediate processing

### Common Use Cases

- **Bag updates**: BAG_UPDATE fires multiple times per action - batch them
- **Unit aura changes**: UNIT_AURA fires for every buff/debuff change
- **Combat log batching**: Group multiple combat events for efficient processing
- **Inventory scanning**: Batch item changes for a single scan
- **UI throttling**: Limit UI updates when data changes rapidly

### Key Features

- **Event bucketing**: Batch WoW game events using EventRegistry
- **Message bucketing**: Batch custom messages/signals
- **Count aggregation**: Track how many times each event fired
- **Automatic timing**: Uses Timer module for interval management
- **Callback flexibility**: Function or method name callbacks
- **Query support**: Check bucket state and current data

## Quick Start

```lua
-- Mix Bucket into your addon (includes Timer automatically)
local MyAddon = LoolibCreateFromMixins(LoolibBucketMixin)

-- Bucket rapid BAG_UPDATE events
local handle = MyAddon:RegisterBucketEvent("BAG_UPDATE", 0.5, function(data)
    print(string.format("Bags updated %d times", data.count))
    -- Refresh UI once instead of many times
    MyAddon:RefreshBagDisplay()
end)

-- Bucket multiple events together
MyAddon:RegisterBucketEvent(
    {"UNIT_HEALTH", "UNIT_POWER", "UNIT_AURA"},
    1,
    "OnUnitStatsChanged"
)

function MyAddon:OnUnitStatsChanged(data)
    print(string.format("%d unit updates:", data.count))
    for event, count in pairs(data.events) do
        print(string.format("  %s: %d times", event, count))
    end
    self:UpdateUnitFrames()
end
```

## API Reference

### Bucket Registration

#### RegisterBucketEvent(events, interval, callback)

Register a bucket for WoW game events.

**Parameters:**
- `events` (string|table): Event name or array of event names
- `interval` (number): Seconds to collect events before firing callback (must be > 0)
- `callback` (function|string): Callback function or method name to invoke

**Returns:**
- `string`: Bucket handle for unregistration

**Callback signature:**
```lua
function callback(data)
    -- data.count (number): Total events received
    -- data.events (table): Map of eventName -> count
end
```

**Example:**
```lua
-- Single event
local handle = self:RegisterBucketEvent("BAG_UPDATE", 0.3, function(data)
    print(string.format("Bags updated %d times", data.count))
end)

-- Multiple events
local handle = self:RegisterBucketEvent(
    {"PLAYER_MONEY", "PLAYER_TRADE_MONEY"},
    1,
    "OnMoneyChanged"
)

function MyAddon:OnMoneyChanged(data)
    -- data.count = total events
    -- data.events["PLAYER_MONEY"] = count
    -- data.events["PLAYER_TRADE_MONEY"] = count
    self:UpdateMoneyDisplay()
end
```

#### RegisterBucketMessage(messages, interval, callback)

Register a bucket for custom messages (via Loolib's CallbackRegistry).

**Parameters:**
- `messages` (string|table): Message name or array of message names
- `interval` (number): Seconds to collect messages before firing callback (must be > 0)
- `callback` (function|string): Callback function or method name to invoke

**Returns:**
- `string`: Bucket handle for unregistration

**Callback signature:**
```lua
function callback(data)
    -- data.count (number): Total messages received
    -- data.events (table): Map of messageName -> count (note: called "events" for consistency)
end
```

**Example:**
```lua
-- Custom message bucket
local handle = self:RegisterBucketMessage("DataChanged", 0.5, function(data)
    print(string.format("Data changed %d times", data.count))
    self:RefreshUI()
end)

-- Fire the message elsewhere in your code
EventRegistry:TriggerEvent("DataChanged")
```

### Bucket Unregistration

#### UnregisterBucket(handle)

Unregister a bucket by its handle. Stops event/message listening and clears any pending data.

**Parameters:**
- `handle` (string): Bucket handle returned from RegisterBucketEvent or RegisterBucketMessage

**Returns:**
- `boolean`: True if unregistered, false if not found

**Example:**
```lua
local handle = self:RegisterBucketEvent("BAG_UPDATE", 0.5, callback)

-- Later, stop bucketing
if self:UnregisterBucket(handle) then
    print("Bucket unregistered")
end
```

#### UnregisterAllBuckets()

Unregister all buckets for this object. Essential for cleanup on addon disable.

**Parameters:** None

**Returns:** None

**Example:**
```lua
function MyAddon:OnDisable()
    self:UnregisterAllBuckets()
end
```

### Bucket Query

#### IsBucketActive(handle)

Check if a bucket exists and is active.

**Parameters:**
- `handle` (string): Bucket handle

**Returns:**
- `boolean`: True if bucket exists and is active

**Example:**
```lua
if self:IsBucketActive(handle) then
    print("Bucket is still collecting events")
end
```

#### GetActiveBuckets()

Get all active bucket handles for this object.

**Parameters:** None

**Returns:**
- `table`: Array of bucket handles

**Example:**
```lua
local handles = self:GetActiveBuckets()
print(string.format("Active buckets: %d", #handles))
```

#### GetBucketCount()

Get the count of active buckets.

**Parameters:** None

**Returns:**
- `number`: Number of active buckets

**Example:**
```lua
local count = self:GetBucketCount()
if count > 5 then
    print("Warning: Many active buckets")
end
```

#### GetBucketData(handle)

Get current data for a bucket without firing it. Useful for inspecting bucket state.

**Parameters:**
- `handle` (string): Bucket handle

**Returns:**
- `table|nil`: Data table `{ count, events }` or nil if not found

**Example:**
```lua
local data = self:GetBucketData(handle)
if data then
    print(string.format("Bucket has %d pending events", data.count))
    for event, count in pairs(data.events) do
        print(string.format("  %s: %d", event, count))
    end
end
```

#### FireBucketNow(handle)

Manually fire a bucket immediately, clearing its data and resetting the timer.

**Parameters:**
- `handle` (string): Bucket handle

**Returns:**
- `boolean`: True if fired, false if not found or no data

**Example:**
```lua
-- Force immediate processing
if self:FireBucketNow(handle) then
    print("Bucket fired manually")
end
```

## Usage Examples

### Event Bucketing

```lua
-- Batch bag updates
function MyAddon:OnEnable()
    self.bagBucket = self:RegisterBucketEvent("BAG_UPDATE", 0.5, "OnBagsBatched")
end

function MyAddon:OnBagsBatched(data)
    print(string.format("Processing %d bag updates", data.count))
    self:ScanAllBags()
end

-- Batch unit events
function MyAddon:StartMonitoring()
    self.unitBucket = self:RegisterBucketEvent(
        {"UNIT_HEALTH", "UNIT_POWER", "UNIT_AURA"},
        0.2,
        function(data)
            print("Unit updates:")
            print("  Health: " .. (data.events["UNIT_HEALTH"] or 0))
            print("  Power: " .. (data.events["UNIT_POWER"] or 0))
            print("  Aura: " .. (data.events["UNIT_AURA"] or 0))
            self:UpdateAllUnitFrames()
        end
    )
end

-- Batch combat log events
function MyAddon:PLAYER_REGEN_DISABLED()
    self.combatBucket = self:RegisterBucketEvent(
        "COMBAT_LOG_EVENT_UNFILTERED",
        1,
        "ProcessCombatBatch"
    )
end

function MyAddon:PLAYER_REGEN_ENABLED()
    self:UnregisterBucket(self.combatBucket)
end

function MyAddon:ProcessCombatBatch(data)
    print(string.format("Processing %d combat events", data.count))
    self:UpdateDamageMeters()
end
```

### Message Bucketing

```lua
-- Bucket custom data changes
function MyAddon:Initialize()
    self.dataBucket = self:RegisterBucketMessage(
        "DataChanged",
        0.3,
        "OnDataBatched"
    )
end

function MyAddon:OnDataBatched(data)
    print(string.format("Data changed %d times", data.count))
    self:RecalculateEverything()
end

-- Trigger the message from anywhere
function MyAddon:UpdateData()
    self.data[key] = value
    EventRegistry:TriggerEvent("DataChanged")
end

-- Bucket multiple message types
self:RegisterBucketMessage(
    {"SettingsChanged", "ProfileChanged", "ThemeChanged"},
    0.5,
    function(data)
        print("Configuration changes:")
        for msg, count in pairs(data.events) do
            print(string.format("  %s: %d times", msg, count))
        end
        self:ReloadUI()
    end
)
```

### Integration Between Timer and Bucket

The Bucket module uses Timer internally, so you have access to both:

```lua
local MyAddon = LoolibCreateFromMixins(LoolibBucketMixin)

function MyAddon:OnEnable()
    -- Use bucket for events
    self.bagBucket = self:RegisterBucketEvent("BAG_UPDATE", 0.5, "OnBags")

    -- Use timer for periodic check
    self.checkTimer = self:ScheduleRepeatingTimer("CheckStatus", 5)

    -- Use timer for delayed initialization
    self:ScheduleTimer("LateInit", 2)
end

function MyAddon:OnDisable()
    -- Cleanup both
    self:UnregisterAllBuckets()
    self:CancelAllTimers()
end

-- Bucket callback
function MyAddon:OnBags(data)
    print(string.format("Bags: %d updates", data.count))
end

-- Timer callbacks
function MyAddon:CheckStatus()
    print("Periodic check")
end

function MyAddon:LateInit()
    print("Late initialization")
end
```

### Manual Bucket Control

```lua
-- Create bucket
local handle = self:RegisterBucketEvent("BAG_UPDATE", 2, callback)

-- Check if it has pending data
local data = self:GetBucketData(handle)
if data and data.count > 10 then
    -- Too many events, process immediately
    self:FireBucketNow(handle)
    print("Forced immediate processing")
end

-- Conditionally unregister
function MyAddon:StopMonitoring()
    if self:IsBucketActive(self.monitorBucket) then
        self:UnregisterBucket(self.monitorBucket)
        print("Stopped monitoring")
    end
end
```

## Patterns

### Delayed Initialization

Wait for events to stabilize before processing:

```lua
function MyAddon:ADDON_LOADED(addonName)
    if addonName == "MyAddon" then
        -- Don't process BAG_UPDATE during login spam
        self:ScheduleTimer(function()
            -- Start bucketing after login settles
            self.bagBucket = self:RegisterBucketEvent(
                "BAG_UPDATE",
                0.5,
                "OnBagsBatched"
            )
        end, 5)
    end
end
```

### Throttling Expensive Operations

Limit how often expensive code runs in response to events:

```lua
-- BAG_UPDATE can fire 20+ times for a single action
-- Bucket to process only once
self:RegisterBucketEvent("BAG_UPDATE", 0.3, function(data)
    -- This expensive operation only runs once per 0.3s
    self:ScanAllBags()
    self:UpdateAuctions()
    self:CalculateNetWorth()
end)
```

### Batch Processing

Collect events and process in a single operation:

```lua
function MyAddon:OnEnable()
    self.auraChanges = {}

    self.auraBucket = self:RegisterBucketEvent("UNIT_AURA", 0.2, function(data)
        -- Process all aura changes at once
        print(string.format("Processing %d aura changes", data.count))

        for unit in pairs(self.auraChanges) do
            self:UpdateUnitAuras(unit)
        end

        self.auraChanges = {}
    end)
end

function MyAddon:UNIT_AURA(unit)
    -- Track which units changed
    self.auraChanges[unit] = true
    -- Bucket will fire after 0.2s of no events
end
```

### Cooldown Management

Track cooldown-related events:

```lua
function MyAddon:StartCooldownTracking()
    self.cooldownBucket = self:RegisterBucketEvent(
        {"SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN"},
        0.5,
        function(data)
            print(string.format("Cooldown events: %d", data.count))
            self:RefreshAllCooldowns()
        end
    )
end
```

### Dynamic Bucket Control

Enable/disable bucketing based on conditions:

```lua
function MyAddon:PLAYER_REGEN_DISABLED()
    -- Start bucketing in combat
    self.combatBucket = self:RegisterBucketEvent(
        "COMBAT_LOG_EVENT_UNFILTERED",
        0.5,
        "OnCombatBatch"
    )
end

function MyAddon:PLAYER_REGEN_ENABLED()
    -- Stop bucketing out of combat
    if self.combatBucket then
        -- Process any remaining events
        self:FireBucketNow(self.combatBucket)
        -- Then unregister
        self:UnregisterBucket(self.combatBucket)
        self.combatBucket = nil
    end
end
```

## Best Practices

### Bucket Cleanup

Always clean up buckets to prevent memory leaks:

```lua
-- Store handles for cleanup
function MyAddon:OnEnable()
    self.bagBucket = self:RegisterBucketEvent("BAG_UPDATE", 0.5, callback)
    self.auraBucket = self:RegisterBucketEvent("UNIT_AURA", 0.2, callback)
end

function MyAddon:OnDisable()
    -- Unregister all buckets
    self:UnregisterAllBuckets()

    -- Clear handles
    self.bagBucket = nil
    self.auraBucket = nil
end
```

### Memory Leaks to Avoid

**Don't:** Forget to unregister buckets

```lua
-- BAD: Bucket keeps listening forever
function MyAddon:StartTemporaryMonitoring()
    self:RegisterBucketEvent("UNIT_HEALTH", 1, callback)
    -- No way to stop this!
end
```

**Do:** Store handle and clean up

```lua
-- GOOD: Can be stopped
function MyAddon:StartTemporaryMonitoring()
    self.tempBucket = self:RegisterBucketEvent("UNIT_HEALTH", 1, callback)
end

function MyAddon:StopMonitoring()
    if self.tempBucket then
        self:UnregisterBucket(self.tempBucket)
        self.tempBucket = nil
    end
end
```

**Don't:** Create multiple buckets for the same events

```lua
-- BAD: Creates duplicate buckets
function MyAddon:UpdateSettings()
    self.bagBucket = self:RegisterBucketEvent("BAG_UPDATE", 0.5, callback)
    -- Old bucket still exists!
    self.bagBucket = self:RegisterBucketEvent("BAG_UPDATE", 0.5, callback)
end
```

**Do:** Unregister before creating new bucket

```lua
-- GOOD: Cleans up old bucket first
function MyAddon:UpdateSettings()
    if self.bagBucket then
        self:UnregisterBucket(self.bagBucket)
    end
    self.bagBucket = self:RegisterBucketEvent("BAG_UPDATE", 0.5, callback)
end
```

### Performance Considerations

**Choose appropriate intervals:**

```lua
-- Very rapid events (multiple per second)
self:RegisterBucketEvent("UNIT_AURA", 0.2, callback) -- Short interval

// Moderate events
self:RegisterBucketEvent("BAG_UPDATE", 0.5, callback) // Medium interval

// Slow events
self:RegisterBucketEvent("PLAYER_MONEY", 2, callback) // Long interval
```

**Don't bucket events that need immediate response:**

```lua
// BAD: Player might be dead for 1 second before we notice!
self:RegisterBucketEvent("PLAYER_DEAD", 1, callback)

// GOOD: Handle immediately
EventRegistry:RegisterEventCallbackWithHandle("PLAYER_DEAD", function()
    self:OnPlayerDead()
end, self)
```

**Batch related events together:**

```lua
-- GOOD: Single bucket for related events
self:RegisterBucketEvent(
    {"UNIT_HEALTH", "UNIT_POWER", "UNIT_AURA"},
    0.2,
    "UpdateUnitFrames"
)

-- LESS EFFICIENT: Separate buckets
self:RegisterBucketEvent("UNIT_HEALTH", 0.2, "UpdateUnitFrames")
self:RegisterBucketEvent("UNIT_POWER", 0.2, "UpdateUnitFrames")
self:RegisterBucketEvent("UNIT_AURA", 0.2, "UpdateUnitFrames")
```

### When to Use Buckets vs Timers

**Use Buckets for:**
- Rapid-fire game events (BAG_UPDATE, UNIT_AURA, etc.)
- Batching multiple related events
- Throttling event-driven updates
- Collecting event counts/statistics

**Use Timers for:**
- Delayed execution (one-shot)
- Periodic checks (independent of events)
- Cooldown tracking
- Timeout patterns

**Use Direct Events for:**
- Events that need immediate response
- Events that fire infrequently
- Critical game state changes

### Common Event Bucketing

Events that benefit from bucketing:

```lua
-- Bag and inventory (fires 10-20 times per action)
self:RegisterBucketEvent("BAG_UPDATE", 0.3, callback)

-- Unit auras (fires for every buff/debuff change)
self:RegisterBucketEvent("UNIT_AURA", 0.2, callback)

-- Combat log (fires multiple times per second in combat)
self:RegisterBucketEvent("COMBAT_LOG_EVENT_UNFILTERED", 0.5, callback)

-- Currency changes
self:RegisterBucketEvent(
    {"CURRENCY_DISPLAY_UPDATE", "PLAYER_MONEY"},
    1,
    callback
)

// Reputation (can fire multiple times during quests)
self:RegisterBucketEvent("UPDATE_FACTION", 1, callback)

// Skill updates
self:RegisterBucketEvent(
    {"SKILL_LINES_CHANGED", "TRADE_SKILL_UPDATE"},
    0.5,
    callback
)
```

## Technical Details

### C_Timer Integration

Buckets use the Timer module internally for interval management:

```lua
-- When first event arrives, start timer
self:ScheduleTimer(function()
    if self.buckets[bucket.handle] then
        FireBucket(self, bucket)
    end
end, bucket.interval)
```

### Bucket Firing Behavior

1. **Event arrives**: Counter incremented for that event
2. **Timer check**: If timer not running, start timer
3. **Timer fires**: Callback executed with aggregate data, data cleared
4. **Next event**: Process repeats

Important: Bucket fires **once** after `interval` seconds of the **first** event, not the last event.

```lua
-- Timeline example with 1 second interval:
-- T+0.0s: BAG_UPDATE #1 arrives -> start 1s timer
-- T+0.1s: BAG_UPDATE #2 arrives -> timer still running
// T+0.5s: BAG_UPDATE #3 arrives -> timer still running
// T+1.0s: Timer fires -> callback receives count=3
// T+1.1s: BAG_UPDATE #4 arrives -> start new 1s timer
```

### Data Structure

The callback receives a table with this structure:

```lua
{
    count = 5,              -- Total events across all types
    events = {              -- Map of event name to count
        ["BAG_UPDATE"] = 3,
        ["UNIT_AURA"] = 2,
    }
}
```

**Single event example:**
```lua
-- RegisterBucketEvent("BAG_UPDATE", 1, callback)
-- After 3 BAG_UPDATE events, callback receives:
{
    count = 3,
    events = {
        ["BAG_UPDATE"] = 3
    }
}
```

**Multiple events example:**
```lua
-- RegisterBucketEvent({"UNIT_HEALTH", "UNIT_POWER"}, 1, callback)
-- After 2 UNIT_HEALTH and 3 UNIT_POWER events, callback receives:
{
    count = 5,
    events = {
        ["UNIT_HEALTH"] = 2,
        ["UNIT_POWER"] = 3
    }
}
```

### Event Registration

Buckets register with EventRegistry:

```lua
-- Event buckets use RegisterEventCallbackWithHandle
EventRegistry:RegisterEventCallbackWithHandle(
    eventName,
    function() HandleBucketEvent(self, bucket, eventName) end,
    self
)

-- Message buckets use RegisterCallbackWithHandle
EventRegistry:RegisterCallbackWithHandle(
    messageName,
    function() HandleBucketEvent(self, bucket, messageName) end,
    self
)
```

### Handle Management

Buckets are tracked using unique handles:

```lua
local bucketHandleCounter = 0
local function GenerateBucketHandle()
    bucketHandleCounter = bucketHandleCounter + 1
    return "LoolibBucket" .. bucketHandleCounter
end
```

Each bucket is stored in `self.buckets[handle]` with metadata:
- `handle`: Unique identifier
- `events`: Array of event/message names
- `interval`: Time in seconds
- `callback`: Function or method name
- `data`: Map of event name -> count
- `timerActive`: Boolean flag
- `type`: "event" or "message"
- `registrations`: Array of EventRegistry handles

### Memory Management

- Bucket data is cleared after firing
- `timerActive` flag prevents multiple timers
- Event registrations stored for proper cleanup
- `UnregisterBucket()` calls `registration:Unregister()` on each
- `UnregisterAllBuckets()` clears entire bucket storage table

### Relationship to Timer Module

LoolibBucketMixin inherits from LoolibTimerMixin:

```lua
LoolibBucketMixin = LoolibCreateFromMixins(TimerModule.Mixin)
```

This means objects with Bucket also have Timer functionality:
- All Timer methods available
- Can use both timers and buckets
- `CancelAllTimers()` is separate from `UnregisterAllBuckets()`
- Both should be called in cleanup code
