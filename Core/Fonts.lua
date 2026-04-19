--[[--------------------------------------------------------------------
    Loolib - Font & icon registry

    Ships Font Awesome 6 Free Solid (subset) at Loolib/Media/Fonts/LoolibIcons.ttf.
    WoW's default fonts have no glyphs for most UI icons (U+F000+ PUA);
    this module exposes the bundled icon font path plus a name-to-UTF-8
    catalog so callers can write `Fonts:Icon("star")` instead of
    juggling raw codepoints.

    The icon font is icons-only: it has NO Latin glyphs. Never swap it
    onto a FontString that also displays text, or the text will render
    as tofu. Use a dedicated FontString for the glyph and anchor it
    next to the text FontString.

    Regeneration: tools/build-icon-font.py reads this file's CODEPOINTS
    table, subsets the upstream Font Awesome 6 Free Solid TTF to the
    listed codepoints, and writes the result to Media/Fonts/.

    Upstream:   https://fontawesome.com
    License:    Media/Fonts/LICENSE.txt (Font Awesome Free — SIL OFL 1.1
                for the font file, MIT for the icons).
----------------------------------------------------------------------]]

local addonName = ...

local Loolib = LibStub("Loolib")
local Fonts = Loolib.Fonts or Loolib:GetOrCreateModule("Fonts")

--[[--------------------------------------------------------------------
    Public API (declared before the heavy data so downstream code that
    runs during later initialization never sees Loolib.Fonts as nil
    even if something in the catalog encoding chokes).
----------------------------------------------------------------------]]

Fonts.Icons      = Fonts.Icons      or ""
Fonts.Glyph      = Fonts.Glyph      or {}
Fonts.Codepoints = Fonts.Codepoints or {}

--- Get the UTF-8 glyph string for an icon name.
-- Must be rendered in a FontString whose font is set to Fonts.Icons.
-- Returns "" for unknown names.
function Fonts:Icon(name)
    return self.Glyph[name] or ""
end

--- Get an icon wrapped in a WoW color escape.
-- @param colorHex 6-char RRGGBB or 8-char AARRGGBB
function Fonts:IconColored(name, colorHex)
    local g = self.Glyph[name] or ""
    if not colorHex then return g end
    if #colorHex == 6 then return "|cff" .. colorHex .. g .. "|r" end
    if #colorHex == 8 then return "|c" .. colorHex .. g .. "|r" end
    return g
end

--- Apply the icon font to an existing FontString.
-- Returns the SetFont success flag so callers can detect a broken TTF path.
function Fonts:SetIconFont(fontString, size, flags)
    if not fontString then return false end
    if self.Icons == "" then return false end
    return fontString:SetFont(self.Icons, size or 12, flags or "") ~= false
end

--- Apply the icon font to the normal FontString of a Button.
-- Returns the SetFont success flag.
function Fonts:ApplyIconFontToButton(button, size, flags)
    if not button then return false end
    if self.Icons == "" then return false end
    local fs = button.GetFontString and button:GetFontString()
    if not fs then return false end
    return fs:SetFont(self.Icons, size or 12, flags or "") ~= false
end

-- Register immediately, before the catalog is populated. If anything
-- below errors, Loolib.Fonts stays a usable (empty) module instead of
-- leaving callers with a nil-index error.
Loolib:RegisterModule("Fonts", Fonts)

-- Two valid layouts:
--   Standalone Loolib addon : Interface\AddOns\Loolib\Media\Fonts\...
--   Embedded via builder.py : Interface\AddOns\<consumer>\Libs\Loolib\Media\Fonts\...
-- Probe via the addon registry so a renamed standalone folder (e.g.
-- "Loolib-2.1.3" from a manual unzip) still resolves to the right path.
local _addonName = tostring(addonName)
local standaloneExists = C_AddOns
    and C_AddOns.DoesAddOnExist
    and C_AddOns.DoesAddOnExist("Loolib")
if standaloneExists then
    Fonts.Icons = "Interface\\AddOns\\Loolib\\Media\\Fonts\\LoolibIcons.ttf"
else
    Fonts.Icons = "Interface\\AddOns\\" .. _addonName .. "\\Libs\\Loolib\\Media\\Fonts\\LoolibIcons.ttf"
end

