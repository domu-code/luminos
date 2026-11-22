local Engine=require('engine')
local Renderer=require('render')
local Font=require('pixel')
local P=require('palettes')
local Versus=require('versus')
local Records=require('records')
local ui={}
local sound={}
local function clamp(a,b,c) return math.max(b,math.min(c,a)) end
local function isBool(v) return type(v)=='boolean' end
local function setKeyboardRepeat(enabled)
  if love.keyboard and love.keyboard.setKeyRepeat then love.keyboard.setKeyRepeat(enabled) end
end
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
  cfg.touchMode=clamp(math.floor(cfg.touchMode),1,2)
  cfg.renderStyle=clamp(math.floor(cfg.renderStyle),1,4)
  cfg.selfGarbageRate=clamp(cfg.selfGarbageRate,0,.08)
  cfg.selfGarbageCount=clamp(math.floor(cfg.selfGarbageCount),1,24)
  cfg.glowPower=clamp(cfg.glowPower,0,2.5)
  cfg.particlePower=clamp(cfg.particlePower,0,2.5)
  cfg.juicePower=clamp(cfg.juicePower,0,2.5)
  cfg.boostSpeed=clamp(cfg.boostSpeed,1.5,12)
  cfg.boostReward=clamp(cfg.boostReward,0,3)
  cfg.cpuSkill=clamp(cfg.cpuSkill,0,1)
  cfg.cpuSpeed=clamp(cfg.cpuSpeed,.4,2)
  cfg.garbagePower=clamp(cfg.garbagePower,0,3)
  cfg.garbageDelay=clamp(cfg.garbageDelay,.3,5)
  cfg.comboVolume=clamp(cfg.comboVolume,0,2)
  cfg.randomRows=clamp(cfg.randomRows,0,3)
  cfg.gamepadDeadzone=clamp(cfg.gamepadDeadzone,.2,.85)
  cfg.keyboardLayout=clamp(math.floor(cfg.keyboardLayout),1,3)
  cfg.mouseMode=clamp(math.floor(cfg.mouseMode),0,2)
  cfg.mouseSensitivity=clamp(cfg.mouseSensitivity,.4,3)
  cfg.surgeRate=clamp(cfg.surgeRate,0,.08)
  cfg.garbageSmallRate=clamp(cfg.garbageSmallRate,0,.08)
  cfg.garbageMediumRate=clamp(cfg.garbageMediumRate,0,.06)
  cfg.garbageLargeRate=clamp(cfg.garbageLargeRate,0,.04)
  cfg.garbageSmallCount=clamp(cfg.garbageSmallCount,1,6)
  cfg.garbageMediumCount=clamp(cfg.garbageMediumCount,2,12)
  cfg.garbageLargeCount=clamp(cfg.garbageLargeCount,4,24)
  cfg.garbageChainMultiplier=clamp(cfg.garbageChainMultiplier,0,3)
  return cfg
end
local function row(label,key,kind,mn,mx,step,values)
  return {label=label,key=key,kind=kind,min=mn,max=mx,step=step,values=values}
