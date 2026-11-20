local dungeon = require("dungeon")
local floors = {}
local unpack = table.unpack or unpack

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

local BREAKABLE_DOOR_HP = 3

local function placeBreakableDoors(rooms, random)
    local doors, candidates = {}, {}
    for index in ipairs(rooms) do doors[index] = {} end
    for index, room in ipairs(rooms) do
        if room.kind ~= "start" and room.kind ~= "boss" then
            for _, side in ipairs({"right", "down"}) do
                local target = room.exits[side]
                local neighbor = rooms[target]
                if neighbor and neighbor.kind ~= "start" and neighbor.kind ~= "boss" then
                    candidates[#candidates + 1] = {index, side, target}
                end
            end
        end
    end
    for _ = 1, math.min(#candidates, random(1, 2)) do
        local index, side, target = unpack(table.remove(candidates, random(#candidates)))
        local door = {hp = BREAKABLE_DOOR_HP}
        doors[index][side] = door
        doors[target][side == "right" and "left" or "up"] = door
    end
    return doors
end

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
        enemies = {}, breakableDoors = placeBreakableDoors(rooms, random),
    }
end

function floors.runeCount(floor)
    local collected = 0
    for _ in pairs(floor.runes) do collected = collected + 1 end
    return collected
end

function floors.bossUnlocked(floor)
    return floors.runeCount(floor) >= floor.runeRequired
end

function floors.doorState(floor, index, side)
    local target = floor.rooms[index].exits[side]
    if not target then return "wall" end
    if floor.rooms[target].kind == "boss" and not floors.bossUnlocked(floor) then return "locked" end
    local door = floor.breakableDoors[index][side]
    if door and door.hp > 0 then return "breakable", BREAKABLE_DOOR_HP - door.hp end
    return "open"
end

function floors.doorOpen(floor, index, side)
    return floors.doorState(floor, index, side) == "open"
end

function floors.damageDoor(floor, index, side, damage)
    local door = floor.breakableDoors[index][side]
    if not door or door.hp == 0 then return end
    door.hp = math.max(0, door.hp - damage)
    return door.hp
end

return floors
