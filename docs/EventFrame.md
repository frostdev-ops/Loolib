# EventFrame Module

The EventFrame module provides a mixin for WoW frames that need to handle game events with automatic registration management tied to frame visibility. Events registered as "frame events" are only active when the frame is shown, preventing unnecessary processing when UI is hidden.

## Overview

### What It Does

EventFrameMixin provides three tiers of event registration for frames:
- **Permanent events**: Always active regardless of frame visibility
- **Frame events**: Automatically registered on show, unregistered on hide
- **Global registry events**: Same show/hide lifecycle but using the shared EventRegistry singleton

### Common Use Cases

- **UI panels**: Register for data events only when the panel is visible
- **Config dialogs**: Listen for profile changes only while open
- **Tooltips**: Register for unit changes only while shown
- **Any frame**: Automatic cleanup prevents stale event handlers

### Key Features

- **Automatic lifecycle**: Frame events register on OnShow, unregister on OnHide
- **Three registration tiers**: Permanent, visibility-based, and global registry
- **Full cleanup**: CleanupEvents removes all registrations
- **Query support**: Check if events are registered, list all events
- **Factory function**: ApplyEventFrameMixin sets up scripts automatically

## Quick Start

```lua
-- Apply to a frame
local frame = CreateFrame("Frame", nil, UIParent)
Loolib.ApplyEventFrameMixin(frame)

-- Permanent event (always active)
frame:RegisterPermanentEvent("PLAYER_LOGIN", function(self)
    print("Logged in!")
end)

-- Frame event (only active when frame is shown)
frame:RegisterFrameEvent("BAG_UPDATE", function(self, bagID)
    self:RefreshBagDisplay(bagID)
end)

-- Global registry event (show/hide lifecycle via EventRegistry)
frame:RegisterFrameEventAndCallback("UNIT_HEALTH", function(owner, unit)
    if unit == "player" then
        -- Update health display
    end
end, myOwner)

-- Cleanup on destroy
frame:CleanupEvents()
```

## API Reference

### Initialization

#### InitEventFrame()

Initialize the event frame storage tables. Called automatically by ApplyEventFrameMixin.

**Parameters:** None

**Returns:** None

### Permanent Events

#### RegisterPermanentEvent(event, callback)

Register for a WoW event that stays active regardless of frame visibility.

**Parameters:**
- `event` (string): The WoW event name
- `callback` (function): Callback receiving `(self, ...)` where self is the frame

**Returns:** None

**Example:**
```lua
frame:RegisterPermanentEvent("ADDON_LOADED", function(self, addonName)
    if addonName == "MyAddon" then
        self:Initialize()
    end
end)
```

#### UnregisterPermanentEvent(event)

Unregister a permanent event.

**Parameters:**
- `event` (string): The WoW event name

**Returns:** None

### Visibility-Based Events

#### RegisterFrameEvent(event, callback)

Register for a WoW event that is only active when the frame is shown. If the frame is currently shown, the event is registered immediately. If hidden, it will be registered on the next OnShow.

**Parameters:**
- `event` (string): The WoW event name
- `callback` (function): Callback receiving `(self, ...)`

**Returns:** None

**Example:**
```lua
-- Only process bag updates when inventory panel is visible
frame:RegisterFrameEvent("BAG_UPDATE", function(self, bagID)
    self:RefreshBag(bagID)
end)
```

#### UnregisterFrameEvent(event)

Unregister a visibility-based event. Removes both the callback and the WoW event registration if currently shown.

**Parameters:**
- `event` (string): The WoW event name

**Returns:** None

### Global Registry Events

#### RegisterFrameEventAndCallback(event, callback, owner)

Register for a WoW event via the shared EventRegistry singleton. The registration follows the frame's show/hide lifecycle: active when shown, unregistered when hidden.

**Parameters:**
- `event` (string): The WoW event name
- `callback` (function): The callback function
- `owner` (any): Registration owner (defaults to self)

**Returns:** None

**Notes:**
- Uses EventRegistry:RegisterEventCallbackWithHandle internally
- Re-registering the same (event, owner) pair replaces the previous callback
- The registration info is stored in pendingGlobalEvents so it can be re-registered on each OnShow

#### UnregisterFrameEventAndCallback(event, owner)

Unregister from a global registry event.

**Parameters:**
- `event` (string): The WoW event name
- `owner` (any): The owner (defaults to self)

**Returns:** None

### Lifecycle Handlers

#### OnShow()

Called when the frame is shown. Registers all frame events and global registry events. Hooked automatically by ApplyEventFrameMixin.

#### OnHide()

Called when the frame is hidden. Unregisters all frame events and global registry handles. Hooked automatically by ApplyEventFrameMixin.

#### OnEvent(event, ...)

Event dispatcher. Checks permanent events first, then frame events. Set as the frame's OnEvent script by ApplyEventFrameMixin.

### Cleanup

#### CleanupEvents()

Remove all event registrations (permanent, frame, and global registry). Calls UnregisterAllEvents on the frame and cleans up all internal state.

**Parameters:** None

**Returns:** None

**Example:**
```lua
function MyFrame:OnDestroy()
    self:CleanupEvents()
end
```

### Query

#### IsEventRegisteredOnFrame(event)

Check if an event is registered (either permanent or frame-based).

**Parameters:**
- `event` (string): The WoW event name

**Returns:**
- `boolean`: True if registered

#### GetRegisteredFrameEvents()

Get all registered events (both permanent and frame-based).

**Parameters:** None

**Returns:**
- `table`: Array of event name strings

### Factory

#### Loolib.ApplyEventFrameMixin(frame)

Apply the EventFrameMixin to a frame, initialize storage, and hook OnShow/OnHide/OnEvent scripts.

**Parameters:**
- `frame` (table/Frame): The WoW frame to enhance

**Returns:**
- `Frame`: The enhanced frame

**Notes:**
- Uses HookScript for OnShow/OnHide (preserves existing handlers)
- Uses SetScript for OnEvent (replaces existing handler)
- Calls InitEventFrame automatically

## Globals and Access Paths

| Path | Value |
|------|-------|
| `Loolib.EventFrameMixin` | The mixin table |
| `Loolib.ApplyEventFrameMixin` | Factory function |
| `Loolib.Events.EventFrameMixin` | Same mixin |
| `Loolib.Events.ApplyEventFrameMixin` | Same factory |
| `Loolib.Events.FrameMixin` | Same mixin (alias) |
| `Loolib.Events.ApplyFrameMixin` | Same factory (alias) |
| `Loolib.Events.EventFrame.Mixin` | Same mixin |
| `Loolib.Events.EventFrame.Apply` | Same factory |

Module names: `"EventFrame"`, `"Events.EventFrame"`

## Event Priority

When OnEvent fires, the dispatcher checks in this order:
1. Permanent events (`self.eventCallbacks[event]`) - returns immediately if found
2. Frame events (`self.frameEventCallbacks[event]`)

A permanent event handler for the same event name will shadow a frame event handler.

## Dependencies

- `Core/Loolib.lua` - Loolib namespace
- `Core/Mixin.lua` - Mixin (ApplyMixins)
- `Events/EventRegistry.lua` - EventRegistry singleton (for global registry events)
