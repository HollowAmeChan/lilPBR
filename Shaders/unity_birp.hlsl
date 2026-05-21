#ifndef INCLUDED_UNITY_SHADINGS
#define INCLUDED_UNITY_SHADINGS

SamplerState sampler_linear_repeat;
SamplerState sampler_linear_clamp;
SamplerState sampler_point_clamp;
SamplerState sampler_trilinear_repeat;

float3 O2W(float4 vertex)
{
    if(dot(_WorldSpaceCameraPos.xyz,_WorldSpaceCameraPos.xyz) > 100000000)
    {
        float4x4 matrixM = unity_ObjectToWorld;
        matrixM._m03_m13_m23 -= _WorldSpaceCameraPos.xyz;
        return mul(matrixM, vertex).xyz + _WorldSpaceCameraPos.xyz;
    }
    else
    {
        return mul(unity_ObjectToWorld, vertex).xyz;
    }
}

float3 W2O(float3 vertex)
{
    if(dot(_WorldSpaceCameraPos.xyz,_WorldSpaceCameraPos.xyz) > 100000000)
    {
        float4x4 matrixM = unity_WorldToObject;
        matrixM._m03_m13_m23 += _WorldSpaceCameraPos.xyz;
        return mul(matrixM, float4(vertex,1)).xyz - _WorldSpaceCameraPos.xyz;
    }
    else
    {
        return mul(unity_WorldToObject, float4(vertex,1)).xyz;
    }
}

float4 W2P(float3 vertex)
{
    return UnityWorldToClipPos(vertex);
}

float4 O2P(float4 vertex)
{
    if(dot(_WorldSpaceCameraPos.xyz,_WorldSpaceCameraPos.xyz) > 100000000)
    {
        float4x4 matrixM = unity_ObjectToWorld;
        float4x4 matrixV = UNITY_MATRIX_V;
        matrixM._m03_m13_m23 -= _WorldSpaceCameraPos.xyz;
        matrixV._m03_m13_m23 = 0.0;
        float3 wp = mul(matrixM, vertex).xyz;
        float3 vp = mul(matrixV, float4(wp,1));
        return mul(UNITY_MATRIX_P, float4(vp,1));
    }
    else
    {
        return UnityObjectToClipPos(vertex);
    }
}

float3 O2WNormal(float3 d)
{
    return UnityObjectToWorldNormal(d);
}

float3 O2WVector(float3 d)
{
    return UnityObjectToWorldDir(d);
}

float3 W2OVector(float3 d)
{
    return mul((float3x3)unity_WorldToObject, d);
}

float3 V2WVector(float3 d)
{
    return mul((float3x3)UNITY_MATRIX_I_V, d);
}

float4x4 GetMatrixI_V()
{
    return UNITY_MATRIX_I_V;
}

float3 ComputeBinormal(float3 n, float3 t, float w)
{
    return cross(n, t) * w * unity_WorldTransformParams.w;
}

float3 GetCameraPos()
{
    #ifdef SHADOWS_SCREEN
    return _WorldSpaceCameraPos;
    #else
    return UNITY_MATRIX_I_V._m03_m13_m23;
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
    float3 camerapos = GetCameraPos();
    return UNITY_MATRIX_P._m33 != 0.0 ? UNITY_MATRIX_V._m20_m21_m22 :
        (dot(camerapos.xyz,camerapos.xyz) > 100000000 ? normalize(V) : normalize(camerapos.xyz - posWorld));
}

float3 O2VDir(float4 vertex)
{
    float4x4 matrixM = unity_ObjectToWorld;
    matrixM._m03_m13_m23 -= _WorldSpaceCameraPos.xyz;
    return normalize(-mul(matrixM, vertex).xyz);
}

bool IsPerspective()
{
    return UNITY_MATRIX_P._m33 == 0.0;
}

bool IsShadowCaster()
{
    #ifdef UNITY_PASS_SHADOWCASTER
        #ifndef SHADOWS_CUBE
        return !IsPerspective();
        #endif
        return true;
    #endif
    return false;
}

