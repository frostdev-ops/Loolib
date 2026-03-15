# ColorSwatch

Color picker widgets with preset palettes and recent colors tracking.

## Overview

The ColorSwatch module provides two widget types for color selection:

1. **LoolibColorSwatch** - Simple 24x24 clickable swatch that opens Blizzard's ColorPickerFrame
2. **LoolibColorSwatchWithPresets** - Full color picker with:
   - Main color swatch (32x32)
   - Hex color input field
   - 16 preset colors (8 common + 8 class colors)
   - Recent colors history (up to 5, saved to SavedVariables)
   - Optional alpha/opacity slider

Both widgets integrate with WoW's native ColorPickerFrame for advanced picking.

## Basic Usage

### Simple Color Swatch

```lua
local Loolib = LibStub("Loolib")

-- Create a basic swatch
local swatch = LoolibColorSwatch.Create(parentFrame, {
    r = 1.0,
    g = 0.0,
    b = 0.0,
    callback = function(r, g, b, a)
        myFrame:SetBackdropColor(r, g, b, a)
    end
})

swatch:SetPoint("TOPLEFT", 20, -20)
```

### Color Swatch with Presets

```lua
-- Create full picker with presets
local picker = LoolibColorSwatchWithPresets.Create(parentFrame, {
    r = 0.5,
    g = 0.5,
    b = 1.0,
    hasAlpha = true,
    recentColorsKey = "myAddon_colors",
    callback = function(r, g, b, a)
        print("Color changed to:", r, g, b, a)
    end
})

picker:SetPoint("TOPLEFT", 20, -20)
```

## API Reference

### LoolibColorSwatch

#### Factory Function

```lua
LoolibColorSwatch.Create(parent, options)
```

**Parameters:**
- `parent` (Frame) - Parent frame
- `options` (table, optional):
  - `r` (number) - Initial red value (0-1), default: 1.0
  - `g` (number) - Initial green value (0-1), default: 1.0
  - `b` (number) - Initial blue value (0-1), default: 1.0
  - `a` (number) - Initial alpha value (0-1), default: 1.0
  - `hasAlpha` (boolean) - Enable alpha support, default: false
  - `callback` (function) - Callback function(r, g, b, a)

**Returns:** ColorSwatch frame (24x24)

#### Methods

##### SetColor(r, g, b, a)
Set the current color.

```lua
swatch:SetColor(1.0, 0.0, 0.0, 1.0)  -- Red, fully opaque
```

##### GetColor()
Get the current color.

```lua
local r, g, b, a = swatch:GetColor()
```

**Returns:** r, g, b, a (numbers, 0-1)

##### SetHasAlpha(hasAlpha)
Enable or disable alpha channel support.

```lua
swatch:SetHasAlpha(true)
```

##### SetCallback(callback)
Set the color change callback function.

```lua
swatch:SetCallback(function(r, g, b, a)
    myFrame:SetBackdropColor(r, g, b, a)
end)
```

#### Events

##### OnColorChanged
Triggered when color changes (via picker or programmatically).

```lua
swatch:RegisterCallback("OnColorChanged", function(r, g, b, a)
    print("New color:", r, g, b, a)
end)
```

**Payload:** r, g, b, a (numbers, 0-1)

### LoolibColorSwatchWithPresets

Inherits all methods from `LoolibColorSwatch` plus:

#### Factory Function

```lua
LoolibColorSwatchWithPresets.Create(parent, options)
```

**Parameters:**
- `parent` (Frame) - Parent frame
- `options` (table, optional):
  - Same as LoolibColorSwatch, plus:
  - `recentColorsKey` (string) - SavedVariables key for recent colors

**Returns:** ColorSwatchWithPresets frame (280x130, or 280x160 with alpha)

#### Additional Methods

##### SetRecentColorsKey(key)
Set the SavedVariables key for storing recent colors.

```lua
picker:SetRecentColorsKey("myAddon_backgroundColors")
```

**Important:** Add `LoolibRecentColors` to your TOC's `## SavedVariables` line:
```
## SavedVariables: MyAddonDB, LoolibRecentColors
```

