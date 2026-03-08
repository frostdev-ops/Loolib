--[[--------------------------------------------------------------------
    Loolib - DragGhost Usage Example

    This file demonstrates how to use the LoolibDragGhostMixin for
    implementing drag-and-drop operations with visual feedback.
----------------------------------------------------------------------]]

--[[
    EXAMPLE 1: Basic Drag Ghost with Shared Instance

    This example shows the simplest usage - using the shared singleton
    ghost for a simple drag operation.
]]

local function Example1_BasicDragGhost()
    -- Create a draggable button
    local button = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    button:SetSize(100, 30)
    button:SetPoint("CENTER")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    button:SetBackdropColor(0.2, 0.2, 0.2, 1)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText("Drag Me")

    -- Enable mouse and dragging
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")

    -- Get shared ghost
    local ghost = LoolibGetSharedDragGhost()

    -- OnDragStart: Show the ghost
    button:SetScript("OnDragStart", function(self)
        ghost:ShowFor(self, {
            label = "Dragging Button",
            icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        })
    end)

    -- OnDragStop: Hide the ghost
    button:SetScript("OnDragStop", function(self)
        ghost:HideGhost()
    end)

    return button
end

--[[
    EXAMPLE 2: Custom Ghost with Validity Checking

    This example creates a custom ghost and checks drop validity
    based on mouse position.
]]

local function Example2_ValidityChecking()
    -- Create source button
    local source = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    source:SetSize(100, 30)
    source:SetPoint("LEFT", UIParent, "CENTER", -150, 0)
    source:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    source:SetBackdropColor(0.2, 0.3, 0.2, 1)
    source:SetBackdropBorderColor(0.3, 0.6, 0.3, 1)

    local sourceText = source:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sourceText:SetPoint("CENTER")
    sourceText:SetText("Drag from here")

    -- Create drop target
    local target = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    target:SetSize(150, 80)
    target:SetPoint("RIGHT", UIParent, "CENTER", 150, 0)
    target:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    target:SetBackdropColor(0.2, 0.2, 0.3, 1)
    target:SetBackdropBorderColor(0.3, 0.3, 0.6, 1)

    local targetText = target:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetText:SetPoint("CENTER")
    targetText:SetText("Drop here")

    -- Create custom ghost
    local ghost = LoolibCreateDragGhost()
    ghost:ShowIndicator(true)  -- Show checkmark/X indicator

    -- Enable dragging
    source:EnableMouse(true)
    source:RegisterForDrag("LeftButton")

    source:SetScript("OnDragStart", function(self)
        ghost:ShowFor(self, {
            label = "Item",
            icon = "Interface\\Icons\\INV_Misc_Gift_02",
        })
    end)

    source:SetScript("OnDragStop", function(self)
        ghost:HideGhost()
    end)

    -- OnUpdate to check validity
    ghost:HookScript("OnUpdate", function(self, elapsed)
        if not self.isShowing then return end

        -- Get cursor position
        local cursorX, cursorY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cursorX, cursorY = cursorX / scale, cursorY / scale

        -- Check if cursor is over target
        local left, bottom = target:GetLeft(), target:GetBottom()
        local right, top = target:GetRight(), target:GetTop()

        local isValid = false
        if left and bottom and right and top then
            isValid = cursorX >= left and cursorX <= right and
                      cursorY >= bottom and cursorY <= top
        end

        self:SetValid(isValid)
    end)

    return source, target, ghost
end

--[[
    EXAMPLE 3: Clone Appearance

    This example shows how to clone the visual appearance of the
    source frame for a more seamless drag effect.
]]

local function Example3_CloneAppearance()
    -- Create a styled button
    local button = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    button:SetSize(120, 40)
    button:SetPoint("CENTER", 0, 100)
    button:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    button:SetBackdropColor(0.3, 0.1, 0.1, 1)

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    text:SetText("Styled Button")

    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")

    local ghost = LoolibCreateDragGhost()

    button:SetScript("OnDragStart", function(self)
        ghost:ShowFor(self)
        ghost:CloneAppearance(self)  -- Clone the visual style
        ghost:SetLabel("Dragging...")
    end)

    button:SetScript("OnDragStop", function(self)
        ghost:HideGhost()
    end)

    return button, ghost
