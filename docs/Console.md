# LoolibConsoleMixin

Comprehensive chat output and slash command registration system for WoW addons, equivalent to AceConsole-3.0.

## Overview

### Purpose and Features

LoolibConsoleMixin provides:
- **Chat Output**: Print messages to any chat frame with automatic addon name prefixing
- **Slash Commands**: Register custom slash commands with flexible handler resolution
- **Argument Parsing**: Extract arguments from slash commands with support for quoted strings
- **Multiple Signatures**: Flexible API that supports various calling patterns

### When to Use

Use LoolibConsoleMixin when you need to:
- Output messages to the chat frame with consistent formatting
- Register slash commands for user interaction
- Parse complex command-line arguments with quoted strings
- Provide a command-line interface for your addon

## Quick Start

```lua
local Loolib = LibStub("Loolib")

-- Create your addon object
local MyAddon = Mixin({}, LoolibConsoleMixin)
MyAddon.name = "MyAddon"  -- Used for message prefix

-- Print a simple message
MyAddon:Print("Hello World!")
-- Output: [MyAddon] Hello World!

-- Register a slash command
MyAddon:RegisterChatCommand("myaddon", function(self, input)
    self:Print("You typed:", input)
end)

-- Now typing /myaddon test will output: [MyAddon] You typed: test
```

## API Reference

### Chat Output Functions

#### Print(frame, ...)
Print a message to a chat frame with automatic formatting.

**Signatures:**
```lua
Print(...)                    -- Print to DEFAULT_CHAT_FRAME
Print(chatFrame, ...)         -- Print to specified chat frame
```

**Parameters:**
- `frame` (ChatFrame|any) - Optional chat frame, or first part of message
- `...` - Message components (concatenated with spaces)

**Examples:**
```lua
-- Print to default chat frame
addon:Print("Simple message")
addon:Print("Multiple", "parts", "concatenated")

-- Print to specific frame
addon:Print(ChatFrame3, "This goes to ChatFrame3")

-- All values are converted to strings
addon:Print("Player level:", 60, "gold:", 1500)
```

#### Printf(frame, format, ...)
Print a formatted message using `string.format()`.

**Signatures:**
```lua
Printf(format, ...)           -- Print to DEFAULT_CHAT_FRAME
Printf(chatFrame, format, ...) -- Print to specified chat frame
```

**Parameters:**
- `frame` (ChatFrame|string) - Optional chat frame, or format string
- `format` (string|any) - Format string, or first format argument
- `...` - Format arguments

**Examples:**
```lua
-- Simple formatting
addon:Printf("Player has %d gold", 1500)

-- Multiple format arguments
addon:Printf("%s has %d/%d health", playerName, health, maxHealth)

-- Print to specific frame
addon:Printf(ChatFrame2, "Target: %s (Level %d)", name, level)

-- Numeric formatting
addon:Printf("Percentage: %.2f%%", 85.7777)  -- Output: 85.78%
```

### Slash Command Registration

#### RegisterChatCommand(command, func, persist)
Register a slash command handler.

**Parameters:**
- `command` (string) - Command name without "/" (e.g., "myaddon")
- `func` (function|string) - Handler function or method name
- `persist` (boolean) - Optional, keep registration across reloads (currently unused)

**Returns:**
- `boolean` - Success (false if already registered or invalid)

**Handler Signature:**
```lua
function handler(self, input, editBox)
    -- self: your addon object
    -- input: string - everything typed after the command
    -- editBox: the edit box frame (usually ChatFrameEditBox)
end
```

**Examples:**
```lua
-- Function handler
addon:RegisterChatCommand("test", function(self, input)
    self:Print("Input:", input)
end)

-- Method name (string)
function addon:HandleCommand(input, editBox)
    self:Print("Command received:", input)
end
addon:RegisterChatCommand("cmd", "HandleCommand")

-- Method reference
addon:RegisterChatCommand("cmd2", addon.HandleCommand)
```

#### UnregisterChatCommand(command)
Remove a previously registered slash command.

**Parameters:**
- `command` (string) - Command name without "/"

**Returns:**
- `boolean` - Success (false if not registered)

**Examples:**
```lua
-- Register and later unregister
addon:RegisterChatCommand("temp", myHandler)
-- ... later ...
addon:UnregisterChatCommand("temp")
```

#### UnregisterAllChatCommands()
Remove all slash commands registered by this addon.

**Examples:**
```lua
-- Clean up on disable
function addon:OnDisable()
    self:UnregisterAllChatCommands()
end
```

#### IsCommandRegistered(command)
Check if a command is currently registered.

