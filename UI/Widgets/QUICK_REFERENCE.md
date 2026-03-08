# WidgetMod Quick Reference

## Factory Functions

```lua
-- Create new frame with WidgetMod
local frame = LoolibCreateModFrame("Frame", parent, "template")

-- Apply to existing frame
LoolibApplyWidgetMod(existingFrame)
```

## Size & Position

```lua
:Size(width, height)        -- height defaults to width
:Width(w) :Height(h)        -- individual dimensions
:Point(...)                 -- smart SetPoint (6 patterns)
:NewPoint(...)              -- clear then point
:ClearPoints()              -- clear all anchors
```

### Point() Patterns

```lua
:Point("CENTER")                                    -- simple
:Point("TOPLEFT", 10, -10)                         -- with offset
:Point("TOPLEFT", frame, 5, -5)                    -- relative (auto-mirror)
:Point("BOTTOMLEFT", frame, "TOPRIGHT", 10, 0)     -- full
:Point(frame)                                       -- SetAllPoints
:Point("TOPLEFT", 'x', 10, -10)                    -- 'x' = parent
```

## Appearance

```lua
:Alpha(0.8)                 -- transparency (0-1)
:Scale(1.2)                 -- scale multiplier
:Shown(bool)                -- conditional visibility
:ShowFrame() :HideFrame()   -- explicit show/hide
:FrameLevel(10)             -- frame level
:FrameStrata("DIALOG")      -- frame strata
```

## Script Handlers

```lua
:OnClick(fn)                -- button clicks
:OnEnter(fn) :OnLeave(fn)   -- mouse hover
:OnShow(fn, skipFirst)      -- show (opt skip first)
:OnHide(fn)                 -- hide
:OnUpdate(fn)               -- every frame
:OnMouseDown(fn) :OnMouseUp(fn)
:OnMouseWheel(fn)           -- auto-enables wheel
:OnDragStart(fn) :OnDragStop(fn)
:OnValueChanged(fn)         -- slider/scrollbar
:OnTextChanged(fn)          -- editbox
:OnEnterPressed(fn) :OnEscapePressed(fn)
```

## Tooltips

```lua
-- Single line
:Tooltip("Help text")

-- Multi-line
:Tooltip({"Title", "Line 1", "Line 2"})

-- Anchor
:TooltipAnchor("ANCHOR_RIGHT")  -- or CURSOR, TOP, etc.
```

## Utilities

```lua
:Run(fn, ...)               -- execute inline code
:EnableWidget() :DisableWidget() :SetEnabled(bool)
:Text("string")             -- set text
:Mouse(bool)                -- enable mouse
:MouseWheel(bool)           -- enable wheel
:Movable("LeftButton")      -- make draggable
:ClampedToScreen(bool)      -- screen clamping
:Parent(frame)              -- set parent
```

## Common Patterns

### Button

```lua
LoolibCreateModFrame("Button", parent, "UIPanelButtonTemplate")
    :Size(100, 30)
    :Point("CENTER")
    :Text("Save")
    :Tooltip("Save settings")
    :OnClick(function() print("Clicked") end)
```

### Panel

```lua
LoolibCreateModFrame("Frame", UIParent, "BackdropTemplate")
    :Size(300, 200)
    :Point("CENTER")
    :Movable()
    :ClampedToScreen()
    :Run(function(self)
        self:SetBackdrop({...})
        self:SetBackdropColor(0, 0, 0, 0.8)
    end)
```

### EditBox

```lua
LoolibCreateModFrame("EditBox", parent, "InputBoxTemplate")
    :Size(200, 30)
    :Point("TOPLEFT", 20, -50)
    :Run(function(self)
        self:SetAutoFocus(false)
        self:SetMaxLetters(50)
    end)
    :OnEnterPressed(function(self) self:ClearFocus() end)
    :OnEscapePressed(function(self) self:ClearFocus() end)
```

### Slider

```lua
LoolibCreateModFrame("Slider", parent, "OptionsSliderTemplate")
    :Size(200, 16)
    :Point("TOPLEFT", 20, -100)
    :Run(function(self)
        self:SetMinMaxValues(0, 100)
        self:SetValue(50)
    end)
    :OnValueChanged(function(self, value)
        print("Value:", value)
    end)
```

## Module Access

```lua
local Loolib = LibStub("Loolib")
local WidgetMod = Loolib:GetModule("WidgetMod")

-- Access components
WidgetMod.Mixin   -- LoolibWidgetModMixin
WidgetMod.Apply   -- LoolibApplyWidgetMod
WidgetMod.Create  -- LoolibCreateModFrame
```

## Tips

1. **Every method returns self** - chain unlimited
2. **Use :Run() for complex setup** - keeps chains readable
3. **Store references** - `self.button = LoolibCreateModFrame(...)`
4. **Group logically** - size/position, then appearance, then handlers
5. **skipFirstRun** - :OnShow(fn, true) skips first invocation

## Full Documentation

See `/Loolib/docs/WidgetMod.md` for complete API reference.
