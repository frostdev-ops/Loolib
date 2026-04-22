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
-- Use Loolib.Mixin/CreateFromMixins directly (module aliases can shift during load order)
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

-- Message-count budget (aligned with WoW's addon-channel throttle).
-- WoW's SendAddonMessage channel allows ~10 burst messages then ~1/sec steady.
-- We leave 2-token headroom for bypass traffic from DBM/WA/BigWigs sharing the
-- channel. The byte budget above is not sufficient on its own — a burst of
-- small messages at 50-100 bytes can send 30+ in one tick under byte-rate
-- alone, which WoW will then throttle with AddOnMessageThrottle errors.
local MSG_BUDGET_BURST     = 8       -- Burst capacity (messages)
local MSG_BUDGET_RATE      = 1.0     -- Refill rate (messages / second)

-- Queue limits
local MAX_QUEUE_SIZE = 500          -- Drop BULK when exceeded; warn for NORMAL

-- OnUpdate gating
local ONUPDATE_INTERVAL = 0.08      -- 80 ms minimum between ProcessSendQueue runs

-- Pending message cleanup
local CLEANUP_INTERVAL  = 30        -- Seconds between cleanup sweeps

-- Human-readable names for SendAddonMessageResult enum values (WoW 12.0 PTR)
local RESULT_NAMES = {
    [0]  = "Success",              [1]  = "InvalidPrefix",
    [2]  = "InvalidMessage",       [3]  = "AddonMessageThrottle",
    [4]  = "InvalidChatType",      [5]  = "NotInGroup",
    [6]  = "TargetRequired",       [7]  = "InvalidChannel",
    [8]  = "ChannelThrottle",      [9]  = "GeneralError",
    [10] = "NotInGuild",           [11] = "AddOnMessageLockdown",
    [12] = "TargetOffline",
}
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

-- Pending multi-part messages: senderKey -> { prefix -> {id, parts, startTime, origSender} }
-- senderKey is string.lower(sender). The WoW chat server does not guarantee
-- stable casing of the sender string across a multi-part stream (e.g.,
-- "Name-Realm" on one packet and "Name-realm" on another), so keying by the
-- raw sender would split one physical stream across two buckets and lose
-- parts. origSender preserves the first-seen casing for diagnostic logs.
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

-- Message-count token bucket (separate from byte budget)
local msgTokens          = MSG_BUDGET_BURST
local lastMsgTokenUpdate = 0
local msgCoalesced       = 0   -- Diag counter: how many enqueues were collapsed into prior queued items

-- Outbound coalesce index: prefix|key -> queued item. Used to mark earlier
-- queued copies of idempotent state (MLDB, council roster, heartbeat, etc.)
-- as superseded when a newer copy is enqueued. Drain skips superseded items.
-- Only single-part messages are coalesced to avoid tearing multi-part streams.
local coalesceIndex = {}

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

-- Normalize a CHAT_MSG_ADDON sender string to a stable reassembly key.
-- The chat server can deliver the same physical sender with inconsistent
-- realm-part casing across a multi-part stream — e.g., "Name-Realm" and
-- "Name-realm" for consecutive parts of one broadcast. Keying the
-- pendingMessages buffer by the raw sender would split such a stream
-- across two buckets and silently drop the tail.
--
-- Strategy: split on the first "-" and lowercase each segment. WoW realm
-- slugs are always ASCII (they appear in HTTP URLs), so string.lower is
-- lossless on them. Character name casing is stable from Blizzard's
-- name service, but we lowercase the name segment as well for defense
-- in depth; string.lower is a safe no-op on non-ASCII bytes, so Cyrillic /
-- Hangul / Han characters pass through unchanged. Edge case: on a
-- non-English realm where the name portion contains mixed-case Latin-1
-- (ä, Ä), casing drift on the name won't collapse — accepted as a rare
-- and low-impact limitation.
local function NormalizeSenderKey(sender)
    if type(sender) ~= "string" or sender == "" then return "" end
    local name, realm = sender:match("^([^-]+)-(.+)$")
    if name and realm then
        return name:lower() .. "-" .. realm:lower()
    end
    return sender:lower()
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

local function GetMsgTokens()
    local now = GetTime()
    local elapsed = now - lastMsgTokenUpdate
    lastMsgTokenUpdate = now
    msgTokens = math.min(MSG_BUDGET_BURST, msgTokens + elapsed * MSG_BUDGET_RATE)
    return msgTokens
end

local function ConsumeMsgToken()
    msgTokens = msgTokens - 1
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

    -- Key the reassembly buffer by the normalized sender so server-side
    -- casing drift across consecutive parts cannot split one stream across
    -- two buckets. The original sender is preserved on the bucket for logs
    -- and passed through unchanged to consumer callbacks.
    local senderKey = NormalizeSenderKey(sender)

    if not pendingMessages[senderKey] then
        pendingMessages[senderKey] = {}
    end
    if not pendingMessages[senderKey][prefix] then
        pendingMessages[senderKey][prefix] = {}
    end

    local pending = pendingMessages[senderKey][prefix]

    if ctrlByte == CTRL_FIRST then
        -- A new FIRST arriving while a prior partial is still in flight
        -- for this sender+prefix means we lost the tail of that prior
        -- stream (dropped LAST, reorder, or SplitMessage race). Log the
        -- overlap so the failure is greppable in live-raid diagnostics,
        -- then overwrite with the new stream.
        if pending.id then
            Loolib:Debug("AddonMessage: [REASM_OVERLAP] discarded incomplete prior stream from",
                sender, "prefix=" .. prefix,
                "old_id=" .. tostring(pending.id),
                "new_id=" .. msgID,
                "prior_parts=" .. tostring(pending.parts and #pending.parts or 0))
        end
        pending.id         = msgID
        pending.parts      = { content }
        pending.startTime  = GetTime()
        pending.origSender = sender
        return nil, false
    end

    -- CTRL_MIDDLE or CTRL_LAST reaches here. Require a matching prior FIRST.

    if not pending.id then
        -- Orphan part: no FIRST was seen for this sender+prefix, or a
        -- prior stream was purged/cleared. Adopting this part's id would
        -- lead to truncated reassembly on the next LAST. Reject, log,
        -- and delete the empty bucket so an orphan-LAST flood cannot
        -- leak storage.
        Loolib:Debug("AddonMessage: [REASM_ORPHAN] dropped part without prior FIRST from",
            sender, "prefix=" .. prefix,
            "ctrl=" .. tostring(ctrlByte and ctrlByte:byte() or "?"),
            "msgID=" .. msgID)
        pendingMessages[senderKey][prefix] = nil
        return nil, false
    end

    if pending.id ~= msgID then
        -- Mid-stream id divergence. The prior stream lost its LAST or two
        -- streams are overlapping on the same sender+prefix (very rare —
        -- SplitMessage is serial per SendCommMessage). Drop the prior
        -- partial AND this non-FIRST part. Do NOT adopt the new id from
        -- a MIDDLE/LAST; without a FIRST we have no starting content and
        -- any subsequent LAST tagged with this id would produce the exact
        -- silent-truncation bug this fix targets. Wait for a real FIRST.
        Loolib:Debug("AddonMessage: [REASM_ID_MISMATCH] discarded partial from",
            sender, "prefix=" .. prefix,
            "old_id=" .. tostring(pending.id),
            "new_id=" .. msgID,
            "prior_parts=" .. tostring(#pending.parts))
        pendingMessages[senderKey][prefix] = nil
        return nil, false
    end

    pending.parts[#pending.parts + 1] = content

    if ctrlByte == CTRL_LAST then
        local fullMessage = table.concat(pending.parts)
        pendingMessages[senderKey][prefix] = nil
        return fullMessage, true
    end

    return nil, false
end

local function CleanupStalePending(maxAge)
    maxAge = maxAge or PENDING_MAX_AGE
    local now    = GetTime()
    local cutoff = now - maxAge

    for senderKey, prefixTable in pairs(pendingMessages) do
        for prefix, pending in pairs(prefixTable) do
            if pending.startTime and pending.startTime < cutoff then
                Loolib:Debug("AddonMessage: [REASM_STALE] purging partial message from",
                    pending.origSender or senderKey, "prefix=" .. prefix,
                    string.format("age=%.1fs", now - pending.startTime),
                    "parts=" .. tostring(pending.parts and #pending.parts or 0))
                prefixTable[prefix] = nil
            end
        end
        if not next(prefixTable) then
            pendingMessages[senderKey] = nil
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

    -- Note: combat lockdown does NOT block addon messages (only encounter/challenge
    -- restrictions do). ProcessSendQueue runs freely during combat.

    if totalQueued == 0 then
        if commFrame then commFrame:Hide() end
        return
    end

    local allowance = GetThrottleAllowance()
    GetMsgTokens()  -- refill message-count bucket based on elapsed time

    -- tryDrain: drain messages from a queue respecting budget constraints.
    -- ignoreBudget=true (ALERT): send regardless of byte AND message-count budget.
    -- isBulk=true (BULK): each message costs 4x against the byte budget.
    local function tryDrain(queue, isBulk, ignoreBudget, maxMessages)
        local drained = 0
        while queue:Size() > 0 do
            local item = queue:Peek()

            -- Skip superseded (coalesced) items silently. A newer message for
            -- the same (prefix, coalesceKey) replaced this one while it was
            -- still queued. Pop and continue; don't consume budget, don't fire
            -- the callback — the caller's intent is fulfilled by the newer item.
            if item.coalesced then
                queue:Pop()
                totalQueued = totalQueued - 1
                -- Continue to next item; no budget check needed
            else

            local msgLen    = #item.text + MSG_OVERHEAD
            local effectLen = isBulk and (msgLen * THROTTLE_BULK_DIVISOR) or msgLen

            -- Stop draining if budget exhausted (unless ignoreBudget).
            -- Both the byte budget AND the message-count budget must permit it;
            -- WoW's channel enforces a per-message-count throttle that the byte
            -- budget alone does not model (small messages would burst-drain).
            if not ignoreBudget then
                if effectLen > allowance then return end
                if msgTokens < 1 then return end
            end

            queue:Pop()
            totalQueued = totalQueued - 1

            -- Pre-validate distribution vs current group state. Sending to a
            -- group channel we're no longer in returns result=9 (GeneralError)
            -- instead of a clean NotInGroup, which spams the error frame.
            -- Drop silently: by the time the queue drains, if we've left the
            -- raid the message is irrelevant anyway.
            -- WHISPER/CHANNEL also require a non-empty target.
            local dist = item.distribution
            local distInvalid = false
            if dist == "RAID" and not IsInRaid() then
                distInvalid = true
            elseif dist == "PARTY" and (not IsInGroup() or IsInRaid()) then
                -- IsInGroup() is true for both party and raid; WoW rejects
                -- PARTY-channel sends while in a raid with NotInGroup/GeneralError.
                distInvalid = true
            elseif dist == "INSTANCE_CHAT" and not IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
                distInvalid = true
            elseif dist == "GUILD" and not IsInGuild() then
                distInvalid = true
            elseif (dist == "WHISPER" or dist == "CHANNEL")
                and (not item.target or item.target == "") then
                distInvalid = true
            end

            if distInvalid then
                -- Drop without consuming throttle (no wire bytes sent) and
                -- signal the caller with bytesSent=0 so any caller tracking
                -- delivery for accounting/retry purposes can distinguish a
                -- drop from a successful send. Also drop the coalesce-index
                -- entry so a future send with the same key is treated as a
                -- fresh enqueue, not a supersede of a now-dead item.
                if item.coalesceKey and coalesceIndex[item.coalesceKey] == item then
                    coalesceIndex[item.coalesceKey] = nil
                end
                if item.callback then
                    pcall(item.callback, item.arg, 0)
                end
                drained = drained + 1
                if maxMessages and drained >= maxMessages then
                    return
                end
                -- Continue draining the queue. We did NOT call ConsumeThrottle
                -- because no actual SendAddonMessage occurred.
            else

            -- Attempt send and check result
            ourOwnSend = true
            local ok, result = pcall(C_ChatInfo.SendAddonMessage,
                item.prefix, item.text, item.distribution, item.target)
            ourOwnSend = false

            if not ok then
                -- Lua error calling the API — re-queue and pause
                queue:Push(item)
                totalQueued = totalQueued + 1
                throttlePauseUntil = now + THROTTLE_PAUSE_DURATION
                Loolib:Error("AddonMessage: SendAddonMessage pcall error:", result)
                return
            end

            -- Check all non-success results from C_ChatInfo.SendAddonMessage.
            -- WoW 12.0 returns Enum.SendAddonMessageResult; older builds may return nil/true.
            local SendResult = Enum and Enum.SendAddonMessageResult
            local isSuccess = (result == nil)
                or (result == true)
                or (SendResult and result == SendResult.Success)

            if not isSuccess then
                local isThrottled = SendResult
                    and result == SendResult.AddonMessageThrottle
                local isLockdown = SendResult
                    and result == SendResult.AddOnMessageLockdown

                if isThrottled or isLockdown then
                    -- Re-queue for retry after a pause
                    queue:Push(item)
                    totalQueued = totalQueued + 1
                    throttlePauseUntil = now + THROTTLE_PAUSE_DURATION
                    return
                end

                -- Non-recoverable error (InvalidPrefix, NotInGroup, etc.)
                -- Log and discard — re-queuing won't help
                local resultName = RESULT_NAMES[result] or "Unknown"
                Loolib:Error("AddonMessage: SendAddonMessage failed —",
                    "prefix=" .. tostring(item.prefix),
                    "dist=" .. tostring(item.distribution),
                    "target=" .. tostring(item.target),
                    "result=" .. tostring(result) .. " (" .. resultName .. ")")
                -- fall through to consume and continue
            end

            ConsumeThrottle(effectLen)
            allowance = allowance - effectLen
            ConsumeMsgToken()

            -- Mark item as sent and drop its coalesce-index entry so a later
            -- enqueue with the same key is treated as a fresh send, not a
            -- supersede of an already-transmitted message.
            item.sent = true
            if item.coalesceKey and coalesceIndex[item.coalesceKey] == item then
                coalesceIndex[item.coalesceKey] = nil
            end

            if item.callback then
                pcall(item.callback, item.arg, #item.text)
            end

            drained = drained + 1
            if maxMessages and drained >= maxMessages then
                return
            end
            end -- end else (valid distribution branch)
            end -- end else (non-coalesced branch)
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

-- Track whether the bypass-traffic secure hook has been installed.
-- hooksecurefunc cannot be uninstalled, so we install it exactly once per
-- Lua state regardless of how many Init/Shutdown cycles run.
local sendHookInstalled = false

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
    -- don't over-send when other addons are also using the channel. Install
    -- exactly once per Lua state — hooksecurefunc has no uninstall API, so
    -- doing this on every re-Init would stack duplicate hooks.
    if not sendHookInstalled then
        hooksecurefunc(C_ChatInfo, "SendAddonMessage", function(_, message, _, _)
            if not ourOwnSend then
                -- Another addon sent a message; reduce our available byte
                -- budget. Floored at 0 intentionally: bytes are spent on the
                -- wire, we never expect them back.
                throttleAvailable = math.max(0,
                    throttleAvailable - (#message + MSG_OVERHEAD))
                -- Message-count consumption: do NOT floor at 0. ConsumeMsgToken
                -- (our own sends) allows msgTokens to go negative to represent
                -- a deficit the refill must pay off before the next send. The
                -- bypass path must be symmetric — flooring here would erase
                -- debt from our own drain, letting us mistakenly "spend" budget
                -- that WoW's shared channel already used.
                msgTokens = msgTokens - 1
            end
        end)
        sendHookInstalled = true
    end

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

--- Shut down the comm system and release background resources.
-- Intended for test harnesses and debug reloads. Production addons can
-- leave this unused — WoW tears down Lua state on /reload. After Shutdown
-- the module is in a clean-initializable state: a subsequent Init() or
-- send/register call will rebuild commFrame, start a fresh queue, and
-- re-register for events.
--
-- Not reset:
--   * The secure hook on C_ChatInfo.SendAddonMessage (hooksecurefunc has no
--     uninstall API). InitializeCommFrame guards re-install with a flag.
--   * WoW-client prefix registrations from C_ChatInfo.RegisterAddonMessagePrefix
--     (session-scoped; re-registration is a safe no-op).
function CommMixin:Shutdown()
    if not commFrame then return end

    if commFrame.cleanupTicker then
        commFrame.cleanupTicker:Cancel()
        commFrame.cleanupTicker = nil
    end
    commFrame:UnregisterAllEvents()
    commFrame:SetScript("OnEvent", nil)
    commFrame:SetScript("OnUpdate", nil)
    commFrame:Hide()
    -- Nil the module-level handle so InitializeCommFrame rebuilds rather
    -- than no-ops on `if commFrame then return end`.
    commFrame = nil

    -- Release all queued and in-flight state so a restart begins from a
    -- clean baseline. Without this a Shutdown-then-Init cycle would leak
    -- stale messages onto the wire and reuse partial multi-part buffers.
    queues.ALERT:Reset()
    queues.NORMAL:Reset()
    queues.BULK:Reset()
    totalQueued = 0
    wipe(pendingMessages)
    wipe(registeredPrefixes)

    throttleAvailable    = THROTTLE_BURST
    lastThrottleUpdate   = 0
    loginRampActive      = false
    loginRampEnd         = 0
    throttlePauseUntil   = 0
    onUpdateAccumulator  = 0
    ourOwnSend           = false
    msgTokens            = MSG_BUDGET_BURST
    lastMsgTokenUpdate   = 0
    msgCoalesced         = 0
    wipe(coalesceIndex)
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
-- @param coalesceKey string|nil - Optional key for idempotent-state coalescing.
--   If an earlier send for (prefix, coalesceKey) is still queued and has not
--   yet started transmitting, it is marked superseded and the drain will skip
--   it. Use for whole-state messages where only the most recent value matters
--   (heartbeats, council roster, MLDB, version broadcasts). Only single-part
--   messages participate in coalescing; multi-part messages ignore the key.
-- @return boolean - true if queued, false if dropped due to queue full
function CommMixin:SendCommMessage(prefix, text, distribution, target, prio, callbackFn, callbackArg, coalesceKey)
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

    -- Coalesce: if caller supplied a coalesceKey and this send is a single
    -- packet, mark any prior queued-but-unsent item with the same (prefix, key)
    -- as superseded. The drain loop will skip superseded items. Multi-part
    -- sends skip coalescing to avoid tearing a partially-transmitted stream.
    local fullKey = nil
    if coalesceKey and #messages == 1 then
        fullKey = prefix .. "|" .. coalesceKey
        local prior = coalesceIndex[fullKey]
        if prior and not prior.sent and not prior.coalesced then
            prior.coalesced = true
            msgCoalesced = msgCoalesced + 1
        end
    end

    for _, msg in ipairs(messages) do
        local item = {
            prefix       = prefix,
            text         = msg,
            distribution = distribution,
            target       = target,
            prio         = prio,
            callback     = callbackFn,
            arg          = callbackArg,
            coalesceKey  = fullKey,   -- nil for non-coalesced or multi-part
        }
        EnqueueItem(item)
        if fullKey then
            coalesceIndex[fullKey] = item
        end
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
    -- Wrap the C_ChatInfo call in pcall so an unexpected error doesn't leave
    -- `ourOwnSend` stuck as `true` — that would cause the hooksecurefunc
    -- bypass-tracker to ignore every subsequent bypass send for the rest of
    -- the session, silently poisoning the throttle budget measurement.
    ourOwnSend = true
    local ok, err = pcall(C_ChatInfo.SendAddonMessage, prefix, CTRL_SINGLE .. text, distribution, target)
    ourOwnSend = false
    if not ok then
        error(err, 2)
    end
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
    wipe(coalesceIndex)
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

    -- Strip coalesce-index entries belonging to this prefix. Keys are of the
    -- form "<prefix>|<key>"; the removed items are gone from the queues, and
    -- leaving their index entries behind would cause a later enqueue to try
    -- to "supersede" an item that no longer exists.
    local keyPrefix = prefix .. "|"
    for k in pairs(coalesceIndex) do
        if k:sub(1, #keyPrefix) == keyPrefix then
            coalesceIndex[k] = nil
        end
    end

    if totalQueued == 0 and commFrame then commFrame:Hide() end
end

--- Get current throttle state
-- @return number, number - Available bytes, max burst bytes
function CommMixin:GetThrottleState()
    GetThrottleAllowance()  -- Update available
    return throttleAvailable, THROTTLE_BURST
end

--- Get current message-count token-bucket state.
-- @return number, number, number - Available tokens (float), burst capacity, coalesce counter
function CommMixin:GetMsgBudgetState()
    GetMsgTokens()  -- Refill before read
    return msgTokens, MSG_BUDGET_BURST, msgCoalesced
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

--[[--------------------------------------------------------------------
    Private Testing Hooks

    Not part of the public API. Used by
    Loolib/_examples/tests/AddonMessageReassemblyTest.lua to exercise
    the multi-part reassembler in isolation. Do not rely on this from
    addon code — the shape can change without notice.
----------------------------------------------------------------------]]

Loolib.Comm._testing = {
    AssembleMessage        = AssembleMessage,
    CleanupStalePending    = CleanupStalePending,
    NormalizeSenderKey     = NormalizeSenderKey,
    SplitMessage           = SplitMessage,
    GetPendingMessages     = function() return pendingMessages end,
    ResetPendingMessages   = function() wipe(pendingMessages) end,
    ResetMessageIDCounter  = function() messageIDCounter = 0 end,
    CTRL_SINGLE            = CTRL_SINGLE,
    CTRL_FIRST             = CTRL_FIRST,
    CTRL_MIDDLE            = CTRL_MIDDLE,
    CTRL_LAST              = CTRL_LAST,
}
