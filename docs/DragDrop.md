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

---

## Quick Start

### Basic Drag and Drop

The simplest use case: drag a frame and drop it on a target.

```lua
local Loolib = LibStub("Loolib")
local DragContext = Loolib:GetModule("DragContext")

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

---

## Components

### DragContext (Singleton)

The global coordinator for all drag-and-drop operations. Manages drag state, registered targets, hover detection, and event propagation.

**Access:**
```lua
local DragContext = Loolib:GetModule("DragContext")
-- or
local DragContext = LoolibDragContext
```

**Key Responsibilities:**
- Track current drag state (isDragging, dragData, sourceFrame)
- Maintain registry of drop targets with priorities
- Detect which target is under cursor during drag
- Fire events during drag lifecycle
- Manage drag ghost positioning
- Handle right-click to cancel

### DraggableMixin

A mixin that makes frames draggable. Supports simple window dragging (with position saving) or data transfer dragging (with drop targets).

**Apply to frames:**
```lua
local frame = CreateFrame("Frame", nil, UIParent)
LoolibMixin(frame, LoolibDraggableMixin)
frame:InitDraggable()
```

**Key Features:**
- Window dragging with position persistence
- Data transfer for drop targets
- Optional ghost preview
- Modifier key requirements (Shift/Ctrl/Alt)
- Configurable drag button
- Fluent configuration API

### DropTargetMixin

A mixin that makes frames accept dropped items. Provides validation, visual feedback, and event handling.

**Apply to frames:**
```lua
local frame = CreateFrame("Frame", nil, UIParent)
LoolibMixin(frame, LoolibDropTargetMixin)
frame:InitDropTarget()
```

**Key Features:**
- Custom validation functions
- Priority-based targeting (for overlapping targets)
- Hover highlighting with valid/invalid colors
- Type-based filtering
- Automatic DragContext registration

### DragGhost

Visual preview frame that follows the cursor during drag operations. Shows valid/invalid state through color changes.

**Create ghost:**
```lua
-- Use shared singleton
local ghost = LoolibGetSharedDragGhost()

-- Or create custom ghost
local ghost = LoolibCreateDragGhost(UIParent)
ghost:SetIcon("Interface\\Icons\\INV_Sword_39")
ghost:SetLabel("Thunderfury, Blessed Blade of the Windseeker")
ghost:ShowIndicator(true)
```

**Key Features:**
- Automatic cursor following
- Valid/invalid state indication
- Icon and label display
- Customizable colors and appearance
- Frame appearance cloning

### ReorderableMixin

A mixin for list containers that enables drag-to-reorder functionality. Works with ScrollableList or custom list implementations.

**Apply to lists:**
```lua
local list = CreateFrame("Frame", nil, UIParent)
LoolibMixin(list, LoolibReorderableMixin)
list:InitReorderable()
```

**Key Features:**
- Visual drop indicator (blue line)
- Automatic position restoration
- Data reorder callback
- Compatible with ScrollableList
- Modifier key support
- Event callbacks for reorder lifecycle

---

## API Reference

### DragContext API

#### Drop Target Registration

##### RegisterDropTarget(frame, validator, priority)

Register a frame as a valid drop target.

**Parameters:**
- `frame` (Frame): The frame that can receive drops
- `validator` (function, optional): Function(dragData) -> boolean to validate drops. Defaults to accepting all drops.
- `priority` (number, optional): Higher priority targets are checked first. Default 0.

**Example:**
```lua
-- Accept only items
DragContext:RegisterDropTarget(myFrame, function(dragData)
    return dragData.type == "item"
end, 10)

-- Accept all drops with default priority
DragContext:RegisterDropTarget(myFrame)
```

##### UnregisterDropTarget(frame)

Unregister a drop target.

**Parameters:**
- `frame` (Frame): The frame to unregister

**Behavior:**
- Removes frame from drop target registry
- Clears hover state if this frame was hovered
- Fires OnDropTargetLeave if drag is active

##### IsDropTarget(frame)

Check if a frame is registered as a drop target.

**Parameters:**
- `frame` (Frame): The frame to check

**Returns:**
- `boolean`: True if registered, false otherwise

#### Drag Operations

##### StartDrag(sourceFrame, dragData, ghostFrame)

Start a drag operation.

**Parameters:**
- `sourceFrame` (Frame): The frame being dragged
- `dragData` (any): Data to transfer on drop
- `ghostFrame` (Frame, optional): Ghost/preview frame to show at cursor

**Behavior:**
- Cancels any existing drag
- Sets isDragging = true
- Records start position
- Shows and positions ghost frame
- Starts update loop to track cursor
- Fires OnDragStart event

**Example:**
```lua
local ghost = LoolibGetSharedDragGhost()
ghost:SetLabel("Item being dragged")

DragContext:StartDrag(
    myFrame,
    {type = "item", id = 12345, name = "Thunderfury"},
    ghost
)
```

##### EndDrag(cancelled)

End the current drag operation (drop or cancel).

**Parameters:**
- `cancelled` (boolean, optional): If true, treated as cancel not drop

**Returns:**
- `boolean`: True if drop was successful

**Behavior:**
- If not cancelled, attempts drop on hovered target
- Validates drop with target's validator
- Calls target's OnDrop handler if valid
- Fires OnDragEnd or OnDragCancel event
- Stops update loop
- Hides ghost frame
- Resets drag state

##### CancelDrag()

Cancel the current drag operation.

**Behavior:**
- Calls EndDrag(true)
- Fires OnDragCancel event
- Does not call target's OnDrop handler

#### Query Methods

##### IsDragging()

Check if a drag operation is in progress.

**Returns:**
- `boolean`: True if dragging, false otherwise

##### GetDragData()

Get the data being dragged.

**Returns:**
- `any`: The drag data, or nil if not dragging

##### GetSourceFrame()

Get the source frame being dragged.

**Returns:**
- `Frame`: The source frame, or nil if not dragging

##### GetHoveredDropTarget()

Get the currently hovered drop target.

**Returns:**
- `Frame`: The hovered target, or nil if none

##### GetStartPosition()

Get the cursor position when drag began.

**Returns:**
- `number, number`: startX, startY (or 0, 0 if not dragging)

##### GetDragDistance()

Get the distance the cursor has moved since drag started.

**Returns:**
- `number`: Distance in pixels (or 0 if not dragging)

**Example:**
```lua
-- Require minimum drag distance before starting
if DragContext:GetDragDistance() > 5 then
    -- Visual feedback that drag has truly started
