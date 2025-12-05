# WindowUtil Module Documentation

## Overview

**WindowUtil** is a comprehensive frame position and scale management module for World of Warcraft 12.0+ addons. It provides automatic persistence of window positions, scaling, and advanced features like dragging, mouse wheel scaling, and alt-to-interact mode.

WindowUtil is inspired by the classic LibWindow-1.1 library and provides all the functionality needed to create professional, persistent UI windows that remember their state across sessions.

### Key Features

- **Position Persistence**: Save and restore frame anchor points and offsets
- **Scale Management**: Persist and adjust frame scale (zoom level)
- **Draggable Frames**: Make frames draggable with automatic position saving
- **Mouse Wheel Scaling**: Ctrl+MouseWheel to resize frames
- **Alt-to-Interact Mode**: Click-through frames that only respond when Alt is held
- **Screen Clamping**: Automatically reposition frames that go off-screen
- **Resolution Handling**: Detect and handle screen resolution changes
- **Batch Operations**: Save/restore all registered frames at once

---

## Quick Start

### Basic Window Registration

The simplest use case: register a frame and it will save/restore its position automatically.

```lua
local Loolib = LibStub("Loolib")
local WindowUtil = Loolib:GetModule("UI").WindowUtil

-- Your addon's SavedVariables table
local db = {
    profile = {
        windows = {}  -- Storage for window positions
    }
}

-- Create or get your frame
local myFrame = CreateFrame("Frame", "MyAddonWindow", UIParent)
myFrame:SetSize(400, 300)
myFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

-- Register for position persistence
WindowUtil.RegisterConfig(myFrame, db.profile.windows)

-- Position is automatically restored on next load!
```

### Save and Restore Pattern

```lua
-- Save position when frame closes
myFrame:SetScript("OnHide", function()
    WindowUtil.SavePosition(myFrame)
end)

-- Or save periodically during gameplay
local saveTimer = 0
myFrame:SetScript("OnUpdate", function(self, elapsed)
    saveTimer = saveTimer + elapsed
    if saveTimer > 5 then  -- Save every 5 seconds
        WindowUtil.SavePosition(self)
        saveTimer = 0
    end
end)
```

---

## API Reference

### Position Management

#### RegisterConfig(frame, storage, names)

Register a frame for position and scale persistence. This is the primary entry point for using WindowUtil.

**Parameters:**
- `frame` (Frame): The frame to manage. Must be a valid WoW frame object.
- `storage` (table): A table where position data will be saved. Typically `db.profile.windows` or similar SavedVariable.
- `names` (table, optional): Custom key names for stored data. If omitted, uses default keys.

**Behavior:**
- Validates that `frame` is a valid frame and `storage` is a table
- Attaches `windowStorage` and `windowKeys` properties to the frame
- Tracks the frame internally for batch operations
- Automatically calls `RestorePosition()` if saved data exists

**Example:**
```lua
local customKeys = {
    point = "windowPoint",
    relativePoint = "windowRelPoint",
    relativeTo = "windowRelTo",
    xOffset = "windowX",
    yOffset = "windowY",
    scale = "windowScale",
}

WindowUtil.RegisterConfig(myFrame, db.profile.windows, customKeys)
```

#### SavePosition(frame)

Save the current position and scale of a frame to its storage table.

**Parameters:**
- `frame` (Frame): The frame to save. Must have been registered with `RegisterConfig()`.

**Behavior:**
- Saves the anchor point, offsets, and scale from the frame's current state
- Converts frame-relative anchors to screen-relative (UIParent)
- If frame is anchored to another frame, calculates absolute position and converts to center-based offset
- Does nothing if frame has no registered storage

**Storage Structure:**
After calling `SavePosition()`, the storage table contains:
```lua
storage = {
    point = "CENTER",           -- Anchor point (e.g., "TOPLEFT", "CENTER")
    relativePoint = "CENTER",   -- Point on UIParent to anchor to
    relativeTo = nil,           -- Always nil (screen-relative)
    xOffset = -50,              -- Horizontal offset from anchor in pixels
    yOffset = 100,              -- Vertical offset from anchor in pixels
    scale = 1.0,                -- Frame scale (1.0 = 100%)
}
```

