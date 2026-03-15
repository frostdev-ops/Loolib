--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    AnchorUtil - Utilities for frame anchoring and positioning
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
local AnchorUtil = UI.AnchorUtil or Loolib:GetModule("UI.AnchorUtil") or {}

-- Cache globals
local error = error
local ipairs = ipairs
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local type = type

-- Cache WoW APIs
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local UIParent = UIParent

-- Valid anchor point names for validation
local VALID_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

--[[--------------------------------------------------------------------
    Internal Helpers
----------------------------------------------------------------------]]

--- Validate that a value is a region (has ClearAllPoints/SetPoint) -- INTERNAL
-- @param region any - The value to check
-- @param caller string - Calling function name for error messages
local function ValidateRegion(region, caller)
    if not region or type(region) ~= "table" or not region.ClearAllPoints then
        error("LoolibAnchorUtil." .. caller .. ": region must be a valid region or frame", 2)
    end
end

--- Validate that a value is a valid anchor point name -- INTERNAL
-- @param point any - The value to check
-- @param caller string - Calling function name for error messages
local function ValidatePoint(point, caller)
    if type(point) ~= "string" or not VALID_POINTS[point] then
        error("LoolibAnchorUtil." .. caller .. ": invalid anchor point '" .. tostring(point) .. "'", 2)
    end
end

--[[--------------------------------------------------------------------
    Point Utilities
----------------------------------------------------------------------]]

--- Set a single point on a region
-- @param region Region - The region to anchor
-- @param point string - The anchor point (e.g., "TOPLEFT")
-- @param relativeTo Frame - The frame to anchor relative to (nil = parent)
-- @param relativePoint string - The point on relativeTo (nil = same as point)
-- @param offsetX number - X offset (default 0)
-- @param offsetY number - Y offset (default 0)
function AnchorUtil.SetPoint(region, point, relativeTo, relativePoint, offsetX, offsetY)
    ValidateRegion(region, "SetPoint")
    ValidatePoint(point, "SetPoint")
    if relativePoint then
        ValidatePoint(relativePoint, "SetPoint")
    end

    region:ClearAllPoints()
    region:SetPoint(
        point,
        relativeTo,
        relativePoint or point,
        offsetX or 0,
        offsetY or 0
    )
end

--- Set all points to fill a parent frame
-- @param region Region - The region to anchor
-- @param relativeTo Frame - The frame to fill (nil = parent)
-- @param inset number - Optional inset from edges (applied to all sides)
function AnchorUtil.SetAllPoints(region, relativeTo, inset)
    ValidateRegion(region, "SetAllPoints")

    region:ClearAllPoints()

    if inset then
        region:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", inset, -inset)
        region:SetPoint("BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", -inset, inset)
    else
        region:SetAllPoints(relativeTo)
    end
end

--- Set all points with different insets per side
-- @param region Region - The region to anchor
-- @param relativeTo Frame - The frame to fill
-- @param left number - Left inset
-- @param right number - Right inset
-- @param top number - Top inset
-- @param bottom number - Bottom inset
function AnchorUtil.SetAllPointsWithInsets(region, relativeTo, left, right, top, bottom)
    ValidateRegion(region, "SetAllPointsWithInsets")

    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", left or 0, -(top or 0))
    region:SetPoint("BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", -(right or 0), bottom or 0)
end

--[[--------------------------------------------------------------------
    Relative Positioning
----------------------------------------------------------------------]]

--- Position a region to the right of another
-- @param region Region - The region to position
-- @param relativeTo Region - The region to position relative to
-- @param spacing number - Horizontal spacing (default 0)
-- @param verticalOffset number - Vertical offset (default 0)
function AnchorUtil.SetToRightOf(region, relativeTo, spacing, verticalOffset)
    ValidateRegion(region, "SetToRightOf")
    if not relativeTo or type(relativeTo) ~= "table" then
        error("LoolibAnchorUtil.SetToRightOf: relativeTo must be a valid region or frame", 2)
    end

    region:ClearAllPoints()
    region:SetPoint("LEFT", relativeTo, "RIGHT", spacing or 0, verticalOffset or 0)
end

--- Position a region to the left of another
-- @param region Region - The region to position
-- @param relativeTo Region - The region to position relative to
-- @param spacing number - Horizontal spacing (default 0)
-- @param verticalOffset number - Vertical offset (default 0)
function AnchorUtil.SetToLeftOf(region, relativeTo, spacing, verticalOffset)
    ValidateRegion(region, "SetToLeftOf")
    if not relativeTo or type(relativeTo) ~= "table" then
        error("LoolibAnchorUtil.SetToLeftOf: relativeTo must be a valid region or frame", 2)
    end

    region:ClearAllPoints()
    region:SetPoint("RIGHT", relativeTo, "LEFT", -(spacing or 0), verticalOffset or 0)
