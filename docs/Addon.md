# Loolib Addon Lifecycle System

## Overview

The Loolib addon system provides a comprehensive lifecycle management framework for World of Warcraft addons, similar to AceAddon-3.0 but modernized for WoW 12.0+. It enables structured addon development with module hierarchies, library embedding, and automatic lifecycle callback management.

### Core Concepts

**Addon vs Module**

- **Addon**: A top-level component registered with Loolib that represents a complete addon or a major subsystem
- **Module**: A sub-component of an addon that provides specific functionality and can have its own modules (hierarchical)

Both addons and modules use the same `LoolibAddonMixin`, which provides:
- Module creation and management
- Enable/disable state tracking
- Lifecycle callbacks
- Library embedding
- Utility methods (Print, Debug, etc.)

### Lifecycle Stages

```
┌─────────────────────────────────────────────────────────────┐
│                     Addon Lifecycle                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. NewAddon()        ──┐                                   │
│  2. Embed libraries     │  Registration Phase               │
│  3. NewModule()       ──┘  (Synchronous)                    │
│                                                             │
│                         ↓                                   │
│                                                             │
│  4. OnInitialize()    ──┐  ADDON_LOADED                     │
│     - Set up data       │  (First event after load)         │
│     - Initialize state──┘                                   │
│                                                             │
│                         ↓                                   │
│                                                             │
│  5. OnEnable()        ──┐  PLAYER_LOGIN                     │
│     - Register events   │  (Player enters world)            │
│     - Enable modules  ──┘                                   │
│                                                             │
│                         ↓                                   │
│                                                             │
│  6. Running State                                           │
│     - Event handling                                        │
│     - Module interaction                                    │
│     - Enable/Disable modules                                │
│                                                             │
│                         ↓                                   │
│                                                             │
│  7. OnDisable()       ──┐  Manual or /reload                │
│     - Unregister events │                                   │
│     - Disable modules ──┘                                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Key Timing Notes:**

- `OnInitialize()` fires on `ADDON_LOADED` event (first event after Loolib loads)
- `OnEnable()` fires on `PLAYER_LOGIN` event (when player enters the world)
- `OnDisable()` fires when explicitly disabled or on `/reload`
- Modules follow the same lifecycle as their parent addon

---

## Quick Start

### Basic Addon

```lua
-- MyAddon.lua
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:NewAddon("MyAddon")

function MyAddon:OnInitialize()
    -- Set up saved variables, default settings
    self:Print("MyAddon initialized!")
end

function MyAddon:OnEnable()
    -- Register events, start timers, show UI
    self:Print("MyAddon enabled!")
end

function MyAddon:OnDisable()
    -- Clean up, unregister events
    self:Print("MyAddon disabled!")
end
```

### Addon with Module

```lua
-- MyAddon.lua
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:NewAddon("MyAddon")

function MyAddon:OnInitialize()
    self:Print("Main addon initialized")
end

function MyAddon:OnEnable()
    self:Print("Main addon enabled")
end

-- Create a module
local CombatModule = MyAddon:NewModule("Combat")

function CombatModule:OnModuleEnable()
    self:Print("Combat module enabled!")
    -- Module-specific initialization
end

function CombatModule:OnModuleDisable()
    self:Print("Combat module disabled!")
end
```

### Addon with Embedded Libraries

```lua
-- MyAddon.lua
local Loolib = LibStub("Loolib")
-- Embed Timer and CallbackRegistry mixins
local MyAddon = Loolib:NewAddon("MyAddon", "Timer", "CallbackRegistry")

function MyAddon:OnEnable()
    -- Timer methods now available
    self:ScheduleTimer("UpdateDisplay", 5)

    -- CallbackRegistry methods available
    self:GenerateCallbackEvents({"DataUpdated", "ConfigChanged"})
    self:TriggerEvent("DataUpdated")
end

function MyAddon:UpdateDisplay()
    self:Print("Timer fired!")
end
```

---

## Creating Addons

### NewAddon Signatures

The `NewAddon` function has flexible signatures to support different use cases:

#### 1. Simple Addon Creation

```lua
local MyAddon = Loolib:NewAddon("MyAddon")
-- Creates a new empty addon object
```

#### 2. Addon with Libraries

```lua
local MyAddon = Loolib:NewAddon("MyAddon", "Timer", "CallbackRegistry", "EventFrame")
-- Creates addon and embeds specified libraries
```

#### 3. Using Existing Object as Base

```lua
local MyAddon = {
    customField = "value",
    CustomMethod = function(self)
        print("Custom method")
    end
}

Loolib:NewAddon(MyAddon, "MyAddon")
-- Uses MyAddon table as base, adds lifecycle methods
```

#### 4. Existing Object with Libraries

```lua
local MyAddon = {}
Loolib:NewAddon(MyAddon, "MyAddon", "Timer", "CallbackRegistry")
-- Uses MyAddon table and embeds libraries
```

### Available Libraries for Embedding

Loolib provides several mixins that can be embedded into addons:

| Library | Purpose | Key Methods |
|---------|---------|-------------|
| `Timer` | Schedule delayed/repeating callbacks | `ScheduleTimer()`, `ScheduleRepeatingTimer()`, `CancelTimer()` |
| `CallbackRegistry` | Internal event system | `GenerateCallbackEvents()`, `RegisterCallback()`, `TriggerEvent()` |
| `EventFrame` | WoW event registration | `RegisterFrameEvent()`, `UnregisterFrameEvent()` |
| `Hook` | Secure hook management | `Hook()`, `SecureHook()`, `Unhook()` |
| `Console` | Command-line interface | `RegisterCommand()`, `UnregisterCommand()` |

### Library Embedding Process

When you embed a library:

1. All functions from the library mixin are copied to your addon object
2. If the library has an `OnEmbed()` hook, it's called to perform library-specific initialization
3. The library's methods become part of your addon's interface

```lua
-- Manual embedding (rarely needed, NewAddon does this)
local MyAddon = Loolib:NewAddon("MyAddon")
Loolib:EmbedLibrary(MyAddon, "Timer")

