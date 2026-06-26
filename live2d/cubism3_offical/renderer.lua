-- renderer.lua - OpenGL renderer for Cubism3/4/5 drawables (FFI Core path)
-- Uses official Cubism Core for vertex/index/opacity/blend data.
-- Handles clipping masks via stencil buffer.
-- Independent of existing cubism3/ renderer.

local ffi = require("ffi")
local image_loader = require("live2d.image_loader")

local GL_STENCIL_TEST = 0x0B90
local GL_ALPHA_TEST = 0x0BC0
local GL_STENCIL_BUFFER_BIT = 0x00000400
local GL_ALWAYS = 0x0207
local GL_EQUAL = 0x0202
local GL_NOTEQUAL = 0x0205
local GL_KEEP = 0x1E00
local GL_REPLACE = 0x1E01
local GL_GREATER = 0x0204

local VERTEX_SHADER = [[
#version 120
attribute vec2 a_position;
attribute vec2 a_uv;
attribute float a_opacity;
attribute vec4 a_multiply;
attribute vec4 a_screen;

varying vec2 v_uv;
varying float v_opacity;
varying vec4 v_multiply;
varying vec4 v_screen;

uniform mat4 u_projection;

void main() {
    gl_Position = u_projection * vec4(a_position, 0.0, 1.0);
    v_uv = a_uv;
    v_opacity = a_opacity;
    v_multiply = a_multiply;
    v_screen = a_screen;
}
]]

local FRAGMENT_SHADER = [[
#version 120
varying vec2 v_uv;
varying float v_opacity;
varying vec4 v_multiply;
varying vec4 v_screen;

uniform sampler2D u_texture;

void main() {
    vec4 tex = texture2D(u_texture, v_uv);
    vec3 blended = tex.rgb * v_multiply.rgb;
    blended = blended + v_screen.rgb * (1.0 - tex.rgb);
    gl_FragColor = vec4(blended, tex.a * v_opacity);
}
]]

local Renderer = {}
Renderer.__index = Renderer

function Renderer.new(gl)
    local self = setmetatable({}, Renderer)
    self.gl = gl
    self.shader = nil
    self.textures = {}
    self.vao = nil
    self.vbo = nil
    self.ibo = nil
    self.vertex_data = nil
    self.vertex_capacity = 0
    self.index_data = nil
    self.index_capacity = 0
    self:initShader()
    return self
end

