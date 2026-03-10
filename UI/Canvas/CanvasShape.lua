--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Canvas Shape Drawing System

    Provides geometric shape drawing and management for canvas systems.
    Supports circles, rectangles, lines, arrows, and dashed lines with
    group-based organization and serialization.

    Based on MRT's VisNote.lua parallel array pattern for performance.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Shape Type Constants
----------------------------------------------------------------------]]

--- Global shape type enumeration
local LOOLIB_SHAPE_TYPES = {
    CIRCLE = 1,           -- Outline circle
    CIRCLE_FILLED = 2,    -- Filled circle
    LINE = 3,             -- Straight line
    LINE_ARROW = 4,       -- Line with arrowhead
    LINE_DASHED = 5,      -- Dashed line
    RECTANGLE = 6,        -- Outline rectangle
    RECTANGLE_FILLED = 7, -- Filled rectangle
}

--[[--------------------------------------------------------------------
    LoolibCanvasShapeMixin

    Manages geometric shapes on a canvas using parallel arrays for
    optimal performance. Each shape is defined by two points (start/end)
    plus rendering properties.
----------------------------------------------------------------------]]

local LoolibCanvasShapeMixin = {}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the shape management system
-- Sets up parallel arrays and default settings
function LoolibCanvasShapeMixin:OnLoad()
    -- Current drawing settings
    self._shapeType = LOOLIB_SHAPE_TYPES.LINE
    self._shapeColor = 4  -- Red default
    self._shapeSize = 2   -- Line thickness/size
    self._shapeAlpha = 1.0

    -- Preview state for interactive drawing (click-drag)
    self._isDrawingShape = false
    self._previewX1 = nil
    self._previewY1 = nil
    self._previewX2 = nil
    self._previewY2 = nil

    -- Current group ID for organization
    self._currentGroup = 0

    -- Shape storage (parallel arrays for performance)
    -- Indexed by shape number (1-based)
    self._shape_X1 = {}      -- Start X coordinate
    self._shape_Y1 = {}      -- Start Y coordinate
    self._shape_X2 = {}      -- End X coordinate
    self._shape_Y2 = {}      -- End Y coordinate
    self._shape_TYPE = {}    -- LOOLIB_SHAPE_TYPES value
    self._shape_COLOR = {}   -- Color index
    self._shape_SIZE = {}    -- Thickness/size
    self._shape_ALPHA = {}   -- Alpha transparency (0-1)
    self._shape_GROUP = {}   -- Group ID (0 = ungrouped)
    self._shape_SYNC = {}    -- Sync/version ID

    -- Sync ID counter
    self._nextSyncId = 1
end

--[[--------------------------------------------------------------------
    Current Drawing Settings

    These control the properties of newly created shapes.
----------------------------------------------------------------------]]

--- Set the current shape type for new shapes
-- @param shapeType number - One of LOOLIB_SHAPE_TYPES
-- @return self - For method chaining
function LoolibCanvasShapeMixin:SetShapeType(shapeType)
    self._shapeType = shapeType
    return self
end

--- Get the current shape type
-- @return number - Current LOOLIB_SHAPE_TYPES value
function LoolibCanvasShapeMixin:GetShapeType()
    return self._shapeType
end

--- Set the current color index for new shapes
-- @param colorIndex number - Color palette index (1-based)
-- @return self - For method chaining
function LoolibCanvasShapeMixin:SetShapeColor(colorIndex)
    self._shapeColor = colorIndex
    return self
end

--- Get the current color index
-- @return number - Current color palette index
function LoolibCanvasShapeMixin:GetShapeColor()
    return self._shapeColor
end

--- Set the current size/thickness for new shapes
-- @param size number - Size value (1-10, clamped)
-- @return self - For method chaining
function LoolibCanvasShapeMixin:SetShapeSize(size)
    self._shapeSize = math.max(1, math.min(10, size))
    return self
end

--- Get the current shape size
-- @return number - Current size value
function LoolibCanvasShapeMixin:GetShapeSize()
    return self._shapeSize
end

--- Set the current alpha transparency for new shapes
-- @param alpha number - Alpha value (0-1, clamped)
-- @return self - For method chaining
function LoolibCanvasShapeMixin:SetShapeAlpha(alpha)
    self._shapeAlpha = math.max(0, math.min(1, alpha))
    return self
end

