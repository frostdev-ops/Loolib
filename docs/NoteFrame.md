# NoteFrame

Display frame for the Note system. Integrates the full rendering pipeline (Parser, Markup, Renderer, Timer) into a draggable, scrollable, combat-aware WoW frame.

## Module Access

```lua
local Loolib = LibStub("Loolib")
local NoteFrame = Loolib:GetModule("NoteFrame")

-- Create a new frame
local frame = NoteFrame.Create(UIParent, "MyRaidNote")
```

There is no singleton for NoteFrame -- each consumer creates its own frame via `NoteFrame.Create()`.

## Quick Start

```lua
local frame = NoteFrame.Create(UIParent, "MyNote")
frame:SetPoint("CENTER")
frame:SetSize(400, 300)

frame:SetText([[
{H}Healers: Dispel {spell:123456} immediately!{/H}
{T}Tanks: Taunt swap at {time:30}{/T}
{P:Alice,Bob}You interrupt {skull}!{/P}
]])

frame:SetSelfText("I soak purple circles")
frame:Show()
```

## Public API

### Text Management

```lua
---@param text string  Raw markup text (or nil to clear)
frame:SetText(text)

---@return string
frame:GetText()

---@param text string  Personal note for {self} placeholder
frame:SetSelfText(text)

---@return string
frame:GetSelfText()

-- Force re-render (called automatically by SetText/SetSelfText)
frame:Update()
```

### Appearance

```lua
frame:SetFontSize(14)
frame:GetFontSize()          --> number

frame:SetFontFace("Fonts\\FRIZQT__.TTF")
frame:GetFontFace()          --> string

frame:SetTextColor(r, g, b [, a])
frame:GetTextColor()         --> r, g, b, a

frame:SetBackgroundColor(r, g, b [, a])
frame:GetBackgroundColor()   --> r, g, b, a

frame:SetBackgroundAlpha(0.7)
frame:GetBackgroundAlpha()   --> number
```

### Auto-Sizing

When enabled, the frame height adjusts automatically to fit its rendered content.

```lua
frame:SetAutoSize(true)
frame:GetAutoSize()          --> boolean
```

Minimum height is 40 px. Horizontal size is still controlled by `SetSize` or `SetContentWidth`.

### Lock / Unlock

```lua
frame:SetLocked(true)   -- Disables mouse, hides border, disables drag
frame:SetLocked(false)  -- Enables mouse, shows border, enables drag
frame:IsLocked()         --> boolean
```

### Visibility

```lua
frame:SetVisible(true)              -- Master visibility toggle
frame:IsVisible()                   --> boolean

-- Combat rules: show only in combat, only out of combat, or both
frame:SetCombatVisibility(showInCombat, showOutOfCombat)
frame:GetCombatVisibility()         --> showInCombat, showOutOfCombat

-- Re-evaluate (called automatically on PLAYER_REGEN events)
frame:UpdateVisibility()
```

### Sizing

```lua
frame:SetContentWidth(350)     -- Sets text width; frame adds 30 px for scrollbar
frame:GetContentWidth()        --> number
```

### Glow Effect

```lua
frame:ShowGlow(1.5)   -- 1.5-second fade-out glow overlay
```

### Encounter Integration

```lua
frame:OnEncounterStart(encounterId, encounterName)
frame:OnEncounterEnd()
frame:OnPhaseChange(2)
```

These are called automatically when the frame receives `ENCOUNTER_START` / `ENCOUNTER_END` events. You can also call them manually for testing.

## Automatic Event Handling

The frame registers and responds to these WoW events:

| Event | Action |
|-------|--------|
| `ENCOUNTER_START` | Starts timer system, re-renders |
| `ENCOUNTER_END` | Stops timer system, re-renders |
| `PLAYER_REGEN_DISABLED` | Re-evaluates combat visibility |
| `PLAYER_REGEN_ENABLED` | Re-evaluates combat visibility |
| `GROUP_ROSTER_UPDATE` | Updates raid roster, re-renders |

## Lifecycle Behaviour

### OnHide

- Stops glow animation
- Pauses the timer update loop (prevents wasted CPU while hidden)

### OnShow

- Resumes the timer update loop if an encounter is active
- Re-renders content

### Empty Content Guard

Calling `Show()` when `SetText()` has not been called (or was set to `""`) renders an empty frame rather than displaying stale or broken content.

## Soft Dependencies

The factory function checks for these optional modules at creation time. If present they are mixed in; if absent the frame still works:

| Module | Purpose |
|--------|---------|
| `DraggableMixin` | Drag-to-move support |
| `EventFrame` | Structured event handling |

Drag-related calls (`SetDragEnabled`, `InitDraggable`, `SetClampToScreen`) are guarded with nil checks so the frame never errors if `ui-dragdrop` is not loaded.

## Rendering Pipeline

```
SetText(markup)
  --> NoteParser:Parse()      -- AST
  --> NoteMarkup:Process()    -- Filter by player context
  --> NoteRenderer:Render()   -- Formatted WoW text
  --> FontString:SetText()    -- Display
  --> _UpdateContentSize()    -- Resize scroll child / auto-size
```

Components are lazy-loaded via `_EnsureComponents()`. If any component is not yet registered, the frame displays `[Note Loading...]` until the next `Update()` call.

## Error Handling

| Scenario | Behaviour |
|----------|-----------|
| `SetText(nil)` | Clears display |
| `SetText(123)` (non-string) | `error()` at call site |
| Components not loaded | Placeholder text shown |
| Parse failure | `[Parse Error]` shown |
| Timer hidden mid-encounter | Update loop paused, resumed on show |

## See Also

- [Note.md](Note.md) -- Full Note system overview, markup syntax, examples
- [NoteParser.md](NoteParser.md) -- Parser syntax and AST reference
- [NoteMarkup.md](NoteMarkup.md) -- Conditional evaluation
