--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    EnhancedDropdown - Advanced Dropdown with Submenus

    Features:
    - Multi-level submenus with automatic positioning
    - Icons (texture or atlas)
    - Embedded controls (sliders, editboxes)
    - Checkboxes and radio buttons
    - Separators and section headers
    - Color-coded text
    - Tooltips
    - Fluent API for configuration

    Inspired by MRT's sophisticated dropdown system.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local LoolibMixin = assert(Loolib.Mixin, "Loolib.Mixin is required for EnhancedDropdown")

--[[--------------------------------------------------------------------
    DROPDOWN OPTION STRUCTURE
----------------------------------------------------------------------]]
--[[
Example DropdownOption structure: {
    text = "Label",               -- Display text (required)
    value = any,                  -- Value to store/return
    icon = "path" or atlasName,   -- Left-side icon
    iconIsAtlas = bool,           -- If true, icon is atlas
    iconCoords = {l,r,t,b},       -- Tex coords for icon
    colorCode = "|cFFRRGGBB",     -- Color code prefix
    disabled = bool,              -- Grayed out
    isTitle = bool,               -- Non-selectable header
    isSeparator = bool,           -- Horizontal divider
    subMenu = { ... },            -- Nested options
    tooltip = "text",             -- Hover tooltip

    -- Advanced embedded controls (MRT features)
    slider = {min, max, value, callback, step},  -- Embedded slider
    editBox = {defaultText, callback, width},    -- Embedded edit box
    checkState = bool,            -- Checkbox state
    onCheckChange = function,     -- Checkbox callback
    radio = bool,                 -- Radio button style
    font = "FontObject",          -- Custom font
    padding = number,             -- Extra vertical padding
}
]]

--[[--------------------------------------------------------------------
    LoolibEnhancedDropdownMixin
----------------------------------------------------------------------]]

---@class LoolibEnhancedDropdownMixin : Frame
local LoolibEnhancedDropdownMixin = {}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function LoolibEnhancedDropdownMixin:OnLoad()
    self._options = {}
    self._selectedValue = nil
    self._selectedText = nil
    self._menuWidth = nil
    self._maxLines = 15
    self._onSelectCallback = nil
    self._autoText = true  -- Auto-update button text on selection
    self._menuFrame = nil
    self._isOpen = false

    -- Create button elements
    self:_CreateButton()
end

function LoolibEnhancedDropdownMixin:_CreateButton()
    -- Background
    self:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    self:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Icon (optional, left side)
    self.icon = self:CreateTexture(nil, "ARTWORK")
    self.icon:SetSize(16, 16)
    self.icon:SetPoint("LEFT", 6, 0)
    self.icon:Hide()

    -- Text label
    self.text = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.text:SetPoint("LEFT", 8, 0)
    self.text:SetPoint("RIGHT", -24, 0)
    self.text:SetJustifyH("LEFT")
    self.text:SetText("Select...")

    -- Dropdown arrow
    self.arrow = self:CreateTexture(nil, "ARTWORK")
    self.arrow:SetSize(12, 12)
    self.arrow:SetPoint("RIGHT", -6, 0)
    self.arrow:SetAtlas("Gamepad_Ltr_Down_64")

    -- Highlight
    self.highlight = self:CreateTexture(nil, "HIGHLIGHT")
    self.highlight:SetAllPoints()
    self.highlight:SetColorTexture(1, 1, 1, 0.1)

    -- Click handler
    self:EnableMouse(true)
    self:SetScript("OnClick", function(frame)
        if frame._isOpen then
            frame:CloseMenu()
        else
            frame:OpenMenu()
        end
    end)

    self:SetScript("OnEnter", function(frame)
        frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end)

    self:SetScript("OnLeave", function(frame)
        frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end)
end

-- ============================================================
-- CONFIGURATION (Fluent API)
-- ============================================================

---Set dropdown options
---@param options table[] Array of DropdownOption
---@return LoolibEnhancedDropdownMixin
function LoolibEnhancedDropdownMixin:SetList(options)
    self._options = options
    return self
