--[[--------------------------------------------------------------------
    Dump - Pretty-print function for debugging Lua values

    Provides a comprehensive dumping system for inspecting any Lua value,
    including support for recursive tables, circular reference detection,
    and depth limiting.
----------------------------------------------------------------------]]

LoolibDumpMixin = {}

-- Default maximum recursion depth
local DEFAULT_MAX_DEPTH = 5
local MAXIMUM_MAX_DEPTH = 10

--[[--------------------------------------------------------------------
    Type Detection Helpers
----------------------------------------------------------------------]]

--- Get a human-readable type name
-- @param value - The value to check
-- @return string - Type name
local function GetTypeName(value)
    return type(value)
end

--- Check if a value is a simple type (not table/function)
-- @param value - The value to check
-- @return boolean
local function IsSimpleType(value)
    local t = type(value)
    return t ~= "table" and t ~= "function"
end

--- Format a simple value for output
-- @param value - The value to format
-- @return string - Formatted representation
local function FormatSimpleValue(value)
    local t = type(value)

    if t == "string" then
        return string.format('"%s"', value)
    elseif t == "number" then
        if value == math.floor(value) then
            return tostring(value)
        else
            return string.format("%.2f", value)
        end
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "nil" then
        return "nil"
    else
        -- Function, thread, userdata, etc.
        return tostring(value)
    end
end

--- Sort table keys for consistent output
-- @param tbl table - The table to get keys from
-- @return table - Sorted keys
local function GetSortedKeys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end

    table.sort(keys, function(a, b)
        -- Sort by type first (strings first), then by value
        local typeA = type(a)
        local typeB = type(b)

        if typeA ~= typeB then
            return typeA < typeB
        end

        if typeA == "string" or typeA == "number" then
            return a < b
        end

        return false
    end)

    return keys
end

--[[--------------------------------------------------------------------
    Main Dump Implementation
----------------------------------------------------------------------]]

--- Recursively dump a value with circular reference detection
-- @param value - The value to dump
-- @param name string|nil - Optional name for the value
-- @param maxDepth number|nil - Maximum recursion depth
local function DumpValue(value, visited, depth, maxDepth)
    local t = type(value)

    -- Handle simple types
    if IsSimpleType(value) then
        return FormatSimpleValue(value)
    end

    -- Check depth limit
    if depth >= maxDepth then
        if t == "table" then
            return "{...}"
        elseif t == "function" then
            return tostring(value)
        end
    end

    -- Handle functions
    if t == "function" then
        return tostring(value)
    end

    -- Handle tables
    if t == "table" then
        -- Check for circular reference
        if visited[value] then
            return "[CIRCULAR]"
        end

        -- Mark as visited
        visited[value] = true

        -- Get sorted keys
        local keys = GetSortedKeys(value)

        -- Empty table
        if #keys == 0 then
            visited[value] = nil
            return "{}"
        end

        -- Build table representation
        local indent = string.rep("  ", depth)
        local nextIndent = string.rep("  ", depth + 1)
        local lines = { "{" }

        for _, key in ipairs(keys) do
            local keyStr
            if type(key) == "string" then
                keyStr = key
            else
                keyStr = string.format("[%s]", FormatSimpleValue(key))
            end

            local val = value[key]
            local valStr = DumpValue(val, visited, depth + 1, maxDepth)
            table.insert(lines, string.format("%s%s = %s,", nextIndent, keyStr, valStr))
        end

        table.insert(lines, indent .. "}")

        -- Unmark from visited
        visited[value] = nil

        return table.concat(lines, "\n")
    end

    -- Unknown type
    return tostring(value)
end

--[[--------------------------------------------------------------------
    Public Dump Function
----------------------------------------------------------------------]]

--- Dump a value to the default chat frame for debugging
-- @param value - Any Lua value to dump
-- @param name string|nil - Optional name to display
-- @param maxDepth number|nil - Maximum recursion depth (default 5, max 10)
function LoolibDumpMixin:Dump(value, name, maxDepth)
    -- Validate and normalize maxDepth
    if maxDepth == nil then
        maxDepth = DEFAULT_MAX_DEPTH
    elseif type(maxDepth) == "number" then
        maxDepth = math.min(math.max(maxDepth, 0), MAXIMUM_MAX_DEPTH)
    else
        maxDepth = DEFAULT_MAX_DEPTH
    end

    -- Generate output
    local visited = {}
    local valueStr = DumpValue(value, visited, 0, maxDepth)

    -- Format with name if provided
    local output
    if name then
        output = string.format("%s = %s", name, valueStr)
    else
        output = valueStr
    end

    -- Output to chat frame
    if DEFAULT_CHAT_FRAME then
        -- Split multi-line output and output each line
        for line in output:gmatch("[^\n]+") do
            DEFAULT_CHAT_FRAME:AddMessage(line)
        end
    else
        -- Fallback for when chat frame isn't available
        print(output)
    end
end

--[[--------------------------------------------------------------------
    Convenience Functions
----------------------------------------------------------------------]]

--- Quick dump with a single line limit (shows first 100 chars)
-- @param value - The value to dump
-- @param name string|nil - Optional name
function LoolibDumpMixin:DumpLine(value, name)
    local visited = {}
    local valueStr = DumpValue(value, visited, 0, 2)

    -- Truncate if too long
    if #valueStr > 100 then
        valueStr = valueStr:sub(1, 97) .. "..."
    end

    local output
    if name then
        output = string.format("%s = %s", name, valueStr)
    else
        output = valueStr
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(output)
    else
        print(output)
    end
end

--- Dump a table's keys (without values)
-- @param tbl table - The table to inspect
-- @param name string|nil - Optional name
function LoolibDumpMixin:DumpKeys(tbl, name)
    if type(tbl) ~= "table" then
        error("DumpKeys requires a table argument")
    end

    local keys = GetSortedKeys(tbl)
    local keyStrs = {}

    for _, k in ipairs(keys) do
        if type(k) == "string" then
            table.insert(keyStrs, k)
        else
            table.insert(keyStrs, tostring(k))
        end
    end

    local output = string.format("%s keys: {%s}", name or "Table", table.concat(keyStrs, ", "))

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(output)
    else
        print(output)
    end
end

--[[--------------------------------------------------------------------
    Module Registration
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
Loolib:RegisterModule("Dump", LoolibDumpMixin)
