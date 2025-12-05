--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ThemeManager - Centralized theme management system

    Provides theme registration, switching, and value retrieval.
    Widgets query the theme manager for styling values.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibThemeManagerMixin

    Singleton mixin that manages theme registration and retrieval.
----------------------------------------------------------------------]]

LoolibThemeManagerMixin = {}

--- Initialize the theme manager
function LoolibThemeManagerMixin:Init()
    self.themes = {}
    self.activeThemeName = nil
    self.activeTheme = nil
    self.callbacks = {}
end

--[[--------------------------------------------------------------------
    Theme Registration
----------------------------------------------------------------------]]

--- Register a theme
-- @param name string - Unique theme name
-- @param theme table - Theme data table
function LoolibThemeManagerMixin:RegisterTheme(name, theme)
    if not name or not theme then
        Loolib:Error("ThemeManager:RegisterTheme - name and theme are required")
        return
    end

    self.themes[name] = theme

    -- Set as active if this is the first theme
    if not self.activeTheme then
        self:SetActiveTheme(name)
    end
end

--- Unregister a theme
-- @param name string - Theme name to unregister
function LoolibThemeManagerMixin:UnregisterTheme(name)
    if self.activeThemeName == name then
        Loolib:Error("ThemeManager:UnregisterTheme - cannot unregister active theme")
        return
    end

    self.themes[name] = nil
end

--- Check if a theme is registered
-- @param name string - Theme name
-- @return boolean
function LoolibThemeManagerMixin:HasTheme(name)
    return self.themes[name] ~= nil
end

--- Get all registered theme names
-- @return table - Array of theme names
function LoolibThemeManagerMixin:GetThemeNames()
    local names = {}
    for name in pairs(self.themes) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

--[[--------------------------------------------------------------------
    Active Theme
----------------------------------------------------------------------]]

--- Set the active theme
-- @param name string - Theme name to activate
function LoolibThemeManagerMixin:SetActiveTheme(name)
    local theme = self.themes[name]
    if not theme then
        Loolib:Error("ThemeManager:SetActiveTheme - theme not found: " .. tostring(name))
        return
    end

    local previousTheme = self.activeThemeName
    self.activeThemeName = name
    self.activeTheme = theme

    -- Notify listeners
    self:TriggerThemeChanged(previousTheme, name)
end

--- Get the active theme
-- @return table - The active theme table
function LoolibThemeManagerMixin:GetActiveTheme()
    return self.activeTheme
end

--- Get the active theme name
-- @return string - The active theme name
function LoolibThemeManagerMixin:GetActiveThemeName()
    return self.activeThemeName
end

--- Get a specific theme by name
-- @param name string - Theme name
-- @return table|nil - The theme table or nil
function LoolibThemeManagerMixin:GetTheme(name)
    return self.themes[name]
end

--[[--------------------------------------------------------------------
    Theme Value Retrieval
----------------------------------------------------------------------]]

--- Get a value from the active theme
-- @param category string - Value category (e.g., "colors", "fonts")
-- @param key string - Value key within category
-- @param fallback any - Fallback value if not found
-- @return any - The theme value
function LoolibThemeManagerMixin:GetValue(category, key, fallback)
    if not self.activeTheme then
        return fallback
    end

    local categoryTable = self.activeTheme[category]
    if not categoryTable then
        return fallback
    end

    local value = categoryTable[key]
    if value == nil then
        return fallback
    end

    return value
end

--- Get a color from the active theme
-- @param colorName string - Color name
-- @param fallback table - Fallback color {r, g, b, a}
-- @return table - Color table {r, g, b, a}
function LoolibThemeManagerMixin:GetColor(colorName, fallback)
    return self:GetValue("colors", colorName, fallback or {1, 1, 1, 1})
end

--- Get a font from the active theme
-- @param fontName string - Font name
-- @param fallback string - Fallback font object name
-- @return string - Font object name
function LoolibThemeManagerMixin:GetFont(fontName, fallback)
    return self:GetValue("fonts", fontName, fallback or "GameFontNormal")
end

--- Get a backdrop from the active theme
-- @param backdropName string - Backdrop name
-- @param fallback table - Fallback backdrop table
-- @return table - Backdrop table
function LoolibThemeManagerMixin:GetBackdrop(backdropName, fallback)
    return self:GetValue("backdrops", backdropName, fallback)
end

--- Get a spacing value from the active theme
-- @param spacingName string - Spacing name
-- @param fallback number - Fallback spacing value
-- @return number - Spacing value
function LoolibThemeManagerMixin:GetSpacing(spacingName, fallback)
    return self:GetValue("spacing", spacingName, fallback or 8)
end

--- Get component configuration from the active theme
-- @param componentName string - Component name (e.g., "Button", "EditBox")
-- @param fallback table - Fallback configuration
-- @return table - Component configuration
function LoolibThemeManagerMixin:GetComponentConfig(componentName, fallback)
    return self:GetValue("components", componentName, fallback or {})
end

