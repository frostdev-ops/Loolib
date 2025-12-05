--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    CallbackRegistry - Internal event system for component communication

    Based on Blizzard's CallbackRegistryMixin pattern but simplified
    for addon use (no secure frame requirements).
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Callback Types
----------------------------------------------------------------------]]

local CallbackType = {
    Closure = 1,   -- Callbacks with captured arguments
    Function = 2,  -- Simple function callbacks
}

-- Counter for generating unique owner IDs when none provided
local ownerIDCounter = 0
local function GenerateOwnerID()
    ownerIDCounter = ownerIDCounter + 1
    return ownerIDCounter
end

--[[--------------------------------------------------------------------
    LoolibCallbackRegistryMixin

    A mixin that provides internal event registration and dispatch.
    Components that want to fire custom events should include this mixin.
----------------------------------------------------------------------]]

LoolibCallbackRegistryMixin = {}

--- Initialize the callback registry
-- Must be called in OnLoad or Init
function LoolibCallbackRegistryMixin:OnLoad()
    self.callbackTables = {
        [CallbackType.Closure] = {},
        [CallbackType.Function] = {},
    }
    self.executingEvents = {}
    self.deferredCallbacks = {}
end

--- Define the events this registry can fire
-- @param events table - Array of event name strings
function LoolibCallbackRegistryMixin:GenerateCallbackEvents(events)
    self.Event = self.Event or {}
    for _, eventName in ipairs(events) do
        self.Event[eventName] = eventName
    end
end

--- Allow undefined events to be triggered without error
-- @param allowed boolean
function LoolibCallbackRegistryMixin:SetUndefinedEventsAllowed(allowed)
    self.isUndefinedEventAllowed = allowed
end

--[[--------------------------------------------------------------------
    Internal Helpers
----------------------------------------------------------------------]]

function LoolibCallbackRegistryMixin:GetCallbacksByEvent(callbackType, event)
    local callbackTable = self.callbackTables[callbackType]
    return callbackTable and callbackTable[event]
end

function LoolibCallbackRegistryMixin:GetOrCreateCallbacksByEvent(callbackType, event)
    local callbackTable = self.callbackTables[callbackType]
    if not callbackTable[event] then
        callbackTable[event] = {}
    end
    return callbackTable[event]
end

function LoolibCallbackRegistryMixin:GetMutableCallbacksByEvent(callbackType, event)
    -- If we're currently executing this event, use deferred callbacks
    -- to avoid modifying the table we're iterating
    if self.executingEvents[event] then
        if not self.deferredCallbacks[event] then
            self.deferredCallbacks[event] = {}
        end
        if not self.deferredCallbacks[event][callbackType] then
            self.deferredCallbacks[event][callbackType] = {}
        end
        return self.deferredCallbacks[event][callbackType]
    end

    return self:GetOrCreateCallbacksByEvent(callbackType, event)
end

function LoolibCallbackRegistryMixin:HasRegistrantsForEvent(event)
    for _, callbackTable in pairs(self.callbackTables) do
        local callbacks = callbackTable[event]
        if callbacks and next(callbacks) then
            return true
        end
    end
    return false
end

--[[--------------------------------------------------------------------
    Registration
----------------------------------------------------------------------]]

--- Register a callback for an event
-- @param event string - The event name
-- @param func function - The callback function
-- @param owner any - The owner (used to unregister). If nil, one is generated.
-- @param ... - Optional arguments to capture (makes it a closure)
-- @return any - The owner (for later unregistration)
function LoolibCallbackRegistryMixin:RegisterCallback(event, func, owner, ...)
    if type(event) ~= "string" then
        error("LoolibCallbackRegistryMixin:RegisterCallback 'event' requires string type.")
    end
    if type(func) ~= "function" then
        error("LoolibCallbackRegistryMixin:RegisterCallback 'func' requires function type.")
    end

    -- Generate owner ID if not provided
    if owner == nil then
        owner = GenerateOwnerID()
    elseif type(owner) == "number" then
        error("LoolibCallbackRegistryMixin:RegisterCallback 'owner' as number is reserved internally.")
    end

    -- Ensure we don't have duplicate registrations for same owner/event
    self:UnregisterCallback(event, owner)

    -- Register as closure or function depending on whether extra args provided
    local count = select("#", ...)
    if count > 0 then
        local callbacks = self:GetMutableCallbacksByEvent(CallbackType.Closure, event)
        callbacks[owner] = LoolibFunctionUtil.GenerateClosure(func, owner, ...)
    else
        local callbacks = self:GetMutableCallbacksByEvent(CallbackType.Function, event)
        callbacks[owner] = func
    end

    return owner
end