// Depth

#if defined(UNITY_SINGLE_PASS_STEREO)
    float2 ScreenUV(float4 pos){ return pos.xy / _ScreenParams.xy * float2(0.5,1.0); }
    float2 ClampScreenUV(float2 uv){ return UnityStereoClamp(uv, unity_StereoScaleOffset[unity_StereoEyeIndex]); }
#else
    float2 ScreenUV(float4 pos){ return pos.xy / _ScreenParams.xy; }
    float2 ClampScreenUV(float2 uv){ return saturate(uv); }
#endif

#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
    Texture2DArray _GrabTexture;
    Texture2DArray _CameraDepthTexture;

    bool IsCameraDepthGenerated()
    {
        uint w, h, a;
        _CameraDepthTexture.GetDimensions(w,h,a);
        #if defined(UNITY_SINGLE_PASS_STEREO)
            return (abs(w - _ScreenParams.x * 2) + abs(h - _ScreenParams.y)) < 1;
        #else
            return (abs(w - _ScreenParams.x) + abs(h - _ScreenParams.y)) < 1;
        #endif
    }

    half SampleDepth(float2 uv)
    {
        return _CameraDepthTexture.Sample(sampler_linear_clamp, float3(uv, unity_StereoEyeIndex)).r;
    }

    half4 SampleScreen(float2 uv)
    {
        return _GrabTexture.Sample(sampler_linear_clamp, float3(uv, unity_StereoEyeIndex));
    }
#else
    Texture2D _GrabTexture;
    Texture2D_float _CameraDepthTexture;

    bool IsCameraDepthGenerated()
    {
        uint w, h;
        _CameraDepthTexture.GetDimensions(w,h);
        #if defined(UNITY_SINGLE_PASS_STEREO)
            return (abs(w - _ScreenParams.x * 2) + abs(h - _ScreenParams.y)) < 1;
        #else
            return (abs(w - _ScreenParams.x) + abs(h - _ScreenParams.y)) < 1;
        #endif
    }

    half SampleDepth(float2 uv)
    {
        return _CameraDepthTexture.Sample(sampler_linear_clamp, uv).r;
    }

    half4 SampleScreen(float2 uv)
    {
        return _GrabTexture.Sample(sampler_linear_clamp, uv);
    }
#endif

float lilLinearEyeDepth(float z, float2 uvScreen)
{
    float2 pos = uvScreen * 2.0 - 1.0;
    #if UNITY_UV_STARTS_AT_TOP
        pos.y = -pos.y;
    #endif
    return UNITY_MATRIX_P._m23 / (z + UNITY_MATRIX_P._m22
        - UNITY_MATRIX_P._m20 / UNITY_MATRIX_P._m00 * (uvScreen.x + UNITY_MATRIX_P._m02)
        - UNITY_MATRIX_P._m21 / UNITY_MATRIX_P._m11 * (uvScreen.y + UNITY_MATRIX_P._m12)
    );
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
        return _WorldSpaceCameraPos + depth / dot(-UNITY_MATRIX_V._m20_m21_m22, V) * V;
    }
    else
    {
        return 0;
    }
}

// Lightings

void OverrideByPlatform(inout ShadingParams p, v2f i)
{
}

#ifdef LIL_VRCLIGHTVOLUMES
#include "Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc"
void VRCLightVolumes(inout half3 diff, inout half3 spec, ShadingParams p)
{
    #ifdef UNITY_PASS_FORWARDBASE
    if (_UdonLightVolumeEnabled)
    {
        float3 L0, L1r, L1g, L1b = 0;
        #if LIGHTMAP_ON
        LightVolumeAdditiveSH(p.posWorld, L0, L1r, L1g, L1b);
        diff += LightVolumeEvaluate(p.N, L0, L1r, L1g, L1b);
        #else
        LightVolumeSH(p.posWorld, L0, L1r, L1g, L1b);
        diff = LightVolumeEvaluate(p.N, L0, L1r, L1g, L1b);
        #endif
        spec = LightVolumeSpecular(p.albedo, p.smoothness, p.metallic, p.N, p.V, L0, L1r, L1g, L1b);
    }
    #endif
}
#else
void VRCLightVolumes(inout half3 diff, inout half3 spec, ShadingParams p){}
#endif

