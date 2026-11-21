local P=require('palettes')
local F=require('pixel')
local R={}
R.__index=R
local floor,cos,sin,pi,exp,min,max=math.floor,math.cos,math.sin,math.pi,math.exp,math.min,math.max
local g=love.graphics
local LW,LH=640,440
local function rect(x,y,w,h,col,line)
  g.setColor(col[1],col[2],col[3],col[4] or 1)
  g.rectangle(line and 'line' or 'fill',floor(x),floor(y),floor(w),floor(h))
end
local function txt(s,x,y,size,col,align)
  F.draw(s,x,y,size or 2,(col and col[1]) or .85,(col and col[2]) or .95,(col and col[3]) or 1,(col and col[4]) or 1,align)
end
function R.new()
  local r=setmetatable({frame=0,quality=3,target=3,qualityTimer=0,blurring=false},R)
  r.scene=g.newCanvas(LW,LH)
  r.scene:setFilter('linear','linear')
  r:makeBloom()
  return r
end
function R:makeBloom()
  local ok,result=pcall(function()
    self.threshold=g.newShader([[
      vec4 effect(vec4 color, Image tex, vec2 uv, vec2 pixel) {
        vec4 c=Texel(tex,uv);
        float v=max(c.r,max(c.g,c.b));
        return vec4(c.rgb*smoothstep(0.37,0.9,v),1.0)*color;
      }
    ]])
    self.blur=g.newShader([[
      extern vec2 direction;
      vec4 effect(vec4 color, Image tex, vec2 uv, vec2 pixel) {
        vec4 c=Texel(tex,uv)*0.227027;
        c+=Texel(tex,uv+direction*1.384615)*0.316216;
        c+=Texel(tex,uv-direction*1.384615)*0.316216;
        c+=Texel(tex,uv+direction*3.230769)*0.070270;
        c+=Texel(tex,uv-direction*3.230769)*0.070270;
        return c*color;
      }
    ]])
  end)
  if not ok then self.threshold=nil;self.blur=nil end
  self:resizeBlur()
end
function R:resizeBlur()
  local factor=self.quality==3 and 4 or self.quality==2 and 6 or 8
  local w,h=math.ceil(LW/factor),math.ceil(LH/factor)
  self.bloomW,self.bloomH=w,h
  self.a=g.newCanvas(w,h);self.b=g.newCanvas(w,h)
  self.a:setFilter('linear','linear');self.b:setFilter('linear','linear')
  self.blurNeedsUpdate=true
end
function R:adaptive(dt,enabled)
  if not enabled then
    if self.quality~=3 then self.quality=3;self:resizeBlur() end
    return
  end
  self.qualityTimer=self.qualityTimer+dt
  if self.qualityTimer<2.2 then return end
  self.qualityTimer=0
  local fps=love.timer.getFPS()
  if fps<42 and self.quality>1 then self.quality=self.quality-1;self:resizeBlur()
  elseif fps>57 and self.quality<3 then self.quality=self.quality+1;self:resizeBlur() end
end
local function cellRGB(cfg,c,t)
  return P.get(c,cfg.palette,cfg.colours,t,cfg.hueDrift)
end
function R:stars(time)
  for i=1,65 do
    local x=(i*137.21)%LW;local y=(i*74.57)%LH
    local v=.13+.08*sin(time*.6+i*1.3)
    g.setColor(.24,.67,1,v)
    g.rectangle('fill',floor(x),floor(y),1,1)
  end
end
function R:background(t)
  g.clear(.018,.026,.060,1)
  local horizon=320
  g.setColor(.075,.25,.38,.23)
  for i=0,13 do
    local a=(i-6.5)/6.5
    g.line(LW/2,horizon, LW/2+a*LW*1.4,LH)
  end
  for i=1,6 do
    local y=horizon+(i/6)^1.8*(LH-horizon)
    g.line(0,y,LW,y)
  end
  self:stars(t)
  g.setColor(.11,.50,.72,.12)
  for i=1,5 do
    g.ellipse('line',LW/2,177,115+i*45,85+i*22)
  end
