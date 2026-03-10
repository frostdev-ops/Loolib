--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    TempTable - Memory-efficient temporary table pooling

    Provides a pool of reusable tables to reduce garbage collection
    pressure when frequently creating/destroying temporary tables.

    Usage:
        local TempTable = Loolib:GetModule("TempTable")
        local t = TempTable:Acquire()
        -- use t...
        TempTable:Release(t)

        -- Or with automatic release:
        local a, b, c = TempTable:UnpackAndRelease(TempTable:Acquire({1, 2, 3}))
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local Core = Loolib.Core or Loolib:GetOrCreateModule("Core")

--[[--------------------------------------------------------------------
    TempTable Module
----------------------------------------------------------------------]]

local TempTable = Core.TempTable or Loolib:GetModule("Core.TempTable") or {}

-- Pool configuration
local POOL_SIZE = 100
local WARN_ON_LEAK = true

-- The pool of available tables
local pool = {}
local poolSize = 0

-- Track acquired tables (for debugging)
local acquired = {}
local acquiredCount = 0

-- Metatable for released tables (prevents accidental use)
local releasedMeta = {
    __index = function(_, _)
        error("Attempted to read from a released TempTable", 2)
    end,
    __newindex = function(_, _, _)
        error("Attempted to write to a released TempTable", 2)
    end,
    __pairs = function()
        error("Attempted to iterate a released TempTable", 2)
    end,
    __ipairs = function()
        error("Attempted to iterate a released TempTable", 2)
    end,
}

--[[--------------------------------------------------------------------
    Core Functions
----------------------------------------------------------------------]]

--- Acquire a table from the pool
-- @param init table|nil - Optional initial values to copy into the table
-- @return table - A clean table ready for use
function TempTable:Acquire(init)
    local t

    if poolSize > 0 then
        t = pool[poolSize]
        pool[poolSize] = nil
        poolSize = poolSize - 1

        -- Remove protection metatable
        setmetatable(t, nil)
    else
        t = {}
    end

    -- Track for debugging
    if WARN_ON_LEAK then
        acquired[t] = debugstack(2)
        acquiredCount = acquiredCount + 1
    end

    -- Copy initial values if provided
    if init then
        if type(init) == "table" then
            for k, v in pairs(init) do
                t[k] = v
            end
        end
    end

    return t
end

--- Release a table back to the pool
-- @param t table - The table to release
function TempTable:Release(t)
    if type(t) ~= "table" then
        error("TempTable:Release() expected table, got " .. type(t), 2)
    end

    -- Check if already released (has protection metatable)
    if getmetatable(t) == releasedMeta then
        error("Attempted to release an already-released TempTable", 2)
    end

    -- Remove from tracking
    if WARN_ON_LEAK then
        acquired[t] = nil
        acquiredCount = acquiredCount - 1
    end

    -- Wipe the table
    wipe(t)

    -- Return to pool if space available
    if poolSize < POOL_SIZE then
        poolSize = poolSize + 1
        pool[poolSize] = t

        -- Add protection metatable to catch accidental use
        setmetatable(t, releasedMeta)
    end
    -- Otherwise let garbage collector handle it
end

--- Unpack table values and release it in one call
-- @param t table - The table to unpack and release
-- @return ... - The unpacked values
function TempTable:UnpackAndRelease(t)
    local n = #t
    if n == 0 then
        self:Release(t)
        return
    end

    -- Store values before wipe
    local values = { unpack(t, 1, n) }
    self:Release(t)

    return unpack(values, 1, n)
end

--- Acquire a table with array values
-- @param ... - Values to add to the table
-- @return table - A table containing the values
function TempTable:AcquireWithValues(...)
    local t = self:Acquire()
    local n = select("#", ...)
    for i = 1, n do
        t[i] = select(i, ...)
    end
    return t
end

--[[--------------------------------------------------------------------
    Debug Functions
----------------------------------------------------------------------]]

--- Get pool statistics
-- @return number, number, number - poolSize, acquiredCount, POOL_SIZE
function TempTable:GetStats()
    return poolSize, acquiredCount, POOL_SIZE
end

--- Check for leaked tables (tables acquired but not released)
-- @return table - Map of leaked tables to their acquisition stack traces
function TempTable:GetLeaks()
    local leaks = {}
    for t, stack in pairs(acquired) do
        leaks[t] = stack
    end
    return leaks
end

--- Print leak warnings to chat
function TempTable:PrintLeaks()
    if acquiredCount == 0 then
        print("|cff00ff00[Loolib TempTable]|r No leaked tables")
        return
    end

    print("|cffff0000[Loolib TempTable]|r " .. acquiredCount .. " leaked table(s):")
    local count = 0
    for _, stack in pairs(acquired) do
        count = count + 1
        if count <= 5 then
            print("  Leak " .. count .. ":")
            print("    " .. stack:sub(1, 200))
        end
    end
    if count > 5 then
        print("  ..." .. (count - 5) .. " more")
    end
end

--- Clear the entire pool (for testing)
function TempTable:ClearPool()
    for i = 1, poolSize do
        pool[i] = nil
    end
    poolSize = 0
end

--- Enable/disable leak warnings
-- @param enabled boolean
function TempTable:SetLeakWarnings(enabled)
    WARN_ON_LEAK = enabled
    if not enabled then
        wipe(acquired)
        acquiredCount = 0
    end
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Core.TempTable = TempTable
Loolib.TempTable = TempTable

Loolib:RegisterModule("Core.TempTable", TempTable)
