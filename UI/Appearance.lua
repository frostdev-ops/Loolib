--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Appearance - UI skin/theme management for frames with BackdropTemplate

    Provides skin registration, switching, and application to frames.
    Skins define visual appearance (textures, colors) that can be
    saved/loaded and applied to any frame using BackdropTemplate.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

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
    LoolibAppearanceMixin

    A mixin that provides skin management for UI appearance.
----------------------------------------------------------------------]]

LoolibAppearanceMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

--- Initialize the appearance manager with saved data or defaults
-- @param savedData table|nil - Previously saved data (from SavedVariables)
function LoolibAppearanceMixin:Init(savedData)
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(APPEARANCE_EVENTS)

    savedData = savedData or {}

    -- Initialize skins collection
    self.skins = savedData.skins or { Default = LoolibTableUtil.DeepCopy(DEFAULT_SKIN) }
    self.currentSkinName = savedData.currentSkin or "Default"

    -- Ensure default skin always exists
    if not self.skins.Default then
        self.skins.Default = LoolibTableUtil.DeepCopy(DEFAULT_SKIN)
    end

    -- Set current skin reference
    self.currentSkin = self.skins[self.currentSkinName]
    if not self.currentSkin then
        self.currentSkinName = "Default"
        self.currentSkin = self.skins.Default
    end

    -- Track registered frames for automatic updates
    self.registeredFrames = {}
end

--[[--------------------------------------------------------------------
    Skin Access
----------------------------------------------------------------------]]

--- Get the current skin data
-- @return table - The current skin table
function LoolibAppearanceMixin:GetCurrentSkin()
    return self.currentSkin
end

--- Get the current skin name
-- @return string - The name of the current skin
function LoolibAppearanceMixin:GetCurrentSkinName()
    return self.currentSkinName
end

--- Set the current skin by name
-- @param skinName string - Name of the skin to activate
-- @return boolean - True if skin was set successfully
function LoolibAppearanceMixin:SetCurrentSkin(skinName)
    if not skinName or skinName == "" then
        Loolib:Error("Appearance:SetCurrentSkin - skin name is required")
        return false
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
function LoolibAppearanceMixin:GetSkinList()
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
function LoolibAppearanceMixin:GetSkin(skinName)
    return self.skins[skinName]
end

--[[--------------------------------------------------------------------
    Skin Management
----------------------------------------------------------------------]]

--- Save current settings as a new skin or overwrite an existing one
-- @param name string - Name for the skin
-- @return boolean - True if saved successfully
function LoolibAppearanceMixin:SaveSkin(name)
    if not name or name == "" then
        Loolib:Error("Appearance:SaveSkin - name is required")
        return false
    end

    -- Deep copy current skin settings
    self.skins[name] = LoolibTableUtil.DeepCopy(self.currentSkin)
    self.skins[name].name = name

    self:TriggerEvent("OnSkinSaved", name)
    return true
end

--- Load and apply a skin by name
-- @param name string - Name of the skin to load
-- @return boolean - True if loaded successfully
function LoolibAppearanceMixin:LoadSkin(name)
    return self:SetCurrentSkin(name)
end

--- Delete a skin by name
-- @param name string - Name of the skin to delete
-- @return boolean - True if deleted successfully
function LoolibAppearanceMixin:DeleteSkin(name)
    if not name or name == "" then
        Loolib:Error("Appearance:DeleteSkin - name is required")
        return false
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
function LoolibAppearanceMixin:ResetSkins()
    local previousSkin = self.currentSkinName
    wipe(self.skins)
    self.skins.Default = LoolibTableUtil.DeepCopy(DEFAULT_SKIN)
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
function LoolibAppearanceMixin:GetBackgroundTexture()
    if not self.currentSkin or not self.currentSkin.background then
        return "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
    end
    return self.currentSkin.background.texture
end

--- Set the background texture
-- @param texture string - Texture path
function LoolibAppearanceMixin:SetBackgroundTexture(texture)
    if not texture then return end
    if not self.currentSkin or not self.currentSkin.background then return end
    self.currentSkin.background.texture = texture
    self:UpdateRegisteredFrames()
end

