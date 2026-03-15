# DragDrop Module Documentation

## Overview

**DragDrop** is a comprehensive drag-and-drop system for World of Warcraft 12.0+ addons. It provides a coordinated framework for making frames draggable, accepting drops, showing visual feedback, and reordering list items.

The system is built on the singleton DragContext pattern, which manages global drag state and coordinates between draggable sources and drop targets. This ensures proper priority handling, hover detection, and event propagation across your entire UI.

### Key Features

- **Global Drag Coordination**: Singleton context manages all drag operations
- **Draggable Frames**: Make any frame draggable with data transfer
- **Drop Targets**: Accept drops with validation and priority
- **Visual Feedback**: Drag ghost preview and drop target highlighting
- **List Reordering**: Drag-to-reorder functionality for scrollable lists
- **Event System**: Comprehensive callbacks for drag lifecycle
- **Position Persistence**: Optional integration with SavedVariables
- **Modifier Keys**: Require Shift/Ctrl/Alt for drag operations
- **Right-Click Cancel**: Standard UX pattern for canceling drags
- **Error-Safe Cleanup**: Ghost frames and cursor state are always cleaned up, even if callbacks error

### Known Limitations

- **Single-drag constraint**: Only one drag operation may be active at a time. Starting a new drag while one is in progress cancels the first. This is by design (DD-04).
- **HookScript persistence**: Once drag hooks are installed on a frame via `SetDragEnabled(true)`, they remain installed even after `SetDragEnabled(false)`. They become no-ops when disabled, but the hook itself persists. This is required by R7 (never SetScript on consumer-owned frames).

---

## Quick Start

### Basic Drag and Drop

The simplest use case: drag a frame and drop it on a target.

```lua
local Loolib = LibStub("Loolib")
local DragContext = Loolib:GetModule("DragDrop.DragContext")

-- Create source frame
local source = CreateFrame("Frame", nil, UIParent)
source:SetSize(100, 100)
source:SetPoint("CENTER", -100, 0)

-- Make it draggable
LoolibMixin(source, LoolibDraggableMixin)
source:InitDraggable()
source:SetDragEnabled(true)
source:SetDragData({type = "item", id = 12345, name = "Thunderfury"})

-- Create drop target
local target = CreateFrame("Frame", nil, UIParent)
target:SetSize(200, 200)
target:SetPoint("CENTER", 100, 0)

-- Make it accept drops
LoolibMixin(target, LoolibDropTargetMixin)
target:InitDropTarget()
target:SetDropEnabled(true)

-- Handle the drop
function target:OnDropReceived(dragData, sourceFrame)
    print("Received:", dragData.name)
end
```

### List Item Reordering

```lua
local Loolib = LibStub("Loolib")

-- Create scrollable list
local list = CreateFrame("Frame", nil, UIParent)
LoolibMixin(list, LoolibScrollableListMixin, LoolibReorderableMixin)
list:OnLoad()
list:InitReorderable()

-- Enable reordering
list:SetReorderEnabled(true)
list:SetDataReorderCallback(function(fromIndex, toIndex)
    -- Reorder backing data
    local item = table.remove(myData, fromIndex)
    table.insert(myData, toIndex, item)
end)

-- User can now drag items to reorder!
```

### Movable Window with Position Save

```lua
local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
frame:SetSize(300, 200)
frame:SetPoint("CENTER")

LoolibMixin(frame, LoolibDraggableMixin)
frame:InitDraggable()
frame:SetDragEnabled(true)
    :SetSavePosition(MyAddonDB, "MainWindow")
    :SetClampToScreen(true)
    :SetDragButton("LeftButton")

-- Restore position on login
frame:RestorePosition()
```

---

## Components

### DragContext (Singleton)

The global coordinator for all drag-and-drop operations. Manages drag state, registered targets, hover detection, and event propagation.

**Module name:** `"DragDrop.DragContext"` (alias: `"DragContext"`)

**Access:**
```lua
local DragContext = Loolib:GetModule("DragDrop.DragContext")
```

#### Methods

