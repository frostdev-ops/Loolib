--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    FramePool - Specialized object pools for WoW frames and regions

    Provides convenient factory functions for creating pools of
    frames, textures, and font strings.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateObjectPool = assert(Loolib.CreateObjectPool, "Loolib.CreateObjectPool is required for FramePool")
local GetResetterForFrameType = assert(Loolib.GetResetterForFrameType, "Loolib.GetResetterForFrameType is required for FramePool")
local ResetTexture = assert(Loolib.PoolReset_Texture, "Loolib.PoolReset_Texture is required for FramePool")
local ResetFontString = assert(Loolib.PoolReset_FontString, "Loolib.PoolReset_FontString is required for FramePool")
local Mixin = assert(Loolib.Mixin, "Loolib.Mixin is required for FramePool")
local ReflectScriptHandlers = assert(Loolib.ReflectScriptHandlers, "Loolib.ReflectScriptHandlers is required for FramePool")
local Pool = Loolib.Pool or Loolib:GetOrCreateModule("Pool")
local FramePoolModule = Pool.FramePool or Loolib:GetModule("Pool.FramePool") or {}

-- Cache globals
local error = error
local type = type
local unpack = unpack

-- Cache WoW globals
local CreateFrame = CreateFrame

--[[--------------------------------------------------------------------
    Frame Pool
----------------------------------------------------------------------]]

--- Create a pool for frames
-- @param frameType string - The frame type (e.g., "Frame", "Button")
-- @param parent Frame - The parent frame for created frames
-- @param template string - Optional XML template name
-- @param resetFunc function - Optional reset function
-- @param capacity number - Optional maximum capacity
-- @return table - A new FramePool instance
local function CreateFramePool(frameType, parent, template, resetFunc, capacity)
    frameType = frameType or "Frame"

    if type(frameType) ~= "string" then
        error("LoolibFramePool: CreateFramePool frameType must be a string", 2)
    end
    if resetFunc ~= nil and type(resetFunc) ~= "function" then
        error("LoolibFramePool: CreateFramePool resetFunc must be a function or nil", 2)
    end

    -- Default reset function based on frame type
    if not resetFunc then
        resetFunc = GetResetterForFrameType(frameType)
    end

    -- Create function -- INTERNAL
    local createFunc = function(pool)
        local frame = CreateFrame(frameType, nil, parent, template)
        return frame
    end

    -- Create and return the pool
    local pool = CreateObjectPool(createFunc, resetFunc, capacity)

    -- Store metadata
    pool.frameType = frameType
    pool.parent = parent
    pool.template = template

    return pool
end

--- Create a pool for frames with automatic mixin application
-- @param frameType string - The frame type
-- @param parent Frame - The parent frame
-- @param template string - Optional XML template name
-- @param resetFunc function - Optional reset function
-- @param mixins table - Mixins to apply to each frame
-- @param capacity number - Optional maximum capacity
-- @return table - A new FramePool instance
local function CreateFramePoolWithMixins(frameType, parent, template, resetFunc, mixins, capacity)
    frameType = frameType or "Frame"

    if type(frameType) ~= "string" then
        error("LoolibFramePool: CreateFramePoolWithMixins frameType must be a string", 2)
    end
    if resetFunc ~= nil and type(resetFunc) ~= "function" then
        error("LoolibFramePool: CreateFramePoolWithMixins resetFunc must be a function or nil", 2)
    end

    -- Default reset function
    if not resetFunc then
        resetFunc = GetResetterForFrameType(frameType)
    end

    -- Create function with mixin application -- INTERNAL
    local createFunc = function(pool)
        local frame = CreateFrame(frameType, nil, parent, template)

        if mixins then
            if type(mixins) == "table" and mixins[1] then
                -- Array of mixins
                Mixin(frame, unpack(mixins))
            else
                -- Single mixin
                Mixin(frame, mixins)
            end

            -- Reflect script handlers from mixins
            ReflectScriptHandlers(frame)

            -- Call Init if available
            if frame.Init then
                frame:Init()
            end
        end

        return frame
    end

    local pool = CreateObjectPool(createFunc, resetFunc, capacity)

    -- Store metadata
    pool.frameType = frameType
    pool.parent = parent
    pool.template = template
    pool.mixins = mixins

    return pool
