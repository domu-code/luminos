-- CPU opponent and versus attack exchange, using the same Engine API as the player.
local Engine=require('engine')
local V={};V.__index=V
local floor,min,max,random=math.floor,math.min,math.max,math.random
local function cellMatches(b)
  local groups=b:collect(false)
  local score=0
  for _,gr in ipairs(groups) do score=score+#gr.cells*#gr.cells end
  return score
end
function V.new(cfg)
  local v=setmetatable({},V)
  v.cfg=cfg;v.board=Engine.new(cfg);v.timer=.8;v.target=nil
  v.ended=false;v.winner=nil;v.ticks=0
  return v
end
function V:choose()
  local b=self.board
  if b.gameover then return end
  local samples=8+floor(18*self.cfg.cpuSkill)
  local current=cellMatches(b);local best=-1e9;local destination=nil
  for n=1,samples do
    local x=random(b.w-1);local y=max(1,min(b.h-(self.cfg.mode==3 and 0 or 1),b.h-random(1,13)))
    local ps=self.cfg.mode==3 and {{x,y},{x+1,y}} or {{x,y},{x+1,y},{x+1,y+1},{x,y+1}}
    local source={}
    for _,layer in ipairs({'grid','icon'}) do
      local tab=b[layer];source[layer]={}
      for k,p in ipairs(ps) do source[layer][k]=tab[p[2]][p[1]] end
      if #ps==2 then tab[y][x],tab[y][x+1]=tab[y][x+1],tab[y][x]
      else for k,p in ipairs(ps) do tab[p[2]][p[1]]=source[layer][({4,1,2,3})[k]] end end
    end
    local potential=cellMatches(b)
    local neighbor=0
    for _,p in ipairs(ps) do
      local c=b.grid[p[2]][p[1]]
      if c>0 then neighbor=neighbor+1 end
    end
    local heuristic=(potential-current)*4+neighbor*.15+random()*max(1,12*(1-self.cfg.cpuSkill))
    if heuristic>best then best=heuristic;destination={x,y} end
    for _,layer in ipairs({'grid','icon'}) do
      local tab=b[layer]
      for k,p in ipairs(ps) do tab[p[2]][p[1]]=source[layer][k] end
    end
  end
  if destination then b.cx,b.cy=destination[1],destination[2];b:act(true) end
  self.ticks=self.ticks+1
end
function V:update(dt,player)
  if self.ended then return end
  local b=self.board
  b:update(dt,false)
  self.timer=self.timer-dt
  if self.timer<=0 then
    self:choose()
    self.timer=max(.16,(1.7-(self.cfg.cpuSkill or .65)*1.1)/(self.cfg.cpuSpeed or .85))
  end
  local pa,ca=player:drainAttack(),b:drainAttack()
  local cancel=min(pa,ca);pa=pa-cancel;ca=ca-cancel
  -- Attacks already incoming can be neutralised by a sufficiently good clear.
  local dp=min(pa,player.pendingGarbage);player.pendingGarbage=player.pendingGarbage-dp;pa=pa-dp
  local dc=min(ca,b.pendingGarbage);b.pendingGarbage=b.pendingGarbage-dc;ca=ca-dc
  if pa>0 then b:queueGarbage(pa) end
  if ca>0 then player:queueGarbage(ca) end
  if player.gameover or b.gameover then
    self.ended=true
    self.winner=player.gameover and (b.gameover and 'DRAW' or 'CPU') or 'PLAYER'
  end
end
return V