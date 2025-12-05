--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    LayoutBase - Base mixin for all layout managers

    Provides common functionality for layout systems including
    dirty flagging, child management, and content size calculation.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibBaseLayoutMixin

    Base mixin that all layout types inherit from.
----------------------------------------------------------------------]]

LoolibBaseLayoutMixin = {}

--- Initialize the layout
-- @param container Frame - The container frame to manage
-- @param config table - Configuration options
function LoolibBaseLayoutMixin:Init(container, config)
    self.container = container
    self.children = {}
    self.config = config or {}
    self.dirty = true
    self.layoutPending = false

    -- Default configuration
    self.config.padding = self.config.padding or 0
    self.config.paddingLeft = self.config.paddingLeft or self.config.padding
    self.config.paddingRight = self.config.paddingRight or self.config.padding
    self.config.paddingTop = self.config.paddingTop or self.config.padding
    self.config.paddingBottom = self.config.paddingBottom or self.config.padding
    self.config.spacing = self.config.spacing or 0
    self.config.autoSize = self.config.autoSize ~= false

    -- Content size tracking
    self.contentWidth = 0
    self.contentHeight = 0
end

--[[--------------------------------------------------------------------
    Child Management
----------------------------------------------------------------------]]

--- Add a child to the layout
-- @param child Region - The child region to add
-- @param index number - Optional index to insert at
-- @return number - The index of the added child
function LoolibBaseLayoutMixin:AddChild(child, index)
    if not child then
        return nil
    end

    -- Remove from current parent layout if any
    if child.parentLayout then
        child.parentLayout:RemoveChild(child)
    end

    -- Insert at index or append
    if index and index >= 1 and index <= #self.children + 1 then
        table.insert(self.children, index, child)
    else
        self.children[#self.children + 1] = child
        index = #self.children
    end

    child.parentLayout = self
    child:SetParent(self.container)

    self:MarkDirty()
    return index
end

--- Add multiple children
-- @param ... Region - Children to add
function LoolibBaseLayoutMixin:AddChildren(...)
    for i = 1, select("#", ...) do
        self:AddChild(select(i, ...))
    end
end

--- Remove a child from the layout
-- @param child Region - The child to remove
-- @return boolean - True if removed
function LoolibBaseLayoutMixin:RemoveChild(child)
    for i, c in ipairs(self.children) do
        if c == child then
            table.remove(self.children, i)
            child.parentLayout = nil
            self:MarkDirty()
            return true
        end
    end
    return false
end

--- Remove a child by index
-- @param index number - The index to remove
-- @return Region|nil - The removed child
function LoolibBaseLayoutMixin:RemoveChildByIndex(index)
    if index >= 1 and index <= #self.children then
        local child = table.remove(self.children, index)
        child.parentLayout = nil
        self:MarkDirty()
        return child
    end
    return nil
end

--- Remove all children
function LoolibBaseLayoutMixin:ClearChildren()
    for _, child in ipairs(self.children) do
        child.parentLayout = nil
    end
    wipe(self.children)
    self:MarkDirty()
end

--- Get a child by index
-- @param index number - The index
-- @return Region|nil - The child
function LoolibBaseLayoutMixin:GetChild(index)
    return self.children[index]
end

--- Get all children
-- @return table - Array of children
function LoolibBaseLayoutMixin:GetChildren()
    return self.children
end

--- Get the number of children
-- @return number
function LoolibBaseLayoutMixin:GetNumChildren()
    return #self.children
end

--- Check if the layout has children
-- @return boolean
function LoolibBaseLayoutMixin:HasChildren()
    return #self.children > 0
end

--- Iterate over children
-- @return iterator
function LoolibBaseLayoutMixin:EnumerateChildren()
    return ipairs(self.children)
end

--- Find child index
-- @param child Region - The child to find
-- @return number|nil - The index or nil
function LoolibBaseLayoutMixin:FindChildIndex(child)
    for i, c in ipairs(self.children) do
        if c == child then
            return i
        end
    end
    return nil
end

--- Move a child to a new index
-- @param child Region - The child to move
-- @param newIndex number - The new index
function LoolibBaseLayoutMixin:MoveChild(child, newIndex)
    local currentIndex = self:FindChildIndex(child)
    if currentIndex and newIndex ~= currentIndex then
        table.remove(self.children, currentIndex)
        if newIndex > currentIndex then
            newIndex = newIndex - 1
        end
        table.insert(self.children, newIndex, child)
        self:MarkDirty()
    end
end

--[[--------------------------------------------------------------------
    Dirty Flag Management
----------------------------------------------------------------------]]

--- Mark the layout as dirty (needs recalculation)
function LoolibBaseLayoutMixin:MarkDirty()
    self.dirty = true

    -- Schedule deferred layout if not already pending
    if not self.layoutPending and self.container:IsShown() then
        self.layoutPending = true
        C_Timer.After(0, function()
            self.layoutPending = false
            if self.dirty then
                self:Layout()
            end
        end)
    end
end

--- Mark the layout as clean
function LoolibBaseLayoutMixin:MarkClean()
    self.dirty = false
end

--- Check if the layout is dirty
-- @return boolean
function LoolibBaseLayoutMixin:IsDirty()
    return self.dirty
end

--- Force an immediate layout
function LoolibBaseLayoutMixin:ForceLayout()
    self.dirty = true
    self:Layout()
end

--[[--------------------------------------------------------------------
    Layout Calculation (Abstract)
----------------------------------------------------------------------]]

--- Perform layout calculation
-- Subclasses MUST override this method
function LoolibBaseLayoutMixin:Layout()
    error("LoolibBaseLayoutMixin:Layout must be overridden by subclass")
end

--[[--------------------------------------------------------------------
    Content Size
----------------------------------------------------------------------]]

--- Get the content size
-- @return number, number - width, height
function LoolibBaseLayoutMixin:GetContentSize()
    return self.contentWidth, self.contentHeight
end

--- Set the content size (internal)
-- @param width number
-- @param height number
function LoolibBaseLayoutMixin:SetContentSize(width, height)
    self.contentWidth = width
    self.contentHeight = height

    -- Auto-size container if enabled
    if self.config.autoSize then
        local totalWidth = width + self.config.paddingLeft + self.config.paddingRight
        local totalHeight = height + self.config.paddingTop + self.config.paddingBottom

        self.container:SetSize(totalWidth, totalHeight)
    end
end

--- Get the available space for children
-- @return number, number - available width, height
function LoolibBaseLayoutMixin:GetAvailableSpace()
    local width = self.container:GetWidth() - self.config.paddingLeft - self.config.paddingRight
    local height = self.container:GetHeight() - self.config.paddingTop - self.config.paddingBottom
    return math.max(0, width), math.max(0, height)
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set padding
-- @param left number - Left padding
-- @param right number - Right padding
-- @param top number - Top padding
-- @param bottom number - Bottom padding
function LoolibBaseLayoutMixin:SetPadding(left, right, top, bottom)
    self.config.paddingLeft = left
    self.config.paddingRight = right or left
    self.config.paddingTop = top or left
    self.config.paddingBottom = bottom or top or left
    self:MarkDirty()
end

--- Set uniform padding
-- @param padding number - Padding for all sides
function LoolibBaseLayoutMixin:SetUniformPadding(padding)
    self:SetPadding(padding, padding, padding, padding)
end

--- Set spacing between children
-- @param spacing number - Spacing in pixels
function LoolibBaseLayoutMixin:SetSpacing(spacing)
    self.config.spacing = spacing
    self:MarkDirty()
end

--- Set auto-size behavior
-- @param autoSize boolean - Whether to auto-size container
function LoolibBaseLayoutMixin:SetAutoSize(autoSize)
    self.config.autoSize = autoSize
end

--- Get the container frame
-- @return Frame
function LoolibBaseLayoutMixin:GetContainer()
    return self.container
end

--- Get configuration
-- @return table
function LoolibBaseLayoutMixin:GetConfig()
    return self.config
end

--[[--------------------------------------------------------------------
    Visibility Helpers
----------------------------------------------------------------------]]

--- Get visible children only
-- @return table - Array of visible children
function LoolibBaseLayoutMixin:GetVisibleChildren()
    local visible = {}
    for _, child in ipairs(self.children) do
        if child:IsShown() then
            visible[#visible + 1] = child
        end
    end
    return visible
end

--- Get number of visible children
-- @return number
function LoolibBaseLayoutMixin:GetNumVisibleChildren()
    local count = 0
    for _, child in ipairs(self.children) do
        if child:IsShown() then
            count = count + 1
        end
    end
    return count
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Get the size of a child (respecting layout hints)
-- @param child Region - The child
-- @return number, number - width, height
function LoolibBaseLayoutMixin:GetChildSize(child)
    -- Check for layout hints
    local width = child.layoutWidth or child:GetWidth()
    local height = child.layoutHeight or child:GetHeight()
    return width, height
end

--- Check if a child should stretch
-- @param child Region - The child
-- @param axis string - "width" or "height"
-- @return boolean
function LoolibBaseLayoutMixin:ShouldStretch(child, axis)
    if axis == "width" then
        return child.layoutStretchWidth == true
    elseif axis == "height" then
        return child.layoutStretchHeight == true
    end
    return false
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local LayoutBaseModule = {
    Mixin = LoolibBaseLayoutMixin,
}

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.LayoutBase = LayoutBaseModule

Loolib:RegisterModule("LayoutBase", LayoutBaseModule)
