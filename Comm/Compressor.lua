--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Compressor - DEFLATE compression implementation

    Provides compression/decompression using the DEFLATE algorithm
    (RFC 1951) with optional zlib wrapper (RFC 1950). Includes encoding
    functions for WoW addon channel and printable export strings.

    Implementation is original, designed for Lua 5.1 with bit library.
----------------------------------------------------------------------]]

local LibStub = LibStub
local assert = assert
local error = error
local math = math
local string = string
local table = table
local type = type

local Loolib = LibStub("Loolib")
-- Use Loolib.Mixin/CreateFromMixins directly (module aliases can shift during load order)
local ApplyMixins = assert(Loolib.Mixin,
    "Loolib.Mixin must be loaded before Comm/Compressor.lua")
local CreateFromMixins = assert(Loolib.CreateFromMixins,
    "Loolib.CreateFromMixins must be loaded before Comm/Compressor.lua")
local Comm = Loolib.Comm or Loolib:GetOrCreateModule("Comm")

Loolib.Comm = Comm

--[[--------------------------------------------------------------------
    Bit Operations
    WoW provides bit library: bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
----------------------------------------------------------------------]]

local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local lshift = bit.lshift
local rshift = bit.rshift

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

local CompressorMixin = {}

-- DEFLATE fixed Huffman tables (RFC 1951, Section 3.2.6)
local MAX_WINDOW_SIZE = 32768  -- 32KB sliding window
local MAX_MATCH_LENGTH = 258
local MIN_MATCH_LENGTH = 3
local MAX_DISTANCE = 32768

-- Hash-chain constants for O(N * chainLen) LZ77 matching (replaces naive O(N * 32768))
local HASH_SIZE = 65536
local HASH_MASK = HASH_SIZE - 1
local MAX_CHAIN_LEN = 64

-- Huffman tree limits
local MAX_BITS = 15
local LITERAL_COUNT = 286  -- 0-255 literals + 256 end + 257-285 length codes
local DISTANCE_COUNT = 30

-- Block types
local BLOCK_STORED = 0
local BLOCK_FIXED = 1
local BLOCK_DYNAMIC = 2

-- Length code base values (codes 257-285)
local LENGTH_BASE = {
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
}

-- Extra bits for length codes
local LENGTH_EXTRA_BITS = {
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
}

-- Distance code base values
local DISTANCE_BASE = {
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
    257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
    8193, 12289, 16385, 24577
}

-- Extra bits for distance codes
local DISTANCE_EXTRA_BITS = {
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
    7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
}

-- Code length order for dynamic huffman header
local CODE_LENGTH_ORDER = {
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
}

-- Base64 alphabet for printable encoding
local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_DECODE = {}
for i = 1, #BASE64_CHARS do
    BASE64_DECODE[BASE64_CHARS:sub(i, i)] = i - 1
end

-- Pre-computed lookup table for EncodeForPrint (avoids per-char sub() calls)
local BASE64_LOOKUP = {}
for i = 0, 63 do
    BASE64_LOOKUP[i] = BASE64_CHARS:sub(i + 1, i + 1)
end

--[[--------------------------------------------------------------------
    BitStream - Bit-level reading and writing
----------------------------------------------------------------------]]

