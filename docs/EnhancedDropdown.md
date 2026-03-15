# EnhancedDropdown

Advanced dropdown widget with submenus, icons, embedded controls, and rich customization options.

**File**: `UI/Widgets/EnhancedDropdown.lua`

## Overview

The EnhancedDropdown provides a sophisticated menu selection system inspired by MRT's dropdown implementation. It supports:

- Multi-level nested submenus
- Icons (texture paths or atlas names)
- Embedded controls (sliders, editboxes)
- Checkboxes and radio buttons
- Separators and section headers
- Color-coded text
- Tooltips
- Fluent API for configuration

## Factory Function

```lua
LoolibCreateEnhancedDropdown(parent, name)
```

**Parameters**:
- `parent` (Frame) - Parent frame
- `name` (string, optional) - Global name for the frame

**Returns**: EnhancedDropdown frame with all mixin methods

## Option Structure

Each dropdown option is a table with the following fields:

```lua
{
    -- Basic fields
    text = "Label",               -- Display text (required)
    value = any,                  -- Value to store/return

    -- Visual customization
    icon = "path" or atlasName,   -- Left-side icon
    iconIsAtlas = bool,           -- If true, icon is atlas
    iconCoords = {l,r,t,b},       -- Texture coordinates for icon
    colorCode = "|cFFRRGGBB",     -- Color code prefix

    -- State and behavior
    disabled = bool,              -- Grayed out, non-interactive
    isTitle = bool,               -- Non-selectable section header
    isSeparator = bool,           -- Horizontal divider line
    tooltip = "text",             -- Hover tooltip

    -- Submenus
    subMenu = { ... },            -- Array of nested options

    -- Embedded controls (MRT-style)
    slider = {min, max, value, callback, step},
    editBox = {defaultText, callback, width},

    -- Checkboxes
    checkState = bool,            -- Checkbox state
    onCheckChange = function,     -- Checkbox callback
    radio = bool,                 -- Radio button style

    -- Advanced
    font = "FontObject",          -- Custom font
    padding = number,             -- Extra vertical padding
}
```

## Configuration Methods

### SetList(options)
Set the complete list of dropdown options.

```lua
dropdown:SetList({
    {text = "Option 1", value = 1},
    {text = "Option 2", value = 2},
    {text = "Option 3", value = 3},
})
```

**Parameters**:
- `options` (table[]) - Array of option tables

**Returns**: self (for chaining)

### AddOption(option)
Add a single option to the list.

```lua
dropdown:AddOption({text = "New Option", value = 4})
```

**Parameters**:
- `option` (table) - Option table

**Returns**: self

### ClearOptions()
Remove all options from the dropdown.

```lua
dropdown:ClearOptions()
```

**Returns**: self

### SetValue(value)
Set the selected value and update display text.

```lua
dropdown:SetValue(2)  -- Selects option with value=2
```

**Parameters**:
- `value` (any) - Value to select

**Returns**: self

### GetValue()
Get the currently selected value.

```lua
local value = dropdown:GetValue()
```

**Returns**: any - Selected value

### SetText(text)
Set the button display text (manual override).

```lua
dropdown:SetText("Custom Text")
```

**Parameters**:
- `text` (string) - Text to display

**Returns**: self

### OnSelect(callback)
Register a callback for when an option is selected.

```lua
dropdown:OnSelect(function(value, option)
    print("Selected:", option.text, "Value:", value)
end)
```

**Parameters**:
- `callback` (function) - Function(value, option)

**Returns**: self

### SetMenuWidth(width)
Set the width of the dropdown menu (independent of button width).

```lua
dropdown:SetMenuWidth(300)
```

**Parameters**:
- `width` (number) - Menu width in pixels

**Returns**: self

### SetMaxLines(lines)
Set the maximum number of visible menu lines before scrolling.

```lua
dropdown:SetMaxLines(20)
```

**Parameters**:
- `lines` (number) - Max visible lines (default: 15)

**Returns**: self

### SetAutoText(enabled)
Enable/disable automatic text update when option is selected.

```lua
dropdown:SetAutoText(false)  -- Keep custom text
```

**Parameters**:
- `enabled` (boolean) - Auto-update text on selection

**Returns**: self

### SetEnabled(enabled)
Enable or disable the dropdown.

```lua
dropdown:SetEnabled(false)  -- Disable
```

**Parameters**:
- `enabled` (boolean) - Enabled state

**Returns**: self

## Menu Control Methods

