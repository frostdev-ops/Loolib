--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Timer - AceTimer-3.0 compatible timer scheduling system

    Provides repeating and one-shot timer functionality using C_Timer
    with callback support for methods and functions.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Local references for performance
local GetTime = GetTime
local C_Timer = C_Timer
local type = type
local max = math.max

-- Global handle counter for unique timer IDs
local timerHandleCounter = 0

--[[--------------------------------------------------------------------
    LoolibTimerMixin

    Mixin for objects that need timer scheduling capabilities.
    Can be mixed into addons to provide AceTimer-like functionality.
----------------------------------------------------------------------]]

LoolibTimerMixin = {}

--[[--------------------------------------------------------------------
    Internal Helper Functions
----------------------------------------------------------------------]]

--- Generate a unique timer handle
-- @return string - Unique timer handle
local function GenerateTimerHandle()
    timerHandleCounter = timerHandleCounter + 1
    return "LoolibTimer" .. timerHandleCounter
end

--- Validate callback parameter
-- @param callback function|string - The callback to validate
-- @return boolean - True if valid
local function ValidateCallback(callback)
    local callbackType = type(callback)
    return callbackType == "function" or callbackType == "string"
end

--- Validate delay parameter
-- @param delay number - The delay to validate
-- @return boolean - True if valid
local function ValidateDelay(delay)
    return type(delay) == "number" and delay > 0
end

--[[--------------------------------------------------------------------
    Timer Creation and Management
----------------------------------------------------------------------]]

--- Initialize timer storage for this object
-- @param self table - The object instance
local function EnsureTimerStorage(self)
    if not self.timers then
        self.timers = {}
    end
end

--- Schedule a one-shot timer
-- @param callback function|string - Function to call or method name
-- @param delay number - Seconds to wait before firing
-- @param ... - Arguments to pass to callback
-- @return string - Timer handle for cancellation
function LoolibTimerMixin:ScheduleTimer(callback, delay, ...)
    -- Validate parameters
    if not ValidateCallback(callback) then
        error("ScheduleTimer: callback must be a function or string (method name)", 2)
    end

    if not ValidateDelay(delay) then
        error("ScheduleTimer: delay must be a positive number", 2)
    end

    EnsureTimerStorage(self)

    -- Generate unique handle
    local handle = GenerateTimerHandle()

    -- Capture arguments for callback
    local args = {...}
    local argCount = select("#", ...)

    -- Store timer info
    local timerInfo = {
        handle = handle,
        callback = callback,
        endTime = GetTime() + delay,
        repeating = false,
        args = args,
        argCount = argCount,
    }

    self.timers[handle] = timerInfo

    -- Create the C_Timer callback
    local timerCallback = function()
        -- Check if timer still exists (not cancelled)
        if not self.timers[handle] then
            return
        end

        -- Remove timer before firing (one-shot)
        self.timers[handle] = nil

        -- Execute callback
        if type(callback) == "string" then
            -- Method name - call self[callback](self, ...)
            local method = self[callback]
            if method then
                if argCount > 0 then
                    method(self, unpack(args, 1, argCount))
                else
                    method(self)
                end
            else
                Loolib:Error("ScheduleTimer: method '" .. callback .. "' not found")
            end
        else
            -- Function - call callback(...)
            if argCount > 0 then
                callback(unpack(args, 1, argCount))
            else
                callback()
            end
        end
    end

    -- Schedule with C_Timer
    C_Timer.After(delay, timerCallback)

    return handle
end

