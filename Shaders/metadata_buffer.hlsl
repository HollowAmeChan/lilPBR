#ifndef INCLUDED_LILPBR_METADATA_BUFFER
#define INCLUDED_LILPBR_METADATA_BUFFER

struct LilPbrMetadataBufferOutput
{
    half4 maskId : SV_Target0;
    half4 surfaceData : SV_Target1;
    half4 custom0 : SV_Target2;
    half4 objectCustom0 : SV_Target3;
    half4 objectCustom1 : SV_Target4;
};

float LilPbrMetadataHasBit(float value, float bitValue)
{
    return step(0.5, fmod(floor(value / bitValue), 2.0));
}

float LilPbrMetadataHasSystemChannel(float bitValue)
{
    return LilPbrMetadataHasBit(_HoMetadataBufferSystemWriteMask, bitValue);
}

float LilPbrMetadataEncodeScalar(float value)
{
    return frac(abs(value) * 0.61803398875);
}

float LilPbrMetadataEncodeByte(float value)
{
    return saturate(round(clamp(value, 0.0, 255.0)) / 255.0);
}

float LilPbrMetadataByteToFloat(uint value, uint shift)
{
    return (float)((value >> shift) & 255u);
}

float LilPbrMetadataHasObjectCustomBit(uint mask, uint bitIndex)
{
    return (float)((mask >> bitIndex) & 1u);
}

float4 LilPbrMetadataDecodeObjectCustom0(uint mask)
{
    return float4(
        LilPbrMetadataHasObjectCustomBit(mask, 0u),
        LilPbrMetadataHasObjectCustomBit(mask, 1u),
        LilPbrMetadataHasObjectCustomBit(mask, 2u),
        LilPbrMetadataHasObjectCustomBit(mask, 3u));
}

float4 LilPbrMetadataDecodeObjectCustom1(uint mask)
{
    return float4(
        LilPbrMetadataHasObjectCustomBit(mask, 4u),
        LilPbrMetadataHasObjectCustomBit(mask, 5u),
        LilPbrMetadataHasObjectCustomBit(mask, 6u),
        LilPbrMetadataHasObjectCustomBit(mask, 7u));
}

float4 LilPbrMetadataApplyCustomWriteMask(float4 values, float startBit)
{
    if (_HoMetadataBufferCustomWriteMask < 0.5)
    {
        return values;
    }

    return float4(
        values.x * LilPbrMetadataHasBit(_HoMetadataBufferCustomWriteMask, exp2(startBit)),
        values.y * LilPbrMetadataHasBit(_HoMetadataBufferCustomWriteMask, exp2(startBit + 1.0)),
        values.z * LilPbrMetadataHasBit(_HoMetadataBufferCustomWriteMask, exp2(startBit + 2.0)),
        values.w * LilPbrMetadataHasBit(_HoMetadataBufferCustomWriteMask, exp2(startBit + 3.0)));
}

half LilPbrMetadataSelectChannel(half4 value, uint channel)
{
    if (channel == 1u) return value.g;
    if (channel == 2u) return value.b;
    if (channel == 3u) return value.a;
    return value.r;
}

half LilPbrMetadataResolveAlpha(v2f i)
{
    float2 uv_MainTex = i.uv01.xy * _MainTex_ST.xy + _MainTex_ST.zw;
    half alpha = _MainTex.Sample(sampler_trilinear_repeat, uv_MainTex).a * _Color.a;
    if (_VertexColorMode == 1)
    {
        alpha *= i.color.a;
    }
    return alpha;
}

half LilPbrMetadataResolveSurfaceColorCoverage(half alpha)
{
    #if defined(_TRANSPARENT)
        return saturate(alpha);
    #else
        return 1.0h;
    #endif
}

void LilPbrMetadataApplyAlpha(v2f i, inout float depth, half alpha)
{
    depth = i.pos.z;

    #if defined(_CUTOUT) || defined(_DITHER)
        #if defined(_DITHER)
            if (_DitherRandomize && IsPerspective()) alpha = alpha + ibuki(i.pos) * 0.1h - 0.05h;
            clip(alpha - (_DitherTex[uint2(i.pos.xy) % 4].r * 255 + 1) / (15 + 2));
        #else
            clip(alpha - _Cutoff);
        #endif
    #endif
}

