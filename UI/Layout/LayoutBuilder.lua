--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    LayoutBuilder - Fluent API for creating layouts

    Example usage:
        local vbox = UI.Layout(container)
            :Vertical()
            :Spacing(5)
            :Padding(10)
            :AlignItems("LEFT")
            :Build()

        vbox:AddChild(button1)
        vbox:AddChild(button2)
        vbox:Layout()
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for LayoutBuilder")
local CreateVerticalLayout = assert(Loolib.CreateVerticalLayout, "Loolib.CreateVerticalLayout is required for LayoutBuilder")
local CreateHorizontalLayout = assert(Loolib.CreateHorizontalLayout, "Loolib.CreateHorizontalLayout is required for LayoutBuilder")
local CreateGridLayout = assert(Loolib.CreateGridLayout, "Loolib.CreateGridLayout is required for LayoutBuilder")
local CreateFlowLayout = assert(Loolib.CreateFlowLayout, "Loolib.CreateFlowLayout is required for LayoutBuilder")
local Layout = Loolib.Layout or Loolib:GetOrCreateModule("Layout")
local LayoutBuilderModule = Layout.LayoutBuilder or Loolib:GetModule("Layout.LayoutBuilder") or {}

--[[--------------------------------------------------------------------
    LoolibLayoutBuilderMixin

    Fluent builder for creating layout instances.
----------------------------------------------------------------------]]

local LayoutBuilderMixin = LayoutBuilderModule.Mixin or {}

--- Initialize the layout builder
-- @param container Frame - Container frame for the layout
function LayoutBuilderMixin:Init(container)
    if not container then
        error("LoolibLayoutBuilder: Init: container is required", 2)
    end
    self.container = container
    self.layoutType = "VERTICAL"
    self.config = {}
end

--[[--------------------------------------------------------------------
    Layout Type Selection
----------------------------------------------------------------------]]

--- Create a vertical layout
-- @return self
function LayoutBuilderMixin:Vertical()
    self.layoutType = "VERTICAL"
    return self
end

--- Create a horizontal layout
-- @return self
function LayoutBuilderMixin:Horizontal()
    self.layoutType = "HORIZONTAL"
    return self
end

--- Create a grid layout
-- @param columns number - Number of columns
-- @return self
function LayoutBuilderMixin:Grid(columns)
    self.layoutType = "GRID"
    self.config.columns = columns or 4
    return self
end

--- Create a flow layout
-- @param direction string - "HORIZONTAL" or "VERTICAL" (default HORIZONTAL)
-- @return self
function LayoutBuilderMixin:Flow(direction)
    self.layoutType = "FLOW"
    self.config.direction = direction or "HORIZONTAL"
    return self
end

--[[--------------------------------------------------------------------
    Common Configuration
----------------------------------------------------------------------]]

--- Set spacing between children
-- @param spacing number - Spacing in pixels
-- @return self
function LayoutBuilderMixin:Spacing(spacing)
    self.config.spacing = spacing
    return self
end

--- Set uniform padding
-- @param padding number - Padding for all sides
-- @return self
function LayoutBuilderMixin:Padding(padding)
    self.config.padding = padding
    return self
end

--- Set padding per side
-- @param left number - Left padding
-- @param right number - Right padding
-- @param top number - Top padding
-- @param bottom number - Bottom padding
-- @return self
function LayoutBuilderMixin:PaddingEach(left, right, top, bottom)
    self.config.paddingLeft = left
    self.config.paddingRight = right or left
    self.config.paddingTop = top or left
    self.config.paddingBottom = bottom or top or left
    return self
end

--- Set auto-size behavior
-- @param autoSize boolean - Whether container should auto-size to content
-- @return self
function LayoutBuilderMixin:AutoSize(autoSize)
    self.config.autoSize = autoSize
    return self
end

--[[--------------------------------------------------------------------
    Alignment Configuration (Vertical/Horizontal)
----------------------------------------------------------------------]]

--- Set item alignment
-- For Vertical: LEFT, CENTER, RIGHT, STRETCH
-- For Horizontal: TOP, CENTER, BOTTOM, STRETCH
-- @param align string
-- @return self
function LayoutBuilderMixin:AlignItems(align)
    self.config.alignItems = align
    return self
end

--- Set content justification
-- START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND
-- @param justify string
-- @return self
function LayoutBuilderMixin:JustifyContent(justify)
    self.config.justifyContent = justify
    return self
end

--- Set layout direction for vertical/horizontal layouts
-- @param direction string - DOWN/UP for vertical, RIGHT/LEFT for horizontal
-- @return self
function LayoutBuilderMixin:Direction(direction)
    self.config.direction = direction
    return self
end

--[[--------------------------------------------------------------------
    Grid Configuration
----------------------------------------------------------------------]]

