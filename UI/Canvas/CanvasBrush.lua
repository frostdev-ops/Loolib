--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    CanvasBrush - Freehand drawing system for canvas elements

    Provides brush stroke management with dot interpolation for smooth
    lines. Stores dot data in parallel arrays for performance (MRT pattern).
    Supports grouping, serialization, and network sync.

    Dependencies (must be loaded before this file):
    - Core/Loolib.lua (Loolib namespace)
    - Core/Mixin.lua (LoolibMixin, LoolibCreateFromMixins)
    - Events/CallbackRegistry.lua (LoolibCallbackRegistryMixin)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Verify dependencies are loaded
assert(LoolibMixin, "Loolib/Core/Mixin.lua must be loaded before CanvasBrush")
assert(LoolibCallbackRegistryMixin, "Loolib/Events/CallbackRegistry.lua must be loaded before CanvasBrush")

-- Local math references for performance
local sqrt = math.sqrt
local floor = math.floor
local max = math.max
local min = math.min

--[[--------------------------------------------------------------------
    Event Names
----------------------------------------------------------------------]]

local BRUSH_EVENTS = {
    "OnDotAdded",       -- Fired when a single dot is added
    "OnStrokeEnd",      -- Fired when a stroke is complete
    "OnDotsCleared",    -- Fired when all dots are cleared
}

--[[--------------------------------------------------------------------
    LoolibCanvasBrushMixin

    A mixin that provides freehand brush drawing functionality.
    Uses parallel arrays for dot storage (MRT VisNote pattern).
----------------------------------------------------------------------]]

LoolibCanvasBrushMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

--- Initialize the brush system
function LoolibCanvasBrushMixin:OnLoad()
    -- Initialize callback system
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(BRUSH_EVENTS)

    -- Brush settings
    self._brushSize = 6      -- Default brush size (pixels)
    self._brushColor = 4     -- Default color index (red in MRT)

    -- Stroke state
    self._isDrawing = false  -- Whether a stroke is in progress
    self._lastX = nil        -- Last X coordinate for interpolation
    self._lastY = nil        -- Last Y coordinate for interpolation
    self._currentGroup = 0   -- Current group ID for new dots

    -- Dot storage (parallel arrays for performance)
    -- This pattern is copied from MRT VisNote for compatibility
    self._dots = {}          -- Frame references (when rendered)
    self._dots_X = {}        -- X positions
    self._dots_Y = {}        -- Y positions
    self._dots_SIZE = {}     -- Sizes
    self._dots_COLOR = {}    -- Color indices
    self._dots_GROUP = {}    -- Group IDs
    self._dots_SYNC = {}     -- Sync IDs for network

    self._nextSyncId = 1     -- Next sync ID to assign
end

--[[--------------------------------------------------------------------
    Brush Settings
----------------------------------------------------------------------]]

--- Set the brush size
-- @param size number - Brush size in pixels (clamped to 2-20)
-- @return self - For method chaining
function LoolibCanvasBrushMixin:SetBrushSize(size)
    self._brushSize = max(2, min(20, size))
    return self
end

--- Get the current brush size
-- @return number - Current brush size
function LoolibCanvasBrushMixin:GetBrushSize()
    return self._brushSize
end

--- Set the brush color
-- @param colorIndex number - Color index to use
-- @return self - For method chaining
function LoolibCanvasBrushMixin:SetBrushColor(colorIndex)
    self._brushColor = colorIndex
    return self
end

--- Get the current brush color
-- @return number - Current color index
function LoolibCanvasBrushMixin:GetBrushColor()
    return self._brushColor
end

--- Set the current group ID for new dots
-- @param groupId number|nil - Group ID (nil or 0 for no group)
-- @return self - For method chaining
function LoolibCanvasBrushMixin:SetCurrentGroup(groupId)
    self._currentGroup = groupId or 0
    return self
end

--- Get the current group ID
-- @return number - Current group ID
function LoolibCanvasBrushMixin:GetCurrentGroup()
    return self._currentGroup
end

--[[--------------------------------------------------------------------
    Stroke Operations
----------------------------------------------------------------------]]

--- Start a new brush stroke
-- @param x number - Starting X coordinate
-- @param y number - Starting Y coordinate
-- @return self - For method chaining
function LoolibCanvasBrushMixin:StartStroke(x, y)
    self._isDrawing = true
    self._lastX = x
    self._lastY = y
    self:_AddDot(x, y)
    return self
