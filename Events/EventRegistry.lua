--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    EventRegistry - Singleton for WoW game events

    Provides a central registry for handling WoW events like
    PLAYER_LOGIN, ADDON_LOADED, etc. Uses the CallbackRegistry
    pattern for internal dispatching.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local Events = Loolib.Events or Loolib:GetOrCreateModule("Events")
Loolib.Events = Events

-- Use Loolib.CreateFromMixins directly (module aliases can shift during load order)
local CallbackRegistryModule = Events.CallbackRegistry
    or Loolib:GetModule("Events.CallbackRegistry")
    or Loolib:GetModule("CallbackRegistry")

assert(Loolib.CreateFromMixins, "Loolib/Core/Mixin.lua must be loaded before EventRegistry")
assert(CallbackRegistryModule and CallbackRegistryModule.Mixin, "Loolib/Events/CallbackRegistry.lua must be loaded before EventRegistry")

local CallbackRegistryMixin = Events.CallbackRegistryMixin or CallbackRegistryModule.Mixin
local CreateFromMixins = Loolib.CreateFromMixins
local CreateFrame = CreateFrame
local error = error
local ipairs = ipairs
local pairs = pairs
local type = type
---@diagnostic disable-next-line: undefined-field
local unpack = unpack or table.unpack

--[[--------------------------------------------------------------------
    EventRegistryMixin

    A mixin for handling WoW game events with callback support.
----------------------------------------------------------------------]]

local EventRegistryMixin = CreateFromMixins(CallbackRegistryMixin)

function EventRegistryMixin:Init()
    CallbackRegistryMixin.OnLoad(self)

    -- Allow any WoW event to be used
    self:SetUndefinedEventsAllowed(true)

    -- Create the event frame
    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)

    -- Track registered events and their callback counts
    self.registeredEvents = {}
end

--[[--------------------------------------------------------------------
    Event Handling
----------------------------------------------------------------------]]

--- Called when a WoW event fires
-- @param event string - The event name
-- @param ... - Event arguments
function EventRegistryMixin:OnEvent(event, ...)
    self:TriggerEvent(event, ...)
end

--[[--------------------------------------------------------------------
    Registration
----------------------------------------------------------------------]]

--- Register a callback for a WoW event
-- @param event string - The WoW event name (e.g., "PLAYER_LOGIN")
-- @param callback function - The callback function
-- @param owner any - The owner for unregistration
-- @param ... - Optional captured arguments
-- @return any - The owner
function EventRegistryMixin:RegisterEventCallback(event, callback, owner, ...)
    if type(event) ~= "string" then
        error("LoolibEventRegistry: RegisterEventCallback 'event' must be a string", 2)
    end
    if type(callback) ~= "function" then
        error("LoolibEventRegistry: RegisterEventCallback 'callback' must be a function", 2)
    end

    -- RegisterCallback internally calls UnregisterCallback first for the
    -- same (event, owner). Only increment the ref count when this is a genuinely new
    -- registration, not a replacement, to prevent count inflation that leaks WoW events.
    local isReplacement = false
    if owner ~= nil then
        for _, callbackTable in pairs(self.callbackTables or {}) do
            if callbackTable[event] and callbackTable[event][owner] then
                isReplacement = true
                break
            end
        end
    end

    owner = self:RegisterCallback(event, callback, owner, ...)

    if not isReplacement then
        self.registeredEvents[event] = (self.registeredEvents[event] or 0) + 1
    end

    -- Register with WoW if this is the first callback for this event
    if self.registeredEvents[event] == 1 then
        self.frame:RegisterEvent(event)
    end

    return owner
end

--- Unregister a callback for a WoW event
-- @param event string - The WoW event name
-- @param owner any - The owner that registered the callback
-- @return boolean - True if a callback was removed
function EventRegistryMixin:UnregisterEventCallback(event, owner)
    if type(event) ~= "string" then
        error("LoolibEventRegistry: UnregisterEventCallback 'event' must be a string", 2)
    end
    if owner == nil then
        error("LoolibEventRegistry: UnregisterEventCallback 'owner' must not be nil", 2)
    end

    local removed = self:UnregisterCallback(event, owner)

    if removed then
        self.registeredEvents[event] = (self.registeredEvents[event] or 1) - 1

        -- Unregister from WoW if no more callbacks for this event
        if self.registeredEvents[event] <= 0 then
            self.registeredEvents[event] = nil
            self.frame:UnregisterEvent(event)
        end
    end

    return removed
end

