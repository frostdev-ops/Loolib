# Note System

The Note System provides MRT-compatible conditional markup rendering for raid notes. It enables raid leaders to create dynamic notes that show different content based on player role, name, class, group assignment, and other conditions, with support for countdown timers, spell icons, and raid markers.

## Overview

### What It Does

The Note System is a complete rendering pipeline for conditional raid notes:
- Parse MRT-style markup tags into an Abstract Syntax Tree (AST)
- Evaluate conditionals based on player context (role, name, class, group)
- Render formatted text with embedded icons, spell textures, and countdown timers
- Display notes in a draggable, combat-aware frame
- Track encounter timers with countdown integration

### Common Use Cases

- **Role-specific instructions**: Show different tactics to tanks, healers, and DPS
- **Player assignments**: Display personalized notes to specific players
- **Boss timers**: Countdown to abilities with visual alerts
- **Class callouts**: Target instructions at specific classes
- **Group assignments**: Coordinate raid group positioning
- **Encounter phases**: Show/hide content based on boss phase

### Key Features

- **MRT compatibility**: Uses MethodRaidTools markup syntax
- **Full pipeline**: Parser → Markup → Renderer → Display
- **Rich formatting**: Spell icons, raid markers, role icons, class colors
- **Live timers**: Encounter-based countdowns with color-coded warnings
- **Conditional rendering**: Hide/show content based on player context
- **Extensible**: Register custom tag handlers and conditions

## Quick Start

```lua
-- Get the Note System modules
local Loolib = LibStub("Loolib")
local NoteFrame = Loolib:GetModule("NoteFrame")

-- Create a note frame
local noteFrame = NoteFrame.Create(UIParent, "MyRaidNote")
noteFrame:SetPoint("CENTER", 0, 0)
noteFrame:SetSize(400, 300)

-- Set note text with conditionals
noteFrame:SetText([[
{H}Healers: Dispel {spell:123456} immediately!{/H}
{T}Tanks: Taunt swap at {time:30}{/T}
{P:Alice,Bob}You interrupt {skull}!{/P}
{C:MAGE,WARLOCK}Bloodlust at {time:1:30}{/C:}
]])

-- Show the note
noteFrame:Show()
```

## Markup Syntax Reference

### Role Conditionals

Show content only to specific roles.

| Tag | Role | Example |
|-----|------|---------|
| `{H}...{/H}` | Healers | `{H}Keep raid above 80%{/H}` |
| `{T}...{/T}` | Tanks | `{T}Face boss away from raid{/T}` |
| `{D}...{/D}` | DPS/Damagers | `{D}Burn adds quickly{/D}` |

**Example:**
```
{H}Heal tank through {spell:12345}{/H}
{T}Taunt at 3 stacks{/T}
{D}Focus {skull} first{/D}
```

### Player Conditionals

Show content to specific players by name.

| Tag | Matches | Example |
|-----|---------|---------|
| `{P:name}...{/P}` | Player with name | `{P:Alice}You soak{/P}` |
| `{!P:name}...{/P}` | Everyone except player | `{!P:Bob}Bob soaks{/P}` |
| `{P:name1,name2}...{/P}` | Multiple players | `{P:Alice,Bob}Interrupt{/P}` |

**Notes:**
- Player names are case-insensitive
- Server names are automatically stripped
- Supports comma-separated lists

**Example:**
```
{P:Alice}You take {star}{/P}
{P:Bob,Charlie}You take {circle}{/P}
{!P:Alice,Bob,Charlie}Stack on {triangle}{/P}
```

### Class Conditionals

Show content to specific classes.

| Tag | Matches | Example |
|-----|---------|---------|
| `{C:CLASS}...{/C}` | Class token | `{C:WARRIOR}Execute{/C}` |
| `{!C:CLASS}...{/C}` | All except class | `{!C:PRIEST}Avoid{/C}` |
| `{C:CLASS1,CLASS2}...{/C}` | Multiple classes | `{C:MAGE,LOCK}Lust{/C}` |

**Supported formats:**
- Full class name: `WARRIOR`, `PALADIN`, `HUNTER`, `ROGUE`, `PRIEST`, `DEATHKNIGHT`, `SHAMAN`, `MAGE`, `WARLOCK`, `DRUID`, `DEMONHUNTER`, `EVOKER`
- Abbreviations: `WAR`, `PAL`, `HUN`, `ROG`, `PRI`, `DK`, `SHAM`, `MAG`, `LOCK`, `DRU`, `DH`, `DRAGON`
- Class IDs: `1`-`12` (numeric)

