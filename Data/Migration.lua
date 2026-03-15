--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Migration - Database and settings migration for addon version updates

    Provides a migration system for handling version upgrades:
    - Semantic version comparison (1.0.0 < 1.1.0 < 2.0.0)
    - Ordered migration execution based on version
    - Migration history tracking to prevent re-running
    - Error handling with configurable stop-on-error behavior
    - Support for both profile-specific and global migrations
    - Integration with SavedVariables system

    Usage:
        local Migration = Loolib:GetModule("Migration")
        local migrations = LoolibCreateFromMixins(LoolibMigrationMixin)
        migrations:Init({
            stopOnError = false,  -- Continue on errors
            trackHistory = true,  -- Track executed migrations
        })

        migrations:RegisterMigration("1.0.0", function(db)
            -- Migrate from pre-1.0.0 to 1.0.0
            db.profile.newField = db.profile.oldField
            db.profile.oldField = nil
        end)

        migrations:RegisterMigration("1.1.0", function(db)
            -- Migrate from 1.0.x to 1.1.0
            db.global.cache = {}
        end)

        -- Run all migrations needed to get to version 1.1.0
        local success, errors = migrations:RunMigrations(MyAddonDB, "1.1.0")

----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local error = error
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local time = time
local tostring = tostring
local type = type
local sort = table.sort
local format = string.format
local match = string.match
local wipe = wipe

local function GetRequiredModule(name)
    local module = Loolib:GetModule(name)
    if not module then
        error("Loolib module '" .. name .. "' is required", 2)
    end
    return module
end

local CallbackRegistryMixin = GetRequiredModule("CallbackRegistry").Mixin
-- FIX(critical-01): Use Loolib.CreateFromMixins directly instead of unstable "Mixin" module lookup
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required")

local Data = Loolib.Data or Loolib:GetOrCreateModule("Data")
Loolib.Data = Data

local MigrationModule = Data.Migration or Loolib:GetModule("Data.Migration") or {}
Loolib.Data.Migration = MigrationModule

--[[--------------------------------------------------------------------
    Semantic Version Comparison

    Supports versions like: "1.0.0", "2.3.1", "1.0.0-beta", "3.0.0-rc1"
----------------------------------------------------------------------]]

-- INTERNAL: Parse a version string into its component parts.
local function ParseVersion(versionStr)
    if type(versionStr) ~= "string" or versionStr == "" then
        return nil
    end

    -- Handle non-standard formats (try to extract numbers)
    local major, minor, patch, suffix = match(versionStr, "^(%d+)%.?(%d*)%.?(%d*)(.-)$")

    if not major then
        return nil
    end

    return {
        major = tonumber(major) or 0,
        minor = tonumber(minor) or 0,
        patch = tonumber(patch) or 0,
        suffix = suffix or "",
        original = versionStr,
    }
end

--- Compare two semantic versions
-- @param a string - First version (e.g., "1.0.0")
-- @param b string - Second version (e.g., "1.1.0")
-- @return number - -1 if a < b, 0 if a == b, 1 if a > b, nil if invalid
local function CompareVersions(a, b)
    local versionA = ParseVersion(a)
    local versionB = ParseVersion(b)

    if not versionA or not versionB then
        return nil
    end

    -- Compare major version
    if versionA.major ~= versionB.major then
        return versionA.major < versionB.major and -1 or 1
    end

    -- Compare minor version
    if versionA.minor ~= versionB.minor then
        return versionA.minor < versionB.minor and -1 or 1
    end

    -- Compare patch version
    if versionA.patch ~= versionB.patch then
        return versionA.patch < versionB.patch and -1 or 1
    end

    -- Versions are equal (we ignore suffix for now)
    return 0
end

-- INTERNAL: Check if version A is less than version B
-- @param a string - First version
-- @param b string - Second version
-- @return boolean
local function IsVersionLessThan(a, b)
    local result = CompareVersions(a, b)
    return result == -1
