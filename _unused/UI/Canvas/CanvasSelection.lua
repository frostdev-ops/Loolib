--[[----------------------------------------------------------------------------
    Loolib - Canvas Selection System

    Handles selecting canvas elements - single click selection, shift-click
    multi-select, and lasso/rectangle selection. Selected elements can then be
    moved, deleted, or grouped.

    Features:
        - Single click selection
        - Shift/Ctrl multi-select
        - Rectangle selection (click-drag)
        - Selection bounds calculation
        - Move selected elements
        - Delete selected elements
        - Group selection support
        - Hit testing across all element types

    Usage:
        local selection = LoolibCreateCanvasSelection()
        selection:SetElementManagers(brush, shape, text, icon, image)

        -- Single selection
        selection:HandleClick(100, 200, false, false)

        -- Multi-select
        selection:HandleClick(150, 250, true, false)

        -- Rectangle selection
        selection:StartRectangleSelection(50, 50)
        selection:UpdateRectangleSelection(200, 200)
        selection:FinishRectangleSelection(200, 200, false)

        -- Manipulate selection
        selection:MoveSelection(10, 10)
        selection:DeleteSelection()

        -- Query selection
        local selected = selection:GetSelectedElements()
        local count = selection:GetSelectionCount()
        local x, y, w, h = selection:GetSelectionBounds()

    Dependencies:
        - Loolib.lua (LibStub registration)
        - Mixin.lua (LoolibMixin)
        - CanvasBrush.lua, CanvasShape.lua, CanvasText.lua, CanvasIcon.lua, CanvasImage.lua

    Events:
        OnElementSelected(elementType, index) - Element added to selection
        OnElementDeselected(elementType, index) - Element removed from selection
        OnSelectionCleared() - All selection cleared
        OnSelectionStarted(selectionType) - Rectangle/lasso selection started
        OnSelectionUpdated(x1, y1, x2, y2) - Rectangle selection updated
        OnSelectionFinished() - Rectangle/lasso selection completed
        OnSelectionCancelled() - Selection operation cancelled
        OnSelectionMoved(deltaX, deltaY) - Selected elements moved
        OnSelectionDeleted() - Selected elements deleted

    Author: James Kueller
    License: All Rights Reserved
    Created: 2025-12-06
----------------------------------------------------------------------------]]--

local LOOLIB_VERSION = 1
local Loolib = LibStub and LibStub("Loolib", true)
if not Loolib then return end

--[[----------------------------------------------------------------------------
    LoolibCanvasSelectionMixin

    Mixin providing canvas element selection functionality. Supports single and
    multi-select, rectangle selection, and bulk operations on selected elements.

    @class LoolibCanvasSelectionMixin
    @field _selectedElements table Array of selected elements {type, index}
    @field _selectionMode string Current selection mode ("single", "multi", "lasso")
    @field _isSelecting boolean Whether rectangle/lasso selection is in progress
    @field _selectionStart table Selection start coordinates {x, y}
    @field _selectionEnd table Selection end coordinates {x, y}
    @field _selectionType string Selection type ("rectangle" or "lasso")
    @field _lassoPoints table Array of lasso selection points
    @field _brushManager table Reference to canvas brush manager
    @field _shapeManager table Reference to canvas shape manager
    @field _textManager table Reference to canvas text manager
    @field _iconManager table Reference to canvas icon manager
    @field _imageManager table Reference to canvas image manager
----------------------------------------------------------------------------]]--
local LoolibCanvasSelectionMixin = {}

--[[----------------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------------]]--

---Initialize the selection manager with default settings.
---Called automatically by LoolibCreateCanvasSelection().
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:OnLoad()
    -- Selection state
    self._selectedElements = {}  -- { {type="icon", index=5}, {type="text", index=2}, ... }
    self._selectionMode = "single"  -- "single", "multi", "lasso"

    -- Lasso/rectangle selection state
    self._isSelecting = false
    self._selectionStart = nil
    self._selectionEnd = nil
    self._selectionType = nil  -- "rectangle" or "lasso"
    self._lassoPoints = {}

    -- Element managers (set by canvas frame)
    self._brushManager = nil
    self._shapeManager = nil
    self._textManager = nil
    self._iconManager = nil
    self._imageManager = nil

    return self
