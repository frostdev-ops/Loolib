# ObjectPool

Generic object pooling for efficient reuse. Based on Blizzard's `ObjectPoolMixin` pattern. Objects are acquired from the pool when needed and released back when done, avoiding repeated creation/destruction overhead.

## Module Access

```lua
local Loolib = LibStub("Loolib")

-- Factory function
local pool = Loolib.CreateObjectPool(createFunc, resetFunc, capacity)

-- Mixin (for custom pool types)
local ObjectPoolMixin = Loolib.ObjectPoolMixin
```

## Factory

### CreateObjectPool(createFunc, resetFunc, capacity)

Create a new object pool.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `createFunc` | function | Yes | `function(pool) -> object`. Called when pool is empty and a new object is needed. |
| `resetFunc` | function | No | `function(pool, object, isNew)`. Called on release and on first creation. Defaults to noop. |
| `capacity` | number | No | Maximum active objects. Defaults to unlimited. |

```lua
local pool = Loolib.CreateObjectPool(
    function(pool) return {} end,
    function(pool, obj, isNew) wipe(obj) end,
    50
)
```

## Mixin API (LoolibObjectPoolMixin)

### Init(createFunc, resetFunc, capacity)

Initialize pool state. Called automatically by `CreateObjectPool`. Validates:
- `createFunc` must be a function (error if not)
- `resetFunc` must be function or nil
- `capacity` must be number or nil

### Acquire() -> object, isNew

Acquire an object from the pool.

- If inactive objects exist, returns one from the inactive list.
- If no inactive objects exist, calls `createFunc` to make a new one, then calls `resetFunc(pool, object, true)`.
- If at capacity, returns `nil, false`.
- The returned object is tracked as active.

```lua
local obj, isNew = pool:Acquire()
if obj then
    -- use obj
end
```

### Release(object) -> boolean

Release an object back to the pool.

- Returns `true` if the object was active and successfully released.
- Returns `false` if the object is not active in this pool (safe against double-release).
- Calls `resetFunc(pool, object, false)` before moving to inactive.
- Errors if called with `nil`.

```lua
local released = pool:Release(obj)
```

### ReleaseAll()

Release all active objects. Calls reset on each before moving to inactive.

### CallReset(object, isNew)

*INTERNAL.* Calls the reset function wrapped in `pcall`. Logs errors via `Loolib:Error` but does not re-raise them.

### IsActive(object) -> boolean

Returns `true` if the object is currently acquired from this pool.

### DoesObjectBelongToPool(object) -> boolean

Returns `true` if the object is in either the active or inactive set. Note: the inactive check is O(n).

### GetNumActive() -> number

Number of currently acquired objects.

### GetNumInactive() -> number

Number of objects available for reuse.

### GetTotalCreated() -> number

Lifetime count of objects created by this pool.

### GetCapacity() -> number

Current capacity (may be `math.huge` for unlimited).

### IsAtCapacity() -> boolean

`true` if `activeCount >= capacity`.

### EnumerateActive() -> iterator

`pairs`-style iterator over active objects. Values are always `true`.

```lua
for obj in pool:EnumerateActive() do
    -- process obj
end
```

### GetNextActive(current) -> object

Manual iteration via `next()`. Pass `nil` to start.

### ForEachActive(func)

Call `func(object)` for every active object. `func` must be a function.

### Reserve(count)

Pre-allocate up to `count` total objects (active + inactive). Creates new objects and calls reset on each. `count` must be a number.

### Clear()

Destroy all pool state. Wipes both active and inactive sets. Resets counters to 0.

### SetResetFunc(resetFunc)

Replace the reset function. Must be a function or nil.

### SetCapacity(capacity)

Replace the capacity. Must be a number or nil (nil resets to unlimited).

### Dump()

Print pool statistics to chat: active, inactive, total, capacity.

## Ownership Contract

- The pool **owns** all objects it creates. Do not pass objects between pools.
- `Acquire()` transfers ownership to the caller. The caller **must** call `Release()` when done.
- `Release()` transfers ownership back to the pool. The caller **must not** use the object after release.
- Double-release is safe (returns `false`, no error) but indicates a logic bug.
- Objects created outside the pool should never be released into it.

## Double-Release Safety

`Release()` checks `IsActive(object)` before proceeding. If the object is not active (already released or never acquired), it returns `false` without error. This prevents the same object from appearing in the inactive list twice.

## Source

`Loolib/UI/Pool/ObjectPool.lua`
