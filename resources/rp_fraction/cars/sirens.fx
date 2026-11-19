// The uploaded DFF identifies each ELS lamp by material RGB (ID,255,255).
texture gTexture0 < string textureState="0,Texture"; >;
float4 gMaterialDiffuse < string renderState="MATERIALDIFFUSE"; >;
texture lightPalette;
sampler BaseSampler=sampler_state { Texture=<gTexture0>; };
sampler PaletteSampler=sampler_state { Texture=<lightPalette>; MinFilter=Point; MagFilter=Point; MipFilter=None; AddressU=Clamp; AddressV=Clamp; };
float4 lightPixel(float2 uv:TEXCOORD0,float4 diffuse:COLOR0):COLOR0
{
 float4 base=tex2D(BaseSampler,uv)*diffuse;
 float id=floor(gMaterialDiffuse.r*255.0+0.5);
 if(gMaterialDiffuse.g>0.998 && gMaterialDiffuse.b>0.998 && id>=1 && id<=63)
 {
  float4 lamp=tex2D(PaletteSampler,float2((id+0.5)/64.0,0.5));
  float3 tex=tex2D(BaseSampler,uv).rgb;
  // Transparent diffuse materials are intentional lamp faces, not invisible lamps.
  return float4(tex*lamp.rgb*2.0, lamp.a);
 }
 return base;
}
technique SirenMaterials { pass P0 { PixelShader=compile ps_2_0 lightPixel(); } }