end

--- Continue the current stroke to a new position
-- Interpolates dots between the last position and the current position
-- @param x number - Current X coordinate
-- @param y number - Current Y coordinate
-- @return self - For method chaining
function LoolibCanvasBrushMixin:ContinueStroke(x, y)
    if not self._isDrawing then return self end

    -- Interpolate between last point and current point for smooth lines
    self:_InterpolateDots(self._lastX, self._lastY, x, y)
    self._lastX = x
    self._lastY = y

    return self
end

--- End the current stroke
-- @return self - For method chaining
function LoolibCanvasBrushMixin:EndStroke()
    self._isDrawing = false
    self._lastX = nil
    self._lastY = nil

    -- Trigger callback if registered
    self:TriggerEvent(self.Event.OnStrokeEnd)

    return self
end

--- Check if a stroke is currently in progress
-- @return boolean - True if drawing
function LoolibCanvasBrushMixin:IsDrawing()
    return self._isDrawing
end

--[[--------------------------------------------------------------------
    Dot Management (Internal)
----------------------------------------------------------------------]]

--- Add a single dot to the canvas
-- @param x number - X coordinate
-- @param y number - Y coordinate
-- @param size number|nil - Dot size (uses current brush size if nil)
-- @param color number|nil - Color index (uses current color if nil)
-- @param group number|nil - Group ID (uses current group if nil)
-- @return number - Index of the added dot
function LoolibCanvasBrushMixin:_AddDot(x, y, size, color, group)
    local index = #self._dots_X + 1

    self._dots_X[index] = x
    self._dots_Y[index] = y
    self._dots_SIZE[index] = size or self._brushSize
    self._dots_COLOR[index] = color or self._brushColor
    self._dots_GROUP[index] = group or self._currentGroup
    self._dots_SYNC[index] = self._nextSyncId
    self._nextSyncId = self._nextSyncId + 1

    -- Trigger callback
    self:TriggerEvent(self.Event.OnDotAdded, index)

    return index
end

