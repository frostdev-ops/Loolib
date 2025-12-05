--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    WidgetBuilder - Fluent API for widget creation

    Provides a chainable builder pattern for creating UI widgets.

    Example usage:
        local btn = UI.Widget(parent)
            :Button()
            :Size(120, 30)
            :Point("CENTER")
            :Text("Click Me")
            :OnClick(function() print("clicked!") end)
            :Build()
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    LoolibWidgetBuilderMixin

    The core builder mixin that provides the fluent API.
----------------------------------------------------------------------]]

LoolibWidgetBuilderMixin = {}

--- Initialize the widget builder
-- @param parent Frame - Parent frame for the widget
function LoolibWidgetBuilderMixin:Init(parent)
    self.parent = parent
    self.frameType = "Frame"
    self.template = nil
    self.name = nil
    self.width = nil
    self.height = nil
    self.points = {}
    self.scripts = {}
    self.mixins = {}
    self.properties = {}
    self.backdrop = nil
    self.backdropColor = nil
    self.backdropBorderColor = nil
    self.themeName = nil
    self.pooled = false
    self.resetFunc = nil
    self.children = {}
end

--[[--------------------------------------------------------------------
    Frame Type Selection
----------------------------------------------------------------------]]

--- Create a basic Frame
-- @return self - For chaining
function LoolibWidgetBuilderMixin:Frame()
    self.frameType = "Frame"
    return self
end

--- Create a Button
-- @return self
function LoolibWidgetBuilderMixin:Button()
    self.frameType = "Button"
    self.properties.normalTexture = "Interface\\Buttons\\UI-Panel-Button-Up"
    self.properties.pushedTexture = "Interface\\Buttons\\UI-Panel-Button-Down"
    self.properties.highlightTexture = "Interface\\Buttons\\UI-Panel-Button-Highlight"
    return self
end

--- Create a CheckButton
-- @return self
function LoolibWidgetBuilderMixin:CheckButton()
    self.frameType = "CheckButton"
    return self
end

--- Create an EditBox
-- @param multiLine boolean - True for multi-line edit box
-- @return self
function LoolibWidgetBuilderMixin:EditBox(multiLine)
    self.frameType = "EditBox"
    self.properties.multiLine = multiLine or false
    self.properties.autoFocus = false
    return self
end

--- Create a Slider
-- @return self
function LoolibWidgetBuilderMixin:Slider()
    self.frameType = "Slider"
    self.properties.orientation = "HORIZONTAL"
    self.properties.minValue = 0
    self.properties.maxValue = 100
    self.properties.valueStep = 1
    return self
end

--- Create a StatusBar
-- @return self
function LoolibWidgetBuilderMixin:StatusBar()
    self.frameType = "StatusBar"
    self.properties.minValue = 0
    self.properties.maxValue = 100
    return self
end

--- Create a ScrollFrame
-- @return self
function LoolibWidgetBuilderMixin:ScrollFrame()
    self.frameType = "ScrollFrame"
    return self
end

--- Create a simple Texture holder frame
-- @return self
function LoolibWidgetBuilderMixin:TextureFrame()
    self.frameType = "Frame"
    self.properties.isTextureHolder = true
    return self
end

--[[--------------------------------------------------------------------
    Size and Position
----------------------------------------------------------------------]]

--- Set the size of the widget
-- @param width number - Width in pixels
-- @param height number - Height in pixels (defaults to width if not specified)
-- @return self
function LoolibWidgetBuilderMixin:Size(width, height)
    self.width = width
    self.height = height or width
    return self
end

--- Set only the width
-- @param width number - Width in pixels
-- @return self
function LoolibWidgetBuilderMixin:Width(width)
    self.width = width
    return self
end

--- Set only the height
-- @param height number - Height in pixels
-- @return self
function LoolibWidgetBuilderMixin:Height(height)
    self.height = height
    return self
end