-- Or embed multiple
Loolib:EmbedLibraries(MyAddon, "Timer", "CallbackRegistry", "EventFrame")
```

---

## Addon API Reference

### Lifecycle Callbacks

These callbacks are optional. Define them on your addon to receive lifecycle notifications:

#### OnInitialize(self)

Called once when the addon is first initialized (on `ADDON_LOADED` event).

```lua
function MyAddon:OnInitialize()
    -- Initialize saved variables
    MyAddonDB = MyAddonDB or {}

    -- Set up default configuration
    self.config = {
        enabled = true,
        scale = 1.0
    }

    -- DO NOT register events here - do this in OnEnable
end
```

**Use for:**
- Setting up saved variables
- Creating data structures
- Initializing configuration
- Creating UI elements (not shown yet)

**Do NOT:**
- Register game events (do in OnEnable)
- Start timers (do in OnEnable)
- Access player data (may not be available yet)

#### OnEnable(self)

Called when the addon is enabled (on `PLAYER_LOGIN` event). This is where most runtime initialization happens.

```lua
function MyAddon:OnEnable()
    -- Register WoW events
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")

    -- Start timers
    self:ScheduleRepeatingTimer("UpdateData", 1)

    -- Show UI
    self.mainFrame:Show()
end
```

**Use for:**
- Registering game events
- Starting timers
- Showing UI frames
- Accessing player data
- Enabling modules

#### OnDisable(self)

Called when the addon is disabled (manually via `Disable()` or on `/reload`).

```lua
function MyAddon:OnDisable()
    -- Unregister events
    self:UnregisterAllEvents()

    -- Cancel timers
    self:CancelAllTimers()

    -- Hide UI
    self.mainFrame:Hide()

    -- Save data
    MyAddonDB = self.config
end
```

**Use for:**
- Cleaning up resources
- Unregistering events
- Canceling timers
- Hiding UI
- Saving data

### State Management Methods

#### Enable()

Enable this addon or module.

```lua
MyAddon:Enable()
-- Triggers OnEnable callback
-- Enables child modules with defaultModuleState == true
```

#### Disable()

Disable this addon or module.

```lua
MyAddon:Disable()
-- Disables all child modules first
-- Triggers OnDisable callback
```

#### IsEnabled() → boolean

Check if the addon/module is currently enabled.

```lua
if MyAddon:IsEnabled() then
    print("Addon is enabled")
end
```

#### SetEnabledState(state)

Set the enabled state without triggering callbacks (advanced use).

```lua
MyAddon:SetEnabledState(true)
-- Sets internal state without calling OnEnable
-- Rarely needed - use Enable() instead
```

### Module Management Methods

#### NewModule(name, [prototype], [...]) → module

Create a new module as a child of this addon.

**Parameters:**
- `name` (string): Unique module name
- `prototype` (table, optional): Base object for the module
- `...` (varargs): Library names to embed

**Returns:** The module object

```lua
-- Simple module
local CombatModule = MyAddon:NewModule("Combat")

-- Module with embedded libraries
local UIModule = MyAddon:NewModule("UI", "Timer", "EventFrame")

-- Module with prototype
local prototype = { customField = 42 }
local ConfigModule = MyAddon:NewModule("Config", prototype)

-- Note: If prototype is a string, it's treated as a library name
local TimerModule = MyAddon:NewModule("Timer", "Timer")
-- This creates a module named "Timer" with Timer library embedded
```

**Module Lifecycle:**
- Modules have their own `OnInitialize`, `OnEnable`, `OnDisable` callbacks
- When used on modules, prefer `OnModuleEnable` and `OnModuleDisable` for clarity
- Modules are automatically enabled when parent is enabled (if `defaultModuleState` is true)

#### GetModule(name, [silent]) → module|nil

Get a module by name.

```lua
local CombatModule = MyAddon:GetModule("Combat")
-- Errors if module doesn't exist

local OptionalModule = MyAddon:GetModule("Optional", true)
-- Returns nil if not found (silent mode)
```

#### IterateModules() → iterator

Iterate over all modules (unordered).

```lua
for moduleName, module in MyAddon:IterateModules() do
    print("Module:", moduleName)
end
```

#### IterateOrderedModules() → iterator

Iterate over modules in creation order.

```lua
for moduleName, module in MyAddon:IterateOrderedModules() do
    print("Module:", moduleName)
    -- Guaranteed to iterate in order modules were created
end
```

#### EnableModule(name)

Enable a specific module by name.

```lua
MyAddon:EnableModule("Combat")
-- Calls module:Enable()
```

#### DisableModule(name)

Disable a specific module by name.

```lua
MyAddon:DisableModule("Combat")
-- Calls module:Disable()
```

### Default Module Configuration

#### SetDefaultModuleState(state)

Set whether newly created modules are automatically enabled when the parent addon is enabled.

```lua
MyAddon:SetDefaultModuleState(false)
-- New modules won't auto-enable
-- Must manually Enable() each module

MyAddon:SetDefaultModuleState(true)
-- Default: modules auto-enable with parent
```

#### SetDefaultModuleLibraries(...)

Set libraries that are automatically embedded in all new modules.

```lua
MyAddon:SetDefaultModuleLibraries("Timer", "CallbackRegistry")

-- Now all new modules will have Timer and CallbackRegistry
local NewModule = MyAddon:NewModule("NewModule")
-- NewModule already has Timer and CallbackRegistry methods
```

#### SetDefaultModulePrototype(proto)

Set a prototype object that all new modules inherit from.

```lua
local ModulePrototype = {
    defaultValue = 100,
    CommonMethod = function(self)
        print("Common method")
    end
}

MyAddon:SetDefaultModulePrototype(ModulePrototype)

