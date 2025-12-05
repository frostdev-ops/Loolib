--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    PoolCollection - Manage multiple pools by template/type

    A pool collection manages multiple frame pools, automatically
    creating pools for new template types and routing releases
    to the correct pool.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibPoolCollectionMixin

    Manages multiple pools indexed by template name.
----------------------------------------------------------------------]]

LoolibPoolCollectionMixin = {}

--- Initialize the pool collection
function LoolibPoolCollectionMixin:Init()
    self.pools = {}
end

--[[--------------------------------------------------------------------
    Pool Management
----------------------------------------------------------------------]]

--- Generate a unique key for a pool
-- @param frameType string - The frame type
-- @param parent Frame - The parent frame
-- @param template string - The template name
-- @param specialization any - Optional additional key component
-- @return string - A unique pool key
function LoolibPoolCollectionMixin:GeneratePoolKey(frameType, parent, template, specialization)
    local parentKey = parent and tostring(parent) or "nil"
    local templateKey = template or ""
    local specKey = specialization and tostring(specialization) or ""

    return string.format("%s:%s:%s:%s", frameType, parentKey, templateKey, specKey)
end

--- Get an existing pool
-- @param frameType string - The frame type
-- @param parent Frame - The parent frame
-- @param template string - The template name
-- @param specialization any - Optional additional key component
-- @return table|nil - The pool or nil if not found
function LoolibPoolCollectionMixin:GetPool(frameType, parent, template, specialization)
    local key = self:GeneratePoolKey(frameType, parent, template, specialization)
    return self.pools[key]
end

--- Create a new pool
-- @param frameType string - The frame type
-- @param parent Frame - The parent frame
-- @param template string - The template name
-- @param resetFunc function - Optional reset function
-- @param specialization any - Optional additional key component
-- @param capacity number - Optional maximum capacity
-- @return table - The new pool
function LoolibPoolCollectionMixin:CreatePool(frameType, parent, template, resetFunc, specialization, capacity)
    local key = self:GeneratePoolKey(frameType, parent, template, specialization)

    if self.pools[key] then
        error("LoolibPoolCollectionMixin:CreatePool - Pool already exists for key: " .. key)
    end

    local pool = CreateLoolibFramePool(frameType, parent, template, resetFunc, capacity)
    pool.collectionKey = key

    self.pools[key] = pool

    return pool
end

--- Get an existing pool or create a new one
-- @param frameType string - The frame type
-- @param parent Frame - The parent frame
-- @param template string - The template name
-- @param resetFunc function - Optional reset function
-- @param specialization any - Optional additional key component
-- @param capacity number - Optional maximum capacity
-- @return table, boolean - The pool and whether it was newly created
function LoolibPoolCollectionMixin:GetOrCreatePool(frameType, parent, template, resetFunc, specialization, capacity)
    local pool = self:GetPool(frameType, parent, template, specialization)

    if pool then
        return pool, false
    end

    return self:CreatePool(frameType, parent, template, resetFunc, specialization, capacity), true
end

--[[--------------------------------------------------------------------
    Acquire/Release
----------------------------------------------------------------------]]

--- Acquire a frame from the appropriate pool
-- @param frameType string - The frame type
-- @param parent Frame - The parent frame
-- @param template string - The template name
-- @param resetFunc function - Optional reset function
-- @param specialization any - Optional additional key component
-- @return Frame, boolean - The frame and whether it was newly created
function LoolibPoolCollectionMixin:Acquire(frameType, parent, template, resetFunc, specialization)
    local pool = self:GetOrCreatePool(frameType, parent, template, resetFunc, specialization)
    return pool:Acquire()
end

--- Acquire a frame by template only (searches pools)
-- @param template string - The template name to find
-- @return Frame, boolean|nil - The frame and isNew, or nil if no matching pool
function LoolibPoolCollectionMixin:AcquireByTemplate(template)
    for key, pool in pairs(self.pools) do
        if pool.template == template then
            return pool:Acquire()
        end
    end
    return nil
end

--- Release a frame back to its pool
-- @param object Frame - The frame to release
-- @return boolean - True if the frame was released
function LoolibPoolCollectionMixin:Release(object)
    -- Try each pool until we find the right one
    for key, pool in pairs(self.pools) do
        if pool:IsActive(object) then
            return pool:Release(object)
        end
    end

    -- Object not found in any pool
    Loolib:Error("PoolCollection:Release - Object not found in any pool")
    return false
end

--- Release all frames from all pools
function LoolibPoolCollectionMixin:ReleaseAll()
    for key, pool in pairs(self.pools) do
        pool:ReleaseAll()
    end
