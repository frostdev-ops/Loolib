--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    UI/Note/NoteMarkup_Example.lua - Example usage of NoteMarkup

    Demonstrates practical integration of NoteMarkup in a raid note addon.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Example addon that uses NoteMarkup
local ExampleAddon = Loolib:NewAddon("LoolibNoteExample")

--[[--------------------------------------------------------------------
    Setup
----------------------------------------------------------------------]]

function ExampleAddon:OnEnable()
    self.noteProcessor = Loolib:GetModule("NoteMarkup").Get()

    -- Create UI frame
    self:CreateNoteFrame()

    -- Register events
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateNote")
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "UpdateNote")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "UpdateNote")

    print("|cff00ff00Loolib Note Example loaded.|r Type |cffff8800/lnote|r to show note")
end

--[[--------------------------------------------------------------------
    UI Frame Creation
----------------------------------------------------------------------]]

function ExampleAddon:CreateNoteFrame()
    -- Simple scrolling frame for note display
    local frame = CreateFrame("Frame", "LoolibNoteExampleFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(500, 600)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
    frame.title:SetText("Raid Note Example")

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -24, 4)

    -- Content frame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(content)

    -- Text display
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
    text:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -8)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(2)

    -- Update button
    local updateBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    updateBtn:SetSize(100, 22)
    updateBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    updateBtn:SetText("Refresh")
    updateBtn:SetScript("OnClick", function()
        self:UpdateNote()
    end)

    -- Role indicator
    local roleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    roleText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    roleText:SetJustifyH("RIGHT")

    frame.scrollFrame = scrollFrame
    frame.content = content
    frame.text = text
    frame.roleText = roleText

    self.noteFrame = frame
end

--[[--------------------------------------------------------------------
    Example Raid Note
----------------------------------------------------------------------]]

-- This is what raid leader writes (with markup)
local EXAMPLE_RAID_NOTE = [[
|cffff8800BOSS: Example Mythic Fight|r

|cff00ff00OVERVIEW:|r
This boss has 3 phases. Save cooldowns for Phase 2.

|cffffff00PHASE 1:|r

{H}
|cff00ff00HEALERS:|r
- Dispel magic DoTs immediately (|A:nameplates-InterruptShield:16:16|a priority)
- Heavy raid damage every 30 seconds
- Save major CDs for Phase 2
- Position: Behind boss, spread 10yd
{/H}

{T}
|cff0080ffTANKS:|r
- Taunt on 3 stacks of debuff
- Face boss AWAY from raid
- Move boss to edge when adds spawn
- Tank swap = 1 → 2 → 1 (repeat)
{/T}

{D}
|cffff0000DPS:|r
- Kill adds IMMEDIATELY (priority targets)
- Cleave adds if grouped
- Single target boss when no adds
- Do NOT stand in fire (obvious but important)
{/D}

|cffffff00ASSIGNMENTS:|r

{P:Alice,Bob}
|cffff00ffSOAKERS (Alice, Bob):|r
- Stack on {rt1} marker
- Soak purple swirls (1 person each)
- Call in voice when soaking
- Rotate: Alice → Bob → Alice
{/P}

{P:Charlie,Dave,Eve}
|cffff00ffINTERRUPT TEAM (Charlie, Dave, Eve):|r
- Interrupt boss cast "Shadow Bolt"
- Rotation order: Charlie → Dave → Eve
- Backup: Anyone with interrupt ready
{/P}

{C:MAGE,WARLOCK,HUNTER}
|cff9400d3RANGED DPS:|r
- Spread 8 yards minimum
- Kill adds from range
- Focus fire priority: Small → Medium → Large
{/C}

{C:WARRIOR,ROGUE,DEATHKNIGHT,DEMONHUNTER}
|cffaa0000MELEE DPS:|r
- Stack behind boss
- Cleave adds when they spawn
- Watch for ground effects (move fast)
{/C}

|cffffff00GROUP POSITIONS:|r

{G12}
|cffaaffaaGROUPS 1 & 2:|r
- Position: LEFT side of room
- Kill LEFT adds first
- Stay away from right side
{/G}

{G34}
|cffaaffaaGROUPS 3 & 4:|r
- Position: RIGHT side of room
- Kill RIGHT adds first
- Stay away from left side
{/G}

|cffffff00BLOODLUST TIMING:|r
{C:MAGE,SHAMAN,EVOKER,HUNTER}
Time Warp / Bloodlust / Heroism:
- Use at PHASE 2 start (70% HP)
- Call in voice before using
{/C}

|cffff0000IMPORTANT:|r Everyone must:
- Dodge swirls on ground
- Run OUT with bomb debuff
- Stack IN for shield mechanic
- Call cooldowns in voice

|cffffff00PHASE 2:|r (70% HP)
- Boss gains damage buff
- Adds spawn faster
- Same mechanics, just faster

|cffffff00PHASE 3:|r (30% HP)
- Burn phase
- Use ALL cooldowns
- Ignore adds (if needed)
- Hero/Lust if not used yet

Good luck!
]]

--[[--------------------------------------------------------------------
    Note Processing and Display
----------------------------------------------------------------------]]

