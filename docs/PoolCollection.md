# PoolCollection

Manages multiple frame pools indexed by a composite key of `frameType:parent:template:specialization`. Automatically creates pools on first acquire and routes releases to the correct pool.

## Module Access

```lua
local Loolib = LibStub("Loolib")

-- Factory functions
local collection = Loolib.CreatePoolCollection()
local collection = Loolib.CreateFramePoolCollection()  -- alias

-- Mixin (for custom collection types)
local PoolCollectionMixin = Loolib.PoolCollectionMixin
```

## Factory

### CreatePoolCollection() -> collection

Create a new pool collection. Returns a table with `PoolCollectionMixin` applied and `Init()` already called.

### CreateFramePoolCollection() -> collection

Alias for `CreatePoolCollection()`. Exists for API parity with Blizzard's naming.

## Mixin API (LoolibPoolCollectionMixin)

### Init()

Initialize the collection's internal pool map. Called automatically by the factory.

### GeneratePoolKey(frameType, parent, template, specialization) -> string

*INTERNAL.* Generates a composite key string: `"frameType:parentAddr:template:spec"`.

### GetPool(frameType, parent, template, specialization) -> pool|nil

Look up an existing pool by key. `frameType` must be a string (raises error otherwise).

### CreatePool(frameType, parent, template, resetFunc, specialization, capacity) -> pool

Create and register a new pool. Errors if a pool already exists for the same key.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `frameType` | string | Yes | Frame type |
| `parent` | Frame | No | Parent frame |
| `template` | string | No | XML template |
| `resetFunc` | function | No | Reset function |
| `specialization` | any | No | Extra key differentiator |
| `capacity` | number | No | Max active objects |

The created pool gets a `collectionKey` field set to its composite key.

### GetOrCreatePool(frameType, parent, template, resetFunc, specialization, capacity) -> pool, isNew

Get an existing pool or create one. Returns the pool and whether it was newly created.

### Acquire(frameType, parent, template, resetFunc, specialization) -> frame, isNew

Acquire a frame from the appropriate pool (creating the pool if needed). Delegates to `GetOrCreatePool` then `pool:Acquire()`.

### AcquireByTemplate(template) -> frame, isNew|nil

Search all pools for one matching the template and acquire from it. Returns `nil` if no matching pool exists.

### Release(object) -> boolean

Release an object back to its originating pool. Searches all pools for the active object.

- Errors if `object` is nil.
- Returns `false` and logs an error if the object is not found in any pool.
- Returns `true` on success.

### ReleaseAll()

Release all active objects from all managed pools.

### ReleaseAllByPool(frameType, parent, template, specialization)

Release all active objects from a specific pool identified by key parameters.

### EnumerateActive() -> iterator

Iterator over all active objects across all pools. Returns one object per call.

```lua
for obj in collection:EnumerateActive() do
    -- process
end
```

### EnumerateActiveByPool(frameType, parent, template, specialization) -> iterator

Iterator over active objects in a specific pool. Returns a noop iterator if pool does not exist.

### EnumeratePools() -> iterator

`pairs`-style iterator over `key, pool`.

### GetNumActive() -> number

Total active objects across all pools.

### GetNumPools() -> number

Number of managed pools.

### IsActive(object) -> boolean

`true` if the object is active in any managed pool.

### FindPoolForObject(object) -> pool|nil

Find which pool an object belongs to (checks both active and inactive). Returns `nil` if not found. Note: inactive check is O(n) per pool.

### Clear()

Clear all pools and remove them from the collection.

### Dump()

Print statistics for the entire collection and each pool to chat.

## Cross-Pool Release Safety

`Release()` iterates all managed pools to find the correct one for the object. This means:
- An object acquired from pool A cannot accidentally be released into pool B.
- The collection acts as the ownership authority -- consumers call `collection:Release(obj)` without needing to know which internal pool owns the object.

## Consumers

- `Loolib/UI/Factory/FrameFactory.lua` -- creates a `PoolCollection` as `self.poolCollection` for multi-type frame management.

## Source

`Loolib/UI/Pool/PoolCollection.lua`