--- Get the current alpha transparency
-- @return number - Current alpha value
function LoolibCanvasShapeMixin:GetShapeAlpha()
    return self._shapeAlpha
end

--- Set the current group ID for new shapes
-- @param groupId number - Group ID (0 = ungrouped)
-- @return self - For method chaining
function LoolibCanvasShapeMixin:SetCurrentGroup(groupId)
    self._currentGroup = groupId or 0
    return self
end

--- Get the current group ID
-- @return number - Current group ID
function LoolibCanvasShapeMixin:GetCurrentGroup()
    return self._currentGroup
end

--[[--------------------------------------------------------------------
    Interactive Shape Drawing (Click-Drag Pattern)

    Supports a preview mode where shapes are drawn interactively,
    showing a live preview before finalizing the shape.
----------------------------------------------------------------------]]

--- Begin drawing a new shape at the given point
-- Enters preview mode for interactive shape creation
-- @param x number - Starting X coordinate
-- @param y number - Starting Y coordinate
-- @return self - For method chaining
function LoolibCanvasShapeMixin:StartShape(x, y)
    self._isDrawingShape = true
    self._previewX1 = x
    self._previewY1 = y
    self._previewX2 = x
    self._previewY2 = y

    if self.TriggerEvent then
        self:TriggerEvent("OnShapeStart", x, y)
    end

    return self
end

--- Update the preview endpoint as the mouse moves
-- @param x number - Current X coordinate
-- @param y number - Current Y coordinate
-- @return self - For method chaining
function LoolibCanvasShapeMixin:UpdateShapePreview(x, y)
    if not self._isDrawingShape then return self end

    self._previewX2 = x
    self._previewY2 = y

    if self.TriggerEvent then
        self:TriggerEvent("OnShapePreviewUpdate", self._previewX1, self._previewY1, x, y)
    end

    return self
end

--- Finalize the shape at the current endpoint
-- Creates the actual shape and exits preview mode
-- @param x number - Final X coordinate
-- @param y number - Final Y coordinate
-- @return number|nil - Index of created shape, or nil if invalid
function LoolibCanvasShapeMixin:FinishShape(x, y)
    if not self._isDrawingShape then return nil end

    self._isDrawingShape = false

    -- Don't create zero-size shapes (no movement)
    local dx = x - self._previewX1
    local dy = y - self._previewY1
    if dx == 0 and dy == 0 then
        self._previewX1 = nil
        self._previewY1 = nil
        self._previewX2 = nil
        self._previewY2 = nil
        return nil
    end

    -- Create the actual shape
    local index = self:_AddShape(
        self._previewX1, self._previewY1,
        x, y,
        self._shapeType,
        self._shapeColor,
        self._shapeSize,
        self._shapeAlpha,
        self._currentGroup
    )

    -- Clear preview state
    self._previewX1 = nil
    self._previewY1 = nil
    self._previewX2 = nil
    self._previewY2 = nil

    return index
end

--- Cancel the current shape preview
-- Exits preview mode without creating a shape
-- @return self - For method chaining
function LoolibCanvasShapeMixin:CancelShape()
    self._isDrawingShape = false
    self._previewX1 = nil
    self._previewY1 = nil
    self._previewX2 = nil
    self._previewY2 = nil
    return self
end

--- Check if currently in preview mode
-- @return boolean - True if drawing a shape
function LoolibCanvasShapeMixin:IsDrawingShape()
    return self._isDrawingShape
end

--- Get the current preview shape data
-- @return table|nil - Preview shape info, or nil if not drawing
--   Fields: x1, y1, x2, y2, shapeType, color, size, alpha
function LoolibCanvasShapeMixin:GetPreviewShape()
    if not self._isDrawingShape then return nil end
    return {
        x1 = self._previewX1,
        y1 = self._previewY1,
        x2 = self._previewX2,
        y2 = self._previewY2,
        shapeType = self._shapeType,
        color = self._shapeColor,
        size = self._shapeSize,
        alpha = self._shapeAlpha,
    }
end

--[[--------------------------------------------------------------------
    Shape Creation and Management
----------------------------------------------------------------------]]

