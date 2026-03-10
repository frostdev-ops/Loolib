--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    CanvasHistory - Undo/Redo history system for canvas operations

    Manages undo/redo stacks for all canvas operations including adding,
    deleting, moving, and modifying elements (dots, shapes, text, icons,
    images). Supports batching multiple operations and snapshotting for
    complex undo operations like clear all.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Canvas Action Type Constants

    Defines all recordable action types for the history system.
    Each action can be undone and redone with appropriate state restoration.
----------------------------------------------------------------------]]

local LOOLIB_CANVAS_ACTION_TYPES = {
    ADD_DOT = "add_dot",
    ADD_DOTS = "add_dots",              -- Batch for strokes
    DELETE_DOTS = "delete_dots",
    ADD_SHAPE = "add_shape",
    DELETE_SHAPE = "delete_shape",
    UPDATE_SHAPE = "update_shape",
    ADD_TEXT = "add_text",
    DELETE_TEXT = "delete_text",
    UPDATE_TEXT = "update_text",
    ADD_ICON = "add_icon",
    DELETE_ICON = "delete_icon",
    MOVE_ICON = "move_icon",
    ADD_IMAGE = "add_image",
    DELETE_IMAGE = "delete_image",
    UPDATE_IMAGE = "update_image",
    MOVE_SELECTION = "move_selection",
    DELETE_SELECTION = "delete_selection",
    MOVE_GROUP = "move_group",
    DELETE_GROUP = "delete_group",
    CREATE_GROUP = "create_group",
    CLEAR_ALL = "clear_all",
}

--[[--------------------------------------------------------------------
    LoolibCanvasHistoryMixin

    Provides undo/redo functionality for canvas operations.

    Features:
    - Unlimited undo/redo with configurable history size limit
    - Batch operations to group multiple actions
    - Snapshot support for complex undo operations
    - Event triggers for UI updates
    - Recording control to prevent circular history entries

    Events Triggered:
    - OnHistoryChanged: When history state changes (new action, undo, redo)
    - OnUndo: When an undo operation completes
    - OnRedo: When a redo operation completes
    - OnHistoryCleared: When history is cleared

    Usage:
        local history = LoolibCreateCanvasHistory()
        history:SetElementManagers(brush, shape, text, icon, image)

        -- Record an action
        history:PushAction(LOOLIB_CANVAS_ACTION_TYPES.ADD_ICON, {
            x = 100, y = 100, iconType = 1, size = 32
        }, {
            index = 1  -- undoData
        })

        -- Batch multiple actions
        history:BeginBatch("Draw Stroke")
        -- ... multiple PushAction calls ...
        history:EndBatch()

        -- Undo/redo
        if history:CanUndo() then
            history:Undo()
        end
----------------------------------------------------------------------]]

local LoolibCanvasHistoryMixin = {}

--- Initialize the history system
function LoolibCanvasHistoryMixin:OnLoad()
    -- History stacks
    self._undoStack = {}
    self._redoStack = {}

    -- Configuration
    self._maxHistorySize = 100

    -- Recording state
    self._isRecording = true
    self._batchAction = nil  -- For grouping multiple operations

    -- Element managers (set via SetElementManagers)
    self._brushManager = nil
    self._shapeManager = nil
    self._textManager = nil
    self._iconManager = nil
    self._imageManager = nil
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set element managers for undo/redo operations
--- @param brush table Brush manager (LoolibCanvasBrushMixin)
--- @param shape table Shape manager (LoolibCanvasShapeMixin)
--- @param text table Text manager (LoolibCanvasTextMixin)
--- @param icon table Icon manager (LoolibCanvasIconMixin)
--- @param image table Image manager (LoolibCanvasImageMixin)
--- @return table self for chaining
function LoolibCanvasHistoryMixin:SetElementManagers(brush, shape, text, icon, image)
    self._brushManager = brush
    self._shapeManager = shape
    self._textManager = text
    self._iconManager = icon
    self._imageManager = image
    return self
end

--- Set maximum history size (number of undo steps to keep)
--- @param size number Maximum number of actions to store
--- @return table self for chaining
function LoolibCanvasHistoryMixin:SetMaxHistorySize(size)
    self._maxHistorySize = size
    return self
end

--[[--------------------------------------------------------------------
    Recording Control
----------------------------------------------------------------------]]

--- Enable or disable history recording
--- Useful to prevent circular history entries when programmatically
--- modifying canvas during undo/redo operations.
--- @param enabled boolean True to enable recording
--- @return table self for chaining
function LoolibCanvasHistoryMixin:SetRecording(enabled)
    self._isRecording = enabled
    return self
