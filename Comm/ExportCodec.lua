--[[--------------------------------------------------------------------
    Loolib - WoW 12.0+ Addon Library
    ExportCodec - Printable table export encode/decode helpers

    Reuses Loolib's Serializer and Compressor to convert structured table
    payloads into Base64-safe printable strings and back again.
----------------------------------------------------------------------]]

local LibStub = LibStub
local assert = assert
local error = error
local type = type

local Loolib = LibStub("Loolib")
local ApplyMixins = assert(Loolib.Mixin,
    "Loolib.Mixin must be loaded before Comm/ExportCodec.lua")
local CreateFromMixins = assert(Loolib.CreateFromMixins,
    "Loolib.CreateFromMixins must be loaded before Comm/ExportCodec.lua")
local Comm = Loolib.Comm or Loolib:GetOrCreateModule("Comm")

Loolib.Comm = Comm

local ExportCodecMixin = {}

local DEFAULT_OPTIONS = {
    compression = "deflate",
    level = 6,
}

local function NormalizeOptions(options)
    local normalized = {
        compression = DEFAULT_OPTIONS.compression,
        level = DEFAULT_OPTIONS.level,
    }

    if type(options) == "table" then
        if options.compression ~= nil then
            normalized.compression = options.compression
        end
        if options.level ~= nil then
            normalized.level = options.level
        end
    end

    return normalized
end

local function CompressPayload(compressor, serialized, options)
    if options.compression == "zlib" then
        return compressor:CompressZlib(serialized, options.level)
    end

    if options.compression == "deflate" then
        return compressor:Compress(serialized, options.level)
    end

    return nil, "Unsupported compression mode"
end

local function DecompressPayload(compressor, encoded, options)
    if options.compression == "zlib" then
        local decompressed, success = compressor:DecompressZlib(encoded)
        if not success or not decompressed then
            return nil, "Decompression failed"
        end
        return decompressed
    end

    if options.compression == "deflate" then
        local decompressed, success = compressor:Decompress(encoded)
        if not success or not decompressed then
            return nil, "Decompression failed"
        end
        return decompressed
    end

    return nil, "Unsupported compression mode"
end

--- Encode a structured table payload into a printable export string.
-- @param payload table
-- @param options table|nil - { compression = "deflate"|"zlib", level = 0..9 }
-- @return string|nil encoded
-- @return string|nil errMsg
function ExportCodecMixin:EncodeTable(payload, options)
    if type(payload) ~= "table" then
        return nil, "Payload must be a table"
    end

    local serializer = Loolib.Serializer
    local compressor = Loolib.Compressor
    if not serializer or not compressor then
        return nil, "Serializer or compressor not available"
    end

    options = NormalizeOptions(options)

    local serialized = serializer:Serialize(payload)
    if not serialized then
        return nil, "Serialization failed"
    end

    local compressed, compressErr = CompressPayload(compressor, serialized, options)
    if not compressed then
        return nil, compressErr or "Compression failed"
    end

    local ok, encoded = pcall(compressor.EncodeForPrint, compressor, compressed)
    if not ok or not encoded then
        return nil, "Base64 encoding failed"
    end

    return encoded, nil
end

--- Decode a printable export string into a structured table payload.
-- @param encoded string
-- @param options table|nil - { compression = "deflate"|"zlib", level = 0..9 }
-- @return boolean success
-- @return table|string payload or errMsg
function ExportCodecMixin:DecodeTable(encoded, options)
    if type(encoded) ~= "string" or encoded == "" then
        return false, "Empty import string"
    end

    local serializer = Loolib.Serializer
    local compressor = Loolib.Compressor
    if not serializer or not compressor then
        return false, "Serializer or compressor not available"
    end

    options = NormalizeOptions(options)
    encoded = encoded:gsub("%s+", "")

    local ok, decoded = pcall(compressor.DecodeForPrint, compressor, encoded)
    if not ok or not decoded then
        return false, "Invalid Base64 string"
    end

    local decompressed, decompressErr = DecompressPayload(compressor, decoded, options)
    if not decompressed then
        return false, decompressErr or "Decompression failed"
    end

    local success, payload = serializer:Deserialize(decompressed)
    if not success then
        return false, "Deserialization failed — invalid data format"
    end

    if type(payload) ~= "table" then
        return false, "Decoded payload is not a table"
    end

    return true, payload
end

local function CreateExportCodec()
    return CreateFromMixins(ExportCodecMixin)
end

local ExportCodecModule = Comm.ExportCodec
local ExportCodecInstance

if type(ExportCodecModule) == "table" and ExportCodecModule.Instance then
    ExportCodecInstance = ExportCodecModule.Instance
elseif type(ExportCodecModule) == "table"
    and ExportCodecModule.EncodeTable
    and ExportCodecModule.DecodeTable then
    ExportCodecInstance = ExportCodecModule
    ExportCodecModule = {}
else
    ExportCodecModule = type(ExportCodecModule) == "table" and ExportCodecModule or {}
    ExportCodecInstance = ExportCodecModule.Instance or Loolib.ExportCodec or {}
end

ApplyMixins(ExportCodecInstance, ExportCodecMixin)

Loolib.Comm.ExportCodec = ExportCodecModule
Loolib.Comm.ExportCodec.Mixin = ExportCodecMixin
Loolib.Comm.ExportCodec.Create = CreateExportCodec
Loolib.Comm.ExportCodec.Instance = ExportCodecInstance
Loolib.Comm.ExportCodec.ExportCodec = ExportCodecInstance

Loolib.ExportCodec = ExportCodecInstance

Loolib:RegisterModule("Comm.ExportCodec", ExportCodecModule)
Loolib:RegisterModule("ExportCodec", ExportCodecModule)