--- Register for a WoW event and get a handle for easy cleanup
-- @param event string - The WoW event name
-- @param callback function - The callback function
-- @param owner any - The owner
-- @param ... - Optional captured arguments
-- @return table - Handle with Unregister() method
function EventRegistryMixin:RegisterEventCallbackWithHandle(event, callback, owner, ...)
    owner = self:RegisterEventCallback(event, callback, owner, ...)

    local registry = self
    return {
        Unregister = function()
            registry:UnregisterEventCallback(event, owner)
        end,
    }
end

--- Unregister all event callbacks for an owner
-- @param owner any - The owner
function EventRegistryMixin:UnregisterAllEventsForOwner(owner)
    if owner == nil then
        error("LoolibEventRegistry: UnregisterAllEventsForOwner 'owner' must not be nil", 2)
    end

    local eventsToCheck = {}
    for event in pairs(self.registeredEvents) do
        eventsToCheck[#eventsToCheck + 1] = event
    end

    for _, event in ipairs(eventsToCheck) do
        self:UnregisterEventCallback(event, owner)
    end
end

--[[--------------------------------------------------------------------
    Convenience Methods
----------------------------------------------------------------------]]

--- Check if an event is currently being listened for
-- @param event string - The WoW event name
-- @return boolean
function EventRegistryMixin:IsEventRegistered(event)
    return self.registeredEvents[event] and self.registeredEvents[event] > 0
end

--- Get the count of callbacks for a specific event
-- @param event string - The WoW event name
-- @return number
function EventRegistryMixin:GetEventCallbackCount(event)
    return self.registeredEvents[event] or 0
end

--- Get all currently registered WoW events
-- @return table - Array of event names
function EventRegistryMixin:GetAllRegisteredEvents()
    local events = {}
    for event in pairs(self.registeredEvents) do
        events[#events + 1] = event
    end
    return events
end

--[[--------------------------------------------------------------------
    One-Shot Events
----------------------------------------------------------------------]]

--- Register a callback that automatically unregisters after firing once
-- @param event string - The WoW event name
-- @param callback function - The callback function
-- @param owner any - The owner
-- @param ... - Optional captured arguments
-- @return any - The owner
function EventRegistryMixin:RegisterOneShotEvent(event, callback, owner, ...)
    if type(event) ~= "string" then
        error("LoolibEventRegistry: RegisterOneShotEvent 'event' must be a string", 2)
    end
    if type(callback) ~= "function" then
        error("LoolibEventRegistry: RegisterOneShotEvent 'callback' must be a function", 2)
    end

    local registry = self
    local capturedArgs = {...}

    local wrapper = function(actualOwner, ...)
        registry:UnregisterEventCallback(event, actualOwner)

        if #capturedArgs > 0 then
            callback(actualOwner, unpack(capturedArgs), ...)
        else
            callback(actualOwner, ...)
        end
    end

    return self:RegisterEventCallback(event, wrapper, owner)
end

--[[--------------------------------------------------------------------
    Filtered Events
----------------------------------------------------------------------]]

--- Register a callback with a filter function
-- @param event string - The WoW event name
-- @param filter function - Function(owner, ...) that returns true to call callback
-- @param callback function - The callback function (called if filter returns true)
-- @param owner any - The owner
-- @return any - The owner
function EventRegistryMixin:RegisterFilteredEvent(event, filter, callback, owner)
    if type(event) ~= "string" then
        error("LoolibEventRegistry: RegisterFilteredEvent 'event' must be a string", 2)
    end
    if type(filter) ~= "function" then
        error("LoolibEventRegistry: RegisterFilteredEvent 'filter' must be a function", 2)
    end
    if type(callback) ~= "function" then
        error("LoolibEventRegistry: RegisterFilteredEvent 'callback' must be a function", 2)
    end

    local wrapper = function(actualOwner, ...)
        if filter(actualOwner, ...) then
            callback(actualOwner, ...)
        end
    end

    return self:RegisterEventCallback(event, wrapper, owner)
end

--[[--------------------------------------------------------------------
    Singleton Instance
----------------------------------------------------------------------]]

local EventRegistry = CreateFromMixins(EventRegistryMixin)
EventRegistry:Init()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local EventRegistryModule = {
    Mixin = EventRegistryMixin,
    Registry = EventRegistry,
}

Loolib.Events.EventRegistry = EventRegistryModule
Loolib.Events.EventRegistryMixin = EventRegistryMixin
Loolib.Events.Registry = EventRegistry

Loolib.EventRegistryMixin = EventRegistryMixin
Loolib.EventRegistry = EventRegistry

Loolib:RegisterModule("EventRegistry", EventRegistryModule)
Loolib:RegisterModule("Events.EventRegistry", EventRegistryModule)
