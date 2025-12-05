--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Table utilities for common operations
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

LoolibTableUtil = {}

--[[--------------------------------------------------------------------
    Basic Operations
----------------------------------------------------------------------]]

--- Create a shallow copy of a table
-- @param tbl table - The table to copy
-- @return table - A new table with the same keys/values
function LoolibTableUtil.Copy(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end

    local copy = {}
    for key, value in pairs(tbl) do
        copy[key] = value
    end
    return copy
end

--- Create a deep copy of a table (recursive)
-- @param tbl table - The table to copy
-- @param seen table - Internal tracking for circular references
-- @return table - A new table with recursively copied values
function LoolibTableUtil.DeepCopy(tbl, seen)
    if type(tbl) ~= "table" then
        return tbl
    end

    seen = seen or {}
    if seen[tbl] then
        return seen[tbl]
    end

    local copy = {}
    seen[tbl] = copy

    for key, value in pairs(tbl) do
        copy[LoolibTableUtil.DeepCopy(key, seen)] = LoolibTableUtil.DeepCopy(value, seen)
    end

    return setmetatable(copy, getmetatable(tbl))
end

--- Merge one or more tables into the first table
-- @param target table - The target table to merge into
-- @param ... - One or more source tables
-- @return table - The modified target table
function LoolibTableUtil.Merge(target, ...)
    for i = 1, select("#", ...) do
        local source = select(i, ...)
        if source then
            for key, value in pairs(source) do
                target[key] = value
            end
        end
    end
    return target
end

--- Merge tables recursively (deep merge)
-- @param target table - The target table to merge into
-- @param source table - The source table
-- @return table - The modified target table
function LoolibTableUtil.DeepMerge(target, source)
    if type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            LoolibTableUtil.DeepMerge(target[key], value)
        else
            target[key] = value
        end
    end
    return target
end

--[[--------------------------------------------------------------------
    Array Operations
----------------------------------------------------------------------]]

--- Check if a table is an array (sequential integer keys starting at 1)
-- @param tbl table - The table to check
-- @return boolean
function LoolibTableUtil.IsArray(tbl)
    if type(tbl) ~= "table" then
        return false
    end

    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end

    return count == #tbl
end

--- Get the number of elements in a table (works for both arrays and maps)
-- @param tbl table - The table to count
-- @return number
function LoolibTableUtil.Count(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

--- Check if a table is empty
-- @param tbl table - The table to check
-- @return boolean
function LoolibTableUtil.IsEmpty(tbl)
    return next(tbl) == nil
end

--- Check if a value exists in a table
-- @param tbl table - The table to search
-- @param value any - The value to find
-- @return boolean
function LoolibTableUtil.Contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

--- Check if a key exists in a table
-- @param tbl table - The table to search
-- @param key any - The key to find
-- @return boolean
function LoolibTableUtil.ContainsKey(tbl, key)
    return tbl[key] ~= nil
end

--- Find the index of a value in an array
-- @param tbl table - The array to search
-- @param value any - The value to find
-- @return number|nil - The index, or nil if not found
function LoolibTableUtil.IndexOf(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return nil
end

--- Find the key of a value in a table
-- @param tbl table - The table to search
-- @param value any - The value to find
-- @return any|nil - The key, or nil if not found
function LoolibTableUtil.KeyOf(tbl, value)
    for k, v in pairs(tbl) do
        if v == value then
            return k
        end
    end
    return nil
end

--[[--------------------------------------------------------------------
    Functional Operations
----------------------------------------------------------------------]]

--- Filter a table based on a predicate function
-- @param tbl table - The table to filter
-- @param predicate function - Function(value, key) -> boolean
-- @return table - A new table with matching elements
function LoolibTableUtil.Filter(tbl, predicate)
    local result = {}

    if LoolibTableUtil.IsArray(tbl) then
        for i, v in ipairs(tbl) do
            if predicate(v, i) then
                result[#result + 1] = v
            end
        end
    else
        for k, v in pairs(tbl) do
            if predicate(v, k) then
                result[k] = v
            end
        end
    end

    return result
end

--- Map a table's values through a transform function
-- @param tbl table - The table to map
-- @param transform function - Function(value, key) -> newValue
-- @return table - A new table with transformed values
function LoolibTableUtil.Map(tbl, transform)
    local result = {}

    if LoolibTableUtil.IsArray(tbl) then
        for i, v in ipairs(tbl) do
            result[i] = transform(v, i)
        end
    else
        for k, v in pairs(tbl) do
            result[k] = transform(v, k)
        end
    end

    return result
end

--- Reduce a table to a single value
-- @param tbl table - The table to reduce
-- @param reducer function - Function(accumulator, value, key) -> newAccumulator
-- @param initial any - The initial accumulator value
-- @return any - The final accumulated value
function LoolibTableUtil.Reduce(tbl, reducer, initial)
    local accumulator = initial

    for k, v in pairs(tbl) do
        accumulator = reducer(accumulator, v, k)
    end

    return accumulator
end

--- Find the first element matching a predicate
-- @param tbl table - The table to search
-- @param predicate function - Function(value, key) -> boolean
-- @return any, any - The value and key, or nil if not found
function LoolibTableUtil.Find(tbl, predicate)
    for k, v in pairs(tbl) do
        if predicate(v, k) then
            return v, k
        end
    end
    return nil, nil
end

--- Check if all elements match a predicate
-- @param tbl table - The table to check
-- @param predicate function - Function(value, key) -> boolean
-- @return boolean
function LoolibTableUtil.Every(tbl, predicate)
    for k, v in pairs(tbl) do
        if not predicate(v, k) then
            return false
        end
    end
    return true
end

--- Check if any element matches a predicate
-- @param tbl table - The table to check
-- @param predicate function - Function(value, key) -> boolean
-- @return boolean
function LoolibTableUtil.Some(tbl, predicate)
    for k, v in pairs(tbl) do
        if predicate(v, k) then
            return true
        end
    end
    return false
end

--- Execute a function for each element
-- @param tbl table - The table to iterate
-- @param func function - Function(value, key)
function LoolibTableUtil.ForEach(tbl, func)
    for k, v in pairs(tbl) do
        func(v, k)
    end
end

--[[--------------------------------------------------------------------
    Key/Value Operations
----------------------------------------------------------------------]]

--- Get all keys from a table
-- @param tbl table - The table
-- @return table - An array of keys
function LoolibTableUtil.Keys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        keys[#keys + 1] = k
    end
    return keys
end

--- Get all values from a table
-- @param tbl table - The table
-- @return table - An array of values
function LoolibTableUtil.Values(tbl)
    local values = {}
    for _, v in pairs(tbl) do
        values[#values + 1] = v
    end
    return values
end

--- Invert a table (swap keys and values)
-- @param tbl table - The table to invert
-- @return table - A new table with keys and values swapped
function LoolibTableUtil.Invert(tbl)
    local inverted = {}
    for k, v in pairs(tbl) do
        inverted[v] = k
    end
    return inverted
end

--[[--------------------------------------------------------------------
    Array Manipulation
----------------------------------------------------------------------]]

--- Remove an element from an array by value
-- @param tbl table - The array to modify
-- @param value any - The value to remove
-- @return boolean - True if an element was removed
function LoolibTableUtil.RemoveByValue(tbl, value)
    local index = LoolibTableUtil.IndexOf(tbl, value)
    if index then
        table.remove(tbl, index)
        return true
    end
    return false
end

--- Insert elements from source into target at position
-- @param target table - The target array
-- @param position number - The position to insert at
-- @param source table - The source array to insert
-- @return table - The modified target array
function LoolibTableUtil.InsertRange(target, position, source)
    for i = #source, 1, -1 do
        table.insert(target, position, source[i])
    end
    return target
end

--- Append elements from source to target
-- @param target table - The target array
-- @param source table - The source array to append
-- @return table - The modified target array
function LoolibTableUtil.Append(target, source)
    for i = 1, #source do
        target[#target + 1] = source[i]
    end
    return target
end

--- Reverse an array
-- @param tbl table - The array to reverse
-- @return table - A new reversed array
function LoolibTableUtil.Reverse(tbl)
    local reversed = {}
    for i = #tbl, 1, -1 do
        reversed[#reversed + 1] = tbl[i]
    end
    return reversed
end

--- Create a slice of an array
-- @param tbl table - The source array
-- @param startIndex number - The start index (inclusive)
-- @param endIndex number - The end index (inclusive, optional)
-- @return table - A new array slice
function LoolibTableUtil.Slice(tbl, startIndex, endIndex)
    endIndex = endIndex or #tbl
    local slice = {}
    for i = startIndex, endIndex do
        slice[#slice + 1] = tbl[i]
    end
    return slice
end

--[[--------------------------------------------------------------------
    Comparison
----------------------------------------------------------------------]]

--- Compare two tables for shallow equality
-- @param a table - First table
-- @param b table - Second table
-- @return boolean
function LoolibTableUtil.Equals(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end

    for k, v in pairs(a) do
        if b[k] ~= v then
            return false
        end
    end

    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end

--- Compare two tables for deep equality
-- @param a table - First table
-- @param b table - Second table
-- @param seen table - Internal tracking for circular references
-- @return boolean
function LoolibTableUtil.DeepEquals(a, b, seen)
    if type(a) ~= "table" or type(b) ~= "table" then
        return a == b
    end

    seen = seen or {}
    if seen[a] then
        return seen[a] == b
    end
    seen[a] = b

    for k, v in pairs(a) do
        if not LoolibTableUtil.DeepEquals(v, b[k], seen) then
            return false
        end
    end

    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib:RegisterModule("TableUtil", LoolibTableUtil)
