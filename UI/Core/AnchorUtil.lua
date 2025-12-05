--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    AnchorUtil - Utilities for frame anchoring and positioning
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

LoolibAnchorUtil = {}

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
function LoolibAnchorUtil.SetPoint(region, point, relativeTo, relativePoint, offsetX, offsetY)
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
function LoolibAnchorUtil.SetAllPoints(region, relativeTo, inset)
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
function LoolibAnchorUtil.SetAllPointsWithInsets(region, relativeTo, left, right, top, bottom)
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
function LoolibAnchorUtil.SetToRightOf(region, relativeTo, spacing, verticalOffset)
    region:ClearAllPoints()
    region:SetPoint("LEFT", relativeTo, "RIGHT", spacing or 0, verticalOffset or 0)
end

--- Position a region to the left of another
-- @param region Region - The region to position
-- @param relativeTo Region - The region to position relative to
-- @param spacing number - Horizontal spacing (default 0)
-- @param verticalOffset number - Vertical offset (default 0)
function LoolibAnchorUtil.SetToLeftOf(region, relativeTo, spacing, verticalOffset)
    region:ClearAllPoints()
    region:SetPoint("RIGHT", relativeTo, "LEFT", -(spacing or 0), verticalOffset or 0)
end

--- Position a region below another
-- @param region Region - The region to position
-- @param relativeTo Region - The region to position relative to
-- @param spacing number - Vertical spacing (default 0)
-- @param horizontalOffset number - Horizontal offset (default 0)
function LoolibAnchorUtil.SetBelow(region, relativeTo, spacing, horizontalOffset)
    region:ClearAllPoints()
    region:SetPoint("TOP", relativeTo, "BOTTOM", horizontalOffset or 0, -(spacing or 0))
end

--- Position a region above another
-- @param region Region - The region to position
-- @param relativeTo Region - The region to position relative to
-- @param spacing number - Vertical spacing (default 0)
-- @param horizontalOffset number - Horizontal offset (default 0)
function LoolibAnchorUtil.SetAbove(region, relativeTo, spacing, horizontalOffset)
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
function LoolibAnchorUtil.CenterHorizontally(region, relativeTo, verticalPoint, verticalOffset)
    region:ClearAllPoints()

    local point = verticalPoint or "CENTER"
    region:SetPoint(point, relativeTo, point, 0, verticalOffset or 0)
end

--- Center a region vertically within another
-- @param region Region - The region to center
-- @param relativeTo Frame - The frame to center within
-- @param horizontalPoint string - Horizontal anchor point ("LEFT", "CENTER", "RIGHT")
-- @param horizontalOffset number - Horizontal offset
function LoolibAnchorUtil.CenterVertically(region, relativeTo, horizontalPoint, horizontalOffset)
    region:ClearAllPoints()

    local point = horizontalPoint or "CENTER"
    region:SetPoint(point, relativeTo, point, horizontalOffset or 0, 0)
end

--- Center a region both horizontally and vertically
-- @param region Region - The region to center
-- @param relativeTo Frame - The frame to center within
-- @param offsetX number - Horizontal offset
-- @param offsetY number - Vertical offset
function LoolibAnchorUtil.Center(region, relativeTo, offsetX, offsetY)
    region:ClearAllPoints()
    region:SetPoint("CENTER", relativeTo, "CENTER", offsetX or 0, offsetY or 0)
end

--[[--------------------------------------------------------------------
    Corner Positioning
----------------------------------------------------------------------]]

--- Position a region in a corner of another
-- @param region Region - The region to position
-- @param relativeTo Frame - The frame to position within
-- @param corner string - Corner: "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"
-- @param offsetX number - Horizontal offset
-- @param offsetY number - Vertical offset
function LoolibAnchorUtil.SetCorner(region, relativeTo, corner, offsetX, offsetY)
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
function LoolibAnchorUtil.CalculateGridPosition(index, columns, cellWidth, cellHeight, spacingX, spacingY, paddingLeft, paddingTop)
    spacingX = spacingX or 0
    spacingY = spacingY or 0
    paddingLeft = paddingLeft or 0
    paddingTop = paddingTop or 0

    local row = math.floor((index - 1) / columns)
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
function LoolibAnchorUtil.SetGridPosition(region, parent, index, columns, cellWidth, cellHeight, spacingX, spacingY, paddingLeft, paddingTop)
    local x, y = LoolibAnchorUtil.CalculateGridPosition(
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
function LoolibAnchorUtil.SetPointsFromTable(region, points)
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
function LoolibAnchorUtil.ChainVertically(regions, parent, startPoint, spacing, padding, alignment)
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
function LoolibAnchorUtil.ChainHorizontally(regions, parent, startPoint, spacing, padding, alignment)
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
function LoolibAnchorUtil.ClampToScreen(frame, margin)
    margin = margin or 0

    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local scale = frame:GetEffectiveScale()

    local left = frame:GetLeft() * scale
    local right = frame:GetRight() * scale
    local top = frame:GetTop() * scale
    local bottom = frame:GetBottom() * scale

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
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (currentX * scale + x) / scale, (currentY * scale + y) / scale)
    end
end

--- Center a frame on the screen
-- @param frame Frame - The frame to center
function LoolibAnchorUtil.CenterOnScreen(frame)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.AnchorUtil = LoolibAnchorUtil

Loolib:RegisterModule("AnchorUtil", LoolibAnchorUtil)
