--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    CanvasIcon - Icon placement system for canvas drawings

    Manages placement of raid markers, role icons, class icons, and faction
    icons on a tactical canvas. Uses parallel arrays for performance-critical
    icon storage and rendering.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Icon Type Constants

    Defines all 25 available icon types:
    - Raid markers (1-8): Star, Circle, Diamond, Triangle, Moon, Square, Cross, Skull
    - Role icons (9-11): Tank, Healer, DPS
    - Faction icon (12): Alliance/Horde (based on player faction)
    - Class icons (13-25): All WoW classes
----------------------------------------------------------------------]]

LOOLIB_ICON_TYPES = {
    -- Raid target markers (1-8)
    STAR = 1,
    CIRCLE = 2,
    DIAMOND = 3,
    TRIANGLE = 4,
    MOON = 5,
    SQUARE = 6,
    CROSS = 7,
    SKULL = 8,

    -- Role icons (9-11)
    TANK = 9,
    HEALER = 10,
    DPS = 11,

    -- Faction icon (12)
    FACTION = 12,

    -- Class icons (13-25)
    WARRIOR = 13,
    PALADIN = 14,
    HUNTER = 15,
    ROGUE = 16,
    PRIEST = 17,
    SHAMAN = 18,
    MAGE = 19,
    WARLOCK = 20,
    DRUID = 21,
    DEATHKNIGHT = 22,
    MONK = 23,
    DEMONHUNTER = 24,
    EVOKER = 25,
}

--[[--------------------------------------------------------------------
    Icon Texture Definitions

    Maps icon types to texture paths and texture coordinates.
    Role icons and class icons use texture atlases with coordinate sets.
----------------------------------------------------------------------]]

LOOLIB_ICON_TEXTURES = {
    -- Raid target markers (1-8)
    [1] = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
    [2] = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
    [3] = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
    [4] = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
    [5] = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
    [6] = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
    [7] = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
    [8] = { path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },

    -- Tank role icon (9)
    [9] = {
        path = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES",
        coords = { 0, 0.26171875, 0.26171875, 0.5234375 }
    },

    -- Healer role icon (10)
    [10] = {
        path = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES",
        coords = { 0.26171875, 0.5234375, 0, 0.26171875 }
    },

    -- DPS role icon (11)
    [11] = {
        path = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES",
        coords = { 0.26171875, 0.5234375, 0.26171875, 0.5234375 }
    },

    -- Faction icon (12) - dynamically set based on player faction
    [12] = {
        path = UnitFactionGroup("player") == "Alliance"
            and "Interface\\FriendsFrame\\PlusManz-Alliance"
            or "Interface\\FriendsFrame\\PlusManz-Horde"
    },

    -- Class icons from character creation screen (13-25)
    -- Warrior
    [13] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0, 0.25, 0, 0.25 }
    },

    -- Paladin
    [14] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0, 0.25, 0.5, 0.75 }
    },

    -- Hunter
    [15] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0, 0.25, 0.25, 0.5 }
    },

    -- Rogue
    [16] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0.49609375, 0.7421875, 0, 0.25 }
    },

    -- Priest
    [17] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0.49609375, 0.7421875, 0.25, 0.5 }
    },

    -- Shaman
    [18] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0.25, 0.5, 0.5, 0.75 }
    },

    -- Mage
    [19] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0.25, 0.49609375, 0.25, 0.5 }
    },

    -- Warlock
    [20] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0.25, 0.49609375, 0, 0.25 }
    },

    -- Druid
    [21] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0.7421875, 0.98828125, 0.25, 0.5 }
    },

    -- Death Knight
    [22] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0.5, 0.73828125, 0.5, 0.75 }
    },

    -- Monk
    [23] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0.7421875, 0.98828125, 0, 0.25 }
    },

    -- Demon Hunter
    [24] = {
        path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        coords = { 0.7421875, 0.98828125, 0.5, 0.75 }
    },

    -- Evoker
    [25] = {
        path = "Interface\\Icons\\classicon_evoker"
    },
}

--[[--------------------------------------------------------------------
    LoolibCanvasIconMixin

    Manages icon placement on a tactical canvas using parallel arrays
    for performance-critical storage and rendering.

    Storage Architecture:
    - Uses parallel arrays (MRT pattern) for memory efficiency
    - Each icon has: position (x,y), type, size, group, syncId
    - Group support for batch operations (move/delete groups)
    - Sync IDs for tracking individual icons across operations

    Events (requires CallbackRegistryMixin):
    - OnIconAdded(index) - Fired when an icon is added
    - OnIconDeleted(index) - Fired when an icon is deleted
    - OnIconsCleared() - Fired when all icons are cleared
----------------------------------------------------------------------]]

