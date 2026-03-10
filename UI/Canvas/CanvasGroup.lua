--[[
    Loolib - Canvas Group Manager
    Handles grouping canvas elements together for batch operations.

    Part of the Loolib UI framework for World of Warcraft addons.

    Copyright (c) 2025 James Kueller. All rights reserved.

    This file is part of Loolib, licensed under the BSD 3-Clause License.
    See the LICENSE file in the project root for full license information.
]]

local LOOLIB_VERSION = 1
local Loolib = LibStub("Loolib")
if not Loolib then return end

-- ============================================================================
-- Canvas Group Mixin
-- ============================================================================
-- Coordinates group operations across all canvas element types.
-- Groups allow organizing drawings and manipulating multiple elements as a unit.
--
-- Features:
--   - Create/delete groups with names
--   - Lock/unlock groups for protection
--   - Show/hide group visibility
--   - Move all elements in a group
--   - Delete all elements in a group
--   - Merge groups together
--   - Set current group for new elements
--   - Serialization for save/sync
--
-- Events:
--   - OnGroupCreated(groupId)
--   - OnGroupDeleted(groupId)
--   - OnGroupLockChanged(groupId, locked)
--   - OnGroupVisibilityChanged(groupId, visible)
--   - OnGroupMoved(groupId, deltaX, deltaY)
--   - OnGroupElementsDeleted(groupId)
--   - OnGroupsMerged(sourceGroupId, targetGroupId)
--
-- Usage:
--   local groupManager = LoolibCreateCanvasGroup()
--   groupManager:SetElementManagers(brush, shape, text, icon, image)
--
--   local groupId = groupManager:CreateGroup("My Group")
--   groupManager:SetCurrentGroup(groupId)  -- New elements go into this group
--
--   groupManager:LockGroup(groupId)
--   groupManager:MoveGroup(groupId, 10, 20)
--   groupManager:DeleteElementsByGroup(groupId)
-- ============================================================================

local LoolibCanvasGroupMixin = {}

-- ============================================================================
-- Initialization
-- ============================================================================

function LoolibCanvasGroupMixin:OnLoad()
    -- Group tracking
    self._groups = {}             -- { [groupId] = { name = "...", locked = false, visible = true } }
    self._nextGroupId = 1
    self._currentGroup = 0        -- 0 = no group (ungrouped)
    self._lockedGroups = {}       -- { [groupId] = true } - Fast lookup

    -- Element manager references (set by canvas frame)
    self._brushManager = nil
    self._shapeManager = nil
    self._textManager = nil
    self._iconManager = nil
    self._imageManager = nil
end

-- ============================================================================
-- Element Manager Setup
-- ============================================================================

--- Set references to all element managers
-- @param brush LoolibCanvasBrush manager
-- @param shape LoolibCanvasShape manager
-- @param text LoolibCanvasText manager
-- @param icon LoolibCanvasIcon manager
-- @param image LoolibCanvasImage manager
-- @return self for chaining
function LoolibCanvasGroupMixin:SetElementManagers(brush, shape, text, icon, image)
    self._brushManager = brush
    self._shapeManager = shape
    self._textManager = text
    self._iconManager = icon
    self._imageManager = image
    return self
end

-- ============================================================================
-- Current Group Management
-- ============================================================================

--- Set the current group for new elements
-- All element managers will assign this group ID to newly created elements
-- @param groupId number|nil Group ID (0 or nil = ungrouped)
-- @return self for chaining
function LoolibCanvasGroupMixin:SetCurrentGroup(groupId)
    self._currentGroup = groupId or 0

    -- Update all managers so they assign this group to new elements
    if self._brushManager then self._brushManager:SetCurrentGroup(groupId) end
    if self._shapeManager then self._shapeManager:SetCurrentGroup(groupId) end
    if self._textManager then self._textManager:SetCurrentGroup(groupId) end
    if self._iconManager then self._iconManager:SetCurrentGroup(groupId) end
    if self._imageManager then self._imageManager:SetCurrentGroup(groupId) end

    return self
end

--- Get the current group ID for new elements
-- @return number Group ID (0 = ungrouped)
function LoolibCanvasGroupMixin:GetCurrentGroup()
    return self._currentGroup
end

-- ============================================================================
-- Group CRUD Operations
-- ============================================================================

--- Create a new group
-- @param name string|nil Optional group name (default: "Group N")
-- @return number Group ID
function LoolibCanvasGroupMixin:CreateGroup(name)
    local groupId = self._nextGroupId
    self._nextGroupId = self._nextGroupId + 1

    self._groups[groupId] = {
        name = name or ("Group " .. groupId),
        locked = false,
        visible = true,
    }

    if self.TriggerEvent then
        self:TriggerEvent("OnGroupCreated", groupId)
    end

    return groupId
