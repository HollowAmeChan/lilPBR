#ifndef INCLUDED_LILPBR_CRYSTAL_MATCAP_PARALLAX_GEM_CORE
#define INCLUDED_LILPBR_CRYSTAL_MATCAP_PARALLAX_GEM_CORE

half3 CrystalGemMatCap(CrystalSurface surface)
{
    float2 matcapUV = mul((float3x3)UNITY_MATRIX_V, normalize(surface.normalWS)).xy * 0.5 + 0.5;
    matcapUV = matcapUV * _CrystalGemMatCap_ST.xy + _CrystalGemMatCap_ST.zw;
    half3 matcap = SAMPLE_TEXTURE2D(_CrystalGemMatCap, sampler_CrystalGemMatCap, matcapUV).rgb * _CrystalGemMatCapColor.rgb;
    half edgeWeight = lerp(1.0h, surface.fresnel, saturate(_CrystalGemMatCapFresnel));
    return matcap * _CrystalGemMatCapStrength * edgeWeight;
}

float2 CrystalGemParallaxRay(CrystalVaryings input, CrystalSurface surface)
{
    half3x3 tangentToWorld = CrystalTangentToWorld(input);
    half3 viewDirTS = mul(transpose(tangentToWorld), surface.viewDirWS);
    return viewDirTS.xy / max(abs(viewDirTS.z), 0.25h) * _CrystalGemParallaxDepth * 0.002;
}

half3 CrystalGemApplyParallaxContrast(half3 color)
{
    half contrast = max(_CrystalGemParallaxContrast, 0.001h);
    return pow(saturate(color), contrast) * contrast;
}

half3 CrystalGemParallaxLayer(CrystalVaryings input, CrystalSurface surface)
{
    float2 baseUV = input.uv * _CrystalGemParallaxMap_ST.xy + _CrystalGemParallaxMap_ST.zw;
    float2 ray = CrystalGemParallaxRay(input, surface);

    half4 nearLayer = SAMPLE_TEXTURE2D(_CrystalGemParallaxMap, sampler_CrystalGemParallaxMap, baseUV - ray);
    half4 farLayer = SAMPLE_TEXTURE2D(_CrystalGemParallaxMap, sampler_CrystalGemParallaxMap, baseUV - ray * 2.0);
    half layerMix = saturate(surface.fresnel + dot(farLayer.rgb, half3(0.333333h, 0.333333h, 0.333333h)));
    half3 parallax = lerp(nearLayer.rgb, farLayer.rgb, layerMix);

    half luminanceMask = saturate(max(dot(nearLayer.rgb, half3(0.333333h, 0.333333h, 0.333333h)), dot(farLayer.rgb, half3(0.333333h, 0.333333h, 0.333333h))));
    half edgeWeight = lerp(1.0h, surface.fresnel + luminanceMask, saturate(_CrystalGemParallaxFresnel));
    return CrystalGemApplyParallaxContrast(parallax) * _CrystalGemParallaxTint.rgb * _CrystalGemParallaxStrength * saturate(edgeWeight);
}

half3 CrystalShadeMatCapParallaxGem(CrystalVaryings input, CrystalSurface surface)
{
    half3 crystalLit = CrystalShade(input, surface);
    half3 baseLighting = max(crystalLit - surface.emission, half3(0.0h, 0.0h, 0.0h)) * _CrystalGemBaseLightStrength;
    half3 volumeEmission = surface.emission * _CrystalGemVolumeEmissionStrength;
    return baseLighting + volumeEmission + CrystalGemMatCap(surface) + CrystalGemParallaxLayer(input, surface);
}

half4 CrystalFragMatCapParallaxGem(CrystalVaryings input, bool isFront : SV_IsFrontFace) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    CrystalSurface surface = CrystalResolveSurface(input);
    if (!isFront)
    {
        surface.normalWS = -surface.normalWS;
        surface.fresnel = CrystalFresnel(surface.normalWS, surface.viewDirWS, _CrystalFresnelPower);
    }

    half3 debugColor = CrystalDebugColor(surface);
    if (debugColor.x >= 0.0h)
    {
        return half4(debugColor, 1.0h);
    }

    return half4(CrystalShadeMatCapParallaxGem(input, surface), surface.alpha);
}

#endif