**Example:**
```lua
-- Save when frame closes
myFrame:SetScript("OnHide", function()
    WindowUtil.SavePosition(myFrame)
end)

-- Inspect saved data
print(db.profile.windows.point)      -- "CENTER"
print(db.profile.windows.xOffset)    -- -50
print(db.profile.windows.scale)      -- 1.0
```

#### RestorePosition(frame)

Restore a frame's position and scale from its storage table.

**Parameters:**
- `frame` (Frame): The frame to restore. Must have been registered with `RegisterConfig()`.

**Behavior:**
- Clears all anchor points
- Applies stored scale
- Sets anchor point relative to UIParent
- Automatically clamps frame to screen to prevent off-screen positioning
- Does nothing if frame has no registered storage

**Example:**
```lua
-- Restore on login
myFrame:RegisterEvent("PLAYER_LOGIN")
myFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        WindowUtil.RestorePosition(self)
    end
end)
```

#### ClampToScreen(frame)

Ensure a frame is completely visible on screen. Repositions the frame if it's off-screen.

**Parameters:**
- `frame` (Frame): The frame to clamp.

**Behavior:**
- Checks if frame extends beyond screen boundaries
- If off-screen, repositions to screen center and saves the new position
- Takes frame scale into account
- Safe to call repeatedly

**Example:**
```lua
-- Handle resolution changes
myFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
myFrame:SetScript("OnEvent", function(self, event)
    if event == "DISPLAY_SIZE_CHANGED" then
        WindowUtil.ClampToScreen(self)
    end
end)
```

#### SetScale(frame, scale)

Set a frame's scale and automatically save the new position.

**Parameters:**
- `frame` (Frame): The frame to scale
- `scale` (number): Scale value. Will be clamped to 0.5 - 2.0.

**Behavior:**
- Clamps scale to 0.5 (50%) to 2.0 (200%)
- Preserves frame center position while scaling
- Saves new position and scale to storage
- Automatically clamps to screen

**Example:**
```lua
-- Set frame to 75% scale
WindowUtil.SetScale(myFrame, 0.75)

-- Frame center stays in same position, frame shrinks around it
```

---

### Draggable Frames

#### MakeDraggable(frame, dragHandle)

Make a frame draggable with automatic position saving on drag stop.

**Parameters:**
- `frame` (Frame): The frame to make draggable
- `dragHandle` (Frame, optional): A child frame to use as the drag handle. If omitted, the frame itself is used.

**Behavior:**
- Enables frame movement and screen clamping
- Registers for left-button drag
- Automatically saves position when drag ends
- Preserves any existing OnDragStart/OnDragStop scripts
- Calls scripts in order: WindowUtil handlers first, then original scripts

**Example:**
```lua
-- Simple: make frame draggable by its entire area
WindowUtil.MakeDraggable(myFrame)

-- With drag handle: use only a header bar for dragging
local headerBar = CreateFrame("Frame", nil, myFrame)
headerBar:SetSize(myFrame:GetWidth(), 20)
headerBar:SetPoint("TOPLEFT", myFrame)
WindowUtil.MakeDraggable(myFrame, headerBar)
```

**Common Pattern: Title Bar as Drag Handle**
```lua
-- Create main window
local window = CreateFrame("Frame", "MyWindow", UIParent)
window:SetSize(500, 400)
window:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})

-- Create title bar
local titleBar = CreateFrame("Frame", nil, window)
titleBar:SetSize(window:GetWidth(), 30)
titleBar:SetPoint("TOPLEFT")
titleBar:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})

-- Add title text
local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("CENTER")
title:SetText("My Window")

-- Make window draggable by title bar
WindowUtil.MakeDraggable(window, titleBar)
```

---

### Mouse Wheel Scaling

#### EnableMouseWheelScaling(frame)

Enable Ctrl+MouseWheel to scale the frame up and down.

**Parameters:**
- `frame` (Frame): The frame to enable scaling on

