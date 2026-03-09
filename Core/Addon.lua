local Loolib = LibStub("Loolib")

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

local AddonModule = Loolib.Addon or {}
local AddonMixin = AddonModule.Mixin or {}
-- FIX(critical-01): Resolve Loolib.Mixin as the raw apply function directly,
-- not as a module table. After Timer.Mixin registers, "Mixin" is no longer a stable leaf alias.
local ApplyMixins = assert(Loolib.Mixin, "Loolib.Mixin must be loaded before Core/Addon.lua")

local CreateFrame = CreateFrame
local assert = assert
local error = error
local format = string.format
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local print = print
local select = select
local type = type

local tinsert = table.insert

-- Initialization state tracking
local initializationComplete = false
local enableComplete = false
local addonQueue = {}
local enableQueue = {}

local function EnsureAddonState(addon, name, parentAddon)
    addon.name = name or addon.name
    addon.parentAddon = parentAddon
    addon.modules = addon.modules or {}
    addon.orderedModules = addon.orderedModules or {}
    if addon.defaultModuleState == nil then
        addon.defaultModuleState = true
    end
    if addon.enabledState == nil then
        addon.enabledState = false
    end
end

local function ResolveLibrary(libName)
    local lib = Loolib:GetModule(libName)
    if lib then
        return lib
    end

    if type(libName) == "string" and not libName:find("%.") then
        lib = Loolib[libName]
        if lib then
            return lib
        end

        lib = Loolib:GetModule("Core." .. libName)
        if lib then
            return lib
        end
    end

    local success
    success, lib = pcall(LibStub, libName)
    if success then
        return lib
    end

    return nil
end

local function InitializeAddon(addon)
    if addon._initialized then
        return
    end

    addon._initialized = true

    if addon.OnInitialize then
        local success, err = pcall(addon.OnInitialize, addon)
        if not success then
            Loolib:Error(format("Error in OnInitialize for '%s': %s", addon.name, err))
        end
    end
end

local function EnableAddon(addon)
    addon:Enable()
end

local function ProcessInitQueue()
    for _, addon in ipairs(addonQueue) do
        InitializeAddon(addon)
    end
    initializationComplete = true
end

local function ProcessEnableQueue()
    for _, addon in ipairs(addonQueue) do
        EnableAddon(addon)
    end
    enableComplete = true
end

--[[--------------------------------------------------------------------
    Module Management
----------------------------------------------------------------------]]

--- Create a new module (sub-component) of this addon
-- @param name string - The module name
-- @param prototype table|nil - Optional table to use as module base
-- @param ... - Optional libraries to embed (varargs)
-- @return table - The module object
function AddonMixin:NewModule(name, prototype, ...)
    assert(type(name) == "string" and name ~= "", "Module name must be a non-empty string")

    if self.modules[name] then
        error(format("Module '%s' already exists in addon '%s'", name, self.name), 2)
    end

    local module
    if type(prototype) == "table" then
        module = prototype
    else
        module = {}
    end

    ApplyMixins(module, AddonMixin)

    if self.defaultModulePrototype then
        ApplyMixins(module, self.defaultModulePrototype)
    end

    EnsureAddonState(module, name, self)
    module.defaultModuleLibraries = nil
    module.defaultModulePrototype = nil

    if type(prototype) == "string" then
        Loolib:EmbedLibrary(module, prototype)
    end

    if self.defaultModuleLibraries then
        for _, libName in ipairs(self.defaultModuleLibraries) do
            Loolib:EmbedLibrary(module, libName)
        end
    end

    for index = 1, select("#", ...) do
        local libName = select(index, ...)
        if type(libName) == "string" and libName ~= "" then
            Loolib:EmbedLibrary(module, libName)
        end
    end

    self.modules[name] = module
    tinsert(self.orderedModules, module)

    if module.OnModuleCreated then
        local success, err = pcall(module.OnModuleCreated, module)
        if not success then
            Loolib:Error(format("Error in OnModuleCreated for module '%s': %s", name, err))
        end
    end

    if self.enabledState and self.defaultModuleState then
        module:Enable()
    end

    return module
end

