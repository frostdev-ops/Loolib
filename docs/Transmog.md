# Transmog - Transmog Utilities Module

The Transmog module provides comprehensive transmog-related functionality using the C_TransmogCollection API with optional CanIMogIt addon integration.

## Overview

This module helps addons determine:
- Whether items can be transmogged
- Whether the player knows specific appearances
- Whether the player can learn appearances (considering class/armor restrictions)
- Detailed appearance information and collection progress

It automatically integrates with the popular CanIMogIt addon if loaded, falling back to native WoW API otherwise.

## Basic Usage

```lua
local Loolib = LibStub("Loolib")
local Transmog = Loolib:GetModule("Transmog")

-- Check if an item can be transmogged
local itemLink = "|cff0070dd|Hitem:1234:::::::::::::|h[Example Item]|h|r"
if Transmog:IsTransmoggable(itemLink) then
    print("This item can be transmogged!")
end

-- Check if player knows the appearance
if Transmog:PlayerKnowsAppearance(itemLink) then
    print("You already know this appearance!")
end

-- Check if player can learn it
local canLearn, reason = Transmog:CanLearnAppearance(itemLink)
if not canLearn then
    print("Cannot learn:", reason)
end
```

## Core Functions

### IsTransmoggable

Check if an item can be transmogged.

```lua
local canTransmog = Transmog:IsTransmoggable(itemLink)
```

**Parameters:**
- `itemLink` (string) - Item link or item ID

**Returns:**
- `boolean` - True if the item can be transmogged

**Example:**
```lua
local itemLink = GetContainerItemLink(1, 1) -- Get item from bag slot
if Transmog:IsTransmoggable(itemLink) then
    print("This item is transmoggable")
end
```

---

### PlayerKnowsAppearance

Check if the player knows this item's appearance from any source.

```lua
local knows = Transmog:PlayerKnowsAppearance(itemLink)
```

**Parameters:**
- `itemLink` (string) - Item link or item ID

**Returns:**
- `boolean` - True if player knows the appearance (from any source)

**Example:**
```lua
if Transmog:PlayerKnowsAppearance(itemLink) then
    print("You already have this appearance unlocked!")
else
    print("This is a new appearance for you!")
end
```

---

### PlayerKnowsAppearanceFromItem

Check if the player knows this appearance from this specific item source.

```lua
local knowsFromItem = Transmog:PlayerKnowsAppearanceFromItem(itemLink)
```

**Parameters:**
- `itemLink` (string) - Item link or item ID

**Returns:**
- `boolean` - True if player knows the appearance from this specific item

**Example:**
```lua
if Transmog:PlayerKnowsAppearanceFromItem(itemLink) then
    print("You have collected this exact source!")
else
    print("You may have the appearance, but not from this source")
end
```

---

### CanLearnAppearance

Check if the player's character can learn this appearance (class/armor restrictions).

```lua
local canLearn, reason = Transmog:CanLearnAppearance(itemLink)
```

**Parameters:**
- `itemLink` (string) - Item link or item ID

**Returns:**
- `canLearn` (boolean) - True if the player can learn this appearance
- `reason` (string|nil) - If cannot learn, a reason string (e.g., "Wrong armor type")

**Example:**
```lua
local canLearn, reason = Transmog:CanLearnAppearance(itemLink)
if canLearn then
    if not Transmog:PlayerKnowsAppearance(itemLink) then
        print("You can learn this new appearance!")
    end
else
    print("Cannot learn this appearance:", reason)
end
```

---

### GetAppearanceSourceID

Get the appearance source ID for an item.

```lua
local sourceID = Transmog:GetAppearanceSourceID(itemLink)
```

**Parameters:**
- `itemLink` (string) - Item link or item ID

**Returns:**
- `number|nil` - The modified appearance source ID, or nil if not transmoggable

**Example:**
```lua
local sourceID = Transmog:GetAppearanceSourceID(itemLink)
if sourceID then
    print("Source ID:", sourceID)
end
```

