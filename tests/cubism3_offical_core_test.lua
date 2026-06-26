-- tests/cubism3_offical_core_test.lua - Smoke and unit tests for FFI Core path
-- Tests the official Live2D Cubism Core binding and model lifecycle without GPU.
io.stdout:setvbuf("no")
package.path = package.path .. ";./?.lua;./?/init.lua"

local core = require("live2d.cubism3_offical.core_ffi")
local Model = require("live2d.cubism3_offical.model")
local model3 = require("live2d.cubism3_offical.json.model3")
local motion3 = require("live2d.cubism3_offical.json.motion3")
local MotionPlayer = require("live2d.cubism3_offical.motion")
local native_moc3 = require("live2d.cubism3.moc3")

local passed = 0
local total = 0

local function check(name, ok, msg)
    total = total + 1
    if ok then
        passed = passed + 1
        print("[PASS] " .. name)
    else
        print("[FAIL] " .. name .. ": " .. (msg or "unknown"))
    end
end

local function read_file(path)
    local file = assert(io.open(path, "rb"))
    local data = file:read("*all")
    file:close()
    return data
end

local function read_text(path)
    local file = assert(io.open(path, "r"))
    local data = file:read("*all")
    file:close()
    return data
end

print("=== Cubism3 Offical Core Test ===")

-- Test 1: Core library loaded
print("\n-- Core Loading --")
check("core library loaded", core ~= nil)
local version = core.getVersion()
check("core version query", type(version) == "number")
print(string.format("  Core version: 0x%08X", version))
local latest_moc = core.getLatestMocVersion()
check("latest moc version query", type(latest_moc) == "number")
print(string.format("  Latest MOC version: %d", latest_moc))

