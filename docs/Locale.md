# Loolib Locale System

## Overview

The Loolib Locale system provides comprehensive multilingual support for World of Warcraft addons. It offers an AceLocale-3.0 equivalent implementation that allows addons to support multiple languages with automatic fallback to a default locale when a translation is not available.

### Key Features

- **Multi-language support**: Register translations for any WoW locale code
- **Automatic fallback**: Missing translations automatically fall back to the default locale
- **Efficient loading**: Locale files only load if they match the player's game locale
- **Simple API**: Intuitive `NewLocale()` and `GetLocale()` functions
- **Metatable-based**: Uses Lua metatables for elegant fallback and initialization

### How It Works

The Locale system maintains a registry of locale tables organized by addon name and locale code. Each addon can register a default locale, which serves as a fallback when translations are missing. Non-default locales are only loaded if their locale code matches the player's current game locale, reducing memory overhead.

---

## Quick Start

### Basic Setup

Here's the simplest way to get localization working:

```lua
local Loolib = LibStub("Loolib")
local Locale = Loolib:GetModule("Locale")

-- Create default locale (enUS) - this is always returned and loaded
local L = Locale:NewLocale("MyAddon", "enUS", true)
if not L then return end

-- Define default strings using the L["key"] = true pattern
L["GREETING"] = true
L["FAREWELL"] = true
L["CONFIRM"] = true
```

When you assign `true` to a key, the system automatically converts it so that `L["GREETING"]` becomes `"GREETING"`. This makes it easy to define keys without repetition.

### Adding Translations

```lua
local Loolib = LibStub("Loolib")
local Locale = Loolib:GetModule("Locale")

-- German translations
local L = Locale:NewLocale("MyAddon", "deDE")
if not L then return end

L["GREETING"] = "Hallo"
L["FAREWELL"] = "Auf Wiedersehen"
L["CONFIRM"] = "Bestätigen"

-- French translations
local L = Locale:NewLocale("MyAddon", "frFR")
if not L then return end

L["GREETING"] = "Bonjour"
L["FAREWELL"] = "Au revoir"
L["CONFIRM"] = "Confirmer"
```

Notice that `NewLocale()` returns `nil` for non-default locales that don't match the player's game locale. Your locale file can safely return early if `NewLocale()` returns nil, preventing unnecessary processing.

### Runtime Locale Access

```lua
local Loolib = LibStub("Loolib")
local Locale = Loolib:GetModule("Locale")

-- Get the locale for the current player
local L = Locale:GetLocale("MyAddon")

-- Use translations
print(L["GREETING"])  -- "Hallo" (if player is German), "GREETING" (fallback)
```

---

## API Reference

### NewLocale(application, locale, isDefault, silent)

Creates or retrieves a locale table for the specified addon and locale code.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `application` | string | Yes | The addon name (e.g., `"MyAddon"`, `"Loothing"`) |
| `locale` | string | Yes | WoW locale code (e.g., `"enUS"`, `"deDE"`) |
| `isDefault` | boolean | No | Whether this is the default/fallback locale (defaults to false) |
| `silent` | boolean | No | Suppress warning messages (defaults to false) |

**Return Value:**

- **For default locale** (`isDefault = true`): Returns the locale table (always)
- **For non-default locale matching player's locale**: Returns the locale table
- **For non-default locale NOT matching player's locale**: Returns `nil`

**Behavior:**

When `isDefault = true`:
- The locale table is created with a special metatable that converts `L[key] = true` to `L[key] = key`
- This makes it easy to define translation keys
- This locale becomes the fallback for all other locales of that application

