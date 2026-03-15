--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    RegionUtil - Utilities for working with regions (textures, font strings)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
local RegionUtil = UI.RegionUtil or Loolib:GetModule("UI.RegionUtil") or {}

-- Cache globals
local error = error
local ipairs = ipairs
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local select = select
local tostring = tostring
local type = type

--[[--------------------------------------------------------------------
    Internal Helpers
----------------------------------------------------------------------]]

--- Validate that a value is a valid frame (has CreateTexture) -- INTERNAL
-- @param parent any - The value to check
-- @param caller string - Calling function name for error messages
local function ValidateParent(parent, caller)
    if not parent or type(parent) ~= "table" or not parent.CreateTexture then
        error("LoolibRegionUtil." .. caller .. ": parent must be a valid frame", 2)
    end
end

--- Validate that a value is a valid region (has IsObjectType) -- INTERNAL
-- @param region any - The value to check
-- @param caller string - Calling function name for error messages
local function ValidateRegion(region, caller)
    if not region or type(region) ~= "table" or not region.IsObjectType then
        error("LoolibRegionUtil." .. caller .. ": region must be a valid region", 2)
    end
end

--[[--------------------------------------------------------------------
    Texture Utilities
----------------------------------------------------------------------]]

--- Create a colored texture
-- @param parent Frame - Parent frame
-- @param r number - Red (0-1)
-- @param g number - Green (0-1)
-- @param b number - Blue (0-1)
-- @param a number - Alpha (0-1, default 1)
-- @param layer string - Draw layer (default "BACKGROUND")
-- @return Texture
function RegionUtil.CreateColorTexture(parent, r, g, b, a, layer)
    ValidateParent(parent, "CreateColorTexture")
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        error("LoolibRegionUtil.CreateColorTexture: r, g, b must be numbers", 2)
    end

    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetColorTexture(r, g, b, a or 1)
    return texture
end

--- Create a texture from a file
-- @param parent Frame - Parent frame
-- @param texturePath string - Path to texture file
-- @param layer string - Draw layer (default "ARTWORK")
-- @return Texture
function RegionUtil.CreateTexture(parent, texturePath, layer)
    ValidateParent(parent, "CreateTexture")
    if type(texturePath) ~= "string" then
        error("LoolibRegionUtil.CreateTexture: texturePath must be a string", 2)
    end

    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture(texturePath)
    return texture
end

--- Create an atlas texture
-- @param parent Frame - Parent frame
-- @param atlasName string - Atlas name
-- @param layer string - Draw layer (default "ARTWORK")
-- @return Texture
function RegionUtil.CreateAtlasTexture(parent, atlasName, layer)
    ValidateParent(parent, "CreateAtlasTexture")
    if type(atlasName) ~= "string" then
        error("LoolibRegionUtil.CreateAtlasTexture: atlasName must be a string", 2)
    end

    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetAtlas(atlasName)
    return texture
end

--- Set texture coordinates for a portion of a texture
-- @param texture Texture - The texture
-- @param left number - Left coord (0-1)
-- @param right number - Right coord (0-1)
-- @param top number - Top coord (0-1)
-- @param bottom number - Bottom coord (0-1)
function RegionUtil.SetTexCoord(texture, left, right, top, bottom)
    ValidateRegion(texture, "SetTexCoord")
    if type(left) ~= "number" or type(right) ~= "number" or type(top) ~= "number" or type(bottom) ~= "number" then
        error("LoolibRegionUtil.SetTexCoord: left, right, top, bottom must be numbers", 2)
    end

    texture:SetTexCoord(left, right, top, bottom)
end

--- Calculate tex coords for a grid-based sprite sheet
-- @param col number - Column (1-based)
-- @param row number - Row (1-based)
-- @param cols number - Total columns
-- @param rows number - Total rows
-- @return number, number, number, number - left, right, top, bottom
function RegionUtil.CalculateSpriteTexCoords(col, row, cols, rows)
    if type(col) ~= "number" or type(row) ~= "number" or type(cols) ~= "number" or type(rows) ~= "number" then
        error("LoolibRegionUtil.CalculateSpriteTexCoords: col, row, cols, rows must be numbers", 2)
    end
    if cols <= 0 or rows <= 0 then
        error("LoolibRegionUtil.CalculateSpriteTexCoords: cols and rows must be positive", 2)
    end

    local width = 1 / cols
    local height = 1 / rows

    local left = (col - 1) * width
    local right = col * width
    local top = (row - 1) * height
    local bottom = row * height

    return left, right, top, bottom
end

--[[--------------------------------------------------------------------
    FontString Utilities
----------------------------------------------------------------------]]

