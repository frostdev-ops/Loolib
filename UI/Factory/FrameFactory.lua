--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    FrameFactory - Universal frame creation with template caching

    Based on Blizzard's FrameFactoryMixin pattern. Provides unified
    frame creation with automatic pooling, mixin application, and
    template detection.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for FrameFactory")
local CreatePoolCollection = assert(Loolib.CreatePoolCollection, "Loolib.CreatePoolCollection is required for FrameFactory")
local ResetFrame = assert(Loolib.PoolReset_Frame, "Loolib.PoolReset_Frame is required for FrameFactory")
local Mixin = assert(Loolib.Mixin, "Loolib.Mixin is required for FrameFactory")
local ReflectScriptHandlers = assert(Loolib.ReflectScriptHandlers, "Loolib.ReflectScriptHandlers is required for FrameFactory")
local Factory = Loolib.Factory or Loolib:GetOrCreateModule("Factory")
local FrameFactoryModule = Factory.FrameFactory or Loolib:GetModule("Factory.FrameFactory") or {}

-- Cache globals
local error = error
local pcall = pcall
local print = print
local select = select
local type = type
local wipe = wipe

--[[--------------------------------------------------------------------
    Template Info Cache

    Caches information about XML templates to avoid repeated lookups.
----------------------------------------------------------------------]]

local TemplateInfoCacheMixin = FrameFactoryModule.TemplateInfoCacheMixin or {}

function TemplateInfoCacheMixin:Init()
    self.cache = {}
end

--- Get information about a template
-- @param templateName string - The template name
-- @return table|nil - Template info or nil if not a template
function TemplateInfoCacheMixin:GetTemplateInfo(templateName)
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

-- Known WoW frame types (hoisted to avoid table recreation per call) -- INTERNAL
local KNOWN_FRAME_TYPES = {
    Frame = true, Button = true, CheckButton = true, EditBox = true,
    ScrollFrame = true, Slider = true, StatusBar = true, Cooldown = true,
    ColorSelect = true, GameTooltip = true, MessageFrame = true,
    Model = true, PlayerModel = true, DressUpModel = true,
    MovieFrame = true, SimpleHTML = true, Browser = true,
    ModelScene = true, OffScreenFrame = true,
}

--- Check if a string is a known frame type (not a template)
-- @param name string - The name to check
-- @return boolean
function TemplateInfoCacheMixin:IsFrameType(name)
    return KNOWN_FRAME_TYPES[name] == true
end

--- Clear the cache
function TemplateInfoCacheMixin:Clear()
    wipe(self.cache)
end

--- Create a new template info cache -- INTERNAL
local function CreateTemplateInfoCache()
    local cache = CreateFromMixins(TemplateInfoCacheMixin)
    cache:Init()
    return cache
end

--[[--------------------------------------------------------------------
    LoolibFrameFactoryMixin

    A mixin that provides universal frame creation with pooling.
----------------------------------------------------------------------]]

local FrameFactoryMixin = FrameFactoryModule.FactoryMixin or {}

function FrameFactoryMixin:Init()
    self.templateInfoCache = CreateTemplateInfoCache()
    self.poolCollection = CreatePoolCollection()
end

--[[--------------------------------------------------------------------
    Frame Creation
----------------------------------------------------------------------]]

--- Create a frame (or acquire from pool)
-- @param parent Frame - Parent frame
-- @param frameTemplateOrType string - Template name or frame type
-- @param resetFunc function - Optional reset function
-- @return Frame, boolean, table - Frame, isNew, templateInfo
function FrameFactoryMixin:Create(parent, frameTemplateOrType, resetFunc)
    if type(frameTemplateOrType) ~= "string" or frameTemplateOrType == "" then
        error("LoolibFactory: Create: frameTemplateOrType must be a non-empty string", 2)
    end
    if resetFunc ~= nil and type(resetFunc) ~= "function" then
        error("LoolibFactory: Create: resetFunc must be a function or nil", 2)
    end

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
        resetFunc or ResetFrame
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
function FrameFactoryMixin:CreateWithMixins(parent, frameTemplateOrType, resetFunc, ...)
    -- Validate that at least one mixin was provided
    if select("#", ...) == 0 then
        error("LoolibFactory: CreateWithMixins: at least one mixin table must be provided", 2)
    end

    local frame, isNew, info = self:Create(parent, frameTemplateOrType, resetFunc)

    if isNew then
        local mixinCount = select("#", ...)
        if mixinCount > 0 then
            Mixin(frame, ...)
            ReflectScriptHandlers(frame)

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
function FrameFactoryMixin:Release(frame)
    if frame == nil then
        error("LoolibFactory: Release: frame must not be nil", 2)
    end
    return self.poolCollection:Release(frame)
