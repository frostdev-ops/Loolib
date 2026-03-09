--[[----------------------------------------------------------------------------
    Loolib - Canvas Image System

    Handles image/texture placement on canvas objects. Users can place images
    with custom texture paths, size them by dragging corners, and adjust
    transparency. Images are stored in parallel arrays for performance and
    support grouping for bulk operations.

    Usage:
        local imageManager = LoolibCreateCanvasImage()
        imageManager:SetDefaultPath("Interface\\Icons\\Achievement_BG_killflag_alterac")

        -- Interactive placement
        imageManager:StartPlacement(100, 100)
        imageManager:UpdatePlacement(164, 164)
        local index = imageManager:FinishPlacement(164, 164)

        -- Direct placement
        local idx = imageManager:AddImage(50, 50, 150, 150, "Interface\\Icons\\INV_Misc_QuestionMark", 0.8, 1)

        -- Query and modify
        local image = imageManager:GetImage(idx)
        imageManager:SetImageAlpha(idx, 0.5)
        imageManager:SetImagePath(idx, "Interface\\Icons\\Achievement_BG_killflag_horde")

        -- Hit testing
        local hitIndex = imageManager:FindImageAt(100, 100)
        local cornerIndex, corner = imageManager:FindImageCornerAt(150, 150, 8)

        -- Serialization
        local data = imageManager:SerializeImages()
        imageManager:DeserializeImages(data)

    Dependencies:
        - Loolib.lua (LibStub registration)
        - Mixin.lua (LoolibMixin)

    Events:
        OnImagePlacementStart(x, y) - Triggered when placement begins
        OnImagePlacementUpdate(x1, y1, x2, y2) - Triggered during placement drag
        OnImageAdded(index) - Triggered when image is added
        OnImageUpdated(index) - Triggered when image properties change
        OnImageDeleted(index) - Triggered when image is removed
        OnImagesCleared() - Triggered when all images are cleared

    Author: James Kueller
    License: All Rights Reserved
    Created: 2025-12-06
----------------------------------------------------------------------------]]--

---@class LoolibCanvasImageMixin
---@field _defaultPath string Default texture path for new images
---@field _defaultAlpha number Default alpha value for new images (0.1-1.0)
---@field _currentGroup number Current group ID for new images
---@field _isPlacingImage boolean Whether interactive placement is in progress
---@field _previewX1 number? Preview image top-left X coordinate
---@field _previewY1 number? Preview image top-left Y coordinate
---@field _previewX2 number? Preview image bottom-right X coordinate
---@field _previewY2 number? Preview image bottom-right Y coordinate
---@field _previewPath string? Preview image texture path
---@field _image_X1 number[] Top-left X coordinates of all images
---@field _image_Y1 number[] Top-left Y coordinates of all images
---@field _image_X2 number[] Bottom-right X coordinates of all images
---@field _image_Y2 number[] Bottom-right Y coordinates of all images
---@field _image_PATH string[] Texture paths of all images
---@field _image_ALPHA number[] Alpha values of all images
---@field _image_GROUP number[] Group IDs of all images
---@field _image_SYNC number[] Sync IDs of all images (for network sync)
---@field _nextSyncId number Next available sync ID
local LoolibCanvasImageMixin = {}

---Initialize the image manager with default settings.
---Called automatically by LoolibCreateCanvasImage().
function LoolibCanvasImageMixin:OnLoad()
    -- Default settings for new images
    self._defaultPath = "Interface\\Icons\\INV_Misc_QuestionMark"
    self._defaultAlpha = 1.0
    self._currentGroup = 0

    -- Interactive placement state
    self._isPlacingImage = false
    self._previewX1 = nil
    self._previewY1 = nil
    self._previewX2 = nil
    self._previewY2 = nil
    self._previewPath = nil

    -- Image storage (parallel arrays for performance)
    -- Images are defined by two corner points (x1,y1) and (x2,y2)
    -- for flexible sizing and rotation support in the future
    self._image_X1 = {}      -- Top-left X coordinate
    self._image_Y1 = {}      -- Top-left Y coordinate
    self._image_X2 = {}      -- Bottom-right X coordinate
    self._image_Y2 = {}      -- Bottom-right Y coordinate
    self._image_PATH = {}    -- Texture path (e.g., "Interface\\Icons\\...")
    self._image_ALPHA = {}   -- Transparency (0.1-1.0)
    self._image_GROUP = {}   -- Group ID for bulk operations
    self._image_SYNC = {}    -- Sync ID for network synchronization

    self._nextSyncId = 1
end

