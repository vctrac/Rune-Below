local floors = require("floors")
local controls = require("controls")
local art = require("art")

local W, H, HUD = 640, 396, 48
local WALL, GAP = 24, 44
local RADIUS = 9
local DESCENT_TIME = 1.15
local TAU = 2 * math.pi
local state, scale, offsetX, offsetY = nil, 1, 0, 0
local sides = {"left", "right", "up", "down"}
local enemyTypes = {
    slime = {hp = 4, speed = 20, radius = 16, color = "lime"},
    spirit = {hp = 5, radius = 13, color = "white"},
    spark = {hp = 2, speed = 186, radius = 9, color = "orange"},
    bone = {hp = 3, speed = 74, radius = 12, color = "gold"},
    hex = {hp = 5, speed = 56, radius = 14, color = "violet"},
    king = {hp = 36, speed = 42, radius = 25, color = "violet"},
}

local function unit(x, y)
    local length = math.sqrt(x * x + y * y)
    if length == 0 then return 0, 0, 0 end
    return x / length, y / length, length
end

local function near(x, y, tx, ty, r)
    return (x - tx)^2 + (y - ty)^2 < r^2
end

local function spawnPlayer(player)
    player.x, player.y = 267, 198
    return player
end

local function reset()
    state = {
        mode = "title", floor = floors.new(1, love.math.random), room = 1,
        player = spawnPlayer({ax = 1, ay = 0, hp = 6}),
        bullets = {}, sparks = {}, enemies = {}, rings = {}, ghosts = {},
        shake = 0, shakeX = 0, shakeY = 0, flash = 0, muzzle = 0, trail = 0,
        time = 0, shot = 0, dash = 0, dashCooldown = 0, ward = 0, magic = 0, invulnerable = 0,
        message = "", messageTime = 0, kills = 0, dashHeld = true, magicHeld = true,
    }
end

local function announce(message)
    state.message, state.messageTime = message, 2.8
end

local function doorOpen(index, side)
    return floors.doorOpen(state.floor, index, side)
end

local function solid(x, y, r, useDoors)
    local room = state.floor.rooms[state.room]
    for _, pillar in ipairs(room.pillars) do
        if near(x, y, pillar[1], pillar[2], r + 15) then return true end
    end
    if x < WALL + r and not (useDoors and math.abs(y - H / 2) <= GAP - r and doorOpen(state.room, "left")) then return true end
    if x > W - WALL - r and not (useDoors and math.abs(y - H / 2) <= GAP - r and doorOpen(state.room, "right")) then return true end
    if y < WALL + r and not (useDoors and math.abs(x - W / 2) <= GAP - r and doorOpen(state.room, "up")) then return true end
    if y > H - WALL - r and not (useDoors and math.abs(x - W / 2) <= GAP - r and doorOpen(state.room, "down")) then return true end
    return false
end

local function move(actor, dx, dy, radius, useDoors)
    if not solid(actor.x + dx, actor.y, radius, useDoors) then actor.x = actor.x + dx end
    if not solid(actor.x, actor.y + dy, radius, useDoors) then actor.y = actor.y + dy end
end

local function burst(x, y, color, count)
    for i = 1, count do
        local angle, speed = love.math.random() * TAU, love.math.random(32, 155)
        state.sparks[#state.sparks + 1] = {
            x = x, y = y, vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
            life = love.math.random(12, 38) / 100, color = color,
        }
    end
end

