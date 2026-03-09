--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    UI/Note/NoteRenderer.lua - Text and Icon Rendering

    Renders processed AST nodes to formatted WoW text strings with
    embedded icons, colors, and spell textures.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local LoolibMixin = assert(Loolib.Mixin, "Loolib.Mixin is required for NoteRenderer")

--[[--------------------------------------------------------------------
    ICON TEXTURES
----------------------------------------------------------------------]]

-- Raid target icons (Star, Circle, Diamond, Triangle, Moon, Square, X, Skull)
local RAID_TARGET_ICONS = {
    [1] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t",  -- Star
    [2] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t",  -- Circle
    [3] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t",  -- Diamond
    [4] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t",  -- Triangle
    [5] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t",  -- Moon
    [6] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t",  -- Square
    [7] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t",  -- X/Cross
    [8] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t",  -- Skull
}

-- Role icons (Tank, Healer, DPS) with proper texture coordinates
local ROLE_ICONS = {
    TANK = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:0:19:22:41|t",
    HEALER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:1:20|t",
    DPS = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:22:41|t",
}

-- Class colors (hex format without |c prefix)
-- Uses Blizzard RAID_CLASS_COLORS as authoritative source
local CLASS_COLORS = {}

-- Initialize class colors from Blizzard's system
local function InitializeClassColors()
    for classToken, colorData in pairs(RAID_CLASS_COLORS) do
        if colorData.colorStr then
            -- Remove 'ff' alpha prefix if present
            CLASS_COLORS[classToken] = colorData.colorStr:match("^[fF][fF](.+)") or colorData.colorStr
        end
    end
end

-- Call on load
InitializeClassColors()

--[[--------------------------------------------------------------------
    AST Node Types

    Expected node structure from NoteParser/NoteMarkup:
----------------------------------------------------------------------]]

local NodeTypes = {
    ROOT = "ROOT",           -- Container node with children
    TEXT = "TEXT",           -- Plain text: { type="TEXT", text="..." }
    ICON = "ICON",           -- Icon: { type="ICON", iconType="RAID_TARGET|ROLE|CUSTOM", index=N, role="...", path="..." }
    SPELL = "SPELL",         -- Spell icon: { type="SPELL", spellId=N, size=N? }
    TIMER = "TIMER",         -- Timer: { type="TIMER", minutes=N?, seconds=N, ... }
    SELF = "SELF",           -- {self} placeholder
}

--[[--------------------------------------------------------------------
    LoolibNoteRendererMixin
----------------------------------------------------------------------]]

local LoolibNoteRendererMixin = {}

function LoolibNoteRendererMixin:OnLoad()
    self._selfText = ""
    self._autoColorNames = true
    self._defaultIconSize = 0  -- 0 means use font height
    self._timerRenderer = nil
    self._raidRoster = {}
    self._rosterUpdateTime = 0
end

--[[--------------------------------------------------------------------
    CONFIGURATION
----------------------------------------------------------------------]]

--- Set self-text (replacement for {self} placeholder)
-- @param text string - The text to use for {self} placeholders
function LoolibNoteRendererMixin:SetSelfText(text)
    self._selfText = text or ""
end

--- Enable/disable automatic class coloring of player names
-- @param enabled boolean - True to enable auto-coloring
function LoolibNoteRendererMixin:SetAutoColorNames(enabled)
    self._autoColorNames = enabled
end

--- Set default icon size (0 = font height)
-- @param size number - Icon size in pixels (0 = match font height)
function LoolibNoteRendererMixin:SetDefaultIconSize(size)
    self._defaultIconSize = size or 0
end

--- Set timer renderer for {time:...} tags
-- @param timerRenderer table - NoteTimer instance
function LoolibNoteRendererMixin:SetTimerRenderer(timerRenderer)
    self._timerRenderer = timerRenderer
end

--- Update raid roster for name coloring
-- Caches roster data for 5 seconds to avoid excessive API calls
function LoolibNoteRendererMixin:UpdateRaidRoster()
    local now = GetTime()

    -- Only update every 5 seconds
    if now - self._rosterUpdateTime < 5 then
        return
    end

    self._rosterUpdateTime = now
    self._raidRoster = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, classToken = GetRaidRosterInfo(i)
            if name then
                -- Store by base name (without server)
                local baseName = name:match("^([^-]+)")
                if baseName then
                    self._raidRoster[baseName:lower()] = classToken
                end
                self._raidRoster[name:lower()] = classToken
            end
        end
    elseif IsInGroup() then
        -- Party members
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            local name = UnitName(unit)
            local _, classToken = UnitClass(unit)
            if name and classToken then
                self._raidRoster[name:lower()] = classToken
            end
        end
        -- Add player
        local playerName = UnitName("player")
        local _, playerClass = UnitClass("player")
        if playerName and playerClass then
            self._raidRoster[playerName:lower()] = playerClass
        end
    else
        -- Solo - just add player
        local playerName = UnitName("player")
        local _, playerClass = UnitClass("player")
        if playerName and playerClass then
            self._raidRoster[playerName:lower()] = playerClass
        end
    end
end

