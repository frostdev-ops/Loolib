--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    StyleUtil - Shared styling helpers for themed UI construction

    Provides light-weight helpers around ThemeManager so addons can apply
    fonts, textures, backdrops, dividers, and button chrome without
    repeating raw colors and spacing values in every frame constructor.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local ThemeManager = assert(Loolib.ThemeManager, "Loolib.ThemeManager is required for StyleUtil")
local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
local StyleUtil = UI.StyleUtil or Loolib:GetModule("UI.StyleUtil") or {}

local type = type

local function ResolveColor(colorName, fallback)
    if type(colorName) == "table" then
        return colorName
    end
    return ThemeManager:GetColor(colorName, fallback)
end

local function SetVertexColor(region, color)
    if not color or type(region) ~= "table" or type(region.SetVertexColor) ~= "function" then
        return
    end
    region:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

local function SetSolidColor(region, color)
    if not color or type(region) ~= "table" or type(region.SetColorTexture) ~= "function" then
        return
    end
    region:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

local function ResolveMediaToken(mediaType, token)
    if token == nil then
        return nil
    end
    if mediaType == "texture" or mediaType == "image" then
        return ThemeManager:GetTexture(token, nil)
    end
    return ThemeManager:ResolveMedia(mediaType, token, nil)
end

local function NormalizeTextureState(state)
    if state == nil then
        return nil
    end

    if type(state) == "string" or type(state) == "number" then
        return {
            texture = ResolveMediaToken("texture", state),
        }
    end

    if type(state) ~= "table" then
        return nil
    end

    local textureToken = state.texture or state.path or state.media
    local kind = state.kind or "texture"
    local normalized = {
        texture = ResolveMediaToken(kind, textureToken),
        alpha = state.alpha,
        blendMode = state.blendMode,
        texCoord = state.texCoord,
        vertexColor = state.vertexColor,
        desaturated = state.desaturated,
    }

    if normalized.texture == nil then
        return nil
    end

    return normalized
end

local function SetButtonTextureState(button, stateName, textureState, sharedState)
    local setterNameByState = {
        normal = "SetNormalTexture",
        pushed = "SetPushedTexture",
        highlight = "SetHighlightTexture",
        disabled = "SetDisabledTexture",
    }
    local getterNameByState = {
        normal = "GetNormalTexture",
        pushed = "GetPushedTexture",
        highlight = "GetHighlightTexture",
        disabled = "GetDisabledTexture",
    }

    local setterName = setterNameByState[stateName]
    local getterName = getterNameByState[stateName]
    local setter = setterName and button[setterName]
    if type(setter) ~= "function" then
        return
    end

    if not textureState or not textureState.texture then
        if stateName == "highlight" then
            setter(button, "")
        else
            setter(button, "")
        end
        return
    end

    if stateName == "highlight" then
        setter(button, textureState.texture, textureState.blendMode or sharedState.blendMode or "ADD")
    else
        setter(button, textureState.texture)
    end

    local getter = getterName and button[getterName]
    local region = type(getter) == "function" and getter(button) or nil
    if type(region) ~= "table" then
        return
    end

    if type(region.SetAllPoints) == "function" then
        region:SetAllPoints(button)
    end

    local texCoord = textureState.texCoord or sharedState.texCoord
    if texCoord and type(region.SetTexCoord) == "function" then
        region:SetTexCoord(unpack(texCoord))
    end

    local vertexColor = textureState.vertexColor or sharedState.vertexColor
    if vertexColor then
        SetVertexColor(region, ResolveColor(vertexColor))
    elseif type(region.SetVertexColor) == "function" then
        region:SetVertexColor(1, 1, 1, 1)
    end

    local alpha = textureState.alpha or sharedState.alpha
    if alpha ~= nil and type(region.SetAlpha) == "function" then
        region:SetAlpha(alpha)
    end

    local desaturated = textureState.desaturated
    if desaturated == nil then
        desaturated = sharedState.desaturated
    end
    if desaturated ~= nil and type(region.SetDesaturated) == "function" then
        region:SetDesaturated(desaturated and true or false)
    end
end

--- Get a spacing token from the active theme.
-- @param spacingName string
-- @param fallback number|nil
-- @return number
function StyleUtil.GetSpacing(spacingName, fallback)
    return ThemeManager:GetSpacing(spacingName, fallback)
end

--- Get a spacing-set table from the active theme.
-- @param spacingSetName string
-- @param fallback table|nil
-- @return table|nil
function StyleUtil.GetSpacingSet(spacingSetName, fallback)
    return ThemeManager:GetSpacingSet(spacingSetName, fallback)
end

--- Apply a themed font and optional text color to a FontString.
-- @param fontString FontString
-- @param fontName string
-- @param colorName string|table|nil
-- @param sizeOverride number|nil
-- @param flagsOverride string|nil
function StyleUtil.ApplyText(fontString, fontName, colorName, sizeOverride, flagsOverride)
    if type(fontString) ~= "table" then
        return
    end

    ThemeManager:ApplyFont(fontString, fontName, sizeOverride, flagsOverride)

    if colorName ~= nil and type(fontString.SetTextColor) == "function" then
        local color = ResolveColor(colorName, ThemeManager:GetColor("text"))
        fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
end

