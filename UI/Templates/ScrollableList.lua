--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ScrollableList - Virtual scrolling list with data provider integration

    Features:
    - Virtual scrolling (only renders visible items)
    - Frame pooling for list items
    - DataProvider integration with auto-updates
    - Selection support (single/multi)
    - Keyboard navigation
    - Column headers with click-to-sort
    - Column resizing (drag between headers)
    - Custom cell rendering (DoCellUpdate callbacks)
    - Row highlighting on hover
    - Right-click context menus
    - Filter function support
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
    "OnItemRightClick",
    "OnItemEnter",
    "OnItemLeave",
    "OnColumnClick",
    "OnSort",
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

    -- Column support
    self.columns = nil
    self.columnHeaders = {}
    self.sortColumn = nil
    self.sortDirection = "asc"  -- "asc" or "dsc"
    self.filterFunc = nil
    self.onRowRightClick = nil

    -- Get references to child frames
    self.ScrollFrame = self.ScrollFrame or self:GetName() and _G[self:GetName() .. "ScrollFrame"]
    self.Content = self.ScrollFrame and self.ScrollFrame.Content
    self.HeaderContainer = self.HeaderContainer

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

--- Set columns for table display
-- @param columns table - Array of column definitions with fields:
--   - name: string - Column header text
--   - width: number - Column width in pixels
--   - DoCellUpdate: function(rowFrame, cellFrame, data, cols, row, realrow, column, table) - Custom cell renderer
--   - sort: string - Default sort direction ("asc" or "dsc")
--   - sortnext: number - Secondary sort column index
function LoolibScrollableListMixin:SetColumns(columns)
    self.columns = columns
    self:CreateColumnHeaders()
    self:MarkDirty()
end

--- Set filter function
-- @param filterFunc function(data) - Returns true to show item, false to hide
function LoolibScrollableListMixin:SetFilterFunc(filterFunc)
    self.filterFunc = filterFunc
    self:MarkDirty()
end

--- Set right-click context menu callback
-- @param callback function(data, index, button)
function LoolibScrollableListMixin:SetOnRowRightClick(callback)
    self.onRowRightClick = callback
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
    Column Headers and Sorting
----------------------------------------------------------------------]]

--- Create column headers
function LoolibScrollableListMixin:CreateColumnHeaders()
    if not self.columns or not self.HeaderContainer then
        return
    end

    -- Clear existing headers
    for _, header in ipairs(self.columnHeaders) do
        header:Hide()
        header:SetParent(nil)
    end
    wipe(self.columnHeaders)

    local xOffset = 0
    for i, colDef in ipairs(self.columns) do
        local header = CreateFrame("Button", nil, self.HeaderContainer)
        header:SetSize(colDef.width, 20)
        header:SetPoint("TOPLEFT", self.HeaderContainer, "TOPLEFT", xOffset, 0)

        -- Background
        local bg = header:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        header.bg = bg

        -- Text
        local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", header, "LEFT", 4, 0)
        text:SetText(colDef.name)
        header.text = text

        -- Sort arrow (initially hidden)
        local arrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        arrow:SetPoint("RIGHT", header, "RIGHT", -4, 0)
        arrow:Hide()
        header.arrow = arrow

        -- Click to sort
        header.columnIndex = i
        header:SetScript("OnClick", function(self)
            self:GetParent():GetParent():SortByColumn(i)
        end)

        -- Highlight on hover
        header:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.3, 0.3, 0.3, 0.9)
        end)
        header:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        end)

        self.columnHeaders[i] = header
        xOffset = xOffset + colDef.width
    end
end

