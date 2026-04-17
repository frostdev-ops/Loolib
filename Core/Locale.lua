local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Loolib Locale System - AceLocale-3.0 equivalent
    Multilingual support with fallback to default locale
----------------------------------------------------------------------]]

-- Local references to globals
local type = type
local pairs = pairs
local assert = assert
local print = print
local rawset = rawset
local setmetatable = setmetatable
local string_format = string.format

local LocaleMixin = Loolib.Locale or Loolib:GetModule("Locale") or {}

-- Locale registry: locales[application][locale] = locale_table
LocaleMixin.locales = LocaleMixin.locales or {}

-- Default locale tracking per application
LocaleMixin.defaults = LocaleMixin.defaults or {}

-- Per-application locale overrides (set before locale files load)
LocaleMixin.overrides = LocaleMixin.overrides or {}

-- Shared fallback table for GetLocale's no-locale / no-default paths.
-- __index echoes the key back as a string so L["FOO"] returns "FOO" rather
-- than nil, preventing string.format(L[...]) crashes when an application
-- hasn't registered any locale (or its default locale).
-- __newindex silently rejects writes to prevent a caller from mutating the
-- fallback table's shared state (e.g. `L["X"] = "Y"` after GetLocale returned
-- the fallback instead of a real locale table — that would leak a key into
-- every subsequent caller that receives the same shared table).
local emptyFallback = setmetatable({}, {
    __index = function(_, key) return key end,
    __newindex = function(_, _, _) end,
})

--- Get the effective locale for an application (override or game locale)
-- @param application string|nil - Addon name, or nil for global
-- @return string - Locale code
local function GetEffectiveLocale(self, application)
    if application and self.overrides[application] then
        return self.overrides[application]
    end
    if self.overrides["*"] then
        return self.overrides["*"]
    end
    return GetLocale()
end

--[[--------------------------------------------------------------------
    Create or get a locale table for an application

    @param application (string): Addon name (e.g., "MyAddon")
    @param locale (string): Locale code (e.g., "enUS", "deDE")
    @param isDefault (boolean): Is this the default/fallback locale?
    @param silent (boolean): Suppress warnings?
    @return (table|nil): Locale table, or nil if not current locale
----------------------------------------------------------------------]]
function LocaleMixin:NewLocale(application, locale, isDefault, _silent)
    if type(application) ~= "string" or application == "" then
        error("LoolibLocale: NewLocale() application must be a non-empty string", 2)
    end
    if type(locale) ~= "string" or locale == "" then
        error("LoolibLocale: NewLocale() locale must be a non-empty string", 2)
    end

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
    local effectiveLocale = GetEffectiveLocale(self, application)

    if locale ~= effectiveLocale then
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
function LocaleMixin:GetLocale(application, silent)
    if type(application) ~= "string" or application == "" then
        error("LoolibLocale: GetLocale() application must be a non-empty string", 2)
    end

    if not self.locales[application] then
        if not silent then
            -- Warn that no locales registered for this application
            print(string_format("|cffff0000[Loolib Locale]|r No locales found for '%s'", application))
        end
        return emptyFallback
    end

    local effectiveLocale = GetEffectiveLocale(self, application)
    local appLocales = self.locales[application]

    -- Try to get locale for effective locale (override or game locale)
    if appLocales[effectiveLocale] then
        return appLocales[effectiveLocale]
    end

    -- Fall back to default locale
    local defaultLocale = self.defaults[application]
    if defaultLocale and appLocales[defaultLocale] then
        if not silent then
            print(string_format(
                "|cffff0000[Loolib Locale]|r Locale '%s' not found for '%s', using default '%s'",
                effectiveLocale, application, defaultLocale
            ))
        end
        return appLocales[defaultLocale]
    end

    -- No locale found at all
    if not silent then
        print(string_format("|cffff0000[Loolib Locale]|r No default locale found for '%s'", application))
    end
    return emptyFallback
end

--[[--------------------------------------------------------------------
    Get all registered locales for an application

    @param application (string): Addon name
    @return (table): Table of {locale = locale_table, ...}
----------------------------------------------------------------------]]
function LocaleMixin:GetLocales(application)
    if type(application) ~= "string" or application == "" then
        error("LoolibLocale: GetLocales() application must be a non-empty string", 2)
    end
    return self.locales[application] or {}
end

--[[--------------------------------------------------------------------
    Get the default locale for an application

    @param application (string): Addon name
    @return (string): Locale code of default locale, or nil
----------------------------------------------------------------------]]
function LocaleMixin:GetDefaultLocale(application)
    if type(application) ~= "string" or application == "" then
        error("LoolibLocale: GetDefaultLocale() application must be a non-empty string", 2)
    end
    return self.defaults[application]
end

--[[--------------------------------------------------------------------
    Set a locale override for an application.
    Must be called BEFORE locale files load (e.g., in Bootstrap.lua).
    Use "*" as application to override all applications.

    @param application (string): Addon name or "*" for global
    @param locale (string|nil): Locale code, or nil to clear
----------------------------------------------------------------------]]
function LocaleMixin:SetLocaleOverride(application, locale)
    if type(application) ~= "string" or application == "" then
        error("LoolibLocale: SetLocaleOverride() application must be a non-empty string", 2)
    end
    self.overrides[application] = locale
end

--[[--------------------------------------------------------------------
    Get the current locale override for an application.

    @param application (string): Addon name or "*"
    @return (string|nil): Override locale code, or nil if none
----------------------------------------------------------------------]]
function LocaleMixin:GetLocaleOverride(application)
    if type(application) ~= "string" or application == "" then
        error("LoolibLocale: GetLocaleOverride() application must be a non-empty string", 2)
    end
    return self.overrides[application]
end

--[[--------------------------------------------------------------------
    Get the effective locale for an application (override → game locale).

    @param application (string): Addon name
    @return (string): Effective locale code
----------------------------------------------------------------------]]
function LocaleMixin:GetEffectiveLocale(application)
    return GetEffectiveLocale(self, application)
end

Loolib.Locale = LocaleMixin
Loolib:RegisterModule("Locale", LocaleMixin)