---

### GetAppearanceInfo

Get both appearance ID and source ID for an item.

```lua
local appearanceID, sourceID = Transmog:GetAppearanceInfo(itemLink)
```

**Parameters:**
- `itemLink` (string) - Item link or item ID

**Returns:**
- `appearanceID` (number|nil) - The appearance ID
- `sourceID` (number|nil) - The modified appearance source ID

**Example:**
```lua
local appearanceID, sourceID = Transmog:GetAppearanceInfo(itemLink)
if appearanceID then
    print(string.format("Appearance: %d, Source: %d", appearanceID, sourceID))
end
```

---

## CanIMogIt Integration

### HasCanIMogIt

Check if the CanIMogIt addon is loaded.

```lua
local hasAddon = Transmog:HasCanIMogIt()
```

**Returns:**
- `boolean` - True if CanIMogIt is available

**Example:**
```lua
if Transmog:HasCanIMogIt() then
    print("Using CanIMogIt for enhanced transmog detection")
else
    print("Using native WoW API for transmog detection")
end
```

---

### CanIMogItCheck

Get comprehensive transmog status (uses CanIMogIt if available, otherwise native API).

```lua
local status = Transmog:CanIMogItCheck(itemLink)
```

**Parameters:**
- `itemLink` (string) - Item link or item ID

**Returns:**
- `string|nil` - One of the following constants, or nil if invalid:
  - `Transmog.APPEARANCE_KNOWN` - Player knows from any source
  - `Transmog.APPEARANCE_KNOWN_FROM_ITEM` - Player knows from this specific source
  - `Transmog.APPEARANCE_UNKNOWN` - Player can learn but hasn't yet
  - `Transmog.APPEARANCE_CANNOT_LEARN` - Player cannot learn (wrong class/armor)
  - `Transmog.APPEARANCE_NOT_TRANSMOGGABLE` - Item is not transmoggable

**Example:**
```lua
local status = Transmog:CanIMogItCheck(itemLink)
if status == Transmog.APPEARANCE_KNOWN_FROM_ITEM then
    print("Collected from this source!")
elseif status == Transmog.APPEARANCE_KNOWN then
    print("Collected from a different source")
elseif status == Transmog.APPEARANCE_UNKNOWN then
    print("Not collected - you should get this!")
elseif status == Transmog.APPEARANCE_CANNOT_LEARN then
    print("Cannot learn (wrong class or armor type)")
end
```

---

## Advanced Functions

### GetAllAppearanceSources

Get all source IDs for an appearance.

```lua
local sources = Transmog:GetAllAppearanceSources(itemLink)
```

**Parameters:**
- `itemLink` (string) - Item link or item ID

**Returns:**
- `table|nil` - Array of source IDs, or nil if no appearance

**Example:**
```lua
local sources = Transmog:GetAllAppearanceSources(itemLink)
if sources then
    print("This appearance has", #sources, "different sources")
    for _, sourceID in ipairs(sources) do
        local collected = Transmog:IsSourceCollected(sourceID)
        print("Source", sourceID, "collected:", collected)
    end
end
```

---

### GetSourceInfo

Get detailed information about a specific appearance source.

```lua
local info = Transmog:GetSourceInfo(sourceID)
```

**Parameters:**
- `sourceID` (number) - The appearance source ID

**Returns:**
- `table|nil` - Source info table with fields:
  - `sourceID` (number) - The source ID
  - `visualID` (number) - The visual ID
  - `isCollected` (boolean) - Whether player has collected this source
  - `sourceType` (number) - Source type (vendor, drop, etc.)
  - Additional fields from C_TransmogCollection.GetSourceInfo

**Example:**
```lua
local sourceID = Transmog:GetAppearanceSourceID(itemLink)
if sourceID then
    local info = Transmog:GetSourceInfo(sourceID)
    if info then
        print("Source ID:", info.sourceID)
        print("Collected:", info.isCollected)
    end
end
```

