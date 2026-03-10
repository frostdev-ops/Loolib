-------------------------------------------------------------------------------
-- CanvasText.lua
-- Text label management for Loolib Canvas system
-------------------------------------------------------------------------------
-- This module provides text label functionality for the canvas, allowing users
-- to place, edit, and manage text annotations with configurable size, color,
-- and grouping. Uses parallel arrays for efficient storage and retrieval,
-- following the pattern established by MRT's VisNote system.
--
-- Usage:
--   local Loolib = LibStub("Loolib")
--   local CanvasText = Loolib:GetModule("CanvasText")
--
--   local textManager = CanvasText.Create()
--   textManager:SetTextSize(14):SetTextColor(11)
--   local index = textManager:AddText(100, 200, "Hello World")
--   textManager:UpdateText(index, "Updated Text")
--
-- @module CanvasText
-- @author James Kueller
-- @copyright 2025
-- @license MIT
-------------------------------------------------------------------------------

local LOOLIB_VERSION = 1
local Loolib = LibStub and LibStub("Loolib", true)
if not Loolib then return end

-------------------------------------------------------------------------------
-- LoolibCanvasTextMixin
-------------------------------------------------------------------------------
-- Mixin providing text label management functionality for canvas systems.
-- Stores text annotations with position, size, color, and grouping data using
-- parallel arrays for optimal performance during iteration and rendering.
--
-- @class LoolibCanvasTextMixin
-- @field _textSize number Default text size for new labels (8-32)
-- @field _textColor number Default color index for new labels
-- @field _currentGroup number Current group ID for new labels
-- @field _text_X table Parallel array: X coordinates
-- @field _text_Y table Parallel array: Y coordinates
-- @field _text_DATA table Parallel array: Text content strings
-- @field _text_SIZE table Parallel array: Font sizes
-- @field _text_COLOR table Parallel array: Color indices
-- @field _text_GROUP table Parallel array: Group IDs
-- @field _text_SYNC table Parallel array: Sync IDs for network operations
-- @field _nextSyncId number Next available sync ID
-------------------------------------------------------------------------------
local LoolibCanvasTextMixin = {}

-------------------------------------------------------------------------------
-- Initializes the text manager with default settings and storage.
-- Called automatically by factory function.
--
-- @function LoolibCanvasTextMixin:OnLoad
-- @return self
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:OnLoad()
	-- Default settings
	self._textSize = 12
	self._textColor = 11  -- White default
	self._currentGroup = 0

	-- Text storage (parallel arrays for performance)
	self._texts = {}
	self._text_X = {}
	self._text_Y = {}
	self._text_DATA = {}     -- The actual text string
	self._text_SIZE = {}
	self._text_COLOR = {}
	self._text_GROUP = {}
	self._text_SYNC = {}

	self._nextSyncId = 1

	return self
end

-------------------------------------------------------------------------------
-- Text Settings
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Sets the default text size for new labels.
-- Size is clamped to the range [8, 32] for readability.
--
-- @function LoolibCanvasTextMixin:SetTextSize
-- @param size number Font size in pixels (8-32)
-- @return self For method chaining
-- @usage textManager:SetTextSize(14):SetTextColor(11)
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:SetTextSize(size)
	self._textSize = math.max(8, math.min(32, size))
	return self
end

-------------------------------------------------------------------------------
-- Gets the current default text size.
--
-- @function LoolibCanvasTextMixin:GetTextSize
-- @return number Current default text size
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:GetTextSize()
	return self._textSize
end

-------------------------------------------------------------------------------
-- Sets the default color index for new labels.
-- Color index maps to a predefined color palette (implementation-specific).
--
-- @function LoolibCanvasTextMixin:SetTextColor
-- @param colorIndex number Color palette index
-- @return self For method chaining
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:SetTextColor(colorIndex)
	self._textColor = colorIndex
	return self
end

-------------------------------------------------------------------------------
-- Gets the current default color index.
--
-- @function LoolibCanvasTextMixin:GetTextColor
-- @return number Current default color index
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:GetTextColor()
	return self._textColor