end

--- Release all frames from a specific pool
-- @param frameType string - The frame type
-- @param parent Frame - The parent frame
-- @param template string - The template name
-- @param specialization any - Optional additional key component
function LoolibPoolCollectionMixin:ReleaseAllByPool(frameType, parent, template, specialization)
    local pool = self:GetPool(frameType, parent, template, specialization)
    if pool then
        pool:ReleaseAll()
    end
end

--[[--------------------------------------------------------------------
    Iteration
----------------------------------------------------------------------]]

--- Iterate over all active objects in all pools
-- @return iterator
function LoolibPoolCollectionMixin:EnumerateActive()
    local pools = {}
    for _, pool in pairs(self.pools) do
        pools[#pools + 1] = pool
    end

    local poolIndex = 1
    local currentObject = nil

    return function()
        while poolIndex <= #pools do
            local pool = pools[poolIndex]
            currentObject = pool:GetNextActive(currentObject)

            if currentObject then
                return currentObject
            else
                poolIndex = poolIndex + 1
                currentObject = nil
            end
        end
        return nil
    end
end

--- Iterate over all active objects in a specific pool
-- @param frameType string - The frame type
-- @param parent Frame - The parent frame
-- @param template string - The template name
-- @param specialization any - Optional additional key component
-- @return iterator
function LoolibPoolCollectionMixin:EnumerateActiveByPool(frameType, parent, template, specialization)
    local pool = self:GetPool(frameType, parent, template, specialization)
    if pool then
        return pool:EnumerateActive()
    end
    return function() return nil end
end

--- Iterate over all pools
-- @return iterator
function LoolibPoolCollectionMixin:EnumeratePools()
    return pairs(self.pools)
end

--[[--------------------------------------------------------------------
    State Queries
----------------------------------------------------------------------]]

--- Get the total number of active objects across all pools
-- @return number
function LoolibPoolCollectionMixin:GetNumActive()
    local count = 0
    for _, pool in pairs(self.pools) do
        count = count + pool:GetNumActive()
    end
    return count
end

--- Get the number of pools
-- @return number
function LoolibPoolCollectionMixin:GetNumPools()
    local count = 0
    for _ in pairs(self.pools) do
        count = count + 1
    end
    return count
end

--- Check if an object is active in any pool
-- @param object any - The object to check
-- @return boolean
function LoolibPoolCollectionMixin:IsActive(object)
    for _, pool in pairs(self.pools) do
        if pool:IsActive(object) then
            return true
        end
    end
    return false
end

--- Find which pool an object belongs to
-- @param object any - The object to find
-- @return table|nil - The pool, or nil if not found
function LoolibPoolCollectionMixin:FindPoolForObject(object)
    for _, pool in pairs(self.pools) do
        if pool:DoesObjectBelongToPool(object) then
            return pool
        end
    end
    return nil
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Clear all pools
function LoolibPoolCollectionMixin:Clear()
    for _, pool in pairs(self.pools) do
        pool:Clear()
    end
    wipe(self.pools)
end

--- Debug: Print statistics for all pools
function LoolibPoolCollectionMixin:Dump()
    print("Pool Collection Statistics:")
    print(string.format("  Total Pools: %d", self:GetNumPools()))
    print(string.format("  Total Active: %d", self:GetNumActive()))
    print("")

    for key, pool in pairs(self.pools) do
        print(string.format("  [%s]", key))
        print(string.format("    Active: %d, Inactive: %d, Total: %d",
            pool:GetNumActive(),
            pool:GetNumInactive(),
            pool:GetTotalCreated()
        ))
    end
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new pool collection
-- @return table - A new PoolCollection instance
function CreateLoolibPoolCollection()
    local collection = LoolibCreateFromMixins(LoolibPoolCollectionMixin)
    collection:Init()
    return collection
end

--- Create a new pool collection pre-configured for frames
-- @return table - A new PoolCollection instance
function CreateLoolibFramePoolCollection()
    return CreateLoolibPoolCollection()
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local PoolCollectionModule = {
    Mixin = LoolibPoolCollectionMixin,
    Create = CreateLoolibPoolCollection,
    CreateFramePoolCollection = CreateLoolibFramePoolCollection,
}

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.PoolCollection = PoolCollectionModule
UI.CreatePoolCollection = CreateLoolibPoolCollection
UI.CreateFramePoolCollection = CreateLoolibFramePoolCollection

Loolib:RegisterModule("PoolCollection", PoolCollectionModule)
