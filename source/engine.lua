local Engine={}
Engine.__index=Engine
local floor, min,max,random=math.floor,math.min,math.max,math.random
local dirs={{1,0},{-1,0},{0,1},{0,-1}}
local function clamp(x,a,b) return max(a,min(b,x)) end
local function empty(w,h,fill)
  local t={};if fill==nil then fill=0 end;for y=1,h do t[y]={};for x=1,w do t[y][x]=fill end end
  return t
end
local function id(x,y,w) return (y-1)*w+x end
local function pos(idx,w) return ((idx-1)%w)+1,floor((idx-1)/w)+1 end
local function copy(t)
  local o={};for i=1,#t do o[i]=t[i] end;return o
end
local default={mode=1,cols=10,rows=20,colours=5,startRows=6,minGroup=3,
  icons=false,linkResonance=true,gravity=true,riseSecs=15,sweepSecs=7.5,
  bombs=true,bomb3=.012,bomb5=.004,bomb7=.0015,beamH=.009,beamV=.009,
  painter=.003,shifter=.002,freezeRate=.01,freezeSecs=5.0,
  palette=1,hueDrift=true,bloom=true,adaptive=true,particles=true,
  sound=true,volume=.55,gameSpeed=1.0,bonusText=true,
  touchMode=2,touchSensitivity=1.0,glowPower=1.15,particlePower=1.0,juicePower=1.0,
  boostSpeed=4.7,boostReward=1.0,vsCPU=false,cpuSkill=.65,cpuSpeed=.85,
  garbagePower=1.0,garbageDelay=1.4,garbageBreak=true,comboVolume=1.0,
  shakePower=.45,visualPulse=1.0,randomRows=1.0,
  gamepadEnabled=true,gamepadDeadzone=.52,mouseMode=1,mouseSensitivity=1.0,
  keyboardEnabled=true,keyboardLayout=1,keyboardRepeat=true,
  surgeRate=.007,garbageSmallRate=.008,garbageMediumRate=.004,garbageLargeRate=.0015,
  garbageSmallCount=2,garbageMediumCount=4,garbageLargeCount=8,garbageChainMultiplier=1.0,
  selfGarbageRate=.003,selfGarbageCount=4,
  shineClearDelay=0,linkClearDelay=0,attackClearDelay=.15,bridgeClearDelay=0,
  shineChainWindow=17,linkChainWindow=19,attackChainWindow=4,bridgeChainWindow=22,
  shineRiseSecs=15,linkRiseSecs=15,attackRiseSecs=15,bridgeRiseSecs=15,
  shineSweepSecs=7.5,linkSweepSecs=7.5,bridgeSweepSecs=7.5,
  attackGravitySecs=.065,shineGravitySecs=.065,linkGravitySecs=.065,bridgeGravitySecs=.065,
  shineScorePower=1,linkScorePower=1,attackScorePower=1,bridgeScorePower=1,
  renderStyle=1,paletteSaturation=1,paletteBrightness=1,paletteHue=0,
  bloomIntensity=1,flashPower=1,trailPower=1,backgroundDetail=2,
  screenContrast=1,paletteCycleSecs=0,
  holdSlots=1,nextPreview=4,wallKicks=true,tSpins=true,infiniteSpin=false,
  lockDelay=.50,lockResetLimit=15,spinBonus=450,dropBonus=2,
  fallingGravity=.80,fallingClearDelay=.16,fallingMinGroup=4,
  fallingSweepSecs=8.0,tetrisClearDelay=.18,fallingScorePower=1.0,
  crashGemRate=.20,slideShape=3,slideMinGroup=3,slideDiagonal=false,
  labPieceShape=2,labClearRule=3,customBase=5,selectedMode=1,
  zoneEnabled=true,zoneDuration=9,zoneThreshold=.5,zoneChargeRate=.12,
  zoneStartCharge=0,zoneGravityScale=.6,fallingSpecials=true}
function Engine.defaults() local o={};for k,v in pairs(default) do o[k]=v end;return o end
function Engine.new(cfg)
  local b=setmetatable({},Engine);b.cfg=cfg or Engine.defaults();b:reset();return b
