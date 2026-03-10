--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    CanvasElement - Base mixin for all canvas drawing elements

    This is the BASE MIXIN that all canvas elements (brush, shape, text,
    icon, image) inherit from. It provides common functionality for
    position, grouping, locking, and serialization.

    Inspired by MRT's VisNote system which uses parallel arrays to store
    element data. This mixin provides an object-oriented interface while
    maintaining compatibility with MRT's storage format.

    Usage:
        -- Create a canvas element
        local CanvasElement = Loolib:GetModule("CanvasElement")
        local element = CanvasElement.Create(CanvasElement.TYPES.DOT)
        element:SetPosition(100, 150)
               :SetColor(4)
               :SetSize(8)
               :SetGroup(1)

        -- Serialize for storage
        local data = element:Serialize()

        -- Deserialize from storage
        element:Deserialize(data)

        -- Get RGB color values
        local r, g, b = element:GetColorRGB()
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Local references for performance (removed unused aliases)

local CreateCanvasElement  -- forward declaration

--[[--------------------------------------------------------------------
    ELEMENT TYPES
----------------------------------------------------------------------]]

--- Canvas element types (compatible with MRT VisNote)
--- @type table<string, number>
local LOOLIB_CANVAS_ELEMENT_TYPES = {
    DOT = 1,        -- Brush stroke dot/pixel
    ICON = 2,       -- Icon/texture
    TEXT = 3,       -- Text label
    SHAPE = 4,      -- Geometric shape (line, rect, circle, etc.)
    IMAGE = 5,      -- Image/atlas texture
}

--[[--------------------------------------------------------------------
    COLOR PALETTE
----------------------------------------------------------------------]]

--- MRT-compatible color palette (25 colors)
--- Each color is {r, g, b} with values 0-1
--- @type table<number, table<number>>
local LOOLIB_CANVAS_COLORS = {
    {0, 0, 0},                              -- 1: Black
    {127/255, 127/255, 127/255},            -- 2: Gray
    {136/255, 0/255, 21/255},               -- 3: Dark red
    {237/255, 28/255, 36/255},              -- 4: Red
    {255/255, 127/255, 39/255},             -- 5: Orange
    {255/255, 242/255, 0/255},              -- 6: Yellow
    {34/255, 177/255, 76/255},              -- 7: Green
    {0/255, 162/255, 232/255},              -- 8: Light blue
    {63/255, 72/255, 204/255},              -- 9: Blue
    {163/255, 73/255, 164/255},             -- 10: Purple
    {1, 1, 1},                              -- 11: White
    {195/255, 195/255, 195/255},            -- 12: Light gray
    {185/255, 122/255, 87/255},             -- 13: Brown
    {255/255, 174/255, 201/255},            -- 14: Pink
    {255/255, 201/255, 14/255},             -- 15: Gold
    {239/255, 228/255, 176/255},            -- 16: Cream
    {181/255, 230/255, 29/255},             -- 17: Lime
    {153/255, 217/255, 234/255},            -- 18: Cyan
    {112/255, 146/255, 190/255},            -- 19: Steel blue
    {200/255, 191/255, 231/255},            -- 20: Lavender
    {0.67, 0.83, 0.45},                     -- 21: Light green
    {0, 1, 0.59},                           -- 22: Aqua
    {0.53, 0.53, 0.93},                     -- 23: Periwinkle
    {0.64, 0.19, 0.79},                     -- 24: Violet
    {0.20, 0.58, 0.50},                     -- 25: Teal
}

--[[--------------------------------------------------------------------
    LoolibCanvasElementMixin - Base Canvas Element
----------------------------------------------------------------------]]

--- Base mixin for all canvas elements
--- Provides position, color, grouping, locking, and serialization
--- @class LoolibCanvasElementMixin
local LoolibCanvasElementMixin = {}

--- Initialize element with default values
--- Called automatically when element is created
function LoolibCanvasElementMixin:OnLoad()
    self._elementType = nil
    self._x = 0
    self._y = 0
    self._groupId = 0
    self._isLocked = false
    self._colorIndex = 4        -- Default red
    self._size = 6              -- Default size
    self._syncId = nil          -- ID for multiplayer sync
end

-- ============================================================
-- ELEMENT TYPE
-- ============================================================

--- Get the element type
--- @return number Element type from LOOLIB_CANVAS_ELEMENT_TYPES
function LoolibCanvasElementMixin:GetElementType()
    return self._elementType
end

--- Set the element type
--- @param elementType number Element type from LOOLIB_CANVAS_ELEMENT_TYPES
--- @return table self for chaining
function LoolibCanvasElementMixin:SetElementType(elementType)
    self._elementType = elementType
    return self
end

-- ============================================================
-- POSITION
-- ============================================================

--- Get element position
--- @return number x X coordinate
--- @return number y Y coordinate
function LoolibCanvasElementMixin:GetPosition()
    return self._x, self._y
end

--- Set element position
--- @param x number X coordinate
--- @param y number Y coordinate
--- @return table self for chaining
function LoolibCanvasElementMixin:SetPosition(x, y)
    self._x = x
    self._y = y
    return self
