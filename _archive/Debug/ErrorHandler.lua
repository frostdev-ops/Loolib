--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ErrorHandler - Centralized error logging and handling system

    Provides error capture from WoW events, persistent storage,
    deduplication, and retrieval APIs for debugging.

    Features:
    - Captures ADDON_ACTION_BLOCKED, ADDON_ACTION_FORBIDDEN, LUA_WARNING
    - Stack trace capture (configurable depth, default 10 levels)
    - Error deduplication by message hash
    - Circular buffer storage (configurable max, default 100)
    - Time-based cleanup (configurable retention, default 7 days)
    - SavedVariables persistence across sessions
    - Integration with Logger module for output
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for ErrorHandler")

-- Verify dependencies
local LoolibEventRegistry = assert(Loolib.EventRegistry, "Loolib/Events/EventRegistry.lua must be loaded before ErrorHandler")

--[[--------------------------------------------------------------------
    Configuration Constants
----------------------------------------------------------------------]]

local DEFAULT_MAX_ERRORS = 100              -- Maximum errors in circular buffer
local DEFAULT_STACK_DEPTH = 10              -- Stack trace depth
local DEFAULT_RETENTION_DAYS = 7            -- Days to keep errors
local SECONDS_PER_DAY = 86400               -- 24 * 60 * 60
local HASH_MODULO = 2147483647              -- Prime for string hashing

--[[--------------------------------------------------------------------
    LoolibErrorHandlerMixin

    The main error handler mixin. Can be used standalone or
    accessed via Loolib:GetModule("ErrorHandler").
----------------------------------------------------------------------]]

local LoolibErrorHandlerMixin = {}

--- Initialize the error handler
function LoolibErrorHandlerMixin:Init()
    -- Configuration
    self.config = {
        maxErrors = DEFAULT_MAX_ERRORS,
        stackDepth = DEFAULT_STACK_DEPTH,
        retentionDays = DEFAULT_RETENTION_DAYS,
        enableLogging = true,           -- Log errors via Logger module
        enablePersistence = true,       -- Save to SavedVariables
        enableDeduplication = true,     -- Deduplicate identical errors
    }

    -- Error storage (circular buffer)
    self.errors = {}
    self.errorCount = 0                 -- Total errors captured
    self.writeIndex = 1                 -- Next position to write

    -- Deduplication tracking
    self.errorHashes = {}               -- hash -> {count, firstSeen, lastSeen, index}

    -- Registered for events flag
    self.eventsRegistered = false

    -- Reference to Logger if available
    self.logger = nil
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set maximum number of errors to store
-- @param max number - Maximum errors (1-10000)
function LoolibErrorHandlerMixin:SetMaxErrors(max)
    if type(max) ~= "number" or max < 1 or max > 10000 then
        error("MaxErrors must be between 1 and 10000")
    end
    self.config.maxErrors = math.floor(max)
end

--- Get maximum error storage capacity
-- @return number
function LoolibErrorHandlerMixin:GetMaxErrors()
    return self.config.maxErrors
end

--- Set stack trace depth
-- @param depth number - Stack depth (0-50)
function LoolibErrorHandlerMixin:SetStackDepth(depth)
    if type(depth) ~= "number" or depth < 0 or depth > 50 then
        error("StackDepth must be between 0 and 50")
    end
    self.config.stackDepth = math.floor(depth)
end

--- Get stack trace depth
-- @return number
function LoolibErrorHandlerMixin:GetStackDepth()
    return self.config.stackDepth
end

--- Set error retention period in days
-- @param days number - Days to keep errors (1-365)
function LoolibErrorHandlerMixin:SetRetentionDays(days)
    if type(days) ~= "number" or days < 1 or days > 365 then
        error("RetentionDays must be between 1 and 365")
    end
    self.config.retentionDays = days
end

--- Get error retention period
-- @return number - Days
function LoolibErrorHandlerMixin:GetRetentionDays()
    return self.config.retentionDays
end

