--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    AddonMessage - Addon communication system

    Provides AceComm-compatible addon messaging with automatic message
    splitting, reassembly, priority queuing, and throttling.

    Features:
    - Register prefixes and receive callbacks
    - Automatic splitting of messages > 255 bytes
    - Multi-part message reassembly with timestamp-based stale cleanup
    - Priority queue (ALERT, NORMAL, BULK) via O(1) FIFO ring buffers
    - Throttling at 800 B/s (ChatThrottleLib-proven safe rate)
    - FPS-aware replenishment and login ramp throttle
    - Bypass traffic tracking via hooksecurefunc
    - Backpressure API: IsQueueFull(), GetQueuePressure()
----------------------------------------------------------------------]]

local LibStub = LibStub
local assert = assert
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local C_ChatInfo = C_ChatInfo
local Enum = Enum
local error = error
local GetFramerate = GetFramerate
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local math = math
local next = next
local pairs = pairs
local pcall = pcall
local string = string
local table = table
local tostring = tostring
local type = type
local wipe = wipe

local Loolib = LibStub("Loolib")
-- FIX(critical-01): Use Loolib.Mixin/CreateFromMixins directly instead of unstable module lookup
local ApplyMixins = assert(Loolib.Mixin,
    "Loolib.Mixin must be loaded before Comm/AddonMessage.lua")
local CreateFromMixins = assert(Loolib.CreateFromMixins,
    "Loolib.CreateFromMixins must be loaded before Comm/AddonMessage.lua")
local Comm = Loolib.Comm or Loolib:GetOrCreateModule("Comm")

Loolib.Comm = Comm

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

local CommMixin = {}

-- Maximum message size for addon channel
local MAX_MESSAGE_SIZE = 255

-- WoW protocol overhead per SendAddonMessage call (header, framing, etc.)
local MSG_OVERHEAD = 40

-- Control bytes for message splitting protocol
local CTRL_SINGLE = "\001"    -- Single message (no splitting needed)
local CTRL_FIRST  = "\002"    -- First part of multi-part message
local CTRL_MIDDLE = "\003"    -- Middle part of multi-part message
local CTRL_LAST   = "\004"    -- Last part of multi-part message

-- Priority levels
local PRIORITY_ALERT  = "ALERT"    -- Immediate; drains past budget limit
local PRIORITY_NORMAL = "NORMAL"   -- Default; stops when budget exhausted
local PRIORITY_BULK   = "BULK"     -- Low priority; 4x cost against budget

-- Throttle settings
local THROTTLE_RATE        = 800    -- Safe base rate: 800 B/s (ChatThrottleLib proven value)
local THROTTLE_BURST       = 4000   -- Burst allowance in bytes
local THROTTLE_BULK_DIVISOR = 4    -- BULK messages count 4x against budget
local LOGIN_THROTTLE_RATE  = 80     -- 10% rate during login ramp
local LOGIN_RAMP_DURATION  = 5      -- Seconds at reduced rate after PLAYER_ENTERING_WORLD
local FPS_LOW_THRESHOLD    = 20     -- FPS below this halves replenishment
local THROTTLE_PAUSE_DURATION = 0.35 -- Pause after AddonMessageThrottle result (seconds)

-- Queue limits
local MAX_QUEUE_SIZE = 500          -- Drop BULK when exceeded; warn for NORMAL

-- OnUpdate gating
local ONUPDATE_INTERVAL = 0.08      -- 80 ms minimum between ProcessSendQueue runs

-- Pending message cleanup
local CLEANUP_INTERVAL  = 30        -- Seconds between cleanup sweeps
local PENDING_MAX_AGE   = 60        -- Default max age for incomplete multi-part messages

-- Message ID counter — randomized at load to reduce post-reload ID correlation
local messageIDCounter = math.random(1, 65535)

--[[--------------------------------------------------------------------
    FIFO Ring Buffer
----------------------------------------------------------------------]]

