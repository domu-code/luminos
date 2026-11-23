-- LUMINE ATTACK ARCADE LAB. Shared falling-piece engine for modes 5-11.
-- All co-ordinates use (x,y) with y increasing DOWN. Board cells use 1-based indices.
local Base=require('engine')
local F={};F.__index=F
F.sound=Base.sound;F.popup=Base.popup;F.burst=Base.burst
local floor,min,max,random=math.floor,math.min,math.max,math.random
local function clamp(n,a,b) return max(a,min(b,n)) end
local function mat(w,h,v)
  local z={};for y=1,h do z[y]={};for x=1,w do z[y][x]=v or 0 end end;return z
end
local dir={{1,0},{0,1},{-1,0},{0,-1}}
local function encode(x,y,w) return (y-1)*w+x end
local function decode(i,w) return (i-1)%w+1,floor((i-1)/w)+1 end
local kinds={'I','J','L','O','S','T','Z'}
local patterns={
 I={{0,1},{1,1},{2,1},{3,1}},
 J={{0,0},{0,1},{1,1},{2,1}},
 L={{2,0},{0,1},{1,1},{2,1}},
 O={{1,0},{2,0},{1,1},{2,1}},
 S={{1,0},{2,0},{0,1},{1,1}},
 T={{1,0},{0,1},{1,1},{2,1}},
 Z={{0,0},{1,0},{1,1},{2,1}}
}
-- SRS 0,R,2,L wall-kicks, transformed from +Y up to +Y down.
local normalKicks={
 ['0>1']={{0,0},{-1,0},{-1,-1},{0,2},{-1,2}},
 ['1>0']={{0,0},{1,0},{1,1},{0,-2},{1,-2}},
 ['1>2']={{0,0},{1,0},{1,1},{0,-2},{1,-2}},
 ['2>1']={{0,0},{-1,0},{-1,-1},{0,2},{-1,2}},
 ['2>3']={{0,0},{1,0},{1,-1},{0,2},{1,2}},
 ['3>2']={{0,0},{-1,0},{-1,1},{0,-2},{-1,-2}},
 ['3>0']={{0,0},{-1,0},{-1,1},{0,-2},{-1,-2}},
 ['0>3']={{0,0},{1,0},{1,-1},{0,2},{1,2}}
}
local iKicks={
 ['0>1']={{0,0},{-2,0},{1,0},{-2,1},{1,-2}},
 ['1>0']={{0,0},{2,0},{-1,0},{2,-1},{-1,2}},
 ['1>2']={{0,0},{-1,0},{2,0},{-1,-2},{2,1}},
 ['2>1']={{0,0},{1,0},{-2,0},{1,2},{-2,-1}},
 ['2>3']={{0,0},{2,0},{-1,0},{2,-1},{-1,2}},
 ['3>2']={{0,0},{-2,0},{1,0},{-2,1},{1,-2}},
 ['3>0']={{0,0},{1,0},{-2,0},{1,2},{-2,-1}},
 ['0>3']={{0,0},{-1,0},{2,0},{-1,-2},{2,1}}
}
local function isTetrisMode(mode) return mode==5 or mode==6 end
local function kindFor(cfg)
  if cfg.mode==5 or cfg.mode==6 then return 1 end
  if cfg.mode==10 then return cfg.slideShape or 2 end
  if cfg.mode==11 then return cfg.labPieceShape or 2 end
  if cfg.mode==12 then return 2 end
  return 2
end
local function ruleFor(cfg)
  if cfg.mode==5 then return 1 end -- line
  if cfg.mode==6 then return 2 end -- scanning line
  if cfg.mode==7 then return 3 end -- puyo 4+
  if cfg.mode==8 then return 4 end -- crash gem
  if cfg.mode==9 then return 5 end -- animal-food
  if cfg.mode==10 then return 6 end -- sliding-cluster
  if cfg.mode==12 then return 3 end -- Zone Garden colour pairs
  return cfg.labClearRule or 3
end
function F:rule() return ruleFor(self.cfg) end
function F:isLines() return self:rule()<=2 end
function F.new(cfg)
  local self=setmetatable({cfg=cfg},F)
  self:reset()
  return self
