-- LUMINE ATTACK / Reactive VFX engine
-- LÖVE 11.5, no external dependencies. Runs entirely in the existing 640x440 scene.
-- The board is sampled read-only; the visual engine NEVER changes game rules.
local presets=require('vfx_presets')
local V={};V.__index=V
local G=love.graphics
local pi,sin,cos,sqrt,exp,abs,min,max,floor=math.pi,math.sin,math.cos,math.sqrt,math.exp,math.abs,math.min,math.max,math.floor
local W,H=640,440
local clamp=function(x,a,b) return max(a,min(b,x)) end
local palettes={
 {{.04,.9,1},{.18,.36,1},{.72,.15,1},{1,.08,.70},{1,.92,.1}},
 {{1,.91,.32},{1,.52,.08},{1,.17,.08},{.67,.04,.25},{.29,.03,.31}},
 {{1,.12,.35},{1,.78,.24},{.22,.91,.66},{.20,.51,1},{.70,.36,1}},
 {{.75,1,.01},{.35,1,.02},{.98,.14,.82},{.45,.22,1},{.02,.92,.95}},
 {{.20,1,.72},{.30,.84,1},{.56,.43,1},{1,.34,.73},{1,.77,.94}},
 {{.25,.25,.25},{.45,.45,.45},{.66,.66,.66},{.86,.86,.86},{1,1,1}}
}
local function colour(self,index,alpha)
 local p=palettes[self.config.palette] or palettes[1]
 local c=p[(index-1)%#p+1]
 G.setColor(c[1],c[2],c[3],alpha or 1)
end
local function val(v,default) if type(v)=='number' then return v else return default end end
local function cell(board,x,y)
 if not board then return nil end
 local fields={board.cells,board.grid,board.field,board.tiles}
 for index=1,4 do
  local f=fields[index]
  if type(f)=='table' then
   local row=f[y]
   if type(row)=='table' then
    local item=row[x]
    if item~=nil then
     if type(item)=='number' then return item end
     if type(item)=='table' then return item.colour or item.color or item.c or item[1] or 0 end
    end
   end
   local col=f[x]
   if type(col)=='table' and col[y]~=nil then
    local item=col[y]
    if type(item)=='number' then return item end
    if type(item)=='table' then return item.colour or item.color or item.c or item[1] or 0 end
   end
  end
 end
 return nil
end
local function boardSample(board,x,y)
 local bw=val(board and board.w,12);local bh=val(board and board.h,20)
 local xx=clamp(floor(x*bw)+1,1,bw);local yy=clamp(floor(y*bh)+1,1,bh)
 local c=cell(board,xx,yy)
 if type(c)=='number' then return c end
 return 0
end
function V.new()
 local self=setmetatable({},V)
 self.time=0;self.elapsed=0;self.particles={};self.rings={};self.shards={}
 self.points={};self.previousScore=0;self.previousCleared=0;self.previousChain=0
 self.cursorX=.5;self.cursorY=.5;self.cursorPulse=0;self.energy=0
 self.boardReadout={density=0,entropy=0};self.lastBoard=nil
 self.config={};self.lastPreset=0;self.cachedW=0;self.cachedH=0
 self.random=love.math.newRandomGenerator(75291)
 self.history=nil;self.nextHistory=nil;self.aberrationShader=nil
 return self
end
function V:configure(cfg)
 local index=clamp(floor(val(cfg.vfxPreset,1)),1,#presets)
 local p=presets[index]
 local intensity=val(cfg.vfxIntensity,100)/100
 self.config={
  palette=clamp(floor((val(cfg.vfxPalette,0)>0) and cfg.vfxPalette or p.palette),1,#palettes),
  background=clamp(floor((val(cfg.vfxBackground,0)>0) and cfg.vfxBackground or p.background),1,4),
  intensity=p.intensity*intensity,
  density=p.density*val(cfg.vfxDensity,100)/100,
  reactivity=p.reactivity*val(cfg.vfxReactivity,100)/100,
  feedback=p.feedback*val(cfg.vfxFeedback,100)/100,
  particles=p.particles,bloom=p.bloom,aberration=p.aberration,shards=p.shards,
  enabled=cfg.vfxEnabled~=false,
  mesh=cfg.vfxMesh~=false,
  particlesEnabled=cfg.vfxParticles~=false,
  waves=cfg.vfxWaves~=false,
  shardsEnabled=cfg.vfxShards~=false,
  scanlines=cfg.vfxScanlines==true,
  quality=clamp(floor(val(cfg.vfxQuality,2)),1,3),
 }
 self.presetName=p.name
end
function V:buildPoints()
 local c=self.config
 local nx=floor(11+17*c.density);local ny=floor(7+12*c.density)
 if c.quality==1 then nx=floor(nx*.60);ny=floor(ny*.60) end
 if c.quality==3 then nx=floor(nx*1.16);ny=floor(ny*1.16) end
 nx=max(5,nx);ny=max(4,ny)
 if nx==self.cachedW and ny==self.cachedH then return end
 self.cachedW,self.cachedH=nx,ny;self.points={}
 for y=0,ny-1 do for x=0,nx-1 do
  local u=x/(nx-1);local v=y/(ny-1)
  local jx=(self.random:random()-.5)*W/(nx-1)*.42
  local jy=(self.random:random()-.5)*H/(ny-1)*.42
  self.points[#self.points+1]={u=u,v=v,x=u*W+jx,y=v*H+jy,h=0,target=0,c=1}
 end end
end
function V:emit(x,y,n,force)
 if not self.config.enabled then return end
 local cap= self.config.quality==1 and 110 or self.config.quality==2 and 240 or 420
 local amount=min(floor(n*self.config.density*self.config.particles+1),cap)
 for i=1,amount do
  if #self.particles>=cap then table.remove(self.particles,1) end
  local a=self.random:random()*2*pi;local speed=(30+self.random:random()*155)*force
  self.particles[#self.particles+1]={x=x,y=y,vx=cos(a)*speed,vy=sin(a)*speed,
   life=.5+self.random:random()*1.1,maxLife=1.6,c=self.random:random(1,5),size=1+self.random:random()*2}
 end
 if #self.rings>20 then table.remove(self.rings,1) end
 self.rings[#self.rings+1]={x=x,y=y,life=1,radius=0,c=self.random:random(1,5),force=force}
 if self.config.shardsEnabled then
  for i=1,min(30,floor(n*self.config.shards*.25)) do
   if #self.shards>=90 then table.remove(self.shards,1) end
   local a=self.random:random()*pi*2
   self.shards[#self.shards+1]={x=x,y=y,vx=cos(a)*self.random:random(20,110),vy=sin(a)*self.random:random(20,110),
     angle=a,spin=(self.random:random()-.5)*8,life=.8+self.random:random(),size=3+self.random:random()*15,c=self.random:random(1,5)}
  end
 end
end
local function cursor(board)
 if type(board)~='table' then return .5,.5 end
 local x=board.cursorX or board.cx or (type(board.cursor)=='table' and (board.cursor.x or board.cursor[1]))
 local y=board.cursorY or board.cy or (type(board.cursor)=='table' and (board.cursor.y or board.cursor[2]))
 return clamp((val(x,board.w*.5)-.5)/max(1,board.w),0,1),clamp((val(y,board.h*.5)-.5)/max(1,board.h),0,1)
end
function V:update(ui,dt)
 dt=clamp(dt or 1/60,0,.07)
 self:configure(ui.cfg or {})
 if not self.config.enabled then return end
 self.time=self.time+dt
 local board=ui.board or {}
 self:buildPoints()
 local cx,cy=cursor(board)
 local moved=abs(cx-self.cursorX)+abs(cy-self.cursorY)
 self.cursorPulse=clamp(self.cursorPulse+20*moved-2*dt,0,1)
 self.cursorX,self.cursorY=cx,cy
 local cleared=val(board.cleared,0);local score=val(board.score,0);local chain=val(board.chain,0)
 local clearDelta=max(0,cleared-self.previousCleared)
 if clearDelta>0 or (score>self.previousScore and chain>self.previousChain) then
  self:emit(cx*W,cy*H,clamp(clearDelta*6+chain*7,12,90),clamp(1+chain*.16,1,3))
  self.energy=clamp(self.energy+.16+clearDelta*.035,0,2)
 end
 self.previousCleared=cleared;self.previousScore=score;self.previousChain=chain
 self.energy=max(0,self.energy-dt*.48)
 local alive={}
 for _,p in ipairs(self.particles) do
  p.x=p.x+p.vx*dt;p.y=p.y+p.vy*dt;p.vx=p.vx*(1-dt*.7);p.vy=p.vy*(1-dt*.7)
  p.life=p.life-dt
  if p.life>0 then alive[#alive+1]=p end
 end
 self.particles=alive
 alive={}
 for _,p in ipairs(self.rings) do p.life=p.life-dt*.95;p.radius=p.radius+dt*175*p.force;if p.life>0 then alive[#alive+1]=p end end
 self.rings=alive
 alive={}
 for _,p in ipairs(self.shards) do
  p.x=p.x+p.vx*dt;p.y=p.y+p.vy*dt;p.angle=p.angle+p.spin*dt;p.life=p.life-dt*.9
  if p.life>0 then alive[#alive+1]=p end
 end
 self.shards=alive
 -- Read-only sample of board to derive occupancy and colour diversity.
 local occupied=0;local counts={};local samples=0
 for y=1,7 do for x=1,11 do
  local c=boardSample(board,(x-.5)/11,(y-.5)/7)
  if c>0 then occupied=occupied+1;counts[c]=(counts[c] or 0)+1 end
  samples=samples+1
 end end
 self.boardReadout.density=occupied/samples
 local entropy=0
 if occupied>0 then for _,v in pairs(counts) do local q=v/occupied;entropy=entropy-q*math.log(q) end end
 self.boardReadout.entropy=entropy
 local C=self.config
 for _,p in ipairs(self.points) do
  local dx=p.u-cx;local dy=p.v-cy
  local distance=dx*dx+dy*dy
  local cursorWave=exp(-distance*34)*((self.cursorPulse*.5)+.32)
  local wave=sin(p.u*21+self.time*1.9)*cos(p.v*14-self.time*1.5)*.12
  local top=boardSample(board,p.u,p.v)
  local value=clamp(top/10,0,1)
  local ripple=0
  if C.waves then
   for _,r in ipairs(self.rings) do
    local d=sqrt((p.x-r.x)^2+(p.y-r.y)^2)
    ripple=ripple+exp(-abs(d-r.radius)*.046)*sin((d-r.radius)*.13)*r.life*.60
   end
  end
  p.target=(cursorWave+wave+ripple+value*.33+self.energy*.22)*C.reactivity
  p.h=p.h+(p.target-p.h)*min(1,dt*8)
  p.c=top>0 and top or (1+floor((p.u+p.v+self.time*.07)*5))
 end
end
local function pt(self,x,y)
 local p=self.points[(y-1)*self.cachedW+x]
 local c=self.config
 local d=p.h*c.intensity
 local dx=(p.u-self.cursorX);local dy=(p.v-self.cursorY)
 local mx=dx*d*32;local my=dy*d*25
 return p.x+mx,p.y-my-sin(p.u*12+self.time)*d*15,p.c
end
function V:background(ui)
 local c=self.config
 if not c.enabled or not c.mesh then return end
 local nx,ny=self.cachedW,self.cachedH
 if nx==0 or ny==0 then return end
 local mode=c.background
 local alpha=clamp(.18*c.intensity,0,.55)
 G.setLineWidth(1)
 for y=1,ny do for x=1,nx do
  local ax,ay,col=pt(self,x,y)
  if x<nx then
   local bx,by=pt(self,x+1,y)
   colour(self,col,alpha);G.line(ax,ay,bx,by)
  end
  if y<ny then
   local bx,by=pt(self,x,y+1)
   colour(self,col,alpha);G.line(ax,ay,bx,by)
  end
  if mode==1 or mode==3 then
   if x<nx and y<ny then
    local bx,by=pt(self,x+1,y)
    local dx,dy=pt(self,x,y+1)
    colour(self,col,alpha*.75);G.line(bx,by,dx,dy)
    if mode==3 then
     colour(self,col,alpha*.21)
     G.polygon('fill',ax,ay,bx,by,dx,dy)
    end
   end
  elseif mode==4 then
   if x<nx and y<ny and (x+y)%2==0 then
    local bx,by=pt(self,x+1,y+1)
    colour(self,col,alpha*.7);G.line(ax,ay,bx,by)
   end
  end
  if mode==2 or (x+y)%2==0 then
   colour(self,col,clamp(alpha*(mode==2 and 2 or .9),0,.8))
   G.points(ax,ay)
  end
 end end
 -- Contour lines and breathing rings created by board clear events.
 for _,r in ipairs(self.rings) do
  colour(self,r.c,r.life*.15*c.intensity)
  G.circle('line',r.x,r.y,r.radius,48)
 end
 if c.scanlines then
  G.setColor(.08,.12,.2,.07)
  for y=0,H,4 do G.line(0,y,W,y) end
 end
 G.setColor(1,1,1,1)
end
function V:foreground(ui)
 local c=self.config
 if not c.enabled then return end
 G.setBlendMode('add','alphamultiply')
 if c.particlesEnabled then
  for _,p in ipairs(self.particles) do
   colour(self,p.c,clamp(p.life*.5*c.intensity,0,1))
   G.rectangle('fill',p.x,p.y,p.size,p.size)
  end
 end
 if c.shardsEnabled then
  for _,p in ipairs(self.shards) do
   colour(self,p.c,clamp(p.life*.26*c.intensity,0,.7))
   local x,y,s,a=p.x,p.y,p.size,p.angle
   G.polygon('line',x+cos(a)*s,y+sin(a)*s,x+cos(a+2.3)*s*.7,y+sin(a+2.3)*s*.7,x+cos(a+4.4)*s*.75,y+sin(a+4.4)*s*.75)
  end
 end
 if c.bloom>0 then
  local power=clamp((self.energy+.05)*c.intensity*c.bloom,0,.5)
  G.setColor(.3,.7,1,power)
  G.circle('line',self.cursorX*W,self.cursorY*H,22+self.energy*75,48)
 end
 G.setBlendMode('alpha','alphamultiply')
 G.setColor(1,1,1,1)
end
function V:postScene(scene)
 local c=self.config
 if not c.enabled or c.feedback<=0 then return end
 if not self.history then
  self.history=G.newCanvas(W,H)
  self.nextHistory=G.newCanvas(W,H)
  self.history:setFilter('linear','linear')
  self.nextHistory:setFilter('linear','linear')
  G.setCanvas(self.history);G.clear(0,0,0,0)
 end
 -- Scene canvas is the caller's target; read previous feedback from a separate canvas.
 G.setCanvas(scene)
 G.setColor(1,1,1,clamp(c.feedback*.22,0,.32))
 G.draw(self.history)
 G.setCanvas(self.nextHistory)
 G.clear(0,0,0,0)
 G.setColor(1,1,1,clamp(c.feedback*.88,0,.92))
 G.draw(self.history)
 G.setBlendMode('add','alphamultiply')
 G.setColor(1,1,1,clamp(c.feedback*.20,0,.30))
 G.draw(scene)
 G.setBlendMode('alpha','alphamultiply')
 self.history,self.nextHistory=self.nextHistory,self.history
 G.setCanvas(scene)
 G.setColor(1,1,1,1)
end
function V:postDisplay(scene,ox,oy,scale)
 local c=self.config
 if not c.enabled or c.aberration<=0 then return end
 if not self.aberrationShader then
  local ok,shader=pcall(G.newShader,[[extern vec2 shift;
   vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
    vec4 center=Texel(texture,tc);
    float red=Texel(texture,tc+shift).r;
    float blue=Texel(texture,tc-shift).b;
    return vec4(red,center.g,blue,center.a)*color;
   }]])
  if ok then self.aberrationShader=shader else return end
 end
 G.setShader(self.aberrationShader)
 self.aberrationShader:send('shift',{c.aberration*.003,0})
 G.setColor(1,1,1,clamp(c.aberration*.65,0,.55))
 G.draw(scene,ox,oy,0,scale,scale)
 G.setShader()
 G.setColor(1,1,1,1)
end
function V:paletteCount() return #palettes end
function V:presetCount() return #presets end
function V:presetName(i) return presets[i] and presets[i].name or 'UNKNOWN' end
return V