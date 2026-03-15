--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    WidgetMod - Fluent API Mixin for Widgets

    Inspired by MRT's Mod() pattern, this mixin provides chainable methods
    for configuring any WoW frame or widget.

    Usage:
        local frame = LoolibCreateModFrame("Frame", parent)
        frame:Size(200, 30):Point("CENTER"):Alpha(0.8):Tooltip("Help")

        -- Or apply to existing frame:
        LoolibApplyWidgetMod(existingFrame)
        existingFrame:Size(100, 100):Point("TOPLEFT", 10, -10)
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local LoolibMixin = assert(Loolib.Mixin, "Loolib.Mixin is required for WidgetMod")

--[[--------------------------------------------------------------------
    LoolibWidgetModMixin - Fluent API for Widgets
----------------------------------------------------------------------]]

---@class LoolibWidgetModMixin : Frame
---@field SetText fun(self: any, text: string)?  -- Button, EditBox, FontString
---@field SetScale fun(self: any, scale: number)
---@field HasScript fun(self: any, scriptType: string): boolean
---@field GetScript fun(self: any, scriptType: string): function?
---@field EnableMouseWheel fun(self: any, enable: boolean)
---@field Enable fun(self: any)
---@field Disable fun(self: any)
local LoolibWidgetModMixin = {}

-- ============================================================
-- SIZING & POSITIONING (all return self)
-- ============================================================

--- Set size with optional height (defaults to width if not provided)
-- @param width number - Width in pixels
-- @param height number|nil - Height in pixels (defaults to width)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Size(width, height)
    self:SetSize(width, height or width)
    return self
end

--- Set width only
-- @param width number - Width in pixels
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Width(width)
    self:SetWidth(width)
    return self
end

--- Set height only
-- @param height number - Height in pixels
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Height(height)
    self:SetHeight(height)
    return self
end

--- Smart SetPoint with multiple argument patterns
-- Supports:
--   :Point("CENTER") - anchor to parent center
--   :Point("TOPLEFT", 10, -10) - anchor with offsets
--   :Point("TOPLEFT", otherFrame, 10, -10) - anchor to other frame
--   :Point("TOPLEFT", otherFrame, "BOTTOMLEFT", 0, -5) - full anchor
--   :Point(otherFrame) - SetAllPoints to frame
-- @param ... - Variable arguments based on pattern
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Point(...)
    local arg1, arg2, arg3, arg4, arg5 = ...

    -- Special case: 'x' means self:GetParent()
    if arg1 == 'x' then
        arg1 = self:GetParent()
    end
    if arg2 == 'x' then
        arg2 = self:GetParent()
    end

    -- Pattern 1: Two numbers -> "TOPLEFT", x, y
    if type(arg1) == 'number' and type(arg2) == 'number' then
        self:SetPoint("TOPLEFT", arg1, arg2)
        return self
    end

    -- Pattern 2: Single frame -> SetAllPoints(frame)
    if type(arg1) == 'table' and not arg2 then
        self:SetAllPoints(arg1)
        return self
    end

    -- Pattern 3: point, x, y
    if type(arg2) == 'number' and not arg3 then
        self:SetPoint(arg1, arg2, 0)
        return self
    end

    -- Pattern 4: point, x, y (with y specified)
    if type(arg2) == 'number' and type(arg3) == 'number' and not arg4 then
        self:SetPoint(arg1, arg2, arg3)
        return self
    end

    -- Pattern 5: point, frame, x, y -> point, frame, point, x, y
    if type(arg2) == 'table' and type(arg3) == 'number' and not arg5 then
        self:SetPoint(arg1, arg2, arg1, arg3, arg4 or 0)
        return self
    end

    -- Pattern 6: Full form - point, frame, relativePoint, x, y
    if arg5 then
        self:SetPoint(arg1, arg2, arg3, arg4, arg5)
    elseif arg4 then
        self:SetPoint(arg1, arg2, arg3, arg4)
    elseif arg3 then
        self:SetPoint(arg1, arg2, arg3)
    elseif arg2 then
        self:SetPoint(arg1, arg2)
    else
        self:SetPoint(arg1)
    end

    return self