end

-------------------------------------------------------------------------------
-- Sets the current group ID for new labels.
-- Groups allow batch operations (move, delete) on related labels.
--
-- @function LoolibCanvasTextMixin:SetCurrentGroup
-- @param groupId number|nil Group identifier (nil = 0)
-- @return self For method chaining
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:SetCurrentGroup(groupId)
	self._currentGroup = groupId or 0
	return self
end

-------------------------------------------------------------------------------
-- Text Management
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Adds a new text label at the specified position.
-- Returns the array index of the newly created label for later reference.
-- Triggers "OnTextAdded" event if TriggerEvent is available.
--
-- @function LoolibCanvasTextMixin:AddText
-- @param x number X coordinate on canvas
-- @param y number Y coordinate on canvas
-- @param text string Text content to display
-- @param size number|nil Font size (defaults to current _textSize)
-- @param color number|nil Color index (defaults to current _textColor)
-- @param group number|nil Group ID (defaults to current _currentGroup)
-- @return number|nil Index of added text, or nil if text is empty
-- @usage local idx = textManager:AddText(100, 200, "Boss Position", 16, 11, 1)
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:AddText(x, y, text, size, color, group)
	if not text or text == "" then return nil end

	local index = #self._text_X + 1

	self._text_X[index] = x
	self._text_Y[index] = y
	self._text_DATA[index] = text
	self._text_SIZE[index] = size or self._textSize
	self._text_COLOR[index] = color or self._textColor
	self._text_GROUP[index] = group or self._currentGroup
	self._text_SYNC[index] = self._nextSyncId
	self._nextSyncId = self._nextSyncId + 1

	if self.TriggerEvent then
		self:TriggerEvent("OnTextAdded", index)
	end

	return index
end

-------------------------------------------------------------------------------
-- Updates the content of an existing text label.
-- Triggers "OnTextUpdated" event if TriggerEvent is available.
--
-- @function LoolibCanvasTextMixin:UpdateText
-- @param index number Index of text to update
-- @param newText string New text content (empty string to clear)
-- @return self For method chaining
-- @usage textManager:UpdateText(5, "Updated Label")
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:UpdateText(index, newText)
	if not self._text_X[index] then return self end
	self._text_DATA[index] = newText or ""

	if self.TriggerEvent then
		self:TriggerEvent("OnTextUpdated", index)
	end

	return self
end

-------------------------------------------------------------------------------
-- Retrieves a text label's complete data by index.
-- Returns a table containing all properties of the label.
--
-- @function LoolibCanvasTextMixin:GetText
-- @param index number Index of text to retrieve
-- @return table|nil Table with fields: x, y, text, size, color, group, syncId
-- @usage local data = textManager:GetText(5)
--        if data then print(data.text, data.x, data.y) end
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:GetText(index)
	if not self._text_X[index] then return nil end
	return {
		x = self._text_X[index],
		y = self._text_Y[index],
		text = self._text_DATA[index],
		size = self._text_SIZE[index],
		color = self._text_COLOR[index],
		group = self._text_GROUP[index],
		syncId = self._text_SYNC[index],
	}
end

-------------------------------------------------------------------------------
-- Retrieves all text labels as an array of data tables.
-- Useful for rendering or serialization operations.
--
-- @function LoolibCanvasTextMixin:GetAllTexts
-- @return table Array of text data tables
-- @usage for i, text in ipairs(textManager:GetAllTexts()) do
--          -- Render text.text at (text.x, text.y)
--        end
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:GetAllTexts()
	local result = {}
	for i = 1, #self._text_X do
		result[i] = self:GetText(i)
	end
	return result
end

-------------------------------------------------------------------------------
-- Returns the total number of text labels.
--
-- @function LoolibCanvasTextMixin:GetTextCount
-- @return number Total text label count
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:GetTextCount()
	return #self._text_X
end