**Behavior:**
- Enables mouse wheel events on the frame
- When Ctrl is held, scrolling adjusts scale by 5% per scroll tick
- If Ctrl is not held, passes event to any existing OnMouseWheel handler
- Scale is automatically saved and clamped to 0.5 - 2.0

**Example:**
```lua
-- Enable mouse wheel scaling
WindowUtil.EnableMouseWheelScaling(myFrame)

-- User can now:
-- Ctrl+Scroll Up to zoom in
-- Ctrl+Scroll Down to zoom out
-- Regular scroll (if desired) passes to original handler
```

**Combined Dragging and Scaling:**
```lua
-- Create draggable, scalable window
local window = CreateFrame("Frame", "MyWindow", UIParent)
window:SetSize(400, 300)
WindowUtil.RegisterConfig(window, db.profile.windows)
WindowUtil.MakeDraggable(window)
WindowUtil.EnableMouseWheelScaling(window)

-- User can now drag to move and Ctrl+scroll to resize!
```

---

### Alt-to-Interact Mode

#### EnableMouseOnAlt(frame)

Make a frame click-through by default, only responding to mouse when Alt is held.

**Parameters:**
- `frame` (Frame): The frame to modify

**Behavior:**
- Disables mouse input initially
- Adds OnUpdate handler to detect Alt key state
- Enables mouse only while Alt is held
- Allows click-through gameplay when Alt is not held
- Preserves original mouse state when disabled

**Use Cases:**
- Overlay HUD frames that shouldn't block combat
- Info panels in the middle of the screen
- Minimal UI designs where frames should be out of the way

**Example:**
```lua
-- Create a damage meter overlay
local dmgMeter = CreateFrame("Frame", "DamageOverlay", UIParent)
dmgMeter:SetPoint("CENTER")
dmgMeter:SetSize(200, 300)

-- Make click-through unless Alt is held
WindowUtil.EnableMouseOnAlt(dmgMeter)

-- Now:
-- - Clicking on dmgMeter during combat passes clicks through to game
-- - Hold Alt + click to interact with dmgMeter
-- - Great for scrolling, dragging, etc. while fighting
```

#### DisableMouseOnAlt(frame)

Disable Alt-to-interact mode and restore normal mouse behavior.

**Parameters:**
- `frame` (Frame): The frame to modify

**Behavior:**
- Removes the Alt-key detection OnUpdate handler
- Restores original mouse-enabled state
- Safe to call even if mode is not active

**Example:**
```lua
if mode == "combat" then
    WindowUtil.EnableMouseOnAlt(hud)
elseif mode == "ui" then
    WindowUtil.DisableMouseOnAlt(hud)
end
```

---

### Utility Functions

#### IsRegistered(frame)

Check if a frame is currently registered with WindowUtil.

**Parameters:**
- `frame` (Frame): The frame to check

**Returns:**
- `boolean`: True if registered, false otherwise

**Example:**
```lua
if WindowUtil.IsRegistered(myFrame) then
    WindowUtil.SavePosition(myFrame)
end
```

#### Unregister(frame)

Stop managing a frame's position. Clears WindowUtil-specific properties.

**Parameters:**
- `frame` (Frame): The frame to unregister

**Behavior:**
- Removes frame from internal tracking
- Clears `windowStorage` and `windowKeys` properties
- Does not delete stored data

**Example:**
```lua
-- Clean up on addon disable
function MyAddon:Disable()
    WindowUtil.Unregister(self.mainWindow)
end
```

#### ResetPosition(frame)

Clear saved position and reset frame to default center position.

**Parameters:**
- `frame` (Frame): The frame to reset

**Behavior:**
- Clears all position keys from storage
- Repositions frame to UIParent center
- Resets scale to 1.0
- Saves the default position

**Example:**
```lua
-- Add reset button to options
resetButton:SetScript("OnClick", function()
    WindowUtil.ResetPosition(mainWindow)
    print("Window position reset to default")
end)
```

#### SaveAllPositions()

Save positions of all currently registered frames.

**Parameters:** None

**Behavior:**
- Iterates through all registered frames
- Saves position only if frame is visible
- Useful before addon unload or profile switch