end
```

#### Event Registration

##### RegisterCallback(event, callback, owner)

Register a callback for drag events.

**Parameters:**
- `event` (string): Event name (see Events section)
- `callback` (function): Callback function
- `owner` (any): Owner for unregistration

**Returns:**
- `any`: Owner (for later unregistration)

**Example:**
```lua
DragContext:RegisterCallback("OnDragEnd", function(target, dragData, success)
    if success then
        print("Dropped on", target:GetName())
    else
        print("Drop failed or cancelled")
    end
end, self)
```

##### UnregisterCallback(event, owner)

Unregister a specific callback.

**Parameters:**
- `event` (string): Event name
- `owner` (any): Owner that registered the callback

**Returns:**
- `boolean`: True if a callback was removed

##### UnregisterAllCallbacks(owner)

Unregister all callbacks for an owner.

**Parameters:**
- `owner` (any): Owner to unregister

---

### DraggableMixin API

#### Initialization

##### InitDraggable()

Initialize the draggable system. Must be called after mixin is applied.

**Behavior:**
- Sets default configuration
- Initializes internal state
- Must be called before using any other methods

**Example:**
```lua
local frame = CreateFrame("Frame", nil, UIParent)
LoolibMixin(frame, LoolibDraggableMixin)
frame:InitDraggable()
```

#### Configuration (Fluent API)

All configuration methods return `self` for chaining.

##### SetDragEnabled(enabled)

Enable or disable dragging.

**Parameters:**
- `enabled` (boolean): True to enable, false to disable

**Returns:**
- `self`: For method chaining

**Behavior:**
- When enabled: Sets up drag scripts, enables mouse, sets movable
- When disabled: Removes drag scripts, sets not movable
- Applies screen clamping if enabled

**Example:**
```lua
frame:SetDragEnabled(true)
    :SetDragButton("LeftButton")
    :SetClampToScreen(true)
```

##### SetDragData(data)

Set data to transfer when dropped.

**Parameters:**
- `data` (any): The data to transfer. Can be any type - table, string, number, etc.

**Returns:**
- `self`: For method chaining

**Example:**
```lua
-- Simple string
frame:SetDragData("MyItem")

-- Structured data
frame:SetDragData({
    type = "item",
    id = 12345,
    name = "Thunderfury",
    icon = "Interface\\Icons\\INV_Sword_39",
    quality = 5
})
```

##### SetDragButton(button)

Set which mouse button initiates drag.

**Parameters:**
- `button` (string): "LeftButton", "RightButton", etc.

**Returns:**
- `self`: For method chaining

**Default:** "LeftButton"

##### SetDragModifier(modifier)

Require modifier key for drag.

**Parameters:**
- `modifier` (string|nil): "shift", "ctrl", "alt", or nil for none

**Returns:**
- `self`: For method chaining

**Example:**
```lua
-- Require shift key to drag
frame:SetDragModifier("shift")

-- Drag only works when shift is held
```

##### SetUseGhost(useGhost, template)

Use ghost preview during drag.

**Parameters:**
- `useGhost` (boolean): True to use ghost
- `template` (string, optional): Optional template for ghost frame

**Returns:**
- `self`: For method chaining

**Example:**
```lua
-- Use default ghost
frame:SetUseGhost(true)

-- Use custom template
frame:SetUseGhost(true, "MyCustomGhostTemplate")
```

##### SetClampToScreen(clamp)

Clamp to screen bounds during drag.

**Parameters:**
- `clamp` (boolean): True to clamp

**Returns:**
- `self`: For method chaining

**Default:** true

##### SetSavePosition(savedVarsTable, key)

Enable position persistence to SavedVariables.

**Parameters:**
- `savedVarsTable` (table): The SavedVariables table to use
- `key` (string): Key prefix for position data

**Returns:**
- `self`: For method chaining

**Behavior:**
- Automatically saves position on drag stop
- Saves left/top coordinates
- Format: `savedVarsTable[key.."Left"]` and `savedVarsTable[key.."Top"]`

**Example:**
```lua
-- SavedVariables table
local db = {profile = {windows = {}}}

-- Enable position saving
frame:SetSavePosition(db.profile.windows, "MainWindow")

-- After drag, saves to:
-- db.profile.windows.MainWindowLeft = 500
-- db.profile.windows.MainWindowTop = 300
```

#### Position Management

##### RestorePosition()

Restore saved position from SavedVariables.

**Returns:**
- `boolean`: True if position was restored, false if no saved data

**Example:**
```lua
-- Restore on addon load
if frame:RestorePosition() then
    print("Position restored")
else
    frame:CenterOnScreen()
end
```

##### RestoreOriginalPoints()

Restore anchor points from before drag started.

**Behavior:**
- Used internally for list reordering
- Restores all anchor points saved at drag start
- Useful when drag is cancelled

##### CenterOnScreen()

Center frame on screen (default position).

#### Query Methods

##### IsDragging()

Check if this frame is currently being dragged.

**Returns:**
- `boolean`: True if dragging, false otherwise

##### GetDragData()

Get the drag data for this frame.

**Returns:**
- `any`: The drag data

#### Override Points

Implement these methods in your frame to customize behavior:

```lua
-- Called when drag starts
function MyFrame:OnDragStart()
    print("Started dragging!")
end

-- Called when drag ends
-- success: true if dropped on valid target, false otherwise
function MyFrame:OnDragEnd(success)
    if success then
        print("Dropped on valid target")
    else
        print("Drag cancelled or invalid target")
    end