end

--- Delete a group and optionally its elements
-- @param groupId number Group ID
-- @param deleteElements boolean If true, delete all elements in the group
-- @return self for chaining
function LoolibCanvasGroupMixin:DeleteGroup(groupId, deleteElements)
    if not self._groups[groupId] then return self end

    if deleteElements then
        self:DeleteElementsByGroup(groupId)
    end

    self._groups[groupId] = nil
    self._lockedGroups[groupId] = nil

    if self.TriggerEvent then
        self:TriggerEvent("OnGroupDeleted", groupId)
    end

    return self
end

--- Get group information
-- @param groupId number Group ID
-- @return table|nil Group info { name, locked, visible }
function LoolibCanvasGroupMixin:GetGroup(groupId)
    return self._groups[groupId]
end

--- Get all groups
-- @return table { [groupId] = { id, name, locked, visible } }
function LoolibCanvasGroupMixin:GetAllGroups()
    local result = {}
    for id, info in pairs(self._groups) do
        result[id] = {
            id = id,
            name = info.name,
            locked = info.locked,
            visible = info.visible,
        }
    end
    return result
end

--- Rename a group
-- @param groupId number Group ID
-- @param name string New name
-- @return self for chaining
function LoolibCanvasGroupMixin:RenameGroup(groupId, name)
    if self._groups[groupId] then
        self._groups[groupId].name = name

        if self.TriggerEvent then
            self:TriggerEvent("OnGroupRenamed", groupId, name)
        end
    end
    return self
end

-- ============================================================================
-- Group Locking
-- ============================================================================

--- Lock or unlock a group
-- Locked groups cannot be moved or deleted
-- @param groupId number Group ID
-- @param locked boolean Lock state (default: true)
-- @return self for chaining
function LoolibCanvasGroupMixin:LockGroup(groupId, locked)
    if locked == nil then locked = true end

    self._lockedGroups[groupId] = locked or nil

    if self._groups[groupId] then
        self._groups[groupId].locked = locked
    end

    if self.TriggerEvent then
        self:TriggerEvent("OnGroupLockChanged", groupId, locked)
    end

    return self
end

--- Unlock a group
-- @param groupId number Group ID
-- @return self for chaining
function LoolibCanvasGroupMixin:UnlockGroup(groupId)
    return self:LockGroup(groupId, false)
end

--- Check if a group is locked
-- @param groupId number Group ID
-- @return boolean True if locked
function LoolibCanvasGroupMixin:IsGroupLocked(groupId)
    return self._lockedGroups[groupId] == true
end

--- Toggle group lock state
-- @param groupId number Group ID
-- @return self for chaining
function LoolibCanvasGroupMixin:ToggleGroupLock(groupId)
    return self:LockGroup(groupId, not self:IsGroupLocked(groupId))
end

-- ============================================================================
-- Group Visibility
-- ============================================================================

--- Set group visibility
-- @param groupId number Group ID
-- @param visible boolean Visibility state
-- @return self for chaining
function LoolibCanvasGroupMixin:SetGroupVisible(groupId, visible)
    if self._groups[groupId] then
        self._groups[groupId].visible = visible

        if self.TriggerEvent then
            self:TriggerEvent("OnGroupVisibilityChanged", groupId, visible)
        end
    end
    return self
end

--- Check if a group is visible
-- @param groupId number Group ID
-- @return boolean True if visible (default: true)
function LoolibCanvasGroupMixin:IsGroupVisible(groupId)
    local group = self._groups[groupId]
    return group and group.visible ~= false
end

--- Toggle group visibility
-- @param groupId number Group ID
-- @return self for chaining
function LoolibCanvasGroupMixin:ToggleGroupVisibility(groupId)
    if self._groups[groupId] then
        self:SetGroupVisible(groupId, not self:IsGroupVisible(groupId))
    end
    return self
end

-- ============================================================================
-- Batch Operations
-- ============================================================================

--- Move all elements in a group by a delta
-- Does nothing if group is locked
-- @param groupId number Group ID
-- @param deltaX number X offset in pixels
-- @param deltaY number Y offset in pixels
-- @return self for chaining
function LoolibCanvasGroupMixin:MoveGroup(groupId, deltaX, deltaY)
    if self:IsGroupLocked(groupId) then return self end

    if self._brushManager then
        self._brushManager:MoveDotsByGroup(groupId, deltaX, deltaY)
    end
    if self._shapeManager then
        self._shapeManager:MoveShapesByGroup(groupId, deltaX, deltaY)
    end
    if self._textManager then
        self._textManager:MoveTextsByGroup(groupId, deltaX, deltaY)
    end
    if self._iconManager then
        self._iconManager:MoveIconsByGroup(groupId, deltaX, deltaY)
    end
    if self._imageManager then
        self._imageManager:MoveImagesByGroup(groupId, deltaX, deltaY)
    end

    if self.TriggerEvent then
        self:TriggerEvent("OnGroupMoved", groupId, deltaX, deltaY)
    end

    return self
