--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Dialog - Modal and non-modal dialogs

    Features:
    - Confirmation dialogs
    - Input dialogs (single or multiple editboxes)
    - Multiple checkboxes
    - Icon display
    - Custom button configurations
    - Modal overlay support
    - Escape to close
    - Auto-dismiss with duration timer
    - Lifecycle callbacks (on_show, on_hide, on_update)
    - Delegate pattern (dialog templates)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Dialog Stack
----------------------------------------------------------------------]]

local dialogStack = {}
local modalOverlay = nil

local function GetModalOverlay()
    if not modalOverlay then
        modalOverlay = CreateFrame("Frame", nil, UIParent, "LoolibModalOverlayTemplate")
        modalOverlay:SetAllPoints(UIParent)
        modalOverlay:SetFrameStrata("DIALOG")
        modalOverlay:Hide()
    end
    return modalOverlay
end

local function UpdateModalOverlay()
    local overlay = GetModalOverlay()

    -- Find highest modal dialog
    local highestLevel = 0
    local hasModal = false

    for _, dialog in ipairs(dialogStack) do
        if dialog.modal and dialog:IsShown() then
            hasModal = true
            highestLevel = math.max(highestLevel, dialog:GetFrameLevel())
        end
    end

    if hasModal then
        overlay:SetFrameLevel(highestLevel - 1)
        overlay:Show()
    else
        overlay:Hide()
    end
end

--[[--------------------------------------------------------------------
    LoolibDialogMixin
----------------------------------------------------------------------]]

LoolibDialogMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

local DIALOG_EVENTS = {
    "OnAccept",
    "OnCancel",
    "OnShow",
    "OnHide",
}

--- Initialize the dialog
function LoolibDialogMixin:OnLoad()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(DIALOG_EVENTS)

    self.modal = false
    self.escapeClose = true
    self.buttons = {}
    self.buttonPool = nil
    self.editBoxes = {}
    self.checkBoxes = {}
    self.duration = nil
    self.durationTimer = 0
    self.on_show = nil
    self.on_hide = nil
    self.on_update = nil

    -- Get references
    self.Title = self.Title or self:GetName() and _G[self:GetName() .. "Title"]
    self.Message = self.Message or self:GetName() and _G[self:GetName() .. "Message"]
    self.CloseButton = self.CloseButton or self:GetName() and _G[self:GetName() .. "CloseButton"]
    self.ButtonContainer = self.ButtonContainer
    self.Icon = self.Icon

    -- Set up close button
    if self.CloseButton then
        self.CloseButton:SetScript("OnClick", function()
            self:Cancel()
        end)
    end

    -- Register escape handler
    self:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" and self.escapeClose then
            self:Cancel()
        end
    end)

    -- Set up OnUpdate for duration timer and callbacks
    self:SetScript("OnUpdate", function(frame, elapsed)
        -- Duration timer
        if self.duration then
            self.durationTimer = self.durationTimer + elapsed
            if self.durationTimer >= self.duration then
                self:Hide()
                return
            end
        end

        -- Custom update callback
        if self.on_update then
            self.on_update(self, elapsed)
        end
    end)

    -- Create button pool
    self.buttonPool = CreateLoolibFramePool("Button", self.ButtonContainer or self, "UIPanelButtonTemplate")

    self:Hide()
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

--- Set the dialog title
-- @param title string
function LoolibDialogMixin:SetTitle(title)
    if self.Title then
        self.Title:SetText(title)
    end
end

--- Set the dialog message
-- @param message string
function LoolibDialogMixin:SetMessage(message)
    if self.Message then
        self.Message:SetText(message)
    end
end

--- Set whether the dialog is modal
-- @param modal boolean
function LoolibDialogMixin:SetModal(modal)
    self.modal = modal
end

--- Set whether escape closes the dialog
-- @param escapeClose boolean
function LoolibDialogMixin:SetEscapeClose(escapeClose)
    self.escapeClose = escapeClose
end

--- Set the dialog buttons
-- @param buttons table - Array of { text, onClick, danger }
function LoolibDialogMixin:SetButtons(buttons)
    self.buttons = buttons or {}
    self:LayoutButtons()
end

--- Set the dialog icon
-- @param iconPath string - Texture path for icon
function LoolibDialogMixin:SetIcon(iconPath)
    if self.Icon then
        self.Icon:SetTexture(iconPath)
        self.Icon:Show()
    end
end

