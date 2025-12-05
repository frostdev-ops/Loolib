# Loolib AddonMessage

## Overview

The **Loolib AddonMessage** system provides AceComm-compatible addon messaging with automatic message splitting, reassembly, priority queuing, and throttling. It handles the complexity of WoW's addon communication channels, allowing you to send large messages reliably without worrying about size limits or disconnects.

### Key Features

- Automatic message splitting for messages > 255 bytes
- Multi-part message reassembly with validation
- Priority queue system (ALERT, NORMAL, BULK)
- Intelligent throttling to prevent disconnects
- Prefix registration and callback management
- Distribution support (PARTY, RAID, GUILD, WHISPER, etc.)
- Integration with Serializer and Compressor
- OnUpdate-based queue processing

### When to Use It

- Sending raid/party coordination data
- Syncing addon state across guild members
- Broadcasting combat logs or damage meters
- Whisper-based configuration sharing
- Any inter-addon or inter-player communication
- Large data structures that exceed 255 bytes

---

## Quick Start

```lua
-- Get the comm system
local Loolib = LibStub("Loolib")
local Comm = Loolib:GetModule("AddonMessage").Comm

-- Or use the global singleton
local Comm = LoolibComm

-- Register a prefix to receive messages
Comm:RegisterComm("MyAddon", function(prefix, message, distribution, sender)
    print("Received from", sender, ":", message)
end)

-- Send a message
Comm:SendCommMessage("MyAddon", "Hello, raid!", "RAID")

-- Send a large message (automatically split)
local largeData = string.rep("Data chunk ", 100)  -- 1100 bytes
Comm:SendCommMessage("MyAddon", largeData, "PARTY")
-- Automatically split into 5 parts, reassembled on receive
```

---

## API Reference

### RegisterComm(prefix, callback, owner)

Register a prefix for receiving addon messages.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| prefix | string | Addon message prefix (1-16 characters, case-sensitive) |
| callback | function | Called when message received: `function(prefix, message, distribution, sender)` |
| owner | any | Optional owner reference for the callback |

**Returns:** Nothing

**Example:**
```lua
-- Simple registration
Comm:RegisterComm("MYDPS", function(prefix, message, dist, sender)
    print(sender, "sent DPS data:", message)
end)

-- With owner tracking
local MyAddon = {}
Comm:RegisterComm("MYCFG", MyAddon.OnConfigReceived, MyAddon)

function MyAddon:OnConfigReceived(prefix, message, dist, sender)
    -- self is MyAddon
    self:UpdateConfig(message)
end
```

**Important Notes:**
- WoW limits you to registering a total of ~100 prefixes per session
- Prefixes are case-sensitive: "MyAddon" != "MYADDON"
- Once registered with WoW, prefixes cannot be unregistered
- Registration is automatically attempted when first message is sent

---

### UnregisterComm(prefix)

Unregister a prefix callback.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| prefix | string | The prefix to unregister |

**Returns:** Nothing

**Example:**
```lua
Comm:UnregisterComm("MyAddon")
```

**Note:** This only removes the Loolib callback. WoW still considers the prefix registered.

---

### IsCommRegistered(prefix)

Check if a prefix is registered with Loolib.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| prefix | string | The prefix to check |

**Returns:**
| Type | Description |
|------|-------------|
| boolean | `true` if registered, `false` otherwise |

**Example:**
```lua
if not Comm:IsCommRegistered("MyAddon") then
    Comm:RegisterComm("MyAddon", OnMessage)
end
```

---

### SendCommMessage(prefix, text, distribution, target, prio, callbackFn, callbackArg)

Send an addon message with automatic splitting and queuing.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| prefix | string | Yes | Registered prefix (1-16 chars) |
| text | string | Yes | Message content (any size, auto-split if needed) |
| distribution | string | Yes | "PARTY", "RAID", "GUILD", "WHISPER", "CHANNEL", "INSTANCE_CHAT" |
| target | string | Conditional | Player name (for WHISPER) or channel number/name |
| prio | string | No | "ALERT", "NORMAL" (default), "BULK" |
| callbackFn | function | No | Called after each part sent: `function(callbackArg, bytesSent)` |
| callbackArg | any | No | Argument passed to callback |

**Returns:** Nothing (messages are queued)

