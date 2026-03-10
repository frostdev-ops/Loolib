--[[--------------------------------------------------------------------
    Loolib Migration Example
    Demonstrates the Migration module for version upgrades

    This example shows how to:
    - Set up a migration manager
    - Register migrations for different versions
    - Run migrations when addon version changes
    - Handle migration errors
    - Track migration history
----------------------------------------------------------------------]]

-- Simulate LibStub and Loolib being available
-- (In real addon, these would already be loaded)
local Loolib = LibStub("Loolib")
local Migration = Loolib:GetModule("Migration")
local Data = Loolib:GetModule("Data")

--[[--------------------------------------------------------------------
    Example Addon with Migrations
----------------------------------------------------------------------]]

local MyAddon = {
    VERSION = "2.1.0",
    ADDON_NAME = "MyExampleAddon",
}

--- Initialize the addon
function MyAddon:OnInitialize()
    print("Initializing", self.ADDON_NAME, "version", self.VERSION)

    -- Create SavedVariables database
    self.db = Data.CreateSavedVariables("MyAddonDB", {
        profile = {
            enabled = true,
            scale = 1.0,
            position = "CENTER",
        },
        global = {
            version = nil,  -- Will be set after migrations
            cache = {},
        }
    })

    -- Create migration manager
    self.migrations = Migration.Create({
        stopOnError = false,  -- Continue even if one migration fails
        trackHistory = true,  -- Track executed migrations
        logErrors = true,     -- Log errors to chat
    })

    -- Register migration callbacks
    self:SetupMigrationCallbacks()

    -- Register all migrations
    self:RegisterMigrations()
end

--- Set up migration event callbacks
function MyAddon:SetupMigrationCallbacks()
    self.migrations:RegisterCallback("OnMigrationStart", function(currentVer, fromVer, count)
        print(string.format("[%s] Starting %d migrations from %s to %s",
            self.ADDON_NAME, count, fromVer or "initial install", currentVer))
    end)

    self.migrations:RegisterCallback("OnMigrationExecuted", function(version, name)
        print(string.format("[%s]   ✓ Migration %s complete%s",
            self.ADDON_NAME, version, name and (" - " .. name) or ""))
    end)

    self.migrations:RegisterCallback("OnMigrationError", function(version, error)
        print(string.format("[%s]   ✗ Migration %s failed: %s",
            self.ADDON_NAME, version, error))
    end)

    self.migrations:RegisterCallback("OnMigrationComplete", function(currentVer, successCount, errorCount)
        if errorCount == 0 then
            print(string.format("[%s] All %d migrations completed successfully!",
                self.ADDON_NAME, successCount))
        else
            print(string.format("[%s] Migrations complete: %d succeeded, %d failed",
                self.ADDON_NAME, successCount, errorCount))
        end
    end)
end

--- Register all version migrations
function MyAddon:RegisterMigrations()
    -- Migration to 1.1.0 - Add new settings structure
    self.migrations:RegisterMigration("1.1.0", function(db)
        -- Restructure settings
        if db.profile.scale and db.profile.position then
            db.profile.ui = {
                scale = db.profile.scale,
                position = db.profile.position,
            }
            -- Remove old fields (but keep for backward compat check)
            -- db.profile.scale = nil
            -- db.profile.position = nil
        end

        -- Initialize new feature
        db.profile.autoLoot = false
    end, {
        name = "Restructure UI settings"
    })

    -- Migration to 1.2.0 - Convert blacklist to map
    self.migrations:RegisterMigration("1.2.0", function(db)
        -- Convert blacklist from array to map for O(1) lookup
        if db.profile.blacklist and type(db.profile.blacklist) == "table" then
            local oldList = db.profile.blacklist
            -- Check if it's an array
            if oldList[1] then
                local newMap = {}
                for _, name in ipairs(oldList) do
                    newMap[name] = true
                end
                db.profile.blacklist = newMap
            end
        else
            db.profile.blacklist = {}
        end
    end, {
        name = "Convert blacklist to map"
    })

    -- Migration to 1.3.0 - Remove deprecated feature
    self.migrations:RegisterMigration("1.3.0", function(db)
        -- Remove old feature that was replaced
        db.profile.oldFeature = nil

        -- Clear cache for fresh start
        db.global.cache = {}
    end, {
        name = "Remove deprecated features"
    })

    -- Migration to 2.0.0 - Major restructure
    self.migrations:RegisterMigration("2.0.0", function(db, fromVer)
        local Version = Migration.Version

        -- Check if upgrading from pre-2.0
        if fromVer and Version.IsLessThan(fromVer, "2.0.0") then
            print("  [Info] Upgrading from pre-2.0, applying legacy migration")

            -- Migrate all profiles
            if db.profiles then
                for profileName, profileData in pairs(db.profiles) do
                    -- Add v2.0 structure
                    profileData.features = {
                        feature1 = true,
                        feature2 = false,
                    }

                    -- Convert old settings if they exist
                    if profileData.ui then
                        profileData.ui.theme = "default"
                    end
                end
            end
        end

        -- Initialize new global structure
        db.global.metadata = {
            created = time(),
            addonVersion = "2.0.0",
        }
    end, {
        name = "Major v2.0 restructure"
    })

    -- Migration to 2.1.0 - Add player cache
    self.migrations:RegisterMigration("2.1.0", function(db)
        -- Add player cache
        db.global.playerCache = {}

        -- Add new profile settings
        if db.profiles then
            for _, profileData in pairs(db.profiles) do
                profileData.syncEnabled = true
            end
        end
    end, {
        name = "Add player cache and sync"
    })