-- All new modules will have defaultValue and CommonMethod
local NewModule = MyAddon:NewModule("NewModule")
print(NewModule.defaultValue) -- 100
NewModule:CommonMethod() -- "Common method"
```

### Utility Methods

#### GetName() → string

Get the addon or module name.

```lua
print(MyAddon:GetName()) -- "MyAddon"
```

#### Print(...)

Print a message prefixed with the addon name.

```lua
MyAddon:Print("Hello", "World")
-- Output: |cff33ff99MyAddon|r: Hello World
```

#### Debug(...)

Print a debug message (only if `Loolib:SetDebug(true)`).

```lua
Loolib:SetDebug(true)
MyAddon:Debug("Debug info", value)
-- Output: |cff00ff00[MyAddon Debug]|r Debug info <value>

Loolib:SetDebug(false)
MyAddon:Debug("This won't print")
```

---

## Module System

### Module Hierarchy

Modules can contain other modules, creating a hierarchical structure:

```lua
local MyAddon = Loolib:NewAddon("MyAddon")

-- Top-level module
local CombatModule = MyAddon:NewModule("Combat")

-- Sub-module of Combat
local DamageTracker = CombatModule:NewModule("DamageTracker")

-- Sub-module of DamageTracker
local DPSDisplay = DamageTracker:NewModule("DPSDisplay")

-- Access nested modules
local dps = MyAddon:GetModule("Combat"):GetModule("DamageTracker"):GetModule("DPSDisplay")
```

**Hierarchy rules:**
- Each module can have unlimited child modules
- Module names must be unique within their parent
- Modules inherit `defaultModuleState` from parent
- When parent disables, all children disable (cascading)
- When parent enables, children enable only if `defaultModuleState` is true

### Module Lifecycle

Modules follow the same lifecycle as addons but use specialized callbacks for clarity:

```lua
local MyModule = MyAddon:NewModule("MyModule")

-- Module creation callback (optional)
function MyModule:OnModuleCreated()
    -- Called immediately after module is created
    -- Parent may not be enabled yet
end

-- Module initialization (optional)
function MyModule:OnInitialize()
    -- Called when parent addon initializes
    -- Set up module data structures
end

-- Module enable callback (preferred for modules)
function MyModule:OnModuleEnable()
    -- Called when module is enabled
    -- Register events, start timers
end

-- Module disable callback (preferred for modules)
function MyModule:OnModuleDisable()
    -- Called when module is disabled
    -- Clean up resources
end

-- Fallback callbacks (also supported)
function MyModule:OnEnable()
    -- Also called if OnModuleEnable doesn't exist
end

function MyModule:OnDisable()
    -- Also called if OnModuleDisable doesn't exist
end
```

**Callback order:**
1. `OnModuleCreated()` - Right after `NewModule()` returns
2. `OnInitialize()` - When parent initializes (if not already initialized)
3. `OnModuleEnable()` / `OnEnable()` - When module is enabled
4. `OnModuleDisable()` / `OnDisable()` - When module is disabled

### Module Example: Combat Tracker

```lua
local MyAddon = Loolib:NewAddon("MyAddon", "Timer")
local CombatModule = MyAddon:NewModule("Combat", "EventFrame", "CallbackRegistry")

function CombatModule:OnModuleCreated()
    -- Set up event names
    self:GenerateCallbackEvents({
        "CombatStarted",
        "CombatEnded",
        "DamageDone"
    })
end

function CombatModule:OnModuleEnable()
    -- Register combat events
    self:RegisterFrameEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterFrameEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
    self:RegisterFrameEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLog")

    -- Initialize combat state
    self.inCombat = false
    self.damageTotal = 0
end

function CombatModule:OnCombatStart()
    self.inCombat = true
    self.damageTotal = 0
    self:TriggerEvent("CombatStarted")
end

function CombatModule:OnCombatEnd()
    self.inCombat = false
    self:TriggerEvent("CombatEnded", self.damageTotal)
end

function CombatModule:OnCombatLog()
    local _, subevent, _, sourceGUID = CombatLogGetCurrentEventInfo()

    if subevent == "SWING_DAMAGE" and sourceGUID == UnitGUID("player") then
        local amount = select(12, CombatLogGetCurrentEventInfo())
        self.damageTotal = self.damageTotal + amount
        self:TriggerEvent("DamageDone", amount)
    end
end

-- Other parts of the addon can listen to combat events
CombatModule:RegisterCallback("CombatStarted", function()
    MyAddon:Print("Combat started!")
end)
```

### Module Organization Best Practices

**Organize by feature:**
```lua
local MyAddon = Loolib:NewAddon("MyAddon")

local Combat = MyAddon:NewModule("Combat")
local UI = MyAddon:NewModule("UI")
local Config = MyAddon:NewModule("Config")
local Database = MyAddon:NewModule("Database")
```

**Use sub-modules for complex features:**
```lua
local UI = MyAddon:NewModule("UI")
local MainFrame = UI:NewModule("MainFrame")
local MiniMap = UI:NewModule("MiniMap")
local Tooltips = UI:NewModule("Tooltips")
```

**Share common functionality via default prototype:**
```lua
local ModuleBase = {
    RegisterSharedEvents = function(self)
        -- Common event registration
    end
}

MyAddon:SetDefaultModulePrototype(ModuleBase)
-- All modules now have RegisterSharedEvents
```

---

## Library Embedding

### How Embedding Works

Library embedding uses the mixin pattern to copy all library functions into your addon object:

```lua
-- Define a library
LoolibMyLibraryMixin = {
    DoSomething = function(self, value)
        print("Library method:", value)
    end
}

-- Register with Loolib
Loolib:RegisterModule("MyLibrary", {
    Mixin = LoolibMyLibraryMixin
})

-- Embed into addon
local MyAddon = Loolib:NewAddon("MyAddon", "MyLibrary")

