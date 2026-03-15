# FrameFactory & WidgetBuilder

The `ui-factory` family provides two modules for creating WoW frames in Loolib:

- **FrameFactory** (`Factory.FrameFactory`) -- Pool-backed frame creation with template detection
- **WidgetBuilder** (`Factory.WidgetBuilder`) -- Fluent builder API for common widget types

## FrameFactory

### Quick Start

```lua
local Loolib = LibStub("Loolib")

-- Create a frame via the default factory (pool-backed)
local frame, isNew = Loolib.CreateFrame(parentFrame, "Frame")

-- Create a frame from a template
local btn, isNew2 = Loolib.CreateFrame(parentFrame, "UIPanelButtonTemplate")

-- Create with mixins
local panel, isNew3 = Loolib.CreateFrameWithMixins(parentFrame, "BackdropTemplate", nil, MyPanelMixin)

-- Release back to pool
Loolib.ReleaseFrame(frame)
```

### API Reference

#### Module Access

```lua
local FrameFactory = Loolib:GetModule("Factory.FrameFactory")
-- or
local factory = Loolib.FrameFactory  -- default singleton instance
```

#### Factory Instance Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `Create` | `(parent, frameTemplateOrType, resetFunc?)` | `Frame, boolean, table?` | Acquire or create a frame. Returns frame, isNew flag, and template info (if applicable). |
| `CreateWithMixins` | `(parent, frameTemplateOrType, resetFunc?, ...)` | `Frame, boolean` | Like Create, but applies mixin tables to newly created frames. At least one mixin required. |
| `Release` | `(frame)` | `boolean` | Return a frame to its pool. |
| `ReleaseAll` | `()` | -- | Release all active frames. |
| `GetOrCreatePool` | `(frameType, parent, template, resetFunc?)` | `table, boolean` | Get or create a specific sub-pool. |
| `GetPoolCollection` | `()` | `table` | Get the underlying PoolCollection. |
| `GetTemplateInfoCache` | `()` | `table` | Get the TemplateInfoCache. |
| `GetNumActive` | `()` | `number` | Count of active (acquired) frames. |
| `GetNumPools` | `()` | `number` | Count of sub-pools. |
| `EnumerateActive` | `()` | `iterator` | Iterate all active frames. |
| `Dump` | `()` | -- | Print pool statistics. |

#### Convenience Functions (use default factory)

| Function | Signature | Description |
|----------|-----------|-------------|
| `Loolib.CreateFrame` | `(parent, frameTemplateOrType, resetFunc?)` | Create via default factory. |
| `Loolib.CreateFrameWithMixins` | `(parent, frameTemplateOrType, resetFunc?, ...)` | Create with mixins via default factory. |
| `Loolib.ReleaseFrame` | `(frame)` | Release to default factory. |
| `Loolib.CreateTemplateInfoCache` | `()` | Create a standalone template cache. |

#### Creating Custom Factories

```lua
local FrameFactoryModule = Loolib:GetModule("Factory.FrameFactory")
local myFactory = FrameFactoryModule.Create()
```

### Template Detection

FrameFactory automatically detects whether a string is a known frame type or an XML template:

- Known frame types: Frame, Button, CheckButton, EditBox, ScrollFrame, Slider, StatusBar, Cooldown, ColorSelect, GameTooltip, MessageFrame, Model, PlayerModel, DressUpModel, MovieFrame, SimpleHTML, Browser, ModelScene, OffScreenFrame
- Anything else is treated as a template name and looked up via `C_XMLUtil.GetTemplateInfo`

### Input Validation

All public methods validate their arguments:

- `frameTemplateOrType` must be a non-empty string
- `resetFunc` must be a function or nil
- `Release` rejects nil frames
- `CreateWithMixins` requires at least one mixin argument

Errors follow the format: `error("LoolibFactory: MethodName: message", 2)`

---

## WidgetBuilder

### Quick Start

```lua
local UI = Loolib.UI

local btn = UI.Widget(parentFrame)
    :Button()
    :Size(120, 30)
    :Point("CENTER")
    :Text("Click Me")
    :OnClick(function() print("clicked!") end)
    :Build()
```

### API Reference

#### Entry Points

```lua
local builder = Loolib.Widget(parent)
-- or
local builder = Loolib.CreateWidgetBuilder(parent)
-- or
local builder = Loolib.UI.Widget(parent)
```

#### Frame Type Methods

Each returns `self` for chaining.

| Method | Frame Type | Default Properties |
|--------|-----------|-------------------|
| `:Frame()` | Frame | -- |
| `:Button()` | Button | Normal/pushed/highlight textures |
| `:CheckButton()` | CheckButton | -- |
| `:EditBox(multiLine?)` | EditBox | autoFocus=false |
| `:Slider()` | Slider | orientation=HORIZONTAL, range 0-100, step 1 |
| `:StatusBar()` | StatusBar | range 0-100 |
| `:ScrollFrame()` | ScrollFrame | -- |
| `:TextureFrame()` | Frame | isTextureHolder=true |

#### Size & Position

| Method | Description |
|--------|-------------|
| `:Size(w, h?)` | Set size (h defaults to w) |
| `:Width(w)` | Set width only |
| `:Height(h)` | Set height only |
| `:Point(point, relativeTo?, relativePoint?, x?, y?)` | Add anchor. Supports shorthand: `:Point("TOPLEFT", 10, -10)` |
| `:AllPoints(inset?)` | Fill parent (SetAllPoints) with optional inset |
| `:Center(x?, y?)` | Center in parent |

