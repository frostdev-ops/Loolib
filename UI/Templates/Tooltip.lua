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

--[[--------------------------------------------------------------------
    LoolibTooltipMixin
----------------------------------------------------------------------]]

LoolibTooltipMixin = {}

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
    self.owner = owner
    self.anchor = anchor or "ANCHOR_RIGHT"
    self.offsetX = offsetX or 0
    self.offsetY = offsetY or 0
end

--- Show the tooltip
function LoolibTooltipMixin:Show()
    self:BuildContent()
    self:Position()
    getmetatable(self).__index.Show(self)
end

--- Build the content from lines
function LoolibTooltipMixin:BuildContent()
    if not self.Text then
        return
    end

    local textContent = ""
    for i, line in ipairs(self.lines) do
        if line.type == "line" then
            local color = string.format("|cff%02x%02x%02x",
                math.floor(line.r * 255),
                math.floor(line.g * 255),
                math.floor(line.b * 255))
            textContent = textContent .. color .. line.text .. "|r\n"
        elseif line.type == "double" then
            local leftColor = string.format("|cff%02x%02x%02x",
                math.floor(line.leftR * 255),
                math.floor(line.leftG * 255),
                math.floor(line.leftB * 255))
            local rightColor = string.format("|cff%02x%02x%02x",
                math.floor(line.rightR * 255),
                math.floor(line.rightG * 255),
                math.floor(line.rightB * 255))
            textContent = textContent .. leftColor .. line.leftText .. "|r    " .. rightColor .. line.rightText .. "|r\n"
        elseif line.type == "blank" then
            textContent = textContent .. "\n"
        elseif line.type == "separator" then
            textContent = textContent .. "|cff666666------------|r\n"
        end
    end

    -- Remove trailing newline
    textContent = textContent:gsub("\n$", "")

    self.Text:SetText(textContent)
    self:UpdateSize()
end

--- Update tooltip size to fit content
function LoolibTooltipMixin:UpdateSize()
    local titleHeight = self.Title and self.Title:GetStringHeight() or 0
    local textHeight = self.Text and self.Text:GetStringHeight() or 0
    local textWidth = self.Text and self.Text:GetStringWidth() or 0
    local titleWidth = self.Title and self.Title:GetStringWidth() or 0

    local width = math.max(textWidth, titleWidth) + 20
    local height = titleHeight + textHeight + 24

    if titleHeight > 0 and textHeight > 0 then
        height = height + 4  -- Spacing between title and text
    end

    self:SetSize(math.max(100, width), math.max(30, height))
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
function LoolibTooltipMixin:ClampToScreen()
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local scale = self:GetEffectiveScale()

    local left = self:GetLeft() * scale
    local right = self:GetRight() * scale
    local top = self:GetTop() * scale
    local bottom = self:GetBottom() * scale

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
        self:SetPoint(point, relativeTo, relativePoint, x + xOffset / scale, y + yOffset / scale)
    end
end

--[[--------------------------------------------------------------------
    Attach to Frame
----------------------------------------------------------------------]]

--- Attach tooltip to a frame (auto show/hide on enter/leave)
-- @param frame Frame - Frame to attach to
-- @param anchor string - Anchor type
function LoolibTooltipMixin:AttachToFrame(frame, anchor)
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
function CreateLoolibTooltip(parent)
    local tooltip = CreateFrame("Frame", nil, parent or UIParent, "LoolibTooltipTemplate")
    LoolibMixin(tooltip, LoolibTooltipMixin)
    tooltip:OnLoad()
    return tooltip
end

--[[--------------------------------------------------------------------
    Builder Pattern
----------------------------------------------------------------------]]

LoolibTooltipBuilderMixin = {}

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

function LoolibTooltip(frame)
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

local UI = Loolib:GetOrCreateModule("UI")
UI.Tooltip = TooltipModule
UI.CreateTooltip = CreateLoolibTooltip

Loolib:RegisterModule("Tooltip", TooltipModule)
