#ifndef INCLUDED_LILPBR_CRYSTAL_GEM_COMPOSITE_CORE
#define INCLUDED_LILPBR_CRYSTAL_GEM_COMPOSITE_CORE

float3 _LightDirection;
float3 _LightPosition;

struct GemAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct GemVaryings
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

struct GemMask
{
    half edges;
    half thickness;
};

struct GemSurface
{
    half3 baseColor;
    half3 normalWS;
    half3 viewDirWS;
    half alpha;
    half fresnel;
    half fieldMain;
    half fieldSecondary;
    half fieldMask;
    half edges;
    half thickness;
};

struct FieldGlow
{
    half3 field;
    half3 glow;
};

struct GemLightingData
{
    Light mainLight;
    float3 shadowPositionWS;
    half screenSpaceAO;
};

struct FiberRay
{
    float3 entryOS;
    float3 directionOS;
    float radius;
    float travelDistance;
    half coverage;
};

struct GemComponents
{
    half3 baseLayer;
    half3 fieldGlow;
    half3 matCap;
    half3 dynamicFibers;
};

half GemClamp(half value, half minValue, half maxValue)
{
    return min(max(value, minValue), maxValue);
}

float2 GemRotate2(float2 value, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    return float2(value.x * c - value.y * s, value.x * s + value.y * c);
}

GemVaryings GemVert(GemAttributes input)
{
    GemVaryings output = (GemVaryings)0;
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

GemVaryings GemVertDepth(GemAttributes input)
{
    return GemVert(input);
}

GemVaryings GemVertShadowCaster(GemAttributes input)
{
    GemVaryings output = GemVert(input);
    half3 normalWS = normalize(output.normalWS);
    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
        half3 lightDirectionWS = SafeNormalize(_LightPosition - output.positionWS);
    #else
        half3 lightDirectionWS = _LightDirection;
    #endif

    output.positionWS -= lightDirectionWS * _ShadowCasterOffset;
    output.positionCS = TransformWorldToHClip(ApplyShadowBias(output.positionWS, normalWS, lightDirectionWS));
    #if UNITY_REVERSED_Z
        output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
        output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif
    return output;
}

half4 GemSampleMain(GemVaryings input)
{
    float2 uv = input.uv * _MainTex_ST.xy + _MainTex_ST.zw;
    return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
}

void GemClipAlpha(half alpha)
{
    clip(alpha - saturate(_Cutoff));
}

half3x3 GemTangentToWorld(GemVaryings input)
{
    half3 normalWS = normalize(input.normalWS);
    half3 tangentWS = normalize(input.tangentWS.xyz);
    half3 bitangentWS = normalize(cross(normalWS, tangentWS) * input.tangentWS.w);
    return half3x3(tangentWS, bitangentWS, normalWS);
}

half GemFresnel(half3 normalWS, half3 viewDirWS, half power)
{
    return pow(saturate(1.0h - dot(normalWS, viewDirWS)), max(power, 0.001h));
}

half3 GemResolveNormalWS(GemVaryings input)
{
    half3 normalTS = UnpackNormalScale(
        SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv * _NormalMap_ST.xy + _NormalMap_ST.zw),
        _NormalStrength);
    half3 mapNormalWS = normalize(mul(normalTS, GemTangentToWorld(input)));
    half3 sphericalNormalWS = normalize(TransformObjectToWorldNormal(SafeNormalize(input.positionOS)));
    return normalize(lerp(mapNormalWS, sphericalNormalWS, saturate(_SphericalNormalBlend)));
}

float2 GemParallaxMaskUV(GemVaryings input, half3 viewDirWS, half parallaxScale)
{
    half3x3 tangentToWorld = GemTangentToWorld(input);
    half3 viewDirTS = mul(transpose(tangentToWorld), viewDirWS);
    float2 baseUV = input.uv * _MaskTex_ST.xy + _MaskTex_ST.zw;
    float height = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, baseUV).g;
    float2 parallax = viewDirTS.xy / max(abs(viewDirTS.z), 0.25h) * (height - 0.5h) * parallaxScale * 0.002;
    return baseUV - parallax;
}

GemMask GemResolveMask(GemVaryings input, half3 viewDirWS)
{
    float2 maskUV = GemParallaxMaskUV(input, viewDirWS, 4.0h);
    half4 mask = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, maskUV);

    GemMask data;
    data.edges = saturate(mask.r);
    data.thickness = saturate(mask.g);
    return data;
}

