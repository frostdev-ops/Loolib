--[[--------------------------------------------------------------------
    Loolib AddonMessage Reassembler Test Harness

    Exercises the private multi-part reassembler exposed at
    Loolib.Comm._testing. Designed to run two ways:

    1. Standalone (recommended during development):

           lua Loolib/_examples/tests/AddonMessageReassemblyTest.lua

       Stubs enough of the WoW environment to load Comm/AddonMessage.lua
       and its transitive Loolib dependencies are not required because
       we bypass the real loader and construct the module namespace
       inline. See SETUP below.

    2. In-game, after Loolib is loaded. Paste the contents into a chat
       line via /run or load via a dev addon. The SETUP block auto-
       detects an existing Loolib and skips stubbing.

    NOT referenced by any .toc. This is a reference harness, not a
    shipped test. Covered scenarios:

    * happy_path_three_parts      — basic 3-part reassembly
    * case_flip_mid_stream        — sender casing drift mid-stream
    * normalized_key_collision    — two senders with same normalized key
    * orphan_last                 — CTRL_LAST with no prior FIRST
    * orphan_middle               — CTRL_MIDDLE with no prior FIRST
    * id_mismatch_mid_stream      — id changes mid-stream
    * first_overlap               — new FIRST before prior LAST
    * cleanup_purges_stale        — CleanupStalePending removes old buckets
    * single_fast_path            — CTRL_SINGLE bypasses assembly

    Exit code is 0 on all pass, 1 on any failure.
----------------------------------------------------------------------]]

--[[--------------------------------------------------------------------
    SETUP — stub WoW env if running standalone
----------------------------------------------------------------------]]

local _mockTime = 1000.0
local function _setMockTime(t) _mockTime = t end

local running_in_wow = (type(_G) == "table" and type(_G.LibStub) == "function")

if not running_in_wow then
    -- Minimal WoW-client stubs needed by Comm/AddonMessage.lua at load time.
    GetTime         = function() return _mockTime end
    GetFramerate    = function() return 60 end
    IsInRaid        = function() return false end
    IsInGroup       = function() return false end
    IsInGuild       = function() return false end
    hooksecurefunc  = function() end
    wipe            = function(t) for k in pairs(t) do t[k] = nil end end
    CreateFrame     = function()
        return setmetatable({}, { __index = function()
            return function() end
        end })
    end
    C_ChatInfo = {
        SendAddonMessage              = function() return true end,
        RegisterAddonMessagePrefix    = function() return true end,
    }
    C_Timer = {
        NewTicker = function() return { Cancel = function() end } end,
        After     = function() end,
    }
    Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3,
        AddOnMessageLockdown = 11 } }

    -- Minimal LibStub + Loolib shim.
    local _libs = {}
    LibStub = setmetatable({
        NewLibrary = function(_, name) _libs[name] = _libs[name] or {}; return _libs[name] end,
    }, { __call = function(_, name) return _libs[name] end })

    local Loolib = {
        debug = false,
        Mixin = function(target, ...)
            for _, src in ipairs({...}) do
                for k, v in pairs(src) do target[k] = v end
            end
            return target
        end,
        CreateFromMixins = function(...)
            local t = {}
            for _, src in ipairs({...}) do
                for k, v in pairs(src) do t[k] = v end
            end
            return t
        end,
        _modules = {},
        Debug = function() end,
        Error = function() end,
    }
    function Loolib:GetOrCreateModule(name)
        self._modules[name] = self._modules[name] or {}
        return self._modules[name]
    end
    function Loolib:RegisterModule(name, mod) self._modules[name] = mod end
    function Loolib:GetModule(name) return self._modules[name] end
    _libs.Loolib = Loolib

    -- Resolve Comm/AddonMessage.lua relative to this file.
    local here = debug.getinfo(1, "S").source:sub(2):gsub("[^/]+$", "")
    dofile(here .. "../../Comm/AddonMessage.lua")
end

local Loolib = LibStub("Loolib")
assert(Loolib and Loolib.Comm and Loolib.Comm._testing,
    "Loolib.Comm._testing must be exposed — are you on a patched v2.1.3+?")

