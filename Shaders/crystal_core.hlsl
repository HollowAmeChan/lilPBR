#ifndef INCLUDED_LILPBR_CRYSTAL_CORE
#define INCLUDED_LILPBR_CRYSTAL_CORE

#ifndef CRYSTAL_SURFACE_METALLIC
#define CRYSTAL_SURFACE_METALLIC saturate(_CrystalMetallic)
#endif

#ifndef CRYSTAL_SURFACE_SMOOTHNESS
#define CRYSTAL_SURFACE_SMOOTHNESS saturate(_CrystalSmoothness)
#endif

#ifndef CRYSTAL_PBR_SPECULAR_STRENGTH
#define CRYSTAL_PBR_SPECULAR_STRENGTH _CrystalSpecularStrength
#endif

#ifndef CRYSTAL_PBR_SPECULAR_COLOR
#define CRYSTAL_PBR_SPECULAR_COLOR _CrystalSpecularColor.rgb
#endif

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
    half3 color;
    half3 emission;
    half3 normalWS;
    half3 viewDirWS;
    half metallic;
    half smoothness;
    half occlusion;
    half alpha;
    half fresnel;
    half volumeMain;
    half volumeSecondary;
    half rampCoord;
    half edges;
    half thickness;
};

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

half3 CrystalBlendNormals(half3 a, half3 b)
{
    return normalize(half3(a.xy + b.xy, a.z * b.z));
}

half3 CrystalApplyNormalStrength(half3 normalTS, half strength)
{
    normalTS.xy *= strength;
    normalTS.z = sqrt(saturate(1.0h - dot(normalTS.xy, normalTS.xy)));
    return normalize(normalTS);
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
    half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_CrystalNormalMap, sampler_CrystalNormalMap, uv * _CrystalNormalMap_ST.xy + _CrystalNormalMap_ST.zw), _CrystalNormalScale);
    return CrystalApplyNormalStrength(normalTS, _CrystalNormalStrength);
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
    float2 parallax = viewDirTS.xy / max(abs(viewDirTS.z), 0.25h) * (height - 0.5) * _CrystalEdgesParallax * 0.002;
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
    half edgeRB = lerp(mask.r, mask.b, saturate(_CrystalEdgesStyle));
    half thicknessA = saturate(mask.g);
    half thicknessB = saturate(1.0h - mask.g);
    half thicknessStyle = lerp(thicknessA, thicknessB, saturate(_CrystalEdgesStyle));
    half edgeBase = lerp(edgeRB, thicknessStyle, _CrystalEdgesUseThickness != 0 ? 1.0h : 0.0h);

    CrystalMaskData data;
    data.edges = saturate(edgeBase * _CrystalEdgesEmission);
    data.thickness = pow(saturate(thicknessA + _CrystalThicknessNegate), max(_CrystalThicknessExp, 0.001h));
    data.thicknessForDesaturate = saturate(lerp(1.0h, thicknessA, _CrystalDesaturateThickness));
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
    rayInput.linearMaskScale = _CrystalLinearMaskScale;
    rayInput.linearMaskNegate = _CrystalLinearMaskNegate;
    rayInput.linearMaskOffset = _CrystalLinearMaskOffset;
    rayInput.linearMaskVector = SafeNormalize(_CrystalLinearMaskVector.xyz);
    rayInput.linearMaskWorldOffset = _CrystalLinearMaskWorldOffset.xyz;
    return rayInput;
}

half CrystalResolveRampMask(CrystalRaymarchOutput volume, CrystalMaskData masks, half fresnel)
{
    half volumeMask = saturate(volume.mainMask + volume.secondaryMask * _CrystalVolumeSecondaryIntersect);
    half edges = lerp(masks.edges, masks.edges * volumeMask, saturate(_CrystalEdgesOnlyOnMasked));
    half thickness = saturate(masks.thickness + (1.0h - fresnel) * _CrystalThicknessNegateFresnel);
    half thicknessMask = lerp(1.0h, thickness, saturate(_CrystalThicknessEmission));
    return saturate(edges + volumeMask * thicknessMask);
}

half CrystalResolveRampCoord(half rampMask, half fresnel)
{
    half remapped = 1.0h - pow(saturate(1.0h - rampMask), max(_CrystalRampExp, 0.001h));
    half rampFresnel = pow(saturate(1.0h - fresnel), max(_CrystalRampFresnelExp, 0.001h));
    half fresnelMask = saturate(pow(rampFresnel, max(_CrystalRampFresnelExp2, 0.001h)) + _CrystalRampFresnelAdd);
    return saturate(remapped * fresnelMask);
}

half3 CrystalResolveEmission(half rampCoord, half rampMask)
{
    half3 ramp = SAMPLE_TEXTURE2D(_CrystalRamp, sampler_CrystalRamp, float2(rampCoord, 0.5)).rgb * _CrystalRampTint.rgb;
    half emissionMask = pow(saturate(rampMask), max(_CrystalRampMainMaskExp, 0.001h));
    return ramp * emissionMask * _CrystalRampEmissionPower;
}