end

-- INTERNAL: Check if version A is less than or equal to version B
-- @param a string - First version
-- @param b string - Second version
-- @return boolean
local function IsVersionLessThanOrEqual(a, b)
    local result = CompareVersions(a, b)
    return result == -1 or result == 0
end

-- INTERNAL: Check if version A is greater than version B
-- @param a string - First version
-- @param b string - Second version
-- @return boolean
local function IsVersionGreaterThan(a, b)
    local result = CompareVersions(a, b)
    return result == 1
end

--[[--------------------------------------------------------------------
    LoolibMigrationMixin

    Provides migration management for addon databases.
----------------------------------------------------------------------]]

local MigrationMixin = MigrationModule.Mixin or CreateFromMixins(CallbackRegistryMixin)
Loolib.Data.Migration.Mixin = MigrationMixin

local MIGRATION_EVENTS = {
    "OnMigrationStart",      -- Fired when migration process starts
    "OnMigrationComplete",   -- Fired when migration process completes
    "OnMigrationError",      -- Fired when a migration fails
    "OnMigrationExecuted",   -- Fired when a single migration executes
}

--- Initialize the migration manager
-- @param options table - Configuration options
--   - stopOnError: boolean - Stop migrations on first error (default: true)
--   - trackHistory: boolean - Track executed migrations (default: true)
--   - logErrors: boolean - Log errors to chat (default: true)
--   - historyKey: string - Key in db to store history (default: "_migrationHistory")
function MigrationMixin:Init(options)
    if options ~= nil and type(options) ~= "table" then
        error("LoolibMigration: options must be a table or nil", 2)
    end

    CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(MIGRATION_EVENTS)

    options = options or {}

    self.migrations = {}           -- Registered migrations { version = func }
    self.executedMigrations = {}   -- Migrations executed this session
    self.options = {
        stopOnError = options.stopOnError ~= false,  -- Default: true
        trackHistory = options.trackHistory ~= false, -- Default: true
        logErrors = options.logErrors ~= false,      -- Default: true
        historyKey = options.historyKey or "_migrationHistory",
    }
end

--[[--------------------------------------------------------------------
    Migration Registration
----------------------------------------------------------------------]]

--- Register a migration for a specific version
-- Migrations are executed in version order when running migrations.
-- @param version string - The version this migration upgrades TO (e.g., "1.1.0")
-- @param migrationFunc function - Migration function(db, fromVersion, toVersion)
-- @param options table - Optional migration-specific options
--   - name: string - Optional name for this migration (for logging)
--   - scope: string - "global" or "profile" (default: both)
function MigrationMixin:RegisterMigration(version, migrationFunc, options)
    if type(version) ~= "string" or version == "" then
        error("LoolibMigration: migration version must be a non-empty string", 2)
    end

    if type(migrationFunc) ~= "function" then
        error("LoolibMigration: migration function must be a function", 2)
    end

    if not ParseVersion(version) then
        error(format("LoolibMigration: version '%s' is not a valid semantic version", version), 2)
    end

    if options ~= nil and type(options) ~= "table" then
        error("LoolibMigration: migration options must be a table or nil", 2)
    end

    options = options or {}

    if options.scope ~= nil and options.scope ~= "global" and options.scope ~= "profile" then
        error(format("LoolibMigration: invalid scope '%s', must be 'global', 'profile', or nil", tostring(options.scope)), 2)
    end

    self.migrations[version] = {
        version = version,
        func = migrationFunc,
        name = options.name,
        scope = options.scope,  -- "global", "profile", or nil (both)
    }
end

--- Unregister a migration
-- @param version string - The version to unregister
-- @return boolean - True if migration was removed
function MigrationMixin:UnregisterMigration(version)
    if type(version) ~= "string" then
        error("LoolibMigration: version must be a string", 2)
    end

    if self.migrations[version] then
        self.migrations[version] = nil
        return true
    end
    return false