end

--- Clear all points and set a new point
-- @param ... - Same arguments as Point()
-- @return Frame - self for chaining
function LoolibWidgetModMixin:NewPoint(...)
    self:ClearAllPoints()
    return self:Point(...)
end

--- Clear all anchor points
-- @return Frame - self for chaining
function LoolibWidgetModMixin:ClearPoints()
    self:ClearAllPoints()
    return self
end

-- ============================================================
-- APPEARANCE (all return self)
-- ============================================================

--- Set alpha transparency
-- @param alpha number - Alpha value (0 = transparent, 1 = opaque)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Alpha(alpha)
    self:SetAlpha(alpha)
    return self
end

--- Set scale
-- @param scale number - Scale multiplier
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Scale(scale)
    self:SetScale(scale)
    return self
end

--- Conditional show/hide
-- @param bool boolean - True to show, false to hide
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Shown(bool)
    if bool then
        self:Show()
    else
        self:Hide()
    end
    return self
end

--- Hide the frame
-- @return Frame - self for chaining
function LoolibWidgetModMixin:HideFrame()
    self:Hide()
    return self
end

--- Show the frame
-- @return Frame - self for chaining
function LoolibWidgetModMixin:ShowFrame()
    self:Show()
    return self
end

--- Set frame level
-- @param level number - Frame level
-- @return Frame - self for chaining
function LoolibWidgetModMixin:FrameLevel(level)
    self:SetFrameLevel(level)
    return self
end

--- Set frame strata
-- @param strata string - Frame strata ("BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP")
-- @return Frame - self for chaining
function LoolibWidgetModMixin:FrameStrata(strata)
    self:SetFrameStrata(strata)
    return self
end

-- ============================================================
-- SCRIPTS/HANDLERS (all return self)
-- ============================================================

--- Set OnClick script handler
-- @param handler function - Click handler function(self, button, down)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnClick(handler)
    if self.HasScript and self:HasScript("OnClick") then
        self:SetScript("OnClick", handler)
    end
    return self
end

--- Set OnEnter script handler
-- @param handler function - Mouse enter handler function(self, motion)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnEnter(handler)
    if self.HasScript and self:HasScript("OnEnter") then
        self:SetScript("OnEnter", handler)
    end
    return self
end

--- Set OnLeave script handler
-- @param handler function - Mouse leave handler function(self, motion)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnLeave(handler)
    if self.HasScript and self:HasScript("OnLeave") then
        self:SetScript("OnLeave", handler)
    end
    return self
end

--- Set OnShow script handler with optional skip first run
-- @param handler function - Show handler function(self)
-- @param skipFirstRun boolean - If true, don't execute handler immediately
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnShow(handler, skipFirstRun)
    if not handler then
        if self.HasScript and self:HasScript("OnShow") then
            self:SetScript("OnShow", nil)
        end
        return self
    end

    if self.HasScript and self:HasScript("OnShow") then
        if skipFirstRun then
            -- Wrap handler to skip first invocation
            local hasRun = false
            self:SetScript("OnShow", function(...)
                if hasRun then
                    handler(...)
                else
                    hasRun = true
                end
            end)
        else
            self:SetScript("OnShow", handler)
            -- Run immediately if not skipping
            if self:IsShown() then
                handler(self)
            end
        end
    end

    return self
end

--- Set OnHide script handler
-- @param handler function - Hide handler function(self)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnHide(handler)
    if self.HasScript and self:HasScript("OnHide") then
        self:SetScript("OnHide", handler)
    end
    return self
end

--- Set OnUpdate script handler
-- @param handler function - Update handler function(self, elapsed)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnUpdate(handler)
    if self.HasScript and self:HasScript("OnUpdate") then
        self:SetScript("OnUpdate", handler)
    end
    return self
end

--- Set OnMouseDown script handler
-- @param handler function - Mouse down handler function(self, button)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnMouseDown(handler)
    if self.HasScript and self:HasScript("OnMouseDown") then
        self:SetScript("OnMouseDown", handler)
    end
    return self
end

