FractionSirenPatterns={}
local P=FractionSirenPatterns
function P.compile(config,state)
 local result={}
 for key,entry in pairs(config.states and config.states[state] or {}) do
  local id=tonumber(key);local color=entry.color
  if type(color)=='string' then color=config.references and config.references.colors and config.references.colors[color] end
  if id and id%1==0 and id>=1 and id<=63 and type(color)=='table' then
   local durations,total={},0
   for _,ms in ipairs(entry.pattern or {}) do
    if type(ms)=='number' and ms>0 then durations[#durations+1]=ms;total=total+ms end
   end
   result[id]={color={color.red or 255,color.green or 255,color.blue or 255,color.alpha or 255},
    on=entry.state==1,durations=durations,total=total,inertia=tonumber(entry.inertia) or 0}
  end
 end
 return result
end
function P.sample(light,elapsed)
 local on=light.on
 if light.total==0 then return on and 1 or 0 end
 local cycle=math.floor(elapsed/light.total);local offset=elapsed%light.total
 if #light.durations%2==1 and cycle%2==1 then on=not on end
 for _,ms in ipairs(light.durations) do
  if offset<ms then
   -- Inertia softens the edge without changing the configured pulse durations.
   local fade=math.min(80,ms*math.max(0,math.min(1,light.inertia)))
   local blend=fade>0 and math.min(1,offset/fade) or 1
   return on and blend or (1-blend)
  end
  offset=offset-ms;on=not on
 end
 return 0
end
