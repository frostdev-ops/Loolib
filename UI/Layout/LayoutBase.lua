--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    LayoutBase - Base mixin for all layout managers

    Provides common functionality for layout systems including
    dirty flagging, child management, and content size calculation.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local Layout = Loolib.Layout or Loolib:GetOrCreateModule("Layout")
local LayoutBaseModule = Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase") or {}

--[[--------------------------------------------------------------------
    LoolibBaseLayoutMixin

    Base mixin that all layout types inherit from.
----------------------------------------------------------------------]]

local LayoutBaseMixin = LayoutBaseModule.Mixin or {}

--- Initialize the layout
-- @param container Frame - The container frame to manage
-- @param config table - Configuration options
function LayoutBaseMixin:Init(container, config)
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
function LayoutBaseMixin:AddChild(child, index)
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
function LayoutBaseMixin:AddChildren(...)
    for i = 1, select("#", ...) do
        self:AddChild(select(i, ...))
    end
end

--- Remove a child from the layout
-- @param child Region - The child to remove
-- @return boolean - True if removed
function LayoutBaseMixin:RemoveChild(child)
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
function LayoutBaseMixin:RemoveChildByIndex(index)
    if index >= 1 and index <= #self.children then
        local child = table.remove(self.children, index)
        child.parentLayout = nil
        self:MarkDirty()
        return child
    end
    return nil
end

--- Remove all children
function LayoutBaseMixin:ClearChildren()
    for _, child in ipairs(self.children) do
        child.parentLayout = nil
    end
    wipe(self.children)
    self:MarkDirty()
end

--- Get a child by index
-- @param index number - The index
-- @return Region|nil - The child
function LayoutBaseMixin:GetChild(index)
    return self.children[index]
end

--- Get all children
-- @return table - Array of children
function LayoutBaseMixin:GetChildren()
    return self.children
end

--- Get the number of children
-- @return number
function LayoutBaseMixin:GetNumChildren()
    return #self.children
end

--- Check if the layout has children
-- @return boolean
function LayoutBaseMixin:HasChildren()
    return #self.children > 0
end

--- Iterate over children
-- @return iterator
function LayoutBaseMixin:EnumerateChildren()
    return ipairs(self.children)
end

--- Find child index
-- @param child Region - The child to find
-- @return number|nil - The index or nil
function LayoutBaseMixin:FindChildIndex(child)
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
function LayoutBaseMixin:MoveChild(child, newIndex)
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
function LayoutBaseMixin:MarkDirty()
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
function LayoutBaseMixin:MarkClean()
    self.dirty = false
end

--- Check if the layout is dirty
-- @return boolean
function LayoutBaseMixin:IsDirty()
    return self.dirty
end

--- Force an immediate layout
function LayoutBaseMixin:ForceLayout()
    self.dirty = true
    self:Layout()
end

--[[--------------------------------------------------------------------
    Layout Calculation (Abstract)
----------------------------------------------------------------------]]

--- Perform layout calculation
-- Subclasses MUST override this method
function LayoutBaseMixin:Layout()
    error("LayoutBaseMixin:Layout must be overridden by subclass")
end

--[[--------------------------------------------------------------------
    Content Size
----------------------------------------------------------------------]]

--- Get the content size
-- @return number, number - width, height
function LayoutBaseMixin:GetContentSize()
    return self.contentWidth, self.contentHeight
end

--- Set the content size (internal)
-- @param width number
-- @param height number
function LayoutBaseMixin:SetContentSize(width, height)
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
function LayoutBaseMixin:GetAvailableSpace()
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
function LayoutBaseMixin:SetPadding(left, right, top, bottom)
    self.config.paddingLeft = left
    self.config.paddingRight = right or left
    self.config.paddingTop = top or left
    self.config.paddingBottom = bottom or top or left
    self:MarkDirty()
end

--- Set uniform padding
-- @param padding number - Padding for all sides
function LayoutBaseMixin:SetUniformPadding(padding)
    self:SetPadding(padding, padding, padding, padding)
end

--- Set spacing between children
-- @param spacing number - Spacing in pixels
function LayoutBaseMixin:SetSpacing(spacing)
    self.config.spacing = spacing
    self:MarkDirty()
end

--- Set auto-size behavior
-- @param autoSize boolean - Whether to auto-size container
function LayoutBaseMixin:SetAutoSize(autoSize)
    self.config.autoSize = autoSize
end

--- Get the container frame
-- @return Frame
function LayoutBaseMixin:GetContainer()
    return self.container
end

--- Get configuration
-- @return table
function LayoutBaseMixin:GetConfig()
    return self.config
end

--[[--------------------------------------------------------------------
    Visibility Helpers
----------------------------------------------------------------------]]

--- Get visible children only
-- @return table - Array of visible children
function LayoutBaseMixin:GetVisibleChildren()
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
function LayoutBaseMixin:GetNumVisibleChildren()
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
function LayoutBaseMixin:GetChildSize(child)
    -- Check for layout hints
    local width = child.layoutWidth or child:GetWidth()
    local height = child.layoutHeight or child:GetHeight()
    return width, height
end

--- Check if a child should stretch
-- @param child Region - The child
-- @param axis string - "width" or "height"
-- @return boolean
function LayoutBaseMixin:ShouldStretch(child, axis)
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

LayoutBaseModule.Mixin = LayoutBaseMixin

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.LayoutBase = LayoutBaseModule

Layout.LayoutBase = LayoutBaseModule
Loolib.LayoutBaseMixin = LayoutBaseMixin

Loolib:RegisterModule("Layout.LayoutBase", LayoutBaseModule)
