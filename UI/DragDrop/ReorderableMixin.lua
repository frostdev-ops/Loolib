--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ReorderableMixin - List item drag-to-reorder functionality

    Features:
    - Drag-and-drop item reordering in scrollable lists
    - Visual drop indicator showing insertion point
    - Optional modifier key requirement (shift/ctrl/alt)
    - Customizable drag button
    - Data reorder callback for external data arrays
    - Event callbacks for drag lifecycle
    - Automatic position restoration on drop
    - Compatible with ScrollableList and custom list implementations

    Usage:
        local list = CreateFrame("Frame", nil, parent)
        LoolibMixin(list, LoolibScrollableListMixin, LoolibReorderableMixin)
        list:OnLoad()
        list:InitReorderable()
        list:SetReorderEnabled(true)
        list:SetDataReorderCallback(function(fromIndex, toIndex)
            -- Reorder backing data array
            local item = table.remove(myData, fromIndex)
            table.insert(myData, toIndex, item)
        end)

    Dependencies:
    - Core/Loolib.lua (Loolib namespace)
    - Events/CallbackRegistry.lua (LoolibCallbackRegistryMixin)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local _LoolibMixin = assert(Loolib.Mixin, "Loolib.Mixin is required for ReorderableMixin") ---@diagnostic disable-line: unused-local
local _LoolibScrollableListMixin = assert(Loolib.ScrollableListMixin, "Loolib.ScrollableListMixin is required for ReorderableMixin") ---@diagnostic disable-line: unused-local

-- Local references to globals
local type = type
local error = error
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local select = select
local table_insert = table.insert

--[[--------------------------------------------------------------------
    LoolibReorderableMixin

    Mixin for list containers that enables drag-to-reorder functionality.
    Apply this to your scrollable list frame.
----------------------------------------------------------------------]]

---@class LoolibReorderableMixin : Frame
---@field reorderEnabled boolean
---@field reorderButton string
---@field reorderModifier string?
---@field dataReorderCallback function?
---@field _draggedItem Frame?
---@field _draggedIndex number?
---@field _dropIndex number?
---@field _dropIndicator Frame?
---@field _updateFrame Frame?
local LoolibReorderableMixin = {}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the reorderable system.
--- Idempotent: safe to call multiple times. Must be called after OnLoad.
---@return nil
function LoolibReorderableMixin:InitReorderable()
    self.reorderEnabled = false
    self.reorderButton = "LeftButton"
    self.reorderModifier = nil  -- nil, "shift", "ctrl", or "alt"
    self.dataReorderCallback = nil

    -- Internal state
    self._draggedItem = nil
    self._draggedIndex = nil
    self._dropIndex = nil
    self._dropIndicator = nil
    self._updateFrame = nil

    -- Set up callback events if CallbackRegistry is available
    if self.GenerateCallbackEvents then
        self:GenerateCallbackEvents({
            "OnItemDragStart",   -- (item, index)
            "OnItemDragEnd",     -- (item, fromIndex, toIndex)
            "OnItemReorder",     -- (fromIndex, toIndex)
        })
    end
end

--[[--------------------------------------------------------------------
    Configuration (Fluent API)
----------------------------------------------------------------------]]

--- Enable or disable reordering
---@param enabled boolean True to enable, false to disable
---@return LoolibReorderableMixin self
function LoolibReorderableMixin:SetReorderEnabled(enabled)
    if type(enabled) ~= "boolean" then
        error("LoolibReorderableMixin: SetReorderEnabled: 'enabled' must be a boolean", 2)
    end

    self.reorderEnabled = enabled

    -- Apply to existing visible items
    local items = self:_GetVisibleItems()
    for _, item in ipairs(items) do
        self:_SetupItemDrag(item, enabled)
    end

    return self
end

