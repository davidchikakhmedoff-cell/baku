-- GTA SA supplies a rotating clothes pickup (1275), but no stock key-shaped
-- pickup. Draw the key as a rotating vertical 3D material at the server colshape.
local texture=svgCreate(128,128,[[<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<circle cx="64" cy="64" r="57" fill="#131313" fill-opacity="0.8" stroke="#ffd966" stroke-width="5"/>
<circle cx="45" cy="45" r="17" fill="none" stroke="#ffd966" stroke-width="9"/>
<path d="M58 58 L91 91 M77 77 L88 66 M87 87 L98 76" fill="none" stroke="#ffd966" stroke-width="9" stroke-linecap="round"/>
</svg>]])
addEventHandler('onClientRender',root,function()
 if not texture then return end
 local x,y,z=getElementPosition(localPlayer)
 local interior,dimension=getElementInterior(localPlayer),getElementDimension(localPlayer)
 local angle=getTickCount()/1000
 for _,f in pairs(Fractions) do
  local p=f.keysPoint
  if interior==f.interior and dimension==f.dimension and (x-p.x)^2+(y-p.y)^2+(z-p.z)^2<30^2 then
   local center=p.z+0.7
   dxDrawMaterialLine3D(p.x,p.y,center+0.4,p.x,p.y,center-0.4,texture,0.8,tocolor(255,255,255,255),false,p.x+math.cos(angle),p.y+math.sin(angle),center)
  end
 end
end)
addEventHandler('onClientResourceStop',resourceRoot,function() if isElement(texture) then destroyElement(texture) end end)
