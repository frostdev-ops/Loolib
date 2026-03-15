# NoteParser

Tokenizer and AST builder for MRT-style conditional note markup. Converts raw markup text into a structured Abstract Syntax Tree consumed by NoteMarkup and NoteRenderer.

## Module Access

```lua
local Loolib = LibStub("Loolib")
local NoteParser = Loolib:GetModule("NoteParser")

-- Singleton
local parser = NoteParser.Get()

-- New instance
local myParser = NoteParser.Create()
```

## Markup Syntax

### Conditional Tags

| Tag | Meaning | Closing Tag |
|-----|---------|-------------|
| `{H}` | Healer-only | `{/H}` |
| `{T}` | Tank-only | `{/T}` |
| `{D}` | DPS-only | `{/D}` |
| `{P:name}` | Player name (comma-separated) | `{/P}` |
| `{!P:name}` | Everyone except player | `{/P}` |
| `{C:CLASS}` | Class token or abbreviation | `{/C}` |
| `{!C:CLASS}` | Everyone except class | `{/C}` |
| `{G1}` .. `{G8}` | Raid group | `{/G}` |
| `{everyone}` | Always visible | `{/everyone}` |

### Inline Elements

| Syntax | Description |
|--------|-------------|
| `{time:30}` | 30-second countdown timer |
| `{time:1:30}` | 1 minute 30 seconds |
| `{time:30,glow,p2}` | Timer with options |
| `{spell:12345}` | Spell icon at font size |
| `{spell:12345:16}` | Spell icon at 16 px |
| `{rt1}` .. `{rt8}` | Raid target icon by number |
| `{star}`, `{skull}`, ... | Raid target icon by name |
| `{tank}`, `{healer}`, `{dps}` | Role icon |
| `{self}` | Personal note placeholder |
| `{icon:path}` | Custom texture |

### Timer Options (comma-separated after seconds)

| Option | Meaning |
|--------|---------|
| `p:N` or `pN` | Start on phase N |
| `glow` | Glow effect at expiry |
| `glowall` | Glow + show to all |
| `all` | Show to all players |
| `wa:eventName` | Fire WeakAura event |

## Public API

### Parsing

```lua
---@param text string  Raw markup text
---@return table       AST root node
parser:Parse(text)
```

Trims leading/trailing whitespace before parsing. Returns a tree of nodes rooted at a `ROOT` node.

**Depth limit**: Nested conditional tags deeper than 20 levels are truncated with an error marker (`[!max nesting depth exceeded!]`) instead of causing a stack overflow.

**Error recovery**: Unmatched closing tags (e.g., `{/H}` without a preceding `{H}`) are emitted as literal text rather than crashing the parser.

### Tokenizing

```lua
---@param text string  Raw markup text
---@return table[]     Array of token tables
parser:Tokenize(text)
```

Low-level access to the token stream. Each token has a `type` field from `TokenTypes`.

### Serialization

```lua
---@param node table   AST node
---@return string      Reconstructed markup text
parser:Serialize(node)
```

Round-trips an AST back to markup. Useful for debugging and note export.

### Debug Printing

```lua
---@param node table    AST node
---@param indent number? Indentation level (default 0)
---@return string        Human-readable tree
parser:DebugPrint(node, indent)
```

## AST Node Types

Accessed via `NoteParser.NodeTypes`:

| Type | Fields | Description |
|------|--------|-------------|
| `ROOT` | `children` | Document root |
| `TEXT` | `text` | Plain text |
| `CONDITIONAL` | `condition`, `tag`, `children`, plus condition-specific fields | Conditional block |
| `ICON` | `iconType`, `index`/`role`/`path` | Inline icon |
| `SPELL` | `spellId`, `size` | Spell texture |
| `TIMER` | `minutes`, `seconds`, `options` | Countdown |
| `SELF` | (none) | Self-text placeholder |

## Token Types

Accessed via `NoteParser.TokenTypes`:

`TEXT`, `TAG_OPEN`, `TAG_CLOSE`, `ICON`, `SPELL`, `TIME`, `SELF`, `CUSTOM_ICON`

## AST Example

Input:

```
{H}Heal {spell:64843} at {time:30}{/H}
```

Produces:

```lua
{
    type = "ROOT",
    children = {
        {
            type = "CONDITIONAL",
            condition = "ROLE",
            tag = "H",
            role = "HEALER",
            children = {
                { type = "TEXT", text = "Heal " },
                { type = "SPELL", spellId = 64843, size = 0 },
                { type = "TEXT", text = " at " },
                { type = "TIMER", minutes = 0, seconds = 30, options = nil },
            },
        },
    },
}
```

## Error Handling

| Scenario | Behaviour |
|----------|-----------|
| Non-string argument to `Parse`/`Tokenize` | `error()` at call site (level 2) |
| Unrecognized tag `{foo}` | Emitted as literal text `{` |
| Unclosed brace `{foo` | Remainder treated as plain text |
| Unmatched close `{/H}` without open | Emitted as text `{/H}` |
| Nesting > 20 levels | Marker text inserted, remaining tokens consumed |

## See Also

- [Note.md](Note.md) -- Full Note system overview and usage examples
- [NoteMarkup.md](NoteMarkup.md) -- Conditional evaluation
- [NoteFrame.md](NoteFrame.md) -- Display frame API
