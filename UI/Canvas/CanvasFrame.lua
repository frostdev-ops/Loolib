--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    CanvasFrame - Main canvas container that coordinates all canvas systems

    This is the top-level canvas component that brings together all canvas
    subsystems: brush drawing, shape creation, text/icon/image placement,
    grouping, selection, zoom/pan, undo/redo history, and network sync.

    The canvas frame handles:
    - Mouse input routing to appropriate tools
    - Frame/texture rendering for all element types
    - Object pooling for performance
    - Save/load of full canvas state
    - Toolbar integration
    - Transform management (zoom/pan)

    Architecture:
    - Main frame (_frame) contains drawing area (_drawArea)
    - Content frame (_content) applies zoom/pan transforms
    - Element managers handle data (brush, shape, text, icon, image)
    - Render frames display the data visually
    - Object pools minimize frame creation overhead

    Usage:
        local canvas = LoolibCreateCanvasFrame(UIParent)
        canvas:SetTool("brush")
              :SetColor(4)
              :SetBrushSize(6)
              :Show()

        -- Save/load state
        local data = canvas:SaveData()
        canvas:LoadData(data)

        -- Undo/redo
        canvas:Undo()
        canvas:Redo()

        -- Zoom/pan
        canvas:ZoomIn()
        canvas:ResetZoom()

    Dependencies:
    - Core/Loolib.lua (LibStub registration)
    - Core/Mixin.lua (LoolibMixin)
    - UI/Canvas/CanvasBrush.lua (brush drawing)
    - UI/Canvas/CanvasShape.lua (shape drawing)
    - UI/Canvas/CanvasText.lua (text labels)
    - UI/Canvas/CanvasIcon.lua (icon placement)
    - UI/Canvas/CanvasImage.lua (image placement)
    - UI/Canvas/CanvasElement.lua (color utilities)

    Author: James Kueller
    License: All Rights Reserved
    Created: 2025-12-06
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Verify dependencies
assert(LoolibMixin, "Loolib/Core/Mixin.lua must be loaded before CanvasFrame")

--[[--------------------------------------------------------------------
    LoolibCanvasFrameMixin

    Main canvas frame mixin that coordinates all canvas subsystems.
----------------------------------------------------------------------]]

LoolibCanvasFrameMixin = {}

--[[--------------------------------------------------------------------
    Initialization
----------------------------------------------------------------------]]

--- Initialize the canvas frame with default settings and managers
function LoolibCanvasFrameMixin:OnLoad()
    -- Frame dimensions
    self._width = 800
    self._height = 600

    -- Current tool and settings
    self._currentTool = "brush"
    self._currentColor = 4  -- Red
    self._currentSize = 6

    -- Background
    self._backgroundMapId = nil
    self._backgroundTexture = nil

    -- Create element managers
    local CanvasBrush = Loolib:GetModule("CanvasBrush")
    local CanvasShape = Loolib:GetModule("CanvasShape")
    local CanvasText = Loolib:GetModule("CanvasText")
    local CanvasIcon = Loolib:GetModule("CanvasIcon")
    local CanvasImage = Loolib:GetModule("CanvasImage")

    self._brushManager = CanvasBrush and CanvasBrush.Create() or nil
    self._shapeManager = CanvasShape and CanvasShape.Create() or nil
    self._textManager = CanvasText and CanvasText.Create() or nil
    self._iconManager = CanvasIcon and CanvasIcon.Create() or nil
    self._imageManager = CanvasImage and CanvasImage.Create() or nil

    -- Initialize managers with current settings
    if self._brushManager then
        self._brushManager:SetBrushSize(self._currentSize)
                         :SetBrushColor(self._currentColor)
    end

    if self._shapeManager then
        self._shapeManager:SetShapeSize(self._currentSize)
                         :SetShapeColor(self._currentColor)
    end

    if self._textManager then
        self._textManager:SetTextColor(self._currentColor)
    end

    -- Optional advanced managers (loaded if available)
    -- These are stubbed out since they don't exist yet
    self._groupManager = nil
    self._selectionManager = nil
    self._zoomManager = nil
    self._historyManager = nil
    self._syncManager = nil

    -- Render frame collections (populated by BuildUI)
    self._dotFrames = {}
    self._shapeFrames = {}
    self._textFrames = {}
    self._iconFrames = {}
    self._imageFrames = {}

    -- Object pools (created by BuildUI)
    self._dotPool = nil
    self._shapePool = nil
    self._textPool = nil
    self._iconPool = nil
    self._imagePool = nil

    -- Toolbar (created by BuildUI)
    self._toolbar = nil

    -- Mouse state
    self._isDrawing = false
    self._isDragging = false
    self._dragStartX = nil
    self._dragStartY = nil

    -- Setup callbacks for element events
    self:_SetupCallbacks()
