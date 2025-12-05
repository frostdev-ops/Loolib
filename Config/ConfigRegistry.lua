--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ConfigRegistry - Options table registry and management

    Central registry for addon options tables. Supports both static
    tables and dynamic function-based options generation.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibConfigRegistryMixin

    Manages registration, retrieval, and validation of options tables.
----------------------------------------------------------------------]]

LoolibConfigRegistryMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local REGISTRY_EVENTS = {
    "OnConfigTableChange",
    "OnConfigTableRegistered",
    "OnConfigTableUnregistered",
}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the config registry
function LoolibConfigRegistryMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(REGISTRY_EVENTS)

    self.tables = {}           -- appName -> options table or function
    self.cachedTables = {}     -- appName -> { [cacheKey] = evaluated options table }
    self.cacheTime = {}        -- appName -> last cache time
    self.cacheInvalid = {}     -- appName -> true if cache needs refresh
end

--[[--------------------------------------------------------------------
    Registration
----------------------------------------------------------------------]]

--- Register an options table for an addon
-- @param appName string - Unique identifier for the addon
-- @param options table|function - Options table OR function returning options table
-- @param skipValidation boolean - Skip validation for performance (default false)
-- @return boolean - Success
function LoolibConfigRegistryMixin:RegisterOptionsTable(appName, options, skipValidation)
    if type(appName) ~= "string" or appName == "" then
        error("LoolibConfigRegistry:RegisterOptionsTable: appName must be a non-empty string", 2)
    end

    if type(options) ~= "table" and type(options) ~= "function" then
        error("LoolibConfigRegistry:RegisterOptionsTable: options must be a table or function", 2)
    end

    -- Validate if not skipped and options is a table
    if not skipValidation and type(options) == "table" then
        local isValid, errors = self:ValidateOptionsTable(options, appName)
        if not isValid then
            local errorMsg = table.concat(errors, "\n  ")
            Loolib:Error("Config validation failed for '" .. appName .. "':\n  " .. errorMsg)
            -- Continue anyway but log the warning
        end
    end

    self.tables[appName] = options
    self.cachedTables[appName] = {}
    self.cacheInvalid[appName] = true

    self:TriggerEvent("OnConfigTableRegistered", appName)

    return true
end

--- Unregister an options table
-- @param appName string - The addon name
-- @return boolean - Success
function LoolibConfigRegistryMixin:UnregisterOptionsTable(appName)
    if not self.tables[appName] then
        return false
    end

    self.tables[appName] = nil
    self.cachedTables[appName] = nil
    self.cacheTime[appName] = nil
    self.cacheInvalid[appName] = nil

    self:TriggerEvent("OnConfigTableUnregistered", appName)

    return true
end

--[[--------------------------------------------------------------------
    Retrieval
----------------------------------------------------------------------]]

--- Get options table for rendering
-- @param appName string - Addon name
-- @param uiType string - "cmd", "dialog", "bliz" (optional, for *Hidden filtering)
-- @param uiName string - Specific UI instance (optional)
-- @return table|nil - Options table (evaluated if function)
function LoolibConfigRegistryMixin:GetOptionsTable(appName, uiType, uiName)
    local registered = self.tables[appName]
    if not registered then
        return nil
    end

    local options

    -- Evaluate function if needed
    if type(registered) == "function" then
        -- Generate a cache key based on arguments
        local cacheKey = (uiType or "") .. ":" .. (uiName or "")
        
        -- Initialize cache for this app if needed
        if not self.cachedTables[appName] then
            self.cachedTables[appName] = {}
        end

        -- Check cache
        if self.cachedTables[appName][cacheKey] and not self.cacheInvalid[appName] then
            options = self.cachedTables[appName][cacheKey]
        else
            local success, result = pcall(registered, uiType, uiName)
            if success then
                options = result
                self.cachedTables[appName][cacheKey] = options
                self.cacheTime[appName] = GetTime()
                -- Note: cacheInvalid remains true until explicitly cleared or managed
                -- But for now, we treat invalidation as a signal to rebuild, 
                -- and we just rebuilt this specific key.
                -- To avoid constant rebuilding if the invalid flag is sticky, 
                -- we should probably clear it if we've rebuilt "enough" or manage it better.
                -- However, simpler is to treat cacheInvalid as "next read must refresh".
                -- So we should clear it for at least this read? 
                -- If we clear it for the app, other keys might be stale.
                -- Let's rely on NotifyChange clearing the table, so checking for existence is enough.
                if self.cacheInvalid[appName] then
                     self.cacheInvalid[appName] = false
                end
            else
                Loolib:Error("Error generating options table for '" .. appName .. "': " .. tostring(result))
                return nil
            end
        end
    else
        options = registered
    end

    return options
