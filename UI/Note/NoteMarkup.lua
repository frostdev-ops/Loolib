--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    UI/Note/NoteMarkup.lua - Conditional tag handlers for note markup

    Evaluates conditional markup tags to determine which content should
    be shown based on player role, name, class, group, etc.
----------------------------------------------------------------------]]

-- Cache globals -- INTERNAL
local type = type
local error = error
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local table_insert = table.insert
local table_concat = table.concat
local table_sort = table.sort
local string_lower = string.lower
local string_upper = string.upper
local string_match = string.match
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local string_find = string.find
local string_format = string.format

-- WoW globals -- INTERNAL
local GetTime = GetTime
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitRace = UnitRace
local strsplit = strsplit
local strtrim = strtrim

local Loolib = LibStub("Loolib")
local LoolibMixin = assert(Loolib.Mixin, "Loolib.Mixin is required for NoteMarkup")
local SecretUtil = Loolib.SecretUtil

--[[--------------------------------------------------------------------
    Pattern-escape helper (NT-05)

    Escapes Lua pattern-special characters in a string so it can be
    passed safely to gsub/find as a literal match.
----------------------------------------------------------------------]]

--- Escape pattern-special characters for safe literal matching -- INTERNAL
---@param s string
---@return string
local function PatternEscape(s)
    return (string_gsub(s, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

--- Strip WoW color codes from a string -- INTERNAL
---@param s string
---@return string
local function StripColorCodes(s)
    s = string_gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string_gsub(s, "|r", "")
    return s
end

--- Unescape WoW text escapes -- INTERNAL
--- Handles || -> | (literal pipe) (NT-09)
---@param s string
---@return string
local function UnescapeWoW(s)
    return (string_gsub(s, "||", "|"))
end

--[[--------------------------------------------------------------------
    LoolibNoteMarkupMixin

    Provides conditional tag evaluation for raid notes. Determines
    whether content should be displayed based on player context.
----------------------------------------------------------------------]]

---@class LoolibNoteMarkupMixin
local LoolibNoteMarkupMixin = {}

--- Initialise markup processor state. Idempotent.
function LoolibNoteMarkupMixin:OnLoad()
    self._customHandlers = {}
    self._context = {}
    self._roleCache = nil
    self._roleCacheTime = 0
end

--[[--------------------------------------------------------------------
    CONTEXT (runtime state for evaluating conditions)
----------------------------------------------------------------------]]

--- Set evaluation context
---@param context table {playerName, playerRole, playerClass, playerGroup, encounterPhase, etc.}
function LoolibNoteMarkupMixin:SetContext(context)
    if context ~= nil and type(context) ~= "table" then
        error("LoolibNoteMarkup: SetContext: 'context' must be a table or nil", 2)
    end
    self._context = context or {}
end

--- Get current evaluation context
---@return table context
function LoolibNoteMarkupMixin:GetContext()
    return self._context
end

--- Update context with current player info
function LoolibNoteMarkupMixin:UpdatePlayerContext()
    -- Player name (without server)
    local fullName = SecretUtil.SafeUnitName("player")
    if not fullName then return end
    local shortName = string_match(fullName, "^([^%-]+)") or fullName
    self._context.playerName = shortName
    self._context.playerFullName = fullName

    -- Get role with caching (role detection can be expensive)
    local now = GetTime()
    if not self._roleCache or (now - self._roleCacheTime) > 1 then
        local role = UnitGroupRolesAssigned("player")
        if role == "NONE" or not role then
            -- Fallback to spec role when not in group
            local specIndex = GetSpecialization()
            if specIndex then
                local _, _, _, _, roleFromSpec = GetSpecializationInfo(specIndex)
                role = roleFromSpec
            end
        end
        self._roleCache = role or "DAMAGER"
        self._roleCacheTime = now
    end
    self._context.playerRole = self._roleCache

    -- Get class token and class ID in one call
    local _, classToken, classID = SecretUtil.SafeUnitClass("player")
    self._context.playerClass = classToken
    self._context.playerClassID = classID

    -- Get group number
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup = SecretUtil.SafeGetRaidRosterInfo(i)
            if name then
                local shortRaidName = string_match(name, "^([^%-]+)") or name
                if shortRaidName == shortName then
                    self._context.playerGroup = subgroup
                    break
                end
            end
        end
    end
    self._context.playerGroup = self._context.playerGroup or 1

    -- Group status
    self._context.inRaid = IsInRaid()
    self._context.inGroup = IsInGroup()
end

--[[--------------------------------------------------------------------
    BUILT-IN CONDITION HANDLERS
----------------------------------------------------------------------]]

local BuiltInHandlers = {}

--- Role condition: HEALER, TANK, DAMAGER -- INTERNAL
-- Used by {H}, {T}, {D} tags
BuiltInHandlers.ROLE = function(node, context)
    local playerRole = context.playerRole
    if node.role == "HEALER" then
        return playerRole == "HEALER"
    elseif node.role == "TANK" then
        return playerRole == "TANK"
    elseif node.role == "DAMAGER" or node.role == "DPS" then
        return playerRole == "DAMAGER" or playerRole == "DPS"
    end
    return false
end

--- Player name condition: P:name, !P:name -- INTERNAL
-- Supports comma-separated lists: {P:Alice,Bob,Charlie}
BuiltInHandlers.PLAYER = function(node, context)
    local playerName = context.playerName

    -- Support comma-separated list
    local names = {strsplit(",", node.player)}
    local matches = false

    for _, name in ipairs(names) do
        name = strtrim(name)
        -- Remove color codes if present (NT-09)
        name = StripColorCodes(name)
        -- Unescape WoW pipe literals (NT-09)
        name = UnescapeWoW(name)

        -- Case-insensitive comparison, handle server names
        local baseName = string_match(name, "^([^%-]+)") or name
        if string_lower(baseName) == string_lower(playerName) then
            matches = true
            break
        end
    end

    if node.negate then
        return not matches
    end
    return matches
end

--- Class condition: C:CLASSNAME -- INTERNAL
-- Supports class names, abbreviations, and IDs
BuiltInHandlers.CLASS = function(node, context)
    local playerClass = context.playerClass
    local playerClassID = context.playerClassID

    -- Support comma-separated list
    local classes = {strsplit(",", node.class)}
    local matches = false

    for _, class in ipairs(classes) do
        class = strtrim(class)
        -- Remove color codes (NT-09)
        class = StripColorCodes(class)
        class = string_upper(class)

        -- Check by class token
        if class == playerClass then
            matches = true
            break
        end

        -- Check by class ID
        local classIDNum = tonumber(class)
        if classIDNum and classIDNum == playerClassID then
            matches = true
            break
        end

        -- Check by abbreviation
        local abbrevMap = {
            WAR = "WARRIOR",
            PAL = "PALADIN",
            HUN = "HUNTER",
            ROG = "ROGUE",
            PRI = "PRIEST",
            DK = "DEATHKNIGHT",
            SHAM = "SHAMAN",
            MAG = "MAGE",
            LOCK = "WARLOCK",
            DRU = "DRUID",
            DH = "DEMONHUNTER",
            DRAGON = "EVOKER",
        }
        local fullClass = abbrevMap[class] or class
        if fullClass == playerClass then
            matches = true
            break
        end
    end

    if node.negate then
        return not matches
    end
    return matches
end

--- Group condition: G1-G8 -- INTERNAL
-- Used by {G1}, {G2}, etc.
BuiltInHandlers.GROUP = function(node, context)
    local playerGroup = context.playerGroup

    -- Support group ranges like "123" meaning groups 1, 2, or 3
    local groupStr = tostring(node.group)
    for i = 1, #groupStr do
        local digit = tonumber(string.sub(groupStr, i, i))
        if digit and digit == playerGroup then
            if node.negate then
                return false
            end
            return true
        end
    end

    if node.negate then
        return true
    end
    return false
end

--- Everyone condition (always true) -- INTERNAL
-- Used by {everyone}
BuiltInHandlers.EVERYONE = function(_node, _context)
    return true
end

--- Race condition: RACE:racename -- INTERNAL
-- Supports comma-separated lists
BuiltInHandlers.RACE = function(node, context)
    local playerRace = context.playerRace
    if not playerRace then
        local _, raceToken = UnitRace("player")
        playerRace = raceToken
        context.playerRace = playerRace
    end

    -- Support comma-separated list
    local races = {strsplit(",", node.race)}
    local matches = false

    for _, race in ipairs(races) do
        race = strtrim(race)
        race = StripColorCodes(race)

        if string_upper(race) == string_upper(playerRace) then
            matches = true
            break
        end
    end

    if node.negate then
        return not matches
    end
    return matches
end

--- Phase condition: P:phase -- INTERNAL
-- Requires phase tracking in context
BuiltInHandlers.PHASE = function(node, context)
    local currentPhase = context.encounterPhase or context.phase
    if not currentPhase then
        -- No phase tracking, show by default
        return not node.negate
    end

    local matches = tostring(currentPhase) == tostring(node.phase)

    if node.negate then
        return not matches
    end
    return matches
end

--[[--------------------------------------------------------------------
    CONDITION EVALUATION
----------------------------------------------------------------------]]

--- Evaluate a condition node
---@param node table AST conditional node
---@param context table? Override context
---@return boolean shouldShow Whether content should be shown
function LoolibNoteMarkupMixin:EvaluateCondition(node, context)
    if type(node) ~= "table" then
        error("LoolibNoteMarkup: EvaluateCondition: 'node' must be a table", 2)
    end
    context = context or self._context

    -- Ensure we have current player context
    if not context.playerName then
        self:UpdatePlayerContext()
        context = self._context
    end

    -- Check for custom handler first
    if self._customHandlers[node.condition] then
        return self._customHandlers[node.condition](node, context)
    end

    -- Use built-in handler
    local handler = BuiltInHandlers[node.condition]
    if handler then
        return handler(node, context)
    end

    -- Unknown condition, default to showing
    return true
end

--- Register custom condition handler
---@param conditionType string Condition type name
---@param handler function Function(node, context) -> boolean
function LoolibNoteMarkupMixin:RegisterHandler(conditionType, handler)
    if type(conditionType) ~= "string" then
        error("LoolibNoteMarkup: RegisterHandler: 'conditionType' must be a string", 2)
    end
    if type(handler) ~= "function" then
        error("LoolibNoteMarkup: RegisterHandler: 'handler' must be a function", 2)
    end
    self._customHandlers[conditionType] = handler
end

--- Unregister custom handler
---@param conditionType string
function LoolibNoteMarkupMixin:UnregisterHandler(conditionType)
    if type(conditionType) ~= "string" then
        error("LoolibNoteMarkup: UnregisterHandler: 'conditionType' must be a string", 2)
    end
    self._customHandlers[conditionType] = nil
end

--- Get all registered handlers (built-in + custom)
---@return table handlers Map of condition type -> handler function
function LoolibNoteMarkupMixin:GetHandlers()
    local handlers = {}

    -- Copy built-in handlers
    for k, v in pairs(BuiltInHandlers) do
        handlers[k] = v
    end

    -- Copy custom handlers (override built-in if same name)
    for k, v in pairs(self._customHandlers) do
        handlers[k] = v
    end

    return handlers
end

--[[--------------------------------------------------------------------
    AST PROCESSING

    Note: These methods expect an AST from NoteParser. If NoteParser
    doesn't exist, these will error. Use the string-based methods below
    for simple text processing without AST.
----------------------------------------------------------------------]]

--- Process AST and return filtered node tree
---@param ast table Root AST node from NoteParser
---@param context table? Override context
---@return table filteredAst Filtered AST with hidden nodes removed
function LoolibNoteMarkupMixin:Process(ast, context)
    if type(ast) ~= "table" then
        error("LoolibNoteMarkup: Process: 'ast' must be a table", 2)
    end
    context = context or self._context

    -- Make sure we have current context
    if not context.playerName then
        self:UpdatePlayerContext()
        context = self._context
    end

    return self:_ProcessNode(ast, context)
end

--- Process a single node recursively -- INTERNAL
---@param node table AST node
---@param context table Context
---@return table? processed Processed node or nil if hidden
function LoolibNoteMarkupMixin:_ProcessNode(node, context)
    if not Loolib:HasModule("NoteParser") then
        error("LoolibNoteMarkup: Process: requires NoteParser module", 2)
    end

    local NodeTypes = Loolib:GetModule("NoteParser").NodeTypes

    if node.type == NodeTypes.ROOT then
        local newNode = {
            type = node.type,
            children = {},
        }
        for _, child in ipairs(node.children) do
            local processed = self:_ProcessNode(child, context)
            if processed then
                table_insert(newNode.children, processed)
            end
        end
        return newNode

    elseif node.type == NodeTypes.CONDITIONAL then
        -- Evaluate condition
        if not self:EvaluateCondition(node, context) then
            return nil  -- Hide this entire branch
        end

        -- Condition passed, process children
        local newNode = {
            type = NodeTypes.ROOT,  -- Flatten conditional to root
            children = {},
        }
        for _, child in ipairs(node.children) do
            local processed = self:_ProcessNode(child, context)
            if processed then
                table_insert(newNode.children, processed)
            end
        end
        return newNode

    else
        -- Non-conditional nodes pass through unchanged
        return node
    end
end

--- Flatten processed AST to simple node list
---@param ast table Processed AST
---@return table[] nodes Array of leaf nodes (TEXT, ICON, SPELL, TIMER, SELF)
function LoolibNoteMarkupMixin:Flatten(ast)
    if type(ast) ~= "table" then
        error("LoolibNoteMarkup: Flatten: 'ast' must be a table", 2)
    end
    local nodes = {}
    self:_FlattenNode(ast, nodes)
    return nodes
end

--- Flatten a single node recursively -- INTERNAL
function LoolibNoteMarkupMixin:_FlattenNode(node, nodes)
    if not Loolib:HasModule("NoteParser") then
        error("LoolibNoteMarkup: Flatten: requires NoteParser module", 2)
    end

    local NodeTypes = Loolib:GetModule("NoteParser").NodeTypes

    if node.type == NodeTypes.ROOT then
        for _, child in ipairs(node.children or {}) do
            self:_FlattenNode(child, nodes)
        end
    else
        table_insert(nodes, node)
    end
end

--[[--------------------------------------------------------------------
    STRING-BASED PROCESSING

    These methods work directly on markup strings without requiring
    NoteParser. They use pattern matching to handle basic conditionals.
----------------------------------------------------------------------]]

--- Process markup text directly with basic role/player/class filtering
--- This is a simplified version that doesn't require NoteParser
---@param text string Markup text
---@param context table? Override context
---@return string processed Processed text
function LoolibNoteMarkupMixin:ProcessText(text, context)
    if type(text) ~= "string" then
        error("LoolibNoteMarkup: ProcessText: 'text' must be a string", 2)
    end
    context = context or self._context

    -- Make sure we have current context
    if not context.playerName then
        self:UpdatePlayerContext()
        context = self._context
    end

    local result = text

    -- Process role tags {H}...{/H}, {T}...{/T}, {D}...{/D}
    local role = context.playerRole
    if role ~= "HEALER" then
        result = string_gsub(result, "{[Hh]}.-{/[Hh]}", "")
    end
    if role ~= "TANK" then
        result = string_gsub(result, "{[Tt]}.-{/[Tt]}", "")
    end
    if role ~= "DAMAGER" and role ~= "DPS" then
        result = string_gsub(result, "{[Dd]}.-{/[Dd]}", "")
    end

    -- Process player tags {P:name}...{/P}, {!P:name}...{/P}
    result = string_gsub(result, "{(!?)P:([^}]+)}(.-){/P}", function(negateStr, names, content)
        local node = {
            condition = "PLAYER",
            player = names,
            negate = negateStr == "!",
        }
        if self:EvaluateCondition(node, context) then
            return content
        else
            return ""
        end
    end)

    -- Process class tags {C:class}...{/C}, {!C:class}...{/C}
    result = string_gsub(result, "{(!?)C:([^}]+)}(.-){/C}", function(negateStr, classes, content)
        local node = {
            condition = "CLASS",
            class = classes,
            negate = negateStr == "!",
        }
        if self:EvaluateCondition(node, context) then
            return content
        else
            return ""
        end
    end)

    -- Process group tags {G1}...{/G}, {!G123}...{/G}
    result = string_gsub(result, "{(!?)G(%d+)}(.-){/G}", function(negateStr, group, content)
        local node = {
            condition = "GROUP",
            group = tonumber(group),
            negate = negateStr == "!",
        }
        if self:EvaluateCondition(node, context) then
            return content
        else
            return ""
        end
    end)

    -- Process race tags {RACE:name}...{/RACE}, {!RACE:name}...{/RACE}
    result = string_gsub(result, "{(!?)RACE:([^}]+)}(.-){/RACE}", function(negateStr, race, content)
        local node = {
            condition = "RACE",
            race = race,
            negate = negateStr == "!",
        }
        if self:EvaluateCondition(node, context) then
            return content
        else
            return ""
        end
    end)

    -- Process phase tags {P:phase}...{/P}, {!P:phase}...{/P}
    -- Note: This conflicts with player tags, so use different pattern
    result = string_gsub(result, "{(!?)P(%d+)}(.-){/P}", function(negateStr, phase, content)
        local node = {
            condition = "PHASE",
            phase = tonumber(phase),
            negate = negateStr == "!",
        }
        if self:EvaluateCondition(node, context) then
            return content
        else
            return ""
        end
    end)

    -- NT-09: Unescape WoW pipe literals after processing
    result = UnescapeWoW(result)

    return result
end

--[[--------------------------------------------------------------------
    CONVENIENCE METHODS
----------------------------------------------------------------------]]

--- Check if text would produce any visible output for current player
---@param text string Raw markup text
---@return boolean
function LoolibNoteMarkupMixin:HasVisibleContent(text)
    if type(text) ~= "string" then
        error("LoolibNoteMarkup: HasVisibleContent: 'text' must be a string", 2)
    end
    local processed = self:ProcessText(text)

    -- Remove all remaining markup tags
    processed = string_gsub(processed, "{[^}]+}", "")

    -- Check if any non-whitespace content remains
    return string_match(processed, "%S") ~= nil
end

--- Get list of player names mentioned in markup
---@param text string Raw markup text
---@return string[] names Array of player names
function LoolibNoteMarkupMixin:ExtractPlayerNames(text)
    if type(text) ~= "string" then
        error("LoolibNoteMarkup: ExtractPlayerNames: 'text' must be a string", 2)
    end
    local names = {}
    local seen = {}

    -- Match {P:name} and {!P:name} patterns
    for _negate, nameList in string_gmatch(text, "{(!?)P:([^}]+)}") do
        -- Handle comma-separated names
        for name in string_gmatch(nameList, "[^,]+") do
            name = strtrim(name)
            -- Remove color codes (NT-09)
            name = StripColorCodes(name)

            local lowerName = string_lower(name)
            if not seen[lowerName] then
                seen[lowerName] = true
                table_insert(names, name)
            end
        end
    end

    return names
end

--- Get list of classes mentioned in markup
---@param text string Raw markup text
---@return string[] classes Array of class tokens
function LoolibNoteMarkupMixin:ExtractClasses(text)
    if type(text) ~= "string" then
        error("LoolibNoteMarkup: ExtractClasses: 'text' must be a string", 2)
    end
    local classes = {}
    local seen = {}

    -- Match {C:class} and {!C:class} patterns
    for _negate, classList in string_gmatch(text, "{(!?)C:([^}]+)}") do
        -- Handle comma-separated classes
        for class in string_gmatch(classList, "[^,]+") do
            class = strtrim(class)
            -- Remove color codes (NT-09)
            class = StripColorCodes(class)
            class = string_upper(class)

            if not seen[class] then
                seen[class] = true
                table_insert(classes, class)
            end
        end
    end

    return classes
end

--- Get list of roles mentioned in markup
---@param text string Raw markup text
---@return string[] roles Array of role tokens ("HEALER", "TANK", "DAMAGER")
function LoolibNoteMarkupMixin:ExtractRoles(text)
    if type(text) ~= "string" then
        error("LoolibNoteMarkup: ExtractRoles: 'text' must be a string", 2)
    end
    local roles = {}

    if string_match(text, "{[Hh]}") then
        table_insert(roles, "HEALER")
    end
    if string_match(text, "{[Tt]}") then
        table_insert(roles, "TANK")
    end
    if string_match(text, "{[Dd]}") then
        table_insert(roles, "DAMAGER")
    end

    return roles
end

--- Get list of groups mentioned in markup
---@param text string Raw markup text
---@return number[] groups Array of group numbers
function LoolibNoteMarkupMixin:ExtractGroups(text)
    if type(text) ~= "string" then
        error("LoolibNoteMarkup: ExtractGroups: 'text' must be a string", 2)
    end
    local groups = {}
    local seen = {}

    -- Match {G1}, {!G123}, etc.
    for _negate, groupStr in string_gmatch(text, "{(!?)G(%d+)}") do
        -- Each digit is a separate group
        for i = 1, #groupStr do
            local group = tonumber(string.sub(groupStr, i, i))
            if group and not seen[group] then
                seen[group] = true
                table_insert(groups, group)
            end
        end
    end

    table_sort(groups)
    return groups
end

--[[--------------------------------------------------------------------
    FACTORY AND REGISTRATION
----------------------------------------------------------------------]]

--- Create a new markup processor instance
---@return table processor Processor instance
local function LoolibCreateNoteMarkup()
    local processor = {}
    LoolibMixin(processor, LoolibNoteMarkupMixin)
    processor:OnLoad()
    return processor
end

-- Singleton processor for convenience
local defaultProcessor = nil

--- Get default processor instance
---@return table processor Singleton processor
local function LoolibGetNoteMarkup()
    if not defaultProcessor then
        defaultProcessor = LoolibCreateNoteMarkup()
    end
    return defaultProcessor
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib:RegisterModule("Note.NoteMarkup", {
    Mixin = LoolibNoteMarkupMixin,
    Create = LoolibCreateNoteMarkup,
    Get = LoolibGetNoteMarkup,
    BuiltInHandlers = BuiltInHandlers,
})
