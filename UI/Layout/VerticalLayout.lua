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
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for VerticalLayout")
local Layout = Loolib.Layout or Loolib:GetOrCreateModule("Layout")
local LayoutBaseMixin = assert(
    Loolib.LayoutBaseMixin or ((Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")) and (Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")).Mixin),
    "Loolib.Layout.LayoutBase.Mixin is required for VerticalLayout"
)
local VerticalLayoutModule = Layout.VerticalLayout or Loolib:GetModule("Layout.VerticalLayout") or {}

--[[--------------------------------------------------------------------
    LoolibVerticalLayoutMixin
----------------------------------------------------------------------]]

local VerticalLayoutMixin = VerticalLayoutModule.Mixin or CreateFromMixins(LayoutBaseMixin)

--- Initialize vertical layout
-- @param container Frame - The container frame
-- @param config table - Configuration options
function VerticalLayoutMixin:Init(container, config)
    LayoutBaseMixin.Init(self, container, config)

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
function VerticalLayoutMixin:SetAlignItems(align)
    self.config.alignItems = align
    self:MarkDirty()
end

--- Set vertical content justification
-- @param justify string - START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND
function VerticalLayoutMixin:SetJustifyContent(justify)
    self.config.justifyContent = justify
    self:MarkDirty()
end

--- Set layout direction
-- @param direction string - DOWN, UP
function VerticalLayoutMixin:SetDirection(direction)
    self.config.direction = direction
    self:MarkDirty()
end

--[[--------------------------------------------------------------------
    Layout Calculation
----------------------------------------------------------------------]]

function VerticalLayoutMixin:Layout()
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
local function CreateVerticalLayout(container, config)
    local layout = CreateFromMixins(VerticalLayoutMixin)
    layout:Init(container, config)
    return layout
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

VerticalLayoutModule.Mixin = VerticalLayoutMixin
VerticalLayoutModule.Create = CreateVerticalLayout

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.VerticalLayout = VerticalLayoutModule
UI.CreateVerticalLayout = CreateVerticalLayout

Layout.VerticalLayout = VerticalLayoutModule
Loolib.VerticalLayoutMixin = VerticalLayoutMixin
Loolib.CreateVerticalLayout = CreateVerticalLayout

Loolib:RegisterModule("Layout.VerticalLayout", VerticalLayoutModule)
