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

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UIParent = UIParent
local wipe = wipe
local ipairs = ipairs
local tinsert = table.insert
local tremove = table.remove
local mathMax = math.max
local mathMin = math.min

local CreateFromMixins = assert(Loolib.CreateFromMixins, "Loolib.CreateFromMixins is required for Dialog")
local Mixin = assert(Loolib.Mixin, "Loolib.Mixin is required for Dialog")
local CallbackRegistryMixin = assert(Loolib.CallbackRegistryMixin, "Loolib.CallbackRegistryMixin is required for Dialog")

Loolib.UI = Loolib.UI or {}

local function CreateButtonPool(parent)
    local pool = {
        parent = parent,
        buttons = {},
    }

    function pool:Acquire()
        for _, button in ipairs(self.buttons) do
            if not button.__loolibActive then
                button.__loolibActive = true
                return button
            end
        end

        local button = CreateFrame("Button", nil, self.parent, "UIPanelButtonTemplate")
        button.__loolibActive = true
        tinsert(self.buttons, button)
        return button
    end

    function pool:ReleaseAll()
        for _, button in ipairs(self.buttons) do
            button.__loolibActive = nil
            button:SetScript("OnClick", nil)
            button:Hide()
        end
    end

    return pool
end

--[[--------------------------------------------------------------------
    Local Template Initializers

    These mirror the dialog pieces from Templates.lua so this module
    does not depend on the legacy template singleton.
----------------------------------------------------------------------]]

local function InitDialogFrame(frame)
    frame:SetSize(320, 160)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetJustifyH("CENTER")
    frame.Title:SetPoint("TOP", 0, -15)

    frame.Message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Message:SetJustifyH("CENTER")
    frame.Message:SetJustifyV("TOP")
    frame.Message:SetSize(280, 0)
    frame.Message:SetPoint("TOP", frame.Title, "BOTTOM", 0, -10)

    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", -3, -3)

    frame.ButtonContainer = CreateFrame("Frame", nil, frame)
    frame.ButtonContainer:SetSize(1, 30)
    frame.ButtonContainer:SetPoint("BOTTOMLEFT", 20, 15)
    frame.ButtonContainer:SetPoint("BOTTOMRIGHT", -20, 15)

    frame:SetBackdrop(BACKDROP_DIALOG_32_32)
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

local function InitInputDialogFrame(frame)
    InitDialogFrame(frame)
    frame:SetSize(320, 140)

    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetSize(260, 24)
    editBox:SetAutoFocus(false)
    editBox:SetPoint("TOP", frame.Message, "BOTTOM", 0, -10)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    frame.EditBox = editBox
end

local function InitModalOverlay(frame)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.5)
end

--[[--------------------------------------------------------------------
    Dialog Stack
----------------------------------------------------------------------]]

local dialogStack = {}
local modalOverlay

local function GetModalOverlay()
    if not modalOverlay then
        modalOverlay = CreateFrame("Frame", nil, UIParent)
        InitModalOverlay(modalOverlay)
        modalOverlay:SetAllPoints(UIParent)
        modalOverlay:Hide()
    end

    return modalOverlay
end

local function UpdateModalOverlay()
    local overlay = GetModalOverlay()
    local highestLevel = 0
    local hasModal = false

    for _, dialog in ipairs(dialogStack) do
        if dialog.modal and dialog:IsShown() then
            hasModal = true
            highestLevel = mathMax(highestLevel, dialog:GetFrameLevel())
        end
    end

    if hasModal then
        overlay:SetFrameStrata("FULLSCREEN_DIALOG")
        overlay:SetFrameLevel(highestLevel - 1)
        overlay:Show()
    else
        overlay:SetFrameStrata("DIALOG")
        overlay:Hide()
    end
end

--[[--------------------------------------------------------------------
    Dialog Mixin
----------------------------------------------------------------------]]

local DialogMixin = CreateFromMixins(CallbackRegistryMixin)

local DIALOG_EVENTS = {
    "OnAccept",
    "OnCancel",
    "OnShow",
    "OnHide",
}

function DialogMixin:OnLoad()
    CallbackRegistryMixin.OnLoad(self)
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

    if self.CloseButton then
        self.CloseButton:SetScript("OnClick", function()
            self:Cancel()
        end)
    end

    self:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" and self.escapeClose then
            self:Cancel()
        end
    end)

    self:SetScript("OnUpdate", function(_, elapsed)
        if self.duration then
            self.durationTimer = self.durationTimer + elapsed
            if self.durationTimer >= self.duration then
                self:Hide()
                return
            end
        end

        if self.on_update then
            self.on_update(self, elapsed)
        end
    end)

    self.buttonPool = CreateButtonPool(self.ButtonContainer or self)

    self:Hide()
end

--[[--------------------------------------------------------------------
    Configuration
----------------------------------------------------------------------]]

function DialogMixin:SetTitle(title)
    if self.Title then
        self.Title:SetText(title)
    end
end

function DialogMixin:SetMessage(message)
    if self.Message then
        self.Message:SetText(message)
    end