**Example:**
```lua
-- Simple message
Comm:SendCommMessage("MyAddon", "Ready check!", "RAID")

-- Whisper to specific player
Comm:SendCommMessage("MyAddon", "Config update", "WHISPER", "PlayerName-Realm")

-- Large message with priority
local data = string.rep("X", 2000)  -- 2000 bytes
Comm:SendCommMessage("MyAddon", data, "PARTY", nil, "ALERT")

-- With callback
Comm:SendCommMessage("MyAddon", "Log data", "RAID", nil, "BULK",
    function(arg, bytes)
        print("Sent", bytes, "bytes")
    end
)
```

**Distribution Types:**
- `PARTY` - Current party members
- `RAID` - Current raid members
- `GUILD` - All online guild members
- `WHISPER` - Single player (requires target)
- `CHANNEL` - Custom channel (requires target channel number)
- `INSTANCE_CHAT` - Instance group (dungeons, scenarios)

**Priority Levels:**
- `ALERT` - Highest priority, sent immediately (use sparingly)
- `NORMAL` - Default priority, standard queue
- `BULK` - Low priority, heavily throttled (logs, non-critical data)

---

### SendCommMessageInstant(prefix, text, distribution, target)

Send a single-part message immediately, bypassing the queue.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| prefix | string | Registered prefix |
| text | string | Message content (must be ≤ 254 bytes) |
| distribution | string | Distribution channel |
| target | string | Target (for WHISPER) |

**Returns:** Nothing

**Example:**
```lua
-- Emergency alert
Comm:SendCommMessageInstant("MyAddon", "PULL NOW", "RAID")
```

**Warning:**
- Message must be 254 bytes or less (errors if larger)
- Bypasses throttling (can cause disconnects if abused)
- Use only for truly urgent messages
- No automatic splitting or reassembly

---

### GetQueuedMessageCount()

Get the number of messages waiting in the send queue.

**Parameters:** None

**Returns:**
| Type | Description |
|------|-------------|
| number | Number of queued message parts |

**Example:**
```lua
local count = Comm:GetQueuedMessageCount()
if count > 50 then
    print("Warning: Message queue is backing up!")
end
```

---

### ClearSendQueue()

Clear all queued messages.

**Parameters:** None

**Returns:** Nothing

**Example:**
```lua
-- Cancel all pending sends (e.g., on logout)
Comm:ClearSendQueue()
```

---

### ClearSendQueueForPrefix(prefix)

Clear queued messages for a specific prefix.

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| prefix | string | The prefix to clear |

**Returns:** Nothing

**Example:**
```lua
-- Cancel only DPS meter updates
Comm:ClearSendQueueForPrefix("MyDPS")
```

---

### GetThrottleState()

Get current throttle state.

**Parameters:** None

**Returns:**
| Type | Description |
|------|-------------|
| number | Available bytes in throttle budget |
| number | Maximum bytes (burst capacity) |

**Example:**
```lua
local available, max = Comm:GetThrottleState()
local percent = (available / max) * 100

if percent < 20 then
    print("Throttle at", percent, "% - messages will queue")
end
```

**Throttle Details:**
- Base rate: 2000 bytes/second
- Burst capacity: 4000 bytes
- BULK messages consume 4x bandwidth (effectively 500 bytes/sec)
- Throttle replenishes continuously over time

---

### CleanupPendingMessages(maxAge)

Clean up stale multi-part messages.

**Parameters:**
| Name | Type | Default | Description |
|------|------|---------|-------------|
| maxAge | number | 60 | Maximum age in seconds (currently unused) |

**Returns:** Nothing

**Example:**
```lua
-- Call periodically to prevent memory leaks
C_Timer.NewTicker(300, function()
    Comm:CleanupPendingMessages()
end)
```

**Note:** Current implementation clears all pending messages. Future versions may respect maxAge parameter.

---

## Usage Examples

### Basic Messaging

```lua
local Comm = LoolibComm

-- Register to receive
Comm:RegisterComm("CHAT", function(prefix, message, dist, sender)
    print(string.format("[%s] %s: %s", dist, sender, message))
end)

-- Send to party
Comm:SendCommMessage("CHAT", "Hello, party!", "PARTY")

-- Send to raid
Comm:SendCommMessage("CHAT", "Raid is ready!", "RAID")

-- Whisper a player
Comm:SendCommMessage("CHAT", "Check your settings", "WHISPER", "FriendName-Realm")
```

### Large Message Handling

