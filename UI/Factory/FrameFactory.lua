--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    FrameFactory - Universal frame creation with template caching

    Based on Blizzard's FrameFactoryMixin pattern. Provides unified
    frame creation with automatic pooling, mixin application, and
    template detection.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Template Info Cache

    Caches information about XML templates to avoid repeated lookups.
----------------------------------------------------------------------]]

LoolibTemplateInfoCacheMixin = {}

function LoolibTemplateInfoCacheMixin:Init()
    self.cache = {}
end

--- Get information about a template
-- @param templateName string - The template name
-- @return table|nil - Template info or nil if not a template
function LoolibTemplateInfoCacheMixin:GetTemplateInfo(templateName)
    if not templateName or templateName == "" then
        return nil
    end

    if self.cache[templateName] == nil then
        -- Try to get template info from WoW API
        local success, info = pcall(function()
            return C_XMLUtil.GetTemplateInfo(templateName)
        end)

        if success and info then
            self.cache[templateName] = info
        else
            self.cache[templateName] = false
        end
    end

    local result = self.cache[templateName]
    return result ~= false and result or nil
end

--- Check if a string is a known frame type (not a template)
-- @param name string - The name to check
-- @return boolean
function LoolibTemplateInfoCacheMixin:IsFrameType(name)
    local frameTypes = {
        Frame = true, Button = true, CheckButton = true, EditBox = true,
        ScrollFrame = true, Slider = true, StatusBar = true, Cooldown = true,
        ColorSelect = true, GameTooltip = true, MessageFrame = true,
        Model = true, PlayerModel = true, DressUpModel = true,
        MovieFrame = true, SimpleHTML = true, Browser = true,
        ModelScene = true, OffScreenFrame = true,
    }
    return frameTypes[name] == true
end

--- Clear the cache
function LoolibTemplateInfoCacheMixin:Clear()
    wipe(self.cache)
end

--- Create a new template info cache
function CreateLoolibTemplateInfoCache()
    local cache = LoolibCreateFromMixins(LoolibTemplateInfoCacheMixin)
    cache:Init()
    return cache
end

--[[--------------------------------------------------------------------
    LoolibFrameFactoryMixin

    A mixin that provides universal frame creation with pooling.
----------------------------------------------------------------------]]

LoolibFrameFactoryMixin = {}

function LoolibFrameFactoryMixin:Init()
    self.templateInfoCache = CreateLoolibTemplateInfoCache()
    self.poolCollection = CreateLoolibPoolCollection()
end

--[[--------------------------------------------------------------------
    Frame Creation
----------------------------------------------------------------------]]

--- Create a frame (or acquire from pool)
-- @param parent Frame - Parent frame
-- @param frameTemplateOrType string - Template name or frame type
-- @param resetFunc function - Optional reset function
-- @return Frame, boolean, table - Frame, isNew, templateInfo
function LoolibFrameFactoryMixin:Create(parent, frameTemplateOrType, resetFunc)
    local frameTemplate = nil
    local frameType = nil
    local info = nil

    -- Determine if it's a template or frame type
    if self.templateInfoCache:IsFrameType(frameTemplateOrType) then
        -- It's a native frame type
        frameType = frameTemplateOrType
        frameTemplate = nil
    else
        -- Try to get template info
        info = self.templateInfoCache:GetTemplateInfo(frameTemplateOrType)
        if info then
            frameTemplate = frameTemplateOrType
            frameType = info.type or "Frame"
        else
            -- Assume it's a template we don't have info for
            frameTemplate = frameTemplateOrType
            frameType = "Frame"
        end
    end

    -- Use pool collection to acquire/create
    local pool, isNewPool = self.poolCollection:GetOrCreatePool(
        frameType,
        parent,
        frameTemplate,
        resetFunc or LoolibPoolReset_Frame
    )

    local frame, isNew = pool:Acquire()

    return frame, isNew, info
end

--- Create a frame with mixins applied
-- @param parent Frame - Parent frame
-- @param frameTemplateOrType string - Template name or frame type
-- @param resetFunc function - Optional reset function
-- @param ... - Mixins to apply
-- @return Frame, boolean
function LoolibFrameFactoryMixin:CreateWithMixins(parent, frameTemplateOrType, resetFunc, ...)
    local frame, isNew, info = self:Create(parent, frameTemplateOrType, resetFunc)

    if isNew then
        local mixinCount = select("#", ...)
        if mixinCount > 0 then
            LoolibMixin(frame, ...)
            LoolibReflectScriptHandlers(frame)

            if frame.Init then
                frame:Init()
            end
        end
    end

    return frame, isNew
