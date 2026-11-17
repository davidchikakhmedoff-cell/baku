float alpha = 0.5;

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
    return float4(0.0, 0.0, 0.0, saturate(alpha));
}

technique TexReplace
{
    pass P0
    {
        AlphaBlendEnable = TRUE;
        SrcBlend = SRCALPHA;
        DestBlend = INVSRCALPHA;
        AlphaTestEnable = FALSE;
        ZWriteEnable = FALSE;
        VertexShader = compile vs_2_0 VS();
        PixelShader = compile ps_2_0 PS();
    }
}

technique fallback
{
    pass P0
    {
    }
}
