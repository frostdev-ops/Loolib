# ThemeManager

Centralized theme management system for Loolib UI widgets. Provides theme registration, switching, and value retrieval with automatic fallback to the Default theme.

## Files

| File | Purpose |
|------|---------|
| `UI/Theme/ThemeManager.lua` | Core ThemeManager mixin and singleton |
| `UI/Theme/ThemeDefault.lua` | Default Blizzard-style theme + standard Backdrop definitions |
| `UI/Theme/ThemeDark.lua` | Dark theme variant |
| `UI/Theme/ThemeMinimal.lua` | Minimal/flat theme variant + Minimal Backdrop definitions |

## Dependencies

- `Core/Loolib.lua` - Namespace and module registration
- `Core/Mixin.lua` - `CreateFromMixins`
- `Core/TableUtil.lua` - `DeepCopy` (used to isolate registered theme data)

## Load Order

```
ThemeManager.lua -> ThemeDefault.lua -> ThemeDark.lua -> ThemeMinimal.lua
```

`ThemeDefault.lua` **must** load before Dark/Minimal because it defines `Loolib.Backdrop` (Dialog, Tooltip, Panel, Flat, TransparentBorder) which the variant themes reference.

## Quick Start

```lua
local Loolib = LibStub("Loolib")
local ThemeManager = Loolib.ThemeManager

-- Get a color (always returns a valid {r, g, b, a} table)
local color = ThemeManager:GetColor("accent")
frame:SetBackdropColor(color[1], color[2], color[3], color[4])

-- Switch theme
ThemeManager:SetActiveTheme("Dark")

-- Listen for theme changes
ThemeManager:RegisterThemeCallback(function(prev, new)
    -- re-style your frames here
end, myAddon)
```

## Access Patterns

### Via Singleton

```lua
local ThemeManager = Loolib.ThemeManager
ThemeManager:GetColor("accent")
```

### Via Module Lookup

```lua
local Theme = Loolib:GetModule("Theme.Manager")
Theme.GetColor("accent")  -- module-level convenience wrappers
```

### Via UI Namespace

```lua
Loolib.UI.ThemeManager:GetColor("accent")
```

## API Reference

### Theme Registration

#### `RegisterTheme(name, theme)`
Register a theme data table. The table is deep-copied to prevent external mutation.

- **name** `string` - Unique theme name (non-empty)
- **theme** `table` - Theme data table. Must contain at least `name` (string) and `colors` (table).
- **Errors** if name/theme are invalid or theme data fails validation.

#### `UnregisterTheme(name)`
Remove a registered theme. Cannot unregister the currently active theme.

- **name** `string` - Theme name to remove
- **Errors** if attempting to unregister the active theme.

#### `HasTheme(name) -> boolean`
Check if a theme is registered.

#### `GetThemeNames() -> table`
Return a sorted array of all registered theme names.

#### `GetTheme(name) -> table|nil`
Return the internal theme data table for a given name.

### Active Theme

#### `SetActiveTheme(name)`
Switch the active theme and fire `OnThemeChanged` callbacks.

- Protected against reentrancy: if a callback calls `SetActiveTheme`, it is silently ignored.
- **Errors** if the theme name is not registered.

#### `GetActiveTheme() -> table|nil`
Return the active theme data table.

#### `GetActiveThemeName() -> string|nil`
Return the active theme name.

### Value Retrieval

All getters follow the same pattern: try the active theme first, fall back to the "Default" theme, then return the explicit fallback parameter.

#### `GetValue(category, key, fallback) -> any`
Generic lookup by category and key.

#### `GetColor(colorName, fallback) -> table`
Return `{r, g, b, a}`. Guaranteed to return a valid color table. Ultimate fallback: `{1, 1, 1, 1}` (white).

#### `GetFont(fontName, fallback) -> string`
Return a font object name. Fallback: `"GameFontNormal"`.

#### `GetBackdrop(backdropName, fallback) -> table|nil`
Return a backdrop definition table.

#### `GetSpacing(spacingName, fallback) -> number`
Return a spacing value. Fallback: `8`.

#### `GetComponentConfig(componentName, fallback) -> table`
Return component configuration table. Fallback: `{}`.

#### `GetPath(path, fallback) -> any`
Dot-notation path lookup (e.g., `"colors.accent"`).

### Theme Application

#### `ApplyBackdropColors(frame, bgColor, borderColor)`
Apply theme colors to a frame's backdrop. Checks for `SetBackdropColor` and `SetBackdropBorderColor` capability before calling.

#### `ApplyFont(fontString, fontName)`
Apply a theme font to a FontString. Validates `SetFontObject` capability.

#### `ApplyTextColor(fontString, colorName)`
Apply a theme text color to a FontString. Validates `SetTextColor` capability.

#### `ApplyComponentStyle(frame, componentType)`
Apply full theme styling (size, backdrop, colors) to a frame based on component type name. Uses capability checks, not pcall.

### Callbacks

#### `RegisterThemeCallback(callback, owner)`
Register a function to be called when the active theme changes.

- **callback** `function(previousThemeName, newThemeName)` - The callback
- **owner** `any` (not nil) - Unique owner key for later unregistration

#### `UnregisterThemeCallback(owner)`
Remove a previously registered callback.

### Color Utilities