--- Get the current background color
-- @return number, number, number, number - r, g, b, a values
function LoolibAppearanceMixin:GetBackgroundColor()
    if not self.currentSkin or not self.currentSkin.background or not self.currentSkin.background.color then
        return 0, 0, 0, 1  -- Return safe default
    end
    local c = self.currentSkin.background.color
    return c.r, c.g, c.b, c.a
end

--- Set the background color
-- @param r number - Red component (0-1)
-- @param g number - Green component (0-1)
-- @param b number - Blue component (0-1)
-- @param a number - Alpha component (0-1, optional, defaults to existing)
function LoolibAppearanceMixin:SetBackgroundColor(r, g, b, a)
    if not self.currentSkin or not self.currentSkin.background or not self.currentSkin.background.color then
        return
    end
    local c = self.currentSkin.background.color
    c.r = r or c.r
    c.g = g or c.g
    c.b = b or c.b
    c.a = a or c.a
    self:UpdateRegisteredFrames()
end

--[[--------------------------------------------------------------------
    Border Settings
----------------------------------------------------------------------]]

--- Get the current border texture path
-- @return string - Texture path
function LoolibAppearanceMixin:GetBorderTexture()
    if not self.currentSkin or not self.currentSkin.border then
        return "Interface\\DialogFrame\\UI-DialogBox-Border"
    end
    return self.currentSkin.border.texture
end

--- Set the border texture
-- @param texture string - Texture path
function LoolibAppearanceMixin:SetBorderTexture(texture)
    if not texture then return end
    if not self.currentSkin or not self.currentSkin.border then return end
    self.currentSkin.border.texture = texture
    self:UpdateRegisteredFrames()
end

--- Get the current border color
-- @return number, number, number, number - r, g, b, a values
function LoolibAppearanceMixin:GetBorderColor()
    if not self.currentSkin or not self.currentSkin.border or not self.currentSkin.border.color then
        return 0.6, 0.6, 0.6, 1  -- Return safe default
    end
    local c = self.currentSkin.border.color
    return c.r, c.g, c.b, c.a
end

--- Set the border color
-- @param r number - Red component (0-1)
-- @param g number - Green component (0-1)
-- @param b number - Blue component (0-1)
-- @param a number - Alpha component (0-1, optional, defaults to existing)
function LoolibAppearanceMixin:SetBorderColor(r, g, b, a)
    if not self.currentSkin or not self.currentSkin.border or not self.currentSkin.border.color then
        return
    end
    local c = self.currentSkin.border.color
    c.r = r or c.r
    c.g = g or c.g
    c.b = b or c.b
    c.a = a or c.a
    self:UpdateRegisteredFrames()
end

--[[--------------------------------------------------------------------
    Frame Application
----------------------------------------------------------------------]]

--- Apply the current skin to a frame with BackdropTemplate
-- @param frame Frame - The frame to apply skin to (must have BackdropTemplate)
function LoolibAppearanceMixin:ApplyToFrame(frame)
    if not frame or not frame.SetBackdrop then
        return
    end

    local skin = self.currentSkin
    if not skin or not skin.background or not skin.border then
        return
    end
    if not skin.background.color or not skin.border.color then
        return
    end

    -- Build and apply backdrop
    local backdrop = {
        bgFile = skin.background.texture,
        edgeFile = skin.border.texture,
        tile = true,
        tileEdge = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    }

    frame:SetBackdrop(backdrop)

    -- Apply background color
    local bg = skin.background.color
    frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)

    -- Apply border color
    local border = skin.border.color
    frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
end

--- Register a frame to automatically receive skin updates
-- @param frame Frame - The frame to register
function LoolibAppearanceMixin:RegisterFrame(frame)
    if not frame then return end
    self.registeredFrames[frame] = true
    self:ApplyToFrame(frame)
end

--- Unregister a frame from automatic skin updates
-- @param frame Frame - The frame to unregister
function LoolibAppearanceMixin:UnregisterFrame(frame)
    if not frame then return end
    self.registeredFrames[frame] = nil
end

--- Update all registered frames with current skin
function LoolibAppearanceMixin:UpdateRegisteredFrames()
    for frame in pairs(self.registeredFrames) do
        if frame and frame.SetBackdrop then
            self:ApplyToFrame(frame)
        else
            self.registeredFrames[frame] = nil
        end
    end
