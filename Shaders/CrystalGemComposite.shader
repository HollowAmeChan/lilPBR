Shader "lilPBR/Crystal/Gem Composite"
{
    Properties
    {
        [LILFoldout(Surface)]
        [LILPropertyCache] _BaseColor ("基础颜色", Color) = (0.18,0.45,0.95,1)
        _MainTex ("主贴图", 2D) = "white" {}
        _Cutoff ("Alpha 裁剪", Range(0.0, 1.0)) = 0.0
        _MaskTex ("表面遮罩 (R 边缘, G 厚度)", 2D) = "white" {}
        _NormalMap ("法线贴图", 2D) = "bump" {}
        [LILFoldoutEnd]

        [LILFoldout(Surface Preprocess)]
        _NormalStrength ("法线强度", Range(0.0, 4.0)) = 1.0
        _SphericalNormalBlend ("球形法线混合", Range(0.0, 1.0)) = 0.5

        [Space(8)] _ColorProcessStrength ("颜色处理强度", Range(0.0, 1.0)) = 0.75
        [HDR] _OuterTint ("外层染色", Color) = (1,1,1,1)
        [HDR] _InnerTint ("内部染色", Color) = (0.5,0.5,0.5,1)
        _ThicknessTintStrength ("厚度染色强度", Range(0.0, 1.0)) = 1.0
        [Space(4)] [HDR] _EdgeTint ("边缘染色", Color) = (1,1,1,1)
        _EdgeTintStrength ("边缘染色强度", Range(0.0, 1.0)) = 0.25
        _FresnelTintStrength ("菲涅尔染色强度", Range(0.0, 1.0)) = 0.5
        _FresnelTintPower ("菲涅尔染色范围", Range(0.05, 8.0)) = 1.0
        [LILFoldoutEnd]

        [LILFoldout(Internal Field And Glow)]
        _FieldStrength ("内部场强度", Range(0.0, 4.0)) = 1.0
        _GlowStrength ("辉光强度", Range(0.0, 8.0)) = 1.0
        [NoScaleOffset] _VolumeNoise ("体积噪声 (RG)", 2D) = "gray" {}
        _StepLength ("步进长度", Range(0.0, 4.0)) = 1.0
        _VolumeNoiseScale ("体积噪声缩放", Range(0.001, 4.0)) = 0.25
        _VolumeMainPower ("主噪声指数", Range(0.05, 4.0)) = 0.8
        _VolumeMainMultiply ("主噪声倍增", Range(0.0, 16.0)) = 2.25
        _VolumeSecondaryPower ("次级噪声指数", Range(0.05, 4.0)) = 0.5
        _VolumeSecondaryMultiply ("次级噪声倍增", Range(0.0, 8.0)) = 0.125
        _VolumeSecondaryIntersect ("次级交叠强度", Range(0.0, 4.0)) = 1.0
        _FieldMaskPower ("场遮罩指数", Range(0.05, 4.0)) = 1.25
        _FieldStepFade ("步进衰减", Range(0.0, 2.0)) = 1.0

        [Space(8)] _InternalRayBend ("内部光路弯曲", Range(0.05, 8.0)) = 1.0
        [ToggleUI] _UseSurfaceNoise ("启用表面噪声", Int) = 1
        _SurfaceNoise ("表面噪声", 2D) = "white" {}
        _SurfaceNoiseScale ("表面噪声缩放", Range(0.001, 8.0)) = 1.0
        _SurfaceNoiseStrength ("表面噪声强度", Range(0.0, 1.0)) = 1.0
        _SurfaceNoiseAdd ("表面噪声叠加", Range(0.0, 1.0)) = 0.0
        _SurfaceNoiseParallax ("表面噪声视差", Range(0.0, 32.0)) = 5.0

        [Space(8)] [NoScaleOffset] _GlowRamp ("辉光渐变", 2D) = "white" {}
        [HDR] _GlowTint ("辉光染色", Color) = (1,1,1,1)
        _GlowContrast ("辉光遮罩对比", Range(0.25, 4.0)) = 1.0
        _GlowThicknessWeight ("厚度权重", Range(0.0, 1.0)) = 1.0
        _GlowEdgeWeight ("边缘权重", Range(0.0, 2.0)) = 0.25
        _GlowFresnelWeight ("菲涅尔权重", Range(0.0, 1.0)) = 0.0
        _FresnelPower ("菲涅尔范围", Range(0.05, 8.0)) = 1.0

        [Space(8)] _StyleFadeStrength ("风格方向渐隐强度", Range(0.0, 1.0)) = 0.0
        [LILVector3] _StyleFadeDirection ("风格方向渐隐 XYZ", Vector) = (0,1,0,0)
        _StyleFadeOffset ("风格方向渐隐偏移", Range(-1.0, 1.0)) = 0.0
        _StyleFadeSoftness ("风格方向渐隐柔和度", Range(0.01, 2.0)) = 0.5
        [Enum(World, 0, Local, 1, LocalOneToOne, 2)] _VolumeSpace ("体积空间", Int) = 1
        [LILVector3] _VolumeOffset ("体积偏移 XYZ", Vector) = (0,0,0,0)
        [LILFoldoutEnd]

        [LILFoldout(MatCap)]
        _MatCapTex ("MatCap", 2D) = "black" {}
        [HDR] _MatCapColor ("MatCap 颜色", Color) = (1,1,1,1)
        _MatCapStrength ("MatCap 强度", Range(0.0, 4.0)) = 1.0
        _MatCapFresnel ("MatCap 菲涅尔", Range(0.0, 1.0)) = 0.35
        [Enum(Add, 0, Multiply, 1, Screen, 2)] _MatCapBlendMode ("MatCap 叠加模式", Int) = 0
        [LILFoldoutEnd]

        [LILFoldout(Dynamic Fibers)]
        _FiberStrength ("动态絮状强度", Range(0.0, 1.0)) = 1.0
        [Enum(Fractal, 0, Marble, 1, Veins, 2)] _FiberMode ("动态絮状模式", Int) = 0
        _FiberFlowSpeed ("流动速度", Range(0.0, 4.0)) = 0.0
        _FiberFlowStrength ("流动强度", Range(0.0, 1.0)) = 0.0
        _FiberFlowPhase ("流动相位", Range(0.0, 6.283)) = 0.0
        _FiberScale ("絮状密度", Range(0.5, 6.0)) = 2.25
        _FiberDepth ("絮状深度", Range(0.0, 16.0)) = 12.0
        _FiberBrightness ("絮状亮度", Range(0.0, 4.0)) = 1.25
        _FiberSharpness ("絮状锐度", Range(0.25, 8.0)) = 1.15
        _FiberFresnel ("絮状边缘混合", Range(0.0, 1.0)) = 0.25
        [HDR] _FiberMainColor ("絮状主色", Color) = (1,0.72,0.18,1)
        [HDR] _FiberSecondaryColor ("絮状变化色", Color) = (1,0.16,0.02,1)
        _FiberColorVariation ("絮状颜色变化", Range(0.0, 1.0)) = 0.65
        [LILFoldoutEnd]

        [LILFoldout(Environment)]
        _EnvironmentStrength ("环境强度", Range(0.0, 4.0)) = 1.0
        _SSAOStrength ("SSAO 强度", Range(0.0, 1.0)) = 0.0
        _SSAOTint ("SSAO 染色", Color) = (0.0,0.0,0.0,1)
        [LILFoldoutEnd]

        [LILFoldout(Direct Light And Shadow)]
        _DirectLightStrength ("直接光强度", Range(0.0, 4.0)) = 1.0
        [Space(8)]
        _ShadowStrength ("阴影强度", Range(0.0, 1.0)) = 1.0
        _ShadowCastStrength ("投影强度", Range(0.0, 1.0)) = 1.0
        _ShadowBorder ("阴影边界", Range(0.0, 1.0)) = 0.5
        _ShadowBlur ("阴影模糊", Range(0.0, 2.0)) = 1.0
        _ShadowReceiveOffset ("接收阴影偏移", Range(-0.1, 0.1)) = 0.0
        _ShadowCasterOffset ("投影深度偏移", Range(-0.1, 0.1)) = 0.0
        [NoScaleOffset] _ShadowRamp ("阴影 LUT 渐变", 2D) = "white" {}
        _ShadowRampStrength ("阴影 LUT 强度", Range(0.0, 1.0)) = 0.0
        [LILFoldoutEnd]

        [LILFoldout(Highlight)]
        _HighlightSharpness ("高光锐度", Range(0.0, 1.0)) = 1.0
        _HighlightStrength ("高光强度", Range(0.0, 8.0)) = 1.0
        [HDR] _HighlightColor ("高光颜色", Color) = (1,1,1,1)
        [LILFoldoutEnd]

        [LILFoldout(Reflection)]
        _ReflectionStrength ("反射强度", Range(0.0, 1.0)) = 0.18
        _ReflectionFresnel ("反射菲涅尔", Range(0.05, 4.0)) = 1.0
        _ReflectionRoughness ("反射粗糙度", Range(0.0, 1.0)) = 0.08
        [LILFoldoutEnd]

        [LILFoldout(Advanced)]
        [Enum(Off, 0, Front, 1, Back, 2)] [LILFoldoutEnd] _Cull ("剔除模式", Int) = 2
    }

    HLSLINCLUDE
    #pragma target 4.5
    #pragma multi_compile_instancing
    #pragma instancing_options renderinglayer

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    TEXTURE2D(_VolumeNoise); SAMPLER(sampler_VolumeNoise);
    TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
    TEXTURE2D(_GlowRamp); SAMPLER(sampler_GlowRamp);
    TEXTURE2D(_MaskTex); SAMPLER(sampler_MaskTex);
    TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);
    TEXTURE2D(_SurfaceNoise); SAMPLER(sampler_SurfaceNoise);
    TEXTURE2D(_ShadowRamp); SAMPLER(sampler_ShadowRamp);
    TEXTURE2D(_MatCapTex); SAMPLER(sampler_MatCapTex);

    CBUFFER_START(UnityPerMaterial)
        float4 _BaseColor;
        float4 _MainTex_ST;
        float _Cutoff;
        float4 _MaskTex_ST;
        float4 _NormalMap_ST;
        float _NormalStrength;
        float _SphericalNormalBlend;
        float _ColorProcessStrength;
        float4 _OuterTint;
        float4 _InnerTint;
        float _ThicknessTintStrength;
        float4 _EdgeTint;
        float _EdgeTintStrength;
        float _FresnelTintStrength;
        float _FresnelTintPower;

        float _FieldStrength;
        float _GlowStrength;
        float _StepLength;
        float _VolumeNoiseScale;
        float _VolumeMainPower;
        float _VolumeMainMultiply;
        float _VolumeSecondaryPower;
        float _VolumeSecondaryMultiply;
        float _VolumeSecondaryIntersect;
        float _FieldMaskPower;
        float _FieldStepFade;
        float _InternalRayBend;
        uint _UseSurfaceNoise;
        float4 _SurfaceNoise_ST;
        float _SurfaceNoiseScale;
        float _SurfaceNoiseStrength;
        float _SurfaceNoiseAdd;
        float _SurfaceNoiseParallax;
        float4 _GlowTint;
        float _GlowContrast;
        float _GlowThicknessWeight;
        float _GlowEdgeWeight;
        float _GlowFresnelWeight;
        float _FresnelPower;
        float _StyleFadeStrength;
        float4 _StyleFadeDirection;
        float _StyleFadeOffset;
        float _StyleFadeSoftness;
        float _VolumeSpace;
        float4 _VolumeOffset;

        float4 _MatCapTex_ST;
        float4 _MatCapColor;
        float _MatCapStrength;
        float _MatCapFresnel;
        float _MatCapBlendMode;

        float _FiberStrength;
        float _FiberMode;
        float _FiberFlowSpeed;
        float _FiberFlowStrength;
        float _FiberFlowPhase;
        float _FiberScale;
        float _FiberDepth;
        float _FiberBrightness;
        float _FiberSharpness;
        float _FiberFresnel;
        float4 _FiberMainColor;
        float4 _FiberSecondaryColor;
        float _FiberColorVariation;

        float _EnvironmentStrength;
        float _SSAOStrength;
        float4 _SSAOTint;
        float _DirectLightStrength;
        float _ShadowStrength;
        float _ShadowCastStrength;
        float _ShadowBorder;
        float _ShadowBlur;
        float _ShadowReceiveOffset;
        float _ShadowCasterOffset;
        float _ShadowRampStrength;
        float _HighlightSharpness;
        float _HighlightStrength;
        float4 _HighlightColor;
        float _ReflectionStrength;
        float _ReflectionFresnel;
        float _ReflectionRoughness;
    CBUFFER_END

    #include "crystal_gem_composite_core.hlsl"
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            Blend Off
            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex GemVert
            #pragma fragment GemFragForward
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex GemVertShadowCaster
            #pragma fragment GemFragDepth
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex GemVertDepth
            #pragma fragment GemFragDepth
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }
            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex GemVertDepth
            #pragma fragment GemFragDepthNormals
            ENDHLSL
        }
    }

    Fallback Off
    CustomEditor "jp.lilxyzw.lilpbr.PBRShaderGUI"
}
