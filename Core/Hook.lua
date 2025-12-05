--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Function and script hooking system (AceHook-3.0 equivalent)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibHookMixin

    Provides function and script hooking capabilities for addons.
    Based on AceHook-3.0 API.

    Hook Types:
    - Regular Hook: Pre-hook that calls handler before original
    - Raw Hook: Replaces original entirely (handler must call original)
    - Secure Hook: Post-hook using hooksecurefunc (safe for secure code)
----------------------------------------------------------------------]]

LoolibHookMixin = {}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the hook storage for an object
-- @param self table - The object to initialize
function LoolibHookMixin:_InitHooks()
    if not self.hooks then
        self.hooks = {}
        self.hookData = {}
        self.scripts = {}
    end
end

--[[--------------------------------------------------------------------
    Hook Signature Generation
----------------------------------------------------------------------]]

--- Generate a unique signature for a hook
-- @param object table|string - The object or global function name
-- @param method string - The method/function name
-- @return string - Unique signature
local function GetSignature(object, method)
    if type(object) == "string" then
        -- Global function
        return "GLOBAL:" .. object
    elseif type(object) == "table" then
        -- Object method
        return tostring(object) .. "." .. (method or "")
    end
    return "UNKNOWN"
end

--- Generate a signature for a script hook
-- @param frame Frame - The frame
-- @param script string - The script name
-- @return string - Unique signature
local function GetScriptSignature(frame, script)
    return tostring(frame) .. ":SCRIPT:" .. script
end

--[[--------------------------------------------------------------------
    Handler Resolution
----------------------------------------------------------------------]]

--- Resolve a handler to a function
-- @param self table - The object
-- @param handler function|string - Handler function or method name
-- @return function|nil - The resolved handler
local function ResolveHandler(self, handler)
    if type(handler) == "function" then
        return handler
    elseif type(handler) == "string" then
        local method = self[handler]
        if type(method) == "function" then
            return method
        end
    end
    return nil
end

--[[--------------------------------------------------------------------
    Function Hooks
----------------------------------------------------------------------]]

--- Hook a function or method (pre-hook)
-- Signatures:
--   Hook("GlobalFunc", handler)
--   Hook(object, "Method", handler)
--   Hook(object, "Method") - uses self.Method as handler
--   Hook(object, "Method", "HandlerMethod")
-- @param object table|string - Object or global function name
-- @param method string|function - Method name or handler (if object is string)
-- @param handler function|string - Handler function or method name
-- @param hookSecure boolean - Use secure hook instead
-- @return boolean - Success
function LoolibHookMixin:Hook(object, method, handler, hookSecure)
    self:_InitHooks()

    -- Parse arguments based on signature
    local isGlobal = type(object) == "string"
    local targetObject, targetMethod, targetHandler

    if isGlobal then
        -- Hook("GlobalFunc", handler, hookSecure)
        targetObject = _G
        targetMethod = object
        targetHandler = method
        hookSecure = handler
    else
        -- Hook(object, "Method", handler, hookSecure)
        targetObject = object
        targetMethod = method
        targetHandler = handler

        -- If no handler specified, use self[method]
        if not targetHandler then
            targetHandler = method
        end
    end

    -- Validate inputs
    if not targetObject or type(targetObject) ~= "table" then
        error("Hook: invalid target object", 2)
        return false
    end

    if type(targetMethod) ~= "string" or targetMethod == "" then
        error("Hook: method must be a non-empty string", 2)
        return false
    end

    -- Resolve handler
    local handlerFunc = ResolveHandler(self, targetHandler)
    if not handlerFunc then
        error("Hook: handler must be a function or valid method name", 2)
        return false
    end

    -- Check if already hooked
    local sig = GetSignature(isGlobal and targetMethod or targetObject, isGlobal and nil or targetMethod)
    if self.hooks[sig] then
        error("Hook: already hooked " .. sig, 2)
        return false
    end

    -- Get original function
    local original = targetObject[targetMethod]
    if type(original) ~= "function" then
        error("Hook: " .. targetMethod .. " is not a function", 2)
        return false
    end

    -- Use secure hook if requested
    if hookSecure then
        return self:SecureHook(object, method, targetHandler)
    end

    -- Create pre-hook wrapper
    local function hookWrapper(...)
        handlerFunc(self, ...)
        return original(...)
    end

    -- Install hook
    targetObject[targetMethod] = hookWrapper

    -- Store original
    self.hooks[sig] = original
    self.hookData[sig] = {
        object = targetObject,
        method = targetMethod,
        handler = handlerFunc,
        type = "hook",
    }

    return true