**Example:**
```lua
-- Save all positions on logout
local Events = Loolib:GetModule("Events")
Events.Registry:RegisterFrameEventAndCallback("PLAYER_LOGOUT", function()
    WindowUtil.SaveAllPositions()
end)
```

#### RestoreAllPositions()

Restore positions of all registered frames.

**Parameters:** None

**Behavior:**
- Iterates through all registered frames
- Restores position from storage
- Useful after resolution change or frame recreation

**Example:**
```lua
-- Restore on resolution change
myFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
myFrame:SetScript("OnEvent", function(self, event)
    if event == "DISPLAY_SIZE_CHANGED" then
        WindowUtil.RestoreAllPositions()
    end
end)
```

---

## Usage Examples

### Example 1: Basic Persistent Window

```lua
local Loolib = LibStub("Loolib")
local WindowUtil = Loolib:GetModule("UI").WindowUtil

-- SavedVariables declaration (in .toc file):
-- ## SavedVariables: MyAddonDB

-- Initialize database
MyAddonDB = MyAddonDB or {
    profile = {
        windows = {}
    }
}

-- Create main window
local mainFrame = CreateFrame("Frame", "MyAddonWindow", UIParent)
mainFrame:SetSize(600, 400)
mainFrame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})

-- Register for position persistence
WindowUtil.RegisterConfig(mainFrame, MyAddonDB.profile.windows)

-- Position is automatically restored on next session!
```

### Example 2: Professional Window with Drag and Scale

```lua
local Loolib = LibStub("Loolib")
local WindowUtil = Loolib:GetModule("UI").WindowUtil

-- Database setup
MyAddonDB = MyAddonDB or {
    profile = {
        windows = {}
    }
}

-- Create window
local window = CreateFrame("Frame", "MyAddonWindow", UIParent)
window:SetSize(500, 400)
window:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

-- Create title bar for dragging
local titleBar = CreateFrame("Frame", nil, window)
titleBar:SetSize(window:GetWidth(), 30)
titleBar:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
titleBar:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
titleBar:EnableMouse(true)

-- Add title text
local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("CENTER", titleBar)
titleText:SetText("My Addon")

-- Configure window
WindowUtil.RegisterConfig(window, MyAddonDB.profile.windows)
WindowUtil.MakeDraggable(window, titleBar)
WindowUtil.EnableMouseWheelScaling(window)

-- User experience:
-- - Drag title bar to move window
-- - Ctrl+Scroll to resize
-- - Position saved automatically and restored on next session
```

### Example 3: Multiple Windows with Profile System

```lua
local Loolib = LibStub("Loolib")
local WindowUtil = Loolib:GetModule("UI").WindowUtil

MyAddonDB = MyAddonDB or {
    profiles = {
        Default = {
            windows = {}
        },
        Raid = {
            windows = {}
        },
        PvP = {
            windows = {}
        }
    }
}

local currentProfile = "Default"

-- Create multiple windows
local windows = {
    main = CreateFrame("Frame", "MyAddon_Main", UIParent),
    stats = CreateFrame("Frame", "MyAddon_Stats", UIParent),
    log = CreateFrame("Frame", "MyAddon_Log", UIParent),
}

-- Configure all windows
for name, frame in pairs(windows) do
    frame:SetSize(400, 300)
    WindowUtil.RegisterConfig(
        frame,
        MyAddonDB.profiles[currentProfile].windows
    )
    WindowUtil.MakeDraggable(frame)
end

-- Switch profiles
function SwitchProfile(profileName)
    -- Save current positions
    WindowUtil.SaveAllPositions()

    -- Update database reference
    currentProfile = profileName

    -- Re-register all windows with new storage
    for name, frame in pairs(windows) do
        WindowUtil.RegisterConfig(
            frame,
            MyAddonDB.profiles[currentProfile].windows
        )
        -- Restore from new profile
        WindowUtil.RestorePosition(frame)
    end
end

-- Switch to raid profile on entering raid
local Events = Loolib:GetModule("Events")
Events.Registry:RegisterCallback("PLAYER_ENTERING_WORLD", function()
    local inRaid = IsInRaid()
    if inRaid then
        SwitchProfile("Raid")
    else
        SwitchProfile("Default")
    end
end)
```

