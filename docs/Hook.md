# LoolibHookMixin

Comprehensive function and script hooking system for WoW addons, equivalent to AceHook-3.0.

## Overview

### Purpose and Features

LoolibHookMixin provides:
- **Function Hooks**: Intercept calls to global functions or object methods
- **Script Hooks**: Hook frame script handlers (OnShow, OnClick, etc.)
- **Multiple Hook Types**: Regular hooks (pre-hook), raw hooks (replace), and secure hooks (post-hook)
- **Automatic Management**: Track all hooks with automatic cleanup
- **Safe Unhooking**: Restore original functions when needed

### Hook Types

1. **Hook** - Pre-hook that calls your handler before the original function
2. **RawHook** - Replaces the original entirely; handler must manually call original
3. **SecureHook** - Post-hook using `hooksecurefunc`; safe for secure frames, cannot be unhooked

### When to Use

Use LoolibHookMixin when you need to:
- Monitor or modify function calls without replacing them
- Add functionality before or after existing code
- Hook Blizzard UI functions safely
- Intercept frame script handlers
- Debug function calls and parameters

## Quick Start

```lua
local Loolib = LibStub("Loolib")

-- Create your addon object
local MyAddon = Mixin({}, LoolibHookMixin)

-- Hook a global function (pre-hook)
MyAddon:Hook("SetItemRef", function(self, link, text, button)
    print("Link clicked:", link)
    -- Original function still executes after this
end)

-- Secure hook a Blizzard function (post-hook, safe)
MyAddon:SecureHook("ToggleGameMenu", function(self)
    print("Game menu was toggled")
end)

-- Hook a frame script
local frame = CreateFrame("Frame")
MyAddon:HookScript(frame, "OnShow", function(self, frame)
    print("Frame is showing")
end)
```

## API Reference

### Function Hooks

#### Hook(object, method, handler, hookSecure)
Create a pre-hook that calls handler before the original function.

**Signatures:**
```lua
Hook("GlobalFunc", handler)              -- Hook global function
Hook(object, "Method", handler)          -- Hook object method
Hook(object, "Method", "HandlerMethod")  -- Handler is method name
Hook(object, "Method")                   -- Handler is object.Method
```

**Parameters:**
- `object` (table|string) - Object or global function name
- `method` (string|function) - Method name or handler (if object is string)
- `handler` (function|string) - Handler function or method name
- `hookSecure` (boolean) - If true, uses SecureHook instead

**Returns:**
- `boolean` - Success (false if already hooked or invalid)

**Handler Signature:**
```lua
function handler(self, ...)
    -- self: your addon object
    -- ...: all arguments passed to the original function
end
```

**Behavior:**
1. Handler is called first with all arguments
2. Original function is called after with same arguments
3. Return values come from original function

**Examples:**
```lua
-- Hook global function
MyAddon:Hook("PlaySound", function(self, soundKitID)
    print("Playing sound:", soundKitID)
end)

-- Hook object method
local obj = { DoSomething = function() print("Original") end }
MyAddon:Hook(obj, "DoSomething", function(self)
    print("Before original")
end)
obj:DoSomething()
-- Output: "Before original" then "Original"

-- Use method name as handler
function MyAddon:OnPlaySound(soundKitID)
    print("Sound:", soundKitID)
end
MyAddon:Hook("PlaySound", "OnPlaySound")

-- Use same method name (shorthand)
function MyAddon:DoSomething()
    print("My handler")
end
MyAddon:Hook(obj, "DoSomething")  -- Uses MyAddon.DoSomething as handler
```

#### RawHook(object, method, handler)
Replace the original function entirely. Handler must manually call the original.

**Signatures:**
```lua
RawHook("GlobalFunc", handler)
RawHook(object, "Method", handler)
```

**Parameters:**
- Same as Hook()

**Returns:**
- `boolean` - Success

**Handler Signature:**
```lua
function handler(self, ...)
    -- Call original via self.hooks[signature]
    -- Modify arguments or return values as needed
end
```

**Accessing Original:**
```lua
-- For global function:
local original = self.hooks["GLOBAL:FunctionName"]

-- For object method:
local sig = tostring(object) .. ".MethodName"
local original = self.hooks[sig]
```

**Behavior:**
1. Original function is completely replaced
2. Handler controls if/when/how original is called
3. Handler controls return values

