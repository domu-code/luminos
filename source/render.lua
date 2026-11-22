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
  local palette=cfg.palette
  if cfg.paletteCycleSecs and cfg.paletteCycleSecs>0 then
    palette=(palette-1+floor(t/cfg.paletteCycleSecs))%#P.names+1
  end
  local r,gg,b=P.get(c,palette,cfg.colours,t,cfg.hueDrift,cfg)
  local style=cfg.renderStyle or 1
  if style==4 then
    -- True 1-bit luminance; the tile index is additionally encoded via stipple
    -- in board(), so 2-10 match identities remain visually distinguishable.
    return 1,1,1
  elseif style==3 then
    -- Quantise onto a 16-colour indexed RGBI palette (four-level R, two G, two B).
    return floor(r*3+.5)/3,floor(gg+.5),floor(b+.5)
  elseif style==2 then
    -- 8-bit RGB332 quantisation.
    return floor(r*7+.5)/7,floor(gg*7+.5)/7,floor(b*3+.5)/3
  end
  return r,gg,b
end
function R:stars(time)
  for i=1,65 do
    local x=(i*137.21)%LW;local y=(i*74.57)%LH
    local v=.13+.08*sin(time*.6+i*1.3)
    g.setColor(.24,.67,1,v)
    g.rectangle('fill',floor(x),floor(y),1,1)
  end
end
function R:background(t,cfg)
  if (cfg.renderStyle or 1)==4 then g.clear(0,0,0,1)
  elseif (cfg.renderStyle or 1)==3 then g.clear(.025,.035,.065,1)
  else g.clear(.018,.026,.060,1) end
  local horizon=320
  if (cfg.renderStyle or 1)==4 then g.setColor(1,1,1,.13) else g.setColor(.075,.25,.38,.23) end
  for i=0,max(0,floor(13*(cfg.backgroundDetail or 2)/2)) do
    local a=(i-6.5)/6.5
    g.line(LW/2,horizon, LW/2+a*LW*1.4,LH)
  end
  for i=1,max(1,floor(6*(cfg.backgroundDetail or 2)/2)) do
    local y=horizon+(i/6)^1.8*(LH-horizon)
    g.line(0,y,LW,y)
  end
  if (cfg.backgroundDetail or 2)>0 and (cfg.renderStyle or 1)~=4 then self:stars(t) end
  if (cfg.renderStyle or 1)==4 then g.setColor(1,1,1,.08)
  else g.setColor(.11,.50,.72,.10+(cfg.visualPulse or 1)*.025*(1+sin(t*2.2))) end
  for i=1,max(0,floor(5*(cfg.backgroundDetail or 2)/2)) do
    g.ellipse('line',LW/2,177,115+i*45,85+i*22)
  end
