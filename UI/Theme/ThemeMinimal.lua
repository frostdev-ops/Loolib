--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ThemeMinimal - Minimal/flat theme variant

    A clean, modern flat design with minimal decoration.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Minimal Backdrop
    Ultra-thin borders, no decorative elements
----------------------------------------------------------------------]]

LoolibBackdrop.Minimal = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

LoolibBackdrop.MinimalThick = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = 2,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

--[[--------------------------------------------------------------------
    Minimal Theme Definition

    Clean, flat design with sharp edges and minimal decoration.
----------------------------------------------------------------------]]

LoolibThemeMinimal = {
    name = "Minimal",
    description = "Clean, flat modern design",

    --[[----------------------------------------------------------------
        Colors - High contrast, flat colors
    ------------------------------------------------------------------]]
    colors = {
        -- Backgrounds - Clean grays
        background = {0.12, 0.12, 0.12, 0.95},
        backgroundAlt = {0.15, 0.15, 0.15, 0.95},
        backgroundLight = {0.18, 0.18, 0.18, 0.95},
        backgroundDark = {0.08, 0.08, 0.08, 0.98},

        -- Borders - Very subtle
        border = {0.25, 0.25, 0.25, 1},
        borderLight = {0.35, 0.35, 0.35, 1},
        borderDark = {0.15, 0.15, 0.15, 1},
        borderHighlight = {0.4, 0.7, 1, 1},  -- Bright blue

        -- Text - High contrast
        text = {1, 1, 1, 1},
        textSecondary = {0.75, 0.75, 0.75, 1},
        textMuted = {0.5, 0.5, 0.5, 1},
        textDisabled = {0.35, 0.35, 0.35, 1},
        textHighlight = {0.4, 0.7, 1, 1},  -- Bright blue
        textLink = {0.4, 0.7, 1, 1},

        -- Accent colors - Vibrant blue
        accent = {0.2, 0.5, 0.9, 1},
        accentHover = {0.3, 0.6, 1, 1},
        accentPressed = {0.15, 0.4, 0.8, 1},

        -- Semantic colors - Flat, modern
        success = {0.2, 0.75, 0.4, 1},
        warning = {0.95, 0.7, 0.2, 1},
        danger = {0.9, 0.3, 0.3, 1},
        info = {0.4, 0.7, 1, 1},

        -- Interactive states
        hover = {0.2, 0.2, 0.2, 0.9},
        pressed = {0.08, 0.08, 0.08, 0.95},
        selected = {0.2, 0.5, 0.9, 0.3},
        disabled = {0.1, 0.1, 0.1, 0.5},

        -- Button colors
        buttonNormal = {0.18, 0.18, 0.18, 1},
        buttonHover = {0.25, 0.25, 0.25, 1},
        buttonPressed = {0.12, 0.12, 0.12, 1},
        buttonDisabled = {0.15, 0.15, 0.15, 0.5},

        -- Primary button (accent-colored)
        buttonPrimary = {0.2, 0.5, 0.9, 1},
        buttonPrimaryHover = {0.3, 0.6, 1, 1},
        buttonPrimaryPressed = {0.15, 0.4, 0.8, 1},

        -- Class colors - Same as default
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
        Backdrops - Minimal flat backdrops
    ------------------------------------------------------------------]]
    backdrops = {
        dialog = LoolibBackdrop.Minimal,
        tooltip = LoolibBackdrop.Minimal,
        panel = LoolibBackdrop.Minimal,
        flat = LoolibBackdrop.Minimal,
        border = LoolibBackdrop.Minimal,
        thick = LoolibBackdrop.MinimalThick,
    },

    --[[----------------------------------------------------------------
        Fonts - Same as default
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
        Spacing - Slightly increased for cleaner look
    ------------------------------------------------------------------]]
    spacing = {
        none = 0,
        tiny = 2,
        small = 6,
        medium = 10,
        large = 14,
        xlarge = 20,
        xxlarge = 28,
        huge = 40,
    },

    --[[----------------------------------------------------------------
        Component Configurations - Clean, flat styling
    ------------------------------------------------------------------]]
    components = {
        Button = {
            height = 28,  -- Taller
            minWidth = 80,
            padding = 14,
            backdrop = "flat",
            bgColor = "buttonNormal",
            borderColor = "border",
            textColor = "text",
            font = "GameFontNormal",
            cornerRadius = 0,  -- Sharp corners (for custom rendering)
        },

        EditBox = {
            height = 28,
            padding = 8,
            backdrop = "flat",
            bgColor = "backgroundDark",
            borderColor = "border",
            textColor = "text",
            font = "GameFontWhite",
        },

        Slider = {
            height = 24,
            thumbSize = 14,
            trackHeight = 4,  -- Thin track
            bgColor = "backgroundDark",
            trackColor = "border",
            thumbColor = "accent",
        },

        CheckButton = {
            size = 20,  -- Slightly smaller
            spacing = 8,
            textColor = "text",
            font = "GameFontNormal",
        },

        Tab = {
            height = 32,
            minWidth = 80,
            spacing = 0,  -- No gaps
            padding = 16,
            font = "GameFontNormal",
            bgColor = "backgroundLight",
            activeColor = "accent",
            indicatorHeight = 2,  -- Bottom indicator line
        },

        ListItem = {
            height = 32,
            padding = 12,
            bgColor = "background",
            hoverColor = "hover",
            selectedColor = "selected",
            textColor = "text",
        },

        Panel = {
            backdrop = "flat",
            bgColor = "background",
            borderColor = "border",
            titleFont = "GameFontNormalLarge",
            padding = 16,
        },

        Tooltip = {
            backdrop = "flat",
            bgColor = "backgroundDark",
            borderColor = "border",
            titleFont = "GameFontNormal",
            textFont = "GameFontNormalSmall",
            padding = 10,
        },

        Dialog = {
            backdrop = "flat",
            bgColor = "background",
            borderColor = "border",
            titleFont = "GameFontNormalLarge",
            padding = 20,
            buttonSpacing = 10,
        },

        Dropdown = {
            height = 28,
            minWidth = 140,
            padding = 10,
            backdrop = "flat",
            bgColor = "buttonNormal",
            borderColor = "border",
            textColor = "text",
        },

        ScrollBar = {
            width = 8,  -- Very thin
            thumbMinHeight = 30,
            bgColor = "backgroundDark",
            thumbColor = "border",
            thumbHoverColor = "borderLight",
        },

        StatusBar = {
            height = 6,  -- Thin
            bgColor = "backgroundDark",
            fillColor = "accent",
            borderColor = "border",
        },

        -- Additional minimal-specific components
        Card = {
            backdrop = "flat",
            bgColor = "backgroundAlt",
            borderColor = "border",
            padding = 16,
            shadowOffset = 0,  -- No shadow
        },

        Divider = {
            height = 1,
            color = "border",
        },

        Badge = {
            height = 20,
            minWidth = 20,
            padding = 6,
            bgColor = "accent",
            textColor = "text",
            font = "GameFontNormalSmall",
        },
    },

    --[[----------------------------------------------------------------
        Textures - Minimal uses fewer textures
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
        Animations - Snappy, quick animations
    ------------------------------------------------------------------]]
    animations = {
        fadeDuration = 0.15,
        slideDuration = 0.2,
        scaleDuration = 0.1,
    },
}

--[[--------------------------------------------------------------------
    Register the Minimal Theme
----------------------------------------------------------------------]]

LoolibThemeManager:RegisterTheme("Minimal", LoolibThemeMinimal)
