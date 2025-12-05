--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    AddonMessage - Addon communication system

    Provides AceComm-compatible addon messaging with automatic message
    splitting, reassembly, priority queuing, and throttling.

    Features:
    - Register prefixes and receive callbacks
    - Automatic splitting of messages > 255 bytes
    - Multi-part message reassembly
    - Priority queue (ALERT, NORMAL, BULK)
    - Throttling to prevent disconnects
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

LoolibCommMixin = {}

-- Maximum message size for addon channel
local MAX_MESSAGE_SIZE = 255

-- Control bytes for message splitting protocol
local CTRL_SINGLE = "\001"    -- Single message (no splitting needed)
local CTRL_FIRST = "\002"     -- First part of multi-part message
local CTRL_MIDDLE = "\003"    -- Middle part of multi-part message
local CTRL_LAST = "\004"      -- Last part of multi-part message

-- Priority levels
local PRIORITY_ALERT = "ALERT"    -- Immediate transmission
local PRIORITY_NORMAL = "NORMAL"  -- Default priority
local PRIORITY_BULK = "BULK"      -- Low priority, heavily throttled

-- Priority order (lower = higher priority)
local PRIORITY_ORDER = {
    [PRIORITY_ALERT] = 1,
    [PRIORITY_NORMAL] = 2,
    [PRIORITY_BULK] = 3,
}

-- Throttle settings (bytes per second limits)
local THROTTLE_RATE = 2000        -- Base rate: 2000 bytes/sec
local THROTTLE_BURST = 4000       -- Burst allowance
local THROTTLE_BULK_DIVISOR = 4   -- Bulk messages get 1/4 the rate

-- Message ID counter for multi-part messages
local messageIDCounter = 0

--[[--------------------------------------------------------------------
    Internal State
----------------------------------------------------------------------]]

-- Registered prefixes and their callbacks: prefix -> {callback, owner}
local registeredPrefixes = {}

-- Pending multi-part messages: sender -> {prefix -> {id, parts, expected}}
local pendingMessages = {}

-- Send queue: array of {prefix, text, distribution, target, prio, callback, arg}
local sendQueue = {}

-- Throttle state
local throttleAvailable = THROTTLE_BURST
local lastThrottleUpdate = 0

-- Communication frame for events
local commFrame = nil

--[[--------------------------------------------------------------------
    Internal Functions
----------------------------------------------------------------------]]

local function GenerateMessageID()
    messageIDCounter = messageIDCounter + 1
    if messageIDCounter > 65535 then
        messageIDCounter = 1
    end
    -- 4 hex chars: same size header, but 65K IDs instead of 999
    return string.format("%04X", messageIDCounter)
end

local function GetThrottleAllowance()
    local now = GetTime()
    local elapsed = now - lastThrottleUpdate
    lastThrottleUpdate = now

    -- Replenish throttle based on elapsed time
    throttleAvailable = math.min(THROTTLE_BURST, throttleAvailable + (elapsed * THROTTLE_RATE))
    return throttleAvailable
end

local function ConsumeThrottle(amount)
    throttleAvailable = throttleAvailable - amount
end

local function SplitMessage(text, prefix)
    local messages = {}
    local textLen = #text

    if textLen <= MAX_MESSAGE_SIZE - 1 then
        -- Single message (control byte + content)
        messages[1] = CTRL_SINGLE .. text
        return messages
    end

    -- Multi-part message
    local msgID = GenerateMessageID()

    -- Reserve space for control byte and message ID in first/middle/last parts
    local headerSize = 1 + 4  -- control byte + 4-char hex ID
    local chunkSize = MAX_MESSAGE_SIZE - headerSize

    local pos = 1
    local partNum = 1

    while pos <= textLen do
        local chunk = text:sub(pos, pos + chunkSize - 1)
        local remaining = textLen - pos - #chunk + 1

        if partNum == 1 then
            messages[partNum] = CTRL_FIRST .. msgID .. chunk
        elseif remaining <= 0 then
            messages[partNum] = CTRL_LAST .. msgID .. chunk
        else
            messages[partNum] = CTRL_MIDDLE .. msgID .. chunk
        end

        pos = pos + #chunk
        partNum = partNum + 1
    end

    return messages
end

