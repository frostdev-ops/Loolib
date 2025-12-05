--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Addon Lifecycle System

    Provides AceAddon-3.0 equivalent functionality for addon lifecycle
    management including:
    - Addon registration and lookup
    - Module hierarchy (addons contain modules)
    - Library embedding
    - Lifecycle callbacks (OnInitialize, OnEnable, OnDisable)
    - Enable/disable state management
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Local References and State
----------------------------------------------------------------------]]

local type = type
local pairs = pairs
local ipairs = ipairs
local select = select
local error = error
local pcall = pcall
local tinsert = table.insert
local format = string.format

-- Initialization state tracking
local initializationComplete = false
local enableComplete = false
local addonQueue = {}  -- Addons waiting for initialization
local enableQueue = {} -- Addons waiting for enable

--[[--------------------------------------------------------------------
    LoolibAddonMixin

    Base mixin for all addon objects. Provides module management,
    enable/disable functionality, and lifecycle callback support.
----------------------------------------------------------------------]]

LoolibAddonMixin = {}

--[[--------------------------------------------------------------------
    Module Management
----------------------------------------------------------------------]]

--- Create a new module (sub-component) of this addon
-- @param name string - The module name
-- @param prototype table|nil - Optional table to use as module base
-- @param ... - Optional libraries to embed (varargs)
-- @return table - The module object
function LoolibAddonMixin:NewModule(name, prototype, ...)
    -- Validate name
    assert(type(name) == "string" and name ~= "", "Module name must be a non-empty string")

    -- Check for duplicate module names
    if self.modules[name] then
        error(format("Module '%s' already exists in addon '%s'", name, self.name), 2)
    end

    -- Handle variable arguments - prototype could be a string (library name)
    local module
    local libStart = 1

    if type(prototype) == "table" then
        module = prototype
        libStart = 1
    elseif type(prototype) == "string" then
        -- prototype is actually a library name
        module = {}
        -- Shift the library embedding to include prototype
        Loolib:EmbedLibrary(module, prototype)
    else
        module = {}
    end

    -- Apply LoolibAddonMixin (modules can have sub-modules)
    LoolibMixin(module, LoolibAddonMixin)

    -- Apply default module prototype if set
    if self.defaultModulePrototype then
        LoolibMixin(module, self.defaultModulePrototype)
    end

    -- Apply default module libraries
    if self.defaultModuleLibraries then
        for _, libName in ipairs(self.defaultModuleLibraries) do
            Loolib:EmbedLibrary(module, libName)
        end
    end

    -- Apply additional libraries from varargs
    local libs = {...}
    for i = libStart, #libs do
        local libName = libs[i]
        if type(libName) == "string" then
            Loolib:EmbedLibrary(module, libName)
        end
    end

    -- Set up module state
    module.name = name
    module.parentAddon = self
    module.modules = {}
    module.orderedModules = {}
    module.defaultModuleState = true
    module.enabledState = false
    module.defaultModuleLibraries = nil
    module.defaultModulePrototype = nil

    -- Register module
    self.modules[name] = module
    tinsert(self.orderedModules, module)

    -- Call OnModuleCreated if defined
    if module.OnModuleCreated then
        local success, err = pcall(module.OnModuleCreated, module)
        if not success then
            Loolib:Error(format("Error in OnModuleCreated for module '%s': %s", name, err))
        end
    end

    -- If addon is already enabled and default state is true, enable the module
    if self.enabledState and self.defaultModuleState then
        module:Enable()
    end

    return module
end

--- Get a module by name
-- @param name string - The module name
-- @param silent boolean|nil - If true, don't error if not found
-- @return table|nil - The module or nil
function LoolibAddonMixin:GetModule(name, silent)
    local module = self.modules[name]
    if not module and not silent then
        error(format("Module '%s' does not exist in addon '%s'", name, self.name), 2)
    end
    return module
end

--- Iterate over all modules
-- @return iterator
function LoolibAddonMixin:IterateModules()
    return pairs(self.modules)
end

--- Iterate over all modules in creation order
-- @return iterator
function LoolibAddonMixin:IterateOrderedModules()
    local i = 0
    return function()
        i = i + 1
        local module = self.orderedModules[i]
        if module then
            return module.name, module
        end
    end
