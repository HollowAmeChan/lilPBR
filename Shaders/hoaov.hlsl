#ifndef INCLUDED_LILPBR_HOAOV
#define INCLUDED_LILPBR_HOAOV

float _HoAovMaskWeight;
float _lilHoAovSystemChannelMask;
float _HoAovSystemWriteMask;
float _HoAovCustomWriteMask;
float _HoAovGroupId;
float _HoAovObjectId;
float _HoAovMaterialClass;
float _HoAovFlags;
float _HoAovThickness;
float _HoAovCurvature;
float _HoAovUtility;
float4 _HoAovCustomValues0;
float4 _HoAovCustomValues1;
float4 _HoAovCustomValues2;

struct HoAovOutput
{
    half4 maskId : SV_Target0;
    half4 normalDepth : SV_Target1;
    half4 tangentNormal : SV_Target2;
    half4 surfaceData : SV_Target3;
    half4 custom0 : SV_Target4;
    half4 custom1 : SV_Target5;
    half4 custom2 : SV_Target6;
};

float HoAovHasBit(float value, float bitValue)
{
    return step(0.5, fmod(floor(value / bitValue), 2.0));
}

float HoAovHasSystemChannel(float bitValue)
{
    return HoAovHasBit(_HoAovSystemWriteMask, bitValue);
}

float HoAovEncodeScalar(float value)
{
    return frac(abs(value) * 0.61803398875);
}

float HoAovGetObjectId()
{
    float3 objectPositionWS = TransformObjectToWorld(float3(0.0, 0.0, 0.0));
    float objectSeed = dot(objectPositionWS, float3(0.13, 0.31, 0.73)) * 1000.0;
    return lerp(objectSeed, _HoAovObjectId, step(0.5, abs(_HoAovObjectId)));
}

float4 HoAovApplyCustomWriteMask(float4 values, float startBit)
{
    return float4(
        values.x * HoAovHasBit(_HoAovCustomWriteMask, exp2(startBit)),
        values.y * HoAovHasBit(_HoAovCustomWriteMask, exp2(startBit + 1.0)),
        values.z * HoAovHasBit(_HoAovCustomWriteMask, exp2(startBit + 2.0)),
        values.w * HoAovHasBit(_HoAovCustomWriteMask, exp2(startBit + 3.0)));
}

half3 HoAovGetNormal(v2f i, bool isFront, out half3 normalTS)
{
    half3 tangent = normalize(i.tangent.xyz);
    half3 binormal = normalize(i.binormal.xyz);
    half3 normal = normalize(i.normal.xyz);
    normalTS = half3(0.0, 0.0, 1.0);
    if(!isFront)
    {
        tangent = -tangent;
        binormal = -binormal;
        normal = -normal;
    }

    half3x3 matrixTBN = half3x3(tangent, binormal, normal);
    float2 uv_MainTex = i.uv01.xy * _MainTex_ST.xy + _MainTex_ST.zw;
    float2 dx = ddx(uv_MainTex);
    float2 dy = ddy(uv_MainTex);

    #ifdef _NORMALMAP
        half4 bumpmap = Sample(_BumpMap, sampler_MainTex, uv_MainTex, dx, dy);
        normalTS = normalize(UnpackScaleNormal(bumpmap, _BumpScale));
        return normalize(mul(normalTS, matrixTBN));
    #else
        return normal;
    #endif
}

HoAovOutput HoAovFrag(v2f i, bool isFront, inout float depth)
{
    UnpackAndShadingAlpha(i, i.normal, i.tangent, i.binormal, i.color, i.V, i.uv01, i.uv23, isFront, depth);

    float maskEnabled = HoAovHasSystemChannel(1.0);
    float idEnabled = HoAovHasSystemChannel(2.0);
    float flagsEnabled = HoAovHasSystemChannel(4.0);
    float worldNormalEnabled = HoAovHasSystemChannel(16.0);
    float tangentNormalEnabled = HoAovHasSystemChannel(64.0);
    float thicknessEnabled = HoAovHasSystemChannel(256.0);
    float curvatureEnabled = HoAovHasSystemChannel(512.0);
    float materialEnabled = HoAovHasSystemChannel(1024.0);
    float utilityEnabled = HoAovHasSystemChannel(2048.0);

    float linearDepth = LinearEyeDepth(i.pos.z, _ZBufferParams);
    half3 normalTS;
    half3 normalWS = HoAovGetNormal(i, isFront, normalTS);

    HoAovOutput output;
    output.maskId = half4(
        saturate(_HoAovMaskWeight) * maskEnabled,
        HoAovEncodeScalar(_HoAovGroupId) * idEnabled,
        HoAovEncodeScalar(HoAovGetObjectId()) * idEnabled,
        HoAovEncodeScalar(_HoAovFlags) * flagsEnabled);
    output.normalDepth = half4((normalize(normalWS) * 0.5 + 0.5) * worldNormalEnabled, linearDepth);
    output.tangentNormal = half4((normalize(normalTS) * 0.5 + 0.5) * tangentNormalEnabled, tangentNormalEnabled);
    output.surfaceData = half4(
        saturate(_HoAovThickness) * thicknessEnabled,
        saturate(abs(_HoAovCurvature)) * curvatureEnabled,
        HoAovEncodeScalar(_HoAovMaterialClass) * materialEnabled,
        saturate(_HoAovUtility) * utilityEnabled);
    output.custom0 = half4(HoAovApplyCustomWriteMask(_HoAovCustomValues0, 0.0));
    output.custom1 = half4(HoAovApplyCustomWriteMask(_HoAovCustomValues1, 4.0));
    output.custom2 = half4(HoAovApplyCustomWriteMask(_HoAovCustomValues2, 8.0));
    return output;
}

#endif
