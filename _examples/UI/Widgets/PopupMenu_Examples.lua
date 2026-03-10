--[[--------------------------------------------------------------------
    PopupMenu Usage Examples

    This file demonstrates various ways to use the PopupMenu system.
    DO NOT include this file in the TOC - it's for reference only.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local UI = Loolib.UI or {}
local PopupMenu = UI.PopupMenu or {}

local function GetSharedMenu()
    assert(type(UI.GetSharedPopupMenu) == "function", "Loolib.UI.GetSharedPopupMenu is required for PopupMenu examples")
    return UI.GetSharedPopupMenu()
end

local function CreateBuilder()
    assert(type(PopupMenu.Builder) == "function", "Loolib.UI.PopupMenu.Builder is required for PopupMenu examples")
    return PopupMenu.Builder()
end

--[[--------------------------------------------------------------------
    Example 1: Simple Right-Click Menu
----------------------------------------------------------------------]]

local function Example1_SimpleMenu()
    -- Get the shared menu instance
    local menu = GetSharedMenu()

    -- Configure options
    menu:SetOptions({
        {text = "Edit", value = "edit", icon = "Interface\\Icons\\INV_Misc_Note_01"},
        {text = "Delete", value = "delete", colorCode = "|cFFFF0000"},
        {isSeparator = true},
        {text = "Cancel", value = "cancel"},
    })

    -- Set callback
    menu:OnSelect(function(value, item)
        print("Selected:", value)
    end)

    -- Show at cursor
    menu:ShowAtCursor()
end

--[[--------------------------------------------------------------------
    Example 2: Menu with Submenus
----------------------------------------------------------------------]]

local function Example2_Submenus()
    local menu = GetSharedMenu()

    menu:SetOptions({
        {text = "File", isTitle = true},
        {text = "New", value = "new", icon = "Interface\\Icons\\INV_Misc_Note_01"},
        {text = "Open Recent", subMenu = {
            {text = "Document1.txt", value = "doc1"},
            {text = "Document2.txt", value = "doc2"},
            {text = "Document3.txt", value = "doc3"},
        }},
        {isSeparator = true},
        {text = "Exit", value = "exit", colorCode = "|cFFFF0000"},
    })

    menu:OnSelect(function(value, item)
        print("Selected:", value)
    end)

    menu:ShowAtCursor()
end

--[[--------------------------------------------------------------------
    Example 3: Checkboxes and Radio Buttons
----------------------------------------------------------------------]]

local function Example3_ChecksAndRadios()
    local menu = GetSharedMenu()

    menu:SetOptions({
        {text = "View Options", isTitle = true},
        {text = "Show Tooltips", checked = true, keepOpen = true, func = function()
            print("Toggled tooltips")
        end},
        {text = "Show Icons", checked = false, keepOpen = true, func = function()
            print("Toggled icons")
        end},
        {isSeparator = true},
        {text = "Sort Options", isTitle = true},
        {text = "Sort by Name", radio = true, checked = true, value = "name"},
        {text = "Sort by Date", radio = true, checked = false, value = "date"},
        {text = "Sort by Size", radio = true, checked = false, value = "size"},
    })

    menu:OnSelect(function(value, item)
        print("Selected:", value)
    end)

    menu:ShowAtCursor()
end

--[[--------------------------------------------------------------------
    Example 4: Disabled Items and Tooltips
----------------------------------------------------------------------]]

local function Example4_DisabledAndTooltips()
    local menu = GetSharedMenu()

    menu:SetOptions({
        {text = "Copy", value = "copy", tooltip = "Copy the selected text"},
        {text = "Paste", value = "paste", disabled = true, tooltip = "Nothing to paste"},
        {text = "Cut", value = "cut", tooltip = "Cut the selected text"},
        {isSeparator = true},
        {text = "Delete", value = "delete", colorCode = "|cFFFF0000",
         tooltip = "Permanently delete the item"},
    })

    menu:OnSelect(function(value, item)
        print("Selected:", value)
    end)

    menu:ShowAtCursor()
end

--[[--------------------------------------------------------------------
    Example 5: Fluent API Builder
----------------------------------------------------------------------]]

local function Example5_FluentAPI()
    CreateBuilder()
        :AddTitle("Actions")
        :AddOption("Edit", "edit", {icon = "Interface\\Icons\\INV_Misc_Note_01"})
        :AddOption("Delete", "delete", {colorCode = "|cFFFF0000"})
        :AddSeparator()
        :AddOption("Cancel", "cancel")
        :OnSelect(function(value)
            print("Selected:", value)
        end)
        :ShowAtCursor()
end

--[[--------------------------------------------------------------------
    Example 6: Right-Click Handler for a Frame
----------------------------------------------------------------------]]

local function Example6_FrameRightClick()
    -- Create a test frame
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(200, 200)
    frame:SetPoint("CENTER")
    frame:EnableMouse(true)

    -- Add background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

    -- Right-click handler
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            CreateBuilder()
                :AddTitle("Frame Options")
                :AddOption("Move", "move")
                :AddOption("Resize", "resize")
                :AddSeparator()
                :AddOption("Hide", "hide", {colorCode = "|cFFFF0000"})
                :OnSelect(function(value)
                    if value == "hide" then
                        self:Hide()
                    else
                        print("Action:", value)
                    end
                end)
                :ShowAtCursor()
        end
    end)
end

--[[--------------------------------------------------------------------
    Example 7: Custom Menu Instance (Not Shared)
----------------------------------------------------------------------]]

local function Example7_CustomInstance()
    -- Create your own menu instance if you need multiple menus
    local myMenu = (Loolib.UI and Loolib.UI.CreatePopupMenu and Loolib.UI.CreatePopupMenu()) or nil
    if not myMenu then
        error("Loolib.UI.CreatePopupMenu is required for this example")
    end

    myMenu:SetOptions({
        {text = "Option 1", value = 1},
        {text = "Option 2", value = 2},
        {text = "Option 3", value = 3},
    })

    myMenu:OnSelect(function(value)
        print("Custom menu selected:", value)
    end)

    myMenu:SetMenuWidth(200)
    myMenu:ShowAtCursor()
end

--[[--------------------------------------------------------------------
    Example 8: Anchored to Frame (Not Cursor)
----------------------------------------------------------------------]]

local function Example8_AnchoredMenu(anchorFrame)
    local menu = GetSharedMenu()

    menu:SetOptions({
        {text = "Above", value = "above"},
        {text = "Below", value = "below"},
        {text = "Left", value = "left"},
        {text = "Right", value = "right"},
    })

    menu:OnSelect(function(value)
        print("Direction:", value)
    end)

    -- Show anchored below the frame
    menu:ShowAt(anchorFrame, "TOPLEFT", "BOTTOMLEFT", 0, -2)
end

--[[--------------------------------------------------------------------
    Example 9: Complex Nested Menu
----------------------------------------------------------------------]]

local function Example9_ComplexNested()
    CreateBuilder()
        :AddTitle("Edit")
        :AddOption("Undo", "undo", {icon = "Interface\\Buttons\\UI-RotationLeft-Button-Up"})
        :AddOption("Redo", "redo", {icon = "Interface\\Buttons\\UI-RotationRight-Button-Up"})
        :AddSeparator()
        :AddOption("Copy", "copy")
        :AddOption("Paste", "paste")
        :AddSeparator()
        :AddOption("Transform", nil, {
            subMenu = {
                {text = "Rotate", subMenu = {
                    {text = "90° Left", value = "rot_left_90"},
                    {text = "90° Right", value = "rot_right_90"},
                    {text = "180°", value = "rot_180"},
                }},
                {text = "Scale", subMenu = {
                    {text = "50%", value = "scale_50"},
                    {text = "100%", value = "scale_100"},
                    {text = "200%", value = "scale_200"},
                }},
                {text = "Flip Horizontal", value = "flip_h"},
                {text = "Flip Vertical", value = "flip_v"},
            }
        })
        :OnSelect(function(value)
            print("Transform action:", value)
        end)
        :ShowAtCursor()
end

--[[--------------------------------------------------------------------
    Example 10: Item-Specific Callbacks
----------------------------------------------------------------------]]

local function Example10_ItemCallbacks()
    local menu = GetSharedMenu()

    menu:SetOptions({
        {text = "Quick Action 1", func = function()
            print("Quick action 1 executed")
        end},
        {text = "Quick Action 2", func = function()
            print("Quick action 2 executed")
        end},
        {isSeparator = true},
        {text = "Action with Value", value = "special", func = function(value)
            print("Executed with value:", value)
        end},
    })

    -- Global callback still works
    menu:OnSelect(function(value, item)
        print("Global callback:", value)
    end)

    menu:ShowAtCursor()
end

-- Return examples for testing
return {
    SimpleMenu = Example1_SimpleMenu,
    Submenus = Example2_Submenus,
    ChecksAndRadios = Example3_ChecksAndRadios,
    DisabledAndTooltips = Example4_DisabledAndTooltips,
    FluentAPI = Example5_FluentAPI,
    FrameRightClick = Example6_FrameRightClick,
    CustomInstance = Example7_CustomInstance,
    AnchoredMenu = Example8_AnchoredMenu,
    ComplexNested = Example9_ComplexNested,
    ItemCallbacks = Example10_ItemCallbacks,
}
