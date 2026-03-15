# FramePool

Specialized factory functions for creating `ObjectPool` instances pre-configured for WoW frames, textures, font strings, lines, and actors. Each factory wraps `CreateObjectPool` with the appropriate `CreateFrame` / `CreateTexture` / etc. call and a type-specific default resetter.

## Module Access

```lua
local Loolib = LibStub("Loolib")

-- Top-level factories
local pool = Loolib.CreateFramePool("Button", UIParent)
local pool = Loolib.CreateTexturePool(parentFrame, "ARTWORK")

-- Module table
local FramePool = Loolib:GetModule("Pool.FramePool")
local pool = FramePool.CreateFramePool("Frame", UIParent)
```

## Factory Functions

### CreateFramePool(frameType, parent, template, resetFunc, capacity)

Create a pool of WoW frames.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `frameType` | string | No | `"Frame"` | Frame type ("Frame", "Button", etc.) |
| `parent` | Frame | No | nil | Parent frame for created frames |
| `template` | string | No | nil | XML template name |
| `resetFunc` | function | No | auto | Reset function. Auto-selected by frame type if nil. |
| `capacity` | number | No | unlimited | Max active frames |

Returns an ObjectPool instance with additional metadata fields: `pool.frameType`, `pool.parent`, `pool.template`.

```lua
local rowPool = Loolib.CreateFramePool("Button", scrollContent, "BackdropTemplate", function(_, frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame.data = nil
end)
```

### CreateFramePoolWithMixins(frameType, parent, template, resetFunc, mixins, capacity)

Like `CreateFramePool` but applies mixins to each frame on creation:
- If `mixins` is an array, all are applied via `Mixin(frame, unpack(mixins))`.
- If `mixins` is a single table, applied via `Mixin(frame, mixins)`.
- Script handlers are reflected after mixin application.
- If the frame has an `Init` method after mixin, it is called.

Additional metadata: `pool.mixins`.

```lua
local pool = Loolib.CreateFramePoolWithMixins("Frame", UIParent, nil, nil, {MyRowMixin})
```

### CreateTexturePool(parent, layer, subLayer, template, resetFunc, capacity)

Create a pool of texture regions.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `parent` | Frame | Yes | -- | Parent frame (errors if nil) |
| `layer` | string | No | `"ARTWORK"` | Draw layer |
| `subLayer` | number | No | `0` | Sub-layer |
| `template` | string | No | nil | XML template |
| `resetFunc` | function | No | `ResetTexture` | Reset function |
| `capacity` | number | No | unlimited | Max active textures |

Additional metadata: `pool.parent`, `pool.layer`, `pool.subLayer`, `pool.template`.

### CreateFontStringPool(parent, layer, subLayer, template, resetFunc, capacity)

Create a pool of font string regions.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `parent` | Frame | Yes | -- | Parent frame (errors if nil) |
| `layer` | string | No | `"OVERLAY"` | Draw layer |
| `subLayer` | number | No | `0` | Sub-layer |
| `template` | string | No | nil | Font template |
| `resetFunc` | function | No | `ResetFontString` | Reset function |
| `capacity` | number | No | unlimited | Max active font strings |

### CreateLinePool(parent, layer, subLayer, template, resetFunc, capacity)

Create a pool of line regions.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `parent` | Frame | Yes | -- | Parent frame (errors if nil) |
| `layer` | string | No | `"ARTWORK"` | Draw layer |
| `subLayer` | number | No | `0` | Sub-layer |
| `template` | string | No | nil | XML template |
| `resetFunc` | function | No | built-in | Hides, clears points, resets color/thickness |
| `capacity` | number | No | unlimited | Max active lines |

### CreateActorPool(modelScene, resetFunc, capacity)

Create a pool of model scene actors.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `modelScene` | ModelScene | Yes | -- | Model scene frame (errors if nil) |
| `resetFunc` | function | No | built-in | Clears model and hides |
| `capacity` | number | No | unlimited | Max active actors |

Additional metadata: `pool.modelScene`.

## Utility

### AcquireFrame(pool, initializer) -> frame, isNew

Acquire from a pool and run an initializer on first creation only.

```lua
local frame, isNew = Loolib.AcquireFrame(myPool, function(f)
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
end)
```

`pool` is required (errors if nil).

## Input Validation

All factory functions validate:
- `frameType` (when applicable) must be a string
- `resetFunc` (when provided) must be a function
- `parent`/`modelScene` (when required) must not be nil

Invalid inputs raise errors with `level = 2` (caller's stack frame).

## Pool Metadata

Every pool created by a FramePool factory stores metadata on the pool table itself:

| Field | Description |
|-------|-------------|
| `frameType` | The frame type string |
| `parent` | The parent frame |
| `template` | The XML template name |
| `mixins` | Mixin table(s) (CreateFramePoolWithMixins only) |
| `layer` | Draw layer (texture/font/line pools) |
| `subLayer` | Sub-layer (texture/font/line pools) |
| `modelScene` | The model scene (actor pools) |

## Consumers

- `Loolib/UI/Factory/FrameFactory.lua` -- uses `CreatePoolCollection` (which wraps `CreateFramePool`)
- `Loolib/UI/Templates/ScrollableList.lua` -- uses `CreateFramePool` and `CreateObjectPool`
- `Loolib/UI/Templates/TabbedPanel.lua` -- uses `CreateObjectPool`
- `Loolib/UI/Canvas/CanvasFrame.lua` -- uses `CreateFramePool` for dot/shape/text/icon/image pools
- `Loothing/UI/VersionCheckPanel.lua` -- `CreateFramePool("Frame", content)`
- `Loothing/UI/HistoryPanel.lua` -- `CreateFramePool("Button", ...)`
- `Loothing/UI/RosterPanel.lua` -- `CreateFramePool("Button", ...)`
- `Loothing/UI/CouncilTable.lua` -- `CreateFramePool("Button", ..., "BackdropTemplate", ...)`

## Source

`Loolib/UI/Pool/FramePool.lua`