end

--[[--------------------------------------------------------------------
    Callback Setup
----------------------------------------------------------------------]]

--- Setup event callbacks from element managers
function LoolibCanvasFrameMixin:_SetupCallbacks()
    -- Brush manager callbacks
    if self._brushManager and self._brushManager.RegisterCallback then
        self._brushManager:RegisterCallback("OnDotAdded", function(_, index)
            self:_RenderDot(index)
        end)

        self._brushManager:RegisterCallback("OnDotsCleared", function()
            self:_ClearDotFrames()
        end)
    end

    -- Icon manager callbacks
    if self._iconManager and self._iconManager.RegisterCallback then
        self._iconManager:RegisterCallback("OnIconAdded", function(_, index)
            self:_RenderIcon(index)
        end)

        self._iconManager:RegisterCallback("OnIconsCleared", function()
            self:_ClearIconFrames()
        end)
    end

    -- Text manager callbacks
    if self._textManager and self._textManager.RegisterCallback then
        self._textManager:RegisterCallback("OnTextAdded", function(_, index)
            self:_RenderText(index)
        end)

        self._textManager:RegisterCallback("OnTextsCleared", function()
            self:_ClearTextFrames()
        end)
    end

    -- Shape manager callbacks
    if self._shapeManager and self._shapeManager.RegisterCallback then
        self._shapeManager:RegisterCallback("OnShapeAdded", function(_, index)
            self:_RenderShape(index)
        end)

        self._shapeManager:RegisterCallback("OnShapesCleared", function()
            self:_ClearShapeFrames()
        end)
    end

    -- Image manager callbacks
    if self._imageManager and self._imageManager.RegisterCallback then
        self._imageManager:RegisterCallback("OnImageAdded", function(_, index)
            self:_RenderImage(index)
        end)

        self._imageManager:RegisterCallback("OnImagesCleared", function()
            self:_ClearImageFrames()
        end)
    end
end

--[[--------------------------------------------------------------------
    UI Construction
----------------------------------------------------------------------]]

--- Build the canvas UI hierarchy
-- @param parent Frame - Parent frame (defaults to UIParent)
-- @return self - For method chaining
function LoolibCanvasFrameMixin:BuildUI(parent)
    -- Create main canvas frame
    self._frame = CreateFrame("Frame", nil, parent or UIParent)
    self._frame:SetSize(self._width, self._height)
    self._frame:SetPoint("CENTER")

    -- Background
    local bg = self._frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    self._backgroundTexture = bg

    -- Drawing area (clips children to bounds)
    self._drawArea = CreateFrame("Frame", nil, self._frame)
    self._drawArea:SetAllPoints()
    self._drawArea:SetClipsChildren(true)

    -- Content frame (transforms with zoom/pan)
    self._content = CreateFrame("Frame", nil, self._drawArea)
    self._content:SetSize(self._width, self._height)
    self._content:SetPoint("CENTER")

    -- Enable mouse input
    self._frame:EnableMouse(true)
    self._frame:SetScript("OnMouseDown", function(_, button)
        self:_OnMouseDown(button)
    end)
    self._frame:SetScript("OnMouseUp", function(_, button)
        self:_OnMouseUp(button)
    end)

    -- Mouse wheel for zoom
    self._frame:EnableMouseWheel(true)
    self._frame:SetScript("OnMouseWheel", function(_, delta)
        self:_OnMouseWheel(delta)
    end)

    -- Update handler for continuous operations (dragging, etc.)
    self._frame:SetScript("OnUpdate", function(_, elapsed)
        self:_OnUpdate(elapsed)
    end)

    -- Create object pools for performance
    self:_CreatePools()

    -- Build toolbar (if available)
    local CanvasToolbar = Loolib:GetModule("CanvasToolbar")
    if CanvasToolbar then
        self._toolbar = CanvasToolbar.Create()
        self._toolbar:SetCanvas(self)
        self._toolbar:BuildUI(self._frame)
    end

    return self
