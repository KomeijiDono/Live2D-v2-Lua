-- core_ffi.lua - LuaJIT FFI bindings for Live2D Cubism Core (v3/v4/v5)
-- Independent module; no dependency on existing cubism3 implementation.
-- Uses official Live2DCubismCore.dll / .dylib / .so from core/dll/<platform>/
local ffi = require("ffi")
local bit = require("bit")

local is_win = ffi.os == "Windows"
local is_mac = ffi.os == "OSX"

local CC = is_win and "__stdcall " or ""

ffi.cdef([[
typedef struct csmMoc csmMoc;
typedef struct csmModel csmModel;
typedef unsigned int csmVersion;
typedef unsigned int csmMocVersion;
typedef unsigned char csmFlags;
typedef int csmParameterType;

typedef void (*csmLogFunction)(const char* message);

typedef struct { float X; float Y; } csmVector2;
typedef struct { float X; float Y; float Z; float W; } csmVector4;

// Alignment constants (not callable since they're enums, referenced in code)
enum {
    csmAlignofMoc = 64,
    csmAlignofModel = 16
};

// Constant drawable flags
enum {
    csmBlendAdditive = 1,
    csmBlendMultiplicative = 2,
    csmIsDoubleSided = 4,
    csmIsInvertedMask = 8
};

// Dynamic drawable flags
enum {
    csmIsVisible = 1,
    csmVisibilityDidChange = 2,
    csmOpacityDidChange = 4,
    csmDrawOrderDidChange = 8,
    csmRenderOrderDidChange = 16,
    csmVertexPositionsDidChange = 32,
    csmBlendColorDidChange = 64
};

// MOC versions
enum {
    csmMocVersion_Unknown = 0,
    csmMocVersion_30 = 1,
    csmMocVersion_33 = 2,
    csmMocVersion_40 = 3,
    csmMocVersion_42 = 4,
    csmMocVersion_50 = 5,
    csmMocVersion_53 = 6
};

// Color blend types
enum {
    csmColorBlendType_Normal = 0,
    csmColorBlendType_Add = 3,
    csmColorBlendType_AddGlow = 4,
    csmColorBlendType_Darken = 5,
    csmColorBlendType_Multiply = 6,
    csmColorBlendType_ColorBurn = 7,
    csmColorBlendType_LinearBurn = 8,
    csmColorBlendType_Lighten = 9,
    csmColorBlendType_Screen = 10,
    csmColorBlendType_ColorDodge = 11,
    csmColorBlendType_Overlay = 12,
    csmColorBlendType_SoftLight = 13,
    csmColorBlendType_HardLight = 14,
    csmColorBlendType_LinearLight = 15,
    csmColorBlendType_Hue = 16,
    csmColorBlendType_Color = 17,
    csmColorBlendType_AddCompatible = 1,
    csmColorBlendType_MultiplyCompatible = 2
};
]])