end
ui.pageNames={'FIELD','MATCH','POWERS','SURGE+GARBAGE','CURSES','GRAPHICS','PALETTE','SOUND','CONTROLS','BOOST','VERSUS','PRESETS','EXTRAS','SHINE RULES','LINK RULES','ATTACK RULES','BRIDGE RULES'}
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
  {row('SURGE CELL %','surgeRate','pct',0,.08,.002),
   row('SMALL DROP %','garbageSmallRate','pct',0,.08,.002),
   row('MED DROP %','garbageMediumRate','pct',0,.06,.002),
   row('LARGE DROP %','garbageLargeRate','pct',0,.04,.001),
   row('SMALL BLOCKS','garbageSmallCount','int',1,6,1),
   row('MEDIUM BLOCKS','garbageMediumCount','int',2,12,1),
   row('LARGE BLOCKS','garbageLargeCount','int',4,24,1),
   row('VS DROP POWER','garbageChainMultiplier','float',0,3,.25),
   row('GARBAGE GROUP','garbageCluster','locked')},
  {row('SELF GARBAGE %','selfGarbageRate','pct',0,.08,.002),
   row('SELF GARBAGE COUNT','selfGarbageCount','int',1,24,1),
   row('NO PENALTY CANCEL','selfCurse','locked'),
   row('BLOCK COLOUR','effectColour','locked')},
  {row('VISUAL STYLE','renderStyle','style',1,4,1),
   row('ADAPTIVE QUALITY','adaptive','bool'),row('BLOOM','bloom','bool'),
   row('GLOW POWER','glowPower','float',0,2.5,.1),
   row('BLOOM STRENGTH','bloomIntensity','float',0,3,.1),
   row('PARTICLES','particles','bool'),row('PARTICLE POWER','particlePower','float',0,2.5,.1),
   row('SCREEN SHAKE','shakePower','float',0,2,.1),
   row('CLEAR FLASH','flashPower','float',0,2.5,.1),
   row('EXPLOSION JUICE','juicePower','float',0,2.5,.1),
   row('TRAIL POWER','trailPower','float',0,2.5,.1),
   row('BACKGROUND DETAIL','backgroundDetail','int',0,4,1),
   row('SCREEN CONTRAST','screenContrast','float',.5,2,.1)},
  {row('PALETTE','palette','palette',1,#P.names,1),
   row('PALETTE SATURATION','paletteSaturation','float',0,2,.1),
   row('PALETTE BRIGHTNESS','paletteBrightness','float',.2,1.5,.1),
   row('PALETTE HUE','paletteHue','int',-180,180,5),
   row('AUTOMATIC HUE DRIFT','hueDrift','bool'),
   row('PALETTE CYCLE SECS','paletteCycleSecs','float',0,60,2)},
  {row('SOUND','sound','bool'),row('VOLUME','volume','float',0,1,.1),
   row('SAFE ROWS','passive','locked'),row('ACTION CURSOR','cursor','locked'),
   row('TWO-ROW WAVES','waves','locked'),row('TOP OUT','topout','locked'),
   row('SAVING','save','locked')},
  {row('TOUCH CONTROL','touchMode','touch',1,2,1),
   row('DRAG SENSITIVITY','touchSensitivity','float',.4,3,.1),
   row('DPAD DIRECTION SIZE','padSize','locked'),
   row('RELATIVE TOUCH','relative','locked'),
   row('BOOST BUTTON','boost','locked'),
   row('MOUSE CONTROL','mouseMode','mouse',0,2,1),
   row('MOUSE SPEED','mouseSensitivity','float',.4,3,.1),
   row('USB KEYBOARD','keyboardEnabled','bool'),
   row('KEYBOARD LAYOUT','keyboardLayout','keyboard',1,3,1),
   row('KEY AUTO REPEAT','keyboardRepeat','bool'),
   row('USB GAMEPAD','gamepadEnabled','bool'),
   row('STICK DEADZONE','gamepadDeadzone','float',.2,.85,.05)},
  {row('BOOST SPEED','boostSpeed','float',1.5,12,.5),
   row('BOOST REWARD','boostReward','float',0,3,.25),
   row('RISING RANDOMNESS','randomRows','float',0,3,.25),
   row('GAME SPEED','gameSpeed','float',.5,2,.1),
   row('RISK MULTIPLIER','risk','locked'),row('BOOST CAN TOP OUT','boostrisk','locked')},
  {row('VS CPU','vsCPU','bool'),row('CPU SKILL','cpuSkill','float',0,1,.1),
   row('CPU SPEED','cpuSpeed','float',.4,2,.1),row('GARBAGE POWER','garbagePower','float',0,3,.25),
   row('GARBAGE DELAY','garbageDelay','float',.3,5,.2),
   row('BREAK GARBAGE','garbageBreak','bool')},
  {row('PRESET SLOT','presetSlot','slot',1,8,1),row('SAVE PRESET','savePreset','command'),
   row('LOAD PRESET','loadPreset','command'),row('HIGH SCORES','scores','command'),
   row('SCORE MODE','scoreMode','mode',1,4,1),row('SCORE CATEGORY','scoreVS','scoreType'),
   row('ACTIVE PRESET','activeSlot','locked')},
  {row('LIGHT PULSE','visualPulse','float',0,2,.1),
   row('COMBO AUDIO','comboVolume','float',0,2,.1),
   row('PAINTER %','painter','pct',0,.05,.001),
   row('SHIFTER %','shifter','pct',0,.05,.001),
   row('NO PASSIVE CHAINS','passive','locked')},
  {row('SHINE CLEAR DELAY','shineClearDelay','float',0,12,.25),
   row('SHINE CHAIN WINDOW','shineChainWindow','float',1,60,1),
   row('SHINE ROW SPEED','shineRiseSecs','float',3,40,1),
   row('SHINE SWEEP SPEED','shineSweepSecs','float',2,25,.5),
   row('SHINE GRAVITY STEP','shineGravitySecs','float',.035,.5,.025),
   row('SHINE SCORE SCALE','shineScorePower','float',.25,5,.25)},
  {row('LINK CLEAR DELAY','linkClearDelay','float',0,12,.25),
   row('LINK CHAIN WINDOW','linkChainWindow','float',1,60,1),
   row('LINK ROW SPEED','linkRiseSecs','float',3,40,1),
   row('LINK SWEEP SPEED','linkSweepSecs','float',2,25,.5),
   row('LINK GRAVITY STEP','linkGravitySecs','float',.035,.5,.025),
   row('LINK SCORE SCALE','linkScorePower','float',.25,5,.25)},
  {row('ATTACK CLEAR DELAY','attackClearDelay','float',0,12,.25),
   row('ATTACK CHAIN WINDOW','attackChainWindow','float',1,60,1),
   row('ATTACK ROW SPEED','attackRiseSecs','float',3,40,1),
   row('ATTACK GRAVITY STEP','attackGravitySecs','float',.035,.5,.025),
   row('ATTACK SCORE SCALE','attackScorePower','float',.25,5,.25)},
  {row('BRIDGE CLEAR DELAY','bridgeClearDelay','float',0,12,.25),
   row('BRIDGE CHAIN WINDOW','bridgeChainWindow','float',1,60,1),
   row('BRIDGE ROW SPEED','bridgeRiseSecs','float',3,40,1),
   row('BRIDGE SWEEP SPEED','bridgeSweepSecs','float',2,25,.5),
   row('BRIDGE GRAVITY STEP','bridgeGravitySecs','float',.035,.5,.025),
   row('BRIDGE SCORE SCALE','bridgeScorePower','float',.25,5,.25)}
}
function ui.optionText(r,cfg)
  if r.kind=='locked' then
    return r.key=='activeSlot' and (ui.activeSlot==0 and 'CUSTOM' or 'SLOT '..ui.activeSlot) or r.key=='boostrisk' and 'YES' or r.key=='risk' and 'SCORE X1-PLUS' or r.key=='garbageCluster' and 'ALL CONNECTED' or r.key=='selfCurse' and 'MANDATORY' or r.key=='effectColour' and 'YES / MATCHABLE' or r.key=='padSize' and 'EQUAL 42X42' or r.key=='relative' and 'LEFT DRAG' or r.key=='boost' and 'HOLD TO CHARGE' or r.key=='gamepad' and 'ALWAYS AVAILABLE' or r.key=='cursor' and 'MICROCELL' or r.key=='waves' and 'ONE ROW AT A TIME' or r.key=='topout' and 'ONE ROW EXIT' or r.key=='save' and 'AUTO' or 'DISABLED'
  end
  local v=cfg[r.key]
  if r.kind=='bool' then return v and 'ON' or 'OFF' end
  if r.kind=='touch' then return v==1 and 'DPAD + BUTTONS' or 'RELATIVE TOUCH' end
  if r.kind=='style' then return ({'NEON','8-BIT','4-BIT','1-BIT'})[v] end
  if r.kind=='mouse' then return ({'OFF','DIRECT','RELATIVE'})[v+1] end
  if r.kind=='keyboard' then return ({'WASD + ARROWS','ARROWS ONLY','IJKL + ARROWS'})[v] end
  if r.kind=='slot' then return tostring(ui.presetSlot)..(ui.records.slots[ui.presetSlot] and ' SAVED' or ' EMPTY') end
  if r.kind=='mode' then return ({'SHINE','LINK','ATTACK','BRIDGE'})[ui.scoreMode] end
  if r.kind=='scoreType' then return ui.scoreVS and 'VS CPU' or 'SOLO' end
  if r.kind=='command' then return '[ ACTIVATE ]' end
  if r.kind=='palette' then return P.names[v] end
  if r.kind=='pct' then return string.format('%.1f%%',v*100) end
  if r.kind=='float' then return string.format('%.1f',v) end
  return tostring(v)