When `isDefault = false`:
- If the locale code matches `GetLocale()` (player's current game locale), the locale table is created with a fallback metatable pointing to the default locale
- If the locale code doesn't match, returns `nil` to allow the file to skip loading translations
- Missing keys automatically fall back to the default locale via the metatable

**Example:**

```lua
local Locale = LibStub("Loolib"):GetModule("Locale")

-- Default locale - always returns a table
local L = Locale:NewLocale("MyAddon", "enUS", true)
assert(L ~= nil)

-- Non-default locales - only returns if it matches the player's locale
local L_de = Locale:NewLocale("MyAddon", "deDE")
if not L_de then
    return  -- Player isn't German, skip loading German translations
end
```

---

### GetLocale(application, silent)

Retrieves the current locale table for an addon. Returns the locale matching the player's game locale, or falls back to the default locale.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `application` | string | Yes | The addon name |
| `silent` | boolean | No | Suppress warning messages (defaults to false) |

**Return Value:**

- Locale table for the current game locale, or
- Locale table for the default locale, or
- Empty table `{}` if no locales are registered

**Warnings:**

When `silent = false`:
- If no locales are found for the application, prints: `[Loolib Locale] No locales found for 'application'`
- If the player's locale isn't available but a default exists, prints: `[Loolib Locale] Locale 'playerLocale' not found for 'application', using default 'defaultLocale'`
- If no default locale is found, prints: `[Loolib Locale] No default locale found for 'application'`

**Example:**

```lua
local Locale = LibStub("Loolib"):GetModule("Locale")
local L = Locale:GetLocale("MyAddon", true)  -- true = suppress warnings

print(L["GREETING"])  -- Uses player's locale, or falls back to default
```

---

### GetLocales(application)

Retrieves all registered locale tables for an addon.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `application` | string | Yes | The addon name |

**Return Value:**

Table of all registered locales: `{enUS = {...}, deDE = {...}, ...}`

**Example:**

```lua
local Locale = LibStub("Loolib"):GetModule("Locale")
local allLocales = Locale:GetLocales("MyAddon")

for localeCode, localeTable in pairs(allLocales) do
    print(localeCode)  -- "enUS", "deDE", "frFR", etc.
end
```

---

### GetDefaultLocale(application)

Retrieves the locale code of the default locale for an addon.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `application` | string | Yes | The addon name |

**Return Value:**

The locale code of the default locale (e.g., `"enUS"`), or `nil` if not set.

**Example:**

```lua
local Locale = LibStub("Loolib"):GetModule("Locale")
local defaultCode = Locale:GetDefaultLocale("MyAddon")
print(defaultCode)  -- "enUS"
```

---

## Usage Examples

### Complete Multi-File Example

Here's a complete example showing how to organize and use the Locale system in a real addon.

**File: MyAddon/Locales/enUS.lua**

```lua
local Loolib = LibStub("Loolib")
local Locale = Loolib:GetModule("Locale")

local L = Locale:NewLocale("MyAddon", "enUS", true)
if not L then return end

-- Define all your strings here
L["ADDON_NAME"] = true
L["GREETING"] = true
L["FAREWELL"] = true
L["CONFIRM_DELETE"] = true
L["ITEMS_FOUND"] = true
L["NO_ITEMS"] = true
L["SETTINGS"] = true
L["HELP"] = true
```

**File: MyAddon/Locales/deDE.lua**

```lua
local Loolib = LibStub("Loolib")
local Locale = Loolib:GetModule("Locale")

local L = Locale:NewLocale("MyAddon", "deDE")
if not L then return end

L["ADDON_NAME"] = "MeinAddon"
L["GREETING"] = "Hallo"
L["FAREWELL"] = "Auf Wiedersehen"
L["CONFIRM_DELETE"] = "Bestätigen und löschen?"
L["ITEMS_FOUND"] = "Gegenstände gefunden"
L["NO_ITEMS"] = "Keine Gegenstände"
L["SETTINGS"] = "Einstellungen"
L["HELP"] = "Hilfe"
```

**File: MyAddon/Locales/frFR.lua**

```lua
local Loolib = LibStub("Loolib")
local Locale = Loolib:GetModule("Locale")

local L = Locale:NewLocale("MyAddon", "frFR")
if not L then return end

L["ADDON_NAME"] = "MonAddon"
L["GREETING"] = "Bonjour"
L["FAREWELL"] = "Au revoir"
L["CONFIRM_DELETE"] = "Confirmer et supprimer?"
L["ITEMS_FOUND"] = "Éléments trouvés"
L["NO_ITEMS"] = "Aucun élément"
L["SETTINGS"] = "Paramètres"
L["HELP"] = "Aide"
```

**File: MyAddon/Core/Main.lua**

```lua
local Loolib = LibStub("Loolib")
local Locale = Loolib:GetModule("Locale")

local function Initialize()
    local L = Locale:GetLocale("MyAddon")

    print(L["GREETING"])
    print(L["ADDON_NAME"] .. " loaded!")
end

-- Hook into ADDON_LOADED
local Events = Loolib:GetModule("Events")
Events.Registry:RegisterFrameEventAndCallback("ADDON_LOADED", function(event, addonName)
    if addonName == "MyAddon" then
        Initialize()
    end
end)
```

---

### Advanced: String Formatting with Locales

You can use Lua string formatting with localized strings:

```lua
local L = Locale:GetLocale("MyAddon")

-- Define in locale:
-- L["ITEM_COUNT"] = "Found %d items"
-- L["PLAYER_GREETING"] = "Hello, %s!"

local message = string.format(L["ITEM_COUNT"], 5)
print(message)  -- "Found 5 items"

local greeting = string.format(L["PLAYER_GREETING"], UnitName("player"))
print(greeting)  -- "Hello, PlayerName!"
```

### Loading Locale Files from Multiple Directories

If you have multiple addon modules that each need their own locales:

```lua
-- MyAddon/Core/Strings.lua (default locale)
local Locale = LibStub("Loolib"):GetModule("Locale")
local L = Locale:NewLocale("MyAddon", "enUS", true)
if not L then return end
L["MODULE_A"] = true

-- MyAddon/Modules/ModuleB/Locales.lua
local Locale = LibStub("Loolib"):GetModule("Locale")
local L = Locale:NewLocale("MyAddon", "enUS", true)  -- Same application name!
if not L then return end
L["MODULE_B"] = true

-- Later, GetLocale returns all strings registered under "MyAddon"
local L = Locale:GetLocale("MyAddon")
print(L["MODULE_A"])  -- "MODULE_A"
print(L["MODULE_B"])  -- "MODULE_B"
```

The key point: **call `NewLocale()` multiple times with the same `application` name and locale code to add more strings to the same locale table**.

---

## File Organization

### Recommended Structure

For a typical addon using Loolib localization:

```
MyAddon/
├── MyAddon.toc              # Main TOC file
├── Core/
│   ├── Main.lua             # Core addon logic
│   └── Strings.lua          # Default locale (enUS)
├── Locales/
│   ├── enUS.lua             # English (default)
│   ├── deDE.lua             # German
│   ├── frFR.lua             # French
│   ├── esES.lua             # Spanish (Spain)
│   ├── esMX.lua             # Spanish (Mexico)
│   ├── ptBR.lua             # Portuguese (Brazil)
│   ├── ruRU.lua             # Russian
│   ├── koKR.lua             # Korean
│   ├── zhCN.lua             # Chinese (Simplified)
│   └── zhTW.lua             # Chinese (Traditional)
└── UI/
    ├── MainWindow.lua
    └── Panels.lua
```

### TOC File Example

```toc
## Interface: 120000
## Title: MyAddon
## Notes: A sample addon using Loolib
## Author: Your Name
## Version: 1.0.0

# Load Loolib (if embedding)
Libs/LibStub/LibStub.lua
Libs/Loolib/Loolib.lua
Libs/Loolib/Core/Locale.lua

# Load locales BEFORE main code
Locales/enUS.lua
Locales/deDE.lua
Locales/frFR.lua
Locales/esES.lua
Locales/esMX.lua
Locales/ptBR.lua
Locales/ruRU.lua
Locales/koKR.lua
Locales/zhCN.lua
Locales/zhTW.lua

# Load main code
Core/Strings.lua
Core/Main.lua
UI/MainWindow.lua
UI/Panels.lua
```

### Load Order

**Critical Rule**: Always load your default locale FIRST, then non-default locales.

Why? The first call to `NewLocale()` with `isDefault = true` establishes the fallback target. All subsequent locales registered with the same application name will automatically fall back to it.

```lua
-- CORRECT ORDER:
LoadLocaleFile("Locales/enUS.lua")    -- Default (first!)
LoadLocaleFile("Locales/deDE.lua")    -- Will fall back to enUS
LoadLocaleFile("Locales/frFR.lua")    -- Will fall back to enUS

-- WRONG ORDER:
LoadLocaleFile("Locales/deDE.lua")    -- Loaded first (no fallback yet!)
LoadLocaleFile("Locales/enUS.lua")    -- Set as default (too late for deDE)
```

---

## Best Practices

### 1. Use Consistent Key Names

Keep your translation keys consistent across all locales. Use UPPERCASE_WITH_UNDERSCORES for readability:

```lua
-- GOOD
L["ITEM_DROP_RATE"] = "Drop Rate"
L["LOOT_WINDOW_TITLE"] = "Loot Council"
L["CONFIRM_ACTION"] = "Are you sure?"

-- AVOID
L["dropRate"] = "Drop Rate"
L["loot_window_title"] = "Loot Council"
L["CONFIRM"] = "Are you sure?"  -- Too vague
```

### 2. Handle Missing Translations Gracefully

Since the system falls back to the default locale, missing translations will show the default text. But if you need custom behavior:

```lua
local L = Locale:GetLocale("MyAddon")

local function GetTranslation(key, fallback)
    return L[key] or fallback or key
end

local text = GetTranslation("MISSING_KEY", "Unknown")
```

### 3. Use Format Strings for Dynamic Content

Define templates in your locale, not concatenation:

```lua
-- GOOD - define in locale
-- L["PLAYER_LEVEL"] = "%s is level %d"
local message = string.format(L["PLAYER_LEVEL"], playerName, playerLevel)

-- AVOID - concatenation is hard to translate
-- local message = playerName .. " is level " .. playerLevel
```

### 4. Separate Content Locales from Code Locales

For large addons, keep UI strings separate from code messages:

```lua
-- Locales/enUS.lua - UI STRINGS
local L = Locale:NewLocale("MyAddon", "enUS", true)
if not L then return end

L["MENU_FILE"] = "File"
L["MENU_EDIT"] = "Edit"
L["MENU_HELP"] = "Help"
L["BTN_OK"] = "OK"
L["BTN_CANCEL"] = "Cancel"

-- Core/Messages.lua - CODE MESSAGES (internal)
local L = Locale:NewLocale("MyAddon", "enUS", true)
if not L then return end

L["CHAT_PREFIX"] = "MyAddon"
L["ERR_NOT_INITIALIZED"] = "Addon not yet initialized"
L["ERR_INVALID_PARAM"] = "Invalid parameter"
```

### 5. Document Locale Dependencies

If certain locales require updates for new strings, document it:

```lua
-- Default locale (enUS)
local L = Locale:NewLocale("MyAddon", "enUS", true)
if not L then return end

L["NEW_FEATURE_1"] = "New feature"  -- Added in v2.0
L["NEW_FEATURE_2"] = "Another feature"  -- Added in v2.0
```

Then in your locale files:

```lua
-- deDE.lua
-- Last updated: 2025-12-01
-- Missing: NEW_FEATURE_1, NEW_FEATURE_2 (added v2.0)
local L = Locale:NewLocale("MyAddon", "deDE")
if not L then return end

-- Translations...
```

### 6. Never Assume Locale is Available

Always use the fallback behavior:

```lua
-- GOOD - uses fallback if locale doesn't exist
local L = Locale:GetLocale("MyAddon", true)  -- silent = true
print(L["GREETING"])

-- RISKY - could be empty table
local allLocales = Locale:GetLocales("MyAddon")
if not allLocales.deDE then
    -- Handle missing locale
end
```

---

## Supported WoW Locale Codes

The WoW Locale system supports all of Blizzard's official locales:

| Code | Language | Region |
|------|----------|--------|
| `enUS` | English | United States |
| `enGB` | English | Great Britain |
| `deDE` | German | Germany |
| `frFR` | French | France |
| `esES` | Spanish | Spain |
| `esMX` | Spanish | Mexico |
| `ptBR` | Portuguese | Brazil |
| `ptPT` | Portuguese | Portugal |
| `itIT` | Italian | Italy |
| `ruRU` | Russian | Russia |
| `koKR` | Korean | Korea |
| `zhCN` | Chinese | China (Simplified) |
| `zhTW` | Chinese | Taiwan (Traditional) |
| `jaJP` | Japanese | Japan |

Your addon can register locales for any of these codes. Players will automatically use their game's locale if available, with fallback to your default locale.

---

## Common Patterns

### Pattern 1: Singleton Locale Access

If your addon frequently accesses the locale, cache it:

```lua
local MyAddon = {}
MyAddon.L = LibStub("Loolib"):GetModule("Locale"):GetLocale("MyAddon")

-- Now use it everywhere
print(MyAddon.L["GREETING"])
```

### Pattern 2: Locale with Namespace

For modularity, attach locale to each module:

```lua
local MyModule = {}

function MyModule:Initialize()
    self.L = LibStub("Loolib"):GetModule("Locale"):GetLocale("MyAddon")
end

function MyModule:OnClick()
    print(self.L["BTN_CLICKED"])
end
```

### Pattern 3: Conditional Localization

Load different locales for different features:

```lua
local Locale = LibStub("Loolib"):GetModule("Locale")

-- Core UI (always)
local L = Locale:NewLocale("MyAddon", "enUS", true)

-- Extended content (only for certain regions)
local L_de = Locale:NewLocale("MyAddon", "deDE")
if L_de then
    -- We're in a German client, load German-specific content
end
```

### Pattern 4: Locale Switching (Advanced)

While the Locale system doesn't support runtime locale switching (WoW doesn't either), you can provide a fallback:

