--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Console output and slash command registration (AceConsole-3.0 equivalent)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local Core = Loolib.Core or Loolib:GetOrCreateModule("Core")

-- Local references to globals
local type = type
local pairs = pairs
local error = error
local print = print
local tostring = tostring
local select = select
local unpack = unpack
local string_format = string.format
local table_concat = table.concat

--[[--------------------------------------------------------------------
    LoolibConsoleMixin

    Provides chat output and slash command registration for addons.
    Based on AceConsole-3.0 API.
----------------------------------------------------------------------]]

local ConsoleMixin = Core.Console or Loolib:GetModule("Core.Console") or {}

-- Storage for registered slash commands
ConsoleMixin.commands = ConsoleMixin.commands or {}
ConsoleMixin.slashIndices = ConsoleMixin.slashIndices or {}
ConsoleMixin.nextCommandId = ConsoleMixin.nextCommandId or 1

--[[--------------------------------------------------------------------
    Chat Output
----------------------------------------------------------------------]]

--- Print a message to a chat frame
-- Supports two calling patterns:
--   Print(frame, ...) - Print to specified frame
--   Print(...) - Print to DEFAULT_CHAT_FRAME
-- @param frame ChatFrame|any - The chat frame, or first part of message
-- @param ... - Message components
function ConsoleMixin:Print(frame, ...)
    local chatFrame, message

    -- Detect if first argument is a frame
    if type(frame) == "table" and frame.AddMessage then
        chatFrame = frame
        message = self:_FormatMessage(...)
    else
        chatFrame = DEFAULT_CHAT_FRAME
        if not chatFrame then
            return -- No chat frame available (extremely early load)
        end
        message = self:_FormatMessage(frame, ...)
    end

    -- Add addon name prefix if available
    if self.name then
        message = string_format("|cff00ff00[%s]|r %s", tostring(self.name), message)
    end

    chatFrame:AddMessage(message)
end

--- Print a formatted message to a chat frame
-- Supports two calling patterns:
--   Printf(frame, format, ...) - Print to specified frame
--   Printf(format, ...) - Print to DEFAULT_CHAT_FRAME
-- @param frame ChatFrame|string - The chat frame, or format string
-- @param format string|any - The format string, or first format argument
-- @param ... - Format arguments
function ConsoleMixin:Printf(frame, format, ...)
    local chatFrame, message

    -- Detect if first argument is a frame
    if type(frame) == "table" and frame.AddMessage then
        chatFrame = frame
        if type(format) ~= "string" then
            error("LoolibConsole: Printf() format argument must be a string", 2)
        end
        message = string_format(format, ...)
    else
        chatFrame = DEFAULT_CHAT_FRAME
        if not chatFrame then
            return -- No chat frame available (extremely early load)
        end
        if type(frame) ~= "string" then
            error("LoolibConsole: Printf() format argument must be a string", 2)
        end
        message = string_format(frame, format, ...)
    end

    -- Add addon name prefix if available
    if self.name then
        message = string_format("|cff00ff00[%s]|r %s", tostring(self.name), message)
    end

    chatFrame:AddMessage(message)
end

-- INTERNAL
--- Format multiple values into a message string
-- @param ... - Values to format
-- @return string - Formatted message
function ConsoleMixin:_FormatMessage(...)
    local n = select("#", ...)
    if n == 0 then return "" end

    local parts = {}
    for i = 1, n do
        local v = select(i, ...)
        parts[i] = tostring(v)
    end

    return table_concat(parts, " ")
end

--[[--------------------------------------------------------------------
    Slash Command Registration
----------------------------------------------------------------------]]

--- Register a slash command
-- @param command string - The command name (without /)
-- @param func function|string - Callback function or method name
-- @param persist boolean - (Optional) Keep registration across reloads
-- @return boolean - Success
function ConsoleMixin:RegisterChatCommand(command, func, persist)
    if type(command) ~= "string" or command == "" then
        error("LoolibConsole: RegisterChatCommand() command must be a non-empty string", 2)
        return false
    end

    if not func then
        error("LoolibConsole: RegisterChatCommand() func is required", 2)
        return false
    end

    -- Resolve method name to function
    local handler = func
    if type(func) == "string" then
        handler = self[func]
        if not handler then
            error(string_format("LoolibConsole: RegisterChatCommand() method '%s' not found on object", func), 2)
            return false
        end
    end

    if type(handler) ~= "function" then
        error("LoolibConsole: RegisterChatCommand() func must be a function or method name", 2)
        return false
    end

    -- Check if already registered
    if self.commands[command] then
        Loolib:Debug("Command already registered:", command)
        return false
    end

    -- Generate unique command ID
    local commandId = "LOOLIB_CMD_" .. self.nextCommandId
    self.nextCommandId = self.nextCommandId + 1

    -- intentional: slash command registration requires _G write
    _G["SLASH_" .. commandId .. "1"] = "/" .. command:lower()

    -- Create the handler wrapper
    SlashCmdList[commandId] = function(msg, editBox)
        handler(self, msg or "", editBox)
    end

    -- Store command info
    self.commands[command] = {
        id = commandId,
        handler = handler,
        persist = persist or false,
    }

    -- Track this slash index
    if not self.slashIndices[commandId] then
        self.slashIndices[commandId] = 1
    end

    return true
