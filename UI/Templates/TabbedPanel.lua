--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    TabbedPanel - Tabbed container with lazy content loading

    Features:
    - Lazy content initialization
    - Tab button pooling
    - Enable/disable tabs
    - Badge/notification indicators
    - Tab position (TOP, BOTTOM, LEFT, RIGHT)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibTabbedPanelMixin
----------------------------------------------------------------------]]

LoolibTabbedPanelMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local TABBED_PANEL_EVENTS = {
    "OnTabChanged",
    "OnTabAdded",
    "OnTabRemoved",
}

--- Initialize the tabbed panel
function LoolibTabbedPanelMixin:OnLoad()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(TABBED_PANEL_EVENTS)

    self.tabs = {}  -- { id, text, content, enabled, badge, button }
    self.tabButtons = {}
    self.activeTabId = nil
    self.tabPosition = "TOP"
    self.tabSpacing = 2
    self.tabMinWidth = 60
    self.tabHeight = 28

    -- Get references
    self.TabBar = self.TabBar or self:GetName() and _G[self:GetName() .. "TabBar"]
    self.ContentFrame = self.ContentFrame or self:GetName() and _G[self:GetName() .. "ContentFrame"]

    -- Create tab button pool
    self.tabButtonPool = CreateLoolibFramePool("Button", self.TabBar, "LoolibTabButtonTemplate")
end

--[[--------------------------------------------------------------------
    Tab Management
----------------------------------------------------------------------]]