end
function R:board(board,cfg,t)
  local w,h=board.w,board.h
  local S=15;local bx=floor((LW-w*S)/2);local by=45
  self.bx,self.by,self.tile=bx,by,S
  rect(bx-7,by-7,w*S+14,h*S+14,{.02,.08,.13,.93})
  rect(bx-6,by-6,w*S+12,h*S+12,{.18,.85,1,.53},true)
  rect(bx-9,by-9,w*S+18,h*S+18,{.22,.64,1,.18},true)
  g.setColor(.14,.42,.61,.20)
  for x=0,w do g.line(bx+x*S,by,bx+x*S,by+h*S) end
  for y=0,h do g.line(bx,by+y*S,bx+w*S,by+y*S) end
  local matched={}
  for _,gr in ipairs(board.groups) do for _,index in ipairs(gr.cells) do matched[index]=true end end
  -- A quiet pulse behind candidate groups becomes brighter when the sweep approaches.
  for y=1,h do for x=1,w do
    local c=board.grid[y][x]
    if c~=0 then
      local py=by+(y-1-board.rise)*S
      if py>=by-16 and py<by+h*S then
        local px=bx+(x-1)*S
        local rr,gg,bb=cellRGB(cfg,c,t)
        local index=(y-1)*w+x
        local charged=matched[index]
        local distance=math.abs(board.sweep-y)
        local charge=charged and (1.2+2.3*exp(-distance*.38)) or .25
        g.setColor(rr,gg,bb,.13+(charged and .18 or 0))
        g.rectangle('fill',px-2,py-2,S+4,S+4)
        g.setColor(rr*.42,gg*.42,bb*.42,1)
        g.rectangle('fill',px+1,py+1,S-2,S-2)
        g.setColor(rr*.83,gg*.83,bb*.83,.8)
        g.rectangle('line',px+.5,py+.5,S-1,S-1)
        g.setColor(min(1,rr*.55+charge*.15),min(1,gg*.55+charge*.15),min(1,bb*.55+charge*.15),charged and .75 or .46)
        g.rectangle('fill',px+3,py+3,S-6,S-6)
        if charged then
          g.setColor(rr,gg,bb,.72)
          g.rectangle('line',px-1,py-1,S+2,S+2)
          g.setColor(1,1,1,.65+sin(t*8)*.13)
          g.rectangle('line',px+2,py+2,S-4,S-4)
        end
        local fx=board.fx[y][x]
        if fx~=0 then
          local marker=fx<=3 and '*' or fx==4 and 'P' or fx==5 and 'R' or fx==6 and 'F' or fx==7 and '-' or '|'
          txt(marker,px+S/2,py+4,1,{1,1,1,.94},'center')
        elseif cfg.mode==2 and cfg.icons then
          local sym=board.icon[y][x]
          txt(sym==1 and 'X' or sym==2 and 'O' or '+',px+S/2,py+4,1,{1,1,1,.88},'center')
        end
      end
    end
  end end
  -- Single-row rising preview. The second half of a two-row wave stays non-interactive.
  local incoming=board.incoming
  if incoming then
    for index=board.incomingIndex,2 do
      local dy=index-board.incomingIndex+1
      local py=by+h*S+(dy-1)*S-board.rise*S
      if py<=by+h*S then
        for x=1,w do
          local c=incoming.c[index][x]
          local r,gg,b=cellRGB(cfg,c,t)
          g.setColor(r,gg,b,.35)
          g.rectangle('fill',bx+(x-1)*S+1,py+1,S-2,S-2)
        end
      end
    end
  end
  if cfg.mode~=3 then
    local yy=by+board.sweep*S
    g.setColor(.23,.94,1,.14);g.rectangle('fill',bx-6,yy-9,w*S+12,18)
    g.setColor(.48,.93,1,.9);g.rectangle('fill',bx-9,yy-1,w*S+18,2)
    g.setColor(1,1,1,.8);g.rectangle('fill',bx-5,yy,w*S+10,1)
    if board.freeze>0 then txt('HOLD',bx+w*S/2,yy-11,1,{.7,1,1},'center') end
  end
  local cursorX=bx+(board.cx-1)*S
  local cursorY=by+(board.cy-1-board.rise)*S
  local ch=cfg.mode==3 and S or S*2
  g.setColor(.47,.95,1,.10);g.rectangle('fill',cursorX-2,cursorY-2,S*2+4,ch+4)
  g.setLineWidth(2);g.setColor(.98,.98,.99,1)
  g.rectangle('line',cursorX-2,cursorY-2,S*2+4,ch+4)
  g.setLineWidth(1)
  for _,p in ipairs(board.shocks) do
    local c=max(1,p.colour)
    local r,gg,b=cellRGB(cfg,c,t)
    g.setColor(r,gg,b,max(0,p.life)*.68)
    g.circle('line',bx+(p.x-.5)*S,by+(p.y-.5-board.rise)*S,p.size*S)
  end
  for _,p in ipairs(board.trails) do
    g.setColor(.5,1,1,p.life*.26)
    if p.horizontal then
      local py=by+(p.y-.5-board.rise)*S
      g.rectangle('fill',bx,py-8,w*S,16)
    else
      local px=bx+(p.x-.5)*S
      g.rectangle('fill',px-8,by,16,h*S)
    end
  end
  for _,p in ipairs(board.particles) do
    local c=max(1,p.colour)
    local r,gg,b=cellRGB(cfg,c,t)
    g.setColor(r,gg,b,min(1,p.life*1.7))
    g.rectangle('fill',bx+(p.x-.5)*S,by+(p.y-.5-board.rise)*S,2,2)
  end
  g.setColor(.38,.88,1,1)
  for i=0,4 do
    local xx=bx+i*(w*S/4)
    g.line(xx,by-8,xx,by-5);g.line(xx,by+h*S+5,xx,by+h*S+8)
  end
  return bx,by
