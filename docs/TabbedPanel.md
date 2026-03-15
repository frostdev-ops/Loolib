# TabbedPanel

Tabbed container with lazy content loading and tab button pooling.

## Overview

`LoolibTabbedPanelMixin` provides a multi-tab container supporting:

- Lazy content initialization (function factory per tab)
- Tab button pooling via ObjectPool
- Enable/disable individual tabs
- Badge/notification indicators
- Tab positions: TOP, BOTTOM, LEFT, RIGHT
- Configurable spacing and minimum width

## Basic Usage

### Factory Function

```lua
local Loolib = LibStub("Loolib")
local UI = Loolib:GetModule("UI.TabbedPanel")

local panel = UI.Create(parentFrame)
panel:SetSize(500, 400)

panel:AddTab("general", "General", function()
    local f = CreateFrame("Frame")
    -- build general settings UI
    return f
end)

panel:AddTab("advanced", "Advanced", function()
    local f = CreateFrame("Frame")
    -- build advanced settings UI
    return f
end, { badge = 3 })

panel:SelectTab("general")
```

### Builder Pattern

```lua
local panel = UI.Builder(parentFrame)
    :SetTabPosition("TOP")
    :AddTab("tab1", "Overview", overviewFrame)
    :AddTab("tab2", "Details", function() return detailsFrame end)
    :OnTabChanged(function(owner, newId, oldId)
        print("Switched from", oldId, "to", newId)
    end)
    :Build()
```

## API Reference

### LoolibTabbedPanelMixin

#### Tab Management

| Method | Description |
|--------|-------------|
| AddTab(id, text, content, options) | Add a tab. `content` is a Frame or `function() -> Frame`. Options: `{ enabled, badge, icon }` |
| RemoveTab(id) | Remove a tab by ID |
| GetTab(id) | Get tab data table or nil |
| GetTabs() | Array of all tab data |

#### Selection

| Method | Description |
|--------|-------------|
| SelectTab(id) | Switch to a tab (lazy-creates content if needed) |
| GetActiveTab() | Current tab ID or nil |

#### Tab State

| Method | Description |
|--------|-------------|
| SetTabEnabled(id, enabled) | Enable/disable a tab |
| SetTabBadge(id, badge) | Set badge text/number (nil to clear) |
| SetTabText(id, text) | Change tab button text |

#### Configuration

| Method | Description |
|--------|-------------|
| SetTabPosition(pos) | "TOP", "BOTTOM", "LEFT", "RIGHT" |
| SetTabSpacing(px) | Gap between tab buttons (default 2) |
| SetTabMinWidth(px) | Minimum tab button width (default 60) |

### Events

| Event | Payload | Description |
|-------|---------|-------------|
| OnTabChanged | newId, previousId | Active tab changed |
| OnTabAdded | tabData | Tab was added |
| OnTabRemoved | tabData | Tab was removed |

### Factory

```lua
UI.TabbedPanel.Create(parent) -> panel
```

### Builder

```lua
UI.TabbedPanel.Builder(parent) -> builderChain
```

## Hardening Notes

- **TP-06**: Tab buttons are pooled via `ObjectPool` and recycled on `RefreshTabButtons()`. Content frames produced by lazy initializer functions are NOT pooled (accepted design trade-off -- panels rarely exceed ~10 tabs). The `AddTab` doc comment explains this.
- Input validation on `AddTab`: id must be string, text must be string, content must not be nil, duplicate IDs are rejected.
- `math.max` calls use cached local reference.

## Known Limitations

- Content frames created by lazy initializers are never released -- they persist for the lifetime of the panel. For dynamic tab counts, consider wrapping content creation with an external FramePool.
- Badge display requires the tab button template to have a `.Badge` FontString (the default `InitTabButton` does not create one -- consumers must extend the template).

## See Also

- [ObjectPool.md](ObjectPool.md) - Object pooling
- [FramePool.md](FramePool.md) - Frame pooling
