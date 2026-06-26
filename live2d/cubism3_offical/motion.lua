-- motion.lua - Motion3 player for Cubism3/4/5 models (FFI Core path)
-- Parses motion3.json and applies curves to model parameters/parts.
-- Independent of existing cubism3/ motion player.

local motion3 = require("live2d.cubism3_offical.json.motion3")

local MotionPlayer = {}
MotionPlayer.__index = MotionPlayer

function MotionPlayer.new(motion_data)
    local self = setmetatable({}, MotionPlayer)
    self.time = 0
    self.duration = motion_data.meta.duration or 3.0
    self.fade_in_time = motion_data.meta.fade_in_time or 0
    self.fade_out_time = motion_data.meta.fade_out_time or 0
    self.loop = motion_data.meta.loop or false
    self.curves = motion_data.curves
    self.curve_count = #self.curves
    self.finished = false
    return self
end

function MotionPlayer:restart()
    self.time = 0
    self.finished = false
end

function MotionPlayer:tick(delta)
    if self.finished then
        return
    end
    self.time = self.time + delta
    if self.time >= self.duration then
        if self.loop then
            self.time = self.time - self.duration
        else
            self.time = self.duration
            self.finished = true
        end
    end
end

function MotionPlayer:is_finished()
    return self.finished
end

function MotionPlayer:apply(model)
    local time = self.time

    for _, curve in ipairs(self.curves) do
        local value = curve:sample(time)

        -- Apply fade
        local fade = 1.0
        if self.fade_in_time >= 0 then
            -- Use per-curve fade or motion fade
            local curve_fade_in = curve.fade_in_time or self.fade_in_time
            if curve_fade_in < 0 then
                curve_fade_in = self.fade_in_time
            end
            if curve_fade_in > 0 then
                local curve_fade_out = curve.fade_out_time or self.fade_out_time
                if curve_fade_out < 0 then
                    curve_fade_out = self.fade_out_time
                end
                if curve_fade_out > 0 then
                    -- Both fade in and out
                    local fade_in_end = curve_fade_in
                    local fade_out_start = self.duration - curve_fade_out
                    if time < fade_in_end then
                        fade = time / fade_in_end
                    elseif time > fade_out_start then
                        fade = math.max(0, (self.duration - time) / curve_fade_out)
                    end
                else
                    -- Only fade in
                    if time < curve_fade_in then
                        fade = time / curve_fade_in
                    end
                end
            end
        end

        -- Apply based on target type
        if curve.target == "Parameter" then
            local current = model:getParameterValueById(curve.id)
            model:setParameterValueById(curve.id, current + (value - current) * fade)
        elseif curve.target == "PartOpacity" then
            model:setPartOpacityById(curve.id, 1.0 + (value - 1.0) * fade)
        end
    end
end

return MotionPlayer