end

--- Run migrations when addon enables
function MyAddon:OnEnable()
    print(string.format("[%s] OnEnable called", self.ADDON_NAME))

    -- Wait for database to be ready
    self.db:OnReady(function()
        local previousVersion = self.db.global.version
        local currentVersion = self.VERSION

        print(string.format("[%s] Database ready. Previous version: %s, Current: %s",
            self.ADDON_NAME, previousVersion or "none", currentVersion))

        -- Check if migrations are needed
        if self.migrations:HasPendingMigrations(self.db, currentVersion, previousVersion) then
            -- Run migrations
            local success, errors = self.migrations:RunMigrations(
                self.db,
                currentVersion,
                previousVersion
            )

            if success then
                -- Update stored version
                self.db.global.version = currentVersion
                print(string.format("[%s] Successfully upgraded to version %s",
                    self.ADDON_NAME, currentVersion))
            else
                -- Migrations had errors
                print(string.format("[%s] WARNING: Some migrations failed!", self.ADDON_NAME))
                for _, err in ipairs(errors) do
                    print(string.format("  - %s: %s", err.version, err.error))
                end

                -- Still update version (since we continue on error)
                self.db.global.version = currentVersion
            end
        else
            print(string.format("[%s] No migrations needed", self.ADDON_NAME))

            -- First install or already up to date
            if not previousVersion then
                print(string.format("[%s] First install detected", self.ADDON_NAME))
                self.db.global.version = currentVersion
            end
        end

        -- Show migration history
        self:ShowMigrationHistory()
    end)
end

--- Display migration history
function MyAddon:ShowMigrationHistory()
    local history = self.migrations:GetHistory(self.db)

    if #history == 0 then
        print(string.format("[%s] No migration history", self.ADDON_NAME))
        return
    end

    print(string.format("[%s] Migration History:", self.ADDON_NAME))
    for _, entry in ipairs(history) do
        local dateStr = date("%Y-%m-%d %H:%M:%S", entry.timestamp)
        print(string.format("  - %s: %s%s",
            entry.version,
            dateStr,
            entry.name and (" (" .. entry.name .. ")") or ""
        ))
    end
end

--[[--------------------------------------------------------------------
    Command Line Testing Interface
----------------------------------------------------------------------]]

function MyAddon:ShowMigrationInfo()
    print(string.format("[%s] Migration Information:", self.ADDON_NAME))
    print(string.format("  Current Version: %s", self.VERSION))
    print(string.format("  Database Version: %s", self.db.global.version or "none"))
    print(string.format("  Registered Migrations: %d", self.migrations:GetMigrationCount()))

    local versions = self.migrations:GetMigrationVersions()
    print("  Migration Versions:")
    for _, version in ipairs(versions) do
        local info = self.migrations:GetMigrationInfo(version)
        local executed = self.migrations:IsMigrationExecuted(self.db, version)
        print(string.format("    - %s%s%s",
            version,
            info.name and (" - " .. info.name) or "",
            executed and " [EXECUTED]" or " [PENDING]"
        ))
    end