end

--- Create object pools for efficient frame management
function LoolibCanvasFrameMixin:_CreatePools()
    -- Dot pool (for brush strokes)
    self._dotPool = CreateFramePool("Frame", self._content, nil, function(pool, frame)
        frame:Hide()
        frame:ClearAllPoints()
        if frame.texture then
            frame.texture:Hide()
        end
    end)

    -- Shape pool (for geometric shapes)
    self._shapePool = CreateFramePool("Frame", self._content, nil, function(pool, frame)
        frame:Hide()
        frame:ClearAllPoints()
        if frame.texture then
            frame.texture:Hide()
        end
    end)

    -- Text pool (for text labels)
    self._textPool = CreateFramePool("Frame", self._content, nil, function(pool, frame)
        frame:Hide()
        frame:ClearAllPoints()
        if frame.fontString then
            frame.fontString:SetText("")
        end
    end)

    -- Icon pool (for icons)
    self._iconPool = CreateFramePool("Frame", self._content, nil, function(pool, frame)
        frame:Hide()
        frame:ClearAllPoints()
        if frame.texture then
            frame.texture:Hide()
        end
    end)

    -- Image pool (for images)
    self._imagePool = CreateFramePool("Frame", self._content, nil, function(pool, frame)
        frame:Hide()
        frame:ClearAllPoints()
        if frame.texture then
            frame.texture:Hide()
        end
    end)
end

--[[--------------------------------------------------------------------
    Mouse Input Handling
----------------------------------------------------------------------]]

--- Handle mouse down events
-- @param button string - Mouse button ("LeftButton", "RightButton", etc.)
function LoolibCanvasFrameMixin:_OnMouseDown(button)
    local x, y = self:_GetMousePosition()

    if button == "LeftButton" then
        if self._currentTool == "brush" then
            -- Start brush stroke
            if self._brushManager then
                self._brushManager:StartStroke(x, y)
                self._isDrawing = true
            end

        elseif self._currentTool:match("^shape_") then
            -- Start shape drawing
            if self._shapeManager then
                local shapeType = self:_ToolToShapeType(self._currentTool)
                self._shapeManager:SetShapeType(shapeType)
                self._shapeManager:StartShape(x, y)
                self._isDrawing = true
            end

        elseif self._currentTool == "icon" then
            -- Place icon immediately
            if self._iconManager then
                local index = self._iconManager:AddIcon(x, y)
                if self._historyManager then
                    self._historyManager:PushAction("add_icon", {
                        index = index,
                        x = x, y = y,
                        iconType = self._iconManager:GetIconType(),
                        size = self._iconManager:GetIconSize(),
                    })
                end
            end

        elseif self._currentTool == "text" then
            -- Show text input dialog
            self:_ShowTextInput(x, y)

        elseif self._currentTool == "image" then
            -- Start image placement
            if self._imageManager then
                self._imageManager:StartPlacement(x, y)
                self._isDrawing = true
            end

        elseif self._currentTool == "select" then
            -- Handle selection (requires selection manager)
            if self._selectionManager then
                local isShift = IsShiftKeyDown()
                self._selectionManager:HandleClick(x, y, isShift, IsControlKeyDown())
            end

        elseif self._currentTool == "move" then
            -- Start move operation (requires selection manager)
            if self._selectionManager and self._selectionManager:HasSelection() then
                self._isDragging = true
                self._dragStartX = x
                self._dragStartY = y
            end
        end

    elseif button == "RightButton" then
        -- Pan (requires zoom manager)
        if self._zoomManager then
            self._zoomManager:StartPan(x, y)
        end
    end
end

