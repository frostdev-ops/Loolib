local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Library constants and enumerations
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
    Library Information
----------------------------------------------------------------------]]

Loolib.NAME = "Loolib"
Loolib.INTERFACE = 120000 -- WoW 12.0

Loolib.Enum = Loolib.Enum or {}
local Enum = Loolib.Enum

--[[--------------------------------------------------------------------
    Frame Types
----------------------------------------------------------------------]]

Loolib.Enum.FrameType = {
    Frame = "Frame",
    Button = "Button",
    CheckButton = "CheckButton",
    EditBox = "EditBox",
    ScrollFrame = "ScrollFrame",
    Slider = "Slider",
    StatusBar = "StatusBar",
    Cooldown = "Cooldown",
    ColorSelect = "ColorSelect",
    GameTooltip = "GameTooltip",
    MessageFrame = "MessageFrame",
    Model = "Model",
    MovieFrame = "MovieFrame",
    SimpleHTML = "SimpleHTML",
}

--[[--------------------------------------------------------------------
    Draw Layers
----------------------------------------------------------------------]]

Loolib.Enum.DrawLayer = {
    Background = "BACKGROUND",
    Border = "BORDER",
    Artwork = "ARTWORK",
    Overlay = "OVERLAY",
    Highlight = "HIGHLIGHT",
}

--[[--------------------------------------------------------------------
    Frame Strata
----------------------------------------------------------------------]]

Loolib.Enum.FrameStrata = {
    World = "WORLD",
    Background = "BACKGROUND",
    Low = "LOW",
    Medium = "MEDIUM",
    High = "HIGH",
    Dialog = "DIALOG",
    Fullscreen = "FULLSCREEN",
    FullscreenDialog = "FULLSCREEN_DIALOG",
    Tooltip = "TOOLTIP",
}

--[[--------------------------------------------------------------------
    Anchor Points
----------------------------------------------------------------------]]

Loolib.Enum.AnchorPoint = {
    TopLeft = "TOPLEFT",
    Top = "TOP",
    TopRight = "TOPRIGHT",
    Left = "LEFT",
    Center = "CENTER",
    Right = "RIGHT",
    BottomLeft = "BOTTOMLEFT",
    Bottom = "BOTTOM",
    BottomRight = "BOTTOMRIGHT",
}

--[[--------------------------------------------------------------------
    Tooltip Anchors
----------------------------------------------------------------------]]

Loolib.Enum.TooltipAnchor = {
    Top = "ANCHOR_TOP",
    Bottom = "ANCHOR_BOTTOM",
    Left = "ANCHOR_LEFT",
    Right = "ANCHOR_RIGHT",
    TopLeft = "ANCHOR_TOPLEFT",
    TopRight = "ANCHOR_TOPRIGHT",
    BottomLeft = "ANCHOR_BOTTOMLEFT",
    BottomRight = "ANCHOR_BOTTOMRIGHT",
    Cursor = "ANCHOR_CURSOR",
    Preserve = "ANCHOR_PRESERVE",
    None = "ANCHOR_NONE",
}

--[[--------------------------------------------------------------------
    Layout Directions
----------------------------------------------------------------------]]

Loolib.Enum.LayoutDirection = {
    Vertical = "VERTICAL",
    Horizontal = "HORIZONTAL",
}

Loolib.Enum.LayoutAlign = {
    Start = "START",
    Center = "CENTER",
    End = "END",
    Stretch = "STRETCH",
}

Loolib.Enum.LayoutJustify = {
    Start = "START",
    Center = "CENTER",
    End = "END",
    SpaceBetween = "SPACE_BETWEEN",
    SpaceAround = "SPACE_AROUND",
    SpaceEvenly = "SPACE_EVENLY",
}

--[[--------------------------------------------------------------------
    Grid Layout Directions
----------------------------------------------------------------------]]

Loolib.Enum.GridDirection = {
    TopLeftToBottomRight = 1,
    TopRightToBottomLeft = 2,
    BottomLeftToTopRight = 3,
    BottomRightToTopLeft = 4,
    TopLeftToBottomRightVertical = 5,
    TopRightToBottomLeftVertical = 6,
    BottomLeftToTopRightVertical = 7,
    BottomRightToTopLeftVertical = 8,
}

--[[--------------------------------------------------------------------
    Selection Modes
----------------------------------------------------------------------]]

Loolib.Enum.SelectionMode = {
    None = "NONE",
    Single = "SINGLE",
    Multiple = "MULTIPLE",
}

--[[--------------------------------------------------------------------
    Tab Positions
----------------------------------------------------------------------]]

