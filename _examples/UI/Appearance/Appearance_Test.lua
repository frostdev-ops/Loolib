--[[--------------------------------------------------------------------
    Appearance - Regression Tests

    Load this file and run /testappearance to execute tests.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local Appearance = Loolib.UI and Loolib.UI.Appearance

if not Appearance or not Appearance.Create then
    error("Appearance test requires Loolib.UI.Appearance", 2)
end

local testFrame = CreateFrame("Frame")
testFrame:RegisterEvent("PLAYER_LOGIN")
testFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    local tests = {}

    local function test(name, func)
        tests[#tests + 1] = { name = name, func = func }
    end

    local function assertTrue(condition, message)
        if not condition then
            error(message or "Assertion failed: expected true", 2)
        end
    end

    local function assertFalse(condition, message)
        if condition then
            error(message or "Assertion failed: expected false", 2)
        end
    end

    local function assertEquals(actual, expected, message)
        if actual ~= expected then
            error(string.format("%s: expected %s, got %s", message or "Assertion failed", tostring(expected), tostring(actual)), 2)
        end
    end

    test("RegisterFrame accepts real WoW frames", function()
        local appearance = Appearance.Create()
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")

        appearance:RegisterFrame(frame)

        assertTrue(appearance.registeredFrames[frame] == true, "Frame should be registered")
    end)

    test("ApplyToFrame skins real WoW frames", function()
        local appearance = Appearance.Create()
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")

        appearance:ApplyToFrame(frame)

        local backdrop = frame:GetBackdrop()
        assertTrue(type(backdrop) == "table", "Backdrop should be applied")
        assertEquals(backdrop.bgFile, appearance:GetBackgroundTexture(), "Background texture should match current skin")
        assertEquals(backdrop.edgeFile, appearance:GetBorderTexture(), "Border texture should match current skin")
    end)

    test("UpdateRegisteredFrames prunes dead frame references", function()
        local appearance = Appearance.Create()
        local deadFrame = setmetatable({}, {
            __index = {
                GetObjectType = function()
                    error("dead frame")
                end,
            },
        })

        appearance.registeredFrames[deadFrame] = true
        appearance:UpdateRegisteredFrames()

        assertFalse(appearance.registeredFrames[deadFrame], "Dead frame reference should be removed")
    end)

    test("Init drops malformed skins but keeps valid sanitized skins", function()
        local appearance = Appearance.Create({
            skins = {
                Valid = {
                    name = "Valid",
                    background = {
                        texture = "Interface\\DialogFrame\\UI-DialogBox-Background",
                        color = { r = 2, g = -1, b = 0.5, a = 4 },
                    },
                    border = {
                        texture = "Interface\\DialogFrame\\UI-DialogBox-Border",
                        color = { r = 0.2, g = 0.3, b = 0.4, a = -2 },
                    },
                },
                Invalid = {
                    name = "Invalid",
                    background = {
                        texture = "Interface\\DialogFrame\\UI-DialogBox-Background",
                        color = { r = "bad", g = 0, b = 0, a = 1 },
                    },
                    border = {
                        texture = "Interface\\DialogFrame\\UI-DialogBox-Border",
                        color = { r = 0, g = 0, b = 0, a = 1 },
                    },
                },
            },
            currentSkin = "Valid",
        })

        local valid = appearance:GetSkin("Valid")
        assertTrue(valid ~= nil, "Valid skin should be retained")
        assertTrue(appearance:GetSkin("Invalid") == nil, "Malformed skin should be dropped")
        assertEquals(valid.background.color.r, 1, "Valid skin colors should be clamped")
        assertEquals(valid.background.color.g, 0, "Valid skin colors should be clamped")
        assertEquals(valid.background.color.a, 1, "Valid skin alpha should be clamped")
        assertEquals(valid.border.color.a, 0, "Valid border alpha should be clamped")
    end)

    local function runTests()
        local passed = 0
        local failed = 0

        print("|cff00ff00=== Appearance Tests ===|r")

        for _, testCase in ipairs(tests) do
            local ok, err = pcall(testCase.func)
            if ok then
                passed = passed + 1
                print(string.format("|cff00ff00[PASS]|r %s", testCase.name))
            else
                failed = failed + 1
                print(string.format("|cffff0000[FAIL]|r %s: %s", testCase.name, err))
            end
        end

        print(string.format("\n|cff00ff00Passed: %d|r | |cffff0000Failed: %d|r | Total: %d", passed, failed, passed + failed))
    end

    SLASH_TESTAPPEARANCE1 = "/testappearance"
    SlashCmdList.TESTAPPEARANCE = runTests

    print("|cffffff00Appearance tests loaded. Use |cff00ff00/testappearance|r to run them.|r")
end)