#### Appearance

| Method | Description |
|--------|-------------|
| `:Backdrop(table_or_name)` | Set backdrop (auto-adds BackdropTemplate) |
| `:BackdropColor(r, g, b, a?)` | Set backdrop color |
| `:BackdropBorderColor(r, g, b, a?)` | Set border color |
| `:Alpha(a)` | Set alpha |
| `:FrameLevel(n)` | Set frame level |
| `:FrameStrata(s)` | Set frame strata |
| `:Shown(bool)` | Set visibility |
| `:Hidden()` | Start hidden |

#### Behavior

| Method | Description |
|--------|-------------|
| `:Movable(clampToScreen?)` | Make movable (clamp defaults true) |
| `:Resizable(minW, minH, maxW?, maxH?)` | Make resizable with grip |
| `:CloseButton(onClose?)` | Add close button |
| `:Title(text, fontObject?)` | Add title text |
| `:EnableMouse(bool?)` | Enable mouse |
| `:EnableKeyboard(bool?)` | Enable keyboard |

#### Widget Properties

| Method | Applies To | Description |
|--------|-----------|-------------|
| `:Text(text, fontObject?)` | Button, EditBox | Set display text |
| `:Textures(normal, pushed, highlight, disabled)` | Button | Set button textures |
| `:Range(min, max)` | Slider, StatusBar | Set value range |
| `:Step(n)` | Slider | Set step size |
| `:Orientation(s)` | Slider | HORIZONTAL or VERTICAL |
| `:Value(n)` | Slider, StatusBar | Set initial value |
| `:MaxLetters(n)` | EditBox | Max characters |
| `:Numeric(bool?)` | EditBox | Numbers only |
| `:Password(bool?)` | EditBox | Hide characters |
| `:Placeholder(text)` | EditBox | Placeholder text |
| `:Label(text)` | CheckButton | Label text |
| `:Checked(bool)` | CheckButton | Initial state |

#### Event Handlers

All handler methods validate that the argument is a function.

| Method | Script |
|--------|--------|
| `:OnClick(fn)` | OnClick |
| `:OnEnter(fn)` | OnEnter |
| `:OnLeave(fn)` | OnLeave |
| `:OnShow(fn)` | OnShow |
| `:OnHide(fn)` | OnHide |
| `:OnUpdate(fn)` | OnUpdate |
| `:OnValueChanged(fn)` | OnValueChanged |
| `:OnTextChanged(fn)` | OnTextChanged |
| `:OnEnterPressed(fn)` | OnEnterPressed |
| `:OnEscapePressed(fn)` | OnEscapePressed |
| `:OnMouseDown(fn)` | OnMouseDown |
| `:OnMouseUp(fn)` | OnMouseUp |
| `:OnMouseWheel(fn)` | OnMouseWheel (auto-enables) |
| `:OnDragStart(fn)` | OnDragStart |
| `:OnDragStop(fn)` | OnDragStop |

**Important**: Script handlers are applied via `HookScript`, not `SetScript`. This preserves any scripts set by XML templates (e.g. UIPanelButtonTemplate's OnClick). Handlers added through the builder will fire *after* template handlers.

#### Advanced

| Method | Description |
|--------|-------------|
| `:Mixin(...)` | Apply mixin tables on build |
| `:Template(name)` | Use XML template |
| `:Name(name)` | Set global frame name |
| `:Pooled(resetFunc?)` | Use FrameFactory pool |
| `:Theme(name)` | Use a specific theme |
| `:Set(key, value)` | Set arbitrary property |

#### Build

| Method | Description |
|--------|-------------|
| `:Build()` | Create and return the frame |
| `:BuildAndShow()` | Create, show, and return |

### Input Validation

All public methods validate arguments at call time:

- `parent` must not be nil
- `Size`/`Width`/`Height` require numbers
- `Point` requires a string anchor
- Script handlers require functions
- `Mixin` requires at least one table argument
- `Template`/`Name` require non-empty strings
- `Pooled` accepts function or nil
- `Set` requires a non-empty string key

Errors follow the format: `error("LoolibWidgetBuilder: MethodName: message", 2)`

### Known Limitations

1. **OVERLAY layer FontStrings** (FA-05): `Button()` and `CheckButton()` create their text FontStrings on the "OVERLAY" draw layer. If the widget is placed inside a ScrollFrame's scroll child, the text will not clip to the scroll region. Workaround: use a template-based button or manually adjust the draw layer after build.

2. **ScrollFrame returns single frame**: The `:ScrollFrame()` type selector builds a raw ScrollFrame. It does not automatically create a scroll child or scrollbar. For a complete scrollable panel, use the dedicated scroll frame APIs in Loolib or create the scroll child manually after build.

3. **HookScript stacking**: Because `Build()` uses `HookScript`, calling `Build()` multiple times on a pooled frame will stack handlers. Always release and re-acquire pooled frames rather than re-building.

### Dependencies

- `Loolib.CreateFromMixins` (Core.Mixin)
- `Loolib.FrameFactory` (Factory.FrameFactory)
- `Loolib.Mixin`, `Loolib.ReflectScriptHandlers` (Core.Mixin)
- `Loolib.AnchorUtil` (UI.AnchorUtil)
- `Loolib.FrameUtil` (UI.FrameUtil)
- `Loolib.ThemeManager` (Theme.Manager)