```lua
local function GetString(key, preferredLocale)
    local Locale = LibStub("Loolib"):GetModule("Locale")
    local locales = Locale:GetLocales("MyAddon")

    if preferredLocale and locales[preferredLocale] then
        return locales[preferredLocale][key]
    end

    return Locale:GetLocale("MyAddon")[key]
end

print(GetString("GREETING"))  -- Uses player's locale
print(GetString("GREETING", "deDE"))  -- Forces German
```

---

## Metatable Behavior

Understanding how the Locale system uses metatables helps with advanced usage:

### Default Locale Metatable

```lua
-- When you create a default locale:
local L = Locale:NewLocale("MyAddon", "enUS", true)

-- The metatable does this:
setmetatable(L, {
    __newindex = function(tbl, key, value)
        if value == true then
            rawset(tbl, key, key)  -- L[key] = true becomes L[key] = "key"
        else
            rawset(tbl, key, value)
        end
    end
})

-- So:
L["GREETING"] = true   -- Actually stores L["GREETING"] = "GREETING"
L["NAME"] = "James"    -- Stores as-is: L["NAME"] = "James"
```

### Non-Default Locale Metatable

```lua
-- When you create a non-default locale (that matches player's locale):
local L = Locale:NewLocale("MyAddon", "deDE")

-- The metatable does this:
setmetatable(L, {
    __index = defaultTable  -- Falls back to default locale
})

-- So:
L["GREETING"] = "Hallo"  -- Stores translation
print(L["UNKNOWN"])       -- Not found in deDE, falls back to defaultTable["UNKNOWN"]
                          -- Which returns "UNKNOWN" (the key itself)
```

