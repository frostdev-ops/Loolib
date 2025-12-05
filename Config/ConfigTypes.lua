--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ConfigTypes - Option type definitions for declarative configuration

    Defines all supported option types and their properties for the
    configuration system. This serves as the schema for options tables.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibConfigTypes

    Defines the valid option types and their expected properties.
    Used for validation and documentation purposes.
----------------------------------------------------------------------]]

LoolibConfigTypes = {}

--[[--------------------------------------------------------------------
    Type Specifications

    Each type has:
    - properties: Type-specific configuration options
    - required: Required properties for this type
    - description: What this type represents
----------------------------------------------------------------------]]

LoolibConfigTypes.types = {
    --[[----------------------------------------------------------------
        Container Type: group

        A container that holds other options. Can be displayed as
        a tree node, tab, inline section, or select dropdown.
    ------------------------------------------------------------------]]
    group = {
        description = "Container for nested options",
        properties = {
            args = "table",              -- Nested options table
            childGroups = "string",      -- "tree", "tab", or "select"
            inline = "boolean",          -- Display inline instead of separate panel
        },
        defaults = {
            childGroups = "tree",
            inline = false,
        },
    },

    --[[----------------------------------------------------------------
        Action Type: execute

        A button that triggers an action when clicked.
    ------------------------------------------------------------------]]
    execute = {
        description = "Button that executes a function",
        properties = {
            func = "function",           -- Click handler: func(info)
            image = "string",            -- Optional icon texture path
            imageCoords = "table",       -- Icon crop coordinates {l, r, t, b}
            imageWidth = "number",       -- Icon width
            imageHeight = "number",      -- Icon height
        },
        required = {"func"},
    },

    --[[----------------------------------------------------------------
        Input Type: input

        Text input field for string values.
    ------------------------------------------------------------------]]
    input = {
        description = "Text input field",
        properties = {
            multiline = "boolean",       -- Multi-line text box (true = 4 lines default)
            pattern = "string",          -- Validation regex pattern
            usage = "string",            -- Usage hint displayed on error
        },
        defaults = {
            multiline = false,
        },
    },

    --[[----------------------------------------------------------------
        Toggle Type: toggle

        Boolean checkbox for on/off settings.
    ------------------------------------------------------------------]]
    toggle = {
        description = "Boolean checkbox",
        properties = {
            tristate = "boolean",        -- Allow nil as third state
        },
        defaults = {
            tristate = false,
        },
    },

    --[[----------------------------------------------------------------
        Range Type: range

        Slider for numeric values within a range.
    ------------------------------------------------------------------]]
    range = {
        description = "Numeric slider",
        properties = {
            min = "number",              -- Minimum value
            max = "number",              -- Maximum value
            softMin = "number",          -- Soft minimum (can exceed with input)
            softMax = "number",          -- Soft maximum (can exceed with input)
            step = "number",             -- Step increment
            bigStep = "number",          -- Ctrl+click increment
            isPercent = "boolean",       -- Display as percentage (0-1 as 0-100%)
        },
        required = {"min", "max"},
        defaults = {
            step = 0,                    -- 0 = continuous
            isPercent = false,
        },
    },

    --[[----------------------------------------------------------------
        Select Type: select

        Dropdown or radio button selection from predefined values.
    ------------------------------------------------------------------]]
    select = {
        description = "Dropdown or radio selection",
        properties = {
            values = "table|function",   -- {key = "Label"} or function(info) returning table
            style = "string",            -- "dropdown" or "radio"
            sorting = "table|function",  -- Custom sort order {key1, key2, ...}
        },
        required = {"values"},
        defaults = {
            style = "dropdown",
        },
    },

    --[[----------------------------------------------------------------
        MultiSelect Type: multiselect

        Multiple checkbox selection from predefined values.
    ------------------------------------------------------------------]]
    multiselect = {
        description = "Multiple checkbox selection",
        properties = {
            values = "table|function",   -- {key = "Label"} or function(info) returning table
            tristate = "boolean",        -- Allow nil as third state per item
        },
        required = {"values"},
        defaults = {
            tristate = false,
        },
    },

    --[[----------------------------------------------------------------
        Color Type: color

        Color picker for RGBA values.
    ------------------------------------------------------------------]]
    color = {
        description = "Color picker",
        properties = {
            hasAlpha = "boolean",        -- Show alpha slider
        },
        defaults = {
            hasAlpha = false,
        },
    },

    --[[----------------------------------------------------------------
        Keybinding Type: keybinding

        Key binding capture button.
    ------------------------------------------------------------------]]
    keybinding = {
        description = "Key binding capture",
        properties = {},
    },

    --[[----------------------------------------------------------------
        Header Type: header

        Section divider/header text.
    ------------------------------------------------------------------]]
    header = {
        description = "Section divider",
        properties = {},
        -- Only uses 'name' property for display
    },

    --[[----------------------------------------------------------------
        Description Type: description

        Static text description/help.
    ------------------------------------------------------------------]]
    description = {
        description = "Static text display",
        properties = {
            fontSize = "string",         -- "small", "medium", or "large"
            image = "string",            -- Optional image texture path
            imageCoords = "table",       -- Image crop coordinates
            imageWidth = "number",       -- Image width
            imageHeight = "number",      -- Image height
        },
        defaults = {
            fontSize = "medium",
        },
    },

    --[[----------------------------------------------------------------
        Texture Type: texture
        
        Select or display a texture.
    ------------------------------------------------------------------]]
    texture = {
        description = "Texture selector or display",
        properties = {
            image = "string",            -- Texture path
            imageCoords = "table",       -- {l, r, t, b}
            imageWidth = "number",
            imageHeight = "number",
            values = "table|function",   -- Optional selection values
        },
    },

    --[[----------------------------------------------------------------
        Font Type: font
        
        Select a font (integrates with LibSharedMedia if available).
    ------------------------------------------------------------------]]
    font = {
        description = "Font selector",
        properties = {
            values = "table|function",   -- Optional override values
        },
    },
}

