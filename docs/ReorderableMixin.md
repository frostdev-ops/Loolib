# ReorderableMixin - List Item Drag-to-Reorder

**File:** `UI/DragDrop/ReorderableMixin.lua`

Mixin for scrollable lists that enables drag-and-drop item reordering functionality. List items can be dragged and dropped to change their order with visual feedback and customizable behavior.

## Features

- **Visual drop indicator** - Blue line showing where item will be inserted
- **Modifier key support** - Optional Shift/Ctrl/Alt requirement for dragging
- **Customizable drag button** - Left, right, or middle mouse button
- **Data synchronization** - Callback to reorder backing data arrays
- **Event callbacks** - Track drag lifecycle (start, end, reorder)
- **Automatic restoration** - Items snap back to original position if not dropped on valid target
- **Multiple list patterns** - Works with ScrollableList, custom lists, and MRT-style lists

## Table of Contents

- [Basic Usage](#basic-usage)
- [API Reference](#api-reference)
- [Integration Patterns](#integration-patterns)
- [Events](#events)
- [Examples](#examples)

## Basic Usage

### With ScrollableList

```lua
local Loolib = LibStub("Loolib")

-- Create list with reorderable mixin
local list = CreateFrame("Frame", nil, parent)
LoolibMixin(list, LoolibScrollableListMixin, LoolibReorderableMixin)
list:OnLoad()
list:InitReorderable()

-- Set up data
local myData = {"Item 1", "Item 2", "Item 3", "Item 4"}
local dataProvider = CreateLoolibDataProvider()
for _, item in ipairs(myData) do
    dataProvider:Insert(item)
end

list:SetDataProvider(dataProvider)
list:SetItemHeight(24)

-- Configure reordering
list:SetReorderEnabled(true)
list:SetReorderButton("LeftButton")
list:SetReorderModifier("shift")  -- Require Shift key

-- Set up data reorder callback
list:SetDataReorderCallback(function(fromIndex, toIndex)
    -- Reorder the backing data array
    local item = table.remove(myData, fromIndex)
    table.insert(myData, toIndex, item)

    -- Rebuild data provider
    dataProvider:Flush()
    for _, d in ipairs(myData) do
        dataProvider:Insert(d)
    end
end)
```

### With Custom List

```lua
local frame = CreateFrame("Frame", nil, parent)
LoolibMixin(frame, LoolibReorderableMixin)
frame:InitReorderable()

-- Your list data
frame.data = {"Player 1", "Player 2", "Player 3"}

-- Create list lines
frame.List = {}
for i = 1, 10 do
    local line = CreateFrame("Button", nil, frame)
    -- ... configure line
    frame.List[i] = line
end

-- Update function
function frame:Update()
    for i = 1, #self.List do
        local line = self.List[i]
        local data = self.data[i]

        if data then
            line.Text:SetText(data)
            line:Show()

            -- Enable reordering for this item
            self:SetupReorderableItem(line, i)
        else
            line:Hide()
        end
    end
end

-- Configure reordering
frame:SetReorderEnabled(true)
frame:SetDataReorderCallback(function(fromIndex, toIndex)
    local item = table.remove(frame.data, fromIndex)
    table.insert(frame.data, toIndex, item)
    frame:Update()
end)

frame:Update()
```

## API Reference

### LoolibReorderableMixin

Mixin for list container frames.

#### Initialization

##### `InitReorderable()`

Initialize the reorderable system. Must be called after `OnLoad()`.

```lua
list:OnLoad()
list:InitReorderable()
```

#### Configuration Methods

All configuration methods return `self` for method chaining.

##### `SetReorderEnabled(enabled)`

Enable or disable drag-to-reorder functionality.

**Parameters:**
- `enabled` (boolean) - True to enable, false to disable

**Returns:** self

```lua
list:SetReorderEnabled(true)
```

##### `SetReorderButton(button)`

Set which mouse button initiates drag.

**Parameters:**
- `button` (string) - Mouse button: "LeftButton", "RightButton", "MiddleButton"

**Returns:** self

**Default:** "LeftButton"

```lua
list:SetReorderButton("RightButton")
```

##### `SetReorderModifier(modifier)`

Require a modifier key to be held during drag.

**Parameters:**
- `modifier` (string|nil) - Modifier key: "shift", "ctrl", "alt", or nil for no requirement

**Returns:** self

**Default:** nil (no modifier required)

```lua
list:SetReorderModifier("shift")  -- Require Shift key
list:SetReorderModifier(nil)      -- No modifier required
```

##### `SetDataReorderCallback(callback)`

Set callback for reordering backing data array.

**Parameters:**
- `callback` (function) - Function signature: `callback(fromIndex, toIndex)`

**Returns:** self

The callback receives:
- `fromIndex` (number) - Original position of dragged item
- `toIndex` (number) - New position for item

**Important:** The callback is responsible for reordering the backing data array. If `toIndex > fromIndex`, the callback should account for the removal shifting indices.

```lua
list:SetDataReorderCallback(function(fromIndex, toIndex)
    -- Remove item from old position
    local item = table.remove(myData, fromIndex)
    -- Insert at new position
    table.insert(myData, toIndex, item)

    -- Update UI (if needed)
    list:Refresh()
end)
```

#### Item Setup

##### `SetupReorderableItem(item, index)`

Set up a list item frame for reordering. Call this when creating/acquiring list items in your refresh logic.

**Parameters:**
- `item` (Frame) - The list item frame
- `index` (number) - The item's position in the list

```lua
function MyList:Update()
    for i = 1, #self.data do
        local frame = self:AcquireItem()
        frame.data = self.data[i]

        -- Enable reordering for this item
        self:SetupReorderableItem(frame, i)
    end
end
```

#### Manual Control

##### `SwapItems(index1, index2)`

Programmatically swap two items.

**Parameters:**
- `index1` (number) - First item index
- `index2` (number) - Second item index

```lua
-- Swap items at positions 1 and 3
list:SwapItems(1, 3)
```

### LoolibReorderableItemMixin

Optional mixin for individual list item frames.

##### `InitReorderableItem()`

Initialize a reorderable item.

##### `SetListIndex(index)`

Set this item's list index.

##### `GetListIndex()`

Get this item's list index.

**Returns:** (number|nil)

##### `GetParentList()`

Get the parent list frame.

**Returns:** (Frame|nil)

## Integration Patterns

### Pattern 1: ScrollableList Integration

The ReorderableMixin integrates seamlessly with `LoolibScrollableListMixin`:

```lua
local list = CreateFrame("Frame", nil, parent)
LoolibMixin(list, LoolibScrollableListMixin, LoolibReorderableMixin)
list:OnLoad()
list:InitReorderable()

-- ScrollableList handles item creation/pooling
-- ReorderableMixin adds drag functionality

list:SetReorderEnabled(true)
```

### Pattern 2: Custom List (_items table)

For lists that maintain an `_items` table:

```lua
local list = CreateFrame("Frame", nil, parent)
LoolibMixin(list, LoolibReorderableMixin)
list:InitReorderable()

list._items = {}

function list:CreateItem(index)
    local item = CreateFrame("Button", nil, self)
    self._items[index] = item
    self:SetupReorderableItem(item, index)
    return item
end

list:SetReorderEnabled(true)
```

### Pattern 3: MRT-Style List (List array)

For lists that use a `List` array (MRT addon pattern):

```lua
local frame = CreateFrame("Frame", nil, parent)
LoolibMixin(frame, LoolibReorderableMixin)
frame:InitReorderable()

frame.List = {}

for i = 1, 10 do
    local line = CreateFrame("Button", nil, frame)
    frame.List[i] = line
end

function frame:Update()
    for i, line in ipairs(self.List) do
        if self.data[i] then
            line:Show()
            self:SetupReorderableItem(line, i)
        else
            line:Hide()
        end
    end
end

frame:SetReorderEnabled(true)
```

### Pattern 4: Complex Data Structures

For lists with complex object data:

```lua
local players = {
    {name = "Tank", class = "WARRIOR", role = "TANK"},
    {name = "Healer", class = "PRIEST", role = "HEALER"},
    {name = "DPS1", class = "MAGE", role = "DPS"},
}

list:SetDataReorderCallback(function(fromIndex, toIndex)
    local player = table.remove(players, fromIndex)
    table.insert(players, toIndex, player)

    -- Rebuild data provider with new order
    dataProvider:Flush()
    for _, p in ipairs(players) do
        dataProvider:Insert(p)
    end
end)
```

## Events

Register event callbacks using the standard callback system:

```lua
list:RegisterCallback("OnItemDragStart", function(owner, item, index)
    print("Started dragging item at index", index)
end)

list:RegisterCallback("OnItemDragEnd", function(owner, item, fromIndex, toIndex)
    if toIndex then
        print("Dropped at index", toIndex)
    else
        print("Drag cancelled")
    end
end)

list:RegisterCallback("OnItemReorder", function(owner, fromIndex, toIndex)
    print("Reordered:", fromIndex, "->", toIndex)
end)
```

### OnItemDragStart

Fired when dragging begins.

**Parameters:**
- `owner` - Callback owner
- `item` (Frame) - The dragged item frame
- `index` (number) - The item's original index

### OnItemDragEnd

Fired when dragging ends (whether successful or cancelled).

**Parameters:**
- `owner` - Callback owner
- `item` (Frame) - The dragged item frame
- `fromIndex` (number) - The item's original index
- `toIndex` (number|nil) - The target index, or nil if drag was cancelled

### OnItemReorder

Fired when items are successfully reordered.

**Parameters:**
- `owner` - Callback owner
- `fromIndex` (number) - Original index
- `toIndex` (number) - New index

## Examples

### Example 1: Simple List with Shift+Drag

```lua
local data = {"Apple", "Banana", "Cherry", "Date"}
local dataProvider = CreateLoolibDataProvider()
for _, item in ipairs(data) do
    dataProvider:Insert(item)
end

local list = CreateLoolibScrollableList(parent)
list:InitReorderable()
list:SetDataProvider(dataProvider)
list:SetItemHeight(24)
list:SetInitializer(function(frame, itemData, index)
    if not frame.Text then
        frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.Text:SetPoint("LEFT", 8, 0)
    end
    frame.Text:SetText(itemData)
end)

list:SetReorderEnabled(true)
    :SetReorderModifier("shift")
    :SetDataReorderCallback(function(fromIndex, toIndex)
        local item = table.remove(data, fromIndex)
        table.insert(data, toIndex, item)

        dataProvider:Flush()
        for _, d in ipairs(data) do
            dataProvider:Insert(d)
        end
    end)
```

### Example 2: Right-Click Drag, No Modifier

```lua
list:SetReorderEnabled(true)
    :SetReorderButton("RightButton")
    :SetReorderModifier(nil)
```

### Example 3: With Event Logging

```lua
local Logger = Loolib:GetModule("Logger")

list:RegisterCallback("OnItemDragStart", function(_, item, index)
    Logger:Info("Drag started:", index)
end)

list:RegisterCallback("OnItemDragEnd", function(_, item, fromIndex, toIndex)
    if toIndex then
        Logger:Info("Drag completed:", fromIndex, "->", toIndex)
    else
        Logger:Warn("Drag cancelled")
    end
end)

list:RegisterCallback("OnItemReorder", function(_, fromIndex, toIndex)
    Logger:Info("Data reordered")
    -- Save to SavedVariables
    MySavedData.itemOrder = data
end)
```

### Example 4: Reorderable Player List

```lua
local players = {"Tank", "Healer", "DPS1", "DPS2", "DPS3"}

local list = CreateLoolibScrollableList(parent)
list:InitReorderable()

local dataProvider = CreateLoolibDataProvider()
for _, player in ipairs(players) do
    dataProvider:Insert(player)
end

list:SetDataProvider(dataProvider)
list:SetItemHeight(32)
list:SetInitializer(function(frame, player, index)
    if not frame.Icon then
        frame.Icon = frame:CreateTexture(nil, "ARTWORK")
        frame.Icon:SetSize(24, 24)
        frame.Icon:SetPoint("LEFT", 4, 0)

        frame.Name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.Name:SetPoint("LEFT", frame.Icon, "RIGHT", 8, 0)
    end

    frame.Icon:SetTexture(GetPlayerIcon(player))
    frame.Name:SetText(player)
end)

list:SetReorderEnabled(true)
    :SetReorderButton("LeftButton")
    :SetReorderModifier("shift")
    :SetDataReorderCallback(function(fromIndex, toIndex)
        local player = table.remove(players, fromIndex)
        table.insert(players, toIndex, player)

        -- Save new order
        MyAddonDB.playerOrder = players

        -- Refresh list
        dataProvider:Flush()
        for _, p in ipairs(players) do
            dataProvider:Insert(p)
        end
    end)
```

### Example 5: Programmatic Reordering

```lua
-- Create up/down buttons for selected item
local upBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
upBtn:SetText("Move Up")
upBtn:SetScript("OnClick", function()
    local selected = list:GetFirstSelected()
    if selected then
        local index = dataProvider:FindIndex(selected)
        if index > 1 then
            list:SwapItems(index, index - 1)
        end
    end
end)

local downBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
downBtn:SetText("Move Down")
downBtn:SetScript("OnClick", function()
    local selected = list:GetFirstSelected()
    if selected then
        local index = dataProvider:FindIndex(selected)
        if index < dataProvider:GetSize() then
            list:SwapItems(index, index + 1)
        end
    end
end)
```

## Implementation Details

### Drop Indicator

The mixin creates a visual drop indicator (blue line) that shows where the dragged item will be inserted:

- **Color:** Blue (0.3, 0.7, 1.0) with glow effect
- **Height:** 2 pixels
- **Position:** Dynamically positioned above or below target item during drag

### Drag Mechanics

1. **Drag Start:**
   - Checks modifier key requirement
   - Saves original anchor points
   - Sets dragged item to 50% opacity
   - Starts OnUpdate loop to track mouse position
   - Hides tooltip

2. **During Drag:**
   - Continuously checks mouse position
   - Detects target item under cursor
   - Shows/hides drop indicator
   - Determines insertion point (before/after target)

3. **Drag End:**
   - Stops OnUpdate loop
   - Hides drop indicator
   - Restores original position
   - Calculates final target index
   - Calls data reorder callback
   - Refreshes list
   - Fires events

### Index Adjustment

When moving an item down the list (toIndex > fromIndex), the implementation automatically adjusts for the removal:

```lua
-- User drags item from index 2 to drop after index 4
-- fromIndex = 2, toIndex = 5 (after item 4)
-- After removal at index 2, item 4 becomes index 3
-- So we adjust: toIndex = 5 - 1 = 4
```

This ensures the item ends up in the correct position.

### List Pattern Detection

The mixin automatically detects different list patterns:

1. **ScrollableList:** `self.visibleItems` (hash table)
2. **MRT Pattern:** `self.List` (indexed array)
3. **Generic:** `self._items` (any table)

## Best Practices

### 1. Always Set Data Callback

The mixin doesn't know about your data structure. Always provide a data reorder callback:

```lua
list:SetDataReorderCallback(function(fromIndex, toIndex)
    -- Reorder your data here
end)
```

### 2. Refresh After Reorder

If using DataProvider, flush and rebuild after reordering:

```lua
list:SetDataReorderCallback(function(fromIndex, toIndex)
    local item = table.remove(myData, fromIndex)
    table.insert(myData, toIndex, item)

    -- Rebuild provider
    dataProvider:Flush()
    for _, d in ipairs(myData) do
        dataProvider:Insert(d)
    end
end)
```

### 3. Use Modifier Keys for Complex UIs

If your list items have interactive elements (buttons, checkboxes), require a modifier key:

```lua
list:SetReorderModifier("shift")  -- Prevents accidental drags
```

### 4. Save Order Changes

Persist reordered data to SavedVariables:

```lua
list:RegisterCallback("OnItemReorder", function()
    MyAddonDB.savedOrder = myData
end)
```

### 5. Provide Visual Feedback

The mixin handles basic feedback (opacity, indicator), but you can enhance it:

```lua
list:RegisterCallback("OnItemDragStart", function(_, item)
    item:SetScale(0.9)  -- Shrink slightly
end)

list:RegisterCallback("OnItemDragEnd", function(_, item)
    item:SetScale(1.0)  -- Restore size
end)
```

## See Also

- [ScrollableList.md](ScrollableList.md) - Virtual scrolling list component
- [DataProvider.md](DataProvider.md) - Data collection management
- [CallbackRegistry.md](CallbackRegistry.md) - Event system
