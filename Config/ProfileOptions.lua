--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ProfileOptions - Generate options table for profile management

    Provides a pre-built options table for LoolibSavedVariables profile
    management that can be included in addon configuration.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibProfileOptionsMixin

    Generates a complete options table for profile management UI.
----------------------------------------------------------------------]]

LoolibProfileOptionsMixin = {}

--[[--------------------------------------------------------------------
    Options Table Generation
----------------------------------------------------------------------]]

--- Generate options table for profile management
-- @param db table - LoolibSavedVariables or compatible instance
-- @param noDefaultProfiles boolean - Don't include default character profiles
-- @return table - Options table compatible with ConfigRegistry
function LoolibProfileOptionsMixin:GetOptionsTable(db, noDefaultProfiles)
    if not db then
        error("LoolibProfileOptions:GetOptionsTable requires a database instance", 2)
    end

    -- Verify it has required methods
    if type(db.GetCurrentProfile) ~= "function" then
        error("Database must have GetCurrentProfile method", 2)
    end

    local options = {
        type = "group",
        name = "Profiles",
        desc = "Manage configuration profiles",
        order = 100,  -- Usually last in options
        args = {
            --[[------------------------------------------------------------
                Current Profile Info
            --------------------------------------------------------------]]
            currentHeader = {
                type = "header",
                name = "Current Profile",
                order = 1,
            },
            current = {
                type = "description",
                name = function()
                    local profile = db:GetCurrentProfile()
                    return "|cffffd700Current Profile:|r " .. (profile or "Default")
                end,
                fontSize = "medium",
                order = 2,
            },

            spacer1 = {
                type = "description",
                name = " ",
                order = 3,
            },

            --[[------------------------------------------------------------
                Profile Selection
            --------------------------------------------------------------]]
            selectHeader = {
                type = "header",
                name = "Select Profile",
                order = 10,
            },
            choose = {
                type = "select",
                name = "Profile",
                desc = "Select a profile to activate",
                values = function()
                    return self:GetProfileList(db, noDefaultProfiles)
                end,
                get = function()
                    return db:GetCurrentProfile()
                end,
                set = function(info, value)
                    db:SetProfile(value)
                end,
                order = 11,
                width = "double",
            },

            spacer2 = {
                type = "description",
                name = " ",
                order = 19,
            },

            --[[------------------------------------------------------------
                New Profile Creation
            --------------------------------------------------------------]]
            newHeader = {
                type = "header",
                name = "Create New Profile",
                order = 20,
            },
            newName = {
                type = "input",
                name = "New Profile Name",
                desc = "Enter a name for the new profile",
                get = function() return "" end,
                set = function(info, value)
                    if value and value ~= "" then
                        db:SetProfile(value)  -- Creates if doesn't exist
                    end
                end,
                validate = function(info, value)
                    if not value or value == "" then
                        return "Profile name cannot be empty"
                    end
                    if value:match("^%s") or value:match("%s$") then
                        return "Profile name cannot start or end with spaces"
                    end
                    return true
                end,
                order = 21,
                width = "double",
            },

            spacer3 = {
                type = "description",
                name = " ",
                order = 29,
            },

            --[[------------------------------------------------------------
                Copy Profile
            --------------------------------------------------------------]]
            copyHeader = {
                type = "header",
                name = "Copy From",
                order = 30,
            },
            copyDesc = {
                type = "description",
                name = "Copy settings from another profile into the current profile.",
                fontSize = "medium",
                order = 31,
            },
            copyFrom = {
                type = "select",
                name = "Source Profile",
                desc = "Select a profile to copy settings from",
                values = function()
                    local profiles = self:GetProfileList(db, noDefaultProfiles)
                    -- Remove current profile from copy options
                    local current = db:GetCurrentProfile()
                    -- Create a copy to modify
                    local copyOptions = {}
                    for k, v in pairs(profiles) do
                        if k ~= current then
                            copyOptions[k] = v
                        end
                    end
                    return copyOptions
                end,
                get = function() return nil end,
                set = function(info, value)
                    if value then
                        db:CopyProfile(value)
                    end
                end,
                confirm = true,
                confirmText = function()
                    local current = db:GetCurrentProfile()
                    return string.format(
                        "Are you sure you want to copy to profile '%s'?\n\n" ..
                        "This will overwrite your current settings!",
                        current
                    )
                end,
                disabled = function()
                    local profiles = db:GetProfiles()
                    return #profiles <= 1
                end,
                order = 32,
                width = "double",
            },

            spacer4 = {
                type = "description",
                name = " ",
                order = 39,
            },

            --[[------------------------------------------------------------
                Profile Actions
            --------------------------------------------------------------]]
            actionsHeader = {
                type = "header",
                name = "Profile Actions",
                order = 40,
            },

            importExportHeader = {
                type = "header",
                name = "Import / Export",
                order = 40.5,
            },

            exportProfile = {
                type = "execute",
                name = "Export Profile",
                desc = "Export the current profile to a string",
                func = function()
                    self:ShowExportDialog(db)
                end,
                order = 41,
            },

            importProfile = {
                type = "execute",
                name = "Import Profile",
                desc = "Import a profile from a string",
                func = function()
                    self:ShowImportDialog(db)
                end,
                order = 42,
            },

            spacerActions = {
                type = "description",
                name = " ",
                order = 49,
            },

            reset = {
                type = "execute",
                name = "Reset Profile",
                desc = "Reset the current profile to default values",
                func = function()
                    db:ResetProfile()
                end,
                confirm = true,
                confirmText = function()
                    local current = db:GetCurrentProfile()
                    return string.format(
                        "Are you sure you want to reset profile '%s' to defaults?\n\n" ..
                        "All your settings in this profile will be lost!",
                        current
                    )
                end,
                order = 54,
            },

            delete = {
                type = "execute",
                name = "Delete Profile",
                desc = "Delete the current profile and switch to Default",
                func = function()
                    local current = db:GetCurrentProfile()
                    local defaultProfile = db.defaultProfile or "Default"

                    -- Switch to default first
                    if current ~= defaultProfile then
                        db:SetProfile(defaultProfile)
                        db:DeleteProfile(current, true)
                    end
                end,
                confirm = true,
                confirmText = function()
                    local current = db:GetCurrentProfile()
                    return string.format(
                        "Are you sure you want to delete profile '%s'?\n\n" ..
                        "This cannot be undone!",
                        current
                    )
                end,
                disabled = function()
                    -- Can't delete default profile
                    local current = db:GetCurrentProfile()
                    local defaultProfile = db.defaultProfile or "Default"
                    if current == defaultProfile then
                        return true
                    end
                    return false
                end,
                order = 55,
            },

            spacer5 = {
                type = "description",
                name = " ",
                order = 59,
            },

            --[[------------------------------------------------------------
                All Profiles List
            --------------------------------------------------------------]]
            listHeader = {
                type = "header",
                name = "All Profiles",
                order = 60,
            },
            profileList = {
                type = "description",
                name = function()
                    local profiles = db:GetProfiles()
                    if #profiles == 0 then
                        return "(no profiles)"
                    end
                    local current = db:GetCurrentProfile()
                    local lines = {}
                    for _, name in ipairs(profiles) do
                        if name == current then
                            lines[#lines + 1] = "|cff00ff00>> " .. name .. " <<|r"
                        else
                            lines[#lines + 1] = "    " .. name
                        end
                    end
                    return table.concat(lines, "\n")
                end,
                fontSize = "medium",
                order = 61,
            },
        },
    }

    return options
end

--[[--------------------------------------------------------------------
    Helper Functions
----------------------------------------------------------------------]]

--- Get profile list for dropdown
-- @param db table - Database instance
-- @param noDefaultProfiles boolean - Exclude character-based default profiles
-- @return table - Key-value pairs for dropdown
function LoolibProfileOptionsMixin:GetProfileList(db, noDefaultProfiles)
    local profiles = {}
    local profileNames = db:GetProfiles()

    for _, name in ipairs(profileNames) do
        -- Optionally filter out default character profiles
        if noDefaultProfiles then
            -- Default profiles often contain " - " for character-realm
            if not name:match(" %- ") then
                profiles[name] = name
            end
        else
            profiles[name] = name
        end
    end

    -- Ensure at least default exists
    if not next(profiles) then
        local defaultProfile = db.defaultProfile or "Default"
        profiles[defaultProfile] = defaultProfile
    end

    return profiles
end

--- Create a compact profile options table (for embedding in smaller spaces)
-- @param db table - Database instance
-- @return table - Compact options table
function LoolibProfileOptionsMixin:GetCompactOptionsTable(db)
    return {
        type = "group",
        name = "Profiles",
        inline = true,
        order = 100,
        args = {
            choose = {
                type = "select",
                name = "Profile",
                desc = "Select a profile",
                values = function()
                    return self:GetProfileList(db, false)
                end,
                get = function()
                    return db:GetCurrentProfile()
                end,
                set = function(info, value)
                    db:SetProfile(value)
                end,
                order = 1,
                width = "normal",
            },
            new = {
                type = "input",
                name = "New",
                desc = "Create a new profile",
                get = function() return "" end,
                set = function(info, value)
                    if value and value ~= "" then
                        db:SetProfile(value)
                    end
                end,
                order = 2,
                width = "half",
            },
            reset = {
                type = "execute",
                name = "Reset",
                desc = "Reset current profile to defaults",
                func = function()
                    db:ResetProfile()
                end,
                confirm = true,
                confirmText = "Reset profile to defaults?",
                order = 3,
                width = "half",
            },
        },
    }
end

--[[--------------------------------------------------------------------
    Standalone Profile Dialog
----------------------------------------------------------------------]]

--- Create a standalone profile management dialog
-- @param db table - Database instance
-- @param parentFrame Frame - Optional parent frame
-- @return Frame - The dialog frame
function LoolibProfileOptionsMixin:CreateDialog(db, parentFrame)
    local ConfigDialog = Loolib:GetModule("ConfigDialog")
    if not ConfigDialog or not ConfigDialog.Dialog then
        Loolib:Error("ConfigDialog not available")
        return nil
    end

    -- Register temporary options table
    local appName = "_ProfileDialog_" .. tostring(db)
    local options = self:GetOptionsTable(db)

    local ConfigRegistry = Loolib:GetModule("ConfigRegistry")
    if ConfigRegistry and ConfigRegistry.Registry then
        ConfigRegistry.Registry:RegisterOptionsTable(appName, options, true)
    end

    -- Open the dialog
    return ConfigDialog.Dialog:Open(appName, parentFrame)
end

--- Show export dialog
-- @param db table - Database instance
function LoolibProfileOptionsMixin:ShowExportDialog(db)
    local Serializer = Loolib:GetModule("Serializer")
    if not Serializer then
        Loolib:Error("Serializer module not found")
        return
    end
    
    local currentProfile = db:GetCurrentProfile()
    -- Get the raw profile table. This depends on DB implementation.
    -- Assuming typical DB structure where profile data is accessible.
    -- If LoolibSavedVariables, we might need a specific method.
    local profileData = db:GetProfileData(currentProfile)
    
    if not profileData then
         -- Fallback if specific API doesn't exist, though GetProfileData should be standard
         -- If not, we can't export easily without knowing internal structure.
         -- Let's assume GetProfileData exists or we try to serialize the result of GetProfile(current)
         if db.profile then
             profileData = db.profile
         else
             Loolib:Error("Could not retrieve profile data for export")
             return
         end
    end

    local data = {
        profileName = currentProfile,
        timestamp = time(),
        data = profileData
    }
    
    local serialized = Serializer.Serializer:Serialize(data)
    
    -- Show a dialog with the text (using StaticPopup or similar)
    -- Since we don't have a dedicated text dialog in Loolib yet, we'll use a basic one or LoolibConfigDialog if it supports it.
    -- For now, we'll assume a simple Copy box is needed.
    
    -- Check for AceGUI or similar if available, or use our own.
    -- Since we are in Loolib, let's rely on Loolib tools.
    -- We'll define a StaticPopup for now as a fallback.
    
    local popupName = "LOOLIB_EXPORT_PROFILE"
    if not StaticPopupDialogs[popupName] then
        StaticPopupDialogs[popupName] = {
            text = "Export Profile: " .. currentProfile .. "\n(Ctrl+C to copy)",
            button1 = "Close",
            hasEditBox = true,
            maxLetters = 0,
            OnShow = function(self)
                self.editBox:SetText(serialized)
                self.editBox:SetFocus()
                self.editBox:HighlightText()
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    
    -- Update text for this specific show
    StaticPopupDialogs[popupName].text = "Export Profile: " .. currentProfile .. "\n(Ctrl+C to copy)"
    StaticPopupDialogs[popupName].OnShow = function(self)
        self.editBox:SetText(serialized)
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end
    
    StaticPopup_Show(popupName)
end

--- Show import dialog
-- @param db table - Database instance
function LoolibProfileOptionsMixin:ShowImportDialog(db)
    local popupName = "LOOLIB_IMPORT_PROFILE"
    if not StaticPopupDialogs[popupName] then
        StaticPopupDialogs[popupName] = {
            text = "Import Profile\n(Ctrl+V to paste)",
            button1 = "Import",
            button2 = "Cancel",
            hasEditBox = true,
            maxLetters = 0,
            OnAccept = function(self)
                local text = self.editBox:GetText()
                Loolib.ProfileOptions:ImportProfile(db, text)
            end,
            EditBoxOnEnterPressed = function(self)
                local text = self:GetText()
                Loolib.ProfileOptions:ImportProfile(db, text)
                self:GetParent():Hide()
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    
    StaticPopup_Show(popupName)
end

--- Import profile from string
-- @param db table - Database instance
-- @param str string - Serialized profile string
function LoolibProfileOptionsMixin:ImportProfile(db, str)
    local Serializer = Loolib:GetModule("Serializer")
    if not Serializer then
        Loolib:Error("Serializer module not found")
        return
    end

    local success, data = Serializer.Serializer:Deserialize(str)
    if not success then
        Loolib:Error("Failed to deserialize profile: " .. tostring(data))
        return
    end
    
    if type(data) ~= "table" or not data.data then
        Loolib:Error("Invalid profile data format")
        return
    end
    
    local profileName = data.profileName or "Imported"
    
    -- Ask for name if it already exists? Or just overwrite/append?
    -- For simplicity, if it exists, we'll append " (Imported)"
    local profiles = db:GetProfiles()
    local nameExists = false
    for _, name in ipairs(profiles) do
        if name == profileName then
            nameExists = true
            break
        end
    end
    
    if nameExists then
        profileName = profileName .. " (Imported)"
    end
    
    -- Create/Set profile
    db:SetProfile(profileName)
    
    -- Overwrite data
    -- We assume db has a way to bulk set data or we do it manually
    -- Since LoolibSavedVariablesMixin usually exposes .profile
    if db.profile then
        -- Wipe current
        wipe(db.profile)
        -- Copy new
        for k, v in pairs(data.data) do
            db.profile[k] = v
        end
        -- Notify change
        if db.OnProfileChanged then
            db:OnProfileChanged(db, profileName)
        end
        Loolib:Print("Profile '" .. profileName .. "' imported successfully.")
    else
        Loolib:Error("Could not write profile data")
    end
end

--[[--------------------------------------------------------------------
    Factory and Singleton
----------------------------------------------------------------------]]

--- Create a new profile options instance
-- @return table - New instance
function CreateLoolibProfileOptions()
    return LoolibCreateFromMixins(LoolibProfileOptionsMixin)
end

-- Create the singleton instance
local ProfileOptions = CreateLoolibProfileOptions()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local ProfileOptionsModule = {
    Mixin = LoolibProfileOptionsMixin,
    Create = CreateLoolibProfileOptions,

    -- Convenience access to singleton methods
    GetOptionsTable = function(db, noDefaultProfiles)
        return ProfileOptions:GetOptionsTable(db, noDefaultProfiles)
    end,
    GetCompactOptionsTable = function(db)
        return ProfileOptions:GetCompactOptionsTable(db)
    end,
    CreateDialog = function(db, parentFrame)
        return ProfileOptions:CreateDialog(db, parentFrame)
    end,
}

Loolib:RegisterModule("ProfileOptions", ProfileOptionsModule)