--- Set the mouse button required for drag
---@param button string "LeftButton", "RightButton", etc.
---@return LoolibReorderableMixin self
function LoolibReorderableMixin:SetReorderButton(button)
    if type(button) ~= "string" then
        error("LoolibReorderableMixin: SetReorderButton: 'button' must be a string", 2)
    end
    self.reorderButton = button
    return self
end

--- Require a modifier key to be held during drag
---@param modifier string? "shift", "ctrl", "alt", or nil for no requirement
---@return LoolibReorderableMixin self
function LoolibReorderableMixin:SetReorderModifier(modifier)
    if modifier ~= nil and type(modifier) ~= "string" then
        error("LoolibReorderableMixin: SetReorderModifier: 'modifier' must be a string or nil", 2)
    end
    self.reorderModifier = modifier
    return self
end

--- Set callback for reordering backing data
--- The callback receives (fromIndex, toIndex) and should reorder the data array.
--- If toIndex > fromIndex, the item moves down in the list.
--- The callback is responsible for removing from fromIndex and inserting at toIndex.
---@param callback function function(fromIndex, toIndex) to reorder external data
---@return LoolibReorderableMixin self
function LoolibReorderableMixin:SetDataReorderCallback(callback)
    if callback ~= nil and type(callback) ~= "function" then
        error("LoolibReorderableMixin: SetDataReorderCallback: 'callback' must be a function or nil", 2)
    end
    self.dataReorderCallback = callback
    return self
end

--[[--------------------------------------------------------------------
    Drop Indicator
----------------------------------------------------------------------]]

--- Get or create the drop indicator frame -- INTERNAL
---@return Frame indicator
function LoolibReorderableMixin:_GetDropIndicator()
    if self._dropIndicator then
        return self._dropIndicator
    end

    -- Create drop indicator frame
    local indicator = CreateFrame("Frame", nil, self)
    indicator:SetHeight(2)
    indicator:SetFrameLevel(self:GetFrameLevel() + 100)

    -- Main line texture
    local texture = indicator:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetColorTexture(0.3, 0.7, 1.0, 1.0)  -- Blue indicator line

    -- Glow effect
    local glow = indicator:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("TOPLEFT", -2, 2)
    glow:SetPoint("BOTTOMRIGHT", 2, -2)
    glow:SetColorTexture(0.3, 0.7, 1.0, 0.3)

    indicator:Hide()
    self._dropIndicator = indicator
    return indicator
end

--- Show the drop indicator at the insertion point -- INTERNAL
---@param targetItem Frame The item frame to show indicator near
---@param insertAfter boolean If true, show below targetItem
function LoolibReorderableMixin:_ShowDropIndicator(targetItem, insertAfter)
    local indicator = self:_GetDropIndicator()

    indicator:ClearAllPoints()
    indicator:SetWidth(targetItem:GetWidth())

    if insertAfter then
        -- Show below target item
        indicator:SetPoint("TOPLEFT", targetItem, "BOTTOMLEFT", 0, 1)
    else
        -- Show above target item
        indicator:SetPoint("BOTTOMLEFT", targetItem, "TOPLEFT", 0, -1)
    end

    indicator:Show()
end

--- Hide the drop indicator -- INTERNAL
function LoolibReorderableMixin:_HideDropIndicator()
    if self._dropIndicator then
        self._dropIndicator:Hide()
    end
end

--[[--------------------------------------------------------------------
    Item Setup
----------------------------------------------------------------------]]

--- Set up drag handlers on a list item frame -- INTERNAL
--- Called internally when creating/acquiring list items.
---@param item Frame The list item frame
---@param enabled boolean Whether drag should be enabled
function LoolibReorderableMixin:_SetupItemDrag(item, enabled)
    if enabled then
        item:EnableMouse(true)
        item:SetMovable(true)
        item:RegisterForDrag(self.reorderButton)

        local list = self

        ---@diagnostic disable-next-line: redefined-local
        item:SetScript("OnDragStart", function(self)
            list:_OnItemDragStart(self)
        end)

        ---@diagnostic disable-next-line: redefined-local
        item:SetScript("OnDragStop", function(self)
            list:_OnItemDragStop(self)
        end)
    else
        item:SetMovable(false)
        item:RegisterForDrag()
        item:SetScript("OnDragStart", nil)
        item:SetScript("OnDragStop", nil)
    end
