local floors = require("floors")
local art = {}
local g = love.graphics
local colors = {
    cyan = {0.30, 0.96, 0.91}, lime = {0.52, 0.96, 0.46}, gold = {1, 0.76, 0.32},
    violet = {0.85, 0.44, 1}, red = {1, 0.35, 0.38}, muted = {0.47, 0.63, 0.58},
    white = {0.88, 0.97, 0.91}, orange = {1, 0.49, 0.19},
}
local fonts, sounds = {}, {}
local outgoingCanvas, incomingCanvas, capturedDescent
local W, H, GAP = 640, 396, 44

local function ink(name, alpha)
    local c = colors[name] or name
    g.setColor(c[1], c[2], c[3], alpha or 1)
end

local function text(value, font, color, x, y, width, align)
    g.setFont(fonts[font])
    ink(color)
    if width then g.printf(value, x, y, width, align or "center")
    else g.print(value, x, y) end
end

local function diamond(x, y, r)
    g.polygon("line", x, y-r, x+r, y, x, y+r, x-r, y)
end

local function etchedLine(x, y, xx, yy, color)
    ink(color, 0.12)
    g.setLineWidth(5)
    g.line(x, y, xx, yy)
    ink(color, 0.88)
    g.setLineWidth(1)
    g.line(x, y, xx, yy)
end

function art.load()
    for key, size in pairs({small = 12, body = 15, heading = 22, title = 49}) do
        fonts[key] = g.newFont(size)
    end
    local notes = {
        gun = {0.08, 195, -110, 0.13}, dash = {0.13, 220, 270, 0.10},
        magic = {0.26, 305, 440, 0.12}, hurt = {0.19, 145, -75, 0.18},
        clear = {0.31, 392, 275, 0.12}, descent = {0.38, 290, -185, 0.12},
        hit = {0.048, 330, -210, 0.065}, explode = {0.22, 184, -135, 0.17},
        strike = {0.17, 390, -245, 0.11}, teleport = {0.17, 450, 370, 0.09},
        rune = {0.41, 440, 490, 0.14},
    }
    if not love.audio then return end
    for name, note in pairs(notes) do
        local rate, phase = 22050, 0
        local count = math.floor(note[1] * rate)
        local samples = love.sound.newSoundData(count, rate, 16, 1)
        for i = 0, count - 1 do
            local fraction = i / count
            phase = phase + 2 * math.pi * (note[2] + fraction * note[3]) / rate
            local wave = math.sin(phase) + 0.24 * math.sin(phase * 3)
            samples:setSample(i, wave * note[4] * (1 - fraction)^2 * math.min(1, i / 60))
        end
        sounds[name] = love.audio.newSource(samples, "static")
    end
end

function art.play(name)
    if not sounds[name] then return end
    sounds[name]:stop()
    sounds[name]:play()
end

local function wall(time, floor, room, index, side)
    local outline = floor.theme.outline
    local horizontal = side == "up" or side == "down"
    local length = horizontal and W or H
    local fixed = (side == "up" or side == "left") and 24 or (horizontal and H - 24 or W - 24)
    local function line(a, b, color)
        if horizontal then etchedLine(a, fixed, b, fixed, color)
        else etchedLine(fixed, a, fixed, b, color) end
    end
    if not room.exits[side] then
        line(24, length - 24, outline)
        return
    end
    local a, b = length / 2 - GAP, length / 2 + GAP
    line(24, a, outline)
    line(b, length - 24, outline)
    local open = floors.doorOpen(floor, index, side)
    if not open then line(a, b, side == room.bossDoor and "violet" or "red") end
    for _, endpoint in ipairs({a, b}) do
        local x, y = fixed, endpoint
        if horizontal then x, y = endpoint, fixed end
        ink(open and "cyan" or "gold", 0.85)
        diamond(x, y, 4)
    end
    if open then
        local x, y = fixed, length / 2
        if horizontal then x, y = length / 2, fixed end
        g.push()
        g.translate(x, y)
        g.rotate(({left = math.pi, right = 0, up = -math.pi / 2, down = math.pi / 2})[side])
        ink("cyan", 0.44 + 0.2 * math.sin(time * 5))
        g.line(-5, -7, 3, 0, -5, 7)
        g.line(2, -7, 10, 0, 2, 7)
        g.pop()
    end
end