**Example:**
```
{C:WARRIOR,PALADIN}Use defensive cooldown{/C}
{C:MAGE}Spellsteal the buff{/C}
{!C:HUNTER}Hunters handle adds{/C}
```

### Group Conditionals

Show content to specific raid groups (1-8).

| Tag | Matches | Example |
|-----|---------|---------|
| `{G1}...{/G}` | Group 1 | `{G1}Left side{/G}` |
| `{G2}...{/G}` | Group 2 | `{G2}Right side{/G}` |
| `{G123}...{/G}` | Groups 1, 2, or 3 | `{G123}Melee groups{/G}` |

**Example:**
```
{G1}Take position at {star}{/G}
{G2}Take position at {circle}{/G}
{G345}Ranged spread out{/G}
{G678}Healers in center{/G}
```

### Everyone Tag

Always shows content (useful for resetting conditionals).

| Tag | Purpose |
|-----|---------|
| `{everyone}...{/everyone}` | Always visible to all |

### Timer Tags

Display countdown timers that update during encounters.

| Format | Description | Example |
|--------|-------------|---------|
| `{time:seconds}` | Countdown in seconds | `{time:30}` = "30" |
| `{time:min:sec}` | Countdown with minutes | `{time:1:30}` = "1:30" |
| `{time:sec,options}` | Timer with options | `{time:30,glow}` |

**Timer Options (comma-separated):**
- `p:N` or `pN` - Start timer when phase N begins
- `glow` - Glow effect when timer reaches 0
- `all` - Show timer to all players (not just targeted)
- `wa:eventName` - Trigger WeakAura event when timer fires

**Timer Colors:**
- Gray (waiting): Timer not started
- Yellow: Timer running (> 5 seconds)
- Green: Imminent (≤ 5 seconds)
- Dark gray: Expired

**Example:**
```
Boss ability in {time:45}
Tank swap at {time:30,glow}
Phase 2 starts in {time:2:00,p2,wa:Phase2}
```

### Spell Icons

Display spell icons inline with text.

| Format | Description | Example |
|--------|-------------|---------|
| `{spell:spellId}` | Spell icon at font size | `{spell:12345}` |
| `{spell:spellId:size}` | Spell icon at custom size | `{spell:12345:16}` |

**Example:**
```
Dispel {spell:8122} immediately!
Interrupt {spell:2139} on cooldown
Stack for {spell:64843:20}
```

### Raid Target Icons

Display raid marker icons.

| Numbered Tags | Named Tags | Icon |
|---------------|------------|------|
| `{rt1}` | `{star}` | Star |
| `{rt2}` | `{circle}` | Circle |
| `{rt3}` | `{diamond}` | Diamond |
| `{rt4}` | `{triangle}` | Triangle |
| `{rt5}` | `{moon}` | Moon |
| `{rt6}` | `{square}` | Square |
| `{rt7}` | `{cross}` or `{x}` | Cross/X |
| `{rt8}` | `{skull}` | Skull |

**Example:**
```
Tanks on {skull} and {x}
Melee on {star}, ranged on {circle}
Soak {diamond} marker
```

### Role Icons

Display role icons.

| Tag | Icon |
|-----|------|
| `{tank}` | Tank icon |
| `{healer}` | Healer icon |
| `{dps}` | DPS icon |

**Example:**
```
{tank} Shield wall on pull
{healer} Cooldown rotation: 1-2-3
{dps} Burn phase at 30%
```

### Self Placeholder

Replaced with the player's personal note text.

| Tag | Purpose |
|-----|---------|
| `{self}` | Player's custom note |

**Example:**
```lua
-- Set personal note
noteFrame:SetSelfText("I handle adds")

-- In note text
Your assignment: {self}
-- Displays: "Your assignment: I handle adds"
```

### Custom Icons

Display custom textures from file paths.

| Format | Description |
|--------|-------------|
| `{icon:path}` | Custom texture at font size |

**Example:**
```
{icon:Interface\\Icons\\Ability_Warrior_BattleShout}
```

## Components

The Note System consists of five integrated modules:

### NoteParser

Tokenizes markup text and builds an Abstract Syntax Tree.

