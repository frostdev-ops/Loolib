--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Easing - Robert Penner's easing curves for interpolation

    Pure functions, no state, no WoW API dependencies.
    Signature: Easing.<curve>(t, b, c, d)
      t = elapsed time   (0..d)
      b = begin value
      c = change         (end - begin)
      d = total duration
    Returns: eased value at time t.

    13 curves x (in, out, inout) = 39 functions, plus linear.

    Dependencies (must be loaded before this file):
    - Core/Loolib.lua
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local Animation = Loolib.Animation or Loolib:GetOrCreateModule("Animation")
local Easing = Animation.Easing or Loolib:GetModule("Animation.Easing") or {}

local math_pow = math.pow or function(a, b) return a ^ b end
local math_sin = math.sin
local math_cos = math.cos
local math_sqrt = math.sqrt
local math_pi = math.pi
local math_abs = math.abs
local math_asin = math.asin

local HALF_PI = math_pi / 2

--[[--------------------------------------------------------------------
    Linear
----------------------------------------------------------------------]]

function Easing.linear(t, b, c, d)
    return c * t / d + b
end

--[[--------------------------------------------------------------------
    Quadratic
----------------------------------------------------------------------]]

function Easing.inQuad(t, b, c, d)
    t = t / d
    return c * t * t + b
end

function Easing.outQuad(t, b, c, d)
    t = t / d
    return -c * t * (t - 2) + b
end

function Easing.inOutQuad(t, b, c, d)
    t = t / (d / 2)
    if t < 1 then
        return c / 2 * t * t + b
    end
    t = t - 1
    return -c / 2 * (t * (t - 2) - 1) + b
end

--[[--------------------------------------------------------------------
    Cubic
----------------------------------------------------------------------]]

function Easing.inCubic(t, b, c, d)
    t = t / d
    return c * t * t * t + b
end

function Easing.outCubic(t, b, c, d)
    t = t / d - 1
    return c * (t * t * t + 1) + b
end

function Easing.inOutCubic(t, b, c, d)
    t = t / (d / 2)
    if t < 1 then
        return c / 2 * t * t * t + b
    end
    t = t - 2
    return c / 2 * (t * t * t + 2) + b
end

--[[--------------------------------------------------------------------
    Quartic
----------------------------------------------------------------------]]

function Easing.inQuart(t, b, c, d)
    t = t / d
    return c * t * t * t * t + b
end

function Easing.outQuart(t, b, c, d)
    t = t / d - 1
    return -c * (t * t * t * t - 1) + b
end

function Easing.inOutQuart(t, b, c, d)
    t = t / (d / 2)
    if t < 1 then
        return c / 2 * t * t * t * t + b
    end
    t = t - 2
    return -c / 2 * (t * t * t * t - 2) + b
end

--[[--------------------------------------------------------------------
    Quintic
----------------------------------------------------------------------]]

function Easing.inQuint(t, b, c, d)
    t = t / d
    return c * t * t * t * t * t + b
end

function Easing.outQuint(t, b, c, d)
    t = t / d - 1
    return c * (t * t * t * t * t + 1) + b
end

function Easing.inOutQuint(t, b, c, d)
    t = t / (d / 2)
    if t < 1 then
        return c / 2 * t * t * t * t * t + b
    end
    t = t - 2
    return c / 2 * (t * t * t * t * t + 2) + b
end

--[[--------------------------------------------------------------------
    Sinusoidal
----------------------------------------------------------------------]]

function Easing.inSine(t, b, c, d)
    return -c * math_cos(t / d * HALF_PI) + c + b
end

function Easing.outSine(t, b, c, d)
    return c * math_sin(t / d * HALF_PI) + b
end

function Easing.inOutSine(t, b, c, d)
    return -c / 2 * (math_cos(math_pi * t / d) - 1) + b
end

--[[--------------------------------------------------------------------
    Exponential
----------------------------------------------------------------------]]

function Easing.inExpo(t, b, c, d)
    if t == 0 then return b end
    return c * math_pow(2, 10 * (t / d - 1)) + b
end

function Easing.outExpo(t, b, c, d)
    if t == d then return b + c end
    return c * (-math_pow(2, -10 * t / d) + 1) + b
end

function Easing.inOutExpo(t, b, c, d)
    if t == 0 then return b end
    if t == d then return b + c end
    t = t / (d / 2)
    if t < 1 then
        return c / 2 * math_pow(2, 10 * (t - 1)) + b
    end
    t = t - 1
    return c / 2 * (-math_pow(2, -10 * t) + 2) + b