float3 GemObjectScale()
{
    return float3(
        length(float3(unity_ObjectToWorld._m00, unity_ObjectToWorld._m10, unity_ObjectToWorld._m20)),
        length(float3(unity_ObjectToWorld._m01, unity_ObjectToWorld._m11, unity_ObjectToWorld._m21)),
        length(float3(unity_ObjectToWorld._m02, unity_ObjectToWorld._m12, unity_ObjectToWorld._m22)));
}

void GemResolveVolumeSpace(GemVaryings input, half3 normalWS, half3 viewDirWS, out float3 position, out float3 normal, out float3 viewDirection)
{
    if (_VolumeSpace < 0.5)
    {
        position = input.positionWS;
        normal = normalWS;
        viewDirection = viewDirWS;
    }
    else
    {
        float3 localPosition = input.positionOS;
        if (_VolumeSpace > 1.5)
        {
            localPosition *= GemObjectScale();
        }
        position = localPosition;
        normal = TransformWorldToObjectDir(normalWS, false);
        viewDirection = TransformWorldToObjectDir(viewDirWS, false);
    }

    position += _VolumeOffset.xyz;
}

half GemRefractionSurfaceNoise(GemVaryings input, half3 viewDirWS)
{
    if (_UseSurfaceNoise == 0)
    {
        return 1.0h;
    }

    half3x3 tangentToWorld = GemTangentToWorld(input);
    half3 viewDirTS = mul(transpose(tangentToWorld), viewDirWS);
    float2 uv = input.uv * _SurfaceNoise_ST.xy + _SurfaceNoise_ST.zw;
    uv -= viewDirTS.xy / max(abs(viewDirTS.z), 0.25h) * _SurfaceNoiseParallax * 0.002;
    half noise = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, uv * _SurfaceNoiseScale).r;
    return saturate(lerp(1.0h, noise, _SurfaceNoiseStrength));
}

half2 CrystalInternalField(GemVaryings input, GemSurface surface)
{
    if (_FieldStrength <= 0.0h && _GlowStrength <= 0.0h)
    {
        return half2(0.0h, 0.0h);
    }

    float3 position;
    float3 normal;
    float3 viewDirection;
    GemResolveVolumeSpace(input, surface.normalWS, surface.viewDirWS, position, normal, viewDirection);

    float surfaceNoise = max(GemRefractionSurfaceNoise(input, surface.viewDirWS), 0.001);
    float3 rayDir = SafeNormalize(-viewDirection);
    float eta = saturate(1.0 - (surfaceNoise / max(_InternalRayBend, 0.001)));
    float3 bentDir = refract(rayDir, SafeNormalize(normal), eta);
    if (dot(bentDir, bentDir) > 0.0001)
    {
        rayDir = SafeNormalize(bentDir);
    }

    half mainMask = 0.0h;
    half secondaryMask = 0.0h;
    float stepDistance = _StepLength * 0.125;

    [unroll]
    for (int i = 0; i < 8; i++)
    {
        float stepT = (i + 0.5) * 0.125;
        float3 samplePosition = position + rayDir * (stepDistance * (i + 1));
        float2 uvX = samplePosition.yz * _VolumeNoiseScale;
        float2 uvY = samplePosition.zx * _VolumeNoiseScale;
        float2 uvZ = samplePosition.xy * _VolumeNoiseScale;
        half4 noiseX = SAMPLE_TEXTURE2D(_VolumeNoise, sampler_VolumeNoise, uvX);
        half4 noiseY = SAMPLE_TEXTURE2D(_VolumeNoise, sampler_VolumeNoise, uvY);
        half4 noiseZ = SAMPLE_TEXTURE2D(_VolumeNoise, sampler_VolumeNoise, uvZ);
        half2 noise = noiseX.rg * noiseY.rg * noiseZ.rg;

        half stepFade = saturate(1.0h - stepT * _FieldStepFade);
        half mainSample = pow(saturate(noise.r), max(_VolumeMainPower, 0.001h)) * _VolumeMainMultiply * 1.45h;
        half secondarySample = pow(saturate(noise.g), max(_VolumeSecondaryPower, 0.001h)) * _VolumeSecondaryMultiply * 2.0h;
        mainMask += saturate(pow(saturate(mainSample), _FieldMaskPower)) * stepFade;
        secondaryMask += saturate(secondarySample) * stepFade;
    }

    return saturate(half2(mainMask, secondaryMask));
}