**Key Methods:**
```lua
local parser = LoolibGetNoteParser()

-- Parse markup to AST
local ast = parser:Parse(markupText)

-- Tokenize only (for debugging)
local tokens = parser:Tokenize(markupText)

-- Serialize AST back to markup
local text = parser:Serialize(ast)

-- Debug print AST structure
local debug = parser:DebugPrint(ast)
```

**AST Node Types:**
- `ROOT` - Document root
- `TEXT` - Plain text
- `CONDITIONAL` - Role/player/class/group conditional
- `ICON` - Raid marker or role icon
- `SPELL` - Spell icon
- `TIMER` - Countdown timer
- `SELF` - Self-text placeholder

### NoteMarkup

Evaluates conditionals and filters AST based on player context.

**Key Methods:**
```lua
local markup = LoolibGetNoteMarkup()

-- Update player context (role, class, name, group)
markup:UpdatePlayerContext()

-- Set custom context
markup:SetContext({
    playerName = "Alice",
    playerRole = "HEALER",
    playerClass = "PRIEST",
    playerGroup = 1,
    encounterPhase = 2,
})

-- Process AST (filter by conditionals)
local processed = markup:Process(ast)

-- Flatten to leaf nodes
local nodes = markup:Flatten(processed)

-- Simple text processing (no AST)
local filtered = markup:ProcessText(markupText)
```

**Context Fields:**
- `playerName` - Player name (short, without server)
- `playerRole` - `"HEALER"`, `"TANK"`, or `"DAMAGER"`
- `playerClass` - Class token (e.g., `"WARRIOR"`)
- `playerGroup` - Raid group number (1-8)
- `encounterPhase` - Current boss phase
- `inRaid` - Boolean, in raid group
- `inGroup` - Boolean, in any group

### NoteRenderer

Renders AST nodes to formatted WoW text with icons and colors.

**Key Methods:**
```lua
local renderer = LoolibGetNoteRenderer()

-- Render processed AST to string
local text = renderer:Render(processedAst)

-- Configure renderer
renderer:SetSelfText("My assignment")
renderer:SetAutoColorNames(true)  -- Color player names by class
renderer:SetDefaultIconSize(16)   -- Icon size in pixels (0 = font height)

-- Manual icon rendering
local icon = renderer:GetRaidTargetIcon(1)  -- Star
local role = renderer:GetRoleIcon("TANK")
local spell = renderer:RenderSpell(12345, 16)

-- Color utilities
local colored = renderer:ColorName("Alice", "PRIEST")
local text = renderer:ColorText("Warning!", 1, 0, 0)
local plain = renderer:StripFormatting(text)
```

### NoteTimer

Manages encounter-based countdown timers.

**Key Methods:**
```lua
local timer = LoolibGetNoteTimer()

-- Encounter lifecycle
timer:StartEncounter()  -- Start encounter time tracking
timer:EndEncounter()    -- Stop all timers
timer:SetPhase(2)       -- Update encounter phase

-- Timer registration
local timerInfo = timer:RegisterTimer("myTimer", 30, {
    phase = 1,      -- Start in phase 1
    glow = true,    -- Glow effect at 0
    wa = "MyEvent", -- WeakAura event
})

-- Timer queries
local elapsed = timer:GetEncounterTime()
local phaseTime = timer:GetPhaseTime(2)
local isActive = timer:IsInEncounter()

-- Render timer to string
local timeStr = timer:FormatTimer(30, "RUNNING")  -- "30" in yellow
```

**Timer Events (Callback Registry):**
- `OnTimerStart` - Encounter started
- `OnTimerTick` - Every 0.1 seconds during encounter
- `OnTimerImminent` - Timer reached 5 seconds
- `OnTimerExpire` - Timer reached 0
- `OnTimerGlow` - Glow effect triggered

### NoteFrame

Display frame with full rendering pipeline and event handling.

**Key Methods:**
```lua
local frame = LoolibCreateNoteFrame(UIParent, "MyNote")

-- Text management
frame:SetText(markupText)
frame:SetSelfText("My assignment")

-- Appearance
frame:SetFontSize(14)
frame:SetFontFace("Fonts\\FRIZQT__.TTF")
frame:SetTextColor(1, 1, 1, 1)
frame:SetBackgroundColor(0, 0, 0, 0.8)
frame:SetBackgroundAlpha(0.5)

-- Lock/unlock for dragging
frame:SetLocked(false)  -- Unlocked = draggable with border
frame:SetLocked(true)   -- Locked = no interaction

-- Visibility rules
frame:SetVisible(true)
frame:SetCombatVisibility(true, false)  -- Show in combat only
frame:UpdateVisibility()

-- Encounter integration
frame:OnEncounterStart(2424, "Gnarlroot")
frame:OnPhaseChange(2)
frame:OnEncounterEnd()

-- Visual effects
frame:ShowGlow(1.5)  -- 1.5 second glow

-- Sizing
frame:SetSize(400, 300)
frame:SetContentWidth(350)
```