--- Interpolate dots between two points for smooth strokes
-- This is the core algorithm from MRT VisNote for smooth line drawing
-- @param x1 number - Start X coordinate
-- @param y1 number - Start Y coordinate
-- @param x2 number - End X coordinate
-- @param y2 number - End Y coordinate
function LoolibCanvasBrushMixin:_InterpolateDots(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dist = sqrt(dx * dx + dy * dy)

    -- Step size based on brush size (smaller = smoother, more dots)
    -- MRT uses 0.5, we use 0.4 for slightly smoother results
    local stepSize = self._brushSize * 0.4
    local steps = max(1, floor(dist / stepSize))

    -- Add interpolated dots
    for i = 1, steps do
        local t = i / steps
        local px = x1 + dx * t
        local py = y1 + dy * t
        self:_AddDot(px, py)
    end
end

--[[--------------------------------------------------------------------
    Batch Dot Operations
----------------------------------------------------------------------]]

--- Add multiple dots at once (for loading/sync)
-- @param dotsData table - Array of dot tables with x, y, size, color, group
-- @return self - For method chaining
function LoolibCanvasBrushMixin:AddDots(dotsData)
    for _, dot in ipairs(dotsData) do
        self:_AddDot(dot.x, dot.y, dot.size, dot.color, dot.group)
    end
    return self
end

--- Get dot data at a specific index
-- @param index number - Dot index
-- @return table|nil - Dot data table or nil if index invalid
function LoolibCanvasBrushMixin:GetDot(index)
    if not self._dots_X[index] then return nil end

    return {
        x = self._dots_X[index],
        y = self._dots_Y[index],
        size = self._dots_SIZE[index],
        color = self._dots_COLOR[index],
        group = self._dots_GROUP[index],
        syncId = self._dots_SYNC[index],
    }
end

--- Get all dots as an array
-- @return table - Array of dot data tables
function LoolibCanvasBrushMixin:GetAllDots()
    local result = {}
    for i = 1, #self._dots_X do
        result[i] = self:GetDot(i)
    end
    return result
end

--- Get the total number of dots
-- @return number - Dot count
function LoolibCanvasBrushMixin:GetDotCount()
    return #self._dots_X
end

--- Clear all dots
-- @return self - For method chaining
function LoolibCanvasBrushMixin:ClearDots()
    self._dots = {}
    self._dots_X = {}
    self._dots_Y = {}
    self._dots_SIZE = {}
    self._dots_COLOR = {}
    self._dots_GROUP = {}
    self._dots_SYNC = {}

    self:TriggerEvent(self.Event.OnDotsCleared)

    return self
end

--[[--------------------------------------------------------------------
    Group Operations
----------------------------------------------------------------------]]

--- Delete all dots belonging to a specific group
-- @param groupId number - Group ID to delete
-- @return self - For method chaining
function LoolibCanvasBrushMixin:DeleteDotsByGroup(groupId)
    local newX, newY, newSize, newColor, newGroup, newSync = {}, {}, {}, {}, {}, {}

    -- Rebuild arrays excluding the specified group
    for i = 1, #self._dots_X do
        if self._dots_GROUP[i] ~= groupId then
            local n = #newX + 1
            newX[n] = self._dots_X[i]
            newY[n] = self._dots_Y[i]
            newSize[n] = self._dots_SIZE[i]
            newColor[n] = self._dots_COLOR[i]
            newGroup[n] = self._dots_GROUP[i]
            newSync[n] = self._dots_SYNC[i]
        end
    end

    self._dots_X = newX
    self._dots_Y = newY
    self._dots_SIZE = newSize
    self._dots_COLOR = newColor
    self._dots_GROUP = newGroup
    self._dots_SYNC = newSync

    return self
end

--- Move all dots in a group by a delta
-- @param groupId number - Group ID to move
-- @param deltaX number - X offset to apply
-- @param deltaY number - Y offset to apply
-- @return self - For method chaining
function LoolibCanvasBrushMixin:MoveDotsByGroup(groupId, deltaX, deltaY)
    for i = 1, #self._dots_X do
        if self._dots_GROUP[i] == groupId then
            self._dots_X[i] = self._dots_X[i] + deltaX
            self._dots_Y[i] = self._dots_Y[i] + deltaY
        end
    end
    return self
end

--- Get all dots belonging to a specific group
-- @param groupId number - Group ID to query
-- @return table - Array of dot data tables
function LoolibCanvasBrushMixin:GetDotsByGroup(groupId)
    local result = {}
    for i = 1, #self._dots_X do
        if self._dots_GROUP[i] == groupId then
            result[#result + 1] = self:GetDot(i)
        end
    end
    return result
end

--[[--------------------------------------------------------------------
    Serialization
----------------------------------------------------------------------]]

--- Serialize all dots to a compact format
-- Uses short keys (x, y, s, c, g) to minimize data size for storage/network
-- @return table - Array of serialized dot data
function LoolibCanvasBrushMixin:SerializeDots()
    local data = {}
    for i = 1, #self._dots_X do
        data[i] = {
            x = self._dots_X[i],
            y = self._dots_Y[i],
            s = self._dots_SIZE[i],
            c = self._dots_COLOR[i],
            g = self._dots_GROUP[i],
        }
    end
    return data
end

--- Deserialize dots from compact format
-- @param data table|nil - Array of serialized dot data (nil to clear)
-- @return self - For method chaining
function LoolibCanvasBrushMixin:DeserializeDots(data)
    self:ClearDots()
    if not data then return self end

    for i, dot in ipairs(data) do
        self._dots_X[i] = dot.x
        self._dots_Y[i] = dot.y
        self._dots_SIZE[i] = dot.s or 6
        self._dots_COLOR[i] = dot.c or 4
        self._dots_GROUP[i] = dot.g or 0
        self._dots_SYNC[i] = i
    end
    self._nextSyncId = #data + 1

    return self
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new canvas brush instance
-- @return table - Initialized brush object
function LoolibCreateCanvasBrush()
    local brush = {}
    LoolibMixin(brush, LoolibCanvasBrushMixin)
    brush:OnLoad()
    return brush
end

--[[--------------------------------------------------------------------
    Module Registration
----------------------------------------------------------------------]]

local CanvasBrushModule = {
    Mixin = LoolibCanvasBrushMixin,
    Create = LoolibCreateCanvasBrush,
}

Loolib:RegisterModule("CanvasBrush", CanvasBrushModule)
