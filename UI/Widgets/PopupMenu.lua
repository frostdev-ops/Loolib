--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    PopupMenu - Context/Right-Click Menus

    Features:
    - Popup context menus for right-click interactions
    - Icons, checkmarks, radio buttons
    - Separators and title headers
    - Disabled items
    - Nested submenus
    - Tooltips on hover
    - Auto-positioning to stay on screen
    - Click-outside-to-close detection
    - Keyboard navigation (Escape to close)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    MenuItem Structure
----------------------------------------------------------------------]]

--[[
MenuItem = {
    text = "Label",              -- Display text
    value = any,                 -- Value passed to callback
    icon = "path" or atlasName,  -- Optional icon
    iconIsAtlas = bool,          -- If true, icon is atlas name
    colorCode = "|cFFRRGGBB",    -- Optional color prefix
    disabled = bool,             -- Grayed out, not clickable
    checked = bool,              -- Show checkmark
    radio = bool,                -- Radio button style (mutually exclusive)
    isTitle = bool,              -- Bold, non-clickable header
    isSeparator = bool,          -- Horizontal line
    keepOpen = bool,             -- Don't close menu on click
    subMenu = { ... },           -- Nested menu items
    func = function(value),      -- Click callback (alternative to menu callback)
    tooltip = "text",            -- Hover tooltip
}
]]

--[[--------------------------------------------------------------------
    LoolibPopupMenuMixin
----------------------------------------------------------------------]]

---@class LoolibPopupMenuMixin
LoolibPopupMenuMixin = {}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function LoolibPopupMenuMixin:OnLoad()
    self._options = {}
    self._selectedValue = nil
    self._onSelectCallback = nil
    self._anchorFrame = nil
    self._menuLevel = 1
    self._parentMenu = nil
    self._childMenu = nil
    self._items = {}
    self._closeTimer = nil
    self._menuWidth = nil

    -- Set up frame properties
    self:SetFrameStrata("FULLSCREEN_DIALOG")
    self:SetClampedToScreen(true)
    self:EnableMouse(true)
    self:Hide()

    -- Create backdrop
    self:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = {left = 1, right = 1, top = 1, bottom = 1},
    })
    self:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Create scroll container for long menus
    self.scrollFrame = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
    self.scrollFrame:SetPoint("TOPLEFT", 4, -4)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", -20, 4)

    self.content = CreateFrame("Frame", nil, self.scrollFrame)
    self.scrollFrame:SetScrollChild(self.content)

    -- Close on escape
    self:EnableKeyboard(true)
    self:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Close()
            if not InCombatLockdown() then
                self:SetPropagateKeyboardInput(false)
            end
        else
            if not InCombatLockdown() then
                self:SetPropagateKeyboardInput(true)
            end
        end
    end)

    -- World click to close
    self:SetScript("OnShow", function(self)
        self:_StartCloseDetection()
    end)

    self:SetScript("OnHide", function(self)
        self:_StopCloseDetection()
        if self._childMenu then
            self._childMenu:Close()
        end
    end)
end

-- ============================================================
-- CONFIGURATION (Fluent API)
-- ============================================================

---Set menu options
---@param options table[] Array of MenuItem structures
---@return self
function LoolibPopupMenuMixin:SetOptions(options)
    self._options = options or {}
    return self
end

---Add a single option
---@param option table MenuItem structure
---@return self
function LoolibPopupMenuMixin:AddOption(option)
    table.insert(self._options, option)
    return self
end

---Add a separator
---@return self
function LoolibPopupMenuMixin:AddSeparator()
    table.insert(self._options, {isSeparator = true})
    return self
end

---Add a title/header
---@param text string
---@return self
function LoolibPopupMenuMixin:AddTitle(text)
    table.insert(self._options, {text = text, isTitle = true})
    return self
end

---Set callback for item selection
---@param callback function Function(value, menuItem)
---@return self
function LoolibPopupMenuMixin:OnSelect(callback)
    self._onSelectCallback = callback
    return self
end

---Set menu width
---@param width number
---@return self
function LoolibPopupMenuMixin:SetMenuWidth(width)
    self._menuWidth = width
    return self
end

-- ============================================================
-- SHOWING/HIDING
-- ============================================================

