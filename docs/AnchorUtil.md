# AnchorUtil Module Documentation

## Overview

**AnchorUtil** provides utilities for frame and region anchoring and positioning in WoW 12.0+ addons. It wraps the standard `SetPoint`/`ClearAllPoints` API with convenience methods for common positioning patterns: relative placement, centering, corner pinning, grid layout, anchor chains, and screen clamping.

Registered as `UI.AnchorUtil`. Also accessible via `Loolib.AnchorUtil`.

---

## API Reference

### Point Utilities

#### SetPoint(region, point, relativeTo, relativePoint, offsetX, offsetY)

Set a single anchor point on a region, clearing existing points first.

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `region` | Region | yes | -- | The region/frame to anchor |
| `point` | string | yes | -- | Anchor point name (e.g. `"TOPLEFT"`) |
| `relativeTo` | Frame/nil | no | parent | Frame to anchor relative to |
| `relativePoint` | string/nil | no | same as `point` | Point on `relativeTo` |
| `offsetX` | number | no | 0 | Horizontal offset |
| `offsetY` | number | no | 0 | Vertical offset |

#### SetAllPoints(region, relativeTo, inset)

Fill a parent frame, optionally with uniform insets.

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `region` | Region | yes | -- | The region to anchor |
| `relativeTo` | Frame/nil | no | parent | Frame to fill |
| `inset` | number/nil | no | nil | Uniform inset from all edges |

#### SetAllPointsWithInsets(region, relativeTo, left, right, top, bottom)

Fill a parent frame with per-side insets.

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `region` | Region | yes | -- | The region to anchor |
| `relativeTo` | Frame/nil | no | parent | Frame to fill |
| `left` | number | no | 0 | Left inset |
| `right` | number | no | 0 | Right inset |
| `top` | number | no | 0 | Top inset |
| `bottom` | number | no | 0 | Bottom inset |

---

### Relative Positioning

#### SetToRightOf(region, relativeTo, spacing, verticalOffset)

Position a region to the right of another (`LEFT` anchored to `RIGHT`).

#### SetToLeftOf(region, relativeTo, spacing, verticalOffset)

Position a region to the left of another (`RIGHT` anchored to `LEFT`).

#### SetBelow(region, relativeTo, spacing, horizontalOffset)

Position a region below another (`TOP` anchored to `BOTTOM`).

#### SetAbove(region, relativeTo, spacing, horizontalOffset)

Position a region above another (`BOTTOM` anchored to `TOP`).

All four accept:
| Parameter | Type | Required | Default |
|---|---|---|---|
| `region` | Region | yes | -- |
| `relativeTo` | Region | yes | -- |
| `spacing` | number | no | 0 |
| `offset` | number | no | 0 |

---

### Center Positioning

#### CenterHorizontally(region, relativeTo, verticalPoint, verticalOffset)

Center horizontally using a vertical anchor (`"TOP"`, `"CENTER"`, `"BOTTOM"`).

#### CenterVertically(region, relativeTo, horizontalPoint, horizontalOffset)

Center vertically using a horizontal anchor (`"LEFT"`, `"CENTER"`, `"RIGHT"`).

#### Center(region, relativeTo, offsetX, offsetY)

Center both axes on `relativeTo`.

---

### Corner Positioning

#### SetCorner(region, relativeTo, corner, offsetX, offsetY)

Pin a region to a corner. `corner` must be one of: `"TOPLEFT"`, `"TOPRIGHT"`, `"BOTTOMLEFT"`, `"BOTTOMRIGHT"`.

---

### Grid Positioning

#### CalculateGridPosition(index, columns, cellWidth, cellHeight, spacingX, spacingY, paddingLeft, paddingTop)

Pure calculation -- returns `x, y` offsets for a 1-based grid index. No frame manipulation.

**Validates:** `index >= 1`, `columns >= 1`, `cellWidth`/`cellHeight` must be numbers.

#### SetGridPosition(region, parent, index, columns, cellWidth, cellHeight, spacingX, spacingY, paddingLeft, paddingTop)

Anchor a region at the computed grid position inside `parent`.

---

### Anchor Points Table

#### SetPointsFromTable(region, points)

Apply multiple anchor points from a config table. Each entry can be:
- A table: `{point, relativeTo, relativePoint, x, y}` or `{point=..., relativeTo=..., ...}`
- A string: simple point name

---

### Anchor Chains

#### ChainVertically(regions, parent, startPoint, spacing, padding, alignment)

Chain an array of regions vertically. First region anchors to `parent`; subsequent regions anchor to the previous.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `regions` | table | -- | Array of regions |
| `parent` | Frame | -- | Parent frame |
| `startPoint` | string | `"TOP"` | `"TOP"` or `"BOTTOM"` |
| `spacing` | number | 0 | Vertical gap |
| `padding` | number | 0 | Padding from parent edge |
| `alignment` | string | `"CENTER"` | `"LEFT"`, `"CENTER"`, or `"RIGHT"` |

#### ChainHorizontally(regions, parent, startPoint, spacing, padding, alignment)

Chain an array of regions horizontally. Same pattern, horizontal axis.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `startPoint` | string | `"LEFT"` | `"LEFT"` or `"RIGHT"` |
| `alignment` | string | `"CENTER"` | `"TOP"`, `"CENTER"`, or `"BOTTOM"` |

---

### Screen Positioning

#### ClampToScreen(frame, margin)

Clamp a frame to screen bounds. If the frame has no valid position, returns silently. Otherwise adjusts the frame center to stay within the margin on all edges.

#### CenterOnScreen(frame)

Center a frame on `UIParent`.

---

## Input Validation

All functions that accept a `region` parameter validate it has `ClearAllPoints`. All functions that accept anchor point names validate them against the canonical set of 9 WoW anchor points. Invalid inputs raise `error("LoolibAnchorUtil.<func>: ...", 2)`.