**Examples:**
```lua
-- Modify arguments before calling original
MyAddon:RawHook("SendChatMessage", function(self, msg, chatType, ...)
    -- Censor bad words
    msg = msg:gsub("badword", "***")

    -- Call original with modified message
    local sig = "GLOBAL:SendChatMessage"
    local original = self.hooks[sig]
    return original(msg, chatType, ...)
end)

-- Block function calls conditionally
MyAddon:RawHook("TakeInboxItem", function(self, index, ...)
    if self.blockMailLoot then
        print("Mail looting is blocked")
        return  -- Don't call original
    end

    local sig = "GLOBAL:TakeInboxItem"
    local original = self.hooks[sig]
    return original(index, ...)
end)

-- Modify return values
MyAddon:RawHook(itemDB, "GetItemPrice", function(self, itemID)
    local sig = tostring(itemDB) .. ".GetItemPrice"
    local original = self.hooks[sig]

    local price = original(itemDB, itemID)

    -- Apply discount
    return price * 0.9
end)
```

#### SecureHook(object, method, handler)
Create a post-hook using `hooksecurefunc`. Safe for secure frames, cannot be unhooked.

**Signatures:**
```lua
SecureHook("GlobalFunc", handler)
SecureHook(object, "Method", handler)
```

**Parameters:**
- Same as Hook()

**Returns:**
- `boolean` - Success

**Behavior:**
1. Original function executes normally
2. Handler is called after with same arguments
3. Handler cannot modify arguments or return values
4. Cannot be unhooked (permanent)
5. Does not taint secure execution

**When to Use:**
- Hooking Blizzard UI functions
- Monitoring secure frame interactions
- When you need read-only observation
- When taint prevention is critical

**Examples:**
```lua
-- Monitor container updates (secure)
MyAddon:SecureHook("ContainerFrameItemButton_OnClick", function(self, button, down)
    print("Item clicked:", button:GetParent():GetID(), button:GetID())
end)

-- Track talent changes
MyAddon:SecureHook(C_Traits, "CommitConfig", function(self, configID)
    print("Talents changed, config:", configID)
    -- Update addon UI
end)

-- Monitor action bar usage
MyAddon:SecureHook("UseAction", function(self, slot, checkCursor, onSelf)
    print("Used action slot:", slot)
end)
```

### Script Hooks

#### HookScript(frame, script, handler)
Hook a frame script handler (pre-hook).

**Parameters:**
- `frame` (Frame) - The frame object
- `script` (string) - Script name (e.g., "OnShow", "OnClick", "OnUpdate")
- `handler` (function|string) - Handler function or method name

**Returns:**
- `boolean` - Success

**Handler Signature:**
```lua
function handler(self, frame, ...)
    -- self: your addon object
    -- frame: the frame that triggered the script
    -- ...: script-specific arguments
end
```

**Behavior:**
1. Handler is called first
2. Original script (if any) is called after
3. Both receive same arguments

**Examples:**
```lua
-- Hook OnShow
MyAddon:HookScript(CharacterFrame, "OnShow", function(self, frame)
    print("Character frame opened")
    -- Update custom UI elements
end)

-- Hook OnClick
MyAddon:HookScript(button, "OnClick", function(self, frame, buttonName, down)
    if buttonName == "RightButton" then
        print("Right clicked!")
    end
end)

-- Hook OnUpdate (use carefully - high frequency)
MyAddon:HookScript(someFrame, "OnUpdate", function(self, frame, elapsed)
    -- This runs every frame!
end)
```

#### RawHookScript(frame, script, handler)
Replace a frame script entirely. Handler must manually call original.

**Parameters:**
- Same as HookScript()

**Returns:**
- `boolean` - Success

**Accessing Original:**
```lua
local sig = tostring(frame) .. ":SCRIPT:" .. script
local original = self.scripts[sig]
```

**Examples:**
```lua
-- Control when original script executes
MyAddon:RawHookScript(frame, "OnShow", function(self, frame)
    if not self.allowFrameShow then
        return  -- Block original OnShow
    end

    -- Call original
    local sig = tostring(frame) .. ":SCRIPT:OnShow"
    local original = self.scripts[sig]
    if original then
        original(frame)
    end

    -- Do additional work
    print("Frame shown")
end)
```

#### SecureHookScript(frame, script, handler)
Post-hook a frame script using frame:HookScript(). Cannot be unhooked.

**Parameters:**
- Same as HookScript()

**Returns:**
- `boolean` - Success

**Behavior:**
- Original script executes first
- Handler executes after
- Cannot modify behavior or block execution
- Safe for secure frames

