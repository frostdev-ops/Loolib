--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ProfileManager - UI helper utilities for profile management

    Provides convenience methods for building profile selection UIs,
    creating/deleting profiles, and handling profile operations with
    validation and safety checks.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local bit = bit
local ChatFontNormal = ChatFontNormal
local CreateFrame = CreateFrame
local UIParent = UIParent
local error = error
local format = string.format
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local print = print
local strtrim = strtrim
local tostring = tostring
local type = type
local wipe = wipe
local concat = table.concat
local char = string.char

local function GetRequiredModule(name)
    local module = Loolib:GetModule(name)
    if not module then
        error("Loolib module '" .. name .. "' is required", 2)
    end
    return module
end

local DeepCopy = GetRequiredModule("TableUtil").DeepCopy

local Data = Loolib.Data or Loolib:GetOrCreateModule("Data")
Loolib.Data = Data

local ProfileManagerModule = Data.ProfileManager or Loolib:GetModule("Data.ProfileManager") or {}
Loolib.Data.ProfileManager = ProfileManagerModule

-- INTERNAL: Maximum number of auto-generated import name attempts before giving up
local MAX_IMPORT_NAME_ATTEMPTS = 1000

--[[--------------------------------------------------------------------
    LoolibProfileManagerMixin

    Helper utilities for profile UI management. This is separate from
    the SavedVariables storage logic and provides higher-level
    operations for common UI patterns.
----------------------------------------------------------------------]]

local ProfileManagerMixin = ProfileManagerModule.Mixin or {}
Loolib.Data.ProfileManager.Mixin = ProfileManagerMixin

--[[--------------------------------------------------------------------
    Profile List Generation
----------------------------------------------------------------------]]

--- Get a formatted profile list for dropdowns
-- @param db table - SavedVariables database
-- @return table - Array of {text, value} tables suitable for dropdown menus
function ProfileManagerMixin:GetProfileList(db)
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
function ProfileManagerMixin:GetProfileListDetailed(db)
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
function ProfileManagerMixin:CreateProfile(db, name)
    if not db then
        return false, "Database not provided"
    end

    if type(name) ~= "string" then
        return false, "Profile name must be a string"
    end

    -- Trim whitespace
    name = strtrim(name)

    -- Use centralized validation
    local valid, validErr = self:ValidateProfileName(name)
    if not valid then
        return false, validErr
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
function ProfileManagerMixin:DeleteProfile(db, name)
    if not db then
        return false, "Database not provided"
    end

    if type(name) ~= "string" or name == "" then
        return false, "Profile name must be a non-empty string"
    end

    -- Use centralized deletion check
    local canDelete, reason = self:CanDeleteProfile(db, name)
    if not canDelete then
        return false, reason
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
function ProfileManagerMixin:CopyProfile(db, sourceName, destName)
    if not db then
        return false, "Database not provided"
    end

    if type(sourceName) ~= "string" or sourceName == "" then
        return false, "Source profile name must be a non-empty string"
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
        if type(destName) ~= "string" then
            return false, "Destination profile name must be a string"
        end

        destName = strtrim(destName)

        -- Use centralized validation
        local valid, validErr = self:ValidateProfileName(destName)
        if not valid then
            return false, validErr
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
function ProfileManagerMixin:GetCharacterProfiles(db)
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
function ProfileManagerMixin:GetCharactersUsingProfile(db, profileName)
    if not db or not profileName then
        return {}
    end

    if type(profileName) ~= "string" or profileName == "" then
        return {}
    end

    local characters = {}

    -- Access profileKeys safely through the db's data table
    local dataTable = db.data
    if type(dataTable) ~= "table" then
        return {}
    end

    local profileKeys = dataTable.profileKeys
    if type(profileKeys) ~= "table" then
        return {}
    end

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
function ProfileManagerMixin:ResetProfile(db, profileName)
    if not db then
        return false, "Database not provided"
    end

    if profileName ~= nil and (type(profileName) ~= "string" or profileName == "") then
        return false, "Profile name must be a non-empty string or nil"
    end

    local originalProfile = db:GetCurrentProfile()
    local switched = false

    if profileName and originalProfile ~= profileName then
        -- Switch to the profile first
        local switchOk, switchErr = pcall(function()
            db:SetProfile(profileName)
        end)

        if not switchOk then
            return false, "Failed to switch to profile: " .. tostring(switchErr)
        end
        switched = true
    end

    -- Reset current profile
    local success, err = pcall(function()
        db:ResetProfile()
    end)

    -- Switch back if we changed profiles, regardless of reset success
    if switched then
        pcall(function()
            db:SetProfile(originalProfile)
        end)
    end

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
function ProfileManagerMixin:ValidateProfileName(name)
    if type(name) ~= "string" or name == "" then
        return false, "Profile name must be a non-empty string"
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
function ProfileManagerMixin:CanDeleteProfile(db, name)
    if not db then
        return false, "Database not provided"
    end

    if type(name) ~= "string" or name == "" then
        return false, "Profile name must be a non-empty string"
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
    Profile Export/Import