--------------------------------------------------------------------------------
-- Default Settings
--------------------------------------------------------------------------------

---Set the default texture path for newly created images.
---@param path string Texture path (e.g., "Interface\\Icons\\INV_Misc_QuestionMark")
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:SetDefaultPath(path)
    self._defaultPath = path or "Interface\\Icons\\INV_Misc_QuestionMark"
    return self
end

---Get the default texture path for new images.
---@return string path Default texture path
function LoolibCanvasImageMixin:GetDefaultPath()
    return self._defaultPath
end

---Set the default alpha (transparency) for newly created images.
---@param alpha number Alpha value between 0.1 and 1.0 (clamped if outside range)
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:SetDefaultAlpha(alpha)
    self._defaultAlpha = math.max(0.1, math.min(1, alpha))
    return self
end

---Get the default alpha value for new images.
---@return number alpha Default alpha (0.1-1.0)
function LoolibCanvasImageMixin:GetDefaultAlpha()
    return self._defaultAlpha
end

---Set the current group ID for newly created images.
---Images in the same group can be moved or deleted together.
---@param groupId number Group ID (0 = no group)
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:SetCurrentGroup(groupId)
    self._currentGroup = groupId or 0
    return self
end

--------------------------------------------------------------------------------
-- Interactive Image Placement (Click-Drag)
--------------------------------------------------------------------------------

---Start interactive image placement mode.
---Call this when the user clicks to begin placing an image.
---@param x number Starting X coordinate
---@param y number Starting Y coordinate
---@param path? string Optional texture path (uses default if nil)
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:StartPlacement(x, y, path)
    self._isPlacingImage = true
    self._previewX1 = x
    self._previewY1 = y
    self._previewX2 = x
    self._previewY2 = y
    self._previewPath = path or self._defaultPath

    if self.TriggerEvent then
        self:TriggerEvent("OnImagePlacementStart", x, y)
    end

    return self
end

---Update the preview image size during placement.
---Call this as the user drags to resize the image.
---@param x number Current X coordinate
---@param y number Current Y coordinate
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:UpdatePlacement(x, y)
    if not self._isPlacingImage then return self end

    self._previewX2 = x
    self._previewY2 = y

    if self.TriggerEvent then
        self:TriggerEvent("OnImagePlacementUpdate",
            self._previewX1, self._previewY1, x, y)
    end

    return self
end

---Finish interactive placement and create the image.
---Call this when the user releases the mouse button.
---If the dragged size is too small, creates a default 64x64 image.
---@param x number Final X coordinate
---@param y number Final Y coordinate
---@return number? index Index of the created image, or nil if placement wasn't active
function LoolibCanvasImageMixin:FinishPlacement(x, y)
    if not self._isPlacingImage then return nil end

    self._isPlacingImage = false

    -- Ensure minimum size (if drag was too small, use default 64x64)
    local minSize = 20
    local dx = math.abs(x - self._previewX1)
    local dy = math.abs(y - self._previewY1)

    if dx < minSize and dy < minSize then
        -- Default to 64x64 square
        x = self._previewX1 + 64
        y = self._previewY1 + 64
    end

    -- Normalize corners so (x1,y1) is top-left and (x2,y2) is bottom-right
    local x1, y1 = math.min(self._previewX1, x), math.min(self._previewY1, y)
    local x2, y2 = math.max(self._previewX1, x), math.max(self._previewY1, y)

    local index = self:_AddImage(
        x1, y1, x2, y2,
        self._previewPath,
        self._defaultAlpha,
        self._currentGroup
    )

    -- Clear preview state
    self._previewX1 = nil
    self._previewY1 = nil
    self._previewX2 = nil
    self._previewY2 = nil
    self._previewPath = nil

    return index
end

---Cancel interactive placement without creating an image.
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:CancelPlacement()
    self._isPlacingImage = false
    self._previewX1 = nil
    self._previewY1 = nil
    self._previewX2 = nil
    self._previewY2 = nil
    self._previewPath = nil
    return self
end

---Check if interactive placement is in progress.
---@return boolean isPlacing True if placement mode is active
function LoolibCanvasImageMixin:IsPlacingImage()
    return self._isPlacingImage
end

---Get the current preview image data during placement.
---@return table? preview Preview image data, or nil if not placing
---@field x1 number Top-left X
---@field y1 number Top-left Y
---@field x2 number Bottom-right X
---@field y2 number Bottom-right Y
---@field path string Texture path
---@field alpha number Transparency
function LoolibCanvasImageMixin:GetPreviewImage()
    if not self._isPlacingImage then return nil end
    return {
        x1 = self._previewX1,
        y1 = self._previewY1,
        x2 = self._previewX2,
        y2 = self._previewY2,
        path = self._previewPath,
        alpha = self._defaultAlpha,
    }
