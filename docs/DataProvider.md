# DataProvider Documentation

**Module**: `Loolib.Data.DataProvider`
**Mixin**: `LoolibDataProviderMixin`
**Factory**: `Loolib.Data.CreateDataProvider(initialData)`

## Table of Contents
1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [API Reference](#api-reference)
4. [Events](#events)
5. [Filtering and Sorting](#filtering-and-sorting)
6. [Best Practices](#best-practices)

---

## Overview

The DataProvider module is a collection management system with change
notifications, modelled after Blizzard's `DataProviderMixin`. It is the
standard way to feed data into UI components such as ScrollingTable,
ListView, or any widget that needs to observe a dynamic data set.

Key features:

- **Indexed collection** with insert, remove, find, and replace operations
- **Callback events** for every mutation (insert, remove, sort, flush, update)
- **Lazy filtering** with pending/apply lifecycle
- **Lazy sorting** with pending/apply lifecycle
- **Functional helpers**: Map, Reduce, FindByPredicate, FindAllByPredicate
- **Input validation** on all public APIs (errors show caller stack frame)

### Blizzard DataProviderMixin Comparison

| Feature | Blizzard | Loolib DataProvider |
|---------|----------|---------------------|
| Insert / Remove | Yes | Yes |
| Bulk insert | InsertTable only | InsertTable + InsertMany |
| Sort | Yes | Yes (lazy with pending flag) |
| Filter | No | Yes (lazy with pending flag) |
| Callbacks | Yes | Yes (6 events) |
| Map / Reduce | No | Yes |
| Range access | No | Yes (GetRange) |
| Input validation | No | Yes |

---

## Quick Start

```lua
local Loolib = LibStub("Loolib")
local Data = Loolib:GetModule("Data")

-- Create a provider with initial data
local provider = Data.CreateDataProvider({
    { name = "Alpha", score = 100 },
    { name = "Beta",  score = 85 },
})

-- Listen for changes
provider:RegisterCallback("OnInsert", function(elementData, index)
    print("Inserted at", index, elementData.name)
end, myOwner)

provider:RegisterCallback("OnSizeChanged", function(newSize)
    print("Size is now", newSize)
end, myOwner)

-- Add data
provider:Append({ name = "Gamma", score = 92 })

-- Sort
provider:SetSortComparator(function(a, b) return a.score > b.score end)
provider:Sort()

-- Filter
provider:SetFilter(function(d) return d.score >= 90 end)
provider:ApplyFilter()

-- Iterate (respects filter)
for i, data in provider:Enumerate() do
    print(i, data.name, data.score)
end
```

---

## API Reference

### Factory

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `Data.CreateDataProvider(initialData)` | `table\|nil` | DataProvider | Create a new DataProvider instance |

### Insertion

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `Insert(elementData, insertIndex?)` | any, number\|nil | number | Insert element, returns index |
| `Prepend(elementData)` | any | number | Insert at beginning |
| `Append(elementData)` | any | number | Insert at end |
| `InsertTable(tbl)` | table | -- | Bulk insert from array |
| `InsertMany(...)` | varargs | -- | Insert multiple elements |

### Removal

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `Remove(elementData)` | any | boolean | Remove by value |
| `RemoveIndex(index)` | number | any\|nil | Remove by index, returns removed |
| `RemoveByPredicate(predicate)` | function | number | Remove matching, returns count |
| `Flush()` | -- | -- | Remove all elements |

### Retrieval

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `Find(index)` | number | any\|nil | Get element by index (filter-aware) |
| `FindIndex(elementData)` | any | number\|nil | Get index of element |
| `FindByPredicate(predicate)` | function | any, number\|nil | First match + index |
| `FindAllByPredicate(predicate)` | function | table | All matches |
| `Contains(elementData)` | any | boolean | Check existence |
| `GetRange(startIndex, endIndex)` | number, number | table | Slice (filter-aware) |
| `GetRawData()` | -- | table | Direct reference to internal array |

### Size and Iteration

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `GetSize()` | -- | number | Filtered size |
| `GetUnfilteredSize()` | -- | number | Total size |
| `IsEmpty()` | -- | boolean | Size == 0 |
| `Enumerate()` | -- | iterator | ipairs over filtered data |
| `EnumerateUnfiltered()` | -- | iterator | ipairs over raw data |

### Sorting

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `SetSortComparator(sortFunc)` | function | -- | Set comparator, marks sort pending |
| `ClearSortComparator()` | -- | -- | Remove comparator |
| `Sort()` | -- | -- | Execute sort now |
| `IsSortPending()` | -- | boolean | Check pending flag |
| `SortIfPending()` | -- | -- | Sort only if pending |

### Filtering

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `SetFilter(filterFunc)` | function | -- | Set filter, invalidates cache |
| `ClearFilter()` | -- | -- | Remove filter |
| `ApplyFilter()` | -- | -- | Rebuild filtered cache |
| `ApplyFilterIfPending()` | -- | -- | Apply only if pending |
| `EnsureUpToDate()` | -- | -- | Sort + filter if pending |

### Updates

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `UpdateElement(elementData)` | any | -- | Trigger OnUpdate for element |
| `UpdateIndex(index, newData?)` | number, any\|nil | -- | Replace data at index + trigger |
| `ReplaceAll(newData)` | table | -- | Wipe + refill |

### Transformation

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `Map(mapFunc)` | function | table | Transform each element |
| `Reduce(reduceFunc, initialValue)` | function, any | any | Fold to single value |

---

## Events

Register via the inherited `CallbackRegistryMixin`:

```lua
provider:RegisterCallback("OnInsert", handler, owner)
```

| Event | Payload | Fires When |
|-------|---------|------------|
| `OnSizeChanged` | newSize (number) | Element count changes |
| `OnInsert` | elementData, index | After an element is inserted |
| `OnRemove` | elementData, index | After an element is removed |
| `OnUpdate` | elementData, index | After UpdateElement / UpdateIndex |
| `OnSort` | -- | After Sort() executes |
| `OnFlush` | -- | After Flush() or ReplaceAll() |

---

## Filtering and Sorting

### Lifecycle

Sorting and filtering use a **lazy invalidation** model:

1. `SetSortComparator` / `SetFilter` sets the function and marks the
   operation as pending.
2. Mutations (`Insert`, `Remove`, etc.) call `InvalidateFiltered()` which
   clears the cached `filteredData` and sets `pendingFilter = true`.
3. The consumer calls `EnsureUpToDate()` (or `SortIfPending` / `ApplyFilterIfPending`)
   before reading data.

This avoids redundant work when many mutations happen in sequence.

### Filter-Aware Methods

These methods operate on `filteredData` when a filter is active and applied:

- `Find`, `FindIndex`, `FindByPredicate`, `FindAllByPredicate`
- `GetSize`, `Enumerate`, `GetRange`, `Map`, `Reduce`

Use `EnumerateUnfiltered()` and `GetUnfilteredSize()` to bypass the filter.

---

## Best Practices

### 1. Call EnsureUpToDate Before Reading

```lua
-- GOOD
provider:SetSortComparator(mySort)
provider:Append(item1)
provider:Append(item2)
provider:EnsureUpToDate()  -- sort + filter once
for i, data in provider:Enumerate() do ... end

-- BAD: sort/filter fires multiple times
provider:Append(item1)
provider:Sort()
provider:Append(item2)
provider:Sort()
```

### 2. Use Predicate Methods for Lookups

```lua
-- GOOD: single pass
local item, idx = provider:FindByPredicate(function(d) return d.id == targetID end)

-- BAD: iterate manually
for i, d in provider:Enumerate() do
    if d.id == targetID then ... end
end
```

### 3. Avoid Holding GetRawData References

`GetRawData()` returns a direct reference. Mutations (insert, remove, wipe)
will change the same table. Only use it for read-only bulk operations where
performance matters and you understand the lifecycle.

### 4. Input Validation

All public APIs validate inputs and throw errors with level 2 (caller's
stack frame). The error format is:

```
LoolibDataProvider:MethodName: description
```

| Method | Validated Parameters |
|--------|---------------------|
| `Init` | `initialData` (table or nil) |
| `Insert` | `insertIndex` (number or nil) |
| `InsertTable` | `tbl` (table) |
| `RemoveIndex` | `index` (number) |
| `RemoveByPredicate` | `predicate` (function) |
| `Find` | `index` (number) |
| `FindByPredicate` | `predicate` (function) |
| `FindAllByPredicate` | `predicate` (function) |
| `GetRange` | `startIndex` (number), `endIndex` (number) |
| `SetSortComparator` | `sortFunc` (function) |
| `SetFilter` | `filterFunc` (function) |
| `UpdateIndex` | `index` (number) |
| `ReplaceAll` | `newData` (table) |
| `Map` | `mapFunc` (function) |
| `Reduce` | `reduceFunc` (function) |
| Factory `Create` | `initialData` (table or nil) |