**Automatic Event Handling:**
- `ENCOUNTER_START` / `ENCOUNTER_END` - Starts/stops timers
- `PLAYER_REGEN_DISABLED` / `ENABLED` - Combat visibility
- `GROUP_ROSTER_UPDATE` - Updates player context

## Usage Examples

### Healer-Only Instructions

```lua
local noteText = [[
{H}
=== HEALER ASSIGNMENTS ===
Phase 1: Rotate cooldowns
  1. {spell:64843} at pull
  2. {spell:98008} at {time:30}
  3. {spell:64901} at {time:1:00}

Phase 2: Keep raid above 80%
  Dispel {spell:123456} immediately!
{/H}
]]

noteFrame:SetText(noteText)
```

### Tank Swap Reminder

```lua
local noteText = [[
{T}
TANK MECHANICS:
- Taunt swap at 3 stacks of {spell:123456}
- Face boss AWAY from raid
- Use major cooldown at {time:45}

{P:Alice}You taunt first{/P}
{P:Bob}You taunt second{/P}
{/T}
]]

noteFrame:SetText(noteText)
```

### Countdown Timer for Boss Ability

```lua
local noteText = [[
Boss casts {spell:123456} in {time:90,glow,wa:BigAbility}

{H}Stack for healing{/H}
{T}Use major defensive{/T}
{D}Hero/Bloodlust NOW!{/D}
]]

-- Start encounter to activate timer
local timer = LoolibGetNoteTimer()
timer:StartEncounter()
```

### Class-Specific Assignments

```lua
local noteText = [[
=== INTERRUPT ROTATION ===

{C:WARRIOR}1st interrupt: {spell:6552}{/C}
{C:ROGUE}2nd interrupt: {spell:1766}{/C}
{C:MAGE}3rd interrupt: {spell:2139}{/C}
{C:PALADIN,DEATHKNIGHT}Backup interrupts{/C}

{!C:WARRIOR,ROGUE,MAGE,PALADIN,DEATHKNIGHT}
Focus on damage - no interrupts
{/C}
]]

noteFrame:SetText(noteText)
```

### Full Raid Note with Multiple Conditionals

```lua
local noteText = [[
=== GNARLROOT TACTICS ===

{everyone}
Kill priority: {skull} > {x} > {star}
Spread for {spell:123456}
{/everyone}

{T}
TANKS:
- Taunt at 3 stacks of {spell:421840}
- Face boss NORTH
- Tank swap at {time:30,p1,glow}
{/T}

{H}
HEALERS:
- Dispel {spell:421898} instantly
- Major cooldown at {time:1:00,p1}
- {P:Carol,Dave}Focus tank healing{/P}
- {P:Eve,Frank}Raid healing{/P}
{/H}

{D}
DPS:
- Burn {skull} in P1
- Save CDs for P2
- {C:MAGE,WARLOCK}Lust at {time:2:30,p2}{/C}
{/D}

{G1}Group 1: Left side at {star}{/G}
{G2}Group 2: Right side at {circle}{/G}
{G3}Group 3: Back at {triangle}{/G}

Your assignment: {self}
]]

noteFrame:SetText(noteText)
noteFrame:SetSelfText("Soak purple swirls")
```

### Encounter Integration

```lua
-- Create note frame
local frame = LoolibCreateNoteFrame(UIParent, "RaidNote")
frame:SetPoint("TOP", 0, -100)
frame:SetSize(400, 300)
frame:SetLocked(true)
frame:SetCombatVisibility(true, false)  -- Combat only

-- Set note with phase-based timers
frame:SetText([[
Phase 1:
  Tank swap at {time:30,p1}
  Adds spawn at {time:1:00,p1}

Phase 2 ({time:1:30,p1} until transition):
  Hero at transition!

Phase 3:
  Burn boss, dodge swirls
  {time:45,p3} until berserk
]])

-- The frame automatically handles ENCOUNTER_START/END events
-- Timers start counting when encounter begins
```