--- Internal: Add a shape to the parallel arrays
-- @param x1 number - Start X
-- @param y1 number - Start Y
-- @param x2 number - End X
-- @param y2 number - End Y
-- @param shapeType number - LOOLIB_SHAPE_TYPES value
-- @param color number - Color index
-- @param size number - Size/thickness
-- @param alpha number - Alpha transparency
-- @param group number - Group ID
-- @return number - Index of added shape
function LoolibCanvasShapeMixin:_AddShape(x1, y1, x2, y2, shapeType, color, size, alpha, group)
    local index = #self._shape_X1 + 1

    self._shape_X1[index] = x1
    self._shape_Y1[index] = y1
    self._shape_X2[index] = x2
    self._shape_Y2[index] = y2
    self._shape_TYPE[index] = shapeType
    self._shape_COLOR[index] = color
    self._shape_SIZE[index] = size
    self._shape_ALPHA[index] = alpha
    self._shape_GROUP[index] = group
    self._shape_SYNC[index] = self._nextSyncId
    self._nextSyncId = self._nextSyncId + 1

    if self.TriggerEvent then
        self:TriggerEvent("OnShapeAdded", index)
    end

    return index
end

--- Add a shape directly with all parameters
-- @param x1 number - Start X
-- @param y1 number - Start Y
-- @param x2 number - End X
-- @param y2 number - End Y
-- @param shapeType number|nil - LOOLIB_SHAPE_TYPES value (default: current)
-- @param color number|nil - Color index (default: current)
-- @param size number|nil - Size/thickness (default: current)
-- @param alpha number|nil - Alpha transparency (default: current)
-- @param group number|nil - Group ID (default: current)
-- @return number - Index of created shape
function LoolibCanvasShapeMixin:AddShape(x1, y1, x2, y2, shapeType, color, size, alpha, group)
    return self:_AddShape(
        x1, y1, x2, y2,
        shapeType or self._shapeType,
        color or self._shapeColor,
        size or self._shapeSize,
        alpha or self._shapeAlpha,
        group or self._currentGroup
    )
end

--- Get a shape's data by index
-- @param index number - Shape index (1-based)
-- @return table|nil - Shape data, or nil if not found
--   Fields: x1, y1, x2, y2, shapeType, color, size, alpha, group, syncId
function LoolibCanvasShapeMixin:GetShape(index)
    if not self._shape_X1[index] then return nil end
    return {
        x1 = self._shape_X1[index],
        y1 = self._shape_Y1[index],
        x2 = self._shape_X2[index],
        y2 = self._shape_Y2[index],
        shapeType = self._shape_TYPE[index],
        color = self._shape_COLOR[index],
        size = self._shape_SIZE[index],
        alpha = self._shape_ALPHA[index],
        group = self._shape_GROUP[index],
        syncId = self._shape_SYNC[index],
    }
end

--- Get all shapes as an array
-- @return table - Array of shape data tables (indexed 1-N)
function LoolibCanvasShapeMixin:GetAllShapes()
    local result = {}
    for i = 1, #self._shape_X1 do
        result[i] = self:GetShape(i)
    end
    return result
end

--- Get the total number of shapes
-- @return number - Shape count
function LoolibCanvasShapeMixin:GetShapeCount()
    return #self._shape_X1
end

--- Clear all shapes
-- Removes all shape data and resets sync counter
-- @return self - For method chaining
function LoolibCanvasShapeMixin:ClearShapes()
    self._shape_X1 = {}
    self._shape_Y1 = {}
    self._shape_X2 = {}
    self._shape_Y2 = {}
    self._shape_TYPE = {}
    self._shape_COLOR = {}
    self._shape_SIZE = {}
    self._shape_ALPHA = {}
    self._shape_GROUP = {}
    self._shape_SYNC = {}

    if self.TriggerEvent then
        self:TriggerEvent("OnShapesCleared")
    end

    return self
end

--[[--------------------------------------------------------------------
    Group Operations

    Shapes can be organized into groups for batch operations.
----------------------------------------------------------------------]]

