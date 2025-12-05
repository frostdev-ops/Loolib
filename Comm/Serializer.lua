--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Serializer - Lua value serialization/deserialization

    Provides AceSerializer-compatible protocol for converting Lua values
    to strings and back. Supports tables, strings, numbers, booleans, nil.

    Protocol Format:
    - Version header: ^1
    - Type tags: ^S (string), ^N (number), ^F^f (float), ^T^t (table),
                 ^B^b (bool true/false), ^Z (nil)
    - Control characters (\001-\004) and ^ are escaped
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Constants and Protocol Definition
----------------------------------------------------------------------]]

LoolibSerializerMixin = {}

-- Protocol version
local PROTOCOL_VERSION = "1"

-- Type tags (prefix with ^)
local TAG_STRING = "S"
local TAG_NUMBER = "N"
local TAG_FLOAT = "F"
local TAG_FLOAT_END = "f"
local TAG_TABLE_START = "T"
local TAG_TABLE_END = "t"
local TAG_BOOL_TRUE = "B"
local TAG_BOOL_FALSE = "b"
local TAG_NIL = "Z"
local TAG_INF = "I"
local TAG_NINF = "i"

-- Serialization marker
local MARKER = "^"

-- Pattern for control characters that need escaping
local CONTROL_CHARS = "[\001-\004%^]"

-- Escape mapping
local ESCAPE_MAP = {
    ["\001"] = "\001\001",  -- \001 -> \001\001
    ["\002"] = "\001\002",  -- \002 -> \001\002
    ["\003"] = "\001\003",  -- \003 -> \001\003
    ["\004"] = "\001\004",  -- \004 -> \001\004
    ["^"] = "\001\005",     -- ^ -> \001\005
}

-- Unescape mapping (reverse)
local UNESCAPE_MAP = {
    ["\001"] = "\001",
    ["\002"] = "\002",
    ["\003"] = "\003",
    ["\004"] = "\004",
    ["\005"] = "^",
}

-- Byte constants for zero-garbage parsing
local MARKER_BYTE = string.byte("^")  -- 94
local ESCAPE_BYTE = 1  -- \001

-- Tag bytes for comparison (avoids string creation)
local TAG_STRING_BYTE = string.byte("S")
local TAG_NUMBER_BYTE = string.byte("N")
local TAG_FLOAT_BYTE = string.byte("F")
local TAG_FLOAT_END_BYTE = string.byte("f")
local TAG_TABLE_START_BYTE = string.byte("T")
local TAG_TABLE_END_BYTE = string.byte("t")
local TAG_BOOL_TRUE_BYTE = string.byte("B")
local TAG_BOOL_FALSE_BYTE = string.byte("b")
local TAG_NIL_BYTE = string.byte("Z")
local TAG_INF_BYTE = string.byte("I")
local TAG_NINF_BYTE = string.byte("i")

-- Byte-based unescape lookup (indexed by second byte after \001)
local UNESCAPE_BYTES = {
    [1] = 1,     -- \001\001 -> \001
    [2] = 2,     -- \001\002 -> \002
    [3] = 3,     -- \001\003 -> \003
    [4] = 4,     -- \001\004 -> \004
    [5] = 94,    -- \001\005 -> ^
}

--[[--------------------------------------------------------------------
    Escaping Functions
----------------------------------------------------------------------]]

local function EscapeString(str)
    return str:gsub(CONTROL_CHARS, ESCAPE_MAP)
end

local function UnescapeString(str)
    -- Replace \001X sequences with their unescaped values
    return str:gsub("\001(.)", function(c)
        return UNESCAPE_MAP[c] or c
    end)
end

--[[--------------------------------------------------------------------
    Serialization Implementation
----------------------------------------------------------------------]]

-- Forward declaration for recursive serialization
local SerializeValue

-- Track tables being serialized to detect circular references
local serializingTables = {}

-- Append string directly to output table (avoids intermediate concatenation)
local function SerializeString(value, output)
    local n = #output
    output[n + 1] = MARKER
    output[n + 2] = TAG_STRING
    output[n + 3] = EscapeString(value)
end

