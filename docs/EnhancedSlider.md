# EnhancedSlider

Enhanced slider widget with value display, min/max labels, step values, and fluent API. Builds on WoW's native Slider widget with modern conveniences inspired by the MRT addon library.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Factory Function](#factory-function)
- [Configuration Methods](#configuration-methods)
  - [Value Range](#value-range)
  - [Step Control](#step-control)
  - [Value Display](#value-display)
  - [Labels](#labels)
  - [Title](#title)
  - [Callbacks](#callbacks)
  - [Enable/Disable](#enabledisable)
  - [Tooltips](#tooltips)
  - [Appearance](#appearance)
  - [Orientation](#orientation)
- [Utility Methods](#utility-methods)
- [Integration with WidgetMod](#integration-with-widgetmod)
- [Complete Examples](#complete-examples)

## Overview

The EnhancedSlider widget provides a rich, configurable slider control with:

- **Value Display** - Formatted value shown above the slider
- **Min/Max Labels** - Customizable labels for range endpoints
- **Title/Label** - Optional title above the slider
- **Step Control** - Configurable value increments
- **Mouse Wheel** - Scroll to adjust values
- **Right-Click Reset** - Optional default value restoration
- **Tooltips** - Single or multi-line help text
- **Fluent API** - All configuration methods chain for easy setup

## Quick Start

```lua
local Loolib = LibStub("Loolib")

local slider = LoolibCreateEnhancedSlider(parent)
    :Size(200, 20)
    :Point("CENTER")
    :Title("Volume")
    :Range(0, 100)
    :Step(5)
    :SetTo(50)
    :ShowValue("%d%%")
    :ShowLabels("Quiet", "Loud")
    :OnChange(function(self, value, userInput)
        SetMasterVolume(value / 100)
    end)
    :Tooltip("Adjust the master volume")
```

## Factory Function

### LoolibCreateEnhancedSlider

```lua
LoolibCreateEnhancedSlider(parent, name, template)
```

Creates a new enhanced slider widget.

**Parameters:**
- `parent` (Frame) - Parent frame for the slider
- `name` (string, optional) - Global name for the slider frame
- `template` (string, optional) - XML template (defaults to "MinimalSliderTemplate")

**Returns:**
- (Slider) - The created slider with EnhancedSliderMixin applied

**Example:**
```lua
-- Basic creation
local slider = LoolibCreateEnhancedSlider(UIParent)

-- With global name
local namedSlider = LoolibCreateEnhancedSlider(UIParent, "MyAddonSlider")

-- With custom template
local customSlider = LoolibCreateEnhancedSlider(UIParent, nil, "OptionsSliderTemplate")
```

## Configuration Methods

All configuration methods return `self` for method chaining.

### Value Range

#### :Range(min, max)

Sets the minimum and maximum values for the slider.

**Parameters:**
- `min` (number) - Minimum value
- `max` (number) - Maximum value

**Returns:** `self`

**Example:**
```lua
slider:Range(0, 100)       -- 0 to 100
slider:Range(1, 10)        -- 1 to 10
slider:Range(0.5, 2.0)     -- Decimal range
```

#### :GetRange()

Gets the current range values.

**Returns:** `min, max` (number, number)

**Example:**
```lua
local min, max = slider:GetRange()
print(string.format("Range: %d to %d", min, max))
```

### Step Control

#### :Step(step)

Sets the value increment step. Automatically enables `SetObeyStepOnDrag`.

**Parameters:**
- `step` (number) - Step increment

**Returns:** `self`

**Example:**
```lua
slider:Step(1)      -- Integer steps
slider:Step(5)      -- Steps of 5
slider:Step(0.1)    -- Decimal steps
```

#### :GetStep()

Gets the current step value.

**Returns:** `step` (number)

#### :ObeyStepOnDrag(obey)

Controls whether dragging respects the step value.

**Parameters:**
- `obey` (boolean) - True to obey step while dragging

**Returns:** `self`

**Example:**
```lua
slider:Step(10):ObeyStepOnDrag(true)   -- Snap to steps while dragging
slider:Step(10):ObeyStepOnDrag(false)  -- Free drag, snap on release
```

### Value Display

#### :ShowValue(formatString)

Shows the formatted value above the slider.

**Parameters:**
- `formatString` (string, optional) - Printf-style format string (default: "%d")

**Returns:** `self`

**Format Examples:**
```lua
slider:ShowValue("%d")          -- Integer: "50"
slider:ShowValue("%d%%")        -- Percentage: "50%"
slider:ShowValue("%.1f")        -- One decimal: "50.0"
slider:ShowValue("%.2f")        -- Two decimals: "50.00"
slider:ShowValue("%d seconds")  -- With suffix: "50 seconds"
slider:ShowValue("x%.1f")       -- With prefix: "x5.0"
```

#### :HideValue()

Hides the value display.

**Returns:** `self`

#### :ValueFormat(formatString)

Changes the value format string without hiding/showing.

**Parameters:**
- `formatString` (string) - Printf-style format string

**Returns:** `self`

**Example:**
```lua
slider:ShowValue("%d")
-- Later...
slider:ValueFormat("%.1f")  -- Change to decimal display
```

### Labels

#### :ShowLabels(minText, maxText)

Shows min/max labels below the slider.

**Parameters:**
- `minText` (string, optional) - Text for minimum label (defaults to min value)
- `maxText` (string, optional) - Text for maximum label (defaults to max value)

**Returns:** `self`

**Examples:**
```lua
-- Automatic labels (show min/max values)
slider:Range(0, 100):ShowLabels()

-- Custom labels
slider:Range(0, 100):ShowLabels("Off", "Max")
slider:Range(1, 10):ShowLabels("Easy", "Hard")
slider:Range(0.5, 2.0):ShowLabels("Slower", "Faster")
```

#### :HideLabels()

Hides the min/max labels.

**Returns:** `self`

### Title

#### :Title(title)

Sets and shows the slider title above the slider.

**Parameters:**
- `title` (string) - Title text

**Returns:** `self`

**Example:**
```lua
slider:Title("Master Volume")
slider:Title("Difficulty Level")
```

#### :HideTitle()

Hides the slider title.

**Returns:** `self`

### Callbacks

#### :SetTo(value)

Sets the current slider value.

**Parameters:**
- `value` (number) - Value to set

**Returns:** `self`

**Example:**
```lua
slider:SetTo(50)
slider:SetTo(slider._maxValue)  -- Set to max
```

#### :GetTo()

Gets the current slider value.

**Returns:** `value` (number)

**Example:**
```lua
local currentValue = slider:GetTo()
print("Current value:", currentValue)
```

#### :OnChange(callback)

Sets the value changed callback.

**Parameters:**
- `callback` (function) - Callback function with signature: `function(self, value, userInput)`
  - `self` - The slider frame
  - `value` - The new value
  - `userInput` - True if changed by user interaction, false if programmatic

**Returns:** `self`

**Example:**
```lua
slider:OnChange(function(self, value, userInput)
    if userInput then
        print(string.format("User set value to %d", value))
        SaveSetting("volume", value)
    end
end)
```

### Enable/Disable

#### :SetEnabled(enabled)

Enables or disables the slider.

**Parameters:**
- `enabled` (boolean) - True to enable, false to disable

**Returns:** `self`

**Notes:**
- Disabled sliders are shown at 50% alpha
- Mouse and keyboard input is disabled

**Example:**
```lua
slider:SetEnabled(true)   -- Enable
slider:SetEnabled(false)  -- Disable

-- Conditional enable
local hasPermission = UnitIsGroupLeader("player")
slider:SetEnabled(hasPermission)
```

### Tooltips

#### :Tooltip(text)

Sets tooltip text for the slider.

**Parameters:**
- `text` (string|table) - Tooltip text
  - String: Single-line tooltip
  - Table: Multi-line tooltip where first element is the title

**Returns:** `self`

**Examples:**
```lua
-- Single line
slider:Tooltip("Adjust the master volume")

-- Multi-line
slider:Tooltip({
    "Master Volume",
    "Controls all game audio",
    "Use mouse wheel to adjust",
    "Right-click to reset to default"
})
```

#### :TooltipAnchor(anchor)

Sets the tooltip anchor point.

**Parameters:**
- `anchor` (string) - Anchor point (e.g., "ANCHOR_RIGHT", "ANCHOR_TOP", "ANCHOR_CURSOR")

**Returns:** `self`

**Example:**
```lua
slider:TooltipAnchor("ANCHOR_TOP")
```

### Appearance

#### :Font(font, size, flags)

Sets the font for all text elements.

**Parameters:**
- `font` (string) - Font path
- `size` (number, optional) - Font size (default: 10 for labels, 12 for title)
- `flags` (string, optional) - Font flags ("OUTLINE", "THICKOUTLINE", "MONOCHROME")

**Returns:** `self`

**Example:**
```lua
slider:Font("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
```

#### :FontSize(size)

Sets font size for all text elements.

**Parameters:**
- `size` (number) - Font size in points

**Returns:** `self`

**Note:** Title is rendered 2 points larger than the specified size.

**Example:**
```lua
slider:FontSize(10)  -- Labels at 10pt, title at 12pt
```

#### :TextColor(r, g, b, a)

Sets text color for all label text (value, min/max labels).

**Parameters:**
- `r` (number) - Red component (0-1)
- `g` (number) - Green component (0-1)
- `b` (number) - Blue component (0-1)
- `a` (number, optional) - Alpha component (0-1, default: 1)

**Returns:** `self`

**Example:**
```lua
slider:TextColor(1, 0.8, 0)        -- Gold
slider:TextColor(1, 0, 0, 0.8)     -- Semi-transparent red
slider:TextColor(0.5, 0.5, 0.5)    -- Gray
```

### Orientation

#### :Orientation(orientation)

Sets slider orientation and adjusts label positions accordingly.

**Parameters:**
- `orientation` (string) - "HORIZONTAL" or "VERTICAL"

**Returns:** `self`

**Notes:**
- Horizontal (default):
  - Min label at bottom-left
  - Max label at bottom-right
  - Value display above slider
- Vertical:
  - Min label at bottom
  - Max label at top
  - Value display to the right

**Example:**
```lua
local vSlider = LoolibCreateEnhancedSlider(parent)
    :Size(20, 200)
    :Orientation("VERTICAL")
    :Range(0, 100)
    :ShowValue()
```

## Utility Methods

### :SetDefault(defaultValue)

Sets a default value and enables right-click reset.

**Parameters:**
- `defaultValue` (number) - Default value to reset to

**Returns:** `self`

**Behavior:**
- Right-click and hold: Preview reset value
- Right-click release: Return to current value
- User can drag while holding right-click to cancel reset

**Example:**
```lua
slider:Range(0, 100):SetTo(75):SetDefault(75)
-- Right-clicking will reset to 75
```

### :Run(func, ...)

Executes a function with the slider as the first argument, then returns the slider for continued chaining.

**Parameters:**
- `func` (function) - Function to execute
- `...` - Additional arguments to pass to the function

**Returns:** `self`

**Example:**
```lua
slider:Run(function(self, customData)
    self._customProperty = customData
    print("Custom setup complete for", self:GetName())
end, "myData")
```

## Integration with WidgetMod

If the WidgetMod module is available, EnhancedSlider automatically inherits all WidgetMod methods:

**Inherited Methods:**
- `:Size(width, height)` - Set dimensions
- `:Width(width)` - Set width only
- `:Height(height)` - Set height only
- `:Point(...)` - Smart SetPoint with multiple patterns
- `:NewPoint(...)` - Clear points and set new one
- `:ClearPoints()` - Clear all anchor points
- `:Alpha(alpha)` - Set transparency
- `:Scale(scale)` - Set scale
- `:Shown(bool)` - Conditional show/hide
- `:ShowFrame()` / `:HideFrame()` - Show or hide
- `:FrameLevel(level)` - Set frame level
- `:FrameStrata(strata)` - Set frame strata
- `:Mouse(enable)` - Enable/disable mouse
- `:MouseWheel(enable)` - Enable/disable mouse wheel
- `:Parent(parent)` - Set parent frame

**Example:**
```lua
slider:Size(250, 20)
    :Point("CENTER", 0, 100)
    :Alpha(0.9)
    :FrameStrata("MEDIUM")
```

## Complete Examples

### Example 1: Volume Control

```lua
local volumeSlider = LoolibCreateEnhancedSlider(settingsPanel)
    :Size(300, 20)
    :Point("TOP", 0, -50)
    :Title("Master Volume")
    :Range(0, 100)
    :Step(5)
    :SetTo(GetCVar("Sound_MasterVolume") * 100)
    :ShowValue("%d%%")
    :ShowLabels("Mute", "Max")
    :OnChange(function(self, value, userInput)
        if userInput then
            SetCVar("Sound_MasterVolume", value / 100)
        end
    end)
    :Tooltip({
        "Master Volume",
        "Controls all game audio output",
        "Use mouse wheel for fine control",
        "Right-click to reset to default (75%)"
    })
    :SetDefault(75)
```

### Example 2: Difficulty Selector

```lua
local difficultySlider = LoolibCreateEnhancedSlider(configFrame)
    :Size(250, 20)
    :Point("TOP", 0, -100)
    :Title("Difficulty")
    :Range(1, 5)
    :Step(1)
    :SetTo(3)
    :ShowValue()
    :ShowLabels("Easy", "Brutal")
    :OnChange(function(self, value, userInput)
        if userInput then
            local labels = {"Trivial", "Easy", "Normal", "Hard", "Brutal"}
            self.valueText:SetText(labels[value])
            SetDifficulty(value)
        end
    end)
    :Tooltip("Select game difficulty level")

-- Trigger initial display
difficultySlider:_OnValueChanged(difficultySlider:GetValue(), false)
```

### Example 3: Damage Multiplier (Decimal)

```lua
local damageSlider = LoolibCreateEnhancedSlider(debugPanel)
    :Size(300, 20)
    :Point("CENTER")
    :Title("Damage Multiplier")
    :Range(0.1, 5.0)
    :Step(0.1)
    :SetTo(1.0)
    :ShowValue("%.1fx")
    :ShowLabels("10%", "500%")
    :OnChange(function(self, value, userInput)
        if userInput then
            MyAddon:SetDamageMultiplier(value)
            print(string.format("Damage multiplier set to %.1fx", value))
        end
    end)
    :Tooltip("Adjust damage output multiplier for testing")
    :SetDefault(1.0)
    :TextColor(1, 0.5, 0)  -- Orange text
```

### Example 4: Cooldown Timer

```lua
local cooldownSlider = LoolibCreateEnhancedSlider(abilityFrame)
    :Size(200, 20)
    :Point("BOTTOM", 0, 50)
    :Title("Cooldown Duration")
    :Range(1, 300)
    :Step(1)
    :SetTo(60)
    :ShowValue()
    :OnChange(function(self, value, userInput)
        if userInput then
            -- Custom value formatting
            if value < 60 then
                self.valueText:SetText(string.format("%d sec", value))
            else
                local minutes = math.floor(value / 60)
                local seconds = value % 60
                if seconds == 0 then
                    self.valueText:SetText(string.format("%d min", minutes))
                else
                    self.valueText:SetText(string.format("%d:%02d", minutes, seconds))
                end
            end
            SetAbilityCooldown(value)
        end
    end)
    :ShowLabels("1 sec", "5 min")

-- Trigger initial format
cooldownSlider:_OnValueChanged(cooldownSlider:GetValue(), false)
```

### Example 5: RGB Color Picker

```lua
local colorFrame = CreateFrame("Frame", nil, UIParent)
colorFrame:SetSize(300, 200)
colorFrame:SetPoint("CENTER")

local colorPreview = colorFrame:CreateTexture(nil, "ARTWORK")
colorPreview:SetSize(60, 60)
colorPreview:SetPoint("TOPRIGHT", colorFrame, "TOPRIGHT", -10, -10)

local function UpdateColor(userInput)
    local r = rSlider:GetValue() / 255
    local g = gSlider:GetValue() / 255
    local b = bSlider:GetValue() / 255
    colorPreview:SetColorTexture(r, g, b)

    if userInput then
        MyAddon:SaveColor(r, g, b)
    end
end

local rSlider = LoolibCreateEnhancedSlider(colorFrame)
    :Size(200, 16)
    :Point("TOPLEFT", 10, -10)
    :Title("Red")
    :Range(0, 255)
    :Step(1)
    :SetTo(255)
    :ShowValue("%d")
    :OnChange(function(self, value, userInput) UpdateColor(userInput) end)
    :TextColor(1, 0.5, 0.5)

local gSlider = LoolibCreateEnhancedSlider(colorFrame)
    :Size(200, 16)
    :Point("TOP", rSlider, "BOTTOM", 0, -40)
    :Title("Green")
    :Range(0, 255)
    :Step(1)
    :SetTo(128)
    :ShowValue("%d")
    :OnChange(function(self, value, userInput) UpdateColor(userInput) end)
    :TextColor(0.5, 1, 0.5)

local bSlider = LoolibCreateEnhancedSlider(colorFrame)
    :Size(200, 16)
    :Point("TOP", gSlider, "BOTTOM", 0, -40)
    :Title("Blue")
    :Range(0, 255)
    :Step(1)
    :SetTo(64)
    :ShowValue("%d")
    :OnChange(function(self, value, userInput) UpdateColor(userInput) end)
    :TextColor(0.5, 0.5, 1)

-- Initialize color preview
UpdateColor(false)
```

### Example 6: Vertical Slider

```lua
local verticalSlider = LoolibCreateEnhancedSlider(sidePanel)
    :Size(20, 250)
    :Point("LEFT", 30, 0)
    :Orientation("VERTICAL")
    :Range(0, 100)
    :Step(5)
    :SetTo(50)
    :ShowValue("%d%%")
    :ShowLabels("0%", "100%")
    :OnChange(function(self, value, userInput)
        if userInput then
            AdjustHeight(value)
        end
    end)
    :Tooltip("Adjust height percentage")
```

## Mouse Interactions

### Built-in Mouse Support

- **Click and Drag** - Adjust value (respects step if `ObeyStepOnDrag` is true)
- **Mouse Wheel** - Increment/decrement by step value
- **Right-Click Hold** - Preview default value (if `SetDefault` was called)
- **Right-Click Release** - Return to current value
- **Hover** - Show tooltip (if set)

### Custom Mouse Handlers

You can add additional mouse handlers if needed:

```lua
slider:SetScript("OnMouseDown", function(self, button)
    if button == "MiddleButton" then
        -- Custom middle-click behavior
        self:SetValue((self._minValue + self._maxValue) / 2)
    end
end)
```

## Best Practices

1. **Always set Range before SetTo** - Ensures the initial value is valid
   ```lua
   slider:Range(0, 100):SetTo(50)  -- Correct
   ```

2. **Use Step for discrete values** - Makes the slider easier to use
   ```lua
   slider:Range(0, 100):Step(5)  -- Snap to 0, 5, 10, 15...
   ```

3. **Check userInput in OnChange** - Prevent feedback loops
   ```lua
   :OnChange(function(self, value, userInput)
       if userInput then
           -- Only save on user interaction
           SaveSetting(value)
       end
   end)
   ```

4. **Use descriptive labels** - Better UX than just numbers
   ```lua
   slider:ShowLabels("Off", "Max")     -- Good
   slider:ShowLabels("0", "100")       -- Less helpful
   ```

5. **Provide tooltips** - Help users understand what the slider does
   ```lua
   slider:Tooltip({
       "Setting Name",
       "What it does",
       "Special notes"
   })
   ```

6. **Set meaningful defaults** - Let users easily reset
   ```lua
   slider:SetTo(75):SetDefault(75)
   ```

## Performance Notes

- Text updates are throttled to `OnValueChanged` only
- Font string creation happens once in `OnLoad`
- No memory leaks - all child frames are parented correctly
- Mouse wheel is enabled by default but can be disabled via `MouseWheel(false)` if WidgetMod is available

## Related Modules

- **[WidgetMod](WidgetMod.md)** - Fluent API methods inherited by EnhancedSlider
- **[WindowUtil](WindowUtil.md)** - Window positioning utilities that work with sliders
- **[Config](Config.md)** - Configuration system that can use EnhancedSlider for range options
