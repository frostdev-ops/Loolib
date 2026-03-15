# ScrollableList

Virtual scrolling list with DataProvider integration, columns, sorting, and selection.

## Overview

`LoolibScrollableListMixin` provides a high-level list widget with:

- Virtual scrolling (only visible items are rendered)
- Frame pooling for list items
- DataProvider integration with automatic refresh on data changes
- Selection modes: NONE, SINGLE, MULTI (with Ctrl+click and Shift+range)
- Column headers with click-to-sort and sort arrows
- Custom cell rendering via `DoCellUpdate` callbacks
- Filter function support
- Right-click context menus
- Mouse wheel scrolling

## Basic Usage

### Factory Function

```lua
local Loolib = LibStub("Loolib")
local UI = Loolib:GetModule("UI.ScrollableList")

local list = UI.Create(parentFrame)
list:SetItemHeight(24)
list:SetSelectionMode("SINGLE")
list:SetInitializer(function(frame, data, index)
    frame.Text:SetText(data.name)
end)
list:SetDataProvider(myDataProvider)
list:SetPoint("TOPLEFT", 10, -40)
list:SetSize(300, 400)
```

### Builder Pattern

```lua
local list = UI.Builder(parentFrame)
    :SetItemHeight(28)
    :SetSelectionMode("MULTI")
    :SetInitializer(function(frame, data, index)
        frame.Text:SetText(data.name)
    end)
    :SetDataProvider(myDataProvider)
    :OnSelectionChanged(function(owner, selection)
        print("Selected", #selection, "items")
    end)
    :Build()
```

### With Columns

```lua
list:SetColumns({
    { name = "Name",  width = 150, sort = "asc" },
    { name = "Level", width = 60,  sort = "dsc",
      DoCellUpdate = function(row, cell, data, cols, rowIdx, realRow, colIdx, tbl)
          cell.text:SetText(tostring(data.level))
      end
    },
})
```

## API Reference

### LoolibScrollableListMixin

#### Configuration

| Method | Description |
|--------|-------------|
| SetItemTemplate(template) | XML template name for items |
| SetItemHeight(height) | Pixel height per row (default 24) |
| SetInitializer(func) | `function(frame, data, index)` called per visible item |
| SetSelectionMode(mode) | "NONE", "SINGLE", or "MULTI" |
| SetColumns(columns) | Array of column definitions |
| SetFilterFunc(func) | `function(data) -> bool` to filter displayed items |
| SetOnRowRightClick(func) | Right-click handler `function(data, index, button)` |

#### Data Provider

| Method | Description |
|--------|-------------|
| SetDataProvider(provider) | Bind a DataProvider (auto-refresh on changes) |
| GetDataProvider() | Get the current DataProvider |

#### Selection

| Method | Description |
|--------|-------------|
| SelectData(data) | Select an item |
| DeselectData(data) | Deselect an item |
| ToggleSelect(data) | Toggle selection |
| ClearSelection() | Clear all selections |
| GetSelection() | Array of selected data elements |
| GetFirstSelected() | First selected element or nil |
| IsSelected(data) | Boolean check |

#### Scrolling

| Method | Description |
|--------|-------------|
| ScrollToData(data) | Scroll to make a data element visible |
| ScrollToIndex(index) | Scroll to a specific index |
| ScrollToTop() | Scroll to top |
| ScrollToBottom() | Scroll to bottom |

#### Sorting

| Method | Description |
|--------|-------------|
| SortByColumn(index) | Sort by column (toggles direction on repeat) |

### Events

| Event | Payload | Description |
|-------|---------|-------------|
| OnSelectionChanged | selection (array) | Selection changed |
| OnItemClicked | data, index, button | Item left-clicked |
| OnItemDoubleClicked | data, index, button | Item double-clicked |
| OnItemRightClick | data, index, button | Item right-clicked |
| OnItemEnter | data, index, frame | Mouse entered item |
| OnItemLeave | data, index, frame | Mouse left item |
| OnColumnClick | colIndex, direction | Column header clicked |
| OnSort | colIndex, direction | Sort applied |

## Hardening Notes

- **TP-05**: `Refresh()` tracks a signature of `(numFilteredItems, firstVisible, lastVisible)` and short-circuits if unchanged since the last render. `MarkDirty()` sets a force-refresh flag so data mutations always trigger a full re-render.
- All `math.*` calls use cached local references.
- The duplicate `SetScript("OnClick", ...)` assignment in the original code (which silently overwrote the first handler) has been consolidated into a single handler that dispatches by button type.

## Known Limitations

- Full virtualization (reusing item frames across scroll without `ReleaseAll`) is not implemented. Each `Refresh()` that passes the signature check releases all frames and re-acquires visible ones. This is O(visible) per refresh, which is adequate for lists up to ~1000 items but may need optimization for very large datasets.
- Column resizing (drag between headers) is documented in the header but not yet implemented.

## See Also

- [DataProvider.md](DataProvider.md) - Data source integration
- [FramePool.md](FramePool.md) - Frame pooling internals
- [ObjectPool.md](ObjectPool.md) - Generic object pooling