### Custom Context and Preview

```lua
-- Preview note as different roles/players
local markup = LoolibGetNoteMarkup()
local renderer = LoolibGetNoteRenderer()
local parser = LoolibGetNoteParser()

local noteText = [[
{H}Healer instruction{/H}
{T}Tank instruction{/T}
{P:Alice}Alice's job{/P}
]]

-- Preview as healer
markup:SetContext({
    playerRole = "HEALER",
    playerName = "Bob",
    playerClass = "PRIEST",
})
local ast = parser:Parse(noteText)
local processed = markup:Process(ast)
local rendered = renderer:Render(processed)
print("As Healer Bob:", rendered)
-- Output: "Healer instruction"

-- Preview as tank named Alice
markup:SetContext({
    playerRole = "TANK",
    playerName = "Alice",
    playerClass = "WARRIOR",
})
processed = markup:Process(parser:Parse(noteText))
print("As Tank Alice:", renderer:Render(processed))
-- Output: "Tank instruction\nAlice's job"
```

## Extending the System

### Registering Custom Tag Handlers

You can extend the markup system with custom conditionals.

```lua
local markup = LoolibGetNoteMarkup()

-- Register a custom condition handler
-- Tag syntax: {MYTHIC}...{/MYTHIC}
markup:RegisterHandler("MYTHIC", function(node, context)
    local difficultyId = select(3, GetInstanceInfo())
    return difficultyId == 16  -- 16 = Mythic
end)

-- Now you can use {MYTHIC} tags
local noteText = [[
{everyone}Normal tactics{/everyone}
{MYTHIC}Extra mechanic on Mythic!{/MYTHIC}
]]
```

**Custom Handler Signature:**
```lua
function handler(node, context)
    -- node: AST node with condition properties
    -- context: Current player context table
    return true  -- Show content
    return false -- Hide content
end
```

### Race Condition Example

```lua
markup:RegisterHandler("RACE", function(node, context)
    local playerRace = context.playerRace
    if not playerRace then
        local _, raceToken = UnitRace("player")
        playerRace = raceToken
        context.playerRace = playerRace
    end

    -- node.race contains the race name from tag
    -- Supports comma-separated: {RACE:Human,Dwarf}
    local races = {strsplit(",", node.race)}
    for _, race in ipairs(races) do
        if race:upper() == playerRace:upper() then
            return not node.negate
        end
    end

    return node.negate or false
end)

-- Usage: {RACE:Human}Humans only!{/RACE}
```

### Item Level Condition

```lua
markup:RegisterHandler("ILVL", function(node, context)
    local avgItemLevel = GetAverageItemLevel()
    local required = tonumber(node.ilvl) or 0

    if node.operator == ">=" then
        return avgItemLevel >= required
    elseif node.operator == ">" then
        return avgItemLevel > required
    elseif node.operator == "<" then
        return avgItemLevel < required
    else
        return avgItemLevel >= required
    end
end)

-- Would require parser extension to support:
-- {ILVL:480:>=}High ilvl strat{/ILVL}
```

## Events

The Timer system uses Callback Registry for event notifications.

### Registering Callbacks

```lua
local timer = LoolibGetNoteTimer()

-- Register for timer events
timer:RegisterCallback("OnTimerTick", function(encounterTime)
    print("Encounter time:", encounterTime)
end, self)

timer:RegisterCallback("OnTimerImminent", function(timerId, timerInfo)
    print("Timer", timerId, "is about to expire!")
end, self)

timer:RegisterCallback("OnTimerExpire", function(timerId, timerInfo)
    print("Timer", timerId, "expired!")
end, self)

timer:RegisterCallback("OnTimerGlow", function(timerId, timerInfo)
    -- Show visual alert
    PlaySound(SOUNDKIT.ALARM_CLOCK_WARNING_3)
end, self)
```

### WeakAura Integration

Timers can trigger WeakAura events for custom alerts.

```lua
-- In note text
local noteText = [[
Big ability in {time:45,wa:BigAbility}
]]

-- Set WeakAura callback
timer:SetWeakAuraCallback(function(eventName, timeleft, timer)
    print("WA Event:", eventName, "Time:", timeleft)
    -- Custom handling here
end)

-- The timer automatically calls WeakAuras.ScanEvents() if available:
-- WeakAuras.ScanEvents("LOOLIB_NOTE_TIME_EVENT", "BigAbility", 5, "message")
-- WeakAuras.ScanEvents("MRT_NOTE_TIME_EVENT", "BigAbility", 5, "message")
```