end

---Add single option
---@param option table DropdownOption
---@return LoolibEnhancedDropdownMixin
function LoolibEnhancedDropdownMixin:AddOption(option)
    table.insert(self._options, option)
    return self
end

---Clear all options
---@return LoolibEnhancedDropdownMixin
function LoolibEnhancedDropdownMixin:ClearOptions()
    self._options = {}
    return self
end

---Set selected value
---@param value any
---@return LoolibEnhancedDropdownMixin
function LoolibEnhancedDropdownMixin:SetValue(value)
    self._selectedValue = value

    -- Find matching option to update text
    local function findOption(options)
        for _, option in ipairs(options) do
            if option.value == value then
                return option
            end
            if option.subMenu then
                local found = findOption(option.subMenu)
                if found then return found end
            end
        end
    end

    local option = findOption(self._options)
    if option then
        self:_SetDisplayText(option.text, option.icon, option.iconIsAtlas)
    end

    return self
end

---Get selected value
---@return any
function LoolibEnhancedDropdownMixin:GetValue()
    return self._selectedValue
end

---Set button text
---@param text string
---@return LoolibEnhancedDropdownMixin
function LoolibEnhancedDropdownMixin:SetText(text)
    self.text:SetText(text)
    return self
end

---Set callback for selection
---@param callback function Function(value, option)
---@return LoolibEnhancedDropdownMixin
function LoolibEnhancedDropdownMixin:OnSelect(callback)
    self._onSelectCallback = callback
    return self
end

---Set menu width
---@param width number
---@return LoolibEnhancedDropdownMixin
function LoolibEnhancedDropdownMixin:SetMenuWidth(width)
    self._menuWidth = width
    return self
end

---Set max visible lines
---@param lines number
---@return LoolibEnhancedDropdownMixin
function LoolibEnhancedDropdownMixin:SetMaxLines(lines)
    self._maxLines = lines
    return self
end

---Enable/disable auto-text update on selection
---@param enabled boolean
---@return LoolibEnhancedDropdownMixin
function LoolibEnhancedDropdownMixin:SetAutoText(enabled)
    self._autoText = enabled
    return self
end

---Set tooltip
---@param text string|table
---@return LoolibEnhancedDropdownMixin
function LoolibEnhancedDropdownMixin:Tooltip(text)
    self._tooltipText = text
    return self
end

---Enable/disable dropdown
---@param enabled boolean
---@return LoolibEnhancedDropdownMixin
function LoolibEnhancedDropdownMixin:SetEnabled(enabled)
    if enabled then
        self:Enable()
        self:SetAlpha(1)
    else
        self:Disable()
        self:SetAlpha(0.5)
    end
    return self
end

-- ============================================================
-- DISPLAY HELPERS
-- ============================================================

function LoolibEnhancedDropdownMixin:_SetDisplayText(text, icon, isAtlas)
    self.text:SetText(text or "")

    if icon then
        if isAtlas then
            self.icon:SetAtlas(icon)
        else
            self.icon:SetTexture(icon)
        end
        self.icon:Show()
        self.text:SetPoint("LEFT", self.icon, "RIGHT", 4, 0)
    else
        self.icon:Hide()
        self.text:SetPoint("LEFT", 8, 0)
    end
end

-- ============================================================
-- MENU MANAGEMENT
-- ============================================================

function LoolibEnhancedDropdownMixin:OpenMenu()
    if self._isOpen then return end

    -- Create menu frame if needed
    if not self._menuFrame then
        self._menuFrame = self:_CreateMenuFrame()
    end

    -- Build menu content
    self:_BuildMenu()

    -- Position menu
    self._menuFrame:ClearAllPoints()
    self._menuFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)

    -- Clamp to screen edges so the menu never renders off-screen
    self._menuFrame:SetClampedToScreen(true)

    self._menuFrame:Show()
    self._isOpen = true

    -- Rotate arrow
    self.arrow:SetAtlas("Gamepad_Ltr_Up_64")
