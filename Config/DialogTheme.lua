--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    DialogTheme - Themable appearance registry for ConfigDialog

    Provides a per-app theme registry so consuming addons can customize
    the visual appearance of ConfigDialog without forking the renderer.

    Resolution order for any theme value:
        app override (Config:RegisterAppTheme)
        -> active global theme (Config:SetActiveDialogTheme)
        -> built-in default theme (the verbatim values from pre-theming
           ConfigDialog so existing consumers see zero visual change)

    Theme tables are sparse: any missing key falls through the chain.
    Only `colors`, `backdrops`, `fonts`, `layout`, `widgetFactories`,
    and `afterCreateWidget` are recognized at the top level.

    Public API (re-exported on Loolib.Config):
        Config:RegisterAppTheme(appName, themeTable)
        Config:RegisterDialogTheme(themeName, themeTable)
        Config:SetActiveDialogTheme(themeName)
        Config:GetDialogTheme(appName)  -- returns fully-resolved theme
----------------------------------------------------------------------]]

local pairs = pairs
local type = type

local Loolib = LibStub("Loolib")
local Config = Loolib:GetOrCreateModule("Config")

local DialogTheme = {}
Config.DialogTheme = DialogTheme

--[[--------------------------------------------------------------------
    Built-in Default Theme

    These values were extracted verbatim from ConfigDialog.lua before the
    refactor. Do NOT change them — they are the regression baseline. If
    a consumer wants a different look, they register an override.
----------------------------------------------------------------------]]

