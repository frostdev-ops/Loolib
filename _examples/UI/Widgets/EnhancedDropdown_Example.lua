--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    EnhancedDropdown Usage Examples

    This file demonstrates the various features of the EnhancedDropdown widget.
    Not loaded by default - use as reference for implementation.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- ============================================================
-- EXAMPLE 1: Basic Dropdown
-- ============================================================

local function Example_BasicDropdown(parent)
    local dropdown = LoolibCreateEnhancedDropdown(parent)
    dropdown:Size(200, 28)
    dropdown:Point("CENTER", 0, 100)
    dropdown:SetList({
        {text = "Option 1", value = 1},
        {text = "Option 2", value = 2},
        {text = "Option 3", value = 3},
    })
    dropdown:OnSelect(function(value, option)
        print("Selected:", option.text, "Value:", value)
    end)

    return dropdown
end

-- ============================================================
-- EXAMPLE 2: Dropdown with Icons
-- ============================================================

local function Example_IconDropdown(parent)
    local dropdown = LoolibCreateEnhancedDropdown(parent)
    dropdown:Size(200, 28)
    dropdown:Point("CENTER", 0, 50)
    dropdown:SetList({
        {
            text = "Tank",
            value = "TANK",
            icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
        },
        {
            text = "Healer",
            value = "HEALER",
            icon = "Interface\\Icons\\Spell_Holy_FlashHeal",
        },
        {
            text = "DPS",
            value = "DPS",
            icon = "Interface\\Icons\\Ability_DualWield",
        },
    })

    return dropdown
end

-- ============================================================
-- EXAMPLE 3: Dropdown with Submenus
-- ============================================================

local function Example_SubmenuDropdown(parent)
    local dropdown = LoolibCreateEnhancedDropdown(parent)
    dropdown:Size(200, 28)
    dropdown:Point("CENTER", 0, 0)
    dropdown:SetList({
        {text = "Main Options", isTitle = true},
        {isSeparator = true},
        {
            text = "Classes",
            subMenu = {
                {text = "Warrior", value = "WARRIOR"},
                {text = "Paladin", value = "PALADIN"},
                {text = "Hunter", value = "HUNTER"},
                {text = "Rogue", value = "ROGUE"},
            }
        },
        {
            text = "Specs",
            subMenu = {
                {text = "Arms", value = "ARMS"},
                {text = "Fury", value = "FURY"},
                {text = "Protection", value = "PROTECTION"},
            }
        },
        {isSeparator = true},
        {text = "None", value = nil},
    })

    return dropdown
end

-- ============================================================
-- EXAMPLE 4: Dropdown with Checkboxes
-- ============================================================

local function Example_CheckboxDropdown(parent)
    local dropdown = LoolibCreateEnhancedDropdown(parent)
    dropdown:Size(200, 28)
    dropdown:Point("CENTER", 0, -50)
    dropdown:SetText("Options")
    dropdown:SetAutoText(false)  -- Don't update text on selection

    dropdown:SetList({
        {text = "Settings", isTitle = true},
        {isSeparator = true},
        {
            text = "Enable Sound",
            checkState = true,
            onCheckChange = function(checked)
                print("Sound:", checked and "ON" or "OFF")
            end
        },
        {
            text = "Show Minimap",
            checkState = false,
            onCheckChange = function(checked)
                print("Minimap:", checked and "ON" or "OFF")
            end
        },
        {
            text = "Auto Accept",
            checkState = true,
            onCheckChange = function(checked)
                print("Auto Accept:", checked and "ON" or "OFF")
            end
        },
    })

    return dropdown
end

-- ============================================================
-- EXAMPLE 5: Dropdown with Embedded Controls
-- ============================================================

local function Example_EmbeddedControlsDropdown(parent)
    local dropdown = LoolibCreateEnhancedDropdown(parent)
    dropdown:Size(220, 28)
    dropdown:Point("CENTER", 0, -100)
    dropdown:SetText("Advanced Options")
    dropdown:SetAutoText(false)

    local volume = 50
    local prefix = "Player"

    dropdown:SetList({
        {text = "Settings", isTitle = true},
        {isSeparator = true},
        {
            text = "Volume",
            slider = {
                0,      -- min
                100,    -- max
                volume, -- current value
                function(value)
                    volume = value
                    print("Volume set to:", value)
                end,
                1       -- step
            }
        },
        {
            text = "Name Prefix",
            editBox = {
                prefix, -- default text
                function(text)
                    prefix = text
                    print("Prefix set to:", text)
                end,
                150     -- width
            }
        },
        {isSeparator = true},
        {text = "Save", value = "save"},
        {text = "Cancel", value = "cancel"},
    })

    dropdown:OnSelect(function(value, option)
        print("Action:", value)
    end)

    return dropdown
end

-- ============================================================
-- EXAMPLE 6: Color-Coded Dropdown
-- ============================================================