float4 LilPbrMetadataResolveSurfaceColor(v2f i, bool isFront, float2 uv_MainTex, float2 dx, float2 dy, half coverage)
{
    half4 mainTex = Sample(_MainTex, sampler_trilinear_repeat, uv_MainTex, dx, dy) * _Color;
    half3 surfaceColor = mainTex.rgb;

    #ifdef _BACKFACE_COLOR
    half4 backfaceTex = Sample(_BackfaceTex, sampler_trilinear_repeat, uv_MainTex, dx, dy) * _BackfaceColor;
    surfaceColor = isFront ? mainTex.rgb : backfaceTex.rgb;
    #endif

    #ifdef _SCREENINGMODE_AM
    surfaceColor = AMScreening(surfaceColor, uv_MainTex, float2(_ScreeningScaleX, _ScreeningScaleY), 1, _ScreeningNoiseStrength);
    #endif

    if (_VertexColorMode == 1)
    {
        surfaceColor *= i.color.rgb;
    }

    return float4(saturate(surfaceColor), saturate(coverage));
}

half3 LilPbrMetadataGetNormal(v2f i, bool isFront, out half3 normalTS)
{
    half3 tangent = normalize(i.tangent.xyz);
    half3 binormal = normalize(i.binormal.xyz);
    half3 normal = normalize(i.normal.xyz);
    normalTS = half3(0.0h, 0.0h, 1.0h);
    if (!isFront)
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

half LilPbrMetadataResolveThickness(float2 uv_MainTex, float2 dx, float2 dy)
{
    half thickness = saturate(_HoMetadataBufferThickness);

    if (_SubsurfaceScattering > 0.0001)
    {
        half subsurfaceMask = LilPbrMetadataSelectChannel(Sample(_SubsurfaceMap, sampler_trilinear_repeat, uv_MainTex, dx, dy), _SubsurfaceChannel);
        if (_SubsurfaceInvert != 0)
        {
            subsurfaceMask = 1.0h - subsurfaceMask;
        }

        half subsurfaceThinness = pow(saturate(subsurfaceMask), _SubsurfacePower) * _SubsurfaceScattering;
        half subsurfaceFloor = saturate(_SubsurfaceScattering) * 0.2h;
        thickness = max(thickness, max(subsurfaceFloor, saturate(subsurfaceThinness)) * max(_HoSSSThicknessScale, 0.0));
    }

    return saturate(thickness);
}

float LilPbrMetadataResolveMaterialProfile()
{
    if (_SubsurfaceScattering > 0.0001)
    {
        return LilPbrMetadataEncodeByte(_HoSSSProfileId);
    }

    return LilPbrMetadataEncodeScalar(_HoMetadataBufferMaterialClass);
}

float4 LilPbrMetadataResolvePlanarCustom0(float smoothness)
{
    float planarReflectionEnabled = _UsePlanarReflection != 0 ? 1.0 : 0.0;
    float4 custom0 = float4(
        saturate(smoothness),
        1.0,
        0.0,
        saturate(_PlanarReflectionStrength) * planarReflectionEnabled);

    if (_HoMetadataBufferCustomWriteMask >= 0.5)
    {
        custom0 = LilPbrMetadataApplyCustomWriteMask(_HoMetadataBufferCustomValues0, 0.0);
    }

    return custom0;
}

half4 LilPbrMetadataBufferSurfaceColorFrag(v2f i, bool isFront, inout float depth)
{
    half alpha = LilPbrMetadataResolveAlpha(i);
    LilPbrMetadataApplyAlpha(i, depth, alpha);
    half coverage = LilPbrMetadataResolveSurfaceColorCoverage(alpha);

    float subjectCoverage = saturate(_HoMetadataBufferMaskWeight) * coverage;
    float subjectValid = step(0.0001, subjectCoverage);
    float2 uv_MainTex = i.uv01.xy * _MainTex_ST.xy + _MainTex_ST.zw;
    float2 uvDx = ddx(uv_MainTex);
    float2 uvDy = ddy(uv_MainTex);
    return half4(LilPbrMetadataResolveSurfaceColor(i, isFront, uv_MainTex, uvDx, uvDy, subjectCoverage) * subjectValid);
}

LilPbrMetadataBufferOutput LilPbrMetadataBufferFrag(v2f i, bool isFront, inout float depth)
{
    half alpha = LilPbrMetadataResolveAlpha(i);
    LilPbrMetadataApplyAlpha(i, depth, alpha);
    half coverage = LilPbrMetadataResolveSurfaceColorCoverage(alpha);

    float2 uv_MainTex = i.uv01.xy * _MainTex_ST.xy + _MainTex_ST.zw;
    float2 uvDx = ddx(uv_MainTex);
    float2 uvDy = ddy(uv_MainTex);
    float2 uv[4];
    uv[0] = i.uv01.xy;
    uv[1] = i.uv01.zw;
    uv[2] = i.uv23.xy;
    uv[3] = i.uv23.zw;
    ShadingParams p = ShadingMeta(i, i.pos, uv);

    float maskEnabled = LilPbrMetadataHasSystemChannel(1.0);
    float idEnabled = LilPbrMetadataHasSystemChannel(2.0);
    float flagsEnabled = LilPbrMetadataHasSystemChannel(4.0);
    float thicknessEnabled = LilPbrMetadataHasSystemChannel(256.0);
    float curvatureEnabled = LilPbrMetadataHasSystemChannel(512.0);
    float materialEnabled = LilPbrMetadataHasSystemChannel(1024.0);
    float transmittanceHintEnabled = LilPbrMetadataHasSystemChannel(2048.0);
    float subjectCoverage = saturate(_HoMetadataBufferMaskWeight) * coverage;
    float subjectValid = step(0.0001, subjectCoverage);

    uint rendererUserValue = unity_RendererUserValue;
    bool hasRendererUserValue = rendererUserValue != 0u;
    uint objectCustomMask = hasRendererUserValue ? (rendererUserValue & 255u) : (uint)round(saturate(_HoMetadataBufferObjectCustomMask / 255.0) * 255.0);
    float effectiveGroupId = hasRendererUserValue ? LilPbrMetadataByteToFloat(rendererUserValue, 8u) : _HoMetadataBufferGroupId;
    float effectiveObjectId = hasRendererUserValue ? LilPbrMetadataByteToFloat(rendererUserValue, 16u) : _HoMetadataBufferObjectId;
    float effectiveFlags = hasRendererUserValue ? LilPbrMetadataByteToFloat(rendererUserValue, 24u) : _HoMetadataBufferFlags;
    half hoSssEnabled = step(0.0001, _SubsurfaceScattering);
    half hoSssTransmissionStrength = saturate(_HoSSSTransmissionStrength - 1.0);
    half hoSssTransmissionRadius = saturate((_HoSSSTransmissionRadius - 0.5) / 1.5);

    LilPbrMetadataBufferOutput output = (LilPbrMetadataBufferOutput)0;
    output.maskId = half4(
        subjectCoverage * maskEnabled,
        LilPbrMetadataEncodeByte(effectiveGroupId) * idEnabled * subjectValid,
        LilPbrMetadataEncodeByte(effectiveObjectId) * idEnabled * subjectValid,
        LilPbrMetadataEncodeByte(effectiveFlags) * flagsEnabled * subjectValid);
    output.surfaceData = half4(
        LilPbrMetadataResolveThickness(uv_MainTex, uvDx, uvDy) * thicknessEnabled * subjectValid,
        max(saturate(abs(_HoMetadataBufferCurvature)), hoSssTransmissionStrength * hoSssEnabled) * curvatureEnabled * subjectValid,
        LilPbrMetadataResolveMaterialProfile() * materialEnabled * subjectValid,
        max(saturate(_HoMetadataBufferTransmittanceHint), hoSssTransmissionRadius * hoSssEnabled) * transmittanceHintEnabled * subjectValid);
    output.custom0 = half4(LilPbrMetadataResolvePlanarCustom0(p.smoothness) * subjectValid);
    output.objectCustom0 = half4(LilPbrMetadataDecodeObjectCustom0(objectCustomMask) * subjectValid);
    output.objectCustom1 = half4(LilPbrMetadataDecodeObjectCustom1(objectCustomMask) * subjectValid);
    return output;
}

half4 LilPbrGeometryBufferFrag(v2f i, bool isFront, inout float depth)
{
    half alpha = LilPbrMetadataResolveAlpha(i);
    LilPbrMetadataApplyAlpha(i, depth, alpha);

    half3 normalTS;
    half3 normalWS = LilPbrMetadataGetNormal(i, isFront, normalTS);
    float linearDepth = LinearEyeDepth(i.pos.z, _ZBufferParams);
    return half4(normalize(normalWS) * 0.5h + 0.5h, linearDepth);
}

#endif