### Example 4: Overlay HUD with Alt-to-Interact

```lua
local Loolib = LibStub("Loolib")
local WindowUtil = Loolib:GetModule("UI").WindowUtil

MyAddonDB = MyAddonDB or {
    profile = {
        windows = {}
    }
}

-- Create damage meter HUD
local hud = CreateFrame("Frame", "DamageMeter", UIParent)
hud:SetSize(250, 400)
hud:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
hud:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
hud:SetAlpha(0.7)

-- Create scrollable content area
local content = CreateFrame("ScrollFrame", nil, hud)
content:SetSize(hud:GetWidth() - 10, hud:GetHeight() - 40)
content:SetPoint("TOPLEFT", hud, "TOPLEFT", 5, -35)

-- Configure HUD
WindowUtil.RegisterConfig(hud, MyAddonDB.profile.windows)
WindowUtil.EnableMouseOnAlt(hud)

-- Now during combat:
-- - Clicks pass through the HUD to the game world
-- - Hold Alt to interact with scrollbar, drag, etc.
-- - Position and scale are saved and restored

-- User can still do combat while HUD is visible!
```

### Example 5: Batch Operations and Session Management

```lua
local Loolib = LibStub("Loolib")
local WindowUtil = Loolib:GetModule("UI").WindowUtil

MyAddonDB = MyAddonDB or {
    profile = {
        windows = {}
    }
}

-- Create multiple windows
local windows = {}
for i = 1, 5 do
    windows[i] = CreateFrame("Frame", "MyAddon_Panel_" .. i, UIParent)
    windows[i]:SetSize(300, 200)
    WindowUtil.RegisterConfig(windows[i], MyAddonDB.profile.windows)
    WindowUtil.MakeDraggable(windows[i])
end

-- Save all positions before logout
local Events = Loolib:GetModule("Events")
Events.Registry:RegisterFrameEventAndCallback("PLAYER_LOGOUT", function()
    WindowUtil.SaveAllPositions()
    print("Window positions saved for next session")
end)

-- Handle resolution changes
CreateFrame("Frame"):RegisterEvent("DISPLAY_SIZE_CHANGED")
CreateFrame("Frame"):SetScript("OnEvent", function(self, event)
    if event == "DISPLAY_SIZE_CHANGED" then
        -- Re-clamp all frames to new screen bounds
        WindowUtil.RestoreAllPositions()
        print("Windows repositioned for new resolution")
    end
end)

-- Reset all windows to defaults
function ResetAllWindows()
    for i = 1, 5 do
        WindowUtil.ResetPosition(windows[i])
    end
    print("All windows reset to default positions")
end
```

---

## Advanced Topics

### Screen Clamping Behavior

WindowUtil automatically prevents frames from going off-screen in two scenarios:

1. **On Restore**: When `RestorePosition()` is called, it clamps the frame if the saved position is outside current screen bounds
2. **On Manual Clamp**: When `ClampToScreen()` is called directly

If a frame is detected off-screen, it's repositioned to the center of the screen and the new position is saved.

**When Clamping Happens:**
- User changes resolution (make frame off-screen)
- Addon remembers old position from different resolution
- LoadUI saves frame in corner of ultra-wide monitor, then loads on standard monitor

**Preventing Clamping Issues:**
```lua
-- Always restore after layout is complete
frame:SetScript("OnShow", function()
    WindowUtil.RestorePosition(frame)
end)

-- Handle resolution changes
frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:SetScript("OnEvent", function(self, event)
    if event == "DISPLAY_SIZE_CHANGED" then
        WindowUtil.RestoreAllPositions()
    end
end)
```

### Resolution Changes

When screen resolution changes, previously saved positions may be invalid. Handle this by:

1. **Listen for Display Changes:**
```lua
frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:SetScript("OnEvent", function(self, event)
    if event == "DISPLAY_SIZE_CHANGED" then
        WindowUtil.RestorePosition(self)  -- Re-clamps automatically
    end
end)
```

2. **Or use batch restore:**
```lua
frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:SetScript("OnEvent", function(self, event)
    if event == "DISPLAY_SIZE_CHANGED" then
        WindowUtil.RestoreAllPositions()  -- Restore all at once
    end
end)
```

