--[[--------------------------------------------------------------------
    Loolib - WoW API compatibility helpers
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

Loolib.Compat = Loolib.Compat or {}

Loolib.Compat.GetGuildRosterInfo = C_GuildInfo.GetGuildRosterInfo
Loolib.Compat.GuildRoster = C_GuildInfo.GuildRoster
Loolib.Compat.GetAddOnMetadata = C_AddOns.GetAddOnMetadata

function Loolib.Compat.RegisterSlashCommand(id, slash1, slash2, func)
    local bridge = Loolib.Compat.GlobalBridge
    if bridge then
        local commands = {
            {
                id = id,
                commands = { slash1, slash2 },
                handler = func,
            },
        }
        return bridge:RegisterSlashCommands(id, commands)
    end

    _G["SLASH_" .. id .. "1"] = slash1
    if slash2 then
        _G["SLASH_" .. id .. "2"] = slash2
    end
    SlashCmdList[id] = func
end

function Loolib.Compat.RegisterStaticPopup(name, definition)
    local bridge = Loolib.Compat.GlobalBridge
    if bridge then
        return bridge:RegisterStaticPopup("Compat", name, definition)
    end

    StaticPopupDialogs[name] = definition
end

Loolib:RegisterModule("Core.Compat", Loolib.Compat)
