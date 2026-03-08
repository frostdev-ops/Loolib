# Loolib Widgets

This directory contains widget enhancements and fluent APIs for WoW frames.

## Files

### WidgetMod.lua

Core fluent API mixin inspired by MRT's `Mod()` pattern. Provides chainable methods for rapid UI development.

**Key Features:**
- Chainable sizing/positioning (`:Size()`, `:Point()`, `:NewPoint()`)
- Chainable appearance (`:Alpha()`, `:Scale()`, `:Shown()`)
- Chainable script handlers (`:OnClick()`, `:OnEnter()`, `:OnShow()`, etc.)
- Smart tooltip system (`:Tooltip()`, `:TooltipAnchor()`)
- Utility methods (`:Run()`, `:Movable()`, `:Mouse()`)

**Documentation:** [/Loolib/docs/WidgetMod.md](../../docs/WidgetMod.md)

### WidgetMod_Examples.lua

Real-world usage examples including:
- Information panels
- Action buttons
- Settings panels with controls
- Scrollable lists
- Fade animations
- Context menus

### WidgetMod_Test.lua

Test suite for WidgetMod (only loads if `LOOLIB_RUN_TESTS` is true).

## Quick Usage

```lua
-- Create frame with fluent API
local frame = LoolibCreateModFrame("Frame", UIParent)
    :Size(200, 100)
    :Point("CENTER")
    :Alpha(0.9)
    :Tooltip("Custom Frame")

-- Apply to existing frame
local existing = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
LoolibApplyWidgetMod(existing)
existing:Size(100, 30):Point("TOPLEFT", 10, -10):Text("Click")
```

## See Also

- [Core/FrameUtil.lua](../Core/FrameUtil.lua) - Advanced frame utilities
- [Factory/WidgetBuilder.lua](../Factory/WidgetBuilder.lua) - Widget factory pattern
- [Templates/](../Templates/) - Reusable UI components