end

--[[--------------------------------------------------------------------
    Texture Pool
----------------------------------------------------------------------]]

--- Create a pool for textures
-- @param parent Frame - The parent frame
-- @param layer string - The draw layer (e.g., "ARTWORK", "BACKGROUND")
-- @param subLayer number - Optional sub-layer
-- @param template string - Optional XML template name
-- @param resetFunc function - Optional reset function
-- @param capacity number - Optional maximum capacity
-- @return table - A new TexturePool instance
local function CreateTexturePool(parent, layer, subLayer, template, resetFunc, capacity)
    if parent == nil then
        error("LoolibFramePool: CreateTexturePool requires a parent frame", 2)
    end
    if resetFunc ~= nil and type(resetFunc) ~= "function" then
        error("LoolibFramePool: CreateTexturePool resetFunc must be a function or nil", 2)
    end

    layer = layer or "ARTWORK"
    subLayer = subLayer or 0

    -- Default reset function
    if not resetFunc then
        resetFunc = ResetTexture
    end

    -- Create function -- INTERNAL
    local createFunc = function(pool)
        local texture = parent:CreateTexture(nil, layer, template, subLayer)
        return texture
    end

    local pool = CreateObjectPool(createFunc, resetFunc, capacity)

    -- Store metadata
    pool.parent = parent
    pool.layer = layer
    pool.subLayer = subLayer
    pool.template = template

    return pool
end

--[[--------------------------------------------------------------------
    FontString Pool
----------------------------------------------------------------------]]

--- Create a pool for font strings
-- @param parent Frame - The parent frame
-- @param layer string - The draw layer
-- @param subLayer number - Optional sub-layer
-- @param template string - Optional font template name
-- @param resetFunc function - Optional reset function
-- @param capacity number - Optional maximum capacity
-- @return table - A new FontStringPool instance
local function CreateFontStringPool(parent, layer, subLayer, template, resetFunc, capacity)
    if parent == nil then
        error("LoolibFramePool: CreateFontStringPool requires a parent frame", 2)
    end
    if resetFunc ~= nil and type(resetFunc) ~= "function" then
        error("LoolibFramePool: CreateFontStringPool resetFunc must be a function or nil", 2)
    end

    layer = layer or "OVERLAY"
    subLayer = subLayer or 0

    -- Default reset function
    if not resetFunc then
        resetFunc = ResetFontString
    end

    -- Create function -- INTERNAL
    local createFunc = function(pool)
        local fontString = parent:CreateFontString(nil, layer, template, subLayer)
        return fontString
    end

    local pool = CreateObjectPool(createFunc, resetFunc, capacity)

    -- Store metadata
    pool.parent = parent
    pool.layer = layer
    pool.subLayer = subLayer
    pool.template = template

    return pool
end

--[[--------------------------------------------------------------------
    Line Pool
----------------------------------------------------------------------]]

