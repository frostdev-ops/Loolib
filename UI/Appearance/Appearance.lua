--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Appearance - UI skin/theme management for frames with BackdropTemplate

    Provides skin registration, switching, and application to frames.
    Skins define visual appearance (textures, colors) that can be
    saved/loaded and applied to any frame using BackdropTemplate.

    Dependencies (must be loaded before this file):
    - Core/Loolib.lua (Loolib namespace)
    - Core/Mixin.lua (CreateFromMixins)
    - Core/TableUtil.lua (DeepCopy, Copy, Contains)
    - Events/CallbackRegistry.lua (CallbackRegistryMixin)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for Appearance")
local CallbackRegistryMixin = assert(Loolib.CallbackRegistryMixin, "Loolib.CallbackRegistryMixin is required for Appearance")
local TableUtil = assert(Loolib.TableUtil, "Loolib.TableUtil is required for Appearance")
local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
local AppearanceModule = UI.Appearance or Loolib:GetModule("UI.Appearance") or {}

-- Cache globals at file top
local error = error
local format = string.format
local ipairs = ipairs
local math_max = math.max
local math_min = math.min
local next = next
local pairs = pairs
local pcall = pcall
local tostring = tostring
local type = type
local wipe = wipe

--[[--------------------------------------------------------------------
    Default Skin Definition
----------------------------------------------------------------------]]

local DEFAULT_SKIN = {
    name = "Default",
    background = {
        texture = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        color = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 },
    },
    border = {
        texture = "Interface\\DialogFrame\\UI-DialogBox-Border",
        color = { r = 0.6, g = 0.6, b = 0.6, a = 1 },
    },
}

-- Common textures available for selection
local AVAILABLE_BACKGROUND_TEXTURES = {
    "Interface\\DialogFrame\\UI-DialogBox-Background",
    "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    "Interface\\Tooltips\\UI-Tooltip-Background",
    "Interface\\FrameGeneral\\UI-Background-Marble",
    "Interface\\FrameGeneral\\UI-Background-Rock",
    "Interface\\ChatFrame\\ChatFrameBackground",
}

local AVAILABLE_BORDER_TEXTURES = {
    "Interface\\DialogFrame\\UI-DialogBox-Border",
    "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    "Interface\\Tooltips\\UI-Tooltip-Border",
    "Interface\\FrameGeneral\\UIFrameSlicedBorder",
}

--[[--------------------------------------------------------------------
    Event Names
----------------------------------------------------------------------]]

local APPEARANCE_EVENTS = {
    "OnSkinChanged",
    "OnSkinSaved",
    "OnSkinDeleted",
}

--[[--------------------------------------------------------------------
    Internal Helpers
----------------------------------------------------------------------]]

-- INTERNAL: Clamp a number to [0, 1] range for color components
local function ClampColor(value)
    if type(value) ~= "number" then return nil end
    return math_max(0, math_min(1, value))
end

-- INTERNAL: Validate that a frame reference is still alive and usable.
-- WoW frames that have been garbage-collected or whose C-side object was
-- destroyed will error on any method call. We pcall a cheap introspection
-- method to detect this without risk.
local function IsFrameValid(frame)
    local frameType = type(frame)
    if frameType ~= "table" and frameType ~= "userdata" then
        return false
    end

    -- Probe liveness through a cheap object method. Keep the lookup and call
    -- inside pcall so dead/protected frame objects fail closed instead of
    -- throwing while we validate them.
    local ok, objectType = pcall(function()
        local getter = frame.GetObjectType
        if type(getter) ~= "function" then
            return nil
        end
        return getter(frame)
    end)

    return ok and type(objectType) == "string" and objectType ~= ""
end

