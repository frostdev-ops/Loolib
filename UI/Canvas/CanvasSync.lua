--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Canvas Network Sync System

    Provides network synchronization for canvas drawings between players
    using delta encoding and compression. Integrates with Loolib's
    AddonMessage system for reliable multi-part message handling.

    Features:
    - Delta encoding (send only changes, not full canvas state)
    - Full sync on join or request
    - Element sync IDs for tracking individual elements
    - LibDeflate compression for bandwidth efficiency
    - Throttling to prevent spam
    - Version tracking per sender

    Based on MRT's VisNote incremental update pattern.

    Dependencies (must be loaded before this file):
    - Core/Loolib.lua (Loolib namespace)
    - Core/Mixin.lua (LoolibMixin, LoolibCreateFromMixins)
    - Events/CallbackRegistry.lua (LoolibCallbackRegistryMixin)
    - Comm/Serializer.lua (LoolibSerializer)
    - Comm/AddonMessage.lua (LoolibComm)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local LoolibCallbackRegistryMixin = assert(Loolib.CallbackRegistryMixin, "Loolib/Events/CallbackRegistry.lua must be loaded before CanvasSync")

-- Verify dependencies are loaded
assert(Loolib.Mixin, "Loolib/Core/Mixin.lua must be loaded before CanvasSync")

-- Cached globals
local type = type
local error = error
local pairs = pairs
local ipairs = ipairs
local next = next
local table_insert = table.insert
local math_max = math.max

-- INTERNAL: Shallow-copy a serialized element table so sync metadata can be
-- attached without mutating the captured baseline state.
local function CopyElement(element)
    local copy = {}
    for key, value in pairs(element) do
        copy[key] = value
    end
    return copy
end

--[[--------------------------------------------------------------------
    Event Names
----------------------------------------------------------------------]]

local SYNC_EVENTS = {
    "OnSyncReceived",       -- Fired when a sync message is received (sender, version)
    "OnFullSyncReceived",   -- Fired when a full sync is received (sender)
    "OnDeltaReceived",      -- Fired when a delta is received (sender, changeCount)
    "OnSyncSent",           -- Fired when a sync is sent (messageType, recipientCount)
    "OnSyncEnabled",        -- Fired when sync is enabled
    "OnSyncDisabled",       -- Fired when sync is disabled
}

--[[--------------------------------------------------------------------
    Message Type Constants
----------------------------------------------------------------------]]

local MSG_FULL = "FULL"         -- Full canvas state
local MSG_DELTA = "DELTA"       -- Incremental changes
local MSG_REQUEST_FULL = "REQ"  -- Request full sync from leader

--[[--------------------------------------------------------------------
    LoolibCanvasSyncMixin

    A mixin that provides network synchronization for canvas drawings.
    Uses delta encoding to minimize bandwidth and supports compression.
----------------------------------------------------------------------]]

local LoolibCanvasSyncMixin = Loolib.CreateFromMixins(LoolibCallbackRegistryMixin)

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the sync system
function LoolibCanvasSyncMixin:OnLoad()
    -- Initialize callback system
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(SYNC_EVENTS)

    -- Sync state
    self._syncEnabled = false
    self._syncChannel = "RAID"  -- RAID, PARTY, GUILD, INSTANCE_CHAT
    self._syncPrefix = "LOOLIB_CANVAS"

    -- Version tracking for delta encoding
    self._localVersion = 0
    self._remoteVersions = {}  -- { [sender] = version }

    -- Last known state for delta calculation
    self._lastSyncState = nil

    -- Queue for outgoing changes
    self._pendingChanges = {}
    self._syncThrottle = 0.5  -- Seconds between syncs
    self._lastSyncTime = 0

    -- Element managers (set via SetElementManagers)
    self._brushManager = nil
    self._shapeManager = nil
    self._textManager = nil
    self._iconManager = nil
    self._imageManager = nil

    -- LibDeflate reference (loaded on demand)
    self._libDeflate = nil
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set the element managers for serialization
-- @param brush LoolibCanvasBrushMixin - Brush manager
-- @param shape LoolibCanvasShapeMixin - Shape manager
-- @param text LoolibCanvasTextMixin - Text manager
-- @param icon LoolibCanvasIconMixin - Icon manager
-- @param image LoolibCanvasImageMixin - Image manager
-- @return self - For method chaining
function LoolibCanvasSyncMixin:SetElementManagers(brush, shape, text, icon, image)
    self._brushManager = brush
    self._shapeManager = shape
    self._textManager = text
    self._iconManager = icon
    self._imageManager = image
    return self
