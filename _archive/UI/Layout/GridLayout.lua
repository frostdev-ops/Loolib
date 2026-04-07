--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    GridLayout - Arranges children in a grid pattern

    Supports:
    - Fixed number of columns
    - Fixed or auto cell size
    - Cell spacing
    - Row/column gaps
    - Fill direction (row-first or column-first)

    LIMITATION (LY-06): Per-child options.align is not supported.
    All children are anchored at the TOPLEFT of their cell. To align
    a child within its cell, wrap it in a container frame with
    internal anchoring.

    NOTE: Layout calls child:ClearAllPoints() on every managed child.
    External anchors on managed children are destroyed. See LayoutBase
    header comment for details.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for GridLayout")
local Layout = Loolib.Layout or Loolib:GetOrCreateModule("Layout")
local LayoutBaseMixin = assert(
    Loolib.LayoutBaseMixin or ((Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")) and (Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")).Mixin),
    "Loolib.Layout.LayoutBase.Mixin is required for GridLayout"
)
local GridLayoutModule = Layout.GridLayout or Loolib:GetModule("Layout.GridLayout") or {}

-- Cache globals at file top
local type = type
local ipairs = ipairs
local tostring = tostring
local error = error
local math_max = math.max
local math_ceil = math.ceil
local math_floor = math.floor
local math_sqrt = math.sqrt

--[[--------------------------------------------------------------------
    LoolibGridLayoutMixin
----------------------------------------------------------------------]]

local GridLayoutMixin = GridLayoutModule.Mixin or CreateFromMixins(LayoutBaseMixin)

--- Initialize grid layout
-- @param container Frame - The container frame
-- @param config table - Configuration options
function GridLayoutMixin:Init(container, config)
    LayoutBaseMixin.Init(self, container, config)

    -- Grid-specific config
    self.config.columns = self.config.columns or 4
    self.config.rows = self.config.rows  -- nil = auto
    self.config.cellWidth = self.config.cellWidth  -- nil = auto
    self.config.cellHeight = self.config.cellHeight  -- nil = auto
    self.config.cellSpacing = self.config.cellSpacing or 0  -- Uniform spacing
    self.config.columnSpacing = self.config.columnSpacing or self.config.cellSpacing
    self.config.rowSpacing = self.config.rowSpacing or self.config.cellSpacing
    self.config.fillDirection = self.config.fillDirection or "ROW"  -- ROW, COLUMN
    self.config.resizeToFit = self.config.resizeToFit or false
end

--[[--------------------------------------------------------------------
    Configuration Setters
----------------------------------------------------------------------]]

-- INTERNAL: valid fill direction values
local VALID_FILL_DIRECTION = { ROW = true, COLUMN = true }

--- Set the number of columns
-- @param columns number
function GridLayoutMixin:SetColumns(columns)
    if type(columns) ~= "number" or columns < 1 then
        error("LoolibGridLayout: SetColumns: columns must be a positive number", 2)
    end
    self.config.columns = columns
    self:MarkDirty()
end

--- Set the number of rows (nil for auto)
-- @param rows number|nil
function GridLayoutMixin:SetRows(rows)
    if rows ~= nil and (type(rows) ~= "number" or rows < 1) then
        error("LoolibGridLayout: SetRows: rows must be a positive number or nil", 2)
    end
    self.config.rows = rows
    self:MarkDirty()
end

--- Set cell size
-- @param width number - Cell width
-- @param height number - Cell height (defaults to width)
function GridLayoutMixin:SetCellSize(width, height)
    if type(width) ~= "number" or width <= 0 then
        error("LoolibGridLayout: SetCellSize: width must be a positive number", 2)
    end
    self.config.cellWidth = width
    self.config.cellHeight = height or width
    self:MarkDirty()
end

--- Set spacing between cells
-- @param columnSpacing number - Horizontal spacing
-- @param rowSpacing number - Vertical spacing (defaults to columnSpacing)
function GridLayoutMixin:SetCellSpacing(columnSpacing, rowSpacing)
    if type(columnSpacing) ~= "number" then
        error("LoolibGridLayout: SetCellSpacing: columnSpacing must be a number", 2)
    end
    self.config.columnSpacing = columnSpacing
    self.config.rowSpacing = rowSpacing or columnSpacing
    self:MarkDirty()
end

--- Set fill direction
-- @param direction string - ROW or COLUMN
function GridLayoutMixin:SetFillDirection(direction)
    if not VALID_FILL_DIRECTION[direction] then
        error("LoolibGridLayout: SetFillDirection: invalid direction '" .. tostring(direction) .. "', expected ROW|COLUMN", 2)
    end
    self.config.fillDirection = direction
    self:MarkDirty()
end

--- Set whether to resize children to fit cells
-- @param resize boolean
function GridLayoutMixin:SetResizeToFit(resize)
    self.config.resizeToFit = resize
    self:MarkDirty()
end

--[[--------------------------------------------------------------------
    Grid Calculations
----------------------------------------------------------------------]]