end

--[[--------------------------------------------------------------------
    Release
----------------------------------------------------------------------]]

--- Release a frame back to its pool
-- @param frame Frame - The frame to release
-- @return boolean - True if released
function LoolibFrameFactoryMixin:Release(frame)
    return self.poolCollection:Release(frame)
end

--- Release all frames
function LoolibFrameFactoryMixin:ReleaseAll()
    self.poolCollection:ReleaseAll()
end

--[[--------------------------------------------------------------------
    Pool Management
----------------------------------------------------------------------]]

--- Get or create a specific pool
-- @param frameType string - Frame type
-- @param parent Frame - Parent frame
-- @param template string - Template name
-- @param resetFunc function - Reset function
-- @return table, boolean - Pool, isNew
function LoolibFrameFactoryMixin:GetOrCreatePool(frameType, parent, template, resetFunc)
    return self.poolCollection:GetOrCreatePool(frameType, parent, template, resetFunc)
end

--- Get the pool collection
-- @return table
function LoolibFrameFactoryMixin:GetPoolCollection()
    return self.poolCollection
end

--- Get the template info cache
-- @return table
function LoolibFrameFactoryMixin:GetTemplateInfoCache()
    return self.templateInfoCache
end

--[[--------------------------------------------------------------------
    Statistics
----------------------------------------------------------------------]]

--- Get the number of active frames
-- @return number
function LoolibFrameFactoryMixin:GetNumActive()
    return self.poolCollection:GetNumActive()
end

--- Get the number of pools
-- @return number
function LoolibFrameFactoryMixin:GetNumPools()
    return self.poolCollection:GetNumPools()
end

--- Dump statistics
function LoolibFrameFactoryMixin:Dump()
    print("Frame Factory Statistics:")
    self.poolCollection:Dump()
end

--[[--------------------------------------------------------------------
    Iteration
----------------------------------------------------------------------]]

--- Iterate over all active frames
-- @return iterator
function LoolibFrameFactoryMixin:EnumerateActive()
    return self.poolCollection:EnumerateActive()
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new frame factory
-- @return table - A new FrameFactory instance
function CreateLoolibFrameFactory()
    local factory = LoolibCreateFromMixins(LoolibFrameFactoryMixin)
    factory:Init()
    return factory
end

--[[--------------------------------------------------------------------
    Global Default Factory

    A shared factory instance for general use.
----------------------------------------------------------------------]]

LoolibFrameFactory = CreateLoolibFrameFactory()

--[[--------------------------------------------------------------------
    Convenience Functions

    Top-level functions that use the default factory.
----------------------------------------------------------------------]]

--- Create a frame using the default factory
-- @param parent Frame - Parent frame
-- @param frameTemplateOrType string - Template or frame type
-- @param resetFunc function - Optional reset function
-- @return Frame, boolean, table
function LoolibCreateFrame(parent, frameTemplateOrType, resetFunc)
    return LoolibFrameFactory:Create(parent, frameTemplateOrType, resetFunc)
end

--- Create a frame with mixins using the default factory
-- @param parent Frame - Parent frame
-- @param frameTemplateOrType string - Template or frame type
-- @param resetFunc function - Optional reset function
-- @param ... - Mixins to apply
-- @return Frame, boolean
function LoolibCreateFrameWithMixins(parent, frameTemplateOrType, resetFunc, ...)
    return LoolibFrameFactory:CreateWithMixins(parent, frameTemplateOrType, resetFunc, ...)
end

--- Release a frame to the default factory
-- @param frame Frame - The frame to release
-- @return boolean
function LoolibReleaseFrame(frame)
    return LoolibFrameFactory:Release(frame)
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local FrameFactoryModule = {
    -- Mixins
    FactoryMixin = LoolibFrameFactoryMixin,
    TemplateInfoCacheMixin = LoolibTemplateInfoCacheMixin,

    -- Factory functions
    Create = CreateLoolibFrameFactory,
    CreateTemplateInfoCache = CreateLoolibTemplateInfoCache,

    -- Default factory
    Default = LoolibFrameFactory,

    -- Convenience functions
    CreateFrame = LoolibCreateFrame,
    CreateFrameWithMixins = LoolibCreateFrameWithMixins,
    ReleaseFrame = LoolibReleaseFrame,
}

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.FrameFactory = FrameFactoryModule
UI.CreateFrame = LoolibCreateFrame
UI.CreateFrameWithMixins = LoolibCreateFrameWithMixins
UI.ReleaseFrame = LoolibReleaseFrame

Loolib:RegisterModule("FrameFactory", FrameFactoryModule)