end
```

---

### DropTargetMixin API

#### Initialization

##### InitDropTarget()

Initialize the drop target system. Must be called after mixin is applied.

**Example:**
```lua
local frame = CreateFrame("Frame", nil, UIParent)
LoolibMixin(frame, LoolibDropTargetMixin)
frame:InitDropTarget()
```

#### Configuration (Fluent API)

All configuration methods return `self` for chaining.

##### SetDropEnabled(enabled)

Enable or disable drop target functionality.

**Parameters:**
- `enabled` (boolean): True to enable drops

**Returns:**
- `self`: For method chaining

**Behavior:**
- When enabled: Registers with DragContext
- When disabled: Unregisters from DragContext, clears hover state

**Example:**
```lua
target:SetDropEnabled(true)
    :SetDropValidator(function(data) return data.type == "item" end)
    :SetDropPriority(10)
```

##### SetDropValidator(validator)

Set custom validator function.

**Parameters:**
- `validator` (function|nil): Function(dragData) -> boolean

**Returns:**
- `self`: For method chaining

**Behavior:**
- Validator is called before OnDragEnter to determine if drop is valid
- Return true to accept drop, false to reject
- If nil, accepts all drops

**Example:**
```lua
-- Accept only items with quality >= 4
target:SetDropValidator(function(dragData)
    return dragData.type == "item" and dragData.quality >= 4
end)
```

##### SetDropPriority(priority)

Set drop priority for overlapping targets.

**Parameters:**
- `priority` (number): Priority value (default 0)

**Returns:**
- `self`: For method chaining

**Behavior:**
- Higher priority targets are checked first
- Useful for nested frames where child should receive drop
- Re-registers with DragContext if already enabled

**Example:**
```lua
-- Parent container (low priority)
parentFrame:SetDropPriority(0)

-- Child drop zone (high priority)
childFrame:SetDropPriority(10)

-- Child receives drop even when both are under cursor
```

##### SetHighlightOnHover(enabled)

Enable/disable hover highlight effect.

**Parameters:**
- `enabled` (boolean): True to show highlights

**Returns:**
- `self`: For method chaining

**Default:** true

##### SetHighlightColors(validColor, invalidColor)

Set highlight colors for valid and invalid drops.

**Parameters:**
- `validColor` (table): {r, g, b, a} for valid drops
- `invalidColor` (table, optional): {r, g, b, a} for invalid drops

**Returns:**
- `self`: For method chaining

**Default:**
- Valid: Green tint {r=0.3, g=0.8, b=0.3, a=0.3}
- Invalid: Red tint {r=0.8, g=0.3, b=0.3, a=0.3}

**Example:**
```lua
target:SetHighlightColors(
    {r = 0.2, g = 0.6, b = 1.0, a = 0.4},  -- Blue for valid
    {r = 1.0, g = 0.5, b = 0.0, a = 0.4}   -- Orange for invalid
)
```

##### SetAcceptedTypes(...)

Set accepted drag data types for type-based filtering.

**Parameters:**
- `...` (string): Type names to accept

**Returns:**
- `self`: For method chaining

**Behavior:**
- If types are specified, only dragData with matching type will be accepted
- Leave empty to accept all types
- Checks `dragData.type` field

**Example:**
```lua
-- Accept only items and spells
target:SetAcceptedTypes("item", "spell")

-- Rejects dragData where type is not "item" or "spell"
```

#### Query Methods

##### IsDropTarget()

Check if this frame is a drop target.

**Returns:**
- `boolean`: True if drop enabled

##### IsHoveredByDrag()

Check if a dragged item is currently hovering.

**Returns:**
- `boolean`: True if hovered during active drag

##### CanAcceptDrop(dragData)

Check if this target can accept specific drag data.

**Parameters:**
- `dragData` (any): The data to test

**Returns:**
- `boolean`: True if drop would be accepted

**Example:**
```lua
local testData = {type = "item", id = 12345}
if target:CanAcceptDrop(testData) then
    print("Target would accept this data")
end
```

#### Override Points

Implement these methods in your frame to add custom behavior:

```lua
-- Called when dragged item enters this target
-- isValid: true if drop would be accepted
function MyTarget:OnDropTargetEnter(dragData, isValid)
    if isValid then
        print("Can drop:", dragData.name)
    else
        print("Cannot drop here")
    end
end

-- Called when dragged item leaves this target
function MyTarget:OnDropTargetLeave(dragData)
    print("Left target")
end

-- Called when item is dropped on this target
-- sourceFrame: The frame that was dragged
function MyTarget:OnDropReceived(dragData, sourceFrame)
    print("Received:", dragData.name)
    -- Process the drop