### Glow Effect Callback

```lua
timer:SetGlowCallback(function(timerId, timerInfo)
    -- Custom glow logic
    if timerInfo.all then
        -- Show to everyone
        RaidNotice_AddMessage(RaidWarningFrame, "TIMER EXPIRED!", ChatTypeInfo["RAID_WARNING"])
    end
end)
```

## API Reference

### Module Access

```lua
local Loolib = LibStub("Loolib")

-- Get modules
local NoteParser = Loolib:GetModule("NoteParser")
local NoteMarkup = Loolib:GetModule("NoteMarkup")
local NoteRenderer = Loolib:GetModule("NoteRenderer")
local NoteTimer = Loolib:GetModule("NoteTimer")
local NoteFrame = Loolib:GetModule("NoteFrame")

-- Get singleton instances
local parser = NoteParser.Get()
local markup = NoteMarkup.Get()
local renderer = NoteRenderer.Get()
local timer = NoteTimer.Get()

-- Create instances
local myParser = NoteParser.Create()
local myMarkup = NoteMarkup.Create()
local myRenderer = NoteRenderer.Create()
local myTimer = NoteTimer.Create()
local myFrame = NoteFrame.Create(parent, name)
```

### NoteParser API

```lua
-- Parsing
local ast = parser:Parse(text)
local tokens = parser:Tokenize(text)

-- Serialization
local markup = parser:Serialize(ast)
local debug = parser:DebugPrint(ast, indent)

-- Factory
local parser = LoolibCreateNoteParser()
local parser = LoolibGetNoteParser()  -- Singleton

-- Constants
LoolibNoteTokenTypes  -- Token type constants
LoolibNoteNodeTypes   -- AST node type constants
```

### NoteMarkup API

```lua
-- Context
markup:SetContext(contextTable)
local context = markup:GetContext()
markup:UpdatePlayerContext()

-- Processing
local processed = markup:Process(ast, context)
local nodes = markup:Flatten(processed)
local text = markup:ProcessText(markupText, context)

-- Conditionals
local shouldShow = markup:EvaluateCondition(node, context)

-- Custom handlers
markup:RegisterHandler(conditionType, handlerFunc)
markup:UnregisterHandler(conditionType)
local handlers = markup:GetHandlers()

-- Utilities
local hasContent = markup:HasVisibleContent(text)
local names = markup:ExtractPlayerNames(text)
local classes = markup:ExtractClasses(text)
local roles = markup:ExtractRoles(text)
local groups = markup:ExtractGroups(text)

-- Factory
local markup = LoolibCreateNoteMarkup()
local markup = LoolibGetNoteMarkup()  -- Singleton
```

### NoteRenderer API

```lua
-- Rendering
local text = renderer:Render(ast)
local text = renderer:RenderNode(node)

-- Configuration
renderer:SetSelfText(text)
renderer:SetAutoColorNames(enabled)
renderer:SetDefaultIconSize(size)
renderer:SetTimerRenderer(timerObj)
renderer:UpdateRaidRoster()

-- Icons
local icon = renderer:GetRaidTargetIcon(index)
local icon = renderer:GetRoleIcon(role)
local icon = renderer:CreateIcon(path, size)
local spell = renderer:RenderSpell(spellId, size)

-- Colors
local colored = renderer:ColorName(name, classToken)
local text = renderer:ColorText(text, r, g, b)
local hex = renderer:GetClassColor(classToken)
local plain = renderer:StripColors(text)
local plain = renderer:StripTextures(text)
local plain = renderer:StripFormatting(text)

-- Factory
local renderer = LoolibCreateNoteRenderer()
local renderer = LoolibGetNoteRenderer()  -- Singleton

-- Constants
LoolibNoteRaidTargetIcons  -- Icon texture strings
LoolibNoteRoleIcons        -- Role icon texture strings
LoolibNoteClassColors      -- Class color hex codes
```

### NoteTimer API

