--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ThemeDark - Dark theme variant

    A darker, more subdued theme for users who prefer less contrast.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Dark Theme Definition

    Inherits most values from Default, overrides colors and some settings.
----------------------------------------------------------------------]]

LoolibThemeDark = {
    name = "Dark",
    description = "Darker, low-contrast theme",

    --[[----------------------------------------------------------------
        Colors - Darker variants with lower contrast
    ------------------------------------------------------------------]]
    colors = {
        -- Backgrounds - Much darker
        background = {0.04, 0.04, 0.05, 0.95},
        backgroundAlt = {0.06, 0.06, 0.07, 0.95},
        backgroundLight = {0.08, 0.08, 0.09, 0.95},
        backgroundDark = {0.02, 0.02, 0.02, 0.98},

        -- Borders - Subtle
        border = {0.2, 0.2, 0.22, 1},
        borderLight = {0.3, 0.3, 0.32, 1},
        borderDark = {0.1, 0.1, 0.1, 1},
        borderHighlight = {0.6, 0.5, 0.2, 1},  -- Muted gold

        -- Text - Slightly dimmed to reduce eye strain
        text = {0.9, 0.9, 0.9, 1},
        textSecondary = {0.7, 0.7, 0.7, 1},
        textMuted = {0.45, 0.45, 0.45, 1},
        textDisabled = {0.35, 0.35, 0.35, 1},
        textHighlight = {0.8, 0.65, 0.2, 1},  -- Muted gold
        textLink = {0.3, 0.6, 0.8, 1},  -- Muted cyan

        -- Accent colors - Deeper, less saturated
        accent = {0.15, 0.35, 0.6, 1},  -- Deep blue
        accentHover = {0.2, 0.4, 0.65, 1},
        accentPressed = {0.1, 0.3, 0.55, 1},

        -- Semantic colors - Muted versions
        success = {0.15, 0.5, 0.15, 1},
        warning = {0.7, 0.55, 0.15, 1},
        danger = {0.6, 0.2, 0.2, 1},
        info = {0.25, 0.5, 0.65, 1},

        -- Interactive states
        hover = {0.1, 0.1, 0.12, 0.9},
        pressed = {0.05, 0.05, 0.06, 0.95},
        selected = {0.15, 0.25, 0.4, 0.9},
        disabled = {0.08, 0.08, 0.08, 0.7},

        -- Button colors
        buttonNormal = {0.08, 0.08, 0.09, 0.9},
        buttonHover = {0.12, 0.12, 0.14, 0.9},
        buttonPressed = {0.05, 0.05, 0.06, 0.95},
        buttonDisabled = {0.06, 0.06, 0.06, 0.5},

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

        -- Quality colors - Same as default
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
        Backdrops - Use flat for cleaner dark look
    ------------------------------------------------------------------]]
    backdrops = {
        dialog = LoolibBackdrop.Flat,
        tooltip = LoolibBackdrop.Flat,
        panel = LoolibBackdrop.Flat,
        flat = LoolibBackdrop.Flat,
        border = LoolibBackdrop.TransparentBorder,
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
        Spacing - Same as default
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
        Button = {
            height = 22,
            minWidth = 80,
            padding = 10,
            bgColor = "buttonNormal",
            borderColor = "border",
            textColor = "text",
            font = "GameFontNormal",
        },

        EditBox = {
            height = 24,
            padding = 5,
            backdrop = "flat",
            bgColor = "backgroundDark",
            borderColor = "border",
            textColor = "text",
            font = "GameFontWhite",
        },

        Slider = {
            height = 20,
            thumbSize = 16,
            trackHeight = 8,
            bgColor = "backgroundDark",
            trackColor = "backgroundLight",
            thumbColor = "accent",
        },

        CheckButton = {
            size = 24,
            spacing = 4,
            textColor = "text",
            font = "GameFontNormal",
        },

        Tab = {
            height = 28,
            minWidth = 60,
            spacing = 2,
            padding = 12,
            font = "GameFontNormal",
            bgColor = "buttonNormal",
            activeColor = "selected",
        },

        ListItem = {
            height = 24,
            padding = 8,
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
            padding = 12,
        },

        Tooltip = {
            backdrop = "flat",
            bgColor = "backgroundDark",
            borderColor = "border",
            titleFont = "GameFontNormal",
            textFont = "GameFontNormalSmall",
            padding = 8,
        },

        Dialog = {
            backdrop = "flat",
            bgColor = "background",
            borderColor = "border",
            titleFont = "GameFontNormalLarge",
            padding = 16,
            buttonSpacing = 8,
        },

        Dropdown = {
            height = 24,
            minWidth = 120,
            padding = 8,
            backdrop = "flat",
            bgColor = "buttonNormal",
            borderColor = "border",
            textColor = "text",
        },

        ScrollBar = {
            width = 14,  -- Slightly thinner
            thumbMinHeight = 24,
            bgColor = "backgroundDark",
            thumbColor = "buttonNormal",
            thumbHoverColor = "buttonHover",
        },

        StatusBar = {
            height = 20,
            bgColor = "backgroundDark",
            fillColor = "accent",
            borderColor = "border",
        },
    },

    --[[----------------------------------------------------------------
        Textures - Same as default
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
        Animations - Slightly slower for smoother feel
    ------------------------------------------------------------------]]
    animations = {
        fadeDuration = 0.25,
        slideDuration = 0.35,
        scaleDuration = 0.2,
    },
}

--[[--------------------------------------------------------------------
    Register the Dark Theme
----------------------------------------------------------------------]]

LoolibThemeManager:RegisterTheme("Dark", LoolibThemeDark)
