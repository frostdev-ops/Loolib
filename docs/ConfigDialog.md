# Loolib ConfigDialog Reference

Comprehensive documentation for the ConfigDialog GUI rendering system.

## Table of Contents

1. [Overview](#overview)
2. [Dialog Lifecycle](#dialog-lifecycle)
3. [Layout Types](#layout-types)
4. [Opening and Closing Dialogs](#opening-and-closing-dialogs)
5. [Navigation](#navigation)
6. [Widget Rendering](#widget-rendering)
7. [Widget Pooling](#widget-pooling)
8. [Blizzard Settings Integration](#blizzard-settings-integration)
9. [Styling and Appearance](#styling-and-appearance)
10. [Events](#events)
11. [API Reference](#api-reference)
12. [Customization](#customization)
13. [Troubleshooting](#troubleshooting)

---

## Overview

The ConfigDialog module transforms declarative options tables into interactive graphical user interfaces. It handles:

- Dialog window creation and management
- Layout rendering (tree, tab, inline)
- Widget creation for all option types
- User interaction handling
- Integration with WoW's Settings panel
- Performance optimization through widget pooling

### Architecture

```
+----------------------------------+
|         ConfigDialog             |
|----------------------------------|
| Dialog Management                |
|   - Create/Open/Close dialogs    |
|   - Track active dialogs         |
|----------------------------------|
| Layout System                    |
|   - Tree layout (sidebar + content)|
|   - Tab layout (tabs + content)  |
|   - Simple layout (content only) |
|----------------------------------|
| Widget Rendering                 |
|   - Type-specific renderers      |
|   - Widget pooling               |
|   - Event binding                |
|----------------------------------|
| Blizzard Integration             |
|   - Settings panel registration  |
|   - Category management          |
+----------------------------------+
```

### Module Access

```lua
local Loolib = LibStub("Loolib")
local ConfigDialogModule = Loolib:GetModule("ConfigDialog")
local Dialog = ConfigDialogModule.Dialog  -- Singleton instance

-- Or through LoolibConfig
LoolibConfig:Open("MyAddon")
```

---

## Dialog Lifecycle

### Creation Flow

```
RegisterOptionsTable()
        |
        v
    Open(appName)
        |
        +-- Check if dialog exists
        |       |
        |       +-- Yes: Show existing
        |       |
        |       +-- No: CreateDialog()
        |               |
        |               +-- Create frame
        |               +-- Apply backdrop
        |               +-- Create title
        |               +-- Create close button
        |               +-- Create layout (tree/tab/simple)
        |               +-- Initial render
        |
        v
    RefreshContent()
        |
        +-- Render navigation (tree/tabs)
        +-- Get selected group
        +-- Render options widgets
        |
        v
    Dialog shown
```

### Dialog Structure

```
+--------------------------------------------------+
|  Title                                       [X] |
+--------------------------------------------------+
|  +----------+  +-----------------------------+   |
|  | Tree     |  | Content Area               |   |
|  | Nav      |  |                            |   |
|  |          |  | [Options render here]       |   |
|  | > Gen    |  |                            |   |
|  | > App    |  |                            |   |
|  | > Adv    |  |                            |   |
|  |          |  |                            |   |
|  +----------+  +-----------------------------+   |
+--------------------------------------------------+
```

### State Management

```lua
-- Dialog state stored per app
self.dialogs = {}          -- appName -> dialog frame
self.selectedPaths = {}    -- appName -> current selected path
self.blizPanels = {}       -- appName -> Blizzard settings panel
self.defaultSizes = {}     -- appName -> {width, height}
```

---

## Layout Types

### Tree Layout (Default)

Used when `childGroups = "tree"` (or default).

```lua
local options = {
    type = "group",
    name = "My Addon",
    childGroups = "tree",  -- Or omit for default
    args = { ... }
}
```

**Visual Structure:**
```
+-------+-------------------+
| Tree  | Content           |
+-------+-------------------+
|General| Group Title       |
|  +-Dis| Description...    |
|  +-Col|                   |
|Appear | [x] Option 1      |
|Modules| [x] Option 2      |
|       | Scale: [===|==]   |
+-------+-------------------+
```

**Characteristics:**
- Left sidebar (180px default) with scrollable tree
- Right content area with scrollable options
- Supports nested groups (indented in tree)
- Selected group highlighted in tree

### Tab Layout

Used when `childGroups = "tab"`.

```lua
local options = {
    type = "group",
    name = "My Addon",
    childGroups = "tab",
    args = { ... }
}
```

**Visual Structure:**
```
+---------------------------+
| [Gen] [Appear] [Modules]  |
+---------------------------+
| Group Title               |
| Description...            |
|                           |
| [x] Option 1              |
| [x] Option 2              |
| Scale: [===|==]           |
+---------------------------+
```

**Characteristics:**
- Horizontal tabs at top
- Selected tab highlighted
- Good for 3-5 top-level groups
- Not nested (only first level shows as tabs)

### Simple Layout

Used when no child groups or `childGroups = "select"`.

```lua
local options = {
    type = "group",
    name = "My Addon",
    childGroups = "select",  -- Or no child groups
    args = { ... }
}
```

**Visual Structure:**
```
+---------------------------+
| Content fills entire      |
| dialog area               |
|                           |
| Options render directly   |
+---------------------------+
```

### Inline Groups

Groups with `inline = true` render within their parent:

```lua
appearance = {
    type = "group",
    name = "Appearance",
    args = {
        colors = {
            type = "group",
            name = "Colors",
            inline = true,
            args = {
                background = { type = "color", name = "Background" },
                text = { type = "color", name = "Text" },
            },
        },
    },
}
```

**Visual Structure:**
```
+-----------------------------+
| Appearance                  |
+-----------------------------+
| +-------------------------+ |
| | Colors                  | |
| | Background: [##]        | |
| | Text: [##]              | |
| +-------------------------+ |
+-----------------------------+
```

---

## Opening and Closing Dialogs

### Opening

```lua
-- Basic open
LoolibConfig:Open("MyAddon")

-- Open to specific group
LoolibConfig:Open("MyAddon", "appearance")

-- Open to nested group
LoolibConfig:Open("MyAddon", "appearance", "colors")

-- Direct dialog access
local dialog = ConfigDialogModule.Dialog:Open("MyAddon", nil, "appearance")
```

### Closing

```lua
-- Close specific dialog
LoolibConfig:Close("MyAddon")

-- Close all dialogs
LoolibConfig:Close()

-- Direct access
ConfigDialogModule.Dialog:Close("MyAddon")
ConfigDialogModule.Dialog:CloseAll()
```

### Dialog Visibility

```lua
local dialog = ConfigDialogModule.Dialog.dialogs["MyAddon"]
if dialog and dialog:IsShown() then
    -- Dialog is visible
end
```

### Custom Container

Open within a parent frame:

```lua
local myFrame = CreateFrame("Frame", nil, UIParent)
myFrame:SetSize(800, 600)
myFrame:SetPoint("CENTER")

-- Dialog will be embedded in myFrame
local dialog = ConfigDialogModule.Dialog:Open("MyAddon", myFrame)
```

---

## Navigation

### Selecting Groups

```lua
-- Navigate to group
LoolibConfig:Open("MyAddon", "appearance")

-- After dialog open, change selection
ConfigDialogModule.Dialog:SelectGroup("MyAddon", "modules")

-- Navigate to nested group
ConfigDialogModule.Dialog:SelectGroup("MyAddon", "appearance", "colors")
```

### Getting Current Selection

```lua
local currentPath = ConfigDialogModule.Dialog.selectedPaths["MyAddon"]
-- currentPath = {"appearance", "colors"} or {}
```

### Programmatic Navigation

```lua
-- Build your own navigation
local function GoToOption(appName, ...)
    local Dialog = ConfigDialogModule.Dialog

    -- Ensure dialog is open
    if not Dialog.dialogs[appName] or not Dialog.dialogs[appName]:IsShown() then
        Dialog:Open(appName, nil, ...)
    else
        Dialog:SelectGroup(appName, ...)
    end
end
```

### Navigation Events

```lua
ConfigDialogModule.Dialog:RegisterCallback("OnGroupSelected", function(appName, ...)
    local path = {...}
    print("Selected:", table.concat(path, " > "))
end)
```

---

## Widget Rendering

### Rendering Pipeline

```
RenderOptions(dialog, group, rootOptions, registry, path)
    |
    +-- Release existing widgets
    |
    +-- Render group header (if path > 0)
    |
    +-- Render group description
    |
    +-- For each option in sorted order:
            |
            +-- Skip if hidden
            |
            +-- If inline group: RenderInlineGroup()
            |
            +-- Else: RenderWidget()
                    |
                    +-- Dispatch to type-specific renderer:
                        - RenderHeader()
                        - RenderDescription()
                        - RenderToggle()
                        - RenderInput()
                        - RenderRange()
                        - RenderSelect()
                        - RenderMultiSelect()
                        - RenderColor()
                        - RenderExecute()
                        - RenderKeybinding()
                        - RenderTexture()
                        - RenderFont()
```

### Type-Specific Renderers

Each option type has a dedicated render function:

| Renderer | Creates | Notes |
|----------|---------|-------|
| `RenderHeader` | FontString + Line | Section divider |
| `RenderDescription` | FontString | Static text, optional image |
| `RenderToggle` | CheckButton | UICheckButtonTemplate |
| `RenderInput` | EditBox + Label | BackdropTemplate for border |
| `RenderRange` | Slider + Label + Value | OptionsSliderTemplate |
| `RenderSelect` | Button + Popup Menu | Custom dropdown |
| `RenderMultiSelect` | Multiple CheckButtons | Grid layout |
| `RenderColor` | Button + Swatch | Opens ColorPickerFrame |
| `RenderExecute` | Button | UIPanelButtonTemplate |
| `RenderKeybinding` | Button + Capture | Custom capture logic |
| `RenderTexture` | Frame + Texture | Optional selection |
| `RenderFont` | Button + Popup Menu | Font preview in items |

### Widget Width Calculation

```lua
local WIDTH_MULTIPLIERS = {
    half = 0.5,
    normal = 1.0,
    double = 2.0,
    full = 3.0,
}

-- Calculation
local widthMod = WIDTH_MULTIPLIERS[option.width] or WIDTH_MULTIPLIERS.normal
if option.width == "full" then
    widthMod = contentWidth / LABEL_WIDTH
elseif type(option.width) == "number" then
    widthMod = option.width
end
```

### Layout Constants

```lua
local DIALOG_WIDTH = 700
local DIALOG_HEIGHT = 500
local TREE_WIDTH = 180
local CONTENT_PADDING = 16
local WIDGET_SPACING = 8
local LABEL_WIDTH = 200
```

---

## Widget Pooling

ConfigDialog uses frame pools to optimize performance.

### Pool Architecture

```lua
self.widgetPools = {}  -- type -> { inactive = {} }

-- Acquire from pool
function LoolibConfigDialogMixin:AcquireWidget(widgetType, parent, template, frameTypeOverride)
    local pool = self.widgetPools[widgetType]
    if not pool then
        pool = { inactive = {} }
        self.widgetPools[widgetType] = pool
    end

    local widget = table.remove(pool.inactive)
    if not widget then
        -- Create new widget
        widget = CreateFrame(frameType, nil, parent, template)
        widget.pooledWidgetType = widgetType
    end

    -- Reset and return
    widget:SetParent(parent)
    widget:Show()
    widget:ClearAllPoints()
    return widget
end
```

### Releasing Widgets

```lua
function LoolibConfigDialogMixin:ReleaseWidgets(container)
    local children = {container:GetChildren()}
    for _, child in ipairs(children) do
        -- Recursively release children
        self:ReleaseWidgets(child)

        if child.pooledWidgetType and self.widgetPools[child.pooledWidgetType] then
            -- Clean up scripts
            child:Hide()
            child:ClearAllPoints()
            child:SetScript("OnEnter", nil)
            child:SetScript("OnLeave", nil)
            child:SetScript("OnClick", nil)
            -- ... more cleanup

            -- Return to pool
            table.insert(pool.inactive, child)
        end
    end
end
```

### Widget Types in Pool

- `"button"`
- `"checkbutton"`
- `"editbox"`
- `"slider"`
- `"scrollframe"`
- `"group_frame"` (for inline groups)

---

## Blizzard Settings Integration

### Adding to Settings

```lua
-- Add to root of Settings > Addons
LoolibConfig:AddToBlizOptions("MyAddon", "My Addon")

-- Add as sub-category
LoolibConfig:AddToBlizOptions("MyAddon", "Combat Module", "My Addon")

-- With path to specific group
LoolibConfig:AddToBlizOptions("MyAddon", "Colors", "My Addon", "appearance", "colors")
```

### Panel Creation

```lua
function LoolibConfigDialogMixin:AddToBlizOptions(appName, name, parent, ...)
    -- Create settings panel frame
    local panel = CreateFrame("Frame", "LoolibBlizPanel_" .. appName, UIParent)
    panel.name = name or appName

    -- OnShow creates content
    panel:SetScript("OnShow", function(self)
        if not self.initialized then
            self.initialized = true
            -- Create title, description, "Open Config" button
        end
    end)

    -- Register with WoW 10.0+ Settings API
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category
        if parent then
            local parentCategory = Settings.GetCategory(parent)
            if parentCategory then
                category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, panel.name)
            end
        end
        if not category then
            category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        end
        Settings.RegisterAddOnCategory(category)
    else
        -- Legacy InterfaceOptions fallback
        if parent then panel.parent = parent end
        InterfaceOptions_AddCategory(panel)
    end

    return panel
end
```

### Settings Panel Content

The Blizzard Settings panel shows:
1. Addon title
2. Description (from options.desc)
3. "Open Config" button - opens full dialog

### Opening Settings Programmatically

```lua
-- WoW 10.0+
Settings.OpenToCategory("My Addon")

-- Legacy
InterfaceOptionsFrame_OpenToCategory("My Addon")
```

---

## Styling and Appearance

### Dialog Backdrop

```lua
dialog:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = {left = 11, right = 12, top = 12, bottom = 11}
})
```

### Tree Container Backdrop

```lua
treeContainer:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 3, right = 3, top = 3, bottom = 3}
})
treeContainer:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
treeContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
```

### Content Container Backdrop

```lua
optionsContainer:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 3, right = 3, top = 3, bottom = 3}
})
optionsContainer:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
optionsContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
```

### Inline Group Styling

```lua
groupFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = {left = 2, right = 2, top = 2, bottom = 2}
})
groupFrame:SetBackdropColor(0.15, 0.15, 0.2, 0.5)
groupFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
```

### Custom Dialog Size

```lua
-- Before opening
ConfigDialogModule.Dialog:SetDefaultSize("MyAddon", 800, 600)

-- Then open
LoolibConfig:Open("MyAddon")
```

### Color Scheme

| Element | Color |
|---------|-------|
| Background | `(0.1, 0.1, 0.1)` |
| Tree background | `(0.1, 0.1, 0.1, 0.8)` |
| Content background | `(0.1, 0.1, 0.1, 0.6)` |
| Inline group | `(0.15, 0.15, 0.2, 0.5)` |
| Border | `(0.4, 0.4, 0.4)` to `(0.6, 0.6, 0.6)` |
| Selection highlight | `(0.2, 0.4, 0.6, 0.8)` |
| Hover highlight | `(0.3, 0.3, 0.5, 0.5)` |
| Header text | Gold `(1, 0.82, 0)` |
| Selected text | Yellow `(1, 1, 0)` |
| Disabled text | Gray `(0.5, 0.5, 0.5)` |

---

## Events

### Available Events

| Event | Parameters | Description |
|-------|------------|-------------|
| `OnDialogOpened` | appName | Dialog opened |
| `OnDialogClosed` | appName | Dialog closed |
| `OnGroupSelected` | appName, path... | Group navigation |
| `OnOptionChanged` | appName, path..., value | Option value changed |

### Registering for Events

```lua
local Dialog = ConfigDialogModule.Dialog

-- On dialog open
Dialog:RegisterCallback("OnDialogOpened", function(appName)
    print("Config opened for:", appName)
end)

-- On dialog close
Dialog:RegisterCallback("OnDialogClosed", function(appName)
    print("Config closed for:", appName)
end)

-- On navigation
Dialog:RegisterCallback("OnGroupSelected", function(appName, ...)
    local path = {...}
    print("Navigated to:", table.concat(path, " > "))
end)

-- With specific owner
local myFrame = CreateFrame("Frame")
Dialog:RegisterCallback("OnDialogOpened", function(appName)
    -- Handler code
end, myFrame)

-- Unregister
Dialog:UnregisterCallback("OnDialogOpened", myFrame)
```

### Config Table Change

The dialog also listens for config changes:

```lua
-- Trigger refresh when options change
LoolibConfig:NotifyChange("MyAddon")

-- Or directly
ConfigRegistryModule.Registry:NotifyChange("MyAddon")
```

---

## API Reference

### LoolibConfigDialogMixin

The dialog singleton instance provides these methods:

#### Init

```lua
function LoolibConfigDialogMixin:Init()
```
Initialize the dialog system. Called automatically.

#### Open

```lua
function LoolibConfigDialogMixin:Open(appName, container, ...)
```
Open configuration dialog.

| Parameter | Type | Description |
|-----------|------|-------------|
| `appName` | string | Registered app name |
| `container` | Frame | Optional parent (nil = standalone) |
| `...` | strings | Optional path to group |

Returns: `Frame` - Dialog frame

#### Close

```lua
function LoolibConfigDialogMixin:Close(appName)
```
Close dialog for specific app.

#### CloseAll

```lua
function LoolibConfigDialogMixin:CloseAll()
```
Close all open dialogs.

#### SelectGroup

```lua
function LoolibConfigDialogMixin:SelectGroup(appName, ...)
```
Navigate to specific group.

| Parameter | Type | Description |
|-----------|------|-------------|
| `appName` | string | App name |
| `...` | strings | Path components |

Returns: `boolean` - Success

#### SetDefaultSize

```lua
function LoolibConfigDialogMixin:SetDefaultSize(appName, width, height)
```
Set default dialog dimensions.

| Parameter | Type | Description |
|-----------|------|-------------|
| `appName` | string | App name |
| `width` | number | Width in pixels |
| `height` | number | Height in pixels |

#### AddToBlizOptions

```lua
function LoolibConfigDialogMixin:AddToBlizOptions(appName, name, parent, ...)
```
Add to Blizzard Settings panel.

| Parameter | Type | Description |
|-----------|------|-------------|
| `appName` | string | App name |
| `name` | string | Display name |
| `parent` | string | Parent category (optional) |
| `...` | strings | Path to group (optional) |

Returns: `Frame` - Settings panel frame

#### RefreshContent

```lua
function LoolibConfigDialogMixin:RefreshContent(appName)
```
Refresh dialog content for app.

#### AcquireWidget

```lua
function LoolibConfigDialogMixin:AcquireWidget(widgetType, parent, template, frameTypeOverride)
```
Get widget from pool or create new.

#### ReleaseWidgets

```lua
function LoolibConfigDialogMixin:ReleaseWidgets(container)
```
Release all widgets in container back to pools.

### Render Functions

Each type has a render function returning new yOffset:

```lua
function LoolibConfigDialogMixin:RenderHeader(parent, name, yOffset, contentWidth)
function LoolibConfigDialogMixin:RenderDescription(parent, option, name, desc, yOffset, contentWidth)
function LoolibConfigDialogMixin:RenderToggle(parent, option, name, desc, registry, info, disabled, yOffset)
function LoolibConfigDialogMixin:RenderInput(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
function LoolibConfigDialogMixin:RenderRange(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
function LoolibConfigDialogMixin:RenderSelect(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
function LoolibConfigDialogMixin:RenderMultiSelect(parent, option, name, desc, registry, info, disabled, yOffset, contentWidth)
function LoolibConfigDialogMixin:RenderColor(parent, option, name, desc, registry, info, disabled, yOffset)
function LoolibConfigDialogMixin:RenderExecute(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
function LoolibConfigDialogMixin:RenderKeybinding(parent, option, name, desc, registry, info, disabled, yOffset)
function LoolibConfigDialogMixin:RenderTexture(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
function LoolibConfigDialogMixin:RenderFont(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
function LoolibConfigDialogMixin:RenderInlineGroup(parent, group, rootOptions, registry, path, yOffset, contentWidth, appName)
```

---

## Customization

### Custom Dialog Title

The title comes from `options.name`:

```lua
local options = {
    type = "group",
    name = "My Custom Title",  -- This appears in title bar
    args = { ... }
}
```

Dynamic title:
```lua
name = function(info)
    return "My Addon v" .. GetAddOnMetadata("MyAddon", "Version")
end,
```

### Custom Default Size

```lua
-- Before first open
ConfigDialogModule.Dialog:SetDefaultSize("MyAddon", 900, 700)
```

### Post-Processing

Listen for dialog open to customize:

```lua
ConfigDialogModule.Dialog:RegisterCallback("OnDialogOpened", function(appName)
    if appName == "MyAddon" then
        local dialog = ConfigDialogModule.Dialog.dialogs[appName]
        -- Customize dialog frame
        dialog:SetFrameStrata("FULLSCREEN")
    end
end)
```

### Custom Refresh Behavior

Force refresh when your addon state changes:

```lua
function MyAddon:OnStateChange()
    -- Update your data
    self.db.state = newState

    -- Refresh config dialog if open
    if ConfigDialogModule.Dialog.dialogs["MyAddon"] then
        ConfigDialogModule.Dialog:RefreshContent("MyAddon")
    end
end
```

---

## Troubleshooting

### Dialog Not Opening

```lua
-- Check if options registered
if not LoolibConfig:IsRegistered("MyAddon") then
    print("Options not registered!")
end

-- Check for errors in options table
local options = LoolibConfig:GetOptionsTable("MyAddon")
if not options then
    print("Failed to get options table")
end
```

### Dialog Not Showing Options

```lua
-- Ensure args table exists
local options = {
    type = "group",
    name = "Test",
    args = {},  -- Must exist, even if empty
}

-- Check hidden property
{
    type = "toggle",
    name = "Test",
    hidden = function(info)
        print("Hidden check called")
        return false
    end,
}
```

### Options Not Updating

```lua
-- Make sure to notify changes
LoolibConfig:NotifyChange("MyAddon")

-- Check that get/set work correctly
get = function(info)
    local value = db.setting
    print("Get called, value:", value)
    return value
end,
```

### Memory Leaks

```lua
-- Ensure dialogs are properly closed
-- Widget pooling should handle most cases

-- If you create custom widgets, clean them up:
dialog:SetScript("OnHide", function()
    -- Cleanup code
end)
```

### Performance Issues

1. **Avoid expensive operations in get/set functions**
2. **Cache dynamic values when possible**
3. **Use static values where dynamic not needed**
4. **Minimize NotifyChange calls**

```lua
-- Bad: expensive in get
get = function()
    local items = {}
    for i = 1, 1000 do
        items[i] = GetItemInfo(i)  -- API call each time!
    end
    return items
end,

-- Good: cache results
local itemCache
values = function()
    if not itemCache then
        itemCache = {}
        -- Build once
    end
    return itemCache
end,
```

---

## See Also

- [Config.md](Config.md) - Main configuration system documentation
- [ConfigTypes.md](ConfigTypes.md) - Option type reference
