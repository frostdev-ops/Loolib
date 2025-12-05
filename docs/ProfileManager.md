# ProfileManager Documentation

**Module**: `Loolib.Data.ProfileManager`
**Mixin**: `LoolibProfileManagerMixin`

## Table of Contents
1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Profile List Generation](#profile-list-generation)
4. [Profile Creation](#profile-creation)
5. [Profile Deletion](#profile-deletion)
6. [Profile Copying](#profile-copying)
7. [Profile Reset](#profile-reset)
8. [Character Profile Information](#character-profile-information)
9. [Validation Utilities](#validation-utilities)
10. [API Reference](#api-reference)
11. [Usage Examples](#usage-examples)
12. [Integration with SavedVariables](#integration-with-savedvariables)
13. [Building Profile UIs](#building-profile-uis)
14. [Best Practices](#best-practices)

---

## Overview

The ProfileManager module provides high-level UI helper utilities for managing SavedVariables profiles. It sits on top of the SavedVariables module and offers:

- **Profile List Generation**: Create dropdown/list entries with metadata
- **Validation**: Profile name validation and operation safety checks
- **Helper Functions**: Convenient wrappers for common profile operations
- **Error Handling**: Robust error messages for UI display
- **Character Tracking**: Find which characters use which profiles

### Why Use ProfileManager?

The SavedVariables module provides the core profile functionality, but ProfileManager makes it easier to build user interfaces:

| Task | Without ProfileManager | With ProfileManager |
|------|----------------------|---------------------|
| Create dropdown entries | Manual iteration + formatting | `GetProfileList(db)` |
| Validate profile name | Manual regex + length checks | `ValidateProfileName(name)` |
| Check if can delete | Multiple safety checks | `CanDeleteProfile(db, name)` |
| Create profile safely | Try/catch + validation | `CreateProfile(db, name)` |
| Get profile metadata | Manual calculations | `GetProfileListDetailed(db)` |

### When to Use ProfileManager

**Use ProfileManager when:**
- Building profile selection UIs (dropdowns, lists)
- Creating profile management panels
- Validating user input for profile names
- Need detailed profile metadata (is current, can delete, etc.)

**Use SavedVariables directly when:**
- Programmatically managing profiles
- No user input validation needed
- Simple profile switching without UI

---

## Quick Start

### Basic Setup

```lua
local Loolib = LibStub("Loolib")
local ProfileManager = Loolib:GetModule("ProfileManager").Mixin

-- Create a SavedVariables database
local db = Loolib.Data.CreateSavedVariables("MyAddonDB", defaults)

-- Use ProfileManager helpers
local profileList = ProfileManager:GetProfileList(db)
for _, entry in ipairs(profileList) do
    print(entry.text, entry.checked and "(current)" or "")
end
```

### Simple Profile Creation UI

```lua
-- Validate user input
local valid, err = ProfileManager:ValidateProfileName(userName)
if not valid then
    print("Invalid name:", err)
    return
end

-- Create profile safely
local success, err = ProfileManager:CreateProfile(db, userName)
if success then
    print("Created profile:", userName)
else
    print("Error:", err)
end
```

---

## Profile List Generation

ProfileManager provides functions to generate profile lists suitable for dropdowns, selection UIs, and profile browsers.

### GetProfileList

Generate a simple profile list for dropdowns.

**Function:** `ProfileManager:GetProfileList(db)`

**Parameters:**
- `db` (table) - SavedVariables database

**Returns:** table - Array of profile entries

**Entry Format:**
```lua
{
    text = "ProfileName",     -- Display text
    value = "ProfileName",    -- Value (same as text)
    checked = true/false      -- Is this the current profile?
}
```

**Example:**
```lua
local profiles = ProfileManager:GetProfileList(db)

-- Use with UIDropDownMenu
UIDropDownMenu_Initialize(dropdown, function(self, level)
    for _, entry in ipairs(profiles) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = entry.text
        info.checked = entry.checked
        info.func = function()
            db:SetProfile(entry.value)
        end
        UIDropDownMenu_AddButton(info)
    end
end)
```

### GetProfileListDetailed

Generate a detailed profile list with metadata.

**Function:** `ProfileManager:GetProfileListDetailed(db)`

**Parameters:**
- `db` (table) - SavedVariables database

**Returns:** table - Array of detailed profile entries

**Entry Format:**
```lua
{
    name = "ProfileName",      -- Profile name
    isCurrent = true/false,    -- Is this the current profile?
    isDefault = true/false,    -- Is this the default profile?
    canDelete = true/false     -- Can this profile be deleted?
}
```

**Example:**
```lua
local profiles = ProfileManager:GetProfileListDetailed(db)

-- Build a profile list with icons
for _, entry in ipairs(profiles) do
    local icon = ""
    if entry.isCurrent then icon = icon .. "[C]" end
    if entry.isDefault then icon = icon .. "[D]" end

    local deleteBtn = entry.canDelete and "[Delete]" or ""

    print(string.format("%s %s %s", icon, entry.name, deleteBtn))
end
```

**Output:**
```
[C][D] Default
[C] Tank [Delete]
Healer [Delete]
```

---

## Profile Creation

Create new profiles with validation and error handling.

### CreateProfile

Create a new profile with validation.

**Function:** `ProfileManager:CreateProfile(db, name)`

**Parameters:**
- `db` (table) - SavedVariables database
- `name` (string) - Profile name

**Returns:**
- `success` (boolean) - Operation succeeded
- `error` (string) - Error message if failed

**Validation Checks:**
- Name is not empty
- Name doesn't contain invalid characters
- Profile doesn't already exist

**Example:**
```lua
-- Basic usage
local success, err = ProfileManager:CreateProfile(db, "NewProfile")
if not success then
    print("Error:", err)
    return
end

-- With user input
local function OnCreateProfileClicked()
    local name = editBox:GetText()

    local success, err = ProfileManager:CreateProfile(db, name)

    if success then
        print("Created profile:", name)
        editBox:SetText("")
        RefreshProfileList()
    else
        errorText:SetText(err)
    end
end
```

**Error Messages:**
- "Database not provided"
- "Profile name cannot be empty"
- "Profile name contains invalid characters"
- "Profile 'X' already exists"
- "Failed to create profile: [reason]"

### Invalid Characters

Profile names cannot contain:
- `<` `>` `:` `"` `/` `\` `|` `?` `*`

These are reserved file system characters that could cause issues.

**Example:**
```lua
ProfileManager:CreateProfile(db, "Tank/DPS")  -- Error: invalid characters
ProfileManager:CreateProfile(db, "Tank-DPS")  -- Success!
```

---

## Profile Deletion

Delete profiles with comprehensive safety checks.

### DeleteProfile

Delete a profile with safety checks.

**Function:** `ProfileManager:DeleteProfile(db, name)`

**Parameters:**
- `db` (table) - SavedVariables database
- `name` (string) - Profile name

**Returns:**
- `success` (boolean) - Operation succeeded
- `error` (string) - Error message if failed

**Safety Checks:**
- Cannot delete current profile (must switch first)
- Cannot delete default profile
- Cannot delete last remaining profile
- Profile must exist

**Example:**
```lua
-- Basic usage
local success, err = ProfileManager:DeleteProfile(db, "OldProfile")
if not success then
    print("Cannot delete:", err)
    return
end

-- Safe deletion with confirmation
local function OnDeleteProfileClicked(profileName)
    -- Check if can delete
    local canDelete, reason = ProfileManager:CanDeleteProfile(db, profileName)

    if not canDelete then
        print("Cannot delete:", reason)
        return
    end

    -- Confirm
    StaticPopup_Show("CONFIRM_DELETE_PROFILE", profileName, nil, {
        db = db,
        profileName = profileName
    })
end

StaticPopupDialogs["CONFIRM_DELETE_PROFILE"] = {
    text = "Delete profile '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        local success, err = ProfileManager:DeleteProfile(data.db, data.profileName)
        if success then
            print("Deleted:", data.profileName)
        else
            print("Error:", err)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
```

**Error Messages:**
- "Database not provided"
- "Profile name cannot be empty"
- "Cannot delete the current profile. Switch profiles first."
- "Cannot delete the default profile"
- "Profile 'X' does not exist"
- "Cannot delete the last profile"
- "Failed to delete profile: [reason]"

### Deletion Workflow

```lua
-- Step 1: Check if current profile
if db:GetCurrentProfile() == profileToDelete then
    -- Must switch to another profile first
    db:SetProfile("Default")
end

-- Step 2: Delete
local success, err = ProfileManager:DeleteProfile(db, profileToDelete)

-- Step 3: Update UI
if success then
    RefreshProfileList()
end
```

---

## Profile Copying

Copy profile data with validation.

### CopyProfile

Copy a profile to current or new profile.

**Function:** `ProfileManager:CopyProfile(db, sourceName, destName)`

**Parameters:**
- `db` (table) - SavedVariables database
- `sourceName` (string) - Source profile name
- `destName` (string, optional) - Destination profile name (creates new if provided)

**Returns:**
- `success` (boolean) - Operation succeeded
- `error` (string) - Error message if failed

**Behavior:**
- If `destName` is `nil`: Copy to current profile
- If `destName` is provided: Create new profile with that name and copy

**Example:**
```lua
-- Copy to current profile
db:SetProfile("MyProfile")
local success, err = ProfileManager:CopyProfile(db, "Default")
-- "MyProfile" now has data from "Default"

-- Copy to new profile
local success, err = ProfileManager:CopyProfile(db, "Tank", "Tank-Copy")
-- Creates "Tank-Copy" with data from "Tank"

-- UI Example
local function ShowCopyDialog()
    StaticPopup_Show("COPY_PROFILE", nil, nil, db)
end

StaticPopupDialogs["COPY_PROFILE"] = {
    text = "Copy from which profile?",
    button1 = "Copy to Current",
    button2 = "Copy to New",
    button3 = "Cancel",
    hasEditBox = true,
    OnShow = function(self, db)
        -- Populate dropdown with source profiles
        -- (Implementation details omitted)
    end,
    OnAccept = function(self, db)
        local sourceName = selectedSource  -- From dropdown
        local success, err = ProfileManager:CopyProfile(db, sourceName)

        if success then
            print("Copied from:", sourceName)
        else
            print("Error:", err)
        end
    end,
    OnAlt = function(self, db)
        local sourceName = selectedSource
        local destName = self.editBox:GetText()

        local success, err = ProfileManager:CopyProfile(db, sourceName, destName)

        if success then
            print("Created and copied to:", destName)
        else
            print("Error:", err)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
```

**Error Messages:**
- "Database not provided"
- "Source profile name cannot be empty"
- "Source profile 'X' does not exist"
- "Destination profile name cannot be empty"
- "Profile name contains invalid characters"
- "Profile 'X' already exists"
- "Failed to create destination profile: [reason]"
- "Failed to copy profile: [reason]"

---

## Profile Reset

Reset profiles to default values.

### ResetProfile

Reset a profile to defaults with confirmation.

**Function:** `ProfileManager:ResetProfile(db, profileName)`

**Parameters:**
- `db` (table) - SavedVariables database
- `profileName` (string, optional) - Profile to reset (nil for current)

**Returns:**
- `success` (boolean) - Operation succeeded
- `error` (string) - Error message if failed

**Behavior:**
- If `profileName` is `nil`: Reset current profile
- If `profileName` is provided: Switch to that profile, then reset

**Example:**
```lua
-- Reset current profile
local success, err = ProfileManager:ResetProfile(db)

-- Reset specific profile
local success, err = ProfileManager:ResetProfile(db, "Tank")

-- With confirmation dialog
local function OnResetClicked()
    StaticPopup_Show("CONFIRM_RESET_PROFILE", db:GetCurrentProfile(), nil, db)
end

StaticPopupDialogs["CONFIRM_RESET_PROFILE"] = {
    text = "Reset profile '%s' to defaults?\n\nAll settings will be lost!",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function(self, db)
        local success, err = ProfileManager:ResetProfile(db)

        if success then
            print("Profile reset to defaults")
            ReloadUI()  -- Often needed to refresh UI
        else
            print("Error:", err)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
```

**Error Messages:**
- "Database not provided"
- "Failed to switch to profile: [reason]"
- "Failed to reset profile: [reason]"

---

## Character Profile Information

Get information about which characters use which profiles.

### GetCharacterProfiles

Get profile information for the current character.

**Function:** `ProfileManager:GetCharacterProfiles(db)`

**Parameters:**
- `db` (table) - SavedVariables database

**Returns:** table - Character profile information

**Return Format:**
```lua
{
    character = "CurrentProfileName",     -- Which profile this char uses
    characterKey = "PlayerName - Realm",  -- Character key
    realm = "RealmName",                  -- Realm name
    class = "WARRIOR",                    -- Class name (uppercase)
    race = "Human",                       -- Race name
    faction = "Alliance"                  -- Faction name
}
```

**Example:**
```lua
local info = ProfileManager:GetCharacterProfiles(db)

print("Character:", info.characterKey)
print("Using profile:", info.character)
print("Class:", info.class)
print("Faction:", info.faction)

-- Display in UI
local text = string.format(
    "%s (%s %s) is using profile: %s",
    info.characterKey,
    info.faction,
    info.class,
    info.character
)
```

### GetCharactersUsingProfile

Find all characters using a specific profile.

**Function:** `ProfileManager:GetCharactersUsingProfile(db, profileName)`

**Parameters:**
- `db` (table) - SavedVariables database
- `profileName` (string) - Profile name to search for

**Returns:** table - Array of character keys

**Example:**
```lua
local characters = ProfileManager:GetCharactersUsingProfile(db, "Tank")

print("Characters using 'Tank' profile:")
for _, charKey in ipairs(characters) do
    print("-", charKey)
end

-- Check before deleting
local function SafeDeleteProfile(db, profileName)
    local users = ProfileManager:GetCharactersUsingProfile(db, profileName)

    if #users > 0 then
        print("Cannot delete! Used by:")
        for _, charKey in ipairs(users) do
            print("-", charKey)
        end
        return false
    end

    return ProfileManager:DeleteProfile(db, profileName)
end
```

**Use Cases:**
- Warning before deletion: "Profile 'X' is used by 3 characters"
- Profile usage statistics
- Character management UIs
- Migration tools

---

## Validation Utilities

Validate profile names and check operation safety.

### ValidateProfileName

Validate a profile name.

**Function:** `ProfileManager:ValidateProfileName(name)`

**Parameters:**
- `name` (string) - Profile name to validate

**Returns:**
- `valid` (boolean) - Name is valid
- `error` (string) - Error message if invalid

**Validation Rules:**
- Not empty (after trimming)
- Max 48 characters
- No invalid characters: `<` `>` `:` `"` `/` `\` `|` `?` `*`

**Example:**
```lua
-- Validate user input before creating
local function OnCreateButtonClicked()
    local name = editBox:GetText()

    -- Validate first
    local valid, err = ProfileManager:ValidateProfileName(name)

    if not valid then
        errorText:SetText(err)
        errorText:Show()
        return
    end

    -- Create profile
    local success, err = ProfileManager:CreateProfile(db, name)

    if success then
        print("Created:", name)
    else
        errorText:SetText(err)
    end
end

-- Real-time validation
editBox:SetScript("OnTextChanged", function(self)
    local name = self:GetText()

    if name == "" then
        validationIcon:Hide()
        return
    end

    local valid, err = ProfileManager:ValidateProfileName(name)

    if valid then
        validationIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        validationIcon:Show()
        errorText:Hide()
    else
        validationIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        validationIcon:Show()
        errorText:SetText(err)
        errorText:Show()
    end
end)
```

**Error Messages:**
- "Profile name cannot be empty"
- "Profile name too long (max 48 characters)"
- "Profile name contains invalid characters"

### CanDeleteProfile

Check if a profile can be deleted.

**Function:** `ProfileManager:CanDeleteProfile(db, name)`

**Parameters:**
- `db` (table) - SavedVariables database
- `name` (string) - Profile name

**Returns:**
- `canDelete` (boolean) - Profile can be deleted
- `reason` (string) - Reason if cannot delete

**Example:**
```lua
-- Check before showing delete button
local function UpdateDeleteButton(profileName)
    local canDelete, reason = ProfileManager:CanDeleteProfile(db, profileName)

    deleteButton:SetEnabled(canDelete)

    if not canDelete then
        deleteButton:SetTooltip(reason)
    end
end

-- Conditional UI
local function CreateProfileListEntry(profileName)
    local entry = CreateFrame("Frame", nil, parent)

    local canDelete, reason = ProfileManager:CanDeleteProfile(db, profileName)

    if canDelete then
        -- Show delete button
        local deleteBtn = CreateFrame("Button", nil, entry)
        deleteBtn:SetText("Delete")
        deleteBtn:SetScript("OnClick", function()
            ProfileManager:DeleteProfile(db, profileName)
        end)
    else
        -- Show disabled icon with tooltip
        local icon = entry:CreateTexture()
        icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        icon:SetTooltip(reason)
    end

    return entry
end
```

**Reasons:**
- "Invalid parameters"
- "Cannot delete current profile"
- "Cannot delete default profile"
- "Cannot delete last profile"

---

## API Reference

### Profile List Generation

#### `ProfileManager:GetProfileList(db)`

Get a simple profile list for dropdowns.

**Returns:** Array of `{text, value, checked}`

---

#### `ProfileManager:GetProfileListDetailed(db)`

Get a detailed profile list with metadata.

**Returns:** Array of `{name, isCurrent, isDefault, canDelete}`

---

### Profile Creation

#### `ProfileManager:CreateProfile(db, name)`

Create a new profile with validation.

**Returns:** `success, error`

---

### Profile Deletion

#### `ProfileManager:DeleteProfile(db, name)`

Delete a profile with safety checks.

**Returns:** `success, error`

---

### Profile Copying

#### `ProfileManager:CopyProfile(db, sourceName, destName)`

Copy a profile to current or new profile.

**Parameters:**
- `sourceName` - Source profile
- `destName` - (optional) Destination profile name

**Returns:** `success, error`

---

### Profile Reset

#### `ProfileManager:ResetProfile(db, profileName)`

Reset a profile to defaults.

**Parameters:**
- `profileName` - (optional) Profile to reset (current if nil)

**Returns:** `success, error`

---

### Character Information

#### `ProfileManager:GetCharacterProfiles(db)`

Get profile info for current character.

**Returns:** Table with `{character, characterKey, realm, class, race, faction}`

---

#### `ProfileManager:GetCharactersUsingProfile(db, profileName)`

Get all characters using a profile.

**Returns:** Array of character keys

---

### Validation

#### `ProfileManager:ValidateProfileName(name)`

Validate a profile name.

**Returns:** `valid, error`

---

#### `ProfileManager:CanDeleteProfile(db, name)`

Check if a profile can be deleted.

**Returns:** `canDelete, reason`

---

## Usage Examples

### Example 1: Basic Profile Dropdown

```lua
local ProfileDropdown = {}
local Loolib = LibStub("Loolib")
local ProfileManager = Loolib:GetModule("ProfileManager").Mixin

function ProfileDropdown:Create(parent, db)
    local dropdown = CreateFrame("Frame", "MyAddonProfileDropdown", parent, "UIDropDownMenuTemplate")

    -- Initialize
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        ProfileDropdown:PopulateMenu(db)
    end)

    -- Set current profile text
    UIDropDownMenu_SetText(dropdown, db:GetCurrentProfile())

    -- Listen for profile changes
    db:RegisterCallback("OnProfileChanged", function(newProfile)
        UIDropDownMenu_SetText(dropdown, newProfile)
    end, dropdown)

    return dropdown
end

function ProfileDropdown:PopulateMenu(db)
    -- Get profile list
    local profiles = ProfileManager:GetProfileList(db)

    -- Add profile entries
    for _, entry in ipairs(profiles) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = entry.text
        info.checked = entry.checked
        info.func = function()
            db:SetProfile(entry.value)
            UIDropDownMenu_SetText(MyAddonProfileDropdown, entry.value)
        end
        UIDropDownMenu_AddButton(info)
    end
end
```

### Example 2: Profile Management Panel

```lua
local ProfilePanel = {}
local Loolib = LibStub("Loolib")
local ProfileManager = Loolib:GetModule("ProfileManager").Mixin

function ProfilePanel:Create(parent, db)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(400, 300)

    -- Current profile label
    local currentLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentLabel:SetPoint("TOP", 0, -20)
    currentLabel:SetText("Current Profile: " .. db:GetCurrentProfile())

    -- Profile list
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(360, 1)
    scrollFrame:SetScrollChild(content)

    -- Populate list
    ProfilePanel:PopulateList(content, db)

    -- Buttons
    local newBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    newBtn:SetSize(100, 25)
    newBtn:SetPoint("BOTTOMLEFT", 10, 10)
    newBtn:SetText("New Profile")
    newBtn:SetScript("OnClick", function()
        ProfilePanel:ShowNewProfileDialog(db)
    end)

    local copyBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copyBtn:SetSize(100, 25)
    copyBtn:SetPoint("BOTTOM", 0, 10)
    copyBtn:SetText("Copy Profile")
    copyBtn:SetScript("OnClick", function()
        ProfilePanel:ShowCopyProfileDialog(db)
    end)

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(100, 25)
    resetBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    resetBtn:SetText("Reset Profile")
    resetBtn:SetScript("OnClick", function()
        ProfilePanel:ShowResetDialog(db)
    end)

    -- Update on profile change
    db:RegisterCallback("OnProfileChanged", function(newProfile)
        currentLabel:SetText("Current Profile: " .. newProfile)
        ProfilePanel:PopulateList(content, db)
    end, panel)

    db:RegisterCallback("OnNewProfile", function()
        ProfilePanel:PopulateList(content, db)
    end, panel)

    db:RegisterCallback("OnProfileDeleted", function()
        ProfilePanel:PopulateList(content, db)
    end, panel)

    return panel
end

function ProfilePanel:PopulateList(parent, db)
    -- Clear existing
    for _, child in ipairs({parent:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Get detailed profile list
    local profiles = ProfileManager:GetProfileListDetailed(db)

    local yOffset = 0
    for _, entry in ipairs(profiles) do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(340, 30)
        row:SetPoint("TOPLEFT", 0, -yOffset)

        -- Profile name
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        name:SetPoint("LEFT", 10, 0)
        name:SetText(entry.name)

        -- Current indicator
        if entry.isCurrent then
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("RIGHT", name, "LEFT", -5, 0)
            icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        end

        -- Default indicator
        if entry.isDefault then
            local tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            tag:SetPoint("LEFT", name, "RIGHT", 5, 0)
            tag:SetText("(Default)")
        end

        -- Select button
        local selectBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        selectBtn:SetSize(60, 22)
        selectBtn:SetPoint("RIGHT", -70, 0)
        selectBtn:SetText("Select")
        selectBtn:SetEnabled(not entry.isCurrent)
        selectBtn:SetScript("OnClick", function()
            db:SetProfile(entry.name)
        end)

        -- Delete button
        local deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        deleteBtn:SetSize(60, 22)
        deleteBtn:SetPoint("RIGHT", -5, 0)
        deleteBtn:SetText("Delete")
        deleteBtn:SetEnabled(entry.canDelete)

        if entry.canDelete then
            deleteBtn:SetScript("OnClick", function()
                StaticPopup_Show("CONFIRM_DELETE_PROFILE", entry.name, nil, {
                    db = db,
                    profileName = entry.name,
                    panel = parent
                })
            end)
        else
            -- Show tooltip explaining why
            local canDelete, reason = ProfileManager:CanDeleteProfile(db, entry.name)
            deleteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Cannot Delete", 1, 0, 0)
                GameTooltip:AddLine(reason, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            deleteBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end

        yOffset = yOffset + 35
    end

    parent:SetHeight(math.max(1, yOffset))
end

function ProfilePanel:ShowNewProfileDialog(db)
    StaticPopup_Show("NEW_PROFILE", nil, nil, db)
end

function ProfilePanel:ShowCopyProfileDialog(db)
    StaticPopup_Show("COPY_PROFILE", nil, nil, db)
end

function ProfilePanel:ShowResetDialog(db)
    StaticPopup_Show("RESET_PROFILE", db:GetCurrentProfile(), nil, db)
end

-- Static Popups
StaticPopupDialogs["NEW_PROFILE"] = {
    text = "Enter a name for the new profile:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        self.editBox:SetMaxLetters(48)
        self.editBox:SetFocus()
    end,
    OnAccept = function(self, db)
        local name = self.editBox:GetText()

        -- Validate
        local valid, err = ProfileManager:ValidateProfileName(name)
        if not valid then
            UIErrorsFrame:AddMessage(err, 1, 0, 0)
            return true  -- Keep dialog open
        end

        -- Create
        local success, err = ProfileManager:CreateProfile(db, name)
        if not success then
            UIErrorsFrame:AddMessage(err, 1, 0, 0)
            return true  -- Keep dialog open
        end

        print("Created profile:", name)
    end,
    EditBoxOnEnterPressed = function(self, db)
        local parent = self:GetParent()
        StaticPopup_OnClick(parent, 1)
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["COPY_PROFILE"] = {
    text = "Copy from which profile?",
    button1 = "Copy",
    button2 = "Cancel",
    OnShow = function(self, db)
        -- Build profile list dropdown
        -- (Implementation omitted for brevity)
    end,
    OnAccept = function(self, db)
        local sourceName = self.selectedProfile
        if not sourceName then
            UIErrorsFrame:AddMessage("No profile selected", 1, 0, 0)
            return true
        end

        local success, err = ProfileManager:CopyProfile(db, sourceName)
        if not success then
            UIErrorsFrame:AddMessage(err, 1, 0, 0)
            return true
        end

        print("Copied from:", sourceName)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["RESET_PROFILE"] = {
    text = "Reset profile '%s' to defaults?\n\nAll settings will be lost!",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function(self, db)
        local success, err = ProfileManager:ResetProfile(db)
        if not success then
            UIErrorsFrame:AddMessage(err, 1, 0, 0)
            return
        end

        print("Profile reset to defaults")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["CONFIRM_DELETE_PROFILE"] = {
    text = "Delete profile '%s'?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        local success, err = ProfileManager:DeleteProfile(data.db, data.profileName)
        if not success then
            UIErrorsFrame:AddMessage(err, 1, 0, 0)
            return
        end

        print("Deleted profile:", data.profileName)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
```

### Example 3: Profile Usage Statistics

```lua
local ProfileStats = {}
local Loolib = LibStub("Loolib")
local ProfileManager = Loolib:GetModule("ProfileManager").Mixin

function ProfileStats:Show(db)
    local profiles = ProfileManager:GetProfileListDetailed(db)

    print("Profile Usage Statistics:")
    print("-------------------------")

    for _, entry in ipairs(profiles) do
        local users = ProfileManager:GetCharactersUsingProfile(db, entry.name)

        local flags = {}
        if entry.isCurrent then table.insert(flags, "CURRENT") end
        if entry.isDefault then table.insert(flags, "DEFAULT") end

        local flagText = #flags > 0 and (" [" .. table.concat(flags, ", ") .. "]") or ""

        print(string.format(
            "%s%s - %d character(s)",
            entry.name,
            flagText,
            #users
        ))

        if #users > 0 then
            for _, charKey in ipairs(users) do
                print("  - " .. charKey)
            end
        end
    end
end

-- Usage
ProfileStats:Show(MyAddon.db)
```

**Output:**
```
Profile Usage Statistics:
-------------------------
Default [CURRENT, DEFAULT] - 2 character(s)
  - Thrall - MoonGuard
  - Jaina - MoonGuard
Tank - 1 character(s)
  - Varian - MoonGuard
Healer - 0 character(s)
```

### Example 4: Advanced Profile Selector with Validation

```lua
local AdvancedProfileSelector = {}
local Loolib = LibStub("Loolib")
local ProfileManager = Loolib:GetModule("ProfileManager").Mixin

function AdvancedProfileSelector:Create(parent, db)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(300, 250)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Profile Manager")

    -- Current profile
    local currentLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    currentLabel:SetPoint("TOP", 0, -45)
    currentLabel:SetText("Current: " .. db:GetCurrentProfile())

    -- New profile section
    local newLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    newLabel:SetPoint("TOPLEFT", 20, -70)
    newLabel:SetText("New Profile:")

    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetSize(160, 20)
    editBox:SetPoint("LEFT", newLabel, "RIGHT", 10, 0)
    editBox:SetMaxLetters(48)
    editBox:SetAutoFocus(false)

    -- Validation indicator
    local validIcon = frame:CreateTexture(nil, "OVERLAY")
    validIcon:SetSize(16, 16)
    validIcon:SetPoint("LEFT", editBox, "RIGHT", 5, 0)
    validIcon:Hide()

    -- Validation text
    local errorText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    errorText:SetPoint("TOP", editBox, "BOTTOM", 0, -5)
    errorText:SetTextColor(1, 0, 0)
    errorText:SetWidth(250)
    errorText:SetJustifyH("LEFT")
    errorText:Hide()

    -- Real-time validation
    editBox:SetScript("OnTextChanged", function(self)
        local name = self:GetText()

        if name == "" then
            validIcon:Hide()
            errorText:Hide()
            createBtn:SetEnabled(false)
            return
        end

        local valid, err = ProfileManager:ValidateProfileName(name)

        if valid then
            -- Check if already exists
            local profiles = db:GetProfiles()
            local exists = false
            for _, existingName in ipairs(profiles) do
                if existingName == name then
                    exists = true
                    break
                end
            end

            if exists then
                validIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
                validIcon:Show()
                errorText:SetText("Profile already exists")
                errorText:Show()
                createBtn:SetEnabled(false)
            else
                validIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                validIcon:Show()
                errorText:Hide()
                createBtn:SetEnabled(true)
            end
        else
            validIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
            validIcon:Show()
            errorText:SetText(err)
            errorText:Show()
            createBtn:SetEnabled(false)
        end
    end)

    -- Create button
    createBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    createBtn:SetSize(80, 25)
    createBtn:SetPoint("TOP", editBox, "BOTTOM", 0, -30)
    createBtn:SetText("Create")
    createBtn:SetEnabled(false)
    createBtn:SetScript("OnClick", function()
        local name = editBox:GetText()
        local success, err = ProfileManager:CreateProfile(db, name)

        if success then
            print("Created profile:", name)
            editBox:SetText("")
            validIcon:Hide()
        else
            errorText:SetText(err)
            errorText:Show()
        end
    end)

    -- Profile list
    local listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", 20, -150)
    listLabel:SetText("Available Profiles:")

    -- Simple list (full implementation would use scroll frame)
    local profileList = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profileList:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -5)
    profileList:SetWidth(260)
    profileList:SetJustifyH("LEFT")

    local function UpdateProfileList()
        local profiles = ProfileManager:GetProfileListDetailed(db)
        local lines = {}

        for _, entry in ipairs(profiles) do
            local line = entry.name
            if entry.isCurrent then line = line .. " (current)" end
            if entry.isDefault then line = line .. " (default)" end
            table.insert(lines, line)
        end

        profileList:SetText(table.concat(lines, "\n"))
    end

    UpdateProfileList()

    -- Update on changes
    db:RegisterCallback("OnProfileChanged", function(newProfile)
        currentLabel:SetText("Current: " .. newProfile)
        UpdateProfileList()
    end, frame)

    db:RegisterCallback("OnNewProfile", UpdateProfileList, frame)
    db:RegisterCallback("OnProfileDeleted", UpdateProfileList, frame)

    return frame
end
```

---

## Integration with SavedVariables

ProfileManager is designed to work seamlessly with SavedVariables databases.

### Typical Integration Pattern

```lua
-- Create SavedVariables database
local db = Loolib.Data.CreateSavedVariables("MyAddonDB", defaults)

-- Use ProfileManager for UI operations
local ProfileManager = Loolib:GetModule("ProfileManager").Mixin

-- Profile creation (with validation)
local success, err = ProfileManager:CreateProfile(db, userInput)

-- Direct profile switching (no validation needed)
db:SetProfile("Tank")

-- Profile deletion (with safety checks)
local success, err = ProfileManager:DeleteProfile(db, profileName)

-- Direct profile operations when you control the input
db:CopyProfile("Default")
db:ResetProfile()
```

### When to Use Which

| Operation | Use ProfileManager | Use SavedVariables Directly |
|-----------|-------------------|----------------------------|
| Create from user input | Yes | No |
| Delete from UI | Yes | No |
| Get dropdown entries | Yes | N/A |
| Validate before operation | Yes | No |
| Programmatic profile switch | Optional | Yes |
| Copy profile | Optional | Yes |
| Reset profile | Optional | Yes |
| Listen for changes | N/A | Yes |

---

## Building Profile UIs

Common UI patterns for profile management.

### Pattern 1: Dropdown Selector

```lua
-- Simple profile dropdown
local dropdown = CreateFrame("Frame", "MyProfileDropdown", parent, "UIDropDownMenuTemplate")

UIDropDownMenu_Initialize(dropdown, function()
    local profiles = ProfileManager:GetProfileList(db)
    for _, entry in ipairs(profiles) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = entry.text
        info.checked = entry.checked
        info.func = function() db:SetProfile(entry.value) end
        UIDropDownMenu_AddButton(info)
    end
end)

UIDropDownMenu_SetText(dropdown, db:GetCurrentProfile())
```

### Pattern 2: List with Actions

```lua
-- Profile list with select/delete buttons
for _, entry in ipairs(ProfileManager:GetProfileListDetailed(db)) do
    local row = CreateFrame("Button", nil, parent)

    -- Name
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetText(entry.name)

    -- Select button
    local selectBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    selectBtn:SetText("Select")
    selectBtn:SetEnabled(not entry.isCurrent)
    selectBtn:SetScript("OnClick", function() db:SetProfile(entry.name) end)

    -- Delete button
    local deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    deleteBtn:SetText("Delete")
    deleteBtn:SetEnabled(entry.canDelete)
    if entry.canDelete then
        deleteBtn:SetScript("OnClick", function()
            ProfileManager:DeleteProfile(db, entry.name)
        end)
    end
end
```

### Pattern 3: Creation Dialog

```lua
-- Profile creation dialog with validation
local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
local editBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
local errorText = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
local createBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")

editBox:SetScript("OnTextChanged", function(self)
    local name = self:GetText()
    local valid, err = ProfileManager:ValidateProfileName(name)

    if valid then
        errorText:Hide()
        createBtn:SetEnabled(true)
    else
        errorText:SetText(err)
        errorText:Show()
        createBtn:SetEnabled(false)
    end
end)

createBtn:SetScript("OnClick", function()
    local name = editBox:GetText()
    local success, err = ProfileManager:CreateProfile(db, name)

    if success then
        dialog:Hide()
    else
        errorText:SetText(err)
        errorText:Show()
    end
end)
```

---

## Best Practices

### 1. Always Validate User Input

```lua
-- GOOD: Validate before creating
local valid, err = ProfileManager:ValidateProfileName(userName)
if not valid then
    errorText:SetText(err)
    return
end

ProfileManager:CreateProfile(db, userName)

-- BAD: No validation
db:SetProfile(userName)  -- Could fail with weird errors
```

### 2. Check Before Deleting

```lua
-- GOOD: Use ProfileManager safety checks
local success, err = ProfileManager:DeleteProfile(db, profileName)
if not success then
    print("Cannot delete:", err)
end

-- BAD: Direct deletion without checks
db:DeleteProfile(profileName)  -- Could error
```

### 3. Provide User Feedback

```lua
-- GOOD: Show validation in real-time
editBox:SetScript("OnTextChanged", function(self)
    local valid, err = ProfileManager:ValidateProfileName(self:GetText())
    validationIcon:SetTexture(valid and "Ready" or "NotReady")
    errorText:SetText(err or "")
end)

-- BAD: Only show error after submission
createBtn:SetScript("OnClick", function()
    local success, err = ProfileManager:CreateProfile(db, editBox:GetText())
    if not success then
        print(err)  -- User doesn't see until they click
    end
end)
```

### 4. Handle Edge Cases

```lua
-- GOOD: Check profile usage before deleting
local function SafeDeleteProfile(db, profileName)
    local users = ProfileManager:GetCharactersUsingProfile(db, profileName)

    if #users > 1 then
        local msg = string.format(
            "Profile '%s' is used by %d other characters. Delete anyway?",
            profileName, #users - 1
        )
        -- Show confirmation
    end

    return ProfileManager:DeleteProfile(db, profileName)
end
```

### 5. Keep UI in Sync

```lua
-- GOOD: Listen for all relevant callbacks
db:RegisterCallback("OnProfileChanged", UpdateUI, frame)
db:RegisterCallback("OnNewProfile", UpdateProfileList, frame)
db:RegisterCallback("OnProfileDeleted", UpdateProfileList, frame)
db:RegisterCallback("OnProfileReset", RefreshSettings, frame)

-- BAD: Only update on manual actions
createBtn:SetScript("OnClick", function()
    ProfileManager:CreateProfile(db, name)
    UpdateProfileList()  -- Misses programmatic changes
end)
```

### 6. Disable Invalid Actions

```lua
-- GOOD: Disable buttons that can't be used
local canDelete, reason = ProfileManager:CanDeleteProfile(db, profileName)
deleteBtn:SetEnabled(canDelete)
if not canDelete then
    deleteBtn:SetTooltip(reason)
end

-- BAD: Let users try and fail
deleteBtn:SetScript("OnClick", function()
    local success, err = ProfileManager:DeleteProfile(db, profileName)
    if not success then
        print(err)  -- User shouldn't have been able to click
    end
end)
```

### 7. Use Detailed Lists for Management UIs

```lua
-- GOOD: Use detailed list for management panels
local profiles = ProfileManager:GetProfileListDetailed(db)
for _, entry in ipairs(profiles) do
    -- Show indicators
    if entry.isCurrent then AddCurrentIcon() end
    if entry.isDefault then AddDefaultBadge() end

    -- Enable/disable actions based on canDelete
    deleteBtn:SetEnabled(entry.canDelete)
end

-- MEDIOCRE: Use simple list and do manual checks
local profiles = ProfileManager:GetProfileList(db)
for _, entry in ipairs(profiles) do
    -- Have to manually check everything
    local isCurrent = (entry.value == db:GetCurrentProfile())
    local isDefault = (entry.value == db.defaultProfile)
    -- etc.
end
```

### 8. Consistent Error Display

```lua
-- GOOD: Consistent error handling
local function ShowError(err)
    errorText:SetText(err)
    errorText:SetTextColor(1, 0, 0)
    errorText:Show()
    C_Timer.After(5, function() errorText:Hide() end)
end

local success, err = ProfileManager:CreateProfile(db, name)
if not success then
    ShowError(err)
end

-- GOOD: Use UIErrorsFrame for transient errors
UIErrorsFrame:AddMessage(err, 1, 0, 0)
```

### 9. Confirmation for Destructive Actions

```lua
-- GOOD: Confirm before destructive actions
local function DeleteWithConfirmation(db, profileName)
    StaticPopup_Show("CONFIRM_DELETE", profileName, nil, {
        db = db,
        profileName = profileName
    })
end

StaticPopupDialogs["CONFIRM_DELETE"] = {
    text = "Delete profile '%s'?\n\nThis cannot be undone!",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        ProfileManager:DeleteProfile(data.db, data.profileName)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
```

### 10. Accessibility

```lua
-- GOOD: Provide tooltips for disabled buttons
if not canDelete then
    deleteBtn:SetEnabled(false)
    deleteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Cannot Delete", 1, 0, 0)
        GameTooltip:AddLine(reason, 1, 1, 1, true)
        GameTooltip:Show()
    end)
end

-- GOOD: Keyboard shortcuts
editBox:SetScript("OnEnterPressed", function(self)
    createBtn:Click()
end)

editBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    dialog:Hide()
end)
```