end

--- Delete all elements in a group
-- Does nothing if group is locked
-- @param groupId number Group ID
-- @return self for chaining
function LoolibCanvasGroupMixin:DeleteElementsByGroup(groupId)
    if self:IsGroupLocked(groupId) then return self end

    if self._brushManager then
        self._brushManager:DeleteDotsByGroup(groupId)
    end
    if self._shapeManager then
        self._shapeManager:DeleteShapesByGroup(groupId)
    end
    if self._textManager then
        self._textManager:DeleteTextsByGroup(groupId)
    end
    if self._iconManager then
        self._iconManager:DeleteIconsByGroup(groupId)
    end
    if self._imageManager then
        self._imageManager:DeleteImagesByGroup(groupId)
    end

    if self.TriggerEvent then
        self:TriggerEvent("OnGroupElementsDeleted", groupId)
    end

    return self
end

-- ============================================================================
-- Group Analysis
-- ============================================================================

--- Count total elements in a group across all types
-- @param groupId number Group ID
-- @return number Total element count
function LoolibCanvasGroupMixin:GetGroupElementCount(groupId)
    local count = 0

    -- Count dots
    if self._brushManager then
        for i = 1, self._brushManager:GetDotCount() do
            local dot = self._brushManager:GetDot(i)
            if dot and dot.group == groupId then
                count = count + 1
            end
        end
    end

    -- Count shapes
    if self._shapeManager then
        for i = 1, self._shapeManager:GetShapeCount() do
            local shape = self._shapeManager:GetShape(i)
            if shape and shape.group == groupId then
                count = count + 1
            end
        end
    end

    -- Count text
    if self._textManager then
        for i = 1, self._textManager:GetTextCount() do
            local text = self._textManager:GetText(i)
            if text and text.group == groupId then
                count = count + 1
            end
        end
    end

    -- Count icons
    if self._iconManager then
        for i = 1, self._iconManager:GetIconCount() do
            local icon = self._iconManager:GetIcon(i)
            if icon and icon.group == groupId then
                count = count + 1
            end
        end
    end

    -- Count images
    if self._imageManager then
        for i = 1, self._imageManager:GetImageCount() do
            local image = self._imageManager:GetImage(i)
            if image and image.group == groupId then
                count = count + 1
            end
        end
    end

    return count
end

--- Get element counts by type for a group
-- @param groupId number Group ID
-- @return table { dots, shapes, texts, icons, images, total }
function LoolibCanvasGroupMixin:GetGroupElementCountsByType(groupId)
    local counts = {
        dots = 0,
        shapes = 0,
        texts = 0,
        icons = 0,
        images = 0,
        total = 0,
    }

    -- Count dots
    if self._brushManager then
        for i = 1, self._brushManager:GetDotCount() do
            local dot = self._brushManager:GetDot(i)
            if dot and dot.group == groupId then
                counts.dots = counts.dots + 1
            end
        end
    end

    -- Count shapes
    if self._shapeManager then
        for i = 1, self._shapeManager:GetShapeCount() do
            local shape = self._shapeManager:GetShape(i)
            if shape and shape.group == groupId then
                counts.shapes = counts.shapes + 1
            end
        end
    end

    -- Count text
    if self._textManager then
        for i = 1, self._textManager:GetTextCount() do
            local text = self._textManager:GetText(i)
            if text and text.group == groupId then
                counts.texts = counts.texts + 1
            end
        end
    end

    -- Count icons
    if self._iconManager then
        for i = 1, self._iconManager:GetIconCount() do
            local icon = self._iconManager:GetIcon(i)
            if icon and icon.group == groupId then
                counts.icons = counts.icons + 1
            end
        end
    end

    -- Count images
    if self._imageManager then
        for i = 1, self._imageManager:GetImageCount() do
            local image = self._imageManager:GetImage(i)
            if image and image.group == groupId then
                counts.images = counts.images + 1
            end
        end
    end

    counts.total = counts.dots + counts.shapes + counts.texts + counts.icons + counts.images

    return counts
end

-- ============================================================================
-- Group Merging
-- ============================================================================

