#ifndef INCLUDED_LILPBR_CRYSTAL_GEM_TRANSPARENT_CORE
#define INCLUDED_LILPBR_CRYSTAL_GEM_TRANSPARENT_CORE

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
    half3 fieldGlow;
    half3 matCap;
    half3 dynamicFibers;
    half3 fire;
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

half3 GemSaturateColor(half3 color, half saturation)
{
    half luminance = dot(color, half3(0.2126h, 0.7152h, 0.0722h));
    return max(lerp(half3(luminance, luminance, luminance), color, max(saturation, 0.0h)), half3(0.0h, 0.0h, 0.0h));
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

half4 GemSampleMain(GemVaryings input)
{
    float2 uv = input.uv * _MainTex_ST.xy + _MainTex_ST.zw;
    return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
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

half GemShapeMask(half value, half strength, half power, half contrast, half offset)
{
    half shaped = saturate(value + offset);
    shaped = pow(shaped, max(power, 0.001h));
    shaped = saturate((shaped - 0.5h) * contrast + 0.5h);
    return saturate(shaped * strength);
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
    float2 parallax = viewDirTS.xy / max(abs(viewDirTS.z), 0.25h) * (height - 0.5h) * parallaxScale * _ThicknessParallaxStrength * 0.002;
    return baseUV - parallax;
}

GemMask GemResolveMask(GemVaryings input, half3 viewDirWS)
{
    float2 maskUV = GemParallaxMaskUV(input, viewDirWS, 4.0h);
    half4 mask = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, maskUV);

    GemMask data;
    data.edges = GemShapeMask(mask.r, _EdgeMaskStrength, _EdgeMaskPower, _EdgeMaskContrast, _EdgeMaskOffset);
    data.thickness = GemShapeMask(mask.g, _ThicknessMaskStrength, _ThicknessMaskPower, _ThicknessMaskContrast, _ThicknessMaskOffset);
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

GemSurface GemResolveSurface(GemVaryings input, half4 mainTex)
{
    GemSurface surface = (GemSurface)0;
    surface.viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
    surface.normalWS = GemResolveNormalWS(input);
    surface.fresnel = GemFresnel(surface.normalWS, surface.viewDirWS, _FresnelPower);

    half4 baseTex = mainTex * _BaseColor;
    surface.baseColor = max(baseTex.rgb, half3(0.0h, 0.0h, 0.0h));
    surface.alpha = saturate(baseTex.a);

    GemMask masks = GemResolveMask(input, surface.viewDirWS);
    half2 field = CrystalInternalField(input, surface);
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

float3 FiberResolveSamplePosition(float3 sampleOS)
{
    float3 samplePosition = sampleOS;
    if (_FiberSpace < 0.5)
    {
        samplePosition = TransformObjectToWorld(sampleOS);
    }
    else if (_FiberSpace > 1.5)
    {
        samplePosition *= GemObjectScale();
    }

    return samplePosition + _FiberOffset.xyz;
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
        float3 fiberSample = FiberResolveSamplePosition(sampleOS) / ray.radius;
        float3 impuritySample = FiberAnimatePosition(fiberSample, stepT);
        half density = FiberVolumeDensity(normalizedSample, impuritySample, ray.coverage, contrast, mode);
        half phase = FiberPhase(impuritySample, stepT);
        half3 sampleColor = FiberSampleColor(density, phase, mode);
        accumulated = accumulated * persistence + sampleColor * FiberStepWeight(density, ray.coverage, mode);
    }

    half volumeMask = saturate(dot(accumulated, half3(0.2126h, 0.7152h, 0.0722h)));
    half fresnelWeight = saturate(lerp(1.0h, surface.fresnel + volumeMask, saturate(_FiberFresnel)));
    return accumulated * GemClamp(_FiberBrightness, 0.0h, 4.0h) * fresnelWeight * impurityStrength;
}

half3 GemApplyContrast(half3 color, half contrast)
{
    half safeContrast = max(contrast, 0.001h);
    return max((color - 0.5h) * safeContrast + 0.5h, half3(0.0h, 0.0h, 0.0h));
}

half3 GemSampleSceneColor(float2 uv)
{
    return SampleSceneColor(saturate(uv));
}

half3 CrystalRefraction(GemVaryings input, GemSurface surface)
{
    float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS);
    float eta = 1.0 / max(_IOR, 1.001);
    float3 refractDirWS = refract(-surface.viewDirWS, surface.normalWS, eta);
    if (dot(refractDirWS, refractDirWS) <= 0.0001)
    {
        refractDirWS = -surface.viewDirWS;
    }

    float2 refractOffset = mul((float3x3)UNITY_MATRIX_V, SafeNormalize(refractDirWS)).xy;
    half refractionFresnel = pow(saturate(1.0h - dot(surface.normalWS, surface.viewDirWS)), max(_RefractionFresnelPower, 0.001h));
    half thicknessWeight = lerp(0.65h, 1.35h, saturate(surface.thickness));
    float2 offset = refractOffset * (_RefractionStrength * refractionFresnel * thicknessWeight);
    half chromatic = _ChromaticAberration;

    float2 uvR = screenUV + offset;
    float2 uvG = screenUV + offset * (1.0 + chromatic * 0.5);
    float2 uvB = screenUV + offset * (1.0 + chromatic);

    half3 refracted;
    refracted.r = GemSampleSceneColor(uvR).r;
    refracted.g = GemSampleSceneColor(uvG).g;
    refracted.b = GemSampleSceneColor(uvB).b;
    refracted *= max(_RefractionTint.rgb, half3(0.0h, 0.0h, 0.0h));
    return GemApplyContrast(refracted, _RefractionContrast);
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
    half perceptualRoughness = saturate(max(_ReflectionRoughness, 1.0h - _Smoothness));
    half3 reflection = GlossyEnvironmentReflection(
        reflectionDirection,
        input.positionWS,
        perceptualRoughness,
        1.0h,
        GetNormalizedScreenSpaceUV(input.positionCS)
    );
    return reflection * max(_ReflectionTint.rgb, half3(0.0h, 0.0h, 0.0h)) * fresnel * strength;
}

half3 FireSpectralWeight(int spectralIndex)
{
    if (spectralIndex == 0)
    {
        return half3(0.8h, 0.0h, 1.0h);
    }

    if (spectralIndex == 1)
    {
        return half3(0.0h, 0.22h, 1.0h);
    }

    if (spectralIndex == 2)
    {
        return half3(0.0h, 1.0h, 0.82h);
    }

    if (spectralIndex == 3)
    {
        return half3(0.35h, 1.0h, 0.0h);
    }

    if (spectralIndex == 4)
    {
        return half3(1.0h, 0.68h, 0.0h);
    }

    return half3(1.0h, 0.0h, 0.06h);
}

half FireSpectralOffset(int spectralIndex)
{
    return ((half)spectralIndex - 2.5h) * 0.4h;
}

half FireHighlightResponse(half nDotH, half threshold, half sharpness)
{
    half broadPower = exp2(lerp(5.0h, 9.0h, sharpness));
    half needlePower = exp2(lerp(8.0h, 14.0h, sharpness));
    half broad = pow(saturate(nDotH), broadPower) * lerp(0.35h, 0.08h, sharpness);
    half needle = pow(saturate(nDotH), needlePower);
    half response = max(broad, needle);
    return pow(saturate((response - threshold) / max(1.0h - threshold, 0.001h)), lerp(1.4h, 0.5h, sharpness));
}

half FireFacetMask(GemVaryings input, GemSurface surface, half spectralOffset)
{
    half directionalMask = pow(saturate(surface.fresnel + dot(surface.normalWS, surface.viewDirWS) * 0.25h), 0.6h);
    half edgeMask = lerp(1.0h, saturate(surface.fresnel + surface.edges * 0.5h), saturate(_FireFresnelWeight * 0.5h));
    half fieldMask = lerp(0.75h, 1.35h, saturate(surface.fieldMask + surface.thickness * 0.5h));
    half scintillation = lerp(1.0h, saturate(directionalMask + surface.edges * 0.35h), saturate(_FireScintillation));
    return saturate(edgeMask * fieldMask * scintillation);
}

float3 FireFacetNormal(GemVaryings input, GemSurface surface, half spectralOffset)
{
    float3 tangentWS = SafeNormalize(input.tangentWS.xyz);
    float3 bitangentWS = SafeNormalize(cross(surface.normalWS, tangentWS) * input.tangentWS.w);
    half facetFrequency = max(_FireFacetScale, 1.0h);
    half angularA = sin(dot(surface.viewDirWS, tangentWS) * facetFrequency + spectralOffset * 2.37h);
    half angularB = cos(dot(surface.viewDirWS, bitangentWS) * facetFrequency * 0.73h - spectralOffset * 1.91h);
    half perturbStrength = saturate(_FireScintillation) * 0.18h;
    float3 worldDir = SafeNormalize(
        surface.normalWS +
        tangentWS * angularA * perturbStrength +
        bitangentWS * angularB * perturbStrength);
    return worldDir;
}

float3 FireTraceDirection(GemVaryings input, GemSurface surface, half spectralOffset)
{
    float3 rayDir = -surface.viewDirWS;
    float3 normalWS = FireFacetNormal(input, surface, spectralOffset);
    float etaBase = 1.0 / max(_IOR + spectralOffset * _FireDispersion, 1.001);
    half bounceCount = saturate((_FireBounces - 1.0h) * (1.0h / 7.0h)) * 7.0h + 1.0h;

    [unroll]
    for (int i = 0; i < 8; i++)
    {
        half bounceT = (i + 1.0h) * 0.137h + spectralOffset * 0.31h;
        half bounceWeight = saturate(bounceCount - (half)i);
        float3 facetNormal = FireFacetNormal(input, surface, spectralOffset + bounceT);
        float3 refracted = refract(rayDir, facetNormal, etaBase);
        float3 nextRayDir;
        if (dot(refracted, refracted) <= 0.0001)
        {
            nextRayDir = reflect(rayDir, facetNormal);
        }
        else
        {
            half internalMix = saturate(0.45h + surface.thickness * 0.35h + surface.fresnel * 0.2h);
            nextRayDir = SafeNormalize(lerp(refracted, reflect(rayDir, facetNormal), internalMix));
        }

        rayDir = SafeNormalize(lerp(rayDir, nextRayDir, bounceWeight));
        normalWS = SafeNormalize(lerp(normalWS, facetNormal, 0.55 * bounceWeight));
    }

    float3 exitDir = refract(rayDir, -normalWS, max(_IOR + spectralOffset * _FireDispersion, 1.001));
    if (dot(exitDir, exitDir) <= 0.0001)
    {
        exitDir = reflect(rayDir, -normalWS);
    }

    return SafeNormalize(exitDir);
}

half3 CrystalFireSampleLight(GemSurface surface, Light light, float3 facetNormal, float3 tracedDir, half facetMask)
{
    if (facetMask <= 0.0h)
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    half3 refractedHalfDir = SafeNormalize(light.direction + surface.viewDirWS + tracedDir * 0.18);
    half3 reflectedHalfDir = SafeNormalize(light.direction + surface.viewDirWS);
    half nDotH = max(saturate(dot(facetNormal, refractedHalfDir)), saturate(dot(facetNormal, reflectedHalfDir)) * 0.82h);
    half threshold = saturate(_FireThreshold * 0.25h);
    half response = FireHighlightResponse(nDotH, threshold, saturate(_FireSharpness));
    half fresnelBoost = lerp(1.0h, surface.fresnel + surface.edges, saturate(_FireFresnelWeight));
    return response * fresnelBoost * light.distanceAttenuation * light.color * GemClamp(_FireLightStrength, 0.0h, 8.0h);
}

half3 CrystalFire(GemVaryings input, GemSurface surface)
{
    half strength = GemClamp(_FireStrength, 0.0h, 32.0h);
    if (strength <= 0.0h)
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    half3 spectralColor = half3(0.0h, 0.0h, 0.0h);
    float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS);
    half threshold = max(_FireThreshold, 0.0h);
    half sharpness = saturate(_FireSharpness);
    half envStrength = GemClamp(_FireEnvironmentStrength, 0.0h, 8.0h);
    Light mainLight = GetMainLight();

    [unroll]
    for (int spectralIndex = 0; spectralIndex < 6; spectralIndex++)
    {
        half spectralOffset = FireSpectralOffset(spectralIndex);
        half3 spectralWeight = FireSpectralWeight(spectralIndex);
        float3 tracedDir = FireTraceDirection(input, surface, spectralOffset);
        float3 facetNormal = FireFacetNormal(input, surface, spectralOffset);
        half facetMask = FireFacetMask(input, surface, spectralOffset);

        half perceptualRoughness = lerp(0.0h, 0.08h, 1.0h - sharpness);
        half3 env = GlossyEnvironmentReflection(
            tracedDir,
            input.positionWS,
            perceptualRoughness,
            1.0h,
            screenUV
        );

        float2 screenOffset = mul((float3x3)UNITY_MATRIX_V, tracedDir).xy;
        half3 sceneFlash = GemSampleSceneColor(screenUV + screenOffset * (_RefractionStrength + _FireDispersion * spectralOffset) * 0.65h);
        half3 lightFire = CrystalFireSampleLight(surface, mainLight, facetNormal, tracedDir, facetMask);

        #if defined(_ADDITIONAL_LIGHTS)
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
        {
            Light light = GetAdditionalLight(lightIndex, input.positionWS);
            lightFire += CrystalFireSampleLight(surface, light, facetNormal, tracedDir, facetMask);
        }
        #endif

        half3 environmentSource = env * envStrength + sceneFlash * envStrength * 0.35h;
        half envBright = max(max(environmentSource.r, environmentSource.g), environmentSource.b);
        half envGated = pow(saturate((envBright - threshold) / max(envBright + 0.001h, 0.001h)), lerp(2.4h, 0.7h, sharpness));

        half directThreshold = threshold * 0.35h;
        half directBright = max(max(lightFire.r, lightFire.g), lightFire.b);
        half directGated = pow(saturate((directBright - directThreshold) / max(directBright + 0.001h, 0.001h)), lerp(1.3h, 0.45h, sharpness));

        spectralColor += (environmentSource * envGated + lightFire * directGated) * spectralWeight * facetMask;
    }

    spectralColor *= 0.45h;
    spectralColor = GemSaturateColor(spectralColor, _FireSaturation);
    half3 tint = max(_FireTint.rgb, half3(0.0h, 0.0h, 0.0h)) * max(_FireTint.a, 0.0h);
    return spectralColor * tint * strength;
}

