#ifndef INCLUDED_UNITY_URP_SHADINGS
#define INCLUDED_UNITY_URP_SHADINGS

SamplerState sampler_linear_repeat;
SamplerState sampler_linear_clamp;
SamplerState sampler_point_clamp;
SamplerState sampler_trilinear_repeat;

#include "Packages/jp.lilxyzw.liltoon.urp.extensions/Runtime/ShadowCast/Shaders/HoShadowCastSampling.hlsl"

float3 O2W(float4 vertex)
{
    return TransformObjectToWorld(vertex.xyz);
}

float3 W2O(float3 vertex)
{
    return TransformWorldToObject(vertex);
}

float4 W2P(float3 vertex)
{
    return TransformWorldToHClip(vertex);
}

float4 O2P(float4 vertex)
{
    return W2P(O2W(vertex));
}

float3 O2WNormal(float3 d)
{
    return TransformObjectToWorldNormal(d, false);
}

float3 O2WVector(float3 d)
{
    return TransformObjectToWorldDir(d, false);
}

float3 W2OVector(float3 d)
{
    return TransformWorldToObjectDir(d, false);
}

float3 V2WVector(float3 d)
{
    return TransformViewToWorldDir(d, false);
}

float4x4 GetMatrixI_V()
{
    return UNITY_MATRIX_I_V;
}

float3 ComputeBinormal(float3 n, float3 t, float w)
{
    return cross(n, t) * w * GetOddNegativeScale();
}

float3 GetCameraPos()
{
    //return GetCurrentViewPosition();
    #if defined(SHADERPASS) && (SHADERPASS == SHADERPASS_SHADOWS)
    return UNITY_MATRIX_I_V._m03_m13_m23;
    #elif (SHADEROPTIONS_CAMERA_RELATIVE_RENDERING != 0)
    return float3(0, 0, 0);
    #else
    return _WorldSpaceCameraPos;
    #endif
}

float3 GetHeadPos()
{
    #if defined(USING_STEREO_MATRICES)
    return (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]) * 0.5;
    #else
    return GetCameraPos();
    #endif
}

float3 GetVDir(float3 posWorld, float3 V)
{
    return UNITY_MATRIX_P._m33 != 0.0 ? UNITY_MATRIX_V._m20_m21_m22 : normalize(GetCameraPos() - posWorld);
}

float3 O2VDir(float4 vertex)
{
    return GetVDir(O2W(vertex),float3(0,0,0));
}

bool IsPerspective()
{
    return IsPerspectiveProjection();
}

bool IsShadowCaster()
{
    #if defined(SHADERPASS) && (SHADERPASS == SHADERPASS_SHADOWS)
    return !IsPerspective();
    #endif
    return false;
}

half3 UnpackScaleNormal(half4 normal, float scale)
{
    return UnpackNormalScale(normal, scale);
}

half3 BlendNormals(half3 n1, half3 n2)
{
    return normalize(half3(n1.xy + n2.xy, n1.z*n2.z));
}

// Depth
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
float2 ScreenUV(float4 pos){ return pos.xy / _ScreenParams.xy; }
float2 ClampScreenUV(float2 uv){ return saturate(uv); }

bool IsCameraDepthGenerated()
{
    return true;
}

half SampleDepth(float2 uv)
{
    return SampleSceneDepth(uv, sampler_linear_clamp);
}

half4 SampleScreen(float2 uv)
{
    return half4(SampleSceneColor(uv), 1);
}

half SampleDepthLod0(float2 uv)
{
    uv = ClampAndScaleUVForBilinear(UnityStereoTransformScreenSpaceTex(uv), _CameraDepthTexture_TexelSize.xy);
    return SAMPLE_TEXTURE2D_X_LOD(_CameraDepthTexture, sampler_linear_clamp, uv, 0).r;
}

