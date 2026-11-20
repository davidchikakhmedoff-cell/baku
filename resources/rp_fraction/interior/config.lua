-- Object position is the DFF origin, not the player spawn. Keep both aligned
-- with the hospital's indoor points in fleet_config.lua.
HospitalInteriorConfig={
 baseModel=1337, -- Clone a model slot; never replace the base model on the map.
 origin={x=1500,y=1500,z=1200},
 txd='interior/hospital_lae.txd',
 dff='interior/laehospital1.dff',
 col='interior/laehospital1.col', -- Only the hospital entry, not all 41 archive models.
 lodDistance=200,
 -- Local coordinates in the hospital DFF. A solid wall behind the existing
 -- front door frame closes the void; the exit marker stays inside the lobby.
 exitBarrier={
  dff='interior/exit_barrier.dff',col='interior/exit_barrier.col',
  offset={x=-20.7,y=2.4,z=-15.5}
 }
}
