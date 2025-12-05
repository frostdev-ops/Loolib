--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ConfigDialog - GUI dialog renderer for options tables

    Renders declarative options tables into interactive UI dialogs.
    Supports tree, tab, and inline group layouts with all option types.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Constants
----------------------------------------------------------------------]]

local DIALOG_WIDTH = 700
local DIALOG_HEIGHT = 500
local TREE_WIDTH = 180
local CONTENT_PADDING = 16
local WIDGET_SPACING = 8
local LABEL_WIDTH = 200

local WIDTH_MULTIPLIERS = {
    half = 0.5,
    normal = 1.0,
    double = 2.0,
    full = 3.0,
}

--[[--------------------------------------------------------------------
    LoolibConfigDialogMixin

    Main dialog system that renders options tables as interactive UI.
----------------------------------------------------------------------]]

LoolibConfigDialogMixin = LoolibCreateFromMixins(LoolibCallbackRegistryMixin)

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
function LoolibConfigDialogMixin:Init()
    LoolibCallbackRegistryMixin.OnLoad(self)
    self:GenerateCallbackEvents(DIALOG_EVENTS)

    self.dialogs = {}          -- appName -> dialog frame
    self.blizPanels = {}       -- appName -> Blizzard settings panel
    self.defaultSizes = {}     -- appName -> {width, height}
    self.selectedPaths = {}    -- appName -> current selected path
    self.widgetPools = {}      -- Frame pools for widgets (type -> pool)
    self.regionPools = {}      -- Pools for regions (FontString, Texture)
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
function LoolibConfigDialogMixin:AcquireWidget(widgetType, parent, template, frameTypeOverride)
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
function LoolibConfigDialogMixin:ReleaseWidgets(container)
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
            child:SetScript("OnEnter", nil)
            child:SetScript("OnLeave", nil)
            child:SetScript("OnClick", nil)
            child:SetScript("OnValueChanged", nil)
            child:SetScript("OnKeyDown", nil)
            
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
function LoolibConfigDialogMixin:Open(appName, container, ...)
    local ConfigRegistry = Loolib:GetModule("ConfigRegistry")
    local registry = ConfigRegistry and ConfigRegistry.Registry

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
    self.dialogs[appName] = dialog

    -- Navigate to initial path if provided
    if select("#", ...) > 0 then
        self:SelectGroup(appName, ...)
    else
        -- Select first group
        self:SelectFirstGroup(appName, options)
    end

    dialog:Show()
    self:TriggerEvent("OnDialogOpened", appName)

    return dialog
end

--- Close dialog for specific app
-- @param appName string - The app name
function LoolibConfigDialogMixin:Close(appName)
    local dialog = self.dialogs[appName]
    if dialog then
        dialog:Hide()
        self:TriggerEvent("OnDialogClosed", appName)
    end
end

--- Close all open dialogs
function LoolibConfigDialogMixin:CloseAll()
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
function LoolibConfigDialogMixin:SelectGroup(appName, ...)
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
function LoolibConfigDialogMixin:SetDefaultSize(appName, width, height)
    self.defaultSizes[appName] = {width = width, height = height}
end

--- Select first available group
function LoolibConfigDialogMixin:SelectFirstGroup(appName, options)
    if not options.args then
        self.selectedPaths[appName] = {}
        return
    end

    local ConfigRegistry = Loolib:GetModule("ConfigRegistry")
    local registry = ConfigRegistry and ConfigRegistry.Registry
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
function LoolibConfigDialogMixin:CreateDialog(appName, options, container)
    local ConfigRegistry = Loolib:GetModule("ConfigRegistry")
    local registry = ConfigRegistry and ConfigRegistry.Registry

    -- Get size
    local size = self.defaultSizes[appName] or {}
    local width = size.width or DIALOG_WIDTH
    local height = size.height or DIALOG_HEIGHT

    -- Create main frame
    local dialog = CreateFrame("Frame", "LoolibConfigDialog_" .. appName, container or UIParent, "BackdropTemplate")
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
    if childGroups == "tree" then
        self:CreateTreeLayout(dialog)
    elseif childGroups == "tab" then
        self:CreateTabLayout(dialog)
    else
        self:CreateSimpleLayout(dialog)
    end

    -- Initial render
    self:RefreshContent(appName)

    -- Listen for config changes
    registry:RegisterCallback("OnConfigTableChange", function(_, changedApp)
        if changedApp == appName or changedApp == nil then
            self:RefreshContent(appName)
        end
    end, dialog)

    return dialog