end

--- Position a region below another
-- @param region Region - The region to position
-- @param relativeTo Region - The region to position relative to
-- @param spacing number - Vertical spacing (default 0)
-- @param horizontalOffset number - Horizontal offset (default 0)
function AnchorUtil.SetBelow(region, relativeTo, spacing, horizontalOffset)
    ValidateRegion(region, "SetBelow")
    if not relativeTo or type(relativeTo) ~= "table" then
        error("LoolibAnchorUtil.SetBelow: relativeTo must be a valid region or frame", 2)
    end

    region:ClearAllPoints()
    region:SetPoint("TOP", relativeTo, "BOTTOM", horizontalOffset or 0, -(spacing or 0))
end

--- Position a region above another
-- @param region Region - The region to position
-- @param relativeTo Region - The region to position relative to
-- @param spacing number - Vertical spacing (default 0)
-- @param horizontalOffset number - Horizontal offset (default 0)
function AnchorUtil.SetAbove(region, relativeTo, spacing, horizontalOffset)
    ValidateRegion(region, "SetAbove")
    if not relativeTo or type(relativeTo) ~= "table" then
        error("LoolibAnchorUtil.SetAbove: relativeTo must be a valid region or frame", 2)
    end

    region:ClearAllPoints()
    region:SetPoint("BOTTOM", relativeTo, "TOP", horizontalOffset or 0, spacing or 0)
end

--[[--------------------------------------------------------------------
    Center Positioning
----------------------------------------------------------------------]]

--- Center a region horizontally within another
-- @param region Region - The region to center
-- @param relativeTo Frame - The frame to center within (nil = parent)
-- @param verticalPoint string - Vertical anchor point ("TOP", "CENTER", "BOTTOM")
-- @param verticalOffset number - Vertical offset
function AnchorUtil.CenterHorizontally(region, relativeTo, verticalPoint, verticalOffset)
    ValidateRegion(region, "CenterHorizontally")

    local point = verticalPoint or "CENTER"
    ValidatePoint(point, "CenterHorizontally")

    region:ClearAllPoints()
    region:SetPoint(point, relativeTo, point, 0, verticalOffset or 0)
end

--- Center a region vertically within another
-- @param region Region - The region to center
-- @param relativeTo Frame - The frame to center within
-- @param horizontalPoint string - Horizontal anchor point ("LEFT", "CENTER", "RIGHT")
-- @param horizontalOffset number - Horizontal offset
function AnchorUtil.CenterVertically(region, relativeTo, horizontalPoint, horizontalOffset)
    ValidateRegion(region, "CenterVertically")

    local point = horizontalPoint or "CENTER"
    ValidatePoint(point, "CenterVertically")

    region:ClearAllPoints()
    region:SetPoint(point, relativeTo, point, horizontalOffset or 0, 0)
end

--- Center a region both horizontally and vertically
-- @param region Region - The region to center
-- @param relativeTo Frame - The frame to center within
-- @param offsetX number - Horizontal offset
-- @param offsetY number - Vertical offset
function AnchorUtil.Center(region, relativeTo, offsetX, offsetY)
    ValidateRegion(region, "Center")

    region:ClearAllPoints()
    region:SetPoint("CENTER", relativeTo, "CENTER", offsetX or 0, offsetY or 0)
end

--[[--------------------------------------------------------------------
    Corner Positioning
----------------------------------------------------------------------]]