end

--------------------------------------------------------------------------------
-- Image Creation and Management
--------------------------------------------------------------------------------

---Internal: Add an image to the canvas.
---Use AddImage() or AddImageAt() instead for external calls.
---@param x1 number Top-left X coordinate
---@param y1 number Top-left Y coordinate
---@param x2 number Bottom-right X coordinate
---@param y2 number Bottom-right Y coordinate
---@param path string Texture path
---@param alpha number Transparency (0.1-1.0)
---@param group number Group ID
---@return number index Index of the added image
function LoolibCanvasImageMixin:_AddImage(x1, y1, x2, y2, path, alpha, group)
    local index = #self._image_X1 + 1

    self._image_X1[index] = x1
    self._image_Y1[index] = y1
    self._image_X2[index] = x2
    self._image_Y2[index] = y2
    self._image_PATH[index] = path
    self._image_ALPHA[index] = alpha
    self._image_GROUP[index] = group
    self._image_SYNC[index] = self._nextSyncId
    self._nextSyncId = self._nextSyncId + 1

    if self.TriggerEvent then
        self:TriggerEvent("OnImageAdded", index)
    end

    return index
end

---Add an image defined by two corner points.
---@param x1 number Top-left X coordinate
---@param y1 number Top-left Y coordinate
---@param x2 number Bottom-right X coordinate
---@param y2 number Bottom-right Y coordinate
---@param path? string Texture path (uses default if nil)
---@param alpha? number Transparency (uses default if nil)
---@param group? number Group ID (uses current group if nil)
---@return number index Index of the added image
function LoolibCanvasImageMixin:AddImage(x1, y1, x2, y2, path, alpha, group)
    return self:_AddImage(
        x1, y1, x2, y2,
        path or self._defaultPath,
        alpha or self._defaultAlpha,
        group or self._currentGroup
    )
end

---Add an image at a position with explicit width and height.
---Convenience wrapper around AddImage().
---@param x number Top-left X coordinate
---@param y number Top-left Y coordinate
---@param width? number Image width in pixels (default: 64)
---@param height? number Image height in pixels (default: 64)
---@param path? string Texture path (uses default if nil)
---@param alpha? number Transparency (uses default if nil)
---@param group? number Group ID (uses current group if nil)
---@return number index Index of the added image
function LoolibCanvasImageMixin:AddImageAt(x, y, width, height, path, alpha, group)
    width = width or 64
    height = height or 64
    return self:AddImage(x, y, x + width, y + height, path, alpha, group)
end

---Get image data by index.
---@param index number Image index
---@return table? image Image data, or nil if index is invalid
---@field x1 number Top-left X
---@field y1 number Top-left Y
---@field x2 number Bottom-right X
---@field y2 number Bottom-right Y
---@field path string Texture path
---@field alpha number Transparency
---@field group number Group ID
---@field syncId number Sync ID
---@field width number Computed width
---@field height number Computed height
function LoolibCanvasImageMixin:GetImage(index)
    if not self._image_X1[index] then return nil end
    return {
        x1 = self._image_X1[index],
        y1 = self._image_Y1[index],
        x2 = self._image_X2[index],
        y2 = self._image_Y2[index],
        path = self._image_PATH[index],
        alpha = self._image_ALPHA[index],
        group = self._image_GROUP[index],
        syncId = self._image_SYNC[index],
        -- Computed properties for convenience
        width = self._image_X2[index] - self._image_X1[index],
        height = self._image_Y2[index] - self._image_Y1[index],
    }
end

---Get all images as an array.
---@return table[] images Array of image data tables
function LoolibCanvasImageMixin:GetAllImages()
    local result = {}
    for i = 1, #self._image_X1 do
        result[i] = self:GetImage(i)
    end
    return result
end

---Get the total number of images.
---@return number count Image count
function LoolibCanvasImageMixin:GetImageCount()
    return #self._image_X1
end

--------------------------------------------------------------------------------
-- Image Property Updates
--------------------------------------------------------------------------------

---Set the texture path for an image.
---@param index number Image index
---@param path string New texture path
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:SetImagePath(index, path)
    if not self._image_X1[index] then return self end
    self._image_PATH[index] = path
    if self.TriggerEvent then
        self:TriggerEvent("OnImageUpdated", index)
    end
    return self
end