--- Get a module by name
-- @param name string - The module name
-- @param silent boolean|nil - If true, don't error if not found
-- @return table|nil - The module or nil
function AddonMixin:GetModule(name, silent)
    local module = self.modules[name]
    if not module and not silent then
        error(format("Module '%s' does not exist in addon '%s'", name, self.name), 2)
    end
    return module
end

--- Iterate over all modules
-- @return iterator
function AddonMixin:IterateModules()
    return pairs(self.modules)
end

--- Iterate over all modules in creation order
-- @return iterator
function AddonMixin:IterateOrderedModules()
    local index = 0
    return function()
        index = index + 1
        local module = self.orderedModules[index]
        if module then
            return module.name, module
        end
    end
end

--[[--------------------------------------------------------------------
    Enable/Disable State Management
----------------------------------------------------------------------]]

--- Enable this addon or module
function AddonMixin:Enable()
    if self.enabledState then
        return
    end

    self.enabledState = true

    if self.parentAddon then
        if self.OnModuleEnable then
            local success, err = pcall(self.OnModuleEnable, self)
            if not success then
                Loolib:Error(format("Error in OnModuleEnable for '%s': %s", self.name, err))
            end
        elseif self.OnEnable then
            local success, err = pcall(self.OnEnable, self)
            if not success then
                Loolib:Error(format("Error in OnEnable for module '%s': %s", self.name, err))
            end
        end
    elseif self.OnEnable then
        local success, err = pcall(self.OnEnable, self)
        if not success then
            Loolib:Error(format("Error in OnEnable for '%s': %s", self.name, err))
        end
    end

    for _, module in ipairs(self.orderedModules) do
        if self.defaultModuleState then
            module:Enable()
        end
    end
end

--- Disable this addon or module
function AddonMixin:Disable()
    if not self.enabledState then
        return
    end

    self.enabledState = false

    if self.CancelAllTimers then
        self:CancelAllTimers()
    end

    for _, module in ipairs(self.orderedModules) do
        module:Disable()
    end

    if self.parentAddon then
        if self.OnModuleDisable then
            local success, err = pcall(self.OnModuleDisable, self)
            if not success then
                Loolib:Error(format("Error in OnModuleDisable for '%s': %s", self.name, err))
            end
        elseif self.OnDisable then
            local success, err = pcall(self.OnDisable, self)
            if not success then
                Loolib:Error(format("Error in OnDisable for module '%s': %s", self.name, err))
            end
        end
    elseif self.OnDisable then
        local success, err = pcall(self.OnDisable, self)
        if not success then
            Loolib:Error(format("Error in OnDisable for '%s': %s", self.name, err))
        end
    end
end

--- Enable a specific module by name
-- @param name string - The module name
function AddonMixin:EnableModule(name)
    local module = self:GetModule(name)
    if module then
        module:Enable()
    end
end

--- Disable a specific module by name
-- @param name string - The module name
function AddonMixin:DisableModule(name)
    local module = self:GetModule(name)
    if module then
        module:Disable()
    end
end

--- Check if this addon/module is enabled
-- @return boolean
function AddonMixin:IsEnabled()
    return self.enabledState
end

--- Set enabled state without calling callbacks
-- @param state boolean
function AddonMixin:SetEnabledState(state)
    self.enabledState = state
end

--[[--------------------------------------------------------------------
    Default Module Configuration
----------------------------------------------------------------------]]

--- Set whether new modules are enabled by default when addon is enabled
-- @param state boolean (default true)
function AddonMixin:SetDefaultModuleState(state)
    self.defaultModuleState = state
end

--- Set default libraries to embed in new modules
-- @param ... - Library names (varargs)
function AddonMixin:SetDefaultModuleLibraries(...)
    local libs = { ... }
    if #libs > 0 then
        self.defaultModuleLibraries = libs
    else
        self.defaultModuleLibraries = nil
    end
end

--- Set default prototype for new modules
-- @param proto table
function AddonMixin:SetDefaultModulePrototype(proto)
    self.defaultModulePrototype = proto
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Get the addon/module name
-- @return string
function AddonMixin:GetName()
    return self.name
end

--- Print a message prefixed with addon name
-- @param ... - Values to print
function AddonMixin:Print(...)
    print(format("|cff33ff99%s|r:", self.name), ...)
