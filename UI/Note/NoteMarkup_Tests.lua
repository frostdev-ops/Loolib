--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    UI/Note/NoteMarkup_Tests.lua - Test suite for NoteMarkup

    Manual test cases to verify conditional tag handling.
    Run these tests with /run in-game.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Only load if NoteMarkup module exists
if not Loolib:HasModule("NoteMarkup") then
    return
end

local NoteMarkup = Loolib:GetModule("NoteMarkup")

--[[--------------------------------------------------------------------
    Test Utilities
----------------------------------------------------------------------]]

local function PrintTestHeader(testName)
    print("|cff00ff00========================================|r")
    print("|cff00ff00TEST:|r", testName)
    print("|cff00ff00========================================|r")
end

local function PrintTestResult(name, expected, actual)
    local match = expected == actual
    local color = match and "|cff00ff00" or "|cffff0000"
    local status = match and "PASS" or "FAIL"

    print(color .. status .. "|r", name)
    if not match then
        print("  Expected:", expected)
        print("  Got:     ", actual)
    end
end

--[[--------------------------------------------------------------------
    Basic Role Tag Tests
----------------------------------------------------------------------]]

function LoolibTestNoteMarkup_RoleTags()
    PrintTestHeader("Role Tag Processing")

    local processor = NoteMarkup.Get()
    processor:UpdatePlayerContext()

    local role = processor:GetContext().playerRole
    print("Current role:", role)

    -- Test healer tag
    local healerText = "{H}Healer content{/H}"
    local result = processor:ProcessText(healerText)
    local expected = (role == "HEALER") and "Healer content" or ""
    PrintTestResult("Healer tag", expected, result)

    -- Test tank tag
    local tankText = "{T}Tank content{/T}"
    result = processor:ProcessText(tankText)
    expected = (role == "TANK") and "Tank content" or ""
    PrintTestResult("Tank tag", expected, result)

    -- Test DPS tag
    local dpsText = "{D}DPS content{/D}"
    result = processor:ProcessText(dpsText)
    expected = (role == "DAMAGER" or role == "DPS") and "DPS content" or ""
    PrintTestResult("DPS tag", expected, result)

    -- Test mixed content
    local mixedText = "{H}Heal{/H} Everyone {T}Tank{/T}"
    result = processor:ProcessText(mixedText)
    print("Mixed result:", result)
end

--[[--------------------------------------------------------------------
    Player Name Tag Tests
----------------------------------------------------------------------]]

function LoolibTestNoteMarkup_PlayerTags()
    PrintTestHeader("Player Name Tag Processing")

    local processor = NoteMarkup.Get()
    processor:UpdatePlayerContext()

    local playerName = processor:GetContext().playerName
    print("Current player:", playerName)

    -- Test exact match
    local text = "{P:" .. playerName .. "}This is for you{/P}"
    local result = processor:ProcessText(text)
    PrintTestResult("Exact name match", "This is for you", result)

    -- Test non-match
    text = "{P:NotYourName}Not for you{/P}"
    result = processor:ProcessText(text)
    PrintTestResult("Name non-match", "", result)

    -- Test negation
    text = "{!P:SomeoneElse}For everyone except SomeoneElse{/P}"
    result = processor:ProcessText(text)
    PrintTestResult("Negated player", "For everyone except SomeoneElse", result)

    -- Test comma-separated list (should match current player)
    text = "{P:" .. playerName .. ",Alice,Bob}In the list{/P}"
    result = processor:ProcessText(text)
    PrintTestResult("Comma-separated (match)", "In the list", result)

    -- Test comma-separated list (no match)
    text = "{P:Alice,Bob,Charlie}Not in list{/P}"
    result = processor:ProcessText(text)
    PrintTestResult("Comma-separated (no match)", "", result)
end

--[[--------------------------------------------------------------------
    Class Tag Tests
----------------------------------------------------------------------]]

function LoolibTestNoteMarkup_ClassTags()
    PrintTestHeader("Class Tag Processing")

    local processor = NoteMarkup.Get()
    processor:UpdatePlayerContext()

    local playerClass = processor:GetContext().playerClass
    print("Current class:", playerClass)

    -- Test exact match
    local text = "{C:" .. playerClass .. "}Class-specific{/C}"
    local result = processor:ProcessText(text)
    PrintTestResult("Exact class match", "Class-specific", result)

    -- Test non-match
    text = "{C:PALADIN}Paladin only{/C}"
    result = processor:ProcessText(text)
    local expected = (playerClass == "PALADIN") and "Paladin only" or ""
    PrintTestResult("Specific class", expected, result)

    -- Test negation
    text = "{!C:WARRIOR}Not warriors{/C}"
    result = processor:ProcessText(text)
    expected = (playerClass ~= "WARRIOR") and "Not warriors" or ""
    PrintTestResult("Negated class", expected, result)

    -- Test abbreviations
    text = "{C:MAG,LOCK}Casters{/C}"
    result = processor:ProcessText(text)
    expected = (playerClass == "MAGE" or playerClass == "WARLOCK") and "Casters" or ""
    PrintTestResult("Class abbreviations", expected, result)
