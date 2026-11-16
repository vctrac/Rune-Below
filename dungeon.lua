local dungeon = {}
local SIZE = 5
local unpack = table.unpack or unpack

local directions = {
    {side = "left", opposite = "right", dx = -1, dy = 0},
    {side = "right", opposite = "left", dx = 1, dy = 0},
    {side = "up", opposite = "down", dx = 0, dy = -1},
    {side = "down", opposite = "up", dx = 0, dy = 1},
}
local names = {
    "OSSUARY", "ASH VAULT", "THE UNDERTOMB", "BONE COURT", "CINDER HALL",
    "WEEPING HALL", "THE CATACOMBS", "DUST GALLERY", "GRAVE WATCH",
}
local pillarPlans = {
    {{140, 107}, {140, 289}, {500, 107}, {500, 289}},
    {{204, 111}, {436, 285}},
    {{170, 198}, {470, 198}},
    {{240, 97}, {400, 97}, {240, 299}, {400, 299}},
    {{242, 104}, {242, 292}, {472, 104}, {472, 292}},
    {{245, 155}, {395, 241}, {456, 128}},
    {},
}
local specials = {"slime", "spirit", "spark"}
local spawnPoints = {
    {127, 101}, {127, 295}, {207, 213}, {280, 132}, {280, 264},
    {360, 132}, {360, 264}, {433, 183}, {513, 101}, {513, 295},
    {213, 272}, {427, 124},
}

local function shuffled(values, random)
    local copy = {unpack(values)}
    for i = #copy, 2, -1 do
        local j = random(i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    return copy
end

local function validSpawn(point, pillars)
    for _, pillar in ipairs(pillars) do
        if (point[1] - pillar[1])^2 + (point[2] - pillar[2])^2 < 48^2 then return false end
    end
    return true
end

local function furnish(rooms, random)
    local shuffledNames = shuffled(names, random)
    local nameIndex = 1
    for _, room in ipairs(rooms) do
        room.pillars = pillarPlans[random(#pillarPlans)]
        if room.kind == "start" then
            room.name, room.pillars = "THE THRESHOLD", pillarPlans[1]
        else
            local count = random(2, 3)
            if room.kind == "boss" then
                room.name = "CROWN CRYPT"
                room.foes = {{"king", 320, 198}}
                count = 3
            elseif room.rune then
                room.name = room.rune == 1 and "HEX CHAPEL" or "THE RELIQUARY"
                room.foes, count = {}, random(3, 4)
            else
                room.name, room.foes = shuffledNames[nameIndex], {}
                nameIndex = nameIndex + 1
            end
            local used = {}
            for _, point in ipairs(shuffled(spawnPoints, random)) do
                if #room.foes == count then break end
                if validSpawn(point, room.pillars) then
                    local kind = "bone"
                    local slot = #room.foes + 1
                    if room.rune and slot == 1 then
                        kind = "hex"
                    elseif room.rune == 1 and slot == 2 then
                        kind = "spirit"
                    elseif room.index == 2 and slot == 1 then
                        kind = "slime"
                    elseif room.index == 3 and slot == 1 then
                        kind = "spark"
                    elseif room.depth >= 2 and room.kind ~= "boss" and random(3) == 1 then
                        local special = specials[random(#specials)]
                        if not used[special] and not (room.rune == 1 and special == "spirit") then kind = special end
                    elseif room.depth >= 3 and random(3) == 1 then
                        kind = "hex"
                    end
                    used[kind] = true
                    room.foes[#room.foes + 1] = {kind, point[1], point[2]}
                end
            end
        end
    end
end

function dungeon.generate(random)
    local rooms, occupied = {}, {}
    local function add(x, y, parent, direction)
        local index = #rooms + 1
        local room = {x = x, y = y, depth = parent and parent.depth + 1 or 0, exits = {}}
        rooms[index], occupied[(y - 1) * SIZE + x] = room, true
        if parent then
            parent.exits[direction.side] = index
            room.exits[direction.opposite] = parent.index
        end
        room.index = index
        return room
    end

    local function remove(room, parent, direction)
        parent.exits[direction.side] = nil
        occupied[(room.y - 1) * SIZE + room.x], rooms[room.index] = nil, nil
    end

    local function extend(parent, attempt)
        for _, direction in ipairs(shuffled(directions, random)) do
            local x, y = parent.x + direction.dx, parent.y + direction.dy
            if x >= 1 and x <= SIZE and y >= 1 and y <= SIZE and not occupied[(y - 1) * SIZE + x] then
                local room = add(x, y, parent, direction)
                if attempt(room) then return true end
                remove(room, parent, direction)
            end
        end
        return false
    end

    local start = add(3, 3)
    start.kind = "start"
    local spineLength = random(5, 7)
    local branchParents = {}
    for i = 2, spineLength - 1 do branchParents[#branchParents + 1] = i end
    branchParents = shuffled(branchParents, random)
    local runeCount = random(1, 3)
    local branchLength = {}
    for i = 1, runeCount do branchLength[i] = random(1, 2) end

    local function growBranch(parent, length, finish)
        if length == 0 then return finish(parent) end
        return extend(parent, function(room) return growBranch(room, length - 1, finish) end)
    end

    local function attachRunes()
        local chosenParents, runeRooms = {}, {}
        local function attachNext(runeIndex, parentIndex)
            if runeIndex > runeCount then
                for i, room in ipairs(runeRooms) do room.rune = i end
                return true
            end
            for i = parentIndex, #branchParents do
                local spineIndex = branchParents[i]
                if not chosenParents[spineIndex] then
                    local attached = growBranch(rooms[spineIndex], branchLength[runeIndex], function(runeRoom)
                        chosenParents[spineIndex] = true
                        runeRooms[runeIndex] = runeRoom
                        if attachNext(runeIndex + 1, i + 1) then return true end
                        chosenParents[spineIndex], runeRooms[runeIndex] = nil, nil
                        return false
                    end)
                    if attached then return true end
                end
            end
            return false
        end
        return attachNext(1, 1)
    end

    local function growSpine(room)
        if #rooms == spineLength then
            if not attachRunes() then return false end
            room.kind = "boss"
            local gate = rooms[room.index - 1]
            for side, target in pairs(gate.exits) do
                if target == room.index then gate.bossDoor = side end
            end
            room.runeRequired = runeCount
            return true
        end
        return extend(room, growSpine)
    end

    assert(growSpine(start), "Could not lay out the dungeon")
    furnish(rooms, random)
    return rooms
end

return dungeon

