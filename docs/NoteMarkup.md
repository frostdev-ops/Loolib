# NoteMarkup

Conditional tag handlers for raid note markup. Evaluates conditional tags to determine which content should be displayed based on player role, name, class, group, and other context.

## Overview

NoteMarkup provides a flexible system for creating personalized raid notes that show different content to different players. It supports role-based visibility (healers, tanks, DPS), player-specific assignments, class-specific strategies, group assignments, and custom conditions.

## Basic Usage

```lua
local Loolib = LibStub("Loolib")
local NoteMarkup = Loolib:GetModule("NoteMarkup")

-- Get the default processor instance
local processor = NoteMarkup.Get()

-- Process markup text directly
local text = [[
{H}
Healers: Focus on tank healing during this phase
Dispel DoTs immediately
{/H}

{T}
Tanks: Taunt on 3 stacks
Face boss away from raid
{/T}

{P:Alice,Bob}
Alice and Bob: Stack on marker 1
{/P}

{C:MAGE,WARLOCK}
Casters: Use Time Warp at 30%
{/C}
]]

local filtered = processor:ProcessText(text)
-- Result will only show content relevant to current player
```

## Context System

### Automatic Context

The processor automatically updates player context:

```lua
processor:UpdatePlayerContext()

-- Context includes:
-- playerName         - Character name (no server)
-- playerFullName     - Character name with server
-- playerRole         - HEALER, TANK, or DAMAGER
-- playerClass        - Class token (WARRIOR, MAGE, etc.)
-- playerClassID      - Numeric class ID (1-13)
-- playerGroup        - Raid group number (1-8)
-- inRaid            - Boolean
-- inGroup           - Boolean
```

### Custom Context

You can set custom context for special scenarios:

```lua
-- Set custom context
processor:SetContext({
    playerName = "TestPlayer",
    playerRole = "HEALER",
    playerClass = "PRIEST",
    playerGroup = 2,
    encounterPhase = 2,  -- Custom field for phase tracking
})

-- Get current context
local context = processor:GetContext()

-- Process with override context
local filtered = processor:ProcessText(text, customContext)
```

## Built-in Conditional Tags

### Role Tags

Show content only to specific roles:

```lua
-- Healer-only content
{H}
Heal the tanks!
{/H}

-- Tank-only content
{T}
Taunt on 3 stacks
{/T}

-- DPS-only content
{D}
Burn boss at 30%
{/D}
```

Tags are case-insensitive: `{h}`, `{H}`, `{t}`, `{T}`, `{d}`, `{D}`

### Player Name Tags

Show content to specific players:

```lua
-- Single player
{P:Alice}
Alice: Soak mechanic 1
{/P}

-- Multiple players (comma-separated)
{P:Alice,Bob,Charlie}
Stack on marker 1
{/P}

-- Negated (show to everyone EXCEPT these players)
{!P:Alice}
Don't soak if you're Alice
{/P}
```

Player matching:
- Case-insensitive
- Handles server names automatically
- Strips color codes
- Supports abbreviated names

### Class Tags

Show content to specific classes:

```lua
-- Single class
{C:MAGE}
Mages: Use Time Warp
{/C}

-- Multiple classes
{C:MAGE,WARLOCK,PRIEST}
Casters: Stack for raid buff
{/C}

-- Negated (show to all EXCEPT these classes)
{!C:PALADIN,SHAMAN}
Non-support: Focus on DPS
{/C}

-- Abbreviations supported
{C:MAG,LOCK}
Ranged DPS: Spread out
{/C}

-- Class IDs work too
{C:8,9}  -- MAGE=8, WARLOCK=9
Int users: Stack
{/C}
```

Supported abbreviations:
- WAR = WARRIOR
- PAL = PALADIN
- HUN = HUNTER
- ROG = ROGUE
- PRI = PRIEST
- DK = DEATHKNIGHT
- SHAM = SHAMAN
- MAG = MAGE
- LOCK = WARLOCK
- DRU = DRUID
- DH = DEMONHUNTER
- DRAGON = EVOKER