--- Merge one group into another
-- Reassigns all elements from source group to target group, then deletes source
-- Does nothing if either group is locked
-- @param sourceGroupId number Source group ID (will be deleted)
-- @param targetGroupId number Target group ID (will receive all elements)
-- @return self for chaining
function LoolibCanvasGroupMixin:MergeGroups(sourceGroupId, targetGroupId)
    if self:IsGroupLocked(sourceGroupId) or self:IsGroupLocked(targetGroupId) then
        return self
    end

    -- Reassign all elements from source to target
    if self._brushManager then
        for i = 1, self._brushManager:GetDotCount() do
            local dot = self._brushManager:GetDot(i)
            if dot and dot.group == sourceGroupId then
                dot.group = targetGroupId
            end
        end
    end

    if self._shapeManager then
        for i = 1, self._shapeManager:GetShapeCount() do
            local shape = self._shapeManager:GetShape(i)
            if shape and shape.group == sourceGroupId then
                shape.group = targetGroupId
            end
        end
    end

    if self._textManager then
        for i = 1, self._textManager:GetTextCount() do
            local text = self._textManager:GetText(i)
            if text and text.group == sourceGroupId then
                text.group = targetGroupId
            end
        end
    end

    if self._iconManager then
        for i = 1, self._iconManager:GetIconCount() do
            local icon = self._iconManager:GetIcon(i)
            if icon and icon.group == sourceGroupId then
                icon.group = targetGroupId
            end
        end
    end

    if self._imageManager then
        for i = 1, self._imageManager:GetImageCount() do
            local image = self._imageManager:GetImage(i)
            if image and image.group == sourceGroupId then
                image.group = targetGroupId
            end
        end
    end

    -- Delete source group metadata
    self:DeleteGroup(sourceGroupId, false)

    if self.TriggerEvent then
        self:TriggerEvent("OnGroupsMerged", sourceGroupId, targetGroupId)
    end

    return self
end

-- ============================================================================
-- Serialization
-- ============================================================================

--- Serialize group data for saving
-- @return table Serialized group data
function LoolibCanvasGroupMixin:SerializeGroups()
    local data = {
        groups = {},
        lockedGroups = {},
        nextGroupId = self._nextGroupId,
    }

    -- Serialize group metadata (compact format)
    for id, info in pairs(self._groups) do
        data.groups[id] = {
            n = info.name,
            l = info.locked or nil,        -- Only store if true
            v = info.visible == false and false or nil,  -- Only store if false
        }
    end

    -- Serialize locked groups list (for fast lookup on deserialize)
    for id in pairs(self._lockedGroups) do
        data.lockedGroups[#data.lockedGroups + 1] = id
    end

    return data
end

--- Deserialize group data from saved state
-- @param data table Serialized group data
-- @return self for chaining
function LoolibCanvasGroupMixin:DeserializeGroups(data)
    if not data then return self end

    self._groups = {}
    self._lockedGroups = {}
    self._nextGroupId = data.nextGroupId or 1

    -- Restore group metadata
    for id, info in pairs(data.groups or {}) do
        local groupId = tonumber(id)
        self._groups[groupId] = {
            name = info.n or ("Group " .. id),
            locked = info.l or false,
            visible = info.v ~= false,
        }
    end

    -- Restore locked groups lookup
    for _, id in ipairs(data.lockedGroups or {}) do
        self._lockedGroups[id] = true
    end

    return self
end

--- Clear all groups
-- Optionally delete all elements in groups
-- @param deleteElements boolean If true, delete all grouped elements
-- @return self for chaining
function LoolibCanvasGroupMixin:Clear(deleteElements)
    if deleteElements then
        for groupId in pairs(self._groups) do
            if not self:IsGroupLocked(groupId) then
                self:DeleteElementsByGroup(groupId)
            end
        end
    end

    self._groups = {}
    self._lockedGroups = {}
    self._nextGroupId = 1
    self._currentGroup = 0

    if self.TriggerEvent then
        self:TriggerEvent("OnGroupsCleared")
    end

    return self
end

-- ============================================================================
-- Factory Function
-- ============================================================================

--- Create a new canvas group manager
-- @return table Canvas group manager with LoolibCanvasGroupMixin
local function LoolibCreateCanvasGroup()
    local groupManager = {}
    Loolib.Mixin(groupManager, LoolibCanvasGroupMixin)
    groupManager:OnLoad()
    return groupManager
end

-- ============================================================================
-- Module Registration
-- ============================================================================

Loolib:RegisterModule("CanvasGroup", {
    Mixin = LoolibCanvasGroupMixin,
    Create = LoolibCreateCanvasGroup,
})