end

--[[----------------------------------------------------------------------------
    Manager Setup
----------------------------------------------------------------------------]]--

---Set element managers for selection operations.
---@param brush table Canvas brush manager
---@param shape table Canvas shape manager
---@param text table Canvas text manager
---@param icon table Canvas icon manager
---@param image table Canvas image manager
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:SetElementManagers(brush, shape, text, icon, image)
    self._brushManager = brush
    self._shapeManager = shape
    self._textManager = text
    self._iconManager = icon
    self._imageManager = image
    return self
end

--[[----------------------------------------------------------------------------
    Selection Mode
----------------------------------------------------------------------------]]--

---Set the selection mode.
---@param mode string Selection mode: "single", "multi", or "lasso"
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:SetSelectionMode(mode)
    assert(mode == "single" or mode == "multi" or mode == "lasso", "Invalid selection mode")
    self._selectionMode = mode
    return self
end

---Get the current selection mode.
---@return string mode Current selection mode
function LoolibCanvasSelectionMixin:GetSelectionMode()
    return self._selectionMode
end

--[[----------------------------------------------------------------------------
    Single Element Selection
----------------------------------------------------------------------------]]--

---Select a single element.
---@param elementType string Element type ("icon", "text", "image", "shape", "brush")
---@param index number Element index
---@param addToSelection boolean If true, add to existing selection; if false, clear first
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:SelectElement(elementType, index, addToSelection)
    if not addToSelection then
        self:ClearSelection()
    end

    -- Check if already selected
    for i, sel in ipairs(self._selectedElements) do
        if sel.type == elementType and sel.index == index then
            return self  -- Already selected
        end
    end

    table.insert(self._selectedElements, {
        type = elementType,
        index = index,
    })

    if self.TriggerEvent then
        self:TriggerEvent("OnElementSelected", elementType, index)
    end

    return self
end

---Deselect a single element.
---@param elementType string Element type
---@param index number Element index
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:DeselectElement(elementType, index)
    for i = #self._selectedElements, 1, -1 do
        local sel = self._selectedElements[i]
        if sel.type == elementType and sel.index == index then
            table.remove(self._selectedElements, i)

            if self.TriggerEvent then
                self:TriggerEvent("OnElementDeselected", elementType, index)
            end
            break
        end
    end
    return self
end

---Toggle element selection state.
---@param elementType string Element type
---@param index number Element index
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:ToggleElementSelection(elementType, index)
    if self:IsElementSelected(elementType, index) then
        return self:DeselectElement(elementType, index)
    else
        return self:SelectElement(elementType, index, true)
    end
end

---Clear all selected elements.
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:ClearSelection()
    local hadSelection = #self._selectedElements > 0
    self._selectedElements = {}

    if hadSelection and self.TriggerEvent then
        self:TriggerEvent("OnSelectionCleared")
    end

    return self
end

--[[----------------------------------------------------------------------------
    Selection Queries
----------------------------------------------------------------------------]]--

---Check if an element is currently selected.
---@param elementType string Element type
---@param index number Element index
---@return boolean isSelected True if element is selected
function LoolibCanvasSelectionMixin:IsElementSelected(elementType, index)
    for _, sel in ipairs(self._selectedElements) do
        if sel.type == elementType and sel.index == index then
            return true
        end
    end
    return false
end

---Get all selected elements.
---@return table selectedElements Array of {type, index} tables
function LoolibCanvasSelectionMixin:GetSelectedElements()
    return self._selectedElements
end

---Get the number of selected elements.
---@return number count Selection count
function LoolibCanvasSelectionMixin:GetSelectionCount()
    return #self._selectedElements
end

---Check if any elements are selected.
---@return boolean hasSelection True if selection is not empty
function LoolibCanvasSelectionMixin:HasSelection()
    return #self._selectedElements > 0
end

--[[----------------------------------------------------------------------------
    Hit Testing
----------------------------------------------------------------------------]]--

