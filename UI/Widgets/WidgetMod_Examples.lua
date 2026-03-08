--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    WidgetMod Usage Examples

    Real-world usage patterns and examples for the fluent API.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    EXAMPLE 1: Simple Information Panel

    Create a basic panel with title and text content.
----------------------------------------------------------------------]]

local function CreateInfoPanel(parent, title, content)
    local panel = LoolibCreateModFrame("Frame", parent, "BackdropTemplate")
        :Size(300, 150)
        :Point("CENTER")
        :Run(function(self)
            self:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            self:SetBackdropColor(0, 0, 0, 0.8)
            self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        end)
        :Movable()
        :ClampedToScreen()

    -- Title
    local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    LoolibApplyWidgetMod(titleText)
    titleText:Point("TOP", 0, -10):Text(title)

    -- Content
    local contentText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    LoolibApplyWidgetMod(contentText)
    contentText:Point("TOPLEFT", 10, -40)
        :Point("BOTTOMRIGHT", -10, 10)
        :Text(content)
        :Run(function(self)
            self:SetJustifyH("LEFT")
            self:SetJustifyV("TOP")
        end)

    -- Close button
    local closeBtn = LoolibCreateModFrame("Button", panel, "UIPanelCloseButton")
        :Size(24, 24)
        :Point("TOPRIGHT", -2, -2)
        :OnClick(function() panel:Hide() end)
        :Tooltip("Close")

    return panel
end

--[[--------------------------------------------------------------------
    EXAMPLE 2: Action Bar Button with Cooldown

    Create a custom action button with icon, tooltip, and click handler.
----------------------------------------------------------------------]]

local function CreateActionButton(parent, icon, tooltipText, onClick)
    local button = LoolibCreateModFrame("Button", parent)
        :Size(36, 36)
        :Mouse(true)
        :OnClick(onClick)
        :Tooltip(tooltipText)
        :TooltipAnchor("ANCHOR_RIGHT")
        :Run(function(self)
            -- Create icon texture
            self.icon = self:CreateTexture(nil, "ARTWORK")
            self.icon:SetAllPoints()
            self.icon:SetTexture(icon)

            -- Create border
            self.border = self:CreateTexture(nil, "OVERLAY")
            self.border:SetAllPoints()
            self.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            self.border:SetBlendMode("ADD")

            -- Highlight on hover
            self:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        end)

    return button
end

--[[--------------------------------------------------------------------
    EXAMPLE 3: Settings Panel with Multiple Controls

    Create a configuration panel with various input types.
----------------------------------------------------------------------]]