end
```

---

### DragGhost API

#### Factory Functions

##### LoolibCreateDragGhost(parent, name)

Create a new drag ghost frame.

**Parameters:**
- `parent` (Frame, optional): Parent frame (defaults to UIParent)
- `name` (string, optional): Optional global frame name

**Returns:**
- `Frame`: Ghost frame with LoolibDragGhostMixin

**Example:**
```lua
local ghost = LoolibCreateDragGhost(UIParent, "MyAddonDragGhost")
```

##### LoolibGetSharedDragGhost()

Get or create shared drag ghost frame (singleton).

**Returns:**
- `Frame`: Shared drag ghost instance

**Example:**
```lua
-- Use shared ghost (most common)
local ghost = LoolibGetSharedDragGhost()
ghost:ShowFor(sourceFrame, dragData)
```

#### Methods

##### OnLoad()

Initialize the ghost frame. Called automatically by factory functions.

##### ShowFor(sourceFrame, dragData)

Show ghost for a source frame.

**Parameters:**
- `sourceFrame` (Frame): The frame being dragged
- `dragData` (any, optional): Optional data for the ghost to display

**Behavior:**
- Sizes ghost to match source frame
- Calculates offset from cursor to frame center
- Updates appearance from drag data
- Sets initial position
- Shows ghost frame

**Example:**
```lua
local ghost = LoolibGetSharedDragGhost()
ghost:ShowFor(myFrame, {
    icon = "Interface\\Icons\\INV_Sword_39",
    label = "Thunderfury",
    quality = 5
})
```

##### HideGhost()

Hide the ghost.

##### UpdatePosition(x, y)

Update ghost position to follow cursor.

**Parameters:**
- `x` (number, optional): Cursor X position (scaled). If omitted, gets current position.
- `y` (number, optional): Cursor Y position (scaled). If omitted, gets current position.

**Note:** Usually called automatically by OnUpdate handler.

##### SetOffset(offsetX, offsetY)

Set position offset from cursor.

**Parameters:**
- `offsetX` (number): Horizontal offset
- `offsetY` (number): Vertical offset

**Example:**
```lua
-- Ghost appears 20 pixels right and 10 pixels up from cursor
ghost:SetOffset(20, 10)
```

##### SetValid(isValid)

Set valid/invalid visual state.

**Parameters:**
- `isValid` (boolean): True if current drop target is valid

**Behavior:**
- Changes border color (green for valid, red for invalid)
- Changes background tint
- Updates indicator icon if shown

**Example:**
```lua
-- Called by DragContext during drag
ghost:SetValid(true)   -- Green border
ghost:SetValid(false)  -- Red border
```

##### SetIcon(icon, isAtlas)

Set the ghost icon.

**Parameters:**
- `icon` (string|number): Texture path or file ID
- `isAtlas` (boolean, optional): If true, treat as atlas name

**Example:**
```lua
ghost:SetIcon("Interface\\Icons\\INV_Sword_39")
ghost:SetIcon("questlegendary", true)  -- Atlas
```

##### SetLabel(text)

Set the ghost label text.

**Parameters:**
- `text` (string|nil): Label text to display

**Example:**
```lua
ghost:SetLabel("Thunderfury, Blessed Blade of the Windseeker")
```

##### ShowIndicator(show)

Show validity indicator (checkmark/X).

**Parameters:**
- `show` (boolean): Whether to show the indicator

**Behavior:**
- Shows checkmark when valid
- Shows X when invalid
- Updates automatically with SetValid()

##### SetColors(validColor, invalidColor, validBorder, invalidBorder)

Set custom colors for valid/invalid states.

**Parameters:**
- `validColor` (table, optional): {r, g, b, a} Color for valid state
- `invalidColor` (table, optional): {r, g, b, a} Color for invalid state
- `validBorder` (table, optional): {r, g, b, a} Border color for valid state
- `invalidBorder` (table, optional): {r, g, b, a} Border color for invalid state

**Example:**
```lua
ghost:SetColors(
    {r = 0.2, g = 0.8, b = 0.2, a = 0.7},  -- Valid: bright green
    {r = 0.8, g = 0.2, b = 0.2, a = 0.7},  -- Invalid: bright red
    {r = 0.3, g = 1.0, b = 0.3, a = 1.0},  -- Valid border
    {r = 1.0, g = 0.3, b = 0.3, a = 1.0}   -- Invalid border
)
```

##### CloneAppearance(sourceFrame)

Clone the visual appearance of source frame.

**Parameters:**
- `sourceFrame` (Frame): Frame to copy appearance from

**Behavior:**
- Copies backdrop if available
- Copies size
- Makes ghost semi-transparent

**Example:**
```lua
-- Ghost looks like the source frame
ghost:CloneAppearance(sourceFrame)
```

---

### ReorderableMixin API

#### Initialization

##### InitReorderable()

Initialize the reorderable system. Must be called after OnLoad.

**Example:**
```lua
local list = CreateFrame("Frame", nil, UIParent)
LoolibMixin(list, LoolibScrollableListMixin, LoolibReorderableMixin)
list:OnLoad()
list:InitReorderable()
```

#### Configuration (Fluent API)

##### SetReorderEnabled(enabled)

Enable or disable reordering.

**Parameters:**
- `enabled` (boolean): True to enable, false to disable

**Returns:**
- `self`: For method chaining

**Behavior:**
- Applies to existing visible items
- Sets up drag handlers on items

##### SetReorderButton(button)

Set the mouse button required for drag.

**Parameters:**
- `button` (string): "LeftButton", "RightButton", etc.

**Returns:**
- `self`: For method chaining

**Default:** "LeftButton"

##### SetReorderModifier(modifier)

Require a modifier key to be held during drag.

**Parameters:**
- `modifier` (string|nil): "shift", "ctrl", "alt", or nil for no requirement

**Returns:**
- `self`: For method chaining

**Example:**
```lua
-- Require shift to reorder (prevents accidental drags)
list:SetReorderModifier("shift")
```

##### SetDataReorderCallback(callback)

Set callback for reordering backing data.

**Parameters:**
- `callback` (function): Function(fromIndex, toIndex)

**Returns:**
- `self`: For method chaining

**Behavior:**
- Called when items are reordered
- Receives fromIndex and toIndex (1-based)
- Should reorder the backing data array
- If toIndex > fromIndex, item moves down in list

**Example:**
```lua
list:SetDataReorderCallback(function(fromIndex, toIndex)
    -- Reorder backing data
    local item = table.remove(myData, fromIndex)
    table.insert(myData, toIndex, item)

    -- Optionally save to database
    SaveData()
end)
```

#### Item Setup

##### SetupReorderableItem(item, index)

Set up a list item for reordering.

**Parameters:**
- `item` (Frame): The list item frame
- `index` (number): The item's position in the list (1-based)

**Behavior:**
- Sets item's list index
- Sets parent list reference
- Enables drag if reordering is enabled
- Call this when creating/refreshing list items

**Example:**
```lua
-- In your list's refresh function
for i, data in ipairs(myData) do
    local item = self:AcquireItem(i)
    item:SetData(data)

    -- Set up for reordering
    self:SetupReorderableItem(item, i)
end
```

#### Manual Reordering

##### SwapItems(index1, index2)

Manually swap two items (for external control).

**Parameters:**
- `index1` (number): First item index
- `index2` (number): Second item index

**Behavior:**
- Calls data reorder callback
- Triggers refresh
- Fires OnItemReorder event

**Example:**
```lua
-- Move item 3 to position 1
list:SwapItems(3, 1)
```

#### Events

Register callbacks for reorder lifecycle:

```lua
list:RegisterCallback("OnItemDragStart", function(item, index)
    print("Started dragging item", index)
end)

