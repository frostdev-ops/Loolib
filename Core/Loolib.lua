--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Core namespace and module registration
----------------------------------------------------------------------]]

local LOOLIB_MAJOR = "Loolib"
local LOOLIB_MINOR = 1

local Loolib, oldVersion = LibStub:NewLibrary(LOOLIB_MAJOR, LOOLIB_MINOR)
if not Loolib then return end

-- Preserve existing data on upgrade
Loolib.modules = Loolib.modules or {}
Loolib.addons = Loolib.addons or {}  -- Addon registry (populated by Core/Addon.lua)
Loolib.version = LOOLIB_MINOR

--[[--------------------------------------------------------------------
    Module Registration
----------------------------------------------------------------------]]

--- Register a module with the library
-- @param name string - The module name (e.g., "UI", "Events")
-- @param tbl table - The module table
-- @return table - The registered module
function Loolib:RegisterModule(name, tbl)
    assert(type(name) == "string", "Module name must be a string")
    assert(type(tbl) == "table", "Module must be a table")

    self.modules[name] = tbl
    return tbl
end

--- Get a registered module
-- @param name string - The module name
-- @return table|nil - The module table, or nil if not found
function Loolib:GetModule(name)
    return self.modules[name]
end

--- Get or create a module
-- @param name string - The module name
-- @return table - The existing or new module table
function Loolib:GetOrCreateModule(name)
    if not self.modules[name] then
        self.modules[name] = {}
    end
    return self.modules[name]
end

--- Check if a module exists
-- @param name string - The module name
-- @return boolean
function Loolib:HasModule(name)
    return self.modules[name] ~= nil
end

--- Iterate over all registered modules
-- @return iterator
function Loolib:IterateModules()
    return pairs(self.modules)
end

--[[--------------------------------------------------------------------
    Version Information
----------------------------------------------------------------------]]

--- Get the library version
-- @return number - The minor version number
function Loolib:GetVersion()
    return self.version
end

--- Get the full version string
-- @return string
function Loolib:GetVersionString()
    return string.format("%s v%d", LOOLIB_MAJOR, self.version)
end

--[[--------------------------------------------------------------------
    Debug Utilities
----------------------------------------------------------------------]]

Loolib.debug = Loolib.debug or false

--- Enable or disable debug mode
-- @param enabled boolean
function Loolib:SetDebug(enabled)
    self.debug = enabled
end

--- Check if debug mode is enabled
-- @return boolean
function Loolib:IsDebug()
    return self.debug
end

--- Print a debug message (only if debug mode is enabled)
-- @param ... - Values to print
function Loolib:Debug(...)
    if self.debug then
        print("|cff00ff00[Loolib]|r", ...)
    end
end

--- Print an error message
-- @param ... - Values to print
function Loolib:Error(...)
    print("|cffff0000[Loolib Error]|r", ...)
end

--[[--------------------------------------------------------------------
    Addon Management API (implemented in Core/Addon.lua)

    These stubs document the API and will be overwritten when
    Addon.lua loads. This ensures the functions exist even if
    accessed before Addon.lua is fully loaded.
----------------------------------------------------------------------]]

--- Create a new addon with lifecycle management
-- Signature variants:
--   NewAddon(name) -> creates new addon
--   NewAddon(name, lib1, lib2, ...) -> creates addon with embedded libraries
--   NewAddon(existingObject, name) -> uses existingObject as base
--   NewAddon(existingObject, name, lib1, lib2, ...) -> uses object + embeds libs
-- @param arg1 table|string - Either an existing object or the addon name
-- @param arg2 string - The addon name (if arg1 is an object)
-- @param ... - Optional library names to embed
-- @return table - The addon object with LoolibAddonMixin applied
-- @see LoolibAddonMixin
function Loolib:NewAddon(arg1, arg2, ...)
    -- Stub - implemented in Core/Addon.lua
    error("Loolib:NewAddon requires Core/Addon.lua to be loaded", 2)
end

--- Get an addon by name
-- @param name string - The addon name
-- @param silent boolean|nil - If true, don't error if addon not found
-- @return table|nil - The addon object, or nil if not found and silent
function Loolib:GetAddon(name, silent)
    -- Stub - implemented in Core/Addon.lua
    local addon = self.addons[name]
    if not addon and not silent then
        error(string.format("Addon '%s' does not exist", name), 2)
    end
    return addon
end

--- Iterate over all registered addons
-- @return iterator - pairs iterator over addon name -> addon object
function Loolib:IterateAddons()
    -- Stub - implemented in Core/Addon.lua
    return pairs(self.addons)
end

--- Embed a library into a target object
-- Looks up library from Loolib.modules first, then falls back to LibStub.
-- Calls library.OnEmbed(target) if the library defines it.
-- @param target table - The object to embed the library into
-- @param libName string - The library name to embed
-- @return boolean - True if library was found and embedded
function Loolib:EmbedLibrary(target, libName)
    -- Stub - implemented in Core/Addon.lua
    local lib = self.modules[libName]
    if lib then
        for k, v in pairs(lib) do
            target[k] = v
        end
        if lib.OnEmbed then
            lib:OnEmbed(target)
        end
        return true
    end
    return false
end

--- Embed multiple libraries into a target object
-- @param target table - The object to embed libraries into
-- @param ... - Library names to embed (varargs)
function Loolib:EmbedLibraries(target, ...)
    for i = 1, select("#", ...) do
        local libName = select(i, ...)
        if type(libName) == "string" then
            self:EmbedLibrary(target, libName)
        end
    end
end