local function CreateSettingsPanel(parent)
    local panel = LoolibCreateModFrame("Frame", parent, "BackdropTemplate")
        :Size(400, 500)
        :Point("CENTER")
        :Run(function(self)
            self:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
            self:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        end)
        :Movable()
        :ClampedToScreen()

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    LoolibApplyWidgetMod(title)
    title:Point("TOP", 0, -20):Text("Settings")

    local yOffset = -60

    -- Checkbox example
    local checkbox = LoolibCreateModFrame("CheckButton", panel, "UICheckButtonTemplate")
        :Point("TOPLEFT", 20, yOffset)
        :Size(24, 24)
        :Tooltip({
            "Enable Feature",
            "This enables the feature",
            "Toggle to turn on/off"
        })
        :OnClick(function(self)
            print("Checkbox clicked:", self:GetChecked())
        end)

    local checkboxLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    LoolibApplyWidgetMod(checkboxLabel)
    checkboxLabel:Point("LEFT", checkbox, "RIGHT", 5, 0)
        :Text("Enable Advanced Mode")

    yOffset = yOffset - 40

    -- Slider example
    local slider = LoolibCreateModFrame("Slider", panel, "OptionsSliderTemplate")
        :Point("TOPLEFT", 20, yOffset)
        :Size(200, 16)
        :Run(function(self)
            self:SetMinMaxValues(0, 100)
            self:SetValue(50)
            self:SetValueStep(1)
            self:SetObeyStepOnDrag(true)
        end)
        :OnValueChanged(function(self, value)
            self.valueText:SetText(string.format("%.0f%%", value))
        end)

    slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    LoolibApplyWidgetMod(slider.valueText)
    slider.valueText:Point("TOP", slider, "BOTTOM", 0, -5)
        :Text("50%")

    local sliderLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    LoolibApplyWidgetMod(sliderLabel)
    sliderLabel:Point("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
        :Text("Opacity")

    yOffset = yOffset - 60

    -- EditBox example
    local editBox = LoolibCreateModFrame("EditBox", panel, "InputBoxTemplate")
        :Size(200, 30)
        :Point("TOPLEFT", 20, yOffset)
        :Run(function(self)
            self:SetAutoFocus(false)
            self:SetMaxLetters(50)
        end)
        :OnTextChanged(function(self, userInput)
            if userInput then
                print("EditBox changed:", self:GetText())
            end
        end)
        :OnEnterPressed(function(self)
            self:ClearFocus()
            print("EditBox submitted:", self:GetText())
        end)
        :OnEscapePressed(function(self)
            self:ClearFocus()
        end)
        :Tooltip("Enter custom text")

    local editBoxLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    LoolibApplyWidgetMod(editBoxLabel)
    editBoxLabel:Point("BOTTOMLEFT", editBox, "TOPLEFT", 0, 5)
        :Text("Custom Label")

    yOffset = yOffset - 60

    -- Buttons at bottom
    local saveBtn = LoolibCreateModFrame("Button", panel, "UIPanelButtonTemplate")
        :Size(100, 30)
        :Point("BOTTOMLEFT", 20, 20)
        :Text("Save")
        :OnClick(function()
            print("Settings saved!")
        end)
        :Tooltip("Save current settings")

    local cancelBtn = LoolibCreateModFrame("Button", panel, "UIPanelButtonTemplate")
        :Size(100, 30)
        :Point("BOTTOMRIGHT", -20, 20)
        :Text("Cancel")
        :OnClick(function()
            panel:Hide()
        end)
        :Tooltip("Close without saving")

    return panel
end

--[[--------------------------------------------------------------------
    EXAMPLE 4: Dynamic List with Scroll

    Create a scrollable list of items.
----------------------------------------------------------------------]]

local function CreateScrollList(parent, items)
    local frame = LoolibCreateModFrame("Frame", parent, "BackdropTemplate")
        :Size(250, 400)
        :Point("CENTER")
        :Run(function(self)
            self:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            self:SetBackdropColor(0, 0, 0, 0.7)
            self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end)

    -- Scroll frame
    local scrollFrame = LoolibCreateModFrame("ScrollFrame", frame, "UIPanelScrollFrameTemplate")
        :Point("TOPLEFT", 10, -10)
        :Point("BOTTOMRIGHT", -30, 10)

    -- Scroll child (content container)
    local content = LoolibCreateModFrame("Frame", scrollFrame)
        :Size(200, 1)

    scrollFrame:SetScrollChild(content)

    -- Populate items
    local yPos = -5
    for i, itemData in ipairs(items) do
        local item = LoolibCreateModFrame("Button", content, "UIPanelButtonTemplate")
            :Size(200, 30)
            :Point("TOP", 0, yPos)
            :Text(itemData.text)
            :OnClick(function(self)
                print("Clicked:", itemData.text)
            end)
            :Tooltip(itemData.tooltip or itemData.text)

        yPos = yPos - 35
    end

    -- Update content height
    content:Height(math.abs(yPos) + 5)

    return frame
end

--[[--------------------------------------------------------------------
    EXAMPLE 5: Fade In/Out Animation

    Create a frame with animated transitions.
----------------------------------------------------------------------]]

local function CreateFadeFrame(parent, text)
    local frame = LoolibCreateModFrame("Frame", parent, "BackdropTemplate")
        :Size(300, 100)
        :Point("CENTER")
        :Alpha(0)
        :Run(function(self)
            self:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            self:SetBackdropColor(0, 0, 0, 0.9)
            self:SetBackdropBorderColor(1, 1, 0, 1)
        end)

    -- Text
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    LoolibApplyWidgetMod(label)
    label:Point("CENTER"):Text(text)

    -- Fade in method
    frame.FadeIn = function(self, duration)
        duration = duration or 0.5
        self:Show()

        local elapsed = 0
        self:OnUpdate(function(self, dt)
            elapsed = elapsed + dt
            local progress = math.min(elapsed / duration, 1)
            self:SetAlpha(progress)

            if progress >= 1 then
                self:SetScript("OnUpdate", nil)
            end
        end)
    end

    -- Fade out method
    frame.FadeOut = function(self, duration)
        duration = duration or 0.5

        local startAlpha = self:GetAlpha()
        local elapsed = 0

        self:OnUpdate(function(self, dt)
            elapsed = elapsed + dt
            local progress = math.min(elapsed / duration, 1)
            self:SetAlpha(startAlpha * (1 - progress))

            if progress >= 1 then
                self:Hide()
                self:SetAlpha(1)
                self:SetScript("OnUpdate", nil)
            end
        end)
    end

    return frame
end

--[[--------------------------------------------------------------------
    EXAMPLE 6: Context Menu

    Create a right-click context menu.
----------------------------------------------------------------------]]

local function CreateContextMenu(parent, menuItems)
    local menu = LoolibCreateModFrame("Frame", UIParent, "BackdropTemplate")
        :Size(150, #menuItems * 25 + 10)
        :FrameStrata("DIALOG")
        :Alpha(0.95)
        :Run(function(self)
            self:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
            self:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
            self:Hide()
        end)

    local yPos = -8
    for i, item in ipairs(menuItems) do
        local btn = LoolibCreateModFrame("Button", menu)
            :Size(130, 20)
            :Point("TOP", 0, yPos)
            :OnClick(function()
                if item.onClick then
                    item.onClick()
                end
                menu:Hide()
            end)
            :OnEnter(function(self)
                self:SetAlpha(0.7)
            end)
            :OnLeave(function(self)
                self:SetAlpha(1.0)
            end)

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        LoolibApplyWidgetMod(label)
        label:Point("LEFT", 5, 0):Text(item.text)

        yPos = yPos - 25
    end

    -- Show at cursor
    menu.ShowAtCursor = function(self)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearPoints()
        self:Point("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        self:Show()
    end

    -- Hide on click outside
    menu:OnShow(function(self)
        self:SetScript("OnUpdate", function(self)
            if not self:IsMouseOver() and IsMouseButtonDown() then
                self:Hide()
                self:SetScript("OnUpdate", nil)
            end
        end)
    end, true)

    return menu
end

--[[--------------------------------------------------------------------
    Export Examples
----------------------------------------------------------------------]]

-- Make examples available globally for testing
LOOLIB_WIDGET_EXAMPLES = {
    CreateInfoPanel = CreateInfoPanel,
    CreateActionButton = CreateActionButton,
    CreateSettingsPanel = CreateSettingsPanel,
    CreateScrollList = CreateScrollList,
    CreateFadeFrame = CreateFadeFrame,
    CreateContextMenu = CreateContextMenu,
}