----------------------------------------------------------------------]]

--- Export a profile to an encoded string
-- @param db table - SavedVariables database
-- @param profileName string - Profile name (nil for current)
-- @return string - Base64 encoded profile data
-- @return string - Error message (if failed)
function ProfileManagerMixin:ExportProfile(db, profileName)
    if not db then
        return nil, "Database not provided"
    end

    profileName = profileName or db:GetCurrentProfile()

    if type(profileName) ~= "string" or profileName == "" then
        return nil, "Profile name must be a non-empty string"
    end

    -- Check if profile exists
    local profiles = db:GetProfiles()
    local exists = false
    for _, name in ipairs(profiles) do
        if name == profileName then
            exists = true
            break
        end
    end

    if not exists then
        return nil, "Profile '" .. profileName .. "' does not exist"
    end

    -- Get profile data safely
    local dataTable = db.data
    if type(dataTable) ~= "table" or type(dataTable.profiles) ~= "table" then
        return nil, "Profile data not accessible"
    end

    local profileData = dataTable.profiles[profileName]
    if not profileData then
        return nil, "Profile data not found"
    end

    -- Get Serializer module
    local SerializerModule = Loolib:GetModule("Serializer")
    if not SerializerModule or not SerializerModule.Serializer then
        return nil, "Serializer module not available"
    end

    local Serializer = SerializerModule.Serializer

    -- Serialize the profile data
    local serialized = Serializer:Serialize(profileData)
    if not serialized or serialized == "" then
        return nil, "Failed to serialize profile data"
    end

    -- Get Compressor module (optional)
    local CompressorModule = Loolib:GetModule("Compressor")
    local encoded

    if CompressorModule and CompressorModule.Compressor then
        local Compressor = CompressorModule.Compressor

        -- Compress the serialized data
        local compressed = Compressor:Compress(serialized, 6)

        -- Base64 encode for safe text sharing
        encoded = Compressor:EncodeForPrint(compressed)

        -- Add prefix to indicate compression
        encoded = "C:" .. encoded
    else
        -- No compressor available, just base64 encode the serialized data
        -- Use a simple base64 implementation
        encoded = "S:" .. self:Base64Encode(serialized)
    end

    -- Fire event
    if db.TriggerEvent then
        db:TriggerEvent("OnProfileExported", profileName)
    end

    return encoded
end

