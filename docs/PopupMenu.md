# PopupMenu

Popup context menu system for right-click menus and dropdown alternatives. Provides a flexible, easy-to-use API for creating context menus with icons, separators, submenus, disabled items, and keyboard navigation.

## Features

- **Context Menus**: Right-click popup menus at cursor or anchored to frames
- **Rich Items**: Icons, checkmarks, radio buttons, color-coded text
- **Submenus**: Nested menu hierarchies
- **Separators & Headers**: Visual organization with title headers and separator lines
- **Disabled Items**: Grayed-out, non-clickable items
- **Tooltips**: Hover tooltips for menu items
- **Auto-Positioning**: Stays on screen automatically
- **Click-Outside-to-Close**: Automatic dismissal
- **Keyboard Navigation**: Escape key to close
- **Fluent API**: Builder pattern for easy menu construction

## Usage

### Basic Example

```lua
local menu = LoolibGetSharedPopupMenu()

menu:SetOptions({
    {text = "Edit", value = "edit"},
    {text = "Delete", value = "delete", colorCode = "|cFFFF0000"},
    {isSeparator = true},
    {text = "Cancel", value = "cancel"},
})

menu:OnSelect(function(value, item)
    print("Selected:", value)
end)

menu:ShowAtCursor()
```

### Fluent API

```lua
LoolibPopupMenu()
    :AddTitle("Actions")
    :AddOption("Copy", "copy")
    :AddOption("Paste", "paste")
    :AddSeparator()
    :AddOption("Delete", "delete", {colorCode = "|cFFFF0000"})
    :OnSelect(function(value)
        print("Selected:", value)
    end)
    :ShowAtCursor()
```

### Right-Click Handler

```lua
frame:SetScript("OnMouseDown", function(self, button)
    if button == "RightButton" then
        LoolibPopupMenu()
            :AddOption("Option 1", "opt1")
            :AddOption("Option 2", "opt2")
            :OnSelect(function(value)
                print("Clicked:", value)
            end)
            :ShowAtCursor()
    end
end)
```

## MenuItem Structure

Each menu item is a table with the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `text` | `string` | Display text for the item |
| `value` | `any` | Value passed to callback (defaults to text) |
| `icon` | `string` | Icon texture path or atlas name |
| `iconIsAtlas` | `boolean` | If true, `icon` is treated as atlas name |
| `colorCode` | `string` | WoW color code prefix (e.g., `"\|cFFFF0000"`) |
| `disabled` | `boolean` | Grayed out, not clickable |
| `checked` | `boolean` | Show checkmark |
| `radio` | `boolean` | Radio button style (mutually exclusive) |
| `isTitle` | `boolean` | Bold, non-clickable header |
| `isSeparator` | `boolean` | Horizontal separator line |
| `keepOpen` | `boolean` | Don't close menu when clicked |
| `subMenu` | `table[]` | Nested menu items (same structure) |
| `func` | `function` | Click callback (alternative to menu callback) |
| `tooltip` | `string` | Hover tooltip text |

## API Reference

### Factory Functions

#### `LoolibCreatePopupMenu(parent, name)`

Create a new popup menu instance.

**Parameters:**
- `parent` (Frame, optional): Parent frame (defaults to UIParent)
- `name` (string, optional): Global name for the frame

**Returns:** Frame with LoolibPopupMenuMixin

```lua
local myMenu = LoolibCreatePopupMenu()
```

#### `LoolibGetSharedPopupMenu()`

Get or create the shared popup menu singleton. Use this for simple menus that don't need to be shown simultaneously.

**Returns:** Frame with LoolibPopupMenuMixin

```lua
local menu = LoolibGetSharedPopupMenu()
```

#### `LoolibPopupMenu()`

Create a fluent API builder for popup menus.

**Returns:** LoolibPopupMenuBuilderMixin

```lua
LoolibPopupMenu()
    :AddOption("Item", "value")
    :ShowAtCursor()
```

### LoolibPopupMenuMixin

#### `:SetOptions(options)`

Set the menu options array.

**Parameters:**
- `options` (table[]): Array of MenuItem structures

**Returns:** self (for chaining)

```lua
menu:SetOptions({
    {text = "Option 1", value = 1},
    {text = "Option 2", value = 2},
})
```

#### `:AddOption(option)`

Add a single menu item.

**Parameters:**
- `option` (table): MenuItem structure

**Returns:** self (for chaining)