**Parameters:**
- `command` (string) - Command name without "/"

**Returns:**
- `boolean` - True if registered

**Examples:**
```lua
if not addon:IsCommandRegistered("config") then
    addon:RegisterChatCommand("config", "ShowConfig")
end
```

### Argument Parsing

#### GetArgs(str, numargs, startpos)
Parse slash command arguments with support for quoted strings.

**Parameters:**
- `str` (string) - Input string to parse
- `numargs` (number) - Optional, maximum arguments to extract
- `startpos` (number) - Optional, starting position (default: 1)

**Returns:**
- `...` - Multiple values (not a table)

**Features:**
- Handles single and double quotes
- Supports escaped quotes inside quoted strings
- Skips leading/trailing whitespace
- Returns multiple values for easy unpacking

**Examples:**
```lua
-- Basic parsing
local arg1, arg2, arg3 = addon:GetArgs("one two three")
-- arg1 = "one", arg2 = "two", arg3 = "three"

-- Quoted strings with spaces
local name, message = addon:GetArgs('player "hello world"')
-- name = "player", message = "hello world"

-- Limit number of arguments
local cmd, rest = addon:GetArgs("set option value", 2)
-- cmd = "set", rest = "option"

-- Escaped quotes
local text = addon:GetArgs([["He said \"hello\""]])
-- text = 'He said "hello"'

-- Mixed quotes
local a, b = addon:GetArgs([[one 'two words' three]], 2)
-- a = "one", b = "two words"
```

## Usage Examples

### Basic Command Handler with Subcommands

```lua
local MyAddon = Mixin({}, LoolibConsoleMixin)
MyAddon.name = "MyAddon"

function MyAddon:OnCommand(input)
    local cmd, arg1, arg2 = self:GetArgs(input, 3)

    if not cmd or cmd == "help" then
        self:Print("Commands: show, set, reset")
        return
    end

    if cmd == "show" then
        self:Printf("Current value: %s", self.db.value)
    elseif cmd == "set" then
        if not arg1 then
            self:Print("Usage: /myaddon set <value>")
            return
        end
        self.db.value = arg1
        self:Printf("Value set to: %s", arg1)
    elseif cmd == "reset" then
        self.db.value = "default"
        self:Print("Value reset to default")
    else
        self:Printf("Unknown command: %s", cmd)
    end
end

-- Register
MyAddon:RegisterChatCommand("myaddon", "OnCommand")
```

### Multiple Slash Commands for Same Handler

```lua
local MyAddon = Mixin({}, LoolibConsoleMixin)
MyAddon.name = "MyAddon"

function MyAddon:ShowConfig()
    self:Print("Opening configuration...")
    -- Show config UI
end

-- Register multiple commands
MyAddon:RegisterChatCommand("myaddon", "ShowConfig")
MyAddon:RegisterChatCommand("ma", "ShowConfig")  -- Short alias
MyAddon:RegisterChatCommand("myconfig", "ShowConfig")

-- Now /myaddon, /ma, and /myconfig all work
```

### Parsing Complex Arguments

```lua
function MyAddon:OnCommand(input)
    -- Parse: /tell "Player Name" "Your message here"
    local target, message = self:GetArgs(input, 2)

    if not target or not message then
        self:Print('Usage: /tell "Player Name" "Message"')
        return
    end

    -- Send whisper
    SendChatMessage(message, "WHISPER", nil, target)
    self:Printf("Sent to %s: %s", target, message)
end

-- Example usage:
-- /tell "John Doe" "Hello there!"
```

### Debug Output with Different Frames

```lua
local MyAddon = Mixin({}, LoolibConsoleMixin)
MyAddon.name = "MyAddon"

function MyAddon:Debug(...)
    -- Always print debug to ChatFrame2
    if self.debugMode then
        self:Print(ChatFrame2, "[DEBUG]", ...)
    end
end

function MyAddon:Error(...)
    -- Errors to ChatFrame1 with red color
    local message = self:_FormatMessage(...)
    ChatFrame1:AddMessage("|cffff0000[" .. self.name .. " ERROR]|r " .. message)
end

-- Usage
MyAddon.debugMode = true
MyAddon:Debug("Entering function HandleClick")
MyAddon:Error("Failed to load data!")
```

### Conditional Command Registration

```lua
local MyAddon = Mixin({}, LoolibConsoleMixin)
MyAddon.name = "MyAddon"

function MyAddon:Initialize()
    -- Always register main command
    self:RegisterChatCommand("myaddon", "OnCommand")

    -- Only register debug command in development mode
    if self.isDevelopment then
        self:RegisterChatCommand("madebug", "OnDebugCommand")
    end

    -- Register admin commands for GMs
    if self:IsUserAdmin() then
        self:RegisterChatCommand("maadmin", "OnAdminCommand")
    end
end

function MyAddon:Shutdown()
    -- Clean up all commands
    self:UnregisterAllChatCommands()
end
```