end

--- Raw hook a function (replaces original entirely)
-- Handler must manually call the original via self.hooks[signature]
-- @param object table|string - Object or global function name
-- @param method string|function - Method name or handler
-- @param handler function|string - Handler function or method name
-- @return boolean - Success
function LoolibHookMixin:RawHook(object, method, handler)
    self:_InitHooks()

    -- Parse arguments
    local isGlobal = type(object) == "string"
    local targetObject, targetMethod, targetHandler

    if isGlobal then
        targetObject = _G
        targetMethod = object
        targetHandler = method
    else
        targetObject = object
        targetMethod = method
        targetHandler = handler
    end

    -- Validate
    if not targetObject or type(targetObject) ~= "table" then
        error("RawHook: invalid target object", 2)
        return false
    end

    if type(targetMethod) ~= "string" or targetMethod == "" then
        error("RawHook: method must be a non-empty string", 2)
        return false
    end

    -- Resolve handler
    local handlerFunc = ResolveHandler(self, targetHandler)
    if not handlerFunc then
        error("RawHook: handler must be a function or valid method name", 2)
        return false
    end

    -- Check if already hooked
    local sig = GetSignature(isGlobal and targetMethod or targetObject, isGlobal and nil or targetMethod)
    if self.hooks[sig] then
        error("RawHook: already hooked " .. sig, 2)
        return false
    end

    -- Get original
    local original = targetObject[targetMethod]
    if type(original) ~= "function" then
        error("RawHook: " .. targetMethod .. " is not a function", 2)
        return false
    end

    -- Store original (handler will call this manually)
    self.hooks[sig] = original
    self.hookData[sig] = {
        object = targetObject,
        method = targetMethod,
        handler = handlerFunc,
        type = "rawhook",
    }

    -- Replace function entirely
    targetObject[targetMethod] = function(...)
        return handlerFunc(self, ...)
    end

    return true
end

--- Secure hook a function (post-hook, safe for secure code)
-- Uses hooksecurefunc - cannot prevent or modify original call
-- @param object table|string - Object or global function name
-- @param method string|function - Method name or handler
-- @param handler function|string - Handler function or method name
-- @return boolean - Success
function LoolibHookMixin:SecureHook(object, method, handler)
    self:_InitHooks()

    -- Parse arguments
    local isGlobal = type(object) == "string"
    local targetObject, targetMethod, targetHandler

    if isGlobal then
        targetMethod = object
        targetHandler = method
    else
        targetObject = object
        targetMethod = method
        targetHandler = handler
    end

    -- Validate
    if not isGlobal and (not targetObject or type(targetObject) ~= "table") then
        error("SecureHook: invalid target object", 2)
        return false
    end

    if type(targetMethod) ~= "string" or targetMethod == "" then
        error("SecureHook: method must be a non-empty string", 2)
        return false
    end

    -- Resolve handler
    local handlerFunc = ResolveHandler(self, targetHandler)
    if not handlerFunc then
        error("SecureHook: handler must be a function or valid method name", 2)
        return false
    end

    -- Check if already hooked
    local sig = GetSignature(isGlobal and targetMethod or targetObject, isGlobal and nil or targetMethod)
    if self.hooks[sig] then
        error("SecureHook: already hooked " .. sig, 2)
        return false
    end

    -- Create wrapper that calls handler with self
    local function secureWrapper(...)
        handlerFunc(self, ...)
    end

    -- Install secure hook
    if isGlobal then
        hooksecurefunc(targetMethod, secureWrapper)
    else
        hooksecurefunc(targetObject, targetMethod, secureWrapper)
    end

    -- Mark as hooked (but no original to store for secure hooks)
    self.hooks[sig] = true
    self.hookData[sig] = {
        object = targetObject,
        method = targetMethod,
        handler = handlerFunc,
        type = "securehook",
    }

    return true