local function drawLadder(ladder, time)
    local age = time - ladder.opened
    g.push()
    g.translate(ladder.x, ladder.y)
    g.setLineWidth(1.5)
    g.setColor(0.01, 0.015, 0.013)
    g.rectangle("fill", -15, -17, 30, 34)
    ink("gold", 0.7 + 0.25 * math.sin(age * 6))
    g.rectangle("line", -15, -17, 30, 34)
    g.line(-7, -11, -7, 11)
    g.line(7, -11, 7, 11)
    for y = -9, 9, 6 do g.line(-7, y, 7, y) end
    if age < 0.8 then
        ink("gold", 0.7 * (1 - age / 0.8))
        g.circle("line", 0, 0, 19 + 63 * age, 20)
    end
    g.pop()
    text("DESCEND", "small", "gold", ladder.x - 56, ladder.y + 27, 112)
end

local function drawRune(pickup, time)
    local x, y = pickup.x, pickup.y
    local bob = math.sin(time * 4) * 3
    ink("violet", 0.25)
    g.ellipse("line", x, y + 11, 19, 6)
    ink("violet", 0.21)
    g.circle("fill", x, y + bob, 16)
    g.setLineWidth(1.8)
    ink("violet")
    diamond(x, y + bob, 11)
    ink("white")
    diamond(x, y + bob, 5)
    for i = 1, 3 do
        local angle = time * 1.4 + i * math.pi * 2 / 3
        g.points(x + math.cos(angle) * 22, y + math.sin(angle) * 15)
    end
    g.setLineWidth(1)
end

local function drawRoom(time, floor, index, sides, x, y)
    local room, theme = floor.rooms[index], floor.theme
    g.push()
    g.translate(x, y)
    ink(theme.stone)
    g.rectangle("fill", 0, 0, W, H)
    ink(theme.ground)
    g.rectangle("fill", 24, 24, W - 48, H - 48)
    ink(theme.outline, 0.09)
    g.setLineWidth(1)
    for gx = 48, W - 48, 32 do g.line(gx, 24, gx, H - 24) end
    for gy = 38, H - 24, 32 do g.line(24, gy, W - 24, gy) end
    for _, side in ipairs(sides) do wall(time, floor, room, index, side) end
    for _, pillar in ipairs(room.pillars) do
        local px, py = pillar[1], pillar[2]
        ink(theme.pillar)
        g.circle("fill", px, py, 15, 8)
        ink(theme.outline, 0.48)
        g.circle("line", px, py, 15, 8)
        diamond(px, py, 7)
    end
    if room.kind or room.rune then
        local active = room.kind or floor.runes[room.rune]
        ink(room.kind == "boss" and "red" or "violet", active and 0.33 or 0.16)
        g.circle("line", W / 2, H / 2, 42, 12)
        diamond(W / 2, H / 2, 32)
        g.line(304, 210, 320, 179, 336, 210, 304, 210)
    end
    if room.kind == "start" then
        text("RECOVER THE RUNES. DEFEAT THE HOLLOW KING.", "small", "muted", 0, 270, W)
        text("FOLLOW THE OPEN DOOR", "small", theme.outline, 0, 302, W)
    end
    local pickup = floor.pickups[index]
    if pickup then drawRune(pickup, time) end
    if floor.ladder and floor.ladder.room == index then drawLadder(floor.ladder, time) end
    g.pop()
end

local function actor(x, y, ax, ay, alpha)
    g.push()
    g.translate(x, y)
    ink("cyan", alpha)
    g.setLineWidth(1.6)
    g.polygon("line", -9, 9, -6, -1, 0, -10, 6, -1, 9, 9, 0, 6)
    g.line(-4, -2, 4, -2)
    g.line(ax * 7, ay * 7, ax * 18, ay * 18)
    ink("white", (alpha or 1) * 0.9)
    g.points(ax * 22, ay * 22)
    g.pop()
end