```lua
-- Messages > 255 bytes are automatically split
local largeMessage = ""
for i = 1, 100 do
    largeMessage = largeMessage .. "Line " .. i .. ": Some data here.\n"
end

print("Message size:", #largeMessage, "bytes")  -- ~2500 bytes

-- Send (automatically split into ~10 parts)
Comm:SendCommMessage("MyData", largeMessage, "RAID")

-- Receive (automatically reassembled)
Comm:RegisterComm("MyData", function(prefix, message, dist, sender)
    -- message is the complete original data
    print("Received complete message:", #message, "bytes")
end)
```

### Priority Queue System

```lua
local Comm = LoolibComm

-- ALERT priority: Emergency pull timer
Comm:SendCommMessage("DBM", "PULL:5", "RAID", nil, "ALERT")

-- NORMAL priority: Regular coordination
Comm:SendCommMessage("MyAddon", "Boss at 50%", "RAID", nil, "NORMAL")

-- BULK priority: Combat logs (low priority, won't spam)
local combatLog = GetCombatLogData()  -- Large data
Comm:SendCommMessage("Logger", combatLog, "RAID", nil, "BULK")

-- Processing order: ALERT messages go first, then NORMAL, then BULK
```

### Integration with Serializer

```lua
local Serializer = LoolibSerializer
local Comm = LoolibComm

-- Send complex data structure
function SendRaidConfig(config)
    local serialized = Serializer:Serialize(config)
    Comm:SendCommMessage("RaidCfg", serialized, "RAID")
end

-- Receive and deserialize
Comm:RegisterComm("RaidCfg", function(prefix, message, dist, sender)
    local success, config = Serializer:Deserialize(message)
    if success then
        ApplyRaidConfig(config, sender)
    else
        print("Invalid config from", sender, ":", config)
    end
end)

-- Usage
local config = {
    difficulty = "Mythic",
    lootMethod = "Master Looter",
    masterlooter = "RaidLeader-Realm"
}
SendRaidConfig(config)
```

### Integration with Compressor and Serializer

```lua
local Serializer = LoolibSerializer
local Compressor = LoolibCompressor
local Comm = LoolibComm

-- Complete pipeline: Serialize -> Compress -> Encode -> Send
function SendCompressedData(data)
    -- Step 1: Serialize
    local serialized = Serializer:Serialize(data)

    -- Step 2: Compress
    local compressed = Compressor:Compress(serialized)

    -- Step 3: Encode for addon channel
    local encoded = Compressor:EncodeForAddonChannel(compressed)

    print(string.format("Size: %d → %d → %d bytes",
        #serialized, #compressed, #encoded))

    -- Step 4: Send
    Comm:SendCommMessage("MyData", encoded, "RAID")
end

-- Reverse pipeline: Receive -> Decode -> Decompress -> Deserialize
Comm:RegisterComm("MyData", function(prefix, message, dist, sender)
    -- Step 1: Decode
    local compressed = Compressor:DecodeForAddonChannel(message)

    -- Step 2: Decompress
    local serialized, success = Compressor:Decompress(compressed)
    if not success then
        print("Decompression failed from", sender)
        return
    end

    -- Step 3: Deserialize
    local ok, data = Serializer:Deserialize(serialized)
    if not ok then
        print("Deserialization failed from", sender)
        return
    end

    -- Step 4: Process
    ProcessReceivedData(data, sender)
end)
```

### Send Callbacks

```lua
-- Track upload progress
local totalSent = 0

local function OnPartSent(userData, bytesSent)
    totalSent = totalSent + bytesSent
    print(string.format("Sent %d/%d bytes (%.1f%%)",
        totalSent, userData.total, (totalSent / userData.total) * 100))
end

local data = string.rep("X", 5000)  -- 5KB
local userData = {total = #data}

Comm:SendCommMessage("Upload", data, "RAID", nil, "NORMAL",
    OnPartSent, userData)
```

### Throttle Monitoring

```lua
-- Monitor throttle state
local function CheckThrottle()
    local available, max = Comm:GetThrottleState()
    local percent = (available / max) * 100

    if percent < 25 then
        print(string.format("WARNING: Throttle at %.1f%%", percent))
    end

    local queued = Comm:GetQueuedMessageCount()
    if queued > 20 then
        print(string.format("WARNING: %d messages queued", queued))
    end
end

-- Check every 5 seconds
C_Timer.NewTicker(5, CheckThrottle)
```

### Channel Communication

```lua
-- Send to custom channel
local channelName = "MyAddonChannel"
local channelId = GetChannelName(channelName)

if channelId > 0 then
    Comm:SendCommMessage("MyAddon", "Channel message", "CHANNEL", tostring(channelId))
else
    print("Not in channel:", channelName)
end

-- Receive from channel
Comm:RegisterComm("MyAddon", function(prefix, message, dist, sender)
    if dist == "CHANNEL" then
        print("Channel message from", sender, ":", message)
    end
end)
```