-- Library methods are now part of MyAddon
MyAddon:DoSomething(42) -- "Library method: 42"
```

**Embedding process:**
1. Loolib looks up the library by name in `Loolib.modules`
2. If not found, tries `LibStub(libName)` for external libraries
3. Copies all library properties to the target object
4. Calls `library.OnEmbed(target)` if the hook exists
5. Returns true if successful, false if library not found

### OnEmbed Hook

Libraries can define an `OnEmbed` callback to perform initialization when embedded:

```lua
LoolibMyLibraryMixin = {
    -- Regular library methods
    DoSomething = function(self)
        print(self.libraryData)
    end
}

-- OnEmbed hook
LoolibMyLibraryMixin.OnEmbed = function(library, target)
    -- Initialize library-specific state on the target
    target.libraryData = {}
    target.librarySettings = { enabled = true }

    print(string.format("MyLibrary embedded into %s", target.name or "unnamed"))
end

-- When embedded, OnEmbed is called
local MyAddon = Loolib:NewAddon("MyAddon", "MyLibrary")
-- Output: "MyLibrary embedded into MyAddon"
-- MyAddon.libraryData now exists
```

### Available Built-in Libraries

#### Timer

Provides AceTimer-3.0 compatible timer scheduling.

```lua
local MyAddon = Loolib:NewAddon("MyAddon", "Timer")

function MyAddon:OnEnable()
    -- One-shot timer
    self:ScheduleTimer("DoUpdate", 5)

    -- Repeating timer
    local handle = self:ScheduleRepeatingTimer("CheckStatus", 1)

    -- Cancel specific timer
    self:CancelTimer(handle)

    -- Cancel all timers
    self:CancelAllTimers()
end

function MyAddon:DoUpdate()
    print("Timer fired after 5 seconds")
end

function MyAddon:CheckStatus()
    print("Checking status every 1 second")
end
```

#### CallbackRegistry

Provides internal event system for component communication.

```lua
local MyAddon = Loolib:NewAddon("MyAddon", "CallbackRegistry")

function MyAddon:OnInitialize()
    -- Initialize callback registry
    self:OnLoad()

    -- Define events
    self:GenerateCallbackEvents({
        "DataUpdated",
        "ConfigChanged",
        "PlayerDied"
    })
end

function MyAddon:OnEnable()
    -- Register callback
    self:RegisterCallback("DataUpdated", function(event, newData)
        print("Data updated:", newData)
    end)

    -- Trigger event
    self:TriggerEvent("DataUpdated", { value = 42 })
end
```

#### EventFrame

Provides WoW event registration with automatic frame management.

```lua
local MyAddon = Loolib:NewAddon("MyAddon", "EventFrame")

function MyAddon:OnEnable()
    -- Register events with callbacks
    self:RegisterFrameEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterFrameEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterFrameEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
end

function MyAddon:OnPlayerEnteringWorld()
    print("Player entering world")
end

function MyAddon:OnCombatStart()
    print("Combat started")
end

function MyAddon:OnCombatEnd()
    print("Combat ended")
end

function MyAddon:OnDisable()
    -- Unregister all events
    self:UnregisterAllFrameEvents()
end
```

#### Hook

Provides secure function hooking capabilities.

```lua
local MyAddon = Loolib:NewAddon("MyAddon", "Hook")

function MyAddon:OnEnable()
    -- Hook a global function
    self:SecureHook("ToggleGameMenu", function()
        print("Game menu toggled")
    end)

    -- Hook an object method
    self:SecureHook(PlayerFrame, "Show", function()
        print("Player frame shown")
    end)
end

function MyAddon:OnDisable()
    -- Unhook everything
    self:UnhookAll()
end
```

#### Console

Provides slash command registration.

```lua
local MyAddon = Loolib:NewAddon("MyAddon", "Console")

function MyAddon:OnEnable()
    -- Register slash command
    self:RegisterCommand("myaddon", "HandleCommand", {
        "enable",
        "disable",
        "status"
    })
end

function MyAddon:HandleCommand(args)
    if args[1] == "enable" then
        self:Enable()
        print("Addon enabled")
    elseif args[1] == "disable" then
        self:Disable()
        print("Addon disabled")
    elseif args[1] == "status" then
        print("Status:", self:IsEnabled() and "Enabled" or "Disabled")
    end
end
```

### Creating Custom Libraries

You can create your own libraries for embedding:

```lua
-- Define the mixin
LoolibMyFeatureMixin = {}

function LoolibMyFeatureMixin:MyMethod(value)
    -- Your implementation
    return value * 2
end

function LoolibMyFeatureMixin:AnotherMethod()
    -- Another method
end

-- Optional: OnEmbed hook for initialization
LoolibMyFeatureMixin.OnEmbed = function(library, target)
    target.myFeatureData = {}
end

-- Register with Loolib
local MyFeatureModule = {
    Mixin = LoolibMyFeatureMixin,

    -- Optional: module-level functions
    Version = "1.0.0",
    GetInfo = function()
        return "My Feature Library"
    end
}

Loolib:RegisterModule("MyFeature", MyFeatureModule)

-- Now it can be embedded
local MyAddon = Loolib:NewAddon("MyAddon", "MyFeature")
MyAddon:MyMethod(21) -- 42
```

---

## Usage Examples

### Example 1: Basic Addon with Modules

```lua
-- MyAddon.lua
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:NewAddon("MyAddon")

function MyAddon:OnInitialize()
    -- Set up saved variables
    MyAddonDB = MyAddonDB or {
        enabled = true,
        scale = 1.0
    }

    self.db = MyAddonDB
    self:Print("Initialized with settings:", self.db.enabled)
end

function MyAddon:OnEnable()
    if not self.db.enabled then
        self:Disable()
        return
    end

    self:Print("Addon enabled!")
end

-- Combat tracking module
local CombatModule = MyAddon:NewModule("Combat")