end

--- Enable or disable network sync
-- @param enabled boolean - True to enable sync, false to disable
-- @return self - For method chaining
function LoolibCanvasSyncMixin:SetSyncEnabled(enabled)
    if self._syncEnabled == enabled then
        return self
    end

    self._syncEnabled = enabled

    if enabled then
        self:_RegisterMessages()
        self:TriggerEvent("OnSyncEnabled")
    else
        self:_UnregisterMessages()
        self:TriggerEvent("OnSyncDisabled")
    end

    return self
end

--- Check if sync is enabled
-- @return boolean - True if sync is enabled
function LoolibCanvasSyncMixin:IsSyncEnabled()
    return self._syncEnabled
end

--- Set the sync channel
-- @param channel string - "RAID", "PARTY", "GUILD", "INSTANCE_CHAT"
-- @return self - For method chaining
function LoolibCanvasSyncMixin:SetSyncChannel(channel)
    self._syncChannel = channel
    return self
end

--- Get the current sync channel
-- @return string - Current channel
function LoolibCanvasSyncMixin:GetSyncChannel()
    return self._syncChannel
end

--- Set the sync throttle delay
-- @param seconds number - Minimum seconds between syncs (default 0.5)
-- @return self - For method chaining
function LoolibCanvasSyncMixin:SetSyncThrottle(seconds)
    self._syncThrottle = math_max(0.1, seconds)
    return self
end

--[[--------------------------------------------------------------------
    State Capture and Delta Generation
----------------------------------------------------------------------]]

--- Capture the current canvas state from all element managers
-- @return table - Current state with all elements
function LoolibCanvasSyncMixin:_CaptureState()
    local state = {}

    if self._brushManager then
        state.dots = self._brushManager:SerializeDots()
    end
    if self._shapeManager then
        state.shapes = self._shapeManager:SerializeShapes()
    end
    if self._textManager then
        state.texts = self._textManager:SerializeTexts()
    end
    if self._iconManager then
        state.icons = self._iconManager:SerializeIcons()
    end
    if self._imageManager then
        state.images = self._imageManager:SerializeImages()
    end

    return state
end

--- Generate delta between current state and last sync
-- @return table - Delta with added, removed, modified elements
function LoolibCanvasSyncMixin:GenerateDelta()
    local currentState = self:_CaptureState()
    local delta = {
        version = self._localVersion + 1,
        added = {},
        removed = {},
        modified = {},
    }

    if not self._lastSyncState then
        -- First sync - send everything as full state
        delta.full = true
        delta.state = currentState
    else
        -- Compute delta between last and current state
        delta = self:_ComputeDelta(self._lastSyncState, currentState)
        delta.version = self._localVersion + 1
    end

    self._localVersion = delta.version
    self._lastSyncState = currentState

    return delta
end