--- Set number of columns (grid)
-- @param columns number
-- @return self
function LayoutBuilderMixin:Columns(columns)
    self.config.columns = columns
    return self
end

--- Set number of rows (grid)
-- @param rows number
-- @return self
function LayoutBuilderMixin:Rows(rows)
    self.config.rows = rows
    return self
end

--- Set cell size (grid)
-- @param width number
-- @param height number
-- @return self
function LayoutBuilderMixin:CellSize(width, height)
    self.config.cellWidth = width
    self.config.cellHeight = height or width
    return self
end

--- Set cell spacing (grid)
-- @param columnSpacing number
-- @param rowSpacing number
-- @return self
function LayoutBuilderMixin:CellSpacing(columnSpacing, rowSpacing)
    self.config.columnSpacing = columnSpacing
    self.config.rowSpacing = rowSpacing or columnSpacing
    return self
end

--- Set fill direction (grid)
-- @param direction string - ROW or COLUMN
-- @return self
function LayoutBuilderMixin:FillDirection(direction)
    self.config.fillDirection = direction
    return self
end

--- Set whether to resize children to fit cells (grid)
-- @param resize boolean
-- @return self
function LayoutBuilderMixin:ResizeToFit(resize)
    self.config.resizeToFit = resize ~= false
    return self
end

--[[--------------------------------------------------------------------
    Flow Configuration
----------------------------------------------------------------------]]

--- Set wrap spacing (flow)
-- @param spacing number - Spacing between wrapped rows/columns
-- @return self
function LayoutBuilderMixin:WrapSpacing(spacing)
    self.config.wrapSpacing = spacing
    return self
end

--- Set content alignment (flow)
-- @param align string - START, CENTER, END
-- @return self
function LayoutBuilderMixin:AlignContent(align)
    self.config.alignContent = align
    return self
end

--[[--------------------------------------------------------------------
    Build Methods
----------------------------------------------------------------------]]

--- Build and return the layout
-- @return table - The layout instance
function LayoutBuilderMixin:Build()
    if not self.container then
        error("LoolibLayoutBuilder: Build: no container set (call Init first)", 2)
    end

    local layout

    if self.layoutType == "VERTICAL" then
        layout = CreateVerticalLayout(self.container, self.config)
    elseif self.layoutType == "HORIZONTAL" then
        layout = CreateHorizontalLayout(self.container, self.config)
    elseif self.layoutType == "GRID" then
        layout = CreateGridLayout(self.container, self.config)
    elseif self.layoutType == "FLOW" then
        layout = CreateFlowLayout(self.container, self.config)
    else
        error("LoolibLayoutBuilder: Build: unknown layout type '" .. tostring(self.layoutType) .. "'", 2)
    end

    -- Store layout reference on container
    self.container.layout = layout

    return layout
end

--- Build the layout and add children
-- @param ... Region - Children to add
-- @return table - The layout instance
function LayoutBuilderMixin:BuildWithChildren(...)
    local layout = self:Build()

    for i = 1, select("#", ...) do
        layout:AddChild(select(i, ...))
    end

    layout:Layout()
    return layout
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new layout builder
-- @param container Frame - Container frame
-- @return LoolibLayoutBuilderMixin
local function CreateLayoutBuilder(container)
    if not container then
        error("LoolibLayoutBuilder: CreateLayoutBuilder: container is required", 2)
    end
    local builder = CreateFromMixins(LayoutBuilderMixin)
    builder:Init(container)
    return builder
end

--[[--------------------------------------------------------------------
    Convenience Function
----------------------------------------------------------------------]]

--- UI.Layout() - Entry point for fluent layout creation
-- @param container Frame - Container frame
-- @return LoolibLayoutBuilderMixin
local function BuildLayout(container)
    if not container then
        error("LoolibLayoutBuilder: Layout: container is required", 2)
    end
    return CreateLayoutBuilder(container)
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

LayoutBuilderModule.Mixin = LayoutBuilderMixin
LayoutBuilderModule.Create = CreateLayoutBuilder
LayoutBuilderModule.Layout = BuildLayout

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.LayoutBuilder = LayoutBuilderModule
UI.Layout = BuildLayout
UI.CreateVerticalLayout = CreateVerticalLayout
UI.CreateHorizontalLayout = CreateHorizontalLayout
UI.CreateGridLayout = CreateGridLayout
UI.CreateFlowLayout = CreateFlowLayout

Layout.LayoutBuilder = LayoutBuilderModule
Loolib.LayoutBuilderMixin = LayoutBuilderMixin
Loolib.CreateLayoutBuilder = CreateLayoutBuilder
Loolib.LayoutBuilder = BuildLayout

Loolib:RegisterModule("Layout.LayoutBuilder", LayoutBuilderModule)
