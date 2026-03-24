--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    DataProvider - Collection management with event notifications

    Provides a data container that notifies listeners when data changes.
    Similar to Blizzard's DataProviderMixin but simplified for addon use.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Cache globals at file top
local error = error
local ipairs = ipairs
local max = math.max
local min = math.min
local select = select
local type = type
local sort = table.sort
local insert = table.insert
local remove = table.remove
local wipe = wipe

-- INTERNAL: Resolve a required Loolib module or throw
local function GetRequiredModule(name)
    local module = Loolib:GetModule(name)
    if not module then
        error("LoolibDataProvider: required module '" .. name .. "' not found", 2)
    end
    return module
end

local CallbackRegistryMixin = GetRequiredModule("CallbackRegistry").Mixin
-- Use Loolib.CreateFromMixins directly (module aliases can shift during load order)
local CreateFromMixins = assert(Loolib.CreateFromMixins, "LoolibDataProvider: Loolib.CreateFromMixins is required")

local Data = Loolib.Data or Loolib:GetOrCreateModule("Data")
Loolib.Data = Data

local DataProviderModule = Data.DataProvider or Loolib:GetModule("Data.DataProvider") or {}
Loolib.Data.DataProvider = DataProviderModule

--[[--------------------------------------------------------------------
    LoolibDataProviderMixin

    A mixin that manages a collection of data with change notifications.
----------------------------------------------------------------------]]

local DataProviderMixin = DataProviderModule.Mixin or CreateFromMixins(CallbackRegistryMixin)
Loolib.Data.DataProvider.Mixin = DataProviderMixin

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
-- @param initialData table|nil - Optional initial data array
function DataProviderMixin:Init(initialData)
    CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(DATA_PROVIDER_EVENTS)

    self.data = {}
    self.sortFunc = nil
    self.filterFunc = nil
    self.filteredData = nil
    self.pendingSort = false
    self.pendingFilter = false

    if initialData then
        if type(initialData) ~= "table" then
            error("LoolibDataProvider:Init: initialData must be a table", 2)
        end
        self:InsertTable(initialData)
    end
end

--[[--------------------------------------------------------------------
    Insertion
----------------------------------------------------------------------]]

