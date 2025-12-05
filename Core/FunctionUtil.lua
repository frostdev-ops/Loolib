--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Function utilities for closures, callbacks, and composition
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

LoolibFunctionUtil = {}

--[[--------------------------------------------------------------------
    Closure Generation

    Create closures that capture arguments at creation time.
----------------------------------------------------------------------]]

--- Generate a closure that prepends captured arguments
-- @param func function - The function to wrap
-- @param ... - Arguments to capture (prepended to call-time arguments)
-- @return function - A closure that calls func with captured + new args
function LoolibFunctionUtil.GenerateClosure(func, ...)
    local capturedCount = select("#", ...)

    if capturedCount == 0 then
        return func
    elseif capturedCount == 1 then
        local arg1 = ...
        return function(...)
            return func(arg1, ...)
        end
    elseif capturedCount == 2 then
        local arg1, arg2 = ...
        return function(...)
            return func(arg1, arg2, ...)
        end
    elseif capturedCount == 3 then
        local arg1, arg2, arg3 = ...
        return function(...)
            return func(arg1, arg2, arg3, ...)
        end
    else
        local captured = {...}
        return function(...)
            local callArgs = {...}
            local combined = {}
            for i = 1, #captured do
                combined[i] = captured[i]
            end
            for i = 1, #callArgs do
                combined[#captured + i] = callArgs[i]
            end
            return func(unpack(combined))
        end
    end
end

--- Generate a closure that appends captured arguments
-- @param func function - The function to wrap
-- @param ... - Arguments to capture (appended to call-time arguments)
-- @return function - A closure that calls func with new + captured args
function LoolibFunctionUtil.GenerateClosureAppend(func, ...)
    local capturedCount = select("#", ...)

    if capturedCount == 0 then
        return func
    elseif capturedCount == 1 then
        local arg1 = ...
        return function(...)
            local count = select("#", ...)
            if count == 0 then
                return func(arg1)
            elseif count == 1 then
                return func(..., arg1)
            else
                local args = {...}
                args[count + 1] = arg1
                return func(unpack(args, 1, count + 1))
            end
        end
    else
        local captured = {...}
        return function(...)
            local callArgs = {...}
            local combined = {}
            for i = 1, #callArgs do
                combined[i] = callArgs[i]
            end
            for i = 1, #captured do
                combined[#callArgs + i] = captured[i]
            end
            return func(unpack(combined))
        end
    end
end

--[[--------------------------------------------------------------------
    Function Composition
----------------------------------------------------------------------]]

--- Compose multiple functions into one (right to left)
-- @param ... - Functions to compose (last is called first)
-- @return function - A composed function
function LoolibFunctionUtil.Compose(...)
    local funcs = {...}
    local count = #funcs

    if count == 0 then
        return function(...) return ... end
    elseif count == 1 then
        return funcs[1]
    end

    return function(...)
        local result = {funcs[count](...)}
        for i = count - 1, 1, -1 do
            result = {funcs[i](unpack(result))}
        end
        return unpack(result)
    end
end

--- Pipe multiple functions (left to right, opposite of compose)
-- @param ... - Functions to pipe (first is called first)
-- @return function - A piped function
function LoolibFunctionUtil.Pipe(...)
    local funcs = {...}
    local count = #funcs

    if count == 0 then
        return function(...) return ... end
    elseif count == 1 then
        return funcs[1]
    end

    return function(...)
        local result = {funcs[1](...)}
        for i = 2, count do
            result = {funcs[i](unpack(result))}
        end
        return unpack(result)
    end
end

--[[--------------------------------------------------------------------
    Function Wrapping
----------------------------------------------------------------------]]

--- Wrap a function with before/after hooks
-- @param func function - The function to wrap
-- @param before function - Called before func (receives same args)
-- @param after function - Called after func (receives result)
-- @return function
function LoolibFunctionUtil.Wrap(func, before, after)
    return function(...)
        if before then
            before(...)
        end
        local result = {func(...)}
        if after then
            after(unpack(result))
        end
        return unpack(result)
    end
end

--- Create a function that can only be called once
-- @param func function - The function to wrap
-- @return function
function LoolibFunctionUtil.Once(func)
    local called = false
    local result

    return function(...)
        if not called then
            called = true
            result = {func(...)}
        end
        return unpack(result)
    end
end

--- Create a function that ignores calls after n invocations
-- @param func function - The function to wrap
-- @param n number - Maximum number of calls
-- @return function
function LoolibFunctionUtil.Times(func, n)
    local count = 0
    local lastResult

    return function(...)
        if count < n then
            count = count + 1
            lastResult = {func(...)}
        end
        return unpack(lastResult or {})
    end
end

--[[--------------------------------------------------------------------
    Memoization
----------------------------------------------------------------------]]

--- Memoize a function with a single argument
-- @param func function - The function to memoize
-- @return function - A memoized version that caches results
function LoolibFunctionUtil.Memoize(func)
    local cache = {}

    return function(arg)
        if cache[arg] == nil then
            cache[arg] = func(arg)
        end
        return cache[arg]
    end
end

--- Memoize a function with multiple arguments (using string key)
-- @param func function - The function to memoize
-- @param keyFunc function - Optional function to generate cache key from args
-- @return function
function LoolibFunctionUtil.MemoizeMulti(func, keyFunc)
    local cache = {}

    keyFunc = keyFunc or function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring(select(i, ...))
        end
        return table.concat(parts, "\0")
    end

    return function(...)
        local key = keyFunc(...)
        if cache[key] == nil then
            cache[key] = {func(...)}
        end
        return unpack(cache[key])
    end
end

--[[--------------------------------------------------------------------
    Throttling and Debouncing
----------------------------------------------------------------------]]

--- Create a throttled function (rate-limited to once per interval)
-- @param func function - The function to throttle
-- @param interval number - Minimum seconds between calls
-- @return function - A throttled version
function LoolibFunctionUtil.Throttle(func, interval)
    local lastCall = 0

    return function(...)
        local now = GetTime()
        if now - lastCall >= interval then
            lastCall = now
            return func(...)
        end
    end
end

--- Create a debounced function (waits for pause in calls)
-- @param func function - The function to debounce
-- @param delay number - Seconds to wait after last call
-- @return function - A debounced version
function LoolibFunctionUtil.Debounce(func, delay)
    local timer = nil
    local lastArgs = nil

    return function(...)
        lastArgs = {...}

        if timer then
            timer:Cancel()
        end

        timer = C_Timer.NewTimer(delay, function()
            timer = nil
            func(unpack(lastArgs))
        end)
    end
end

--[[--------------------------------------------------------------------
    Delayed Execution
----------------------------------------------------------------------]]

--- Defer a function to execute after the current execution
-- @param func function - The function to defer
-- @param ... - Arguments to pass
function LoolibFunctionUtil.Defer(func, ...)
    C_Timer.After(0, LoolibFunctionUtil.GenerateClosure(func, ...))
end

--- Execute a function after a delay
-- @param delay number - Seconds to wait
-- @param func function - The function to execute
-- @param ... - Arguments to pass
-- @return table - Timer handle that can be cancelled
function LoolibFunctionUtil.Delay(delay, func, ...)
    return C_Timer.NewTimer(delay, LoolibFunctionUtil.GenerateClosure(func, ...))
end

--[[--------------------------------------------------------------------
    Safe Calls
----------------------------------------------------------------------]]

--- Call a function with error handling
-- @param func function - The function to call
-- @param ... - Arguments to pass
-- @return boolean, any - Success flag and result or error message
function LoolibFunctionUtil.SafeCall(func, ...)
    return pcall(func, ...)
end

--- Call a function, returning nil on error
-- @param func function - The function to call
-- @param ... - Arguments to pass
-- @return any - Result or nil on error
function LoolibFunctionUtil.TryCall(func, ...)
    local success, result = pcall(func, ...)
    if success then
        return result
    end
    return nil
end

--- Call a method on an object if it exists
-- @param object table - The object
-- @param methodName string - The method name
-- @param ... - Arguments to pass
-- @return any - Method result or nil if method doesn't exist
function LoolibFunctionUtil.CallIfExists(object, methodName, ...)
    if object and type(object[methodName]) == "function" then
        return object[methodName](object, ...)
    end
end

--[[--------------------------------------------------------------------
    Predicates
----------------------------------------------------------------------]]

--- Create a negated predicate
-- @param predicate function - The predicate to negate
-- @return function
function LoolibFunctionUtil.Negate(predicate)
    return function(...)
        return not predicate(...)
    end
end

--- Create a predicate that returns true if all predicates pass
-- @param ... - Predicates to combine
-- @return function
function LoolibFunctionUtil.All(...)
    local predicates = {...}
    return function(...)
        for _, pred in ipairs(predicates) do
            if not pred(...) then
                return false
            end
        end
        return true
    end
end

--- Create a predicate that returns true if any predicate passes
-- @param ... - Predicates to combine
-- @return function
function LoolibFunctionUtil.Any(...)
    local predicates = {...}
    return function(...)
        for _, pred in ipairs(predicates) do
            if pred(...) then
                return true
            end
        end
        return false
    end
end

--[[--------------------------------------------------------------------
    Identity and Constants
----------------------------------------------------------------------]]

--- Identity function - returns its argument unchanged
-- @param x any
-- @return any
function LoolibFunctionUtil.Identity(x)
    return x
end

--- Create a function that always returns the same value
-- @param value any - The value to return
-- @return function
function LoolibFunctionUtil.Constant(value)
    return function()
        return value
    end
end

--- No-operation function
function LoolibFunctionUtil.Noop()
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib:RegisterModule("FunctionUtil", LoolibFunctionUtil)
