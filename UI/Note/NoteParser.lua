--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    NoteParser - Tokenizer and AST builder for conditional note markup

    Parses MRT-style markup tags into an Abstract Syntax Tree that can
    be processed by NoteMarkup and rendered by NoteRenderer.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local LoolibMixin = assert(Loolib.Mixin, "Loolib.Mixin is required for NoteParser")

--[[--------------------------------------------------------------------
    TOKEN TYPES
----------------------------------------------------------------------]]

local TOKEN_TYPES = {
    TEXT = "TEXT",                -- Plain text
    TAG_OPEN = "TAG_OPEN",        -- {H}, {T}, {P:name}, etc.
    TAG_CLOSE = "TAG_CLOSE",      -- {/H}, {/T}, {/P}, etc.
    ICON = "ICON",                -- {rt1}, {star}, {tank}, etc.
    SPELL = "SPELL",              -- {spell:12345} or {spell:12345:16}
    TIME = "TIME",                -- {time:30} or {time:1:30}
    SELF = "SELF",                -- {self}
    CUSTOM_ICON = "CUSTOM_ICON",  -- {icon:path}
}

--[[--------------------------------------------------------------------
    AST NODE TYPES
----------------------------------------------------------------------]]

local NODE_TYPES = {
    ROOT = "ROOT",                -- Root document node
    TEXT = "TEXT",                -- Plain text
    CONDITIONAL = "CONDITIONAL",  -- {H}..{/H}, {P:name}..{/P}, etc.
    ICON = "ICON",                -- Inline icon
    SPELL = "SPELL",              -- Spell icon
    TIMER = "TIMER",              -- Countdown timer
    SELF = "SELF",                -- Self-text placeholder
}

--[[--------------------------------------------------------------------
    PARSER MIXIN
----------------------------------------------------------------------]]

---@class LoolibNoteParserMixin
local LoolibNoteParserMixin = {}

function LoolibNoteParserMixin:OnLoad()
    self._tokens = {}
    self._position = 0
    self._text = ""
end

--[[--------------------------------------------------------------------
    TOKENIZER
----------------------------------------------------------------------]]

--- Tokenize input text into token array
--- @param text string Raw note text
--- @return table[] Array of tokens
function LoolibNoteParserMixin:Tokenize(text)
    local tokens = {}
    local pos = 1
    local len = #text

    while pos <= len do
        -- Check for tag opening
        if text:sub(pos, pos) == "{" then
            local tagEnd = text:find("}", pos, true)
            if tagEnd then
                local tagContent = text:sub(pos + 1, tagEnd - 1)
                local token = self:_ParseTag(tagContent)
                if token then
                    table.insert(tokens, token)
                    pos = tagEnd + 1
                else
                    -- Not a valid tag, treat as text
                    table.insert(tokens, {
                        type = TOKEN_TYPES.TEXT,
                        value = "{",
                    })
                    pos = pos + 1
                end
            else
                -- No closing brace, treat as text
                table.insert(tokens, {
                    type = TOKEN_TYPES.TEXT,
                    value = text:sub(pos),
                })
                break
            end
        else
            -- Find next tag or end of string
            local nextTag = text:find("{", pos, true)
            local textEnd = nextTag and (nextTag - 1) or len
            local textContent = text:sub(pos, textEnd)

            if #textContent > 0 then
                table.insert(tokens, {
                    type = TOKEN_TYPES.TEXT,
                    value = textContent,
                })
            end

            pos = textEnd + 1
        end
    end

    return tokens
end

