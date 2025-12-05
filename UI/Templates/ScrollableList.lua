--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ScrollableList - Virtual scrolling list with data provider integration

    Features:
    - Virtual scrolling (only renders visible items)
    - Frame pooling for list items
    - DataProvider integration with auto-updates
    - Selection support (single/multi)
    - Keyboard navigation
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibScrollableListMixin
----------------------------------------------------------------------]]

LoolibScrollableListMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local LIST_EVENTS = {
    "OnSelectionChanged",
    "OnItemClicked",
    "OnItemDoubleClicked",
    "OnItemEnter",
    "OnItemLeave",
}

--- Initialize the scrollable list
function LoolibScrollableListMixin:OnLoad()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(LIST_EVENTS)

    self.itemPool = nil
    self.itemHeight = 24
    self.itemTemplate = "LoolibListItemTemplate"
    self.itemInitializer = nil
    self.dataProvider = nil
    self.selectionMode = "SINGLE"  -- NONE, SINGLE, MULTI
    self.selection = {}
    self.visibleItems = {}
    self.scrollOffset = 0
    self.pendingRefresh = false

    -- Get references to child frames
    self.ScrollFrame = self.ScrollFrame or self:GetName() and _G[self:GetName() .. "ScrollFrame"]
    self.Content = self.ScrollFrame and self.ScrollFrame.Content

    -- Set up scroll handling
    if self.ScrollFrame then
        self.ScrollFrame:SetScript("OnVerticalScroll", function(_, offset)
            self.scrollOffset = offset
            self:Refresh()
        end)
    end

    -- Enable mouse wheel
    self:EnableMouseWheel(true)
    self:SetScript("OnMouseWheel", function(_, delta)
        local scrollStep = self.itemHeight * 3
        local currentScroll = self.ScrollFrame:GetVerticalScroll()
        local newScroll = currentScroll - (delta * scrollStep)
        self.ScrollFrame:SetVerticalScroll(math.max(0, newScroll))
    end)
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set the item template
-- @param template string - Template name
function LoolibScrollableListMixin:SetItemTemplate(template)
    self.itemTemplate = template
    self.itemPool = nil  -- Invalidate pool
end

--- Set the item height
-- @param height number - Height in pixels
function LoolibScrollableListMixin:SetItemHeight(height)
    self.itemHeight = height
    self:MarkDirty()
end

--- Set the item initializer function
-- @param initializer function - Function(frame, data, index)
function LoolibScrollableListMixin:SetInitializer(initializer)
    self.itemInitializer = initializer
end

--- Set the selection mode
-- @param mode string - NONE, SINGLE, MULTI
function LoolibScrollableListMixin:SetSelectionMode(mode)
    self.selectionMode = mode
    self:ClearSelection()
end

--[[--------------------------------------------------------------------
    Data Provider
----------------------------------------------------------------------]]

--- Set the data provider
-- @param dataProvider table - DataProvider instance
function LoolibScrollableListMixin:SetDataProvider(dataProvider)
    -- Unregister from old provider
    if self.dataProvider then
        self.dataProvider:UnregisterCallback("OnSizeChanged", self)
        self.dataProvider:UnregisterCallback("OnInsert", self)
        self.dataProvider:UnregisterCallback("OnRemove", self)
        self.dataProvider:UnregisterCallback("OnUpdate", self)
        self.dataProvider:UnregisterCallback("OnFlush", self)
        self.dataProvider:UnregisterCallback("OnSort", self)
    end

    self.dataProvider = dataProvider

    -- Register with new provider
    if dataProvider then
        dataProvider:RegisterCallback("OnSizeChanged", self.OnDataSizeChanged, self)
        dataProvider:RegisterCallback("OnInsert", self.OnDataInsert, self)
        dataProvider:RegisterCallback("OnRemove", self.OnDataRemove, self)
        dataProvider:RegisterCallback("OnUpdate", self.OnDataUpdate, self)
        dataProvider:RegisterCallback("OnFlush", self.OnDataFlush, self)
        dataProvider:RegisterCallback("OnSort", self.OnDataSort, self)
    end

    self:ClearSelection()
    self:MarkDirty()
