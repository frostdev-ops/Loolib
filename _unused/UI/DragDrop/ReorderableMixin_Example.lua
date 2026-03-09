--[[--------------------------------------------------------------------
    ReorderableMixin - Usage Examples

    This file demonstrates how to integrate ReorderableMixin with
    ScrollableList and custom list implementations.
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
    Example 1: Reorderable ScrollableList
----------------------------------------------------------------------]]

local function Example_ScrollableList(parent)
    local Loolib = LibStub("Loolib")

    -- Create data provider
    local data = {"Item 1", "Item 2", "Item 3", "Item 4", "Item 5"}
    local dataProvider = CreateLoolibDataProvider()
    for _, item in ipairs(data) do
        dataProvider:Insert(item)
    end

    -- Create list with reorderable mixin
    local list = CreateFrame("Frame", nil, parent)
    LoolibMixin(list, LoolibScrollableListMixin, LoolibReorderableMixin)
    list:OnLoad()
    list:InitReorderable()

    -- Configure list
    list:SetDataProvider(dataProvider)
    list:SetItemHeight(24)
    list:SetInitializer(function(frame, itemData, index)
        if not frame.Text then
            frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            frame.Text:SetPoint("LEFT", 8, 0)
        end
        frame.Text:SetText(itemData)
    end)

    -- Configure reordering
    list:SetReorderEnabled(true)
    list:SetReorderButton("LeftButton")
    list:SetReorderModifier("shift")  -- Require Shift key

    -- Set up data reorder callback
    list:SetDataReorderCallback(function(fromIndex, toIndex)
        -- Reorder the backing data array
        local item = table.remove(data, fromIndex)
        table.insert(data, toIndex, item)

        -- Rebuild data provider
        dataProvider:Flush()
        for _, d in ipairs(data) do
            dataProvider:Insert(d)
        end
    end)

    -- Register event callbacks
    list:RegisterCallback("OnItemDragStart", function(_, item, index)
        print("Started dragging item at index", index)
    end)

    list:RegisterCallback("OnItemDragEnd", function(_, item, fromIndex, toIndex)
        if toIndex then
            print("Dropped item from", fromIndex, "to", toIndex)
        else
            print("Drag cancelled")
        end
    end)

    list:RegisterCallback("OnItemReorder", function(_, fromIndex, toIndex)
        print("Items reordered:", fromIndex, "->", toIndex)
    end)

    return list
end

--[[--------------------------------------------------------------------
    Example 2: Custom List with Reordering (MRT Pattern)
----------------------------------------------------------------------]]

local function Example_CustomList(parent)
    -- Create main frame
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(300, 400)

    -- Apply reorderable mixin
    LoolibMixin(frame, LoolibReorderableMixin)
    frame:InitReorderable()

    -- Data array
    frame.data = {"Player 1", "Player 2", "Player 3", "Player 4"}

    -- Create list lines (MRT pattern)
    frame.List = {}
    for i = 1, 10 do
        local line = CreateFrame("Button", nil, frame)
        line:SetSize(280, 24)
        line:SetPoint("TOPLEFT", 10, -10 - (i - 1) * 24)

        -- Background
        local bg = line:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        line.Background = bg

        -- Text
        local text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", 8, 0)
        line.Text = text

        frame.List[i] = line
    end

    -- Update function
    function frame:Update()
        for i = 1, #self.List do
            local line = self.List[i]
            local data = self.data[i]

            if data then
                line.Text:SetText(data)
                line:Show()

                -- Set up reorderable item
                self:SetupReorderableItem(line, i)
            else
                line:Hide()
            end
        end
    end

    -- Override _GetVisibleItems for custom list
    function frame:_GetVisibleItems()
        local items = {}
        for _, line in ipairs(self.List) do
            if line:IsShown() then
                table.insert(items, line)
            end
        end
        return items
    end

    -- Configure reordering
    frame:SetReorderEnabled(true)
    frame:SetDataReorderCallback(function(fromIndex, toIndex)
        -- Reorder data array
        local item = table.remove(frame.data, fromIndex)
        table.insert(frame.data, toIndex, item)

        -- Refresh list
        frame:Update()
    end)

    -- Initial update
    frame:Update()

    return frame
end

--[[--------------------------------------------------------------------
    Example 3: Nested Frame Reordering (Complex Data)
----------------------------------------------------------------------]]

local function Example_ComplexData(parent)
    local Loolib = LibStub("Loolib")

    -- Complex data structure
    local players = {
        {name = "Tank", class = "WARRIOR", role = "TANK"},
        {name = "Healer", class = "PRIEST", role = "HEALER"},
        {name = "DPS1", class = "MAGE", role = "DPS"},
        {name = "DPS2", class = "ROGUE", role = "DPS"},
    }

    local dataProvider = CreateLoolibDataProvider()
    for _, player in ipairs(players) do
        dataProvider:Insert(player)
    end

    local list = CreateFrame("Frame", nil, parent)
    LoolibMixin(list, LoolibScrollableListMixin, LoolibReorderableMixin)
    list:OnLoad()
    list:InitReorderable()

    list:SetDataProvider(dataProvider)
    list:SetItemHeight(32)
    list:SetInitializer(function(frame, playerData, index)
        if not frame.NameText then
            frame.NameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            frame.NameText:SetPoint("LEFT", 8, 0)

            frame.ClassText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            frame.ClassText:SetPoint("RIGHT", -8, 0)
        end

        frame.NameText:SetText(playerData.name)
        frame.ClassText:SetText(playerData.class)

        -- Color by role
        local color
        if playerData.role == "TANK" then
            color = {0.2, 0.5, 1.0}
        elseif playerData.role == "HEALER" then
            color = {0.2, 1.0, 0.2}
        else
            color = {1.0, 0.2, 0.2}
        end
        frame.NameText:SetTextColor(unpack(color))
    end)

    -- Configure reordering
    list:SetReorderEnabled(true)
    list:SetReorderButton("LeftButton")
    list:SetDataReorderCallback(function(fromIndex, toIndex)
        -- Reorder players array
        local player = table.remove(players, fromIndex)
        table.insert(players, toIndex, player)

        -- Rebuild data provider
        dataProvider:Flush()
        for _, p in ipairs(players) do
            dataProvider:Insert(p)
        end
    end)

    return list
end

--[[--------------------------------------------------------------------
    Example 4: No Modifier, Right Button Drag
----------------------------------------------------------------------]]

local function Example_RightButtonDrag(parent)
    local list = Example_ScrollableList(parent)

    -- Allow drag without modifier, using right mouse button
    list:SetReorderModifier(nil)
    list:SetReorderButton("RightButton")

    return list
end

--[[--------------------------------------------------------------------
    Example 5: Manual Swap (Programmatic Reordering)
----------------------------------------------------------------------]]

local function Example_ManualSwap(parent)
    local list = Example_ScrollableList(parent)

    -- Create buttons to swap items
    local swapBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    swapBtn:SetSize(100, 24)
    swapBtn:SetPoint("BOTTOM", parent, "BOTTOM", 0, 10)
    swapBtn:SetText("Swap 1 & 3")
    swapBtn:SetScript("OnClick", function()
        list:SwapItems(1, 3)
    end)

    return list
end
