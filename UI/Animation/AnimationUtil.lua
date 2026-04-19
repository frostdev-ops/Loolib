--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    AnimationUtil - Single-updater tween engine with richer easing than
    Blizzard's native AnimationGroup.

    Modelled on ToxiUI's Core/Animations.lua: one OnUpdate frame drives
    every active animation through Penner easing curves. Group scheduling
    mirrors AnimationGroup semantics (orders fire sequentially, items
    within an order run in parallel).

    API:
        local group = AnimationUtil:CreateGroup(frame)
        group:CreateAnimation("fade", {
            duration = 0.3,
            easing   = "outCubic",
            from     = 0,
            to       = 1,
            startDelay = 0,
            order    = 1,
            onFinished = function(anim) ... end,
        })
        group:Play()
        group:Stop()
        group:Pause()
        group:SetOnFinished(fn)

    Animation types:
        fade       target = frame,    property = alpha      (0..1)
        scale      target = frame,    property = scale
        width      target = frame,    property = width
        height     target = frame,    property = height
        move       target = frame,    property = {x, y}     delta offsets
        color      target = texture,  property = {r,g,b,a}  (VertexColor)
        progress   target = statusbar,property = value
        flipbook   target = texture,  property = texCoord   sprite sheet
        sleep      no target, just delays

    Dependencies (must be loaded before this file):
    - Core/Loolib.lua
    - UI/Animation/Easing.lua
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local Animation = Loolib.Animation or Loolib:GetOrCreateModule("Animation")
local Easing = assert(Loolib.Easing or (Animation.Easing), "Loolib.Easing is required for AnimationUtil")

local AnimationUtil = Animation.Util or Loolib:GetModule("Animation.Util") or {}

-- Cache globals
local type = type
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local tremove = table.remove
local tinsert = table.insert
local tsort = table.sort
local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local CreateFrame = CreateFrame

local DEFAULT_EASING = "outCubic"

--[[--------------------------------------------------------------------
    Internal: Easing resolution
----------------------------------------------------------------------]]

local function resolveEasing(name)
    if type(name) == "function" then
        return name
    end
    if type(name) == "string" and Easing[name] then
        return Easing[name]
    end
    return Easing[DEFAULT_EASING] or Easing.linear
end

--[[--------------------------------------------------------------------
    Internal: Property apply per-type
----------------------------------------------------------------------]]

local function applyFade(target, from, to, t)
    if type(target) ~= "table" or type(target.SetAlpha) ~= "function" then return end
    target:SetAlpha(from + (to - from) * t)
end

local function applyScale(target, from, to, t)
    if type(target) ~= "table" or type(target.SetScale) ~= "function" then return end
    target:SetScale(from + (to - from) * t)
end

local function applyWidth(target, from, to, t)
    if type(target) ~= "table" or type(target.SetWidth) ~= "function" then return end
    target:SetWidth(from + (to - from) * t)
end

local function applyHeight(target, from, to, t)
    if type(target) ~= "table" or type(target.SetHeight) ~= "function" then return end
    target:SetHeight(from + (to - from) * t)
end

local function applyMove(anim, t)
    local target = anim.target
    if type(target) ~= "table" or type(target.ClearAllPoints) ~= "function" then return end
    local from = anim.from
    local to = anim.to
    if not from or not to or not anim.baseAnchor then return end
    local dx = from[1] + (to[1] - from[1]) * t
    local dy = from[2] + (to[2] - from[2]) * t
    local base = anim.baseAnchor
    target:ClearAllPoints()
    target:SetPoint(base.point, base.relativeTo, base.relativePoint, base.x + dx, base.y + dy)
end

local function applyColor(target, from, to, t, sink)
    if type(target) ~= "table" then return end
    local r = from[1] + (to[1] - from[1]) * t
    local g = from[2] + (to[2] - from[2]) * t
    local b = from[3] + (to[3] - from[3]) * t
    local a = (from[4] or 1) + ((to[4] or 1) - (from[4] or 1)) * t

    if sink == "backdropColor" and type(target.SetBackdropColor) == "function" then
        target:SetBackdropColor(r, g, b, a)
        return
    end
    if sink == "backdropBorderColor" and type(target.SetBackdropBorderColor) == "function" then
        target:SetBackdropBorderColor(r, g, b, a)
        return
    end
    if sink == "textColor" and type(target.SetTextColor) == "function" then
        target:SetTextColor(r, g, b, a)
        return
    end

    if type(target.SetVertexColor) == "function" then
        target:SetVertexColor(r, g, b, a)
    elseif type(target.SetColorTexture) == "function" then
        target:SetColorTexture(r, g, b, a)
    elseif type(target.SetStatusBarColor) == "function" then
        target:SetStatusBarColor(r, g, b, a)
    elseif type(target.SetBackdropColor) == "function" then
        target:SetBackdropColor(r, g, b, a)
    elseif type(target.SetTextColor) == "function" then
        target:SetTextColor(r, g, b, a)
    end