--- Valid corner names for SetCorner
local VALID_CORNERS = {
    TOPLEFT = true, TOPRIGHT = true,
    BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

--- Position a region in a corner of another
-- @param region Region - The region to position
-- @param relativeTo Frame - The frame to position within
-- @param corner string - Corner: "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"
-- @param offsetX number - Horizontal offset
-- @param offsetY number - Vertical offset
function AnchorUtil.SetCorner(region, relativeTo, corner, offsetX, offsetY)
    ValidateRegion(region, "SetCorner")
    if type(corner) ~= "string" or not VALID_CORNERS[corner] then
        error("LoolibAnchorUtil.SetCorner: corner must be TOPLEFT, TOPRIGHT, BOTTOMLEFT, or BOTTOMRIGHT", 2)
    end

    region:ClearAllPoints()
    region:SetPoint(corner, relativeTo, corner, offsetX or 0, offsetY or 0)
end

--[[--------------------------------------------------------------------
    Grid Positioning
----------------------------------------------------------------------]]

--- Calculate grid position for an index
-- @param index number - The item index (1-based)
-- @param columns number - Number of columns
-- @param cellWidth number - Width of each cell
-- @param cellHeight number - Height of each cell
-- @param spacingX number - Horizontal spacing
-- @param spacingY number - Vertical spacing
-- @param paddingLeft number - Left padding
-- @param paddingTop number - Top padding
-- @return number, number - x, y position
function AnchorUtil.CalculateGridPosition(index, columns, cellWidth, cellHeight, spacingX, spacingY, paddingLeft, paddingTop)
    if type(index) ~= "number" or index < 1 then
        error("LoolibAnchorUtil.CalculateGridPosition: index must be a positive number", 2)
    end
    if type(columns) ~= "number" or columns < 1 then
        error("LoolibAnchorUtil.CalculateGridPosition: columns must be a positive number", 2)
    end
    if type(cellWidth) ~= "number" or type(cellHeight) ~= "number" then
        error("LoolibAnchorUtil.CalculateGridPosition: cellWidth and cellHeight must be numbers", 2)
    end

    spacingX = spacingX or 0
    spacingY = spacingY or 0
    paddingLeft = paddingLeft or 0
    paddingTop = paddingTop or 0

    local row = math_floor((index - 1) / columns)
    local col = (index - 1) % columns

    local x = paddingLeft + col * (cellWidth + spacingX)
    local y = -(paddingTop + row * (cellHeight + spacingY))

    return x, y
end

--- Position a region in a grid
-- @param region Region - The region to position
-- @param parent Frame - The parent frame
-- @param index number - The grid index (1-based)
-- @param columns number - Number of columns
-- @param cellWidth number - Width of each cell
-- @param cellHeight number - Height of each cell
-- @param spacingX number - Horizontal spacing
-- @param spacingY number - Vertical spacing
-- @param paddingLeft number - Left padding
-- @param paddingTop number - Top padding
function AnchorUtil.SetGridPosition(region, parent, index, columns, cellWidth, cellHeight, spacingX, spacingY, paddingLeft, paddingTop)
    ValidateRegion(region, "SetGridPosition")

    local x, y = AnchorUtil.CalculateGridPosition(
        index, columns, cellWidth, cellHeight,
        spacingX, spacingY, paddingLeft, paddingTop
    )

    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
end

--[[--------------------------------------------------------------------
    Anchor Points Table
----------------------------------------------------------------------]]

--- Apply multiple anchor points from a table
-- @param region Region - The region to anchor
-- @param points table - Array of point configs: { {point, relativeTo, relativePoint, x, y}, ... }
function AnchorUtil.SetPointsFromTable(region, points)
    ValidateRegion(region, "SetPointsFromTable")
    if type(points) ~= "table" then
        error("LoolibAnchorUtil.SetPointsFromTable: points must be a table", 2)
    end

    region:ClearAllPoints()

    for _, pointConfig in ipairs(points) do
        if type(pointConfig) == "table" then
            region:SetPoint(
                pointConfig[1] or pointConfig.point,
                pointConfig[2] or pointConfig.relativeTo,
                pointConfig[3] or pointConfig.relativePoint or pointConfig[1] or pointConfig.point,
                pointConfig[4] or pointConfig.x or 0,
                pointConfig[5] or pointConfig.y or 0
            )
        elseif type(pointConfig) == "string" then
            -- Simple point string
            region:SetPoint(pointConfig)
        end
    end
end

--[[--------------------------------------------------------------------
    Anchor Chain
----------------------------------------------------------------------]]

--- Create a vertical chain of regions
-- @param regions table - Array of regions to chain
-- @param parent Frame - The parent frame
-- @param startPoint string - Starting point ("TOP", "BOTTOM", "CENTER")
-- @param spacing number - Vertical spacing between regions
-- @param padding number - Padding from edge
-- @param alignment string - Horizontal alignment ("LEFT", "CENTER", "RIGHT")
function AnchorUtil.ChainVertically(regions, parent, startPoint, spacing, padding, alignment)
    if type(regions) ~= "table" or #regions == 0 then
        return
    end
    if not parent or type(parent) ~= "table" then
        error("LoolibAnchorUtil.ChainVertically: parent must be a valid frame", 2)
    end

    startPoint = startPoint or "TOP"
    spacing = spacing or 0
    padding = padding or 0
    alignment = alignment or "CENTER"

    local direction = startPoint == "BOTTOM" and 1 or -1
    local anchor = startPoint == "BOTTOM" and "BOTTOM" or "TOP"

    for i, region in ipairs(regions) do
        region:ClearAllPoints()

        if i == 1 then
            -- First region anchors to parent
            local point = anchor .. (alignment == "CENTER" and "" or alignment)
            region:SetPoint(point, parent, point, 0, direction * padding)
        else
            -- Subsequent regions anchor to previous
            local prevRegion = regions[i - 1]
            local fromPoint = direction == 1 and "BOTTOM" or "TOP"
            local toPoint = direction == 1 and "TOP" or "BOTTOM"

            if alignment == "LEFT" then
                region:SetPoint(fromPoint .. "LEFT", prevRegion, toPoint .. "LEFT", 0, direction * spacing)
            elseif alignment == "RIGHT" then
                region:SetPoint(fromPoint .. "RIGHT", prevRegion, toPoint .. "RIGHT", 0, direction * spacing)
            else
                region:SetPoint(fromPoint, prevRegion, toPoint, 0, direction * spacing)
            end
        end
    end
end

--- Create a horizontal chain of regions
-- @param regions table - Array of regions to chain
-- @param parent Frame - The parent frame
-- @param startPoint string - Starting point ("LEFT", "RIGHT", "CENTER")
-- @param spacing number - Horizontal spacing between regions
-- @param padding number - Padding from edge
-- @param alignment string - Vertical alignment ("TOP", "CENTER", "BOTTOM")
function AnchorUtil.ChainHorizontally(regions, parent, startPoint, spacing, padding, alignment)
    if type(regions) ~= "table" or #regions == 0 then
        return
    end
    if not parent or type(parent) ~= "table" then
        error("LoolibAnchorUtil.ChainHorizontally: parent must be a valid frame", 2)
    end

    startPoint = startPoint or "LEFT"
    spacing = spacing or 0
    padding = padding or 0
    alignment = alignment or "CENTER"

    local direction = startPoint == "RIGHT" and -1 or 1
    local anchor = startPoint == "RIGHT" and "RIGHT" or "LEFT"

    for i, region in ipairs(regions) do
        region:ClearAllPoints()

        if i == 1 then
            local point = (alignment == "CENTER" and "" or alignment) .. anchor
            if alignment == "CENTER" then
                point = anchor
            end
            region:SetPoint(point, parent, point, direction * padding, 0)
        else
            local prevRegion = regions[i - 1]
            local fromPoint = direction == 1 and "LEFT" or "RIGHT"
            local toPoint = direction == 1 and "RIGHT" or "LEFT"

            if alignment == "TOP" then
                region:SetPoint("TOP" .. fromPoint, prevRegion, "TOP" .. toPoint, direction * spacing, 0)
            elseif alignment == "BOTTOM" then
                region:SetPoint("BOTTOM" .. fromPoint, prevRegion, "BOTTOM" .. toPoint, direction * spacing, 0)
            else
                region:SetPoint(fromPoint, prevRegion, toPoint, direction * spacing, 0)
            end
        end
    end
end

--[[--------------------------------------------------------------------
    Screen Positioning
----------------------------------------------------------------------]]

--- Clamp a frame to stay within screen bounds
-- @param frame Frame - The frame to clamp
-- @param margin number - Margin from screen edges
function AnchorUtil.ClampToScreen(frame, margin)
    if not frame or type(frame) ~= "table" or not frame.GetEffectiveScale then
        error("LoolibAnchorUtil.ClampToScreen: frame must be a valid frame", 2)
    end

    margin = margin or 0

    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local scale = frame:GetEffectiveScale()

    local left = frame:GetLeft()
    local right = frame:GetRight()
    local top = frame:GetTop()
    local bottom = frame:GetBottom()

    -- Guard against frames with no valid position yet
    if not left or not right or not top or not bottom then
        return
    end

    left = left * scale
    right = right * scale
    top = top * scale
    bottom = bottom * scale

    local x, y = 0, 0

    if left < margin then
        x = margin - left
    elseif right > screenWidth - margin then
        x = screenWidth - margin - right
    end

    if bottom < margin then
        y = margin - bottom
    elseif top > screenHeight - margin then
        y = screenHeight - margin - top
    end

    if x ~= 0 or y ~= 0 then
        local currentX, currentY = frame:GetCenter()
        if currentX and currentY then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (currentX * scale + x) / scale, (currentY * scale + y) / scale)
        end
    end
end

--- Center a frame on the screen
-- @param frame Frame - The frame to center
function AnchorUtil.CenterOnScreen(frame)
    if not frame or type(frame) ~= "table" or not frame.ClearAllPoints then
        error("LoolibAnchorUtil.CenterOnScreen: frame must be a valid frame", 2)
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

UI.AnchorUtil = AnchorUtil
Loolib.AnchorUtil = AnchorUtil

Loolib:RegisterModule("UI.AnchorUtil", AnchorUtil)