-- Append number directly to output table
local function SerializeNumber(value, output)
    local n = #output
    
    -- Handle special cases
    if value == math.huge then
        output[n + 1] = MARKER
        output[n + 2] = TAG_INF
        return
    elseif value == -math.huge then
        output[n + 1] = MARKER
        output[n + 2] = TAG_NINF
        return
    end

    -- Check if it's an integer
    local intPart = math.floor(value)
    if value == intPart and value >= -2147483648 and value <= 2147483647 then
        output[n + 1] = MARKER
        output[n + 2] = TAG_NUMBER
        output[n + 3] = tostring(intPart)
        return
    end

    -- Float: use format that preserves precision
    -- Format: ^F<value>^f
    output[n + 1] = MARKER
    output[n + 2] = TAG_FLOAT
    output[n + 3] = string.format("%.17g", value)
    output[n + 4] = MARKER
    output[n + 5] = TAG_FLOAT_END
end

-- Append boolean directly to output table
local function SerializeBoolean(value, output)
    local n = #output
    output[n + 1] = MARKER
    output[n + 2] = value and TAG_BOOL_TRUE or TAG_BOOL_FALSE
end

-- Append nil marker directly to output table
local function SerializeNil(output)
    local n = #output
    output[n + 1] = MARKER
    output[n + 2] = TAG_NIL
end

local function SerializeTable(tbl, output)
    -- Check for circular reference
    if serializingTables[tbl] then
        error("Circular reference detected in table serialization", 3)
    end

    serializingTables[tbl] = true
    local n = #output
    output[n + 1] = MARKER
    output[n + 2] = TAG_TABLE_START

    -- Serialize key-value pairs
    for key, val in pairs(tbl) do
        SerializeValue(key, output)
        SerializeValue(val, output)
    end

    n = #output
    output[n + 1] = MARKER
    output[n + 2] = TAG_TABLE_END
    serializingTables[tbl] = nil
end

function SerializeValue(value, output)
    local valueType = type(value)

    if valueType == "string" then
        SerializeString(value, output)
    elseif valueType == "number" then
        SerializeNumber(value, output)
    elseif valueType == "boolean" then
        SerializeBoolean(value, output)
    elseif valueType == "nil" then
        SerializeNil(output)
    elseif valueType == "table" then
        SerializeTable(value, output)
    else
        error(string.format("Cannot serialize type '%s'", valueType), 3)
    end
end

--[[--------------------------------------------------------------------
    Deserialization Implementation
----------------------------------------------------------------------]]

-- Parser state
local parseStr
local parsePos
local parseLen

-- Read and consume a byte (returns number, zero garbage)
local function ParseByte()
    if parsePos > parseLen then
        return nil
    end
    local b = parseStr:byte(parsePos)
    parsePos = parsePos + 1
    return b
end

-- Peek at current byte without consuming (returns number, zero garbage)
local function PeekByte()
    if parsePos > parseLen then
        return nil
    end
    return parseStr:byte(parsePos)
end

-- Read until next ^ marker or end, handling escape sequences
-- Returns string (only creates one string at the end)
local function ReadUntilMarker()
    local result = {}
    local resultLen = 0

    while parsePos <= parseLen do
        local b = parseStr:byte(parsePos)
        if b == MARKER_BYTE then
            break
        elseif b == ESCAPE_BYTE then
            -- Escape sequence: \001X
            parsePos = parsePos + 1
            if parsePos <= parseLen then
                local escapedByte = parseStr:byte(parsePos)
                local unescaped = UNESCAPE_BYTES[escapedByte]
                resultLen = resultLen + 1
                result[resultLen] = unescaped or escapedByte
                parsePos = parsePos + 1
            end
        else
            resultLen = resultLen + 1
            result[resultLen] = b
            parsePos = parsePos + 1
        end
    end

    -- Convert accumulated bytes to string (single allocation)
    if resultLen == 0 then
        return ""
    end
    return string.char(unpack(result, 1, resultLen))
end

-- Forward declaration
local ParseValue

local function ParseString()
    return ReadUntilMarker()
end

local function ParseNumber()
    local numStr = ReadUntilMarker()
    return tonumber(numStr)
end

