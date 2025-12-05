# Loolib Serializer

## Overview

The **Loolib Serializer** provides AceSerializer-compatible protocol for converting Lua values to strings and back. It enables safe transmission of complex data structures through WoW's addon communication channels, saved variables, or any system requiring string representation of data.

### Key Features

- Serializes tables, strings, numbers, booleans, and nil values
- Circular reference detection prevents infinite loops
- Zero-garbage parsing for optimal performance
- Protocol version validation ensures compatibility
- Escape sequences handle control characters safely
- Supports special numeric values (infinity, negative infinity)

### When to Use It

- Sending complex data structures through addon messages
- Storing structured configuration in SavedVariables
- Creating export strings for sharing data between players
- Transmitting nested tables with mixed data types
- Any scenario requiring string representation of Lua values

---

## Quick Start

```lua
-- Get the serializer
local Loolib = LibStub("Loolib")
local Serializer = Loolib:GetModule("Serializer").Serializer

-- Or use the global singleton
local Serializer = LoolibSerializer

-- Serialize some data
local data = {
    name = "Thunderfury",
    itemLevel = 397,
    stats = {strength = 50, stamina = 75},
    equipped = true
}

local serialized = Serializer:Serialize(data)

-- Deserialize it back
local success, restored = Serializer:Deserialize(serialized)
if success then
    print(restored.name)  -- "Thunderfury"
    print(restored.stats.strength)  -- 50
end
```

---

## API Reference

### Serialize(...)

Serialize one or more Lua values into a single string.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| ... | any | One or more values to serialize (tables, strings, numbers, booleans, nil) |

**Returns:**
| Type | Description |
|------|-------------|
| string | The serialized representation with protocol header |

**Example:**
```lua
-- Single value
local str = Serializer:Serialize({gold = 1000, silver = 50})

-- Multiple values (preserves order)
local str = Serializer:Serialize("PlayerName", 60, true, {class = "WARRIOR"})
```

**Error Conditions:**
- Throws error if attempting to serialize unsupported types (functions, userdata, threads)
- Throws error if circular reference detected in table

---

### Deserialize(str)

Deserialize a string back into the original Lua values.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| str | string | The serialized string (must include protocol header) |

**Returns:**
| Type | Description |
|------|-------------|
| boolean | Success flag (true if deserialization succeeded) |
| any... | The deserialized values (in original order) |

**Example:**
```lua
local serialized = Serializer:Serialize("PlayerName", 60, {class = "WARRIOR"})
local success, name, level, info = Serializer:Deserialize(serialized)

if success then
    print(name)  -- "PlayerName"
    print(level)  -- 60
    print(info.class)  -- "WARRIOR"
else
    print("Deserialization failed:", name)  -- name contains error message
end
```

**Error Conditions:**
Returns `false` plus error message if:
- Input is not a string
- Input is too short (less than 2 bytes)
- Missing or invalid protocol header
- Unsupported protocol version
- Invalid type tags in serialized data
- Malformed data structure

---

## Usage Examples

### Basic Serialization

```lua
-- Serialize a simple table
local config = {
    volume = 0.75,
    showMinimap = true,
    position = {x = 100, y = 200}
}

local serialized = Serializer:Serialize(config)
print("Serialized:", serialized)
-- Output: ^1^T^Svolume^F0.75^f^SshowMinimap^B^Sposition^T^Sx^N100^Sy^N200^t^t
```

### Multiple Values

```lua
-- Serialize multiple values in one call
local player = "Ragnaros-Thunderfury"
local level = 80
local gold = 125000

local data = Serializer:Serialize(player, level, gold)

-- Deserialize returns them in order
local success, p, l, g = Serializer:Deserialize(data)
print(p, l, g)  -- "Ragnaros-Thunderfury" 80 125000
```

### Nested Tables

```lua
-- Deep nesting is fully supported
local guild = {
    name = "Legends",
    members = {
        {name = "Player1", rank = 0, level = 80},
        {name = "Player2", rank = 1, level = 78},
        {name = "Player3", rank = 2, level = 75}
    },
    bank = {
        gold = 1000000,
        tabs = {
            {name = "Consumables", items = 98},
            {name = "Gear", items = 42}
        }
    }
}

local serialized = Serializer:Serialize(guild)
local success, restored = Serializer:Deserialize(serialized)

if success then
    print(restored.members[1].name)  -- "Player1"
    print(restored.bank.tabs[1].items)  -- 98
end
```

### Special Numeric Values

```lua
-- Infinity and negative infinity are preserved
local data = {
    maxDamage = math.huge,
    minResist = -math.huge,
    normalValue = 42.5
}

local serialized = Serializer:Serialize(data)
local success, restored = Serializer:Deserialize(serialized)

print(restored.maxDamage == math.huge)  -- true
print(restored.minResist == -math.huge)  -- true
```