--- Create a font string
-- @param parent Frame - Parent frame
-- @param fontObject string - Font object name (default "GameFontNormal")
-- @param layer string - Draw layer (default "OVERLAY")
-- @return FontString
function RegionUtil.CreateFontString(parent, fontObject, layer)
    ValidateParent(parent, "CreateFontString")

    return parent:CreateFontString(nil, layer or "OVERLAY", fontObject or "GameFontNormal")
end

--- Create a font string with initial text
-- @param parent Frame - Parent frame
-- @param text string - Initial text
-- @param fontObject string - Font object name
-- @param layer string - Draw layer
-- @return FontString
function RegionUtil.CreateText(parent, text, fontObject, layer)
    ValidateParent(parent, "CreateText")

    local fontString = RegionUtil.CreateFontString(parent, fontObject, layer)
    if text then
        fontString:SetText(text)
    end
    return fontString
end

--- Set font string properties in one call
-- @param fontString FontString - The font string
-- @param options table - Options: text, font, size, outline, color, shadow
function RegionUtil.ConfigureFontString(fontString, options)
    ValidateRegion(fontString, "ConfigureFontString")
    if type(options) ~= "table" then
        error("LoolibRegionUtil.ConfigureFontString: options must be a table", 2)
    end

    if options.text then
        fontString:SetText(options.text)
    end

    if options.font and options.size then
        local flags = options.outline or ""
        fontString:SetFont(options.font, options.size, flags)
    end

    if options.color then
        if type(options.color) == "table" then
            fontString:SetTextColor(
                options.color.r or options.color[1] or 1,
                options.color.g or options.color[2] or 1,
                options.color.b or options.color[3] or 1,
                options.color.a or options.color[4] or 1
            )
        end
    end

    if options.shadow then
        fontString:SetShadowOffset(options.shadow.x or 1, options.shadow.y or -1)
        if options.shadow.color then
            fontString:SetShadowColor(
                options.shadow.color.r or 0,
                options.shadow.color.g or 0,
                options.shadow.color.b or 0,
                options.shadow.color.a or 1
            )
        end
    end

    if options.justifyH then
        fontString:SetJustifyH(options.justifyH)
    end

    if options.justifyV then
        fontString:SetJustifyV(options.justifyV)
    end

    if options.wordWrap ~= nil then
        fontString:SetWordWrap(options.wordWrap)
    end

    if options.nonSpaceWrap ~= nil then
        fontString:SetNonSpaceWrap(options.nonSpaceWrap)
    end

    if options.maxLines then
        fontString:SetMaxLines(options.maxLines)
    end
end

--- Truncate text to fit within a width
-- @param fontString FontString - The font string
-- @param maxWidth number - Maximum width in pixels
-- @param suffix string - Suffix to add when truncated (default "...")
function RegionUtil.TruncateText(fontString, maxWidth, suffix)
    ValidateRegion(fontString, "TruncateText")
    if type(maxWidth) ~= "number" or maxWidth <= 0 then
        error("LoolibRegionUtil.TruncateText: maxWidth must be a positive number", 2)
    end

    suffix = suffix or "..."
    local text = fontString:GetText()

    if not text or fontString:GetStringWidth() <= maxWidth then
        return
    end

    -- Binary search for the right length
    local low, high = 1, #text
    while low < high do
        local mid = math_ceil((low + high) / 2)
        fontString:SetText(text:sub(1, mid) .. suffix)

        if fontString:GetStringWidth() <= maxWidth then
            low = mid
        else
            high = mid - 1
        end
    end

    fontString:SetText(text:sub(1, low) .. suffix)
end

--[[--------------------------------------------------------------------
    Line Utilities
----------------------------------------------------------------------]]

--- Create a horizontal divider line
-- @param parent Frame - Parent frame
-- @param thickness number - Line thickness (default 1)
-- @param color table - Color table {r, g, b, a}
-- @param layer string - Draw layer
-- @return Texture
function RegionUtil.CreateHorizontalLine(parent, thickness, color, layer)
    ValidateParent(parent, "CreateHorizontalLine")

    local line = parent:CreateTexture(nil, layer or "ARTWORK")
    line:SetHeight(thickness or 1)

    if color then
        line:SetColorTexture(color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4] or 1)
    else
        line:SetColorTexture(0.5, 0.5, 0.5, 1)
    end

    return line
end

--- Create a vertical divider line
-- @param parent Frame - Parent frame
-- @param thickness number - Line thickness (default 1)
-- @param color table - Color table {r, g, b, a}
-- @param layer string - Draw layer
-- @return Texture
function RegionUtil.CreateVerticalLine(parent, thickness, color, layer)
    ValidateParent(parent, "CreateVerticalLine")

    local line = parent:CreateTexture(nil, layer or "ARTWORK")
    line:SetWidth(thickness or 1)

    if color then
        line:SetColorTexture(color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4] or 1)
    else
        line:SetColorTexture(0.5, 0.5, 0.5, 1)
    end

    return line