**Examples:**
```lua
-- Monitor GameMenuFrame
MyAddon:SecureHookScript(GameMenuFrame, "OnShow", function(self, frame)
    print("Game menu opened")
    -- Update pause screen UI
end)

-- Track bag updates
for i = 1, NUM_CONTAINER_FRAMES do
    local frame = _G["ContainerFrame"..i]
    MyAddon:SecureHookScript(frame, "OnShow", function(self, f)
        print("Bag", i, "opened")
    end)
end
```

### Unhook Functions

#### Unhook(object, method)
Remove a function hook and restore the original.

**Parameters:**
- `object` (table|string) - Object or global function name
- `method` (string) - Method name (nil if object is string)

**Returns:**
- `boolean` - Success (false if not hooked or is secure hook)

**Note:** Secure hooks cannot be unhooked.

**Examples:**
```lua
-- Unhook global function
MyAddon:Hook("PlaySound", handler)
-- ... later ...
MyAddon:Unhook("PlaySound")

-- Unhook object method
MyAddon:Hook(obj, "Method", handler)
MyAddon:Unhook(obj, "Method")

-- Secure hooks cannot be unhooked
MyAddon:SecureHook("UseAction", handler)
MyAddon:Unhook("UseAction")  -- Returns false, hook remains
```

#### UnhookScript(frame, script)
Remove a script hook and restore the original.

**Parameters:**
- `frame` (Frame) - The frame
- `script` (string) - Script name

**Returns:**
- `boolean` - Success (false if not hooked or is secure hook)

**Examples:**
```lua
MyAddon:HookScript(frame, "OnShow", handler)
-- ... later ...
MyAddon:UnhookScript(frame, "OnShow")
```

#### UnhookAll()
Remove all hooks (functions and scripts) created by this object.

**Note:** Secure hooks are not removed (they cannot be unhooked).

**Examples:**
```lua
function MyAddon:OnDisable()
    self:UnhookAll()
end
```

### Query Functions

#### IsHooked(object, method)
Check if a function is currently hooked.

**Parameters:**
- `object` (table|string) - Object or global function name
- `method` (string) - Method name (nil if object is string)

**Returns:**
- `boolean` - True if hooked
- `function|nil` - The handler function

**Examples:**
```lua
local hooked, handler = MyAddon:IsHooked("PlaySound")
if hooked then
    print("PlaySound is hooked")
end

if MyAddon:IsHooked(obj, "Method") then
    print("Already hooked, skipping")
else
    MyAddon:Hook(obj, "Method", handler)
end
```

#### IsScriptHooked(frame, script)
Check if a frame script is hooked.

**Parameters:**
- `frame` (Frame) - The frame
- `script` (string) - Script name

**Returns:**
- `boolean` - True if hooked
- `function|nil` - The handler function

**Examples:**
```lua
if not MyAddon:IsScriptHooked(frame, "OnShow") then
    MyAddon:HookScript(frame, "OnShow", handler)
end
```

## Usage Examples

### Monitoring Function Calls

```lua
local MyAddon = Mixin({}, LoolibHookMixin)

function MyAddon:EnableDebugMode()
    -- Monitor all container operations
    self:SecureHook("UseContainerItem", function(self, bag, slot)
        print(string.format("Used item: bag=%d slot=%d", bag, slot))
    end)

    self:SecureHook("PickupContainerItem", function(self, bag, slot)
        print(string.format("Picked up: bag=%d slot=%d", bag, slot))
    end)

    self:SecureHook("SplitContainerItem", function(self, bag, slot, amount)
        print(string.format("Split: bag=%d slot=%d amount=%d", bag, slot, amount))
    end)
end
```

### Modifying Function Behavior

```lua
function MyAddon:InstallChatFilter()
    -- Filter out spam messages
    self:RawHook("ChatFrame_MessageEventHandler", function(self, frame, event, ...)
        local msg = select(1, ...)

        -- Block gold spam
        if msg:find("WTS") or msg:find("gold") then
            return  -- Don't call original - message blocked
        end

        -- Call original for legitimate messages
        local sig = "GLOBAL:ChatFrame_MessageEventHandler"
        local original = self.hooks[sig]
        return original(frame, event, ...)
    end)
end
```

### Extending Blizzard UI

