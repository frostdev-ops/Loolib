--[[--------------------------------------------------------------------
    Loolib - WoW API compatibility helpers
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

Loolib.Compat = Loolib.Compat or {}

Loolib.Compat.GetGuildRosterInfo = C_GuildInfo and C_GuildInfo.GetGuildRosterInfo or GetGuildRosterInfo
Loolib.Compat.GuildRoster = C_GuildInfo and C_GuildInfo.GuildRoster or GuildRoster
Loolib.Compat.GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

function Loolib.Compat.RegisterSlashCommand(id, slash1, slash2, func)
    _G["SLASH_" .. id .. "1"] = slash1
    if slash2 then
        _G["SLASH_" .. id .. "2"] = slash2
    end
    SlashCmdList[id] = func
end

function Loolib.Compat.RegisterStaticPopup(name, definition)
    StaticPopupDialogs[name] = definition
end

Loolib:RegisterModule("Core.Compat", Loolib.Compat)