LoolibCanvasIconMixin = {}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the icon manager
-- Sets up default settings and parallel arrays for icon storage
function LoolibCanvasIconMixin:OnLoad()
    -- Default icon settings for new icons
    self._iconType = LOOLIB_ICON_TYPES.STAR
    self._iconSize = 24
    self._currentGroup = 0

    -- Parallel arrays for icon storage (MRT pattern)
    self._icon_X = {}       -- X coordinates
    self._icon_Y = {}       -- Y coordinates
    self._icon_TYPE = {}    -- Icon type (1-25)
    self._icon_SIZE = {}    -- Icon size in pixels
    self._icon_GROUP = {}   -- Group ID for batch operations
    self._icon_SYNC = {}    -- Sync ID for individual tracking

    -- Next available sync ID
    self._nextSyncId = 1
end

--[[--------------------------------------------------------------------
    Icon Settings
----------------------------------------------------------------------]]

--- Set the default icon type for new icons
-- @param iconType number - Icon type constant (1-25)
-- @return self - For method chaining
function LoolibCanvasIconMixin:SetIconType(iconType)
    self._iconType = iconType
    return self
end

--- Get the current default icon type
-- @return number - Icon type constant
function LoolibCanvasIconMixin:GetIconType()
    return self._iconType
end

--- Set the default icon size for new icons
-- @param size number - Icon size in pixels (clamped to 12-64)
-- @return self - For method chaining
function LoolibCanvasIconMixin:SetIconSize(size)
    self._iconSize = math.max(12, math.min(64, size))
    return self
end

--- Get the current default icon size
-- @return number - Icon size in pixels
function LoolibCanvasIconMixin:GetIconSize()
    return self._iconSize
end

--- Set the current group ID for new icons
-- @param groupId number - Group identifier (0 = no group)
-- @return self - For method chaining
function LoolibCanvasIconMixin:SetCurrentGroup(groupId)
    self._currentGroup = groupId or 0
    return self
end

--- Get the current group ID
-- @return number - Current group identifier
function LoolibCanvasIconMixin:GetCurrentGroup()
    return self._currentGroup
end

--[[--------------------------------------------------------------------
    Icon Management
----------------------------------------------------------------------]]

--- Add an icon to the canvas
-- @param x number - X coordinate (canvas space)
-- @param y number - Y coordinate (canvas space)
-- @param iconType number - Icon type (defaults to current setting)
-- @param size number - Icon size (defaults to current setting)
-- @param group number - Group ID (defaults to current group)
-- @return number - Index of the newly added icon
function LoolibCanvasIconMixin:AddIcon(x, y, iconType, size, group)
    local index = #self._icon_X + 1

    self._icon_X[index] = x
    self._icon_Y[index] = y
    self._icon_TYPE[index] = iconType or self._iconType
    self._icon_SIZE[index] = size or self._iconSize
    self._icon_GROUP[index] = group or self._currentGroup
    self._icon_SYNC[index] = self._nextSyncId
    self._nextSyncId = self._nextSyncId + 1

    if self.TriggerEvent then
        self:TriggerEvent("OnIconAdded", index)
    end

    return index
end

--- Get icon data at a specific index
-- @param index number - Icon index
-- @return table|nil - Icon data table or nil if not found
--   {x, y, iconType, size, group, syncId}
function LoolibCanvasIconMixin:GetIcon(index)
    if not self._icon_X[index] then return nil end

    return {
        x = self._icon_X[index],
        y = self._icon_Y[index],
        iconType = self._icon_TYPE[index],
        size = self._icon_SIZE[index],
        group = self._icon_GROUP[index],
        syncId = self._icon_SYNC[index],
    }
end

--- Get texture information for an icon type
-- @param iconType number - Icon type constant (1-25)
-- @return table - Texture data {path, coords?}
function LoolibCanvasIconMixin:GetIconTexture(iconType)
    return LOOLIB_ICON_TEXTURES[iconType]
end

--- Get all icons as an array of icon data tables
-- @return table - Array of icon data tables
function LoolibCanvasIconMixin:GetAllIcons()
    local result = {}
    for i = 1, #self._icon_X do
        result[i] = self:GetIcon(i)
    end
    return result
end

--- Get the total number of icons
-- @return number - Icon count
function LoolibCanvasIconMixin:GetIconCount()
    return #self._icon_X
end

--- Clear all icons from the canvas
-- @return self - For method chaining
function LoolibCanvasIconMixin:ClearIcons()
    self._icon_X = {}
    self._icon_Y = {}
    self._icon_TYPE = {}
    self._icon_SIZE = {}
    self._icon_GROUP = {}
    self._icon_SYNC = {}

    if self.TriggerEvent then
        self:TriggerEvent("OnIconsCleared")
    end

    return self
