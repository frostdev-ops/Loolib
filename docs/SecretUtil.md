# SecretUtil Module

The SecretUtil module provides detection and safe handling of WoW 12.0 "secret values" -- opaque Lua values returned by unit APIs on tainted execution paths during combat.

## Overview

### What It Does

WoW 12.0 introduced secret values: opaque handles returned by APIs like `UnitName`, `UnitClass`, `GetRaidRosterInfo`, and `GetPlayerInfoByGUID` when called from tainted code during combat. Any operation on a secret value (comparison, `string.find()`, `#`, table key usage) raises a Lua error. The global `issecretvalue(value)` detects them.

SecretUtil provides:
- Core detection functions to check and sanitize secret values
- Safe wrappers for common unit APIs that return nil instead of secrets
- Full backward compatibility with pre-12.0 clients (all functions early-return raw API results when `issecretvalue` is nil)

### Common Use Cases

- **Player name resolution**: Safely get player names during combat without risking taint errors
- **Raid roster iteration**: Iterate raid members and handle secret returns gracefully
- **Debug output**: Safely print values that may be secrets
- **GUID lookups**: Safely query player info by GUID during tainted execution

### Key Features

- **Pre-12.0 compatible**: All functions work transparently on older clients
- **Nil-safe returns**: Secret values become nil, never leak through
- **Variadic detection**: Check multiple values in a single call
- **No data leakage**: Error messages never expose secret content

## Quick Start

```lua
local Loolib = LibStub("Loolib")
local SecretUtil = Loolib.SecretUtil

-- Check if a value is secret before using it
local name = UnitName("target")
if SecretUtil.IsSecretValue(name) then
    name = "Unknown"
end

-- Or use Guard for the same pattern
local safeName = SecretUtil.Guard(UnitName("target"), "Unknown")

-- Use Safe wrappers to avoid secrets entirely
local playerName, realm = SecretUtil.SafeUnitName("player")
if playerName then
    print("Player:", playerName)
end
```

## API Reference

### Core Detection

#### IsAvailable()

Check whether the `issecretvalue` API exists in this WoW build.

**Parameters:** None

**Returns:**
- `boolean`: True if `issecretvalue` is available (WoW 12.0+)

**Example:**
```lua
if SecretUtil.IsAvailable() then
    print("Running on WoW 12.0+, secret value handling active")
end
```

#### IsSecretValue(...)

Check if any of the given values are WoW secret values.

**Parameters:**
- `...` (any): One or more values to check

**Returns:**
- `boolean`: True if any value is a secret value. Always false on pre-12.0.

**Example:**
```lua
local name, realm = UnitName("target")
if SecretUtil.IsSecretValue(name, realm) then
    -- At least one value is secret, cannot use them
    return
end
```

#### SecretsForPrint(...)

Replace secret values with `"<secret>"` for safe printing. Non-secret values are converted via `tostring()`. On pre-12.0, passes through unchanged.

**Parameters:**
- `...` (any): Values to sanitize

**Returns:**
- `...` (string): Same number of values, with secrets replaced

**Example:**
```lua
local name, realm = UnitName("target")
print("Target:", SecretUtil.SecretsForPrint(name, realm))
-- Output: "Target: Arthas Menethil" or "Target: <secret> <secret>"
```

#### Guard(value, fallback)

Return the value if it is not secret, otherwise return a fallback.

**Parameters:**
- `value` (any): The value to guard
- `fallback` (any): Value to return if `value` is secret (default: nil)

**Returns:**
- `any`: The original value or the fallback

**Example:**
```lua
local name = SecretUtil.Guard(UnitName("target"), "Unknown")
```

#### GuardToString(value, placeholder)

Return `tostring(value)` if not secret, otherwise return a placeholder string.

**Parameters:**
- `value` (any): The value to guard
- `placeholder` (string): String to return if secret (default: `"<secret>"`)

**Returns:**
- `string`: The stringified value or placeholder

**Example:**
```lua
local nameStr = SecretUtil.GuardToString(UnitName("target"), "???")
myFrame.text:SetText(nameStr)
```

### Safe Unit API Wrappers

All Safe wrappers validate their input and raise `error(..., 2)` on type mismatch. Error messages never include the invalid value (which could itself be a secret).

#### SafeUnitName(unit, showServerName)

Safe wrapper for `UnitName` / `GetUnitName`. Returns nil instead of secret values.

**Parameters:**
- `unit` (string): Unit ID (e.g., `"player"`, `"target"`, `"raid1"`)
- `showServerName` (boolean|nil): If truthy, uses `GetUnitName(unit, true)` which bakes the realm into the name string

**Returns:**
- `string|nil` name
- `string|nil` realm (nil when `showServerName` is truthy, since realm is baked into name)

**Errors:**
- `"LoolibSecretUtil: SafeUnitName requires a string unit ID"` if `unit` is not a string

**Example:**
```lua
local name, realm = SecretUtil.SafeUnitName("target")
if name then
    print("Target:", name, realm or "")
else
    print("Target name is secret (combat taint)")
end
```

