--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    UI/Note/NoteMarkup.lua - Conditional tag handlers for note markup

    Evaluates conditional markup tags to determine which content should
    be shown based on player role, name, class, group, etc.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local LoolibMixin = assert(Loolib.Mixin, "Loolib.Mixin is required for NoteMarkup")

--[[--------------------------------------------------------------------
    LoolibNoteMarkupMixin

    Provides conditional tag evaluation for raid notes. Determines
    whether content should be displayed based on player context.
----------------------------------------------------------------------]]

local LoolibNoteMarkupMixin = {}

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
-- @param context table {playerName, playerRole, playerClass, playerGroup, encounterPhase, etc.}
function LoolibNoteMarkupMixin:SetContext(context)
    self._context = context or {}
end

--- Get current evaluation context
-- @return table Context
function LoolibNoteMarkupMixin:GetContext()
    return self._context
end

--- Update context with current player info
function LoolibNoteMarkupMixin:UpdatePlayerContext()
    -- Player name (without server)
    local fullName = UnitName("player")
    local shortName = fullName:match("^([^%-]+)") or fullName
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

    -- Get class
    local _, classToken = UnitClass("player")
    self._context.playerClass = classToken

    -- Get class ID
    local classID = select(3, UnitClass("player"))
    self._context.playerClassID = classID

    -- Get group number
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name then
                local shortRaidName = name:match("^([^%-]+)") or name
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

--- Role condition: HEALER, TANK, DAMAGER
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

--- Player name condition: P:name, !P:name
-- Supports comma-separated lists: {P:Alice,Bob,Charlie}
BuiltInHandlers.PLAYER = function(node, context)
    local playerName = context.playerName

    -- Support comma-separated list
    local names = {strsplit(",", node.player)}
    local matches = false

    for _, name in ipairs(names) do
        name = strtrim(name)
        -- Remove color codes if present
        name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

        -- Case-insensitive comparison, handle server names
        local baseName = name:match("^([^%-]+)") or name
        if baseName:lower() == playerName:lower() then
            matches = true
            break
        end
    end

    if node.negate then
        return not matches
    end
    return matches
end

--- Class condition: C:CLASSNAME
-- Supports class names, abbreviations, and IDs
BuiltInHandlers.CLASS = function(node, context)
    local playerClass = context.playerClass
    local playerClassID = context.playerClassID

    -- Support comma-separated list
    local classes = {strsplit(",", node.class)}
    local matches = false

    for _, class in ipairs(classes) do
        class = strtrim(class)
        -- Remove color codes
        class = class:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        class = class:upper()

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

--- Group condition: G1-G8
-- Used by {G1}, {G2}, etc.
BuiltInHandlers.GROUP = function(node, context)
    local playerGroup = context.playerGroup

    -- Support group ranges like "123" meaning groups 1, 2, or 3
    local groupStr = tostring(node.group)
    for i = 1, #groupStr do
        local digit = tonumber(groupStr:sub(i, i))
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

--- Everyone condition (always true)
-- Used by {everyone}
BuiltInHandlers.EVERYONE = function(node, context)
    return true
end

--- Race condition: RACE:racename
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
        race = race:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

        if race:upper() == playerRace:upper() then
            matches = true
            break
        end
    end

    if node.negate then
        return not matches
    end
    return matches
end

--- Phase condition: P:phase
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
-- @param node table AST conditional node
-- @param context table? Override context
-- @return boolean Should content be shown
function LoolibNoteMarkupMixin:EvaluateCondition(node, context)
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
-- @param conditionType string Condition type name
-- @param handler function Function(node, context) -> boolean
function LoolibNoteMarkupMixin:RegisterHandler(conditionType, handler)
    self._customHandlers[conditionType] = handler
end

--- Unregister custom handler
-- @param conditionType string
function LoolibNoteMarkupMixin:UnregisterHandler(conditionType)
    self._customHandlers[conditionType] = nil
end

