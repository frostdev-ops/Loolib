local Loolib = LibStub("Loolib")
local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")

--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Templates - Lua-based template initialization functions

    Replaces Templates.xml to avoid "Deferred XML Node already exists"
    errors when both standalone and embedded Loolib are loaded.
    LibStub guards Lua from double-loading; XML has no such guard.
----------------------------------------------------------------------]]

-- Version guard: if a newer or equal version already loaded, bail out
if Loolib.templatesVersion and Loolib.templatesVersion >= 1 then
    return
end
Loolib.templatesVersion = 1

local LoolibTemplates = {}

--[[--------------------------------------------------------------------
    LoolibPanelTemplate
    Base panel with backdrop support
----------------------------------------------------------------------]]
function LoolibTemplates.InitPanel(frame)
    frame:SetSize(300, 200)
    -- Title
    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetJustifyH("CENTER")
    frame.Title:SetPoint("TOP", 0, -10)
    -- Backdrop
    frame:SetBackdrop(BACKDROP_DIALOG_32_32)
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
end

--[[--------------------------------------------------------------------
    LoolibCloseButtonTemplate
----------------------------------------------------------------------]]
function LoolibTemplates.InitCloseButton(button)
    button:SetSize(24, 24)
end

--[[--------------------------------------------------------------------
    LoolibButtonTemplate
----------------------------------------------------------------------]]
function LoolibTemplates.InitButton(button)
    button:SetSize(100, 22)
end

--[[--------------------------------------------------------------------
    LoolibListItemTemplate
    Base template for scrollable list items
----------------------------------------------------------------------]]
function LoolibTemplates.InitListItem(button)
    button:SetSize(200, 24)
    -- Background
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0.1, 0.1, 0.1, 0)
    button.Background = bg
    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(true)
    highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    button.Highlight = highlight
    -- Text
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -8, 0)
    button.Text = text
    -- Scripts
    button:SetScript("OnEnter", function(self)
        self.Highlight:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if not self.selected then
            self.Highlight:Hide()
        end
    end)
end

--[[--------------------------------------------------------------------
    LoolibScrollableListTemplate
    Scrollable list container
----------------------------------------------------------------------]]
function LoolibTemplates.InitScrollableList(frame)
    frame:SetSize(250, 300)
    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 4)
    frame.ScrollFrame = scrollFrame
    -- Content
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    content:SetPoint("TOPLEFT")
    scrollFrame.Content = content
    scrollFrame:SetScrollChild(content)
    -- Backdrop
    frame:SetBackdrop(BACKDROP_DIALOG_32_32)
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
end

--[[--------------------------------------------------------------------
    LoolibTabButtonTemplate
----------------------------------------------------------------------]]
function LoolibTemplates.InitTabButton(button)
    button:SetSize(80, 28)
    -- Background
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    button.Background = bg
    -- Left border
    local leftBorder = button:CreateTexture(nil, "BORDER")
    leftBorder:SetWidth(1)
    leftBorder:SetPoint("TOPLEFT")
    leftBorder:SetPoint("BOTTOMLEFT")
    leftBorder:SetColorTexture(0.4, 0.4, 0.4, 1)
    button.LeftBorder = leftBorder
    -- Right border
    local rightBorder = button:CreateTexture(nil, "BORDER")
    rightBorder:SetWidth(1)
    rightBorder:SetPoint("TOPRIGHT")
    rightBorder:SetPoint("BOTTOMRIGHT")
    rightBorder:SetColorTexture(0.4, 0.4, 0.4, 1)
    button.RightBorder = rightBorder
    -- Top border
    local topBorder = button:CreateTexture(nil, "BORDER")
    topBorder:SetHeight(1)
    topBorder:SetPoint("TOPLEFT")
    topBorder:SetPoint("TOPRIGHT")
    topBorder:SetColorTexture(0.4, 0.4, 0.4, 1)
    button.TopBorder = topBorder
    -- Text
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetJustifyH("CENTER")
    text:SetPoint("CENTER")
    button.Text = text
    -- Highlight
    local highlightTexture = button:CreateTexture()
    highlightTexture:SetAllPoints(true)
    highlightTexture:SetColorTexture(0.2, 0.2, 0.2, 0.3)
    highlightTexture:SetBlendMode("ADD")
    button:SetHighlightTexture(highlightTexture)
end

--[[--------------------------------------------------------------------
    LoolibTabbedPanelTemplate
----------------------------------------------------------------------]]
function LoolibTemplates.InitTabbedPanel(frame)
    frame:SetSize(400, 300)
    -- TabBar
    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetSize(1, 28)
    tabBar:SetPoint("TOPLEFT")
    tabBar:SetPoint("TOPRIGHT")
    frame.TabBar = tabBar
    -- ContentFrame
    local contentFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentFrame:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT")
    contentFrame:SetPoint("BOTTOMRIGHT")
    contentFrame:SetBackdrop(BACKDROP_DIALOG_32_32)
    contentFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    contentFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    frame.ContentFrame = contentFrame