end
local function changeOption(delta)
  local r=ui.pages[ui.page][ui.selected]
  if not r or r.kind=='locked' then return end
  if r.kind=='command' then return end
  if r.kind=='slot' then ui.presetSlot=clamp(ui.presetSlot+delta,1,8);return end
  if r.kind=='mode' then ui.scoreMode=clamp(ui.scoreMode+delta,1,4);return end
  if r.kind=='scoreType' then ui.scoreVS=not ui.scoreVS;return end
  ui.activeSlot=0
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
  ui.vs=ui.cfg.vsCPU and Versus.new(ui.cfg) or nil
  ui.scoreSaved=false
  ui.renderer.quality=ui.cfg.adaptive and 2 or 3
  ui.renderer:resizeBlur()
end
local function start(mode)
  ui.cfg.mode=mode;ui.mode=mode;ui.state='play';ui.paused=false
  ui.runSlot=ui.activeSlot
  ui.runVS=ui.cfg.vsCPU
  resetBoard();saveSettings();sound.play('start')
end
local function saveScore()
  if ui.scoreSaved or not ui.board then return end
  ui.scoreSaved=true
  if ui.records then
    ui.records:record(ui.runSlot or 0,ui.cfg.mode,ui.runVS or false,
      ui.board.score,ui.board.bestChain,ui.board.cleared,
      ui.vs and ui.vs.winner=='PLAYER' or false)
  end
