# CallbackRegistry Module

The CallbackRegistry module provides an internal event/signal system for component communication within Loolib addons. Based on Blizzard's CallbackRegistryMixin pattern, simplified for addon use without secure frame requirements.

## Overview

### What It Does

The CallbackRegistry provides a publish/subscribe system for custom events:
- Register callbacks for named events
- Fire events to notify all registered listeners
- Automatic duplicate prevention (re-registering replaces the old callback)
- Reentrant-safe dispatch (callbacks that register/unregister during event fire are deferred)
- Owner-based registration for clean bulk unregistration
- Handle-based registration for easy one-off cleanup

### Common Use Cases

- **Component communication**: Decouple UI from data layers
- **State change notifications**: Notify listeners when data changes
- **Plugin/extension points**: Allow other addons to hook into events
- **UI event propagation**: Notify child frames of parent state changes

### Key Features

- **Owner tracking**: Every registration has an owner for bulk cleanup
- **Closure support**: Capture arguments at registration time
- **Reentrant safety**: Safe to register/unregister inside callbacks
- **pcall protection**: Callback errors are caught and logged, not propagated
- **Handle pattern**: RegisterCallbackWithHandle returns an object with Unregister()
- **Defined events**: Optionally restrict which events can be fired

## Quick Start

```lua
-- Create a standalone registry
local registry = Loolib.CreateCallbackRegistry()

-- Or mix into an object
local MyComponent = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
MyComponent:OnLoad()

-- Define allowed events (optional)
MyComponent:GenerateCallbackEvents({
    "DataChanged",
    "SelectionChanged",
    "FilterUpdated",
})

-- Register a callback
MyComponent:RegisterCallback("DataChanged", function(owner, newData)
    print("Data changed:", newData)
end, myOwner)

-- Fire the event
MyComponent:TriggerEvent("DataChanged", someData)

-- Unregister when done
MyComponent:UnregisterCallback("DataChanged", myOwner)
```

## API Reference

### Initialization

#### OnLoad()

Initialize the callback registry. Must be called before any registration.

**Parameters:** None

**Returns:** None

**Example:**
```lua
local MyObj = Loolib.CreateFromMixins(Loolib.CallbackRegistryMixin)
MyObj:OnLoad()
```

#### GenerateCallbackEvents(events)

Define the set of events this registry can fire. When defined, TriggerEvent will error if an undefined event is used (unless SetUndefinedEventsAllowed is true).

**Parameters:**
- `events` (table): Array of event name strings

**Returns:** None

**Example:**
```lua
MyObj:GenerateCallbackEvents({
    "OnDataChanged",
    "OnSelectionChanged",
})
-- MyObj.Event.OnDataChanged == "OnDataChanged"
```

#### SetUndefinedEventsAllowed(allowed)

Allow or disallow triggering events not defined via GenerateCallbackEvents.

**Parameters:**
- `allowed` (boolean): True to allow undefined events

**Returns:** None

### Registration

#### RegisterCallback(event, func, owner, ...)

Register a callback for an event.

**Parameters:**
- `event` (string): The event name
- `func` (function): The callback function
- `owner` (any): The owner used for unregistration. If nil, a numeric ID is generated. Numbers are reserved for internal use.
- `...` (any): Optional arguments captured into a closure (prepended to event args)

**Returns:**
- `any`: The owner (for later unregistration)

**Callback signatures:**
```lua
-- Without captured args: func(owner, eventArg1, eventArg2, ...)
-- With captured args: closure(eventArg1, eventArg2, ...)
--   where closure = GenerateClosure(func, owner, capturedArg1, ...)
```

**Example:**
```lua
-- Simple function callback
registry:RegisterCallback("DataChanged", function(owner, newData)
    print(owner, "got data:", newData)
end, myAddon)

-- With captured arguments (creates closure)
registry:RegisterCallback("DataChanged", function(owner, extra, newData)
    print(owner, extra, newData)
end, myAddon, "extraArg")

-- Auto-generated owner
local owner = registry:RegisterCallback("DataChanged", function(owner, data)
    print("anonymous:", data)
end)
```

#### RegisterCallbackWithHandle(event, func, owner, ...)

Register a callback and return a handle object for easy cleanup.

**Parameters:** Same as RegisterCallback

**Returns:**
- `table`: Handle with `Unregister()` method

**Example:**
```lua
local handle = registry:RegisterCallbackWithHandle("DataChanged", callback, self)

-- Later:
handle:Unregister()
```

#### UnregisterCallback(event, owner)

Unregister a callback by event and owner.

**Parameters:**
- `event` (string): The event name
- `owner` (any): The owner that registered the callback (must not be nil)

**Returns:**
- `boolean`: True if a callback was removed

#### UnregisterAllCallbacks(owner)

Unregister all callbacks for an owner across all events.

**Parameters:**
- `owner` (any): The owner (must not be nil)

**Returns:** None

### Event Dispatch

#### TriggerEvent(event, ...)

Fire an event, calling all registered callbacks.

**Parameters:**
- `event` (string): The event name
- `...` (any): Arguments passed to callbacks

**Returns:** None

**Notes:**
- Callbacks are called inside pcall; errors are logged via Loolib:Error() but do not propagate
- Safe to call TriggerEvent recursively (reentrant)
- Registrations/unregistrations during dispatch are deferred until dispatch completes

### Query

#### HasRegistrantsForEvent(event)

Check if any callbacks are registered for an event.

**Parameters:**
- `event` (string): The event name

**Returns:**
- `boolean`: True if at least one callback exists

#### GetRegisteredEvents()

Get all events that have registered callbacks.

**Parameters:** None

**Returns:**
- `table`: Array of event name strings

#### GetCallbackCount(event)

Get the number of callbacks registered for an event.

**Parameters:**
- `event` (string): The event name

**Returns:**
- `number`: Count of registered callbacks

### Factory

#### Loolib.CreateCallbackRegistry()

Create a new, initialized CallbackRegistry instance.

**Parameters:** None

**Returns:**
- `table`: A new CallbackRegistry with OnLoad already called

## Globals and Access Paths

The module registers under multiple paths for convenience:

| Path | Value |
|------|-------|
| `Loolib.CallbackRegistryMixin` | The mixin table |
| `Loolib.CreateCallbackRegistry` | Factory function |
| `Loolib.Events.CallbackRegistryMixin` | Same mixin |
| `Loolib.Events.CreateCallbackRegistry` | Same factory |
| `Loolib.Events.CallbackRegistry.Mixin` | Same mixin |
| `Loolib.Events.CallbackRegistry.Create` | Same factory |

Module names: `"CallbackRegistry"`, `"Events.CallbackRegistry"`

## Reentrant Safety

The registry handles the case where callbacks register or unregister other callbacks during event dispatch:

```lua
registry:RegisterCallback("MyEvent", function(owner)
    -- This is safe: the new callback is deferred
    registry:RegisterCallback("MyEvent", newCallback, newOwner)

    -- This is also safe: removal is deferred
    registry:UnregisterCallback("MyEvent", someOtherOwner)
end, self)

registry:TriggerEvent("MyEvent")
-- After TriggerEvent returns, deferred changes are applied
```

Internally, a nesting counter tracks recursive TriggerEvent calls. Deferred callbacks are reconciled only when the outermost dispatch completes.

## Dependencies

- `Core/Loolib.lua` - Loolib namespace
- `Core/Mixin.lua` - CreateFromMixins
- `Core/FunctionUtil.lua` - GenerateClosure for captured-argument callbacks
