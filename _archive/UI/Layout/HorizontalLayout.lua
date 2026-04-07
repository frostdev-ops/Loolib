--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    HorizontalLayout - Stacks children horizontally (left to right)

    Supports:
    - Spacing between children
    - Padding around content
    - Vertical alignment (TOP, CENTER, BOTTOM, STRETCH)
    - Horizontal justification (START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND)
    - Optional per-child layoutWeight for proportional stretch sizing

    NOTE: Layout calls child:ClearAllPoints() on every managed child.
    External anchors on managed children are destroyed. See LayoutBase
    header comment for details.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for HorizontalLayout")
local Layout = Loolib.Layout or Loolib:GetOrCreateModule("Layout")
local LayoutBaseMixin = assert(
    Loolib.LayoutBaseMixin or ((Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")) and (Layout.LayoutBase or Loolib:GetModule("Layout.LayoutBase")).Mixin),
    "Loolib.Layout.LayoutBase.Mixin is required for HorizontalLayout"
)
local HorizontalLayoutModule = Layout.HorizontalLayout or Loolib:GetModule("Layout.HorizontalLayout") or {}

-- Cache globals at file top
local type = type
local ipairs = ipairs
local tostring = tostring
local error = error
local math_max = math.max
local math_floor = math.floor

--[[--------------------------------------------------------------------
    LoolibHorizontalLayoutMixin
----------------------------------------------------------------------]]

local HorizontalLayoutMixin = HorizontalLayoutModule.Mixin or CreateFromMixins(LayoutBaseMixin)

--- Initialize horizontal layout
-- @param container Frame - The container frame
-- @param config table - Configuration options
function HorizontalLayoutMixin:Init(container, config)
    LayoutBaseMixin.Init(self, container, config)

    -- Horizontal-specific config
    self.config.alignItems = self.config.alignItems or "TOP"  -- TOP, CENTER, BOTTOM, STRETCH
    self.config.justifyContent = self.config.justifyContent or "START"  -- START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND
    self.config.direction = self.config.direction or "RIGHT"  -- RIGHT, LEFT
end

--[[--------------------------------------------------------------------
    Configuration Setters
----------------------------------------------------------------------]]

-- INTERNAL: valid alignment values
local VALID_ALIGN_ITEMS = { TOP = true, CENTER = true, BOTTOM = true, STRETCH = true }
local VALID_JUSTIFY = { START = true, CENTER = true, END = true, SPACE_BETWEEN = true, SPACE_AROUND = true }
local VALID_DIRECTION = { RIGHT = true, LEFT = true }

--- Set vertical alignment of children
-- @param align string - TOP, CENTER, BOTTOM, STRETCH
function HorizontalLayoutMixin:SetAlignItems(align)
    if not VALID_ALIGN_ITEMS[align] then
        error("LoolibHorizontalLayout: SetAlignItems: invalid align '" .. tostring(align) .. "', expected TOP|CENTER|BOTTOM|STRETCH", 2)
    end
    self.config.alignItems = align
    self:MarkDirty()
end

--- Set horizontal content justification
-- @param justify string - START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND
function HorizontalLayoutMixin:SetJustifyContent(justify)
    if not VALID_JUSTIFY[justify] then
        error("LoolibHorizontalLayout: SetJustifyContent: invalid justify '" .. tostring(justify) .. "', expected START|CENTER|END|SPACE_BETWEEN|SPACE_AROUND", 2)
    end
    self.config.justifyContent = justify
    self:MarkDirty()
end

--- Set layout direction
-- @param direction string - RIGHT, LEFT
function HorizontalLayoutMixin:SetDirection(direction)
    if not VALID_DIRECTION[direction] then
        error("LoolibHorizontalLayout: SetDirection: invalid direction '" .. tostring(direction) .. "', expected RIGHT|LEFT", 2)
    end
    self.config.direction = direction
    self:MarkDirty()
end

--[[--------------------------------------------------------------------
    Layout Calculation
----------------------------------------------------------------------]]

function HorizontalLayoutMixin:Layout()
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

    -- Calculate total content width and weight (LY-02: weight support)
    local totalWidth = 0
    local maxHeight = 0
    local totalWeight = 0

    for _, child in ipairs(children) do
        local childWidth, childHeight = self:GetChildSize(child)
        totalWidth = totalWidth + childWidth
        maxHeight = math_max(maxHeight, childHeight)
        totalWeight = totalWeight + (child.layoutWeight or 0)
    end

    -- Add spacing
    totalWidth = totalWidth + (config.spacing * (numChildren - 1))

    -- Distribute remaining space to weighted children (LY-02)
    local remainingSpace = availWidth - totalWidth
    if totalWeight > 0 and remainingSpace > 0 then
        for _, child in ipairs(children) do
            local weight = child.layoutWeight or 0
            if weight > 0 then
                local extraWidth = math_floor(remainingSpace * weight / totalWeight)
                local childWidth = self:GetChildSize(child)
                child:SetWidth(childWidth + extraWidth)
            end
        end
        -- Recalculate total after weight distribution
        totalWidth = 0
        for _, child in ipairs(children) do
            local childWidth = self:GetChildSize(child)
            totalWidth = totalWidth + childWidth
        end
        totalWidth = totalWidth + (config.spacing * (numChildren - 1))
        remainingSpace = availWidth - totalWidth
    end

    -- Calculate starting X position based on justifyContent
    local startX = 0
    local extraSpacing = 0

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

    if config.direction == "LEFT" then
        currentX = self.container:GetWidth() - config.paddingRight - startX
    end

    for _, child in ipairs(children) do
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

        -- Position the child (NOTE: ClearAllPoints destroys external anchors - LY-01)
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
    self.layoutInProgress = false
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a horizontal layout
-- @param container Frame - Container frame
-- @param config table - Optional configuration
-- @return table - Layout instance
local function CreateHorizontalLayout(container, config)
    if not container then
        error("LoolibHorizontalLayout: CreateHorizontalLayout: container is required", 2)
    end
    local layout = CreateFromMixins(HorizontalLayoutMixin)
    layout:Init(container, config)
    return layout
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

HorizontalLayoutModule.Mixin = HorizontalLayoutMixin
HorizontalLayoutModule.Create = CreateHorizontalLayout

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.HorizontalLayout = HorizontalLayoutModule
UI.CreateHorizontalLayout = CreateHorizontalLayout

Layout.HorizontalLayout = HorizontalLayoutModule
Loolib.HorizontalLayoutMixin = HorizontalLayoutMixin
Loolib.CreateHorizontalLayout = CreateHorizontalLayout

Loolib:RegisterModule("Layout.HorizontalLayout", HorizontalLayoutModule)