end

--[[--------------------------------------------------------------------
    Enable/Disable State Management
----------------------------------------------------------------------]]

--- Enable this addon
-- Calls OnEnable() callback if present, enables modules with defaultModuleState
function LoolibAddonMixin:Enable()
    if self.enabledState then
        return
    end

    self.enabledState = true

    -- Call OnEnable callback
    if self.OnEnable then
        local success, err = pcall(self.OnEnable, self)
        if not success then
            Loolib:Error(format("Error in OnEnable for '%s': %s", self.name, err))
        end
    end

    -- Enable modules with defaultModuleState == true
    for _, module in ipairs(self.orderedModules) do
        if self.defaultModuleState then
            module:Enable()
        end
    end
end

--- Disable this addon
-- Calls OnDisable() callback if present, disables all modules
function LoolibAddonMixin:Disable()
    if not self.enabledState then
        return
    end

    self.enabledState = false

    -- Disable all modules first
    for _, module in ipairs(self.orderedModules) do
        module:Disable()
    end

    -- Call OnDisable callback
    if self.OnDisable then
        local success, err = pcall(self.OnDisable, self)
        if not success then
            Loolib:Error(format("Error in OnDisable for '%s': %s", self.name, err))
        end
    end
end

--- Enable a specific module by name
-- @param name string - The module name
function LoolibAddonMixin:EnableModule(name)
    local module = self:GetModule(name)
    if module then
        module:Enable()
    end
end

--- Disable a specific module by name
-- @param name string - The module name
function LoolibAddonMixin:DisableModule(name)
    local module = self:GetModule(name)
    if module then
        module:Disable()
    end
end

--- Check if this addon/module is enabled
-- @return boolean
function LoolibAddonMixin:IsEnabled()
    return self.enabledState
end

--- Set enabled state without calling callbacks
-- @param state boolean
function LoolibAddonMixin:SetEnabledState(state)
    self.enabledState = state
end

--[[--------------------------------------------------------------------
    Default Module Configuration
----------------------------------------------------------------------]]

--- Set whether new modules are enabled by default when addon is enabled
-- @param state boolean (default true)
function LoolibAddonMixin:SetDefaultModuleState(state)
    self.defaultModuleState = state
end

--- Set default libraries to embed in new modules
-- @param ... - Library names (varargs)
function LoolibAddonMixin:SetDefaultModuleLibraries(...)
    local libs = {...}
    if #libs > 0 then
        self.defaultModuleLibraries = libs
    else
        self.defaultModuleLibraries = nil
    end
end

--- Set default prototype for new modules
-- @param proto table
function LoolibAddonMixin:SetDefaultModulePrototype(proto)
    self.defaultModulePrototype = proto
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Get the addon/module name
-- @return string
function LoolibAddonMixin:GetName()
    return self.name
end

--- Print a message prefixed with addon name
-- @param ... - Values to print
function LoolibAddonMixin:Print(...)
    print(format("|cff33ff99%s|r:", self.name), ...)
end

--- Print a debug message (only if Loolib debug is enabled)
-- @param ... - Values to print
function LoolibAddonMixin:Debug(...)
    if Loolib:IsDebug() then
        print(format("|cff00ff00[%s Debug]|r", self.name), ...)
    end
end

--[[--------------------------------------------------------------------
    Module-Specific Enable/Disable (overrides for modules)

    When used on a module (not top-level addon), these call the
    OnModuleEnable/OnModuleDisable callbacks instead.
----------------------------------------------------------------------]]

-- Store original Enable/Disable
local AddonEnable = LoolibAddonMixin.Enable
local AddonDisable = LoolibAddonMixin.Disable

--- Enable implementation that handles both addons and modules
function LoolibAddonMixin:Enable()
    if self.enabledState then
        return
    end

    self.enabledState = true

    -- Determine if this is a module or a top-level addon
    if self.parentAddon then
        -- This is a module
        if self.OnModuleEnable then
            local success, err = pcall(self.OnModuleEnable, self)
            if not success then
                Loolib:Error(format("Error in OnModuleEnable for '%s': %s", self.name, err))
            end
        elseif self.OnEnable then
            -- Fallback to OnEnable for compatibility
            local success, err = pcall(self.OnEnable, self)
            if not success then
                Loolib:Error(format("Error in OnEnable for module '%s': %s", self.name, err))
            end
        end
    else
        -- This is a top-level addon
        if self.OnEnable then
            local success, err = pcall(self.OnEnable, self)
            if not success then
                Loolib:Error(format("Error in OnEnable for '%s': %s", self.name, err))
            end
        end
    end

    -- Enable child modules with defaultModuleState == true
    for _, module in ipairs(self.orderedModules) do
        if self.defaultModuleState then
            module:Enable()
        end
    end