-- INTERNAL: Validate a skin table has the required structure
local function ValidateSkinStructure(skin)
    if type(skin) ~= "table" then
        return false
    end
    if type(skin.background) ~= "table" then
        return false
    end
    if type(skin.border) ~= "table" then
        return false
    end
    if type(skin.background.color) ~= "table" then
        return false
    end
    if type(skin.border.color) ~= "table" then
        return false
    end
    -- Validate color fields are numbers
    local bgc = skin.background.color
    local brc = skin.border.color
    if type(bgc.r) ~= "number" or type(bgc.g) ~= "number" or type(bgc.b) ~= "number" then
        return false
    end
    if type(brc.r) ~= "number" or type(brc.g) ~= "number" or type(brc.b) ~= "number" then
        return false
    end
    -- Texture fields should be strings (if present)
    if skin.background.texture ~= nil and type(skin.background.texture) ~= "string" then
        return false
    end
    if skin.border.texture ~= nil and type(skin.border.texture) ~= "string" then
        return false
    end
    return true
end

-- INTERNAL: Sanitize a skin's numeric color fields to [0,1] range
local function SanitizeSkinColors(skin)
    if not skin then return end
    if skin.background and skin.background.color then
        local c = skin.background.color
        c.r = ClampColor(c.r) or 0
        c.g = ClampColor(c.g) or 0
        c.b = ClampColor(c.b) or 0
        c.a = ClampColor(c.a) or 1
    end
    if skin.border and skin.border.color then
        local c = skin.border.color
        c.r = ClampColor(c.r) or 0.6
        c.g = ClampColor(c.g) or 0.6
        c.b = ClampColor(c.b) or 0.6
        c.a = ClampColor(c.a) or 1
    end
end

--[[--------------------------------------------------------------------
    LoolibAppearanceMixin

    A mixin that provides skin management for UI appearance.
----------------------------------------------------------------------]]

local AppearanceMixin = AppearanceModule.Mixin or CreateFromMixins(CallbackRegistryMixin)

--- Initialize the appearance manager with saved data or defaults
-- @param savedData table|nil - Previously saved data (from SavedVariables)
function AppearanceMixin:Init(savedData)
    CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(APPEARANCE_EVENTS)

    -- FIX(AP-05): Validate savedData field types before applying
    if savedData ~= nil and type(savedData) ~= "table" then
        savedData = nil
    end
    savedData = savedData or {}

    -- Validate skins from saved data: must be a table of tables
    local loadedSkins = nil
    if type(savedData.skins) == "table" then
        loadedSkins = {}
        for name, skin in pairs(savedData.skins) do
            if type(name) == "string" and ValidateSkinStructure(skin) then
                SanitizeSkinColors(skin)
                loadedSkins[name] = skin
            end
        end
        -- If all skins were invalid, discard
        if not next(loadedSkins) then
            loadedSkins = nil
        end
    end

    -- Initialize skins collection
    self.skins = loadedSkins or { Default = TableUtil.DeepCopy(DEFAULT_SKIN) }

    -- Validate currentSkin name from saved data
    local requestedSkin = nil
    if type(savedData.currentSkin) == "string" and savedData.currentSkin ~= "" then
        requestedSkin = savedData.currentSkin
    end
    self.currentSkinName = requestedSkin or "Default"

    -- Ensure default skin always exists
    if not self.skins.Default then
        self.skins.Default = TableUtil.DeepCopy(DEFAULT_SKIN)
    end

    -- Set current skin reference
    self.currentSkin = self.skins[self.currentSkinName]
    if not self.currentSkin then
        self.currentSkinName = "Default"
        self.currentSkin = self.skins.Default
    end

    -- FIX(AP-01): Use weak-keyed table for registered frames to allow GC
    -- of frames that are destroyed but not explicitly unregistered.
    self.registeredFrames = setmetatable({}, { __mode = "k" })
end

--[[--------------------------------------------------------------------
    Skin Access
----------------------------------------------------------------------]]

--- Get the current skin data
-- @return table - The current skin table
function AppearanceMixin:GetCurrentSkin()
    return self.currentSkin
end

--- Get the current skin name
-- @return string - The name of the current skin
function AppearanceMixin:GetCurrentSkinName()
    return self.currentSkinName
end

