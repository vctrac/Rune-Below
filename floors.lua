local dungeon = require("dungeon")
local floors = {}

-- Add themes in ascending order of firstDepth. Each can supply its own generator.
local themes = {
    {
        firstDepth = 1,
        generate = dungeon.generate,
        stone = {0.017, 0.032, 0.027},
        ground = {0.025, 0.054, 0.041},
        pillar = {0.035, 0.08, 0.058},
        outline = {0.52, 0.96, 0.46},
    },
}

function floors.new(depth, random)
    local theme = themes[1]
    for i = #themes, 2, -1 do
        if depth >= themes[i].firstDepth then
            theme = themes[i]
            break
        end
    end
    local rooms = theme.generate(random)
    local runeRequired = 2
    for _, room in ipairs(rooms) do
        if room.kind == "boss" then runeRequired = room.runeRequired end
    end
    return {
        depth = depth, theme = theme, rooms = rooms,
        runeRequired = runeRequired,
        cleared = {[1] = true}, runes = {}, pickups = {},
    }
end

function floors.doorOpen(floor, index, side)
    local room = floor.rooms[index]
    local target = room.exits[side]
    if not target or (room.foes and not floor.cleared[index]) then return false end
    local required = floor.runeRequired
    local collected = 0
    for _ in pairs(floor.runes) do collected = collected + 1 end
    return floor.rooms[target].kind ~= "boss" or collected >= required
end

return floors