##### ApplyColor(r, g, b, a)
Apply a color programmatically (updates display, triggers callback, adds to recent).

```lua
picker:ApplyColor(1.0, 0.5, 0.0, 1.0)  -- Orange
```

##### ApplyHexColor(hex)
Apply a color from hex string (updates display, triggers callback, adds to recent).

```lua
picker:ApplyHexColor("FF6600")  -- Orange
picker:ApplyHexColor("#FF6600") -- Also works with #
```

**Note:** Invalid hex strings are ignored and display reverts to current color.

## Widget Layout

### LoolibColorSwatch
```
┌──────┐
│      │  24x24 swatch
│      │  Click to open ColorPickerFrame
└──────┘
```

### LoolibColorSwatchWithPresets
```
┌────────────────────────────────────────────┐
│ ┌──────┐ Hex: [FF6600]        Opacity: 80% │  Main swatch + hex input + alpha slider
│ │      │                                     │
│ └──────┘                                     │
│                                              │
│ Presets:                                     │
│ ▪▪▪▪▪▪▪▪  (8 common colors)                 │  Preset palette
│ ▪▪▪▪▪▪▪▪  (8 class colors)                  │
│                                              │
│ Recent:                                      │
│ ▪▪▪▪▪     (Last 5 used colors)              │  Recent colors
└────────────────────────────────────────────┘
280x130 (without alpha) or 280x160 (with alpha)
```

## Color Presets

### Common Colors
- Red (1.0, 0.0, 0.0)
- Green (0.0, 1.0, 0.0)
- Blue (0.0, 0.0, 1.0)
- Yellow (1.0, 1.0, 0.0)
- Orange (1.0, 0.5, 0.0)
- Purple (0.5, 0.0, 1.0)
- White (1.0, 1.0, 1.0)
- Gray (0.5, 0.5, 0.5)

### Class Colors
- Warrior (0.78, 0.61, 0.43)
- Paladin (0.96, 0.55, 0.73)
- Hunter (0.67, 0.83, 0.45)
- Rogue (1.00, 0.96, 0.41)
- Priest (1.00, 1.00, 1.00)
- Death Knight (0.77, 0.12, 0.23)
- Shaman (0.00, 0.44, 0.87)
- Mage (0.41, 0.80, 0.94)
- Warlock (0.58, 0.51, 0.79)
- Monk (0.00, 1.00, 0.59)
- Druid (1.00, 0.49, 0.04)
- Demon Hunter (0.64, 0.19, 0.79)
- Evoker (0.20, 0.58, 0.50)

## Recent Colors

Recent colors are automatically tracked when using `LoolibColorSwatchWithPresets`. Up to 5 recent colors are stored per `recentColorsKey`.

### SavedVariables Setup

1. Add to your TOC file:
```
## SavedVariables: MyAddonDB, LoolibRecentColors
```

2. Set the key when creating the picker:
```lua
local picker = LoolibColorSwatchWithPresets.Create(parent, {
    recentColorsKey = "myAddon_textColors",
})
```

3. Recent colors are automatically saved on PLAYER_LOGOUT and loaded on next login.

### Manual Control

```lua
-- Load recent colors
picker:LoadRecentColors()

-- Save recent colors
picker:SaveRecentColors()

-- Add color to recent
picker:AddToRecentColors(1.0, 0.0, 0.0)  -- Red
```

## Integration Examples

### With SavedVariables

```lua
-- In your addon's DB initialization
local defaults = {
    profile = {
        colors = {
            background = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 },
            text = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        }
    }
}

-- Create picker for background color
local bgPicker = LoolibColorSwatchWithPresets.Create(settingsFrame, {
    r = db.profile.colors.background.r,
    g = db.profile.colors.background.g,
    b = db.profile.colors.background.b,
    a = db.profile.colors.background.a,
    hasAlpha = true,
    recentColorsKey = "myAddon_background",
    callback = function(r, g, b, a)
        db.profile.colors.background.r = r
        db.profile.colors.background.g = g
        db.profile.colors.background.b = b
        db.profile.colors.background.a = a
        myFrame:SetBackdropColor(r, g, b, a)
    end
})
```