function Renderer:initShader()
    local gl = self.gl

    local function compileShader(shaderType, source)
        local shader = gl.glCreateShader(shaderType)
        local src = ffi.new("const char*[1]", ffi.new("const char*", source))
        local length = ffi.new("int[1]", #source)
        gl.glShaderSource(shader, 1, src, length)
        gl.glCompileShader(shader)

        local status = ffi.new("int[1]", 0)
        gl.glGetShaderiv(shader, 0x8B81, status)
        if status[0] == 0 then
            local infoLog = ffi.new("char[1024]")
            gl.glGetShaderInfoLog(shader, 1024, nil, infoLog)
            error("Shader compile failed: " .. ffi.string(infoLog))
        end
        return shader
    end

    local vertShader = compileShader(0x8B31, VERTEX_SHADER)
    local fragShader = compileShader(0x8B30, FRAGMENT_SHADER)

    local prog = gl.glCreateProgram()
    gl.glAttachShader(prog, vertShader)
    gl.glAttachShader(prog, fragShader)
    gl.glLinkProgram(prog)

    local status = ffi.new("int[1]", 0)
    gl.glGetProgramiv(prog, 0x8B82, status)
    if status[0] == 0 then
        local infoLog = ffi.new("char[1024]")
        gl.glGetProgramInfoLog(prog, 1024, nil, infoLog)
        error("Program link failed: " .. ffi.string(infoLog))
    end

    gl.glDeleteShader(vertShader)
    gl.glDeleteShader(fragShader)

    self.shader = prog
    self.u_projection = gl.glGetUniformLocation(prog, "u_projection")
    self.u_texture = gl.glGetUniformLocation(prog, "u_texture")
    self.a_position = gl.glGetAttribLocation(prog, "a_position")
    self.a_uv = gl.glGetAttribLocation(prog, "a_uv")
    self.a_opacity = gl.glGetAttribLocation(prog, "a_opacity")
    self.a_multiply = gl.glGetAttribLocation(prog, "a_multiply")
    self.a_screen = gl.glGetAttribLocation(prog, "a_screen")

    local vao = ffi.new("GLuint[1]")
    local vbo = ffi.new("GLuint[1]")
    local ibo = ffi.new("GLuint[1]")

    local has_vao = pcall(function()
        if gl.glGenVertexArrays then
            gl.glGenVertexArrays(1, vao)
        end
    end)

    if vao[0] and vao[0] ~= 0 then
        self.vao = vao[0]
    end

    gl.glGenBuffers(1, vbo)
    gl.glGenBuffers(1, ibo)
    self.vbo = vbo[0]
    self.ibo = ibo[0]
end

function Renderer:loadTexture(texturePath)
    local gl = self.gl
    if self.textures[texturePath] then
        return self.textures[texturePath]
    end

    local width, height, data = image_loader.loadImage(texturePath)
    if not width or not data then
        error("Failed to load texture: " .. texturePath)
    end

    local texId = ffi.new("GLuint[1]")
    gl.glGenTextures(1, texId)
    gl.glBindTexture(0x0DE1, texId[0])
    gl.glTexParameteri(0x0DE1, 0x2801, 0x2601)
    gl.glTexParameteri(0x0DE1, 0x2800, 0x2601)
    gl.glTexParameteri(0x0DE1, 0x2802, 0x812F)
    gl.glTexParameteri(0x0DE1, 0x2803, 0x812F)
    gl.glTexImage2D(0x0DE1, 0, 0x1908, width, height, 0, 0x1908, 0x1401, data)

    self.textures[texturePath] = texId[0]
    return texId[0]
end

function Renderer:ensureTexture(texturePath)
    if self.textures[texturePath] then
        return self.textures[texturePath]
    end
    return self:loadTexture(texturePath)
end

function Renderer:renderModel(model, textures, projection)
    local gl = self.gl
    gl.glUseProgram(self.shader)

    local drawables = model:getAllDrawableData()

    -- Build render order list
    local render_list = {}
    for i, d in ipairs(drawables) do
        if d and d.opacity > 0.001 then
            render_list[#render_list + 1] = d
        end
    end

    -- Sort by render_order (from MOC3 slot 87), then draw_order as tiebreaker
    table.sort(render_list, function(a, b)
        if a.render_order ~= b.render_order then
            return a.render_order < b.render_order
        end
        if a.draw_order ~= b.draw_order then
            return a.draw_order < b.draw_order
        end
        return a.index < b.index
    end)

    for _, d in ipairs(render_list) do
        if d.mask_count > 0 and gl.glStencilFunc and gl.glStencilOp and gl.glStencilMask then
            self:drawClippedDrawable(d, model, textures, projection)
        else
            self:drawDrawable(d, textures, projection)
        end
    end
end

function Renderer:drawClippedDrawable(d, model, textures, projection)
    local gl = self.gl

    gl.glEnable(GL_STENCIL_TEST)
    if gl.glAlphaFunc then
        gl.glEnable(GL_ALPHA_TEST)
        gl.glAlphaFunc(GL_GREATER, 0.01)
    end

    gl.glClear(GL_STENCIL_BUFFER_BIT)
    gl.glColorMask(0, 0, 0, 0)
    gl.glStencilMask(0xFF)
    gl.glStencilFunc(GL_ALWAYS, 1, 0xFF)
    gl.glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)

    for _, mask_idx in ipairs(d.masks) do
        if mask_idx >= 0 then
            local mask_data = model:getDrawableData(mask_idx + 1)
            if mask_data then
                -- Force mask opacity to 1.0 for stencil population
                local saved_opacity = mask_data.opacity
                mask_data.opacity = 1.0
                self:drawDrawable(mask_data, textures, projection)
                mask_data.opacity = saved_opacity
            end
        end
    end

    gl.glColorMask(1, 1, 1, 1)
    gl.glStencilMask(0x00)
    local inverted_mask = bit.band(d.constant_flags, 8) ~= 0
    local stencil_func = inverted_mask and GL_NOTEQUAL or GL_EQUAL
    gl.glStencilFunc(stencil_func, 1, 0xFF)
    gl.glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)

    self:drawDrawable(d, textures, projection)

    gl.glStencilMask(0xFF)
    gl.glDisable(GL_STENCIL_TEST)
    if gl.glAlphaFunc then
        gl.glDisable(GL_ALPHA_TEST)
    end
end

local function table_offset(t, n)
    n = n or 0
    local mt = { __index = function(tbl, key)
        return rawget(tbl, key + n)
    end }
    return setmetatable({}, mt)
end

