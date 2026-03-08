--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    NoteFrame - Main note display frame

    The primary display frame for notes. Handles text rendering, drag/positioning,
    encounter events, and timer updates.

    Features:
    - Full rendering pipeline (Parser → Markup → Renderer)
    - Timer integration with countdown updates
    - Glow effects for timer alerts
    - Draggable with position persistence
    - Combat visibility rules
    - Lock/unlock for interaction control
    - Event handling for encounters, combat, roster changes
    - Scrollable for long notes

    Reference:
    - MRT/Note.lua: Note window creation and positioning
    - WindowUtil: Position persistence
    - DraggableMixin: Drag support
    - EventFrame: Event handling patterns
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

---@class LoolibNoteFrameMixin
LoolibNoteFrameMixin = {}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function LoolibNoteFrameMixin:OnLoad()
    -- Raw note text
    self._rawText = ""
    self._selfText = ""

    -- Display state
    self._isLocked = false
    self._isVisible = true
    self._showInCombat = true
    self._showOutOfCombat = true

    -- Appearance
    self._fontSize = 12
    self._fontFace = "Fonts\\FRIZQT__.TTF"
    self._textColor = {r = 1, g = 1, b = 1, a = 1}
    self._backgroundColor = {r = 0, g = 0, b = 0, a = 0.5}

    -- Components (lazy-loaded when modules are available)
    self._parser = nil
    self._markup = nil
    self._renderer = nil
    self._timer = nil

    -- Create UI elements
    self:_CreateUI()

    -- Set up callbacks (deferred until components exist)
    self._callbacksSetup = false
end

function LoolibNoteFrameMixin:_CreateUI()
    -- Background
    self.background = self:CreateTexture(nil, "BACKGROUND")
    self.background:SetAllPoints()
    self.background:SetColorTexture(
        self._backgroundColor.r,
        self._backgroundColor.g,
        self._backgroundColor.b,
        self._backgroundColor.a
    )

    -- Border (optional, when not locked)
    self.border = CreateFrame("Frame", nil, self, "BackdropTemplate")
    self.border:SetAllPoints()
    self.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    self.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

    -- Scroll frame for long notes
    self.scrollFrame = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
    self.scrollFrame:SetPoint("TOPLEFT", 4, -4)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", -22, 4)

    -- Content frame
    self.content = CreateFrame("Frame", nil, self.scrollFrame)
    self.scrollFrame:SetScrollChild(self.content)

    -- Text display
    self.text = self.content:CreateFontString(nil, "OVERLAY")
    self.text:SetPoint("TOPLEFT", 0, 0)
    self.text:SetJustifyH("LEFT")
    self.text:SetJustifyV("TOP")
    self.text:SetWordWrap(true)
    self.text:SetFont(self._fontFace, self._fontSize, "OUTLINE")
    self.text:SetTextColor(
        self._textColor.r,
        self._textColor.g,
        self._textColor.b,
        self._textColor.a
    )

    -- Glow overlay for timer highlights
    self.glow = self:CreateTexture(nil, "OVERLAY")
    self.glow:SetAllPoints()
    self.glow:SetColorTexture(1, 0.8, 0.2, 0.15)
    self.glow:SetBlendMode("ADD")
    self.glow:Hide()

    -- Set initial size
    self:SetSize(300, 200)
    self.content:SetSize(274, 200)
end

function LoolibNoteFrameMixin:_EnsureComponents()
    -- Lazy-load components when they become available
    if not self._parser then
        local parserModule = Loolib:GetModule("NoteParser")
        if parserModule and parserModule.Get then
            self._parser = parserModule.Get()
        end
    end

    if not self._markup then
        local markupModule = Loolib:GetModule("NoteMarkup")
        if markupModule and markupModule.Get then
            self._markup = markupModule.Get()
        end
    end

    if not self._renderer then
        local rendererModule = Loolib:GetModule("NoteRenderer")
        if rendererModule and rendererModule.Get then
            self._renderer = rendererModule.Get()
        end
    end

    if not self._timer then
        local timerModule = Loolib:GetModule("NoteTimer")
        if timerModule and timerModule.Get then
            self._timer = timerModule.Get()
        end
    end

    -- Set up callbacks once all components are loaded
    if not self._callbacksSetup and self._timer and self._renderer then
        self:_SetupCallbacks()
        self._callbacksSetup = true
    end

    return self._parser ~= nil and self._markup ~= nil and
           self._renderer ~= nil and self._timer ~= nil