half3 SampleSceneColorLod0(float2 uv)
{
    uv = ClampAndScaleUVForBilinear(UnityStereoTransformScreenSpaceTex(uv), _CameraOpaqueTexture_TexelSize.xy);
    return SAMPLE_TEXTURE2D_X_LOD(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv, 0).rgb;
}

float lilLinearEyeDepth(float z, float2 uvScreen)
{
    return LinearEyeDepth(z, _ZBufferParams);
    /*
    float2 pos = uvScreen * 2.0 - 1.0;
    float4x4 matrixP = GetViewToHClipMatrix();
    #if UNITY_UV_STARTS_AT_TOP
        pos.y = -pos.y;
    #endif
    return matrixP._m23 / (z + matrixP._m22
        - matrixP._m20 / matrixP._m00 * (uvScreen.x + matrixP._m02)
        - matrixP._m21 / matrixP._m11 * (uvScreen.y + matrixP._m12)
    );
    */
}

float GetOpaqueDepth(float2 uvScreen)
{
    if(IsCameraDepthGenerated())
    {
        #if UNITY_UV_STARTS_AT_TOP
            if(_ProjectionParams.x > 0) uvScreen.y = _ScreenParams.y - uvScreen.y;
        #else
            if(_ProjectionParams.x < 0) uvScreen.y = _ScreenParams.y - uvScreen.y;
        #endif
        float cameraDepthTexture = SampleDepth(uvScreen);
        #if UNITY_REVERSED_Z
            if(cameraDepthTexture == 0) return 0;
        #else
            if(cameraDepthTexture == 1) return 0;
        #endif
        return lilLinearEyeDepth(cameraDepthTexture, uvScreen);
    }
    else
    {
        return 0;
    }
}

float3 GetOpaquePosW(float2 uvScreen, float3 V)
{
    if(IsCameraDepthGenerated())
    {
        #if UNITY_UV_STARTS_AT_TOP
            if(_ProjectionParams.x > 0) uvScreen.y = _ScreenParams.y - uvScreen.y;
        #else
            if(_ProjectionParams.x < 0) uvScreen.y = _ScreenParams.y - uvScreen.y;
        #endif
        float cameraDepthTexture = SampleDepth(uvScreen);
        #if UNITY_REVERSED_Z
            if(cameraDepthTexture == 0) return 0;
        #else
            if(cameraDepthTexture == 1) return 0;
        #endif
        float depth = lilLinearEyeDepth(cameraDepthTexture, uvScreen);
        return GetCameraPos() + depth / dot(-GetWorldToViewMatrix()._m20_m21_m22, V) * V;
    }
    else
    {
        return 0;
    }
}

#define LILPBR_PROPERTY(t,n) t n;
#define LILPBR_TEXTURE(t,n) t n;
#define LILPBR_SAMPLER(t,n) t n;

CBUFFER_START(UnityPerMaterial)
LILPBR_PROPERTIES
CBUFFER_END
LILPBR_TEXTURES
LILPBR_SAMPLERS
TEXTURE2D(_HTraceBufferAO);
float4x4 _LILPBRPlanarReflectionTextureMatrix;
float4 _LILPBRPlanarReflectionParams;

// Lightings

