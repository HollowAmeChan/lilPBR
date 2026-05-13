#ifndef INCLUDED_PBR_SHADINGS
#define INCLUDED_PBR_SHADINGS

#pragma warning(disable: 4008)

#ifdef _PARALLAXMODE_PIXEL
#if defined(SHADER_API_D3D11)
    #define DEPTH_OUT , out float depth : SV_DepthLessEqual
    #define POS_INTERPOLATION linear noperspective sample
#else
    #define DEPTH_OUT , out float depth : SV_Depth
    #define POS_INTERPOLATION linear noperspective sample
#endif
#else
    #define DEPTH_OUT
    static float depth = 0;
    #define POS_INTERPOLATION
#endif

struct ShadingParams
{
    half3 albedo;
    half3 albedoback;
    half alpha;
    float2 uv[4];
    float3 posWorld;
    float3 posWorldOrig;
    half3 T;
    half3 B;
    half3 N;
    half3 bentN;
    half3 V;
    half3 refN;
    half3 origN;
    half metallic;
    half occlusion;
    half smoothness;
    half perceptualRoughness;
    half roughness;
    half reflectance;
    half3 specular;
    bool isAnisotropy;
    half anisotropy;
    half3 emission;
    half subsurfaceThickness;
    half3 subsurfaceColor;
    half ssaoMask;
    half3 oneMinusReflectionStrength;
};

float3 lilBlendColor(float3 dstCol, float3 srcCol, float3 srcA, uint blendMode)
{
    float3 ad = dstCol + srcCol;
    float3 mu = dstCol * srcCol;
    float3 outCol;
    if(blendMode == 0) outCol = srcCol;               // Normal
    if(blendMode == 1) outCol = ad;                   // Add
    if(blendMode == 2) outCol = max(ad - mu, dstCol); // Screen
    if(blendMode == 3) outCol = mu;                   // Multiply
    return lerp(dstCol, outCol, srcA);
}

half3 Ortho(half3 tangent, half3 normal)
{
    return tangent - normal * dot(normal, tangent);
}

half3 OrthoNormalize(half3 tangent, half3 normal)
{
    return normalize(tangent - normal * dot(normal, tangent));
}

float UVDensity(float3 posWorld, float2 dx, float2 dy)
{
    float3 dxp = ddx(posWorld);
    float3 dyp = ddy(posWorld);
    return sqrt(dot(dx,dx)+dot(dy,dy)) * rsqrt(dot(dxp,dxp)+dot(dyp,dyp));
}

float2 RotateVector2(float2 vec, float angle)
{
    float si, co;
    sincos(angle, si, co);
    return float2(
        vec.x * co - vec.y * si,
        vec.x * si + vec.y * co
    );
}

float3 RotateVector3(float3 vec, float3 axs, float angle)
{
    float si, co;
    sincos(angle, si, co);
    float t = 1-co;
    float3x3 m = float3x3(
        t * axs.x * axs.x + co,          t * axs.x * axs.y - si * axs.z,  t * axs.x * axs.z + si * axs.y,
        t * axs.x * axs.y + si * axs.z,  t * axs.y * axs.y + co,          t * axs.y * axs.z - si * axs.x,
        t * axs.x * axs.z - si * axs.y,  t * axs.y * axs.z + si * axs.x,  t * axs.z * axs.z + co
    );
    return mul(vec, m);
}

float2 RotateUV(float2 uv, float angle)
{
    float si,co;
    sincos(angle, si, co);
    float2 outuv = uv - 0.5;
    outuv = float2(
        outuv.x * co - outuv.y * si,
        outuv.x * si + outuv.y * co
    );
    outuv += 0.5;
    return outuv;
}

half3x3 GetTBN(float2 uv, float3 N, float3 V, float4x4 matrixIV)
{
    half3 T2 = float3(ddx_fine(uv.x), ddy_fine(uv.x), 0);
    T2 = mul((float3x3)matrixIV, T2);
    T2 = OrthoNormalize(T2, N);
    half3 B2 = float3(ddx_fine(uv.y), ddy_fine(uv.y), 0);
    B2 = mul((float3x3)matrixIV, B2);
    B2 = OrthoNormalize(B2, N);
    half3 B = -cross(N, T2);
    half3 T = cross(N, B2);
    return half3x3(T,B,N);
}

half GetDiffuse(ShadingParams p, half3 L)
{
    half NdotL = saturate(dot(p.N,L));
    return saturate(lerp(NdotL, NdotL * NdotL, p.smoothness * 0.2 - 0.1));
}