end

--[[--------------------------------------------------------------------
    Script Hooks
----------------------------------------------------------------------]]

--- Hook a frame script (pre-hook)
-- @param frame Frame - The frame to hook
-- @param script string - Script name (e.g., "OnShow", "OnHide")
-- @param handler function|string - Handler function or method name
-- @return boolean - Success
function LoolibHookMixin:HookScript(frame, script, handler)
    self:_InitHooks()

    -- Validate
    if type(frame) ~= "table" or not frame.GetScript then
        error("HookScript: frame must be a valid frame object", 2)
        return false
    end

    if type(script) ~= "string" or script == "" then
        error("HookScript: script must be a non-empty string", 2)
        return false
    end

    if not frame:HasScript(script) then
        error("HookScript: frame does not support script " .. script, 2)
        return false
    end

    -- Resolve handler
    local handlerFunc = ResolveHandler(self, handler)
    if not handlerFunc then
        error("HookScript: handler must be a function or valid method name", 2)
        return false
    end

    -- Check if already hooked
    local sig = GetScriptSignature(frame, script)
    if self.scripts[sig] then
        error("HookScript: already hooked " .. sig, 2)
        return false
    end

    -- Get original script
    local original = frame:GetScript(script)

    -- Create pre-hook wrapper
    local function scriptWrapper(...)
        handlerFunc(self, ...)
        if original then
            return original(...)
        end
    end

    -- Install hook
    frame:SetScript(script, scriptWrapper)

    -- Store original
    self.scripts[sig] = original
    self.hookData[sig] = {
        frame = frame,
        script = script,
        handler = handlerFunc,
        type = "scripthook",
    }

    return true
end

--- Raw hook a frame script (replaces original entirely)
-- @param frame Frame - The frame to hook
-- @param script string - Script name
-- @param handler function|string - Handler function or method name
-- @return boolean - Success
function LoolibHookMixin:RawHookScript(frame, script, handler)
    self:_InitHooks()

    -- Validate
    if type(frame) ~= "table" or not frame.GetScript then
        error("RawHookScript: frame must be a valid frame object", 2)
        return false
    end

    if type(script) ~= "string" or script == "" then
        error("RawHookScript: script must be a non-empty string", 2)
        return false
    end

    if not frame:HasScript(script) then
        error("RawHookScript: frame does not support script " .. script, 2)
        return false
    end

    -- Resolve handler
    local handlerFunc = ResolveHandler(self, handler)
    if not handlerFunc then
        error("RawHookScript: handler must be a function or valid method name", 2)
        return false
    end

    -- Check if already hooked
    local sig = GetScriptSignature(frame, script)
    if self.scripts[sig] then
        error("RawHookScript: already hooked " .. sig, 2)
        return false
    end

    -- Get original
    local original = frame:GetScript(script)

    -- Store original (handler will call manually via self.scripts[sig])
    self.scripts[sig] = original
    self.hookData[sig] = {
        frame = frame,
        script = script,
        handler = handlerFunc,
        type = "rawscripthook",
    }

    -- Replace script
    frame:SetScript(script, function(...)
        return handlerFunc(self, ...)
    end)

    return true
end

--- Secure hook a frame script (post-hook)
-- @param frame Frame - The frame to hook
-- @param script string - Script name
-- @param handler function|string - Handler function or method name
-- @return boolean - Success
function LoolibHookMixin:SecureHookScript(frame, script, handler)
    self:_InitHooks()

    -- Validate
    if type(frame) ~= "table" or not frame.HookScript then
        error("SecureHookScript: frame must be a valid frame object", 2)
        return false
    end

    if type(script) ~= "string" or script == "" then
        error("SecureHookScript: script must be a non-empty string", 2)
        return false
    end

    if not frame:HasScript(script) then
        error("SecureHookScript: frame does not support script " .. script, 2)
        return false
    end

    -- Resolve handler
    local handlerFunc = ResolveHandler(self, handler)
    if not handlerFunc then
        error("SecureHookScript: handler must be a function or valid method name", 2)
        return false
    end

    -- Check if already hooked
    local sig = GetScriptSignature(frame, script)
    if self.scripts[sig] then
        error("SecureHookScript: already hooked " .. sig, 2)
        return false
    end

    -- Install secure hook
    frame:HookScript(script, function(...)
        handlerFunc(self, ...)
    end)

    -- Mark as hooked
    self.scripts[sig] = true
    self.hookData[sig] = {
        frame = frame,
        script = script,
        handler = handlerFunc,
        type = "securescripthook",
    }

    return true
