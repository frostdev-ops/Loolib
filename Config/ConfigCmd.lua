--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ConfigCmd - Command-line interface for options

    Provides slash command handling for configuration options.
    Parses input, navigates option trees, and displays/sets values.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibConfigCmdMixin

    Handles slash command registration and processing for config options.
----------------------------------------------------------------------]]

LoolibConfigCmdMixin = {}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the command handler
function LoolibConfigCmdMixin:Init()
    self.commands = {}         -- slashcmd -> appName
    self.appCommands = {}      -- appName -> {slashcmds}
    self.commandHandlers = {}  -- commandId -> handler function
    self.nextCommandId = 1
end

--[[--------------------------------------------------------------------
    Slash Command Registration
----------------------------------------------------------------------]]

--- Register a slash command for an options table
-- @param slashcmd string - The command name (without /)
-- @param appName string - The registered app name
-- @return boolean - Success
function LoolibConfigCmdMixin:CreateChatCommand(slashcmd, appName)
    if type(slashcmd) ~= "string" or slashcmd == "" then
        error("LoolibConfigCmd:CreateChatCommand: slashcmd must be a non-empty string", 2)
    end
    if type(appName) ~= "string" or appName == "" then
        error("LoolibConfigCmd:CreateChatCommand: appName must be a non-empty string", 2)
    end

    -- Normalize command
    slashcmd = slashcmd:lower():gsub("^/", "")

    -- Check if already registered
    if self.commands[slashcmd] then
        if self.commands[slashcmd] ~= appName then
            Loolib:Error("Command /" .. slashcmd .. " already registered to " .. self.commands[slashcmd])
            return false
        end
        return true  -- Already registered to same app
    end

    -- Generate unique command ID
    local commandId = "LOOLIB_CFG_" .. self.nextCommandId
    self.nextCommandId = self.nextCommandId + 1

    -- Register the slash command globally
    _G["SLASH_" .. commandId .. "1"] = "/" .. slashcmd

    -- Create the handler
    local handler = function(input)
        self:HandleCommand(slashcmd, appName, input or "")
    end

    SlashCmdList[commandId] = handler
    self.commandHandlers[commandId] = handler

    -- Track registrations
    self.commands[slashcmd] = appName

    if not self.appCommands[appName] then
        self.appCommands[appName] = {}
    end
    self.appCommands[appName][slashcmd] = commandId

    return true
end

--- Unregister a specific slash command
-- @param slashcmd string - The command to unregister
-- @return boolean - Success
function LoolibConfigCmdMixin:UnregisterChatCommand(slashcmd)
    slashcmd = slashcmd:lower():gsub("^/", "")

    local appName = self.commands[slashcmd]
    if not appName then
        return false
    end

    -- Find the command ID
    local commandId = self.appCommands[appName] and self.appCommands[appName][slashcmd]
    if commandId then
        -- Clear global registration
        _G["SLASH_" .. commandId .. "1"] = nil
        SlashCmdList[commandId] = nil
        self.commandHandlers[commandId] = nil
        self.appCommands[appName][slashcmd] = nil
    end

    self.commands[slashcmd] = nil
    return true
end

--- Unregister all slash commands for an app
-- @param appName string - The app name
function LoolibConfigCmdMixin:UnregisterChatCommands(appName)
    local cmds = self.appCommands[appName]
    if cmds then
        for slashcmd in pairs(cmds) do
            self:UnregisterChatCommand(slashcmd)
        end
    end
    self.appCommands[appName] = nil
end