end

--- Check if history recording is enabled
--- @return boolean True if recording
function LoolibCanvasHistoryMixin:IsRecording()
    return self._isRecording
end

--[[--------------------------------------------------------------------
    Action Recording
----------------------------------------------------------------------]]

--- Push an action to the history stack
--- @param actionType string Action type from LOOLIB_CANVAS_ACTION_TYPES
--- @param data table Action data (parameters for redo)
--- @param undoData table Optional undo-specific data (parameters for undo)
--- @return table self for chaining
function LoolibCanvasHistoryMixin:PushAction(actionType, data, undoData)
    if not self._isRecording then return self end

    local action = {
        type = actionType,
        data = data,
        undoData = undoData,
        timestamp = GetTime(),
    }

    if self._batchAction then
        -- Add to current batch
        table.insert(self._batchAction.actions, action)
    else
        -- Add as standalone action
        table.insert(self._undoStack, action)

        -- Clear redo stack on new action (branching timeline)
        self._redoStack = {}

        -- Limit history size
        while #self._undoStack > self._maxHistorySize do
            table.remove(self._undoStack, 1)
        end
    end

    if self.TriggerEvent then
        self:TriggerEvent("OnHistoryChanged")
    end

    return self
end

--[[--------------------------------------------------------------------
    Batch Operations
----------------------------------------------------------------------]]

--- Begin a batch operation
--- All actions pushed until EndBatch() are grouped together and
--- undone/redone as a single unit.
--- @param batchName string Optional name for the batch
--- @return table self for chaining
function LoolibCanvasHistoryMixin:BeginBatch(batchName)
    if self._batchAction then return self end  -- Already in batch

    self._batchAction = {
        type = "batch",
        name = batchName or "Batch",
        actions = {},
    }

    return self
end

--- End the current batch operation
--- @return table self for chaining
function LoolibCanvasHistoryMixin:EndBatch()
    if not self._batchAction then return self end

    -- Only add batch if it contains actions
    if #self._batchAction.actions > 0 then
        table.insert(self._undoStack, self._batchAction)
        self._redoStack = {}

        -- Limit history size
        while #self._undoStack > self._maxHistorySize do
            table.remove(self._undoStack, 1)
        end
    end

    self._batchAction = nil

    if self.TriggerEvent then
        self:TriggerEvent("OnHistoryChanged")
    end

    return self
end

--- Cancel the current batch operation
--- Undoes all actions in the current batch and discards it.
--- @return table self for chaining
function LoolibCanvasHistoryMixin:CancelBatch()
    if self._batchAction then
        -- Undo all actions in current batch
        for i = #self._batchAction.actions, 1, -1 do
            self:_UndoAction(self._batchAction.actions[i])
        end
    end
    self._batchAction = nil
    return self
end

--[[--------------------------------------------------------------------
    Undo/Redo Operations
----------------------------------------------------------------------]]

--- Undo the last action
--- @return table self for chaining
function LoolibCanvasHistoryMixin:Undo()
    if not self:CanUndo() then return self end

    local action = table.remove(self._undoStack)

    -- Disable recording during undo to prevent circular history
    self._isRecording = false
    self:_UndoAction(action)
    self._isRecording = true

    table.insert(self._redoStack, action)

    if self.TriggerEvent then
        self:TriggerEvent("OnUndo", action.type)
        self:TriggerEvent("OnHistoryChanged")
    end

    return self
end

--- Redo the last undone action
--- @return table self for chaining
function LoolibCanvasHistoryMixin:Redo()
    if not self:CanRedo() then return self end

    local action = table.remove(self._redoStack)

    -- Disable recording during redo to prevent circular history
    self._isRecording = false
    self:_RedoAction(action)
    self._isRecording = true

    table.insert(self._undoStack, action)

    if self.TriggerEvent then
        self:TriggerEvent("OnRedo", action.type)
        self:TriggerEvent("OnHistoryChanged")
    end

    return self
end

--[[--------------------------------------------------------------------
    Internal Action Handlers
----------------------------------------------------------------------]]