-------------------------------------------------------------------------------
-- Text Removal
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Removes all text labels from the canvas.
-- Triggers "OnTextsCleared" event if TriggerEvent is available.
--
-- @function LoolibCanvasTextMixin:ClearTexts
-- @return self For method chaining
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:ClearTexts()
	self._texts = {}
	self._text_X = {}
	self._text_Y = {}
	self._text_DATA = {}
	self._text_SIZE = {}
	self._text_COLOR = {}
	self._text_GROUP = {}
	self._text_SYNC = {}

	if self.TriggerEvent then
		self:TriggerEvent("OnTextsCleared")
	end

	return self
end

-------------------------------------------------------------------------------
-- Deletes a single text label by index.
-- All subsequent labels are shifted down to maintain array continuity.
-- Triggers "OnTextDeleted" event if TriggerEvent is available.
--
-- @function LoolibCanvasTextMixin:DeleteText
-- @param index number Index of text to delete
-- @return self For method chaining
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:DeleteText(index)
	if not self._text_X[index] then return self end

	-- Shift all elements after index
	for i = index, #self._text_X - 1 do
		self._text_X[i] = self._text_X[i + 1]
		self._text_Y[i] = self._text_Y[i + 1]
		self._text_DATA[i] = self._text_DATA[i + 1]
		self._text_SIZE[i] = self._text_SIZE[i + 1]
		self._text_COLOR[i] = self._text_COLOR[i + 1]
		self._text_GROUP[i] = self._text_GROUP[i + 1]
		self._text_SYNC[i] = self._text_SYNC[i + 1]
	end

	-- Remove last element
	local n = #self._text_X
	self._text_X[n] = nil
	self._text_Y[n] = nil
	self._text_DATA[n] = nil
	self._text_SIZE[n] = nil
	self._text_COLOR[n] = nil
	self._text_GROUP[n] = nil
	self._text_SYNC[n] = nil

	if self.TriggerEvent then
		self:TriggerEvent("OnTextDeleted", index)
	end

	return self
end

-------------------------------------------------------------------------------
-- Deletes all text labels belonging to a specific group.
-- Uses array rebuilding to avoid index shifting overhead.
--
-- @function LoolibCanvasTextMixin:DeleteTextsByGroup
-- @param groupId number Group identifier to delete
-- @return self For method chaining
-- @usage textManager:DeleteTextsByGroup(1)  -- Remove all group 1 labels
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:DeleteTextsByGroup(groupId)
	local newX, newY, newData, newSize, newColor, newGroup, newSync =
		{}, {}, {}, {}, {}, {}, {}

	for i = 1, #self._text_X do
		if self._text_GROUP[i] ~= groupId then
			local n = #newX + 1
			newX[n] = self._text_X[i]
			newY[n] = self._text_Y[i]
			newData[n] = self._text_DATA[i]
			newSize[n] = self._text_SIZE[i]
			newColor[n] = self._text_COLOR[i]
			newGroup[n] = self._text_GROUP[i]
			newSync[n] = self._text_SYNC[i]
		end
	end

	self._text_X, self._text_Y = newX, newY
	self._text_DATA, self._text_SIZE = newData, newSize
	self._text_COLOR, self._text_GROUP = newColor, newGroup
	self._text_SYNC = newSync

	return self
end

-------------------------------------------------------------------------------
-- Text Manipulation
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Moves all text labels in a group by the specified delta.
-- Useful for repositioning related annotations together.
--
-- @function LoolibCanvasTextMixin:MoveTextsByGroup
-- @param groupId number Group identifier to move
-- @param deltaX number Horizontal offset to apply
-- @param deltaY number Vertical offset to apply
-- @return self For method chaining
-- @usage textManager:MoveTextsByGroup(1, 50, -20)  -- Move group 1 right and up
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:MoveTextsByGroup(groupId, deltaX, deltaY)
	for i = 1, #self._text_X do
		if self._text_GROUP[i] == groupId then
			self._text_X[i] = self._text_X[i] + deltaX
			self._text_Y[i] = self._text_Y[i] + deltaY
		end
	end
	return self