```lua
function MyAddon:EnhanceTooltips()
    -- Add custom info to tooltips
    self:SecureHook(GameTooltip, "SetUnitBuff", function(self, tooltip, ...)
        -- Add custom aura information
        local customInfo = self:GetAuraInfo(...)
        if customInfo then
            tooltip:AddLine(customInfo, 1, 1, 1)
            tooltip:Show()
        end
    end)

    self:SecureHook(GameTooltip, "SetItemByHyperlink", function(self, tooltip, link)
        -- Add price information
        local price = self:GetItemPrice(link)
        if price then
            tooltip:AddDoubleLine("Price:", GetCoinTextureString(price))
            tooltip:Show()
        end
    end)
end
```

### Hooking Multiple Objects

```lua
function MyAddon:HookAllBags()
    for i = 1, NUM_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame"..i]
        if frame then
            -- Hook each bag frame
            self:SecureHookScript(frame, "OnShow", function(self, f)
                self:OnBagOpened(i)
            end)

            self:SecureHookScript(frame, "OnHide", function(self, f)
                self:OnBagClosed(i)
            end)

            -- Hook item buttons
            for j = 1, frame.size or 0 do
                local button = _G["ContainerFrame"..i.."Item"..j]
                if button then
                    self:SecureHookScript(button, "OnEnter", function(self, btn)
                        self:OnItemHover(i, j)
                    end)
                end
            end
        end
    end
end
```

### Conditional Hooks

```lua
function MyAddon:Initialize()
    -- Only hook if feature is enabled
    if self.db.trackCombat then
        self:SecureHook("CombatLogGetCurrentEventInfo", "OnCombatEvent")
    end

    -- Different hooks for different classes
    local _, class = UnitClass("player")
    if class == "WARRIOR" then
        self:HookWarriorAbilities()
    elseif class == "MAGE" then
        self:HookMageAbilities()
    end
end

function MyAddon:UpdateSettings(trackCombat)
    if trackCombat and not self:IsHooked("CombatLogGetCurrentEventInfo") then
        self:SecureHook("CombatLogGetCurrentEventInfo", "OnCombatEvent")
    elseif not trackCombat then
        -- Note: Can't unhook secure hooks!
        -- Consider using regular Hook if you need to toggle
    end
end
```

### Temporary Hooks

```lua
function MyAddon:StartRecording()
    -- Hook functions temporarily
    self:Hook("SendChatMessage", function(self, msg, chatType, lang, channel)
        table.insert(self.chatLog, {
            msg = msg,
            type = chatType,
            time = time()
        })
    end)

    self:Hook("UseAction", function(self, slot)
        table.insert(self.actionLog, {
            slot = slot,
            time = time()
        })
    end)
end

function MyAddon:StopRecording()
    -- Remove hooks
    self:Unhook("SendChatMessage")
    self:Unhook("UseAction")

    -- Export logs
    self:ExportLogs(self.chatLog, self.actionLog)
end
```

## Advanced Topics

### Understanding the self.hooks Table

The `hooks` table stores original functions:

```lua
-- Structure for function hooks:
self.hooks = {
    ["GLOBAL:FunctionName"] = originalFunction,
    ["table: 0x12345.MethodName"] = originalMethod,
}

-- For secure hooks, value is just true (no original to call):
self.hooks["GLOBAL:SecureFunc"] = true

-- Accessing stored originals:
function MyAddon:CallOriginal(name, ...)
    local sig = "GLOBAL:" .. name
    local original = self.hooks[sig]
    if original and type(original) == "function" then
        return original(...)
    end
end
```

### Understanding the self.scripts Table

Script hooks are stored separately:

```lua
-- Structure:
self.scripts = {
    ["frame: 0x12345:SCRIPT:OnShow"] = originalHandler,
}

-- originalHandler can be nil if frame had no script
```

### Understanding the self.hookData Table

Metadata for all hooks:

```lua
self.hookData = {
    [signature] = {
        object = targetObject,      -- For function hooks
        method = "MethodName",       -- For function hooks
        frame = frameObject,         -- For script hooks
        script = "OnShow",           -- For script hooks
        handler = handlerFunction,
        type = "hook" | "rawhook" | "securehook" | "scripthook" | "rawscripthook" | "securescripthook"
    }
}

-- Use this for introspection:
function MyAddon:PrintAllHooks()
    for sig, data in pairs(self.hookData) do
        print(sig, data.type)
    end
end
```

### Hook Chaining

Multiple addons can hook the same function:

```lua
-- Addon1
Addon1:Hook("PlaySound", function(self, soundID)
    print("Addon1:", soundID)
end)

-- Addon2
Addon2:Hook("PlaySound", function(self, soundID)
    print("Addon2:", soundID)
end)

-- When PlaySound(12345) is called:
-- Output: "Addon1: 12345"
-- Output: "Addon2: 12345"
-- Then original PlaySound executes
```

