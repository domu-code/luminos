-- Self-contained local preset and leaderboard store (no network, no account).
local R={};R.__index=R
local function copy(cfg)
  local out={}
  for k,v in pairs(cfg) do
    if type(v)=='number' or type(v)=='boolean' then out[k]=v end
  end
  return out
end
local function serial(t)
  local p={'return {'}
  for slot=1,8 do
    local record=t.slots[slot]
    if record then
      p[#p+1]=' ['..slot..']={name='..string.format('%q',record.name)..',cfg={'
      local keys={};for k in pairs(record.cfg) do keys[#keys+1]=k end
      table.sort(keys)
      for _,k in ipairs(keys) do
        local v=record.cfg[k]
        if type(v)=='number' or type(v)=='boolean' then
          p[#p+1]=string.format(' [%q]=%s,',k,tostring(v))
        end
      end
      p[#p+1]=' },scores={'
      local kinds={};for kind in pairs(record.scores or {}) do kinds[#kinds+1]=kind end
      table.sort(kinds)
      for _,kind in ipairs(kinds) do
        p[#p+1]=string.format(' [%q]={',kind)
        for _,s in ipairs(record.scores[kind]) do
          p[#p+1]=string.format('{points=%d,chain=%d,cleared=%d,won=%s},',s.points,s.chain,s.cleared,tostring(s.won))
        end
        p[#p+1]=' },'
      end
      p[#p+1]=' }},'
    end
  end
  p[#p+1]='}'
  return table.concat(p,'\n')
end
function R.new(defaults)
  local self=setmetatable({slots={}},R)
  if love.filesystem.getInfo('tide_records.lua') then
    local f=love.filesystem.load('tide_records.lua')
    if f then
      local ok,records=pcall(f)
      if ok and type(records)=='table' then
        for slot=1,8 do
          local rec=records[slot]
          if type(rec)=='table' and type(rec.cfg)=='table' and type(rec.scores)=='table' then
            self.slots[slot]={name='PRESET '..slot,cfg=copy(rec.cfg),scores=rec.scores}
          end
        end
      end
    end
  end
  if not self.slots[1] then
    self.slots[1]={name='DEFAULT',cfg=copy(defaults),scores={}}
    self:save()
  end
  return self
end
function R:save() return love.filesystem.write('tide_records.lua',serial(self)) end
function R:store(slot,cfg)
  slot=math.max(1,math.min(8,math.floor(slot)))
  self.slots[slot]={name='PRESET '..slot,cfg=copy(cfg),scores={}}
  self:save()
end
function R:load(slot,defaults)
  local rec=self.slots[slot];if not rec then return nil end
  local config=copy(defaults)
  for k,v in pairs(config) do if type(rec.cfg[k])==type(v) then config[k]=rec.cfg[k] end end
  return config
end
function R:list(slot,mode,versus)
  local rec=self.slots[slot]
  if not rec then return {} end
  local name=(versus and 'V' or 'S')..tostring(mode)
  return rec.scores[name] or {}
end
function R:record(slot,mode,versus,score,chain,cleared,won)
  local rec=self.slots[slot]
  if not rec or score<1 then return end
  local name=(versus and 'V' or 'S')..tostring(mode)
  local scores=rec.scores[name] or {}
  scores[#scores+1]={points=math.floor(score),chain=math.floor(chain),cleared=math.floor(cleared),won=not not won}
  table.sort(scores,function(a,b)
    if versus and a.won~=b.won then return a.won end
    return a.points>b.points
  end)
  while #scores>10 do table.remove(scores) end
  rec.scores[name]=scores
  self:save()
end
return R