--- Calculate the row and column for a given index
-- @param index number - 1-based index
-- @return number, number - row, column (0-based)
function GridLayoutMixin:GetCellPosition(index)
    local config = self.config
    index = index - 1  -- Convert to 0-based

    if config.fillDirection == "COLUMN" then
        local rows = config.rows or math_ceil(#self:GetVisibleChildren() / math_max(1, config.columns))
        rows = math_max(1, rows)  -- guard against zero rows
        local col = math_floor(index / rows)
        local row = index % rows
        return row, col
    else
        local cols = math_max(1, config.columns)  -- guard against zero columns
        local col = index % cols
        local row = math_floor(index / cols)
        return row, col
    end
end

--- Calculate the cell size
-- @return number, number - width, height
function GridLayoutMixin:CalculateCellSize()
    local config = self.config

    if config.cellWidth and config.cellHeight then
        return config.cellWidth, config.cellHeight
    end

    -- Auto-calculate based on children
    local maxWidth = 0
    local maxHeight = 0

    for _, child in ipairs(self.children) do
        if child:IsShown() then
            local w, h = self:GetChildSize(child)
            maxWidth = math_max(maxWidth, w)
            maxHeight = math_max(maxHeight, h)
        end
    end

    return config.cellWidth or maxWidth, config.cellHeight or maxHeight
end

--- Calculate grid dimensions
-- @param numChildren number - Number of visible children
-- @return number, number - rows, columns
function GridLayoutMixin:CalculateGridDimensions(numChildren)
    local config = self.config

    if numChildren == 0 then
        return 0, config.columns or 1
    end

    if config.rows and config.columns then
        return config.rows, config.columns
    elseif config.columns then
        local cols = math_max(1, config.columns)
        local rows = math_ceil(numChildren / cols)
        return rows, cols
    elseif config.rows then
        local rows = math_max(1, config.rows)
        local columns = math_ceil(numChildren / rows)
        return rows, columns
    else
        -- Default to square-ish grid
        local columns = math_ceil(math_sqrt(numChildren))
        columns = math_max(1, columns)
        local rows = math_ceil(numChildren / columns)
        return rows, columns
    end
end

--[[--------------------------------------------------------------------
    Layout Calculation
----------------------------------------------------------------------]]

function GridLayoutMixin:Layout()
    if not self.dirty or self.layoutInProgress then
        return  -- LY-04: reentrancy guard
    end

    self.layoutInProgress = true  -- INTERNAL: prevent reentrant layout

    local children = self:GetVisibleChildren()
    local numChildren = #children

    if numChildren == 0 then
        self:SetContentSize(0, 0)
        self:MarkClean()
        self.layoutInProgress = false
        return
    end

    local config = self.config
    local cellWidth, cellHeight = self:CalculateCellSize()
    local numRows, numCols = self:CalculateGridDimensions(numChildren)

    -- Position each child
    for i, child in ipairs(children) do
        local row, col = self:GetCellPosition(i)

        -- Calculate position
        local x = config.paddingLeft + col * (cellWidth + config.columnSpacing)
        local y = -(config.paddingTop + row * (cellHeight + config.rowSpacing))

        -- Position child (NOTE: ClearAllPoints destroys external anchors - LY-01)
        child:ClearAllPoints()
        child:SetPoint("TOPLEFT", self.container, "TOPLEFT", x, y)

        -- Resize if configured
        if config.resizeToFit then
            child:SetSize(cellWidth, cellHeight)
        end
    end

    -- Calculate content size
    local contentWidth = numCols * cellWidth + math_max(0, numCols - 1) * config.columnSpacing
    local contentHeight = numRows * cellHeight + math_max(0, numRows - 1) * config.rowSpacing

    self:SetContentSize(contentWidth, contentHeight)
    self:MarkClean()
    self.layoutInProgress = false
end

--[[--------------------------------------------------------------------
    Utility Methods
----------------------------------------------------------------------]]

--- Get the child at a specific grid position
-- @param row number - 0-based row
-- @param col number - 0-based column
-- @return Region|nil - The child at that position
function GridLayoutMixin:GetChildAt(row, col)
    if type(row) ~= "number" or type(col) ~= "number" then
        error("LoolibGridLayout: GetChildAt: row and col must be numbers", 2)
    end

    local config = self.config
    local index

    if config.fillDirection == "COLUMN" then
        local rows = config.rows or math_ceil(#self:GetVisibleChildren() / math_max(1, config.columns))
        rows = math_max(1, rows)
        index = col * rows + row + 1
    else
        index = row * math_max(1, config.columns) + col + 1
    end

    return self:GetVisibleChildren()[index]
end

--- Get the grid position of a child
-- @param child Region - The child
-- @return number, number|nil - row, column (0-based) or nil
function GridLayoutMixin:GetChildGridPosition(child)
    local children = self:GetVisibleChildren()
    for i, c in ipairs(children) do
        if c == child then
            return self:GetCellPosition(i)
        end
    end
    return nil
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a grid layout
-- @param container Frame - Container frame
-- @param config table - Optional configuration
-- @return table - Layout instance
local function CreateGridLayout(container, config)
    if not container then
        error("LoolibGridLayout: CreateGridLayout: container is required", 2)
    end
    local layout = CreateFromMixins(GridLayoutMixin)
    layout:Init(container, config)
    return layout
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

GridLayoutModule.Mixin = GridLayoutMixin
GridLayoutModule.Create = CreateGridLayout

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.GridLayout = GridLayoutModule
UI.CreateGridLayout = CreateGridLayout

Layout.GridLayout = GridLayoutModule
Loolib.GridLayoutMixin = GridLayoutMixin
Loolib.CreateGridLayout = CreateGridLayout

Loolib:RegisterModule("Layout.GridLayout", GridLayoutModule)
