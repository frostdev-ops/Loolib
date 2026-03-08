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

local Loolib = LibStub("Loolib")

-- Verify dependencies are loaded
assert(LoolibMixin, "Loolib/Core/Mixin.lua must be loaded before NoteTimer")
assert(LoolibCallbackRegistryMixin, "Loolib/Events/CallbackRegistry.lua must be loaded before NoteTimer")

--[[--------------------------------------------------------------------
    Timer States and Colors
----------------------------------------------------------------------]]

local TIMER_STATES = {
    WAITING = "WAITING",     -- Timer not started (future encounter)
    RUNNING = "RUNNING",     -- Timer counting down
    IMMINENT = "IMMINENT",   -- Less than 5 seconds remaining
    EXPIRED = "EXPIRED",     -- Timer reached 0
}

-- Timer colors by state (MRT-style coloring)
local TIMER_COLORS = {
    WAITING = "808080",      -- Gray
    RUNNING = "FFFED88",     -- Yellow (MRT style: FFED88)
    IMMINENT = "00FF00",     -- Green (MRT style - green when imminent)
    EXPIRED = "666666",      -- Dark gray
}

--[[--------------------------------------------------------------------
    LoolibNoteTimerMixin

    Manages countdown timers for encounter notes.
----------------------------------------------------------------------]]

LoolibNoteTimerMixin = {}

--- Initialize the timer system
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

    -- Set up callback registry
    LoolibMixin(self, LoolibCallbackRegistryMixin)
    CallbackRegistryMixin.OnLoad(self)
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
-- @param encounterTime number? Encounter start time (GetTime()), nil = now
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
-- @param phase number Phase number
-- @param phaseTime number? Phase start time (GetTime()), nil = now
function LoolibNoteTimerMixin:SetPhase(phase, phaseTime)
    self._currentPhase = phase
    self._phaseStartTimes[phase] = phaseTime or GetTime()
end

--- Get current encounter time elapsed
-- @return number Seconds since encounter start, or 0 if not in encounter
function LoolibNoteTimerMixin:GetEncounterTime()
    if not self._encounterStartTime then
        return 0
    end
    return GetTime() - self._encounterStartTime
end

--- Get time since phase started
-- @param phase number? Phase number (default: current phase)
-- @return number Seconds since phase start
function LoolibNoteTimerMixin:GetPhaseTime(phase)
    phase = phase or self._currentPhase
    local phaseStart = self._phaseStartTimes[phase]
    if not phaseStart then
        return 0
    end
    return GetTime() - phaseStart
end

--- Check if in active encounter
-- @return boolean
function LoolibNoteTimerMixin:IsInEncounter()
    return self._encounterStartTime ~= nil
end

--[[--------------------------------------------------------------------
    Timer Registration
----------------------------------------------------------------------]]

--- Register a timer for tracking
-- @param timerId string Unique identifier
-- @param totalSeconds number Total countdown time
-- @param options table? {phase, glow, all, wa}
-- @return table Timer info
function LoolibNoteTimerMixin:RegisterTimer(timerId, totalSeconds, options)
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
-- @param timerId string
-- @return table?
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
-- @param node table Timer AST node with {minutes, seconds, options}
-- @return string Formatted timer string
function LoolibNoteTimerMixin:RenderTimer(node)
    local totalSeconds = (node.minutes or 0) * 60 + (node.seconds or 0)
    local options = self:_ParseTimerOptions(node.options)

    -- Generate unique ID for this timer
    local timerId = totalSeconds .. "_" .. (node.options or "default")

    -- Get or create timer
    local timer = self._activeTimers[timerId]
    if not timer then
        timer = self:RegisterTimer(timerId, totalSeconds, options)
    end

    -- Calculate remaining time
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
        local timeleft = math.ceil(remaining)
        self:_TriggerWeakAuraEvent(options.wa, timeleft, timer, node)
    end

    -- Format output
    return self:FormatTimer(remaining, state)
end

--- Format timer value with color
-- @param remaining number Seconds remaining (can be negative)
-- @param state string Timer state
-- @return string Formatted string with WoW color codes
function LoolibNoteTimerMixin:FormatTimer(remaining, state)
    local color = TIMER_COLORS[state] or TIMER_COLORS.RUNNING
    local timeStr

    if remaining >= 60 then
        local minutes = math.floor(remaining / 60)
        local seconds = remaining % 60
        timeStr = string.format("%d:%02d", minutes, seconds)
    elseif remaining >= 0 then
        timeStr = string.format("%.0f", remaining)
    else
        -- Negative = expired
        timeStr = "0"
    end

    return "|cFF" .. color .. timeStr .. "|r"
