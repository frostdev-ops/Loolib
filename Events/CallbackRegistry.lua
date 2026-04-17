--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    CallbackRegistry - Internal event system for component communication

    Based on Blizzard's CallbackRegistryMixin pattern but simplified
    for addon use (no secure frame requirements).

    Dependencies (must be loaded before this file):
    - Core/Loolib.lua (Loolib namespace)
    - Core/Mixin.lua (CreateFromMixins)
    - Core/FunctionUtil.lua (closure helpers)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local Events = Loolib.Events or Loolib:GetOrCreateModule("Events")
Loolib.Events = Events

-- Use Loolib.CreateFromMixins directly (module aliases can shift during load order)
local FunctionUtil = Loolib.FunctionUtil or Loolib:GetModule("Core.FunctionUtil") or Loolib:GetModule("FunctionUtil")

assert(Loolib.CreateFromMixins, "Loolib/Core/Mixin.lua must be loaded before CallbackRegistry")
assert(FunctionUtil and FunctionUtil.GenerateClosure, "Loolib/Core/FunctionUtil.lua must be loaded before CallbackRegistry")

local CreateFromMixins = Loolib.CreateFromMixins
local error = error
local format = string.format
local ipairs = ipairs
local next = next
local pairs = pairs
local pcall = pcall
local select = select
local type = type

--[[--------------------------------------------------------------------
    Callback Types
----------------------------------------------------------------------]]

local CallbackType = {
    Closure = 1,   -- Callbacks with captured arguments
    Function = 2,  -- Simple function callbacks
}

-- INTERNAL: Sentinel value marking a callback that was unregistered while
-- its event was mid-dispatch. TriggerEvent's pairs() loop would otherwise
-- see undefined behavior if we deleted arbitrary keys from the live
-- callback table. Writing a non-nil sentinel to an existing key is
-- well-defined; the sentinel is cleared after dispatch drains in
-- ReconcileDeferredCallbacks.
local TOMBSTONE = {}

-- INTERNAL: Counter for generating unique owner IDs when none provided
local ownerIDCounter = 0

-- INTERNAL: Generate a numeric owner ID for registrations with no explicit owner
local function GenerateOwnerID()
    ownerIDCounter = ownerIDCounter + 1
    return ownerIDCounter
end

--[[--------------------------------------------------------------------
    CallbackRegistryMixin

    A mixin that provides internal event registration and dispatch.
    Components that want to fire custom events should include this mixin.
----------------------------------------------------------------------]]

---@class LoolibCallbackRegistryMixin
local CallbackRegistryMixin = {}

--- Initialize the callback registry
-- Must be called in OnLoad or Init
function CallbackRegistryMixin:OnLoad()
    self.callbackTables = {
        [CallbackType.Closure] = {},
        [CallbackType.Function] = {},
    }
    self.executingEvents = {}
    self.deferredCallbacks = {}
end

--- Define the events this registry can fire
-- @param events table - Array of event name strings
function CallbackRegistryMixin:GenerateCallbackEvents(events)
    if type(events) ~= "table" then
        error("LoolibCallbackRegistry: GenerateCallbackEvents 'events' must be a table", 2)
    end

    self.Event = self.Event or {}
    for _, eventName in ipairs(events) do
        self.Event[eventName] = eventName
    end
end

--- Allow undefined events to be triggered without error
-- @param allowed boolean
function CallbackRegistryMixin:SetUndefinedEventsAllowed(allowed)
    self.isUndefinedEventAllowed = allowed
end

--[[--------------------------------------------------------------------
    Internal Helpers
----------------------------------------------------------------------]]

-- INTERNAL: Get callback table for a given type and event
function CallbackRegistryMixin:GetCallbacksByEvent(callbackType, event)
    local callbackTable = self.callbackTables[callbackType]
    return callbackTable and callbackTable[event]
end

-- INTERNAL: Get or create callback table for a given type and event
function CallbackRegistryMixin:GetOrCreateCallbacksByEvent(callbackType, event)
    local callbackTable = self.callbackTables[callbackType]
    if not callbackTable[event] then
        callbackTable[event] = {}
    end
    return callbackTable[event]
end

-- Iterator safety: during TriggerEvent dispatch, new registrations go
-- into a deferred table to avoid invalidating the active pairs() loop.
-- They are merged back in ReconcileDeferredCallbacks after dispatch.
-- INTERNAL: Get mutable callback table, deferring writes during event dispatch
function CallbackRegistryMixin:GetMutableCallbacksByEvent(callbackType, event)
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

