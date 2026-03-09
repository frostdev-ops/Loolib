--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    FrameUtil - Utilities for working with frames
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local Mixin = assert(Loolib.Mixin, "Loolib.Mixin is required for FrameUtil")
local ReflectScriptHandlers = assert(Loolib.ReflectScriptHandlers, "Loolib.ReflectScriptHandlers is required for FrameUtil")
local Backdrop = assert(Loolib.Backdrop or (Loolib.Theme and Loolib.Theme.Backdrop), "Loolib.Backdrop is required for FrameUtil")
local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
local FrameUtil = UI.FrameUtil or Loolib:GetModule("UI.FrameUtil") or {}

--[[--------------------------------------------------------------------
    Frame Creation
----------------------------------------------------------------------]]

--- Create a frame with mixins applied
-- @param frameType string - The frame type
-- @param name string - Optional global name
-- @param parent Frame - Parent frame
-- @param template string - Optional XML template
-- @param ... - Mixins to apply
-- @return Frame - The created frame
function FrameUtil.CreateFrameWithMixins(frameType, name, parent, template, ...)
    local frame = CreateFrame(frameType, name, parent, template)

    Mixin(frame, ...)
    ReflectScriptHandlers(frame)

    if frame.OnLoad then
        frame:OnLoad()
    end

    return frame
end

--- Create a simple backdrop frame
-- @param parent Frame - Parent frame
-- @param backdrop table - Backdrop info (or use default)
-- @return Frame - The created frame
function FrameUtil.CreateBackdropFrame(parent, backdrop)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")

    backdrop = backdrop or Backdrop.Panel
    if backdrop then
        frame:SetBackdrop(backdrop)
        frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end

    return frame
end

--[[--------------------------------------------------------------------
    Script Handlers
----------------------------------------------------------------------]]

-- Standard script handlers that can be reflected from mixins
local STANDARD_SCRIPT_HANDLERS = {
    "OnLoad", "OnShow", "OnHide", "OnEvent", "OnUpdate",
    "OnEnter", "OnLeave", "OnClick", "OnDoubleClick",
    "OnDragStart", "OnDragStop", "OnReceiveDrag",
    "OnMouseDown", "OnMouseUp", "OnMouseWheel",
    "OnValueChanged", "OnTextChanged", "OnTextSet",
    "OnEnterPressed", "OnEscapePressed", "OnTabPressed",
    "OnSpacePressed", "OnEditFocusGained", "OnEditFocusLost",
    "OnCursorChanged", "OnInputLanguageChanged",
    "OnSizeChanged", "OnAttributeChanged",
    "OnHorizontalScroll", "OnVerticalScroll", "OnScrollRangeChanged",
    "OnCharComposition",
}

--- Get the list of standard script handler names
-- @return table - Array of script handler names
function FrameUtil.GetStandardScriptHandlers()
    return STANDARD_SCRIPT_HANDLERS
end

--- Check if a frame supports a specific script
-- @param frame Frame - The frame to check
-- @param scriptName string - The script name
-- @return boolean
function FrameUtil.SupportsScript(frame, scriptName)
    return frame.HasScript and frame:HasScript(scriptName)
end

--- Hook a script handler (preserving existing)
-- @param frame Frame - The frame
-- @param scriptName string - The script name
-- @param handler function - The handler to add
function FrameUtil.HookScript(frame, scriptName, handler)
    if FrameUtil.SupportsScript(frame, scriptName) then
        frame:HookScript(scriptName, handler)
    end
end

--- Set a script handler with automatic nil handling
-- @param frame Frame - The frame
-- @param scriptName string - The script name
-- @param handler function - The handler (or nil to clear)
function FrameUtil.SetScript(frame, scriptName, handler)
    if FrameUtil.SupportsScript(frame, scriptName) then
        frame:SetScript(scriptName, handler)
    end
end

--[[--------------------------------------------------------------------
    Frame Properties
----------------------------------------------------------------------]]

--- Make a frame movable by dragging
-- @param frame Frame - The frame to make movable
-- @param clampToScreen boolean - Whether to clamp to screen (default true)
function FrameUtil.MakeMovable(frame, clampToScreen)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(clampToScreen ~= false)

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

--- Make a frame resizable
-- @param frame Frame - The frame to make resizable
-- @param minWidth number - Minimum width
-- @param minHeight number - Minimum height
-- @param maxWidth number - Maximum width (optional)
-- @param maxHeight number - Maximum height (optional)
function FrameUtil.MakeResizable(frame, minWidth, minHeight, maxWidth, maxHeight)
    frame:SetResizable(true)

    if minWidth and minHeight then
        frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    end

    -- Create resize grip
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    grip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)

    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
    end)

    frame.resizeGrip = grip
end

--- Add a close button to a frame
-- @param frame Frame - The frame
-- @param onClose function - Optional close callback
-- @return Button - The close button
function FrameUtil.AddCloseButton(frame, onClose)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)

    closeBtn:SetScript("OnClick", function()
        if onClose then
            onClose(frame)
        end
        frame:Hide()
    end)

    frame.CloseButton = closeBtn
    return closeBtn
end