end

--[[--------------------------------------------------------------------
    LoolibTooltipTemplate
----------------------------------------------------------------------]]
function LoolibTemplates.InitTooltip(frame)
    frame:SetSize(200, 50)
    frame:SetFrameStrata("TOOLTIP")
    -- Title
    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetPoint("TOPLEFT", 10, -10)
    frame.Title:SetPoint("TOPRIGHT", -10, -10)
    -- Text
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetJustifyV("TOP")
    frame.Text:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -4)
    frame.Text:SetPoint("RIGHT", -10, 0)
    -- Backdrop
    frame:SetBackdrop(BACKDROP_TOOLTIP_16_16_5555)
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

--[[--------------------------------------------------------------------
    LoolibDialogTemplate
----------------------------------------------------------------------]]
function LoolibTemplates.InitDialog(frame)
    frame:SetSize(320, 160)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    -- Title
    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetJustifyH("CENTER")
    frame.Title:SetPoint("TOP", 0, -15)
    -- Message
    frame.Message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Message:SetJustifyH("CENTER")
    frame.Message:SetJustifyV("TOP")
    frame.Message:SetSize(280, 0)
    frame.Message:SetPoint("TOP", frame.Title, "BOTTOM", 0, -10)
    -- CloseButton
    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", -3, -3)
    -- ButtonContainer
    frame.ButtonContainer = CreateFrame("Frame", nil, frame)
    frame.ButtonContainer:SetSize(1, 30)
    frame.ButtonContainer:SetPoint("BOTTOMLEFT", 20, 15)
    frame.ButtonContainer:SetPoint("BOTTOMRIGHT", -20, 15)
    -- Backdrop
    frame:SetBackdrop(BACKDROP_DIALOG_32_32)
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

--[[--------------------------------------------------------------------
    LoolibModalOverlayTemplate
----------------------------------------------------------------------]]
function LoolibTemplates.InitModalOverlay(frame)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    -- Background overlay
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.5)
end

--[[--------------------------------------------------------------------
    LoolibDropdownTemplate
----------------------------------------------------------------------]]
function LoolibTemplates.InitDropdown(frame)
    frame:SetSize(150, 24)
    frame:EnableMouse(true)
    -- Button
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(24, 24)
    button:SetPoint("RIGHT", -2, 0)
    button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    frame.Button = button
    -- Text
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetPoint("LEFT", 8, 0)
    frame.Text:SetPoint("RIGHT", button, "LEFT", -4, 0)
    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
end

--[[--------------------------------------------------------------------
    LoolibDropdownMenuTemplate
----------------------------------------------------------------------]]
function LoolibTemplates.InitDropdownMenu(frame)
    frame:SetSize(150, 100)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(true)
    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -4, 4)
    frame.ScrollFrame = scrollFrame
    -- Content
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    content:SetPoint("TOPLEFT")
    scrollFrame.Content = content
    scrollFrame:SetScrollChild(content)
    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

--[[--------------------------------------------------------------------
    LoolibDropdownMenuItemTemplate
----------------------------------------------------------------------]]
function LoolibTemplates.InitDropdownMenuItem(button)
    button:SetSize(140, 20)
    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(true)
    highlight:SetColorTexture(0.2, 0.4, 0.6, 0.5)
    button.Highlight = highlight
    -- Text
    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.Text:SetJustifyH("LEFT")
    button.Text:SetPoint("LEFT", 8, 0)
    button.Text:SetPoint("RIGHT", -8, 0)
    -- Check
    button.Check = button:CreateTexture(nil, "OVERLAY")
    button.Check:SetSize(14, 14)
    button.Check:SetPoint("LEFT", 4, 0)
    button.Check:Hide()
end

--[[--------------------------------------------------------------------
    LoolibInputDialogTemplate
    Extends DialogTemplate with an EditBox
----------------------------------------------------------------------]]
function LoolibTemplates.InitInputDialog(frame)
    LoolibTemplates.InitDialog(frame)
    frame:SetSize(320, 140)
    -- EditBox
    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetSize(260, 24)
    editBox:SetAutoFocus(false)
    editBox:SetPoint("TOP", frame.Message, "BOTTOM", 0, -10)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    frame.EditBox = editBox
end

UI.Templates = LoolibTemplates
Loolib.Templates = LoolibTemplates

Loolib:RegisterModule("UI.Templates", LoolibTemplates)
