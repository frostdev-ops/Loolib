--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    SavedVariables - Manage addon saved variables with defaults

    Provides utilities for working with WoW saved variables including:
    - Default value merging
    - Profile management
    - Automatic value migration
    - Change notifications
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Cache globals at file top
local _G = _G
local CreateFrame = CreateFrame
local GetRealmName = GetRealmName
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local UnitName = UnitName
local UnitRace = UnitRace
local error = error
local ipairs = ipairs
local issecretvalue = issecretvalue
local next = next
local pairs = pairs
local select = select
local setmetatable = setmetatable
local type = type
local sort = table.sort
local format = string.format
local wipe = wipe
local gmatch = string.gmatch

-- INTERNAL: Guard against secret values returned by restricted WoW APIs
local function GuardSecretValue(value, fallback)
    if value == nil then
        return fallback
    end
    if issecretvalue and issecretvalue(value) then
        return fallback
    end
    return value
end

-- INTERNAL: Resolve a required Loolib module or throw
local function GetRequiredModule(name)
    local module = Loolib:GetModule(name)
    if not module then
        error("LoolibSavedVariables: required module '" .. name .. "' not found", 2)
    end
    return module
end

local CallbackRegistryMixin = GetRequiredModule("CallbackRegistry").Mixin
-- FIX(critical-01): Use Loolib.CreateFromMixins directly instead of unstable "Mixin" module lookup
local CreateFromMixins = assert(Loolib.CreateFromMixins, "LoolibSavedVariables: Loolib.CreateFromMixins is required")
local DeepCopy = (Loolib.TableUtil or GetRequiredModule("TableUtil")).DeepCopy

local Data = Loolib.Data or Loolib:GetOrCreateModule("Data")
Loolib.Data = Data

local SavedVariablesModule = Data.SavedVariables or Loolib:GetModule("Data.SavedVariables") or {}
Loolib.Data.SavedVariables = SavedVariablesModule

-- INTERNAL: Ensure all intermediate tables along a key path exist
local function EnsureTablePath(root, path)
    if type(root) ~= "table" then
        error("LoolibSavedVariables: EnsureTablePath root must be a table", 2)
    end
    local current = root
    for _, key in ipairs(path or {}) do
        if type(current[key]) ~= "table" then
            current[key] = {}
        end
        current = current[key]
    end
    return current
end

-- INTERNAL: Traverse a key path and return the leaf value, or nil if any step is missing
local function GetTablePath(root, path)
    if type(root) ~= "table" then
        return nil
    end
    local current = root
    for _, key in ipairs(path or {}) do
        if type(current) ~= "table" then
            return nil
        end
        current = current[key]
        if current == nil then
            return nil
        end
    end
    return current
end

--[[--------------------------------------------------------------------
    LoolibSavedVariablesMixin

    Manages a single saved variable table with defaults and profiles.
----------------------------------------------------------------------]]

local SavedVariablesMixin = SavedVariablesModule.Mixin or CreateFromMixins(CallbackRegistryMixin)
Loolib.Data.SavedVariables.Mixin = SavedVariablesMixin

local SAVED_VARS_EVENTS = {
    "OnValueChanged",
    "OnProfileChanged",
    "OnProfileCopied",
    "OnProfileDeleted",
    "OnProfileReset",
    "OnNewProfile",
    "OnDatabaseShutdown",
    "OnDatabaseReset",
    "OnReset",
    "OnInitialized",
}

