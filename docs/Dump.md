# Loolib Dump Documentation

## Overview

The **Dump** module (`Debug/Dump.lua`) provides a comprehensive pretty-printing system for inspecting Lua values during development. It recursively formats tables, detects circular references, and limits recursion depth to prevent infinite loops and chat spam.

### Purpose

Dump makes inspecting complex data structures easy by:
- **Pretty-printing all Lua types** - Tables, functions, primitives, etc.
- **Circular reference detection** - Prevents infinite loops and marks cycles
- **Depth limiting** - Prevents overwhelming output while allowing deep inspection
- **Formatted table display** - Organized hierarchical output with proper indentation
- **Multiple inspection modes** - Full dumps, single-line summaries, or key listings

### When to Use

- **Table inspection**: Understand data structure layout and contents
- **Function testing**: Verify return values and complex outputs
- **State debugging**: Inspect addon state at specific points
- **API exploration**: Check what a function returns or what a frame contains
- **Data validation**: Verify data structures match expectations

---

## Quick Start

### Basic Usage

```lua
-- Get the Dump module
local Loolib = LibStub("Loolib")
local Dump = Loolib:GetModule("Dump")

-- Dump a simple table
local myData = {name = "Player", level = 60, health = 100}
Dump:Dump(myData)

-- Output:
-- myData = {
--   health = 100,
--   level = 60,
--   name = "Player",
-- }

-- Dump a value with a name
Dump:Dump(myData, "PlayerStats")

-- Dump without a name
Dump:Dump(myData)
```

### Depth Control

```lua
-- Default depth (5 levels)
Dump:Dump(complexObject)

-- Limited depth (2 levels, quick summary)
Dump:Dump(complexObject, "object", 2)

-- Maximum depth (10 levels, most detailed)
Dump:Dump(complexObject, "object", 10)

-- Zero depth (top level only)
Dump:Dump(complexObject, "object", 0)
```

### Quick Inspection Functions

```lua
-- Single-line dump (truncated at 100 chars)
Dump:DumpLine(myTable, "Quick summary")

-- Just list the keys
Dump:DumpKeys(myTable, "Table")
```

---

## API Reference

### Main Dump Functions

#### `Dump:Dump(value, name, maxDepth)`
**Description**: Recursively dump any Lua value to the chat frame with proper formatting.

**Parameters**:
- `value` (any): The value to dump (table, function, string, number, boolean, nil)
- `name` (string, optional): A name to display before the value
- `maxDepth` (number, optional): Maximum recursion depth (0-10, default 5)

**Returns**: None (output goes to chat frame or print if unavailable)

**Behavior**:
- Tables are formatted with indentation and sorted keys
- Functions display as `function: 0x...` format
- Circular references display as `[CIRCULAR]`
- Depth limit displays as `{...}` for tables
- String values show with quotes: `"value"`
- Numbers with decimals show 2 decimal places
- Each line of output is sent separately to the chat frame

**Example**:
```lua
local playerInfo = {
    name = "Thrall",
    level = 60,
    stats = {
        health = 1000,
        mana = 500,
        stamina = 100
    }
}

Dump:Dump(playerInfo, "PlayerInfo", 5)

-- Output:
-- PlayerInfo = {
--   level = 60,
--   name = "Thrall",
--   stats = {
--     health = 1000,
--     mana = 500,
--     stamina = 100,
--   },
-- }
```

#### `Dump:DumpLine(value, name)`
**Description**: Quick single-line dump with truncation for summary inspection.

**Parameters**:
- `value` (any): The value to dump
- `name` (string, optional): Name to display

**Returns**: None

**Behavior**:
- Uses depth limit of 2
- Truncates output to 100 characters
- Long output ends with `...`
- Good for rapid inspection without flooding chat

**Example**:
```lua
local myTable = {x = 1, y = 2, z = 3, nested = {a = 1, b = 2, c = 3}}
Dump:DumpLine(myTable, "Quick")

-- Output:
-- Quick = {nested = {...}, x = 1, y = 2, z = 3, ...}
```

#### `Dump:DumpKeys(table, name)`
**Description**: Dump only the keys of a table (useful for exploring structure).

**Parameters**:
- `table` (table): The table to inspect (required, must be a table)
- `name` (string, optional): Name to display

**Returns**: None

**Errors**: Raises error if argument is not a table

**Behavior**:
- Lists all table keys in sorted order
- Keys separated by commas
- String keys display as-is, other types as strings
- Useful for quickly understanding table structure

**Example**:
```lua
local config = {
    enabled = true,
    name = "MyConfig",
    maxRetries = 3,
    handlers = {}
}

Dump:DumpKeys(config, "Config")

-- Output:
-- Config keys: {enabled, handlers, maxRetries, name}
```