end

--- Set up a list item for reordering
--- Call this when creating/acquiring list items in your refresh logic.
---@param item Frame The list item frame
---@param index number The item's position in the list
---@return nil
function LoolibReorderableMixin:SetupReorderableItem(item, index)
    if type(index) ~= "number" or index < 1 then
        error("LoolibReorderableMixin: SetupReorderableItem: 'index' must be a positive number", 2)
    end

    item._listIndex = index
    item._parentList = self

    if self.reorderEnabled then
        self:_SetupItemDrag(item, true)
    end
end

--[[--------------------------------------------------------------------
    Drag Handlers
----------------------------------------------------------------------]]

--- Handle item drag start -- INTERNAL
---@param item Frame The item frame being dragged
function LoolibReorderableMixin:_OnItemDragStart(item)
    -- Check modifier requirement
    if self.reorderModifier then
        local modifierDown = false
        if self.reorderModifier == "shift" then
            modifierDown = IsShiftKeyDown()
        elseif self.reorderModifier == "ctrl" then
            modifierDown = IsControlKeyDown()
        elseif self.reorderModifier == "alt" then
            modifierDown = IsAltKeyDown()
        end

        if not modifierDown then
            return
        end
    end

    if not self.reorderEnabled or not item:IsMovable() then
        return
    end

    -- Ignore drag if item has ignoreDrag flag (compatibility with MRT pattern)
    if item.ignoreDrag then
        return
    end

    -- Save original anchor points for restoration
    item._originalPoints = {}
    for i = 1, item:GetNumPoints() do
        item._originalPoints[i] = {item:GetPoint(i)}
    end

    self._draggedItem = item
    self._draggedIndex = item._listIndex

    -- Visual feedback - make dragged item semi-transparent
    item:SetAlpha(0.5)
    item:StartMoving()

    -- Start update loop to track mouse position
    self:_StartDragUpdate()

    -- Hide tooltip
    if GameTooltip then
        GameTooltip:Hide()
    end

    -- Fire event
    if self.TriggerEvent then
        self:TriggerEvent("OnItemDragStart", item, self._draggedIndex)
    end
end

--- Handle item drag stop -- INTERNAL
---@param item Frame The item frame being dropped
function LoolibReorderableMixin:_OnItemDragStop(item)
    if self._draggedItem ~= item then
        return
    end

    item:StopMovingOrSizing()
    item:SetAlpha(1)

    -- Stop update loop
    self:_StopDragUpdate()
    self:_HideDropIndicator()

    -- Restore original position
    item:ClearAllPoints()
    if item._originalPoints then
        for _, point in ipairs(item._originalPoints) do
            item:SetPoint(unpack(point))
        end
        item._originalPoints = nil
    end

    -- Check if we have a valid drop target
    local targetItem, insertAfter = self:_GetDropTarget()
    local targetIndex = nil

    if targetItem and targetItem._listIndex then
        targetIndex = targetItem._listIndex
        if insertAfter then
            targetIndex = targetIndex + 1
        end

        -- Don't reorder to same position or adjacent position
        if targetIndex ~= self._draggedIndex and targetIndex ~= self._draggedIndex + 1 then
            self:_PerformReorder(self._draggedIndex, targetIndex)
        end
    end

    -- Fire event
    if self.TriggerEvent then
        self:TriggerEvent("OnItemDragEnd", item, self._draggedIndex, targetIndex)
    end

    -- Clear state
    self._draggedItem = nil
    self._draggedIndex = nil
    self._dropIndex = nil
end