--- Initialize the saved variables manager
-- @param globalName string - The global variable name (must match TOC)
-- @param defaults table|nil - Default values with scope keys
-- @param defaultProfile string|nil - Default profile name (default: "Default")
function SavedVariablesMixin:Init(globalName, defaults, defaultProfile)
    if type(globalName) ~= "string" or globalName == "" then
        error("LoolibSavedVariables:Init: globalName must be a non-empty string", 2)
    end
    if defaults ~= nil and type(defaults) ~= "table" then
        error("LoolibSavedVariables:Init: defaults must be a table or nil", 2)
    end
    if defaultProfile ~= nil and type(defaultProfile) ~= "string" then
        error("LoolibSavedVariables:Init: defaultProfile must be a string or nil", 2)
    end

    CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SAVED_VARS_EVENTS)

    self.globalName = globalName
    self.defaults = defaults or {}
    self.defaultProfile = defaultProfile or "Default"
    self.initialized = false
    self.data = nil
    self.currentProfile = nil
    self.namespaces = {}  -- Namespace storage
    self.scopeKeys = {}  -- Cached scope keys
    self.dataPath = self.dataPath or nil
    self.rootData = nil

    -- Register for ADDON_LOADED and PLAYER_LOGOUT
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", function(_, event, _addonName)
        if event == "ADDON_LOADED" then
            -- We can't know which addon this is for, so wait until the saved variable exists.
            if not self.initialized and _G[globalName] ~= nil then
                self:OnAddonLoaded()
                if self.initialized then
                    frame:UnregisterEvent("ADDON_LOADED")
                end
            end
        elseif event == "PLAYER_LOGOUT" then
            self:OnPlayerLogout()
        end
    end)

    -- Also try immediate initialization if already loaded
    if _G[globalName] ~= nil then
        self:OnAddonLoaded()
        if self.initialized then
            frame:UnregisterEvent("ADDON_LOADED")
        end
    end
end

--[[--------------------------------------------------------------------
    Scope Key Generation (cached for performance)
----------------------------------------------------------------------]]

--- Generate scope keys (called once, cached)
function SavedVariablesMixin:GenerateScopeKeys()
    if self.scopeKeys.char then
        return  -- Already generated
    end

    local playerName = GuardSecretValue(UnitName("player"), "Player")
    local realmName = GuardSecretValue(GetRealmName(), "UnknownRealm")
    local className = GuardSecretValue(select(2, UnitClass("player")), "UNKNOWNCLASS")
    local raceName = GuardSecretValue(select(2, UnitRace("player")), "UNKNOWNRACE")
    local factionName = GuardSecretValue(UnitFactionGroup("player"), "Neutral")

    self.scopeKeys.char = playerName .. " - " .. realmName
    self.scopeKeys.realm = realmName
    self.scopeKeys.class = className
    self.scopeKeys.race = raceName
    self.scopeKeys.faction = factionName
    self.scopeKeys.factionrealm = factionName .. " - " .. realmName
end

--- Get scope key for a specific scope
-- @param scope string - The scope name (char, realm, class, race, faction, factionrealm)
-- @return string - The scope key
function SavedVariablesMixin:GetScopeKey(scope)
    self:GenerateScopeKeys()
    return self.scopeKeys[scope]
end

--- Called when the addon loads -- INTERNAL
function SavedVariablesMixin:OnAddonLoaded()
    if self.initialized then
        return
    end

    -- Initialize the saved variable if it doesn't exist
    if _G[self.globalName] == nil then
        _G[self.globalName] = {}
    end

    -- Guard against corrupt (non-table) saved data on disk
    local globalData = _G[self.globalName]
    if type(globalData) ~= "table" then
        Loolib:Error(format("SavedVariables '%s': corrupt data (expected table, got %s), resetting",
            self.globalName, type(globalData)))
        _G[self.globalName] = {}
        globalData = _G[self.globalName]
    end

    self.rootData = globalData
    if self.dataPath and #self.dataPath > 0 then
        self.data = EnsureTablePath(self.rootData, self.dataPath)
    else
        self.data = self.rootData
    end

    -- Generate scope keys
    self:GenerateScopeKeys()

    -- Initialize profile system and scopes
    self:InitProfiles()
    self:InitScopes()

    self.initialized = true
    self:TriggerEvent("OnInitialized")
end

--- Called on player logout (strip defaults to save space) -- INTERNAL
function SavedVariablesMixin:OnPlayerLogout()
    if self.initialized then
        self:RemoveDefaults()
        self:TriggerEvent("OnDatabaseShutdown")
    end
end