ffi.cdef(CC .. "csmVersion csmGetVersion();")
ffi.cdef(CC .. "csmMocVersion csmGetLatestMocVersion();")
ffi.cdef(CC .. "csmMocVersion csmGetMocVersion(const void* address, const unsigned int size);")
ffi.cdef(CC .. "int csmHasMocConsistency(void* address, const unsigned int size);")
ffi.cdef(CC .. "csmLogFunction csmGetLogFunction();")
ffi.cdef(CC .. "void csmSetLogFunction(csmLogFunction handler);")
ffi.cdef(CC .. "csmMoc* csmReviveMocInPlace(void* address, const unsigned int size);")
ffi.cdef(CC .. "unsigned int csmGetSizeofModel(const csmMoc* moc);")
ffi.cdef(CC .. "csmModel* csmInitializeModelInPlace(const csmMoc* moc, void* address, const unsigned int size);")
ffi.cdef(CC .. "void csmUpdateModel(csmModel* model);")
ffi.cdef(CC .. "const int* csmGetRenderOrders(const csmModel* model);")
ffi.cdef(CC .. "void csmReadCanvasInfo(const csmModel* model, csmVector2* outSizeInPixels, csmVector2* outOriginInPixels, float* outPixelsPerUnit);")
ffi.cdef(CC .. "int csmGetParameterCount(const csmModel* model);")
ffi.cdef(CC .. "const char** csmGetParameterIds(const csmModel* model);")
ffi.cdef(CC .. "const csmParameterType* csmGetParameterTypes(const csmModel* model);")
ffi.cdef(CC .. "const float* csmGetParameterMinimumValues(const csmModel* model);")
ffi.cdef(CC .. "const float* csmGetParameterMaximumValues(const csmModel* model);")
ffi.cdef(CC .. "const float* csmGetParameterDefaultValues(const csmModel* model);")
ffi.cdef(CC .. "float* csmGetParameterValues(csmModel* model);")
ffi.cdef(CC .. "const int* csmGetParameterRepeats(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetParameterKeyCounts(const csmModel* model);")
ffi.cdef(CC .. "const float** csmGetParameterKeyValues(const csmModel* model);")
ffi.cdef(CC .. "int csmGetPartCount(const csmModel* model);")
ffi.cdef(CC .. "const char** csmGetPartIds(const csmModel* model);")
ffi.cdef(CC .. "float* csmGetPartOpacities(csmModel* model);")
ffi.cdef(CC .. "const int* csmGetPartParentPartIndices(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetPartOffscreenIndices(const csmModel* model);")
ffi.cdef(CC .. "int csmGetDrawableCount(const csmModel* model);")
ffi.cdef(CC .. "const char** csmGetDrawableIds(const csmModel* model);")
ffi.cdef(CC .. "const csmFlags* csmGetDrawableConstantFlags(const csmModel* model);")
ffi.cdef(CC .. "const csmFlags* csmGetDrawableDynamicFlags(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetDrawableBlendModes(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetDrawableTextureIndices(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetDrawableDrawOrders(const csmModel* model);")
ffi.cdef(CC .. "const float* csmGetDrawableOpacities(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetDrawableMaskCounts(const csmModel* model);")
ffi.cdef(CC .. "const int** csmGetDrawableMasks(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetDrawableVertexCounts(const csmModel* model);")
ffi.cdef(CC .. "const csmVector2** csmGetDrawableVertexPositions(const csmModel* model);")
ffi.cdef(CC .. "const csmVector2** csmGetDrawableVertexUvs(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetDrawableIndexCounts(const csmModel* model);")
ffi.cdef(CC .. "const unsigned short** csmGetDrawableIndices(const csmModel* model);")
ffi.cdef(CC .. "const csmVector4* csmGetDrawableMultiplyColors(const csmModel* model);")
ffi.cdef(CC .. "const csmVector4* csmGetDrawableScreenColors(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetDrawableParentPartIndices(const csmModel* model);")
ffi.cdef(CC .. "void csmResetDrawableDynamicFlags(csmModel* model);")
ffi.cdef(CC .. "int csmGetOffscreenCount(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetOffscreenBlendModes(const csmModel* model);")
ffi.cdef(CC .. "const float* csmGetOffscreenOpacities(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetOffscreenOwnerIndices(const csmModel* model);")
ffi.cdef(CC .. "const csmVector4* csmGetOffscreenMultiplyColors(const csmModel* model);")
ffi.cdef(CC .. "const csmVector4* csmGetOffscreenScreenColors(const csmModel* model);")
ffi.cdef(CC .. "const int* csmGetOffscreenMaskCounts(const csmModel* model);")
ffi.cdef(CC .. "const int** csmGetOffscreenMasks(const csmModel* model);")
ffi.cdef(CC .. "const csmFlags* csmGetOffscreenConstantFlags(const csmModel* model);")