function ExampleAddon:UpdateNote()
    if not self.noteFrame then return end

    -- Update processor context
    self.noteProcessor:UpdatePlayerContext()
    local context = self.noteProcessor:GetContext()

    -- Update role indicator
    local roleIcon = ""
    if context.playerRole == "TANK" then
        roleIcon = "|A:groupfinder-icon-role-large-tank:16:16|a"
    elseif context.playerRole == "HEALER" then
        roleIcon = "|A:groupfinder-icon-role-large-heal:16:16|a"
    elseif context.playerRole == "DAMAGER" then
        roleIcon = "|A:groupfinder-icon-role-large-dps:16:16|a"
    end

    self.noteFrame.roleText:SetText(string.format(
        "%s %s (Group %d)",
        roleIcon,
        context.playerRole or "NONE",
        context.playerGroup or 0
    ))

    -- Process note with conditionals
    local filteredNote = self.noteProcessor:ProcessText(EXAMPLE_RAID_NOTE)

    -- Display filtered note
    self.noteFrame.text:SetText(filteredNote)

    -- Update content height
    local textHeight = self.noteFrame.text:GetStringHeight()
    self.noteFrame.content:SetHeight(math.max(textHeight + 16,
        self.noteFrame.scrollFrame:GetHeight()))
end

function ExampleAddon:ShowNote()
    if not self.noteFrame then
        self:CreateNoteFrame()
    end

    self:UpdateNote()
    self.noteFrame:Show()
end

function ExampleAddon:HideNote()
    if self.noteFrame then
        self.noteFrame:Hide()
    end
end

function ExampleAddon:ToggleNote()
    if self.noteFrame and self.noteFrame:IsShown() then
        self:HideNote()
    else
        self:ShowNote()
    end
end

--[[--------------------------------------------------------------------
    Assignment Checking
----------------------------------------------------------------------]]

function ExampleAddon:CheckAssignments()
    local processor = self.noteProcessor
    processor:UpdatePlayerContext()

    print("|cff00ff00=== Assignment Analysis ===|r")

    -- Check if current player has assignments
    local hasContent = processor:HasVisibleContent(EXAMPLE_RAID_NOTE)
    print("You have assignments:", hasContent and "|cff00ff00YES|r" or "|cffff0000NO|r")

    -- List all assigned players
    local players = processor:ExtractPlayerNames(EXAMPLE_RAID_NOTE)
    if #players > 0 then
        print("|cffff8800Assigned Players:|r", table.concat(players, ", "))
    end

    -- List required classes
    local classes = processor:ExtractClasses(EXAMPLE_RAID_NOTE)
    if #classes > 0 then
        print("|cffff8800Required Classes:|r", table.concat(classes, ", "))
    end

    -- List mentioned roles
    local roles = processor:ExtractRoles(EXAMPLE_RAID_NOTE)
    if #roles > 0 then
        print("|cffff8800Mentioned Roles:|r", table.concat(roles, ", "))
    end

    -- List group assignments
    local groups = processor:ExtractGroups(EXAMPLE_RAID_NOTE)
    if #groups > 0 then
        print("|cffff8800Group Assignments:|r", table.concat(groups, ", "))
    end
end

--[[--------------------------------------------------------------------
    Advanced: Compare Views
----------------------------------------------------------------------]]

function ExampleAddon:CompareViews()
    -- Create processors with different contexts
    local contexts = {
        {playerRole = "HEALER", playerClass = "PRIEST", playerName = "Alice", playerGroup = 1},
        {playerRole = "TANK", playerClass = "WARRIOR", playerName = "Bob", playerGroup = 2},
        {playerRole = "DAMAGER", playerClass = "MAGE", playerName = "Charlie", playerGroup = 3},
    }

    for i, ctx in ipairs(contexts) do
        local processor = Loolib:GetModule("NoteMarkup").Create()
        processor:SetContext(ctx)

        local filtered = processor:ProcessText(EXAMPLE_RAID_NOTE)

        print("|cff00ff00=================|r")
        print(string.format("|cff00ff00View %d: %s (%s, Group %d)|r",
            i, ctx.playerName, ctx.playerRole, ctx.playerGroup))
        print("|cff00ff00=================|r")
        print(filtered)
        print("")
    end
end

--[[--------------------------------------------------------------------
    Slash Commands
----------------------------------------------------------------------]]

SLASH_LOOLIBEXAMPLENOTE1 = "/lnote"
SlashCmdList.LOOLIBEXAMPLENOTE = function(msg)
    if msg == "show" then
        ExampleAddon:ShowNote()
    elseif msg == "hide" then
        ExampleAddon:HideNote()
    elseif msg == "check" then
        ExampleAddon:CheckAssignments()
    elseif msg == "compare" then
        ExampleAddon:CompareViews()
    else
        ExampleAddon:ToggleNote()
    end
end

print("|cff00ff00Loolib Note Example loaded.|r")
print("Commands: |cffff8800/lnote|r (toggle), |cffff8800/lnote show|r, |cffff8800/lnote hide|r")
print("          |cffff8800/lnote check|r (assignments), |cffff8800/lnote compare|r (different views)")