local function star(radius)
    local points = {}
    for i = 0, 9 do
        local angle = -math.pi / 2 + i * math.pi / 5
        local r = i % 2 == 0 and radius or radius * 0.45
        points[#points + 1] = math.cos(angle) * r
        points[#points + 1] = math.sin(angle) * r
    end
    g.polygon("line", points)
end

local function enemy(e, time)
    g.push()
    g.translate(e.x, e.y)
    g.setLineWidth(1.5)
    local hit = e.hit > 0
    if e.kind == "slime" then
        local phase = (time * 2 + e.pulse) % (3 * math.pi)
        local pulse = phase <= math.pi and phase or math.pi + (phase - math.pi) / 2
        local visibility = hit and 1 or (0.09 + 0.83 * (0.5 + 0.5 * math.sin(pulse))^2)
        ink(hit and "white" or "lime", visibility * 0.16)
        g.circle("fill", 0, 0, 16, 18)
        ink(hit and "white" or "lime", visibility)
        g.circle("line", 0, 0, 15 + math.sin(pulse) * 1.3, 18)
        g.circle("line", 4, -3, 3, 8)
    elseif e.kind == "spirit" then
        local warning = e.phase == "warning"
        local charge = warning and (1 - e.timer / 0.66) or 0
        local red = e.phase == "strike" or (warning and math.floor(time * (10 + 7 * charge)) % 2 == 0)
        local color = red and "red" or "white"
        if warning then
            ink("red", 0.09 + charge * 0.08)
            g.circle("fill", 0, 0, e.strikeRadius, 36)
            ink("red", 0.55 + charge * 0.4)
            g.circle("line", 0, 0, e.strikeRadius, 36)
            g.circle("line", 0, 0, 14 + (e.strikeRadius - 14) * charge, 28)
        end
        ink(color, 0.18)
        g.circle("fill", 0, 0, 18, 16)
        ink(hit and "white" or color)
        local bob = math.sin(time * 7 + e.pulse) * 2
        g.line(-10, bob + 9, -9, bob - 3, -5, bob - 9, 0, bob - 12, 5, bob - 9,
            9, bob - 3, 10, bob + 9, 4, bob + 5, 0, bob + 10, -4, bob + 5, -10, bob + 9)
        g.points(-3, bob - 3, 3, bob - 3)
    elseif e.kind == "spark" then
        local proximity = e.proximity or 0
        local blink = (0.5 + 0.5 * math.sin(time * 16 + proximity * 14))^2
        local bright = hit or (proximity > 0.55 and blink > 0.65)
        ink("orange", 0.12 + proximity * 0.38 * blink)
        g.circle("fill", 0, 0, 12 + proximity * 9 * blink, 14)
        ink(bright and "white" or "orange", 0.72 + 0.28 * blink)
        g.rotate(time * 2.8)
        star(11 + proximity * 3 * blink)
    elseif e.kind == "bone" then
        ink(hit and "white" or "gold")
        g.polygon("line", -11, -4, -6, -11, 6, -11, 11, -4, 8, 4, 5, 4, 5, 9, -5, 9, -5, 4, -8, 4)
        g.line(-6, -3, -3, -1)
        g.line(6, -3, 3, -1)
    elseif e.kind == "hex" then
        ink(hit and "white" or "violet")
        g.polygon("line", 0, -14, 12, 8, 6, 6, 0, 11, -6, 6, -12, 8)
        diamond(0, 0, 4)
    else
        ink("red", 0.55 + 0.35 * math.sin(time * 4)^2)
        g.circle("line", 0, 0, 25, 8)
        ink(hit and "white" or "red")
        g.polygon("line", -15, -11, -7, -4, 0, -14, 7, -4, 15, -11, 10, 8, -10, 8)
        diamond(0, 1, 4)
        g.line(-16, 33, -16 + 32 * e.hp / 36, 33)
    end
    g.pop()
end

local function meter(x, y, label, color, fraction)
    text(label, "small", color, x, y)
    ink(color, 0.18)
    g.rectangle("fill", x, y + 17, 80, 3)
    ink(color)
    g.rectangle("fill", x, y + 17, 80 * fraction, 3)
end

local function overlay(state)
    if state.mode == "play" then return end
    g.setColor(0.008, 0.018, 0.014, 0.95)
    g.rectangle("fill", 68, 111, 504, 254)
    g.setLineWidth(1)
    ink("lime", 0.7)
    g.rectangle("line", 68, 111, 504, 254)
    local titles = {title = "RUNE BELOW", pause = "PAUSED", dead = "THE CRYPT CLAIMS YOU"}
    local subtitles = {
        title = "Collect the runes to unlock the Crown Crypt.",
        pause = "START to resume  /  SELECT to quit",
        dead = state.kills .. " foes defeated",
    }
    ink("violet")
    diamond(320, 146, 11)
    text(titles[state.mode], state.mode == "title" and "title" or "heading", "cyan", 90, 163, 460)
    text(subtitles[state.mode], "body", "muted", 90, 225, 460)
    if state.mode == "title" then
        text("L STICK MOVE  /  R STICK AIM + FIRE  /  L1 DASH  /  R1 SPELL", "small", "white", 80, 262, 480)
    end
    local action = state.mode == "pause" and "ENTER OR P TO RESUME" or "PRESS START OR ENTER"
    text(action, "body", "lime", 90, 304, 460)
end

local function minimap(state, rooms)
    local floor = state.floor
    local function position(room)
        return 586 + (room.x - 3) * 9, 24 + (room.y - 3) * 9
    end

    ink("muted", 0.65)
    for _, room in ipairs(rooms) do
        local x, y = position(room)
        for _, side in ipairs({"right", "down"}) do
            local nextRoom = rooms[room.exits[side]]
            if nextRoom then
                local nx, ny = position(nextRoom)
                g.line(x, y, nx, ny)
            end
        end
    end
    for i, room in ipairs(rooms) do
        local x, y = position(room)
        g.setColor(0.01, 0.015, 0.013)
        g.rectangle("fill", x - 3, y - 3, 6, 6)
        if i == state.room then
            ink("cyan")
            g.rectangle("fill", x - 3, y - 3, 6, 6)
        elseif room.rune and not floor.runes[room.rune] then
            ink("violet")
            diamond(x, y, 3.5)
        else
            local color = floor.theme.outline
            if floor.ladder and floor.ladder.room == i then color = "gold"
            elseif room.kind == "boss" then color = "red" end
            ink(color, floor.cleared[i] and 1 or 0.65)
            g.rectangle(floor.cleared[i] and "fill" or "line", x - 2.5, y - 2.5, 5, 5)
        end
    end
end

local function drawActors(state)
    local p = state.player
    for _, ghost in ipairs(state.ghosts) do
        actor(ghost.x, ghost.y, ghost.ax, ghost.ay, ghost.life * 2)
    end
    for _, ring in ipairs(state.rings) do
        local t = ring.age / ring.duration
        ink(ring.color, (1 - t)^2 * 0.86)
        g.setLineWidth(1 + (1 - t) * 1.4)
        g.circle("line", ring.x, ring.y, ring.radius * (0.16 + 0.84 * (1 - (1 - t)^2)), 32)
    end
    for _, e in ipairs(state.enemies) do enemy(e, state.time) end
    for _, b in ipairs(state.bullets) do
        ink(b.kind == "gun" and "gold" or (b.kind == "hex" and "red" or "violet"))
        g.setLineWidth(2)
        if b.kind == "gun" then g.line(b.x, b.y, b.x - b.vx * 0.016, b.y - b.vy * 0.016)
        else diamond(b.x, b.y, b.kind == "hex" and 4 or 5) end
    end
    g.setLineWidth(1)
    for _, s in ipairs(state.sparks) do
        ink(s.color, math.min(1, s.life * 5))
        g.line(s.x, s.y, s.x - s.vx * 0.024, s.y - s.vy * 0.024)
    end
    if state.ward > 0 then
        ink("violet", state.ward * 2)
        g.circle("line", p.x, p.y, 18 + (0.38 - state.ward) * 200, 24)
    end
    local blink = state.invulnerable > 0 and math.floor(state.time * 24) % 2 == 0
    actor(p.x, p.y, p.ax, p.ay, blink and 0.45 or 1)
    if state.muzzle > 0 then
        local opacity = state.muzzle / 0.065
        g.push()
        g.translate(p.x + p.ax * 18, p.y + p.ay * 18)
        ink("gold", opacity * 0.20)
        g.circle("fill", 0, 0, 10, 10)
        ink("white", opacity)
        g.setLineWidth(1.4)
        g.line(-p.ax * 3, -p.ay * 3, p.ax * 10, p.ay * 10)
        g.line(-p.ay * 4, p.ax * 4, p.ay * 4, -p.ax * 4)
        g.pop()
    end
end

local function captureRoom(canvas, time, floor, index, sides, drawContents)
    local previous = g.getCanvas()
    g.push("all")
    g.setCanvas(canvas)
    g.origin()
    g.setScissor()
    g.clear(0, 0, 0, 1)
    drawRoom(time, floor, index, sides, 0, 0)
    drawContents()
    if previous then g.setCanvas(previous) else g.setCanvas() end
    g.pop()
end

local function drawDescent(state, sides)
    local descent = state.descent
    if capturedDescent ~= descent then
        outgoingCanvas = outgoingCanvas or g.newCanvas(W, H)
        incomingCanvas = incomingCanvas or g.newCanvas(W, H)
        captureRoom(outgoingCanvas, state.time, state.floor, state.room, sides, function()
            drawActors(state)
        end)
        captureRoom(incomingCanvas, state.time, descent.floor, 1, sides, function()
            local p = descent.player
            actor(p.x, p.y, p.ax, p.ay)
        end)
        capturedDescent = descent
    end

    local t = math.min(1, descent.time / descent.duration)
    t = t * t * (3 - 2 * t)
    local outgoingScale, incomingScale = 1 + 0.32 * t, 0.75 + 0.25 * t
    g.push("all")
    g.setColor(0, 0, 0, 1)
    g.rectangle("fill", 0, 0, W, H)
    -- Both room captures are opaque. Add their weighted colors for the crossfade.
    g.setBlendMode("add", "premultiplied")
    g.setColor(t, t, t, t)
    g.draw(incomingCanvas, W / 2, H / 2, 0, incomingScale, incomingScale, W / 2, H / 2)
    g.setColor(1 - t, 1 - t, 1 - t, 1 - t)
    local ladder = state.floor.ladder
    g.draw(outgoingCanvas, ladder.x, ladder.y, 0, outgoingScale, outgoingScale, ladder.x, ladder.y)
    g.pop()
end

function art.draw(state, sides, scale, ox, oy, hud)
    g.push("all")
    g.translate(ox, oy)
    g.scale(scale)
    g.setScissor(ox, oy + hud * scale, W * scale, H * scale)
    g.push()
    g.translate(0, hud)
    local floor, travel, p = state.floor, state.travel, state.player
    local rooms = floor.rooms
    if not state.descent then capturedDescent = nil end
    if state.descent then
        drawDescent(state, sides)
    elseif travel then
        local t = math.min(1, travel.time / 0.43)
        t = t * t * (3 - 2 * t)
        local x, y = travel.dx * W, travel.dy * H
        local oxRoom, oyRoom = -x * t, -y * t
        drawRoom(state.time, floor, travel.old, sides, oxRoom, oyRoom)
        drawRoom(state.time, floor, state.room, sides, oxRoom + x, oyRoom + y)
        for _, e in ipairs(state.enemies) do
            g.push()
            g.translate(oxRoom + x, oyRoom + y)
            enemy(e, state.time)
            g.pop()
        end
        actor(oxRoom + x + travel.x + (p.x - travel.x) * t,
            oyRoom + y + travel.y + (p.y - travel.y) * t, p.ax, p.ay)
    else
        g.push()
        g.translate(state.shakeX, state.shakeY)
        drawRoom(state.time, floor, state.room, sides, 0, 0)
        drawActors(state)
        g.pop()
        if state.flash > 0 then
            ink("red", state.flash * 0.9)
            g.setLineWidth(16)
            g.rectangle("line", 2, 2, W - 4, H - 4)
        end
    end
    g.pop()
    g.setScissor()
    g.setLineWidth(1)
    ink("lime", 0.25)
    g.line(0, hud, W, hud)
    g.line(0, hud + H, W, hud + H)
    text(rooms[state.room].name, "heading", "white", 18, 2)
    text("FLOOR " .. floor.depth, "small", floor.theme.outline, 19, 28)
    text("VITALITY", "small", "muted", 265, 7)
    for i = 1, 6 do
        ink("cyan", i <= p.hp and 1 or 0.2)
        diamond(270 + (i - 1) * 15, 32, 4.5)
    end
    local collected = 0
    for _ in pairs(floor.runes) do collected = collected + 1 end
    text("RUNES " .. collected .. "/" .. floor.runeRequired, "small", "muted", 404, 7)
    for i = 1, floor.runeRequired do
        ink("violet", floor.runes[i] and 1 or 0.24)
        diamond(411 + (i - 1) * 17, 32, 6)
    end
    minimap(state, rooms)
    meter(18, 452, "L1  DASH", "cyan", 1 - state.dashCooldown / 0.85)
    meter(542, 452, "R1  SPELL", "violet", 1 - state.magic / 3.4)
    if state.descent then
        text("DESCENDING TO FLOOR " .. state.descent.floor.depth, "small", "gold", 111, 455, 418)
    elseif state.messageTime > 0 then text(state.message, "small", "gold", 111, 455, 418)
    elseif rooms[state.room].foes and not floor.cleared[state.room] then
        text(#state.enemies .. " HOSTILES  /  DOORS SEALED", "small", "red", 111, 455, 418)
    end
    overlay(state)
    g.pop()
end

return art