--- Initialize the profile system -- INTERNAL
function SavedVariablesMixin:InitProfiles()
    -- Guard against corrupt profiles/profileKeys (non-table) from damaged saved data
    if type(self.data.profiles) ~= "table" then
        self.data.profiles = {}
    end
    if type(self.data.profileKeys) ~= "table" then
        self.data.profileKeys = {}
    end

    -- Get character-specific profile key
    local charKey = self:GetScopeKey("char")

    -- Set current profile (guard against non-string stored key)
    local storedProfile = self.data.profileKeys[charKey]
    if type(storedProfile) ~= "string" or storedProfile == "" then
        storedProfile = self.defaultProfile
        self.data.profileKeys[charKey] = storedProfile
    end
    self.currentProfile = storedProfile

    -- Ensure the profile data is a table
    if type(self.data.profiles[self.currentProfile]) ~= "table" then
        self.data.profiles[self.currentProfile] = {}
    end

    -- Apply defaults via metatable (for automatic fallback)
    if self.defaults.profile then
        self:SetDefaults(self.data.profiles[self.currentProfile], self.defaults.profile)
    end
end

--- Initialize scope tables with defaults -- INTERNAL
function SavedVariablesMixin:InitScopes()
    local scopes = {"char", "realm", "class", "race", "faction", "factionrealm", "global"}

    for _, scope in ipairs(scopes) do
        -- Guard against corrupt scope data (non-table) from damaged saved data
        if type(self.data[scope]) ~= "table" then
            self.data[scope] = {}
        end

        if scope == "global" then
            -- Global scope has no key
            if self.defaults.global then
                self:SetDefaults(self.data.global, self.defaults.global)
            end
        else
            -- Scoped data uses keys
            local scopeKey = self:GetScopeKey(scope)
            if type(self.data[scope][scopeKey]) ~= "table" then
                self.data[scope][scopeKey] = {}
            end

            if self.defaults[scope] then
                self:SetDefaults(self.data[scope][scopeKey], self.defaults[scope])
            end
        end
    end
end

--- Apply defaults using metatable for automatic fallback -- INTERNAL
-- @param target table - Target table
-- @param defaults table - Default values
function SavedVariablesMixin:SetDefaults(target, defaults)
    if not defaults then return end
    if type(target) ~= "table" then return end
    if type(defaults) ~= "table" then return end

    -- Use metatable for automatic fallback to defaults
    setmetatable(target, {
        __index = function(t, key)
            local defaultValue = defaults[key]
            if type(defaultValue) == "table" then
                -- Create a new table with defaults for nested tables
                local newTable = {}
                t[key] = newTable
                self:SetDefaults(newTable, defaultValue)
                return newTable
            end
            return defaultValue
        end
    })
end

--- Merge defaults into a table (non-destructive)
-- @param target table - Target table
-- @param defaults table - Default values
function SavedVariablesMixin:MergeDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then
        return
    end
    for key, defaultValue in pairs(defaults) do
        if target[key] == nil then
            if type(defaultValue) == "table" then
                target[key] = DeepCopy(defaultValue)
            else
                target[key] = defaultValue
            end
        elseif type(defaultValue) == "table" and type(target[key]) == "table" then
            self:MergeDefaults(target[key], defaultValue)
        end
    end
end

--[[--------------------------------------------------------------------
    Scope Access (AceDB-style shortcuts)
----------------------------------------------------------------------]]

--- Get a scope table (char, realm, class, race, faction, factionrealm, global, profile)
-- @param scope string - The scope name
-- @return table - The scope table
function SavedVariablesMixin:GetScope(scope)
    if type(scope) ~= "string" then
        error("LoolibSavedVariables:GetScope: scope must be a string", 2)
    end

    if not self.initialized then
        return self.defaults[scope] or {}
    end

    if scope == "profile" then
        local profileData = self.data.profiles and self.data.profiles[self.currentProfile]
        return type(profileData) == "table" and profileData or {}
    elseif scope == "global" then
        return type(self.data.global) == "table" and self.data.global or {}
    else
        local scopeKey = self:GetScopeKey(scope)
        local scopeTable = self.data[scope]
        if type(scopeTable) ~= "table" then
            return {}
        end
        local scopeData = scopeTable[scopeKey]
        return type(scopeData) == "table" and scopeData or {}
    end
end

