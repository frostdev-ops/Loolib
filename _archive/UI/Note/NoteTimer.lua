--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    NoteTimer - Countdown timer system for note {time:...} tags

    Handles {time:...} countdown tags in notes. Tracks encounter time,
    phases, and renders timers with appropriate colors and glow effects.

    Timer Tag Formats:
    - {time:seconds}message
    - {time:minutes:seconds}message
    - {time:30,options}message

    Options (comma-separated):
    - p:N or pN - Start timer when phase N begins
    - glow - Glow effect when timer reaches 0
    - all - Show to all players (not just targeted)
    - wa:eventName - Trigger WeakAura custom event

    Dependencies:
    - Core/Loolib.lua
    - Core/Mixin.lua
    - Events/CallbackRegistry.lua
----------------------------------------------------------------------]]

-- Cache globals -- INTERNAL
local type = type
local error = error
local pairs = pairs
local tostring = tostring
local tonumber = tonumber
local math_floor = math.floor
local math_ceil = math.ceil
local string_format = string.format
local string_match = string.match
local string_gmatch = string.gmatch

-- WoW globals -- INTERNAL
local GetTime = GetTime
local CreateFrame = CreateFrame
local strtrim = strtrim

local Loolib = LibStub("Loolib")
local LoolibMixin = assert(Loolib.Mixin, "Loolib.Mixin is required for NoteTimer")

--- NT-02: Use Loolib-prefixed CallbackRegistryMixin, not the Blizzard global
local LoolibCallbackRegistryMixin = assert(Loolib.CallbackRegistryMixin, "Loolib.CallbackRegistryMixin is required for NoteTimer")

--[[--------------------------------------------------------------------
    Timer States and Colors
----------------------------------------------------------------------]]

local TIMER_STATES = {
    WAITING = "WAITING",     -- Timer not started (future encounter)
    RUNNING = "RUNNING",     -- Timer counting down
    IMMINENT = "IMMINENT",   -- Less than 5 seconds remaining
    EXPIRED = "EXPIRED",     -- Timer reached 0
}

-- NT-01 FIX: Timer colors by state — all hex strings are exactly 6 chars
-- (Previously RUNNING had "FFFED88" which is 7 hex chars, causing WoW
--  to consume the next character of note text as part of the color code.)
local TIMER_COLORS = {
    WAITING  = "808080",     -- Gray
    RUNNING  = "FFED88",     -- Yellow (MRT style)
    IMMINENT = "00FF00",     -- Green (MRT style - green when imminent)
    EXPIRED  = "666666",     -- Dark gray
}

--[[--------------------------------------------------------------------
    LoolibNoteTimerMixin

    Manages countdown timers for encounter notes.
----------------------------------------------------------------------]]

---@class LoolibNoteTimerMixin
local LoolibNoteTimerMixin = {}

--- Initialize the timer system. Idempotent.
function LoolibNoteTimerMixin:OnLoad()
    self._encounterStartTime = nil
    self._currentPhase = 0
    self._phaseStartTimes = {}
    self._activeTimers = {}
    self._updateFrame = nil
    self._isRunning = false
    self._glowCallback = nil
    self._weakAuraCallback = nil
    self._waEventCache = {}  -- Cache to prevent duplicate WA events

    -- NT-02 FIX: Use Loolib-prefixed CallbackRegistryMixin, not Blizzard global
    LoolibMixin(self, LoolibCallbackRegistryMixin)
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents({
        "OnTimerStart",
        "OnTimerTick",
        "OnTimerImminent",
        "OnTimerExpire",
        "OnTimerGlow",
    })
end

--[[--------------------------------------------------------------------
    Encounter Management
----------------------------------------------------------------------]]

--- Start encounter timing
---@param encounterTime number? Encounter start time (GetTime()), nil = now
function LoolibNoteTimerMixin:StartEncounter(encounterTime)
    self._encounterStartTime = encounterTime or GetTime()
    self._currentPhase = 1
    self._phaseStartTimes = {[1] = self._encounterStartTime}
    self._activeTimers = {}
    self._waEventCache = {}
    self:_StartUpdateLoop()

    self:TriggerEvent("OnTimerStart")
