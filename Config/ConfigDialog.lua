--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ConfigDialog - GUI dialog renderer for options tables

    Renders declarative options tables into interactive UI dialogs.
    Supports tree, tab, and inline group layouts with all option types.

    Dependencies (must be loaded before this file):
    - Core/Mixin.lua (LoolibCreateFromMixins)
    - Events/CallbackRegistry.lua (LoolibCallbackRegistryMixin)
    - Config/ConfigRegistry.lua (ConfigRegistry for options access)
    - Config/ConfigTypes.lua (ConfigTypes for type info)
----------------------------------------------------------------------]]

local CreateFrame = CreateFrame
local Settings = Settings
local UIParent = UIParent
local ipairs = ipairs
local next = next
local pairs = pairs
local tostring = tostring
local type = type
local unpack = unpack
local wipe = wipe

local Loolib = LibStub("Loolib")
local Config = Loolib:GetOrCreateModule("Config")
local CreateFromMixins = Loolib.CreateFromMixins
local CallbackRegistryModule = Loolib:GetModule("CallbackRegistry")
local CallbackRegistryMixin = CallbackRegistryModule and CallbackRegistryModule.Mixin
local ConfigTypes = Config.Types

assert(CreateFromMixins, "Loolib.Core.Mixin must be loaded before ConfigDialog")
assert(CallbackRegistryMixin, "Loolib.CallbackRegistry must be loaded before ConfigDialog")
assert(ConfigTypes, "Loolib.Config.Types must be loaded before ConfigDialog")

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

-- Default dimensions (can be overridden per-app via SetDefaultSize)
local DIALOG_WIDTH = 750
local DIALOG_HEIGHT = 520
local TREE_WIDTH = 180
local CONTENT_PADDING = 12
local WIDGET_SPACING = 4
local LABEL_WIDTH = 200

-- Helper function to get dialog dimensions with optional override
local function GetDialogDimensions(appName, defaultSizes)
    local size = defaultSizes and defaultSizes[appName]
    return size and size.width or DIALOG_WIDTH, size and size.height or DIALOG_HEIGHT
end

local WIDTH_MULTIPLIERS = {
    third = 0.333,
    half = 0.5,
    normal = 1.0,
    double = 2.0,
    full = 3.0,
}

--[[--------------------------------------------------------------------
    ConfigDialogMixin

    Main dialog system that renders options tables as interactive UI.
----------------------------------------------------------------------]]

local ConfigDialogMixin = CreateFromMixins(CallbackRegistryMixin)

local DIALOG_EVENTS = {
    "OnDialogOpened",
    "OnDialogClosed",
    "OnGroupSelected",
    "OnOptionChanged",
}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the dialog system
function ConfigDialogMixin:Init()
    CallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(DIALOG_EVENTS)

    self.dialogs = {}          -- appName -> dialog frame
    self.blizPanels = {}       -- appName -> Blizzard settings panel
    self.defaultSizes = {}     -- appName -> {width, height}
    self.selectedPaths = {}    -- appName -> current selected path
    self.widgetPools = {}      -- Frame pools for widgets (type -> pool)
    self.regionPools = {}      -- Pools for regions (FontString, Texture)
    self.filterStates = {}     -- appName -> { searchText, typeFilters, activeFilterCount }
    self.searchTimers = {}     -- appName -> debounce timer handle
end

--- Get or initialize filter state for a dialog
-- @param appName string - The app name
-- @return table - Filter state { searchText, typeFilters, activeFilterCount }
function ConfigDialogMixin:GetFilterState(appName)
    if not self.filterStates[appName] then
        self.filterStates[appName] = {
            searchText = "",
            typeFilters = {},    -- optionType -> boolean (false = hide this type)
            activeFilterCount = 0,
        }
    end
    return self.filterStates[appName]
end

--- Clear all filters for a dialog
-- @param appName string - The app name
function ConfigDialogMixin:ClearAllFilters(appName)
    local filterState = self:GetFilterState(appName)
    filterState.searchText = ""
    wipe(filterState.typeFilters)
    filterState.activeFilterCount = 0

    local dialog = self.dialogs[appName]
    if dialog and dialog.searchBox then
        dialog.searchBox:SetText("")
    end

    self:UpdateFilterUI(appName)
    self:RefreshContent(appName)
end

--- Update filter count display
-- @param appName string - The app name
function ConfigDialogMixin:UpdateFilterUI(appName)
    local dialog = self.dialogs[appName]
    if not dialog then return end

    local filterState = self:GetFilterState(appName)
    local count = 0

    if filterState.searchText ~= "" then
        count = count + 1
    end

    for _, enabled in pairs(filterState.typeFilters) do
        if enabled == false then
            count = count + 1
        end
    end

    filterState.activeFilterCount = count

    -- Update clear button visibility
    if dialog.clearFiltersBtn then
        dialog.clearFiltersBtn:SetShown(count > 0)
    end

    -- Update type filter button text
    if dialog.typeFilterBtn and dialog.typeFilterText then
        local typeCount = 0
        for _, v in pairs(filterState.typeFilters) do
            if v == false then typeCount = typeCount + 1 end
        end

        if typeCount > 0 then
            dialog.typeFilterText:SetText(string.format("Types (%d)", typeCount))
        else
            dialog.typeFilterText:SetText("All Types")
        end
    end
end

--- Check if an option should be shown based on current filters
-- @param option table - The option definition
-- @param info table - The info table for this option
-- @param filterState table - Current filter state
-- @param registry table - The config registry
-- @return boolean - True if option should be shown
function ConfigDialogMixin:ShouldShowOption(option, info, filterState, registry)
    -- Skip if already hidden by config
    if registry:IsHidden(option, info, "dialog") then
        return false
    end

    local searchText = filterState.searchText
    local typeFilters = filterState.typeFilters

    -- Search filter: match name or desc (case-insensitive)
    if searchText and searchText ~= "" then
        local searchLower = searchText:lower()
        local name = registry:ResolveValue(option.name, info) or ""
        local desc = registry:ResolveValue(option.desc, info) or ""

        local nameMatch = name:lower():find(searchLower, 1, true)
        local descMatch = desc:lower():find(searchLower, 1, true)

        if not nameMatch and not descMatch then
            return false
        end
    end

    -- Type filter: check if this option type is hidden
    if next(typeFilters) then
        local optType = option.type
        -- Skip groups, headers, descriptions from type filtering
        if optType ~= "group" and optType ~= "header" and optType ~= "description" then
            if typeFilters[optType] == false then
                return false
            end
        end
    end

    return true
end

