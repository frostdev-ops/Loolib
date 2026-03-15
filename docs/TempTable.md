# LoolibTempTable

Memory-efficient temporary table pooling for WoW addons. Reduces garbage collection pressure by recycling table allocations.

## Overview

### Purpose and Features

LoolibTempTable provides:
- **Table Pooling**: Reuse tables instead of creating/destroying them repeatedly
- **Leak Detection**: Track acquired tables and report unreleased ones with stack traces
- **Use-after-release Protection**: Metatable guards prevent accidental access to released tables
- **Auto-wipe**: Released tables are fully wiped before returning to the pool

### When to Use

Use TempTable when you need short-lived tables in hot paths:
- Building temporary argument lists for function calls
- Accumulating batch data that is processed and discarded
- Avoiding GC pressure in per-frame or per-event handlers
- Any acquire-use-release pattern where table lifetime is bounded

## Quick Start

```lua
local Loolib = LibStub("Loolib")
local TempTable = Loolib:GetModule("Core.TempTable")
-- or: local TempTable = Loolib.TempTable

-- Basic acquire/release
local t = TempTable:Acquire()
t.foo = "bar"
t[1] = 42
-- ... use t ...
TempTable:Release(t)
-- t is now poisoned; any access will error

-- Acquire with initial values
local t2 = TempTable:Acquire({ a = 1, b = 2 })
TempTable:Release(t2)

-- Acquire with array values
local t3 = TempTable:AcquireWithValues("x", "y", "z")
-- t3 == { [1]="x", [2]="y", [3]="z" }
TempTable:Release(t3)

-- Unpack and release in one call
local a, b, c = TempTable:UnpackAndRelease(
    TempTable:AcquireWithValues(10, 20, 30)
)
-- a=10, b=20, c=30; table already released
```

## API Reference

### Core Functions

#### Acquire(init)
Acquire a clean table from the pool (or create a new one if the pool is empty).

**Parameters:**
- `init` (table|nil) - Optional table whose key/value pairs are copied into the acquired table

**Returns:**
- `table` - A clean, tracked table ready for use

**Errors:**
- If `init` is provided but is not a table

**Example:**
```lua
local t = TempTable:Acquire()
local t2 = TempTable:Acquire({ key = "value" })
```

#### Release(t)
Return a table to the pool. The table is wiped and poisoned with a protection metatable.

**Parameters:**
- `t` (table) - The table to release

**Errors:**
- If `t` is not a table
- If `t` has already been released (double-release detection)

**Important:** After calling Release, any read/write/iterate/length operation on the table will raise an error. This catches use-after-release bugs immediately.

**Example:**
```lua
local t = TempTable:Acquire()
t.data = ComputeSomething()
ProcessData(t)
TempTable:Release(t)
-- t is now poisoned
```

#### UnpackAndRelease(t)
Unpack all array values from a table, then release it. Convenience for single-expression acquire-use patterns.

**Parameters:**
- `t` (table) - The table to unpack and release