end

function LoolibEnhancedDropdownMixin:CloseMenu()
    if not self._isOpen then return end

    if self._menuFrame then
        self._menuFrame:Hide()

        -- Close any submenus
        if self._menuFrame._submenu then
            self._menuFrame._submenu:Hide()
        end
    end

    self._isOpen = false
    self.arrow:SetAtlas("Gamepad_Ltr_Down_64")
end

function LoolibEnhancedDropdownMixin:Toggle()
    if self._isOpen then
        self:CloseMenu()
    else
        self:OpenMenu()
    end
end

-- ============================================================
-- MENU FRAME CREATION
-- ============================================================

function LoolibEnhancedDropdownMixin:_CreateMenuFrame()
    local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:Hide()

    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    menu:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Content container
    menu.content = CreateFrame("Frame", nil, menu)
    menu.content:SetPoint("TOPLEFT", 4, -4)
    menu.content:SetPoint("BOTTOMRIGHT", -4, 4)

    -- Close detection
    menu:SetScript("OnUpdate", function(frame, elapsed)
        frame._elapsed = (frame._elapsed or 0) + elapsed
        if frame._elapsed < 0.1 then return end
        frame._elapsed = 0

        if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
           and not frame:IsMouseOver()
           and not self:IsMouseOver()
           and not (frame._submenu and frame._submenu:IsMouseOver()) then
            C_Timer.After(0.05, function()
                if not frame:IsMouseOver() and not self:IsMouseOver() then
                    self:CloseMenu()
                end
            end)
        end
    end)

    menu._items = {}
    menu._dropdown = self

    return menu
end

function LoolibEnhancedDropdownMixin:_BuildMenu()
    local menu = self._menuFrame

    -- Clear existing items
    for _, item in ipairs(menu._items) do
        item:Hide()
    end
    wipe(menu._items)

    local width = self._menuWidth or self:GetWidth()
    local itemHeight = 24
    local separatorHeight = 8
    local totalHeight = 0
    local yOffset = 0

    for i, option in ipairs(self._options) do
        local item = self:_CreateMenuItem(menu, option, i)
        item:SetPoint("TOPLEFT", menu.content, "TOPLEFT", 0, yOffset)
        item:SetPoint("RIGHT", menu.content, "RIGHT", 0, 0)

        if option.isSeparator then
            item:SetHeight(separatorHeight)
            yOffset = yOffset - separatorHeight
            totalHeight = totalHeight + separatorHeight
        else
            local height = itemHeight + (option.padding or 0)
            if option.slider then height = height + 20 end
            if option.editBox then height = height + 20 end
            item:SetHeight(height)
            yOffset = yOffset - height
            totalHeight = totalHeight + height
        end

        table.insert(menu._items, item)
    end

    -- Apply size constraints
    local maxHeight = self._maxLines * itemHeight
    if totalHeight > maxHeight then
        totalHeight = maxHeight
        -- TODO: Add scrollbar for long menus
    end

    menu:SetSize(width, totalHeight + 8)
    menu.content:SetSize(width - 8, totalHeight)
end

