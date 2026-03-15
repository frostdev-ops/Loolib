# Templates

Lua-based template initialization functions for Loolib UI components.

## Overview

`Loolib.Templates` (registered as module `UI.Templates`) provides Lua initialization functions that replace XML templates. This avoids "Deferred XML Node already exists" errors when both standalone and embedded copies of Loolib are loaded -- LibStub guards Lua from double-loading; XML has no such guard.

Each `Init*` function takes a frame and configures its size, child regions, scripts, and backdrop.

## Available Templates

| Function | Target Type | Default Size | Description |
|----------|-------------|-------------|-------------|
| InitPanel | Frame | 300x200 | Base panel with Title FontString and dialog backdrop |
| InitCloseButton | Button | 24x24 | Close button sizing |
| InitButton | Button | 100x22 | Standard button sizing |
| InitListItem | Button | 200x24 | Scrollable list row with Background, Highlight, Text |
| InitScrollableList | Frame | 250x300 | Scroll container with ScrollFrame + Content |
| InitTabButton | Button | 80x28 | Tab button with borders, text, highlight |
| InitTabbedPanel | Frame | 400x300 | Tab bar + content frame with backdrop |
| InitTooltip | Frame | 200x50 | Tooltip frame at TOOLTIP strata |
| InitDialog | Frame | 320x160 | Modal dialog with Title, Message, CloseButton, ButtonContainer |
| InitModalOverlay | Frame | fullscreen | Semi-transparent blocking overlay |
| InitDropdown | Frame | 150x24 | Dropdown trigger with arrow button + text |
| InitDropdownMenu | Frame | 150x100 | Dropdown popup with scroll content |
| InitDropdownMenuItem | Button | 140x20 | Menu item with Highlight, Text, Check |
| InitInputDialog | Frame | 320x140 | Dialog extended with EditBox |

## Usage

```lua
local Loolib = LibStub("Loolib")
local Templates = Loolib.Templates

-- Create a panel frame
local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
Templates.InitPanel(panel)
panel:SetPoint("CENTER")
```

## Hardening Notes

- **TP-08**: All `SetBackdrop` calls go through a `SafeSetBackdrop` guard that checks for `BackdropTemplate` inheritance before calling `frame:SetBackdrop()`. If the frame lacks the method (e.g., created without `"BackdropTemplate"`), the call is skipped with a debug message instead of crashing.
- Consumers MUST pass frames created with `"BackdropTemplate"` in the `CreateFrame` inherits argument for backdrop features to work. The guard prevents crashes but the backdrop will be absent.

## Module Registration

```lua
Loolib.Templates         -- direct access
Loolib.UI.Templates      -- namespaced access
Loolib:GetModule("UI.Templates")  -- module lookup
```

## See Also

- [Tooltip.md](Tooltip.md) - Custom tooltip system (uses InitTooltip)
- [Dropdown.md](Dropdown.md) - Dropdown component (uses InitDropdown*)
- [ScrollableList.md](ScrollableList.md) - Scrollable list (uses InitScrollableList, InitListItem)
- [TabbedPanel.md](TabbedPanel.md) - Tabbed container (uses InitTabbedPanel, InitTabButton)
- [ColorSwatch.md](ColorSwatch.md) - Color picker widgets