---

### IsSourceCollected

Check if a specific source is collected.

```lua
local collected = Transmog:IsSourceCollected(sourceID)
```

**Parameters:**
- `sourceID` (number) - The appearance source ID

**Returns:**
- `boolean` - True if the source is collected

---

### GetAppearanceCollectionProgress

Get collection progress for an item's appearance.

```lua
local collected, total = Transmog:GetAppearanceCollectionProgress(itemLink)
```

**Parameters:**
- `itemLink` (string) - Item link or item ID

**Returns:**
- `collected` (number) - Number of sources collected for this appearance
- `total` (number) - Total number of sources for this appearance

**Example:**
```lua
local collected, total = Transmog:GetAppearanceCollectionProgress(itemLink)
print(string.format("Progress: %d/%d sources collected (%.1f%%)",
    collected, total, (collected / total) * 100))
```

---

## Utility Functions

### GetStatusColor

Get a color code based on transmog status (useful for UI).

```lua
local colorCode = Transmog:GetStatusColor(itemLink)
```

**Parameters:**
- `itemLink` (string) - Item link or item ID

**Returns:**
- `string` - A hex color code:
  - `"|cff00ff00"` - Green (known from this item)
  - `"|cff88ff88"` - Light green (known from different source)
  - `"|cffffff00"` - Yellow (can learn, not yet learned)
  - `"|cffff0000"` - Red (cannot learn)
  - `"|cff888888"` - Gray (not transmoggable)
  - `"|cffffffff"` - White (unknown/default)

**Example:**
```lua
local color = Transmog:GetStatusColor(itemLink)
local itemName = GetItemInfo(itemLink)
print(color .. itemName .. "|r")
```

---

### GetStatusText

Get a human-readable text description of transmog status.

```lua
local text = Transmog:GetStatusText(itemLink)
```

**Parameters:**
- `itemLink` (string) - Item link or item ID

**Returns:**
- `string` - A human-readable status string:
  - "Collected (this source)"
  - "Collected (different source)"
  - "Not collected"
  - "Cannot learn: [reason]"
  - "Not transmoggable"
  - "Unknown"

**Example:**
```lua
local statusText = Transmog:GetStatusText(itemLink)
print("Transmog status:", statusText)
```

---

## Complete Example: Loot Frame Integration

```lua
local Loolib = LibStub("Loolib")
local Transmog = Loolib:GetModule("Transmog")

-- Add transmog info to loot frame
local function UpdateLootItemTransmog(itemFrame, itemLink)
    if not itemLink then return end

    -- Get transmog status
    local status = Transmog:CanIMogItCheck(itemLink)
    if not status then return end

    -- Get color and text
    local color = Transmog:GetStatusColor(itemLink)
    local text = Transmog:GetStatusText(itemLink)

    -- Show icon for important statuses
    if status == Transmog.APPEARANCE_UNKNOWN then
        -- Show "NEW!" icon for learnable appearances
        itemFrame.transmogIcon:Show()
        itemFrame.transmogIcon:SetTexture("Interface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon")

        -- Add tooltip info
        itemFrame.transmogTooltip = "New appearance available!"

    elseif status == Transmog.APPEARANCE_KNOWN_FROM_ITEM then
        -- Show check mark for collected
        itemFrame.transmogIcon:Show()
        itemFrame.transmogIcon:SetAtlas("common-icon-checkmark")
        itemFrame.transmogTooltip = text
    else
        itemFrame.transmogIcon:Hide()
    end

    -- Color the item name
    if itemFrame.itemName then
        local itemName = GetItemInfo(itemLink)
        itemFrame.itemName:SetText(color .. itemName .. "|r")
    end
end

-- Hook into loot rolls
hooksecurefunc("GroupLootFrame_OpenNewFrame", function(id, rollTime)
    local frame = GroupLootContainer:GetFrame(id)
    if frame then
        local itemLink = GetLootRollItemLink(id)
        UpdateLootItemTransmog(frame, itemLink)
    end
end)
```

