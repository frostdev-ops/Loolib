# Migration Module

The Migration module provides a comprehensive system for managing database and settings migrations during addon version updates. It supports semantic versioning, ordered migration execution, history tracking, and error handling.

## Table of Contents

- [Overview](#overview)
- [Basic Usage](#basic-usage)
- [API Reference](#api-reference)
  - [LoolibMigrationMixin](#loolibmigrationmixin)
  - [Version Utilities](#version-utilities)
- [Migration Patterns](#migration-patterns)
- [Events](#events)
- [Best Practices](#best-practices)
- [Examples](#examples)

## Overview

The Migration module helps you safely upgrade your addon's database structure across versions:

- **Semantic Versioning**: Compares versions like `1.0.0`, `1.1.0`, `2.0.0`
- **Ordered Execution**: Runs migrations in version order
- **History Tracking**: Prevents re-running migrations (idempotency)
- **Error Handling**: Configurable stop-on-error behavior with structured error returns
- **Input Validation**: All public APIs validate types, version format, and db references
- **Scope Support**: Global and profile-specific migrations
- **Integration**: Works seamlessly with SavedVariables

### Input Validation

All public methods validate their arguments and raise descriptive errors prefixed with `LoolibMigration:`. For example:

```lua
-- These will error at the call site (level 2) with clear messages:
migrations:RegisterMigration(123, func)   -- "LoolibMigration: migration version must be a non-empty string"
migrations:RunMigrations(nil, "1.0.0")    -- "LoolibMigration: db must be a table"
migrations:RunMigrations(db, "bad")       -- "LoolibMigration: currentVersion 'bad' is not a valid semantic version"
```

### Internal vs Public APIs

Methods marked `-- INTERNAL` (`GetMigrationHistory`, `RecordMigration`, `ExecuteMigration`, `ParseVersion`) are implementation details. They are stable for now but may change without notice. Prefer the public API methods listed below.

## Basic Usage

### Creating a Migration Manager

```lua
local Loolib = LibStub("Loolib")
local Migration = Loolib:GetModule("Migration")

-- Create migration manager with default options
local myMigrations = LoolibCreateFromMixins(LoolibMigrationMixin)
myMigrations:Init()

-- Or use the factory function
local myMigrations = Migration.Create({
    stopOnError = false,    -- Continue on errors
    trackHistory = true,    -- Track executed migrations
    logErrors = true,       -- Log errors to chat
})
```

### Registering Migrations

```lua
-- Migration from any version to 1.0.0
myMigrations:RegisterMigration("1.0.0", function(db)
    -- Rename field
    db.profile.enabled = db.profile.enableAddon
    db.profile.enableAddon = nil
end)

-- Migration from 1.0.x to 1.1.0
myMigrations:RegisterMigration("1.1.0", function(db)
    -- Add new structure
    db.global.cache = {}
    db.profile.features = {
        feature1 = true,
        feature2 = false,
    }
end)

-- Migration with name for better logging
myMigrations:RegisterMigration("1.2.0", function(db)
    -- Convert array to map
    local oldList = db.profile.blacklist or {}
    db.profile.blacklist = {}
    for _, name in ipairs(oldList) do
        db.profile.blacklist[name] = true
    end
end, {
    name = "Convert blacklist to map",
})
```

### Running Migrations

```lua
-- In your addon's OnEnable or initialization
local currentVersion = "1.2.0"  -- Your current addon version
local previousVersion = MyAddonDB.global.version  -- Stored previous version

-- Run all pending migrations
local success, errors = myMigrations:RunMigrations(
    MyAddonDB,
    currentVersion,
    previousVersion
)

if success then
    -- All migrations succeeded
    MyAddonDB.global.version = currentVersion
else
    -- Some migrations failed
    for _, err in ipairs(errors) do
        print("Migration failed:", err.version, err.error)
    end
end
```

## API Reference

### LoolibMigrationMixin

The main mixin that provides migration functionality.

#### Init

Initialize the migration manager.

```lua
myMigrations:Init(options)
```

**Parameters:**
- `options` (table, optional) - Configuration options
  - `stopOnError` (boolean) - Stop on first error (default: `true`)
  - `trackHistory` (boolean) - Track executed migrations (default: `true`)
  - `logErrors` (boolean) - Log errors to chat (default: `true`)
  - `historyKey` (string) - Key in db to store history (default: `"_migrationHistory"`)

#### RegisterMigration

Register a migration for a specific version.

```lua
myMigrations:RegisterMigration(version, migrationFunc, options)
```

**Parameters:**
- `version` (string) - The version this migration upgrades TO (e.g., `"1.1.0"`)
- `migrationFunc` (function) - Migration function `(db, fromVersion, toVersion)`
  - `db` - The database being migrated
  - `fromVersion` - Previous version (may be nil)
  - `toVersion` - Target version
- `options` (table, optional)
  - `name` (string) - Optional name for this migration (for logging)
  - `scope` (string) - `"global"` or `"profile"` (default: both)

**Returns:** None

**Example:**
```lua
myMigrations:RegisterMigration("2.0.0", function(db, fromVer, toVer)
    print("Migrating from", fromVer, "to", toVer)
    db.profile.newStructure = {}
end, {
    name = "Initialize v2.0 structure"
})
```

#### RunMigrations

Run all pending migrations to upgrade to current version.

```lua
local success, errors = myMigrations:RunMigrations(db, currentVersion, fromVersion)
```

**Parameters:**
- `db` (table) - The database to migrate
- `currentVersion` (string) - Current addon version
- `fromVersion` (string, optional) - Previous version (from db)

**Returns:**
- `success` (boolean) - `true` if all migrations succeeded
- `errors` (table) - Array of error objects with fields:
  - `version` (string) - Migration version
  - `name` (string) - Migration name
  - `error` (string) - Error message

**Example:**
```lua
local success, errors = myMigrations:RunMigrations(MyDB, "2.1.0", "2.0.0")
if not success then
    for _, err in ipairs(errors) do
        print("Failed:", err.version, "-", err.error)
    end
end
```

#### RunMigration

Run a specific migration by version (for testing or manual execution).

```lua
local success, error = myMigrations:RunMigration(db, version, force)
```

**Parameters:**
- `db` (table) - The database
- `version` (string) - The migration version to run
- `force` (boolean, optional) - Force execution even if already in history

**Returns:**
- `success` (boolean) - `true` if migration succeeded
- `error` (string) - Error message if failed

#### GetPendingMigrations

Get migrations that need to run.

```lua
local pending = myMigrations:GetPendingMigrations(db, currentVersion, fromVersion)
```

**Parameters:**
- `db` (table) - The database
- `currentVersion` (string) - Current version
- `fromVersion` (string, optional) - Previous version

**Returns:**
- `pending` (table) - Array of migration entries to execute, in order

#### HasPendingMigrations

Check if any migrations are pending.

```lua
local hasPending = myMigrations:HasPendingMigrations(db, currentVersion, fromVersion)
```

**Returns:** `boolean` - `true` if migrations are pending

#### GetHistory

Get the migration history for a database.

```lua
local history = myMigrations:GetHistory(db)
```

**Returns:** Array of history entries with fields:
- `version` (string) - Migration version
- `timestamp` (number) - Unix timestamp when executed
- `name` (string) - Migration name (if provided)

#### ClearHistory

Clear migration history.

```lua
-- Clear all history
myMigrations:ClearHistory(db)

-- Clear specific version
myMigrations:ClearHistory(db, "1.0.0")
```

#### ResetHistory

Reset migration history to allow re-running all migrations.

```lua
myMigrations:ResetHistory(db)
```

**Warning:** This will cause all migrations to re-run on next `RunMigrations` call.

#### GetMigrationVersions

Get all registered migration versions.

```lua
local versions = myMigrations:GetMigrationVersions()
-- Returns: { "1.0.0", "1.1.0", "2.0.0" } (sorted)
```

#### GetMigrationCount

Get count of registered migrations.

```lua
local count = myMigrations:GetMigrationCount()
```

#### GetLatestVersion

Get the latest migration version.

```lua
local latest = myMigrations:GetLatestVersion()
-- Returns: "2.0.0" or nil if no migrations
```

### Version Utilities

The module exports version comparison utilities under `Migration.Version`.

```lua
local Version = Migration.Version

-- Parse version string
local parsed = Version.Parse("1.2.3")
-- Returns: { major = 1, minor = 2, patch = 3, suffix = "", original = "1.2.3" }

-- Compare versions
local result = Version.Compare("1.0.0", "1.1.0")
-- Returns: -1 (less than), 0 (equal), 1 (greater than)

-- Boolean comparisons
Version.IsLessThan("1.0.0", "1.1.0")           -- true
Version.IsLessThanOrEqual("1.1.0", "1.1.0")    -- true
Version.IsGreaterThan("2.0.0", "1.9.9")        -- true
Version.IsGreaterThanOrEqual("1.5.0", "1.5.0") -- true
Version.IsEqual("1.2.3", "1.2.3")              -- true
```

## Migration Patterns

### Pattern 1: Renaming Fields

```lua
myMigrations:RegisterMigration("1.1.0", function(db)
    -- Rename profile field
    db.profile.isEnabled = db.profile.enabled
    db.profile.enabled = nil

    -- Rename global field
    db.global.playerData = db.global.players
    db.global.players = nil
end)
```

### Pattern 2: Restructuring Data

```lua
myMigrations:RegisterMigration("1.2.0", function(db)
    -- Convert flat list to nested structure
    local oldSettings = db.profile.settings or {}
    db.profile.settings = {
        ui = {
            scale = oldSettings.scale or 1.0,
            position = oldSettings.position or "CENTER",
        },
        behavior = {
            autoLoot = oldSettings.autoLoot or false,
        }
    }
end)
```

### Pattern 3: Data Cleanup

```lua
myMigrations:RegisterMigration("1.3.0", function(db)
    -- Remove deprecated fields
    db.profile.oldFeature = nil
    db.profile.deprecatedSetting = nil

    -- Clear cache
    db.global.cache = {}
end)
```

### Pattern 4: Migrating All Profiles

```lua
myMigrations:RegisterMigration("2.0.0", function(db)
    -- Migrate all profiles
    if db.profiles then
        for profileName, profileData in pairs(db.profiles) do
            -- Update each profile
            profileData.version2Feature = true
            profileData.oldVersion1Feature = nil
        end
    end
end)
```

### Pattern 5: Converting Data Types

```lua
myMigrations:RegisterMigration("2.1.0", function(db)
    -- Convert array to map
    if db.profile.blacklist and type(db.profile.blacklist) == "table" then
        local oldList = db.profile.blacklist
        if oldList[1] then  -- Is it an array?
            local newMap = {}
            for _, name in ipairs(oldList) do
                newMap[name] = true
            end
            db.profile.blacklist = newMap
        end
    end
end)
```

### Pattern 6: Database Schema Changes

```lua
myMigrations:RegisterMigration("3.0.0", function(db)
    -- Add new structure
    db.global.metadata = {
        created = time(),
        version = "3.0.0",
        migrations = {},
    }

    -- Initialize new profile fields
    if db.profiles then
        for _, profileData in pairs(db.profiles) do
            profileData.layout = profileData.layout or "default"
            profileData.theme = profileData.theme or "dark"
        end
    end
end)
```

## Events

The Migration module fires events during the migration process:

### OnMigrationStart

Fired when migration process starts.

```lua
myMigrations:RegisterCallback("OnMigrationStart", function(currentVersion, fromVersion, count)
    print("Starting", count, "migrations to version", currentVersion)
end)
```

**Parameters:**
- `currentVersion` (string) - Target version
- `fromVersion` (string) - Previous version
- `count` (number) - Number of pending migrations

### OnMigrationExecuted

Fired when a single migration executes successfully.

```lua
myMigrations:RegisterCallback("OnMigrationExecuted", function(version, name)
    print("Executed migration:", version, name or "")
end)
```

**Parameters:**
- `version` (string) - Migration version
- `name` (string) - Migration name (if provided)

### OnMigrationError

Fired when a migration fails.

```lua
myMigrations:RegisterCallback("OnMigrationError", function(version, error)
    print("Migration error:", version, "-", error)
end)
```

**Parameters:**
- `version` (string) - Migration version
- `error` (string) - Error message

### OnMigrationComplete

Fired when migration process completes.

```lua
myMigrations:RegisterCallback("OnMigrationComplete", function(currentVersion, successCount, errorCount)
    print("Migrations complete:", successCount, "succeeded,", errorCount, "failed")
end)
```

**Parameters:**
- `currentVersion` (string) - Target version
- `successCount` (number) - Number of successful migrations
- `errorCount` (number) - Number of failed migrations

## Best Practices

### 1. Version Storage

Always store the current version in your database:

```lua
-- On first load
if not MyAddonDB.global.version then
    MyAddonDB.global.version = "1.0.0"  -- Initial version
end

-- After successful migrations
local success = myMigrations:RunMigrations(MyAddonDB, CURRENT_VERSION, MyAddonDB.global.version)
if success then
    MyAddonDB.global.version = CURRENT_VERSION
end
```

### 2. Migration Naming

Use descriptive names for complex migrations:

```lua
myMigrations:RegisterMigration("2.0.0", function(db)
    -- Complex migration
end, {
    name = "Restructure settings for v2.0"
})
```

### 3. Defensive Coding

Always check if data exists before migrating:

```lua
myMigrations:RegisterMigration("1.5.0", function(db)
    -- Check if field exists
    if db.profile.oldField then
        db.profile.newField = db.profile.oldField
        db.profile.oldField = nil
    end

    -- Initialize if missing
    db.global.cache = db.global.cache or {}
end)
```

### 4. Error Handling

Wrap risky operations in pcall within migrations:

```lua
myMigrations:RegisterMigration("1.6.0", function(db)
    local success, err = pcall(function()
        -- Risky operation
        local data = ComplexDataTransform(db.profile.data)
        db.profile.data = data
    end)

    if not success then
        -- Fallback
        db.profile.data = {}
    end
end)
```

### 5. Testing Migrations

Test migrations manually before release:

```lua
-- Test a specific migration
local success, err = myMigrations:RunMigration(TestDB, "1.5.0", true)  -- force = true
```

### 6. One-Way Migrations

Design migrations to be one-way (no rollback):

```lua
-- GOOD: One-way migration
myMigrations:RegisterMigration("2.0.0", function(db)
    db.profile.newStructure = TransformOldData(db.profile.oldData)
    db.profile.oldData = nil  -- Remove old data
end)

-- BAD: Don't try to support rollback
-- (Migrations should only go forward)
```

### 7. Large Data Migrations

For large datasets, show progress or use throttling:

```lua
myMigrations:RegisterMigration("3.0.0", function(db)
    -- Large dataset migration
    local count = 0
    for id, item in pairs(db.global.items) do
        -- Transform item
        item.v3Format = true
        item.oldField = nil

        count = count + 1
        if count % 1000 == 0 then
            print("Migrated", count, "items...")
        end
    end
end, {
    name = "Convert item database to v3.0 format"
})
```

## Examples

### Example 1: Basic Version Upgrade

```lua
local Loolib = LibStub("Loolib")
local Migration = Loolib:GetModule("Migration")

local MyAddon = {}
local ADDON_VERSION = "1.2.0"

function MyAddon:OnEnable()
    -- Initialize migrations
    self.migrations = Migration.Create()

    -- Register migrations
    self.migrations:RegisterMigration("1.1.0", function(db)
        db.profile.newFeature = true
    end)

    self.migrations:RegisterMigration("1.2.0", function(db)
        db.global.cache = {}
    end)

    -- Run migrations
    local previousVersion = MyAddonDB.global.version
    local success, errors = self.migrations:RunMigrations(
        MyAddonDB,
        ADDON_VERSION,
        previousVersion
    )

    if success then
        MyAddonDB.global.version = ADDON_VERSION
        print("Addon updated to version", ADDON_VERSION)
    else
        print("Some migrations failed!")
    end
end
```

### Example 2: Migration with Callbacks

```lua
local migrations = Migration.Create()

-- Register callbacks
migrations:RegisterCallback("OnMigrationStart", function(currentVer, fromVer, count)
    print(string.format("Migrating from %s to %s (%d migrations)",
        fromVer or "unknown", currentVer, count))
end)

migrations:RegisterCallback("OnMigrationExecuted", function(version, name)
    print("  ✓ Migration", version, "complete")
end)

migrations:RegisterCallback("OnMigrationError", function(version, error)
    print("  ✗ Migration", version, "failed:", error)
end)

-- Register migrations
migrations:RegisterMigration("2.0.0", function(db)
    -- Migration code
end, {
    name = "Major restructure for v2.0"
})

-- Run with callbacks
migrations:RunMigrations(MyDB, "2.0.0")
```

### Example 3: Profile-Specific Migrations

```lua
local migrations = Migration.Create()

-- Register a global-only migration
migrations:RegisterMigration("1.5.0", function(db)
    db.global.newGlobalData = {}
end, {
    scope = "global",
    name = "Add global data structure"
})

-- Register profile-specific migration
migrations:RegisterMigration("1.6.0", function(db)
    -- Migrate all profiles
    for name, profile in pairs(db.profiles or {}) do
        profile.perProfileSetting = true
    end
end, {
    scope = "profile",
    name = "Add per-profile settings"
})
```

### Example 4: Conditional Migrations

```lua
migrations:RegisterMigration("2.1.0", function(db, fromVer, toVer)
    -- Only run certain changes if upgrading from specific versions
    local Version = Migration.Version

    if fromVer and Version.IsLessThan(fromVer, "2.0.0") then
        -- This user is upgrading from pre-2.0
        db.profile.legacyMigration = true
    end

    -- Always run this part
    db.profile.version21Feature = true
end)
```

### Example 5: Integration with SavedVariables

```lua
local Loolib = LibStub("Loolib")
local Data = Loolib:GetModule("Data")
local Migration = Loolib:GetModule("Migration")

-- Create SavedVariables
local db = Data.CreateSavedVariables("MyAddonDB", {
    profile = {
        enabled = true,
    },
    global = {
        version = "1.0.0",
    }
})

-- Create migrations
local migrations = Migration.Create()

migrations:RegisterMigration("1.1.0", function(savedDb)
    -- Access current profile
    savedDb.profile.newSetting = false

    -- Access global
    savedDb.global.cache = {}
end)

-- Run on initialization
db:OnReady(function()
    local currentVer = "1.1.0"
    local previousVer = db.global.version

    local success = migrations:RunMigrations(db, currentVer, previousVer)
    if success then
        db.global.version = currentVer
    end
end)
```

---

## See Also

- [SavedVariables.md](SavedVariables.md) - Data persistence system
- [ProfileManager.md](ProfileManager.md) - Profile management
- [Logger.md](Logger.md) - Logging system for migration debugging