function CombatModule:OnModuleEnable()
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function CombatModule:OnEvent(event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        MyAddon:Print("Combat started!")
    elseif event == "PLAYER_REGEN_ENABLED" then
        MyAddon:Print("Combat ended!")
    end
end

-- UI module
local UIModule = MyAddon:NewModule("UI")

function UIModule:OnModuleEnable()
    self:CreateMainFrame()
end

function UIModule:CreateMainFrame()
    local frame = CreateFrame("Frame", "MyAddonFrame", UIParent)
    frame:SetSize(200, 100)
    frame:SetPoint("CENTER")
    self.mainFrame = frame
end
```

### Example 2: Embedding Multiple Libraries

```lua
-- MyAddon.lua
local Loolib = LibStub("Loolib")

-- Embed Timer, CallbackRegistry, and EventFrame
local MyAddon = Loolib:NewAddon("MyAddon", "Timer", "CallbackRegistry", "EventFrame")

function MyAddon:OnInitialize()
    -- Initialize callback registry
    self:OnLoad()

    -- Define custom events
    self:GenerateCallbackEvents({
        "DataLoaded",
        "UpdateRequired"
    })
end

function MyAddon:OnEnable()
    -- Use Timer mixin
    self:ScheduleRepeatingTimer("CheckUpdates", 30)

    -- Use EventFrame mixin
    self:RegisterFrameEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    -- Register callback listener
    self:RegisterCallback("DataLoaded", function(event, data)
        self:Print("Data loaded:", data)
    end)
end

function MyAddon:CheckUpdates()
    -- Timer callback
    self:Debug("Checking for updates...")

    -- Trigger internal event
    self:TriggerEvent("UpdateRequired")
end

function MyAddon:OnPlayerEnteringWorld()
    -- WoW event callback
    self:TriggerEvent("DataLoaded", { timestamp = time() })
end
```

### Example 3: Nested Module Hierarchy

```lua
-- MyAddon.lua
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:NewAddon("MyAddon")

-- Set default libraries for all modules
MyAddon:SetDefaultModuleLibraries("Timer", "CallbackRegistry")

-- Top-level modules
local Combat = MyAddon:NewModule("Combat")
local UI = MyAddon:NewModule("UI")
local Database = MyAddon:NewModule("Database")

-- Combat sub-modules
local DamageTracker = Combat:NewModule("DamageTracker")
local HealingTracker = Combat:NewModule("HealingTracker")

-- UI sub-modules
local MainFrame = UI:NewModule("MainFrame")
local MiniMap = UI:NewModule("MiniMap")
local Tooltips = UI:NewModule("Tooltips")

-- Database sub-modules
local CharacterData = Database:NewModule("CharacterData")
local Statistics = Database:NewModule("Statistics")

-- All modules have Timer and CallbackRegistry
function DamageTracker:OnModuleEnable()
    -- Timer available from default libraries
    self:ScheduleRepeatingTimer("UpdateDPS", 1)

    -- CallbackRegistry available from default libraries
    self:GenerateCallbackEvents({"DamageUpdated"})
end

-- Access nested modules
function MyAddon:OnEnable()
    local damageTracker = self:GetModule("Combat"):GetModule("DamageTracker")

    damageTracker:RegisterCallback("DamageUpdated", function(event, dps)
        self:Print("Current DPS:", dps)
    end)
end
```

### Example 4: Enable/Disable Management

```lua
-- MyAddon.lua
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:NewAddon("MyAddon")

-- Modules shouldn't auto-enable
MyAddon:SetDefaultModuleState(false)

-- Create modules
local CombatModule = MyAddon:NewModule("Combat")
local PvPModule = MyAddon:NewModule("PvP")
local PvEModule = MyAddon:NewModule("PvE")

function MyAddon:OnEnable()
    -- Load settings
    local settings = MyAddonDB or {}

    -- Enable modules based on settings
    if settings.trackCombat then
        self:EnableModule("Combat")
    end

    if settings.mode == "pvp" then
        self:EnableModule("PvP")
    elseif settings.mode == "pve" then
        self:EnableModule("PvE")
    end
end

-- Slash command to toggle modules
SLASH_MYADDON1 = "/myaddon"
SlashCmdList["MYADDON"] = function(msg)
    local command, module = strsplit(" ", msg)

    if command == "enable" and module then
        MyAddon:EnableModule(module)
        MyAddon:Print(module, "enabled")
    elseif command == "disable" and module then
        MyAddon:DisableModule(module)
        MyAddon:Print(module, "disabled")
    elseif command == "status" then
        for name, mod in MyAddon:IterateModules() do
            local status = mod:IsEnabled() and "enabled" or "disabled"
            MyAddon:Print(name, "is", status)
        end
    end
end
```

### Example 5: Late Initialization

```lua
-- MyAddon.lua
local Loolib = LibStub("Loolib")

-- This addon is created late (after ADDON_LOADED has already fired)
-- For example, in response to a user action or delayed load

local function CreateLateAddon()
    local LateAddon = Loolib:NewAddon("LateAddon")

    function LateAddon:OnInitialize()
        -- This will be called immediately since initialization phase is complete
        self:Print("Late addon initialized immediately")
    end

    function LateAddon:OnEnable()
        -- This will also be called immediately if enable phase is complete
        self:Print("Late addon enabled immediately")
    end
end

-- Create addon after player logs in
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    C_Timer.After(5, function()
        CreateLateAddon()
        -- Late addon is initialized and enabled immediately
    end)
end)
```

---

## Best Practices

### Addon Structure Recommendations

**1. Separate Concerns with Modules**

```lua
-- Good: Each major feature is a module
local MyAddon = Loolib:NewAddon("MyAddon")
local Combat = MyAddon:NewModule("Combat")
local UI = MyAddon:NewModule("UI")
local Config = MyAddon:NewModule("Config")

-- Bad: Everything in the main addon object
local MyAddon = Loolib:NewAddon("MyAddon")
function MyAddon:OnEnable()
    -- 500 lines of code doing everything
end
```

**2. Use Lifecycle Callbacks Appropriately**

```lua
-- Good: Right callbacks for the right tasks
function MyAddon:OnInitialize()
    -- Data setup only
    self.db = MyAddonDB or {}
end

