--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Tooltip - Custom tooltip with flexible content

    Features:
    - Attach to frames (auto show/hide)
    - Multi-line content
    - Double-line entries
    - Custom formatting
    - Multiple anchor positions
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local LoolibCreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for Tooltip")
local LoolibMixin = assert(Loolib.Mixin, "Loolib.Mixin is required for Tooltip")
local LoolibTemplates = assert(Loolib.Templates or (Loolib.UI and Loolib.UI.Templates), "Loolib.Templates is required for Tooltip")

-- Cache globals
local error = error
local ipairs = ipairs
local math_floor = math.floor
local math_max = math.max
local string_format = string.format
local table_concat = table.concat
local table_insert = table.insert
local type = type
local wipe = wipe

-- Cache WoW globals
local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local GetScreenHeight = GetScreenHeight
local GetScreenWidth = GetScreenWidth
local UIParent = UIParent

-- INTERNAL: Reference to Frame:Show() to avoid fragile metatable lookup (TP-01)
local FrameShow = getmetatable(CreateFrame("Frame")).__index.Show

--[[--------------------------------------------------------------------
    LoolibTooltipMixin
----------------------------------------------------------------------]]

---@class LoolibTooltipMixin : Frame
local LoolibTooltipMixin = {}

--- Initialize the tooltip
function LoolibTooltipMixin:OnLoad()
    self.lines = {}
    self.owner = nil
    self.anchor = "ANCHOR_RIGHT"
    self.offsetX = 0
    self.offsetY = 0

    -- Get references
    self.Title = self.Title or self:GetName() and _G[self:GetName() .. "Title"]
    self.Text = self.Text or self:GetName() and _G[self:GetName() .. "Text"]

    -- Hide by default
    self:Hide()
end

--[[--------------------------------------------------------------------
    Content Management
----------------------------------------------------------------------]]

--- Clear all content
function LoolibTooltipMixin:Clear()
    wipe(self.lines)

    if self.Title then
        self.Title:SetText("")
    end
    if self.Text then
        self.Text:SetText("")
    end
end

--- Set the title
-- @param title string - Title text
-- @param r number - Red (optional)
-- @param g number - Green (optional)
-- @param b number - Blue (optional)
function LoolibTooltipMixin:SetTitle(title, r, g, b)
    if self.Title then
        self.Title:SetText(title)
        if r then
            self.Title:SetTextColor(r, g or 1, b or 1, 1)
        else
            self.Title:SetTextColor(1, 1, 1, 1)
        end
    end
end

--- Add a line of text
-- @param text string - Line text
-- @param r number - Red (optional)
-- @param g number - Green (optional)
-- @param b number - Blue (optional)
function LoolibTooltipMixin:AddLine(text, r, g, b)
    self.lines[#self.lines + 1] = {
        type = "line",
        text = text,
        r = r or 1,
        g = g or 1,
        b = b or 1,
    }
end

--- Add a double line (left and right text)
-- @param leftText string - Left text
-- @param rightText string - Right text
-- @param leftR number - Left red
-- @param leftG number - Left green
-- @param leftB number - Left blue
-- @param rightR number - Right red
-- @param rightG number - Right green
-- @param rightB number - Right blue
function LoolibTooltipMixin:AddDoubleLine(leftText, rightText, leftR, leftG, leftB, rightR, rightG, rightB)
    self.lines[#self.lines + 1] = {
        type = "double",
        leftText = leftText,
        rightText = rightText,
        leftR = leftR or 1,
        leftG = leftG or 1,
        leftB = leftB or 1,
        rightR = rightR or 1,
        rightG = rightG or 1,
        rightB = rightB or 1,
    }
end

--- Add a blank line
function LoolibTooltipMixin:AddBlankLine()
    self.lines[#self.lines + 1] = {
        type = "blank",
    }
end

--- Add a separator line
function LoolibTooltipMixin:AddSeparator()
    self.lines[#self.lines + 1] = {
        type = "separator",
    }
end

--[[--------------------------------------------------------------------
    Display
----------------------------------------------------------------------]]

--- Set the owner and anchor
-- @param owner Frame - Frame to anchor to
-- @param anchor string - Anchor type (ANCHOR_RIGHT, ANCHOR_LEFT, ANCHOR_CURSOR, etc.)
-- @param offsetX number - X offset
-- @param offsetY number - Y offset
function LoolibTooltipMixin:SetOwner(owner, anchor, offsetX, offsetY)
    if owner ~= nil and type(owner) ~= "table" then
        error("LoolibTooltip: SetOwner: 'owner' must be a frame or nil", 2)
    end
    self.owner = owner
    self.anchor = anchor or "ANCHOR_RIGHT"
    self.offsetX = offsetX or 0
    self.offsetY = offsetY or 0
end

