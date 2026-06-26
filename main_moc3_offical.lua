-- main_moc3_offical.lua - Live2D Cubism3/4/5 Interactive Viewer (Official FFI Core)
-- Uses official Live2DCubismCore.dll via LuaJIT FFI for model loading and deformation.
-- Independent of existing cubism3/ native parser. Can run standalone.
package.path = package.path .. ";./?.lua;./?/init.lua"
io.stdout:setvbuf("no")

local ffi = require("ffi")

print("=== Live2D Cubism3/4/5 Viewer (Official Core) ===")

local sdl2 = require("live2d.sdl2")
sdl2.init()
local W, H = 800, 900
local win = sdl2.createWindow("Live2D Cubism3/4/5 - Offical Core", W, H)
local ctx = sdl2.createGLContext(win)
sdl2.makeCurrent(win, ctx)
sdl2.setSwapInterval(1)

local gl = require("live2d.gl_loader")
gl.ensureExtensions()

gl.glEnable(0x0BE2) -- GL_BLEND
gl.glEnable(0x0BC0) -- GL_TEXTURE_2D

local core = require("live2d.cubism3_offical.core_ffi")
local Model = require("live2d.cubism3_offical.model")
local Renderer = require("live2d.cubism3_offical.renderer")
local MotionPlayer = require("live2d.cubism3_offical.motion")
local model3 = require("live2d.cubism3_offical.json.model3")
local motion3 = require("live2d.cubism3_offical.json.motion3")

print(string.format("  Cubism Core version: 0x%08X", core.getVersion()))
print(string.format("  Latest MOC version: %d", core.getLatestMocVersion()))

-- Load model3.json
local base = "resources/Rana/"
local model_path = base .. "adv_live2d_rana_003_live_01.model3.json"
print("Loading " .. model_path .. "...")
local file = assert(io.open(model_path, "r"))
local model_json = file:read("*all")
file:close()
local model_data = model3.parse(model_json)
assert(model_data, "Failed to parse model3.json")
print(string.format("  Version: %d, Name: %s", model_data.version, model_data.name))
print("  Textures: " .. #model_data.file_references.textures)

-- Load .moc3 binary
local moc_path = base .. model_data.file_references.moc
print("Loading " .. moc_path .. "...")
local file = assert(io.open(moc_path, "rb"))
local moc_bytes = file:read("*all")
file:close()
print("  MOC size: " .. #moc_bytes .. " bytes")

-- Create model via official Core
print("Creating model...")
local model = Model.new(moc_bytes)
print(string.format("  MOC version: %s", model.moc_version_name))
print(string.format("  Parameters: %d, Parts: %d, Drawables: %d",
    model.parameter_count, model.part_count, model.drawable_count))
print(string.format("  Canvas: %.0fx%.0f ppu=%.1f",
    model.canvas.width, model.canvas.height, model.canvas.pixels_per_unit))

-- Load textures
print("Loading textures...")
local renderer = Renderer.new(gl)
local textures = {}
for i, tex_path in ipairs(model_data.file_references.textures) do
    local full_path = base .. tex_path
    textures[i] = full_path
    print("  Texture " .. i .. ": " .. tex_path)
    renderer:loadTexture(full_path)
end

-- Load motions
print("Loading motions...")
local motions = {}
local motion_groups = model_data.file_references.motions
for group_name, refs in pairs(motion_groups) do
    if type(refs) == "table" then
        for _, ref in ipairs(refs) do
            local motion_path = base .. ref.File
            local ok, mf = pcall(io.open, motion_path, "r")
            if ok and mf then
                local motion_json = mf:read("*all")
                mf:close()
                local motion_data, err = motion3.parse(motion_json)
                if motion_data then
                    local player = MotionPlayer.new(motion_data)
                    table.insert(motions, { name = group_name, player = player })
                else
                    print("  Motion parse warning (" .. group_name .. "): " .. tostring(err))
                end
            end
        end
    end
end
print("  Loaded " .. #motions .. " motions")

-- Setup projection matrix
local model_width = model.canvas.width / model.canvas.pixels_per_unit
local model_height = model.canvas.height / model.canvas.pixels_per_unit
local scale = math.min(W / model_width, H / model_height) * 0.8
local proj = ffi.new("float[16]", {
    scale * 2.0 / W, 0, 0, 0,
    0, scale * 2.0 / H, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
})

print("\n=== Starting render loop ===")

local running = true
local frame_count = 0
local target_frame_ms = 1000 / 60
local motion_index = 1
local current_motion = nil
local last_time = sdl2.getTicks()

local function isInsideWindow(x, y)
    return x >= 0 and x < W and y >= 0 and y < H
end

local function playNextMotion()
    if #motions == 0 then return end
    motion_index = motion_index % #motions + 1
    local motion_data = motions[motion_index]
    current_motion = motion_data.player
    current_motion:restart()
    print("Motion: " .. motion_data.name)
end

while running do
    local frame_start = sdl2.getTicks()
    local now = frame_start
    local delta = math.min((now - last_time) / 1000.0, 0.1)
    last_time = now

    local event = sdl2.pollEvent()
    while event ~= nil do
        local etype = tonumber(event.type) or 0
        if etype == sdl2.SDL_QUIT then
            running = false
        elseif etype == sdl2.SDL_KEYDOWN then
            local key = tonumber(event.key.keysym.sym) or 0
            if key == sdl2.SDLK_ESCAPE then running = false end
        elseif etype == sdl2.SDL_MOUSEBUTTONDOWN then
            local x = tonumber(event.button.x) or -1
            local y = tonumber(event.button.y) or -1
            if tonumber(event.button.button) == 1 and isInsideWindow(x, y) then
                playNextMotion()
            end
        elseif etype == sdl2.SDL_WINDOWEVENT then
            if tonumber(event.window.event) == sdl2.SDL_WINDOWEVENT_SIZE_CHANGED then
                W = tonumber(event.window.data1) or W
                H = tonumber(event.window.data2) or H
                local new_scale = math.min(W / model_width, H / model_height) * 0.8
                proj = ffi.new("float[16]", {
                    new_scale * 2.0 / W, 0, 0, 0,
                    0, new_scale * 2.0 / H, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1,
                })
                gl.glViewport(0, 0, W, H)
            end
        end
        event = sdl2.pollEvent()
    end

    -- Apply motion
    if current_motion then
        model:resetParameters()
        current_motion:tick(delta)
        current_motion:apply(model)
        if current_motion:is_finished() then
            playNextMotion()
        end
    end

    -- Update model (Core computes vertex deformation)
    model:update()

    -- Clear and draw
    gl.glClearColor(0.18, 0.20, 0.22, 1.0)
    gl.glClear(0x4000)
    gl.glViewport(0, 0, W, H)

    renderer:renderModel(model, textures, proj)

    sdl2.swapWindow(win)
    frame_count = frame_count + 1

    collectgarbage("step", 200)

    local elapsed = sdl2.getTicks() - frame_start
    if elapsed < target_frame_ms then
        sdl2.delay(math.floor(target_frame_ms - elapsed))
    end
end

print(string.format("Exited after %d frames.", frame_count))
renderer:destroy()
sdl2.deleteGLContext(ctx)
sdl2.destroyWindow(win)
sdl2.quit()
print("Done.")
