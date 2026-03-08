# Loolib Note System

Complete raid note system with markup parsing, conditional filtering, and UI rendering.

## Files Overview

### Core Modules

- **NoteMarkup.lua** (694 lines) - Conditional tag evaluation
  - Role-based filtering (Healer, Tank, DPS)
  - Player name matching
  - Class-based filtering
  - Group assignments
  - Custom condition handlers
  - Content analysis utilities

- **NoteParser.lua** (575 lines) - Markup parsing to AST
  - Text tokenization
  - Conditional tag parsing
  - Icon/spell tag parsing
  - Timer tag parsing
  - AST generation

- **NoteRenderer.lua** (533 lines) - Render AST to UI
  - Font string rendering
  - Icon atlas rendering
  - Spell icon rendering
  - Timer display
  - Color/formatting support

- **NoteTimer.lua** (490 lines) - Timer management
  - Encounter time tracking
  - Phase-based timers
  - Custom event triggers
  - Timer display formatting

- **NoteFrame.lua** (606 lines) - Complete note UI
  - Scrollable frame
  - Auto-updating display
  - Compact/expanded modes
  - Drag/resize support

### Examples and Tests

- **NoteMarkup_Example.lua** (352 lines) - Practical usage example
  - Complete raid note addon
  - Assignment checking
  - Multi-view comparison
  - Slash commands

- **NoteMarkup_Tests.lua** (410 lines) - Test suite
  - Role tag tests
  - Player/class/group tests
  - Content analysis tests
  - Custom handler tests

### Documentation

- **docs/NoteMarkup.md** (713 lines) - Complete API reference
  - Usage examples
  - All tag types
  - Custom handlers
  - Performance tips

## Quick Start

### Basic Usage

```lua
local Loolib = LibStub("Loolib")
local NoteMarkup = Loolib:GetModule("NoteMarkup")
local processor = NoteMarkup.Get()

-- Process markup text
local text = [[
{H}Healers: Dispel magic{/H}
{T}Tanks: Taunt at 3 stacks{/T}
{D}DPS: Kill adds first{/D}
]]

processor:UpdatePlayerContext()
local filtered = processor:ProcessText(text)
-- Shows only content relevant to current player
```

### Supported Tags

```
{H}...{/H}          - Healers only
{T}...{/T}          - Tanks only
{D}...{/D}          - DPS only

{P:Alice,Bob}...{/P}        - Specific players
{!P:Charlie}...{/P}         - Everyone except Charlie

{C:MAGE,WARLOCK}...{/C}     - Specific classes
{!C:WARRIOR}...{/C}         - Everyone except Warriors

{G1}...{/G}                 - Group 1
{G123}...{/G}               - Groups 1, 2, or 3
{!G45}...{/G}               - Not groups 4-5

{RACE:Human}...{/RACE}      - Specific race
```

### Content Analysis

```lua
-- Check if note has visible content for player
if processor:HasVisibleContent(text) then
    ShowNote()
end

-- Extract assignments
local players = processor:ExtractPlayerNames(text)
local classes = processor:ExtractClasses(text)
local roles = processor:ExtractRoles(text)
local groups = processor:ExtractGroups(text)
```

### Custom Handlers

```lua
-- Register custom condition
processor:RegisterHandler("MYTHICPLUS", function(node, context)
    local _, instanceType = GetInstanceInfo()
    return instanceType == "party"
end)

-- Use in markup
{MYTHICPLUS}
M+ specific strategy
{/MYTHICPLUS}
```

## Module Integration

### With SavedVariables

```lua
local addon = Loolib:NewAddon("MyNoteAddon")

function addon:OnEnable()
    self.db = self:RegisterSavedVariables("MyNoteAddonDB", {
        notes = {},
    })

    self.processor = Loolib:GetModule("NoteMarkup").Get()
end

function addon:ShowNote(noteName)
    local text = self.db.notes[noteName]
    local filtered = self.processor:ProcessText(text)
    self.frame:SetText(filtered)
end
```

### Full Pipeline

```lua
local Parser = Loolib:GetModule("NoteParser")
local Markup = Loolib:GetModule("NoteMarkup")
local Renderer = Loolib:GetModule("NoteRenderer")

-- Parse → Filter → Render
local ast = Parser.Get():Parse(markupText)
local filteredAst = Markup.Get():Process(ast)
Renderer.Get():RenderToFrame(filteredAst, frame)
```

## Testing

### Run Tests In-Game

```lua
-- All tests
/run LoolibTestNoteMarkup_All()

-- Specific tests
/run LoolibTestNoteMarkup_RoleTags()
/run LoolibTestNoteMarkup_PlayerTags()
/run LoolibTestNoteMarkup_ClassTags()
/run LoolibTestNoteMarkup_GroupTags()

-- Or use slash command
/loolib-test-notemarkup
/loolib-test-notemarkup role
/loolib-test-notemarkup player
```

