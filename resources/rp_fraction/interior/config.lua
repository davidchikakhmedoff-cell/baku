-- Object position is the DFF origin, not the player spawn. Keep both aligned
-- with the hospital's indoor points in fleet_config.lua.
HospitalInteriorConfig={
 baseModel=1337, -- Clone a model slot; never replace the base model on the map.
 origin={x=1500,y=1500,z=1200},
 txd='interior/hospital_lae.txd',
 dff='interior/laehospital1.dff',
 col='interior/laehospital1.col', -- Only the hospital entry, not all 41 archive models.
 lodDistance=200
}