---

## Value Type Handling

### Primitives

```lua
Dump:Dump("hello world", "String")
-- Output: String = "hello world"

Dump:Dump(42, "Integer")
-- Output: Integer = 42

Dump:Dump(3.14159, "Float")
-- Output: Float = 3.14

Dump:Dump(true, "Boolean")
-- Output: Boolean = true

Dump:Dump(nil, "Null")
-- Output: Null = nil
```

### Tables

```lua
-- Empty table
Dump:Dump({}, "Empty")
-- Output: Empty = {}

-- Simple key-value table
Dump:Dump({a = 1, b = 2}, "Simple")
-- Output:
-- Simple = {
--   a = 1,
--   b = 2,
-- }

-- Nested tables
Dump:Dump({
    outer = {
        inner = {
            value = 42
        }
    }
}, "Nested", 5)
-- Output:
-- Nested = {
--   outer = {
--     inner = {
--       value = 42,
--     },
--   },
-- }
```

### Functions

```lua
Dump:Dump(function() end, "MyFunc")
-- Output: MyFunc = function: 0x7f123abc

Dump:Dump(print, "PrintFunc")
-- Output: PrintFunc = function: 0x...
```

### Numeric Keys

```lua
local array = {
    [1] = "first",
    [2] = "second",
    [3] = "third"
}

Dump:Dump(array, "Array")
-- Output:
-- Array = {
--   [1] = "first",
--   [2] = "second",
--   [3] = "third",
-- }
```

### Mixed Keys

```lua
local mixed = {
    "item1",
    name = "MyTable",
    [42] = "answer",
    subTable = {x = 1}
}

Dump:Dump(mixed, "Mixed", 3)
-- Output:
-- Mixed = {
--   [1] = "item1",
--   [42] = "answer",
--   name = "MyTable",
--   subTable = {
--     x = 1,
--   },
-- }
```

---

## Circular Reference Handling

### Detecting Circular References

```lua
-- Create a circular reference
local a = {value = 1}
local b = {parent = a}
a.child = b  -- Now a.child points back to b which points back to a

Dump:Dump(a, "CircularRef", 5)
-- Output:
-- CircularRef = {
--   child = {
--     parent = [CIRCULAR],
--   },
--   value = 1,
-- }
```

### Self-Referencing Tables

```lua
-- A table that refers to itself
local selfRef = {name = "SelfRef"}
selfRef.me = selfRef

Dump:Dump(selfRef, "SelfRef", 3)
-- Output:
-- SelfRef = {
--   me = [CIRCULAR],
--   name = "SelfRef",
-- }
```

### Complex Cycles

```lua
-- Deep circular structure
local root = {type = "root"}
local child = {parent = root, siblings = {}}
root.child = child
table.insert(child.siblings, root)

Dump:Dump(root, "ComplexCycle", 5)
-- Output shows [CIRCULAR] where cycles would occur
```

---

## Depth Limiting

### Understanding Depth Limits

```lua
local deep = {
    level1 = {
        level2 = {
            level3 = {
                level4 = {
                    level5 = {
                        level6 = "Bottom"
                    }
                }
            }
        }
    }
}

-- Depth 1: Shows only 1 level
Dump:Dump(deep, "Depth1", 1)
-- Output:
-- Depth1 = {
--   level1 = {...},
-- }

-- Depth 3: Shows up to 3 levels
Dump:Dump(deep, "Depth3", 3)
-- Output:
-- Depth3 = {
--   level1 = {
--     level2 = {
--       level3 = {...},
--     },
--   },
-- }

-- Depth 10: Shows all (max is 10)
Dump:Dump(deep, "Depth10", 10)
-- Output: Full structure shown
```

### Default Depth (5 levels)

```lua
-- These are equivalent
Dump:Dump(myTable, "Name")
Dump:Dump(myTable, "Name", 5)
Dump:Dump(myTable, "Name", nil)
```

### Zero Depth

```lua
-- Depth 0: Only shows table structure, no contents
Dump:Dump({a = 1, b = 2, c = 3}, "Empty", 0)
-- Output:
-- Empty = {...}
```

---

## Usage Examples

### Example 1: Exploring Frame Structure

```lua
local Loolib = LibStub("Loolib")
local Dump = Loolib:GetModule("Dump")

-- Inspect a UI frame
local frame = CreateFrame("Frame", "MyFrame", UIParent)
frame.customField = "test"

Dump:DumpKeys(frame, "FrameStructure")
-- Output shows all frame properties and custom fields

-- Dump specific depth to see important properties
Dump:Dump(frame, "FrameDetails", 2)
```

