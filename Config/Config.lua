--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Config - Main entry point for the configuration system

    Provides a unified API for registering and managing addon options.
    Combines registry, command, dialog, and profile helpers.
----------------------------------------------------------------------]]

local ipairs = ipairs
local select = select
local string_format = string.format
local type = type

local StaticPopup_Show = StaticPopup_Show

---@diagnostic disable: undefined-doc-name

local Loolib = LibStub("Loolib")
local Config = Loolib:GetOrCreateModule("Config")

Loolib.Config = Config

Loolib.Config.Compat = Config.Compat or {}

--[[--------------------------------------------------------------------
    Compatibility Wrappers

    These keep WoW's slash command and popup integration behind a
    namespace-scoped API instead of scattering direct global writes.
----------------------------------------------------------------------]]

---@param commandId string
---@param slashcmd string
---@param handler function
function Config.Compat:RegisterSlashCommand(commandId, slashcmd, handler)
    if type(commandId) ~= "string" or commandId == "" then
        error("Loolib.Config.Compat:RegisterSlashCommand: commandId must be a non-empty string", 2)
    end
    if type(slashcmd) ~= "string" or slashcmd == "" then
        error("Loolib.Config.Compat:RegisterSlashCommand: slashcmd must be a non-empty string", 2)
    end
    if type(handler) ~= "function" then
        error("Loolib.Config.Compat:RegisterSlashCommand: handler must be a function", 2)
    end

    SlashCmdList = SlashCmdList or {}

    _G["SLASH_" .. commandId .. "1"] = "/" .. slashcmd
    SlashCmdList[commandId] = handler

    return commandId
end

---@param commandId string
---@return boolean
function Config.Compat:UnregisterSlashCommand(commandId)
    if type(commandId) ~= "string" or commandId == "" then
        return false
    end

    local index = 1
    while _G["SLASH_" .. commandId .. index] do
        _G["SLASH_" .. commandId .. index] = nil
        index = index + 1
    end

    if SlashCmdList then
        SlashCmdList[commandId] = nil
    end
    return true
end

---@param popupName string
---@param definition StaticPopupInfo
---@return StaticPopupInfo
function Config.Compat:EnsureStaticPopup(popupName, definition)
    if type(popupName) ~= "string" or popupName == "" then
        error("Loolib.Config.Compat:EnsureStaticPopup: popupName must be a non-empty string", 2)
    end
    if type(definition) ~= "table" then
        error("Loolib.Config.Compat:EnsureStaticPopup: definition must be a table", 2)
    end

    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs[popupName] = StaticPopupDialogs[popupName] or definition
    return StaticPopupDialogs[popupName]
end

---@param popupName string
---@param text string|nil
---@param data any
---@return Frame|nil
function Config.Compat:ShowStaticPopup(popupName, text, data)
    local dialogs = StaticPopupDialogs
    ---@type StaticPopupInfo|nil
    local dialog = dialogs and dialogs[popupName]
    if not dialog then
        return nil
    end

    if text ~= nil then
        dialog.text = text
    end

    return StaticPopup_Show(popupName, nil, nil, data)
end

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

function Config:Initialize()
    self.Types = self.Types or Config.Types
    self.Registry = self.Registry or Config.Registry
    self.Cmd = self.Cmd or Config.Cmd
    self.Dialog = self.Dialog or Config.Dialog
    self.DialogTheme = self.DialogTheme or Config.DialogTheme
    self.ProfileOptions = self.ProfileOptions or Config.ProfileOptions
    self.Compat = self.Compat or Config.Compat
end

--[[--------------------------------------------------------------------
    Localization Support
----------------------------------------------------------------------]]

function Config:GetLocaleString(key, ...)
    local strings = {
        VALIDATION_ERROR = "Validation failed: %s",
        REQUIRED_ERROR = "Value is required",
        RANGE_ERROR = "Value must be between %s and %s",
    }

    local str = strings[key] or key
    if select("#", ...) > 0 then
        local success, result = pcall(string_format, str, ...)
        if success then
            return result
        end
    end

    return str
end

--[[--------------------------------------------------------------------
    Convenience Registration
----------------------------------------------------------------------]]

function Config:RegisterOptionsTable(appName, options, slashcmd)
    self:Initialize()

    if not self.Registry then
        Loolib:Error("Loolib.Config.Registry not loaded")
        return false
    end

    local success = self.Registry:RegisterOptionsTable(appName, options)
    if not success then
        return false
    end

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