## Constants

The module defines the following constants for use with `CanIMogItCheck()`:

- `Transmog.APPEARANCE_KNOWN` - "KNOWN"
- `Transmog.APPEARANCE_KNOWN_FROM_ITEM` - "KNOWN_FROM_ITEM"
- `Transmog.APPEARANCE_UNKNOWN` - "UNKNOWN"
- `Transmog.APPEARANCE_CANNOT_LEARN` - "CANNOT_LEARN"
- `Transmog.APPEARANCE_NOT_TRANSMOGGABLE` - "NOT_TRANSMOGGABLE"

## WoW API Reference

This module uses the following WoW 12.0 APIs:

- `C_TransmogCollection.GetItemInfo(itemLink)` - Get appearance and source IDs
- `C_TransmogCollection.GetAllAppearanceSources(appearanceID)` - Get all sources for appearance
- `C_TransmogCollection.GetSourceInfo(sourceID)` - Get detailed source information
- `C_TransmogCollection.PlayerCanCollectSource(sourceID)` - Check if player can collect
- `C_TransmogCollection.GetAppearanceSourceInfo(sourceID)` - Legacy API (deprecated in favor of GetSourceInfo)

## CanIMogIt Integration Details

When CanIMogIt is loaded, the module automatically uses it for the following functions:
- `IsTransmoggable()` - Uses `CanIMogIt:IsTransmogable()`
- `PlayerKnowsAppearance()` - Uses `CanIMogIt:PlayerKnowsTransmog()`
- `PlayerKnowsAppearanceFromItem()` - Uses `CanIMogIt:PlayerKnowsTransmogFromItem()`
- `CanLearnAppearance()` - Uses `CanIMogIt:CharacterCanLearnTransmog()`
- `CanIMogItCheck()` - Uses `CanIMogIt:GetTooltipText()`

All functions gracefully fall back to native WoW API if CanIMogIt is not available or if API calls fail.

## Input Validation & Error Handling

All public functions validate their inputs:

- **`itemLink` parameters**: Passing `nil` returns the safe default (`false`, `nil`, `0,0` depending on signature). Passing a non-string type raises `error("LoolibTransmog: <FuncName> expected string itemLink, got <type>", 2)`.
- **`sourceID` parameters** (`GetSourceInfo`, `IsSourceCollected`): Passing `nil` returns the safe default. Passing a non-number type raises `error("LoolibTransmog: <FuncName> expected number sourceID, got <type>", 2)`.
- **C_TransmogCollection unavailable**: If `C_TransmogCollection` does not exist (e.g., Classic client, very early load), all functions return their safe defaults without error. `CanLearnAppearance` returns `false, "Transmog API unavailable"`.

## API Availability

The module caches `C_TransmogCollection` at file load time. If the namespace does not exist (Classic clients, or if accessed before the WoW API is fully initialized), every function gracefully degrades:

| Return type | Safe default |
|---|---|
| `boolean` | `false` |
| `number\|nil` | `nil` |
| `table\|nil` | `nil` |
| `number, number` | `0, 0` |
| `string\|nil` (status) | `nil` |

## Performance Notes

1. **Caching**: The module does not cache results. If you need to check the same item multiple times in quick succession, consider caching the results yourself.

2. **Batch Processing**: When checking multiple items, make separate calls for each item. The WoW API is efficient enough for real-time checks.

3. **CanIMogIt**: When loaded, CanIMogIt provides more accurate results and handles edge cases better. The performance impact is negligible.

4. **Global caching**: Lua globals (`type`, `pcall`, `ipairs`, `error`, `string.format`) and `C_TransmogCollection` are cached as upvalues at file load for faster access in hot paths.

## See Also

- [Core/Loolib.md](Loolib.md) - Module registration and access
- WoW API Documentation: C_TransmogCollection namespace
