#ifndef INCLUDED_LILPBR_CRYSTAL_CORE
#define INCLUDED_LILPBR_CRYSTAL_CORE

#ifndef CRYSTAL_SURFACE_SMOOTHNESS
#define CRYSTAL_SURFACE_SMOOTHNESS saturate(_CrystalSmoothness)
#endif

#ifndef CRYSTAL_PBR_SPECULAR_STRENGTH
#define CRYSTAL_PBR_SPECULAR_STRENGTH _CrystalSpecularStrength
#endif

#ifndef CRYSTAL_PBR_SPECULAR_COLOR
#define CRYSTAL_PBR_SPECULAR_COLOR _CrystalSpecularColor.rgb
#endif

#ifndef CRYSTAL_HIGHLIGHT_DEFLECTION
#define CRYSTAL_HIGHLIGHT_DEFLECTION _CrystalHighlightDeflection
#endif

float3 _LightDirection;
float3 _LightPosition;

struct CrystalAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct CrystalVaryings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 positionOS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float4 tangentWS : TEXCOORD3;
    float2 uv : TEXCOORD4;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct CrystalMaskData
{
    half edges;
    half thickness;
    half thicknessForDesaturate;
};

struct CrystalSurface
{
    half3 baseColor;
    half3 normalWS;
    half3 viewDirWS;
    half smoothness;
    half alpha;
    half fresnel;
    half volumeMain;
    half volumeSecondary;
    half edges;
    half thickness;
};

struct CrystalGemGlow
{
    half mask;
    half coord;
    half3 color;
};

half4 CrystalSampleMain(CrystalVaryings input)
{
    float2 uv = input.uv * _MainTex_ST.xy + _MainTex_ST.zw;
    return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
}

void CrystalClipAlpha(half alpha)
{
    clip(alpha - saturate(_Cutoff));
}