### Group Tags

Show content to raid groups:

```lua
-- Single group
{G1}
Group 1: Go left
{/G}

-- Multiple groups (digits = OR condition)
{G123}
Groups 1, 2, 3: Stack middle
{/G}

-- Negated
{!G45}
Not groups 4-5: Stay spread
{/G}
```

### Race Tags

Show content to specific races:

```lua
-- Single race
{RACE:Human}
Humans: Use Every Man for Himself
{/RACE}

-- Multiple races
{RACE:NightElf,Tauren}
Elves and Tauren: Stack
{/RACE}

-- Negated
{!RACE:Gnome}
Non-gnomes: Do mechanic
{/RACE}
```

### Phase Tags

Show content during specific encounter phases:

```lua
{P1}
Phase 1: Focus adds
{/P}

{P2}
Phase 2: Burn boss
{/P}

{!P3}
Not phase 3: Save cooldowns
{/P}
```

**Note:** Requires `context.encounterPhase` or `context.phase` to be set.

### Everyone Tag

Always visible (useful as placeholder or for unconditional content):

```lua
{everyone}
This is shown to everyone
{/everyone}
```

## String-Based Processing

Process markup directly without AST parsing:

```lua
local text = "{H}Healers heal{/H} {T}Tanks taunt{/T}"
local filtered = processor:ProcessText(text)

-- Returns filtered text with irrelevant sections removed
```

This method:
- Works without NoteParser module
- Uses pattern matching (faster for simple cases)
- Supports all built-in tags
- Perfect for runtime note filtering

## AST-Based Processing

For advanced use with NoteParser:

```lua
local Parser = Loolib:GetModule("NoteParser")
local parser = Parser.Get()

-- Parse markup to AST
local ast = parser:Parse(text)

-- Process AST with conditions
local filteredAst = processor:Process(ast)

-- Flatten to node list
local nodes = processor:Flatten(filteredAst)

-- Render nodes
for _, node in ipairs(nodes) do
    if node.type == "TEXT" then
        print(node.text)
    end
end
```

AST processing:
- More powerful for complex conditions
- Preserves node structure
- Enables advanced rendering
- Requires NoteParser module

## Custom Condition Handlers

Register your own condition types:

```lua
-- Register handler
processor:RegisterHandler("MYTHICPLUS", function(node, context)
    -- Show only in M+ dungeons
    local _, instanceType = GetInstanceInfo()
    return instanceType == "party"
end)

-- Use in markup
{MYTHICPLUS}
This only shows in M+ dungeons
{/MYTHICPLUS}

-- Unregister when done
processor:UnregisterHandler("MYTHICPLUS")

-- Get all handlers (built-in + custom)
local handlers = processor:GetHandlers()
```

Handler function signature:
```lua
function(node, context)
    -- node: AST node with condition-specific fields
    -- context: Current evaluation context
    -- return: true to show content, false to hide
end
```

## Content Analysis

### Check Visibility

Check if markup has visible content for current player:

```lua
local text = "{H}Healer stuff{/H}"

if processor:HasVisibleContent(text) then
    print("This note has content for me")
else
    print("This note is not relevant to me")
end
```

### Extract Metadata

Extract information from markup:

```lua
local text = [[
{P:Alice,Bob} Assignment 1 {/P}
{C:MAGE,WARLOCK} Caster strategy {/C}
{G123} Groups 1-3 {/G}
{H} Healer {/H} {T} Tank {/T}
]]

-- Get all mentioned players
local players = processor:ExtractPlayerNames(text)
-- Returns: {"Alice", "Bob"}

-- Get all mentioned classes
local classes = processor:ExtractClasses(text)
-- Returns: {"MAGE", "WARLOCK"}

-- Get all mentioned roles
local roles = processor:ExtractRoles(text)
-- Returns: {"HEALER", "TANK"}

-- Get all mentioned groups
local groups = processor:ExtractGroups(text)
-- Returns: {1, 2, 3}
```