--- Add a title text to a frame
-- @param frame Frame - The frame
-- @param title string - The title text
-- @param fontObject string - Font object name (default "GameFontNormal")
-- @return FontString - The title font string
function FrameUtil.AddTitle(frame, title, fontObject)
    local titleText = frame:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal")
    titleText:SetPoint("TOP", 0, -10)
    titleText:SetText(title)

    frame.TitleText = titleText
    return titleText
end

--[[--------------------------------------------------------------------
    Frame State
----------------------------------------------------------------------]]

--- Check if a frame is currently visible on screen
-- @param frame Frame - The frame to check
-- @return boolean
function FrameUtil.IsVisibleOnScreen(frame)
    if not frame:IsShown() then
        return false
    end

    -- Check if any parent is hidden
    local parent = frame:GetParent()
    while parent do
        if not parent:IsShown() then
            return false
        end
        parent = parent:GetParent()
    end

    return true
end

--- Get the effective alpha of a frame (including parent alpha)
-- @param frame Frame - The frame
-- @return number - The effective alpha
function FrameUtil.GetEffectiveAlpha(frame)
    local alpha = frame:GetAlpha()
    local parent = frame:GetParent()

    while parent do
        alpha = alpha * parent:GetAlpha()
        parent = parent:GetParent()
    end

    return alpha
end

--- Get the absolute position of a frame on screen
-- @param frame Frame - The frame
-- @return number, number, number, number - left, bottom, width, height
function FrameUtil.GetAbsolutePosition(frame)
    local scale = frame:GetEffectiveScale()
    local left = frame:GetLeft() * scale
    local bottom = frame:GetBottom() * scale
    local width = frame:GetWidth() * scale
    local height = frame:GetHeight() * scale

    return left, bottom, width, height
end

--[[--------------------------------------------------------------------
    Frame Hierarchy
----------------------------------------------------------------------]]

--- Get all children of a frame
-- @param frame Frame - The frame
-- @return table - Array of child frames
function FrameUtil.GetAllChildren(frame)
    local children = {}
    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        children[#children + 1] = child
    end
    return children
end

--- Get all regions of a frame
-- @param frame Frame - The frame
-- @return table - Array of regions
function FrameUtil.GetAllRegions(frame)
    local regions = {}
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        regions[#regions + 1] = region
    end
    return regions
end

--- Find a child frame by name pattern
-- @param frame Frame - The parent frame
-- @param pattern string - Name pattern to match
-- @return Frame|nil - The matching child or nil
function FrameUtil.FindChild(frame, pattern)
    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        local name = child:GetName()
        if name and name:match(pattern) then
            return child
        end
    end
    return nil
end

--- Execute a function on a frame and all its descendants
-- @param frame Frame - The root frame
-- @param func function - Function(frame) to execute
function FrameUtil.ForEachDescendant(frame, func)
    func(frame)

    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        FrameUtil.ForEachDescendant(child, func)
    end
end

--[[--------------------------------------------------------------------
    Frame Visibility
----------------------------------------------------------------------]]

--- Show a frame with optional fade-in
-- @param frame Frame - The frame to show
-- @param duration number - Fade duration (0 for instant)
-- @param onComplete function - Optional callback when complete
function FrameUtil.ShowWithFade(frame, duration, onComplete)
    if duration and duration > 0 then
        frame:SetAlpha(0)
        frame:Show()

        local elapsed = 0
        frame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local progress = math.min(elapsed / duration, 1)
            self:SetAlpha(progress)

            if progress >= 1 then
                self:SetScript("OnUpdate", nil)
                if onComplete then
                    onComplete(frame)
                end
            end
        end)
    else
        frame:SetAlpha(1)
        frame:Show()
        if onComplete then
            onComplete(frame)
        end
    end
end

--- Hide a frame with optional fade-out
-- @param frame Frame - The frame to hide
-- @param duration number - Fade duration (0 for instant)
-- @param onComplete function - Optional callback when complete
function FrameUtil.HideWithFade(frame, duration, onComplete)
    if duration and duration > 0 then
        local startAlpha = frame:GetAlpha()
        local elapsed = 0

        frame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local progress = math.min(elapsed / duration, 1)
            self:SetAlpha(startAlpha * (1 - progress))

            if progress >= 1 then
                self:SetScript("OnUpdate", nil)
                self:Hide()
                self:SetAlpha(1)
                if onComplete then
                    onComplete(frame)
                end
            end
        end)
    else
        frame:Hide()
        if onComplete then
            onComplete(frame)
        end
    end
end

--[[--------------------------------------------------------------------
    Frame Level Management
----------------------------------------------------------------------]]

--- Bring a frame to the front of its strata
-- @param frame Frame - The frame
function FrameUtil.BringToFront(frame)
    local maxLevel = 0
    local parent = frame:GetParent()

    if parent then
        for i = 1, parent:GetNumChildren() do
            local child = select(i, parent:GetChildren())
            if child ~= frame and child:GetFrameStrata() == frame:GetFrameStrata() then
                maxLevel = math.max(maxLevel, child:GetFrameLevel())
            end
        end
    end

    frame:SetFrameLevel(maxLevel + 1)
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

UI.FrameUtil = FrameUtil
Loolib.FrameUtil = FrameUtil

Loolib:RegisterModule("UI.FrameUtil", FrameUtil)