local T                  = Loolib.Comm._testing
local AssembleMessage    = T.AssembleMessage
local CleanupStalePending = T.CleanupStalePending
local NormalizeSenderKey = T.NormalizeSenderKey
local SplitMessage       = T.SplitMessage
local GetPending         = T.GetPendingMessages
local ResetPending       = T.ResetPendingMessages
local ResetIDCounter     = T.ResetMessageIDCounter
local CTRL_SINGLE        = T.CTRL_SINGLE
local CTRL_FIRST         = T.CTRL_FIRST
local CTRL_MIDDLE        = T.CTRL_MIDDLE
local CTRL_LAST          = T.CTRL_LAST

-- Reset production state between runs so standalone tests don't leak
-- message IDs into the live counter.
if ResetIDCounter then ResetIDCounter() end

--[[--------------------------------------------------------------------
    Test utilities
----------------------------------------------------------------------]]

local tests_passed, tests_failed, failures = 0, 0, {}

local function fail(name, msg)
    tests_failed = tests_failed + 1
    failures[#failures + 1] = name .. " — " .. tostring(msg)
end

local function pass(name)
    tests_passed = tests_passed + 1
    print("  PASS  " .. name)
end

local function check(name, cond, msg)
    if cond then pass(name) else fail(name, msg or "condition false"); print("  FAIL  " .. name .. " — " .. tostring(msg)) end
end

local function check_eq(name, actual, expected)
    if actual == expected then
        pass(name)
    else
        fail(name, ("expected %q, got %q"):format(tostring(expected), tostring(actual)))
        print(("  FAIL  %s — expected %q, got %q"):format(name, tostring(expected), tostring(actual)))
    end
end

-- Convenience: feed a 3-part split of `payload` through AssembleMessage
-- and return (final, bool-complete-on-LAST).
local function feedThreePart(senders, prefix, payload)
    -- Build the wire-format parts manually so we don't depend on GenerateMessageID.
    local msgID = "ABCD"
    local third = math.floor(#payload / 3)
    local p1 = payload:sub(1, third)
    local p2 = payload:sub(third + 1, third * 2)
    local p3 = payload:sub(third * 2 + 1)

    local a, c = AssembleMessage(senders[1], prefix, CTRL_FIRST,  msgID, p1)
    local b, d = AssembleMessage(senders[2], prefix, CTRL_MIDDLE, msgID, p2)
    local e, f = AssembleMessage(senders[3], prefix, CTRL_LAST,   msgID, p3)
    return e, f, a, c, b, d
end

--[[--------------------------------------------------------------------
    Tests
----------------------------------------------------------------------]]

print("\n=== Loolib AddonMessage Reassembler Tests ===\n")

-- single_fast_path
do
    ResetPending()
    local out, ok = AssembleMessage("Felbane-Duskwood", "LOOP", CTRL_SINGLE, "", "hello")
    check_eq("single_fast_path.content",  out, "hello")
    check_eq("single_fast_path.complete", ok,  true)
end

-- happy_path_three_parts
do
    ResetPending()
    local payload = string.rep("X", 300) .. string.rep("Y", 300) .. string.rep("Z", 300)
    local out, ok = feedThreePart(
        { "Felbane-Duskwood", "Felbane-Duskwood", "Felbane-Duskwood" },
        "LOOP", payload)
    check_eq("happy_path.complete", ok, true)
    check_eq("happy_path.content_len", out and #out or 0, #payload)
    check_eq("happy_path.content_eq",  out, payload)
end

-- case_flip_mid_stream — THE PRIMARY BUG. Previously failed silently.
do
    ResetPending()
    local payload = ("abcdefghij"):rep(30)  -- 300 bytes
    local out, ok = feedThreePart(
        { "Felbane-duskwood", "Felbane-duskwood", "Felbane-Duskwood" },  -- note case flip on part 3
        "LOOP", payload)
    check_eq("case_flip.complete", ok, true)
    check_eq("case_flip.content_eq", out, payload)
end

-- case_flip_all_three_differ
do
    ResetPending()
    local payload = ("QWERTYUIOP"):rep(30)
    local out, ok = feedThreePart(
        { "Felbane-DUSKWOOD", "felbane-duskwood", "Felbane-Duskwood" },
        "LOOP", payload)
    check_eq("case_flip_all.complete", ok, true)
    check_eq("case_flip_all.content_eq", out, payload)
end

-- normalized_key_collision — two senders that look different but normalize the same
-- should be treated as one physical sender (correct, because WoW names are
-- case-insensitive unique per realm).
do
    ResetPending()
    local msgID = "0001"
    AssembleMessage("Jimbo-Area52",  "P", CTRL_FIRST,  msgID, "first-")
    local out, ok = AssembleMessage("jimbo-AREA52", "P", CTRL_LAST, msgID, "last")
    check_eq("norm_collision.complete", ok, true)
    check_eq("norm_collision.content", out, "first-last")
end

-- orphan_last — CTRL_LAST without prior FIRST, should be dropped silently.
do
    ResetPending()
    local out, ok = AssembleMessage("Orphan-Illidan", "P", CTRL_LAST, "1234", "payload")
    check_eq("orphan_last.nil_output", out, nil)
    check_eq("orphan_last.incomplete", ok, false)
    -- Bucket should be cleaned, not lingering.
    local pending = GetPending()
    check("orphan_last.no_leak", pending["orphan-illidan"] == nil or pending["orphan-illidan"]["P"] == nil,
        "orphan-illidan bucket should be absent")
end

-- orphan_middle
do
    ResetPending()
    local out, ok = AssembleMessage("Orphan-Illidan", "P", CTRL_MIDDLE, "1234", "middle")
    check_eq("orphan_middle.nil_output", out, nil)
    check_eq("orphan_middle.incomplete", ok, false)
end

-- id_mismatch_mid_stream — FIRST tagged X, LAST tagged Y. Old code would
-- silently adopt Y and eventually return truncated content. New code drops.
do
    ResetPending()
    AssembleMessage("Sender-A", "P", CTRL_FIRST, "AAAA", "first")
    local out, ok = AssembleMessage("Sender-A", "P", CTRL_LAST, "BBBB", "tail")
    check_eq("id_mismatch.nil_output", out, nil)
    check_eq("id_mismatch.incomplete", ok, false)
    -- Bucket should have been reset to empty, ready for a real FIRST.
    local pending = GetPending()
    check("id_mismatch.bucket_reset",
        pending["sender-a"] == nil or pending["sender-a"]["P"] == nil,
        "sender-a bucket should be reset after mismatch")
end

-- first_overlap — second FIRST while a prior is still incomplete.
-- Should adopt the new stream (and log, but we don't capture logs here).
do
    ResetPending()
    AssembleMessage("Sender-B", "P", CTRL_FIRST, "AAAA", "old-first")
    AssembleMessage("Sender-B", "P", CTRL_FIRST, "BBBB", "new-first-")
    local out, ok = AssembleMessage("Sender-B", "P", CTRL_LAST, "BBBB", "new-last")
    check_eq("first_overlap.complete", ok, true)
    check_eq("first_overlap.content", out, "new-first-new-last")
end

-- cleanup_purges_stale — stale buckets get removed by time sweep.
do
    ResetPending()
    _setMockTime(1000.0)
    AssembleMessage("Stale-Peon", "P", CTRL_FIRST, "AAAA", "stale")
    _setMockTime(1100.0)  -- advance 100s, past 60s max age
    CleanupStalePending(60)
    local pending = GetPending()
    check("cleanup.bucket_gone", pending["stale-peon"] == nil,
        "stale bucket should be purged")
end

-- cleanup_keeps_fresh
do
    ResetPending()
    _setMockTime(2000.0)
    AssembleMessage("Fresh-Peon", "P", CTRL_FIRST, "AAAA", "fresh")
    _setMockTime(2010.0)  -- only 10s later
    CleanupStalePending(60)
    local pending = GetPending()
    check("cleanup.fresh_kept", pending["fresh-peon"] and pending["fresh-peon"]["P"],
        "fresh bucket should be kept")
end

-- interleaved_prefixes — two addons on same Loolib shouldn't collide.
do
    ResetPending()
    _setMockTime(3000.0)
    AssembleMessage("Multi-Addon", "ADDON_A", CTRL_FIRST, "AAAA", "a-first-")
    AssembleMessage("Multi-Addon", "ADDON_B", CTRL_FIRST, "BBBB", "b-first-")
    local outA, okA = AssembleMessage("Multi-Addon", "ADDON_A", CTRL_LAST, "AAAA", "a-last")
    local outB, okB = AssembleMessage("Multi-Addon", "ADDON_B", CTRL_LAST, "BBBB", "b-last")
    check_eq("interleaved.a_complete", okA, true)
    check_eq("interleaved.a_content",  outA, "a-first-a-last")
    check_eq("interleaved.b_complete", okB, true)
    check_eq("interleaved.b_content",  outB, "b-first-b-last")
end

-- normalize_helper_basic
do
    check_eq("normalize.basic",       NormalizeSenderKey("Felbane-Duskwood"), "felbane-duskwood")
    check_eq("normalize.lower_realm", NormalizeSenderKey("Felbane-duskwood"), "felbane-duskwood")
    check_eq("normalize.all_upper",   NormalizeSenderKey("FELBANE-DUSKWOOD"), "felbane-duskwood")
    check_eq("normalize.empty",       NormalizeSenderKey(""), "")
    check_eq("normalize.non_string",  NormalizeSenderKey(nil), "")
    check_eq("normalize.no_realm",    NormalizeSenderKey("Felbane"), "felbane")
    -- Multiple dashes in realm (rare, but Blizzard realms like "Arathor-EU"
    -- and hyphenated realm names exist). "^([^-]+)-(.+)$" captures greedy
    -- on the realm, so name is up to the first dash and the rest is realm.
    check_eq("normalize.multi_dash",  NormalizeSenderKey("Felbane-Test-Realm"), "felbane-test-realm")
end

-- short_payload_edge — payload shorter than 3 bytes creates empty chunks
-- when feedThreePart splits by floor(len/3). Reassembly must still succeed.
do
    ResetPending()
    local msgID = "EEEE"
    -- Simulate a naively-split 2-byte payload: first chunk "a", middle "", last "b"
    local out1, ok1 = AssembleMessage("Edge-Realm", "P", CTRL_FIRST,  msgID, "a")
    local out2, ok2 = AssembleMessage("Edge-Realm", "P", CTRL_MIDDLE, msgID, "")
    local out3, ok3 = AssembleMessage("Edge-Realm", "P", CTRL_LAST,   msgID, "b")
    check_eq("empty_chunk.complete", ok3, true)
    check_eq("empty_chunk.content",  out3, "ab")
end

-- empty_single — CTRL_SINGLE with empty content (degenerate but possible)
do
    ResetPending()
    local out, ok = AssembleMessage("Anyone-Realm", "P", CTRL_SINGLE, "", "")
    check_eq("empty_single.complete", ok, true)
    check_eq("empty_single.content",  out, "")
end

-- SplitMessage_sanity — ensure wire format unchanged (backward-compat)
do
    local parts = SplitMessage("hi")
    check_eq("split.single_count", #parts, 1)
    check("split.single_ctrl", parts[1]:sub(1, 1) == CTRL_SINGLE, "short msg should use CTRL_SINGLE")

    local long = string.rep("A", 800)
    local parts2 = SplitMessage(long)
    check("split.multi_count_gt1", #parts2 > 1, "800-byte message should split")
    check("split.multi_first_ctrl",  parts2[1]:sub(1, 1) == CTRL_FIRST,  "first part ctrl byte")
    check("split.multi_last_ctrl",   parts2[#parts2]:sub(1, 1) == CTRL_LAST, "last part ctrl byte")
    for i = 2, #parts2 - 1 do
        check("split.middle_ctrl_" .. i, parts2[i]:sub(1, 1) == CTRL_MIDDLE, "middle ctrl byte")
    end
    -- All parts for the same message must share the same msgID.
    local id1 = parts2[1]:sub(2, 5)
    for i = 2, #parts2 do
        check("split.msgid_consistent_" .. i, parts2[i]:sub(2, 5) == id1,
            "msgID mismatch between parts")
    end
end

--[[--------------------------------------------------------------------
    Summary
----------------------------------------------------------------------]]

print(("\n=== %d passed, %d failed ===\n"):format(tests_passed, tests_failed))
if tests_failed > 0 then
    for _, f in ipairs(failures) do print("  - " .. f) end
    if not running_in_wow then os.exit(1) end
elseif not running_in_wow then
    os.exit(0)
end
