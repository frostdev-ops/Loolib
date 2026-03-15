# Appearance Module

The Appearance module provides skin management for UI frames using BackdropTemplate. It handles skin registration, switching, persistence, and automatic propagation to registered frames.

## Overview

### What It Does

The Appearance module manages visual skins for BackdropTemplate frames:
- Register and switch between named skins (background texture, background color, border texture, border color)
- Automatically propagate skin changes to all registered frames
- Persist skin data via SavedVariables
- Generate AceConfig-style options tables for settings UI integration
- Extend available textures at runtime

### Common Use Cases

- **Addon theming**: Let users customize the look of all addon windows at once
- **Skin presets**: Ship multiple built-in skins and let users create their own
- **Settings panels**: Drop `GenerateOptionsTable()` into an AceConfig dialog
- **Frame registration**: Register frames once, and all future skin changes propagate automatically

### Key Features

- **Callback events**: `OnSkinChanged`, `OnSkinSaved`, `OnSkinDeleted`
- **Weak frame tracking**: Registered frames use weak references -- destroyed frames are automatically cleaned up without explicit unregistration
- **Frame validation**: Every frame access is guarded via `pcall(GetObjectType)` to safely handle dead/forbidden frames
- **Input validation**: All public setters validate argument types; color values are clamped to [0,1]
- **SavedVariables safety**: `Init(savedData)` validates skin structure and color types before applying; corrupt data falls back to defaults
- **Singleton + factory**: Use the global singleton via `Loolib.AppearanceManager` or create isolated instances via `Loolib.CreateAppearance(savedData)`

## Quick Start

```lua
local Loolib = LibStub("Loolib")

-- Use the global singleton
local appearance = Loolib.AppearanceManager

-- Or create a private instance (e.g., per-addon)
local appearance = Loolib.CreateAppearance(myAddonSavedVars.appearance)

-- Register a frame for automatic skin updates
appearance:RegisterFrame(myFrame)

-- Change background color (values clamped to 0-1)
appearance:SetBackgroundColor(0.2, 0.2, 0.2, 0.85)

-- Switch to a different skin
appearance:SetCurrentSkin("Dark")

-- Save current settings as a new preset
appearance:SaveSkin("My Custom Skin")

-- Persist to SavedVariables on logout
myAddonSavedVars.appearance = appearance:GetSaveData()
```

## API Reference

### Initialization

#### `AppearanceMixin:Init(savedData)`
Initialize (or re-initialize) the appearance manager.

| Parameter | Type | Description |
|-----------|------|-------------|
| `savedData` | `table\|nil` | Previously saved data from `GetSaveData()`. If nil or invalid, defaults are used. |

Validates all fields in `savedData`: skins must be properly structured tables with numeric color fields. Invalid skins are silently discarded. If no valid skins remain, the Default skin is created.

### Skin Access

#### `AppearanceMixin:GetCurrentSkin()` -> `table`
Returns the current skin data table.

#### `AppearanceMixin:GetCurrentSkinName()` -> `string`
Returns the name of the current active skin.

#### `AppearanceMixin:SetCurrentSkin(skinName)` -> `boolean`
Switch to a different skin. Updates all registered frames and fires `OnSkinChanged`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `skinName` | `string` | Must be a non-empty string matching a registered skin name. |

**Errors** if `skinName` is not a string. Returns `false` if the skin is not found.

#### `AppearanceMixin:GetSkinList()` -> `table`
Returns a sorted array of all registered skin names.

#### `AppearanceMixin:GetSkin(skinName)` -> `table|nil`
Returns the skin data for a specific name, or nil.

### Skin Management

#### `AppearanceMixin:SaveSkin(name)` -> `boolean`
Deep-copies the current skin under `name`. Fires `OnSkinSaved`.

**Errors** if `name` is not a non-empty string.

#### `AppearanceMixin:LoadSkin(name)` -> `boolean`
Alias for `SetCurrentSkin(name)`.

#### `AppearanceMixin:DeleteSkin(name)` -> `boolean`
Removes a skin. Cannot delete "Default" or the currently active skin.

**Errors** if `name` is not a non-empty string. Returns `false` on constraint violations.

#### `AppearanceMixin:ResetSkins()`
Wipes all skins and restores the Default skin. Fires `OnSkinChanged`.

### Background Settings

#### `AppearanceMixin:GetBackgroundTexture()` -> `string`
#### `AppearanceMixin:SetBackgroundTexture(texture)`
Get/set the background texture path. **Errors** if texture is not a string.