#### SafeUnitClass(unit)

Safe wrapper for `UnitClass`.

**Parameters:**
- `unit` (string): Unit ID

**Returns:**
- `string|nil` localizedClass
- `string|nil` englishClass
- `number|nil` classID

**Errors:**
- `"LoolibSecretUtil: SafeUnitClass requires a string unit ID"` if `unit` is not a string

**Example:**
```lua
local _, englishClass, classID = SecretUtil.SafeUnitClass("player")
if englishClass then
    print("Class:", englishClass, "ID:", classID)
end
```

#### SafeGetRaidRosterInfo(index)

Safe wrapper for `GetRaidRosterInfo`. If the name return is secret, returns bare nil (not 12 nils). Callers destructuring into multiple locals will receive nil for all positions.

**Parameters:**
- `index` (number): Raid roster index (1-based)

**Returns (on success):**
- `string` name, `number` rank, `number` subgroup, `number` level, `string|nil` class, `string|nil` fileName, `string|nil` zone, `boolean` online, `boolean` isDead, `string` role, `boolean` isML, `string` combatRole

**Returns (when secret or absent):**
- `nil` (bare nil, single return value)

**Errors:**
- `"LoolibSecretUtil: SafeGetRaidRosterInfo requires a number index"` if `index` is not a number

**Example:**
```lua
for i = 1, GetNumGroupMembers() do
    local name, rank, subgroup, level, class, fileName, zone,
          online, isDead, role, isML, combatRole = SecretUtil.SafeGetRaidRosterInfo(i)
    if name then
        print(i, name, class or "?")
    end
end
```

#### SafeGetPlayerInfoByGUID(guid)

Safe wrapper for `GetPlayerInfoByGUID`. If the name return is secret, returns bare nil. Does NOT strip null bytes from name/realm -- that is the consumer's concern.

**Parameters:**
- `guid` (string): Player GUID

**Returns (on success):**
- `string|nil` localizedClass, `string|nil` englishClass, `string|nil` localizedRace, `string|nil` englishRace, `number|nil` sex, `string|nil` name, `string|nil` realmName

**Returns (when secret or absent):**
- `nil` (bare nil, single return value)

**Errors:**
- `"LoolibSecretUtil: SafeGetPlayerInfoByGUID requires a string GUID"` if `guid` is not a string

**Example:**
```lua
local localizedClass, englishClass, localizedRace, englishRace,
      sex, name, realmName = SecretUtil.SafeGetPlayerInfoByGUID(playerGUID)
if name then
    print("Found:", name, "-", englishClass)
end
```

## Usage Patterns

### Guard Before String Operations

```lua
-- WRONG: will error if name is a secret value
local name = UnitName("target")
if name:find("-") then ... end

-- RIGHT: use SecretUtil
local name = SecretUtil.SafeUnitName("target")
if name and name:find("-") then ... end
```

### Guard Before Table Key Usage

```lua
-- WRONG: secret values cannot be table keys
local name = UnitName("target")
playerData[name] = true  -- errors if name is secret

-- RIGHT: guard first
local name = SecretUtil.SafeUnitName("target")
if name then
    playerData[name] = true
end
```

### Safe Raid Iteration

```lua
local function GetRaidMembers()
    local members = {}
    for i = 1, GetNumGroupMembers() do
        local name, rank, subgroup = SecretUtil.SafeGetRaidRosterInfo(i)
        if name then
            members[#members + 1] = { name = name, rank = rank, subgroup = subgroup }
        end
    end
    return members
end
```

### Debug Logging with Secret Safety

```lua
local function DebugLog(unit)
    local name = UnitName(unit)
    local class = UnitClass(unit)
    print("Debug:", SecretUtil.SecretsForPrint(name, class))
end
```

## Technical Details

### Pre-12.0 Compatibility

All functions check `if not issecretvalue then` as their first operation. On pre-12.0 clients where `issecretvalue` is nil, functions return raw API results with zero overhead beyond the nil check.

### Global Caching

The module caches all referenced globals (`issecretvalue`, `UnitName`, `GetUnitName`, `UnitClass`, `GetRaidRosterInfo`, `GetPlayerInfoByGUID`, `error`, `select`, `tostring`, `type`, `unpack`) at file scope for consistent performance on hot paths.

### Input Validation

All Safe* wrappers validate their primary argument type before calling the WoW API. Error messages use the format `"LoolibSecretUtil: FunctionName requires a TYPE PARAM"` with `error(..., 2)` to report at the caller's stack level. Error messages intentionally omit the invalid value to prevent leaking secret content through error handlers.

### Module Registration

Registered as `"Utils.SecretUtil"` via `Loolib:RegisterModule()`. Also available as:
- `Loolib.SecretUtil` (convenience alias)
- `Loolib.Utils.SecretUtil` (namespace path)
- `Loolib:GetModule("Utils.SecretUtil")` (formal lookup)
- `Loolib:GetModule("SecretUtil")` (leaf alias)