half3 CrystalHighlight(GemVaryings input, GemSurface surface)
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
    Light mainLight = GetMainLight();

    half3 halfDir = SafeNormalize(mainLight.direction + surface.viewDirWS);
    half nDotH = saturate(dot(surface.normalWS, halfDir));
    color += pow(nDotH, specPower) * sharpness * mainLight.distanceAttenuation * mainLight.color * highlightColor * strength;

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

GemComponents CrystalGemResolveComponents(GemVaryings input, GemSurface surface)
{
    GemComponents components;
    FieldGlow fieldGlow = CrystalResolveFieldGlow(surface);

    components.fieldGlow = max(fieldGlow.field + fieldGlow.glow, half3(0.0h, 0.0h, 0.0h));
    components.matCap = max(CrystalMatCap(surface), half3(0.0h, 0.0h, 0.0h));
    components.dynamicFibers = max(CrystalDynamicFibers(input, surface), half3(0.0h, 0.0h, 0.0h));
    components.fire = max(CrystalFire(input, surface), half3(0.0h, 0.0h, 0.0h));
    return components;
}

half3 CrystalGemTransmission(GemVaryings input, GemSurface surface)
{
    half3 color = CrystalRefraction(input, surface);
    color = lerp(color, color * surface.baseColor, saturate(_BaseTintStrength));
    return max(color, half3(0.0h, 0.0h, 0.0h));
}