--- Get all registered handlers (built-in + custom)
-- @return table Map of condition type -> handler function
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
-- @param ast table Root AST node from NoteParser
-- @param context table? Override context
-- @return table Filtered AST with hidden nodes removed
function LoolibNoteMarkupMixin:Process(ast, context)
    context = context or self._context

    -- Make sure we have current context
    if not context.playerName then
        self:UpdatePlayerContext()
        context = self._context
    end

    return self:_ProcessNode(ast, context)
end

--- Process a single node recursively
-- @param node table AST node
-- @param context table Context
-- @return table? Processed node or nil if hidden
function LoolibNoteMarkupMixin:_ProcessNode(node, context)
    -- Check if NoteParser module exists
    if not Loolib:HasModule("NoteParser") then
        error("NoteMarkup:Process requires NoteParser module", 2)
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
                table.insert(newNode.children, processed)
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
                table.insert(newNode.children, processed)
            end
        end
        return newNode

    else
        -- Non-conditional nodes pass through unchanged
        return node
    end
end

--- Flatten processed AST to simple node list
-- @param ast table Processed AST
-- @return table[] Array of leaf nodes (TEXT, ICON, SPELL, TIMER, SELF)
function LoolibNoteMarkupMixin:Flatten(ast)
    local nodes = {}
    self:_FlattenNode(ast, nodes)
    return nodes
end

function LoolibNoteMarkupMixin:_FlattenNode(node, nodes)
    -- Check if NoteParser module exists
    if not Loolib:HasModule("NoteParser") then
        error("NoteMarkup:Flatten requires NoteParser module", 2)
    end

    local NodeTypes = Loolib:GetModule("NoteParser").NodeTypes

    if node.type == NodeTypes.ROOT then
        for _, child in ipairs(node.children or {}) do
            self:_FlattenNode(child, nodes)
        end
    else
        table.insert(nodes, node)
    end
end

--[[--------------------------------------------------------------------
    STRING-BASED PROCESSING

    These methods work directly on markup strings without requiring
    NoteParser. They use pattern matching to handle basic conditionals.
----------------------------------------------------------------------]]

--- Process markup text directly with basic role/player/class filtering
-- This is a simplified version that doesn't require NoteParser
-- @param text string Markup text
-- @param context table? Override context
-- @return string Processed text
function LoolibNoteMarkupMixin:ProcessText(text, context)
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
        result = result:gsub("{[Hh]}.-{/[Hh]}", "")
    end
    if role ~= "TANK" then
        result = result:gsub("{[Tt]}.-{/[Tt]}", "")
    end
    if role ~= "DAMAGER" and role ~= "DPS" then
        result = result:gsub("{[Dd]}.-{/[Dd]}", "")
    end

    -- Process player tags {P:name}...{/P}, {!P:name}...{/P}
    result = result:gsub("{(!?)P:([^}]+)}(.-){/P}", function(negate, names, content)
        local node = {
            condition = "PLAYER",
            player = names,
            negate = negate == "!",
        }
        if self:EvaluateCondition(node, context) then
            return content
        else
            return ""
        end
    end)

    -- Process class tags {C:class}...{/C}, {!C:class}...{/C}
    result = result:gsub("{(!?)C:([^}]+)}(.-){/C}", function(negate, classes, content)
        local node = {
            condition = "CLASS",
            class = classes,
            negate = negate == "!",
        }
        if self:EvaluateCondition(node, context) then
            return content
        else
            return ""
        end
    end)

    -- Process group tags {G1}...{/G}, {!G123}...{/G}
    result = result:gsub("{(!?)G(%d+)}(.-){/G}", function(negate, group, content)
        local node = {
            condition = "GROUP",
            group = tonumber(group),
            negate = negate == "!",
        }
        if self:EvaluateCondition(node, context) then
            return content
        else
            return ""
        end
    end)

    -- Process race tags {RACE:name}...{/RACE}, {!RACE:name}...{/RACE}
    result = result:gsub("{(!?)RACE:([^}]+)}(.-){/RACE}", function(negate, race, content)
        local node = {
            condition = "RACE",
            race = race,
            negate = negate == "!",
        }
        if self:EvaluateCondition(node, context) then
            return content
        else
            return ""
        end
    end)

    -- Process phase tags {P:phase}...{/P}, {!P:phase}...{/P}
    -- Note: This conflicts with player tags, so use different pattern
    result = result:gsub("{(!?)P(%d+)}(.-){/P}", function(negate, phase, content)
        local node = {
            condition = "PHASE",
            phase = tonumber(phase),
            negate = negate == "!",
        }
        if self:EvaluateCondition(node, context) then
            return content
        else
            return ""
        end
    end)

    return result
