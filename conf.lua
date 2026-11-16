function love.conf(t)
    t.identity = "rune-below"
    t.version = "11.4"
    t.window.title = "Rune Below"
    t.window.width, t.window.height = 640, 480
    t.window.minwidth, t.window.minheight = 320, 240
    t.window.resizable = true
    t.window.fullscreen = os.getenv("RUNE_BELOW_HANDHELD") == "1"
    t.modules.physics = false
end
