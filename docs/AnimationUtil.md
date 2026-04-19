# AnimationUtil Module Documentation

## Overview

**AnimationUtil** is a single-updater tween engine that complements WoW's native `CreateAnimationGroup`. It uses Robert Penner's easing library (39 curves) and is modelled on the approach ToxiUI/ElvUI use for polished transitions. All active animations are ticked by a single shared `OnUpdate` frame, keeping per-animation overhead minimal.

Registered as `UI.AnimationUtil`. Also accessible via `Loolib.AnimationUtil`.

Companion modules:
- `Loolib.Easing` (`UI.Animation.Easing`) — pure Penner functions.
- `Loolib.AnimationPresets` (`UI.AnimationPresets`) — turnkey recipes.

---

## When to use AnimationUtil vs native AnimationGroup

Use **AnimationUtil** when you want:
- More easing curves than `IN / OUT / IN_OUT / NONE`.
- Consistent chaining semantics with rich `onFinished` callbacks.
- Color / progress / flipbook tweens without writing custom `OnUpdate` handlers.

Use **native AnimationGroup** when you're embedding in XML or when a frame's animation needs to survive SetParent reparents at the C API level. The two systems coexist — nothing in Loolib prevents you from mixing them.

---

## API Reference

### AnimationUtil.CreateGroup(parent)

Create a new animation group. `parent` is the default target for child animations when `opts.target` is omitted.

```lua
local AnimationUtil = LibStub("Loolib").AnimationUtil
local group = AnimationUtil.CreateGroup(myFrame)
```

Returns a group with methods:

| Method | Description |
|---|---|
| `group:CreateAnimation(kind, opts)` | Add a child animation. Returns the anim object. |
| `group:Play()` | Start playback from the first order. Resets any prior state. |
| `group:Stop()` | Stop all child animations immediately. |
| `group:Pause()` | Alias for Stop (full pause/resume is not implemented). |
| `group:SetOnFinished(fn)` | Fired once after the last order completes. |
| `group:SetLooping(mode)` | `"NONE"` (default) or `"REPEAT"`. |
| `group:IsPlaying()` | Boolean. |

---

### group:CreateAnimation(kind, opts)

Add a child animation. `kind` (string) selects the tween type. `opts` is a table:

| Field | Type | Description |
|---|---|---|
| `target` | Frame/Texture/StatusBar | Defaults to `group.parent`. |
| `from` | number/table | Starting value; auto-captured for `fade`/`scale`/`width`/`height` when omitted. |
| `to` | number/table | Ending value. |
| `duration` | number | Seconds. Default `0.25`. |
| `easing` | string/function | Easing name (e.g. `"outCubic"`) or function. Default `"outCubic"`. |
| `startDelay` | number | Seconds to wait before the tween starts. |
| `order` | integer | Orders play sequentially; items in an order play in parallel. Default `1`. |
| `onFinished` | function | Called with `(anim)` when the tween completes. |
| `flipbook` | table | `{ frames, cols, rows }` for `kind="flipbook"`. |
| `baseAnchor` | table | `{ point, relativeTo, relativePoint, x, y }` for `kind="move"`. Auto-captured when omitted. |

### Animation kinds

| Kind | Target | `from`/`to` | Notes |
|---|---|---|---|
| `fade` | Region with `SetAlpha` | number | Most common. |
| `scale` | Frame with `SetScale` | number | |
| `width` | Frame with `SetWidth` | number | |
| `height` | Frame with `SetHeight` | number | |
| `move` | Frame with anchor | `{ dx, dy }` | Delta offset from captured base anchor. |
| `color` | Texture/StatusBar with `SetVertexColor`/`SetColorTexture`/`SetStatusBarColor` | `{r,g,b[,a]}` | |
| `progress` | StatusBar | number | Smooth `SetValue`. |
| `flipbook` | Texture with `SetTexCoord` | — | Sprite-sheet advance. |
| `sleep` | — | — | Pure delay within a group. |

### Ordering and chaining

Orders fire sequentially. Within an order, animations run in parallel. The group's `onFinished` fires once after the final order drains.

```lua
local group = AnimationUtil.CreateGroup(frame)
group:CreateAnimation("fade", { from = 1, to = 0, duration = 0.13, easing = "inQuad", order = 1 })
group:CreateAnimation("fade", { from = 0, to = 1, duration = 0.22, easing = "outCubic", order = 2, startDelay = 0.07 })
group:Play()
```

---

## Easing curves

All curves accept `(t, b, c, d)` where `t` is elapsed time (0..d), `b` is begin, `c` is change, `d` is duration. AnimationUtil calls them with the normalized form `ease(elapsedClamped, 0, 1, duration)`, so the returned value is the tween fraction 0..1.

Available curves (pass as `opts.easing` string):

```
linear
inQuad   outQuad   inOutQuad
inCubic  outCubic  inOutCubic
inQuart  outQuart  inOutQuart
inQuint  outQuint  inOutQuint
inSine   outSine   inOutSine
inExpo   outExpo   inOutExpo
inCirc   outCirc   inOutCirc
inBack   outBack   inOutBack
inBounce outBounce inOutBounce
inElastic outElastic inOutElastic
```

You can also pass a function directly: `opts.easing = function(t, b, c, d) ... end`.

---

## Presets

`Loolib.AnimationPresets` wraps the most common patterns:

### Presets.FadeIn(frame, duration, easing, onFinished)

Show + fade from 0 to 1.

### Presets.FadeOut(frame, duration, easing, hideOnFinish, onFinished)

Fade to 0. If `hideOnFinish`, calls `frame:Hide()` when done.

### Presets.SlideIn(frame, fromOffset, duration, easing)

Slide from `{dx, dy}` offset relative to the anchor while fading in. Default offset `{0, -20}`.

### Presets.StaggeredFade(frames, perItemDelay, duration, easing)

Fade a sequence of frames in with a per-item delay. Flagship ToxiUI landing-page pattern.

```lua
Presets.StaggeredFade({ header, subtitle, body, footer }, 0.06, 0.22, "outCubic")
```

### Presets.HoverCrossfade(frame, bgTexture, duration)

Attach `OnEnter`/`OnLeave` hooks that crossfade a background texture. Returns a teardown function.

### Presets.FlashPulse(target, normalColor, flashColor, duration)

One-shot attention pulse: tween color to flash, then back.

---

## Performance notes

- One shared `OnUpdate` frame services every active animation. When the active list drains, the frame hides itself so idle cost is zero.
- `fade`/`scale`/`width`/`height` auto-capture the `from` value when omitted — good for "animate from current state" patterns.
- `color` tweens reuse table slots from `from` and `to` — do not mutate those tables while a tween runs.
- `move` tweens require a valid anchor on the target. If the target has no anchor yet, set one before `Play()` or pass `opts.baseAnchor` explicitly.

---

## Related

- [ThemeManager](ThemeManager.md) — gradient + color tokens that pair well with `color` animations.
- [StyleUtil](StyleUtil.md) — `ApplyGradientBar` for gradient statusbars animated via `progress`.