### OpenMenu()
Open the dropdown menu programmatically. The menu is clamped to screen edges
so it never renders off-screen, even when the dropdown button is positioned
near the bottom or right edge of the viewport.

```lua
dropdown:OpenMenu()
```

### CloseMenu()
Close the dropdown menu programmatically.

```lua
dropdown:CloseMenu()
```

### Toggle()
Toggle menu open/closed state.

```lua
dropdown:Toggle()
```

## Layout Methods

### Size(width, height)
Set dropdown size (fluent API).

```lua
dropdown:Size(200, 28)
```

**Parameters**:
- `width` (number) - Width in pixels
- `height` (number, optional) - Height in pixels (default: 24)

**Returns**: self

### Point(...)
Set anchor point (fluent API).

```lua
dropdown:Point("CENTER", 0, 50)
```

**Returns**: self

## Usage Examples

### Basic Dropdown

```lua
local dropdown = LoolibCreateEnhancedDropdown(parent)
    :Size(200, 28)
    :Point("CENTER")
    :SetList({
        {text = "Warrior", value = "WARRIOR"},
        {text = "Paladin", value = "PALADIN"},
        {text = "Hunter", value = "HUNTER"},
    })
    :OnSelect(function(value, option)
        print("Selected class:", value)
    end)
```

### Dropdown with Icons

```lua
dropdown:SetList({
    {
        text = "Tank",
        value = "TANK",
        icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    },
    {
        text = "Healer",
        value = "HEALER",
        icon = "Interface\\Icons\\Spell_Holy_FlashHeal",
    },
    {
        text = "DPS",
        value = "DPS",
        icon = "Interface\\Icons\\Ability_DualWield",
    },
})
```

### Dropdown with Submenus

```lua
dropdown:SetList({
    {text = "Main Menu", isTitle = true},
    {isSeparator = true},
    {
        text = "Classes",
        subMenu = {
            {text = "Warrior", value = "WARRIOR"},
            {text = "Paladin", value = "PALADIN"},
            {text = "Hunter", value = "HUNTER"},
        }
    },
    {
        text = "Specs",
        subMenu = {
            {text = "Arms", value = "ARMS"},
            {text = "Fury", value = "FURY"},
            {text = "Protection", value = "PROTECTION"},
        }
    },
})
```

### Dropdown with Checkboxes

```lua
dropdown:SetText("Options")
dropdown:SetAutoText(false)  -- Don't change text on selection

dropdown:SetList({
    {text = "Settings", isTitle = true},
    {isSeparator = true},
    {
        text = "Enable Sound",
        checkState = true,
        onCheckChange = function(checked)
            SetCVar("Sound_EnableAllSound", checked and "1" or "0")
        end
    },
    {
        text = "Show Minimap",
        checkState = false,
        onCheckChange = function(checked)
            -- Toggle minimap visibility
        end
    },
})
```

### Dropdown with Embedded Slider

```lua
local volume = 50

dropdown:SetList({
    {text = "Audio Settings", isTitle = true},
    {isSeparator = true},
    {
        text = "Volume",
        slider = {
            0,      -- min
            100,    -- max
            volume, -- current value
            function(value)
                volume = value
                SetCVar("Sound_MasterVolume", value / 100)
            end,
            1       -- step
        }
    },
})
```

### Dropdown with Embedded EditBox

```lua
local prefix = "Player"

dropdown:SetList({
    {text = "Name Settings", isTitle = true},
    {isSeparator = true},
    {
        text = "Name Prefix",
        editBox = {
            prefix,     -- default text
            function(text)
                prefix = text
                print("Prefix changed to:", text)
            end,
            150         -- width
        }
    },
})
```

### Color-Coded Options

```lua
dropdown:SetList({
    {text = "Raid Difficulty", isTitle = true},
    {isSeparator = true},
    {
        text = "Normal",
        value = 1,
        colorCode = "|cFF00FF00",  -- Green
    },
    {
        text = "Heroic",
        value = 2,
        colorCode = "|cFF0070DD",  -- Blue
    },
    {
        text = "Mythic",
        value = 3,
        colorCode = "|cFFA335EE",  -- Purple
    },
})
```

### Full-Featured Dropdown