list:RegisterCallback("OnItemDragEnd", function(item, fromIndex, toIndex)
    print("Drag ended, from", fromIndex, "to", toIndex)
end)

list:RegisterCallback("OnItemReorder", function(fromIndex, toIndex)
    print("Items reordered:", fromIndex, "->", toIndex)
    -- Save to database, etc.
end)
```

---

## Events / Callbacks

### DragContext Events

Register for these events with `DragContext:RegisterCallback()`.

#### OnDragStart

Fired when a drag operation begins.

**Signature:**
```lua
function(sourceFrame, dragData)
```

**Parameters:**
- `sourceFrame` (Frame): The frame being dragged
- `dragData` (any): The data being transferred

**Example:**
```lua
DragContext:RegisterCallback("OnDragStart", function(sourceFrame, dragData)
    print("Started dragging:", dragData.name)
    -- Show UI hints, etc.
end, self)
```

#### OnDragUpdate

Fired every frame during drag (while cursor moves).

**Signature:**
```lua
function(cursorX, cursorY, dragData)
```

**Parameters:**
- `cursorX` (number): Current cursor X position (scaled)
- `cursorY` (number): Current cursor Y position (scaled)
- `dragData` (any): The data being transferred

**Note:** This fires very frequently. Avoid heavy processing.

#### OnDragEnd

Fired when drag ends (drop or release).

**Signature:**
```lua
function(targetFrame, dragData, success)
```

**Parameters:**
- `targetFrame` (Frame|nil): The drop target, or nil if no valid target
- `dragData` (any): The data being transferred
- `success` (boolean): True if drop was successful, false otherwise

**Example:**
```lua
DragContext:RegisterCallback("OnDragEnd", function(target, dragData, success)
    if success then
        print("Dropped on", target:GetName())
    else
        print("Drop cancelled or invalid")
    end
end, self)
```

#### OnDragCancel

Fired when drag is explicitly cancelled (right-click).

**Signature:**
```lua
function(sourceFrame, dragData)
```

**Parameters:**
- `sourceFrame` (Frame): The frame that was being dragged
- `dragData` (any): The data being transferred

#### OnDropTargetEnter

Fired when dragged item enters a valid drop target.

**Signature:**
```lua
function(targetFrame, dragData)
```

**Parameters:**
- `targetFrame` (Frame): The drop target being entered
- `dragData` (any): The data being transferred

**Example:**
```lua
DragContext:RegisterCallback("OnDropTargetEnter", function(target, dragData)
    print("Hovering over", target:GetName())
    -- Update UI, show tooltip, etc.
end, self)
```

#### OnDropTargetLeave

Fired when dragged item leaves a drop target.

**Signature:**
```lua
function(targetFrame, dragData)
```

**Parameters:**
- `targetFrame` (Frame): The drop target being left
- `dragData` (any): The data being transferred

### ReorderableMixin Events

Register for these events with `list:RegisterCallback()`.

#### OnItemDragStart

Fired when a list item drag begins.

**Signature:**
```lua
function(item, index)
```

**Parameters:**
- `item` (Frame): The item frame being dragged
- `index` (number): The item's position in the list

#### OnItemDragEnd

Fired when a list item drag ends.

**Signature:**
```lua
function(item, fromIndex, toIndex)
```

**Parameters:**
- `item` (Frame): The item frame that was dragged
- `fromIndex` (number): Original position
- `toIndex` (number|nil): New position, or nil if cancelled

#### OnItemReorder

Fired when items are actually reordered.

**Signature:**
```lua
function(fromIndex, toIndex)
```

**Parameters:**
- `fromIndex` (number): Original position
- `toIndex` (number): New position (adjusted for removal)

---

## Usage Examples

### Example 1: Basic Item Transfer

Drag items between inventory slots.

```lua
local Loolib = LibStub("Loolib")
local DragContext = Loolib:GetModule("DragContext")

-- Create inventory slots
local function CreateSlot(parent, x, y, slotData)
    local slot = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    slot:SetSize(40, 40)
    slot:SetPoint("TOPLEFT", x, y)
    slot:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    slot:SetBackdropColor(0.2, 0.2, 0.2, 1)
    slot:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    slot.data = slotData

    -- Make draggable if has item
    if slotData then
        LoolibMixin(slot, LoolibDraggableMixin)
        slot:InitDraggable()
        slot:SetDragEnabled(true)
        slot:SetDragData(slotData)

        -- Show item icon
        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(slotData.icon)
        slot.icon = icon
    end

    -- Make drop target
    LoolibMixin(slot, LoolibDropTargetMixin)
    slot:InitDropTarget()
    slot:SetDropEnabled(true)

    -- Handle drop
    function slot:OnDropReceived(dragData, sourceFrame)
        -- Swap items
        local temp = self.data
        self.data = dragData
        sourceFrame.data = temp

        -- Update icons
        if self.data then
            if not self.icon then
                self.icon = self:CreateTexture(nil, "ARTWORK")
                self.icon:SetAllPoints()
            end
            self.icon:SetTexture(self.data.icon)
        elseif self.icon then
            self.icon:Hide()
        end

        if sourceFrame.icon then
            if temp then
                sourceFrame.icon:SetTexture(temp.icon)
                sourceFrame.icon:Show()
            else
                sourceFrame.icon:Hide()
            end
        end

        print("Swapped items")
    end

    return slot
end

-- Create inventory grid
local inventory = CreateFrame("Frame", nil, UIParent)
inventory:SetSize(200, 200)
inventory:SetPoint("CENTER")

local items = {
    {icon = "Interface\\Icons\\INV_Sword_39", name = "Sword"},
    {icon = "Interface\\Icons\\INV_Shield_05", name = "Shield"},
    {icon = "Interface\\Icons\\INV_Potion_51", name = "Potion"},
}

for i = 1, 16 do
    local x = ((i - 1) % 4) * 45 + 10
    local y = -math.floor((i - 1) / 4) * 45 - 10
    CreateSlot(inventory, x, y, items[i])