---

## Troubleshooting

### Issue: Locale shows key instead of translation

**Cause**: Locale file didn't load or translation wasn't set.

**Solution**: Verify:
1. Locale file is listed in TOC before main code
2. Locale code matches one of the supported codes
3. Translation key is spelled correctly

```lua
local L = Locale:GetLocale("MyAddon")
print(L["GREETING"])  -- If shows "GREETING", translation missing
```

### Issue: Wrong locale loading for player

**Cause**: Locale code doesn't match player's game locale.

**Solution**: Check `GetLocale()` from WoW:

```lua
print(GetLocale())  -- Prints player's actual locale code
```

Then ensure your locale files match that code exactly (case-sensitive).

### Issue: "No locales found" warning

**Cause**: No locales registered for addon name.

**Solution**: Verify the addon name is consistent:

```lua
-- Must match exactly:
Locale:NewLocale("MyAddon", "enUS", true)
local L = Locale:GetLocale("MyAddon")  -- Same name!
```

### Issue: Fallback isn't working

**Cause**: Default locale not set or registered first.

**Solution**: Ensure default locale is created first:

```lua
-- CORRECT:
local L_en = Locale:NewLocale("MyAddon", "enUS", true)   -- Default
local L_de = Locale:NewLocale("MyAddon", "deDE")         -- Will fall back

-- WRONG:
local L_de = Locale:NewLocale("MyAddon", "deDE")         -- Loaded first
local L_en = Locale:NewLocale("MyAddon", "enUS", true)   -- Set as default later
```