### Understanding Storage Structure

WindowUtil stores position data in this format:

```lua
storage = {
    point = "CENTER",              -- Where on frame to anchor (e.g., "TOPLEFT")
    relativePoint = "CENTER",      -- Where on UIParent to anchor to
    relativeTo = nil,              -- Always nil (screen-relative)
    xOffset = -50,                 -- Pixels from anchor point X
    yOffset = 100,                 -- Pixels from anchor point Y
    scale = 1.0,                   -- Frame scale (1.0 = 100%)
}
```

**Important:** WindowUtil always converts to screen-relative anchoring. Even if a frame is anchored to another frame, it's saved as anchored to UIParent (screen). This ensures portability and prevents issues if the relative frame is destroyed.

**Reading Stored Values:**
```lua
local storage = MyAddonDB.profile.windows
print("Frame is at", storage.point, "point")
print("Offset:", storage.xOffset, ",", storage.yOffset)
print("Scale:", storage.scale * 100, "%")
```

**Manual Position Editing:**
```lua
-- Programmatically adjust saved position
MyAddonDB.profile.windows.xOffset = 0
MyAddonDB.profile.windows.yOffset = 0
-- On next restore, frame will move to center
```

### Scale Preservation During Drag

When you drag a frame after scaling it, WindowUtil preserves the scaled size and maintains the frame's center position:

```lua
-- Frame is 100x100, scaled to 0.5 (50x50 displayed)
WindowUtil.SetScale(frame, 0.5)

-- Frame center stays in same visual position
-- Frame borders move inward

-- Dragging preserves this scaled state
WindowUtil.MakeDraggable(frame)
```

This differs from default WoW behavior where scaling can cause position shifts.

### Working with Multiple Profiles

For addons with profile systems:

```lua
MyAddonDB = {
    profiles = {
        Profile1 = { windows = {} },
        Profile2 = { windows = {} },
    }
}

-- Switch profiles
function SwitchProfile(profileName)
    -- Save current profile's positions
    WindowUtil.SaveAllPositions()

    -- Change storage reference
    currentStorageTable = MyAddonDB.profiles[profileName].windows

    -- Re-register windows with new storage
    for name, frame in pairs(windows) do
        WindowUtil.RegisterConfig(frame, currentStorageTable)
    end

    -- Restore positions from new profile
    WindowUtil.RestoreAllPositions()
end
```

---

## Best Practices

### 1. Initialize SavedVariables Properly

```lua
-- Always initialize with defaults before use
MyAddonDB = MyAddonDB or {
    profile = {
        windows = {}
    }
}

-- Register after initialization
WindowUtil.RegisterConfig(myFrame, MyAddonDB.profile.windows)
```

### 2. Save on Key Events

```lua
-- Save when frame hides
frame:SetScript("OnHide", function()
    WindowUtil.SavePosition(frame)
end)

-- Or save on logout
local Events = Loolib:GetModule("Events")
Events.Registry:RegisterFrameEventAndCallback("PLAYER_LOGOUT", function()
    WindowUtil.SaveAllPositions()
end)

-- Avoid: Saving constantly every frame update (performance)
```

### 3. Restore During Initialization

```lua
-- Best: Restore when frame shows
frame:SetScript("OnShow", function()
    WindowUtil.RestorePosition(frame)
end)

-- Restore on addon load
local Events = Loolib:GetModule("Events")
Events.Registry:RegisterFrameEventAndCallback("ADDON_LOADED", function(addOnName)
    if addOnName == "MyAddon" then
        WindowUtil.RestoreAllPositions()
    end
end)
```

### 4. Use Meaningful Storage Keys

For addons with many windows, use descriptive storage locations:

```lua
-- Better: Organized storage
MyAddonDB = {
    profile = {
        windows = {
            main = {},
            stats = {},
            options = {},
        }
    }
}

WindowUtil.RegisterConfig(mainWindow, MyAddonDB.profile.windows.main)
WindowUtil.RegisterConfig(statsWindow, MyAddonDB.profile.windows.stats)
WindowUtil.RegisterConfig(optionsWindow, MyAddonDB.profile.windows.options)

-- Easier to understand and debug
```