end
```

### Example 2: Scrollable List with Reordering

```lua
local Loolib = LibStub("Loolib")

-- Create scrollable list
local list = CreateFrame("Frame", nil, UIParent)
list:SetSize(300, 400)
list:SetPoint("CENTER")
LoolibMixin(list, LoolibScrollableListMixin, LoolibReorderableMixin)
list:OnLoad()

-- Data
local myData = {
    {name = "Item 1", value = 100},
    {name = "Item 2", value = 200},
    {name = "Item 3", value = 300},
    {name = "Item 4", value = 400},
    {name = "Item 5", value = 500},
}

-- Configure list
list:SetDataProvider(myData)
list:SetItemHeight(40)
list:SetItemTemplate("Button")
list:SetItemSetup(function(item, data, index)
    if not item.label then
        item.label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        item.label:SetPoint("LEFT", 10, 0)
    end
    item.label:SetText(data.name .. " - " .. data.value)
end)

-- Enable reordering
list:InitReorderable()
list:SetReorderEnabled(true)
list:SetReorderModifier("shift")  -- Require shift to drag
list:SetDataReorderCallback(function(fromIndex, toIndex)
    -- Reorder backing data
    local item = table.remove(myData, fromIndex)
    table.insert(myData, toIndex, item)

    print("Reordered:", fromIndex, "->", toIndex)

    -- Refresh list
    list:Refresh()
end)

-- Listen for reorder events
list:RegisterCallback("OnItemReorder", function(fromIndex, toIndex)
    print("Items reordered, saving to database...")
    -- SaveToDatabase(myData)
end)

list:Refresh()
```

### Example 3: Drag Between Different Windows

Drag items from a source window to a target window.

```lua
local Loolib = LibStub("Loolib")
local DragContext = Loolib:GetModule("DragContext")

-- Source window (item list)
local sourceWindow = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
sourceWindow:SetSize(250, 400)
sourceWindow:SetPoint("LEFT", UIParent, "CENTER", -300, 0)
sourceWindow:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"})

local sourceTitle = sourceWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
sourceTitle:SetPoint("TOP", 0, -10)
sourceTitle:SetText("Available Items")

-- Target window (equipped gear)
local targetWindow = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
targetWindow:SetSize(250, 400)
targetWindow:SetPoint("RIGHT", UIParent, "CENTER", 300, 0)
targetWindow:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"})

local targetTitle = targetWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
targetTitle:SetPoint("TOP", 0, -10)
targetTitle:SetText("Equipped Gear")

-- Available items
local availableItems = {
    {icon = "Interface\\Icons\\INV_Sword_39", name = "Thunderfury", slot = "weapon"},
    {icon = "Interface\\Icons\\INV_Shield_05", name = "Bulwark", slot = "offhand"},
    {icon = "Interface\\Icons\\INV_Helmet_74", name = "Crown", slot = "head"},
}

-- Equipped gear (empty initially)
local equippedGear = {}

-- Create draggable items in source window
for i, itemData in ipairs(availableItems) do
    local item = CreateFrame("Button", nil, sourceWindow)
    item:SetSize(40, 40)
    item:SetPoint("TOPLEFT", 10, -40 - (i - 1) * 45)

    local icon = item:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(itemData.icon)

    local label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", item, "RIGHT", 5, 0)
    label:SetText(itemData.name)

    -- Make draggable
    LoolibMixin(item, LoolibDraggableMixin)
    item:InitDraggable()
    item:SetDragEnabled(true)
    item:SetDragData(itemData)
    item:SetUseGhost(true)

    -- Customize ghost
    function item:OnDragStart()
        local ghost = LoolibGetSharedDragGhost()
        ghost:SetIcon(itemData.icon)
        ghost:SetLabel(itemData.name)
        ghost:ShowIndicator(true)
    end
end

-- Create drop zones in target window
local slotPositions = {
    head = {x = 105, y = -50},
    weapon = {x = 50, y = -150},
    offhand = {x = 160, y = -150},
}

for slotName, pos in pairs(slotPositions) do
    local slot = CreateFrame("Frame", nil, targetWindow, "BackdropTemplate")
    slot:SetSize(60, 60)
    slot:SetPoint("TOPLEFT", pos.x, pos.y)
    slot:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    slot:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    slot:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    slot.slotName = slotName
    slot.itemData = nil

    -- Add label
    local label = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", slot, "TOP", 0, 2)
    label:SetText(slotName:upper())

    -- Make drop target
    LoolibMixin(slot, LoolibDropTargetMixin)
    slot:InitDropTarget()
    slot:SetDropEnabled(true)
    slot:SetDropPriority(10)  -- Higher priority than window

    -- Only accept matching slot type
    slot:SetDropValidator(function(dragData)
        return dragData.slot == slotName
    end)

    -- Custom highlight colors
    slot:SetHighlightColors(
        {r = 0.2, g = 0.8, b = 0.2, a = 0.4},  -- Green for valid
        {r = 0.8, g = 0.2, b = 0.2, a = 0.4}   -- Red for invalid
    )

    -- Handle drop
    function slot:OnDropReceived(dragData, sourceFrame)
        -- Store item
        self.itemData = dragData
        equippedGear[slotName] = dragData

        -- Show icon
        if not self.icon then
            self.icon = self:CreateTexture(nil, "ARTWORK")
            self.icon:SetPoint("CENTER")
            self.icon:SetSize(50, 50)
        end
        self.icon:SetTexture(dragData.icon)
        self.icon:Show()

        print("Equipped:", dragData.name, "in", slotName)
    end

    -- Visual feedback
    function slot:OnDropTargetEnter(dragData, isValid)
        if isValid then
            self:SetBackdropBorderColor(0.2, 0.8, 0.2, 1)
        else
            self:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
        end
    end

    function slot:OnDropTargetLeave(dragData)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end
end
```

### Example 4: Custom Drag Ghost with Quality Colors

```lua
local Loolib = LibStub("Loolib")
local DragContext = Loolib:GetModule("DragContext")