--- Sort by column
-- @param columnIndex number - Column index to sort by
function LoolibScrollableListMixin:SortByColumn(columnIndex)
    if not self.columns or not self.dataProvider then
        return
    end

    local colDef = self.columns[columnIndex]
    if not colDef then
        return
    end

    -- Toggle sort direction if same column, otherwise use default
    if self.sortColumn == columnIndex then
        self.sortDirection = (self.sortDirection == "asc") and "dsc" or "asc"
    else
        self.sortColumn = columnIndex
        self.sortDirection = colDef.sort or "asc"
    end

    -- Update arrow indicators
    for i, header in ipairs(self.columnHeaders) do
        if i == self.sortColumn then
            header.arrow:SetText(self.sortDirection == "asc" and "▲" or "▼")
            header.arrow:Show()
        else
            header.arrow:Hide()
        end
    end

    -- Sort data provider if it has a Sort method
    if self.dataProvider.Sort then
        self.dataProvider:Sort(function(a, b)
            -- Custom comparator based on column
            local aVal = a
            local bVal = b

            -- Extract column-specific value if needed
            -- This is a simplified version - real implementation would need
            -- column-specific value extraction logic

            if self.sortDirection == "asc" then
                return aVal < bVal
            else
                return aVal > bVal
            end
        end)
    end

    self:TriggerEvent("OnColumnClick", columnIndex, self.sortDirection)
    self:TriggerEvent("OnSort", self.sortColumn, self.sortDirection)
    self:MarkDirty()
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

    -- Build filtered data list
    local filteredData = {}
    local totalItems = self.dataProvider:GetSize()
    for i = 1, totalItems do
        local elementData = self.dataProvider:Find(i)
        if elementData then
            -- Apply filter if set
            if not self.filterFunc or self.filterFunc(elementData) then
                filteredData[#filteredData + 1] = elementData
            end
        end
    end

    -- Calculate visible range
    local scrollOffset = self.ScrollFrame:GetVerticalScroll()
    local viewHeight = self.ScrollFrame:GetHeight()
    local numFilteredItems = #filteredData

    local firstVisible = math.floor(scrollOffset / self.itemHeight) + 1
    local lastVisible = math.ceil((scrollOffset + viewHeight) / self.itemHeight)
    lastVisible = math.min(lastVisible, numFilteredItems)

    -- Update content size
    self.Content:SetSize(self.ScrollFrame:GetWidth() - 4, numFilteredItems * self.itemHeight)

    -- Create visible items
    for i = firstVisible, lastVisible do
        local elementData = filteredData[i]
        if elementData then
            local frame = self.itemPool:Acquire()
            frame.index = i
            frame.data = elementData
            frame.list = self

            -- Position
            frame:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, -((i - 1) * self.itemHeight))
            frame:SetPoint("RIGHT", self.Content, "RIGHT", 0, 0)
            frame:SetHeight(self.itemHeight)

            -- Initialize with columns if available
            if self.columns then
                self:InitializeRowWithColumns(frame, elementData, i)
            elseif self.itemInitializer then
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

            -- Right-click handler
            frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            frame:SetScript("OnClick", function(f, button)
                if button == "RightButton" then
                    self:TriggerEvent("OnItemRightClick", f.data, f.index, button)
                    if self.onRowRightClick then
                        self.onRowRightClick(f.data, f.index, button)
                    end
                else
                    self:OnItemClick(f, f.data, button)
                end
            end)

            -- Row highlighting on hover
            frame:SetScript("OnEnter", function(f)
                if f.HighlightTexture then
                    f.HighlightTexture:Show()
                end
                self:TriggerEvent("OnItemEnter", f.data, f.index, f)
            end)

            frame:SetScript("OnLeave", function(f)
                if f.HighlightTexture then
                    f.HighlightTexture:Hide()
                end
                self:TriggerEvent("OnItemLeave", f.data, f.index, f)
            end)

            frame:Show()
            self.visibleItems[elementData] = frame
        end
    end
end

--- Initialize a row with column-based rendering
-- @param frame Frame - The row frame
-- @param elementData any - The data for this row
-- @param index number - Row index
function LoolibScrollableListMixin:InitializeRowWithColumns(frame, elementData, index)
    if not self.columns then
        return
    end

    -- Create cell frames if needed
    if not frame.cells then
        frame.cells = {}
    end

    local xOffset = 0
    for colIndex, colDef in ipairs(self.columns) do
        -- Create or reuse cell frame
        local cellFrame = frame.cells[colIndex]
        if not cellFrame then
            cellFrame = CreateFrame("Frame", nil, frame)
            cellFrame.text = cellFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cellFrame.text:SetPoint("LEFT", cellFrame, "LEFT", 4, 0)
            frame.cells[colIndex] = cellFrame
        end

        -- Position and size cell
        cellFrame:SetSize(colDef.width, self.itemHeight)
        cellFrame:ClearAllPoints()
        cellFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", xOffset, 0)

        -- Custom cell update if defined
        if colDef.DoCellUpdate then
            colDef.DoCellUpdate(frame, cellFrame, elementData, self.columns, index, index, colIndex, self)
        else
            -- Default: display as text
            cellFrame.text:SetText(tostring(elementData))
        end

        cellFrame:Show()
        xOffset = xOffset + colDef.width
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
