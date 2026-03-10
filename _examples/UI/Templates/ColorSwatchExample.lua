--[[--------------------------------------------------------------------
    ColorSwatch Usage Examples

    This file demonstrates how to use the ColorSwatch widgets.
    NOT loaded by loolib.toc - for reference only.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Example 1: Simple Color Swatch
----------------------------------------------------------------------]]

-- Create a simple color swatch (24x24)
local swatch = LoolibColorSwatch.Create(parentFrame, {
    r = 1.0,
    g = 0.0,
    b = 0.0,
    a = 1.0,
    hasAlpha = false,
    callback = function(r, g, b, a)
        print("Color changed:", r, g, b, a)
    end
})

-- Position it
swatch:SetPoint("TOPLEFT", 20, -20)

-- Get/Set color
swatch:SetColor(0, 1, 0, 1)  -- Green
local r, g, b, a = swatch:GetColor()

-- Enable alpha
swatch:SetHasAlpha(true)

-- Register for color change events
swatch:RegisterCallback("OnColorChanged", function(r, g, b, a)
    print("Event fired:", r, g, b, a)
end)

--[[--------------------------------------------------------------------
    Example 2: Color Swatch with Presets
----------------------------------------------------------------------]]

-- Create a full color picker with presets (280x130, 280x160 with alpha)
local picker = LoolibColorSwatchWithPresets.Create(parentFrame, {
    r = 0.5,
    g = 0.5,
    b = 1.0,
    a = 0.8,
    hasAlpha = true,
    recentColorsKey = "myAddonColors",  -- SavedVariables key for recent colors
    callback = function(r, g, b, a)
        -- Apply color to your UI element
        myFrame:SetBackdropColor(r, g, b, a)
    end
})

picker:SetPoint("TOPLEFT", 20, -60)

--[[--------------------------------------------------------------------
    Example 3: Using with Config System
----------------------------------------------------------------------]]

-- In your config options table:
local options = {
    type = "group",
    name = "My Addon",
    args = {
        backgroundColor = {
            type = "color",
            name = "Background Color",
            desc = "Choose a background color",
            hasAlpha = true,
            get = function()
                local db = myAddon.db.profile
                return db.bgR, db.bgG, db.bgB, db.bgA
            end,
            set = function(info, r, g, b, a)
                local db = myAddon.db.profile
                db.bgR = r
                db.bgG = g
                db.bgB = b
                db.bgA = a
                -- Update your UI
                myFrame:SetBackdropColor(r, g, b, a)
            end,
        },
    },
}

--[[--------------------------------------------------------------------
    Example 4: Programmatic Color Selection
----------------------------------------------------------------------]]

-- Apply preset color
picker:ApplyColor(1.0, 0.0, 0.0, 1.0)  -- Red

-- Apply color from hex string
picker:ApplyHexColor("FF6600")  -- Orange

-- Get hex representation
local hex = string.format("%02X%02X%02X",
    math.floor(picker.r * 255),
    math.floor(picker.g * 255),
    math.floor(picker.b * 255)
)

--[[--------------------------------------------------------------------
    Example 5: SavedVariables Integration
----------------------------------------------------------------------]]

-- In your TOC file, add:
-- ## SavedVariables: MyAddonDB, LoolibRecentColors

-- In your addon initialization:
local defaults = {
    profile = {
        textColor = { r = 1, g = 1, b = 1, a = 1 },
    }
}

-- Create picker with recent colors
local textColorPicker = LoolibColorSwatchWithPresets.Create(settingsFrame, {
    r = db.profile.textColor.r,
    g = db.profile.textColor.g,
    b = db.profile.textColor.b,
    a = db.profile.textColor.a,
    hasAlpha = true,
    recentColorsKey = "myAddon_textColors",
    callback = function(r, g, b, a)
        db.profile.textColor.r = r
        db.profile.textColor.g = g
        db.profile.textColor.b = b
        db.profile.textColor.a = a
    end
})

--[[--------------------------------------------------------------------
    Example 6: Building a Color Settings Panel
----------------------------------------------------------------------]]

local function CreateColorSettingsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(300, 400)

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Color Settings")

    -- Background color
    local bgLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bgLabel:SetPoint("TOPLEFT", 10, -40)
    bgLabel:SetText("Background Color:")

    local bgPicker = LoolibColorSwatchWithPresets.Create(panel, {
        hasAlpha = true,
        recentColorsKey = "myAddon_background",
        callback = function(r, g, b, a)
            parent:SetBackdropColor(r, g, b, a)
        end
    })
    bgPicker:SetPoint("TOPLEFT", 10, -60)

    -- Text color
    local textLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textLabel:SetPoint("TOPLEFT", 10, -200)
    textLabel:SetText("Text Color:")

    local textPicker = LoolibColorSwatchWithPresets.Create(panel, {
        hasAlpha = false,
        recentColorsKey = "myAddon_text",
        callback = function(r, g, b, a)
            title:SetTextColor(r, g, b, a)
        end
    })
    textPicker:SetPoint("TOPLEFT", 10, -220)

    return panel
end

--[[--------------------------------------------------------------------
    API Summary
----------------------------------------------------------------------]]

--[[

LoolibColorSwatch.Create(parent, options)
    options = {
        r = 1.0,           -- Initial red (0-1)
        g = 1.0,           -- Initial green (0-1)
        b = 1.0,           -- Initial blue (0-1)
        a = 1.0,           -- Initial alpha (0-1)
        hasAlpha = false,  -- Enable alpha support
        callback = func,   -- Callback function(r, g, b, a)
    }

LoolibColorSwatchWithPresets.Create(parent, options)
    options = {
        r = 1.0,
        g = 1.0,
        b = 1.0,
        a = 1.0,
        hasAlpha = false,
        recentColorsKey = "key",  -- SavedVariables key
        callback = func,
    }

Methods (both widgets):
    :SetColor(r, g, b, a)
    :GetColor() -> r, g, b, a
    :SetHasAlpha(bool)
    :SetCallback(func)
    :RegisterCallback("OnColorChanged", func)

Additional methods (WithPresets only):
    :SetRecentColorsKey(key)
    :ApplyColor(r, g, b, a)
    :ApplyHexColor(hex)

]]