end

--[[--------------------------------------------------------------------
    CONVENIENCE METHODS
----------------------------------------------------------------------]]

--- Check if text would produce any visible output for current player
-- @param text string Raw markup text
-- @return boolean
function LoolibNoteMarkupMixin:HasVisibleContent(text)
    local processed = self:ProcessText(text)

    -- Remove all remaining markup tags
    processed = processed:gsub("{[^}]+}", "")

    -- Check if any non-whitespace content remains
    return processed:match("%S") ~= nil
end

--- Get list of player names mentioned in markup
-- @param text string Raw markup text
-- @return string[] Array of player names
function LoolibNoteMarkupMixin:ExtractPlayerNames(text)
    local names = {}
    local seen = {}

    -- Match {P:name} and {!P:name} patterns
    for negate, nameList in text:gmatch("{(!?)P:([^}]+)}") do
        -- Handle comma-separated names
        for name in nameList:gmatch("[^,]+") do
            name = strtrim(name)
            -- Remove color codes
            name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

            local lowerName = name:lower()
            if not seen[lowerName] then
                seen[lowerName] = true
                table.insert(names, name)
            end
        end
    end

    return names
end

--- Get list of classes mentioned in markup
-- @param text string Raw markup text
-- @return string[] Array of class tokens
function LoolibNoteMarkupMixin:ExtractClasses(text)
    local classes = {}
    local seen = {}

    -- Match {C:class} and {!C:class} patterns
    for negate, classList in text:gmatch("{(!?)C:([^}]+)}") do
        -- Handle comma-separated classes
        for class in classList:gmatch("[^,]+") do
            class = strtrim(class)
            -- Remove color codes
            class = class:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            class = class:upper()

            if not seen[class] then
                seen[class] = true
                table.insert(classes, class)
            end
        end
    end

    return classes
end

--- Get list of roles mentioned in markup
-- @param text string Raw markup text
-- @return string[] Array of role tokens ("HEALER", "TANK", "DAMAGER")
function LoolibNoteMarkupMixin:ExtractRoles(text)
    local roles = {}

    if text:match("{[Hh]}") then
        table.insert(roles, "HEALER")
    end
    if text:match("{[Tt]}") then
        table.insert(roles, "TANK")
    end
    if text:match("{[Dd]}") then
        table.insert(roles, "DAMAGER")
    end

    return roles
end

--- Get list of groups mentioned in markup
-- @param text string Raw markup text
-- @return number[] Array of group numbers
function LoolibNoteMarkupMixin:ExtractGroups(text)
    local groups = {}
    local seen = {}

    -- Match {G1}, {!G123}, etc.
    for negate, groupStr in text:gmatch("{(!?)G(%d+)}") do
        -- Each digit is a separate group
        for i = 1, #groupStr do
            local group = tonumber(groupStr:sub(i, i))
            if group and not seen[group] then
                seen[group] = true
                table.insert(groups, group)
            end
        end
    end

    table.sort(groups)
    return groups
end

--[[--------------------------------------------------------------------
    FACTORY AND REGISTRATION
----------------------------------------------------------------------]]

--- Create a new markup processor instance
-- @return table Processor
local function LoolibCreateNoteMarkup()
    local processor = {}
    LoolibMixin(processor, LoolibNoteMarkupMixin)
    processor:OnLoad()
    return processor
end

-- Singleton processor for convenience
local defaultProcessor = nil

--- Get default processor instance
-- @return table Processor
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