end

local function applyProgress(target, from, to, t)
    if type(target) ~= "table" or type(target.SetValue) ~= "function" then return end
    target:SetValue(from + (to - from) * t)
end

local function applyFlipbook(anim, t)
    local target = anim.target
    if type(target) ~= "table" or type(target.SetTexCoord) ~= "function" then return end
    local opts = anim.flipbook
    if not opts then return end
    local totalFrames = opts.frames or 1
    local cols = opts.cols or totalFrames
    local rows = opts.rows or 1
    local frameIdx = math_min(totalFrames - 1, math_floor(t * totalFrames))
    local col = frameIdx % cols
    local row = math_floor(frameIdx / cols)
    local u1 = col / cols
    local v1 = row / rows
    local u2 = (col + 1) / cols
    local v2 = (row + 1) / rows
    target:SetTexCoord(u1, u2, v1, v2)
end

local function tickAnimation(anim, t)
    local kind = anim.kind
    if kind == "fade" then
        applyFade(anim.target, anim.from, anim.to, t)
    elseif kind == "scale" then
        applyScale(anim.target, anim.from, anim.to, t)
    elseif kind == "width" then
        applyWidth(anim.target, anim.from, anim.to, t)
    elseif kind == "height" then
        applyHeight(anim.target, anim.from, anim.to, t)
    elseif kind == "move" then
        applyMove(anim, t)
    elseif kind == "color" then
        applyColor(anim.target, anim.from, anim.to, t, anim.sink)
    elseif kind == "progress" then
        applyProgress(anim.target, anim.from, anim.to, t)
    elseif kind == "flipbook" then
        applyFlipbook(anim, t)
    end
end

--[[--------------------------------------------------------------------
    Updater frame (single, shared)
----------------------------------------------------------------------]]

local active = {}
local updater

local function ensureUpdater()
    if updater then return end
    updater = CreateFrame("Frame", "LoolibAnimationUpdater", UIParent)
    updater:Hide()
    updater:SetScript("OnUpdate", function(_, elapsed)
        for i = #active, 1, -1 do
            local anim = active[i]
            if anim._stopped then
                tremove(active, i)
            else
                local tickElapsed = elapsed
                if anim.delayRemaining and anim.delayRemaining > 0 then
                    local newDelay = anim.delayRemaining - elapsed
                    if newDelay > 0 then
                        anim.delayRemaining = newDelay
                        tickElapsed = nil
                    else
                        anim.delayRemaining = 0
                        tickElapsed = -newDelay
                    end
                end

                if tickElapsed ~= nil then
                    anim.elapsed = (anim.elapsed or 0) + tickElapsed
                    local duration = anim.duration or 0
                    local capped = math_min(anim.elapsed, duration)
                    local t
                    if duration <= 0 then
                        t = 1
                    else
                        local ease = anim.easingFn
                        t = ease(capped, 0, 1, duration)
                        if t ~= t then t = 1 end -- NaN guard
                    end

                    tickAnimation(anim, t)

                    if (anim.elapsed >= duration) or duration <= 0 then
                        tremove(active, i)
                        anim._running = false
                        -- Final-tick snap: eased curves should return exactly c+b
                        -- at t=d, but float precision can drift. For engine-native
                        -- kinds with a scalar `to`, snap the target region to the
                        -- exact endpoint so the button rests at 1.0 (not 0.9999...)
                        -- after a tween. Drift is imperceptible per tween but
                        -- visible after many interrupted cycles.
                        tickAnimation(anim, 1)
                        if anim.onFinished then
                            local ok, err = pcall(anim.onFinished, anim)
                            if not ok then Loolib:Error("AnimationUtil: onFinished error: " .. tostring(err)) end
                        end
                        -- Skip engine-finish if the onFinished callback stopped
                        -- the group; prevents a cancelled group from starting
                        -- its next order.
                        if anim._onEngineFinish and not anim._stopped then
                            anim._onEngineFinish(anim)
                        end
                    end
                end
            end
        end

        if #active == 0 then
            updater:Hide()
        end
    end)