### Version Check System

```lua
local MY_VERSION = 10205  -- 1.2.5

-- Send version on login
Comm:RegisterComm("VerCheck", function(prefix, message, dist, sender)
    local version = tonumber(message)
    if version and version > MY_VERSION then
        print(sender, "has newer version:", version, "(you have", MY_VERSION, ")")
    end
end)

-- Broadcast version to guild
EventRegistry:RegisterFrameEventAndCallback("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(5, function()
        Comm:SendCommMessage("VerCheck", tostring(MY_VERSION), "GUILD", nil, "BULK")
    end)
end)
```

### Raid Loot System

```lua
local Comm = LoolibComm
local Serializer = LoolibSerializer

-- Loot master broadcasts loot
function BroadcastLoot(itemLink, winner)
    local lootData = {
        item = itemLink,
        winner = winner,
        timestamp = time(),
        method = "Need Roll"
    }

    local serialized = Serializer:Serialize(lootData)
    Comm:SendCommMessage("RaidLoot", serialized, "RAID")
end

-- Raid members receive loot announcements
Comm:RegisterComm("RaidLoot", function(prefix, message, dist, sender)
    local success, lootData = Serializer:Deserialize(message)
    if success then
        print(string.format("%s won %s via %s",
            lootData.winner,
            lootData.item,
            lootData.method))

        -- Add to loot history
        AddLootToHistory(lootData)
    end
end)
```

### Backup and Sync System

```lua
-- Request backup from guild
function RequestBackup()
    Comm:SendCommMessage("Backup", "REQUEST", "GUILD")
end

-- Respond to backup request
Comm:RegisterComm("Backup", function(prefix, message, dist, sender)
    if message == "REQUEST" then
        -- Send our data back to requester
        local myData = GetMyBackupData()
        local serialized = Serializer:Serialize(myData)
        Comm:SendCommMessage("BackupResp", serialized, "WHISPER", sender)
    end
end)

-- Receive backup response
Comm:RegisterComm("BackupResp", function(prefix, message, dist, sender)
    local success, data = Serializer:Deserialize(message)
    if success then
        print("Received backup from", sender)
        MergeBackupData(data)
    end
end)
```

---

## Best Practices

### Performance Tips

1. **Use Appropriate Priorities**
```lua
-- ALERT: Only for truly urgent messages (boss pulls, emergencies)
Comm:SendCommMessage("DBM", "PULL:3", "RAID", nil, "ALERT")

-- NORMAL: Regular coordination, most messages
Comm:SendCommMessage("RC", "Ready check", "RAID", nil, "NORMAL")

-- BULK: Logs, history, non-critical data
Comm:SendCommMessage("Log", combatLog, "RAID", nil, "BULK")
```

2. **Compress Large Messages**
```lua
-- Always compress if message > 500 bytes
local serialized = Serializer:Serialize(data)

if #serialized > 500 then
    local compressed = Compressor:Compress(serialized)
    local encoded = Compressor:EncodeForAddonChannel(compressed)
    Comm:SendCommMessage("Data", encoded, "RAID")
else
    Comm:SendCommMessage("Data", serialized, "RAID")
end
```

3. **Batch Related Messages**
```lua
-- Good: Batch into one message
local updates = {player1 = data1, player2 = data2, player3 = data3}
local serialized = Serializer:Serialize(updates)
Comm:SendCommMessage("Updates", serialized, "RAID")

-- Bad: Send each separately
Comm:SendCommMessage("Updates", Serializer:Serialize(data1), "RAID")
Comm:SendCommMessage("Updates", Serializer:Serialize(data2), "RAID")
Comm:SendCommMessage("Updates", Serializer:Serialize(data3), "RAID")
```

4. **Monitor Queue Size**
```lua
-- Check queue before sending large data
if Comm:GetQueuedMessageCount() > 50 then
    print("Queue backed up, deferring send")
    C_Timer.After(5, function()
        SendData()
    end)
else
    SendData()
end
```

### Common Mistakes to Avoid

1. **Sending Too Many Messages**
```lua
-- Bad: Spam messages in loop
for i = 1, 100 do
    Comm:SendCommMessage("Spam", tostring(i), "RAID")  -- Will flood queue
end

-- Good: Batch them
local batch = {}
for i = 1, 100 do
    batch[i] = i
end
Comm:SendCommMessage("Batch", Serializer:Serialize(batch), "RAID")
```