end
local function actionPreset()
  local r=ui.pages[ui.page][ui.selected]
  if r.key=='savePreset' then
    ui.records:store(ui.presetSlot,ui.cfg)
    ui.activeSlot=ui.presetSlot;ui.toast='SLOT '..ui.presetSlot..' SAVED'
    saveSettings()
  elseif r.key=='loadPreset' then
    local loaded=ui.records:load(ui.presetSlot,Engine.defaults())
    if loaded then ui.cfg=loaded;setKeyboardRepeat(ui.cfg.keyboardRepeat);ui.activeSlot=ui.presetSlot
      ui.toast='SLOT '..ui.presetSlot..' LOADED'
      saveSettings()
    else ui.toast='SLOT IS EMPTY' end
  elseif r.key=='scores' then
    ui.state='scores'
  end
end
local function options()
  ui.prevState=ui.state;ui.state='options';ui.page=1;ui.selected=1
end
local function leaveOptions(apply)
  if apply then
    setKeyboardRepeat(ui.cfg.keyboardRepeat);ui.keyBoost=false;saveSettings();resetBoard()
  else ui.cfg=loadSettings();setKeyboardRepeat(ui.cfg.keyboardRepeat);ui.keyBoost=false;ui.board.cfg=ui.cfg end
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
    local vol=ui.cfg.volume or .55
    if event=='super' or event=='chain' or event:sub(1,5)=='combo' then vol=vol*(ui.cfg.comboVolume or 1) end
    clone:setVolume(math.min(1,vol))
    clone:play()
    sound.playing[#sound.playing+1]=clone
    if #sound.playing>24 then table.remove(sound.playing,1) end
  end
end
local function dispatch(action)
  local state=ui.state
  if state=='mode' then
    if action=='versus' then ui.cfg.vsCPU=not ui.cfg.vsCPU;ui.activeSlot=0;saveSettings();sound.play('rotate')
    elseif action=='up' or action=='left' then ui.mode=(ui.mode+2)%4+1;sound.play('rotate')
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
    elseif action=='a' or action=='start' then
      local r=ui.pages[ui.page][ui.selected]
      if r and r.kind=='command' then actionPreset() else leaveOptions(true) end
    elseif action=='b' or action=='back' then leaveOptions(false)
    end
  elseif state=='scores' then
    if action=='left' then ui.scoreMode=(ui.scoreMode+2)%4+1
    elseif action=='right' then ui.scoreMode=ui.scoreMode%4+1
    elseif action=='up' or action=='down' then ui.scoreVS=not ui.scoreVS
    elseif action=='b' or action=='back' or action=='a' or action=='start' then ui.state='options' end
  elseif state=='help' then
    if action=='b' or action=='a' or action=='start' then ui.state='play' end
  elseif state=='pause' or state=='gameover' then
    if state=='gameover' then saveScore() end
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
  i='up',j='left',k='down',l='right',
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
  setKeyboardRepeat(ui.cfg.keyboardRepeat)
  ui.records=Records.new(Engine.defaults())
  ui.presetSlot=1;ui.scoreMode=ui.cfg.mode;ui.scoreVS=false
  ui.activeSlot=0;ui.toast=''
  ui.state='mode';ui.mode=ui.cfg.mode;ui.page=1;ui.selected=1
  ui.renderer=Renderer.new()
  ui.touch=love.system.getOS()=='Android' or love.system.getOS()=='iOS'
  ui.boost=false;ui.touchFingers={};ui.keyBoost=false;ui.padBoost=false
  ui.mouseBoost=false;ui.mouseHeld=false;ui.mouseMoved=false;ui.mouseStartX=0;ui.mouseStartY=0
  ui.repeatDelay=0;ui.lastDir=nil
  sound.playing={}
  sound.bank={rotate=generateSound(440,.12),rise=generateSound(150,.065),
    start=generateSound(659,.3),clear=generateSound(659,.42),
    dual=generateSound(880,.5),bomb=generateSound(112,.45,'bomb'),
    beam=generateSound(1190,.48,'beam'),lose=generateSound(105,.85,'bomb'),
    chain=generateSound(740,.65),super=generateSound(1070,.92,'beam'),
    surge=generateSound(380,.46,'beam'),garbage=generateSound(180,.64,'bomb'),curse=generateSound(95,.75,'bomb')}
  for i=2,8 do sound.bank['combo'..i]=generateSound(480*2^((i-2)/12),.46+i*.05,'beam') end
  resetBoard()
  if ui.touch then pcall(love.window.setFullscreen,true,'desktop') end
end
function love.update(dt)
  dt=math.min(dt or 0,.06)
  ui.renderer:adaptive(dt,ui.cfg.adaptive)
  ui.padBoost=false
  if ui.cfg.gamepadEnabled then
    for _,pad in ipairs(love.joystick.getJoysticks()) do
      if pad:isGamepad() then
        if pad:isGamepadDown('x') or pad:getGamepadAxis('triggerleft')>.6 or
          pad:getGamepadAxis('triggerright')>.6 then ui.padBoost=true;break end
      elseif pad:getButtonCount()>=3 and pad:isDown(3) then ui.padBoost=true;break end
    end
  end
  local touchBoost=false
  for _,finger in pairs(ui.touchFingers) do
    if finger.kind=='boost' then touchBoost=true
    elseif finger.kind=='direction' and ui.state=='play' then
      finger.delay=finger.delay-dt
      if finger.delay<=0 then dispatch(finger.action);finger.delay=.086 end
    end
  end
  ui.boost=ui.keyBoost or ui.padBoost or ui.mouseBoost or touchBoost
  if ui.state=='play' then
    local elapsed=dt*(ui.cfg.gameSpeed or 1)
    ui.board:update(elapsed,ui.boost)
    if ui.vs then ui.vs:update(elapsed,ui.board) end
    if ui.board.gameover or ui.vs and ui.vs.ended then
      ui.state='gameover';saveScore()
    end
  end
  if ui.board.soundEvents then
    for _,ev in ipairs(ui.board.soundEvents) do sound.play(ev) end
    ui.board.soundEvents={}
  end
  if ui.vs and ui.vs.board.soundEvents then
    for _,ev in ipairs(ui.vs.board.soundEvents) do
      if ev~='rotate' and ev~='rise' then sound.play(ev) end
    end
    ui.vs.board.soundEvents={}
  end
  for i=#sound.playing,1,-1 do if not sound.playing[i]:isPlaying() then table.remove(sound.playing,i) end end
  -- Repeating held d-pad directions and analog sticks on handheld controllers.
  local active
  if ui.cfg.gamepadEnabled then
    for _,j in ipairs(love.joystick.getJoysticks()) do
      local ax,ay=0,0;local up,down,left,right=false,false,false,false
      if j:isGamepad() then
        ax=j:getGamepadAxis('leftx');ay=j:getGamepadAxis('lefty')
        left=j:isGamepadDown('dpleft');right=j:isGamepadDown('dpright')
        up=j:isGamepadDown('dpup');down=j:isGamepadDown('dpdown')
      else
        if j:getAxisCount()>0 then ax=j:getAxis(1) end
        if j:getAxisCount()>1 then ay=j:getAxis(2) end
        if j:getHatCount()>0 then
          local hat=j:getHat(1)
          left=hat:find('l',1,true)~=nil;right=hat:find('r',1,true)~=nil
          up=hat:find('u',1,true)~=nil;down=hat:find('d',1,true)~=nil
        end
      end
      local dead=ui.cfg.gamepadDeadzone or .52
      if left or ax < -dead then active='left'
      elseif right or ax > dead then active='right'
      elseif up or ay < -dead then active='up'
      elseif down or ay > dead then active='down' end
      if active then break end
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
  -- Physical USB/OTG and Bluetooth keyboards use these ordinary LÖVE events.
  -- Keep menu recovery available even with keyboard gameplay disabled.
  if key=='o' and ui.state=='options' then dispatch('b');return end
  if key=='escape' and ui.state=='play' then dispatch('y');return end
  if key=='escape' and ui.state=='options' then dispatch('b');return end
  if not ui.cfg.keyboardEnabled then return end
  if (ui.cfg.keyboardLayout==2 and (key=='w' or key=='a' or key=='s' or key=='d')) or
     (ui.cfg.keyboardLayout==1 and (key=='i' or key=='j' or key=='k' or key=='l')) then return end
  if key=='space' then ui.keyBoost=true;return end
  if key=='f5' then saveSettings();return end
  if key=='r' and ui.state=='play' then resetBoard();return end
  if key=='v' and ui.state=='mode' then dispatch('versus');return end
  local action=keyAction[key]
  if action then
    if key=='b' and ui.state=='play' then dispatch('mode')
    elseif key=='escape' and ui.state=='play' then dispatch('y')
    elseif key=='o' and ui.state=='options' then dispatch('b')
    elseif key=='p' and ui.state=='pause' then dispatch('a')
    else dispatch(action) end
  end
end
function love.keyreleased(key) if key=='space' then ui.keyBoost=false end end
local gamepadActions={dpup='up',dpdown='down',dpleft='left',dpright='right',a='a',b='b',x='boost',y='y',start='start',back='back',leftshoulder='prevPage',rightshoulder='nextPage'}
function love.gamepadpressed(joystick,button)
  if not ui.cfg.gamepadEnabled then return end
  if ui.state=='play' then
    if button=='leftshoulder' then dispatch('ccw');return end
    if button=='rightshoulder' then dispatch('cw');return end
  end
  local a=gamepadActions[button]
  if a=='boost' then ui.padBoost=true
  elseif a=='y' and ui.state=='mode' then dispatch('options')
  elseif a=='y' and ui.state=='play' then dispatch('y')
  elseif a=='b' and ui.state=='options' then dispatch('b')
  elseif a=='b' and ui.state=='mode' then dispatch('options')
  elseif a then dispatch(a) end
end
function love.gamepadreleased(joystick,button)
  if button=='x' then ui.padBoost=false end
end
-- Generic USB/OTG controllers which do not expose the standard gamepad mapping.
function love.joystickpressed(joystick,button)
  if not ui.cfg.gamepadEnabled or joystick:isGamepad() then return end
  local bindings={[1]='cw',[2]='ccw',[4]='y',[7]='back',[8]='start'}
  local action=bindings[button]
  if action then dispatch(action) end
end
function love.joystickreleased(joystick,button)
  if button==3 then ui.padBoost=false end
end
local function screenTouch(x,y)
  local rx,ry=ui.renderer:point(x,y)
  if rx<0 or rx>640 or ry<0 or ry>440 then return nil end
  if ui.state=='mode' then
    if rx>50 and rx<590 and ry>103 and ry<355 then
      local m=clamp(math.floor((ry-111)/61)+1,1,4)
      ui.mode=m;dispatch('start')
    elseif ry>=367 and ry<399 then dispatch('versus')
    elseif ry>=399 then dispatch('options') end
  elseif ui.state=='options' then
    if ry>96 and ry<368 then
      local rows=ui.pages[ui.page]
      local first=math.max(1,math.min(ui.selected-3,math.max(1,#rows-7+1)))
      local idx=first+math.floor((ry-101)/37)
      if idx>=1 and idx<=#rows and idx<first+7 then
        ui.selected=idx
        if ui.pages[ui.page][idx].kind=='command' then actionPreset()
        else changeOption(rx<370 and -1 or 1) end
      end
    elseif ry<90 then changePage(rx<320 and -1 or 1)
    elseif ry>390 then dispatch(rx<320 and 'b' or 'start') end
  elseif ui.state=='play' then
    -- Gameplay touches are handled by touchStart, never as absolute board taps.
    if rx>594 and ry<40 then dispatch('y') end
  elseif ui.state=='scores' then
    if ry>380 then ui.state='options' else dispatch(rx<320 and 'left' or 'right') end
  elseif ui.state=='pause' or ui.state=='gameover' then
    if ry<290 then dispatch('start') else dispatch('back') end
  elseif ui.state=='help' then dispatch('b') end
  return nil
end
local dpad={
  {60,252,42,42,'up'},{18,294,42,42,'left'},
  {102,294,42,42,'right'},{60,336,42,42,'down'},
  {443,268,68,68,'ccw'},{518,268,68,68,'cw'},
  {443,359,143,57,'boost'}
}
local function touchStart(id,x,y)
  if ui.state~='play' then
    local rx,ry=ui.renderer:point(x,y)
    ui.touchFingers[id]={kind='menu',startX=rx,lastX=rx,startY=ry,lastY=ry,swiped=false}
    return
  end
  local rx,ry=ui.renderer:point(x,y)
  if rx<0 or rx>640 or ry<0 or ry>440 then return end
  if rx>=594 and ry<=40 then dispatch('y');return end
  if ui.cfg.touchMode==1 then
    for _,b in ipairs(dpad) do
      if rx>=b[1] and rx<b[1]+b[3] and ry>=b[2] and ry<b[2]+b[4] then
        if b[5]=='boost' then ui.touchFingers[id]={kind='boost'}
        elseif b[5]=='up' or b[5]=='down' or b[5]=='left' or b[5]=='right' then
          dispatch(b[5]);ui.touchFingers[id]={kind='direction',action=b[5],delay=.22}
        else dispatch(b[5]) end
        return
      end
    end
  else
    if rx>=438 and ry>=367 and ry<424 then
      ui.touchFingers[id]={kind='boost'}
    elseif rx<320 then
      ui.touchFingers[id]={kind='drag',lastX=rx,lastY=ry,accX=0,accY=0}
    else
      dispatch(ry<220 and 'cw' or 'ccw')
      ui.touchFingers[id]={kind='rotation'}
    end
  end
end
function love.touchpressed(id,x,y) touchStart(id,x,y) end
function love.touchmoved(id,x,y)
  local finger=ui.touchFingers[id]
  if not finger then return end
  local rx,ry=ui.renderer:point(x,y)
  if finger.kind=='menu' then
    if ui.state=='options' and math.abs(ry-finger.lastY)>=27 then
      local steps=math.floor(math.abs(ry-finger.lastY)/27)
      ui.selected=clamp(ui.selected+(ry<finger.lastY and steps or -steps),1,#ui.pages[ui.page])
      finger.lastY=ry;finger.swiped=true
    elseif math.abs(ry-finger.startY)>16 then finger.swiped=true end
    return
  end
  if finger.kind~='drag' or ui.state~='play' then return end
  finger.accX=finger.accX+rx-finger.lastX
  finger.accY=finger.accY+ry-finger.lastY
  finger.lastX=rx;finger.lastY=ry
  local step=22/(id=='mouse' and (ui.cfg.mouseSensitivity or 1) or ui.cfg.touchSensitivity)
  -- Every movement is relative, never teleport the cursor to the finger.
  for n=1,12 do
    local ax,ay=math.abs(finger.accX),math.abs(finger.accY)
    if math.max(ax,ay)<step then break end
    if ax>=ay then
      local dir=finger.accX>0 and 1 or -1
      dispatch(dir>0 and 'right' or 'left');finger.accX=finger.accX-dir*step
    else
      local dir=finger.accY>0 and 1 or -1
      dispatch(dir>0 and 'down' or 'up');finger.accY=finger.accY-dir*step
    end
  end
end
function love.touchreleased(id)
  local finger=ui.touchFingers[id]
  ui.touchFingers[id]=nil
  if finger and finger.kind=='menu' and not finger.swiped then
    local x=(finger.lastX or 0)*(ui.renderer.scale or 1)+(ui.renderer.ox or 0)
    local y=(finger.lastY or 0)*(ui.renderer.scale or 1)+(ui.renderer.oy or 0)
    screenTouch(x,y)
  end
end
local function setMouseCursor(x,y)
  if not ui.board or ui.state~='play' then return false end
  local rx,ry=ui.renderer:point(x,y)
  local tile=ui.vs and 12 or 15
  local bx=ui.vs and 198 or math.floor((640-ui.board.w*15)/2)
  local by=ui.vs and 68 or 45
  if rx<bx or rx>=bx+ui.board.w*tile or ry<by or ry>=by+ui.board.h*tile then return false end
  ui.board.cx=clamp(math.floor((rx-bx)/tile)+1,1,ui.board.w-1)
  ui.board.cy=clamp(math.floor((ry-by+ui.board.rise*tile)/tile)+1,1,ui.board.h-(ui.cfg.mode==3 and 0 or 1))
  return true
end
function love.mousepressed(x,y,button,istouch)
  if istouch then return end -- Prevent a single Android finger from generating two actions.
  if ui.state~='play' then screenTouch(x,y);return end
  if button==3 then ui.mouseBoost=true;return end
  if ui.cfg.mouseMode==0 then return end
  if ui.cfg.mouseMode==1 then
    if setMouseCursor(x,y) then dispatch(button==2 and 'ccw' or 'cw') end
  else
    if button==2 then dispatch('ccw');return end
    if button==1 then
      local rx,ry=ui.renderer:point(x,y)
      ui.mouseHeld=true;ui.mouseMoved=false;ui.mouseStartX=rx;ui.mouseStartY=ry
      ui.touchFingers.mouse={kind='drag',lastX=rx,lastY=ry,accX=0,accY=0}
    end
  end
end
function love.mousemoved(x,y,dx,dy,istouch)
  if istouch or ui.state~='play' then return end
  if ui.cfg.mouseMode==1 then setMouseCursor(x,y) end
  if ui.cfg.mouseMode==2 and ui.mouseHeld then
    local rx,ry=ui.renderer:point(x,y)
    if math.abs(rx-ui.mouseStartX)+math.abs(ry-ui.mouseStartY)>4 then ui.mouseMoved=true end
    love.touchmoved('mouse',x,y)
  end
end
function love.mousereleased(x,y,button,istouch)
  if istouch then return end
  if button==3 then ui.mouseBoost=false end
  if button==1 and ui.mouseHeld and not ui.mouseMoved and ui.state=='play' then dispatch('cw') end
  ui.mouseHeld=false;ui.touchFingers.mouse=nil
end
function love.wheelmoved(x,y)
  if ui.state=='options' and y~=0 then changePage(y<0 and 1 or -1) end
end
function love.quit() saveSettings() end