--- Enable or disable Logger integration
-- @param enabled boolean
function LoolibErrorHandlerMixin:SetLoggingEnabled(enabled)
    self.config.enableLogging = enabled
end

--- Check if logging is enabled
-- @return boolean
function LoolibErrorHandlerMixin:IsLoggingEnabled()
    return self.config.enableLogging
end

--- Enable or disable SavedVariables persistence
-- @param enabled boolean
function LoolibErrorHandlerMixin:SetPersistenceEnabled(enabled)
    self.config.enablePersistence = enabled
end

--- Check if persistence is enabled
-- @return boolean
function LoolibErrorHandlerMixin:IsPersistenceEnabled()
    return self.config.enablePersistence
end

--- Enable or disable error deduplication
-- @param enabled boolean
function LoolibErrorHandlerMixin:SetDeduplicationEnabled(enabled)
    self.config.enableDeduplication = enabled
end

--- Check if deduplication is enabled
-- @return boolean
function LoolibErrorHandlerMixin:IsDeduplicationEnabled()
    return self.config.enableDeduplication
end

--[[--------------------------------------------------------------------
    Event Registration
----------------------------------------------------------------------]]

--- Start capturing error events
function LoolibErrorHandlerMixin:RegisterEvents()
    if self.eventsRegistered then
        return
    end

    -- Register for WoW error events
    LoolibEventRegistry:RegisterEventCallback("ADDON_ACTION_BLOCKED", function(_, ...)
        self:OnAddonActionBlocked(...)
    end, self)

    LoolibEventRegistry:RegisterEventCallback("ADDON_ACTION_FORBIDDEN", function(_, ...)
        self:OnAddonActionForbidden(...)
    end, self)

    LoolibEventRegistry:RegisterEventCallback("LUA_WARNING", function(_, ...)
        self:OnLuaWarning(...)
    end, self)

    self.eventsRegistered = true
end

--- Stop capturing error events
function LoolibErrorHandlerMixin:UnregisterEvents()
    if not self.eventsRegistered then
        return
    end

    LoolibEventRegistry:UnregisterAllEventsForOwner(self)
    self.eventsRegistered = false
end

--[[--------------------------------------------------------------------
    Event Handlers
----------------------------------------------------------------------]]

--- Check if an addon name belongs to Loolib or a Loolib-based addon
-- @param addonName string - Addon name from WoW event
-- @return boolean
function LoolibErrorHandlerMixin:IsOwnAddon(addonName)
    if not addonName then return false end
    if addonName == "Loolib" then return true end
    return Loolib.addons[addonName] ~= nil
end

--- Handle ADDON_ACTION_BLOCKED event
-- Fired when an addon tries to perform a protected action
-- @param addonName string - The addon name
-- @param blockedAction string - The blocked action
function LoolibErrorHandlerMixin:OnAddonActionBlocked(addonName, blockedAction)
    -- Only capture taint errors from Loolib or Loolib-based addons
    if not self:IsOwnAddon(addonName) then return end
    local message = string.format("Addon '%s' tried to call protected function '%s'",
        addonName or "Unknown", blockedAction or "Unknown")

    self:RecordError("ADDON_ACTION_BLOCKED", message, 3)
end

--- Handle ADDON_ACTION_FORBIDDEN event
-- Fired when an addon tries to perform a forbidden action
-- @param addonName string - The addon name
-- @param forbiddenAction string - The forbidden action
function LoolibErrorHandlerMixin:OnAddonActionForbidden(addonName, forbiddenAction)
    -- Only capture taint errors from Loolib or Loolib-based addons
    if not self:IsOwnAddon(addonName) then return end
    local message = string.format("Addon '%s' tried to call forbidden function '%s'",
        addonName or "Unknown", forbiddenAction or "Unknown")

    self:RecordError("ADDON_ACTION_FORBIDDEN", message, 3)
end

