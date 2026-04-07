--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    VerticalLayout - Stacks children vertically (top to bottom)

    Supports:
    - Spacing between children
    - Padding around content
    - Horizontal alignment (LEFT, CENTER, RIGHT, STRETCH)
    - Vertical justification (START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND)
    - Optional per-child layoutWeight for proportional stretch sizing

    NOTE: Layout calls child:ClearAllPoints() on every managed child.
    External anchors on managed children are destroyed. See LayoutBase
    header comment for details.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for VerticalLayout")
local Layout = Loolib.Layout or Loolib:GetOrCreateModule("Layout")
local LayoutBaseMixin = assert(
    Loolib.LayoutBaseMixin or ((Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")) and (Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")).Mixin),
    "Loolib.Layout.LayoutBase.Mixin is required for VerticalLayout"
)
local VerticalLayoutModule = Layout.VerticalLayout or Loolib:GetModule("Layout.VerticalLayout") or {}

-- Cache globals at file top
local type = type
local ipairs = ipairs
local tostring = tostring
local error = error
local math_max = math.max
local math_floor = math.floor

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

-- INTERNAL: valid alignment values
local VALID_ALIGN_ITEMS = { LEFT = true, CENTER = true, RIGHT = true, STRETCH = true }
local VALID_JUSTIFY = { START = true, CENTER = true, END = true, SPACE_BETWEEN = true, SPACE_AROUND = true }
local VALID_DIRECTION = { DOWN = true, UP = true }

--- Set horizontal alignment of children
-- @param align string - LEFT, CENTER, RIGHT, STRETCH
function VerticalLayoutMixin:SetAlignItems(align)
    if not VALID_ALIGN_ITEMS[align] then
        error("LoolibVerticalLayout: SetAlignItems: invalid align '" .. tostring(align) .. "', expected LEFT|CENTER|RIGHT|STRETCH", 2)
    end
    self.config.alignItems = align
    self:MarkDirty()
end

--- Set vertical content justification
-- @param justify string - START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND
function VerticalLayoutMixin:SetJustifyContent(justify)
    if not VALID_JUSTIFY[justify] then
        error("LoolibVerticalLayout: SetJustifyContent: invalid justify '" .. tostring(justify) .. "', expected START|CENTER|END|SPACE_BETWEEN|SPACE_AROUND", 2)
    end
    self.config.justifyContent = justify
    self:MarkDirty()
end

--- Set layout direction
-- @param direction string - DOWN, UP
function VerticalLayoutMixin:SetDirection(direction)
    if not VALID_DIRECTION[direction] then
        error("LoolibVerticalLayout: SetDirection: invalid direction '" .. tostring(direction) .. "', expected DOWN|UP", 2)
    end
    self.config.direction = direction
    self:MarkDirty()
end

--[[--------------------------------------------------------------------
    Layout Calculation
----------------------------------------------------------------------]]

function VerticalLayoutMixin:Layout()
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

    local availWidth, availHeight = self:GetAvailableSpace()
    local config = self.config

    -- Calculate total content height and weight (LY-02: weight support)
    local totalHeight = 0
    local maxWidth = 0
    local totalWeight = 0

    for _, child in ipairs(children) do
        local childWidth, childHeight = self:GetChildSize(child)
        totalHeight = totalHeight + childHeight
        maxWidth = math_max(maxWidth, childWidth)
        totalWeight = totalWeight + (child.layoutWeight or 0)
    end

    -- Add spacing
    totalHeight = totalHeight + (config.spacing * (numChildren - 1))

    -- Distribute remaining space to weighted children (LY-02)
    local remainingSpace = availHeight - totalHeight
    if totalWeight > 0 and remainingSpace > 0 then
        for _, child in ipairs(children) do
            local weight = child.layoutWeight or 0
            if weight > 0 then
                local extraHeight = math_floor(remainingSpace * weight / totalWeight)
                local _, childHeight = self:GetChildSize(child)
                child:SetHeight(childHeight + extraHeight)
            end
        end
        -- Recalculate total after weight distribution
        totalHeight = 0
        for _, child in ipairs(children) do
            local _, childHeight = self:GetChildSize(child)
            totalHeight = totalHeight + childHeight
        end
        totalHeight = totalHeight + (config.spacing * (numChildren - 1))
        remainingSpace = availHeight - totalHeight
    end

    -- Calculate starting Y position based on justifyContent
    local startY = 0
    local extraSpacing = 0

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

    if config.direction == "UP" then
        currentY = config.paddingBottom + startY
    end

    for _, child in ipairs(children) do
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

        -- Position the child (NOTE: ClearAllPoints destroys external anchors - LY-01)
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
    self.layoutInProgress = false
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a vertical layout
-- @param container Frame - Container frame
-- @param config table - Optional configuration
-- @return table - Layout instance
local function CreateVerticalLayout(container, config)
    if not container then
        error("LoolibVerticalLayout: CreateVerticalLayout: container is required", 2)
    end
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