end
function R:board(board,cfg,t,view)
  local w,h=board.w,board.h
  local S=view and view.tile or 15
  local bx=view and view.x or floor((LW-w*S)/2)
  local by=view and view.y or 45
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
        local rr,gg,bb=cellRGB(cfg,c>0 and c or 1,t)
        if c<0 then rr,gg,bb=.43,.53,.65 end
        local index=(y-1)*w+x
        local charged=matched[index]
        local distance=math.abs(board.sweep-y)
        local charge=(charged and (1.2+2.3*exp(-distance*.38)) or .25)*cfg.glowPower
        if (cfg.renderStyle or 1)==1 then
          g.setColor(rr,gg,bb,.13+(charged and .18 or 0)*cfg.glowPower)
          g.rectangle('fill',px-2,py-2,S+4,S+4)
        end
        local style=cfg.renderStyle or 1
        if style==4 then
          g.setColor(.02,.02,.02,1);g.rectangle('fill',px+1,py+1,S-2,S-2)
          g.setColor(1,1,1,1)
          local pattern=((c-1)%10)+1
          for q=0,S-4,3 do for k=0,S-4,3 do
            if (q/3+k/3*pattern)%11 < pattern then
              g.rectangle('fill',px+2+q,py+2+k,2,2)
            end
          end end
          g.rectangle('line',px+.5,py+.5,S-1,S-1)
        elseif style==3 or style==2 then
          g.setColor(rr*.75,gg*.75,bb*.75,1)
          g.rectangle('fill',px+1,py+1,S-2,S-2)
          g.setColor(rr,gg,bb,1)
          g.rectangle('fill',px+3,py+3,S-6,S-6)
          g.setColor(.94,.94,.94,charged and 1 or .4)
          g.rectangle('line',px+.5,py+.5,S-1,S-1)
        else
          g.setColor(rr*.42,gg*.42,bb*.42,1)
          g.rectangle('fill',px+1,py+1,S-2,S-2)
          g.setColor(rr*.83,gg*.83,bb*.83,.8)
          g.rectangle('line',px+.5,py+.5,S-1,S-1)
          g.setColor(min(1,rr*.55+charge*.15),min(1,gg*.55+charge*.15),min(1,bb*.55+charge*.15),charged and .75 or .46)
          g.rectangle('fill',px+3,py+3,S-6,S-6)
        end
        if charged and cfg.glowPower>0 and (cfg.renderStyle or 1)==1 then
          g.setColor(rr,gg,bb,.72)
          g.rectangle('line',px-1,py-1,S+2,S+2)
          g.setColor(1,1,1,.65+sin(t*8)*.13)
          g.rectangle('line',px+2,py+2,S-4,S-4)
        end
        local fx=board.fx[y][x]
        if c<0 then
          g.setColor(.72,.81,.94,.9)
          g.line(px+2,py+2,px+S-2,py+S-2)
          g.line(px+S-2,py+2,px+2,py+S-2)
        elseif fx~=0 then
          local marker=fx<=3 and '*' or fx==4 and 'P' or fx==5 and 'R' or fx==6 and 'F' or fx==7 and '-' or fx==8 and '|' or fx==9 and '^' or fx==10 and 'g' or fx==11 and 'G' or fx==12 and '#' or '!'
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
  if (cfg.juicePower or 0)>0 then for _,p in ipairs(board.shocks) do
    local c=max(1,p.colour)
    local r,gg,b=cellRGB(cfg,c,t)
    g.setColor(r,gg,b,min(1,max(0,p.life)*.68*cfg.juicePower))
    g.circle('line',bx+(p.x-.5)*S,by+(p.y-.5-board.rise)*S,p.size*S)
  end
  end
  if (cfg.trailPower or 0)>0 then for _,p in ipairs(board.trails) do
    g.setColor(.5,1,1,p.life*.26*cfg.juicePower*(cfg.trailPower or 1))
    if p.horizontal then
      local py=by+(p.y-.5-board.rise)*S
      g.rectangle('fill',bx,py-8,w*S,16)
    else
      local px=bx+(p.x-.5)*S
      g.rectangle('fill',px-8,by,16,h*S)
    end
  end
  end
  if (cfg.particlePower or 0)>0 then for _,p in ipairs(board.particles) do
    local c=max(1,p.colour)
    local r,gg,b=cellRGB(cfg,c,t)
    g.setColor(r,gg,b,min(1,p.life*1.7*cfg.glowPower))
    g.rectangle('fill',bx+(p.x-.5)*S,by+(p.y-.5-board.rise)*S,2,2)
  end
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
  txt('LUMINE',12,8,2,{.42,.9,1})
  txt('ATTACK',12,23,2,{.96,.72,1})
  txt(mode[cfg.mode],LW-14,15,2,{1,1,1},'right')
  local lX=12
  txt('SCORE',lX,73,2,{.4,.78,.99})
  txt(tostring(board.score),lX,89,2,{1,1,1})
  txt('CLEARED',lX,119,1,{.57,.74,.81})
  txt(tostring(board.cleared),lX,131,2,{.91,1,1})
  txt('CHAIN',lX,161,1,{.57,.74,.81})
  txt('x'..board.chain,lX,173,2,{1,.84,.65})
  txt('RISK x'..string.format('%.1f',board.riskMultiplier or 1),lX,190,1,{1,.79,.37})
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
  txt('LOVE 11.5',rx,285,1,{.45,.69,.79})
  txt('FPS '..love.timer.getFPS(),rx,302,1,{.45,.69,.79})
  txt('Q '..self.quality,rx,315,1,{.45,.69,.79})
  if board.celebration>0 then
    local a=min(1,board.celebration*.65)*cfg.juicePower
    rect(bx-11,42,board.w*15+22,board.h*15+6,{.9,.47,1,min(.76,a*.35)},true)
  end
  txt('TOUCH: '..(cfg.touchMode==1 and 'DPAD' or 'RELATIVE')..'  MOUSE '..({'OFF','DIRECT','REL'})[cfg.mouseMode+1],12,354,1,{.57,.74,.81})
  txt('BOOST BUILDS RISK BONUS',405,354,1,{.57,.74,.81})
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
function R:drawTouch(ui)
  local cfg=ui.cfg
  local function button(x,y,w,h,label,hot)
    rect(x,y,w,h,hot and {.32,.19,.39,.82} or {.035,.10,.17,.81})
    rect(x,y,w,h,hot and {1,.68,.98,.9} or {.37,.9,1,.71},true)
    txt(label,x+w/2,y+h/2-4,1,{.90,.99,1},'center')
  end
  if cfg.touchMode==1 then
    -- Equal 42 x 42 buttons arranged in a proper D-pad cross.
    button(60,252,42,42,'^')
    button(18,294,42,42,'<')
    button(102,294,42,42,'>')
    button(60,336,42,42,'V')
    button(443,268,68,68,'CCW',true)
    button(518,268,68,68,'CW',true)
    button(443,359,143,57,'BOOST',ui.boost)
  else
    -- No D-pad exists in relative mode. The left side is a gesture surface.
    rect(7,363,204,51,{.025,.12,.20,.48})
    rect(7,363,204,51,{.35,.88,1,.35},true)
    txt('LEFT  DRAG TO MOVE',109,380,1,{.76,.93,1},'center')
    rect(438,62,190,140,{.06,.18,.25,.07})
    rect(438,222,190,134,{.17,.08,.22,.07})
    txt('ROTATE CW',586,128,1,{.61,1,1},'center')
    txt('ROTATE CCW',581,283,1,{1,.66,.95},'center')
    button(438,367,190,57,'BOOST',ui.boost)
  end
  button(594,7,35,30,'II')
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
    rect(57,365,526,29,{.05,.14,.22,.92})
    rect(57,365,526,29,{.31,.85,1,.54},true)
    txt('VS CPU '..(cfg.vsCPU and 'ON' or 'OFF')..'   [V TO TOGGLE]',LW/2,374,1,{cfg.vsCPU and 1 or .63,.97,1},'center')
    txt('A START   Y OPTIONS   V VS TOGGLE',LW/2,400,1,{.71,.81,.85},'center')
  elseif state=='options' then
    local page=ui.page
    local title=ui.pageNames[page]
    txt('OPTIONS / '..title,LW/2,62,2,{.72,.98,1},'center')
    local rows=ui.pages[page]
    -- Render up to seven options at a time. The selection scrolls rather than
    -- allowing the lower rows to disappear behind the footer on a phone.
    local window=7
    local first=math.max(1,math.min(ui.selected-3,math.max(1,#rows-window+1)))
    for i=first,math.min(#rows,first+window-1) do
      local row=rows[i]
      local y=101+(i-first)*37
      local sel=ui.selected==i
      rect(55,y,533,31,sel and {.12,.29,.39,.86} or {.05,.11,.16,.7})
      if sel then rect(55,y,533,31,{.4,.94,1,.71},true) end
      txt(row.label,65,y+10,1,{.72,.91,.96})
      txt(ui.optionText(row,cfg),576,y+9,1,{1,.98,.82},'right')
    end
    txt('ROW '..ui.selected..'/'..#rows..'  TOP: PREV/NEXT PAGE',LW/2,374,1,{.69,.87,.94},'center')
    txt('BACK                          APPLY',LW/2,397,1,{.69,.87,.94},'center')
  elseif state=='scores' then
    local slot=ui.presetSlot or 1
    local scores=ui.records:list(slot,ui.scoreMode,ui.scoreVS)
    local label=({'SHINE','LINK','ATTACK','BRIDGE'})[ui.scoreMode]
    txt('HIGHSCORES / PRESET '..slot,LW/2,65,2,{.72,.98,1},'center')
    txt(label..'  '..(ui.scoreVS and 'VS CPU' or 'SOLO'),LW/2,93,2,{1,.82,.55},'center')
    if #scores==0 then txt('NO RECORDED SCORES',LW/2,178,2,{.7,.85,1},'center') end
    for i,sc in ipairs(scores) do
      local line=string.format('%02d   %08d   CHAIN %d %s',i,sc.points,sc.chain,sc.won and 'WIN' or '')
      txt(line,LW/2,118+(i-1)*24,1,{.77,.96,1},'center')
    end
    txt('LEFT RIGHT MODE  UP DOWN TYPE',LW/2,368,1,{.75,.94,1},'center')
    txt('A / B BACK TO PRESETS',LW/2,396,1,{.75,.94,1},'center')
  elseif state=='help' then
    txt('HOW TO PLAY',LW/2,65,3,{.8,1,1},'center')
    local help={'MOVE: DPAD OR ARROW KEYS','SHINE: ROTATE 2X2 / SOLID SQUARES','LINK: ROTATE 2X2 / CONNECT COLOURS','ATTACK: SWAP 2 CELLS / MATCH 3','BRIDGE: CONNECT LEFT TO RIGHT','A: CLOCKWISE OR SWAP','B: COUNTERCLOCKWISE','X: SPEED UP RISING ROWS','Y: PAUSE   START: SELECT','RARE POWERS: BOMBS / FREEZE / BEAMS / SURGE / GARBAGE','PASSIVE RISING DOES NOT SCORE','PRESS B TO RETURN'}
    for i,s in ipairs(help) do txt(s,72,109+(i-1)*21,1,{.8,.9,.99}) end
  elseif state=='pause' or state=='gameover' then
    txt(state=='pause' and 'PAUSED' or 'GAME OVER',LW/2,105,3,{1,.84,.95},'center')
    if ui.vs then
      txt('WINNER: '..(ui.vs.winner or 'PENDING'),LW/2,141,2,{1,.78,.85},'center')
      txt('YOU '..ui.board.score..'   CPU '..ui.vs.board.score,LW/2,170,2,{.75,.99,1},'center')
    else txt('SCORE '..ui.board.score,LW/2,165,2,{.75,.99,1},'center') end
    txt('A RESUME / RESTART',LW/2,245,1,{1,1,1},'center')
    txt('B SELECT MODE',LW/2,269,1,{.7,.82,.92},'center')
  end
end
function R:vsHud(ui)
  local cfg=ui.cfg;local a=ui.board;local b=ui.vs.board
  txt('LUMINE ATTACK / VS',LW/2,6,2,{.51,.94,1},'center')
  txt('YOU',120,40,2,{.6,1,1},'center')
  txt('CPU',LW-120,40,2,{1,.6,.82},'center')
  txt('SCORE '..a.score,120,70,1,{1,1,1},'center')
  txt('SCORE '..b.score,LW-120,70,1,{1,1,1},'center')
  txt('CHAIN x'..a.chain,120,91,1,{.9,.9,1},'center')
  txt('CHAIN x'..b.chain,LW-120,91,1,{1,.9,.9},'center')
  txt('GARBAGE '..a.pendingGarbage,120,109,1,{1,.6,.8},'center')
  txt('GARBAGE '..b.pendingGarbage,LW-120,109,1,{1,.6,.8},'center')
  txt('RISK x'..string.format('%.1f',a.riskMultiplier),120,134,1,{1,.8,.55},'center')
  txt('ACTIONS '..ui.vs.ticks,LW-120,134,1,{1,.8,.55},'center')
  txt('BOOST  '..string.format('%.1f',a.boostCharge),120,155,1,{.6,1,.8},'center')
  txt('ROW '..a.rowsRaised..' / '..b.rowsRaised,LW/2,385,1,{.75,.9,1},'center')
  if a.celebration>0 then
    txt('HYPER CHAIN x'..a.chain,250,21,2,{1,.8,.96},'center')
  end
  if b.celebration>0 then
    txt('CPU CHAIN x'..b.chain,400,21,1,{1,.65,.75},'center')
  end
  for _,entry in ipairs({{a,200},{b,355}}) do
    local board,ox=entry[1],entry[2]
    for _,v in ipairs(board.popups) do
      local xx=ox+(v.x-.5)*12;local yy=67+(v.y-.5-board.rise)*12
      txt(v.text,xx,yy,1,{v.r,v.g,v.b,math.min(1,v.life/.38)},'center')
    end
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
  self:background(board.time,cfg)
  if ui.state=='play' or ui.state=='pause' or ui.state=='gameover' or ui.state=='help' then
    if ui.vs then
      local tile=12
      self:board(board,cfg,board.time,{x=198,y=68,tile=tile})
      self:board(ui.vs.board,cfg,ui.vs.board.time,{x=354,y=68,tile=tile})
      self:vsHud(ui)
    else self:board(board,cfg,board.time);self:hud(board,cfg,ui) end
    if ui.touch and ui.state=='play' then self:drawTouch(ui) end
  end
  if ui.state~='play' then self:menu(ui.state,cfg,ui) end
  g.setCanvas()
  if cfg.bloom and cfg.glowPower>0 and cfg.bloomIntensity>0 and self.threshold and self.blur then
    local every=self.quality==3 and 2 or self.quality==2 and 3 or 5
    if self.frame%every==0 or self.blurNeedsUpdate then self:computeBloom() end
  end
  local ww,hh=g.getDimensions();local scale=min(ww/LW,hh/LH)
  local ox=(ww-LW*scale)/2;local oy=(hh-LH*scale)/2
  local shake=0
  if board.celebration>0 and cfg.shakePower>0 then
    shake=board.flash*cfg.shakePower*2*(cfg.flashPower or 1)
  end
  if shake>0 then
    ox=ox+(math.random()-.5)*shake*scale
    oy=oy+(math.random()-.5)*shake*scale
  end
  self.scale,self.ox,self.oy=scale,ox,oy
  g.clear(.008,.012,.028,1)
  g.setColor(1,1,1,1);g.draw(self.scene,ox,oy,0,scale,scale)
  if cfg.bloom and cfg.glowPower>0 and cfg.bloomIntensity>0 and self.threshold and self.blur then
    g.setBlendMode('add','alphamultiply')
    g.setColor(.75,.93,1,min(1.9,(self.quality==1 and .5 or .8)*cfg.glowPower*(cfg.bloomIntensity or 1)))
    g.draw(self.a,ox,oy,0,scale*LW/self.bloomW,scale*LH/self.bloomH)
    g.setBlendMode('alpha','alphamultiply')
  end
end
function R:point(x,y)
  return (x-(self.ox or 0))/(self.scale or 1),(y-(self.oy or 0))/(self.scale or 1)
end
return R