-- Quality color mapping
local qualityColors = {
    [1] = {r = 0.6, g = 0.6, b = 0.6},  -- Poor (gray)
    [2] = {r = 1.0, g = 1.0, b = 1.0},  -- Common (white)
    [3] = {r = 0.1, g = 1.0, b = 0.0},  -- Uncommon (green)
    [4] = {r = 0.0, g = 0.4, b = 1.0},  -- Rare (blue)
    [5] = {r = 0.6, g = 0.2, b = 1.0},  -- Epic (purple)
    [6] = {r = 1.0, g = 0.5, b = 0.0},  -- Legendary (orange)
}

-- Create custom ghost
local customGhost = LoolibCreateDragGhost(UIParent, "MyAddonDragGhost")

-- Customize colors for legendary items
customGhost:SetColors(
    {r = 1.0, g = 0.8, b = 0.0, a = 0.8},  -- Gold for valid
    {r = 1.0, g = 0.3, b = 0.3, a = 0.8},  -- Red for invalid
    {r = 1.0, g = 0.5, b = 0.0, a = 1.0},  -- Orange border valid
    {r = 0.8, g = 0.0, b = 0.0, a = 1.0}   -- Dark red border invalid
)

-- Override appearance update to apply quality colors
local originalUpdateAppearance = customGhost._UpdateAppearance
function customGhost:_UpdateAppearance()
    originalUpdateAppearance(self)

    local data = self.dragData
    if data and data.quality and qualityColors[data.quality] then
        local color = qualityColors[data.quality]

        -- Tint background to quality color
        if self.background then
            self.background:SetColorTexture(
                color.r * 0.3,
                color.g * 0.3,
                color.b * 0.3,
                0.9
            )
        end

        -- Tint label to quality color
        if self.label and data.name then
            self.label:SetTextColor(color.r, color.g, color.b, 1)
        end
    end
end

-- Create draggable item
local item = CreateFrame("Button", nil, UIParent)
item:SetSize(50, 50)
item:SetPoint("CENTER", -100, 0)

local icon = item:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexture("Interface\\Icons\\INV_Sword_39")

LoolibMixin(item, LoolibDraggableMixin)
item:InitDraggable()
item:SetDragEnabled(true)
item:SetDragData({
    type = "item",
    id = 12345,
    name = "Thunderfury, Blessed Blade of the Windseeker",
    icon = "Interface\\Icons\\INV_Sword_39",
    quality = 6  -- Legendary
})

-- Use custom ghost
function item:OnDragStart()
    customGhost:ShowFor(self, self:GetDragData())
end

-- Start drag with custom ghost
item:SetScript("OnDragStart", function(self)
    DragContext:StartDrag(self, self:GetDragData(), customGhost)
end)
```

### Example 5: Drag with Validation and Feedback

Advanced example with multiple validation rules and user feedback.

```lua
local Loolib = LibStub("Loolib")
local DragContext = Loolib:GetModule("DragContext")

-- Create main window
local window = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
window:SetSize(400, 300)
window:SetPoint("CENTER")
window:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"})

-- Feedback label
local feedback = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
feedback:SetPoint("TOP", 0, -10)
feedback:SetText("Drag items to zones")

-- Create drop zones with different rules
local zones = {
    {
        name = "Weapons Only",
        x = 50, y = -50,
        validator = function(data)
            return data.type == "weapon"
        end,
        message = "Only weapons allowed"
    },
    {
        name = "High Quality Only",
        x = 50, y = -150,
        validator = function(data)
            return data.quality and data.quality >= 4
        end,
        message = "Only rare or better items"
    },
    {
        name = "Level 60+ Items",
        x = 50, y = -250,
        validator = function(data)
            return data.level and data.level >= 60
        end,
        message = "Only level 60+ items"
    },
}

for _, zoneData in ipairs(zones) do
    local zone = CreateFrame("Frame", nil, window, "BackdropTemplate")
    zone:SetSize(300, 60)
    zone:SetPoint("TOPLEFT", zoneData.x, zoneData.y)
    zone:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    zone:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    zone:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local label = zone:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 10, 0)
    label:SetText(zoneData.name)
    zone.label = label

    zone.message = zoneData.message

    -- Make drop target
    LoolibMixin(zone, LoolibDropTargetMixin)
    zone:InitDropTarget()
    zone:SetDropEnabled(true)
    zone:SetDropValidator(zoneData.validator)

    -- Visual feedback on hover
    function zone:OnDropTargetEnter(dragData, isValid)
        if isValid then
            feedback:SetText("Drop here!")
            feedback:SetTextColor(0.2, 1.0, 0.2)
            self:SetBackdropBorderColor(0.2, 1.0, 0.2, 1)
        else
            feedback:SetText(self.message)
            feedback:SetTextColor(1.0, 0.2, 0.2)
            self:SetBackdropBorderColor(1.0, 0.2, 0.2, 1)
        end
    end

    function zone:OnDropTargetLeave(dragData)
        feedback:SetText("Drag items to zones")
        feedback:SetTextColor(1.0, 1.0, 1.0)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    function zone:OnDropReceived(dragData, sourceFrame)
        self.label:SetText(zoneData.name .. ": " .. dragData.name)
        print("Accepted:", dragData.name)
    end
end

-- Create test items
local testItems = {
    {type = "weapon", name = "Sword", quality = 3, level = 50, icon = "Interface\\Icons\\INV_Sword_39"},
    {type = "weapon", name = "Legendary Axe", quality = 6, level = 60, icon = "Interface\\Icons\\INV_Axe_09"},
    {type = "armor", name = "Epic Plate", quality = 5, level = 60, icon = "Interface\\Icons\\INV_Chest_Plate16"},
    {type = "armor", name = "Common Cloth", quality = 1, level = 10, icon = "Interface\\Icons\\INV_Chest_Cloth_17"},
}

-- Create draggable buttons for test items
local sourceFrame = CreateFrame("Frame", nil, UIParent)
sourceFrame:SetSize(300, 300)
sourceFrame:SetPoint("LEFT", UIParent, "CENTER", -400, 0)