--[[--------------------------------------------------------------------
    Common Properties

    These properties are available on ALL option types.
----------------------------------------------------------------------]]

LoolibConfigTypes.commonProperties = {
    -- Display properties
    name = "string|function",            -- Display name or function(info) returning name
    desc = "string|function",            -- Description/tooltip or function(info)
    descStyle = "string",                -- "tooltip" or "inline"
    order = "number|function",           -- Sort order or function(info) returning number

    -- Visibility properties
    hidden = "boolean|function",         -- Hidden from view or function(info) returning boolean
    disabled = "boolean|function",       -- Disabled (grayed out) or function(info)

    -- Width control
    width = "string|number",             -- "normal", "half", "double", "full", or custom number

    -- Value accessors
    get = "function|string",             -- Getter function or method name
    set = "function|string",             -- Setter function or method name
    validate = "function|string",        -- Validation function or method name (return true/error string)

    -- Confirmation
    confirm = "boolean|function|string", -- Require confirmation before set
    confirmText = "string",              -- Custom confirmation text

    -- Method resolution
    handler = "table",                   -- Object to call methods on
    arg = "any",                         -- Custom argument passed in info table

    -- UI-specific visibility
    cmdHidden = "boolean|function",      -- Hidden in command-line interface
    guiHidden = "boolean|function",      -- Hidden in GUI dialog
    dialogHidden = "boolean|function",   -- Hidden in modal dialogs
    dropdownHidden = "boolean|function", -- Hidden in dropdown mode

    -- Icon
    icon = "string|function",            -- Icon texture path
    iconCoords = "table|function",       -- Icon texture coordinates
}

--[[--------------------------------------------------------------------
    Width Constants
----------------------------------------------------------------------]]

LoolibConfigTypes.widthValues = {
    half = 0.5,
    normal = 1.0,
    double = 2.0,
    full = "full",  -- Special handling for full width
}

--[[--------------------------------------------------------------------
    Font Size Constants
----------------------------------------------------------------------]]

LoolibConfigTypes.fontSizes = {
    small = "GameFontNormalSmall",
    medium = "GameFontNormal",
    large = "GameFontNormalLarge",
}

--[[--------------------------------------------------------------------
    Validation Functions
----------------------------------------------------------------------]]

--- Validate an option's type-specific properties
-- @param optionType string - The option type
-- @param option table - The option definition
-- @return boolean, string|nil - Success, error message
function LoolibConfigTypes:ValidateOption(optionType, option)
    local typeSpec = self.types[optionType]
    if not typeSpec then
        return false, string.format("Unknown option type: %s", optionType)
    end

    -- Check required properties
    if typeSpec.required then
        for _, propName in ipairs(typeSpec.required) do
            if option[propName] == nil then
                return false, string.format("Missing required property '%s' for type '%s'", propName, optionType)
            end
        end
    end

    return true
end

--- Check if a value matches expected type
-- @param value any - The value to check
-- @param expectedType string - Expected type (can include "|" for alternatives)
-- @return boolean
function LoolibConfigTypes:CheckType(value, expectedType)
    if value == nil then
        return true  -- nil is always valid (checked separately if required)
    end

    -- Handle multiple types (e.g., "string|function")
    for typeOption in string.gmatch(expectedType, "[^|]+") do
        typeOption = typeOption:gsub("^%s+", ""):gsub("%s+$", "")  -- trim

        if typeOption == "any" then
            return true
        elseif typeOption == type(value) then
            return true
        end
    end

    return false
end

--- Get default value for a type-specific property
-- @param optionType string - The option type
-- @param property string - The property name
-- @return any - The default value
function LoolibConfigTypes:GetDefault(optionType, property)
    local typeSpec = self.types[optionType]
    if typeSpec and typeSpec.defaults then
        return typeSpec.defaults[property]
    end
    return nil
end

--- Check if an option type is a container
-- @param optionType string - The option type
-- @return boolean
function LoolibConfigTypes:IsContainer(optionType)
    return optionType == "group"
end

--- Check if an option type supports get/set
-- @param optionType string - The option type
-- @return boolean
function LoolibConfigTypes:SupportsGetSet(optionType)
    -- These types don't have values to get/set
    local noGetSet = {
        group = true,
        execute = true,
        header = true,
        description = true,
        texture = true, -- Texture acts like description unless it has values/selection
    }
    
    -- Special case: texture can be a selector if it has 'values' or 'set'
    if optionType == "texture" then
         -- We don't have the option instance here to check properties easily
         -- But generally 'texture' is for display. If used for selection, 
         -- it should probably be a 'select' with a custom widget/control?
         -- Or we allow texture to be a value type if needed.
         -- Let's assume it's NOT a value type by default unless we check more deep.
         -- Actually, LoolibConfigTypes:SupportsGetSet is called with just type.
         -- So we have to decide globally.
         -- Let's stick to texture being display-only for now, similar to description.
         return false
    end
    
    return not noGetSet[optionType]
end

--- Get list of all valid option types
-- @return table - Array of type names
function LoolibConfigTypes:GetAllTypes()
    local types = {}
    for typeName in pairs(self.types) do
        types[#types + 1] = typeName
    end
    table.sort(types)
    return types
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib:RegisterModule("ConfigTypes", LoolibConfigTypes)
