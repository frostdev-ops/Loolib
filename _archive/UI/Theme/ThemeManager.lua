--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ThemeManager - Centralized theme management system

    Provides theme registration, switching, and value retrieval.
    Widgets query the theme manager for styling values.

    Dependencies (must be loaded before this file):
    - Core/Loolib.lua (Loolib namespace)
    - Core/Mixin.lua (CreateFromMixins)
    - Core/TableUtil.lua (DeepCopy)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for ThemeManager")

local TableUtil = Loolib.TableUtil or Loolib:GetModule("Core.TableUtil")
assert(TableUtil and TableUtil.DeepCopy, "Loolib/Core/TableUtil.lua must be loaded before ThemeManager")

local Theme = Loolib.Theme or Loolib:GetOrCreateModule("Theme")
local ThemeManagerModule = Theme.Manager or Loolib:GetModule("Theme.Manager") or {}

-- Cache globals at file top
local type = type
local error = error
local pairs = pairs
local pcall = pcall
local next = next
local tostring = tostring
local table_sort = table.sort
local math_max = math.max
local math_min = math.min
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local tonumber = tonumber
local string_sub = string.sub

-- INTERNAL: Static fallback constants to avoid per-call allocation
local FALLBACK_COLOR = {1, 1, 1, 1}
local FALLBACK_FONT = "GameFontNormal"
local FALLBACK_SPACING = 8

-- INTERNAL: Required top-level keys for a valid theme data table
local REQUIRED_THEME_KEYS = { "name", "colors" }

--[[--------------------------------------------------------------------
    LoolibThemeManagerMixin

    Singleton mixin that manages theme registration and retrieval.
----------------------------------------------------------------------]]

local ThemeManagerMixin = ThemeManagerModule.Mixin or {}

--- Initialize the theme manager
-- Only resets state if not already initialized (safe for reload)
function ThemeManagerMixin:Init()
    if self._initialized then
        return
    end
    self.themes = {}
    self.activeThemeName = nil
    self.activeTheme = nil
    self.callbacks = {}
    self._settingTheme = false  -- TH-02: reentrancy guard
    self._initialized = true
end

--[[--------------------------------------------------------------------
    Internal Helpers
----------------------------------------------------------------------]]

-- INTERNAL: Validate a theme data table has required structure
-- @param name string - Theme name (for error messages)
-- @param theme table - Theme data to validate
-- @return boolean, string|nil - true if valid, or false + reason
local function ValidateThemeData(name, theme)
    for _, key in pairs(REQUIRED_THEME_KEYS) do
        if theme[key] == nil then
            return false, ("missing required key '%s'"):format(key)
        end
    end
    if type(theme.name) ~= "string" then
        return false, "'name' must be a string"
    end
    if type(theme.colors) ~= "table" then
        return false, "'colors' must be a table"
    end
    return true
end