end
function R:hud(board,cfg,game)
  local w,h=board.w,board.h
  local bx=self.bx;local right=bx+w*15+15
  local mode={'SHINE','LINK','ATTACK','BRIDGE'}
  txt('CHROMATIC',12,8,2,{.42,.9,1})
  txt('TIDE',12,23,2,{.96,.72,1})
  txt(mode[cfg.mode],LW-14,15,2,{1,1,1},'right')
  local lX=12
  txt('SCORE',lX,73,2,{.4,.78,.99})
  txt(tostring(board.score),lX,89,2,{1,1,1})
  txt('CLEARED',lX,119,1,{.57,.74,.81})
  txt(tostring(board.cleared),lX,131,2,{.91,1,1})
  txt('CHAIN',lX,161,1,{.57,.74,.81})
  txt('x'..board.chain,lX,173,2,{1,.84,.65})
  txt('ROWS',lX,206,1,{.57,.74,.81})
  txt(tostring(board.rowsRaised),lX,218,2,{.91,1,1})
  txt('PALETTE',lX,254,1,{.57,.74,.81})
  local pn=P.names[cfg.palette]:sub(1,15)
  txt(pn,lX,266,1,{.90,.95,1})
  local rx=right
  txt('MODE RULES',rx,75,1,{.41,.86,1})
  local lines = cfg.mode==1 and {'SOLID 2X2','COLOUR SQUARES','SWEEP CLEAR'} or cfg.mode==2 and {'ORTHOGONAL LINK','MIN '..cfg.minGroup..' CELLS','SWEEP CLEAR'} or cfg.mode==3 and {'3+ IN A LINE','HORIZ OR VERT','GRAVITY CLEAR'} or {'TOUCH BOTH','SIDE WALLS','SWEEP CLEAR'}
  for i,s in ipairs(lines) do txt(s,rx,93+(i-1)*15,1,{.82,.90,.95}) end
  if cfg.mode==2 then txt(cfg.icons and 'ICONS: ON' or 'ICONS: OFF',rx,151,1,{.7,1,.8}) end
  txt('NEXT WAVE',rx,196,1,{.41,.86,1})
  local wave=board.incoming
  if wave then for y=1,2 do for x=1,min(8,board.w) do
    local c=wave.c[y][x];local r,gg,b=cellRGB(cfg,c,board.time)
    g.setColor(r,gg,b,y>=board.incomingIndex and .9 or .2)
    g.rectangle('fill',rx+(x-1)*10,211+(y-1)*11,9,9)
  end end end
  txt('LÖVE 11.5',rx,285,1,{.45,.69,.79})
  txt('FPS '..love.timer.getFPS(),rx,302,1,{.45,.69,.79})
  txt('Q '..self.quality,rx,315,1,{.45,.69,.79})
  txt('B MODE  O OPT',12,354,1,{.57,.74,.81})
  txt('Z/X ACT  P PAUSE',380,354,1,{.57,.74,.81})
  if board.flash>0 then
    rect(bx,45,board.w*15,board.h*15,{.68,.91,1,board.flash*.22})
  end
  for _,p in ipairs(board.popups) do
    local x=bx+(p.x-.5)*15;local y=45+(p.y-.5-board.rise)*15
    local width=F.width(p.text,1)
    rect(x-width/2-4,y-3,width+8,13,{.03,.08,.13,.48})
    txt(p.text,x,y,1,{p.r,p.g,p.b,min(1,p.life/.38)},'center')
  end
