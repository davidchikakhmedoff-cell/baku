texture gTexture < string textureState = "0,Texture"; >;
float gAlpha = 0.0;

sampler TextureSampler = sampler_state
{
    Texture = (gTexture);
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
};

struct VSInput
{
    float3 Position : POSITION0;
    float4 Color : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

struct VSOutput
{
    float4 Position : POSITION0;
    float4 Color : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

float4x4 gWorldViewProjection : WORLDVIEWPROJECTION;

VSOutput VS(VSInput input)
{
    VSOutput output;
    output.Position = mul(float4(input.Position, 1.0), gWorldViewProjection);
    output.Color = input.Color;
    output.TexCoord = input.TexCoord;
    return output;
}

float4 PS(VSOutput input) : COLOR0
{
    float4 color = tex2D(TextureSampler, input.TexCoord) * input.Color;
    float alpha = saturate(gAlpha);
    color.rgb = lerp(color.rgb, float3(0.0, 0.0, 0.0), alpha);
    return saturate(color);
}

technique TonerPercent
{
    pass P0
    {
        VertexShader = compile vs_2_0 VS();
        PixelShader = compile ps_2_0 PS();
    }
}

technique fallback
{
    pass P0
    {
        Texture[0] = gTexture;
    }
}