--- Set the current skin by name
-- @param skinName string - Name of the skin to activate
-- @return boolean - True if skin was set successfully
function AppearanceMixin:SetCurrentSkin(skinName)
    if type(skinName) ~= "string" or skinName == "" then
        error("LoolibAppearance: SetCurrentSkin: skinName must be a non-empty string", 2)
    end

    local skin = self.skins[skinName]
    if not skin then
        Loolib:Error("Appearance:SetCurrentSkin - skin not found: " .. tostring(skinName))
        return false
    end

    local previousSkin = self.currentSkinName
    self.currentSkinName = skinName
    self.currentSkin = skin

    -- Update all registered frames
    self:UpdateRegisteredFrames()

    -- Fire event
    self:TriggerEvent("OnSkinChanged", skinName, previousSkin)

    return true
end

--- Get a list of all available skin names
-- @return table - Array of skin names (sorted alphabetically)
function AppearanceMixin:GetSkinList()
    local names = {}
    for name in pairs(self.skins) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

--- Get a specific skin by name
-- @param skinName string - Name of the skin
-- @return table|nil - The skin data or nil if not found
function AppearanceMixin:GetSkin(skinName)
    return self.skins[skinName]
end

--[[--------------------------------------------------------------------
    Skin Management
----------------------------------------------------------------------]]

--- Save current settings as a new skin or overwrite an existing one
-- @param name string - Name for the skin
-- @return boolean - True if saved successfully
function AppearanceMixin:SaveSkin(name)
    if type(name) ~= "string" or name == "" then
        error("LoolibAppearance: SaveSkin: name must be a non-empty string", 2)
    end

    -- Deep copy current skin settings
    self.skins[name] = TableUtil.DeepCopy(self.currentSkin)
    self.skins[name].name = name

    self:TriggerEvent("OnSkinSaved", name)
    return true
end

--- Load and apply a skin by name
-- @param name string - Name of the skin to load
-- @return boolean - True if loaded successfully
function AppearanceMixin:LoadSkin(name)
    return self:SetCurrentSkin(name)
end

--- Delete a skin by name
-- @param name string - Name of the skin to delete
-- @return boolean - True if deleted successfully
function AppearanceMixin:DeleteSkin(name)
    if type(name) ~= "string" or name == "" then
        error("LoolibAppearance: DeleteSkin: name must be a non-empty string", 2)
    end

    -- Cannot delete the Default skin
    if name == "Default" then
        Loolib:Error("Appearance:DeleteSkin - cannot delete the Default skin")
        return false
    end

    -- Cannot delete the current skin
    if name == self.currentSkinName then
        Loolib:Error("Appearance:DeleteSkin - cannot delete the current skin. Switch to another skin first.")
        return false
    end

    -- Check if skin exists
    if not self.skins[name] then
        Loolib:Error("Appearance:DeleteSkin - skin not found: " .. tostring(name))
        return false
    end

    self.skins[name] = nil
    self:TriggerEvent("OnSkinDeleted", name)
    return true
end

--- Reset all skins to defaults
function AppearanceMixin:ResetSkins()
    local previousSkin = self.currentSkinName
    wipe(self.skins)
    self.skins.Default = TableUtil.DeepCopy(DEFAULT_SKIN)
    self.currentSkinName = "Default"
    self.currentSkin = self.skins.Default

    self:UpdateRegisteredFrames()
    self:TriggerEvent("OnSkinChanged", "Default", previousSkin)
end

--[[--------------------------------------------------------------------
    Background Settings
----------------------------------------------------------------------]]

--- Get the current background texture path
-- @return string - Texture path
function AppearanceMixin:GetBackgroundTexture()
    if not self.currentSkin or not self.currentSkin.background then
        return DEFAULT_SKIN.background.texture
    end
    return self.currentSkin.background.texture or DEFAULT_SKIN.background.texture
end

--- Set the background texture
-- @param texture string - Texture path
function AppearanceMixin:SetBackgroundTexture(texture)
    if type(texture) ~= "string" then
        error("LoolibAppearance: SetBackgroundTexture: texture must be a string", 2)
    end
    if not self.currentSkin or not self.currentSkin.background then return end
    self.currentSkin.background.texture = texture
    self:UpdateRegisteredFrames()
