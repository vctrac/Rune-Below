local sword = {
    damage = 4,
    cooldown = 0.42,
    duration = 0.24,
    startRadius = 10,
    reach = 48,
    halfAngle = math.pi * 0.22,
}

function sword.radius(progress)
    return sword.startRadius + (sword.reach - sword.startRadius) * (1 - (1 - progress)^2)
end

return sword
