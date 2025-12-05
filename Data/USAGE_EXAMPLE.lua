--[[--------------------------------------------------------------------
    SavedVariables & ProfileManager Usage Examples

    This file demonstrates how to use the enhanced SavedVariables
    system with AceDB-style features including scopes, namespaces,
    and profile management.
----------------------------------------------------------------------]]

-- ==================================================================
-- BASIC USAGE - Creating a database with scopes
-- ==================================================================

local Loolib = LibStub("Loolib")
local Data = Loolib:GetModule("Data")

-- Define defaults with scope structure
local defaults = {
    profile = {
        -- Profile-specific settings (per-character profile)
        showMinimap = true,
        windowScale = 1.0,
        colors = {
            background = {0, 0, 0, 0.8},
            border = {1, 1, 1, 1},
        },
    },
    global = {
        -- Account-wide settings (same for all characters)
        version = "1.0.0",
        firstRun = true,
        accountData = {},
    },
    char = {
        -- Character-specific settings (per character, not profile)
        position = {x = 100, y = 100},
        lastLogin = 0,
    },
    realm = {
        -- Realm-specific settings
        auctionCache = {},
    },
    class = {
        -- Class-specific settings (e.g., for all warriors)
        classSpecificSettings = {},
    },
    faction = {
        -- Faction-specific settings
        factionReputation = {},
    },
}

-- Create database
local db = Data.CreateSavedVariables("MyAddon_DB", defaults, "Default")

-- ==================================================================
-- SCOPE ACCESS - AceDB-style shorthand
-- ==================================================================

-- Access profile data (current profile)
db.profile.showMinimap = false
db.profile.colors.background = {0.1, 0.1, 0.1, 0.9}

-- Access global data (account-wide)
db.global.firstRun = false
db.global.accountData.someKey = "someValue"

-- Access character-specific data
db.char.position = {x = 200, y = 200}
db.char.lastLogin = time()

-- Access realm-specific data
db.realm.auctionCache = {}

-- Access class-specific data
db.class.classSpecificSettings = {enabled = true}

-- Access faction-specific data
db.faction.factionReputation.AllianceFaction = 5000

-- ==================================================================
-- PROFILE MANAGEMENT
-- ==================================================================

-- Get current profile name
local currentProfile = db:GetCurrentProfile()  -- Returns: "Default"

-- Get list of all profiles
local profiles = db:GetProfiles()  -- Returns: {"Default", "Tank", "Healer"}

-- Create and switch to new profile
db:SetProfile("Tank")  -- Creates "Tank" profile if doesn't exist
-- Fires: OnNewProfile("Tank"), OnProfileChanged("Tank", "Default")

-- Copy data from another profile to current
db:CopyProfile("Default")  -- Copies "Default" to current profile ("Tank")
-- Fires: OnProfileCopied("Default")

-- Reset current profile to defaults
db:ResetProfile()
-- Fires: OnProfileReset

-- Delete a profile (with safety checks)
local success = db:DeleteProfile("Healer", false)  -- silent=false
-- Fires: OnProfileDeleted("Healer") if successful

-- ==================================================================
-- NAMESPACES - Isolated data within the database
-- ==================================================================

-- Create a namespace for a specific feature
local itemsDefaults = {
    profile = {
        cache = {},
        maxItems = 100,
    },
    global = {
        itemDatabase = {},
    },
}

local itemsDB = db:RegisterNamespace("Items", itemsDefaults)

-- Namespace has same API as main db
itemsDB.profile.cache = {}
itemsDB.global.itemDatabase[12345] = {name = "Awesome Sword"}

-- Get existing namespace
local itemsDB2 = db:GetNamespace("Items")

-- Namespaces are isolated from main db
db.profile.someSetting = "value"  -- Only in main db
itemsDB.profile.someSetting  -- nil (not in namespace)

-- ==================================================================
-- CALLBACKS - Listen for database events
-- ==================================================================

-- Register callback for profile changes
db:RegisterCallback("OnProfileChanged", function(event, newProfile, oldProfile)
    print("Profile changed from", oldProfile, "to", newProfile)
    -- Update UI, reload data, etc.
end)

-- Register callback for profile copied
db:RegisterCallback("OnProfileCopied", function(event, sourceProfile)
    print("Profile copied from", sourceProfile)
end)

-- Register callback for profile deleted
db:RegisterCallback("OnProfileDeleted", function(event, profileName)
    print("Profile deleted:", profileName)
end)

