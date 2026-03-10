--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    CanvasZoom - Zoom and pan system for canvas views

    This module provides zooming (1x-7x) and panning functionality for
    canvas-based UIs. It handles coordinate transformations between screen
    space and canvas space, mouse wheel zooming centered on cursor position,
    and mouse drag panning.

    Inspired by MRT's VisNote which supports zoom levels: 1, 1.5, 2, 3, 4, 5, 6, 7.
    All canvas coordinates need to be transformed between screen space and
    canvas space based on current zoom and pan offset.

    Usage:
        -- Create a zoom controller
        local zoom = LoolibCreateCanvasZoom()
        zoom:SetCanvasSize(800, 600)
            :SetViewportSize(800, 600)

        -- Handle zoom
        zoom:SetZoom(2)  -- 2x zoom
        zoom:ZoomIn(mouseX, mouseY)  -- Zoom centered on mouse

        -- Handle panning
        zoom:StartPan(x, y)
        zoom:UpdatePan(x, y)
        zoom:EndPan()

        -- Transform coordinates
        local canvasX, canvasY = zoom:ScreenToCanvas(screenX, screenY)
        local screenX, screenY = zoom:CanvasToScreen(canvasX, canvasY)

        -- Fit content
        zoom:FitInView(x1, y1, x2, y2, padding)

    Events (requires CallbackRegistry mixin):
        OnZoomChanged(newZoom, oldZoom)
        OnPanChanged(panX, panY)
        OnPanStarted()
        OnPanEnded()
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

-- Local references for performance
local math = math
local ipairs = ipairs
local select = select

--[[--------------------------------------------------------------------
    CONSTANTS
----------------------------------------------------------------------]]

--- Available zoom levels (compatible with MRT VisNote)
--- @type table<number>
local LOOLIB_CANVAS_ZOOM_LEVELS = { 1, 1.5, 2, 3, 4, 5, 6, 7 }

--- Default zoom level
--- @type number
local LOOLIB_CANVAS_DEFAULT_ZOOM = 1

--- Minimum zoom level
--- @type number
local LOOLIB_CANVAS_MIN_ZOOM = 1

--- Maximum zoom level
--- @type number
local LOOLIB_CANVAS_MAX_ZOOM = 7

--[[--------------------------------------------------------------------
    CANVAS ZOOM MIXIN
----------------------------------------------------------------------]]

--- Canvas zoom and pan controller
--- @class LoolibCanvasZoomMixin
local LoolibCanvasZoomMixin = {}

--- Initialize the zoom controller
function LoolibCanvasZoomMixin:OnLoad()
    -- Zoom state
    self._zoomLevel = 1         -- Current zoom level (1-7)
    self._zoomIndex = 1         -- Index into LOOLIB_CANVAS_ZOOM_LEVELS

    -- Pan state (offset in canvas coordinates)
    self._panX = 0              -- Pan offset X
    self._panY = 0              -- Pan offset Y

    -- Canvas dimensions (logical size)
    self._canvasWidth = 800
    self._canvasHeight = 600

    -- Viewport dimensions (visible area on screen)
    self._viewportWidth = 800
    self._viewportHeight = 600

    -- Panning state
    self._isPanning = false
    self._panStartX = nil       -- Screen coordinates where pan started
    self._panStartY = nil
    self._panStartOffsetX = nil -- Pan offset when pan started
    self._panStartOffsetY = nil
end

--[[--------------------------------------------------------------------
    CANVAS AND VIEWPORT SIZE
----------------------------------------------------------------------]]

--- Set canvas dimensions
--- @param width number - Canvas width in logical pixels
--- @param height number - Canvas height in logical pixels
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:SetCanvasSize(width, height)
    self._canvasWidth = width
    self._canvasHeight = height
    self:ClampPan()
    return self
end

--- Get canvas dimensions
--- @return number, number - Canvas width and height
function LoolibCanvasZoomMixin:GetCanvasSize()
    return self._canvasWidth, self._canvasHeight
end

--- Set viewport dimensions
--- @param width number - Viewport width in screen pixels
--- @param height number - Viewport height in screen pixels
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:SetViewportSize(width, height)
    self._viewportWidth = width
    self._viewportHeight = height
    self:ClampPan()
    return self
end

--- Get viewport dimensions
--- @return number, number - Viewport width and height
function LoolibCanvasZoomMixin:GetViewportSize()
    return self._viewportWidth, self._viewportHeight
