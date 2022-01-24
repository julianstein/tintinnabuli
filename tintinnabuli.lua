-------------- IMPORTS

include "lib/nest/core"
include "lib/nest/norns"
include "lib/nest/grid"

mu = require "musicutil"

engine.name = "PolyPerc"

local cs = require "controlspec"

-------------- VARIABLES

local scale = {0, 2, 4, 5, 7, 9, 11}
local root = 440 * 2 ^ (5 / 12) -- the d above middle a

local row_len = 16
local row_iv = 5

local triad = {scale[1], scale[3], scale[5]}
local direction = 1

-------------- FUNCTIONS

local get_deg = function(x, y, iv)
    local height = (y - 1) * iv
    return x + height
end

local get_register = function(deg, scale)
    return math.floor((deg - 1) / #scale)
end

local remove_duplicates = function(list1, list2)
    table.insert(list1, list2)
    local x = {}
    local y = {}
    for _, v in ipairs(list1) do
        if (not x[v]) then
            y[#y + 1] = v
            x[v] = true
        end
    end
    return y
end

local harm_deg = function(note)
    local sorted_above = function(note, triad)
        if (note <= triad[1] or note > triad[3]) then
            return {3, 2, 1}
        elseif (note <= triad[2] and note > triad[1]) then
            return {1, 3, 2}
        else
            return {2, 1, 3}
        end
    end

    local sorted_below = function(note, triad)
        if (note >= triad[1] and note < triad[2]) then
            return {2, 3, 1}
        elseif (note >= triad[2] and note < triad[3]) then
            return {3, 1, 2}
        else
            return {1, 2, 3}
        end
    end

    return direction == 1 and sorted_above(note, triad) or sorted_below(note, triad)
end

local harm_pitch = function(note)
    local harm = {
        init = {},
        above = {},
        below = {}
    }

    local pitch_below = function(tbl, note)
        local result = {}
        for _, v in pairs(tbl) do
            if v > note then
                table.insert(result, v - 12)
            else
                table.insert(result, v)
            end
        end
        return result
    end

    local pitch_above = function(tbl, note)
        local result = {}
        for _, v in pairs(tbl) do
            if v >= note then
                table.insert(result, v)
            else
                table.insert(result, v + 12)
            end
        end
        return result
    end

    harm.init = {triad[harm_deg(note)[1]], triad[harm_deg(note)[2]], triad[harm_deg(note)[3]]}
    harm.above = pitch_above(harm.init, note)
    harm.below = pitch_below(harm.init, note)

    return remove_duplicates(harm.below, note)
end

local get_freq = function(x, y)
    local z = {}
    for _, v in pairs(x) do
        table.insert(z, root * 2 ^ y * 2 ^ (v / 12))
    end
    return z
end

local is_int = function(n)
    return (type(n) == "number") and (math.floor(n) == n)
end

synth =
    nest_ {
    keyboard = _grid.momentary {
        x = {1, row_len}, -- notes on the x axis
        y = {5, 8},
        -- octaves on the y axis

        action = function(self, value, t, d, added, removed)
            local key = added or removed
            -- print(triad[2])
            local deg = get_deg(key.x, key.y, row_iv)
            local register = get_register(deg, scale)
            local scale_height = register - 2

            local note = scale[((deg - 1) % #scale + 1)]

            local freq = get_freq(harm_pitch(note), scale_height)

            if added then
                for k, v in pairs(freq) do
                    local amp = 1
                    engine.hz(v)
                    amp = k == #freq - 1 and 1 or 0.2
                    engine.amp(amp)
                end
            end
            -- print(mu.freq_to_note_num (hz))
        end
    },
    nodes = _grid.fill {
        x = {1, row_len}, -- notes on the x axis
        y = {5, 8},
        z = -1,
        -- octaves on the y axis
        level = function(s, x, y)
            local deg = get_deg(x, y, row_iv)
            local nodes = (deg - 1) / #scale
            return (is_int(nodes)) and 7 or 2
        end
    }
}

synth:connect {g = grid.connect()}

function init()
    synth:init()
end
