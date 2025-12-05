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
    "OnReset",
    "OnInitialized",
}

--- Initialize the saved variables manager
-- @param globalName string - The global variable name (must match TOC)
-- @param defaults table - Default values
-- @param useProfiles boolean - Whether to use character profiles
function LoolibSavedVariablesMixin:Init(globalName, defaults, useProfiles)
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SAVED_VARS_EVENTS)

    self.globalName = globalName
    self.defaults = defaults or {}
    self.useProfiles = useProfiles or false
    self.initialized = false
    self.data = nil
    self.currentProfile = nil

    -- Register for ADDON_LOADED
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(_, event, addonName)
        -- We can't know which addon this is for, so we check if our global exists
        if _G[globalName] ~= nil or not self.initialized then
            self:OnAddonLoaded()
        end
    end)

    -- Also try immediate initialization if already loaded
    if _G[globalName] ~= nil then
        self:OnAddonLoaded()
    end
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

    if self.useProfiles then
        self:InitProfiles()
    else
        -- Merge defaults into saved data
        self:MergeDefaults(self.data, self.defaults)
    end

    self.initialized = true
    self:TriggerEvent("OnInitialized")
end

--- Initialize the profile system
function LoolibSavedVariablesMixin:InitProfiles()
    -- Ensure profiles table exists
    self.data.profiles = self.data.profiles or {}
    self.data.currentProfile = self.data.currentProfile or {}

    -- Get character-specific profile key
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local charKey = playerName .. "-" .. realmName

    -- Set current profile
    self.data.currentProfile[charKey] = self.data.currentProfile[charKey] or "Default"
    self.currentProfile = self.data.currentProfile[charKey]

    -- Ensure the profile exists
    self.data.profiles[self.currentProfile] = self.data.profiles[self.currentProfile] or {}

    -- Merge defaults
    self:MergeDefaults(self.data.profiles[self.currentProfile], self.defaults)
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
    Profile Management
----------------------------------------------------------------------]]

--- Get the current profile name
-- @return string
function LoolibSavedVariablesMixin:GetCurrentProfile()
    return self.currentProfile
end

--- Get all profile names
-- @return table - Array of profile names
function LoolibSavedVariablesMixin:GetProfiles()
    if not self.useProfiles then
        return {}
    end

    local profiles = {}
    for name in pairs(self.data.profiles) do
        profiles[#profiles + 1] = name
    end
    table.sort(profiles)
    return profiles
end

--- Switch to a different profile
-- @param profileName string - The profile to switch to
function LoolibSavedVariablesMixin:SetProfile(profileName)
    if not self.useProfiles then
        return
    end

    -- Create profile if it doesn't exist
    if not self.data.profiles[profileName] then
        self.data.profiles[profileName] = {}
        self:MergeDefaults(self.data.profiles[profileName], self.defaults)
    end

    local oldProfile = self.currentProfile
    self.currentProfile = profileName

    -- Update character's profile reference
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local charKey = playerName .. "-" .. realmName
    self.data.currentProfile[charKey] = profileName

    if oldProfile ~= profileName then
        self:TriggerEvent("OnProfileChanged", profileName, oldProfile)
    end
end

--- Copy a profile to a new name
-- @param fromProfile string - Source profile
-- @param toProfile string - Destination profile
function LoolibSavedVariablesMixin:CopyProfile(fromProfile, toProfile)
    if not self.useProfiles then
        return
    end

    local source = self.data.profiles[fromProfile]
    if source then
        self.data.profiles[toProfile] = LoolibTableUtil.DeepCopy(source)
    end
end

--- Delete a profile
-- @param profileName string - The profile to delete
function LoolibSavedVariablesMixin:DeleteProfile(profileName)
    if not self.useProfiles then
        return
    end

    if profileName == "Default" then
        return  -- Don't delete Default profile
    end

    if self.currentProfile == profileName then
        self:SetProfile("Default")
    end

    self.data.profiles[profileName] = nil
end

--[[--------------------------------------------------------------------
    Reset
----------------------------------------------------------------------]]

--- Reset current profile/data to defaults
function LoolibSavedVariablesMixin:Reset()
    local data = self:GetData()
    wipe(data)
    self:MergeDefaults(data, self.defaults)
    self:TriggerEvent("OnReset")
end

--- Reset a specific key to its default
-- @param key string - The key to reset
function LoolibSavedVariablesMixin:ResetKey(key)
    local defaultValue = self:GetNestedValue(self.defaults, key)
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

--- Create a saved variables manager
-- @param globalName string - Global variable name
-- @param defaults table - Default values
-- @param useProfiles boolean - Use character profiles
-- @return table - SavedVariables instance
function CreateLoolibSavedVariables(globalName, defaults, useProfiles)
    local sv = LoolibCreateFromMixins(LoolibSavedVariablesMixin)
    sv:Init(globalName, defaults, useProfiles)
    return sv
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