--- Create metatable properties for scope access -- INTERNAL
-- This allows: db.char, db.realm, db.profile, etc.
---@diagnostic disable-next-line: unused-function
local function _CreateScopeAccessor(db)
    return setmetatable({}, {
        __index = function(_, key)
            if key == "char" or key == "realm" or key == "class" or
               key == "race" or key == "faction" or key == "factionrealm" or
               key == "global" or key == "profile" then
                return db:GetScope(key)
            end
            return nil
        end
    })
end

--[[--------------------------------------------------------------------
    Namespace Support (AceDB-style isolated namespaces)
----------------------------------------------------------------------]]

--- Register a namespace (isolated data within the database)
-- @param name string - Namespace name
-- @param defaults table|nil - Default values for this namespace
-- @return table - Namespace object (same API as main db)
function SavedVariablesMixin:RegisterNamespace(name, defaults)
    if type(name) ~= "string" or name == "" then
        error("LoolibSavedVariables:RegisterNamespace: name must be a non-empty string", 2)
    end
    if defaults ~= nil and type(defaults) ~= "table" then
        error("LoolibSavedVariables:RegisterNamespace: defaults must be a table or nil", 2)
    end

    if self.namespaces[name] then
        return self.namespaces[name]
    end

    -- Ensure namespace data exists (guard against corrupt stored data)
    if type(self.data.namespaces) ~= "table" then
        self.data.namespaces = {}
    end
    if type(self.data.namespaces[name]) ~= "table" then
        self.data.namespaces[name] = {}
    end

    -- Create namespace object
    local namespace = CreateFromMixins(SavedVariablesMixin)
    namespace.globalName = self.globalName .. "_NS_" .. name
    namespace.defaults = defaults or {}
    namespace.defaultProfile = self.defaultProfile
    namespace.initialized = true
    namespace.data = self.data.namespaces[name]
    namespace.scopeKeys = self.scopeKeys  -- Share scope keys
    namespace.isNamespace = true
    namespace.parentDB = self

    -- Initialize callback registry
    CallbackRegistryMixin.OnLoad(namespace)
    namespace:GenerateCallbackEvents(SAVED_VARS_EVENTS)

    -- Initialize profiles and scopes for namespace
    namespace:InitProfiles()
    namespace:InitScopes()

    self.namespaces[name] = namespace
    return namespace
end

--- Get an existing namespace
-- @param name string - Namespace name
-- @param silent boolean|nil - Don't error if not found
-- @return table|nil - Namespace or nil
function SavedVariablesMixin:GetNamespace(name, silent)
    if type(name) ~= "string" then
        error("LoolibSavedVariables:GetNamespace: name must be a string", 2)
    end
    local namespace = self.namespaces[name]
    if not namespace and not silent then
        error("LoolibSavedVariables: namespace '" .. name .. "' not found. Use RegisterNamespace first.", 2)
    end
    return namespace
end

--[[--------------------------------------------------------------------
    Value Access
----------------------------------------------------------------------]]

--- Get the current data table
-- @return table
function SavedVariablesMixin:GetData()
    if not self.initialized then
        return self.defaults
    end

    if self.useProfiles then
        return self.data.profiles[self.currentProfile]
    end

    return self.data
end

--- Get a value
-- @param key string - The key (supports dot notation for nested values)
-- @param default any - Default value if not found
-- @return any
function SavedVariablesMixin:Get(key, default)
    if type(key) ~= "string" then
        error("LoolibSavedVariables:Get: key must be a string", 2)
    end
    local data = self:GetData()
    return self:GetNestedValue(data, key, default)
end

--- Set a value
-- @param key string - The key (supports dot notation)
-- @param value any - The value to set
function SavedVariablesMixin:Set(key, value)
    if type(key) ~= "string" then
        error("LoolibSavedVariables:Set: key must be a string", 2)
    end
    local data = self:GetData()
    if type(data) ~= "table" then
        return
    end
    local oldValue = self:GetNestedValue(data, key)

    self:SetNestedValue(data, key, value)

    if oldValue ~= value then
        self:TriggerEvent("OnValueChanged", key, value, oldValue)
    end
end

