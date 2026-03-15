--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    PoolResetters - Standard reset functions for object pools

    Reset functions are called when objects are released back to
    their pool to ensure they are returned to a clean state.
    Signature: function(pool, object, isNew)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local Pool = Loolib.Pool or Loolib:GetOrCreateModule("Pool")

-- Cache globals
local type = type

--[[--------------------------------------------------------------------
    Standard Reset Functions

    These functions are called with (pool, object, isNew) where:
    - pool: The pool the object belongs to
    - object: The object being reset
    - isNew: True if this is first creation (acquire only)
----------------------------------------------------------------------]]

--- Hide and clear anchors - most common reset pattern
-- @param pool table - The pool
-- @param region Region - The region to reset
local function ResetHideAndClearAnchors(pool, region)
    region:Hide()
    region:ClearAllPoints()
end

--- Full frame reset - comprehensive cleanup
-- Clears visibility, anchors, alpha, scale, size, scripts, and stored data.
-- @param pool table - The pool
-- @param frame Frame - The frame to reset
-- @param isNew boolean - True if first creation
local function ResetFrame(pool, frame, isNew)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetAlpha(1)
    frame:SetScale(1)
    frame:SetSize(0, 0)

    if frame.SetEnabled and frame:IsObjectType("Button") then
        frame:SetEnabled(true)
    end

    -- Clear user-set scripts to prevent stale handler leaks
    if frame.HasScript then
        if frame:HasScript("OnUpdate") then frame:SetScript("OnUpdate", nil) end
        if frame:HasScript("OnEnter") then frame:SetScript("OnEnter", nil) end
        if frame:HasScript("OnLeave") then frame:SetScript("OnLeave", nil) end
    end

    -- Clear any stored data
    frame.data = nil
    frame.elementData = nil
    frame.layoutIndex = nil
end

--- Button reset
-- @param pool table - The pool
-- @param button Button - The button to reset
-- @param isNew boolean - True if first creation
local function ResetButton(pool, button, isNew)
    button:Hide()
    button:ClearAllPoints()
    button:SetAlpha(1)
    button:SetScale(1)
    button:SetSize(0, 0)
    button:SetEnabled(true)

    if button.SetText then
        button:SetText("")
    end

    if button.SetNormalTexture then
        button:SetNormalTexture("")
    end

    if button.SetPushedTexture then
        button:SetPushedTexture("")
    end

    if button.SetHighlightTexture then
        button:SetHighlightTexture("")
    end

    -- Clear user-set scripts
    if button.HasScript then
        if button:HasScript("OnClick") then button:SetScript("OnClick", nil) end
        if button:HasScript("OnEnter") then button:SetScript("OnEnter", nil) end
        if button:HasScript("OnLeave") then button:SetScript("OnLeave", nil) end
    end

    button.data = nil
end

--- Texture reset
-- @param pool table - The pool
-- @param texture Texture - The texture to reset
local function ResetTexture(pool, texture)
    texture:Hide()
    texture:ClearAllPoints()
    texture:SetAlpha(1)
    texture:SetTexture(nil)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetDesaturated(false)
    texture:SetRotation(0)
    texture:SetSize(0, 0)
end

--- FontString reset
-- @param pool table - The pool
-- @param fontString FontString - The font string to reset
local function ResetFontString(pool, fontString)
    fontString:Hide()
    fontString:ClearAllPoints()
    fontString:SetAlpha(1)
    fontString:SetText("")
    fontString:SetTextColor(1, 1, 1, 1)
    fontString:SetJustifyH("CENTER")
    fontString:SetJustifyV("MIDDLE")
    fontString:SetWordWrap(true)
    fontString:SetNonSpaceWrap(false)
end

--- EditBox reset
-- @param pool table - The pool
-- @param editBox EditBox - The edit box to reset
local function ResetEditBox(pool, editBox)
    editBox:Hide()
    editBox:ClearAllPoints()
    editBox:SetAlpha(1)
    editBox:SetText("")
    editBox:SetEnabled(true)
    editBox:SetAutoFocus(false)
    editBox:ClearFocus()
    editBox:SetSize(0, 0)

    -- Clear user-set scripts
    if editBox.HasScript then
        if editBox:HasScript("OnTextChanged") then editBox:SetScript("OnTextChanged", nil) end
        if editBox:HasScript("OnEnterPressed") then editBox:SetScript("OnEnterPressed", nil) end
        if editBox:HasScript("OnEscapePressed") then editBox:SetScript("OnEscapePressed", nil) end
    end
end

--- Slider reset
-- @param pool table - The pool
-- @param slider Slider - The slider to reset
local function ResetSlider(pool, slider)
    slider:Hide()
    slider:ClearAllPoints()
    slider:SetAlpha(1)
    slider:SetEnabled(true)
    slider:SetValue(slider:GetMinMaxValues())
    slider:SetSize(0, 0)

    -- Clear user-set scripts
    if slider.HasScript then
        if slider:HasScript("OnValueChanged") then slider:SetScript("OnValueChanged", nil) end
    end
end

--- StatusBar reset
-- @param pool table - The pool
-- @param statusBar StatusBar - The status bar to reset
local function ResetStatusBar(pool, statusBar)
    statusBar:Hide()
    statusBar:ClearAllPoints()
    statusBar:SetAlpha(1)
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)
    statusBar:SetSize(0, 0)
end