end

function DialogMixin:SetModal(modal)
    self.modal = modal
end

function DialogMixin:SetEscapeClose(escapeClose)
    self.escapeClose = escapeClose
end

function DialogMixin:SetButtons(buttons)
    self.buttons = buttons or {}
    self:LayoutButtons()
end

function DialogMixin:SetIcon(iconPath)
    if self.Icon then
        self.Icon:SetTexture(iconPath)
        self.Icon:Show()
    end
end

function DialogMixin:SetDuration(duration)
    self.duration = duration
    self.durationTimer = 0
end

function DialogMixin:SetCallbacks(callbacks)
    callbacks = callbacks or {}
    self.on_show = callbacks.on_show
    self.on_hide = callbacks.on_hide
    self.on_update = callbacks.on_update
end

function DialogMixin:SetEditBoxes(editBoxes)
    for _, editBox in ipairs(self.editBoxes) do
        if editBox.frame then
            editBox.frame:Hide()
            editBox.frame:SetParent(nil)
        end
    end
    wipe(self.editBoxes)

    local yOffset = -60
    for index, editBoxInfo in ipairs(editBoxes or {}) do
        local container = CreateFrame("Frame", nil, self)
        container:SetSize(self:GetWidth() - 40, 40)
        container:SetPoint("TOP", self, "TOP", 0, yOffset)

        local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        label:SetText(editBoxInfo.label or ("Input " .. index))

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

        self.editBoxes[index] = {
            frame = container,
            editBox = editBox,
            label = label,
        }

        yOffset = yOffset - 50
    end
end

function DialogMixin:GetEditBoxValues()
    local values = {}
    for index, editBoxInfo in ipairs(self.editBoxes) do
        values[index] = editBoxInfo.editBox:GetText()
    end
    return values
end