local function CreateBitWriter()
    local writer = {
        buffer = {},
        bitBuf = 0,
        bitCount = 0,
    }

    function writer:WriteBits(value, numBits)
        self.bitBuf = bor(self.bitBuf, lshift(value, self.bitCount))
        self.bitCount = self.bitCount + numBits

        while self.bitCount >= 8 do
            self.buffer[#self.buffer + 1] = string.char(band(self.bitBuf, 0xFF))
            self.bitBuf = rshift(self.bitBuf, 8)
            self.bitCount = self.bitCount - 8
        end
    end

    function writer:WriteByte(value)
        self:WriteBits(value, 8)
    end

    function writer:WriteBytes(str)
        for i = 1, #str do
            self:WriteByte(str:byte(i))
        end
    end

    function writer:AlignToByte()
        if self.bitCount > 0 then
            self.buffer[#self.buffer + 1] = string.char(band(self.bitBuf, 0xFF))
            self.bitBuf = 0
            self.bitCount = 0
        end
    end

    function writer:Flush()
        self:AlignToByte()
        return table.concat(self.buffer)
    end

    return writer
end

local function CreateBitReader(str)
    local reader = {
        data = str,
        pos = 1,
        bitBuf = 0,
        bitCount = 0,
    }

    function reader:ReadBits(numBits)
        while self.bitCount < numBits do
            if self.pos > #self.data then
                return nil  -- End of data
            end
            self.bitBuf = bor(self.bitBuf, lshift(self.data:byte(self.pos), self.bitCount))
            self.pos = self.pos + 1
            self.bitCount = self.bitCount + 8
        end

        local value = band(self.bitBuf, lshift(1, numBits) - 1)
        self.bitBuf = rshift(self.bitBuf, numBits)
        self.bitCount = self.bitCount - numBits
        return value
    end

    function reader:ReadByte()
        return self:ReadBits(8)
    end

    function reader:AlignToByte()
        local discard = self.bitCount % 8
        if discard > 0 then
            self.bitBuf = rshift(self.bitBuf, discard)
            self.bitCount = self.bitCount - discard
        end
    end

    function reader:IsAtEnd()
        return self.pos > #self.data and self.bitCount == 0
    end

    return reader
end

--[[--------------------------------------------------------------------
    Huffman Tree Construction
----------------------------------------------------------------------]]

local function BuildHuffmanTree(codeLengths, maxSymbol)
    -- Count codes of each length
    local blCount = {}
    for i = 0, MAX_BITS do
        blCount[i] = 0
    end

    for i = 0, maxSymbol - 1 do
        local len = codeLengths[i] or 0
        if len > 0 then
            blCount[len] = blCount[len] + 1
        end
    end

    -- Calculate starting code for each length
    local nextCode = {}
    local code = 0
    for bits = 1, MAX_BITS do
        code = lshift(code + (blCount[bits - 1] or 0), 1)
        nextCode[bits] = code
    end

    -- Assign codes to symbols
    local tree = {}
    for i = 0, maxSymbol - 1 do
        local len = codeLengths[i] or 0
        if len > 0 then
            tree[i] = {
                code = nextCode[len],
                length = len,
            }
            nextCode[len] = nextCode[len] + 1
        end
    end

    return tree
end

local function BuildDecodeTable(codeLengths, maxSymbol)
    -- Build a table for fast decoding: maps (reversed code, length) -> symbol
    local table = {}

    local blCount = {}
    for i = 0, MAX_BITS do
        blCount[i] = 0
    end

    for i = 0, maxSymbol - 1 do
        local len = codeLengths[i] or 0
        if len > 0 then
            blCount[len] = blCount[len] + 1
        end
    end

    local nextCode = {}
    local code = 0
    for bits = 1, MAX_BITS do
        code = lshift(code + (blCount[bits - 1] or 0), 1)
        nextCode[bits] = code
    end

    for i = 0, maxSymbol - 1 do
        local len = codeLengths[i] or 0
        if len > 0 then
            local c = nextCode[len]
            nextCode[len] = nextCode[len] + 1

            -- Reverse bits for lookup
            local reversed = 0
            for b = 0, len - 1 do
                if band(c, lshift(1, len - 1 - b)) ~= 0 then
                    reversed = bor(reversed, lshift(1, b))
                end
            end

            table[reversed * 16 + len] = i
        end
    end

    return table
end

local function DecodeSymbol(reader, decodeTable, maxBits)
    local code = 0
    for len = 1, maxBits do
        local bit = reader:ReadBits(1)
        if bit == nil then
            return nil
        end
        code = bor(code, lshift(bit, len - 1))

        local symbol = decodeTable[code * 16 + len]
        if symbol then
            return symbol
        end
    end
    return nil
end

--[[--------------------------------------------------------------------
    Fixed Huffman Tables (DEFLATE block type 1)
----------------------------------------------------------------------]]

local FIXED_LITERAL_LENGTHS = {}
local FIXED_DISTANCE_LENGTHS = {}

-- Build fixed literal/length code lengths (RFC 1951 section 3.2.6)
for i = 0, 143 do FIXED_LITERAL_LENGTHS[i] = 8 end
for i = 144, 255 do FIXED_LITERAL_LENGTHS[i] = 9 end
for i = 256, 279 do FIXED_LITERAL_LENGTHS[i] = 7 end
for i = 280, 287 do FIXED_LITERAL_LENGTHS[i] = 8 end

-- Fixed distance codes all have length 5
for i = 0, 31 do FIXED_DISTANCE_LENGTHS[i] = 5 end

local FIXED_LITERAL_TREE = BuildHuffmanTree(FIXED_LITERAL_LENGTHS, 288)
local FIXED_DISTANCE_TREE = BuildHuffmanTree(FIXED_DISTANCE_LENGTHS, 32)
local FIXED_LITERAL_DECODE = BuildDecodeTable(FIXED_LITERAL_LENGTHS, 288)
local FIXED_DISTANCE_DECODE = BuildDecodeTable(FIXED_DISTANCE_LENGTHS, 32)

-- Pre-computed bit-reversed codes for fixed Huffman trees (avoids per-call reversal in hot loop)
local FIXED_LIT_REV = {}
local FIXED_LIT_LEN = {}
do
    for sym = 0, 287 do
        local entry = FIXED_LITERAL_TREE[sym]
        if entry then
            local code = entry.code
            local len = entry.length
            local rev = 0
            for i = 0, len - 1 do
                if band(code, lshift(1, len - 1 - i)) ~= 0 then
                    rev = bor(rev, lshift(1, i))
                end
            end
            FIXED_LIT_REV[sym] = rev
            FIXED_LIT_LEN[sym] = len
        end
    end
end

local FIXED_DIST_REV = {}
local FIXED_DIST_LEN = {}
do
    for sym = 0, 31 do
        local entry = FIXED_DISTANCE_TREE[sym]
        if entry then
            local code = entry.code
            local len = entry.length
            local rev = 0
            for i = 0, len - 1 do
                if band(code, lshift(1, len - 1 - i)) ~= 0 then
                    rev = bor(rev, lshift(1, i))
                end
            end
            FIXED_DIST_REV[sym] = rev
            FIXED_DIST_LEN[sym] = len
        end
    end
end

--[[--------------------------------------------------------------------
    LZ77 Compression - Find Repeated Strings
----------------------------------------------------------------------]]

-- Hash-chain LZ77: O(N * MAX_CHAIN_LEN) vs naive O(N * 32768)
-- head[hash] = most recent position with that 3-byte hash
-- prev[pos]  = previous position in the same hash chain
local function FindLongestMatchHC(data, pos, head, prev, maxLen)
    local bestLength = 0
    local bestDistance = 0

    local dataLen = #data
    local maxSearchLen = math.min(maxLen, dataLen - pos + 1, MAX_MATCH_LENGTH)

    if maxSearchLen < MIN_MATCH_LENGTH or pos + 2 > dataLen then
        return 0, 0
    end

    local b1 = data:byte(pos)
    local b2 = data:byte(pos + 1)
    local b3 = data:byte(pos + 2)
    local h = band(bxor(lshift(b1, 10), lshift(b2, 5), b3), HASH_MASK)

    local searchPos = head[h]
    local chainLen = 0
    local windowStart = pos - MAX_WINDOW_SIZE

    while searchPos and searchPos > windowStart and chainLen < MAX_CHAIN_LEN do
        if data:byte(searchPos) == b1
            and data:byte(searchPos + 1) == b2
            and data:byte(searchPos + 2) == b3 then
            -- Extend the 3-byte prefix match
            local length = 3
            while length < maxSearchLen do
                if data:byte(searchPos + length) ~= data:byte(pos + length) then
                    break
                end
                length = length + 1
            end
            if length > bestLength then
                bestLength = length
                bestDistance = pos - searchPos
                if length == maxSearchLen then
                    break
                end
            end
        end
        searchPos = prev[searchPos]
        chainLen = chainLen + 1
    end

    -- Update hash chain for this position
    prev[pos] = head[h]
    head[h] = pos

    if bestLength < MIN_MATCH_LENGTH then
        return 0, 0
    end
    return bestLength, bestDistance
end

local function GetLengthCode(length)
    -- Find the length code (257-285) for a given match length
    for i = 1, #LENGTH_BASE do
        if LENGTH_BASE[i] > length then
            return 256 + i - 1, length - LENGTH_BASE[i - 1]
        elseif LENGTH_BASE[i] == length then
            return 256 + i, 0
        end
    end
    return 285, length - 258
end

local function GetDistanceCode(distance)
    -- Find the distance code (0-29) for a given distance
    for i = 1, #DISTANCE_BASE do
        if DISTANCE_BASE[i] > distance then
            return i - 2, distance - DISTANCE_BASE[i - 1]
        elseif DISTANCE_BASE[i] == distance then
            return i - 1, 0
        end
    end
    return 29, distance - DISTANCE_BASE[30]
end

-- Pre-computed O(1) lookup tables for match encoding (replaces linear search per match)
local LENGTH_CODE_LOOKUP_C = {}  -- [length]   = lengthCode
local LENGTH_CODE_LOOKUP_E = {}  -- [length]   = extraBits
local DIST_CODE_LOOKUP_C = {}    -- [distance] = distCode
local DIST_CODE_LOOKUP_E = {}    -- [distance] = extraBits
do
    for len = 3, 258 do
        local code, extra = GetLengthCode(len)
        LENGTH_CODE_LOOKUP_C[len] = code
        LENGTH_CODE_LOOKUP_E[len] = extra
    end
    for dist = 1, 32768 do
        local code, extra = GetDistanceCode(dist)
        DIST_CODE_LOOKUP_C[dist] = code
        DIST_CODE_LOOKUP_E[dist] = extra
    end
end

--[[--------------------------------------------------------------------
    DEFLATE Compression
----------------------------------------------------------------------]]

local function WriteHuffmanCode(writer, tree, symbol)
    local entry = tree[symbol]
    if not entry then
        error("No huffman code for symbol: " .. symbol)
    end

    -- Write bits in reverse order (LSB first for DEFLATE)
    local code = entry.code
    local len = entry.length
    local reversed = 0
    for i = 0, len - 1 do
        if band(code, lshift(1, len - 1 - i)) ~= 0 then
            reversed = bor(reversed, lshift(1, i))
        end
    end
    writer:WriteBits(reversed, len)
end

local function CompressBlockFixed(writer, data, startPos, endPos)
    local pos = startPos
    local head = {}  -- hash -> most-recent position
    local prev = {}  -- position -> previous position with same hash

    while pos <= endPos do
        local length, distance = FindLongestMatchHC(data, pos, head, prev,
            math.min(MAX_MATCH_LENGTH, endPos - pos + 1))

        if length >= MIN_MATCH_LENGTH then
            -- Write length/distance pair using pre-computed tables (O(1) lookups)
            local lengthCode = LENGTH_CODE_LOOKUP_C[length]
            local lengthExtra = LENGTH_CODE_LOOKUP_E[length]
            local distCode = DIST_CODE_LOOKUP_C[distance]
            local distExtra = DIST_CODE_LOOKUP_E[distance]

            writer:WriteBits(FIXED_LIT_REV[lengthCode], FIXED_LIT_LEN[lengthCode])
            if LENGTH_EXTRA_BITS[lengthCode - 256] > 0 then
                writer:WriteBits(lengthExtra, LENGTH_EXTRA_BITS[lengthCode - 256])
            end

            writer:WriteBits(FIXED_DIST_REV[distCode], FIXED_DIST_LEN[distCode])
            if DISTANCE_EXTRA_BITS[distCode + 1] > 0 then
                writer:WriteBits(distExtra, DISTANCE_EXTRA_BITS[distCode + 1])
            end

            -- Update hash chains for positions skipped by this match
            for i = 1, length - 1 do
                local p = pos + i
                if p + 2 <= endPos then
                    local b1 = data:byte(p)
                    local b2 = data:byte(p + 1)
                    local b3 = data:byte(p + 2)
                    local h = band(bxor(lshift(b1, 10), lshift(b2, 5), b3), HASH_MASK)
                    prev[p] = head[h]
                    head[h] = p
                end
            end

            pos = pos + length
        else
            -- Write literal byte using pre-computed reversed code
            local byte = data:byte(pos)
            writer:WriteBits(FIXED_LIT_REV[byte], FIXED_LIT_LEN[byte])
            pos = pos + 1
        end
    end

    -- Write end of block
    writer:WriteBits(FIXED_LIT_REV[256], FIXED_LIT_LEN[256])
end

local function CompressBlockStored(writer, data, startPos, endPos)
    local len = endPos - startPos + 1

    writer:AlignToByte()
    writer:WriteBits(band(len, 0xFF), 8)
    writer:WriteBits(band(rshift(len, 8), 0xFF), 8)
    writer:WriteBits(band(bxor(len, 0xFFFF), 0xFF), 8)
    writer:WriteBits(band(rshift(bxor(len, 0xFFFF), 8), 0xFF), 8)

    for i = startPos, endPos do
        writer:WriteByte(data:byte(i))
    end
end

local function DeflateCompress(data, level)
    if #data == 0 then
        return ""
    end

    local writer = CreateBitWriter()

    -- For simplicity, use single block
    -- BFINAL=1 (last block), BTYPE based on level
    if level == 0 then
        -- Store only
        writer:WriteBits(1, 1)  -- BFINAL
        writer:WriteBits(BLOCK_STORED, 2)  -- BTYPE
        CompressBlockStored(writer, data, 1, #data)
    else
        -- Fixed Huffman
        writer:WriteBits(1, 1)  -- BFINAL
        writer:WriteBits(BLOCK_FIXED, 2)  -- BTYPE
        CompressBlockFixed(writer, data, 1, #data)
    end

    return writer:Flush()
end

--[[--------------------------------------------------------------------
    DEFLATE Decompression
----------------------------------------------------------------------]]

local function InflateBlockStored(reader, output)
    reader:AlignToByte()

    local len = bor(reader:ReadBits(8), lshift(reader:ReadBits(8), 8))
    local nlen = bor(reader:ReadBits(8), lshift(reader:ReadBits(8), 8))

    if bxor(len, nlen) ~= 0xFFFF then
        return false, "Invalid stored block length"
    end

    for i = 1, len do
        local byte = reader:ReadByte()
        if byte == nil then
            return false, "Unexpected end of data"
        end
        output[#output + 1] = string.char(byte)
    end

    return true
end

local function InflateBlockHuffman(reader, litTable, distTable, output)
    -- Track output length separately to avoid repeated #output calls
    local outLen = #output
    
    while true do
        local symbol = DecodeSymbol(reader, litTable, MAX_BITS)
        if symbol == nil then
            return false, "Failed to decode literal/length symbol"
        end

        if symbol < 256 then
            -- Literal byte - each output entry is a single char
            outLen = outLen + 1
            output[outLen] = string.char(symbol)
        elseif symbol == 256 then
            -- End of block
            return true
        else
            -- Length/distance pair
            local lengthIdx = symbol - 256
            if lengthIdx < 1 or lengthIdx > #LENGTH_BASE then
                return false, "Invalid length code: " .. symbol
            end
            local length = LENGTH_BASE[lengthIdx]
            local extraBits = LENGTH_EXTRA_BITS[lengthIdx]
            if extraBits > 0 then
                length = length + reader:ReadBits(extraBits)
            end

            local distSymbol = DecodeSymbol(reader, distTable, MAX_BITS)
            if distSymbol == nil then
                return false, "Failed to decode distance symbol"
            end
            if distSymbol < 0 or distSymbol >= DISTANCE_COUNT then
                return false, "Invalid distance code: " .. distSymbol
            end

            local distance = DISTANCE_BASE[distSymbol + 1]
            local distExtraBits = DISTANCE_EXTRA_BITS[distSymbol + 1]
            if distExtraBits > 0 then
                distance = distance + reader:ReadBits(distExtraBits)
            end

            -- Copy from output buffer using direct table indexing
            -- Each output[i] is a single character, so we can index directly
            local copyStart = outLen - distance + 1

            for i = 0, length - 1 do
                local srcIdx = copyStart + (i % distance)
                outLen = outLen + 1
                output[outLen] = output[srcIdx]
            end
        end
    end
end

local function ReadDynamicTables(reader)
    local hlit = reader:ReadBits(5) + 257
    local hdist = reader:ReadBits(5) + 1
    local hclen = reader:ReadBits(4) + 4

    -- Read code length code lengths
    local codeLengthLengths = {}
    for i = 0, 18 do
        codeLengthLengths[i] = 0
    end

    for i = 1, hclen do
        codeLengthLengths[CODE_LENGTH_ORDER[i]] = reader:ReadBits(3)
    end

    local codeLengthTable = BuildDecodeTable(codeLengthLengths, 19)

    -- Read literal/length and distance code lengths
    local allLengths = {}
    local totalCodes = hlit + hdist
    local i = 0

    while i < totalCodes do
        local symbol = DecodeSymbol(reader, codeLengthTable, 7)
        if symbol == nil then
            return nil, nil, "Failed to decode code length"
        end

        if symbol < 16 then
            allLengths[i] = symbol
            i = i + 1
        elseif symbol == 16 then
            local repeatCount = reader:ReadBits(2) + 3
            local repeatValue = allLengths[i - 1] or 0
            for j = 1, repeatCount do
                allLengths[i] = repeatValue
                i = i + 1
            end
        elseif symbol == 17 then
            local repeatCount = reader:ReadBits(3) + 3
            for j = 1, repeatCount do
                allLengths[i] = 0
                i = i + 1
            end
        elseif symbol == 18 then
            local repeatCount = reader:ReadBits(7) + 11
            for j = 1, repeatCount do
                allLengths[i] = 0
                i = i + 1
            end
        end
    end

    -- Split into literal and distance tables
    local litLengths = {}
    for j = 0, hlit - 1 do
        litLengths[j] = allLengths[j] or 0
    end

    local distLengths = {}
    for j = 0, hdist - 1 do
        distLengths[j] = allLengths[hlit + j] or 0
    end

    return BuildDecodeTable(litLengths, hlit), BuildDecodeTable(distLengths, hdist)
end

local function DeflateDecompress(data)
    if #data == 0 then
        return "", true
    end

    local reader = CreateBitReader(data)
    local output = {}

    repeat
        local bfinal = reader:ReadBits(1)
        local btype = reader:ReadBits(2)

        if bfinal == nil or btype == nil then
            return nil, false, "Unexpected end of compressed data"
        end

        local success, err

        if btype == BLOCK_STORED then
            success, err = InflateBlockStored(reader, output)
        elseif btype == BLOCK_FIXED then
            success, err = InflateBlockHuffman(reader, FIXED_LITERAL_DECODE, FIXED_DISTANCE_DECODE, output)
        elseif btype == BLOCK_DYNAMIC then
            local litTable, distTable
            litTable, distTable, err = ReadDynamicTables(reader)
            if litTable then
                success, err = InflateBlockHuffman(reader, litTable, distTable, output)
            else
                success = false
            end
        else
            return nil, false, "Invalid block type"
        end

        if not success then
            return nil, false, err or "Decompression failed"
        end
    until bfinal == 1

    return table.concat(output), true
end

--[[--------------------------------------------------------------------
    Adler-32 Checksum
----------------------------------------------------------------------]]

local function Adler32(data)
    local a = 1
    local b = 0
    local MOD_ADLER = 65521

    for i = 1, #data do
        a = (a + data:byte(i)) % MOD_ADLER
        b = (b + a) % MOD_ADLER
    end

    return bor(lshift(b, 16), a)
end

--[[--------------------------------------------------------------------
    Zlib Wrapper (RFC 1950)
----------------------------------------------------------------------]]

local function ZlibCompress(data, level)
    -- CMF byte: compression method (8 = deflate) + log2(window size) - 8
    local cmf = 0x78  -- deflate, 32K window

    -- FLG byte: compression level in bits 6-7
    local levelFlag
    if level <= 1 then
        levelFlag = 0
    elseif level <= 5 then
        levelFlag = 1
    elseif level <= 7 then
        levelFlag = 2
    else
        levelFlag = 3
    end

    local flg = lshift(levelFlag, 6)

    -- Adjust FLG so (CMF * 256 + FLG) % 31 == 0
    local check = (cmf * 256 + flg) % 31
    if check ~= 0 then
        flg = flg + (31 - check)
    end

    local compressed = DeflateCompress(data, level)
    local checksum = Adler32(data)

    local result = {
        string.char(cmf),
        string.char(flg),
        compressed,
        string.char(band(rshift(checksum, 24), 0xFF)),
        string.char(band(rshift(checksum, 16), 0xFF)),
        string.char(band(rshift(checksum, 8), 0xFF)),
        string.char(band(checksum, 0xFF)),
    }

    return table.concat(result)
end

local function ZlibDecompress(data)
    if #data < 6 then
        return nil, false, "Data too short for zlib format"
    end

    local cmf = data:byte(1)
    local flg = data:byte(2)

    -- Validate header
    if (cmf * 256 + flg) % 31 ~= 0 then
        return nil, false, "Invalid zlib header checksum"
    end

    local cm = band(cmf, 0x0F)
    if cm ~= 8 then
        return nil, false, "Unsupported compression method"
    end

    -- Extract Adler-32 checksum from end
    local storedChecksum = bor(
        lshift(data:byte(#data - 3), 24),
        lshift(data:byte(#data - 2), 16),
        lshift(data:byte(#data - 1), 8),
        data:byte(#data)
    )

    -- Decompress
    local compressedData = data:sub(3, #data - 4)
    local decompressed, success, err = DeflateDecompress(compressedData)

    if not success then
        return nil, false, err
    end

    -- Verify checksum
    local computedChecksum = Adler32(decompressed)
    if computedChecksum ~= storedChecksum then
        return nil, false, "Checksum mismatch"
    end

    return decompressed, true
end

--[[--------------------------------------------------------------------
    Addon Channel Encoding
    Avoid NULL bytes and other problematic characters for WoW addon messages
----------------------------------------------------------------------]]

local function EncodeForAddonChannel(data)
    local result = {}

    for i = 1, #data do
        local byte = data:byte(i)

        if byte == 0 then
            -- NULL -> escape sequence
            result[#result + 1] = string.char(1, 1)
        elseif byte == 1 then
            -- Escape character itself
            result[#result + 1] = string.char(1, 2)
        elseif byte == 255 then
            -- 255 can be problematic
            result[#result + 1] = string.char(1, 3)
        else
            result[#result + 1] = string.char(byte)
        end
    end

    return table.concat(result)
end

local function DecodeForAddonChannel(data)
    local result = {}
    local i = 1

    while i <= #data do
        local byte = data:byte(i)

        if byte == 1 and i < #data then
            local nextByte = data:byte(i + 1)
            if nextByte == 1 then
                result[#result + 1] = string.char(0)
            elseif nextByte == 2 then
                result[#result + 1] = string.char(1)
            elseif nextByte == 3 then
                result[#result + 1] = string.char(255)
            else
                result[#result + 1] = string.char(byte)
                i = i - 1  -- Will be incremented by 2
            end
            i = i + 2
        else
            result[#result + 1] = string.char(byte)
            i = i + 1
        end
    end

    return table.concat(result)
end

--[[--------------------------------------------------------------------
    Printable Encoding (Base64)
    For export strings that can be copied/pasted
----------------------------------------------------------------------]]

local function EncodeForPrint(data)
    local result = {}
    local len = #data

    for i = 1, len, 3 do
        local b1 = data:byte(i)
        local b2 = data:byte(i + 1) or 0
        local b3 = data:byte(i + 2) or 0

        local n = bor(lshift(b1, 16), lshift(b2, 8), b3)

        -- Use pre-built lookup table: eliminates 4 sub() calls per 3 bytes
        result[#result + 1] = BASE64_LOOKUP[rshift(n, 18)]
        result[#result + 1] = BASE64_LOOKUP[band(rshift(n, 12), 0x3F)]

        if i + 1 <= len then
            result[#result + 1] = BASE64_LOOKUP[band(rshift(n, 6), 0x3F)]
        else
            result[#result + 1] = "="
        end

        if i + 2 <= len then
            result[#result + 1] = BASE64_LOOKUP[band(n, 0x3F)]
        else
            result[#result + 1] = "="
        end
    end

    return table.concat(result)
end

local function DecodeForPrint(data)
    -- Remove whitespace and padding
    data = data:gsub("%s", ""):gsub("=", "")

    local result = {}
    local len = #data

    for i = 1, len, 4 do
        local c1 = BASE64_DECODE[data:sub(i, i)] or 0
        local c2 = BASE64_DECODE[data:sub(i + 1, i + 1)] or 0
        local c3 = BASE64_DECODE[data:sub(i + 2, i + 2)]
        local c4 = BASE64_DECODE[data:sub(i + 3, i + 3)]

        local n = bor(lshift(c1, 18), lshift(c2, 12))

        if c3 then
            n = bor(n, lshift(c3, 6))
        end
        if c4 then
            n = bor(n, c4)
        end

        result[#result + 1] = string.char(band(rshift(n, 16), 0xFF))

        if c3 then
            result[#result + 1] = string.char(band(rshift(n, 8), 0xFF))
        end
        if c4 then
            result[#result + 1] = string.char(band(n, 0xFF))
        end
    end

    return table.concat(result)
end

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

--- Compress data using DEFLATE algorithm
-- @param str string - Data to compress
-- @param level number - Compression level (0-9, default 6)
-- @return string - Compressed data
function CompressorMixin:Compress(str, level)
    if type(str) ~= "string" then
        error("Compress requires string input", 2)
    end

    level = level or 6
    level = math.max(0, math.min(9, level))

    return DeflateCompress(str, level)
end

--- Decompress DEFLATE-compressed data
-- @param str string - Compressed data
-- @return string|nil, boolean - Decompressed data and success flag
function CompressorMixin:Decompress(str)
    if type(str) ~= "string" then
        return nil, false
    end

    return DeflateDecompress(str)
end

--- Compress data with zlib wrapper
-- @param str string - Data to compress
-- @param level number - Compression level (0-9, default 6)
-- @return string - Compressed data with zlib header/trailer
function CompressorMixin:CompressZlib(str, level)
    if type(str) ~= "string" then
        error("CompressZlib requires string input", 2)
    end

    level = level or 6
    level = math.max(0, math.min(9, level))

    return ZlibCompress(str, level)
end

--- Decompress zlib-format data
-- @param str string - Zlib-compressed data
-- @return string|nil, boolean - Decompressed data and success flag
function CompressorMixin:DecompressZlib(str)
    if type(str) ~= "string" then
        return nil, false
    end

    return ZlibDecompress(str)
end

--- Encode data for safe transmission over WoW addon channels
-- @param str string - Data to encode
-- @return string - Encoded data safe for addon messages
function CompressorMixin:EncodeForAddonChannel(str)
    if type(str) ~= "string" then
        error("EncodeForAddonChannel requires string input", 2)
    end

    return EncodeForAddonChannel(str)
end

--- Decode addon channel encoded data
-- @param str string - Encoded data
-- @return string - Original data
function CompressorMixin:DecodeForAddonChannel(str)
    if type(str) ~= "string" then
        error("DecodeForAddonChannel requires string input", 2)
    end

    return DecodeForAddonChannel(str)
end

--- Encode data for printable export strings (Base64)
-- @param str string - Data to encode
-- @return string - Base64-encoded string
function CompressorMixin:EncodeForPrint(str)
    if type(str) ~= "string" then
        error("EncodeForPrint requires string input", 2)
    end

    return EncodeForPrint(str)
end

--- Decode printable export string
-- @param str string - Base64-encoded string
-- @return string - Original data
function CompressorMixin:DecodeForPrint(str)
    if type(str) ~= "string" then
        error("DecodeForPrint requires string input", 2)
    end

    return DecodeForPrint(str)
end

--- Calculate Adler-32 checksum
-- @param str string - Data to checksum
-- @return number - Adler-32 checksum
function CompressorMixin:Adler32(str)
    if type(str) ~= "string" then
        error("Adler32 requires string input", 2)
    end

    return Adler32(str)
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new Compressor instance
-- @return table - A new Compressor object
local function CreateCompressor()
    return CreateFromMixins(CompressorMixin)
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

local CompressorModule = Comm.Compressor
local CompressorInstance

if type(CompressorModule) == "table" and CompressorModule.Instance then
    CompressorInstance = CompressorModule.Instance
elseif type(CompressorModule) == "table"
    and CompressorModule.Compress
    and CompressorModule.Decompress then
    CompressorInstance = CompressorModule
    CompressorModule = {}
else
    CompressorModule = type(CompressorModule) == "table" and CompressorModule or {}
    CompressorInstance = CompressorModule.Instance or Loolib.Compressor or {}
end

ApplyMixins(CompressorInstance, CompressorMixin)

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib.Comm.Compressor = CompressorModule
Loolib.Comm.Compressor.Mixin = CompressorMixin
Loolib.Comm.Compressor.Create = CreateCompressor
Loolib.Comm.Compressor.Instance = CompressorInstance
Loolib.Comm.Compressor.Compressor = CompressorInstance

Loolib.Compressor = CompressorInstance

Loolib:RegisterModule("Comm.Compressor", CompressorModule)
Loolib:RegisterModule("Compressor", CompressorModule)