--- Delete all shapes in a specific group
-- Rebuilds parallel arrays without the matching group
-- @param groupId number - Group ID to delete
-- @return self - For method chaining
function LoolibCanvasShapeMixin:DeleteShapesByGroup(groupId)
    -- Rebuild arrays without matching group
    local newX1, newY1, newX2, newY2 = {}, {}, {}, {}
    local newType, newColor, newSize, newAlpha, newGroup, newSync = {}, {}, {}, {}, {}, {}

    for i = 1, #self._shape_X1 do
        if self._shape_GROUP[i] ~= groupId then
            local n = #newX1 + 1
            newX1[n] = self._shape_X1[i]
            newY1[n] = self._shape_Y1[i]
            newX2[n] = self._shape_X2[i]
            newY2[n] = self._shape_Y2[i]
            newType[n] = self._shape_TYPE[i]
            newColor[n] = self._shape_COLOR[i]
            newSize[n] = self._shape_SIZE[i]
            newAlpha[n] = self._shape_ALPHA[i]
            newGroup[n] = self._shape_GROUP[i]
            newSync[n] = self._shape_SYNC[i]
        end
    end

    self._shape_X1, self._shape_Y1 = newX1, newY1
    self._shape_X2, self._shape_Y2 = newX2, newY2
    self._shape_TYPE, self._shape_COLOR = newType, newColor
    self._shape_SIZE, self._shape_ALPHA = newSize, newAlpha
    self._shape_GROUP, self._shape_SYNC = newGroup, newSync

    if self.TriggerEvent then
        self:TriggerEvent("OnGroupDeleted", groupId)
    end

    return self
end

--- Move all shapes in a group by a delta offset
-- @param groupId number - Group ID to move
-- @param deltaX number - X offset to apply
-- @param deltaY number - Y offset to apply
-- @return self - For method chaining
function LoolibCanvasShapeMixin:MoveShapesByGroup(groupId, deltaX, deltaY)
    for i = 1, #self._shape_X1 do
        if self._shape_GROUP[i] == groupId then
            self._shape_X1[i] = self._shape_X1[i] + deltaX
            self._shape_Y1[i] = self._shape_Y1[i] + deltaY
            self._shape_X2[i] = self._shape_X2[i] + deltaX
            self._shape_Y2[i] = self._shape_Y2[i] + deltaY
        end
    end

    if self.TriggerEvent then
        self:TriggerEvent("OnGroupMoved", groupId, deltaX, deltaY)
    end

    return self
end

--- Delete a single shape by index
-- @param index number - Shape index to delete
-- @return self - For method chaining
function LoolibCanvasShapeMixin:DeleteShape(index)
    if not self._shape_X1[index] then return self end

    -- Rebuild arrays without this index
    local newX1, newY1, newX2, newY2 = {}, {}, {}, {}
    local newType, newColor, newSize, newAlpha, newGroup, newSync = {}, {}, {}, {}, {}, {}

    for i = 1, #self._shape_X1 do
        if i ~= index then
            local n = #newX1 + 1
            newX1[n] = self._shape_X1[i]
            newY1[n] = self._shape_Y1[i]
            newX2[n] = self._shape_X2[i]
            newY2[n] = self._shape_Y2[i]
            newType[n] = self._shape_TYPE[i]
            newColor[n] = self._shape_COLOR[i]
            newSize[n] = self._shape_SIZE[i]
            newAlpha[n] = self._shape_ALPHA[i]
            newGroup[n] = self._shape_GROUP[i]
            newSync[n] = self._shape_SYNC[i]
        end
    end

    self._shape_X1, self._shape_Y1 = newX1, newY1
    self._shape_X2, self._shape_Y2 = newX2, newY2
    self._shape_TYPE, self._shape_COLOR = newType, newColor
    self._shape_SIZE, self._shape_ALPHA = newSize, newAlpha
    self._shape_GROUP, self._shape_SYNC = newGroup, newSync

    if self.TriggerEvent then
        self:TriggerEvent("OnShapeDeleted", index)
    end

    return self
end

--- Get all groups present in the shape list
-- @return table - Array of unique group IDs
function LoolibCanvasShapeMixin:GetGroups()
    local groups = {}
    local seen = {}

    for i = 1, #self._shape_GROUP do
        local groupId = self._shape_GROUP[i]
        if not seen[groupId] then
            seen[groupId] = true
            table.insert(groups, groupId)
        end
    end

    table.sort(groups)
    return groups
end

--- Get shape count for a specific group
-- @param groupId number - Group ID to count
-- @return number - Number of shapes in group
function LoolibCanvasShapeMixin:GetGroupShapeCount(groupId)
    local count = 0
    for i = 1, #self._shape_GROUP do
        if self._shape_GROUP[i] == groupId then
            count = count + 1
        end
    end
    return count
end

--[[--------------------------------------------------------------------
    Serialization

    Convert shapes to/from compact table format for save/sync.
----------------------------------------------------------------------]]

