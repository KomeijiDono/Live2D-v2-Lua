-- live2d/cubism3_offical/init.lua - Module entry point (FFI Core path)
-- Exports Core, Model, MotionPlayer, Renderer, and JSON parsers.
-- Independent of existing cubism3/ implementation.

local M = {
    core = require("live2d.cubism3_offical.core_ffi"),
    Model = require("live2d.cubism3_offical.model"),
    MotionPlayer = require("live2d.cubism3_offical.motion"),
    Renderer = require("live2d.cubism3_offical.renderer"),
    json = require("live2d.cubism3_offical.json"),
    model3 = require("live2d.cubism3_offical.json.model3"),
    motion3 = require("live2d.cubism3_offical.json.motion3"),
}

return M