--- Parse a single tag (content between { and })
--- @param content string Tag content without braces
--- @return table? Token or nil if not valid
function LoolibNoteParserMixin:_ParseTag(content)
    -- Closing tags: /H, /T, /D, /P, /C, /G, /everyone
    if content:sub(1, 1) == "/" then
        local tagName = content:sub(2):upper()
        return {
            type = TOKEN_TYPES.TAG_CLOSE,
            tag = tagName,
        }
    end

    -- Role tags: H, T, D
    local upper = content:upper()
    if upper == "H" or upper == "T" or upper == "D" then
        return {
            type = TOKEN_TYPES.TAG_OPEN,
            tag = upper,
            condition = "ROLE",
            role = upper == "H" and "HEALER" or upper == "T" and "TANK" or "DAMAGER",
        }
    end

    -- Player tag: P:name or !P:name
    local negate, playerName = content:match("^(!?)P:(.+)$")
    if playerName then
        return {
            type = TOKEN_TYPES.TAG_OPEN,
            tag = "P",
            condition = "PLAYER",
            player = playerName,
            negate = negate == "!",
        }
    end

    -- Class tag: C:CLASSNAME or !C:CLASSNAME
    local negateC, className = content:match("^(!?)C:(.+)$")
    if className then
        return {
            type = TOKEN_TYPES.TAG_OPEN,
            tag = "C",
            condition = "CLASS",
            class = className:upper(),
            negate = negateC == "!",
        }
    end

    -- Group tag: G1-G8
    local groupNum = content:match("^G(%d)$")
    if groupNum then
        local num = tonumber(groupNum)
        if num >= 1 and num <= 8 then
            return {
                type = TOKEN_TYPES.TAG_OPEN,
                tag = "G",
                condition = "GROUP",
                group = num,
            }
        end
    end

    -- Everyone tag
    if upper == "EVERYONE" then
        return {
            type = TOKEN_TYPES.TAG_OPEN,
            tag = "EVERYONE",
            condition = "EVERYONE",
        }
    end

    -- Timer: time:30 or time:1:30 or time:30,options
    local timeStr = content:match("^time:(.+)$")
    if timeStr then
        local minutes, seconds, options

        -- Try to match min:sec format first
        local minMatch, secMatch = timeStr:match("^(%d+):(%d+)")
        if minMatch and secMatch then
            minutes = tonumber(minMatch)
            seconds = tonumber(secMatch)
            -- Extract options after the time
            options = timeStr:match("^%d+:%d+,(.+)$")
        else
            -- Just seconds
            seconds = timeStr:match("^(%d+)")
            if seconds then
                seconds = tonumber(seconds)
                -- Extract options after the time
                options = timeStr:match("^%d+,(.+)$")
            end
        end

        if seconds then
            return {
                type = TOKEN_TYPES.TIME,
                minutes = minutes or 0,
                seconds = seconds,
                options = options,
            }
        end
    end

    -- Spell icon: spell:12345 or spell:12345:16
    local spellId, spellSize = content:match("^spell:(%d+):?(%d*)$")
    if spellId then
        return {
            type = TOKEN_TYPES.SPELL,
            spellId = tonumber(spellId),
            size = tonumber(spellSize) or 0,
        }
    end

    -- Custom icon: icon:path
    local iconPath = content:match("^icon:(.+)$")
    if iconPath then
        return {
            type = TOKEN_TYPES.CUSTOM_ICON,
            path = iconPath,
        }
    end

    -- Raid target icons: rt1-rt8
    local rtNum = content:match("^rt(%d)$")
    if rtNum then
        local num = tonumber(rtNum)
        if num >= 1 and num <= 8 then
            return {
                type = TOKEN_TYPES.ICON,
                iconType = "RAID_TARGET",
                index = num,
            }
        end
    end

    -- Named raid icons
    local namedIcons = {
        star = 1, circle = 2, diamond = 3, triangle = 4,
        moon = 5, square = 6, cross = 7, x = 7, skull = 8,
    }
    local lowerContent = content:lower()
    if namedIcons[lowerContent] then
        return {
            type = TOKEN_TYPES.ICON,
            iconType = "RAID_TARGET",
            index = namedIcons[lowerContent],
        }
    end

    -- Role icons
    local roleIcons = {tank = "TANK", healer = "HEALER", dps = "DPS"}
    if roleIcons[lowerContent] then
        return {
            type = TOKEN_TYPES.ICON,
            iconType = "ROLE",
            role = roleIcons[lowerContent],
        }
    end

    -- Self placeholder
    if lowerContent == "self" then
        return {
            type = TOKEN_TYPES.SELF,
        }
    end

    -- Not a recognized tag
    return nil
end

--[[--------------------------------------------------------------------
    AST BUILDER
----------------------------------------------------------------------]]

--- Parse text into AST
--- @param text string Raw note text
--- @return table AST root node
function LoolibNoteParserMixin:Parse(text)
    local tokens = self:Tokenize(text)
    self._tokens = tokens
    self._position = 1

    local root = {
        type = NODE_TYPES.ROOT,
        children = {},
    }

    self:_ParseChildren(root, nil)

    return root
end