function Config:UnregisterOptionsTable(appName)
    if not self.Registry then
        return false
    end

    if self.Cmd then
        self.Cmd:UnregisterChatCommands(appName)
    end

    return self.Registry:UnregisterOptionsTable(appName)
end

--[[--------------------------------------------------------------------
    Options Table Access
----------------------------------------------------------------------]]

function Config:GetOptionsTable(appName, uiType)
    self:Initialize()
    return self.Registry and self.Registry:GetOptionsTable(appName, uiType)
end

function Config:IsRegistered(appName)
    return self.Registry and self.Registry:IsRegistered(appName)
end

function Config:NotifyChange(appName)
    if self.Registry then
        self.Registry:NotifyChange(appName)
    end
end

--[[--------------------------------------------------------------------
    Dialog Access
----------------------------------------------------------------------]]

function Config:Open(appName, ...)
    self:Initialize()
    return self.Dialog and self.Dialog:Open(appName, nil, ...)
end

function Config:Close(appName)
    if not self.Dialog then
        return
    end

    if appName then
        self.Dialog:Close(appName)
    else
        self.Dialog:CloseAll()
    end
end

function Config:AddToBlizOptions(appName, name, parent)
    self:Initialize()
    return self.Dialog and self.Dialog:AddToBlizOptions(appName, name, parent)
end

--[[--------------------------------------------------------------------
    Dialog Theming

    Per-app and global theme overrides for ConfigDialog. Themes are
    sparse tables; missing keys fall through:
        per-app override -> active global theme -> built-in default

    See Loolib/docs/ConfigDialog.md "Theming the dialog" for the full
    list of supported keys (colors, backdrops, fonts, layout,
    widgetFactories, afterCreateWidget) and an end-to-end example.
----------------------------------------------------------------------]]

--- Register a theme override for a specific appName.
-- @param appName string - The registered app name (must match Open(appName))
-- @param themeTable table|nil - Sparse theme table, or nil to clear
-- @return boolean - True on success
function Config:RegisterAppTheme(appName, themeTable)
    self:Initialize()
    if not self.DialogTheme then
        return false
    end
    return self.DialogTheme:RegisterAppTheme(appName, themeTable)
end

--- Register a named global theme. Activate it via SetActiveDialogTheme.
-- @param themeName string - The theme's identifier
-- @param themeTable table|nil - Sparse theme table, or nil to delete
-- @return boolean - True on success
function Config:RegisterDialogTheme(themeName, themeTable)
    self:Initialize()
    if not self.DialogTheme then
        return false
    end
    return self.DialogTheme:RegisterDialogTheme(themeName, themeTable)
end

--- Set the active global theme. Pass nil to revert to the built-in default.
-- @param themeName string|nil
-- @return boolean - True on success
function Config:SetActiveDialogTheme(themeName)
    self:Initialize()
    if not self.DialogTheme then
        return false
    end
    return self.DialogTheme:SetActiveDialogTheme(themeName)
end

--- Get the resolved theme that would apply to the given appName.
-- @param appName string|nil - Optional appName for per-app resolution
-- @return table|nil - Fully-resolved theme table
function Config:GetDialogTheme(appName)
    self:Initialize()
    if not self.DialogTheme then
        return nil
    end
    return self.DialogTheme:Resolve(appName)
end

--[[--------------------------------------------------------------------
    Command-Line Access
----------------------------------------------------------------------]]

function Config:HandleCommand(slashcmd, appName, input)
    self:Initialize()
    if self.Cmd then
        self.Cmd:HandleCommand(slashcmd, appName, input)
    end
end

--[[--------------------------------------------------------------------
    Profile Options
----------------------------------------------------------------------]]

function Config:GetProfileOptions(db, noDefaultProfiles)
    self:Initialize()
    return self.ProfileOptions and self.ProfileOptions:GetOptionsTable(db, noDefaultProfiles)
end

--[[--------------------------------------------------------------------
    Value Helpers
----------------------------------------------------------------------]]

function Config:ResolveValue(valueOrFunc, info)
    if self.Registry then
        return self.Registry:ResolveValue(valueOrFunc, info)
    end

    if type(valueOrFunc) == "function" then
        return valueOrFunc(info)
    end

    return valueOrFunc
end

function Config:BuildInfoTable(options, option, appName, ...)
    if self.Registry then
        return self.Registry:BuildInfoTable(options, option, appName, ...)
    end

    return {}
end

Loolib:RegisterModule("Config", Config)
Config:Initialize()