CrystalVaryings CrystalVert(CrystalAttributes input)
{
    CrystalVaryings output = (CrystalVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    output.positionCS = positionInputs.positionCS;
    output.positionWS = positionInputs.positionWS;
    output.positionOS = input.positionOS.xyz;
    output.normalWS = normalInputs.normalWS;
    output.tangentWS = float4(normalInputs.tangentWS, input.tangentOS.w * GetOddNegativeScale());
    output.uv = input.uv;
    return output;
}

CrystalVaryings CrystalVertDepth(CrystalAttributes input)
{
    return CrystalVert(input);
}

CrystalVaryings CrystalVertShadowCaster(CrystalAttributes input)
{
    CrystalVaryings output = CrystalVert(input);
    half3 normalWS = normalize(output.normalWS);
    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
        half3 lightDirectionWS = SafeNormalize(_LightPosition - output.positionWS);
    #else
        half3 lightDirectionWS = _LightDirection;
    #endif

    output.positionWS -= lightDirectionWS * _CrystalShadowCasterOffset;
    output.positionCS = TransformWorldToHClip(ApplyShadowBias(output.positionWS, normalWS, lightDirectionWS));
    #if UNITY_REVERSED_Z
        output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
        output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif
    return output;
}

half3 CrystalBlendNormals(half3 a, half3 b)
{
    return normalize(half3(a.xy + b.xy, a.z * b.z));
}

half3x3 CrystalTangentToWorld(CrystalVaryings input)
{
    half3 normalWS = normalize(input.normalWS);
    half3 tangentWS = normalize(input.tangentWS.xyz);
    half3 bitangentWS = normalize(cross(normalWS, tangentWS) * input.tangentWS.w);
    return half3x3(tangentWS, bitangentWS, normalWS);
}

half3 CrystalResolveNormalTS(float2 uv)
{
    return UnpackNormalScale(SAMPLE_TEXTURE2D(_CrystalNormalMap, sampler_CrystalNormalMap, uv * _CrystalNormalMap_ST.xy + _CrystalNormalMap_ST.zw), _CrystalNormalStrength);
}

half3 CrystalResolveNormalWS(CrystalVaryings input)
{
    half3 normalTS = CrystalResolveNormalTS(input.uv);
    return normalize(mul(normalTS, CrystalTangentToWorld(input)));
}

half3 CrystalSphericalNormalWS(CrystalVaryings input)
{
    float3 sphericalNormalOS = SafeNormalize(input.positionOS);
    return normalize(TransformObjectToWorldNormal(sphericalNormalOS));
}

float2 CrystalParallaxMaskUV(CrystalVaryings input, half3 viewDirWS)
{
    half3x3 tangentToWorld = CrystalTangentToWorld(input);
    half3 viewDirTS = mul(transpose(tangentToWorld), viewDirWS);
    float height = SAMPLE_TEXTURE2D(_CrystalMask, sampler_CrystalMask, input.uv * _CrystalMask_ST.xy + _CrystalMask_ST.zw).g;
    float2 parallax = viewDirTS.xy / max(abs(viewDirTS.z), 0.25h) * (height - 0.5) * _CrystalRampMaskParallax * 0.002;
    return input.uv * _CrystalMask_ST.xy + _CrystalMask_ST.zw - parallax;
}

half CrystalFresnel(half3 normalWS, half3 viewDirWS, half power)
{
    return pow(saturate(1.0h - dot(normalWS, viewDirWS)), max(power, 0.001h));
}

half CrystalResolveRefractionSurfaceNoise(CrystalVaryings input, half3 viewDirWS)
{
    if (_CrystalUseRefractionNoise == 0)
    {
        return 1.0h;
    }

    half3x3 tangentToWorld = CrystalTangentToWorld(input);
    half3 viewDirTS = mul(transpose(tangentToWorld), viewDirWS);
    float2 uv = input.uv * _CrystalRefractionNoise_ST.xy + _CrystalRefractionNoise_ST.zw;
    uv -= viewDirTS.xy / max(abs(viewDirTS.z), 0.25h) * _CrystalRefractionNoiseParallax * 0.002;
    half noise = SAMPLE_TEXTURE2D(_CrystalRefractionNoise, sampler_CrystalRefractionNoise, uv * _CrystalRefractionNoiseScale).r;
    return saturate(lerp(1.0h, noise + _CrystalRefractionNoiseAdd, _CrystalRefractionNoiseStrength));
}

float3 CrystalObjectScale()
{
    return float3(
        length(float3(unity_ObjectToWorld._m00, unity_ObjectToWorld._m10, unity_ObjectToWorld._m20)),
        length(float3(unity_ObjectToWorld._m01, unity_ObjectToWorld._m11, unity_ObjectToWorld._m21)),
        length(float3(unity_ObjectToWorld._m02, unity_ObjectToWorld._m12, unity_ObjectToWorld._m22)));
}

void CrystalResolveVolumeSpace(CrystalVaryings input, half3 normalWS, half3 viewDirWS, out float3 position, out float3 normal, out float3 viewDirection)
{
    if (_CrystalVolumeSpace < 0.5)
    {
        position = input.positionWS;
        normal = normalWS;
        viewDirection = viewDirWS;
    }
    else
    {
        float3 localPosition = input.positionOS;
        if (_CrystalVolumeSpace > 1.5)
        {
            localPosition *= CrystalObjectScale();
        }
        position = localPosition;
        normal = TransformWorldToObjectDir(normalWS, false);
        viewDirection = TransformWorldToObjectDir(viewDirWS, false);
    }

    position += _CrystalVolumeOffset.xyz;
}

CrystalMaskData CrystalResolveMask(CrystalVaryings input, half3 viewDirWS)
{
    float2 maskUV = CrystalParallaxMaskUV(input, viewDirWS);
    half4 mask = SAMPLE_TEXTURE2D(_CrystalMask, sampler_CrystalMask, maskUV);
    half thickness = saturate(mask.g);

    CrystalMaskData data;
    data.edges = saturate(mask.r);
    data.thickness = thickness;
    data.thicknessForDesaturate = saturate(lerp(1.0h, thickness, _CrystalDesaturateThickness));
    return data;
}

CrystalRaymarchInput CrystalBuildRaymarchInput(CrystalVaryings input, half3 normalWS, half3 viewDirWS)
{
    float3 volumePosition;
    float3 volumeNormal;
    float3 volumeViewDirection;
    CrystalResolveVolumeSpace(input, normalWS, viewDirWS, volumePosition, volumeNormal, volumeViewDirection);

    CrystalRaymarchInput rayInput;
    rayInput.position = volumePosition;
    rayInput.viewDirection = volumeViewDirection;
    rayInput.normal = volumeNormal;
    rayInput.refraction = _CrystalRefraction;
    rayInput.refractionSurfaceNoise = CrystalResolveRefractionSurfaceNoise(input, viewDirWS);
    rayInput.stepLength = _CrystalStepLength;
    rayInput.volumeNoiseScale = _CrystalVolumeNoiseScale;
    rayInput.volumeNoiseExp = _CrystalVolumeNoiseExp;
    rayInput.volumeNoiseMultiply = _CrystalVolumeNoiseMultiply;
    rayInput.secondaryExp = _CrystalVolumeSecondaryExp;
    rayInput.secondaryMultiply = _CrystalVolumeSecondaryMultiply;
    return rayInput;
}

half CrystalResolveGemGlowMask(CrystalSurface surface)
{
    half volumeMask = saturate(surface.volumeMain + surface.volumeSecondary * _CrystalVolumeSecondaryIntersect);
    half thicknessMask = lerp(1.0h, surface.thickness, saturate(_CrystalRampThicknessStrength));
    half edgeMask = surface.edges * max(_CrystalRampEdgeStrength, 0.0h);
    half fresnelMask = surface.fresnel * saturate(_CrystalRampFresnelStrength);
    return saturate(volumeMask * thicknessMask + edgeMask + fresnelMask);
}

half CrystalApplyGemGlowContrast(half value)
{
    half contrast = max(_CrystalRampContrast, 0.001h);
    return saturate((saturate(value) - 0.5h) * contrast + 0.5h);
}

half3 CrystalSampleGemGlowRamp(half coord)
{
    return SAMPLE_TEXTURE2D(_CrystalRamp, sampler_CrystalRamp, float2(coord, 0.5)).rgb * _CrystalRampTint.rgb;
}

CrystalGemGlow CrystalResolveGemGlow(CrystalSurface surface)
{
    CrystalGemGlow glow;
    glow.mask = CrystalApplyGemGlowContrast(CrystalResolveGemGlowMask(surface));
    glow.coord = glow.mask;
    glow.color = CrystalSampleGemGlowRamp(glow.coord) * saturate(glow.mask) * _CrystalRampEmissionPower;
    return glow;
}

half CrystalApplyShadowStrength(half shadow, half strength)
{
    return lerp(1.0h, saturate(shadow), saturate(strength));
}

half CrystalSampleScreenSpaceAO(CrystalVaryings input)
{
    half screenSpaceAO = 1.0h;
    #if defined(_SCREEN_SPACE_OCCLUSION)
        AmbientOcclusionFactor ssao = GetScreenSpaceAmbientOcclusion(GetNormalizedScreenSpaceUV(input.positionCS));
        screenSpaceAO = ssao.indirectAmbientOcclusion;
    #endif
    return CrystalApplyShadowStrength(screenSpaceAO, _CrystalSSAOStrength);
}

half3 CrystalApplySSAOTint(half3 color, half screenSpaceAO)
{
    return lerp(color * _CrystalSSAOTint.rgb, color, saturate(screenSpaceAO));
}

float3 CrystalResolveShadowSamplePositionWS(CrystalVaryings input, CrystalSurface surface)
{
    return input.positionWS + surface.normalWS * _CrystalShadowReceiveOffset;
}

half CrystalTooningScale(half value, half border, half blur)
{
    half borderMin = border - blur * 0.5h;
    half borderMax = border + blur * 0.5h;
    half width = max(borderMax - borderMin + fwidth(value), 0.0001h);
    return saturate((saturate(value) - borderMin) / width);
}

half CrystalApplyShadowBoundaryBlur(half shadow)
{
    return CrystalTooningScale(shadow, saturate(_CrystalShadowBorder), max(_CrystalShadowBlur, 0.0h));
}

half CrystalResolveDirectShapeShadow(half nDotL)
{
    return CrystalApplyShadowBoundaryBlur(nDotL);
}

half CrystalResolveMainLightShadowCast(half urpShadow)
{
    half shadowCast = CrystalApplyShadowBoundaryBlur(urpShadow);
    return lerp(1.0h, shadowCast, saturate(_CrystalShadowCastStrength));
}

half CrystalResolveShadowAttenuation(half urpShadow, half lightShapeShadow)
{
    half shadowCast = CrystalResolveMainLightShadowCast(urpShadow);
    half rawShadow = saturate(shadowCast * saturate(lightShapeShadow));
    return CrystalApplyShadowStrength(rawShadow, _CrystalShadowStrength);
}

half CrystalResolveDiffuseShadowMix(half urpShadow, half nDotL)
{
    half lightShapeShadow = CrystalResolveDirectShapeShadow(nDotL);
    return CrystalResolveShadowAttenuation(urpShadow, lightShapeShadow);
}

half3 CrystalSampleShadowRamp(half shadowAmount)
{
    return SAMPLE_TEXTURE2D(_CrystalShadowRamp, sampler_CrystalShadowRamp, float2(saturate(shadowAmount), 0.5)).rgb;
}

half3 CrystalResolveShadowLayerColor(half3 layerColor, half shadowMix)
{
    half shadowAmount = saturate(1.0h - shadowMix);
    half3 rampShadowColor = layerColor * CrystalSampleShadowRamp(shadowAmount);
    return lerp(half3(0.0h, 0.0h, 0.0h), rampShadowColor, saturate(_CrystalShadowRampStrength));
}

half3 CrystalBlendDirectShadowLayer(half3 layerColor, half3 lightColor, half lightShape, half shadowMix)
{
    half3 litLayer = layerColor * lightColor * lightShape;
    half3 shadowLayer = CrystalResolveShadowLayerColor(layerColor, shadowMix) * lightColor * lightShape;
    return lerp(shadowLayer, litLayer, saturate(shadowMix));
}

half3 CrystalResolveHighlightViewDir(CrystalSurface surface)
{
    half deflection = min(max(CRYSTAL_HIGHLIGHT_DEFLECTION, 0.0h), 2.0h);
    half eta = lerp(1.0h, 0.58h, deflection);
    half3 refractedViewDir = -refract(-surface.viewDirWS, surface.normalWS, eta);
    return SafeNormalize(lerp(surface.viewDirWS, refractedViewDir, deflection));
}

half3 CrystalResolvePreprocessedNormalWS(CrystalVaryings input)
{
    half3 normalMapWS = CrystalResolveNormalWS(input);
    half3 sphericalNormalWS = CrystalSphericalNormalWS(input);
    return normalize(lerp(normalMapWS, sphericalNormalWS, saturate(_CrystalNormalSpherical)));
}

void CrystalApplyNormalPreprocess(CrystalVaryings input, inout CrystalSurface surface)
{
    surface.normalWS = CrystalResolvePreprocessedNormalWS(input);
}

void CrystalApplyBaseColorProcess(CrystalMaskData masks, inout CrystalSurface surface)
{
    half processMask = pow(saturate(surface.fresnel), max(_CrystalDesaturateFresnelExp, 0.001h)) * masks.thicknessForDesaturate;
    half3 baseColor = surface.baseColor;
    half luma = dot(baseColor, half3(0.2126h, 0.7152h, 0.0722h));
    surface.baseColor = lerp(baseColor, half3(luma, luma, luma) * _CrystalDesaturateLighten, processMask * _CrystalDesaturateAmount);
}

void CrystalApplySurfacePreprocess(CrystalVaryings input, CrystalMaskData masks, inout CrystalSurface surface)
{
    CrystalApplyNormalPreprocess(input, surface);
    surface.fresnel = CrystalFresnel(surface.normalWS, surface.viewDirWS, _CrystalFresnelPower);
    CrystalApplyBaseColorProcess(masks, surface);
}

CrystalSurface CrystalResolveSurface(CrystalVaryings input, half4 mainTex)
{
    CrystalSurface surface = (CrystalSurface)0;
    surface.viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
    half4 baseTex = mainTex * _CrystalBaseColor;
    surface.baseColor = baseTex.rgb;
    surface.smoothness = CRYSTAL_SURFACE_SMOOTHNESS;
    surface.alpha = saturate(baseTex.a);

    CrystalMaskData masks = CrystalResolveMask(input, surface.viewDirWS);
    CrystalApplySurfacePreprocess(input, masks, surface);

    CrystalRaymarchOutput volume = CrystalRaymarch8(CrystalBuildRaymarchInput(input, surface.normalWS, surface.viewDirWS));
    surface.volumeMain = volume.mainMask;
    surface.volumeSecondary = volume.secondaryMask;
    surface.edges = masks.edges;
    surface.thickness = masks.thickness;
    return surface;
}

struct CrystalLightingContext
{
    Light mainLight;
    float3 shadowPositionWS;
    half screenSpaceAO;
};

CrystalLightingContext CrystalResolveLightingContext(CrystalVaryings input, CrystalSurface surface)
{
    CrystalLightingContext lighting;
    lighting.shadowPositionWS = CrystalResolveShadowSamplePositionWS(input, surface);
    lighting.mainLight = GetMainLight(TransformWorldToShadowCoord(lighting.shadowPositionWS));
    lighting.screenSpaceAO = CrystalSampleScreenSpaceAO(input);
    return lighting;
}

half3 CrystalShadeIndirect(CrystalSurface surface, half3 layerColor, CrystalLightingContext lighting)
{
    half3 ambientColor = CrystalApplySSAOTint(layerColor, lighting.screenSpaceAO);
    return ambientColor * SampleSH(surface.normalWS) * _CrystalIndirectStrength;
}

half3 CrystalShadeMainDirect(CrystalSurface surface, half3 layerColor, CrystalLightingContext lighting)
{
    half lightFacing = dot(surface.normalWS, lighting.mainLight.direction) * 0.5h + 0.5h;
    half shadowMix = CrystalResolveDiffuseShadowMix(lighting.mainLight.shadowAttenuation, lightFacing);
    half lightShape = lighting.mainLight.distanceAttenuation;
    return CrystalBlendDirectShadowLayer(layerColor, lighting.mainLight.color, lightShape, shadowMix);
}

half3 CrystalShadeAdditionalDirect(CrystalVaryings input, CrystalSurface surface, half3 layerColor, CrystalLightingContext lighting)
{
    half3 color = half3(0.0h, 0.0h, 0.0h);

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, input.positionWS);
        half lightFacing = dot(surface.normalWS, light.direction) * 0.5h + 0.5h;
        half lightShadowMix = CrystalResolveDiffuseShadowMix(1.0h, lightFacing);
        half lightShape = light.distanceAttenuation;
        color += CrystalBlendDirectShadowLayer(layerColor, light.color, lightShape, lightShadowMix);
    }
    #endif

    return color;
}

