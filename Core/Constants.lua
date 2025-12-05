--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Library constants and enumerations
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Library Information
----------------------------------------------------------------------]]

LOOLIB_NAME = "Loolib"
LOOLIB_INTERFACE = 120000  -- WoW 12.0

--[[--------------------------------------------------------------------
    Frame Types
----------------------------------------------------------------------]]

LoolibFrameType = {
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

LoolibDrawLayer = {
    Background = "BACKGROUND",
    Border = "BORDER",
    Artwork = "ARTWORK",
    Overlay = "OVERLAY",
    Highlight = "HIGHLIGHT",
}

--[[--------------------------------------------------------------------
    Frame Strata
----------------------------------------------------------------------]]

LoolibFrameStrata = {
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

LoolibAnchorPoint = {
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

LoolibTooltipAnchor = {
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

LoolibLayoutDirection = {
    Vertical = "VERTICAL",
    Horizontal = "HORIZONTAL",
}

LoolibLayoutAlign = {
    Start = "START",
    Center = "CENTER",
    End = "END",
    Stretch = "STRETCH",
}

LoolibLayoutJustify = {
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

LoolibGridDirection = {
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

LoolibSelectionMode = {
    None = "NONE",
    Single = "SINGLE",
    Multiple = "MULTIPLE",
}

--[[--------------------------------------------------------------------
    Tab Positions
----------------------------------------------------------------------]]

LoolibTabPosition = {
    Top = "TOP",
    Bottom = "BOTTOM",
    Left = "LEFT",
    Right = "RIGHT",
}

--[[--------------------------------------------------------------------
    Dialog Button Types
----------------------------------------------------------------------]]

LoolibDialogButtonType = {
    Default = "DEFAULT",
    Danger = "DANGER",
    Success = "SUCCESS",
    Cancel = "CANCEL",
}

--[[--------------------------------------------------------------------
    Standard Backdrops
----------------------------------------------------------------------]]

LoolibBackdrop = {
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

LoolibColor = {
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
    TextHighlight = { r = 1, g = 0.82, b = 0, a = 1 },  -- Gold
    Accent = { r = 0, g = 0.44, b = 0.87, a = 1 },  -- Blue
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

LoolibFont = {
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

LoolibMouseButton = {
    Left = "LeftButton",
    Right = "RightButton",
    Middle = "MiddleButton",
    Button4 = "Button4",
    Button5 = "Button5",
}

--[[--------------------------------------------------------------------
    Event Types (for CallbackRegistry)
----------------------------------------------------------------------]]

LoolibEventType = {
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

function LoolibUnpackColor(color)
    return color.r, color.g, color.b, color.a or 1
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local Constants = {
    FrameType = LoolibFrameType,
    DrawLayer = LoolibDrawLayer,
    FrameStrata = LoolibFrameStrata,
    AnchorPoint = LoolibAnchorPoint,
    TooltipAnchor = LoolibTooltipAnchor,
    LayoutDirection = LoolibLayoutDirection,
    LayoutAlign = LoolibLayoutAlign,
    LayoutJustify = LoolibLayoutJustify,
    GridDirection = LoolibGridDirection,
    SelectionMode = LoolibSelectionMode,
    TabPosition = LoolibTabPosition,
    DialogButtonType = LoolibDialogButtonType,
    Backdrop = LoolibBackdrop,
    Color = LoolibColor,
    Font = LoolibFont,
    MouseButton = LoolibMouseButton,
    EventType = LoolibEventType,
    UnpackColor = LoolibUnpackColor,
}

Loolib:RegisterModule("Constants", Constants)
