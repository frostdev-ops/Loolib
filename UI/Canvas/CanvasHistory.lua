--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    CanvasHistory - Undo/Redo history system for canvas operations

    Manages undo/redo stacks for all canvas operations including adding,
    deleting, moving, and modifying elements (dots, shapes, text, icons,
    images). Supports batching multiple operations and snapshotting for
    complex undo operations like clear all.

    CV-01/CV-02 FIX: History uses a command pattern where each action
    stores closures/data that map to ACTUAL element manager methods,
    not assumed CanvasFrame methods. Undo/redo operate directly on
    the element managers.

    CV-18 FIX: Configurable max history size (default 50), evicts oldest.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Cached globals
local type = type
local error = error
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local table_insert = table.insert
local table_remove = table.remove

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
    - Configurable max history size (default 50) -- CV-18
    - Batch operations to group multiple actions
    - Snapshot support for complex undo operations
    - Event triggers for UI updates
    - Recording control to prevent circular history entries

    Events Triggered:
    - OnHistoryChanged: When history state changes (new action, undo, redo)
    - OnUndo: When an undo operation completes
    - OnRedo: When a redo operation completes
    - OnHistoryCleared: When history is cleared
----------------------------------------------------------------------]]

---@class LoolibCanvasHistoryMixin
local LoolibCanvasHistoryMixin = {}

--- Initialize the history system
---@return LoolibCanvasHistoryMixin self
function LoolibCanvasHistoryMixin:OnLoad()
    -- History stacks
    self._undoStack = {}
    self._redoStack = {}

    -- CV-18: Configurable max history size (default 50)
    self._maxHistorySize = 50

    -- Recording state
    self._isRecording = true
    self._batchAction = nil  -- For grouping multiple operations

    -- Element managers (set via SetElementManagers)
    self._brushManager = nil
    self._shapeManager = nil
    self._textManager = nil
    self._iconManager = nil
    self._imageManager = nil
    return self
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set element managers for undo/redo operations
---@param brush table Brush manager (LoolibCanvasBrushMixin)
---@param shape table Shape manager (LoolibCanvasShapeMixin)
---@param text table Text manager (LoolibCanvasTextMixin)
---@param icon table Icon manager (LoolibCanvasIconMixin)
---@param image table Image manager (LoolibCanvasImageMixin)
---@return LoolibCanvasHistoryMixin self for chaining
function LoolibCanvasHistoryMixin:SetElementManagers(brush, shape, text, icon, image)
    self._brushManager = brush
    self._shapeManager = shape
    self._textManager = text
    self._iconManager = icon
    self._imageManager = image
    return self
end

--- Set maximum history size (number of undo steps to keep)
--- CV-18: Enforced limit prevents unbounded memory growth
---@param size number Maximum number of actions to store (minimum 1)
---@return LoolibCanvasHistoryMixin self for chaining
function LoolibCanvasHistoryMixin:SetMaxHistorySize(size)
    if type(size) ~= "number" or size < 1 then
        error("LoolibCanvasHistory: SetMaxHistorySize: size must be a positive number", 2)
    end
    self._maxHistorySize = size
    -- Trim if current stack exceeds new limit
    while #self._undoStack > self._maxHistorySize do
        table_remove(self._undoStack, 1)
    end
    return self
end

--- Get the current max history size
---@return number size Max history size
function LoolibCanvasHistoryMixin:GetMaxHistorySize()
    return self._maxHistorySize
end

--[[--------------------------------------------------------------------
    Recording Control
----------------------------------------------------------------------]]

--- Enable or disable history recording
--- Useful to prevent circular history entries when programmatically
--- modifying canvas during undo/redo operations.
---@param enabled boolean True to enable recording
---@return LoolibCanvasHistoryMixin self for chaining
function LoolibCanvasHistoryMixin:SetRecording(enabled)
    self._isRecording = enabled
    return self
end

--- Check if history recording is enabled
---@return boolean recording True if recording
function LoolibCanvasHistoryMixin:IsRecording()
    return self._isRecording
end

--[[--------------------------------------------------------------------
    Action Recording
----------------------------------------------------------------------]]