--[[--------------------------------------------------------------------
    RENDERING
----------------------------------------------------------------------]]

--- Render processed AST to formatted string
-- @param ast table - Processed AST from NoteMarkup
-- @return string - Formatted text with WoW escape sequences
function LoolibNoteRendererMixin:Render(ast)
    if not ast then
        return ""
    end

    -- If we have a NoteMarkup module with Flatten, use it
    local noteMarkup = Loolib:GetModule("NoteMarkup")
    local nodes

    if noteMarkup and noteMarkup.Get then
        local markup = noteMarkup.Get()
        if markup and markup.Flatten then
            nodes = markup:Flatten(ast)
        end
    end

    -- If no Flatten available, treat ast as a single node or array
    if not nodes then
        if ast.type then
            nodes = {ast}
        elseif type(ast) == "table" and #ast > 0 then
            nodes = ast
        else
            return ""
        end
    end

    local parts = {}

    for _, node in ipairs(nodes) do
        local rendered = self:RenderNode(node)
        if rendered then
            table.insert(parts, rendered)
        end
    end

    local result = table.concat(parts)

    -- Auto-color player names if enabled
    if self._autoColorNames then
        result = self:ColorPlayerNames(result)
    end

    return result
end

--- Render a single node
-- @param node table - AST node
-- @return string? - Rendered text or nil
function LoolibNoteRendererMixin:RenderNode(node)
    if not node or not node.type then
        return nil
    end

    if node.type == NodeTypes.TEXT then
        return node.text or ""

    elseif node.type == NodeTypes.ICON then
        return self:RenderIcon(node)

    elseif node.type == NodeTypes.SPELL then
        return self:RenderSpell(node.spellId, node.size)

    elseif node.type == NodeTypes.TIMER then
        return self:RenderTimer(node)

    elseif node.type == NodeTypes.SELF then
        return self._selfText

    elseif node.type == NodeTypes.ROOT then
        -- Recursively render children
        local parts = {}
        for _, child in ipairs(node.children or {}) do
            local rendered = self:RenderNode(child)
            if rendered then
                table.insert(parts, rendered)
            end
        end
        return table.concat(parts)
    end

    return nil
end

--- Render an icon node
-- @param node table - Icon node with iconType, index, role, or path
-- @return string - Icon texture string
function LoolibNoteRendererMixin:RenderIcon(node)
    if node.iconType == "RAID_TARGET" then
        return RAID_TARGET_ICONS[node.index] or ""

    elseif node.iconType == "ROLE" then
        return ROLE_ICONS[node.role] or ""

    elseif node.iconType == "CUSTOM" then
        local size = node.size or self._defaultIconSize
        if size == 0 then
            return "|T" .. node.path .. ":0|t"
        else
            return "|T" .. node.path .. ":" .. size .. "|t"
        end
    end

    return ""
end

--- Render a spell icon
-- @param spellId number - Spell ID
-- @param size number? - Optional size (0 = font height)
-- @return string - Spell icon texture string
function LoolibNoteRendererMixin:RenderSpell(spellId, size)
    if not spellId then
        return ""
    end

    local spellInfo = C_Spell.GetSpellInfo(spellId)
    if not spellInfo then
        return "{spell:" .. spellId .. "}"
    end

    local icon = spellInfo.iconID
    if not icon then
        return "{spell:" .. spellId .. "}"
    end

    size = size or self._defaultIconSize

    if size == 0 then
        return "|T" .. icon .. ":0|t"
    else
        return "|T" .. icon .. ":" .. size .. "|t"
    end
end

--- Render a timer node
-- @param node table - Timer node with minutes/seconds
-- @return string - Formatted time string
function LoolibNoteRendererMixin:RenderTimer(node)
    if self._timerRenderer then
        return self._timerRenderer:RenderTimer(node)
    end

    -- Fallback: static time display
    local totalSeconds = (node.minutes or 0) * 60 + (node.seconds or 0)
    if node.minutes and node.minutes > 0 then
        return string.format("%d:%02d", node.minutes, node.seconds or 0)
    else
        return tostring(node.seconds or 0)
    end
end

--[[--------------------------------------------------------------------
    CLASS COLORING
----------------------------------------------------------------------]]