local DEFAULT_THEME = {
    colors = {
        -- Surface fills
        searchBoxBg          = { 0.1,  0.1,  0.1,  0.8  },
        treeContainerBg      = { 0.1,  0.1,  0.1,  0.8  },
        contentContainerBg   = { 0.1,  0.1,  0.1,  0.6  },
        inlineGroupBg        = { 0.08, 0.08, 0.1,  0.7  },
        inputBg              = { 0.1,  0.1,  0.1,  0.8  },
        inputBgDisabled      = { 0.2,  0.2,  0.2,  0.5  },
        dropdownBg           = { 0.15, 0.15, 0.2,  1.0  },
        dropdownBgDisabled   = { 0.2,  0.2,  0.2,  0.5  },
        dropdownMenuBg       = { 0.1,  0.1,  0.15, 1.0  },
        filterButtonBg       = { 0.15, 0.15, 0.2,  1.0  },
        filterMenuBg         = { 0.1,  0.1,  0.15, 1.0  },
        keyButtonBg          = { 0.15, 0.15, 0.2,  1.0  },
        keyButtonBgDisabled  = { 0.2,  0.2,  0.2,  0.5  },
        textureFrameBg       = { 0.1,  0.1,  0.1,  0.8  },

        -- Surface borders
        treeContainerBorder    = { 0.4, 0.4, 0.4, 1.0 },
        contentContainerBorder = { 0.4, 0.4, 0.4, 1.0 },
        inlineGroupBorder      = { 0.6, 0.6, 0.6, 0.9 },

        -- Tree / tab interactive states
        treeHoverBg          = { 0.3,  0.4,  0.6,  0.4 },
        treeSelectionBg      = { 0.15, 0.35, 0.55, 0.9 },
        treeTextSelected     = { 1.0,  1.0,  0.0,  1.0 },
        tabBgActive          = { 0.12, 0.25, 0.45, 1.0 },
        tabBgInactive        = { 0.1,  0.1,  0.14, 1.0 },
        tabActiveAccent      = { 1.0,  0.82, 0.0,  1.0 },
        tabTextActive        = { 1.0,  1.0,  1.0,  1.0 },
        tabTextInactive      = { 0.7,  0.7,  0.7,  1.0 },

        -- Filter / dropdown item highlights
        filterButtonHover    = { 0.3, 0.3, 0.5, 0.3 },
        dropdownItemHover    = { 0.3, 0.3, 0.5, 0.5 },
        dropdownItemSelected = { 1.0, 1.0, 0.0, 1.0 },

        -- Text colors
        headerText           = { 1.0, 0.82, 0.0, 1.0 },
        descriptionText      = { 0.8, 0.8,  0.8, 1.0 },
        labelText            = { 0.9, 0.9,  0.9, 1.0 },
        labelTextDisabled    = { 0.5, 0.5,  0.5, 1.0 },
        noResultsText        = { 0.6, 0.6,  0.6, 1.0 },
        searchIcon           = { 0.6, 0.6,  0.6, 1.0 },

        -- Decorative
        separator            = { 0.5, 0.5, 0.5, 0.5 },
        textureMissing       = { 0.3, 0.3, 0.3, 1.0 },
    },

    backdrops = {
        dialog = {
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        },
        container = {
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        input = {
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        popupMenu = {
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        inlineGroup = {
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        textureFrame = {
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
    },

    fonts = {
        title         = "GameFontNormalLarge",
        groupHeader   = "GameFontNormalLarge",
        label         = "GameFontNormal",
        labelDisabled = "GameFontDisable",
        description   = "GameFontNormalSmall",
        treeNode      = "GameFontNormal",
    },

    layout = {
        dialogWidth    = 750,
        dialogHeight   = 520,
        treeWidth      = 180,
        contentPadding = 12,
        widgetSpacing  = 4,
        labelWidth     = 200,
    },

    -- Optional widget factories. Default theme provides none; the dialog
    -- falls through to its built-in CreateFrame paths.
    widgetFactories = {},

    -- Optional post-create hook. Default is no-op.
    afterCreateWidget = nil,
}

DialogTheme.DEFAULT_THEME = DEFAULT_THEME

--[[--------------------------------------------------------------------
    Registry State
----------------------------------------------------------------------]]

DialogTheme._appThemes = {}      -- appName  -> theme table
DialogTheme._namedThemes = {}    -- themeName -> theme table
DialogTheme._activeName = nil    -- currently active global theme name

--[[--------------------------------------------------------------------
    Resolution

    Merge order, deepest-overrides-shallowest, per category:
        DEFAULT_THEME -> active global theme -> per-app theme

    The result is a fully-populated table; callers can dereference any
    field without worrying about fallbacks.
----------------------------------------------------------------------]]

local function mergeInto(dst, src)
    if type(src) ~= "table" then
        return
    end
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            -- Recurse only one level (colors/backdrops/fonts/layout are
            -- maps of leaf values; backdrop subtables like `insets` are
            -- copied wholesale by the inner type-check below).
            for kk, vv in pairs(v) do
                if type(vv) == "table" and type(dst[k][kk]) == "table" then
                    -- Wholesale replace inner tables (RGBA arrays, insets)
                    dst[k][kk] = vv
                else
                    dst[k][kk] = vv
                end
            end
        else
            dst[k] = v
        end
    end
end

local function deepCopy(src)
    if type(src) ~= "table" then
        return src
    end
    local out = {}
    for k, v in pairs(src) do
        out[k] = deepCopy(v)
    end
    return out
end

--- Resolve a theme for the given appName.
-- Returns a fresh table — callers may mutate without affecting state.
function DialogTheme:Resolve(appName)
    local merged = deepCopy(DEFAULT_THEME)

    -- Layer 2: active global theme
    if self._activeName then
        local globalTheme = self._namedThemes[self._activeName]
        if globalTheme then
            mergeInto(merged, globalTheme)
        end
    end

    -- Layer 3: per-app override
    if appName then
        local appTheme = self._appThemes[appName]
        if appTheme then
            mergeInto(merged, appTheme)
        end
    end

    return merged
end

--- Returns true if any non-default theme is registered for this app.
function DialogTheme:HasOverride(appName)
    if self._activeName and self._namedThemes[self._activeName] then
        return true
    end
    if appName and self._appThemes[appName] then
        return true
    end
    return false
end

--[[--------------------------------------------------------------------
    Mutators

    Each mutator notifies any open dialogs of the affected app so they
    can refresh in place. The notification is best-effort: if Config.Dialog
    isn't loaded yet, we silently skip — the next Open() will pick up the
    new theme via Resolve().
----------------------------------------------------------------------]]

local function NotifyDialogThemeChanged(appName)
    local Dialog = Config.Dialog
    if not Dialog then
        return
    end
    if Dialog.OnThemeChanged then
        Dialog:OnThemeChanged(appName)
    end
end

--- Register a theme for a specific appName. Sparse table: any missing
-- top-level key (colors, backdrops, fonts, layout, widgetFactories,
-- afterCreateWidget) falls back to the active global theme, then default.
-- Pass nil to clear an existing override.
function DialogTheme:RegisterAppTheme(appName, themeTable)
    if type(appName) ~= "string" or appName == "" then
        Loolib:Error("Loolib.Config.DialogTheme:RegisterAppTheme: appName must be a non-empty string")
        return false
    end
    if themeTable ~= nil and type(themeTable) ~= "table" then
        Loolib:Error("Loolib.Config.DialogTheme:RegisterAppTheme: themeTable must be a table or nil")
        return false
    end
    self._appThemes[appName] = themeTable
    NotifyDialogThemeChanged(appName)
    return true
end

--- Register a named global theme. Pass nil for themeTable to delete it.
function DialogTheme:RegisterDialogTheme(themeName, themeTable)
    if type(themeName) ~= "string" or themeName == "" then
        Loolib:Error("Loolib.Config.DialogTheme:RegisterDialogTheme: themeName must be a non-empty string")
        return false
    end
    if themeTable ~= nil and type(themeTable) ~= "table" then
        Loolib:Error("Loolib.Config.DialogTheme:RegisterDialogTheme: themeTable must be a table or nil")
        return false
    end
    self._namedThemes[themeName] = themeTable
    if self._activeName == themeName then
        NotifyDialogThemeChanged(nil)
    end
    return true
end

--- Switch the active global theme. Pass nil to revert to default.
function DialogTheme:SetActiveDialogTheme(themeName)
    if themeName ~= nil and type(themeName) ~= "string" then
        Loolib:Error("Loolib.Config.DialogTheme:SetActiveDialogTheme: themeName must be a string or nil")
        return false
    end
    if themeName ~= nil and not self._namedThemes[themeName] then
        Loolib:Error("Loolib.Config.DialogTheme:SetActiveDialogTheme: unknown theme '" .. themeName .. "'")
        return false
    end
    self._activeName = themeName
    NotifyDialogThemeChanged(nil)
    return true
end

function DialogTheme:GetActiveDialogTheme()
    return self._activeName
end

return DialogTheme