end

-------------------------------------------------------------------------------
-- Moves a single text label to a new position.
--
-- @function LoolibCanvasTextMixin:MoveText
-- @param index number Index of text to move
-- @param x number New X coordinate
-- @param y number New Y coordinate
-- @return self For method chaining
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:MoveText(index, x, y)
	if not self._text_X[index] then return self end
	self._text_X[index] = x
	self._text_Y[index] = y
	return self
end

-------------------------------------------------------------------------------
-- Hit Testing
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Finds the topmost text label at or near a given position.
-- Searches in reverse order (most recently added first) to prioritize
-- overlapping labels correctly. Uses a simple rectangular hit test.
--
-- @function LoolibCanvasTextMixin:FindTextAt
-- @param x number X coordinate to test
-- @param y number Y coordinate to test
-- @param tolerance number|nil Hit test radius in pixels (default: 20)
-- @return number|nil Index of found text label, or nil if none found
-- @usage local idx = textManager:FindTextAt(mouseX, mouseY, 15)
--        if idx then print("Clicked on:", textManager:GetText(idx).text) end
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:FindTextAt(x, y, tolerance)
	tolerance = tolerance or 20

	for i = #self._text_X, 1, -1 do  -- Reverse order (top-most first)
		local tx, ty = self._text_X[i], self._text_Y[i]
		local dx, dy = math.abs(x - tx), math.abs(y - ty)

		-- Rough hit test (actual rendering would need font metrics)
		if dx < tolerance and dy < tolerance then
			return i
		end
	end

	return nil
end

-------------------------------------------------------------------------------
-- Serialization
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Serializes all text labels to a compact table format.
-- Uses abbreviated field names to reduce data size for network sync or
-- saved variables. Excludes sync IDs as they're regenerated on load.
--
-- @function LoolibCanvasTextMixin:SerializeTexts
-- @return table Array of text data tables with fields: x, y, t, s, c, g
-- @usage local data = textManager:SerializeTexts()
--        MyAddonDB.texts = data
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:SerializeTexts()
	local data = {}
	for i = 1, #self._text_X do
		data[i] = {
			x = self._text_X[i],
			y = self._text_Y[i],
			t = self._text_DATA[i],
			s = self._text_SIZE[i],
			c = self._text_COLOR[i],
			g = self._text_GROUP[i],
		}
	end
	return data
end

-------------------------------------------------------------------------------
-- Deserializes text labels from compact table format.
-- Clears existing texts before loading. Regenerates sync IDs sequentially.
--
-- @function LoolibCanvasTextMixin:DeserializeTexts
-- @param data table|nil Array of text data tables (nil = no-op)
-- @return self For method chaining
-- @usage textManager:DeserializeTexts(MyAddonDB.texts)
-------------------------------------------------------------------------------
function LoolibCanvasTextMixin:DeserializeTexts(data)
	self:ClearTexts()
	if not data then return self end

	for i, text in ipairs(data) do
		self._text_X[i] = text.x
		self._text_Y[i] = text.y
		self._text_DATA[i] = text.t or ""
		self._text_SIZE[i] = text.s or 12
		self._text_COLOR[i] = text.c or 11
		self._text_GROUP[i] = text.g or 0
		self._text_SYNC[i] = i
	end
	self._nextSyncId = #data + 1

	return self
end

-------------------------------------------------------------------------------
-- Factory and Module Registration
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Creates a new CanvasText manager instance.
-- Automatically initializes the instance with OnLoad().
--
-- @function LoolibCreateCanvasText
-- @return table Initialized CanvasText manager
-- @usage local textManager = LoolibCreateCanvasText()
-------------------------------------------------------------------------------
local function LoolibCreateCanvasText()
	local textManager = {}
	Loolib.Mixin(textManager, LoolibCanvasTextMixin)
	textManager:OnLoad()
	return textManager
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------
Loolib:RegisterModule("CanvasText", {
	Mixin = LoolibCanvasTextMixin,
	Create = LoolibCreateCanvasText,
})
