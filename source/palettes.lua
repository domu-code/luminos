local P = {}
P.names = {'NEON PRISM','SYNTHWAVE','DEEP OCEAN','DUSK GARDEN','CHROME NOIR','SUNSET CIRCUIT','ACID ARCADE','ROSE QUARTZ','SOLARIS','FOREST SIGNAL','POLAR AURORA','EMBER + ICE','RETRO TERMINAL','CANDY NEBULA'}
-- Palette identity is distinct from its display colour. Hue offsets affect all equally,
-- and alternate lightness/saturation within each scheme to distinguish 10 identities.
local bases = {180,320,194,103,210,22,95,350,39,145,166,21,126,302}
local sat = {.89,.82,.73,.73,.76,.85,.98,.76,.81,.76,.79,.88,.84,.81}
local light = {.61,.63,.65,.72,.73,.62,.60,.74,.62,.64,.69,.63,.65,.73}
local function clamp(a,b,c) return math.max(b,math.min(c,a)) end
local function hue2rgb(p,q,t)
  if t < 0 then t=t+1 end
  if t > 1 then t=t-1 end
  if t < 1/6 then return p+(q-p)*6*t end
  if t < 1/2 then return q end
  if t < 2/3 then return p+(q-p)*(2/3-t)*6 end
  return p
end
function P.hsl(h,s,l)
  h=(h%360)/360; s=clamp(s,0,1); l=clamp(l,0,1)
  if s==0 then return l,l,l end
  local q=l < .5 and l*(1+s) or l+s-l*s
  local p=2*l-q
  return hue2rgb(p,q,h+1/3),hue2rgb(p,q,h),hue2rgb(p,q,h-1/3)
end
-- For each pool size, choose hue positions by maximum-distance ordering.
-- This keeps 2 colours opposite and 10 colours 36 degrees apart, without
-- allowing any palette scheme to collapse two identities onto one hue.
local hueOrders={}
local function buildOrder(n)
  if hueOrders[n] then return hueOrders[n] end
  local order={0};local used={[0]=true}
  for k=2,n do
    local best,bestSpace=nil,-1
    for candidate=0,n-1 do
      if not used[candidate] then
        local space=360
        for _,picked in ipairs(order) do
          local d=math.abs(candidate-picked)*360/n
          space=math.min(space,d,360-d)
        end
        if space>bestSpace then best,bestSpace=candidate,space end
      end
    end
    used[best]=true;order[#order+1]=best
  end
  hueOrders[n]=order
  return order
end
function P.get(index,palette,count,time,drift)
  local p=clamp(palette or 1,1,#P.names)
  local countN=math.max(2,math.min(10,count or 4))
  local rank=buildOrder(countN)[(index-1)%countN+1]
  local hue=bases[p] + rank*360/countN
  local saturation=sat[p]*(index%3==0 and .83 or 1)
  local luminosity=light[p]+((index%4)-1.5)*.055
  if p==5 then luminosity=.66+((index%4)-1.5)*.10 end
  if p==8 then luminosity=.67+((index%4)-1.5)*.075 end
  if drift then hue=hue+(time or 0)*7+math.sin((time or 0)*.41)*8 end
  return P.hsl(hue,saturation,clamp(luminosity,.42,.86))
end
return P
