Shader "lilPBR/Water/Flowmap Water"
{
    Properties
    {
        [LILFoldout(Surface)]
        [LILPropertyCache] _SurfaceColor ("Surface Color", Color) = (0.18, 0.48, 0.62, 0.72)
        _SurfaceAlpha ("Surface Alpha", Range(0.0, 1.0)) = 0.72
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.92
        _Wetness ("Wetness", Range(0.0, 1.0)) = 1.0
        _WetnessSmoothnessBoost ("Wetness Smoothness Boost", Range(0.0, 1.0)) = 0.08
        _WetnessColor ("Wetness Tint", Color) = (0.09, 0.22, 0.28, 1.0)
        [LILFoldoutEnd]

        [LILFoldout(Flow)]
        _FlowMap0 ("Flow Map 0 (RG)", 2D) = "gray" {}
        _FlowStrength0 ("Flow Strength 0", Range(0.0, 1.0)) = 0.18
        _FlowSpeed0 ("Flow Speed 0", Range(-4.0, 4.0)) = 0.12
        [LILVector2] _FlowMap0Scroll ("Flow Map 0 Scroll XY", Vector) = (0,0,0,0)
        _FlowMap1 ("Flow Map 1 (RG)", 2D) = "gray" {}
        _FlowStrength1 ("Flow Strength 1", Range(0.0, 1.0)) = 0.08
        _FlowSpeed1 ("Flow Speed 1", Range(-4.0, 4.0)) = -0.07
        [LILVector2] _FlowMap1Scroll ("Flow Map 1 Scroll XY", Vector) = (0,0,0,0)
        [LILFoldoutEnd]

        [LILFoldout(Normal)]
        [Normal] _NormalMap0 ("Normal Map 0", 2D) = "bump" {}
        _NormalScale0 ("Normal Scale 0", Range(0.0, 4.0)) = 1.0
        [Normal] _NormalMap1 ("Normal Map 1", 2D) = "bump" {}
        _NormalScale1 ("Normal Scale 1", Range(0.0, 4.0)) = 0.45
        _NormalStrength ("Buffer Normal Strength", Range(0.0, 2.0)) = 1.0
        [LILFoldoutEnd]

        [LILFoldout(Lighting)]
        _ReceiveShadowStrength ("Receive Shadow Strength", Range(0.0, 1.0)) = 1.0
        _ShadowMinLight ("Shadow Min Light", Range(0.0, 1.0)) = 0.38
        _ShadowTint ("Shadow Tint", Color) = (0.08, 0.18, 0.24, 1.0)
        _IndirectStrength ("Indirect Strength", Range(0.0, 2.0)) = 0.65
        _SpecularStrength ("Specular Strength", Range(0.0, 4.0)) = 1.2
        [HDR] _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        [LILFoldoutEnd]

        [LILFoldout(Planar Reflection)]
        [ToggleUI] _UsePlanarReflection ("Planar Reflection", Int) = 1
        [LILIf(_UsePlanarReflection, 1)] _PlanarReflectionStrength ("Strength", Range(0.0, 1.0)) = 1.0
        [LILIf(_UsePlanarReflection, 1)] _PlanarReflectionMinSmoothness ("Min Smoothness", Range(0.0, 1.0)) = 0.65
        [LILIf(_UsePlanarReflection, 1)] _PlanarReflectionDistortion ("Normal Distortion", Range(0.0, 0.1)) = 0.018
        [LILIf(_UsePlanarReflection, 1)] _PlanarReflectionTint ("Tint", Color) = (1,1,1,1)
        [LILIf(_UsePlanarReflection, 1)][ToggleUI] _PlanarReflectionFlipY ("Flip Y", Int) = 0
        [HideInInspector][NoScaleOffset] _LILPBRPlanarReflectionTexture ("Planar Reflection Texture", 2D) = "black" {}
        [LILFoldoutEnd]

        [LILFoldout(MetadataBuffer)]
        _BufferCoverage ("Buffer Coverage", Range(0.0, 1.0)) = 1.0
        [HideInInspector] _HoMetadataBufferMaskWeight ("MetadataBuffer Mask Weight", Range(0, 1)) = 1
        [HideInInspector] _HoMetadataBufferSystemWriteMask ("MetadataBuffer System Write Mask", Float) = 3847
        [HideInInspector] _HoMetadataBufferCustomWriteMask ("MetadataBuffer Custom Write Mask", Float) = 0
        [HideInInspector] _HoMetadataBufferCustomValues0 ("MetadataBuffer Custom 0-3", Vector) = (0,0,0,0)
        [HideInInspector] _HoMetadataBufferGroupId ("MetadataBuffer Group ID", Float) = 0
        [HideInInspector] _HoMetadataBufferObjectId ("MetadataBuffer Object ID", Float) = 0
        [HideInInspector] _HoMetadataBufferFlags ("MetadataBuffer Flags", Float) = 0
        [HideInInspector] _HoMetadataBufferMaterialClass ("MetadataBuffer Material Class", Float) = 8
        [HideInInspector] _HoMetadataBufferThickness ("MetadataBuffer Thickness", Range(0, 1)) = 0
        [HideInInspector] _HoMetadataBufferCurvature ("MetadataBuffer Curvature", Range(-1, 1)) = 0
        [HideInInspector] _HoMetadataBufferTransmittanceHint ("MetadataBuffer Transmittance Hint", Range(0, 1)) = 0
        [HideInInspector] _HoMetadataBufferObjectCustomMask ("MetadataBuffer Object Custom Mask", Float) = 0
        [LILPropertyCache] _HoMetadataBufferCustom0Color ("Custom 0", Color) = (0,0,0,0)
        [NoScaleOffset] _HoMetadataBufferCustom0Tex ("Custom 0", 2D) = "white" {}
        [LILPropertyCacheClear]
        [LILPropertyCache] _HoMetadataBufferCustom1Color ("Custom 1", Color) = (0,0,0,0)
        [NoScaleOffset] _HoMetadataBufferCustom1Tex ("Custom 1", 2D) = "white" {}
        [LILPropertyCacheClear]
        [LILPropertyCache] _HoMetadataBufferCustom2Color ("Custom 2", Color) = (0,0,0,0)
        [NoScaleOffset] _HoMetadataBufferCustom2Tex ("Custom 2", 2D) = "white" {}
        [LILPropertyCacheClear]
        [LILPropertyCache] _HoMetadataBufferCustom3Color ("Custom 3", Color) = (0,0,0,0)
        [NoScaleOffset] _HoMetadataBufferCustom3Tex ("Custom 3", 2D) = "white" {}
        [LILPropertyCacheClear]
        [LILFoldoutEnd]

        [LILFoldout(Advanced)]
        [Enum(Off, 0, Front, 1, Back, 2)] _Cull ("Cull", Int) = 2
        [ToggleUI] _ZWrite ("ZWrite", Int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("SrcBlend", Int) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("DstBlend", Int) = 10
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendAlpha ("SrcBlendAlpha", Int) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlendAlpha ("DstBlendAlpha", Int) = 10
        [LILFoldoutEnd]
        [HideInInspector] _WaterFlowmapAdvancedEnd ("Advanced End", Float) = 0
    }

    HLSLINCLUDE
    #pragma target 4.5
    #pragma multi_compile_instancing
    #pragma instancing_options renderinglayer

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    TEXTURE2D(_FlowMap0); SAMPLER(sampler_FlowMap0);
    TEXTURE2D(_FlowMap1); SAMPLER(sampler_FlowMap1);
    TEXTURE2D(_NormalMap0); SAMPLER(sampler_NormalMap0);
    TEXTURE2D(_NormalMap1); SAMPLER(sampler_NormalMap1);
    TEXTURE2D(_LILPBRPlanarReflectionTexture); SAMPLER(sampler_LILPBRPlanarReflectionTexture);
    TEXTURE2D(_HoMetadataBufferCustom0Tex); SAMPLER(sampler_HoMetadataBufferCustom0Tex);
    TEXTURE2D(_HoMetadataBufferCustom1Tex); SAMPLER(sampler_HoMetadataBufferCustom1Tex);
    TEXTURE2D(_HoMetadataBufferCustom2Tex); SAMPLER(sampler_HoMetadataBufferCustom2Tex);
    TEXTURE2D(_HoMetadataBufferCustom3Tex); SAMPLER(sampler_HoMetadataBufferCustom3Tex);

    CBUFFER_START(UnityPerMaterial)
        float4 _SurfaceColor;
        float _SurfaceAlpha;
        float _Smoothness;
        float _Wetness;
        float _WetnessSmoothnessBoost;
        float4 _WetnessColor;
        float4 _FlowMap0_ST;
        float _FlowStrength0;
        float _FlowSpeed0;
        float4 _FlowMap0Scroll;
        float4 _FlowMap1_ST;
        float _FlowStrength1;
        float _FlowSpeed1;
        float4 _FlowMap1Scroll;
        float4 _NormalMap0_ST;
        float _NormalScale0;
        float4 _NormalMap1_ST;
        float _NormalScale1;
        float _NormalStrength;
        float _ReceiveShadowStrength;
        float _ShadowMinLight;
        float4 _ShadowTint;
        float _IndirectStrength;
        float _SpecularStrength;
        float4 _SpecularColor;
        uint _UsePlanarReflection;
        float _PlanarReflectionStrength;
        float _PlanarReflectionMinSmoothness;
        float _PlanarReflectionDistortion;
        float4 _PlanarReflectionTint;
        uint _PlanarReflectionFlipY;
        float _BufferCoverage;
        float _HoMetadataBufferMaskWeight;
        float _HoMetadataBufferSystemWriteMask;
        float _HoMetadataBufferCustomWriteMask;
        float4 _HoMetadataBufferCustomValues0;
        float _HoMetadataBufferGroupId;
        float _HoMetadataBufferObjectId;
        float _HoMetadataBufferFlags;
        float _HoMetadataBufferMaterialClass;
        float _HoMetadataBufferThickness;
        float _HoMetadataBufferCurvature;
        float _HoMetadataBufferTransmittanceHint;
        float _HoMetadataBufferObjectCustomMask;
        float4 _HoMetadataBufferCustom0Color;
        float4 _HoMetadataBufferCustom1Color;
        float4 _HoMetadataBufferCustom2Color;
        float4 _HoMetadataBufferCustom3Color;
    CBUFFER_END

    float4 _LILPBRPlanarReflectionParams;

    struct Attributes
    {
        float4 positionOS : POSITION;
        float3 normalOS : NORMAL;
        float4 tangentOS : TANGENT;
        float2 uv : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float3 positionWS : TEXCOORD0;
        float3 normalWS : TEXCOORD1;
        float4 tangentWS : TEXCOORD2;
        float2 uv : TEXCOORD3;
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    struct WaterSurface
    {
        half3 color;
        half alpha;
        half smoothness;
        half wetness;
        half3 normalTS;
        half3 normalWS;
        half3 viewDirWS;
    };

    struct MetadataOutput
    {
        half4 maskId : SV_Target0;
        half4 surfaceData : SV_Target1;
        half4 custom0 : SV_Target2;
        half4 objectCustom0 : SV_Target3;
        half4 objectCustom1 : SV_Target4;
    };

    Varyings Vert(Attributes input)
    {
        Varyings output = (Varyings)0;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_TRANSFER_INSTANCE_ID(input, output);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
        VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
        output.positionCS = positionInputs.positionCS;
        output.positionWS = positionInputs.positionWS;
        output.normalWS = normalInputs.normalWS;
        output.tangentWS = float4(normalInputs.tangentWS, input.tangentOS.w * GetOddNegativeScale());
        output.uv = input.uv;
        return output;
    }

    half3 BlendNormals(half3 a, half3 b)
    {
        return normalize(half3(a.xy + b.xy, a.z * b.z));
    }

    half3 ApplyNormalStrength(half3 normalTS, half strength)
    {
        normalTS.xy *= strength;
        normalTS.z = sqrt(saturate(1.0h - dot(normalTS.xy, normalTS.xy)));
        return normalize(normalTS);
    }

    half3 SampleFlowedNormal0(float2 uv)
    {
        float2 flowUV = uv * _FlowMap0_ST.xy + _FlowMap0_ST.zw + _FlowMap0Scroll.xy * _Time.y;
        half2 flow = (SAMPLE_TEXTURE2D(_FlowMap0, sampler_FlowMap0, flowUV).rg * 2.0h - 1.0h) * _FlowStrength0;
        float phaseA = frac(_Time.y * _FlowSpeed0);
        float phaseB = frac(phaseA + 0.5);
        float blend = abs(phaseA * 2.0 - 1.0);
        float2 normalUV = uv * _NormalMap0_ST.xy + _NormalMap0_ST.zw;
        half3 normalA = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap0, sampler_NormalMap0, normalUV + flow * phaseA), _NormalScale0);
        half3 normalB = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap0, sampler_NormalMap0, normalUV + flow * phaseB), _NormalScale0);
        return normalize(lerp(normalA, normalB, blend));
    }

    half3 SampleFlowedNormal1(float2 uv)
    {
        float2 flowUV = uv * _FlowMap1_ST.xy + _FlowMap1_ST.zw + _FlowMap1Scroll.xy * _Time.y;
        half2 flow = (SAMPLE_TEXTURE2D(_FlowMap1, sampler_FlowMap1, flowUV).rg * 2.0h - 1.0h) * _FlowStrength1;
        float phaseA = frac(_Time.y * _FlowSpeed1 + 0.25);
        float phaseB = frac(phaseA + 0.5);
        float blend = abs(phaseA * 2.0 - 1.0);
        float2 normalUV = uv * _NormalMap1_ST.xy + _NormalMap1_ST.zw;
        half3 normalA = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap1, sampler_NormalMap1, normalUV + flow * phaseA), _NormalScale1);
        half3 normalB = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap1, sampler_NormalMap1, normalUV + flow * phaseB), _NormalScale1);
        return normalize(lerp(normalA, normalB, blend));
    }

    half3 ResolveNormalTS(float2 uv)
    {
        half3 normalTS = BlendNormals(SampleFlowedNormal0(uv), SampleFlowedNormal1(uv));
        return ApplyNormalStrength(normalTS, _NormalStrength);
    }

    half3 ResolveNormalWS(Varyings input, half3 normalTS)
    {
        half3 normalWS = normalize(input.normalWS);
        half3 tangentWS = normalize(input.tangentWS.xyz);
        half3 bitangentWS = normalize(cross(normalWS, tangentWS) * input.tangentWS.w);
        half3x3 tangentToWorld = half3x3(tangentWS, bitangentWS, normalWS);
        return normalize(mul(normalTS, tangentToWorld));
    }

    WaterSurface ResolveWaterSurface(Varyings input)
    {
        WaterSurface surface;
        surface.alpha = saturate(_SurfaceColor.a * _SurfaceAlpha);
        surface.wetness = saturate(_Wetness);
        surface.smoothness = saturate(_Smoothness + surface.wetness * _WetnessSmoothnessBoost);
        surface.color = lerp(_SurfaceColor.rgb, _SurfaceColor.rgb * _WetnessColor.rgb, surface.wetness * _WetnessColor.a);
        surface.normalTS = ResolveNormalTS(input.uv);
        surface.normalWS = ResolveNormalWS(input, surface.normalTS);
        surface.viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
        return surface;
    }

    half MetadataHasBit(float value, float bitValue)
    {
        return step(0.5, fmod(floor(value / bitValue), 2.0));
    }

    half MetadataHasSystemChannel(float bitValue)
    {
        return MetadataHasBit(_HoMetadataBufferSystemWriteMask, bitValue);
    }

    half MetadataEncodeScalar(float value)
    {
        return frac(abs(value) * 0.61803398875);
    }

    half MetadataEncodeByte(float value)
    {
        return saturate(round(clamp(value, 0.0, 255.0)) / 255.0);
    }

    float4 MetadataApplyCustomWriteMask(float4 values, float startBit)
    {
        if (_HoMetadataBufferCustomWriteMask < 0.5)
        {
            return values;
        }

        return float4(
            values.x * MetadataHasBit(_HoMetadataBufferCustomWriteMask, exp2(startBit)),
            values.y * MetadataHasBit(_HoMetadataBufferCustomWriteMask, exp2(startBit + 1.0)),
            values.z * MetadataHasBit(_HoMetadataBufferCustomWriteMask, exp2(startBit + 2.0)),
            values.w * MetadataHasBit(_HoMetadataBufferCustomWriteMask, exp2(startBit + 3.0)));
    }

    float MetadataByteToFloat(uint value, uint shift)
    {
        return (float)((value >> shift) & 255u);
    }

    float MetadataHasObjectCustomBit(uint mask, uint bitIndex)
    {
        return (float)((mask >> bitIndex) & 1u);
    }

    float4 MetadataDecodeObjectCustom0(uint mask)
    {
        return float4(
            MetadataHasObjectCustomBit(mask, 0u),
            MetadataHasObjectCustomBit(mask, 1u),
            MetadataHasObjectCustomBit(mask, 2u),
            MetadataHasObjectCustomBit(mask, 3u));
    }

    float4 MetadataDecodeObjectCustom1(uint mask)
    {
        return float4(
            MetadataHasObjectCustomBit(mask, 4u),
            MetadataHasObjectCustomBit(mask, 5u),
            MetadataHasObjectCustomBit(mask, 6u),
            MetadataHasObjectCustomBit(mask, 7u));
    }

    half4 ResolveWaterCustom0(WaterSurface surface)
    {
        if (_HoMetadataBufferCustomWriteMask >= 0.5)
        {
            return half4(MetadataApplyCustomWriteMask(_HoMetadataBufferCustomValues0, 0.0));
        }

        return half4(surface.smoothness, surface.wetness, saturate(_NormalStrength), saturate(_PlanarReflectionStrength));
    }

    half3 ApplyPlanarReflection(Varyings input, WaterSurface surface, half3 litColor)
    {
        if (_UsePlanarReflection == 0 || _PlanarReflectionStrength <= 0.0 || _LILPBRPlanarReflectionParams.x <= 0.5)
        {
            return litColor;
        }

        half smoothnessFade = saturate((surface.smoothness - _PlanarReflectionMinSmoothness) / max(1.0 - _PlanarReflectionMinSmoothness, 0.0001));
        if (smoothnessFade <= 0.0)
        {
            return litColor;
        }

        float2 uv = GetNormalizedScreenSpaceUV(input.positionCS);
        if (_PlanarReflectionFlipY != 0)
        {
            uv.y = 1.0 - uv.y;
        }

        uv += surface.normalTS.xy * _PlanarReflectionDistortion;
        if (any(uv < 0.0) || any(uv > 1.0))
        {
            return litColor;
        }

        half fresnel = pow(1.0h - saturate(dot(surface.normalWS, surface.viewDirWS)), 5.0h);
        half weight = saturate(_PlanarReflectionStrength * smoothnessFade * lerp(0.35h, 1.0h, fresnel) * _PlanarReflectionTint.a);
        half3 reflection = SAMPLE_TEXTURE2D(_LILPBRPlanarReflectionTexture, sampler_LILPBRPlanarReflectionTexture, uv).rgb * _PlanarReflectionTint.rgb;
        return lerp(litColor, reflection, weight);
    }

    half3 ShadeWater(Varyings input, WaterSurface surface)
    {
        float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
        Light mainLight = GetMainLight(shadowCoord);

        half shadow = lerp(1.0h, mainLight.shadowAttenuation, saturate(_ReceiveShadowStrength));
        half shadowLight = lerp(saturate(_ShadowMinLight), 1.0h, shadow);
        half nDotL = saturate(dot(surface.normalWS, mainLight.direction));
        half directShape = lerp(0.35h, 1.0h, nDotL);
        half3 shadowedColor = lerp(surface.color * _ShadowTint.rgb, surface.color, shadowLight);
        half3 color = shadowedColor * SampleSH(surface.normalWS) * _IndirectStrength;
        color += shadowedColor * mainLight.color * directShape * shadowLight;

        half3 halfDir = SafeNormalize(mainLight.direction + surface.viewDirWS);
        half nDotH = saturate(dot(surface.normalWS, halfDir));
        half specPower = exp2(lerp(5.0h, 11.0h, surface.smoothness));
        color += pow(nDotH, specPower) * surface.smoothness * shadow * mainLight.color * _SpecularColor.rgb * _SpecularStrength;

        #if defined(_ADDITIONAL_LIGHTS)
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
        {
            Light light = GetAdditionalLight(lightIndex, input.positionWS, half4(1.0h, 1.0h, 1.0h, 1.0h));
            half lightNdotL = saturate(dot(surface.normalWS, light.direction));
            half lightShadow = lerp(1.0h, light.shadowAttenuation, saturate(_ReceiveShadowStrength));
            half lightShape = lerp(0.25h, 1.0h, lightNdotL) * light.distanceAttenuation * lightShadow;
            color += shadowedColor * light.color * lightShape;

            half3 lightHalfDir = SafeNormalize(light.direction + surface.viewDirWS);
            half lightNdotH = saturate(dot(surface.normalWS, lightHalfDir));
            color += pow(lightNdotH, specPower) * surface.smoothness * light.distanceAttenuation * lightShadow * light.color * _SpecularColor.rgb * _SpecularStrength;
        }
        #endif

        return ApplyPlanarReflection(input, surface, color);
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            Blend [_SrcBlend] [_DstBlend], [_SrcBlendAlpha] [_DstBlendAlpha]
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragForward
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH

            half4 FragForward(Varyings input, bool isFront : SV_IsFrontFace) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                WaterSurface surface = ResolveWaterSurface(input);
                if (!isFront)
                {
                    surface.normalWS = -surface.normalWS;
                }

                half3 color = ShadeWater(input, surface);
                return half4(color, surface.alpha);
            }
            ENDHLSL
        }

        Pass
        {
            Name "HoMetadataBuffer"
            Tags { "LightMode" = "HoMetadataBuffer" }
            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragMetadata

            MetadataOutput FragMetadata(Varyings input)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                WaterSurface surface = ResolveWaterSurface(input);
                half maskEnabled = MetadataHasSystemChannel(1.0);
                half idEnabled = MetadataHasSystemChannel(2.0);
                half flagsEnabled = MetadataHasSystemChannel(4.0);
                half thicknessEnabled = MetadataHasSystemChannel(256.0);
                half curvatureEnabled = MetadataHasSystemChannel(512.0);
                half materialEnabled = MetadataHasSystemChannel(1024.0);
                half transmittanceHintEnabled = MetadataHasSystemChannel(2048.0);
                half subjectCoverage = saturate(_HoMetadataBufferMaskWeight) * saturate(_BufferCoverage);
                half subjectValid = step(0.0001h, subjectCoverage);

                uint rendererUserValue = unity_RendererUserValue;
                bool hasRendererUserValue = rendererUserValue != 0u;
                uint objectCustomMask = hasRendererUserValue ? (rendererUserValue & 255u) : (uint)round(saturate(_HoMetadataBufferObjectCustomMask / 255.0) * 255.0);
                float effectiveGroupId = hasRendererUserValue ? MetadataByteToFloat(rendererUserValue, 8u) : _HoMetadataBufferGroupId;
                float effectiveObjectId = hasRendererUserValue ? MetadataByteToFloat(rendererUserValue, 16u) : _HoMetadataBufferObjectId;
                float effectiveFlags = hasRendererUserValue ? MetadataByteToFloat(rendererUserValue, 24u) : _HoMetadataBufferFlags;

                MetadataOutput output;
                output.maskId = half4(
                    subjectCoverage * maskEnabled,
                    MetadataEncodeByte(effectiveGroupId) * idEnabled * subjectValid,
                    MetadataEncodeByte(effectiveObjectId) * idEnabled * subjectValid,
                    MetadataEncodeByte(effectiveFlags) * flagsEnabled * subjectValid);
                output.surfaceData = half4(
                    saturate(_HoMetadataBufferThickness) * thicknessEnabled * subjectValid,
                    saturate(abs(_HoMetadataBufferCurvature)) * curvatureEnabled * subjectValid,
                    MetadataEncodeScalar(_HoMetadataBufferMaterialClass) * materialEnabled * subjectValid,
                    max(saturate(_HoMetadataBufferTransmittanceHint), surface.wetness) * transmittanceHintEnabled * subjectValid);
                output.custom0 = ResolveWaterCustom0(surface) * subjectValid;
                output.objectCustom0 = half4(MetadataDecodeObjectCustom0(objectCustomMask) * subjectValid);
                output.objectCustom1 = half4(MetadataDecodeObjectCustom1(objectCustomMask) * subjectValid);
                return output;
            }
            ENDHLSL
        }

        Pass
        {
            Name "HoGeometryBuffer"
            Tags { "LightMode" = "HoGeometryBuffer" }
            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragGeometry

            half4 FragGeometry(Varyings input, bool isFront : SV_IsFrontFace) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                WaterSurface surface = ResolveWaterSurface(input);
                half3 normalWS = isFront ? surface.normalWS : -surface.normalWS;
                float linearDepth = LinearEyeDepth(input.positionCS.z, _ZBufferParams);
                return half4(normalize(normalWS) * 0.5h + 0.5h, linearDepth);
            }
            ENDHLSL
        }

        Pass
        {
            Name "HoMetadataBufferSurfaceColor"
            Tags { "LightMode" = "HoMetadataBufferSurfaceColor" }
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragMetadataSurfaceColor

            half4 FragMetadataSurfaceColor(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                WaterSurface surface = ResolveWaterSurface(input);
                half subjectCoverage = saturate(_HoMetadataBufferMaskWeight) * saturate(_BufferCoverage);
                half subjectValid = step(0.0001h, subjectCoverage);
                return half4(surface.color, subjectCoverage) * subjectValid;
            }
            ENDHLSL
        }
    }

    Fallback Off
    CustomEditor "jp.lilxyzw.lilpbr.PBRShaderGUI"
}
