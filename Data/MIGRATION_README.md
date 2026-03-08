# Migration Module - Quick Reference

Location: `/mnt/Dongus/Loothing-Addon-Development/Loolib/Data/Migration.lua`

## Overview

The Migration module provides a comprehensive database migration system for addon version upgrades, following patterns from RCLootCouncil's BackwardsCompat.lua but with enhanced features.

## Features

- **Semantic Version Comparison** - Supports `1.0.0`, `1.1.0`, `2.0.0` format
- **Ordered Execution** - Migrations run in version order
- **History Tracking** - Prevents re-running migrations
- **Error Handling** - Configurable stop-on-error behavior
- **Event System** - Callbacks for migration lifecycle
- **Profile Support** - Works with SavedVariables profiles
- **Testing Support** - Manual migration execution and history management

## Quick Start

```lua
local Loolib = LibStub("Loolib")
local Migration = Loolib:GetModule("Migration")

-- Create migration manager
local migrations = Migration.Create()

-- Register migrations
migrations:RegisterMigration("1.1.0", function(db)
    db.profile.newField = db.profile.oldField
    db.profile.oldField = nil
end)

migrations:RegisterMigration("1.2.0", function(db)
    db.global.cache = {}
end)

-- Run migrations
local success, errors = migrations:RunMigrations(MyAddonDB, "1.2.0", "1.0.0")
```

## Key Components

### LoolibMigrationMixin

Main mixin providing migration functionality:

- `Init(options)` - Initialize with config
- `RegisterMigration(version, func, options)` - Register migration
- `RunMigrations(db, currentVer, fromVer)` - Run pending migrations
- `GetPendingMigrations(db, currentVer, fromVer)` - Get migrations that need to run
- `GetHistory(db)` - Get executed migrations
- `HasPendingMigrations(db, currentVer, fromVer)` - Check if migrations needed

### Version Utilities

Exported as `Migration.Version`:

- `Parse(versionStr)` - Parse version string
- `Compare(a, b)` - Compare versions (-1, 0, 1)
- `IsLessThan(a, b)` - Boolean comparison
- `IsGreaterThan(a, b)` - Boolean comparison
- `IsEqual(a, b)` - Boolean comparison

## Integration with SavedVariables

```lua
local db = Data.CreateSavedVariables("MyAddonDB", {
    profile = { enabled = true },
    global = { version = "1.0.0" }
})

local migrations = Migration.Create()
migrations:RegisterMigration("1.1.0", function(savedDb)
    savedDb.profile.newSetting = false
    savedDb.global.cache = {}
end)

db:OnReady(function()
    local currentVer = "1.1.0"
    local previousVer = db.global.version

    migrations:RunMigrations(db, currentVer, previousVer)
    db.global.version = currentVer
end)
```

## Migration Patterns

### Renaming Fields
```lua
migrations:RegisterMigration("1.1.0", function(db)
    db.profile.isEnabled = db.profile.enabled
    db.profile.enabled = nil
end)
```

### Restructuring Data
```lua
migrations:RegisterMigration("1.2.0", function(db)
    local old = db.profile.settings or {}
    db.profile.settings = {
        ui = { scale = old.scale or 1.0 },
        behavior = { autoLoot = old.autoLoot or false }
    }
end)
```

### Migrating All Profiles
```lua
migrations:RegisterMigration("2.0.0", function(db)
    for name, profile in pairs(db.profiles) do
        profile.newFeature = true
        profile.oldField = nil
    end
end)
```

### Converting Data Types
```lua
migrations:RegisterMigration("2.1.0", function(db)
    -- Array to map
    local oldList = db.profile.blacklist or {}
    local newMap = {}
    for _, name in ipairs(oldList) do
        newMap[name] = true
    end
    db.profile.blacklist = newMap
end)
```

## Events

- `OnMigrationStart(currentVer, fromVer, count)` - Migration process starts
- `OnMigrationExecuted(version, name)` - Single migration completes
- `OnMigrationError(version, error)` - Migration fails
- `OnMigrationComplete(currentVer, successCount, errorCount)` - Process completes

## Configuration Options

```lua
local migrations = Migration.Create({
    stopOnError = false,      -- Continue on errors (default: true)
    trackHistory = true,      -- Track executed migrations (default: true)
    logErrors = true,         -- Log errors to chat (default: true)
    historyKey = "_migHistory" -- DB key for history (default: "_migrationHistory")
})
```

## Files

- **Implementation**: `/mnt/Dongus/Loothing-Addon-Development/Loolib/Data/Migration.lua`
- **Documentation**: `/mnt/Dongus/Loothing-Addon-Development/Loolib/docs/Migration.md`
- **Example**: `/mnt/Dongus/Loothing-Addon-Development/Loolib/Examples/MigrationExample.lua`

## Dependencies

- `LibStub` - Library stub system
- `Loolib` - Core library (Core/Loolib.lua)
- `LoolibCallbackRegistryMixin` - Event system (Events/CallbackRegistry.lua)
- `LoolibCreateFromMixins` - Mixin utilities (Core/Mixin.lua)

## Testing

Manual migration testing:

```lua
-- Run specific migration
local success, err = migrations:RunMigration(db, "1.5.0", true)  -- force = true

-- Check if migration was executed
local executed = migrations:IsMigrationExecuted(db, "1.5.0")

-- Get pending migrations
local pending = migrations:GetPendingMigrations(db, "2.0.0", "1.5.0")

-- Reset history (for re-testing)
migrations:ResetHistory(db)
```

## Best Practices

1. **Always store version in database**
   ```lua
   db.global.version = CURRENT_VERSION
   ```

2. **Use descriptive migration names**
   ```lua
   migrations:RegisterMigration("2.0.0", migFunc, {
       name = "Restructure settings for v2.0"
   })
   ```

3. **Check data exists before migrating**
   ```lua
   if db.profile.oldField then
       db.profile.newField = db.profile.oldField
       db.profile.oldField = nil
   end
   ```

4. **Design one-way migrations** (no rollback support)

5. **Test migrations before release**
   ```lua
   migrations:RunMigration(TestDB, "1.5.0", true)
   ```

## Comparison with RCLootCouncil Pattern

### Similarities
- Version-based migration execution
- pcall error handling
- Support for executing migrations in order
- Tracking executed migrations

### Enhancements
- Proper semantic version comparison (not string comparison)
- Event system for migration lifecycle
- Configurable error handling
- History tracking with timestamps
- Version utility functions
- Better integration with modern Loolib systems
- Manual migration testing support

## Example Usage in Real Addon

```lua
local MyAddon = Loolib:NewAddon("MyAddon")
local CURRENT_VERSION = "2.1.0"

function MyAddon:OnInitialize()
    self.db = Data.CreateSavedVariables("MyAddonDB", defaults)
    self.migrations = Migration.Create()
    self:RegisterMigrations()
end

function MyAddon:RegisterMigrations()
    self.migrations:RegisterMigration("2.0.0", function(db)
        -- v2.0 migration
    end, { name = "Major v2.0 restructure" })

    self.migrations:RegisterMigration("2.1.0", function(db)
        -- v2.1 migration
    end, { name = "Add new features" })
end

function MyAddon:OnEnable()
    self.db:OnReady(function()
        local prevVer = self.db.global.version
        local success = self.migrations:RunMigrations(
            self.db, CURRENT_VERSION, prevVer
        )
        if success then
            self.db.global.version = CURRENT_VERSION
        end
    end)
end
```

## See Documentation

For complete API reference and examples, see:
- [Migration.md](../docs/Migration.md) - Full documentation
- [MigrationExample.lua](../Examples/MigrationExample.lua) - Working example