half CrystalGlowMask(GemSurface surface)
{
    half volumeMask = saturate(surface.fieldMain + surface.fieldSecondary * _VolumeSecondaryIntersect);
    half thicknessMask = lerp(1.0h, surface.thickness, saturate(_GlowThicknessWeight));
    half edgeMask = surface.edges * max(_GlowEdgeWeight, 0.0h);
    half fresnelMask = surface.fresnel * saturate(_GlowFresnelWeight);
    half mask = saturate(pow(saturate(volumeMask), max(_FieldMaskPower, 0.001h)) * thicknessMask + edgeMask + fresnelMask);
    half contrast = max(_GlowContrast, 0.001h);
    return saturate((mask - 0.5h) * contrast + 0.5h);
}

FieldGlow CrystalResolveFieldGlow(GemSurface surface)
{
    FieldGlow result;
    result = (FieldGlow)0;

    half volumeMask = saturate(surface.fieldMain + surface.fieldSecondary * _VolumeSecondaryIntersect);
    half glowMask = CrystalGlowMask(surface);
    half3 ramp = SAMPLE_TEXTURE2D(_GlowRamp, sampler_GlowRamp, float2(glowMask, 0.5)).rgb * _GlowTint.rgb;

    result.field = ramp * volumeMask * GemClamp(_FieldStrength, 0.0h, 4.0h);
    result.glow = ramp * glowMask * GemClamp(_GlowStrength, 0.0h, 8.0h);
    return result;
}

void GemApplyBaseColorProcess(GemMask masks, inout GemSurface surface)
{
    half strength = saturate(_ColorProcessStrength);
    half thicknessMask = saturate(masks.thickness * saturate(_ThicknessTintStrength));
    half edgeMask = saturate(masks.edges * saturate(_EdgeTintStrength));
    half fresnelMask = pow(saturate(surface.fresnel), max(_FresnelTintPower, 0.001h)) * saturate(_FresnelTintStrength);
    half3 depthTint = lerp(max(_OuterTint.rgb, half3(0.0h, 0.0h, 0.0h)), max(_InnerTint.rgb, half3(0.0h, 0.0h, 0.0h)), thicknessMask);
    half3 edgeTint = max(_EdgeTint.rgb, half3(0.0h, 0.0h, 0.0h));
    half3 finalTint = lerp(depthTint, edgeTint, saturate(edgeMask + fresnelMask));
    surface.baseColor = lerp(surface.baseColor, surface.baseColor * finalTint, strength);
}

GemSurface GemResolveSurface(GemVaryings input, half4 mainTex, bool resolveField)
{
    GemSurface surface = (GemSurface)0;
    surface.viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
    surface.normalWS = GemResolveNormalWS(input);
    surface.fresnel = GemFresnel(surface.normalWS, surface.viewDirWS, _FresnelPower);

    half4 baseTex = mainTex * _BaseColor;
    surface.baseColor = baseTex.rgb;
    surface.alpha = saturate(baseTex.a);

    GemMask masks = GemResolveMask(input, surface.viewDirWS);
    GemApplyBaseColorProcess(masks, surface);

    half2 field = half2(0.0h, 0.0h);
    if (resolveField)
    {
        field = CrystalInternalField(input, surface);
    }
    surface.fieldMain = field.x;
    surface.fieldSecondary = field.y;
    surface.fieldMask = saturate(field.x + field.y * _VolumeSecondaryIntersect);
    surface.edges = masks.edges;
    surface.thickness = masks.thickness;
    return surface;
}

half3 CrystalMatCap(GemSurface surface)
{
    if (_MatCapStrength <= 0.0h)
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    float2 matcapUV = mul((float3x3)UNITY_MATRIX_V, normalize(surface.normalWS)).xy * 0.5 + 0.5;
    matcapUV = matcapUV * _MatCapTex_ST.xy + _MatCapTex_ST.zw;
    half3 matcap = SAMPLE_TEXTURE2D(_MatCapTex, sampler_MatCapTex, matcapUV).rgb * _MatCapColor.rgb;
    half edgeWeight = lerp(1.0h, surface.fresnel, saturate(_MatCapFresnel));
    return matcap * edgeWeight;
}