--- Internal: Undo a single action
--- @param action table Action to undo
function LoolibCanvasHistoryMixin:_UndoAction(action)
    if action.type == "batch" then
        -- Undo batch in reverse order
        for i = #action.actions, 1, -1 do
            self:_UndoAction(action.actions[i])
        end
        return
    end

    local data = action.undoData or action.data

    -- Icon actions
    if action.type == LOOLIB_CANVAS_ACTION_TYPES.ADD_ICON then
        if self._iconManager then
            self._iconManager:DeleteIcon(data.index)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_ICON then
        if self._iconManager then
            self._iconManager:AddIcon(data.x, data.y, data.iconType, data.size, data.group)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.MOVE_ICON then
        if self._iconManager then
            self._iconManager:MoveIcon(data.index, data.oldX, data.oldY)
        end

    -- Text actions
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.ADD_TEXT then
        if self._textManager then
            self._textManager:DeleteText(data.index)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_TEXT then
        if self._textManager then
            self._textManager:AddText(data.x, data.y, data.text, data.size, data.color, data.group)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.UPDATE_TEXT then
        if self._textManager and data.oldText then
            self._textManager:UpdateText(data.index, data.oldText)
        end

    -- Shape actions
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.ADD_SHAPE then
        if self._shapeManager then
            self._shapeManager:DeleteShape(data.index)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_SHAPE then
        if self._shapeManager then
            self._shapeManager:AddShape(data.x1, data.y1, data.x2, data.y2,
                data.shapeType, data.color, data.size, data.alpha, data.group)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.UPDATE_SHAPE then
        if self._shapeManager and data.oldShape then
            -- Restore old shape properties
            local shape = self._shapeManager:GetShape(data.index)
            if shape then
                for k, v in pairs(data.oldShape) do
                    shape[k] = v
                end
                self._shapeManager:UpdateShape(data.index)
            end
        end

    -- Image actions
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.ADD_IMAGE then
        if self._imageManager then
            self._imageManager:DeleteImage(data.index)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_IMAGE then
        if self._imageManager then
            self._imageManager:AddImage(data.x1, data.y1, data.x2, data.y2,
                data.path, data.alpha, data.group)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.UPDATE_IMAGE then
        if self._imageManager and data.oldImage then
            -- Restore old image properties
            local image = self._imageManager:GetImage(data.index)
            if image then
                for k, v in pairs(data.oldImage) do
                    image[k] = v
                end
                self._imageManager:UpdateImage(data.index)
            end
        end

    -- Brush/dot actions
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.ADD_DOTS then
        if self._brushManager and data.snapshot then
            -- Restore brush state from snapshot before dots were added
            self._brushManager:DeserializeDots(data.snapshot)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_DOTS then
        if self._brushManager and data.snapshot then
            -- Restore brush state from snapshot before dots were deleted
            self._brushManager:DeserializeDots(data.snapshot)
        end

    -- Selection and group actions
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.MOVE_SELECTION then
        -- Move selection back
        if data.elements then
            for _, elem in ipairs(data.elements) do
                self:_MoveElement(elem.type, elem.index, -data.deltaX, -data.deltaY)
            end
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_SELECTION then
        if data.snapshot then
            self:_RestoreSnapshot(data.snapshot)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.MOVE_GROUP then
        if data.elements then
            for _, elem in ipairs(data.elements) do
                self:_MoveElement(elem.type, elem.index, -data.deltaX, -data.deltaY)
            end
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_GROUP then
        if data.snapshot then
            self:_RestoreSnapshot(data.snapshot)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.CREATE_GROUP then
        -- Remove group assignments
        if data.elements then
            for _, elem in ipairs(data.elements) do
                self:_SetElementGroup(elem.type, elem.index, nil)
            end
        end

    -- Clear all
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.CLEAR_ALL then
        -- Restore all elements from snapshot
        if data.snapshot then
            self:_RestoreSnapshot(data.snapshot)
        end
    end
end