end
function Engine:reset()
  self.w=clamp(self.cfg.cols,8,18);self.h=20
  local w,h=self.w,self.h
  self.grid=empty(w,h);self.icon=empty(w,h);self.fx=empty(w,h)
  self.readyC=empty(w,h,false);self.readyI=empty(w,h,false)
  self.touched=empty(w,h,false);self.groups={};self.dirty=true
  self.score=0;self.cleared=0;self.chain=0;self.bestChain=0
  self.boostCharge=0;self.riskMultiplier=1;self.celebration=0
  self.pendingGarbage=0;self.penaltyGarbage=0;self.garbageWait=0;self.attackUnits=0
  self.totalAttacks=0;self.garbageReceived=0;self.latestClear=0
  self.sweeps=0;self.rowsRaised=0;self.lastScoreSweep=-9;self.gameover=false
  self.freeze=0;self.sweep=0;self.rise=0;self.gravityTimer=0;self.flash=0
  self.clearHold=0;self.attackClearTimer=0;self.lastScoreTime=-100
  self.cx=floor(w/2);self.cy=h-7;self.cascade=false;self.soundEvents={}
  self.popups={};self.particles={};self.shocks={};self.trails={};self.time=0
  self.incoming=nil;self.incomingIndex=1
  local waves=max(1,floor((self.cfg.startRows or 6)/2))
  for k=1,waves do
    local wave=self:generateWave()
    for dy=1,2 do
      for y=1,h-1 do
        self.grid[y]=self.grid[y+1];self.icon[y]=self.icon[y+1];self.fx[y]=self.fx[y+1]
      end
      self.grid[h]=copy(wave.c[dy]);self.icon[h]=copy(wave.i[dy]);self.fx[h]=copy(wave.f[dy])
    end
  end
  self.incoming=self:generateWave()
  self:detect()