---Find the topmost element at a given position.
---Checks in reverse render order: images, icons, text, shapes, brush.
---@param x number X coordinate
---@param y number Y coordinate
---@return string|nil elementType Element type or nil if none found
---@return number|nil index Element index or nil if none found
function LoolibCanvasSelectionMixin:FindElementAt(x, y)
    -- Check in reverse order (topmost first): images, icons, text, shapes
    -- Dots/brush strokes are usually not individually selectable

    if self._imageManager then
        local index = self._imageManager:FindImageAt(x, y)
        if index then return "image", index end
    end

    if self._iconManager then
        local index = self._iconManager:FindIconAt(x, y)
        if index then return "icon", index end
    end

    if self._textManager then
        local index = self._textManager:FindTextAt(x, y)
        if index then return "text", index end
    end

    if self._shapeManager then
        -- Note: Shape hit testing would need to be implemented in CanvasShape
        -- for more complex shapes (lines, circles, etc.)
        -- For now, we skip shapes as they don't have FindShapeAt
    end

    return nil, nil
end

--[[----------------------------------------------------------------------------
    Click Handler
----------------------------------------------------------------------------]]--

---Handle a click event, selecting or deselecting elements.
---@param x number X coordinate
---@param y number Y coordinate
---@param isShiftDown boolean Whether Shift key is pressed
---@param isCtrlDown boolean Whether Ctrl key is pressed
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:HandleClick(x, y, isShiftDown, isCtrlDown)
    local elementType, index = self:FindElementAt(x, y)

    if elementType then
        if isShiftDown or isCtrlDown then
            self:ToggleElementSelection(elementType, index)
        else
            self:SelectElement(elementType, index, false)
        end
    else
        if not isShiftDown and not isCtrlDown then
            self:ClearSelection()
        end
    end

    return self
end

--[[----------------------------------------------------------------------------
    Rectangle Selection
----------------------------------------------------------------------------]]--

---Start a rectangle selection operation.
---@param x number X coordinate
---@param y number Y coordinate
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:StartRectangleSelection(x, y)
    self._isSelecting = true
    self._selectionType = "rectangle"
    self._selectionStart = { x = x, y = y }
    self._selectionEnd = { x = x, y = y }

    if self.TriggerEvent then
        self:TriggerEvent("OnSelectionStarted", "rectangle")
    end

    return self
end

---Update the rectangle selection endpoint.
---@param x number X coordinate
---@param y number Y coordinate
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:UpdateRectangleSelection(x, y)
    if not self._isSelecting or self._selectionType ~= "rectangle" then
        return self
    end

    self._selectionEnd = { x = x, y = y }

    if self.TriggerEvent then
        self:TriggerEvent("OnSelectionUpdated",
            self._selectionStart.x, self._selectionStart.y,
            x, y)
    end

    return self
end

---Finish the rectangle selection and select all elements within bounds.
---@param x number Final X coordinate
---@param y number Final Y coordinate
---@param addToSelection boolean If true, add to existing selection
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:FinishRectangleSelection(x, y, addToSelection)
    if not self._isSelecting then return self end

    self._isSelecting = false
    self._selectionEnd = { x = x, y = y }

    -- Calculate bounds
    local x1 = math.min(self._selectionStart.x, x)
    local y1 = math.min(self._selectionStart.y, y)
    local x2 = math.max(self._selectionStart.x, x)
    local y2 = math.max(self._selectionStart.y, y)

    if not addToSelection then
        self:ClearSelection()
    end

    -- Select all elements within bounds
    self:SelectElementsInRect(x1, y1, x2, y2)

    self._selectionStart = nil
    self._selectionEnd = nil
    self._selectionType = nil

    if self.TriggerEvent then
        self:TriggerEvent("OnSelectionFinished")
    end

    return self
end

