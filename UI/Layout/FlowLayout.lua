--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    FlowLayout - Wraps children to new rows/columns when space runs out

    Supports:
    - Horizontal or vertical flow direction
    - Automatic wrapping
    - Row/column alignment
    - Flexible or fixed sizing
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for FlowLayout")
local Layout = Loolib.Layout or Loolib:GetOrCreateModule("Layout")
local LayoutBaseMixin = assert(
    Loolib.LayoutBaseMixin or ((Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")) and (Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")).Mixin),
    "Loolib.Layout.LayoutBase.Mixin is required for FlowLayout"
)
local FlowLayoutModule = Layout.FlowLayout or Loolib:GetModule("Layout.FlowLayout") or {}

--[[--------------------------------------------------------------------
    LoolibFlowLayoutMixin
----------------------------------------------------------------------]]

local FlowLayoutMixin = FlowLayoutModule.Mixin or CreateFromMixins(LayoutBaseMixin)

--- Initialize flow layout
-- @param container Frame - The container frame
-- @param config table - Configuration options
function FlowLayoutMixin:Init(container, config)
    LayoutBaseMixin.Init(self, container, config)

    -- Flow-specific config
    self.config.direction = self.config.direction or "HORIZONTAL"  -- HORIZONTAL, VERTICAL
    self.config.wrapSpacing = self.config.wrapSpacing or self.config.spacing  -- Spacing between rows/columns
    self.config.alignContent = self.config.alignContent or "START"  -- START, CENTER, END
    self.config.alignItems = self.config.alignItems or "START"  -- START, CENTER, END
end

--[[--------------------------------------------------------------------
    Configuration Setters
----------------------------------------------------------------------]]

--- Set flow direction
-- @param direction string - HORIZONTAL or VERTICAL
function FlowLayoutMixin:SetDirection(direction)
    self.config.direction = direction
    self:MarkDirty()
end

--- Set spacing between wrapped rows/columns
-- @param spacing number
function FlowLayoutMixin:SetWrapSpacing(spacing)
    self.config.wrapSpacing = spacing
    self:MarkDirty()
end

--- Set content alignment (rows/columns)
-- @param align string - START, CENTER, END
function FlowLayoutMixin:SetAlignContent(align)
    self.config.alignContent = align
    self:MarkDirty()
end

--- Set item alignment within row/column
-- @param align string - START, CENTER, END
function FlowLayoutMixin:SetAlignItems(align)
    self.config.alignItems = align
    self:MarkDirty()
end

--[[--------------------------------------------------------------------
    Layout Calculation - Horizontal Flow
----------------------------------------------------------------------]]

