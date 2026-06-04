#ifndef INCLUDED_LILPBR_CRYSTAL_MATCAP_PARALLAX_GEM_CORE
#define INCLUDED_LILPBR_CRYSTAL_MATCAP_PARALLAX_GEM_CORE

half CrystalGemClampRange(half value, half minValue, half maxValue)
{
    return min(max(value, minValue), maxValue);
}

half CrystalGemParallaxScale()
{
    return CrystalGemClampRange(_CrystalGemParallaxScale, 0.5h, 6.0h);
}

half CrystalGemParallaxDepth()
{
    return CrystalGemClampRange(_CrystalGemParallaxDepth, 0.0h, 16.0h);
}

half3 CrystalGemMatCap(CrystalSurface surface)
{
    float2 matcapUV = mul((float3x3)UNITY_MATRIX_V, normalize(surface.normalWS)).xy * 0.5 + 0.5;
    matcapUV = matcapUV * _CrystalGemMatCap_ST.xy + _CrystalGemMatCap_ST.zw;
    half3 matcap = SAMPLE_TEXTURE2D(_CrystalGemMatCap, sampler_CrystalGemMatCap, matcapUV).rgb * _CrystalGemMatCapColor.rgb;
    half edgeWeight = lerp(1.0h, surface.fresnel, saturate(_CrystalGemMatCapFresnel));
    return matcap * CrystalGemClampRange(_CrystalGemMatCapStrength, 0.0h, 4.0h) * edgeWeight;
}

float2 CrystalGemSphereIntersection(float3 rayOrigin, float3 rayDirection, float radius)
{
    float b = dot(rayOrigin, rayDirection);
    float c = dot(rayOrigin, rayOrigin) - radius * radius;
    float h = b * b - c;

    if (h <= 0.0)
    {
        return float2(0.0, 0.0);
    }

    h = sqrt(h);
    return float2(-b - h, -b + h);
}

float2 CrystalGemRotate2(float2 value, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    return float2(value.x * c - value.y * s, value.x * s + value.y * c);
}

struct CrystalGemInternalRay
{
    float3 entryOS;
    float3 directionOS;
    float radius;
    float travelDistance;
    half coverage;
};

half CrystalGemCoverage()
{
    return saturate(0.35h + CrystalGemParallaxDepth() * 0.0625h);
}

half CrystalGemShapeContrast()
{
    half contrast = CrystalGemClampRange(_CrystalGemParallaxContrast, 0.25h, 8.0h);
    half slider = saturate((contrast - 0.25h) * 0.129032h);
    return lerp(0.55h, 1.85h, slider);
}

bool CrystalGemBuildInternalRay(CrystalVaryings input, CrystalSurface surface, out CrystalGemInternalRay ray)
{
    ray = (CrystalGemInternalRay)0;
    if (_CrystalGemParallaxStrength <= 0.0 || CrystalGemParallaxDepth() <= 0.0h)
    {
        return false;
    }

    float3 cameraOS = mul(unity_WorldToObject, float4(GetCameraPositionWS(), 1.0)).xyz;
    float3 surfaceOS = input.positionOS;
    float3 rayDirectionOS = SafeNormalize(surfaceOS - cameraOS);
    float3 normalOS = SafeNormalize(TransformWorldToObjectDir(surface.normalWS, false));
    normalOS = dot(normalOS, rayDirectionOS) > 0.0 ? -normalOS : normalOS;

    float3 refractedDirectionOS = refract(rayDirectionOS, normalOS, 0.74);
    if (dot(refractedDirectionOS, refractedDirectionOS) > 0.0001)
    {
        rayDirectionOS = SafeNormalize(refractedDirectionOS);
    }

    float radius = max(length(surfaceOS), 0.35);
    float3 entryOS = surfaceOS + rayDirectionOS * max(radius * 0.002, 0.001);
    float2 sphereHit = CrystalGemSphereIntersection(entryOS, rayDirectionOS, radius);

    ray.entryOS = entryOS;
    ray.directionOS = rayDirectionOS;
    ray.radius = radius;
    ray.coverage = CrystalGemCoverage();
    ray.travelDistance = max(sphereHit.y, 0.0) * ray.coverage;
    return ray.travelDistance > 0.0001;
}

