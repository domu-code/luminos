-- User rule presets and isolated high scores for both factory and saved games.
-- Backwards compatible with earlier tide_records.lua files (eight numeric slots).
local R={};R.__index=R
local MAX_SLOTS=16
local function copy(cfg)
  local out={}
  for k,v in pairs(cfg or {}) do
    if type(v)=='number' or type(v)=='boolean' then out[k]=v end
  end
  return out
end
local function same(a,b)
  for k,v in pairs(a) do if b[k]~=v then return false end end
  for k,v in pairs(b) do if a[k]~=v then return false end end
  return true
end
local function name(s,default)
  s=tostring(s or default or 'CUSTOM'):upper():gsub('[^A-Z0-9 _%-]','')
  s=s:sub(1,18):gsub('^%s+',''):gsub('%s+$','')
  return s=='' and (default or 'CUSTOM') or s
end
local function scoreKey(mode,versus)
  return (versus and 'V' or 'S')..tostring(mode)
end
local function appendScores(parts,scores)
  parts[#parts+1]='{' 
  local keys={};for k in pairs(scores or {}) do keys[#keys+1]=k end
  table.sort(keys)
  for _,k in ipairs(keys) do
    parts[#parts+1]=string.format('[%q]={',k)
    for _,item in ipairs(scores[k]) do
      parts[#parts+1]=string.format('{points=%.0f,chain=%d,cleared=%d,won=%s},',
        tonumber(item.points) or 0,tonumber(item.chain) or 0,tonumber(item.cleared) or 0,tostring(item.won==true))
    end
    parts[#parts+1]='},'
  end
  parts[#parts+1]='}'
end
local function serial(self)
  local p={'return {\n  factoryScores='}
  appendScores(p,self.factoryScores)
  p[#p+1]=',\n'
  for slot=1,MAX_SLOTS do
    local rec=self.slots[slot]
    if rec then
      p[#p+1]='['..slot..']={name='..string.format('%q',rec.name)..',cfg={'
      local keys={};for k in pairs(rec.cfg) do keys[#keys+1]=k end
      table.sort(keys)
      for _,k in ipairs(keys) do
        local v=rec.cfg[k]
        if type(v)=='number' or type(v)=='boolean' then
          p[#p+1]=string.format('[%q]=%s,',k,tostring(v))
        end
      end
      p[#p+1]='},scores='
      appendScores(p,rec.scores)
      p[#p+1]='},\n'
    end
  end
  p[#p+1]='}'
  return table.concat(p)
end
function R.new(defaults)
  local self=setmetatable({slots={},factoryScores={}},R)
  if love.filesystem.getInfo('tide_records.lua') then
    local f=love.filesystem.load('tide_records.lua')
    if f then
      local ok,recs=pcall(f)
      if ok and type(recs)=='table' then
        if type(recs.factoryScores)=='table' then self.factoryScores=recs.factoryScores end
        for slot=1,MAX_SLOTS do
          local rec=recs[slot]
          if type(rec)=='table' and type(rec.cfg)=='table' then
            self.slots[slot]={name=name(rec.name,'PRESET '..slot),cfg=copy(rec.cfg),scores=type(rec.scores)=='table' and rec.scores or {}}
          end
        end
      end
    end
  end
  return self
end
function R:save() return love.filesystem.write('tide_records.lua',serial(self)) end
function R:store(slot,cfg,requestedName)
  slot=math.max(1,math.min(MAX_SLOTS,math.floor(slot)))
  local prior=self.slots[slot]
  local candidate=copy(cfg)
  -- Preserve scores only when the rules are actually identical.
  local scores=prior and same(prior.cfg,candidate) and prior.scores or {}
  local label=name(requestedName or (prior and prior.name), 'CUSTOM '..slot)
  self.slots[slot]={name=label,cfg=candidate,scores=scores}
  self:save()
end
function R:rename(slot,newName)
  local rec=self.slots[slot]
  if not rec then return false end
  rec.name=name(newName,'CUSTOM '..slot)
  self:save()
  return true
end
function R:load(slot,defaults)
  local rec=self.slots[slot]
  if not rec then return nil end
  local cfg=copy(defaults)
  for k,v in pairs(cfg) do if type(rec.cfg[k])==type(v) then cfg[k]=rec.cfg[k] end end
  return cfg
end
function R:list(slot,mode,versus)
  local records
  if slot==0 then records=self.factoryScores
  else
    local rec=self.slots[slot]
    if not rec then return {} end
    records=rec.scores
  end
  return records[scoreKey(mode,versus)] or {}
end
function R:record(slot,mode,versus,score,chain,cleared,won)
  if type(score)~='number' or score<1 then return end
  local records
  if slot==0 then
    -- Unsaved Custom rules change between plays, so they need a saved preset
    -- before records can be compared fairly.
    if mode==12 then return end
    records=self.factoryScores
  else
    local rec=self.slots[slot];if not rec then return end
    records=rec.scores
  end
  local key=scoreKey(mode,versus)
  local scores=records[key] or {}
  scores[#scores+1]={points=math.floor(score),chain=math.floor(chain or 0),cleared=math.floor(cleared or 0),won=won==true}
  table.sort(scores,function(a,b)
    if versus and a.won~=b.won then return a.won end
    return a.points>b.points
  end)
  while #scores>10 do table.remove(scores) end
  records[key]=scores
  self:save()
end
return R