--- Push an action to the history stack
---@param actionType string Action type from LOOLIB_CANVAS_ACTION_TYPES
---@param data table Action data (parameters for redo)
---@param undoData table|nil Optional undo-specific data (parameters for undo)
---@return LoolibCanvasHistoryMixin self for chaining
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
        table_insert(self._batchAction.actions, action)
    else
        -- Add as standalone action
        table_insert(self._undoStack, action)

        -- Clear redo stack on new action (branching timeline)
        self._redoStack = {}

        -- CV-18: Limit history size
        while #self._undoStack > self._maxHistorySize do
            table_remove(self._undoStack, 1)
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
---@param batchName string|nil Optional name for the batch
---@return LoolibCanvasHistoryMixin self for chaining
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
---@return LoolibCanvasHistoryMixin self for chaining
function LoolibCanvasHistoryMixin:EndBatch()
    if not self._batchAction then return self end

    -- Only add batch if it contains actions
    if #self._batchAction.actions > 0 then
        table_insert(self._undoStack, self._batchAction)
        self._redoStack = {}

        -- CV-18: Limit history size
        while #self._undoStack > self._maxHistorySize do
            table_remove(self._undoStack, 1)
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
---@return LoolibCanvasHistoryMixin self for chaining
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
    CV-01/CV-02 FIX: These now call actual element manager methods
    instead of non-existent CanvasFrame methods.
----------------------------------------------------------------------]]

--- Undo the last action
---@return LoolibCanvasHistoryMixin self for chaining
function LoolibCanvasHistoryMixin:Undo()
    if not self:CanUndo() then return self end

    local action = table_remove(self._undoStack)

    -- Disable recording during undo to prevent circular history
    self._isRecording = false
    local ok, err = pcall(self._UndoAction, self, action)
    self._isRecording = true

    if not ok then
        table_insert(self._undoStack, action)
        error(err, 0)
    end

    table_insert(self._redoStack, action)

    if self.TriggerEvent then
        self:TriggerEvent("OnUndo", action.type)
        self:TriggerEvent("OnHistoryChanged")
    end

    return self
end

--- Redo the last undone action
---@return LoolibCanvasHistoryMixin self for chaining
function LoolibCanvasHistoryMixin:Redo()
    if not self:CanRedo() then return self end

    local action = table_remove(self._redoStack)

    -- Disable recording during redo to prevent circular history
    self._isRecording = false
    local ok, err = pcall(self._RedoAction, self, action)
    self._isRecording = true

    if not ok then
        table_insert(self._redoStack, action)
        error(err, 0)
    end

    table_insert(self._undoStack, action)

    if self.TriggerEvent then
        self:TriggerEvent("OnRedo", action.type)
        self:TriggerEvent("OnHistoryChanged")
    end

    return self
end

--[[--------------------------------------------------------------------
    Internal Action Handlers
    CV-01/CV-02 FIX: _UndoAction and _RedoAction now operate directly
    on element managers using their actual API methods (DeleteIcon,
    AddIcon, DeleteShape, AddShape, etc.) instead of non-existent
    CanvasFrame methods like RemoveElement/AddElement.
----------------------------------------------------------------------]]

--- INTERNAL: Undo a single action
---@param action table Action to undo
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
            self._shapeManager:UpdateShape(data.index, data.oldShape)
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
        if self._imageManager and data.oldPath then
            self._imageManager:SetImagePath(data.index, data.oldPath)
            if data.oldAlpha then
                self._imageManager:SetImageAlpha(data.index, data.oldAlpha)
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
        -- Move selection back by reversing delta
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
                self:_SetElementGroup(elem.type, elem.index, 0)
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

--- INTERNAL: Redo a single action
---@param action table Action to redo
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
            self._shapeManager:UpdateShape(data.index, data.newShape)
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
        if self._imageManager and data.newPath then
            self._imageManager:SetImagePath(data.index, data.newPath)
            if data.newAlpha then
                self._imageManager:SetImageAlpha(data.index, data.newAlpha)
            end
        end

    -- Brush/dot actions
    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.ADD_DOTS then
        if self._brushManager and data.dotsSnapshot then
            self._brushManager:DeserializeDots(data.dotsSnapshot)
        end

    elseif action.type == LOOLIB_CANVAS_ACTION_TYPES.DELETE_DOTS then
        if self._brushManager and data.resultSnapshot then
            self._brushManager:DeserializeDots(data.resultSnapshot)
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
        -- Clear all elements via actual manager API
        if self._brushManager then self._brushManager:ClearDots() end
        if self._shapeManager then self._shapeManager:ClearShapes() end
        if self._textManager then self._textManager:ClearTexts() end
        if self._iconManager then self._iconManager:ClearIcons() end
        if self._imageManager then self._imageManager:ClearImages() end
    end