--- Get a nested value using dot notation
-- @param path string - Dot-separated path (e.g., "colors.accent")
-- @param fallback any - Fallback value
-- @return any - The value at the path
function LoolibThemeManagerMixin:GetPath(path, fallback)
    if not self.activeTheme then
        return fallback
    end

    local current = self.activeTheme
    for part in string.gmatch(path, "[^.]+") do
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
-- @param frame Frame - The frame with backdrop
-- @param bgColor string - Background color name
-- @param borderColor string - Border color name
function LoolibThemeManagerMixin:ApplyBackdropColors(frame, bgColor, borderColor)
    if not frame.SetBackdropColor then
        return
    end

    if bgColor then
        local bg = self:GetColor(bgColor)
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    end

    if borderColor then
        local border = self:GetColor(borderColor)
        frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    end
end

--- Apply theme font to a font string
-- @param fontString FontString - The font string
-- @param fontName string - Font name from theme
function LoolibThemeManagerMixin:ApplyFont(fontString, fontName)
    local font = self:GetFont(fontName)
    if font then
        fontString:SetFontObject(font)
    end
end

--- Apply theme text color to a font string
-- @param fontString FontString - The font string
-- @param colorName string - Color name from theme
function LoolibThemeManagerMixin:ApplyTextColor(fontString, colorName)
    local color = self:GetColor(colorName)
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

--- Apply full theme styling to a frame based on component type
-- @param frame Frame - The frame to style
-- @param componentType string - Component type (e.g., "Button", "Panel")
function LoolibThemeManagerMixin:ApplyComponentStyle(frame, componentType)
    local config = self:GetComponentConfig(componentType)
    if not config then
        return
    end

    -- Apply size if specified
    if config.width then
        frame:SetWidth(config.width)
    end
    if config.height then
        frame:SetHeight(config.height)
    end

    -- Apply backdrop if frame supports it
    if frame.SetBackdrop and config.backdrop then
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
-- @param owner any - Owner object for the callback
function LoolibThemeManagerMixin:RegisterThemeCallback(callback, owner)
    self.callbacks[owner] = callback
end

--- Unregister a theme change callback
-- @param owner any - Owner object
function LoolibThemeManagerMixin:UnregisterThemeCallback(owner)
    self.callbacks[owner] = nil
end

--- Trigger theme changed callbacks
-- @param previousTheme string - Previous theme name
-- @param newTheme string - New theme name
function LoolibThemeManagerMixin:TriggerThemeChanged(previousTheme, newTheme)
    for owner, callback in pairs(self.callbacks) do
        local success, err = pcall(callback, previousTheme, newTheme)
        if not success then
            Loolib:Error("ThemeManager:TriggerThemeChanged - callback error: " .. tostring(err))
        end
    end
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Create a color from hex string
-- @param hex string - Hex color string (e.g., "#FF5500" or "FF5500")
-- @param alpha number - Alpha value (0-1, default 1)
-- @return table - Color table {r, g, b, a}
function LoolibThemeManagerMixin:ColorFromHex(hex, alpha)
    hex = hex:gsub("#", "")

    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255

    return {r, g, b, alpha or 1}
end

--- Blend two colors
-- @param color1 table - First color {r, g, b, a}
-- @param color2 table - Second color {r, g, b, a}
-- @param t number - Blend factor (0 = color1, 1 = color2)
-- @return table - Blended color
function LoolibThemeManagerMixin:BlendColors(color1, color2, t)
    t = math.max(0, math.min(1, t))

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
function LoolibThemeManagerMixin:LightenColor(color, amount)
    return self:BlendColors(color, {1, 1, 1, color[4] or 1}, amount)
end

--- Darken a color
-- @param color table - Color to darken
-- @param amount number - Amount to darken (0-1)
-- @return table - Darkened color
function LoolibThemeManagerMixin:DarkenColor(color, amount)
    return self:BlendColors(color, {0, 0, 0, color[4] or 1}, amount)
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

LoolibThemeManager = LoolibCreateFromMixins(LoolibThemeManagerMixin)
LoolibThemeManager:Init()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local ThemeModule = {
    Mixin = LoolibThemeManagerMixin,
    Manager = LoolibThemeManager,

    -- Convenience functions
    GetValue = function(...) return LoolibThemeManager:GetValue(...) end,
    GetColor = function(...) return LoolibThemeManager:GetColor(...) end,
    GetFont = function(...) return LoolibThemeManager:GetFont(...) end,
    GetBackdrop = function(...) return LoolibThemeManager:GetBackdrop(...) end,
    GetSpacing = function(...) return LoolibThemeManager:GetSpacing(...) end,
    GetComponentConfig = function(...) return LoolibThemeManager:GetComponentConfig(...) end,
    SetActiveTheme = function(...) return LoolibThemeManager:SetActiveTheme(...) end,
    RegisterTheme = function(...) return LoolibThemeManager:RegisterTheme(...) end,
}

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.Theme = ThemeModule
UI.ThemeManager = LoolibThemeManager

Loolib:RegisterModule("Theme", ThemeModule)