--- Set auto-dismiss duration
-- @param duration number - Time in seconds before auto-close
function LoolibDialogMixin:SetDuration(duration)
    self.duration = duration
    self.durationTimer = 0
end

--- Set lifecycle callbacks
-- @param callbacks table - { on_show, on_hide, on_update }
function LoolibDialogMixin:SetCallbacks(callbacks)
    callbacks = callbacks or {}
    self.on_show = callbacks.on_show
    self.on_hide = callbacks.on_hide
    self.on_update = callbacks.on_update
end

--- Set multiple editboxes
-- @param editBoxes table - Array of { label, defaultValue, multiline }
function LoolibDialogMixin:SetEditBoxes(editBoxes)
    -- Clear existing editboxes
    for _, editBox in ipairs(self.editBoxes) do
        if editBox.frame then
            editBox.frame:Hide()
            editBox.frame:SetParent(nil)
        end
    end
    wipe(self.editBoxes)

    -- Create new editboxes
    local yOffset = -60  -- Start below title/message
    for i, editBoxInfo in ipairs(editBoxes or {}) do
        local container = CreateFrame("Frame", nil, self)
        container:SetSize(self:GetWidth() - 40, 40)
        container:SetPoint("TOP", self, "TOP", 0, yOffset)

        -- Label
        local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        label:SetText(editBoxInfo.label or ("Input " .. i))

        -- EditBox
        local editBox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
        editBox:SetSize(container:GetWidth(), 20)
        editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
        editBox:SetAutoFocus(false)
        editBox:SetText(editBoxInfo.defaultValue or "")

        if editBoxInfo.multiline then
            editBox:SetMultiLine(true)
            editBox:SetMaxLetters(0)
        end

        container.editBox = editBox
        container.label = label

        self.editBoxes[i] = {
            frame = container,
            editBox = editBox,
            label = label,
        }

        yOffset = yOffset - 50
    end
end

--- Get editbox values
-- @return table - Array of editbox text values
function LoolibDialogMixin:GetEditBoxValues()
    local values = {}
    for i, editBoxInfo in ipairs(self.editBoxes) do
        values[i] = editBoxInfo.editBox:GetText()
    end
    return values
end

