package.path='./source/?.lua;'..package.path
local Submodes=require('submodes')
local Modes=require('modes')
assert(Modes.count==13,'13 game styles')
for mode=1,Modes.count do
 assert(Submodes.count(mode)>=4,'submodes missing '..mode)
 for index,item in ipairs(Submodes.forMode(mode)) do
  assert(item.name and item.description and item.kind,'mode metadata '..mode..'/'..index)
  assert(Submodes.get(mode,index)==item)
 end
end
local function fakeBoard()
 return {h=20,w=10,lines=0,cleared=0,score=0,bestChain=0,grid=(function()local t={}for y=1,20 do t[y]={}for x=1,10 do t[y][x]=0 end end return t end)()}
end
local b=fakeBoard()
assert(Submodes.progress(Submodes.get(5,3),b,179.5,0)==nil)
assert(Submodes.progress(Submodes.get(5,3),b,180,0)=='TIME UP')
assert(Submodes.progress(Submodes.get(5,2),b,0,0)==nil)
b.lines=40
assert(Submodes.progress(Submodes.get(5,2),b,0,0)=='GOAL COMPLETE')
b.lines=0
b.cleared=100
assert(Submodes.progress(Submodes.get(2,3),b,0,0)==nil) -- target 120
b.cleared=120
assert(Submodes.progress(Submodes.get(2,3),b,0,0)=='MISSION COMPLETE')
b.cleared=30
assert(Submodes.progress(Submodes.get(3,4),b,0,0)=='SWAP MISSION COMPLETE')
b.cleared=0
assert(Submodes.progress(Submodes.get(3,4),b,0,24)=='OUT OF SWAPS')
b.grid[18][2]=2;b.cleared=1
assert(Submodes.progress(Submodes.get(3,3),b,0,0)=='STAGE COMPLETE')
local base={mode=5,fallingGravity=.8,zoneStartCharge=0,vsCPU=false,riseSecs=15,selectedSubmode=1}
local altered=Submodes.configure(5,2,base)
assert(altered~=base and base.mode==5 and altered.mode==5)
local zen=Submodes.configure(2,5,base)
assert(zen.riseSecs==9999 and base.riseSecs==15)

-- Lightweight LÖVE emulator for input/UI+game-state regression tests.
local storage={}
local function nop(...) end
local function makeObj()
 local obj={}
 return setmetatable(obj,{__index=function()return nop end})
end
local G={}
setmetatable(G,{__index=function(_,k)
 if k=='getDimensions' then return function()return 640,440 end end
 if k=='newCanvas' or k=='newImage' or k=='newShader' or k=='newMesh' then return function()return makeObj() end end
 if k=='getCanvas' then return function()return nil end end
 if k=='getColor' then return function()return 1,1,1,1 end end
 if k=='getBlendMode' then return function()return 'alpha','alphamultiply' end end
 return nop
end})
love={graphics=G,math={newRandomGenerator=function()return {random=function(_,a,b) if a==nil then return math.random() end if b==nil then return math.random(a) end return math.random(a,b) end} end},
 image={newImageData=function()return makeObj() end},
 sound={newSoundData=function()return makeObj() end},
 audio={newSource=function()local o=makeObj();o.clone=function()return makeObj() end;o.isPlaying=function()return false end;return o end},
 keyboard={setKeyRepeat=nop,isDown=function()return false end,setTextInput=nop},
 filesystem={getInfo=function(name)return storage[name] and {type='file'} or nil end,
    load=function(name)return load(storage[name],name,'t') end,
    write=function(name,data)storage[name]=data;return true end},
 joystick={getJoysticks=function()return {} end},
 system={getOS=function()return 'Android' end},
 timer={getFPS=function()return 60 end},
 window={setFullscreen=nop}}
local ok,err=pcall(dofile,'source/main.lua')
assert(ok,'main loaded: '..tostring(err))
ok,err=pcall(love.load)
assert(ok,'love.load: '..tostring(err))
local ui
for i=1,30 do
 local name,value=debug.getupvalue(love.draw,i)
 if name=='ui' then ui=value;break end
end
assert(ui and ui.state=='mode','ui available')
local function key(k)
 local ok,err=pcall(love.keypressed,k)
 assert(ok,'input '..k..': '..tostring(err))