end

--- Get the current background color
-- @return number, number, number, number - r, g, b, a values
function AppearanceMixin:GetBackgroundColor()
    if not self.currentSkin or not self.currentSkin.background or not self.currentSkin.background.color then
        return 0, 0, 0, 1  -- Return safe default
    end
    local c = self.currentSkin.background.color
    return c.r or 0, c.g or 0, c.b or 0, c.a or 1
end

--- Set the background color
-- @param r number - Red component (0-1)
-- @param g number - Green component (0-1)
-- @param b number - Blue component (0-1)
-- @param a number - Alpha component (0-1, optional, defaults to existing)
function AppearanceMixin:SetBackgroundColor(r, g, b, a)
    if not self.currentSkin or not self.currentSkin.background or not self.currentSkin.background.color then
        return
    end
    local c = self.currentSkin.background.color
    -- Clamp provided values, keep existing if nil
    c.r = ClampColor(r) or c.r
    c.g = ClampColor(g) or c.g
    c.b = ClampColor(b) or c.b
    c.a = ClampColor(a) or c.a
    self:UpdateRegisteredFrames()
end

--[[--------------------------------------------------------------------
    Border Settings
----------------------------------------------------------------------]]

--- Get the current border texture path
-- @return string - Texture path
function AppearanceMixin:GetBorderTexture()
    if not self.currentSkin or not self.currentSkin.border then
        return DEFAULT_SKIN.border.texture
    end
    return self.currentSkin.border.texture or DEFAULT_SKIN.border.texture
end

--- Set the border texture
-- @param texture string - Texture path
function AppearanceMixin:SetBorderTexture(texture)
    if type(texture) ~= "string" then
        error("LoolibAppearance: SetBorderTexture: texture must be a string", 2)
    end
    if not self.currentSkin or not self.currentSkin.border then return end
    self.currentSkin.border.texture = texture
    self:UpdateRegisteredFrames()
end

--- Get the current border color
-- @return number, number, number, number - r, g, b, a values
function AppearanceMixin:GetBorderColor()
    if not self.currentSkin or not self.currentSkin.border or not self.currentSkin.border.color then
        return 0.6, 0.6, 0.6, 1  -- Return safe default
    end
    local c = self.currentSkin.border.color
    return c.r or 0.6, c.g or 0.6, c.b or 0.6, c.a or 1
end

--- Set the border color
-- @param r number - Red component (0-1)
-- @param g number - Green component (0-1)
-- @param b number - Blue component (0-1)
-- @param a number - Alpha component (0-1, optional, defaults to existing)
function AppearanceMixin:SetBorderColor(r, g, b, a)
    if not self.currentSkin or not self.currentSkin.border or not self.currentSkin.border.color then
        return
    end
    local c = self.currentSkin.border.color
    -- Clamp provided values, keep existing if nil
    c.r = ClampColor(r) or c.r
    c.g = ClampColor(g) or c.g
    c.b = ClampColor(b) or c.b
    c.a = ClampColor(a) or c.a
    self:UpdateRegisteredFrames()
end

--[[--------------------------------------------------------------------
    Frame Application
----------------------------------------------------------------------]]