local function Example_ColorCodedDropdown(parent)
    local dropdown = LoolibCreateEnhancedDropdown(parent)
    dropdown:Size(200, 28)
    dropdown:Point("CENTER", 0, -150)

    dropdown:SetList({
        {text = "Raid Difficulty", isTitle = true},
        {isSeparator = true},
        {
            text = "Normal",
            value = 1,
            colorCode = "|cFF00FF00",  -- Green
        },
        {
            text = "Heroic",
            value = 2,
            colorCode = "|cFF0070DD",  -- Blue
        },
        {
            text = "Mythic",
            value = 3,
            colorCode = "|cFFA335EE",  -- Purple
        },
        {
            text = "Not Available",
            value = nil,
            colorCode = "|cFF666666",  -- Gray
            disabled = true,
        },
    })

    return dropdown
end

-- ============================================================
-- EXAMPLE 7: Full-Featured Dropdown
-- ============================================================

local function Example_FullFeaturedDropdown(parent)
    local dropdown = LoolibCreateEnhancedDropdown(parent)
    dropdown:Size(250, 32)
    dropdown:Point("CENTER")
    dropdown:SetMenuWidth(280)

    local settings = {
        class = "WARRIOR",
        spec = "ARMS",
        showHealth = true,
        showMana = true,
        scale = 100,
        customText = "",
    }

    dropdown:SetList({
        {text = "Configuration", isTitle = true},
        {isSeparator = true},
        {
            text = "Classes",
            icon = "Interface\\Icons\\ClassIcon_Warrior",
            subMenu = {
                {text = "Warrior", value = "WARRIOR", icon = "Interface\\Icons\\ClassIcon_Warrior"},
                {text = "Paladin", value = "PALADIN", icon = "Interface\\Icons\\ClassIcon_Paladin"},
                {text = "Hunter", value = "HUNTER", icon = "Interface\\Icons\\ClassIcon_Hunter"},
            },
            tooltip = "Select your character class",
        },
        {
            text = "Specialization",
            subMenu = {
                {text = "Arms", value = "ARMS"},
                {text = "Fury", value = "FURY"},
                {text = "Protection", value = "PROTECTION"},
            }
        },
        {isSeparator = true},
        {text = "Display Options", isTitle = true, padding = 4},
        {
            text = "Show Health Bar",
            checkState = settings.showHealth,
            onCheckChange = function(checked)
                settings.showHealth = checked
            end
        },
        {
            text = "Show Mana Bar",
            checkState = settings.showMana,
            onCheckChange = function(checked)
                settings.showMana = checked
            end
        },
        {
            text = "UI Scale",
            slider = {50, 150, settings.scale, function(value)
                settings.scale = value
            end, 5},
            padding = 8,
        },
        {
            text = "Custom Label",
            editBox = {settings.customText, function(text)
                settings.customText = text
            end, 180},
            padding = 8,
        },
        {isSeparator = true},
        {text = "Apply", value = "apply", colorCode = "|cFF00FF00"},
        {text = "Reset", value = "reset", colorCode = "|cFFFF0000"},
    })

    dropdown:OnSelect(function(value, option)
        if value == "apply" then
            print("Settings applied:", settings.class, settings.spec)
        elseif value == "reset" then
            print("Settings reset")
        elseif value then
            -- Update settings based on selection
            if option.text == "Warrior" or option.text == "Paladin" or option.text == "Hunter" then
                settings.class = value
            elseif option.text == "Arms" or option.text == "Fury" or option.text == "Protection" then
                settings.spec = value
            end
        end
    end)

    return dropdown
end

-- ============================================================
-- EXAMPLE 8: Fluent API with WidgetMod
-- ============================================================

local function Example_FluentAPI(parent)
    local dropdown = LoolibCreateEnhancedDropdown(parent)
        :Size(200, 28)
        :Point("CENTER", 200, 0)
        :SetList({
            {text = "Option 1", value = 1},
            {text = "Option 2", value = 2},
            {text = "Option 3", value = 3},
        })
        :SetValue(2)
        :OnSelect(function(value, option)
            print("Selected:", value)
        end)
        :Tooltip("Select an option from the list")

    return dropdown
end

-- ============================================================
-- Test Function - Creates all examples
-- ============================================================

function TestEnhancedDropdown()
    local testFrame = CreateFrame("Frame", nil, UIParent)
    testFrame:SetSize(800, 600)
    testFrame:SetPoint("CENTER")
    testFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 8, right = 8, top = 8, bottom = 8}
    })
    testFrame:SetBackdropColor(0, 0, 0, 0.8)

    -- Title
    local title = testFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("EnhancedDropdown Examples")

    -- Create examples
    Example_BasicDropdown(testFrame)
    Example_IconDropdown(testFrame)
    Example_SubmenuDropdown(testFrame)
    Example_CheckboxDropdown(testFrame)
    Example_EmbeddedControlsDropdown(testFrame)
    Example_ColorCodedDropdown(testFrame)
    Example_FluentAPI(testFrame)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, testFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() testFrame:Hide() end)

    testFrame:Show()
end

-- Slash command to test
SLASH_TESTENHANCEDDROPDOWN1 = "/testdropdown"
SlashCmdList["TESTENHANCEDDROPDOWN"] = TestEnhancedDropdown