end

--- End encounter timing
function LoolibNoteTimerMixin:EndEncounter()
    self._encounterStartTime = nil
    self._currentPhase = 0
    self._phaseStartTimes = {}
    self._activeTimers = {}
    self._waEventCache = {}
    self:_StopUpdateLoop()
end

--- Set current encounter phase
---@param phase number Phase number
---@param phaseTime number? Phase start time (GetTime()), nil = now
function LoolibNoteTimerMixin:SetPhase(phase, phaseTime)
    if type(phase) ~= "number" then
        error("LoolibNoteTimer: SetPhase: 'phase' must be a number", 2)
    end
    self._currentPhase = phase
    self._phaseStartTimes[phase] = phaseTime or GetTime()
end

--- Get current encounter time elapsed
---@return number elapsed Seconds since encounter start, or 0 if not in encounter
function LoolibNoteTimerMixin:GetEncounterTime()
    if not self._encounterStartTime then
        return 0
    end
    return GetTime() - self._encounterStartTime
end

--- Get time since phase started
---@param phase number? Phase number (default: current phase)
---@return number elapsed Seconds since phase start
function LoolibNoteTimerMixin:GetPhaseTime(phase)
    phase = phase or self._currentPhase
    local phaseStart = self._phaseStartTimes[phase]
    if not phaseStart then
        return 0
    end
    return GetTime() - phaseStart
end

--- Check if in active encounter
---@return boolean inEncounter
function LoolibNoteTimerMixin:IsInEncounter()
    return self._encounterStartTime ~= nil
end

--[[--------------------------------------------------------------------
    Timer Registration
----------------------------------------------------------------------]]

--- Register a timer for tracking
---@param timerId string Unique identifier
---@param totalSeconds number Total countdown time
---@param options table? {phase, glow, all, wa}
---@return table timer Timer info
function LoolibNoteTimerMixin:RegisterTimer(timerId, totalSeconds, options)
    if type(timerId) ~= "string" then
        error("LoolibNoteTimer: RegisterTimer: 'timerId' must be a string", 2)
    end
    if type(totalSeconds) ~= "number" then
        error("LoolibNoteTimer: RegisterTimer: 'totalSeconds' must be a number", 2)
    end
    options = options or {}

    local timer = {
        id = timerId,
        totalSeconds = totalSeconds,
        phase = options.phase,
        glow = options.glow,
        all = options.all,
        waEvent = options.wa,
        state = TIMER_STATES.WAITING,
        startTime = nil,
        hasGlowed = false,
        hasTriggeredWA = false,
    }

    -- Determine start time
    if options.phase then
        timer.startTime = self._phaseStartTimes[options.phase]
    elseif self._encounterStartTime then
        timer.startTime = self._encounterStartTime
    end

    self._activeTimers[timerId] = timer
    return timer
end

--- Get timer info
---@param timerId string
---@return table? timer
function LoolibNoteTimerMixin:GetTimer(timerId)
    return self._activeTimers[timerId]
end

--- Clear all registered timers
function LoolibNoteTimerMixin:ClearTimers()
    self._activeTimers = {}
    self._waEventCache = {}
end

--[[--------------------------------------------------------------------
    Timer Rendering
----------------------------------------------------------------------]]