end

--- Clear all registered migrations
function MigrationMixin:ClearMigrations()
    wipe(self.migrations)
end

--- Get all registered migration versions
-- @return table - Array of version strings, sorted
function MigrationMixin:GetMigrationVersions()
    local versions = {}
    for version in pairs(self.migrations) do
        versions[#versions + 1] = version
    end

    -- Sort by semantic version
    sort(versions, function(a, b)
        return IsVersionLessThan(a, b)
    end)

    return versions
end

--[[--------------------------------------------------------------------
    Migration Execution
----------------------------------------------------------------------]]

-- INTERNAL: Get migration history from database
-- @param db table - The database to check
-- @return table - Migration history { version -> timestamp }
function MigrationMixin:GetMigrationHistory(db)
    if not db or not self.options.trackHistory then
        return {}
    end

    local historyKey = self.options.historyKey
    local history = db[historyKey]
    if type(history) ~= "table" then
        return {}
    end

    return history
end

-- INTERNAL: Record a migration in history
-- @param db table - The database
-- @param version string - The migration version
function MigrationMixin:RecordMigration(db, version)
    if not db or not self.options.trackHistory then
        return
    end

    local historyKey = self.options.historyKey
    if type(db[historyKey]) ~= "table" then
        db[historyKey] = {}
    end

    db[historyKey][version] = time()
end

--- Check if a migration has been executed
-- @param db table - The database to check
-- @param version string - The migration version
-- @return boolean - True if migration was already executed
function MigrationMixin:IsMigrationExecuted(db, version)
    if not self.options.trackHistory then
        return false
    end

    local history = self:GetMigrationHistory(db)
    return history[version] ~= nil
end

--- Get migrations that need to run
-- @param db table - The database
-- @param currentVersion string - Current addon version
-- @param fromVersion string - Optional previous version (from db)
-- @return table - Array of migration entries to execute, in order
function MigrationMixin:GetPendingMigrations(db, currentVersion, fromVersion)
    if type(db) ~= "table" then
        error("LoolibMigration: db must be a table", 2)
    end

    if type(currentVersion) ~= "string" or currentVersion == "" then
        error("LoolibMigration: currentVersion must be a non-empty string", 2)
    end

    if not ParseVersion(currentVersion) then
        error(format("LoolibMigration: currentVersion '%s' is not a valid semantic version", currentVersion), 2)
    end

    if fromVersion ~= nil and type(fromVersion) ~= "string" then
        error("LoolibMigration: fromVersion must be a string or nil", 2)
    end

    local pending = {}
    local history = self:GetMigrationHistory(db)

    for version, migration in pairs(self.migrations) do
        local shouldRun = false

        -- Check if migration version is <= currentVersion
        if IsVersionLessThanOrEqual(version, currentVersion) then
            -- If we have fromVersion, only run migrations > fromVersion
            if fromVersion and fromVersion ~= "" then
                if IsVersionGreaterThan(version, fromVersion) then
                    shouldRun = true
                end
            else
                -- No fromVersion, run all migrations
                shouldRun = true
            end

            -- Don't re-run migrations already in history (idempotency guard)
            if shouldRun and history[version] then
                shouldRun = false
            end
        end

        if shouldRun then
            pending[#pending + 1] = migration
        end
    end

    -- Sort by version
    sort(pending, function(a, b)
        return IsVersionLessThan(a.version, b.version)
    end)

    return pending
end

--- Run all pending migrations
-- @param db table - The database to migrate
-- @param currentVersion string - Current addon version
-- @param fromVersion string - Optional previous version
-- @return boolean - True if all migrations succeeded
-- @return table - Array of error messages (if any)
function MigrationMixin:RunMigrations(db, currentVersion, fromVersion)
    if type(db) ~= "table" then
        error("LoolibMigration: db must be a table", 2)
    end

    if type(currentVersion) ~= "string" or currentVersion == "" then
        error("LoolibMigration: currentVersion must be a non-empty string", 2)
    end

    if not ParseVersion(currentVersion) then
        error(format("LoolibMigration: currentVersion '%s' is not a valid semantic version", currentVersion), 2)
    end

    if fromVersion ~= nil and type(fromVersion) ~= "string" then
        error("LoolibMigration: fromVersion must be a string or nil", 2)
    end

    -- Get pending migrations
    local pending = self:GetPendingMigrations(db, currentVersion, fromVersion)

    if #pending == 0 then
        -- No migrations to run
        return true, {}
    end

    -- Fire start event
    self:TriggerEvent("OnMigrationStart", currentVersion, fromVersion, #pending)

    local errors = {}
    local successCount = 0

    for _, migration in ipairs(pending) do
        local success, err = self:ExecuteMigration(migration, db, fromVersion, currentVersion)

        if success then
            successCount = successCount + 1

            -- Record in history
            self:RecordMigration(db, migration.version)

            -- Track in session
            self.executedMigrations[migration.version] = true

            -- Fire event
            self:TriggerEvent("OnMigrationExecuted", migration.version, migration.name)
        else
            -- Migration failed
            errors[#errors + 1] = {
                version = migration.version,
                name = migration.name,
                error = err,
            }

            -- Fire error event
            self:TriggerEvent("OnMigrationError", migration.version, err)

            -- Log error if enabled
            if self.options.logErrors then
                Loolib:Error("Migration failed:", migration.version, "-", err)
            end

            -- Stop on error if configured
            if self.options.stopOnError then
                break
            end
        end
    end

    -- Fire complete event
    local allSucceeded = #errors == 0
    self:TriggerEvent("OnMigrationComplete", currentVersion, successCount, #errors)

    return allSucceeded, errors
end

-- INTERNAL: Execute a single migration with pcall protection
-- @param migration table - Migration entry
-- @param db table - Database
-- @param fromVersion string - Previous version
-- @param toVersion string - Target version
-- @return boolean - Success
-- @return string - Error message if failed
function MigrationMixin:ExecuteMigration(migration, db, fromVersion, toVersion)
    if type(migration) ~= "table" or type(migration.func) ~= "function" then
        return false, "LoolibMigration: invalid migration entry (missing func)"
    end

    local success, err = pcall(migration.func, db, fromVersion, toVersion)

    if not success then
        return false, tostring(err)
    end

    return true, nil
end

--- Run a specific migration by version (for testing/manual execution)
-- @param db table - The database
-- @param version string - The migration version to run
-- @param force boolean - Force execution even if already in history
-- @return boolean - Success
-- @return string - Error message if failed
function MigrationMixin:RunMigration(db, version, force)
    if type(db) ~= "table" then
        error("LoolibMigration: db must be a table", 2)
    end

    if type(version) ~= "string" or version == "" then
        error("LoolibMigration: version must be a non-empty string", 2)
    end

    local migration = self.migrations[version]

    if not migration then
        return false, "Migration '" .. version .. "' not found"
    end

    -- Check if already executed (idempotency guard)
    if not force and self:IsMigrationExecuted(db, version) then
        return false, "Migration already executed (use force=true to re-run)"
    end

    local success, err = self:ExecuteMigration(migration, db, nil, version)

    if success then
        self:RecordMigration(db, version)
        self.executedMigrations[version] = true
        self:TriggerEvent("OnMigrationExecuted", version, migration.name)
    else
        self:TriggerEvent("OnMigrationError", version, err)
    end

    return success, err
end

--[[--------------------------------------------------------------------
    History Management
----------------------------------------------------------------------]]

--- Get the migration history for a database
-- @param db table - The database
-- @return table - Array of { version, timestamp, name } sorted by timestamp
function MigrationMixin:GetHistory(db)
    if type(db) ~= "table" then
        error("LoolibMigration: db must be a table", 2)
    end

    local history = self:GetMigrationHistory(db)
    local result = {}

    for version, timestamp in pairs(history) do
        local migration = self.migrations[version]
        result[#result + 1] = {
            version = version,
            timestamp = timestamp,
            name = migration and migration.name,
        }
    end

    -- Sort by timestamp
    sort(result, function(a, b)
        return a.timestamp < b.timestamp
    end)

    return result
end

--- Clear migration history
-- @param db table - The database
-- @param version string - Optional specific version to clear (clears all if nil)
function MigrationMixin:ClearHistory(db, version)
    if type(db) ~= "table" then
        error("LoolibMigration: db must be a table", 2)
    end

    if not self.options.trackHistory then
        return
    end

    local historyKey = self.options.historyKey
    if type(db[historyKey]) ~= "table" then
        return
    end

    if version then
        if type(version) ~= "string" then
            error("LoolibMigration: version must be a string", 2)
        end
        db[historyKey][version] = nil
    else
        wipe(db[historyKey])
    end
end

--- Reset migration history to allow re-running migrations
-- WARNING: This will cause all migrations to re-run on next RunMigrations call
-- @param db table - The database
function MigrationMixin:ResetHistory(db)
    if type(db) ~= "table" then
        error("LoolibMigration: db must be a table", 2)
    end

    self:ClearHistory(db)
    wipe(self.executedMigrations)
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Get information about a specific migration
-- @param version string - The migration version
-- @return table - Migration info { version, name, scope, registered }
function MigrationMixin:GetMigrationInfo(version)
    if type(version) ~= "string" then
        error("LoolibMigration: version must be a string", 2)
    end

    local migration = self.migrations[version]

    if not migration then
        return nil
    end

    return {
        version = migration.version,
        name = migration.name,
        scope = migration.scope,
        registered = true,
    }
end

--- Get count of registered migrations
-- @return number
function MigrationMixin:GetMigrationCount()
    local count = 0
    for _ in pairs(self.migrations) do
        count = count + 1
    end
    return count
end

--- Get the latest migration version
-- @return string - Latest version, or nil if no migrations
function MigrationMixin:GetLatestVersion()
    local versions = self:GetMigrationVersions()
    return versions[#versions]
end

--- Check if any migrations are pending
-- @param db table - The database
-- @param currentVersion string - Current version
-- @param fromVersion string - Optional previous version
-- @return boolean - True if migrations are pending
function MigrationMixin:HasPendingMigrations(db, currentVersion, fromVersion)
    local pending = self:GetPendingMigrations(db, currentVersion, fromVersion)
    return #pending > 0
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new migration manager
-- @param options table - Configuration options
-- @return table - Migration manager instance
local function CreateMigration(options)
    local migration = CreateFromMixins(MigrationMixin)
    migration:Init(options)
    return migration
end

--[[--------------------------------------------------------------------
    Version Utilities (exported for addon use)
----------------------------------------------------------------------]]

local VersionUtil = {
    Parse = ParseVersion,
    Compare = CompareVersions,
    IsLessThan = IsVersionLessThan,
    IsLessThanOrEqual = IsVersionLessThanOrEqual,
    IsGreaterThan = IsVersionGreaterThan,
    IsGreaterThanOrEqual = function(a, b)
        local result = CompareVersions(a, b)
        return result == 1 or result == 0
    end,
    IsEqual = function(a, b)
        local result = CompareVersions(a, b)
        return result == 0
    end,
}

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib.Data.Migration.Mixin = MigrationMixin
Loolib.Data.Migration.Create = CreateMigration
Loolib.Data.Migration.Version = VersionUtil
Loolib.Data.Migration = MigrationModule
Loolib.Data.CreateMigration = CreateMigration

Loolib:RegisterModule("Data.Migration", MigrationModule)