InputData GetInputData(ShadingParams p, v2f i)
{
    InputData inputData = (InputData)0;
    inputData.positionWS = p.posWorld;
    inputData.positionCS = i.pos;
    inputData.tangentToWorld = half3x3(p.T,p.B,p.N);
    inputData.normalWS = p.N;
    inputData.viewDirectionWS = p.V;
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = i.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
    inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif
    #if defined(SHADERPASS) && (SHADERPASS == SHADERPASS_FORWARD)
    inputData.fogCoord = InitializeInputDataFog(float4(inputData.positionWS, 1.0), i.fogFactor);
    #endif
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(inputData.positionCS);

    float2 staticLightmapUV, dynamicLightmapUV = 0;
    #if defined(DYNAMICLIGHTMAP_ON)
    dynamicLightmapUV = p.uv[2].xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;;
    #endif
    #if defined(LIGHTMAP_ON)
    OUTPUT_LIGHTMAP_UV(p.uv[1].xy, unity_LightmapST, staticLightmapUV);
    #endif

    float3 vertexSH = 0;
    float4 probeOcclusion = 0;
    OUTPUT_SH4(p.posWorld, p.N, inputData.viewDirectionWS, vertexSH, probeOcclusion);
    #if defined(DEBUG_DISPLAY)
    inputData.vertexSH = vertexSH;
    inputData.probeOcclusion = probeOcclusion;
    #endif

    #if defined(_SCREEN_SPACE_IRRADIANCE)
    inputData.bakedGI = SAMPLE_GI(_ScreenSpaceIrradiance, inputData.positionCS.xy);
    #elif defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(staticLightmapUV, dynamicLightmapUV, vertexSH, inputData.normalWS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(staticLightmapUV);
    #elif !defined(LIGHTMAP_ON) && (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
    inputData.bakedGI = SAMPLE_GI(vertexSH,
        GetAbsolutePositionWS(inputData.positionWS),
        inputData.normalWS,
        inputData.viewDirectionWS,
        inputData.positionCS.xy,
        probeOcclusion,
        inputData.shadowMask);
    #else
    inputData.bakedGI = SAMPLE_GI(staticLightmapUV, vertexSH, inputData.normalWS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(staticLightmapUV);
    #endif
    return inputData;
}

SurfaceData GetSurfaceData(ShadingParams p, v2f i)
{
    SurfaceData surfaceData = (SurfaceData)0;
    surfaceData.albedo = p.albedo;
    surfaceData.alpha = p.alpha;
    surfaceData.metallic = p.metallic;
    surfaceData.specular = p.specular;
    surfaceData.smoothness = p.smoothness;
    surfaceData.normalTS = 0;
    surfaceData.occlusion = p.occlusion;
    surfaceData.emission = p.emission;
    return surfaceData;
}

half RemapLILPBRScreenSpaceAO(half ao)
{
    half ssaoMin = min(_SSAORemap.x, _SSAORemap.y - 0.001);
    half ssaoMax = max(_SSAORemap.y, ssaoMin + 0.001);
    ao = saturate((ao - ssaoMin) / max(ssaoMax - ssaoMin, 0.001));
    return saturate(1.0 - pow(saturate(1.0 - ao), max(_SSAOContrast, 0.001)));
}

AmbientOcclusionFactor CreateLILPBRAmbientOcclusionFactor(InputData inputData, SurfaceData surfaceData, half ssaoMask)
{
    AmbientOcclusionFactor aoFactor;
    aoFactor.directAmbientOcclusion = 1.0;
    aoFactor.indirectAmbientOcclusion = surfaceData.occlusion;

    #if !defined(_TRANSPARENT)
        if(_UseScreenSpaceAO != 0)
        {
            half screenSpaceDirectAO = 1.0;
            half screenSpaceIndirectAO = 1.0;

            if(_ScreenSpaceAOSource == 1)
            {
                half htraceAO = SAMPLE_TEXTURE2D(_HTraceBufferAO, sampler_linear_clamp, inputData.normalizedScreenSpaceUV).r;
                screenSpaceDirectAO = htraceAO;
                screenSpaceIndirectAO = htraceAO;
            }
            else
            {
                #if defined(_SCREEN_SPACE_OCCLUSION)
                    AmbientOcclusionFactor ssaoFactor = GetScreenSpaceAmbientOcclusion(inputData.normalizedScreenSpaceUV);
                    screenSpaceDirectAO = ssaoFactor.directAmbientOcclusion;
                    screenSpaceIndirectAO = ssaoFactor.indirectAmbientOcclusion;
                #endif
            }

            screenSpaceDirectAO = RemapLILPBRScreenSpaceAO(screenSpaceDirectAO);
            screenSpaceIndirectAO = RemapLILPBRScreenSpaceAO(screenSpaceIndirectAO);

            half directAO = lerp(1.0, screenSpaceDirectAO, _SSAODirectStrength);
            half indirectAO = lerp(1.0, screenSpaceIndirectAO, _SSAOIndirectStrength);
            half ssaoStrength = _SSAOStrength * ssaoMask;
            aoFactor.directAmbientOcclusion = lerp(1.0, directAO, ssaoStrength);
            aoFactor.indirectAmbientOcclusion = min(surfaceData.occlusion, lerp(1.0, indirectAO, ssaoStrength));
        }
    #endif

    return aoFactor;
}

VertexPositionInputs GetVertexPositionInputs(float3 positionWS, float4 positionCS)
{
    VertexPositionInputs input;
    input.positionWS = positionWS;
    input.positionVS = TransformWorldToView(positionWS);
    input.positionCS = positionCS;

    float4 ndc = input.positionCS * 0.5f;
    input.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
    input.positionNDC.zw = input.positionCS.zw;

    return input;
}

void OverrideByPlatform(inout ShadingParams p, v2f i)
{
    #if defined(_DBUFFER)
    InputData inputData = GetInputData(p, i);
    SurfaceData surfaceData = GetSurfaceData(p, i);
    ApplyDecalToSurfaceData(i.pos, surfaceData, inputData);
    p.albedo = surfaceData.albedo;
    p.N = inputData.normalWS;
    p.specular = surfaceData.specular;
    p.metallic = surfaceData.metallic;
    p.occlusion = surfaceData.occlusion;
    p.smoothness = surfaceData.smoothness;
    #endif
}

half3 GetReflection(ShadingParams p, v2f i)
{
    InputData inputData = GetInputData(p, i);
    SurfaceData surfaceData = GetSurfaceData(p, i);
    AmbientOcclusionFactor aoFactor = CreateLILPBRAmbientOcclusionFactor(inputData, surfaceData, p.ssaoMask);
    half3 reflectionVector = -reflect(p.V,p.refN);
    half3 environmentReflection = 0;
    if(_EnvironmentReflectionMode == 0)
    {
        environmentReflection = GlossyEnvironmentReflection(reflectionVector, p.posWorld, p.perceptualRoughness, 1.0, GetNormalizedScreenSpaceUV(i.pos)) * aoFactor.indirectAmbientOcclusion;
    }
    else if(_EnvironmentReflectionMode == 1)
    {
        environmentReflection = GlossyEnvironmentReflection(reflectionVector, p.perceptualRoughness, 1.0) * aoFactor.indirectAmbientOcclusion;
    }
    half3 reflection = environmentReflection;

    if(_UsePlanarReflection != 0 && _PlanarReflectionStrength > 0.0 && _LILPBRPlanarReflectionParams.x > 0.5)
    {
        half planarSmoothnessFade = saturate((p.smoothness - _PlanarReflectionMinSmoothness) / max(1.0 - _PlanarReflectionMinSmoothness, 0.0001));
        if(planarSmoothnessFade > 0.0)
        {
            float2 planarUV = GetNormalizedScreenSpaceUV(i.pos);
            if(_PlanarReflectionFlipY != 0) planarUV.y = 1.0 - planarUV.y;
            if(all(planarUV >= 0.0) && all(planarUV <= 1.0))
            {
                float planarEdge = min(min(planarUV.x, 1.0 - planarUV.x), min(planarUV.y, 1.0 - planarUV.y));
                half planarEdgeFade = _PlanarReflectionEdgeFade > 0.0 ? saturate(planarEdge * _PlanarReflectionEdgeFade) : 1.0;
                half planarDistanceFade = 1.0;
                if(_PlanarReflectionFadeEnd > _PlanarReflectionFadeStart)
                {
                    float viewDistance = distance(GetCameraPos(), p.posWorld);
                    planarDistanceFade = 1.0 - smoothstep(_PlanarReflectionFadeStart, _PlanarReflectionFadeEnd, viewDistance);
                }
                half planarWeight = saturate(_PlanarReflectionStrength * planarSmoothnessFade * planarEdgeFade * planarDistanceFade * _PlanarReflectionTint.a);
                half3 planarColor = SAMPLE_TEXTURE2D(_LILPBRPlanarReflectionTexture, sampler_linear_clamp, planarUV).rgb * _PlanarReflectionTint.rgb;
                reflection = lerp(reflection, planarColor * aoFactor.indirectAmbientOcclusion, planarWeight);
            }
        }
    }

    if(_UseScreenSpaceReflection == 0 || _SSRStrength <= 0.0)
    {
        return reflection;
    }

    half smoothnessFade = saturate((p.smoothness - _SSRMinSmoothness) / max(1.0 - _SSRMinSmoothness, 0.0001));
    if(smoothnessFade <= 0.0)
    {
        return reflection;
    }

    float3 rayDirectionWS = normalize(reflect(-p.V, normalize(p.refN)));
    if(dot(rayDirectionWS, p.origN) <= 0.0)
    {
        return reflection;
    }

    int stepCount = (int)clamp(_SSRStepCount, 4.0, 64.0);
    float rayLength = max(_SSRMaxDistance, 0.001);
    float rayStride = rayLength / stepCount;
    float3 rayOriginWS = p.posWorld + rayDirectionWS * max(rayStride, _SSRThickness) * 0.5;

    half3 ssrColor = reflection;
    half ssrWeight = 0.0;

    [loop]
    for(int stepIndex = 1; stepIndex <= 64; stepIndex++)
    {
        if(stepIndex > stepCount) break;

        float3 rayPositionWS = rayOriginWS + rayDirectionWS * (rayStride * stepIndex);
        float4 rayPositionCS = TransformWorldToHClip(rayPositionWS);
        if(rayPositionCS.w <= 0.0) break;

        float2 rayUV = GetNormalizedScreenSpaceUV(rayPositionCS);
        if(any(rayUV < 0.0) || any(rayUV > 1.0)) break;

        float sceneRawDepth = SampleDepthLod0(rayUV);
        #if UNITY_REVERSED_Z
            if(sceneRawDepth <= 0.00001) continue;
        #else
            if(sceneRawDepth >= 0.99999) continue;
        #endif

        float sceneEyeDepth = LinearEyeDepth(sceneRawDepth, _ZBufferParams);
        float rayEyeDepth = -TransformWorldToView(rayPositionWS).z;
        float depthDelta = rayEyeDepth - sceneEyeDepth;
        float thickness = max(_SSRThickness, sceneEyeDepth * _SSRThickness * 0.025);

        if(depthDelta > 0.0 && depthDelta < thickness)
        {
            float edge = min(min(rayUV.x, 1.0 - rayUV.x), min(rayUV.y, 1.0 - rayUV.y));
            half edgeFade = saturate(edge * _SSREdgeFade);
            half distanceFade = saturate(1.0 - (stepIndex - 1.0) / stepCount);
            ssrColor = SampleSceneColorLod0(rayUV) * aoFactor.indirectAmbientOcclusion;
            ssrWeight = saturate(_SSRStrength * smoothnessFade * edgeFade * distanceFade);
            break;
        }
    }

    return lerp(reflection, ssrColor, ssrWeight);
}

void DoLight(inout half3 diff, inout half3 spec, ShadingParams p, Light light)
{
    DoLight(diff, spec, p, light.direction, light.color * (light.distanceAttenuation * light.shadowAttenuation));
}

void DoAdditionalLight(inout half3 diff, inout half3 spec, ShadingParams p, Light light, half brighteningAttenuation)
{
    DoLight(diff, spec, p, light.direction, light.color * (light.distanceAttenuation * brighteningAttenuation));
}

half GetSubsurfaceShadowAttenuation(Light light, bool useUrpShadow, half brighteningAttenuation)
{
    half shadowAttenuation = useUrpShadow && _SubsurfaceReceiveShadow != 0 ? light.shadowAttenuation : 1.0;
    return light.distanceAttenuation * shadowAttenuation * brighteningAttenuation;
}

half GetSubsurfaceForwardScatter(half3 lightDirection, ShadingParams p, half lightpow)
{
    half forwardScatter = pow(saturate(dot(lightDirection, -p.V)), lightpow);
    half wrappedDiffuse = saturate((dot(p.N, lightDirection) + _SubsurfaceWrap) / (1.0 + _SubsurfaceWrap));
    return lerp(forwardScatter, max(forwardScatter, wrappedDiffuse), _SubsurfaceWrap);
}

void ComputeLights(out half3 diff, out half3 spec, out half3 reflectionStrength, ShadingParams p, v2f i)
{
    uint meshRenderingLayers = GetMeshRenderingLayer();
    InputData inputData = GetInputData(p, i);
    SurfaceData surfaceData = GetSurfaceData(p, i);
    AmbientOcclusionFactor aoFactor = CreateLILPBRAmbientOcclusionFactor(inputData, surfaceData, p.ssaoMask);
    diff = 0;
    spec = 0;
    half hoShadowCastAttenuation = HoShadowCastAttenuation(p.posWorld);

    // Environment Light
    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_GLOBAL_ILLUMINATION)) {
        diff += inputData.bakedGI;
        spec += GetReflection(p, i) * GetReflectionStrength(p, reflectionStrength);

        half NdotR = saturate(dot(-reflect(p.V,p.refN),p.origN) + 0.5);
        reflectionStrength *= NdotR;
        spec *= NdotR;
    }

    // Main Light
    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_MAIN_LIGHT)) {
        Light mainLight = GetMainLight(inputData, inputData.shadowMask, aoFactor);
        mainLight.shadowAttenuation *= hoShadowCastAttenuation;
        MixRealtimeAndBakedGI(mainLight, inputData.normalWS, diff);
        #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
        #endif
        DoLight(diff, spec, p, mainLight);
    }

    // Other Lights
    #if defined(_ADDITIONAL_LIGHTS) || defined(_ADDITIONAL_LIGHTS_VERTEX)
    #if defined(_ADDITIONAL_LIGHTS)
    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_ADDITIONAL_LIGHTS)) {
    #else
    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_VERTEX_LIGHTING)) {
    #endif
        uint pixelLightCount = GetAdditionalLightsCount();

        #if USE_CLUSTER_LIGHT_LOOP
        [loop] for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
        {
            CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK

            Light light = GetAdditionalLight(lightIndex, inputData, inputData.shadowMask, aoFactor);
            #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
            DoAdditionalLight(diff, spec, p, light, hoShadowCastAttenuation);
        }
        #endif

        LIGHT_LOOP_BEGIN(pixelLightCount)
            Light light = GetAdditionalLight(lightIndex, inputData, inputData.shadowMask, aoFactor);
            #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
            DoAdditionalLight(diff, spec, p, light, hoShadowCastAttenuation);
        LIGHT_LOOP_END
    }
    #endif
}

