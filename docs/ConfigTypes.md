# Loolib ConfigTypes Reference

Complete reference for all option types in the Loolib Configuration system.

## Table of Contents

1. [Overview](#overview)
2. [Type Categories](#type-categories)
3. [Container Type: group](#container-type-group)
4. [Value Types](#value-types)
   - [toggle](#toggle)
   - [input](#input)
   - [range](#range)
   - [select](#select)
   - [multiselect](#multiselect)
   - [color](#color)
   - [keybinding](#keybinding)
5. [Action Type: execute](#action-type-execute)
6. [Display Types](#display-types)
   - [header](#header)
   - [description](#description)
7. [Media Types](#media-types)
   - [texture](#texture)
   - [font](#font)
8. [Common Properties](#common-properties)
9. [Property Value Types](#property-value-types)
10. [Type Validation](#type-validation)
11. [Constants](#constants)

---

## Overview

The `ConfigTypes` module defines the schema for all option types supported by the Loolib Configuration system. It provides:

- Type specifications with required and optional properties
- Default values for type-specific properties
- Validation functions
- Utility functions for type checking

### Accessing ConfigTypes

```lua
local Loolib = LibStub("Loolib")
local ConfigTypes = Loolib:GetModule("ConfigTypes")

-- Get all types
local types = ConfigTypes:GetAllTypes()

-- Check if type is container
local isContainer = ConfigTypes:IsContainer("group")

-- Validate an option
local valid, error = ConfigTypes:ValidateOption("range", optionDef)
```

---

## Type Categories

Options are organized into four categories:

### 1. Container Type
- **group** - Contains other options

### 2. Value Types (support get/set)
- **toggle** - Boolean checkbox
- **input** - Text input
- **range** - Numeric slider
- **select** - Single selection dropdown
- **multiselect** - Multiple selection checkboxes
- **color** - Color picker
- **keybinding** - Key binding capture

### 3. Action Type
- **execute** - Button that triggers a function

### 4. Display Types (no values)
- **header** - Section divider
- **description** - Static text

### 5. Media Types
- **texture** - Texture display/selector
- **font** - Font selector

---

## Container Type: group

A container that holds other options. The root of every options table must be a group.

### Definition

```lua
{
    type = "group",
    name = "Group Name",
    desc = "Group description",
    args = {
        -- Child options here
    },
    childGroups = "tree",  -- How to display child groups
    inline = false,        -- Display inline within parent
}
```

### Type-Specific Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `args` | table | (required) | Nested options. Keys become option identifiers |
| `childGroups` | string | "tree" | Display mode: "tree", "tab", or "select" |
| `inline` | boolean | false | Display inline instead of separate panel |

### Child Group Display Modes

#### "tree" (Default)
Displays child groups in a left sidebar tree navigation.

```
+-------+-------------------+
| Root  | Content Area      |
|  +Gen |                   |
|  +App | Options display   |
|  +Adv | here              |
+-------+-------------------+
```

#### "tab"
Displays child groups as tabs along the top.

```
+---------------------------+
| [Gen] [App] [Adv]         |
+---------------------------+
| Content Area              |
|                           |
| Options display here      |
+---------------------------+
```

#### "select"
Displays child groups as a dropdown selector.

### Inline Groups

When `inline = true`, the group displays as a bordered section within its parent:

```lua
colors = {
    type = "group",
    name = "Colors",
    inline = true,
    args = {
        background = { type = "color", name = "Background" },
        text = { type = "color", name = "Text" },
    },
}
```

Renders as:
```
+---------------------------+
| Colors                    |
| +-----------------------+ |
| | Background: [##]      | |
| | Text: [##]            | |
| +-----------------------+ |
+---------------------------+
```

### Examples

```lua
-- Root group with tree navigation
local options = {
    type = "group",
    name = "My Addon",
    childGroups = "tree",
    args = {
        general = {
            type = "group",
            name = "General",
            order = 1,
            args = { ... },
        },
        appearance = {
            type = "group",
            name = "Appearance",
            order = 2,
            args = { ... },
        },
    },
}

-- Tab-based navigation
local options = {
    type = "group",
    name = "My Addon",
    childGroups = "tab",
    args = { ... },
}

-- Group with inline sub-groups
local appearanceGroup = {
    type = "group",
    name = "Appearance",
    args = {
        colors = {
            type = "group",
            name = "Colors",
            inline = true,
            args = { ... },
        },
        fonts = {
            type = "group",
            name = "Fonts",
            inline = true,
            args = { ... },
        },
    },
}
```

---

## Value Types

These types store and retrieve configuration values via `get` and `set`.

### toggle

A boolean checkbox for on/off settings.

#### Definition

```lua
{
    type = "toggle",
    name = "Enable Feature",
    desc = "Turn this feature on or off",
    get = function(info) return db.enabled end,
    set = function(info, value) db.enabled = value end,
    tristate = false,
}
```

#### Type-Specific Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `tristate` | boolean | false | Allow nil as third state |

#### Tristate Behavior

Normal toggle cycles: `true -> false -> true`

Tristate toggle cycles: `true -> nil -> false -> true`

The nil state typically represents "use default" or "inherit from parent".

#### Widget Rendering

```
[x] Enable Feature     <- Checked (true)
[ ] Enable Feature     <- Unchecked (false)
[-] Enable Feature     <- Tristate nil
```

#### CLI Syntax

```
/addon enabled true
/addon enabled false
/addon enabled yes
/addon enabled no
/addon enabled 1
/addon enabled 0
/addon enabled on
/addon enabled off
/addon enabled nil      -- Only for tristate
/addon enabled default  -- Only for tristate
```

---

### input

A text input field for string values.

#### Definition

```lua
{
    type = "input",
    name = "Welcome Message",
    desc = "Message displayed on login",
    get = function(info) return db.message end,
    set = function(info, value) db.message = value end,
    multiline = false,
    pattern = nil,
    usage = nil,
}
```

#### Type-Specific Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `multiline` | boolean | false | Multi-line text box |
| `pattern` | string | nil | Lua pattern for validation |
| `usage` | string | nil | Usage hint shown on error |

#### Single-Line vs Multi-Line

```lua
-- Single line (default)
{
    type = "input",
    name = "Character Name",
    multiline = false,  -- Optional, this is default
}

-- Multi-line (4 lines by default)
{
    type = "input",
    name = "Notes",
    multiline = true,
    width = "full",
}
```

#### Pattern Validation

The `pattern` property uses Lua pattern matching:

```lua
{
    type = "input",
    name = "Email",
    pattern = "^[%w.]+@[%w.]+%.%w+$",
    usage = "Enter a valid email address (e.g., user@example.com)",
}

{
    type = "input",
    name = "Player Name",
    pattern = "^[A-Za-z][A-Za-z0-9]*$",
    usage = "Name must start with a letter and contain only letters/numbers",
}
```

#### Widget Rendering

Single-line:
```
+---------------------------+
| [                       ] |
+---------------------------+
```

Multi-line:
```
+---------------------------+
| [                       ] |
| [                       ] |
| [                       ] |
| [                       ] |
+---------------------------+
```

---

### range

A slider for numeric values within a range.

#### Definition

```lua
{
    type = "range",
    name = "Volume",
    desc = "Set the audio volume",
    min = 0,
    max = 100,
    softMin = 10,
    softMax = 90,
    step = 1,
    bigStep = 10,
    isPercent = false,
    get = function(info) return db.volume end,
    set = function(info, value) db.volume = value end,
}
```

#### Type-Specific Properties

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `min` | number | **Yes** | - | Minimum allowed value |
| `max` | number | **Yes** | - | Maximum allowed value |
| `softMin` | number | No | nil | Soft minimum (slider limit, input can exceed) |
| `softMax` | number | No | nil | Soft maximum (slider limit, input can exceed) |
| `step` | number | No | 0 | Step increment (0 = continuous) |
| `bigStep` | number | No | nil | Ctrl+click step increment |
| `isPercent` | boolean | No | false | Display as percentage |

#### Soft Min/Max

Soft limits constrain the slider but allow manual input to exceed:

```lua
{
    type = "range",
    name = "Font Size",
    min = 1,        -- Absolute minimum
    max = 100,      -- Absolute maximum
    softMin = 8,    -- Slider starts here
    softMax = 24,   -- Slider ends here
    step = 1,
}
```

Users can drag slider between 8-24, but manually type 1-100.

#### Step Values

```lua
-- Continuous (smooth)
step = 0,

-- Integer steps
step = 1,

-- Decimal steps
step = 0.1,
step = 0.05,

-- Ctrl+click for larger steps
step = 1,
bigStep = 10,
```

#### Percentage Display

When `isPercent = true`, values 0-1 display as 0%-100%:

```lua
{
    type = "range",
    name = "Opacity",
    min = 0,
    max = 1,
    step = 0.01,
    isPercent = true,
    get = function() return db.opacity end,  -- Returns 0.75
    set = function(_, v) db.opacity = v end, -- Receives 0.75
}
-- Displays as "75%"
```

#### Widget Rendering

```
Volume: [====|=========] 35
```

---

### select

A dropdown or radio button selection from predefined values.

#### Definition

```lua
{
    type = "select",
    name = "Font",
    desc = "Select display font",
    values = {
        arial = "Arial",
        friz = "Friz Quadrata",
        morpheus = "Morpheus",
    },
    sorting = {"arial", "friz", "morpheus"},
    style = "dropdown",
    get = function(info) return db.font end,
    set = function(info, value) db.font = value end,
}
```

#### Type-Specific Properties

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `values` | table/function | **Yes** | - | `{key = "Label"}` or function returning table |
| `style` | string | No | "dropdown" | "dropdown" or "radio" |
| `sorting` | table/function | No | nil | Custom sort order: `{key1, key2, ...}` |

#### Values Table

Static values:
```lua
values = {
    low = "Low",
    medium = "Medium",
    high = "High",
}
```

Dynamic values:
```lua
values = function(info)
    local items = {}
    for _, item in pairs(GetGameItems()) do
        items[item.id] = item.name
    end
    return items
end,
```

#### Sorting

By default, values sort alphabetically by key. Use `sorting` to customize:

```lua
values = {
    high = "High Priority",
    medium = "Medium Priority",
    low = "Low Priority",
},
sorting = {"high", "medium", "low"},  -- Explicit order
```

Dynamic sorting:
```lua
sorting = function(info)
    return {"newest", "popular", "alphabetical"}
end,
```

#### Style Options

**dropdown** (default):
```
Font: [Arial           v]
```

**radio**:
```
Font:
  ( ) Arial
  (*) Friz Quadrata
  ( ) Morpheus
```

#### Get/Set

```lua
get = function(info)
    return db.selectedKey  -- Returns the KEY, not label
end,

set = function(info, value)
    db.selectedKey = value  -- Receives the KEY
end,
```

---

### multiselect

Multiple checkbox selection from predefined values.

#### Definition

```lua
{
    type = "multiselect",
    name = "Enabled Modules",
    desc = "Select which modules to enable",
    values = {
        combat = "Combat Tracker",
        inventory = "Inventory Manager",
        map = "Map Enhancements",
    },
    tristate = false,
    get = function(info, key) return db.modules[key] end,
    set = function(info, key, value) db.modules[key] = value end,
}
```

#### Type-Specific Properties

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `values` | table/function | **Yes** | - | `{key = "Label"}` or function returning table |
| `tristate` | boolean | No | false | Allow nil as third state per item |

#### Get/Set Signature

**Important:** Unlike other types, multiselect passes `key` to get/set:

```lua
-- Get receives key
get = function(info, key)
    return db.modules[key]  -- Return boolean for this key
end,

-- Set receives key and value
set = function(info, key, value)
    db.modules[key] = value  -- value is boolean
end,
```

#### Storage Patterns

```lua
-- Table storage
db.modules = {
    combat = true,
    inventory = false,
    map = true,
}

get = function(_, key) return db.modules[key] end,
set = function(_, key, val) db.modules[key] = val end,

-- Set storage (enabled items only)
db.enabledModules = { combat = true, map = true }

get = function(_, key) return db.enabledModules[key] or false end,
set = function(_, key, val)
    if val then
        db.enabledModules[key] = true
    else
        db.enabledModules[key] = nil
    end
end,
```

#### Widget Rendering

```
Enabled Modules:
[x] Combat Tracker    [x] Map Enhancements
[ ] Inventory Manager
```

---

### color

A color picker for RGBA values.

#### Definition

```lua
{
    type = "color",
    name = "Background Color",
    desc = "Select background color",
    hasAlpha = true,
    get = function(info)
        return db.bgR, db.bgG, db.bgB, db.bgA
    end,
    set = function(info, r, g, b, a)
        db.bgR, db.bgG, db.bgB, db.bgA = r, g, b, a
    end,
}
```

#### Type-Specific Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `hasAlpha` | boolean | false | Show alpha (transparency) slider |

#### Get/Set Signature

**Get** returns 3 or 4 values (0-1 range):
```lua
get = function(info)
    return r, g, b     -- RGB only
    -- or
    return r, g, b, a  -- RGBA
end,
```

**Set** receives 4 parameters:
```lua
set = function(info, r, g, b, a)
    -- r, g, b, a are all 0-1 range
    -- a is always provided (1.0 if hasAlpha = false)
end,
```

#### Storage Patterns

```lua
-- Separate values
db = { r = 1, g = 0.5, b = 0, a = 0.8 }

get = function() return db.r, db.g, db.b, db.a end,
set = function(_, r, g, b, a)
    db.r, db.g, db.b, db.a = r, g, b, a
end,

-- Table storage
db.color = { r = 1, g = 0.5, b = 0, a = 0.8 }

get = function()
    local c = db.color
    return c.r, c.g, c.b, c.a
end,
set = function(_, r, g, b, a)
    db.color = { r = r, g = g, b = b, a = a }
end,

-- Array storage
db.color = { 1, 0.5, 0, 0.8 }

get = function()
    return unpack(db.color)
end,
set = function(_, r, g, b, a)
    db.color = { r, g, b, a }
end,
```

#### Widget Rendering

Swatch button that opens WoW's color picker:
```
Background Color: [##]  <- Colored swatch
```

---

### keybinding

A key binding capture button.

#### Definition

```lua
{
    type = "keybinding",
    name = "Toggle Hotkey",
    desc = "Press a key to set the binding",
    get = function(info) return db.toggleKey end,
    set = function(info, value) db.toggleKey = value end,
}
```

#### Get/Set Signature

Values are strings like:
- `"A"` - Simple key
- `"CTRL-A"` - With modifier
- `"CTRL-SHIFT-A"` - Multiple modifiers
- `"F12"` - Function key
- `"NUMPAD1"` - Numpad

```lua
get = function(info)
    return db.keybind or ""  -- Return string
end,

set = function(info, value)
    db.keybind = value
    -- Optionally set actual WoW binding
    SetBinding(value, "MYADDON_ACTION")
end,
```

#### Widget Rendering

```
Toggle Hotkey: [CTRL-SHIFT-A]  <- Button
```

Click to capture, press key combination, press Escape to cancel.

---

## Action Type: execute

A button that triggers an action when clicked.

### Definition

```lua
{
    type = "execute",
    name = "Reset Settings",
    desc = "Reset all settings to defaults",
    func = function(info)
        ResetDefaults()
    end,
    confirm = true,
    confirmText = "Are you sure?",
    image = "Interface\\Icons\\INV_Misc_QuestionMark",
    imageWidth = 24,
    imageHeight = 24,
}
```

### Type-Specific Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `func` | function | **Yes** | Click handler: `func(info)` |
| `image` | string | No | Icon texture path |
| `imageCoords` | table | No | Icon crop: `{left, right, top, bottom}` |
| `imageWidth` | number | No | Icon width in pixels |
| `imageHeight` | number | No | Icon height in pixels |

### Function Signature

```lua
func = function(info)
    -- info contains path, handler, etc.
    DoSomething()
end,
```

### With Handler

```lua
handler = MyAddon,

execute = {
    type = "execute",
    name = "Reload",
    func = "Reload",  -- Calls MyAddon:Reload(info)
},
```

### Confirmation

```lua
{
    type = "execute",
    name = "Delete All",
    confirm = true,  -- Uses default confirmation
},

{
    type = "execute",
    name = "Delete All",
    confirm = true,
    confirmText = "This will delete everything. Continue?",
},

{
    type = "execute",
    name = "Delete All",
    confirm = function(info)
        return db.itemCount > 0  -- Only confirm if items exist
    end,
    confirmText = function(info)
        return string.format("Delete %d items?", db.itemCount)
    end,
},
```

### Widget Rendering

```
[Reset Settings]  <- Button
```

With image:
```
[Icon] [Reset Settings]
```

---

## Display Types

These types display information but don't store values.

### header

A section divider with text.

#### Definition

```lua
{
    type = "header",
    name = "Display Options",
    order = 10,
}
```

#### Properties

Only uses common properties:
- `name` - Header text
- `order` - Sort order
- `hidden` - Visibility control

#### Widget Rendering

```
--- Display Options ---
______________________
```

---

### description

Static text display for information or help.

#### Definition

```lua
{
    type = "description",
    name = "This is explanatory text that appears in the config panel.",
    fontSize = "medium",
    image = "Interface\\Icons\\INV_Misc_QuestionMark",
    imageCoords = {0, 1, 0, 1},
    imageWidth = 32,
    imageHeight = 32,
}
```

#### Type-Specific Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fontSize` | string | "medium" | "small", "medium", or "large" |
| `image` | string | nil | Image texture path |
| `imageCoords` | table | nil | Image crop: `{left, right, top, bottom}` |
| `imageWidth` | number | nil | Image width |
| `imageHeight` | number | nil | Image height |

#### Font Size Mapping

| fontSize | WoW Font Object |
|----------|-----------------|
| "small" | GameFontNormalSmall |
| "medium" | GameFontNormal |
| "large" | GameFontNormalLarge |

#### Widget Rendering

```
[Icon] This is explanatory text that appears
       in the config panel.
```

---

## Media Types

### texture

Display or select a texture.

#### Definition

```lua
{
    type = "texture",
    name = "Background",
    image = "Interface\\DialogFrame\\UI-DialogBox-Background",
    imageCoords = {0, 1, 0, 1},
    imageWidth = 64,
    imageHeight = 64,
    -- Optional: make it selectable
    values = {
        ["Interface\\Buttons\\WHITE8X8"] = "Solid",
        ["Interface\\DialogFrame\\UI-DialogBox-Background"] = "Dialog",
    },
    get = function() return db.texture end,
    set = function(_, v) db.texture = v end,
}
```

#### Type-Specific Properties

| Property | Type | Description |
|----------|------|-------------|
| `image` | string | Texture path to display |
| `imageCoords` | table | Crop coordinates |
| `imageWidth` | number | Display width |
| `imageHeight` | number | Display height |
| `values` | table/function | Optional selection values |

#### Widget Rendering

Display only:
```
Background: +------+
            |      |
            | tex  |
            |      |
            +------+
```

---

### font

Select a font from available fonts.

#### Definition

```lua
{
    type = "font",
    name = "Display Font",
    desc = "Select the font for text",
    values = nil,  -- Uses defaults or LibSharedMedia
    get = function() return db.fontPath end,
    set = function(_, v) db.fontPath = v end,
}
```

#### Type-Specific Properties

| Property | Type | Description |
|----------|------|-------------|
| `values` | table/function | Optional override values |

#### Default Fonts

If no `values` provided, includes:
- Friz Quadrata (default)
- Arial Narrow
- Morpheus
- Skurri

If LibSharedMedia-3.0 is available, loads all registered fonts.

#### Widget Rendering

```
Display Font: [Friz Quadrata    v]  <- Dropdown with font preview
```

---

## Common Properties

These properties are available on **all** option types.

### Display Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | string/function | Display label |
| `desc` | string/function | Tooltip/description text |
| `descStyle` | string | "tooltip" or "inline" |
| `order` | number/function | Sort order (lower = earlier) |

### Visibility Properties

| Property | Type | Description |
|----------|------|-------------|
| `hidden` | boolean/function | Hide completely |
| `disabled` | boolean/function | Show but non-interactive |

### Width Control

| Property | Type | Description |
|----------|------|-------------|
| `width` | string/number | Widget width |

Width values:
- `"half"` - 0.5x normal
- `"normal"` - 1.0x (default)
- `"double"` - 2.0x
- `"full"` - Full container width
- `number` - Custom multiplier

### Value Accessors

| Property | Type | Description |
|----------|------|-------------|
| `get` | function/string | Value getter |
| `set` | function/string | Value setter |
| `validate` | function/string | Validation function |

### Confirmation

| Property | Type | Description |
|----------|------|-------------|
| `confirm` | boolean/function/string | Require confirmation |
| `confirmText` | string/function | Confirmation message |

### Handler Support

| Property | Type | Description |
|----------|------|-------------|
| `handler` | table | Object for method resolution |
| `arg` | any | Custom argument in info |

### UI-Specific Visibility

| Property | Type | Description |
|----------|------|-------------|
| `cmdHidden` | boolean/function | Hidden in CLI |
| `guiHidden` | boolean/function | Hidden in GUI |
| `dialogHidden` | boolean/function | Hidden in dialogs |
| `dropdownHidden` | boolean/function | Hidden in dropdowns |

### Icon Properties

| Property | Type | Description |
|----------|------|-------------|
| `icon` | string/function | Icon texture path |
| `iconCoords` | table/function | Icon texture coordinates |

---

## Property Value Types

Most properties can be either static values or functions.

### Static Values

```lua
name = "Enable Feature",
hidden = false,
order = 10,
```

### Function Values

Functions receive the `info` table:

```lua
name = function(info)
    return "Enable " .. db.featureName
end,

hidden = function(info)
    return not db.showAdvanced
end,

order = function(info)
    return db.prioritize and 1 or 100
end,
```

### Info Table in Functions

```lua
function(info)
    -- info.options   = root options table
    -- info.option    = current option table
    -- info.appName   = registered app name
    -- info.type      = option type
    -- info.handler   = handler object
    -- info.arg       = custom arg
    -- info[1..n]     = path components
end
```

---

## Type Validation

### ValidateOption

Check if an option definition is valid:

```lua
local valid, errorMsg = ConfigTypes:ValidateOption("range", {
    type = "range",
    name = "Scale",
    -- Missing required min/max
})

if not valid then
    print("Error:", errorMsg)
    -- "Missing required property 'min' for type 'range'"
end
```

### CheckType

Check if a value matches expected type:

```lua
local isValid = ConfigTypes:CheckType("hello", "string")        -- true
local isValid = ConfigTypes:CheckType(123, "number")            -- true
local isValid = ConfigTypes:CheckType(func, "string|function")  -- true
```

### SupportsGetSet

Check if type stores values:

```lua
ConfigTypes:SupportsGetSet("toggle")      -- true
ConfigTypes:SupportsGetSet("group")       -- false
ConfigTypes:SupportsGetSet("header")      -- false
ConfigTypes:SupportsGetSet("execute")     -- false
```

### IsContainer

Check if type contains other options:

```lua
ConfigTypes:IsContainer("group")   -- true
ConfigTypes:IsContainer("toggle")  -- false
```

---

## Constants

### Width Values

```lua
ConfigTypes.widthValues = {
    half = 0.5,
    normal = 1.0,
    double = 2.0,
    full = "full",  -- Special handling
}
```

### Font Sizes

```lua
ConfigTypes.fontSizes = {
    small = "GameFontNormalSmall",
    medium = "GameFontNormal",
    large = "GameFontNormalLarge",
}
```

---

## Quick Reference Table

| Type | Required Props | get/set | Notes |
|------|----------------|---------|-------|
| group | args | No | Container, root must be group |
| toggle | - | Yes | Boolean checkbox |
| input | - | Yes | Text input |
| range | min, max | Yes | Numeric slider |
| select | values | Yes | Dropdown/radio |
| multiselect | values | Yes | get(info, key), set(info, key, val) |
| color | - | Yes | get returns r,g,b[,a], set receives info,r,g,b,a |
| keybinding | - | Yes | Key capture |
| execute | func | No | Button action |
| header | - | No | Section divider |
| description | - | No | Static text |
| texture | - | Optional | Display/select texture |
| font | - | Yes | Font selector |

---

## See Also

- [Config.md](Config.md) - Main configuration system documentation
- [ConfigDialog.md](ConfigDialog.md) - GUI rendering details