### With Config System

```lua
-- In your config options table
local options = {
    type = "group",
    name = "My Addon",
    args = {
        colors = {
            type = "group",
            name = "Colors",
            args = {
                background = {
                    type = "color",
                    name = "Background Color",
                    desc = "Choose a background color",
                    hasAlpha = true,
                    get = function()
                        return db.bgR, db.bgG, db.bgB, db.bgA
                    end,
                    set = function(info, r, g, b, a)
                        db.bgR, db.bgG, db.bgB, db.bgA = r, g, b, a
                        myFrame:SetBackdropColor(r, g, b, a)
                    end,
                },
            },
        },
    },
}
```

### Building a Settings Panel

```lua
local function CreateColorSettingsPanel(parent, db)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(320, 450)

    local yOffset = -10

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, yOffset)
    title:SetText("Color Settings")
    yOffset = yOffset - 40

    -- Background color
    local bgLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgLabel:SetPoint("TOPLEFT", 10, yOffset)
    bgLabel:SetText("Background Color:")
    yOffset = yOffset - 20

    local bgPicker = LoolibColorSwatchWithPresets.Create(panel, {
        r = db.bgR, g = db.bgG, b = db.bgB, a = db.bgA,
        hasAlpha = true,
        recentColorsKey = "myAddon_bg",
        callback = function(r, g, b, a)
            db.bgR, db.bgG, db.bgB, db.bgA = r, g, b, a
        end
    })
    bgPicker:SetPoint("TOPLEFT", 10, yOffset)
    yOffset = yOffset - 170

    -- Text color
    local textLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textLabel:SetPoint("TOPLEFT", 10, yOffset)
    textLabel:SetText("Text Color:")
    yOffset = yOffset - 20

    local textPicker = LoolibColorSwatchWithPresets.Create(panel, {
        r = db.textR, g = db.textG, b = db.textB,
        hasAlpha = false,
        recentColorsKey = "myAddon_text",
        callback = function(r, g, b, a)
            db.textR, db.textG, db.textB = r, g, b
        end
    })
    textPicker:SetPoint("TOPLEFT", 10, yOffset)

    return panel
end
```

## Implementation Notes

### Blizzard ColorPickerFrame Integration

Both widgets use WoW's native `ColorPickerFrame` for advanced color picking. The picker opens when clicking the swatch and supports:
- HSV color wheel
- RGB sliders
- Opacity slider (if `hasAlpha = true`)
- Accept/Cancel buttons

**API Compatibility (TP-04):** `OpenColorPicker()` detects the available API at runtime:
1. Prefers `ColorPickerFrame:SetupColorPickerAndShow(info)` (WoW 10.0+ / modern Retail API)
2. Falls back to the classic `OpenColorPicker(info)` global if the modern method is absent
3. Logs an error via `Loolib:Error()` if neither API exists

### Color Validation

`SetColor()` coerces inputs to numbers and clamps values to the 0-1 range, preventing arithmetic errors from invalid or out-of-range inputs.

### Color Format

All color values use WoW's standard format:
- RGB values: 0.0 to 1.0 (not 0-255)
- Alpha: 0.0 (transparent) to 1.0 (opaque)
- Hex strings: 6-digit hexadecimal (e.g., "FF6600")

### Performance

- Recent colors use minimal storage (max 5 colors x 3 values = 15 numbers)
- Preset swatches are created once on initialization
- Color changes trigger callbacks only when values actually change
- SavedVariables writes happen only on PLAYER_LOGOUT

### Accessibility

- Hover tooltips on all swatches show color name and hex value
- Keyboard support via EditBox for hex input (Enter to apply, Escape to cancel)
- Visual feedback on hover (highlight texture)
- Clear borders for visibility

## See Also

- [Config.md](Config.md) - Using color pickers in config options
- [SavedVariables.md](SavedVariables.md) - Data persistence
- [WindowUtil.md](WindowUtil.md) - Positioning and layout utilities