end

--[[--------------------------------------------------------------------
    Serialization
----------------------------------------------------------------------]]

--- Get save data for persistence
-- @return table - Data suitable for SavedVariables
function LoolibAppearanceMixin:GetSaveData()
    return {
        skins = LoolibTableUtil.DeepCopy(self.skins),
        currentSkin = self.currentSkinName,
    }
end

--[[--------------------------------------------------------------------
    Options Table Generation (AceConfig-style)
----------------------------------------------------------------------]]

--- Generate an AceConfig-style options table for appearance settings
-- @return table - Options table for use with GUI/config systems
function LoolibAppearanceMixin:GenerateOptionsTable()
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
                set = function(info, value)
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
                        set = function(info, value)
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
                        set = function(info, value)
                            self:DeleteSkin(value)
                        end,
                        confirm = function(info, value)
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
                set = function(info, value)
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
                set = function(info, r, g, b, a)
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
                set = function(info, value)
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
                set = function(info, r, g, b, a)
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
function LoolibAppearanceMixin:GetAvailableBackgroundTextures()
    return LoolibTableUtil.Copy(AVAILABLE_BACKGROUND_TEXTURES)
end

--- Get list of available border textures
-- @return table - Array of texture paths
function LoolibAppearanceMixin:GetAvailableBorderTextures()
    return LoolibTableUtil.Copy(AVAILABLE_BORDER_TEXTURES)
end

--- Add a custom background texture to the available list
-- @param texture string - Texture path
function LoolibAppearanceMixin:AddBackgroundTexture(texture)
    if not LoolibTableUtil.Contains(AVAILABLE_BACKGROUND_TEXTURES, texture) then
        AVAILABLE_BACKGROUND_TEXTURES[#AVAILABLE_BACKGROUND_TEXTURES + 1] = texture
    end
end

--- Add a custom border texture to the available list
-- @param texture string - Texture path
function LoolibAppearanceMixin:AddBorderTexture(texture)
    if not LoolibTableUtil.Contains(AVAILABLE_BORDER_TEXTURES, texture) then
        AVAILABLE_BORDER_TEXTURES[#AVAILABLE_BORDER_TEXTURES + 1] = texture
    end
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new Appearance manager instance
-- @param savedData table|nil - Previously saved data
-- @return table - A new Appearance instance
function CreateLoolibAppearance(savedData)
    local appearance = LoolibCreateFromMixins(LoolibAppearanceMixin)
    appearance:Init(savedData)
    return appearance
end

--[[--------------------------------------------------------------------
    Singleton Instance (optional convenience)
----------------------------------------------------------------------]]

-- Create a default singleton instance
LoolibAppearance = CreateLoolibAppearance()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local AppearanceModule = {
    Mixin = LoolibAppearanceMixin,
    Create = CreateLoolibAppearance,
    Instance = LoolibAppearance,

    -- Default skin reference
    DEFAULT_SKIN = DEFAULT_SKIN,
    AVAILABLE_BACKGROUND_TEXTURES = AVAILABLE_BACKGROUND_TEXTURES,
    AVAILABLE_BORDER_TEXTURES = AVAILABLE_BORDER_TEXTURES,

    -- Convenience functions from singleton
    GetCurrentSkin = function() return LoolibAppearance:GetCurrentSkin() end,
    SetCurrentSkin = function(...) return LoolibAppearance:SetCurrentSkin(...) end,
    GetSkinList = function() return LoolibAppearance:GetSkinList() end,
    SaveSkin = function(...) return LoolibAppearance:SaveSkin(...) end,
    LoadSkin = function(...) return LoolibAppearance:LoadSkin(...) end,
    DeleteSkin = function(...) return LoolibAppearance:DeleteSkin(...) end,
    ApplyToFrame = function(...) return LoolibAppearance:ApplyToFrame(...) end,
    RegisterFrame = function(...) return LoolibAppearance:RegisterFrame(...) end,
    GenerateOptionsTable = function() return LoolibAppearance:GenerateOptionsTable() end,
}

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.Appearance = AppearanceModule
UI.AppearanceManager = LoolibAppearance

Loolib:RegisterModule("Appearance", AppearanceModule)