end

--- Disable implementation that handles both addons and modules
function LoolibAddonMixin:Disable()
    if not self.enabledState then
        return
    end

    self.enabledState = false

    -- Disable all child modules first
    for _, module in ipairs(self.orderedModules) do
        module:Disable()
    end

    -- Determine if this is a module or a top-level addon
    if self.parentAddon then
        -- This is a module
        if self.OnModuleDisable then
            local success, err = pcall(self.OnModuleDisable, self)
            if not success then
                Loolib:Error(format("Error in OnModuleDisable for '%s': %s", self.name, err))
            end
        elseif self.OnDisable then
            -- Fallback to OnDisable for compatibility
            local success, err = pcall(self.OnDisable, self)
            if not success then
                Loolib:Error(format("Error in OnDisable for module '%s': %s", self.name, err))
            end
        end
    else
        -- This is a top-level addon
        if self.OnDisable then
            local success, err = pcall(self.OnDisable, self)
            if not success then
                Loolib:Error(format("Error in OnDisable for '%s': %s", self.name, err))
            end
        end
    end
end

--[[--------------------------------------------------------------------
    Internal Addon Management Functions

    These are added to the Loolib object itself (see below).
----------------------------------------------------------------------]]

--- Create a new addon
-- Signature variants:
--   NewAddon(name) -> creates new addon
--   NewAddon(name, lib1, lib2, ...) -> creates addon with embedded libraries
--   NewAddon(existingObject, name) -> uses existingObject as base
--   NewAddon(existingObject, name, lib1, lib2, ...) -> uses object + embeds libs
-- @return table - The addon object
local function NewAddon(self, arg1, arg2, ...)
    local addon, name, libs

    -- Parse arguments to determine signature
    if type(arg1) == "table" then
        -- NewAddon(existingObject, name, ...)
        addon = arg1
        name = arg2
        libs = {...}
    elseif type(arg1) == "string" then
        -- NewAddon(name, ...)
        addon = {}
        name = arg1
        libs = {arg2, ...}
    else
        error("Usage: Loolib:NewAddon([object,] name, [lib1, lib2, ...])", 2)
    end

    -- Validate name
    assert(type(name) == "string" and name ~= "", "Addon name must be a non-empty string")

    -- Check for duplicate addon names
    if Loolib.addons[name] then
        error(format("Addon '%s' already exists", name), 2)
    end

    -- Apply LoolibAddonMixin
    LoolibMixin(addon, LoolibAddonMixin)

    -- Set up addon state
    addon.name = name
    addon.modules = {}
    addon.orderedModules = {}
    addon.defaultModuleState = true
    addon.enabledState = false
    addon.defaultModuleLibraries = nil
    addon.defaultModulePrototype = nil
    addon.parentAddon = nil  -- nil indicates top-level addon

    -- Embed requested libraries
    for _, libName in ipairs(libs) do
        if type(libName) == "string" and libName ~= "" then
            Loolib:EmbedLibrary(addon, libName)
        end
    end

    -- Register the addon
    Loolib.addons[name] = addon

    -- Add to initialization queue
    tinsert(addonQueue, addon)

    -- If initialization has already happened (late registration), initialize immediately
    if initializationComplete then
        InitializeAddon(addon)

        -- If enabling has also happened, enable immediately
        if enableComplete then
            EnableAddon(addon)
        end
    end

    return addon
end

--- Get an addon by name
-- @param name string - The addon name
-- @param silent boolean|nil - If true, don't error if not found
-- @return table|nil - The addon or nil
local function GetAddon(self, name, silent)
    local addon = Loolib.addons[name]
    if not addon and not silent then
        error(format("Addon '%s' does not exist", name), 2)
    end
    return addon