--- Add an anchor point
-- @param point string - Anchor point (e.g., "CENTER", "TOPLEFT")
-- @param relativeTo Frame|string - Frame or nil (parent) or string (anchor point on parent)
-- @param relativePoint string - Relative point (defaults to point)
-- @param offsetX number - X offset
-- @param offsetY number - Y offset
-- @return self
function LoolibWidgetBuilderMixin:Point(point, relativeTo, relativePoint, offsetX, offsetY)
    -- Handle simplified syntax: Point("CENTER") or Point("TOPLEFT", 10, -10)
    if type(relativeTo) == "number" then
        offsetY = relativePoint
        offsetX = relativeTo
        relativePoint = point
        relativeTo = nil
    end

    self.points[#self.points + 1] = {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint or point,
        x = offsetX or 0,
        y = offsetY or 0,
    }
    return self
end

--- Fill the parent (SetAllPoints)
-- @param inset number - Optional inset from edges
-- @return self
function LoolibWidgetBuilderMixin:AllPoints(inset)
    self.properties.fillParent = true
    self.properties.fillInset = inset
    return self
end

--- Center in parent
-- @param offsetX number - X offset from center
-- @param offsetY number - Y offset from center
-- @return self
function LoolibWidgetBuilderMixin:Center(offsetX, offsetY)
    return self:Point("CENTER", nil, "CENTER", offsetX or 0, offsetY or 0)
end

--[[--------------------------------------------------------------------
    Appearance
----------------------------------------------------------------------]]

--- Set the backdrop
-- @param backdrop table|string - Backdrop table or theme backdrop name
-- @return self
function LoolibWidgetBuilderMixin:Backdrop(backdrop)
    if type(backdrop) == "string" then
        -- It's a theme backdrop name
        self.properties.themeBackdrop = backdrop
    else
        self.backdrop = backdrop
    end
    self.template = self.template or "BackdropTemplate"
    return self
end

--- Set backdrop color
-- @param r number - Red (0-1)
-- @param g number - Green (0-1)
-- @param b number - Blue (0-1)
-- @param a number - Alpha (0-1, default 1)
-- @return self
function LoolibWidgetBuilderMixin:BackdropColor(r, g, b, a)
    self.backdropColor = {r, g, b, a or 1}
    return self
end

--- Set backdrop border color
-- @param r number - Red
-- @param g number - Green
-- @param b number - Blue
-- @param a number - Alpha
-- @return self
function LoolibWidgetBuilderMixin:BackdropBorderColor(r, g, b, a)
    self.backdropBorderColor = {r, g, b, a or 1}
    return self
end

--- Set the alpha
-- @param alpha number - Alpha value (0-1)
-- @return self
function LoolibWidgetBuilderMixin:Alpha(alpha)
    self.properties.alpha = alpha
    return self
end

--- Set the frame level
-- @param level number - Frame level
-- @return self
function LoolibWidgetBuilderMixin:FrameLevel(level)
    self.properties.frameLevel = level
    return self
end

--- Set the frame strata
-- @param strata string - Frame strata (e.g., "HIGH", "DIALOG")
-- @return self
function LoolibWidgetBuilderMixin:FrameStrata(strata)
    self.properties.frameStrata = strata
    return self
end

--- Set visibility
-- @param shown boolean - Whether to show the frame
-- @return self
function LoolibWidgetBuilderMixin:Shown(shown)
    self.properties.shown = shown
    return self
end

--- Hide the frame initially
-- @return self
function LoolibWidgetBuilderMixin:Hidden()
    self.properties.shown = false
    return self
end

--[[--------------------------------------------------------------------
    Behavior
----------------------------------------------------------------------]]

--- Make the frame movable
-- @param clampToScreen boolean - Whether to clamp to screen (default true)
-- @return self
function LoolibWidgetBuilderMixin:Movable(clampToScreen)
    self.properties.movable = true
    self.properties.clampToScreen = clampToScreen ~= false
    return self
end

--- Make the frame resizable
-- @param minWidth number - Minimum width
-- @param minHeight number - Minimum height
-- @param maxWidth number - Maximum width (optional)
-- @param maxHeight number - Maximum height (optional)
-- @return self
function LoolibWidgetBuilderMixin:Resizable(minWidth, minHeight, maxWidth, maxHeight)
    self.properties.resizable = true
    self.properties.minWidth = minWidth
    self.properties.minHeight = minHeight
    self.properties.maxWidth = maxWidth
    self.properties.maxHeight = maxHeight
    return self
end