```lua
-- Encounter management
timer:StartEncounter(encounterTime)
timer:EndEncounter()
timer:SetPhase(phase, phaseTime)
local elapsed = timer:GetEncounterTime()
local phaseTime = timer:GetPhaseTime(phase)
local inEncounter = timer:IsInEncounter()

-- Timer registration
local timerInfo = timer:RegisterTimer(timerId, totalSeconds, options)
local info = timer:GetTimer(timerId)
timer:ClearTimers()

-- Rendering
local text = timer:RenderTimer(node)
local text = timer:FormatTimer(remaining, state)

-- Callbacks
timer:SetGlowCallback(function(timerId, timer) end)
timer:SetWeakAuraCallback(function(eventName, timeleft, timer) end)

-- Callback registry
timer:RegisterCallback("OnTimerTick", function(encounterTime) end, self)
timer:RegisterCallback("OnTimerImminent", function(timerId, timer) end, self)
timer:RegisterCallback("OnTimerExpire", function(timerId, timer) end, self)
timer:RegisterCallback("OnTimerGlow", function(timerId, timer) end, self)

-- Reset
timer:Reset()

-- Factory
local timer = LoolibCreateNoteTimer()
local timer = LoolibGetNoteTimer()  -- Singleton

-- Constants
LoolibNoteTimerStates   -- WAITING, RUNNING, IMMINENT, EXPIRED
LoolibNoteTimerColors   -- Color codes by state
```

### NoteFrame API

```lua
-- Text management
frame:SetText(markupText)
frame:SetSelfText(text)
local text = frame:GetText()
local self = frame:GetSelfText()
frame:Update()

-- Appearance
frame:SetFontSize(size)
frame:SetFontFace(fontPath)
frame:SetTextColor(r, g, b, a)
frame:SetBackgroundColor(r, g, b, a)
frame:SetBackgroundAlpha(alpha)
local size = frame:GetFontSize()
local path = frame:GetFontFace()
local r, g, b, a = frame:GetTextColor()
local r, g, b, a = frame:GetBackgroundColor()
local alpha = frame:GetBackgroundAlpha()

-- Lock/unlock
frame:SetLocked(locked)
local locked = frame:IsLocked()

-- Visibility
frame:SetVisible(visible)
frame:SetCombatVisibility(showInCombat, showOutOfCombat)
frame:UpdateVisibility()
local visible = frame:IsVisible()
local inCombat, outCombat = frame:GetCombatVisibility()

-- Effects
frame:ShowGlow(duration)

-- Encounter integration
frame:OnEncounterStart(encounterId, encounterName)
frame:OnEncounterEnd()
frame:OnPhaseChange(phase)

-- Sizing
frame:SetContentWidth(width)
local width = frame:GetContentWidth()

-- Factory
local frame = LoolibCreateNoteFrame(parent, name)
```

## Best Practices

### Performance

**Cache instances:**
```lua
-- GOOD: Create once, reuse
local parser = LoolibGetNoteParser()
local markup = LoolibGetNoteMarkup()
local renderer = LoolibGetNoteRenderer()

function UpdateNote()
    local ast = parser:Parse(noteText)
    local processed = markup:Process(ast)
    local rendered = renderer:Render(processed)
end
```

**Update context efficiently:**
```lua
-- Context is cached for 1 second
markup:UpdatePlayerContext()  -- Only updates if needed
```

**Batch roster updates:**
```lua
-- Roster is cached for 5 seconds
renderer:UpdateRaidRoster()  -- Only updates if needed
```

### Memory Management

**Clean up timers:**
```lua
function OnEncounterEnd()
    timer:EndEncounter()  -- Stops all timers
    timer:ClearTimers()   -- Clears timer storage
end
```

**Reuse frames:**
```lua
-- GOOD: One frame, update text
noteFrame:SetText(newNote)

-- BAD: Creating frames repeatedly
for i = 1, 10 do
    local frame = LoolibCreateNoteFrame()  -- Memory leak!
end
```

### Markup Organization

**Use clear structure:**
```lua
local noteText = [[
=== BOSS NAME ===

{everyone}
General mechanics for all players
{/everyone}

{T}Tank-specific instructions{/T}
{H}Healer-specific instructions{/H}
{D}DPS-specific instructions{/D}

{P:PlayerName}Personal assignment{/P}
]]
```

**Group related conditionals:**
```lua
-- GOOD: Grouped
{C:MAGE,WARLOCK}
  Bloodlust rotation:
  - {P:Alice}Lust at pull{/P}
  - {P:Bob}Lust at 30%{/P}
{/C}

-- BAD: Scattered
{C:MAGE,WARLOCK}{P:Alice}Lust at pull{/P}{/C}
{C:MAGE,WARLOCK}{P:Bob}Lust at 30%{/P}{/C}
```