--- Apply class colors to player names in text
-- @param text string - Input text
-- @return string - Text with colored names
function LoolibNoteRendererMixin:ColorPlayerNames(text)
    if not text or #text == 0 then
        return text
    end

    -- Update roster if needed
    self:UpdateRaidRoster()

    if not next(self._raidRoster) then
        return text
    end

    -- Find and color known player names
    -- Sort names by length (longest first) to handle partial matches correctly
    local names = {}
    for name in pairs(self._raidRoster) do
        table.insert(names, name)
    end
    table.sort(names, function(a, b) return #a > #b end)

    for _, name in ipairs(names) do
        local classToken = self._raidRoster[name]
        local color = CLASS_COLORS[classToken]
        if color then
            -- Case-insensitive pattern matching
            -- Use word boundaries to avoid partial matches
            local pattern = "([%s%p]?)(" .. name:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. ")([%s%p]?)"
            text = text:gsub(pattern, function(pre, match, post)
                -- Check if already colored
                if pre:match("|c") or post:match("|r") then
                    return pre .. match .. post
                end
                -- Preserve original case of matched name
                return pre .. "|cFF" .. color .. match .. "|r" .. post
            end)
        end
    end

    return text
end

--- Get class color hex for a class token
-- @param classToken string - Class token (e.g., "WARRIOR")
-- @return string? - Hex color without |c prefix
function LoolibNoteRendererMixin:GetClassColor(classToken)
    return CLASS_COLORS[classToken]
end

--- Color a single name by class
-- @param name string - Player name
-- @param classToken string? - Class token (auto-detect if nil)
-- @return string - Colored name
function LoolibNoteRendererMixin:ColorName(name, classToken)
    if not name then
        return ""
    end

    if not classToken then
        classToken = self._raidRoster[name:lower()]
    end

    if classToken and CLASS_COLORS[classToken] then
        return "|cFF" .. CLASS_COLORS[classToken] .. name .. "|r"
    end

    return name
end

--[[--------------------------------------------------------------------
    UTILITY METHODS
----------------------------------------------------------------------]]

--- Get raid target icon string
-- @param index number - 1-8 (Star through Skull)
-- @return string - Icon texture string
function LoolibNoteRendererMixin:GetRaidTargetIcon(index)
    return RAID_TARGET_ICONS[index] or ""
end

--- Get role icon string
-- @param role string - "TANK", "HEALER", or "DPS"
-- @return string - Icon texture string
function LoolibNoteRendererMixin:GetRoleIcon(role)
    return ROLE_ICONS[role:upper()] or ""
end

--- Create inline icon string from texture path
-- @param path string - Texture path
-- @param size number? - Icon size (0 = font height)
-- @return string - Icon texture string
function LoolibNoteRendererMixin:CreateIcon(path, size)
    if not path then
        return ""
    end

    size = size or 0
    if size == 0 then
        return "|T" .. path .. ":0|t"
    else
        return "|T" .. path .. ":" .. size .. "|t"
    end
end

--- Create colored text
-- @param text string - Text to color
-- @param r number - Red (0-1) or hex string
-- @param g number? - Green (0-1)
-- @param b number? - Blue (0-1)
-- @return string - Colored text with escape codes
function LoolibNoteRendererMixin:ColorText(text, r, g, b)
    if not text then
        return ""
    end

    local hex
    if type(r) == "string" then
        -- Already a hex string
        hex = r
        -- Remove any existing color prefixes
        hex = hex:gsub("^|c[fF][fF]", ""):gsub("^[fF][fF]", "")
    else
        -- Convert RGB to hex
        hex = string.format("%02X%02X%02X",
            math.floor((r or 1) * 255),
            math.floor((g or r or 1) * 255),
            math.floor((b or r or 1) * 255))
    end
    return "|cFF" .. hex .. text .. "|r"
end

--- Strip all color codes from text
-- @param text string - Input text
-- @return string - Text without color codes
function LoolibNoteRendererMixin:StripColors(text)
    if not text then
        return ""
    end
    return text:gsub("|c[fF][fF]%x%x%x%x%x%x", ""):gsub("|r", "")
end

--- Strip all texture codes from text
-- @param text string - Input text
-- @return string - Text without textures
function LoolibNoteRendererMixin:StripTextures(text)
    if not text then
        return ""
    end
    return text:gsub("|T.-|t", "")
end

--- Strip all formatting (colors and textures)
-- @param text string - Input text
-- @return string - Plain text
function LoolibNoteRendererMixin:StripFormatting(text)
    if not text then
        return ""
    end
    text = self:StripColors(text)
    text = self:StripTextures(text)
    return text
end

--[[--------------------------------------------------------------------
    FACTORY AND REGISTRATION
----------------------------------------------------------------------]]

--- Create a new renderer instance
-- @return table - Renderer instance
local function LoolibCreateNoteRenderer()
    local renderer = {}
    LoolibMixin(renderer, LoolibNoteRendererMixin)
    renderer:OnLoad()
    return renderer
end

-- Singleton renderer for convenience
local defaultRenderer = nil

--- Get default renderer instance
-- @return table - Default renderer singleton
local function LoolibGetNoteRenderer()
    if not defaultRenderer then
        defaultRenderer = LoolibCreateNoteRenderer()
    end
    return defaultRenderer
end

--[[--------------------------------------------------------------------
    Export Constants
----------------------------------------------------------------------]]

local LoolibNoteRaidTargetIcons = RAID_TARGET_ICONS
local LoolibNoteRoleIcons = ROLE_ICONS
local LoolibNoteClassColors = CLASS_COLORS
local LoolibNoteNodeTypes = NodeTypes

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib:RegisterModule("Note.NoteRenderer", {
    Mixin = LoolibNoteRendererMixin,
    Create = LoolibCreateNoteRenderer,
    Get = LoolibGetNoteRenderer,
    RaidTargetIcons = RAID_TARGET_ICONS,
    RoleIcons = ROLE_ICONS,
    ClassColors = CLASS_COLORS,
    NodeTypes = NodeTypes,
})