function DialogMixin:SetCheckBoxes(checkBoxes)
    for _, checkBox in ipairs(self.checkBoxes) do
        if checkBox.frame then
            checkBox.frame:Hide()
            checkBox.frame:SetParent(nil)
        end
    end
    wipe(self.checkBoxes)

    local yOffset = -60
    if #self.editBoxes > 0 then
        yOffset = -60 - (#self.editBoxes * 50)
    end

    for index, checkBoxInfo in ipairs(checkBoxes or {}) do
        local checkButton = CreateFrame("CheckButton", nil, self, "UICheckButtonTemplate")
        checkButton:SetSize(24, 24)
        checkButton:SetPoint("TOPLEFT", self, "TOPLEFT", 20, yOffset)
        checkButton:SetChecked(checkBoxInfo.checked or false)

        local label = checkButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", checkButton, "RIGHT", 4, 0)
        label:SetText(checkBoxInfo.label or ("Option " .. index))

        if checkBoxInfo.onClick then
            checkButton:SetScript("OnClick", function(cb)
                checkBoxInfo.onClick(cb:GetChecked())
            end)
        end

        self.checkBoxes[index] = {
            frame = checkButton,
            label = label,
        }

        yOffset = yOffset - 30
    end
end

function DialogMixin:GetCheckBoxStates()
    local states = {}
    for index, checkBoxInfo in ipairs(self.checkBoxes) do
        states[index] = checkBoxInfo.frame:GetChecked()
    end
    return states
end

--[[--------------------------------------------------------------------
    Button Layout
----------------------------------------------------------------------]]

function DialogMixin:LayoutButtons()
    self.buttonPool:ReleaseAll()

    local numButtons = #self.buttons
    if numButtons == 0 then
        return
    end

    local container = self.ButtonContainer or self
    local containerWidth = container:GetWidth()
    local buttonWidth = mathMin(100, (containerWidth - (numButtons - 1) * 8) / numButtons)
    local totalWidth = numButtons * buttonWidth + (numButtons - 1) * 8
    local startX = (containerWidth - totalWidth) / 2

    for index, buttonInfo in ipairs(self.buttons) do
        local button = self.buttonPool:Acquire()
        button:SetText(buttonInfo.text or "Button")
        button:SetSize(buttonWidth, 22)

        button:ClearAllPoints()
        button:SetPoint("LEFT", container, "LEFT", startX + (index - 1) * (buttonWidth + 8), 0)

        if buttonInfo.danger then
            button:GetFontString():SetTextColor(1, 0.3, 0.3)
        else
            button:GetFontString():SetTextColor(1, 0.82, 0)
        end

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

function DialogMixin:Show()
    local found = false
    for _, dialog in ipairs(dialogStack) do
        if dialog == self then
            found = true
            break
        end
    end
    if not found then
        dialogStack[#dialogStack + 1] = self
    end

    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    self.durationTimer = 0

    getmetatable(self).__index.Show(self)
    self:Raise()

    if self.modal then
        self:SetFrameStrata("FULLSCREEN_DIALOG")
    end

    if #self.buttons > 0 then
        self:LayoutButtons()
    end

    if self.modal then
        UpdateModalOverlay()
    end

    self:EnableKeyboard(true)
    if not InCombatLockdown() then
        self:SetPropagateKeyboardInput(false)
    end

    if self.on_show then
        self.on_show(self)
    end

    self:TriggerEvent("OnShow")
end

function DialogMixin:Hide()
    for index, dialog in ipairs(dialogStack) do
        if dialog == self then
            tremove(dialogStack, index)
            break
        end
    end

    getmetatable(self).__index.Hide(self)
    UpdateModalOverlay()

    if self.on_hide then
        self.on_hide(self)
    end

    self:TriggerEvent("OnHide")
end

function DialogMixin:Accept()
    self:TriggerEvent("OnAccept")
    self:Hide()
end

function DialogMixin:Cancel()
    self:TriggerEvent("OnCancel")
    self:Hide()
end

--[[--------------------------------------------------------------------
    Factory Functions
----------------------------------------------------------------------]]

local function CreateDialog(parent)
    local dialog = CreateFrame("Frame", nil, parent or UIParent, "BackdropTemplate")
    InitDialogFrame(dialog)
    Mixin(dialog, DialogMixin)
    dialog:OnLoad()
    return dialog
end

--[[--------------------------------------------------------------------
    Input Dialog Mixin
----------------------------------------------------------------------]]

local InputDialogMixin = CreateFromMixins(DialogMixin)

function InputDialogMixin:OnLoad()
    DialogMixin.OnLoad(self)
    self.EditBox = self.EditBox

    self:SetButtons({
        { text = "Accept", onClick = function() self:Accept() end },
        { text = "Cancel", onClick = function() self:Cancel() end },
    })

    if self.EditBox then
        self.EditBox:SetScript("OnEnterPressed", function()
            self:Accept()
        end)
    end
end

function InputDialogMixin:GetInputValue()
    return self.EditBox and self.EditBox:GetText() or ""
end

function InputDialogMixin:SetInputValue(value)
    if self.EditBox then
        self.EditBox:SetText(value or "")
    end
end

function InputDialogMixin:SetPrompt(prompt)
    self:SetMessage(prompt)
end

function InputDialogMixin:Show()
    DialogMixin.Show(self)
    if self.EditBox then
        self.EditBox:SetFocus()
        self.EditBox:HighlightText()
    end
end

local function CreateInputDialog(parent)
    local dialog = CreateFrame("Frame", nil, parent or UIParent, "BackdropTemplate")
    InitInputDialogFrame(dialog)
    Mixin(dialog, InputDialogMixin)
    dialog:OnLoad()
    return dialog
end

--[[--------------------------------------------------------------------
    Builder Pattern
----------------------------------------------------------------------]]

local DialogBuilderMixin = {}

function DialogBuilderMixin:Init()
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

function DialogBuilderMixin:SetTitle(title)
    self.config.title = title
    return self
end

function DialogBuilderMixin:SetMessage(message)
    self.config.message = message
    return self
end

function DialogBuilderMixin:SetModal(modal)
    self.config.modal = modal
    return self
end

function DialogBuilderMixin:SetEscapeClose(escapeClose)
    self.config.escapeClose = escapeClose
    return self
end

function DialogBuilderMixin:SetButtons(buttons)
    self.config.buttons = buttons
    return self
end

function DialogBuilderMixin:OnAccept(callback)
    self.config.onAccept = callback
    return self
end

function DialogBuilderMixin:OnCancel(callback)
    self.config.onCancel = callback
    return self
end

function DialogBuilderMixin:Show()
    local dialog = CreateDialog()

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

local function CreateDialogBuilder()
    local builder = CreateFromMixins(DialogBuilderMixin)
    builder:Init()
    return builder
end

--[[--------------------------------------------------------------------
    Input Dialog Builder
----------------------------------------------------------------------]]

local InputDialogBuilderMixin = CreateFromMixins(DialogBuilderMixin)

function InputDialogBuilderMixin:Init()
    DialogBuilderMixin.Init(self)
    self.config.prompt = ""
    self.config.defaultValue = ""
end

function InputDialogBuilderMixin:SetPrompt(prompt)
    self.config.prompt = prompt
    return self
end

function InputDialogBuilderMixin:SetDefaultValue(value)
    self.config.defaultValue = value
    return self
end

function InputDialogBuilderMixin:Show()
    local dialog = CreateInputDialog()

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

local function CreateInputDialogBuilder()
    local builder = CreateFromMixins(InputDialogBuilderMixin)
    builder:Init()
    return builder
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local DialogModule = {
    Mixin = DialogMixin,
    InputMixin = InputDialogMixin,
    BuilderMixin = DialogBuilderMixin,
    InputBuilderMixin = InputDialogBuilderMixin,
    Create = CreateDialog,
    CreateInput = CreateInputDialog,
    Builder = CreateDialogBuilder,
    InputBuilder = CreateInputDialogBuilder,
}

Loolib.UI.Dialog = DialogModule

Loolib:RegisterModule("UI.Dialog", DialogModule)