half SpecularTerm(ShadingParams p, half3 L, half3 H, half NdotV, half NdotL, half NdotH)
{
    half roughness2 = max(p.roughness, 0.002);
    half sjggx = 0.5 / (lerp(2 * NdotL * NdotV, NdotL + NdotV, roughness2) + 1e-4f);

    half r2 = roughness2 * roughness2;
    half d = (NdotH * r2 - NdotH) * NdotH + 1.0;
    half ggx = r2 / (d * d + 1e-7f);

    return sjggx * ggx;
}

half SpecularTermAniso(ShadingParams p, half3 L, half3 H, half NdotV, half NdotL, half NdotH)
{
    half TdotH = dot(p.T, H);
    half BdotH = dot(p.B, H);
    half TdotV = abs(dot(p.T, p.V));
    half BdotV = abs(dot(p.B, p.V));
    half TdotL = abs(dot(p.T, L));
    half BdotL = abs(dot(p.B, L));

    half roughnessT = max(p.roughness * (1.0 + p.anisotropy), 0.002);
    half roughnessB = max(p.roughness * (1.0 - p.anisotropy), 0.002);
    half sjggx = 0.5 / (
        NdotL * (roughnessT * TdotV + roughnessB * BdotV + NdotV) + 
        NdotV * (roughnessT * TdotL + roughnessB * BdotL + NdotL) + 1e-4f);

    half r2 = roughnessT * roughnessB;
    half3 v = half3(TdotH * roughnessB, BdotH * roughnessT, NdotH * r2);
    half w = r2 / dot(v, v);
    half ggx = r2 * w * w;

    return sjggx * ggx;
}

half3 GetSpecular(ShadingParams p, half3 L)
{
    half3 H = normalize(p.V + L);

    half NdotV = saturate(dot(p.N, p.V));
    half NdotL = saturate(dot(p.N, L));
    half NdotH = saturate(dot(p.N, H));
    half LdotH = saturate(dot(L, H));

    half specularTerm = 0;
    #ifdef _ANISOTROPY
        if (p.isAnisotropy) specularTerm = SpecularTermAniso(p, L, H, NdotV, NdotL, NdotH);
        else
    #else
        specularTerm = SpecularTerm(p, L, H, NdotV, NdotL, NdotH);
    #endif

    if (IsGamma()) specularTerm = sqrt(max(1e-4h, specularTerm));

    half a = 1.0-LdotH;
    half3 fresnelTerm = p.specular + (1-p.specular) * a * a * a * a * a;

    return specularTerm * NdotL * fresnelTerm;
}

void DoLight(inout half3 diff, inout half3 spec, ShadingParams p, half3 L, half3 lightColor)
{
    diff += GetDiffuse(p, L) * lightColor;
    spec += GetSpecular(p, L) * lightColor;
}

half3 GetReflectionStrength(ShadingParams p, out half3 reflectionStrength)
{
    half oneMinusReflectivity = (1-p.reflectance) - (1-p.reflectance) * p.metallic;
    half grazingTerm = saturate(p.smoothness + (1.0-oneMinusReflectivity));
    half surfaceReduction = 1.0 / (p.roughness * p.roughness + 1.0);
    if (IsGamma()) surfaceReduction = 1.0 - 0.28 * p.roughness * p.perceptualRoughness;

    half NdotV = saturate(dot(p.N, p.V));
    half a = 1.0-NdotV;
    half3 fresnelLerp = lerp(p.specular, grazingTerm, a * a * a * a * a);
    reflectionStrength = surfaceReduction * fresnelLerp;
    return reflectionStrength * p.occlusion;
}

float2 lilRandom(float2 v)
{
    return frac(sin(dot(v, float2(12.9898,78.233))) * float2(46203.4357, 21091.5327));
}

// IbukiHash
// https://andantesoft.hatenablog.com/entry/2024/12/19/193517
half ibuki(uint4 v)
{
    v.zw = 0;
    const uint4 mult = 
        uint4(0xae3cc725, 0x9fe72885, 0xae36bfb5, 0x82c1fcad);

    uint4 u = uint4(v);
    u = u * mult;
    u ^= u.wxyz ^ u >> 13;
    
    uint r = dot(u, mult);

    r ^= r >> 11;
    r = (r * r) ^ r;
        
    return r * 2.3283064365386962890625e-10;
}

float rawDistance(float3 a, float3 b)
{
    return dot(a-b,a-b);
}
#endif
