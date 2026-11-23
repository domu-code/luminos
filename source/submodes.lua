-- Second-stage game-mode library. Original named modes are distinguished from
-- Lumine Attack adaptations by their descriptions, not by pretending to clone campaigns.
local S={}
local function spec(name,description,kind,goal,opts)
  return {name=name,description=description,kind=kind,goal=goal,opts=opts or {}}
end
S.modes={
  [1]={
    spec('CHALLENGE','Endless sweep-and-square survival','endless'),
    spec('TIME ATTACK 1 MIN','60-second score challenge','time',60),
    spec('TIME ATTACK 3 MIN','180-second score challenge','time',180),
    spec('TIME ATTACK 5 MIN','300-second score challenge','time',300),
    spec('MISSION 100','Clear 100 microtiles to complete','clear',100),
    spec('ROTATION TRIAL','Adapted move-limited clear challenge','swaps',40,{startRows=12,riseSecs=9999,moveLimit=24}),
    spec('VS CPU','Sweep squares against a rival','endless',nil,{vsCPU=true}),
    spec('CHILL SHINE','No rising pressure; slow sweeps','endless',nil,{riseSecs=9999,sweepSecs=12})},
  [2]={
    spec('ENDLESS LINK','Connect colours until top-out','endless'),
    spec('TIME ATTACK 2 MIN','Score for two minutes','time',120),
    spec('LINK MISSION','Clear 120 connected microtiles','clear',120),
    spec('CHAIN TRIAL','Achieve a four-chain sequence','chain',4),
    spec('ZEN LINK','Slow scanner without rising rows','endless',nil,{riseSecs=9999,sweepSecs=16})},
  [3]={
    spec('ENDLESS','Classic rising-panel endurance','endless'),
    spec('TIME TRIAL','Two-minute score attack','time',120),
    spec('STAGE CLEAR','Reduce the initial stack to 4 rows','stage',4,{startRows=12,riseSecs=9999}),
    spec('SWAP TRIAL','Clear 30 cells within 24 actions','swaps',30,{startRows=12,riseSecs=9999,moveLimit=24}),
    spec('VS CPU','Garbage battle against computer','endless',nil,{vsCPU=true})},
  [4]={
    spec('BRIDGE SURVIVAL','Connect both walls before top-out','endless'),
    spec('TIME TRIAL','High score in two minutes','time',120),
    spec('BRIDGE MISSION','Clear 100 cells through bridges','clear',100),
    spec('ZEN BRIDGE','Time to build paths without rising','endless',nil,{riseSecs=9999})},
  [5]={
    spec('MARATHON','Clear 150 lines; speed rises','marathon',150),
    spec('SPRINT 40','Clear 40 lines; fastest time wins','sprint',40),
    spec('ULTRA 3 MIN','Most points in three minutes','time',180),
    spec('ENDLESS','Classic unbounded falling blocks','endless'),
    spec('MASTER','Increasing fall speed; survive','master')},
  [6]={
    spec('ZONE MARATHON','150 scanned lines, Zone enabled','marathon',150,{zoneEnabled=true}),
    spec('SPRINT 40','40-line scan challenge','sprint',40),
    spec('ULTRA 3 MIN','Three-minute scanning score attack','time',180),
    spec('ENDLESS SWEEP','No line target; sweep forever','endless'),
    spec('CHILL SCANNER','Slow scan and gentler falling','endless',nil,{fallingGravity=1.3,fallingSweepSecs=13,zoneStartCharge=1})},
  [7]={
    spec('ENDLESS PUYO','Make colour groups and chains','endless'),
    spec('CHAIN TRIAL','Reach a four-chain cascade','chain',4),
    spec('TIME ATTACK 3 MIN','Score during a timed challenge','time',180),
    spec('100 CLEAR MISSION','Clear 100 coloured cells','clear',100),
    spec('ZEN PUYO','Slow relaxed falling-pair play','endless',nil,{fallingGravity=1.5,garbagePower=0})},
  [8]={
    spec('ARCADE VS CPU','Crash-gem battle against AI','endless',nil,{vsCPU=true}),
    spec('ENDLESS GEMS','Solo survival and gem clears','endless',nil,{vsCPU=false}),
    spec('CRASH RUSH','Clear 100 gems to finish','clear',100,{vsCPU=false}),
    spec('TIME ATTACK','Three-minute solo score','time',180,{vsCPU=false}),
    spec('TRAINING','Slower gems and no incoming attacks','endless',nil,{vsCPU=false,fallingGravity=1.4,garbagePower=0})},
  [9]={
    spec('ARCADE VS CPU','Feed-animal battle','endless',nil,{vsCPU=true}),
    spec('ENDLESS BAKU','Solo falling animal-food puzzle','endless',nil,{vsCPU=false}),
    spec('TIME TRIAL','Three-minute food-chain score','time',180,{vsCPU=false}),
    spec('FEED MISSION','Feed 100 cells to win','clear',100,{vsCPU=false}),
    spec('PRACTICE','Slow falling food-and-animal pairs','endless',nil,{vsCPU=false,fallingGravity=1.4,garbagePower=0})},
  [10]={
    spec('ENDLESS TRIADS','Slide and clear triad clusters','endless'),
    spec('TIME ATTACK','Three-minute cluster score','time',180),
    spec('CLUSTER RUSH','Clear 120 tiles to finish','clear',120),
    spec('CHAIN TRIAL','Reach chain level four','chain',4),
    spec('ZEN SLIDE','Relaxed, slower cluster falling','endless',nil,{fallingGravity=1.5})},
  [11]={
    spec('FREE LAB','Mix any falling piece and rule','endless'),
    spec('TIME ATTACK','Three-minute custom-piece score','time',180),
    spec('CLEAR 120','Clear 120 cells in this mix','clear',120),
    spec('CHAIN TRIAL','Achieve a four-chain clear','chain',4),
    spec('ZEN LAB','Experiment with slow gravity','endless',nil,{fallingGravity=1.5})},
  [12]={
    spec('DEEP CHILL','Long Zone with relaxed gravity','endless',nil,{zoneEnabled=true,zoneStartCharge=1,zoneDuration=24,zoneGravityScale=.35,fallingGravity=1.05}),
    spec('ZONE HARVEST','Clear 150 blocks using Zone','clear',150,{zoneEnabled=true,zoneStartCharge=1,zoneDuration=21}),
    spec('TIME GARDEN','Build a score over three minutes','time',180,{zoneEnabled=true,zoneStartCharge=1,zoneDuration=20}),
    spec('LONG ZONE','Thirty-second Zone build windows','endless',nil,{zoneEnabled=true,zoneStartCharge=1,zoneDuration=30}),
    spec('ENDLESS ZONE','Regular Zone, no finishing target','endless',nil,{zoneEnabled=true})},
  [13]={
    spec('FREE PLAY','Play your own saved combination','endless'),
    spec('TIME ATTACK','Two-minute custom ruleset','time',120),
    spec('MISSION 100','Clear 100 tiles with custom rules','clear',100),
    spec('CHAIN TRIAL','Build a four-chain clear','chain',4),
    spec('ZEN CUSTOM','Relaxed play with custom rules','endless',nil,{riseSecs=9999,fallingGravity=1.4})}
}
function S.forMode(mode) return S.modes[mode] or S.modes[13] end
function S.count(mode) return #S.forMode(mode) end
function S.clamp(mode,id)
  return math.max(1,math.min(S.count(mode),math.floor(tonumber(id) or 1)))