function MyAddon:OnEnable()
    -- Runtime initialization
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:ScheduleTimer("UpdateDisplay", 1)
end

-- Bad: Everything in OnInitialize
function MyAddon:OnInitialize()
    self.db = MyAddonDB or {}
    self:RegisterEvent("PLAYER_ENTERING_WORLD") -- Won't work properly
    self:ScheduleTimer("UpdateDisplay", 1) -- May fire before player is ready
end
```

**3. Set Default Module Configuration Early**

```lua
-- Good: Set defaults before creating modules
local MyAddon = Loolib:NewAddon("MyAddon")
MyAddon:SetDefaultModuleLibraries("Timer", "CallbackRegistry")
MyAddon:SetDefaultModuleState(false)

-- Now create modules
local Module1 = MyAddon:NewModule("Module1")
local Module2 = MyAddon:NewModule("Module2")

-- Bad: Setting defaults after some modules exist
local Module1 = MyAddon:NewModule("Module1") -- Won't get defaults
MyAddon:SetDefaultModuleLibraries("Timer")
local Module2 = MyAddon:NewModule("Module2") -- Will get defaults
```

**4. Use Error Handling in Callbacks**

Loolib automatically wraps callbacks in `pcall`, but you should still handle expected errors:

```lua
function MyAddon:OnEnable()
    -- Check for required dependencies
    if not LibStub("AceGUI-3.0", true) then
        self:Print("Warning: AceGUI-3.0 not found, UI disabled")
        self:DisableModule("UI")
        return
    end

    -- Validate saved data
    if type(self.db.settings) ~= "table" then
        self:Print("Error: Corrupted settings, resetting")
        self.db.settings = self:GetDefaultSettings()
    end
end
```

### Module Organization

**Feature-based organization:**

```lua
MyAddon/
├── Core.lua           -- Main addon
├── Modules/
│   ├── Combat.lua     -- Combat tracking
│   ├── Database.lua   -- Data persistence
│   ├── UI.lua         -- User interface
│   └── Config.lua     -- Configuration
```

**Layer-based organization:**

```lua
MyAddon/
├── Core.lua           -- Main addon
├── Data/              -- Data layer
│   ├── Database.lua
│   └── Cache.lua
├── Logic/             -- Business logic layer
│   ├── Combat.lua
│   └── Inventory.lua
└── Presentation/      -- UI layer
    ├── MainFrame.lua
    └── Tooltips.lua
```

### When to Use Modules vs Separate Addons

**Use modules when:**
- Features are tightly coupled to the main addon
- Features share significant state/data
- Features are optional but part of the same user experience
- You want unified configuration and lifecycle management

```lua
-- Good use of modules
local MyAddon = Loolib:NewAddon("MyAddon")
local CombatTracker = MyAddon:NewModule("CombatTracker")
local CombatDisplay = MyAddon:NewModule("CombatDisplay")
-- Both are part of the same addon experience
```

**Use separate addons when:**
- Features are completely independent
- You want users to enable/disable features at the addon level
- Features could be useful to other addons
- You want separate saved variables files

```lua
-- Good use of separate addons
local MyTrackerAddon = Loolib:NewAddon("MyTracker")
local MyConfigAddon = Loolib:NewAddon("MyConfig")
-- These are truly independent addons
```

### Memory Management

**1. Clean up in OnDisable**

```lua
function MyAddon:OnDisable()
    -- Cancel timers
    self:CancelAllTimers()

    -- Unregister events
    self:UnregisterAllEvents()

    -- Clear large data structures
    self.combatLog = nil
    self.cachedData = nil

    -- Hide frames
    if self.mainFrame then
        self.mainFrame:Hide()
    end
end
```

**2. Use object pooling for frequently created/destroyed objects**

```lua
local MyAddon = Loolib:NewAddon("MyAddon")

function MyAddon:OnInitialize()
    -- Create object pool
    self.framePool = CreateFramePool("Frame", UIParent, "MyFrameTemplate")
end

function MyAddon:CreateTemporaryFrame()
    -- Acquire from pool instead of creating new
    local frame = self.framePool:Acquire()
    return frame
end

function MyAddon:ReleaseTemporaryFrame(frame)
    -- Return to pool instead of destroying
    self.framePool:Release(frame)
end
```

**3. Avoid storing unnecessary references**

```lua
-- Bad: Storing references prevents garbage collection
function MyAddon:OnEnable()
    self.allFrames = {}
    for i = 1, 1000 do
        local frame = CreateFrame("Frame")
        self.allFrames[i] = frame -- Keeps all frames in memory
    end
end

-- Good: Only store what you need
function MyAddon:OnEnable()
    self.activeFrames = {} -- Only store frames currently in use
end
```

---

## Integration Examples

### With SavedVariables

```lua
-- MyAddon.toc
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB

-- MyAddon.lua
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:NewAddon("MyAddon")

-- Default settings
local defaults = {
    enabled = true,
    scale = 1.0,
    position = { x = 0, y = 0 },
    modules = {
        Combat = { enabled = true },
        UI = { enabled = true }
    }
}

function MyAddon:OnInitialize()
    -- Initialize saved variables with defaults
    if not MyAddonDB then
        MyAddonDB = CopyTable(defaults)
    end

    -- Merge with defaults for new settings
    for key, value in pairs(defaults) do
        if MyAddonDB[key] == nil then
            MyAddonDB[key] = value
        end
    end

    self.db = MyAddonDB

    -- Per-character settings
    MyAddonCharDB = MyAddonCharDB or {}
    self.charDB = MyAddonCharDB
end

function MyAddon:OnEnable()
    -- Apply settings
    if not self.db.enabled then
        self:Disable()
        return
    end

    -- Enable/disable modules based on settings
    for moduleName, settings in pairs(self.db.modules) do
        local module = self:GetModule(moduleName, true)
        if module then
            if settings.enabled then
                module:Enable()
            else
                module:Disable()
            end
        end
    end
end