end

--- Reset migrations (for testing)
function MyAddon:ResetMigrations()
    print(string.format("[%s] Resetting migration history...", self.ADDON_NAME))
    self.migrations:ResetHistory(self.db)
    self.db.global.version = nil
    print("  Migration history cleared. Re-enable addon to run migrations again.")
end

--- Manually run a specific migration (for testing)
function MyAddon:RunSpecificMigration(version, force)
    print(string.format("[%s] Running migration %s...", self.ADDON_NAME, version))

    local success, err = self.migrations:RunMigration(self.db, version, force)

    if success then
        print(string.format("  ✓ Migration %s completed successfully", version))
    else
        print(string.format("  ✗ Migration %s failed: %s", version, err))
    end
end

--[[--------------------------------------------------------------------
    Example Slash Commands
----------------------------------------------------------------------]]

SLASH_MYMIGRATIONTEST1 = "/migtest"
SlashCmdList["MYMIGRATIONTEST"] = function(msg)
    local cmd, arg = strsplit(" ", msg, 2)

    if cmd == "info" then
        MyAddon:ShowMigrationInfo()

    elseif cmd == "history" then
        MyAddon:ShowMigrationHistory()

    elseif cmd == "reset" then
        MyAddon:ResetMigrations()

    elseif cmd == "run" then
        if arg then
            MyAddon:RunSpecificMigration(arg, false)
        else
            print("Usage: /migtest run <version>")
        end

    elseif cmd == "force" then
        if arg then
            MyAddon:RunSpecificMigration(arg, true)
        else
            print("Usage: /migtest force <version>")
        end

    else
        print("Migration Test Commands:")
        print("  /migtest info     - Show migration information")
        print("  /migtest history  - Show migration history")
        print("  /migtest reset    - Reset migration history")
        print("  /migtest run <v>  - Run specific migration")
        print("  /migtest force <v> - Force run migration")
    end
end

--[[--------------------------------------------------------------------
    Example Version Comparison Usage
----------------------------------------------------------------------]]

local function VersionComparisonExamples()
    local Version = Migration.Version

    print("=== Version Comparison Examples ===")

    -- Parse versions
    local v1 = Version.Parse("1.2.3")
    print(string.format("Parsed 1.2.3: major=%d, minor=%d, patch=%d",
        v1.major, v1.minor, v1.patch))

    -- Compare versions
    print(string.format("1.0.0 < 1.1.0: %s", tostring(Version.IsLessThan("1.0.0", "1.1.0"))))
    print(string.format("2.0.0 > 1.9.9: %s", tostring(Version.IsGreaterThan("2.0.0", "1.9.9"))))
    print(string.format("1.5.0 == 1.5.0: %s", tostring(Version.IsEqual("1.5.0", "1.5.0"))))

    -- Practical example
    local dbVersion = "1.2.0"
    local addonVersion = "2.0.0"

    if Version.IsLessThan(dbVersion, addonVersion) then
        print(string.format("Database version (%s) is older than addon version (%s) - migrations needed",
            dbVersion, addonVersion))
    end
end

--[[--------------------------------------------------------------------
    Initialize Example Addon
----------------------------------------------------------------------]]

-- Run on ADDON_LOADED
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == MyAddon.ADDON_NAME then
        MyAddon:OnInitialize()

        -- Register for PLAYER_LOGIN
        frame:RegisterEvent("PLAYER_LOGIN")
        frame:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Run on PLAYER_LOGIN
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        MyAddon:OnEnable()

        -- Show version comparison examples
        VersionComparisonExamples()
    end
end)

--[[--------------------------------------------------------------------
    Usage Examples in Chat:

    After enabling this addon, try these commands:

    /migtest info      - Show current migration state
    /migtest history   - Show executed migrations
    /migtest reset     - Clear migration history and re-run
    /migtest run 2.0.0 - Run specific migration
    /migtest force 1.1.0 - Force re-run a migration

    Example workflow:
    1. Load addon (runs migrations automatically)
    2. /migtest info - See what migrations ran
    3. /migtest history - See when they ran
    4. /migtest reset - Clear history
    5. /reload - Reload to run migrations again
----------------------------------------------------------------------]]