--- Get a nested value using dot notation
-- @param tbl table - The table
-- @param path string - Dot-separated path
-- @param default any - Default if not found
-- @return any
function SavedVariablesMixin:GetNestedValue(tbl, path, default)
    if type(tbl) ~= "table" then
        return default
    end
    if not path or path == "" then
        return tbl
    end
    if type(path) ~= "string" then
        error("LoolibSavedVariables:GetNestedValue: path must be a string", 2)
    end

    local current = tbl
    for part in gmatch(path, "[^.]+") do
        if type(current) ~= "table" then
            return default
        end
        current = current[part]
        if current == nil then
            return default
        end
    end

    return current
end

--- Set a nested value using dot notation
-- @param tbl table - The table
-- @param path string - Dot-separated path
-- @param value any - The value to set
function SavedVariablesMixin:SetNestedValue(tbl, path, value)
    if type(tbl) ~= "table" then
        error("LoolibSavedVariables:SetNestedValue: tbl must be a table", 2)
    end
    if type(path) ~= "string" or path == "" then
        error("LoolibSavedVariables:SetNestedValue: path must be a non-empty string", 2)
    end

    local parts = {}
    for part in gmatch(path, "[^.]+") do
        parts[#parts + 1] = part
    end

    if #parts == 0 then
        return
    end

    local current = tbl
    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(current[part]) ~= "table" then
            current[part] = {}
        end
        current = current[part]
    end

    current[parts[#parts]] = value
end

--- Check if a key exists
-- @param key string - The key
-- @return boolean
function SavedVariablesMixin:Has(key)
    if type(key) ~= "string" then
        error("LoolibSavedVariables:Has: key must be a string", 2)
    end
    local value = self:Get(key)
    return value ~= nil
end

--- Delete a key
-- @param key string - The key to delete
function SavedVariablesMixin:Delete(key)
    if type(key) ~= "string" then
        error("LoolibSavedVariables:Delete: key must be a string", 2)
    end
    self:Set(key, nil)
end

--[[--------------------------------------------------------------------
    Profile Management (Enhanced AceDB-style)
----------------------------------------------------------------------]]

--- Get the current profile name
-- @return string
function SavedVariablesMixin:GetCurrentProfile()
    return self.currentProfile
end

--- Get all profile names
-- @param tbl table - Optional table to fill (if nil, creates new table)
-- @return table - Array of profile names
function SavedVariablesMixin:GetProfiles(tbl)
    tbl = tbl or {}

    for name in pairs(self.data.profiles) do
        tbl[#tbl + 1] = name
    end
    sort(tbl)
    return tbl
end

--- Switch to a different profile
-- @param name string - The profile to switch to (creates if doesn't exist)
function SavedVariablesMixin:SetProfile(name)
    if type(name) ~= "string" or name == "" then
        error("LoolibSavedVariables:SetProfile: name must be a non-empty string", 2)
    end

    local isNewProfile = not self.data.profiles[name]
    local oldProfile = self.currentProfile

    -- Create profile if it doesn't exist
    if isNewProfile then
        self.data.profiles[name] = {}
        if self.defaults.profile then
            self:SetDefaults(self.data.profiles[name], self.defaults.profile)
        end
    end

    self.currentProfile = name

    -- Update character's profile reference
    local charKey = self:GetScopeKey("char")
    self.data.profileKeys[charKey] = name

    -- Fire appropriate callback
    if oldProfile ~= name then
        if isNewProfile then
            self:TriggerEvent("OnNewProfile", name)
        end
        self:TriggerEvent("OnProfileChanged", name, oldProfile)
    end
end

--- Copy data from another profile to current profile
-- @param sourceName string - Name of profile to copy from
-- @param silent boolean|nil - Suppress errors if source doesn't exist
function SavedVariablesMixin:CopyProfile(sourceName, silent)
    if type(sourceName) ~= "string" then
        error("LoolibSavedVariables:CopyProfile: sourceName must be a string", 2)
    end

    local source = self.data.profiles[sourceName]

    if not source then
        if not silent then
            error("LoolibSavedVariables:CopyProfile: source profile '" .. sourceName .. "' does not exist", 2)
        end
        return
    end

    -- Deep copy source to current profile
    local currentProfileData = self.data.profiles[self.currentProfile]
    wipe(currentProfileData)

    for key, value in pairs(source) do
        if type(value) == "table" then
            currentProfileData[key] = DeepCopy(value)
        else
            currentProfileData[key] = value
        end
    end

    -- Reapply defaults metatable
    if self.defaults.profile then
        self:SetDefaults(currentProfileData, self.defaults.profile)
    end

    self:TriggerEvent("OnProfileCopied", sourceName)
end

--- Delete a profile
-- @param name string - The profile to delete
-- @param silent boolean|nil - Suppress errors
-- @return boolean - Success
function SavedVariablesMixin:DeleteProfile(name, silent)
    if type(name) ~= "string" then
        error("LoolibSavedVariables:DeleteProfile: name must be a string", 2)
    end

    -- Don't delete default profile
    if name == self.defaultProfile then
        if not silent then
            error("LoolibSavedVariables:DeleteProfile: cannot delete the default profile", 2)
        end
        return false
    end

    -- Don't delete current profile
    if self.currentProfile == name then
        if not silent then
            error("LoolibSavedVariables:DeleteProfile: cannot delete the current profile. Switch profiles first.", 2)
        end
        return false
    end

    -- Check if profile exists
    if not self.data.profiles[name] then
        if not silent then
            error("LoolibSavedVariables:DeleteProfile: profile '" .. name .. "' does not exist", 2)
        end
        return false
    end

    -- Don't delete last profile
    local profileCount = 0
    for _ in pairs(self.data.profiles) do
        profileCount = profileCount + 1
    end

    if profileCount <= 1 then
        if not silent then
            error("LoolibSavedVariables:DeleteProfile: cannot delete the last profile", 2)
        end
        return false
    end

    self.data.profiles[name] = nil
    self:TriggerEvent("OnProfileDeleted", name)
    return true
end

--- Reset current profile to defaults
function SavedVariablesMixin:ResetProfile()
    local currentProfileData = self.data.profiles[self.currentProfile]
    if type(currentProfileData) ~= "table" then
        currentProfileData = {}
        self.data.profiles[self.currentProfile] = currentProfileData
    end
    wipe(currentProfileData)

    if self.defaults.profile then
        self:SetDefaults(currentProfileData, self.defaults.profile)
    end

    self:TriggerEvent("OnProfileReset")
end

--[[--------------------------------------------------------------------
    Reset and Database Management
----------------------------------------------------------------------]]

--- Reset entire database (all profiles and scopes) to defaults
function SavedVariablesMixin:ResetDB()
    -- Wipe all data
    for key in pairs(self.data) do
        self.data[key] = nil
    end

    -- Reinitialize
    self:InitProfiles()
    self:InitScopes()

    self:TriggerEvent("OnDatabaseReset")
end

--- Reset current profile/data to defaults (legacy compatibility)
function SavedVariablesMixin:Reset()
    self:ResetProfile()
    self:TriggerEvent("OnReset")
end

--- Reset a specific key to its default
-- @param key string - The key to reset
function SavedVariablesMixin:ResetKey(key)
    if type(key) ~= "string" then
        error("LoolibSavedVariables:ResetKey: key must be a string", 2)
    end
    local defaultValue = self:GetNestedValue(self.defaults.profile or self.defaults, key)
    if defaultValue ~= nil then
        if type(defaultValue) == "table" then
            self:Set(key, DeepCopy(defaultValue))
        else
            self:Set(key, defaultValue)
        end
    else
        self:Delete(key)
    end
end

--[[--------------------------------------------------------------------
    Default Stripping (called on PLAYER_LOGOUT to save space)
----------------------------------------------------------------------]]

--- Deep-compare two values for equality (tables compared recursively) -- INTERNAL
-- @param a any
-- @param b any
-- @return boolean
local function DeepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not DeepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

--- Remove values that match defaults (recursive) -- INTERNAL
-- Arrays (tables with a numeric key [1]) are compared atomically to prevent
-- individual element stripping that creates sparse tables on reload.
-- @param saved table - Saved data table
-- @param defaults table - Default values
-- @return boolean - True if table is empty after stripping
local function RemoveDefaultsRecursive(saved, defaults)
    if type(saved) ~= "table" or type(defaults) ~= "table" then
        return false
    end

    local keysToRemove = {}

    for key, savedValue in pairs(saved) do
        local defaultValue = defaults[key]

        if defaultValue ~= nil then
            if type(savedValue) == "table" and type(defaultValue) == "table" then
                -- Arrays (numeric key 1 present): compare as atomic values
                if savedValue[1] ~= nil or defaultValue[1] ~= nil then
                    if DeepEqual(savedValue, defaultValue) then
                        keysToRemove[#keysToRemove + 1] = key
                    end
                else
                    -- Non-array tables: recursively process
                    if RemoveDefaultsRecursive(savedValue, defaultValue) then
                        keysToRemove[#keysToRemove + 1] = key
                    end
                end
            elseif savedValue == defaultValue then
                -- Value matches default, remove it
                keysToRemove[#keysToRemove + 1] = key
            end
        end
    end

    -- Remove keys that match defaults
    for _, key in ipairs(keysToRemove) do
        saved[key] = nil
    end

    -- Check if table is now empty
    return next(saved) == nil
end

--- Remove all default values from saved data to reduce file size
function SavedVariablesMixin:RemoveDefaults()
    if not self.initialized then
        return
    end

    -- Strip defaults from all profiles
    if self.defaults.profile then
        for _, profileData in pairs(self.data.profiles) do
            RemoveDefaultsRecursive(profileData, self.defaults.profile)
        end
    end

    -- Strip defaults from all scopes
    local scopes = {"char", "realm", "class", "race", "faction", "factionrealm", "global"}
    for _, scope in ipairs(scopes) do
        if self.defaults[scope] then
            if scope == "global" then
                RemoveDefaultsRecursive(self.data.global, self.defaults.global)
            elseif self.data[scope] then
                for _, scopeData in pairs(self.data[scope]) do
                    RemoveDefaultsRecursive(scopeData, self.defaults[scope])
                end
            end
        end
    end

    -- Strip defaults from namespaces
    for _, namespace in pairs(self.namespaces) do
        namespace:RemoveDefaults()
    end
end

--[[--------------------------------------------------------------------
    Utility
----------------------------------------------------------------------]]

--- Check if initialized
-- @return boolean
function SavedVariablesMixin:IsInitialized()
    return self.initialized
end

--- Register a callback for when initialized
-- @param callback function - Callback function
-- @param owner any - Owner for the callback
function SavedVariablesMixin:OnReady(callback, owner)
    if type(callback) ~= "function" then
        error("LoolibSavedVariables:OnReady: callback must be a function", 2)
    end
    if self.initialized then
        callback()
    else
        self:RegisterCallback("OnInitialized", callback, owner)
    end
end

--- Export current data as a string (for sharing)
-- @return string
function SavedVariablesMixin:Export()
    local data = self:GetData()
    local serializerModule = Loolib:GetModule("Serializer")
    local serializer = serializerModule and serializerModule.Serializer
    if serializer then
        return serializer:Serialize(data)
    end
    return ""
end

--- Import data from a string
-- @param str string - Serialized data
-- @return boolean - Success
function SavedVariablesMixin:Import(str)
    if type(str) ~= "string" or str == "" then
        error("LoolibSavedVariables:Import: str must be a non-empty string", 2)
    end

    local serializerModule = Loolib:GetModule("Serializer")
    local serializer = serializerModule and serializerModule.Serializer
    if not serializer then
        return false
    end

    local success, imported = serializer:Deserialize(str)
    if success and type(imported) == "table" then
        local data = self:GetData()
        if type(data) ~= "table" then
            return false
        end
        wipe(data)
        for k, v in pairs(imported) do
            data[k] = v
        end
        self:MergeDefaults(data, self.defaults)
        return true
    end
    return false
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a saved variables manager (AceDB-style)
-- @param globalName string - Global variable name
-- @param defaults table|nil - Default values (with scope keys: profile, global, char, etc.)
-- @param defaultProfile string|nil - Default profile name (default: "Default")
-- @return table - SavedVariables instance with scope accessors
local function CreateSavedVariables(globalName, defaults, defaultProfile)
    if type(globalName) ~= "string" or globalName == "" then
        error("LoolibSavedVariables.Create: globalName must be a non-empty string", 2)
    end
    if defaults ~= nil and type(defaults) ~= "table" then
        error("LoolibSavedVariables.Create: defaults must be a table or nil", 2)
    end

    local sv = CreateFromMixins(SavedVariablesMixin)
    sv:Init(globalName, defaults, defaultProfile)

    -- Create scope accessor metatable
    -- This allows: db.profile, db.char, db.global, etc.
    local accessor = setmetatable({}, {
        __index = function(_, key)
            -- Check for scope access
            if key == "char" or key == "realm" or key == "class" or
               key == "race" or key == "faction" or key == "factionrealm" or
               key == "global" or key == "profile" then
                return sv:GetScope(key)
            end
            -- Otherwise, access the sv object itself
            return sv[key]
        end,
        __newindex = function(_, key, value)
            sv[key] = value
        end
    })

    return accessor
end

local function CreateSavedVariablesAtPath(globalName, dataPath, defaults, defaultProfile)
    if type(globalName) ~= "string" or globalName == "" then
        error("LoolibSavedVariables.CreateAtPath: globalName must be a non-empty string", 2)
    end
    if dataPath ~= nil and type(dataPath) ~= "table" then
        error("LoolibSavedVariables.CreateAtPath: dataPath must be a table or nil", 2)
    end

    local sv = CreateFromMixins(SavedVariablesMixin)
    sv.dataPath = dataPath
    sv:Init(globalName, defaults, defaultProfile)

    local accessor = setmetatable({}, {
        __index = function(_, key)
            if key == "char" or key == "realm" or key == "class" or
               key == "race" or key == "faction" or key == "factionrealm" or
               key == "global" or key == "profile" then
                return sv:GetScope(key)
            end
            return sv[key]
        end,
        __newindex = function(_, key, value)
            sv[key] = value
        end
    })

    return accessor
end

-- INTERNAL: Get or create a global storage table
local function GetGlobalStorageRoot(globalName, create)
    if type(globalName) ~= "string" or globalName == "" then
        error("LoolibSavedVariables.GetRootData: globalName must be a non-empty string", 2)
    end
    local root = _G[globalName]
    -- Guard against corrupt (non-table) global data
    if root ~= nil and type(root) ~= "table" then
        if create then
            root = {}
            _G[globalName] = root
        else
            return nil
        end
    end
    if root == nil and create then
        root = {}
        _G[globalName] = root
    end
    return root
end

-- INTERNAL: Get or create an addon-specific data root under LoolibDB
local function GetAddonDataRoot(addonName, create)
    if type(addonName) ~= "string" or addonName == "" then
        error("Loolib.Data.SavedVariables.GetAddonData: addonName must be a non-empty string", 2)
    end

    local root = GetGlobalStorageRoot("LoolibDB", create)
    if not root then
        return nil
    end

    if create then
        return EnsureTablePath(root, { "addons", addonName })
    end

    local addons = GetTablePath(root, { "addons" })
    if type(addons) ~= "table" then
        return nil
    end

    return addons[addonName]
end

local function CreateAddonStore(addonName, defaults, defaultProfile)
    if type(addonName) ~= "string" or addonName == "" then
        error("Loolib.Data.SavedVariables.CreateAddonStore: addonName must be a non-empty string", 2)
    end

    return CreateSavedVariablesAtPath("LoolibDB", { "addons", addonName }, defaults, defaultProfile)
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib.Data.SavedVariables.Mixin = SavedVariablesMixin
Loolib.Data.SavedVariables.Create = CreateSavedVariables
Loolib.Data.SavedVariables.CreateAtPath = CreateSavedVariablesAtPath
Loolib.Data.SavedVariables.CreateAddonStore = CreateAddonStore
Loolib.Data.SavedVariables.GetRootData = GetGlobalStorageRoot
Loolib.Data.SavedVariables.GetAddonData = GetAddonDataRoot
Loolib.Data.SavedVariables = SavedVariablesModule
Loolib.Data.CreateSavedVariables = CreateSavedVariables
Loolib.Data.CreateAddonStore = CreateAddonStore

Loolib:RegisterModule("Data.SavedVariables", SavedVariablesModule)
