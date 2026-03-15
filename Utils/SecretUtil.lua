--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Secret Value Utilities

    WoW 12.0 introduced "secret values" — opaque Lua values returned
    by unit APIs (UnitName, UnitClass, GetRaidRosterInfo,
    GetPlayerInfoByGUID) on tainted execution paths during combat.
    Operations like ==, string.find(), #, or table key usage on secret
    values will error. The global issecretvalue(value) detects them.

    This module provides:
    - Core detection (IsSecretValue, SecretsForPrint, Guard, GuardToString)
    - Safe unit API wrappers that return nil instead of secrets

    All functions are pre-12.0 compatible: they early-return raw API
    results when issecretvalue is nil.

    @author James Kueller
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local error = error
local select = select
local tostring = tostring
local type = type
local unpack = unpack

local issecretvalue = issecretvalue
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetRaidRosterInfo = GetRaidRosterInfo
local GetUnitName = GetUnitName
local UnitClass = UnitClass
local UnitName = UnitName

local SecretUtil = {}

--[[--------------------------------------------------------------------
    Core Detection
----------------------------------------------------------------------]]

--- Check whether the issecretvalue API is available
-- @return boolean
function SecretUtil.IsAvailable()
    return issecretvalue ~= nil
end

--- Check if any of the given values are WoW secret values
-- @param ... - Values to check
-- @return boolean - True if any value is secret
function SecretUtil.IsSecretValue(...)
    if not issecretvalue then return false end
    for i = 1, select("#", ...) do
        if issecretvalue(select(i, ...)) then return true end
    end
    return false
end

--- Replace secret values with "<secret>" for safe printing
-- Non-secret values are tostring()'d. Passthrough when issecretvalue is nil.
-- @param ... - Values to sanitize
-- @return ... - Sanitized values
function SecretUtil.SecretsForPrint(...)
    if not issecretvalue then return ... end
    local n = select("#", ...)
    if n == 0 then return end
    local ret = {}
    for i = 1, n do
        local v = select(i, ...)
        ret[i] = issecretvalue(v) and "<secret>" or tostring(v)
    end
    return unpack(ret, 1, n)
end

--- Return value if not secret, otherwise return fallback
-- @param value any - Value to guard
-- @param fallback any - Fallback if value is secret (default nil)
-- @return any
function SecretUtil.Guard(value, fallback)
    if not issecretvalue then return value end
    if issecretvalue(value) then return fallback end
    return value
end

--- Return tostring(value) if not secret, otherwise return placeholder
-- @param value any - Value to guard
-- @param placeholder string - Placeholder if secret (default "<secret>")
-- @return string
function SecretUtil.GuardToString(value, placeholder)
    if not issecretvalue then return tostring(value) end
    if issecretvalue(value) then return placeholder or "<secret>" end
    return tostring(value)
end

--[[--------------------------------------------------------------------
    Safe Unit API Wrappers
----------------------------------------------------------------------]]

--- Safe wrapper for UnitName / GetUnitName
-- Uses GetUnitName when showServerName is truthy, UnitName otherwise.
-- @param unit string - Unit ID
-- @param showServerName boolean|nil - If truthy, use GetUnitName(unit, true)
-- @return string|nil name
-- @return string|nil realm
function SecretUtil.SafeUnitName(unit, showServerName)
    if type(unit) ~= "string" then
        error("LoolibSecretUtil: SafeUnitName requires a string unit ID", 2)
    end

    local name, realm
    if showServerName then
        name = GetUnitName(unit, true)
        realm = nil -- GetUnitName with showServerName bakes realm into name
    else
        name, realm = UnitName(unit)
    end

    if not issecretvalue then return name, realm end
    if issecretvalue(name) then return nil, nil end
    if realm and issecretvalue(realm) then realm = nil end
    return name, realm
end