local function CreateFIFO()
    local fifo = {
        _buf  = {},
        _head = 1,
        _tail = 0,
        _size = 0,
    }

    function fifo:Push(item)
        self._tail = self._tail + 1
        self._buf[self._tail] = item
        self._size = self._size + 1
    end

    function fifo:Peek()
        if self._size == 0 then return nil end
        return self._buf[self._head]
    end

    function fifo:Pop()
        if self._size == 0 then return nil end
        local item = self._buf[self._head]
        self._buf[self._head] = nil
        self._head = self._head + 1
        self._size = self._size - 1
        -- Compact when empty to prevent unbounded growth of _buf
        if self._size == 0 then
            self._head = 1
            self._tail = 0
        end
        return item
    end

    function fifo:Size()
        return self._size
    end

    function fifo:Reset()
        wipe(self._buf)
        self._head = 1
        self._tail = 0
        self._size = 0
    end

    return fifo
end

--[[--------------------------------------------------------------------
    Internal State
----------------------------------------------------------------------]]

-- Registered prefixes and their callbacks: prefix -> {callback, owner}
local registeredPrefixes = {}

-- Pending multi-part messages: sender -> { prefix -> {id, parts, startTime} }
local pendingMessages = {}

-- Priority queues (FIFO ring buffers)
local queues = {
    ALERT  = CreateFIFO(),
    NORMAL = CreateFIFO(),
    BULK   = CreateFIFO(),
}

-- Total queued messages across all queues (maintained for O(1) pressure check)
local totalQueued = 0

-- Throttle state
local throttleAvailable  = THROTTLE_BURST
local lastThrottleUpdate = 0
local loginRampActive    = false
local loginRampEnd       = 0
local throttlePauseUntil = 0    -- GetTime() epoch to resume after throttle error

-- Flag: true while we are sending via ProcessSendQueue (for bypass tracking)
local ourOwnSend = false

-- Communication frame for events and OnUpdate
local commFrame = nil

-- OnUpdate accumulators
local onUpdateAccumulator = 0
local ALERT_MAX_PER_TICK = 8

--[[--------------------------------------------------------------------
    Internal Helper Functions
----------------------------------------------------------------------]]

local function GenerateMessageID()
    messageIDCounter = messageIDCounter + 1
    if messageIDCounter > 65535 then
        messageIDCounter = 1
    end
    -- 4 hex chars: 65K IDs, same header size as before
    return string.format("%04X", messageIDCounter)
end

local function GetEffectiveThrottleRate()
    local now = GetTime()
    local rate = THROTTLE_RATE

    -- Login ramp: 10% of normal rate for LOGIN_RAMP_DURATION seconds after login
    if loginRampActive then
        if now < loginRampEnd then
            rate = LOGIN_THROTTLE_RATE
        else
            loginRampActive = false
        end
    end

    -- FPS-aware: halve replenishment when framerate is poor
    local fps = GetFramerate()
    if fps > 0 and fps < FPS_LOW_THRESHOLD then
        rate = rate * 0.5
    end

    return rate
end

local function GetThrottleAllowance()
    local now = GetTime()
    local elapsed = now - lastThrottleUpdate
    lastThrottleUpdate = now
    throttleAvailable = math.min(THROTTLE_BURST, throttleAvailable + elapsed * GetEffectiveThrottleRate())
    return throttleAvailable
end

local function ConsumeThrottle(amount)
    throttleAvailable = throttleAvailable - amount
end

