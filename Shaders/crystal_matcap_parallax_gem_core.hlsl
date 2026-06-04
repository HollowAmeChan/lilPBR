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

float CrystalGemFractalDensity(float3 position)
{
    float3 p = position * max(_CrystalGemParallaxScale, 0.001);
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

half3 CrystalGemParallaxLayer(CrystalVaryings input, CrystalSurface surface)
{
    if (_CrystalGemParallaxStrength <= 0.0 || _CrystalGemParallaxDepth <= 0.0)
    {
        return half3(0.0h, 0.0h, 0.0h);
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
    float travelDistance = max(sphereHit.y, 0.0);
    half coverage = saturate(0.35h + _CrystalGemParallaxDepth * 0.0625h);
    travelDistance *= coverage;

    if (travelDistance <= 0.0001)
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    half3 accumulated = half3(0.0h, 0.0h, 0.0h);
    half densityGain = lerp(0.85h, 1.25h, coverage);
    half contrast = lerp(0.55h, 1.85h, saturate((max(_CrystalGemParallaxContrast, 0.25h) - 0.25h) * 0.129032h));

    [unroll]
    for (int i = 0; i < 24; i++)
    {
        float stepT = (i + 0.5) * (1.0 / 24.0);
        float3 sampleOS = entryOS + rayDirectionOS * (travelDistance * stepT);
        float3 normalizedSample = sampleOS / radius;
        float bodyMask = saturate(1.0 - dot(normalizedSample, normalizedSample) * 0.55);
        float shellFloor = saturate(0.22 + 0.78 * coverage);
        float insideMask = saturate(max(bodyMask, shellFloor * 0.35));

        half density = CrystalGemFractalDensity(normalizedSample);
        density = pow(density * insideMask, contrast) * densityGain;

        float phaseA = sin(dot(normalizedSample, float3(11.31, 19.17, 7.73)) + stepT * 3.14159);
        float phaseB = sin(dot(normalizedSample.zxy, float3(17.41, 5.27, 13.83)) - stepT * 2.221);
        half proceduralPhase = saturate(0.5h + 0.25h * (phaseA + phaseB));
        half rampCoord = saturate(surface.rampCoord + density * 0.35h + proceduralPhase * 0.18h + stepT * 0.16h);
        half3 rampColor = SAMPLE_TEXTURE2D(_CrystalRamp, sampler_CrystalRamp, float2(rampCoord, 0.5)).rgb * _CrystalRampTint.rgb;
        half variation = saturate(_CrystalGemParallaxColorVariation);
        half paletteMask = saturate(proceduralPhase * 0.55h + density * 0.45h);
        half3 paletteColor = lerp(_CrystalGemParallaxTint.rgb, _CrystalGemParallaxSecondaryColor.rgb, paletteMask * variation);
        half3 densityProfile = half3(density * density, density, density * density * density);
        half3 densityColor = paletteColor * lerp(half3(density, density, density), densityProfile, variation);
        half3 sampleColor = lerp(densityColor, rampColor * paletteColor, saturate(_CrystalGemParallaxRampBlend));

        accumulated = accumulated * 0.985h + sampleColor * density * lerp(0.045h, 0.075h, coverage);
    }

    half volumeMask = saturate(dot(accumulated, half3(0.2126h, 0.7152h, 0.0722h)));
    half fresnelWeight = saturate(lerp(1.0h, surface.fresnel + volumeMask, saturate(_CrystalGemParallaxFresnel)));
    half3 reflectionFill = SampleSH(reflect(-surface.viewDirWS, surface.normalWS)) * surface.fresnel * 0.18h;
    half3 toned = log(1.0h + accumulated + reflectionFill);
    return toned * _CrystalGemParallaxStrength * fresnelWeight;
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