end

function LoolibNoteFrameMixin:_SetupCallbacks()
    -- Timer tick callback to refresh display
    if self._timer.RegisterCallback then
        self._timer:RegisterCallback("OnTimerTick", function()
            if self:IsShown() and self._timer.IsInEncounter then
                if self._timer:IsInEncounter() then
                    self:Update()
                end
            end
        end, self)
    end

    -- Glow callback
    if self._timer.SetGlowCallback then
        self._timer:SetGlowCallback(function(timerId, timer)
            self:ShowGlow(1.5)  -- 1.5 second glow
        end)
    end
end

-- ============================================================
-- TEXT MANAGEMENT
-- ============================================================

---Set the note text
---@param text string Raw markup text
function LoolibNoteFrameMixin:SetText(text)
    self._rawText = text or ""
    self:Update()
end

---Get the raw note text
---@return string
function LoolibNoteFrameMixin:GetText()
    return self._rawText
end

---Set personal note text (for {self} placeholder)
---@param text string
function LoolibNoteFrameMixin:SetSelfText(text)
    self._selfText = text or ""

    if self._renderer and self._renderer.SetSelfText then
        self._renderer:SetSelfText(self._selfText)
    end

    self:Update()
end

---Get personal note text
---@return string
function LoolibNoteFrameMixin:GetSelfText()
    return self._selfText
end

-- ============================================================
-- RENDERING
-- ============================================================

---Update the display
function LoolibNoteFrameMixin:Update()
    if not self._rawText or #self._rawText == 0 then
        self.text:SetText("")
        return
    end

    -- Ensure components are loaded
    if not self:_EnsureComponents() then
        -- Components not ready yet, show placeholder
        self.text:SetText("|cffff8800[Note Loading...]|r")
        return
    end

    -- Update context
    if self._markup.UpdatePlayerContext then
        self._markup:UpdatePlayerContext()
    end

    if self._renderer.UpdateRaidRoster then
        self._renderer:UpdateRaidRoster()
    end

    -- Parse
    local ast = self._parser:Parse(self._rawText)
    if not ast then
        self.text:SetText("|cffff0000[Parse Error]|r")
        return
    end

    -- Process conditionals
    local processed = self._markup:Process(ast)

    -- Render to formatted string
    local rendered = self._renderer:Render(processed)

    -- Update text
    self.text:SetText(rendered)

    -- Update content size
    local textHeight = self.text:GetStringHeight()
    self.text:SetWidth(self.content:GetWidth())
    self.content:SetHeight(math.max(textHeight, self:GetHeight() - 8))
end

-- ============================================================
-- APPEARANCE
-- ============================================================

---Set font size
---@param size number
function LoolibNoteFrameMixin:SetFontSize(size)
    self._fontSize = size
    self.text:SetFont(self._fontFace, size, "OUTLINE")
    self:Update()
end

---Get font size
---@return number
function LoolibNoteFrameMixin:GetFontSize()
    return self._fontSize
end

---Set font face
---@param fontPath string
function LoolibNoteFrameMixin:SetFontFace(fontPath)
    self._fontFace = fontPath
    self.text:SetFont(fontPath, self._fontSize, "OUTLINE")
    self:Update()
end

---Get font face
---@return string
function LoolibNoteFrameMixin:GetFontFace()
    return self._fontFace
end

---Set text color
---@param r number
---@param g number
---@param b number
---@param a number?
function LoolibNoteFrameMixin:SetTextColor(r, g, b, a)
    self._textColor = {r = r, g = g, b = b, a = a or 1}
    self.text:SetTextColor(r, g, b, a or 1)