--- Handle mouse up events
-- @param button string - Mouse button
function LoolibCanvasFrameMixin:_OnMouseUp(button)
    local x, y = self:_GetMousePosition()

    if button == "LeftButton" then
        if self._isDrawing then
            if self._currentTool == "brush" then
                -- End brush stroke
                if self._brushManager then
                    self._brushManager:EndStroke()

                    if self._historyManager then
                        self._historyManager:PushAction("add_stroke", {
                            -- Stroke data would be captured here
                        })
                    end
                end

            elseif self._currentTool:match("^shape_") then
                -- Finish shape
                if self._shapeManager then
                    local index = self._shapeManager:FinishShape(x, y)
                    if index and self._historyManager then
                        self._historyManager:PushAction("add_shape", {
                            index = index,
                        })
                    end
                end

            elseif self._currentTool == "image" then
                -- Finish image placement
                if self._imageManager then
                    self._imageManager:FinishPlacement(x, y)
                end
            end

            self._isDrawing = false
        end

        if self._isDragging then
            self._isDragging = false
            self._dragStartX = nil
            self._dragStartY = nil
        end

    elseif button == "RightButton" then
        -- End pan
        if self._zoomManager and self._zoomManager.IsPanning and self._zoomManager:IsPanning() then
            self._zoomManager:EndPan()
        end
    end
end

--- Handle mouse wheel events (zoom)
-- @param delta number - Scroll delta (+1 or -1)
function LoolibCanvasFrameMixin:_OnMouseWheel(delta)
    if self._zoomManager then
        local x, y = self:_GetMousePosition()
        self._zoomManager:HandleMouseWheel(delta, x, y)
        self:_UpdateTransform()
    end
end

--- Handle continuous updates (dragging, etc.)
-- @param elapsed number - Time since last update
function LoolibCanvasFrameMixin:_OnUpdate(elapsed)
    if not self._frame:IsMouseOver() then return end

    local x, y = self:_GetMousePosition()

    -- Continue drawing operations
    if self._isDrawing then
        if self._currentTool == "brush" and self._brushManager then
            self._brushManager:ContinueStroke(x, y)

        elseif self._currentTool:match("^shape_") and self._shapeManager then
            self._shapeManager:UpdateShapePreview(x, y)

        elseif self._currentTool == "image" and self._imageManager then
            self._imageManager:UpdatePlacement(x, y)
        end
    end

    -- Handle dragging
    if self._isDragging and self._selectionManager and self._selectionManager.HasSelection then
        if self._selectionManager:HasSelection() then
            local dx = x - self._dragStartX
            local dy = y - self._dragStartY
            self._selectionManager:MoveSelection(dx, dy)
            self._dragStartX = x
            self._dragStartY = y
        end
    end

    -- Handle panning
    if self._zoomManager and self._zoomManager.IsPanning and self._zoomManager:IsPanning() then
        self._zoomManager:UpdatePan(x, y)
        self:_UpdateTransform()
    end
end

--- Get mouse position in canvas coordinates
-- @return number, number - X and Y coordinates
function LoolibCanvasFrameMixin:_GetMousePosition()
    local x, y = GetCursorPosition()
    local scale = self._frame:GetEffectiveScale()
    x, y = x / scale, y / scale

    local left = self._frame:GetLeft() or 0
    local bottom = self._frame:GetBottom() or 0
    x, y = x - left, y - bottom

    -- Convert to canvas coordinates via zoom manager (if available)
    if self._zoomManager and self._zoomManager.ScreenToCanvas then
        x, y = self._zoomManager:ScreenToCanvas(x, y)
    end

    return x, y
end

--[[--------------------------------------------------------------------
    Transform Management
----------------------------------------------------------------------]]

--- Update content frame transform based on zoom/pan state
function LoolibCanvasFrameMixin:_UpdateTransform()
    if not self._zoomManager then return end

    local zoom = self._zoomManager.GetZoom and self._zoomManager:GetZoom() or 1
    local panX, panY = 0, 0
    if self._zoomManager.GetPan then
        panX, panY = self._zoomManager:GetPan()
    end

    self._content:SetScale(zoom)
    self._content:ClearAllPoints()
    self._content:SetPoint("CENTER", self._drawArea, "CENTER", panX * zoom, panY * zoom)
end

--[[--------------------------------------------------------------------
    Tool Conversion
----------------------------------------------------------------------]]

