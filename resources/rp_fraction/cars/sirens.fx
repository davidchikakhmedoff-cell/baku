// Only rp_pd_els_* textures use this shader. The mask stores lamp ID in R,
// original light intensity in G and the original texture alpha in A.
texture gTexture0 < string textureState="0,Texture"; >;
texture lightPalette;
float lampBrightness=4;
float lampOpacity=1.8;
sampler MaskSampler=sampler_state { Texture=<gTexture0>; };
sampler PaletteSampler=sampler_state { Texture=<lightPalette>; MinFilter=Point; MagFilter=Point; MipFilter=None; AddressU=Clamp; AddressV=Clamp; };
float4 lightPixel(float2 uv:TEXCOORD0):COLOR0
{
 float4 mask=tex2D(MaskSampler,uv);
 float id=floor(mask.r*255.0+0.5);
 float4 lamp=tex2D(PaletteSampler,float2((id+0.5)/64.0,0.5));
 return float4(lamp.rgb*mask.g*lampBrightness,saturate(lamp.a*lampOpacity)*mask.a);
}
technique SirenMaterials
{
 pass P0
 {
  AlphaBlendEnable=true;
  SrcBlend=SrcAlpha;
  DestBlend=InvSrcAlpha;
  AlphaTestEnable=false;
  ZWriteEnable=false;
  PixelShader=compile ps_2_0 lightPixel();
 }
}