end

--[[--------------------------------------------------------------------
    Icon Deletion
----------------------------------------------------------------------]]

--- Delete a single icon by index
-- Removes the icon and shifts remaining icons down to fill the gap
-- @param index number - Icon index to delete
-- @return self - For method chaining
function LoolibCanvasIconMixin:DeleteIcon(index)
    if not self._icon_X[index] then return self end

    -- Shift all subsequent icons down
    for i = index, #self._icon_X - 1 do
        self._icon_X[i] = self._icon_X[i + 1]
        self._icon_Y[i] = self._icon_Y[i + 1]
        self._icon_TYPE[i] = self._icon_TYPE[i + 1]
        self._icon_SIZE[i] = self._icon_SIZE[i + 1]
        self._icon_GROUP[i] = self._icon_GROUP[i + 1]
        self._icon_SYNC[i] = self._icon_SYNC[i + 1]
    end

    -- Remove the last element
    local n = #self._icon_X
    self._icon_X[n] = nil
    self._icon_Y[n] = nil
    self._icon_TYPE[n] = nil
    self._icon_SIZE[n] = nil
    self._icon_GROUP[n] = nil
    self._icon_SYNC[n] = nil

    if self.TriggerEvent then
        self:TriggerEvent("OnIconDeleted", index)
    end

    return self
end

--- Delete all icons in a specific group
-- @param groupId number - Group identifier
-- @return self - For method chaining
function LoolibCanvasIconMixin:DeleteIconsByGroup(groupId)
    local newX, newY, newType, newSize, newGroup, newSync =
        {}, {}, {}, {}, {}, {}

    -- Build new arrays excluding the specified group
    for i = 1, #self._icon_X do
        if self._icon_GROUP[i] ~= groupId then
            local n = #newX + 1
            newX[n] = self._icon_X[i]
            newY[n] = self._icon_Y[i]
            newType[n] = self._icon_TYPE[i]
            newSize[n] = self._icon_SIZE[i]
            newGroup[n] = self._icon_GROUP[i]
            newSync[n] = self._icon_SYNC[i]
        end
    end

    -- Replace arrays
    self._icon_X = newX
    self._icon_Y = newY
    self._icon_TYPE = newType
    self._icon_SIZE = newSize
    self._icon_GROUP = newGroup
    self._icon_SYNC = newSync

    if self.TriggerEvent then
        self:TriggerEvent("OnIconsCleared")
    end

    return self
end

--[[--------------------------------------------------------------------
    Icon Movement
----------------------------------------------------------------------]]

--- Move all icons in a group by a delta offset
-- @param groupId number - Group identifier
-- @param deltaX number - X offset to apply
-- @param deltaY number - Y offset to apply
-- @return self - For method chaining
function LoolibCanvasIconMixin:MoveIconsByGroup(groupId, deltaX, deltaY)
    for i = 1, #self._icon_X do
        if self._icon_GROUP[i] == groupId then
            self._icon_X[i] = self._icon_X[i] + deltaX
            self._icon_Y[i] = self._icon_Y[i] + deltaY
        end
    end

    if self.TriggerEvent then
        self:TriggerEvent("OnIconsMoved", groupId)
    end

    return self
end

--- Move a single icon to a new position
-- @param index number - Icon index
-- @param x number - New X coordinate
-- @param y number - New Y coordinate
-- @return self - For method chaining
function LoolibCanvasIconMixin:MoveIcon(index, x, y)
    if not self._icon_X[index] then return self end

    self._icon_X[index] = x
    self._icon_Y[index] = y

    if self.TriggerEvent then
        self:TriggerEvent("OnIconMoved", index)
    end

    return self
end

--[[--------------------------------------------------------------------
    Icon Hit Testing
----------------------------------------------------------------------]]

--- Find an icon at a specific position
-- Searches from top to bottom (last drawn = highest priority)
-- @param x number - X coordinate (canvas space)
-- @param y number - Y coordinate (canvas space)
-- @param tolerance number - Additional hit area padding (default 12)
-- @return number|nil - Icon index or nil if no icon found
function LoolibCanvasIconMixin:FindIconAt(x, y, tolerance)
    tolerance = tolerance or 12

    -- Search from end to start (last drawn icons have priority)
    for i = #self._icon_X, 1, -1 do
        local ix, iy = self._icon_X[i], self._icon_Y[i]
        local size = self._icon_SIZE[i] / 2

        -- Check if point is within icon bounds + tolerance
        if math.abs(x - ix) < size + tolerance and
           math.abs(y - iy) < size + tolerance then
            return i
        end
    end

    return nil