end

--[[--------------------------------------------------------------------
    Circular
----------------------------------------------------------------------]]

function Easing.inCirc(t, b, c, d)
    t = t / d
    return -c * (math_sqrt(1 - t * t) - 1) + b
end

function Easing.outCirc(t, b, c, d)
    t = t / d - 1
    return c * math_sqrt(1 - t * t) + b
end

function Easing.inOutCirc(t, b, c, d)
    t = t / (d / 2)
    if t < 1 then
        return -c / 2 * (math_sqrt(1 - t * t) - 1) + b
    end
    t = t - 2
    return c / 2 * (math_sqrt(1 - t * t) + 1) + b
end

--[[--------------------------------------------------------------------
    Back (overshoot)
----------------------------------------------------------------------]]

local BACK_S = 1.70158

function Easing.inBack(t, b, c, d)
    t = t / d
    return c * t * t * ((BACK_S + 1) * t - BACK_S) + b
end

function Easing.outBack(t, b, c, d)
    t = t / d - 1
    return c * (t * t * ((BACK_S + 1) * t + BACK_S) + 1) + b
end

function Easing.inOutBack(t, b, c, d)
    local s = BACK_S * 1.525
    t = t / (d / 2)
    if t < 1 then
        return c / 2 * (t * t * ((s + 1) * t - s)) + b
    end
    t = t - 2
    return c / 2 * (t * t * ((s + 1) * t + s) + 2) + b
end

--[[--------------------------------------------------------------------
    Bounce
----------------------------------------------------------------------]]

local function bounceOut(t, b, c, d)
    t = t / d
    if t < 1 / 2.75 then
        return c * (7.5625 * t * t) + b
    elseif t < 2 / 2.75 then
        t = t - 1.5 / 2.75
        return c * (7.5625 * t * t + 0.75) + b
    elseif t < 2.5 / 2.75 then
        t = t - 2.25 / 2.75
        return c * (7.5625 * t * t + 0.9375) + b
    else
        t = t - 2.625 / 2.75
        return c * (7.5625 * t * t + 0.984375) + b
    end
end

function Easing.outBounce(t, b, c, d)
    return bounceOut(t, b, c, d)
end

function Easing.inBounce(t, b, c, d)
    return c - bounceOut(d - t, 0, c, d) + b
end

function Easing.inOutBounce(t, b, c, d)
    if t < d / 2 then
        return (c - bounceOut(d - (t * 2), 0, c, d)) * 0.5 + b
    end
    return bounceOut(t * 2 - d, 0, c, d) * 0.5 + c * 0.5 + b
end

--[[--------------------------------------------------------------------
    Elastic
----------------------------------------------------------------------]]

function Easing.inElastic(t, b, c, d)
    if t == 0 then return b end
    t = t / d
    if t == 1 then return b + c end
    local p = d * 0.3
    local a = c
    local s = p / 4
    t = t - 1
    return -(a * math_pow(2, 10 * t) * math_sin((t * d - s) * (2 * math_pi) / p)) + b
end

function Easing.outElastic(t, b, c, d)
    if t == 0 then return b end
    t = t / d
    if t == 1 then return b + c end
    local p = d * 0.3
    local a = c
    local s = p / 4
    return a * math_pow(2, -10 * t) * math_sin((t * d - s) * (2 * math_pi) / p) + c + b
end

function Easing.inOutElastic(t, b, c, d)
    if t == 0 then return b end
    t = t / (d / 2)
    if t == 2 then return b + c end
    local p = d * (0.3 * 1.5)
    local a = c
    local s = p / 4
    if t < 1 then
        t = t - 1
        return -0.5 * (a * math_pow(2, 10 * t) * math_sin((t * d - s) * (2 * math_pi) / p)) + b
    end
    t = t - 1
    return a * math_pow(2, -10 * t) * math_sin((t * d - s) * (2 * math_pi) / p) * 0.5 + c + b
end

-- Silence luacheck for intentionally unused imports (kept for future math expansion)
local _ = math_abs
_ = math_asin
_ = _

--[[--------------------------------------------------------------------
    Registration
----------------------------------------------------------------------]]

Animation.Easing = Easing
Loolib.Easing = Easing

Loolib:RegisterModule("Animation.Easing", Easing)