#ifdef LIL_LTCGI
#include "Packages/at.pimaker.ltcgi/Shaders/LTCGI.cginc"
void LTCGI(inout half3 diff, inout half3 spec, ShadingParams p)
{
    #ifdef UNITY_PASS_FORWARDBASE
    float totalSpecularIntensity, totalDiffuseIntensity = 0;
    LTCGI_Contribution(p.posWorld, p.N, p.V, p.perceptualRoughness, p.uv[1], diff, spec, totalSpecularIntensity, totalDiffuseIntensity);
    #endif
}
#else
void LTCGI(inout half3 diff, inout half3 spec, ShadingParams p){}
#endif

half3 GetGI(ShadingParams p, v2f i, half attenuation, out half3 lightColor, out half3 L)
{
    UnityGIInput data;
    UNITY_INITIALIZE_OUTPUT(UnityGIInput, data);
    #if defined(UNITY_PASS_FORWARDBASE)
        data.light.color = _LightColor0.rgb * attenuation;
        data.light.dir = _WorldSpaceLightPos0.xyz;
    #elif defined(UNITY_PASS_FORWARDADD)
        data.light.color = _LightColor0.rgb * attenuation;
        data.light.dir = normalize(UnityWorldSpaceLightDir(p.posWorld.xyz));
    #endif
    data.worldPos = p.posWorld;
    data.worldViewDir = p.V;
    data.atten = attenuation;
    #ifdef LIGHTMAP_ON
        data.lightmapUV.xy = p.uv[1] * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        data.lightmapUV.zw = p.uv[2] * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    UnityGI gi = UnityGI_Base(data, p.occlusion, p.bentN);
    lightColor = data.light.color;
    L = data.light.dir;
    return gi.indirect.diffuse;
}

half3 GetReflection(ShadingParams p, v2f i)
{
    half3 reflectCol = 0;
    #ifdef UNITY_PASS_FORWARDBASE
        half NdotV = saturate(dot(p.N, p.V));
        UnityGIInput data;
        UNITY_INITIALIZE_OUTPUT(UnityGIInput, data);
        data.worldPos = p.posWorld;
        data.probeHDR[0] = unity_SpecCube0_HDR;
        data.probeHDR[1] = unity_SpecCube1_HDR;
        #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
            data.boxMin[0] = unity_SpecCube0_BoxMin;
        #endif
        #ifdef UNITY_SPECCUBE_BOX_PROJECTION
            data.boxMax[0] = unity_SpecCube0_BoxMax;
            data.probePosition[0] = unity_SpecCube0_ProbePosition;
            data.boxMax[1] = unity_SpecCube1_BoxMax;
            data.boxMin[1] = unity_SpecCube1_BoxMin;
            data.probePosition[1] = unity_SpecCube1_ProbePosition;
        #endif

        Unity_GlossyEnvironmentData glossIn;
        glossIn.roughness = p.perceptualRoughness;
        glossIn.reflUVW   = -reflect(p.V,p.refN);

        reflectCol = UnityGI_IndirectSpecular(data, 1.0, glossIn);
    #endif
    return reflectCol;
}