--- Get registered slash commands for an app
-- @param appName string - The app name
-- @return table - Array of command strings
function LoolibConfigCmdMixin:GetChatCommands(appName)
    local result = {}
    local cmds = self.appCommands[appName]
    if cmds then
        for cmd in pairs(cmds) do
            result[#result + 1] = cmd
        end
        table.sort(result)
    end
    return result
end

--[[--------------------------------------------------------------------
    Command Handling
----------------------------------------------------------------------]]

--- Handle a slash command
-- @param slashcmd string - The slash command used
-- @param appName string - The registered app name
-- @param input string - User input after the command
function LoolibConfigCmdMixin:HandleCommand(slashcmd, appName, input)
    local ConfigRegistry = Loolib:GetModule("ConfigRegistry")
    local registry = ConfigRegistry and ConfigRegistry.Registry

    if not registry then
        self:Print("Configuration system not available")
        return
    end

    local options = registry:GetOptionsTable(appName, "cmd")
    if not options then
        self:Print("No options registered for: " .. appName)
        return
    end

    -- Parse input into path components
    input = input or ""
    input = input:gsub("^%s+", ""):gsub("%s+$", "")  -- trim

    if input == "" then
        -- Show root level options
        self:ShowGroup(appName, options, registry, {})
        return
    end

    -- Parse the input
    local parts = self:ParseInput(input)
    if #parts == 0 then
        self:ShowGroup(appName, options, registry, {})
        return
    end

    -- Navigate to the option
    local path = {}
    local current = options
    local lastValue = nil

    for i, part in ipairs(parts) do
        if current.args and current.args[part] then
            path[#path + 1] = part
            current = current.args[part]
        else
            -- This might be a value rather than a path component
            lastValue = table.concat(parts, " ", i)
            break
        end
    end

    -- Build info table
    local info = registry:BuildInfoTable(options, current, appName, unpack(path))

    -- Check if hidden
    if registry:IsHidden(current, info, "cmd") then
        self:Print("Option not available in command-line interface")
        return
    end

    -- Handle based on type
    if current.type == "group" then
        if lastValue then
            -- Try to find the option in this group
            if current.args and current.args[lastValue] then
                path[#path + 1] = lastValue
                current = current.args[lastValue]
                info = registry:BuildInfoTable(options, current, appName, unpack(path))
                self:HandleOption(appName, options, current, registry, info, path, nil)
            else
                self:Print("Unknown option: " .. lastValue)
            end
        else
            self:ShowGroup(appName, options, registry, path)
        end
    else
        self:HandleOption(appName, options, current, registry, info, path, lastValue)
    end
end

--- Handle a specific option (get or set value)
-- @param appName string - App name
-- @param options table - Root options
-- @param option table - Current option
-- @param registry table - Registry instance
-- @param info table - Info table
-- @param path table - Path to option
-- @param value string|nil - Value to set (nil = get)
function LoolibConfigCmdMixin:HandleOption(appName, options, option, registry, info, path, value)
    local optType = option.type

    -- Check if disabled
    if registry:IsDisabled(option, info) then
        self:Print("This option is currently disabled")
        return
    end

    -- Display option
    if value == nil or value == "" then
        self:DisplayOptionValue(option, registry, info)
        return
    end

    -- Set value based on type
    if optType == "toggle" then
        self:SetToggle(option, registry, info, value)
    elseif optType == "input" then
        self:SetInput(option, registry, info, value)
    elseif optType == "range" then
        self:SetRange(option, registry, info, value)
    elseif optType == "select" then
        self:SetSelect(option, registry, info, value)
    elseif optType == "multiselect" then
        self:SetMultiSelect(option, registry, info, value)
    elseif optType == "color" then
        self:SetColor(option, registry, info, value)
    elseif optType == "execute" then
        self:Execute(option, registry, info)
    elseif optType == "keybinding" then
        self:SetKeybinding(option, registry, info, value)
    else
        self:Print("Cannot set value for option type: " .. tostring(optType))
    end
end

--[[--------------------------------------------------------------------
    Display Functions
----------------------------------------------------------------------]]

--- Show available options in a group
-- @param appName string - App name
-- @param options table - Root options
-- @param registry table - Registry instance
-- @param path table - Current path
function LoolibConfigCmdMixin:ShowGroup(appName, options, registry, path)
    local group = options
    for _, key in ipairs(path) do
        group = group.args and group.args[key]
        if not group then
            self:Print("Path not found")
            return
        end
    end

    local info = registry:BuildInfoTable(options, group, appName, unpack(path))
    local name = registry:ResolveValue(group.name, info) or appName
    local pathStr = #path > 0 and (" > " .. table.concat(path, " > ")) or ""

    self:Print("|cff00ff00" .. name .. "|r" .. pathStr)

    -- Get sorted options
    local sorted = registry:GetSortedOptions(group)

    if #sorted == 0 then
        self:Print("  (no options)")
        return
    end

    for _, item in ipairs(sorted) do
        local key = item.key
        local opt = item.option
        local optInfo = registry:BuildInfoTable(options, opt, appName, unpack(path), key)

        -- Skip hidden options
        if not registry:IsHidden(opt, optInfo, "cmd") then
            local optName = registry:ResolveValue(opt.name, optInfo) or key
            local optType = opt.type
            local disabled = registry:IsDisabled(opt, optInfo)

            local line = "  "
            if disabled then
                line = line .. "|cff808080"
            else
                line = line .. "|cffffff00"
            end

            line = line .. key .. "|r"

            if optType == "group" then
                line = line .. " |cff888888[group]|r"
            elseif optType == "execute" then
                line = line .. " |cff888888[action]|r"
            elseif optType ~= "header" and optType ~= "description" then
                -- Show current value
                local value = registry:GetValue(opt, optInfo)
                if value ~= nil then
                    line = line .. " = " .. self:FormatValue(value, optType, opt)
                end
            end

            if optName ~= key then
                line = line .. " - " .. optName
            end

            self:Print(line)
        end
    end
end

--- Display current value of an option
-- @param option table - The option
-- @param registry table - Registry instance
-- @param info table - Info table
function LoolibConfigCmdMixin:DisplayOptionValue(option, registry, info)
    local name = registry:ResolveValue(option.name, info) or info[#info]
    local desc = registry:ResolveValue(option.desc, info)
    local optType = option.type

    if optType == "header" then
        self:Print("|cffffd700--- " .. name .. " ---|r")
        return
    end

    if optType == "description" then
        self:Print(name)
        return
    end

    if optType == "execute" then
        self:Print("|cffffff00" .. name .. "|r - Action")
        if desc then
            self:Print("  " .. desc)
        end
        self:Print("  Type the command again to execute")
        return
    end

    local value = registry:GetValue(option, info)
    local formattedValue = self:FormatValue(value, optType, option)

    self:Print("|cffffff00" .. name .. "|r = " .. formattedValue)

    if desc then
        self:Print("  " .. desc)
    end

    -- Show valid values for select
    if optType == "select" then
        local values = registry:ResolveValue(option.values, info)
        if values then
            local validKeys = {}
            for k in pairs(values) do
                validKeys[#validKeys + 1] = tostring(k)
            end
            table.sort(validKeys)
            self:Print("  Valid values: " .. table.concat(validKeys, ", "))
        end
    end

    -- Show range for range type
    if optType == "range" then
        local min = option.min or option.softMin or 0
        local max = option.max or option.softMax or 100
        self:Print(string.format("  Range: %s - %s", tostring(min), tostring(max)))
    end
end

--- Format a value for display
-- @param value any - The value
-- @param optType string - Option type
-- @param option table - The option
-- @return string - Formatted value
function LoolibConfigCmdMixin:FormatValue(value, optType, option)
    if value == nil then
        return "|cff888888(not set)|r"
    end

    if optType == "toggle" then
        if value == true then
            return "|cff00ff00true|r"
        elseif value == false then
            return "|cffff0000false|r"
        else
            return "|cff888888nil|r"
        end
    end

    if optType == "range" then
        if option.isPercent then
            return string.format("%.1f%%", value * 100)
        end
        return tostring(value)
    end

    if optType == "color" then
        if type(value) == "table" then
            local r, g, b, a = value.r or value[1] or 1, value.g or value[2] or 1,
                               value.b or value[3] or 1, value.a or value[4] or 1
            local colorCode = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
            return colorCode .. string.format("(%.2f, %.2f, %.2f, %.2f)|r", r, g, b, a)
        end
        return tostring(value)
    end

    if optType == "select" then
        -- Try to show the label if available
        return "|cff00ffff" .. tostring(value) .. "|r"
    end

    if type(value) == "string" then
        return '"' .. value .. '"'
    end

    return tostring(value)
end

--[[--------------------------------------------------------------------
    Value Setting Functions
----------------------------------------------------------------------]]

--- Set a toggle value
function LoolibConfigCmdMixin:SetToggle(option, registry, info, value)
    local boolValue
    value = value:lower()

    if value == "true" or value == "1" or value == "yes" or value == "on" then
        boolValue = true
    elseif value == "false" or value == "0" or value == "no" or value == "off" then
        boolValue = false
    elseif option.tristate and (value == "nil" or value == "none" or value == "default") then
        boolValue = nil
    else
        self:Print("Invalid value. Use: true/false, yes/no, on/off, 1/0")
        return
    end

    if registry:SetValue(option, info, boolValue) ~= false then
        self:Print("Set to " .. self:FormatValue(boolValue, "toggle", option))
    end
end

--- Set an input value
function LoolibConfigCmdMixin:SetInput(option, registry, info, value)
    -- Check pattern validation
    if option.pattern then
        if not value:match(option.pattern) then
            local usage = option.usage or "Value does not match required pattern"
            self:Print("|cffff0000Error:|r " .. usage)
            return
        end
    end

    if registry:SetValue(option, info, value) ~= false then
        self:Print('Set to "' .. value .. '"')
    end
end

--- Set a range value
function LoolibConfigCmdMixin:SetRange(option, registry, info, value)
    local numValue = tonumber(value)
    if not numValue then
        -- Check for percentage
        local pct = value:match("^(%d+%.?%d*)%%$")
        if pct and option.isPercent then
            numValue = tonumber(pct) / 100
        else
            self:Print("Invalid number: " .. value)
            return
        end
    end

    -- Check range
    local min = option.min
    local max = option.max

    if min and numValue < min then
        self:Print(string.format("Value must be at least %s", tostring(min)))
        return
    end

    if max and numValue > max then
        self:Print(string.format("Value must be at most %s", tostring(max)))
        return
    end

    if registry:SetValue(option, info, numValue) ~= false then
        self:Print("Set to " .. self:FormatValue(numValue, "range", option))
    end
end

--- Set a select value
function LoolibConfigCmdMixin:SetSelect(option, registry, info, value)
    local values = registry:ResolveValue(option.values, info)
    if not values then
        self:Print("No values available for this option")
        return
    end

    -- Check if value is valid
    if values[value] == nil then
        -- Try to find by label (case-insensitive)
        local valueLower = value:lower()
        for k, label in pairs(values) do
            if tostring(label):lower() == valueLower then
                value = k
                break
            end
        end
    end

    if values[value] == nil then
        local validKeys = {}
        for k in pairs(values) do
            validKeys[#validKeys + 1] = tostring(k)
        end
        table.sort(validKeys)
        self:Print("Invalid value. Valid options: " .. table.concat(validKeys, ", "))
        return
    end

    if registry:SetValue(option, info, value) ~= false then
        self:Print("Set to " .. value)
    end
end

--- Set a multiselect value
function LoolibConfigCmdMixin:SetMultiSelect(option, registry, info, value)
    -- Parse key=true/false
    local key, state = value:match("^(%S+)%s*=%s*(%S+)$")
    if not key then
        key = value
        state = nil
    end

    local values = registry:ResolveValue(option.values, info)
    if not values or values[key] == nil then
        local validKeys = {}
        for k in pairs(values or {}) do
            validKeys[#validKeys + 1] = tostring(k)
        end
        self:Print("Invalid key. Valid options: " .. table.concat(validKeys, ", "))
        return
    end

    local boolState
    if state then
        state = state:lower()
        if state == "true" or state == "1" or state == "yes" or state == "on" then
            boolState = true
        elseif state == "false" or state == "0" or state == "no" or state == "off" then
            boolState = false
        end
    else
        -- Toggle the current value
        local current = registry:GetValue(option, info)
        if type(current) == "table" then
            boolState = not current[key]
        else
            boolState = true
        end
    end

    if registry:SetValue(option, info, key, boolState) ~= false then
        self:Print(key .. " = " .. self:FormatValue(boolState, "toggle", option))
    end
end

--- Set a color value
function LoolibConfigCmdMixin:SetColor(option, registry, info, value)
    -- Parse color: "r g b" or "r g b a" or "#rrggbb" or "#rrggbbaa"
    local r, g, b, a

    -- Hex format
    local hex = value:match("^#?(%x+)$")
    if hex then
        if #hex == 6 then
            r = tonumber(hex:sub(1, 2), 16) / 255
            g = tonumber(hex:sub(3, 4), 16) / 255
            b = tonumber(hex:sub(5, 6), 16) / 255
            a = 1
        elseif #hex == 8 then
            r = tonumber(hex:sub(1, 2), 16) / 255
            g = tonumber(hex:sub(3, 4), 16) / 255
            b = tonumber(hex:sub(5, 6), 16) / 255
            a = tonumber(hex:sub(7, 8), 16) / 255
        end
    end

    -- Numeric format
    if not r then
        local nums = {}
        for n in value:gmatch("[%d%.]+") do
            nums[#nums + 1] = tonumber(n)
        end
        if #nums >= 3 then
            r, g, b = nums[1], nums[2], nums[3]
            a = nums[4] or 1
        end
    end

    if not r then
        self:Print("Invalid color. Use: r g b [a] (0-1) or #rrggbb or #rrggbbaa")
        return
    end

    if registry:SetValue(option, info, r, g, b, a) ~= false then
        self:Print(string.format("Set to (%.2f, %.2f, %.2f, %.2f)", r, g, b, a))
    end
end

--- Set a keybinding value
function LoolibConfigCmdMixin:SetKeybinding(option, registry, info, value)
    -- Normalize keybinding string
    value = value:upper():gsub("%s", "-")

    if registry:SetValue(option, info, value) ~= false then
        self:Print("Set to " .. value)
    end
end

--- Execute an action
function LoolibConfigCmdMixin:Execute(option, registry, info)
    if option.func then
        local success, err = pcall(registry.CallMethod, registry, option, info, option.func)
        if success then
            local name = registry:ResolveValue(option.name, info) or "Action"
            self:Print(name .. " executed")
        else
            self:Print("|cffff0000Error:|r " .. tostring(err))
        end
    else
        self:Print("No action defined")
    end
end

--[[--------------------------------------------------------------------
    Utility Functions
----------------------------------------------------------------------]]

--- Parse input string into path components
-- @param input string - Input string
-- @return table - Array of components
function LoolibConfigCmdMixin:ParseInput(input)
    local parts = {}

    -- Split by whitespace, respecting quotes
    local pos = 1
    local len = #input
    
    while pos <= len do
        -- Skip whitespace
        local wsEnd = input:match("^%s+()", pos)
        if wsEnd then
            pos = wsEnd
        end

        if pos > len then break end

        -- Check for quoted string
        local char = input:sub(pos, pos)
        if char == '"' or char == "'" then
            local quote = char
            local startPos = pos + 1
            local part = ""
            local current = startPos
            
            -- Look for closing quote, respecting escapes
            while current <= len do
                local c = input:sub(current, current)
                if c == "\\" then
                    -- Escape next char
                    current = current + 1
                    if current <= len then
                        part = part .. input:sub(current, current)
                        current = current + 1
                    end
                elseif c == quote then
                    -- Closing quote found
                    parts[#parts + 1] = part
                    pos = current + 1
                    break
                else
                    part = part .. c
                    current = current + 1
                end
            end
            
            if current > len then
                 -- No closing quote, just take what we found (or the rest)
                 -- This differs from previous behavior which took raw substring
                 -- Here we processed escapes, so we use 'part'
                 parts[#parts + 1] = part
                 pos = len + 1
            end
        else
            -- Unquoted, read until whitespace
            -- But also need to handle escaped spaces? 
            -- Let's support backslash escaping in unquoted strings too for consistency
            local part = ""
            local current = pos
            
            while current <= len do
                 local c = input:sub(current, current)
                 if c:match("%s") then
                     break
                 elseif c == "\\" then
                     current = current + 1
                     if current <= len then
                         part = part .. input:sub(current, current)
                     end
                 else
                     part = part .. c
                 end
                 current = current + 1
            end
            
            if part ~= "" then
                parts[#parts + 1] = part
            end
            pos = current
        end
    end

    return parts
end

--- Print a message to chat
-- @param msg string - Message to print
function LoolibConfigCmdMixin:Print(msg)
    if Loolib.Print then
        local ok = pcall(Loolib.Print, Loolib, msg)
        if ok then return end
    end
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

--[[--------------------------------------------------------------------
    Factory and Singleton
----------------------------------------------------------------------]]

--- Create a new config command handler
-- @return table - New handler instance
function CreateLoolibConfigCmd()
    local cmd = LoolibCreateFromMixins(LoolibConfigCmdMixin)
    cmd:Init()
    return cmd
end

-- Create the singleton instance
local ConfigCmd = CreateLoolibConfigCmd()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local ConfigCmdModule = {
    Mixin = LoolibConfigCmdMixin,
    Create = CreateLoolibConfigCmd,
    Cmd = ConfigCmd,  -- Singleton instance
}

Loolib:RegisterModule("ConfigCmd", ConfigCmdModule)