--- Import a profile from an encoded string
-- @param db table - SavedVariables database
-- @param encodedString string - Base64 encoded profile data
-- @param targetProfileName string - Target profile name (nil to auto-generate)
-- @return boolean - Success
-- @return string - Error message or profile name
function ProfileManagerMixin:ImportProfile(db, encodedString, targetProfileName)
    if not db then
        return false, "Database not provided"
    end

    if type(encodedString) ~= "string" or encodedString == "" then
        return false, "Import string must be a non-empty string"
    end

    -- Remove whitespace
    encodedString = encodedString:gsub("%s", "")

    -- Determine format (C: = compressed, S: = serialized only)
    local importFormat = encodedString:sub(1, 2)
    local data = encodedString:sub(3)

    if importFormat ~= "C:" and importFormat ~= "S:" then
        return false, "Invalid import format. Expected 'C:' or 'S:' prefix."
    end

    local serialized

    if importFormat == "C:" then
        -- Compressed format
        local CompressorModule = Loolib:GetModule("Compressor")
        if not CompressorModule or not CompressorModule.Compressor then
            return false, "Compressor module not available for decompression"
        end

        local Compressor = CompressorModule.Compressor

        -- Base64 decode
        local compressed = Compressor:DecodeForPrint(data)
        if not compressed then
            return false, "Failed to decode base64 data"
        end

        -- Decompress
        local decompressed, decompressOk = Compressor:Decompress(compressed)
        if not decompressOk or not decompressed then
            return false, "Failed to decompress data"
        end

        serialized = decompressed
    else
        -- Serialized-only format
        serialized = self:Base64Decode(data)
        if not serialized then
            return false, "Failed to decode base64 data"
        end
    end

    -- Get Serializer module
    local SerializerModule = Loolib:GetModule("Serializer")
    if not SerializerModule or not SerializerModule.Serializer then
        return false, "Serializer module not available"
    end

    local Serializer = SerializerModule.Serializer

    -- Deserialize the data
    local deserializeOk, profileData = Serializer:Deserialize(serialized)
    if not deserializeOk then
        return false, "Failed to deserialize profile data: " .. tostring(profileData)
    end

    -- Validate the structure
    if type(profileData) ~= "table" then
        return false, "Invalid profile data structure"
    end

    -- Generate target profile name if not provided
    if not targetProfileName or targetProfileName == "" then
        local baseName = "Imported"
        local profiles = db:GetProfiles()
        local existingNames = {}
        for _, name in ipairs(profiles) do
            existingNames[name] = true
        end

        if not existingNames[baseName] then
            targetProfileName = baseName
        else
            local counter = 1
            while existingNames[baseName .. " " .. counter] and counter <= MAX_IMPORT_NAME_ATTEMPTS do
                counter = counter + 1
            end
            if counter > MAX_IMPORT_NAME_ATTEMPTS then
                return false, "Could not generate a unique profile name after " .. MAX_IMPORT_NAME_ATTEMPTS .. " attempts"
            end
            targetProfileName = baseName .. " " .. counter
        end
    else
        if type(targetProfileName) ~= "string" then
            return false, "Target profile name must be a string"
        end
        -- Validate provided name
        local valid, validErr = self:ValidateProfileName(targetProfileName)
        if not valid then
            return false, validErr
        end
    end

    -- Create the new profile
    local createSuccess, createErr = pcall(function()
        db:SetProfile(targetProfileName)
    end)

    if not createSuccess then
        return false, "Failed to create profile: " .. tostring(createErr)
    end

    -- Copy imported data to the new profile safely
    local dataTable = db.data
    if type(dataTable) ~= "table" or type(dataTable.profiles) ~= "table" then
        return false, "Profile data not accessible after creation"
    end

    local currentProfileData = dataTable.profiles[targetProfileName]
    if not currentProfileData then
        return false, "Failed to access created profile data"
    end

    wipe(currentProfileData)

    for key, value in pairs(profileData) do
        if type(value) == "table" then
            currentProfileData[key] = DeepCopy(value)
        else
            currentProfileData[key] = value
        end
    end

    -- Fire event
    if db.TriggerEvent then
        db:TriggerEvent("OnProfileImported", targetProfileName)
    end

    return true, targetProfileName
end

--[[--------------------------------------------------------------------
    Base64 Encoding (fallback when Compressor not available)
----------------------------------------------------------------------]]

local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_DECODE = {}
for i = 1, #BASE64_CHARS do
    BASE64_DECODE[BASE64_CHARS:sub(i, i)] = i - 1
end

