local Engine=require('engine')
local Renderer=require('render')
local Font=require('pixel')
local P=require('palettes')
local ui={}
local sound={}
local function clamp(a,b,c) return math.max(b,math.min(c,a)) end
local function isBool(v) return type(v)=='boolean' end
local function saveSettings()
  local keys={};for k in pairs(ui.cfg) do keys[#keys+1]=k end
  table.sort(keys)
  local lines={'return {'}
  for _,key in ipairs(keys) do
    local value=ui.cfg[key]
    if type(value)=='number' or type(value)=='boolean' then
      lines[#lines+1]='  '..key..' = '..tostring(value)..','
    end
  end
  lines[#lines+1]='}'
  love.filesystem.write('settings.lua',table.concat(lines,'\n'))
end
local function loadSettings()
  local cfg=Engine.defaults()
  if love.filesystem.getInfo('settings.lua') then
    local loader=love.filesystem.load('settings.lua')
    if loader then
      local ok,stored=pcall(loader)
      if ok and type(stored)=='table' then
        for k,v in pairs(cfg) do if type(stored[k])==type(v) then cfg[k]=stored[k] end end
      end
    end
  end
  cfg.mode=clamp(cfg.mode,1,4)
  cfg.colours=clamp(cfg.colours,2,10)
  cfg.cols=clamp(math.floor(cfg.cols/2)*2,8,18)
  cfg.palette=clamp(cfg.palette,1,#P.names)
  cfg.minGroup=clamp(cfg.minGroup,3,9)
  return cfg
end
local function row(label,key,kind,mn,mx,step,values)
  return {label=label,key=key,kind=kind,min=mn,max=mx,step=step,values=values}
end
ui.pageNames={'FIELD','MATCH','POWERS','GRAPHICS','SOUND'}
ui.pages={
  {row('WELL WIDTH','cols','int',8,18,2),row('CELL COLOURS','colours','int',2,10,1),
   row('START ROWS','startRows','int',2,12,2),row('RISE SECONDS','riseSecs','float',3,35,1),
   row('SWEEP SECONDS','sweepSecs','float',2,20,.5),row('GRAVITY','gravity','bool'),
   row('GAME SPEED','gameSpeed','float',.5,2,.1)},
  {row('GROUP MINIMUM','minGroup','int',3,9,1),row('LINK ICONS','icons','bool'),
   row('DUAL RESONANCE','linkResonance','bool'),row('BONUS TEXT','bonusText','bool'),
   row('FREEZE SECONDS','freezeSecs','float',2,15,1),
   row('PASSIVE CHAINS','passive','locked'),row('PALETTE','palette','palette',1,#P.names,1)},
  {row('BOMBS','bombs','bool'),row('SMALL BOMB %','bomb3','pct',0,.08,.002),
   row('MEDIUM BOMB %','bomb5','pct',0,.06,.002),row('BIG BOMB %','bomb7','pct',0,.04,.001),
   row('H BEAM %','beamH','pct',0,.06,.002),row('V BEAM %','beamV','pct',0,.06,.002),
   row('TIME FREEZE %','freezeRate','pct',0,.06,.002)},
  {row('PALETTE','palette','palette',1,#P.names,1),row('HUE DRIFT','hueDrift','bool'),
   row('ADAPTIVE QUALITY','adaptive','bool'),row('BLOOM','bloom','bool'),
   row('PARTICLES','particles','bool'),row('PAINTER %','painter','pct',0,.05,.001),
   row('SHIFTER %','shifter','pct',0,.05,.001)},
  {row('SOUND','sound','bool'),row('VOLUME','volume','float',0,1,.1),
   row('SAFE ROWS','passive','locked'),row('ACTION CURSOR','cursor','locked'),
   row('TWO-ROW WAVES','waves','locked'),row('TOP OUT','topout','locked'),
   row('SAVING','save','locked')}
}
function ui.optionText(r,cfg)
  if r.kind=='locked' then
    return r.key=='cursor' and 'MICROCELL' or r.key=='waves' and 'ONE ROW AT A TIME' or r.key=='topout' and 'ONE ROW EXIT' or r.key=='save' and 'AUTO' or 'DISABLED'
  end
  local v=cfg[r.key]
  if r.kind=='bool' then return v and 'ON' or 'OFF' end
  if r.kind=='palette' then return P.names[v] end
  if r.kind=='pct' then return string.format('%.1f%%',v*100) end
  if r.kind=='float' then return string.format('%.1f',v) end
  return tostring(v)
end
local function changeOption(delta)
  local r=ui.pages[ui.page][ui.selected]
  if not r or r.kind=='locked' then return end
  if r.kind=='bool' then ui.cfg[r.key]=not ui.cfg[r.key]
  else
    local new=clamp(ui.cfg[r.key]+delta*(r.step or 1),r.min,r.max)
    if r.kind=='int' or r.kind=='palette' then new=math.floor(new+.5)
    else new=math.floor(new*10000+.5)/10000 end
    ui.cfg[r.key]=new
  end
  if r.key=='palette' then ui.renderer.blurNeedsUpdate=true end
  sound.play('rotate')
end
local function changePage(dir)
  ui.page=(ui.page-1+dir+#ui.pages)%#ui.pages+1
  ui.selected=1;sound.play('rotate')
end
local function resetBoard()
  ui.board=Engine.new(ui.cfg)
  ui.board.cfg=ui.cfg
  ui.renderer.quality=ui.cfg.adaptive and 2 or 3
  ui.renderer:resizeBlur()
end
local function start(mode)
  ui.cfg.mode=mode;ui.mode=mode;ui.state='play';ui.paused=false
  resetBoard();saveSettings();sound.play('start')
end
local function options()
  ui.prevState=ui.state;ui.state='options';ui.page=1;ui.selected=1
end
local function leaveOptions(apply)
  if apply then
    saveSettings();resetBoard()
  else ui.cfg=loadSettings();ui.board.cfg=ui.cfg end
  ui.state=ui.prevState=='mode' and 'mode' or 'play'
end
local function generateSound(freq,duration,shape)
  local rate=22050;local samples=math.floor(rate*duration)
  local data=love.sound.newSoundData(samples,rate,16,1)
  for i=0,samples-1 do
    local t=i/rate;local envelope=math.pow(1-t/duration,2.3)
    local detune=shape=='beam' and 1+.3*math.sin(t*8) or 1
    local wave=math.sin(2*math.pi*freq*t*detune)+.21*math.sin(2*math.pi*freq*2.01*t)
    if shape=='bomb' then wave=wave+.4*math.sin(2*math.pi*freq*.43*t) end
    data:setSample(i,clamp(wave*.27*envelope,-1,1))
  end
  return love.audio.newSource(data,'static')
end
function sound.play(event)
  if not ui.cfg or not ui.cfg.sound then return end
  local src=sound.bank[event] or sound.bank.rotate
  if src then
    local clone=src:clone()
    clone:setVolume(ui.cfg.volume or .55)
    clone:play()
    sound.playing[#sound.playing+1]=clone
    if #sound.playing>24 then table.remove(sound.playing,1) end
  end
end
local function dispatch(action)
  local state=ui.state
  if state=='mode' then
    if action=='up' or action=='left' then ui.mode=(ui.mode+2)%4+1;sound.play('rotate')
    elseif action=='down' or action=='right' then ui.mode=ui.mode%4+1;sound.play('rotate')
    elseif action=='a' or action=='cw' or action=='start' then start(ui.mode)
    elseif action=='options' or action=='y' then options()
    end
  elseif state=='options' then
    if action=='up' then ui.selected=(ui.selected-2+#ui.pages[ui.page])%#ui.pages[ui.page]+1
    elseif action=='down' then ui.selected=ui.selected%#ui.pages[ui.page]+1
    elseif action=='left' then changeOption(-1)
    elseif action=='right' then changeOption(1)
    elseif action=='prevPage' then changePage(-1)
    elseif action=='nextPage' then changePage(1)
    elseif action=='a' or action=='start' then leaveOptions(true)
    elseif action=='b' or action=='back' then leaveOptions(false)
    end
  elseif state=='help' then
    if action=='b' or action=='a' or action=='start' then ui.state='play' end
  elseif state=='pause' or state=='gameover' then
    if action=='a' or action=='start' then
      if state=='gameover' then resetBoard() end
      ui.state='play'
    elseif action=='b' or action=='back' then ui.state='mode' end
  elseif state=='play' then
    if action=='up' then ui.board:move(0,-1)
    elseif action=='down' then ui.board:move(0,1)
    elseif action=='left' then ui.board:move(-1,0)
    elseif action=='right' then ui.board:move(1,0)
    elseif action=='a' or action=='cw' then ui.board:act(true)
    elseif action=='b' or action=='ccw' then ui.board:act(false)
    elseif action=='y' or action=='start' then ui.state='pause'
    elseif action=='options' then options()
    elseif action=='mode' or action=='back' then ui.state='mode'
    elseif action=='help' then ui.state='help'
    elseif action=='palette' then ui.cfg.palette=ui.cfg.palette%#P.names+1;saveSettings()
    end
  end
end
local keyAction={
  left='left',right='right',up='up',down='down',
  a='left',d='right',w='up',s='down',
  x='a',e='a',z='b',q='b',
  ['return']='start',kpenter='start',escape='back',
  o='options',b='mode',h='help',['?']='help',
  c='palette',p='y',tab='nextPage',['[']='prevPage',[']']='nextPage',
  pageup='prevPage',pagedown='nextPage',
}
function love.load()
  math.randomseed(os.time())
  Font.init()
  ui.cfg=loadSettings()
  ui.state='mode';ui.mode=ui.cfg.mode;ui.page=1;ui.selected=1
  ui.renderer=Renderer.new()
  ui.touch=love.system.getOS()=='Android' or love.system.getOS()=='iOS'
  ui.boost=false;ui.boostTouch={};ui.repeatDelay=0;ui.lastDir=nil
  sound.playing={}
  sound.bank={rotate=generateSound(440,.12),rise=generateSound(150,.065),
    start=generateSound(659,.3),clear=generateSound(659,.42),
    dual=generateSound(880,.5),bomb=generateSound(112,.45,'bomb'),
    beam=generateSound(1190,.48,'beam'),lose=generateSound(105,.85,'bomb')}
  resetBoard()
  if ui.touch then pcall(love.window.setFullscreen,true,'desktop') end
end
function love.update(dt)
  dt=math.min(dt or 0,.06)
  ui.renderer:adaptive(dt,ui.cfg.adaptive)
  if ui.state=='play' then
    ui.board:update(dt*(ui.cfg.gameSpeed or 1),ui.boost)
    if ui.board.gameover then ui.state='gameover' end
  end
  if ui.board.soundEvents then
    for _,ev in ipairs(ui.board.soundEvents) do sound.play(ev) end
    ui.board.soundEvents={}
  end
  for i=#sound.playing,1,-1 do if not sound.playing[i]:isPlaying() then table.remove(sound.playing,i) end end
  -- Repeating held d-pad directions and analog sticks on handheld controllers.
  local active
  for _,j in ipairs(love.joystick.getJoysticks()) do
    if j:isGamepad() then
      local ax=j:getGamepadAxis('leftx');local ay=j:getGamepadAxis('lefty')
      if j:isGamepadDown('dpleft') or ax<-.55 then active='left'
      elseif j:isGamepadDown('dpright') or ax>.55 then active='right'
      elseif j:isGamepadDown('dpup') or ay<-.55 then active='up'
      elseif j:isGamepadDown('dpdown') or ay>.55 then active='down' end
      if j:isGamepadDown('x') then ui.boost=true end
      break
    end
  end
  if active then
    ui.repeatDelay=ui.repeatDelay-dt
    if active~=ui.lastDir then ui.repeatDelay=.17;ui.lastDir=active
    elseif ui.repeatDelay<=0 then dispatch(active);ui.repeatDelay=.09 end
  else ui.lastDir=nil;ui.repeatDelay=0 end
end
function love.draw() ui.renderer:draw(ui) end
function love.resize(w,h) ui.renderer.blurNeedsUpdate=true end
function love.keypressed(key)
  if key=='space' then ui.boost=true;return end
  if key=='f5' then saveSettings();return end
  if key=='r' and ui.state=='play' then resetBoard();return end
  local action=keyAction[key]
  if action then
    if key=='b' and ui.state=='play' then dispatch('mode')
    elseif key=='escape' and ui.state=='play' then dispatch('y')
    elseif key=='o' and ui.state=='options' then dispatch('b')
    elseif key=='p' and ui.state=='pause' then dispatch('a')
    else dispatch(action) end
  end
end
function love.keyreleased(key) if key=='space' then ui.boost=false end end
local gamepadActions={dpup='up',dpdown='down',dpleft='left',dpright='right',a='a',b='b',x='boost',y='y',start='start',back='back',leftshoulder='prevPage',rightshoulder='nextPage'}
function love.gamepadpressed(joystick,button)
  local a=gamepadActions[button]
  if a=='boost' then ui.boost=true
  elseif a=='y' and ui.state=='mode' then dispatch('options')
  elseif a=='y' and ui.state=='play' then dispatch('y')
  elseif a=='b' and ui.state=='options' then dispatch('b')
  elseif a=='b' and ui.state=='mode' then dispatch('options')
  elseif a then dispatch(a) end
end
function love.gamepadreleased(joystick,button)
  if button=='x' then ui.boost=false end
end
local function screenTouch(x,y)
  local rx,ry=ui.renderer:point(x,y)
  if rx<0 or rx>640 or ry<0 or ry>440 then return nil end
  if ui.state=='mode' then
    if rx>50 and rx<590 and ry>103 and ry<355 then
      local m=clamp(math.floor((ry-111)/61)+1,1,4)
      ui.mode=m;dispatch('start')
    elseif ry>390 then dispatch('options') end
  elseif ui.state=='options' then
    if ry>96 and ry<388 then
      local idx=math.floor((ry-101)/37)+1
      if idx>=1 and idx<=#ui.pages[ui.page] then ui.selected=idx;changeOption(rx<370 and -1 or 1) end
    elseif ry<90 then changePage(1)
    elseif ry>390 then dispatch('start') end
  elseif ui.state=='play' then
    local bx=ui.renderer.bx or 245;local by=ui.renderer.by or 45
    if rx>=bx and rx<bx+ui.board.w*15 and ry>=by and ry<by+ui.board.h*15 then
      ui.board.cx=clamp(math.floor((rx-bx)/15)+1,1,ui.board.w-1)
      ui.board.cy=clamp(math.floor((ry-by+ui.board.rise*15)/15)+1,1,ui.board.h-(ui.cfg.mode==3 and 0 or 1))
      ui.board:act(true)
    elseif ry>=383 then
      local buttons={{27,60,'left'},{64,97,'right'},{101,134,ry<405 and 'up' or 'down'},
        {415,468,'ccw'},{474,527,'cw'},{534,620,'boost'}}
      for _,v in ipairs(buttons) do if rx>=v[1] and rx<=v[2] then
        if v[3]=='boost' then ui.boost=true;return 'boost' end
        dispatch(v[3]);break
      end end
    elseif ry<39 then dispatch('y') end
  elseif ui.state=='pause' or ui.state=='gameover' then
    if ry<290 then dispatch('start') else dispatch('back') end
  elseif ui.state=='help' then dispatch('b') end
  return nil
end
function love.touchpressed(id,x,y) ui.boostTouch[id]=screenTouch(x,y) end
function love.touchreleased(id)
  if ui.boostTouch[id]=='boost' then ui.boost=false end
  ui.boostTouch[id]=nil
end
function love.mousepressed(x,y,button)
  if not ui.touch then screenTouch(x,y) end
end
function love.wheelmoved(x,y)
  if ui.state=='options' and y~=0 then changePage(y<0 and 1 or -1) end
end
function love.quit() saveSettings() end