#### `ColorFromHex(hex, alpha) -> table`
Convert `"#FF5500"` or `"FF5500"` to `{r, g, b, a}`. Validates hex format.

#### `BlendColors(color1, color2, t) -> table`
Linear interpolation between two colors. `t` is clamped to `[0, 1]`.

#### `LightenColor(color, amount) -> table`
Blend toward white.

#### `DarkenColor(color, amount) -> table`
Blend toward black.

## Theme Data Structure

A theme table must contain at minimum `name` (string) and `colors` (table). Full structure:

```lua
{
    name = "MyTheme",                -- REQUIRED: string
    description = "Description",     -- optional: string
    colors = { ... },                -- REQUIRED: table of {r,g,b,a} arrays
    backdrops = { ... },             -- optional: table of backdrop definitions
    fonts = { ... },                 -- optional: table of font object names
    spacing = { ... },               -- optional: table of number values
    components = { ... },            -- optional: table of component config tables
    textures = { ... },              -- optional: table of texture paths
    animations = { ... },            -- optional: table of duration values
}
```

## Built-in Themes

| Name | Description |
|------|-------------|
| `Default` | Standard Blizzard-style appearance with dialog/tooltip backdrops |
| `Dark` | Darker, lower-contrast variant using flat backdrops |
| `Minimal` | Clean modern flat design with thin borders and increased spacing |

## Backdrop Definitions

Defined in `ThemeDefault.lua` and `ThemeMinimal.lua`, accessible via `Loolib.Backdrop`:

| Key | Source | Description |
|-----|--------|-------------|
| `Dialog` | ThemeDefault | 32x32 dialog border |
| `Tooltip` | ThemeDefault | 16x16 tooltip border |
| `Panel` | ThemeDefault | Dark dialog background |
| `Flat` | ThemeDefault | WHITE8x8, 1px edge |
| `TransparentBorder` | ThemeDefault | No bg, tooltip border |
| `Minimal` | ThemeMinimal | WHITE8x8, 1px edge |
| `MinimalThick` | ThemeMinimal | WHITE8x8, 2px edge |

## Gradients

Themes expose a `gradients` subtable alongside `colors`. Each entry defines a two-stop linear gradient:

```lua
gradients = {
    healthFG = { direction = "HORIZONTAL", from = {0.1, 0.7, 0.1, 1}, to = {0.6, 1.0, 0.4, 1} },
    ...
}
```

### ThemeManager:GetGradient(name, fallback)

Returns a normalized `{ direction, from, to }` table (with `a` defaulting to `1` for each stop), or `fallback` if missing. Invalid specs — wrong types, missing keys, unknown direction — fall through to `fallback`. Unknown directions are coerced to `"HORIZONTAL"`.

### ThemeManager:ApplyGradient(texture, name, fallback)

Call `TextureBase:SetGradient` on `texture` using the named gradient. The caller is responsible for ensuring the texture has a solid white backing (`SetColorTexture(1,1,1,1)` or a white texture file) so the gradient shows through unmultiplied. For StatusBars, prefer `StyleUtil.ApplyGradientBar` which handles this automatically.

```lua
local StyleUtil = LibStub("Loolib").StyleUtil
local bar = CreateFrame("StatusBar", nil, parent)
bar:SetSize(200, 20)
bar:SetMinMaxValues(0, 100)
bar:SetValue(75)
StyleUtil.ApplyGradientBar(bar, "healthFG")
```

Gradient definitions are re-applied automatically on theme switch via the existing theme-change callback mechanism — register with `RegisterThemeCallback` if your widget needs to re-call `ApplyGradient` on tint change.

### Built-in gradient keys

The Default / Dark / Minimal themes all define these keys; consumers can rely on them existing regardless of the active theme:

| Key | Use |
|---|---|
| `accentPanel` | Panel body background, vertical. |
| `accentHeader` | Header strip, horizontal. |
| `healthFG` / `healthBG` | Health bar foreground / background. |
| `manaFG` / `manaBG` | Mana/resource bar foreground / background. |
| `warningFG` | Warning/danger bar. |
| `goldAccent` | Gold highlight vertical gradient. |

## Globals Exported

| Global | Type | Description |
|--------|------|-------------|
| `Loolib.ThemeManager` | table | Singleton instance |
| `Loolib.ThemeManagerMixin` | table | Mixin for creating additional instances |
| `Loolib.Backdrop` | table | Standard backdrop definitions |
| `Loolib.UI.ThemeManager` | table | Alias to singleton |
| `Loolib.UI.Theme` | table | Module table with convenience wrappers |

## Safety Guarantees

- **No nil colors**: `GetColor` always returns a valid `{r, g, b, a}` table (ultimate fallback: white).
- **No infinite recursion**: `SetActiveTheme` uses a reentrancy guard; nested calls from callbacks are silently dropped.
- **No mutation leaks**: `RegisterTheme` deep-copies theme data so external references cannot corrupt registered themes.
- **Capability checks**: All `Apply*` methods verify method existence before calling WoW APIs.
- **Load-order validation**: Theme variant files assert that `Loolib.Backdrop` (with required keys) exists, catching incorrect TOC ordering.
- **Idempotent Init**: `ThemeManager:Init()` is safe to call multiple times; only the first call initializes state.
- **Safe callback iteration**: Theme-change callbacks are snapshot-iterated, so unregistering during dispatch is safe.