### Interactive Menu System

```lua
function MyAddon:OnCommand(input)
    if input == "" then
        -- Show menu when no arguments
        self:Print("=== MyAddon Menu ===")
        self:Print("1. Show Status")
        self:Print("2. Configure Settings")
        self:Print("3. Export Data")
        self:Print("Type: /myaddon <number>")
        return
    end

    local choice = tonumber(input)

    if choice == 1 then
        self:ShowStatus()
    elseif choice == 2 then
        self:ShowConfig()
    elseif choice == 3 then
        self:ExportData()
    else
        self:Printf("Invalid choice: %s", input)
    end
end
```

## Advanced Topics

### Custom Message Formatting

The internal `_FormatMessage()` method handles value concatenation. You can override it for custom behavior:

```lua
-- Override to add custom formatting
function MyAddon:_FormatMessage(...)
    local n = select("#", ...)
    if n == 0 then return "" end

    local parts = {}
    for i = 1, n do
        local v = select(i, ...)

        -- Custom formatting for tables
        if type(v) == "table" then
            parts[i] = tostringall(v)  -- Use your table serializer
        else
            parts[i] = tostring(v)
        end
    end

    return table.concat(parts, " ")
end
```

### Handling EditBox in Commands

The `editBox` parameter allows you to manipulate the chat input:

```lua
function MyAddon:OnCommand(input, editBox)
    local cmd = self:GetArgs(input, 1)

    if cmd == "reply" then
        -- Set the edit box to reply mode
        if editBox then
            editBox:SetText("/tell LastPlayer ")
            editBox:HighlightText(0, 0)  -- Move cursor to end
        end
    elseif cmd == "clear" then
        -- Clear the input
        if editBox then
            editBox:SetText("")
        end
    end
end
```

### Dynamic Command Name Generation

```lua
local MyAddon = Mixin({}, LoolibConsoleMixin)

function MyAddon:RegisterModuleCommands(modules)
    for _, module in ipairs(modules) do
        local cmdName = "ma" .. module.name:lower()

        -- Create a closure for each module
        local handler = function(self, input)
            module:HandleCommand(input)
        end

        self:RegisterChatCommand(cmdName, handler)
        self:Printf("Registered command: /%s", cmdName)
    end
end
```

### Argument Validation

```lua
function MyAddon:OnSetCommand(input)
    local option, value = self:GetArgs(input, 2)

    -- Validate presence
    if not option or not value then
        self:Print("Usage: /myaddon set <option> <value>")
        return
    end

    -- Validate option name
    local validOptions = { scale = true, alpha = true, enabled = true }
    if not validOptions[option] then
        self:Printf("Invalid option: %s", option)
        self:Print("Valid options: scale, alpha, enabled")
        return
    end

    -- Validate value type
    if option == "scale" or option == "alpha" then
        local num = tonumber(value)
        if not num then
            self:Printf("Value must be a number for %s", option)
            return
        end
        if num < 0 or num > 1 then
            self:Print("Value must be between 0 and 1")
            return
        end
        value = num
    elseif option == "enabled" then
        value = (value == "true" or value == "1")
    end

    -- Apply setting
    self.db[option] = value
    self:Printf("Set %s = %s", option, tostring(value))
end
```

## Best Practices

### 1. Always Set Addon Name

```lua
-- DO: Set name for automatic prefixing
MyAddon.name = "MyAddon"
MyAddon:Print("Hello")  -- Output: [MyAddon] Hello

-- DON'T: Skip name - messages won't have prefix
-- Output: Hello (harder to identify source)
```

### 2. Use Printf for Formatted Output

```lua
-- DO: Use Printf for format strings
addon:Printf("Player %s has %d gold", name, gold)

-- DON'T: Use Print with string.format
addon:Print(string.format("Player %s has %d gold", name, gold))
```

### 3. Validate Command Input

```lua
-- DO: Always validate user input
function addon:OnCommand(input)
    local value = tonumber(input)
    if not value then
        self:Print("Please enter a number")
        return
    end
    -- Use value...
end

-- DON'T: Assume input is valid
function addon:OnCommand(input)
    self.db.value = tonumber(input)  -- Could be nil!
end
```

### 4. Provide Help Text

