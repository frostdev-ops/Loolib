# PoolResetters

Standard reset functions for pooled WoW UI objects. Called by `ObjectPool` when objects are released (and on first creation) to return them to a clean default state.

## Module Access

```lua
local Loolib = LibStub("Loolib")
local PoolResetters = Loolib:GetModule("Pool.PoolResetters")
-- or
local PoolResetters = Loolib.UI.PoolResetters
```

Individual resetters are also available as top-level Loolib globals:

```lua
Loolib.PoolReset_Frame
Loolib.PoolReset_Button
Loolib.PoolReset_Texture
-- etc.
```

## Reset Function Signature

All reset functions share the same signature:

```lua
function(pool, object, isNew)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `pool` | table | The pool that owns the object |
| `object` | Region/Frame | The UI object being reset |
| `isNew` | boolean | `true` on first creation, `false` on release |

## Standard Resetters

### HideAndClearAnchors

Minimal reset. Hides the region and clears all anchor points.

```lua
PoolResetters.HideAndClearAnchors
```

### Frame

Comprehensive frame reset. Clears:
- Visibility (Hide)
- Anchor points
- Alpha (1), Scale (1), Size (0,0)
- Button enabled state (if applicable)
- OnUpdate, OnEnter, OnLeave scripts
- `.data`, `.elementData`, `.layoutIndex` fields

```lua
PoolResetters.Frame
```

### Button

Full button reset. Everything in Frame plus:
- Text cleared
- Normal/Pushed/Highlight textures cleared
- OnClick, OnEnter, OnLeave scripts cleared
- `.data` field cleared

```lua
PoolResetters.Button
```

### Texture

Texture region reset. Clears:
- Visibility, anchors, alpha
- Texture file (nil), tex coords (0,1,0,1)
- Vertex color (white), desaturation (off), rotation (0)
- Size (0,0)

```lua
PoolResetters.Texture
```

### FontString

Font string reset. Clears:
- Visibility, anchors, alpha
- Text (empty), color (white)
- Justify (CENTER/MIDDLE), word wrap (on), non-space wrap (off)

```lua
PoolResetters.FontString
```

### EditBox

Edit box reset. Clears:
- Visibility, anchors, alpha, size
- Text (empty), enabled (true), auto-focus (off), focus cleared
- OnTextChanged, OnEnterPressed, OnEscapePressed scripts

```lua
PoolResetters.EditBox
```

### Slider

Slider reset. Clears:
- Visibility, anchors, alpha, size
- Enabled (true), value (min value)
- OnValueChanged script

```lua
PoolResetters.Slider
```

### StatusBar

Status bar reset. Clears:
- Visibility, anchors, alpha, size
- Min/max (0,1), value (0)

```lua
PoolResetters.StatusBar
```

### CheckButton

Check button reset. Clears:
- Visibility, anchors, alpha, size
- Enabled (true), checked (false)
- `.text` child text cleared
- OnClick script

```lua
PoolResetters.CheckButton
```

### ScrollFrame

Scroll frame reset. Clears:
- Visibility, anchors, alpha, size
- Vertical scroll (0), horizontal scroll (0)

```lua
PoolResetters.ScrollFrame
```

## Factory Functions

### CreateChained(baseReset, customReset)

Chain two reset functions. The base runs first, then the custom.

```lua
local myReset = PoolResetters.CreateChained(
    PoolResetters.Frame,
    function(pool, frame, isNew)
        frame.myCustomField = nil
    end
)
```

Both arguments must be functions; passing non-function values raises an error.

### GetForFrameType(frameType, additionalReset)

Returns the appropriate resetter for a WoW frame type string. Falls back to `ResetFrame` for unknown types.

```lua
local resetter = PoolResetters.GetForFrameType("Button")
local chainedResetter = PoolResetters.GetForFrameType("Button", myExtraReset)
```

`frameType` must be a string. `additionalReset`, if provided, must be a function.

### GetForRegionType(regionType, additionalReset)

Returns the appropriate resetter for a region type ("Texture", "FontString"). Falls back to `HideAndClearAnchors` for unknown types.

```lua
local resetter = PoolResetters.GetForRegionType("Texture")
```

## Ownership

PoolResetters is a stateless utility module. The functions themselves are pure -- they have no side effects beyond modifying the object passed to them. The pool system calls these functions; consumers rarely call them directly.

## Source

`Loolib/UI/Pool/PoolResetters.lua`