Use cases:
- Assignment validation
- Roster coverage checking
- Auto-generating assignment lists
- UI filtering/highlighting

## Performance

### Role Caching

Role detection is cached for 1 second to avoid expensive API calls:

```lua
-- First call: queries game API
processor:UpdatePlayerContext()

-- Calls within 1 second: uses cache
processor:UpdatePlayerContext()
processor:UpdatePlayerContext()

-- After 1 second: re-queries
```

### Efficient Processing

For best performance:

1. **Reuse processor instances:**
```lua
-- Good: Reuse singleton
local processor = NoteMarkup.Get()
processor:ProcessText(text1)
processor:ProcessText(text2)

-- Less efficient: Create new instances
LoolibCreateNoteMarkup():ProcessText(text1)
LoolibCreateNoteMarkup():ProcessText(text2)
```

2. **Use ProcessText for simple cases:**
```lua
-- Fast: Pattern matching
processor:ProcessText(simpleMarkup)

-- Slower: Full AST parsing (only if needed)
local ast = parser:Parse(complexMarkup)
processor:Process(ast)
```

3. **Cache context updates:**
```lua
-- Update context once
processor:UpdatePlayerContext()

-- Process multiple texts with same context
local text1Filtered = processor:ProcessText(text1)
local text2Filtered = processor:ProcessText(text2)
```

## Complete Example

```lua
local Loolib = LibStub("Loolib")
local NoteMarkup = Loolib:GetModule("NoteMarkup")
local processor = NoteMarkup.Get()

-- Raid note markup
local raidNote = [[
Boss Strategy - Mythic Difficulty

{H}
HEALERS:
- Dispel immediately (priority: tanks > DPS)
- Raid damage every 30 seconds
- Save cooldowns for Phase 2
{/H}

{T}
TANKS:
- Taunt at 3 stacks
- Face boss AWAY from raid
- Use major CD at 6 stacks
{/T}

{D}
DPS:
- Cleave adds when they spawn
- Focus boss when no adds
- Save burst for Phase 2
{/D}

{P:Alice,Bob}
SOAKERS (Alice, Bob):
- Stack on {rt1} marker
- Soak purple swirls
- Call out in voice when soaking
{/P}

{C:MAGE,WARLOCK}
CASTERS:
- Use Time Warp at Phase 2 start
- Stand max range
{/C}

{G12}
GROUPS 1 & 2:
- Go LEFT platform
- Kill left add first
{/G}

{G34}
GROUPS 3 & 4:
- Go RIGHT platform
- Kill right add first
{/G}

Everyone: Dodge bad stuff!
]]

-- Update player context
processor:UpdatePlayerContext()

-- Process note for current player
local personalNote = processor:ProcessText(raidNote)

-- Display in UI
noteFrame.Text:SetText(personalNote)

-- Check if player has any assignments
if processor:HasVisibleContent(raidNote) then
    -- Highlight player in roster
    ShowPlayerHasAssignment()
end

-- Extract all assigned players for coverage check
local assignedPlayers = processor:ExtractPlayerNames(raidNote)
local assignedClasses = processor:ExtractClasses(raidNote)

print("Assigned players:", table.concat(assignedPlayers, ", "))
print("Assigned classes:", table.concat(assignedClasses, ", "))
```

## Advanced: Custom Phase Tracking

```lua
-- Create custom processor for encounter tracking
local encounterProcessor = LoolibCreateNoteMarkup()

-- Track phase changes
local currentPhase = 1
local function OnPhaseChange(newPhase)
    currentPhase = newPhase
    encounterProcessor:SetContext({
        encounterPhase = newPhase,
    })

    -- Update note display
    UpdateNoteDisplay()
end

-- Encounter script
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterUnitEvent("UNIT_HEALTH", "boss1")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_START" then
        OnPhaseChange(1)
    elseif event == "UNIT_HEALTH" then
        local hp = UnitHealth("boss1") / UnitHealthMax("boss1")
        if hp < 0.7 and currentPhase == 1 then
            OnPhaseChange(2)
        elseif hp < 0.3 and currentPhase == 2 then
            OnPhaseChange(3)
        end
    end
end)

-- Process note with phase context
function UpdateNoteDisplay()
    encounterProcessor:UpdatePlayerContext()
    local filtered = encounterProcessor:ProcessText(raidNote)
    noteFrame:SetText(filtered)
end
```

