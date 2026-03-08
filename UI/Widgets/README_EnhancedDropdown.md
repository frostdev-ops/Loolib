# EnhancedDropdown Widget

## Implementation Summary

Advanced dropdown widget for WoW 12.0+ with sophisticated menu features inspired by MRT's dropdown system.

## Files Created

1. **EnhancedDropdown.lua** - Main implementation (682 lines)
2. **EnhancedDropdown_Example.lua** - Usage examples with 8 demos
3. **docs/EnhancedDropdown.md** - Complete documentation

## Features Implemented

### Core Features
- Multi-level nested submenus with automatic positioning
- Icons (texture paths or atlas names) with custom tex coords
- Color-coded text with WoW color codes
- Section headers (non-selectable titles)
- Horizontal separators for visual grouping
- Disabled items (grayed out, non-interactive)
- Tooltips on hover

### Advanced Controls (MRT-inspired)
- **Embedded sliders** - Range controls with min/max/step/callback
- **Embedded editboxes** - Text input fields with callbacks
- **Checkboxes** - Toggle states with change callbacks
- **Radio buttons** - Single-selection indicators

### Smart Behavior
- Auto-text update on selection (configurable)
- Click-outside detection to close menu
- Automatic submenu positioning to the right
- Deep value search across nested submenus
- Prevents selection of items with submenus

### Fluent API Integration
- All configuration methods return `self` for chaining
- Automatic WidgetMod mixin application
- Smart Size/Point methods

## Quick Start

```lua
local dropdown = LoolibCreateEnhancedDropdown(parent)
    :Size(200, 28)
    :Point("CENTER")
    :SetList({
        {text = "Settings", isTitle = true},
        {isSeparator = true},
        {text = "Volume", slider = {0, 100, 50, function(v) SetVolume(v) end}},
        {text = "Enable Sound", checkState = true, onCheckChange = function(v) ToggleSound(v) end},
        {isSeparator = true},
        {text = "Presets", subMenu = {
            {text = "Low", value = "low"},
            {text = "Medium", value = "med"},
            {text = "High", value = "high"},
        }},
    })
    :OnSelect(function(value, option)
        print("Selected:", value)
    end)
```

## API Highlights

### Configuration
- `SetList(options)` - Set all dropdown options
- `AddOption(option)` - Add single option
- `SetValue(value)` - Set selected value
- `OnSelect(callback)` - Register selection callback
- `SetMenuWidth(width)` - Custom menu width
- `SetAutoText(enabled)` - Toggle auto-text update

### Menu Control
- `OpenMenu()` - Open programmatically
- `CloseMenu()` - Close programmatically
- `Toggle()` - Toggle open/closed

### Layout
- `Size(width, height)` - Set dropdown size
- `Point(...)` - Set anchor point
- `SetEnabled(enabled)` - Enable/disable

## Option Structure

```lua
{
    -- Basic
    text = "Label",
    value = any,

    -- Visual
    icon = "path",
    iconIsAtlas = bool,
    colorCode = "|cFFRRGGBB",

    -- State
    disabled = bool,
    isTitle = bool,
    isSeparator = bool,
    tooltip = "text",

    -- Nesting
    subMenu = {...},

    -- Embedded controls
    slider = {min, max, val, cb, step},
    editBox = {text, cb, width},

    -- Checkboxes
    checkState = bool,
    onCheckChange = function,

    -- Advanced
    font = "FontObject",
    padding = number,
}
```

## Testing

Run the example file to test all features:

```lua
-- In-game slash command
/testdropdown
```

This creates a test frame with 8 different dropdown examples demonstrating:
1. Basic dropdown
2. Icons
3. Submenus
4. Checkboxes
5. Embedded controls (slider + editbox)
6. Color-coded options
7. Full-featured complex dropdown
8. Fluent API usage

## Technical Details

### Frame Structure
```
EnhancedDropdown (Button)
├── backdrop (background + border)
├── icon (optional, left side)
├── text (label FontString)
├── arrow (up/down indicator)
└── highlight (mouse hover effect)

MenuFrame (Frame)
├── backdrop (background + border)
└── content (Frame)
    └── items[] (Button[])
        ├── highlight
        ├── check (checkbox/radio)
        ├── icon (optional)
        ├── text (FontString)
        ├── arrow (submenu indicator)
        ├── slider (optional)
        └── editBox (optional)

SubmenuFrame (Frame, same structure as MenuFrame)
```

### Menu Building
- Dynamically creates menu items on each open
- Calculates total height based on items + padding
- Reuses item frames when reopening
- Automatic submenu positioning on hover

### Click-Outside Detection
- OnUpdate script polls mouse state every 0.1s
- Checks if mouse is over dropdown, menu, or submenu
- Closes after 0.05s delay to prevent flicker

## Integration with Loolib

Registered as module:
```lua
local Loolib = LibStub("Loolib")
local EnhancedDropdown = Loolib:GetModule("EnhancedDropdown")

-- Create instance
local dropdown = EnhancedDropdown.Create(parent)

-- Access mixin
local mixin = EnhancedDropdown.Mixin
```

## Comparison to Standard Dropdown

| Feature | Standard Dropdown | EnhancedDropdown |
|---------|------------------|------------------|
| Basic options | Yes | Yes |
| Icons | Yes | Yes |
| Submenus | Yes | Yes |
| Checkboxes | Yes | Yes |
| **Embedded sliders** | No | **Yes** |
| **Embedded editboxes** | No | **Yes** |
| Color codes | Yes | Yes |
| Separators | Yes | Yes |
| Tooltips | Yes | Yes |
| Fluent API | Builder pattern | **Built-in** |

## Known Limitations

1. **No scrollbar** - Long menus are height-limited by `SetMaxLines()` but don't scroll
2. **Single submenu level** - Submenus don't support further nesting (submenu items with submenus won't render correctly)
3. **Fixed submenu positioning** - Always opens to the right, doesn't check screen bounds
4. **No search/filter** - Can't filter long lists dynamically

## Future Enhancements

- [ ] Add scrollbar support for long menus
- [ ] Support multi-level submenu nesting
- [ ] Smart submenu positioning (check screen bounds)
- [ ] Search/filter functionality
- [ ] Keyboard navigation (arrow keys)
- [ ] Option icons on the right side
- [ ] Custom item height per option
- [ ] Animation on open/close

## Performance Notes

- Menu items are created on-demand when menu opens
- Items are hidden (not destroyed) when menu closes
- Submenu frame is reused across all submenu displays
- OnUpdate polling runs only when menu is open
- No event registrations or permanent allocations

## License

Part of Loolib - WoW 12.0+ Addon Library