end

--[[--------------------------------------------------------------------
    Group Tag Tests
----------------------------------------------------------------------]]

function LoolibTestNoteMarkup_GroupTags()
    PrintTestHeader("Group Tag Processing")

    local processor = NoteMarkup.Get()
    processor:UpdatePlayerContext()

    local playerGroup = processor:GetContext().playerGroup
    print("Current group:", playerGroup)

    -- Test single group
    local text = "{G" .. playerGroup .. "}Your group{/G}"
    local result = processor:ProcessText(text)
    PrintTestResult("Own group", "Your group", result)

    -- Test non-matching group
    local otherGroup = (playerGroup == 1) and 2 or 1
    text = "{G" .. otherGroup .. "}Other group{/G}"
    result = processor:ProcessText(text)
    PrintTestResult("Other group", "", result)

    -- Test multi-group (123 means groups 1, 2, or 3)
    text = "{G123}Groups 1-3{/G}"
    result = processor:ProcessText(text)
    expected = (playerGroup >= 1 and playerGroup <= 3) and "Groups 1-3" or ""
    PrintTestResult("Multi-group", expected, result)

    -- Test negation
    text = "{!G1}Not group 1{/G}"
    result = processor:ProcessText(text)
    expected = (playerGroup ~= 1) and "Not group 1" or ""
    PrintTestResult("Negated group", expected, result)
end

--[[--------------------------------------------------------------------
    Content Analysis Tests
----------------------------------------------------------------------]]