end

--- Iterate over all registered addons
-- @return iterator
local function IterateAddons(self)
    return pairs(Loolib.addons)
end

--[[--------------------------------------------------------------------
    Library Embedding
----------------------------------------------------------------------]]

--- Embed a library into a target object
-- @param target table - The object to embed into
-- @param libName string - The library name
local function EmbedLibrary(self, target, libName)
    -- Try Loolib modules first
    local lib = Loolib.modules[libName]

    -- Try LibStub if not found in Loolib
    if not lib then
        local success
        success, lib = pcall(LibStub, libName)
        if not success then
            lib = nil
        end
    end

    if not lib then
        Loolib:Debug(format("Library '%s' not found for embedding", libName))
        return false
    end

    -- Mixin the library
    LoolibMixin(target, lib)

    -- Call OnEmbed hook if it exists
    if lib.OnEmbed then
        local success, err = pcall(lib.OnEmbed, lib, target)
        if not success then
            Loolib:Error(format("Error in OnEmbed for library '%s': %s", libName, err))
        end
    end

    return true
end

--- Embed multiple libraries into a target object
-- @param target table - The object to embed into
-- @param ... - Library names (varargs)
local function EmbedLibraries(self, target, ...)
    for i = 1, select("#", ...) do
        local libName = select(i, ...)
        if type(libName) == "string" and libName ~= "" then
            self:EmbedLibrary(target, libName)
        end
    end
end

--[[--------------------------------------------------------------------
    Lifecycle Event Handlers
----------------------------------------------------------------------]]

--- Initialize an addon (call OnInitialize)
local function InitializeAddon(addon)
    if addon.OnInitialize then
        local success, err = pcall(addon.OnInitialize, addon)
        if not success then
            Loolib:Error(format("Error in OnInitialize for '%s': %s", addon.name, err))
        end
    end
end

--- Enable an addon (call Enable which triggers OnEnable)
local function EnableAddon(addon)
    addon:Enable()
end

--- Process addon initialization queue
local function ProcessInitQueue()
    for _, addon in ipairs(addonQueue) do
        InitializeAddon(addon)
    end
    initializationComplete = true
end

--- Process addon enable queue
local function ProcessEnableQueue()
    for _, addon in ipairs(addonQueue) do
        EnableAddon(addon)
    end
    enableComplete = true
end

--[[--------------------------------------------------------------------
    Event Frame for Lifecycle Events
----------------------------------------------------------------------]]

local AddonLifecycleFrame = CreateFrame("Frame")

AddonLifecycleFrame:RegisterEvent("ADDON_LOADED")
AddonLifecycleFrame:RegisterEvent("PLAYER_LOGIN")

AddonLifecycleFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        -- Check if Loolib itself just loaded (first ADDON_LOADED after Loolib loads)
        -- We process the queue on any ADDON_LOADED since addons may have been
        -- registered synchronously before this event
        if not initializationComplete then
            ProcessInitQueue()
        else
            -- Late addon registration - check if any new addons need initialization
            for _, addon in ipairs(addonQueue) do
                if not addon._initialized then
                    InitializeAddon(addon)
                    addon._initialized = true
                end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        ProcessEnableQueue()
    end
end)

--[[--------------------------------------------------------------------
    Register Functions with Loolib
----------------------------------------------------------------------]]

-- Initialize addon storage
Loolib.addons = Loolib.addons or {}

-- Add methods to Loolib
Loolib.NewAddon = NewAddon
Loolib.GetAddon = GetAddon
Loolib.IterateAddons = IterateAddons
Loolib.EmbedLibrary = EmbedLibrary
Loolib.EmbedLibraries = EmbedLibraries

--[[--------------------------------------------------------------------
    Register Module
----------------------------------------------------------------------]]

local AddonModule = {
    Mixin = LoolibAddonMixin,

    -- Expose internal functions for testing/advanced use
    ProcessInitQueue = ProcessInitQueue,
    ProcessEnableQueue = ProcessEnableQueue,

    -- State accessors for debugging
    IsInitComplete = function() return initializationComplete end,
    IsEnableComplete = function() return enableComplete end,
    GetAddonQueue = function() return addonQueue end,
}

Loolib:RegisterModule("Addon", AddonModule)
