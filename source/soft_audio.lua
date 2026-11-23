
local A={}
A.__index=A
local sin,pi,cos,min,max=math.sin,math.pi,math.cos,math.min,math.max
local scales={
 {0,2,4,5,7,9,11},{0,2,3,5,7,8,10},{0,2,3,5,7,9,10},
 {0,2,4,7,9},{0,3,5,7,10},{0,2,4,6,7,9,11},
 {0,2,4,5,7,9,10},{0,1,3,5,7,8,10},{0,2,3,5,7,8,11},{0,2,4,6,8,10}
}
local events={
 rotate={1,.15,.16},rise={-2,.18,.11},start={3,.65,.25},
 clear={2,.52,.22},dual={4,.65,.25},chain={5,.95,.27},super={7,1.12,.33},
 bomb={-4,.65,.23},beam={6,.62,.19},lose={-5,1.1,.28},
 surge={3,.5,.2},garbage={-3,.58,.19},curse={-5,.65,.19}
}
local function clamp(v,a,b) return max(a,min(b,v)) end
local function midiFor(degree,cfg,octave)
 local scale=scales[clamp(cfg.musicScale or 1,1,#scales)]
 local len=#scale
 local idx=((degree-1)%len)+1
 local oct=math.floor((degree-1)/len)
 return 48+(cfg.musicRoot or 0)+scale[idx]+12*(oct+(octave or 0))
end
local function hz(midi) return 440*2^((midi-69)/12) end
local function envelope(t,total,attack,release)
 local a=clamp(t/max(.001,attack),0,1)
 local b=clamp((total-t)/max(.001,release),0,1)
 return (a*a*(3-2*a))*(b*b*(3-2*b))
end
function A.new()
 return setmetatable({cache={},playing={},clock=0,nextNote=2,droneStep=0,cacheSize=0},A)
end
function A:render(freq,length,cfg,pad)
 local rate=22050
 local n=max(1,math.floor(rate*length))
 local data=love.sound.newSoundData(n,rate,16,1)
 local attack=pad and (cfg.musicAttack or 1.2) or (cfg.sfxAttack or .025)
 local release=pad and (cfg.musicRelease or 2.6) or (cfg.sfxRelease or .36)
 local brightness=clamp(pad and (cfg.musicFilter or .32) or (cfg.sfxTone or .22),.02,.95)
 local depth=pad and (cfg.musicModDepth or .13) or .035
 local phase=0
 local smooth=0
 local echoSamples=math.floor(rate*.21)
 local delay={}
 for i=0,n-1 do
   local t=i/rate
   phase=phase+2*pi*freq*(1+.0012*sin(2*pi*.23*t))/rate
   local raw=sin(phase)+.075*sin(phase*2+.3)+.025*sin(phase*3+.7)
   raw=raw*envelope(t,length,attack,release)
   local alpha=clamp(.02+brightness*.28+depth*.08*sin(2*pi*.12*t),.014,.34)
   smooth=smooth+alpha*(raw-smooth)
   local delayed=i>=echoSamples and (delay[i-echoSamples] or 0) or 0
   local out=smooth+.14*delayed
   delay[i]=out
   data:setSample(i,clamp(out*.30,-.9,.9))
 end
 return love.audio.newSource(data,'static')
end
function A:note(degree,duration,cfg,pad,vol,octave)
 if not cfg.sound then return end
 local key=table.concat({degree,duration,pad and 1 or 0,octave or 0,
   cfg.musicScale or 1,cfg.musicRoot or 0,
   cfg.musicAttack or 1.2,cfg.musicRelease or 2.6,
   cfg.musicFilter or .32,cfg.musicModDepth or .13,
   cfg.sfxAttack or .025,cfg.sfxRelease or .36,cfg.sfxTone or .22},':')
 local src=self.cache[key]
 if not src then
   if self.cacheSize>90 then self.cache={};self.cacheSize=0 end
   src=self:render(hz(midiFor(degree,cfg,octave)),duration,cfg,pad)
   self.cache[key]=src
   self.cacheSize=self.cacheSize+1
 end
 local playing=src:clone()
 playing:setVolume(clamp((cfg.volume or .42)*(vol or .3),0,1))
 playing:play()
 self.playing[#self.playing+1]=playing
 if #self.playing>18 then self.playing[1]:stop();table.remove(self.playing,1) end
end
function A:play(event,cfg)
 local def=events[event]
 if not def and event:sub(1,5)=='combo' then
   local n=tonumber(event:sub(6)) or 2
   def={n+1,.42+n*.07,.19}
 end
 def=def or events.rotate
 local gain=def[3]
 if event=='super' or event=='chain' or event:sub(1,5)=='combo' then
   gain=gain*(cfg.comboVolume or 1)
 end
 self:note(def[1],def[2]+(cfg.sfxRelease or .36)*.8,cfg,false,gain,1)
end
function A:update(dt,cfg,board)
 for i=#self.playing,1,-1 do
   if not self.playing[i]:isPlaying() then table.remove(self.playing,i) end
 end
 if not cfg.sound or not cfg.musicEnabled then return end
 self.nextNote=self.nextNote-dt
 if self.nextNote>0 then return end
 local danger=0
 if board and board.grid and board.h then
   for y=1,board.h do
     local occupied=false
     for x=1,board.w do
       if board.grid[y][x]~=0 then occupied=true;break end
     end
     if occupied then
       danger=clamp((board.h-y)/board.h,0,1)
       break
     end
   end
 end
 self.droneStep=self.droneStep+1
 local step=self.droneStep
 local chord=step%4<2 and {1,3,5} or {4,6,8}
 local vol=cfg.musicDrone or .23
 self:note(chord[1],5.5,cfg,true,vol*.40,-1)
 if step%2==0 then self:note(chord[2],5.5,cfg,true,vol*.23,-1) end
 if step%3==0 then self:note(chord[3],5.5,cfg,true,vol*.18,-1) end
 if step%2==1 then self:note(chord[1]+7,.9,cfg,false,.07+danger*.035,0) end
 self.nextNote=clamp(4.2-danger*1.8,1.8,4.2)
end
return A
