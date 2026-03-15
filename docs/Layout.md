# Loolib Layout System

The Layout family provides CSS-flexbox-inspired layout management for WoW UI
frames. All layout types inherit from `LayoutBaseMixin` and share the same
child management, dirty-flag, and auto-size APIs.

## Quick Start

```lua
local Loolib = LibStub("Loolib")
local UI = Loolib.UI

-- Fluent builder
local vbox = UI.Layout(container)
    :Vertical()
    :Spacing(5)
    :Padding(10)
    :AlignItems("LEFT")
    :Build()

vbox:AddChild(button1)
vbox:AddChild(button2)
vbox:Layout()

-- Direct factory
local hbox = Loolib.CreateHorizontalLayout(container, {
    spacing = 8,
    alignItems = "CENTER",
})
```

## Files

| File | Module | Description |
|------|--------|-------------|
| `UI/Layout/LayoutBase.lua` | `Layout.LayoutBase` | Base mixin (child mgmt, padding, spacing, dirty flag, auto-size) |
| `UI/Layout/VerticalLayout.lua` | `Layout.VerticalLayout` | Top-to-bottom child stacking |
| `UI/Layout/HorizontalLayout.lua` | `Layout.HorizontalLayout` | Left-to-right child stacking |
| `UI/Layout/GridLayout.lua` | `Layout.GridLayout` | Fixed-column grid arrangement |
| `UI/Layout/FlowLayout.lua` | `Layout.FlowLayout` | Wrapping flow (horizontal or vertical) |
| `UI/Layout/LayoutBuilder.lua` | `Layout.LayoutBuilder` | Fluent builder API |

## Important Behavior Notes

### ClearAllPoints (LY-01)

All layout types call `child:ClearAllPoints()` during `Layout()`. This is
standard layout engine behavior -- the layout manager owns the positioning of
its children. Any external anchors set on managed children will be destroyed.

**Workaround:** Wrap the externally-anchored element in a container frame and
add the container to the layout instead.

### Auto-Size and Reentrancy (LY-04)

When `autoSize` is enabled (default), `SetContentSize()` calls
`container:SetSize()` which may fire `OnSizeChanged`. If that handler calls
back into the layout, the `layoutInProgress` reentrancy guard prevents
infinite recursion. The dirty flag is set and a deferred re-layout fires in
the next frame after the current layout completes.

### RemoveChild Complexity (LY-05)

`RemoveChild(child)` uses a linear search O(n) to find the child by reference
equality. This is acceptable for typical UI layouts (< 100 children). If the
index is known, prefer `RemoveChildByIndex(index)` for O(1) removal.

### Grid Per-Cell Alignment (LY-06)

`GridLayout` does not support per-child alignment within cells. All children
are anchored at `TOPLEFT` of their cell. To align a child within its cell,
wrap it in a container frame with internal anchoring.

---

## API Reference

### LayoutBaseMixin (inherited by all layouts)

#### Child Management

| Method | Signature | Description |
|--------|-----------|-------------|
| `AddChild` | `(child, index?) -> number` | Add child at index (or append). Errors if child is nil. |
| `AddChildren` | `(...)` | Add multiple children (varargs). |
| `RemoveChild` | `(child) -> boolean` | Remove by reference. O(n) search. |
| `RemoveChildByIndex` | `(index) -> Region\|nil` | Remove by index. O(1). |
| `ClearChildren` | `()` | Remove all children. |
| `GetChild` | `(index) -> Region\|nil` | Get child at index. |
| `GetChildren` | `() -> table` | Get the children array (direct reference). |
| `GetNumChildren` | `() -> number` | Total child count. |
| `HasChildren` | `() -> boolean` | True if any children exist. |
| `EnumerateChildren` | `() -> iterator` | ipairs iterator over children. |
| `FindChildIndex` | `(child) -> number\|nil` | Find index of child. O(n). |
| `MoveChild` | `(child, newIndex)` | Reorder a child. |
| `GetVisibleChildren` | `() -> table` | Array of shown children only. |
| `GetNumVisibleChildren` | `() -> number` | Count of shown children. |

#### Configuration

