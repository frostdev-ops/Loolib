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

--[[--------------------------------------------------------------------
    LoolibSavedVariablesMixin

    Manages a single saved variable table with defaults and profiles.
----------------------------------------------------------------------]]

LoolibSavedVariablesMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

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
-- @param defaults table - Default values with scope keys
-- @param defaultProfile string - Default profile name (default: "Default")
function LoolibSavedVariablesMixin:Init(globalName, defaults, defaultProfile)
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SAVED_VARS_EVENTS)

    self.globalName = globalName
    self.defaults = defaults or {}
    self.defaultProfile = defaultProfile or "Default"
    self.initialized = false
    self.data = nil
    self.currentProfile = nil
    self.namespaces = {}  -- Namespace storage
    self.scopeKeys = {}  -- Cached scope keys

    -- Register for ADDON_LOADED and PLAYER_LOGOUT
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", function(_, event, addonName)
        if event == "ADDON_LOADED" then
            -- We can't know which addon this is for, so we check if our global exists
            if _G[globalName] ~= nil or not self.initialized then
                self:OnAddonLoaded()
            end
        elseif event == "PLAYER_LOGOUT" then
            self:OnPlayerLogout()
        end
    end)

    -- Also try immediate initialization if already loaded
    if _G[globalName] ~= nil then
        self:OnAddonLoaded()
    end
end

--[[--------------------------------------------------------------------
    Scope Key Generation (cached for performance)
----------------------------------------------------------------------]]

--- Generate scope keys (called once, cached)
function LoolibSavedVariablesMixin:GenerateScopeKeys()
    if self.scopeKeys.char then
        return  -- Already generated
    end

    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local className = select(2, UnitClass("player"))  -- Returns "WARRIOR", "MAGE", etc.
    local raceName = select(2, UnitRace("player"))    -- Returns "Human", "Orc", etc.
    local factionName = UnitFactionGroup("player")    -- Returns "Alliance" or "Horde"

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
function LoolibSavedVariablesMixin:GetScopeKey(scope)
    self:GenerateScopeKeys()
    return self.scopeKeys[scope]
end

--- Called when the addon loads
function LoolibSavedVariablesMixin:OnAddonLoaded()
    if self.initialized then
        return
    end

    -- Initialize the saved variable if it doesn't exist
    if _G[self.globalName] == nil then
        _G[self.globalName] = {}
    end

    self.data = _G[self.globalName]

    -- Generate scope keys
    self:GenerateScopeKeys()

    -- Initialize profile system and scopes
    self:InitProfiles()
    self:InitScopes()

    self.initialized = true
    self:TriggerEvent("OnInitialized")
end

--- Called on player logout (strip defaults to save space)
function LoolibSavedVariablesMixin:OnPlayerLogout()
    if self.initialized then
        self:RemoveDefaults()
        self:TriggerEvent("OnDatabaseShutdown")
    end
end

--- Initialize the profile system
function LoolibSavedVariablesMixin:InitProfiles()
    -- Ensure profiles table exists
    self.data.profiles = self.data.profiles or {}
    self.data.profileKeys = self.data.profileKeys or {}

    -- Get character-specific profile key
    local charKey = self:GetScopeKey("char")

    -- Set current profile
    self.data.profileKeys[charKey] = self.data.profileKeys[charKey] or self.defaultProfile
    self.currentProfile = self.data.profileKeys[charKey]

    -- Ensure the profile exists
    self.data.profiles[self.currentProfile] = self.data.profiles[self.currentProfile] or {}

    -- Apply defaults via metatable (for automatic fallback)
    if self.defaults.profile then
        self:SetDefaults(self.data.profiles[self.currentProfile], self.defaults.profile)
    end
end

--- Initialize scope tables with defaults
function LoolibSavedVariablesMixin:InitScopes()
    local scopes = {"char", "realm", "class", "race", "faction", "factionrealm", "global"}

    for _, scope in ipairs(scopes) do
        -- Ensure scope table exists
        self.data[scope] = self.data[scope] or {}

        if scope == "global" then
            -- Global scope has no key
            if self.defaults.global then
                self:SetDefaults(self.data.global, self.defaults.global)
            end
        else
            -- Scoped data uses keys
            local scopeKey = self:GetScopeKey(scope)
            self.data[scope][scopeKey] = self.data[scope][scopeKey] or {}

            if self.defaults[scope] then
                self:SetDefaults(self.data[scope][scopeKey], self.defaults[scope])
            end
        end
    end
end

--- Apply defaults using metatable for automatic fallback
-- @param target table - Target table
-- @param defaults table - Default values
function LoolibSavedVariablesMixin:SetDefaults(target, defaults)
    if not defaults then return end

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
function LoolibSavedVariablesMixin:MergeDefaults(target, defaults)
    for key, defaultValue in pairs(defaults) do
        if target[key] == nil then
            if type(defaultValue) == "table" then
                target[key] = LoolibTableUtil.DeepCopy(defaultValue)
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
function LoolibSavedVariablesMixin:GetScope(scope)
    if not self.initialized then
        return self.defaults[scope] or {}
    end

    if scope == "profile" then
        return self.data.profiles[self.currentProfile]
    elseif scope == "global" then
        return self.data.global
    else
        local scopeKey = self:GetScopeKey(scope)
        return self.data[scope] and self.data[scope][scopeKey] or {}
    end
