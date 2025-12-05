--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    HorizontalLayout - Stacks children horizontally (left to right)

    Supports:
    - Spacing between children
    - Padding around content
    - Vertical alignment (TOP, CENTER, BOTTOM, STRETCH)
    - Horizontal justification (START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibHorizontalLayoutMixin
----------------------------------------------------------------------]]

LoolibHorizontalLayoutMixin = LoolibCreateFromMixins(LoolibBaseLayoutMixin)

--- Initialize horizontal layout
-- @param container Frame - The container frame
-- @param config table - Configuration options
function LoolibHorizontalLayoutMixin:Init(container, config)
    LoolibBaseLayoutMixin.Init(self, container, config)

    -- Horizontal-specific config
    self.config.alignItems = self.config.alignItems or "TOP"  -- TOP, CENTER, BOTTOM, STRETCH
    self.config.justifyContent = self.config.justifyContent or "START"  -- START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND
    self.config.direction = self.config.direction or "RIGHT"  -- RIGHT, LEFT
end

--[[--------------------------------------------------------------------
    Configuration Setters
----------------------------------------------------------------------]]

--- Set vertical alignment of children
-- @param align string - TOP, CENTER, BOTTOM, STRETCH
function LoolibHorizontalLayoutMixin:SetAlignItems(align)
    self.config.alignItems = align
    self:MarkDirty()
end

--- Set horizontal content justification
-- @param justify string - START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND
function LoolibHorizontalLayoutMixin:SetJustifyContent(justify)
    self.config.justifyContent = justify
    self:MarkDirty()
end

--- Set layout direction
-- @param direction string - RIGHT, LEFT
function LoolibHorizontalLayoutMixin:SetDirection(direction)
    self.config.direction = direction
    self:MarkDirty()
end

--[[--------------------------------------------------------------------
    Layout Calculation
----------------------------------------------------------------------]]

function LoolibHorizontalLayoutMixin:Layout()
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

    -- Calculate total content width
    local totalWidth = 0
    local maxHeight = 0

    for i, child in ipairs(children) do
        local childWidth, childHeight = self:GetChildSize(child)
        totalWidth = totalWidth + childWidth
        maxHeight = math.max(maxHeight, childHeight)
    end

    -- Add spacing
    totalWidth = totalWidth + (config.spacing * (numChildren - 1))

    -- Calculate starting X position based on justifyContent
    local startX = 0
    local extraSpacing = 0
    local remainingSpace = availWidth - totalWidth

    if config.justifyContent == "CENTER" then
        startX = remainingSpace / 2
    elseif config.justifyContent == "END" then
        startX = remainingSpace
    elseif config.justifyContent == "SPACE_BETWEEN" and numChildren > 1 then
        extraSpacing = remainingSpace / (numChildren - 1)
    elseif config.justifyContent == "SPACE_AROUND" and numChildren > 0 then
        extraSpacing = remainingSpace / numChildren
        startX = extraSpacing / 2
    end

    -- Position children
    local currentX = config.paddingLeft + startX
    local direction = config.direction == "LEFT" and -1 or 1

    if config.direction == "LEFT" then
        currentX = self.container:GetWidth() - config.paddingRight - startX
    end

    for i, child in ipairs(children) do
        local childWidth, childHeight = self:GetChildSize(child)

        -- Calculate Y position based on alignment
        local y = -config.paddingTop

        if config.alignItems == "CENTER" then
            y = -config.paddingTop - (availHeight - childHeight) / 2
        elseif config.alignItems == "BOTTOM" then
            y = -config.paddingTop - (availHeight - childHeight)
        elseif config.alignItems == "STRETCH" then
            child:SetHeight(availHeight)
            childHeight = availHeight
        end

        -- Position the child
        child:ClearAllPoints()

        if config.direction == "LEFT" then
            child:SetPoint("TOPRIGHT", self.container, "TOPRIGHT", -currentX, y)
            currentX = currentX + childWidth + config.spacing + extraSpacing
        else
            child:SetPoint("TOPLEFT", self.container, "TOPLEFT", currentX, y)
            currentX = currentX + childWidth + config.spacing + extraSpacing
        end
    end

    -- Update content size
    local contentHeight = config.alignItems == "STRETCH" and availHeight or maxHeight
    self:SetContentSize(totalWidth, contentHeight)

    self:MarkClean()
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a horizontal layout
-- @param container Frame - Container frame
-- @param config table - Configuration
-- @return table - Layout instance
function CreateLoolibHorizontalLayout(container, config)
    local layout = LoolibCreateFromMixins(LoolibHorizontalLayoutMixin)
    layout:Init(container, config)
    return layout
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local HorizontalLayoutModule = {
    Mixin = LoolibHorizontalLayoutMixin,
    Create = CreateLoolibHorizontalLayout,
}

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.HorizontalLayout = HorizontalLayoutModule
UI.CreateHorizontalLayout = CreateLoolibHorizontalLayout

Loolib:RegisterModule("HorizontalLayout", HorizontalLayoutModule)