### 5. Handle Dynamic Frames

For frames created at runtime:

```lua
-- Don't reuse storage across instances
for i = 1, 10 do
    local frame = CreateFrame("Frame")

    -- Create unique storage for each frame
    MyAddonDB.profile.windows["panel_" .. i] =
        MyAddonDB.profile.windows["panel_" .. i] or {}

    WindowUtil.RegisterConfig(
        frame,
        MyAddonDB.profile.windows["panel_" .. i]
    )
end
```

### 6. Clean Up Unneeded Frames

```lua
-- When destroying frames permanently, unregister them
function DestroyWindow(frame)
    frame:Hide()
    WindowUtil.SavePosition(frame)
    WindowUtil.Unregister(frame)
    frame:Hide()
    -- Now frame is no longer tracked by WindowUtil
end
```

### 7. Use Custom Keys for Clarity

When you need custom storage keys, document them:

```lua
-- Define custom keys explicitly
local windowKeys = {
    point = "windowAnchorPoint",
    relativePoint = "windowRelativePoint",
    relativeTo = "windowRelativeTo",
    xOffset = "windowOffsetX",
    yOffset = "windowOffsetY",
    scale = "windowScale",
}

-- Now storage is more readable:
-- MyAddonDB.profile.windows.windowAnchorPoint = "CENTER"
-- Instead of:
-- MyAddonDB.profile.windows.point = "CENTER"

WindowUtil.RegisterConfig(myFrame, MyAddonDB.profile.windows, windowKeys)
```

### 8. Performance Tips

```lua
-- Good: Save on specific events
frame:SetScript("OnHide", function()
    WindowUtil.SavePosition(self)
end)

-- Avoid: Saving every frame update
-- This is inefficient and unnecessary
frame:SetScript("OnUpdate", function()
    WindowUtil.SavePosition(self)  -- Don't do this!
end)

-- Good: Use batch operations when managing many frames
function UnloadAddon()
    WindowUtil.SaveAllPositions()  -- Single operation
end

-- Avoid: Looping and saving individually
-- for frame in pairs(frames) do
--     WindowUtil.SavePosition(frame)  -- Multiple operations
-- end
```

### 9. Combine Features Effectively

```lua
-- Professional window combining multiple features
local window = CreateFrame("Frame", "MyWindow", UIParent)
window:SetSize(500, 400)

-- 1. Persistent position
WindowUtil.RegisterConfig(window, db.profile.windows)

-- 2. Draggable by title bar
local titleBar = CreateFrame("Frame", nil, window)
titleBar:SetSize(window:GetWidth(), 30)
titleBar:SetPoint("TOPLEFT")
WindowUtil.MakeDraggable(window, titleBar)

-- 3. Mouse wheel scaling
WindowUtil.EnableMouseWheelScaling(window)

-- 4. Click-through overlay mode
WindowUtil.EnableMouseOnAlt(window)

-- 5. Save on logout
local Events = Loolib:GetModule("Events")
Events.Registry:RegisterFrameEventAndCallback("PLAYER_LOGOUT", function()
    WindowUtil.SavePosition(window)
end)

-- Result: Professional, polished window that "just works"
```

### 10. Error Handling

```lua
-- Validate before using
function SafeRestoreWindow(frame, storage)
    if not WindowUtil.IsRegistered(frame) then
        print("Window not registered, skipping restore")
        return
    end

    if not storage[frame.windowKeys.point] then
        print("No saved position, using default")
        WindowUtil.ResetPosition(frame)
        return
    end

    WindowUtil.RestorePosition(frame)
end
```

---

## Summary

WindowUtil provides a professional, battle-tested approach to window position management for WoW addons. Use it whenever you need:

- Windows that remember their position across sessions
- Draggable and resizable UI elements
- Automatic screen boundary clamping
- Integration with addon SavedVariables

Start with `RegisterConfig()`, optionally add `MakeDraggable()` and `EnableMouseWheelScaling()`, and your addon will have professional-quality window management.
