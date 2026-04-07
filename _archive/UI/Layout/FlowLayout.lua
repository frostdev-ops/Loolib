--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    FlowLayout - Wraps children to new rows/columns when space runs out

    Supports:
    - Horizontal or vertical flow direction
    - Automatic wrapping
    - Row/column alignment
    - Flexible or fixed sizing
    - Oversized children placed on their own line (LY-03)

    NOTE: Layout calls child:ClearAllPoints() on every managed child.
    External anchors on managed children are destroyed. See LayoutBase
    header comment for details.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for FlowLayout")
local Layout = Loolib.Layout or Loolib:GetOrCreateModule("Layout")
local LayoutBaseMixin = assert(
    Loolib.LayoutBaseMixin or ((Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")) and (Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")).Mixin),
    "Loolib.Layout.LayoutBase.Mixin is required for FlowLayout"
)
local FlowLayoutModule = Layout.FlowLayout or Loolib:GetModule("Layout.FlowLayout") or {}

-- Cache globals at file top
local type = type
local ipairs = ipairs
local tostring = tostring
local error = error
local math_max = math.max

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

-- INTERNAL: valid configuration values
local VALID_DIRECTION = { HORIZONTAL = true, VERTICAL = true }
local VALID_ALIGN = { START = true, CENTER = true, END = true }

--- Set flow direction
-- @param direction string - HORIZONTAL or VERTICAL
function FlowLayoutMixin:SetDirection(direction)
    if not VALID_DIRECTION[direction] then
        error("LoolibFlowLayout: SetDirection: invalid direction '" .. tostring(direction) .. "', expected HORIZONTAL|VERTICAL", 2)
    end
    self.config.direction = direction
    self:MarkDirty()
end

--- Set spacing between wrapped rows/columns
-- @param spacing number
function FlowLayoutMixin:SetWrapSpacing(spacing)
    if type(spacing) ~= "number" then
        error("LoolibFlowLayout: SetWrapSpacing: spacing must be a number", 2)
    end
    self.config.wrapSpacing = spacing
    self:MarkDirty()
end

--- Set content alignment (rows/columns)
-- @param align string - START, CENTER, END
function FlowLayoutMixin:SetAlignContent(align)
    if not VALID_ALIGN[align] then
        error("LoolibFlowLayout: SetAlignContent: invalid align '" .. tostring(align) .. "', expected START|CENTER|END", 2)
    end
    self.config.alignContent = align
    self:MarkDirty()
end

--- Set item alignment within row/column
-- @param align string - START, CENTER, END
function FlowLayoutMixin:SetAlignItems(align)
    if not VALID_ALIGN[align] then
        error("LoolibFlowLayout: SetAlignItems: invalid align '" .. tostring(align) .. "', expected START|CENTER|END", 2)
    end
    self.config.alignItems = align
    self:MarkDirty()
end

--[[--------------------------------------------------------------------
    Layout Calculation - Horizontal Flow
----------------------------------------------------------------------]]

-- INTERNAL: Horizontal flow layout calculation
function FlowLayoutMixin:LayoutHorizontal()
    local children = self:GetVisibleChildren()
    local numChildren = #children

    if numChildren == 0 then
        self:SetContentSize(0, 0)
        return
    end

    local availWidth = self:GetAvailableSpace()
    local config = self.config

    -- Build rows
    local rows = {}
    local currentRow = { children = {}, width = 0, height = 0 }

    for _, child in ipairs(children) do
        local childWidth, childHeight = self:GetChildSize(child)

        -- LY-03: Handle children wider than available space
        -- An oversized child is placed on its own line regardless
        if childWidth > availWidth and availWidth > 0 then
            -- Flush current row if non-empty
            if #currentRow.children > 0 then
                rows[#rows + 1] = currentRow
                currentRow = { children = {}, width = 0, height = 0 }
            end
            -- Place oversized child on its own row
            rows[#rows + 1] = { children = { child }, width = childWidth, height = childHeight }
        else
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
            currentRow.height = math_max(currentRow.height, childHeight)
        end
    end

    -- Don't forget the last row
    if #currentRow.children > 0 then
        rows[#rows + 1] = currentRow
    end

    -- Calculate total height
    local totalHeight = 0
    local maxRowWidth = 0
    for _, row in ipairs(rows) do
        totalHeight = totalHeight + row.height
        maxRowWidth = math_max(maxRowWidth, row.width)
    end
    totalHeight = totalHeight + (config.wrapSpacing * math_max(0, #rows - 1))

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

            -- NOTE: ClearAllPoints destroys external anchors (LY-01)
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

-- INTERNAL: Vertical flow layout calculation
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

        -- LY-03: Handle children taller than available space
        -- An oversized child is placed in its own column regardless
        if childHeight > availHeight and availHeight > 0 then
            -- Flush current column if non-empty
            if #currentColumn.children > 0 then
                columns[#columns + 1] = currentColumn
                currentColumn = { children = {}, width = 0, height = 0 }
            end
            -- Place oversized child in its own column
            columns[#columns + 1] = { children = { child }, width = childWidth, height = childHeight }
        else
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
            currentColumn.width = math_max(currentColumn.width, childWidth)
        end
    end

    -- Don't forget the last column
    if #currentColumn.children > 0 then
        columns[#columns + 1] = currentColumn
    end

    -- Calculate total width
    local totalWidth = 0
    local maxColumnHeight = 0
    for _, col in ipairs(columns) do
        totalWidth = totalWidth + col.width
        maxColumnHeight = math_max(maxColumnHeight, col.height)
    end
    totalWidth = totalWidth + (config.wrapSpacing * math_max(0, #columns - 1))

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

            -- NOTE: ClearAllPoints destroys external anchors (LY-01)
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
    if not self.dirty or self.layoutInProgress then
        return  -- LY-04: reentrancy guard
    end

    self.layoutInProgress = true  -- INTERNAL: prevent reentrant layout

    if self.config.direction == "VERTICAL" then
        self:LayoutVertical()
    else
        self:LayoutHorizontal()
    end

    self:MarkClean()
    self.layoutInProgress = false
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a flow layout
-- @param container Frame - Container frame
-- @param config table - Optional configuration
-- @return table - Layout instance
local function CreateFlowLayout(container, config)
    if not container then
        error("LoolibFlowLayout: CreateFlowLayout: container is required", 2)
    end
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