local function AssembleMessage(sender, prefix, ctrlByte, msgID, content)
    if ctrlByte == CTRL_SINGLE then
        return content, true
    end

    -- Initialize pending message storage for this sender/prefix
    if not pendingMessages[sender] then
        pendingMessages[sender] = {}
    end
    if not pendingMessages[sender][prefix] then
        pendingMessages[sender][prefix] = {}
    end

    local pending = pendingMessages[sender][prefix]

    if ctrlByte == CTRL_FIRST then
        -- Start new multi-part message
        pending.id = msgID
        pending.parts = {content}
        pending.complete = false
        return nil, false
    end

    -- Verify message ID matches
    if pending.id ~= msgID then
        -- Mismatched ID, discard and start fresh
        pending.id = msgID
        pending.parts = {}
        pending.complete = false
        return nil, false
    end

    -- Add part
    pending.parts[#pending.parts + 1] = content

    if ctrlByte == CTRL_LAST then
        -- Complete message
        local fullMessage = table.concat(pending.parts)
        pending.id = nil
        pending.parts = {}
        pending.complete = false
        return fullMessage, true
    end

    return nil, false
end

local function ProcessReceivedMessage(prefix, text, distribution, sender)
    if #text < 1 then
        return
    end

    local ctrlByte = text:sub(1, 1)
    local content

    if ctrlByte == CTRL_SINGLE then
        content = text:sub(2)
    else
        -- Multi-part: extract message ID (4 hex chars) and content
        if #text < 5 then
            return
        end
        local msgID = text:sub(2, 5)
        local msgContent = text:sub(6)

        local assembled, complete = AssembleMessage(sender, prefix, ctrlByte, msgID, msgContent)
        if not complete then
            return
        end
        content = assembled
    end

    -- Dispatch to registered callback
    local registration = registeredPrefixes[prefix]
    if registration and registration.callback then
        local success, err = pcall(registration.callback, prefix, content, distribution, sender)
        if not success then
            Loolib:Error("Comm callback error for prefix", prefix, ":", err)
        end
    end
end

local function ProcessSendQueue()
    if #sendQueue == 0 then
        return
    end

    local allowance = GetThrottleAllowance()

    -- Sort by priority (stable sort to maintain order within same priority)
    table.sort(sendQueue, function(a, b)
        return PRIORITY_ORDER[a.prio] < PRIORITY_ORDER[b.prio]
    end)

    local processed = 0
    local i = 1

    while i <= #sendQueue do
        local item = sendQueue[i]
        local msgLen = #item.text

        -- Apply bulk divisor for BULK priority
        local effectiveLen = msgLen
        if item.prio == PRIORITY_BULK then
            effectiveLen = msgLen * THROTTLE_BULK_DIVISOR
        end

        if effectiveLen > allowance and processed > 0 then
            -- Not enough allowance and we've sent at least one
            break
        end

        -- Send the message
        local success, err = pcall(C_ChatInfo.SendAddonMessage, item.prefix, item.text, item.distribution, item.target)

        if success then
            ConsumeThrottle(effectiveLen)
            allowance = allowance - effectiveLen

            -- Call delivery callback if provided
            if item.callback then
                pcall(item.callback, item.arg, #item.text)
            end

            -- Remove from queue
            table.remove(sendQueue, i)
            processed = processed + 1
        else
            -- Failed to send, leave in queue for retry
            Loolib:Error("Failed to send addon message:", err)
            i = i + 1
        end
    end
end

--[[--------------------------------------------------------------------
    Event Handling
----------------------------------------------------------------------]]

local function OnAddonMessage(prefix, text, distribution, sender)
    if not registeredPrefixes[prefix] then
        return
    end

    ProcessReceivedMessage(prefix, text, distribution, sender)
end

local function OnUpdate(self, elapsed)
    ProcessSendQueue()
end

local function InitializeCommFrame()
    if commFrame then
        return
    end

    commFrame = CreateFrame("Frame")
    commFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_ADDON" then
            OnAddonMessage(...)
        end
    end)
    commFrame:SetScript("OnUpdate", OnUpdate)
    commFrame:RegisterEvent("CHAT_MSG_ADDON")
end

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

--- Initialize the comm system
-- Called automatically on first use
function LoolibCommMixin:Init()
    InitializeCommFrame()
end

--- Register a prefix for receiving addon messages
-- @param prefix string - Addon message prefix (4-16 characters)
-- @param callback function - Function(prefix, message, distribution, sender)
-- @param owner any - Optional owner for the callback
function LoolibCommMixin:RegisterComm(prefix, callback, owner)
    if type(prefix) ~= "string" or #prefix < 1 or #prefix > 16 then
        error("RegisterComm: prefix must be a string of 1-16 characters", 2)
    end
    if type(callback) ~= "function" then
        error("RegisterComm: callback must be a function", 2)
    end

    InitializeCommFrame()

    -- Register with WoW
    local success = C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    if not success then
        -- Prefix may already be registered, which is okay
        Loolib:Debug("Prefix already registered or limit reached:", prefix)
    end

    registeredPrefixes[prefix] = {
        callback = callback,
        owner = owner,
    }
end

--- Unregister a prefix
-- @param prefix string - The prefix to unregister
function LoolibCommMixin:UnregisterComm(prefix)
    registeredPrefixes[prefix] = nil
    -- Note: WoW doesn't provide a way to unregister prefixes once registered
end

--- Check if a prefix is registered
-- @param prefix string - The prefix to check
-- @return boolean
function LoolibCommMixin:IsCommRegistered(prefix)
    return registeredPrefixes[prefix] ~= nil
end

--- Send an addon message
-- @param prefix string - Registered prefix
-- @param text string - Message content (will be split if > 255 bytes)
-- @param distribution string - "PARTY", "RAID", "GUILD", "WHISPER", "CHANNEL"
-- @param target string|nil - Player name (for WHISPER) or channel name/number
-- @param prio string|nil - "ALERT", "NORMAL" (default), "BULK"
-- @param callbackFn function|nil - Optional callback(arg, bytesSent) after each part sent
-- @param callbackArg any - Optional argument for callback
function LoolibCommMixin:SendCommMessage(prefix, text, distribution, target, prio, callbackFn, callbackArg)
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

    -- Validate distribution
    local validDist = {
        PARTY = true,
        RAID = true,
        GUILD = true,
        WHISPER = true,
        CHANNEL = true,
        INSTANCE_CHAT = true,
    }
    if not validDist[distribution] then
        error("SendCommMessage: invalid distribution: " .. distribution, 2)
    end

    -- WHISPER requires target
    if distribution == "WHISPER" and (not target or target == "") then
        error("SendCommMessage: WHISPER distribution requires target", 2)
    end

    -- Normalize priority
    prio = prio or PRIORITY_NORMAL
    if not PRIORITY_ORDER[prio] then
        prio = PRIORITY_NORMAL
    end

    -- Split message if needed
    local messages = SplitMessage(text, prefix)

    -- Queue messages for sending
    for i, msg in ipairs(messages) do
        sendQueue[#sendQueue + 1] = {
            prefix = prefix,
            text = msg,
            distribution = distribution,
            target = target,
            prio = prio,
            callback = callbackFn,
            arg = callbackArg,
        }
    end
end

--- Send an addon message immediately (bypass throttle for ALERT priority)
-- @param prefix string - Registered prefix
-- @param text string - Message content (single part only, no splitting)
-- @param distribution string - Distribution channel
-- @param target string|nil - Target for WHISPER
function LoolibCommMixin:SendCommMessageInstant(prefix, text, distribution, target)
    if #text > MAX_MESSAGE_SIZE - 1 then
        error("SendCommMessageInstant: message too long for instant send", 2)
    end

    local msg = CTRL_SINGLE .. text
    C_ChatInfo.SendAddonMessage(prefix, msg, distribution, target)
end

--- Get the number of queued messages
-- @return number
function LoolibCommMixin:GetQueuedMessageCount()
    return #sendQueue
end

--- Clear all queued messages
function LoolibCommMixin:ClearSendQueue()
    wipe(sendQueue)
end

--- Clear queued messages for a specific prefix
-- @param prefix string - The prefix to clear
function LoolibCommMixin:ClearSendQueueForPrefix(prefix)
    for i = #sendQueue, 1, -1 do
        if sendQueue[i].prefix == prefix then
            table.remove(sendQueue, i)
        end
    end
end

--- Get current throttle state
-- @return number, number - Available bytes, max bytes
function LoolibCommMixin:GetThrottleState()
    GetThrottleAllowance()  -- Update available
    return throttleAvailable, THROTTLE_BURST
end

--- Clean up stale pending messages (call periodically)
-- @param maxAge number - Maximum age in seconds (default 60)
function LoolibCommMixin:CleanupPendingMessages(maxAge)
    -- For simplicity, just clear all pending messages
    -- A more sophisticated implementation would track timestamps
    wipe(pendingMessages)
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new Comm instance
-- @return table - A new Comm object
function CreateLoolibComm()
    local comm = LoolibCreateFromMixins(LoolibCommMixin)
    comm:Init()
    return comm
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

LoolibComm = LoolibCreateFromMixins(LoolibCommMixin)

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local CommModule = {
    Mixin = LoolibCommMixin,
    Create = CreateLoolibComm,
    Comm = LoolibComm,

    -- Priority constants
    PRIORITY_ALERT = PRIORITY_ALERT,
    PRIORITY_NORMAL = PRIORITY_NORMAL,
    PRIORITY_BULK = PRIORITY_BULK,
}

Loolib:RegisterModule("AddonMessage", CommModule)

-- Also register in Comm module namespace
local Comm = Loolib:GetOrCreateModule("Comm")
Comm.AddonMessage = LoolibComm
Comm.PRIORITY = {
    ALERT = PRIORITY_ALERT,
    NORMAL = PRIORITY_NORMAL,
    BULK = PRIORITY_BULK,
}