```lua
menu:AddOption({
    text = "Delete",
    value = "delete",
    colorCode = "|cFFFF0000",
    icon = "Interface\\Icons\\INV_Misc_QuestionMark",
})
```

#### `:AddSeparator()`

Add a horizontal separator line.

**Returns:** self (for chaining)

```lua
menu:AddSeparator()
```

#### `:AddTitle(text)`

Add a title/header item.

**Parameters:**
- `text` (string): Header text

**Returns:** self (for chaining)

```lua
menu:AddTitle("File Options")
```

#### `:OnSelect(callback)`

Set the callback for item selection.

**Parameters:**
- `callback` (function): `function(value, menuItem)` called when an item is clicked

**Returns:** self (for chaining)

```lua
menu:OnSelect(function(value, item)
    print("Selected:", value)
    print("Item text:", item.text)
end)
```

#### `:SetMenuWidth(width)`

Set a fixed menu width.

**Parameters:**
- `width` (number): Width in pixels

**Returns:** self (for chaining)

```lua
menu:SetMenuWidth(250)
```

#### `:ShowAtCursor()`

Show the menu at the cursor position.

```lua
menu:ShowAtCursor()
```

#### `:ShowAt(anchorFrame, anchor, relativeAnchor, xOffset, yOffset)`

Show the menu anchored to a frame.

**Parameters:**
- `anchorFrame` (Frame): Frame to anchor to
- `anchor` (string, optional): Anchor point (default "TOPLEFT")
- `relativeAnchor` (string, optional): Relative anchor point (default "BOTTOMLEFT")
- `xOffset` (number, optional): X offset (default 0)
- `yOffset` (number, optional): Y offset (default 0)

```lua
menu:ShowAt(button, "TOPLEFT", "BOTTOMLEFT", 0, -2)
```

#### `:Close()`

Close the menu and all submenus.

```lua
menu:Close()
```

### LoolibPopupMenuBuilderMixin (Fluent API)

#### `:AddOption(text, value, options)`

Add a menu option.

**Parameters:**
- `text` (string): Display text
- `value` (any): Value for callback
- `options` (table, optional): Additional fields (icon, colorCode, disabled, etc.)

**Returns:** self (for chaining)

```lua
builder:AddOption("Delete", "delete", {
    icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    colorCode = "|cFFFF0000",
    tooltip = "Delete this item",
})
```

#### `:AddSeparator()`

Add a separator.

**Returns:** self (for chaining)

#### `:AddTitle(text)`

Add a title header.

**Parameters:**
- `text` (string): Header text

**Returns:** self (for chaining)

#### `:OnSelect(callback)`

Set the selection callback.

**Parameters:**
- `callback` (function): `function(value, item)`

**Returns:** self (for chaining)

#### `:SetWidth(width)`

Set menu width.

**Parameters:**
- `width` (number): Width in pixels

**Returns:** self (for chaining)

#### `:ShowAtCursor()`

Build and show the menu at cursor.

**Returns:** The menu frame

#### `:ShowAt(anchorFrame, anchor, relativeAnchor, xOffset, yOffset)`

Build and show the menu anchored to a frame.

**Returns:** The menu frame

## Examples

### Icons and Colors

```lua
LoolibPopupMenu()
    :AddOption("Edit", "edit", {
        icon = "Interface\\Icons\\INV_Misc_Note_01",
    })
    :AddOption("Delete", "delete", {
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        colorCode = "|cFFFF0000",
    })
    :ShowAtCursor()
```

### Checkboxes and Radio Buttons

```lua
LoolibPopupMenu()
    :AddTitle("View Options")
    :AddOption("Show Tooltips", "tooltips", {
        checked = true,
        keepOpen = true,
    })
    :AddOption("Show Icons", "icons", {
        checked = false,
        keepOpen = true,
    })
    :AddSeparator()
    :AddTitle("Sort By")
    :AddOption("Name", "name", {radio = true, checked = true})
    :AddOption("Date", "date", {radio = true})
    :AddOption("Size", "size", {radio = true})
    :ShowAtCursor()
```

### Nested Submenus

```lua
LoolibPopupMenu()
    :AddOption("File", nil, {
        subMenu = {
            {text = "New", value = "new"},
            {text = "Open", value = "open"},
            {text = "Save", value = "save"},
        }
    })
    :AddOption("Edit", nil, {
        subMenu = {
            {text = "Copy", value = "copy"},
            {text = "Paste", value = "paste"},
        }
    })
    :OnSelect(function(value)
        print("Action:", value)
    end)
    :ShowAtCursor()
```