---

## Technical Details

### Metatable Creation Timing

The metatable is created ONLY when:
- Default locale is first created, OR
- Non-default locale is created AND matches player's current locale

This ensures:
- Missing keys in default locale show the key itself
- Missing keys in non-default locale fall back to default

### Memory Efficiency

The Locale system is memory-efficient:
- Only the default locale and player's current locale are fully loaded
- Other locale files don't execute or consume memory if the player isn't that locale
- The `NewLocale()` check (`if not L then return end`) prevents unnecessary processing

### GetLocale() Return Values

```lua
local Locale = LibStub("Loolib"):GetModule("Locale")

-- Player is German, German locale exists:
local L = Locale:GetLocale("MyAddon")
-- Returns: German locale table

-- Player is German, German locale missing, default is enUS:
local L = Locale:GetLocale("MyAddon")
-- Returns: enUS locale table with warning

-- Player is German, no locales registered:
local L = Locale:GetLocale("MyAddon")
-- Returns: {} (empty table) with warning
```

---

## API Summary

| Function | Returns | Purpose |
|----------|---------|---------|
| `NewLocale(app, locale, isDefault, silent)` | table or nil | Create/get locale for app |
| `GetLocale(app, silent)` | table | Get current locale with fallback |
| `GetLocales(app)` | table | Get all registered locales for app |
| `GetDefaultLocale(app)` | string or nil | Get default locale code |

---

## Related Documentation

- [Loolib Core](./Core.md) - Core module system and LibStub
- [Loolib Events](./Events.md) - Event handling with locale-aware messages
- [Loolib Config](./Config.md) - Configuration system that integrates with locales