function LoolibEnhancedDropdownMixin:_CreateMenuItem(menu, option, index)
    local item = CreateFrame("Button", nil, menu.content)
    item.option = option
    item._dropdown = self

    -- Highlight
    item.highlight = item:CreateTexture(nil, "BACKGROUND")
    item.highlight:SetAllPoints()
    item.highlight:SetColorTexture(0.3, 0.5, 0.8, 0.3)
    item.highlight:Hide()

    if option.isSeparator then
        local line = item:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", 4, 0)
        line:SetPoint("RIGHT", -4, 0)
        line:SetColorTexture(0.4, 0.4, 0.4, 1)
        item:SetEnabled(false)
        return item
    end

    -- Checkbox/Radio
    if option.checkState ~= nil or option.radio then
        item.check = item:CreateTexture(nil, "ARTWORK")
        item.check:SetSize(14, 14)
        item.check:SetPoint("LEFT", 4, 0)
        if option.checkState then
            item.check:SetAtlas("common-icon-checkmark")
        else
            item.check:SetColorTexture(0, 0, 0, 0)
        end
    end

    -- Icon
    local textOffset = 8
    if option.icon then
        item.icon = item:CreateTexture(nil, "ARTWORK")
        item.icon:SetSize(16, 16)
        item.icon:SetPoint("LEFT", option.checkState ~= nil and 22 or 6, 0)
        if option.iconIsAtlas then
            item.icon:SetAtlas(option.icon)
        else
            item.icon:SetTexture(option.icon)
        end
        if option.iconCoords then
            item.icon:SetTexCoord(unpack(option.iconCoords))
        end
        textOffset = textOffset + 20
    end

    if option.checkState ~= nil then
        textOffset = textOffset + 18
    end

    -- Text
    item.text = item:CreateFontString(nil, "OVERLAY", option.font or "GameFontHighlightSmall")
    item.text:SetPoint("LEFT", textOffset, option.slider or option.editBox and 8 or 0)
    item.text:SetPoint("RIGHT", option.subMenu and -20 or -8, option.slider or option.editBox and 8 or 0)
    item.text:SetJustifyH("LEFT")

    local displayText = option.text or ""
    if option.colorCode then
        displayText = option.colorCode .. displayText .. "|r"
    end
    item.text:SetText(displayText)

    -- Title/header styling
    if option.isTitle then
        item.text:SetFontObject("GameFontNormal")
        item:SetEnabled(false)
    end

    -- Disabled styling
    if option.disabled then
        item.text:SetTextColor(0.5, 0.5, 0.5)
        item:SetEnabled(false)
    end

    -- Submenu arrow
    if option.subMenu then
        item.arrow = item:CreateTexture(nil, "ARTWORK")
        item.arrow:SetSize(10, 10)
        item.arrow:SetPoint("RIGHT", -4, 0)
        item.arrow:SetAtlas("Gamepad_Ltr_Right_64")
    end

    -- Embedded slider
    if option.slider then
        local sliderData = option.slider
        item.slider = CreateFrame("Slider", nil, item, "MinimalSliderTemplate")
        item.slider:SetSize(item:GetWidth() - textOffset - 10, 14)
        item.slider:SetPoint("BOTTOMLEFT", textOffset, 4)
        item.slider:SetPoint("BOTTOMRIGHT", -8, 4)
        item.slider:SetMinMaxValues(sliderData[1], sliderData[2])
        item.slider:SetValue(sliderData[3] or sliderData[1])
        if sliderData[5] then
            item.slider:SetValueStep(sliderData[5])
            item.slider:SetObeyStepOnDrag(true)
        end
        item.slider:SetScript("OnValueChanged", function(slider, value)
            if sliderData[4] then
                sliderData[4](value)
            end
        end)
    end

    -- Embedded editbox
    if option.editBox then
        local editData = option.editBox
        item.editBox = CreateFrame("EditBox", nil, item, "InputBoxTemplate")
        item.editBox:SetSize(editData[3] or 100, 18)
        item.editBox:SetPoint("BOTTOMLEFT", textOffset, 4)
        item.editBox:SetAutoFocus(false)
        item.editBox:SetText(editData[1] or "")
        item.editBox:SetScript("OnEnterPressed", function(editbox)
            if editData[2] then
                editData[2](editbox:GetText())
            end
            editbox:ClearFocus()
        end)
    end

    -- Scripts
    item:SetScript("OnEnter", function(itemFrame)
        if not option.disabled and not option.isTitle then
            itemFrame.highlight:Show()

            if option.subMenu then
                self:_ShowSubmenu(itemFrame, option.subMenu)
            end

            if option.tooltip then
                GameTooltip:SetOwner(itemFrame, "ANCHOR_RIGHT")
                GameTooltip:SetText(option.tooltip, nil, nil, nil, nil, true)
                GameTooltip:Show()
            end
        end
    end)

    item:SetScript("OnLeave", function(itemFrame)
        itemFrame.highlight:Hide()
        GameTooltip:Hide()
    end)

    item:SetScript("OnClick", function(itemFrame)
        if option.disabled or option.isTitle or option.isSeparator then
            return
        end

        -- Toggle checkbox
        if option.checkState ~= nil then
            option.checkState = not option.checkState
            if option.checkState then
                itemFrame.check:SetAtlas("common-icon-checkmark")
            else
                itemFrame.check:SetColorTexture(0, 0, 0, 0)
            end
            if option.onCheckChange then
                option.onCheckChange(option.checkState)
            end
            return  -- Don't close menu
        end

        -- Don't select if has submenu
        if option.subMenu then
            return
        end

        -- Select value
        self._selectedValue = option.value
        self._selectedText = option.text

        if self._autoText then
            self:_SetDisplayText(option.text, option.icon, option.iconIsAtlas)
        end

        if self._onSelectCallback then
            self._onSelectCallback(option.value, option)
        end

        self:CloseMenu()
    end)

    return item