-- INTERNAL: Validate a hex color string
-- @param hex string - The hex string to validate (with or without #)
-- @return boolean
local function IsValidHexColor(hex)
    if type(hex) ~= "string" then
        return false
    end
    local stripped = string_gsub(hex, "#", "")
    return #stripped == 6 and stripped:match("^%x+$") ~= nil
end

-- INTERNAL: Validate a color table has the expected {r, g, b, a} structure
-- @param color table - The color to validate
-- @return boolean
local function IsValidColorTable(color)
    if type(color) ~= "table" then
        return false
    end
    if type(color[1]) ~= "number" or type(color[2]) ~= "number" or type(color[3]) ~= "number" then
        return false
    end
    -- alpha is optional
    if color[4] ~= nil and type(color[4]) ~= "number" then
        return false
    end
    return true
end

--[[--------------------------------------------------------------------
    Theme Registration
----------------------------------------------------------------------]]

--- Register a theme
-- @param name string - Unique theme name
-- @param theme table - Theme data table (deep-copied to prevent external mutation)
function ThemeManagerMixin:RegisterTheme(name, theme)
    if type(name) ~= "string" or name == "" then
        error("LoolibThemeManager: RegisterTheme: 'name' must be a non-empty string", 2)
    end
    if type(theme) ~= "table" then
        error("LoolibThemeManager: RegisterTheme: 'theme' must be a table", 2)
    end

    -- TH-05: Validate theme data structure
    local valid, reason = ValidateThemeData(name, theme)
    if not valid then
        error("LoolibThemeManager: RegisterTheme: invalid theme '" .. name .. "': " .. reason, 2)
    end

    -- TH-04: Deep-copy theme data to prevent external mutation
    self.themes[name] = TableUtil.DeepCopy(theme)

    -- Set as active if this is the first theme
    if not self.activeTheme then
        self:SetActiveTheme(name)
    end
end

--- Unregister a theme
-- @param name string - Theme name to unregister
function ThemeManagerMixin:UnregisterTheme(name)
    if type(name) ~= "string" then
        error("LoolibThemeManager: UnregisterTheme: 'name' must be a string", 2)
    end

    if self.activeThemeName == name then
        error("LoolibThemeManager: UnregisterTheme: cannot unregister active theme '" .. name .. "'", 2)
    end

    self.themes[name] = nil
end

--- Check if a theme is registered
-- @param name string - Theme name
-- @return boolean
function ThemeManagerMixin:HasTheme(name)
    if type(name) ~= "string" then
        return false
    end
    return self.themes[name] ~= nil
end

--- Get all registered theme names
-- @return table - Array of theme names (sorted alphabetically)
function ThemeManagerMixin:GetThemeNames()
    local names = {}
    for name in pairs(self.themes) do
        names[#names + 1] = name
    end
    table_sort(names)
    return names
end

--[[--------------------------------------------------------------------
    Active Theme
----------------------------------------------------------------------]]

--- Set the active theme
-- @param name string - Theme name to activate
function ThemeManagerMixin:SetActiveTheme(name)
    if type(name) ~= "string" then
        error("LoolibThemeManager: SetActiveTheme: 'name' must be a string", 2)
    end

    local theme = self.themes[name]
    if not theme then
        error("LoolibThemeManager: SetActiveTheme: theme not found: " .. tostring(name), 2)
    end

    local previousTheme = self.activeThemeName
    self.activeThemeName = name
    self.activeTheme = theme

    -- Notify listeners (with reentrancy guard -- TH-02)
    self:TriggerThemeChanged(previousTheme, name)
end

--- Get the active theme data table
-- @return table|nil - The active theme table, or nil if none set
function ThemeManagerMixin:GetActiveTheme()
    return self.activeTheme
end

--- Get the active theme name
-- @return string|nil - The active theme name, or nil if none set
function ThemeManagerMixin:GetActiveThemeName()
    return self.activeThemeName
end

--- Get a specific theme by name
-- @param name string - Theme name
-- @return table|nil - The theme table or nil
function ThemeManagerMixin:GetTheme(name)
    if type(name) ~= "string" then
        return nil
    end
    return self.themes[name]
end

--[[--------------------------------------------------------------------
    Theme Value Retrieval
----------------------------------------------------------------------]]

--- Get a value from the active theme, falling back to the "Default" theme
-- @param category string - Value category (e.g., "colors", "fonts")
-- @param key string - Value key within category
-- @param fallback any - Fallback value if not found in active or default theme
-- @return any - The theme value
function ThemeManagerMixin:GetValue(category, key, fallback)
    if type(category) ~= "string" then
        return fallback
    end

    -- Try active theme first
    if self.activeTheme then
        local categoryTable = self.activeTheme[category]
        if categoryTable then
            local value = categoryTable[key]
            if value ~= nil then
                return value
            end
        end
    end

    -- TH-01: Fall back to "Default" theme if active theme does not have the key
    if self.activeThemeName ~= "Default" then
        local defaultTheme = self.themes["Default"]
        if defaultTheme then
            local categoryTable = defaultTheme[category]
            if categoryTable then
                local value = categoryTable[key]
                if value ~= nil then
                    return value
                end
            end
        end
    end

    return fallback
end

--- Get a color from the active theme
-- Returns {r, g, b, a} table. Falls back to white {1, 1, 1, 1}.
-- @param colorName string - Color name
-- @param fallback table - Fallback color {r, g, b, a} (default: white)
-- @return table - Color table {r, g, b, a}
function ThemeManagerMixin:GetColor(colorName, fallback)
    local color = self:GetValue("colors", colorName, fallback or FALLBACK_COLOR)
    -- TH-01: Guarantee a valid color table is always returned
    if not IsValidColorTable(color) then
        return fallback or FALLBACK_COLOR
    end
    return color
end

--- Get a font from the active theme
-- @param fontName string - Font name
-- @param fallback string - Fallback font object name (default: "GameFontNormal")
-- @return string - Font object name
function ThemeManagerMixin:GetFont(fontName, fallback)
    local font = self:GetValue("fonts", fontName, fallback or FALLBACK_FONT)
    if type(font) ~= "string" then
        return fallback or FALLBACK_FONT
    end
    return font
end

--- Get a backdrop from the active theme
-- @param backdropName string - Backdrop name
-- @param fallback table - Fallback backdrop table
-- @return table|nil - Backdrop table
function ThemeManagerMixin:GetBackdrop(backdropName, fallback)
    local backdrop = self:GetValue("backdrops", backdropName, fallback)
    if backdrop ~= nil and type(backdrop) ~= "table" then
        return fallback
    end
    return backdrop
end

--- Get a spacing value from the active theme
-- @param spacingName string - Spacing name
-- @param fallback number - Fallback spacing value (default: 8)
-- @return number - Spacing value
function ThemeManagerMixin:GetSpacing(spacingName, fallback)
    local spacing = self:GetValue("spacing", spacingName, fallback or FALLBACK_SPACING)
    if type(spacing) ~= "number" then
        return fallback or FALLBACK_SPACING
    end
    return spacing
end

--- Get component configuration from the active theme
-- @param componentName string - Component name (e.g., "Button", "EditBox")
-- @param fallback table - Fallback configuration (default: empty table)
-- @return table - Component configuration
function ThemeManagerMixin:GetComponentConfig(componentName, fallback)
    local config = self:GetValue("components", componentName, fallback or {})
    if type(config) ~= "table" then
        return fallback or {}
    end
    return config
end

--- Get a nested value using dot notation
-- @param path string - Dot-separated path (e.g., "colors.accent")
-- @param fallback any - Fallback value
-- @return any - The value at the path
function ThemeManagerMixin:GetPath(path, fallback)
    if type(path) ~= "string" then
        return fallback
    end
    if not self.activeTheme then
        return fallback
    end

    local current = self.activeTheme
    for part in string_gmatch(path, "[^.]+") do
        if type(current) ~= "table" then
            return fallback
        end
        current = current[part]
        if current == nil then
            return fallback
        end
    end

    return current
end

--[[--------------------------------------------------------------------
    Theme Application
----------------------------------------------------------------------]]

--- Apply theme colors to a frame's backdrop
-- TH-03: Capability-checks both SetBackdropColor and SetBackdropBorderColor
-- @param frame Frame - The frame with backdrop
-- @param bgColor string - Background color name
-- @param borderColor string - Border color name
function ThemeManagerMixin:ApplyBackdropColors(frame, bgColor, borderColor)
    if type(frame) ~= "table" then
        return
    end

    if bgColor and type(frame.SetBackdropColor) == "function" then
        local bg = self:GetColor(bgColor)
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    end

    if borderColor and type(frame.SetBackdropBorderColor) == "function" then
        local border = self:GetColor(borderColor)
        frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    end
end

--- Apply theme font to a font string
-- @param fontString FontString - The font string
-- @param fontName string - Font name from theme
function ThemeManagerMixin:ApplyFont(fontString, fontName)
    if type(fontString) ~= "table" or type(fontString.SetFontObject) ~= "function" then
        return
    end
    local font = self:GetFont(fontName)
    if font then
        fontString:SetFontObject(font)
    end
end

--- Apply theme text color to a font string
-- @param fontString FontString - The font string
-- @param colorName string - Color name from theme
function ThemeManagerMixin:ApplyTextColor(fontString, colorName)
    if type(fontString) ~= "table" or type(fontString.SetTextColor) ~= "function" then
        return
    end
    local color = self:GetColor(colorName)
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

--- Apply full theme styling to a frame based on component type
-- TH-03: Capability-checks SetBackdrop instead of pcall
-- @param frame Frame - The frame to style
-- @param componentType string - Component type (e.g., "Button", "Panel")
function ThemeManagerMixin:ApplyComponentStyle(frame, componentType)
    if type(frame) ~= "table" then
        return
    end
    if type(componentType) ~= "string" then
        return
    end

    local config = self:GetComponentConfig(componentType)
    if not config or not next(config) then
        return
    end

    -- Apply size if specified
    if config.width and type(frame.SetWidth) == "function" then
        frame:SetWidth(config.width)
    end
    if config.height and type(frame.SetHeight) == "function" then
        frame:SetHeight(config.height)
    end

    -- TH-03: Capability-check SetBackdrop instead of pcall
    if config.backdrop and type(frame.SetBackdrop) == "function" then
        local backdrop = self:GetBackdrop(config.backdrop)
        if backdrop then
            frame:SetBackdrop(backdrop)
        end
    end

    -- Apply backdrop colors
    if config.bgColor then
        self:ApplyBackdropColors(frame, config.bgColor, config.borderColor)
    end
end

--[[--------------------------------------------------------------------
    Theme Change Callbacks
----------------------------------------------------------------------]]

--- Register a callback for theme changes
-- @param callback function - Function(previousTheme, newTheme)
-- @param owner any - Owner object for the callback (must not be nil)
function ThemeManagerMixin:RegisterThemeCallback(callback, owner)
    if type(callback) ~= "function" then
        error("LoolibThemeManager: RegisterThemeCallback: 'callback' must be a function", 2)
    end
    if owner == nil then
        error("LoolibThemeManager: RegisterThemeCallback: 'owner' must not be nil", 2)
    end
    self.callbacks[owner] = callback
end

--- Unregister a theme change callback
-- @param owner any - Owner object
function ThemeManagerMixin:UnregisterThemeCallback(owner)
    if owner == nil then
        return
    end
    self.callbacks[owner] = nil
end

--- Trigger theme changed callbacks
-- TH-02: Protected against reentrancy (SetTheme inside a callback is a no-op)
-- TH-10: Snapshot callback table before iteration to avoid mutation during pairs()
-- @param previousTheme string - Previous theme name
-- @param newTheme string - New theme name
function ThemeManagerMixin:TriggerThemeChanged(previousTheme, newTheme)
    -- TH-02: Reentrancy guard - prevent infinite recursion from callbacks calling SetActiveTheme
    if self._settingTheme then
        return
    end
    self._settingTheme = true

    -- TH-10: Snapshot callbacks so unregister during iteration is safe
    local snapshot = {}
    for owner, callback in pairs(self.callbacks) do
        snapshot[owner] = callback
    end

    for owner, callback in pairs(snapshot) do
        -- Only fire if still registered (may have been unregistered by a prior callback)
        if self.callbacks[owner] then
            local success, err = pcall(callback, previousTheme, newTheme)
            if not success then
                Loolib:Error("ThemeManager:TriggerThemeChanged - callback error: " .. tostring(err))
            end
        end
    end

    self._settingTheme = false
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Create a color from hex string
-- @param hex string - Hex color string (e.g., "#FF5500" or "FF5500")
-- @param alpha number - Alpha value (0-1, default 1)
-- @return table - Color table {r, g, b, a}
function ThemeManagerMixin:ColorFromHex(hex, alpha)
    -- TH-07: Validate hex input
    if not IsValidHexColor(hex) then
        error("LoolibThemeManager: ColorFromHex: invalid hex color string: " .. tostring(hex), 2)
    end
    if alpha ~= nil and type(alpha) ~= "number" then
        error("LoolibThemeManager: ColorFromHex: 'alpha' must be a number or nil", 2)
    end

    hex = string_gsub(hex, "#", "")

    local r = tonumber(string_sub(hex, 1, 2), 16) / 255
    local g = tonumber(string_sub(hex, 3, 4), 16) / 255
    local b = tonumber(string_sub(hex, 5, 6), 16) / 255

    return {r, g, b, alpha or 1}
end

--- Blend two colors
-- @param color1 table - First color {r, g, b, a}
-- @param color2 table - Second color {r, g, b, a}
-- @param t number - Blend factor (0 = color1, 1 = color2)
-- @return table - Blended color
function ThemeManagerMixin:BlendColors(color1, color2, t)
    -- TH-08: Validate color inputs
    if not IsValidColorTable(color1) then
        error("LoolibThemeManager: BlendColors: 'color1' must be a valid color table {r, g, b[, a]}", 2)
    end
    if not IsValidColorTable(color2) then
        error("LoolibThemeManager: BlendColors: 'color2' must be a valid color table {r, g, b[, a]}", 2)
    end
    if type(t) ~= "number" then
        error("LoolibThemeManager: BlendColors: 't' must be a number", 2)
    end

    t = math_max(0, math_min(1, t))

    return {
        color1[1] + (color2[1] - color1[1]) * t,
        color1[2] + (color2[2] - color1[2]) * t,
        color1[3] + (color2[3] - color1[3]) * t,
        (color1[4] or 1) + ((color2[4] or 1) - (color1[4] or 1)) * t,
    }
end

--- Lighten a color
-- @param color table - Color to lighten
-- @param amount number - Amount to lighten (0-1)
-- @return table - Lightened color
function ThemeManagerMixin:LightenColor(color, amount)
    if not IsValidColorTable(color) then
        error("LoolibThemeManager: LightenColor: 'color' must be a valid color table {r, g, b[, a]}", 2)
    end
    return self:BlendColors(color, {1, 1, 1, color[4] or 1}, amount)
end

--- Darken a color
-- @param color table - Color to darken
-- @param amount number - Amount to darken (0-1)
-- @return table - Darkened color
function ThemeManagerMixin:DarkenColor(color, amount)
    if not IsValidColorTable(color) then
        error("LoolibThemeManager: DarkenColor: 'color' must be a valid color table {r, g, b[, a]}", 2)
    end
    return self:BlendColors(color, {0, 0, 0, color[4] or 1}, amount)
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

local ThemeManager = ThemeManagerModule.Manager or CreateFromMixins(ThemeManagerMixin)
-- TH-09: Init is now idempotent - safe to call on reload
ThemeManager:Init()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

ThemeManagerModule.Mixin = ThemeManagerMixin
ThemeManagerModule.Manager = ThemeManager
ThemeManagerModule.GetValue = function(...) return ThemeManager:GetValue(...) end
ThemeManagerModule.GetColor = function(...) return ThemeManager:GetColor(...) end
ThemeManagerModule.GetFont = function(...) return ThemeManager:GetFont(...) end
ThemeManagerModule.GetBackdrop = function(...) return ThemeManager:GetBackdrop(...) end
ThemeManagerModule.GetSpacing = function(...) return ThemeManager:GetSpacing(...) end
ThemeManagerModule.GetComponentConfig = function(...) return ThemeManager:GetComponentConfig(...) end
ThemeManagerModule.SetActiveTheme = function(...) return ThemeManager:SetActiveTheme(...) end
ThemeManagerModule.RegisterTheme = function(...) return ThemeManager:RegisterTheme(...) end

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.Theme = ThemeManagerModule
UI.ThemeManager = ThemeManager

Theme.Manager = ThemeManagerModule
Loolib.ThemeManagerMixin = ThemeManagerMixin
Loolib.ThemeManager = ThemeManager

Loolib:RegisterModule("Theme.Manager", ThemeManagerModule)