### Handling Nil Values

```lua
-- nil values are preserved in multi-value serialization
local serialized = Serializer:Serialize("first", nil, "third")
local success, a, b, c = Serializer:Deserialize(serialized)

print(a)  -- "first"
print(b)  -- nil
print(c)  -- "third"

-- nil in tables is handled correctly
local tbl = {a = 1, b = nil, c = 3}
local ser = Serializer:Serialize(tbl)
local ok, result = Serializer:Deserialize(ser)
-- b will not exist in result (Lua table behavior)
```

### Error Handling

```lua
-- Always check success flag
local data = "^1^T^S" -- Incomplete/malformed data
local success, result = Serializer:Deserialize(data)

if not success then
    print("Error:", result)  -- result contains error message
else
    -- Process result safely
    ProcessData(result)
end
```

### Integration with Addon Messages

```lua
local Comm = Loolib:GetModule("AddonMessage").Comm
local Serializer = LoolibSerializer

-- Send complex data structure
local raidLoot = {
    item = 192988,
    winner = "PlayerName",
    timestamp = time(),
    roll = 95
}

local serialized = Serializer:Serialize(raidLoot)
Comm:SendCommMessage("MyAddon", serialized, "RAID")

-- Receive and deserialize
Comm:RegisterComm("MyAddon", function(prefix, message, dist, sender)
    local success, loot = Serializer:Deserialize(message)
    if success then
        print(sender, "won item", loot.item, "with roll", loot.roll)
    end
end)
```

### Integration with Compressor

```lua
local Serializer = LoolibSerializer
local Compressor = LoolibCompressor

-- Serialize then compress for efficient transmission
local largeData = {
    -- ... lots of data ...
}

local serialized = Serializer:Serialize(largeData)
local compressed = Compressor:CompressZlib(serialized)
local encoded = Compressor:EncodeForAddonChannel(compressed)

-- Send encoded data...

-- Receive and reverse the process
local decoded = Compressor:DecodeForAddonChannel(encoded)
local decompressed, success = Compressor:DecompressZlib(decoded)
if success then
    local ok, data = Serializer:Deserialize(decompressed)
    if ok then
        -- Use data
    end
end
```

---

## Best Practices

### Performance Tips

1. **Reuse the Singleton**: Use the global `LoolibSerializer` instead of creating new instances
```lua
-- Good
local str = LoolibSerializer:Serialize(data)

-- Unnecessary overhead
local ser = CreateLoolibSerializer()
local str = ser:Serialize(data)
```

2. **Avoid Circular References**: Design data structures to prevent cycles
```lua
-- Bad - circular reference
local a = {name = "A"}
local b = {name = "B", ref = a}
a.ref = b
Serializer:Serialize(a)  -- ERROR: Circular reference

-- Good - use IDs instead
local a = {id = 1, name = "A"}
local b = {id = 2, name = "B", refId = 1}
```

3. **Minimize Serialization Calls**: Serialize once and cache if sending to multiple targets
```lua
-- Good
local serialized = Serializer:Serialize(config)
for _, player in ipairs(guildMembers) do
    SendToPlayer(player, serialized)
end

-- Bad - redundant serialization
for _, player in ipairs(guildMembers) do
    local serialized = Serializer:Serialize(config)  -- Wasteful
    SendToPlayer(player, serialized)
end
```

4. **Use Compression for Large Data**: Combine with Compressor for data > 500 bytes
```lua
local serialized = Serializer:Serialize(largeTable)
if #serialized > 500 then
    serialized = Compressor:CompressZlib(serialized)
end
```

### Common Mistakes to Avoid

1. **Not Checking Success Flag**
```lua
-- Bad
local success, data = Serializer:Deserialize(str)
print(data.value)  -- Crashes if deserialization failed

-- Good
local success, data = Serializer:Deserialize(str)
if success then
    print(data.value)
else
    print("Error:", data)  -- data is error message
end
```

2. **Attempting to Serialize Functions**
```lua
-- Bad - will error
local tbl = {
    data = 123,
    callback = function() end  -- ERROR
}
Serializer:Serialize(tbl)

-- Good - serialize data only
local tbl = {
    data = 123,
    callbackId = "OnItemReceived"  -- Store ID, not function
}
```

3. **Forgetting Protocol Overhead**
```lua
-- The serialized string is always longer than raw data
local original = "test"  -- 4 bytes
local serialized = Serializer:Serialize(original)
print(#serialized)  -- ~9 bytes (^1^Stest)

-- Account for this when checking message size limits
local MAX_SIZE = 255
local margin = 50  -- Reserve for protocol overhead
if #rawData < MAX_SIZE - margin then
    local serialized = Serializer:Serialize(rawData)
end
```

