--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    VerticalLayout - Stacks children vertically (top to bottom)

    Supports:
    - Spacing between children
    - Padding around content
    - Horizontal alignment (LEFT, CENTER, RIGHT, STRETCH)
    - Vertical justification (START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibVerticalLayoutMixin
----------------------------------------------------------------------]]

LoolibVerticalLayoutMixin = LoolibCreateFromMixins(LoolibBaseLayoutMixin)

--- Initialize vertical layout
-- @param container Frame - The container frame
-- @param config table - Configuration options
function LoolibVerticalLayoutMixin:Init(container, config)
    LoolibBaseLayoutMixin.Init(self, container, config)

    -- Vertical-specific config
    self.config.alignItems = self.config.alignItems or "LEFT"  -- LEFT, CENTER, RIGHT, STRETCH
    self.config.justifyContent = self.config.justifyContent or "START"  -- START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND
    self.config.direction = self.config.direction or "DOWN"  -- DOWN, UP
end

--[[--------------------------------------------------------------------
    Configuration Setters
----------------------------------------------------------------------]]

--- Set horizontal alignment of children
-- @param align string - LEFT, CENTER, RIGHT, STRETCH
function LoolibVerticalLayoutMixin:SetAlignItems(align)
    self.config.alignItems = align
    self:MarkDirty()
end

--- Set vertical content justification
-- @param justify string - START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND
function LoolibVerticalLayoutMixin:SetJustifyContent(justify)
    self.config.justifyContent = justify
    self:MarkDirty()
end

--- Set layout direction
-- @param direction string - DOWN, UP
function LoolibVerticalLayoutMixin:SetDirection(direction)
    self.config.direction = direction
    self:MarkDirty()
end

--[[--------------------------------------------------------------------
    Layout Calculation
----------------------------------------------------------------------]]

function LoolibVerticalLayoutMixin:Layout()
    if not self.dirty then
        return
    end

    local children = self:GetVisibleChildren()
    local numChildren = #children

    if numChildren == 0 then
        self:SetContentSize(0, 0)
        self:MarkClean()
        return
    end

    local availWidth, availHeight = self:GetAvailableSpace()
    local config = self.config

    -- Calculate total content height
    local totalHeight = 0
    local maxWidth = 0

    for i, child in ipairs(children) do
        local childWidth, childHeight = self:GetChildSize(child)
        totalHeight = totalHeight + childHeight
        maxWidth = math.max(maxWidth, childWidth)
    end

    -- Add spacing
    totalHeight = totalHeight + (config.spacing * (numChildren - 1))

    -- Calculate starting Y position based on justifyContent
    local startY = 0
    local extraSpacing = 0
    local remainingSpace = availHeight - totalHeight

    if config.justifyContent == "CENTER" then
        startY = remainingSpace / 2
    elseif config.justifyContent == "END" then
        startY = remainingSpace
    elseif config.justifyContent == "SPACE_BETWEEN" and numChildren > 1 then
        extraSpacing = remainingSpace / (numChildren - 1)
    elseif config.justifyContent == "SPACE_AROUND" and numChildren > 0 then
        extraSpacing = remainingSpace / numChildren
        startY = extraSpacing / 2
    end

    -- Position children
    local currentY = -config.paddingTop - startY
    local direction = config.direction == "UP" and 1 or -1

    if config.direction == "UP" then
        currentY = config.paddingBottom + startY
    end

    for i, child in ipairs(children) do
        local childWidth, childHeight = self:GetChildSize(child)

        -- Calculate X position based on alignment
        local x = config.paddingLeft

        if config.alignItems == "CENTER" then
            x = config.paddingLeft + (availWidth - childWidth) / 2
        elseif config.alignItems == "RIGHT" then
            x = config.paddingLeft + availWidth - childWidth
        elseif config.alignItems == "STRETCH" then
            child:SetWidth(availWidth)
            childWidth = availWidth
        end

        -- Position the child
        child:ClearAllPoints()

        if config.direction == "UP" then
            child:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", x, currentY)
            currentY = currentY + childHeight + config.spacing + extraSpacing
        else
            child:SetPoint("TOPLEFT", self.container, "TOPLEFT", x, currentY)
            currentY = currentY - childHeight - config.spacing - extraSpacing
        end
    end

    -- Update content size
    local contentWidth = config.alignItems == "STRETCH" and availWidth or maxWidth
    self:SetContentSize(contentWidth, totalHeight)

    self:MarkClean()
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a vertical layout
-- @param container Frame - Container frame
-- @param config table - Configuration
-- @return table - Layout instance
function CreateLoolibVerticalLayout(container, config)
    local layout = LoolibCreateFromMixins(LoolibVerticalLayoutMixin)
    layout:Init(container, config)
    return layout
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local VerticalLayoutModule = {
    Mixin = LoolibVerticalLayoutMixin,
    Create = CreateLoolibVerticalLayout,
}

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.VerticalLayout = VerticalLayoutModule
UI.CreateVerticalLayout = CreateLoolibVerticalLayout

Loolib:RegisterModule("VerticalLayout", VerticalLayoutModule)