--- Convert tool name to shape type constant
-- @param tool string - Tool name (e.g., "shape_line")
-- @return number - Shape type constant
function LoolibCanvasFrameMixin:_ToolToShapeType(tool)
    local CanvasShape = Loolib:GetModule("CanvasShape")
    local TYPES = CanvasShape and CanvasShape.TYPES or {}

    if tool == "shape_line" then return TYPES.LINE or 3
    elseif tool == "shape_arrow" then return TYPES.LINE_ARROW or 4
    elseif tool == "shape_circle" then return TYPES.CIRCLE or 1
    elseif tool == "shape_rectangle" then return TYPES.RECTANGLE or 6
    end

    return TYPES.LINE or 3
end

--[[--------------------------------------------------------------------
    Text Input Dialog
----------------------------------------------------------------------]]

--- Show text input dialog at position
-- @param x number - X coordinate
-- @param y number - Y coordinate
function LoolibCanvasFrameMixin:_ShowTextInput(x, y)
    -- Simple text input using StaticPopup
    StaticPopupDialogs["LOOLIB_CANVAS_TEXT_INPUT"] = {
        text = "Enter text:",
        button1 = "OK",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self)
            local text = self.editBox:GetText()
            if text and text ~= "" then
                local canvas = self.data
                if canvas._textManager then
                    local index = canvas._textManager:AddText(x, y, text)
                    if canvas._historyManager then
                        canvas._historyManager:PushAction("add_text", {
                            index = index,
                            x = x, y = y,
                            text = text,
                        })
                    end
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    local dialog = StaticPopup_Show("LOOLIB_CANVAS_TEXT_INPUT")
    if dialog then
        dialog.data = self
    end
end

--[[--------------------------------------------------------------------
    Rendering - Dots (Brush Strokes)
----------------------------------------------------------------------]]

--- Render a single dot from the brush manager
-- @param index number - Dot index
function LoolibCanvasFrameMixin:_RenderDot(index)
    if not self._brushManager then return end

    local dot = self._brushManager:GetDot(index)
    if not dot then return end

    local frame = self._dotPool:Acquire()
    frame:SetSize(dot.size, dot.size)
    frame:SetPoint("CENTER", self._content, "TOPLEFT", dot.x, -dot.y)

    local tex = frame.texture or frame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetColorTexture(LoolibGetCanvasColor(dot.color))
    frame.texture = tex

    frame:Show()
    self._dotFrames[index] = frame
end

--- Clear all dot render frames
function LoolibCanvasFrameMixin:_ClearDotFrames()
    for _, frame in pairs(self._dotFrames) do
        if self._dotPool then
            self._dotPool:Release(frame)
        else
            frame:Hide()
        end
    end
    self._dotFrames = {}
end

--[[--------------------------------------------------------------------
    Rendering - Icons
----------------------------------------------------------------------]]

--- Render a single icon from the icon manager
-- @param index number - Icon index
function LoolibCanvasFrameMixin:_RenderIcon(index)
    if not self._iconManager then return end

    local icon = self._iconManager:GetIcon(index)
    if not icon then return end

    local frame = self._iconPool:Acquire()
    frame:SetSize(icon.size, icon.size)
    frame:SetPoint("CENTER", self._content, "TOPLEFT", icon.x, -icon.y)

    local tex = frame.texture or frame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    frame.texture = tex

    local texInfo = self._iconManager:GetIconTexture(icon.iconType)
    if texInfo then
        tex:SetTexture(texInfo.path)
        if texInfo.coords then
            tex:SetTexCoord(unpack(texInfo.coords))
        else
            tex:SetTexCoord(0, 1, 0, 1)
        end
    end

    frame:Show()
    self._iconFrames[index] = frame
end

--- Clear all icon render frames
function LoolibCanvasFrameMixin:_ClearIconFrames()
    for _, frame in pairs(self._iconFrames) do
        if self._iconPool then
            self._iconPool:Release(frame)
        else
            frame:Hide()
        end
    end
    self._iconFrames = {}
end

--[[--------------------------------------------------------------------
    Rendering - Text
----------------------------------------------------------------------]]