---Show menu at cursor position
function LoolibPopupMenuMixin:ShowAtCursor()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self:_ShowAt(x / scale, y / scale)
end

---Show menu anchored to a frame
---@param anchorFrame Frame
---@param anchor string? Anchor point (default "TOPLEFT")
---@param relativeAnchor string? Relative anchor (default "BOTTOMLEFT")
---@param xOffset number?
---@param yOffset number?
function LoolibPopupMenuMixin:ShowAt(anchorFrame, anchor, relativeAnchor, xOffset, yOffset)
    self._anchorFrame = anchorFrame
    self:ClearAllPoints()
    self:SetPoint(anchor or "TOPLEFT", anchorFrame, relativeAnchor or "BOTTOMLEFT", xOffset or 0, yOffset or 0)
    self:_Build()
    self:Show()
end

---Close the menu
function LoolibPopupMenuMixin:Close()
    -- Close child menus first
    if self._childMenu then
        self._childMenu:Close()
        self._childMenu = nil
    end

    self:Hide()
    self:_ReleaseItems()

    -- Notify parent if this is a submenu
    if self._parentMenu then
        self._parentMenu._childMenu = nil
    end
end

function LoolibPopupMenuMixin:_ShowAt(x, y)
    self:ClearAllPoints()

    -- Build menu to get dimensions
    self:_Build()

    -- Adjust position to stay on screen
    local width, height = self:GetSize()
    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()

    if x + width > screenWidth then
        x = screenWidth - width - 10
    end
    if y - height < 0 then
        y = height + 10
    end

    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    self:Show()
end

-- ============================================================
-- MENU BUILDING
-- ============================================================

function LoolibPopupMenuMixin:_Build()
    self:_ReleaseItems()

    local maxWidth = self._menuWidth or 150
    local totalHeight = 8  -- Padding
    local itemHeight = 22
    local separatorHeight = 8

    for i, option in ipairs(self._options) do
        local item = self:_CreateItem(option, i)

        if option.isSeparator then
            item:SetHeight(separatorHeight)
            totalHeight = totalHeight + separatorHeight
        else
            item:SetHeight(itemHeight)
            totalHeight = totalHeight + itemHeight

            -- Track max width
            if item.text then
                local textWidth = item.text:GetStringWidth() + 50  -- Icon + padding + arrow
                if textWidth > maxWidth then
                    maxWidth = textWidth
                end
            end
        end

        table.insert(self._items, item)
    end

    -- Position items
    local yOffset = -4
    for _, item in ipairs(self._items) do
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, yOffset)
        item:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -4, yOffset)
        yOffset = yOffset - item:GetHeight()
    end

    -- Set sizes
    self.content:SetSize(maxWidth, totalHeight)
    self:SetSize(maxWidth + 8, math.min(totalHeight + 8, 400))
end

