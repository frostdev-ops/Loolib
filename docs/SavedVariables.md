# SavedVariables Documentation

**Module**: `Loolib.Data.SavedVariables`
**Mixin**: `LoolibSavedVariablesMixin`
**Factory**: `CreateLoolibSavedVariables(globalName, defaults, defaultProfile)`

## Table of Contents
1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Data Scopes](#data-scopes)
4. [Profile Management](#profile-management)
5. [Namespaces](#namespaces)
6. [Defaults System](#defaults-system)
7. [API Reference](#api-reference)
8. [Usage Examples](#usage-examples)
9. [Advanced Topics](#advanced-topics)
10. [Best Practices](#best-practices)

---

## Overview

The SavedVariables module provides a robust system for managing WoW addon saved variables with support for:

- **8 Data Scopes**: profile, global, char, realm, class, race, faction, factionrealm
- **Profile System**: AceDB-compatible profile management with per-character assignments
- **Namespaces**: Isolated data storage within a single SavedVariable
- **Smart Defaults**: Metatable-based defaults that reduce file size
- **Change Callbacks**: Event notifications for all data changes
- **Import/Export**: Profile sharing capabilities

### AceDB Feature Comparison

| Feature | AceDB | Loolib SavedVariables | Notes |
|---------|-------|----------------------|-------|
| Profile system | Yes | Yes | Full compatibility |
| 8 data scopes | Yes | Yes | Identical scope structure |
| Namespaces | Yes | Yes | Isolated data storage |
| Default merging | Yes | Yes | Metatable-based |
| Callbacks | Yes | Yes | More comprehensive events |
| Import/Export | Limited | Yes | Built-in serialization |
| Dot notation | No | Yes | `db:Get("ui.frames.width")` |
| Default stripping | Yes | Yes | Automatic on logout |

### Key Concepts

**Scopes**: Different storage contexts for addon data. Each scope targets different granularities (per-character, per-class, etc.).

**Profiles**: Named configuration sets that can be shared across characters. Characters can switch between profiles.

**Namespaces**: Isolated data storage within a single saved variable, useful for separating feature data.

**Defaults**: Fallback values that are only stored to disk if they differ from the default, reducing file size.

---

## Quick Start

### Basic Setup

```lua
-- 1. Declare SavedVariable in your TOC file
## SavedVariables: MyAddonDB

-- 2. Create the database on ADDON_LOADED
local Loolib = LibStub("Loolib")
local MyAddon = {}

-- Define your default values
local defaults = {
    profile = {
        enabled = true,
        minimap = {
            show = true,
            position = 45
        }
    },
    global = {
        version = "1.0.0",
        firstRun = true
    }
}

-- Create the database
MyAddon.db = Loolib.Data.CreateSavedVariables("MyAddonDB", defaults, "Default")

-- 3. Wait for initialization
MyAddon.db:OnReady(function()
    print("Database ready!")
    print("Enabled:", MyAddon.db.profile.enabled)
end)
```

### Simple Usage

```lua
-- Access profile data
local enabled = MyAddon.db.profile.enabled
MyAddon.db.profile.enabled = false

-- Access global data
local version = MyAddon.db.global.version

-- Access character-specific data
MyAddon.db.char.lastLogin = time()

-- Using Get/Set with dot notation
local width = MyAddon.db:Get("profile.ui.frames.width", 300)
MyAddon.db:Set("profile.ui.frames.width", 400)
```

---

## Data Scopes

SavedVariables provides 8 different scopes for organizing your addon data. Each scope has a different key that determines what data is shared between characters.

### Data Structure Diagram

```
MyAddonDB = {
    -- Profile system
    profiles = {
        ["Default"] = { ... },      -- Profile data
        ["Tank"] = { ... },
        ["Healer"] = { ... }
    },
    profileKeys = {
        ["Thrall - MoonGuard"] = "Tank",       -- Which profile each character uses
        ["Jaina - MoonGuard"] = "Healer"
    },

    -- Scope data
    char = {
        ["Thrall - MoonGuard"] = { ... }       -- Per-character data
    },
    realm = {
        ["MoonGuard"] = { ... }                -- Per-realm data
    },
    class = {
        ["WARRIOR"] = { ... }                  -- Per-class data
    },
    race = {
        ["Orc"] = { ... }                      -- Per-race data
    },
    faction = {
        ["Horde"] = { ... }                    -- Per-faction data
    },
    factionrealm = {
        ["Horde - MoonGuard"] = { ... }        -- Per-faction-realm data
    },
    global = { ... },                          -- Account-wide data

    -- Namespaces (optional)
    namespaces = {
        ["ModuleName"] = {
            -- Same structure as above, isolated
        }
    }
}
```

### Scope Reference

#### 1. Profile Scope

**Key**: Profile name (e.g., "Default", "Tank", "Healer")
**Shared by**: Characters assigned to the same profile
**Access**: `db.profile`

```lua
-- Each character can be assigned to any profile
-- Perfect for shareable configurations

defaults.profile = {
    ui = {
        scale = 1.0,
        fontSize = 12
    },
    combat = {
        autoTarget = true
    }
}

-- Access
local scale = db.profile.ui.scale
db.profile.ui.scale = 1.2
```

**When to use**: Settings that you want to share across multiple characters (UI layouts, keybinds, general preferences).

#### 2. Global Scope

**Key**: None (account-wide)
**Shared by**: All characters on the account
**Access**: `db.global`

```lua
defaults.global = {
    version = "1.0.0",
    firstRun = true,
    statistics = {
        totalLogins = 0,
        timePlayed = 0
    }
}

-- Access
db.global.totalLogins = db.global.totalLogins + 1
```

**When to use**: Account-wide settings, version tracking, global statistics, first-run flags.

#### 3. Character Scope

**Key**: "PlayerName - RealmName"
**Shared by**: Only this specific character
**Access**: `db.char`

```lua
defaults.char = {
    lastLogin = 0,
    position = { x = 0, y = 0 },
    quests = {}
}

-- Access
db.char.lastLogin = time()
db.char.position = { x = player:GetX(), y = player:GetY() }
```

**When to use**: Character-specific data that shouldn't be shared (quest progress, position, character state).

#### 4. Realm Scope

**Key**: "RealmName"
**Shared by**: All characters on the same realm
**Access**: `db.realm`

```lua
defaults.realm = {
    guildRoster = {},
    auctionHistory = {},
    knownPlayers = {}
}

-- Access
db.realm.knownPlayers[playerName] = true
```

**When to use**: Realm-specific data (auction prices, guild info, player lists).

#### 5. Class Scope

**Key**: "CLASSNAME" (uppercase, e.g., "WARRIOR", "MAGE")
**Shared by**: All characters of the same class
**Access**: `db.class`

```lua
defaults.class = {
    specSettings = {
        [1] = { rotation = {...} },
        [2] = { rotation = {...} }
    },
    macros = {}
}

-- Access
local spec = GetSpecialization()
db.class.specSettings[spec].rotation = {...}
```

**When to use**: Class-specific settings (spec configurations, class-specific UI elements).

#### 6. Race Scope

**Key**: "RaceName" (e.g., "Human", "Orc")
**Shared by**: All characters of the same race
**Access**: `db.race`

```lua
defaults.race = {
    racialSettings = {
        autoUseRacial = true,
        racialPriority = 1
    }
}

-- Access
db.race.autoUseRacial = true
```

**When to use**: Race-specific settings (racial ability settings, race-themed UI).

#### 7. Faction Scope

**Key**: "Alliance" or "Horde"
**Shared by**: All characters on the same faction
**Access**: `db.faction`

```lua
defaults.faction = {
    enemyList = {},
    factionReputation = {},
    pvpSettings = {
        autoFlag = false
    }
}

-- Access
db.faction.enemyList[enemyName] = true
```

**When to use**: Faction-specific data (enemy lists, faction reputation, PvP settings).

#### 8. FactionRealm Scope

**Key**: "FactionName - RealmName"
**Shared by**: All characters of the same faction on the same realm
**Access**: `db.factionrealm`

```lua
defaults.factionrealm = {
    economy = {
        marketPrices = {},
        tradeskills = {}
    },
    social = {
        allies = {},
        guilds = {}
    }
}

-- Access
db.factionrealm.economy.marketPrices[itemID] = price
```

**When to use**: Faction-realm specific data (market prices, faction guilds, realm-faction alliances).

### Scope Key Generation

Scope keys are automatically generated and cached:

```lua
-- Internal scope key generation
function LoolibSavedVariablesMixin:GenerateScopeKeys()
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local className = select(2, UnitClass("player"))
    local raceName = select(2, UnitRace("player"))
    local factionName = UnitFactionGroup("player")

    self.scopeKeys.char = playerName .. " - " .. realmName
    self.scopeKeys.realm = realmName
    self.scopeKeys.class = className
    self.scopeKeys.race = raceName
    self.scopeKeys.faction = factionName
    self.scopeKeys.factionrealm = factionName .. " - " .. realmName
end

-- Get a scope key
local charKey = db:GetScopeKey("char")  -- "Thrall - MoonGuard"
```

---

## Profile Management

Profiles allow characters to share configuration data. Each character can be assigned to any profile, and switching profiles is instant.

### Creating Profiles

```lua
-- Create a new profile by switching to it
db:SetProfile("Tank")

-- The profile is created automatically if it doesn't exist
-- It starts with default values from defaults.profile
```

### Switching Profiles

```lua
-- Get current profile name
local current = db:GetCurrentProfile()  -- "Default"

-- Switch to a different profile
db:SetProfile("Healer")

-- This character now uses the "Healer" profile
-- The assignment is saved in profileKeys
```

### Listing Profiles

```lua
-- Get all profile names
local profiles = db:GetProfiles()
-- Returns: {"Default", "Tank", "Healer"}

-- Iterate profiles
for _, profileName in ipairs(profiles) do
    print("Profile:", profileName)
end
```

### Copying Profiles

```lua
-- Copy another profile to current profile
db:CopyProfile("Tank")

-- This deep copies all data from "Tank" profile to the current profile
-- Original "Tank" profile remains unchanged

-- Silent copy (no error if source doesn't exist)
db:CopyProfile("NonExistent", true)
```

### Deleting Profiles

```lua
-- Delete a profile
local success = db:DeleteProfile("OldProfile")

-- Safety checks prevent deleting:
-- - The default profile
-- - The current profile (switch first)
-- - The last remaining profile

-- Silent delete
db:DeleteProfile("Profile", true)  -- No error if it doesn't exist
```

### Resetting Profiles

```lua
-- Reset current profile to defaults
db:ResetProfile()

-- All data in current profile is wiped and replaced with defaults
```

### Profile Callbacks

Listen for profile changes:

```lua
-- Profile changed (switched to different profile)
db:RegisterCallback("OnProfileChanged", function(newProfile, oldProfile)
    print("Switched from", oldProfile, "to", newProfile)
    -- Update UI, reload settings, etc.
end)

-- New profile created
db:RegisterCallback("OnNewProfile", function(profileName)
    print("Created new profile:", profileName)
end)

-- Profile copied
db:RegisterCallback("OnProfileCopied", function(sourceName)
    print("Copied data from:", sourceName)
end)

-- Profile deleted
db:RegisterCallback("OnProfileDeleted", function(profileName)
    print("Deleted profile:", profileName)
end)

-- Profile reset
db:RegisterCallback("OnProfileReset", function()
    print("Profile reset to defaults")
end)
```

### Profile Workflow Example

```lua
-- Character 1 creates and configures a profile
local char1DB = CreateLoolibSavedVariables("MyAddonDB", defaults)
char1DB:SetProfile("PvP")
char1DB.profile.combat.autoTarget = true
char1DB.profile.ui.scale = 1.2

-- Character 2 uses the same profile
local char2DB = CreateLoolibSavedVariables("MyAddonDB", defaults)
char2DB:SetProfile("PvP")
-- char2DB.profile.combat.autoTarget == true (shared!)
-- char2DB.profile.ui.scale == 1.2 (shared!)

-- Character 3 creates their own profile
local char3DB = CreateLoolibSavedVariables("MyAddonDB", defaults)
char3DB:SetProfile("Solo")
char3DB.profile.combat.autoTarget = false  -- Independent
```

---

## Namespaces

Namespaces provide isolated data storage within a single SavedVariable. They're useful for:

- Separating feature module data
- Avoiding key collisions
- Organizing large addons
- Optional modules that can be enabled/disabled

### What Are Namespaces?

Namespaces are independent data stores that live inside your main SavedVariable but have their own:

- Profiles
- Scopes
- Defaults
- Callbacks

They share the same `profileKeys` so characters use the same profile across namespaces.

### Creating Namespaces

```lua
-- Define defaults for the namespace
local moduleDefaults = {
    profile = {
        enabled = true,
        settings = {}
    },
    char = {
        state = {}
    }
}

-- Register a namespace
local moduleDB = db:RegisterNamespace("ModuleName", moduleDefaults)

-- Use it like a normal database
moduleDB.profile.enabled = true
moduleDB.char.state = "active"
```

### When to Use Namespaces

**Use namespaces when:**

- You have distinct feature modules (combat, UI, economy)
- You want data isolation between components
- You have optional modules
- You want to avoid key naming conflicts

**Don't use namespaces when:**

- You have simple, flat data structures
- All data is tightly coupled
- You want to access everything from one place

### Namespace Example: Multi-Module Addon

```lua
-- Main addon database
local defaults = {
    profile = {
        general = {
            enabled = true
        }
    }
}

local db = CreateLoolibSavedVariables("BigAddonDB", defaults)

-- Combat module namespace
local combatDefaults = {
    profile = {
        rotation = {},
        cooldowns = {}
    }
}
local combatDB = db:RegisterNamespace("Combat", combatDefaults)

-- UI module namespace
local uiDefaults = {
    profile = {
        frames = {},
        scale = 1.0
    },
    char = {
        positions = {}
    }
}
local uiDB = db:RegisterNamespace("UI", uiDefaults)

-- Economy module namespace
local economyDefaults = {
    profile = {
        autoSell = true
    },
    realm = {
        marketData = {}
    }
}
local economyDB = db:RegisterNamespace("Economy", economyDefaults)

-- Each namespace is independent
combatDB.profile.rotation = {...}
uiDB.profile.frames = {...}
economyDB.realm.marketData = {...}

-- But they share profile assignments
db:SetProfile("MainSpec")
-- All namespaces now use "MainSpec" profile
```

### Retrieving Namespaces

```lua
-- Get an existing namespace
local moduleDB = db:GetNamespace("ModuleName")

-- Silent get (returns nil if not found)
local moduleDB = db:GetNamespace("ModuleName", true)

-- Error if not found
local moduleDB = db:GetNamespace("ModuleName", false)  -- Errors if not registered
```

### Namespace Data Structure

```lua
MyAddonDB = {
    profiles = { ... },      -- Main database profiles
    profileKeys = { ... },   -- Shared across all namespaces
    global = { ... },
    char = { ... },
    -- ... other scopes

    namespaces = {
        ["Combat"] = {
            profiles = { ... },    -- Combat namespace profiles
            global = { ... },
            char = { ... },
            -- ... other scopes
        },
        ["UI"] = {
            profiles = { ... },    -- UI namespace profiles
            global = { ... },
            char = { ... },
            -- ... other scopes
        }
    }
}
```

---

## Defaults System

The defaults system uses Lua metatables to provide fallback values without storing them to disk. This dramatically reduces SavedVariable file size.

### How Defaults Work

When you access a key that doesn't exist in the saved data, the metatable's `__index` function returns the default value:

```lua
-- Define defaults
local defaults = {
    profile = {
        enabled = true,
        scale = 1.0,
        position = { x = 0, y = 0 }
    }
}

local db = CreateLoolibSavedVariables("MyAddonDB", defaults)

-- On disk: MyAddonDB = { profiles = { Default = {} } }
-- Everything returns defaults!

print(db.profile.enabled)  -- true (from defaults, not stored)
print(db.profile.scale)    -- 1.0 (from defaults, not stored)

-- Change a value
db.profile.scale = 1.5

-- On disk: MyAddonDB = { profiles = { Default = { scale = 1.5 } } }
-- Only the changed value is stored!
```

### Metatable Magic Explained

```lua
-- When you create a database, this happens:
function LoolibSavedVariablesMixin:SetDefaults(target, defaults)
    setmetatable(target, {
        __index = function(t, key)
            local defaultValue = defaults[key]

            if type(defaultValue) == "table" then
                -- For nested tables, create a new table with defaults
                local newTable = {}
                t[key] = newTable
                self:SetDefaults(newTable, defaultValue)
                return newTable
            end

            -- Return the default value
            return defaultValue
        end
    })
end

-- Access flow:
-- 1. db.profile.enabled
-- 2. Look in saved data: not found
-- 3. Call __index metamethod
-- 4. Return defaults.profile.enabled
-- 5. User sees: true
```

### Default Stripping

On `PLAYER_LOGOUT`, the system automatically removes values that match defaults to save disk space:

```lua
-- Before logout
db.profile = {
    enabled = true,    -- Matches default
    scale = 1.5,       -- Different from default (1.0)
    color = "blue"     -- Different from default (nil)
}

-- After logout (automatic)
db.profile = {
    scale = 1.5,
    color = "blue"
}
-- "enabled" removed because it matches the default
```

### Manual Default Merging

```lua
-- Merge defaults into existing data (non-destructive)
db:MergeDefaults(db.profile, defaults.profile)

-- This fills in missing keys but doesn't overwrite existing values
```

### Default Stripping Control

```lua
-- Default stripping happens automatically on PLAYER_LOGOUT
-- You can also trigger it manually:
db:RemoveDefaults()

-- This strips defaults from:
-- - All profiles
-- - All scopes
-- - All namespaces
```

### Nested Defaults Example

```lua
local defaults = {
    profile = {
        ui = {
            frames = {
                main = {
                    width = 400,
                    height = 300,
                    position = { x = 0, y = 0 }
                }
            }
        }
    }
}

local db = CreateLoolibSavedVariables("MyAddonDB", defaults)

-- All nested access works through defaults
print(db.profile.ui.frames.main.width)  -- 400 (not stored)

-- Only changed values are stored
db.profile.ui.frames.main.width = 500

-- On disk:
-- MyAddonDB = {
--     profiles = {
--         Default = {
--             ui = {
--                 frames = {
--                     main = {
--                         width = 500
--                     }
--                 }
--             }
--         }
--     }
-- }
```

---

## API Reference

### Factory Function

#### `CreateLoolibSavedVariables(globalName, defaults, defaultProfile)`

Creates a new SavedVariables database.

**Parameters:**
- `globalName` (string) - Global variable name (must match TOC declaration)
- `defaults` (table, optional) - Default values with scope keys
- `defaultProfile` (string, optional) - Default profile name (default: "Default")

**Returns:** SavedVariables database object with scope accessors

**Example:**
```lua
local db = CreateLoolibSavedVariables("MyAddonDB", {
    profile = { enabled = true },
    global = { version = "1.0" }
}, "Default")
```

### Initialization

#### `:Init(globalName, defaults, defaultProfile)`

Manually initialize the database (usually called by factory function).

#### `:OnReady(callback, owner)`

Register a callback for when the database is initialized.

**Parameters:**
- `callback` (function) - Function to call when ready
- `owner` (any) - Owner for the callback

**Example:**
```lua
db:OnReady(function()
    print("Database ready!")
end)
```

#### `:IsInitialized()`

Check if the database has been initialized.

**Returns:** boolean

### Scope Access

#### `:GetScope(scope)`

Get a scope table.

**Parameters:**
- `scope` (string) - Scope name: "profile", "global", "char", "realm", "class", "race", "faction", "factionrealm"

**Returns:** table - The scope data table

**Example:**
```lua
local profileData = db:GetScope("profile")
local charData = db:GetScope("char")
```

#### Direct Scope Access

All scopes can be accessed directly:

```lua
db.profile      -- Current profile data
db.global       -- Global data
db.char         -- Character data
db.realm        -- Realm data
db.class        -- Class data
db.race         -- Race data
db.faction      -- Faction data
db.factionrealm -- Faction-realm data
```

#### `:GetScopeKey(scope)`

Get the key used for a specific scope.

**Parameters:**
- `scope` (string) - Scope name

**Returns:** string - The scope key

**Example:**
```lua
local charKey = db:GetScopeKey("char")  -- "Thrall - MoonGuard"
local realmKey = db:GetScopeKey("realm")  -- "MoonGuard"
local classKey = db:GetScopeKey("class")  -- "WARRIOR"
```

### Value Access

#### `:Get(key, default)`

Get a value using dot notation.

**Parameters:**
- `key` (string) - Dot-separated path (e.g., "ui.frames.width")
- `default` (any, optional) - Default value if not found

**Returns:** any - The value or default

**Example:**
```lua
local width = db:Get("ui.frames.width", 400)
local enabled = db:Get("combat.autoTarget", true)
```

#### `:Set(key, value)`

Set a value using dot notation.

**Parameters:**
- `key` (string) - Dot-separated path
- `value` (any) - Value to set

**Example:**
```lua
db:Set("ui.frames.width", 500)
db:Set("combat.rotation.opener", "Charge")
```

#### `:Has(key)`

Check if a key exists.

**Parameters:**
- `key` (string) - The key to check

**Returns:** boolean

**Example:**
```lua
if db:Has("ui.customFrame") then
    -- Key exists
end
```

#### `:Delete(key)`

Delete a key.

**Parameters:**
- `key` (string) - The key to delete

**Example:**
```lua
db:Delete("ui.oldFrame")
```

### Profile Management

#### `:GetCurrentProfile()`

Get the current profile name.

**Returns:** string

**Example:**
```lua
local current = db:GetCurrentProfile()  -- "Default"
```

#### `:GetProfiles(tbl)`

Get all profile names.

**Parameters:**
- `tbl` (table, optional) - Table to fill (creates new if nil)

**Returns:** table - Sorted array of profile names

**Example:**
```lua
local profiles = db:GetProfiles()
for _, name in ipairs(profiles) do
    print(name)
end
```

#### `:SetProfile(name)`

Switch to a different profile.

**Parameters:**
- `name` (string) - Profile name (creates if doesn't exist)

**Example:**
```lua
db:SetProfile("Tank")
```

#### `:CopyProfile(sourceName, silent)`

Copy data from another profile to current profile.

**Parameters:**
- `sourceName` (string) - Name of profile to copy from
- `silent` (boolean, optional) - Suppress errors if source doesn't exist

**Example:**
```lua
db:CopyProfile("Default")
db:CopyProfile("NonExistent", true)  -- Silent
```

#### `:DeleteProfile(name, silent)`

Delete a profile.

**Parameters:**
- `name` (string) - Profile name
- `silent` (boolean, optional) - Suppress errors

**Returns:** boolean - Success

**Example:**
```lua
if db:DeleteProfile("OldProfile") then
    print("Deleted!")
end
```

#### `:ResetProfile()`

Reset current profile to defaults.

**Example:**
```lua
db:ResetProfile()
```

### Namespaces

#### `:RegisterNamespace(name, defaults)`

Register a namespace.

**Parameters:**
- `name` (string) - Namespace name
- `defaults` (table, optional) - Default values for namespace

**Returns:** SavedVariables object for the namespace

**Example:**
```lua
local moduleDB = db:RegisterNamespace("Combat", {
    profile = { rotation = {} }
})
```

#### `:GetNamespace(name, silent)`

Get an existing namespace.

**Parameters:**
- `name` (string) - Namespace name
- `silent` (boolean, optional) - Don't error if not found

**Returns:** SavedVariables object or nil

**Example:**
```lua
local moduleDB = db:GetNamespace("Combat")
```

### Reset Operations

#### `:ResetDB()`

Reset entire database (all profiles and scopes) to defaults.

**Example:**
```lua
db:ResetDB()  -- Nuclear option!
```

#### `:Reset()`

Reset current profile to defaults (legacy compatibility).

**Example:**
```lua
db:Reset()
```

#### `:ResetKey(key)`

Reset a specific key to its default value.

**Parameters:**
- `key` (string) - The key to reset

**Example:**
```lua
db:ResetKey("ui.scale")  -- Back to default
```

### Import/Export

#### `:Export()`

Export current profile as a string.

**Returns:** string - Serialized data

**Example:**
```lua
local exported = db:Export()
-- Share this string with other players
```

#### `:Import(str)`

Import data from a string.

**Parameters:**
- `str` (string) - Serialized data

**Returns:** boolean - Success

**Example:**
```lua
if db:Import(importedString) then
    print("Profile imported!")
end
```

### Callbacks

#### `:RegisterCallback(event, func, owner, ...)`

Register a callback for an event.

**Parameters:**
- `event` (string) - Event name
- `func` (function) - Callback function
- `owner` (any) - Owner for unregistration
- `...` - Optional captured arguments

**Returns:** any - Owner (for unregistration)

**Example:**
```lua
db:RegisterCallback("OnProfileChanged", function(newProfile, oldProfile)
    print("Changed to:", newProfile)
end, myAddon)
```

#### `:UnregisterCallback(event, owner)`

Unregister a callback.

**Parameters:**
- `event` (string) - Event name
- `owner` (any) - Owner that registered the callback

**Example:**
```lua
db:UnregisterCallback("OnProfileChanged", myAddon)
```

### Callback Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `OnInitialized` | - | Database initialized and ready |
| `OnValueChanged` | key, newValue, oldValue | A value was changed |
| `OnProfileChanged` | newProfile, oldProfile | Profile switched |
| `OnNewProfile` | profileName | New profile created |
| `OnProfileCopied` | sourceName | Profile copied |
| `OnProfileDeleted` | profileName | Profile deleted |
| `OnProfileReset` | - | Profile reset to defaults |
| `OnDatabaseReset` | - | Entire database reset |
| `OnReset` | - | Legacy reset (same as OnProfileReset) |
| `OnDatabaseShutdown` | - | PLAYER_LOGOUT (before default stripping) |

---

## Usage Examples

### Example 1: Basic Addon with Profiles

```lua
-- MyAddon.lua
local MyAddon = CreateFrame("Frame")
local Loolib = LibStub("Loolib")

-- Define defaults
local defaults = {
    profile = {
        enabled = true,
        minimap = {
            show = true,
            position = 45
        },
        ui = {
            scale = 1.0,
            fontSize = 12
        }
    },
    global = {
        version = "1.0.0"
    },
    char = {
        lastLogin = 0
    }
}

-- Create database
MyAddon.db = Loolib.Data.CreateSavedVariables("MyAddonDB", defaults, "Default")

-- Wait for initialization
MyAddon.db:OnReady(function()
    -- Update last login
    MyAddon.db.char.lastLogin = time()

    -- Check if enabled
    if MyAddon.db.profile.enabled then
        MyAddon:Initialize()
    end

    -- Update UI scale
    MyAddon.mainFrame:SetScale(MyAddon.db.profile.ui.scale)
end)

-- Listen for profile changes
MyAddon.db:RegisterCallback("OnProfileChanged", function(newProfile, oldProfile)
    print("Switched from", oldProfile, "to", newProfile)
    MyAddon:RefreshUI()
end, MyAddon)
```

### Example 2: Multi-Character Settings Addon

```lua
-- AltTracker.lua
local AltTracker = {}
local Loolib = LibStub("Loolib")

local defaults = {
    global = {
        characters = {}  -- Track all characters
    },
    char = {
        gold = 0,
        level = 1,
        itemLevel = 0,
        professions = {}
    }
}

AltTracker.db = Loolib.Data.CreateSavedVariables("AltTrackerDB", defaults)

function AltTracker:OnLogin()
    local charKey = self.db:GetScopeKey("char")

    -- Update this character's info
    self.db.char.gold = GetMoney()
    self.db.char.level = UnitLevel("player")
    self.db.char.itemLevel = GetAverageItemLevel()

    -- Add to global character list
    self.db.global.characters[charKey] = {
        name = UnitName("player"),
        realm = GetRealmName(),
        class = select(2, UnitClass("player")),
        lastSeen = time()
    }
end

function AltTracker:GetAllCharacters()
    local chars = {}

    -- Iterate global character list
    for charKey, info in pairs(self.db.global.characters) do
        table.insert(chars, {
            key = charKey,
            name = info.name,
            realm = info.realm,
            class = info.class,
            lastSeen = info.lastSeen
        })
    end

    return chars
end

function AltTracker:GetCharacterGold(charKey)
    -- Access another character's data
    if self.db.data.char[charKey] then
        return self.db.data.char[charKey].gold or 0
    end
    return 0
end

function AltTracker:GetTotalGold()
    local total = 0

    for charKey in pairs(self.db.global.characters) do
        total = total + self:GetCharacterGold(charKey)
    end

    return total
end
```

### Example 3: Using Namespaces

```lua
-- BigAddon.lua
local BigAddon = {}
local Loolib = LibStub("Loolib")

-- Main database
local mainDefaults = {
    profile = {
        general = {
            enabled = true
        }
    }
}

BigAddon.db = Loolib.Data.CreateSavedVariables("BigAddonDB", mainDefaults)

-- Combat module namespace
local combatDefaults = {
    profile = {
        autoAttack = true,
        rotation = {
            opener = "Charge",
            filler = "Slam"
        },
        cooldowns = {
            autoUse = true
        }
    }
}

BigAddon.combatDB = BigAddon.db:RegisterNamespace("Combat", combatDefaults)

-- UI module namespace
local uiDefaults = {
    profile = {
        scale = 1.0,
        frames = {}
    },
    char = {
        positions = {}
    }
}

BigAddon.uiDB = BigAddon.db:RegisterNamespace("UI", uiDefaults)

-- Combat module
BigAddon.Combat = {
    db = BigAddon.combatDB
}

function BigAddon.Combat:GetRotation()
    return self.db.profile.rotation
end

function BigAddon.Combat:SetOpener(spell)
    self.db.profile.rotation.opener = spell
end

-- UI module
BigAddon.UI = {
    db = BigAddon.uiDB
}

function BigAddon.UI:SavePosition(frameName, x, y)
    self.db.char.positions[frameName] = { x = x, y = y }
end

function BigAddon.UI:LoadPosition(frameName)
    return self.db.char.positions[frameName]
end

-- Profile switching affects all namespaces
function BigAddon:SwitchProfile(profileName)
    self.db:SetProfile(profileName)
    -- All namespaces automatically use the new profile

    self.Combat:RefreshSettings()
    self.UI:RefreshFrames()
end
```

### Example 4: Profile Switching UI

```lua
-- ProfileSelector.lua
local ProfileSelector = {}
local Loolib = LibStub("Loolib")

function ProfileSelector:CreateDropdown(parent, db)
    local dropdown = CreateFrame("Frame", "ProfileDropdown", parent, "UIDropDownMenuTemplate")

    -- Initialize dropdown
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local profiles = db:GetProfiles()
        local current = db:GetCurrentProfile()

        for _, profileName in ipairs(profiles) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = profileName
            info.checked = (profileName == current)
            info.func = function()
                db:SetProfile(profileName)
                UIDropDownMenu_SetText(dropdown, profileName)
            end
            UIDropDownMenu_AddButton(info)
        end

        -- Add separator
        local info = UIDropDownMenu_CreateInfo()
        info.text = ""
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)

        -- New profile button
        local info = UIDropDownMenu_CreateInfo()
        info.text = "New Profile..."
        info.notCheckable = true
        info.func = function()
            StaticPopup_Show("PROFILE_NEW", nil, nil, db)
        end
        UIDropDownMenu_AddButton(info)

        -- Copy profile button
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Copy Profile..."
        info.notCheckable = true
        info.func = function()
            StaticPopup_Show("PROFILE_COPY", nil, nil, db)
        end
        UIDropDownMenu_AddButton(info)

        -- Delete profile button
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Delete Profile..."
        info.notCheckable = true
        info.func = function()
            StaticPopup_Show("PROFILE_DELETE", nil, nil, db)
        end
        UIDropDownMenu_AddButton(info)
    end)

    -- Set current profile text
    UIDropDownMenu_SetText(dropdown, db:GetCurrentProfile())

    -- Listen for profile changes
    db:RegisterCallback("OnProfileChanged", function(newProfile)
        UIDropDownMenu_SetText(dropdown, newProfile)
    end, dropdown)

    return dropdown
end

-- Static popup for new profile
StaticPopupDialogs["PROFILE_NEW"] = {
    text = "Enter a name for the new profile:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = function(self, db)
        local name = self.editBox:GetText()
        if name and name ~= "" then
            db:SetProfile(name)
            print("Created profile:", name)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Static popup for copy profile
StaticPopupDialogs["PROFILE_COPY"] = {
    text = "Select a profile to copy:",
    button1 = "Copy",
    button2 = "Cancel",
    hasEditBox = false,
    OnShow = function(self, db)
        -- Create dropdown for source selection
        -- (Implementation omitted for brevity)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Static popup for delete profile
StaticPopupDialogs["PROFILE_DELETE"] = {
    text = "Delete the current profile?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, db)
        local current = db:GetCurrentProfile()
        db:SetProfile("Default")
        if db:DeleteProfile(current, true) then
            print("Deleted profile:", current)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
```

### Example 5: Integration with Config Module

```lua
-- Config integration example
local MyAddon = {}
local Loolib = LibStub("Loolib")

-- Create database
local defaults = {
    profile = {
        enabled = true,
        ui = {
            scale = 1.0,
            alpha = 1.0
        }
    }
}

MyAddon.db = Loolib.Data.CreateSavedVariables("MyAddonDB", defaults)

-- Create config options
local configOptions = {
    type = "group",
    name = "MyAddon",
    args = {
        enabled = {
            type = "toggle",
            name = "Enabled",
            desc = "Enable/disable the addon",
            get = function() return MyAddon.db.profile.enabled end,
            set = function(_, value)
                MyAddon.db.profile.enabled = value
                if value then
                    MyAddon:Enable()
                else
                    MyAddon:Disable()
                end
            end
        },
        scale = {
            type = "range",
            name = "UI Scale",
            min = 0.5,
            max = 2.0,
            step = 0.1,
            get = function() return MyAddon.db.profile.ui.scale end,
            set = function(_, value)
                MyAddon.db.profile.ui.scale = value
                MyAddon:UpdateScale()
            end
        },
        profile = {
            type = "select",
            name = "Profile",
            values = function()
                local profiles = {}
                for _, name in ipairs(MyAddon.db:GetProfiles()) do
                    profiles[name] = name
                end
                return profiles
            end,
            get = function() return MyAddon.db:GetCurrentProfile() end,
            set = function(_, value)
                MyAddon.db:SetProfile(value)
            end
        }
    }
}

-- Listen for changes
MyAddon.db:RegisterCallback("OnValueChanged", function(key, newValue, oldValue)
    print("Setting changed:", key, "->", newValue)
end, MyAddon)
```

---

## Advanced Topics

### Profile Import/Export

Share profiles between accounts or players:

```lua
-- Export current profile
local exported = db:Export()

-- This returns a serialized string
-- Share it via chat, email, pastebin, etc.

-- Import a profile
local importString = "..." -- From another player
if db:Import(importString) then
    print("Profile imported successfully!")
else
    print("Failed to import profile")
end

-- Import workflow:
-- 1. Create a new profile
db:SetProfile("ImportedProfile")

-- 2. Import the data
db:Import(importString)

-- 3. The current profile now has the imported data
```

### Character-Specific Profile Settings

Sometimes you want mostly shared settings but with per-character overrides:

```lua
-- Approach 1: Use char scope for overrides
defaults = {
    profile = {
        ui = {
            scale = 1.0,
            position = { x = 0, y = 0 }
        }
    },
    char = {
        ui = {
            position = nil  -- Override position per-character
        }
    }
}

-- Access shared setting
local scale = db.profile.ui.scale

-- Access character-specific override
local position = db.char.ui.position or db.profile.ui.position

-- Approach 2: Profile per character with copy
-- Character 1
db:SetProfile("Char1-Tank")
db:CopyProfile("DefaultTank")  -- Start with tank defaults
db.profile.ui.position = { x = 100, y = 100 }  -- Character-specific

-- Character 2
db:SetProfile("Char2-Tank")
db:CopyProfile("DefaultTank")  -- Same tank defaults
db.profile.ui.position = { x = 200, y = 200 }  -- Different position
```

### Migration from Old Data Structures

Convert legacy SavedVariables to Loolib format:

```lua
-- Old structure
MyAddon_SavedVars = {
    version = "1.0",
    characters = {
        ["Thrall-MoonGuard"] = {
            gold = 1000,
            level = 60
        }
    },
    settings = {
        scale = 1.2,
        enabled = true
    }
}

-- Migration function
function MyAddon:MigrateData()
    local old = MyAddon_SavedVars

    if old and old.version == "1.0" then
        -- Migrate global data
        self.db.global.version = "2.0"  -- New version

        -- Migrate profile settings
        self.db.profile.scale = old.settings.scale
        self.db.profile.enabled = old.settings.enabled

        -- Migrate character data
        local charKey = self.db:GetScopeKey("char")
        if old.characters[charKey] then
            self.db.char.gold = old.characters[charKey].gold
            self.db.char.level = old.characters[charKey].level
        end

        -- Clear old data
        MyAddon_SavedVars = nil

        print("Migration complete!")
    end
end

-- Run migration on first load
MyAddon.db:OnReady(function()
    MyAddon:MigrateData()
end)
```

### Dynamic Defaults

Update defaults at runtime:

```lua
-- Initial defaults
local defaults = {
    profile = {
        features = {}
    }
}

local db = CreateLoolibSavedVariables("MyAddonDB", defaults)

-- Later, dynamically add feature defaults
function MyAddon:RegisterFeature(name, featureDefaults)
    -- Update defaults
    self.db.defaults.profile.features[name] = featureDefaults

    -- Merge into existing data
    if not self.db.profile.features[name] then
        self.db.profile.features[name] = LoolibTableUtil.DeepCopy(featureDefaults)
    end
end

-- Usage
MyAddon:RegisterFeature("Combat", {
    enabled = true,
    rotation = {}
})
```

### Profile Validation

Ensure profile data integrity:

```lua
function MyAddon:ValidateProfile()
    local profile = self.db.profile

    -- Ensure required keys exist
    if not profile.ui then
        profile.ui = LoolibTableUtil.DeepCopy(self.db.defaults.profile.ui)
    end

    -- Validate value ranges
    if profile.ui.scale < 0.5 or profile.ui.scale > 2.0 then
        profile.ui.scale = 1.0
    end

    -- Fix corrupted data
    if type(profile.settings) ~= "table" then
        profile.settings = {}
    end

    -- Clean up old data
    profile.deprecatedKey = nil
end

-- Run validation on profile change
MyAddon.db:RegisterCallback("OnProfileChanged", function()
    MyAddon:ValidateProfile()
end, MyAddon)
```

---

## Best Practices

### 1. Structuring Your Defaults

```lua
-- GOOD: Organized, hierarchical structure
local defaults = {
    profile = {
        ui = {
            frames = {
                main = { width = 400, height = 300 },
                minimap = { show = true, position = 45 }
            },
            scale = 1.0,
            alpha = 1.0
        },
        combat = {
            rotation = {},
            cooldowns = { autoUse = true }
        },
        features = {
            autoLoot = true,
            autoSell = false
        }
    },
    global = {
        version = "1.0.0",
        statistics = {
            totalLogins = 0,
            timePlayed = 0
        }
    },
    char = {
        state = {},
        cache = {}
    }
}

-- BAD: Flat, unorganized
local defaults = {
    profile = {
        frameWidth = 400,
        frameHeight = 300,
        minimapShow = true,
        minimapPos = 45,
        uiScale = 1.0,
        uiAlpha = 1.0,
        combatRotation = {},
        cooldownsAuto = true
        -- Hard to navigate!
    }
}
```

### 2. Profile Naming Conventions

```lua
-- GOOD: Descriptive, consistent names
"Default"
"Tank-Main"
"DPS-Raid"
"PvP-Arena"
"Solo-Questing"

-- BAD: Unclear, inconsistent
"asdf"
"Profile 1"
"test"
"sdfghjk"
```

### 3. When to Use Each Scope

```lua
-- Profile: Settings you want to share across characters
profile = {
    ui = { scale = 1.0, alpha = 1.0 },
    keybinds = { ... },
    preferences = { ... }
}

-- Global: Account-wide data that's not character or profile specific
global = {
    version = "1.0.0",
    accountStatistics = { ... },
    sharedData = { ... }
}

-- Char: Character-specific data that shouldn't be shared
char = {
    position = { x = 0, y = 0 },
    questState = { ... },
    equipment = { ... }
}

-- Realm: Realm economy, guilds, auction data
realm = {
    marketPrices = { ... },
    guildRoster = { ... }
}

-- Class: Class-specific settings (same for all characters of this class)
class = {
    specSettings = { ... },
    talentLoadouts = { ... }
}

-- Race: Race-specific settings (rarely used)
race = {
    racialSettings = { ... }
}

-- Faction: Faction-specific data (PvP, enemy lists)
faction = {
    enemyPlayers = { ... },
    warMode = true
}

-- FactionRealm: Faction-realm economy
factionrealm = {
    economyData = { ... },
    tradeskills = { ... }
}
```

### 4. Performance Optimization

```lua
-- GOOD: Cache scope access
function MyAddon:UpdateUI()
    local profile = self.db.profile  -- Cache

    frame:SetScale(profile.ui.scale)
    frame:SetAlpha(profile.ui.alpha)
    frame:SetWidth(profile.ui.width)
    frame:SetHeight(profile.ui.height)
end

-- BAD: Repeated scope access
function MyAddon:UpdateUI()
    frame:SetScale(self.db.profile.ui.scale)
    frame:SetAlpha(self.db.profile.ui.alpha)
    frame:SetWidth(self.db.profile.ui.width)
    frame:SetHeight(self.db.profile.ui.height)
end

-- GOOD: Batch changes
function MyAddon:ResetToDefaults()
    local profile = self.db.profile

    profile.ui.scale = 1.0
    profile.ui.alpha = 1.0
    profile.ui.width = 400
    profile.ui.height = 300
end

-- BAD: Individual Set calls (triggers callbacks each time)
function MyAddon:ResetToDefaults()
    self.db:Set("ui.scale", 1.0)
    self.db:Set("ui.alpha", 1.0)
    self.db:Set("ui.width", 400)
    self.db:Set("ui.height", 300)
end
```

### 5. When to Use Namespaces

```lua
-- GOOD: Large addon with distinct modules
BigAddon.db = CreateLoolibSavedVariables("BigAddonDB", mainDefaults)
BigAddon.combatDB = BigAddon.db:RegisterNamespace("Combat", combatDefaults)
BigAddon.uiDB = BigAddon.db:RegisterNamespace("UI", uiDefaults)
BigAddon.economyDB = BigAddon.db:RegisterNamespace("Economy", economyDefaults)

-- BAD: Small addon with tight coupling
SmallAddon.db = CreateLoolibSavedVariables("SmallAddonDB", defaults)
SmallAddon.namespace1 = SmallAddon.db:RegisterNamespace("Unnecessary", ...)
SmallAddon.namespace2 = SmallAddon.db:RegisterNamespace("Overkill", ...)

-- GOOD: Optional modules
CoreAddon.db = CreateLoolibSavedVariables("CoreDB", coreDefaults)

if OptionalModule1 then
    OptionalModule1.db = CoreAddon.db:RegisterNamespace("Module1", module1Defaults)
end

if OptionalModule2 then
    OptionalModule2.db = CoreAddon.db:RegisterNamespace("Module2", module2Defaults)
end
```

### 6. Callback Usage

```lua
-- GOOD: Targeted callbacks
db:RegisterCallback("OnProfileChanged", function(newProfile, oldProfile)
    MyAddon:RefreshUI()
    MyAddon:ReloadSettings()
end, MyAddon)

db:RegisterCallback("OnValueChanged", function(key, newValue, oldValue)
    if key:match("^ui%.") then
        MyAddon:UpdateUIElement(key, newValue)
    end
end, MyAddon)

-- BAD: Overly broad callbacks
db:RegisterCallback("OnValueChanged", function(key, newValue, oldValue)
    MyAddon:ReloadEverything()  -- Expensive!
end, MyAddon)
```

### 7. Error Handling

```lua
-- GOOD: Graceful error handling
function MyAddon:SwitchProfile(profileName)
    local success, err = pcall(function()
        self.db:SetProfile(profileName)
    end)

    if not success then
        print("Failed to switch profile:", err)
        return false
    end

    return true
end

-- GOOD: Validation before operations
function MyAddon:DeleteProfile(profileName)
    local profiles = self.db:GetProfiles()

    if #profiles <= 1 then
        print("Cannot delete the last profile")
        return false
    end

    if profileName == self.db:GetCurrentProfile() then
        print("Switch profiles before deleting")
        return false
    end

    return self.db:DeleteProfile(profileName)
end
```

### 8. TOC Declaration

```lua
-- Always declare SavedVariables in your TOC
## SavedVariables: MyAddonDB

-- For per-character variables, use SavedVariablesPerCharacter
## SavedVariablesPerCharacter: MyAddonCharDB

-- Multiple variables
## SavedVariables: MyAddonDB, MyAddonGlobal
## SavedVariablesPerCharacter: MyAddonChar
```

### 9. Version Management

```lua
local defaults = {
    global = {
        version = "1.0.0",
        dataVersion = 1  -- Separate data structure version
    }
}

function MyAddon:CheckVersion()
    local dataVersion = self.db.global.dataVersion or 1

    if dataVersion < 2 then
        self:MigrateToV2()
        self.db.global.dataVersion = 2
    end

    if dataVersion < 3 then
        self:MigrateToV3()
        self.db.global.dataVersion = 3
    end

    self.db.global.version = "1.2.0"  -- Current addon version
end
```

### 10. Testing Profile Functionality

```lua
function MyAddon:TestProfiles()
    -- Create test profiles
    local testProfiles = {"Test1", "Test2", "Test3"}

    for _, name in ipairs(testProfiles) do
        self.db:SetProfile(name)
        self.db.profile.testValue = name
    end

    -- Verify data isolation
    for _, name in ipairs(testProfiles) do
        self.db:SetProfile(name)
        assert(self.db.profile.testValue == name, "Profile data leaked!")
    end

    -- Clean up
    self.db:SetProfile("Default")
    for _, name in ipairs(testProfiles) do
        self.db:DeleteProfile(name, true)
    end

    print("Profile tests passed!")
end
```