---Select all elements within a rectangular area.
---@param x1 number Left X coordinate
---@param y1 number Top Y coordinate
---@param x2 number Right X coordinate
---@param y2 number Bottom Y coordinate
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:SelectElementsInRect(x1, y1, x2, y2)
    -- Check icons
    if self._iconManager then
        for i = 1, self._iconManager:GetIconCount() do
            local icon = self._iconManager:GetIcon(i)
            if icon and icon.x >= x1 and icon.x <= x2 and
               icon.y >= y1 and icon.y <= y2 then
                self:SelectElement("icon", i, true)
            end
        end
    end

    -- Check text
    if self._textManager then
        for i = 1, self._textManager:GetTextCount() do
            local text = self._textManager:GetText(i)
            if text and text.x >= x1 and text.x <= x2 and
               text.y >= y1 and text.y <= y2 then
                self:SelectElement("text", i, true)
            end
        end
    end

    -- Check images (check center point)
    if self._imageManager then
        for i = 1, self._imageManager:GetImageCount() do
            local img = self._imageManager:GetImage(i)
            if img then
                -- Check if image center is in rect
                local cx = (img.x1 + img.x2) / 2
                local cy = (img.y1 + img.y2) / 2
                if cx >= x1 and cx <= x2 and cy >= y1 and cy <= y2 then
                    self:SelectElement("image", i, true)
                end
            end
        end
    end

    return self
end

---Cancel an in-progress selection operation.
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:CancelSelection()
    self._isSelecting = false
    self._selectionStart = nil
    self._selectionEnd = nil
    self._selectionType = nil
    self._lassoPoints = {}

    if self.TriggerEvent then
        self:TriggerEvent("OnSelectionCancelled")
    end

    return self
end

--[[----------------------------------------------------------------------------
    Selection Bounds
----------------------------------------------------------------------------]]--

---Get the bounding box of all selected elements.
---@return number|nil x Left X coordinate or nil if no selection
---@return number|nil y Top Y coordinate or nil if no selection
---@return number|nil width Bounding box width or nil if no selection
---@return number|nil height Bounding box height or nil if no selection
function LoolibCanvasSelectionMixin:GetSelectionBounds()
    if #self._selectedElements == 0 then return nil end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for _, sel in ipairs(self._selectedElements) do
        local x, y, w, h = self:GetElementBounds(sel.type, sel.index)
        if x then
            minX = math.min(minX, x)
            minY = math.min(minY, y)
            maxX = math.max(maxX, x + (w or 0))
            maxY = math.max(maxY, y + (h or 0))
        end
    end

    if minX == math.huge then return nil end
    return minX, minY, maxX - minX, maxY - minY
end

---Get the bounding box of a single element.
---@param elementType string Element type
---@param index number Element index
---@return number|nil x Left X coordinate or nil if not found
---@return number|nil y Top Y coordinate or nil if not found
---@return number|nil width Element width or nil if not found
---@return number|nil height Element height or nil if not found
function LoolibCanvasSelectionMixin:GetElementBounds(elementType, index)
    if elementType == "icon" and self._iconManager then
        local icon = self._iconManager:GetIcon(index)
        if icon then
            return icon.x - icon.size/2, icon.y - icon.size/2, icon.size, icon.size
        end
    elseif elementType == "text" and self._textManager then
        local text = self._textManager:GetText(index)
        if text then
            -- Text bounds are approximate - actual width depends on string content
            -- This is a reasonable estimate for selection bounds
            return text.x, text.y, 100, text.size
        end
    elseif elementType == "image" and self._imageManager then
        local img = self._imageManager:GetImage(index)
        if img then
            return img.x1, img.y1, img.x2 - img.x1, img.y2 - img.y1
        end
    elseif elementType == "shape" and self._shapeManager then
        -- Shapes would need bounds calculation based on their type
        -- For now, return nil as shapes may have complex bounds
        return nil
    end
    return nil
end

--[[----------------------------------------------------------------------------
    Selection Manipulation
----------------------------------------------------------------------------]]--

---Move all selected elements by a delta offset.
---@param deltaX number X offset
---@param deltaY number Y offset
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:MoveSelection(deltaX, deltaY)
    for _, sel in ipairs(self._selectedElements) do
        if sel.type == "icon" and self._iconManager then
            local icon = self._iconManager:GetIcon(sel.index)
            if icon then
                self._iconManager:MoveIcon(sel.index, icon.x + deltaX, icon.y + deltaY)
            end
        elseif sel.type == "text" and self._textManager then
            local text = self._textManager:GetText(sel.index)
            if text then
                self._textManager:MoveText(sel.index, text.x + deltaX, text.y + deltaY)
            end
        elseif sel.type == "image" and self._imageManager then
            self._imageManager:MoveImage(sel.index, deltaX, deltaY)
        end
    end

    if self.TriggerEvent then
        self:TriggerEvent("OnSelectionMoved", deltaX, deltaY)
    end

    return self