function CallbackRegistryMixin:HasRegistrantsForEvent(event)
    for _, callbackTable in pairs(self.callbackTables) do
        local callbacks = callbackTable[event]
        if callbacks then
            for _, val in pairs(callbacks) do
                if val ~= TOMBSTONE then
                    return true
                end
            end
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
function CallbackRegistryMixin:RegisterCallback(event, func, owner, ...)
    if type(event) ~= "string" then
        error("LoolibCallbackRegistry: RegisterCallback 'event' must be a string", 2)
    end
    if type(func) ~= "function" then
        error("LoolibCallbackRegistry: RegisterCallback 'func' must be a function", 2)
    end

    -- Generate owner ID if not provided
    if owner == nil then
        owner = GenerateOwnerID()
    elseif type(owner) == "number" then
        error("LoolibCallbackRegistry: RegisterCallback 'owner' as number is reserved for internal use", 2)
    end

    -- Ensure we don't have duplicate registrations for same owner/event
    self:UnregisterCallback(event, owner)

    -- Register as closure or function depending on whether extra args provided
    if select("#", ...) > 0 then
        local callbacks = self:GetMutableCallbacksByEvent(CallbackType.Closure, event)
        callbacks[owner] = FunctionUtil.GenerateClosure(func, owner, ...)
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
function CallbackRegistryMixin:RegisterCallbackWithHandle(event, func, owner, ...)
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
function CallbackRegistryMixin:UnregisterCallback(event, owner)
    if type(event) ~= "string" then
        error("LoolibCallbackRegistry: UnregisterCallback 'event' must be a string", 2)
    end
    if owner == nil then
        error("LoolibCallbackRegistry: UnregisterCallback 'owner' must not be nil", 2)
    end

    local removed = false
    local duringDispatch = self.executingEvents[event] ~= nil

    for _, callbackTable in pairs(self.callbackTables) do
        local callbacks = callbackTable[event]
        if callbacks then
            local existing = callbacks[owner]
            if existing ~= nil and existing ~= TOMBSTONE then
                if duringDispatch then
                    -- Tombstone instead of delete: TriggerEvent's pairs() loop
                    -- is iterating this table right now.
                    callbacks[owner] = TOMBSTONE
                else
                    callbacks[owner] = nil
                end
                removed = true
            end
        end
    end

    -- Deferred additions are safe to delete: ReconcileDeferredCallbacks
    -- reads them post-dispatch, and no loop iterates them during dispatch.
    local deferred = self.deferredCallbacks[event]
    if deferred then
        for _, callbacks in pairs(deferred) do
            if callbacks[owner] ~= nil then
                callbacks[owner] = nil
                removed = true
            end
        end
    end

    return removed
end

--- Unregister all callbacks for an owner across all events
-- @param owner any - The owner
function CallbackRegistryMixin:UnregisterAllCallbacks(owner)
    if owner == nil then
        error("LoolibCallbackRegistry: UnregisterAllCallbacks 'owner' must not be nil", 2)
    end

    for _, callbackTable in pairs(self.callbackTables) do
        for event, callbacks in pairs(callbackTable) do
            local existing = callbacks[owner]
            if existing ~= nil and existing ~= TOMBSTONE then
                if self.executingEvents[event] then
                    callbacks[owner] = TOMBSTONE
                else
                    callbacks[owner] = nil
                end
            end
        end
    end

    for _, deferred in pairs(self.deferredCallbacks) do
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
function CallbackRegistryMixin:TriggerEvent(event, ...)
    if type(event) ~= "string" then
        error("LoolibCallbackRegistry: TriggerEvent 'event' must be a string", 2)
    end

    -- Validate event is defined (unless undefined events are allowed)
    if not self.isUndefinedEventAllowed and self.Event and not self.Event[event] then
        error(format("LoolibCallbackRegistry: TriggerEvent event '%s' is not defined", event), 2)
    end

    -- Track nesting for reentrant calls
    local count = (self.executingEvents[event] or 0) + 1
    self.executingEvents[event] = count

    -- Call closure callbacks (owner already captured in closure).
    -- Skip tombstones — those entries were unregistered mid-dispatch.
    local closures = self:GetCallbacksByEvent(CallbackType.Closure, event)
    if closures then
        for _, closure in pairs(closures) do
            if closure ~= TOMBSTONE then
                local success, err = pcall(closure, ...)
                if not success then
                    Loolib:Error("Callback error for event", event, ":", err)
                end
            end
        end
    end

    -- Call function callbacks (pass owner as first arg). Skip tombstones.
    local funcs = self:GetCallbacksByEvent(CallbackType.Function, event)
    if funcs then
        for owner, func in pairs(funcs) do
            if func ~= TOMBSTONE then
                local success, err = pcall(func, owner, ...)
                if not success then
                    Loolib:Error("Callback error for event", event, ":", err)
                end
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

--- INTERNAL: Merge deferred callbacks into main callback tables and
--- clear tombstones left by in-dispatch unregisters.
-- @param event string - The event name
function CallbackRegistryMixin:ReconcileDeferredCallbacks(event)
    -- Step 1: sweep tombstones. Now that dispatch has fully drained it is
    -- safe to delete these keys from the live callback tables.
    for _, callbackTable in pairs(self.callbackTables) do
        local callbacks = callbackTable[event]
        if callbacks then
            for owner, val in pairs(callbacks) do
                if val == TOMBSTONE then
                    callbacks[owner] = nil
                end
            end
        end
    end

    -- Step 2: merge deferred additions into the live tables.
    local deferred = self.deferredCallbacks[event]
    if not deferred then
        return
    end

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
function CallbackRegistryMixin:GetRegisteredEvents()
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
function CallbackRegistryMixin:GetCallbackCount(event)
    if type(event) ~= "string" then
        error("LoolibCallbackRegistry: GetCallbackCount 'event' must be a string", 2)
    end

    local count = 0

    for _, callbackTable in pairs(self.callbackTables) do
        local callbacks = callbackTable[event]
        if callbacks then
            for _, val in pairs(callbacks) do
                if val ~= TOMBSTONE then
                    count = count + 1
                end
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
local function CreateCallbackRegistry()
    local registry = CreateFromMixins(CallbackRegistryMixin)
    registry:OnLoad()
    return registry
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local CallbackRegistryModule = {
    Mixin = CallbackRegistryMixin,
    Create = CreateCallbackRegistry,
}

Loolib.Events.CallbackRegistry = CallbackRegistryModule
Loolib.Events.CallbackRegistryMixin = CallbackRegistryMixin
Loolib.Events.CreateCallbackRegistry = CreateCallbackRegistry

Loolib.CallbackRegistryMixin = CallbackRegistryMixin
Loolib.CreateCallbackRegistry = CreateCallbackRegistry

Loolib:RegisterModule("CallbackRegistry", CallbackRegistryModule)
Loolib:RegisterModule("Events.CallbackRegistry", CallbackRegistryModule)
