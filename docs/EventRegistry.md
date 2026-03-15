# EventRegistry Module

The EventRegistry module provides a singleton registry for WoW game events, built on top of CallbackRegistryMixin. It manages a hidden frame for event listening and ref-counts registrations to automatically register/unregister WoW events as callbacks are added and removed.

## Overview

### What It Does

The EventRegistry bridges WoW's frame-based event system with Loolib's callback pattern:
- Central singleton for all WoW event handling
- Automatic WoW event registration/unregistration based on callback ref-counts
- One-shot events that auto-unregister after firing once
- Filtered events with a predicate function
- Handle-based registration for easy cleanup
- Inherits all CallbackRegistryMixin capabilities (reentrant safety, pcall, deferred callbacks)

### Common Use Cases

- **WoW event handling**: Register for PLAYER_LOGIN, ADDON_LOADED, etc. without managing frames
- **One-shot events**: Wait for a single event occurrence then auto-cleanup
- **Filtered events**: Only process events matching a condition
- **Shared event listening**: Multiple components can listen for the same WoW event without conflicts

### Key Features

- **Ref-counted WoW registration**: The underlying frame:RegisterEvent is called only when the first callback registers; frame:UnregisterEvent when the last unregisters
- **Replacement-safe**: Re-registering the same (event, owner) pair replaces the callback without inflating the ref count
- **Singleton pattern**: One global EventRegistry instance shared across all consumers

## Quick Start

```lua
local EventRegistry = Loolib.EventRegistry

-- Register for a WoW event
EventRegistry:RegisterEventCallback("PLAYER_LOGIN", function(owner)
    print("Player logged in!")
end, myAddon)

-- Register with a handle for easy cleanup
local handle = EventRegistry:RegisterEventCallbackWithHandle(
    "ADDON_LOADED",
    function(owner, addonName)
        if addonName == "MyAddon" then
            print("My addon loaded!")
        end
    end,
    myAddon
)

-- Later:
handle:Unregister()

-- One-shot: fires once then auto-unregisters
EventRegistry:RegisterOneShotEvent("PLAYER_ENTERING_WORLD", function(owner)
    print("First zone entered!")
end, myAddon)

-- Filtered: only fires when filter returns true
EventRegistry:RegisterFilteredEvent(
    "UNIT_HEALTH",
    function(owner, unit) return unit == "player" end,
    function(owner, unit) print("Player health changed!") end,
    myAddon
)
```

## API Reference

### Registration

#### RegisterEventCallback(event, callback, owner, ...)

Register a callback for a WoW event.

**Parameters:**
- `event` (string): The WoW event name (e.g., "PLAYER_LOGIN")
- `callback` (function): The callback function
- `owner` (any): The owner for unregistration
- `...` (any): Optional captured arguments

**Returns:**
- `any`: The owner

**Notes:**
- Internally calls RegisterCallback from CallbackRegistryMixin
- Ref-counts event registrations; calls frame:RegisterEvent on first callback
- Re-registering the same (event, owner) replaces the callback without double-counting

#### RegisterEventCallbackWithHandle(event, callback, owner, ...)

Register for a WoW event and get a handle for cleanup.

**Parameters:** Same as RegisterEventCallback

**Returns:**
- `table`: Handle with `Unregister()` method that calls UnregisterEventCallback

#### UnregisterEventCallback(event, owner)

Unregister a callback for a WoW event.

**Parameters:**
- `event` (string): The WoW event name
- `owner` (any): The owner (must not be nil)

**Returns:**
- `boolean`: True if removed

**Notes:**
- Decrements the ref count; calls frame:UnregisterEvent when count reaches zero

#### UnregisterAllEventsForOwner(owner)

Unregister all event callbacks for a given owner across all events.

**Parameters:**
- `owner` (any): The owner (must not be nil)

**Returns:** None

### One-Shot Events

#### RegisterOneShotEvent(event, callback, owner, ...)

Register a callback that automatically unregisters after firing once.

**Parameters:**
- `event` (string): The WoW event name
- `callback` (function): The callback function
- `owner` (any): The owner
- `...` (any): Optional captured arguments (prepended to callback args)

**Returns:**
- `any`: The owner

**Example:**
```lua
EventRegistry:RegisterOneShotEvent("PLAYER_ENTERING_WORLD", function(owner)
    -- This fires exactly once, then the registration is removed
    self:InitializeAfterLoad()
end, self)
```

### Filtered Events

#### RegisterFilteredEvent(event, filter, callback, owner)

Register a callback with a filter predicate. The callback only fires when the filter returns true.

**Parameters:**
- `event` (string): The WoW event name
- `filter` (function): Predicate function `filter(owner, ...)` returning boolean
- `callback` (function): The callback function (called when filter returns true)
- `owner` (any): The owner

**Returns:**
- `any`: The owner

**Example:**
```lua
-- Only react to player health changes, ignore other units
EventRegistry:RegisterFilteredEvent(
    "UNIT_HEALTH",
    function(owner, unit) return unit == "player" end,
    function(owner, unit) self:UpdatePlayerHealth() end,
    self
)
```

### Query

#### IsEventRegistered(event)

Check if an event is currently being listened for.

**Parameters:**
- `event` (string): The WoW event name

**Returns:**
- `boolean`: True if at least one callback exists

#### GetEventCallbackCount(event)

Get the ref-count of callbacks for a specific event.

**Parameters:**
- `event` (string): The WoW event name

**Returns:**
- `number`: Number of registered callbacks

#### GetAllRegisteredEvents()

Get all WoW events currently being listened for.

**Parameters:** None

**Returns:**
- `table`: Array of event name strings

## Globals and Access Paths

| Path | Value |
|------|-------|
| `Loolib.EventRegistry` | The singleton instance |
| `Loolib.EventRegistryMixin` | The mixin table |
| `Loolib.Events.Registry` | Same singleton |
| `Loolib.Events.EventRegistryMixin` | Same mixin |
| `Loolib.Events.EventRegistry.Mixin` | Same mixin |
| `Loolib.Events.EventRegistry.Registry` | Same singleton |

Module names: `"EventRegistry"`, `"Events.EventRegistry"`

## Architecture Notes

### Ref-Counting

The registry maintains `self.registeredEvents[event] = count` where count tracks how many owners are registered for each WoW event. This prevents premature unregistration when multiple components listen for the same event:

```
Component A registers PLAYER_LOGIN -> count=1, frame:RegisterEvent called
Component B registers PLAYER_LOGIN -> count=2
Component A unregisters            -> count=1
Component B unregisters            -> count=0, frame:UnregisterEvent called
```

### Replacement Detection

When `RegisterEventCallback` is called with an (event, owner) pair that already exists, the existing callback is replaced. The ref count is not incremented for replacements, preventing count inflation that would leak WoW event registrations.

### Singleton

The module creates a single EventRegistry instance at load time. All consumers share this instance. The internal frame is created once and handles OnEvent dispatch to TriggerEvent.

## Dependencies

- `Core/Loolib.lua` - Loolib namespace
- `Core/Mixin.lua` - CreateFromMixins
- `Events/CallbackRegistry.lua` - CallbackRegistryMixin base
