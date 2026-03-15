# Loolib Enhanced Widgets System

Comprehensive documentation for the Loolib fluent API widget enhancement system.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [WidgetMod Mixin](#widgetmod-mixin)
4. [EnhancedSlider](#enhancedslider)
5. [PopupMenu](#popupmenu)
6. [EnhancedDropdown](#enhanceddropdown)
7. [Usage Examples](#usage-examples)
8. [API Reference](#api-reference)

---

## Overview

### What is the Enhanced Widgets System?

The Loolib Enhanced Widgets system provides a **fluent API** for creating and configuring WoW UI widgets. Instead of writing verbose code with many separate method calls, you chain methods together for concise, readable widget configuration.

### Fluent API Pattern

Traditional WoW widget configuration:

```lua
local slider = CreateFrame("Slider", nil, parent, "MinimalSliderTemplate")
slider:SetSize(200, 20)
slider:SetPoint("CENTER")
slider:SetMinMaxValues(0, 100)
slider:SetValue(50)
slider:SetScript("OnValueChanged", function(self, value)
    print("Value changed:", value)
end)
```

With Loolib's fluent API:

```lua
local slider = LoolibCreateEnhancedSlider(parent)
    :Size(200, 20)
    :Point("CENTER")
    :Range(0, 100)
    :SetTo(50)
    :OnChange(function(self, value)
        print("Value changed:", value)
    end)
```

### Components

The Enhanced Widgets system includes four main components:

| Component | Purpose |
|-----------|---------|
| **WidgetMod** | Base mixin providing fluent API for any frame |
| **EnhancedSlider** | Advanced slider with labels, value display, and formatting |
| **PopupMenu** | Context menus with icons, checkboxes, submenus |
| **EnhancedDropdown** | Feature-rich dropdown with nested menus, embedded controls |

### Comparison with MRT

Inspired by MaxDps Rotation Tool's Mod() pattern, but designed specifically for WoW's native frame system:

| Feature | Loolib WidgetMod | MRT Mod() |
|---------|------------------|-----------|
| Chaining API | Yes | Yes |
| Native frames | Yes | Custom system |
| External deps | None | MRT framework |
| Mixins | LoolibMixin | Custom |
| Event handling | Native scripts | Custom |
| Profile support | Via SavedVariables | Built-in |

---

## Quick Start

### Minimal Working Example

Enhance any existing frame with the WidgetMod API:

```lua
-- Apply to existing frame
local frame = CreateFrame("Frame", nil, UIParent)
LoolibApplyWidgetMod(frame)

frame:Size(200, 100)
    :Point("CENTER")
    :Alpha(0.9)
    :Tooltip("This is a tooltip")
    :OnClick(function(self)
        print("Clicked!")
    end)
```

### Create Enhanced Slider

```lua
local slider = LoolibCreateEnhancedSlider(UIParent)
    :Size(200, 20)
    :Point("CENTER")
    :Title("Volume")
    :Range(0, 100)
    :Step(5)
    :SetTo(50)
    :ShowValue("%d%%")
    :ShowLabels("Quiet", "Loud")
    :OnChange(function(self, value, userInput)
        SetVolume(value / 100)
    end)
    :Tooltip("Adjust the volume level")
```

### Create Context Menu

```lua
local menu = LoolibCreatePopupMenu()
    :SetOptions({
        {text = "Copy", value = "copy", icon = "Interface\\Icons\\INV_Misc_Note_01"},
        {text = "Paste", value = "paste", disabled = not HasClipboard()},
        {isSeparator = true},
        {text = "Delete", value = "delete", colorCode = "|cffff0000"},
    })
    :OnSelect(function(value, item)
        HandleAction(value)
    end)
    :ShowAtCursor()
```

### Create Dropdown

```lua
local dropdown = LoolibCreateEnhancedDropdown(parent)
    :Size(150, 24)
    :Point("TOPLEFT", 10, -10)
    :SetList({
        {text = "Option 1", value = 1},
        {text = "Option 2", value = 2},
        {text = "Submenu", subMenu = {
            {text = "Sub 1", value = "sub1"},
            {text = "Sub 2", value = "sub2"},
        }},
    })
    :SetValue(1)
    :OnSelect(function(value)
        print("Selected:", value)
    end)
```

---

## WidgetMod Mixin

The base mixin that provides fluent API methods to any frame.

### Applying the Mixin

#### To Existing Frames

```lua
local frame = CreateFrame("Button", nil, UIParent)
LoolibApplyWidgetMod(frame)

-- Now you can chain methods
frame:Size(100, 30):Point("CENTER"):Text("Click Me")
```

#### Create New Frames

```lua
local frame = LoolibCreateModFrame("Frame", UIParent)
    :Size(200, 100)
    :Point("CENTER")
    :Alpha(0.8)
```

### Sizing and Positioning

#### Size

Set width and height:

```lua
-- Both dimensions
frame:Size(200, 100)

-- Square (height defaults to width)
frame:Size(100)
```

#### Width / Height

Set individual dimensions:

```lua
frame:Width(250)
frame:Height(150)
```

#### Point

Smart positioning with multiple signatures:

```lua
-- Simple anchor to parent
frame:Point("CENTER")

-- Anchor with offsets
frame:Point("TOPLEFT", 10, -10)

-- Anchor to another frame
frame:Point("TOPLEFT", otherFrame, 5, -5)

-- Full anchor specification
frame:Point("TOPLEFT", otherFrame, "BOTTOMLEFT", 0, -5)

-- SetAllPoints to frame
frame:Point(otherFrame)

-- Two numbers = TOPLEFT + offsets
frame:Point(10, -10)  -- Same as Point("TOPLEFT", 10, -10)

-- Special: 'x' means parent
frame:Point("LEFT", 'x', "RIGHT", 5, 0)  -- Anchor to parent's right
```

#### NewPoint

Clear all points and set a new one:

```lua
frame:NewPoint("CENTER")
frame:NewPoint("TOPLEFT", 20, -20)
```

#### ClearPoints

Clear all anchor points:

```lua
frame:ClearPoints()
```

### Appearance

#### Alpha

Set transparency:

```lua
frame:Alpha(0.8)  -- 0 = invisible, 1 = opaque
```

#### Scale

Set scale multiplier:

```lua
frame:Scale(1.5)
```

#### Shown

Conditional visibility:

```lua
frame:Shown(shouldShow)  -- true to show, false to hide
frame:Shown(db.enabled)
```

#### ShowFrame / HideFrame

Explicit show/hide:

```lua
frame:ShowFrame()
frame:HideFrame()
```

#### FrameLevel / FrameStrata

Control layering:

```lua
frame:FrameLevel(10)
frame:FrameStrata("DIALOG")
```

### Script Handlers

All script handlers return self for chaining.

#### OnClick

```lua
button:OnClick(function(self, button, down)
    if button == "LeftButton" then
        print("Left clicked!")
    end
end)
```

#### OnEnter / OnLeave

Mouse hover handlers:

```lua
frame:OnEnter(function(self, motion)
    self:SetAlpha(1)
end)
    :OnLeave(function(self, motion)
        self:SetAlpha(0.8)
    end)
```

#### OnShow / OnHide

```lua
frame:OnShow(function(self)
    print("Frame shown")
end)
    :OnHide(function(self)
        print("Frame hidden")
    end)

-- Skip first run (don't execute immediately)
frame:OnShow(function(self)
    RefreshData()
end, true)  -- skipFirstRun
```

#### OnUpdate

```lua
frame:OnUpdate(function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer > 1 then
        self.timer = 0
        DoSomething()
    end
end)
```

#### Mouse Events

```lua
frame:OnMouseDown(function(self, button)
    print("Mouse down:", button)
end)
    :OnMouseUp(function(self, button)
        print("Mouse up:", button)
    end)
    :OnMouseWheel(function(self, delta)
        AdjustZoom(delta)
    end)
```

#### Drag Events

```lua
frame:OnDragStart(function(self, button)
    self:StartMoving()
end)
    :OnDragStop(function(self)
        self:StopMovingOrSizing()
    end)
```

#### Value/Text Changed

For sliders and editboxes:

```lua
slider:OnValueChanged(function(self, value)
    print("Value:", value)
end)

editbox:OnTextChanged(function(self, userInput)
    if userInput then
        ValidateInput(self:GetText())
    end
end)
```

#### EditBox Events

```lua
editbox:OnEnterPressed(function(self)
    SubmitValue(self:GetText())
    self:ClearFocus()
end)
    :OnEscapePressed(function(self)
        self:SetText(originalValue)
        self:ClearFocus()
    end)
```

### Tooltip Support

#### Tooltip

Add tooltip to widget. Uses `HookScript` internally so it does not clobber
existing `OnEnter`/`OnLeave` handlers. Calling `:Tooltip()` multiple times
safely updates the tooltip text without re-hooking.

```lua
-- Simple tooltip
button:Tooltip("Click to activate")

-- Multi-line tooltip
button:Tooltip({
    "Feature Name",
    "Description line 1",
    "Description line 2",
})
```

#### TooltipAnchor

Set tooltip anchor point:

```lua
button:Tooltip("Help text")
    :TooltipAnchor("ANCHOR_TOP")
```

Available anchors:
- `"ANCHOR_RIGHT"` (default)
- `"ANCHOR_LEFT"`
- `"ANCHOR_TOP"`
- `"ANCHOR_BOTTOM"`
- `"ANCHOR_CURSOR"`
- `"ANCHOR_TOPRIGHT"`
- `"ANCHOR_TOPLEFT"`
- `"ANCHOR_BOTTOMRIGHT"`
- `"ANCHOR_BOTTOMLEFT"`

### Utility Methods

#### Run

Execute a function inline while chaining:

```lua
frame:Size(100, 100)
    :Run(function(self)
        self.customProperty = true
        self.data = {}
    end)
    :Point("CENTER")
```

#### EnableWidget / DisableWidget / SetEnabled

Control interactive state:

```lua
button:EnableWidget()
button:DisableWidget()
button:SetEnabled(hasPermission)
```

#### Text

Set text content:

```lua
button:Text("Click Me")
fontString:Text("Hello World")
editbox:Text("Default value")
```

#### Mouse / MouseWheel

Enable mouse input:

```lua
frame:Mouse(true)    -- Enable mouse
frame:Mouse(false)   -- Disable mouse
frame:MouseWheel()   -- Enable mouse wheel
```

#### Movable

Make frame draggable:

```lua
frame:Movable()              -- Left button (default)
frame:Movable("RightButton") -- Right button drag

-- Automatically sets up drag handlers if not present
```

#### ClampedToScreen

Prevent frame from going off-screen:

```lua
frame:ClampedToScreen(true)
frame:ClampedToScreen(false)
```

#### Parent

Change parent frame:

```lua
frame:Parent(newParent)
```

### Complete Chaining Example

```lua
local button = LoolibCreateModFrame("Button", UIParent, "UIPanelButtonTemplate")
    :Size(120, 30)
    :Point("CENTER")
    :Text("My Button")
    :Tooltip("Click to do something")
    :OnClick(function(self)
        DoAction()
    end)
    :OnEnter(function(self)
        self:SetAlpha(1)
    end)
    :OnLeave(function(self)
        self:SetAlpha(0.8)
    end)
    :SetEnabled(true)
    :Alpha(0.8)
```

---

## EnhancedSlider

Advanced slider widget with value display, labels, and fluent API.

### Creating Enhanced Sliders

```lua
local slider = LoolibCreateEnhancedSlider(parent, name, template)
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `parent` | Frame | Yes | Parent frame |
| `name` | string | No | Global name |
| `template` | string | No | Template (default: "MinimalSliderTemplate") |

### Configuration Methods

All methods return `self` for chaining.

#### Range

Set minimum and maximum values:

```lua
slider:Range(0, 100)
slider:Range(-10, 10)

-- Get current range
local min, max = slider:GetRange()
```

#### Step

Set step increment:

```lua
slider:Step(5)    -- Steps of 5
slider:Step(0.1)  -- Decimal steps
slider:Step(1)    -- Integer steps

-- Get current step
local step = slider:GetStep()
```

#### SetTo

Set current value:

```lua
slider:SetTo(50)

-- Get current value
local value = slider:GetTo()
```

#### OnChange

Set change callback:

```lua
slider:OnChange(function(self, value, userInput)
    -- value: new slider value
    -- userInput: true if changed by user, false if programmatic

    if userInput then
        db.volume = value
        UpdateVolume()
    end
end)
```

#### ShowValue

Display value above slider:

```lua
slider:ShowValue()          -- Show with default format "%d"
slider:ShowValue("%d%%")    -- Percentage: "50%"
slider:ShowValue("%.1f")    -- Decimal: "50.5"
slider:ShowValue("%d sec")  -- With units: "50 sec"

-- Hide value display
slider:HideValue()
```

#### ShowLabels

Show min/max labels below slider:

```lua
-- Custom labels
slider:ShowLabels("Quiet", "Loud")

-- Automatic labels (uses min/max values)
slider:ShowLabels()

-- Hide labels
slider:HideLabels()
```

#### Title

Set slider title/label:

```lua
slider:Title("Volume")
slider:Title("Opacity")

-- Hide title
slider:HideTitle()
```

#### ValueFormat

Change value format string:

```lua
slider:ValueFormat("%d%%")
slider:ValueFormat("%.2f seconds")
```

#### SetEnabled

Enable or disable slider:

```lua
slider:SetEnabled(true)   -- Enabled, alpha 1
slider:SetEnabled(false)  -- Disabled, alpha 0.5
```

#### Tooltip

Add tooltip:

```lua
slider:Tooltip("Adjust the volume level")

-- Multi-line tooltip
slider:Tooltip({
    "Volume Control",
    "Adjusts game volume from 0% to 100%",
    "Use mouse wheel for fine adjustments",
})
```

#### TooltipAnchor

```lua
slider:TooltipAnchor("ANCHOR_RIGHT")
```

#### Font / FontSize / TextColor

Customize text appearance:

```lua
-- Set font for all text
slider:Font("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

-- Set size only
slider:FontSize(14)

-- Set color
slider:TextColor(1, 1, 0)  -- Yellow
slider:TextColor(1, 1, 1, 0.8)  -- White with alpha
```

### Advanced Methods

#### SetDefault

Add right-click to reset:

```lua
slider:SetDefault(50)  -- Right-click resets to 50
```

#### Orientation

Vertical or horizontal:

```lua
slider:Orientation("HORIZONTAL")  -- Default
slider:Orientation("VERTICAL")
```

#### ObeyStepOnDrag

Control step behavior:

```lua
slider:ObeyStepOnDrag(true)   -- Snap to steps while dragging
slider:ObeyStepOnDrag(false)  -- Smooth dragging
```

### Complete Example

```lua
local volumeSlider = LoolibCreateEnhancedSlider(settingsFrame)
    :Size(250, 20)
    :Point("TOPLEFT", 20, -60)
    :Title("Master Volume")
    :Range(0, 100)
    :Step(5)
    :SetTo(db.volume or 50)
    :ShowValue("%d%%")
    :ShowLabels("Mute", "Max")
    :OnChange(function(self, value, userInput)
        if userInput then
            db.volume = value
            SetVolume(value / 100)
        end
    end)
    :Tooltip({
        "Master Volume",
        "Control overall game volume",
        "Right-click to reset to default",
    })
    :SetDefault(50)
```

### Internal Elements

EnhancedSlider creates these child elements:

| Element | Type | Purpose |
|---------|------|---------|
| `slider.titleText` | FontString | Title above slider |
| `slider.valueText` | FontString | Value display |
| `slider.minLabel` | FontString | Minimum label |
| `slider.maxLabel` | FontString | Maximum label |

Access if needed:

```lua
slider.titleText:SetTextColor(1, 1, 0)
slider.valueText:SetFont("Fonts\\ARIALN.TTF", 14)
```

---

## PopupMenu

Context menus with icons, checkboxes, submenus, and more.

### Creating Popup Menus

```lua
local menu = LoolibCreatePopupMenu(parent, name)
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `parent` | Frame | No | Parent frame (default: UIParent) |
| `name` | string | No | Global name |

### Shared Menu Singleton

For simple use cases, use the shared menu:

```lua
local menu = LoolibGetSharedPopupMenu()
```

### MenuItem Structure

Menu items are defined as tables with these properties:

```lua
{
    -- Required
    text = "Menu Item",              -- Display text

    -- Value/Action
    value = any,                     -- Value passed to callback
    func = function(value),          -- Item-specific callback

    -- Appearance
    icon = "Interface\\Icons\\...",  -- Icon texture path
    iconIsAtlas = false,             -- If true, icon is atlas name
    colorCode = "|cFFRRGGBB",        -- Text color prefix

    -- State
    disabled = false,                -- Grayed out, not clickable
    checked = false,                 -- Show checkmark
    radio = false,                   -- Radio button style

    -- Special Types
    isTitle = false,                 -- Bold header, non-clickable
    isSeparator = false,             -- Horizontal line

    -- Behavior
    keepOpen = false,                -- Don't close menu on click
    subMenu = { ... },               -- Nested menu items

    -- Tooltip
    tooltip = "Help text",           -- Hover tooltip
}
```

### Configuration Methods

#### SetOptions

Set menu items:

```lua
menu:SetOptions({
    {text = "New", value = "new"},
    {text = "Open", value = "open"},
    {isSeparator = true},
    {text = "Exit", value = "exit"},
})
```

#### AddOption

Add single item:

```lua
menu:AddOption({
    text = "Delete",
    value = "delete",
    icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    colorCode = "|cffff0000",
})
```

#### AddSeparator

Add horizontal divider:

```lua
menu:AddSeparator()
```

#### AddTitle

Add section header:

```lua
menu:AddTitle("File Operations")
```

#### OnSelect

Set selection callback:

```lua
menu:OnSelect(function(value, menuItem)
    print("Selected:", value)
    print("Item text:", menuItem.text)
end)
```

#### SetMenuWidth

Set menu width:

```lua
menu:SetMenuWidth(200)
```

### Showing and Hiding

#### ShowAtCursor

Show menu at cursor position:

```lua
menu:ShowAtCursor()
```

#### ShowAt

Show anchored to frame:

```lua
menu:ShowAt(anchorFrame)
menu:ShowAt(anchorFrame, "TOPLEFT", "BOTTOMLEFT")
menu:ShowAt(anchorFrame, "TOPLEFT", "BOTTOMLEFT", 0, -5)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `anchorFrame` | Frame | Required | Anchor frame |
| `anchor` | string | "TOPLEFT" | Menu anchor point |
| `relativeAnchor` | string | "BOTTOMLEFT" | Frame anchor point |
| `xOffset` | number | 0 | X offset |
| `yOffset` | number | 0 | Y offset |

#### Close

Close the menu:

```lua
menu:Close()
```

### MenuItem Features

#### Icons

Texture or atlas icons:

```lua
-- Texture icon
{
    text = "Item",
    icon = "Interface\\Icons\\INV_Misc_Bag_08",
}

-- Atlas icon
{
    text = "Settings",
    icon = "Gamepad_Ltr_Menu_64",
    iconIsAtlas = true,
}
```

#### Checkmarks

Show checked state:

```lua
{
    text = "Enable Feature",
    value = "enable",
    checked = db.featureEnabled,
}
```

#### Radio Buttons

Mutually exclusive selection:

```lua
{
    text = "Mode A",
    value = "modeA",
    radio = true,
    checked = db.mode == "modeA",
},
{
    text = "Mode B",
    value = "modeB",
    radio = true,
    checked = db.mode == "modeB",
}
```

#### Color Coding

```lua
{
    text = "Delete",
    colorCode = "|cffff0000",  -- Red
},
{
    text = "Success",
    colorCode = "|cff00ff00",  -- Green
}
```

#### Disabled Items

```lua
{
    text = "Disabled Action",
    disabled = true,
}
```

#### Headers and Separators

```lua
{text = "File", isTitle = true},
{text = "New", value = "new"},
{text = "Open", value = "open"},
{isSeparator = true},
{text = "Edit", isTitle = true},
{text = "Copy", value = "copy"},
```

#### Submenus

Nested menus:

```lua
{
    text = "Export",
    subMenu = {
        {text = "As JSON", value = "json"},
        {text = "As XML", value = "xml"},
        {text = "As CSV", value = "csv"},
    },
}
```

#### Item-Specific Callbacks

```lua
{
    text = "Do Action",
    func = function(value)
        PerformAction()
    end,
}
```

#### Keep Open

Prevent menu from closing:

```lua
{
    text = "Toggle Debug",
    keepOpen = true,
    func = function()
        db.debug = not db.debug
    end,
}
```

#### Tooltips

```lua
{
    text = "Advanced",
    tooltip = "This is an advanced feature that requires caution",
}
```

### Complete Example

```lua
local contextMenu = LoolibCreatePopupMenu()
    :SetOptions({
        -- Title
        {text = "Actions", isTitle = true},

        -- Basic actions with icons
        {
            text = "Copy",
            value = "copy",
            icon = "Interface\\Icons\\INV_Misc_Note_01",
            disabled = not HasSelection(),
        },
        {
            text = "Paste",
            value = "paste",
            icon = "Interface\\Icons\\INV_Misc_Note_02",
            disabled = not HasClipboard(),
        },

        {isSeparator = true},

        -- Submenu
        {
            text = "Export",
            subMenu = {
                {text = "As String", value = "export_string"},
                {text = "To File", value = "export_file"},
            },
        },

        {isSeparator = true},

        -- Dangerous action
        {
            text = "Delete",
            value = "delete",
            colorCode = "|cffff0000",
            icon = "Interface\\Icons\\INV_Misc_QuestionMark",
            iconIsAtlas = false,
        },
    })
    :OnSelect(function(value, item)
        if value == "copy" then
            DoCopy()
        elseif value == "paste" then
            DoPaste()
        elseif value == "delete" then
            DoDelete()
        end
    end)

-- Show on right-click
frame:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
        contextMenu:ShowAtCursor()
    end
end)
```

### Fluent Builder API

Alternative API for building menus:

```lua
local menu = LoolibPopupMenu()
    :AddTitle("File")
    :AddOption("New", "new")
    :AddOption("Open", "open")
    :AddSeparator()
    :AddOption("Exit", "exit")
    :OnSelect(function(value)
        HandleFileAction(value)
    end)
    :ShowAtCursor()
```

### Close Detection

Menus automatically close when:
- Clicking outside the menu
- Pressing Escape
- Selecting an item (unless `keepOpen = true`)
- Opening a different menu

---

## EnhancedDropdown

Advanced dropdown with submenus, embedded controls, and extensive customization.

### Creating Enhanced Dropdowns

```lua
local dropdown = LoolibCreateEnhancedDropdown(parent, name)
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `parent` | Frame | Yes | Parent frame |
| `name` | string | No | Global name |

### DropdownOption Structure

Extended option structure with embedded controls:

```lua
{
    -- Basic Properties
    text = "Label",               -- Display text (required)
    value = any,                  -- Value to store/return

    -- Appearance
    icon = "path" or atlasName,   -- Left-side icon
    iconIsAtlas = false,          -- If true, icon is atlas
    iconCoords = {l,r,t,b},       -- Texture coordinates for icon
    colorCode = "|cFFRRGGBB",     -- Color code prefix
    font = "FontObject",          -- Custom font

    -- State
    disabled = false,             -- Grayed out

    -- Special Types
    isTitle = false,              -- Non-selectable header
    isSeparator = false,          -- Horizontal divider

    -- Navigation
    subMenu = { ... },            -- Nested options

    -- Advanced Features (MRT-inspired)
    slider = {min, max, value, callback, step},  -- Embedded slider
    editBox = {defaultText, callback, width},    -- Embedded edit box
    checkState = bool,            -- Checkbox state
    onCheckChange = function,     -- Checkbox callback
    radio = false,                -- Radio button style
    padding = 0,                  -- Extra vertical padding

    -- Help
    tooltip = "text",             -- Hover tooltip
}
```

### Configuration Methods

#### SetList

Set dropdown options:

```lua
dropdown:SetList({
    {text = "Option 1", value = 1},
    {text = "Option 2", value = 2},
    {text = "Option 3", value = 3},
})
```

#### AddOption

Add single option:

```lua
dropdown:AddOption({
    text = "New Option",
    value = "new",
})
```

#### ClearOptions

Remove all options:

```lua
dropdown:ClearOptions()
```

#### SetValue

Set selected value:

```lua
dropdown:SetValue(2)

-- Get selected value
local value = dropdown:GetValue()
```

#### SetText

Manually set button text:

```lua
dropdown:SetText("Custom Text")
```

#### OnSelect

Set selection callback:

```lua
dropdown:OnSelect(function(value, option)
    print("Selected:", value)
    db.setting = value
    ApplySettings()
end)
```

#### SetMenuWidth

Set menu width:

```lua
dropdown:SetMenuWidth(200)
```

#### SetMaxLines

Set maximum visible lines before scrolling:

```lua
dropdown:SetMaxLines(15)  -- Default
dropdown:SetMaxLines(20)
```

#### SetAutoText

Control automatic text update:

```lua
dropdown:SetAutoText(true)   -- Auto-update button text (default)
dropdown:SetAutoText(false)  -- Manual text control
```

#### Tooltip

Add tooltip to button:

```lua
dropdown:Tooltip("Select an option from the list")
```

#### SetEnabled

Enable or disable dropdown:

```lua
dropdown:SetEnabled(true)
dropdown:SetEnabled(false)
```

### Menu Control

#### OpenMenu

Open the dropdown menu:

```lua
dropdown:OpenMenu()
```

#### CloseMenu

Close the dropdown menu:

```lua
dropdown:CloseMenu()
```

#### Toggle

Toggle menu open/closed:

```lua
dropdown:Toggle()
```

### Advanced Features

#### Embedded Sliders

Add a slider within a dropdown item:

```lua
{
    text = "Opacity",
    slider = {
        0,     -- min
        1,     -- max
        0.8,   -- current value
        function(value)  -- callback
            db.opacity = value
            UpdateOpacity()
        end,
        0.05,  -- step (optional)
    },
}
```

#### Embedded EditBoxes

Add a text input within a dropdown item:

```lua
{
    text = "Custom Name",
    editBox = {
        db.customName,  -- default text
        function(text)  -- callback
            db.customName = text
            UpdateName()
        end,
        150,  -- width (optional)
    },
}
```

#### Checkboxes

Toggle options within dropdown:

```lua
{
    text = "Enable Feature",
    checkState = db.featureEnabled,
    onCheckChange = function(checked)
        db.featureEnabled = checked
        UpdateFeature()
    end,
}
```

#### Radio Buttons

Mutually exclusive options:

```lua
{
    text = "Mode A",
    value = "modeA",
    radio = true,
    checkState = db.mode == "modeA",
}
```

#### Submenus

Multi-level nested menus:

```lua
{
    text = "Advanced",
    subMenu = {
        {text = "Sub Option 1", value = "sub1"},
        {text = "Sub Option 2", value = "sub2"},
        {
            text = "More Options",
            subMenu = {
                {text = "Deep Option 1", value = "deep1"},
                {text = "Deep Option 2", value = "deep2"},
            },
        },
    },
}
```

### Complete Example

```lua
local qualityDropdown = LoolibCreateEnhancedDropdown(settingsFrame)
    :Size(200, 24)
    :Point("TOPLEFT", 20, -100)
    :SetList({
        -- Header
        {text = "Quality Settings", isTitle = true},

        -- Simple options
        {text = "Low", value = 1, icon = "Interface\\Icons\\Spell_Nature_Sleep"},
        {text = "Medium", value = 2, icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow"},
        {text = "High", value = 3, icon = "Interface\\Icons\\Spell_Nature_HealingTouch"},

        {isSeparator = true},

        -- Submenu
        {
            text = "Custom",
            subMenu = {
                {
                    text = "Resolution Scale",
                    slider = {0.5, 2.0, db.resScale or 1.0, function(v)
                        db.resScale = v
                        ApplyResolutionScale()
                    end, 0.1},
                },
                {
                    text = "Shadow Quality",
                    slider = {0, 5, db.shadowQuality or 3, function(v)
                        db.shadowQuality = v
                        ApplyShadowQuality()
                    end, 1},
                },
            },
        },

        {isSeparator = true},

        -- Checkbox options
        {
            text = "Enable Anti-Aliasing",
            checkState = db.antiAliasing,
            onCheckChange = function(checked)
                db.antiAliasing = checked
                ApplyAASettings()
            end,
        },
        {
            text = "Enable Bloom",
            checkState = db.bloom,
            onCheckChange = function(checked)
                db.bloom = checked
                ApplyBloomSettings()
            end,
        },
    })
    :SetValue(db.quality or 2)
    :OnSelect(function(value, option)
        db.quality = value
        ApplyQuality()
    end)
    :Tooltip("Select graphics quality preset")
```

### Internal Elements

EnhancedDropdown creates these elements:

| Element | Type | Purpose |
|---------|------|---------|
| `dropdown.icon` | Texture | Button icon (left) |
| `dropdown.text` | FontString | Button text |
| `dropdown.arrow` | Texture | Dropdown arrow (right) |
| `dropdown.highlight` | Texture | Hover highlight |

---

## Usage Examples

### Example 1: Settings Panel with Sliders

```lua
local panel = LoolibCreateModFrame("Frame", UIParent, "BackdropTemplate")
    :Size(400, 300)
    :Point("CENTER")
    :Run(function(self)
        self:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        self:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end)

-- Volume slider
local volumeSlider = LoolibCreateEnhancedSlider(panel)
    :Size(300, 20)
    :Point("TOP", 0, -40)
    :Title("Master Volume")
    :Range(0, 100)
    :Step(5)
    :SetTo(db.volume)
    :ShowValue("%d%%")
    :ShowLabels("Mute", "Max")
    :OnChange(function(self, value, userInput)
        if userInput then
            db.volume = value
            SetVolume(value / 100)
        end
    end)

-- Opacity slider
local opacitySlider = LoolibCreateEnhancedSlider(panel)
    :Size(300, 20)
    :Point("TOP", volumeSlider, "BOTTOM", 0, -40)
    :Title("Window Opacity")
    :Range(0, 1)
    :Step(0.05)
    :SetTo(db.opacity)
    :ShowValue("%.0f%%")
    :OnChange(function(self, value, userInput)
        if userInput then
            db.opacity = value
            panel:SetAlpha(value)
        end
    end)

-- Scale slider
local scaleSlider = LoolibCreateEnhancedSlider(panel)
    :Size(300, 20)
    :Point("TOP", opacitySlider, "BOTTOM", 0, -40)
    :Title("UI Scale")
    :Range(0.5, 2.0)
    :Step(0.1)
    :SetTo(db.scale)
    :ShowValue("%.1fx")
    :OnChange(function(self, value, userInput)
        if userInput then
            db.scale = value
            panel:SetScale(value)
        end
    end)
    :SetDefault(1.0)
```

### Example 2: Right-Click Context Menu

```lua
-- Create list frame with right-click menu
local listFrame = LoolibCreateModFrame("Frame", UIParent)
    :Size(200, 400)
    :Point("CENTER")

-- Create context menu
local contextMenu = LoolibCreatePopupMenu()

-- Right-click handler
listFrame:EnableMouse(true)
listFrame:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
        local item = GetItemUnderMouse()

        contextMenu:SetOptions({
            {text = item.name, isTitle = true},
            {isSeparator = true},

            {
                text = "Edit",
                value = "edit",
                icon = "Interface\\Icons\\INV_Misc_Note_01",
            },
            {
                text = "Duplicate",
                value = "duplicate",
                icon = "Interface\\Icons\\INV_Misc_Note_02",
            },
            {isSeparator = true},
            {
                text = "Delete",
                value = "delete",
                colorCode = "|cffff0000",
                icon = "Interface\\Icons\\Ability_Rogue_FeignDeath",
            },
        })

        contextMenu:OnSelect(function(value)
            if value == "edit" then
                EditItem(item)
            elseif value == "duplicate" then
                DuplicateItem(item)
            elseif value == "delete" then
                DeleteItem(item)
            end
        end)

        contextMenu:ShowAtCursor()
    end
end)
```

### Example 3: Multi-Level Dropdown Menu

```lua
local classDropdown = LoolibCreateEnhancedDropdown(frame)
    :Size(150, 24)
    :Point("TOPLEFT", 20, -20)
    :SetList({
        -- Warrior specs
        {
            text = "Warrior",
            icon = "Interface\\Icons\\ClassIcon_Warrior",
            subMenu = {
                {text = "Arms", value = "warrior_arms"},
                {text = "Fury", value = "warrior_fury"},
                {text = "Protection", value = "warrior_prot"},
            },
        },

        -- Paladin specs
        {
            text = "Paladin",
            icon = "Interface\\Icons\\ClassIcon_Paladin",
            subMenu = {
                {text = "Holy", value = "paladin_holy"},
                {text = "Protection", value = "paladin_prot"},
                {text = "Retribution", value = "paladin_ret"},
            },
        },

        -- Hunter specs
        {
            text = "Hunter",
            icon = "Interface\\Icons\\ClassIcon_Hunter",
            subMenu = {
                {text = "Beast Mastery", value = "hunter_bm"},
                {text = "Marksmanship", value = "hunter_mm"},
                {text = "Survival", value = "hunter_sv"},
            },
        },
    })
    :OnSelect(function(value, option)
        db.selectedSpec = value
        LoadSpecProfile(value)
    end)
```

### Example 4: Dropdown with Embedded Slider

```lua
local displayDropdown = LoolibCreateEnhancedDropdown(frame)
    :Size(200, 24)
    :Point("TOP", 0, -50)
    :SetList({
        -- Simple options
        {text = "Small", value = "small"},
        {text = "Medium", value = "medium"},
        {text = "Large", value = "large"},

        {isSeparator = true},

        -- Custom size with embedded slider
        {
            text = "Custom Size",
            slider = {
                50,    -- min
                500,   -- max
                db.customSize or 200,
                function(value)
                    db.customSize = value
                    ResizeDisplay(value)
                end,
                10,    -- step
            },
        },

        {isSeparator = true},

        -- Custom opacity with embedded slider
        {
            text = "Opacity",
            slider = {
                0,
                1,
                db.displayOpacity or 1,
                function(value)
                    db.displayOpacity = value
                    SetDisplayOpacity(value)
                end,
                0.05,
            },
        },

        {isSeparator = true},

        -- Toggle options
        {
            text = "Show Borders",
            checkState = db.showBorders,
            onCheckChange = function(checked)
                db.showBorders = checked
                UpdateBorders()
            end,
        },
        {
            text = "Show Icons",
            checkState = db.showIcons,
            onCheckChange = function(checked)
                db.showIcons = checked
                UpdateIcons()
            end,
        },
    })
```

### Example 5: Movable Frame

```lua
local movableFrame = LoolibCreateModFrame("Frame", UIParent, "BackdropTemplate")
    :Size(300, 200)
    :Point("CENTER")
    :Run(function(self)
        self:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = {left = 8, right = 8, top = 8, bottom = 8},
        })
    end)
    :Movable()  -- Enable dragging
    :ClampedToScreen(true)
    :Run(function(self)
        -- Add title bar
        local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -12)
        title:SetText("Movable Window")

        -- Add close button
        local closeButton = CreateFrame("Button", nil, self, "UIPanelCloseButton")
        LoolibApplyWidgetMod(closeButton)
        closeButton:Point("TOPRIGHT", -8, -8)
            :OnClick(function()
                self:Hide()
            end)
    end)
```

---

## API Reference

### WidgetMod Mixin

#### Factory Functions

```lua
LoolibApplyWidgetMod(frame) → Frame
```
Apply WidgetMod mixin to an existing frame.

```lua
LoolibCreateModFrame(frameType, parent, template) → Frame
```
Create a new frame with WidgetMod already applied.

#### Sizing Methods

```lua
frame:Size(width, height) → self
frame:Width(width) → self
frame:Height(height) → self
```

#### Positioning Methods

```lua
frame:Point(...) → self
frame:NewPoint(...) → self
frame:ClearPoints() → self
```

#### Appearance Methods

```lua
frame:Alpha(alpha) → self
frame:Scale(scale) → self
frame:Shown(bool) → self
frame:ShowFrame() → self
frame:HideFrame() → self
frame:FrameLevel(level) → self
frame:FrameStrata(strata) → self
```

#### Script Methods

```lua
frame:OnClick(handler) → self
frame:OnEnter(handler) → self
frame:OnLeave(handler) → self
frame:OnShow(handler, skipFirstRun) → self
frame:OnHide(handler) → self
frame:OnUpdate(handler) → self
frame:OnMouseDown(handler) → self
frame:OnMouseUp(handler) → self
frame:OnMouseWheel(handler) → self
frame:OnDragStart(handler) → self
frame:OnDragStop(handler) → self
frame:OnEvent(handler) → self
frame:OnValueChanged(handler) → self
frame:OnTextChanged(handler) → self
frame:OnEnterPressed(handler) → self
frame:OnEscapePressed(handler) → self
```

#### Tooltip Methods

```lua
frame:Tooltip(text) → self
frame:TooltipAnchor(anchor) → self
```

#### Utility Methods

```lua
frame:Run(func, ...) → self
frame:EnableWidget() → self
frame:DisableWidget() → self
frame:SetEnabled(enabled) → self
frame:Text(text) → self
frame:Mouse(enable) → self
frame:MouseWheel(enable) → self
frame:Movable(button) → self
frame:ClampedToScreen(clamped) → self
frame:Parent(parent) → self
```

### EnhancedSlider

#### Factory Function

```lua
LoolibCreateEnhancedSlider(parent, name, template) → Slider
```

#### Configuration Methods

```lua
slider:Range(min, max) → self
slider:GetRange() → min, max
slider:Step(step) → self
slider:GetStep() → step
slider:SetTo(value) → self
slider:GetTo() → value
slider:OnChange(callback) → self
slider:ShowValue(formatString) → self
slider:HideValue() → self
slider:ShowLabels(minText, maxText) → self
slider:HideLabels() → self
slider:Title(title) → self
slider:HideTitle() → self
slider:ValueFormat(formatString) → self
slider:SetEnabled(enabled) → self
slider:Tooltip(text) → self
slider:TooltipAnchor(anchor) → self
slider:Font(font, size, flags) → self
slider:FontSize(size) → self
slider:TextColor(r, g, b, a) → self
slider:SetDefault(defaultValue) → self
slider:Orientation(orientation) → self
slider:ObeyStepOnDrag(obey) → self
slider:Run(func, ...) → self
```

### PopupMenu

#### Factory Functions

```lua
LoolibCreatePopupMenu(parent, name) → Frame
LoolibGetSharedPopupMenu() → Frame
LoolibPopupMenu() → Builder
```

#### Configuration Methods

```lua
menu:SetOptions(options) → self
menu:AddOption(option) → self
menu:AddSeparator() → self
menu:AddTitle(text) → self
menu:OnSelect(callback) → self
menu:SetMenuWidth(width) → self
```

#### Display Methods

```lua
menu:ShowAtCursor()
menu:ShowAt(anchorFrame, anchor, relativeAnchor, xOffset, yOffset)
menu:Close()
```

### EnhancedDropdown

#### Factory Function

```lua
LoolibCreateEnhancedDropdown(parent, name) → Button
```

#### Configuration Methods

```lua
dropdown:SetList(options) → self
dropdown:AddOption(option) → self
dropdown:ClearOptions() → self
dropdown:SetValue(value) → self
dropdown:GetValue() → value
dropdown:SetText(text) → self
dropdown:OnSelect(callback) → self
dropdown:SetMenuWidth(width) → self
dropdown:SetMaxLines(lines) → self
dropdown:SetAutoText(enabled) → self
dropdown:Tooltip(text) → self
dropdown:SetEnabled(enabled) → self
```

#### Menu Control Methods

```lua
dropdown:OpenMenu()
dropdown:CloseMenu()
dropdown:Toggle()
```

#### Positioning Methods (inherited from WidgetMod)

```lua
dropdown:Size(width, height) → self
dropdown:Point(...) → self
```

---

## See Also

- [Config.md](Config.md) - Declarative configuration system
- [WindowUtil.md](WindowUtil.md) - Window positioning and layout utilities
- [SavedVariables.md](SavedVariables.md) - Data persistence