end
function R:drawTouch()
  local buttons={
    {27,386,33,38,'<','left'},{64,386,33,38,'>','right'},
    {101,386,33,18,'^','up'},{101,406,33,18,'V','down'},
    {415,386,53,38,'CCW','ccw'}, {474,386,53,38,'CW','cw'},
    {534,386,86,38,'BOOST','boost'}
  }
  for _,v in ipairs(buttons) do
    rect(v[1],v[2],v[3],v[4],{.05,.14,.23,.9})
    rect(v[1],v[2],v[3],v[4],{.38,.90,1,.63},true)
    txt(v[5],v[1]+v[3]/2,v[2]+v[4]/2-4,1,{.9,1,1},'center')
  end
end
function R:menu(state,cfg,ui)
  rect(36,51,568,333,{.02,.06,.10,.92})
  rect(36,51,568,333,{.25,.80,.95,.55},true)
  if state=='mode' then
    txt('SELECT GAME MODE',LW/2,65,3,{.77,.98,1},'center')
    local names={'SHINE','LINK','ATTACK','BRIDGE'}
    local notes={'2X2 COLOUR SQUARES','CONNECTED COLOUR GROUPS','SWAP / MATCH THREE','CONNECT THE SIDE WALLS'}
    for k=1,4 do
      local yy=111+(k-1)*61
      local selected=ui.mode==k
      rect(57,yy,526,53,selected and {.11,.29,.39,.92} or {.05,.12,.18,.9})
      rect(57,yy,526,53,{selected and .69 or .23,selected and .99 or .55,1,selected and .85 or .28},true)
      txt(k..'  '..names[k],71,yy+8,2,{selected and 1 or .65,selected and 1 or .84,1})
      txt(notes[k],92,yy+30,1,{.62,.78,.86})
    end
    txt('DPAD SELECT    A START    Y OPTIONS',LW/2,399,1,{.71,.81,.85},'center')
  elseif state=='options' then
    local page=ui.page
    local title=ui.pageNames[page]
    txt('OPTIONS / '..title,LW/2,62,2,{.72,.98,1},'center')
    local rows=ui.pages[page]
    for i,row in ipairs(rows) do
      local y=101+(i-1)*37
      local sel=ui.selected==i
      rect(55,y,533,31,sel and {.12,.29,.39,.86} or {.05,.11,.16,.7})
      if sel then rect(55,y,533,31,{.4,.94,1,.71},true) end
      txt(row.label,65,y+10,1,{.72,.91,.96})
      txt(ui.optionText(row,cfg),576,y+9,1,{1,.98,.82},'right')
    end
    txt('< / > ADJUST   L/R PAGE   A APPLY   B BACK',LW/2,397,1,{.69,.87,.94},'center')
  elseif state=='help' then
    txt('HOW TO PLAY',LW/2,65,3,{.8,1,1},'center')
    local help={'MOVE: DPAD OR ARROW KEYS','SHINE: ROTATE 2X2 / SOLID SQUARES','LINK: ROTATE 2X2 / CONNECT COLOURS','ATTACK: SWAP 2 CELLS / MATCH 3','BRIDGE: CONNECT LEFT TO RIGHT','A: CLOCKWISE OR SWAP','B: COUNTERCLOCKWISE','X: SPEED UP RISING ROWS','Y: PAUSE   START: SELECT','RARE POWERS: BOMBS / FREEZE / BEAMS','PASSIVE RISING DOES NOT SCORE','PRESS B TO RETURN'}
    for i,s in ipairs(help) do txt(s,72,109+(i-1)*21,1,{.8,.9,.99}) end
  elseif state=='pause' or state=='gameover' then
    txt(state=='pause' and 'PAUSED' or 'GAME OVER',LW/2,105,3,{1,.84,.95},'center')
    txt('SCORE '..ui.board.score,LW/2,165,2,{.75,.99,1},'center')
    txt('A RESUME / RESTART',LW/2,245,1,{1,1,1},'center')
    txt('B SELECT MODE',LW/2,269,1,{.7,.82,.92},'center')
  end