end

-- ============================================================
-- SUBMENU HANDLING
-- ============================================================

function LoolibEnhancedDropdownMixin:_ShowSubmenu(parentItem, subOptions)
    local menu = self._menuFrame

    -- Close existing submenu
    if menu._submenu then
        menu._submenu:Hide()
    end

    -- Create submenu frame if needed
    if not menu._submenu then
        menu._submenu = CreateFrame("Frame", nil, menu, "BackdropTemplate")
        menu._submenu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu._submenu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        menu._submenu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menu._submenu:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        menu._submenu._items = {}
    end

    local submenu = menu._submenu

    -- Clear existing items
    for _, item in ipairs(submenu._items) do
        item:Hide()
    end
    wipe(submenu._items)

    -- Build submenu
    local width = self._menuWidth or 150
    local itemHeight = 24
    local totalHeight = 0
    local yOffset = -4

    for i, option in ipairs(subOptions) do
        local item = self:_CreateMenuItem(submenu, option, i)
        item:SetPoint("TOPLEFT", submenu, "TOPLEFT", 4, yOffset)
        item:SetSize(width - 8, itemHeight)
        yOffset = yOffset - itemHeight
        totalHeight = totalHeight + itemHeight
        table.insert(submenu._items, item)
    end

    submenu:SetSize(width, totalHeight + 8)
    submenu:ClearAllPoints()
    submenu:SetPoint("TOPLEFT", parentItem, "TOPRIGHT", 0, 4)
    submenu:Show()
end

-- ============================================================
-- SIZE/POSITION
-- ============================================================

function LoolibEnhancedDropdownMixin:Size(width, height)
    self:SetSize(width, height or 24)
    return self
end

function LoolibEnhancedDropdownMixin:Point(...)
    self:SetPoint(...)
    return self
end

-- ============================================================
-- FACTORY FUNCTION
-- ============================================================

---Create an enhanced dropdown
---@param parent Frame
---@param name string?
---@return Frame
local function LoolibCreateEnhancedDropdown(parent, name)
    local dropdown = CreateFrame("Button", name, parent, "BackdropTemplate")
    LoolibMixin(dropdown, LoolibEnhancedDropdownMixin)

    -- Also apply WidgetMod if available
    local WidgetMod = Loolib:GetModule("WidgetMod")
    if WidgetMod and WidgetMod.Mixin then
        LoolibMixin(dropdown, WidgetMod.Mixin)
    end

    dropdown:SetSize(150, 24)
    dropdown:OnLoad()

    return dropdown
end

-- Register with Loolib
Loolib:RegisterModule("Widgets.EnhancedDropdown", {
    Mixin = LoolibEnhancedDropdownMixin,
    Create = LoolibCreateEnhancedDropdown,
})
