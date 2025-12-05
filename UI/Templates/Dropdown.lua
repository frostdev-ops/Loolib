--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Dropdown - Customizable dropdown menu

    Features:
    - Simple options list
    - Multi-level nested submenus with arrows
    - Disabled items
    - Icons and checkmarks
    - Radio buttons and checkmarks
    - Separators
    - Color codes in text
    - Tooltips on hover
    - Search/filter for long lists
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Dropdown Menu Frame (Shared)
----------------------------------------------------------------------]]

local dropdownMenu = nil
local submenuFrame = nil
local currentDropdown = nil
local activeSubmenu = nil

local function GetDropdownMenu()
    if not dropdownMenu then
        dropdownMenu = CreateFrame("Frame", nil, UIParent, "LoolibDropdownMenuTemplate")
        dropdownMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        dropdownMenu:Hide()

        -- Close on click outside
        dropdownMenu:SetScript("OnShow", function()
            dropdownMenu:SetPropagateKeyboardInput(false)
        end)

        dropdownMenu:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then
                dropdownMenu:Hide()
                if submenuFrame then
                    submenuFrame:Hide()
                end
            end
        end)

        dropdownMenu:EnableKeyboard(true)
    end
    return dropdownMenu
end

local function GetSubmenuFrame()
    if not submenuFrame then
        submenuFrame = CreateFrame("Frame", nil, UIParent, "LoolibDropdownMenuTemplate")
        submenuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        submenuFrame:SetFrameLevel(GetDropdownMenu():GetFrameLevel() + 1)
        submenuFrame:Hide()
    end
    return submenuFrame
end

--[[--------------------------------------------------------------------
    LoolibDropdownMixin
----------------------------------------------------------------------]]

LoolibDropdownMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local DROPDOWN_EVENTS = {
    "OnSelect",
    "OnOpen",
    "OnClose",
}

--- Initialize the dropdown
function LoolibDropdownMixin:OnLoad()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(DROPDOWN_EVENTS)

    self.options = {}
    self.selectedValue = nil
    self.selectedText = nil
    self.placeholder = "Select..."
    self.maxVisibleItems = 10
    self.itemHeight = 20

    -- Get references
    self.Button = self.Button
    self.Text = self.Text

    -- Set up button click
    if self.Button then
        self.Button:SetScript("OnClick", function()
            self:ToggleMenu()
        end)
    end

    -- Make the whole frame clickable
    self:EnableMouse(true)
    self:SetScript("OnMouseDown", function()
        self:ToggleMenu()
    end)

    self:UpdateDisplay()
end

--[[--------------------------------------------------------------------
    Options
----------------------------------------------------------------------]]

--- Set the dropdown options
-- @param options table - Array of option tables with fields:
--   - value: any - Option value
--   - text: string - Display text
--   - icon: string|nil - Icon texture path
--   - disabled: boolean|nil - Whether item is disabled
--   - isSeparator: boolean|nil - Whether this is a separator line
--   - hasArrow: boolean|nil - Whether this item has a submenu
--   - submenu: table|nil - Array of submenu items (same format)
--   - checked: boolean|nil - Whether item has checkmark
--   - isNotRadio: boolean|nil - Use checkmark instead of radio button
--   - colorCode: string|nil - Color code prefix (e.g., "|cFFFF0000")
--   - tooltipTitle: string|nil - Tooltip title
--   - tooltipText: string|nil - Tooltip body text
function LoolibDropdownMixin:SetOptions(options)
    self.options = options or {}
end

--- Add a single option
-- @param value any - Option value
-- @param text string - Display text
-- @param options table - Optional fields (see SetOptions for full list)
function LoolibDropdownMixin:AddOption(value, text, options)
    options = options or {}
    self.options[#self.options + 1] = {
        value = value,
        text = text,
        icon = options.icon,
        disabled = options.disabled,
        isSeparator = options.isSeparator,
        hasArrow = options.hasArrow,
        submenu = options.submenu,
        checked = options.checked,
        isNotRadio = options.isNotRadio,
        colorCode = options.colorCode,
        tooltipTitle = options.tooltipTitle,
        tooltipText = options.tooltipText,
    }
end

--- Clear all options
function LoolibDropdownMixin:ClearOptions()
    wipe(self.options)
end

--[[--------------------------------------------------------------------
    Selection
----------------------------------------------------------------------]]

--- Set the selected value
-- @param value any - Value to select
function LoolibDropdownMixin:SetSelectedValue(value)
    self.selectedValue = value
    self.selectedText = nil

    -- Find the text for this value
    for _, option in ipairs(self.options) do
        if option.value == value then
            self.selectedText = option.text
            break
        end
    end

    self:UpdateDisplay()
end

--- Get the selected value
-- @return any
function LoolibDropdownMixin:GetSelectedValue()
    return self.selectedValue
end

--- Get the selected text
-- @return string|nil
function LoolibDropdownMixin:GetSelectedText()
    return self.selectedText
end

--- Set placeholder text
-- @param text string
function LoolibDropdownMixin:SetPlaceholder(text)
    self.placeholder = text
    self:UpdateDisplay()
