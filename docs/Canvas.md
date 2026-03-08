# Canvas Documentation

**Module**: `Loolib.UI.Canvas`
**Main Component**: `CanvasFrame`
**Factory**: `LoolibCreateCanvasFrame(parent)`

## Table of Contents
1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Constants Reference](#constants-reference)
4. [Core Components](#core-components)
5. [Feature Components](#feature-components)
6. [CanvasFrame](#canvasframe)
7. [Usage Examples](#usage-examples)
8. [Events](#events)
9. [Network Sync](#network-sync)
10. [API Reference](#api-reference)

---

## Overview

The Loolib Canvas system is a **comprehensive tactical drawing and annotation framework** inspired by MRT's VisNote. It provides a complete suite of tools for creating collaborative sketches, raid diagrams, and tactical overlays in World of Warcraft.

### What Can You Build?

- **Raid Planning Tools**: Draw boss mechanics, movement paths, and positioning diagrams
- **Tactical Overlays**: Sketch routes, mark objectives, annotate maps
- **Collaborative Drawing**: Real-time synchronized drawing across raid/party members
- **Annotation Systems**: Add notes, icons, and markers to any UI frame

### Key Features

**Drawing Tools** (11 types):
- Freehand brush with smooth stroke interpolation
- Geometric shapes (lines, arrows, circles, rectangles, filled variants)
- Text labels with configurable size and color
- Icon placement (25 icons: raid markers, roles, classes)
- Image/texture placement with resize

**Organization**:
- Element grouping with lock/unlock
- Multi-select with rectangle selection
- Move, copy, delete operations
- Undo/redo history (21 action types)

**Collaboration**:
- Network sync with delta encoding
- Compression for bandwidth efficiency
- Version tracking per sender

**User Experience**:
- 1x-7x zoom with pan
- 25-color palette (MRT-compatible)
- Toolbar UI with tool buttons
- Object pooling for performance

### Architecture Overview

```
CanvasFrame (Main Container)
├── Element Managers (Data Layer)
│   ├── CanvasBrush      - Freehand strokes (parallel arrays)
│   ├── CanvasShape      - Geometric shapes (7 types)
│   ├── CanvasText       - Text labels
│   ├── CanvasIcon       - Icons (25 types)
│   └── CanvasImage      - Image placement
│
├── Feature Managers (Functionality)
│   ├── CanvasGroup      - Element grouping
│   ├── CanvasSelection  - Selection system
│   ├── CanvasZoom       - Zoom/pan controls
│   ├── CanvasHistory    - Undo/redo
│   └── CanvasSync       - Network sync
│
└── UI Components
    ├── CanvasToolbar    - Tool selection UI
    └── Render Pools     - Frame object pools
```

### MRT VisNote Compatibility

The Canvas system uses **parallel array storage** (MRT VisNote pattern) for optimal performance:

```lua
-- Instead of array of objects (slow)
elements = {
    { x = 100, y = 200, color = 4, size = 6 },
    { x = 150, y = 250, color = 11, size = 8 }
}

-- Use parallel arrays (fast iteration)
_dots_X     = { 100, 150 }
_dots_Y     = { 200, 250 }
_dots_COLOR = { 4, 11 }
_dots_SIZE  = { 6, 8 }
```

This pattern enables:
- Cache-friendly iteration during rendering
- Efficient bulk operations
- Minimal memory allocations

---

## Quick Start

### Basic Canvas Setup

```lua
local Loolib = LibStub("Loolib")

-- Create a canvas
local canvas = LoolibCreateCanvasFrame(UIParent)
canvas:SetTool("brush")
      :SetColor(4)         -- Red
      :SetBrushSize(6)
      :Show()

-- The canvas is now ready for drawing!
```

### Drawing with the Brush

```lua
-- Set up brush
canvas:SetTool("brush")
canvas:SetColor(4)        -- Red
canvas:SetBrushSize(8)

-- User draws by clicking and dragging
-- Dots are automatically interpolated for smooth strokes
```

### Adding Shapes

```lua
-- Draw a line
canvas:SetTool("shape_line")
canvas:SetColor(8)        -- Blue
canvas:SetBrushSize(2)    -- Line thickness

-- Draw a circle
canvas:SetTool("shape_circle")

-- Draw a rectangle
canvas:SetTool("shape_rectangle")

-- User clicks and drags to define shape bounds
```

### Placing Icons and Text

```lua
-- Place a raid marker icon
canvas:SetTool("icon")
local CanvasIcon = Loolib:GetModule("CanvasIcon")
canvas._iconManager:SetIconType(CanvasIcon.TYPES.STAR)
-- Click to place

-- Add a text label
canvas:SetTool("text")
-- Click to open text input dialog
```

### Save and Load

```lua
-- Save canvas state
local savedData = canvas:SaveData()
MyAddonDB.canvasData = savedData

-- Load canvas state
canvas:LoadData(MyAddonDB.canvasData)
```

---

## Constants Reference

### Element Types

```lua
LOOLIB_CANVAS_ELEMENT_TYPES = {
    DOT = 1,        -- Brush stroke dot/pixel
    ICON = 2,       -- Icon/texture
    TEXT = 3,       -- Text label
    SHAPE = 4,      -- Geometric shape
    IMAGE = 5,      -- Image/atlas texture
}
```

### Color Palette

**25 colors** (MRT-compatible, RGB values 0-1):

```lua
LOOLIB_CANVAS_COLORS = {
    {0, 0, 0},                      -- 1: Black
    {127/255, 127/255, 127/255},    -- 2: Gray
    {136/255, 0/255, 21/255},       -- 3: Dark red
    {237/255, 28/255, 36/255},      -- 4: Red
    {255/255, 127/255, 39/255},     -- 5: Orange
    {255/255, 242/255, 0/255},      -- 6: Yellow
    {34/255, 177/255, 76/255},      -- 7: Green
    {0/255, 162/255, 232/255},      -- 8: Light blue
    {63/255, 72/255, 204/255},      -- 9: Blue
    {163/255, 73/255, 164/255},     -- 10: Purple
    {1, 1, 1},                      -- 11: White
    {195/255, 195/255, 195/255},    -- 12: Light gray
    {185/255, 122/255, 87/255},     -- 13: Brown
    {255/255, 174/255, 201/255},    -- 14: Pink
    {255/255, 201/255, 14/255},     -- 15: Gold
    {239/255, 228/255, 176/255},    -- 16: Cream
    {181/255, 230/255, 29/255},     -- 17: Lime
    {153/255, 217/255, 234/255},    -- 18: Cyan
    {112/255, 146/255, 190/255},    -- 19: Steel blue
    {200/255, 191/255, 231/255},    -- 20: Lavender
    {0.67, 0.83, 0.45},             -- 21: Light green
    {0, 1, 0.59},                   -- 22: Aqua
    {0.53, 0.53, 0.93},             -- 23: Periwinkle
    {0.64, 0.19, 0.79},             -- 24: Violet
    {0.20, 0.58, 0.50},             -- 25: Teal
}

-- Helper functions
local r, g, b = LoolibGetCanvasColor(4)  -- Get RGB for red
local colorIndex = LoolibFindClosestCanvasColor(1, 0, 0)  -- Find closest to red
```

### Tools

```lua
LOOLIB_CANVAS_TOOLS = {
    BRUSH = "brush",                    -- Freehand drawing
    SHAPE_LINE = "shape_line",          -- Straight line
    SHAPE_ARROW = "shape_arrow",        -- Line with arrowhead
    SHAPE_CIRCLE = "shape_circle",      -- Circle outline
    SHAPE_RECTANGLE = "shape_rectangle",-- Rectangle outline
    TEXT = "text",                      -- Text label
    ICON = "icon",                      -- Icon placement
    IMAGE = "image",                    -- Image placement
    MOVE = "move",                      -- Move selected elements
    SELECT = "select",                  -- Select elements
    ERASE = "erase",                    -- Erase tool (future)
}
```

### Shape Types

```lua
LOOLIB_SHAPE_TYPES = {
    CIRCLE = 1,           -- Outline circle
    CIRCLE_FILLED = 2,    -- Filled circle
    LINE = 3,             -- Straight line
    LINE_ARROW = 4,       -- Line with arrowhead
    LINE_DASHED = 5,      -- Dashed line
    RECTANGLE = 6,        -- Outline rectangle
    RECTANGLE_FILLED = 7, -- Filled rectangle
}
```

### Icon Types

**25 icon types** (8 raid markers + 3 roles + 1 faction + 13 classes):

```lua
LOOLIB_ICON_TYPES = {
    -- Raid target markers (1-8)
    STAR = 1,
    CIRCLE = 2,
    DIAMOND = 3,
    TRIANGLE = 4,
    MOON = 5,
    SQUARE = 6,
    CROSS = 7,
    SKULL = 8,

    -- Role icons (9-11)
    TANK = 9,
    HEALER = 10,
    DPS = 11,

    -- Faction icon (12)
    FACTION = 12,

    -- Class icons (13-25)
    WARRIOR = 13,
    PALADIN = 14,
    HUNTER = 15,
    ROGUE = 16,
    PRIEST = 17,
    SHAMAN = 18,
    MAGE = 19,
    WARLOCK = 20,
    DRUID = 21,
    DEATHKNIGHT = 22,
    MONK = 23,
    DEMONHUNTER = 24,
    EVOKER = 25,
}
```

### Zoom Levels

**8 zoom levels** (MRT-compatible):

```lua
LOOLIB_CANVAS_ZOOM_LEVELS = { 1, 1.5, 2, 3, 4, 5, 6, 7 }

LOOLIB_CANVAS_DEFAULT_ZOOM = 1
LOOLIB_CANVAS_MIN_ZOOM = 1
LOOLIB_CANVAS_MAX_ZOOM = 7
```

### History Action Types

**21 recordable action types** for undo/redo:

```lua
LOOLIB_CANVAS_ACTION_TYPES = {
    ADD_DOT = "add_dot",
    ADD_DOTS = "add_dots",              -- Batch for strokes
    DELETE_DOTS = "delete_dots",
    ADD_SHAPE = "add_shape",
    DELETE_SHAPE = "delete_shape",
    UPDATE_SHAPE = "update_shape",
    ADD_TEXT = "add_text",
    DELETE_TEXT = "delete_text",
    UPDATE_TEXT = "update_text",
    ADD_ICON = "add_icon",
    DELETE_ICON = "delete_icon",
    MOVE_ICON = "move_icon",
    ADD_IMAGE = "add_image",
    DELETE_IMAGE = "delete_image",
    UPDATE_IMAGE = "update_image",
    MOVE_SELECTION = "move_selection",
    DELETE_SELECTION = "delete_selection",
    MOVE_GROUP = "move_group",
    DELETE_GROUP = "delete_group",
    CREATE_GROUP = "create_group",
    CLEAR_ALL = "clear_all",
}
```

---

## Core Components

### CanvasElement - Base Mixin

All canvas elements inherit from `LoolibCanvasElementMixin`.

**Shared Properties**:
- Position (x, y)
- Color index (1-25)
- Size
- Group ID (0 = ungrouped)
- Locked state
- Sync ID (for network sync)

**Example**:
```lua
local element = LoolibCreateCanvasElement(LOOLIB_CANVAS_ELEMENT_TYPES.DOT)
element:SetPosition(100, 150)
       :SetColor(4)
       :SetSize(8)
       :SetGroup(1)

-- Serialize for storage
local data = element:Serialize()

-- Get RGB color values
local r, g, b = element:GetColorRGB()
```

**Key Methods**:
- `SetPosition(x, y)` - Set element position
- `GetPosition()` - Get x, y coordinates
- `SetColor(colorIndex)` - Set color (1-25)
- `GetColorRGB()` - Get RGB values (0-1)
- `SetSize(size)` - Set element size
- `SetGroup(groupId)` - Assign to group
- `SetLocked(locked)` - Lock/unlock element
- `Serialize()` - Export to table
- `Deserialize(data)` - Import from table
- `Clone()` - Deep copy element
- `GetBounds()` - Get bounding box
- `HitTest(x, y)` - Point inside test

---

### CanvasBrush - Freehand Drawing

Manages freehand brush strokes with **dot interpolation** for smooth lines.

**Storage**: Parallel arrays (MRT pattern)
- `_dots_X[]` - X positions
- `_dots_Y[]` - Y positions
- `_dots_SIZE[]` - Sizes
- `_dots_COLOR[]` - Color indices
- `_dots_GROUP[]` - Group IDs
- `_dots_SYNC[]` - Sync IDs

**Drawing Flow**:
```lua
local brush = LoolibCreateCanvasBrush()
brush:SetBrushSize(6)
     :SetBrushColor(4)

-- Start stroke
brush:StartStroke(100, 100)

-- Continue stroke (interpolates dots automatically)
brush:ContinueStroke(150, 120)
brush:ContinueStroke(200, 150)

-- End stroke
brush:EndStroke()

-- Total dots created: ~50-100 (interpolated for smoothness)
```

**Interpolation Algorithm**:
```lua
-- MRT-inspired smooth stroke interpolation
-- Step size = brushSize * 0.4 (smaller = smoother, more dots)
local dx = x2 - x1
local dy = y2 - y1
local dist = sqrt(dx * dx + dy * dy)
local steps = max(1, floor(dist / (brushSize * 0.4)))

for i = 1, steps do
    local t = i / steps
    local px = x1 + dx * t
    local py = y1 + dy * t
    AddDot(px, py)
end
```

**Key Methods**:
- `SetBrushSize(size)` - Set brush size (2-20 pixels)
- `SetBrushColor(colorIndex)` - Set brush color
- `StartStroke(x, y)` - Begin new stroke
- `ContinueStroke(x, y)` - Continue stroke (interpolates)
- `EndStroke()` - Finish stroke
- `GetDot(index)` - Get dot data
- `GetAllDots()` - Get all dots as array
- `GetDotCount()` - Get total dot count
- `ClearDots()` - Clear all dots
- `DeleteDotsByGroup(groupId)` - Delete group dots
- `MoveDotsByGroup(groupId, dx, dy)` - Move group dots
- `SerializeDots()` - Export dots
- `DeserializeDots(data)` - Import dots

**Events**:
- `OnDotAdded(index)` - Single dot added
- `OnStrokeEnd()` - Stroke complete
- `OnDotsCleared()` - All dots cleared

---

### CanvasShape - Geometric Shapes

Manages **7 shape types** defined by two points (start/end).

**Storage**: Parallel arrays
- `_shape_X1[]`, `_shape_Y1[]` - Start point
- `_shape_X2[]`, `_shape_Y2[]` - End point
- `_shape_TYPE[]` - Shape type (1-7)
- `_shape_COLOR[]` - Color indices
- `_shape_SIZE[]` - Line thickness/size
- `_shape_ALPHA[]` - Transparency (0-1)
- `_shape_GROUP[]` - Group IDs

**Interactive Drawing**:
```lua
local shape = LoolibCreateCanvasShape()
shape:SetShapeType(LOOLIB_SHAPE_TYPES.LINE)
     :SetShapeColor(8)
     :SetShapeSize(2)
     :SetShapeAlpha(1.0)

-- Start shape (click-drag pattern)
shape:StartShape(100, 100)

-- Update preview as mouse moves
shape:UpdateShapePreview(200, 150)

-- Finish shape
local index = shape:FinishShape(200, 150)

-- Or cancel
shape:CancelShape()
```

**Direct Creation**:
```lua
-- Add a line directly
local index = shape:AddShape(
    100, 100,  -- Start x, y
    200, 150,  -- End x, y
    LOOLIB_SHAPE_TYPES.LINE,
    8,         -- Color
    2,         -- Size
    1.0,       -- Alpha
    1          -- Group
)
```

**Key Methods**:
- `SetShapeType(shapeType)` - Set current shape type
- `SetShapeColor(colorIndex)` - Set color
- `SetShapeSize(size)` - Set thickness (1-10)
- `SetShapeAlpha(alpha)` - Set transparency (0-1)
- `StartShape(x, y)` - Begin interactive drawing
- `UpdateShapePreview(x, y)` - Update preview
- `FinishShape(x, y)` - Complete shape
- `CancelShape()` - Cancel preview
- `AddShape(x1, y1, x2, y2, ...)` - Add shape directly
- `GetShape(index)` - Get shape data
- `GetAllShapes()` - Get all shapes
- `DeleteShape(index)` - Delete single shape
- `ClearShapes()` - Clear all shapes
- `DeleteShapesByGroup(groupId)` - Delete group shapes
- `MoveShapesByGroup(groupId, dx, dy)` - Move group shapes
- `SerializeShapes()` - Export shapes
- `DeserializeShapes(data)` - Import shapes

**Events**:
- `OnShapeStart(x, y)` - Shape drawing started
- `OnShapePreviewUpdate(x1, y1, x2, y2)` - Preview updated
- `OnShapeAdded(index)` - Shape created
- `OnShapesCleared()` - All shapes cleared

---

### CanvasText - Text Labels

Manages text annotations with configurable size and color.

**Storage**: Parallel arrays
- `_text_X[]`, `_text_Y[]` - Position
- `_text_DATA[]` - Text content strings
- `_text_SIZE[]` - Font sizes (8-32)
- `_text_COLOR[]` - Color indices
- `_text_GROUP[]` - Group IDs

**Usage**:
```lua
local text = LoolibCreateCanvasText()
text:SetTextSize(14)
    :SetTextColor(11)  -- White

-- Add a text label
local index = text:AddText(100, 200, "Boss Position", 16, 11, 1)

-- Update text
text:UpdateText(index, "Updated Label")

-- Move text
text:MoveText(index, 150, 250)

-- Find text at position
local hitIndex = text:FindTextAt(mouseX, mouseY, 20)
```

**Key Methods**:
- `SetTextSize(size)` - Set font size (8-32)
- `SetTextColor(colorIndex)` - Set text color
- `AddText(x, y, text, size, color, group)` - Add label
- `UpdateText(index, newText)` - Change text content
- `GetText(index)` - Get text data
- `GetAllTexts()` - Get all texts
- `DeleteText(index)` - Delete single text
- `ClearTexts()` - Clear all texts
- `MoveText(index, x, y)` - Move text
- `FindTextAt(x, y, tolerance)` - Hit test
- `SerializeTexts()` - Export texts
- `DeserializeTexts(data)` - Import texts

**Events**:
- `OnTextAdded(index)` - Text created
- `OnTextUpdated(index)` - Text modified
- `OnTextDeleted(index)` - Text removed
- `OnTextsCleared()` - All texts cleared

---

### CanvasIcon - Icon Placement

Manages **25 icon types**: raid markers, roles, classes, faction.

**Storage**: Parallel arrays
- `_icon_X[]`, `_icon_Y[]` - Position
- `_icon_TYPE[]` - Icon type (1-25)
- `_icon_SIZE[]` - Icon size (12-64)
- `_icon_GROUP[]` - Group IDs

**Usage**:
```lua
local icon = LoolibCreateCanvasIcon()
icon:SetIconType(LOOLIB_ICON_TYPES.STAR)
    :SetIconSize(32)

-- Add icon
local index = icon:AddIcon(100, 200)

-- Get icon texture info
local texInfo = icon:GetIconTexture(LOOLIB_ICON_TYPES.STAR)
-- texInfo.path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"

-- Class icon (uses texture coords)
local texInfo = icon:GetIconTexture(LOOLIB_ICON_TYPES.WARRIOR)
-- texInfo.path = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
-- texInfo.coords = { 0, 0.25, 0, 0.25 }

-- Hit testing
local hitIndex = icon:FindIconAt(mouseX, mouseY, 12)
```

**Icon Textures**:
- **Raid markers**: Individual texture files
- **Roles**: UI-LFG-ICON-ROLES atlas with coords
- **Faction**: Alliance/Horde based on player faction
- **Classes**: UI-CHARACTERCREATE-CLASSES atlas with coords

**Key Methods**:
- `SetIconType(iconType)` - Set icon type (1-25)
- `SetIconSize(size)` - Set icon size (12-64)
- `AddIcon(x, y, iconType, size, group)` - Add icon
- `GetIcon(index)` - Get icon data
- `GetIconTexture(iconType)` - Get texture info
- `GetAllIcons()` - Get all icons
- `DeleteIcon(index)` - Delete icon
- `ClearIcons()` - Clear all icons
- `MoveIcon(index, x, y)` - Move icon
- `FindIconAt(x, y, tolerance)` - Hit test
- `SerializeIcons()` - Export icons
- `DeserializeIcons(data)` - Import icons

---

### CanvasImage - Image Placement

Manages image/texture placement with **resize and transparency**.

**Storage**: Parallel arrays
- `_image_X1[]`, `_image_Y1[]` - Top-left corner
- `_image_X2[]`, `_image_Y2[]` - Bottom-right corner
- `_image_PATH[]` - Texture paths
- `_image_ALPHA[]` - Transparency (0.1-1.0)
- `_image_GROUP[]` - Group IDs

**Interactive Placement**:
```lua
local image = LoolibCreateCanvasImage()
image:SetDefaultPath("Interface\\Icons\\Achievement_BG_killflag_alterac")
     :SetDefaultAlpha(0.8)

-- Start placement (click-drag pattern)
image:StartPlacement(100, 100)

-- Update size as mouse moves
image:UpdatePlacement(164, 164)

-- Finish placement
local index = image:FinishPlacement(164, 164)
-- Creates 64x64 image if drag was too small
```

**Direct Placement**:
```lua
-- Add image with explicit size
local index = image:AddImage(
    50, 50,    -- Top-left x, y
    150, 150,  -- Bottom-right x, y
    "Interface\\Icons\\INV_Misc_QuestionMark",
    0.8,       -- Alpha
    1          -- Group
)

-- Or with width/height
local index = image:AddImageAt(50, 50, 100, 100, texturePath, 0.8, 1)
```

**Manipulation**:
```lua
-- Change texture
image:SetImagePath(index, "Interface\\Icons\\Achievement_BG_killflag_horde")

-- Change transparency
image:SetImageAlpha(index, 0.5)

-- Resize
image:SetImageSize(index, 50, 50, 200, 200)

-- Find corner for resize handles
local hitIndex, corner = image:FindImageCornerAt(150, 150, 8)
-- corner = "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"
```

**Key Methods**:
- `SetDefaultPath(path)` - Set default texture
- `SetDefaultAlpha(alpha)` - Set default transparency
- `StartPlacement(x, y, path)` - Begin interactive placement
- `UpdatePlacement(x, y)` - Update size preview
- `FinishPlacement(x, y)` - Complete placement
- `AddImage(x1, y1, x2, y2, path, alpha, group)` - Add directly
- `AddImageAt(x, y, width, height, ...)` - Add with size
- `GetImage(index)` - Get image data
- `SetImagePath(index, path)` - Change texture
- `SetImageAlpha(index, alpha)` - Change transparency
- `SetImageSize(index, x1, y1, x2, y2)` - Resize
- `DeleteImage(index)` - Delete image
- `ClearImages()` - Clear all images
- `MoveImage(index, dx, dy)` - Move by offset
- `FindImageAt(x, y)` - Hit test
- `FindImageCornerAt(x, y, tolerance)` - Corner hit test
- `SerializeImages()` - Export images
- `DeserializeImages(data)` - Import images

---

## Feature Components

### CanvasGroup - Element Grouping

Coordinates group operations across **all element types**.

**Group Features**:
- Named groups
- Lock/unlock protection
- Show/hide visibility
- Batch move/delete
- Merge groups

**Usage**:
```lua
local group = LoolibCreateCanvasGroup()
group:SetElementManagers(brush, shape, text, icon, image)

-- Create a group
local groupId = group:CreateGroup("Boss Mechanics")

-- Set current group (new elements go here)
group:SetCurrentGroup(groupId)

-- Lock group (prevents modifications)
group:LockGroup(groupId)

-- Move all elements in group
group:MoveGroup(groupId, 10, 20)

-- Delete all elements in group
group:DeleteElementsByGroup(groupId)

-- Merge two groups
group:MergeGroups(sourceGroupId, targetGroupId)
```

**Group Management**:
```lua
-- Get group info
local info = group:GetGroup(groupId)
-- info = { name = "...", locked = false, visible = true }

-- Get all groups
local groups = group:GetAllGroups()
-- { [groupId] = { id, name, locked, visible }, ... }

-- Rename group
group:RenameGroup(groupId, "New Name")

-- Delete group (optionally delete elements)
group:DeleteGroup(groupId, true)

-- Set visibility
group:SetGroupVisible(groupId, false)
group:ToggleGroupVisibility(groupId)
```

**Group Analysis**:
```lua
-- Count elements in group
local count = group:GetGroupElementCount(groupId)

-- Get counts by type
local counts = group:GetGroupElementCountsByType(groupId)
-- { dots = 50, shapes = 5, texts = 2, icons = 3, images = 1, total = 61 }
```

**Key Methods**:
- `SetElementManagers(brush, shape, text, icon, image)` - Set managers
- `SetCurrentGroup(groupId)` - Set current group
- `GetCurrentGroup()` - Get current group
- `CreateGroup(name)` - Create new group
- `DeleteGroup(groupId, deleteElements)` - Delete group
- `GetGroup(groupId)` - Get group info
- `GetAllGroups()` - Get all groups
- `RenameGroup(groupId, name)` - Rename group
- `LockGroup(groupId, locked)` - Lock/unlock group
- `UnlockGroup(groupId)` - Unlock group
- `IsGroupLocked(groupId)` - Check if locked
- `ToggleGroupLock(groupId)` - Toggle lock state
- `SetGroupVisible(groupId, visible)` - Set visibility
- `IsGroupVisible(groupId)` - Check if visible
- `MoveGroup(groupId, dx, dy)` - Move group elements
- `DeleteElementsByGroup(groupId)` - Delete group elements
- `GetGroupElementCount(groupId)` - Count elements
- `MergeGroups(sourceGroupId, targetGroupId)` - Merge groups
- `SerializeGroups()` - Export groups
- `DeserializeGroups(data)` - Import groups

**Events**:
- `OnGroupCreated(groupId)` - Group created
- `OnGroupDeleted(groupId)` - Group deleted
- `OnGroupLockChanged(groupId, locked)` - Lock state changed
- `OnGroupVisibilityChanged(groupId, visible)` - Visibility changed
- `OnGroupMoved(groupId, dx, dy)` - Group moved
- `OnGroupElementsDeleted(groupId)` - Group elements deleted
- `OnGroupsMerged(sourceGroupId, targetGroupId)` - Groups merged

---

### CanvasSelection - Selection System

Handles element selection with **single-click, multi-select, and rectangle selection**.

**Selection Modes**:
- **Single**: Click to select, replaces previous selection
- **Multi**: Shift/Ctrl+click to add/remove from selection
- **Rectangle**: Click-drag to select all elements in bounds

**Usage**:
```lua
local selection = LoolibCreateCanvasSelection()
selection:SetElementManagers(brush, shape, text, icon, image)

-- Handle click (detects element at position)
selection:HandleClick(mouseX, mouseY, isShiftDown, isCtrlDown)

-- Rectangle selection
selection:StartRectangleSelection(x1, y1)
selection:UpdateRectangleSelection(x2, y2)
selection:FinishRectangleSelection(x2, y2, addToSelection)

-- Manipulate selection
selection:MoveSelection(10, 10)
selection:DeleteSelection()

-- Query selection
local elements = selection:GetSelectedElements()
-- { {type="icon", index=5}, {type="text", index=2}, ... }

local count = selection:GetSelectionCount()
local x, y, w, h = selection:GetSelectionBounds()
```

**Selection Management**:
```lua
-- Select specific element
selection:SelectElement("icon", 5, addToSelection)

-- Deselect element
selection:DeselectElement("icon", 5)

-- Toggle element
selection:ToggleElementSelection("icon", 5)

-- Clear all
selection:ClearSelection()

-- Check if selected
if selection:IsElementSelected("icon", 5) then
    -- Element is selected
end
```

**Group Selection**:
```lua
-- Select all elements in a group
selection:SelectGroup(groupId, addToSelection)
```

**Key Methods**:
- `SetElementManagers(...)` - Set element managers
- `SetSelectionMode(mode)` - "single", "multi", "lasso"
- `SelectElement(elementType, index, addToSelection)` - Select element
- `DeselectElement(elementType, index)` - Deselect element
- `ToggleElementSelection(elementType, index)` - Toggle selection
- `ClearSelection()` - Clear all selection
- `IsElementSelected(elementType, index)` - Check if selected
- `GetSelectedElements()` - Get selected elements array
- `GetSelectionCount()` - Get count
- `HasSelection()` - Check if any selected
- `HandleClick(x, y, isShift, isCtrl)` - Handle click
- `StartRectangleSelection(x, y)` - Start rect select
- `UpdateRectangleSelection(x, y)` - Update rect
- `FinishRectangleSelection(x, y, add)` - Finish rect
- `CancelSelection()` - Cancel in-progress selection
- `GetSelectionBounds()` - Get bounding box
- `MoveSelection(dx, dy)` - Move selected elements
- `DeleteSelection()` - Delete selected elements
- `SelectGroup(groupId, add)` - Select group

**Events**:
- `OnElementSelected(elementType, index)` - Element selected
- `OnElementDeselected(elementType, index)` - Element deselected
- `OnSelectionCleared()` - Selection cleared
- `OnSelectionStarted(selectionType)` - Selection started
- `OnSelectionUpdated(x1, y1, x2, y2)` - Rectangle updated
- `OnSelectionFinished()` - Selection completed
- `OnSelectionMoved(dx, dy)` - Selection moved
- `OnSelectionDeleted()` - Selection deleted

---

### CanvasZoom - Zoom and Pan

Provides **1x-7x zoom** with pan and coordinate transformations.

**Zoom Levels**: 1, 1.5, 2, 3, 4, 5, 6, 7 (MRT-compatible)

**Usage**:
```lua
local zoom = LoolibCreateCanvasZoom()
zoom:SetCanvasSize(800, 600)
    :SetViewportSize(800, 600)

-- Set zoom level
zoom:SetZoom(2)  -- 2x zoom

-- Zoom in/out
zoom:ZoomIn(centerX, centerY)   -- Center on point
zoom:ZoomOut()
zoom:ResetZoom()

-- Pan
zoom:SetPan(offsetX, offsetY)
zoom:Pan(deltaX, deltaY)

-- Mouse wheel zoom (centered on cursor)
zoom:HandleMouseWheel(delta, mouseX, mouseY)

-- Coordinate transformations
local canvasX, canvasY = zoom:ScreenToCanvas(screenX, screenY)
local screenX, screenY = zoom:CanvasToScreen(canvasX, canvasY)

-- Get visible region
local x, y, width, height = zoom:GetVisibleRegion()
```

**Interactive Pan**:
```lua
-- Mouse drag panning
zoom:StartPan(mouseX, mouseY)
zoom:UpdatePan(mouseX, mouseY)  -- Call on mouse move
zoom:EndPan()
```

**View Manipulation**:
```lua
-- Center view on a point
zoom:CenterOn(canvasX, canvasY)

-- Fit content in view
zoom:FitInView(x1, y1, x2, y2, padding)
```

**Key Methods**:
- `SetCanvasSize(width, height)` - Set canvas dimensions
- `GetCanvasSize()` - Get canvas dimensions
- `SetViewportSize(width, height)` - Set viewport dimensions
- `GetViewportSize()` - Get viewport dimensions
- `GetZoom()` - Get current zoom level
- `SetZoom(level, centerX, centerY)` - Set zoom level
- `ZoomIn(centerX, centerY)` - Zoom in one level
- `ZoomOut(centerX, centerY)` - Zoom out one level
- `ResetZoom()` - Reset to 1x
- `CanZoomIn()` - Check if can zoom in
- `CanZoomOut()` - Check if can zoom out
- `SetPan(x, y)` - Set pan offset
- `GetPan()` - Get pan offset
- `Pan(dx, dy)` - Pan by delta
- `StartPan(screenX, screenY)` - Start mouse pan
- `UpdatePan(screenX, screenY)` - Update mouse pan
- `EndPan()` - End mouse pan
- `IsPanning()` - Check if panning
- `HandleMouseWheel(delta, mouseX, mouseY)` - Mouse wheel zoom
- `ScreenToCanvas(screenX, screenY)` - Transform coordinates
- `CanvasToScreen(canvasX, canvasY)` - Transform coordinates
- `GetVisibleRegion()` - Get visible canvas region
- `CenterOn(canvasX, canvasY)` - Center view
- `FitInView(x1, y1, x2, y2, padding)` - Fit content
- `SerializeView()` - Export view state
- `DeserializeView(data)` - Import view state

**Events**:
- `OnZoomChanged(newZoom, oldZoom)` - Zoom changed
- `OnPanChanged(panX, panY)` - Pan changed
- `OnPanStarted()` - Pan started
- `OnPanEnded()` - Pan ended

---

### CanvasHistory - Undo/Redo

Manages **undo/redo stacks** with support for **21 action types** and batching.

**Action Types**: See [Constants Reference](#history-action-types)

**Usage**:
```lua
local history = LoolibCreateCanvasHistory()
history:SetElementManagers(brush, shape, text, icon, image)
       :SetMaxHistorySize(100)

-- Record an action
history:PushAction(LOOLIB_CANVAS_ACTION_TYPES.ADD_ICON, {
    x = 100, y = 100, iconType = 1, size = 32
}, {
    index = 1  -- undoData
})

-- Batch multiple actions
history:BeginBatch("Draw Stroke")
-- ... multiple PushAction calls ...
history:EndBatch()

-- Undo/redo
if history:CanUndo() then
    history:Undo()
end

if history:CanRedo() then
    history:Redo()
end

-- Query state
local undoCount = history:GetUndoCount()
local redoCount = history:GetRedoCount()
local lastAction = history:GetLastActionType()
```

**Recording Control**:
```lua
-- Disable recording during programmatic operations
history:SetRecording(false)
-- ... modify canvas ...
history:SetRecording(true)

-- Check if recording
if history:IsRecording() then
    -- Recording enabled
end
```

**Snapshots** (for complex undo):
```lua
-- Create snapshot before clearing
local snapshot = history:CreateSnapshot()

history:PushAction(LOOLIB_CANVAS_ACTION_TYPES.CLEAR_ALL, {
    -- Action data
}, {
    snapshot = snapshot  -- undoData
})

-- Undo restores from snapshot
```

**Key Methods**:
- `SetElementManagers(...)` - Set element managers
- `SetMaxHistorySize(size)` - Set max undo steps
- `SetRecording(enabled)` - Enable/disable recording
- `IsRecording()` - Check if recording
- `PushAction(actionType, data, undoData)` - Record action
- `BeginBatch(batchName)` - Start batch
- `EndBatch()` - End batch
- `CancelBatch()` - Cancel and undo batch
- `Undo()` - Undo last action
- `Redo()` - Redo last undone action
- `CanUndo()` - Check if undo available
- `CanRedo()` - Check if redo available
- `GetUndoCount()` - Get undo count
- `GetRedoCount()` - Get redo count
- `GetLastActionType()` - Get last action type
- `ClearHistory()` - Clear undo/redo stacks
- `CreateSnapshot()` - Create state snapshot

**Events**:
- `OnHistoryChanged()` - History state changed
- `OnUndo(actionType)` - Undo performed
- `OnRedo(actionType)` - Redo performed
- `OnHistoryCleared()` - History cleared

---

### CanvasSync - Network Synchronization

Provides **network sync** with **delta encoding** and **compression**.

**Features**:
- Delta encoding (send only changes)
- Full sync on join/request
- Element sync IDs for tracking
- LibDeflate compression
- Throttling to prevent spam
- Version tracking per sender

**Usage**:
```lua
local sync = LoolibCreateCanvasSync()
sync:SetElementManagers(brush, shape, text, icon, image)
    :SetSyncEnabled(true)
    :SetSyncChannel("RAID")
    :SetSyncThrottle(0.5)  -- Min 0.5s between syncs

-- Broadcast full state
sync:BroadcastFull()

-- Broadcast changes
sync:BroadcastChanges()

-- Request full sync from leader
sync:RequestFullSync()

-- Receive sync (automatic)
-- sync:ApplyDelta(delta, sender) called internally
```

**Delta Encoding**:
```lua
-- Generate delta (only changes since last sync)
local delta = sync:GenerateDelta()

-- delta structure:
-- {
--     version = 5,
--     added = { icons = {...}, texts = {...} },
--     removed = { dots = {...} },
--     modified = { shapes = {...} }
-- }

-- Delta only includes changed elements!
```

**Compression**:
```lua
-- Compress data (uses LibDeflate if available)
local compressed = sync:Compress(data)

-- Decompress
local data = sync:Decompress(compressed)
```

**Version Tracking**:
```lua
-- Get local version
local version = sync:GetLocalVersion()

-- Get remote version for a sender
local version = sync:GetRemoteVersion("PlayerName-Realm")

-- Reset sync state
sync:ResetSyncState()
```

**Key Methods**:
- `SetElementManagers(...)` - Set element managers
- `SetSyncEnabled(enabled)` - Enable/disable sync
- `IsSyncEnabled()` - Check if enabled
- `SetSyncChannel(channel)` - "RAID", "PARTY", "GUILD", etc.
- `GetSyncChannel()` - Get current channel
- `SetSyncThrottle(seconds)` - Set min time between syncs
- `BroadcastFull()` - Broadcast full state
- `BroadcastChanges()` - Broadcast changes only
- `RequestFullSync()` - Request full sync
- `GenerateDelta()` - Generate delta
- `ApplyDelta(delta, sender)` - Apply received delta
- `Compress(data)` - Compress data
- `Decompress(data)` - Decompress data
- `GetLocalVersion()` - Get local version
- `GetRemoteVersion(sender)` - Get remote version
- `ResetSyncState()` - Reset sync state

**Events**:
- `OnSyncReceived(sender, version)` - Sync received
- `OnFullSyncReceived(sender)` - Full sync received
- `OnDeltaReceived(sender, changeCount)` - Delta received
- `OnSyncSent(messageType, recipientCount)` - Sync sent
- `OnSyncEnabled()` - Sync enabled
- `OnSyncDisabled()` - Sync disabled

**Message Types**:
- `MSG_FULL` - Full canvas state
- `MSG_DELTA` - Incremental changes
- `MSG_REQUEST_FULL` - Request full sync

---

### CanvasToolbar - Tool Selection UI

Provides a **visual toolbar** with tool buttons, color picker, size slider, and zoom controls.

**Features**:
- 11 tool buttons with icons
- 10-color palette (subset of 25-color palette)
- Size slider (2-20)
- Zoom controls (+, -, reset)
- Undo/redo buttons

**Usage**:
```lua
local Loolib = LibStub("Loolib")
local CanvasToolbar = Loolib:GetModule("CanvasToolbar")

local toolbar = CanvasToolbar.Create()
toolbar:SetCanvas(myCanvas)
       :BuildUI(parentFrame)

-- Listen for tool changes
toolbar:RegisterCallback("OnToolChanged", function(newTool, oldTool)
    print("Tool changed:", newTool)
end)

-- Update zoom display
toolbar:UpdateZoomDisplay()

-- Update undo/redo button states
toolbar:UpdateUndoRedoState()
```

**Tool Buttons**:
- Brush, Line, Arrow, Circle, Rectangle
- Text, Icon, Image
- Move, Select

**Key Methods**:
- `SetCanvas(canvas)` - Set canvas reference
- `BuildUI(parent)` - Build toolbar UI
- `SetTool(toolId)` - Set current tool
- `GetTool()` - Get current tool
- `SetColor(colorIndex)` - Set current color
- `GetColor()` - Get current color
- `SetSize(size)` - Set current size
- `GetSize()` - Get current size
- `UpdateZoomDisplay()` - Update zoom label
- `UpdateUndoRedoState()` - Update undo/redo buttons
- `Show()` - Show toolbar
- `Hide()` - Hide toolbar
- `IsShown()` - Check if shown

**Events**:
- `OnToolChanged(toolId, oldTool)` - Tool changed
- `OnColorChanged(colorIndex)` - Color changed

---

## CanvasFrame

The **main container** that coordinates all canvas subsystems.

### Architecture

```
CanvasFrame
├── _frame (main frame)
│   └── _drawArea (clips children)
│       └── _content (zoom/pan transform)
│           ├── Dot frames (from pool)
│           ├── Shape frames (from pool)
│           ├── Text frames (from pool)
│           ├── Icon frames (from pool)
│           └── Image frames (from pool)
│
├── Element Managers
│   ├── _brushManager
│   ├── _shapeManager
│   ├── _textManager
│   ├── _iconManager
│   └── _imageManager
│
├── Feature Managers
│   ├── _groupManager
│   ├── _selectionManager
│   ├── _zoomManager
│   ├── _historyManager
│   └── _syncManager
│
└── _toolbar (CanvasToolbar)
```

### Creating a Canvas

```lua
-- Create with default size (800x600)
local canvas = LoolibCreateCanvasFrame(UIParent)

-- Canvas is initialized with:
-- - All element managers
-- - Object pools for performance
-- - Mouse input handlers
-- - Toolbar (if available)
```

### Tool Usage

```lua
-- Set tool
canvas:SetTool("brush")
canvas:SetTool("shape_line")
canvas:SetTool("icon")
canvas:SetTool("text")
canvas:SetTool("select")

-- Set drawing parameters
canvas:SetColor(4)         -- Red
canvas:SetBrushSize(8)     -- 8 pixels

-- Tools automatically handle mouse input:
-- - Brush: Click-drag to draw
-- - Shapes: Click-drag to define bounds
-- - Icon: Click to place
-- - Text: Click to open input dialog
-- - Select: Click to select, drag to rectangle select
```

### Save and Load

```lua
-- Save entire canvas state
local data = canvas:SaveData()
-- data structure:
-- {
--     dots = {...},
--     shapes = {...},
--     texts = {...},
--     icons = {...},
--     images = {...},
--     groups = {...},
--     view = {...}
-- }

-- Store in saved variables
MyAddonDB.canvasData = data

-- Load canvas state
canvas:LoadData(MyAddonDB.canvasData)
```

### Undo/Redo

```lua
-- Check if available
if canvas:CanUndo() then
    canvas:Undo()
end

if canvas:CanRedo() then
    canvas:Redo()
end
```

### Zoom and Pan

```lua
-- Get current zoom
local zoom = canvas:GetZoom()  -- 1.0 = 100%

-- Zoom in/out
canvas:ZoomIn()
canvas:ZoomOut()

-- Reset zoom
canvas:ResetZoom()

-- Pan is handled by right-click-drag automatically
```

### Clear Canvas

```lua
-- Clear everything
canvas:Clear()

-- Refresh rendering
canvas:Refresh()
```

### Visibility

```lua
canvas:Show()
canvas:Hide()
canvas:Toggle()

if canvas:IsShown() then
    -- Canvas is visible
end
```

### Key Methods

**Tool Management**:
- `SetTool(tool)` - Set current tool
- `GetTool()` - Get current tool
- `SetColor(colorIndex)` - Set color
- `GetColor()` - Get color
- `SetBrushSize(size)` - Set size
- `GetBrushSize()` - Get size

**Zoom**:
- `GetZoom()` - Get zoom level
- `ZoomIn()` - Zoom in
- `ZoomOut()` - Zoom out
- `ResetZoom()` - Reset to 1x

**History**:
- `CanUndo()` - Check if undo available
- `CanRedo()` - Check if redo available
- `Undo()` - Undo last action
- `Redo()` - Redo last undone action

**Canvas Operations**:
- `Clear()` - Clear entire canvas
- `Refresh()` - Refresh rendering
- `SaveData()` - Export canvas state
- `LoadData(data)` - Import canvas state

**Visibility**:
- `Show()` - Show canvas
- `Hide()` - Hide canvas
- `Toggle()` - Toggle visibility
- `IsShown()` - Check if shown

---

## Usage Examples

### Example 1: Simple Drawing Canvas

```lua
local Loolib = LibStub("Loolib")

-- Create canvas
local canvas = LoolibCreateCanvasFrame(UIParent)
canvas:SetTool("brush")
      :SetColor(4)
      :SetBrushSize(6)
      :Show()

-- User can now draw by clicking and dragging
```

### Example 2: Tactical Raid Planner

```lua
local RaidPlanner = {}

function RaidPlanner:Create()
    -- Create canvas
    self.canvas = LoolibCreateCanvasFrame(UIParent)
    self.canvas:SetTool("brush")

    -- Load saved data
    if MyAddonDB.raidPlans then
        self.canvas:LoadData(MyAddonDB.raidPlans[self.currentPlan])
    end

    -- Set up save on logout
    self.canvas._frame:RegisterEvent("PLAYER_LOGOUT")
    self.canvas._frame:SetScript("OnEvent", function()
        MyAddonDB.raidPlans = MyAddonDB.raidPlans or {}
        MyAddonDB.raidPlans[self.currentPlan] = self.canvas:SaveData()
    end)

    return self
end

function RaidPlanner:NewPlan(name)
    -- Clear canvas for new plan
    self.canvas:Clear()
    self.currentPlan = name
    MyAddonDB.raidPlans[name] = {}
end

function RaidPlanner:LoadPlan(name)
    if MyAddonDB.raidPlans[name] then
        self.canvas:LoadData(MyAddonDB.raidPlans[name])
        self.currentPlan = name
    end
end

function RaidPlanner:ExportPlan()
    local data = self.canvas:SaveData()
    local Serializer = Loolib:GetModule("Serializer")
    return Serializer.Serializer:Serialize(data)
end

function RaidPlanner:ImportPlan(str)
    local Serializer = Loolib:GetModule("Serializer")
    local success, data = Serializer.Serializer:Deserialize(str)
    if success then
        self.canvas:LoadData(data)
    end
end
```

### Example 3: Map Annotation System

```lua
local MapAnnotations = {}

function MapAnnotations:Create(mapFrame)
    -- Create canvas overlay
    self.canvas = LoolibCreateCanvasFrame(mapFrame)
    self.canvas._frame:SetAllPoints(mapFrame)
    self.canvas:SetTool("icon")

    -- Set up icon placement
    local CanvasIcon = Loolib:GetModule("CanvasIcon")
    self.canvas._iconManager:SetIconType(CanvasIcon.TYPES.STAR)
    self.canvas._iconManager:SetIconSize(24)

    return self
end

function MapAnnotations:MarkLocation(x, y, iconType, text)
    -- Add icon
    local CanvasIcon = Loolib:GetModule("CanvasIcon")
    self.canvas._iconManager:SetIconType(iconType)
    self.canvas._iconManager:AddIcon(x, y)

    -- Add text label
    if text then
        self.canvas._textManager:AddText(x + 15, y - 5, text, 12, 11)
    end
end

function MapAnnotations:ClearMarkers()
    self.canvas:Clear()
end

function MapAnnotations:SaveMarkers()
    return self.canvas:SaveData()
end

function MapAnnotations:LoadMarkers(data)
    self.canvas:LoadData(data)
end
```

### Example 4: Collaborative Drawing with Sync

```lua
local CollabDraw = {}

function CollabDraw:Create()
    -- Create canvas
    self.canvas = LoolibCreateCanvasFrame(UIParent)

    -- Enable network sync
    if self.canvas._syncManager then
        self.canvas._syncManager:SetSyncEnabled(true)
                                :SetSyncChannel("RAID")
                                :SetSyncThrottle(0.5)

        -- Listen for sync events
        self.canvas._syncManager:RegisterCallback("OnSyncReceived",
            function(sender, version)
                print("Received update from:", sender)
                self.canvas:Refresh()
            end)

        -- Broadcast changes on draw
        if self.canvas._brushManager then
            self.canvas._brushManager:RegisterCallback("OnStrokeEnd",
                function()
                    self.canvas._syncManager:BroadcastChanges()
                end)
        end
    end

    return self
end

function CollabDraw:RequestSync()
    if self.canvas._syncManager then
        self.canvas._syncManager:RequestFullSync()
    end
end

function CollabDraw:BroadcastFull()
    if self.canvas._syncManager then
        self.canvas._syncManager:BroadcastFull()
    end
end
```

### Example 5: Boss Mechanic Diagram

```lua
local BossMechanics = {}

function BossMechanics:Create()
    self.canvas = LoolibCreateCanvasFrame(UIParent)
    self.canvas:SetTool("shape_circle")
    return self
end

function BossMechanics:DrawSoak(x, y, radius, color)
    -- Draw soak circle
    local shape = self.canvas._shapeManager
    shape:SetShapeType(LOOLIB_SHAPE_TYPES.CIRCLE_FILLED)
    shape:SetShapeColor(color or 5)  -- Orange
    shape:SetShapeAlpha(0.3)
    shape:AddShape(x - radius, y - radius, x + radius, y + radius)
end

function BossMechanics:DrawMovementPath(points, color)
    -- Draw path as connected lines
    local shape = self.canvas._shapeManager
    shape:SetShapeType(LOOLIB_SHAPE_TYPES.LINE_ARROW)
    shape:SetShapeColor(color or 7)  -- Green
    shape:SetShapeSize(3)

    for i = 1, #points - 1 do
        local p1, p2 = points[i], points[i + 1]
        shape:AddShape(p1.x, p1.y, p2.x, p2.y)
    end
end

function BossMechanics:MarkPosition(x, y, role, label)
    -- Add role icon
    local CanvasIcon = Loolib:GetModule("CanvasIcon")
    local iconType = (role == "tank" and CanvasIcon.TYPES.TANK)
                  or (role == "healer" and CanvasIcon.TYPES.HEALER)
                  or CanvasIcon.TYPES.DPS

    self.canvas._iconManager:SetIconType(iconType)
    self.canvas._iconManager:AddIcon(x, y)

    -- Add label
    if label then
        self.canvas._textManager:AddText(x + 20, y - 5, label, 12, 11)
    end
end

function BossMechanics:ExportDiagram()
    return self.canvas:SaveData()
end
```

---

## Events

Canvas components use the **CallbackRegistry** pattern for events.

### Brush Events

- `OnDotAdded(index)` - Single dot added
- `OnStrokeEnd()` - Stroke complete
- `OnDotsCleared()` - All dots cleared

### Shape Events

- `OnShapeStart(x, y)` - Shape drawing started
- `OnShapePreviewUpdate(x1, y1, x2, y2)` - Preview updated
- `OnShapeAdded(index)` - Shape created
- `OnShapesCleared()` - All shapes cleared

### Text Events

- `OnTextAdded(index)` - Text created
- `OnTextUpdated(index)` - Text modified
- `OnTextDeleted(index)` - Text removed
- `OnTextsCleared()` - All texts cleared

### Icon Events

- `OnIconAdded(index)` - Icon added
- `OnIconDeleted(index)` - Icon deleted
- `OnIconsCleared()` - All icons cleared

### Image Events

- `OnImagePlacementStart(x, y)` - Placement started
- `OnImagePlacementUpdate(x1, y1, x2, y2)` - Placement updated
- `OnImageAdded(index)` - Image added
- `OnImageUpdated(index)` - Image properties changed
- `OnImageDeleted(index)` - Image deleted
- `OnImagesCleared()` - All images cleared

### Group Events

- `OnGroupCreated(groupId)` - Group created
- `OnGroupDeleted(groupId)` - Group deleted
- `OnGroupLockChanged(groupId, locked)` - Lock state changed
- `OnGroupVisibilityChanged(groupId, visible)` - Visibility changed
- `OnGroupMoved(groupId, dx, dy)` - Group moved
- `OnGroupElementsDeleted(groupId)` - Group elements deleted
- `OnGroupsMerged(sourceGroupId, targetGroupId)` - Groups merged

### Selection Events

- `OnElementSelected(elementType, index)` - Element selected
- `OnElementDeselected(elementType, index)` - Element deselected
- `OnSelectionCleared()` - Selection cleared
- `OnSelectionStarted(selectionType)` - Selection started
- `OnSelectionUpdated(x1, y1, x2, y2)` - Rectangle updated
- `OnSelectionFinished()` - Selection completed
- `OnSelectionMoved(dx, dy)` - Selection moved
- `OnSelectionDeleted()` - Selection deleted

### Zoom Events

- `OnZoomChanged(newZoom, oldZoom)` - Zoom changed
- `OnPanChanged(panX, panY)` - Pan changed
- `OnPanStarted()` - Pan started
- `OnPanEnded()` - Pan ended

### History Events

- `OnHistoryChanged()` - History state changed
- `OnUndo(actionType)` - Undo performed
- `OnRedo(actionType)` - Redo performed
- `OnHistoryCleared()` - History cleared

### Sync Events

- `OnSyncReceived(sender, version)` - Sync received
- `OnFullSyncReceived(sender)` - Full sync received
- `OnDeltaReceived(sender, changeCount)` - Delta received
- `OnSyncSent(messageType, recipientCount)` - Sync sent
- `OnSyncEnabled()` - Sync enabled
- `OnSyncDisabled()` - Sync disabled

---

## Network Sync

### How Delta Encoding Works

Delta encoding sends **only changes** since last sync:

```lua
-- Initial state
State 0: { icons = {}, texts = {} }

-- User adds icon
State 1: { icons = { {x=100, y=200, type=1} }, texts = {} }

-- Delta sent:
{
    version = 1,
    added = { icons = { {x=100, y=200, type=1, syncId=1} } },
    removed = {},
    modified = {}
}

-- User adds text
State 2: { icons = { ... }, texts = { {x=50, y=50, text="Hi"} } }

-- Delta sent:
{
    version = 2,
    added = { texts = { {x=50, y=50, text="Hi", syncId=2} } },
    removed = {},
    modified = {}
}

-- User deletes icon
State 3: { icons = {}, texts = { ... } }

-- Delta sent:
{
    version = 3,
    added = {},
    removed = { icons = { 1 } },  -- syncId
    modified = {}
}
```

### Sync IDs

Every element has a **syncId** for tracking:

```lua
-- Element managers assign sync IDs automatically
self._dots_SYNC[index] = self._nextSyncId
self._nextSyncId = self._nextSyncId + 1

-- Sync system uses syncIds to identify elements across clients
-- When receiving delta:
-- - added: Insert new elements with syncId
-- - removed: Find and delete by syncId
-- - modified: Find and update by syncId
```

### Compression

**LibDeflate** compression reduces bandwidth:

```lua
-- Without compression: ~5000 bytes
-- With compression: ~500 bytes (90% reduction)

-- Compression is automatic:
local compressed = sync:Compress(data)
-- Uses LibDeflate if available, falls back to uncompressed
```

### Sync Workflow

```lua
-- 1. Local change occurs
brush:EndStroke()

-- 2. Generate delta
local delta = sync:GenerateDelta()

-- 3. Compress
local compressed = sync:Compress({ t = "DELTA", d = delta })

-- 4. Send via addon message
AddonMessage.Comm:SendCommMessage(prefix, compressed, "RAID")

-- 5. Remote client receives
sync:_OnMessageReceived(compressed, sender)

-- 6. Decompress
local data = sync:Decompress(compressed)

-- 7. Apply delta
sync:ApplyDelta(data.d, sender)

-- 8. Refresh rendering
canvas:Refresh()
```

---

## API Reference

### Factory Functions

```lua
-- Element Managers
LoolibCreateCanvasElement(elementType)
LoolibCreateCanvasBrush()
LoolibCreateCanvasShape()
LoolibCreateCanvasText()
LoolibCreateCanvasIcon()
LoolibCreateCanvasImage()

-- Feature Managers
LoolibCreateCanvasGroup()
LoolibCreateCanvasSelection()
LoolibCreateCanvasZoom()
LoolibCreateCanvasHistory()
LoolibCreateCanvasSync()

-- UI Components
LoolibCreateCanvasToolbar()
LoolibCreateCanvasFrame(parent)
```

### Color Utilities

```lua
-- Get RGB from color index
local r, g, b = LoolibGetCanvasColor(colorIndex)

-- Get RGBA with alpha
local r, g, b, a = LoolibGetCanvasColorRGBA(colorIndex, alpha)

-- Find closest color to RGB
local colorIndex = LoolibFindClosestCanvasColor(r, g, b)
```

### Module Access

```lua
local Loolib = LibStub("Loolib")

-- Get modules
local CanvasBrush = Loolib:GetModule("CanvasBrush")
local CanvasShape = Loolib:GetModule("CanvasShape")
local CanvasText = Loolib:GetModule("CanvasText")
local CanvasIcon = Loolib:GetModule("CanvasIcon")
local CanvasImage = Loolib:GetModule("CanvasImage")
local CanvasGroup = Loolib:GetModule("CanvasGroup")
local CanvasSelection = Loolib:GetModule("CanvasSelection")
local CanvasZoom = Loolib:GetModule("CanvasZoom")
local CanvasHistory = Loolib:GetModule("CanvasHistory")
local CanvasSync = Loolib:GetModule("CanvasSync")
local CanvasToolbar = Loolib:GetModule("CanvasToolbar")
local CanvasFrame = Loolib:GetModule("CanvasFrame")

-- Access constants
local TYPES = CanvasIcon.TYPES
local TOOLS = CanvasToolbar.TOOLS
local SHAPES = CanvasShape.TYPES
```

---

**Complete Canvas Documentation**

This documentation covers all 13 Canvas system components with comprehensive API reference, usage examples, and architectural details. The Canvas system is Loolib's largest and most complex module, providing professional-grade tactical drawing and collaboration features for WoW addons.