| Method | Scope | Description |
|--------|-------|-------------|
| `Initialize()` | Public | Initialize singleton state. Idempotent. |
| `RegisterDropTarget(frame, validator?, priority?)` | Public | Register a frame as a valid drop target |
| `UnregisterDropTarget(frame)` | Public | Remove a frame from the drop target registry |
| `IsDropTarget(frame)` | Public | Check if a frame is registered as a drop target |
| `StartDrag(sourceFrame, dragData, ghostFrame?)` | Public | Begin a drag operation. Cancels any active drag first. |
| `EndDrag(cancelled?)` | Public | End the current drag (drop or cancel). Returns boolean success. |
| `CancelDrag()` | Public | Cancel the current drag operation |
| `RegisterCallback(event, callback, owner)` | Public | Register a callback for drag events |
| `UnregisterCallback(event, owner)` | Public | Unregister a callback |
| `UnregisterAllCallbacks(owner)` | Public | Unregister all callbacks for an owner |
| `IsDragging()` | Public | Check if a drag is in progress |
| `GetDragData()` | Public | Get the data being dragged |
| `GetSourceFrame()` | Public | Get the source frame being dragged |
| `GetHoveredDropTarget()` | Public | Get the currently hovered drop target |
| `GetStartPosition()` | Public | Get the starting cursor position (startX, startY) |
| `GetDragDistance()` | Public | Get the distance the cursor has moved since drag start |

#### Events

| Event | Arguments | Description |
|-------|-----------|-------------|
| `OnDragStart` | sourceFrame, dragData | Fired when a drag begins |
| `OnDragUpdate` | cursorX, cursorY, dragData | Fired every frame during drag |
| `OnDragEnd` | targetFrame, dragData, success | Fired when drag completes (drop) |
| `OnDragCancel` | sourceFrame, dragData | Fired when drag is cancelled |
| `OnDropTargetEnter` | targetFrame, dragData | Fired when cursor enters a drop target |
| `OnDropTargetLeave` | targetFrame, dragData | Fired when cursor leaves a drop target |

---

### DraggableMixin

Make any frame draggable with optional data transfer and position persistence.

**Module name:** `"DragDrop.DraggableMixin"`

**Access:**
```lua
local DraggableMixin = Loolib:GetModule("DragDrop.DraggableMixin")
```

#### Methods

| Method | Scope | Description |
|--------|-------|-------------|
| `InitDraggable()` | Public | Initialize draggable state. Idempotent. |
| `SetDragEnabled(enabled)` | Public | Enable/disable dragging. Uses HookScript (R7). Returns self. |
| `SetDragData(data)` | Public | Set data to transfer on drop. Returns self. |
| `SetDragButton(button)` | Public | Set which mouse button initiates drag. Returns self. |
| `SetDragModifier(modifier)` | Public | Require modifier key ("shift"/"ctrl"/"alt"/nil). Returns self. |
| `SetUseGhost(useGhost, template?)` | Public | Enable ghost preview during drag. Returns self. |
| `SetClampToScreen(clamp)` | Public | Clamp frame to screen bounds. Returns self. |
| `SetSavePosition(savedVarsTable, key)` | Public | Enable position persistence. Returns self. |
| `RestorePosition()` | Public | Restore saved position. Returns boolean success. |
| `RestoreOriginalPoints()` | Public | Restore pre-drag anchor points. |
| `CenterOnScreen()` | Public | Center the frame on screen. |
| `IsDragging()` | Public | Check if currently being dragged. |
| `GetDragData()` | Public | Get the drag data for this frame. |

#### Override Points

Implement these on your frame for custom behavior:

```lua
function myFrame:OnDragStart()
    print("Started dragging!")
end

function myFrame:OnDragEnd(success)
    if success then
        print("Dropped on valid target")
    end
end
```

---

### DragGhost

Visual ghost/preview frame for drag-and-drop operations. Provides cursor-following preview with valid/invalid state indication.

**Module name:** `"DragDrop.DragGhost"`

**Access:**
```lua
local DragGhost = Loolib:GetModule("DragDrop.DragGhost")
local ghost = DragGhost.GetShared()    -- singleton
local ghost = DragGhost.Create(parent) -- new instance
```

#### LoolibDragGhostMixin Methods