end

--- Release all frames
function FrameFactoryMixin:ReleaseAll()
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
function FrameFactoryMixin:GetOrCreatePool(frameType, parent, template, resetFunc)
    if type(frameType) ~= "string" or frameType == "" then
        error("LoolibFactory: GetOrCreatePool: frameType must be a non-empty string", 2)
    end
    if resetFunc ~= nil and type(resetFunc) ~= "function" then
        error("LoolibFactory: GetOrCreatePool: resetFunc must be a function or nil", 2)
    end
    return self.poolCollection:GetOrCreatePool(frameType, parent, template, resetFunc)
end

--- Get the pool collection
-- @return table
function FrameFactoryMixin:GetPoolCollection()
    return self.poolCollection
end

--- Get the template info cache
-- @return table
function FrameFactoryMixin:GetTemplateInfoCache()
    return self.templateInfoCache
end

--[[--------------------------------------------------------------------
    Statistics
----------------------------------------------------------------------]]

--- Get the number of active frames
-- @return number
function FrameFactoryMixin:GetNumActive()
    return self.poolCollection:GetNumActive()
end

--- Get the number of pools
-- @return number
function FrameFactoryMixin:GetNumPools()
    return self.poolCollection:GetNumPools()
end

--- Dump statistics
function FrameFactoryMixin:Dump()
    print("Frame Factory Statistics:")
    self.poolCollection:Dump()
end

--[[--------------------------------------------------------------------
    Iteration
----------------------------------------------------------------------]]

--- Iterate over all active frames
-- @return iterator
function FrameFactoryMixin:EnumerateActive()
    return self.poolCollection:EnumerateActive()
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new frame factory
-- @return table - A new FrameFactory instance
local function CreateFrameFactory()
    local factory = CreateFromMixins(FrameFactoryMixin)
    factory:Init()
    return factory
end

--[[--------------------------------------------------------------------
    Global Default Factory

    A shared factory instance for general use.
----------------------------------------------------------------------]]

local DefaultFrameFactory = FrameFactoryModule.Default or CreateFrameFactory()

--[[--------------------------------------------------------------------
    Convenience Functions

    Top-level functions that use the default factory.
----------------------------------------------------------------------]]

--- Create a frame using the default factory
-- @param parent Frame - Parent frame
-- @param frameTemplateOrType string - Template or frame type
-- @param resetFunc function - Optional reset function
-- @return Frame, boolean, table
local function CreateFrame(parent, frameTemplateOrType, resetFunc)
    return DefaultFrameFactory:Create(parent, frameTemplateOrType, resetFunc)
end

--- Create a frame with mixins using the default factory
-- @param parent Frame - Parent frame
-- @param frameTemplateOrType string - Template or frame type
-- @param resetFunc function - Optional reset function
-- @param ... - Mixins to apply
-- @return Frame, boolean
local function CreateFrameWithMixins(parent, frameTemplateOrType, resetFunc, ...)
    return DefaultFrameFactory:CreateWithMixins(parent, frameTemplateOrType, resetFunc, ...)
end

--- Release a frame to the default factory
-- @param frame Frame - The frame to release
-- @return boolean
local function ReleaseFrame(frame)
    return DefaultFrameFactory:Release(frame)
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

FrameFactoryModule.FactoryMixin = FrameFactoryMixin
FrameFactoryModule.TemplateInfoCacheMixin = TemplateInfoCacheMixin
FrameFactoryModule.Create = CreateFrameFactory
FrameFactoryModule.CreateTemplateInfoCache = CreateTemplateInfoCache
FrameFactoryModule.Default = DefaultFrameFactory
FrameFactoryModule.CreateFrame = CreateFrame
FrameFactoryModule.CreateFrameWithMixins = CreateFrameWithMixins
FrameFactoryModule.ReleaseFrame = ReleaseFrame

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.FrameFactory = FrameFactoryModule
UI.CreateFrame = CreateFrame
UI.CreateFrameWithMixins = CreateFrameWithMixins
UI.ReleaseFrame = ReleaseFrame

Factory.FrameFactory = FrameFactoryModule
Loolib.FrameFactory = DefaultFrameFactory
Loolib.CreateFrame = CreateFrame
Loolib.CreateFrameWithMixins = CreateFrameWithMixins
Loolib.ReleaseFrame = ReleaseFrame
Loolib.CreateTemplateInfoCache = CreateTemplateInfoCache

Loolib:RegisterModule("Factory.FrameFactory", FrameFactoryModule)