--- Render a single text label from the text manager
-- @param index number - Text index
function LoolibCanvasFrameMixin:_RenderText(index)
    if not self._textManager then return end

    local textData = self._textManager:GetText(index)
    if not textData then return end

    local frame = self._textPool:Acquire()
    frame:SetSize(200, 50)  -- Approximate size
    frame:SetPoint("TOPLEFT", self._content, "TOPLEFT", textData.x, -textData.y)

    local fontString = frame.fontString or frame:CreateFontString(nil, "OVERLAY")
    fontString:SetFont("Fonts\\FRIZQT__.TTF", textData.size or 12)
    fontString:SetText(textData.text)
    fontString:SetTextColor(LoolibGetCanvasColor(textData.color))
    fontString:SetAllPoints()
    fontString:SetJustifyH("LEFT")
    fontString:SetJustifyV("TOP")
    frame.fontString = fontString

    frame:Show()
    self._textFrames[index] = frame
end

--- Clear all text render frames
function LoolibCanvasFrameMixin:_ClearTextFrames()
    for _, frame in pairs(self._textFrames) do
        if self._textPool then
            self._textPool:Release(frame)
        else
            frame:Hide()
        end
    end
    self._textFrames = {}
end

--[[--------------------------------------------------------------------
    Rendering - Shapes
----------------------------------------------------------------------]]

--- Render a single shape from the shape manager
-- @param index number - Shape index
function LoolibCanvasFrameMixin:_RenderShape(index)
    if not self._shapeManager then return end

    local shape = self._shapeManager:GetShape(index)
    if not shape then return end

    -- For now, use a simple line texture
    -- Full implementation would need proper shape rendering
    local frame = self._shapePool:Acquire()

    local width = math.abs(shape.x2 - shape.x1)
    local height = math.abs(shape.y2 - shape.y1)
    frame:SetSize(math.max(width, 1), math.max(height, 1))
    frame:SetPoint("TOPLEFT", self._content, "TOPLEFT",
                   math.min(shape.x1, shape.x2),
                   -math.min(shape.y1, shape.y2))

    local tex = frame.texture or frame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetColorTexture(LoolibGetCanvasColor(shape.color))
    tex:SetAlpha(shape.alpha or 1)
    frame.texture = tex

    frame:Show()
    self._shapeFrames[index] = frame
end

--- Clear all shape render frames
function LoolibCanvasFrameMixin:_ClearShapeFrames()
    for _, frame in pairs(self._shapeFrames) do
        if self._shapePool then
            self._shapePool:Release(frame)
        else
            frame:Hide()
        end
    end
    self._shapeFrames = {}
end

--[[--------------------------------------------------------------------
    Rendering - Images
----------------------------------------------------------------------]]

--- Render a single image from the image manager
-- @param index number - Image index
function LoolibCanvasFrameMixin:_RenderImage(index)
    if not self._imageManager then return end

    local image = self._imageManager:GetImage(index)
    if not image then return end

    local frame = self._imagePool:Acquire()
    frame:SetSize(image.width, image.height)
    frame:SetPoint("TOPLEFT", self._content, "TOPLEFT", image.x1, -image.y1)

    local tex = frame.texture or frame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(image.path)
    tex:SetAlpha(image.alpha or 1)
    frame.texture = tex

    frame:Show()
    self._imageFrames[index] = frame
end

--- Clear all image render frames
function LoolibCanvasFrameMixin:_ClearImageFrames()
    for _, frame in pairs(self._imageFrames) do
        if self._imagePool then
            self._imagePool:Release(frame)
        else
            frame:Hide()
        end
    end
    self._imageFrames = {}
end

--[[--------------------------------------------------------------------
    Public API - Tool Management
----------------------------------------------------------------------]]

--- Set the current drawing tool
-- @param tool string - Tool name ("brush", "shape_line", "icon", etc.)
-- @return self - For method chaining
function LoolibCanvasFrameMixin:SetTool(tool)
    self._currentTool = tool
    return self
end

--- Get the current drawing tool
-- @return string - Current tool name
function LoolibCanvasFrameMixin:GetTool()
    return self._currentTool
end

--- Set the current color for drawing
-- @param colorIndex number - Color palette index (1-25)
-- @return self - For method chaining
function LoolibCanvasFrameMixin:SetColor(colorIndex)
    self._currentColor = colorIndex
    if self._brushManager then self._brushManager:SetBrushColor(colorIndex) end
    if self._shapeManager then self._shapeManager:SetShapeColor(colorIndex) end
    if self._textManager then self._textManager:SetTextColor(colorIndex) end
    return self
end

--- Get the current color
-- @return number - Current color palette index
function LoolibCanvasFrameMixin:GetColor()
    return self._currentColor