--- Compute delta between two states
--- CV-04 FIX: Uses index-based comparison instead of syncId reference equality.
--- The serialized element data from Serialize*() methods does NOT include syncId,
--- so the old syncId-based map approach produced empty maps and every element
--- appeared as "added" on every sync cycle. Now we compare by array index
--- and use deep field comparison to detect changes.
---@param oldState table Previous state
---@param newState table Current state
---@return table delta Delta with version, added, removed, modified
function LoolibCanvasSyncMixin:_ComputeDelta(oldState, newState)
    local delta = {
        added = {},
        removed = {},
        modified = {},
    }

    -- Element types to check
    local elementTypes = { "dots", "shapes", "texts", "icons", "images" }

    for _, elementType in ipairs(elementTypes) do
        local oldElements = oldState[elementType] or {}
        local newElements = newState[elementType] or {}
        local oldCount = #oldElements
        local newCount = #newElements

        delta.added[elementType] = {}
        delta.modified[elementType] = {}
        delta.removed[elementType] = {}

        -- CV-04 FIX: Compare by index position, not by syncId reference
        -- Check elements that exist in both old and new (potential modifications)
        local minCount = oldCount < newCount and oldCount or newCount
        for i = 1, minCount do
            if self:_ElementChanged(oldElements[i], newElements[i]) then
                local elem = CopyElement(newElements[i])
                elem._idx = i  -- Tag with index for apply without mutating baseline state
                table_insert(delta.modified[elementType], elem)
            end
        end

        -- Elements beyond old count are newly added
        for i = oldCount + 1, newCount do
            table_insert(delta.added[elementType], newElements[i])
        end

        -- Elements beyond new count were removed (store indices)
        for i = newCount + 1, oldCount do
            table_insert(delta.removed[elementType], i)
        end

        -- Clean up empty tables
        if #delta.added[elementType] == 0 then
            delta.added[elementType] = nil
        end
        if #delta.removed[elementType] == 0 then
            delta.removed[elementType] = nil
        end
        if #delta.modified[elementType] == 0 then
            delta.modified[elementType] = nil
        end
    end

    return delta
end

--- Check if an element has changed
-- @param old table - Old element data
-- @param new table - New element data
-- @return boolean - True if changed
function LoolibCanvasSyncMixin:_ElementChanged(old, new)
    -- Simple deep comparison
    -- Could be optimized for specific element types
    for key, value in pairs(new) do
        if type(value) == "table" then
            if type(old[key]) ~= "table" then
                return true
            end
            -- Shallow comparison for nested tables
            for k, v in pairs(value) do
                if old[key][k] ~= v then
                    return true
                end
            end
        elseif old[key] ~= value then
            return true
        end
    end

    for key in pairs(old) do
        if new[key] == nil then
            return true
        end
    end

    return false
end

--[[--------------------------------------------------------------------
    Applying Deltas
----------------------------------------------------------------------]]

--- Apply a delta received from a remote sender
-- @param delta table - Delta from remote
-- @param sender string - Sender name
-- @return self - For method chaining
function LoolibCanvasSyncMixin:ApplyDelta(delta, sender)
    if not delta then return self end

    -- Track remote version
    self._remoteVersions[sender] = delta.version

    local changeCount = 0

    if delta.full then
        -- Full sync - replace everything
        changeCount = self:_ApplyFullState(delta.state)
        self:TriggerEvent("OnFullSyncReceived", sender)
    else
        -- Incremental delta
        changeCount = self:_ApplyIncrementalDelta(delta)
        self:TriggerEvent("OnDeltaReceived", sender, changeCount)
    end

    -- Keep the local sync baseline aligned with the newly applied remote
    -- state so subsequent local broadcasts do not immediately echo it back.
    self._lastSyncState = self:_CaptureState()

    self:TriggerEvent("OnSyncReceived", sender, delta.version)

    return self
end