end

--- Get X coordinate
--- @return number X coordinate
function LoolibCanvasElementMixin:GetX()
    return self._x
end

--- Set X coordinate
--- @param x number X coordinate
--- @return table self for chaining
function LoolibCanvasElementMixin:SetX(x)
    self._x = x
    return self
end

--- Get Y coordinate
--- @return number Y coordinate
function LoolibCanvasElementMixin:GetY()
    return self._y
end

--- Set Y coordinate
--- @param y number Y coordinate
--- @return table self for chaining
function LoolibCanvasElementMixin:SetY(y)
    self._y = y
    return self
end

--- Offset element position by delta
--- @param dx number X offset
--- @param dy number Y offset
--- @return table self for chaining
function LoolibCanvasElementMixin:Offset(dx, dy)
    self._x = self._x + dx
    self._y = self._y + dy
    return self
end

-- ============================================================
-- GROUPING
-- ============================================================

--- Get group ID
--- @return number Group ID (0 = no group)
function LoolibCanvasElementMixin:GetGroup()
    return self._groupId
end

--- Set group ID
--- @param groupId number|nil Group ID (0 or nil = no group)
--- @return table self for chaining
function LoolibCanvasElementMixin:SetGroup(groupId)
    self._groupId = groupId or 0
    return self
end

--- Check if element belongs to a group
--- @return boolean True if element is in a group
function LoolibCanvasElementMixin:IsInGroup()
    return self._groupId > 0
end

--- Check if element belongs to a specific group
--- @param groupId number Group ID to check
--- @return boolean True if element is in the specified group
function LoolibCanvasElementMixin:IsInGroupId(groupId)
    return self._groupId == groupId
end

-- ============================================================
-- LOCKING
-- ============================================================

--- Check if element is locked
--- @return boolean True if locked
function LoolibCanvasElementMixin:IsLocked()
    return self._isLocked
end

--- Set locked state
--- @param locked boolean True to lock, false to unlock
--- @return table self for chaining
function LoolibCanvasElementMixin:SetLocked(locked)
    self._isLocked = locked
    return self
end

--- Lock the element
--- @return table self for chaining
function LoolibCanvasElementMixin:Lock()
    self._isLocked = true
    return self
end

--- Unlock the element
--- @return table self for chaining
function LoolibCanvasElementMixin:Unlock()
    self._isLocked = false
    return self
end

-- ============================================================
-- COLOR
-- ============================================================

--- Get color index
--- @return number Color index (1-25)
function LoolibCanvasElementMixin:GetColor()
    return self._colorIndex
end

--- Set color by index
--- @param colorIndex number Color index (1-25)
--- @return table self for chaining
function LoolibCanvasElementMixin:SetColor(colorIndex)
    self._colorIndex = colorIndex
    return self
end

--- Get RGB color values
--- @return number r Red component (0-1)
--- @return number g Green component (0-1)
--- @return number b Blue component (0-1)
function LoolibCanvasElementMixin:GetColorRGB()
    local color = LOOLIB_CANVAS_COLORS[self._colorIndex]
    if color then
        return color[1], color[2], color[3]
    end
    return 1, 0, 0  -- Default to red if invalid
end

--- Get RGBA color values with optional alpha
--- @param alpha number|nil Alpha value (default 1.0)
--- @return number r Red component (0-1)
--- @return number g Green component (0-1)
--- @return number b Blue component (0-1)
--- @return number a Alpha component (0-1)
function LoolibCanvasElementMixin:GetColorRGBA(alpha)
    local r, g, b = self:GetColorRGB()
    return r, g, b, alpha or 1.0
end

-- ============================================================
-- SIZE
-- ============================================================

--- Get element size
--- @return number Size value
function LoolibCanvasElementMixin:GetSize()
    return self._size
end

--- Set element size
--- @param size number Size value
--- @return table self for chaining
function LoolibCanvasElementMixin:SetSize(size)
    self._size = size
    return self
end

-- ============================================================
-- SYNC ID (for multiplayer)
-- ============================================================

--- Get sync ID (for multiplayer synchronization)
--- @return string|nil Sync ID
function LoolibCanvasElementMixin:GetSyncId()
    return self._syncId
end

--- Set sync ID (for multiplayer synchronization)
--- @param id string|nil Sync ID
--- @return table self for chaining
function LoolibCanvasElementMixin:SetSyncId(id)
    self._syncId = id
    return self
end

--- Check if element has a sync ID
--- @return boolean True if element has a sync ID
function LoolibCanvasElementMixin:HasSyncId()
    return self._syncId ~= nil
end

-- ============================================================
-- SERIALIZATION
-- ============================================================

--- Serialize element to table for storage or sync
--- Subclasses should extend this to include type-specific data
--- @return table Serialized element data
function LoolibCanvasElementMixin:Serialize()
    return {
        t = self._elementType,      -- Type
        x = self._x,                -- X coordinate
        y = self._y,                -- Y coordinate
        g = self._groupId,          -- Group ID
        c = self._colorIndex,       -- Color index
        s = self._size,             -- Size
    }
