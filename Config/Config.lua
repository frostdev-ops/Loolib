--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Config - Main entry point for the configuration system

    Provides a unified API for registering and managing addon options.
    Combines ConfigRegistry and ConfigCmd for a simplified experience.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibConfig

    Main configuration system entry point. Provides convenience methods
    that combine the registry and command-line subsystems.
----------------------------------------------------------------------]]

LoolibConfig = {}

-- References to submodules (populated after they load)
LoolibConfig.Types = nil       -- Set in ConfigTypes.lua
LoolibConfig.Registry = nil    -- Set in ConfigRegistry.lua
LoolibConfig.Cmd = nil         -- Set in ConfigCmd.lua
LoolibConfig.Dialog = nil      -- Set in ConfigDialog.lua
LoolibConfig.ProfileOptions = nil  -- Set in ProfileOptions.lua

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the config system with references to submodules
-- Called after all Config modules are loaded
function LoolibConfig:Initialize()
    local RegistryModule = Loolib:GetModule("ConfigRegistry")
    local CmdModule = Loolib:GetModule("ConfigCmd")
    local DialogModule = Loolib:GetModule("ConfigDialog")
    local ProfileOptionsModule = Loolib:GetModule("ProfileOptions")
    local TypesModule = Loolib:GetModule("ConfigTypes")

    self.Types = TypesModule
    self.Registry = RegistryModule and RegistryModule.Registry
    self.Cmd = CmdModule and CmdModule.Cmd
    self.Dialog = DialogModule and DialogModule.Dialog
    self.ProfileOptions = ProfileOptionsModule
end

--[[--------------------------------------------------------------------
    Convenience Registration
----------------------------------------------------------------------]]

--- Register an options table with optional slash command
-- This is the primary entry point for addon configuration registration.
-- @param appName string - Unique identifier for the addon
-- @param options table|function - Options table or function returning options
-- @param slashcmd string|table - Slash command(s) to register (optional)
-- @return boolean - Success
--
-- Example:
--   LoolibConfig:RegisterOptionsTable("MyAddon", myOptions, "myaddon")
--   -- Now /myaddon opens config and MyAddon is registered
function LoolibConfig:RegisterOptionsTable(appName, options, slashcmd)
    -- Ensure we're initialized
    if not self.Registry then
        self:Initialize()
    end

    if not self.Registry then
        Loolib:Error("ConfigRegistry not loaded")
        return false
    end

    -- Register the options table
    local success = self.Registry:RegisterOptionsTable(appName, options)
    if not success then
        return false
    end

    -- Register slash command if provided
    if slashcmd and self.Cmd then
        if type(slashcmd) == "string" then
            self.Cmd:CreateChatCommand(slashcmd, appName)
        elseif type(slashcmd) == "table" then
            for _, cmd in ipairs(slashcmd) do
                self.Cmd:CreateChatCommand(cmd, appName)
            end
        end
    end

    return true
end

--- Unregister an options table and its slash commands
-- @param appName string - The addon name
-- @return boolean - Success
function LoolibConfig:UnregisterOptionsTable(appName)
    if not self.Registry then
        return false
    end

    -- Unregister commands first
    if self.Cmd then
        self.Cmd:UnregisterChatCommands(appName)
    end

    return self.Registry:UnregisterOptionsTable(appName)
end

--[[--------------------------------------------------------------------
    Options Table Access
----------------------------------------------------------------------]]

--- Get an options table
-- @param appName string - The addon name
-- @param uiType string - UI type for filtering (optional)
-- @return table|nil - The options table
function LoolibConfig:GetOptionsTable(appName, uiType)
    if not self.Registry then
        self:Initialize()
    end
    return self.Registry and self.Registry:GetOptionsTable(appName, uiType)
end

--- Check if an options table is registered
-- @param appName string - The addon name
-- @return boolean
function LoolibConfig:IsRegistered(appName)
    return self.Registry and self.Registry:IsRegistered(appName)
end

--- Notify that options have changed (refresh UIs)
-- @param appName string - The addon name (or nil for all)
function LoolibConfig:NotifyChange(appName)
    if self.Registry then
        self.Registry:NotifyChange(appName)
    end
end

--[[--------------------------------------------------------------------
    Dialog Access
----------------------------------------------------------------------]]

--- Open the configuration dialog
-- @param appName string - The addon name
-- @param ... - Optional path to group
-- @return Frame|nil - The dialog frame
function LoolibConfig:Open(appName, ...)
    if not self.Dialog then
        self:Initialize()
    end
    return self.Dialog and self.Dialog:Open(appName, nil, ...)
end

--- Close the configuration dialog
-- @param appName string - The addon name (or nil for all)
function LoolibConfig:Close(appName)
    if self.Dialog then
        if appName then
            self.Dialog:Close(appName)
        else
            self.Dialog:CloseAll()
        end
    end
end

--- Add options to Blizzard Settings
-- @param appName string - The addon name
-- @param name string - Display name in settings
-- @param parent string - Parent category name (optional)
-- @param ... - Path to group (optional)
-- @return Frame|nil - The settings frame
function LoolibConfig:AddToBlizOptions(appName, name, parent, ...)
    if not self.Dialog then
        self:Initialize()
    end
    return self.Dialog and self.Dialog:AddToBlizOptions(appName, name, parent, ...)
end

--[[--------------------------------------------------------------------
    Command-Line Access
----------------------------------------------------------------------]]

--- Handle a slash command
-- @param slashcmd string - The slash command
-- @param appName string - The addon name
-- @param input string - User input
function LoolibConfig:HandleCommand(slashcmd, appName, input)
    if not self.Cmd then
        self:Initialize()
    end
    if self.Cmd then
        self.Cmd:HandleCommand(slashcmd, appName, input)
    end
end

--[[--------------------------------------------------------------------
    Profile Options
----------------------------------------------------------------------]]

--- Get profile options table for a database
-- @param db table - LoolibSavedVariables instance
-- @param noDefaultProfiles boolean - Don't include default profiles
-- @return table - Options table for profiles
function LoolibConfig:GetProfileOptions(db, noDefaultProfiles)
    if not self.ProfileOptions then
        self:Initialize()
    end
    return self.ProfileOptions and self.ProfileOptions:GetOptionsTable(db, noDefaultProfiles)
end

--[[--------------------------------------------------------------------
    Value Helpers (pass-through to Registry)
----------------------------------------------------------------------]]

--- Resolve a property value (handles functions)
-- @param valueOrFunc any - Static value or function
-- @param info table - Info table
-- @return any - Resolved value
function LoolibConfig:ResolveValue(valueOrFunc, info)
    if self.Registry then
        return self.Registry:ResolveValue(valueOrFunc, info)
    elseif type(valueOrFunc) == "function" then
        return valueOrFunc(info)
    end
    return valueOrFunc
end

--- Build info table for option callbacks
-- @param options table - Root options table
-- @param option table - Current option
-- @param appName string - App name
-- @param ... - Path to option
-- @return table - Info table
function LoolibConfig:BuildInfoTable(options, option, appName, ...)
    if self.Registry then
        return self.Registry:BuildInfoTable(options, option, appName, ...)
    end
    return {}
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib:RegisterModule("Config", LoolibConfig)
