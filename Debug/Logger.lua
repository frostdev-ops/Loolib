--[[--------------------------------------------------------------------
    Logger - Multi-level logging system for Loolib

    Provides formatted logging at multiple severity levels with
    color-coded output to the default chat frame.
----------------------------------------------------------------------]]

LoolibLoggerMixin = {}

-- Log level constants
local LOG_LEVELS = {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
}

-- Reverse lookup for level names
local LEVEL_NAMES = {
    [0] = "DEBUG",
    [1] = "INFO",
    [2] = "WARN",
    [3] = "ERROR",
}

-- Color codes for WoW chat
local COLORS = {
    DEBUG = "|cff888888",  -- Gray
    INFO = "|cffffffff",   -- White
    WARN = "|cffffaa00",   -- Orange
    ERROR = "|cffff0000",  -- Red
}
local RESET = "|r"

-- Default log level is INFO
LoolibLoggerMixin.currentLevel = LOG_LEVELS.INFO

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set the current log level
-- @param level string|number - Level name ("DEBUG", "INFO", "WARN", "ERROR") or numeric (0-3)
function LoolibLoggerMixin:SetLevel(level)
    local numLevel

    if type(level) == "string" then
        numLevel = LOG_LEVELS[level:upper()]
        if not numLevel then
            error(string.format("Invalid log level: %s", level))
        end
    elseif type(level) == "number" then
        if level < 0 or level > 3 then
            error("Log level must be between 0 and 3")
        end
        numLevel = level
    else
        error("Log level must be string or number")
    end

    self.currentLevel = numLevel
end

--- Get the current log level
-- @return number - The current log level (0-3)
function LoolibLoggerMixin:GetLevel()
    return self.currentLevel
end

--- Get the current log level name
-- @return string - The current log level name
function LoolibLoggerMixin:GetLevelName()
    return LEVEL_NAMES[self.currentLevel]
end

--[[--------------------------------------------------------------------
    Internal Helpers
----------------------------------------------------------------------]]

--- Convert arguments to a formatted string
-- @param ... - Values to format
-- @return string - Formatted message
local function FormatMessage(...)
    local args = {...}
    local parts = {}

    for i, arg in ipairs(args) do
        table.insert(parts, tostring(arg))
    end

    return table.concat(parts, " ")
end

--- Output a message to chat if level allows
-- @param levelName string - Level name (DEBUG, INFO, WARN, ERROR)
-- @param message string - The formatted message
local function OutputToChat(levelName, message)
    local prefix = string.format("[Loolib %s]", levelName)
    local color = COLORS[levelName]
    local formatted = string.format("%s%s%s %s", color, prefix, RESET, message)

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(formatted)
    else
        -- Fallback for when chat frame isn't available yet
        print(formatted)
    end
end

--- Check if a level should be logged
-- @param levelValue number - The log level to check (0-3)
-- @return boolean - True if should log, false otherwise
local function ShouldLog(currentLevel, levelValue)
    return levelValue >= currentLevel
end

--[[--------------------------------------------------------------------
    Public Logging Functions
----------------------------------------------------------------------]]

--- Log at DEBUG level (most verbose)
-- @param ... - Values to log
function LoolibLoggerMixin:Debug(...)
    if ShouldLog(self.currentLevel, LOG_LEVELS.DEBUG) then
        local message = FormatMessage(...)
        OutputToChat("DEBUG", message)
    end
end

--- Log at INFO level
-- @param ... - Values to log
function LoolibLoggerMixin:Info(...)
    if ShouldLog(self.currentLevel, LOG_LEVELS.INFO) then
        local message = FormatMessage(...)
        OutputToChat("INFO", message)
    end
end

--- Log at WARN level
-- @param ... - Values to log
function LoolibLoggerMixin:Warn(...)
    if ShouldLog(self.currentLevel, LOG_LEVELS.WARN) then
        local message = FormatMessage(...)
        OutputToChat("WARN", message)
    end
end

--- Log at ERROR level
-- @param ... - Values to log
function LoolibLoggerMixin:Error(...)
    if ShouldLog(self.currentLevel, LOG_LEVELS.ERROR) then
        local message = FormatMessage(...)
        OutputToChat("ERROR", message)
    end
end

--[[--------------------------------------------------------------------
    Assertions
----------------------------------------------------------------------]]

--- Assert a condition, logging an error and raising if false
-- @param condition boolean - The condition to check
-- @param message string|nil - Optional message to display
-- @return boolean - The condition value
function LoolibLoggerMixin:Assert(condition, message)
    if not condition then
        local errorMsg = message or "Assertion failed"
        self:Error(errorMsg)
        error(errorMsg)
    end
    return condition
end

--[[--------------------------------------------------------------------
    Module Registration
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
Loolib:RegisterModule("Logger", LoolibLoggerMixin)