end

---Get text color
---@return number r, number g, number b, number a
function LoolibNoteFrameMixin:GetTextColor()
    return self._textColor.r, self._textColor.g, self._textColor.b, self._textColor.a
end

---Set background color
---@param r number
---@param g number
---@param b number
---@param a number?
function LoolibNoteFrameMixin:SetBackgroundColor(r, g, b, a)
    self._backgroundColor = {r = r, g = g, b = b, a = a or 0.5}
    self.background:SetColorTexture(r, g, b, a or 0.5)
end

---Get background color
---@return number r, number g, number b, number a
function LoolibNoteFrameMixin:GetBackgroundColor()
    return self._backgroundColor.r, self._backgroundColor.g,
           self._backgroundColor.b, self._backgroundColor.a
end

---Set background alpha only
---@param alpha number
function LoolibNoteFrameMixin:SetBackgroundAlpha(alpha)
    self._backgroundColor.a = alpha
    self.background:SetColorTexture(
        self._backgroundColor.r,
        self._backgroundColor.g,
        self._backgroundColor.b,
        alpha
    )
end

---Get background alpha
---@return number
function LoolibNoteFrameMixin:GetBackgroundAlpha()
    return self._backgroundColor.a
end

-- ============================================================
-- LOCK/UNLOCK
-- ============================================================

---Lock the note (disable drag, hide border)
---@param locked boolean
function LoolibNoteFrameMixin:SetLocked(locked)
    self._isLocked = locked

    if locked then
        self:EnableMouse(false)
        self.border:Hide()

        -- Disable drag if available
        if self.SetDragEnabled then
            self:SetDragEnabled(false)
        end
    else
        self:EnableMouse(true)
        self.border:Show()

        -- Enable drag if available
        if self.SetDragEnabled then
            self:SetDragEnabled(true)
        end
    end
end

---Check if locked
---@return boolean
function LoolibNoteFrameMixin:IsLocked()
    return self._isLocked
end

-- ============================================================
-- VISIBILITY
-- ============================================================

---Set combat visibility rules
---@param showInCombat boolean
---@param showOutOfCombat boolean
function LoolibNoteFrameMixin:SetCombatVisibility(showInCombat, showOutOfCombat)
    self._showInCombat = showInCombat
    self._showOutOfCombat = showOutOfCombat
    self:UpdateVisibility()
end

---Get combat visibility settings
---@return boolean showInCombat, boolean showOutOfCombat
function LoolibNoteFrameMixin:GetCombatVisibility()
    return self._showInCombat, self._showOutOfCombat
end

---Update visibility based on combat state
function LoolibNoteFrameMixin:UpdateVisibility()
    if not self._isVisible then
        self:Hide()
        return
    end

    local inCombat = InCombatLockdown()

    if inCombat and not self._showInCombat then
        self:Hide()
    elseif not inCombat and not self._showOutOfCombat then
        self:Hide()
    else
        self:Show()
    end
end

---Show/hide the note
---@param visible boolean
function LoolibNoteFrameMixin:SetVisible(visible)
    self._isVisible = visible
    self:UpdateVisibility()
end

---Check if visible (not locked)
---@return boolean
function LoolibNoteFrameMixin:IsVisible()
    return self._isVisible
end

-- ============================================================
-- GLOW EFFECT
-- ============================================================

---Show glow effect
---@param duration number Duration in seconds
function LoolibNoteFrameMixin:ShowGlow(duration)
    self.glow:Show()

    -- Fade out animation
    if not self.glowAnim then
        self.glowAnim = self.glow:CreateAnimationGroup()
        local fade = self.glowAnim:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetSmoothing("OUT")
        self.glowAnim:SetScript("OnFinished", function()
            self.glow:Hide()
        end)
    end

    -- Find the animation and set duration
    for _, anim in pairs({self.glowAnim:GetAnimations()}) do
        if anim.SetDuration then
            anim:SetDuration(duration)
        end
    end

    self.glowAnim:Stop()
    self.glow:SetAlpha(1)
    self.glowAnim:Play()