end

--- Set the brush/shape size
-- @param size number - Size in pixels
-- @return self - For method chaining
function LoolibCanvasFrameMixin:SetBrushSize(size)
    self._currentSize = size
    if self._brushManager then self._brushManager:SetBrushSize(size) end
    if self._shapeManager then self._shapeManager:SetShapeSize(size) end
    return self
end

--- Get the current brush/shape size
-- @return number - Current size
function LoolibCanvasFrameMixin:GetBrushSize()
    return self._currentSize
end

--[[--------------------------------------------------------------------
    Public API - Zoom (delegation to zoom manager)
----------------------------------------------------------------------]]

--- Get current zoom level
-- @return number - Zoom level (1.0 = 100%)
function LoolibCanvasFrameMixin:GetZoom()
    if self._zoomManager and self._zoomManager.GetZoom then
        return self._zoomManager:GetZoom()
    end
    return 1
end

--- Zoom in
-- @return self - For method chaining
function LoolibCanvasFrameMixin:ZoomIn()
    if self._zoomManager and self._zoomManager.ZoomIn then
        self._zoomManager:ZoomIn()
        self:_UpdateTransform()
    end
    return self
end

--- Zoom out
-- @return self - For method chaining
function LoolibCanvasFrameMixin:ZoomOut()
    if self._zoomManager and self._zoomManager.ZoomOut then
        self._zoomManager:ZoomOut()
        self:_UpdateTransform()
    end
    return self
end

--- Reset zoom to 100%
-- @return self - For method chaining
function LoolibCanvasFrameMixin:ResetZoom()
    if self._zoomManager and self._zoomManager.ResetZoom then
        self._zoomManager:ResetZoom()
        self:_UpdateTransform()
    end
    return self
end

--[[--------------------------------------------------------------------
    Public API - History (delegation to history manager)
----------------------------------------------------------------------]]

--- Check if undo is available
-- @return boolean - True if can undo
function LoolibCanvasFrameMixin:CanUndo()
    return self._historyManager and self._historyManager.CanUndo
           and self._historyManager:CanUndo() or false
end

--- Check if redo is available
-- @return boolean - True if can redo
function LoolibCanvasFrameMixin:CanRedo()
    return self._historyManager and self._historyManager.CanRedo
           and self._historyManager:CanRedo() or false
end

--- Undo last action
-- @return self - For method chaining
function LoolibCanvasFrameMixin:Undo()
    if self._historyManager and self._historyManager.Undo then
        self._historyManager:Undo()
        self:Refresh()
    end
    return self
end

--- Redo last undone action
-- @return self - For method chaining
function LoolibCanvasFrameMixin:Redo()
    if self._historyManager and self._historyManager.Redo then
        self._historyManager:Redo()
        self:Refresh()
    end
    return self
end

--[[--------------------------------------------------------------------
    Public API - Canvas Operations
----------------------------------------------------------------------]]

--- Clear the entire canvas
-- @return self - For method chaining
function LoolibCanvasFrameMixin:Clear()
    -- Push to history before clearing
    if self._historyManager and self._historyManager.PushAction then
        self._historyManager:PushAction("clear_all", {
            snapshot = self._historyManager.CreateSnapshot
                       and self._historyManager:CreateSnapshot() or nil
        })
    end

    -- Clear all element managers
    if self._brushManager then self._brushManager:ClearDots() end
    if self._shapeManager then self._shapeManager:ClearShapes() end
    if self._textManager then self._textManager:ClearTexts() end
    if self._iconManager then self._iconManager:ClearIcons() end
    if self._imageManager then self._imageManager:ClearImages() end

    -- Clear all render frames
    self:_ClearAllFrames()

    return self
end

--- Refresh all rendered elements
-- @return self - For method chaining
function LoolibCanvasFrameMixin:Refresh()
    -- Clear existing render frames
    self:_ClearAllFrames()

    -- Re-render all elements
    if self._brushManager then
        for i = 1, self._brushManager:GetDotCount() do
            self:_RenderDot(i)
        end
    end

    if self._iconManager then
        for i = 1, self._iconManager:GetIconCount() do
            self:_RenderIcon(i)
        end
    end

    if self._textManager then
        for i = 1, self._textManager:GetTextCount() do
            self:_RenderText(i)
        end
    end

    if self._shapeManager then
        for i = 1, self._shapeManager:GetShapeCount() do
            self:_RenderShape(i)
        end
    end

    if self._imageManager then
        for i = 1, self._imageManager:GetImageCount() do
            self:_RenderImage(i)
        end
    end

    return self