--- Apply a themed texture token to a texture region.
-- @param textureRegion Texture
-- @param textureName string
-- @param options table|nil
function StyleUtil.ApplyTexture(textureRegion, textureName, options)
    if type(textureRegion) ~= "table" or type(textureRegion.SetTexture) ~= "function" then
        return
    end

    options = options or {}
    ThemeManager:ApplyTexture(textureRegion, textureName, options.fallback)

    if options.texCoord and type(textureRegion.SetTexCoord) == "function" then
        textureRegion:SetTexCoord(unpack(options.texCoord))
    end

    if options.vertexColor then
        SetVertexColor(textureRegion, ResolveColor(options.vertexColor))
    end
end

--- Apply a themed backdrop and colors to a frame.
-- @param frame Frame
-- @param options table|nil
function StyleUtil.ApplyBackdrop(frame, options)
    if type(frame) ~= "table" or type(frame.SetBackdrop) ~= "function" then
        return
    end

    options = options or {}

    local backdrop = options.backdropData or ThemeManager:GetBackdrop(options.backdrop or "flat")
    if backdrop then
        frame:SetBackdrop(backdrop)
    end

    ThemeManager:ApplyBackdropColors(
        frame,
        options.bgColor or "background",
        options.borderColor or "border"
    )
end

--- Apply a themed gradient to a StatusBar texture.
-- Configures the statusbar with a 1x1 white backing and applies the gradient
-- via ThemeManager:ApplyGradient. The bar's SetStatusBarColor is set to white
-- so the gradient shows through unmultiplied.
-- @param statusBar StatusBar
-- @param gradientName string
-- @param fallback table|nil
function StyleUtil.ApplyGradientBar(statusBar, gradientName, fallback)
    if type(statusBar) ~= "table" then return end

    if type(statusBar.SetStatusBarTexture) == "function" then
        statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    end
    if type(statusBar.SetStatusBarColor) == "function" then
        statusBar:SetStatusBarColor(1, 1, 1, 1)
    end

    local region = type(statusBar.GetStatusBarTexture) == "function" and statusBar:GetStatusBarTexture() or nil
    if region then
        ThemeManager:ApplyGradient(region, gradientName, fallback)
    end
end

--- Apply a themed gradient to any texture region (not a StatusBar).
-- Ensures the texture is white-backed so the gradient shows through.
-- @param textureRegion Texture
-- @param gradientName string
-- @param fallback table|nil
function StyleUtil.ApplyGradientTexture(textureRegion, gradientName, fallback)
    if type(textureRegion) ~= "table" then return end
    if type(textureRegion.SetColorTexture) == "function" then
        textureRegion:SetColorTexture(1, 1, 1, 1)
    end
    ThemeManager:ApplyGradient(textureRegion, gradientName, fallback)
end

--- Create a thin divider texture anchored to a parent.
-- @param parent Frame
-- @param options table|nil
-- @return Texture
function StyleUtil.CreateDivider(parent, options)
    options = options or {}

    local divider = parent:CreateTexture(nil, options.layer or "ARTWORK", nil, options.subLevel)
    local thickness = options.thickness or 1
    local color = ResolveColor(options.color or "borderDark", ThemeManager:GetColor("borderDark"))

    if options.orientation == "vertical" then
        divider:SetWidth(thickness)
    else
        divider:SetHeight(thickness)
    end

    if options.texture then
        StyleUtil.ApplyTexture(divider, options.texture, options)
        SetVertexColor(divider, color)
    else
        SetSolidColor(divider, color)
    end

    return divider
end

--- Style a simple backdrop button using theme tokens.
-- Safe for buttons that do not use WoW's nine-slice templates.
-- @param button Button
-- @param options table|nil
function StyleUtil.ApplyButton(button, options)
    if type(button) ~= "table" then
        return
    end

    options = options or {}

    local componentConfig = ThemeManager:GetComponentConfig("Button", {})
    local textureSet = options.textureSet or componentConfig.textureSet
    local clearTextures = options.clearTextures or false

    if type(button.SetBackdrop) == "function" then
        StyleUtil.ApplyBackdrop(button, {
            backdrop = options.backdrop or componentConfig.backdrop or "flat",
            bgColor = options.bgColor or componentConfig.bgColor or "buttonNormal",
            borderColor = options.borderColor or componentConfig.borderColor or "border",
        })
    end

    if textureSet or clearTextures then
        local sharedState = type(textureSet) == "table" and textureSet.shared or {}
        local normalState = NormalizeTextureState(type(textureSet) == "table" and textureSet.normal or nil)
        local pushedState = NormalizeTextureState(type(textureSet) == "table" and (textureSet.pushed or textureSet.pressed) or nil)
        local highlightState = NormalizeTextureState(type(textureSet) == "table" and (textureSet.highlight or textureSet.hover) or nil)
        local disabledState = NormalizeTextureState(type(textureSet) == "table" and textureSet.disabled or nil)

        SetButtonTextureState(button, "normal", normalState, sharedState or {})
        SetButtonTextureState(button, "pushed", pushedState, sharedState or {})
        SetButtonTextureState(button, "highlight", highlightState, sharedState or {})
        SetButtonTextureState(button, "disabled", disabledState, sharedState or {})
    end

    local fontString = (button.GetFontString and button:GetFontString()) or button.Text or button.text or button.label
    if fontString then
        StyleUtil.ApplyText(fontString, options.font or componentConfig.font or "body", options.textColor or componentConfig.textColor or "text")
    end
end

UI.StyleUtil = StyleUtil
Loolib.StyleUtil = StyleUtil
Loolib:RegisterModule("UI.StyleUtil", StyleUtil)