end
local function draw(tag)
 local ok,err=pcall(love.draw)
 assert(ok,'draw '..tag..': '..tostring(err))
end
local function update(dt)
 local ok,err=pcall(love.update,dt)
 assert(ok,'update: '..tostring(err))
end
assert(ui.cfg.ghostPiece==true,'ghost defaults enabled')
draw('13-game menu')
ui.mode=5
key('return')
assert(ui.state=='submode' and ui.mode==5)
assert(ui.submode==1)
draw('secondary mode menu')
key('down')
assert(ui.submode==2)
key('return')
assert(ui.state=='play' and ui.runSpec.kind=='sprint')
assert(ui.cfg.selectedSubmode==2 and ui.cfg.submode5==2)
assert(ui.board.isFalling,'falling mode')
local orig=ui.board.active
local beforeY=orig.y
local ghosts=ui.board:ghostCells()
assert(#ghosts>0 and orig.y==beforeY,'ghost non-mutating')
local lowest=-1000
for _,cell in ipairs(ghosts) do if cell[2]>lowest then lowest=cell[2] end end
assert(lowest>=beforeY,'ghost below active')
draw('ghost falling game')
ui.board.lines=40;ui.board.score=5000
update(.015)
assert(ui.state=='gameover' and ui.finishResult=='GOAL COMPLETE','sprint completion')
draw('win state')
local record=ui.records:list(0,5,false,2)
assert(#record==1 and record[1].won and record[1].seconds>0,'sprint leaderboard')
assert(#ui.records:list(0,5,false,1)==0,'isolation marathon vs sprint')
key('return')
assert(ui.state=='play' and ui.runElapsed==0,'restart timer reset')
key('escape')
assert(ui.state=='pause','pause')
key('b') -- B from pause return to game select? actual mapping B in pause: back
assert(ui.state=='mode')
-- Touch test of 13th style selection from screen (screen x350 y330)
draw('mode redraw')
love.touchpressed(1,360,301)
love.touchreleased(1,360,301)
assert(ui.state=='submode' and ui.mode==13,'13th style via touch')
draw('custom submode screen')
love.touchpressed(2,150,214)
love.touchreleased(2,150,214)
assert(ui.state=='play' and ui.submode==3,'touch selected third submode')
-- 2-minute timer must end and record time key distinct from submode1.
ui.state='mode';ui.mode=5;ui.cfg.submode5=1
key('return');key('down');key('down');key('return')
assert(ui.runSpec.kind=='time' and ui.runSpec.goal==180)
ui.runElapsed=179.98
ui.board.score=200
update(.03)
assert(ui.state=='gameover' and ui.finishResult=='TIME UP','ultra timed endpoint')
assert(#ui.records:list(0,5,false,3)==1,'ultra leaderboard')
-- Presets retain the selected submode.
ui.records:store(1,ui.cfg,'MARATHON TEST')
local loaded=ui.records:load(1,require('engine').defaults())
assert(loaded.selectedSubmode==3 and loaded.submode5==3,'preset stores secondary submode')
print('PASS: 13 base modes; per-game modes; objectives; ghosts; timer; scores; HUD; Android touch; presets')
-- Falling games with CPU must use a falling CPU board, not a rising cursor engine.
ui.state='mode';ui.mode=8;ui.cfg.submode8=1
key('return');key('return')
assert(ui.state=='play' and ui.vs and ui.vs.board.isFalling,'falling CPU initialized')
for i=1,28 do update(.06) end
assert(ui.vs.ticks>=1,'CPU took a falling action')
print('PASS: falling-versus CPU is using compatible game logic')
for mode=1,Modes.count do
 for sub=1,Submodes.count(mode) do
  ui.state='mode';ui.mode=mode;ui.modeTab=1
  ui.cfg['submode'..mode]=sub
  key('return')
  assert(ui.state=='submode' and ui.submode==sub,'mode screen '..mode..':'..sub)
  draw('submode '..mode..':'..sub)
  key('return')
  assert(ui.state=='play' and ui.runSubmode==sub,'play '..mode..':'..sub)
  update(.017)
  draw('game '..mode..':'..sub)
 end
end
print('PASS: all 67 submodes load, update and render in Android-style mock')