--[[--------------------------------------------------------------------
    Loolib - Generic bridge for WoW global integrations
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local Compat = Loolib.Compat or Loolib:GetOrCreateModule("Compat")

local GlobalBridge = Compat.GlobalBridge or {}
Compat.GlobalBridge = GlobalBridge

local _G = _G
local error = error
local ipairs = ipairs
local pairs = pairs
local type = type
local tinsert = table.insert

local SlashCmdList = SlashCmdList
local StaticPopupDialogs = StaticPopupDialogs
local StaticPopup_Show = StaticPopup_Show

GlobalBridge.slashCommands = GlobalBridge.slashCommands or {}
GlobalBridge.staticPopups = GlobalBridge.staticPopups or {}
GlobalBridge.addonCompartments = GlobalBridge.addonCompartments or {}
GlobalBridge.namedCallbacks = GlobalBridge.namedCallbacks or {}

local function EnsureString(value, label, level)
    if type(value) ~= "string" or value == "" then
        error("Loolib.Compat.GlobalBridge: " .. label .. " must be a non-empty string", level or 3)
    end
end

local function EnsureTable(value, label, level)
    if type(value) ~= "table" then
        error("Loolib.Compat.GlobalBridge: " .. label .. " must be a table", level or 3)
    end
end

local function EnsureFunction(value, label, level)
    if type(value) ~= "function" then
        error("Loolib.Compat.GlobalBridge: " .. label .. " must be a function", level or 3)
    end
end

local function NormalizeSlashCommands(commands)
    local normalized = {}
    for _, command in ipairs(commands or {}) do
        if type(command) == "string" and command ~= "" then
            tinsert(normalized, command)
        end
    end
    return normalized
end

local function RegisterSlashCommandGlobals(commandId, commands, handler)
    local index = 1
    for _, slashCommand in ipairs(commands) do
        _G["SLASH_" .. commandId .. index] = slashCommand
        index = index + 1
    end
    SlashCmdList[commandId] = handler
end

local function GetCompartmentThunkName(addonName, eventName)
    return string.format("Loolib_GlobalBridge_%s_%s", addonName, eventName)
end

function GlobalBridge:RegisterSlashCommands(addonName, commands)
    EnsureString(addonName, "addonName", 2)
    EnsureTable(commands, "commands", 2)

    local addonCommands = {}

    for index, descriptor in ipairs(commands) do
        EnsureTable(descriptor, "commands[" .. index .. "]", 2)

        local commandId = descriptor.id or (addonName:upper() .. tostring(index))
        local slashCommands = NormalizeSlashCommands(descriptor.commands or {
            descriptor[1],
            descriptor[2],
            descriptor.command,
        })
        local handler = descriptor.handler or descriptor.func

        EnsureString(commandId, "commands[" .. index .. "].id", 2)
        EnsureFunction(handler, "commands[" .. index .. "].handler", 2)

        if #slashCommands == 0 then
            error("Loolib.Compat.GlobalBridge: commands[" .. index .. "] must include at least one slash command", 2)
        end

        RegisterSlashCommandGlobals(commandId, slashCommands, handler)

        addonCommands[#addonCommands + 1] = {
            id = commandId,
            commands = slashCommands,
            handler = handler,
        }
    end

    self.slashCommands[addonName] = addonCommands
    return addonCommands
end

function GlobalBridge:RegisterStaticPopup(addonName, popupName, definition)
    EnsureString(addonName, "addonName", 2)
    EnsureString(popupName, "popupName", 2)
    EnsureTable(definition, "definition", 2)

    self.staticPopups[addonName] = self.staticPopups[addonName] or {}
    self.staticPopups[addonName][popupName] = definition
    StaticPopupDialogs[popupName] = definition
    return definition
end

function GlobalBridge:ShowStaticPopup(addonName, popupName, text, data)
    EnsureString(addonName, "addonName", 2)
    EnsureString(popupName, "popupName", 2)

    local definitions = self.staticPopups[addonName]
    if not definitions or not definitions[popupName] then
        error("Loolib.Compat.GlobalBridge: popup '" .. popupName .. "' is not registered for addon '" .. addonName .. "'", 2)
    end

    return StaticPopup_Show(popupName, text, nil, data)
end

function GlobalBridge:RegisterNamedCallback(kind, addonName, handlers)
    EnsureString(kind, "kind", 2)
    EnsureString(addonName, "addonName", 2)
    EnsureTable(handlers, "handlers", 2)

    self.namedCallbacks[kind] = self.namedCallbacks[kind] or {}
    self.namedCallbacks[kind][addonName] = handlers
    return handlers
end

function GlobalBridge:RegisterAddonCompartment(addonName, handlers)
    EnsureString(addonName, "addonName", 2)
    EnsureTable(handlers, "handlers", 2)

    self.addonCompartments[addonName] = handlers

    local eventMap = {
        OnClick = "OnAddonCompartmentClick",
        OnEnter = "OnAddonCompartmentEnter",
        OnLeave = "OnAddonCompartmentLeave",
    }

    for handlerKey, eventName in pairs(eventMap) do
        local thunkName = GetCompartmentThunkName(addonName, eventName)
        _G[thunkName] = function(...)
            return GlobalBridge:DispatchAddonCompartment(addonName, handlerKey, ...)
        end
        handlers[eventName] = thunkName
    end

    return handlers
end

function GlobalBridge:DispatchAddonCompartment(addonName, handlerKey, ...)
    local handlers = self.addonCompartments[addonName]
    local handler = handlers and handlers[handlerKey]
    if handler then
        return handler(...)
    end
end

function GlobalBridge:RegisterSpecialFrame(frame)
    if frame then
        tinsert(UISpecialFrames, frame:GetName())
    end
end

Loolib:RegisterModule("Compat.GlobalBridge", GlobalBridge)