```lua
-- DO: Show help for empty or invalid commands
function addon:OnCommand(input)
    if input == "" or input == "help" then
        self:Print("Usage: /myaddon <command>")
        self:Print("Commands: show, set, reset, help")
        return
    end
    -- Handle commands...
end
```

### 5. Use Method Names for Readability

```lua
-- DO: Use method names for clarity
MyAddon:RegisterChatCommand("config", "ShowConfig")
MyAddon:RegisterChatCommand("reset", "ResetSettings")

-- DON'T: Use anonymous functions everywhere
MyAddon:RegisterChatCommand("config", function(self, input)
    -- 50 lines of code here...
end)
```

### 6. Clean Up on Shutdown

```lua
-- DO: Unregister commands when addon is disabled
function addon:OnDisable()
    self:UnregisterAllChatCommands()
end

-- Prevents conflicts if addon is reloaded
```

### 7. Use GetArgs for Complex Parsing

```lua
-- DO: Use GetArgs for quoted strings
local name, message = self:GetArgs(input, 2)

-- DON'T: Try to parse manually
local parts = {}
for word in input:gmatch("%S+") do  -- Breaks on spaces in quotes!
    table.insert(parts, word)
end
```

## Troubleshooting

### Command Not Working

**Problem:** Typing `/mycommand` does nothing.

**Solutions:**
```lua
-- Check if registered
if addon:IsCommandRegistered("mycommand") then
    print("Registered")
else
    print("Not registered")
    addon:RegisterChatCommand("mycommand", handler)
end

-- Check for errors in handler
function addon:OnCommand(input)
    print("Handler called!")  -- Does this print?
    -- Your code...
end

-- Verify command ID is unique
-- Check SlashCmdList for conflicts
for k, v in pairs(SlashCmdList) do
    if k:find("LOOLIB") then
        print(k, v)
    end
end
```

### Messages Not Showing Addon Name

**Problem:** Messages don't have `[AddonName]` prefix.

**Solution:**
```lua
-- Set the name property
MyAddon.name = "MyAddon"

-- Verify it's set
print(MyAddon.name)  -- Should not be nil
```

### GetArgs Not Splitting Correctly

**Problem:** Arguments are not parsed as expected.

**Examples:**
```lua
-- Input: 'one "two three" four'
local a, b, c = addon:GetArgs('one "two three" four')
-- a = "one", b = "two three", c = "four"

-- Input: 'command arg1 arg2 arg3...'
-- Only want first 2 arguments
local cmd, arg = addon:GetArgs(input, 2)

-- Input has escaped quotes: 'text "He said \"hi\""'
local text = addon:GetArgs([[text "He said \"hi\""]])
-- text = 'text', second arg = 'He said "hi"'
```

### Print vs Printf Confusion

**Issue:** Not sure which to use?

**Guide:**
```lua
-- Use Print for simple concatenation
addon:Print("Player logged in:", name)

-- Use Printf for formatting
addon:Printf("Player %s has %d/%d health", name, health, maxHealth)

-- Print is easier for debug output
addon:Print("Debug:", var1, var2, var3)

-- Printf is better for structured messages
addon:Printf("%s: %.2f%% complete", task, percent)
```

### Memory Leaks from Closures

**Problem:** Creating many command handlers causes memory issues.

**Solution:**
```lua
-- DON'T: Create closures in loops
for i = 1, 100 do
    addon:RegisterChatCommand("cmd" .. i, function(self, input)
        print(i)  -- Captures i
    end)
end

-- DO: Use method names or reuse functions
function addon:OnNumberCommand(input)
    local num = tonumber(self.currentNum)
    self:Print("Number:", num)
end

for i = 1, 100 do
    addon.currentNum = i
    addon:RegisterChatCommand("cmd" .. i, "OnNumberCommand")
end
```

### Handler Not Receiving Self

**Problem:** `self` is nil in handler.

**Solution:**
```lua
-- DON'T: Use regular function binding
local handler = MyAddon.OnCommand
addon:RegisterChatCommand("cmd", handler)  -- self will be wrong!

-- DO: Use string method name
addon:RegisterChatCommand("cmd", "OnCommand")

-- DO: Create proper closure
addon:RegisterChatCommand("cmd", function(self, input)
    self:OnCommand(input)
end)
```

### Command Registered Multiple Times

**Problem:** Typing `/cmd` executes handler multiple times.

**Solution:**
```lua
-- Check before registering
if not addon:IsCommandRegistered("cmd") then
    addon:RegisterChatCommand("cmd", "OnCommand")
end

-- Or unregister first
addon:UnregisterChatCommand("cmd")
addon:RegisterChatCommand("cmd", "OnCommand")
```