--- Serialize all shapes to a compact table format
-- @return table - Array of shape data (abbreviated field names)
function LoolibCanvasShapeMixin:SerializeShapes()
    local data = {}
    for i = 1, #self._shape_X1 do
        data[i] = {
            x1 = self._shape_X1[i],
            y1 = self._shape_Y1[i],
            x2 = self._shape_X2[i],
            y2 = self._shape_Y2[i],
            t = self._shape_TYPE[i],
            c = self._shape_COLOR[i],
            s = self._shape_SIZE[i],
            a = self._shape_ALPHA[i],
            g = self._shape_GROUP[i],
        }
    end
    return data
end

--- Deserialize shapes from a table format
-- Clears existing shapes and loads the provided data
-- @param data table|nil - Array of shape data (or nil to clear)
-- @return self - For method chaining
function LoolibCanvasShapeMixin:DeserializeShapes(data)
    self:ClearShapes()
    if not data then return self end

    for i, shape in ipairs(data) do
        self._shape_X1[i] = shape.x1
        self._shape_Y1[i] = shape.y1
        self._shape_X2[i] = shape.x2
        self._shape_Y2[i] = shape.y2
        self._shape_TYPE[i] = shape.t or LOOLIB_SHAPE_TYPES.LINE
        self._shape_COLOR[i] = shape.c or 4
        self._shape_SIZE[i] = shape.s or 2
        self._shape_ALPHA[i] = shape.a or 1
        self._shape_GROUP[i] = shape.g or 0
        self._shape_SYNC[i] = i
    end
    self._nextSyncId = #data + 1

    if self.TriggerEvent then
        self:TriggerEvent("OnShapesDeserialized", #data)
    end

    return self
end

--[[--------------------------------------------------------------------
    Utility Functions
----------------------------------------------------------------------]]

--- Get the human-readable name of a shape type
-- @param shapeType number - LOOLIB_SHAPE_TYPES value
-- @return string - Type name (e.g., "CIRCLE") or "UNKNOWN"
function LoolibCanvasShapeMixin:GetShapeTypeName(shapeType)
    for name, value in pairs(LOOLIB_SHAPE_TYPES) do
        if value == shapeType then return name end
    end
    return "UNKNOWN"
end

--- Update a shape's properties
-- @param index number - Shape index
-- @param updates table - Table of properties to update (x1, y1, x2, y2, etc.)
-- @return self - For method chaining
function LoolibCanvasShapeMixin:UpdateShape(index, updates)
    if not self._shape_X1[index] then return self end

    if updates.x1 then self._shape_X1[index] = updates.x1 end
    if updates.y1 then self._shape_Y1[index] = updates.y1 end
    if updates.x2 then self._shape_X2[index] = updates.x2 end
    if updates.y2 then self._shape_Y2[index] = updates.y2 end
    if updates.shapeType then self._shape_TYPE[index] = updates.shapeType end
    if updates.color then self._shape_COLOR[index] = updates.color end
    if updates.size then self._shape_SIZE[index] = updates.size end
    if updates.alpha then self._shape_ALPHA[index] = updates.alpha end
    if updates.group then self._shape_GROUP[index] = updates.group end

    if self.TriggerEvent then
        self:TriggerEvent("OnShapeUpdated", index)
    end

    return self
end

--- Move a single shape by offset
-- @param index number - Shape index
-- @param deltaX number - X offset
-- @param deltaY number - Y offset
-- @return self - For method chaining
function LoolibCanvasShapeMixin:MoveShape(index, deltaX, deltaY)
    if not self._shape_X1[index] then return self end

    self._shape_X1[index] = self._shape_X1[index] + deltaX
    self._shape_Y1[index] = self._shape_Y1[index] + deltaY
    self._shape_X2[index] = self._shape_X2[index] + deltaX
    self._shape_Y2[index] = self._shape_Y2[index] + deltaY

    if self.TriggerEvent then
        self:TriggerEvent("OnShapeMoved", index, deltaX, deltaY)
    end

    return self
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new shape manager instance
-- @return table - A new shape manager object
local function LoolibCreateCanvasShape()
    local shape = {}
    Loolib.Mixin(shape, LoolibCanvasShapeMixin)
    shape:OnLoad()
    return shape
end

--[[--------------------------------------------------------------------
    Module Registration
----------------------------------------------------------------------]]

Loolib:RegisterModule("CanvasShape", {
    Mixin = LoolibCanvasShapeMixin,
    TYPES = LOOLIB_SHAPE_TYPES,
    Create = LoolibCreateCanvasShape,
})
