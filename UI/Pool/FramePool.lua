--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    FramePool - Specialized object pools for WoW frames and regions

    Provides convenient factory functions for creating pools of
    frames, textures, and font strings.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

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
function CreateLoolibFramePool(frameType, parent, template, resetFunc, capacity)
    frameType = frameType or "Frame"

    -- Default reset function based on frame type
    if not resetFunc then
        resetFunc = LoolibGetResetterForFrameType(frameType)
    end

    -- Create function
    local createFunc = function(pool)
        local frame = CreateFrame(frameType, nil, parent, template)
        return frame
    end

    -- Create and return the pool
    local pool = CreateLoolibObjectPool(createFunc, resetFunc, capacity)

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
function CreateLoolibFramePoolWithMixins(frameType, parent, template, resetFunc, mixins, capacity)
    frameType = frameType or "Frame"

    -- Default reset function
    if not resetFunc then
        resetFunc = LoolibGetResetterForFrameType(frameType)
    end

    -- Create function with mixin application
    local createFunc = function(pool)
        local frame = CreateFrame(frameType, nil, parent, template)

        if mixins then
            if type(mixins) == "table" and mixins[1] then
                -- Array of mixins
                LoolibMixin(frame, unpack(mixins))
            else
                -- Single mixin
                LoolibMixin(frame, mixins)
            end

            -- Reflect script handlers from mixins
            LoolibReflectScriptHandlers(frame)

            -- Call Init if available
            if frame.Init then
                frame:Init()
            end
        end

        return frame
    end

    local pool = CreateLoolibObjectPool(createFunc, resetFunc, capacity)

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
function CreateLoolibTexturePool(parent, layer, subLayer, template, resetFunc, capacity)
    layer = layer or "ARTWORK"
    subLayer = subLayer or 0

    -- Default reset function
    if not resetFunc then
        resetFunc = LoolibPoolReset_Texture
    end

    -- Create function
    local createFunc = function(pool)
        local texture = parent:CreateTexture(nil, layer, template, subLayer)
        return texture
    end

    local pool = CreateLoolibObjectPool(createFunc, resetFunc, capacity)

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
function CreateLoolibFontStringPool(parent, layer, subLayer, template, resetFunc, capacity)
    layer = layer or "OVERLAY"
    subLayer = subLayer or 0

    -- Default reset function
    if not resetFunc then
        resetFunc = LoolibPoolReset_FontString
    end

    -- Create function
    local createFunc = function(pool)
        local fontString = parent:CreateFontString(nil, layer, template, subLayer)
        return fontString
    end

    local pool = CreateLoolibObjectPool(createFunc, resetFunc, capacity)

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
function CreateLoolibLinePool(parent, layer, subLayer, template, resetFunc, capacity)
    layer = layer or "ARTWORK"
    subLayer = subLayer or 0

    -- Default reset function
    if not resetFunc then
        resetFunc = function(pool, line)
            line:Hide()
            line:ClearAllPoints()
            line:SetColorTexture(1, 1, 1, 1)
            line:SetThickness(1)
        end
    end

    -- Create function
    local createFunc = function(pool)
        local line = parent:CreateLine(nil, layer, template, subLayer)
        return line
    end

    local pool = CreateLoolibObjectPool(createFunc, resetFunc, capacity)

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
function CreateLoolibActorPool(modelScene, resetFunc, capacity)
    -- Default reset function
    if not resetFunc then
        resetFunc = function(pool, actor)
            actor:ClearModel()
            actor:Hide()
        end
    end

    -- Create function
    local createFunc = function(pool)
        return modelScene:CreateActor()
    end

    local pool = CreateLoolibObjectPool(createFunc, resetFunc, capacity)

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
function LoolibAcquireFrame(pool, initializer)
    local frame, isNew = pool:Acquire()

    if isNew and initializer then
        initializer(frame)
    end

    return frame, isNew
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local FramePoolModule = {
    CreateFramePool = CreateLoolibFramePool,
    CreateFramePoolWithMixins = CreateLoolibFramePoolWithMixins,
    CreateTexturePool = CreateLoolibTexturePool,
    CreateFontStringPool = CreateLoolibFontStringPool,
    CreateLinePool = CreateLoolibLinePool,
    CreateActorPool = CreateLoolibActorPool,
    AcquireFrame = LoolibAcquireFrame,
}

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.CreateFramePool = CreateLoolibFramePool
UI.CreateFramePoolWithMixins = CreateLoolibFramePoolWithMixins
UI.CreateTexturePool = CreateLoolibTexturePool
UI.CreateFontStringPool = CreateLoolibFontStringPool
UI.CreateLinePool = CreateLoolibLinePool
UI.CreateActorPool = CreateLoolibActorPool

Loolib:RegisterModule("FramePool", FramePoolModule)
