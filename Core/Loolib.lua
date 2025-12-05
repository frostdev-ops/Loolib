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