half3 CrystalApplyMatCapBlend(half3 color, half3 matcap)
{
    half strength = GemClamp(_MatCapStrength, 0.0h, 4.0h);
    if (strength <= 0.0h)
    {
        return color;
    }

    half mode = floor(GemClamp(_MatCapBlendMode, 0.0h, 2.0h) + 0.5h);
    if (mode < 0.5h)
    {
        return color + matcap * strength;
    }

    half weight = saturate(strength);
    half3 blendColor = saturate(matcap);

    if (mode < 1.5h)
    {
        return color * lerp(half3(1.0h, 1.0h, 1.0h), blendColor, weight);
    }

    half3 base = saturate(color);
    half3 overflow = max(color - base, half3(0.0h, 0.0h, 0.0h));

    half3 screen = 1.0h - (1.0h - base) * (1.0h - blendColor);
    return overflow + lerp(base, screen, weight);
}

float2 FiberSphereIntersection(float3 rayOrigin, float3 rayDirection, float radius)
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

half FiberScale()
{
    return GemClamp(_FiberScale, 0.5h, 6.0h);
}

half FiberDepth()
{
    return GemClamp(_FiberDepth, 0.0h, 16.0h);
}

half FiberMode()
{
    return floor(GemClamp(_FiberMode, 0.0h, 2.0h) + 0.5h);
}

half FiberFlowSpeed()
{
    return GemClamp(_FiberFlowSpeed, 0.0h, 4.0h);
}

half FiberFlowStrength()
{
    return saturate(_FiberFlowStrength);
}

float FiberTime()
{
    return _Time.y * FiberFlowSpeed() + _FiberFlowPhase;
}

float2 FiberFoldParams(float baseFold, float baseOffset)
{
    half flowStrength = FiberFlowStrength();
    float time = FiberTime();
    float animatedFold = sin(time * 0.35432) * 0.7 + 1.5;
    float animatedOffset = -0.4 + sin(time * 0.2443) * 0.3;
    return float2(lerp(baseFold, animatedFold, flowStrength), lerp(baseOffset, animatedOffset, flowStrength));
}

float3 FiberAnimatePosition(float3 position, float stepT)
{
    half flowStrength = FiberFlowStrength();
    float time = FiberTime();
    float3 p = position;
    p.xy = GemRotate2(p.xy, sin(time * 0.177 + stepT * 2.1) * flowStrength * 0.45);
    p.yz = GemRotate2(p.yz, sin(time * 0.131 - stepT * 1.7) * flowStrength * 0.35);
    p += float3(
        sin(time * 0.35432 + position.y * 2.0 + stepT * 2.7),
        sin(time * 0.2443 + position.z * 2.3 - stepT * 2.1),
        sin(time * 0.193 + position.x * 1.7)
    ) * (0.18 * flowStrength);
    return p;
}

half FiberCoverage()
{
    return saturate(0.35h + FiberDepth() * 0.0625h);
}

half FiberShapeContrast()
{
    half contrast = GemClamp(_FiberSharpness, 0.25h, 8.0h);
    half slider = saturate((contrast - 0.25h) * 0.129032h);
    return lerp(0.55h, 1.85h, slider);
}

bool FiberBuildRay(GemVaryings input, GemSurface surface, out FiberRay ray)
{
    ray = (FiberRay)0;
    if (_FiberBrightness <= 0.0 || FiberDepth() <= 0.0h)
    {
        return false;
    }

    float3 cameraOS = mul(unity_WorldToObject, float4(GetCameraPositionWS(), 1.0)).xyz;
    float3 surfaceOS = input.positionOS;
    float3 rayDirectionOS = SafeNormalize(surfaceOS - cameraOS);
    float3 normalOS = SafeNormalize(TransformWorldToObjectDir(surface.normalWS, false));
    normalOS = dot(normalOS, rayDirectionOS) > 0.0 ? -normalOS : normalOS;

    float surfaceNoise = max(GemRefractionSurfaceNoise(input, surface.viewDirWS), 0.001);
    float eta = saturate(1.0 - (surfaceNoise / max(_InternalRayBend, 0.001)));
    float3 refractedDirectionOS = refract(rayDirectionOS, normalOS, eta);
    if (dot(refractedDirectionOS, refractedDirectionOS) > 0.0001)
    {
        rayDirectionOS = SafeNormalize(refractedDirectionOS);
    }

    float radius = max(length(surfaceOS), 0.35);
    float3 entryOS = surfaceOS + rayDirectionOS * max(radius * 0.002, 0.001);
    float2 sphereHit = FiberSphereIntersection(entryOS, rayDirectionOS, radius);

    ray.entryOS = entryOS;
    ray.directionOS = rayDirectionOS;
    ray.radius = radius;
    ray.coverage = FiberCoverage();
    ray.travelDistance = max(sphereHit.y, 0.0) * ray.coverage;
    return ray.travelDistance > 0.0001;
}

