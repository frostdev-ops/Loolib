# Loolib Compressor

## Overview

The **Loolib Compressor** provides a complete DEFLATE compression implementation (RFC 1951) with optional zlib wrapper (RFC 1950). It's designed specifically for WoW addon development, offering data compression, channel-safe encoding, and printable export string generation.

### Key Features

- Pure Lua DEFLATE compression and decompression
- Zlib wrapper with Adler-32 checksums
- Multiple compression levels (0-9)
- Addon channel encoding (escapes problematic bytes)
- Base64 encoding for copy/paste export strings
- Zero external dependencies (uses WoW's bit library)
- LZ77 pattern matching for optimal compression ratios

### When to Use It

- Reducing addon message sizes (avoid splitting large messages)
- Creating compact export strings for sharing configurations
- Storing large data structures efficiently in SavedVariables
- Transmitting logs or combat data between raid members
- Any scenario where bandwidth or storage size matters

---

## Quick Start

```lua
-- Get the compressor
local Loolib = LibStub("Loolib")
local Compressor = Loolib:GetModule("Compressor").Compressor

-- Or use the global singleton
local Compressor = LoolibCompressor

-- Compress some data
local originalData = "This is a long string with repeating patterns. " ..
                     "This is a long string with repeating patterns."

local compressed = Compressor:CompressZlib(originalData)
print("Original:", #originalData, "bytes")   -- 94 bytes
print("Compressed:", #compressed, "bytes")   -- ~35 bytes (63% reduction)

-- Decompress it back
local decompressed, success = Compressor:DecompressZlib(compressed)
if success then
    print(decompressed == originalData)  -- true
end
```

---

## API Reference

### Compress(str, level)

Compress data using raw DEFLATE algorithm (no wrapper).

**Parameters:**
| Name | Type | Default | Description |
|------|------|---------|-------------|
| str | string | required | Data to compress |
| level | number | 6 | Compression level: 0 (store only) to 9 (maximum compression) |

**Returns:**
| Type | Description |
|------|-------------|
| string | Compressed data (DEFLATE format) |

**Example:**
```lua
local data = string.rep("Hello World! ", 100)  -- 1300 bytes
local compressed = Compressor:Compress(data, 9)
print(#compressed)  -- ~50 bytes (96% reduction)
```

**Compression Levels:**
- `0` - Store only (no compression, just copy)
- `1-9` - Fixed Huffman compression (currently all use same algorithm)
- Higher levels may use dynamic Huffman in future (currently use fixed)

---

### Decompress(str)

Decompress DEFLATE-compressed data.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| str | string | Compressed data in DEFLATE format |

**Returns:**
| Type | Description |
|------|-------------|
| string\|nil | Decompressed data (nil on failure) |
| boolean | Success flag |
| string | Error message (only if success is false) |

**Example:**
```lua
local compressed = Compressor:Compress(originalData)
local decompressed, success, err = Compressor:Decompress(compressed)

if success then
    print("Decompressed:", #decompressed, "bytes")
else
    print("Error:", err)
end
```

---

### CompressZlib(str, level)

Compress data with zlib wrapper (includes header and Adler-32 checksum).

**Parameters:**
| Name | Type | Default | Description |
|------|------|---------|-------------|
| str | string | required | Data to compress |
| level | number | 6 | Compression level (0-9) |

**Returns:**
| Type | Description |
|------|-------------|
| string | Compressed data with zlib wrapper |

**Example:**
```lua
local data = "Important configuration data..."
local compressed = Compressor:CompressZlib(data, 9)

-- Zlib format: [2-byte header][compressed data][4-byte Adler-32]
print("With wrapper:", #compressed, "bytes")  -- Adds ~6 bytes overhead
```

**Why Use Zlib Over Raw DEFLATE:**
- Checksum validation detects corruption
- Standard format compatible with external tools
- Recommended for saved variables and export strings
- Use raw DEFLATE only when every byte counts (addon messages)

---

### DecompressZlib(str)

Decompress zlib-format data with validation.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| str | string | Zlib-compressed data |

**Returns:**
| Type | Description |
|------|-------------|
| string\|nil | Decompressed data (nil on failure) |
| boolean | Success flag |
| string | Error message (only if success is false) |

**Example:**
```lua
local compressed = Compressor:CompressZlib(data)
local decompressed, success, err = Compressor:DecompressZlib(compressed)

if success then
    ProcessData(decompressed)
else
    if err:match("Checksum mismatch") then
        print("Data corrupted during transmission!")
    else
        print("Decompression error:", err)
    end
end
```

---

### EncodeForAddonChannel(str)

Encode compressed data for safe transmission over WoW addon channels.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| str | string | Data to encode (typically compressed) |

**Returns:**
| Type | Description |
|------|-------------|
| string | Encoded data safe for addon messages |

**Example:**
```lua
local serialized = Serializer:Serialize(data)
local compressed = Compressor:Compress(serialized)
local encoded = Compressor:EncodeForAddonChannel(compressed)

-- Send via addon message
Comm:SendCommMessage("MyAddon", encoded, "RAID")
```

**What It Does:**
- Escapes NULL bytes (`\000` → `\001\001`)
- Escapes escape character (`\001` → `\001\002`)
- Escapes 255 byte (`\255` → `\001\003`)
- Adds ~2-5% overhead depending on data content

**Why It's Needed:**
- WoW addon messages don't handle NULL bytes safely
- Some bytes can cause message truncation or corruption
- Required for reliable binary data transmission

---

### DecodeForAddonChannel(str)

Decode addon channel encoded data.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| str | string | Encoded data from addon channel |

**Returns:**
| Type | Description |
|------|-------------|
| string | Original data |

**Example:**
```lua
-- In message receive handler
function OnCommReceived(prefix, message, dist, sender)
    local decoded = Compressor:DecodeForAddonChannel(message)
    local decompressed, success = Compressor:Decompress(decoded)
    if success then
        local ok, data = Serializer:Deserialize(decompressed)
        -- Use data
    end
end
```

---

### EncodeForPrint(str)

Encode data as Base64 for printable export strings.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| str | string | Data to encode (typically compressed) |

**Returns:**
| Type | Description |
|------|-------------|
| string | Base64-encoded string |

**Example:**
```lua
local config = {theme = "dark", scale = 1.2, position = {x = 100, y = 200}}
local serialized = Serializer:Serialize(config)
local compressed = Compressor:CompressZlib(serialized)
local exportString = Compressor:EncodeForPrint(compressed)

print("Share this string:")
print(exportString)
-- Output: eJxLTEpJVchNzMzTLU4tKk... (can be copied/pasted)
```

**Characteristics:**
- Uses standard Base64 alphabet (A-Z, a-z, 0-9, +, /)
- Adds ~33% overhead (4 chars per 3 bytes)
- Ideal for chat, forums, or text sharing
- Whitespace-tolerant (removed during decode)

---

### DecodeForPrint(str)

Decode Base64 export strings.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| str | string | Base64-encoded string |

**Returns:**
| Type | Description |
|------|-------------|
| string | Original data |

**Example:**
```lua
-- Import configuration from user input
function ImportConfig(exportString)
    local compressed = Compressor:DecodeForPrint(exportString)
    local serialized, success = Compressor:DecompressZlib(compressed)

    if success then
        local ok, config = Serializer:Deserialize(serialized)
        if ok then
            ApplyConfig(config)
            return true
        end
    end

    return false, "Invalid import string"
end
```

**Features:**
- Automatically strips whitespace
- Handles padding characters
- Tolerant of line breaks (useful for forum posts)

---

### Adler32(str)

Calculate Adler-32 checksum.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| str | string | Data to checksum |

**Returns:**
| Type | Description |
|------|-------------|
| number | 32-bit Adler-32 checksum |

**Example:**
```lua
local data = "Test data"
local checksum = Compressor:Adler32(data)
print(string.format("Checksum: 0x%08X", checksum))  -- 0x12AB34CD

-- Verify data integrity
local received = GetDataFromNetwork()
if Compressor:Adler32(received) == expectedChecksum then
    print("Data intact")
else
    print("Data corrupted!")
end
```

**Use Cases:**
- Quick data integrity checks
- SavedVariables validation
- Custom protocols requiring checksums
- Note: Adler-32 is faster but less robust than CRC32

---

## Usage Examples

### Basic Compression

```lua
-- Simple compression example
local text = [[
Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
Ut enim ad minim veniam, quis nostrud exercitation ullamco.
]]

local compressed = Compressor:Compress(text)
local ratio = (1 - #compressed / #text) * 100

print(string.format("Original: %d bytes", #text))
print(string.format("Compressed: %d bytes", #compressed))
print(string.format("Savings: %.1f%%", ratio))

-- Output:
-- Original: 189 bytes
-- Compressed: 142 bytes
-- Savings: 24.9%
```

### Compression Levels Comparison

```lua
local data = string.rep("The quick brown fox jumps over the lazy dog. ", 50)

for level = 0, 9 do
    local start = debugprofilestop()
    local compressed = Compressor:Compress(data, level)
    local elapsed = debugprofilestop() - start

    print(string.format("Level %d: %d bytes, %.2fms",
        level, #compressed, elapsed))
end

-- Output (approximate):
-- Level 0: 2250 bytes, 0.1ms  (no compression)
-- Level 1: 185 bytes, 2.5ms   (fixed huffman)
-- Level 6: 185 bytes, 2.5ms   (currently same as level 1)
-- Level 9: 185 bytes, 2.5ms   (currently same as level 1)
```

### Addon Message Integration

```lua
local Serializer = LoolibSerializer
local Compressor = LoolibCompressor
local Comm = LoolibComm

-- Sending large data structure
function SendRaidData()
    local raidInfo = {
        members = GetRaidMembers(),  -- 40 players
        loot = GetLootHistory(),     -- 100 items
        timestamp = time()
    }

    -- Serialize -> Compress -> Encode
    local serialized = Serializer:Serialize(raidInfo)
    local compressed = Compressor:Compress(serialized)
    local encoded = Compressor:EncodeForAddonChannel(compressed)

    print(string.format("Size: %d → %d → %d bytes",
        #serialized, #compressed, #encoded))

    Comm:SendCommMessage("RaidData", encoded, "RAID")
end

-- Receiving
Comm:RegisterComm("RaidData", function(prefix, message, dist, sender)
    local decoded = Compressor:DecodeForAddonChannel(message)
    local decompressed, success = Compressor:Decompress(decoded)

    if success then
        local ok, raidInfo = Serializer:Deserialize(decompressed)
        if ok then
            ProcessRaidData(raidInfo)
        end
    end
end)
```

### Export String Generation

```lua
-- Complete export string system
function CreateExportString(config)
    -- Step 1: Serialize
    local serialized = Serializer:Serialize(config)

    -- Step 2: Compress with zlib (adds checksum)
    local compressed = Compressor:CompressZlib(serialized, 9)

    -- Step 3: Encode for printing
    local exportString = Compressor:EncodeForPrint(compressed)

    -- Step 4: Add version prefix
    return "!CFG:1:" .. exportString
end

function ImportExportString(str)
    -- Step 1: Validate prefix
    local version, data = str:match("^!CFG:(%d+):(.+)$")
    if not version or version ~= "1" then
        return nil, "Invalid or unsupported format"
    end

    -- Step 2: Decode Base64
    local compressed = Compressor:DecodeForPrint(data)

    -- Step 3: Decompress
    local serialized, success, err = Compressor:DecompressZlib(compressed)
    if not success then
        return nil, "Corrupted data: " .. err
    end

    -- Step 4: Deserialize
    local ok, config = Serializer:Deserialize(serialized)
    if not ok then
        return nil, "Invalid configuration: " .. config
    end

    return config
end

-- Usage
local config = {scale = 1.5, position = {x = 100, y = 200}}
local export = CreateExportString(config)
print(export)  -- !CFG:1:eJxLTEpJVahU...

-- Later, import it
local imported, err = ImportExportString(export)
if imported then
    ApplyConfig(imported)
else
    print("Import failed:", err)
end
```

### SavedVariables Compression

```lua
-- Compress large saved variables
function SaveCompressedData(key, data)
    local serialized = Serializer:Serialize(data)

    -- Only compress if it saves space
    if #serialized > 500 then
        local compressed = Compressor:CompressZlib(serialized)
        if #compressed < #serialized * 0.8 then  -- 20% savings threshold
            MyAddonDB[key] = {
                compressed = true,
                data = compressed
            }
            return
        end
    end

    -- Store uncompressed if small or not worth it
    MyAddonDB[key] = {
        compressed = false,
        data = serialized
    }
end

function LoadCompressedData(key)
    local saved = MyAddonDB[key]
    if not saved then return nil end

    local data
    if saved.compressed then
        local decompressed, success = Compressor:DecompressZlib(saved.data)
        if not success then return nil end
        local ok, result = Serializer:Deserialize(decompressed)
        if not ok then return nil end
        data = result
    else
        local ok, result = Serializer:Deserialize(saved.data)
        if not ok then return nil end
        data = result
    end

    return data
end
```

### Benchmarking Compression

```lua
-- Test compression on different data types
function BenchmarkCompression(data, name)
    local serialized = Serializer:Serialize(data)

    print(string.format("\n%s:", name))
    print(string.format("  Serialized: %d bytes", #serialized))

    -- Test raw DEFLATE
    local start = debugprofilestop()
    local deflate = Compressor:Compress(serialized)
    local deflateTime = debugprofilestop() - start

    -- Test zlib
    start = debugprofilestop()
    local zlib = Compressor:CompressZlib(serialized)
    local zlibTime = debugprofilestop() - start

    -- Test with encoding
    start = debugprofilestop()
    local encoded = Compressor:EncodeForAddonChannel(deflate)
    local encodeTime = debugprofilestop() - start

    print(string.format("  DEFLATE: %d bytes (%.2fms, %.1f%%)",
        #deflate, deflateTime, (1 - #deflate / #serialized) * 100))
    print(string.format("  Zlib: %d bytes (%.2fms, %.1f%%)",
        #zlib, zlibTime, (1 - #zlib / #serialized) * 100))
    print(string.format("  Encoded: %d bytes (+%.2fms)",
        #encoded, encodeTime))
end

-- Test different data patterns
BenchmarkCompression(string.rep("A", 1000), "Highly repetitive")
BenchmarkCompression(SecureRandom(1000), "Random data")
BenchmarkCompression({a = 1, b = 2, c = 3}, "Small table")
BenchmarkCompression(GetRaidData(), "Real world data")
```

---

## Best Practices

### Performance Tips

1. **Choose Appropriate Compression Level**
```lua
-- For real-time messages: use lower levels
local compressed = Compressor:Compress(data, 1)  -- Fast

-- For saved data or export strings: use higher levels
local compressed = Compressor:CompressZlib(data, 9)  -- Maximum compression
```

2. **Don't Compress Small Data**
```lua
-- Compression adds overhead for tiny data
if #data > 200 then  -- Threshold
    local compressed = Compressor:Compress(data)
    if #compressed < #data then  -- Only use if actually smaller
        SendCompressed(compressed)
    else
        SendUncompressed(data)
    end
else
    SendUncompressed(data)
end
```

3. **Reuse Singleton**
```lua
-- Good - use global singleton
local compressed = LoolibCompressor:Compress(data)

-- Wasteful - creates new instance
local compressor = CreateLoolibCompressor()
local compressed = compressor:Compress(data)
```

4. **Batch Compression**
```lua
-- Good - compress once
local batch = {item1, item2, item3}
local serialized = Serializer:Serialize(batch)
local compressed = Compressor:Compress(serialized)
SendData(compressed)

-- Bad - compress each item separately
for _, item in ipairs(items) do
    local s = Serializer:Serialize(item)
    local c = Compressor:Compress(s)  -- Poor compression ratio
    SendData(c)
end
```

### Common Mistakes to Avoid

1. **Forgetting to Check Success Flag**
```lua
-- Bad
local data = Compressor:Decompress(compressed)
print(data:sub(1, 10))  -- Crashes if decompression failed

-- Good
local data, success, err = Compressor:Decompress(compressed)
if success then
    print(data:sub(1, 10))
else
    print("Error:", err)
end
```

2. **Wrong Compression/Decompression Pairing**
```lua
-- Bad - mismatch
local compressed = Compressor:Compress(data)
local decompressed = Compressor:DecompressZlib(compressed)  -- FAIL

-- Good - match compression method
local compressed = Compressor:Compress(data)
local decompressed = Compressor:Decompress(compressed)

-- Or use zlib for both
local compressed = Compressor:CompressZlib(data)
local decompressed = Compressor:DecompressZlib(compressed)
```

3. **Encoding Already-Encoded Data**
```lua
-- Bad - double encoding
local compressed = Compressor:Compress(data)
local encoded1 = Compressor:EncodeForAddonChannel(compressed)
local encoded2 = Compressor:EncodeForAddonChannel(encoded1)  -- Wasteful!

-- Good - encode once
local compressed = Compressor:Compress(data)
local encoded = Compressor:EncodeForAddonChannel(compressed)
```

4. **Compressing Random/Encrypted Data**
```lua
-- Bad - random data doesn't compress
local random = SecureRandom(1000)
local compressed = Compressor:Compress(random)
print(#compressed >= #random)  -- true - wasted CPU

-- Good - check if data is compressible
if IsCompressible(data) then  -- Contains patterns
    compressed = Compressor:Compress(data)
end
```

### Security Considerations

1. **Validate Decompressed Size**
```lua
-- Prevent decompression bombs
local MAX_DECOMPRESSED_SIZE = 1000000  -- 1MB limit

local decompressed, success = Compressor:DecompressZlib(received)
if success then
    if #decompressed > MAX_DECOMPRESSED_SIZE then
        print("Decompressed data too large, possible attack")
        return
    end
    ProcessData(decompressed)
end
```

2. **Use Zlib for External Data**
```lua
-- Always use checksum validation for untrusted data
local imported = GetUserImportString()
local compressed = Compressor:DecodeForPrint(imported)

-- Use Zlib for checksum verification
local data, success, err = Compressor:DecompressZlib(compressed)
if not success then
    if err:match("Checksum") then
        print("Data corrupted or tampered with!")
    end
    return
end
```

3. **Rate Limit Compression Operations**
```lua
-- Prevent CPU exhaustion attacks
local compressionCount = 0
local lastReset = time()

function SafeDecompress(data)
    if time() - lastReset > 60 then
        compressionCount = 0
        lastReset = time()
    end

    compressionCount = compressionCount + 1
    if compressionCount > 100 then  -- 100 per minute
        return nil, false, "Rate limit exceeded"
    end

    return Compressor:Decompress(data)
end
```

---

## Technical Details

### DEFLATE Algorithm

The compressor implements RFC 1951 DEFLATE with these components:

**LZ77 Compression:**
- Sliding window: 32KB
- Minimum match length: 3 bytes
- Maximum match length: 258 bytes
- Maximum lookback distance: 32KB
- Byte-level comparison for zero garbage

**Huffman Coding:**
- Fixed Huffman trees (pre-defined)
- Dynamic Huffman support (future enhancement)
- 286 literal/length codes
- 30 distance codes
- Bit-level encoding

**Block Types:**
- Type 0: Stored (no compression, just copy)
- Type 1: Fixed Huffman (currently used for levels 1-9)
- Type 2: Dynamic Huffman (planned for future)

### Compression Levels

Current implementation:

| Level | Algorithm | Speed | Ratio | Use Case |
|-------|-----------|-------|-------|----------|
| 0 | Store only | Instant | 0% | Testing, already compressed |
| 1-9 | Fixed Huffman + LZ77 | Fast | 30-70% | General use |

Future enhancements will differentiate levels 1-9 with varying search depths and dynamic Huffman.

### Zlib Wrapper Format

```
[CMF][FLG][...compressed data...][ADLER32]
 1B   1B                           4B

CMF (Compression Method and Flags):
  Bits 0-3: Compression method (8 = DEFLATE)
  Bits 4-7: Window size (7 = 32KB)

FLG (Flags):
  Bits 0-4: Check bits (make CMF*256+FLG divisible by 31)
  Bit 5: Preset dictionary (0 = none)
  Bits 6-7: Compression level (0=fast, 3=max)

ADLER32: Big-endian checksum of uncompressed data
```

### Addon Channel Encoding

Escapes three problematic byte values:

```
0x00 (NULL)  → 0x01 0x01
0x01 (ESC)   → 0x01 0x02
0xFF (255)   → 0x01 0x03
```

**Overhead Analysis:**
- Best case: 0% (no escaped bytes)
- Typical: 2-3% (few NULL/255 bytes in compressed data)
- Worst case: 100% (all bytes are NULL/255, doubles size)

### Base64 Encoding

Standard Base64 alphabet with padding:

```
Alphabet: A-Z, a-z, 0-9, +, /
Padding: =
Ratio: 4 output chars per 3 input bytes (33% overhead)
```

**Example:**
```
Input:  "Man" (3 bytes)
Binary: 01001101 01100001 01101110
Split:  010011 010110 000101 101110
Index:  19     22     5      46
Output: "TWFu"
```

### Performance Benchmarks

Approximate timings on modern hardware (WoW client):

**Compression:**
```
Small (< 1KB):     0.5-2ms
Medium (1-10KB):   2-10ms
Large (10-100KB):  10-100ms
```

**Decompression:**
```
Small (< 1KB):     0.2-1ms
Medium (1-10KB):   1-5ms
Large (10-100KB):  5-50ms
```

**Encoding:**
```
Addon channel:     0.1-0.5ms per KB
Base64:            0.2-1ms per KB
```

### Compression Ratios

Real-world data patterns:

| Data Type | Typical Ratio | Example |
|-----------|---------------|---------|
| Repeated strings | 70-90% | Chat logs, item names |
| Serialized tables | 30-60% | Configuration, SavedVariables |
| Binary data | 10-30% | Already compressed formats |
| Random data | 0% or worse | Encrypted, true random |

### Memory Usage

**Compression:**
- Input buffer: n bytes (input size)
- Output buffer: ≤n bytes (worst case)
- Sliding window: 32KB
- Total: ~n + 35KB

**Decompression:**
- Input buffer: m bytes (compressed size)
- Output buffer: k bytes (original size)
- Huffman tables: ~5KB
- Total: ~m + k + 5KB

---

## Related Modules

- **Serializer** - Serialize data before compression
- **AddonMessage** - Send compressed data through addon channels
- **SavedVariables** - Store compressed configuration

---

## See Also

- [Serializer Documentation](./Serializer.md)
- [AddonMessage Documentation](./AddonMessage.md)
- [RFC 1951 - DEFLATE Specification](https://tools.ietf.org/html/rfc1951)
- [RFC 1950 - Zlib Specification](https://tools.ietf.org/html/rfc1950)