end

--- Print a debug message (only if Loolib debug is enabled)
-- @param ... - Values to print
function AddonMixin:Debug(...)
    if Loolib:IsDebug() then
        print(format("|cff00ff00[%s Debug]|r", self.name), ...)
    end
end

--[[--------------------------------------------------------------------
    Loolib Addon Management API
----------------------------------------------------------------------]]

--- Create a new addon
-- Signature variants:
--   NewAddon(name) -> creates new addon
--   NewAddon(name, lib1, lib2, ...) -> creates addon with embedded libraries
--   NewAddon(existingObject, name) -> uses existingObject as base
--   NewAddon(existingObject, name, lib1, lib2, ...) -> uses object + embeds libs
-- @return table - The addon object
local function NewAddon(self, arg1, arg2, ...)
    local addon
    local name
    local libs

    if type(arg1) == "table" then
        addon = arg1
        name = arg2
        libs = { ... }
    elseif type(arg1) == "string" then
        addon = {}
        name = arg1
        libs = { arg2, ... }
    else
        error("Usage: Loolib:NewAddon([object,] name, [lib1, lib2, ...])", 2)
    end

    assert(type(name) == "string" and name ~= "", "Addon name must be a non-empty string")

    if Loolib.addons[name] then
        error(format("Addon '%s' already exists", name), 2)
    end

    ApplyMixins(addon, AddonMixin)
    EnsureAddonState(addon, name, nil)
    addon.defaultModuleLibraries = nil
    addon.defaultModulePrototype = nil

    for _, libName in ipairs(libs) do
        if type(libName) == "string" and libName ~= "" then
            Loolib:EmbedLibrary(addon, libName)
        end
    end

    Loolib.addons[name] = addon
    tinsert(addonQueue, addon)

    if initializationComplete then
        InitializeAddon(addon)
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

--- Embed a library into a target object
-- @param target table - The object to embed into
-- @param libName string - The library name
local function EmbedLibrary(self, target, libName)
    local lib = ResolveLibrary(libName)
    if not lib then
        Loolib:Debug(format("Library '%s' not found for embedding", libName))
        return false
    end

    ApplyMixins(target, lib)

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
    for index = 1, select("#", ...) do
        local libName = select(index, ...)
        if type(libName) == "string" and libName ~= "" then
            self:EmbedLibrary(target, libName)
        end
    end
end

--[[--------------------------------------------------------------------
    Event Frame for Lifecycle Events
----------------------------------------------------------------------]]

local AddonLifecycleFrame = CreateFrame("Frame")

AddonLifecycleFrame:RegisterEvent("ADDON_LOADED")
AddonLifecycleFrame:RegisterEvent("PLAYER_LOGIN")

AddonLifecycleFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if not initializationComplete then
            ProcessInitQueue()
        else
            for _, addon in ipairs(addonQueue) do
                InitializeAddon(addon)
            end
        end
    elseif event == "PLAYER_LOGIN" then
        ProcessEnableQueue()
    end
end)

--[[--------------------------------------------------------------------
    Register Functions with Loolib
----------------------------------------------------------------------]]

Loolib.addons = Loolib.addons or {}

Loolib.NewAddon = NewAddon
Loolib.GetAddon = GetAddon
Loolib.IterateAddons = IterateAddons
Loolib.EmbedLibrary = EmbedLibrary
Loolib.EmbedLibraries = EmbedLibraries

--[[--------------------------------------------------------------------
    Register Module
----------------------------------------------------------------------]]

Loolib.Addon = AddonModule
Loolib.Addon.Mixin = AddonMixin
Loolib.Addon.ProcessInitQueue = ProcessInitQueue
Loolib.Addon.ProcessEnableQueue = ProcessEnableQueue
Loolib.Addon.IsInitComplete = function()
    return initializationComplete
end
Loolib.Addon.IsEnableComplete = function()
    return enableComplete
end
Loolib.Addon.GetAddonQueue = function()
    return addonQueue
end

Loolib:RegisterModule("Core.Addon", AddonModule)
Loolib:RegisterModule("Addon.Mixin", AddonMixin)