### Disabled Items

```lua
LoolibPopupMenu()
    :AddOption("Copy", "copy")
    :AddOption("Paste", "paste", {
        disabled = true,
        tooltip = "Nothing to paste",
    })
    :AddOption("Cut", "cut")
    :OnSelect(function(value)
        print("Action:", value)
    end)
    :ShowAtCursor()
```

### Item-Specific Callbacks

```lua
local menu = LoolibGetSharedPopupMenu()

menu:SetOptions({
    {text = "Quick Save", func = function()
        print("Saved!")
    end},
    {text = "Quick Load", func = function()
        print("Loaded!")
    end},
    {isSeparator = true},
    {text = "Exit", value = "exit"},
})

-- Global callback still works for items without func
menu:OnSelect(function(value)
    if value == "exit" then
        print("Exiting...")
    end
end)

menu:ShowAtCursor()
```

### Multi-Level Nested Menus

```lua
LoolibPopupMenu()
    :AddOption("Transform", nil, {
        subMenu = {
            {text = "Rotate", subMenu = {
                {text = "90° Left", value = "rot_left"},
                {text = "90° Right", value = "rot_right"},
                {text = "180°", value = "rot_180"},
            }},
            {text = "Scale", subMenu = {
                {text = "50%", value = "scale_50"},
                {text = "100%", value = "scale_100"},
                {text = "200%", value = "scale_200"},
            }},
        }
    })
    :OnSelect(function(value)
        print("Transform:", value)
    end)
    :ShowAtCursor()
```

## Pattern: Right-Click Context Menu

```lua
-- Add to any frame for right-click menu
local function AddContextMenu(frame, options)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            local menu = LoolibGetSharedPopupMenu()
            menu:SetOptions(options)
            menu:OnSelect(function(value, item)
                -- Handle selection
                print("Selected:", value)
            end)
            menu:ShowAtCursor()
        end
    end)
end

-- Usage
AddContextMenu(myFrame, {
    {text = "Inspect", value = "inspect"},
    {text = "Trade", value = "trade"},
    {isSeparator = true},
    {text = "Report", value = "report", colorCode = "|cFFFF0000"},
})
```

## Pattern: Dropdown Alternative

```lua
-- Use popup menu as a dropdown
local dropdownButton = CreateFrame("Button", nil, parent)
-- ... set up button appearance ...

dropdownButton:SetScript("OnClick", function(self)
    LoolibPopupMenu()
        :AddOption("Option 1", 1)
        :AddOption("Option 2", 2)
        :AddOption("Option 3", 3)
        :OnSelect(function(value)
            self:SetText("Selected: " .. value)
        end)
        :ShowAt(self, "TOPLEFT", "BOTTOMLEFT", 0, -2)
end)
```

## Best Practices

1. **Use Shared Menu**: For simple menus that don't need to be open simultaneously, use `LoolibGetSharedPopupMenu()` to avoid creating multiple frame instances.

2. **Custom Instances**: Create dedicated menu instances with `LoolibCreatePopupMenu()` when you need multiple menus open at once.

3. **KeepOpen for Toggles**: Use `keepOpen = true` for checkbox-style items to prevent menu dismissal.

4. **Clear Visual Hierarchy**: Use separators and title headers to group related items.

5. **Color Code Sparingly**: Use color codes for emphasis (like delete actions in red), not for every item.

6. **Tooltips for Disabled**: Always add tooltips to disabled items explaining why they're unavailable.

7. **Submenus for Organization**: Use submenus to organize complex option sets, but avoid going more than 2-3 levels deep.

## Performance

- Menu frames are lightweight and created on-demand
- Shared menu singleton reuses the same frame instance
- Items are created when menu is shown and released when hidden
- Automatic cleanup of event handlers and submenus on close
- No frame pooling needed - menu frames are long-lived

## Integration with Loolib

```lua
-- Module access
local Loolib = LibStub("Loolib")
local PopupMenu = Loolib:GetModule("PopupMenu")

-- Factory functions
local menu = PopupMenu.Create()
local shared = PopupMenu.GetShared()
local builder = PopupMenu.Builder()

-- Via UI module
local UI = Loolib:GetModule("UI")
local menu = UI.CreatePopupMenu()
```

## See Also

- [Dropdown.md](Dropdown.md) - Traditional dropdown selector widget
- [WidgetMod.md](WidgetMod.md) - Fluent API pattern for widgets
- [WindowUtil.md](WindowUtil.md) - Window positioning utilities