function LoolibPopupMenuMixin:_CreateItem(option, index)
    local item = CreateFrame("Button", nil, self.content)
    item.option = option
    item.menuIndex = index
    item.parentMenu = self

    -- Background highlight
    item.highlight = item:CreateTexture(nil, "BACKGROUND")
    item.highlight:SetAllPoints()
    item.highlight:SetColorTexture(0.3, 0.5, 0.8, 0.3)
    item.highlight:Hide()

    if option.isSeparator then
        -- Separator line
        local line = item:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("LEFT", 4, 0)
        line:SetPoint("RIGHT", -4, 0)
        line:SetColorTexture(0.4, 0.4, 0.4, 1)
        item:SetEnabled(false)
    else
        -- Icon
        item.icon = item:CreateTexture(nil, "ARTWORK")
        item.icon:SetSize(16, 16)
        item.icon:SetPoint("LEFT", 4, 0)

        if option.icon then
            if option.iconIsAtlas then
                item.icon:SetAtlas(option.icon)
            else
                item.icon:SetTexture(option.icon)
            end
            item.icon:Show()
        else
            item.icon:Hide()
        end

        -- Check/Radio indicator
        item.check = item:CreateTexture(nil, "ARTWORK")
        item.check:SetSize(14, 14)
        item.check:SetPoint("LEFT", 4, 0)
        item.check:Hide()

        local hasCheckOrRadio = false
        if option.checked then
            item.check:SetAtlas("common-icon-checkmark")
            item.check:Show()
            hasCheckOrRadio = true
        elseif option.radio then
            item.check:SetAtlas("common-icon-checkmark-yellow")
            if option.checked then
                item.check:Show()
            end
            hasCheckOrRadio = true
        end

        -- Adjust icon position if we have a check/radio
        if hasCheckOrRadio and option.icon then
            item.icon:SetPoint("LEFT", 20, 0)
        end

        -- Text
        item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local leftOffset = 8
        if option.icon then
            leftOffset = hasCheckOrRadio and 40 or 24
        elseif hasCheckOrRadio then
            leftOffset = 24
        end
        item.text:SetPoint("LEFT", leftOffset, 0)
        item.text:SetPoint("RIGHT", option.subMenu and -20 or -8, 0)
        item.text:SetJustifyH("LEFT")

        local displayText = option.text or ""
        if option.colorCode then
            displayText = option.colorCode .. displayText .. "|r"
        end
        item.text:SetText(displayText)

        -- Title styling
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
            item.arrow:SetSize(12, 12)
            item.arrow:SetPoint("RIGHT", -4, 0)
            item.arrow:SetAtlas("Gamepad_Ltr_Right_64")
        end

        -- Scripts
        item:SetScript("OnEnter", function(self)
            if not option.disabled and not option.isTitle then
                self.highlight:Show()

                -- Show submenu
                if option.subMenu then
                    self.parentMenu:_ShowSubmenu(self, option.subMenu)
                else
                    -- Close any open submenu
                    if self.parentMenu._childMenu then
                        self.parentMenu._childMenu:Close()
                    end
                end

                -- Tooltip
                if option.tooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(option.tooltip, nil, nil, nil, nil, true)
                    GameTooltip:Show()
                end
            end
        end)

        item:SetScript("OnLeave", function(self)
            self.highlight:Hide()
            GameTooltip:Hide()
        end)

        item:SetScript("OnClick", function(self)
            if option.disabled or option.isTitle or option.isSeparator then
                return
            end

            -- Call item callback if exists
            if option.func then
                option.func(option.value or option.text)
            end

            -- Call menu callback
            if self.parentMenu._onSelectCallback then
                self.parentMenu._onSelectCallback(option.value or option.text, option)
            end

            -- Close menu unless keepOpen
            if not option.keepOpen and not option.subMenu then
                -- Close all parent menus
                local menu = self.parentMenu
                while menu do
                    local parent = menu._parentMenu
                    menu:Close()
                    menu = parent
                end
            end
        end)
    end

    return item
end

-- ============================================================
-- SUBMENU HANDLING
-- ============================================================

function LoolibPopupMenuMixin:_ShowSubmenu(parentItem, subOptions)
    -- Close existing submenu
    if self._childMenu then
        self._childMenu:Close()
    end

    -- Create submenu
    local submenu = LoolibCreatePopupMenu()
    submenu._parentMenu = self
    submenu._menuLevel = self._menuLevel + 1
    submenu:SetOptions(subOptions)

    -- Position to the right of parent item
    submenu:ShowAt(parentItem, "TOPLEFT", "TOPRIGHT", 0, 0)

    self._childMenu = submenu
end

-- ============================================================
-- CLOSE DETECTION
-- ============================================================

function LoolibPopupMenuMixin:_StartCloseDetection()
    if not self._closeFrame then
        self._closeFrame = CreateFrame("Frame")
    end

    local menu = self
    self._closeFrame:SetScript("OnUpdate", function()
        if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
            -- Check if click is outside menu hierarchy
            if not menu:_IsMouseOverMenuHierarchy() then
                -- Delay close slightly to allow click events to process
                C_Timer.After(0.05, function()
                    if menu:IsShown() and not menu:_IsMouseOverMenuHierarchy() then
                        menu:Close()
                    end
                end)
            end
        end
    end)
end

function LoolibPopupMenuMixin:_StopCloseDetection()
    if self._closeFrame then
        self._closeFrame:SetScript("OnUpdate", nil)
    end
end

function LoolibPopupMenuMixin:_IsMouseOverMenuHierarchy()
    if self:IsMouseOver() then
        return true
    end
    if self._childMenu and self._childMenu:_IsMouseOverMenuHierarchy() then
        return true
    end
    return false