**Important:** Hook order matters. Last hook registered is called first.

### Performance Considerations

```lua
-- AVOID: Hooking high-frequency functions
self:Hook("OnUpdate", handler)  -- Called every frame!

-- PREFER: Use throttling in handler
self:Hook("OnUpdate", function(self, frame, elapsed)
    self.updateTimer = (self.updateTimer or 0) + elapsed
    if self.updateTimer < 0.5 then return end  -- Update every 0.5s
    self.updateTimer = 0

    -- Do work here
end)

-- BETTER: Use events instead of hooks when possible
-- Instead of hooking frame updates, use PLAYER_ENTERING_WORLD, etc.
```

### Memory Management

```lua
-- Clean up hooks when no longer needed
function MyAddon:OnDisable()
    self:UnhookAll()
    -- This prevents memory leaks from closures
end

-- For temporary hooks, unhook immediately
function MyAddon:DoOneTimeOperation()
    local hookFired = false

    self:Hook("SomeFunc", function(self)
        if hookFired then return end
        hookFired = true

        -- Do one-time operation
        print("Operation complete")

        -- Clean up
        self:Unhook("SomeFunc")
    end)
end
```

## Best Practices

### 1. Prefer SecureHook for Blizzard UI

```lua
-- DO: Use SecureHook for Blizzard functions
MyAddon:SecureHook("ToggleGameMenu", handler)

-- DON'T: Use regular Hook (causes taint)
MyAddon:Hook("ToggleGameMenu", handler)  -- May cause taint errors!
```

### 2. Check Before Hooking

```lua
-- DO: Check if already hooked
if not MyAddon:IsHooked("PlaySound") then
    MyAddon:Hook("PlaySound", handler)
end

-- AVOID: Multiple hooks of same function
-- This will error:
MyAddon:Hook("PlaySound", handler1)
MyAddon:Hook("PlaySound", handler2)  -- ERROR!
```

### 3. Call Original in RawHooks

```lua
-- DO: Always call original unless intentionally blocking
MyAddon:RawHook("Func", function(self, ...)
    -- Your code
    local original = self.hooks["GLOBAL:Func"]
    return original(...)
end)

-- DON'T: Forget to call original
MyAddon:RawHook("Func", function(self, ...)
    -- Your code only - original never executes!
end)
```

### 4. Use Method Names for Clarity

```lua
-- DO: Use method names
function MyAddon:OnPlaySound(soundID)
    print("Sound:", soundID)
end
MyAddon:Hook("PlaySound", "OnPlaySound")

-- ACCEPTABLE: Anonymous functions for simple cases
MyAddon:Hook("PlaySound", function(self, soundID)
    print("Sound:", soundID)
end)
```

### 5. Document Hook Purpose

```lua
-- DO: Comment why you're hooking
-- Hook PlaySound to track sound effects for accessibility features
MyAddon:SecureHook("PlaySound", "OnSoundPlayed")

-- DON'T: Leave unexplained hooks
MyAddon:SecureHook("SomeBlizzardFunc", "DoStuff")
```

### 6. Clean Up on Disable

```lua
-- DO: Unhook when addon is disabled
function MyAddon:OnDisable()
    self:UnhookAll()
end

-- Prevents hooks from firing when addon is inactive
```

### 7. Validate Frame Scripts

```lua
-- DO: Check if script exists
if frame:HasScript("OnShow") then
    MyAddon:HookScript(frame, "OnShow", handler)
end

-- DON'T: Assume all frames have all scripts
MyAddon:HookScript(frame, "OnClick", handler)  -- May error!
```

## Troubleshooting

### Taint Errors from Hooks

**Problem:** "Interface action failed because of an AddOn" errors.

**Cause:** Regular Hook() on secure Blizzard functions.

**Solution:**
```lua
-- Change from Hook to SecureHook
-- BEFORE (causes taint):
MyAddon:Hook("UseAction", handler)

-- AFTER (safe):
MyAddon:SecureHook("UseAction", handler)
```

**Understanding Taint:**
- Regular hooks replace functions, which taints execution
- Secure hooks use `hooksecurefunc`, which doesn't taint
- Secure frames (action bars, unit frames) cannot use tainted code
- Always use SecureHook for Blizzard UI functions

### Hook Not Firing

**Problem:** Handler never executes.