--- Apply the current skin to a frame with BackdropTemplate
-- @param frame Frame - The frame to apply skin to (must have BackdropTemplate)
function AppearanceMixin:ApplyToFrame(frame)
    -- FIX(AP-01): Validate frame is alive before calling any methods on it
    if not IsFrameValid(frame) then
        return
    end
    if not frame.SetBackdrop then
        return
    end

    local skin = self.currentSkin
    if not skin or not skin.background or not skin.border then
        return
    end
    if not skin.background.color or not skin.border.color then
        return
    end

    -- FIX(AP-03): If both textures are nil/empty, clear the backdrop and return
    -- without attempting SetBackdropColor which would error after SetBackdrop(nil).
    local bgTexture = skin.background.texture
    local borderTexture = skin.border.texture
    if not bgTexture and not borderTexture then
        frame:SetBackdrop(nil)
        return
    end

    -- Build and apply backdrop
    local backdrop = {
        bgFile = bgTexture,
        edgeFile = borderTexture,
        tile = true,
        tileEdge = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    }

    frame:SetBackdrop(backdrop)

    -- FIX(AP-03): Guard SetBackdropColor/SetBackdropBorderColor — these
    -- methods are only valid after a successful SetBackdrop with content.
    -- After SetBackdrop(nil) or with no bgFile, SetBackdropColor may error.
    if frame.SetBackdropColor and bgTexture then
        local bg = skin.background.color
        frame:SetBackdropColor(bg.r or 0, bg.g or 0, bg.b or 0, bg.a or 1)
    end

    if frame.SetBackdropBorderColor and borderTexture then
        local border = skin.border.color
        frame:SetBackdropBorderColor(border.r or 0.6, border.g or 0.6, border.b or 0.6, border.a or 1)
    end
end

--- Register a frame to automatically receive skin updates
-- @param frame Frame - The frame to register
function AppearanceMixin:RegisterFrame(frame)
    if not IsFrameValid(frame) then
        error("LoolibAppearance: RegisterFrame: frame must be a valid frame object", 2)
    end
    self.registeredFrames[frame] = true
    self:ApplyToFrame(frame)
end

--- Unregister a frame from automatic skin updates
-- @param frame Frame - The frame to unregister
function AppearanceMixin:UnregisterFrame(frame)
    if not frame then return end
    self.registeredFrames[frame] = nil
end