end
function S.get(mode,id) return S.forMode(mode)[S.clamp(mode,id)] end
function S.configure(mode,id,cfg)
  local out={}
  for k,v in pairs(cfg) do out[k]=v end
  for k,v in pairs(S.get(mode,id).opts) do
    if k~='moveLimit' then out[k]=v end
  end
  return out
end
function S.progress(spec,board,elapsed,actions)
  if not spec or spec.kind=='endless' or spec.kind=='master' then return nil end
  if spec.kind=='time' then return elapsed>=spec.goal and 'TIME UP' or nil end
  if spec.kind=='sprint' or spec.kind=='marathon' then
    return (board.lines or 0)>=spec.goal and 'GOAL COMPLETE' or nil
  end
  if spec.kind=='clear' then return (board.cleared or 0)>=spec.goal and 'MISSION COMPLETE' or nil end
  if spec.kind=='chain' then return (board.bestChain or 0)>=spec.goal and 'CHAIN COMPLETE' or nil end
  if spec.kind=='stage' then
    local highest=board.h+1
    for y=1,board.h do
      for x=1,board.w do
        if board.grid[y][x]~=0 then highest=y;break end
      end
      if highest<=board.h then break end
    end
    local height=math.max(0,board.h-highest+1)
    return (board.cleared or 0)>0 and height<=spec.goal and 'STAGE COMPLETE' or nil
  end
  if spec.kind=='swaps' then
    if (board.cleared or 0)>=spec.goal then return 'SWAP MISSION COMPLETE' end
    return actions>=(spec.opts.moveLimit or 24) and 'OUT OF SWAPS' or nil
  end
  return nil
end
function S.hud(spec,board,elapsed,actions)
  if not spec then return '' end
  local kind=spec.kind
  if kind=='time' then return string.format('TIME %02d:%02d  SCORE %d',math.max(0,math.floor((spec.goal-elapsed)/60)),math.max(0,math.floor(spec.goal-elapsed)%60),board.score or 0) end
  if kind=='marathon' or kind=='sprint' then return string.format('%s  %d/%d LINES  %.1f SEC',spec.name,board.lines or 0,spec.goal,elapsed) end
  if kind=='clear' then return string.format('%s  %d/%d',spec.name,board.cleared or 0,spec.goal) end
  if kind=='chain' then return string.format('CHAIN TRIAL  BEST %d/%d',board.bestChain or 0,spec.goal) end
  if kind=='swaps' then return string.format('SWAPS %d/%d   CLEARED %d/%d',actions,spec.opts.moveLimit or 24,board.cleared or 0,spec.goal) end
  if kind=='stage' then return string.format('STAGE CLEAR  GET STACK DOWN TO %d ROWS',spec.goal) end
  if kind=='master' then return string.format('MASTER  LINES %d  %.1f SEC',board.lines or 0,elapsed) end
  return spec.name
end
return S