end

--- Clear all render frames
function LoolibCanvasFrameMixin:_ClearAllFrames()
    self:_ClearDotFrames()
    self:_ClearShapeFrames()
    self:_ClearTextFrames()
    self:_ClearIconFrames()
    self:_ClearImageFrames()
end

--[[--------------------------------------------------------------------
    Public API - Save/Load
----------------------------------------------------------------------]]

--- Save canvas data to a table
-- @return table - Serialized canvas data
function LoolibCanvasFrameMixin:SaveData()
    return {
        dots = self._brushManager and self._brushManager:SerializeDots() or {},
        shapes = self._shapeManager and self._shapeManager:SerializeShapes() or {},
        texts = self._textManager and self._textManager:SerializeTexts() or {},
        icons = self._iconManager and self._iconManager:SerializeIcons() or {},
        images = self._imageManager and self._imageManager:SerializeImages() or {},
        groups = self._groupManager and self._groupManager.SerializeGroups
                 and self._groupManager:SerializeGroups() or {},
        view = self._zoomManager and self._zoomManager.SerializeView
               and self._zoomManager:SerializeView() or {},
    }
end

--- Load canvas data from a table
-- @param data table - Serialized canvas data
-- @return self - For method chaining
function LoolibCanvasFrameMixin:LoadData(data)
    if not data then return self end

    -- Deserialize all element types
    if self._brushManager and data.dots then
        self._brushManager:DeserializeDots(data.dots)
    end
    if self._shapeManager and data.shapes then
        self._shapeManager:DeserializeShapes(data.shapes)
    end
    if self._textManager and data.texts then
        self._textManager:DeserializeTexts(data.texts)
    end
    if self._iconManager and data.icons then
        self._iconManager:DeserializeIcons(data.icons)
    end
    if self._imageManager and data.images then
        self._imageManager:DeserializeImages(data.images)
    end

    -- Deserialize groups and view state
    if self._groupManager and self._groupManager.DeserializeGroups and data.groups then
        self._groupManager:DeserializeGroups(data.groups)
    end
    if self._zoomManager and self._zoomManager.DeserializeView and data.view then
        self._zoomManager:DeserializeView(data.view)
    end

    -- Refresh rendering
    self:Refresh()
    self:_UpdateTransform()

    return self
end

--[[--------------------------------------------------------------------
    Public API - Visibility
----------------------------------------------------------------------]]

--- Show the canvas frame
-- @return self - For method chaining
function LoolibCanvasFrameMixin:Show()
    if self._frame then
        self._frame:Show()
    end
    return self
end

--- Hide the canvas frame
-- @return self - For method chaining
function LoolibCanvasFrameMixin:Hide()
    if self._frame then
        self._frame:Hide()
    end
    return self
end

--- Toggle canvas visibility
-- @return self - For method chaining
function LoolibCanvasFrameMixin:Toggle()
    if self._frame then
        if self._frame:IsShown() then
            self:Hide()
        else
            self:Show()
        end
    end
    return self
end

--- Check if canvas is shown
-- @return boolean - True if visible
function LoolibCanvasFrameMixin:IsShown()
    return self._frame and self._frame:IsShown() or false
end

--[[--------------------------------------------------------------------
    Factory Function
----------------------------------------------------------------------]]

--- Create a new canvas frame instance
-- @param parent Frame - Parent frame (defaults to UIParent)
-- @return table - Initialized canvas frame
function LoolibCreateCanvasFrame(parent)
    local canvas = {}
    LoolibMixin(canvas, LoolibCanvasFrameMixin)
    canvas:OnLoad()
    canvas:BuildUI(parent)
    return canvas
end

--[[--------------------------------------------------------------------
    Module Registration
----------------------------------------------------------------------]]

Loolib:RegisterModule("CanvasFrame", {
    Mixin = LoolibCanvasFrameMixin,
    Create = LoolibCreateCanvasFrame,
})