float FiberFractalDensity(float3 position)
{
    float2 foldParams = FiberFoldParams(0.7, -0.7);
    float3 p = position * FiberScale();
    float3 origin = p;
    float density = 0.0;

    [unroll]
    for (int i = 0; i < 6; i++)
    {
        p = foldParams.x * abs(p) / max(dot(p, p), 0.001) + foldParams.y;
        p.yz = float2(p.y * p.y - p.z * p.z, 2.0 * p.y * p.z);
        p = p.zxy;
        density += exp(-19.0 * abs(dot(p, origin)));
    }

    return saturate(density * 0.5);
}

float FiberMarbleDensity(float3 position)
{
    float3 p = position * FiberScale();
    float time = FiberTime();
    half flowStrength = FiberFlowStrength();
    float3 layerDir = normalize(float3(0.78, 0.34, 0.52));
    float3 crossDir = normalize(float3(-0.42, 0.86, 0.28));
    float lowWarp = sin(dot(p, float3(1.73, 2.11, 0.91)) + time * 0.31) * lerp(0.28, 0.85, flowStrength);
    float crossWarp = sin(dot(p, float3(-1.21, 0.73, 2.47)) - time * 0.23) * lerp(0.18, 0.55, flowStrength);
    float layer = dot(p, layerDir) + lowWarp + crossWarp * 0.55;
    float broad = 0.5 + 0.5 * sin(layer * 4.6);
    float fine = 0.5 + 0.5 * sin((layer + dot(p, crossDir) * 0.18) * 17.0 + broad * 2.4);
    float cloudy = 0.5 + 0.5 * sin(dot(p, float3(2.31, -1.17, 1.63)) * 3.1 + lowWarp * 2.0);
    float density = broad * 0.58 + fine * 0.27 + cloudy * 0.15;
    return saturate(smoothstep(0.18, 0.92, density));
}

float FiberVeinDensity(float3 position)
{
    float3 p = position * FiberScale();
    float folded = FiberFractalDensity(position * 0.75);
    float veinA = sin(dot(p, float3(7.13, 11.71, 5.41)) + folded * 4.0);
    float veinB = sin(dot(p.zxy, float3(13.31, 4.17, 8.69)) - folded * 2.5);
    float bands = 1.0 - abs(veinA * 0.65 + veinB * 0.35);
    return saturate(pow(saturate(bands), 3.0) * (0.45 + folded));
}

half FiberDensity(float3 normalizedSample, half mode)
{
    if (mode < 0.5h)
    {
        return FiberFractalDensity(normalizedSample);
    }

    if (mode < 1.5h)
    {
        return FiberMarbleDensity(normalizedSample);
    }

    return FiberVeinDensity(normalizedSample);
}

half FiberInsideMask(float3 normalizedSample, half coverage)
{
    float bodyMask = saturate(1.0 - dot(normalizedSample, normalizedSample) * 0.55);
    float shellFloor = saturate(0.22 + 0.78 * coverage);
    return saturate(max(bodyMask, shellFloor * 0.35));
}

half FiberVolumeDensity(float3 normalizedSample, float3 impuritySample, half coverage, half contrast, half mode)
{
    half densityGain = lerp(0.85h, 1.25h, coverage);
    half insideMask = FiberInsideMask(normalizedSample, coverage);
    half density = FiberDensity(impuritySample, mode);
    return pow(density * insideMask, contrast) * densityGain;
}

half FiberPhase(float3 normalizedSample, float stepT)
{
    float phaseA = sin(dot(normalizedSample, float3(11.31, 19.17, 7.73)) + stepT * 3.14159);
    float phaseB = sin(dot(normalizedSample.zxy, float3(17.41, 5.27, 13.83)) - stepT * 2.221);
    return saturate(0.5h + 0.25h * (phaseA + phaseB));
}

half3 FiberPaletteBase(half density, half phase)
{
    half variation = saturate(_FiberColorVariation);
    half paletteMask = saturate(phase * 0.55h + density * 0.45h);
    return max(lerp(_FiberMainColor.rgb, _FiberSecondaryColor.rgb, paletteMask * variation), half3(0.0h, 0.0h, 0.0h));
}