end

--[[
    EXAMPLE 4: Custom Colors

    This example demonstrates custom valid/invalid colors.
]]

local function Example4_CustomColors()
    local button = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    button:SetSize(100, 30)
    button:SetPoint("CENTER", 0, -100)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    button:SetBackdropColor(0.2, 0.2, 0.2, 1)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText("Custom Colors")

    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")

    local ghost = LoolibCreateDragGhost()

    -- Set custom colors (blue for valid, orange for invalid)
    ghost:SetColors(
        {r = 0.5, g = 0.7, b = 1, a = 0.8},  -- Valid: light blue
        {r = 1, g = 0.5, b = 0.2, a = 0.8},  -- Invalid: orange
        {r = 0.2, g = 0.5, b = 1, a = 1},    -- Valid border: blue
        {r = 1, g = 0.4, b = 0, a = 1}       -- Invalid border: orange
    )

    local isValid = true
    button:SetScript("OnDragStart", function(self)
        ghost:ShowFor(self, "Custom Styled Ghost")
    end)

    button:SetScript("OnDragStop", function(self)
        ghost:HideGhost()
    end)

    -- Toggle validity on click (for demonstration)
    ghost:HookScript("OnUpdate", function(self, elapsed)
        if not self.isShowing then return end

        -- Toggle valid/invalid every second for demo
        if not self.lastToggle then self.lastToggle = 0 end
        self.lastToggle = self.lastToggle + elapsed

        if self.lastToggle > 1 then
            isValid = not isValid
            self:SetValid(isValid)
            self.lastToggle = 0
        end
    end)

    return button, ghost
end

--[[
    EXAMPLE 5: Using with ObjectPool

    This example shows how to pool multiple ghost instances for
    multi-object drag scenarios.
]]

local function Example5_PooledGhosts()
    local Loolib = LibStub("Loolib")
    local UI = Loolib:GetModule("UI")

    -- Create a pool of drag ghosts
    local ghostPool = CreateLoolibFramePoolWithMixins(
        "Frame",
        UIParent,
        "BackdropTemplate",
        nil,
        {LoolibDragGhostMixin}
    )

    -- Acquire ghost with initialization
    local ghost1 = LoolibAcquireFrame(ghostPool, function(ghost)
        ghost:OnLoad()
    end)

    local ghost2 = LoolibAcquireFrame(ghostPool, function(ghost)
        ghost:OnLoad()
    end)

    -- Use ghosts...
    ghost1:ShowFor(someFrame1, "Ghost 1")
    ghost2:ShowFor(someFrame2, "Ghost 2")

    -- Release when done
    ghostPool:Release(ghost1)
    ghostPool:Release(ghost2)

    return ghostPool
end

--[[
    USAGE NOTES:

    1. Shared vs Custom:
       - Use LoolibGetSharedDragGhost() for simple single-drag scenarios
       - Use LoolibCreateDragGhost() for custom ghosts or multiple simultaneous drags

    2. Position Tracking:
       - Ghost automatically follows cursor via OnUpdate
       - Call UpdatePosition() manually if OnUpdate is disabled

    3. Validity Checking:
       - Call SetValid(true/false) based on mouse position or drop target
       - Use ShowIndicator(true) to display checkmark/X visual feedback

    4. Appearance:
       - Set icon and label via ShowFor(frame, {icon=..., label=...})
       - Use CloneAppearance() to copy source frame's visual style
       - Customize colors with SetColors()

    5. Performance:
       - OnUpdate runs every frame while ghost is showing
       - Keep validity checking logic lightweight
       - Pool ghosts if creating many instances
]]
