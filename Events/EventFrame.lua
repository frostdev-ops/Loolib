--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    EventFrame - Mixin for frames that handle WoW events

    Provides automatic event registration/unregistration on show/hide,
    which is a common pattern for UI frames that need to respond to
    game events only when visible.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local Events = Loolib.Events or Loolib:GetOrCreateModule("Events")
Loolib.Events = Events

-- FIX(critical-01): Use Loolib.Mixin directly instead of unstable "Mixin" module lookup
local EventRegistryModule = Events.EventRegistry
    or Loolib:GetModule("Events.EventRegistry")
    or Loolib:GetModule("EventRegistry")

assert(Loolib.Mixin, "Loolib/Core/Mixin.lua must be loaded before EventFrame")
assert(EventRegistryModule and EventRegistryModule.Registry, "Loolib/Events/EventRegistry.lua must be loaded before EventFrame")

local ApplyMixin = Loolib.Mixin
local EventRegistry = Events.Registry or EventRegistryModule.Registry
local pairs = pairs
local tostring = tostring
local wipe = wipe

--[[--------------------------------------------------------------------
    EventFrameMixin

    A mixin for frames that need to handle WoW events with
    automatic registration management.
----------------------------------------------------------------------]]

local EventFrameMixin = {}

--- Initialize the event frame
-- Call this in OnLoad
function EventFrameMixin:InitEventFrame()
    self.eventCallbacks = {}
    self.frameEventCallbacks = {}
    self.registeredWhileShown = {}
end

--[[--------------------------------------------------------------------
    Permanent Event Registration

    These events stay registered regardless of frame visibility.
----------------------------------------------------------------------]]

--- Register for a WoW event permanently (regardless of show/hide)
-- @param event string - The WoW event name
-- @param callback function - The callback (receives self, ...)
function EventFrameMixin:RegisterPermanentEvent(event, callback)
    if not self.eventCallbacks then
        self:InitEventFrame()
    end

    self.eventCallbacks[event] = callback
    self:RegisterEvent(event)
end

--- Unregister a permanent event
-- @param event string - The WoW event name
function EventFrameMixin:UnregisterPermanentEvent(event)
    if self.eventCallbacks then
        self.eventCallbacks[event] = nil
    end

    self:UnregisterEvent(event)
end

--[[--------------------------------------------------------------------
    Visibility-Based Event Registration

    These events are only registered when the frame is shown.
----------------------------------------------------------------------]]

--- Register for a WoW event that's only active when frame is shown
-- @param event string - The WoW event name
-- @param callback function - The callback (receives self, ...)
function EventFrameMixin:RegisterFrameEvent(event, callback)
    if not self.frameEventCallbacks then
        self:InitEventFrame()
    end

    self.frameEventCallbacks[event] = callback

    if self:IsShown() then
        self:RegisterEvent(event)
        self.registeredWhileShown[event] = true
    end
end

--- Unregister a visibility-based event
-- @param event string - The WoW event name
function EventFrameMixin:UnregisterFrameEvent(event)
    if self.frameEventCallbacks then
        self.frameEventCallbacks[event] = nil
    end

    if self.registeredWhileShown and self.registeredWhileShown[event] then
        self:UnregisterEvent(event)
        self.registeredWhileShown[event] = nil
    end
end

--[[--------------------------------------------------------------------
    Frame Event Callbacks with Global Registry

    Use the shared Loolib.Events.Registry singleton for event handling.
----------------------------------------------------------------------]]

--- Register for a WoW event via the shared registry
-- Automatically unregisters when frame is hidden
-- @param event string - The WoW event name
-- @param callback function - The callback
-- @param owner any - Registration owner (defaults to self)
function EventFrameMixin:RegisterFrameEventAndCallback(event, callback, owner)
    if not self.globalEventHandles then
        self.globalEventHandles = {}
    end

    owner = owner or self

    local key = event .. tostring(owner)
    if self.globalEventHandles[key] then
        self.globalEventHandles[key]:Unregister()
    end

    if self:IsShown() then
        self.globalEventHandles[key] = EventRegistry:RegisterEventCallbackWithHandle(event, callback, owner)
    end

    if not self.pendingGlobalEvents then
        self.pendingGlobalEvents = {}
    end

    self.pendingGlobalEvents[key] = {
        event = event,
        callback = callback,
        owner = owner,
    }
end

--- Unregister from a global registry event
-- @param event string - The WoW event name
-- @param owner any - The owner (defaults to self)
function EventFrameMixin:UnregisterFrameEventAndCallback(event, owner)
    owner = owner or self

    local key = event .. tostring(owner)
    if self.globalEventHandles and self.globalEventHandles[key] then
        self.globalEventHandles[key]:Unregister()
        self.globalEventHandles[key] = nil
    end

    if self.pendingGlobalEvents then
        self.pendingGlobalEvents[key] = nil
    end