half3 FiberPaletteColor(half density, half phase)
{
    half variation = saturate(_FiberColorVariation);
    half3 paletteBase = FiberPaletteBase(density, phase);
    half3 densityProfile = half3(density * density, density, density * density * density);
    return paletteBase * lerp(half3(density, density, density), densityProfile, variation);
}

half3 FiberMarblePaletteColor(half density, half phase)
{
    half variation = saturate(_FiberColorVariation);
    half band = pow(abs(cos(density * 4.712h + phase * 1.5h)), lerp(4.0h, 16.0h, variation));
    half colorMask = saturate(lerp(phase * 0.45h + density * 0.55h, band, variation));
    half3 tint = max(lerp(_FiberMainColor.rgb, _FiberSecondaryColor.rgb, colorMask), half3(0.0h, 0.0h, 0.0h));
    return tint * lerp(density, 1.0h, band) * (0.35h + band * 0.65h);
}

half3 FiberVeinPaletteColor(half density, half phase)
{
    half variation = saturate(_FiberColorVariation);
    half veinMask = pow(saturate(density), lerp(0.55h, 1.5h, variation));
    half3 tint = max(lerp(_FiberSecondaryColor.rgb, _FiberMainColor.rgb, saturate(phase * 0.35h + density * 0.65h)), half3(0.0h, 0.0h, 0.0h));
    return tint * veinMask;
}

half3 FiberSampleColor(half density, half phase, half mode)
{
    if (mode < 0.5h)
    {
        return FiberPaletteColor(density, phase);
    }

    if (mode < 1.5h)
    {
        return FiberMarblePaletteColor(density, phase);
    }

    return FiberVeinPaletteColor(density, phase);
}

half FiberPersistence(half mode)
{
    if (mode < 0.5h)
    {
        return 0.985h;
    }

    if (mode < 1.5h)
    {
        return 0.99h;
    }

    return 0.975h;
}

half FiberStepWeight(half density, half coverage, half mode)
{
    if (mode < 1.5h && mode >= 0.5h)
    {
        return lerp(0.035h, 0.06h, coverage);
    }

    if (mode >= 1.5h)
    {
        return density * lerp(0.065h, 0.105h, coverage);
    }

    return density * lerp(0.045h, 0.075h, coverage);
}

half3 CrystalDynamicFibers(GemVaryings input, GemSurface surface)
{
    half impurityStrength = saturate(_FiberStrength);
    if (impurityStrength <= 0.0h)
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    FiberRay ray;
    if (!FiberBuildRay(input, surface, ray))
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    half3 accumulated = half3(0.0h, 0.0h, 0.0h);
    half contrast = FiberShapeContrast();
    half mode = FiberMode();
    half persistence = FiberPersistence(mode);

    [unroll]
    for (int i = 0; i < 24; i++)
    {
        float stepT = (i + 0.5) * (1.0 / 24.0);
        float3 sampleOS = ray.entryOS + ray.directionOS * (ray.travelDistance * stepT);
        float3 normalizedSample = sampleOS / ray.radius;
        float3 impuritySample = FiberAnimatePosition(normalizedSample, stepT);
        half density = FiberVolumeDensity(normalizedSample, impuritySample, ray.coverage, contrast, mode);
        half phase = FiberPhase(impuritySample, stepT);
        half3 sampleColor = FiberSampleColor(density, phase, mode);
        accumulated = accumulated * persistence + sampleColor * FiberStepWeight(density, ray.coverage, mode);
    }

    half volumeMask = saturate(dot(accumulated, half3(0.2126h, 0.7152h, 0.0722h)));
    half fresnelWeight = saturate(lerp(1.0h, surface.fresnel + volumeMask, saturate(_FiberFresnel)));
    return accumulated * GemClamp(_FiberBrightness, 0.0h, 4.0h) * fresnelWeight * impurityStrength;
}

half GemApplyShadowStrength(half shadow, half strength)
{
    return lerp(1.0h, saturate(shadow), saturate(strength));
}

half GemSampleScreenSpaceAO(GemVaryings input)
{
    half screenSpaceAO = 1.0h;
    #if defined(_SCREEN_SPACE_OCCLUSION)
        AmbientOcclusionFactor ssao = GetScreenSpaceAmbientOcclusion(GetNormalizedScreenSpaceUV(input.positionCS));
        screenSpaceAO = ssao.indirectAmbientOcclusion;
    #endif
    return GemApplyShadowStrength(screenSpaceAO, _SSAOStrength);
}

