#ifndef INCLUDED_LILPBR_HOAOV
#define INCLUDED_LILPBR_HOAOV

float _lilHoAovSystemChannelMask;

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
    if (_HoAovCustomWriteMask < 0.5)
    {
        return values;
    }

    return float4(
        values.x * HoAovHasBit(_HoAovCustomWriteMask, exp2(startBit)),
        values.y * HoAovHasBit(_HoAovCustomWriteMask, exp2(startBit + 1.0)),
        values.z * HoAovHasBit(_HoAovCustomWriteMask, exp2(startBit + 2.0)),
        values.w * HoAovHasBit(_HoAovCustomWriteMask, exp2(startBit + 3.0)));
}

float4 HoAovSampleCustom0To3(float2 uv_MainTex)
{
    return float4(
        _HoAovCustom0Tex.Sample(sampler_trilinear_repeat, uv_MainTex).r * _HoAovCustom0Color.r,
        _HoAovCustom1Tex.Sample(sampler_trilinear_repeat, uv_MainTex).r * _HoAovCustom1Color.r,
        _HoAovCustom2Tex.Sample(sampler_trilinear_repeat, uv_MainTex).r * _HoAovCustom2Color.r,
        _HoAovCustom3Tex.Sample(sampler_trilinear_repeat, uv_MainTex).r * _HoAovCustom3Color.r);
}

float4 HoAovResolveCustom0To3(float2 uv_MainTex)
{
    if (_HoAovCustomWriteMask >= 0.5)
    {
        return HoAovApplyCustomWriteMask(_HoAovCustomValues0, 0.0);
    }

    return HoAovSampleCustom0To3(uv_MainTex);
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
        half4 bumpmap = _BumpMap.SampleGrad(sampler_trilinear_repeat, uv_MainTex, dx, dy);
        normalTS = normalize(UnpackScaleNormal(bumpmap, _BumpScale));
        return normalize(mul(normalTS, matrixTBN));
    #else
        return normal;
    #endif
}

half HoAovResolveAlpha(v2f i)
{
    float2 uv_MainTex = i.uv01.xy * _MainTex_ST.xy + _MainTex_ST.zw;
    half alpha = _MainTex.Sample(sampler_trilinear_repeat, uv_MainTex).a * _Color.a;
    if(_VertexColorMode == 1)
    {
        alpha *= i.color.a;
    }
    return alpha;
}

void HoAovApplyAlpha(v2f i, bool isFront, inout float depth, half alpha)
{
    #if defined(_CUTOUT) || defined(_DITHER)
        #if defined(_DITHER)
            if(_DitherRandomize && IsPerspective()) alpha = alpha + ibuki(i.pos) * 0.1 - 0.05;
            clip(alpha - (_DitherTex[uint2(i.pos.xy)%4].r * 255 + 1) / (15 + 2));
        #else
            clip(alpha - _Cutoff);
        #endif
    #endif
}

HoAovOutput HoAovFrag(v2f i, bool isFront, inout float depth)
{
    half alpha = HoAovResolveAlpha(i);
    HoAovApplyAlpha(i, isFront, depth, alpha);

    float maskEnabled = HoAovHasSystemChannel(1.0);
    float idEnabled = HoAovHasSystemChannel(2.0);
    float flagsEnabled = HoAovHasSystemChannel(4.0);
    float linearDepthEnabled = HoAovHasSystemChannel(8.0);
    float worldNormalEnabled = HoAovHasSystemChannel(16.0);
    float tangentNormalEnabled = HoAovHasSystemChannel(64.0);
    float thicknessEnabled = HoAovHasSystemChannel(256.0);
    float curvatureEnabled = HoAovHasSystemChannel(512.0);
    float materialEnabled = HoAovHasSystemChannel(1024.0);
    float utilityEnabled = HoAovHasSystemChannel(2048.0);
    float subjectCoverage = saturate(_HoAovMaskWeight);
    float subjectValid = step(0.0001, subjectCoverage);

    float linearDepth = LinearEyeDepth(i.pos.z, _ZBufferParams);
    float2 uv_MainTex = i.uv01.xy * _MainTex_ST.xy + _MainTex_ST.zw;
    half3 normalTS;
    half3 normalWS = HoAovGetNormal(i, isFront, normalTS);

    HoAovOutput output;
    output.maskId = half4(
        subjectCoverage * maskEnabled,
        HoAovEncodeScalar(_HoAovGroupId) * idEnabled * subjectValid,
        HoAovEncodeScalar(HoAovGetObjectId()) * idEnabled * subjectValid,
        HoAovEncodeScalar(_HoAovFlags) * flagsEnabled * subjectValid);
    output.normalDepth = half4((normalize(normalWS) * 0.5 + 0.5) * worldNormalEnabled * subjectValid, linearDepth * linearDepthEnabled * subjectValid);
    output.tangentNormal = half4((normalize(normalTS) * 0.5 + 0.5) * tangentNormalEnabled * subjectValid, tangentNormalEnabled * subjectValid);
    output.surfaceData = half4(
        saturate(_HoAovThickness) * thicknessEnabled * subjectValid,
        saturate(abs(_HoAovCurvature)) * curvatureEnabled * subjectValid,
        HoAovEncodeScalar(_HoAovMaterialClass) * materialEnabled * subjectValid,
        saturate(_HoAovUtility) * utilityEnabled * subjectValid);
    output.custom0 = half4(HoAovResolveCustom0To3(uv_MainTex) * subjectValid);
    output.custom1 = half4(0.0, 0.0, 0.0, 0.0);
    output.custom2 = half4(0.0, 0.0, 0.0, 0.0);
    return output;
}

#endif