float CrystalGemFractalDensity(float3 position)
{
    float3 p = position * CrystalGemParallaxScale();
    float3 origin = p;
    float density = 0.0;

    [unroll]
    for (int i = 0; i < 6; i++)
    {
        p = 0.7 * abs(p) / max(dot(p, p), 0.001) - 0.7;
        p.yz = float2(p.y * p.y - p.z * p.z, 2.0 * p.y * p.z);
        p = p.zxy;
        density += exp(-19.0 * abs(dot(p, origin)));
    }

    return saturate(density * 0.5);
}

half CrystalGemInsideMask(float3 normalizedSample, half coverage)
{
    float bodyMask = saturate(1.0 - dot(normalizedSample, normalizedSample) * 0.55);
    float shellFloor = saturate(0.22 + 0.78 * coverage);
    return saturate(max(bodyMask, shellFloor * 0.35));
}

half CrystalGemVolumeDensity(float3 normalizedSample, half coverage, half contrast)
{
    half densityGain = lerp(0.85h, 1.25h, coverage);
    half insideMask = CrystalGemInsideMask(normalizedSample, coverage);
    half density = CrystalGemFractalDensity(normalizedSample);
    return pow(density * insideMask, contrast) * densityGain;
}

half CrystalGemVolumePhase(float3 normalizedSample, float stepT)
{
    float phaseA = sin(dot(normalizedSample, float3(11.31, 19.17, 7.73)) + stepT * 3.14159);
    float phaseB = sin(dot(normalizedSample.zxy, float3(17.41, 5.27, 13.83)) - stepT * 2.221);
    return saturate(0.5h + 0.25h * (phaseA + phaseB));
}

half3 CrystalGemPaletteBase(half density, half phase)
{
    half variation = saturate(_CrystalGemParallaxColorVariation);
    half paletteMask = saturate(phase * 0.55h + density * 0.45h);
    return max(lerp(_CrystalGemParallaxTint.rgb, _CrystalGemParallaxSecondaryColor.rgb, paletteMask * variation), half3(0.0h, 0.0h, 0.0h));
}

half3 CrystalGemPaletteColor(half density, half phase)
{
    half variation = saturate(_CrystalGemParallaxColorVariation);
    half3 paletteBase = CrystalGemPaletteBase(density, phase);
    half3 densityProfile = half3(density * density, density, density * density * density);
    return paletteBase * lerp(half3(density, density, density), densityProfile, variation);
}

half3 CrystalGemVolumeSampleColor(half density, half phase)
{
    return CrystalGemPaletteColor(density, phase);
}

half3 CrystalGemInternalVolume(CrystalVaryings input, CrystalSurface surface)
{
    CrystalGemInternalRay ray;
    if (!CrystalGemBuildInternalRay(input, surface, ray))
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    half3 accumulated = half3(0.0h, 0.0h, 0.0h);
    half contrast = CrystalGemShapeContrast();

    [unroll]
    for (int i = 0; i < 24; i++)
    {
        float stepT = (i + 0.5) * (1.0 / 24.0);
        float3 sampleOS = ray.entryOS + ray.directionOS * (ray.travelDistance * stepT);
        float3 normalizedSample = sampleOS / ray.radius;
        half density = CrystalGemVolumeDensity(normalizedSample, ray.coverage, contrast);
        half phase = CrystalGemVolumePhase(normalizedSample, stepT);
        half3 sampleColor = CrystalGemVolumeSampleColor(density, phase);
        accumulated = accumulated * 0.985h + sampleColor * density * lerp(0.045h, 0.075h, ray.coverage);
    }

    half volumeMask = saturate(dot(accumulated, half3(0.2126h, 0.7152h, 0.0722h)));
    half fresnelWeight = saturate(lerp(1.0h, surface.fresnel + volumeMask, saturate(_CrystalGemParallaxFresnel)));
    return accumulated * CrystalGemClampRange(_CrystalGemParallaxStrength, 0.0h, 4.0h) * fresnelWeight;
}

