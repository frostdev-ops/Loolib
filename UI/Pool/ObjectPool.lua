--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ObjectPool - Generic object pooling for efficient reuse

    Based on Blizzard's ObjectPoolMixin pattern. Objects are acquired
    from the pool when needed and released back when done, avoiding
    the overhead of creating/destroying objects frequently.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for ObjectPool")
local Pool = Loolib.Pool or Loolib:GetOrCreateModule("Pool")
local ObjectPoolModule = Pool.ObjectPool or Loolib:GetModule("Pool.ObjectPool") or {}

--[[--------------------------------------------------------------------
    LoolibObjectPoolMixin

    A mixin that provides object pooling functionality.
----------------------------------------------------------------------]]

local ObjectPoolMixin = ObjectPoolModule.Mixin or {}

--- Initialize the pool
-- @param createFunc function - Function that creates new objects: function(pool) -> object
-- @param resetFunc function - Function called on acquire/release: function(pool, object, isNew)
-- @param capacity number - Optional maximum pool capacity (default: unlimited)
function ObjectPoolMixin:Init(createFunc, resetFunc, capacity)
    if type(createFunc) ~= "function" then
        error("LoolibObjectPoolMixin:Init requires createFunc as first argument")
    end

    self.createFunc = createFunc
    self.resetFunc = resetFunc or function() end
    self.capacity = capacity or math.huge

    self.activeObjects = {}
    self.inactiveObjects = {}
    self.activeCount = 0
    self.totalCreated = 0
end

--[[--------------------------------------------------------------------
    Core Pool Operations
----------------------------------------------------------------------]]

--- Acquire an object from the pool
-- Returns an existing inactive object or creates a new one
-- @return any, boolean - The object and whether it's newly created
function ObjectPoolMixin:Acquire()
    -- Check capacity
    if self.activeCount >= self.capacity then
        return nil, false
    end

    -- Try to get an inactive object
    local object = table.remove(self.inactiveObjects)
    local isNew = object == nil

    if isNew then
        -- Create a new object
        object = self.createFunc(self)

        if type(object) ~= "table" then
            error("LoolibObjectPoolMixin: createFunc must return a table")
        end

        self.totalCreated = self.totalCreated + 1

        -- Call reset on new objects
        self:CallReset(object, true)
    end

    -- Mark as active
    self.activeObjects[object] = true
    self.activeCount = self.activeCount + 1

    return object, isNew
end