--[[--------------------------------------------------------------------
    Drop Target Detection
----------------------------------------------------------------------]]

--- Find the list item under the mouse cursor -- INTERNAL
---@return Frame? targetItem The item frame under cursor
---@return boolean? insertAfter Whether to insert after the target
function LoolibReorderableMixin:_GetDropTarget()
    if not self._draggedItem then
        return nil, nil
    end

    local items = self:_GetVisibleItems()
    local draggedY = select(2, self._draggedItem:GetCenter())
    if not draggedY then
        return nil, nil
    end

    -- Find the item under the mouse cursor
    for _, item in ipairs(items) do
        if item ~= self._draggedItem and item:IsVisible() and MouseIsOver(item) then
            local itemY = select(2, item:GetCenter())
            if itemY then
                -- Determine if we should insert before or after this item
                local insertAfter = draggedY < itemY
                return item, insertAfter
            end
        end
    end

    return nil, nil
end

--- Get all visible list items -- INTERNAL
--- Tries multiple patterns: ScrollableList API, _items table, or MRT List pattern.
---@return table items Array of visible item frames
function LoolibReorderableMixin:_GetVisibleItems()
    -- Try ScrollableList pattern
    if self.visibleItems then
        local items = {}
        for _, frame in pairs(self.visibleItems) do
            if frame:IsVisible() then
                table_insert(items, frame)
            end
        end
        return items
    end

    -- Try MRT pattern
    if self.List then
        local items = {}
        for _, frame in ipairs(self.List) do
            if frame:IsShown() then
                table_insert(items, frame)
            end
        end
        return items
    end

    -- Try generic _items table
    if self._items then
        local items = {}
        for _, frame in pairs(self._items) do
            if frame:IsVisible() then
                table_insert(items, frame)
            end
        end
        return items
    end

    return {}
end

--[[--------------------------------------------------------------------
    Update Loop (during drag)
----------------------------------------------------------------------]]

--- Start the drag tracking update loop -- INTERNAL
function LoolibReorderableMixin:_StartDragUpdate()
    if not self._updateFrame then
        self._updateFrame = CreateFrame("Frame")
    end

    local list = self
    self._updateFrame:SetScript("OnUpdate", function()
        if not list._draggedItem then
            return
        end

        local targetItem, insertAfter = list:_GetDropTarget()

        if targetItem then
            list:_ShowDropIndicator(targetItem, insertAfter)
        else
            list:_HideDropIndicator()
        end
    end)
end

--- Stop the drag tracking update loop -- INTERNAL
function LoolibReorderableMixin:_StopDragUpdate()
    if self._updateFrame then
        self._updateFrame:SetScript("OnUpdate", nil)
    end
end

--[[--------------------------------------------------------------------
    Reorder Execution
----------------------------------------------------------------------]]

--- Perform the reorder operation -- INTERNAL
---@param fromIndex number Source index
---@param toIndex number Target index
function LoolibReorderableMixin:_PerformReorder(fromIndex, toIndex)
    -- Adjust toIndex if moving down (account for removal)
    -- When removing item at fromIndex, all items after it shift down
    if toIndex > fromIndex then
        toIndex = toIndex - 1
    end

    -- Call data reorder callback if set
    if self.dataReorderCallback then
        self.dataReorderCallback(fromIndex, toIndex)
    end

    -- Fire reorder event
    if self.TriggerEvent then
        self:TriggerEvent("OnItemReorder", fromIndex, toIndex)
    end

    -- Refresh the list if possible
    if self.Refresh then
        self:Refresh()
    elseif self.Update then
        self:Update()
    end
end

