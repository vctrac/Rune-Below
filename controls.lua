local controls = {}

local function stick(x, y, deadzone)
    local length = math.sqrt(x * x + y * y)
    if length <= deadzone then return 0, 0 end
    local strength = (math.min(length, 1) - deadzone) / (1 - deadzone)
    return x / length * strength, y / length * strength
end

function controls.read(scale, offsetX, offsetY)
    local keys = love.keyboard.isDown
    local mx = (keys("d") and 1 or 0) - (keys("a") and 1 or 0)
    local my = (keys("s") and 1 or 0) - (keys("w") and 1 or 0)
    local x, y = love.mouse.getPosition()
    x, y = (x - offsetX) / scale, (y - offsetY) / scale
    local fire, dash, magic = love.mouse.isDown(1), keys("lshift", "rshift"), love.mouse.isDown(2) or keys("e")
    for _, pad in ipairs(love.joystick.getJoysticks()) do
        if pad:isGamepad() then
            local gx, gy = stick(pad:getGamepadAxis("leftx"), pad:getGamepadAxis("lefty"), 0.17)
            if mx == 0 and my == 0 then mx, my = gx, gy end
            local rx, ry = pad:getGamepadAxis("rightx"), pad:getGamepadAxis("righty")
            local ax, ay = stick(rx, ry, 0.21)
            local atRim = rx * rx + ry * ry >= 0.92 * 0.92
            return mx, my, ax, ay, x, y, fire or atRim,
                dash or pad:isGamepadDown("leftshoulder"), magic or pad:isGamepadDown("rightshoulder"), true
        end
    end
    return mx, my, 0, 0, x, y, fire, dash, magic, false
end

return controls