half3 CrystalGemTransparent(GemVaryings input, GemSurface surface, GemComponents components)
{
    half3 color = CrystalGemTransmission(input, surface);
    color = CrystalApplyMatCapBlend(color, components.matCap);
    color += components.fieldGlow;
    color += components.dynamicFibers;
    color += CrystalReflection(input, surface);
    color += components.fire;
    color += CrystalHighlight(input, surface);
    return max(color, half3(0.0h, 0.0h, 0.0h));
}

half4 GemFragForwardCore(GemVaryings input, bool isFront)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half4 mainTex = GemSampleMain(input);
    GemSurface surface = GemResolveSurface(input, mainTex);
    if (!isFront)
    {
        surface.normalWS = -surface.normalWS;
        surface.fresnel = GemFresnel(surface.normalWS, surface.viewDirWS, _FresnelPower);
    }

    // _Opacity is a visibility mask for hiding mesh regions, not the glass blend amount.
    half visibility = saturate(surface.alpha * _Opacity);
    if (visibility <= 0.0001h)
    {
        discard;
    }

    half opticalBlend = saturate(_OpticalBlend);
    GemComponents components = CrystalGemResolveComponents(input, surface);
    half3 transmission = CrystalGemTransmission(input, surface);
    half3 outputColor = CrystalGemTransparent(input, surface, components);

    half backfaceWeight = (isFront || _UseDoubleSidedPass <= 0.5h) ? 1.0h : saturate(_BackfaceWeight);
    half3 additiveColor = max(outputColor - transmission, half3(0.0h, 0.0h, 0.0h));
    half3 premultipliedColor = (transmission + additiveColor) * visibility * backfaceWeight;
    return half4(premultipliedColor, opticalBlend * visibility * backfaceWeight);
}

half4 GemFragForwardSingle(GemVaryings input, bool isFront : SV_IsFrontFace) : SV_Target
{
    if (_UseDoubleSidedPass > 0.5h && _HoTransparentActive > 0.5h)
    {
        discard;
    }

    return GemFragForwardCore(input, isFront);
}

half4 GemFragForwardDouble(GemVaryings input, bool isFront : SV_IsFrontFace) : SV_Target
{
    if (_UseDoubleSidedPass <= 0.5h || _HoTransparentActive <= 0.5h)
    {
        discard;
    }

    return GemFragForwardCore(input, isFront);
}

#endif
