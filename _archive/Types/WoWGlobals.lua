-- Project-level LuaLS type stubs — supplements Ketho WoW API annotations.
-- This file is never loaded by WoW (not in TOC).
-- IMPORTANT: Do NOT redeclare Region, Frame, Texture, FontString — Ketho is the source of truth.

--- StaticPopup dialog definition table.
---@class StaticPopupInfo
---@field text string
---@field button1 string
---@field button2 string
---@field timeout number
---@field whileDead boolean
---@field hideOnEscape boolean
---@field OnAccept fun(self: Frame, data: any)
---@field OnCancel fun(self: Frame, data: any)

--- Frame pool returned by CreateFramePool.
---@class FramePool
local FramePool = {}
---@return Frame
function FramePool:Acquire() end
---@param frame Frame
function FramePool:Release(frame) end
function FramePool:ReleaseAll() end
---@return function
function FramePool:EnumerateActive() end

-- Blizzard global backdrop templates
---@type table
BACKDROP_TOOLTIP_16_16_5555 = BACKDROP_TOOLTIP_16_16_5555
