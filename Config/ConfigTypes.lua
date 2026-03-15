--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ConfigTypes - Option type definitions for declarative configuration
----------------------------------------------------------------------]]

local pairs = pairs
local string_gmatch = string.gmatch
local table_sort = table.sort
local type = type

local Loolib = LibStub("Loolib")
local Config = Loolib:GetOrCreateModule("Config")

Loolib.Config.Types = Loolib.Config.Types or {}
local ConfigTypes = Loolib.Config.Types

--[[--------------------------------------------------------------------
    Type Specifications
----------------------------------------------------------------------]]

Loolib.Config.Types.types = {
    group = {
        description = "Container for nested options",
        properties = {
            args = "table",
            childGroups = "string",
            inline = "boolean",
        },
        defaults = {
            childGroups = "tree",
            inline = false,
        },
    },
    execute = {
        description = "Button that executes a function",
        properties = {
            func = "function",
            image = "string",
            imageCoords = "table",
            imageWidth = "number",
            imageHeight = "number",
        },
        required = {"func"},
    },
    input = {
        description = "Text input field",
        properties = {
            multiline = "boolean|number", -- true = 4 lines, number = that many lines
            pattern = "string",
            usage = "string",
        },
        defaults = {
            multiline = false,
        },
    },
    toggle = {
        description = "Boolean checkbox",
        properties = {
            tristate = "boolean",
        },
        defaults = {
            tristate = false,
        },
    },
    range = {
        description = "Numeric slider",
        properties = {
            min = "number",
            max = "number",
            softMin = "number",
            softMax = "number",
            step = "number",
            bigStep = "number",
            isPercent = "boolean",
        },
        required = {"min", "max"},
        defaults = {
            step = 0,
            isPercent = false,
        },
    },
    select = {
        description = "Dropdown or radio selection",
        properties = {
            values = "table|function",
            style = "string",
            sorting = "table|function",
        },
        required = {"values"},
        defaults = {
            style = "dropdown",
        },
    },
    multiselect = {
        description = "Multiple checkbox selection",
        properties = {
            values = "table|function",
            tristate = "boolean",
        },
        required = {"values"},
        defaults = {
            tristate = false,
        },
    },
    color = {
        description = "Color picker",
        properties = {
            hasAlpha = "boolean",
        },
        defaults = {
            hasAlpha = false,
        },
    },
    keybinding = {
        description = "Key binding capture",
        properties = {},
    },
    header = {
        description = "Section divider",
        properties = {},
    },
    description = {
        description = "Static text display",
        properties = {
            fontSize = "string",
            image = "string",
            imageCoords = "table",
            imageWidth = "number",
            imageHeight = "number",
        },
        defaults = {
            fontSize = "medium",
        },
    },
    texture = {
        description = "Texture selector or display",
        properties = {
            image = "string",
            imageCoords = "table",
            imageWidth = "number",
            imageHeight = "number",
            values = "table|function",
        },
    },
    font = {
        description = "Font selector",
        properties = {
            values = "table|function",
        },
    },
}

Loolib.Config.Types.commonProperties = {
    name = "string|function",
    desc = "string|function",
    descStyle = "string",
    order = "number|function",
    hidden = "boolean|function",
    disabled = "boolean|function",
    width = "string|number",
    get = "function|string",
    set = "function|string",
    validate = "function|string",
    confirm = "boolean|function|string",
    confirmText = "string",
    handler = "table",
    arg = "any",
    cmdHidden = "boolean|function",
    guiHidden = "boolean|function",
    dialogHidden = "boolean|function",
    dropdownHidden = "boolean|function",
    icon = "string|function",
    iconCoords = "table|function",
}

Loolib.Config.Types.widthValues = {
    third = 0.333,
    half = 0.5,
    normal = 1.0,
    double = 2.0,
    full = "full",
}

Loolib.Config.Types.fontSizes = {
    small = "GameFontNormalSmall",
    medium = "GameFontNormal",
    large = "GameFontNormalLarge",
}

--[[--------------------------------------------------------------------
    Validation Functions
----------------------------------------------------------------------]]

function ConfigTypes:ValidateOption(optionType, option)
    local typeSpec = self.types[optionType]
    if not typeSpec then
        return false, string.format("Unknown option type: %s", optionType)
    end

    if typeSpec.required then
        for _, propName in ipairs(typeSpec.required) do
            if option[propName] == nil then
                return false, string.format("Missing required property '%s' for type '%s'", propName, optionType)
            end
        end
    end

    return true
end

function ConfigTypes:CheckType(value, expectedType)
    if value == nil then
        return true
    end

    for typeOption in string_gmatch(expectedType, "[^|]+") do
        typeOption = typeOption:gsub("^%s+", ""):gsub("%s+$", "")
        if typeOption == "any" or typeOption == type(value) then
            return true
        end
    end

    return false
end

function ConfigTypes:GetDefault(optionType, property)
    local typeSpec = self.types[optionType]
    if typeSpec and typeSpec.defaults then
        return typeSpec.defaults[property]
    end
    return nil
end

function ConfigTypes:IsContainer(optionType)
    return optionType == "group"
end

function ConfigTypes:SupportsGetSet(optionType)
    local noGetSet = {
        group = true,
        execute = true,
        header = true,
        description = true,
        texture = true,
    }

    if optionType == "texture" then
        return false
    end

    return not noGetSet[optionType]
end

function ConfigTypes:GetAllTypes()
    local types = {}
    for typeName in pairs(self.types) do
        types[#types + 1] = typeName
    end
    table_sort(types)
    return types
end

Loolib.Config.Types = ConfigTypes

Loolib:RegisterModule("ConfigTypes", ConfigTypes)
Loolib:RegisterModule("Config.Types", ConfigTypes)