half3 DoTranslucent(ShadingParams p, v2f i, half translucentRoughness)
{
    InputData inputData = GetInputData(p, i);
    SurfaceData surfaceData = GetSurfaceData(p, i);
    AmbientOcclusionFactor aoFactor = CreateLILPBRAmbientOcclusionFactor(inputData, surfaceData, p.ssaoMask);
    return GlossyEnvironmentReflection(-p.V+p.N*0.2, p.posWorld, translucentRoughness, 1.0, GetNormalizedScreenSpaceUV(i.pos)) * aoFactor.indirectAmbientOcclusion;
}

void ComputeSubsurface(out half3 diff, ShadingParams p, v2f i)
{
    uint meshRenderingLayers = GetMeshRenderingLayer();
    InputData inputData = GetInputData(p, i);
    SurfaceData surfaceData = GetSurfaceData(p, i);
    AmbientOcclusionFactor aoFactor = CreateLILPBRAmbientOcclusionFactor(inputData, surfaceData, p.ssaoMask);
    diff = 0;
    half hoShadowCastAttenuation = HoShadowCastAttenuation(p.posWorld);

    half roughness = p.subsurfaceThickness * 0.5;
    half lightpow = rcp(max(roughness * roughness, 0.002));

    // Environment Light
    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_GLOBAL_ILLUMINATION)) {
        diff += inputData.bakedGI;
    }

    // Main Light
    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_MAIN_LIGHT)) {
        Light mainLight = GetMainLight(inputData, inputData.shadowMask, aoFactor);
        mainLight.shadowAttenuation *= hoShadowCastAttenuation;
        MixRealtimeAndBakedGI(mainLight, inputData.normalWS, diff);
        #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
        #endif
        diff += GetSubsurfaceForwardScatter(mainLight.direction, p, lightpow) * GetSubsurfaceShadowAttenuation(mainLight, true, 1.0) * mainLight.color * _SubsurfaceDirectStrength;
    }

    diff += GlossyEnvironmentReflection(-p.V, p.posWorld, roughness, 1.0, GetNormalizedScreenSpaceUV(i.pos)) * aoFactor.indirectAmbientOcclusion * _SubsurfaceEnvironmentStrength;

    // Other Lights
    #if defined(_ADDITIONAL_LIGHTS) || defined(_ADDITIONAL_LIGHTS_VERTEX)
    #if defined(_ADDITIONAL_LIGHTS)
    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_ADDITIONAL_LIGHTS)) {
    #else
    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_VERTEX_LIGHTING)) {
    #endif
        uint pixelLightCount = GetAdditionalLightsCount();

        #if USE_CLUSTER_LIGHT_LOOP
        [loop] for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
        {
            CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK

            Light light = GetAdditionalLight(lightIndex, inputData, inputData.shadowMask, aoFactor);
            #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
            diff += GetSubsurfaceForwardScatter(light.direction, p, lightpow) * GetSubsurfaceShadowAttenuation(light, false, hoShadowCastAttenuation) * light.color * _SubsurfaceDirectStrength;
        }
        #endif

        LIGHT_LOOP_BEGIN(pixelLightCount)
            Light light = GetAdditionalLight(lightIndex, inputData, inputData.shadowMask, aoFactor);
            #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
            diff += GetSubsurfaceForwardScatter(light.direction, p, lightpow) * GetSubsurfaceShadowAttenuation(light, false, hoShadowCastAttenuation) * light.color * _SubsurfaceDirectStrength;
        LIGHT_LOOP_END
    }
    #endif
}

Texture2D _VFogNoise;
float _VFogDensity;
float _VFogScrollX;
float _VFogScrollZ;
float _VFogHeightScale;
float _VFogHeightOffset;
float _VFogHeightSharpness;

void DoFog(v2f i, inout half4 col, ShadingParams p)
{
    #if defined(SHADERPASS) && (SHADERPASS == SHADERPASS_FORWARD)
    col.rgb = MixFog(col.rgb, InitializeInputDataFog(float4(p.posWorld, 1.0), i.fogFactor));
    #endif
}

struct appdata
{
    float4 vertex : POSITION;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;
    float2 uv3 : TEXCOORD3;
    float3 normal: NORMAL;
    float4 tangent: TANGENT;
    float4 color : COLOR;
    #if defined(SHADERPASS) && (SHADERPASS == SHADERPASS_MOTION_VECTORS || SHADERPASS == SHADERPASS_XR_MOTION_VECTORS)
    float3 positionOld : TEXCOORD4;
    float3 alembicMotionVector : TEXCOORD5;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

#endif