half3 GemApplySSAOTint(half3 color, half screenSpaceAO)
{
    return lerp(color * _SSAOTint.rgb, color, saturate(screenSpaceAO));
}

half GemTooningScale(half value, half border, half blur)
{
    half borderMin = border - blur * 0.5h;
    half borderMax = border + blur * 0.5h;
    half width = max(borderMax - borderMin + fwidth(value), 0.0001h);
    return saturate((saturate(value) - borderMin) / width);
}

half GemApplyShadowBoundaryBlur(half shadow)
{
    return GemTooningScale(shadow, saturate(_ShadowBorder), max(_ShadowBlur, 0.0h));
}

half GemResolveDirectShapeShadow(half nDotL)
{
    return GemApplyShadowBoundaryBlur(nDotL);
}

half GemResolveMainLightShadowCast(half urpShadow)
{
    half shadowCast = GemApplyShadowBoundaryBlur(urpShadow);
    return lerp(1.0h, shadowCast, saturate(_ShadowCastStrength));
}

half GemResolveShadowAttenuation(half urpShadow, half lightShapeShadow)
{
    half shadowCast = GemResolveMainLightShadowCast(urpShadow);
    half rawShadow = saturate(shadowCast * saturate(lightShapeShadow));
    return GemApplyShadowStrength(rawShadow, _ShadowStrength);
}

half GemResolveDiffuseShadowMix(half urpShadow, half nDotL)
{
    half lightShapeShadow = GemResolveDirectShapeShadow(nDotL);
    return GemResolveShadowAttenuation(urpShadow, lightShapeShadow);
}

half3 GemSampleShadowRamp(half shadowAmount)
{
    return SAMPLE_TEXTURE2D(_ShadowRamp, sampler_ShadowRamp, float2(saturate(shadowAmount), 0.5)).rgb;
}

half3 GemResolveShadowLayerColor(half3 layerColor, half shadowMix)
{
    half shadowAmount = saturate(1.0h - shadowMix);
    half3 rampShadowColor = layerColor * GemSampleShadowRamp(shadowAmount);
    return lerp(half3(0.0h, 0.0h, 0.0h), rampShadowColor, saturate(_ShadowRampStrength));
}

half3 CrystalShadow(half3 layerColor, half3 lightColor, half lightShape, half shadowMix)
{
    half3 litLayer = layerColor * lightColor * lightShape;
    half3 shadowLayer = GemResolveShadowLayerColor(layerColor, shadowMix) * lightColor * lightShape;
    return lerp(shadowLayer, litLayer, saturate(shadowMix));
}

GemLightingData GemResolveLighting(GemVaryings input, GemSurface surface)
{
    GemLightingData lighting;
    lighting.shadowPositionWS = input.positionWS + surface.normalWS * _ShadowReceiveOffset;
    lighting.mainLight = GetMainLight(TransformWorldToShadowCoord(lighting.shadowPositionWS));
    lighting.screenSpaceAO = GemSampleScreenSpaceAO(input);
    return lighting;
}

half3 CrystalEnvironment(GemSurface surface, half3 layerColor, GemLightingData lighting)
{
    half3 ambientColor = GemApplySSAOTint(layerColor, lighting.screenSpaceAO);
    return ambientColor * SampleSH(surface.normalWS) * GemClamp(_EnvironmentStrength, 0.0h, 4.0h);
}

half3 GemDirectLights(GemVaryings input, GemSurface surface, half3 layerColor, GemLightingData lighting)
{
    half3 color = half3(0.0h, 0.0h, 0.0h);
    half lightFacing = dot(surface.normalWS, lighting.mainLight.direction) * 0.5h + 0.5h;
    half shadowMix = GemResolveDiffuseShadowMix(lighting.mainLight.shadowAttenuation, lightFacing);
    color += CrystalShadow(layerColor, lighting.mainLight.color, lighting.mainLight.distanceAttenuation, shadowMix);

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, input.positionWS);
        half lightFacingAdditional = dot(surface.normalWS, light.direction) * 0.5h + 0.5h;
        half lightShadowMix = GemResolveDiffuseShadowMix(1.0h, lightFacingAdditional);
        color += CrystalShadow(layerColor, light.color, light.distanceAttenuation, lightShadowMix);
    }
    #endif

    return color * GemClamp(_DirectLightStrength, 0.0h, 4.0h);
}