### Example 2: Debugging Table Data Structure

```lua
local Dump = Loolib:GetModule("Dump")

local playerData = {
    character = {
        name = "Arthas",
        level = 60,
        class = "DEATHKNIGHT",
        stats = {
            strength = 50,
            agility = 30,
            stamina = 60,
            intellect = 20,
            wisdom = 25,
            constitution = 55
        }
    },
    items = {
        {id = 1, name = "Sword", rarity = "epic"},
        {id = 2, name = "Shield", rarity = "rare"},
        {id = 3, name = "Boots", rarity = "common"}
    },
    spells = {}
}

-- Full inspection
Dump:Dump(playerData, "PlayerData", 5)

-- Quick look at structure
Dump:DumpLine(playerData, "Player Quick")

-- Just see what's available
Dump:DumpKeys(playerData, "PlayerData")
```

### Example 3: Event Payload Inspection

```lua
local Dump = Loolib:GetModule("Dump")
local Events = Loolib:GetModule("Events")

-- Inspect event payloads
Events.Registry:RegisterFrameEventAndCallback("PLAYER_TARGET_CHANGED", function(payload)
    Dump:Dump(payload, "TargetChanged", 3)
end)

-- Event payload structure will be displayed each time event fires
```

### Example 4: API Return Value Inspection

```lua
local Dump = Loolib:GetModule("Dump")

-- Inspect what an API function returns
local result = C_Map.GetBestMapForUnit("player")
Dump:Dump(result, "MapResult")

-- Inspect UnitAuras structure
local auras = C_UnitAuras.GetAuraDataByIndex("player", 1)
Dump:Dump(auras, "AuraData", 3)
```

### Example 5: Configuration Validation

```lua
local Dump = Loolib:GetModule("Dump")

local config = LoadConfiguration()

-- Verify structure
Dump:Dump(config, "LoadedConfig", 4)

-- Check for expected keys
Dump:DumpKeys(config, "Config")

-- Quick summary
Dump:DumpLine(config, "ConfigSummary")
```

### Example 6: Comparing Structures

```lua
local Dump = Loolib:GetModule("Dump")

-- Before modification
local before = {name = "Old", value = 1, nested = {x = 0}}
Dump:Dump(before, "Before", 2)

-- After modification
local after = {name = "New", value = 2, nested = {x = 0, y = 1}}
Dump:Dump(after, "After", 2)

-- Compare visually to see differences
```

### Example 7: Iterative Development with Depth Control

```lua
local Dump = Loolib:GetModule("Dump")

local complexObject = LoadComplexData()

-- Stage 1: Quick look at structure
Dump:DumpLine(complexObject, "Step1")

-- Stage 2: One more level
Dump:Dump(complexObject, "Step2", 2)

-- Stage 3: Full depth for specific investigation
Dump:Dump(complexObject, "Step3", 5)

-- Stage 4: Maximum depth when needed
Dump:Dump(complexObject, "Step4", 10)
```

---

## Best Practices

### Development Workflow

**Progressively deeper inspection:**
```lua
local Dump = Loolib:GetModule("Dump")
local data = GetComplexData()

-- Start with key overview
Dump:DumpKeys(data, "Overview")

-- If needed, one-line summary
Dump:DumpLine(data, "Summary")

-- If still needed, structured view
Dump:Dump(data, "Full", 3)

-- Only if really needed, maximum detail
Dump:Dump(data, "Detailed", 10)
```

### Debugging Performance Issues

```lua
local Dump = Loolib:GetModule("Dump")

-- Use DumpLine for frequent inspection
Dump:DumpLine(largeTable, "State")  -- Won't flood chat

-- Use Dump with limited depth for structure
Dump:Dump(largeTable, "Structure", 2)
```

### Avoiding Circular Reference Traps

```lua
-- The Dump module handles this automatically
-- But be aware that circular references will show as [CIRCULAR]

local cache = {}
table.insert(cache, cache)  -- Self-reference

Dump:Dump(cache, "SelfRefCache")
-- Safely displays without hanging
```

### Type-Specific Strategies

**For investigating tables with many keys:**
```lua
local Dump = Loolib:GetModule("Dump")

-- First, see what keys exist
Dump:DumpKeys(bigTable, "Available")

-- Then inspect specific keys
Dump:Dump({value = bigTable.interestingKey}, "Specific", 3)
```

**For exploring nested structures:**
```lua
-- Use depth limiting to focus on relevant levels
Dump:Dump(nestedData, "Level1", 1)  -- What's at top?
Dump:Dump(nestedData, "Level2", 2)  -- What's inside?
Dump:Dump(nestedData, "Level3", 3)  -- Go deeper if needed
```