--[[--------------------------------------------------------------------
    Icon catalog

    Maps a FontAwesome name to its Unicode codepoint. Keep entries
    grouped by purpose so it's easy to scan for an icon to reuse.
    When you add a new entry, re-run tools/build-icon-font.py to
    re-subset LoolibIcons.ttf so the glyph actually ships.

    Browse all icons: https://fontawesome.com/search?o=r&ic=free
----------------------------------------------------------------------]]

local CODEPOINTS = {
    -- Navigation / arrows
    ["chevron-up"]                  = 0xF077,
    ["chevron-down"]                = 0xF078,
    ["chevron-left"]                = 0xF053,
    ["chevron-right"]               = 0xF054,
    ["caret-up"]                    = 0xF0D8,
    ["caret-down"]                  = 0xF0D7,
    ["angles-up"]                   = 0xF102,
    ["angles-down"]                 = 0xF103,
    ["arrow-up"]                    = 0xF062,
    ["arrow-down"]                  = 0xF063,
    ["arrow-left"]                  = 0xF060,
    ["arrow-right"]                 = 0xF061,
    ["arrow-right-arrow-left"]      = 0xF0EC,
    ["arrows-rotate"]               = 0x1F5D8,
    ["arrow-up-short-wide"]         = 0xF885,
    ["arrow-down-wide-short"]       = 0xF160,
    ["sort"]                        = 0xF0DC,

    -- Close / confirm / deny
    ["xmark"]                       = 0x1F5D9,
    ["check"]                       = 0xF00C,
    ["circle-check"]                = 0xF05D,
    ["circle-xmark"]                = 0xF05C,
    ["circle-exclamation"]          = 0xF06A,
    ["circle-info"]                 = 0xF05A,
    ["circle-question"]             = 0xF29C,
    ["triangle-exclamation"]        = 0xF071,
    ["square-check"]                = 0xF14A,
    ["square"]                      = 0xF0C8,
    ["square-xmark"]                = 0xF2D3,
    ["square-plus"]                 = 0xF196,
    ["square-minus"]                = 0xF147,

    -- Actions
    ["plus"]                        = 0xF067,
    ["minus"]                       = 0xF068,
    ["gear"]                        = 0xF013,
    ["sliders"]                     = 0xF1DE,
    ["pen"]                         = 0x1F58A,
    ["pen-to-square"]               = 0xF044,
    ["trash"]                       = 0xF1F8,
    ["trash-can"]                   = 0xF2ED,
    ["copy"]                        = 0xF0C5,
    ["eye"]                         = 0x1F441,
    ["eye-slash"]                   = 0xF070,
    ["lock"]                        = 0x1F512,
    ["unlock"]                      = 0x1F513,
    ["ellipsis"]                    = 0xF141,
    ["ellipsis-vertical"]           = 0xF142,
    ["grip-vertical"]               = 0xF58E,
    ["toggle-on"]                   = 0xF205,
    ["toggle-off"]                  = 0xF204,
    ["bars"]                        = 0xF0C9,

    -- Status / ranking / reward
    ["star"]                        = 0xF006,
    ["trophy"]                      = 0x1F3C6,
    ["crown"]                       = 0x1F451,
    ["medal"]                       = 0x1F3C5,
    ["ranking-star"]                = 0xE561,
    ["thumbs-up"]                   = 0x1F44D,
    ["thumbs-down"]                 = 0x1F44E,
    ["hand"]                        = 0x1F91A,
    ["flag"]                        = 0x1F3F4,
    ["flag-checkered"]              = 0x1F3C1,
    ["thumbtack"]                   = 0x1F588,

    -- Loot / items
    ["sack-dollar"]                 = 0x1F4B0,
    ["coins"]                       = 0xF51E,
    ["gem"]                         = 0x1F48E,
    ["gift"]                        = 0x1F381,
    ["box"]                         = 0x1F4E6,
    ["boxes-stacked"]               = 0xF4A1,
    ["wand-sparkles"]               = 0xF72B,
    ["fire"]                        = 0x1F525,
    ["fire-flame-curved"]           = 0xF7E4,
    ["bolt"]                        = 0xF0E7,
    ["star-of-life"]                = 0xF621,

    -- Combat / class
    ["shield"]                      = 0x1F6E1,
    ["shield-halved"]               = 0xF3ED,
    ["heart"]                       = 0x1F9E1,
    ["hand-fist"]                   = 0xF6DE,
    ["dice"]                        = 0x1F3B2,
    ["dice-six"]                    = 0xF526,
    ["dice-five"]                   = 0xF523,
    ["skull"]                       = 0x1F480,
    ["dragon"]                      = 0x1F409,

    -- Council / voting
    ["gavel"]                       = 0xF0E3,
    ["scale-balanced"]              = 0xF24E,
    ["users"]                       = 0xF0C0,
    ["user"]                        = 0x1F464,
    ["user-group"]                  = 0x1F465,
    ["people-group"]                = 0xE533,
    ["user-plus"]                   = 0xF234,
    ["user-check"]                  = 0xF4FC,
    ["user-xmark"]                  = 0xF235,
    ["handshake"]                   = 0xF2B5,

    -- Labels / organization
    ["tag"]                         = 0x1F3F7,
    ["tags"]                        = 0xF02C,
    ["bookmark"]                    = 0x1F516,
    ["filter"]                      = 0xF0B0,
    ["list"]                        = 0xF03A,
    ["list-check"]                  = 0xF0AE,
    ["list-ul"]                     = 0xF0CA,
    ["magnifying-glass"]            = 0x1F50D,
    ["table"]                       = 0xF0CE,
    ["table-list"]                  = 0xF00B,
    ["table-cells"]                 = 0xF00A,
    ["border-all"]                  = 0xF84C,

    -- Time
    ["clock"]                       = 0x1F553,
    ["clock-rotate-left"]           = 0xF1DA,
    ["hourglass"]                   = 0xF254,
    ["hourglass-half"]              = 0xF252,
    ["calendar"]                    = 0x1F4C6,

    -- Sync / network
    ["wifi"]                        = 0xF1EB,
    ["plug"]                        = 0x1F50C,
    ["plug-circle-check"]           = 0xE55C,
    ["plug-circle-xmark"]           = 0xE560,
    ["cloud-arrow-up"]              = 0xF382,
    ["cloud-arrow-down"]            = 0xF381,
    ["download"]                    = 0xF019,
    ["upload"]                      = 0xF093,
    ["file-export"]                 = 0xF56E,
    ["file-import"]                 = 0xF56F,
    ["share"]                       = 0xF064,
    ["link"]                        = 0x1F517,
    ["link-slash"]                  = 0xF127,

    -- Communication
    ["comment"]                     = 0x1F5E9,
    ["comments"]                    = 0x1F5EA,
    ["comment-dots"]                = 0x1F4AC,
    ["bullhorn"]                    = 0x1F56B,
    ["bell"]                        = 0x1F514,
    ["bell-slash"]                  = 0x1F515,
    ["envelope"]                    = 0x1F582,
    ["message"]                     = 0xF27A,

    -- Progress / loading
    ["circle-notch"]                = 0xF1CE,
    ["spinner"]                     = 0xF110,
    ["play"]                        = 0xF04B,
    ["pause"]                       = 0xF04C,
    ["stop"]                        = 0xF04D,
    ["circle"]                      = 0x1F7E4,

    -- Tools / misc
    ["screwdriver-wrench"]          = 0xF7D9,
    ["xmarks-lines"]                = 0xE59A,
}