end

--- Check if an options table is registered
-- @param appName string - Addon name
-- @return boolean
function LoolibConfigRegistryMixin:IsRegistered(appName)
    return self.tables[appName] ~= nil
end

--- Iterate over all registered options tables
-- @return iterator - for name, options in Registry:IterateOptionsTables()
function LoolibConfigRegistryMixin:IterateOptionsTables()
    local appNames = {}
    for appName in pairs(self.tables) do
        appNames[#appNames + 1] = appName
    end
    table.sort(appNames)

    local i = 0
    return function()
        i = i + 1
        local appName = appNames[i]
        if appName then
            return appName, self:GetOptionsTable(appName)
        end
    end
end

--- Get list of all registered app names
-- @return table - Array of app names
function LoolibConfigRegistryMixin:GetRegisteredAppNames()
    local names = {}
    for appName in pairs(self.tables) do
        names[#names + 1] = appName
    end
    table.sort(names)
    return names
end

--[[--------------------------------------------------------------------
    Cache Management
----------------------------------------------------------------------]]

--- Notify that an options table has changed
-- @param appName string - The addon name
function LoolibConfigRegistryMixin:NotifyChange(appName)
    if appName then
        self.cacheInvalid[appName] = true
        -- We clear the cache table so next GetOptionsTable rebuilds it
        if self.cachedTables[appName] then
             wipe(self.cachedTables[appName])
        end
        self:TriggerEvent("OnConfigTableChange", appName)
    else
        -- Invalidate all
        for name in pairs(self.tables) do
            self.cacheInvalid[name] = true
            if self.cachedTables[name] then
                wipe(self.cachedTables[name])
            end
        end
        self:TriggerEvent("OnConfigTableChange", nil)
    end
end

--- Clear the cache for an app
-- @param appName string - The addon name (or nil for all)
function LoolibConfigRegistryMixin:ClearCache(appName)
    if appName then
        self.cachedTables[appName] = {}
        self.cacheTime[appName] = nil
        self.cacheInvalid[appName] = true
    else
        wipe(self.cachedTables)
        wipe(self.cacheTime)
        for name in pairs(self.tables) do
            self.cacheInvalid[name] = true
            self.cachedTables[name] = {} -- Ensure table exists
        end
    end
end

--[[--------------------------------------------------------------------
    Validation
----------------------------------------------------------------------]]

--- Validate an options table structure
-- @param options table - Options table to validate
-- @param name string - Name for error messages
-- @param path string - Current path (for recursion)
-- @return boolean, table - isValid, array of error strings
function LoolibConfigRegistryMixin:ValidateOptionsTable(options, name, path, visited)
    local errors = {}
    path = path or ""
    local fullPath = path == "" and name or (name .. "." .. path)
    
    -- Cycle detection
    visited = visited or {}
    if visited[options] then
        return false, { string.format("Circular reference detected at '%s'", fullPath) }
    end
    visited[options] = true

    -- Check if options is a table
    if type(options) ~= "table" then
        errors[#errors + 1] = string.format("Expected table at '%s', got %s", fullPath, type(options))
        return false, errors
    end

    -- Root must be type "group"
    if path == "" then
        if options.type and options.type ~= "group" then
            errors[#errors + 1] = string.format("Root options must be type 'group', got '%s'", options.type)
        end
        -- If no type specified, assume group
        if not options.type then
            options.type = "group"
        end
    end

    -- Validate the type
    local optType = options.type
    if optType then
        -- Check type is valid
        if not LoolibConfigTypes.types[optType] then
            errors[#errors + 1] = string.format("Unknown option type '%s' at '%s'", optType, fullPath)
        else
            -- Validate type-specific properties
            local typeValid, typeError = LoolibConfigTypes:ValidateOption(optType, options)
            if not typeValid then
                errors[#errors + 1] = string.format("At '%s': %s", fullPath, typeError)
            end
        end
    end

    -- Validate nested args for groups
    if optType == "group" and options.args then
        if type(options.args) ~= "table" then
            errors[#errors + 1] = string.format("Expected table for 'args' at '%s', got %s", fullPath, type(options.args))
        else
            -- Validate each child option
            for key, childOption in pairs(options.args) do
                if type(childOption) == "table" then
                    local childPath = path == "" and key or (path .. "." .. key)
                    local childValid, childErrors = self:ValidateOptionsTable(childOption, name, childPath, visited)
                    if not childValid then
                        for _, err in ipairs(childErrors) do
                            errors[#errors + 1] = err
                        end
                    end
                end
            end
        end
    end

    -- Check for get/set on types that need them
    if optType and LoolibConfigTypes:SupportsGetSet(optType) then
        -- Warning only - get/set are often inherited from handler
        -- This is not an error but could be validated more strictly
    end

    return #errors == 0, errors
end

--[[--------------------------------------------------------------------
    Option Navigation
----------------------------------------------------------------------]]

--- Navigate to an option by path
-- @param options table - Root options table
-- @param ... - Path components
-- @return table|nil - The option at the path
function LoolibConfigRegistryMixin:GetOptionByPath(options, ...)
    local current = options
    local pathCount = select("#", ...)

    for i = 1, pathCount do
        local key = select(i, ...)

        if not current then
            return nil
        end

        -- Handle args lookup for groups
        if current.args and current.args[key] then
            current = current.args[key]
        elseif current[key] then
            current = current[key]
        else
            return nil
        end
    end

    return current
end

--- Get all options sorted by order
-- @param group table - Group option with args
-- @return table - Array of {key, option} sorted by order
function LoolibConfigRegistryMixin:GetSortedOptions(group)
    if not group or not group.args then
        return {}
    end

    local sorted = {}
    for key, option in pairs(group.args) do
        if type(option) == "table" then
            sorted[#sorted + 1] = {key = key, option = option}
        end
    end

    -- Sort by order property
    table.sort(sorted, function(a, b)
        local orderA = self:ResolveValue(a.option.order, nil) or 100
        local orderB = self:ResolveValue(b.option.order, nil) or 100
        if orderA == orderB then
            return a.key < b.key
        end
        return orderA < orderB
    end)

    return sorted
end

--[[--------------------------------------------------------------------
    Value Resolution Helpers
----------------------------------------------------------------------]]

--- Resolve a property value (handles functions)
-- @param valueOrFunc any - Static value or function returning value
-- @param info table - Info table to pass to function
-- @return any - Resolved value
function LoolibConfigRegistryMixin:ResolveValue(valueOrFunc, info)
    if type(valueOrFunc) == "function" then
        local success, result = pcall(valueOrFunc, info)
        if success then
            return result
        else
            Loolib:Error("Error resolving config value:", result)
            return nil
        end
    end
    return valueOrFunc
end

--- Build info table for callbacks
-- @param options table - Root options table
-- @param option table - Current option
-- @param appName string - App name
-- @param ... - Path to option
-- @return table - Info table
function LoolibConfigRegistryMixin:BuildInfoTable(options, option, appName, ...)
    local info = {
        options = options,
        option = option,
        appName = appName,
        type = option and option.type,
        handler = option and option.handler,
        arg = option and option.arg,
    }

    -- Add path components
    local pathCount = select("#", ...)
    for i = 1, pathCount do
        info[i] = select(i, ...)
    end

    -- Find handler from parent chain if not set
    if not info.handler and options then
        info.handler = options.handler
    end

    return info
end

--- Call a method on handler or directly
-- @param option table - Option with handler/method
-- @param info table - Info table
-- @param methodOrFunc function|string - Method name or function
-- @param ... - Additional arguments
-- @return any - Result
function LoolibConfigRegistryMixin:CallMethod(option, info, methodOrFunc, ...)
    local handler = info.handler or option.handler

    if type(methodOrFunc) == "string" then
        -- It's a method name
        if handler and handler[methodOrFunc] then
            local success, result = pcall(handler[methodOrFunc], handler, info, ...)
            if not success then
                Loolib:Error("Error calling method '" .. methodOrFunc .. "': " .. tostring(result))
                return nil
            end
            return result
        else
            Loolib:Error("Method '" .. methodOrFunc .. "' not found on handler")
            return nil
        end
    elseif type(methodOrFunc) == "function" then
        local success, result = pcall(methodOrFunc, info, ...)
        if not success then
            Loolib:Error("Error calling function: " .. tostring(result))
            return nil
        end
        return result
    end

    return nil
end

--- Get option value using get property
-- @param option table - The option
-- @param info table - Info table
-- @return any - The value
function LoolibConfigRegistryMixin:GetValue(option, info)
    if not option.get then
        return nil
    end
    return self:CallMethod(option, info, option.get)
end

--- Set option value using set property
-- @param option table - The option
-- @param info table - Info table
-- @param ... - Values to set
function LoolibConfigRegistryMixin:SetValue(option, info, ...)
    if not option.set then
        return
    end

    -- Handle confirmation
    local confirm = self:ResolveValue(option.confirm, info)
    if confirm then
        -- Confirmation would be handled by the UI layer
        -- For now, just proceed
    end

    -- Handle validation
    if option.validate then
        local valid, errorMsg = self:CallMethod(option, info, option.validate, ...)
        if valid ~= true then
            if errorMsg then
                Loolib:Error("Validation failed:", errorMsg)
            end
            return false
        end
    end

    self:CallMethod(option, info, option.set, ...)
    return true
end

--[[--------------------------------------------------------------------
    Hidden/Disabled State
----------------------------------------------------------------------]]

--- Check if option is hidden
-- @param option table - The option
-- @param info table - Info table
-- @param uiType string - UI type for specific hidden check
-- @return boolean
function LoolibConfigRegistryMixin:IsHidden(option, info, uiType)
    -- Check type-specific hidden
    local typeHiddenKey = uiType and (uiType .. "Hidden")
    if typeHiddenKey and option[typeHiddenKey] then
        local typeHidden = self:ResolveValue(option[typeHiddenKey], info)
        if typeHidden then
            return true
        end
    end

    -- Check general hidden
    local hidden = self:ResolveValue(option.hidden, info)
    return hidden == true
end

--- Check if option is disabled
-- @param option table - The option
-- @param info table - Info table
-- @return boolean
function LoolibConfigRegistryMixin:IsDisabled(option, info)
    local disabled = self:ResolveValue(option.disabled, info)
    return disabled == true
end

--[[--------------------------------------------------------------------
    Factory and Singleton
----------------------------------------------------------------------]]

--- Create a new config registry instance
-- @return table - New registry instance
function CreateLoolibConfigRegistry()
    local registry = LoolibCreateFromMixins(LoolibConfigRegistryMixin)
    registry:Init()
    return registry
end

-- Create the singleton instance
local ConfigRegistry = CreateLoolibConfigRegistry()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local ConfigRegistryModule = {
    Mixin = LoolibConfigRegistryMixin,
    Create = CreateLoolibConfigRegistry,
    Registry = ConfigRegistry,  -- Singleton instance
}

Loolib:RegisterModule("ConfigRegistry", ConfigRegistryModule)