### Timer Usage

**Start timers on encounter start:**
```lua
-- Frame automatically handles this
frame:OnEncounterStart(encounterId, name)

-- Or manually
timer:StartEncounter()
```

**Use phase-based timers:**
```lua
-- Timer starts when phase 2 begins
{time:45,p2}
```

**Add glow for important timers:**
```lua
-- Visual alert at 0 seconds
{time:30,glow}
```

### Testing Notes

**Preview as different roles:**
```lua
local function PreviewNote(noteText, role, name, class)
    local markup = LoolibGetNoteMarkup()
    local parser = LoolibGetNoteParser()
    local renderer = LoolibGetNoteRenderer()

    markup:SetContext({
        playerRole = role,
        playerName = name,
        playerClass = class,
    })

    local ast = parser:Parse(noteText)
    local processed = markup:Process(ast)
    local rendered = renderer:Render(processed)

    print(string.format("=== As %s %s (%s) ===", role, name, class))
    print(rendered)
end

PreviewNote(noteText, "TANK", "Alice", "WARRIOR")
PreviewNote(noteText, "HEALER", "Bob", "PRIEST")
PreviewNote(noteText, "DAMAGER", "Carol", "MAGE")
```

## Technical Details

### Parsing Pipeline

1. **Tokenization**: Raw text → Token stream
2. **AST Building**: Tokens → Abstract Syntax Tree
3. **Conditional Evaluation**: AST → Filtered AST (based on context)
4. **Rendering**: Filtered AST → Formatted WoW text

### AST Structure

```lua
{
    type = "ROOT",
    children = {
        { type = "TEXT", text = "Hello " },
        {
            type = "CONDITIONAL",
            condition = "ROLE",
            role = "HEALER",
            children = {
                { type = "TEXT", text = "Healer!" }
            }
        },
        { type = "TIMER", minutes = 1, seconds = 30 },
        { type = "SPELL", spellId = 12345, size = 16 },
        { type = "ICON", iconType = "RAID_TARGET", index = 1 },
    }
}
```

### Timer State Machine

```
WAITING → RUNNING → IMMINENT → EXPIRED
  ↓         ↓           ↓         ↓
 Gray    Yellow      Green    Dark Gray
```

### Context Caching

- **Role cache**: 1 second (expensive spec lookup)
- **Raid roster cache**: 5 seconds (API call limit)
- **WeakAura event cache**: Per-encounter (prevent duplicates)

### WoW Escape Sequences

The renderer generates WoW formatting codes:

**Colors:**
```lua
"|cFFRRGGBB" .. text .. "|r"  -- RGB color
```

**Textures:**
```lua
"|Tpath:size:width:height:xOffset:yOffset:texWidth:texHeight:left:right:top:bottom|t"
-- Simplified: "|Tpath:size|t"
```

**Examples:**
```lua
"|cFFFFFF00Yellow Text|r"  -- Yellow
"|TInterface\\Icons\\Spell_Nature_Lightning:16|t"  -- Lightning icon, 16px
"|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t"  -- Star, font height
```

### Safety and Hardening

- **Parser depth limit**: Nested conditionals deeper than 20 levels are truncated with an error marker. This prevents stack overflows from deeply nested or malicious note text.
- **Parser error recovery**: Unmatched closing tags are emitted as literal text instead of aborting the parse.
- **Whitespace normalisation**: Leading/trailing whitespace is trimmed by the parser.
- **Pattern injection protection**: User text passed to `string.gsub` patterns is escaped to prevent Lua pattern errors.
- **WoW escape handling**: Literal pipes (`||`) and standard WoW text escapes are handled during markup processing.
- **Timer drift prevention**: Remaining time is always calculated from `GetTime() - startTime` rather than accumulated decrements.
- **Timer pause on hide**: The timer update loop is paused when the NoteFrame is hidden and resumes on show.
- **Auto-size support**: `NoteFrame:SetAutoSize(true)` lets the frame height track content size dynamically.
- **Word wrap**: Long lines are word-wrapped and non-space-wrapped to prevent text overflow.

## Per-Module Documentation

| Module | Doc |
|--------|-----|
| NoteParser | [NoteParser.md](NoteParser.md) |
| NoteMarkup | [NoteMarkup.md](NoteMarkup.md) |
| NoteFrame | [NoteFrame.md](NoteFrame.md) |