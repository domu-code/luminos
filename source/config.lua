function love.conf(t)
  t.identity = 'chromatic_tide'
  t.version = '11.5'
  t.window.title = 'CHROMATIC TIDE | Handheld Edition'
  t.window.width = 960
  t.window.height = 640
  t.window.resizable = true
  t.window.minwidth = 400
  t.window.minheight = 300
  t.window.vsync = 1
  t.window.fullscreen = false
  t.modules.physics = false
  t.modules.video = false
end