--- Show the tooltip
function LoolibTooltipMixin:Show()
    self:BuildContent()
    self:Position()
    -- FIX(TP-01): Use cached Frame.Show ref instead of fragile metatable lookup
    FrameShow(self)
end

--- Build the content from lines
-- FIX(TP-07): Use table.concat instead of string concatenation in loop
function LoolibTooltipMixin:BuildContent()
    if not self.Text then
        return
    end

    local parts = {}
    for _, line in ipairs(self.lines) do
        if line.type == "line" then
            local color = string_format("|cff%02x%02x%02x",
                math_floor(line.r * 255),
                math_floor(line.g * 255),
                math_floor(line.b * 255))
            table_insert(parts, color)
            table_insert(parts, line.text)
            table_insert(parts, "|r\n")
        elseif line.type == "double" then
            local leftColor = string_format("|cff%02x%02x%02x",
                math_floor(line.leftR * 255),
                math_floor(line.leftG * 255),
                math_floor(line.leftB * 255))
            local rightColor = string_format("|cff%02x%02x%02x",
                math_floor(line.rightR * 255),
                math_floor(line.rightG * 255),
                math_floor(line.rightB * 255))
            table_insert(parts, leftColor)
            table_insert(parts, line.leftText)
            table_insert(parts, "|r    ")
            table_insert(parts, rightColor)
            table_insert(parts, line.rightText)
            table_insert(parts, "|r\n")
        elseif line.type == "blank" then
            table_insert(parts, "\n")
        elseif line.type == "separator" then
            table_insert(parts, "|cff666666------------|r\n")
        end
    end

    -- Remove trailing newline from last entry
    local n = #parts
    if n > 0 then
        local last = parts[n]
        if last == "\n" then
            parts[n] = nil
        elseif last:sub(-1) == "\n" then
            parts[n] = last:sub(1, -2)
        end
    end

    self.Text:SetText(table_concat(parts))
    self:UpdateSize()
end

--- Update tooltip size to fit content
function LoolibTooltipMixin:UpdateSize()
    local titleHeight = self.Title and self.Title:GetStringHeight() or 0
    local textHeight = self.Text and self.Text:GetStringHeight() or 0
    local textWidth = self.Text and self.Text:GetStringWidth() or 0
    local titleWidth = self.Title and self.Title:GetStringWidth() or 0

    local width = math_max(textWidth, titleWidth) + 20
    local height = titleHeight + textHeight + 24

    if titleHeight > 0 and textHeight > 0 then
        height = height + 4  -- Spacing between title and text
    end

    self:SetSize(math_max(100, width), math_max(30, height))
end

--- Position the tooltip
function LoolibTooltipMixin:Position()
    if not self.owner then
        return
    end

    self:ClearAllPoints()

    if self.anchor == "ANCHOR_CURSOR" then
        local x, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + self.offsetX, y / scale + self.offsetY)
    elseif self.anchor == "ANCHOR_RIGHT" then
        self:SetPoint("LEFT", self.owner, "RIGHT", 5 + self.offsetX, self.offsetY)
    elseif self.anchor == "ANCHOR_LEFT" then
        self:SetPoint("RIGHT", self.owner, "LEFT", -5 + self.offsetX, self.offsetY)
    elseif self.anchor == "ANCHOR_TOP" then
        self:SetPoint("BOTTOM", self.owner, "TOP", self.offsetX, 5 + self.offsetY)
    elseif self.anchor == "ANCHOR_BOTTOM" then
        self:SetPoint("TOP", self.owner, "BOTTOM", self.offsetX, -5 + self.offsetY)
    elseif self.anchor == "ANCHOR_TOPRIGHT" then
        self:SetPoint("BOTTOMLEFT", self.owner, "TOPRIGHT", self.offsetX, self.offsetY)
    elseif self.anchor == "ANCHOR_TOPLEFT" then
        self:SetPoint("BOTTOMRIGHT", self.owner, "TOPLEFT", self.offsetX, self.offsetY)
    elseif self.anchor == "ANCHOR_BOTTOMRIGHT" then
        self:SetPoint("TOPLEFT", self.owner, "BOTTOMRIGHT", self.offsetX, self.offsetY)
    elseif self.anchor == "ANCHOR_BOTTOMLEFT" then
        self:SetPoint("TOPRIGHT", self.owner, "BOTTOMLEFT", self.offsetX, self.offsetY)
    else
        self:SetPoint("LEFT", self.owner, "RIGHT", 5, 0)
    end

    -- Clamp to screen
    self:ClampToScreen()
end

