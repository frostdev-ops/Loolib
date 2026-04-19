--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    PixelUtil - Pixel-perfect sizing math (E.mult equivalent)

    Exposes the "pixel mult" that ElvUI/ToxiUI use to snap UI units to
    physical screen pixels. Loolib deliberately does NOT modify
    UIParent:SetScale -- that's an addon-level choice. This module just
    exposes the math and a thin-border helper.

    mult = 768 / screenHeight / UIParent:GetScale()

    Fires Loolib.Events callback "LOOLIB_PIXEL_MULT_CHANGED" when the
    value is recomputed (UI scale or display size change).

    Dependencies (must be loaded before this file):
    - Core/Loolib.lua
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")
local PixelUtil = Loolib.PixelUtil or Loolib:GetModule("UI.PixelUtil") or {}

local type = type
local pairs = pairs
local pcall = pcall
local select = select
local math_floor = math.floor
local math_max = math.max
local GetPhysicalScreenSize = GetPhysicalScreenSize
local UIParent = UIParent
local CreateFrame = CreateFrame

local cachedMult
local watcher
local callbacks = {}

local function computeMult()
    local _, screenHeight = 1920, 1080
    if type(GetPhysicalScreenSize) == "function" then
        _, screenHeight = GetPhysicalScreenSize()
    end
    if not screenHeight or screenHeight <= 0 then screenHeight = 1080 end

    local uiScale = 1
    if type(UIParent) == "table" and type(UIParent.GetScale) == "function" then
        uiScale = UIParent:GetScale() or 1
    end

    return 768 / screenHeight / math_max(uiScale, 0.01)
end

local function recompute()
    local old = cachedMult
    cachedMult = computeMult()
    if old ~= cachedMult then
        for owner, fn in pairs(callbacks) do
            if type(fn) == "function" then
                local ok, err = pcall(fn, cachedMult, old)
                if not ok then Loolib:Error("PixelUtil: callback error: " .. tostring(err)) end
            end
        end
    end
end

local function ensureWatcher()
    if watcher then return end
    watcher = CreateFrame("Frame", "LoolibPixelUtilWatcher", UIParent)
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:SetScript("OnEvent", recompute)
end

--- Return the current pixel mult. Cached; refreshed on scale/resolution change.
-- @return number
function PixelUtil.GetMult()
    if not cachedMult then
        cachedMult = computeMult()
        ensureWatcher()
    end
    return cachedMult
end

--- Snap a value to the nearest multiple of the current pixel mult.
-- @param value number
-- @return number
function PixelUtil.Snap(value)
    if type(value) ~= "number" then return value end
    local m = PixelUtil.GetMult()
    if m <= 0 then return value end
    return math_floor(value / m + 0.5) * m
end

--- Register a callback fired when the pixel mult changes.
-- @param owner any - Must be non-nil, used as the key for unregister
-- @param callback function(newMult, oldMult)
function PixelUtil.RegisterCallback(owner, callback)
    if owner == nil or type(callback) ~= "function" then return end
    ensureWatcher()
    callbacks[owner] = callback
end

--- Unregister a callback.
-- @param owner any
function PixelUtil.UnregisterCallback(owner)
    if owner == nil then return end
    callbacks[owner] = nil
end

--- Set a thin 1-physical-pixel border on a frame using two nested textures.
-- Creates and returns the outline texture family on the frame (frame._loolibBorderEdges).
-- Safe to call multiple times; rebuilds in-place.
-- @param frame Frame
-- @param color table {r,g,b[,a]}
-- @return table edges with fields Top, Bottom, Left, Right (textures)
function PixelUtil.SetThinBorder(frame, color)
    if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then return end
    color = color or { 0, 0, 0, 1 }
    local r, g, b, a = color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1

    local edges = frame._loolibBorderEdges
    if not edges then
        edges = {}
        local function makeEdge()
            local tex = frame:CreateTexture(nil, "OVERLAY")
            tex:SetColorTexture(r, g, b, a)
            return tex
        end
        edges.Top = makeEdge()
        edges.Bottom = makeEdge()
        edges.Left = makeEdge()
        edges.Right = makeEdge()
        frame._loolibBorderEdges = edges
    else
        for _, tex in pairs(edges) do
            tex:SetColorTexture(r, g, b, a)
        end
    end

    local function reanchor()
        local m = PixelUtil.GetMult()
        edges.Top:ClearAllPoints()
        edges.Top:SetPoint("TOPLEFT", frame, "TOPLEFT", -m, m)
        edges.Top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", m, m)
        edges.Top:SetHeight(m)

        edges.Bottom:ClearAllPoints()
        edges.Bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -m, -m)
        edges.Bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", m, -m)
        edges.Bottom:SetHeight(m)

        edges.Left:ClearAllPoints()
        edges.Left:SetPoint("TOPLEFT", frame, "TOPLEFT", -m, m)
        edges.Left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -m, -m)
        edges.Left:SetWidth(m)

        edges.Right:ClearAllPoints()
        edges.Right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", m, m)
        edges.Right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", m, -m)
        edges.Right:SetWidth(m)
    end

    reanchor()

    -- Re-anchor on mult change so borders stay crisp across resolution changes.
    if not edges._reanchorRegistered then
        PixelUtil.RegisterCallback(edges, reanchor)
        edges._reanchorRegistered = true
    end

    return edges
end

--[[--------------------------------------------------------------------
    Registration
----------------------------------------------------------------------]]

local UI = Loolib.UI or Loolib:GetOrCreateModule("UI")
UI.PixelUtil = PixelUtil
Loolib.PixelUtil = PixelUtil

Loolib:RegisterModule("UI.PixelUtil", PixelUtil)

-- Silence luacheck: select is kept for future use
local _ = select
_ = _

-- Initial compute + watcher so cached value is ready on first GetMult().
ensureWatcher()