end

--- Get the data provider
-- @return table|nil
function LoolibScrollableListMixin:GetDataProvider()
    return self.dataProvider
end

-- Data provider callbacks
function LoolibScrollableListMixin:OnDataSizeChanged()
    self:MarkDirty()
end

function LoolibScrollableListMixin:OnDataInsert(elementData, index)
    self:MarkDirty()
end

function LoolibScrollableListMixin:OnDataRemove(elementData, index)
    -- Remove from selection if selected
    self.selection[elementData] = nil
    self:MarkDirty()
end

function LoolibScrollableListMixin:OnDataUpdate(elementData, index)
    self:RefreshItem(elementData)
end

function LoolibScrollableListMixin:OnDataFlush()
    self:ClearSelection()
    self:MarkDirty()
end

function LoolibScrollableListMixin:OnDataSort()
    self:MarkDirty()
end

--[[--------------------------------------------------------------------
    Selection
----------------------------------------------------------------------]]

--- Select a data element
-- @param elementData any - The data to select
function LoolibScrollableListMixin:SelectData(elementData)
    if self.selectionMode == "NONE" then
        return
    end

    if self.selectionMode == "SINGLE" then
        local changed = next(self.selection) ~= nil or not self.selection[elementData]
        wipe(self.selection)
        self.selection[elementData] = true
        if changed then
            self:TriggerEvent("OnSelectionChanged", self:GetSelection())
            self:Refresh()
        end
    else  -- MULTI
        if not self.selection[elementData] then
            self.selection[elementData] = true
            self:TriggerEvent("OnSelectionChanged", self:GetSelection())
            self:Refresh()
        end
    end
end

--- Deselect a data element
-- @param elementData any - The data to deselect
function LoolibScrollableListMixin:DeselectData(elementData)
    if self.selection[elementData] then
        self.selection[elementData] = nil
        self:TriggerEvent("OnSelectionChanged", self:GetSelection())
        self:Refresh()
    end
end

--- Toggle selection of a data element
-- @param elementData any - The data to toggle
function LoolibScrollableListMixin:ToggleSelect(elementData)
    if self.selection[elementData] then
        self:DeselectData(elementData)
    else
        self:SelectData(elementData)
    end
end

--- Clear all selection
function LoolibScrollableListMixin:ClearSelection()
    if next(self.selection) then
        wipe(self.selection)
        self:TriggerEvent("OnSelectionChanged", {})
        self:Refresh()
    end
end