**For monitoring object changes:**
```lua
-- Compare before and after
Dump:DumpLine(state, "Before")
ModifyState()
Dump:DumpLine(state, "After")
```

---

## Output Formatting

### Key Sorting

Keys are sorted by:
1. **Type**: String keys first, then numbers, then others
2. **Value**: Within same type, sorted by value

```lua
local mixed = {
    "item",
    z = "last",
    [10] = "ten",
    a = "first",
    [1] = "one"
}

Dump:Dump(mixed, "Sorted")
-- Output shows keys in sorted order:
-- a, z (strings)
-- [1], [10] (numbers)
-- [1] (array item)
```

### Indentation

- 2 spaces per depth level
- Nested tables indented properly
- Closing braces aligned with opening

```lua
-- Depth visualized through indentation
{
  level1 = {
    level2 = {
      level3 = {
        value = 1,
      },
    },
  },
}
```

### String Representation

```lua
-- Strings quoted
Dump:Dump("text", "str")
-- Output: str = "text"

-- Numbers with decimals to 2 places
Dump:Dump(3.14159, "pi")
-- Output: pi = 3.14

-- Integers as-is
Dump:Dump(42, "answer")
-- Output: answer = 42

-- Booleans lowercase
Dump:Dump(true, "flag")
-- Output: flag = true

-- Nil as nil
Dump:Dump(nil, "empty")
-- Output: empty = nil
```

---

## Performance Considerations

### When to Limit Depth

```lua
-- For large/complex objects, use limited depth
local hugeTable = LoadLargeDataset()

-- Good: Limited output
Dump:Dump(hugeTable, "Data", 2)

-- Risky: Might generate huge output
Dump:Dump(hugeTable, "Data", 10)

-- Better: Keys first
Dump:DumpKeys(hugeTable, "Keys")
```

### Circular Reference Performance

The Dump module uses a visitor pattern that efficiently detects circular references without infinite loops:

```lua
-- Safe even with circular references
local circular = {}
circular.self = circular

Dump:Dump(circular)
-- Completes instantly, marks as [CIRCULAR]
```

### Chat Frame Limits

Each line is sent separately to the chat frame:

```lua
-- Large tables might generate many lines
-- But each is handled independently
Dump:Dump(veryLargeTable, "Big", 5)
```

---

## Troubleshooting

### Output Not Visible

**Problem**: Dump output doesn't appear in chat
- **Solution**: Check if `DEFAULT_CHAT_FRAME` exists
  ```lua
  if DEFAULT_CHAT_FRAME then
      Dump:Dump(data, "Test")
  end
  ```

### Truncated Output in DumpLine

**Problem**: Important information cut off at 100 characters
- **Solution**: Use `Dump:Dump()` with appropriate depth
  ```lua
  Dump:DumpLine(data, "Quick")     -- Truncated
  Dump:Dump(data, "Full", 3)       -- Complete
  ```

### Overwhelming Output

**Problem**: Too many lines in chat after dumping large table
- **Solution**: Reduce depth or use DumpKeys
  ```lua
  Dump:Dump(table, "Data", 1)      -- Top level only
  Dump:DumpKeys(table, "Table")    -- Keys only
  ```

### [CIRCULAR] Appearing Unexpectedly

**Problem**: Getting [CIRCULAR] when no cycle should exist
- **Diagnosis**: The Dump module is protecting against actual circular references
  ```lua
  -- This is not a bug, it's correct behavior
  -- The table truly references itself or has a cycle
  ```

### Functions Showing as Addresses

**Problem**: Want to see function names instead of addresses
- **Note**: Lua functions don't carry name information in the function object
- **Solution**: Provide context in the dump name:
  ```lua
  Dump:Dump(myFunction, "MyCallback")
  -- Better identifies what the function is for
  ```

---

## Quick Reference

| Function | Use Case | Example |
|----------|----------|---------|
| `Dump:Dump()` | Full inspection | `Dump:Dump(table, "Name", 5)` |
| `DumpLine()` | Quick overview | `Dump:DumpLine(table, "Quick")` |
| `DumpKeys()` | Structure exploration | `Dump:DumpKeys(table, "Keys")` |

| Feature | Behavior |
|---------|----------|
| Circular Refs | Marked as `[CIRCULAR]` |
| Depth Limit | Shows `{...}` at max depth |
| Max Depth | 10 levels (configurable) |
| Default Depth | 5 levels |
| Key Sorting | Type then value |
| Indentation | 2 spaces per level |
| Strings | Quoted `"value"` |
| Numbers | Decimals to 2 places |
| Functions | `function: 0x...` |