local function impact(x, y, color, radius, duration, shake)
    state.rings[#state.rings + 1] = {x = x, y = y, color = color, radius = radius, age = 0, duration = duration}
    state.shake = math.min(9, state.shake + shake)
end

local function clearEffects()
    state.bullets, state.sparks, state.enemies, state.rings, state.ghosts = {}, {}, {}, {}, {}
    state.shake, state.shakeX, state.shakeY, state.muzzle, state.flash = 0, 0, 0, 0, 0
end

local function enter(side, dx, dy)
    local old = state.room
    local nextRoom = state.floor.rooms[old].exits[side]
    if not doorOpen(old, side) then return end
    local p = state.player
    state.room = nextRoom
    state.travel = {old = old, time = 0, dx = dx, dy = dy, x = p.x - dx * W, y = p.y - dy * H}
    if dx ~= 0 then p.x = dx > 0 and WALL + 25 or W - WALL - 25 end
    if dy ~= 0 then p.y = dy > 0 and WALL + 25 or H - WALL - 25 end
    clearEffects()
    state.dash, state.ward = 0, 0
    if not state.floor.cleared[nextRoom] then
        for index, spawn in ipairs(state.floor.rooms[nextRoom].foes or {}) do
            local kind = spawn[1]
            state.enemies[index] = {
                kind = kind, x = spawn[2], y = spawn[3], hp = enemyTypes[kind].hp,
                fire = 0.8 + index * 0.24, turn = index % 2 == 0 and 1 or -1, avoid = 0,
                timer = 1 + index * 0.3, phase = "cooldown", hit = 0, pulse = index * 1.7,
            }
        end
    end
end

local function projectile(x, y, ax, ay, kind)
    local speed = kind == "gun" and 530 or (kind == "spell" and 290 or 175)
    state.bullets[#state.bullets + 1] = {
        x = x, y = y, vx = ax * speed, vy = ay * speed, kind = kind, life = 1.8,
    }
end

local function hurt()
    if state.invulnerable > 0 or state.dash > 0 then return end
    local p = state.player
    state.invulnerable = 0.85
    p.hp = p.hp - 1
    art.play("hurt")
    burst(p.x, p.y, "red", 24)
    state.flash = 0.24
    impact(p.x, p.y, "red", 56, 0.3, 7)
    if p.hp == 0 then state.mode = "dead" end
end

local function teleport(e, x, y)
    burst(e.x, e.y, "white", 8)
    impact(e.x, e.y, "white", 25, 0.24, 0)
    e.x, e.y = x, y
    burst(x, y, "white", 12)
end

local function updateSpirit(e, dt)
    local p = state.player
    e.timer = e.timer - dt
    if e.timer > 0 then return end
    if e.phase == "cooldown" then
        local angle = love.math.random() * TAU
        for i = 0, 11 do
            local x, y = p.x + math.cos(angle) * 37, p.y + math.sin(angle) * 37
            if not solid(x, y, enemyTypes.spirit.radius, false) then
                teleport(e, x, y)
                e.phase, e.timer, e.strikeRadius = "warning", 0.66, 47
                art.play("teleport")
                return
            end
            angle = angle + TAU / 12
        end
        e.timer = 0.3
    elseif e.phase == "warning" then
        burst(e.x, e.y, "red", 25)
        impact(e.x, e.y, "red", e.strikeRadius, 0.3, 2)
        art.play("strike")
        if near(p.x, p.y, e.x, e.y, e.strikeRadius + RADIUS) then hurt() end
        e.phase, e.timer = "strike", 0.18
    else
        local bestX, bestY, distance = e.x, e.y, -1
        for x = 94, W - 80, 113 do
            for y = 74, H - 70, 82 do
                local candidate = (p.x - x)^2 + (p.y - y)^2
                if candidate > distance and not solid(x, y, enemyTypes.spirit.radius, false) then
                    bestX, bestY, distance = x, y, candidate
                end
            end
        end
        teleport(e, bestX, bestY)
        e.phase, e.timer = "cooldown", 2.1
    end
end

local function explode(e)
    burst(e.x, e.y, "orange", 30)
    burst(e.x, e.y, "white", 10)
    impact(e.x, e.y, "orange", 53, 0.32, 5)
    art.play("explode")
end

local function defeatEnemy(index)
    local e = state.enemies[index]
    if e.kind == "spark" then
        explode(e)
    else
        burst(e.x, e.y, enemyTypes[e.kind].color, 19)
        impact(e.x, e.y, enemyTypes[e.kind].color, 33, 0.23, 2)
    end
    table.remove(state.enemies, index)
    state.kills = state.kills + 1
    if e.kind == "king" then
        impact(e.x, e.y, "gold", 148, 0.62, 9)
        burst(e.x, e.y, "gold", 32)
        burst(e.x, e.y, "violet", 24)
        for _, escort in ipairs(state.enemies) do
            burst(escort.x, escort.y, "violet", 9)
        end
        state.enemies = {}
    end
end

local function damageEnemy(index, damage)
    local enemy = state.enemies[index]
    enemy.hp = enemy.hp - damage
    enemy.hit = 0.09
    if enemy.hp <= 0 then defeatEnemy(index) end
end

local function updateEnemies(dt)
    local p = state.player
    for i = #state.enemies, 1, -1 do
        local e = state.enemies[i]
        local spec = enemyTypes[e.kind]
        e.hit = math.max(0, e.hit - dt)
        if e.kind == "spirit" then
            updateSpirit(e, dt)
        else
            local ax, ay, distance = unit(p.x - e.x, p.y - e.y)
            e.proximity = math.max(0, 1 - distance / 180)
            if distance > (e.kind == "hex" and 158 or 0) then
                local x, y = e.x, e.y
                e.avoid = math.max(0, e.avoid - dt)
                if e.avoid > 0 then ax, ay = -ay * e.turn, ax * e.turn end
                local stride = spec.speed * dt
                if e.kind == "spark" then stride = stride * (0.66 + e.proximity * 0.34) end
                move(e, ax * stride, ay * stride, spec.radius, false)
                if near(e.x, e.y, x, y, stride * 0.35) and e.avoid == 0 then e.avoid = 0.55 end
            end
            if e.kind == "hex" or e.kind == "king" then
                e.fire = e.fire - dt
                if e.fire <= 0 then
                    local aimX, aimY = unit(p.x - e.x, p.y - e.y)
                    local spread = e.kind == "king" and 2 or 0
                    for i = -spread, spread do
                        local c, s = math.cos(i * 0.22), math.sin(i * 0.22)
                        projectile(e.x, e.y, aimX * c - aimY * s, aimX * s + aimY * c, "hex")
                    end
                    e.fire = e.kind == "king" and 0.95 or 1.7
                end
            end
            if near(p.x, p.y, e.x, e.y, spec.radius + RADIUS) then
                if e.kind == "spark" then
                    explode(e)
                    table.remove(state.enemies, i)
                end
                hurt()
            end
        end
        if state.mode ~= "play" then return end
    end
end

local function updateBullets(dt)
    local p = state.player
    for i = #state.bullets, 1, -1 do
        local b = state.bullets[i]
        b.x, b.y, b.life = b.x + b.vx * dt, b.y + b.vy * dt, b.life - dt
        local blocked = solid(b.x, b.y, 2, false)
        local expired = b.life <= 0 or blocked
        if blocked and b.kind ~= "hex" then
            burst(b.x, b.y, b.kind == "spell" and "violet" or "gold", 3)
        end
        if not expired and b.kind == "hex" then
            if near(b.x, b.y, p.x, p.y, RADIUS + 4) then
                hurt()
                expired = true
            end
        elseif not expired then
            for j = #state.enemies, 1, -1 do
                local e = state.enemies[j]
                if near(b.x, b.y, e.x, e.y, enemyTypes[e.kind].radius + 3) then
                    burst(b.x, b.y, b.kind == "spell" and "violet" or "gold", 7)
                    state.shake = math.min(9, state.shake + 0.6)
                    art.play("hit")
                    damageEnemy(j, b.kind == "spell" and 3 or 1)
                    expired = true
                    break
                end
            end
        end
        if expired then table.remove(state.bullets, i) end
    end
end

local function updateRoom()
    local index = state.room
    if #state.enemies > 0 or state.floor.cleared[index] or not state.floor.rooms[index].foes then return end
    state.floor.cleared[index] = true
    state.bullets = {}
    art.play("clear")
    local room = state.floor.rooms[index]
    if room.kind == "boss" then
        state.floor.ladder = {room = index, x = W / 2, y = H / 2, opened = state.time}
        burst(W / 2, H / 2, "gold", 22)
        announce("LADDER OPEN  /  WALK OVER TO DESCEND")
    elseif room.rune then
        state.floor.pickups[index] = {rune = room.rune, x = W / 2, y = H / 2, opened = state.time}
        burst(W / 2, H / 2, "violet", 18)
        impact(W / 2, H / 2, "violet", 60, 0.44, 2)
        announce("RUNE DROPPED  /  WALK OVER TO COLLECT")
    elseif room.bossDoor and not doorOpen(index, room.bossDoor) then
        announce("CROWN GATE REQUIRES MORE RUNES")
    else
        announce("CHAMBER CLEARED")
    end
end

local function collectRune()
    local floor, p = state.floor, state.player
    local pickup = floor.pickups[state.room]
    if not pickup then return end
    if state.time - pickup.opened >= 0.25 and near(p.x, p.y, pickup.x, pickup.y, 20) then
        floor.runes[pickup.rune] = true
        floor.pickups[state.room] = nil
        local healed = math.min(2, 6 - p.hp)
        p.hp = p.hp + healed
        art.play("rune")
        burst(pickup.x, pickup.y, "violet", 30)
        burst(pickup.x, pickup.y, "white", 14)
        impact(pickup.x, pickup.y, "violet", 95, 0.44, 5)
        local runeCount = 0
        for _ in pairs(floor.runes) do runeCount = runeCount + 1 end
        if runeCount >= floor.runeRequired then
            announce("RUNE RECOVERED  /  CROWN CRYPT OPEN")
        elseif healed > 0 then
            announce("RUNE RECOVERED  /  +" .. healed .. " VITALITY")
        else
            announce("RUNE RECOVERED")
        end
    end
end

local function beginDescent()
    local nextPlayer = {}
    for key, value in pairs(state.player) do nextPlayer[key] = value end
    state.descent = {
        time = 0, duration = DESCENT_TIME,
        floor = floors.new(state.floor.depth + 1, love.math.random),
        player = spawnPlayer(nextPlayer),
    }
    state.bullets = {}
    state.ward = 0
    art.play("descent")
end

local function updateStep(dt)
    local p = state.player
    state.time = state.time + dt
    if state.mode ~= "play" then return end
    local mx, my, ax, ay, mouseX, mouseY, fire, dash, magic, pad = controls.read(scale, offsetX, offsetY)
    local descent = state.descent
    if descent then
        descent.time = descent.time + dt
        state.dashHeld, state.magicHeld = dash, magic
        if descent.time >= descent.duration then
            state.floor, state.room, state.player = descent.floor, 1, descent.player
            state.descent = nil
            clearEffects()
            state.dash, state.dashCooldown, state.shot, state.magic, state.invulnerable = 0, 0, 0, 0, 0
            announce("FLOOR " .. state.floor.depth)
        end
        return
    end
    if state.travel then
        state.travel.time = state.travel.time + dt
        if state.travel.time >= 0.43 then
            state.travel = nil
            state.invulnerable = 0.48
            local bossDoor = state.floor.rooms[state.room].bossDoor
            if state.floor.cleared[state.room] and bossDoor and not doorOpen(state.room, bossDoor) then
                announce("CROWN GATE REQUIRES MORE RUNES")
            end
        end
        state.dashHeld, state.magicHeld = dash, magic
        return
    end

    state.shake = math.max(0, state.shake - dt * 32)
    state.shakeX = math.sin(state.time * 137) * state.shake
    state.shakeY = math.sin(state.time * 191) * state.shake * 0.66
    state.flash = math.max(0, state.flash - dt)
    state.muzzle = math.max(0, state.muzzle - dt)
    state.messageTime = math.max(0, state.messageTime - dt)
    state.shot = math.max(0, state.shot - dt)
    state.dash = math.max(0, state.dash - dt)
    state.dashCooldown = math.max(0, state.dashCooldown - dt)
    state.invulnerable = math.max(0, state.invulnerable - dt)
    state.magic = math.max(0, state.magic - dt)
    state.ward = math.max(0, state.ward - dt)

    if not pad or love.mouse.isDown(1, 2) then
        ax, ay = mouseX - p.x - state.shakeX, mouseY - HUD - p.y - state.shakeY
    end
    if ax ~= 0 or ay ~= 0 then p.ax, p.ay = unit(ax, ay) end
    local ux, uy, magnitude = unit(mx, my)
    if dash and not state.dashHeld and state.dashCooldown == 0 then
        if magnitude == 0 then ux, uy = p.ax, p.ay end
        state.dashX, state.dashY = ux, uy
        state.dash, state.dashCooldown = 0.16, 0.85
        state.trail = 0
        impact(p.x, p.y, "cyan", 37, 0.2, 3)
        art.play("dash")
    end
    state.dashHeld = dash
    if state.dash > 0 then
        move(p, state.dashX * 420 * dt, state.dashY * 420 * dt, RADIUS, true)
        state.trail = state.trail - dt
        if state.trail <= 0 then
            state.ghosts[#state.ghosts + 1] = {x = p.x, y = p.y, ax = p.ax, ay = p.ay, life = 0.2}
            burst(p.x, p.y, "cyan", 2)
            state.trail = 0.024
        end
    else
        local speed = 155 * math.min(magnitude, 1)
        move(p, ux * speed * dt, uy * speed * dt, RADIUS, true)
    end

    if p.x <= 0 then enter("left", -1, 0)
    elseif p.x >= W then enter("right", 1, 0)
    elseif p.y <= 0 then enter("up", 0, -1)
    elseif p.y >= H then enter("down", 0, 1) end
    if state.travel then return end

    local ladder = state.floor.ladder
    if ladder and ladder.room == state.room and state.time - ladder.opened >= 0.8
        and near(p.x, p.y, ladder.x, ladder.y, 19) then
        beginDescent()
        return
    end

    if fire and state.shot == 0 then
        projectile(p.x + p.ax * 16, p.y + p.ay * 16, p.ax, p.ay, "gun")
        state.shot, state.muzzle = 0.125, 0.065
        state.shake = math.min(9, state.shake + 0.85)
        burst(p.x + p.ax * 17, p.y + p.ay * 17, "gold", 3)
        art.play("gun")
    end
    if magic and not state.magicHeld and state.magic == 0 then
        state.magic, state.ward = 3.4, 0.38
        for i = 0, 15 do
            local angle = i * TAU / 16
            projectile(p.x, p.y, math.cos(angle), math.sin(angle), "spell")
        end
        for i = #state.bullets, 1, -1 do
            local b = state.bullets[i]
            if b.kind == "hex" and near(b.x, b.y, p.x, p.y, 94) then table.remove(state.bullets, i) end
        end
        art.play("magic")
        burst(p.x, p.y, "violet", 32)
        impact(p.x, p.y, "violet", 100, 0.36, 5)
    end
    state.magicHeld = magic

    updateEnemies(dt)
    if state.mode == "play" then
        updateBullets(dt)
        if state.mode == "play" then
            updateRoom()
            collectRune()
        end
    end
    for i = #state.rings, 1, -1 do
        local ring = state.rings[i]
        ring.age = ring.age + dt
        if ring.age >= ring.duration then table.remove(state.rings, i) end
    end
    for i = #state.ghosts, 1, -1 do
        local ghost = state.ghosts[i]
        ghost.life = ghost.life - dt
        if ghost.life <= 0 then table.remove(state.ghosts, i) end
    end
    for i = #state.sparks, 1, -1 do
        local s = state.sparks[i]
        s.x, s.y, s.life = s.x + s.vx * dt, s.y + s.vy * dt, s.life - dt
        if s.life <= 0 then table.remove(state.sparks, i) end
    end
end

local accumulator = 0
function love.load()
    love.graphics.setBackgroundColor(0.01, 0.015, 0.013)
    art.load()
    reset()
end

function love.update(dt)
    accumulator = accumulator + math.min(dt, 0.1)
    while accumulator >= 1 / 120 do
        updateStep(1 / 120)
        accumulator = accumulator - 1 / 120
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    scale = math.min(w / W, h / 480)
    offsetX, offsetY = (w - W * scale) / 2, (h - 480 * scale) / 2
    art.draw(state, sides, scale, offsetX, offsetY, HUD)
end

local function confirm()
    if state.mode == "dead" then reset() end
    if state.mode == "title" or state.mode == "pause" then state.mode = "play" end
end

local function menu()
    if state.mode == "play" then state.mode = "pause"
    elseif state.mode == "pause" then state.mode = "play"
    else confirm() end
end

function love.keypressed(key)
    if key == "return" then confirm()
    elseif key == "p" then menu()
    elseif key == "escape" then love.event.quit() end
end

function love.gamepadpressed(_, button)
    if button == "start" then menu()
    elseif button == "back" and (state.mode == "pause" or state.mode == "title") then love.event.quit()
    elseif button == "a" and state.mode ~= "play" then confirm() end
end