CrystalSurface CrystalResolveSurface(CrystalVaryings input)
{
    CrystalSurface surface;
    surface.viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
    half3 normalMapWS = CrystalResolveNormalWS(input);
    half3 sphericalNormalWS = CrystalSphericalNormalWS(input);
    surface.normalWS = normalize(lerp(normalMapWS, sphericalNormalWS, saturate(_CrystalNormalSpherical)));
    surface.fresnel = CrystalFresnel(surface.normalWS, surface.viewDirWS, _CrystalFresnelPower);

    CrystalMaskData masks = CrystalResolveMask(input, surface.viewDirWS);
    CrystalRaymarchOutput volume = CrystalRaymarch8(CrystalBuildRaymarchInput(input, surface.normalWS, surface.viewDirWS));
    half rampMask = CrystalResolveRampMask(volume, masks, surface.fresnel);
    half rampCoord = CrystalResolveRampCoord(rampMask, surface.fresnel);

    half3 baseColor = _CrystalBaseColor.rgb;
    half desaturateMask = pow(saturate(surface.fresnel), max(_CrystalDesaturateFresnelExp, 0.001h)) * masks.thicknessForDesaturate;
    half luma = dot(baseColor, half3(0.2126h, 0.7152h, 0.0722h));
    baseColor = lerp(baseColor, half3(luma, luma, luma) * _CrystalDesaturateLighten, desaturateMask * _CrystalDesaturateAmount);

    surface.color = baseColor;
    surface.emission = CrystalResolveEmission(rampCoord, rampMask);
    surface.metallic = CRYSTAL_SURFACE_METALLIC;
    surface.smoothness = CRYSTAL_SURFACE_SMOOTHNESS;
    surface.occlusion = saturate(_CrystalOcclusion);
    surface.alpha = saturate(_CrystalBaseColor.a);
    surface.volumeMain = volume.mainMask;
    surface.volumeSecondary = volume.secondaryMask;
    surface.rampCoord = rampCoord;
    surface.edges = masks.edges;
    surface.thickness = masks.thickness;
    return surface;
}

half3 CrystalShade(CrystalVaryings input, CrystalSurface surface)
{
    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light mainLight = GetMainLight(shadowCoord);

    half shadow = lerp(1.0h, mainLight.shadowAttenuation, saturate(_CrystalReceiveShadowStrength));
    half shadowLight = lerp(saturate(_CrystalShadowMinLight), 1.0h, shadow);
    half nDotL = saturate(dot(surface.normalWS, mainLight.direction));
    half directShape = lerp(0.25h, 1.0h, nDotL);
    half3 shadowedColor = lerp(surface.color * _CrystalShadowTint.rgb, surface.color, shadowLight);
    half3 color = shadowedColor * SampleSH(surface.normalWS) * _CrystalIndirectStrength * surface.occlusion;
    color += shadowedColor * mainLight.color * directShape * shadowLight;

    half3 halfDir = SafeNormalize(mainLight.direction + surface.viewDirWS);
    half nDotH = saturate(dot(surface.normalWS, halfDir));
    half specPower = exp2(lerp(5.0h, 12.0h, surface.smoothness));
    half dielectricSpec = lerp(0.04h, 1.0h, surface.metallic);
    color += pow(nDotH, specPower) * surface.smoothness * shadow * mainLight.color * CRYSTAL_PBR_SPECULAR_COLOR * CRYSTAL_PBR_SPECULAR_STRENGTH * dielectricSpec;

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, input.positionWS, half4(1.0h, 1.0h, 1.0h, 1.0h));
        half lightNdotL = saturate(dot(surface.normalWS, light.direction));
        half lightShadow = lerp(1.0h, light.shadowAttenuation, saturate(_CrystalReceiveShadowStrength));
        half lightShape = lerp(0.2h, 1.0h, lightNdotL) * light.distanceAttenuation * lightShadow;
        color += shadowedColor * light.color * lightShape;

        half3 lightHalfDir = SafeNormalize(light.direction + surface.viewDirWS);
        half lightNdotH = saturate(dot(surface.normalWS, lightHalfDir));
        color += pow(lightNdotH, specPower) * surface.smoothness * light.distanceAttenuation * lightShadow * light.color * CRYSTAL_PBR_SPECULAR_COLOR * CRYSTAL_PBR_SPECULAR_STRENGTH * dielectricSpec;
    }
    #endif

    return color + surface.emission;
}

half4 CrystalFragForward(CrystalVaryings input, bool isFront : SV_IsFrontFace) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    CrystalSurface surface = CrystalResolveSurface(input);
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
    return 0;
}

half4 CrystalFragDepthNormals(CrystalVaryings input, bool isFront : SV_IsFrontFace) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    CrystalSurface surface = CrystalResolveSurface(input);
    half3 normalWS = isFront ? surface.normalWS : -surface.normalWS;
    return half4(normalize(normalWS) * 0.5h + 0.5h, 1.0h);
}

#endif