--- Register a callback and return a handle for easy unregistration
-- @param event string - The event name
-- @param func function - The callback function
-- @param owner any - The owner
-- @param ... - Optional arguments to capture
-- @return table - Handle with Unregister() method
function LoolibCallbackRegistryMixin:RegisterCallbackWithHandle(event, func, owner, ...)
    owner = self:RegisterCallback(event, func, owner, ...)

    local registry = self
    return {
        Unregister = function()
            registry:UnregisterCallback(event, owner)
        end,
    }
end

--- Unregister a callback
-- @param event string - The event name
-- @param owner any - The owner that registered the callback
-- @return boolean - True if a callback was removed
function LoolibCallbackRegistryMixin:UnregisterCallback(event, owner)
    local removed = false

    for _, callbackTable in pairs(self.callbackTables) do
        local callbacks = callbackTable[event]
        if callbacks and callbacks[owner] then
            callbacks[owner] = nil
            removed = true
        end
    end

    -- Also check deferred callbacks
    local deferred = self.deferredCallbacks[event]
    if deferred then
        for _, callbacks in pairs(deferred) do
            if callbacks[owner] then
                callbacks[owner] = nil
                removed = true
            end
        end
    end

    return removed
end

--- Unregister all callbacks for an owner across all events
-- @param owner any - The owner
function LoolibCallbackRegistryMixin:UnregisterAllCallbacks(owner)
    for _, callbackTable in pairs(self.callbackTables) do
        for event, callbacks in pairs(callbackTable) do
            callbacks[owner] = nil
        end
    end

    for event, deferred in pairs(self.deferredCallbacks) do
        for _, callbacks in pairs(deferred) do
            callbacks[owner] = nil
        end
    end
end

--[[--------------------------------------------------------------------
    Event Dispatch
----------------------------------------------------------------------]]

--- Trigger an event, calling all registered callbacks
-- @param event string - The event name
-- @param ... - Arguments to pass to callbacks
function LoolibCallbackRegistryMixin:TriggerEvent(event, ...)
    if type(event) ~= "string" then
        error("LoolibCallbackRegistryMixin:TriggerEvent 'event' requires string type.")
    end

    -- Validate event is defined (unless undefined events are allowed)
    if not self.isUndefinedEventAllowed and self.Event and not self.Event[event] then
        error(string.format("LoolibCallbackRegistryMixin:TriggerEvent event '%s' doesn't exist.", event))
    end

    -- Track nesting for reentrant calls
    local count = (self.executingEvents[event] or 0) + 1
    self.executingEvents[event] = count

    -- Call closure callbacks (owner already captured in closure)
    local closures = self:GetCallbacksByEvent(CallbackType.Closure, event)
    if closures then
        for owner, closure in pairs(closures) do
            local success, err = pcall(closure, ...)
            if not success then
                Loolib:Error("Callback error for event", event, ":", err)
            end
        end
    end

    -- Call function callbacks (pass owner as first arg)
    local funcs = self:GetCallbacksByEvent(CallbackType.Function, event)
    if funcs then
        for owner, func in pairs(funcs) do
            local success, err = pcall(func, owner, ...)
            if not success then
                Loolib:Error("Callback error for event", event, ":", err)
            end
        end
    end

    -- Reconcile deferred callbacks after dispatch
    count = count - 1
    if count == 0 then
        self.executingEvents[event] = nil
        self:ReconcileDeferredCallbacks(event)
    else
        self.executingEvents[event] = count
    end
end

--- Merge deferred callbacks into main callback tables
-- @param event string - The event name
function LoolibCallbackRegistryMixin:ReconcileDeferredCallbacks(event)
    local deferred = self.deferredCallbacks[event]
    if not deferred then return end

    for callbackType, callbacks in pairs(deferred) do
        local target = self:GetOrCreateCallbacksByEvent(callbackType, event)
        for owner, callback in pairs(callbacks) do
            target[owner] = callback
        end
    end

    self.deferredCallbacks[event] = nil
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Get all registered events
-- @return table - Array of event names
function LoolibCallbackRegistryMixin:GetRegisteredEvents()
    local events = {}
    local seen = {}

    for _, callbackTable in pairs(self.callbackTables) do
        for event in pairs(callbackTable) do
            if not seen[event] then
                seen[event] = true
                events[#events + 1] = event
            end
        end
    end

    return events
end

--- Get the count of callbacks registered for an event
-- @param event string - The event name
-- @return number
function LoolibCallbackRegistryMixin:GetCallbackCount(event)
    local count = 0

    for _, callbackTable in pairs(self.callbackTables) do
        local callbacks = callbackTable[event]
        if callbacks then
            for _ in pairs(callbacks) do
                count = count + 1
            end
        end
    end

    return count
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new callback registry instance
-- @return table - A new CallbackRegistry object
function CreateLoolibCallbackRegistry()
    local registry = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)
    registry:OnLoad()
    return registry
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local CallbackRegistryModule = {
    Mixin = LoolibCallbackRegistryMixin,
    Create = CreateLoolibCallbackRegistry,
}

Loolib:RegisterModule("CallbackRegistry", CallbackRegistryModule)