end

--[[--------------------------------------------------------------------
    ZOOM CONTROLS
----------------------------------------------------------------------]]

--- Get current zoom level
--- @return number - Current zoom level (1-7)
function LoolibCanvasZoomMixin:GetZoom()
    return self._zoomLevel
end

--- Get current zoom index
--- @return number - Index into LOOLIB_CANVAS_ZOOM_LEVELS
function LoolibCanvasZoomMixin:GetZoomIndex()
    return self._zoomIndex
end

--- Set zoom by level
--- @param level number - Zoom level to set (1-7)
--- @param centerX number|nil - Canvas X coordinate to center zoom on
--- @param centerY number|nil - Canvas Y coordinate to center zoom on
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:SetZoom(level, centerX, centerY)
    local oldZoom = self._zoomLevel

    -- Clamp to valid range
    level = math.max(LOOLIB_CANVAS_MIN_ZOOM, math.min(LOOLIB_CANVAS_MAX_ZOOM, level))

    -- Find closest zoom index
    local closestIndex = 1
    local closestDiff = math.huge
    for i, z in ipairs(LOOLIB_CANVAS_ZOOM_LEVELS) do
        local diff = math.abs(z - level)
        if diff < closestDiff then
            closestDiff = diff
            closestIndex = i
        end
    end

    self._zoomIndex = closestIndex
    self._zoomLevel = LOOLIB_CANVAS_ZOOM_LEVELS[closestIndex]

    -- Adjust pan to keep center point stable
    if centerX and centerY and oldZoom ~= self._zoomLevel then
        local zoomRatio = self._zoomLevel / oldZoom
        self._panX = centerX - (centerX - self._panX) * zoomRatio
        self._panY = centerY - (centerY - self._panY) * zoomRatio
    end

    self:ClampPan()

    if self.TriggerEvent then
        self:TriggerEvent("OnZoomChanged", self._zoomLevel, oldZoom)
    end

    return self
end