-- Register callback for profile reset
db:RegisterCallback("OnProfileReset", function(event)
    print("Profile reset to defaults")
end)

-- Register callback for new profile created
db:RegisterCallback("OnNewProfile", function(event, profileName)
    print("New profile created:", profileName)
end)

-- Register callback for database shutdown (PLAYER_LOGOUT)
db:RegisterCallback("OnDatabaseShutdown", function(event)
    print("Database shutting down, defaults stripped")
end)

-- Register callback for database reset
db:RegisterCallback("OnDatabaseReset", function(event)
    print("Entire database reset")
end)

-- ==================================================================
-- PROFILE MANAGER - UI Helper Utilities
-- ==================================================================

local ProfileManager = Loolib:GetModule("ProfileManager")
local PM = ProfileManager.Mixin

-- Get formatted profile list for dropdown
local dropdownList = PM:GetProfileList(db)
-- Returns: {
--   {text = "Default", value = "Default", checked = true},
--   {text = "Tank", value = "Tank", checked = false},
-- }

-- Get detailed profile information
local detailedList = PM:GetProfileListDetailed(db)
-- Returns: {
--   {name = "Default", isCurrent = true, isDefault = true, canDelete = false},
--   {name = "Tank", isCurrent = false, isDefault = false, canDelete = true},
-- }

-- Create new profile with validation
local success, error = PM:CreateProfile(db, "New Profile")
if not success then
    print("Failed to create profile:", error)
end

-- Delete profile with validation
local success, error = PM:DeleteProfile(db, "Old Profile")
if not success then
    print("Failed to delete profile:", error)
end

-- Copy profile with validation
local success, error = PM:CopyProfile(db, "Default", "My Copy")
if not success then
    print("Failed to copy profile:", error)
end

-- Get character information
local charInfo = PM:GetCharacterProfiles(db)
-- Returns: {
--   character = "Default",
--   characterKey = "PlayerName - RealmName",
--   realm = "RealmName",
--   class = "WARRIOR",
--   race = "Human",
--   faction = "Alliance",
-- }

-- Get all characters using a profile
local characters = PM:GetCharactersUsingProfile(db, "Default")
-- Returns: {"PlayerName - RealmName", "AltName - RealmName"}

-- Validate profile name
local valid, error = PM:ValidateProfileName("New Profile")
if not valid then
    print("Invalid profile name:", error)
end

-- Check if profile can be deleted
local canDelete, reason = PM:CanDeleteProfile(db, "Default")
if not canDelete then
    print("Cannot delete profile:", reason)
end

-- ==================================================================
-- ADVANCED FEATURES
-- ==================================================================

-- Reset entire database (all profiles and scopes)
db:ResetDB()
-- Fires: OnDatabaseReset

-- Manual default stripping (normally called on PLAYER_LOGOUT)
db:RemoveDefaults()

-- Get scope keys
local charKey = db:GetScopeKey("char")      -- "PlayerName - RealmName"
local realmKey = db:GetScopeKey("realm")    -- "RealmName"
local classKey = db:GetScopeKey("class")    -- "WARRIOR"
local raceKey = db:GetScopeKey("race")      -- "Human"
local factionKey = db:GetScopeKey("faction") -- "Alliance"

-- ==================================================================
-- MIGRATION FROM OLD API (useProfiles parameter)
-- ==================================================================

-- OLD API (still works for compatibility):
-- local db = Data.CreateSavedVariables("MyAddon_DB", defaults, true)

-- NEW API (recommended):
local db = Data.CreateSavedVariables("MyAddon_DB", {
    profile = defaults  -- Wrap old defaults in profile scope
}, "Default")

-- ==================================================================
-- STORAGE STRUCTURE
-- ==================================================================

--[[
MyAddon_DB = {
    -- Profile system
    profiles = {
        ["Default"] = { ... },
        ["Tank"] = { ... },
    },
    profileKeys = {
        ["PlayerName - RealmName"] = "Default",  -- Current profile per character
    },

    -- Scopes
    char = {
        ["PlayerName - RealmName"] = { ... }
    },
    realm = {
        ["RealmName"] = { ... }
    },
    class = {
        ["WARRIOR"] = { ... }
    },
    race = {
        ["Human"] = { ... }
    },
    faction = {
        ["Alliance"] = { ... }
    },
    factionrealm = {
        ["Alliance - RealmName"] = { ... }
    },
    global = { ... },

    -- Namespaces
    namespaces = {
        ["Items"] = {
            profiles = { ... },
            char = { ... },
            -- ... same structure as main db
        }
    }
}
]]