| Method | Signature | Description |
|--------|-----------|-------------|
| `SetPadding` | `(left, right?, top?, bottom?)` | Set per-side padding. |
| `SetUniformPadding` | `(padding)` | Set all sides to same value. |
| `SetSpacing` | `(spacing)` | Set spacing between children. |
| `SetAutoSize` | `(bool)` | Enable/disable container auto-sizing. |
| `GetContainer` | `() -> Frame` | Get the container frame. |
| `GetConfig` | `() -> table` | Get the config table. |

#### Layout Control

| Method | Signature | Description |
|--------|-----------|-------------|
| `Layout` | `()` | Perform layout if dirty. Subclass override. |
| `ForceLayout` | `()` | Force immediate layout (sets dirty, calls Layout). |
| `MarkDirty` | `()` | Flag for deferred relayout (next frame). |
| `MarkClean` | `()` | Clear the dirty flag. |
| `IsDirty` | `() -> boolean` | Check dirty state. |

#### Size Queries

| Method | Signature | Description |
|--------|-----------|-------------|
| `GetContentSize` | `() -> width, height` | Content dimensions (excluding padding). |
| `GetAvailableSpace` | `() -> width, height` | Container size minus padding. |
| `GetChildSize` | `(child) -> width, height` | Child size (respects layoutWidth/layoutHeight hints). |
| `ShouldStretch` | `(child, axis) -> boolean` | Check layoutStretchWidth/Height hint. |

---

### VerticalLayoutMixin

Stacks children top-to-bottom (or bottom-to-top with `direction = "UP"`).

#### Config Options

| Key | Type | Default | Values |
|-----|------|---------|--------|
| `alignItems` | string | `"LEFT"` | `LEFT`, `CENTER`, `RIGHT`, `STRETCH` |
| `justifyContent` | string | `"START"` | `START`, `CENTER`, `END`, `SPACE_BETWEEN`, `SPACE_AROUND` |
| `direction` | string | `"DOWN"` | `DOWN`, `UP` |

#### Per-Child Hints

| Property | Type | Effect |
|----------|------|--------|
| `child.layoutWeight` | number | Proportional share of remaining vertical space. Only used when totalWeight > 0 and remainingSpace > 0. |
| `child.layoutWidth` | number | Override width for layout calculation. |
| `child.layoutHeight` | number | Override height for layout calculation. |
| `child.layoutStretchWidth` | boolean | Hint for ShouldStretch queries. |

#### Setters

- `SetAlignItems(align)` -- validates against LEFT|CENTER|RIGHT|STRETCH
- `SetJustifyContent(justify)` -- validates against START|CENTER|END|SPACE_BETWEEN|SPACE_AROUND
- `SetDirection(direction)` -- validates against DOWN|UP

#### Factory

```lua
local layout = Loolib.CreateVerticalLayout(container, config?)
```

---

### HorizontalLayoutMixin

Stacks children left-to-right (or right-to-left with `direction = "LEFT"`).

#### Config Options

| Key | Type | Default | Values |
|-----|------|---------|--------|
| `alignItems` | string | `"TOP"` | `TOP`, `CENTER`, `BOTTOM`, `STRETCH` |
| `justifyContent` | string | `"START"` | `START`, `CENTER`, `END`, `SPACE_BETWEEN`, `SPACE_AROUND` |
| `direction` | string | `"RIGHT"` | `RIGHT`, `LEFT` |

#### Per-Child Hints

| Property | Type | Effect |
|----------|------|--------|
| `child.layoutWeight` | number | Proportional share of remaining horizontal space. |
| `child.layoutWidth` | number | Override width for layout calculation. |
| `child.layoutHeight` | number | Override height for layout calculation. |
| `child.layoutStretchHeight` | boolean | Hint for ShouldStretch queries. |

#### Setters

- `SetAlignItems(align)` -- validates against TOP|CENTER|BOTTOM|STRETCH
- `SetJustifyContent(justify)` -- validates against START|CENTER|END|SPACE_BETWEEN|SPACE_AROUND
- `SetDirection(direction)` -- validates against RIGHT|LEFT

#### Factory

```lua
local layout = Loolib.CreateHorizontalLayout(container, config?)
```

---

### GridLayoutMixin

Arranges children in a fixed-column grid.