--- Handle LUA_WARNING event
-- Fired when Lua generates a warning
-- @param warningType number - Warning type ID
-- @param warningMessage string - The warning message
function LoolibErrorHandlerMixin:OnLuaWarning(warningType, warningMessage)
    -- LUA_WARNING fires synchronously — the original call stack IS preserved.
    -- However, Loolib's event dispatch frames are always on top of the stack:
    --   Loolib/Debug/ErrorHandler.lua  (this handler + anonymous closure)
    --   Loolib/Events/CallbackRegistry.lua  (TriggerEvent + pcall)
    --   Loolib/Events/EventRegistry.lua  (OnEvent + anonymous closure)
    -- Strip these dispatch frames before checking for addon paths.
    local stackStr = debugstack(2, 20, 20)

    -- Filter out Loolib event dispatch infrastructure
    local filteredLines = {}
    for line in stackStr:gmatch("[^\n]+") do
        if not line:find("Loolib/Debug/", 1, true)
           and not line:find("Loolib/Events/", 1, true) then
            filteredLines[#filteredLines + 1] = line
        end
    end
    local filteredStack = table.concat(filteredLines, "\n")

    -- Check filtered stack for Loolib functional code or registered addons
    local isOwn = filteredStack:find("AddOns/Loolib/", 1, true) ~= nil
    if not isOwn then
        for addonName in pairs(Loolib.addons) do
            if filteredStack:find("AddOns/" .. addonName .. "/", 1, true) then
                isOwn = true
                break
            end
        end
    end
    if not isOwn then return end

    local message = string.format("[Warning Type %s] %s",
        tostring(warningType), warningMessage or "Unknown")

    self:RecordError("LUA_WARNING", message, 3)
end

--[[--------------------------------------------------------------------
    Stack Trace Utilities
----------------------------------------------------------------------]]

--- Capture a stack trace
-- @param startLevel number - Stack level to start from (default 1)
-- @param maxDepth number - Maximum depth (default from config)
-- @return table - Array of stack frame strings
function LoolibErrorHandlerMixin:CaptureStackTrace(startLevel, maxDepth)
    startLevel = startLevel or 1
    maxDepth = maxDepth or self.config.stackDepth

    -- Get the full stack trace as a string
    local stackStr = debugstack(startLevel + 1, maxDepth, maxDepth)

    if not stackStr or stackStr == "" then
        return {}
    end

    -- Parse the stack trace into individual lines
    local stack = {}
    local lineNum = 0

    for line in stackStr:gmatch("[^\r\n]+") do
        lineNum = lineNum + 1

        -- Skip the first line which is usually the debugstack() call itself
        if lineNum > 1 and lineNum <= maxDepth + 1 then
            -- Clean up the line (remove leading/trailing whitespace)
            line = line:match("^%s*(.-)%s*$")
            if line and line ~= "" then
                table.insert(stack, line)
            end
        end
    end

    return stack
end

--- Format a stack trace for display
-- @param stack table - Array of stack frame strings
-- @return string - Formatted stack trace
function LoolibErrorHandlerMixin:FormatStackTrace(stack)
    if not stack or #stack == 0 then
        return "  (no stack trace)"
    end

    local lines = {}
    for i, frame in ipairs(stack) do
        lines[i] = string.format("  %d: %s", i, frame)
    end

    return table.concat(lines, "\n")
end

--[[--------------------------------------------------------------------
    Error Hashing and Deduplication
----------------------------------------------------------------------]]

--- Generate a hash for an error message
-- Simple string hash using polynomial rolling hash
-- @param message string - The error message
-- @return number - Hash value
function LoolibErrorHandlerMixin:HashMessage(message)
    local hash = 0
    local p = 31
    local p_pow = 1

    for i = 1, #message do
        local char = string.byte(message, i)
        hash = (hash + char * p_pow) % HASH_MODULO
        p_pow = (p_pow * p) % HASH_MODULO
    end

    return hash
end

--- Check if an error is a duplicate
-- @param errorType string - The error type
-- @param message string - The error message
-- @return boolean, table|nil - True if duplicate, and existing error data
function LoolibErrorHandlerMixin:IsDuplicate(errorType, message)
    if not self.config.enableDeduplication then
        return false
    end

    local key = errorType .. "|" .. message
    local hash = self:HashMessage(key)

    local existing = self.errorHashes[hash]
    if existing then
        return true, existing
    end

    return false
end

--[[--------------------------------------------------------------------
    Error Recording
----------------------------------------------------------------------]]

--- Record an error
-- @param errorType string - Type of error (event name or custom)
-- @param message string - Error message
-- @param stackStartLevel number - Where to start stack trace (default 1)
function LoolibErrorHandlerMixin:RecordError(errorType, message, stackStartLevel)
    stackStartLevel = stackStartLevel or 1

    local timestamp = time()
    local stack = self:CaptureStackTrace(stackStartLevel + 1)

    -- Check for duplicates
    local isDupe, existing = self:IsDuplicate(errorType, message)
    if isDupe and existing then
        -- Update duplicate tracking
        existing.count = existing.count + 1
        existing.lastSeen = timestamp

        -- Update the stored error with new timestamp
        if existing.index and self.errors[existing.index] then
            self.errors[existing.index].lastSeen = timestamp
            self.errors[existing.index].count = existing.count
        end

        -- Still log if enabled
        self:LogError(errorType, message, existing.count)
        return
    end

    -- Create error record
    local error = {
        type = errorType,
        message = message,
        timestamp = timestamp,
        lastSeen = timestamp,
        stack = stack,
        count = 1,
    }

    -- Store in circular buffer
    local index = self.writeIndex
    self.errors[index] = error
    self.errorCount = self.errorCount + 1

    -- Update write index (circular)
    self.writeIndex = (index % self.config.maxErrors) + 1

    -- Track for deduplication
    if self.config.enableDeduplication then
        local key = errorType .. "|" .. message
        local hash = self:HashMessage(key)
        self.errorHashes[hash] = {
            count = 1,
            firstSeen = timestamp,
            lastSeen = timestamp,
            index = index,
        }
    end

    -- Log the error
    self:LogError(errorType, message, 1)
end

--- Log an error via the Logger module
-- @param errorType string - Error type
-- @param message string - Error message
-- @param count number - Occurrence count
function LoolibErrorHandlerMixin:LogError(errorType, message, count)
    if not self.config.enableLogging then
        return
    end

    -- Get Logger module if not cached
    if not self.logger and Loolib:HasModule("Logger") then
        self.logger = Loolib:GetModule("Logger")
    end

    local prefix = count > 1 and string.format("[%s x%d]", errorType, count) or string.format("[%s]", errorType)
    local fullMessage = string.format("%s %s", prefix, message)

    if self.logger then
        self.logger:Error(fullMessage)
    else
        -- Fallback to print
        print("|cffff0000[Loolib Error]|r", fullMessage)
    end
end

--[[--------------------------------------------------------------------
    Error Retrieval
----------------------------------------------------------------------]]

--- Get all stored errors
-- @param sorted boolean - If true, sort by timestamp descending (newest first)
-- @return table - Array of error records
function LoolibErrorHandlerMixin:GetErrors(sorted)
    local errors = {}

    -- Copy all non-nil errors
    for i = 1, self.config.maxErrors do
        if self.errors[i] then
            errors[#errors + 1] = self.errors[i]
        end
    end

    -- Sort if requested
    if sorted then
        table.sort(errors, function(a, b)
            return a.timestamp > b.timestamp
        end)
    end

    return errors
end

--- Get the N most recent errors
-- @param count number - Number of errors to retrieve
-- @return table - Array of error records (newest first)
function LoolibErrorHandlerMixin:GetRecentErrors(count)
    count = count or 10

    local errors = self:GetErrors(true)
    local recent = {}

    for i = 1, math.min(count, #errors) do
        recent[i] = errors[i]
    end

    return recent
end

--- Get errors by type
-- @param errorType string - The error type to filter by
-- @return table - Array of matching error records
function LoolibErrorHandlerMixin:GetErrorsByType(errorType)
    local matches = {}

    for i = 1, self.config.maxErrors do
        local error = self.errors[i]
        if error and error.type == errorType then
            matches[#matches + 1] = error
        end
    end

    return matches
end

--- Get error statistics
-- @return table - Stats table with counts and info
function LoolibErrorHandlerMixin:GetErrorStats()
    local stats = {
        totalCaptured = self.errorCount,
        currentlyStored = 0,
        byType = {},
        oldestTimestamp = nil,
        newestTimestamp = nil,
    }

    for i = 1, self.config.maxErrors do
        local error = self.errors[i]
        if error then
            stats.currentlyStored = stats.currentlyStored + 1

            -- Count by type
            stats.byType[error.type] = (stats.byType[error.type] or 0) + error.count

            -- Track timestamp range
            if not stats.oldestTimestamp or error.timestamp < stats.oldestTimestamp then
                stats.oldestTimestamp = error.timestamp
            end
            if not stats.newestTimestamp or error.timestamp > stats.newestTimestamp then
                stats.newestTimestamp = error.timestamp
            end
        end
    end

    return stats
end

--[[--------------------------------------------------------------------
    Error Cleanup
----------------------------------------------------------------------]]

--- Clear all stored errors
function LoolibErrorHandlerMixin:ClearErrors()
    self.errors = {}
    self.errorHashes = {}
    self.writeIndex = 1
    -- Note: Don't reset errorCount, it's a lifetime counter
end

--- Remove errors older than the retention period
-- @return number - Count of errors removed
function LoolibErrorHandlerMixin:CleanupOldErrors()
    local now = time()
    local cutoff = now - (self.config.retentionDays * SECONDS_PER_DAY)
    local removed = 0

    for i = 1, self.config.maxErrors do
        local error = self.errors[i]
        if error and error.timestamp < cutoff then
            -- Remove from storage
            self.errors[i] = nil
            removed = removed + 1

            -- Remove from hash tracking
            if self.config.enableDeduplication then
                local key = error.type .. "|" .. error.message
                local hash = self:HashMessage(key)
                self.errorHashes[hash] = nil
            end
        end
    end

    return removed
end

--- Remove errors of a specific type
-- @param errorType string - The error type to remove
-- @return number - Count of errors removed
function LoolibErrorHandlerMixin:ClearErrorsByType(errorType)
    local removed = 0

    for i = 1, self.config.maxErrors do
        local error = self.errors[i]
        if error and error.type == errorType then
            self.errors[i] = nil
            removed = removed + 1

            -- Remove from hash tracking
            if self.config.enableDeduplication then
                local key = error.type .. "|" .. error.message
                local hash = self:HashMessage(key)
                self.errorHashes[hash] = nil
            end
        end
    end

    return removed
end

--[[--------------------------------------------------------------------
    Persistence (SavedVariables)
----------------------------------------------------------------------]]

--- Export errors to a table suitable for SavedVariables
-- @return table - Serializable error data
function LoolibErrorHandlerMixin:ExportToSavedVariables()
    if not self.config.enablePersistence then
        return nil
    end

    return {
        version = 1,
        config = self.config,
        errors = self.errors,
        errorCount = self.errorCount,
        writeIndex = self.writeIndex,
        exportTime = time(),
    }
end

--- Import errors from SavedVariables
-- @param data table - Data previously exported
-- @return boolean - True if import succeeded
function LoolibErrorHandlerMixin:ImportFromSavedVariables(data)
    if not data or type(data) ~= "table" then
        return false
    end

    -- Validate version
    if data.version ~= 1 then
        return false
    end

    -- Restore config (merge with defaults to handle new options)
    if data.config then
        for key, value in pairs(data.config) do
            if self.config[key] ~= nil then
                self.config[key] = value
            end
        end
    end

    -- Restore errors
    if data.errors then
        self.errors = data.errors
    end

    -- Restore counters
    if data.errorCount then
        self.errorCount = data.errorCount
    end

    if data.writeIndex then
        self.writeIndex = data.writeIndex
    end

    -- Rebuild deduplication hash table
    self:RebuildHashTable()

    -- Clean up old errors after import
    self:CleanupOldErrors()

    return true
end

--- Rebuild the deduplication hash table from stored errors
function LoolibErrorHandlerMixin:RebuildHashTable()
    self.errorHashes = {}

    if not self.config.enableDeduplication then
        return
    end

    for i = 1, self.config.maxErrors do
        local error = self.errors[i]
        if error then
            local key = error.type .. "|" .. error.message
            local hash = self:HashMessage(key)

            self.errorHashes[hash] = {
                count = error.count or 1,
                firstSeen = error.timestamp,
                lastSeen = error.lastSeen or error.timestamp,
                index = i,
            }
        end
    end
end

--[[--------------------------------------------------------------------
    Manual Error Recording
----------------------------------------------------------------------]]

--- Manually record a custom error
-- Useful for capturing errors in pcall blocks or custom validation
-- @param message string - Error message
-- @param errorType string - Optional error type (default "MANUAL")
function LoolibErrorHandlerMixin:RecordManualError(message, errorType)
    errorType = errorType or "MANUAL"
    self:RecordError(errorType, message, 2)
end

--- Wrap a function with error capturing
-- @param func function - The function to wrap
-- @param errorType string - Error type for captured errors
-- @return function - Wrapped function that captures errors
function LoolibErrorHandlerMixin:WrapFunction(func, errorType)
    errorType = errorType or "WRAPPED_FUNCTION"
    local handler = self

    return function(...)
        local success, result = pcall(func, ...)
        if not success then
            handler:RecordManualError(tostring(result), errorType)
            return nil
        end
        return result
    end
end

--[[--------------------------------------------------------------------
    Formatted Output
----------------------------------------------------------------------]]

--- Format an error record as a human-readable string
-- @param error table - Error record
-- @param includeStack boolean - Include stack trace (default true)
-- @return string - Formatted error
function LoolibErrorHandlerMixin:FormatError(error, includeStack)
    if includeStack == nil then
        includeStack = true
    end

    local parts = {}

    -- Header
    local countStr = error.count > 1 and string.format(" (x%d)", error.count) or ""
    table.insert(parts, string.format("[%s]%s %s",
        error.type,
        countStr,
        error.message))

    -- Timestamp
    table.insert(parts, string.format("Time: %s", date("%Y-%m-%d %H:%M:%S", error.timestamp)))

    if error.count > 1 and error.lastSeen and error.lastSeen ~= error.timestamp then
        table.insert(parts, string.format("Last seen: %s", date("%Y-%m-%d %H:%M:%S", error.lastSeen)))
    end

    -- Stack trace
    if includeStack and error.stack then
        table.insert(parts, "Stack trace:")
        table.insert(parts, self:FormatStackTrace(error.stack))
    end

    return table.concat(parts, "\n")
end

--- Print all errors to chat
-- @param count number - Max errors to print (default 10)
function LoolibErrorHandlerMixin:PrintRecentErrors(count)
    count = count or 10
    local errors = self:GetRecentErrors(count)

    if #errors == 0 then
        print("|cff00ff00[Loolib ErrorHandler]|r No errors recorded.")
        return
    end

    print(string.format("|cff00ff00[Loolib ErrorHandler]|r Recent errors (%d):", #errors))

    for i, error in ipairs(errors) do
        print(string.format("|cffff8800--- Error %d ---|r", i))
        print(self:FormatError(error, false))
    end
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

local errorHandler = CreateFromMixins(LoolibErrorHandlerMixin)
errorHandler:Init()
errorHandler:RegisterEvents()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local errorHandlerModule = {
    Mixin = LoolibErrorHandlerMixin,
    Handler = errorHandler,
}

Loolib:RegisterModule("Debug.ErrorHandler", errorHandlerModule)

-- Also register for easy access
local debugModule = Loolib:GetOrCreateModule("Debug")
debugModule.ErrorHandler = errorHandler
