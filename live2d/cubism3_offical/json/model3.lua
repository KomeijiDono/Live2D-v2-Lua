-- json/model3.lua - model3.json parser (FFI Core path)
-- Minimal self-contained JSON parser for model3.json descriptor files.
-- Independent of existing cubism3/ JSON parsers.

local dkjson = require("live2d.dkjson")

local model3 = {}

function model3.parse(json_str)
    local ok, data = pcall(dkjson.decode, json_str)
    if not ok or type(data) ~= "table" then
        return nil, "Failed to parse model3.json: " .. tostring(data)
    end

    local ver = tonumber(data.Version)
    if not ver then
        return nil, "Missing or invalid Version in model3.json"
    end

    local refs = data.FileReferences
    if not refs then
        return nil, "Missing FileReferences in model3.json"
    end

    local moc_file = refs.Moc
    if not moc_file then
        return nil, "Missing FileReferences.Moc in model3.json"
    end

    local result = {
        version = ver,
        name = data.Name or "",
        file_references = {
            moc = moc_file,
            textures = {},
            physics = refs.Physics,
            pose = refs.Pose,
            display_info = refs.DisplayInfo,
            motions = {},
            expressions = {},
        },
        groups = {},
    }

    if type(refs.Textures) == "table" then
        result.file_references.textures = refs.Textures
    end

    if type(refs.Motions) == "table" then
        result.file_references.motions = refs.Motions
    end

    if type(refs.Expressions) == "table" then
        result.file_references.expressions = refs.Expressions
    end

    if type(data.Groups) == "table" then
        result.groups = data.Groups
    end

    if type(data.HitAreas) == "table" then
        result.hit_areas = data.HitAreas
    end

    if type(data.Layout) == "table" then
        result.layout = data.Layout
    end

    return result
end

return model3
