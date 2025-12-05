--[[--------------------------------------------------------------------
    Loolib Locale System - AceLocale-3.0 equivalent
    Multilingual support with fallback to default locale
----------------------------------------------------------------------]]

LoolibLocaleMixin = {}

-- Locale registry: locales[application][locale] = locale_table
LoolibLocaleMixin.locales = LoolibLocaleMixin.locales or {}

-- Default locale tracking per application
LoolibLocaleMixin.defaults = LoolibLocaleMixin.defaults or {}

--[[--------------------------------------------------------------------
    Create or get a locale table for an application

    @param application (string): Addon name (e.g., "MyAddon")
    @param locale (string): Locale code (e.g., "enUS", "deDE")
    @param isDefault (boolean): Is this the default/fallback locale?
    @param silent (boolean): Suppress warnings?
    @return (table|nil): Locale table, or nil if not current locale
----------------------------------------------------------------------]]
function LoolibLocaleMixin:NewLocale(application, locale, isDefault, silent)
    assert(type(application) == "string", "Application name must be a string")
    assert(type(locale) == "string", "Locale code must be a string")

    -- Initialize registry for this application
    if not self.locales[application] then
        self.locales[application] = {}
    end

    -- Create or retrieve the locale table
    local localeTable = self.locales[application][locale]
    if not localeTable then
        localeTable = {}
        self.locales[application][locale] = localeTable
    end

    -- Mark as default locale for this application
    if isDefault then
        self.defaults[application] = locale
        -- For default locale, set up __newindex to convert true -> key
        setmetatable(localeTable, {
            __newindex = function(tbl, key, value)
                if value == true then
                    rawset(tbl, key, key)  -- key becomes value
                else
                    rawset(tbl, key, value)
                end
            end
        })
        return localeTable
    end

    -- For non-default locales, check if we should return it
    local gameLocale = GetLocale()

    if locale ~= gameLocale then
        -- Not the current locale, return nil so file can skip loading translations
        return nil
    end

    -- Set up fallback metatable to default locale
    local defaultLocale = self.defaults[application]
    if defaultLocale then
        local defaultTable = self.locales[application][defaultLocale]
        if defaultTable then
            -- Metatable with __index to fall back to default locale
            setmetatable(localeTable, {__index = defaultTable})
        end
    end

    return localeTable
end

--[[--------------------------------------------------------------------
    Get the locale table for the current game locale
    Falls back to default locale if current locale not found

    @param application (string): Addon name
    @param silent (boolean): Suppress warnings if not found?
    @return (table): Locale table for current locale or default
----------------------------------------------------------------------]]
function LoolibLocaleMixin:GetLocale(application, silent)
    assert(type(application) == "string", "Application name must be a string")

    if not self.locales[application] then
        if not silent then
            -- Warn that no locales registered for this application
            print(string.format("|cffff0000[Loolib Locale]|r No locales found for '%s'", application))
        end
        return {}
    end

    local gameLocale = GetLocale()
    local appLocales = self.locales[application]

    -- Try to get locale for current game locale
    if appLocales[gameLocale] then
        return appLocales[gameLocale]
    end

    -- Fall back to default locale
    local defaultLocale = self.defaults[application]
    if defaultLocale and appLocales[defaultLocale] then
        if not silent then
            print(string.format(
                "|cffff0000[Loolib Locale]|r Locale '%s' not found for '%s', using default '%s'",
                gameLocale, application, defaultLocale
            ))
        end
        return appLocales[defaultLocale]
    end

    -- No locale found at all
    if not silent then
        print(string.format("|cffff0000[Loolib Locale]|r No default locale found for '%s'", application))
    end
    return {}
end

--[[--------------------------------------------------------------------
    Get all registered locales for an application

    @param application (string): Addon name
    @return (table): Table of {locale = locale_table, ...}
----------------------------------------------------------------------]]
function LoolibLocaleMixin:GetLocales(application)
    assert(type(application) == "string", "Application name must be a string")
    return self.locales[application] or {}
end

--[[--------------------------------------------------------------------
    Get the default locale for an application

    @param application (string): Addon name
    @return (string): Locale code of default locale, or nil
----------------------------------------------------------------------]]
function LoolibLocaleMixin:GetDefaultLocale(application)
    assert(type(application) == "string", "Application name must be a string")
    return self.defaults[application]
end

-- Register the module
local Loolib = LibStub("Loolib")
Loolib:RegisterModule("Locale", LoolibLocaleMixin)
