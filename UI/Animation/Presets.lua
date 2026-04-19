--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Animation Presets - Common recipes built on AnimationUtil

    Provides turnkey helpers for the patterns most polished addons repeat:
    fade-in/out, slide-in, staggered fades for list reveals, hover
    crossfades, and attention flashes.

    Dependencies (must be loaded before this file):
    - Core/Loolib.lua
    - UI/Animation/Easing.lua
    - UI/Animation/AnimationUtil.lua
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local AnimationUtil = assert(Loolib.AnimationUtil, "Loolib.AnimationUtil is required for Animation.Presets")
local Animation = Loolib.Animation or Loolib:GetOrCreateModule("Animation")
local Presets = Animation.Presets or Loolib:GetModule("Animation.Presets") or {}

local type = type
local ipairs = ipairs

--- Fade a frame in from 0 to 1.
-- @param frame Frame
-- @param duration number|nil (default 0.2)
-- @param easing string|nil (default "outCubic")
-- @param onFinished function|nil
-- @return group
function Presets.FadeIn(frame, duration, easing, onFinished)
    local group = AnimationUtil.CreateGroup(frame)
    if type(frame) == "table" and type(frame.Show) == "function" then frame:Show() end
    if type(frame) == "table" and type(frame.SetAlpha) == "function" then frame:SetAlpha(0) end
    group:CreateAnimation("fade", {
        target = frame,
        from = 0,
        to = 1,
        duration = duration or 0.2,
        easing = easing or "outCubic",
        onFinished = onFinished,
    })
    group:Play()
    return group
end

--- Fade a frame out from its current alpha to 0, optionally hiding on completion.
-- @param frame Frame
-- @param duration number|nil
-- @param easing string|nil
-- @param hideOnFinish boolean|nil
-- @param onFinished function|nil
-- @return group
function Presets.FadeOut(frame, duration, easing, hideOnFinish, onFinished)
    local group = AnimationUtil.CreateGroup(frame)
    local from = (type(frame) == "table" and type(frame.GetAlpha) == "function") and frame:GetAlpha() or 1
    group:CreateAnimation("fade", {
        target = frame,
        from = from,
        to = 0,
        duration = duration or 0.2,
        easing = easing or "inCubic",
        onFinished = function(anim)
            if hideOnFinish and type(frame) == "table" and type(frame.Hide) == "function" then
                frame:Hide()
            end
            if onFinished then onFinished(anim) end
        end,
    })
    group:Play()
    return group
end

--- Slide a frame from an offset (relative to its current anchor) to its anchored position while fading in.
-- @param frame Frame
-- @param fromOffset table { dx, dy } (default { 0, -20 })
-- @param duration number|nil
-- @param easing string|nil
-- @return group
function Presets.SlideIn(frame, fromOffset, duration, easing)
    local group = AnimationUtil.CreateGroup(frame)
    local offset = fromOffset or { 0, -20 }
    local dur = duration or 0.28
    local ease = easing or "outCubic"

    if type(frame) == "table" and type(frame.SetAlpha) == "function" then frame:SetAlpha(0) end
    if type(frame) == "table" and type(frame.Show) == "function" then frame:Show() end

    group:CreateAnimation("move", {
        target = frame,
        from = offset,
        to = { 0, 0 },
        duration = dur,
        easing = ease,
    })
    group:CreateAnimation("fade", {
        target = frame,
        from = 0,
        to = 1,
        duration = dur,
        easing = ease,
    })
    group:Play()
    return group
end

--- Fade a sequence of frames in with a delay between each.
-- Classic ToxiUI landing-page pattern: title, subtitle, body, staggered.
-- @param frames table of Frame
-- @param perItemDelay number|nil (default 0.06)
-- @param duration number|nil (default 0.22)
-- @param easing string|nil (default "outCubic")
-- @return group
function Presets.StaggeredFade(frames, perItemDelay, duration, easing)
    local group = AnimationUtil.CreateGroup()
    local delay = perItemDelay or 0.06
    local dur = duration or 0.22
    local ease = easing or "outCubic"

    for i, f in ipairs(frames) do
        if type(f) == "table" and type(f.SetAlpha) == "function" then f:SetAlpha(0) end
        if type(f) == "table" and type(f.Show) == "function" then f:Show() end
        group:CreateAnimation("fade", {
            target = f,
            from = 0,
            to = 1,
            duration = dur,
            easing = ease,
            startDelay = delay * (i - 1),
        })
    end

    group:Play()
    return group
end

--- Wire an OnEnter/OnLeave crossfade on a frame. The `bgTexture` fades in on
-- hover and out on leave. Returns a teardown function that detaches scripts.
-- @param frame Frame (must accept OnEnter/OnLeave)
-- @param bgTexture Texture
-- @param duration number|nil
-- @return function teardown
function Presets.HoverCrossfade(frame, bgTexture, duration)
    if type(frame) ~= "table" or type(frame.HookScript) ~= "function" then return function() end end
    if type(bgTexture) ~= "table" or type(bgTexture.SetAlpha) ~= "function" then return function() end end

    local dur = duration or 0.18
    bgTexture:SetAlpha(0)
    if type(bgTexture.Show) == "function" then bgTexture:Show() end

    local current
    local function play(toAlpha)
        if current then current:Stop() end
        local group = AnimationUtil.CreateGroup(bgTexture)
        group:CreateAnimation("fade", {
            target = bgTexture,
            from = bgTexture:GetAlpha(),
            to = toAlpha,
            duration = dur,
            easing = "outCubic",
        })
        current = group
        group:Play()
    end

    local onEnter = function() play(1) end
    local onLeave = function() play(0) end

    frame:HookScript("OnEnter", onEnter)
    frame:HookScript("OnLeave", onLeave)

    return function()
        if current then current:Stop() end
        -- HookScript cannot be unhooked; callers accept this.
    end
end

--- One-shot attention pulse: fade color from normal to flash color and back.
-- Target must support SetVertexColor or SetColorTexture.
-- @param target Texture
-- @param normalColor table {r,g,b[,a]}
-- @param flashColor table {r,g,b[,a]}
-- @param duration number|nil (total round-trip, default 0.4)
-- @return group
function Presets.FlashPulse(target, normalColor, flashColor, duration)
    local group = AnimationUtil.CreateGroup(target)
    local half = (duration or 0.4) / 2

    group:CreateAnimation("color", {
        target = target,
        from = normalColor,
        to = flashColor,
        duration = half,
        easing = "outQuad",
        order = 1,
    })
    group:CreateAnimation("color", {
        target = target,
        from = flashColor,
        to = normalColor,
        duration = half,
        easing = "inQuad",
        order = 2,
    })

    group:Play()
    return group
end

--[[--------------------------------------------------------------------
    Registration
----------------------------------------------------------------------]]

Animation.Presets = Presets
Loolib.AnimationPresets = Presets

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.AnimationPresets = Presets

Loolib:RegisterModule("Animation.Presets", Presets)