end
function Engine:sound(kind) self.soundEvents[#self.soundEvents+1]=kind end
function Engine:popup(msg,x,y,r,g,b)
  if not self.cfg.bonusText then return end
  self.popups[#self.popups+1]={text=msg,x=x or self.w/2,y=y or self.h/2,life=1.45,maxLife=1.45,r=r or 1,g=g or 1,b=b or 1}
  if #self.popups>14 then table.remove(self.popups,1) end
end
function Engine:burst(x,y,colour,n)
  self.shocks[#self.shocks+1]={x=x,y=y,life=.38+.17*self.cfg.juicePower,size=0,colour=colour}
  if #self.shocks>18 then table.remove(self.shocks,1) end
  if not self.cfg.particles then return end
  for i=1,min(floor((n or 13)*self.cfg.particlePower+.5),floor(24*self.cfg.particlePower+8)) do
    local ang=random()*math.pi*2;local sp=(2+random()*5)
    self.particles[#self.particles+1]={x=x,y=y,vx=math.cos(ang)*sp,vy=math.sin(ang)*sp,life=.35+random()*.6,colour=colour}
  end
  while #self.particles>floor(120*self.cfg.particlePower+30) do table.remove(self.particles,1) end
end
function Engine:pickEffect()
  local r=random()
  if self.cfg.bombs then
    if r<self.cfg.bomb3 then return 1 end;r=r-self.cfg.bomb3
    if r<self.cfg.bomb5 then return 2 end;r=r-self.cfg.bomb5
    if r<self.cfg.bomb7 then return 3 end;r=r-self.cfg.bomb7
  end
  if r<(self.cfg.painter or 0) then return 4 end;r=r-(self.cfg.painter or 0)
  if r<(self.cfg.shifter or 0) then return 5 end;r=r-(self.cfg.shifter or 0)
  if r<(self.cfg.freezeRate or 0) then return 6 end;r=r-(self.cfg.freezeRate or 0)
  if r<(self.cfg.beamH or 0) then return 7 end;r=r-(self.cfg.beamH or 0)
  if r<(self.cfg.beamV or 0) then return 8 end;r=r-(self.cfg.beamV or 0)
  if r<(self.cfg.surgeRate or 0) then return 9 end;r=r-(self.cfg.surgeRate or 0)
  if r<(self.cfg.garbageSmallRate or 0) then return 10 end;r=r-(self.cfg.garbageSmallRate or 0)
  if r<(self.cfg.garbageMediumRate or 0) then return 11 end;r=r-(self.cfg.garbageMediumRate or 0)
  if r<(self.cfg.garbageLargeRate or 0) then return 12 end;r=r-(self.cfg.garbageLargeRate or 0)
  if r<(self.cfg.selfGarbageRate or 0) then return 13 end
  return 0
end
function Engine:generateWave()
  local w=self.w
  local best,bestCost=nil,math.huge
  -- Randomness is balanced against unsafe patterns; an entire 2-row wave never
  -- uses a single repeated AB checkerboard when 3+ colours are available.
  local lastPair=-1
  -- Searches for visually varied, low-conflict 2x2 waves.
  -- Passive group authorization is independently prohibited regardless of spawn topology.
  for trial=1,48 do
    local p={c=empty(w,2),i=empty(w,2),f=empty(w,2)}
    for x=1,w,2 do
      local a=1+floor(random()*self.cfg.colours)
      local b=1+floor(random()*(self.cfg.colours-1));if b>=a then b=b+1 end
      if self.cfg.colours>=3 and lastPair==a then a=a%self.cfg.colours+1 end
      lastPair=a
      local kind=1+floor(random()*6)
      if kind==1 or kind==2 then
        local aa,bb=kind==1 and a or b,kind==1 and b or a
        p.c[1][x]=aa;p.c[2][x]=aa;p.c[1][x+1]=bb;p.c[2][x+1]=bb
      elseif kind==3 or kind==4 then
        local aa,bb=kind==3 and a or b,kind==3 and b or a
        p.c[1][x]=aa;p.c[1][x+1]=aa;p.c[2][x]=bb;p.c[2][x+1]=bb
      else
        local aa,bb=kind==5 and a or b,kind==5 and b or a
        p.c[1][x]=aa;p.c[2][x+1]=aa;p.c[1][x+1]=bb;p.c[2][x]=bb
      end
      local e=self:pickEffect()
      if e>0 then p.f[1+floor(random()*2)][x+floor(random()*2)]=e end
    end
    for y=1,2 do for x=1,w do
      local above = y==1 and self.icon[self.h][x] or p.i[1][x]
      local left = x==1 and 0 or p.i[y][x-1]
      local r=1+floor(random()*3)
      for k=0,2 do
        local v=1+(r+k-1)%3
        if v~=above and v~=left then p.i[y][x]=v;break end
      end
    end end
    local cost=self:waveCost(p)
    local seen,counts={},{}
    for y=1,2 do for x=1,w do
      local c=p.c[y][x];seen[c]=true;counts[c]=(counts[c] or 0)+1
      if x>=4 and p.c[y][x]==p.c[y][x-2] and p.c[y][x-1]==p.c[y][x-3] then
        cost=cost+3*(self.cfg.randomRows or 1)
      end
      if self.grid[self.h][x]==c then cost=cost+.25*(self.cfg.randomRows or 1) end
    end end
    local countDistinct=0;local highest=0
    for _,cnt in pairs(counts) do countDistinct=countDistinct+1;highest=max(highest,cnt) end
    if self.cfg.colours>=4 then cost=cost+max(0,math.min(self.cfg.colours,5)-countDistinct)*6*(self.cfg.randomRows or 1) end
    cost=cost+max(0,highest-w*.75)*2*(self.cfg.randomRows or 1)
    if cost<bestCost or (cost==bestCost and random()<.22) then best,bestCost=p,cost end
    if bestCost==0 and trial>16 then break end
  end
  return best
end
function Engine:waveCost(p)
  local w=self.w
  local rows={self.grid[self.h],p.c[1],p.c[2]}
  local cost=0
  if self.cfg.mode==3 then
    for y=1,3 do for x=1,w-2 do
      if rows[y][x]~=0 and rows[y][x]==rows[y][x+1] and rows[y][x]==rows[y][x+2] and y>1 then cost=cost+2 end
    end end
    for y=1,1 do for x=1,w do if rows[y][x]~=0 and rows[y][x]==rows[y+1][x] and rows[y][x]==rows[y+2][x] then cost=cost+3 end end end
  elseif self.cfg.mode==1 then
    for y=1,2 do for x=1,w-1 do
      local c=rows[y][x]
      if c~=0 and c==rows[y][x+1] and c==rows[y+1][x] and c==rows[y+1][x+1] then cost=cost+3 end
    end end
  elseif self.cfg.mode==2 then
    for y=2,3 do for x=2,w do
      if rows[y][x]==rows[y][x-1] and rows[y][x]~=0 then cost=cost+1 end
      if rows[y][x]==rows[y-1][x] and rows[y][x]~=0 then cost=cost+1 end
    end end
  else
    -- Bridge penalty discourages horizontally contiguous paths.
    for y=2,3 do for x=2,w do if rows[y][x]==rows[y][x-1] then cost=cost+1 end end end
  end
  return cost
end
function Engine:raise()
  local w,h=self.w,self.h
  for x=1,w do if self.grid[1][x]~=0 then self.gameover=true;self:sound('lose');return end end
  for y=1,h-1 do
    self.grid[y]=self.grid[y+1];self.icon[y]=self.icon[y+1];self.fx[y]=self.fx[y+1]
    self.readyC[y]=self.readyC[y+1];self.readyI[y]=self.readyI[y+1]
  end
  local i=self.incomingIndex
  self.grid[h]=copy(self.incoming.c[i]);self.icon[h]=copy(self.incoming.i[i]);self.fx[h]=copy(self.incoming.f[i])
  self.readyC[h]={};self.readyI[h]={}
  for x=1,w do self.readyC[h][x]=false;self.readyI[h][x]=false end
  self.touched=empty(w,h,false)
  self.incomingIndex=i+1
  if self.incomingIndex==3 then self.incomingIndex=1;self.incoming=self:generateWave() end
  self.rowsRaised=self.rowsRaised+1;self.cy=max(1,self.cy-1)
  self.cascade=false;self.dirty=true;self:sound('rise')
end
function Engine:move(dx,dy)
  self.cx=clamp(self.cx+dx,1,self.w-1)
  self.cy=clamp(self.cy+dy,1,self.h-(self.cfg.mode==3 and 0 or 1))
end
function Engine:act(clockwise)
  if self.gameover then return end
  local x,y=self.cx,self.cy
  local positions={}
  if self.cfg.mode==3 then
    positions={{x,y},{x+1,y}}
    if self.grid[y][x]==self.grid[y][x+1] and self.icon[y][x]==self.icon[y][x+1] and self.fx[y][x]==self.fx[y][x+1] then return end
    for _,layer in ipairs({'grid','icon','fx','readyC','readyI'}) do
      local t=self[layer];t[y][x],t[y][x+1]=t[y][x+1],t[y][x]
    end
  else
    positions={{x,y},{x+1,y},{x+1,y+1},{x,y+1}}
    local src=clockwise and {4,1,2,3} or {2,3,4,1}
    for _,layer in ipairs({'grid','icon','fx','readyC','readyI'}) do
      local tab=self[layer];local old={}
      for j,p in ipairs(positions) do old[j]=tab[p[2]][p[1]] end
      for j,p in ipairs(positions) do tab[p[2]][p[1]]=old[src[j]] end
    end
  end
  for _,p in ipairs(positions) do self.touched[p[2]][p[1]]=true end
  self.dirty=true;self.cascade=false;self:sound('rotate')
  self:burst(x+1,y+.8,self.grid[y][x],6)
end
function Engine:components(out,eligible,dimension,minimum,bridge)
  local w,h=self.w,self.h;local visited=empty(w,h,false)
  local field=dimension==1 and self.grid or self.icon
  for y=1,h do for x=1,w do
    if eligible[y][x] and not visited[y][x] then
      local colour=field[y][x]
      local q={id(x,y,w)};local head=1
      local cells={};local bottom=0;local top=h+1;local left=false;local right=false
      visited[y][x]=true
      while head<=#q do
        local index=q[head];head=head+1
        local cx,cy=pos(index,w)
        cells[#cells+1]=index
        bottom=max(bottom,cy);top=min(top,cy)
        if cx==1 then left=true end;if cx==w then right=true end
        for _,d in ipairs(dirs) do
          local nx,ny=cx+d[1],cy+d[2]
          if nx>=1 and nx<=w and ny>=1 and ny<=h and eligible[ny][nx] and not visited[ny][nx] and field[ny][nx]==colour then
            visited[ny][nx]=true;q[#q+1]=id(nx,ny,w)
          end
        end
      end
      if #cells>=minimum and (not bridge or (left and right)) then
        out[#out+1]={cells=cells,dimension=dimension,colour=colour,top=top,bottom=bottom}
      end
    end
  end end
end
function Engine:collect(readyOnly)
  local w,h=self.w,self.h;local out={};local g=self.grid
  local mode=self.cfg.mode
  if mode==1 then
    local eligible=empty(w,h,false)
    for y=1,h-1 do for x=1,w-1 do
      local a=g[y][x]
      if a>0 and a==g[y+1][x] and a==g[y][x+1] and a==g[y+1][x+1] then
        if not readyOnly or (self.readyC[y][x] and self.readyC[y+1][x] and self.readyC[y][x+1] and self.readyC[y+1][x+1]) then
          eligible[y][x]=true;eligible[y+1][x]=true;eligible[y][x+1]=true;eligible[y+1][x+1]=true
        end
      end
    end end
    self:components(out,eligible,1,4,false)
  elseif mode==3 then
    local eligible=empty(w,h,false)
    for y=1,h do local x=1;while x<=w do
      local a=g[y][x];local e=x+1
      if a>0 then while e<=w and g[y][e]==a do e=e+1 end end
      if a>0 and e-x>=3 then
        local ok=true
        if readyOnly then for k=x,e-1 do if not self.readyC[y][k] then ok=false;break end end end
        if ok then for k=x,e-1 do eligible[y][k]=true end end
      end
      x=e
    end end
    for x=1,w do local y=1;while y<=h do
      local a=g[y][x];local e=y+1
      if a>0 then while e<=h and g[e][x]==a do e=e+1 end end
      if a>0 and e-y>=3 then
        local ok=true
        if readyOnly then for k=y,e-1 do if not self.readyC[k][x] then ok=false;break end end end
        if ok then for k=y,e-1 do eligible[k][x]=true end end
      end
      y=e
    end end
    self:components(out,eligible,1,3,false)
  else
    local eligible=empty(w,h,false)
    for y=1,h do for x=1,w do eligible[y][x]=g[y][x]>0 and (not readyOnly or self.readyC[y][x]) end end
    self:components(out,eligible,1,mode==4 and w or self.cfg.minGroup,mode==4)
    if mode==2 and self.cfg.icons then
      for y=1,h do for x=1,w do eligible[y][x]=g[y][x]>0 and self.icon[y][x]~=0 and (not readyOnly or self.readyI[y][x]) end end
      self:components(out,eligible,2,self.cfg.minGroup,false)
    end
  end
  return out
end
function Engine:detect()
  if not self.dirty then return end
  local potential=self:collect(false)
  for _,gr in ipairs(potential) do
    local authorised=false
    for _,index in ipairs(gr.cells) do
      local x,y=pos(index,self.w)
      if self.touched[y][x] then authorised=true;break end
    end
    if authorised then
      local ready=gr.dimension==1 and self.readyC or self.readyI
      for _,index in ipairs(gr.cells) do local x,y=pos(index,self.w);ready[y][x]=true end
    end
  end
  self.touched=empty(self.w,self.h,false)
  self.groups=self:collect(true)
  self.dirty=false
end
function Engine:clearGroups(active)
  if #active==0 then return end
  local w,h=self.w,self.h
  local selected={};for _,index in ipairs(active) do selected[index]=true end
  if self.cfg.mode==2 and self.cfg.icons and self.cfg.linkResonance then
    local changed=true
    while changed do
      changed=false;local union={}
      for i,g in ipairs(self.groups) do if selected[i] then for _,idx in ipairs(g.cells) do union[idx]=true end end end
      for i,g in ipairs(self.groups) do if not selected[i] then
        for _,idx in ipairs(g.cells) do if union[idx] then selected[i]=true;changed=true;break end end
      end end
    end
  end
  local remove={};local col={};local ico={};local queue={};local totalGroups=0;local growth=0;local biggest=0
  local garbageTouch={}
  local surgeCount,garbageSpecial,selfGarbage=0,0,0
  local garbageCleared=0
  local cx,cy,numCenters=0,0,0
  local function mark(x,y)
    if x<1 or x>w or y<1 or y>h then return end
    local idx=id(x,y,w)
    if self.grid[y][x]<=0 or remove[idx] then return end
    remove[idx]=true
    local effect=self.fx[y][x]
    if effect~=0 then queue[#queue+1]={x=x,y=y,kind=effect,colour=self.grid[y][x]} end
  end
  for i,g in ipairs(self.groups) do if selected[i] then
    totalGroups=totalGroups+1;biggest=max(biggest,#g.cells)
    local minsize=self.cfg.mode==1 and 4 or self.cfg.mode==3 and 3 or self.cfg.mode==4 and w or self.cfg.minGroup
    local extra=max(0,#g.cells-minsize)
    growth=growth+extra*extra*65
    local xsum,ysum=0,0
    for _,idx in ipairs(g.cells) do
      local x,y=pos(idx,w);xsum=xsum+x;ysum=ysum+y
      if g.dimension==1 then col[idx]=true else ico[idx]=true end
      mark(x,y)
    end
    local mx,my=xsum/#g.cells,ysum/#g.cells
    cx=cx+mx;cy=cy+my;numCenters=numCenters+1
    self:burst(mx,my,g.dimension==1 and g.colour or self.grid[g.bottom][clamp(floor(mx),1,w)],14+#g.cells)
    if extra>0 then self:popup('GROWTH +'..extra*extra*65,mx,my,1,.9,.6) end
  end end
  local effects=0;local bombs=0;local beams=0;local delayed={}
  while #queue>effects and effects<w*h do
    effects=effects+1;local e=queue[effects]
    if e.kind>=1 and e.kind<=3 then
      bombs=bombs+1
      for yy=e.y-e.kind,e.y+e.kind do for xx=e.x-e.kind,e.x+e.kind do mark(xx,yy) end end
      self:burst(e.x,e.y,e.colour,22);self:popup('BOMB CHAIN',e.x,e.y,1,.68,.5)
    elseif e.kind==7 or e.kind==8 then
      beams=beams+1
      if e.kind==7 then for xx=1,w do mark(xx,e.y) end else for yy=1,h do mark(e.x,yy) end end
      self.trails[#self.trails+1]={horizontal=e.kind==7,x=e.x,y=e.y,life=.6}
      self:popup(e.kind==7 and 'H BEAM' or 'V BEAM',e.x,e.y,.6,.94,1)
    else delayed[#delayed+1]=e end
  end
  local count=0;local dual=0
  if self.cfg.garbageBreak then
    for idx in pairs(remove) do
      local x,y=pos(idx,w)
      for _,d in ipairs(dirs) do
        local xx,yy=x+d[1],y+d[2]
        if xx>=1 and xx<=w and yy>=1 and yy<=h and self.grid[yy][xx]==-1 then
          garbageTouch[id(xx,yy,w)]=true
        end
      end
    end
  end
  -- Touching one part of a connected garbage formation clears the whole
  -- orthogonally connected mass. Bombs and beams are treated as ordinary clears
  -- for discovering adjacent garbage too.
  if self.cfg.garbageBreak then
    local pending={};local visited={};local head=1
    for idx in pairs(garbageTouch) do pending[#pending+1]=idx;visited[idx]=true end
    while head<=#pending do
      local idx=pending[head];head=head+1
      local x,y=pos(idx,w)
      if self.grid[y][x]==-1 then
        remove[idx]=true;garbageCleared=garbageCleared+1
        for _,d in ipairs(dirs) do
          local xx,yy=x+d[1],y+d[2]
          if xx>=1 and xx<=w and yy>=1 and yy<=h then
            local other=id(xx,yy,w)
            if not visited[other] and self.grid[yy][xx]==-1 then
              visited[other]=true;pending[#pending+1]=other
            end
          end
        end
      end
    end
  end
  for idx in pairs(remove) do
    local x,y=pos(idx,w)
    if col[idx] and ico[idx] then dual=dual+1 end
    if self.cfg.particles then
      for n=1,math.max(0,floor(2*self.cfg.particlePower+.5)) do
        local ang=random()*6.2832
        self.particles[#self.particles+1]={x=x,y=y,vx=math.cos(ang)*3,vy=math.sin(ang)*3,life=.45,colour=self.grid[y][x]}
      end
    end
    self.grid[y][x]=0;self.icon[y][x]=0;self.fx[y][x]=0
    self.readyC[y][x]=false;self.readyI[y][x]=false
    count=count+1
  end
  while #self.particles>floor(120*self.cfg.particlePower+30) do table.remove(self.particles,1) end
  if garbageCleared>0 then
    self:popup('GARBAGE SHATTER +'..garbageCleared*180,w/2,h/2,1,.76,.42)
    self:burst(w/2,h/2,1,8+garbageCleared*2)
    self:sound('garbage')
  end
  for _,e in ipairs(delayed) do
    if e.kind==9 then
      surgeCount=surgeCount+1
      self:popup('SURGE / FIELD UP +1',e.x,e.y,1,.55,.85)
    elseif e.kind>=10 and e.kind<=12 then
      local amount=e.kind==10 and self.cfg.garbageSmallCount or
        e.kind==11 and self.cfg.garbageMediumCount or self.cfg.garbageLargeCount
      garbageSpecial=garbageSpecial+max(1,floor(amount or 2))
      self:popup('GARBAGE DROP +'..amount,e.x,e.y,1,.65,.25)
    elseif e.kind==13 then
      selfGarbage=selfGarbage+max(1,floor(self.cfg.selfGarbageCount or 4))
      self:popup('CURSE! SELF GARBAGE +'..(self.cfg.selfGarbageCount or 4),e.x,e.y,1,.22,.26)
    elseif e.kind==6 then
      self.freeze=min(25,self.freeze+self.cfg.freezeSecs)
      self:popup('TIME FREEZE +'..self.cfg.freezeSecs..'S',e.x,e.y,.5,1,1)
    elseif e.kind==4 then
      for y=max(1,e.y-1),min(h,e.y+1) do for x=max(1,e.x-1),min(w,e.x+1) do
        if self.grid[y][x]>0 then self.grid[y][x]=e.colour;self.touched[y][x]=true end
      end end
    elseif e.kind==5 then
      local sx=clamp(e.x-1,1,w-2);local sy=clamp(e.y-1,1,h-2)
      for _,layer in ipairs({'grid','icon','fx','readyC','readyI'}) do
        local f=self[layer];local tmp={}
        for y=0,2 do tmp[y]={};for x=0,2 do tmp[y][x]=f[sy+y][sx+x] end end
        for y=0,2 do for x=0,2 do f[sy+x][sx+2-y]=tmp[y][x] end end
      end
      for y=sy,sy+2 do for x=sx,sx+2 do self.touched[y][x]=true end end
    end
  end
  local modeName=({'shine','link','attack','bridge'})[self.cfg.mode]
  local chainWindow=self.cfg[modeName..'ChainWindow'] or 12
  local continuing=self.chain>0 and (self.time-self.lastScoreTime)<=chainWindow
  self.chain=continuing and self.chain+1 or 1
  self.lastScoreTime=self.time
  self.lastScoreSweep=self.sweeps;self.bestChain=max(self.bestChain,self.chain)
  local mult=min(32,1+floor(1.7*self.chain^1.65))
  local risk=1+floor(min(4.5,self.boostCharge)*(self.cfg.boostReward or 1)*2+.01)/2
  self.riskMultiplier=risk
  local base=count*40+growth+dual*dual*240+max(0,totalGroups-1)*220+bombs*275+beams*1050+garbageCleared*180+surgeCount*350+garbageSpecial*95
  local score=floor(base*mult*risk*(self.cfg[modeName..'ScorePower'] or 1))
  self.score=self.score+score;self.cleared=self.cleared+count
  local attack=floor((count/4+max(0,self.chain-1)*1.8+dual*1.5+beams*2+bombs*.6)*(self.cfg.garbagePower or 1))
  local inflicted=min(80,max(1,attack)+floor(garbageSpecial*(self.cfg.garbageChainMultiplier or 1)))
  self.attackUnits=self.attackUnits+inflicted
  self.totalAttacks=self.totalAttacks+inflicted
  self.latestClear=count
  self.boostCharge=self.boostCharge*.45
  self.celebration=min(3.0,.6+self.chain*.22+dual*.15+count*.035)
  self.flash=min(1.4,(.22+count/28+dual*.075+beams*.16)*self.cfg.juicePower)
  self.cascade=true;self.dirty=true;self:detect()
  cx=cx/max(1,numCenters);cy=cy/max(1,numCenters)
  self:popup('+'..score..' / '..count..' CLEAR',cx,cy-1,1,1,1)
  if dual>0 then self:popup('DUAL RESONANCE x'..dual,cx,cy-2.7,1,.66,1) end
  if biggest>=7 then self:popup('MEGA GROUP '..biggest,cx,cy+1.6,1,.92,.55) end
  if self.chain>1 then self:popup('CHAIN x'..self.chain..'  SCORE x'..mult,cx,cy+3,.6,1,1) end
  if risk>1 then self:popup('BOOST RISK x'..string.format('%.1f',risk),cx,cy+4.1,1,.78,.38) end
  if dual>0 or self.chain>=4 or count>=18 then
    self:popup('HYPER RESONANCE',cx,cy-3.9,1,.52,.97)
  end
  self:sound((self.chain>=4 or dual>=3) and 'super' or self.chain>1 and 'chain' or beams>0 and 'beam' or bombs>0 and 'bomb' or dual>0 and 'dual' or 'clear')
  -- A solo garbage-drop block is a risk/reward hazard; in VS its units
  -- are routed to the opposing board by the exchange layer.
  -- Positive garbage specials attack the CPU only in versus mode.
  -- A curse ALWAYS lands on the current board, including solo mode, and
  -- cannot be cancelled by offensive clears.
  if selfGarbage>0 then self:queueGarbage(selfGarbage,true) end
  if selfGarbage>0 then self:sound('curse') end
  for n=1,min(3,surgeCount) do
    if not self.gameover then self:raise() end
  end
  if surgeCount>0 then self:sound('surge') end
  if garbageSpecial>0 then self:sound('garbage') end
  if self.chain>=2 then self:sound('combo'..min(8,self.chain)) end
end
function Engine:gravityStep()
  local w,h=self.w,self.h;local moved=false
  for y=h-1,1,-1 do for x=1,w do
    if self.grid[y][x]~=0 and self.grid[y+1][x]==0 then
      for _,layer in ipairs({'grid','icon','fx','readyC','readyI'}) do
        local tab=self[layer];tab[y+1][x],tab[y][x]=tab[y][x],(layer=='readyC' or layer=='readyI') and false or 0
      end
      if self.cascade then self.touched[y+1][x]=true end
      moved=true
    end
  end end
  if moved then self.dirty=true end
end
function Engine:update(dt,boost)
  if self.gameover then return end
  dt=min(.06,dt or 0);self.time=self.time+dt
  self.flash=max(0,self.flash-dt*2)
  self.celebration=max(0,self.celebration-dt)
  for i=#self.popups,1,-1 do local p=self.popups[i];p.life=p.life-dt;p.y=p.y-dt*.8;if p.life<=0 then table.remove(self.popups,i) end end
  for i=#self.shocks,1,-1 do local p=self.shocks[i];p.life=p.life-dt;p.size=p.size+dt*13;if p.life<=0 then table.remove(self.shocks,i) end end
  for i=#self.trails,1,-1 do local p=self.trails[i];p.life=p.life-dt;if p.life<=0 then table.remove(self.trails,i) end end
  for i=#self.particles,1,-1 do
    local p=self.particles[i];p.life=p.life-dt;p.x=p.x+p.vx*dt;p.y=p.y+p.vy*dt;p.vy=p.vy+5*dt
    if p.life<=0 then table.remove(self.particles,i) end
  end
  local modeName=({'shine','link','attack','bridge'})[self.cfg.mode]
  local risingOK=not (self.cfg.mode==3 and self.freeze>0)
  if risingOK then
    if boost then self.boostCharge=min(4.5,self.boostCharge+dt*.90)
    else self.boostCharge=max(0,self.boostCharge-dt*.24) end
    self.riskMultiplier=1+floor(self.boostCharge*(self.cfg.boostReward or 1)*2+.01)/2
    local riseDuration=self.cfg[modeName..'RiseSecs'] or self.cfg.riseSecs or 15
    local interval=max(.7,(riseDuration-self.rowsRaised*.028)*.5)
    self.rise=self.rise+dt/interval*(boost and (self.cfg.boostSpeed or 4.7) or 1)
    while self.rise>=1 and not self.gameover do self.rise=self.rise-1;self:raise() end
  end
  if self.cfg.gravity or self.cfg.mode==3 then
    self.gravityTimer=self.gravityTimer+dt
    local gStep=clamp(self.cfg[modeName..'GravitySecs'] or .065,.035,.5)
    while self.gravityTimer>gStep do self.gravityTimer=self.gravityTimer-gStep;self:gravityStep() end
  end
  if self.dirty then self:detect() end
  if self.cfg.mode==3 then
    if #self.groups>0 then
      self.attackClearTimer=self.attackClearTimer+dt
      if self.attackClearTimer>=(self.cfg.attackClearDelay or 0) then
        local active={};for i=1,#self.groups do active[#active+1]=i end
        self:clearGroups(active);self.attackClearTimer=0
      end
    else self.attackClearTimer=0 end
  else
    if self.freeze>0 then self.freeze=max(0,self.freeze-dt)
    elseif self.clearHold>0 then
      self.clearHold=max(0,self.clearHold-dt)
      if self.clearHold==0 then self:applySweep(self.sweep-.1,self.sweep+.1,true) end
    else
      local prev=self.sweep
      local sweepDuration=self.cfg[modeName..'SweepSecs'] or self.cfg.sweepSecs
      self.sweep=self.sweep+dt*self.h/max(1,sweepDuration)
      if self.sweep>=self.h then
        self:applySweep(prev,self.h);self.sweep=self.sweep-self.h;self.sweeps=self.sweeps+1
        if self.sweeps-self.lastScoreSweep>1 then self.chain=0 end
        self:applySweep(0,self.sweep)
      else self:applySweep(prev,self.sweep) end
    end
  end
  if self.cfg.mode==3 and self.freeze>0 then self.freeze=max(0,self.freeze-dt) end
  if self.pendingGarbage+self.penaltyGarbage>0 then
    self.garbageWait=self.garbageWait-dt
    if self.garbageWait<=0 then
      self:dropGarbage(min(3,self.pendingGarbage+self.penaltyGarbage))
      self.garbageWait=.22
    end
  end
end
function Engine:queueGarbage(units,mandatory)
  units=max(0,floor(units or 0))
  if units<=0 then return end
  if mandatory then self.penaltyGarbage=min(80,self.penaltyGarbage+units)
  else self.pendingGarbage=min(80,self.pendingGarbage+units) end
  self.garbageWait=max(self.garbageWait,self.cfg.garbageDelay or 1.4)
end
function Engine:dropGarbage(units)
  for n=1,units do
    if self.pendingGarbage+self.penaltyGarbage<=0 or self.gameover then break end
    local candidates={};local tallest=0
    for x=1,self.w do
      local top=self.h+1
      for y=1,self.h do if self.grid[y][x]~=0 then top=y;break end end
      if top>2 then
        candidates[#candidates+1]={x=x,y=top-1}
      else tallest=tallest+1 end
    end
    if #candidates==0 then self.gameover=true;self:sound('lose');break end
    local spot=candidates[random(#candidates)]
    self.grid[spot.y][spot.x]=-1
    self.icon[spot.y][spot.x]=0;self.fx[spot.y][spot.x]=0
    self.readyC[spot.y][spot.x]=false;self.readyI[spot.y][spot.x]=false
    if self.penaltyGarbage>0 then self.penaltyGarbage=self.penaltyGarbage-1
    else self.pendingGarbage=self.pendingGarbage-1 end
    self.garbageReceived=self.garbageReceived+1
    self.dirty=true
  end
end
function Engine:drainAttack()
  local units=self.attackUnits or 0;self.attackUnits=0;return units
end
function Engine:applySweep(a,b,forced)
  local active={}
  for i,g in ipairs(self.groups) do
    local boundary=g.bottom-self.rise
    if a<=boundary and b>=boundary then active[#active+1]=i end
  end
  if #active>0 then
    local nm=({'shine','link','attack','bridge'})[self.cfg.mode]
    local delay=self.cfg[nm..'ClearDelay'] or 0
    if delay>0 and not forced then
      self.clearHold=delay
      self.sweep=clamp(b,0,self.h)
      self:popup('SWEEP HOLD '..string.format('%.1f',delay)..'S',self.w/2,self.sweep,1,.9,.54)
    else self:clearGroups(active) end
  end
end
return Engine