end

-- ============================================================
-- CLEANUP
-- ============================================================

function LoolibPopupMenuMixin:_ReleaseItems()
    for _, item in ipairs(self._items) do
        item:Hide()
        item:SetParent(nil)
    end
    wipe(self._items)
end

-- ============================================================
-- FACTORY FUNCTIONS
-- ============================================================

---Create a popup menu
---@param parent Frame? Parent frame (defaults to UIParent)
---@param name string? Optional global name
---@return Frame
function LoolibCreatePopupMenu(parent, name)
    local menu = CreateFrame("Frame", name, parent or UIParent, BackdropTemplateMixin and "BackdropTemplate")
    LoolibMixin(menu, LoolibPopupMenuMixin)
    menu:OnLoad()
    return menu
end

-- Shared menu singleton for simple use cases
local sharedMenu = nil

---Get or create shared popup menu
---@return Frame
function LoolibGetSharedPopupMenu()
    if not sharedMenu then
        sharedMenu = LoolibCreatePopupMenu()
    end
    return sharedMenu
end

--[[--------------------------------------------------------------------
    Fluent API Builder (optional convenience)
----------------------------------------------------------------------]]

---@class LoolibPopupMenuBuilderMixin
LoolibPopupMenuBuilderMixin = {}

function LoolibPopupMenuBuilderMixin:Init()
    self._options = {}
    self._callback = nil
    self._width = nil
end

function LoolibPopupMenuBuilderMixin:AddOption(text, value, options)
    options = options or {}
    table.insert(self._options, {
        text = text,
        value = value,
        icon = options.icon,
        iconIsAtlas = options.iconIsAtlas,
        colorCode = options.colorCode,
        disabled = options.disabled,
        checked = options.checked,
        radio = options.radio,
        keepOpen = options.keepOpen,
        subMenu = options.subMenu,
        func = options.func,
        tooltip = options.tooltip,
    })
    return self
end

function LoolibPopupMenuBuilderMixin:AddSeparator()
    table.insert(self._options, {isSeparator = true})
    return self
end

function LoolibPopupMenuBuilderMixin:AddTitle(text)
    table.insert(self._options, {text = text, isTitle = true})
    return self
end

function LoolibPopupMenuBuilderMixin:OnSelect(callback)
    self._callback = callback
    return self
end

function LoolibPopupMenuBuilderMixin:SetWidth(width)
    self._width = width
    return self
end

function LoolibPopupMenuBuilderMixin:ShowAtCursor()
    local menu = LoolibGetSharedPopupMenu()
    menu:SetOptions(self._options)
    if self._callback then
        menu:OnSelect(self._callback)
    end
    if self._width then
        menu:SetMenuWidth(self._width)
    end
    menu:ShowAtCursor()
    return menu
end

function LoolibPopupMenuBuilderMixin:ShowAt(anchorFrame, anchor, relativeAnchor, xOffset, yOffset)
    local menu = LoolibGetSharedPopupMenu()
    menu:SetOptions(self._options)
    if self._callback then
        menu:OnSelect(self._callback)
    end
    if self._width then
        menu:SetMenuWidth(self._width)
    end
    menu:ShowAt(anchorFrame, anchor, relativeAnchor, xOffset, yOffset)
    return menu
end

---Create a popup menu builder for fluent API
---@return LoolibPopupMenuBuilderMixin
function LoolibPopupMenu()
    local builder = LoolibCreateFromMixins(LoolibPopupMenuBuilderMixin)
    builder:Init()
    return builder
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local PopupMenuModule = {
    Mixin = LoolibPopupMenuMixin,
    BuilderMixin = LoolibPopupMenuBuilderMixin,
    Create = LoolibCreatePopupMenu,
    GetShared = LoolibGetSharedPopupMenu,
    Builder = LoolibPopupMenu,
}

local UI = Loolib:GetOrCreateModule("UI")
UI.PopupMenu = PopupMenuModule
UI.CreatePopupMenu = LoolibCreatePopupMenu
UI.GetSharedPopupMenu = LoolibGetSharedPopupMenu

Loolib:RegisterModule("PopupMenu", PopupMenuModule)
