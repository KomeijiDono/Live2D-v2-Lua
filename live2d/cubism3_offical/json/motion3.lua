-- json/motion3.lua - motion3.json parser (FFI Core path)
-- Minimal self-contained JSON parser for motion3.json curves.
-- Independent of existing cubism3/ JSON parsers.

local dkjson = require("live2d.dkjson")

local motion3 = {}

local MotionPoint = {}
MotionPoint.__index = MotionPoint

function MotionPoint.new(time, value)
    return setmetatable({ time = time, value = value }, MotionPoint)
end

local function lerp_point(a, b, t)
    return MotionPoint.new(
        a.time + (b.time - a.time) * t,
        a.value + (b.value - a.value) * t
    )
end

local function cubic_bezier_point(start, control1, control2, end_p, t)
    local p01 = lerp_point(start, control1, t)
    local p12 = lerp_point(control1, control2, t)
    local p23 = lerp_point(control2, end_p, t)
    local p012 = lerp_point(p01, p12, t)
    local p123 = lerp_point(p12, p23, t)
    return lerp_point(p012, p123, t)
end

local function sample_linear(start, end_p, time)
    if start.time == end_p.time then
        return end_p.value
    end
    local amount = math.max(0, math.min(1, (time - start.time) / (end_p.time - start.time)))
    return start.value + (end_p.value - start.value) * amount
end

local function sample_bezier(start, control1, control2, end_p, time)
    local t
    if start.time == end_p.time then
        t = 1
    else
        t = math.max(0, math.min(1, (time - start.time) / (end_p.time - start.time)))
    end
    return cubic_bezier_point(start, control1, control2, end_p, t).value
end

local function parse_segments(values)
    if #values < 2 then
        return nil, nil
    end

    local first_point = MotionPoint.new(tonumber(values[1]) or 0, tonumber(values[2]) or 0)
    local cursor = 3
    local start = first_point
    local segments = {}

    local function read_point()
        if cursor + 1 > #values then
            return nil
        end
        local point = MotionPoint.new(tonumber(values[cursor]) or 0, tonumber(values[cursor + 1]) or 0)
        cursor = cursor + 2
        return point
    end

    while cursor <= #values do
        local segment_type = tonumber(values[cursor]) or 0
        cursor = cursor + 1

        if segment_type == 0 then
            local end_p = read_point()
            if not end_p then break end
            segments[#segments + 1] = { kind = "linear", start = start, ["end"] = end_p }
            start = end_p
        elseif segment_type == 1 then
            local control1 = read_point()
            local control2 = read_point()
            local end_p = read_point()
            if not control1 or not control2 or not end_p then break end
            segments[#segments + 1] = {
                kind = "bezier",
                start = start,
                control1 = control1,
                control2 = control2,
                ["end"] = end_p,
            }
            start = end_p
        elseif segment_type == 2 then
            local end_p = read_point()
            if not end_p then break end
            segments[#segments + 1] = { kind = "stepped", start = start, ["end"] = end_p }
            start = end_p
        elseif segment_type == 3 then
            local end_p = read_point()
            if not end_p then break end
            segments[#segments + 1] = { kind = "inverse_stepped", start = start, ["end"] = end_p }
            start = end_p
        else
            break
        end
    end

    return first_point, segments
end

local MotionCurve = {}
MotionCurve.__index = MotionCurve

function MotionCurve:sample(time)
    if time <= self.first_point.time then
        return self.first_point.value
    end

    for _, segment in ipairs(self.segments) do
        if time < segment["end"].time then
            if segment.kind == "linear" then
                return sample_linear(segment.start, segment["end"], time)
            elseif segment.kind == "bezier" then
                return sample_bezier(segment.start, segment.control1, segment.control2, segment["end"], time)
            elseif segment.kind == "stepped" then
                return segment.start.value
            elseif segment.kind == "inverse_stepped" then
                return segment["end"].value
            end
        end
    end

    local last_segment = self.segments[#self.segments]
    if last_segment then
        return last_segment["end"].value
    end
    return self.first_point.value
end

local function parse_curve_entry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local id = entry.Id or ""
    local target = entry.Target or ""

    local first_point, segments = parse_segments(entry.Segments or {})
    local fade_in_time = nil
    local fade_out_time = nil
    if not first_point then
        return nil
    end

    if type(entry.FadeInTime) == "number" then
        fade_in_time = entry.FadeInTime
    end
    if type(entry.FadeOutTime) == "number" then
        fade_out_time = entry.FadeOutTime
    end

    return setmetatable({
        id = id,
        target = target,
        first_point = first_point,
        segments = segments,
        fade_in_time = fade_in_time,
        fade_out_time = fade_out_time,
    }, MotionCurve)
end

function motion3.parse(json_str, max_duration)
    local ok, data = pcall(dkjson.decode, json_str)
    if not ok or type(data) ~= "table" then
        return nil, "Failed to parse motion3.json: " .. tostring(data)
    end

    local meta_table = data.Meta or {}
    local meta = {
        duration = tonumber(meta_table.Duration) or 0,
        fade_in_time = tonumber(meta_table.FadeInTime) or 0,
        fade_out_time = tonumber(meta_table.FadeOutTime) or 0,
        loop = meta_table.Loop or false,
        fps = tonumber(meta_table.Fps) or 30,
        curve_count = tonumber(meta_table.CurveCount) or 0,
        total_segment_count = tonumber(meta_table.TotalSegmentCount) or 0,
        total_point_count = tonumber(meta_table.TotalPointCount) or 0,
    }

    -- Handle "Duration" as fallback
    if meta.duration <= 0 then
        meta.duration = tonumber(data.MetaDurationCount) or 0
    end

    -- Calculate duration from curve segments if not specified
    if meta.duration <= 0 or max_duration then
        local max_time = max_duration or 0
        if max_time <= 0 then
            if type(data.Curves) == "table" then
                for _, entry in ipairs(data.Curves) do
                    if type(entry.Curve) == "table" then
                        for _, seg in ipairs(entry.Curve) do
                            local t = tonumber(seg[1]) or 0
                            if t > max_time then
                                max_time = t
                            end
                        end
                    end
                end
            end
        end
        if max_time > 0 and meta.duration <= 0 then
            meta.duration = max_time
        end
    end

    local curves = {}
    if type(data.Curves) == "table" then
        for _, entry in ipairs(data.Curves) do
            local curve = parse_curve_entry(entry)
            if curve then
                curves[#curves + 1] = curve
            end
        end
    end

    return { meta = meta, curves = curves }
end

return motion3