#### Config Options

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `columns` | number | `4` | Number of columns. |
| `rows` | number\|nil | auto | Number of rows (nil = auto-calculate). |
| `cellWidth` | number\|nil | auto | Fixed cell width (nil = largest child). |
| `cellHeight` | number\|nil | auto | Fixed cell height (nil = largest child). |
| `cellSpacing` | number | `0` | Uniform cell spacing. |
| `columnSpacing` | number | cellSpacing | Horizontal gap between cells. |
| `rowSpacing` | number | cellSpacing | Vertical gap between cells. |
| `fillDirection` | string | `"ROW"` | `ROW` (left-to-right, top-to-bottom) or `COLUMN`. |
| `resizeToFit` | boolean | `false` | Resize children to match cell size. |

#### Grid Queries

- `GetCellPosition(index) -> row, col` (0-based)
- `GetChildAt(row, col) -> Region|nil`
- `GetChildGridPosition(child) -> row, col|nil`
- `CalculateCellSize() -> width, height`
- `CalculateGridDimensions(numChildren) -> rows, cols`

#### Setters

- `SetColumns(n)` -- must be positive number
- `SetRows(n|nil)` -- positive number or nil for auto
- `SetCellSize(w, h?)` -- positive numbers
- `SetCellSpacing(colSpacing, rowSpacing?)`
- `SetFillDirection(dir)` -- validates ROW|COLUMN
- `SetResizeToFit(bool)`

#### Factory

```lua
local layout = Loolib.CreateGridLayout(container, config?)
```

---

### FlowLayoutMixin

Wraps children into rows (horizontal) or columns (vertical) when space runs
out. Oversized children (wider/taller than available space) are placed on
their own line automatically (LY-03).

#### Config Options

| Key | Type | Default | Values |
|-----|------|---------|--------|
| `direction` | string | `"HORIZONTAL"` | `HORIZONTAL`, `VERTICAL` |
| `wrapSpacing` | number | spacing | Gap between wrapped rows/columns. |
| `alignContent` | string | `"START"` | `START`, `CENTER`, `END` (row/column alignment). |
| `alignItems` | string | `"START"` | `START`, `CENTER`, `END` (item alignment within row/column). |

#### Setters

- `SetDirection(dir)` -- validates HORIZONTAL|VERTICAL
- `SetWrapSpacing(n)` -- must be number
- `SetAlignContent(align)` -- validates START|CENTER|END
- `SetAlignItems(align)` -- validates START|CENTER|END

#### Factory

```lua
local layout = Loolib.CreateFlowLayout(container, config?)
```

---

### LayoutBuilderMixin (Fluent API)

```lua
local layout = UI.Layout(container)
    :Vertical()            -- or :Horizontal(), :Grid(cols), :Flow(dir)
    :Spacing(5)
    :Padding(10)           -- uniform, or :PaddingEach(l, r, t, b)
    :AlignItems("CENTER")
    :JustifyContent("SPACE_BETWEEN")
    :AutoSize(true)
    :Build()

-- Or build with children in one call:
local layout = UI.Layout(container)
    :Horizontal()
    :Spacing(4)
    :BuildWithChildren(btn1, btn2, btn3)
```

#### Grid-specific builder methods

- `:Columns(n)`, `:Rows(n)`, `:CellSize(w, h?)`, `:CellSpacing(col, row?)`
- `:FillDirection(dir)`, `:ResizeToFit(bool)`

#### Flow-specific builder methods

- `:WrapSpacing(n)`, `:AlignContent(align)`

---

## Global Exports

| Global | Type | Description |
|--------|------|-------------|
| `Loolib.LayoutBaseMixin` | table | Base layout mixin. |
| `Loolib.VerticalLayoutMixin` | table | Vertical layout mixin. |
| `Loolib.HorizontalLayoutMixin` | table | Horizontal layout mixin. |
| `Loolib.GridLayoutMixin` | table | Grid layout mixin. |
| `Loolib.FlowLayoutMixin` | table | Flow layout mixin. |
| `Loolib.LayoutBuilderMixin` | table | Builder mixin. |
| `Loolib.CreateVerticalLayout` | function | Factory. |
| `Loolib.CreateHorizontalLayout` | function | Factory. |
| `Loolib.CreateGridLayout` | function | Factory. |
| `Loolib.CreateFlowLayout` | function | Factory. |
| `Loolib.CreateLayoutBuilder` | function | Builder factory. |
| `Loolib.LayoutBuilder` | function | Alias for `UI.Layout()`. |

---

## Error Format

All errors follow the convention:
```
"LoolibLayoutName: MethodName: message"
```
with `error(..., 2)` to report at the caller's stack level.