function MyAddon:OnDisable()
    -- Save current state
    self.db.modules = {}
    for name, module in self:IterateModules() do
        self.db.modules[name] = { enabled = module:IsEnabled() }
    end
end
```

### With Config System

```lua
-- MyAddon.lua
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:NewAddon("MyAddon")
local Config = Loolib:GetModule("Config")

function MyAddon:OnInitialize()
    -- Initialize database
    MyAddonDB = MyAddonDB or {}
    self.db = MyAddonDB

    -- Register options
    self:RegisterOptions()
end

function MyAddon:RegisterOptions()
    local options = {
        type = "group",
        name = "MyAddon",
        args = {
            enable = {
                type = "toggle",
                name = "Enable Addon",
                desc = "Enable or disable the addon",
                get = function() return self.db.enabled end,
                set = function(_, value)
                    self.db.enabled = value
                    if value then
                        self:Enable()
                    else
                        self:Disable()
                    end
                end
            },
            scale = {
                type = "range",
                name = "UI Scale",
                desc = "Adjust UI scale",
                min = 0.5,
                max = 2.0,
                step = 0.1,
                get = function() return self.db.scale or 1.0 end,
                set = function(_, value)
                    self.db.scale = value
                    self:UpdateScale()
                end
            },
            modules = {
                type = "group",
                name = "Modules",
                args = {}
            }
        }
    }

    -- Add module options
    for name, module in self:IterateModules() do
        options.args.modules.args[name] = {
            type = "toggle",
            name = name,
            desc = "Enable " .. name .. " module",
            get = function() return module:IsEnabled() end,
            set = function(_, value)
                if value then
                    self:EnableModule(name)
                else
                    self:DisableModule(name)
                end
            end
        }
    end

    -- Register with config system
    Config:RegisterOptionsTable("MyAddon", options)
    Config:RegisterSlashCommand("MyAddon", "myaddon")
end
```

### With Timer/Events

```lua
-- MyAddon.lua
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:NewAddon("MyAddon", "Timer", "EventFrame")

function MyAddon:OnInitialize()
    self.updateInterval = 1
    self.lastUpdate = 0
end

function MyAddon:OnEnable()
    -- Schedule repeating timer
    self.updateTimer = self:ScheduleRepeatingTimer("OnUpdate", self.updateInterval)

    -- Register WoW events
    self:RegisterFrameEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterFrameEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterFrameEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")

    -- One-shot timer for delayed initialization
    self:ScheduleTimer("LateInitialization", 5)
end

function MyAddon:OnUpdate()
    local now = GetTime()
    local delta = now - self.lastUpdate
    self.lastUpdate = now

    -- Update logic
    self:UpdateDisplay()
end

function MyAddon:OnPlayerEnteringWorld()
    -- Player entered world
    self:Print("Welcome!")
end

function MyAddon:OnCombatStart()
    -- Speed up updates during combat
    self:CancelTimer(self.updateTimer)
    self.updateInterval = 0.1
    self.updateTimer = self:ScheduleRepeatingTimer("OnUpdate", self.updateInterval)
end

function MyAddon:OnCombatEnd()
    -- Slow down updates out of combat
    self:CancelTimer(self.updateTimer)
    self.updateInterval = 1
    self.updateTimer = self:ScheduleRepeatingTimer("OnUpdate", self.updateInterval)
end

function MyAddon:LateInitialization()
    -- Delayed initialization (5 seconds after enable)
    self:Print("Late initialization complete")
end

function MyAddon:OnDisable()
    -- Clean up
    self:CancelAllTimers()
    self:UnregisterAllFrameEvents()
end

function MyAddon:UpdateDisplay()
    -- Display update logic
end
```

### Complete Addon Template

```lua
-- MyAddon.toc
## Interface: 120000
## Title: MyAddon
## Notes: A complete addon example
## Author: Your Name
## Version: 1.0.0
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB

# Libraries
Libs\LibStub\LibStub.lua
Libs\Loolib\loolib.toc

# Core
MyAddon.lua

# Modules
Modules\Combat.lua
Modules\UI.lua
Modules\Config.lua

-- MyAddon.lua
local Loolib = LibStub("Loolib")

-- Create main addon with embedded libraries
local MyAddon = Loolib:NewAddon("MyAddon", "Timer", "CallbackRegistry", "EventFrame")

-- Default settings
local defaults = {
    enabled = true,
    version = 1,
    modules = {
        Combat = { enabled = true },
        UI = { enabled = true, scale = 1.0 },
        Config = { enabled = true }
    }
}

function MyAddon:OnInitialize()
    -- Initialize saved variables
    MyAddonDB = MyAddonDB or CopyTable(defaults)
    MyAddonCharDB = MyAddonCharDB or {}

    self.db = MyAddonDB
    self.charDB = MyAddonCharDB

    -- Perform version upgrade if needed
    if self.db.version < defaults.version then
        self:UpgradeDatabase()
    end

    -- Initialize callback system
    self:OnLoad()
    self:GenerateCallbackEvents({
        "Initialized",
        "Enabled",
        "Disabled",
        "ConfigChanged"
    })

    self:TriggerEvent("Initialized")
    self:Print("Initialized v" .. defaults.version)
end

function MyAddon:OnEnable()
    -- Check if addon is disabled in settings
    if not self.db.enabled then
        self:Print("Addon is disabled in settings")
        self:Disable()
        return
    end

    -- Enable modules based on settings
    for moduleName, settings in pairs(self.db.modules) do
        local module = self:GetModule(moduleName, true)
        if module and settings.enabled then
            module:Enable()
        end
    end

    -- Register global events
    self:RegisterFrameEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    -- Start update timer
    self:ScheduleRepeatingTimer("OnUpdate", 1)

    self:TriggerEvent("Enabled")
    self:Print("Enabled")
end

function MyAddon:OnDisable()
    -- Disable all modules
    for name, module in self:IterateModules() do
        module:Disable()
    end

    -- Clean up
    self:CancelAllTimers()
    self:UnregisterAllFrameEvents()

    self:TriggerEvent("Disabled")
    self:Print("Disabled")
