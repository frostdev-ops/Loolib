--[[--------------------------------------------------------------------
    Loolib - Transmog Utilities

    Provides comprehensive transmog-related functionality using the
    C_TransmogCollection API with optional CanIMogIt addon integration.

    Features:
    - Check if items can be transmogged
    - Detect if player knows appearances (any source or specific source)
    - Determine if player can learn appearances (class/armor restrictions)
    - Get appearance source IDs
    - Integration with CanIMogIt addon (if loaded)

    API:
    - IsTransmoggable(itemLink) -> boolean
    - PlayerKnowsAppearance(itemLink) -> boolean
    - PlayerKnowsAppearanceFromItem(itemLink) -> boolean
    - CanLearnAppearance(itemLink) -> boolean, reason|nil
    - GetAppearanceSourceID(itemLink) -> sourceID|nil
    - GetAppearanceInfo(itemLink) -> appearanceID, sourceID
    - HasCanIMogIt() -> boolean
    - CanIMogItCheck(itemLink) -> status|nil

    @author James Kueller
    @created 2025-12-06
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local Transmog = Loolib:GetOrCreateModule("Transmog")

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

-- Transmog appearance states (mirrors CanIMogIt states)
Transmog.APPEARANCE_KNOWN = "KNOWN"
Transmog.APPEARANCE_KNOWN_FROM_ITEM = "KNOWN_FROM_ITEM"
Transmog.APPEARANCE_UNKNOWN = "UNKNOWN"
Transmog.APPEARANCE_CANNOT_LEARN = "CANNOT_LEARN"
Transmog.APPEARANCE_NOT_TRANSMOGGABLE = "NOT_TRANSMOGGABLE"

--[[--------------------------------------------------------------------
    CanIMogIt Integration
----------------------------------------------------------------------]]

--- Check if the CanIMogIt addon is loaded
-- @return boolean - True if CanIMogIt is available
function Transmog:HasCanIMogIt()
    return _G.CanIMogIt ~= nil
end

--- Get the CanIMogIt addon reference
-- @return table|nil - The CanIMogIt addon table, or nil if not loaded
function Transmog:GetCanIMogIt()
    return _G.CanIMogIt
end

--[[--------------------------------------------------------------------
    Core Transmog Detection
----------------------------------------------------------------------]]

--- Check if an item can be transmogged
-- Uses CanIMogIt if available, otherwise falls back to C_TransmogCollection.
-- @param itemLink string - Item link or item ID
-- @return boolean - True if the item can be transmogged
function Transmog:IsTransmoggable(itemLink)
    if not itemLink then return false end

    -- Try CanIMogIt first if available
    local canIMogIt = self:GetCanIMogIt()
    if canIMogIt and canIMogIt.IsTransmogable then
        local success, result = pcall(canIMogIt.IsTransmogable, canIMogIt, itemLink)
        if success then
            return result
        end
    end

    -- Fall back to C_TransmogCollection
    local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
    return appearanceID ~= nil
end

--- Get appearance information for an item
-- @param itemLink string - Item link or item ID
-- @return number|nil appearanceID - The appearance ID
-- @return number|nil sourceID - The modified appearance source ID
function Transmog:GetAppearanceInfo(itemLink)
    if not itemLink then return nil, nil end

    local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
    return appearanceID, sourceID
end

--- Get the appearance source ID for an item
-- @param itemLink string - Item link or item ID
-- @return number|nil - The modified appearance source ID
function Transmog:GetAppearanceSourceID(itemLink)
    if not itemLink then return nil end

    local _, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
    return sourceID
end

--[[--------------------------------------------------------------------
    Player Knowledge Detection
----------------------------------------------------------------------]]

--- Internal function to check if player knows a transmog appearance
-- @param itemLink string - Item link or item ID
-- @param checkSource boolean - If true, check if player knows from this specific source
-- @return boolean - True if player knows the appearance (optionally from this source)
local function PlayerKnowsTransmogInternal(itemLink, checkSource)
    if not itemLink then return false end

    -- Try CanIMogIt first if available
    local canIMogIt = Transmog:GetCanIMogIt()
    if canIMogIt then
        local funcName = checkSource and "PlayerKnowsTransmogFromItem" or "PlayerKnowsTransmog"
        if canIMogIt[funcName] then
            local success, result = pcall(canIMogIt[funcName], canIMogIt, itemLink)
            if success then
                return result
            end
        end
    end

    -- Fall back to C_TransmogCollection
    local appearanceID, itemModifiedAppearanceID = C_TransmogCollection.GetItemInfo(itemLink)
    if not appearanceID then
        return false
    end

    -- Get all sources for this appearance
    local sourceIDs = C_TransmogCollection.GetAllAppearanceSources(appearanceID)
    if not sourceIDs then
        return false
    end

    -- Check if player knows any source (or the specific source if checkSource is true)
    for _, sourceID in ipairs(sourceIDs) do
        local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
        if sourceInfo and sourceInfo.isCollected then
            -- If we're checking for any source, return true immediately
            if not checkSource then
                return true
            end

            -- If we're checking for this specific source, verify it matches
            if itemModifiedAppearanceID == sourceID then
                return true
            end
        end
    end

    return false
end

--- Check if the player knows this item's appearance from any source
-- @param itemLink string - Item link or item ID
-- @return boolean - True if player knows the appearance (from any source)
function Transmog:PlayerKnowsAppearance(itemLink)
    return PlayerKnowsTransmogInternal(itemLink, false)
end

--- Check if the player knows this appearance from this specific item
-- @param itemLink string - Item link or item ID
-- @return boolean - True if player knows the appearance from this specific item
function Transmog:PlayerKnowsAppearanceFromItem(itemLink)
    return PlayerKnowsTransmogInternal(itemLink, true)
end

--[[--------------------------------------------------------------------
    Learning Capability Detection
----------------------------------------------------------------------]]

--- Check if the player's character can learn this appearance
-- Takes into account class restrictions, armor type, and collectability.
-- @param itemLink string - Item link or item ID
-- @return boolean canLearn - True if the player can learn this appearance
-- @return string|nil reason - If cannot learn, a reason string (e.g., "Wrong armor type", "Wrong class")
function Transmog:CanLearnAppearance(itemLink)
    if not itemLink then
        return false, "Invalid item"
    end

    -- Try CanIMogIt first if available
    local canIMogIt = self:GetCanIMogIt()
    if canIMogIt and canIMogIt.CharacterCanLearnTransmog then
        local success, result = pcall(canIMogIt.CharacterCanLearnTransmog, canIMogIt, itemLink)
        if success then
            return result, nil
        end
    end

    -- Fall back to C_TransmogCollection
    local sourceID = self:GetAppearanceSourceID(itemLink)
    if not sourceID then
        return false, "Not transmoggable"
    end

    -- Check if player can collect this source
    local canCollect, failureReason = C_TransmogCollection.PlayerCanCollectSource(sourceID)

    if not canCollect then
        -- Convert failure reason enum to readable string
        local reasonText = "Cannot learn"
        if failureReason then
            -- TransmogCollectionType enumeration
            -- 0 = NONE, 1 = HEAD, 2 = SHOULDER, etc.
            -- Use GetAppearanceSourceInfo for more details
            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
            if sourceInfo then
                if sourceInfo.useError then
                    reasonText = sourceInfo.useErrorType or "Cannot use"
                end
            end
        end
        return false, reasonText
    end

    return true, nil
end

--[[--------------------------------------------------------------------
    Combined CanIMogIt Status Check
----------------------------------------------------------------------]]

--- Get comprehensive transmog status using CanIMogIt if available, otherwise native API
-- @param itemLink string - Item link or item ID
-- @return string|nil - One of the APPEARANCE_* constants, or nil if item is invalid
function Transmog:CanIMogItCheck(itemLink)
    if not itemLink then return nil end

    -- Try CanIMogIt for most accurate status
    local canIMogIt = self:GetCanIMogIt()
    if canIMogIt and canIMogIt.GetTooltipText then
        -- CanIMogIt provides a comprehensive status check
        local success, text = pcall(canIMogIt.GetTooltipText, canIMogIt, itemLink)
        if success and text then
            -- Parse CanIMogIt status (they use localized strings, so we check patterns)
            if text:find("Known") or text:find("Learned") then
                if self:PlayerKnowsAppearanceFromItem(itemLink) then
                    return self.APPEARANCE_KNOWN_FROM_ITEM
                else
                    return self.APPEARANCE_KNOWN
                end
            elseif text:find("Cannot") or text:find("Unable") then
                return self.APPEARANCE_CANNOT_LEARN
            else
                return self.APPEARANCE_UNKNOWN
            end
        end
    end

    -- Fall back to native API checks
    if not self:IsTransmoggable(itemLink) then
        return self.APPEARANCE_NOT_TRANSMOGGABLE
    end

    if self:PlayerKnowsAppearanceFromItem(itemLink) then
        return self.APPEARANCE_KNOWN_FROM_ITEM
    end

    if self:PlayerKnowsAppearance(itemLink) then
        return self.APPEARANCE_KNOWN
    end

    local canLearn = self:CanLearnAppearance(itemLink)
    if not canLearn then
        return self.APPEARANCE_CANNOT_LEARN
    end

    return self.APPEARANCE_UNKNOWN
end

--[[--------------------------------------------------------------------
    Appearance Source Utilities
----------------------------------------------------------------------]]

--- Get all source IDs for an appearance
-- @param itemLink string - Item link or item ID
-- @return table|nil - Array of source IDs, or nil if no appearance
function Transmog:GetAllAppearanceSources(itemLink)
    if not itemLink then return nil end

    local appearanceID = self:GetAppearanceInfo(itemLink)
    if not appearanceID then return nil end

    return C_TransmogCollection.GetAllAppearanceSources(appearanceID)
end

--- Get detailed source information
-- @param sourceID number - The appearance source ID
-- @return table|nil - Source info table with fields: sourceID, visualID, isCollected, etc.
function Transmog:GetSourceInfo(sourceID)
    if not sourceID then return nil end
    return C_TransmogCollection.GetSourceInfo(sourceID)
end

--- Check if a specific source is collected
-- @param sourceID number - The appearance source ID
-- @return boolean - True if the source is collected
function Transmog:IsSourceCollected(sourceID)
    if not sourceID then return false end

    local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
    return sourceInfo and sourceInfo.isCollected or false
end

--[[--------------------------------------------------------------------
    Collection Statistics
----------------------------------------------------------------------]]

--- Get appearance collection progress for an item's appearance
-- @param itemLink string - Item link or item ID
-- @return number collected - Number of sources collected for this appearance
-- @return number total - Total number of sources for this appearance
function Transmog:GetAppearanceCollectionProgress(itemLink)
    if not itemLink then return 0, 0 end

    local sourceIDs = self:GetAllAppearanceSources(itemLink)
    if not sourceIDs then return 0, 0 end

    local collected = 0
    local total = #sourceIDs

    for _, sourceID in ipairs(sourceIDs) do
        if self:IsSourceCollected(sourceID) then
            collected = collected + 1
        end
    end

    return collected, total
end

--[[--------------------------------------------------------------------
    Utility Functions
----------------------------------------------------------------------]]

--- Get a color code based on transmog status
-- Useful for colorizing item links or text in UI
-- @param itemLink string - Item link or item ID
-- @return string colorCode - A hex color code (e.g., "|cff00ff00" for green)
function Transmog:GetStatusColor(itemLink)
    local status = self:CanIMogItCheck(itemLink)

    if status == self.APPEARANCE_KNOWN_FROM_ITEM then
        return "|cff00ff00" -- Green (known from this item)
    elseif status == self.APPEARANCE_KNOWN then
        return "|cff88ff88" -- Light green (known from different source)
    elseif status == self.APPEARANCE_UNKNOWN then
        return "|cffffff00" -- Yellow (can learn, not yet learned)
    elseif status == self.APPEARANCE_CANNOT_LEARN then
        return "|cffff0000" -- Red (cannot learn)
    elseif status == self.APPEARANCE_NOT_TRANSMOGGABLE then
        return "|cff888888" -- Gray (not transmoggable)
    end

    return "|cffffffff" -- White (unknown/default)
end

--- Get a text description of transmog status
-- @param itemLink string - Item link or item ID
-- @return string - A human-readable status string
function Transmog:GetStatusText(itemLink)
    local status = self:CanIMogItCheck(itemLink)

    if status == self.APPEARANCE_KNOWN_FROM_ITEM then
        return "Collected (this source)"
    elseif status == self.APPEARANCE_KNOWN then
        return "Collected (different source)"
    elseif status == self.APPEARANCE_UNKNOWN then
        return "Not collected"
    elseif status == self.APPEARANCE_CANNOT_LEARN then
        local _, reason = self:CanLearnAppearance(itemLink)
        return "Cannot learn" .. (reason and (": " .. reason) or "")
    elseif status == self.APPEARANCE_NOT_TRANSMOGGABLE then
        return "Not transmoggable"
    end

    return "Unknown"
end

--[[--------------------------------------------------------------------
    Module Registration
----------------------------------------------------------------------]]

return Loolib:RegisterModule("Transmog", Transmog)