**Returns:**
- `...` - The unpacked array values (indices 1 through #t)

**Errors:**
- If `t` is not a table
- If `t` has already been released

**Example:**
```lua
local x, y = TempTable:UnpackAndRelease(
    TempTable:AcquireWithValues(100, 200)
)
```

#### AcquireWithValues(...)
Acquire a table and populate it with the provided values as an array.

**Parameters:**
- `...` - Values to store at indices 1, 2, 3, ...

**Returns:**
- `table` - A table containing the values

**Example:**
```lua
local args = TempTable:AcquireWithValues("RAID", "ALERT", playerName)
SendMessage(unpack(args, 1, 3))
TempTable:Release(args)
```

### Debug Functions

#### GetStats()
Get current pool statistics.

**Returns:**
- `number` - Current number of tables in the pool
- `number` - Current number of acquired (outstanding) tables
- `number` - Maximum pool size (100)

**Example:**
```lua
local pooled, outstanding, max = TempTable:GetStats()
print(string.format("Pool: %d/%d, Outstanding: %d", pooled, max, outstanding))
```

#### GetLeaks()
Get a snapshot of all currently acquired tables and their acquisition stack traces.

**Returns:**
- `table` - Map of `{[table] = stackTrace}` for all outstanding tables

**Note:** Only populated when leak warnings are enabled (default: on).

#### PrintLeaks()
Print leak information to the chat frame. Shows up to 5 leak stack traces.

**Usage:**
```lua
/run Loolib.TempTable:PrintLeaks()
```

**Output examples:**
- `[Loolib TempTable] No leaked tables` (all clean)
- `[Loolib TempTable] 3 leaked table(s):` followed by stack traces
- `[Loolib TempTable] Leak tracking is disabled` (if warnings are off)

#### SetLeakWarnings(enabled)
Enable or disable leak tracking. When disabled, the `acquired` tracking table is cleared and no stack traces are captured on Acquire.

**Parameters:**
- `enabled` (boolean) - true to enable, false to disable

**Note:** Disabling leak warnings slightly improves Acquire/Release performance by skipping `debugstack()` calls. Recommended for production; keep enabled during development.

#### ClearPool()
Clear all pooled tables. For testing/debugging only.

**Note:** This does not affect currently acquired tables. Only empties the free pool.

## Pool Mechanics

### Capacity

The pool holds up to 100 recycled tables. Tables released when the pool is full are left for the garbage collector.

### Protection Metatable

Released tables receive a metatable that errors on:
- `__index` (read access)
- `__newindex` (write access)
- `__pairs` / `__ipairs` (iteration)
- `__len` (# operator)
- `__tostring` (returns `"LoolibTempTable(released)"`)

This metatable is removed when the table is re-acquired.

### Lifecycle

```
Acquire() -> table leaves pool (or is created fresh)
           -> metatable cleared
           -> tracking entry added (if leak warnings on)
           -> init values copied (if provided)
           -> returned to caller

Release() -> type + double-release check
           -> tracking entry removed
           -> metatable cleared (user metatables)
           -> wipe(t)
           -> if pool not full: pushed to pool + protection metatable set
           -> if pool full: table abandoned to GC
```

## Best Practices

### 1. Always Release

Every `Acquire` must have a matching `Release`. Use `/run Loolib.TempTable:PrintLeaks()` to verify.

### 2. Release in All Exit Paths

```lua
local t = TempTable:Acquire()
if not someCondition then
    TempTable:Release(t)  -- Don't forget early returns!
    return
end
ProcessData(t)
TempTable:Release(t)
```

### 3. Don't Store References After Release

```lua
local t = TempTable:Acquire()
local ref = t  -- ref will be poisoned after release
TempTable:Release(t)
-- ref.foo  -- ERROR: attempted to read from a released TempTable
```

### 4. Use UnpackAndRelease for One-Shot Patterns

```lua
-- DO: single expression, no leak risk
local a, b = TempTable:UnpackAndRelease(TempTable:AcquireWithValues(1, 2))

-- DON'T: manual unpack risks forgetting release
local t = TempTable:AcquireWithValues(1, 2)
local a, b = unpack(t)
-- forgot TempTable:Release(t) -- LEAK
```

### 5. Don't Set Metatables on Acquired Tables

The pool manages metatables internally. Setting your own metatable on an acquired table is safe (it will be cleared on release), but avoid it if possible.

## Troubleshooting

### "attempted to read from a released TempTable"

You are using a table reference after calling Release(). Check that no other code path holds a reference to the released table.

### "attempted to release an already-released TempTable"

Double-release detected. Check that your Release call isn't inside a loop or called from multiple cleanup paths.

### Leak count keeps growing

Run `TempTable:PrintLeaks()` to see stack traces of unreleased tables. Common causes:
- Early return without Release
- Error thrown between Acquire and Release (use pcall if needed)
- Storing acquired table in a long-lived data structure without releasing

## API Summary

| Function | Returns | Purpose |
|----------|---------|---------|
| `Acquire(init)` | table | Get a table from the pool |
| `Release(t)` | - | Return a table to the pool |
| `UnpackAndRelease(t)` | ... | Unpack array values and release |
| `AcquireWithValues(...)` | table | Acquire pre-populated with values |
| `GetStats()` | number, number, number | Pool size, outstanding, max |
| `GetLeaks()` | table | Map of leaked tables to stacks |
| `PrintLeaks()` | - | Print leak report to chat |
| `SetLeakWarnings(enabled)` | - | Toggle leak tracking |
| `ClearPool()` | - | Empty the free pool |