for i, itemData in ipairs(testItems) do
    local btn = CreateFrame("Button", nil, sourceFrame)
    btn:SetSize(40, 40)
    btn:SetPoint("TOPLEFT", 10, -10 - (i - 1) * 45)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(itemData.icon)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", btn, "RIGHT", 5, 0)
    label:SetText(string.format("%s (Q:%d L:%d)", itemData.name, itemData.quality, itemData.level))

    LoolibMixin(btn, LoolibDraggableMixin)
    btn:InitDraggable()
    btn:SetDragEnabled(true)
    btn:SetDragData(itemData)
    btn:SetUseGhost(true)

    function btn:OnDragStart()
        local ghost = LoolibGetSharedDragGhost()
        ghost:SetIcon(itemData.icon)
        ghost:SetLabel(itemData.name)
        ghost:ShowIndicator(true)
    end
end

-- Global drag end feedback
DragContext:RegisterCallback("OnDragEnd", function(target, dragData, success)
    if success then
        feedback:SetText("Drop successful!")
        feedback:SetTextColor(0.2, 1.0, 0.2)
    else
        feedback:SetText("Invalid drop target")
        feedback:SetTextColor(1.0, 0.5, 0.0)
    end

    C_Timer.After(2, function()
        feedback:SetText("Drag items to zones")
        feedback:SetTextColor(1.0, 1.0, 1.0)
    end)
end)
```

---

## Integration

### Integration with ScrollableList

ReorderableMixin is designed to work seamlessly with ScrollableList:

```lua
local list = CreateFrame("Frame", nil, UIParent)
LoolibMixin(list, LoolibScrollableListMixin, LoolibReorderableMixin)
list:OnLoad()
list:InitReorderable()

-- Configure scrollable list
list:SetDataProvider(myData)
list:SetItemHeight(40)
list:SetItemTemplate("Button")
list:SetItemSetup(function(item, data, index)
    -- Set up item display
    item.label:SetText(data.name)

    -- Set up reordering
    list:SetupReorderableItem(item, index)
end)

-- Enable reordering
list:SetReorderEnabled(true)
list:SetDataReorderCallback(function(fromIndex, toIndex)
    local item = table.remove(myData, fromIndex)
    table.insert(myData, toIndex, item)
    list:Refresh()
end)
```

### Integration with SavedVariables

DraggableMixin can save window positions:

```lua
-- SavedVariables table
local db = {profile = {windows = {}}}

-- Create draggable window
local window = CreateFrame("Frame", nil, UIParent)
LoolibMixin(window, LoolibDraggableMixin)
window:InitDraggable()
window:SetDragEnabled(true)
window:SetSavePosition(db.profile.windows, "MainWindow")

-- Restore position on login
window:RegisterEvent("PLAYER_LOGIN")
window:SetScript("OnEvent", function(self)
    if not self:RestorePosition() then
        self:CenterOnScreen()
    end
end)
```

### Integration with WindowUtil

For advanced position management, combine with WindowUtil:

```lua
local WindowUtil = Loolib:GetModule("UI").WindowUtil

-- Register with WindowUtil for full features
WindowUtil.RegisterConfig(window, db.profile.windows)
WindowUtil.MakeDraggable(window)
WindowUtil.EnableMouseWheelScaling(window)

-- OR use DraggableMixin for data transfer drag-drop
LoolibMixin(window, LoolibDraggableMixin)
window:InitDraggable()
window:SetDragEnabled(true)
window:SetDragData({type = "window", id = "main"})
```

---

## Best Practices

### 1. Use Shared Ghost for Simple Cases

```lua
-- Good: Use shared ghost
local ghost = LoolibGetSharedDragGhost()
DragContext:StartDrag(frame, data, ghost)

-- Avoid: Creating new ghost every drag
-- (Creates memory churn)
```

### 2. Set Appropriate Priorities

```lua
-- Child frames should have higher priority
parentFrame:SetDropPriority(0)
childFrame:SetDropPriority(10)

-- Otherwise parent steals drops from child
```

### 3. Validate Early

```lua
-- Good: Use validator function
target:SetDropValidator(function(data)
    return data.type == "item" and data.quality >= 4
end)

-- Avoid: Validation in OnDropReceived
-- (Allows invalid hover highlighting)
```

### 4. Clean Up Event Handlers

```lua
-- Register with owner for easy cleanup
DragContext:RegisterCallback("OnDragEnd", callback, self)

-- Later, unregister all at once
DragContext:UnregisterAllCallbacks(self)
```

### 5. Provide Visual Feedback

```lua
-- Good: Show what's happening
function target:OnDropTargetEnter(dragData, isValid)
    if isValid then
        self.label:SetText("Drop here!")
    else
        self.label:SetText("Can't drop here")
    end
end

-- Users appreciate knowing what's valid
```

### 6. Handle Modifier Keys Appropriately

```lua
-- For reordering, require modifier to prevent accidents
list:SetReorderModifier("shift")

-- For simple dragging, no modifier needed
frame:SetDragModifier(nil)
```

### 7. Save Reorder to Database

```lua
list:SetDataReorderCallback(function(fromIndex, toIndex)
    -- Reorder backing data
    local item = table.remove(myData, fromIndex)
    table.insert(myData, toIndex, item)

    -- Save to database
    SaveToDatabase(myData)
end)
```

### 8. Use Type-Based Filtering

```lua
-- Simple: Use SetAcceptedTypes
target:SetAcceptedTypes("item", "spell")

-- Complex: Use custom validator
target:SetDropValidator(function(data)
    return (data.type == "item" and data.quality >= 4) or
           (data.type == "spell" and data.school == "frost")
end)
```

---

## Summary

The DragDrop system provides a complete, coordinated solution for drag-and-drop in WoW addons. Use it whenever you need:

- Draggable UI elements with data transfer
- Drop targets with validation and visual feedback
- List item reordering
- Professional drag-and-drop UX

Start with the Quick Start examples, then explore the API reference for advanced features. The event system and override points provide extensive customization while maintaining coordinated behavior across your entire UI.
