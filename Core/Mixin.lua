--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    Mixin utilities for composition-based objects
----------------------------------------------------------------------]]

local Loolib = LibStub("Loolib")

--[[--------------------------------------------------------------------
    Core Mixin Functions

    These wrap Blizzard's global Mixin/CreateFromMixins functions
    with additional utilities and safety checks.
----------------------------------------------------------------------]]

--- Apply one or more mixins to an existing object
-- @param object table - The target object
-- @param ... - One or more mixin tables to apply
-- @return table - The modified object
local function ApplyMixins(object, ...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...)
        if mixin then
            for key, value in pairs(mixin) do
                object[key] = value
            end
        end
    end
    return object
end

--- Create a new object from one or more mixins
-- @param ... - One or more mixin tables
-- @return table - A new table with all mixin members
local function CreateFromMixins(...)
    return ApplyMixins({}, ...)
end

--- Create a new object from a mixin and initialize it
-- @param mixin table - The mixin to use
-- @param ... - Arguments passed to Init()
-- @return table - The initialized object
local function CreateAndInitFromMixin(mixin, ...)
    local object = CreateFromMixins(mixin)
    if object.Init then
        object:Init(...)
    end
    return object
end

--[[--------------------------------------------------------------------
    Frame Specialization

    Apply mixins to frames and reflect script handlers.
----------------------------------------------------------------------]]

-- Standard script handlers that can be reflected from mixins
local STANDARD_SCRIPTS = {
    "OnLoad",
    "OnShow",
    "OnHide",
    "OnEvent",
    "OnUpdate",
    "OnEnter",
    "OnLeave",
    "OnClick",
    "OnDoubleClick",
    "OnDragStart",
    "OnDragStop",
    "OnReceiveDrag",
    "OnMouseDown",
    "OnMouseUp",
    "OnMouseWheel",
    "OnValueChanged",
    "OnTextChanged",
    "OnEnterPressed",
    "OnEscapePressed",
    "OnTabPressed",
    "OnSizeChanged",
    "OnAttributeChanged",
}

--- Reflect standard script handlers from object methods to frame scripts
-- @param frame Frame - The frame to set scripts on
local function ReflectScriptHandlers(frame)
    for _, scriptName in ipairs(STANDARD_SCRIPTS) do
        local handler = frame[scriptName]
        if handler and type(handler) == "function" then
            -- Check if the frame supports this script type
            if frame.HasScript and frame:HasScript(scriptName) then
                frame:SetScript(scriptName, handler)
            end
        end
    end
end

--- Apply mixins to a frame and reflect script handlers
-- @param frame Frame - The target frame
-- @param ... - One or more mixin tables to apply
-- @return Frame - The modified frame
local function SpecializeFrameWithMixins(frame, ...)
    ApplyMixins(frame, ...)
    ReflectScriptHandlers(frame)
    return frame
end

--[[--------------------------------------------------------------------
    Mixin Validation
----------------------------------------------------------------------]]

--- Check if an object has all methods from a mixin
-- @param object table - The object to check
-- @param mixin table - The mixin to validate against
-- @return boolean - True if all mixin methods exist on the object
local function ValidateMixin(object, mixin)
    for key, value in pairs(mixin) do
        if type(value) == "function" and type(object[key]) ~= "function" then
            return false, key
        end
    end
    return true
end

--- Assert that an object implements a mixin interface
-- @param object table - The object to check
-- @param mixin table - The mixin to validate against
-- @param mixinName string - Name for error messages
local function AssertMixin(object, mixin, mixinName)
    local valid, missing = ValidateMixin(object, mixin)
    if not valid then
        error(string.format("Object missing required method '%s' from %s", missing, mixinName or "mixin"), 2)
    end
end

--[[--------------------------------------------------------------------
    Mixin Inheritance Utilities
----------------------------------------------------------------------]]

--- Create a mixin that inherits from a base mixin
-- @param baseMixin table - The base mixin to inherit from
-- @param ... - Additional mixins to include
-- @return table - A new mixin combining all sources
local function ExtendMixin(baseMixin, ...)
    return CreateFromMixins(baseMixin, ...)
end

--- Call a parent mixin's method
-- @param self table - The object instance
-- @param mixin table - The parent mixin
-- @param methodName string - The method to call
-- @param ... - Arguments to pass
-- @return any - The method's return value
local function CallParentMethod(self, mixin, methodName, ...)
    local method = mixin[methodName]
    if method then
        return method(self, ...)
    end
end

--[[--------------------------------------------------------------------
    Register with Loolib
----------------------------------------------------------------------]]

local MixinModule = {
    Mixin = ApplyMixins,
    CreateFromMixins = CreateFromMixins,
    CreateAndInitFromMixin = CreateAndInitFromMixin,
    ReflectScriptHandlers = ReflectScriptHandlers,
    SpecializeFrameWithMixins = SpecializeFrameWithMixins,
    ValidateMixin = ValidateMixin,
    AssertMixin = AssertMixin,
    ExtendMixin = ExtendMixin,
    CallParentMethod = CallParentMethod,
}

Loolib.Core = Loolib.Core or {}
Loolib.Core.Mixin = MixinModule

Loolib.Mixin = ApplyMixins
Loolib.CreateFromMixins = CreateFromMixins
Loolib.CreateAndInitFromMixin = CreateAndInitFromMixin
Loolib.ReflectScriptHandlers = ReflectScriptHandlers
Loolib.SpecializeFrameWithMixins = SpecializeFrameWithMixins
Loolib.ValidateMixin = ValidateMixin
Loolib.AssertMixin = AssertMixin
Loolib.ExtendMixin = ExtendMixin
Loolib.CallParentMethod = CallParentMethod

Loolib:RegisterModule("Core.Mixin", MixinModule)
