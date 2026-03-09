local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Timer - AceTimer-3.0 compatible timer scheduling system

    Provides repeating and one-shot timer functionality using C_Timer
    with callback support for methods and functions.
----------------------------------------------------------------------]]

local C_Timer = C_Timer
local GetTime = GetTime
local error = error
local pairs = pairs
local select = select
local type = type
local unpack = unpack

local max = math.max

local TimerModule = Loolib.Timer or {}
local TimerMixin = TimerModule.Mixin or {}

-- Global handle counter for unique timer IDs
local timerHandleCounter = 0

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

--- Initialize timer storage for this object
-- @param self table - The object instance
local function EnsureTimerStorage(self)
    if not self.timers then
        self.timers = {}
    end
end

local function InvokeTimerCallback(owner, callback, args, argCount, context)
    if type(callback) == "string" then
        local method = owner[callback]
        if method then
            if argCount > 0 then
                method(owner, unpack(args, 1, argCount))
            else
                method(owner)
            end
        else
            Loolib:Error(context .. ": method '" .. callback .. "' not found")
        end
        return
    end

    if argCount > 0 then
        callback(unpack(args, 1, argCount))
    else
        callback()
    end
end

--[[--------------------------------------------------------------------
    Timer Creation and Management
----------------------------------------------------------------------]]

--- Schedule a one-shot timer
-- @param callback function|string - Function to call or method name
-- @param delay number - Seconds to wait before firing
-- @param ... - Arguments to pass to callback
-- @return string - Timer handle for cancellation
function TimerMixin:ScheduleTimer(callback, delay, ...)
    if not ValidateCallback(callback) then
        error("ScheduleTimer: callback must be a function or string (method name)", 2)
    end

    if not ValidateDelay(delay) then
        error("ScheduleTimer: delay must be a positive number", 2)
    end

    EnsureTimerStorage(self)

    local handle = GenerateTimerHandle()
    local args = { ... }
    local argCount = select("#", ...)

    self.timers[handle] = {
        handle = handle,
        callback = callback,
        endTime = GetTime() + delay,
        repeating = false,
        args = args,
        argCount = argCount,
    }

    C_Timer.After(delay, function()
        if not self.timers or not self.timers[handle] then
            return
        end

        self.timers[handle] = nil
        InvokeTimerCallback(self, callback, args, argCount, "ScheduleTimer")
    end)

    return handle
end

--- Schedule a repeating timer
-- @param callback function|string - Function to call or method name
-- @param delay number - Seconds between each execution
-- @param ... - Arguments to pass to callback
-- @return string - Timer handle for cancellation
function TimerMixin:ScheduleRepeatingTimer(callback, delay, ...)
    if not ValidateCallback(callback) then
        error("ScheduleRepeatingTimer: callback must be a function or string (method name)", 2)
    end

    if not ValidateDelay(delay) then
        error("ScheduleRepeatingTimer: delay must be a positive number", 2)
    end

    EnsureTimerStorage(self)

    local handle = GenerateTimerHandle()
    local args = { ... }
    local argCount = select("#", ...)
    local timerInfo = {
        handle = handle,
        callback = callback,
        endTime = GetTime() + delay,
        repeating = true,
        delay = delay,
        args = args,
        argCount = argCount,
        ticker = nil,
    }

    self.timers[handle] = timerInfo

    timerInfo.ticker = C_Timer.NewTicker(delay, function()
        if not self.timers or not self.timers[handle] then
            return
        end

        timerInfo.endTime = GetTime() + delay
        InvokeTimerCallback(self, callback, args, argCount, "ScheduleRepeatingTimer")
    end)

    return handle
end

--[[--------------------------------------------------------------------
    Timer Cancellation
----------------------------------------------------------------------]]

--- Cancel a scheduled timer
-- @param handle string - Timer handle returned from Schedule methods
-- @return boolean - True if cancelled, false if not found
function TimerMixin:CancelTimer(handle)
    if not self.timers then
        return false
    end

    local timerInfo = self.timers[handle]
    if not timerInfo then
        return false
    end

    if timerInfo.repeating and timerInfo.ticker then
        timerInfo.ticker:Cancel()
    end

    self.timers[handle] = nil
    return true
end

--- Cancel all timers for this object
function TimerMixin:CancelAllTimers()
    if not self.timers then
        return
    end

    for _, timerInfo in pairs(self.timers) do
        if timerInfo.repeating and timerInfo.ticker then
            timerInfo.ticker:Cancel()
        end
    end

    self.timers = {}
end

--[[--------------------------------------------------------------------
    Timer Query
----------------------------------------------------------------------]]

--- Get time remaining on a timer
-- @param handle string - Timer handle
-- @return number|nil - Seconds remaining, or nil if not found
function TimerMixin:TimeLeft(handle)
    if not self.timers then
        return nil
    end

    local timerInfo = self.timers[handle]
    if not timerInfo then
        return nil
    end

    return max(0, timerInfo.endTime - GetTime())
end

--- Check if a timer exists
-- @param handle string - Timer handle
-- @return boolean - True if timer exists and is active
function TimerMixin:IsTimerActive(handle)
    return self.timers and self.timers[handle] ~= nil
end

--- Get all active timer handles
-- @return table - Array of timer handles
function TimerMixin:GetActiveTimers()
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
function TimerMixin:GetTimerCount()
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

Loolib.Timer = TimerModule
Loolib.Timer.Mixin = TimerMixin

Loolib:RegisterModule("Core.Timer", TimerModule)
Loolib:RegisterModule("Timer.Mixin", TimerMixin)
