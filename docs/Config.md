# Loolib Configuration System

Comprehensive documentation for the Loolib declarative configuration system.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Option Types Reference](#option-types-reference)
4. [Common Properties](#common-properties)
5. [The "info" Parameter](#the-info-parameter)
6. [Creating Options Tables](#creating-options-tables)
7. [GUI System (ConfigDialog)](#gui-system-configdialog)
8. [Command-Line Interface (ConfigCmd)](#command-line-interface-configcmd)
9. [Profile Options](#profile-options)
10. [Complete Examples](#complete-examples)
11. [Advanced Topics](#advanced-topics)
12. [Best Practices](#best-practices)
13. [Integration Examples](#integration-examples)
14. [API Reference](#api-reference)

---

## Overview

### What is the Configuration System?

The Loolib Configuration System provides a **declarative** approach to addon configuration. Instead of manually creating UI elements and handling their events, you define your configuration options in a structured Lua table, and the system automatically:

- Generates a graphical user interface (GUI)
- Creates command-line interface (CLI) support via slash commands
- Handles value getting/setting
- Manages validation and confirmation dialogs
- Integrates with WoW's Settings panel

### Declarative Options Tables

A declarative options table describes **what** your configuration options are, not **how** to render them:

```lua
local options = {
    type = "group",
    name = "My Addon",
    args = {
        enabled = {
            type = "toggle",
            name = "Enable Addon",
            desc = "Turn the addon on or off",
            get = function() return MyAddonDB.enabled end,
            set = function(info, value) MyAddonDB.enabled = value end,
        },
        scale = {
            type = "range",
            name = "UI Scale",
            min = 0.5,
            max = 2.0,
            get = function() return MyAddonDB.scale end,
            set = function(info, value) MyAddonDB.scale = value end,
        },
    },
}
```

The system interprets this table and creates the appropriate UI widgets automatically.

### Comparison with AceConfig-3.0

Loolib's Config system is inspired by and largely compatible with AceConfig-3.0, the industry standard for WoW addon configuration. Key similarities and differences:

| Feature | Loolib Config | AceConfig-3.0 |
|---------|---------------|---------------|
| Declarative tables | Yes | Yes |
| Options table format | Compatible | Original |
| GUI rendering | Built-in | Via AceConfigDialog |
| CLI support | Built-in | Via AceConfigCmd |
| Blizzard Settings | WoW 10.0+ API | Legacy + modern |
| External dependencies | LibStub only | Ace3 ecosystem |
| Profile management | LoolibSavedVariables | AceDB-3.0 |

If you're migrating from Ace3, most of your options tables will work with minimal changes.

### Architecture Diagram

```
+----------------------------------------------------------------------+
|                        LoolibConfig                                   |
|                    (Main Entry Point)                                 |
|                                                                       |
|  RegisterOptionsTable()  Open()  Close()  GetProfileOptions()         |
+----------------------------------------------------------------------+
        |                    |                    |
        v                    v                    v
+----------------+  +------------------+  +-------------------+
| ConfigRegistry |  |   ConfigDialog   |  |  ProfileOptions   |
|----------------|  |------------------|  |-------------------|
| - Storage      |  | - GUI Rendering  |  | - Profile UI      |
| - Validation   |  | - Tree/Tab/Inline|  | - Import/Export   |
| - Caching      |  | - Blizzard Panel |  | - Profile Mgmt    |
| - Navigation   |  | - Widget Pools   |  |                   |
+----------------+  +------------------+  +-------------------+
        |
        v
+----------------+  +------------------+
|  ConfigTypes   |  |    ConfigCmd     |
|----------------|  |------------------|
| - Type Specs   |  | - Slash Commands |
| - Validation   |  | - CLI Parsing    |
| - Defaults     |  | - Value Display  |
+----------------+  +------------------+
```

### Module Responsibilities

| Module | Purpose |
|--------|---------|
| **Config** | Main entry point, convenience methods, localization |
| **ConfigTypes** | Defines all option types and their properties |
| **ConfigRegistry** | Stores and manages options tables, provides navigation |
| **ConfigDialog** | Renders options tables as GUI dialogs |
| **ConfigCmd** | Handles slash commands and CLI interaction |
| **ProfileOptions** | Generates profile management UI |

---

## Quick Start

### Minimal Working Example

```lua
-- In your addon's main file
local MyAddon = {}
local db = {}

-- Define your options table
local options = {
    type = "group",
    name = "My Addon Settings",
    args = {
        enable = {
            type = "toggle",
            name = "Enable",
            desc = "Enable or disable the addon",
            get = function() return db.enable end,
            set = function(info, value)
                db.enable = value
            end,
            order = 1,
        },
        greeting = {
            type = "input",
            name = "Greeting Message",
            desc = "Message shown on login",
            get = function() return db.greeting end,
            set = function(info, value) db.greeting = value end,
            order = 2,
        },
    },
}

-- Register on addon load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
    if addon ~= "MyAddon" then return end

    -- Initialize saved variables
    MyAddonDB = MyAddonDB or { enable = true, greeting = "Hello!" }
    db = MyAddonDB

    -- Register options with a slash command
    LoolibConfig:RegisterOptionsTable("MyAddon", options, "myaddon")

    -- Optionally add to Blizzard Settings
    LoolibConfig:AddToBlizOptions("MyAddon", "My Addon")
end)
```

### Opening the Dialog

After registration, users can open your config in several ways:

```lua
-- Via slash command (if registered)
/myaddon

-- Programmatically
LoolibConfig:Open("MyAddon")

-- Open to a specific section
LoolibConfig:Open("MyAddon", "appearance", "colors")

-- Via Blizzard Settings panel (if added)
-- Settings > Addons > My Addon
```

---

## Option Types Reference

The Config system supports 14 option types, each designed for a specific kind of configuration value.

### Container Type

#### group

A container that holds other options. Can be displayed as a tree node, tab panel, inline section, or select dropdown.

```lua
{
    type = "group",
    name = "General Settings",
    desc = "Configure general options",
    args = {
        -- Child options go here
    },
    childGroups = "tree",  -- "tree", "tab", or "select"
    inline = false,        -- true = display inline within parent
}
```

| Property | Type | Description |
|----------|------|-------------|
| `args` | table | Nested options (key = option key) |
| `childGroups` | string | Display mode: "tree" (default), "tab", "select" |
| `inline` | boolean | Display inline instead of separate panel |

**Display Modes:**

- **tree**: Shows child groups in a left sidebar tree (default)
- **tab**: Shows child groups as tabs at the top
- **select**: Shows child groups as a dropdown selector

### Action Type

#### execute

A button that triggers an action when clicked.

```lua
{
    type = "execute",
    name = "Reset to Defaults",
    desc = "Reset all settings to their default values",
    func = function(info)
        ResetDefaults()
        print("Settings reset!")
    end,
    confirm = true,
    confirmText = "Are you sure you want to reset all settings?",
}
```

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `func` | function | **Yes** | Click handler: `func(info)` |
| `image` | string | No | Icon texture path |
| `imageCoords` | table | No | Icon crop: `{left, right, top, bottom}` |
| `imageWidth` | number | No | Icon width in pixels |
| `imageHeight` | number | No | Icon height in pixels |

### Input Types

#### input

A text input field for string values.

```lua
{
    type = "input",
    name = "Character Name",
    desc = "Enter your character's name",
    get = function() return db.charName end,
    set = function(info, value) db.charName = value end,
    multiline = false,
    pattern = "^[A-Za-z]+$",
    usage = "Name must contain only letters",
}
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `multiline` | boolean | false | Multi-line text box (4 lines default) |
| `pattern` | string | nil | Lua pattern for validation |
| `usage` | string | nil | Usage hint shown on validation error |

#### toggle

A boolean checkbox for on/off settings.

```lua
{
    type = "toggle",
    name = "Show Minimap Icon",
    desc = "Display the addon icon on the minimap",
    get = function() return db.showMinimap end,
    set = function(info, value) db.showMinimap = value end,
    tristate = false,
}
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `tristate` | boolean | false | Allow nil as third state |

#### range

A slider for numeric values within a range.

```lua
{
    type = "range",
    name = "Opacity",
    desc = "Set the window opacity",
    min = 0,
    max = 1,
    step = 0.05,
    isPercent = true,
    get = function() return db.opacity end,
    set = function(info, value) db.opacity = value end,
}
```

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `min` | number | **Yes** | Minimum value |
| `max` | number | **Yes** | Maximum value |
| `softMin` | number | No | Soft minimum (slider limit, but input can exceed) |
| `softMax` | number | No | Soft maximum (slider limit, but input can exceed) |
| `step` | number | 0 | Step increment (0 = continuous) |
| `bigStep` | number | nil | Ctrl+click step increment |
| `isPercent` | boolean | false | Display as percentage (0-1 shown as 0%-100%) |

### Selection Types

#### select

A dropdown or radio button selection from predefined values.

```lua
{
    type = "select",
    name = "Font",
    desc = "Select the display font",
    values = {
        arial = "Arial",
        friz = "Friz Quadrata",
        morpheus = "Morpheus",
    },
    sorting = {"arial", "friz", "morpheus"},
    style = "dropdown",
    get = function() return db.font end,
    set = function(info, value) db.font = value end,
}
```

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `values` | table/function | **Yes** | `{key = "Label"}` or `function(info)` returning table |
| `style` | string | "dropdown" | "dropdown" or "radio" |
| `sorting` | table/function | nil | Custom sort order: `{key1, key2, ...}` |

**Dynamic Values:**

```lua
values = function(info)
    local fonts = {}
    -- Build dynamically based on game state
    for _, font in pairs(GetAvailableFonts()) do
        fonts[font.path] = font.name
    end
    return fonts
end,
```

#### multiselect

Multiple checkbox selection from predefined values.

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
    get = function(info, key)
        return db.modules[key]
    end,
    set = function(info, key, value)
        db.modules[key] = value
    end,
}
```

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `values` | table/function | **Yes** | `{key = "Label"}` or `function(info)` returning table |
| `tristate` | boolean | No | Allow nil as third state per item |

**Note:** For multiselect, `get` and `set` receive an additional `key` parameter.

### Color Type

#### color

A color picker for RGBA values.

```lua
{
    type = "color",
    name = "Border Color",
    desc = "Select the border color",
    hasAlpha = true,
    get = function()
        return db.borderR, db.borderG, db.borderB, db.borderA
    end,
    set = function(info, r, g, b, a)
        db.borderR, db.borderG, db.borderB, db.borderA = r, g, b, a
    end,
}
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `hasAlpha` | boolean | false | Show alpha (transparency) slider |

**Note:** Color `get` returns `r, g, b, a` (0-1 range). `set` receives `info, r, g, b, a`.

### Key Binding Type

#### keybinding

A key binding capture button.

```lua
{
    type = "keybinding",
    name = "Toggle Hotkey",
    desc = "Press a key to set the toggle binding",
    get = function() return db.toggleKey end,
    set = function(info, value)
        db.toggleKey = value
        -- Update actual binding
        SetBinding(value, "MYADDON_TOGGLE")
    end,
}
```

The `set` function receives a string like `"CTRL-SHIFT-A"` or `"F12"`.

### Display Types

#### header

A section divider/header text. No value storage.

```lua
{
    type = "header",
    name = "Display Options",
    order = 10,
}
```

Only uses `name` and `order`. Creates a visual separator with text.

#### description

Static text description/help. No value storage.

```lua
{
    type = "description",
    name = "Configure how the addon displays information on your screen. These settings affect all characters on this account.",
    fontSize = "medium",
    image = "Interface\\Icons\\INV_Misc_QuestionMark",
    imageWidth = 32,
    imageHeight = 32,
}
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fontSize` | string | "medium" | "small", "medium", or "large" |
| `image` | string | nil | Image texture path |
| `imageCoords` | table | nil | Image crop coordinates |
| `imageWidth` | number | nil | Image width |
| `imageHeight` | number | nil | Image height |

### Media Types

#### texture

Select or display a texture.

```lua
{
    type = "texture",
    name = "Background",
    image = "Interface\\DialogFrame\\UI-DialogBox-Background",
    imageWidth = 64,
    imageHeight = 64,
    -- Optional: make it a selector
    values = {
        ["Interface\\Buttons\\WHITE8X8"] = "Solid",
        ["Interface\\DialogFrame\\UI-DialogBox-Background"] = "Dialog",
    },
    get = function() return db.bgTexture end,
    set = function(info, value) db.bgTexture = value end,
}
```

#### font

Select a font (integrates with LibSharedMedia if available).

```lua
{
    type = "font",
    name = "Display Font",
    desc = "Select the font for text display",
    -- Uses default WoW fonts, or LibSharedMedia if available
    get = function() return db.fontPath end,
    set = function(info, value) db.fontPath = value end,
}
```

If `LibSharedMedia-3.0` is loaded, it automatically populates with registered fonts.

---

## Common Properties

These properties are available on **all** option types:

### Display Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | string/function | Display name. Can be `function(info)` returning string |
| `desc` | string/function | Description/tooltip text |
| `descStyle` | string | "tooltip" or "inline" |
| `order` | number/function | Sort order (lower = earlier). Default 100 |

### Visibility Properties

| Property | Type | Description |
|----------|------|-------------|
| `hidden` | boolean/function | Hide from view entirely |
| `disabled` | boolean/function | Show but grayed out, non-interactive |

```lua
{
    type = "toggle",
    name = "Advanced Feature",
    hidden = function(info) return not db.showAdvanced end,
    disabled = function(info) return not db.mainEnabled end,
}
```

### Width Control

| Property | Type | Description |
|----------|------|-------------|
| `width` | string/number | "half", "normal", "double", "full", or custom number |

```lua
width = "half",     -- Half width (side by side with another)
width = "normal",   -- Standard width (default)
width = "double",   -- Double width
width = "full",     -- Full container width
width = 1.5,        -- Custom multiplier
```

### Value Accessors

| Property | Type | Description |
|----------|------|-------------|
| `get` | function/string | Getter: `function(info)` or method name |
| `set` | function/string | Setter: `function(info, value)` or method name |
| `validate` | function/string | Validation: return `true` or error string |

### Confirmation

| Property | Type | Description |
|----------|------|-------------|
| `confirm` | boolean/function/string | Require confirmation before `set` |
| `confirmText` | string | Custom confirmation message |

```lua
{
    type = "execute",
    name = "Delete All Data",
    confirm = true,
    confirmText = "This will permanently delete all saved data. Continue?",
    func = function() DeleteAllData() end,
}
```

### Method Resolution

| Property | Type | Description |
|----------|------|-------------|
| `handler` | table | Object to call methods on |
| `arg` | any | Custom argument passed in info table |

### UI-Specific Visibility

| Property | Type | Description |
|----------|------|-------------|
| `cmdHidden` | boolean/function | Hidden in command-line interface only |
| `guiHidden` | boolean/function | Hidden in GUI dialog only |
| `dialogHidden` | boolean/function | Hidden in modal dialogs only |
| `dropdownHidden` | boolean/function | Hidden in dropdown mode only |

```lua
{
    type = "color",
    name = "Theme Color",
    cmdHidden = true,  -- Colors are hard to set via CLI
}
```

### Icon Properties

| Property | Type | Description |
|----------|------|-------------|
| `icon` | string/function | Icon texture path |
| `iconCoords` | table/function | Icon texture coordinates |

---

## The "info" Parameter

Every `get`, `set`, `validate`, `hidden`, `disabled`, and callback function receives an `info` table as its first parameter. Understanding this table is crucial for advanced configuration.

### Structure

```lua
info = {
    -- Options context
    options = <root options table>,
    option = <current option table>,
    appName = "MyAddon",
    type = "toggle",

    -- Handler for method resolution
    handler = <handler table or nil>,

    -- Custom argument
    arg = <value from option.arg or nil>,

    -- Path components (array indices 1, 2, 3, ...)
    [1] = "general",      -- First path component
    [2] = "display",      -- Second path component
    [3] = "showMinimap",  -- Third path component (option key)
}
```

### Path Components

The info table is also an array containing the path to the current option:

```lua
local options = {
    type = "group",
    name = "Root",
    args = {
        general = {
            type = "group",
            name = "General",
            args = {
                display = {
                    type = "group",
                    name = "Display",
                    args = {
                        showMinimap = {
                            type = "toggle",
                            name = "Show Minimap",
                            get = function(info)
                                -- info[1] = "general"
                                -- info[2] = "display"
                                -- info[3] = "showMinimap"
                                -- #info = 3
                            end,
                        },
                    },
                },
            },
        },
    },
}
```

### Using Path for Storage

A common pattern is using the path to navigate your saved variables:

```lua
-- Flat storage using last key
get = function(info)
    return db[info[#info]]  -- info[#info] = option key
end,
set = function(info, value)
    db[info[#info]] = value
end,

-- Nested storage matching options structure
get = function(info)
    local value = db
    for i = 1, #info do
        value = value[info[i]]
        if value == nil then return nil end
    end
    return value
end,
```

### Handler Resolution

When you use a string for `get`/`set` instead of a function, the system looks up that method on the handler:

```lua
local MyHandler = {
    db = {},
    GetEnabled = function(self, info)
        return self.db.enabled
    end,
    SetEnabled = function(self, info, value)
        self.db.enabled = value
    end,
}

local options = {
    type = "group",
    name = "My Addon",
    handler = MyHandler,  -- Set handler at root level
    args = {
        enabled = {
            type = "toggle",
            name = "Enabled",
            get = "GetEnabled",  -- Calls MyHandler:GetEnabled(info)
            set = "SetEnabled",  -- Calls MyHandler:SetEnabled(info, value)
        },
    },
}
```

Handler inheritance works top-down: child options inherit the handler from their parent unless they specify their own.

### Info Properties Reference

| Property | Description |
|----------|-------------|
| `info.options` | Root options table |
| `info.option` | Current option's table |
| `info.appName` | Registered app name |
| `info.type` | Option type string |
| `info.handler` | Handler object for method resolution |
| `info.arg` | Custom argument from `option.arg` |
| `info[1..n]` | Path components from root to current option |
| `#info` | Number of path components |

---

## Creating Options Tables

### Basic Structure

Every options table must have a root `group`:

```lua
local options = {
    type = "group",           -- Required: root must be "group"
    name = "Addon Name",      -- Display name
    desc = "Description",     -- Optional description
    handler = myHandler,      -- Optional: handler for method resolution
    childGroups = "tree",     -- Optional: "tree", "tab", or "select"
    args = {
        -- Child options here
    },
}
```

### Nesting Groups

Groups can be nested to create hierarchical navigation:

```lua
local options = {
    type = "group",
    name = "My Addon",
    args = {
        general = {
            type = "group",
            name = "General",
            order = 1,
            args = {
                enabled = {
                    type = "toggle",
                    name = "Enabled",
                    order = 1,
                },
            },
        },
        appearance = {
            type = "group",
            name = "Appearance",
            order = 2,
            args = {
                scale = {
                    type = "range",
                    name = "Scale",
                    min = 0.5, max = 2,
                },
                colors = {
                    type = "group",
                    name = "Colors",
                    inline = true,  -- Display inline, not as separate panel
                    args = {
                        background = {
                            type = "color",
                            name = "Background",
                        },
                    },
                },
            },
        },
    },
}
```

### Function vs Static Values

Most properties can be either static values or functions:

```lua
-- Static value
name = "Enable Feature",

-- Dynamic value
name = function(info)
    if db.featureVersion == 2 then
        return "Enable Feature (v2)"
    end
    return "Enable Feature"
end,

-- Dynamic select values
values = function(info)
    local vals = {}
    for id, data in pairs(GetGameData()) do
        vals[id] = data.name
    end
    return vals
end,

-- Dynamic visibility
hidden = function(info)
    return db.advancedMode == false
end,
```

### Ordering Options

Use `order` to control display sequence:

```lua
args = {
    header1 = { type = "header", name = "Basic", order = 1 },
    enabled = { type = "toggle", name = "Enabled", order = 2 },
    name = { type = "input", name = "Name", order = 3 },

    header2 = { type = "header", name = "Advanced", order = 10 },
    debug = { type = "toggle", name = "Debug Mode", order = 11 },

    -- Without order, sorts alphabetically by key after ordered items
    zzzOption = { type = "toggle", name = "Last Option" },  -- order = 100 (default)
}
```

### Complete Example with All Patterns

```lua
local db = {}  -- Your saved variables reference

local options = {
    type = "group",
    name = "Complete Example Addon",
    handler = {
        db = db,
        GetDB = function(self, info)
            return self.db[info[#info]]
        end,
        SetDB = function(self, info, value)
            self.db[info[#info]] = value
        end,
    },
    get = "GetDB",   -- Default getter for all children
    set = "SetDB",   -- Default setter for all children
    args = {
        -- Header for section
        generalHeader = {
            type = "header",
            name = "General Settings",
            order = 1,
        },

        -- Basic toggle
        enabled = {
            type = "toggle",
            name = "Enable Addon",
            desc = "Master switch for the addon",
            order = 2,
        },

        -- Input with validation
        welcomeMsg = {
            type = "input",
            name = "Welcome Message",
            desc = "Shown when you log in",
            validate = function(info, value)
                if #value > 100 then
                    return "Message too long (max 100 characters)"
                end
                return true
            end,
            order = 3,
        },

        -- Range slider
        scale = {
            type = "range",
            name = "UI Scale",
            min = 0.5,
            max = 2.0,
            step = 0.1,
            isPercent = true,
            order = 4,
        },

        -- Appearance group
        appearance = {
            type = "group",
            name = "Appearance",
            order = 10,
            args = {
                font = {
                    type = "select",
                    name = "Font",
                    values = {
                        ["Fonts\\FRIZQT__.TTF"] = "Default",
                        ["Fonts\\ARIALN.TTF"] = "Arial",
                    },
                },
                backgroundColor = {
                    type = "color",
                    name = "Background Color",
                    hasAlpha = true,
                    get = function()
                        local c = db.backgroundColor or {r=0, g=0, b=0, a=1}
                        return c.r, c.g, c.b, c.a
                    end,
                    set = function(info, r, g, b, a)
                        db.backgroundColor = {r=r, g=g, b=b, a=a}
                    end,
                },
            },
        },

        -- Actions group
        actions = {
            type = "group",
            name = "Actions",
            inline = true,
            order = 20,
            args = {
                reset = {
                    type = "execute",
                    name = "Reset Settings",
                    func = function()
                        wipe(db)
                        print("Settings reset!")
                    end,
                    confirm = true,
                    confirmText = "Reset all settings to defaults?",
                },
            },
        },
    },
}
```

---

## GUI System (ConfigDialog)

The ConfigDialog module renders options tables as interactive UI dialogs.

### Opening Dialogs

```lua
-- Simple open
LoolibConfig:Open("MyAddon")

-- Open to specific group (by path)
LoolibConfig:Open("MyAddon", "appearance")
LoolibConfig:Open("MyAddon", "appearance", "colors")

-- Close dialog
LoolibConfig:Close("MyAddon")

-- Close all dialogs
LoolibConfig:Close()
```

### Group Display Modes

The `childGroups` property on a group determines how its children are displayed:

#### Tree Mode (Default)

```lua
{
    type = "group",
    name = "My Addon",
    childGroups = "tree",
    args = { ... }
}
```

```
+-----------------------------------+
| My Addon                      [X] |
+--------+--------------------------+
| > Gen  |  General Settings       |
| > App  |  [x] Enable             |
| > Adv  |  Scale: [====|===]      |
|        |                         |
+--------+--------------------------+
```

#### Tab Mode

```lua
{
    type = "group",
    name = "My Addon",
    childGroups = "tab",
    args = { ... }
}
```

```
+-----------------------------------+
| My Addon                      [X] |
+-----------------------------------+
| [General] [Appearance] [Advanced] |
+-----------------------------------+
|  General Settings                 |
|  [x] Enable                       |
|  Scale: [====|===]                |
+-----------------------------------+
```

#### Select Mode

Children appear as a dropdown selector instead of tree or tabs.

#### Inline Groups

Groups with `inline = true` display directly within the parent panel:

```lua
appearance = {
    type = "group",
    name = "Appearance",
    args = {
        colors = {
            type = "group",
            name = "Colors",
            inline = true,  -- Shows as bordered section
            args = {
                background = { type = "color", name = "Background" },
                text = { type = "color", name = "Text" },
            },
        },
    },
}
```

```
+-----------------------------+
| Appearance                  |
+-----------------------------+
| +-------------------------+ |
| | Colors                  | |
| | Background: [##]        | |
| | Text: [##]              | |
| +-------------------------+ |
+-----------------------------+
```

### Widget Rendering

Each option type renders as a specific widget:

| Type | Widget |
|------|--------|
| toggle | Checkbox |
| input | EditBox (multiline = TextBox) |
| range | Slider with value display |
| select | Dropdown button with popup menu |
| multiselect | Grid of checkboxes |
| color | Color swatch button opening ColorPicker |
| execute | Button |
| keybinding | Capture button |
| header | FontString with underline |
| description | FontString |
| texture | Frame with texture display |
| font | Dropdown with font preview |

### Blizzard Settings Integration

Add your addon to WoW's Settings panel:

```lua
-- Add to root of Settings > Addons
LoolibConfig:AddToBlizOptions("MyAddon", "My Addon Display Name")

-- Add as sub-category
LoolibConfig:AddToBlizOptions("MyAddon", "Combat", "My Addon Display Name")
```

When opened from Blizzard Settings, a simplified panel with an "Open Config" button appears, which opens the full standalone dialog.

### Direct ConfigDialog Access

For advanced usage, access the ConfigDialog module directly:

```lua
local ConfigDialogModule = Loolib:GetModule("ConfigDialog")
local Dialog = ConfigDialogModule.Dialog

-- Set default dialog size
Dialog:SetDefaultSize("MyAddon", 800, 600)

-- Navigate programmatically
Dialog:SelectGroup("MyAddon", "appearance", "colors")

-- Listen for events
Dialog:RegisterCallback("OnDialogOpened", function(appName)
    print("Config opened for:", appName)
end)

Dialog:RegisterCallback("OnGroupSelected", function(appName, ...)
    local path = {...}
    print("Selected:", table.concat(path, " > "))
end)
```

---

## Command-Line Interface (ConfigCmd)

The ConfigCmd module provides slash command support for navigating and modifying options.

### Registering Slash Commands

```lua
-- During options registration
LoolibConfig:RegisterOptionsTable("MyAddon", options, "myaddon")

-- Multiple commands
LoolibConfig:RegisterOptionsTable("MyAddon", options, {"myaddon", "ma"})

-- Separate registration
LoolibConfig.Cmd:CreateChatCommand("myaddon", "MyAddon")
```

### Command Syntax

```
/myaddon                    -- Show root options
/myaddon general            -- Navigate to "general" group
/myaddon general enabled    -- Show value of "enabled" in "general"
/myaddon enabled true       -- Set "enabled" to true
/myaddon scale 1.5          -- Set "scale" to 1.5
/myaddon font arial         -- Set "font" to "arial"
/myaddon reset              -- Execute "reset" action
```

### Value Formats by Type

| Type | Format | Examples |
|------|--------|----------|
| toggle | true/false, yes/no, on/off, 1/0 | `true`, `yes`, `on`, `1` |
| input | Any text (quote for spaces) | `Hello`, `"Hello World"` |
| range | Number or percentage | `1.5`, `75%` |
| select | Key or label (case-insensitive) | `arial`, `"Arial Narrow"` |
| multiselect | key=true/false or key (toggle) | `combat=true`, `combat` |
| color | r g b [a] or #rrggbb | `1 0 0`, `1 0 0 0.5`, `#ff0000` |
| keybinding | Key string | `CTRL-SHIFT-A`, `F12` |

### Command Output

```
/myaddon
|cff00ff00My Addon|r
  |cffffff00enabled|r = |cff00ff00true|r - Enable Addon
  |cffffff00scale|r = 1.50 - UI Scale
  |cffffff00general|r |cff888888[group]|r - General Settings
  |cffffff00reset|r |cff888888[action]|r - Reset Settings

/myaddon enabled
|cffffff00Enable Addon|r = |cff00ff00true|r
  Master switch for the addon

/myaddon enabled false
Set to |cffff0000false|r
```

### Hiding Options from CLI

Some options don't make sense in CLI (like colors):

```lua
backgroundColor = {
    type = "color",
    name = "Background Color",
    cmdHidden = true,  -- Won't show in /command
},
```

---

## Profile Options

The ProfileOptions module generates a complete profile management UI for `LoolibSavedVariables` instances.

### Basic Usage

```lua
local db = LoolibSavedVariables:Create("MyAddonDB", defaults)

local options = {
    type = "group",
    name = "My Addon",
    args = {
        -- Your regular options...
        general = { ... },
        appearance = { ... },

        -- Add profile management
        profiles = LoolibConfig:GetProfileOptions(db),
    },
}
```

### Generated UI

The profile options table includes:

1. **Current Profile Display** - Shows active profile name
2. **Profile Selector** - Dropdown to switch profiles
3. **New Profile Creation** - Text input to create new profile
4. **Copy From** - Copy settings from another profile
5. **Import/Export** - Export to string, import from string
6. **Reset Profile** - Reset to defaults (with confirmation)
7. **Delete Profile** - Delete current profile (with confirmation)
8. **Profile List** - View all available profiles

### Standalone Profile Dialog

```lua
-- Open a dedicated profile management dialog
local ProfileOptions = Loolib:GetModule("ProfileOptions")
ProfileOptions:CreateDialog(db)
```

### Compact Profile Options

For embedding in limited space:

```lua
local compactProfiles = ProfileOptions:GetCompactOptionsTable(db)

-- Only includes: Profile dropdown, New input, Reset button
```

### Profile Options Screenshot Layout

```
+---------------------------------------------+
| Profiles                                     |
+---------------------------------------------+
| --- Current Profile ---                      |
| Current Profile: MyProfile                   |
|                                              |
| --- Select Profile ---                       |
| Profile: [MyProfile         v]               |
|                                              |
| --- Create New Profile ---                   |
| New Profile Name: [________________]         |
|                                              |
| --- Copy From ---                            |
| Source Profile: [Select...        v]         |
|                                              |
| --- Import / Export ---                      |
| [Export Profile]  [Import Profile]           |
|                                              |
| [Reset Profile]   [Delete Profile]           |
|                                              |
| --- All Profiles ---                         |
| >> MyProfile <<                              |
|     Default                                  |
|     Healer                                   |
|     Tank                                     |
+---------------------------------------------+
```

---

## Complete Examples

### Example 1: Simple Addon Config

A minimal but complete configuration for a small addon:

```lua
local AddonName, Addon = ...
local db

local defaults = {
    enabled = true,
    message = "Hello, World!",
    scale = 1.0,
}

local options = {
    type = "group",
    name = AddonName,
    desc = "A simple example addon",
    args = {
        enabled = {
            type = "toggle",
            name = "Enable",
            desc = "Enable or disable the addon",
            get = function() return db.enabled end,
            set = function(_, v) db.enabled = v end,
            order = 1,
        },
        message = {
            type = "input",
            name = "Message",
            desc = "The message to display",
            get = function() return db.message end,
            set = function(_, v) db.message = v end,
            order = 2,
            width = "double",
        },
        scale = {
            type = "range",
            name = "Scale",
            desc = "UI element scale",
            min = 0.5,
            max = 2.0,
            step = 0.1,
            get = function() return db.scale end,
            set = function(_, v)
                db.scale = v
                Addon:UpdateScale()
            end,
            order = 3,
        },
    },
}

-- Initialization
local function OnLoad()
    MyAddonDB = MyAddonDB or CopyTable(defaults)
    db = MyAddonDB

    LoolibConfig:RegisterOptionsTable(AddonName, options, "myaddon")
    LoolibConfig:AddToBlizOptions(AddonName, AddonName)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addon)
    if addon == AddonName then
        OnLoad()
    end
end)
```

### Example 2: Complex Nested Groups

Demonstrating tree navigation with multiple levels:

```lua
local options = {
    type = "group",
    name = "Advanced Addon",
    childGroups = "tree",
    args = {
        general = {
            type = "group",
            name = "General",
            order = 1,
            args = {
                intro = {
                    type = "description",
                    name = "General addon settings",
                    order = 1,
                },
                enabled = {
                    type = "toggle",
                    name = "Enable Addon",
                    order = 2,
                    get = function() return db.enabled end,
                    set = function(_, v) db.enabled = v end,
                },
                debug = {
                    type = "toggle",
                    name = "Debug Mode",
                    order = 3,
                    hidden = function() return not db.showAdvanced end,
                    get = function() return db.debug end,
                    set = function(_, v) db.debug = v end,
                },
            },
        },

        appearance = {
            type = "group",
            name = "Appearance",
            order = 2,
            args = {
                mainFrame = {
                    type = "group",
                    name = "Main Frame",
                    order = 1,
                    args = {
                        scale = {
                            type = "range",
                            name = "Scale",
                            min = 0.5, max = 2, step = 0.05,
                            get = function() return db.mainFrame.scale end,
                            set = function(_, v) db.mainFrame.scale = v end,
                        },
                        alpha = {
                            type = "range",
                            name = "Opacity",
                            min = 0, max = 1, step = 0.05,
                            isPercent = true,
                            get = function() return db.mainFrame.alpha end,
                            set = function(_, v) db.mainFrame.alpha = v end,
                        },
                    },
                },

                colors = {
                    type = "group",
                    name = "Colors",
                    order = 2,
                    args = {
                        background = {
                            type = "color",
                            name = "Background",
                            hasAlpha = true,
                            get = function()
                                local c = db.colors.background
                                return c.r, c.g, c.b, c.a
                            end,
                            set = function(_, r, g, b, a)
                                db.colors.background = {r=r, g=g, b=b, a=a}
                            end,
                        },
                        border = {
                            type = "color",
                            name = "Border",
                            get = function()
                                local c = db.colors.border
                                return c.r, c.g, c.b
                            end,
                            set = function(_, r, g, b)
                                db.colors.border = {r=r, g=g, b=b}
                            end,
                        },
                    },
                },

                fonts = {
                    type = "group",
                    name = "Fonts",
                    order = 3,
                    args = {
                        mainFont = {
                            type = "font",
                            name = "Main Font",
                            get = function() return db.fonts.main end,
                            set = function(_, v) db.fonts.main = v end,
                        },
                        fontSize = {
                            type = "range",
                            name = "Font Size",
                            min = 8, max = 24, step = 1,
                            get = function() return db.fonts.size end,
                            set = function(_, v) db.fonts.size = v end,
                        },
                    },
                },
            },
        },

        modules = {
            type = "group",
            name = "Modules",
            order = 3,
            args = {
                enabledModules = {
                    type = "multiselect",
                    name = "Enabled Modules",
                    values = {
                        combat = "Combat Tracker",
                        inventory = "Inventory Manager",
                        map = "Map Extensions",
                        chat = "Chat Enhancements",
                    },
                    get = function(_, key) return db.modules[key] end,
                    set = function(_, key, val) db.modules[key] = val end,
                },
            },
        },

        -- Profile management at the end
        profiles = {
            type = "group",
            name = "Profiles",
            order = 100,
            args = LoolibConfig:GetProfileOptions(db).args,
        },
    },
}
```

### Example 3: Tab Panel Layout

Using tabs instead of tree:

```lua
local options = {
    type = "group",
    name = "Tab Example",
    childGroups = "tab",
    args = {
        general = {
            type = "group",
            name = "General",
            order = 1,
            args = {
                desc = {
                    type = "description",
                    name = "General settings for the addon.",
                    order = 1,
                },
                -- ... options
            },
        },
        display = {
            type = "group",
            name = "Display",
            order = 2,
            args = {
                -- ... options
            },
        },
        advanced = {
            type = "group",
            name = "Advanced",
            order = 3,
            args = {
                -- ... options
            },
        },
    },
}
```

### Example 4: Inline Groups

Grouping related options visually:

```lua
local options = {
    type = "group",
    name = "Inline Example",
    args = {
        mainHeader = {
            type = "header",
            name = "Main Settings",
            order = 1,
        },
        enabled = {
            type = "toggle",
            name = "Enable",
            order = 2,
        },

        -- Inline group for position
        position = {
            type = "group",
            name = "Position",
            inline = true,
            order = 10,
            args = {
                x = {
                    type = "range",
                    name = "X Offset",
                    min = -500, max = 500,
                    width = "half",
                    order = 1,
                },
                y = {
                    type = "range",
                    name = "Y Offset",
                    min = -500, max = 500,
                    width = "half",
                    order = 2,
                },
            },
        },

        -- Another inline group for size
        size = {
            type = "group",
            name = "Size",
            inline = true,
            order = 20,
            args = {
                width = {
                    type = "range",
                    name = "Width",
                    min = 50, max = 500,
                    width = "half",
                    order = 1,
                },
                height = {
                    type = "range",
                    name = "Height",
                    min = 50, max = 500,
                    width = "half",
                    order = 2,
                },
            },
        },
    },
}
```

### Example 5: All Option Types Showcase

Demonstrating every option type:

```lua
local options = {
    type = "group",
    name = "All Types Demo",
    args = {
        -- Display types
        typeHeader = {
            type = "header",
            name = "Display Types",
            order = 1,
        },
        typeDescription = {
            type = "description",
            name = "This is a description. It displays informational text that doesn't interact with any settings.",
            fontSize = "medium",
            order = 2,
        },

        -- Input types header
        inputHeader = {
            type = "header",
            name = "Input Types",
            order = 10,
        },

        -- toggle
        toggleExample = {
            type = "toggle",
            name = "Toggle Example",
            desc = "A simple on/off checkbox",
            order = 11,
            get = function() return db.toggle end,
            set = function(_, v) db.toggle = v end,
        },

        -- tristate toggle
        tristateExample = {
            type = "toggle",
            name = "Tristate Toggle",
            desc = "Can be true, false, or nil (default)",
            tristate = true,
            order = 12,
            get = function() return db.tristate end,
            set = function(_, v) db.tristate = v end,
        },

        -- input (single line)
        inputExample = {
            type = "input",
            name = "Text Input",
            desc = "Single line text input",
            order = 13,
            get = function() return db.textInput end,
            set = function(_, v) db.textInput = v end,
        },

        -- input (multi-line)
        multilineExample = {
            type = "input",
            name = "Multi-line Input",
            desc = "Multi-line text area",
            multiline = true,
            width = "full",
            order = 14,
            get = function() return db.multilineInput end,
            set = function(_, v) db.multilineInput = v end,
        },

        -- range
        rangeExample = {
            type = "range",
            name = "Range Slider",
            desc = "Numeric slider",
            min = 0,
            max = 100,
            step = 5,
            order = 15,
            get = function() return db.rangeValue end,
            set = function(_, v) db.rangeValue = v end,
        },

        -- range (percent)
        percentExample = {
            type = "range",
            name = "Percentage",
            desc = "Displayed as percentage",
            min = 0,
            max = 1,
            step = 0.01,
            isPercent = true,
            order = 16,
            get = function() return db.percentValue end,
            set = function(_, v) db.percentValue = v end,
        },

        -- Selection header
        selectHeader = {
            type = "header",
            name = "Selection Types",
            order = 20,
        },

        -- select (dropdown)
        selectExample = {
            type = "select",
            name = "Dropdown Select",
            desc = "Choose from a list",
            values = {
                option1 = "First Option",
                option2 = "Second Option",
                option3 = "Third Option",
            },
            order = 21,
            get = function() return db.selected end,
            set = function(_, v) db.selected = v end,
        },

        -- select (radio)
        radioExample = {
            type = "select",
            name = "Radio Select",
            desc = "Radio button style",
            values = {
                choice1 = "Choice A",
                choice2 = "Choice B",
                choice3 = "Choice C",
            },
            style = "radio",
            order = 22,
            get = function() return db.radioChoice end,
            set = function(_, v) db.radioChoice = v end,
        },

        -- multiselect
        multiselectExample = {
            type = "multiselect",
            name = "Multi-Select",
            desc = "Select multiple options",
            values = {
                opt1 = "Option 1",
                opt2 = "Option 2",
                opt3 = "Option 3",
                opt4 = "Option 4",
            },
            order = 23,
            get = function(_, key) return db.multiOptions[key] end,
            set = function(_, key, val) db.multiOptions[key] = val end,
        },

        -- Special types header
        specialHeader = {
            type = "header",
            name = "Special Types",
            order = 30,
        },

        -- color
        colorExample = {
            type = "color",
            name = "Color Picker",
            desc = "Select a color",
            order = 31,
            get = function()
                local c = db.color
                return c.r, c.g, c.b
            end,
            set = function(_, r, g, b)
                db.color = {r = r, g = g, b = b}
            end,
        },

        -- color with alpha
        colorAlphaExample = {
            type = "color",
            name = "Color with Alpha",
            desc = "Color with transparency",
            hasAlpha = true,
            order = 32,
            get = function()
                local c = db.colorAlpha
                return c.r, c.g, c.b, c.a
            end,
            set = function(_, r, g, b, a)
                db.colorAlpha = {r = r, g = g, b = b, a = a}
            end,
        },

        -- keybinding
        keybindExample = {
            type = "keybinding",
            name = "Keybinding",
            desc = "Press a key combination",
            order = 33,
            get = function() return db.keybind end,
            set = function(_, v) db.keybind = v end,
        },

        -- execute
        executeExample = {
            type = "execute",
            name = "Execute Button",
            desc = "Click to perform an action",
            order = 34,
            func = function()
                print("Button clicked!")
            end,
        },

        -- execute with confirm
        executeConfirmExample = {
            type = "execute",
            name = "Confirm Action",
            desc = "Requires confirmation",
            confirm = true,
            confirmText = "Are you sure?",
            order = 35,
            func = function()
                print("Confirmed action executed!")
            end,
        },

        -- Media types header
        mediaHeader = {
            type = "header",
            name = "Media Types",
            order = 40,
        },

        -- font
        fontExample = {
            type = "font",
            name = "Font Selector",
            desc = "Choose a font",
            order = 41,
            get = function() return db.font end,
            set = function(_, v) db.font = v end,
        },

        -- texture
        textureExample = {
            type = "texture",
            name = "Texture Display",
            image = "Interface\\Icons\\INV_Misc_QuestionMark",
            imageWidth = 48,
            imageHeight = 48,
            order = 42,
        },

        -- Groups
        groupHeader = {
            type = "header",
            name = "Group Types",
            order = 50,
        },

        -- inline group
        inlineGroupExample = {
            type = "group",
            name = "Inline Group",
            inline = true,
            order = 51,
            args = {
                opt1 = {
                    type = "toggle",
                    name = "Inline Option 1",
                    order = 1,
                },
                opt2 = {
                    type = "toggle",
                    name = "Inline Option 2",
                    order = 2,
                },
            },
        },
    },
}
```

---

## Advanced Topics

### Dynamic Options (Functions)

Almost any property can be a function:

```lua
{
    type = "select",

    -- Dynamic name
    name = function(info)
        return "Select " .. (db.itemType or "Item")
    end,

    -- Dynamic values
    values = function(info)
        local items = {}
        for id, data in pairs(GetAvailableItems()) do
            items[id] = data.name
        end
        return items
    end,

    -- Dynamic visibility
    hidden = function(info)
        return #GetAvailableItems() == 0
    end,

    -- Dynamic disabled state
    disabled = function(info)
        return InCombatLockdown()
    end,
}
```

### Confirm Dialogs

Three ways to use confirmation:

```lua
-- Simple boolean - uses default text
confirm = true,

-- Custom static text
confirm = true,
confirmText = "This action cannot be undone. Continue?",

-- Dynamic confirmation
confirm = function(info)
    return db.itemCount > 100  -- Only confirm if many items
end,
confirmText = function(info)
    return string.format("Delete all %d items?", db.itemCount)
end,
```

### Validation

The `validate` function should return `true` for valid input, or an error string:

```lua
{
    type = "input",
    name = "Character Name",
    validate = function(info, value)
        -- Check empty
        if not value or value == "" then
            return "Name cannot be empty"
        end

        -- Check length
        if #value < 2 or #value > 12 then
            return "Name must be 2-12 characters"
        end

        -- Check pattern
        if not value:match("^[A-Za-z]+$") then
            return "Name can only contain letters"
        end

        -- Check uniqueness
        if db.names[value] then
            return "Name already exists"
        end

        return true  -- Valid!
    end,
}
```

### Disabled/Hidden Logic

Control visibility and interactivity based on other settings:

```lua
args = {
    enableFeature = {
        type = "toggle",
        name = "Enable Feature",
        order = 1,
    },

    -- Hidden unless feature enabled
    featureOption = {
        type = "range",
        name = "Feature Intensity",
        hidden = function() return not db.enableFeature end,
        order = 2,
    },

    -- Visible but disabled during combat
    combatOption = {
        type = "toggle",
        name = "Combat Setting",
        disabled = function() return InCombatLockdown() end,
        order = 3,
    },

    -- Advanced options hidden by toggle
    showAdvanced = {
        type = "toggle",
        name = "Show Advanced Options",
        order = 10,
    },
    advancedHeader = {
        type = "header",
        name = "Advanced",
        hidden = function() return not db.showAdvanced end,
        order = 11,
    },
    advancedOption1 = {
        type = "toggle",
        name = "Advanced Option 1",
        hidden = function() return not db.showAdvanced end,
        order = 12,
    },
}
```

### Custom Handlers

Use handlers to organize your addon code:

```lua
local MyAddon = {
    db = nil,

    -- Generic getter
    Get = function(self, info)
        return self.db[info[#info]]
    end,

    -- Generic setter with refresh
    Set = function(self, info, value)
        self.db[info[#info]] = value
        self:Refresh()
    end,

    -- Specific handlers
    GetColor = function(self, info)
        local c = self.db[info[#info]]
        return c.r, c.g, c.b, c.a
    end,

    SetColor = function(self, info, r, g, b, a)
        self.db[info[#info]] = {r=r, g=g, b=b, a=a}
        self:Refresh()
    end,

    Refresh = function(self)
        -- Update UI
    end,
}

local options = {
    type = "group",
    name = "My Addon",
    handler = MyAddon,
    get = "Get",
    set = "Set",
    args = {
        enabled = {
            type = "toggle",
            name = "Enabled",
            -- Uses handler's Get/Set automatically
        },
        color = {
            type = "color",
            name = "Color",
            hasAlpha = true,
            get = "GetColor",   -- Overrides default
            set = "SetColor",
        },
    },
}
```

### Option Dependencies

Create options that depend on other options' values:

```lua
args = {
    mode = {
        type = "select",
        name = "Mode",
        values = {
            simple = "Simple",
            advanced = "Advanced",
            expert = "Expert",
        },
        order = 1,
    },

    -- Only for advanced/expert
    advancedSetting = {
        type = "range",
        name = "Advanced Setting",
        hidden = function()
            return db.mode == "simple"
        end,
        order = 2,
    },

    -- Only for expert
    expertSetting = {
        type = "input",
        name = "Expert Setting",
        hidden = function()
            return db.mode ~= "expert"
        end,
        order = 3,
    },

    -- Disabled based on another toggle
    autoMode = {
        type = "toggle",
        name = "Automatic Mode",
        order = 10,
    },
    manualValue = {
        type = "range",
        name = "Manual Value",
        disabled = function()
            return db.autoMode
        end,
        order = 11,
    },
}
```

---

## Best Practices

### Options Table Organization

1. **Group related options** - Use groups and headers to organize
2. **Order logically** - Put important options first
3. **Use descriptive names** - Clear labels and descriptions
4. **Provide defaults** - Show reasonable values
5. **Progressive disclosure** - Hide advanced options by default

```lua
-- Good organization
args = {
    -- Essential options first (order 1-9)
    enabled = { order = 1 },
    mode = { order = 2 },

    -- Main settings (order 10-19)
    mainHeader = { type = "header", order = 10 },
    setting1 = { order = 11 },
    setting2 = { order = 12 },

    -- Advanced settings (order 50+)
    showAdvanced = { order = 50 },
    advancedHeader = { order = 51, hidden = ... },
    advSetting1 = { order = 52, hidden = ... },

    -- Profiles always last
    profiles = { order = 100 },
}
```

### Performance Optimization

1. **Avoid expensive operations in functions** - Cache results when possible
2. **Use static values when possible** - Functions have overhead
3. **Minimize options table rebuilds** - Use NotifyChange sparingly

```lua
-- Bad: Expensive operation in values function
values = function()
    local items = {}
    for i = 1, GetNumInventorySlots() do
        local info = GetInventorySlotInfo(i)  -- API call each time!
        items[i] = info.name
    end
    return items
end,

-- Good: Cache and refresh only when needed
local cachedItems = nil

values = function()
    if not cachedItems then
        cachedItems = {}
        -- Build cache
    end
    return cachedItems
end,

-- Clear cache when inventory changes
Events:RegisterCallback("BAG_UPDATE", function()
    cachedItems = nil
end)
```

### User Experience Guidelines

1. **Instant feedback** - Apply changes immediately when safe
2. **Confirm destructive actions** - Use `confirm` for dangerous operations
3. **Validate early** - Use `validate` to prevent bad input
4. **Provide tooltips** - Use `desc` for every interactive option
5. **Support undo** - Consider providing reset/default options

```lua
-- Good UX patterns
{
    type = "execute",
    name = "Apply Changes",
    desc = "Apply all pending changes",
    disabled = function() return not HasPendingChanges() end,
},

{
    type = "execute",
    name = "Reset to Defaults",
    desc = "Reset all settings to their default values",
    confirm = true,
    confirmText = "This will reset ALL settings. Your current configuration will be lost.",
    func = ResetDefaults,
},
```

### Accessibility

1. **Use clear labels** - Avoid jargon
2. **Provide keyboard navigation** - Tab order through options
3. **Color isn't the only indicator** - Don't rely solely on color
4. **Reasonable text sizes** - Use "medium" or "large" for descriptions

---

## Integration Examples

### With SavedVariables

Using Loolib's SavedVariables system:

```lua
local Loolib = LibStub("Loolib")
local db

local defaults = {
    profile = {
        enabled = true,
        scale = 1.0,
    },
}

local options = {
    type = "group",
    name = "My Addon",
    args = {
        enabled = {
            type = "toggle",
            name = "Enabled",
            get = function() return db.profile.enabled end,
            set = function(_, v) db.profile.enabled = v end,
        },
        scale = {
            type = "range",
            name = "Scale",
            min = 0.5, max = 2,
            get = function() return db.profile.scale end,
            set = function(_, v) db.profile.scale = v end,
        },
        profiles = LoolibConfig:GetProfileOptions(db),
    },
}

-- On ADDON_LOADED
db = Loolib:GetModule("SavedVariables"):Create("MyAddonDB", defaults)
LoolibConfig:RegisterOptionsTable("MyAddon", options, "myaddon")
```

### With Addon System

Using Loolib's Addon system:

```lua
local Loolib = LibStub("Loolib")
local Addon = Loolib:GetModule("Addon")

local MyAddon = Addon:Create("MyAddon", {
    savedVariables = "MyAddonDB",
    defaults = {
        profile = {
            enabled = true,
        },
    },
})

function MyAddon:OnInitialize()
    -- self.db is available (LoolibSavedVariables instance)

    local options = {
        type = "group",
        name = self.name,
        args = {
            enabled = {
                type = "toggle",
                name = "Enabled",
                get = function() return self.db.profile.enabled end,
                set = function(_, v)
                    self.db.profile.enabled = v
                    self:UpdateState()
                end,
            },
            profiles = LoolibConfig:GetProfileOptions(self.db),
        },
    }

    LoolibConfig:RegisterOptionsTable(self.name, options, "myaddon")
    LoolibConfig:AddToBlizOptions(self.name, self.name)
end
```

### With Localization

```lua
local L = MyAddonLocale  -- Your localization table

local options = {
    type = "group",
    name = L["ADDON_NAME"],
    desc = L["ADDON_DESC"],
    args = {
        enabled = {
            type = "toggle",
            name = L["OPT_ENABLED"],
            desc = L["OPT_ENABLED_DESC"],
        },
        scale = {
            type = "range",
            name = L["OPT_SCALE"],
            desc = L["OPT_SCALE_DESC"],
        },
    },
}

-- Or use functions for dynamic localization
{
    name = function() return L["DYNAMIC_NAME"] end,
}
```

### Complete Addon Template

```lua
-- MyAddon.lua
local AddonName, Private = ...
local Loolib = LibStub("Loolib")

-- Create addon
local MyAddon = {}
Private.addon = MyAddon

-- Defaults
local defaults = {
    profile = {
        enabled = true,
        scale = 1.0,
        colors = {
            background = {r = 0, g = 0, b = 0, a = 0.8},
        },
        modules = {
            feature1 = true,
            feature2 = false,
        },
    },
}

-- Options table
local function GetOptions(db)
    return {
        type = "group",
        name = AddonName,
        handler = MyAddon,
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enable Addon",
                        get = function() return db.profile.enabled end,
                        set = function(_, v)
                            db.profile.enabled = v
                            MyAddon:UpdateState()
                        end,
                        order = 1,
                    },
                    scale = {
                        type = "range",
                        name = "UI Scale",
                        min = 0.5, max = 2, step = 0.05,
                        get = function() return db.profile.scale end,
                        set = function(_, v)
                            db.profile.scale = v
                            MyAddon:UpdateScale()
                        end,
                        order = 2,
                    },
                },
            },

            appearance = {
                type = "group",
                name = "Appearance",
                order = 2,
                args = {
                    backgroundColor = {
                        type = "color",
                        name = "Background",
                        hasAlpha = true,
                        get = function()
                            local c = db.profile.colors.background
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            db.profile.colors.background = {r=r, g=g, b=b, a=a}
                            MyAddon:UpdateColors()
                        end,
                    },
                },
            },

            modules = {
                type = "group",
                name = "Modules",
                order = 3,
                args = {
                    enabledModules = {
                        type = "multiselect",
                        name = "Enabled Modules",
                        values = {
                            feature1 = "Feature 1",
                            feature2 = "Feature 2",
                        },
                        get = function(_, key)
                            return db.profile.modules[key]
                        end,
                        set = function(_, key, val)
                            db.profile.modules[key] = val
                            MyAddon:UpdateModules()
                        end,
                    },
                },
            },

            profiles = LoolibConfig:GetProfileOptions(db),
        },
    }
end

-- Initialization
function MyAddon:Init()
    local SavedVars = Loolib:GetModule("SavedVariables")
    self.db = SavedVars:Create("MyAddonDB", defaults)

    -- Register options
    local options = GetOptions(self.db)
    LoolibConfig:RegisterOptionsTable(AddonName, options, "myaddon")
    LoolibConfig:AddToBlizOptions(AddonName, AddonName)

    -- Setup profile change callback
    self.db:RegisterCallback("OnProfileChanged", function()
        self:UpdateState()
    end)

    self:UpdateState()
end

function MyAddon:UpdateState()
    -- Apply all settings
    self:UpdateScale()
    self:UpdateColors()
    self:UpdateModules()
end

function MyAddon:UpdateScale()
    -- Apply scale
end

function MyAddon:UpdateColors()
    -- Apply colors
end

function MyAddon:UpdateModules()
    -- Enable/disable modules
end

-- Event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addon)
    if addon == AddonName then
        MyAddon:Init()
    end
end)
```

---

## API Reference

### LoolibConfig (Main Module)

#### Registration

```lua
LoolibConfig:RegisterOptionsTable(appName, options, slashcmd)
```
Register an options table with optional slash command.

| Parameter | Type | Description |
|-----------|------|-------------|
| `appName` | string | Unique identifier for the addon |
| `options` | table/function | Options table or function returning one |
| `slashcmd` | string/table | Slash command(s) without "/" |

Returns: `boolean` - Success

---

```lua
LoolibConfig:UnregisterOptionsTable(appName)
```
Unregister an options table and its slash commands.

---

```lua
LoolibConfig:GetOptionsTable(appName, uiType)
```
Get a registered options table.

| Parameter | Type | Description |
|-----------|------|-------------|
| `appName` | string | The addon name |
| `uiType` | string | Optional: "cmd", "dialog", "bliz" |

Returns: `table` or `nil`

---

```lua
LoolibConfig:IsRegistered(appName)
```
Check if an options table is registered.

Returns: `boolean`

---

```lua
LoolibConfig:NotifyChange(appName)
```
Notify that options have changed (refresh UIs).

---

#### Dialog Control

```lua
LoolibConfig:Open(appName, ...)
```
Open the configuration dialog.

| Parameter | Type | Description |
|-----------|------|-------------|
| `appName` | string | The addon name |
| `...` | strings | Optional path to group |

Returns: `Frame` or `nil`

---

```lua
LoolibConfig:Close(appName)
```
Close the configuration dialog.

| Parameter | Type | Description |
|-----------|------|-------------|
| `appName` | string | Addon name (or nil for all) |

---

```lua
LoolibConfig:AddToBlizOptions(appName, name, parent, ...)
```
Add options to Blizzard Settings panel.

| Parameter | Type | Description |
|-----------|------|-------------|
| `appName` | string | The addon name |
| `name` | string | Display name in settings |
| `parent` | string | Parent category name (optional) |
| `...` | strings | Path to group (optional) |

Returns: `Frame` or `nil`

---

#### Profile Options

```lua
LoolibConfig:GetProfileOptions(db, noDefaultProfiles)
```
Get profile options table for a database.

| Parameter | Type | Description |
|-----------|------|-------------|
| `db` | table | LoolibSavedVariables instance |
| `noDefaultProfiles` | boolean | Don't include default profiles |

Returns: `table` - Options table for profiles

---

#### Utility Functions

```lua
LoolibConfig:ResolveValue(valueOrFunc, info)
```
Resolve a property value (handles functions).

---

```lua
LoolibConfig:BuildInfoTable(options, option, appName, ...)
```
Build info table for option callbacks.

---

### ConfigRegistry

Access via `Loolib:GetModule("ConfigRegistry").Registry`

```lua
Registry:RegisterOptionsTable(appName, options, skipValidation)
Registry:UnregisterOptionsTable(appName)
Registry:GetOptionsTable(appName, uiType, uiName)
Registry:IsRegistered(appName)
Registry:IterateOptionsTables()
Registry:GetRegisteredAppNames()
Registry:NotifyChange(appName)
Registry:ClearCache(appName)
Registry:ValidateOptionsTable(options, name, path)
Registry:GetOptionByPath(options, ...)
Registry:GetSortedOptions(group)
Registry:ResolveValue(valueOrFunc, info)
Registry:BuildInfoTable(options, option, appName, ...)
Registry:CallMethod(option, info, methodOrFunc, ...)
Registry:GetValue(option, info)
Registry:SetValue(option, info, ...)
Registry:IsHidden(option, info, uiType)
Registry:IsDisabled(option, info)
```

#### Events

- `OnConfigTableChange` - Options changed
- `OnConfigTableRegistered` - New options registered
- `OnConfigTableUnregistered` - Options removed

---

### ConfigCmd

Access via `Loolib:GetModule("ConfigCmd").Cmd`

```lua
Cmd:CreateChatCommand(slashcmd, appName)
Cmd:UnregisterChatCommand(slashcmd)
Cmd:UnregisterChatCommands(appName)
Cmd:GetChatCommands(appName)
Cmd:HandleCommand(slashcmd, appName, input)
```

---

### ConfigDialog

Access via `Loolib:GetModule("ConfigDialog").Dialog`

```lua
Dialog:Open(appName, container, ...)
Dialog:Close(appName)
Dialog:CloseAll()
Dialog:SelectGroup(appName, ...)
Dialog:SetDefaultSize(appName, width, height)
Dialog:AddToBlizOptions(appName, name, parent, ...)
```

#### Events

- `OnDialogOpened` - Dialog opened
- `OnDialogClosed` - Dialog closed
- `OnGroupSelected` - Group navigation
- `OnOptionChanged` - Option value changed

---

### ProfileOptions

Access via `Loolib:GetModule("ProfileOptions")`

```lua
ProfileOptions:GetOptionsTable(db, noDefaultProfiles)
ProfileOptions:GetCompactOptionsTable(db)
ProfileOptions:CreateDialog(db, parentFrame)
ProfileOptions:ShowExportDialog(db)
ProfileOptions:ShowImportDialog(db)
ProfileOptions:ImportProfile(db, str)
ProfileOptions:GetProfileList(db, noDefaultProfiles)
```

---

### ConfigTypes

Access via `Loolib:GetModule("ConfigTypes")`

```lua
ConfigTypes.types                -- Type specifications
ConfigTypes.commonProperties     -- Common property definitions
ConfigTypes.widthValues          -- Width constants
ConfigTypes.fontSizes            -- Font size mappings

ConfigTypes:ValidateOption(optionType, option)
ConfigTypes:CheckType(value, expectedType)
ConfigTypes:GetDefault(optionType, property)
ConfigTypes:IsContainer(optionType)
ConfigTypes:SupportsGetSet(optionType)
ConfigTypes:GetAllTypes()
```

---

## See Also

- [ConfigTypes.md](ConfigTypes.md) - Detailed type reference
- [ConfigDialog.md](ConfigDialog.md) - GUI system details
- [SavedVariables.md](SavedVariables.md) - Data persistence
- [Events.md](Events.md) - Event system integration