function FlowLayoutMixin:LayoutHorizontal()
    local children = self:GetVisibleChildren()
    local numChildren = #children

    if numChildren == 0 then
        self:SetContentSize(0, 0)
        return
    end

    local availWidth, _ = self:GetAvailableSpace()
    local config = self.config

    -- Build rows
    local rows = {}
    local currentRow = { children = {}, width = 0, height = 0 }

    for _, child in ipairs(children) do
        local childWidth, childHeight = self:GetChildSize(child)

        -- Check if child fits in current row
        local neededWidth = currentRow.width > 0 and (currentRow.width + config.spacing + childWidth) or childWidth

        if neededWidth > availWidth and currentRow.width > 0 then
            -- Start new row
            rows[#rows + 1] = currentRow
            currentRow = { children = {}, width = 0, height = 0 }
        end

        -- Add to current row
        currentRow.children[#currentRow.children + 1] = child
        currentRow.width = currentRow.width + (currentRow.width > 0 and config.spacing or 0) + childWidth
        currentRow.height = math.max(currentRow.height, childHeight)
    end

    -- Don't forget the last row
    if #currentRow.children > 0 then
        rows[#rows + 1] = currentRow
    end

    -- Calculate total height
    local totalHeight = 0
    local maxRowWidth = 0
    for i, row in ipairs(rows) do
        totalHeight = totalHeight + row.height
        maxRowWidth = math.max(maxRowWidth, row.width)
    end
    totalHeight = totalHeight + (config.wrapSpacing * (#rows - 1))

    -- Position rows
    local currentY = -config.paddingTop

    for _, row in ipairs(rows) do
        -- Calculate row starting X based on alignment
        local rowX = config.paddingLeft
        if config.alignContent == "CENTER" then
            rowX = config.paddingLeft + (availWidth - row.width) / 2
        elseif config.alignContent == "END" then
            rowX = config.paddingLeft + availWidth - row.width
        end

        -- Position children in row
        local currentX = rowX
        for _, child in ipairs(row.children) do
            local childWidth, childHeight = self:GetChildSize(child)

            -- Calculate Y offset based on item alignment
            local offsetY = 0
            if config.alignItems == "CENTER" then
                offsetY = -(row.height - childHeight) / 2
            elseif config.alignItems == "END" then
                offsetY = -(row.height - childHeight)
            end

            child:ClearAllPoints()
            child:SetPoint("TOPLEFT", self.container, "TOPLEFT", currentX, currentY + offsetY)

            currentX = currentX + childWidth + config.spacing
        end

        currentY = currentY - row.height - config.wrapSpacing
    end

    self:SetContentSize(maxRowWidth, totalHeight)
end

--[[--------------------------------------------------------------------
    Layout Calculation - Vertical Flow
----------------------------------------------------------------------]]

function FlowLayoutMixin:LayoutVertical()
    local children = self:GetVisibleChildren()
    local numChildren = #children

    if numChildren == 0 then
        self:SetContentSize(0, 0)
        return
    end

    local _, availHeight = self:GetAvailableSpace()
    local config = self.config

    -- Build columns
    local columns = {}
    local currentColumn = { children = {}, width = 0, height = 0 }

    for _, child in ipairs(children) do
        local childWidth, childHeight = self:GetChildSize(child)

        -- Check if child fits in current column
        local neededHeight = currentColumn.height > 0 and (currentColumn.height + config.spacing + childHeight) or childHeight

        if neededHeight > availHeight and currentColumn.height > 0 then
            -- Start new column
            columns[#columns + 1] = currentColumn
            currentColumn = { children = {}, width = 0, height = 0 }
        end

        -- Add to current column
        currentColumn.children[#currentColumn.children + 1] = child
        currentColumn.height = currentColumn.height + (currentColumn.height > 0 and config.spacing or 0) + childHeight
        currentColumn.width = math.max(currentColumn.width, childWidth)
    end

    -- Don't forget the last column
    if #currentColumn.children > 0 then
        columns[#columns + 1] = currentColumn
    end

    -- Calculate total width
    local totalWidth = 0
    local maxColumnHeight = 0
    for i, col in ipairs(columns) do
        totalWidth = totalWidth + col.width
        maxColumnHeight = math.max(maxColumnHeight, col.height)
    end
    totalWidth = totalWidth + (config.wrapSpacing * (#columns - 1))

    -- Position columns
    local currentX = config.paddingLeft

    for _, col in ipairs(columns) do
        -- Calculate column starting Y based on alignment
        local colY = -config.paddingTop
        if config.alignContent == "CENTER" then
            colY = -config.paddingTop - (availHeight - col.height) / 2
        elseif config.alignContent == "END" then
            colY = -config.paddingTop - (availHeight - col.height)
        end

        -- Position children in column
        local currentY = colY
        for _, child in ipairs(col.children) do
            local childWidth, childHeight = self:GetChildSize(child)

            -- Calculate X offset based on item alignment
            local offsetX = 0
            if config.alignItems == "CENTER" then
                offsetX = (col.width - childWidth) / 2
            elseif config.alignItems == "END" then
                offsetX = col.width - childWidth
            end

            child:ClearAllPoints()
            child:SetPoint("TOPLEFT", self.container, "TOPLEFT", currentX + offsetX, currentY)

            currentY = currentY - childHeight - config.spacing
        end

        currentX = currentX + col.width + config.wrapSpacing
    end

    self:SetContentSize(totalWidth, maxColumnHeight)
end

--[[--------------------------------------------------------------------
    Layout Entry Point
----------------------------------------------------------------------]]

function FlowLayoutMixin:Layout()
    if not self.dirty then
        return
    end

    if self.config.direction == "VERTICAL" then
        self:LayoutVertical()
    else
        self:LayoutHorizontal()
    end

    self:MarkClean()
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a flow layout
-- @param container Frame - Container frame
-- @param config table - Configuration
-- @return table - Layout instance
local function CreateFlowLayout(container, config)
    local layout = CreateFromMixins(FlowLayoutMixin)
    layout:Init(container, config)
    return layout
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

FlowLayoutModule.Mixin = FlowLayoutMixin
FlowLayoutModule.Create = CreateFlowLayout

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.FlowLayout = FlowLayoutModule
UI.CreateFlowLayout = CreateFlowLayout

Layout.FlowLayout = FlowLayoutModule
Loolib.FlowLayoutMixin = FlowLayoutMixin
Loolib.CreateFlowLayout = CreateFlowLayout

Loolib:RegisterModule("Layout.FlowLayout", FlowLayoutModule)