--- Update all registered frames with current skin
-- FIX(AP-01): Validate each frame is still alive before calling methods.
-- Collect stale references in a separate pass to avoid modifying the table
-- during iteration.
function AppearanceMixin:UpdateRegisteredFrames()
    local stale  -- INTERNAL: lazily allocated list of dead frame refs
    for frame in pairs(self.registeredFrames) do
        if IsFrameValid(frame) and frame.SetBackdrop then
            self:ApplyToFrame(frame)
        else
            -- Collect stale refs for removal after iteration
            if not stale then stale = {} end
            stale[#stale + 1] = frame
        end
    end
    -- Remove stale references
    if stale then
        for i = 1, #stale do
            self.registeredFrames[stale[i]] = nil
        end
    end
end

--[[--------------------------------------------------------------------
    Serialization
----------------------------------------------------------------------]]

--- Get save data for persistence
-- @return table - Data suitable for SavedVariables
function AppearanceMixin:GetSaveData()
    return {
        skins = TableUtil.DeepCopy(self.skins),
        currentSkin = self.currentSkinName,
    }
end

--[[--------------------------------------------------------------------
    Options Table Generation (AceConfig-style)
----------------------------------------------------------------------]]

--- Generate an AceConfig-style options table for appearance settings
-- @return table - Options table for use with GUI/config systems
function AppearanceMixin:GenerateOptionsTable()
    ---@diagnostic disable-next-line: redefined-local
    local self = self

    -- Build skin dropdown values
    local function GetSkinValues()
        local values = {}
        for name in pairs(self.skins) do
            values[name] = name
        end
        return values
    end

    -- Build texture dropdown values for backgrounds
    local function GetBackgroundTextureValues()
        local values = {}
        for _, texture in ipairs(AVAILABLE_BACKGROUND_TEXTURES) do
            -- Use filename as display name
            local displayName = texture:match("([^\\]+)$") or texture
            values[texture] = displayName
        end
        return values
    end

    -- Build texture dropdown values for borders
    local function GetBorderTextureValues()
        local values = {}
        for _, texture in ipairs(AVAILABLE_BORDER_TEXTURES) do
            local displayName = texture:match("([^\\]+)$") or texture
            values[texture] = displayName
        end
        return values
    end

    local options = {
        type = "group",
        name = "Appearance",
        desc = "Skin and visual customization settings",
        order = 100,
        args = {
            -- Skin Selection Header
            skinHeader = {
                type = "header",
                name = "Skin Selection",
                order = 1,
            },

            -- Current Skin Dropdown
            currentSkin = {
                type = "select",
                name = "Active Skin",
                desc = "Select the active skin preset",
                order = 2,
                values = GetSkinValues,
                get = function()
                    return self:GetCurrentSkinName()
                end,
                set = function(_, value)
                    self:SetCurrentSkin(value)
                end,
            },

            -- Skin Management Group
            skinManagement = {
                type = "group",
                name = "Skin Management",
                inline = true,
                order = 3,
                args = {
                    saveSkinName = {
                        type = "input",
                        name = "New Skin Name",
                        desc = "Enter a name for the new skin",
                        order = 1,
                        get = function() return "" end,
                        set = function(_, value)
                            if value and value ~= "" then
                                self:SaveSkin(value)
                            end
                        end,
                    },
                    saveSkin = {
                        type = "execute",
                        name = "Save Current as Skin",
                        desc = "Save current settings as a new skin (use name above)",
                        order = 2,
                        func = function()
                            -- This requires the saveSkinName to be entered first
                        end,
                        disabled = true, -- Use the input above instead
                    },
                    deleteSkin = {
                        type = "select",
                        name = "Delete Skin",
                        desc = "Select a skin to delete (cannot delete Default or current skin)",
                        order = 3,
                        values = function()
                            local values = {}
                            for name in pairs(self.skins) do
                                if name ~= "Default" and name ~= self:GetCurrentSkinName() then
                                    values[name] = name
                                end
                            end
                            return values
                        end,
                        get = function() return nil end,
                        set = function(_, value)
                            self:DeleteSkin(value)
                        end,
                        confirm = function(_, value)
                            return "Are you sure you want to delete the skin '" .. value .. "'?"
                        end,
                    },
                    resetSkins = {
                        type = "execute",
                        name = "Reset All Skins",
                        desc = "Reset all skins to defaults",
                        order = 4,
                        func = function()
                            self:ResetSkins()
                        end,
                        confirm = true,
                        confirmText = "Are you sure you want to reset all skins? This cannot be undone.",
                    },
                },
            },

            -- Background Settings Header
            backgroundHeader = {
                type = "header",
                name = "Background",
                order = 10,
            },

            -- Background Texture
            backgroundTexture = {
                type = "select",
                name = "Background Texture",
                desc = "Select the background texture",
                order = 11,
                values = GetBackgroundTextureValues,
                get = function()
                    return self:GetBackgroundTexture()
                end,
                set = function(_, value)
                    self:SetBackgroundTexture(value)
                end,
            },

            -- Background Color
            backgroundColor = {
                type = "color",
                name = "Background Color",
                desc = "Set the background color and opacity",
                order = 12,
                hasAlpha = true,
                get = function()
                    return self:GetBackgroundColor()
                end,
                set = function(_, r, g, b, a)
                    self:SetBackgroundColor(r, g, b, a)
                end,
            },

            -- Border Settings Header
            borderHeader = {
                type = "header",
                name = "Border",
                order = 20,
            },

            -- Border Texture
            borderTexture = {
                type = "select",
                name = "Border Texture",
                desc = "Select the border texture",
                order = 21,
                values = GetBorderTextureValues,
                get = function()
                    return self:GetBorderTexture()
                end,
                set = function(_, value)
                    self:SetBorderTexture(value)
                end,
            },

            -- Border Color
            borderColor = {
                type = "color",
                name = "Border Color",
                desc = "Set the border color and opacity",
                order = 22,
                hasAlpha = true,
                get = function()
                    return self:GetBorderColor()
                end,
                set = function(_, r, g, b, a)
                    self:SetBorderColor(r, g, b, a)
                end,
            },
        },
    }

    return options
end

--[[--------------------------------------------------------------------
    Available Textures Access
----------------------------------------------------------------------]]

--- Get list of available background textures
-- @return table - Array of texture paths
function AppearanceMixin:GetAvailableBackgroundTextures()
    return TableUtil.Copy(AVAILABLE_BACKGROUND_TEXTURES)
end

--- Get list of available border textures
-- @return table - Array of texture paths
function AppearanceMixin:GetAvailableBorderTextures()
    return TableUtil.Copy(AVAILABLE_BORDER_TEXTURES)
end

--- Add a custom background texture to the available list
-- @param texture string - Texture path
function AppearanceMixin:AddBackgroundTexture(texture)
    if type(texture) ~= "string" then
        error("LoolibAppearance: AddBackgroundTexture: texture must be a string", 2)
    end
    if not TableUtil.Contains(AVAILABLE_BACKGROUND_TEXTURES, texture) then
        AVAILABLE_BACKGROUND_TEXTURES[#AVAILABLE_BACKGROUND_TEXTURES + 1] = texture
    end
end

--- Add a custom border texture to the available list
-- @param texture string - Texture path
function AppearanceMixin:AddBorderTexture(texture)
    if type(texture) ~= "string" then
        error("LoolibAppearance: AddBorderTexture: texture must be a string", 2)
    end
    if not TableUtil.Contains(AVAILABLE_BORDER_TEXTURES, texture) then
        AVAILABLE_BORDER_TEXTURES[#AVAILABLE_BORDER_TEXTURES + 1] = texture
    end
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new Appearance manager instance
-- @param savedData table|nil - Previously saved data
-- @return table - A new Appearance instance
local function CreateAppearance(savedData)
    local appearance = CreateFromMixins(AppearanceMixin)
    appearance:Init(savedData)
    return appearance
end

--[[--------------------------------------------------------------------
    Singleton Instance

    FIX(AP-04): The singleton is safe to create at file-load time because
    the assert guards at the top of this file ensure CallbackRegistryMixin
    and all other dependencies are present before we reach this point.
    If any dependency is missing, execution halts at the assert, never
    reaching singleton creation.
----------------------------------------------------------------------]]

-- Create a default singleton instance
local appearanceManager = CreateAppearance()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

AppearanceModule.Mixin = AppearanceMixin
AppearanceModule.Create = CreateAppearance
AppearanceModule.Instance = appearanceManager

-- Default skin reference
AppearanceModule.DEFAULT_SKIN = DEFAULT_SKIN
AppearanceModule.AVAILABLE_BACKGROUND_TEXTURES = AVAILABLE_BACKGROUND_TEXTURES
AppearanceModule.AVAILABLE_BORDER_TEXTURES = AVAILABLE_BORDER_TEXTURES

-- Convenience functions from singleton
-- Note: These are free-function wrappers. The vararg correctly forwards
-- all arguments because the singleton methods use explicit self (colon syntax).
AppearanceModule.GetCurrentSkin = function() return appearanceManager:GetCurrentSkin() end
AppearanceModule.SetCurrentSkin = function(...) return appearanceManager:SetCurrentSkin(...) end
AppearanceModule.GetSkinList = function() return appearanceManager:GetSkinList() end
AppearanceModule.SaveSkin = function(...) return appearanceManager:SaveSkin(...) end
AppearanceModule.LoadSkin = function(...) return appearanceManager:LoadSkin(...) end
AppearanceModule.DeleteSkin = function(...) return appearanceManager:DeleteSkin(...) end
AppearanceModule.ApplyToFrame = function(...) return appearanceManager:ApplyToFrame(...) end
AppearanceModule.RegisterFrame = function(...) return appearanceManager:RegisterFrame(...) end
AppearanceModule.GenerateOptionsTable = function() return appearanceManager:GenerateOptionsTable() end

UI.Appearance = AppearanceModule
UI.AppearanceManager = appearanceManager
Loolib.AppearanceMixin = AppearanceMixin
Loolib.CreateAppearance = CreateAppearance
Loolib.AppearanceManager = appearanceManager

Loolib:RegisterModule("UI.Appearance", AppearanceModule)