---Set the alpha (transparency) for an image.
---@param index number Image index
---@param alpha number New alpha value (clamped to 0.1-1.0)
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:SetImageAlpha(index, alpha)
    if not self._image_X1[index] then return self end
    self._image_ALPHA[index] = math.max(0.1, math.min(1, alpha))
    if self.TriggerEvent then
        self:TriggerEvent("OnImageUpdated", index)
    end
    return self
end

---Set the size and position of an image by corner points.
---@param index number Image index
---@param x1 number New top-left X
---@param y1 number New top-left Y
---@param x2 number New bottom-right X
---@param y2 number New bottom-right Y
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:SetImageSize(index, x1, y1, x2, y2)
    if not self._image_X1[index] then return self end
    self._image_X1[index] = x1
    self._image_Y1[index] = y1
    self._image_X2[index] = x2
    self._image_Y2[index] = y2
    if self.TriggerEvent then
        self:TriggerEvent("OnImageUpdated", index)
    end
    return self
end

--------------------------------------------------------------------------------
-- Image Deletion
--------------------------------------------------------------------------------

---Clear all images from the canvas.
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:ClearImages()
    self._image_X1 = {}
    self._image_Y1 = {}
    self._image_X2 = {}
    self._image_Y2 = {}
    self._image_PATH = {}
    self._image_ALPHA = {}
    self._image_GROUP = {}
    self._image_SYNC = {}

    if self.TriggerEvent then
        self:TriggerEvent("OnImagesCleared")
    end

    return self
end

---Delete a single image by index.
---Shifts all subsequent images down by one index.
---@param index number Image index to delete
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:DeleteImage(index)
    if not self._image_X1[index] then return self end

    -- Shift all images after this one down by one index
    for i = index, #self._image_X1 - 1 do
        self._image_X1[i] = self._image_X1[i + 1]
        self._image_Y1[i] = self._image_Y1[i + 1]
        self._image_X2[i] = self._image_X2[i + 1]
        self._image_Y2[i] = self._image_Y2[i + 1]
        self._image_PATH[i] = self._image_PATH[i + 1]
        self._image_ALPHA[i] = self._image_ALPHA[i + 1]
        self._image_GROUP[i] = self._image_GROUP[i + 1]
        self._image_SYNC[i] = self._image_SYNC[i + 1]
    end

    -- Remove the last element
    local n = #self._image_X1
    self._image_X1[n] = nil
    self._image_Y1[n] = nil
    self._image_X2[n] = nil
    self._image_Y2[n] = nil
    self._image_PATH[n] = nil
    self._image_ALPHA[n] = nil
    self._image_GROUP[n] = nil
    self._image_SYNC[n] = nil

    if self.TriggerEvent then
        self:TriggerEvent("OnImageDeleted", index)
    end

    return self
end

---Delete all images belonging to a specific group.
---@param groupId number Group ID to delete
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:DeleteImagesByGroup(groupId)
    local newX1, newY1, newX2, newY2 = {}, {}, {}, {}
    local newPath, newAlpha, newGroup, newSync = {}, {}, {}, {}

    -- Copy all images that don't match the group
    for i = 1, #self._image_X1 do
        if self._image_GROUP[i] ~= groupId then
            local n = #newX1 + 1
            newX1[n] = self._image_X1[i]
            newY1[n] = self._image_Y1[i]
            newX2[n] = self._image_X2[i]
            newY2[n] = self._image_Y2[i]
            newPath[n] = self._image_PATH[i]
            newAlpha[n] = self._image_ALPHA[i]
            newGroup[n] = self._image_GROUP[i]
            newSync[n] = self._image_SYNC[i]
        end
    end

    -- Replace arrays with filtered versions
    self._image_X1, self._image_Y1 = newX1, newY1
    self._image_X2, self._image_Y2 = newX2, newY2
    self._image_PATH, self._image_ALPHA = newPath, newAlpha
    self._image_GROUP, self._image_SYNC = newGroup, newSync

    return self
end

--------------------------------------------------------------------------------
-- Image Movement
--------------------------------------------------------------------------------

---Move all images in a group by a delta offset.
---@param groupId number Group ID to move
---@param deltaX number X offset to add
---@param deltaY number Y offset to add
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:MoveImagesByGroup(groupId, deltaX, deltaY)
    for i = 1, #self._image_X1 do
        if self._image_GROUP[i] == groupId then
            self._image_X1[i] = self._image_X1[i] + deltaX
            self._image_Y1[i] = self._image_Y1[i] + deltaY
            self._image_X2[i] = self._image_X2[i] + deltaX
            self._image_Y2[i] = self._image_Y2[i] + deltaY
        end
    end
    return self
end

