#ifndef INCLUDED_UNITY_URP_SHADINGS
#define INCLUDED_UNITY_URP_SHADINGS

SamplerState sampler_linear_repeat;
SamplerState sampler_linear_clamp;
SamplerState sampler_point_clamp;
SamplerState sampler_trilinear_repeat;

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

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
half4 SampleScreen(float2 uv)
{
    return half4(SampleSceneColor(uv), 1);
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

LILPBR_PROPERTIES
LILPBR_TEXTURES
LILPBR_SAMPLERS

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

    #if defined(_SCREEN_SPACE_OCCLUSION) && !defined(_TRANSPARENT)
        if(_UseSSAO != 0)
        {
            AmbientOcclusionFactor ssaoFactor = GetScreenSpaceAmbientOcclusion(inputData.normalizedScreenSpaceUV);
            ssaoFactor.directAmbientOcclusion = RemapLILPBRScreenSpaceAO(ssaoFactor.directAmbientOcclusion);
            ssaoFactor.indirectAmbientOcclusion = RemapLILPBRScreenSpaceAO(ssaoFactor.indirectAmbientOcclusion);

            half directAO = lerp(1.0, ssaoFactor.directAmbientOcclusion, _SSAODirectStrength);
            half indirectAO = lerp(1.0, ssaoFactor.indirectAmbientOcclusion, _SSAOIndirectStrength);
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
    return GlossyEnvironmentReflection(-reflect(p.V,p.refN), p.posWorld, p.perceptualRoughness, 1.0, GetNormalizedScreenSpaceUV(i.pos)) * aoFactor.indirectAmbientOcclusion;
}

void DoLight(inout half3 diff, inout half3 spec, ShadingParams p, Light light)
{
    DoLight(diff, spec, p, light.direction, light.color * (light.distanceAttenuation * light.shadowAttenuation));
}

half GetSubsurfaceShadowAttenuation(Light light)
{
    half shadowAttenuation = _SubsurfaceReceiveShadow != 0 ? light.shadowAttenuation : 1.0;
    return light.distanceAttenuation * shadowAttenuation;
}

void ComputeLights(out half3 diff, out half3 spec, out half3 reflectionStrength, ShadingParams p, v2f i)
{
    uint meshRenderingLayers = GetMeshRenderingLayer();
    InputData inputData = GetInputData(p, i);
    SurfaceData surfaceData = GetSurfaceData(p, i);
    AmbientOcclusionFactor aoFactor = CreateLILPBRAmbientOcclusionFactor(inputData, surfaceData, p.ssaoMask);
    diff = 0;
    spec = 0;

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
            DoLight(diff, spec, p, light);
        }
        #endif

        LIGHT_LOOP_BEGIN(pixelLightCount)
            Light light = GetAdditionalLight(lightIndex, inputData, inputData.shadowMask, aoFactor);
            #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
            DoLight(diff, spec, p, light);
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

    half roughness = p.subsurfaceThickness * 0.5;
    half lightpow = rcp(max(roughness * roughness, 0.002));

    // Environment Light
    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_GLOBAL_ILLUMINATION)) {
        diff += inputData.bakedGI;
    }

    // Main Light
    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_MAIN_LIGHT)) {
        Light mainLight = GetMainLight(inputData, inputData.shadowMask, aoFactor);
        MixRealtimeAndBakedGI(mainLight, inputData.normalWS, diff);
        #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
        #endif
        diff += pow(saturate(dot(mainLight.direction,-p.V)), lightpow) * GetSubsurfaceShadowAttenuation(mainLight) * mainLight.color;
    }

    diff = GlossyEnvironmentReflection(-p.V, p.posWorld, roughness, 1.0, GetNormalizedScreenSpaceUV(i.pos)) * aoFactor.indirectAmbientOcclusion;

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
            diff += pow(saturate(dot(light.direction,-p.V)), lightpow) * GetSubsurfaceShadowAttenuation(light) * light.color;
        }
        #endif

        LIGHT_LOOP_BEGIN(pixelLightCount)
            Light light = GetAdditionalLight(lightIndex, inputData, inputData.shadowMask, aoFactor);
            #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
            diff += pow(saturate(dot(light.direction,-p.V)), lightpow) * GetSubsurfaceShadowAttenuation(light) * light.color;
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