--- Apply a full state sync
-- @param state table - Full canvas state
-- @return number - Number of elements changed
function LoolibCanvasSyncMixin:_ApplyFullState(state)
    local count = 0

    if state.dots and self._brushManager then
        self._brushManager:DeserializeDots(state.dots)
        count = count + (state.dots and #state.dots or 0)
    end
    if state.shapes and self._shapeManager then
        self._shapeManager:DeserializeShapes(state.shapes)
        count = count + (state.shapes and #state.shapes or 0)
    end
    if state.texts and self._textManager then
        self._textManager:DeserializeTexts(state.texts)
        count = count + (state.texts and #state.texts or 0)
    end
    if state.icons and self._iconManager then
        self._iconManager:DeserializeIcons(state.icons)
        count = count + (state.icons and #state.icons or 0)
    end
    if state.images and self._imageManager then
        self._imageManager:DeserializeImages(state.images)
        count = count + (state.images and #state.images or 0)
    end

    return count
end

--- Apply an incremental delta
-- @param delta table - Delta with added, removed, modified
-- @return number - Number of elements changed
function LoolibCanvasSyncMixin:_ApplyIncrementalDelta(delta)
    local count = 0

    -- Apply added elements
    if delta.added then
        count = count + self:_ApplyAdded(delta.added)
    end

    -- Apply removed elements
    if delta.removed then
        count = count + self:_ApplyRemoved(delta.removed)
    end

    -- Apply modified elements
    if delta.modified then
        count = count + self:_ApplyModified(delta.modified)
    end

    return count
end

--- Apply added elements
-- @param added table - Added elements by type
-- @return number - Number of elements added
function LoolibCanvasSyncMixin:_ApplyAdded(added)
    local count = 0

    -- Note: For simplicity, we deserialize the added elements as a full set
    -- A more sophisticated implementation would add individual elements

    if added.dots and self._brushManager then
        -- Append dots to existing ones
        local existing = self._brushManager:SerializeDots() or {}
        for _, dot in ipairs(added.dots) do
            table.insert(existing, dot)
            count = count + 1
        end
        self._brushManager:DeserializeDots(existing)
    end

    if added.shapes and self._shapeManager then
        local existing = self._shapeManager:SerializeShapes() or {}
        for _, shape in ipairs(added.shapes) do
            table.insert(existing, shape)
            count = count + 1
        end
        self._shapeManager:DeserializeShapes(existing)
    end

    if added.texts and self._textManager then
        local existing = self._textManager:SerializeTexts() or {}
        for _, text in ipairs(added.texts) do
            table.insert(existing, text)
            count = count + 1
        end
        self._textManager:DeserializeTexts(existing)
    end

    if added.icons and self._iconManager then
        local existing = self._iconManager:SerializeIcons() or {}
        for _, icon in ipairs(added.icons) do
            table.insert(existing, icon)
            count = count + 1
        end
        self._iconManager:DeserializeIcons(existing)
    end

    if added.images and self._imageManager then
        local existing = self._imageManager:SerializeImages() or {}
        for _, image in ipairs(added.images) do
            table.insert(existing, image)
            count = count + 1
        end
        self._imageManager:DeserializeImages(existing)
    end

    return count
end

--- Apply removed elements
--- CV-05 FIX: _ComputeDelta sends array indices (not syncIds) in the removed
--- arrays. Build a set of those indices and filter out matching positions.
-- @param removed table - Removed elements by type (array of indices)
-- @return number - Number of elements removed
function LoolibCanvasSyncMixin:_ApplyRemoved(removed)
    local count = 0

    -- Build a set of removed indices for each type
    local removedSets = {}
    for elementType, indices in pairs(removed) do
        removedSets[elementType] = {}
        for _, idx in ipairs(indices) do
            removedSets[elementType][idx] = true
        end
    end

    -- Filter out removed elements by index position
    if removedSets.dots and self._brushManager then
        local existing = self._brushManager:SerializeDots() or {}
        local filtered = {}
        for i, dot in ipairs(existing) do
            if not removedSets.dots[i] then
                table_insert(filtered, dot)
            else
                count = count + 1
            end
        end
        self._brushManager:DeserializeDots(filtered)
    end

    if removedSets.shapes and self._shapeManager then
        local existing = self._shapeManager:SerializeShapes() or {}
        local filtered = {}
        for i, shape in ipairs(existing) do
            if not removedSets.shapes[i] then
                table_insert(filtered, shape)
            else
                count = count + 1
            end
        end
        self._shapeManager:DeserializeShapes(filtered)
    end

    if removedSets.texts and self._textManager then
        local existing = self._textManager:SerializeTexts() or {}
        local filtered = {}
        for i, text in ipairs(existing) do
            if not removedSets.texts[i] then
                table_insert(filtered, text)
            else
                count = count + 1
            end
        end
        self._textManager:DeserializeTexts(filtered)
    end

    if removedSets.icons and self._iconManager then
        local existing = self._iconManager:SerializeIcons() or {}
        local filtered = {}
        for i, icon in ipairs(existing) do
            if not removedSets.icons[i] then
                table_insert(filtered, icon)
            else
                count = count + 1
            end
        end
        self._iconManager:DeserializeIcons(filtered)
    end

    if removedSets.images and self._imageManager then
        local existing = self._imageManager:SerializeImages() or {}
        local filtered = {}
        for i, image in ipairs(existing) do
            if not removedSets.images[i] then
                table_insert(filtered, image)
            else
                count = count + 1
            end
        end
        self._imageManager:DeserializeImages(filtered)
    end

    return count
end

--- Apply modified elements
--- CV-05 FIX: Uses index-based lookup via _idx tag (set by _ComputeDelta)
--- instead of syncId, which serialized data does not include.
-- @param modified table - Modified elements by type
-- @return number - Number of elements modified
function LoolibCanvasSyncMixin:_ApplyModified(modified)
    local count = 0

    -- Build index-based lookup maps for modified elements
    -- _ComputeDelta tags each modified element with _idx = array position
    local modifiedMaps = {}
    for elementType, elements in pairs(modified) do
        modifiedMaps[elementType] = {}
        for _, elem in ipairs(elements) do
            if elem._idx then
                modifiedMaps[elementType][elem._idx] = elem
            end
        end
    end

    -- Update modified elements by index
    if modifiedMaps.dots and next(modifiedMaps.dots) and self._brushManager then
        local existing = self._brushManager:SerializeDots() or {}
        for idx, elem in pairs(modifiedMaps.dots) do
            if existing[idx] then
                existing[idx] = elem
                count = count + 1
            end
        end
        self._brushManager:DeserializeDots(existing)
    end

    if modifiedMaps.shapes and next(modifiedMaps.shapes) and self._shapeManager then
        local existing = self._shapeManager:SerializeShapes() or {}
        for idx, elem in pairs(modifiedMaps.shapes) do
            if existing[idx] then
                existing[idx] = elem
                count = count + 1
            end
        end
        self._shapeManager:DeserializeShapes(existing)
    end

    if modifiedMaps.texts and next(modifiedMaps.texts) and self._textManager then
        local existing = self._textManager:SerializeTexts() or {}
        for idx, elem in pairs(modifiedMaps.texts) do
            if existing[idx] then
                existing[idx] = elem
                count = count + 1
            end
        end
        self._textManager:DeserializeTexts(existing)
    end

    if modifiedMaps.icons and next(modifiedMaps.icons) and self._iconManager then
        local existing = self._iconManager:SerializeIcons() or {}
        for idx, elem in pairs(modifiedMaps.icons) do
            if existing[idx] then
                existing[idx] = elem
                count = count + 1
            end
        end
        self._iconManager:DeserializeIcons(existing)
    end

    if modifiedMaps.images and next(modifiedMaps.images) and self._imageManager then
        local existing = self._imageManager:SerializeImages() or {}
        for idx, elem in pairs(modifiedMaps.images) do
            if existing[idx] then
                existing[idx] = elem
                count = count + 1
            end
        end
        self._imageManager:DeserializeImages(existing)
    end

    return count
end

--[[--------------------------------------------------------------------
    Compression and Serialization
----------------------------------------------------------------------]]

--- Get LibDeflate reference
-- @return table|nil - LibDeflate library or nil
function LoolibCanvasSyncMixin:_GetLibDeflate()
    if not self._libDeflate then
        self._libDeflate = LibStub and LibStub("LibDeflate", true)
    end
    return self._libDeflate
end

--- Compress data for transmission
-- @param data table - Data to compress
-- @return string - Compressed and encoded string
function LoolibCanvasSyncMixin:Compress(data)
    -- Serialize using Loolib's serializer
    local serialized = self:_Serialize(data)

    -- Use LibDeflate if available
    local LibDeflate = self:_GetLibDeflate()
    if LibDeflate then
        local compressed = LibDeflate:CompressDeflate(serialized, {level = 9})
        if compressed then
            return LibDeflate:EncodeForWoWAddonChannel(compressed)
        end
    end

    -- Fallback to uncompressed
    return serialized
end

--- Decompress data
-- @param data string - Compressed data
-- @return table|nil - Decompressed data or nil on error
function LoolibCanvasSyncMixin:Decompress(data)
    local LibDeflate = self:_GetLibDeflate()

    if LibDeflate then
        local decoded = LibDeflate:DecodeForWoWAddonChannel(data)
        if decoded then
            local decompressed = LibDeflate:DecompressDeflate(decoded)
            if decompressed then
                return self:_Deserialize(decompressed)
            end
        end
    end

    -- Try uncompressed
    return self:_Deserialize(data)
end

--- Serialize data using Loolib's serializer
-- @param data table - Data to serialize
-- @return string - Serialized string
function LoolibCanvasSyncMixin:_Serialize(data)
    local Serializer = Loolib:GetModule("Serializer")
    if Serializer and Serializer.Serializer then
        return Serializer.Serializer:Serialize(data)
    end

    -- Fallback: error
    error("Loolib Serializer not available", 2)
end

--- Deserialize data using Loolib's serializer
-- @param str string - Serialized string
-- @return table|nil - Deserialized data or nil on error
function LoolibCanvasSyncMixin:_Deserialize(str)
    local Serializer = Loolib:GetModule("Serializer")
    if Serializer and Serializer.Serializer then
        local success, data = Serializer.Serializer:Deserialize(str)
        if success then
            return data
        end
    end

    return nil
end

--[[--------------------------------------------------------------------
    Broadcasting
----------------------------------------------------------------------]]

--- Broadcast full canvas state
-- @return self - For method chaining
function LoolibCanvasSyncMixin:BroadcastFull()
    if not self._syncEnabled then return self end

    local delta = self:GenerateDelta()
    delta.full = true

    self:_SendMessage(MSG_FULL, delta)
    self:TriggerEvent("OnSyncSent", MSG_FULL, 1)

    return self
end

--- Broadcast incremental changes
-- @return self - For method chaining
function LoolibCanvasSyncMixin:BroadcastChanges()
    if not self._syncEnabled then return self end

    local now = GetTime and GetTime() or 0
    if now - self._lastSyncTime < self._syncThrottle then
        -- Throttle - skip this broadcast
        return self
    end

    local delta = self:GenerateDelta()

    -- Only send if there are changes
    local hasChanges = delta.full or
                      (delta.added and next(delta.added)) or
                      (delta.removed and next(delta.removed)) or
                      (delta.modified and next(delta.modified))

    if hasChanges then
        self:_SendMessage(MSG_DELTA, delta)
        self._lastSyncTime = now
        self:TriggerEvent("OnSyncSent", MSG_DELTA, 1)
    end

    return self
end

--- Request full sync from raid/party leader
-- @return self - For method chaining
function LoolibCanvasSyncMixin:RequestFullSync()
    if not self._syncEnabled then return self end

    self:_SendMessage(MSG_REQUEST_FULL, {})
    self:TriggerEvent("OnSyncSent", MSG_REQUEST_FULL, 1)

    return self
end

--[[--------------------------------------------------------------------
    Message Handling
----------------------------------------------------------------------]]

--- Send a message over the sync channel
-- @param msgType string - Message type (FULL, DELTA, REQ)
-- @param data table - Message payload
function LoolibCanvasSyncMixin:_SendMessage(msgType, data)
    local payload = self:Compress({ t = msgType, d = data })

    -- Use Loolib's AddonMessage system
    local AddonMessage = Loolib:GetModule("AddonMessage")
    if AddonMessage and AddonMessage.Comm then
        AddonMessage.Comm:SendCommMessage(
            self._syncPrefix,
            payload,
            self._syncChannel,
            nil,  -- target
            msgType == MSG_REQUEST_FULL and "ALERT" or "NORMAL"
        )
    end
end

--- Register for addon messages
function LoolibCanvasSyncMixin:_RegisterMessages()
    local AddonMessage = Loolib:GetModule("AddonMessage")
    if not AddonMessage or not AddonMessage.Comm then
        Loolib:Error("AddonMessage module not available for CanvasSync")
        return
    end

    -- Register prefix and callback
    AddonMessage.Comm:RegisterComm(self._syncPrefix, function(_, msg, _, sender)
        self:_OnMessageReceived(msg, sender)
    end, self)
end

--- Unregister from addon messages
function LoolibCanvasSyncMixin:_UnregisterMessages()
    local AddonMessage = Loolib:GetModule("AddonMessage")
    if AddonMessage and AddonMessage.Comm then
        AddonMessage.Comm:UnregisterComm(self._syncPrefix)
    end
end

--- Handle received addon message
-- @param msg string - Compressed message
-- @param sender string - Sender name
function LoolibCanvasSyncMixin:_OnMessageReceived(msg, sender)
    -- Ignore messages from self. UnitName("player") can return a secret-tagged
    -- value under encounter taint; use SafeUnitName to keep the equality safe.
    local playerName = Loolib.SecretUtil and Loolib.SecretUtil.SafeUnitName("player") or UnitName("player")
    if playerName and sender == playerName then
        return
    end

    -- Decompress and parse
    local data = self:Decompress(msg)
    if not data or not data.t then
        return
    end

    local msgType = data.t
    local payload = data.d

    if msgType == MSG_FULL or msgType == MSG_DELTA then
        -- Apply the delta
        self:ApplyDelta(payload, sender)
    elseif msgType == MSG_REQUEST_FULL then
        -- Someone requested full sync - send it
        self:BroadcastFull()
    end
end

--[[--------------------------------------------------------------------
    Version and State Management
----------------------------------------------------------------------]]

--- Get the local version number
-- @return number - Current local version
function LoolibCanvasSyncMixin:GetLocalVersion()
    return self._localVersion
end

--- Get the remote version for a sender
-- @param sender string - Sender name
-- @return number|nil - Remote version or nil if unknown
function LoolibCanvasSyncMixin:GetRemoteVersion(sender)
    return self._remoteVersions[sender]
end

--- Reset local version and state
-- @return self - For method chaining
function LoolibCanvasSyncMixin:ResetSyncState()
    self._localVersion = 0
    self._lastSyncState = nil
    wipe(self._remoteVersions)
    return self
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new CanvasSync instance
-- @return table - A new CanvasSync object
local function LoolibCreateCanvasSync()
    local sync = Loolib.CreateFromMixins(LoolibCanvasSyncMixin)
    sync:OnLoad()
    return sync
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local CanvasSyncModule = {
    Mixin = LoolibCanvasSyncMixin,
    Create = LoolibCreateCanvasSync,

    -- Message type constants
    MSG_FULL = MSG_FULL,
    MSG_DELTA = MSG_DELTA,
    MSG_REQUEST_FULL = MSG_REQUEST_FULL,
}

-- R4: Fully qualified name
Loolib:RegisterModule("Canvas.CanvasSync", CanvasSyncModule)

-- Backward-compat alias
Loolib:RegisterModule("CanvasSync", CanvasSyncModule)