--- Check if a group has any visible children (for tree/tab visibility)
-- @param group table - The group option
-- @param rootOptions table - Root options table
-- @param registry table - The config registry
-- @param path table - Current path
-- @param filterState table - Current filter state
-- @param appName string - App name
-- @return boolean - True if group has visible children
function ConfigDialogMixin:HasVisibleChildren(group, rootOptions, registry, path, filterState, appName)
    if not group.args then
        return false
    end

    for key, opt in pairs(group.args) do
        local currentPath = {}
        for _, p in ipairs(path) do currentPath[#currentPath + 1] = p end
        currentPath[#currentPath + 1] = key

        local info = registry:BuildInfoTable(rootOptions, opt, appName, unpack(currentPath))

        if opt.type == "group" then
            -- Recursively check nested groups
            if self:HasVisibleChildren(opt, rootOptions, registry, currentPath, filterState, appName) then
                return true
            end
        else
            -- Check if this leaf option is visible
            if self:ShouldShowOption(opt, info, filterState, registry) then
                return true
            end
        end
    end

    return false
end

--- Check if filters are currently active
-- @param appName string - App name
-- @return boolean - True if any filters are active
function ConfigDialogMixin:HasActiveFilters(appName)
    local filterState = self:GetFilterState(appName)
    if filterState.searchText ~= "" then
        return true
    end
    for _, enabled in pairs(filterState.typeFilters) do
        if enabled == false then
            return true
        end
    end
    return false
end

--[[--------------------------------------------------------------------
    Widget Pooling
----------------------------------------------------------------------]]

--- Get a widget from the pool or create new
-- @param widgetType string - Type of widget (e.g., "button", "editbox")
-- @param parent Frame - Parent frame
-- @param template string - Template to use
-- @param frameTypeOverride string - Optional override for CreateFrame type
-- @return Frame - The widget
function ConfigDialogMixin:AcquireWidget(widgetType, parent, template, frameTypeOverride)
    local pool = self.widgetPools[widgetType]
    if not pool then
        pool = { inactive = {} }
        self.widgetPools[widgetType] = pool
    end

    local widget = table.remove(pool.inactive)
    if not widget then
        -- Create new
        local frameType = frameTypeOverride or "Frame"
        if not frameTypeOverride then
            if widgetType == "button" then frameType = "Button"
            elseif widgetType == "checkbutton" then frameType = "CheckButton"
            elseif widgetType == "editbox" then frameType = "EditBox"
            elseif widgetType == "slider" then frameType = "Slider"
            elseif widgetType == "scrollframe" then frameType = "ScrollFrame"
            end
        end

        widget = CreateFrame(frameType, nil, parent, template)
        widget.pooledWidgetType = widgetType
    end

    widget:SetParent(parent)
    widget:Show()
    widget:ClearAllPoints()

    return widget
end

--- Release all widgets for a specific dialog content frame
-- @param container Frame - The container to clear
function ConfigDialogMixin:ReleaseWidgets(container)
    if not container then return end

    -- Release children (Frames)
    local children = {container:GetChildren()}
    for _, child in ipairs(children) do
        -- Recursively release children of this widget if it's a container
        self:ReleaseWidgets(child)

        if child.pooledWidgetType and self.widgetPools[child.pooledWidgetType] then
            local pool = self.widgetPools[child.pooledWidgetType]

            child:Hide()
            child:ClearAllPoints()
            if child:HasScript("OnEnter") then child:SetScript("OnEnter", nil) end
            if child:HasScript("OnLeave") then child:SetScript("OnLeave", nil) end
            if child:HasScript("OnClick") then child:SetScript("OnClick", nil) end
            if child:HasScript("OnValueChanged") then child:SetScript("OnValueChanged", nil) end
            if child:HasScript("OnKeyDown") then child:SetScript("OnKeyDown", nil) end
            if child:HasScript("OnUpdate") then child:SetScript("OnUpdate", nil) end

            -- More aggressive cleanup - clear text, textures, values
            if child.SetText then child:SetText("") end
            if child.SetNormalTexture then child:SetNormalTexture("") end
            if child.SetHighlightTexture then child:SetHighlightTexture("") end
            if child.SetValue then child:SetValue(0) end
            if child.SetChecked then child:SetChecked(false) end

            table.insert(pool.inactive, child)
        else
            -- Not pooled by us, just hide
            child:Hide()
            child:SetParent(nil)
        end
    end

    -- Release regions (FontStrings, Textures)
    local regions = {container:GetRegions()}
    for _, region in ipairs(regions) do
        region:Hide()
        -- We can't easily pool regions created via parent:CreateFontString
        -- but we can hide them. SetParent(nil) doesn't work for regions.
        -- They'll be orphaned when the container frame is reused.
    end
end

--[[--------------------------------------------------------------------
    Dialog Management
----------------------------------------------------------------------]]

--- Open configuration dialog
-- @param appName string - Registered app name
-- @param container Frame - Optional parent frame (creates standalone if nil)
-- @param ... - Optional path to open specific group
-- @return Frame - Dialog frame
function ConfigDialogMixin:Open(appName, container, ...)
    local registry = Config.Registry

    if not registry then
        Loolib:Error("ConfigRegistry not available")
        return nil
    end

    local options = registry:GetOptionsTable(appName, "dialog")
    if not options then
        Loolib:Error("No options registered for: " .. appName)
        return nil
    end

    -- Check if dialog already exists
    local dialog = self.dialogs[appName]
    if dialog and dialog:IsShown() then
        -- Navigate to path if provided
        if select("#", ...) > 0 then
            self:SelectGroup(appName, ...)
        end
        return dialog
    end

    -- Create new dialog
    dialog = self:CreateDialog(appName, options, container)
    self.dialogs[appName] = dialog  -- Must be set before RefreshContent

    -- Navigate to initial path if provided
    if select("#", ...) > 0 then
        self:SelectGroup(appName, ...)
    else
        -- Select first group
        self:SelectFirstGroup(appName, options)
    end

    dialog:Show()

    -- Refresh content after dialog is shown and registered
    self:RefreshContent(appName)

    self:TriggerEvent("OnDialogOpened", appName)

    return dialog
end

--- Close dialog for specific app
-- @param appName string - The app name
function ConfigDialogMixin:Close(appName)
    local dialog = self.dialogs[appName]
    if dialog then
        dialog:Hide()
        self:TriggerEvent("OnDialogClosed", appName)
    end
end

--- Close all open dialogs
function ConfigDialogMixin:CloseAll()
    for appName, dialog in pairs(self.dialogs) do
        if dialog:IsShown() then
            dialog:Hide()
            self:TriggerEvent("OnDialogClosed", appName)
        end
    end
end

--- Navigate to specific group
-- @param appName string - App name
-- @param ... - Path components
-- @return boolean - Success
function ConfigDialogMixin:SelectGroup(appName, ...)
    local dialog = self.dialogs[appName]
    if not dialog then
        return false
    end

    local path = {...}
    self.selectedPaths[appName] = path

    -- Rebuild content for selected path
    self:RefreshContent(appName)

    self:TriggerEvent("OnGroupSelected", appName, unpack(path))
    return true
end

--- Set default dialog size
-- @param appName string - App name
-- @param width number - Width
-- @param height number - Height
function ConfigDialogMixin:SetDefaultSize(appName, width, height)
    self.defaultSizes[appName] = {width = width, height = height}
end

--- Select first available group
function ConfigDialogMixin:SelectFirstGroup(appName, options)
    if not options.args then
        self.selectedPaths[appName] = {}
        return
    end

    local registry = Config.Registry
    if not registry then return end

    local sorted = registry:GetSortedOptions(options)
    for _, item in ipairs(sorted) do
        if item.option.type == "group" and not item.option.inline then
            local info = registry:BuildInfoTable(options, item.option, appName, item.key)
            if not registry:IsHidden(item.option, info, "dialog") then
                self.selectedPaths[appName] = {item.key}
                return
            end
        end
    end

    self.selectedPaths[appName] = {}
end

--[[--------------------------------------------------------------------
    Dialog Creation
----------------------------------------------------------------------]]

--- Create the main dialog frame
-- @param appName string - App name
-- @param options table - Options table
-- @param container Frame - Parent frame (or nil)
-- @return Frame - Dialog frame
function ConfigDialogMixin:CreateDialog(appName, options, container)
    local registry = Config.Registry
    -- Get size (supports configurable dimensions)
    local width, height = GetDialogDimensions(appName, self.defaultSizes)

    -- Create main frame
    local dialog = CreateFrame("Frame", nil, container or UIParent, "BackdropTemplate")
    dialog:SetSize(width, height)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(100)

    -- Apply backdrop
    dialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })

    -- Make movable
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)

    -- Make resizable
    dialog:SetResizable(true)
    dialog:SetResizeBounds(500, 350, 1200, 900)

    local resizeGrip = CreateFrame("Button", nil, dialog)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -6, 6)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function() dialog:StartSizing("BOTTOMRIGHT") end)
    resizeGrip:SetScript("OnMouseUp", function()
        dialog:StopMovingOrSizing()
        self:RefreshContent(appName)
    end)
    dialog.resizeGrip = resizeGrip

    -- Title bar
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    local titleText = registry:ResolveValue(options.name, nil) or appName
    title:SetText(titleText)
    dialog.title = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    closeBtn:SetScript("OnClick", function()
        self:Close(appName)
    end)

    -- Content container
    local content = CreateFrame("Frame", nil, dialog)
    content:SetPoint("TOPLEFT", 16, -45)
    content:SetPoint("BOTTOMRIGHT", -16, 16)
    dialog.content = content

    -- Store references
    dialog.appName = appName
    dialog.options = options
    dialog.registry = registry

    -- Create appropriate layout based on childGroups
    local childGroups = options.childGroups or "tree"

    -- Check if ANY child group also has childGroups = "tab" (nested tabs)
    -- If so, force tree layout for better UX (nested tabs are complex and confusing)
    local hasNestedTabs = false
    if childGroups == "tab" and options.args then
        for _, opt in pairs(options.args) do
            if opt.type == "group" and opt.childGroups == "tab" then
                hasNestedTabs = true
                break
            end
        end
    end

    -- Auto-convert nested tabs to tree layout
    if hasNestedTabs then
        childGroups = "tree"
    end

    -- Create filter bar before layouts
    self:CreateFilterBar(dialog)

    if childGroups == "tree" then
        self:CreateTreeLayout(dialog)
    elseif childGroups == "tab" then
        self:CreateTabLayout(dialog)
    else
        self:CreateSimpleLayout(dialog)
    end

    -- Note: RefreshContent is called from Open() after dialog is registered and shown

    -- Listen for config changes
    registry:RegisterCallback("OnConfigTableChange", function(_, changedApp)
        if changedApp == appName or changedApp == nil then
            self:RefreshContent(appName)
        end
    end, dialog)

    return dialog
end

--[[--------------------------------------------------------------------
    Filter Bar Creation
----------------------------------------------------------------------]]

local FILTER_BAR_HEIGHT = 32
local FILTER_OPTION_TYPES = {"toggle", "input", "range", "select", "multiselect", "color", "keybinding", "execute"}

--- Create the filter bar UI
-- @param dialog Frame - The dialog frame
function ConfigDialogMixin:CreateFilterBar(dialog)
    local appName = dialog.appName
    local dialogMixin = self

    -- Filter bar container
    local filterBar = CreateFrame("Frame", nil, dialog.content)
    filterBar:SetPoint("TOPLEFT", 0, 0)
    filterBar:SetPoint("TOPRIGHT", 0, 0)
    filterBar:SetHeight(FILTER_BAR_HEIGHT)
    dialog.filterBar = filterBar

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, filterBar, "BackdropTemplate")
    searchBox:SetSize(180, 22)
    searchBox:SetPoint("LEFT", 8, 0)
    searchBox:SetFontObject("GameFontHighlight")
    searchBox:SetAutoFocus(false)
    searchBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    searchBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    searchBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    searchBox:SetTextInsets(8, 20, 0, 0)
    dialog.searchBox = searchBox

    -- Search icon
    local searchIcon = searchBox:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", 4, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetVertexColor(0.6, 0.6, 0.6)

    -- Placeholder text
    local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 24, 0)
    placeholder:SetText("Search options...")
    searchBox.placeholder = placeholder

    -- Clear search button
    local clearSearchBtn = CreateFrame("Button", nil, searchBox)
    clearSearchBtn:SetSize(16, 16)
    clearSearchBtn:SetPoint("RIGHT", -4, 0)
    clearSearchBtn:Hide()

    local clearX = clearSearchBtn:CreateTexture(nil, "ARTWORK")
    clearX:SetAllPoints()
    clearX:SetTexture("Interface\\Buttons\\UI-StopButton")

    clearSearchBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)
    dialog.clearSearchBtn = clearSearchBtn

    -- Search box events
    searchBox:SetScript("OnTextChanged", function()
        local text = searchBox:GetText()
        clearSearchBtn:SetShown(text ~= "")
        placeholder:SetShown(text == "")

        -- Cancel previous timer
        if dialogMixin.searchTimers[appName] then
            dialogMixin.searchTimers[appName]:Cancel()
        end

        -- Debounce search
        dialogMixin.searchTimers[appName] = C_Timer.NewTimer(0.2, function()
            local filterState = dialogMixin:GetFilterState(appName)
            filterState.searchText = text
            dialogMixin:UpdateFilterUI(appName)
            dialogMixin:RefreshContent(appName)
        end)
    end)

    searchBox:SetScript("OnEscapePressed", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)

    searchBox:SetScript("OnEnterPressed", function()
        searchBox:ClearFocus()
    end)

    -- Type filter dropdown button
    local typeFilterBtn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
    typeFilterBtn:SetSize(100, 22)
    typeFilterBtn:SetPoint("LEFT", searchBox, "RIGHT", 12, 0)
    typeFilterBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    typeFilterBtn:SetBackdropColor(0.15, 0.15, 0.2, 1)
    typeFilterBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    dialog.typeFilterBtn = typeFilterBtn

    local typeFilterText = typeFilterBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    typeFilterText:SetPoint("LEFT", 8, 0)
    typeFilterText:SetText("All Types")
    dialog.typeFilterText = typeFilterText

    local arrow = typeFilterBtn:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("RIGHT", -5, 0)
    arrow:SetSize(10, 10)
    arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")

    -- Highlight
    local highlight = typeFilterBtn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.3, 0.3, 0.5, 0.3)

    typeFilterBtn:SetScript("OnClick", function()
        dialogMixin:ShowTypeFilterMenu(dialog)
    end)

    -- Clear all filters button
    local clearFiltersBtn = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    clearFiltersBtn:SetSize(50, 22)
    clearFiltersBtn:SetPoint("RIGHT", -8, 0)
    clearFiltersBtn:SetText("Clear")
    clearFiltersBtn:Hide()
    clearFiltersBtn:SetScript("OnClick", function()
        dialogMixin:ClearAllFilters(appName)
    end)
    dialog.clearFiltersBtn = clearFiltersBtn
