# Tooltip

Custom tooltip system with flexible content and anchor support.

## Overview

The Tooltip module provides a custom tooltip widget (`LoolibTooltipMixin`) and a builder pattern for convenient construction. Tooltips support multi-line content, double lines (left + right), blank lines, separators, color codes, and 9 anchor positions including cursor-relative.

## Basic Usage

### Factory Function

```lua
local Loolib = LibStub("Loolib")
local UI = Loolib:GetModule("UI.Tooltip")

local tooltip = UI.Create(parentFrame)
tooltip:SetTitle("My Tooltip", 1, 0.82, 0)
tooltip:AddLine("Line one", 1, 1, 1)
tooltip:AddDoubleLine("Left", "Right", 0.7, 0.7, 0.7, 0, 1, 0)
tooltip:AddSeparator()
tooltip:AddLine("Footer", 0.5, 0.5, 0.5)
tooltip:SetOwner(someFrame, "ANCHOR_RIGHT")
tooltip:Show()
```

### Builder Pattern

```lua
local tooltip = UI.Builder(someFrame)
    :SetTitle("Item Info")
    :AddLine("iLvl 489", 0, 1, 0)
    :AddDoubleLine("Strength", "+120", 1, 1, 1, 0, 1, 0)
    :SetAnchor("ANCHOR_CURSOR", 10, 10)
    :Build()
```

### Attach to Frame (auto show/hide)

```lua
tooltip:AttachToFrame(myButton, "ANCHOR_RIGHT")
```

## API Reference

### LoolibTooltipMixin

#### OnLoad()
Initialize internal state. Called automatically by the factory.

#### SetTitle(title, r, g, b)
Set the tooltip title.

#### AddLine(text, r, g, b)
Add a single-line entry. Colors default to white.

#### AddDoubleLine(leftText, rightText, leftR, leftG, leftB, rightR, rightG, rightB)
Add a left-right pair on the same line.

#### AddBlankLine()
Add an empty line for spacing.

#### AddSeparator()
Add a horizontal separator (dashes).

#### Clear()
Remove all lines and reset title/text.

#### SetOwner(owner, anchor, offsetX, offsetY)
Set the anchor frame and positioning. Valid anchors:
`ANCHOR_RIGHT`, `ANCHOR_LEFT`, `ANCHOR_TOP`, `ANCHOR_BOTTOM`,
`ANCHOR_TOPRIGHT`, `ANCHOR_TOPLEFT`, `ANCHOR_BOTTOMRIGHT`, `ANCHOR_BOTTOMLEFT`,
`ANCHOR_CURSOR`.

#### Show()
Build content, position, and display the tooltip.

#### AttachToFrame(frame, anchor)
Hook `OnEnter`/`OnLeave` on a frame for automatic show/hide.

### Factory

```lua
UI.Tooltip.Create(parent) -> tooltip
```

### Builder

```lua
UI.Tooltip.Builder(frame) -> builderChain
```

## Hardening Notes

- **TP-01**: `Show()` uses a cached `Frame.Show` reference instead of a fragile `getmetatable(self).__index.Show(self)` call that crashes if the metatable chain is non-standard.
- **TP-02**: `ClampToScreen()` nil-guards `GetLeft()`/`GetRight()`/`GetTop()`/`GetBottom()` which return nil before the frame is positioned.
- **TP-07**: `BuildContent()` uses `table.concat` instead of string concatenation in a loop.

## Known Limitations

- Content uses a single FontString (`self.Text`) with color escape sequences rather than per-line FontStrings. This means word-wrap and per-line alignment are limited.
- Double-line spacing is achieved with spaces, not columnar layout.

## See Also

- [ColorSwatch.md](ColorSwatch.md) - Color picker widgets
- [FramePool.md](FramePool.md) - Frame pooling
