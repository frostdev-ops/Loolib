# FrameUtil Module Documentation

## Overview

**FrameUtil** provides utilities for frame creation, script handling, property management, hierarchy traversal, visibility effects, and frame level management for WoW 12.0+ addons.

Registered as `UI.FrameUtil`. Also accessible via `Loolib.FrameUtil`.

---

## API Reference

### Frame Creation

#### CreateFrameWithMixins(frameType, name, parent, template, ...)

Create a frame, apply mixins, reflect script handlers, and call `OnLoad` if defined.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `frameType` | string | yes | WoW frame type (e.g. `"Frame"`, `"Button"`) |
| `name` | string/nil | no | Global name |
| `parent` | Frame/nil | no | Parent frame |
| `template` | string/nil | no | XML template |
| `...` | table(s) | no | Mixin tables to apply |

**Returns:** Frame

#### CreateBackdropFrame(parent, backdrop)

Create a frame with `BackdropTemplate` and default styling.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `parent` | Frame | no | Parent frame |
| `backdrop` | table/nil | no | Backdrop info (defaults to `Backdrop.Panel`) |

**Returns:** Frame

---

### Script Handlers

#### GetStandardScriptHandlers()

Returns the list of standard WoW script handler names (OnLoad, OnShow, etc.).

#### SupportsScript(frame, scriptName)

Check if a frame supports a script. Returns `false` gracefully for nil/invalid frames.

#### HookScript(frame, scriptName, handler)

Hook a script handler (preserving existing). Validates frame and handler.

#### SetScript(frame, scriptName, handler)

Set a script handler. Validates frame; accepts nil handler to clear.

---

### Frame Properties

#### MakeMovable(frame, clampToScreen)

Make a frame draggable via left-button drag.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `frame` | Frame | -- | The frame |
| `clampToScreen` | boolean | `true` | Whether to clamp to screen |

#### MakeResizable(frame, minWidth, minHeight, maxWidth, maxHeight)

Make a frame resizable with a resize grip at bottom-right. Stores the grip as `frame.resizeGrip`.

#### AddCloseButton(frame, onClose)

Add a close button at top-right. Calls optional `onClose(frame)` before hiding. Stores as `frame.CloseButton`.

**Returns:** Button

#### AddTitle(frame, title, fontObject)

Add a title FontString at the top. Stores as `frame.TitleText`.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `title` | string | -- | Title text (required) |
| `fontObject` | string | `"GameFontNormal"` | Font object name |

**Returns:** FontString

---

### Frame State

#### IsVisibleOnScreen(frame)

Returns `true` only if the frame and all its ancestors are shown. Returns `false` gracefully for nil/invalid frames.

#### GetEffectiveAlpha(frame)

Walk the parent chain to compute the effective alpha.

**Returns:** number

#### GetAbsolutePosition(frame)

Get the screen-space position accounting for effective scale.

**Returns:** `left, bottom, width, height` (all nil if frame has no valid position)

---

### Frame Hierarchy

#### GetAllChildren(frame)

**Returns:** Array of child frames.

#### GetAllRegions(frame)

**Returns:** Array of regions (textures, fontstrings, etc.).

#### FindChild(frame, pattern)

Find the first child whose name matches a Lua pattern.

**Returns:** Frame or nil.

#### ForEachDescendant(frame, func)

Recursively execute `func(frame)` on the frame and all descendants.

---

### Frame Visibility

#### ShowWithFade(frame, duration, onComplete)

Show a frame with an optional fade-in animation. Uses OnUpdate for the fade; clears the handler on completion.

#### HideWithFade(frame, duration, onComplete)

Hide a frame with an optional fade-out animation. Restores alpha to 1 after hiding.

---

### Frame Level Management

#### BringToFront(frame)

Set the frame level to one above the highest sibling in the same strata.

---

## Input Validation

All functions that accept a `frame` parameter validate it has `GetObjectType`. Functions that accept callbacks validate them as functions. Invalid inputs raise `error("LoolibFrameUtil.<func>: ...", 2)`.