end

--[[--------------------------------------------------------------------
    Region Bounds
----------------------------------------------------------------------]]

--- Get the bounding box of multiple regions
-- @param regions table - Array of regions
-- @return number, number, number, number - left, right, top, bottom (or nil if no visible regions)
function RegionUtil.GetBoundingBox(regions)
    if type(regions) ~= "table" then
        error("LoolibRegionUtil.GetBoundingBox: regions must be a table", 2)
    end

    local minLeft, maxRight, maxTop, minBottom

    for _, region in ipairs(regions) do
        if region and region.IsShown and region:IsShown() then
            local left = region:GetLeft()
            local right = region:GetRight()
            local top = region:GetTop()
            local bottom = region:GetBottom()

            if left and right and top and bottom then
                minLeft = minLeft and math_min(minLeft, left) or left
                maxRight = maxRight and math_max(maxRight, right) or right
                maxTop = maxTop and math_max(maxTop, top) or top
                minBottom = minBottom and math_min(minBottom, bottom) or bottom
            end
        end
    end

    return minLeft, maxRight, maxTop, minBottom
end

--- Check if two regions overlap
-- @param region1 Region - First region
-- @param region2 Region - Second region
-- @return boolean
function RegionUtil.DoRegionsOverlap(region1, region2)
    if not region1 or not region2 then
        return false
    end

    local left1, right1 = region1:GetLeft(), region1:GetRight()
    local top1, bottom1 = region1:GetTop(), region1:GetBottom()
    local left2, right2 = region2:GetLeft(), region2:GetRight()
    local top2, bottom2 = region2:GetTop(), region2:GetBottom()

    if not (left1 and right1 and top1 and bottom1 and left2 and right2 and top2 and bottom2) then
        return false
    end

    return not (right1 < left2 or left1 > right2 or top1 < bottom2 or bottom1 > top2)
end

--- Check if a point is inside a region
-- @param region Region - The region
-- @param x number - X coordinate
-- @param y number - Y coordinate
-- @return boolean
function RegionUtil.IsPointInRegion(region, x, y)
    if not region or type(x) ~= "number" or type(y) ~= "number" then
        return false
    end

    local left = region:GetLeft()
    local right = region:GetRight()
    local top = region:GetTop()
    local bottom = region:GetBottom()

    if not (left and right and top and bottom) then
        return false
    end

    return x >= left and x <= right and y >= bottom and y <= top
end

--[[--------------------------------------------------------------------
    Color Utilities
----------------------------------------------------------------------]]

--- Apply a color to a region (texture or font string)
-- @param region Region - The region
-- @param r number - Red
-- @param g number - Green
-- @param b number - Blue
-- @param a number - Alpha
function RegionUtil.SetColor(region, r, g, b, a)
    ValidateRegion(region, "SetColor")

    a = a or 1

    if region:IsObjectType("Texture") then
        region:SetVertexColor(r, g, b, a)
    elseif region:IsObjectType("FontString") then
        region:SetTextColor(r, g, b, a)
    elseif region:IsObjectType("Line") then
        region:SetColorTexture(r, g, b, a)
    end
end

--- Get the color from a region
-- @param region Region - The region
-- @return number, number, number, number - r, g, b, a
function RegionUtil.GetColor(region)
    if not region or type(region) ~= "table" or not region.IsObjectType then
        return 1, 1, 1, 1
    end

    if region:IsObjectType("Texture") then
        return region:GetVertexColor()
    elseif region:IsObjectType("FontString") then
        return region:GetTextColor()
    end
    return 1, 1, 1, 1
end

--[[--------------------------------------------------------------------
    Visibility
----------------------------------------------------------------------]]

--- Set the shown state of multiple regions
-- @param regions table - Array of regions
-- @param shown boolean - Whether to show or hide
function RegionUtil.SetShown(regions, shown)
    if type(regions) ~= "table" then
        error("LoolibRegionUtil.SetShown: regions must be a table", 2)
    end

    for _, region in ipairs(regions) do
        if region and region.SetShown then
            region:SetShown(shown)
        end
    end
end

--- Hide multiple regions
-- @param ... Region - Regions to hide
function RegionUtil.HideAll(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.Hide then
            region:Hide()
        end
    end
end

--- Show multiple regions
-- @param ... Region - Regions to show
function RegionUtil.ShowAll(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.Show then
            region:Show()
        end
    end
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

UI.RegionUtil = RegionUtil
Loolib.RegionUtil = RegionUtil

Loolib:RegisterModule("UI.RegionUtil", RegionUtil)