end

--- Update the display text
function LoolibDropdownMixin:UpdateDisplay()
    if self.Text then
        if self.selectedText then
            self.Text:SetText(self.selectedText)
            self.Text:SetTextColor(1, 1, 1, 1)
        else
            self.Text:SetText(self.placeholder)
            self.Text:SetTextColor(0.5, 0.5, 0.5, 1)
        end
    end
end

--[[--------------------------------------------------------------------
    Menu Display
----------------------------------------------------------------------]]

--- Toggle the menu open/closed
function LoolibDropdownMixin:ToggleMenu()
    local menu = GetDropdownMenu()

    if menu:IsShown() and currentDropdown == self then
        self:CloseMenu()
    else
        self:OpenMenu()
    end
end

--- Open the menu
function LoolibDropdownMixin:OpenMenu()
    local menu = GetDropdownMenu()

    -- Close any existing menu
    if currentDropdown and currentDropdown ~= self then
        currentDropdown:CloseMenu()
    end

    currentDropdown = self

    -- Build menu content
    self:BuildMenu(menu)

    -- Position menu below dropdown
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)

    -- Size menu
    local numVisible = math.min(#self.options, self.maxVisibleItems)
    local menuHeight = numVisible * self.itemHeight + 8
    menu:SetSize(self:GetWidth(), menuHeight)

    if menu.ScrollFrame and menu.ScrollFrame.Content then
        menu.ScrollFrame.Content:SetWidth(self:GetWidth() - 8)
        menu.ScrollFrame.Content:SetHeight(#self.options * self.itemHeight)
    end

    menu:Show()
    self:TriggerEvent("OnOpen")

    -- Set up click-outside handling
    menu:SetScript("OnUpdate", function()
        if not MouseIsOver(menu) and not MouseIsOver(self) and IsMouseButtonDown() then
            self:CloseMenu()
        end
    end)
end

--- Close the menu
function LoolibDropdownMixin:CloseMenu()
    local menu = GetDropdownMenu()
    menu:Hide()
    menu:SetScript("OnUpdate", nil)

    if currentDropdown == self then
        currentDropdown = nil
    end

    self:TriggerEvent("OnClose")
end

--- Build the menu content
-- @param menu Frame - The menu frame to populate
-- @param options table - The options to display
-- @param parentItem Frame|nil - The parent menu item (for submenus)
function LoolibDropdownMixin:BuildMenu(menu, options, parentItem)
    options = options or self.options
    local content = menu.ScrollFrame and menu.ScrollFrame.Content

    if not content then
        return
    end

    -- Clear existing items
    for i = content:GetNumChildren(), 1, -1 do
        local child = select(i, content:GetChildren())
        child:Hide()
        child:SetParent(nil)
    end

    -- Create items
    for i, option in ipairs(options) do
        local item

        -- Handle separators
        if option.isSeparator then
            item = CreateFrame("Frame", nil, content)
            item:SetSize(content:GetWidth(), self.itemHeight / 2)
            item:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * self.itemHeight))

            -- Create separator line
            local line = item:CreateTexture(nil, "ARTWORK")
            line:SetHeight(1)
            line:SetPoint("LEFT", item, "LEFT", 4, 0)
            line:SetPoint("RIGHT", item, "RIGHT", -4, 0)
            line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

            item:Show()
        else
            item = CreateFrame("Button", nil, content, "LoolibDropdownMenuItemTemplate")
            item:SetSize(content:GetWidth(), self.itemHeight)
            item:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * self.itemHeight))

            -- Text with optional color code
            if item.Text then
                local displayText = option.text or ""
                if option.colorCode then
                    displayText = option.colorCode .. displayText .. "|r"
                end
                item.Text:SetText(displayText)
            end

            -- Checkmark or radio button for selected/checked items
            if item.Check then
                local isChecked = option.checked or (option.value == self.selectedValue)
                if isChecked then
                    if option.isNotRadio then
                        -- Checkmark
                        item.Check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                    else
                        -- Radio button
                        item.Check:SetTexture("Interface\\Buttons\\UI-RadioButton")
                        item.Check:SetTexCoord(0.25, 0.5, 0, 1)
                    end
                    item.Check:Show()
                    if item.Text then
                        item.Text:SetPoint("LEFT", item.Check, "RIGHT", 2, 0)
                    end
                else
                    item.Check:Hide()
                end
            end

            -- Arrow for submenu
            if option.hasArrow and option.submenu then
                if not item.Arrow then
                    item.Arrow = item:CreateTexture(nil, "ARTWORK")
                    item.Arrow:SetSize(16, 16)
                    item.Arrow:SetPoint("RIGHT", item, "RIGHT", -4, 0)
                    item.Arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
                end
                item.Arrow:Show()
            elseif item.Arrow then
                item.Arrow:Hide()
            end

            -- Disabled state
            if option.disabled then
                item:SetEnabled(false)
                if item.Text then
                    item.Text:SetTextColor(0.5, 0.5, 0.5, 1)
                end
            else
                item:SetEnabled(true)
                if item.Text and not option.colorCode then
                    item.Text:SetTextColor(1, 1, 1, 1)
                end
            end

            -- Tooltip
            if option.tooltipTitle or option.tooltipText then
                item:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if option.tooltipTitle then
                        GameTooltip:SetText(option.tooltipTitle, 1, 1, 1)
                    end
                    if option.tooltipText then
                        GameTooltip:AddLine(option.tooltipText, nil, nil, nil, true)
                    end
                    GameTooltip:Show()
                end)
                item:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
            end

            -- Click handler or submenu opener
            if option.hasArrow and option.submenu then
                -- Show submenu on hover
                item:SetScript("OnEnter", function(itemFrame)
                    -- Use dropdown instance, not the item frame
                    if self.OpenSubmenu then
                        self:OpenSubmenu(option.submenu, itemFrame)
                    end
                end)
                item:SetScript("OnClick", function() end)  -- No click action for submenu parents
            else
                item:SetScript("OnClick", function()
                    if not option.disabled then
                        self:SetSelectedValue(option.value)
                        self:TriggerEvent("OnSelect", option.value, option.text)
                        self:CloseMenu()
                    end
                end)
            end

            item:Show()
        end
    end