--- Add a close button
-- @param onClose function - Optional callback when closed
-- @return self
function LoolibWidgetBuilderMixin:CloseButton(onClose)
    self.properties.closeButton = true
    self.properties.onCloseCallback = onClose
    return self
end

--- Add a title
-- @param title string - Title text
-- @param fontObject string - Font object name (optional)
-- @return self
function LoolibWidgetBuilderMixin:Title(title, fontObject)
    self.properties.title = title
    self.properties.titleFont = fontObject
    return self
end

--- Enable mouse
-- @param enabled boolean - Enable mouse (default true)
-- @return self
function LoolibWidgetBuilderMixin:EnableMouse(enabled)
    self.properties.enableMouse = enabled ~= false
    return self
end

--- Enable keyboard
-- @param enabled boolean - Enable keyboard (default true)
-- @return self
function LoolibWidgetBuilderMixin:EnableKeyboard(enabled)
    self.properties.enableKeyboard = enabled ~= false
    return self
end

--[[--------------------------------------------------------------------
    Widget-Specific Properties
----------------------------------------------------------------------]]

--- Set button/fontstring text
-- @param text string - The text to display
-- @param fontObject string - Font object name (optional)
-- @return self
function LoolibWidgetBuilderMixin:Text(text, fontObject)
    self.properties.text = text
    self.properties.fontObject = fontObject
    return self
end

--- Set button textures
-- @param normal string - Normal texture path
-- @param pushed string - Pushed texture path
-- @param highlight string - Highlight texture path
-- @param disabled string - Disabled texture path
-- @return self
function LoolibWidgetBuilderMixin:Textures(normal, pushed, highlight, disabled)
    self.properties.normalTexture = normal
    self.properties.pushedTexture = pushed
    self.properties.highlightTexture = highlight
    self.properties.disabledTexture = disabled
    return self
end

--- Set slider/statusbar range
-- @param minValue number - Minimum value
-- @param maxValue number - Maximum value
-- @return self
function LoolibWidgetBuilderMixin:Range(minValue, maxValue)
    self.properties.minValue = minValue
    self.properties.maxValue = maxValue
    return self
end

--- Set slider step size
-- @param step number - Step size
-- @return self
function LoolibWidgetBuilderMixin:Step(step)
    self.properties.valueStep = step
    return self
end

--- Set slider orientation
-- @param orientation string - "HORIZONTAL" or "VERTICAL"
-- @return self
function LoolibWidgetBuilderMixin:Orientation(orientation)
    self.properties.orientation = orientation
    return self
end

--- Set initial value (slider/statusbar)
-- @param value number - Initial value
-- @return self
function LoolibWidgetBuilderMixin:Value(value)
    self.properties.value = value
    return self
end

--- Set editbox max letters
-- @param maxLetters number - Maximum characters
-- @return self
function LoolibWidgetBuilderMixin:MaxLetters(maxLetters)
    self.properties.maxLetters = maxLetters
    return self
end

--- Set editbox numeric only
-- @param numeric boolean - Only allow numbers
-- @return self
function LoolibWidgetBuilderMixin:Numeric(numeric)
    self.properties.numeric = numeric ~= false
    return self
end

--- Set editbox password mode
-- @param password boolean - Hide characters
-- @return self
function LoolibWidgetBuilderMixin:Password(password)
    self.properties.password = password ~= false
    return self
end

--- Set editbox placeholder text
-- @param placeholder string - Placeholder text
-- @return self
function LoolibWidgetBuilderMixin:Placeholder(placeholder)
    self.properties.placeholder = placeholder
    return self
end

--- Set checkbox label
-- @param label string - Label text
-- @return self
function LoolibWidgetBuilderMixin:Label(label)
    self.properties.label = label
    return self
end

--- Set checkbox checked state
-- @param checked boolean - Whether checked
-- @return self
function LoolibWidgetBuilderMixin:Checked(checked)
    self.properties.checked = checked
    return self
end

--[[--------------------------------------------------------------------
    Event Handlers
----------------------------------------------------------------------]]

--- Set OnClick handler
-- @param handler function - Click handler
-- @return self
function LoolibWidgetBuilderMixin:OnClick(handler)
    self.scripts.OnClick = handler
    return self
end

--- Set OnEnter handler
-- @param handler function - Enter handler
-- @return self
function LoolibWidgetBuilderMixin:OnEnter(handler)
    self.scripts.OnEnter = handler
    return self
