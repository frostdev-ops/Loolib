--[[--------------------------------------------------------------------
    Loolib - WindowManager
    Centralized click-to-raise focus management for top-level frames.
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

local WindowManager = {}
Loolib:RegisterModule("WindowManager", WindowManager)

local registry = {}  -- frame → true when actively registered

--- Register a frame for click-to-raise behavior.
-- Calls frame:SetToplevel(true) so the frame raises whenever it or any child receives a click.
-- This is WoW's native focus-management mechanism — works for title bars, buttons, and content areas.
-- Safe to call multiple times; no-ops if already registered.
-- @param frame Frame
function WindowManager:Register(frame)
    if not frame or registry[frame] then return end
    registry[frame] = true
    frame:SetToplevel(true)
end

--- Unregister a frame, reversing click-to-raise behavior via SetToplevel(false).
-- @param frame Frame
function WindowManager:Unregister(frame)
    if not registry[frame] then return end
    registry[frame] = nil
    frame:SetToplevel(false)
end