end

--- Show the type filter dropdown menu
-- @param dialog Frame - The dialog frame
function ConfigDialogMixin:ShowTypeFilterMenu(dialog)
    local appName = dialog.appName
    local filterState = self:GetFilterState(appName)
    local typeFilters = filterState.typeFilters
    local dialogMixin = self

    -- Close existing menu if any
    if dialog.typeFilterMenu then
        dialog.typeFilterMenu:Hide()
    end

    local menu = CreateFrame("Frame", nil, dialog.typeFilterBtn, "BackdropTemplate")
    menu:SetFrameStrata("TOOLTIP")
    menu:SetPoint("TOPLEFT", dialog.typeFilterBtn, "BOTTOMLEFT", 0, -2)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    menu:SetBackdropColor(0.1, 0.1, 0.15, 1)
    menu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    dialog.typeFilterMenu = menu

    local yOffset = -6
    local menuWidth = 140

    for _, optType in ipairs(FILTER_OPTION_TYPES) do
        local item = CreateFrame("CheckButton", nil, menu, "UICheckButtonTemplate")
        item:SetSize(20, 20)
        item:SetPoint("TOPLEFT", 6, yOffset)

        -- Default to checked (showing all types)
        local isEnabled = typeFilters[optType] ~= false
        item:SetChecked(isEnabled)

        local label = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", item, "RIGHT", 4, 0)
        -- Capitalize first letter
        label:SetText(optType:sub(1,1):upper() .. optType:sub(2))

        local itemType = optType
        item:SetScript("OnClick", function()
            if item:GetChecked() then
                typeFilters[itemType] = nil  -- Show this type
            else
                typeFilters[itemType] = false  -- Hide this type
            end
            dialogMixin:UpdateFilterUI(appName)
            dialogMixin:RefreshContent(appName)
        end)

        yOffset = yOffset - 22
    end

    menu:SetSize(menuWidth, math.abs(yOffset) + 6)
    menu:Show()

    -- ESC key handling
    menu:EnableKeyboard(true)
    menu:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            menu:Hide()
        else
            if not InCombatLockdown() then
                menu:SetPropagateKeyboardInput(true)
            end
        end
    end)

    -- Close on click outside
    menu:SetScript("OnUpdate", function()
        if not MouseIsOver(menu) and not MouseIsOver(dialog.typeFilterBtn) then
            if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                menu:Hide()
            end
        end
    end)
end

--[[--------------------------------------------------------------------
    Layout Creation
----------------------------------------------------------------------]]

--- Create tree layout (left tree + right content)
function ConfigDialogMixin:CreateTreeLayout(dialog)
    local content = dialog.content

    -- Tree container (left side) - offset by filter bar height
    local treeContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    treeContainer:SetPoint("TOPLEFT", 0, -FILTER_BAR_HEIGHT)
    treeContainer:SetPoint("BOTTOMLEFT", 0, 0)
    treeContainer:SetWidth(TREE_WIDTH)
    treeContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    treeContainer:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    treeContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Tree scroll frame
    local treeScroll = CreateFrame("ScrollFrame", nil, treeContainer, "UIPanelScrollFrameTemplate")
    treeScroll:SetPoint("TOPLEFT", 5, -5)
    treeScroll:SetPoint("BOTTOMRIGHT", -25, 5)

    local treeContent = CreateFrame("Frame", nil, treeScroll)
    treeContent:SetSize(TREE_WIDTH - 30, 1)
    treeScroll:SetScrollChild(treeContent)

    dialog.treeContainer = treeContainer
    dialog.treeScroll = treeScroll
    dialog.treeContent = treeContent

    -- Options container (right side)
    local optionsContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    optionsContainer:SetPoint("TOPLEFT", treeContainer, "TOPRIGHT", 8, 0)
    optionsContainer:SetPoint("BOTTOMRIGHT", 0, 0)
    optionsContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    optionsContainer:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
    optionsContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Options scroll frame
    local optionsScroll = CreateFrame("ScrollFrame", nil, optionsContainer, "UIPanelScrollFrameTemplate")
    optionsScroll:SetPoint("TOPLEFT", 5, -5)
    optionsScroll:SetPoint("BOTTOMRIGHT", -25, 5)

    local optionsContent = CreateFrame("Frame", nil, optionsScroll)
    optionsContent:SetSize(1, 1)
    optionsScroll:SetScrollChild(optionsContent)

    dialog.optionsContainer = optionsContainer
    dialog.optionsScroll = optionsScroll
    dialog.optionsContent = optionsContent

    dialog.layoutType = "tree"
end

--- Create tab layout
function ConfigDialogMixin:CreateTabLayout(dialog)
    local content = dialog.content

    -- Hide filter bar in tab layout (tabs replace navigation, filter is clutter)
    if dialog.filterBar then
        dialog.filterBar:Hide()
    end

    -- Tab bar at the very top (no filter bar offset needed)
    local tabBar = CreateFrame("Frame", nil, content)
    tabBar:SetPoint("TOPLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", 0, 0)
    tabBar:SetHeight(32)
    dialog.tabBar = tabBar

    -- Options container
    local optionsContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    optionsContainer:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -4)
    optionsContainer:SetPoint("BOTTOMRIGHT", 0, 0)
    optionsContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    optionsContainer:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
    optionsContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Options scroll frame
    local optionsScroll = CreateFrame("ScrollFrame", nil, optionsContainer, "UIPanelScrollFrameTemplate")
    optionsScroll:SetPoint("TOPLEFT", 5, -5)
    optionsScroll:SetPoint("BOTTOMRIGHT", -25, 5)

    local optionsContent = CreateFrame("Frame", nil, optionsScroll)
    optionsContent:SetSize(1, 1)
    optionsScroll:SetScrollChild(optionsContent)

    dialog.optionsContainer = optionsContainer
    dialog.optionsScroll = optionsScroll
    dialog.optionsContent = optionsContent

    dialog.layoutType = "tab"
end

--- Create simple layout (no navigation)
function ConfigDialogMixin:CreateSimpleLayout(dialog)
    local content = dialog.content

    -- Options container fills entire content (offset by filter bar)
    local optionsContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    optionsContainer:SetPoint("TOPLEFT", 0, -FILTER_BAR_HEIGHT)
    optionsContainer:SetPoint("BOTTOMRIGHT", 0, 0)
    optionsContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    optionsContainer:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
    optionsContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Options scroll frame
    local optionsScroll = CreateFrame("ScrollFrame", nil, optionsContainer, "UIPanelScrollFrameTemplate")
    optionsScroll:SetPoint("TOPLEFT", 5, -5)
    optionsScroll:SetPoint("BOTTOMRIGHT", -25, 5)

    local optionsContent = CreateFrame("Frame", nil, optionsScroll)
    optionsContent:SetSize(1, 1)
    optionsScroll:SetScrollChild(optionsContent)

    dialog.optionsContainer = optionsContainer
    dialog.optionsScroll = optionsScroll
    dialog.optionsContent = optionsContent

    dialog.layoutType = "simple"
end

--[[--------------------------------------------------------------------
    Content Rendering
----------------------------------------------------------------------]]

--- Refresh dialog content
-- @param appName string - App name
function ConfigDialogMixin:RefreshContent(appName)
    local dialog = self.dialogs[appName]
    if not dialog or not dialog:IsShown() then
        return
    end

    local options = dialog.options
    local registry = dialog.registry

    -- Rebuild tree/tabs if needed
    if dialog.layoutType == "tree" then
        self:RenderTree(dialog, options, registry)
    elseif dialog.layoutType == "tab" then
        self:RenderTabs(dialog, options, registry)
    end

    -- Get current group
    local path = self.selectedPaths[appName] or {}
    local group = options
    for _, key in ipairs(path) do
        if group.args and group.args[key] then
            group = group.args[key]
        end
    end

    -- Render options
    self:RenderOptions(dialog, group, options, registry, path)
end