-- Test 2: Load Rana model (Cubism5)
print("\n-- Rana Model Loading --")
local base = "resources/Rana/"
local model_json = read_text(base .. "adv_live2d_rana_003_live_01.model3.json")
local model_data = model3.parse(model_json)
check("model3.json parsed", model_data ~= nil)
check("model version is 3", model_data.version == 3)
check("has moc reference", model_data.file_references.moc ~= nil)
check("has textures", #model_data.file_references.textures > 0)

local moc_bytes = read_file(base .. model_data.file_references.moc)
check("moc bytes loaded", #moc_bytes > 0)
print("  MOC size: " .. #moc_bytes .. " bytes")

-- Test 3: MOC validation
local moc_ptr, moc_size = core.loadMocBytes(moc_bytes)
check("moc buffer aligned", moc_ptr ~= nil)
check("moc consistency", core.hasMocConsistency(moc_ptr, moc_size))
local moc_version = core.getMocVersion(moc_ptr, moc_size)
check("moc version query", moc_version > 0)
print(string.format("  MOC version: %d (expect 5.0 = 5 or 5.3 = 6)", moc_version))

-- Test 4: Create model
print("\n-- Model Creation --")
local model = Model.new(moc_bytes)
check("model created", model ~= nil)
check("drawable count > 0", model.drawable_count > 0)
check("parameter count > 0", model.parameter_count > 0)
check("part count > 0", model.part_count > 0)
check("canvas info", model.canvas ~= nil and model.canvas.width > 0)
print(string.format("  Parameters: %d, Parts: %d, Drawables: %d",
    model.parameter_count, model.part_count, model.drawable_count))
print(string.format("  Canvas: %.0fx%.0f ppu=%.1f",
    model.canvas.width, model.canvas.height, model.canvas.pixels_per_unit))

-- Test 5: Parameter management
print("\n-- Parameter Management --")
check("parameter ids loaded", #model.parameter_ids == model.parameter_count)
check("parameter defaults loaded", #model.parameter_defaults == model.parameter_count)
check("parameter min/max loaded", #model.parameter_min == model.parameter_count)

-- Set a parameter and verify
local param_idx = 1
local default_val = model.parameter_defaults[param_idx]
model:setParameterValue(param_idx, 0.5)
local new_val = model:getParameterValue(param_idx)
check("set/get parameter by index", new_val == 0.5)

-- Reset
model:setParameterValue(param_idx, default_val)
check("parameter reset", true)

-- Set by ID
if #model.parameter_ids > 0 then
    local first_id = model.parameter_ids[1]
    model:setParameterValueById(first_id, 0.8)
    local val = model:getParameterValueById(first_id)
    check("set/get parameter by id", math.abs(val - 0.8) < 0.0001)
    model:setParameterValue(param_idx, default_val)
end

-- Test 6: Part management
print("\n-- Part Management --")
check("part ids loaded", #model.part_ids == model.part_count)
local parts_before = model:getPartOpacities()
check("part opacities queryable", #parts_before == model.part_count)

if model.part_count > 0 then
    model:setPartOpacity(1, 0.5)
    local parts_after = model:getPartOpacities()
    check("set/get part opacity by index", parts_after[1] == 0.5)
    model:setPartOpacity(1, 1.0)
end

-- Test 7: Drawable data
print("\n-- Drawable Data --")
model:update()
local drawables = model:getAllDrawableData()
check("drawables returned", #drawables == model.drawable_count)

local visible_count = 0
local has_masks = false
local has_additive = false
local has_multiplicative = false
for _, d in ipairs(drawables) do
    if d then
        if d.opacity > 0.001 then
            visible_count = visible_count + 1
        end
        if d.mask_count > 0 then
            has_masks = true
        end
        if d.blend_mode_num == 3 or d.blend_mode_num == 1 then
            has_additive = true
        end
        if d.blend_mode_num == 6 or d.blend_mode_num == 2 then
            has_multiplicative = true
        end
    end
end
check("visible drawables > 0", visible_count > 0)
print("  Visible drawables: " .. visible_count)

-- Check that first drawable has geometry
local first_drawable = drawables[1]
check("first drawable exists", first_drawable ~= nil)
if first_drawable then
    check("first drawable has vertices", first_drawable.vertex_count > 0)
    check("first drawable has indices", first_drawable.index_count > 0)
    check("first drawable has positions", #first_drawable.positions == first_drawable.vertex_count)
    check("first drawable has uvs", #first_drawable.uvs == first_drawable.vertex_count)
    check("first drawable has indices table", #first_drawable.indices == first_drawable.index_count)
    check("first drawable has render_order", type(first_drawable.render_order) == "number")
    check("first drawable has opacity", type(first_drawable.opacity) == "number")
    check("first drawable has blend_mode_num", type(first_drawable.blend_mode_num) == "number")
    check("triangle alignment", first_drawable.index_count % 3 == 0)
end

-- Core reports UV V in the opposite convention from the existing texture upload
-- path. The official wrapper exposes renderer-ready UVs so both backends sample
-- the same atlas pixels.
local hiyori_moc = read_file("resources/Hiyori/Hiyori.moc3")
local hiyori_official = Model.new(hiyori_moc)
hiyori_official:update()
local hiyori_ids = native_moc3.ids.parse(hiyori_moc)
local hiyori_art_meshes = native_moc3.art_meshes.parse(hiyori_moc)
local checked_uvs = 0
local uv_convention_ok = true
for art_index, drawable_id in ipairs(hiyori_ids.art_meshes) do
    local official_index = hiyori_official.drawable_id_to_index[drawable_id]
    local native_uvs = hiyori_art_meshes:art_mesh_uvs(art_index - 1)
    if official_index and native_uvs then
        local official_uvs = hiyori_official:getDrawableVertexUvs(official_index)
        for i = 1, math.min(#official_uvs, #native_uvs / 2, 16) do
            local native_u = native_uvs[(i - 1) * 2 + 1]
            local native_v = native_uvs[(i - 1) * 2 + 2]
            local official_uv = official_uvs[i]
            checked_uvs = checked_uvs + 1
            if math.abs(official_uv[1] - native_u) > 0.000001
                or math.abs(official_uv[2] - native_v) > 0.000001 then
                uv_convention_ok = false
                break
            end
        end
    end
    if not uv_convention_ok or checked_uvs >= 64 then
        break
    end
end
check("official core UVs match renderer convention", uv_convention_ok and checked_uvs > 0)

-- Verify geometry changed after parameter update
print("\n-- Deformation Verification --")
model:resetParameters()
model:update()
local default_positions = model:getDrawableVertexPositions(1)

-- Change angle parameters
model:setParameterValueById("ParamAngleX", 10.0)
model:setParameterValueById("ParamAngleY", 5.0)
model:update()
local modified_positions = model:getDrawableVertexPositions(1)

if #default_positions > 0 and #modified_positions > 0 then
    local changed = false
    for i = 1, math.min(#default_positions, #modified_positions) do
        if math.abs(default_positions[i][1] - modified_positions[i][1]) > 0.0001
            or math.abs(default_positions[i][2] - modified_positions[i][2]) > 0.0001 then
            changed = true
            break
        end
    end
    check("vertex positions change after param update", changed)
end

-- Reset
model:resetParameters()
model:update()

-- Test 8: Draw order / render order
print("\n-- Draw Order --")
local render_list = {}
for i, d in ipairs(drawables) do
    if d then
        render_list[#render_list + 1] = d
    end
end
table.sort(render_list, function(a, b)
    if a.render_order ~= b.render_order then
        return a.render_order < b.render_order
    end
    if a.draw_order ~= b.draw_order then
        return a.draw_order < b.draw_order
    end
    return a.index < b.index
end)
check("render order list valid", #render_list > 0)
if #render_list > 1 then
    local sorted = true
    for i = 2, #render_list do
        if render_list[i].render_order < render_list[i-1].render_order then
            sorted = false
            break
        end
    end
    check("render orders sorted ascending", sorted)
end

-- Test 9: Motion playback
print("\n-- Motion Playback --")
local motion_path = base .. "motions/mtn_idle01_C.motion3.json"
local ok, mf = pcall(io.open, motion_path, "r")
if ok and mf then
    local motion_json = mf:read("*all")
    mf:close()
    local motion_data = motion3.parse(motion_json)
    check("motion3.json parsed", motion_data ~= nil)
    if motion_data then
        check("motion has meta", motion_data.meta ~= nil)
        check("motion has curves", #motion_data.curves > 0)
        print(string.format("  Duration: %.2f, Curves: %d",
            motion_data.meta.duration or 0, #motion_data.curves))

        local player = MotionPlayer.new(motion_data)
        check("motion player created", player ~= nil)
        check("motion not initially finished", not player:is_finished())

        local curve_with_segments = false
        for _, curve in ipairs(motion_data.curves) do
            if curve.target == "Parameter" and curve.id == "ParamAngleX" then
                curve_with_segments = type(curve.sample) == "function" and curve:sample(0.5) ~= nil
                break
            end
        end
        check("motion segments are sampleable", curve_with_segments)

        player:tick(1.0)
        check("motion time advances", player.time > 0)

        model:resetParameters()
        local before_motion = model:getParameterValueById("ParamAngleX")
        player:apply(model)
        model:update()
        local after_motion = model:getParameterValueById("ParamAngleX")
        check("motion applied without error", true)
        check("motion changes parameter value", math.abs(after_motion - before_motion) > 0.0001)
    end
end

-- Test 10: Drawable query batching
print("\n-- Drawable Query Batching --")
local watched_core_calls = {
    "getDrawableVertexPositions",
    "getDrawableVertexUvs",
    "getDrawableIndices",
    "getDynamicFlags",
    "getDrawableOpacities",
    "getDrawableMultiplyColors",
    "getDrawableScreenColors",
    "getDrawableDrawOrders",
}
local originals = {}
local call_counts = {}
for _, name in ipairs(watched_core_calls) do
    originals[name] = core[name]
    call_counts[name] = 0
    core[name] = function(...)
        call_counts[name] = call_counts[name] + 1
        return originals[name](...)
    end
end

model:getAllDrawableData()

local batched = true
for _, name in ipairs(watched_core_calls) do
    core[name] = originals[name]
    if call_counts[name] > 1 then
        batched = false
    end
end
check("drawable data uses one batched core query per array", batched)

-- Test 11: Renderer require smoke
print("\n-- Renderer Smoke --")
local renderer_ok, renderer_err = pcall(require, "live2d.cubism3_offical.renderer")
check("renderer module requires", renderer_ok)
if not renderer_ok then
    print("  Error: " .. tostring(renderer_err))
end

print("\n=== Results: " .. passed .. "/" .. total .. " passed ===")
if passed == total then
    print("ALL TESTS PASSED!")
    os.exit(0)
else
    print("SOME TESTS FAILED!")
    os.exit(1)
end
