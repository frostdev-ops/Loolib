--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Bucket - AceBucket-3.0 compatible event/message batching system

    Provides event and message bucketing to throttle rapid-fire events
    like bag updates or unit changes. Collects events over an interval
    and fires a single callback with aggregate data.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Get dependencies
local TimerModule = Loolib:GetModule("Timer")
local EventRegistryModule = Loolib:GetModule("EventRegistry")
local EventRegistry = EventRegistryModule.Registry

-- Local references
local type = type

-- Global handle counter for unique bucket IDs
local bucketHandleCounter = 0

--[[--------------------------------------------------------------------
    LoolibBucketMixin

    Mixin for objects that need event/message bucketing capabilities.
    Automatically includes timer functionality.
----------------------------------------------------------------------]]

LoolibBucketMixin = LoolibCreateFromMixins(TimerModule.Mixin)

--[[--------------------------------------------------------------------
    Internal Helper Functions
----------------------------------------------------------------------]]

--- Generate a unique bucket handle
-- @return string - Unique bucket handle
local function GenerateBucketHandle()
    bucketHandleCounter = bucketHandleCounter + 1
    return "LoolibBucket" .. bucketHandleCounter
end

--- Validate callback parameter
-- @param callback function|string - The callback to validate
-- @return boolean - True if valid
local function ValidateCallback(callback)
    local callbackType = type(callback)
    return callbackType == "function" or callbackType == "string"
end

--- Validate interval parameter
-- @param interval number - The interval to validate
-- @return boolean - True if valid
local function ValidateInterval(interval)
    return type(interval) == "number" and interval > 0
end

--- Normalize events parameter to table
-- @param events string|table - Event name or table of event names
-- @return table - Table of event names
local function NormalizeEvents(events)
    if type(events) == "string" then
        return {events}
    elseif type(events) == "table" then
        return events
    else
        error("Events must be a string or table of strings", 3)
    end
end

--[[--------------------------------------------------------------------
    Bucket Storage and Management
----------------------------------------------------------------------]]

--- Initialize bucket storage for this object
-- @param self table - The object instance
local function EnsureBucketStorage(self)
    if not self.buckets then
        self.buckets = {}
    end
end

--- Fire a bucket callback with collected data
-- @param self table - The object instance
-- @param bucket table - The bucket info
local function FireBucket(self, bucket)
    -- Calculate total count
    local totalCount = 0
    for _, count in pairs(bucket.data) do
        totalCount = totalCount + count
    end

    -- Prepare data table
    local data = {
        count = totalCount,
        events = bucket.data,
    }

    -- Clear bucket data
    bucket.data = {}
    bucket.timerActive = false

    -- Execute callback
    local callback = bucket.callback
    if type(callback) == "string" then
        -- Method name - call self[callback](self, data)
        local method = self[callback]
        if method then
            method(self, data)
        else
            Loolib:Error("Bucket: method '" .. callback .. "' not found")
        end
    else
        -- Function - call callback(data)
        callback(data)
    end
end

--- Handle an event for a bucket
-- @param self table - The object instance
-- @param bucket table - The bucket info
-- @param eventName string - The event name
local function HandleBucketEvent(self, bucket, eventName)
    -- Increment counter for this event
    bucket.data[eventName] = (bucket.data[eventName] or 0) + 1

    -- Start timer if not already running
    if not bucket.timerActive then
        bucket.timerActive = true

        -- Schedule timer to fire bucket
        self:ScheduleTimer(function()
            if self.buckets[bucket.handle] then
                FireBucket(self, bucket)
            end
        end, bucket.interval)
    end
end

--[[--------------------------------------------------------------------
    Event Bucket Registration
----------------------------------------------------------------------]]

