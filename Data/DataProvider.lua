--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    DataProvider - Collection management with event notifications

    Provides a data container that notifies listeners when data changes.
    Similar to Blizzard's DataProviderMixin but simplified for addon use.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibDataProviderMixin

    A mixin that manages a collection of data with change notifications.
----------------------------------------------------------------------]]

LoolibDataProviderMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

-- Define callback events
local DATA_PROVIDER_EVENTS = {
    "OnSizeChanged",
    "OnInsert",
    "OnRemove",
    "OnUpdate",
    "OnSort",
    "OnFlush",
}

--- Initialize the data provider
-- @param initialData table - Optional initial data array
function LoolibDataProviderMixin:Init(initialData)
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(DATA_PROVIDER_EVENTS)

    self.data = {}
    self.sortFunc = nil
    self.filterFunc = nil
    self.filteredData = nil
    self.pendingSort = false
    self.pendingFilter = false

    if initialData then
        self:InsertTable(initialData)
    end
end

--[[--------------------------------------------------------------------
    Insertion
----------------------------------------------------------------------]]

--- Insert a single element
-- @param elementData any - The data to insert
-- @param insertIndex number - Optional index to insert at
-- @return number - The index where the element was inserted
function LoolibDataProviderMixin:Insert(elementData, insertIndex)
    if insertIndex then
        insertIndex = math.max(1, math.min(insertIndex, #self.data + 1))
        table.insert(self.data, insertIndex, elementData)
    else
        insertIndex = #self.data + 1
        self.data[insertIndex] = elementData
    end

    self:InvalidateFiltered()
    self:TriggerEvent("OnInsert", elementData, insertIndex)
    self:TriggerEvent("OnSizeChanged", #self.data)

    return insertIndex
end

--- Insert an element at the beginning
-- @param elementData any - The data to insert
function LoolibDataProviderMixin:Prepend(elementData)
    return self:Insert(elementData, 1)
end

--- Insert an element at the end
-- @param elementData any - The data to insert
function LoolibDataProviderMixin:Append(elementData)
    return self:Insert(elementData)
end

--- Insert multiple elements from a table
-- @param tbl table - Array of elements to insert
function LoolibDataProviderMixin:InsertTable(tbl)
    for _, elementData in ipairs(tbl) do
        self.data[#self.data + 1] = elementData
    end

    self:InvalidateFiltered()
    self:TriggerEvent("OnSizeChanged", #self.data)
end

--- Insert multiple elements
-- @param ... any - Elements to insert
function LoolibDataProviderMixin:InsertMany(...)
    for i = 1, select("#", ...) do
        self.data[#self.data + 1] = select(i, ...)
    end

    self:InvalidateFiltered()
    self:TriggerEvent("OnSizeChanged", #self.data)
end

--[[--------------------------------------------------------------------
    Removal
----------------------------------------------------------------------]]

--- Remove an element by value
-- @param elementData any - The element to remove
-- @return boolean - True if removed
function LoolibDataProviderMixin:Remove(elementData)
    for i, data in ipairs(self.data) do
        if data == elementData then
            return self:RemoveIndex(i) ~= nil
        end
    end
    return false
end

--- Remove an element by index
-- @param index number - The index to remove
-- @return any - The removed element or nil
function LoolibDataProviderMixin:RemoveIndex(index)
    if index < 1 or index > #self.data then
        return nil
    end

    local removed = table.remove(self.data, index)

    self:InvalidateFiltered()
    self:TriggerEvent("OnRemove", removed, index)
    self:TriggerEvent("OnSizeChanged", #self.data)

    return removed
end

--- Remove elements matching a predicate
-- @param predicate function - Function(elementData) returns true to remove
-- @return number - Number of elements removed
function LoolibDataProviderMixin:RemoveByPredicate(predicate)
    local removed = 0

    for i = #self.data, 1, -1 do
        if predicate(self.data[i]) then
            table.remove(self.data, i)
            removed = removed + 1
        end
    end

    if removed > 0 then
        self:InvalidateFiltered()
        self:TriggerEvent("OnSizeChanged", #self.data)
    end

    return removed
end

--- Remove all elements
function LoolibDataProviderMixin:Flush()
    local hadData = #self.data > 0
    wipe(self.data)
    self:InvalidateFiltered()

    if hadData then
        self:TriggerEvent("OnFlush")
        self:TriggerEvent("OnSizeChanged", 0)
    end
end

--[[--------------------------------------------------------------------
    Retrieval
----------------------------------------------------------------------]]

--- Get an element by index
-- @param index number - The index
-- @return any - The element or nil
function LoolibDataProviderMixin:Find(index)
    if self.filterFunc and self.filteredData then
        return self.filteredData[index]
    end
    return self.data[index]
end

--- Get the index of an element
-- @param elementData any - The element to find
-- @return number|nil - The index or nil
function LoolibDataProviderMixin:FindIndex(elementData)
    local dataToSearch = self.filteredData or self.data
    for i, data in ipairs(dataToSearch) do
        if data == elementData then
            return i
        end
    end
    return nil
end

--- Find an element by predicate
-- @param predicate function - Function(elementData) returns true for match
-- @return any, number - Element and index, or nil
function LoolibDataProviderMixin:FindByPredicate(predicate)
    local dataToSearch = self.filteredData or self.data
    for i, data in ipairs(dataToSearch) do
        if predicate(data) then
            return data, i
        end
    end
    return nil
end

--- Find all elements matching a predicate
-- @param predicate function - Function(elementData) returns true for match
-- @return table - Array of matching elements
function LoolibDataProviderMixin:FindAllByPredicate(predicate)
    local results = {}
    local dataToSearch = self.filteredData or self.data
    for _, data in ipairs(dataToSearch) do
        if predicate(data) then
            results[#results + 1] = data
        end
    end
    return results
end

--- Check if an element exists
-- @param elementData any - The element to check
-- @return boolean
function LoolibDataProviderMixin:Contains(elementData)
    return self:FindIndex(elementData) ~= nil
end

--[[--------------------------------------------------------------------
    Size and Iteration
----------------------------------------------------------------------]]

--- Get the number of elements
-- @return number
function LoolibDataProviderMixin:GetSize()
    if self.filterFunc and self.filteredData then
        return #self.filteredData
    end
    return #self.data
end

--- Get the unfiltered size
-- @return number
function LoolibDataProviderMixin:GetUnfilteredSize()
    return #self.data
end

--- Check if the provider is empty
-- @return boolean
function LoolibDataProviderMixin:IsEmpty()
    return self:GetSize() == 0
end

--- Iterate over elements
-- @return iterator
function LoolibDataProviderMixin:Enumerate()
    local dataToIterate = self.filteredData or self.data
    return ipairs(dataToIterate)
end

--- Iterate over raw (unfiltered) elements
-- @return iterator
function LoolibDataProviderMixin:EnumerateUnfiltered()
    return ipairs(self.data)
end

--- Get elements in a range
-- @param startIndex number - Start index (inclusive)
-- @param endIndex number - End index (inclusive)
-- @return table - Array of elements in range
function LoolibDataProviderMixin:GetRange(startIndex, endIndex)
    local result = {}
    local dataToSearch = self.filteredData or self.data
    local maxIndex = math.min(endIndex, #dataToSearch)

    for i = startIndex, maxIndex do
        result[#result + 1] = dataToSearch[i]
    end

    return result
end

--[[--------------------------------------------------------------------
    Sorting
----------------------------------------------------------------------]]

--- Set the sort comparator
-- @param sortFunc function - Comparison function(a, b) returns true if a < b
function LoolibDataProviderMixin:SetSortComparator(sortFunc)
    self.sortFunc = sortFunc
    self.pendingSort = true
end

--- Clear the sort comparator
function LoolibDataProviderMixin:ClearSortComparator()
    self.sortFunc = nil
end

--- Sort the data
function LoolibDataProviderMixin:Sort()
    if self.sortFunc then
        table.sort(self.data, self.sortFunc)
        self:InvalidateFiltered()
        self.pendingSort = false
        self:TriggerEvent("OnSort")
    end
end

--- Check if sort is pending
-- @return boolean
function LoolibDataProviderMixin:IsSortPending()
    return self.pendingSort
end

--- Sort if pending
function LoolibDataProviderMixin:SortIfPending()
    if self.pendingSort then
        self:Sort()
    end
end

--[[--------------------------------------------------------------------
    Filtering
----------------------------------------------------------------------]]

--- Set the filter function
-- @param filterFunc function - Function(elementData) returns true to include
function LoolibDataProviderMixin:SetFilter(filterFunc)
    self.filterFunc = filterFunc
    self:InvalidateFiltered()
end

--- Clear the filter
function LoolibDataProviderMixin:ClearFilter()
    self.filterFunc = nil
    self.filteredData = nil
    self:TriggerEvent("OnSizeChanged", #self.data)
end

--- Invalidate the filtered cache
function LoolibDataProviderMixin:InvalidateFiltered()
    if self.filterFunc then
        self.filteredData = nil
        self.pendingFilter = true
    end
end

--- Apply the filter
function LoolibDataProviderMixin:ApplyFilter()
    if not self.filterFunc then
        self.filteredData = nil
        return
    end

    self.filteredData = {}
    for _, data in ipairs(self.data) do
        if self.filterFunc(data) then
            self.filteredData[#self.filteredData + 1] = data
        end
    end

    self.pendingFilter = false
    self:TriggerEvent("OnSizeChanged", #self.filteredData)
end

--- Apply filter if pending
function LoolibDataProviderMixin:ApplyFilterIfPending()
    if self.pendingFilter then
        self:ApplyFilter()
    end
end

--- Ensure data is up to date (sorted and filtered)
function LoolibDataProviderMixin:EnsureUpToDate()
    self:SortIfPending()
    self:ApplyFilterIfPending()
end

--[[--------------------------------------------------------------------
    Updates
----------------------------------------------------------------------]]

--- Update an element and trigger notification
-- @param elementData any - The element that was updated
function LoolibDataProviderMixin:UpdateElement(elementData)
    local index = self:FindIndex(elementData)
    if index then
        self:TriggerEvent("OnUpdate", elementData, index)
    end
end

--- Update an element at a specific index
-- @param index number - The index to update
-- @param newData any - The new data (or nil to keep existing and just trigger update)
function LoolibDataProviderMixin:UpdateIndex(index, newData)
    if index >= 1 and index <= #self.data then
        if newData ~= nil then
            self.data[index] = newData
            self:InvalidateFiltered()
        end
        self:TriggerEvent("OnUpdate", self.data[index], index)
    end
end

--- Replace all data
-- @param newData table - New data array
function LoolibDataProviderMixin:ReplaceAll(newData)
    wipe(self.data)
    for _, elementData in ipairs(newData) do
        self.data[#self.data + 1] = elementData
    end
    self:InvalidateFiltered()
    self:TriggerEvent("OnFlush")
    self:TriggerEvent("OnSizeChanged", #self.data)
end

--[[--------------------------------------------------------------------
    Transformation
----------------------------------------------------------------------]]

--- Map elements to a new array
-- @param mapFunc function - Function(elementData, index) returns new value
-- @return table - Array of mapped values
function LoolibDataProviderMixin:Map(mapFunc)
    local result = {}
    local dataToMap = self.filteredData or self.data
    for i, data in ipairs(dataToMap) do
        result[i] = mapFunc(data, i)
    end
    return result
end

--- Reduce elements to a single value
-- @param reduceFunc function - Function(accumulator, elementData, index)
-- @param initialValue any - Initial accumulator value
-- @return any - Final accumulated value
function LoolibDataProviderMixin:Reduce(reduceFunc, initialValue)
    local result = initialValue
    local dataToReduce = self.filteredData or self.data
    for i, data in ipairs(dataToReduce) do
        result = reduceFunc(result, data, i)
    end
    return result
end

--- Get raw data (be careful modifying this directly)
-- @return table - The underlying data array
function LoolibDataProviderMixin:GetRawData()
    return self.data
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new data provider
-- @param initialData table - Optional initial data
-- @return table - A new DataProvider instance
function CreateLoolibDataProvider(initialData)
    local provider = LoolibCreateFromMixins(LoolibDataProviderMixin)
    provider:Init(initialData)
    return provider
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local DataProviderModule = {
    Mixin = LoolibDataProviderMixin,
    Create = CreateLoolibDataProvider,
}

-- Register in Data module
local Data = Loolib:GetOrCreateModule("Data")
Data.DataProvider = DataProviderModule
Data.CreateDataProvider = CreateLoolibDataProvider

Loolib:RegisterModule("DataProvider", DataProviderModule)
