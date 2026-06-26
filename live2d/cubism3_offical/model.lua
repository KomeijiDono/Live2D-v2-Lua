-- model.lua - Cubism Model (FFI Core path)
-- Wraps official Live2DCubismCore lifecycle: revive moc -> initialize model -> update -> query.
-- Independent of existing cubism3/ native parser.

local ffi = require("ffi")
local core = require("live2d.cubism3_offical.core_ffi")

local function align_up(addr, alignment)
    local mod = addr % alignment
    if mod == 0 then return addr end
    return addr + alignment - mod
end

local Model = {}
Model.__index = Model

function Model.new(moc_bytes)
    local self = setmetatable({}, Model)

    local moc_ptr, moc_size, moc_buf = core.loadMocBytes(moc_bytes)
    self._moc_buf = moc_buf

    if not core.hasMocConsistency(moc_ptr, moc_size) then
        error("MOC consistency check failed")
    end

    local moc_version = core.getMocVersion(moc_ptr, moc_size)
    self.moc_version = moc_version
    local version_names = {"Unknown", "3.0", "3.3", "4.0", "4.2", "5.0", "5.3"}
    self.moc_version_name = version_names[moc_version + 1] or "Unknown"

    self.moc = core.reviveMocInPlace(moc_ptr, moc_size)
    if self.moc == nil then
        error("Failed to revive MOC")
    end

    self.model_size = core.getSizeofModel(self.moc)
    if self.model_size == 0 then
        error("Failed to get model size")
    end

    local model_buf_size = self.model_size + core.ALIGN_MODEL
    self.model_buf = ffi.new("uint8_t[?]", model_buf_size)
    local raw_addr = tonumber(ffi.cast("uintptr_t", self.model_buf))
    local aligned_addr = align_up(raw_addr, core.ALIGN_MODEL)
    self.model_off = aligned_addr - raw_addr

    self.model = core.initializeModelInPlace(self.moc,
        ffi.cast("void*", self.model_buf + self.model_off),
        self.model_size)
    if self.model == nil then
        error("Failed to initialize model")
    end

    -- Cache counts
    self.drawable_count = core.getDrawableCount(self.model)
    self.parameter_count = core.getParameterCount(self.model)
    self.part_count = core.getPartCount(self.model)

    -- Cache arrays (pointer-based, not copied yet)
    self._drawable_count = self.drawable_count
    self._parameter_count = self.parameter_count
    self._part_count = self.part_count

    -- Read canvas info
    self.canvas = core.readCanvasInfo(self.model)

    -- Load parameter metadata
    self:load_parameter_info()
    self:load_part_info()
    self:load_drawable_static_info()

    return self
end

function Model:load_parameter_info()
    local count = self._parameter_count
    self.parameter_ids = core.getParameterIds(self.model, count)
    self.parameter_min = core.getParameterMinimumValues(self.model, count)
    self.parameter_max = core.getParameterMaximumValues(self.model, count)
    self.parameter_defaults = core.getParameterDefaultValues(self.model, count)

    -- Build ID -> index map
    self.param_id_to_index = {}
    for i, id in ipairs(self.parameter_ids) do
        self.param_id_to_index[id] = i
    end
end

function Model:load_part_info()
    local count = self._part_count
    self.part_ids = core.getPartIds(self.model, count)
    self.part_parents = core.getPartParentPartIndices(self.model, count)
    self.part_offscreen = core.getPartOffscreenIndices(self.model, count)

    self.part_id_to_index = {}
    for i, id in ipairs(self.part_ids) do
        self.part_id_to_index[id] = i
    end
end

function Model:load_drawable_static_info()
    local count = self._drawable_count
    self.drawable_ids = core.getDrawableIds(self.model, count)
    self.drawable_constant_flags = core.getDrawableConstantFlags(self.model, count)
    self.drawable_texture_indices = core.getDrawableTextureIndices(self.model, count)
    self.drawable_blend_modes = core.getDrawableBlendModes(self.model, count)
    self.drawable_mask_counts = core.getDrawableMaskCounts(self.model, count)
    self.drawable_masks = core.getDrawableMasks(self.model, count)
    self.drawable_parent_parts = core.getDrawableParentPartIndices(self.model, count)
    self.drawable_vertex_counts = core.getDrawableVertexCounts(self.model, count)
    self.drawable_index_counts = core.getDrawableIndexCounts(self.model, count)

    self.drawable_id_to_index = {}
    for i, id in ipairs(self.drawable_ids) do
        self.drawable_id_to_index[id] = i
    end
end

function Model:update()
    core.updateModel(self.model)
end

function Model:setParameterValue(index, value)
    core.setParameterValue(self.model, index - 1, value)
end

function Model:setParameterValueById(id, value)
    local idx = self.param_id_to_index[id]
    if idx then
        core.setParameterValue(self.model, idx - 1, value)
    end
end

function Model:getParameterValue(index)
    return core.getParameterValues(self.model, self._parameter_count)[index]