end
function F:reset()
  self.isFalling=true;self.w=clamp(floor(self.cfg.cols or 10),8,18);self.h=20
  self.grid=mat(self.w,self.h);self.icon=mat(self.w,self.h);self.fx=mat(self.w,self.h)
  self.readyC=mat(self.w,self.h,false);self.readyI=mat(self.w,self.h,false)
  self.groups={};self.particles={};self.popups={};self.shocks={};self.trails={};self.soundEvents={}
  self.time=0;self.rise=0;self.sweep=0;self.rowsRaised=0;self.sweeps=0
  self.chain=0;self.bestChain=0;self.score=0;self.cleared=0;self.lines=0;self.lastScoreTime=-100
  self.boostCharge=0;self.riskMultiplier=1;self.celebration=0;self.flash=0
  self.attackUnits=0;self.totalAttacks=0;self.garbageReceived=0
  self.pendingGarbage=0;self.penaltyGarbage=0;self.garbageWait=0
  self.gameover=false;self.freeze=0;self.lastSpin='';self.lastClear=0
  self.fallTimer=0;self.lockTimer=0;self.lockResets=0;self.clearTimer=0;self.pendingCells=nil
  self.zoneCharge=clamp(self.cfg.zoneStartCharge or 0,0,1);self.zoneActive=false
  self.zoneTime=0;self.zoneRows=0;self.zoneDeferred={};self.zoneDeferredCount=0
  self.combo=0;self.lastLockTime=-100;self.holdSlots={};self.holdSelected=1;self.holdUsed=false
  self.bag={};self.nextQueue={};self.active=nil;self.cx=1;self.cy=1
  self.incoming=nil;self.incomingIndex=1
  for i=1,8 do self.nextQueue[#self.nextQueue+1]=self:randomPiece() end
  self:spawn()
end
function F:pickColour() return 1+floor(random()*clamp(self.cfg.colours or 5,2,10)) end
function F:refillBag()
  self.bag={1,2,3,4,5,6,7}
  for i=#self.bag,2,-1 do local j=random(i);self.bag[i],self.bag[j]=self.bag[j],self.bag[i] end
end
function F:randomPiece()
  local shape=kindFor(self.cfg)
  local p={shape=shape,dir=0,x=0,y=0,blocks={},lastRotation=false}
  if shape==1 then
    if #self.bag==0 then self:refillBag() end
    p.kind=table.remove(self.bag)
    for i=1,4 do
      p.blocks[i]={c=1+(p.kind-1)%(self.cfg.colours or 5),fx=(self.cfg.fallingSpecials and random()<.03 and Base.pickEffect and Base.pickEffect(self)) or 0}
    end
  else
    local count=shape==3 and 3 or 2
    for i=1,count do
      local colour=self:pickColour()
      local fx=0
      if self:rule()==4 and random()<(self.cfg.crashGemRate or .2) then fx=20
      elseif self:rule()==5 then fx=random()<.5 and 21 or 0
      elseif self.cfg.fallingSpecials and random()<.075 and Base.pickEffect then fx=Base.pickEffect(self) end
      p.blocks[i]={c=colour,fx=fx}
    end
  end
  return p
end
function F:cells(p,orientation,px,py)
  orientation=orientation==nil and p.dir or orientation
  px=px or p.x;py=py or p.y
  local out={}
  if p.shape==1 then
    local name=kinds[p.kind];local initial=patterns[name]
    for i,off in ipairs(initial) do
      local x,y=off[1],off[2]
      if name~='O' then
        for j=1,orientation do
          if name=='I' then x,y=3-y,x else x,y=2-y,x end
        end
      end
      out[i]={px+x,py+y,p.blocks[i].c,p.blocks[i].fx}
    end
  else
    -- First block is the pivot; pairs and triads rotate as a rigid figure.
    local offsets=p.shape==3 and {{0,0},{0,1},{1,1}} or {{0,0},{0,1}}
    for i,off in ipairs(offsets) do
      local x,y=off[1],off[2]
      for j=1,orientation do x,y=-y,x end
      out[i]={px+x,py+y,p.blocks[i].c,p.blocks[i].fx}
    end
  end
  return out
end
function F:valid(p,rot,x,y)
  for _,b in ipairs(self:cells(p,rot,x,y)) do
    local bx,by=b[1],b[2]
    if bx<1 or bx>self.w or by>self.h or (by>=1 and self.grid[by][bx]~=0) then return false end
  end
  return true
end
function F:spawn(keepHold)
  if #self.nextQueue==0 then self.nextQueue[1]=self:randomPiece() end
  local p=table.remove(self.nextQueue,1)
  self.nextQueue[#self.nextQueue+1]=self:randomPiece()
  p.dir=0;p.x=floor(self.w/2)-(p.shape==1 and 1 or 0);p.y=p.shape==1 and 0 or 1
  p.lastRotation=false;self.active=p;self.cx=p.x;self.cy=p.y
  self.lockTimer=0;self.lockResets=0;self.fallTimer=0
  if not keepHold then self.holdUsed=false end
  if not self:valid(p,p.dir,p.x,p.y) then
    self.gameover=true;self:sound('lose')
  end
end
function F:spawnHeld(p)
  p.dir=0;p.x=floor(self.w/2)-(p.shape==1 and 1 or 0);p.y=p.shape==1 and 0 or 1
  p.lastRotation=false;self.active=p;self.lockTimer=0;self.lockResets=0;self.fallTimer=0
  if not self:valid(p,p.dir,p.x,p.y) then self.gameover=true;self:sound('lose') end
end
function F:hold()
  if not self.active or self.holdUsed or self.gameover or self.clearTimer>0 then return false end
  local n=clamp(floor(self.cfg.holdSlots or 1),0,3)
  if n==0 then return false end
  local old=self.active
  if #self.holdSlots<n then
    self.holdSlots[#self.holdSlots+1]=old
    self.holdSelected=#self.holdSlots
    self:spawn(true)
  else
    self.holdSelected=clamp(self.holdSelected,1,n)
    local replacement=self.holdSlots[self.holdSelected]
    self.holdSlots[self.holdSelected]=old
    self:spawnHeld(replacement)
  end
  self.holdUsed=true;self:sound('rotate');return true
end
function F:selectHold(dir)
  if #self.holdSlots==0 then return end
  self.holdSelected=(self.holdSelected-1+(dir or 1))%#self.holdSlots+1
end
function F:onGround() return self.active and not self:valid(self.active,self.active.dir,self.active.x,self.active.y+1) end
function F:resetLock(isRotation)
  if not self:onGround() then self.lockTimer=0;return end
  local unlimited=isRotation and self.cfg.infiniteSpin
  if unlimited or self.lockResets<clamp(self.cfg.lockResetLimit or 15,0,99) then
    self.lockTimer=0
    if not unlimited then self.lockResets=self.lockResets+1 end
  end
end
function F:move(dx,dy)
  local p=self.active
  if not p or self.gameover or self.clearTimer>0 then return false end
  if self:valid(p,p.dir,p.x+dx,p.y+dy) then
    p.x=p.x+dx;p.y=p.y+dy
    if dx~=0 then p.lastRotation=false;self:resetLock(false) end
    if dy>0 then self.lockTimer=0 end
    self.cx=p.x;self.cy=p.y
    return true
  end
  return false
end
function F:rotate(clockwise)
  local p=self.active
  if not p or self.gameover or self.clearTimer>0 then return false end
  local ori=(p.dir+(clockwise and 1 or 3))%4
  local kicks={{0,0}}
  if self.cfg.wallKicks then
    if p.shape==1 then
      kicks=(p.kind==1 and iKicks or normalKicks)[tostring(p.dir)..'>'..ori] or kicks
    else kicks={{0,0},{-1,0},{1,0},{0,-1},{-2,0},{2,0}} end
  end
  for _,k in ipairs(kicks) do
    if self:valid(p,ori,p.x+k[1],p.y+k[2]) then
      p.x=p.x+k[1];p.y=p.y+k[2];p.dir=ori;p.lastRotation=true
      self:resetLock(true);self.cx=p.x;self.cy=p.y
      self:sound('rotate');return true
    end
  end
  return false
end
function F:act(clockwise) return self:rotate(clockwise) end
function F:hardDrop()
  if not self.active or self.clearTimer>0 then return false end
  local count=0
  while self:move(0,1) and count<self.h do count=count+1 end
  self.score=self.score+count*(self.cfg.dropBonus or 2)
  if count>0 then self.active.lastRotation=false end
  self:lock()
  return true
end
function F:slide(dx)
  if self.cfg.mode~=10 and self.cfg.mode~=11 then return false end
  if not self.active then return false end
  local count=0
  while self:move(dx,0) and count<self.w do count=count+1 end
  return count>0
end
function F:cycleColours()
  if not self.active or self.active.shape==1 then return false end
  local p=self.active;local temp=p.blocks[#p.blocks]
  for i=#p.blocks,2,-1 do p.blocks[i]=p.blocks[i-1] end
  p.blocks[1]=temp;self:sound('rotate');return true
end
function F:ghostCells()
  if not self.active then return {} end
  local y=self.active.y
  while self:valid(self.active,self.active.dir,self.active.x,y+1) do y=y+1 end
  return self:cells(self.active,self.active.dir,self.active.x,y)
end
function F:spinType(p)
  if not self.cfg.tSpins or p.shape~=1 or p.kind~=6 or not p.lastRotation then return '' end
  local cx,cy=p.x+1,p.y+1;local occupied=0
  for _,d in ipairs({{-1,-1},{1,-1},{-1,1},{1,1}}) do
    local x,y=cx+d[1],cy+d[2]
    if x<1 or x>self.w or y>self.h or (y>=1 and self.grid[y][x]~=0) then occupied=occupied+1 end
  end
  return occupied>=3 and 'T-SPIN' or ''
end
function F:lock()
  local p=self.active
  if not p or self.gameover then return end
  local spin=self:spinType(p)
  for _,b in ipairs(self:cells(p)) do
    local x,y=b[1],b[2]
    if y<1 then self.gameover=true;self:sound('lose');return end
    if self.grid[y][x]~=0 then self.gameover=true;self:sound('lose');return end
    self.grid[y][x]=b[3];self.fx[y][x]=b[4]
  end
  self.active=nil;self.lastSpin=spin
  if self:isLines() then self:processLines(spin)
  else self:processClusters() end
  if not self.gameover and self.clearTimer<=0 and not self.cascadePending then self:spawn() end
end
function F:fullRows()
  local rows={}
  for y=1,self.h-self.zoneRows do
    local full=true
    for x=1,self.w do if self.grid[y][x]==0 then full=false;break end end
    if full then rows[#rows+1]=y end
  end
  return rows
end
function F:removeRows(rows)
  if #rows==0 then return end
  local marked={};for _,y in ipairs(rows) do marked[y]=true end
  for _,layer in ipairs({'grid','icon','fx'}) do
    local old=self[layer];local new=mat(self.w,self.h)
    local dst=self.h
    for y=self.h,1,-1 do if not marked[y] then
      new[dst]=old[y];dst=dst-1
    end end
    self[layer]=new
  end
end
function F:sealRows(rows)
  if #rows==0 then return end
  local marked={};for _,y in ipairs(rows) do marked[y]=true end
  local n=#rows
  for _,layer in ipairs({'grid','icon','fx'}) do
    local old=self[layer];local new=mat(self.w,self.h)
    local dst=self.h-n
    for y=self.h,1,-1 do if not marked[y] then
      new[dst]=old[y];dst=dst-1
    end end
    for y=self.h-n+1,self.h do for x=1,self.w do
      local src=rows[y-(self.h-n)]
      new[y][x]=old[src][x]
    end end
    self[layer]=new
  end
  self.zoneRows=self.zoneRows+n
  self:popup('STORED '..self.zoneRows..' LINES',self.w/2,9,.8,.99,1)
  if self.zoneRows>=self.h-2 then self:releaseSealed('MAX ZONE') end
end
function F:processLines(spin)
  local rows=self:fullRows()
  if #rows==0 then
    if spin~='' then self:popup('T-SPIN',self.w/2,6,1,.82,.5);self.score=self.score+max(50,self.cfg.spinBonus or 400) end
    self.combo=0;return
  end
  if self.zoneActive or self:rule()==2 then
    self:sealRows(rows)
    self.lastSpin=spin
  elseif (self.cfg.tetrisClearDelay or 0)>0 then
    self.pendingCells={kind='lines',rows=rows,spin=spin}
    self.clearTimer=self.cfg.tetrisClearDelay
    self:popup('LOCKED LINES '..#rows,self.w/2,8,.7,1,1)
  else
    self:clearRowsNow(rows,spin,0)
  end
end
function F:clearRowsNow(rows,spin,zoneBonus)
  local cells={}
  for _,y in ipairs(rows) do for x=1,self.w do cells[encode(x,y,self.w)]=true end end
  self:clearCells(cells,#rows,spin,zoneBonus or 0)
end
function F:releaseSealed(reason)
  local n=self.zoneRows
  if n<=0 then return end
  local rows={};for y=self.h-n+1,self.h do rows[#rows+1]=y end
  self.zoneRows=0
  self:clearRowsNow(rows,self.lastSpin,n>4 and n or 0)
  self:popup((reason or 'SWEEP')..' '..n..' LINES',self.w/2,self.h/2,1,.8,1)
  self:burst(self.w/2,self.h/2,2,15+n*2)
  self.lastSpin=''
end
function F:collectClusters()
  local w,h=self.w,self.h;local seen=mat(w,h,false);local all={}
  local rule=self:rule();local minimum=(rule==6 or rule==7) and (self.cfg.slideMinGroup or 3) or (self.cfg.fallingMinGroup or 4)
  for y=1,h do for x=1,w do
    local v=self.grid[y][x];local symbol=self.fx[y][x]
    if v>0 and not seen[y][x] and not (rule==5 and symbol==21) then
      seen[y][x]=true
      local q={{x,y}};local head=1;local cells={};local crash=false;local animals={}
      while head<=#q do
        local p=q[head];head=head+1
        local ax,ay=p[1],p[2]
        cells[#cells+1]=encode(ax,ay,w)
        if self.fx[ay][ax]==20 then crash=true end
        for _,d in ipairs(dir) do
          local nx,ny=ax+d[1],ay+d[2]
          if nx>=1 and nx<=w and ny>=1 and ny<=h then
            if not seen[ny][nx] and self.grid[ny][nx]==v and (rule~=5 or self.fx[ny][nx]~=21) then
              seen[ny][nx]=true;q[#q+1]={nx,ny}
            end
            if rule==5 and self.grid[ny][nx]==v and self.fx[ny][nx]==21 then
              animals[encode(nx,ny,w)]=true
            end
          end
        end
      end
      local match=false
      if rule==4 then match=crash
      elseif rule==5 then
        -- The food component must touch at least one corresponding animal.
        if symbol==21 then match=false else match=next(animals)~=nil end
      else match=#cells>=minimum end
      if match then
        if rule==5 then for i in pairs(animals) do cells[#cells+1]=i end end
        all[#all+1]={cells=cells,colour=v,dimension=1,top=y,bottom=y}
      end
    end
  end end
  if rule==6 and self.cfg.slideDiagonal then
    -- Diagonal extension of an already qualified orthogonal component.
    -- Optional 8-way matching is processed separately for full consistency.
    all={};seen=mat(w,h,false)
    for y=1,h do for x=1,w do
      if self.grid[y][x]>0 and not seen[y][x] then
        local col=self.grid[y][x];local q={{x,y}};local head=1;local cells={}
        seen[y][x]=true
        while head<=#q do
          local p=q[head];head=head+1;cells[#cells+1]=encode(p[1],p[2],w)
          for dx=-1,1 do for dy=-1,1 do
            local xx,yy=p[1]+dx,p[2]+dy
            if (dx~=0 or dy~=0) and xx>=1 and xx<=w and yy>=1 and yy<=h and
               not seen[yy][xx] and self.grid[yy][xx]==col then
              seen[yy][xx]=true;q[#q+1]={xx,yy}
            end
          end end
        end
        if #cells>=minimum then all[#all+1]={cells=cells,colour=col,dimension=1,top=y,bottom=y} end
      end
    end end
  end
  return all
end
function F:processClusters()
  local matches=self:collectClusters()
  self.groups=matches
  if #matches==0 then self.combo=0;return end
  if self.zoneActive then
    for _,group in ipairs(matches) do
      for _,idx in ipairs(group.cells) do self.zoneDeferred[idx]=true end
    end
    self.zoneDeferredCount=0;for _ in pairs(self.zoneDeferred) do self.zoneDeferredCount=self.zoneDeferredCount+1 end
    return
  end
  local cells={};for _,gr in ipairs(matches) do for _,idx in ipairs(gr.cells) do cells[idx]=true end end
  if (self.cfg.fallingClearDelay or 0)>0 then
    self.pendingCells={kind='cells',cells=cells};self.clearTimer=self.cfg.fallingClearDelay
  else self:clearCells(cells) end
end
function F:applyGravity()
  for x=1,self.w do
    local bottom=self.h
    for y=self.h,1,-1 do if self.grid[y][x]~=0 then
      for _,field in ipairs({'grid','fx','icon'}) do
        self[field][bottom][x]=self[field][y][x]
        if bottom~=y then self[field][y][x]=0 end
      end
      bottom=bottom-1
    end end
  end
end
function F:clearCells(mask,lines,spin,zoneBonus)
  local queue={};local count=0;local touched={}
  for idx in pairs(mask) do touched[idx]=true end
  local function add(x,y)
    if x<1 or x>self.w or y<1 or y>self.h then return end
    local idx=encode(x,y,self.w)
    if self.grid[y][x]~=0 and not touched[idx] then touched[idx]=true end
  end
  for idx in pairs(touched) do
    local x,y=decode(idx,self.w)
    if self.fx[y][x]>0 and self.fx[y][x]<20 then queue[#queue+1]={x=x,y=y,fx=self.fx[y][x]} end
  end
  local processed=0;local surge=0;local punishment=0;local attack=0;local beamCount=0
  while processed<#queue and processed<self.w*self.h do
    processed=processed+1
    local p=queue[processed];local fx=p.fx
    if fx<=3 then
      for yy=p.y-fx,p.y+fx do for xx=p.x-fx,p.x+fx do add(xx,yy) end end
    elseif fx==7 or fx==8 then
      beamCount=beamCount+1
      if fx==7 then for xx=1,self.w do add(xx,p.y) end
      else for yy=1,self.h do add(p.x,yy) end end
      self.trails[#self.trails+1]={horizontal=fx==7,x=p.x,y=p.y,life=.6}
    elseif fx==9 then surge=surge+1
    elseif fx>=10 and fx<=12 then
      attack=attack+(fx==10 and self.cfg.garbageSmallCount or fx==11 and self.cfg.garbageMediumCount or self.cfg.garbageLargeCount)
    elseif fx==13 then punishment=punishment+(self.cfg.selfGarbageCount or 4)
    elseif fx==6 then self.freeze=self.freeze+(self.cfg.freezeSecs or 5)
    end
    for idx in pairs(touched) do
      if not mask[idx] then
        mask[idx]=true
        local x,y=decode(idx,self.w)
        if self.fx[y][x]>0 and self.fx[y][x]<20 then queue[#queue+1]={x=x,y=y,fx=self.fx[y][x]} end
      end
    end
  end
  -- Garbage is broken as a full connected orthogonal mass when touched.
  local q={};local head=1
  for idx in pairs(touched) do
    local x,y=decode(idx,self.w)
    for _,d in ipairs(dir) do
      local nx,ny=x+d[1],y+d[2]
      if nx>=1 and nx<=self.w and ny>=1 and ny<=self.h and self.grid[ny][nx]==-1 then
        local ni=encode(nx,ny,self.w)
        if not touched[ni] then touched[ni]=true;q[#q+1]={nx,ny} end
      end
    end
  end
  while head<=#q do
    local p=q[head];head=head+1
    for _,d in ipairs(dir) do
      local nx,ny=p[1]+d[1],p[2]+d[2]
      if nx>=1 and nx<=self.w and ny>=1 and ny<=self.h and self.grid[ny][nx]==-1 then
        local ni=encode(nx,ny,self.w)
        if not touched[ni] then touched[ni]=true;q[#q+1]={nx,ny} end
      end
    end
  end
  for idx in pairs(touched) do
    local x,y=decode(idx,self.w)
    if self.grid[y][x]~=0 then
      count=count+1
      self.grid[y][x]=0;self.fx[y][x]=0;self.icon[y][x]=0
      if count%4==0 then self:burst(x,y,1,7) end
    end
  end
  self:applyGravity();self.groups={}
  self:awardClear(count,lines or 0,spin or '',zoneBonus or 0,beamCount)
  if punishment>0 then self:queueGarbage(punishment,true);self:popup('CURSE '..punishment,self.w/2,10,1,.5,.52) end
  self.attackUnits=self.attackUnits+floor(attack*(self.cfg.garbageChainMultiplier or 1))
  if surge>0 then
    for i=1,min(surge,3) do self:surge() end
  end
  -- Gravity cascades are processed on later updates so each chain link is visible.
  self.cascadePending=not self:isLines()
end
function F:surge()
  for x=1,self.w do if self.grid[1][x]~=0 then self.gameover=true;self:sound('lose');return end end
  for y=1,self.h-1 do
    self.grid[y]=self.grid[y+1];self.fx[y]=self.fx[y+1];self.icon[y]=self.icon[y+1]
  end
  self.grid[self.h]={};self.fx[self.h]={};self.icon[self.h]={}
  for x=1,self.w do self.grid[self.h][x]=0;self.fx[self.h][x]=0;self.icon[self.h][x]=0 end
  self.rowsRaised=self.rowsRaised+1
end
function F:awardClear(blocks,lines,spin,zoneBonus,beams)
  blocks=blocks or 0;lines=lines or 0
  if blocks<=0 then return end
  self.combo=self.combo+1;self.chain=self.chain+1
  self.bestChain=max(self.bestChain,self.chain)
  self.lastScoreTime=self.time
  local base=blocks*35+lines*lines*180+(beams or 0)*650
  if spin and spin~='' then base=base+(self.cfg.spinBonus or 400)*(lines+1) end
  if zoneBonus and zoneBonus>0 then base=base+zoneBonus*zoneBonus*220 end
  local risk=self.riskMultiplier or 1
  local total=floor(base*(1+self.combo*.38)*(1+max(0,self.chain-1)*.5)*risk*(self.cfg.fallingScorePower or 1))
  self.score=self.score+total;self.cleared=self.cleared+blocks;self.lines=self.lines+lines
  self.attackUnits=self.attackUnits+max(0,floor((lines*2+blocks/5+self.combo-1)*(self.cfg.garbagePower or 1)))
  self.totalAttacks=self.totalAttacks+max(0,floor((lines*2+blocks/5+self.combo-1)*(self.cfg.garbagePower or 1)))
  self.zoneCharge=clamp(self.zoneCharge+(lines>0 and lines or blocks/8)*(self.cfg.zoneChargeRate or .12),0,1)
  self.flash=clamp(.3+blocks*.03,0,1.6);self.celebration=clamp(.5+self.combo*.14+blocks*.017,0,3)
  self:popup('+'..total..'  '..(lines>0 and lines..' LINE' or blocks..' CLEAR'),self.w/2,5,1,1,.8)
  if lines>4 then self:popup('ULTRA '..lines..' LINES',self.w/2,9,1,.67,1) end
  if spin and spin~='' then self:popup('T-SPIN BONUS',self.w/2,11,1,.8,.6) end
  if self.combo>=2 then self:popup('CASCADE '..self.combo..'  X'..(1+self.combo),self.w/2,15,.6,1,1) end
  self:burst(self.w/2,9,1,min(35,blocks*2))
  self:sound((blocks>14 or self.combo>=4) and 'super' or self.combo>=2 and 'chain' or 'clear')
end
function F:activateZone()
  if not self.cfg.zoneEnabled or self.zoneActive or self.gameover then return false end
  local threshold=clamp(self.cfg.zoneThreshold or .5,.1,1)
  if self.zoneCharge<threshold then return false end
  self.zoneCharge=self.zoneCharge-threshold
  self.zoneActive=true;self.zoneTime=max(1,self.cfg.zoneDuration or 8)
  self:popup('ZONE ACTIVE',self.w/2,7,.7,1,1);self:sound('super');return true
end
function F:endZone()
  if not self.zoneActive then return end
  self.zoneActive=false;self.zoneTime=0
  if self.zoneRows>0 then self:releaseSealed('ZONE') end
  if next(self.zoneDeferred) then
    local mask=self.zoneDeferred;self.zoneDeferred={};self.zoneDeferredCount=0
    self:clearCells(mask)
  end
  self:popup('ZONE RELEASE',self.w/2,10,1,.85,.55)
end
function F:queueGarbage(units,mandatory)
  units=max(0,floor(units or 0))
  if mandatory then self.penaltyGarbage=min(80,self.penaltyGarbage+units)
  else self.pendingGarbage=min(80,self.pendingGarbage+units) end
  self.garbageWait=max(self.garbageWait,self.cfg.garbageDelay or 1.4)
end
function F:drainAttack() local v=self.attackUnits;self.attackUnits=0;return v end
function F:dropGarbage(units)
  for k=1,units do
    if self.pendingGarbage+self.penaltyGarbage<=0 then break end
    local xs={};for x=1,self.w do xs[x]=x end
    for j=self.w,2,-1 do local q=random(j);xs[j],xs[q]=xs[q],xs[j] end
    local placed=false
    for _,x in ipairs(xs) do
      local y=self.h+1
      for yy=1,self.h do if self.grid[yy][x]~=0 then y=yy;break end end
      if y>1 then
        self.grid[y-1][x]=-1;self.fx[y-1][x]=0
        placed=true;break
      end
    end
    if not placed then self.gameover=true;break end
    if self.penaltyGarbage>0 then self.penaltyGarbage=self.penaltyGarbage-1
    else self.pendingGarbage=self.pendingGarbage-1 end
    self.garbageReceived=self.garbageReceived+1
  end
end
function F:update(dt,boost)
  if self.gameover then return end
  dt=min(dt or 0,.06);self.time=self.time+dt
  self.flash=max(0,self.flash-dt*2.5);self.celebration=max(0,self.celebration-dt)
  for i=#self.popups,1,-1 do local v=self.popups[i];v.life=v.life-dt;v.y=v.y-dt*.75;if v.life<=0 then table.remove(self.popups,i) end end
  for i=#self.particles,1,-1 do
    local p=self.particles[i];p.life=p.life-dt;p.x=p.x+p.vx*dt;p.y=p.y+p.vy*dt;p.vy=p.vy+5*dt
    if p.life<=0 then table.remove(self.particles,i) end
  end
  for i=#self.shocks,1,-1 do local p=self.shocks[i];p.life=p.life-dt;p.size=p.size+dt*13;if p.life<=0 then table.remove(self.shocks,i) end end
  for i=#self.trails,1,-1 do local p=self.trails[i];p.life=p.life-dt;if p.life<=0 then table.remove(self.trails,i) end end
  if boost then self.boostCharge=min(4.5,self.boostCharge+dt*.45)
  else self.boostCharge=max(0,self.boostCharge-dt*.15) end
  self.riskMultiplier=1+floor(self.boostCharge*(self.cfg.boostReward or 1)*2)/2
  if self.zoneActive then
    self.zoneTime=self.zoneTime-dt
    if self.zoneTime<=0 then self:endZone() end
  end
  if self:rule()==2 and not self.zoneActive and self.zoneRows>0 then
    local previous=self.sweep
    self.sweep=self.sweep+dt*self.h/max(1,self.cfg.fallingSweepSecs or 8)
    if self.sweep>=self.h-self.zoneRows and previous<self.h-self.zoneRows then
      self:releaseSealed('SWEEP')
    end
    if self.sweep>=self.h then self.sweep=self.sweep-self.h;self.sweeps=self.sweeps+1 end
  elseif self:rule()==2 and not self.zoneActive then
    self.sweep=(self.sweep+dt*self.h/max(1,self.cfg.fallingSweepSecs or 8))%self.h
  end
  if self.clearTimer>0 then
    self.clearTimer=self.clearTimer-dt
    if self.clearTimer<=0 and self.pendingCells then
      local pending=self.pendingCells;self.pendingCells=nil
      if pending.kind=='lines' then
        self:clearRowsNow(pending.rows,pending.spin,0)
      else self:clearCells(pending.cells) end
      self.clearTimer=0
    else return end
  end
  if self.cascadePending and not self.zoneActive then
    self.cascadePending=false
    local matches=self:collectClusters()
    if #matches>0 then
      local cells={};for _,gr in ipairs(matches) do for _,idx in ipairs(gr.cells) do cells[idx]=true end end
      if (self.cfg.fallingClearDelay or 0)>0 then
        self.pendingCells={kind='cells',cells=cells};self.clearTimer=self.cfg.fallingClearDelay
      else self:clearCells(cells) end
      return
    else
      self.combo=0
    end
  end
  if not self.active then
    if self.pendingGarbage+self.penaltyGarbage>0 then
      self.garbageWait=self.garbageWait-dt
      if self.garbageWait<=0 then self:dropGarbage(min(3,self.pendingGarbage+self.penaltyGarbage));self.garbageWait=.1 end
    end
    if not self.gameover and self.clearTimer<=0 then self:spawn() end
    if not self.active or self.gameover then return end
  end
  local rate=max(.06,self.cfg.fallingGravity or .8)
  local zfactor=self.zoneActive and (self.cfg.zoneGravityScale or .55) or 1
  self.fallTimer=self.fallTimer+dt/(rate*zfactor)*(boost and (self.cfg.boostSpeed or 4.7) or 1)
  while self.fallTimer>=1 and self.active and not self.gameover do
    self.fallTimer=self.fallTimer-1
    if not self:move(0,1) then break end
  end
  if self:onGround() then
    self.lockTimer=self.lockTimer+dt
    if self.lockTimer>=max(.07,self.cfg.lockDelay or .45) then self:lock() end
  else self.lockTimer=0 end
end
return F