```lua
local dropdown = LoolibCreateEnhancedDropdown(parent)
    :Size(250, 32)
    :Point("CENTER")
    :SetMenuWidth(300)

local settings = {
    class = "WARRIOR",
    spec = "ARMS",
    showHealth = true,
    scale = 100,
}

dropdown:SetList({
    {text = "Configuration", isTitle = true},
    {isSeparator = true},
    {
        text = "Classes",
        icon = "Interface\\Icons\\ClassIcon_Warrior",
        subMenu = {
            {text = "Warrior", value = "WARRIOR", icon = "Interface\\Icons\\ClassIcon_Warrior"},
            {text = "Paladin", value = "PALADIN", icon = "Interface\\Icons\\ClassIcon_Paladin"},
        },
        tooltip = "Select your character class",
    },
    {isSeparator = true},
    {text = "Display Options", isTitle = true, padding = 4},
    {
        text = "Show Health Bar",
        checkState = settings.showHealth,
        onCheckChange = function(checked)
            settings.showHealth = checked
        end
    },
    {
        text = "UI Scale",
        slider = {50, 150, settings.scale, function(value)
            settings.scale = value
        end, 5},
        padding = 8,
    },
    {isSeparator = true},
    {text = "Apply", value = "apply", colorCode = "|cFF00FF00"},
    {text = "Reset", value = "reset", colorCode = "|cFFFF0000"},
})

dropdown:OnSelect(function(value, option)
    if value == "apply" then
        print("Settings applied")
    elseif value == "reset" then
        print("Settings reset")
    end
end)
```

## Advanced Features

### Multi-Level Submenus

Submenus can contain their own submenus for deep nesting:

```lua
dropdown:SetList({
    {
        text = "Level 1",
        subMenu = {
            {
                text = "Level 2",
                subMenu = {
                    {text = "Level 3", value = "deep"},
                }
            }
        }
    }
})
```

### Mixed Content in Single Menu

Combine all option types in a single menu:

```lua
dropdown:SetList({
    {text = "Header", isTitle = true},
    {isSeparator = true},
    {text = "Regular Option", value = 1},
    {text = "Option with Icon", value = 2, icon = "Interface\\Icons\\INV_Misc_QuestionMark"},
    {text = "Submenu Parent", subMenu = {...}},
    {text = "Checkbox", checkState = true, onCheckChange = function() end},
    {text = "Slider", slider = {0, 100, 50, function() end}},
    {text = "EditBox", editBox = {"text", function() end, 100}},
    {isSeparator = true},
    {text = "Disabled", value = 3, disabled = true},
})
```

### Dynamic Option Updates

Options can be updated dynamically:

```lua
local myOptions = {
    {text = "Option 1", value = 1},
    {text = "Option 2", value = 2},
}

dropdown:SetList(myOptions)

-- Later, add more options
table.insert(myOptions, {text = "Option 3", value = 3})
dropdown:SetList(myOptions)  -- Refresh
```

### Stateful Checkboxes

Checkbox states persist in the option table:

```lua
local options = {
    {text = "Setting 1", checkState = true, onCheckChange = function(checked)
        -- checked reflects the new state
        print("Setting 1 is now:", checked)
    end},
}

dropdown:SetList(options)

-- Access current state later
print("Current state:", options[1].checkState)
```

## Best Practices

1. **Use SetAutoText(false) for multi-action dropdowns**: When the dropdown triggers actions rather than selecting values (like checkboxes or buttons), disable auto-text update.

2. **Provide tooltips for complex options**: Help users understand what each option does.

3. **Use separators for visual grouping**: Break long lists into logical sections.

4. **Limit submenu depth**: Keep submenus to 2-3 levels maximum for usability.

5. **Test embedded controls**: Sliders and editboxes need enough padding to be usable.

6. **Set appropriate menu width**: Use `SetMenuWidth()` for dropdowns with embedded controls or long text.

## Integration with WidgetMod

EnhancedDropdown automatically applies WidgetMod if available:

```lua
local dropdown = LoolibCreateEnhancedDropdown(parent)
    :Size(200, 28)
    :Point("CENTER")
    :Alpha(0.95)
    :Tooltip("Select an option")
    :SetList({...})
```

## Module Registration

```lua
local Loolib = LibStub("Loolib")
local EnhancedDropdownModule = Loolib:GetModule("EnhancedDropdown")

-- Access mixin
local mixin = EnhancedDropdownModule.Mixin

-- Create instance
local dropdown = EnhancedDropdownModule.Create(parent)
```

## See Also

- [Dropdown.md](Dropdown.md) - Basic dropdown widget
- [WidgetMod.md](WidgetMod.md) - Fluent API mixin
- [WindowUtil.md](WindowUtil.md) - Positioning and layout utilities