end

--[[--------------------------------------------------------------------
    Show/Hide Handlers
----------------------------------------------------------------------]]

--- Called when frame is shown - registers visibility-based events
function EventFrameMixin:OnShow()
    if self.frameEventCallbacks then
        for event in pairs(self.frameEventCallbacks) do
            self:RegisterEvent(event)
            self.registeredWhileShown[event] = true
        end
    end

    if self.pendingGlobalEvents then
        self.globalEventHandles = self.globalEventHandles or {}
        for key, info in pairs(self.pendingGlobalEvents) do
            self.globalEventHandles[key] = EventRegistry:RegisterEventCallbackWithHandle(
                info.event,
                info.callback,
                info.owner
            )
        end
    end
end

--- Called when frame is hidden - unregisters visibility-based events
function EventFrameMixin:OnHide()
    if self.registeredWhileShown then
        for event in pairs(self.registeredWhileShown) do
            self:UnregisterEvent(event)
        end
        wipe(self.registeredWhileShown)
    end

    if self.globalEventHandles then
        for _, handle in pairs(self.globalEventHandles) do
            handle:Unregister()
        end
        wipe(self.globalEventHandles)
    end
end

--[[--------------------------------------------------------------------
    Event Handler
----------------------------------------------------------------------]]

--- OnEvent handler - dispatches to registered callbacks
-- @param event string - The WoW event name
-- @param ... - Event arguments
function EventFrameMixin:OnEvent(event, ...)
    if self.eventCallbacks and self.eventCallbacks[event] then
        self.eventCallbacks[event](self, ...)
        return
    end

    if self.frameEventCallbacks and self.frameEventCallbacks[event] then
        self.frameEventCallbacks[event](self, ...)
    end
end

--[[--------------------------------------------------------------------
    Cleanup
----------------------------------------------------------------------]]

--- Clean up all event registrations
function EventFrameMixin:CleanupEvents()
    self:UnregisterAllEvents()

    if self.eventCallbacks then
        wipe(self.eventCallbacks)
    end
    if self.frameEventCallbacks then
        wipe(self.frameEventCallbacks)
    end
    if self.registeredWhileShown then
        wipe(self.registeredWhileShown)
    end

    if self.globalEventHandles then
        for _, handle in pairs(self.globalEventHandles) do
            handle:Unregister()
        end
        wipe(self.globalEventHandles)
    end
    if self.pendingGlobalEvents then
        wipe(self.pendingGlobalEvents)
    end
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Check if an event is registered
-- @param event string - The WoW event name
-- @return boolean
function EventFrameMixin:IsEventRegisteredOnFrame(event)
    if self.eventCallbacks and self.eventCallbacks[event] then
        return true
    end
    if self.frameEventCallbacks and self.frameEventCallbacks[event] then
        return true
    end
    return false
end

--- Get all registered events
-- @return table - Array of event names
function EventFrameMixin:GetRegisteredFrameEvents()
    local events = {}
    local seen = {}

    if self.eventCallbacks then
        for event in pairs(self.eventCallbacks) do
            if not seen[event] then
                seen[event] = true
                events[#events + 1] = event
            end
        end
    end

    if self.frameEventCallbacks then
        for event in pairs(self.frameEventCallbacks) do
            if not seen[event] then
                seen[event] = true
                events[#events + 1] = event
            end
        end
    end

    return events
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Apply the EventFrame mixin to a frame and set up handlers
-- @param frame Frame - The frame to enhance
-- @return Frame - The enhanced frame
local function ApplyEventFrameMixin(frame)
    ApplyMixin(frame, EventFrameMixin)
    frame:InitEventFrame()

    frame:HookScript("OnShow", frame.OnShow)
    frame:HookScript("OnHide", frame.OnHide)
    frame:SetScript("OnEvent", frame.OnEvent)

    return frame
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local EventFrameModule = {
    Mixin = EventFrameMixin,
    Apply = ApplyEventFrameMixin,
}

Loolib.Events.EventFrame = EventFrameModule
Loolib.Events.EventFrameMixin = EventFrameMixin
Loolib.Events.ApplyEventFrameMixin = ApplyEventFrameMixin
Loolib.Events.FrameMixin = EventFrameMixin
Loolib.Events.ApplyFrameMixin = ApplyEventFrameMixin

Loolib.EventFrameMixin = EventFrameMixin
Loolib.ApplyEventFrameMixin = ApplyEventFrameMixin

Loolib:RegisterModule("EventFrame", EventFrameModule)
Loolib:RegisterModule("Events.EventFrame", EventFrameModule)
