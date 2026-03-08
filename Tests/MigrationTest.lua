--[[--------------------------------------------------------------------
    Loolib Migration Module - Unit Tests
    Tests the Migration module functionality
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local Migration = Loolib:GetModule("Migration")

-- Simple test framework
local Tests = {
    passed = 0,
    failed = 0,
    results = {}
}

local function Assert(condition, message)
    if condition then
        Tests.passed = Tests.passed + 1
        table.insert(Tests.results, {pass = true, msg = message})
        return true
    else
        Tests.failed = Tests.failed + 1
        table.insert(Tests.results, {pass = false, msg = message})
        return false
    end
end

local function AssertEquals(actual, expected, message)
    return Assert(actual == expected,
        string.format("%s (expected: %s, got: %s)", message, tostring(expected), tostring(actual)))
end

local function AssertNotNil(value, message)
    return Assert(value ~= nil, message or "Value should not be nil")
end

local function PrintResults()
    print("\n=== Migration Module Test Results ===")
    print(string.format("Passed: %d, Failed: %d", Tests.passed, Tests.failed))

    if Tests.failed > 0 then
        print("\nFailed Tests:")
        for _, result in ipairs(Tests.results) do
            if not result.pass then
                print("  ✗", result.msg)
            end
        end
    end

    if Tests.passed == #Tests.results then
        print("\n✓ All tests passed!")
    end
end

--[[--------------------------------------------------------------------
    Version Comparison Tests
----------------------------------------------------------------------]]

local function TestVersionComparison()
    print("\n--- Testing Version Comparison ---")
    local Version = Migration.Version

    -- Test parsing
    local v1 = Version.Parse("1.2.3")
    AssertNotNil(v1, "Parse valid version")
    AssertEquals(v1.major, 1, "Parse major version")
    AssertEquals(v1.minor, 2, "Parse minor version")
    AssertEquals(v1.patch, 3, "Parse patch version")

    -- Test comparison
    AssertEquals(Version.Compare("1.0.0", "1.0.0"), 0, "Equal versions")
    AssertEquals(Version.Compare("1.0.0", "1.1.0"), -1, "Less than")
    AssertEquals(Version.Compare("2.0.0", "1.9.9"), 1, "Greater than")

    -- Test boolean comparisons
    Assert(Version.IsLessThan("1.0.0", "1.1.0"), "IsLessThan")
    Assert(Version.IsGreaterThan("2.0.0", "1.9.9"), "IsGreaterThan")
    Assert(Version.IsEqual("1.5.0", "1.5.0"), "IsEqual")
    Assert(Version.IsLessThanOrEqual("1.0.0", "1.0.0"), "IsLessThanOrEqual equal")
    Assert(Version.IsLessThanOrEqual("1.0.0", "1.1.0"), "IsLessThanOrEqual less")

    -- Test edge cases
    local v2 = Version.Parse("1.0")
    AssertNotNil(v2, "Parse short version")
    AssertEquals(v2.major, 1, "Short version major")
    AssertEquals(v2.minor, 0, "Short version minor")
    AssertEquals(v2.patch, 0, "Short version patch default")
end

--[[--------------------------------------------------------------------
    Migration Registration Tests
----------------------------------------------------------------------]]

local function TestMigrationRegistration()
    print("\n--- Testing Migration Registration ---")

    local migrations = Migration.Create()

    -- Register migrations
    migrations:RegisterMigration("1.0.0", function(db)
        db.test1 = true
    end)

    migrations:RegisterMigration("1.1.0", function(db)
        db.test2 = true
    end, {
        name = "Test Migration 1.1.0"
    })

    -- Test registration
    AssertEquals(migrations:GetMigrationCount(), 2, "Migration count")

    local versions = migrations:GetMigrationVersions()
    AssertEquals(#versions, 2, "Version list length")
    AssertEquals(versions[1], "1.0.0", "First version in order")
    AssertEquals(versions[2], "1.1.0", "Second version in order")

    -- Test migration info
    local info = migrations:GetMigrationInfo("1.1.0")
    AssertNotNil(info, "Get migration info")
    AssertEquals(info.name, "Test Migration 1.1.0", "Migration name")

    -- Test latest version
    AssertEquals(migrations:GetLatestVersion(), "1.1.0", "Latest version")
end

--[[--------------------------------------------------------------------
    Migration Execution Tests
----------------------------------------------------------------------]]

local function TestMigrationExecution()
    print("\n--- Testing Migration Execution ---")

    local migrations = Migration.Create({
        stopOnError = false,
        trackHistory = true
    })

    -- Create test database
    local db = {
        profile = {
            oldField = "value"
        },
        global = {}
    }

    -- Register migrations
    migrations:RegisterMigration("1.0.0", function(testDb)
        testDb.profile.newField = testDb.profile.oldField
        testDb.profile.oldField = nil
    end, {
        name = "Rename field"
    })

    migrations:RegisterMigration("1.1.0", function(testDb)
        testDb.global.cache = {}
    end, {
        name = "Add cache"
    })

    -- Run migrations
    local success, errors = migrations:RunMigrations(db, "1.1.0")

    Assert(success, "Migrations succeeded")
    AssertEquals(#errors, 0, "No errors")

    -- Check database was modified
    AssertEquals(db.profile.newField, "value", "Field was migrated")
    Assert(db.profile.oldField == nil, "Old field removed")
    AssertNotNil(db.global.cache, "Cache added")

    -- Check history
    Assert(migrations:IsMigrationExecuted(db, "1.0.0"), "Migration 1.0.0 in history")
    Assert(migrations:IsMigrationExecuted(db, "1.1.0"), "Migration 1.1.0 in history")

    local history = migrations:GetHistory(db)
    AssertEquals(#history, 2, "History count")
end

--[[--------------------------------------------------------------------
    Pending Migrations Tests
----------------------------------------------------------------------]]

local function TestPendingMigrations()
    print("\n--- Testing Pending Migrations ---")

    local migrations = Migration.Create()

    migrations:RegisterMigration("1.0.0", function(db) end)
    migrations:RegisterMigration("1.1.0", function(db) end)
    migrations:RegisterMigration("1.2.0", function(db) end)
    migrations:RegisterMigration("2.0.0", function(db) end)

    local db = {}

    -- Test all pending (no fromVersion)
    local pending = migrations:GetPendingMigrations(db, "2.0.0")
    AssertEquals(#pending, 4, "All migrations pending without fromVersion")

    -- Test partial pending (with fromVersion)
    pending = migrations:GetPendingMigrations(db, "2.0.0", "1.0.0")
    AssertEquals(#pending, 3, "Migrations after 1.0.0")

    pending = migrations:GetPendingMigrations(db, "1.1.0", "1.0.0")
    AssertEquals(#pending, 1, "Only 1.1.0 pending")

    -- Test none pending
    pending = migrations:GetPendingMigrations(db, "1.0.0", "2.0.0")
    AssertEquals(#pending, 0, "No migrations when fromVersion > currentVersion")

    -- Test HasPendingMigrations
    Assert(migrations:HasPendingMigrations(db, "2.0.0", "1.0.0"), "Has pending migrations")
    Assert(not migrations:HasPendingMigrations(db, "1.0.0", "2.0.0"), "No pending migrations")
end

--[[--------------------------------------------------------------------
    Error Handling Tests
----------------------------------------------------------------------]]

local function TestErrorHandling()
    print("\n--- Testing Error Handling ---")

    -- Test stopOnError = true
    local migrations1 = Migration.Create({ stopOnError = true })

    migrations1:RegisterMigration("1.0.0", function(db)
        db.success1 = true
    end)

    migrations1:RegisterMigration("1.1.0", function(db)
        error("Intentional error")
    end)

    migrations1:RegisterMigration("1.2.0", function(db)
        db.success2 = true
    end)

    local db1 = {}
    local success1, errors1 = migrations1:RunMigrations(db1, "1.2.0")

    Assert(not success1, "Migration failed with stopOnError")
    AssertEquals(#errors1, 1, "One error recorded")
    Assert(db1.success1 == true, "First migration ran")
    Assert(db1.success2 == nil, "Third migration skipped after error")

    -- Test stopOnError = false
    local migrations2 = Migration.Create({ stopOnError = false })

    migrations2:RegisterMigration("1.0.0", function(db)
        db.success1 = true
    end)

    migrations2:RegisterMigration("1.1.0", function(db)
        error("Intentional error")
    end)

    migrations2:RegisterMigration("1.2.0", function(db)
        db.success2 = true
    end)

    local db2 = {}
    local success2, errors2 = migrations2:RunMigrations(db2, "1.2.0")

    Assert(not success2, "Migration failed but continued")
    AssertEquals(#errors2, 1, "One error recorded")
    Assert(db2.success1 == true, "First migration ran")
    Assert(db2.success2 == true, "Third migration ran despite error")
end

--[[--------------------------------------------------------------------
    History Management Tests
----------------------------------------------------------------------]]

local function TestHistoryManagement()
    print("\n--- Testing History Management ---")

    local migrations = Migration.Create()

    migrations:RegisterMigration("1.0.0", function(db) end)
    migrations:RegisterMigration("1.1.0", function(db) end)

    local db = {}

    -- Run migrations
    migrations:RunMigrations(db, "1.1.0")

    -- Check history
    local history = migrations:GetHistory(db)
    AssertEquals(#history, 2, "History has 2 entries")

    -- Clear specific version
    migrations:ClearHistory(db, "1.0.0")
    history = migrations:GetHistory(db)
    AssertEquals(#history, 1, "History has 1 entry after clearing one")

    -- Clear all history
    migrations:ClearHistory(db)
    history = migrations:GetHistory(db)
    AssertEquals(#history, 0, "History empty after clearing all")

    -- Test reset history
    migrations:RunMigrations(db, "1.1.0")
    migrations:ResetHistory(db)
    history = migrations:GetHistory(db)
    AssertEquals(#history, 0, "History empty after reset")
end

--[[--------------------------------------------------------------------
    Run All Tests
----------------------------------------------------------------------]]

local function RunAllTests()
    print("=== Running Migration Module Tests ===")

    TestVersionComparison()
    TestMigrationRegistration()
    TestMigrationExecution()
    TestPendingMigrations()
    TestErrorHandling()
    TestHistoryManagement()

    PrintResults()
end

-- Run tests on slash command
SLASH_MIGRATIONTEST1 = "/testmigration"
SlashCmdList["MIGRATIONTEST"] = function()
    RunAllTests()
end

-- Auto-run on load (optional)
-- C_Timer.After(1, RunAllTests)

print("Migration tests loaded. Use /testmigration to run tests.")