half3 CrystalHighlight(GemVaryings input, GemSurface surface, GemLightingData lighting)
{
    if (_HighlightStrength <= 0.0 || _HighlightSharpness <= 0.0)
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    half sharpness = saturate(_HighlightSharpness);
    half specPower = exp2(lerp(4.0h, 8.0h, sharpness));
    half3 color = half3(0.0h, 0.0h, 0.0h);
    half3 highlightColor = max(_HighlightColor.rgb, half3(0.0h, 0.0h, 0.0h));
    half strength = GemClamp(_HighlightStrength, 0.0h, 8.0h);

    half3 halfDir = SafeNormalize(lighting.mainLight.direction + surface.viewDirWS);
    half nDotH = saturate(dot(surface.normalWS, halfDir));
    color += pow(nDotH, specPower) * sharpness * lighting.mainLight.distanceAttenuation * lighting.mainLight.color * highlightColor * strength;

    #if defined(_ADDITIONAL_LIGHTS)
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, input.positionWS);
        half3 lightHalfDir = SafeNormalize(light.direction + surface.viewDirWS);
        half lightNdotH = saturate(dot(surface.normalWS, lightHalfDir));
        color += pow(lightNdotH, specPower) * sharpness * light.distanceAttenuation * light.color * highlightColor * strength;
    }
    #endif

    return color;
}

half3 CrystalReflection(GemVaryings input, GemSurface surface)
{
    half strength = GemClamp(_ReflectionStrength, 0.0h, 1.0h);
    if (strength <= 0.0h)
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    half fresnelPower = GemClamp(_ReflectionFresnel, 0.05h, 4.0h);
    half fresnel = pow(saturate(surface.fresnel), fresnelPower);
    half3 reflectionDirection = reflect(-surface.viewDirWS, surface.normalWS);
    half perceptualRoughness = saturate(_ReflectionRoughness);
    half3 reflection = GlossyEnvironmentReflection(
        reflectionDirection,
        input.positionWS,
        perceptualRoughness,
        1.0h,
        GetNormalizedScreenSpaceUV(input.positionCS)
    );
    return reflection * fresnel * strength;
}

GemComponents CrystalGemResolveComponents(GemVaryings input, GemSurface surface)
{
    GemComponents components;
    FieldGlow fieldGlow = CrystalResolveFieldGlow(surface);

    components.baseLayer = max(surface.baseColor, half3(0.0h, 0.0h, 0.0h));
    components.fieldGlow = max(fieldGlow.field + fieldGlow.glow, half3(0.0h, 0.0h, 0.0h));
    components.matCap = max(CrystalMatCap(surface), half3(0.0h, 0.0h, 0.0h));
    components.dynamicFibers = max(CrystalDynamicFibers(input, surface), half3(0.0h, 0.0h, 0.0h));
    return components;
}

half3 CrystalGemComposite(GemVaryings input, GemSurface surface)
{
    GemComponents components = CrystalGemResolveComponents(input, surface);
    GemLightingData lighting = GemResolveLighting(input, surface);

    half3 color = half3(0.0h, 0.0h, 0.0h);
    color += CrystalEnvironment(surface, components.baseLayer, lighting);
    color += GemDirectLights(input, surface, components.baseLayer, lighting);
    color = CrystalApplyMatCapBlend(color, components.matCap);
    color += components.fieldGlow;
    color += components.dynamicFibers;
    color += CrystalHighlight(input, surface, lighting);
    color += CrystalReflection(input, surface);
    return max(color, half3(0.0h, 0.0h, 0.0h));
}

half4 GemFragForward(GemVaryings input, bool isFront : SV_IsFrontFace) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half4 mainTex = GemSampleMain(input);
    GemClipAlpha(mainTex.a);
    GemSurface surface = GemResolveSurface(input, mainTex, true);
    if (!isFront)
    {
        surface.normalWS = -surface.normalWS;
        surface.fresnel = GemFresnel(surface.normalWS, surface.viewDirWS, _FresnelPower);
    }

    return half4(CrystalGemComposite(input, surface), 1.0h);
}

half4 GemFragDepth(GemVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    GemClipAlpha(GemSampleMain(input).a);
    return 0;
}

half4 GemFragDepthNormals(GemVaryings input, bool isFront : SV_IsFrontFace) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half4 mainTex = GemSampleMain(input);
    GemClipAlpha(mainTex.a);
    GemSurface surface = GemResolveSurface(input, mainTex, false);
    half3 normalWS = isFront ? surface.normalWS : -surface.normalWS;
    return half4(normalize(normalWS) * 0.5h + 0.5h, 1.0h);
}

#endif