function Renderer:drawDrawable(d, textures, projection)
    local gl = self.gl
    local positions = d.positions
    local uvs = d.uvs
    local indices = d.indices

    if #indices == 0 then
        return
    end

    local vertex_count = #positions
    local index_count = #indices

    -- 4 floats for multiply + 4 for screen + 1 for opacity + 2 pos + 2 uv = 13
    local vertex_float_count = vertex_count * 13
    if (self.vertex_capacity or 0) < vertex_float_count then
        self.vertex_data = ffi.new("float[?]", vertex_float_count)
        self.vertex_capacity = vertex_float_count
    end
    local vdata = self.vertex_data

    local mc = d.multiply_color or {1, 1, 1, 1}
    local sc = d.screen_color or {0, 0, 0, 0}
    local opacity = d.opacity or 1.0

    for i = 1, vertex_count do
        local off = (i - 1) * 13
        local pos = positions[i]
        local uv = uvs[i]
        vdata[off + 0] = pos[1]
        vdata[off + 1] = pos[2]
        vdata[off + 2] = uv[1]
        vdata[off + 3] = uv[2]
        vdata[off + 4] = opacity
        vdata[off + 5] = mc[1]
        vdata[off + 6] = mc[2]
        vdata[off + 7] = mc[3]
        vdata[off + 8] = mc[4]
        vdata[off + 9] = sc[1]
        vdata[off + 10] = sc[2]
        vdata[off + 11] = sc[3]
        vdata[off + 12] = sc[4]
    end

    if (self.index_capacity or 0) < index_count then
        self.index_data = ffi.new("uint16_t[?]", index_count)
        self.index_capacity = index_count
    end
    local idata = self.index_data
    for i = 1, index_count do
        idata[i - 1] = indices[i]
    end

    -- Texture
    local tex_idx = d.texture_index
    local tex_path
    if textures then
        tex_path = textures[tex_idx + 1]
    end
    local tex_id = 0
    if tex_path then
        tex_id = self:ensureTexture(tex_path)
    end

    -- Blend mode
    local blend_mode = d.blend_mode_num or 0
    if blend_mode == 3 or blend_mode == 1 then
        -- Additive
        gl.glBlendFunc(0x0302, 0x0001)
        gl.glBlendEquationSeparate(0x8006, 0x8006)
    elseif blend_mode == 6 or blend_mode == 2 then
        -- Multiplicative
        gl.glBlendFunc(0x0300, 0x0302)
        gl.glBlendEquationSeparate(0x8006, 0x8006)
    else
        -- Normal
        gl.glBlendFunc(0x0302, 0x0303)
        gl.glBlendEquationSeparate(0x8006, 0x8006)
    end

    -- Upload geometry
    gl.glBindBuffer(0x8892, self.vbo)
    gl.glBufferData(0x8892, vertex_float_count * 4, vdata, 0x88E4)

    gl.glBindBuffer(0x8893, self.ibo)
    gl.glBufferData(0x8893, index_count * 2, idata, 0x88E4)

    -- Vertex attributes
    local stride = 13 * 4

    local a_pos = self.a_position
    local a_uv = self.a_uv
    local a_opacity = self.a_opacity
    local a_multiply = self.a_multiply
    local a_screen = self.a_screen

    if a_pos >= 0 then
        gl.glEnableVertexAttribArray(a_pos)
        gl.glVertexAttribPointer(a_pos, 2, 0x1406, 0, stride, ffi.cast("void*", ffi.cast("intptr_t", 0)))
    end
    if a_uv >= 0 then
        gl.glEnableVertexAttribArray(a_uv)
        gl.glVertexAttribPointer(a_uv, 2, 0x1406, 0, stride, ffi.cast("void*", ffi.cast("intptr_t", 8)))
    end
    if a_opacity >= 0 then
        gl.glEnableVertexAttribArray(a_opacity)
        gl.glVertexAttribPointer(a_opacity, 1, 0x1406, 0, stride, ffi.cast("void*", ffi.cast("intptr_t", 16)))
    end
    if a_multiply >= 0 then
        gl.glEnableVertexAttribArray(a_multiply)
        gl.glVertexAttribPointer(a_multiply, 4, 0x1406, 0, stride, ffi.cast("void*", ffi.cast("intptr_t", 20)))
    end
    if a_screen >= 0 then
        gl.glEnableVertexAttribArray(a_screen)
        gl.glVertexAttribPointer(a_screen, 4, 0x1406, 0, stride, ffi.cast("void*", ffi.cast("intptr_t", 36)))
    end

    gl.glUniformMatrix4fv(self.u_projection, 1, 0, projection)
    gl.glActiveTexture(0x84C0)
    gl.glBindTexture(0x0DE1, tex_id)
    gl.glUniform1i(self.u_texture, 0)

    gl.glDrawElements(0x0004, index_count, 0x1403, nil)

    if a_pos >= 0 then gl.glDisableVertexAttribArray(a_pos) end
    if a_uv >= 0 then gl.glDisableVertexAttribArray(a_uv) end
    if a_opacity >= 0 then gl.glDisableVertexAttribArray(a_opacity) end
    if a_multiply >= 0 then gl.glDisableVertexAttribArray(a_multiply) end
    if a_screen >= 0 then gl.glDisableVertexAttribArray(a_screen) end
end

function Renderer:destroy()
    local gl = self.gl
    if self.shader then
        gl.glDeleteProgram(self.shader)
    end
    if self.vbo then
        gl.glDeleteBuffers(1, ffi.new("GLuint[1]", self.vbo))
    end
    if self.ibo then
        gl.glDeleteBuffers(1, ffi.new("GLuint[1]", self.ibo))
    end
    for _, tex_id in pairs(self.textures) do
        gl.glDeleteTextures(1, ffi.new("GLuint[1]", tex_id))
    end
    self.textures = {}
end

return Renderer