--- CheckButton reset
-- @param pool table - The pool
-- @param checkButton CheckButton - The check button to reset
local function ResetCheckButton(pool, checkButton)
    checkButton:Hide()
    checkButton:ClearAllPoints()
    checkButton:SetAlpha(1)
    checkButton:SetEnabled(true)
    checkButton:SetChecked(false)
    checkButton:SetSize(0, 0)

    if checkButton.text then
        checkButton.text:SetText("")
    end

    -- Clear user-set scripts
    if checkButton.HasScript then
        if checkButton:HasScript("OnClick") then checkButton:SetScript("OnClick", nil) end
    end
end

--- ScrollFrame reset
-- @param pool table - The pool
-- @param scrollFrame ScrollFrame - The scroll frame to reset
local function ResetScrollFrame(pool, scrollFrame)
    scrollFrame:Hide()
    scrollFrame:ClearAllPoints()
    scrollFrame:SetAlpha(1)
    scrollFrame:SetVerticalScroll(0)
    scrollFrame:SetHorizontalScroll(0)
    scrollFrame:SetSize(0, 0)
end

--[[--------------------------------------------------------------------
    Reset Function Factory
----------------------------------------------------------------------]]

--- Create a custom reset function that chains with a base reset
-- @param baseReset function - The base reset function to call first
-- @param customReset function - Additional reset logic
-- @return function - Combined reset function
local function CreateChainedReset(baseReset, customReset)
    if type(baseReset) ~= "function" then
        error("LoolibPoolResetters: CreateChainedReset requires baseReset as a function", 2)
    end
    if type(customReset) ~= "function" then
        error("LoolibPoolResetters: CreateChainedReset requires customReset as a function", 2)
    end
    return function(pool, object, isNew)
        baseReset(pool, object, isNew)
        customReset(pool, object, isNew)
    end
end

--- Create a reset function for a specific frame type -- INTERNAL
-- @param frameType string - The frame type (e.g., "Button", "Frame")
-- @param additionalReset function - Optional additional reset logic
-- @return function - Reset function for the frame type
local function GetResetterForFrameType(frameType, additionalReset)
    if type(frameType) ~= "string" then
        error("LoolibPoolResetters: GetForFrameType requires frameType as a string", 2)
    end
    if additionalReset ~= nil and type(additionalReset) ~= "function" then
        error("LoolibPoolResetters: GetForFrameType additionalReset must be a function or nil", 2)
    end

    local baseReset

    if frameType == "Button" then
        baseReset = ResetButton
    elseif frameType == "CheckButton" then
        baseReset = ResetCheckButton
    elseif frameType == "EditBox" then
        baseReset = ResetEditBox
    elseif frameType == "Slider" then
        baseReset = ResetSlider
    elseif frameType == "StatusBar" then
        baseReset = ResetStatusBar
    elseif frameType == "ScrollFrame" then
        baseReset = ResetScrollFrame
    else
        baseReset = ResetFrame
    end

    if additionalReset then
        return CreateChainedReset(baseReset, additionalReset)
    end

    return baseReset
end

--[[--------------------------------------------------------------------
    Region Type Reset
----------------------------------------------------------------------]]

--- Create a reset function for a specific region type -- INTERNAL
-- @param regionType string - "Texture" or "FontString"
-- @param additionalReset function - Optional additional reset logic
-- @return function - Reset function for the region type
local function GetResetterForRegionType(regionType, additionalReset)
    if type(regionType) ~= "string" then
        error("LoolibPoolResetters: GetForRegionType requires regionType as a string", 2)
    end
    if additionalReset ~= nil and type(additionalReset) ~= "function" then
        error("LoolibPoolResetters: GetForRegionType additionalReset must be a function or nil", 2)
    end

    local baseReset

    if regionType == "Texture" then
        baseReset = ResetTexture
    elseif regionType == "FontString" then
        baseReset = ResetFontString
    else
        baseReset = ResetHideAndClearAnchors
    end

    if additionalReset then
        return CreateChainedReset(baseReset, additionalReset)
    end

    return baseReset
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local PoolResetters = {
    -- Standard resetters
    HideAndClearAnchors = ResetHideAndClearAnchors,
    Frame = ResetFrame,
    Button = ResetButton,
    Texture = ResetTexture,
    FontString = ResetFontString,
    EditBox = ResetEditBox,
    Slider = ResetSlider,
    StatusBar = ResetStatusBar,
    CheckButton = ResetCheckButton,
    ScrollFrame = ResetScrollFrame,

    -- Factory functions
    CreateChained = CreateChainedReset,
    GetForFrameType = GetResetterForFrameType,
    GetForRegionType = GetResetterForRegionType,
}

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.PoolResetters = PoolResetters

Pool.PoolResetters = PoolResetters

Loolib.PoolReset_HideAndClearAnchors = ResetHideAndClearAnchors
Loolib.PoolReset_Frame = ResetFrame
Loolib.PoolReset_Button = ResetButton
Loolib.PoolReset_Texture = ResetTexture
Loolib.PoolReset_FontString = ResetFontString
Loolib.PoolReset_EditBox = ResetEditBox
Loolib.PoolReset_Slider = ResetSlider
Loolib.PoolReset_StatusBar = ResetStatusBar
Loolib.PoolReset_CheckButton = ResetCheckButton
Loolib.PoolReset_ScrollFrame = ResetScrollFrame
Loolib.CreateChainedReset = CreateChainedReset
Loolib.GetResetterForFrameType = GetResetterForFrameType
Loolib.GetResetterForRegionType = GetResetterForRegionType

Loolib:RegisterModule("Pool.PoolResetters", PoolResetters)