end

-- ============================================================
-- ENCOUNTER INTEGRATION
-- ============================================================

---Called when encounter starts
---@param encounterId number
---@param encounterName string
function LoolibNoteFrameMixin:OnEncounterStart(encounterId, encounterName)
    if self._timer and self._timer.StartEncounter then
        self._timer:StartEncounter()
    end
    self:Update()
end

---Called when encounter ends
function LoolibNoteFrameMixin:OnEncounterEnd()
    if self._timer and self._timer.EndEncounter then
        self._timer:EndEncounter()
    end
    self:Update()
end

---Called when phase changes
---@param phase number
function LoolibNoteFrameMixin:OnPhaseChange(phase)
    if self._timer and self._timer.SetPhase then
        self._timer:SetPhase(phase)
    end
    self:Update()
end

-- ============================================================
-- EVENT HANDLING
-- ============================================================

function LoolibNoteFrameMixin:OnEvent(event, ...)
    if event == "ENCOUNTER_START" then
        local encounterId, encounterName = ...
        self:OnEncounterStart(encounterId, encounterName)

    elseif event == "ENCOUNTER_END" then
        self:OnEncounterEnd()

    elseif event == "PLAYER_REGEN_DISABLED" then
        self:UpdateVisibility()

    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UpdateVisibility()

    elseif event == "GROUP_ROSTER_UPDATE" then
        if self._renderer and self._renderer.UpdateRaidRoster then
            self._renderer:UpdateRaidRoster()
        end
        self:Update()
    end
end

-- ============================================================
-- SIZE HELPERS
-- ============================================================

---Set content width (adjusts frame width for scrollbar)
---@param width number
function LoolibNoteFrameMixin:SetContentWidth(width)
    self:SetWidth(width + 30)  -- Account for scrollbar
    self.content:SetWidth(width)
    self.text:SetWidth(width)
    self:Update()
end

---Get content width
---@return number
function LoolibNoteFrameMixin:GetContentWidth()
    return self.content:GetWidth()
end

-- ============================================================
-- CLEANUP
-- ============================================================

function LoolibNoteFrameMixin:OnHide()
    -- Stop any active animations
    if self.glowAnim and self.glowAnim:IsPlaying() then
        self.glowAnim:Stop()
    end

    if self.glow then
        self.glow:Hide()
    end
end

-- ============================================================
-- FACTORY FUNCTION
-- ============================================================

---Create a note frame
---@param parent Frame? Parent frame
---@param name string? Global name
---@return Frame
function LoolibCreateNoteFrame(parent, name)
    local frame = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")

    -- Apply mixins
    LoolibMixin(frame, LoolibNoteFrameMixin)

    -- Apply draggable support if available
    local DraggableMixin = Loolib:GetModule("DraggableMixin")
    if DraggableMixin then
        LoolibMixin(frame, DraggableMixin)
        frame:InitDraggable()
        frame:SetDragEnabled(true)
        frame:SetClampToScreen(true)
    end

    -- Apply event frame support if available
    local EventFrameMixin = Loolib:GetModule("EventFrame")
    if EventFrameMixin and EventFrameMixin.Mixin then
        LoolibMixin(frame, EventFrameMixin.Mixin)
        frame:InitEventFrame()
    end

    -- Initialize
    frame:OnLoad()

    -- Register events
    frame:RegisterEvent("ENCOUNTER_START")
    frame:RegisterEvent("ENCOUNTER_END")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:SetScript("OnEvent", frame.OnEvent)
    frame:SetScript("OnHide", frame.OnHide)

    return frame
end

-- ============================================================
-- REGISTER WITH LOOLIB
-- ============================================================

Loolib:RegisterModule("NoteFrame", {
    Mixin = LoolibNoteFrameMixin,
    Create = LoolibCreateNoteFrame,
})