--- Render a timer node to formatted string
---@param node table Timer AST node with {minutes, seconds, options}
---@return string formatted Formatted timer string
function LoolibNoteTimerMixin:RenderTimer(node)
    if type(node) ~= "table" then
        error("LoolibNoteTimer: RenderTimer: 'node' must be a table", 2)
    end
    local totalSeconds = (node.minutes or 0) * 60 + (node.seconds or 0)
    local options = self:_ParseTimerOptions(node.options)

    -- Generate unique ID for this timer
    local timerId = totalSeconds .. "_" .. (node.options or "default")

    -- Get or create timer
    local timer = self._activeTimers[timerId]
    if not timer then
        timer = self:RegisterTimer(timerId, totalSeconds, options)
    end

    -- NT-06 FIX: Calculate remaining time from absolute start, not decrements
    local remaining = self:_CalculateRemaining(timer)
    local state = self:_DetermineState(timer, remaining)

    -- Update timer state
    local oldState = timer.state
    timer.state = state

    -- Handle glow (triggers when entering IMMINENT state)
    if state == TIMER_STATES.IMMINENT and oldState ~= TIMER_STATES.IMMINENT then
        if options.glow and not timer.hasGlowed then
            timer.hasGlowed = true
            self:TriggerEvent("OnTimerGlow", timerId, timer)
            if self._glowCallback then
                self._glowCallback(timerId, timer)
            end
        end
    end

    -- Handle WeakAura event (fires every second when <= 5 seconds)
    if options.wa and remaining <= 5 and remaining >= 0 then
        local timeleft = math_ceil(remaining)
        self:_TriggerWeakAuraEvent(options.wa, timeleft, timer, node)
    end

    -- Format output
    return self:FormatTimer(remaining, state)
end

--- Format timer value with color
---@param remaining number Seconds remaining (can be negative)
---@param state string Timer state
---@return string formatted Formatted string with WoW color codes
function LoolibNoteTimerMixin:FormatTimer(remaining, state)
    -- NT-01: All color values are exactly 6 hex chars
    local color = TIMER_COLORS[state] or TIMER_COLORS.RUNNING
    local timeStr

    if remaining >= 60 then
        local minutes = math_floor(remaining / 60)
        local seconds = remaining % 60
        timeStr = string_format("%d:%02d", minutes, seconds)
    elseif remaining >= 0 then
        timeStr = string_format("%.0f", remaining)
    else
        -- Negative = expired
        timeStr = "0"
    end

    return "|cFF" .. color .. timeStr .. "|r"
end

--[[--------------------------------------------------------------------
    Internal Helpers
----------------------------------------------------------------------]]

--- Parse timer options string -- INTERNAL
---@param optionsStr string? Comma-separated options
---@return table options Parsed options {phase, glow, all, wa}
function LoolibNoteTimerMixin:_ParseTimerOptions(optionsStr)
    local options = {}

    if not optionsStr then
        return options
    end

    -- Parse comma-separated options
    for option in string_gmatch(optionsStr, "[^,]+") do
        option = strtrim(option)

        -- Phase: p:N or pN (e.g., "p:2", "p2")
        local phase = string_match(option, "^p:?(%d+)$")
        if phase then
            options.phase = tonumber(phase)

        -- Glow effect
        elseif option == "glow" or option == "glowall" then
            options.glow = true
            if option == "glowall" then
                options.all = true
            end

        -- Show to all
        elseif option == "all" then
            options.all = true

        -- WeakAura event: wa:eventName
        elseif string_match(option, "^wa:") then
            options.wa = string_match(option, "^wa:(.+)$")
        end
    end

    return options
end

--- Calculate remaining time for a timer -- INTERNAL
--- NT-06 FIX: Always compute from absolute start time to prevent drift
---@param timer table Timer object
---@return number remaining Seconds remaining
function LoolibNoteTimerMixin:_CalculateRemaining(timer)
    if not timer.startTime then
        return timer.totalSeconds
    end

    local elapsed = GetTime() - timer.startTime
    return timer.totalSeconds - elapsed
end

--- Determine timer state based on remaining time -- INTERNAL
---@param timer table Timer object
---@param remaining number Seconds remaining
---@return string state Timer state (WAITING, RUNNING, IMMINENT, EXPIRED)
function LoolibNoteTimerMixin:_DetermineState(timer, remaining)
    if not timer.startTime then
        return TIMER_STATES.WAITING
    elseif remaining <= 0 then
        return TIMER_STATES.EXPIRED
    elseif remaining <= 5 then
        return TIMER_STATES.IMMINENT
    else
        return TIMER_STATES.RUNNING
    end
end