end

--- Set OnLeave handler
-- @param handler function - Leave handler
-- @return self
function LoolibWidgetBuilderMixin:OnLeave(handler)
    self.scripts.OnLeave = handler
    return self
end

--- Set OnShow handler
-- @param handler function - Show handler
-- @return self
function LoolibWidgetBuilderMixin:OnShow(handler)
    self.scripts.OnShow = handler
    return self
end

--- Set OnHide handler
-- @param handler function - Hide handler
-- @return self
function LoolibWidgetBuilderMixin:OnHide(handler)
    self.scripts.OnHide = handler
    return self
end

--- Set OnUpdate handler
-- @param handler function - Update handler
-- @return self
function LoolibWidgetBuilderMixin:OnUpdate(handler)
    self.scripts.OnUpdate = handler
    return self
end

--- Set OnValueChanged handler (sliders)
-- @param handler function - Value changed handler
-- @return self
function LoolibWidgetBuilderMixin:OnValueChanged(handler)
    self.scripts.OnValueChanged = handler
    return self
end

--- Set OnTextChanged handler (editbox)
-- @param handler function - Text changed handler
-- @return self
function LoolibWidgetBuilderMixin:OnTextChanged(handler)
    self.scripts.OnTextChanged = handler
    return self
end

--- Set OnEnterPressed handler (editbox)
-- @param handler function - Enter pressed handler
-- @return self
function LoolibWidgetBuilderMixin:OnEnterPressed(handler)
    self.scripts.OnEnterPressed = handler
    return self
end

--- Set OnEscapePressed handler (editbox)
-- @param handler function - Escape pressed handler
-- @return self
function LoolibWidgetBuilderMixin:OnEscapePressed(handler)
    self.scripts.OnEscapePressed = handler
    return self
end

--- Set OnMouseDown handler
-- @param handler function - Mouse down handler
-- @return self
function LoolibWidgetBuilderMixin:OnMouseDown(handler)
    self.scripts.OnMouseDown = handler
    return self
end

--- Set OnMouseUp handler
-- @param handler function - Mouse up handler
-- @return self
function LoolibWidgetBuilderMixin:OnMouseUp(handler)
    self.scripts.OnMouseUp = handler
    return self
end

--- Set OnMouseWheel handler
-- @param handler function - Mouse wheel handler
-- @return self
function LoolibWidgetBuilderMixin:OnMouseWheel(handler)
    self.scripts.OnMouseWheel = handler
    self.properties.enableMouseWheel = true
    return self
end

--- Set OnDragStart handler
-- @param handler function - Drag start handler
-- @return self
function LoolibWidgetBuilderMixin:OnDragStart(handler)
    self.scripts.OnDragStart = handler
    return self
end

--- Set OnDragStop handler
-- @param handler function - Drag stop handler
-- @return self
function LoolibWidgetBuilderMixin:OnDragStop(handler)
    self.scripts.OnDragStop = handler
    return self
end

--[[--------------------------------------------------------------------
    Advanced Options
----------------------------------------------------------------------]]

