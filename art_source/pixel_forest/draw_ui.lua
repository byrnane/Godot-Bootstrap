-- Forest Keeper UI, static 16x16 cells. Run on a fresh 16x16 RGB sprite.
-- Frames are independent assets, named by single-frame tags. 9-slice margin: 4.
local sprite = sprite or app.activeSprite
assert(sprite, "Open a fresh 16x16 RGB sprite before running this script")
local function color(hex)
  return app.pixelColor.rgba(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16),255)
end
local p={ink=color('101522'),base=color('1b2535'),slate=color('28394a'),edge=color('345366'),light=color('437476'),moss=color('3e6655'),leaf=color('689468'),pale=color('a5b978'),wood=color('7a513e'),amber=color('ae7650'),gold=color('d6a35b'),sun=color('f5ce78'),cream=color('fff0b0')}
local names={'ui_panel','ui_button_normal','ui_button_hover','ui_button_pressed','ui_button_disabled','ui_button_focus','ui_button_primary','ui_pause','ui_settings','ui_save','ui_back'}
local im
local function pixel(x,y,c) im:drawPixel(x,y,c) end
local function rect(x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do pixel(xx,yy,c) end end end
local function shell(body,rail,lit,shadow)
  rect(2,0,12,16,p.ink); rect(1,1,14,14,p.ink); rect(0,2,16,12,p.ink)
  rect(2,1,12,14,rail); rect(1,2,14,12,rail)
  rect(3,2,10,12,shadow); rect(2,3,12,10,shadow)
  rect(3,3,10,10,body)
  rect(3,1,9,1,lit); rect(1,3,1,7,lit)
end
local function icon(rows)
  local colors={['#']=p.ink,a=p.amber,g=p.gold,s=p.sun,c=p.cream,m=p.moss,l=p.leaf,b=p.base,e=p.edge}
  for y,row in ipairs(rows) do for x=1,#row do local c=colors[row:sub(x,x)]; if c then pixel(x-1,y-1,c) end end end
end
for i,name in ipairs(names) do
  if i>1 then sprite:newEmptyFrame(i) end
  im=Image(16,16,ColorMode.RGB)
  if name=='ui_panel' then
    shell(p.base,p.edge,p.light,p.slate)
    rect(4,2,6,1,p.edge); rect(2,4,1,4,p.edge)
    pixel(2,2,p.amber); pixel(13,2,p.wood); pixel(2,13,p.wood); pixel(13,13,p.wood)
  elseif name=='ui_button_normal' then
    shell(p.base,p.wood,p.amber,p.slate)
    rect(4,2,5,1,p.edge); pixel(2,2,p.gold); pixel(13,2,p.amber)
    rect(3,14,10,1,p.wood)
  elseif name=='ui_button_hover' then
    shell(p.slate,p.amber,p.sun,p.edge)
    rect(4,2,6,1,p.light); pixel(2,2,p.cream); pixel(13,2,p.gold)
    rect(3,14,10,1,p.wood)
  elseif name=='ui_button_pressed' then
    shell(p.base,p.wood,p.wood,p.ink)
    rect(3,3,10,1,p.slate); rect(3,13,10,1,p.amber); rect(4,14,8,1,p.gold)
    pixel(2,13,p.gold); pixel(13,13,p.amber)
  elseif name=='ui_button_disabled' then
    shell(p.base,p.slate,p.edge,p.base)
    rect(4,2,5,1,p.slate)
  elseif name=='ui_button_focus' then
    rect(2,0,12,1,p.sun); rect(2,15,12,1,p.gold)
    rect(0,2,1,12,p.sun); rect(15,2,1,12,p.gold)
    pixel(1,1,p.sun); pixel(14,1,p.sun); pixel(1,14,p.gold); pixel(14,14,p.gold)
    pixel(2,0,p.cream); pixel(0,2,p.cream)
  elseif name=='ui_button_primary' then
    shell(p.wood,p.amber,p.sun,p.wood)
    rect(3,3,10,10,p.wood); rect(3,2,10,1,p.amber)
    pixel(2,2,p.cream); pixel(13,2,p.gold); rect(3,14,10,1,p.wood)
  elseif name=='ui_pause' then
    icon({'................','................','..####...####...','..#ss#...#ss#...','..#sg#...#sg#...','..#gg#...#gg#...','..#gg#...#gg#...','..#gg#...#gg#...','..#gg#...#gg#...','..#gg#...#gg#...','..#gg#...#gg#...','..#aa#...#aa#...','..####...####...','................','................','................'})
  elseif name=='ui_settings' then
    rect(4,3,8,10,p.ink); rect(3,4,10,8,p.ink)
    rect(6,1,4,4,p.ink); rect(6,11,4,4,p.ink); rect(1,6,4,4,p.ink); rect(11,6,4,4,p.ink)
    rect(3,3,3,3,p.ink); rect(10,3,3,3,p.ink); rect(3,10,3,3,p.ink); rect(10,10,3,3,p.ink)
    rect(5,4,6,8,p.gold); rect(4,5,8,6,p.gold)
    rect(7,2,2,4,p.sun); rect(7,10,2,4,p.amber); rect(2,7,4,2,p.sun); rect(10,7,4,2,p.amber)
    rect(4,4,2,2,p.sun); rect(10,4,2,2,p.gold); rect(4,10,2,2,p.gold); rect(10,10,2,2,p.amber)
    rect(6,6,4,4,p.ink); rect(7,7,2,2,0)
  elseif name=='ui_save' then
    icon({'................','................','...#########....','..#ssbbbbgsa#...','..#ggbggbggga#..','..#ggbggbggga#..','..#ggbbbbggga#..','..#ggggggggga#..','..#gg#####gga#..','..#gg#sss#gga#..','..#gg#ggg#gga#..','..#gg#ggg#gga#..','..#aa#aaa#aaa#..','...##########...','................','................'})
  elseif name=='ui_back' then
    icon({'................','................','......##........','.....#ss#.......','....#ss#........','...#ss########..','..#sssggggggga#.','.#ssggggggggga#.','..#aagggggggga#.','...#aa########..','....#aa#........','.....#aa#.......','......##........','................','................','................'})
  end
  sprite:newCel(sprite.layers[1],i,im,Point(0,0))
  local tag=sprite:newTag(i,i); tag.name=name
  sprite.frames[i].duration=0.1
end
-- Adding frames extends existing tags; restore their independent static ranges.
for i,tag in ipairs(sprite.tags) do tag.fromFrame=sprite.frames[i]; tag.toFrame=sprite.frames[i] end
sprite.layers[1].name='Pixel UI; frames are separate static assets'
local palette=Palette(14)
palette:setColor(0,Color{r=0,g=0,b=0,a=0})
local entries={'ink','base','slate','edge','light','moss','leaf','pale','wood','amber','gold','sun','cream'}
for i,key in ipairs(entries) do local c=p[key]; palette:setColor(i,Color{r=app.pixelColor.rgbaR(c),g=app.pixelColor.rgbaG(c),b=app.pixelColor.rgbaB(c),a=255}) end
sprite:setPalette(palette)
