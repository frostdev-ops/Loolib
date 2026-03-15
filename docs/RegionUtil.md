# RegionUtil Module Documentation

## Overview

**RegionUtil** provides utilities for creating and manipulating regions (textures, font strings, lines) in WoW 12.0+ addons. Covers creation helpers, text truncation, bounding-box math, overlap detection, color management, and batch visibility.

Registered as `UI.RegionUtil`. Also accessible via `Loolib.RegionUtil`.

---

## API Reference

### Texture Utilities

#### CreateColorTexture(parent, r, g, b, a, layer)

Create a solid-color texture.

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `parent` | Frame | yes | -- | Parent frame |
| `r` | number | yes | -- | Red (0-1) |
| `g` | number | yes | -- | Green (0-1) |
| `b` | number | yes | -- | Blue (0-1) |
| `a` | number | no | 1 | Alpha (0-1) |
| `layer` | string | no | `"BACKGROUND"` | Draw layer |

**Returns:** Texture

#### CreateTexture(parent, texturePath, layer)

Create a texture from a file path.

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `parent` | Frame | yes | -- | Parent frame |
| `texturePath` | string | yes | -- | File path |
| `layer` | string | no | `"ARTWORK"` | Draw layer |

**Returns:** Texture

#### CreateAtlasTexture(parent, atlasName, layer)

Create a texture from a Blizzard atlas.

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `parent` | Frame | yes | -- | Parent frame |
| `atlasName` | string | yes | -- | Atlas name |
| `layer` | string | no | `"ARTWORK"` | Draw layer |

**Returns:** Texture

#### SetTexCoord(texture, left, right, top, bottom)

Set texture coordinates. All four coords are required numbers.

#### CalculateSpriteTexCoords(col, row, cols, rows)

Calculate tex coords for a grid-based sprite sheet. All four params required; `cols` and `rows` must be positive.

**Returns:** `left, right, top, bottom`

---

### FontString Utilities

#### CreateFontString(parent, fontObject, layer)

Create a FontString.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `parent` | Frame | -- | Parent frame |
| `fontObject` | string | `"GameFontNormal"` | Font object |
| `layer` | string | `"OVERLAY"` | Draw layer |

**Returns:** FontString

#### CreateText(parent, text, fontObject, layer)

Create a FontString with initial text. `text` may be nil (no text set).

**Returns:** FontString

#### ConfigureFontString(fontString, options)

Batch-configure a FontString. `options` is a table with optional fields:

| Field | Type | Description |
|---|---|---|
| `text` | string | Text content |
| `font` | string | Font path (requires `size` too) |
| `size` | number | Font size |
| `outline` | string | Outline flags (`"OUTLINE"`, `"THICKOUTLINE"`, etc.) |
| `color` | table | `{r,g,b,a}` or `{[1],[2],[3],[4]}` |
| `shadow` | table | `{x, y, color={r,g,b,a}}` |
| `justifyH` | string | Horizontal justify |
| `justifyV` | string | Vertical justify |
| `wordWrap` | boolean | Word wrap |
| `nonSpaceWrap` | boolean | Non-space wrap |
| `maxLines` | number | Max lines |

#### TruncateText(fontString, maxWidth, suffix)

Truncate text with binary search to fit `maxWidth` pixels. Appends `suffix` (default `"..."`).

| Parameter | Type | Required | Description |
|---|---|---|---|
| `fontString` | FontString | yes | Target font string |
| `maxWidth` | number | yes | Max width in pixels (must be positive) |
| `suffix` | string | no | Truncation suffix (default `"..."`) |

---

### Line Utilities

#### CreateHorizontalLine(parent, thickness, color, layer)

Create a horizontal divider texture.

#### CreateVerticalLine(parent, thickness, color, layer)

Create a vertical divider texture.

Both accept optional `color` as `{r, g, b, a}` (defaults to grey 0.5/0.5/0.5).

---

### Region Bounds

#### GetBoundingBox(regions)

Get the bounding box of an array of visible regions.

**Returns:** `left, right, top, bottom` (all nil if no visible regions with valid positions).

#### DoRegionsOverlap(region1, region2)

Check if two regions overlap. Returns `false` for nil inputs or regions without valid positions.

#### IsPointInRegion(region, x, y)

Check if a point `(x, y)` is inside a region. Returns `false` for nil/invalid inputs.

---

### Color Utilities

#### SetColor(region, r, g, b, a)

Apply color to a Texture (vertex color), FontString (text color), or Line (color texture). Auto-detects region type via `IsObjectType`.

#### GetColor(region)

Get the color from a region. Returns `1, 1, 1, 1` for unsupported or nil regions.

---

### Visibility

#### SetShown(regions, shown)

Set the shown state of an array of regions. Skips nil entries gracefully.

#### HideAll(...)

Hide all passed regions (varargs). Skips nil entries.

#### ShowAll(...)

Show all passed regions (varargs). Skips nil entries.

---

## Input Validation

- Parent frame params validate `CreateTexture` capability.
- Region params validate `IsObjectType` capability.
- Color and coordinate params validate numeric types.
- All errors use `error("LoolibRegionUtil.<func>: ...", 2)`.