--- Insert a single element
-- @param elementData any - The data to insert
-- @param insertIndex number|nil - Optional index to insert at
-- @return number - The index where the element was inserted
function DataProviderMixin:Insert(elementData, insertIndex)
    if insertIndex ~= nil and type(insertIndex) ~= "number" then
        error("LoolibDataProvider:Insert: insertIndex must be a number or nil", 2)
    end

    if insertIndex then
        insertIndex = max(1, min(insertIndex, #self.data + 1))
        insert(self.data, insertIndex, elementData)
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
function DataProviderMixin:Prepend(elementData)
    return self:Insert(elementData, 1)
end

--- Insert an element at the end
-- @param elementData any - The data to insert
function DataProviderMixin:Append(elementData)
    return self:Insert(elementData)
end

--- Insert multiple elements from a table
-- @param tbl table - Array of elements to insert
function DataProviderMixin:InsertTable(tbl)
    if type(tbl) ~= "table" then
        error("LoolibDataProvider:InsertTable: tbl must be a table", 2)
    end

    for _, elementData in ipairs(tbl) do
        self.data[#self.data + 1] = elementData
    end

    self:InvalidateFiltered()
    self:TriggerEvent("OnSizeChanged", #self.data)
end

--- Insert multiple elements
-- @param ... any - Elements to insert
function DataProviderMixin:InsertMany(...)
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
function DataProviderMixin:Remove(elementData)
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
function DataProviderMixin:RemoveIndex(index)
    if type(index) ~= "number" then
        error("LoolibDataProvider:RemoveIndex: index must be a number", 2)
    end
    if index < 1 or index > #self.data then
        return nil
    end

    local removed = remove(self.data, index)

    self:InvalidateFiltered()
    self:TriggerEvent("OnRemove", removed, index)
    self:TriggerEvent("OnSizeChanged", #self.data)

    return removed
end

--- Remove elements matching a predicate
-- @param predicate function - Function(elementData) returns true to remove
-- @return number - Number of elements removed
function DataProviderMixin:RemoveByPredicate(predicate)
    if type(predicate) ~= "function" then
        error("LoolibDataProvider:RemoveByPredicate: predicate must be a function", 2)
    end

    local removed = 0

    for i = #self.data, 1, -1 do
        if predicate(self.data[i]) then
            remove(self.data, i)
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
function DataProviderMixin:Flush()
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
function DataProviderMixin:Find(index)
    if type(index) ~= "number" then
        error("LoolibDataProvider:Find: index must be a number", 2)
    end
    if self.filterFunc and self.filteredData then
        return self.filteredData[index]
    end
    return self.data[index]
end

--- Get the index of an element
-- @param elementData any - The element to find
-- @return number|nil - The index or nil
function DataProviderMixin:FindIndex(elementData)
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
-- @return any, number|nil - Element and index, or nil
function DataProviderMixin:FindByPredicate(predicate)
    if type(predicate) ~= "function" then
        error("LoolibDataProvider:FindByPredicate: predicate must be a function", 2)
    end
    local dataToSearch = self.filteredData or self.data
    for i, data in ipairs(dataToSearch) do
        if predicate(data) then
            return data, i
        end
    end
    return nil, nil
end

--- Find all elements matching a predicate
-- @param predicate function - Function(elementData) returns true for match
-- @return table - Array of matching elements
function DataProviderMixin:FindAllByPredicate(predicate)
    if type(predicate) ~= "function" then
        error("LoolibDataProvider:FindAllByPredicate: predicate must be a function", 2)
    end
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
function DataProviderMixin:Contains(elementData)
    return self:FindIndex(elementData) ~= nil
end

--[[--------------------------------------------------------------------
    Size and Iteration
----------------------------------------------------------------------]]

--- Get the number of elements
-- @return number
function DataProviderMixin:GetSize()
    if self.filterFunc and self.filteredData then
        return #self.filteredData
    end
    return #self.data
end

--- Get the unfiltered size
-- @return number
function DataProviderMixin:GetUnfilteredSize()
    return #self.data
end

--- Check if the provider is empty
-- @return boolean
function DataProviderMixin:IsEmpty()
    return self:GetSize() == 0
end

--- Iterate over elements
-- @return iterator
function DataProviderMixin:Enumerate()
    local dataToIterate = self.filteredData or self.data
    return ipairs(dataToIterate)
end

--- Iterate over raw (unfiltered) elements
-- @return iterator
function DataProviderMixin:EnumerateUnfiltered()
    return ipairs(self.data)
end

--- Get elements in a range
-- @param startIndex number - Start index (inclusive)
-- @param endIndex number - End index (inclusive)
-- @return table - Array of elements in range
function DataProviderMixin:GetRange(startIndex, endIndex)
    if type(startIndex) ~= "number" then
        error("LoolibDataProvider:GetRange: startIndex must be a number", 2)
    end
    if type(endIndex) ~= "number" then
        error("LoolibDataProvider:GetRange: endIndex must be a number", 2)
    end

    local result = {}
    local dataToSearch = self.filteredData or self.data
    startIndex = max(1, startIndex)
    local maxIndex = min(endIndex, #dataToSearch)

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
function DataProviderMixin:SetSortComparator(sortFunc)
    if type(sortFunc) ~= "function" then
        error("LoolibDataProvider:SetSortComparator: sortFunc must be a function", 2)
    end
    self.sortFunc = sortFunc
    self.pendingSort = true
end

--- Clear the sort comparator
function DataProviderMixin:ClearSortComparator()
    self.sortFunc = nil
end

--- Sort the data
function DataProviderMixin:Sort()
    if self.sortFunc then
        sort(self.data, self.sortFunc)
        self:InvalidateFiltered()
        self.pendingSort = false
        self:TriggerEvent("OnSort")
    end
end

--- Check if sort is pending
-- @return boolean
function DataProviderMixin:IsSortPending()
    return self.pendingSort
end

--- Sort if pending
function DataProviderMixin:SortIfPending()
    if self.pendingSort then
        self:Sort()
    end
end

--[[--------------------------------------------------------------------
    Filtering
----------------------------------------------------------------------]]

--- Set the filter function
-- @param filterFunc function - Function(elementData) returns true to include
function DataProviderMixin:SetFilter(filterFunc)
    if type(filterFunc) ~= "function" then
        error("LoolibDataProvider:SetFilter: filterFunc must be a function", 2)
    end
    self.filterFunc = filterFunc
    self:InvalidateFiltered()
end

--- Clear the filter
function DataProviderMixin:ClearFilter()
    self.filterFunc = nil
    self.filteredData = nil
    self:TriggerEvent("OnSizeChanged", #self.data)
end

--- Invalidate the filtered cache -- INTERNAL
function DataProviderMixin:InvalidateFiltered()
    if self.filterFunc then
        self.filteredData = nil
        self.pendingFilter = true
    end
end

--- Apply the filter
function DataProviderMixin:ApplyFilter()
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
function DataProviderMixin:ApplyFilterIfPending()
    if self.pendingFilter then
        self:ApplyFilter()
    end
end

--- Ensure data is up to date (sorted and filtered)
function DataProviderMixin:EnsureUpToDate()
    self:SortIfPending()
    self:ApplyFilterIfPending()
end

--[[--------------------------------------------------------------------
    Updates
----------------------------------------------------------------------]]

--- Update an element and trigger notification
-- @param elementData any - The element that was updated
function DataProviderMixin:UpdateElement(elementData)
    local index = self:FindIndex(elementData)
    if index then
        self:TriggerEvent("OnUpdate", elementData, index)
    end
end

--- Update an element at a specific index
-- @param index number - The index to update
-- @param newData any - The new data (or nil to keep existing and just trigger update)
function DataProviderMixin:UpdateIndex(index, newData)
    if type(index) ~= "number" then
        error("LoolibDataProvider:UpdateIndex: index must be a number", 2)
    end
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
function DataProviderMixin:ReplaceAll(newData)
    if type(newData) ~= "table" then
        error("LoolibDataProvider:ReplaceAll: newData must be a table", 2)
    end
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
function DataProviderMixin:Map(mapFunc)
    if type(mapFunc) ~= "function" then
        error("LoolibDataProvider:Map: mapFunc must be a function", 2)
    end
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
function DataProviderMixin:Reduce(reduceFunc, initialValue)
    if type(reduceFunc) ~= "function" then
        error("LoolibDataProvider:Reduce: reduceFunc must be a function", 2)
    end
    local result = initialValue
    local dataToReduce = self.filteredData or self.data
    for i, data in ipairs(dataToReduce) do
        result = reduceFunc(result, data, i)
    end
    return result
end

--- Get raw data (be careful modifying this directly)
-- @return table - The underlying data array
function DataProviderMixin:GetRawData()
    return self.data
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new data provider
-- @param initialData table|nil - Optional initial data
-- @return table - A new DataProvider instance
local function CreateDataProvider(initialData)
    if initialData ~= nil and type(initialData) ~= "table" then
        error("LoolibDataProvider.Create: initialData must be a table or nil", 2)
    end
    local provider = CreateFromMixins(DataProviderMixin)
    provider:Init(initialData)
    return provider
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib.Data.DataProvider.Mixin = DataProviderMixin
Loolib.Data.DataProvider.Create = CreateDataProvider
Loolib.Data.DataProvider = DataProviderModule
Loolib.Data.CreateDataProvider = CreateDataProvider

Loolib:RegisterModule("Data.DataProvider", DataProviderModule)