end

-- INTERNAL: Remove every entry for `anim` from `active`. Called by both
-- `stopAnim` and `scheduleAnim` to guarantee no duplicate entries can ever
-- coexist for the same anim table. Without this, a rapid Stop+Play cycle
-- can leave a stopped entry AND a freshly-scheduled entry in `active`
-- pointing to the same table -- the updater would tick both, advancing
-- `anim.elapsed` at 2x (or Nx) speed.
local function removeAnimFromActive(anim)
    for i = #active, 1, -1 do
        if active[i] == anim then
            tremove(active, i)
        end
    end
end

local function scheduleAnim(anim)
    ensureUpdater()
    removeAnimFromActive(anim)
    anim.elapsed = 0
    anim.delayRemaining = anim.startDelay or 0
    anim._running = true
    anim._stopped = nil
    tinsert(active, anim)
    updater:Show()
end

local function stopAnim(anim)
    anim._stopped = true
    anim._running = false
    removeAnimFromActive(anim)
end

--[[--------------------------------------------------------------------
    Animation object
----------------------------------------------------------------------]]

local AnimationMixin = {}
AnimationMixin.__index = AnimationMixin

function AnimationMixin:SetFrom(v) self.from = v end
function AnimationMixin:SetTo(v) self.to = v end
function AnimationMixin:SetDuration(v) self.duration = v end
function AnimationMixin:SetEasing(name) self.easingFn = resolveEasing(name); self.easing = name end
function AnimationMixin:SetStartDelay(v) self.startDelay = v end
function AnimationMixin:SetOrder(v) self.order = v end
function AnimationMixin:SetOnFinished(fn) self.onFinished = fn end
function AnimationMixin:IsPlaying() return self._running == true end

--[[--------------------------------------------------------------------
    Group object
----------------------------------------------------------------------]]

local GroupMixin = {}
GroupMixin.__index = GroupMixin

local function newAnimation(group, kind, opts)
    opts = opts or {}
    local anim = setmetatable({}, AnimationMixin)
    anim.kind = kind
    anim.group = group
    anim.target = opts.target or group.parent
    anim.from = opts.from
    anim.to = opts.to
    anim.duration = opts.duration or 0.25
    anim.startDelay = opts.startDelay or 0
    anim.order = opts.order or 1
    anim.easing = opts.easing or DEFAULT_EASING
    anim.easingFn = resolveEasing(opts.easing)
    anim.onFinished = opts.onFinished
    anim.flipbook = opts.flipbook
    anim.baseAnchor = opts.baseAnchor
    anim.sink = opts.sink

    -- Auto-capture current value as `from` if omitted (per type)
    local target = anim.target
    if kind == "fade" and anim.from == nil and type(target) == "table" and type(target.GetAlpha) == "function" then
        anim.from = target:GetAlpha()
    elseif kind == "scale" and anim.from == nil and type(target) == "table" and type(target.GetScale) == "function" then
        anim.from = target:GetScale()
    elseif kind == "width" and anim.from == nil and type(target) == "table" and type(target.GetWidth) == "function" then
        anim.from = target:GetWidth()
    elseif kind == "height" and anim.from == nil and type(target) == "table" and type(target.GetHeight) == "function" then
        anim.from = target:GetHeight()
    elseif kind == "move" then
        if type(target) == "table" and type(target.GetPoint) == "function" and not anim.baseAnchor then
            local p, relTo, relP, x, y = target:GetPoint(1)
            if p then
                anim.baseAnchor = { point = p, relativeTo = relTo, relativePoint = relP, x = x or 0, y = y or 0 }
            end
        end
        anim.from = anim.from or { 0, 0 }
        anim.to = anim.to or { 0, 0 }
    end

    tinsert(group.animations, anim)
    return anim
end

function GroupMixin:CreateAnimation(kind, opts)
    if type(kind) ~= "string" then
        error("AnimationUtil: group:CreateAnimation: 'kind' must be a string", 2)
    end
    return newAnimation(self, kind, opts)
end