## Integration with Other Modules

### With NoteParser

```lua
local Parser = Loolib:GetModule("NoteParser")
local Markup = Loolib:GetModule("NoteMarkup")

local parser = Parser.Get()
local processor = Markup.Get()

-- Full pipeline
local ast = parser:Parse(markupText)
local filteredAst = processor:Process(ast)
local nodes = processor:Flatten(filteredAst)

-- Render nodes with custom renderer
for _, node in ipairs(nodes) do
    RenderNode(node, frame)
end
```

### With SavedVariables

```lua
local Loolib = LibStub("Loolib")
local addon = Loolib:NewAddon("MyNoteAddon")

-- Store note in saved variables
function addon:SaveNote(noteName, noteText)
    self.db.notes = self.db.notes or {}
    self.db.notes[noteName] = noteText
end

-- Load and process note
function addon:ShowNote(noteName)
    local noteText = self.db.notes[noteName]
    if not noteText then return end

    local Markup = Loolib:GetModule("NoteMarkup")
    local processor = Markup.Get()
    processor:UpdatePlayerContext()

    local filtered = processor:ProcessText(noteText)
    self.noteFrame:SetText(filtered)
end
```

## Module API Reference

### Factory Functions

```lua
-- Create new processor instance
local processor = LoolibCreateNoteMarkup()

-- Get singleton instance
local processor = LoolibGetNoteMarkup()

-- Via module
local NoteMarkup = Loolib:GetModule("NoteMarkup")
local processor = NoteMarkup.Create()
local processor = NoteMarkup.Get()
```

### Core Methods

```lua
-- Context management
processor:SetContext(context)
processor:GetContext()
processor:UpdatePlayerContext()

-- String processing
local filtered = processor:ProcessText(text [, context])

-- AST processing (requires NoteParser)
local filteredAst = processor:Process(ast [, context])
local nodes = processor:Flatten(ast)

-- Custom handlers
processor:RegisterHandler(conditionType, handlerFunc)
processor:UnregisterHandler(conditionType)
local handlers = processor:GetHandlers()

-- Condition evaluation
local show = processor:EvaluateCondition(node [, context])

-- Content analysis
local hasContent = processor:HasVisibleContent(text)
local players = processor:ExtractPlayerNames(text)
local classes = processor:ExtractClasses(text)
local roles = processor:ExtractRoles(text)
local groups = processor:ExtractGroups(text)
```

### Module Fields

```lua
NoteMarkup.Mixin              -- LoolibNoteMarkupMixin
NoteMarkup.Create             -- Factory function
NoteMarkup.Get                -- Singleton accessor
NoteMarkup.BuiltInHandlers    -- Built-in handler map
```

## Condition Node Structure

Nodes passed to handlers have this structure:

```lua
-- Role condition
{
    condition = "ROLE",
    role = "HEALER" | "TANK" | "DAMAGER"
}

-- Player condition
{
    condition = "PLAYER",
    player = "Alice,Bob",  -- Comma-separated
    negate = false | true  -- ! prefix
}

-- Class condition
{
    condition = "CLASS",
    class = "MAGE,WARLOCK",  -- Comma-separated
    negate = false | true
}

-- Group condition
{
    condition = "GROUP",
    group = 1 | 123,  -- Single digit or multi-digit
    negate = false | true
}

-- Custom condition
{
    condition = "CUSTOMTYPE",
    -- Custom fields added by parser/handler
}
```

## See Also

- [NoteParser.md](NoteParser.md) - Markup parsing and AST generation
- [NoteRenderer.md](NoteRenderer.md) - Rendering notes to UI
- [Config.md](Config.md) - Note configuration options
- [SavedVariables.md](SavedVariables.md) - Storing notes