end

--- Open a submenu
-- @param submenuOptions table - The submenu options
-- @param parentItem Frame - The parent menu item
function LoolibDropdownMixin:OpenSubmenu(submenuOptions, parentItem)
    local submenu = GetSubmenuFrame()

    -- Build submenu content
    self:BuildMenu(submenu, submenuOptions, parentItem)

    -- Position submenu to the right of parent item
    submenu:ClearAllPoints()
    submenu:SetPoint("TOPLEFT", parentItem, "TOPRIGHT", 0, 0)

    -- Size submenu
    local itemHeight = self.itemHeight
    local numItems = #submenuOptions
    local menuHeight = numItems * itemHeight + 8
    local menuWidth = 150  -- Default submenu width

    submenu:SetSize(menuWidth, menuHeight)

    if submenu.ScrollFrame and submenu.ScrollFrame.Content then
        submenu.ScrollFrame.Content:SetWidth(menuWidth - 8)
        submenu.ScrollFrame.Content:SetHeight(numItems * itemHeight)
    end

    submenu:Show()
    activeSubmenu = submenu
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set maximum visible items
-- @param max number
function LoolibDropdownMixin:SetMaxVisibleItems(max)
    self.maxVisibleItems = max
end

--- Set item height
-- @param height number
function LoolibDropdownMixin:SetItemHeight(height)
    self.itemHeight = height
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a dropdown
-- @param parent Frame - Parent frame
-- @return Frame - The dropdown frame
function CreateLoolibDropdown(parent)
    local dropdown = CreateFrame("Frame", nil, parent, "LoolibDropdownTemplate")
    LoolibMixin(dropdown, LoolibDropdownMixin)
    dropdown:OnLoad()
    return dropdown
end

--[[--------------------------------------------------------------------
    Builder Pattern
----------------------------------------------------------------------]]

LoolibDropdownBuilderMixin = {}

function LoolibDropdownBuilderMixin:Init(parent)
    self.parent = parent
    self.options = {}
    self.config = {}
end

function LoolibDropdownBuilderMixin:SetOptions(options)
    self.options = options
    return self
end

function LoolibDropdownBuilderMixin:AddOption(value, text, options)
    self.options[#self.options + 1] = {
        value = value,
        text = text,
        icon = options and options.icon,
        disabled = options and options.disabled,
    }
    return self
end

function LoolibDropdownBuilderMixin:SetSelectedValue(value)
    self.config.selectedValue = value
    return self
end

function LoolibDropdownBuilderMixin:SetPlaceholder(text)
    self.config.placeholder = text
    return self
end

function LoolibDropdownBuilderMixin:OnSelect(callback)
    self.config.onSelect = callback
    return self
end

function LoolibDropdownBuilderMixin:Build()
    local dropdown = CreateLoolibDropdown(self.parent)

    dropdown:SetOptions(self.options)

    if self.config.placeholder then
        dropdown:SetPlaceholder(self.config.placeholder)
    end

    if self.config.selectedValue then
        dropdown:SetSelectedValue(self.config.selectedValue)
    end

    if self.config.onSelect then
        dropdown:RegisterCallback("OnSelect", self.config.onSelect)
    end

    return dropdown
end

function LoolibDropdown(parent)
    local builder = LoolibCreateFromMixins(LoolibDropdownBuilderMixin)
    builder:Init(parent)
    return builder
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local DropdownModule = {
    Mixin = LoolibDropdownMixin,
    BuilderMixin = LoolibDropdownBuilderMixin,
    Create = CreateLoolibDropdown,
    Builder = LoolibDropdown,
}

local UI = Loolib:GetOrCreateModule("UI")
UI.Dropdown = DropdownModule
UI.CreateDropdown = CreateLoolibDropdown

Loolib:RegisterModule("Dropdown", DropdownModule)