-- INTERNAL: Encode a string to base64
-- @param data string - Data to encode
-- @return string - Base64 encoded string
function ProfileManagerMixin:Base64Encode(data)
    if type(data) ~= "string" then
        error("LoolibProfileManager: Base64Encode expects a string", 2)
    end

    local result = {}
    local len = #data

    for i = 1, len, 3 do
        local b1 = data:byte(i)
        local b2 = data:byte(i + 1) or 0
        local b3 = data:byte(i + 2) or 0

        local n = bit.bor(bit.lshift(b1, 16), bit.lshift(b2, 8), b3)

        result[#result + 1] = BASE64_CHARS:sub(bit.rshift(n, 18) + 1, bit.rshift(n, 18) + 1)
        result[#result + 1] = BASE64_CHARS:sub(bit.band(bit.rshift(n, 12), 0x3F) + 1, bit.band(bit.rshift(n, 12), 0x3F) + 1)

        if i + 1 <= len then
            result[#result + 1] = BASE64_CHARS:sub(bit.band(bit.rshift(n, 6), 0x3F) + 1, bit.band(bit.rshift(n, 6), 0x3F) + 1)
        else
            result[#result + 1] = "="
        end

        if i + 2 <= len then
            result[#result + 1] = BASE64_CHARS:sub(bit.band(n, 0x3F) + 1, bit.band(n, 0x3F) + 1)
        else
            result[#result + 1] = "="
        end
    end

    return concat(result)
end

-- INTERNAL: Decode a base64 string
-- @param data string - Base64 encoded string
-- @return string - Decoded data
function ProfileManagerMixin:Base64Decode(data)
    if type(data) ~= "string" then
        error("LoolibProfileManager: Base64Decode expects a string", 2)
    end

    -- Remove whitespace and padding
    data = data:gsub("%s", ""):gsub("=", "")

    local result = {}
    local len = #data

    for i = 1, len, 4 do
        local c1 = BASE64_DECODE[data:sub(i, i)] or 0
        local c2 = BASE64_DECODE[data:sub(i + 1, i + 1)] or 0
        local c3 = BASE64_DECODE[data:sub(i + 2, i + 2)]
        local c4 = BASE64_DECODE[data:sub(i + 3, i + 3)]

        local n = bit.bor(bit.lshift(c1, 18), bit.lshift(c2, 12))

        if c3 then
            n = bit.bor(n, bit.lshift(c3, 6))
        end
        if c4 then
            n = bit.bor(n, c4)
        end

        result[#result + 1] = char(bit.band(bit.rshift(n, 16), 0xFF))

        if c3 then
            result[#result + 1] = char(bit.band(bit.rshift(n, 8), 0xFF))
        end
        if c4 then
            result[#result + 1] = char(bit.band(n, 0xFF))
        end
    end

    return concat(result)
end

--[[--------------------------------------------------------------------
    Enhanced Profile Operations
----------------------------------------------------------------------]]

--- Deep copy source profile to target profile
-- @param db table - SavedVariables database
-- @param sourceProfile string - Source profile name
-- @param targetProfile string - Target profile name
-- @return boolean - Success
-- @return string - Error message (if failed)
function ProfileManagerMixin:CopyProfileTo(db, sourceProfile, targetProfile)
    if not db then
        return false, "Database not provided"
    end

    if type(sourceProfile) ~= "string" or sourceProfile == "" then
        return false, "Source profile name must be a non-empty string"
    end

    if type(targetProfile) ~= "string" or targetProfile == "" then
        return false, "Target profile name must be a non-empty string"
    end

    -- Validate target name
    local valid, validErr = self:ValidateProfileName(targetProfile)
    if not valid then
        return false, validErr
    end

    -- Check if source exists
    local profiles = db:GetProfiles()
    local sourceExists = false
    local targetExists = false

    for _, name in ipairs(profiles) do
        if name == sourceProfile then
            sourceExists = true
        end
        if name == targetProfile then
            targetExists = true
        end
    end

    if not sourceExists then
        return false, "Source profile '" .. sourceProfile .. "' does not exist"
    end

    -- Get source data safely
    local dataTable = db.data
    if type(dataTable) ~= "table" or type(dataTable.profiles) ~= "table" then
        return false, "Profile data not accessible"
    end

    local sourceData = dataTable.profiles[sourceProfile]
    if not sourceData then
        return false, "Source profile data not found"
    end

    -- Create target profile if it doesn't exist
    if not targetExists then
        local createSuccess, createErr = pcall(function()
            db:SetProfile(targetProfile)
        end)

        if not createSuccess then
            return false, "Failed to create target profile: " .. tostring(createErr)
        end
    end

    -- Deep copy source to target
    local targetData = dataTable.profiles[targetProfile]
    if not targetData then
        return false, "Failed to access target profile data"
    end

    wipe(targetData)

    for key, value in pairs(sourceData) do
        if type(value) == "table" then
            targetData[key] = DeepCopy(value)
        else
            targetData[key] = value
        end
    end

    -- Fire event
    if db.TriggerEvent then
        db:TriggerEvent("OnProfileCopied", sourceProfile, targetProfile)
    end

    return true
end

--- Reset a profile to default values
-- @param db table - SavedVariables database
-- @param profileName string - Profile name (nil for current)
-- @return boolean - Success
-- @return string - Error message (if failed)
function ProfileManagerMixin:ResetProfileToDefaults(db, profileName)
    if not db then
        return false, "Database not provided"
    end

    profileName = profileName or db:GetCurrentProfile()

    if type(profileName) ~= "string" or profileName == "" then
        return false, "Profile name must be a non-empty string"
    end

    -- Check if profile exists
    local profiles = db:GetProfiles()
    local exists = false
    for _, name in ipairs(profiles) do
        if name == profileName then
            exists = true
            break
        end
    end

    if not exists then
        return false, "Profile '" .. profileName .. "' does not exist"
    end

    -- Switch to profile if not current
    local currentProfile = db:GetCurrentProfile()
    local switched = false

    if currentProfile ~= profileName then
        local switchSuccess, switchErr = pcall(function()
            db:SetProfile(profileName)
        end)

        if not switchSuccess then
            return false, "Failed to switch to profile: " .. tostring(switchErr)
        end
        switched = true
    end

    -- Reset the profile
    local resetSuccess, resetErr = pcall(function()
        db:ResetProfile()
    end)

    -- Switch back if we changed profiles, regardless of reset success
    if switched then
        pcall(function()
            db:SetProfile(currentProfile)
        end)
    end

    if not resetSuccess then
        return false, "Failed to reset profile: " .. tostring(resetErr)
    end

    -- Fire event
    if db.TriggerEvent then
        db:TriggerEvent("OnProfileReset", profileName)
    end

    return true
end

--[[--------------------------------------------------------------------
    AceConfig-Style Options Table Generation
----------------------------------------------------------------------]]

--- Generate an AceConfig-compatible options table for profile management
-- @param db table - SavedVariables database
-- @return table - Options table for profile management
function ProfileManagerMixin:GenerateProfileOptionsTable(db)
    ---@diagnostic disable-next-line: redefined-local
    local self = self  -- Reference for closures

    local options = {
        type = "group",
        name = "Profiles",
        desc = "Manage addon profiles",
        order = 100,
        args = {
            -- Current profile display
            currentHeader = {
                type = "header",
                name = "Current Profile",
                order = 1,
            },
            currentDesc = {
                type = "description",
                name = function()
                    if not db then return "No database" end
                    return "Current Profile: |cff00ff00" .. db:GetCurrentProfile() .. "|r"
                end,
                fontSize = "medium",
                order = 2,
            },

            -- Profile selection
            selectHeader = {
                type = "header",
                name = "Select Profile",
                order = 10,
            },
            profile = {
                type = "select",
                name = "Profile",
                desc = "Switch to a different profile",
                values = function()
                    if not db then return {} end
                    local profiles = db:GetProfiles()
                    local values = {}
                    for _, name in ipairs(profiles) do
                        values[name] = name
                    end
                    return values
                end,
                get = function()
                    if not db then return nil end
                    return db:GetCurrentProfile()
                end,
                set = function(_, value)
                    if not db then return end
                    db:SetProfile(value)
                end,
                order = 11,
            },

            -- New profile creation
            newHeader = {
                type = "header",
                name = "Create New Profile",
                order = 20,
            },
            newProfileName = {
                type = "input",
                name = "New Profile Name",
                desc = "Enter a name for the new profile",
                get = function() return "" end,
                set = function(_, value)
                    if not db then return end
                    local success, err = self:CreateProfile(db, value)
                    if not success then
                        print("|cffff0000Error:|r " .. err)
                    else
                        print("Created profile: " .. value)
                    end
                end,
                order = 21,
            },

            -- Copy from profile
            copyHeader = {
                type = "header",
                name = "Copy Profile",
                order = 30,
            },
            copyFrom = {
                type = "select",
                name = "Copy From",
                desc = "Copy settings from another profile to current profile",
                values = function()
                    if not db then return {} end
                    local profiles = db:GetProfiles()
                    local currentProfile = db:GetCurrentProfile()
                    local values = {}
                    for _, name in ipairs(profiles) do
                        if name ~= currentProfile then
                            values[name] = name
                        end
                    end
                    return values
                end,
                get = function() return nil end,
                set = function(_, value)
                    if not db then return end
                    local success, err = self:CopyProfile(db, value)
                    if not success then
                        print("|cffff0000Error:|r " .. err)
                    else
                        print("Copied settings from: " .. value)
                    end
                end,
                confirm = true,
                confirmText = "Copy settings from another profile? This will overwrite your current settings.",
                order = 31,
            },

            -- Delete profile
            deleteHeader = {
                type = "header",
                name = "Delete Profile",
                order = 40,
            },
            deleteProfile = {
                type = "select",
                name = "Delete Profile",
                desc = "Permanently delete a profile",
                values = function()
                    if not db then return {} end
                    local profiles = db:GetProfiles()
                    local currentProfile = db:GetCurrentProfile()
                    local defaultProfile = db.defaultProfile or "Default"
                    local values = {}
                    for _, name in ipairs(profiles) do
                        if name ~= currentProfile and name ~= defaultProfile then
                            values[name] = name
                        end
                    end
                    return values
                end,
                get = function() return nil end,
                set = function(_, value)
                    if not db then return end
                    local success, err = self:DeleteProfile(db, value)
                    if not success then
                        print("|cffff0000Error:|r " .. err)
                    else
                        print("Deleted profile: " .. value)
                    end
                end,
                confirm = true,
                confirmText = "Are you sure you want to delete this profile? This cannot be undone.",
                order = 41,
            },

            -- Reset profile
            resetHeader = {
                type = "header",
                name = "Reset Profile",
                order = 50,
            },
            resetProfile = {
                type = "execute",
                name = "Reset Current Profile",
                desc = "Reset the current profile to default values",
                func = function()
                    if not db then return end
                    local success, err = self:ResetProfile(db)
                    if not success then
                        print("|cffff0000Error:|r " .. err)
                    else
                        print("Profile reset to defaults")
                    end
                end,
                confirm = true,
                confirmText = "Reset current profile to defaults? All settings will be lost.",
                order = 51,
            },

            -- Export/Import
            exportImportHeader = {
                type = "header",
                name = "Export / Import",
                order = 60,
            },
            exportProfile = {
                type = "execute",
                name = "Export Profile",
                desc = "Export the current profile to a string for sharing",
                func = function()
                    if not db then return end
                    local encoded, err = self:ExportProfile(db)
                    if not encoded then
                        print("|cffff0000Error:|r " .. err)
                        return
                    end

                    -- Create a dialog to show the export string
                    local frame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
                    frame:SetSize(500, 300)
                    frame:SetPoint("CENTER")
                    frame:SetFrameStrata("DIALOG")
                    frame:SetMovable(true)
                    frame:EnableMouse(true)
                    frame:RegisterForDrag("LeftButton")
                    frame:SetScript("OnDragStart", frame.StartMoving)
                    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

                    frame.TitleText:SetText("Export Profile")

                    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
                    scrollFrame:SetPoint("TOPLEFT", 12, -30)
                    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

                    local editBox = CreateFrame("EditBox", nil, scrollFrame)
                    editBox:SetMultiLine(true)
                    editBox:SetFontObject(ChatFontNormal)
                    editBox:SetWidth(scrollFrame:GetWidth())
                    editBox:SetAutoFocus(false)
                    editBox:SetText(encoded)
                    editBox:HighlightText()
                    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)

                    scrollFrame:SetScrollChild(editBox)

                    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
                    closeBtn:SetSize(100, 24)
                    closeBtn:SetPoint("BOTTOM", 0, 10)
                    closeBtn:SetText("Close")
                    closeBtn:SetScript("OnClick", function() frame:Hide() end)

                    print("Profile exported. Copy the string from the dialog.")
                end,
                order = 61,
            },
            importString = {
                type = "input",
                name = "Import Profile",
                desc = "Paste an export string to import a profile",
                multiline = true,
                width = "full",
                get = function() return "" end,
                set = function(_, value)
                    if not db then return end
                    local success, result = self:ImportProfile(db, value)
                    if not success then
                        print("|cffff0000Error:|r " .. result)
                    else
                        print("Imported profile: " .. result)
                    end
                end,
                order = 62,
            },
        },
    }

    return options
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib.Data.ProfileManager.Mixin = ProfileManagerMixin
Loolib.Data.ProfileManager = ProfileManagerModule

Loolib:RegisterModule("Data.ProfileManager", ProfileManagerModule)