--- Clamp tooltip to screen bounds
-- FIX(TP-02): Nil-guard GetLeft/GetRight/GetTop/GetBottom which return nil
-- before the frame is positioned or has zero dimensions.
function LoolibTooltipMixin:ClampToScreen()
    local rawLeft = self:GetLeft()
    local rawRight = self:GetRight()
    local rawTop = self:GetTop()
    local rawBottom = self:GetBottom()

    -- Bail out if geometry is not yet available (frame not positioned)
    if not rawLeft or not rawRight or not rawTop or not rawBottom then
        return
    end

    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local scale = self:GetEffectiveScale()

    local left = rawLeft * scale
    local right = rawRight * scale
    local top = rawTop * scale
    local bottom = rawBottom * scale

    local xOffset = 0
    local yOffset = 0

    if right > screenWidth then
        xOffset = screenWidth - right
    elseif left < 0 then
        xOffset = -left
    end

    if top > screenHeight then
        yOffset = screenHeight - top
    elseif bottom < 0 then
        yOffset = -bottom
    end

    if xOffset ~= 0 or yOffset ~= 0 then
        local point, relativeTo, relativePoint, x, y = self:GetPoint()
        if point then
            self:SetPoint(point, relativeTo, relativePoint, x + xOffset / scale, y + yOffset / scale)
        end
    end
end

--[[--------------------------------------------------------------------
    Attach to Frame
----------------------------------------------------------------------]]

--- Attach tooltip to a frame (auto show/hide on enter/leave)
-- @param frame Frame - Frame to attach to
-- @param anchor string - Anchor type
function LoolibTooltipMixin:AttachToFrame(frame, anchor)
    if type(frame) ~= "table" or not frame.HookScript then
        error("LoolibTooltip: AttachToFrame: 'frame' must be a valid frame with HookScript", 2)
    end

    local tooltip = self

    frame:HookScript("OnEnter", function()
        tooltip:SetOwner(frame, anchor or "ANCHOR_RIGHT")
        tooltip:Show()
    end)

    frame:HookScript("OnLeave", function()
        tooltip:Hide()
    end)
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a tooltip
-- @param parent Frame - Parent frame
-- @return Frame - The tooltip frame
local function CreateLoolibTooltip(parent)
    local tooltip = CreateFrame("Frame", nil, parent or UIParent, "BackdropTemplate")
    LoolibTemplates.InitTooltip(tooltip)
    LoolibMixin(tooltip, LoolibTooltipMixin)
    tooltip:OnLoad()
    return tooltip
end

--[[--------------------------------------------------------------------
    Builder Pattern
----------------------------------------------------------------------]]

local LoolibTooltipBuilderMixin = {}

function LoolibTooltipBuilderMixin:Init(frame)
    self.frame = frame
    self.title = nil
    self.lines = {}
    self.anchor = "ANCHOR_RIGHT"
    self.offsetX = 0
    self.offsetY = 0
end

function LoolibTooltipBuilderMixin:SetTitle(title, r, g, b)
    self.title = { text = title, r = r, g = g, b = b }
    return self
end

function LoolibTooltipBuilderMixin:AddLine(text, r, g, b)
    self.lines[#self.lines + 1] = { type = "line", text = text, r = r, g = g, b = b }
    return self
end

function LoolibTooltipBuilderMixin:AddDoubleLine(leftText, rightText, leftR, leftG, leftB, rightR, rightG, rightB)
    self.lines[#self.lines + 1] = {
        type = "double",
        leftText = leftText,
        rightText = rightText,
        leftR = leftR, leftG = leftG, leftB = leftB,
        rightR = rightR, rightG = rightG, rightB = rightB,
    }
    return self
end

function LoolibTooltipBuilderMixin:SetAnchor(anchor, offsetX, offsetY)
    self.anchor = anchor
    self.offsetX = offsetX or 0
    self.offsetY = offsetY or 0
    return self
end

function LoolibTooltipBuilderMixin:Build()
    local tooltip = CreateLoolibTooltip()

    -- Set up content
    if self.title then
        tooltip:SetTitle(self.title.text, self.title.r, self.title.g, self.title.b)
    end

    for _, line in ipairs(self.lines) do
        if line.type == "line" then
            tooltip:AddLine(line.text, line.r, line.g, line.b)
        elseif line.type == "double" then
            tooltip:AddDoubleLine(line.leftText, line.rightText,
                line.leftR, line.leftG, line.leftB,
                line.rightR, line.rightG, line.rightB)
        end
    end

    -- Attach to frame
    tooltip:AttachToFrame(self.frame, self.anchor)
    tooltip.offsetX = self.offsetX
    tooltip.offsetY = self.offsetY

    return tooltip
end

local function LoolibTooltip(frame)
    local builder = LoolibCreateFromMixins(LoolibTooltipBuilderMixin)
    builder:Init(frame)
    return builder
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local TooltipModule = {
    Mixin = LoolibTooltipMixin,
    BuilderMixin = LoolibTooltipBuilderMixin,
    Create = CreateLoolibTooltip,
    Builder = LoolibTooltip,
}

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.Tooltip = TooltipModule
UI.CreateTooltip = CreateLoolibTooltip

Loolib:RegisterModule("UI.Tooltip", TooltipModule)