**Debugging:**
```lua
-- Verify hook was registered
local hooked, handler = MyAddon:IsHooked("FuncName")
print("Hooked:", hooked, "Handler:", handler)

-- Add debug output in handler
MyAddon:Hook("FuncName", function(self, ...)
    print("HOOK FIRED!")  -- Does this print?
    print("Args:", ...)
end)

-- Check if function actually exists
print(type(_G["FuncName"]))  -- Should be "function"

-- Verify function is being called
-- Try calling it manually: FuncName()
```

### Original Function Not Called

**Problem:** In RawHook, original doesn't execute.

**Cause:** Forgot to call original or wrong signature.

**Solution:**
```lua
-- Verify signature
MyAddon:RawHook("FuncName", function(self, ...)
    print("In handler")

    -- Get signature
    local sig = "GLOBAL:FuncName"
    print("Signature:", sig)
    print("Original:", self.hooks[sig])

    -- Call original
    local original = self.hooks[sig]
    if type(original) == "function" then
        return original(...)
    else
        print("ERROR: Original not found!")
    end
end)
```

### Cannot Unhook Secure Hooks

**Problem:** `Unhook()` returns false for secure hooks.

**Explanation:** This is intentional. Secure hooks are permanent.

**Solution:**
```lua
-- If you need to toggle hooks, use regular Hook instead
if needsToggle then
    MyAddon:Hook("Func", handler)  -- Can unhook later
else
    MyAddon:SecureHook("Func", handler)  -- Permanent but safe
end
```

### Multiple Hook Attempts Error

**Problem:** Error: "already hooked [signature]"

**Cause:** Trying to hook same function twice.

**Solution:**
```lua
-- Check before hooking
if not MyAddon:IsHooked("Func") then
    MyAddon:Hook("Func", handler)
end

-- Or unhook first
MyAddon:Unhook("Func")
MyAddon:Hook("Func", newHandler)

-- Or use different addon objects
Addon1:Hook("Func", handler1)
Addon2:Hook("Func", handler2)  -- Different object, works fine
```

### Wrong self in Handler

**Problem:** `self` is not your addon object.

**Cause:** Using external function instead of method.

**Solution:**
```lua
-- DON'T: Use external function
local function externalHandler(...)
    -- self is wrong here
end
MyAddon:Hook("Func", externalHandler)

-- DO: Use method
function MyAddon:HandleFunc(...)
    -- self is MyAddon
end
MyAddon:Hook("Func", "HandleFunc")

-- DO: Use closure
MyAddon:Hook("Func", function(self, ...)
    -- self is MyAddon
end)
```

### Script Hook on Wrong Frame

**Problem:** Hook fires on unexpected frame.

**Cause:** Multiple frames with same script name.

**Solution:**
```lua
-- Verify you're hooking the right frame
MyAddon:HookScript(CharacterFrame, "OnShow", function(self, frame)
    print("Frame:", frame:GetName())  -- Verify frame name
    assert(frame == CharacterFrame)
end)

-- Use frame parameter, not global
MyAddon:HookScript(someFrame, "OnClick", function(self, frame, button)
    -- Use 'frame' parameter, not 'someFrame'
    print(frame:GetName())
end)
```

### Memory Leaks from Hooks

**Problem:** Memory usage grows over time.

**Cause:** Closures capturing large tables or many hooks without cleanup.

**Solution:**
```lua
-- DO: Clean up hooks
function MyAddon:Disable()
    self:UnhookAll()
end

-- DON'T: Create hooks in loops with closures
for i = 1, 1000 do
    MyAddon:Hook("Func"..i, function(self)
        print(i)  -- Captures i, creates 1000 closures
    end)
end

-- DO: Use shared handler
function MyAddon:SharedHandler(...)
    -- Handle all variants
end
for i = 1, 1000 do
    MyAddon:Hook("Func"..i, "SharedHandler")
end
```

### Security Warnings

**WARNING:** Hooking secure code incorrectly can cause:
- "Interface action failed because of an AddOn" errors
- Action buttons becoming unclickable
- Protected functions failing
- Game UI breaking in combat

**Rules:**
1. Always use `SecureHook` for Blizzard UI functions
2. Never use `Hook` or `RawHook` on secure frames
3. Test thoroughly outside of combat first
4. Have a way to disable your hooks (`/console reloadui`)

**Secure Functions Include:**
- Action bar functions (UseAction, PickupAction, etc.)
- Targeting functions (TargetUnit, AssistUnit, etc.)
- Combat-related functions
- Most Blizzard frame methods

**When Unsure:** Use `SecureHook` - it's always safe.