void ComputeLights(out half3 diff, out half3 spec, out half3 reflectionStrength, ShadingParams p, v2f i)
{
    UNITY_LIGHT_ATTENUATION(attenuation, i, p.posWorld);
    half3 lightColor, L;

    // Environment Light
    diff = 0;
    spec = 0;
    diff += GetGI(p, i, attenuation, lightColor, L);
    VRCLightVolumes(diff, spec, p);
    LTCGI(diff, spec, p);
    spec += GetReflection(p, i) * GetReflectionStrength(p, reflectionStrength);

    half NdotR = saturate(dot(-reflect(p.V,p.refN),p.origN) + 0.5);
    reflectionStrength *= NdotR;
    spec *= NdotR;

    // Main Light
    DoLight(diff, spec, p, L, lightColor);

    // Vertex Light
    #if !LIGHTMAP_ON && UNITY_SHOULD_SAMPLE_SH && VERTEXLIGHT_ON
    float4 toLightX = unity_4LightPosX0 - p.posWorld.x;
    float4 toLightY = unity_4LightPosY0 - p.posWorld.y;
    float4 toLightZ = unity_4LightPosZ0 - p.posWorld.z;

    float4 lengthSq = toLightX * toLightX + 0.000001;
    lengthSq += toLightY * toLightY;
    lengthSq += toLightZ * toLightZ;

    float4 atten = saturate(saturate((25.0 - lengthSq * unity_4LightAtten0) * 0.111375) / (0.987725 + lengthSq * unity_4LightAtten0));

    [unroll]
    for(int i = 0; i < 4; i++)
    {
        half3 L = half3(toLightX[i], toLightY[i], toLightZ[i]) * rsqrt(lengthSq[i]);
        half3 lightColor = unity_LightColor[i].rgb * atten[i];
        DoLight(diff, spec, p, L, lightColor);
    }
    #endif
}

half3 DoTranslucent(ShadingParams p, v2f i, half translucentRoughness)
{
    #ifdef UNITY_PASS_FORWARDBASE
        UnityGIInput data;
        UNITY_INITIALIZE_OUTPUT(UnityGIInput, data);
        data.worldPos = p.posWorld;
        data.probeHDR[0] = unity_SpecCube0_HDR;
        data.probeHDR[1] = unity_SpecCube1_HDR;
        #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
            data.boxMin[0] = unity_SpecCube0_BoxMin;
        #endif
        #ifdef UNITY_SPECCUBE_BOX_PROJECTION
            data.boxMax[0] = unity_SpecCube0_BoxMax;
            data.probePosition[0] = unity_SpecCube0_ProbePosition;
            data.boxMax[1] = unity_SpecCube1_BoxMax;
            data.boxMin[1] = unity_SpecCube1_BoxMin;
            data.probePosition[1] = unity_SpecCube1_ProbePosition;
        #endif

        Unity_GlossyEnvironmentData glossIn;
        glossIn.roughness = translucentRoughness;
        glossIn.reflUVW   = -p.V+p.N*0.2;

        return UnityGI_IndirectSpecular(data, 1.0, glossIn);
    #else
        return 0;
    #endif
}

half GetSubsurfaceForwardScatter(half3 lightDirection, ShadingParams p, half lightpow)
{
    half forwardScatter = pow(saturate(dot(lightDirection, -p.V)), lightpow);
    half wrappedDiffuse = saturate((dot(p.N, lightDirection) + _SubsurfaceWrap) / (1.0 + _SubsurfaceWrap));
    return lerp(forwardScatter, max(forwardScatter, wrappedDiffuse), _SubsurfaceWrap);
}