--- Move an item from one index to another.
--- DD-05: Validates both indices against data length.
---@param fromIndex number Source item index (1-based)
---@param toIndex number Target item index (1-based)
---@return nil
function LoolibReorderableMixin:MoveItem(fromIndex, toIndex)
    if type(fromIndex) ~= "number" then
        error("LoolibReorderableMixin: MoveItem: 'fromIndex' must be a number", 2)
    end
    if type(toIndex) ~= "number" then
        error("LoolibReorderableMixin: MoveItem: 'toIndex' must be a number", 2)
    end

    -- DD-05: Validate index bounds
    local itemCount = self:_GetItemCount()
    if fromIndex < 1 or fromIndex > itemCount then
        error("LoolibReorderableMixin: MoveItem: 'fromIndex' out of bounds (got "
            .. fromIndex .. ", count is " .. itemCount .. ")", 2)
    end
    if toIndex < 1 or toIndex > itemCount then
        error("LoolibReorderableMixin: MoveItem: 'toIndex' out of bounds (got "
            .. toIndex .. ", count is " .. itemCount .. ")", 2)
    end

    if fromIndex == toIndex then
        return
    end

    self:_PerformReorder(fromIndex, toIndex)
end

--- Swap two items by index.
---@param index1 number First item index (1-based)
---@param index2 number Second item index (1-based)
---@return nil
function LoolibReorderableMixin:SwapItems(index1, index2)
    if type(index1) ~= "number" then
        error("LoolibReorderableMixin: SwapItems: 'index1' must be a number", 2)
    end
    if type(index2) ~= "number" then
        error("LoolibReorderableMixin: SwapItems: 'index2' must be a number", 2)
    end

    -- DD-05: Validate index bounds
    local itemCount = self:_GetItemCount()
    if index1 < 1 or index1 > itemCount then
        error("LoolibReorderableMixin: SwapItems: 'index1' out of bounds (got "
            .. index1 .. ", count is " .. itemCount .. ")", 2)
    end
    if index2 < 1 or index2 > itemCount then
        error("LoolibReorderableMixin: SwapItems: 'index2' out of bounds (got "
            .. index2 .. ", count is " .. itemCount .. ")", 2)
    end

    if self.dataReorderCallback then
        -- Move index1 to index2's position
        local toIndex = index2
        if toIndex > index1 then
            toIndex = toIndex + 1
        end
        self:_PerformReorder(index1, toIndex)
    end
end

--- Get the total item count for bounds checking -- INTERNAL
---@return number count
function LoolibReorderableMixin:_GetItemCount()
    local items = self:_GetVisibleItems()
    return #items
end

--[[--------------------------------------------------------------------
    LoolibReorderableItemMixin

    Optional mixin for individual list line frames.
    Use this if your list items need additional reorder-related functionality.
----------------------------------------------------------------------]]

---@class LoolibReorderableItemMixin : Frame
---@field _listIndex number?
---@field _parentList Frame?
---@field _originalPoints table
local LoolibReorderableItemMixin = {}

--- Initialize a reorderable item.
--- Idempotent: safe to call multiple times.
---@return nil
function LoolibReorderableItemMixin:InitReorderableItem()
    self._listIndex = nil
    self._parentList = nil
    self._originalPoints = {}
end

--- Set this item's list index
---@param index number
---@return nil
function LoolibReorderableItemMixin:SetListIndex(index)
    if type(index) ~= "number" then
        error("LoolibReorderableItemMixin: SetListIndex: 'index' must be a number", 2)
    end
    self._listIndex = index
end

--- Get this item's list index
---@return number?
function LoolibReorderableItemMixin:GetListIndex()
    return self._listIndex
end

--- Get the parent list
---@return Frame?
function LoolibReorderableItemMixin:GetParentList()
    return self._parentList
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local ReorderableModule = {
    ListMixin = LoolibReorderableMixin,
    ItemMixin = LoolibReorderableItemMixin,
}

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.Reorderable = ReorderableModule

Loolib:RegisterModule("DragDrop.ReorderableMixin", LoolibReorderableMixin)
Loolib:RegisterModule("DragDrop.ReorderableItemMixin", LoolibReorderableItemMixin)
