for _,path in ipairs({'source/main.lua','source/engine.lua','source/falling.lua','source/render.lua','source/modes.lua','source/submodes.lua','source/records.lua','source/soft_audio.lua','source/vfx.lua','source/vfx_presets.lua','source/versus.lua','source/pixel.lua','source/palettes.lua'}) do
 local code,err=loadfile(path)
 if not code then print('SYNTAX ERROR',path,err) os.exit(1) end
 print('OK',path)
end