2. **Not Validating Received Data**
```lua
-- Bad: Trust received data
Comm:RegisterComm("Config", function(prefix, message, dist, sender)
    local success, config = Serializer:Deserialize(message)
    ApplyConfig(config)  -- Dangerous!
end)

-- Good: Validate everything
Comm:RegisterComm("Config", function(prefix, message, dist, sender)
    local success, config = Serializer:Deserialize(message)
    if not success then return end

    -- Validate structure
    if type(config) ~= "table" then return end
    if type(config.scale) ~= "number" then return end
    if config.scale < 0.5 or config.scale > 2.0 then return end

    -- Validate sender
    if not IsInRaid() or not UnitIsGroupLeader(sender) then
        print("Unauthorized config from", sender)
        return
    end

    ApplyConfig(config)
end)
```

3. **Forgetting to Register Before Sending**
```lua
-- Bad: Send before registering
Comm:SendCommMessage("MyAddon", "test", "RAID")  -- May not register properly

-- Good: Register early (on addon load)
EventRegistry:RegisterFrameEventAndCallback("ADDON_LOADED", function(_, addonName)
    if addonName == "MyAddon" then
        Comm:RegisterComm("MyAddon", OnMessageReceived)
    end
end)

-- Later, send as needed
Comm:SendCommMessage("MyAddon", "test", "RAID")
```

4. **Abusing ALERT Priority**
```lua
-- Bad: Everything is ALERT
Comm:SendCommMessage("DPS", currentDPS, "RAID", nil, "ALERT")  -- Not urgent!

-- Good: ALERT only for emergencies
Comm:SendCommMessage("DPS", currentDPS, "RAID", nil, "BULK")  -- Appropriate priority
Comm:SendCommMessage("DBM", "PULL:5", "RAID", nil, "ALERT")  -- Actually urgent
```

5. **Not Handling Message Failures**
```lua
-- Messages can fail silently (not in group, player offline, etc.)
-- Always have fallback logic

-- Send with callback to detect issues
local attempts = 0
local function TrySend()
    attempts = attempts + 1
    if attempts > 3 then
        print("Failed to send after 3 attempts")
        return
    end

    Comm:SendCommMessage("Data", data, "WHISPER", target, "NORMAL",
        function(arg, bytes)
            print("Successfully sent", bytes, "bytes")
        end
    )

    -- If no callback after 5 seconds, retry
    C_Timer.After(5, function()
        if not confirmed then
            TrySend()
        end
    end)
end
```

### Security Considerations

1. **Validate Message Sources**
```lua
Comm:RegisterComm("Admin", function(prefix, message, dist, sender)
    -- Only accept admin commands from raid leader
    if not UnitIsGroupLeader(sender) then
        print("Unauthorized admin command from", sender)
        return
    end

    ProcessAdminCommand(message)
end)
```

2. **Rate Limit Incoming Messages**
```lua
local messageCount = {}
local MESSAGE_LIMIT = 10  -- Max 10 messages per sender per minute

Comm:RegisterComm("Data", function(prefix, message, dist, sender)
    -- Initialize counter
    local now = time()
    if not messageCount[sender] or now - messageCount[sender].time > 60 then
        messageCount[sender] = {count = 0, time = now}
    end

    -- Check rate limit
    messageCount[sender].count = messageCount[sender].count + 1
    if messageCount[sender].count > MESSAGE_LIMIT then
        print("Rate limit exceeded from", sender)
        return
    end

    ProcessMessage(message)
end)
```

3. **Sanitize Display Strings**
```lua
Comm:RegisterComm("Chat", function(prefix, message, dist, sender)
    -- Escape WoW UI codes to prevent exploits
    local safe = message:gsub("|", "||")  -- Escape |
    print(sender, ":", safe)
end)
```

4. **Size Limits**
```lua
-- Limit maximum message size to prevent memory attacks
local MAX_MESSAGE_SIZE = 100000  -- 100KB

Comm:RegisterComm("Upload", function(prefix, message, dist, sender)
    if #message > MAX_MESSAGE_SIZE then
        print("Message too large from", sender, ":", #message)
        return
    end

    ProcessUpload(message)
end)
```

---

## Technical Details

### Message Splitting Protocol

Messages larger than 255 bytes are split using control bytes:

```
Single message (≤254 bytes):
  [0x01][...message content...]

Multi-part message (>254 bytes):
  Part 1: [0x02][MSG_ID][...chunk 1...]  -- FIRST
  Part 2: [0x03][MSG_ID][...chunk 2...]  -- MIDDLE
  Part N: [0x04][MSG_ID][...chunk N...]  -- LAST
```

**Control Bytes:**
- `\001` (0x01) - Single message
- `\002` (0x02) - First part
- `\003` (0x03) - Middle part
- `\004` (0x04) - Last part

**Message ID:**
- 4 hexadecimal characters (0000-FFFF)
- 65,536 unique IDs before wraparound
- Same ID for all parts of a message
- Example: `A3F1`, `00BC`, `FFFF`

**Header Sizes:**
- Single: 1 byte overhead
- Multi-part: 5 bytes overhead (1 control + 4 hex ID)

**Chunk Size:**
- Single: 254 bytes max
- Multi-part: 250 bytes per chunk (255 - 5 byte header)

### Throttling Algorithm

**Parameters:**
```
THROTTLE_RATE = 2000        // Base: 2000 bytes/sec
THROTTLE_BURST = 4000       // Burst: 4000 bytes
THROTTLE_BULK_DIVISOR = 4   // BULK penalty
```

**Replenishment:**
```lua
available = min(BURST, available + (elapsed * RATE))
```

**Consumption:**
```lua
-- NORMAL/ALERT messages
consumed = messageSize

-- BULK messages
consumed = messageSize * 4  // 4x penalty
```

**Example Timeline:**
```
T=0.0s:  Send 1000 bytes (NORMAL)
         Available: 4000 - 1000 = 3000

T=0.5s:  Replenish: 3000 + (0.5 * 2000) = 4000 (capped at BURST)

T=0.5s:  Send 2000 bytes (BULK, effectively 8000)
         Available: 4000 - 8000 = -4000 (queued, wait for replenish)

T=4.5s:  Replenish: -4000 + (4.0 * 2000) = 4000
         BULK message sent
```

### Queue Processing

**OnUpdate Handler:**
```lua
function OnUpdate(self, elapsed)
    ProcessSendQueue()  -- Called every frame
end
```

**Processing Logic:**
1. Sort queue by priority (ALERT > NORMAL > BULK)
2. For each queued message:
   - Check throttle allowance
   - If available, send and consume throttle
   - If not available and nothing sent yet, wait
   - If not available but some sent, break (try next frame)
3. Remove sent messages from queue
4. Failed sends remain in queue for retry

**Priority Sorting:**
```lua
PRIORITY_ORDER = {
    ALERT = 1,
    NORMAL = 2,
    BULK = 3
}
```

### Multi-Part Reassembly

**State Tracking:**
```lua
pendingMessages[sender][prefix] = {
    id = "A3F1",           -- Current message ID
    parts = {"chunk1", "chunk2"},  -- Accumulated parts
    complete = false
}
```

**Assembly Logic:**
1. FIRST: Initialize new message, store first chunk
2. MIDDLE: Verify ID matches, append chunk
3. LAST: Verify ID matches, append chunk, concatenate all parts
4. Call registered callback with complete message

**Error Handling:**
- ID mismatch: Discard previous parts, start fresh
- Missing parts: Keep partial message until timeout
- Out-of-order: Not handled (assumes in-order delivery)

### Performance Characteristics

**Queue Processing:**
- Time complexity: O(n log n) for sort, O(n) for send
- Runs every frame (~60-200 times/sec depending on FPS)
- Minimal overhead when queue is empty

**Message Splitting:**
- Time complexity: O(n) where n = message length
- Space complexity: O(k) where k = number of parts
- No copying (uses string.sub for zero-copy slicing)

**Reassembly:**
- Time complexity: O(m) where m = total chunks
- Space complexity: O(m) for storing parts
- Final concatenation: O(n) where n = total message size

---

## Related Modules

- **Serializer** - Serialize data structures before sending
- **Compressor** - Compress messages to reduce bandwidth
- **CallbackRegistry** - Event system pattern used internally

---

## See Also

- [Serializer Documentation](./Serializer.md)
- [Compressor Documentation](./Compressor.md)
- [WoW Addon API - C_ChatInfo.SendAddonMessage](https://wowpedia.fandom.com/wiki/API_C_ChatInfo.SendAddonMessage)
- [WoW Addon API - CHAT_MSG_ADDON](https://wowpedia.fandom.com/wiki/CHAT_MSG_ADDON)