--- Parse children until closing tag or end
--- @param parent table Parent node
--- @param closingTag string? Expected closing tag or nil for root
function LoolibNoteParserMixin:_ParseChildren(parent, closingTag)
    while self._position <= #self._tokens do
        local token = self._tokens[self._position]

        -- Check for closing tag
        if token.type == TOKEN_TYPES.TAG_CLOSE then
            if closingTag and (token.tag == closingTag or
                (closingTag == "G" and token.tag == "G") or
                (closingTag == "P" and token.tag == "P") or
                (closingTag == "C" and token.tag == "C") or
                (closingTag == "EVERYONE" and token.tag == "EVERYONE")) then
                self._position = self._position + 1
                return
            else
                -- Unexpected closing tag, treat as text
                table.insert(parent.children, {
                    type = NODE_TYPES.TEXT,
                    text = "{/" .. token.tag .. "}",
                })
                self._position = self._position + 1
            end

        -- Opening tags create conditional nodes
        elseif token.type == TOKEN_TYPES.TAG_OPEN then
            local node = {
                type = NODE_TYPES.CONDITIONAL,
                condition = token.condition,
                tag = token.tag,
                children = {},
            }

            -- Copy condition-specific properties
            if token.role then node.role = token.role end
            if token.player then node.player = token.player end
            if token.negate then node.negate = token.negate end
            if token.class then node.class = token.class end
            if token.group then node.group = token.group end

            self._position = self._position + 1
            self:_ParseChildren(node, token.tag)
            table.insert(parent.children, node)

        -- Plain text
        elseif token.type == TOKEN_TYPES.TEXT then
            table.insert(parent.children, {
                type = NODE_TYPES.TEXT,
                text = token.value,
            })
            self._position = self._position + 1

        -- Timer
        elseif token.type == TOKEN_TYPES.TIME then
            table.insert(parent.children, {
                type = NODE_TYPES.TIMER,
                minutes = token.minutes,
                seconds = token.seconds,
                options = token.options,
            })
            self._position = self._position + 1

        -- Spell icon
        elseif token.type == TOKEN_TYPES.SPELL then
            table.insert(parent.children, {
                type = NODE_TYPES.SPELL,
                spellId = token.spellId,
                size = token.size,
            })
            self._position = self._position + 1

        -- Icons (raid target, role)
        elseif token.type == TOKEN_TYPES.ICON then
            table.insert(parent.children, {
                type = NODE_TYPES.ICON,
                iconType = token.iconType,
                index = token.index,
                role = token.role,
            })
            self._position = self._position + 1

        -- Custom icon
        elseif token.type == TOKEN_TYPES.CUSTOM_ICON then
            table.insert(parent.children, {
                type = NODE_TYPES.ICON,
                iconType = "CUSTOM",
                path = token.path,
            })
            self._position = self._position + 1

        -- Self placeholder
        elseif token.type == TOKEN_TYPES.SELF then
            table.insert(parent.children, {
                type = NODE_TYPES.SELF,
            })
            self._position = self._position + 1

        else
            -- Unknown token, skip
            self._position = self._position + 1
        end
    end
end

--[[--------------------------------------------------------------------
    UTILITY METHODS
----------------------------------------------------------------------]]

--- Serialize AST back to markup text (for debugging)
--- @param node table AST node
--- @return string
function LoolibNoteParserMixin:Serialize(node)
    if node.type == NODE_TYPES.ROOT then
        local parts = {}
        for _, child in ipairs(node.children) do
            table.insert(parts, self:Serialize(child))
        end
        return table.concat(parts)
    elseif node.type == NODE_TYPES.TEXT then
        return node.text
    elseif node.type == NODE_TYPES.CONDITIONAL then
        local openTag = "{" .. node.tag
        if node.player then
            openTag = "{" .. (node.negate and "!" or "") .. "P:" .. node.player
        elseif node.class then
            openTag = "{" .. (node.negate and "!" or "") .. "C:" .. node.class
        elseif node.group then
            openTag = "{G" .. node.group
        end
        openTag = openTag .. "}"

        local content = {}
        for _, child in ipairs(node.children) do
            table.insert(content, self:Serialize(child))
        end

        local closeTag = "{/" .. (node.tag == "G" and "G" or node.tag) .. "}"
        return openTag .. table.concat(content) .. closeTag
    elseif node.type == NODE_TYPES.TIMER then
        local timeStr = "{time:"
        if node.minutes > 0 then
            timeStr = timeStr .. node.minutes .. ":" .. node.seconds
        else
            timeStr = timeStr .. node.seconds
        end
        if node.options then
            timeStr = timeStr .. "," .. node.options
        end
        return timeStr .. "}"
    elseif node.type == NODE_TYPES.SPELL then
        if node.size > 0 then
            return "{spell:" .. node.spellId .. ":" .. node.size .. "}"
        else
            return "{spell:" .. node.spellId .. "}"
        end
    elseif node.type == NODE_TYPES.ICON then
        if node.iconType == "RAID_TARGET" then
            return "{rt" .. node.index .. "}"
        elseif node.iconType == "ROLE" then
            return "{" .. node.role:lower() .. "}"
        elseif node.iconType == "CUSTOM" then
            return "{icon:" .. node.path .. "}"
        end
    elseif node.type == NODE_TYPES.SELF then
        return "{self}"
    end
    return ""