---Move a single image by a delta offset.
---@param index number Image index
---@param deltaX number X offset to add
---@param deltaY number Y offset to add
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:MoveImage(index, deltaX, deltaY)
    if not self._image_X1[index] then return self end
    self._image_X1[index] = self._image_X1[index] + deltaX
    self._image_Y1[index] = self._image_Y1[index] + deltaY
    self._image_X2[index] = self._image_X2[index] + deltaX
    self._image_Y2[index] = self._image_Y2[index] + deltaY
    return self
end

--------------------------------------------------------------------------------
-- Hit Testing
--------------------------------------------------------------------------------

---Find the topmost image at a given position.
---Searches from top to bottom (highest index first).
---@param x number X coordinate to test
---@param y number Y coordinate to test
---@return number? index Index of the hit image, or nil if no hit
function LoolibCanvasImageMixin:FindImageAt(x, y)
    -- Search from top to bottom (highest index = topmost)
    for i = #self._image_X1, 1, -1 do
        local x1, y1 = self._image_X1[i], self._image_Y1[i]
        local x2, y2 = self._image_X2[i], self._image_Y2[i]

        if x >= x1 and x <= x2 and y >= y1 and y <= y2 then
            return i
        end
    end

    return nil
end

---Find if a point is near an image corner (for resize operations).
---Searches from top to bottom and returns the first corner hit.
---@param x number X coordinate to test
---@param y number Y coordinate to test
---@param tolerance? number Hit tolerance in pixels (default: 8)
---@return number? index Image index, or nil if no corner hit
---@return string? corner Corner name ("TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"), or nil
function LoolibCanvasImageMixin:FindImageCornerAt(x, y, tolerance)
    tolerance = tolerance or 8

    -- Search from top to bottom (highest index = topmost)
    for i = #self._image_X1, 1, -1 do
        local x1, y1 = self._image_X1[i], self._image_Y1[i]
        local x2, y2 = self._image_X2[i], self._image_Y2[i]

        -- Check all 4 corners
        local corners = {
            { x = x1, y = y1, corner = "TOPLEFT" },
            { x = x2, y = y1, corner = "TOPRIGHT" },
            { x = x1, y = y2, corner = "BOTTOMLEFT" },
            { x = x2, y = y2, corner = "BOTTOMRIGHT" },
        }

        for _, c in ipairs(corners) do
            if math.abs(x - c.x) < tolerance and math.abs(y - c.y) < tolerance then
                return i, c.corner
            end
        end
    end

    return nil, nil
end

--------------------------------------------------------------------------------
-- Serialization
--------------------------------------------------------------------------------

---Serialize all images to a table for saving or network sync.
---Returns a compact format suitable for SavedVariables or addon messages.
---@return table data Serialized image data
function LoolibCanvasImageMixin:SerializeImages()
    local data = {}
    for i = 1, #self._image_X1 do
        data[i] = {
            x1 = self._image_X1[i],
            y1 = self._image_Y1[i],
            x2 = self._image_X2[i],
            y2 = self._image_Y2[i],
            p = self._image_PATH[i],  -- Shortened keys for smaller save size
            a = self._image_ALPHA[i],
            g = self._image_GROUP[i],
        }
    end
    return data
end

---Deserialize image data and replace current images.
---Clears existing images before loading.
---@param data? table Serialized image data from SerializeImages()
---@return LoolibCanvasImageMixin self For method chaining
function LoolibCanvasImageMixin:DeserializeImages(data)
    self:ClearImages()
    if not data then return self end

    for i, image in ipairs(data) do
        self._image_X1[i] = image.x1
        self._image_Y1[i] = image.y1
        self._image_X2[i] = image.x2
        self._image_Y2[i] = image.y2
        self._image_PATH[i] = image.p or "Interface\\Icons\\INV_Misc_QuestionMark"
        self._image_ALPHA[i] = image.a or 1
        self._image_GROUP[i] = image.g or 0
        self._image_SYNC[i] = i
    end
    self._nextSyncId = #data + 1

    return self
end

--------------------------------------------------------------------------------
-- Module Registration
--------------------------------------------------------------------------------

---Create a new canvas image manager instance.
---@return LoolibCanvasImageMixin imageManager New image manager
local function LoolibCreateCanvasImage()
    local imageManager = {}
    LoolibMixin(imageManager, LoolibCanvasImageMixin)
    imageManager:OnLoad()
    return imageManager
end

-- Register with Loolib module system
local Loolib = LibStub("Loolib")
Loolib:RegisterModule("CanvasImage", {
    Mixin = LoolibCanvasImageMixin,
    Create = LoolibCreateCanvasImage,
})