end

--[[--------------------------------------------------------------------
    Unhook Functions
----------------------------------------------------------------------]]

--- Unhook a function or method
-- @param object table|string - Object or global function name
-- @param method string - Method name (nil if object is string)
-- @return boolean - Success
function LoolibHookMixin:Unhook(object, method)
    if not self.hooks then
        return false
    end

    -- Parse arguments
    local isGlobal = type(object) == "string"
    local sig

    if isGlobal then
        sig = GetSignature(object, nil)
    else
        sig = GetSignature(object, method)
    end

    -- Check if hooked
    local hookData = self.hookData[sig]
    if not hookData then
        return false
    end

    -- Can't unhook secure hooks (they're permanent)
    if hookData.type == "securehook" then
        Loolib:Debug("Cannot unhook secure hook:", sig)
        return false
    end

    -- Restore original function
    local original = self.hooks[sig]
    if original and type(original) == "function" then
        hookData.object[hookData.method] = original
    end

    -- Clean up
    self.hooks[sig] = nil
    self.hookData[sig] = nil

    return true
end

--- Unhook a frame script
-- @param frame Frame - The frame
-- @param script string - Script name
-- @return boolean - Success
function LoolibHookMixin:UnhookScript(frame, script)
    if not self.scripts then
        return false
    end

    local sig = GetScriptSignature(frame, script)
    local hookData = self.hookData[sig]

    if not hookData then
        return false
    end

    -- Can't unhook secure script hooks
    if hookData.type == "securescripthook" then
        Loolib:Debug("Cannot unhook secure script hook:", sig)
        return false
    end

    -- Restore original script
    local original = self.scripts[sig]
    frame:SetScript(script, original)

    -- Clean up
    self.scripts[sig] = nil
    self.hookData[sig] = nil

    return true
end

--- Unhook all hooks created by this object
function LoolibHookMixin:UnhookAll()
    if not self.hooks then
        return
    end

    -- Unhook all functions
    for sig, original in pairs(self.hooks) do
        local hookData = self.hookData[sig]
        if hookData and hookData.type ~= "securehook" then
            if type(original) == "function" then
                hookData.object[hookData.method] = original
            end
        end
    end

    -- Unhook all scripts
    if self.scripts then
        for sig, original in pairs(self.scripts) do
            local hookData = self.hookData[sig]
            if hookData and hookData.type ~= "securescripthook" then
                hookData.frame:SetScript(hookData.script, original)
            end
        end
    end

    -- Clear storage
    self.hooks = {}
    self.scripts = {}
    self.hookData = {}
end

--[[--------------------------------------------------------------------
    Query Functions
----------------------------------------------------------------------]]

--- Check if a function is hooked
-- @param object table|string - Object or global function name
-- @param method string - Method name (nil if object is string)
-- @return boolean - True if hooked
-- @return function|nil - The handler function
function LoolibHookMixin:IsHooked(object, method)
    if not self.hooks then
        return false, nil
    end

    local isGlobal = type(object) == "string"
    local sig

    if isGlobal then
        sig = GetSignature(object, nil)
    else
        sig = GetSignature(object, method)
    end

    local hookData = self.hookData[sig]
    if hookData then
        return true, hookData.handler
    end

    return false, nil
end

--- Check if a script is hooked
-- @param frame Frame - The frame
-- @param script string - Script name
-- @return boolean - True if hooked
-- @return function|nil - The handler function
function LoolibHookMixin:IsScriptHooked(frame, script)
    if not self.scripts then
        return false, nil
    end

    local sig = GetScriptSignature(frame, script)
    local hookData = self.hookData[sig]

    if hookData then
        return true, hookData.handler
    end

    return false, nil
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib:RegisterModule("Hook", LoolibHookMixin)