--- Set OnMouseUp script handler
-- @param handler function - Mouse up handler function(self, button)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnMouseUp(handler)
    if self.HasScript and self:HasScript("OnMouseUp") then
        self:SetScript("OnMouseUp", handler)
    end
    return self
end

--- Set OnMouseWheel script handler and enable mouse wheel
-- @param handler function - Mouse wheel handler function(self, delta)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnMouseWheel(handler)
    if self.HasScript and self:HasScript("OnMouseWheel") then
        self:EnableMouseWheel(true)
        self:SetScript("OnMouseWheel", handler)
    end
    return self
end

--- Set OnDragStart script handler
-- @param handler function - Drag start handler function(self, button)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnDragStart(handler)
    if self.HasScript and self:HasScript("OnDragStart") then
        self:SetScript("OnDragStart", handler)
    end
    return self
end

--- Set OnDragStop script handler
-- @param handler function - Drag stop handler function(self)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnDragStop(handler)
    if self.HasScript and self:HasScript("OnDragStop") then
        self:SetScript("OnDragStop", handler)
    end
    return self
end

--- Set OnEvent script handler
-- @param handler function - Event handler function(self, event, ...)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnEvent(handler)
    if self.HasScript and self:HasScript("OnEvent") then
        self:SetScript("OnEvent", handler)
    end
    return self
end

--- Set OnValueChanged script handler (for sliders, scrollbars)
-- @param handler function - Value changed handler function(self, value)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnValueChanged(handler)
    if self.HasScript and self:HasScript("OnValueChanged") then
        self:SetScript("OnValueChanged", handler)
    end
    return self
end

--- Set OnTextChanged script handler (for editboxes)
-- @param handler function - Text changed handler function(self, userInput)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnTextChanged(handler)
    if self.HasScript and self:HasScript("OnTextChanged") then
        self:SetScript("OnTextChanged", handler)
    end
    return self
end

--- Set OnEnterPressed script handler (for editboxes)
-- @param handler function - Enter pressed handler function(self)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnEnterPressed(handler)
    if self.HasScript and self:HasScript("OnEnterPressed") then
        self:SetScript("OnEnterPressed", handler)
    end
    return self
end

--- Set OnEscapePressed script handler (for editboxes)
-- @param handler function - Escape pressed handler function(self)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:OnEscapePressed(handler)
    if self.HasScript and self:HasScript("OnEscapePressed") then
        self:SetScript("OnEscapePressed", handler)
    end
    return self
end

-- ============================================================
-- TOOLTIP SUPPORT (all return self)
-- ============================================================

--- Add tooltip to widget
-- Uses HookScript to avoid clobbering existing OnEnter/OnLeave handlers.
-- Subsequent calls update the tooltip text without re-hooking.
-- @param text string|table - Tooltip text or {title, line1, line2, ...} for multi-line
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Tooltip(text)
    if type(text) == "table" then
        -- Multi-line tooltip
        self.tooltipLines = text
        self.tooltipText = nil
    else
        -- Single line tooltip
        self.tooltipText = text
        self.tooltipLines = nil
    end

    -- INTERNAL: Only hook once; subsequent calls just update the data fields
    if not self._tooltipHooked then
        self._tooltipHooked = true

        if self.HasScript and self:HasScript("OnEnter") then
            self:HookScript("OnEnter", function(frame)
                if not frame.tooltipText and not frame.tooltipLines then
                    return
                end

                GameTooltip:SetOwner(frame, frame.tooltipAnchor or "ANCHOR_RIGHT")

                if frame.tooltipLines then
                    for i, line in ipairs(frame.tooltipLines) do
                        if i == 1 then
                            GameTooltip:SetText(line, 1, 1, 1, 1, true)
                        else
                            GameTooltip:AddLine(line, nil, nil, nil, true)
                        end
                    end
                else
                    GameTooltip:SetText(frame.tooltipText, 1, 1, 1, 1, true)
                end

                GameTooltip:Show()
            end)
        end

        if self.HasScript and self:HasScript("OnLeave") then
            self:HookScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
    end

    return self
end

