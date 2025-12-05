--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ProfileManager - UI helper utilities for profile management

    Provides convenience methods for building profile selection UIs,
    creating/deleting profiles, and handling profile operations with
    validation and safety checks.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibProfileManagerMixin

    Helper utilities for profile UI management. This is separate from
    the SavedVariables storage logic and provides higher-level
    operations for common UI patterns.
----------------------------------------------------------------------]]

LoolibProfileManagerMixin = {}

--[[--------------------------------------------------------------------
    Profile List Generation
----------------------------------------------------------------------]]

--- Get a formatted profile list for dropdowns
-- @param db table - SavedVariables database
-- @return table - Array of {text, value} tables suitable for dropdown menus
function LoolibProfileManagerMixin:GetProfileList(db)
    if not db then
        return {}
    end

    local profiles = db:GetProfiles()
    local currentProfile = db:GetCurrentProfile()
    local list = {}

    for _, name in ipairs(profiles) do
        local entry = {
            text = name,
            value = name,
            checked = (name == currentProfile),
        }
        list[#list + 1] = entry
    end

    return list
end

--- Get profile list with additional metadata
-- @param db table - SavedVariables database
-- @return table - Array of profile info tables with name, isCurrent, isDefault
function LoolibProfileManagerMixin:GetProfileListDetailed(db)
    if not db then
        return {}
    end

    local profiles = db:GetProfiles()
    local currentProfile = db:GetCurrentProfile()
    local defaultProfile = db.defaultProfile or "Default"
    local list = {}

    for _, name in ipairs(profiles) do
        local entry = {
            name = name,
            isCurrent = (name == currentProfile),
            isDefault = (name == defaultProfile),
            canDelete = (name ~= defaultProfile and name ~= currentProfile),
        }
        list[#list + 1] = entry
    end

    return list
end

--[[--------------------------------------------------------------------
    Profile Creation
----------------------------------------------------------------------]]

--- Create a new profile with validation
-- @param db table - SavedVariables database
-- @param name string - Profile name
-- @return boolean - Success
-- @return string - Error message (if failed)
function LoolibProfileManagerMixin:CreateProfile(db, name)
    if not db then
        return false, "Database not provided"
    end

    if not name or name == "" then
        return false, "Profile name cannot be empty"
    end

    -- Trim whitespace
    name = strtrim(name)

    if name == "" then
        return false, "Profile name cannot be empty"
    end

    -- Check for invalid characters
    if name:match("[<>:\"/\\|?*]") then
        return false, "Profile name contains invalid characters"
    end

    -- Check if profile already exists
    local profiles = db:GetProfiles()
    for _, existingName in ipairs(profiles) do
        if existingName == name then
            return false, "Profile '" .. name .. "' already exists"
        end
    end

    -- Create the profile by switching to it
    local success, err = pcall(function()
        db:SetProfile(name)
    end)

    if not success then
        return false, "Failed to create profile: " .. tostring(err)
    end

    return true
end

--[[--------------------------------------------------------------------
    Profile Deletion
----------------------------------------------------------------------]]

--- Delete a profile with safety checks
-- @param db table - SavedVariables database
-- @param name string - Profile name
-- @return boolean - Success
-- @return string - Error message (if failed)
function LoolibProfileManagerMixin:DeleteProfile(db, name)
    if not db then
        return false, "Database not provided"
    end

    if not name or name == "" then
        return false, "Profile name cannot be empty"
    end

    -- Safety checks
    local currentProfile = db:GetCurrentProfile()
    if name == currentProfile then
        return false, "Cannot delete the current profile. Switch profiles first."
    end

    local defaultProfile = db.defaultProfile or "Default"
    if name == defaultProfile then
        return false, "Cannot delete the default profile"
    end

    -- Check if profile exists
    local profiles = db:GetProfiles()
    local exists = false
    for _, profileName in ipairs(profiles) do
        if profileName == name then
            exists = true
            break
        end
    end

    if not exists then
        return false, "Profile '" .. name .. "' does not exist"
    end

    -- Don't delete last profile
    if #profiles <= 1 then
        return false, "Cannot delete the last profile"
    end

    -- Delete the profile
    local success, err = pcall(function()
        db:DeleteProfile(name, false)
    end)

    if not success then
        return false, "Failed to delete profile: " .. tostring(err)
    end

    return true
end

--[[--------------------------------------------------------------------
    Profile Copying
----------------------------------------------------------------------]]

--- Copy a profile with validation
-- @param db table - SavedVariables database
-- @param sourceName string - Source profile name
-- @param destName string - Destination profile name (nil to copy to current)
-- @return boolean - Success
-- @return string - Error message (if failed)
function LoolibProfileManagerMixin:CopyProfile(db, sourceName, destName)
    if not db then
        return false, "Database not provided"
    end

    if not sourceName or sourceName == "" then
        return false, "Source profile name cannot be empty"
    end

    -- Check if source exists
    local profiles = db:GetProfiles()
    local sourceExists = false
    for _, name in ipairs(profiles) do
        if name == sourceName then
            sourceExists = true
            break
        end
    end

    if not sourceExists then
        return false, "Source profile '" .. sourceName .. "' does not exist"
    end

    -- If destName provided, create new profile first
    if destName then
        destName = strtrim(destName)

        if destName == "" then
            return false, "Destination profile name cannot be empty"
        end

        -- Check for invalid characters
        if destName:match("[<>:\"/\\|?*]") then
            return false, "Profile name contains invalid characters"
        end

        -- Check if already exists
        for _, name in ipairs(profiles) do
            if name == destName then
                return false, "Profile '" .. destName .. "' already exists"
            end
        end

        -- Create new profile first
        local success, err = pcall(function()
            db:SetProfile(destName)
        end)

        if not success then
            return false, "Failed to create destination profile: " .. tostring(err)
        end
    end

    -- Copy from source to current
    local success, err = pcall(function()
        db:CopyProfile(sourceName, false)
    end)

    if not success then
        return false, "Failed to copy profile: " .. tostring(err)
    end

    return true
end

--[[--------------------------------------------------------------------
    Character Profile Information
----------------------------------------------------------------------]]

--- Get profiles associated with current character/realm/class
-- @param db table - SavedVariables database
-- @return table - Table with character, realm, class profile info
function LoolibProfileManagerMixin:GetCharacterProfiles(db)
    if not db then
        return {}
    end

    local info = {
        character = db:GetCurrentProfile(),
        characterKey = db:GetScopeKey("char"),
        realm = db:GetScopeKey("realm"),
        class = db:GetScopeKey("class"),
        race = db:GetScopeKey("race"),
        faction = db:GetScopeKey("faction"),
    }

    return info
end

--- Get all characters using a specific profile
-- @param db table - SavedVariables database
-- @param profileName string - Profile name to search for
-- @return table - Array of character keys using this profile
function LoolibProfileManagerMixin:GetCharactersUsingProfile(db, profileName)
    if not db or not profileName then
        return {}
    end

    local characters = {}
    local profileKeys = db.data.profileKeys or {}

    for charKey, profile in pairs(profileKeys) do
        if profile == profileName then
            characters[#characters + 1] = charKey
        end
    end

    return characters
end

--[[--------------------------------------------------------------------
    Profile Reset
----------------------------------------------------------------------]]

--- Reset a profile to defaults with confirmation
-- @param db table - SavedVariables database
-- @param profileName string - Profile name (nil for current)
-- @return boolean - Success
-- @return string - Error message (if failed)
function LoolibProfileManagerMixin:ResetProfile(db, profileName)
    if not db then
        return false, "Database not provided"
    end

    if profileName then
        -- Switch to the profile first
        local currentProfile = db:GetCurrentProfile()
        if currentProfile ~= profileName then
            local success, err = pcall(function()
                db:SetProfile(profileName)
            end)

            if not success then
                return false, "Failed to switch to profile: " .. tostring(err)
            end
        end
    end

    -- Reset current profile
    local success, err = pcall(function()
        db:ResetProfile()
    end)

    if not success then
        return false, "Failed to reset profile: " .. tostring(err)
    end

    return true
end

--[[--------------------------------------------------------------------
    Validation Utilities
----------------------------------------------------------------------]]

--- Validate a profile name
-- @param name string - Profile name to validate
-- @return boolean - Valid
-- @return string - Error message (if invalid)
function LoolibProfileManagerMixin:ValidateProfileName(name)
    if not name or name == "" then
        return false, "Profile name cannot be empty"
    end

    name = strtrim(name)

    if name == "" then
        return false, "Profile name cannot be empty"
    end

    if #name > 48 then
        return false, "Profile name too long (max 48 characters)"
    end

    if name:match("[<>:\"/\\|?*]") then
        return false, "Profile name contains invalid characters"
    end

    return true
end

--- Check if a profile can be deleted
-- @param db table - SavedVariables database
-- @param name string - Profile name
-- @return boolean - Can delete
-- @return string - Reason (if cannot delete)
function LoolibProfileManagerMixin:CanDeleteProfile(db, name)
    if not db or not name then
        return false, "Invalid parameters"
    end

    local currentProfile = db:GetCurrentProfile()
    if name == currentProfile then
        return false, "Cannot delete current profile"
    end

    local defaultProfile = db.defaultProfile or "Default"
    if name == defaultProfile then
        return false, "Cannot delete default profile"
    end

    local profiles = db:GetProfiles()
    if #profiles <= 1 then
        return false, "Cannot delete last profile"
    end

    return true
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local ProfileManagerModule = {
    Mixin = LoolibProfileManagerMixin,
}

-- Register in Data module
local Data = Loolib:GetOrCreateModule("Data")
Data.ProfileManager = ProfileManagerModule

Loolib:RegisterModule("ProfileManager", ProfileManagerModule)