--- Internal: Redo a single action
--- @param action table Action to redo
function LoolibCanvasHistoryMixin:_RedoAction(action)
    if action.type == "batch" then
        -- Redo batch in forward order
        for i = 1, #action.actions do
            self:_RedoAction(action.actions[i])
        end
        return
    end

    local data = action.data

    -- Icon actions
    if action.type == LOOLIB_CANVAS_ACTION_TYPES.ADD_ICON then
        if self._iconManager then
            self._iconManager:AddIcon(data.x, data.y, data.iconType, data.size, data.group)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_ICON then
        if self._iconManager then
            self._iconManager:DeleteIcon(data.index)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.MOVE_ICON then
        if self._iconManager then
            self._iconManager:MoveIcon(data.index, data.newX, data.newY)
        end

    -- Text actions
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.ADD_TEXT then
        if self._textManager then
            self._textManager:AddText(data.x, data.y, data.text, data.size, data.color, data.group)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_TEXT then
        if self._textManager then
            self._textManager:DeleteText(data.index)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.UPDATE_TEXT then
        if self._textManager then
            self._textManager:UpdateText(data.index, data.newText)
        end

    -- Shape actions
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.ADD_SHAPE then
        if self._shapeManager then
            self._shapeManager:AddShape(data.x1, data.y1, data.x2, data.y2,
                data.shapeType, data.color, data.size, data.alpha, data.group)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_SHAPE then
        if self._shapeManager then
            self._shapeManager:DeleteShape(data.index)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.UPDATE_SHAPE then
        if self._shapeManager and data.newShape then
            local shape = self._shapeManager:GetShape(data.index)
            if shape then
                for k, v in pairs(data.newShape) do
                    shape[k] = v
                end
                self._shapeManager:UpdateShape(data.index)
            end
        end

    -- Image actions
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.ADD_IMAGE then
        if self._imageManager then
            self._imageManager:AddImage(data.x1, data.y1, data.x2, data.y2,
                data.path, data.alpha, data.group)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_IMAGE then
        if self._imageManager then
            self._imageManager:DeleteImage(data.index)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.UPDATE_IMAGE then
        if self._imageManager and data.newImage then
            local image = self._imageManager:GetImage(data.index)
            if image then
                for k, v in pairs(data.newImage) do
                    image[k] = v
                end
                self._imageManager:UpdateImage(data.index)
            end
        end

    -- Brush/dot actions
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.ADD_DOTS then
        if self._brushManager and data.dots then
            -- no-op: Re-add dots (complex, would need brush API support)
            -- For now, assume brush manager tracks indices
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_DOTS then
        if self._brushManager and data.indices then
            -- no-op: Re-delete dots
        end

    -- Selection and group actions
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.MOVE_SELECTION then
        if data.elements then
            for _, elem in ipairs(data.elements) do
                self:_MoveElement(elem.type, elem.index, data.deltaX, data.deltaY)
            end
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_SELECTION then
        if data.elements then
            for _, elem in ipairs(data.elements) do
                self:_DeleteElement(elem.type, elem.index)
            end
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.MOVE_GROUP then
        if data.elements then
            for _, elem in ipairs(data.elements) do
                self:_MoveElement(elem.type, elem.index, data.deltaX, data.deltaY)
            end
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_GROUP then
        if data.elements then
            for _, elem in ipairs(data.elements) do
                self:_DeleteElement(elem.type, elem.index)
            end
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.CREATE_GROUP then
        if data.elements and data.groupId then
            for _, elem in ipairs(data.elements) do
                self:_SetElementGroup(elem.type, elem.index, data.groupId)
            end
        end

    -- Clear all
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.CLEAR_ALL then
        -- Clear all elements (already done, snapshot is for undo)
        if self._brushManager then self._brushManager:ClearAllDots() end
        if self._shapeManager then self._shapeManager:ClearAllShapes() end
        if self._textManager then self._textManager:ClearAllTexts() end
        if self._iconManager then self._iconManager:ClearAllIcons() end
        if self._imageManager then self._imageManager:ClearAllImages() end
    end
end

--[[--------------------------------------------------------------------
    Internal Helper Methods
----------------------------------------------------------------------]]

--- Helper: Move an element by delta
--- @param elementType string Element type ("icon", "text", "image", "shape")
--- @param index number Element index
--- @param dx number X delta
--- @param dy number Y delta
function LoolibCanvasHistoryMixin:_MoveElement(elementType, index, dx, dy)
    if elementType == "icon" and self._iconManager then
        local icon = self._iconManager:GetIcon(index)
        if icon then
            self._iconManager:MoveIcon(index, icon.x + dx, icon.y + dy)
        end
    elseif elementType == "text" and self._textManager then
        local text = self._textManager:GetText(index)
        if text then
            self._textManager:MoveText(index, text.x + dx, text.y + dy)
        end
    elseif elementType == "image" and self._imageManager then
        self._imageManager:MoveImage(index, dx, dy)
    elseif elementType == "shape" and self._shapeManager then
        local shape = self._shapeManager:GetShape(index)
        if shape then
            self._shapeManager:MoveShape(index, shape.x1 + dx, shape.y1 + dy,
                shape.x2 + dx, shape.y2 + dy)
        end
    end
end

