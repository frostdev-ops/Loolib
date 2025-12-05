--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    EventFrame - Mixin for frames that handle WoW events

    Provides automatic event registration/unregistration on show/hide,
    which is a common pattern for UI frames that need to respond to
    game events only when visible.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibEventFrameMixin

    A mixin for frames that need to handle WoW events with
    automatic registration management.
----------------------------------------------------------------------]]

LoolibEventFrameMixin = {}

--- Initialize the event frame
-- Call this in OnLoad
function LoolibEventFrameMixin:InitEventFrame()
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
function LoolibEventFrameMixin:RegisterPermanentEvent(event, callback)
    if not self.eventCallbacks then
        self:InitEventFrame()
    end

    self.eventCallbacks[event] = callback

    -- Register with the frame directly
    self:RegisterEvent(event)
end

--- Unregister a permanent event
-- @param event string - The WoW event name
function LoolibEventFrameMixin:UnregisterPermanentEvent(event)
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
function LoolibEventFrameMixin:RegisterFrameEvent(event, callback)
    if not self.frameEventCallbacks then
        self:InitEventFrame()
    end

    self.frameEventCallbacks[event] = callback

    -- If currently shown, register immediately
    if self:IsShown() then
        self:RegisterEvent(event)
        self.registeredWhileShown[event] = true
    end
end

--- Unregister a visibility-based event
-- @param event string - The WoW event name
function LoolibEventFrameMixin:UnregisterFrameEvent(event)
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

    Use the global LoolibEventRegistry for event handling.
----------------------------------------------------------------------]]

--- Register for a WoW event via the global registry
-- Automatically unregisters when frame is hidden
-- @param event string - The WoW event name
-- @param callback function - The callback
function LoolibEventFrameMixin:RegisterFrameEventAndCallback(event, callback, owner)
    if not self.globalEventHandles then
        self.globalEventHandles = {}
    end

    owner = owner or self

    -- If we already have a handle for this event/owner, unregister first
    local key = event .. tostring(owner)
    if self.globalEventHandles[key] then
        self.globalEventHandles[key]:Unregister()
    end

    -- Register with global registry if shown
    if self:IsShown() then
        self.globalEventHandles[key] = LoolibEventRegistry:RegisterEventCallbackWithHandle(
            event, callback, owner
        )
    end

    -- Store for re-registration on show
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
function LoolibEventFrameMixin:UnregisterFrameEventAndCallback(event, owner)
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
function LoolibEventFrameMixin:OnShow()
    -- Register frame events
    if self.frameEventCallbacks then
        for event in pairs(self.frameEventCallbacks) do
            self:RegisterEvent(event)
            self.registeredWhileShown[event] = true
        end
    end

    -- Register global events
    if self.pendingGlobalEvents then
        for key, info in pairs(self.pendingGlobalEvents) do
            if not self.globalEventHandles then
                self.globalEventHandles = {}
            end
            self.globalEventHandles[key] = LoolibEventRegistry:RegisterEventCallbackWithHandle(
                info.event, info.callback, info.owner
            )
        end
    end
end

--- Called when frame is hidden - unregisters visibility-based events
function LoolibEventFrameMixin:OnHide()
    -- Unregister frame events (but keep callbacks stored)
    if self.registeredWhileShown then
        for event in pairs(self.registeredWhileShown) do
            self:UnregisterEvent(event)
        end
        wipe(self.registeredWhileShown)
    end

    -- Unregister global events (but keep pending info stored)
    if self.globalEventHandles then
        for key, handle in pairs(self.globalEventHandles) do
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
function LoolibEventFrameMixin:OnEvent(event, ...)
    -- Check permanent callbacks first
    if self.eventCallbacks and self.eventCallbacks[event] then
        self.eventCallbacks[event](self, ...)
        return
    end

    -- Check frame callbacks
    if self.frameEventCallbacks and self.frameEventCallbacks[event] then
        self.frameEventCallbacks[event](self, ...)
        return
    end
end

--[[--------------------------------------------------------------------
    Cleanup
----------------------------------------------------------------------]]

--- Clean up all event registrations
function LoolibEventFrameMixin:CleanupEvents()
    -- Unregister all events from frame
    self:UnregisterAllEvents()

    -- Clear callback tables
    if self.eventCallbacks then
        wipe(self.eventCallbacks)
    end
    if self.frameEventCallbacks then
        wipe(self.frameEventCallbacks)
    end
    if self.registeredWhileShown then
        wipe(self.registeredWhileShown)
    end

    -- Unregister from global registry
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
function LoolibEventFrameMixin:IsEventRegisteredOnFrame(event)
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
function LoolibEventFrameMixin:GetRegisteredFrameEvents()
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
function LoolibApplyEventFrameMixin(frame)
    LoolibMixin(frame, LoolibEventFrameMixin)
    frame:InitEventFrame()

    -- Set up script handlers
    frame:HookScript("OnShow", frame.OnShow)
    frame:HookScript("OnHide", frame.OnHide)
    frame:SetScript("OnEvent", frame.OnEvent)

    return frame
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local EventFrameModule = {
    Mixin = LoolibEventFrameMixin,
    Apply = LoolibApplyEventFrameMixin,
}

Loolib:RegisterModule("EventFrame", EventFrameModule)

-- Also add to Events module
local Events = Loolib:GetOrCreateModule("Events")
Events.FrameMixin = LoolibEventFrameMixin
Events.ApplyFrameMixin = LoolibApplyEventFrameMixin
