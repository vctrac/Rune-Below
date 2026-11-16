local orbit = {}

function orbit.position(player, time, index, count)
    local angle = time * 2.4 + index * 2 * math.pi / count
    return player.x + math.cos(angle) * 34, player.y + math.sin(angle) * 34
end

return orbit