--- Trigger WeakAura event (with duplicate prevention) -- INTERNAL
---@param eventName string WA event name
---@param timeleft number Seconds remaining (ceiled)
---@param timer table Timer object
---@param _node table Timer node (unused, kept for interface compat)
function LoolibNoteTimerMixin:_TriggerWeakAuraEvent(eventName, timeleft, timer, _node)
    -- Create unique cache key to prevent duplicate events
    local cacheKey = eventName .. ":" .. timeleft

    if self._waEventCache[cacheKey] then
        return  -- Already triggered this event at this time
    end

    self._waEventCache[cacheKey] = true

    -- Call custom callback if set
    if self._weakAuraCallback then
        self._weakAuraCallback(eventName, timeleft, timer)
    end
end

--[[--------------------------------------------------------------------
    Update Loop
----------------------------------------------------------------------]]

--- Start the update loop (10 updates per second) -- INTERNAL
function LoolibNoteTimerMixin:_StartUpdateLoop()
    if self._isRunning then
        return
    end

    self._isRunning = true

    if not self._updateFrame then
        self._updateFrame = CreateFrame("Frame")
    end

    local lastTick = 0
    local timerSelf = self

    self._updateFrame:SetScript("OnUpdate", function(_, elapsed)
        lastTick = lastTick + elapsed
        if lastTick >= 0.1 then  -- 10 updates per second
            lastTick = lastTick - 0.1  -- NT-06: subtract interval, don't reset to 0
            timerSelf:_OnTick()
        end
    end)
end

--- Stop the update loop -- INTERNAL
function LoolibNoteTimerMixin:_StopUpdateLoop()
    self._isRunning = false

    if self._updateFrame then
        self._updateFrame:SetScript("OnUpdate", nil)
    end
end

--- Called every tick (10 times per second) -- INTERNAL
function LoolibNoteTimerMixin:_OnTick()
    self:TriggerEvent("OnTimerTick", self:GetEncounterTime())

    -- Check for state changes
    for timerId, timer in pairs(self._activeTimers) do
        local remaining = self:_CalculateRemaining(timer)
        local newState = self:_DetermineState(timer, remaining)

        if newState ~= timer.state then
            timer.state = newState

            if newState == TIMER_STATES.IMMINENT then
                self:TriggerEvent("OnTimerImminent", timerId, timer)
            elseif newState == TIMER_STATES.EXPIRED then
                self:TriggerEvent("OnTimerExpire", timerId, timer)
            end
        end
    end
end

--[[--------------------------------------------------------------------
    Callbacks
----------------------------------------------------------------------]]

--- Set glow callback
---@param callback function Function(timerId, timer)
function LoolibNoteTimerMixin:SetGlowCallback(callback)
    if callback ~= nil and type(callback) ~= "function" then
        error("LoolibNoteTimer: SetGlowCallback: 'callback' must be a function or nil", 2)
    end
    self._glowCallback = callback
end

--- Set WeakAura event callback
---@param callback function Function(eventName, timeleft, timer)
function LoolibNoteTimerMixin:SetWeakAuraCallback(callback)
    if callback ~= nil and type(callback) ~= "function" then
        error("LoolibNoteTimer: SetWeakAuraCallback: 'callback' must be a function or nil", 2)
    end
    self._weakAuraCallback = callback
end

--[[--------------------------------------------------------------------
    Reset
----------------------------------------------------------------------]]

--- Reset all timer state
function LoolibNoteTimerMixin:Reset()
    self:EndEncounter()
    self:ClearTimers()
end

--[[--------------------------------------------------------------------
    Factory and Registration
----------------------------------------------------------------------]]

--- Create a new timer instance
---@return table timer Timer instance
local function LoolibCreateNoteTimer()
    local timer = {}
    LoolibMixin(timer, LoolibNoteTimerMixin)
    timer:OnLoad()
    return timer
end

-- Singleton timer for convenience
local defaultTimer = nil

--- Get default timer instance (singleton)
---@return table timer Singleton timer
local function LoolibGetNoteTimer()
    if not defaultTimer then
        defaultTimer = LoolibCreateNoteTimer()
    end
    return defaultTimer
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib:RegisterModule("Note.NoteTimer", {
    Mixin = LoolibNoteTimerMixin,
    Create = LoolibCreateNoteTimer,
    Get = LoolibGetNoteTimer,
    States = TIMER_STATES,
    Colors = TIMER_COLORS,
})