end

--- Unregister a slash command
-- @param command string - The command name (without /)
-- @return boolean - Success
function ConsoleMixin:UnregisterChatCommand(command)
    if type(command) ~= "string" then
        error("LoolibConsole: UnregisterChatCommand() command must be a string", 2)
        return false
    end

    local cmdInfo = self.commands[command]
    if not cmdInfo then
        return false
    end

    -- intentional: slash command registration requires _G write
    local commandId = cmdInfo.id
    if commandId then
        local idx = 1
        while _G["SLASH_" .. commandId .. idx] do
            _G["SLASH_" .. commandId .. idx] = nil
            idx = idx + 1
        end

        -- Clear the handler
        SlashCmdList[commandId] = nil

        -- Remove slash index tracking
        self.slashIndices[commandId] = nil
    end

    -- Remove from tracking
    self.commands[command] = nil

    return true
end

--- Unregister all slash commands
function ConsoleMixin:UnregisterAllChatCommands()
    for command in pairs(self.commands) do
        self:UnregisterChatCommand(command)
    end
end

--- Check if a command is registered
-- @param command string - The command name (without /)
-- @return boolean
function ConsoleMixin:IsCommandRegistered(command)
    return self.commands[command] ~= nil
end

--[[--------------------------------------------------------------------
    Argument Parsing
----------------------------------------------------------------------]]

--- Parse slash command arguments
-- Handles quoted strings and returns multiple values
-- @param str string - The input string to parse
-- @param numargs number|nil - (Optional) Number of arguments to extract
-- @param startpos number|nil - (Optional) Starting position (default 1)
-- @return ... - Parsed arguments
function ConsoleMixin:GetArgs(str, numargs, startpos)
    if type(str) ~= "string" then
        return
    end

    if numargs ~= nil and type(numargs) ~= "number" then
        error("LoolibConsole: GetArgs() numargs must be a number or nil", 2)
    end

    if startpos ~= nil and type(startpos) ~= "number" then
        error("LoolibConsole: GetArgs() startpos must be a number or nil", 2)
    end

    local pos = startpos or 1
    local args = {}
    local argCount = 0

    while pos <= #str do
        -- Skip whitespace
        local wsStart, wsEnd = str:find("^%s+", pos)
        if wsStart then
            pos = wsEnd + 1
        end

        if pos > #str then
            break
        end

        -- Check if we've extracted enough arguments
        if numargs and argCount >= numargs then
            break
        end

        -- Check for quoted string
        local char = str:sub(pos, pos)
        local arg

        if char == '"' or char == "'" then
            -- Find matching quote, handling escapes
            local quoteChar = char
            pos = pos + 1
            local startPos = pos
            local escaped = false

            while pos <= #str do
                local c = str:sub(pos, pos)

                if escaped then
                    escaped = false
                elseif c == "\\" then
                    escaped = true
                elseif c == quoteChar then
                    -- Found closing quote
                    arg = str:sub(startPos, pos - 1)
                    -- Process escape sequences
                    arg = arg:gsub("\\(.)", "%1")
                    pos = pos + 1
                    break
                end

                pos = pos + 1
            end

            -- If no closing quote found, take rest of string
            if not arg then
                arg = str:sub(startPos)
                arg = arg:gsub("\\(.)", "%1")
            end
        else
            -- Unquoted argument - read until whitespace
            local argEnd = str:find("%s", pos) or (#str + 1)
            arg = str:sub(pos, argEnd - 1)
            pos = argEnd
        end

        if arg and arg ~= "" then
            argCount = argCount + 1
            args[argCount] = arg
        end
    end

    -- Return multiple values, not a table
    return unpack(args, 1, argCount)
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Core.Console = ConsoleMixin
Loolib.Console = ConsoleMixin

Loolib:RegisterModule("Core.Console", ConsoleMixin)