--- Add a tab
-- @param id string - Unique tab identifier
-- @param text string - Tab button text
-- @param content Frame|function - Content frame or lazy initializer function
-- @param options table - Optional: { enabled, badge, icon }
-- @return table - The tab data
function LoolibTabbedPanelMixin:AddTab(id, text, content, options)
    options = options or {}

    local tab = {
        id = id,
        text = text,
        content = content,
        contentFrame = nil,  -- Actual frame (created lazily)
        enabled = options.enabled ~= false,
        badge = options.badge,
        icon = options.icon,
        button = nil,
    }

    self.tabs[#self.tabs + 1] = tab

    self:RefreshTabButtons()
    self:TriggerEvent("OnTabAdded", tab)

    -- Select first tab if none selected
    if not self.activeTabId then
        self:SelectTab(id)
    end

    return tab
end

--- Remove a tab
-- @param id string - Tab identifier
function LoolibTabbedPanelMixin:RemoveTab(id)
    for i, tab in ipairs(self.tabs) do
        if tab.id == id then
            -- Hide content
            if tab.contentFrame then
                tab.contentFrame:Hide()
            end

            table.remove(self.tabs, i)
            self:RefreshTabButtons()
            self:TriggerEvent("OnTabRemoved", tab)

            -- Select another tab if this was active
            if self.activeTabId == id then
                self.activeTabId = nil
                if #self.tabs > 0 then
                    self:SelectTab(self.tabs[1].id)
                end
            end

            return
        end
    end
end

--- Get a tab by id
-- @param id string - Tab identifier
-- @return table|nil - The tab data
function LoolibTabbedPanelMixin:GetTab(id)
    for _, tab in ipairs(self.tabs) do
        if tab.id == id then
            return tab
        end
    end
    return nil
end

--- Get all tabs
-- @return table - Array of tab data
function LoolibTabbedPanelMixin:GetTabs()
    return self.tabs
end

--[[--------------------------------------------------------------------
    Tab Selection
----------------------------------------------------------------------]]

--- Select a tab
-- @param id string - Tab identifier
function LoolibTabbedPanelMixin:SelectTab(id)
    local tab = self:GetTab(id)
    if not tab or not tab.enabled then
        return
    end

    local previousId = self.activeTabId

    -- Hide current content
    if self.activeTabId then
        local currentTab = self:GetTab(self.activeTabId)
        if currentTab and currentTab.contentFrame then
            currentTab.contentFrame:Hide()
        end
    end

    self.activeTabId = id

    -- Get or create content
    local contentFrame = self:GetOrCreateContent(tab)
    if contentFrame then
        contentFrame:SetParent(self.ContentFrame)
        contentFrame:ClearAllPoints()
        contentFrame:SetAllPoints(self.ContentFrame)
        contentFrame:Show()
    end

    -- Update button states
    self:UpdateTabButtonStates()

    if previousId ~= id then
        self:TriggerEvent("OnTabChanged", id, previousId)
    end
end

--- Get the active tab id
-- @return string|nil
function LoolibTabbedPanelMixin:GetActiveTab()
    return self.activeTabId
end

--- Get or create content for a tab
-- @param tab table - Tab data
-- @return Frame|nil
function LoolibTabbedPanelMixin:GetOrCreateContent(tab)
    if tab.contentFrame then
        return tab.contentFrame
    end

    if type(tab.content) == "function" then
        -- Lazy initialization
        tab.contentFrame = tab.content()
    elseif type(tab.content) == "table" then
        tab.contentFrame = tab.content
    end

    return tab.contentFrame
end

--[[--------------------------------------------------------------------
    Tab State
----------------------------------------------------------------------]]

--- Enable or disable a tab
-- @param id string - Tab identifier
-- @param enabled boolean - Whether enabled
function LoolibTabbedPanelMixin:SetTabEnabled(id, enabled)
    local tab = self:GetTab(id)
    if tab then
        tab.enabled = enabled
        self:UpdateTabButtonStates()

        -- Switch away if this tab is active and now disabled
        if not enabled and self.activeTabId == id then
            for _, t in ipairs(self.tabs) do
                if t.enabled and t.id ~= id then
                    self:SelectTab(t.id)
                    break
                end
            end
        end
    end
end

--- Set a badge on a tab
-- @param id string - Tab identifier
-- @param badge string|number|nil - Badge text (nil to clear)
function LoolibTabbedPanelMixin:SetTabBadge(id, badge)
    local tab = self:GetTab(id)
    if tab then
        tab.badge = badge
        self:UpdateTabButtonStates()
    end
end

--- Set tab text
-- @param id string - Tab identifier
-- @param text string - New text
function LoolibTabbedPanelMixin:SetTabText(id, text)
    local tab = self:GetTab(id)
    if tab then
        tab.text = text
        if tab.button then
            tab.button.Text:SetText(text)
        end
    end
end

--[[--------------------------------------------------------------------
    Tab Buttons
----------------------------------------------------------------------]]

--- Refresh all tab buttons
function LoolibTabbedPanelMixin:RefreshTabButtons()
    -- Release all buttons
    self.tabButtonPool:ReleaseAll()

    local xOffset = 0

    for i, tab in ipairs(self.tabs) do
        local button = self.tabButtonPool:Acquire()
        tab.button = button
        button.tab = tab
        button.panel = self

        -- Set text
        if button.Text then
            button.Text:SetText(tab.text)
        end

        -- Size based on text
        local textWidth = button.Text and button.Text:GetStringWidth() or 50
        local buttonWidth = math.max(self.tabMinWidth, textWidth + 20)
        button:SetSize(buttonWidth, self.tabHeight)

        -- Position
        button:ClearAllPoints()
        if self.tabPosition == "TOP" or self.tabPosition == "BOTTOM" then
            button:SetPoint("LEFT", self.TabBar, "LEFT", xOffset, 0)
            xOffset = xOffset + buttonWidth + self.tabSpacing
        else
            button:SetPoint("TOP", self.TabBar, "TOP", 0, -xOffset)
            xOffset = xOffset + self.tabHeight + self.tabSpacing
        end

        -- Click handler
        button:SetScript("OnClick", function()
            self:SelectTab(tab.id)
        end)

        button:Show()
    end

    self:UpdateTabButtonStates()
end

--- Update tab button visual states
function LoolibTabbedPanelMixin:UpdateTabButtonStates()
    for _, tab in ipairs(self.tabs) do
        if tab.button then
            local button = tab.button
            local isActive = tab.id == self.activeTabId

            -- Enabled/disabled
            button:SetEnabled(tab.enabled)
            if button.Text then
                if not tab.enabled then
                    button.Text:SetTextColor(0.5, 0.5, 0.5, 1)
                elseif isActive then
                    button.Text:SetTextColor(1, 0.82, 0, 1)  -- Gold
                else
                    button.Text:SetTextColor(1, 1, 1, 1)
                end
            end

            -- Active background
            if button.Background then
                if isActive then
                    button.Background:SetColorTexture(0.2, 0.4, 0.6, 0.9)
                else
                    button.Background:SetColorTexture(0.15, 0.15, 0.15, 0.9)
                end
            end

            -- Badge
            if button.Badge then
                if tab.badge then
                    button.Badge:SetText(tostring(tab.badge))
                    button.Badge:Show()
                else
                    button.Badge:Hide()
                end
            end
        end
    end
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set tab position
-- @param position string - TOP, BOTTOM, LEFT, RIGHT
function LoolibTabbedPanelMixin:SetTabPosition(position)
    self.tabPosition = position

    -- Adjust TabBar and ContentFrame anchors
    if self.TabBar and self.ContentFrame then
        self.TabBar:ClearAllPoints()
        self.ContentFrame:ClearAllPoints()

        if position == "TOP" then
            self.TabBar:SetPoint("TOPLEFT")
            self.TabBar:SetPoint("TOPRIGHT")
            self.TabBar:SetHeight(self.tabHeight)
            self.ContentFrame:SetPoint("TOPLEFT", self.TabBar, "BOTTOMLEFT")
            self.ContentFrame:SetPoint("BOTTOMRIGHT")
        elseif position == "BOTTOM" then
            self.TabBar:SetPoint("BOTTOMLEFT")
            self.TabBar:SetPoint("BOTTOMRIGHT")
            self.TabBar:SetHeight(self.tabHeight)
            self.ContentFrame:SetPoint("TOPLEFT")
            self.ContentFrame:SetPoint("BOTTOMRIGHT", self.TabBar, "TOPRIGHT")
        elseif position == "LEFT" then
            self.TabBar:SetPoint("TOPLEFT")
            self.TabBar:SetPoint("BOTTOMLEFT")
            self.TabBar:SetWidth(self.tabMinWidth)
            self.ContentFrame:SetPoint("TOPLEFT", self.TabBar, "TOPRIGHT")
            self.ContentFrame:SetPoint("BOTTOMRIGHT")
        elseif position == "RIGHT" then
            self.TabBar:SetPoint("TOPRIGHT")
            self.TabBar:SetPoint("BOTTOMRIGHT")
            self.TabBar:SetWidth(self.tabMinWidth)
            self.ContentFrame:SetPoint("TOPLEFT")
            self.ContentFrame:SetPoint("BOTTOMRIGHT", self.TabBar, "BOTTOMLEFT")
        end
    end

    self:RefreshTabButtons()
end

--- Set tab spacing
-- @param spacing number
function LoolibTabbedPanelMixin:SetTabSpacing(spacing)
    self.tabSpacing = spacing
    self:RefreshTabButtons()
end

--- Set minimum tab width
-- @param width number
function LoolibTabbedPanelMixin:SetTabMinWidth(width)
    self.tabMinWidth = width
    self:RefreshTabButtons()
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a tabbed panel
-- @param parent Frame - Parent frame
-- @return Frame - The tabbed panel
function CreateLoolibTabbedPanel(parent)
    local panel = CreateFrame("Frame", nil, parent, "LoolibTabbedPanelTemplate")
    LoolibMixin(panel, LoolibTabbedPanelMixin)
    panel:OnLoad()
    return panel
end

--[[--------------------------------------------------------------------
    Builder Pattern
----------------------------------------------------------------------]]

LoolibTabbedPanelBuilderMixin = {}

function LoolibTabbedPanelBuilderMixin:Init(parent)
    self.parent = parent
    self.tabs = {}
    self.config = {}
end

function LoolibTabbedPanelBuilderMixin:AddTab(id, text, content, options)
    self.tabs[#self.tabs + 1] = { id = id, text = text, content = content, options = options }
    return self
end

function LoolibTabbedPanelBuilderMixin:SetTabPosition(position)
    self.config.tabPosition = position
    return self
end

function LoolibTabbedPanelBuilderMixin:OnTabChanged(callback)
    self.config.onTabChanged = callback
    return self
end

function LoolibTabbedPanelBuilderMixin:Build()
    local panel = CreateLoolibTabbedPanel(self.parent)

    if self.config.tabPosition then
        panel:SetTabPosition(self.config.tabPosition)
    end

    if self.config.onTabChanged then
        panel:RegisterCallback("OnTabChanged", self.config.onTabChanged)
    end

    for _, tab in ipairs(self.tabs) do
        panel:AddTab(tab.id, tab.text, tab.content, tab.options)
    end

    return panel
end

function LoolibTabbedPanel(parent)
    local builder = LoolibCreateFromMixins(LoolibTabbedPanelBuilderMixin)
    builder:Init(parent)
    return builder
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local TabbedPanelModule = {
    Mixin = LoolibTabbedPanelMixin,
    BuilderMixin = LoolibTabbedPanelBuilderMixin,
    Create = CreateLoolibTabbedPanel,
    Builder = LoolibTabbedPanel,
}

local UI = Loolib:GetOrCreateModule("UI")
UI.TabbedPanel = TabbedPanelModule
UI.CreateTabbedPanel = CreateLoolibTabbedPanel

Loolib:RegisterModule("TabbedPanel", TabbedPanelModule)