end

--[[--------------------------------------------------------------------
    Internal Helper Methods
----------------------------------------------------------------------]]

--- INTERNAL: Move an element by delta
---@param elementType string Element type ("icon", "text", "image", "shape")
---@param index number Element index
---@param dx number X delta
---@param dy number Y delta
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
        self._shapeManager:MoveShape(index, dx, dy)
    end
end

--- INTERNAL: Delete an element
---@param elementType string Element type ("icon", "text", "image", "shape")
---@param index number Element index
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

--- INTERNAL: Set element group via actual manager API
---@param elementType string Element type ("icon", "text", "image", "shape")
---@param index number Element index
---@param groupId number|nil Group ID or 0 to ungroup
function LoolibCanvasHistoryMixin:_SetElementGroup(elementType, index, groupId)
    if elementType == "icon" and self._iconManager then
        self._iconManager:UpdateIcon(index, { group = groupId or 0 })
    elseif elementType == "shape" and self._shapeManager then
        self._shapeManager:SetShapeGroup(index, groupId or 0)
    end
    -- text and image managers do not expose group setters yet;
    -- this is a known limitation documented in compatibility notes
end

--- Create snapshot of all canvas elements
---@return table snapshot Snapshot data
function LoolibCanvasHistoryMixin:CreateSnapshot()
    return {
        dots = self._brushManager and self._brushManager:SerializeDots() or {},
        shapes = self._shapeManager and self._shapeManager:SerializeShapes() or {},
        texts = self._textManager and self._textManager:SerializeTexts() or {},
        icons = self._iconManager and self._iconManager:SerializeIcons() or {},
        images = self._imageManager and self._imageManager:SerializeImages() or {},
    }
end

--- INTERNAL: Restore snapshot of all canvas elements
---@param snapshot table Snapshot data from CreateSnapshot()
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
---@return boolean canUndo True if can undo
function LoolibCanvasHistoryMixin:CanUndo()
    return #self._undoStack > 0
end

--- Check if redo is available
---@return boolean canRedo True if can redo
function LoolibCanvasHistoryMixin:CanRedo()
    return #self._redoStack > 0
end

--- Get number of undo steps available
---@return number count Undo count
function LoolibCanvasHistoryMixin:GetUndoCount()
    return #self._undoStack
end

--- Get number of redo steps available
---@return number count Redo count
function LoolibCanvasHistoryMixin:GetRedoCount()
    return #self._redoStack
end

--- Get the type of the last action
---@return string|nil actionType Action type or nil if no history
function LoolibCanvasHistoryMixin:GetLastActionType()
    if #self._undoStack > 0 then
        local action = self._undoStack[#self._undoStack]
        return action.type == "batch" and action.name or action.type
    end
    return nil
end

--- Clear all history (both undo and redo stacks)
---@return LoolibCanvasHistoryMixin self for chaining
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
--- INTERNAL
---@return LoolibCanvasHistoryMixin history Canvas history object
local function LoolibCreateCanvasHistory()
    local history = {}
    Loolib.Mixin(history, LoolibCanvasHistoryMixin)
    history:OnLoad()
    return history
end

-- R4: Fully qualified name
Loolib:RegisterModule("Canvas.CanvasHistory", {
    Mixin = LoolibCanvasHistoryMixin,
    ACTIONS = LOOLIB_CANVAS_ACTION_TYPES,
    Create = LoolibCreateCanvasHistory,
})

-- Backward-compat alias
Loolib:RegisterModule("CanvasHistory", {
    Mixin = LoolibCanvasHistoryMixin,
    ACTIONS = LOOLIB_CANVAS_ACTION_TYPES,
    Create = LoolibCreateCanvasHistory,
})