end

--[[--------------------------------------------------------------------
    Internal Helpers
----------------------------------------------------------------------]]

--- Parse timer options string
-- @param optionsStr string? Comma-separated options
-- @return table Parsed options {phase, glow, all, wa}
function LoolibNoteTimerMixin:_ParseTimerOptions(optionsStr)
    local options = {}

    if not optionsStr then
        return options
    end

    -- Parse comma-separated options
    for option in optionsStr:gmatch("[^,]+") do
        option = strtrim(option)

        -- Phase: p:N or pN (e.g., "p:2", "p2")
        local phase = option:match("^p:?(%d+)$")
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
        elseif option:match("^wa:") then
            options.wa = option:match("^wa:(.+)$")
        end
    end

    return options
end

--- Calculate remaining time for a timer
-- @param timer table Timer object
-- @return number Seconds remaining
function LoolibNoteTimerMixin:_CalculateRemaining(timer)
    if not timer.startTime then
        return timer.totalSeconds
    end

    local elapsed = GetTime() - timer.startTime
    return timer.totalSeconds - elapsed
end

--- Determine timer state based on remaining time
-- @param timer table Timer object
-- @param remaining number Seconds remaining
-- @return string Timer state (WAITING, RUNNING, IMMINENT, EXPIRED)
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

--- Trigger WeakAura event (with duplicate prevention)
-- @param eventName string WA event name
-- @param timeleft number Seconds remaining (ceiled)
-- @param timer table Timer object
-- @param node table Timer node (for message)
function LoolibNoteTimerMixin:_TriggerWeakAuraEvent(eventName, timeleft, timer, node)
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

    -- Try to trigger WA event directly (MRT compatibility)
    if WeakAuras and WeakAuras.ScanEvents then
        pcall(function()
            WeakAuras.ScanEvents("LOOLIB_NOTE_TIME_EVENT", eventName, timeleft, node.message or "")
            -- Also trigger MRT-compatible event name
            WeakAuras.ScanEvents("MRT_NOTE_TIME_EVENT", eventName, timeleft, node.message or "")
        end)
    end
end

--[[--------------------------------------------------------------------
    Update Loop
----------------------------------------------------------------------]]

--- Start the update loop (10 updates per second)
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
            lastTick = 0
            timerSelf:_OnTick()
        end
    end)
end

--- Stop the update loop
function LoolibNoteTimerMixin:_StopUpdateLoop()
    self._isRunning = false

    if self._updateFrame then
        self._updateFrame:SetScript("OnUpdate", nil)
    end
end

--- Called every tick (10 times per second)
function LoolibNoteTimerMixin:_OnTick()
    self:TriggerEvent("OnTimerTick", self:GetEncounterTime())

    -- Check for state changes
    for timerId, timer in pairs(self._activeTimers) do
        local remaining = self:_CalculateRemaining(timer)
        local newState = self:_DetermineState(timer, remaining)

        if newState ~= timer.state then
            local oldState = timer.state
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
-- @param callback function Function(timerId, timer)
function LoolibNoteTimerMixin:SetGlowCallback(callback)
    self._glowCallback = callback
end

--- Set WeakAura event callback
-- @param callback function Function(eventName, timeleft, timer)
function LoolibNoteTimerMixin:SetWeakAuraCallback(callback)
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
-- @return table Timer
function LoolibCreateNoteTimer()
    local timer = {}
    LoolibMixin(timer, LoolibNoteTimerMixin)
    timer:OnLoad()
    return timer
end

-- Singleton timer for convenience
local defaultTimer = nil

--- Get default timer instance (singleton)
-- @return table Timer
function LoolibGetNoteTimer()
    if not defaultTimer then
        defaultTimer = LoolibCreateNoteTimer()
    end
    return defaultTimer
end

--[[--------------------------------------------------------------------
    Exports
----------------------------------------------------------------------]]

-- Export constants
LoolibNoteTimerStates = TIMER_STATES
LoolibNoteTimerColors = TIMER_COLORS

-- Register with Loolib
Loolib:RegisterModule("NoteTimer", {
    Mixin = LoolibNoteTimerMixin,
    Create = LoolibCreateNoteTimer,
    Get = LoolibGetNoteTimer,
    States = TIMER_STATES,
    Colors = TIMER_COLORS,
})