| Method | Scope | Description |
|--------|-------|-------------|
| `OnLoad()` | Public | Initialize ghost frame. Idempotent. |
| `ShowFor(sourceFrame, dragData?)` | Public | Show ghost for a source frame |
| `HideGhost()` | Public | Hide ghost and reset state for reuse |
| `UpdatePosition(x?, y?)` | Public | Update ghost position to follow cursor |
| `SetOffset(offsetX, offsetY)` | Public | Set position offset from cursor |
| `SetValid(isValid)` | Public | Set valid/invalid visual state |
| `SetIcon(icon, isAtlas?)` | Public | Set the ghost icon texture |
| `SetLabel(text)` | Public | Set the ghost label text |
| `ShowIndicator(show)` | Public | Show/hide validity indicator (checkmark/X) |
| `SetColors(validColor?, invalidColor?, validBorder?, invalidBorder?)` | Public | Set custom state colors |
| `CloneAppearance(sourceFrame)` | Public | Copy visual appearance from source frame |
| `OnUpdate(elapsed)` | Public | OnUpdate handler for cursor tracking |

#### Module-Level Functions

| Function | Description |
|----------|-------------|
| `DragGhost.Create(parent?, name?)` | Create a new drag ghost frame |
| `DragGhost.GetShared()` | Get the shared singleton ghost (reused, not leaked) |

---

### DropTargetMixin

Make frames accept drag-and-drop with validation, priority, and visual feedback.

**Module name:** `"DragDrop.DropTargetMixin"`

**Access:**
```lua
local DropTargetMixin = Loolib:GetModule("DragDrop.DropTargetMixin")
```

#### Methods

| Method | Scope | Description |
|--------|-------|-------------|
| `InitDropTarget()` | Public | Initialize drop target state. Idempotent. |
| `SetDropEnabled(enabled)` | Public | Enable/disable drop acceptance. Registers with DragContext. Returns self. |
| `SetDropValidator(validator)` | Public | Set custom validation function. Returns self. |
| `SetDropPriority(priority)` | Public | Set priority for overlapping targets. Returns self. |
| `SetHighlightOnHover(enabled)` | Public | Enable/disable hover highlight. Returns self. |
| `SetHighlightColors(validColor?, invalidColor?)` | Public | Set highlight colors. Returns self. |
| `SetAcceptedTypes(...)` | Public | Set accepted drag data types. Returns self. |
| `IsDropTarget()` | Public | Check if this frame is an active drop target. |
| `IsHoveredByDrag()` | Public | Check if a drag is currently hovering. |
| `CanAcceptDrop(dragData)` | Public | Test if specific drag data would be accepted. |
| `DestroyDropTarget()` | Public | Disable and clean up the drop target completely. |
| `OnDragEnter(dragData)` | Internal | Called by DragContext when drag enters target. |
| `OnDragLeave(dragData)` | Internal | Called by DragContext when drag leaves target. |
| `OnDrop(dragData, sourceFrame)` | Internal | Called by DragContext when item is dropped. |

#### Override Points

```lua
function myTarget:OnDropTargetEnter(dragData, isValid)
    -- Cursor entered this target during drag
end

function myTarget:OnDropTargetLeave(dragData)
    -- Cursor left this target during drag
end

function myTarget:OnDropReceived(dragData, sourceFrame)
    -- Item was dropped and validated
    print("Received:", dragData.name, "from", sourceFrame:GetName())
end
```

---

### ReorderableMixin

Drag-to-reorder functionality for scrollable lists. Includes visual drop indicator and data reordering callbacks.

**Module name:** `"DragDrop.ReorderableMixin"`

**Access:**
```lua
local Reorderable = Loolib:GetModule("DragDrop.ReorderableMixin")
-- or
local ReorderableModule = Loolib.UI.Reorderable
local ListMixin = ReorderableModule.ListMixin
local ItemMixin = ReorderableModule.ItemMixin
```

#### LoolibReorderableMixin (List) Methods

| Method | Scope | Description |
|--------|-------|-------------|
| `InitReorderable()` | Public | Initialize reorderable system. Idempotent. |
| `SetReorderEnabled(enabled)` | Public | Enable/disable reordering. Returns self. |
| `SetReorderButton(button)` | Public | Set drag button. Returns self. |
| `SetReorderModifier(modifier)` | Public | Require modifier key. Returns self. |
| `SetDataReorderCallback(callback)` | Public | Set data reorder callback. Returns self. |
| `SetupReorderableItem(item, index)` | Public | Set up a list item for reordering. |
| `MoveItem(fromIndex, toIndex)` | Public | Move item between indices. Validates bounds (DD-05). |
| `SwapItems(index1, index2)` | Public | Swap two items by index. Validates bounds (DD-05). |