--- Release an object back to the pool
-- @param object any - The object to release
-- @return boolean - True if the object was active and released
function ObjectPoolMixin:Release(object)
    if not self:IsActive(object) then
        return false
    end

    -- Call reset
    self:CallReset(object, false)

    -- Move to inactive
    self.activeObjects[object] = nil
    self.activeCount = self.activeCount - 1
    self.inactiveObjects[#self.inactiveObjects + 1] = object

    return true
end

--- Release all active objects back to the pool
function ObjectPoolMixin:ReleaseAll()
    for object in pairs(self.activeObjects) do
        self:CallReset(object, false)
        self.inactiveObjects[#self.inactiveObjects + 1] = object
    end

    wipe(self.activeObjects)
    self.activeCount = 0
end

--- Call the reset function on an object
-- @param object any - The object to reset
-- @param isNew boolean - True if this is a newly created object
function ObjectPoolMixin:CallReset(object, isNew)
    local success, err = pcall(self.resetFunc, self, object, isNew)
    if not success then
        Loolib:Error("Pool reset error:", err)
    end
end

--[[--------------------------------------------------------------------
    State Queries
----------------------------------------------------------------------]]

--- Check if an object is currently active (acquired)
-- @param object any - The object to check
-- @return boolean
function ObjectPoolMixin:IsActive(object)
    return self.activeObjects[object] == true
end

--- Check if an object belongs to this pool
-- @param object any - The object to check
-- @return boolean
function ObjectPoolMixin:DoesObjectBelongToPool(object)
    if self.activeObjects[object] then
        return true
    end

    for _, inactive in ipairs(self.inactiveObjects) do
        if inactive == object then
            return true
        end
    end

    return false
end

--- Get the number of active objects
-- @return number
function ObjectPoolMixin:GetNumActive()
    return self.activeCount
end

--- Get the number of inactive (available) objects
-- @return number
function ObjectPoolMixin:GetNumInactive()
    return #self.inactiveObjects
end

--- Get the total number of objects created by this pool
-- @return number
function ObjectPoolMixin:GetTotalCreated()
    return self.totalCreated
end

--- Get the capacity of this pool
-- @return number
function ObjectPoolMixin:GetCapacity()
    return self.capacity
end

--- Check if the pool is at capacity
-- @return boolean
function ObjectPoolMixin:IsAtCapacity()
    return self.activeCount >= self.capacity
end

--[[--------------------------------------------------------------------
    Iteration
----------------------------------------------------------------------]]

--- Iterate over all active objects
-- @return iterator - Pairs iterator over active objects
function ObjectPoolMixin:EnumerateActive()
    return pairs(self.activeObjects)
end

--- Get the next active object (for manual iteration)
-- @param current any - The current object (nil to start)
-- @return any - The next active object
function ObjectPoolMixin:GetNextActive(current)
    return next(self.activeObjects, current)
end

--- Execute a function for each active object
-- @param func function - Function(object) to call
function ObjectPoolMixin:ForEachActive(func)
    for object in pairs(self.activeObjects) do
        func(object)
    end
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Pre-allocate objects up to a certain count
-- @param count number - Number of objects to pre-allocate
function ObjectPoolMixin:Reserve(count)
    local toCreate = count - (self.activeCount + #self.inactiveObjects)

    for i = 1, toCreate do
        local object = self.createFunc(self)
        self:CallReset(object, true)
        self.inactiveObjects[#self.inactiveObjects + 1] = object
        self.totalCreated = self.totalCreated + 1
    end
end

--- Clear all objects from the pool (both active and inactive)
function ObjectPoolMixin:Clear()
    wipe(self.activeObjects)
    wipe(self.inactiveObjects)
    self.activeCount = 0
    self.totalCreated = 0
end

--- Set a new reset function
-- @param resetFunc function - The new reset function
function ObjectPoolMixin:SetResetFunc(resetFunc)
    self.resetFunc = resetFunc or function() end
end

--- Set the pool capacity
-- @param capacity number - The new capacity
function ObjectPoolMixin:SetCapacity(capacity)
    self.capacity = capacity or math.huge
end

--- Debug: Print pool statistics
function ObjectPoolMixin:Dump()
    print(string.format("Pool Stats: Active=%d, Inactive=%d, Total=%d, Capacity=%s",
        self.activeCount,
        #self.inactiveObjects,
        self.totalCreated,
        self.capacity == math.huge and "unlimited" or tostring(self.capacity)
    ))
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new object pool
-- @param createFunc function - Function that creates new objects
-- @param resetFunc function - Optional reset function
-- @param capacity number - Optional maximum capacity
-- @return table - A new ObjectPool instance
local function CreateObjectPool(createFunc, resetFunc, capacity)
    local pool = CreateFromMixins(ObjectPoolMixin)
    pool:Init(createFunc, resetFunc, capacity)
    return pool
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

ObjectPoolModule.Mixin = ObjectPoolMixin
ObjectPoolModule.Create = CreateObjectPool

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.ObjectPool = ObjectPoolModule
UI.CreateObjectPool = CreateObjectPool

Pool.ObjectPool = ObjectPoolModule
Loolib.ObjectPoolMixin = ObjectPoolMixin
Loolib.CreateObjectPool = CreateObjectPool

Loolib:RegisterModule("Pool.ObjectPool", ObjectPoolModule)