### Try Example Addon

```lua
-- Load example (if NoteMarkup_Example.lua is loaded)
/lnote                  -- Toggle note window
/lnote show            -- Show note
/lnote hide            -- Hide note
/lnote check           -- Check assignments
/lnote compare         -- Compare different player views
```

## Performance

- **Role caching**: Role detection cached for 1 second
- **Singleton pattern**: Reuse `Get()` instance for efficiency
- **Pattern matching**: String processing faster than AST for simple cases
- **Context updates**: Update once, process multiple notes

## Architecture

```
NoteMarkup (This Module)
├── Context Management
│   ├── UpdatePlayerContext() - Detect player role/class/group
│   ├── SetContext() - Custom context override
│   └── GetContext() - Retrieve current context
│
├── Condition Handlers
│   ├── Built-in: ROLE, PLAYER, CLASS, GROUP, RACE, PHASE, EVERYONE
│   └── Custom: RegisterHandler(), UnregisterHandler()
│
├── Processing
│   ├── ProcessText() - Direct string processing
│   ├── Process() - AST processing (requires NoteParser)
│   └── EvaluateCondition() - Single node evaluation
│
└── Analysis
    ├── HasVisibleContent() - Visibility check
    ├── ExtractPlayerNames() - Get assigned players
    ├── ExtractClasses() - Get required classes
    ├── ExtractRoles() - Get mentioned roles
    └── ExtractGroups() - Get group assignments
```

## API Reference

See [docs/NoteMarkup.md](../../docs/NoteMarkup.md) for complete API documentation.

### Core Methods

```lua
-- Factory
processor = LoolibCreateNoteMarkup()
processor = LoolibGetNoteMarkup()  -- Singleton
processor = NoteMarkup.Create()
processor = NoteMarkup.Get()

-- Context
processor:UpdatePlayerContext()
processor:SetContext(context)
context = processor:GetContext()

-- Processing
filtered = processor:ProcessText(text [, context])
filteredAst = processor:Process(ast [, context])
nodes = processor:Flatten(ast)

-- Handlers
processor:RegisterHandler(type, func)
processor:UnregisterHandler(type)
handlers = processor:GetHandlers()

-- Analysis
bool = processor:HasVisibleContent(text)
players = processor:ExtractPlayerNames(text)
classes = processor:ExtractClasses(text)
roles = processor:ExtractRoles(text)
groups = processor:ExtractGroups(text)
```

## Design Patterns

### MRT Compatibility

Tags are compatible with Method Raid Tools (MRT) note format:
- `{H}...{/H}` - Healer tags
- `{T}...{/T}` - Tank tags
- `{D}...{/D}` - DPS tags
- `{P:name}...{/P}` - Player tags
- `{C:class}...{/C}` - Class tags
- `{G#}...{/G}` - Group tags

### Mixin-Based

Uses Loolib mixin pattern:
- `LoolibNoteMarkupMixin` - Core mixin
- `LoolibMixin()` - Apply to objects
- No class inheritance

### Singleton + Factory

- `Get()` - Singleton for common use
- `Create()` - Factory for custom instances
- Flexible for different use cases

## Common Patterns

### Auto-Updating Note

```lua
local processor = NoteMarkup.Get()
local frame = CreateFrame("Frame")

frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

frame:SetScript("OnEvent", function()
    processor:UpdatePlayerContext()
    local filtered = processor:ProcessText(noteText)
    noteDisplay:SetText(filtered)
end)
```

### Assignment Validation

```lua
local requiredPlayers = processor:ExtractPlayerNames(note)
local currentRoster = {}

for i = 1, GetNumGroupMembers() do
    local name = GetRaidRosterInfo(i)
    currentRoster[name] = true
end

for _, player in ipairs(requiredPlayers) do
    if not currentRoster[player] then
        print("Missing assignment:", player)
    end
end
```

### Multi-Role Notes

```lua
local contexts = {
    {playerRole = "HEALER"},
    {playerRole = "TANK"},
    {playerRole = "DAMAGER"},
}

for _, ctx in ipairs(contexts) do
    local p = NoteMarkup.Create()
    p:SetContext(ctx)
    local view = p:ProcessText(note)
    SaveRoleView(ctx.playerRole, view)
end
```

## See Also

- [NoteParser.md](../../docs/NoteParser.md) - Markup parsing
- [NoteRenderer.md](../../docs/NoteRenderer.md) - UI rendering
- [NoteTimer.md](../../docs/NoteTimer.md) - Timer system
- [SavedVariables.md](../../docs/SavedVariables.md) - Data persistence