#### LoolibReorderableItemMixin (Item) Methods

| Method | Scope | Description |
|--------|-------|-------------|
| `InitReorderableItem()` | Public | Initialize reorderable item state. Idempotent. |
| `SetListIndex(index)` | Public | Set the item's list position. |
| `GetListIndex()` | Public | Get the item's list position. |
| `GetParentList()` | Public | Get the parent list frame. |

#### Reorder Events

| Event | Arguments | Description |
|-------|-----------|-------------|
| `OnItemDragStart` | item, index | An item started being dragged |
| `OnItemDragEnd` | item, fromIndex, toIndex | An item was dropped |
| `OnItemReorder` | fromIndex, toIndex | Data was reordered |

---

## Advanced Usage

### Type-Based Drop Filtering

```lua
-- Only accept "item" type drops
target:SetAcceptedTypes("item", "spell")

-- Or use a custom validator for complex logic
target:SetDropValidator(function(dragData)
    return dragData.type == "item" and dragData.quality >= 4
end)
```

### Nested Drop Targets with Priority

```lua
-- Parent accepts any drop (low priority)
parentFrame:SetDropPriority(0)
parentFrame:SetDropEnabled(true)

-- Child accepts specific drops (high priority, checked first)
childFrame:SetDropPriority(10)
childFrame:SetDropEnabled(true)
childFrame:SetAcceptedTypes("item")
```

### Ghost Frame with Custom Appearance

```lua
local DragGhost = Loolib:GetModule("DragDrop.DragGhost")
local ghost = DragGhost.GetShared()

-- Customize colors
ghost:SetColors(
    {r = 0, g = 1, b = 0, a = 0.8},   -- valid color
    {r = 1, g = 0, b = 0, a = 0.8},   -- invalid color
    {r = 0, g = 0.8, b = 0, a = 1},   -- valid border
    {r = 0.8, g = 0, b = 0, a = 1}    -- invalid border
)
ghost:ShowIndicator(true)

-- Show for a source frame
ghost:ShowFor(sourceFrame, {icon = 134400, name = "My Item"})
```

### Modifier-Key Restricted Drag

```lua
frame:InitDraggable()
frame:SetDragEnabled(true)
    :SetDragModifier("shift")  -- Must hold Shift to drag
    :SetDragButton("LeftButton")
```

### Listening to DragContext Events

```lua
local DragContext = Loolib:GetModule("DragDrop.DragContext")

DragContext:RegisterCallback("OnDragStart", function(owner, sourceFrame, dragData)
    print("Drag started from", sourceFrame:GetName())
end, myAddon)

DragContext:RegisterCallback("OnDragEnd", function(owner, targetFrame, dragData, success)
    if success then
        print("Successfully dropped on", targetFrame:GetName())
    else
        print("Drop failed or missed all targets")
    end
end, myAddon)

-- Clean up when done
DragContext:UnregisterAllCallbacks(myAddon)
```

---

## Architecture Notes

### Load Order

1. `DragContext.lua` - Singleton state manager (no dependencies beyond core)
2. `DraggableMixin.lua` - Frame dragging mixin (uses DragContext)
3. `DragGhost.lua` - Visual ghost preview (standalone)
4. `DropTargetMixin.lua` - Drop target mixin (uses DragContext)
5. `ReorderableMixin.lua` - List reorder mixin (uses ScrollableList)

### Module Registration

All modules use fully qualified names with `"DragDrop."` prefix:
- `"DragDrop.DragContext"`
- `"DragDrop.DraggableMixin"`
- `"DragDrop.DragGhost"`
- `"DragDrop.DropTargetMixin"`
- `"DragDrop.ReorderableMixin"`
- `"DragDrop.ReorderableItemMixin"`

Leaf aliases (e.g., `"DragContext"`) are auto-generated and work for `GetModule()` lookups as long as the leaf name is unique across the library.

### Error Handling

All public methods validate arguments at entry per R1/R2:
```
error("LoolibModuleName: MethodName: message", 2)
```

Internal helpers (prefixed with `_`) trust their callers and skip validation.

### Cleanup Safety

`DragContext:EndDrag()` wraps callback invocations in `pcall` to guarantee that ghost frame hiding, cursor reset, and state cleanup always execute, even if a consumer callback throws an error. The error is re-raised after cleanup.