--- Set zoom by index
--- @param index number - Index into LOOLIB_CANVAS_ZOOM_LEVELS (1-8)
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:SetZoomIndex(index)
    index = math.max(1, math.min(#LOOLIB_CANVAS_ZOOM_LEVELS, index))
    return self:SetZoom(LOOLIB_CANVAS_ZOOM_LEVELS[index])
end

--- Zoom in to next level
--- @param centerX number|nil - Canvas X coordinate to center zoom on
--- @param centerY number|nil - Canvas Y coordinate to center zoom on
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:ZoomIn(centerX, centerY)
    if self._zoomIndex < #LOOLIB_CANVAS_ZOOM_LEVELS then
        local newLevel = LOOLIB_CANVAS_ZOOM_LEVELS[self._zoomIndex + 1]
        self:SetZoom(newLevel, centerX, centerY)
    end
    return self
end

--- Zoom out to previous level
--- @param centerX number|nil - Canvas X coordinate to center zoom on
--- @param centerY number|nil - Canvas Y coordinate to center zoom on
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:ZoomOut(centerX, centerY)
    if self._zoomIndex > 1 then
        local newLevel = LOOLIB_CANVAS_ZOOM_LEVELS[self._zoomIndex - 1]
        self:SetZoom(newLevel, centerX, centerY)
    end
    return self
end

--- Reset zoom to default (1x) and clear pan
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:ResetZoom()
    self:SetZoom(LOOLIB_CANVAS_DEFAULT_ZOOM)
    self._panX = 0
    self._panY = 0
    return self
end

--- Check if can zoom in
--- @return boolean - True if zoom in is available
function LoolibCanvasZoomMixin:CanZoomIn()
    return self._zoomIndex < #LOOLIB_CANVAS_ZOOM_LEVELS
end

--- Check if can zoom out
--- @return boolean - True if zoom out is available
function LoolibCanvasZoomMixin:CanZoomOut()
    return self._zoomIndex > 1
end

--[[--------------------------------------------------------------------
    PAN CONTROLS
----------------------------------------------------------------------]]

--- Set pan offset
--- @param x number - Pan offset X in canvas coordinates
--- @param y number - Pan offset Y in canvas coordinates
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:SetPan(x, y)
    self._panX = x
    self._panY = y
    self:ClampPan()

    if self.TriggerEvent then
        self:TriggerEvent("OnPanChanged", self._panX, self._panY)
    end

    return self
end

--- Get current pan offset
--- @return number, number - Pan offset X and Y in canvas coordinates
function LoolibCanvasZoomMixin:GetPan()
    return self._panX, self._panY
end

--- Pan by delta
--- @param deltaX number - Delta X to pan by
--- @param deltaY number - Delta Y to pan by
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:Pan(deltaX, deltaY)
    return self:SetPan(self._panX + deltaX, self._panY + deltaY)
end

--- Clamp pan to valid range (prevent panning beyond canvas edges)
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:ClampPan()
    local scaledWidth = self._canvasWidth * self._zoomLevel
    local scaledHeight = self._canvasHeight * self._zoomLevel

    -- Calculate max pan (don't allow panning beyond canvas edges)
    local maxPanX = math.max(0, (scaledWidth - self._viewportWidth) / 2)
    local maxPanY = math.max(0, (scaledHeight - self._viewportHeight) / 2)

    self._panX = math.max(-maxPanX, math.min(maxPanX, self._panX))
    self._panY = math.max(-maxPanY, math.min(maxPanY, self._panY))

    return self
end

--[[--------------------------------------------------------------------
    MOUSE WHEEL ZOOM
----------------------------------------------------------------------]]

--- Handle mouse wheel for zooming
--- @param delta number - Wheel delta (positive = up/in, negative = down/out)
--- @param mouseX number - Mouse X in screen coordinates
--- @param mouseY number - Mouse Y in screen coordinates
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:HandleMouseWheel(delta, mouseX, mouseY)
    -- Convert mouse position to canvas coordinates first
    local canvasX, canvasY = self:ScreenToCanvas(mouseX, mouseY)

    if delta > 0 then
        self:ZoomIn(canvasX, canvasY)
    else
        self:ZoomOut(canvasX, canvasY)
    end

    return self
end

--[[--------------------------------------------------------------------
    MOUSE PANNING
----------------------------------------------------------------------]]

--- Start panning with mouse
--- @param screenX number - Screen X coordinate where pan started
--- @param screenY number - Screen Y coordinate where pan started
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:StartPan(screenX, screenY)
    self._isPanning = true
    self._panStartX = screenX
    self._panStartY = screenY
    self._panStartOffsetX = self._panX
    self._panStartOffsetY = self._panY

    if self.TriggerEvent then
        self:TriggerEvent("OnPanStarted")
    end

    return self
end

--- Update panning based on mouse movement
--- @param screenX number - Current screen X coordinate
--- @param screenY number - Current screen Y coordinate
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:UpdatePan(screenX, screenY)
    if not self._isPanning then return self end

    local deltaX = (screenX - self._panStartX) / self._zoomLevel
    local deltaY = (screenY - self._panStartY) / self._zoomLevel

    self:SetPan(self._panStartOffsetX + deltaX, self._panStartOffsetY + deltaY)

    return self
end

--- End panning
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:EndPan()
    self._isPanning = false
    self._panStartX = nil
    self._panStartY = nil
    self._panStartOffsetX = nil
    self._panStartOffsetY = nil

    if self.TriggerEvent then
        self:TriggerEvent("OnPanEnded")
    end

    return self
end

--- Check if currently panning
--- @return boolean - True if panning is active
function LoolibCanvasZoomMixin:IsPanning()
    return self._isPanning
end

--[[--------------------------------------------------------------------
    COORDINATE TRANSFORMATIONS
----------------------------------------------------------------------]]

--- Convert screen coordinates to canvas coordinates
--- @param screenX number - Screen X coordinate
--- @param screenY number - Screen Y coordinate
--- @return number, number - Canvas X and Y coordinates
function LoolibCanvasZoomMixin:ScreenToCanvas(screenX, screenY)
    local canvasX = (screenX - self._viewportWidth / 2) / self._zoomLevel - self._panX + self._canvasWidth / 2
    local canvasY = (screenY - self._viewportHeight / 2) / self._zoomLevel - self._panY + self._canvasHeight / 2
    return canvasX, canvasY
end

--- Convert canvas coordinates to screen coordinates
--- @param canvasX number - Canvas X coordinate
--- @param canvasY number - Canvas Y coordinate
--- @return number, number - Screen X and Y coordinates
function LoolibCanvasZoomMixin:CanvasToScreen(canvasX, canvasY)
    local screenX = (canvasX - self._canvasWidth / 2 + self._panX) * self._zoomLevel + self._viewportWidth / 2
    local screenY = (canvasY - self._canvasHeight / 2 + self._panY) * self._zoomLevel + self._viewportHeight / 2
    return screenX, screenY
end

--- Get visible canvas region
--- @return number, number, number, number - X, Y, width, height of visible region in canvas coordinates
function LoolibCanvasZoomMixin:GetVisibleRegion()
    local x1, y1 = self:ScreenToCanvas(0, 0)
    local x2, y2 = self:ScreenToCanvas(self._viewportWidth, self._viewportHeight)
    return x1, y1, x2 - x1, y2 - y1
end

--[[--------------------------------------------------------------------
    VIEW MANIPULATION
----------------------------------------------------------------------]]

--- Center view on a canvas point
--- @param canvasX number - Canvas X coordinate to center on
--- @param canvasY number - Canvas Y coordinate to center on
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:CenterOn(canvasX, canvasY)
    self._panX = canvasX - self._canvasWidth / 2
    self._panY = canvasY - self._canvasHeight / 2
    self:ClampPan()

    if self.TriggerEvent then
        self:TriggerEvent("OnPanChanged", self._panX, self._panY)
    end

    return self
end

--- Fit content in view
--- @param x1 number - Content bounding box min X
--- @param y1 number - Content bounding box min Y
--- @param x2 number - Content bounding box max X
--- @param y2 number - Content bounding box max Y
--- @param padding number|nil - Padding around content (default 20)
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:FitInView(x1, y1, x2, y2, padding)
    padding = padding or 20

    local contentWidth = (x2 - x1) + padding * 2
    local contentHeight = (y2 - y1) + padding * 2

    local zoomX = self._viewportWidth / contentWidth
    local zoomY = self._viewportHeight / contentHeight
    local newZoom = math.min(zoomX, zoomY)

    -- Find closest zoom level that fits
    for i = #LOOLIB_CANVAS_ZOOM_LEVELS, 1, -1 do
        if LOOLIB_CANVAS_ZOOM_LEVELS[i] <= newZoom then
            self:SetZoom(LOOLIB_CANVAS_ZOOM_LEVELS[i])
            break
        end
    end

    -- Center on content
    local centerX = (x1 + x2) / 2
    local centerY = (y1 + y2) / 2
    self:CenterOn(centerX, centerY)

    return self
end

--[[--------------------------------------------------------------------
    SERIALIZATION
----------------------------------------------------------------------]]

--- Serialize current view state
--- @return table - Serialized view data
function LoolibCanvasZoomMixin:SerializeView()
    return {
        z = self._zoomLevel,
        px = self._panX,
        py = self._panY,
    }
end

--- Deserialize view state
--- @param data table - Serialized view data
--- @return LoolibCanvasZoomMixin
function LoolibCanvasZoomMixin:DeserializeView(data)
    if not data then return self end

    self._zoomLevel = data.z or 1
    self._panX = data.px or 0
    self._panY = data.py or 0

    -- Update zoom index
    for i, z in ipairs(LOOLIB_CANVAS_ZOOM_LEVELS) do
        if z == self._zoomLevel then
            self._zoomIndex = i
            break
        end
    end

    return self
end

--[[--------------------------------------------------------------------
    FACTORY
----------------------------------------------------------------------]]

--- Create a new canvas zoom controller
--- @return LoolibCanvasZoomMixin
local function LoolibCreateCanvasZoom()
    local zoom = {}
    Loolib.Mixin(zoom, LoolibCanvasZoomMixin)
    zoom:OnLoad()
    return zoom
end

--[[--------------------------------------------------------------------
    MODULE REGISTRATION
----------------------------------------------------------------------]]

Loolib:RegisterModule("CanvasZoom", {
    Mixin = LoolibCanvasZoomMixin,
    LEVELS = LOOLIB_CANVAS_ZOOM_LEVELS,
    DEFAULT_ZOOM = LOOLIB_CANVAS_DEFAULT_ZOOM,
    MIN_ZOOM = LOOLIB_CANVAS_MIN_ZOOM,
    MAX_ZOOM = LOOLIB_CANVAS_MAX_ZOOM,
    Create = LoolibCreateCanvasZoom,
})