--- Helper: Delete an element
--- @param elementType string Element type ("icon", "text", "image", "shape")
--- @param index number Element index
function LoolibCanvasHistoryMixin:_DeleteElement(elementType, index)
    if elementType == "icon" and self._iconManager then
        self._iconManager:DeleteIcon(index)
    elseif elementType == "text" and self._textManager then
        self._textManager:DeleteText(index)
    elseif elementType == "image" and self._imageManager then
        self._imageManager:DeleteImage(index)
    elseif elementType == "shape" and self._shapeManager then
        self._shapeManager:DeleteShape(index)
    end
end

--- Helper: Set element group
--- @param elementType string Element type ("icon", "text", "image", "shape")
--- @param index number Element index
--- @param groupId number|nil Group ID or nil to ungroup
function LoolibCanvasHistoryMixin:_SetElementGroup(elementType, index, groupId)
    -- This would require API support in element managers
    -- For now, placeholder for future implementation
    if elementType == "icon" and self._iconManager then
        local icon = self._iconManager:GetIcon(index)
        if icon then
            icon.group = groupId
        end
    elseif elementType == "text" and self._textManager then
        local text = self._textManager:GetText(index)
        if text then
            text.group = groupId
        end
    elseif elementType == "image" and self._imageManager then
        local image = self._imageManager:GetImage(index)
        if image then
            image.group = groupId
        end
    elseif elementType == "shape" and self._shapeManager then
        local shape = self._shapeManager:GetShape(index)
        if shape then
            shape.group = groupId
        end
    end
end

--- Helper: Create snapshot of all canvas elements
--- @return table Snapshot data
function LoolibCanvasHistoryMixin:CreateSnapshot()
    return {
        dots = self._brushManager and self._brushManager:SerializeDots() or {},
        shapes = self._shapeManager and self._shapeManager:SerializeShapes() or {},
        texts = self._textManager and self._textManager:SerializeTexts() or {},
        icons = self._iconManager and self._iconManager:SerializeIcons() or {},
        images = self._imageManager and self._imageManager:SerializeImages() or {},
    }
end

--- Helper: Restore snapshot of all canvas elements
--- @param snapshot table Snapshot data from CreateSnapshot()
function LoolibCanvasHistoryMixin:_RestoreSnapshot(snapshot)
    if self._brushManager then self._brushManager:DeserializeDots(snapshot.dots) end
    if self._shapeManager then self._shapeManager:DeserializeShapes(snapshot.shapes) end
    if self._textManager then self._textManager:DeserializeTexts(snapshot.texts) end
    if self._iconManager then self._iconManager:DeserializeIcons(snapshot.icons) end
    if self._imageManager then self._imageManager:DeserializeImages(snapshot.images) end
end

--[[--------------------------------------------------------------------
    History State Queries
----------------------------------------------------------------------]]

--- Check if undo is available
--- @return boolean True if can undo
function LoolibCanvasHistoryMixin:CanUndo()
    return #self._undoStack > 0
end

--- Check if redo is available
--- @return boolean True if can redo
function LoolibCanvasHistoryMixin:CanRedo()
    return #self._redoStack > 0
end

--- Get number of undo steps available
--- @return number Undo count
function LoolibCanvasHistoryMixin:GetUndoCount()
    return #self._undoStack
end

--- Get number of redo steps available
--- @return number Redo count
function LoolibCanvasHistoryMixin:GetRedoCount()
    return #self._redoStack
end

--- Get the type of the last action
--- @return string|nil Action type or nil if no history
function LoolibCanvasHistoryMixin:GetLastActionType()
    if #self._undoStack > 0 then
        local action = self._undoStack[#self._undoStack]
        return action.type == "batch" and action.name or action.type
    end
    return nil
end

--- Clear all history (both undo and redo stacks)
--- @return table self for chaining
function LoolibCanvasHistoryMixin:ClearHistory()
    self._undoStack = {}
    self._redoStack = {}

    if self.TriggerEvent then
        self:TriggerEvent("OnHistoryCleared")
        self:TriggerEvent("OnHistoryChanged")
    end

    return self
end

--[[--------------------------------------------------------------------
    Factory and Module Registration
----------------------------------------------------------------------]]

--- Create a new canvas history instance
--- @return table Canvas history object
local function LoolibCreateCanvasHistory()
    local history = {}
    Loolib.Mixin(history, LoolibCanvasHistoryMixin)
    history:OnLoad()
    return history
end

-- Register module with Loolib
Loolib:RegisterModule("CanvasHistory", {
    Mixin = LoolibCanvasHistoryMixin,
    ACTIONS = LOOLIB_CANVAS_ACTION_TYPES,
    Create = LoolibCreateCanvasHistory,
})