--- Render tree navigation
function ConfigDialogMixin:RenderTree(dialog, options, registry)
    local treeContent = dialog.treeContent
    if not treeContent then return end

    -- Clear existing tree items
    for _, child in ipairs({treeContent:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local yOffset = 0
    local appName = dialog.appName
    local selectedPath = self.selectedPaths[appName] or {}
    local filterState = self:GetFilterState(appName)
    local hasActiveFilters = self:HasActiveFilters(appName)
    local dialogMixin = self

    -- Render tree items recursively
    local function RenderTreeGroup(group, path, indent)
        if not group.args then return end

        local sorted = registry:GetSortedOptions(group)

        for _, item in ipairs(sorted) do
            local opt = item.option
            if opt.type == "group" and not opt.inline then
                local currentPath = {}
                for _, p in ipairs(path) do currentPath[#currentPath + 1] = p end
                currentPath[#currentPath + 1] = item.key

                local info = registry:BuildInfoTable(options, opt, appName, unpack(currentPath))

                -- Check if hidden by config
                local isHidden = registry:IsHidden(opt, info, "dialog")

                -- When filters active, also check if group has any visible children
                if not isHidden and hasActiveFilters then
                    isHidden = not dialogMixin:HasVisibleChildren(opt, options, registry, currentPath, filterState, appName)
                end

                if not isHidden then
                    local name = registry:ResolveValue(opt.name, info) or item.key
                    local isSelected = self:PathEquals(selectedPath, currentPath)

                    -- Create tree button
                    local btn = CreateFrame("Button", nil, treeContent)
                    btn:SetSize(TREE_WIDTH - 35, 24)
                    btn:SetPoint("TOPLEFT", indent * 12, yOffset)

                    -- Highlight
                    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
                    highlight:SetAllPoints()
                    highlight:SetColorTexture(0.3, 0.4, 0.6, 0.4)

                    -- Selection indicator
                    if isSelected then
                        local selected = btn:CreateTexture(nil, "BACKGROUND")
                        selected:SetAllPoints()
                        selected:SetColorTexture(0.15, 0.35, 0.55, 0.9)
                    end

                    -- Icon (if provided)
                    -- Validate icon path and coordinates before rendering
                    local icon
                    if opt.icon and type(opt.icon) == "string" and opt.icon ~= "" then
                        icon = btn:CreateTexture(nil, "ARTWORK")
                        icon:SetSize(16, 16)
                        icon:SetPoint("LEFT", 4, 0)
                        icon:SetTexture(opt.icon)

                        -- Apply iconCoords if valid (must be table with 4 numeric values)
                        if opt.iconCoords and type(opt.iconCoords) == "table" and #opt.iconCoords == 4 then
                            local coords = opt.iconCoords
                            -- Validate that all coords are numbers
                            if type(coords[1]) == "number" and type(coords[2]) == "number" and
                               type(coords[3]) == "number" and type(coords[4]) == "number" then
                                icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                            end
                        end

                        -- Note: If texture path doesn't exist, WoW will show a question mark (expected behavior)
                    end

                    -- Text (always position consistently - icon visibility handled by texture load)
                    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    -- Always position text based on whether icon element exists
                    if icon then
                        text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
                    else
                        text:SetPoint("LEFT", 4, 0)
                    end
                    text:SetText(name)
                    if isSelected then
                        text:SetTextColor(1, 1, 0)
                    end

                    -- Click handler
                    btn:SetScript("OnClick", function()
                        self:SelectGroup(appName, unpack(currentPath))
                    end)

                    yOffset = yOffset - 24

                    -- Render children
                    RenderTreeGroup(opt, currentPath, indent + 1)
                end
            end
        end
    end

    RenderTreeGroup(options, {}, 0)

    -- Update scroll child height
    treeContent:SetHeight(math.abs(yOffset) + 10)
end

--- Render tab navigation
function ConfigDialogMixin:RenderTabs(dialog, options, registry)
    local tabBar = dialog.tabBar
    if not tabBar then return end

    -- Clear existing tabs
    for _, child in ipairs({tabBar:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Tab layout constants
    local TAB_PADDING = 20      -- Horizontal padding inside tab (10 each side)
    local TAB_SPACING = 4       -- Space between tabs
    local TAB_HEIGHT = 28
    local TAB_MIN_WIDTH = 60    -- Minimum tab width
    local TAB_MAX_WIDTH = 180   -- Maximum tab width (prevent overflow)
    local ICON_SIZE = 20
    local ICON_SPACING = 4

    local xOffset = 0
    local appName = dialog.appName
    local selectedPath = self.selectedPaths[appName] or {}
    local filterState = self:GetFilterState(appName)
    local hasActiveFilters = self:HasActiveFilters(appName)

    if not options.args then return end

    local sorted = registry:GetSortedOptions(options)

    for _, item in ipairs(sorted) do
        local opt = item.option
        if opt.type == "group" and not opt.inline then
            local currentPath = {item.key}
            local info = registry:BuildInfoTable(options, opt, appName, item.key)

            -- Check if hidden by config
            local isHidden = registry:IsHidden(opt, info, "dialog")

            -- When filters active, also check if tab has any visible children
            if not isHidden and hasActiveFilters then
                isHidden = not self:HasVisibleChildren(opt, options, registry, currentPath, filterState, appName)
            end

            if not isHidden then
                local name = registry:ResolveValue(opt.name, info) or item.key
                local isSelected = selectedPath[1] == item.key

                -- Create tab button
                local tab = CreateFrame("Button", nil, tabBar)

                -- Calculate dynamic tab width based on text
                local tempText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                tempText:SetText(name)
                local textWidth = tempText:GetStringWidth()
                tempText:Hide()
                tempText:SetParent(nil)  -- Clean up temp text

                -- Check if icon will be used
                local hasIcon = opt.icon and type(opt.icon) == "string" and opt.icon ~= ""
                local iconWidth = hasIcon and (ICON_SIZE + ICON_SPACING) or 0

                -- Calculate final tab width with bounds
                local tabWidth = textWidth + iconWidth + TAB_PADDING
                tabWidth = math.max(TAB_MIN_WIDTH, tabWidth)
                tabWidth = math.min(TAB_MAX_WIDTH, tabWidth)

                tab:SetSize(tabWidth, TAB_HEIGHT)
                tab:SetPoint("BOTTOMLEFT", xOffset, 0)

                -- Background
                local bg = tab:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                if isSelected then
                    bg:SetColorTexture(0.12, 0.25, 0.45, 1)
                else
                    bg:SetColorTexture(0.1, 0.1, 0.14, 1)
                end

                -- Gold bottom border on active tab
                if isSelected then
                    local activeLine = tab:CreateTexture(nil, "OVERLAY")
                    activeLine:SetPoint("BOTTOMLEFT", 0, 0)
                    activeLine:SetPoint("BOTTOMRIGHT", 0, 0)
                    activeLine:SetHeight(2)
                    activeLine:SetColorTexture(1, 0.82, 0, 1)
                end

                -- Highlight
                local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints()
                highlight:SetColorTexture(0.3, 0.4, 0.6, 0.4)

                -- Icon (if provided)
                -- Validate icon path and coordinates before rendering
                local icon
                if hasIcon then
                    icon = tab:CreateTexture(nil, "ARTWORK")
                    icon:SetSize(ICON_SIZE, ICON_SIZE)
                    icon:SetTexture(opt.icon)

                    -- Apply iconCoords if valid (must be table with 4 numeric values)
                    if opt.iconCoords and type(opt.iconCoords) == "table" and #opt.iconCoords == 4 then
                        local coords = opt.iconCoords
                        -- Validate that all coords are numbers
                        if type(coords[1]) == "number" and type(coords[2]) == "number" and
                           type(coords[3]) == "number" and type(coords[4]) == "number" then
                            icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                        end
                    end

                    -- Note: If texture path doesn't exist, WoW will show a question mark (expected behavior)
                end

                -- Text
                local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")

                -- Position text based on whether we have an icon
                if icon then
                    -- Icon on left, text on right
                    icon:SetPoint("LEFT", 8, 0)
                    text:SetPoint("LEFT", icon, "RIGHT", ICON_SPACING, 0)
                    text:SetPoint("RIGHT", -8, 0)  -- Constrain right side
                else
                    -- Text centered with padding
                    text:SetPoint("LEFT", 10, 0)
                    text:SetPoint("RIGHT", -10, 0)
                end
                text:SetText(name)
                text:SetJustifyH("CENTER")
                if isSelected then
                    text:SetTextColor(1, 1, 1, 1)
                else
                    text:SetTextColor(0.7, 0.7, 0.7, 1)
                end

                -- Truncate long text with ellipsis
                text:SetWordWrap(false)

                -- Click handler
                tab:SetScript("OnClick", function()
                    self:SelectGroup(appName, unpack(currentPath))
                end)

                -- Use dynamic width for offset calculation
                xOffset = xOffset + tabWidth + TAB_SPACING
            end
        end
    end
end

--- Check if two paths are equal
function ConfigDialogMixin:PathEquals(path1, path2)
    if #path1 ~= #path2 then return false end
    for i, v in ipairs(path1) do
        if v ~= path2[i] then return false end
    end
    return true
end

--[[--------------------------------------------------------------------
    Options Rendering
----------------------------------------------------------------------]]

--- Render options for a group
function ConfigDialogMixin:RenderOptions(dialog, group, rootOptions, registry, path)
    local optionsContent = dialog.optionsContent
    if not optionsContent then return end

    -- Release existing widgets
    self:ReleaseWidgets(optionsContent)

    if not group.args then return end

    local appName = dialog.appName
    local yOffset = -CONTENT_PADDING
    local filterState = self:GetFilterState(appName)
    local hasActiveFilters = self:HasActiveFilters(appName)

    -- Calculate actual available content width
    -- Container width minus scrollbar (25px) minus insets (5px left + 5px right)
    local containerWidth = dialog.optionsContainer:GetWidth()
    local SCROLLBAR_WIDTH = 25
    local CONTENT_INSETS = 10
    local contentWidth = containerWidth - SCROLLBAR_WIDTH - CONTENT_INSETS
    -- Ensure minimum usable width
    contentWidth = math.max(contentWidth, 300)

    -- Group header
    local groupInfo = registry:BuildInfoTable(rootOptions, group, appName, unpack(path))
    local groupName = registry:ResolveValue(group.name, groupInfo)
    if groupName and #path > 0 then
        local header = optionsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", CONTENT_PADDING, yOffset)
        header:SetText(groupName)
        header:SetTextColor(1, 0.82, 0)  -- Gold color for headers
        -- Measure actual header height instead of hardcoding
        local headerHeight = header:GetStringHeight()
        yOffset = yOffset - headerHeight - 12  -- Header height + spacing below
    end

    -- Group description
    local groupDesc = registry:ResolveValue(group.desc, groupInfo)
    if groupDesc then
        local desc = optionsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        desc:SetPoint("TOPLEFT", CONTENT_PADDING, yOffset)
        desc:SetWidth(contentWidth - CONTENT_PADDING * 2)
        desc:SetJustifyH("LEFT")
        desc:SetText(groupDesc)
        desc:SetTextColor(0.8, 0.8, 0.8)
        yOffset = yOffset - desc:GetHeight() - 16
    end

    -- Track if any options were rendered
    local optionsRendered = 0

    -- Render each option
    local sorted = registry:GetSortedOptions(group)
    local numColumns = group.columns or 1

    if numColumns > 1 then
        local innerContentWidth = contentWidth - CONTENT_PADDING * 2
        local colWidth = innerContentWidth / numColumns
        local col = 0
        local rowStartOffset = yOffset
        local rowMaxHeight = 0

        for _, item in ipairs(sorted) do
            local opt = item.option
            local currentPath = {}
            for _, p in ipairs(path) do currentPath[#currentPath + 1] = p end
            currentPath[#currentPath + 1] = item.key

            local info = registry:BuildInfoTable(rootOptions, opt, appName, unpack(currentPath))
            local optType = opt.type

            if optType == "group" and opt.inline then
                local showInlineGroup = not registry:IsHidden(opt, info, "dialog")
                if showInlineGroup and hasActiveFilters then
                    showInlineGroup = self:HasVisibleChildren(opt, rootOptions, registry, currentPath, filterState, appName)
                end
                if showInlineGroup then
                    if rowMaxHeight > 0 then
                        yOffset = rowStartOffset - rowMaxHeight - WIDGET_SPACING
                        rowStartOffset = yOffset
                        col = 0
                        rowMaxHeight = 0
                    end

                    yOffset = self:RenderInlineGroup(optionsContent, opt, rootOptions, registry, currentPath, yOffset, contentWidth, appName)
                    rowStartOffset = yOffset
                    optionsRendered = optionsRendered + 1
                end
            elseif optType ~= "group" and self:ShouldShowOption(opt, info, filterState, registry) then
                local widthMod = WIDTH_MULTIPLIERS[opt.width] or WIDTH_MULTIPLIERS.normal
                if opt.width == "full" then widthMod = 1.0 end
                local colSpan = math.max(1, math.min(numColumns, math.floor(widthMod * numColumns + 0.5)))

                if col + colSpan > numColumns then
                    yOffset = rowStartOffset - rowMaxHeight - WIDGET_SPACING
                    rowStartOffset = yOffset
                    col = 0
                    rowMaxHeight = 0
                end

                local cellX = CONTENT_PADDING + col * colWidth
                local cellWidth = colSpan * colWidth
                local cell = CreateFrame("Frame", nil, optionsContent)
                cell:SetPoint("TOPLEFT", cellX, rowStartOffset)
                cell:SetSize(cellWidth, 1)

                local newY = self:RenderWidget(cell, opt, registry, info, 0, cellWidth)
                local widgetH = math.abs(newY)
                cell:SetHeight(widgetH)

                rowMaxHeight = math.max(rowMaxHeight, widgetH)
                col = col + colSpan
                optionsRendered = optionsRendered + 1

                if col >= numColumns then
                    yOffset = rowStartOffset - rowMaxHeight - WIDGET_SPACING
                    rowStartOffset = yOffset
                    col = 0
                    rowMaxHeight = 0
                end
            end
        end

        if rowMaxHeight > 0 then
            yOffset = rowStartOffset - rowMaxHeight
        end
    else
        for _, item in ipairs(sorted) do
            local opt = item.option
            local currentPath = {}
            for _, p in ipairs(path) do currentPath[#currentPath + 1] = p end
            currentPath[#currentPath + 1] = item.key

            local info = registry:BuildInfoTable(rootOptions, opt, appName, unpack(currentPath))

            local optType = opt.type

            -- Handle inline groups
            if optType == "group" and opt.inline then
                -- Check if inline group has any visible children
                local showInlineGroup = not registry:IsHidden(opt, info, "dialog")
                if showInlineGroup and hasActiveFilters then
                    showInlineGroup = self:HasVisibleChildren(opt, rootOptions, registry, currentPath, filterState, appName)
                end
                if showInlineGroup then
                    yOffset = self:RenderInlineGroup(optionsContent, opt, rootOptions, registry, currentPath, yOffset, contentWidth, appName)
                    optionsRendered = optionsRendered + 1
                end
            elseif optType ~= "group" then
                -- Use filter predicate for non-group options
                if self:ShouldShowOption(opt, info, filterState, registry) then
                    yOffset = self:RenderWidget(optionsContent, opt, registry, info, yOffset, contentWidth)
                    optionsRendered = optionsRendered + 1
                end
            end
        end
    end

    -- Show "no results" message if filters are active and nothing matched
    if hasActiveFilters and optionsRendered == 0 then
        local noResults = optionsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noResults:SetPoint("TOPLEFT", CONTENT_PADDING, yOffset)
        noResults:SetText("No options match the current filters.")
        noResults:SetTextColor(0.6, 0.6, 0.6)
        yOffset = yOffset - 24
    end

    -- Update scroll child height
    optionsContent:SetHeight(math.abs(yOffset) + CONTENT_PADDING)
    optionsContent:SetWidth(contentWidth)
end

--- Render an inline group
function ConfigDialogMixin:RenderInlineGroup(parent, group, rootOptions, registry, path, yOffset, contentWidth, appName)
    local info = registry:BuildInfoTable(rootOptions, group, appName, unpack(path))
    local groupName = registry:ResolveValue(group.name, info)
    local filterState = self:GetFilterState(appName)

    -- Group frame
    local groupFrame = self:AcquireWidget("group_frame", parent, "BackdropTemplate")
    groupFrame:SetPoint("TOPLEFT", CONTENT_PADDING, yOffset)
    groupFrame:SetWidth(contentWidth - CONTENT_PADDING * 2)
    groupFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    groupFrame:SetBackdropColor(0.08, 0.08, 0.1, 0.7)
    groupFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)

    local innerOffset = -8

    -- Group title
    if groupName then
        local title = groupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 8, innerOffset)
        title:SetText("|cffffd700" .. groupName .. "|r")
        -- Measure actual title height instead of hardcoding
        local titleHeight = title:GetStringHeight()
        innerOffset = innerOffset - titleHeight - 6  -- Title height + spacing
    end

    -- Render group options (with optional multi-column flow)
    if group.args then
        local sorted = registry:GetSortedOptions(group)
        local numColumns = group.columns or 1
        local groupFrameWidth = contentWidth - CONTENT_PADDING * 2
        local innerContentWidth = groupFrameWidth - 16  -- 8px insets each side

        if numColumns > 1 then
            -- Multi-column flow layout
            local colWidth = innerContentWidth / numColumns
            local col = 0
            local rowStartOffset = innerOffset
            local rowMaxHeight = 0

            for _, item in ipairs(sorted) do
                local opt = item.option
                local currentPath = {}
                for _, p in ipairs(path) do currentPath[#currentPath + 1] = p end
                currentPath[#currentPath + 1] = item.key

                local optInfo = registry:BuildInfoTable(rootOptions, opt, appName, unpack(currentPath))

                if opt.type ~= "group" and self:ShouldShowOption(opt, optInfo, filterState, registry) then
                    -- Calculate column span for this widget
                    local widthMod = WIDTH_MULTIPLIERS[opt.width] or WIDTH_MULTIPLIERS.normal
                    if opt.width == "full" then widthMod = 1.0 end
                    local colSpan = math.max(1, math.min(numColumns, math.floor(widthMod * numColumns + 0.5)))

                    -- Wrap to next row if this widget doesn't fit
                    if col + colSpan > numColumns then
                        innerOffset = rowStartOffset - rowMaxHeight - WIDGET_SPACING
                        rowStartOffset = innerOffset
                        col = 0
                        rowMaxHeight = 0
                    end

                    -- Create cell container positioned at correct column
                    local cellX = 8 + col * colWidth
                    local cellWidth = colSpan * colWidth

                    local cell = CreateFrame("Frame", nil, groupFrame)
                    cell:SetPoint("TOPLEFT", cellX, rowStartOffset)
                    cell:SetSize(cellWidth, 1)

                    -- Render widget into cell at y=0
                    local newY = self:RenderWidget(cell, opt, registry, optInfo, 0, cellWidth)
                    local widgetH = math.abs(newY)
                    cell:SetHeight(widgetH)

                    rowMaxHeight = math.max(rowMaxHeight, widgetH)
                    col = col + colSpan

                    -- Auto-wrap after filling a row
                    if col >= numColumns then
                        innerOffset = rowStartOffset - rowMaxHeight - WIDGET_SPACING
                        rowStartOffset = innerOffset
                        col = 0
                        rowMaxHeight = 0
                    end
                end
            end

            -- Account for the last partial row
            if rowMaxHeight > 0 then
                innerOffset = rowStartOffset - rowMaxHeight
            end
        else
            -- Single-column vertical layout (original behavior)
            for _, item in ipairs(sorted) do
                local opt = item.option
                local currentPath = {}
                for _, p in ipairs(path) do currentPath[#currentPath + 1] = p end
                currentPath[#currentPath + 1] = item.key

                local optInfo = registry:BuildInfoTable(rootOptions, opt, appName, unpack(currentPath))

                if opt.type ~= "group" and self:ShouldShowOption(opt, optInfo, filterState, registry) then
                    innerOffset = self:RenderWidget(groupFrame, opt, registry, optInfo, innerOffset, innerContentWidth)
                end
            end
        end
    end

    innerOffset = innerOffset - 8
    groupFrame:SetHeight(math.abs(innerOffset))

    return yOffset - groupFrame:GetHeight() - WIDGET_SPACING
end

--[[--------------------------------------------------------------------
    Widget Rendering
----------------------------------------------------------------------]]

--- Render a single widget
function ConfigDialogMixin:RenderWidget(parent, option, registry, info, yOffset, contentWidth)
    local optType = option.type
    local name = registry:ResolveValue(option.name, info) or info[#info]
    local desc = registry:ResolveValue(option.desc, info)
    local disabled = registry:IsDisabled(option, info)

    -- Calculate width
    local widthMod = WIDTH_MULTIPLIERS[option.width] or WIDTH_MULTIPLIERS.normal
    if option.width == "full" then
        widthMod = contentWidth / LABEL_WIDTH
    elseif type(option.width) == "number" then
        widthMod = option.width
    end

    local widgetHeight = 24

    if optType == "header" then
        return self:RenderHeader(parent, name, yOffset, contentWidth)
    elseif optType == "description" then
        return self:RenderDescription(parent, option, name, yOffset, contentWidth)
    elseif optType == "toggle" then
        return self:RenderToggle(parent, option, name, desc, registry, info, disabled, yOffset)
    elseif optType == "input" then
        return self:RenderInput(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    elseif optType == "range" then
        return self:RenderRange(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    elseif optType == "select" then
        return self:RenderSelect(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    elseif optType == "multiselect" then
        return self:RenderMultiSelect(parent, option, name, registry, info, disabled, yOffset, contentWidth)
    elseif optType == "color" then
        return self:RenderColor(parent, option, name, desc, registry, info, disabled, yOffset)
    elseif optType == "execute" then
        return self:RenderExecute(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    elseif optType == "keybinding" then
        return self:RenderKeybinding(parent, option, name, desc, registry, info, disabled, yOffset)
    elseif optType == "texture" then
        return self:RenderTexture(parent, option, name, desc, registry, info, disabled, yOffset)
    elseif optType == "font" then
        return self:RenderFont(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    end

    return yOffset - widgetHeight - WIDGET_SPACING
end

--- Render header
function ConfigDialogMixin:RenderHeader(parent, name, yOffset, contentWidth)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 8, yOffset - 8)
    header:SetText(name)
    header:SetTextColor(1, 0.82, 0)

    -- Line under header
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 8, yOffset - 28)
    line:SetSize(contentWidth - 16, 1)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    return yOffset - 36
end

--- Render description
function ConfigDialogMixin:RenderDescription(parent, option, name, yOffset, contentWidth)
    local fontSize = option.fontSize or "medium"
    local fontObject = ConfigTypes.fontSizes[fontSize] or "GameFontNormal"

    -- Render image if provided
    if option.image and type(option.image) == "string" and option.image ~= "" then
        local imgWidth = option.imageWidth or 64
        local imgHeight = option.imageHeight or 32
        local img = parent:CreateTexture(nil, "ARTWORK")
        img:SetPoint("TOPLEFT", 8, yOffset)
        img:SetSize(imgWidth, imgHeight)
        img:SetTexture(option.image)
        if option.imageCoords and type(option.imageCoords) == "table" and #option.imageCoords == 4 then
            local c = option.imageCoords
            if type(c[1]) == "number" then
                img:SetTexCoord(c[1], c[2], c[3], c[4])
            end
        end
        yOffset = yOffset - imgHeight - WIDGET_SPACING
    end

    -- Only render text if name is non-empty
    if name and name ~= "" then
        local text = parent:CreateFontString(nil, "OVERLAY", fontObject)
        text:SetPoint("TOPLEFT", 8, yOffset)
        text:SetWidth(contentWidth - 16)
        text:SetJustifyH("LEFT")
        text:SetText(name)
        text:SetTextColor(0.9, 0.9, 0.9)

        yOffset = yOffset - text:GetHeight() - WIDGET_SPACING
    end

    return yOffset
end

--- Render toggle (checkbox)
function ConfigDialogMixin:RenderToggle(parent, option, name, desc, registry, info, disabled, yOffset)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 8, yOffset + 4)
    check:SetSize(24, 24)

    -- Set current value
    local value = registry:GetValue(option, info)
    check:SetChecked(value == true)

    -- Label
    local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(name)
    local parentWidth = parent:GetWidth()
    if parentWidth and parentWidth > 44 then
        label:SetWidth(parentWidth - 44)  -- 8 left pad + 24 check + 4 gap + 8 right pad
    end

    if disabled then
        label:SetTextColor(0.5, 0.5, 0.5)
        check:Disable()
    end

    -- Tooltip
    if desc then
        check:SetScript("OnEnter", function(widget)
            GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function()
            if GameTooltip_Hide then
                GameTooltip_Hide()
            else
                GameTooltip:Hide()
            end
        end)
    end

    -- Handler
    check:SetScript("OnClick", function()
        local newValue = check:GetChecked()
        registry:SetValue(option, info, newValue)
    end)

    return yOffset - 28
end

--- Render input (editbox)
-- option.multiline: false/nil = single-line, true = 4-line scrollable,
--                   number = that many lines scrollable.
function ConfigDialogMixin:RenderInput(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    local isMultiline = option.multiline and true or false
    local lineCount = type(option.multiline) == "number" and option.multiline or 4
    local LINE_HEIGHT = 14
    local editHeight = isMultiline and (lineCount * LINE_HEIGHT) or 20
    local containerHeight = isMultiline and (editHeight + 20) or 28
    local editWidth = LABEL_WIDTH * widthMod

    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 8, yOffset)
    container:SetSize(editWidth + LABEL_WIDTH, containerHeight)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(name)

    if disabled then
        label:SetTextColor(0.5, 0.5, 0.5)
    end

    local INPUT_BACKDROP = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    }

    local editBox

    if isMultiline then
        -- Backdrop container for the scroll area
        local bg = CreateFrame("Frame", nil, container, "BackdropTemplate")
        bg:SetPoint("TOPLEFT", LABEL_WIDTH, 0)
        bg:SetSize(editWidth, editHeight)
        bg:SetBackdrop(INPUT_BACKDROP)
        bg:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        bg:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

        -- Click anywhere in backdrop to focus the editbox
        bg:EnableMouse(true)
        bg:SetScript("OnMouseDown", function()
            editBox:SetFocus()
        end)

        -- ScrollFrame clips content and adds a vertical scrollbar
        local scrollFrame = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 5, -5)
        scrollFrame:SetPoint("BOTTOMRIGHT", -24, 5)

        editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("GameFontHighlight")
        editBox:SetWidth(editWidth - 29)
        editBox:SetTextInsets(0, 0, 0, 0)
        scrollFrame:SetScrollChild(editBox)

        if disabled then
            editBox:Disable()
            bg:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
        end
    else
        editBox = CreateFrame("EditBox", nil, container, "BackdropTemplate")
        editBox:SetPoint("TOPLEFT", LABEL_WIDTH, 0)
        editBox:SetSize(editWidth, editHeight)
        editBox:SetFontObject("GameFontHighlight")
        editBox:SetAutoFocus(false)
        editBox:SetMultiLine(false)

        editBox:SetBackdrop(INPUT_BACKDROP)
        editBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        editBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        editBox:SetTextInsets(5, 5, 3, 3)

        if disabled then
            editBox:Disable()
            editBox:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
        end

        -- Tooltip
        if desc then
            editBox:SetScript("OnEnter", function(widget)
                GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
                GameTooltip:SetText(name, 1, 1, 1)
                GameTooltip:AddLine(desc, 1, 0.82, 0, true)
                GameTooltip:Show()
            end)
            editBox:SetScript("OnLeave", function()
                if GameTooltip_Hide then
                    GameTooltip_Hide()
                else
                    GameTooltip:Hide()
                end
            end)
        end
    end

    -- Set current value
    local value = registry:GetValue(option, info)
    editBox:SetText(value or "")

    -- Handlers
    editBox:SetScript("OnEnterPressed", function()
        if not isMultiline then
            registry:SetValue(option, info, editBox:GetText())
            editBox:ClearFocus()
        end
    end)

    editBox:SetScript("OnEscapePressed", function()
        editBox:SetText(registry:GetValue(option, info) or "")
        editBox:ClearFocus()
    end)

    if isMultiline then
        editBox:SetScript("OnEditFocusLost", function()
            registry:SetValue(option, info, editBox:GetText())
        end)
        -- Sync value on every change so other widgets see updated data
        editBox:SetScript("OnTextChanged", function(_, userInput)
            if userInput then
                registry:SetValue(option, info, editBox:GetText())
            end
        end)
    end

    return yOffset - containerHeight - WIDGET_SPACING
end

--- Render range (slider)
function ConfigDialogMixin:RenderRange(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 8, yOffset)
    container:SetSize(LABEL_WIDTH * widthMod + LABEL_WIDTH + 50, 40)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(name)

    if disabled then
        label:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Slider
    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", LABEL_WIDTH, -5)
    slider:SetSize(LABEL_WIDTH * widthMod, 16)
    slider:SetOrientation("HORIZONTAL")

    local minVal = option.min or option.softMin or 0
    local maxVal = option.max or option.softMax or 100
    local step = option.step or 0

    slider:SetMinMaxValues(minVal, maxVal)
    if step > 0 then
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
    end

    -- Value display
    local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)

    local function UpdateValueText(val)
        if option.isPercent then
            valueText:SetText(string.format("%.0f%%", val * 100))
        else
            if step and step >= 1 then
                valueText:SetText(string.format("%.0f", val))
            else
                valueText:SetText(string.format("%.2f", val))
            end
        end
    end

    -- Set current value
    local value = registry:GetValue(option, info)
    slider:SetValue(value or minVal)
    UpdateValueText(value or minVal)

    if disabled then
        slider:Disable()
    end

    -- Tooltip
    if desc then
        slider:SetScript("OnEnter", function(widget)
            GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:AddLine(string.format("Range: %s - %s", minVal, maxVal), 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        slider:SetScript("OnLeave", function()
            if GameTooltip_Hide then
                GameTooltip_Hide()
            else
                GameTooltip:Hide()
            end
        end)
    end

    -- Handler
    slider:SetScript("OnValueChanged", function(_, val)
        UpdateValueText(val)
        registry:SetValue(option, info, val)
    end)

    -- Hide default labels (OptionsSliderTemplate creates named children)
    -- Since we create sliders without names, access via GetRegions() instead of global lookup
    local sliderName = slider:GetName()
    if sliderName then
        -- Named slider - use global lookup
        local lowText = _G[sliderName .. "Low"]
        local highText = _G[sliderName .. "High"]
        local labelText = _G[sliderName .. "Text"]
        if lowText then lowText:SetText("") end
        if highText then highText:SetText("") end
        if labelText then labelText:SetText("") end
    else
        -- Anonymous slider - hide all FontStrings to suppress default labels
        for _, region in ipairs({slider:GetRegions()}) do
            if region:GetObjectType() == "FontString" then
                ---@cast region FontString
                region:SetText("")
            end
        end
    end

    return yOffset - 44
end

--- Render select (dropdown)
function ConfigDialogMixin:RenderSelect(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 8, yOffset)
    container:SetSize(LABEL_WIDTH * widthMod + LABEL_WIDTH, 28)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(name)

    if disabled then
        label:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Get values
    local values = registry:ResolveValue(option.values, info) or {}
    local currentValue = registry:GetValue(option, info)

    -- Dropdown button
    local dropdown = CreateFrame("Button", nil, container, "BackdropTemplate")
    dropdown:SetPoint("TOPLEFT", LABEL_WIDTH, 2)
    dropdown:SetSize(LABEL_WIDTH * widthMod, 24)

    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    dropdown:SetBackdropColor(0.15, 0.15, 0.2, 1)
    dropdown:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- Current value text
    local valueLabel = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueLabel:SetPoint("LEFT", 8, 0)
    valueLabel:SetText(values[currentValue] or tostring(currentValue) or "")

    -- Arrow
    local arrow = dropdown:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("RIGHT", -5, 0)
    arrow:SetSize(12, 12)
    arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")

    if disabled then
        dropdown:Disable()
        dropdown:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
    end

    -- Tooltip
    if desc then
        dropdown:SetScript("OnEnter", function(widget)
            GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        dropdown:SetScript("OnLeave", function()
            if GameTooltip_Hide then
                GameTooltip_Hide()
            else
                GameTooltip:Hide()
            end
        end)
    end

    -- Click handler - show menu
    dropdown:SetScript("OnClick", function()
        local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
        menu:SetFrameStrata("TOOLTIP")
        menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)

        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3}
        })
        menu:SetBackdropColor(0.1, 0.1, 0.15, 1)
        menu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

        -- Build sorted list
        local sortedKeys = {}
        if option.sorting then
            sortedKeys = registry:ResolveValue(option.sorting, info) or {}
        end
        if #sortedKeys == 0 then
            for k in pairs(values) do
                sortedKeys[#sortedKeys + 1] = k
            end
            table.sort(sortedKeys, function(a, b)
                return tostring(a) < tostring(b)
            end)
        end

        local menuHeight = 8
        local menuWidth = dropdown:GetWidth()

        for i, key in ipairs(sortedKeys) do
            local itemLabel = values[key] or tostring(key)

            local item = CreateFrame("Button", nil, menu)
            item:SetSize(menuWidth - 6, 20)
            item:SetPoint("TOPLEFT", 3, -3 - (i - 1) * 20)

            local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            itemText:SetPoint("LEFT", 8, 0)
            itemText:SetText(itemLabel)

            if key == currentValue then
                itemText:SetTextColor(1, 1, 0)
            end

            local highlight = item:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(0.3, 0.3, 0.5, 0.5)

            item:SetScript("OnClick", function()
                registry:SetValue(option, info, key)
                valueLabel:SetText(itemLabel)
                menu:Hide()
            end)

            menuHeight = menuHeight + 20
        end

        menu:SetSize(menuWidth, menuHeight)
        menu:Show()

        -- ESC key handling
        if not InCombatLockdown() then
            menu:SetPropagateKeyboardInput(false)
        end
        menu:EnableKeyboard(true)
        menu:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then
                menu:Hide()
            else
                if not InCombatLockdown() then
                    menu:SetPropagateKeyboardInput(true)
                end
            end
        end)

        -- Close on click outside
        menu:SetScript("OnUpdate", function()
            if not MouseIsOver(menu) and not MouseIsOver(dropdown) then
                if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                    menu:Hide()
                end
            end
        end)
    end)

    return yOffset - 32
end

--- Render multiselect
function ConfigDialogMixin:RenderMultiSelect(parent, option, name, registry, info, disabled, yOffset, contentWidth)
    -- Header
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 8, yOffset)
    header:SetText(name)

    if disabled then
        header:SetTextColor(0.5, 0.5, 0.5)
    end

    yOffset = yOffset - 20

    -- Get values
    local values = registry:ResolveValue(option.values, info) or {}
    local currentValues = registry:GetValue(option, info) or {}

    -- Sort keys
    local sortedKeys = {}
    for k in pairs(values) do
        sortedKeys[#sortedKeys + 1] = k
    end
    table.sort(sortedKeys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    -- Create checkboxes
    local perRow = math.floor((contentWidth - 16) / 150)
    local col = 0

    for _, key in ipairs(sortedKeys) do
        local itemLabel = values[key] or tostring(key)
        local isChecked = currentValues[key]

        local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 8 + col * 150, yOffset + 4)
        check:SetSize(20, 20)
        check:SetChecked(isChecked == true)

        local checkLabel = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        checkLabel:SetPoint("LEFT", check, "RIGHT", 2, 0)
        checkLabel:SetText(itemLabel)

        if disabled then
            check:Disable()
            checkLabel:SetTextColor(0.5, 0.5, 0.5)
        end

        local itemKey = key
        check:SetScript("OnClick", function()
            local newValue = check:GetChecked()
            -- For multiselect, we set key, value
            registry:SetValue(option, info, itemKey, newValue)
        end)

        col = col + 1
        if col >= perRow then
            col = 0
            yOffset = yOffset - 24
        end
    end

    if col > 0 then
        yOffset = yOffset - 24
    end

    return yOffset - WIDGET_SPACING
end

--- Render color picker
function ConfigDialogMixin:RenderColor(parent, option, name, desc, registry, info, disabled, yOffset)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 8, yOffset)
    container:SetSize(LABEL_WIDTH + 80, 28)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(name)

    if disabled then
        label:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Color swatch
    local swatch = CreateFrame("Button", nil, container)
    swatch:SetPoint("TOPLEFT", LABEL_WIDTH, 2)
    swatch:SetSize(24, 24)

    local swatchBg = swatch:CreateTexture(nil, "BACKGROUND")
    swatchBg:SetAllPoints()
    swatchBg:SetColorTexture(1, 1, 1)

    local swatchColor = swatch:CreateTexture(nil, "ARTWORK")
    swatchColor:SetPoint("TOPLEFT", 2, -2)
    swatchColor:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Set current color
    local r, g, b, a = 1, 1, 1, 1
    local value = registry:GetValue(option, info)
    if type(value) == "table" then
        r = value.r or value[1] or 1
        g = value.g or value[2] or 1
        b = value.b or value[3] or 1
        a = value.a or value[4] or 1
    end
    swatchColor:SetColorTexture(r, g, b, a)

    if disabled then
        swatch:Disable()
    end

    -- Tooltip
    if desc then
        swatch:SetScript("OnEnter", function(widget)
            GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", function()
            if GameTooltip_Hide then
                GameTooltip_Hide()
            else
                GameTooltip:Hide()
            end
        end)
    end

    -- Click handler - open color picker
    swatch:SetScript("OnClick", function()
        local function OnColorChanged()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            local newA = 1
            if option.hasAlpha then
                newA = ColorPickerFrame:GetColorAlpha() or 1
            end

            swatchColor:SetColorTexture(newR, newG, newB, newA)
            registry:SetValue(option, info, newR, newG, newB, newA)
        end

        local function OnCancel(previousValues)
            local prevR, prevG, prevB, prevA = unpack(previousValues)
            swatchColor:SetColorTexture(prevR, prevG, prevB, prevA)
            registry:SetValue(option, info, prevR, prevG, prevB, prevA)
        end

        local colorInfo = {
            r = r,
            g = g,
            b = b,
            opacity = a,
            hasOpacity = option.hasAlpha,
            swatchFunc = OnColorChanged,
            opacityFunc = OnColorChanged,
            cancelFunc = function()
                OnCancel({r, g, b, a})
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(colorInfo)
    end)

    return yOffset - 32
end

--- Render execute button
function ConfigDialogMixin:RenderExecute(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", 8, yOffset + 2)
    btn:SetSize(LABEL_WIDTH * widthMod, 24)
    btn:SetText(name)

    if disabled then
        btn:Disable()
    end

    -- Tooltip
    if desc then
        btn:SetScript("OnEnter", function(widget)
            GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            if GameTooltip_Hide then
                GameTooltip_Hide()
            else
                GameTooltip:Hide()
            end
        end)
    end

    -- Click handler
    btn:SetScript("OnClick", function()
        if option.func then
            local success, err = pcall(registry.CallMethod, registry, option, info, option.func)
            if not success then
                -- Log error
                Loolib:Error("Execute error:", err)
                -- Notify user
                print("|cffff0000Error executing " .. name .. ":|r " .. tostring(err))
            elseif type(registry.NotifyChange) == "function" and info and info[1] then
                registry:NotifyChange(info[1])
            end
        end
    end)

    return yOffset - 32
end

--- Render keybinding
function ConfigDialogMixin:RenderKeybinding(parent, option, name, desc, registry, info, disabled, yOffset)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 8, yOffset)
    container:SetSize(LABEL_WIDTH + 120, 28)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(name)

    if disabled then
        label:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Keybind button
    local keyBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
    keyBtn:SetPoint("TOPLEFT", LABEL_WIDTH, 2)
    keyBtn:SetSize(100, 24)

    keyBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    keyBtn:SetBackdropColor(0.15, 0.15, 0.2, 1)
    keyBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local keyText = keyBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    keyText:SetPoint("CENTER")

    -- Set current value
    local value = registry:GetValue(option, info)
    keyText:SetText(value or "Click to bind")

    if disabled then
        keyBtn:Disable()
        keyBtn:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
    end

    -- Tooltip
    if desc then
        keyBtn:SetScript("OnEnter", function(widget)
            GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:AddLine("Click to set key binding", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        keyBtn:SetScript("OnLeave", function()
            if GameTooltip_Hide then
                GameTooltip_Hide()
            else
                GameTooltip:Hide()
            end
        end)
    end

    local isListening = false

    keyBtn:SetScript("OnClick", function()
        if isListening then
            return
        end

        isListening = true
        keyText:SetText("Press a key...")
        keyBtn:SetBackdropBorderColor(1, 1, 0, 1)

        keyBtn:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then
                -- Cancel
                local currentVal = registry:GetValue(option, info)
                keyText:SetText(currentVal or "Click to bind")
            else
                -- Build binding string
                local binding = ""
                if IsControlKeyDown() then binding = binding .. "CTRL-" end
                if IsShiftKeyDown() then binding = binding .. "SHIFT-" end
                if IsAltKeyDown() then binding = binding .. "ALT-" end
                binding = binding .. key

                keyText:SetText(binding)
                registry:SetValue(option, info, binding)
            end

            isListening = false
            keyBtn:SetScript("OnKeyDown", nil)
            keyBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end)
    end)

    return yOffset - 32
end

--- Render texture display/selector
function ConfigDialogMixin:RenderTexture(parent, option, name, desc, registry, info, disabled, yOffset)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 8, yOffset)

    local texWidth = option.imageWidth or 32
    local texHeight = option.imageHeight or 32
    container:SetSize(LABEL_WIDTH + texWidth + 8, math.max(texHeight, 24))

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(name)

    if disabled then
        label:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Texture display
    local texFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    texFrame:SetPoint("TOPLEFT", LABEL_WIDTH, 0)
    texFrame:SetSize(texWidth + 4, texHeight + 4)
    texFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    texFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    texFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local tex = texFrame:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("CENTER")
    tex:SetSize(texWidth, texHeight)

    -- Set texture
    local texturePath = option.image or registry:GetValue(option, info)
    if texturePath then
        tex:SetTexture(texturePath)
        if option.imageCoords then
            local coords = option.imageCoords
            tex:SetTexCoord(coords[1] or 0, coords[2] or 1, coords[3] or 0, coords[4] or 1)
        end
    else
        tex:SetColorTexture(0.3, 0.3, 0.3, 1)
    end

    -- Tooltip
    if desc then
        texFrame:SetScript("OnEnter", function(widget)
            GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        texFrame:SetScript("OnLeave", function()
            if GameTooltip_Hide then
                GameTooltip_Hide()
            else
                GameTooltip:Hide()
            end
        end)
    end

    -- If values provided, make it a selector
    local values = option.values and registry:ResolveValue(option.values, info)
    if values and not disabled then
        texFrame:EnableMouse(true)
        texFrame:SetScript("OnMouseDown", function()
            -- Show texture selection menu (simplified - just cycles through)
            -- A full implementation would show a dropdown or grid picker
            local sortedKeys = {}
            for k in pairs(values) do
                sortedKeys[#sortedKeys + 1] = k
            end
            table.sort(sortedKeys)

            local current = registry:GetValue(option, info)
            local nextIdx = 1
            for i, k in ipairs(sortedKeys) do
                if k == current then
                    nextIdx = (i % #sortedKeys) + 1
                    break
                end
            end

            local newValue = sortedKeys[nextIdx]
            registry:SetValue(option, info, newValue)
            tex:SetTexture(newValue)
        end)
    end

    return yOffset - container:GetHeight() - WIDGET_SPACING
end

--- Render font selector
function ConfigDialogMixin:RenderFont(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 8, yOffset)
    container:SetSize(LABEL_WIDTH * widthMod + LABEL_WIDTH, 28)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(name)

    if disabled then
        label:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Get font values
    local values = option.values and registry:ResolveValue(option.values, info)
    if not values then
        -- Default fonts if none provided
        values = {
            ["Fonts\\FRIZQT__.TTF"] = "Friz Quadrata",
            ["Fonts\\ARIALN.TTF"] = "Arial Narrow",
            ["Fonts\\MORPHEUS.TTF"] = "Morpheus",
            ["Fonts\\SKURRI.TTF"] = "Skurri",
        }

        -- Try to get fonts from LibSharedMedia if available
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        if LSM then
            local fonts = LSM:HashTable("font")
            if fonts then
                values = {}
                for fontName, fontPath in pairs(fonts) do
                    values[fontPath] = fontName
                end
            end
        end
    end

    local currentValue = registry:GetValue(option, info)

    -- Dropdown button
    local dropdown = CreateFrame("Button", nil, container, "BackdropTemplate")
    dropdown:SetPoint("TOPLEFT", LABEL_WIDTH, 2)
    dropdown:SetSize(LABEL_WIDTH * widthMod, 24)

    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    dropdown:SetBackdropColor(0.15, 0.15, 0.2, 1)
    dropdown:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- Current value text (show in the selected font if possible)
    local valueLabel = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueLabel:SetPoint("LEFT", 8, 0)
    valueLabel:SetText(values[currentValue] or "Select Font")

    -- Try to set the font preview
    if currentValue then
        local success = pcall(function()
            valueLabel:SetFont(currentValue, 12)
        end)
        if not success then
            valueLabel:SetFontObject("GameFontHighlight")
        end
    end

    -- Arrow
    local arrow = dropdown:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("RIGHT", -5, 0)
    arrow:SetSize(12, 12)
    arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")

    if disabled then
        dropdown:Disable()
        dropdown:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
    end

    -- Tooltip
    if desc then
        dropdown:SetScript("OnEnter", function(widget)
            GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        dropdown:SetScript("OnLeave", function()
            if GameTooltip_Hide then
                GameTooltip_Hide()
            else
                GameTooltip:Hide()
            end
        end)
    end

    -- Click handler - show font menu
    dropdown:SetScript("OnClick", function()
        local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
        menu:SetFrameStrata("TOOLTIP")
        menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)

        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3}
        })
        menu:SetBackdropColor(0.1, 0.1, 0.15, 1)
        menu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

        -- Build sorted list
        local sortedKeys = {}
        for k in pairs(values) do
            sortedKeys[#sortedKeys + 1] = k
        end
        table.sort(sortedKeys, function(a, b)
            return tostring(values[a]) < tostring(values[b])
        end)

        local menuHeight = 8
        local menuWidth = dropdown:GetWidth()

        for i, key in ipairs(sortedKeys) do
            local itemLabel = values[key] or tostring(key)

            local item = CreateFrame("Button", nil, menu)
            item:SetSize(menuWidth - 6, 20)
            item:SetPoint("TOPLEFT", 3, -3 - (i - 1) * 20)

            local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            itemText:SetPoint("LEFT", 8, 0)
            itemText:SetText(itemLabel)

            -- Try to show in actual font
            pcall(function()
                itemText:SetFont(key, 11)
            end)

            if key == currentValue then
                itemText:SetTextColor(1, 1, 0)
            end

            local highlight = item:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(0.3, 0.3, 0.5, 0.5)

            item:SetScript("OnClick", function()
                registry:SetValue(option, info, key)
                valueLabel:SetText(itemLabel)
                pcall(function()
                    valueLabel:SetFont(key, 12)
                end)
                menu:Hide()
            end)

            menuHeight = menuHeight + 20
        end

        -- Limit menu height
        local maxHeight = 300
        if menuHeight > maxHeight then
            -- Would need a scroll frame for many fonts
            menuHeight = maxHeight
        end

        menu:SetSize(menuWidth, menuHeight)
        menu:Show()

        -- ESC key handling
        if not InCombatLockdown() then
            menu:SetPropagateKeyboardInput(false)
        end
        menu:EnableKeyboard(true)
        menu:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then
                menu:Hide()
            else
                if not InCombatLockdown() then
                    menu:SetPropagateKeyboardInput(true)
                end
            end
        end)

        -- Close on click outside
        menu:SetScript("OnUpdate", function()
            if not MouseIsOver(menu) and not MouseIsOver(dropdown) then
                if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                    menu:Hide()
                end
            end
        end)
    end)

    return yOffset - 32
end

--[[--------------------------------------------------------------------
    Blizzard Settings Integration
----------------------------------------------------------------------]]

--- Add to Blizzard Settings panel
-- @param appName string - App name
-- @param name string - Display name in settings
-- @param parent string - Parent category name (optional)
-- @param ... - Path to group (optional)
-- @return Frame - Settings frame
function ConfigDialogMixin:AddToBlizOptions(appName, name, parent)
    local registry = Config.Registry

    if not registry then
        Loolib:Error("ConfigRegistry not available")
        return nil
    end

    local options = registry:GetOptionsTable(appName, "bliz")
    if not options then
        Loolib:Error("No options registered for: " .. appName)
        return nil
    end

    -- Create the settings panel frame
    local panel = CreateFrame("Frame", nil, UIParent)
    panel.name = name or appName

    -- Store reference to dialog mixin for use in callbacks
    local dialogInstance = self

    -- Create content when shown
    panel:SetScript("OnShow", function(panelSelf)
        if not panelSelf.initialized then
            panelSelf.initialized = true

            -- Title
            local title = panelSelf:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", 16, -16)
            title:SetText(name or appName)

            -- Description
            local desc = panelSelf:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
            desc:SetText(registry:ResolveValue(options.desc, nil) or "")

            -- Open full config button
            local openBtn = CreateFrame("Button", nil, panelSelf, "UIPanelButtonTemplate")
            openBtn:SetPoint("TOPRIGHT", -16, -16)
            openBtn:SetSize(120, 22)
            openBtn:SetText("Open Config")
            openBtn:SetScript("OnClick", function()
                SettingsPanel:Hide()
                dialogInstance:Open(appName)
            end)
        end
    end)

    -- Register with category system
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
    self.blizPanels[appName] = {panel = panel, category = category}

    return panel
end

--[[--------------------------------------------------------------------
    Factory and Singleton
----------------------------------------------------------------------]]

--- Create a new config dialog instance
-- @return table - New instance
local function CreateConfigDialog()
    local dialog = CreateFromMixins(ConfigDialogMixin)
    dialog:Init()
    return dialog
end

-- Create the singleton instance
local ConfigDialog = CreateConfigDialog()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local ConfigDialogModule = {
    Mixin = ConfigDialogMixin,
    Create = CreateConfigDialog,
    Dialog = ConfigDialog,
}

Loolib.Config.DialogMixin = ConfigDialogMixin
Loolib.Config.CreateDialog = CreateConfigDialog
Loolib.Config.Dialog = ConfigDialog

Loolib:RegisterModule("ConfigDialog", ConfigDialogModule)
-- FIX(Area3-1): Also register under dotted path so Loolib:GetModule("Config.Dialog") works
Loolib:RegisterModule("Config.Dialog", ConfigDialogModule)