local function ParseFloat()
    local numStr = ReadUntilMarker()
    -- Expect closing ^f
    local marker = ParseByte()
    local tag = ParseByte()
    if marker ~= MARKER_BYTE or tag ~= TAG_FLOAT_END_BYTE then
        return nil, "Invalid float format"
    end
    return tonumber(numStr)
end

local function ParseTable()
    local tbl = {}

    while true do
        local marker = PeekByte()
        if not marker then
            return nil, "Unexpected end of input in table"
        end

        if marker ~= MARKER_BYTE then
            return nil, "Expected marker in table"
        end

        parsePos = parsePos + 1
        local tag = PeekByte()

        if tag == TAG_TABLE_END_BYTE then
            parsePos = parsePos + 1
            return tbl
        end

        -- Not end of table, so the marker we consumed belongs to the key.
        -- Step back so ParseValue can consume it correctly.
        parsePos = parsePos - 1

        -- Parse key
        local key, err = ParseValue()
        if err then
            return nil, err
        end

        -- Parse value
        local val
        val, err = ParseValue()
        if err then
            return nil, err
        end

        tbl[key] = val
    end
end

function ParseValue()
    local marker = ParseByte()
    if marker ~= MARKER_BYTE then
        return nil, "Expected marker"
    end

    local tag = ParseByte()
    if not tag then
        return nil, "Unexpected end of input"
    end

    if tag == TAG_STRING_BYTE then
        return ParseString()
    elseif tag == TAG_NUMBER_BYTE then
        return ParseNumber()
    elseif tag == TAG_FLOAT_BYTE then
        return ParseFloat()
    elseif tag == TAG_TABLE_START_BYTE then
        return ParseTable()
    elseif tag == TAG_BOOL_TRUE_BYTE then
        return true
    elseif tag == TAG_BOOL_FALSE_BYTE then
        return false
    elseif tag == TAG_NIL_BYTE then
        return nil
    elseif tag == TAG_INF_BYTE then
        return math.huge
    elseif tag == TAG_NINF_BYTE then
        return -math.huge
    else
        return nil, "Unknown type tag: " .. string.char(tag)
    end
end

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

--- Serialize one or more Lua values to a string
-- @param ... - Values to serialize (any serializable type)
-- @return string - The serialized representation
function LoolibSerializerMixin:Serialize(...)
    local count = select("#", ...)
    if count == 0 then
        return MARKER .. PROTOCOL_VERSION
    end

    -- Clear circular reference tracker
    wipe(serializingTables)

    local output = { MARKER .. PROTOCOL_VERSION }

    for i = 1, count do
        SerializeValue(select(i, ...), output)
    end

    return table.concat(output)
end

--- Deserialize a string back to Lua values
-- @param str string - The serialized string
-- @return boolean, ... - Success flag followed by deserialized values
function LoolibSerializerMixin:Deserialize(str)
    if type(str) ~= "string" then
        return false, "Input must be a string"
    end

    if #str < 2 then
        return false, "Input too short"
    end

    -- Validate version header
    if str:sub(1, 1) ~= MARKER then
        return false, "Invalid serialization format: missing header marker"
    end

    local version = str:sub(2, 2)
    if version ~= PROTOCOL_VERSION then
        return false, "Unsupported protocol version: " .. version
    end

    -- Initialize parser state
    parseStr = str
    parsePos = 3  -- Start after version header
    parseLen = #str

    local results = {}
    local resultCount = 0

    while parsePos <= parseLen do
        local value, err = ParseValue()
        if err then
            return false, err
        end
        resultCount = resultCount + 1
        results[resultCount] = value
    end

    return true, unpack(results, 1, resultCount)
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new Serializer instance
-- @return table - A new Serializer object
function CreateLoolibSerializer()
    return LoolibCreateFromMixins(LoolibSerializerMixin)
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

LoolibSerializer = LoolibCreateFromMixins(LoolibSerializerMixin)

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local SerializerModule = {
    Mixin = LoolibSerializerMixin,
    Create = CreateLoolibSerializer,
    Serializer = LoolibSerializer,
}

Loolib:RegisterModule("Serializer", SerializerModule)

-- Also register in Comm module namespace
local Comm = Loolib:GetOrCreateModule("Comm")
Comm.Serializer = LoolibSerializer
