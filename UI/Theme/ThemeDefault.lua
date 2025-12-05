--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ThemeDefault - Default Blizzard-style theme

    A theme that matches Blizzard's standard UI appearance.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Standard Backdrops
----------------------------------------------------------------------]]

LoolibBackdrop = LoolibBackdrop or {}

-- Standard dialog backdrop (32x32 tiles)
LoolibBackdrop.Dialog = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- Tooltip backdrop (16x16 tiles)
LoolibBackdrop.Tooltip = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

-- Simple panel backdrop
LoolibBackdrop.Panel = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- Flat backdrop (no texture, just solid color)
LoolibBackdrop.Flat = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

-- Transparent with border
LoolibBackdrop.TransparentBorder = {
    bgFile = nil,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

--[[--------------------------------------------------------------------
    Default Theme Definition
----------------------------------------------------------------------]]

LoolibThemeDefault = {
    name = "Default",
    description = "Standard Blizzard-style theme",

    --[[----------------------------------------------------------------
        Colors
    ------------------------------------------------------------------]]
    colors = {
        -- Backgrounds
        background = {0.09, 0.09, 0.09, 0.9},
        backgroundAlt = {0.12, 0.12, 0.12, 0.95},
        backgroundLight = {0.15, 0.15, 0.15, 0.9},
        backgroundDark = {0.05, 0.05, 0.05, 0.95},

        -- Borders
        border = {0.4, 0.4, 0.4, 1},
        borderLight = {0.6, 0.6, 0.6, 1},
        borderDark = {0.2, 0.2, 0.2, 1},
        borderHighlight = {1, 0.82, 0, 1},  -- Gold

        -- Text
        text = {1, 1, 1, 1},
        textSecondary = {0.8, 0.8, 0.8, 1},
        textMuted = {0.5, 0.5, 0.5, 1},
        textDisabled = {0.4, 0.4, 0.4, 1},
        textHighlight = {1, 0.82, 0, 1},  -- Gold
        textLink = {0.25, 0.78, 0.92, 1},  -- Cyan

        -- Accent colors
        accent = {0.0, 0.44, 0.87, 1},  -- Blue
        accentHover = {0.1, 0.54, 0.97, 1},
        accentPressed = {0.0, 0.34, 0.77, 1},

        -- Semantic colors
        success = {0.1, 0.8, 0.1, 1},  -- Green
        warning = {1, 0.82, 0, 1},  -- Gold/Yellow
        danger = {0.9, 0.2, 0.2, 1},  -- Red
        info = {0.25, 0.78, 0.92, 1},  -- Cyan

        -- Interactive states
        hover = {0.2, 0.2, 0.2, 0.9},
        pressed = {0.1, 0.1, 0.1, 0.9},
        selected = {0.2, 0.4, 0.6, 0.9},
        disabled = {0.15, 0.15, 0.15, 0.7},

        -- Button colors
        buttonNormal = {0.15, 0.15, 0.15, 0.9},
        buttonHover = {0.25, 0.25, 0.25, 0.9},
        buttonPressed = {0.1, 0.1, 0.1, 0.9},
        buttonDisabled = {0.12, 0.12, 0.12, 0.5},

        -- Class colors (for reference)
        classWarrior = {0.78, 0.61, 0.43, 1},
        classPaladin = {0.96, 0.55, 0.73, 1},
        classHunter = {0.67, 0.83, 0.45, 1},
        classRogue = {1, 0.96, 0.41, 1},
        classPriest = {1, 1, 1, 1},
        classDeathKnight = {0.77, 0.12, 0.23, 1},
        classShaman = {0, 0.44, 0.87, 1},
        classMage = {0.41, 0.8, 0.94, 1},
        classWarlock = {0.58, 0.51, 0.79, 1},
        classMonk = {0, 1, 0.59, 1},
        classDruid = {1, 0.49, 0.04, 1},
        classDemonHunter = {0.64, 0.19, 0.79, 1},
        classEvoker = {0.2, 0.58, 0.5, 1},

        -- Quality colors
        qualityPoor = {0.62, 0.62, 0.62, 1},
        qualityCommon = {1, 1, 1, 1},
        qualityUncommon = {0.12, 1, 0, 1},
        qualityRare = {0, 0.44, 0.87, 1},
        qualityEpic = {0.64, 0.21, 0.93, 1},
        qualityLegendary = {1, 0.5, 0, 1},
        qualityArtifact = {0.9, 0.8, 0.5, 1},
        qualityHeirloom = {0, 0.8, 1, 1},
    },

    --[[----------------------------------------------------------------
        Backdrops
    ------------------------------------------------------------------]]
    backdrops = {
        dialog = LoolibBackdrop.Dialog,
        tooltip = LoolibBackdrop.Tooltip,
        panel = LoolibBackdrop.Panel,
        flat = LoolibBackdrop.Flat,
        border = LoolibBackdrop.TransparentBorder,
    },

    --[[----------------------------------------------------------------
        Fonts
    ------------------------------------------------------------------]]
    fonts = {
        title = "GameFontNormalLarge",
        titleHuge = "GameFontNormalHuge",
        header = "GameFontNormal",
        body = "GameFontNormal",
        bodySmall = "GameFontNormalSmall",
        highlight = "GameFontHighlight",
        highlightSmall = "GameFontHighlightSmall",
        disabled = "GameFontDisable",
        white = "GameFontWhite",
        number = "NumberFontNormal",
        numberLarge = "NumberFontNormalLarge",
    },

    --[[----------------------------------------------------------------
        Spacing
    ------------------------------------------------------------------]]
    spacing = {
        none = 0,
        tiny = 2,
        small = 4,
        medium = 8,
        large = 12,
        xlarge = 16,
        xxlarge = 24,
        huge = 32,
    },

    --[[----------------------------------------------------------------
        Component Configurations
    ------------------------------------------------------------------]]
    components = {
        -- Button
        Button = {
            height = 22,
            minWidth = 80,
            padding = 10,
            bgColor = "buttonNormal",
            borderColor = "border",
            textColor = "text",
            font = "GameFontNormal",
        },

        -- EditBox
        EditBox = {
            height = 24,
            padding = 5,
            backdrop = "flat",
            bgColor = "backgroundDark",
            borderColor = "border",
            textColor = "text",
            font = "GameFontWhite",
        },

        -- Slider
        Slider = {
            height = 20,
            thumbSize = 16,
            trackHeight = 8,
            bgColor = "backgroundDark",
            trackColor = "backgroundLight",
            thumbColor = "accent",
        },

        -- CheckButton
        CheckButton = {
            size = 24,
            spacing = 4,
            textColor = "text",
            font = "GameFontNormal",
        },

        -- Tab
        Tab = {
            height = 28,
            minWidth = 60,
            spacing = 2,
            padding = 12,
            font = "GameFontNormal",
            bgColor = "buttonNormal",
            activeColor = "selected",
        },

        -- ListItem
        ListItem = {
            height = 24,
            padding = 8,
            bgColor = "background",
            hoverColor = "hover",
            selectedColor = "selected",
            textColor = "text",
        },

        -- Panel
        Panel = {
            backdrop = "panel",
            bgColor = "background",
            borderColor = "border",
            titleFont = "GameFontNormalLarge",
            padding = 12,
        },

        -- Tooltip
        Tooltip = {
            backdrop = "tooltip",
            bgColor = "backgroundDark",
            borderColor = "border",
            titleFont = "GameFontNormal",
            textFont = "GameFontNormalSmall",
            padding = 8,
        },

        -- Dialog
        Dialog = {
            backdrop = "dialog",
            bgColor = "background",
            borderColor = "border",
            titleFont = "GameFontNormalLarge",
            padding = 16,
            buttonSpacing = 8,
        },

        -- Dropdown
        Dropdown = {
            height = 24,
            minWidth = 120,
            padding = 8,
            backdrop = "flat",
            bgColor = "buttonNormal",
            borderColor = "border",
            textColor = "text",
        },

        -- ScrollBar
        ScrollBar = {
            width = 16,
            thumbMinHeight = 24,
            bgColor = "backgroundDark",
            thumbColor = "buttonNormal",
            thumbHoverColor = "buttonHover",
        },

        -- StatusBar
        StatusBar = {
            height = 20,
            bgColor = "backgroundDark",
            fillColor = "accent",
            borderColor = "border",
        },
    },

    --[[----------------------------------------------------------------
        Textures
    ------------------------------------------------------------------]]
    textures = {
        checkmark = "Interface\\Buttons\\UI-CheckBox-Check",
        checkmarkDisabled = "Interface\\Buttons\\UI-CheckBox-Check-Disabled",
        radioButton = "Interface\\Buttons\\UI-RadioButton",
        arrowDown = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up",
        arrowUp = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up",
        arrowLeft = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up",
        arrowRight = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
        close = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
        minimize = "Interface\\Buttons\\UI-Panel-CollapseButton-Up",
        resize = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
    },

    --[[----------------------------------------------------------------
        Animations
    ------------------------------------------------------------------]]
    animations = {
        fadeDuration = 0.2,
        slideDuration = 0.3,
        scaleDuration = 0.15,
    },
}

--[[--------------------------------------------------------------------
    Register the Default Theme
----------------------------------------------------------------------]]

LoolibThemeManager:RegisterTheme("Default", LoolibThemeDefault)

-- Set as active theme
LoolibThemeManager:SetActiveTheme("Default")