Fonts.Codepoints = CODEPOINTS

--[[--------------------------------------------------------------------
    UTF-8 encoding (Lua 5.1 compatible, no utf8 library)

    WoW's Lua is 5.1 which lacks utf8.char. We encode each codepoint
    into its UTF-8 byte sequence once at module load and cache the
    result so callers can concatenate glyphs directly.
----------------------------------------------------------------------]]

local floor = math.floor

local function CodepointToUTF8(cp)
    if cp < 0x80 then
        return string.char(cp)
    elseif cp < 0x800 then
        return string.char(
            0xC0 + floor(cp / 0x40),
            0x80 + (cp % 0x40)
        )
    elseif cp < 0x10000 then
        return string.char(
            0xE0 + floor(cp / 0x1000),
            0x80 + floor((cp % 0x1000) / 0x40),
            0x80 + (cp % 0x40)
        )
    else
        return string.char(
            0xF0 + floor(cp / 0x40000),
            0x80 + floor((cp % 0x40000) / 0x1000),
            0x80 + floor((cp % 0x1000) / 0x40),
            0x80 + (cp % 0x40)
        )
    end
end

local GLYPH = {}
for name, cp in pairs(CODEPOINTS) do
    GLYPH[name] = CodepointToUTF8(cp)
end
Fonts.Glyph = GLYPH