--- Safe wrapper for UnitClass
-- @param unit string - Unit ID
-- @return string|nil localizedClass
-- @return string|nil englishClass
-- @return number|nil classID
function SecretUtil.SafeUnitClass(unit)
    if type(unit) ~= "string" then
        error("LoolibSecretUtil: SafeUnitClass requires a string unit ID", 2)
    end

    ---@type string?, string?, number?
    local localizedClass, englishClass, classID = UnitClass(unit)

    if not issecretvalue then return localizedClass, englishClass, classID end
    if issecretvalue(localizedClass) then localizedClass = nil end
    if issecretvalue(englishClass) then englishClass = nil end
    if classID and issecretvalue(classID) then classID = nil end
    return localizedClass, englishClass, classID
end

--- Safe wrapper for GetRaidRosterInfo
-- If the name return is secret, the entire result returns bare nil
-- (not 12 nils). Callers that destructure into multiple locals will
-- receive nil for all positions — this matches existing consumer code.
-- @param index number - Raid roster index (1-based)
-- @return string|nil name, number|nil rank, number|nil subgroup,
--         number|nil level, string|nil class, string|nil fileName,
--         string|nil zone, boolean|nil online, boolean|nil isDead,
--         string|nil role, boolean|nil isML, string|nil combatRole
function SecretUtil.SafeGetRaidRosterInfo(index)
    if type(index) ~= "number" then
        error("LoolibSecretUtil: SafeGetRaidRosterInfo requires a number index", 2)
    end

    ---@type string?, number?, number?, number?, string?, string?, string?, boolean?, boolean?, string?, boolean?, string?
    local name, rank, subgroup, level, class, fileName, zone,
          online, isDead, role, isML, combatRole = GetRaidRosterInfo(index)

    if not issecretvalue then
        return name, rank, subgroup, level, class, fileName, zone,
               online, isDead, role, isML, combatRole
    end

    -- If name is secret, entire result is unreliable
    if not name or issecretvalue(name) then return nil end

    -- Guard individual string fields
    if issecretvalue(class) then class = nil end
    if issecretvalue(fileName) then fileName = nil end
    if issecretvalue(zone) then zone = nil end

    return name, rank, subgroup, level, class, fileName, zone,
           online, isDead, role, isML, combatRole
end

--- Safe wrapper for GetPlayerInfoByGUID
-- If the name return is secret, the entire result returns bare nil.
-- Does NOT strip null bytes — that is the consumer's concern.
-- @param guid string - Player GUID
-- @return string|nil localizedClass, string|nil englishClass,
--         string|nil localizedRace, string|nil englishRace,
--         number|nil sex, string|nil name, string|nil realmName
function SecretUtil.SafeGetPlayerInfoByGUID(guid)
    if type(guid) ~= "string" then
        error("LoolibSecretUtil: SafeGetPlayerInfoByGUID requires a string GUID", 2)
    end
    if not GetPlayerInfoByGUID then return nil end

    ---@type string?, string?, string?, string?, number?, string?, string?
    local localizedClass, englishClass, localizedRace, englishRace,
          sex, name, realmName = GetPlayerInfoByGUID(guid)

    if not issecretvalue then
        return localizedClass, englishClass, localizedRace, englishRace,
               sex, name, realmName
    end

    -- If name is secret, entire result is unreliable
    if not name or issecretvalue(name) then return nil end

    if issecretvalue(localizedClass) then localizedClass = nil end
    if issecretvalue(englishClass) then englishClass = nil end
    if issecretvalue(localizedRace) then localizedRace = nil end
    if issecretvalue(englishRace) then englishRace = nil end
    ---@diagnostic disable-next-line: cast-local-type
    if realmName and issecretvalue(realmName) then realmName = nil end

    return localizedClass, englishClass, localizedRace, englishRace,
           sex, name, realmName
end

--[[--------------------------------------------------------------------
    Module Registration
----------------------------------------------------------------------]]

Loolib.Utils = Loolib.Utils or {}
Loolib.Utils.SecretUtil = SecretUtil
Loolib.SecretUtil = SecretUtil

Loolib:RegisterModule("Utils.SecretUtil", SecretUtil)