--- Apply mixins to the frame
-- @param ... - Mixins to apply
-- @return self
function LoolibWidgetBuilderMixin:Mixin(...)
    for i = 1, select("#", ...) do
        self.mixins[#self.mixins + 1] = select(i, ...)
    end
    return self
end

--- Use a specific XML template
-- @param template string - Template name
-- @return self
function LoolibWidgetBuilderMixin:Template(template)
    self.template = template
    return self
end

--- Set the global name
-- @param name string - Global frame name
-- @return self
function LoolibWidgetBuilderMixin:Name(name)
    self.name = name
    return self
end

--- Use object pooling
-- @param resetFunc function - Reset function for pool
-- @return self
function LoolibWidgetBuilderMixin:Pooled(resetFunc)
    self.pooled = true
    self.resetFunc = resetFunc
    return self
end

--- Use a specific theme
-- @param themeName string - Theme name to use
-- @return self
function LoolibWidgetBuilderMixin:Theme(themeName)
    self.themeName = themeName
    return self
end

--- Set a custom property
-- @param key string - Property key
-- @param value any - Property value
-- @return self
function LoolibWidgetBuilderMixin:Set(key, value)
    self.properties[key] = value
    return self
end

--[[--------------------------------------------------------------------
    Build Methods
----------------------------------------------------------------------]]

--- Build and return the frame
-- @return Frame - The created frame
function LoolibWidgetBuilderMixin:Build()
    local frame

    -- Create the frame
    if self.pooled then
        frame = LoolibFrameFactory:Create(self.parent, self.template or self.frameType, self.resetFunc)
    else
        frame = CreateFrame(self.frameType, self.name, self.parent, self.template)
    end

    -- Apply mixins
    if #self.mixins > 0 then
        LoolibMixin(frame, unpack(self.mixins))
        LoolibReflectScriptHandlers(frame)
    end

    -- Set size
    if self.width then
        frame:SetWidth(self.width)
    end
    if self.height then
        frame:SetHeight(self.height)
    end

    -- Set points
    if self.properties.fillParent then
        LoolibAnchorUtil.SetAllPoints(frame, self.parent, self.properties.fillInset)
    elseif #self.points > 0 then
        frame:ClearAllPoints()
        for _, pointData in ipairs(self.points) do
            frame:SetPoint(
                pointData.point,
                pointData.relativeTo or self.parent,
                pointData.relativePoint,
                pointData.x,
                pointData.y
            )
        end
    end

    -- Apply backdrop
    if self.backdrop and frame.SetBackdrop then
        frame:SetBackdrop(self.backdrop)
    elseif self.properties.themeBackdrop and frame.SetBackdrop then
        local backdrop = LoolibThemeManager:GetBackdrop(self.properties.themeBackdrop)
        if backdrop then
            frame:SetBackdrop(backdrop)
        end
    end

    if self.backdropColor and frame.SetBackdropColor then
        frame:SetBackdropColor(unpack(self.backdropColor))
    end

    if self.backdropBorderColor and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(unpack(self.backdropBorderColor))
    end

    -- Apply properties
    self:ApplyProperties(frame)

    -- Apply scripts
    for scriptName, handler in pairs(self.scripts) do
        if frame:HasScript(scriptName) then
            frame:SetScript(scriptName, handler)
        end
    end

    -- Apply visibility
    if self.properties.shown == false then
        frame:Hide()
    elseif self.properties.shown == true then
        frame:Show()
    end

    -- Call Init if available
    if frame.Init then
        frame:Init()
    end

    return frame
end

--- Build the frame and show it
-- @return Frame - The created frame (shown)
function LoolibWidgetBuilderMixin:BuildAndShow()
    local frame = self:Build()
    frame:Show()
    return frame
end

--[[--------------------------------------------------------------------
    Internal: Apply Properties
----------------------------------------------------------------------]]

function LoolibWidgetBuilderMixin:ApplyProperties(frame)
    local props = self.properties

    -- Frame properties
    if props.alpha then
        frame:SetAlpha(props.alpha)
    end

    if props.frameLevel then
        frame:SetFrameLevel(props.frameLevel)
    end

    if props.frameStrata then
        frame:SetFrameStrata(props.frameStrata)
    end

    if props.enableMouse ~= nil then
        frame:EnableMouse(props.enableMouse)
    end

    if props.enableKeyboard then
        frame:EnableKeyboard(props.enableKeyboard)
    end

    if props.enableMouseWheel then
        frame:EnableMouseWheel(true)
    end

    -- Movable
    if props.movable then
        LoolibFrameUtil.MakeMovable(frame, props.clampToScreen)
    end

    -- Resizable
    if props.resizable then
        LoolibFrameUtil.MakeResizable(frame, props.minWidth, props.minHeight, props.maxWidth, props.maxHeight)
    end

    -- Close button
    if props.closeButton then
        LoolibFrameUtil.AddCloseButton(frame, props.onCloseCallback)
    end

    -- Title
    if props.title then
        LoolibFrameUtil.AddTitle(frame, props.title, props.titleFont)
    end

    -- Button-specific
    if self.frameType == "Button" then
        self:ApplyButtonProperties(frame)
    end

    -- EditBox-specific
    if self.frameType == "EditBox" then
        self:ApplyEditBoxProperties(frame)
    end

    -- Slider-specific
    if self.frameType == "Slider" then
        self:ApplySliderProperties(frame)
    end

    -- StatusBar-specific
    if self.frameType == "StatusBar" then
        self:ApplyStatusBarProperties(frame)
    end

    -- CheckButton-specific
    if self.frameType == "CheckButton" then
        self:ApplyCheckButtonProperties(frame)
    end
end

function LoolibWidgetBuilderMixin:ApplyButtonProperties(frame)
    local props = self.properties

    if props.normalTexture then
        frame:SetNormalTexture(props.normalTexture)
    end
    if props.pushedTexture then
        frame:SetPushedTexture(props.pushedTexture)
    end
    if props.highlightTexture then
        frame:SetHighlightTexture(props.highlightTexture)
    end
    if props.disabledTexture then
        frame:SetDisabledTexture(props.disabledTexture)
    end

    if props.text then
        if not frame.Text then
            frame.Text = frame:CreateFontString(nil, "OVERLAY", props.fontObject or "GameFontNormal")
            frame.Text:SetPoint("CENTER")
        end
        frame.Text:SetText(props.text)
        frame:SetFontString(frame.Text)
    end
end

function LoolibWidgetBuilderMixin:ApplyEditBoxProperties(frame)
    local props = self.properties

    frame:SetAutoFocus(props.autoFocus or false)

    if props.multiLine then
        frame:SetMultiLine(true)
    end

    if props.maxLetters then
        frame:SetMaxLetters(props.maxLetters)
    end

    if props.numeric then
        frame:SetNumeric(true)
    end

    if props.password then
        frame:SetPassword(true)
    end

    if props.fontObject then
        frame:SetFontObject(props.fontObject)
    end

    if props.text then
        frame:SetText(props.text)
    end

    -- Placeholder handling would require custom logic
    if props.placeholder then
        frame.placeholder = props.placeholder
        -- Could add OnEditFocusGained/Lost handlers here
    end
end

function LoolibWidgetBuilderMixin:ApplySliderProperties(frame)
    local props = self.properties

    frame:SetOrientation(props.orientation or "HORIZONTAL")
    frame:SetMinMaxValues(props.minValue or 0, props.maxValue or 100)
    frame:SetValueStep(props.valueStep or 1)
    frame:SetObeyStepOnDrag(true)

    if props.value then
        frame:SetValue(props.value)
    end
end

function LoolibWidgetBuilderMixin:ApplyStatusBarProperties(frame)
    local props = self.properties

    frame:SetMinMaxValues(props.minValue or 0, props.maxValue or 100)

    if props.value then
        frame:SetValue(props.value)
    end

    if props.statusBarTexture then
        frame:SetStatusBarTexture(props.statusBarTexture)
    end
end

function LoolibWidgetBuilderMixin:ApplyCheckButtonProperties(frame)
    local props = self.properties

    if props.checked then
        frame:SetChecked(true)
    end

    if props.label then
        if not frame.Text then
            frame.Text = frame:CreateFontString(nil, "OVERLAY", props.fontObject or "GameFontNormal")
            frame.Text:SetPoint("LEFT", frame, "RIGHT", 4, 0)
        end
        frame.Text:SetText(props.label)
    end
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new widget builder
-- @param parent Frame - Parent frame
-- @return LoolibWidgetBuilderMixin - A new builder instance
function CreateLoolibWidgetBuilder(parent)
    local builder = LoolibCreateFromMixins(LoolibWidgetBuilderMixin)
    builder:Init(parent)
    return builder
end

--[[--------------------------------------------------------------------
    Convenience Function
----------------------------------------------------------------------]]

--- UI.Widget() - Entry point for fluent widget creation
-- @param parent Frame - Parent frame
-- @return LoolibWidgetBuilderMixin - A new builder instance
function LoolibWidget(parent)
    return CreateLoolibWidgetBuilder(parent)
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local WidgetBuilderModule = {
    Mixin = LoolibWidgetBuilderMixin,
    Create = CreateLoolibWidgetBuilder,
    Widget = LoolibWidget,
}

-- Register in UI module
local UI = Loolib:GetOrCreateModule("UI")
UI.WidgetBuilder = WidgetBuilderModule
UI.Widget = LoolibWidget

Loolib:RegisterModule("WidgetBuilder", WidgetBuilderModule)