end

function MyAddon:OnPlayerEnteringWorld()
    self:Print("Welcome to MyAddon!")
end

function MyAddon:OnUpdate()
    -- Periodic update logic
end

function MyAddon:UpgradeDatabase()
    -- Perform database upgrades
    self:Print("Upgrading database from v" .. self.db.version .. " to v" .. defaults.version)
    self.db.version = defaults.version
end

function MyAddon:GetModuleSettings(moduleName)
    return self.db.modules[moduleName] or {}
end

function MyAddon:SetModuleSettings(moduleName, settings)
    self.db.modules[moduleName] = settings
    self:TriggerEvent("ConfigChanged", moduleName)
end

-- Slash command
SLASH_MYADDON1 = "/myaddon"
SlashCmdList["MYADDON"] = function(msg)
    local command = strlower(msg)

    if command == "" or command == "help" then
        MyAddon:Print("Commands:")
        MyAddon:Print("  /myaddon enable - Enable addon")
        MyAddon:Print("  /myaddon disable - Disable addon")
        MyAddon:Print("  /myaddon status - Show status")
        MyAddon:Print("  /myaddon modules - List modules")
    elseif command == "enable" then
        MyAddon.db.enabled = true
        MyAddon:Enable()
    elseif command == "disable" then
        MyAddon.db.enabled = false
        MyAddon:Disable()
    elseif command == "status" then
        local status = MyAddon:IsEnabled() and "Enabled" or "Disabled"
        MyAddon:Print("Status:", status)
    elseif command == "modules" then
        MyAddon:Print("Modules:")
        for name, module in MyAddon:IterateModules() do
            local status = module:IsEnabled() and "enabled" or "disabled"
            MyAddon:Print("  " .. name .. ": " .. status)
        end
    end
end

-- Modules\Combat.lua
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:GetAddon("MyAddon")
local Combat = MyAddon:NewModule("Combat", "EventFrame")

function Combat:OnModuleEnable()
    self:RegisterFrameEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterFrameEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")

    self.inCombat = false
end

function Combat:OnCombatStart()
    self.inCombat = true
    MyAddon:Print("Combat started!")
end

function Combat:OnCombatEnd()
    self.inCombat = false
    MyAddon:Print("Combat ended!")
end

function Combat:OnModuleDisable()
    self:UnregisterAllFrameEvents()
end

-- Modules\UI.lua
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:GetAddon("MyAddon")
local UI = MyAddon:NewModule("UI")

function UI:OnModuleEnable()
    self:CreateMainFrame()

    -- Listen for config changes
    MyAddon:RegisterCallback("ConfigChanged", function(event, moduleName)
        if moduleName == "UI" then
            self:ApplySettings()
        end
    end)
end

function UI:CreateMainFrame()
    local frame = CreateFrame("Frame", "MyAddonFrame", UIParent)
    frame:SetSize(200, 100)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    self.mainFrame = frame
    self:ApplySettings()
end

function UI:ApplySettings()
    local settings = MyAddon:GetModuleSettings("UI")
    if self.mainFrame then
        self.mainFrame:SetScale(settings.scale or 1.0)
    end
end

function UI:OnModuleDisable()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
end

-- Modules\Config.lua
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:GetAddon("MyAddon")
local Config = MyAddon:NewModule("Config")

function Config:OnModuleEnable()
    -- Config module initialization
end
```

---

## Comparison with AceAddon-3.0

For developers familiar with AceAddon-3.0, here's a quick comparison:

| Feature | AceAddon-3.0 | Loolib Addon |
|---------|--------------|--------------|
| **Addon Creation** | `LibStub("AceAddon-3.0"):NewAddon(name, ...)` | `Loolib:NewAddon(name, ...)` |
| **Module Creation** | `addon:NewModule(name, ...)` | `addon:NewModule(name, ...)` |
| **Lifecycle Callbacks** | `OnInitialize`, `OnEnable`, `OnDisable` | Same |
| **Module Callbacks** | `OnInitialize`, `OnEnable`, `OnDisable` | `OnModuleEnable`, `OnModuleDisable` (preferred) |
| **Library Embedding** | Via AceAddon parameters | Via NewAddon parameters |
| **Get Addon** | `LibStub("AceAddon-3.0"):GetAddon(name)` | `Loolib:GetAddon(name)` |
| **Enable/Disable** | `addon:Enable()`, `addon:Disable()` | Same |
| **Default Module State** | `addon:SetDefaultModuleState(state)` | Same |
| **Default Module Libraries** | `addon:SetDefaultModuleLibraries(...)` | Same |
| **Default Module Prototype** | `addon:SetDefaultModulePrototype(proto)` | Same |

**Migration from AceAddon-3.0:**

Most AceAddon-3.0 code will work with minimal changes:

```lua
-- AceAddon-3.0
local MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceEvent-3.0", "AceTimer-3.0")

-- Loolib
local Loolib = LibStub("Loolib")
local MyAddon = Loolib:NewAddon("MyAddon", "EventFrame", "Timer")
```

**Key Differences:**
1. Different library names (AceEvent → EventFrame, AceTimer → Timer)
2. Event registration syntax may differ slightly
3. Module callbacks: prefer `OnModuleEnable`/`OnModuleDisable` for clarity
4. Loolib uses Blizzard's mixin pattern throughout

---

## Summary

The Loolib addon lifecycle system provides a robust, modern framework for WoW addon development:

- **Structured lifecycle** with clear initialization, enable, and disable phases
- **Modular architecture** supporting nested hierarchies
- **Library embedding** via mixin pattern for code reuse
- **Automatic lifecycle management** tied to WoW events
- **Error handling** with pcall wrapping of all callbacks
- **Flexible configuration** with default module settings
- **Compatible patterns** familiar to AceAddon-3.0 users

Use this system as the foundation for building maintainable, well-organized WoW addons that scale from simple to complex.