4. **Mixing Different Serialization Formats**
```lua
-- Bad - can't deserialize data from other serializers
local aceData = AceSerializer:Serialize(data)
Serializer:Deserialize(aceData)  -- May fail on version check

-- Good - use consistent serialization within your addon
-- If receiving from external source, detect format first
```

### Security Considerations

1. **Validate Deserialized Data**: Never trust deserialized data from other players
```lua
local success, config = Serializer:Deserialize(receivedData)
if success then
    -- Validate before use
    if type(config.itemLevel) == "number" and
       config.itemLevel >= 1 and
       config.itemLevel <= 1000 then
        ApplyConfig(config)
    else
        print("Invalid data from", sender)
    end
end
```

2. **Sanitize Before Display**: Deserialized strings may contain malicious content
```lua
local success, data = Serializer:Deserialize(message)
if success and type(data.note) == "string" then
    -- Escape or sanitize before displaying
    local safe = data.note:gsub("|", "||")  -- Escape WoW UI codes
    print(safe)
end
```

3. **Size Limits**: Implement maximum size checks to prevent memory attacks
```lua
local MAX_SERIALIZED_SIZE = 10000  -- 10KB limit

if #receivedMessage > MAX_SERIALIZED_SIZE then
    print("Message too large, ignoring")
    return
end

local success, data = Serializer:Deserialize(receivedMessage)
```

---

## Technical Details

### Protocol Format

The serializer uses a text-based protocol with type tags prefixed by `^` (caret):

```
^1                  -- Protocol version header
^Svalue            -- String: ^S followed by content
^N123              -- Integer number: ^N followed by digits
^F3.14^f           -- Float: ^F followed by value, terminated by ^f
^B                 -- Boolean true
^b                 -- Boolean false
^Z                 -- Nil value
^I                 -- Positive infinity (math.huge)
^i                 -- Negative infinity (-math.huge)
^T...^t            -- Table: ^T starts, ^t ends, contains key-value pairs
```

**Example:**
```lua
-- Input: {name = "Test", level = 60}
-- Output: ^1^T^Sname^STest^Slevel^N60^t
--         ^1       - Protocol version
--         ^T       - Table start
--         ^Sname   - String key "name"
--         ^STest   - String value "Test"
--         ^Slevel  - String key "level"
--         ^N60     - Number value 60
--         ^t       - Table end
```

### Control Character Escaping

Control bytes `\001` through `\004` and `^` are escaped to prevent conflicts:

| Character | Escaped As | Reason |
|-----------|------------|--------|
| `\001` | `\001\001` | Message splitting control byte |
| `\002` | `\001\002` | Message splitting control byte |
| `\003` | `\001\003` | Message splitting control byte |
| `\004` | `\001\004` | Message splitting control byte |
| `^` | `\001\005` | Protocol marker character |

### Performance Characteristics

**Serialization:**
- Time complexity: O(n) where n is number of values in structure
- Space complexity: O(n) for output buffer
- Zero-garbage design minimizes allocations
- Tables are visited once (no redundant traversal)

**Deserialization:**
- Time complexity: O(m) where m is serialized string length
- Space complexity: O(k) where k is number of values
- Byte-level parsing avoids string creation until necessary
- Single-pass algorithm for optimal speed

**Typical Performance:**
```lua
-- Small data (< 100 values): < 0.1ms
local start = debugprofilestop()
local ser = Serializer:Serialize(smallTable)
local elapsed = debugprofilestop() - start
print(elapsed)  -- ~0.05ms

-- Medium data (1000 values): ~1-2ms
-- Large data (10000 values): ~10-20ms
```

### Circular Reference Detection

The serializer maintains a tracking table during serialization to detect cycles:

```lua
-- This is detected and raises an error
local a = {}
local b = {child = a}
a.parent = b  -- Creates cycle
Serializer:Serialize(a)  -- ERROR: Circular reference detected
```

The tracking table is cleared after each `Serialize()` call, so separate serializations won't interfere.

### Compatibility Notes

**Protocol Version:** Currently version `1`
- Version validation ensures forward/backward compatibility
- Different versions will fail deserialization with clear error
- Update version when making breaking protocol changes

**Lua 5.1 Compatibility:**
- Uses `unpack()` instead of `table.unpack()`
- Compatible with WoW's Lua environment
- No external dependencies beyond LibStub

**Type Limitations:**
- Functions: Not serializable (design limitation)
- Userdata: Not serializable (C objects can't be converted)
- Threads: Not serializable (coroutines are runtime-specific)
- Metatables: Not preserved (only raw table data)

---

## Related Modules

- **Compressor** - Compress serialized data for efficient transmission
- **AddonMessage** - Send serialized data through addon channels
- **SavedVariables** - Store serialized configuration (though tables can be saved directly)

---

## See Also

- [Compressor Documentation](./Compressor.md)
- [AddonMessage Documentation](./AddonMessage.md)
- [LibStub Documentation](https://www.wowace.com/projects/libstub)