function GroupMixin:SetOnFinished(fn)
    self.onFinished = fn
end

function GroupMixin:SetLooping(mode)
    -- "NONE" (default), "REPEAT" (restart), "BOUNCE" (alternate direction not supported per-anim)
    self.looping = mode or "NONE"
end

local function playOrder(group, order)
    local batch = group._byOrder[order]
    if not batch or #batch == 0 then
        group._currentOrder = nil
        if group.onFinished then
            local ok, err = pcall(group.onFinished, group)
            if not ok then Loolib:Error("AnimationUtil: group onFinished error: " .. tostring(err)) end
        end
        if group.looping == "REPEAT" then
            group:Play()
        end
        return
    end

    group._currentOrder = order
    group._remainingInOrder = #batch

    local function onAnimEngineFinish(anim)
        -- If the group was Stop()'d while this order was in-flight, do not
        -- chain to the next order. The onFinished callback on the individual
        -- anim may have cancelled the whole group; honoring _playing here
        -- prevents spurious restart of subsequent orders.
        if not group._playing then return end
        group._remainingInOrder = group._remainingInOrder - 1
        if group._remainingInOrder <= 0 then
            local nextOrder = group._nextOrderAfter[order]
            if nextOrder then
                playOrder(group, nextOrder)
            else
                group._playing = false
                group._currentOrder = nil
                if group.onFinished then
                    local ok, err = pcall(group.onFinished, group)
                    if not ok then Loolib:Error("AnimationUtil: group onFinished error: " .. tostring(err)) end
                end
                if group.looping == "REPEAT" then
                    group:Play()
                end
            end
        end
    end

    for _, anim in ipairs(batch) do
        anim._onEngineFinish = onAnimEngineFinish
        scheduleAnim(anim)
    end
end

function GroupMixin:Play()
    if self._playing then
        self:Stop()
    end

    -- Bucket animations by order; build ordered order list.
    local byOrder = {}
    for _, anim in ipairs(self.animations) do
        local o = anim.order or 1
        byOrder[o] = byOrder[o] or {}
        tinsert(byOrder[o], anim)
    end

    local orders = {}
    for o in pairs(byOrder) do tinsert(orders, o) end
    tsort(orders)

    local nextAfter = {}
    for i = 1, #orders - 1 do
        nextAfter[orders[i]] = orders[i + 1]
    end

    self._byOrder = byOrder
    self._nextOrderAfter = nextAfter
    self._playing = true

    if #orders == 0 then
        self._playing = false
        if self.onFinished then pcall(self.onFinished, self) end
        return
    end

    playOrder(self, orders[1])
end

function GroupMixin:Stop()
    if self._byOrder then
        for _, batch in pairs(self._byOrder) do
            for _, anim in ipairs(batch) do
                stopAnim(anim)
            end
        end
    end
    self._playing = false
    self._currentOrder = nil
end

function GroupMixin:Pause()
    -- Simple pause: stop all animations but remember state. Resume via Play().
    self:Stop()
end

function GroupMixin:IsPlaying()
    return self._playing == true
end

--[[--------------------------------------------------------------------
    Public API
----------------------------------------------------------------------]]

--- Create a new animation group owned by `parent`.
-- @param parent Frame|nil - Default target for child animations if opts.target is omitted
-- @return table - Group object with :CreateAnimation, :Play, :Stop, :Pause, :SetOnFinished
function AnimationUtil.CreateGroup(parent)
    local group = setmetatable({}, GroupMixin)
    group.parent = parent
    group.animations = {}
    group.looping = "NONE"
    return group
end

--- Stop every animation managed by this engine.
-- Intended for testing and emergency cleanup.
function AnimationUtil.StopAll()
    for i = #active, 1, -1 do
        active[i]._stopped = true
        active[i]._running = false
        tremove(active, i)
    end
    if updater then updater:Hide() end
end

--- Internal: number of currently-active animations (for tests/diagnostics).
function AnimationUtil.GetActiveCount()
    return #active
end

--[[--------------------------------------------------------------------
    Registration
----------------------------------------------------------------------]]

Animation.Util = AnimationUtil
Animation.AnimationUtil = AnimationUtil
Loolib.AnimationUtil = AnimationUtil

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.Animation = Animation
UI.AnimationUtil = AnimationUtil

Loolib:RegisterModule("Animation.Util", AnimationUtil)
