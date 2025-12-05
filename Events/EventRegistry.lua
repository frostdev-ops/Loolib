--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    EventRegistry - Singleton for WoW game events

    Provides a central registry for handling WoW events like
    PLAYER_LOGIN, ADDON_LOADED, etc. Uses the CallbackRegistry
    pattern for internal dispatching.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibEventRegistryMixin

    A mixin for handling WoW game events with callback support.
----------------------------------------------------------------------]]

LoolibEventRegistryMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

function LoolibEventRegistryMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)

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
function LoolibEventRegistryMixin:OnEvent(event, ...)
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
function LoolibEventRegistryMixin:RegisterEventCallback(event, callback, owner, ...)
    -- Register with the callback system
    owner = self:RegisterCallback(event, callback, owner, ...)

    -- Track this event
    self.registeredEvents[event] = (self.registeredEvents[event] or 0) + 1

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
function LoolibEventRegistryMixin:UnregisterEventCallback(event, owner)
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
function LoolibEventRegistryMixin:RegisterEventCallbackWithHandle(event, callback, owner, ...)
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
function LoolibEventRegistryMixin:UnregisterAllEventsForOwner(owner)
    -- Get events this owner is registered for
    local eventsToCheck = {}
    for event in pairs(self.registeredEvents) do
        eventsToCheck[#eventsToCheck + 1] = event
    end

    -- Unregister from each event
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
function LoolibEventRegistryMixin:IsEventRegistered(event)
    return self.registeredEvents[event] and self.registeredEvents[event] > 0
end

--- Get the count of callbacks for a specific event
-- @param event string - The WoW event name
-- @return number
function LoolibEventRegistryMixin:GetEventCallbackCount(event)
    return self.registeredEvents[event] or 0
end

--- Get all currently registered WoW events
-- @return table - Array of event names
function LoolibEventRegistryMixin:GetAllRegisteredEvents()
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
function LoolibEventRegistryMixin:RegisterOneShotEvent(event, callback, owner, ...)
    local registry = self
    local capturedArgs = {...}
    local capturedOwner = owner

    -- Create a wrapper that unregisters after firing
    local wrapper = function(actualOwner, ...)
        -- Unregister first (in case callback errors)
        registry:UnregisterEventCallback(event, actualOwner)

        -- Call the original callback
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
function LoolibEventRegistryMixin:RegisterFilteredEvent(event, filter, callback, owner)
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

-- Create the global singleton
LoolibEventRegistry = LoolibCreateFromMixins(LoolibEventRegistryMixin)
LoolibEventRegistry:Init()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local EventRegistryModule = {
    Mixin = LoolibEventRegistryMixin,
    Registry = LoolibEventRegistry,
}

Loolib:RegisterModule("EventRegistry", EventRegistryModule)

-- Also register the singleton for easy access
local Events = Loolib:GetOrCreateModule("Events")
Events.Registry = LoolibEventRegistry