function LoolibTestNoteMarkup_ContentAnalysis()
    PrintTestHeader("Content Analysis")

    local processor = NoteMarkup.Get()

    -- Test HasVisibleContent
    local text = "{H}Healer{/H} {T}Tank{/T} {D}DPS{/D}"
    local hasContent = processor:HasVisibleContent(text)
    print("Has visible content:", hasContent)

    -- Test ExtractPlayerNames
    text = "{P:Alice}A{/P} {P:Bob,Charlie}BC{/P} {!P:Dave}D{/P}"
    local players = processor:ExtractPlayerNames(text)
    print("Extracted players:", table.concat(players, ", "))
    PrintTestResult("Extract 4 players", 4, #players)

    -- Test ExtractClasses
    text = "{C:MAGE}M{/C} {C:WARLOCK,PRIEST}WP{/C}"
    local classes = processor:ExtractClasses(text)
    print("Extracted classes:", table.concat(classes, ", "))
    PrintTestResult("Extract 3 classes", 3, #classes)

    -- Test ExtractRoles
    text = "{H}Healer{/H} {T}Tank{/T}"
    local roles = processor:ExtractRoles(text)
    print("Extracted roles:", table.concat(roles, ", "))
    PrintTestResult("Extract 2 roles", 2, #roles)

    -- Test ExtractGroups
    text = "{G1}G1{/G} {G234}G234{/G}"
    local groups = processor:ExtractGroups(text)
    print("Extracted groups:", table.concat(groups, ", "))
    PrintTestResult("Extract 4 groups", 4, #groups)
end

--[[--------------------------------------------------------------------
    Custom Context Tests
----------------------------------------------------------------------]]

function LoolibTestNoteMarkup_CustomContext()
    PrintTestHeader("Custom Context")

    local processor = LoolibCreateNoteMarkup()

    -- Set custom context
    processor:SetContext({
        playerName = "TestPlayer",
        playerRole = "HEALER",
        playerClass = "PRIEST",
        playerGroup = 2,
    })

    -- Test with custom context
    local text = "{P:TestPlayer}Match{/P}"
    local result = processor:ProcessText(text)
    PrintTestResult("Custom player name", "Match", result)

    text = "{H}Healer{/H}"
    result = processor:ProcessText(text)
    PrintTestResult("Custom role", "Healer", result)

    text = "{C:PRIEST}Priest{/C}"
    result = processor:ProcessText(text)
    PrintTestResult("Custom class", "Priest", result)

    text = "{G2}Group 2{/G}"
    result = processor:ProcessText(text)
    PrintTestResult("Custom group", "Group 2", result)
end

--[[--------------------------------------------------------------------
    Custom Handler Tests
----------------------------------------------------------------------]]

function LoolibTestNoteMarkup_CustomHandlers()
    PrintTestHeader("Custom Handlers")

    local processor = LoolibCreateNoteMarkup()
    processor:UpdatePlayerContext()

    -- Register custom handler
    processor:RegisterHandler("TESTCONDITION", function(node, context)
        return node.value == "show"
    end)

    -- Test custom condition (requires manual AST creation for this test)
    local node = {
        condition = "TESTCONDITION",
        value = "show",
    }
    local result = processor:EvaluateCondition(node)
    PrintTestResult("Custom handler (show)", true, result)

    node.value = "hide"
    result = processor:EvaluateCondition(node)
    PrintTestResult("Custom handler (hide)", false, result)

    -- Test unregister
    processor:UnregisterHandler("TESTCONDITION")
    result = processor:EvaluateCondition(node)
    PrintTestResult("After unregister (default true)", true, result)
end

--[[--------------------------------------------------------------------
    Complex Integration Test
----------------------------------------------------------------------]]

function LoolibTestNoteMarkup_Integration()
    PrintTestHeader("Complex Integration Test")

    local processor = NoteMarkup.Get()
    processor:UpdatePlayerContext()

    local context = processor:GetContext()
    print("Player:", context.playerName)
    print("Role:", context.playerRole)
    print("Class:", context.playerClass)
    print("Group:", context.playerGroup)

    local complexNote = [[
Boss Strategy

{H}
HEALERS:
- Dispel DoTs immediately
- Raid damage at 0:30
{/H}

{T}
TANKS:
- Taunt at 3 stacks
- Face boss away
{/T}

{D}
DPS:
- Kill adds first
- Burn boss after adds dead
{/D}

{P:]] .. context.playerName .. [[}
YOU: Special assignment!
{/P}

{C:MAGE,WARLOCK}
Casters: Use Lust at start
{/C}

{G123}
Groups 1-3: Go left
{/G}

Everyone: Dodge bad stuff!
]]

    local filtered = processor:ProcessText(complexNote)

    print("|cff00ff00Filtered Note:|r")
    print(filtered)
    print("")

    -- Verify it has content
    local hasContent = processor:HasVisibleContent(complexNote)
    PrintTestResult("Has visible content", true, hasContent)
end

--[[--------------------------------------------------------------------
    Run All Tests
----------------------------------------------------------------------]]

function LoolibTestNoteMarkup_All()
    LoolibTestNoteMarkup_RoleTags()
    print("")
    LoolibTestNoteMarkup_PlayerTags()
    print("")
    LoolibTestNoteMarkup_ClassTags()
    print("")
    LoolibTestNoteMarkup_GroupTags()
    print("")
    LoolibTestNoteMarkup_ContentAnalysis()
    print("")
    LoolibTestNoteMarkup_CustomContext()
    print("")
    LoolibTestNoteMarkup_CustomHandlers()
    print("")
    LoolibTestNoteMarkup_Integration()
end

-- Auto-register slash command for easy testing
if SlashCmdList then
    SLASH_LOOLIBTEST_NOTEMARKUP1 = "/loolib-test-notemarkup"
    SlashCmdList.LOOLIBTEST_NOTEMARKUP = function(msg)
        if msg == "role" then
            LoolibTestNoteMarkup_RoleTags()
        elseif msg == "player" then
            LoolibTestNoteMarkup_PlayerTags()
        elseif msg == "class" then
            LoolibTestNoteMarkup_ClassTags()
        elseif msg == "group" then
            LoolibTestNoteMarkup_GroupTags()
        elseif msg == "analysis" then
            LoolibTestNoteMarkup_ContentAnalysis()
        elseif msg == "context" then
            LoolibTestNoteMarkup_CustomContext()
        elseif msg == "handlers" then
            LoolibTestNoteMarkup_CustomHandlers()
        elseif msg == "integration" then
            LoolibTestNoteMarkup_Integration()
        else
            LoolibTestNoteMarkup_All()
        end
    end

    print("|cff00ff00Loolib NoteMarkup Tests loaded.|r")
    print("Run |cffff8800/loolib-test-notemarkup|r to run all tests")
    print("Or run specific tests: role, player, class, group, analysis, context, handlers, integration")
end
