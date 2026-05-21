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
    half4 objectCustom0 : SV_Target5;
    half4 objectCustom1 : SV_Target6;
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

float HoAovEncodeByte(float value)
{
    return saturate(round(clamp(value, 0.0, 255.0)) / 255.0);
}

float HoAovGetObjectId()
{
    return _HoAovObjectId;
}

float HoAovResolveMaterialProfile()
{
    if (_SubsurfaceScattering > 0.0001)
    {
        return HoAovEncodeByte(_HoSSSProfileId);
    }

    return HoAovEncodeScalar(_HoAovMaterialClass);
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

float HoAovByteToFloat(uint value, uint shift)
{
    return (float)((value >> shift) & 255u);
}

float HoAovHasObjectCustomBit(uint mask, uint bitIndex)
{
    return (float)((mask >> bitIndex) & 1u);
}

float4 HoAovDecodeObjectCustom0(uint mask)
{
    return float4(
        HoAovHasObjectCustomBit(mask, 0u),
        HoAovHasObjectCustomBit(mask, 1u),
        HoAovHasObjectCustomBit(mask, 2u),
        HoAovHasObjectCustomBit(mask, 3u));
}

float4 HoAovDecodeObjectCustom1(uint mask)
{
    return float4(
        HoAovHasObjectCustomBit(mask, 4u),
        HoAovHasObjectCustomBit(mask, 5u),
        HoAovHasObjectCustomBit(mask, 6u),
        HoAovHasObjectCustomBit(mask, 7u));
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
    float4 values = HoAovSampleCustom0To3(uv_MainTex);
    if (_HoAovCustomWriteMask >= 0.5)
    {
        values = HoAovApplyCustomWriteMask(_HoAovCustomValues0, 0.0);
    }

    return values;
}

float4 HoAovResolveSssSource(float2 uv_MainTex, float2 dx, float2 dy)
{
    if (_SubsurfaceScattering > 0.0001)
    {
        half3 albedo = Sample(_MainTex, sampler_trilinear_repeat, uv_MainTex, dx, dy).rgb * _Color.rgb;
        half sourceWeight = saturate(_SubsurfaceScattering);
        half3 sourceColor = lerp(_SubsurfaceColor.rgb, _SubsurfaceColor.rgb * albedo, saturate(_SubsurfaceAlbedoBlend));
        return float4(sourceColor, sourceWeight);
    }

    return 0.0;
}

half HoAovSelectChannel(half4 value, uint channel)
{
    if (channel == 1u) return value.g;
    if (channel == 2u) return value.b;
    if (channel == 3u) return value.a;
    return value.r;
}

half HoAovResolveThickness(float2 uv_MainTex, float2 dx, float2 dy)
{
    half thickness = saturate(_HoAovThickness);

    if (_SubsurfaceScattering > 0.0001)
    {
        half subsurfaceMask = HoAovSelectChannel(Sample(_SubsurfaceMap, sampler_trilinear_repeat, uv_MainTex, dx, dy), _SubsurfaceChannel);
        if (_SubsurfaceInvert != 0)
        {
            subsurfaceMask = 1.0 - subsurfaceMask;
        }

        half subsurfaceThinness = pow(saturate(subsurfaceMask), _SubsurfacePower) * _SubsurfaceScattering;
        half subsurfaceFloor = saturate(_SubsurfaceScattering) * 0.2;
        thickness = max(thickness, max(subsurfaceFloor, saturate(subsurfaceThinness)));
    }

    return saturate(thickness);
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
    float2 uvDx = ddx(uv_MainTex);
    float2 uvDy = ddy(uv_MainTex);
    half3 normalWS = HoAovGetNormal(i, isFront, normalTS);
    half thickness = HoAovResolveThickness(uv_MainTex, uvDx, uvDy);
    uint rendererUserValue = unity_RendererUserValue;
    bool hasRendererUserValue = rendererUserValue != 0u;
    uint objectCustomMask = hasRendererUserValue ? (rendererUserValue & 255u) : (uint)round(saturate(_HoAovObjectCustomMask / 255.0) * 255.0);
    float effectiveGroupId = hasRendererUserValue ? HoAovByteToFloat(rendererUserValue, 8u) : _HoAovGroupId;
    float effectiveObjectId = hasRendererUserValue ? HoAovByteToFloat(rendererUserValue, 16u) : HoAovGetObjectId();
    float effectiveFlags = hasRendererUserValue ? HoAovByteToFloat(rendererUserValue, 24u) : _HoAovFlags;

    HoAovOutput output = (HoAovOutput)0;
    output.maskId = half4(
        subjectCoverage * maskEnabled,
        HoAovEncodeScalar(effectiveGroupId) * idEnabled * subjectValid,
        HoAovEncodeScalar(effectiveObjectId) * idEnabled * subjectValid,
        HoAovEncodeScalar(effectiveFlags) * flagsEnabled * subjectValid);
    output.normalDepth = half4((normalize(normalWS) * 0.5 + 0.5) * worldNormalEnabled * subjectValid, linearDepth * linearDepthEnabled * subjectValid);
    output.tangentNormal = half4((normalize(normalTS) * 0.5 + 0.5) * tangentNormalEnabled * subjectValid, tangentNormalEnabled * subjectValid);
    output.surfaceData = half4(
        thickness * thicknessEnabled * subjectValid,
        saturate(abs(_HoAovCurvature)) * curvatureEnabled * subjectValid,
        HoAovResolveMaterialProfile() * materialEnabled * subjectValid,
        saturate(_HoAovUtility) * utilityEnabled * subjectValid);
    output.custom0 = half4(HoAovResolveCustom0To3(uv_MainTex) * subjectValid);
    output.objectCustom0 = half4(HoAovDecodeObjectCustom0(objectCustomMask) * subjectValid);
    output.objectCustom1 = half4(HoAovDecodeObjectCustom1(objectCustomMask) * subjectValid);
    return output;
}

half4 HoAovSssFrag(v2f i, bool isFront, inout float depth)
{
    half alpha = HoAovResolveAlpha(i);
    HoAovApplyAlpha(i, isFront, depth, alpha);

    float subjectCoverage = saturate(_HoAovMaskWeight);
    float subjectValid = step(0.0001, subjectCoverage);
    float2 uv_MainTex = i.uv01.xy * _MainTex_ST.xy + _MainTex_ST.zw;
    float2 uvDx = ddx(uv_MainTex);
    float2 uvDy = ddy(uv_MainTex);
    return half4(HoAovResolveSssSource(uv_MainTex, uvDx, uvDy) * subjectValid);
}

#endif