local function SplitMessage(text)
    local messages = {}
    local textLen  = #text

    if textLen <= MAX_MESSAGE_SIZE - 1 then
        messages[1] = CTRL_SINGLE .. text
        return messages
    end

    -- Multi-part: prefix each chunk with control byte + 4-char hex ID
    local msgID     = GenerateMessageID()
    local headerSz  = 1 + 4  -- control byte (1) + hex ID (4)
    local chunkSz   = MAX_MESSAGE_SIZE - headerSz
    local pos       = 1
    local partNum   = 1

    while pos <= textLen do
        local chunk     = text:sub(pos, pos + chunkSz - 1)
        local remaining = textLen - pos - #chunk + 1

        if partNum == 1 then
            messages[partNum] = CTRL_FIRST .. msgID .. chunk
        elseif remaining <= 0 then
            messages[partNum] = CTRL_LAST  .. msgID .. chunk
        else
            messages[partNum] = CTRL_MIDDLE .. msgID .. chunk
        end

        pos     = pos + #chunk
        partNum = partNum + 1
    end

    return messages
end

local function AssembleMessage(sender, prefix, ctrlByte, msgID, content)
    if ctrlByte == CTRL_SINGLE then
        return content, true
    end

    -- Initialize storage for this sender/prefix
    if not pendingMessages[sender] then
        pendingMessages[sender] = {}
    end
    if not pendingMessages[sender][prefix] then
        pendingMessages[sender][prefix] = {}
    end

    local pending = pendingMessages[sender][prefix]

    if ctrlByte == CTRL_FIRST then
        -- Start new multi-part message
        pending.id        = msgID
        pending.parts     = { content }
        pending.startTime = GetTime()
        pending.complete  = false
        return nil, false
    end

    -- Mismatched ID: the previous partial was interleaved/corrupted — discard
    if pending.id ~= msgID then
        if pending.id then
            Loolib:Debug("AddonMessage: discarded partial message from",
                sender, "prefix=" .. prefix,
                "old_id=" .. tostring(pending.id), "new_id=" .. msgID)
        end
        pending.id        = msgID
        pending.parts     = {}
        pending.startTime = GetTime()
        pending.complete  = false
        return nil, false
    end

    pending.parts[#pending.parts + 1] = content

    if ctrlByte == CTRL_LAST then
        local fullMessage = table.concat(pending.parts)
        pending.id        = nil
        pending.parts     = {}
        pending.complete  = false
        return fullMessage, true
    end

    return nil, false
end

local function CleanupStalePending(maxAge)
    maxAge = maxAge or PENDING_MAX_AGE
    local now    = GetTime()
    local cutoff = now - maxAge

    for sender, prefixTable in pairs(pendingMessages) do
        for prefix, pending in pairs(prefixTable) do
            if pending.startTime and pending.startTime < cutoff then
                Loolib:Debug("AddonMessage: purging stale partial message from",
                    sender, "prefix=" .. prefix,
                    string.format("age=%.1fs", now - pending.startTime))
                prefixTable[prefix] = nil
            end
        end
        if not next(prefixTable) then
            pendingMessages[sender] = nil
        end
    end
end

local function ProcessReceivedMessage(prefix, text, distribution, sender)
    if #text < 1 then return end

    local ctrlByte = text:sub(1, 1)
    local content

    if ctrlByte == CTRL_SINGLE then
        content = text:sub(2)
    else
        if #text < 5 then return end
        local msgID      = text:sub(2, 5)
        local msgContent = text:sub(6)

        local assembled, complete = AssembleMessage(sender, prefix, ctrlByte, msgID, msgContent)
        if not complete then return end
        content = assembled
    end

    local registration = registeredPrefixes[prefix]
    if registration and registration.callback then
        local ok, err = pcall(registration.callback, prefix, content, distribution, sender)
        if not ok then
            Loolib:Error("Comm callback error for prefix", prefix, ":", err)
        end
    end
end

local function EnqueueItem(item)
    local queue = queues[item.prio] or queues.NORMAL
    queue:Push(item)
    totalQueued = totalQueued + 1

    -- Wake the frame when it was idle
    if commFrame and not commFrame:IsShown() then
        commFrame:Show()
    end
end

local function ProcessSendQueue()
    local now = GetTime()

    -- Respect throttle pause (WoW told us we're sending too fast)
    if now < throttlePauseUntil then return end

    if totalQueued == 0 then
        if commFrame then commFrame:Hide() end
        return
    end

    local allowance = GetThrottleAllowance()

    -- tryDrain: drain messages from a queue respecting budget constraints.
    -- ignoreBudget=true (ALERT): send regardless of allowance.
    -- isBulk=true (BULK): each message costs 4x against budget.
    local function tryDrain(queue, isBulk, ignoreBudget, maxMessages)
        local drained = 0
        while queue:Size() > 0 do
            local item      = queue:Peek()
            local msgLen    = #item.text + MSG_OVERHEAD
            local effectLen = isBulk and (msgLen * THROTTLE_BULK_DIVISOR) or msgLen

            -- Stop draining if budget exhausted (unless ignoreBudget)
            if not ignoreBudget and effectLen > allowance then return end

            queue:Pop()
            totalQueued = totalQueued - 1

            -- Attempt send and detect throttle result
            ourOwnSend = true
            local ok, result = pcall(C_ChatInfo.SendAddonMessage,
                item.prefix, item.text, item.distribution, item.target)
            ourOwnSend = false

            local isThrottled = ok and
                (result == Enum.SendAddonMessageResult.AddonMessageThrottle)

            if not ok or isThrottled then
                -- Re-queue for retry and pause
                queue:Push(item)
                totalQueued = totalQueued + 1
                throttlePauseUntil = now + THROTTLE_PAUSE_DURATION
                if not ok then
                    Loolib:Error("AddonMessage: SendAddonMessage error:", result)
                end
                return
            end

            ConsumeThrottle(effectLen)
            allowance = allowance - effectLen

            if item.callback then
                pcall(item.callback, item.arg, #item.text)
            end

            drained = drained + 1
            if maxMessages and drained >= maxMessages then
                return
            end
        end
    end

    -- Drain order: ALERT (all, ignores budget) → NORMAL → BULK
    tryDrain(queues.ALERT,  false, true, ALERT_MAX_PER_TICK)
    if allowance > 0 then tryDrain(queues.NORMAL, false, false) end
    if allowance > 0 then tryDrain(queues.BULK,   true,  false) end

    if totalQueued == 0 and commFrame then
        commFrame:Hide()
    end
end

--[[--------------------------------------------------------------------
    Event Handling
----------------------------------------------------------------------]]

local function OnAddonMessage(prefix, text, distribution, sender)
    if not registeredPrefixes[prefix] then return end
    ProcessReceivedMessage(prefix, text, distribution, sender)
end

local function OnUpdate(self, elapsed)
    onUpdateAccumulator = onUpdateAccumulator + elapsed

    if onUpdateAccumulator >= ONUPDATE_INTERVAL then
        onUpdateAccumulator = 0
        ProcessSendQueue()
    end
end

local function InitializeCommFrame()
    if commFrame then return end

    commFrame = CreateFrame("Frame")
    commFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_ADDON" then
            OnAddonMessage(...)
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Activate login throttle ramp for LOGIN_RAMP_DURATION seconds
            loginRampActive = true
            loginRampEnd    = GetTime() + LOGIN_RAMP_DURATION
        end
    end)
    commFrame:SetScript("OnUpdate", OnUpdate)
    commFrame:RegisterEvent("CHAT_MSG_ADDON")
    commFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Track bypass traffic from other addons; subtract from our budget so we
    -- don't over-send when other addons are also using the channel.
    hooksecurefunc(C_ChatInfo, "SendAddonMessage", function(_, message, _, _)
        if not ourOwnSend then
            -- Another addon sent a message; reduce our available budget.
            throttleAvailable = math.max(0,
                throttleAvailable - (#message + MSG_OVERHEAD))
        end
    end)

    commFrame.cleanupTicker = commFrame.cleanupTicker or C_Timer.NewTicker(CLEANUP_INTERVAL, function()
        CleanupStalePending()
    end)

    -- Start hidden; shown on first enqueue
    commFrame:Hide()
end

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

--- Initialize the comm system (called automatically on first use)
function CommMixin:Init()
    InitializeCommFrame()
end

--- Register a prefix for receiving addon messages
-- @param prefix string - Addon message prefix (1-16 characters)
-- @param callback function - function(prefix, message, distribution, sender)
-- @param owner any - Optional owner for the callback
function CommMixin:RegisterComm(prefix, callback, owner)
    if type(prefix) ~= "string" or #prefix < 1 or #prefix > 16 then
        error("RegisterComm: prefix must be a string of 1-16 characters", 2)
    end
    if type(callback) ~= "function" then
        error("RegisterComm: callback must be a function", 2)
    end

    InitializeCommFrame()

    local success = C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    if not success then
        Loolib:Debug("Prefix already registered or limit reached:", prefix)
    end

    registeredPrefixes[prefix] = { callback = callback, owner = owner }
end

--- Unregister a prefix
-- @param prefix string
function CommMixin:UnregisterComm(prefix)
    registeredPrefixes[prefix] = nil
end

--- Check if a prefix is registered
-- @param prefix string
-- @return boolean
function CommMixin:IsCommRegistered(prefix)
    return registeredPrefixes[prefix] ~= nil
end

--- Send an addon message (queued, throttled, split if needed)
-- @param prefix string - Registered prefix
-- @param text string - Message content (split automatically if > 255 bytes)
-- @param distribution string - "PARTY", "RAID", "GUILD", "WHISPER", "INSTANCE_CHAT"
-- @param target string|nil - Player name (for WHISPER)
-- @param prio string|nil - "ALERT", "NORMAL" (default), or "BULK"
-- @param callbackFn function|nil - Called after each part is sent: callback(arg, bytesSent)
-- @param callbackArg any - Argument passed to callback
-- @return boolean - true if queued, false if dropped due to queue full
function CommMixin:SendCommMessage(prefix, text, distribution, target, prio, callbackFn, callbackArg)
    if type(prefix) ~= "string" then
        error("SendCommMessage: prefix must be a string", 2)
    end
    if type(text) ~= "string" then
        error("SendCommMessage: text must be a string", 2)
    end
    if type(distribution) ~= "string" then
        error("SendCommMessage: distribution must be a string", 2)
    end

    InitializeCommFrame()

    local validDist = {
        PARTY = true, RAID = true, GUILD = true,
        WHISPER = true, CHANNEL = true, INSTANCE_CHAT = true,
    }
    if not validDist[distribution] then
        error("SendCommMessage: invalid distribution: " .. distribution, 2)
    end
    if distribution == "WHISPER" and (not target or target == "") then
        error("SendCommMessage: WHISPER distribution requires target", 2)
    end

    prio = prio or PRIORITY_NORMAL
    if not queues[prio] then prio = PRIORITY_NORMAL end

    -- Backpressure: drop BULK messages when queue is full; warn for NORMAL
    local currentSize = totalQueued
    if currentSize >= MAX_QUEUE_SIZE then
        if prio == PRIORITY_BULK then
            Loolib:Debug("AddonMessage: queue full, dropping BULK message for prefix", prefix)
            return false
        else
            Loolib:Debug("AddonMessage: queue near capacity (" ..
                currentSize .. "/" .. MAX_QUEUE_SIZE .. ") for prefix", prefix)
        end
    end

    local messages = SplitMessage(text)
    for _, msg in ipairs(messages) do
        EnqueueItem({
            prefix       = prefix,
            text         = msg,
            distribution = distribution,
            target       = target,
            prio         = prio,
            callback     = callbackFn,
            arg          = callbackArg,
        })
    end

    return true
end

--- Send an addon message immediately, bypassing the throttle queue.
-- Only for ALERT-priority single-part messages that must go out this frame.
-- @param prefix string - Registered prefix
-- @param text string - Message content (must fit in one packet, ≤ 254 bytes)
-- @param distribution string - Distribution channel
-- @param target string|nil - Target for WHISPER
function CommMixin:SendCommMessageInstant(prefix, text, distribution, target)
    if #text > MAX_MESSAGE_SIZE - 1 then
        error("SendCommMessageInstant: message too long for instant send", 2)
    end
    ourOwnSend = true
    C_ChatInfo.SendAddonMessage(prefix, CTRL_SINGLE .. text, distribution, target)
    ourOwnSend = false
end

--- Get the total number of queued messages across all priority queues
-- @return number
function CommMixin:GetQueuedMessageCount()
    return totalQueued
end

--- Clear all queued messages
function CommMixin:ClearSendQueue()
    queues.ALERT:Reset()
    queues.NORMAL:Reset()
    queues.BULK:Reset()
    totalQueued = 0
    if commFrame then commFrame:Hide() end
end

--- Clear queued messages for a specific prefix
-- @param prefix string
function CommMixin:ClearSendQueueForPrefix(prefix)
    local function clearQueue(queue)
        local kept    = CreateFIFO()
        local removed = 0
        while queue:Size() > 0 do
            local item = queue:Pop()
            if item.prefix == prefix then
                removed = removed + 1
            else
                kept:Push(item)
            end
        end
        while kept:Size() > 0 do
            queue:Push(kept:Pop())
        end
        return removed
    end

    local removed = clearQueue(queues.ALERT)
                  + clearQueue(queues.NORMAL)
                  + clearQueue(queues.BULK)
    totalQueued = totalQueued - removed
    if totalQueued == 0 and commFrame then commFrame:Hide() end
end

--- Get current throttle state
-- @return number, number - Available bytes, max burst bytes
function CommMixin:GetThrottleState()
    GetThrottleAllowance()  -- Update available
    return throttleAvailable, THROTTLE_BURST
end

--- Clean up stale incomplete multi-part messages
-- @param maxAge number - Maximum age in seconds (default 60)
function CommMixin:CleanupPendingMessages(maxAge)
    CleanupStalePending(maxAge)
end

--- Check if the send queue is at capacity (BULK messages will be dropped)
-- @return boolean
function CommMixin:IsQueueFull()
    return totalQueued >= MAX_QUEUE_SIZE
end

--- Get current queue pressure as a ratio from 0.0 (empty) to 1.0 (full)
-- @return number
function CommMixin:GetQueuePressure()
    return math.min(1.0, totalQueued / MAX_QUEUE_SIZE)
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new Comm instance
-- @return table - A new Comm object
local function CreateComm()
    local comm = CreateFromMixins(CommMixin)
    comm.Priority = Comm.Priority
    comm.PRIORITY = Comm.Priority
    comm:Init()
    return comm
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

ApplyMixins(Comm, CommMixin)

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local priority = Comm.Priority or Comm.PRIORITY or {}

priority.ALERT = PRIORITY_ALERT
priority.NORMAL = PRIORITY_NORMAL
priority.BULK = PRIORITY_BULK

Loolib.Comm.Mixin = CommMixin
Loolib.Comm.Create = CreateComm
Loolib.Comm.Instance = Comm
Loolib.Comm.Comm = Comm
Loolib.Comm.AddonMessage = Comm
Loolib.Comm.Priority = priority
Loolib.Comm.PRIORITY = priority
Loolib.Comm.PRIORITY_ALERT = PRIORITY_ALERT
Loolib.Comm.PRIORITY_NORMAL = PRIORITY_NORMAL
Loolib.Comm.PRIORITY_BULK = PRIORITY_BULK

Loolib:RegisterModule("Comm", Comm)
Loolib:RegisterModule("AddonMessage", Comm)