end

---Delete all selected elements.
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:DeleteSelection()
    if #self._selectedElements == 0 then return self end

    -- Group elements by type for efficient deletion
    local toDelete = {
        icon = {},
        text = {},
        image = {},
        shape = {},
        brush = {},
    }

    for _, sel in ipairs(self._selectedElements) do
        table.insert(toDelete[sel.type], sel.index)
    end

    -- Sort indices in descending order to avoid index shifting issues
    for _, indices in pairs(toDelete) do
        table.sort(indices, function(a, b) return a > b end)
    end

    -- Delete in reverse index order
    for _, index in ipairs(toDelete.icon) do
        if self._iconManager then
            self._iconManager:DeleteIcon(index)
        end
    end

    for _, index in ipairs(toDelete.text) do
        if self._textManager then
            self._textManager:DeleteText(index)
        end
    end

    for _, index in ipairs(toDelete.image) do
        if self._imageManager then
            self._imageManager:DeleteImage(index)
        end
    end

    -- Clear selection
    self:ClearSelection()

    if self.TriggerEvent then
        self:TriggerEvent("OnSelectionDeleted")
    end

    return self
end

--[[----------------------------------------------------------------------------
    Group Selection
----------------------------------------------------------------------------]]--

---Select all elements in a group.
---@param groupId number Group ID to select
---@param addToSelection boolean If true, add to existing selection
---@return LoolibCanvasSelectionMixin self For method chaining
function LoolibCanvasSelectionMixin:SelectGroup(groupId, addToSelection)
    if not addToSelection then
        self:ClearSelection()
    end

    -- Select all icons in group
    if self._iconManager then
        for i = 1, self._iconManager:GetIconCount() do
            local icon = self._iconManager:GetIcon(i)
            if icon and icon.group == groupId then
                self:SelectElement("icon", i, true)
            end
        end
    end

    -- Select all text in group
    if self._textManager then
        for i = 1, self._textManager:GetTextCount() do
            local text = self._textManager:GetText(i)
            if text and text.group == groupId then
                self:SelectElement("text", i, true)
            end
        end
    end

    -- Select all images in group
    if self._imageManager then
        for i = 1, self._imageManager:GetImageCount() do
            local img = self._imageManager:GetImage(i)
            if img and img.group == groupId then
                self:SelectElement("image", i, true)
            end
        end
    end

    return self
end

---Assign all selected elements to a group.
---Note: This requires SetIconGroup, SetTextGroup, SetImageGroup methods
---to be implemented in the respective element managers.
---@param groupId number Group ID to assign
---@return LoolibCanvasSelectionMixin self For method chaining
--[[
function LoolibCanvasSelectionMixin:SetSelectionGroup(groupId)
    for _, sel in ipairs(self._selectedElements) do
        if sel.type == "icon" and self._iconManager then
            self._iconManager:SetIconGroup(sel.index, groupId)
        elseif sel.type == "text" and self._textManager then
            self._textManager:SetTextGroup(sel.index, groupId)
        elseif sel.type == "image" and self._imageManager then
            self._imageManager:SetImageGroup(sel.index, groupId)
        end
    end

    return self
end
--]]

--[[----------------------------------------------------------------------------
    Factory Function and Module Registration
----------------------------------------------------------------------------]]--

---Factory function to create a new canvas selection manager.
---@return LoolibCanvasSelectionMixin selection New selection manager instance
local function LoolibCreateCanvasSelection()
    local selection = {}
    LoolibMixin(selection, LoolibCanvasSelectionMixin)
    selection:OnLoad()
    return selection
end

-- Register with Loolib
Loolib:RegisterModule("CanvasSelection", {
    Mixin = LoolibCanvasSelectionMixin,
    Create = LoolibCreateCanvasSelection,
})