half3 CrystalShadePBRSpecular(CrystalVaryings input, CrystalSurface surface, CrystalLightingContext lighting)
{
    if (CRYSTAL_PBR_SPECULAR_STRENGTH <= 0.0h || surface.smoothness <= 0.0h)
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    half3 color = half3(0.0h, 0.0h, 0.0h);
    half specPower = exp2(lerp(4.0h, 8.0h, surface.smoothness));
    half3 highlightViewDir = CrystalResolveHighlightViewDir(surface);

    half3 halfDir = SafeNormalize(lighting.mainLight.direction + highlightViewDir);
    half nDotH = saturate(dot(surface.normalWS, halfDir));
    half3 mainSpecularColor = max(CRYSTAL_PBR_SPECULAR_COLOR, half3(0.0h, 0.0h, 0.0h));
    color += pow(nDotH, specPower) * surface.smoothness * lighting.mainLight.distanceAttenuation * lighting.mainLight.color * mainSpecularColor * CRYSTAL_PBR_SPECULAR_STRENGTH;

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, input.positionWS);
        half3 lightHalfDir = SafeNormalize(light.direction + highlightViewDir);
        half lightNdotH = saturate(dot(surface.normalWS, lightHalfDir));
        half3 lightSpecularColor = max(CRYSTAL_PBR_SPECULAR_COLOR, half3(0.0h, 0.0h, 0.0h));
        color += pow(lightNdotH, specPower) * surface.smoothness * light.distanceAttenuation * light.color * lightSpecularColor * CRYSTAL_PBR_SPECULAR_STRENGTH;
    }
    #endif

    return color;
}