end

--- Deserialize element from table
--- Subclasses should extend this to restore type-specific data
--- @param data table Serialized element data
--- @return table self for chaining
function LoolibCanvasElementMixin:Deserialize(data)
    if not data then
        return self
    end

    self._elementType = data.t
    self._x = data.x or 0
    self._y = data.y or 0
    self._groupId = data.g or 0
    self._colorIndex = data.c or 4
    self._size = data.s or 6

    return self
end

--- Clone element (deep copy)
--- @return table New element with same properties
function LoolibCanvasElementMixin:Clone()
    local clone = CreateCanvasElement(self._elementType)
    local data = self:Serialize()
    clone:Deserialize(data)
    clone._isLocked = self._isLocked
    return clone
end

-- ============================================================
-- BOUNDS & HIT TESTING (for selection)
-- ============================================================

--- Get bounding box for selection/hit testing
--- Subclasses should override this for accurate bounds
--- @return number minX Minimum X coordinate
--- @return number minY Minimum Y coordinate
--- @return number maxX Maximum X coordinate
--- @return number maxY Maximum Y coordinate
function LoolibCanvasElementMixin:GetBounds()
    local halfSize = self._size / 2
    return self._x - halfSize, self._y - halfSize,
           self._x + halfSize, self._y + halfSize
end

--- Test if a point is inside the element
--- Subclasses should override this for accurate hit testing
--- @param x number X coordinate to test
--- @param y number Y coordinate to test
--- @return boolean True if point is inside element
function LoolibCanvasElementMixin:HitTest(x, y)
    local minX, minY, maxX, maxY = self:GetBounds()
    return x >= minX and x <= maxX and y >= minY and y <= maxY
end

--- Get distance from point to element center
--- @param x number X coordinate
--- @param y number Y coordinate
--- @return number Distance in pixels
function LoolibCanvasElementMixin:GetDistanceFrom(x, y)
    local dx = x - self._x
    local dy = y - self._y
    return math.sqrt(dx * dx + dy * dy)
end

--[[--------------------------------------------------------------------
    HELPER FUNCTIONS
----------------------------------------------------------------------]]

--- Get RGB color from palette index
--- @param colorIndex number Color index (1-25)
--- @return number r Red component (0-1)
--- @return number g Green component (0-1)
--- @return number b Blue component (0-1)
local function LoolibGetCanvasColor(colorIndex)
    local color = LOOLIB_CANVAS_COLORS[colorIndex]
    if color then
        return color[1], color[2], color[3]
    end
    return 1, 0, 0  -- Default to red if invalid
end

--- Get RGBA color from palette index with alpha
--- @param colorIndex number Color index (1-25)
--- @param alpha number|nil Alpha value (default 1.0)
--- @return number r Red component (0-1)
--- @return number g Green component (0-1)
--- @return number b Blue component (0-1)
--- @return number a Alpha component (0-1)
local function LoolibGetCanvasColorRGBA(colorIndex, alpha)
    local r, g, b = LoolibGetCanvasColor(colorIndex)
    return r, g, b, alpha or 1.0
end

--- Find closest color index for RGB values
--- @param r number Red component (0-1)
--- @param g number Green component (0-1)
--- @param b number Blue component (0-1)
--- @return number Closest color index
local function LoolibFindClosestCanvasColor(r, g, b)
    local minDist = math.huge
    local closestIndex = 4  -- Default red

    for i, color in ipairs(LOOLIB_CANVAS_COLORS) do
        local dr = r - color[1]
        local dg = g - color[2]
        local db = b - color[3]
        local dist = dr * dr + dg * dg + db * db

        if dist < minDist then
            minDist = dist
            closestIndex = i
        end
    end

    return closestIndex
end

--[[--------------------------------------------------------------------
    FACTORY FUNCTIONS
----------------------------------------------------------------------]]

--- Create a new canvas element with mixin applied
--- @param elementType number Element type from LOOLIB_CANVAS_ELEMENT_TYPES
--- @return table New canvas element
CreateCanvasElement = function(elementType)
    local element = {}
    Loolib.Mixin(element, LoolibCanvasElementMixin)
    element:OnLoad()
    element:SetElementType(elementType)
    return element
end

--[[--------------------------------------------------------------------
    GLOBAL EXPORTS & MODULE REGISTRATION
----------------------------------------------------------------------]]

-- Register with Loolib module system
Loolib:RegisterModule("CanvasElement", {
    -- Mixin
    Mixin = LoolibCanvasElementMixin,

    -- Constants
    TYPES = LOOLIB_CANVAS_ELEMENT_TYPES,
    COLORS = LOOLIB_CANVAS_COLORS,

    -- Factory
    Create = CreateCanvasElement,

    -- Utilities
    GetColor = LoolibGetCanvasColor,
    GetColorRGBA = LoolibGetCanvasColorRGBA,
    FindClosestColor = LoolibFindClosestCanvasColor,
})