end
function R:computeBloom()
  if not (self.threshold and self.blur) then return end
  g.setCanvas(self.a);g.clear(0,0,0,0);g.setShader(self.threshold);g.setColor(1,1,1,1)
  g.draw(self.scene,0,0,0,self.bloomW/LW,self.bloomH/LH)
  g.setShader(self.blur);self.blur:send('direction',{1/self.bloomW,0})
  g.setCanvas(self.b);g.clear(0,0,0,0);g.draw(self.a)
  self.blur:send('direction',{0,1/self.bloomH})
  g.setCanvas(self.a);g.clear(0,0,0,0);g.draw(self.b)
  g.setShader();g.setCanvas()
  self.blurNeedsUpdate=false
end
function R:draw(ui)
  local cfg,board=ui.cfg,ui.board;self.frame=self.frame+1
  g.setCanvas(self.scene)
  self:background(board.time)
  if ui.state=='play' or ui.state=='pause' or ui.state=='gameover' or ui.state=='help' then
    self:board(board,cfg,board.time);self:hud(board,cfg,ui)
    if ui.touch then self:drawTouch() end
  end
  if ui.state~='play' then self:menu(ui.state,cfg,ui) end
  g.setCanvas()
  if cfg.bloom and self.threshold and self.blur then
    local every=self.quality==3 and 2 or self.quality==2 and 3 or 5
    if self.frame%every==0 or self.blurNeedsUpdate then self:computeBloom() end
  end
  local ww,hh=g.getDimensions();local scale=min(ww/LW,hh/LH)
  local ox=(ww-LW*scale)/2;local oy=(hh-LH*scale)/2
  self.scale,self.ox,self.oy=scale,ox,oy
  g.clear(.008,.012,.028,1)
  g.setColor(1,1,1,1);g.draw(self.scene,ox,oy,0,scale,scale)
  if cfg.bloom and self.threshold and self.blur then
    g.setBlendMode('add','alphamultiply')
    g.setColor(.75,.93,1,self.quality==1 and .55 or .8)
    g.draw(self.a,ox,oy,0,scale*LW/self.bloomW,scale*LH/self.bloomH)
    g.setBlendMode('alpha','alphamultiply')
  end
end
function R:point(x,y)
  return (x-(self.ox or 0))/(self.scale or 1),(y-(self.oy or 0))/(self.scale or 1)
end
return R
