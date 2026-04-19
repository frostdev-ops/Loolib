# PixelUtil Module Documentation

## Overview

**PixelUtil** exposes the "pixel mult" that polished UI suites (ElvUI, ToxiUI) use to snap UI units to physical screen pixels. It does NOT modify `UIParent:SetScale` — Loolib is a library that coexists with other addons, so global scale changes are left to the consumer. This module only provides the math and a thin-border helper.

```
mult = 768 / physicalScreenHeight / UIParent:GetScale()
```

When `UIParent:GetScale()` is set to `768 / physicalScreenHeight`, `mult` equals `1` and 1 UI unit = 1 physical pixel. Addons that don't override UIParent still benefit from snapping border thickness to `mult` to avoid sub-pixel anti-aliasing bleed.

Registered as `UI.PixelUtil`. Also accessible via `Loolib.PixelUtil`.

---

## API Reference

### PixelUtil.GetMult()

Returns the current pixel mult. Cached after first call; refreshed automatically on `UI_SCALE_CHANGED` / `DISPLAY_SIZE_CHANGED`.

```lua
local PixelUtil = LibStub("Loolib").PixelUtil
local m = PixelUtil.GetMult()
frame:SetSize(m * 200, m * 40) -- or whatever pixel-snapped size you want
```

### PixelUtil.Snap(value)

Round `value` to the nearest multiple of `GetMult()`. Useful when you've computed a size via arithmetic and want it pixel-aligned.

### PixelUtil.SetThinBorder(frame, color)

Create (or refresh) a four-texture 1-physical-pixel border around a frame. Textures are attached as `frame._loolibBorderEdges = { Top, Bottom, Left, Right }` and are re-anchored automatically when the pixel mult changes. Safe to call multiple times.

```lua
PixelUtil.SetThinBorder(myFrame, { 0.1, 0.1, 0.1, 1 })
```

### PixelUtil.RegisterCallback(owner, callback)

Fire `callback(newMult, oldMult)` when the pixel mult changes. `owner` is any non-nil key used for `UnregisterCallback`.

### PixelUtil.UnregisterCallback(owner)

---

## Why Loolib does not override UIParent:SetScale

ElvUI and ToxiUI replace the entire UI, so taking control of `UIParent:SetScale` is appropriate. Loolib is embedded into addons that run alongside other addons (RaiderIO, WeakAuras, etc.) and changing the global scale would disrupt every coexisting addon. Consumers that want ElvUI-style true pixel-perfect rendering can set `UIParent:SetScale(768 / screenHeight)` themselves; this module's math stays correct either way.

---

## Related

- [StyleUtil](StyleUtil.md) — `CreateDivider` for thin separators; pair with `Snap` for pixel alignment.