local core_lib
local function load_core_lib()
    local lib_names = {}
    if is_win then
        local home = os.getenv("Live2DCubismCorePath") or ""
        if home ~= "" then
            lib_names[#lib_names + 1] = home .. "/Live2DCubismCore.dll"
        end
        lib_names[#lib_names + 1] = "core/dll/windows/x86_64/Live2DCubismCore.dll"
        lib_names[#lib_names + 1] = "./core/dll/windows/x86_64/Live2DCubismCore.dll"
        lib_names[#lib_names + 1] = "core/dll/windows/x86/Live2DCubismCore.dll"
    elseif is_mac then
        lib_names[#lib_names + 1] = "core/dll/macos/libLive2DCubismCore.dylib"
        lib_names[#lib_names + 1] = "./core/dll/macos/libLive2DCubismCore.dylib"
    else
        lib_names[#lib_names + 1] = "core/dll/linux/x86_64/libLive2DCubismCore.so"
        lib_names[#lib_names + 1] = "./core/dll/linux/x86_64/libLive2DCubismCore.so"
        lib_names[#lib_names + 1] = "Live2DCubismCore"
    end
    for _, name in ipairs(lib_names) do
        local ok, lib = pcall(ffi.load, name)
        if ok then
            return lib
        end
    end
    return nil
end

core_lib = load_core_lib()
if not core_lib then
    error("Cannot load Live2DCubismCore library. Place it in core/dll/<platform>/ or set Live2DCubismCorePath env var.")
end

local M = {}

M.ALIGN_MOC = 64
M.ALIGN_MODEL = 16

M.VERSION_Unknown = 0
M.VERSION_30 = 1
M.VERSION_33 = 2
M.VERSION_40 = 3
M.VERSION_42 = 4
M.VERSION_50 = 5
M.VERSION_53 = 6

M.BLEND_NORMAL = 0
M.BLEND_ADD = 3
M.BLEND_MULTIPLY = 6

M.FLAG_BLEND_ADDITIVE = 1
M.FLAG_BLEND_MULTIPLICATIVE = 2
M.FLAG_DOUBLE_SIDED = 4
M.FLAG_INVERTED_MASK = 8

M.FLAG_VISIBLE = 1

function M.getVersion()
    return core_lib.csmGetVersion()
end

function M.getLatestMocVersion()
    return core_lib.csmGetLatestMocVersion()
end

function M.getMocVersion(address, size)
    return core_lib.csmGetMocVersion(address, size)
end

function M.hasMocConsistency(address, size)
    return core_lib.csmHasMocConsistency(address, size) ~= 0
end

function M.reviveMocInPlace(address, size)
    return core_lib.csmReviveMocInPlace(address, size)
end

function M.getSizeofModel(moc)
    return core_lib.csmGetSizeofModel(moc)
end

function M.initializeModelInPlace(moc, address, size)
    return core_lib.csmInitializeModelInPlace(moc, address, size)
end

function M.updateModel(model)
    core_lib.csmUpdateModel(model)
end

function M.getRenderOrders(model)
    return core_lib.csmGetRenderOrders(model)
end

function M.readCanvasInfo(model)
    local sizeInPixels = ffi.new("csmVector2[1]")
    local originInPixels = ffi.new("csmVector2[1]")
    local pixelsPerUnit = ffi.new("float[1]")
    core_lib.csmReadCanvasInfo(model, sizeInPixels, originInPixels, pixelsPerUnit)
    return {
        width = sizeInPixels[0].X,
        height = sizeInPixels[0].Y,
        origin_x = originInPixels[0].X,
        origin_y = originInPixels[0].Y,
        pixels_per_unit = pixelsPerUnit[0],
    }
end

function M.getParameterCount(model)
    return core_lib.csmGetParameterCount(model)
end

function M.getParameterIds(model, count)
    local ptr = core_lib.csmGetParameterIds(model)
    if ptr == nil then return {} end
    local ids = {}
    for i = 0, count - 1 do
        ids[i + 1] = ffi.string(ptr[i])
    end
    return ids
end

function M.getParameterValues(model, count)
    local ptr = core_lib.csmGetParameterValues(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.setParameterValue(model, index, value)
    local ptr = core_lib.csmGetParameterValues(model)
    if ptr == nil then return end
    ptr[index] = value
end

function M.setParameterValues(model, values)
    local ptr = core_lib.csmGetParameterValues(model)
    if ptr == nil then return end
    for i, v in ipairs(values) do
        ptr[i - 1] = v
    end
end

function M.getParameterMinimumValues(model, count)
    local ptr = core_lib.csmGetParameterMinimumValues(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getParameterMaximumValues(model, count)
    local ptr = core_lib.csmGetParameterMaximumValues(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getParameterDefaultValues(model, count)
    local ptr = core_lib.csmGetParameterDefaultValues(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getPartCount(model)
    return core_lib.csmGetPartCount(model)
end

function M.getPartIds(model, count)
    local ptr = core_lib.csmGetPartIds(model)
    if ptr == nil then return {} end
    local ids = {}
    for i = 0, count - 1 do
        ids[i + 1] = ffi.string(ptr[i])
    end
    return ids
end

function M.getPartOpacities(model, count)
    local ptr = core_lib.csmGetPartOpacities(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.setPartOpacity(model, index, value)
    local ptr = core_lib.csmGetPartOpacities(model)
    if ptr == nil then return end
    ptr[index] = value
end

function M.getPartParentPartIndices(model, count)
    local ptr = core_lib.csmGetPartParentPartIndices(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getPartOffscreenIndices(model, count)
    local ptr = core_lib.csmGetPartOffscreenIndices(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getDrawableCount(model)
    return core_lib.csmGetDrawableCount(model)
end

function M.getDrawableIds(model, count)
    local ptr = core_lib.csmGetDrawableIds(model)
    if ptr == nil then return {} end
    local ids = {}
    for i = 0, count - 1 do
        ids[i + 1] = ffi.string(ptr[i])
    end
    return ids
end

function M.getDrawableConstantFlags(model, count)
    local ptr = core_lib.csmGetDrawableConstantFlags(model)
    if ptr == nil then return {} end
    local flags = {}
    for i = 0, count - 1 do
        flags[i + 1] = ptr[i]
    end
    return flags
end

function M.getDrawableBlendModes(model, count)
    local ptr = core_lib.csmGetDrawableBlendModes(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getDrawableTextureIndices(model, count)
    local ptr = core_lib.csmGetDrawableTextureIndices(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getDrawableDrawOrders(model, count)
    local ptr = core_lib.csmGetDrawableDrawOrders(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getDrawableRenderOrders(model)
    local ptr = core_lib.csmGetRenderOrders(model)
    if ptr == nil then return {} end
    return ptr
end

function M.getDrawableOpacities(model, count)
    local ptr = core_lib.csmGetDrawableOpacities(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getDrawableMaskCounts(model, count)
    local ptr = core_lib.csmGetDrawableMaskCounts(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getDrawableMasks(model, count)
    local ptr = core_lib.csmGetDrawableMasks(model)
    if ptr == nil then return {} end
    local masks = {}
    for i = 0, count - 1 do
        local mask_count = core_lib.csmGetDrawableMaskCounts(model)[i]
        local drawable_masks = {}
        if mask_count > 0 and ptr[i] ~= nil then
            for j = 0, mask_count - 1 do
                drawable_masks[j + 1] = ptr[i][j]
            end
        end
        masks[i + 1] = drawable_masks
    end
    return masks
end

function M.getDrawableVertexCounts(model, count)
    local ptr = core_lib.csmGetDrawableVertexCounts(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getDrawableVertexPositions(model, count)
    local ptr = core_lib.csmGetDrawableVertexPositions(model)
    if ptr == nil then return {} end
    local positions = {}
    for i = 0, count - 1 do
        local vertex_count = core_lib.csmGetDrawableVertexCounts(model)[i]
        local drawable_verts = {}
        local vert_ptr = ptr[i]
        if vertex_count > 0 and vert_ptr ~= nil then
            for j = 0, vertex_count - 1 do
                drawable_verts[j + 1] = { vert_ptr[j].X, vert_ptr[j].Y }
            end
        end
        positions[i + 1] = drawable_verts
    end
    return positions
end

function M.getDrawableVertexUvs(model, count)
    local ptr = core_lib.csmGetDrawableVertexUvs(model)
    if ptr == nil then return {} end
    local uvs = {}
    for i = 0, count - 1 do
        local vertex_count = core_lib.csmGetDrawableVertexCounts(model)[i]
        local drawable_uvs = {}
        local uv_ptr = ptr[i]
        if vertex_count > 0 and uv_ptr ~= nil then
            for j = 0, vertex_count - 1 do
                drawable_uvs[j + 1] = { uv_ptr[j].X, 1.0 - uv_ptr[j].Y }
            end
        end
        uvs[i + 1] = drawable_uvs
    end
    return uvs
end

function M.getDrawableIndexCounts(model, count)
    local ptr = core_lib.csmGetDrawableIndexCounts(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getDrawableIndices(model, count)
    local ptr = core_lib.csmGetDrawableIndices(model)
    if ptr == nil then return {} end
    local indices = {}
    for i = 0, count - 1 do
        local index_count = core_lib.csmGetDrawableIndexCounts(model)[i]
        local drawable_indices = {}
        local idx_ptr = ptr[i]
        if index_count > 0 and idx_ptr ~= nil then
            for j = 0, index_count - 1 do
                drawable_indices[j + 1] = idx_ptr[j]
            end
        end
        indices[i + 1] = drawable_indices
    end
    return indices
end

function M.getDrawableMultiplyColors(model, count)
    local ptr = core_lib.csmGetDrawableMultiplyColors(model)
    if ptr == nil then return {} end
    local colors = {}
    for i = 0, count - 1 do
        colors[i + 1] = { ptr[i].X, ptr[i].Y, ptr[i].Z, ptr[i].W }
    end
    return colors
end

function M.getDrawableScreenColors(model, count)
    local ptr = core_lib.csmGetDrawableScreenColors(model)
    if ptr == nil then return {} end
    local colors = {}
    for i = 0, count - 1 do
        colors[i + 1] = { ptr[i].X, ptr[i].Y, ptr[i].Z, ptr[i].W }
    end
    return colors
end

function M.getDrawableParentPartIndices(model, count)
    local ptr = core_lib.csmGetDrawableParentPartIndices(model)
    if ptr == nil then return {} end
    local values = {}
    for i = 0, count - 1 do
        values[i + 1] = ptr[i]
    end
    return values
end

function M.getDynamicFlags(model, count)
    local ptr = core_lib.csmGetDrawableDynamicFlags(model)
    if ptr == nil then return {} end
    local flags = {}
    for i = 0, count - 1 do
        flags[i + 1] = ptr[i]
    end
    return flags
end

function M.isVisible(dynamic_flags)
    return bit.band(dynamic_flags, M.FLAG_VISIBLE) ~= 0
end

local function align_up(addr, alignment)
    local mod = addr % alignment
    if mod == 0 then return addr end
    return addr + alignment - mod
end

function M.allocAligned(size, alignment)
    local buf = ffi.new("uint8_t[?]", size + alignment)
    local raw_ptr = tonumber(ffi.cast("uintptr_t", buf))
    local aligned_addr = align_up(raw_ptr, alignment)
    local off = aligned_addr - raw_ptr
    return buf, off
end

function M.loadMocBytes(moc_bytes)
    local size = #moc_bytes
    local buf_size = size + M.ALIGN_MOC
    local buf = ffi.new("uint8_t[?]", buf_size)
    local raw_addr = tonumber(ffi.cast("uintptr_t", buf))
    local aligned_addr = align_up(raw_addr, M.ALIGN_MOC)
    local off = aligned_addr - raw_addr
    ffi.copy(buf + off, moc_bytes, size)
    return ffi.cast("void*", buf + off), size, buf
end

return M