Loolib.Enum.TabPosition = {
    Top = "TOP",
    Bottom = "BOTTOM",
    Left = "LEFT",
    Right = "RIGHT",
}

--[[--------------------------------------------------------------------
    Dialog Button Types
----------------------------------------------------------------------]]

Loolib.Enum.DialogButtonType = {
    Default = "DEFAULT",
    Danger = "DANGER",
    Success = "SUCCESS",
    Cancel = "CANCEL",
}

--[[--------------------------------------------------------------------
    Standard Backdrops
----------------------------------------------------------------------]]

Loolib.Enum.Backdrop = {
    Panel = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    },
    Tooltip = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    },
    Transparent = {
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    },
    None = nil,
}

--[[--------------------------------------------------------------------
    Standard Colors
----------------------------------------------------------------------]]

Loolib.Enum.Color = {
    White = { r = 1, g = 1, b = 1, a = 1 },
    Black = { r = 0, g = 0, b = 0, a = 1 },
    Red = { r = 1, g = 0.2, b = 0.2, a = 1 },
    Green = { r = 0.2, g = 1, b = 0.2, a = 1 },
    Blue = { r = 0.2, g = 0.4, b = 1, a = 1 },
    Yellow = { r = 1, g = 1, b = 0, a = 1 },
    Orange = { r = 1, g = 0.5, b = 0, a = 1 },
    Purple = { r = 0.6, g = 0.2, b = 0.8, a = 1 },
    Cyan = { r = 0, g = 0.8, b = 0.8, a = 1 },
    Gray = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
    LightGray = { r = 0.75, g = 0.75, b = 0.75, a = 1 },
    DarkGray = { r = 0.25, g = 0.25, b = 0.25, a = 1 },

    -- Semantic colors
    Text = { r = 1, g = 1, b = 1, a = 1 },
    TextDisabled = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
    TextHighlight = { r = 1, g = 0.82, b = 0, a = 1 },
    Accent = { r = 0, g = 0.44, b = 0.87, a = 1 },
    Danger = { r = 0.8, g = 0.2, b = 0.2, a = 1 },
    Success = { r = 0.2, g = 0.8, b = 0.2, a = 1 },
    Warning = { r = 1, g = 0.5, b = 0, a = 1 },

    -- UI colors
    Background = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 },
    BackgroundAlt = { r = 0.15, g = 0.15, b = 0.15, a = 0.9 },
    Border = { r = 0.4, g = 0.4, b = 0.4, a = 1 },
}

--[[--------------------------------------------------------------------
    Font Objects
----------------------------------------------------------------------]]

Loolib.Enum.Font = {
    Title = "GameFontNormalLarge",
    Header = "GameFontNormal",
    Body = "GameFontHighlight",
    Small = "GameFontNormalSmall",
    Disabled = "GameFontDisable",
    White = "GameFontWhite",
    Highlight = "GameFontHighlight",
}

--[[--------------------------------------------------------------------
    Mouse Buttons
----------------------------------------------------------------------]]

Loolib.Enum.MouseButton = {
    Left = "LeftButton",
    Right = "RightButton",
    Middle = "MiddleButton",
    Button4 = "Button4",
    Button5 = "Button5",
}

--[[--------------------------------------------------------------------
    Event Types (for CallbackRegistry)
----------------------------------------------------------------------]]

Loolib.Enum.EventType = {
    -- Lifecycle
    OnLoad = "OnLoad",
    OnShow = "OnShow",
    OnHide = "OnHide",

    -- Data
    OnDataChanged = "OnDataChanged",
    OnSizeChanged = "OnSizeChanged",
    OnInsert = "OnInsert",
    OnRemove = "OnRemove",
    OnSort = "OnSort",

    -- Selection
    OnSelect = "OnSelect",
    OnDeselect = "OnDeselect",
    OnSelectionChanged = "OnSelectionChanged",

    -- UI
    OnClick = "OnClick",
    OnDoubleClick = "OnDoubleClick",
    OnValueChanged = "OnValueChanged",
    OnTextChanged = "OnTextChanged",
    OnEnter = "OnEnter",
    OnLeave = "OnLeave",

    -- Scroll
    OnScroll = "OnScroll",
    OnScrollRangeChanged = "OnScrollRangeChanged",

    -- Layout
    OnLayout = "OnLayout",
    OnChildAdded = "OnChildAdded",
    OnChildRemoved = "OnChildRemoved",
}

--[[--------------------------------------------------------------------
    Utility: Unpack color table to r, g, b, a
----------------------------------------------------------------------]]

function Enum.UnpackColor(color)
    return color.r, color.g, color.b, color.a or 1
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib.Enum = Enum

Loolib:RegisterModule("Core.Constants", Enum)
