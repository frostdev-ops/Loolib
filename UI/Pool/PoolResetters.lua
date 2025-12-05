--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    PoolResetters - Standard reset functions for object pools

    Reset functions are called when objects are acquired and released
    to ensure they're in a clean state.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

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
function LoolibPoolReset_HideAndClearAnchors(pool, region)
    region:Hide()
    region:ClearAllPoints()
end

--- Full frame reset - comprehensive cleanup
-- @param pool table - The pool
-- @param frame Frame - The frame to reset
-- @param isNew boolean - True if first creation
function LoolibPoolReset_Frame(pool, frame, isNew)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetAlpha(1)
    frame:SetScale(1)

    if frame.SetEnabled and frame:IsObjectType("Button") then
        frame:SetEnabled(true)
    end

    -- Clear frame level if it was modified
    -- (Don't reset to 0, that could cause issues)

    -- Clear any stored data
    frame.data = nil
    frame.elementData = nil
    frame.layoutIndex = nil
end

--- Button reset
-- @param pool table - The pool
-- @param button Button - The button to reset
-- @param isNew boolean - True if first creation
function LoolibPoolReset_Button(pool, button, isNew)
    button:Hide()
    button:ClearAllPoints()
    button:SetAlpha(1)
    button:SetScale(1)
    button:SetEnabled(true)

    if button.SetText then
        button:SetText("")
    end

    if button.SetNormalTexture then
        button:SetNormalTexture(nil)
    end

    if button.SetPushedTexture then
        button:SetPushedTexture(nil)
    end

    if button.SetHighlightTexture then
        button:SetHighlightTexture(nil)
    end

    button.data = nil
end

--- Texture reset
-- @param pool table - The pool
-- @param texture Texture - The texture to reset
function LoolibPoolReset_Texture(pool, texture)
    texture:Hide()
    texture:ClearAllPoints()
    texture:SetAlpha(1)
    texture:SetTexture(nil)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetDesaturated(false)
    texture:SetRotation(0)
end

--- FontString reset
-- @param pool table - The pool
-- @param fontString FontString - The font string to reset
function LoolibPoolReset_FontString(pool, fontString)
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
function LoolibPoolReset_EditBox(pool, editBox)
    editBox:Hide()
    editBox:ClearAllPoints()
    editBox:SetAlpha(1)
    editBox:SetText("")
    editBox:SetEnabled(true)
    editBox:SetAutoFocus(false)
    editBox:ClearFocus()
end

--- Slider reset
-- @param pool table - The pool
-- @param slider Slider - The slider to reset
function LoolibPoolReset_Slider(pool, slider)
    slider:Hide()
    slider:ClearAllPoints()
    slider:SetAlpha(1)
    slider:SetEnabled(true)
    slider:SetValue(slider:GetMinMaxValues())
end

--- StatusBar reset
-- @param pool table - The pool
-- @param statusBar StatusBar - The status bar to reset
function LoolibPoolReset_StatusBar(pool, statusBar)
    statusBar:Hide()
    statusBar:ClearAllPoints()
    statusBar:SetAlpha(1)
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)
end

--- CheckButton reset
-- @param pool table - The pool
-- @param checkButton CheckButton - The check button to reset
function LoolibPoolReset_CheckButton(pool, checkButton)
    checkButton:Hide()
    checkButton:ClearAllPoints()
    checkButton:SetAlpha(1)
    checkButton:SetEnabled(true)
    checkButton:SetChecked(false)

    if checkButton.text then
        checkButton.text:SetText("")
    end
end

--- ScrollFrame reset
-- @param pool table - The pool
-- @param scrollFrame ScrollFrame - The scroll frame to reset
function LoolibPoolReset_ScrollFrame(pool, scrollFrame)
    scrollFrame:Hide()
    scrollFrame:ClearAllPoints()
    scrollFrame:SetAlpha(1)
    scrollFrame:SetVerticalScroll(0)
    scrollFrame:SetHorizontalScroll(0)
end

--[[--------------------------------------------------------------------
    Reset Function Factory
----------------------------------------------------------------------]]

--- Create a custom reset function that chains with a base reset
-- @param baseReset function - The base reset function to call first
-- @param customReset function - Additional reset logic
-- @return function - Combined reset function
function LoolibCreateChainedReset(baseReset, customReset)
    return function(pool, object, isNew)
        baseReset(pool, object, isNew)
        customReset(pool, object, isNew)
    end
end

--- Create a reset function for a specific frame type
-- @param frameType string - The frame type (e.g., "Button", "Frame")
-- @param additionalReset function - Optional additional reset logic
-- @return function - Reset function for the frame type
function LoolibGetResetterForFrameType(frameType, additionalReset)
    local baseReset

    if frameType == "Button" then
        baseReset = LoolibPoolReset_Button
    elseif frameType == "CheckButton" then
        baseReset = LoolibPoolReset_CheckButton
    elseif frameType == "EditBox" then
        baseReset = LoolibPoolReset_EditBox
    elseif frameType == "Slider" then
        baseReset = LoolibPoolReset_Slider
    elseif frameType == "StatusBar" then
        baseReset = LoolibPoolReset_StatusBar
    elseif frameType == "ScrollFrame" then
        baseReset = LoolibPoolReset_ScrollFrame
    else
        baseReset = LoolibPoolReset_Frame
    end

    if additionalReset then
        return LoolibCreateChainedReset(baseReset, additionalReset)
    end

    return baseReset
end

--[[--------------------------------------------------------------------
    Region Type Reset
----------------------------------------------------------------------]]

--- Create a reset function for a specific region type
-- @param regionType string - "Texture" or "FontString"
-- @param additionalReset function - Optional additional reset logic
-- @return function - Reset function for the region type
function LoolibGetResetterForRegionType(regionType, additionalReset)
    local baseReset

    if regionType == "Texture" then
        baseReset = LoolibPoolReset_Texture
    elseif regionType == "FontString" then
        baseReset = LoolibPoolReset_FontString
    else
        baseReset = LoolibPoolReset_HideAndClearAnchors
    end

    if additionalReset then
        return LoolibCreateChainedReset(baseReset, additionalReset)
    end

    return baseReset
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local PoolResetters = {
    -- Standard resetters
    HideAndClearAnchors = LoolibPoolReset_HideAndClearAnchors,
    Frame = LoolibPoolReset_Frame,
    Button = LoolibPoolReset_Button,
    Texture = LoolibPoolReset_Texture,
    FontString = LoolibPoolReset_FontString,
    EditBox = LoolibPoolReset_EditBox,
    Slider = LoolibPoolReset_Slider,
    StatusBar = LoolibPoolReset_StatusBar,
    CheckButton = LoolibPoolReset_CheckButton,
    ScrollFrame = LoolibPoolReset_ScrollFrame,

    -- Factory functions
    CreateChained = LoolibCreateChainedReset,
    GetForFrameType = LoolibGetResetterForFrameType,
    GetForRegionType = LoolibGetResetterForRegionType,
}

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.PoolResetters = PoolResetters

Loolib:RegisterModule("PoolResetters", PoolResetters)