end

--[[--------------------------------------------------------------------
    Layout Creation
----------------------------------------------------------------------]]

--- Create tree layout (left tree + right content)
function LoolibConfigDialogMixin:CreateTreeLayout(dialog)
    local content = dialog.content

    -- Tree container (left side)
    local treeContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    treeContainer:SetPoint("TOPLEFT", 0, 0)
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
function LoolibConfigDialogMixin:CreateTabLayout(dialog)
    local content = dialog.content

    -- Tab bar
    local tabBar = CreateFrame("Frame", nil, content)
    tabBar:SetPoint("TOPLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", 0, 0)
    tabBar:SetHeight(30)
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
function LoolibConfigDialogMixin:CreateSimpleLayout(dialog)
    local content = dialog.content

    -- Options container fills entire content
    local optionsContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    optionsContainer:SetAllPoints()
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
function LoolibConfigDialogMixin:RefreshContent(appName)
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
function LoolibConfigDialogMixin:RenderTree(dialog, options, registry)
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

                if not registry:IsHidden(opt, info, "dialog") then
                    local name = registry:ResolveValue(opt.name, info) or item.key
                    local isSelected = self:PathEquals(selectedPath, currentPath)

                    -- Create tree button
                    local btn = CreateFrame("Button", nil, treeContent)
                    btn:SetSize(TREE_WIDTH - 35, 20)
                    btn:SetPoint("TOPLEFT", indent * 12, yOffset)

                    -- Highlight
                    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
                    highlight:SetAllPoints()
                    highlight:SetColorTexture(0.3, 0.3, 0.5, 0.5)

                    -- Selection indicator
                    if isSelected then
                        local selected = btn:CreateTexture(nil, "BACKGROUND")
                        selected:SetAllPoints()
                        selected:SetColorTexture(0.2, 0.4, 0.6, 0.8)
                    end

                    -- Text
                    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    text:SetPoint("LEFT", 4, 0)
                    text:SetText(name)
                    if isSelected then
                        text:SetTextColor(1, 1, 0)
                    end

                    -- Click handler
                    btn:SetScript("OnClick", function()
                        self:SelectGroup(appName, unpack(currentPath))
                    end)

                    yOffset = yOffset - 22

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
function LoolibConfigDialogMixin:RenderTabs(dialog, options, registry)
    local tabBar = dialog.tabBar
    if not tabBar then return end

    -- Clear existing tabs
    for _, child in ipairs({tabBar:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local xOffset = 0
    local appName = dialog.appName
    local selectedPath = self.selectedPaths[appName] or {}

    if not options.args then return end

    local sorted = registry:GetSortedOptions(options)

    for _, item in ipairs(sorted) do
        local opt = item.option
        if opt.type == "group" and not opt.inline then
            local currentPath = {item.key}
            local info = registry:BuildInfoTable(options, opt, appName, item.key)

            if not registry:IsHidden(opt, info, "dialog") then
                local name = registry:ResolveValue(opt.name, info) or item.key
                local isSelected = selectedPath[1] == item.key

                -- Create tab button
                local tab = CreateFrame("Button", nil, tabBar)
                tab:SetSize(100, 26)
                tab:SetPoint("BOTTOMLEFT", xOffset, 0)

                -- Background
                local bg = tab:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                if isSelected then
                    bg:SetColorTexture(0.3, 0.3, 0.4, 1)
                else
                    bg:SetColorTexture(0.15, 0.15, 0.2, 1)
                end

                -- Highlight
                local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints()
                highlight:SetColorTexture(0.4, 0.4, 0.5, 0.5)

                -- Text
                local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                text:SetPoint("CENTER")
                text:SetText(name)

                -- Click handler
                tab:SetScript("OnClick", function()
                    self:SelectGroup(appName, unpack(currentPath))
                end)

                xOffset = xOffset + 104
            end
        end
    end
end

--- Check if two paths are equal
function LoolibConfigDialogMixin:PathEquals(path1, path2)
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
function LoolibConfigDialogMixin:RenderOptions(dialog, group, rootOptions, registry, path)
    local optionsContent = dialog.optionsContent
    if not optionsContent then return end

    -- Release existing widgets
    self:ReleaseWidgets(optionsContent)

    if not group.args then return end

    local appName = dialog.appName
    local yOffset = -CONTENT_PADDING
    local contentWidth = dialog.optionsContainer:GetWidth() - 50

    -- Group header
    local groupInfo = registry:BuildInfoTable(rootOptions, group, appName, unpack(path))
    local groupName = registry:ResolveValue(group.name, groupInfo)
    if groupName and #path > 0 then
        local header = optionsContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", CONTENT_PADDING, yOffset)
        header:SetText(groupName)
        yOffset = yOffset - 30
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

    -- Render each option
    local sorted = registry:GetSortedOptions(group)

    for _, item in ipairs(sorted) do
        local opt = item.option
        local currentPath = {}
        for _, p in ipairs(path) do currentPath[#currentPath + 1] = p end
        currentPath[#currentPath + 1] = item.key

        local info = registry:BuildInfoTable(rootOptions, opt, appName, unpack(currentPath))

        -- Skip hidden options
        if not registry:IsHidden(opt, info, "dialog") then
            local optType = opt.type

            -- Handle inline groups
            if optType == "group" and opt.inline then
                yOffset = self:RenderInlineGroup(optionsContent, opt, rootOptions, registry, currentPath, yOffset, contentWidth, appName)
            elseif optType ~= "group" then
                -- Render the widget
                yOffset = self:RenderWidget(optionsContent, opt, rootOptions, registry, info, yOffset, contentWidth)
            end
        end
    end

    -- Update scroll child height
    optionsContent:SetHeight(math.abs(yOffset) + CONTENT_PADDING)
    optionsContent:SetWidth(contentWidth)
end

--- Render an inline group
function LoolibConfigDialogMixin:RenderInlineGroup(parent, group, rootOptions, registry, path, yOffset, contentWidth, appName)
    local info = registry:BuildInfoTable(rootOptions, group, appName, unpack(path))
    local groupName = registry:ResolveValue(group.name, info)

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
    groupFrame:SetBackdropColor(0.15, 0.15, 0.2, 0.5)
    groupFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)

    local innerOffset = -8

    -- Group title
    if groupName then
        local title = groupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 8, innerOffset)
        title:SetText("|cffffd700" .. groupName .. "|r")
        innerOffset = innerOffset - 20
    end

    -- Render group options
    if group.args then
        local sorted = registry:GetSortedOptions(group)
        for _, item in ipairs(sorted) do
            local opt = item.option
            local currentPath = {}
            for _, p in ipairs(path) do currentPath[#currentPath + 1] = p end
            currentPath[#currentPath + 1] = item.key

            local optInfo = registry:BuildInfoTable(rootOptions, opt, appName, unpack(currentPath))

            if not registry:IsHidden(opt, optInfo, "dialog") and opt.type ~= "group" then
                innerOffset = self:RenderWidget(groupFrame, opt, rootOptions, registry, optInfo, innerOffset, contentWidth - CONTENT_PADDING * 3)
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
function LoolibConfigDialogMixin:RenderWidget(parent, option, rootOptions, registry, info, yOffset, contentWidth)
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
        return self:RenderDescription(parent, option, name, desc, yOffset, contentWidth)
    elseif optType == "toggle" then
        return self:RenderToggle(parent, option, name, desc, registry, info, disabled, yOffset)
    elseif optType == "input" then
        return self:RenderInput(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    elseif optType == "range" then
        return self:RenderRange(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    elseif optType == "select" then
        return self:RenderSelect(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    elseif optType == "multiselect" then
        return self:RenderMultiSelect(parent, option, name, desc, registry, info, disabled, yOffset, contentWidth)
    elseif optType == "color" then
        return self:RenderColor(parent, option, name, desc, registry, info, disabled, yOffset)
    elseif optType == "execute" then
        return self:RenderExecute(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    elseif optType == "keybinding" then
        return self:RenderKeybinding(parent, option, name, desc, registry, info, disabled, yOffset)
    elseif optType == "texture" then
        return self:RenderTexture(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    elseif optType == "font" then
        return self:RenderFont(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    end

    return yOffset - widgetHeight - WIDGET_SPACING
end

--- Render header
function LoolibConfigDialogMixin:RenderHeader(parent, name, yOffset, contentWidth)
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
function LoolibConfigDialogMixin:RenderDescription(parent, option, name, desc, yOffset, contentWidth)
    local fontSize = option.fontSize or "medium"
    local fontObject = LoolibConfigTypes.fontSizes[fontSize] or "GameFontNormal"

    local text = parent:CreateFontString(nil, "OVERLAY", fontObject)
    text:SetPoint("TOPLEFT", 8, yOffset)
    text:SetWidth(contentWidth - 16)
    text:SetJustifyH("LEFT")
    text:SetText(name)
    text:SetTextColor(0.9, 0.9, 0.9)

    return yOffset - text:GetHeight() - WIDGET_SPACING
end

--- Render toggle (checkbox)
function LoolibConfigDialogMixin:RenderToggle(parent, option, name, desc, registry, info, disabled, yOffset)
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

    if disabled then
        label:SetTextColor(0.5, 0.5, 0.5)
        check:Disable()
    end

    -- Tooltip
    if desc then
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", GameTooltip_Hide)
    end

    -- Handler
    check:SetScript("OnClick", function(self)
        local newValue = self:GetChecked()
        registry:SetValue(option, info, newValue)
    end)

    return yOffset - 28
end

--- Render input (editbox)
function LoolibConfigDialogMixin:RenderInput(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 8, yOffset)
    container:SetSize(LABEL_WIDTH * widthMod + LABEL_WIDTH, option.multiline and 80 or 28)

    -- Label
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(name)

    if disabled then
        label:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Edit box
    local editHeight = option.multiline and 60 or 20
    local editBox = CreateFrame("EditBox", nil, container, "BackdropTemplate")
    editBox:SetPoint("TOPLEFT", LABEL_WIDTH, 0)
    editBox:SetSize(LABEL_WIDTH * widthMod, editHeight)
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetAutoFocus(false)
    editBox:SetMultiLine(option.multiline or false)

    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    editBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    editBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    editBox:SetTextInsets(5, 5, 3, 3)

    -- Set current value
    local value = registry:GetValue(option, info)
    editBox:SetText(value or "")

    if disabled then
        editBox:Disable()
        editBox:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
    end

    -- Tooltip
    if desc then
        editBox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        editBox:SetScript("OnLeave", GameTooltip_Hide)
    end

    -- Handlers
    editBox:SetScript("OnEnterPressed", function(self)
        if not option.multiline then
            registry:SetValue(option, info, self:GetText())
            self:ClearFocus()
        end
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(registry:GetValue(option, info) or "")
        self:ClearFocus()
    end)

    if option.multiline then
        editBox:SetScript("OnEditFocusLost", function(self)
            registry:SetValue(option, info, self:GetText())
        end)
    end

    return yOffset - container:GetHeight() - WIDGET_SPACING
end

--- Render range (slider)
function LoolibConfigDialogMixin:RenderRange(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
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
        slider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:AddLine(string.format("Range: %s - %s", minVal, maxVal), 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        slider:SetScript("OnLeave", GameTooltip_Hide)
    end

    -- Handler
    slider:SetScript("OnValueChanged", function(self, val)
        UpdateValueText(val)
        registry:SetValue(option, info, val)
    end)

    -- Hide default labels
    _G[slider:GetName() .. "Low"]:SetText("")
    _G[slider:GetName() .. "High"]:SetText("")
    _G[slider:GetName() .. "Text"]:SetText("")

    return yOffset - 44
end

--- Render select (dropdown)
function LoolibConfigDialogMixin:RenderSelect(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
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
        dropdown:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        dropdown:SetScript("OnLeave", GameTooltip_Hide)
    end

    -- Click handler - show menu
    dropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("TOOLTIP")
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)

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
        local menuWidth = self:GetWidth()

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

        -- Close on click outside
        menu:SetScript("OnUpdate", function(self)
            if not MouseIsOver(self) and not MouseIsOver(dropdown) then
                if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                    self:Hide()
                end
            end
        end)
    end)

    return yOffset - 32
end

--- Render multiselect
function LoolibConfigDialogMixin:RenderMultiSelect(parent, option, name, desc, registry, info, disabled, yOffset, contentWidth)
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
        check:SetScript("OnClick", function(self)
            local newValue = self:GetChecked()
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
function LoolibConfigDialogMixin:RenderColor(parent, option, name, desc, registry, info, disabled, yOffset)
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
        swatch:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        swatch:SetScript("OnLeave", GameTooltip_Hide)
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

        -- Use modern API if available (WoW 10.0+)
        if ColorPickerFrame.SetupColorPickerAndShow then
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
        else
            -- Legacy API fallback
            local function LegacyColorCallback(restore)
                local newR, newG, newB
                if restore then
                    newR, newG, newB = unpack(restore)
                else
                    newR, newG, newB = ColorPickerFrame:GetColorRGB()
                end
                local newA = option.hasAlpha and (1 - OpacitySliderFrame:GetValue()) or 1

                swatchColor:SetColorTexture(newR, newG, newB, newA)
                registry:SetValue(option, info, newR, newG, newB, newA)
            end

            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame.hasOpacity = option.hasAlpha
            ColorPickerFrame.opacity = 1 - a
            ColorPickerFrame.previousValues = {r, g, b, a}
            ColorPickerFrame.func = LegacyColorCallback
            ColorPickerFrame.opacityFunc = LegacyColorCallback
            ColorPickerFrame.cancelFunc = LegacyColorCallback
            ColorPickerFrame:Hide()
            ColorPickerFrame:Show()
        end
    end)

    return yOffset - 32
end

--- Render execute button
function LoolibConfigDialogMixin:RenderExecute(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", 8, yOffset + 2)
    btn:SetSize(LABEL_WIDTH * widthMod, 24)
    btn:SetText(name)

    if disabled then
        btn:Disable()
    end

    -- Tooltip
    if desc then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)
    end

    -- Click handler
    btn:SetScript("OnClick", function()
        if option.func then
            local success, err = pcall(registry.CallMethod, registry, option, info, option.func)
            if not success then
                Loolib:Error("Execute error:", err)
            end
        end
    end)

    return yOffset - 32
end

--- Render keybinding
function LoolibConfigDialogMixin:RenderKeybinding(parent, option, name, desc, registry, info, disabled, yOffset)
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
        keyBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:AddLine("Click to set key binding", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        keyBtn:SetScript("OnLeave", GameTooltip_Hide)
    end

    local isListening = false

    keyBtn:SetScript("OnClick", function(self)
        if isListening then
            return
        end

        isListening = true
        keyText:SetText("Press a key...")
        self:SetBackdropBorderColor(1, 1, 0, 1)

        self:SetScript("OnKeyDown", function(self, key)
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
            self:SetScript("OnKeyDown", nil)
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end)
    end)

    return yOffset - 32
end

--- Render texture display/selector
function LoolibConfigDialogMixin:RenderTexture(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
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
        texFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        texFrame:SetScript("OnLeave", GameTooltip_Hide)
    end

    -- If values provided, make it a selector
    local values = option.values and registry:ResolveValue(option.values, info)
    if values and not disabled then
        texFrame:EnableMouse(true)
        texFrame:SetScript("OnMouseDown", function(self)
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
function LoolibConfigDialogMixin:RenderFont(parent, option, name, desc, registry, info, disabled, yOffset, widthMod)
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
        dropdown:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(name, 1, 1, 1)
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        dropdown:SetScript("OnLeave", GameTooltip_Hide)
    end

    -- Click handler - show font menu
    dropdown:SetScript("OnClick", function(self)
        local menu = CreateFrame("Frame", nil, self, "BackdropTemplate")
        menu:SetFrameStrata("TOOLTIP")
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)

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
        local menuWidth = self:GetWidth()

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

        -- Close on click outside
        menu:SetScript("OnUpdate", function(self)
            if not MouseIsOver(self) and not MouseIsOver(dropdown) then
                if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                    self:Hide()
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
function LoolibConfigDialogMixin:AddToBlizOptions(appName, name, parent, ...)
    local ConfigRegistry = Loolib:GetModule("ConfigRegistry")
    local registry = ConfigRegistry and ConfigRegistry.Registry

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
    local panel = CreateFrame("Frame", "LoolibBlizPanel_" .. appName, UIParent)
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
                -- Hide the settings panel
                if SettingsPanel then
                    SettingsPanel:Hide()
                elseif InterfaceOptionsFrame then
                    InterfaceOptionsFrame:Hide()
                end
                dialogInstance:Open(appName)
            end)
        end
    end)

    -- Register with category system
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- WoW 10.0+ Settings API
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
    else
        -- Legacy interface options
        if parent then
            panel.parent = parent
        end
        InterfaceOptions_AddCategory(panel)
        self.blizPanels[appName] = {panel = panel}
    end

    return panel
end

--[[--------------------------------------------------------------------
    Factory and Singleton
----------------------------------------------------------------------]]

--- Create a new config dialog instance
-- @return table - New instance
function CreateLoolibConfigDialog()
    local dialog = LoolibCreateFromMixins(LoolibConfigDialogMixin)
    dialog:Init()
    return dialog
end

-- Create the singleton instance
local ConfigDialog = CreateLoolibConfigDialog()

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local ConfigDialogModule = {
    Mixin = LoolibConfigDialogMixin,
    Create = CreateLoolibConfigDialog,
    Dialog = ConfigDialog,  -- Singleton instance
}

Loolib:RegisterModule("ConfigDialog", ConfigDialogModule)