--- Get the current selection
-- @return table - Array of selected data elements
function LoolibScrollableListMixin:GetSelection()
    local result = {}
    for data in pairs(self.selection) do
        result[#result + 1] = data
    end
    return result
end

--- Get the first selected item
-- @return any|nil
function LoolibScrollableListMixin:GetFirstSelected()
    for data in pairs(self.selection) do
        return data
    end
    return nil
end

--- Check if a data element is selected
-- @param elementData any
-- @return boolean
function LoolibScrollableListMixin:IsSelected(elementData)
    return self.selection[elementData] == true
end

--[[--------------------------------------------------------------------
    Scrolling
----------------------------------------------------------------------]]

--- Scroll to a data element
-- @param elementData any - The data to scroll to
function LoolibScrollableListMixin:ScrollToData(elementData)
    if not self.dataProvider then
        return
    end

    local index = self.dataProvider:FindIndex(elementData)
    if index then
        self:ScrollToIndex(index)
    end
end

--- Scroll to an index
-- @param index number - The index to scroll to
function LoolibScrollableListMixin:ScrollToIndex(index)
    local targetOffset = (index - 1) * self.itemHeight
    self.ScrollFrame:SetVerticalScroll(targetOffset)
end

--- Scroll to the top
function LoolibScrollableListMixin:ScrollToTop()
    self.ScrollFrame:SetVerticalScroll(0)
end

--- Scroll to the bottom
function LoolibScrollableListMixin:ScrollToBottom()
    local totalHeight = self:GetTotalHeight()
    local viewHeight = self.ScrollFrame:GetHeight()
    self.ScrollFrame:SetVerticalScroll(math.max(0, totalHeight - viewHeight))
end

--[[--------------------------------------------------------------------
    Refresh
----------------------------------------------------------------------]]

--- Mark the list as needing refresh
function LoolibScrollableListMixin:MarkDirty()
    if not self.pendingRefresh then
        self.pendingRefresh = true
        C_Timer.After(0, function()
            self.pendingRefresh = false
            self:Refresh()
        end)
    end
end

--- Get the total content height
-- @return number
function LoolibScrollableListMixin:GetTotalHeight()
    if not self.dataProvider then
        return 0
    end
    return self.dataProvider:GetSize() * self.itemHeight
end

--- Refresh the list display
function LoolibScrollableListMixin:Refresh()
    if not self.dataProvider or not self.Content then
        return
    end

    -- Ensure data is up to date
    self.dataProvider:EnsureUpToDate()

    -- Create item pool if needed
    if not self.itemPool then
        self.itemPool = CreateLoolibFramePool("Button", self.Content, self.itemTemplate)
    end

    -- Release all current items
    self.itemPool:ReleaseAll()
    wipe(self.visibleItems)

    -- Calculate visible range
    local scrollOffset = self.ScrollFrame:GetVerticalScroll()
    local viewHeight = self.ScrollFrame:GetHeight()
    local totalItems = self.dataProvider:GetSize()

    local firstVisible = math.floor(scrollOffset / self.itemHeight) + 1
    local lastVisible = math.ceil((scrollOffset + viewHeight) / self.itemHeight)
    lastVisible = math.min(lastVisible, totalItems)

    -- Update content size
    self.Content:SetSize(self.ScrollFrame:GetWidth() - 4, self:GetTotalHeight())

    -- Create visible items
    for i = firstVisible, lastVisible do
        local elementData = self.dataProvider:Find(i)
        if elementData then
            local frame = self.itemPool:Acquire()
            frame.index = i
            frame.data = elementData
            frame.list = self

            -- Position
            frame:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, -((i - 1) * self.itemHeight))
            frame:SetPoint("RIGHT", self.Content, "RIGHT", 0, 0)
            frame:SetHeight(self.itemHeight)

            -- Initialize
            if self.itemInitializer then
                self.itemInitializer(frame, elementData, i)
            end

            -- Selection state
            self:UpdateItemSelection(frame, elementData)

            -- Set up click handling
            frame:SetScript("OnClick", function(f, button)
                self:OnItemClick(f, f.data, button)
            end)

            frame:SetScript("OnDoubleClick", function(f, button)
                self:TriggerEvent("OnItemDoubleClicked", f.data, f.index, button)
            end)

            frame:SetScript("OnEnter", function(f)
                self:TriggerEvent("OnItemEnter", f.data, f.index, f)
            end)

            frame:SetScript("OnLeave", function(f)
                self:TriggerEvent("OnItemLeave", f.data, f.index, f)
            end)

            frame:Show()
            self.visibleItems[elementData] = frame
        end
    end
end

--- Update the selection visual for an item
-- @param frame Frame - The item frame
-- @param elementData any - The data
function LoolibScrollableListMixin:UpdateItemSelection(frame, elementData)
    local isSelected = self:IsSelected(elementData)
    frame.selected = isSelected

    if frame.Background then
        if isSelected then
            frame.Background:SetColorTexture(0.2, 0.4, 0.6, 0.5)
        else
            frame.Background:SetColorTexture(0, 0, 0, 0)
        end
    end

    if frame.Highlight then
        if isSelected then
            frame.Highlight:Show()
        else
            frame.Highlight:Hide()
        end
    end
end

--- Refresh a specific item
-- @param elementData any - The data element to refresh
function LoolibScrollableListMixin:RefreshItem(elementData)
    local frame = self.visibleItems[elementData]
    if frame and self.itemInitializer then
        self.itemInitializer(frame, elementData, frame.index)
        self:UpdateItemSelection(frame, elementData)
    end
