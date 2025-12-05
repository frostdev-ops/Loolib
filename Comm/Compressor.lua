--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Compressor - DEFLATE compression implementation

    Provides compression/decompression using the DEFLATE algorithm
    (RFC 1951) with optional zlib wrapper (RFC 1950). Includes encoding
    functions for WoW addon channel and printable export strings.

    Implementation is original, designed for Lua 5.1 with bit library.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

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

LoolibCompressorMixin = {}

-- DEFLATE constants
local MAX_WINDOW_SIZE = 32768  -- 32KB sliding window
local MAX_MATCH_LENGTH = 258
local MIN_MATCH_LENGTH = 3
local MAX_DISTANCE = 32768

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

--[[--------------------------------------------------------------------
    LZ77 Compression - Find Repeated Strings
----------------------------------------------------------------------]]

local function FindLongestMatch(data, pos, windowStart, maxLen)
    local bestLength = 0
    local bestDistance = 0

    local dataLen = #data
    local searchStart = math.max(1, pos - MAX_WINDOW_SIZE)
    local maxSearchLen = math.min(maxLen, dataLen - pos + 1, MAX_MATCH_LENGTH)

    if maxSearchLen < MIN_MATCH_LENGTH then
        return 0, 0
    end

    -- Get bytes for 3-byte prefix match (avoids substring creation)
    local b1 = data:byte(pos)
    local b2 = data:byte(pos + 1)
    local b3 = data:byte(pos + 2)

    -- Need at least 3 bytes for minimum match
    if not b3 then
        return 0, 0
    end

    for searchPos = pos - 1, searchStart, -1 do
        -- Compare 3-byte prefix using bytes (zero garbage)
        local sb1 = data:byte(searchPos)
        local sb2 = data:byte(searchPos + 1)
        local sb3 = data:byte(searchPos + 2)

        if sb1 == b1 and sb2 == b2 and sb3 == b3 then
            -- Found potential match, extend it
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
    end

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

    while pos <= endPos do
        local length, distance = FindLongestMatch(data, pos, startPos, math.min(MAX_MATCH_LENGTH, endPos - pos + 1))

        if length >= MIN_MATCH_LENGTH then
            -- Write length/distance pair
            local lengthCode, lengthExtra = GetLengthCode(length)
            local distCode, distExtra = GetDistanceCode(distance)

            WriteHuffmanCode(writer, FIXED_LITERAL_TREE, lengthCode)
            if LENGTH_EXTRA_BITS[lengthCode - 256] > 0 then
                writer:WriteBits(lengthExtra, LENGTH_EXTRA_BITS[lengthCode - 256])
            end

            WriteHuffmanCode(writer, FIXED_DISTANCE_TREE, distCode)
            if DISTANCE_EXTRA_BITS[distCode + 1] > 0 then
                writer:WriteBits(distExtra, DISTANCE_EXTRA_BITS[distCode + 1])
            end

            pos = pos + length
        else
            -- Write literal byte
            WriteHuffmanCode(writer, FIXED_LITERAL_TREE, data:byte(pos))
            pos = pos + 1
        end
    end

    -- Write end of block
    WriteHuffmanCode(writer, FIXED_LITERAL_TREE, 256)
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
            local length = LENGTH_BASE[lengthIdx]
            local extraBits = LENGTH_EXTRA_BITS[lengthIdx]
            if extraBits > 0 then
                length = length + reader:ReadBits(extraBits)
            end

            local distSymbol = DecodeSymbol(reader, distTable, MAX_BITS)
            if distSymbol == nil then
                return false, "Failed to decode distance symbol"
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

        result[#result + 1] = BASE64_CHARS:sub(rshift(n, 18) + 1, rshift(n, 18) + 1)
        result[#result + 1] = BASE64_CHARS:sub(band(rshift(n, 12), 0x3F) + 1, band(rshift(n, 12), 0x3F) + 1)

        if i + 1 <= len then
            result[#result + 1] = BASE64_CHARS:sub(band(rshift(n, 6), 0x3F) + 1, band(rshift(n, 6), 0x3F) + 1)
        else
            result[#result + 1] = "="
        end

        if i + 2 <= len then
            result[#result + 1] = BASE64_CHARS:sub(band(n, 0x3F) + 1, band(n, 0x3F) + 1)
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
function LoolibCompressorMixin:Compress(str, level)
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
function LoolibCompressorMixin:Decompress(str)
    if type(str) ~= "string" then
        return nil, false
    end

    return DeflateDecompress(str)
end

--- Compress data with zlib wrapper
-- @param str string - Data to compress
-- @param level number - Compression level (0-9, default 6)
-- @return string - Compressed data with zlib header/trailer
function LoolibCompressorMixin:CompressZlib(str, level)
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
function LoolibCompressorMixin:DecompressZlib(str)
    if type(str) ~= "string" then
        return nil, false
    end

    return ZlibDecompress(str)
end

--- Encode data for safe transmission over WoW addon channels
-- @param str string - Data to encode
-- @return string - Encoded data safe for addon messages
function LoolibCompressorMixin:EncodeForAddonChannel(str)
    if type(str) ~= "string" then
        error("EncodeForAddonChannel requires string input", 2)
    end

    return EncodeForAddonChannel(str)
end

--- Decode addon channel encoded data
-- @param str string - Encoded data
-- @return string - Original data
function LoolibCompressorMixin:DecodeForAddonChannel(str)
    if type(str) ~= "string" then
        error("DecodeForAddonChannel requires string input", 2)
    end

    return DecodeForAddonChannel(str)
end

--- Encode data for printable export strings (Base64)
-- @param str string - Data to encode
-- @return string - Base64-encoded string
function LoolibCompressorMixin:EncodeForPrint(str)
    if type(str) ~= "string" then
        error("EncodeForPrint requires string input", 2)
    end

    return EncodeForPrint(str)
end

--- Decode printable export string
-- @param str string - Base64-encoded string
-- @return string - Original data
function LoolibCompressorMixin:DecodeForPrint(str)
    if type(str) ~= "string" then
        error("DecodeForPrint requires string input", 2)
    end

    return DecodeForPrint(str)
end

--- Calculate Adler-32 checksum
-- @param str string - Data to checksum
-- @return number - Adler-32 checksum
function LoolibCompressorMixin:Adler32(str)
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
function CreateLoolibCompressor()
    return LoolibCreateFromMixins(LoolibCompressorMixin)
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

LoolibCompressor = LoolibCreateFromMixins(LoolibCompressorMixin)

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local CompressorModule = {
    Mixin = LoolibCompressorMixin,
    Create = CreateLoolibCompressor,
    Compressor = LoolibCompressor,
}

Loolib:RegisterModule("Compressor", CompressorModule)

-- Also register in Comm module namespace
local Comm = Loolib:GetOrCreateModule("Comm")
Comm.Compressor = LoolibCompressor