end

--- Pretty-print AST for debugging
--- @param node table AST node
--- @param indent number? Indentation level (default 0)
--- @return string
function LoolibNoteParserMixin:DebugPrint(node, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    local lines = {}

    if node.type == NODE_TYPES.ROOT then
        table.insert(lines, prefix .. "ROOT")
        for _, child in ipairs(node.children) do
            table.insert(lines, self:DebugPrint(child, indent + 1))
        end
    elseif node.type == NODE_TYPES.TEXT then
        table.insert(lines, prefix .. "TEXT: " .. (node.text or ""))
    elseif node.type == NODE_TYPES.CONDITIONAL then
        local desc = prefix .. "CONDITIONAL: " .. node.condition
        if node.role then
            desc = desc .. " (role=" .. node.role .. ")"
        elseif node.player then
            desc = desc .. " (player=" .. node.player .. (node.negate and ", negated" or "") .. ")"
        elseif node.class then
            desc = desc .. " (class=" .. node.class .. (node.negate and ", negated" or "") .. ")"
        elseif node.group then
            desc = desc .. " (group=" .. node.group .. ")"
        end
        table.insert(lines, desc)
        for _, child in ipairs(node.children) do
            table.insert(lines, self:DebugPrint(child, indent + 1))
        end
    elseif node.type == NODE_TYPES.TIMER then
        local timeDesc = node.minutes > 0 and
            (node.minutes .. ":" .. node.seconds) or
            tostring(node.seconds)
        if node.options then
            timeDesc = timeDesc .. " (options=" .. node.options .. ")"
        end
        table.insert(lines, prefix .. "TIMER: " .. timeDesc)
    elseif node.type == NODE_TYPES.SPELL then
        local desc = prefix .. "SPELL: " .. node.spellId
        if node.size > 0 then
            desc = desc .. " (size=" .. node.size .. ")"
        end
        table.insert(lines, desc)
    elseif node.type == NODE_TYPES.ICON then
        local desc = prefix .. "ICON: " .. node.iconType
        if node.index then
            desc = desc .. " (index=" .. node.index .. ")"
        elseif node.role then
            desc = desc .. " (role=" .. node.role .. ")"
        elseif node.path then
            desc = desc .. " (path=" .. node.path .. ")"
        end
        table.insert(lines, desc)
    elseif node.type == NODE_TYPES.SELF then
        table.insert(lines, prefix .. "SELF")
    end

    return table.concat(lines, "\n")
end

--[[--------------------------------------------------------------------
    FACTORY AND REGISTRATION
----------------------------------------------------------------------]]

--- Create a new parser instance
--- @return table Parser
local function LoolibCreateNoteParser()
    local parser = {}
    LoolibMixin(parser, LoolibNoteParserMixin)
    parser:OnLoad()
    return parser
end

-- Singleton parser for convenience
local defaultParser = nil

--- Get default parser instance
--- @return table Parser
local function LoolibGetNoteParser()
    if not defaultParser then
        defaultParser = LoolibCreateNoteParser()
    end
    return defaultParser
end

--[[--------------------------------------------------------------------
    GLOBAL EXPORTS
----------------------------------------------------------------------]]

-- Export constants
local LoolibNoteTokenTypes = TOKEN_TYPES
local LoolibNoteNodeTypes = NODE_TYPES

-- Register with Loolib
Loolib:RegisterModule("Note.NoteParser", {
    Mixin = LoolibNoteParserMixin,
    Create = LoolibCreateNoteParser,
    Get = LoolibGetNoteParser,
    TokenTypes = TOKEN_TYPES,
    NodeTypes = NODE_TYPES,
})