end

--- Create metatable properties for scope access
-- This allows: db.char, db.realm, db.profile, etc.
local function CreateScopeAccessor(db)
    return setmetatable({}, {
        __index = function(t, key)
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
-- @param defaults table - Default values for this namespace
-- @return table - Namespace object (same API as main db)
function LoolibSavedVariablesMixin:RegisterNamespace(name, defaults)
    if self.namespaces[name] then
        return self.namespaces[name]
    end

    -- Ensure namespace data exists
    self.data.namespaces = self.data.namespaces or {}
    self.data.namespaces[name] = self.data.namespaces[name] or {}

    -- Create namespace object
    local namespace = LoolibCreateFromMixins(LoolibSavedVariablesMixin)
    namespace.globalName = self.globalName .. "_NS_" .. name
    namespace.defaults = defaults or {}
    namespace.defaultProfile = self.defaultProfile
    namespace.initialized = true
    namespace.data = self.data.namespaces[name]
    namespace.scopeKeys = self.scopeKeys  -- Share scope keys
    namespace.isNamespace = true
    namespace.parentDB = self

    -- Initialize callback registry
    LoolibCallbackRegistryMixin.OnLoad(namespace)
    namespace:GenerateCallbackEvents(SAVED_VARS_EVENTS)

    -- Initialize profiles and scopes for namespace
    namespace:InitProfiles()
    namespace:InitScopes()

    self.namespaces[name] = namespace
    return namespace
end

--- Get an existing namespace
-- @param name string - Namespace name
-- @param silent boolean - Don't error if not found
-- @return table - Namespace or nil
function LoolibSavedVariablesMixin:GetNamespace(name, silent)
    local namespace = self.namespaces[name]
    if not namespace and not silent then
        error("Namespace '" .. name .. "' not found. Use RegisterNamespace first.", 2)
    end
    return namespace
end

--[[--------------------------------------------------------------------
    Value Access
----------------------------------------------------------------------]]

--- Get the current data table
-- @return table
function LoolibSavedVariablesMixin:GetData()
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
function LoolibSavedVariablesMixin:Get(key, default)
    local data = self:GetData()
    return self:GetNestedValue(data, key, default)
end

--- Set a value
-- @param key string - The key (supports dot notation)
-- @param value any - The value to set
function LoolibSavedVariablesMixin:Set(key, value)
    local data = self:GetData()
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
function LoolibSavedVariablesMixin:GetNestedValue(tbl, path, default)
    if not path or path == "" then
        return tbl
    end

    local current = tbl
    for part in string.gmatch(path, "[^.]+") do
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
function LoolibSavedVariablesMixin:SetNestedValue(tbl, path, value)
    local parts = {}
    for part in string.gmatch(path, "[^.]+") do
        parts[#parts + 1] = part
    end

    local current = tbl
    for i = 1, #parts - 1 do
        local part = parts[i]
        if current[part] == nil then
            current[part] = {}
        end
        current = current[part]
    end

    current[parts[#parts]] = value
end

--- Check if a key exists
-- @param key string - The key
-- @return boolean
function LoolibSavedVariablesMixin:Has(key)
    local value = self:Get(key)
    return value ~= nil
end

--- Delete a key
-- @param key string - The key to delete
function LoolibSavedVariablesMixin:Delete(key)
    self:Set(key, nil)
end

--[[--------------------------------------------------------------------
    Profile Management (Enhanced AceDB-style)
----------------------------------------------------------------------]]

--- Get the current profile name
-- @return string
function LoolibSavedVariablesMixin:GetCurrentProfile()
    return self.currentProfile
end

--- Get all profile names
-- @param tbl table - Optional table to fill (if nil, creates new table)
-- @return table - Array of profile names
function LoolibSavedVariablesMixin:GetProfiles(tbl)
    tbl = tbl or {}

    for name in pairs(self.data.profiles) do
        tbl[#tbl + 1] = name
    end
    table.sort(tbl)
    return tbl
end

--- Switch to a different profile
-- @param name string - The profile to switch to (creates if doesn't exist)
function LoolibSavedVariablesMixin:SetProfile(name)
    if not name or name == "" then
        error("Profile name cannot be empty", 2)
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
-- @param silent boolean - Suppress errors if source doesn't exist
function LoolibSavedVariablesMixin:CopyProfile(sourceName, silent)
    local source = self.data.profiles[sourceName]

    if not source then
        if not silent then
            error("Source profile '" .. sourceName .. "' does not exist", 2)
        end
        return
    end

    -- Deep copy source to current profile
    local currentProfileData = self.data.profiles[self.currentProfile]
    wipe(currentProfileData)

    for key, value in pairs(source) do
        if type(value) == "table" then
            currentProfileData[key] = LoolibTableUtil.DeepCopy(value)
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
-- @param silent boolean - Suppress errors
-- @return boolean - Success
function LoolibSavedVariablesMixin:DeleteProfile(name, silent)
    -- Don't delete default profile
    if name == self.defaultProfile then
        if not silent then
            error("Cannot delete the default profile", 2)
        end
        return false
    end

    -- Don't delete current profile
    if self.currentProfile == name then
        if not silent then
            error("Cannot delete the current profile. Switch profiles first.", 2)
        end
        return false
    end

    -- Check if profile exists
    if not self.data.profiles[name] then
        if not silent then
            error("Profile '" .. name .. "' does not exist", 2)
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
            error("Cannot delete the last profile", 2)
        end
        return false
    end

    self.data.profiles[name] = nil
    self:TriggerEvent("OnProfileDeleted", name)
    return true
end

--- Reset current profile to defaults
function LoolibSavedVariablesMixin:ResetProfile()
    local currentProfileData = self.data.profiles[self.currentProfile]
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
function LoolibSavedVariablesMixin:ResetDB()
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
function LoolibSavedVariablesMixin:Reset()
    self:ResetProfile()
    self:TriggerEvent("OnReset")
end

--- Reset a specific key to its default
-- @param key string - The key to reset
function LoolibSavedVariablesMixin:ResetKey(key)
    local defaultValue = self:GetNestedValue(self.defaults.profile or self.defaults, key)
    if defaultValue ~= nil then
        if type(defaultValue) == "table" then
            self:Set(key, LoolibTableUtil.DeepCopy(defaultValue))
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

--- Remove values that match defaults (recursive)
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
                -- Recursively process nested tables
                if RemoveDefaultsRecursive(savedValue, defaultValue) then
                    keysToRemove[#keysToRemove + 1] = key
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
function LoolibSavedVariablesMixin:RemoveDefaults()
    if not self.initialized then
        return
    end

    -- Strip defaults from all profiles
    if self.defaults.profile then
        for profileName, profileData in pairs(self.data.profiles) do
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
                for scopeKey, scopeData in pairs(self.data[scope]) do
                    RemoveDefaultsRecursive(scopeData, self.defaults[scope])
                end
            end
        end
    end

    -- Strip defaults from namespaces
    for name, namespace in pairs(self.namespaces) do
        namespace:RemoveDefaults()
    end
end

--[[--------------------------------------------------------------------
    Utility
----------------------------------------------------------------------]]

--- Check if initialized
-- @return boolean
function LoolibSavedVariablesMixin:IsInitialized()
    return self.initialized
end

--- Register a callback for when initialized
-- @param callback function - Callback function
-- @param owner any - Owner for the callback
function LoolibSavedVariablesMixin:OnReady(callback, owner)
    if self.initialized then
        callback()
    else
        self:RegisterCallback("OnInitialized", callback, owner)
    end
end

--- Export current data as a string (for sharing)
-- @return string
function LoolibSavedVariablesMixin:Export()
    local data = self:GetData()
    -- Simple serialization - could be enhanced
    return LoolibTableUtil.Serialize and LoolibTableUtil.Serialize(data) or ""
end

--- Import data from a string
-- @param str string - Serialized data
-- @return boolean - Success
function LoolibSavedVariablesMixin:Import(str)
    if not LoolibTableUtil.Deserialize then
        return false
    end

    local success, imported = pcall(LoolibTableUtil.Deserialize, str)
    if success and type(imported) == "table" then
        local data = self:GetData()
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
-- @param defaults table - Default values (with scope keys: profile, global, char, etc.)
-- @param defaultProfile string - Default profile name (default: "Default")
-- @return table - SavedVariables instance with scope accessors
function CreateLoolibSavedVariables(globalName, defaults, defaultProfile)
    local sv = LoolibCreateFromMixins(LoolibSavedVariablesMixin)
    sv:Init(globalName, defaults, defaultProfile)

    -- Create scope accessor metatable
    -- This allows: db.profile, db.char, db.global, etc.
    local accessor = setmetatable({}, {
        __index = function(t, key)
            -- Check for scope access
            if key == "char" or key == "realm" or key == "class" or
               key == "race" or key == "faction" or key == "factionrealm" or
               key == "global" or key == "profile" then
                return sv:GetScope(key)
            end
            -- Otherwise, access the sv object itself
            return sv[key]
        end,
        __newindex = function(t, key, value)
            sv[key] = value
        end
    })

    return accessor
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local SavedVariablesModule = {
    Mixin = LoolibSavedVariablesMixin,
    Create = CreateLoolibSavedVariables,
}

-- Register in Data module
local Data = Loolib:GetOrCreateModule("Data")
Data.SavedVariables = SavedVariablesModule
Data.CreateSavedVariables = CreateLoolibSavedVariables

Loolib:RegisterModule("SavedVariables", SavedVariablesModule)