half3 CrystalShadeBaseLighting(CrystalVaryings input, CrystalSurface surface, half3 baseLayer, CrystalLightingContext lighting)
{
    half3 layerColor = max(baseLayer, half3(0.0h, 0.0h, 0.0h));
    half3 color = CrystalShadeIndirect(surface, layerColor, lighting);
    color += CrystalShadeMainDirect(surface, layerColor, lighting);
    color += CrystalShadeAdditionalDirect(input, surface, layerColor, lighting);
    return color;
}

half3 CrystalShade(CrystalVaryings input, CrystalSurface surface)
{
    CrystalLightingContext lighting = CrystalResolveLightingContext(input, surface);
    CrystalGemGlow gemGlow = CrystalResolveGemGlow(surface);
    half3 color = CrystalShadeBaseLighting(input, surface, surface.baseColor, lighting);
    color += max(gemGlow.color, half3(0.0h, 0.0h, 0.0h));
    color += CrystalShadePBRSpecular(input, surface, lighting);
    return max(color, half3(0.0h, 0.0h, 0.0h));
}

half4 CrystalFragForward(CrystalVaryings input, bool isFront : SV_IsFrontFace) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half4 mainTex = CrystalSampleMain(input);
    CrystalClipAlpha(mainTex.a);
    CrystalSurface surface = CrystalResolveSurface(input, mainTex);
    if (!isFront)
    {
        surface.normalWS = -surface.normalWS;
    }

    return half4(CrystalShade(input, surface), surface.alpha);
}

half4 CrystalFragDepth(CrystalVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    CrystalClipAlpha(CrystalSampleMain(input).a);
    return 0;
}

half4 CrystalFragDepthNormals(CrystalVaryings input, bool isFront : SV_IsFrontFace) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half4 mainTex = CrystalSampleMain(input);
    CrystalClipAlpha(mainTex.a);
    CrystalSurface surface = CrystalResolveSurface(input, mainTex);
    half3 normalWS = isFront ? surface.normalWS : -surface.normalWS;
    return half4(normalize(normalWS) * 0.5h + 0.5h, 1.0h);
}

#endif
