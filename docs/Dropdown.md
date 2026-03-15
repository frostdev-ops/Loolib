# Dropdown

Customizable dropdown menu with submenus, icons, and item pooling.

## Overview

The Dropdown module provides `LoolibDropdownMixin`, a full-featured dropdown widget supporting:

- Simple option lists
- Multi-level nested submenus with arrows
- Disabled items, checkmarks, radio buttons
- Color codes, icons, separators
- Tooltips on hover
- Click-outside-to-close behaviour
- Keyboard escape to close

A shared singleton menu frame is reused across all dropdowns. Menu item frames are pooled internally to avoid frame creation/orphaning on every open (TP-03).

## Basic Usage

### Factory Function

```lua
local Loolib = LibStub("Loolib")
local UI = Loolib:GetModule("UI.Dropdown")

local dd = UI.Create(parentFrame)
dd:SetOptions({
    { value = "opt1", text = "Option One" },
    { value = "opt2", text = "Option Two", disabled = true },
    { value = "opt3", text = "Option Three", colorCode = "|cFFFF0000" },
})
dd:SetPlaceholder("Choose...")
dd:SetSelectedValue("opt1")
dd:SetPoint("TOPLEFT", 20, -20)
```

### Builder Pattern

```lua
local dd = UI.Builder(parentFrame)
    :AddOption("a", "Alpha")
    :AddOption("b", "Beta")
    :SetPlaceholder("Pick one")
    :OnSelect(function(owner, value, text) print(value) end)
    :Build()
```

### Listening to Selection

```lua
dd:RegisterCallback("OnSelect", function(owner, value, text)
    print("Selected:", value, text)
end)
```

## API Reference

### LoolibDropdownMixin

#### OnLoad()
Initialize internal state. Called automatically by the factory.

#### SetOptions(options)
Set the full options array. Each entry:
```lua
{
    value    = any,
    text     = string,
    icon     = string|nil,      -- texture path
    disabled = boolean|nil,
    isSeparator = boolean|nil,
    hasArrow = boolean|nil,     -- submenu indicator
    submenu  = table|nil,       -- nested options array
    checked  = boolean|nil,
    isNotRadio = boolean|nil,   -- checkmark vs radio dot
    colorCode = string|nil,     -- e.g. "|cFFFF0000"
    tooltipTitle = string|nil,
    tooltipText  = string|nil,
}
```

#### AddOption(value, text, options)
Append a single option.

#### ClearOptions()
Remove all options.

#### SetSelectedValue(value)
Programmatically select an option. Updates display text.

#### GetSelectedValue() -> any
#### GetSelectedText() -> string|nil

#### SetPlaceholder(text)
Text shown when nothing is selected.

#### ToggleMenu()
Open or close the dropdown menu.

#### OpenMenu() / CloseMenu()
Explicit open/close.

#### SetMaxVisibleItems(max)
Cap the visible item count (default 10).

#### SetItemHeight(height)
Set pixel height per item (default 20).

### Events

| Event | Payload | Description |
|-------|---------|-------------|
| OnSelect | value, text | An option was chosen |
| OnOpen | -- | Menu opened |
| OnClose | -- | Menu closed |

### Factory

```lua
UI.Dropdown.Create(parent) -> dropdown
```

### Builder

```lua
UI.Dropdown.Builder(parent) -> builderChain
```

## Hardening Notes

- **TP-03**: Menu item frames are pooled per menu container (main menu, submenu). `BuildMenu()` resets the pool and acquires from it instead of creating and orphaning `Button`/`Frame` children on every call.
- Stale tooltip scripts from a previous pool cycle are explicitly cleared.
- Input validation on `SetOptions`.

## Known Limitations

- Only one dropdown menu can be open at a time (shared singleton).
- Submenu depth is limited to one level (main + submenu).
- No built-in search/filter (feature documented in header but not yet implemented).

## See Also

- [EnhancedDropdown.md](EnhancedDropdown.md) - Extended dropdown variant
- [PopupMenu.md](PopupMenu.md) - Context menu system