half3 CrystalGemHighlight(CrystalVaryings input, CrystalSurface surface)
{
    if (_CrystalGemHighlightStrength <= 0.0 || _CrystalGemHighlightSharpness <= 0.0)
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light mainLight = GetMainLight(shadowCoord);

    half sharpness = saturate(_CrystalGemHighlightSharpness);
    half specPower = exp2(lerp(4.0h, 8.0h, sharpness));
    half3 color = half3(0.0h, 0.0h, 0.0h);

    half3 halfDir = SafeNormalize(mainLight.direction + surface.viewDirWS);
    half nDotH = saturate(dot(surface.normalWS, halfDir));
    half shadow = lerp(1.0h, mainLight.shadowAttenuation, saturate(_CrystalReceiveShadowStrength));
    half highlightStrength = CrystalGemClampRange(_CrystalGemHighlightStrength, 0.0h, 8.0h);
    half3 highlightColor = max(_CrystalGemHighlightColor.rgb, half3(0.0h, 0.0h, 0.0h));
    color += pow(nDotH, specPower) * sharpness * shadow * mainLight.color * highlightColor * highlightStrength;

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, input.positionWS, half4(1.0h, 1.0h, 1.0h, 1.0h));
        half3 lightHalfDir = SafeNormalize(light.direction + surface.viewDirWS);
        half lightNdotH = saturate(dot(surface.normalWS, lightHalfDir));
        half lightShadow = lerp(1.0h, light.shadowAttenuation, saturate(_CrystalReceiveShadowStrength));
        color += pow(lightNdotH, specPower) * sharpness * light.distanceAttenuation * lightShadow * light.color * highlightColor * highlightStrength;
    }
    #endif

    return color;
}

half3 CrystalGemReflection(CrystalSurface surface)
{
    half fresnelPower = CrystalGemClampRange(_CrystalGemReflectionFresnel, 0.05h, 4.0h);
    half fresnel = pow(saturate(surface.fresnel), fresnelPower);
    half3 reflectionDirection = reflect(-surface.viewDirWS, surface.normalWS);
    return SampleSH(reflectionDirection) * fresnel * CrystalGemClampRange(_CrystalGemReflectionStrength, 0.0h, 1.0h);
}

struct CrystalGemComponents
{
    half3 baseLayer;
    half3 matCap;
    half3 reflection;
    half3 rampEmission;
    half3 internalVolume;
};

CrystalGemComponents CrystalGemResolveComponents(CrystalVaryings input, CrystalSurface surface)
{
    CrystalGemComponents components;
    components.baseLayer = surface.color;
    components.matCap = CrystalGemMatCap(surface);
    components.reflection = CrystalGemReflection(surface);
    components.rampEmission = surface.emission;
    components.internalVolume = CrystalGemInternalVolume(input, surface);
    return components;
}

half3 CrystalGemCompose(CrystalGemComponents components)
{
    half3 color = components.baseLayer
        + components.matCap
        + components.reflection
        + components.rampEmission
        + components.internalVolume;
    return max(color, half3(0.0h, 0.0h, 0.0h));
}

half3 CrystalGemShadeLighting(CrystalVaryings input, CrystalSurface surface)
{
    half3 color = CrystalShade(input, surface);
    color += CrystalGemHighlight(input, surface);
    return color;
}

half3 CrystalShadeMatCapParallaxGem(CrystalVaryings input, CrystalSurface surface)
{
    CrystalSurface composedSurface = surface;
    composedSurface.color = CrystalGemCompose(CrystalGemResolveComponents(input, surface));
    composedSurface.emission = half3(0.0h, 0.0h, 0.0h);
    return CrystalGemShadeLighting(input, composedSurface);
}

half4 CrystalFragMatCapParallaxGem(CrystalVaryings input, bool isFront : SV_IsFrontFace) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half4 mainTex = CrystalSampleMain(input);
    CrystalClipAlpha(mainTex.a);
    CrystalSurface surface = CrystalResolveSurface(input, mainTex);
    if (!isFront)
    {
        surface.normalWS = -surface.normalWS;
        surface.fresnel = CrystalFresnel(surface.normalWS, surface.viewDirWS, _CrystalFresnelPower);
    }

    return half4(CrystalShadeMatCapParallaxGem(input, surface), surface.alpha);
}

#endif
