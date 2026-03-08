--[[--------------------------------------------------------------------
    PopupMenu Test/Demo

    Simple test harness for PopupMenu functionality.
    Load this file after PopupMenu.lua to test in-game.

    Usage: /lootestmenu
----------------------------------------------------------------------]]

-- Create test button on screen
local testButton = CreateFrame("Button", "LoolibPopupMenuTestButton", UIParent, "UIPanelButtonTemplate")
testButton:SetSize(150, 30)
testButton:SetPoint("CENTER", UIParent, "CENTER")
testButton:SetText("Right-Click Me!")

-- Background to make it visible
local bg = testButton:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.2, 0.3, 0.5, 0.8)

-- Test function
local function ShowTestMenu()
    LoolibPopupMenu()
        :AddTitle("Test Menu")
        :AddOption("Simple Action", "action1", {
            icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        })
        :AddOption("Colored Action", "action2", {
            colorCode = "|cFF00FF00",
            icon = "Interface\\Icons\\Achievement_BG_winAB_underXminutes",
        })
        :AddSeparator()
        :AddTitle("Checkboxes")
        :AddOption("Option 1", "opt1", {
            checked = true,
            keepOpen = true,
        })
        :AddOption("Option 2", "opt2", {
            checked = false,
            keepOpen = true,
        })
        :AddSeparator()
        :AddTitle("Submenus")
        :AddOption("More Options", nil, {
            subMenu = {
                {text = "Submenu 1", value = "sub1"},
                {text = "Submenu 2", value = "sub2"},
                {text = "Even More", subMenu = {
                    {text = "Deep 1", value = "deep1"},
                    {text = "Deep 2", value = "deep2"},
                }},
            }
        })
        :AddSeparator()
        :AddOption("Disabled Item", "disabled", {
            disabled = true,
            tooltip = "This item is disabled",
        })
        :AddOption("With Tooltip", "tooltip", {
            tooltip = "This is a helpful tooltip!",
        })
        :AddSeparator()
        :AddOption("Delete Something", "delete", {
            colorCode = "|cFFFF0000",
            icon = "Interface\\Icons\\Ability_Rogue_FeignDeath",
        })
        :OnSelect(function(value, item)
            print("PopupMenu Test - Selected:", value)
            if item.text then
                print("  Item text:", item.text)
            end
        end)
        :ShowAtCursor()
end

-- Right-click on button
testButton:SetScript("OnMouseDown", function(self, button)
    if button == "RightButton" then
        ShowTestMenu()
    end
end)

-- Left-click shows at different position
testButton:SetScript("OnClick", function(self)
    LoolibPopupMenu()
        :AddTitle("Anchored Menu")
        :AddOption("This menu is", "1")
        :AddOption("anchored to", "2")
        :AddOption("the button", "3")
        :OnSelect(function(value)
            print("Anchored menu selected:", value)
        end)
        :ShowAt(self, "TOPLEFT", "BOTTOMLEFT", 0, -5)
end)

-- Make it draggable
testButton:SetMovable(true)
testButton:EnableMouse(true)
testButton:RegisterForDrag("LeftButton")
testButton:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
testButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Slash command
SLASH_LOOTESTMENU1 = "/lootestmenu"
SlashCmdList["LOOTESTMENU"] = function(msg)
    if msg == "hide" then
        testButton:Hide()
        print("PopupMenu test button hidden")
    elseif msg == "show" then
        testButton:Show()
        print("PopupMenu test button shown")
    elseif msg == "cursor" then
        ShowTestMenu()
    elseif msg == "examples" then
        print("PopupMenu Test Commands:")
        print("  /lootestmenu - Show this help")
        print("  /lootestmenu show - Show test button")
        print("  /lootestmenu hide - Hide test button")
        print("  /lootestmenu cursor - Show menu at cursor")
        print("")
        print("Test button usage:")
        print("  Right-click: Show full test menu")
        print("  Left-click: Show anchored menu")
        print("  Drag: Move the button")
    else
        print("PopupMenu Test Button created!")
        print("  Right-click it for a test menu")
        print("  Left-click for anchored menu")
        print("  Type /lootestmenu examples for more info")
        testButton:Show()
    end
end

print("|cFF00FF00PopupMenu Test loaded!|r Type /lootestmenu for test button")