--- Register a bucket for WoW game events
-- @param events string|table - Event name or table of event names
-- @param interval number - Seconds to collect events before firing callback
-- @param callback function|string - Callback function or method name
-- @return string - Bucket handle for unregistration
function LoolibBucketMixin:RegisterBucketEvent(events, interval, callback)
    -- Validate parameters
    if not ValidateInterval(interval) then
        error("RegisterBucketEvent: interval must be a positive number", 2)
    end

    if not ValidateCallback(callback) then
        error("RegisterBucketEvent: callback must be a function or string (method name)", 2)
    end

    EnsureBucketStorage(self)

    -- Normalize events to table
    local eventList = NormalizeEvents(events)

    -- Generate unique handle
    local handle = GenerateBucketHandle()

    -- Create bucket info
    local bucket = {
        handle = handle,
        events = eventList,
        interval = interval,
        callback = callback,
        data = {}, -- Event name -> count
        timerActive = false,
        type = "event",
        registrations = {}, -- Store event registration handles
    }

    self.buckets[handle] = bucket

    -- Register for each event
    for _, eventName in ipairs(eventList) do
        local registration = EventRegistry:RegisterEventCallbackWithHandle(
            eventName,
            function()
                HandleBucketEvent(self, bucket, eventName)
            end,
            self
        )

        bucket.registrations[#bucket.registrations + 1] = registration
    end

    return handle
end

--[[--------------------------------------------------------------------
    Message Bucket Registration
----------------------------------------------------------------------]]

--- Register a bucket for custom messages (via CallbackRegistry)
-- @param messages string|table - Message name or table of message names
-- @param interval number - Seconds to collect messages before firing callback
-- @param callback function|string - Callback function or method name
-- @return string - Bucket handle for unregistration
function LoolibBucketMixin:RegisterBucketMessage(messages, interval, callback)
    -- Validate parameters
    if not ValidateInterval(interval) then
        error("RegisterBucketMessage: interval must be a positive number", 2)
    end

    if not ValidateCallback(callback) then
        error("RegisterBucketMessage: callback must be a function or string (method name)", 2)
    end

    EnsureBucketStorage(self)

    -- Normalize messages to table
    local messageList = NormalizeEvents(messages)

    -- Generate unique handle
    local handle = GenerateBucketHandle()

    -- Create bucket info
    local bucket = {
        handle = handle,
        events = messageList,
        interval = interval,
        callback = callback,
        data = {}, -- Message name -> count
        timerActive = false,
        type = "message",
        registrations = {}, -- Store message registration handles
    }

    self.buckets[handle] = bucket

    -- Register for each message
    for _, messageName in ipairs(messageList) do
        local registration = EventRegistry:RegisterCallbackWithHandle(
            messageName,
            function()
                HandleBucketEvent(self, bucket, messageName)
            end,
            self
        )

        bucket.registrations[#bucket.registrations + 1] = registration
    end

    return handle
end

--[[--------------------------------------------------------------------
    Bucket Unregistration
----------------------------------------------------------------------]]

--- Unregister a bucket by handle
-- @param handle string - Bucket handle returned from Register methods
-- @return boolean - True if unregistered, false if not found
function LoolibBucketMixin:UnregisterBucket(handle)
    if not self.buckets then
        return false
    end

    local bucket = self.buckets[handle]
    if not bucket then
        return false
    end

    -- Unregister all event/message callbacks
    for _, registration in ipairs(bucket.registrations) do
        registration:Unregister()
    end

    -- Remove from storage
    self.buckets[handle] = nil

    return true
end

--- Unregister all buckets for this object
function LoolibBucketMixin:UnregisterAllBuckets()
    if not self.buckets then
        return
    end

    -- Unregister each bucket
    for handle in pairs(self.buckets) do
        self:UnregisterBucket(handle)
    end

    -- Clear storage
    self.buckets = {}
end

--[[--------------------------------------------------------------------
    Bucket Query
----------------------------------------------------------------------]]

--- Check if a bucket exists
-- @param handle string - Bucket handle
-- @return boolean - True if bucket exists and is active
function LoolibBucketMixin:IsBucketActive(handle)
    return self.buckets and self.buckets[handle] ~= nil
end

--- Get all active bucket handles
-- @return table - Array of bucket handles
function LoolibBucketMixin:GetActiveBuckets()
    if not self.buckets then
        return {}
    end

    local handles = {}
    for handle in pairs(self.buckets) do
        handles[#handles + 1] = handle
    end

    return handles
end

--- Get count of active buckets
-- @return number - Number of active buckets
function LoolibBucketMixin:GetBucketCount()
    if not self.buckets then
        return 0
    end

    local count = 0
    for _ in pairs(self.buckets) do
        count = count + 1
    end

    return count
end

--- Get current data for a bucket (without firing it)
-- @param handle string - Bucket handle
-- @return table|nil - Data table { count, events } or nil if not found
function LoolibBucketMixin:GetBucketData(handle)
    if not self.buckets then
        return nil
    end

    local bucket = self.buckets[handle]
    if not bucket then
        return nil
    end

    -- Calculate total count
    local totalCount = 0
    for _, count in pairs(bucket.data) do
        totalCount = totalCount + count
    end

    return {
        count = totalCount,
        events = bucket.data,
    }
end

--- Manually fire a bucket immediately (clears data and resets timer)
-- @param handle string - Bucket handle
-- @return boolean - True if fired, false if not found or no data
function LoolibBucketMixin:FireBucketNow(handle)
    if not self.buckets then
        return false
    end

    local bucket = self.buckets[handle]
    if not bucket then
        return false
    end

    -- Check if there's any data to fire
    local hasData = false
    for _ in pairs(bucket.data) do
        hasData = true
        break
    end

    if not hasData then
        return false
    end

    -- Fire the bucket
    FireBucket(self, bucket)

    return true
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local BucketModule = {
    Mixin = LoolibBucketMixin,
}

Loolib:RegisterModule("Bucket", BucketModule)