end

--- Handle item click
function LoolibScrollableListMixin:OnItemClick(frame, elementData, button)
    if self.selectionMode == "NONE" then
        self:TriggerEvent("OnItemClicked", elementData, frame.index, button)
        return
    end

    if self.selectionMode == "MULTI" and IsControlKeyDown() then
        self:ToggleSelect(elementData)
    elseif self.selectionMode == "MULTI" and IsShiftKeyDown() and self:GetFirstSelected() then
        -- Range selection
        local firstSelected = self:GetFirstSelected()
        local firstIndex = self.dataProvider:FindIndex(firstSelected)
        local clickIndex = frame.index
        local startIdx = math.min(firstIndex, clickIndex)
        local endIdx = math.max(firstIndex, clickIndex)

        wipe(self.selection)
        for i = startIdx, endIdx do
            local data = self.dataProvider:Find(i)
            if data then
                self.selection[data] = true
            end
        end
        self:TriggerEvent("OnSelectionChanged", self:GetSelection())
        self:Refresh()
    else
        self:SelectData(elementData)
    end

    self:TriggerEvent("OnItemClicked", elementData, frame.index, button)
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a scrollable list
-- @param parent Frame - Parent frame
-- @return Frame - The list frame
function CreateLoolibScrollableList(parent)
    local list = CreateFrame("Frame", nil, parent, "LoolibScrollableListTemplate")
    LoolibMixin(list, LoolibScrollableListMixin)
    list:OnLoad()
    return list
end

--[[--------------------------------------------------------------------
    Builder Pattern
----------------------------------------------------------------------]]

LoolibScrollableListBuilderMixin = {}

function LoolibScrollableListBuilderMixin:Init(parent)
    self.parent = parent
    self.config = {}
end

function LoolibScrollableListBuilderMixin:SetItemTemplate(template)
    self.config.template = template
    return self
end

function LoolibScrollableListBuilderMixin:SetItemHeight(height)
    self.config.height = height
    return self
end

function LoolibScrollableListBuilderMixin:SetDataProvider(provider)
    self.config.dataProvider = provider
    return self
end

function LoolibScrollableListBuilderMixin:SetInitializer(initializer)
    self.config.initializer = initializer
    return self
end

function LoolibScrollableListBuilderMixin:SetSelectionMode(mode)
    self.config.selectionMode = mode
    return self
end

function LoolibScrollableListBuilderMixin:OnSelectionChanged(callback)
    self.config.onSelectionChanged = callback
    return self
end

function LoolibScrollableListBuilderMixin:Build()
    local list = CreateLoolibScrollableList(self.parent)

    if self.config.template then
        list:SetItemTemplate(self.config.template)
    end
    if self.config.height then
        list:SetItemHeight(self.config.height)
    end
    if self.config.initializer then
        list:SetInitializer(self.config.initializer)
    end
    if self.config.selectionMode then
        list:SetSelectionMode(self.config.selectionMode)
    end
    if self.config.onSelectionChanged then
        list:RegisterCallback("OnSelectionChanged", self.config.onSelectionChanged)
    end
    if self.config.dataProvider then
        list:SetDataProvider(self.config.dataProvider)
    end

    return list
end

function LoolibScrollableList(parent)
    local builder = LoolibCreateFromMixins(LoolibScrollableListBuilderMixin)
    builder:Init(parent)
    return builder
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local ScrollableListModule = {
    Mixin = LoolibScrollableListMixin,
    BuilderMixin = LoolibScrollableListBuilderMixin,
    Create = CreateLoolibScrollableList,
    Builder = LoolibScrollableList,
}

local UI = Loolib:GetOrCreateModule("UI")
UI.ScrollableList = ScrollableListModule
UI.CreateScrollableList = CreateLoolibScrollableList

Loolib:RegisterModule("ScrollableList", ScrollableListModule)