--- Create a pool for lines (Line regions)
-- @param parent Frame - The parent frame
-- @param layer string - The draw layer
-- @param subLayer number - Optional sub-layer
-- @param template string - Optional XML template name
-- @param resetFunc function - Optional reset function
-- @param capacity number - Optional maximum capacity
-- @return table - A new LinePool instance
local function CreateLinePool(parent, layer, subLayer, template, resetFunc, capacity)
    if parent == nil then
        error("LoolibFramePool: CreateLinePool requires a parent frame", 2)
    end
    if resetFunc ~= nil and type(resetFunc) ~= "function" then
        error("LoolibFramePool: CreateLinePool resetFunc must be a function or nil", 2)
    end

    layer = layer or "ARTWORK"
    subLayer = subLayer or 0

    -- Default reset function -- INTERNAL
    if not resetFunc then
        resetFunc = function(pool, line)
            line:Hide()
            line:ClearAllPoints()
            line:SetColorTexture(1, 1, 1, 1)
            line:SetThickness(1)
        end
    end

    -- Create function -- INTERNAL
    local createFunc = function(pool)
        local line = parent:CreateLine(nil, layer, template, subLayer)
        return line
    end

    local pool = CreateObjectPool(createFunc, resetFunc, capacity)

    -- Store metadata
    pool.parent = parent
    pool.layer = layer
    pool.subLayer = subLayer
    pool.template = template

    return pool
end

--[[--------------------------------------------------------------------
    Actor Pool (for ModelScene frames)
----------------------------------------------------------------------]]

--- Create a pool for actors in a model scene
-- @param modelScene ModelScene - The model scene frame
-- @param resetFunc function - Optional reset function
-- @param capacity number - Optional maximum capacity
-- @return table - A new ActorPool instance
local function CreateActorPool(modelScene, resetFunc, capacity)
    if modelScene == nil then
        error("LoolibFramePool: CreateActorPool requires a modelScene", 2)
    end
    if resetFunc ~= nil and type(resetFunc) ~= "function" then
        error("LoolibFramePool: CreateActorPool resetFunc must be a function or nil", 2)
    end

    -- Default reset function -- INTERNAL
    if not resetFunc then
        resetFunc = function(pool, actor)
            actor:ClearModel()
            actor:Hide()
        end
    end

    -- Create function -- INTERNAL
    local createFunc = function(pool)
        return modelScene:CreateActor()
    end

    local pool = CreateObjectPool(createFunc, resetFunc, capacity)

    -- Store metadata
    pool.modelScene = modelScene

    return pool
end

--[[--------------------------------------------------------------------
    Utility: Acquire with Initialization
----------------------------------------------------------------------]]

--- Acquire a frame and run an initializer on first creation
-- @param pool table - The frame pool
-- @param initializer function - Called with (frame) on first acquire
-- @return Frame, boolean - The frame and whether it was newly created
local function AcquireFrame(pool, initializer)
    if pool == nil then
        error("LoolibFramePool: AcquireFrame requires a pool", 2)
    end

    local frame, isNew = pool:Acquire()

    if isNew and initializer then
        initializer(frame)
    end

    return frame, isNew
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

FramePoolModule.CreateFramePool = CreateFramePool
FramePoolModule.CreateFramePoolWithMixins = CreateFramePoolWithMixins
FramePoolModule.CreateTexturePool = CreateTexturePool
FramePoolModule.CreateFontStringPool = CreateFontStringPool
FramePoolModule.CreateLinePool = CreateLinePool
FramePoolModule.CreateActorPool = CreateActorPool
FramePoolModule.AcquireFrame = AcquireFrame

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.CreateFramePool = CreateFramePool
UI.CreateFramePoolWithMixins = CreateFramePoolWithMixins
UI.CreateTexturePool = CreateTexturePool
UI.CreateFontStringPool = CreateFontStringPool
UI.CreateLinePool = CreateLinePool
UI.CreateActorPool = CreateActorPool

Pool.FramePool = FramePoolModule
Loolib.CreateFramePool = CreateFramePool
Loolib.CreateFramePoolWithMixins = CreateFramePoolWithMixins
Loolib.CreateTexturePool = CreateTexturePool
Loolib.CreateFontStringPool = CreateFontStringPool
Loolib.CreateLinePool = CreateLinePool
Loolib.CreateActorPool = CreateActorPool
Loolib.AcquireFrame = AcquireFrame

Loolib:RegisterModule("Pool.FramePool", FramePoolModule)