--- Set tooltip anchor point
-- @param anchor string - Anchor point (e.g., "ANCHOR_RIGHT", "ANCHOR_TOP", "ANCHOR_CURSOR")
-- @return Frame - self for chaining
function LoolibWidgetModMixin:TooltipAnchor(anchor)
    self.tooltipAnchor = anchor
    return self
end

-- ============================================================
-- UTILITY METHODS (all return self)
-- ============================================================

--- Execute a function with self and return self
-- Useful for inline configuration
-- @param func function - Function to execute (receives self, ...)
-- @param ... - Additional arguments to pass
-- @return Frame - self for chaining
-- Usage: widget:Run(function(w) w.customProp = true end)
function LoolibWidgetModMixin:Run(func, ...)
    func(self, ...)
    return self
end

--- Enable the widget (for buttons, editboxes, etc.)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:EnableWidget()
    if self.Enable then
        self:Enable()
    end
    return self
end

--- Disable the widget (for buttons, editboxes, etc.)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:DisableWidget()
    if self.Disable then
        self:Disable()
    end
    return self
end

--- Conditional enable/disable
-- @param enabled boolean - True to enable, false to disable
-- @return Frame - self for chaining
function LoolibWidgetModMixin:SetEnabled(enabled)
    if enabled then
        return self:EnableWidget()
    else
        return self:DisableWidget()
    end
end

--- Set text (for buttons, editboxes, font strings)
-- @param text string - Text to set
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Text(text)
    if self.SetText then
        self:SetText(text)
    end
    return self
end

--- Register for mouse events
-- @param enable boolean - True to enable mouse (default true)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Mouse(enable)
    if self.EnableMouse then
        self:EnableMouse(enable ~= false)
    end
    return self
end

--- Register for mouse wheel events
-- @param enable boolean - True to enable mouse wheel (default true)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:MouseWheel(enable)
    if self.EnableMouseWheel then
        self:EnableMouseWheel(enable ~= false)
    end
    return self
end

--- Set movable and enable dragging
-- @param button string - Mouse button for dragging (default "LeftButton")
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Movable(button)
    if self.SetMovable and self.RegisterForDrag then
        self:SetMovable(true)
        self:EnableMouse(true)
        self:RegisterForDrag(button or "LeftButton")

        -- Set up default drag handlers if not already set
        if not self:GetScript("OnDragStart") then
            self:SetScript("OnDragStart", function(frame)
                frame:StartMoving()
            end)
        end

        if not self:GetScript("OnDragStop") then
            self:SetScript("OnDragStop", function(frame)
                frame:StopMovingOrSizing()
            end)
        end
    end
    return self
end

--- Set clamped to screen
-- @param clamped boolean - True to clamp (default true)
-- @return Frame - self for chaining
function LoolibWidgetModMixin:ClampedToScreen(clamped)
    if self.SetClampedToScreen then
        self:SetClampedToScreen(clamped ~= false)
    end
    return self
end

--- Set parent frame
-- @param parent Frame - New parent frame
-- @return Frame - self for chaining
function LoolibWidgetModMixin:Parent(parent)
    self:SetParent(parent)
    return self
end

-- ============================================================
-- FACTORY FUNCTIONS
-- ============================================================

--- Apply WidgetMod mixin to any frame
-- @param frame Frame - The frame to enhance
-- @return Frame - The same frame with WidgetMod methods
local function LoolibApplyWidgetMod(frame)
    LoolibMixin(frame, LoolibWidgetModMixin)
    return frame
end

--- Create a frame with WidgetMod already applied
-- @param frameType string - Frame type ("Frame", "Button", "EditBox", etc.)
-- @param parent Frame|nil - Parent frame
-- @param template string|nil - XML template name
-- @return Frame - New frame with WidgetMod methods
-- Usage: local f = LoolibCreateModFrame("Frame", UIParent):Size(100, 100):Point("CENTER")
local function LoolibCreateModFrame(frameType, parent, template)
    local frame = CreateFrame(frameType, nil, parent, template)
    return LoolibApplyWidgetMod(frame)
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

Loolib:RegisterModule("Widgets.WidgetMod", {
    Mixin = LoolibWidgetModMixin,
    Apply = LoolibApplyWidgetMod,
    Create = LoolibCreateModFrame,
})
