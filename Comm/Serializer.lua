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

local function SerializeString(value)
    return MARKER .. TAG_STRING .. EscapeString(value)
end

local function SerializeNumber(value)
    -- Handle special cases
    if value == math.huge then
        return MARKER .. TAG_INF
    elseif value == -math.huge then
        return MARKER .. TAG_NINF
    end

    -- Check if it's an integer
    local intPart = math.floor(value)
    if value == intPart and value >= -2147483648 and value <= 2147483647 then
        return MARKER .. TAG_NUMBER .. tostring(intPart)
    end

    -- Float: use format that preserves precision
    -- Format: ^F<integer>^f<fractional>
    local str = string.format("%.17g", value)
    return MARKER .. TAG_FLOAT .. str .. MARKER .. TAG_FLOAT_END
end

local function SerializeBoolean(value)
    return MARKER .. (value and TAG_BOOL_TRUE or TAG_BOOL_FALSE)
end

local function SerializeNil()
    return MARKER .. TAG_NIL
end

local function SerializeTable(tbl, output)
    -- Check for circular reference
    if serializingTables[tbl] then
        error("Circular reference detected in table serialization", 3)
    end

    serializingTables[tbl] = true
    output[#output + 1] = MARKER .. TAG_TABLE_START

    -- Serialize key-value pairs
    for key, val in pairs(tbl) do
        SerializeValue(key, output)
        SerializeValue(val, output)
    end

    output[#output + 1] = MARKER .. TAG_TABLE_END
    serializingTables[tbl] = nil
end

function SerializeValue(value, output)
    local valueType = type(value)

    if valueType == "string" then
        output[#output + 1] = SerializeString(value)
    elseif valueType == "number" then
        output[#output + 1] = SerializeNumber(value)
    elseif valueType == "boolean" then
        output[#output + 1] = SerializeBoolean(value)
    elseif valueType == "nil" then
        output[#output + 1] = SerializeNil()
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

local function ParseChar()
    if parsePos > parseLen then
        return nil
    end
    local c = parseStr:sub(parsePos, parsePos)
    parsePos = parsePos + 1
    return c
end

local function PeekChar()
    if parsePos > parseLen then
        return nil
    end
    return parseStr:sub(parsePos, parsePos)
end

-- Read until next ^ marker or end
local function ReadUntilMarker()
    local start = parsePos
    local result = {}

    while parsePos <= parseLen do
        local c = parseStr:sub(parsePos, parsePos)
        if c == MARKER then
            break
        elseif c == "\001" then
            -- Escape sequence
            parsePos = parsePos + 1
            if parsePos <= parseLen then
                local escaped = parseStr:sub(parsePos, parsePos)
                result[#result + 1] = UNESCAPE_MAP[escaped] or escaped
                parsePos = parsePos + 1
            end
        else
            result[#result + 1] = c
            parsePos = parsePos + 1
        end
    end

    return table.concat(result)
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
    local marker = ParseChar()
    local tag = ParseChar()
    if marker ~= MARKER or tag ~= TAG_FLOAT_END then
        return nil, "Invalid float format"
    end
    return tonumber(numStr)
end

local function ParseTable()
    local tbl = {}

    while true do
        local marker = PeekChar()
        if not marker then
            return nil, "Unexpected end of input in table"
        end

        if marker ~= MARKER then
            return nil, "Expected marker in table"
        end

        parsePos = parsePos + 1
        local tag = PeekChar()

        if tag == TAG_TABLE_END then
            parsePos = parsePos + 1
            return tbl
        end

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
    local marker = ParseChar()
    if marker ~= MARKER then
        return nil, "Expected marker"
    end

    local tag = ParseChar()
    if not tag then
        return nil, "Unexpected end of input"
    end

    if tag == TAG_STRING then
        return ParseString()
    elseif tag == TAG_NUMBER then
        return ParseNumber()
    elseif tag == TAG_FLOAT then
        return ParseFloat()
    elseif tag == TAG_TABLE_START then
        return ParseTable()
    elseif tag == TAG_BOOL_TRUE then
        return true
    elseif tag == TAG_BOOL_FALSE then
        return false
    elseif tag == TAG_NIL then
        return nil
    elseif tag == TAG_INF then
        return math.huge
    elseif tag == TAG_NINF then
        return -math.huge
    else
        return nil, "Unknown type tag: " .. tag
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