end

function Model:getParameterValueById(id)
    local idx = self.param_id_to_index[id]
    if idx then
        return core.getParameterValues(self.model, self._parameter_count)[idx]
    end
    return 0
end

function Model:resetParameters()
    for i = 1, self._parameter_count do
        core.setParameterValue(self.model, i - 1, self.parameter_defaults[i])
    end
end

function Model:getPartOpacities()
    return core.getPartOpacities(self.model, self._part_count)
end

function Model:setPartOpacity(index, value)
    core.setPartOpacity(self.model, index - 1, value)
end

function Model:setPartOpacityById(id, value)
    local idx = self.part_id_to_index[id]
    if idx then
        core.setPartOpacity(self.model, idx - 1, value)
    end
end

function Model:resetPartOpacities()
    for i = 1, self._part_count do
        core.setPartOpacity(self.model, i - 1, 1.0)
    end
end

function Model:getRenderOrders()
    return core.getDrawableRenderOrders(self.model)
end

function Model:getDynamicFlags()
    return core.getDynamicFlags(self.model, self._drawable_count)
end

function Model:getDrawableVertexPositions(drawable_index)
    local count = self._drawable_count
    return core.getDrawableVertexPositions(self.model, count)[drawable_index]
end

function Model:getDrawableVertexUvs(drawable_index)
    local count = self._drawable_count
    return core.getDrawableVertexUvs(self.model, count)[drawable_index]
end

function Model:getDrawableIndices(drawable_index)
    local count = self._drawable_count
    return core.getDrawableIndices(self.model, count)[drawable_index]
end

function Model:getDrawableMultiplyColor(drawable_index)
    local count = self._drawable_count
    return core.getDrawableMultiplyColors(self.model, count)[drawable_index]
end

function Model:getDrawableScreenColor(drawable_index)
    local count = self._drawable_count
    return core.getDrawableScreenColors(self.model, count)[drawable_index]
end

function Model:getDrawableOpacity(drawable_index)
    local count = self._drawable_count
    return core.getDrawableOpacities(self.model, count)[drawable_index]
end

function Model:getDrawableDrawOrder(drawable_index)
    local count = self._drawable_count
    return core.getDrawableDrawOrders(self.model, count)[drawable_index]
end

function Model:getDrawableData(index)
    local vi = self.drawable_vertex_counts[index]
    local ii = self.drawable_index_counts[index]
    if vi == 0 and ii == 0 then
        return nil
    end

    local frame = self._drawable_frame
    local positions = frame and frame.positions[index] or self:getDrawableVertexPositions(index)
    local uvs = frame and frame.uvs[index] or self:getDrawableVertexUvs(index)
    local indices = frame and frame.indices[index] or self:getDrawableIndices(index)
    local dynamic_flag = frame and frame.dynamic_flags[index] or self:getDynamicFlags()[index]
    local opacity = frame and frame.opacities[index] or self:getDrawableOpacity(index)
    local multiply_color = frame and frame.multiply_colors[index] or self:getDrawableMultiplyColor(index)
    local screen_color = frame and frame.screen_colors[index] or self:getDrawableScreenColor(index)
    local draw_order = frame and frame.draw_orders[index] or self:getDrawableDrawOrder(index)
    local render_order = frame and frame.render_orders and (frame.render_orders[index - 1] or 0) or nil

    local data = {
        index = index,
        id = self.drawable_ids[index],
        vertex_count = vi,
        index_count = ii,
        positions = positions,
        uvs = uvs,
        indices = indices,
        opacity = opacity,
        constant_flags = self.drawable_constant_flags[index],
        dynamic_flags = dynamic_flag,
        texture_index = self.drawable_texture_indices[index],
        blend_mode_num = self.drawable_blend_modes[index],
        masks = self.drawable_masks[index],
        mask_count = self.drawable_mask_counts[index],
        parent_part = self.drawable_parent_parts[index],
        multiply_color = multiply_color,
        screen_color = screen_color,
        draw_order = draw_order,
    }
    if render_order ~= nil then
        data.render_order = render_order
    end
    return data
end

function Model:getAllDrawableData()
    self:update()

    local count = self._drawable_count
    self._drawable_frame = {
        positions = core.getDrawableVertexPositions(self.model, count),
        uvs = core.getDrawableVertexUvs(self.model, count),
        indices = core.getDrawableIndices(self.model, count),
        dynamic_flags = core.getDynamicFlags(self.model, count),
        opacities = core.getDrawableOpacities(self.model, count),
        multiply_colors = core.getDrawableMultiplyColors(self.model, count),
        screen_colors = core.getDrawableScreenColors(self.model, count),
        draw_orders = core.getDrawableDrawOrders(self.model, count),
        render_orders = core.getDrawableRenderOrders(self.model),
    }

    local drawables = {}
    for i = 1, count do
        local data = self:getDrawableData(i)
        drawables[i] = data
    end
    return drawables
end

return Model