void ComputeSubsurface(out half3 diff, ShadingParams p, v2f i)
{
    half3 lightColor, L;
    diff = GetGI(p, i, 1, lightColor, L);
    half roughness = p.subsurfaceThickness * 0.5;
    half lightpow = rcp(max(roughness * roughness, 0.002));

    #ifdef UNITY_PASS_FORWARDBASE
        UnityGIInput data;
        UNITY_INITIALIZE_OUTPUT(UnityGIInput, data);
        data.worldPos = p.posWorld;
        data.probeHDR[0] = unity_SpecCube0_HDR;
        data.probeHDR[1] = unity_SpecCube1_HDR;
        #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
            data.boxMin[0] = unity_SpecCube0_BoxMin;
        #endif
        #ifdef UNITY_SPECCUBE_BOX_PROJECTION
            data.boxMax[0] = unity_SpecCube0_BoxMax;
            data.probePosition[0] = unity_SpecCube0_ProbePosition;
            data.boxMax[1] = unity_SpecCube1_BoxMax;
            data.boxMin[1] = unity_SpecCube1_BoxMin;
            data.probePosition[1] = unity_SpecCube1_ProbePosition;
        #endif

        Unity_GlossyEnvironmentData glossIn;
        glossIn.roughness = roughness;
        glossIn.reflUVW   = -p.V;

        diff += UnityGI_IndirectSpecular(data, 1.0, glossIn) * _SubsurfaceEnvironmentStrength;
    #endif

    // Main Light
    diff += GetSubsurfaceForwardScatter(L, p, lightpow) * lightColor * _SubsurfaceDirectStrength;

    // Vertex Light
    #if !LIGHTMAP_ON && UNITY_SHOULD_SAMPLE_SH && VERTEXLIGHT_ON
    float4 toLightX = unity_4LightPosX0 - p.posWorld.x;
    float4 toLightY = unity_4LightPosY0 - p.posWorld.y;
    float4 toLightZ = unity_4LightPosZ0 - p.posWorld.z;

    float4 lengthSq = toLightX * toLightX + 0.000001;
    lengthSq += toLightY * toLightY;
    lengthSq += toLightZ * toLightZ;

    float4 atten = saturate(saturate((25.0 - lengthSq * unity_4LightAtten0) * 0.111375) / (0.987725 + lengthSq * unity_4LightAtten0));

    [unroll]
    for(int i = 0; i < 4; i++)
    {
        half3 L = half3(toLightX[i], toLightY[i], toLightZ[i]) * rsqrt(lengthSq[i]);
        diff += GetSubsurfaceForwardScatter(L, p, lightpow) * atten[i] * unity_LightColor[i].rgb * _SubsurfaceDirectStrength;
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
    UNITY_APPLY_FOG(i.fogCoord, col);

    #if defined(UNITY_PASS_FORWARDBASE) && defined(LIL_VRCLIGHTVOLUMES)
    // LVFog
    if(_VFogDensity)
    {
        float noise = ibuki(i.pos);
        float3 opaquePos = p.posWorld;
        float3 cameraPos = GetCameraPos();
        for(int count = 16; count > 0; count--)
        {
            float3 posWorld = cameraPos - p.V * pow((count + noise), 1.5);
            half fade = saturate(rawDistance(opaquePos,cameraPos) - rawDistance(posWorld,cameraPos)) * _VFogDensity;
            fade *= fade;
            fade *= saturate(16 * 0.1 - count * 0.1);

            // Height
            float height = _VFogNoise.Sample(sampler_linear_repeat, posWorld.xz * 0.0025 + _Time.x * 0.036 * float2(_VFogScrollX, _VFogScrollZ)).r;
            height += _VFogNoise.Sample(sampler_linear_repeat, posWorld.xz * 0.01 + _Time.x * 0.2 * float2(_VFogScrollX, _VFogScrollZ)).r * 0.5 - 0.25;
            height = height * _VFogHeightScale + _VFogHeightOffset;
            fade *= saturate(1 - abs(posWorld.y - height) * _VFogHeightSharpness);

            half3 lv = LightVolumeSH_L0(posWorld);
            col.rgb = lerp(col.rgb, lv * 2, fade * saturate(lv));
        }
    }
    #endif

    // Skybox Fog
    //UNITY_APPLY_FOG_COLOR(i.fogCoord, col, DoTranslucent(p,i,0));
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
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

#define LILPBR_PROPERTY(t,n) t n;
#define LILPBR_TEXTURE(t,n) t n;
#define LILPBR_SAMPLER(t,n) t n;

LILPBR_PROPERTIES
LILPBR_TEXTURES
LILPBR_SAMPLERS

#endif