--- Set multiple checkboxes
-- @param checkBoxes table - Array of { label, checked, onClick }
function LoolibDialogMixin:SetCheckBoxes(checkBoxes)
    -- Clear existing checkboxes
    for _, checkBox in ipairs(self.checkBoxes) do
        if checkBox.frame then
            checkBox.frame:Hide()
            checkBox.frame:SetParent(nil)
        end
    end
    wipe(self.checkBoxes)

    -- Create new checkboxes
    local yOffset = -60  -- Start below title/message
    -- Adjust if editboxes exist
    if #self.editBoxes > 0 then
        yOffset = -60 - (#self.editBoxes * 50)
    end

    for i, checkBoxInfo in ipairs(checkBoxes or {}) do
        local checkButton = CreateFrame("CheckButton", nil, self, "UICheckButtonTemplate")
        checkButton:SetSize(24, 24)
        checkButton:SetPoint("TOPLEFT", self, "TOPLEFT", 20, yOffset)
        checkButton:SetChecked(checkBoxInfo.checked or false)

        -- Label
        local label = checkButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", checkButton, "RIGHT", 4, 0)
        label:SetText(checkBoxInfo.label or ("Option " .. i))

        -- Click handler
        if checkBoxInfo.onClick then
            checkButton:SetScript("OnClick", function(cb)
                checkBoxInfo.onClick(cb:GetChecked())
            end)
        end

        self.checkBoxes[i] = {
            frame = checkButton,
            label = label,
        }

        yOffset = yOffset - 30
    end
end

--- Get checkbox states
-- @return table - Array of boolean checkbox states
function LoolibDialogMixin:GetCheckBoxStates()
    local states = {}
    for i, checkBoxInfo in ipairs(self.checkBoxes) do
        states[i] = checkBoxInfo.frame:GetChecked()
    end
    return states
end

--[[--------------------------------------------------------------------
    Button Layout
----------------------------------------------------------------------]]

function LoolibDialogMixin:LayoutButtons()
    self.buttonPool:ReleaseAll()

    local numButtons = #self.buttons
    if numButtons == 0 then
        return
    end

    local container = self.ButtonContainer or self
    local containerWidth = container:GetWidth()
    local buttonWidth = math.min(100, (containerWidth - (numButtons - 1) * 8) / numButtons)
    local totalWidth = numButtons * buttonWidth + (numButtons - 1) * 8
    local startX = (containerWidth - totalWidth) / 2

    for i, buttonInfo in ipairs(self.buttons) do
        local button = self.buttonPool:Acquire()
        button:SetText(buttonInfo.text or "Button")
        button:SetSize(buttonWidth, 22)

        -- Position
        button:ClearAllPoints()
        button:SetPoint("LEFT", container, "LEFT", startX + (i - 1) * (buttonWidth + 8), 0)

        -- Danger styling
        if buttonInfo.danger then
            button:GetFontString():SetTextColor(1, 0.3, 0.3)
        else
            button:GetFontString():SetTextColor(1, 0.82, 0)
        end

        -- Click handler
        button:SetScript("OnClick", function()
            if buttonInfo.onClick then
                buttonInfo.onClick(self)
            end
            if buttonInfo.closes ~= false then
                self:Hide()
            end
        end)

        button:Show()
    end
end

--[[--------------------------------------------------------------------
    Show/Hide
----------------------------------------------------------------------]]

--- Show the dialog
function LoolibDialogMixin:Show()
    -- Add to stack
    local found = false
    for _, d in ipairs(dialogStack) do
        if d == self then
            found = true
            break
        end
    end
    if not found then
        dialogStack[#dialogStack + 1] = self
    end

    -- Center on screen
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 50)

    -- Reset duration timer
    self.durationTimer = 0

    -- Show
    getmetatable(self).__index.Show(self)

    -- Update modal overlay
    if self.modal then
        UpdateModalOverlay()
    end

    -- Focus
    self:EnableKeyboard(true)
    self:SetPropagateKeyboardInput(false)

    -- Call lifecycle callback
    if self.on_show then
        self.on_show(self)
    end

    self:TriggerEvent("OnShow")
end

--- Hide the dialog
function LoolibDialogMixin:Hide()
    -- Remove from stack
    for i, d in ipairs(dialogStack) do
        if d == self then
            table.remove(dialogStack, i)
            break
        end
    end

    getmetatable(self).__index.Hide(self)

    -- Update modal overlay
    UpdateModalOverlay()

    -- Call lifecycle callback
    if self.on_hide then
        self.on_hide(self)
    end

    self:TriggerEvent("OnHide")
end

--- Close with accept action
function LoolibDialogMixin:Accept()
    self:TriggerEvent("OnAccept")
    self:Hide()
end

--- Close with cancel action
function LoolibDialogMixin:Cancel()
    self:TriggerEvent("OnCancel")
    self:Hide()
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a dialog
-- @param parent Frame - Parent frame (optional, defaults to UIParent)
-- @return Frame - The dialog frame
function CreateLoolibDialog(parent)
    local dialog = CreateFrame("Frame", nil, parent or UIParent, "LoolibDialogTemplate")
    LoolibMixin(dialog, LoolibDialogMixin)
    dialog:OnLoad()
    return dialog
end

--[[--------------------------------------------------------------------
    Input Dialog Mixin
----------------------------------------------------------------------]]

LoolibInputDialogMixin = LoolibCreateFromMixins(LoolibDialogMixin)

function LoolibInputDialogMixin:OnLoad()
    LoolibDialogMixin.OnLoad(self)

    self.EditBox = self.EditBox

    -- Add accept/cancel buttons by default
    self:SetButtons({
        { text = "Accept", onClick = function() self:Accept() end },
        { text = "Cancel", onClick = function() self:Cancel() end },
    })

    -- Enter to accept
    if self.EditBox then
        self.EditBox:SetScript("OnEnterPressed", function()
            self:Accept()
        end)
    end
end

--- Get the input value
-- @return string
function LoolibInputDialogMixin:GetInputValue()
    return self.EditBox and self.EditBox:GetText() or ""
end

--- Set the input value
-- @param value string
function LoolibInputDialogMixin:SetInputValue(value)
    if self.EditBox then
        self.EditBox:SetText(value or "")
    end
end

--- Set the prompt text
-- @param prompt string
function LoolibInputDialogMixin:SetPrompt(prompt)
    self:SetMessage(prompt)
end

--- Show and focus the edit box
function LoolibInputDialogMixin:Show()
    LoolibDialogMixin.Show(self)
    if self.EditBox then
        self.EditBox:SetFocus()
        self.EditBox:HighlightText()
    end
end

--- Create an input dialog
function CreateLoolibInputDialog(parent)
    local dialog = CreateFrame("Frame", nil, parent or UIParent, "LoolibInputDialogTemplate")
    LoolibMixin(dialog, LoolibInputDialogMixin)
    dialog:OnLoad()
    return dialog
end

--[[--------------------------------------------------------------------
    Builder Pattern
----------------------------------------------------------------------]]

LoolibDialogBuilderMixin = {}

function LoolibDialogBuilderMixin:Init()
    self.config = {
        title = "",
        message = "",
        modal = true,
        escapeClose = true,
        buttons = {},
        onAccept = nil,
        onCancel = nil,
    }
end

function LoolibDialogBuilderMixin:SetTitle(title)
    self.config.title = title
    return self
end

function LoolibDialogBuilderMixin:SetMessage(message)
    self.config.message = message
    return self
end

function LoolibDialogBuilderMixin:SetModal(modal)
    self.config.modal = modal
    return self
end

function LoolibDialogBuilderMixin:SetEscapeClose(escapeClose)
    self.config.escapeClose = escapeClose
    return self
end

function LoolibDialogBuilderMixin:SetButtons(buttons)
    self.config.buttons = buttons
    return self
end

function LoolibDialogBuilderMixin:OnAccept(callback)
    self.config.onAccept = callback
    return self
end

function LoolibDialogBuilderMixin:OnCancel(callback)
    self.config.onCancel = callback
    return self
end

function LoolibDialogBuilderMixin:Show()
    local dialog = CreateLoolibDialog()

    dialog:SetTitle(self.config.title)
    dialog:SetMessage(self.config.message)
    dialog:SetModal(self.config.modal)
    dialog:SetEscapeClose(self.config.escapeClose)
    dialog:SetButtons(self.config.buttons)

    if self.config.onAccept then
        dialog:RegisterCallback("OnAccept", self.config.onAccept)
    end
    if self.config.onCancel then
        dialog:RegisterCallback("OnCancel", self.config.onCancel)
    end

    dialog:Show()
    return dialog
end

function LoolibDialog()
    local builder = LoolibCreateFromMixins(LoolibDialogBuilderMixin)
    builder:Init()
    return builder
end

--[[--------------------------------------------------------------------
    Input Dialog Builder
----------------------------------------------------------------------]]

LoolibInputDialogBuilderMixin = LoolibCreateFromMixins(LoolibDialogBuilderMixin)

function LoolibInputDialogBuilderMixin:Init()
    LoolibDialogBuilderMixin.Init(self)
    self.config.prompt = ""
    self.config.defaultValue = ""
end

function LoolibInputDialogBuilderMixin:SetPrompt(prompt)
    self.config.prompt = prompt
    return self
end

function LoolibInputDialogBuilderMixin:SetDefaultValue(value)
    self.config.defaultValue = value
    return self
end

function LoolibInputDialogBuilderMixin:Show()
    local dialog = CreateLoolibInputDialog()

    dialog:SetTitle(self.config.title)
    dialog:SetPrompt(self.config.prompt)
    dialog:SetInputValue(self.config.defaultValue)
    dialog:SetModal(self.config.modal)
    dialog:SetEscapeClose(self.config.escapeClose)

    if self.config.onAccept then
        dialog:RegisterCallback("OnAccept", function()
            self.config.onAccept(dialog:GetInputValue())
        end)
    end
    if self.config.onCancel then
        dialog:RegisterCallback("OnCancel", self.config.onCancel)
    end

    dialog:Show()
    return dialog
end

function LoolibInputDialog()
    local builder = LoolibCreateFromMixins(LoolibInputDialogBuilderMixin)
    builder:Init()
    return builder
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local DialogModule = {
    Mixin = LoolibDialogMixin,
    InputMixin = LoolibInputDialogMixin,
    BuilderMixin = LoolibDialogBuilderMixin,
    InputBuilderMixin = LoolibInputDialogBuilderMixin,
    Create = CreateLoolibDialog,
    CreateInput = CreateLoolibInputDialog,
    Builder = LoolibDialog,
    InputBuilder = LoolibInputDialog,
}

local UI = Loolib:GetOrCreateModule("UI")
UI.Dialog = DialogModule
UI.CreateDialog = CreateLoolibDialog
UI.CreateInputDialog = CreateLoolibInputDialog

Loolib:RegisterModule("Dialog", DialogModule)