end

--- Get all icons within a rectangular region
-- @param x1 number - Top-left X coordinate
-- @param y1 number - Top-left Y coordinate
-- @param x2 number - Bottom-right X coordinate
-- @param y2 number - Bottom-right Y coordinate
-- @return table - Array of icon indices
function LoolibCanvasIconMixin:FindIconsInRect(x1, y1, x2, y2)
    local result = {}

    -- Normalize coordinates
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)

    for i = 1, #self._icon_X do
        local x, y = self._icon_X[i], self._icon_Y[i]
        if x >= minX and x <= maxX and y >= minY and y <= maxY then
            table.insert(result, i)
        end
    end

    return result
end

--[[--------------------------------------------------------------------
    Serialization

    Compact serialization format for saving and network sync:
    - Omits default values to reduce size
    - Uses short key names (x, y, t, s, g)
    - Array format for efficient encoding
----------------------------------------------------------------------]]

--- Serialize all icons to a compact table format
-- @return table - Array of icon data tables {x, y, t, s, g}
function LoolibCanvasIconMixin:SerializeIcons()
    local data = {}
    for i = 1, #self._icon_X do
        data[i] = {
            x = self._icon_X[i],
            y = self._icon_Y[i],
            t = self._icon_TYPE[i],
            s = self._icon_SIZE[i],
            g = self._icon_GROUP[i],
        }
    end
    return data
end

--- Deserialize icons from a compact table format
-- Clears existing icons and replaces with deserialized data
-- @param data table - Array of icon data tables
-- @return self - For method chaining
function LoolibCanvasIconMixin:DeserializeIcons(data)
    self:ClearIcons()
    if not data then return self end

    for i, icon in ipairs(data) do
        self._icon_X[i] = icon.x
        self._icon_Y[i] = icon.y
        self._icon_TYPE[i] = icon.t or 1
        self._icon_SIZE[i] = icon.s or 24
        self._icon_GROUP[i] = icon.g or 0
        self._icon_SYNC[i] = i
    end

    self._nextSyncId = #data + 1

    if self.TriggerEvent then
        self:TriggerEvent("OnIconsLoaded")
    end

    return self
end

--[[--------------------------------------------------------------------
    Utility Functions
----------------------------------------------------------------------]]

--- Get the human-readable name for an icon type
-- @param iconType number - Icon type constant (1-25)
-- @return string - Icon type name or "UNKNOWN"
function LoolibCanvasIconMixin:GetIconName(iconType)
    for name, value in pairs(LOOLIB_ICON_TYPES) do
        if value == iconType then
            return name
        end
    end
    return "UNKNOWN"
end

--- Get all icons in a specific group
-- @param groupId number - Group identifier
-- @return table - Array of icon indices
function LoolibCanvasIconMixin:GetIconsInGroup(groupId)
    local result = {}
    for i = 1, #self._icon_X do
        if self._icon_GROUP[i] == groupId then
            table.insert(result, i)
        end
    end
    return result
end

--- Update an icon's properties
-- @param index number - Icon index
-- @param properties table - Properties to update {iconType?, size?, group?}
-- @return self - For method chaining
function LoolibCanvasIconMixin:UpdateIcon(index, properties)
    if not self._icon_X[index] then return self end

    if properties.iconType then
        self._icon_TYPE[index] = properties.iconType
    end
    if properties.size then
        self._icon_SIZE[index] = math.max(12, math.min(64, properties.size))
    end
    if properties.group ~= nil then
        self._icon_GROUP[index] = properties.group
    end

    if self.TriggerEvent then
        self:TriggerEvent("OnIconUpdated", index)
    end

    return self
end

--[[--------------------------------------------------------------------
    Factory and Module Registration
----------------------------------------------------------------------]]

--- Create a new icon manager instance
-- @return table - New icon manager with LoolibCanvasIconMixin applied
function LoolibCreateCanvasIcon()
    local iconManager = {}
    LoolibMixin(iconManager, LoolibCanvasIconMixin)
    iconManager:OnLoad()
    return iconManager
end

-- Register with Loolib module system
local CanvasIcon = Loolib:RegisterModule("CanvasIcon", {
    Mixin = LoolibCanvasIconMixin,
    TYPES = LOOLIB_ICON_TYPES,
    TEXTURES = LOOLIB_ICON_TEXTURES,
    Create = LoolibCreateCanvasIcon,
})

-- Also register in UI.Canvas namespace
local UI = Loolib:GetOrCreateModule("UI")
UI.Canvas = UI.Canvas or {}
UI.Canvas.Icon = CanvasIcon