#### `AppearanceMixin:GetBackgroundColor()` -> `r, g, b, a`
#### `AppearanceMixin:SetBackgroundColor(r, g, b, a)`
Get/set background color. Components are clamped to [0,1]. Nil components retain existing values.

### Border Settings

#### `AppearanceMixin:GetBorderTexture()` -> `string`
#### `AppearanceMixin:SetBorderTexture(texture)`
Get/set the border texture path. **Errors** if texture is not a string.

#### `AppearanceMixin:GetBorderColor()` -> `r, g, b, a`
#### `AppearanceMixin:SetBorderColor(r, g, b, a)`
Get/set border color. Components are clamped to [0,1]. Nil components retain existing values.

### Frame Application

#### `AppearanceMixin:ApplyToFrame(frame)`
Apply the current skin to a single frame. Validates frame liveness via `pcall`. Gracefully handles nil textures (clears backdrop instead of erroring).

#### `AppearanceMixin:RegisterFrame(frame)`
Register a frame for automatic skin updates. The frame receives the current skin immediately. **Errors** if frame is not a valid frame object.

Registered frames are held via weak references (`__mode = "k"`), so destroyed frames are automatically collected.

#### `AppearanceMixin:UnregisterFrame(frame)`
Remove a frame from automatic updates.

#### `AppearanceMixin:UpdateRegisteredFrames()`
Re-apply the current skin to all registered frames. Stale (dead) frames are pruned automatically.

### Serialization

#### `AppearanceMixin:GetSaveData()` -> `table`
Returns a deep copy suitable for SavedVariables: `{ skins = {...}, currentSkin = "name" }`.

### Options

#### `AppearanceMixin:GenerateOptionsTable()` -> `table`
Returns an AceConfig-compatible options group with dropdowns for skin selection, texture selection, color pickers, and skin management buttons.

### Texture Lists

#### `AppearanceMixin:GetAvailableBackgroundTextures()` -> `table`
#### `AppearanceMixin:GetAvailableBorderTextures()` -> `table`
Return copies of the available texture lists.

#### `AppearanceMixin:AddBackgroundTexture(texture)`
#### `AppearanceMixin:AddBorderTexture(texture)`
Add a custom texture path. **Errors** if texture is not a string. Duplicates are ignored.

### Factory

#### `CreateAppearance(savedData)` -> `table`
Create an independent Appearance instance. Available as `Loolib.CreateAppearance`.

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `OnSkinChanged` | `newSkinName, previousSkinName` | Fired after skin switch completes |
| `OnSkinSaved` | `skinName` | Fired after a skin is saved |
| `OnSkinDeleted` | `skinName` | Fired after a skin is deleted |

## Skin Data Structure

```lua
{
    name = "My Skin",
    background = {
        texture = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        color = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 },
    },
    border = {
        texture = "Interface\\DialogFrame\\UI-DialogBox-Border",
        color = { r = 0.6, g = 0.6, b = 0.6, a = 1 },
    },
}
```

All color fields (`r`, `g`, `b`, `a`) must be numbers in [0,1]. The `a` field defaults to 1 if omitted. Texture fields must be strings.

## Global Access Points

| Path | Type | Description |
|------|------|-------------|
| `Loolib.AppearanceManager` | instance | Global singleton |
| `Loolib.AppearanceMixin` | table | Mixin for `CreateFromMixins` |
| `Loolib.CreateAppearance` | function | Factory function |
| `Loolib.UI.Appearance` | module | Full module table (Mixin, Create, Instance, convenience wrappers) |

## Hardening Notes

The following safety measures are applied (see source comments tagged `FIX(AP-XX)`):

- **AP-01**: Frame tracking uses weak-keyed tables (`__mode = "k"`) and `pcall`-guarded frame liveness probing. Stale frames are collected in a separate pass to avoid modifying the table during iteration.
- **AP-02/AP-03**: `ApplyToFrame` guards `SetBackdropColor`/`SetBackdropBorderColor` calls -- they are only called when the corresponding texture is present. If both textures are nil, `SetBackdrop(nil)` is called and the method returns immediately.
- **AP-04**: Singleton creation at file-load time is safe because `assert` guards at the file top halt execution if any dependency is missing.
- **AP-05**: `Init(savedData)` validates every field: `savedData` must be a table, each skin must pass `ValidateSkinStructure` (checks table structure, color field types, texture field types), accepted skins have their colors clamped to [0,1] via `SanitizeSkinColors`, and malformed skins are discarded rather than partially repaired.