--- Schedule a repeating timer
-- @param callback function|string - Function to call or method name
-- @param delay number - Seconds between each execution
-- @param ... - Arguments to pass to callback
-- @return string - Timer handle for cancellation
function LoolibTimerMixin:ScheduleRepeatingTimer(callback, delay, ...)
    -- Validate parameters
    if not ValidateCallback(callback) then
        error("ScheduleRepeatingTimer: callback must be a function or string (method name)", 2)
    end

    if not ValidateDelay(delay) then
        error("ScheduleRepeatingTimer: delay must be a positive number", 2)
    end

    EnsureTimerStorage(self)

    -- Generate unique handle
    local handle = GenerateTimerHandle()

    -- Capture arguments for callback
    local args = {...}
    local argCount = select("#", ...)

    -- Store timer info (endTime will be updated each tick)
    local timerInfo = {
        handle = handle,
        callback = callback,
        endTime = GetTime() + delay,
        repeating = true,
        delay = delay,
        args = args,
        argCount = argCount,
        ticker = nil, -- Will be set below
    }

    self.timers[handle] = timerInfo

    -- Create the C_Timer callback
    local timerCallback = function()
        -- Check if timer still exists (not cancelled)
        if not self.timers[handle] then
            return
        end

        -- Update next fire time
        timerInfo.endTime = GetTime() + delay

        -- Execute callback
        if type(callback) == "string" then
            -- Method name - call self[callback](self, ...)
            local method = self[callback]
            if method then
                if argCount > 0 then
                    method(self, unpack(args, 1, argCount))
                else
                    method(self)
                end
            else
                Loolib:Error("ScheduleRepeatingTimer: method '" .. callback .. "' not found")
            end
        else
            -- Function - call callback(...)
            if argCount > 0 then
                callback(unpack(args, 1, argCount))
            else
                callback()
            end
        end
    end

    -- Schedule with C_Timer.NewTicker
    local ticker = C_Timer.NewTicker(delay, timerCallback)
    timerInfo.ticker = ticker

    return handle
end

--[[--------------------------------------------------------------------
    Timer Cancellation
----------------------------------------------------------------------]]

--- Cancel a scheduled timer
-- @param handle string - Timer handle returned from Schedule methods
-- @return boolean - True if cancelled, false if not found
function LoolibTimerMixin:CancelTimer(handle)
    if not self.timers then
        return false
    end

    local timerInfo = self.timers[handle]
    if not timerInfo then
        return false
    end

    -- Cancel ticker if it's a repeating timer
    if timerInfo.repeating and timerInfo.ticker then
        timerInfo.ticker:Cancel()
    end

    -- Remove from storage
    self.timers[handle] = nil

    return true
end

--- Cancel all timers for this object
function LoolibTimerMixin:CancelAllTimers()
    if not self.timers then
        return
    end

    -- Cancel each timer
    for handle, timerInfo in pairs(self.timers) do
        if timerInfo.repeating and timerInfo.ticker then
            timerInfo.ticker:Cancel()
        end
    end

    -- Clear storage
    self.timers = {}
end

--[[--------------------------------------------------------------------
    Timer Query
----------------------------------------------------------------------]]

--- Get time remaining on a timer
-- @param handle string - Timer handle
-- @return number|nil - Seconds remaining, or nil if not found
function LoolibTimerMixin:TimeLeft(handle)
    if not self.timers then
        return nil
    end

    local timerInfo = self.timers[handle]
    if not timerInfo then
        return nil
    end

    -- Calculate time remaining
    local remaining = timerInfo.endTime - GetTime()
    return max(0, remaining)
end

--- Check if a timer exists
-- @param handle string - Timer handle
-- @return boolean - True if timer exists and is active
function LoolibTimerMixin:IsTimerActive(handle)
    return self.timers and self.timers[handle] ~= nil
end

--- Get all active timer handles
-- @return table - Array of timer handles
function LoolibTimerMixin:GetActiveTimers()
    if not self.timers then
        return {}
    end

    local handles = {}
    for handle in pairs(self.timers) do
        handles[#handles + 1] = handle
    end

    return handles
end

--- Get count of active timers
-- @return number - Number of active timers
function LoolibTimerMixin:GetTimerCount()
    if not self.timers then
        return 0
    end

    local count = 0
    for _ in pairs(self.timers) do
        count = count + 1
    end

    return count
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local TimerModule = {
    Mixin = LoolibTimerMixin,
}

Loolib:RegisterModule("Timer", TimerModule)
