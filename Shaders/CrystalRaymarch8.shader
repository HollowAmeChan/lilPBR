Shader "lilPBR/Crystal/Raymarch 8"
{
    Properties
    {
        [LILFoldout(Surface)]
        [LILPropertyCache] _CrystalBaseColor ("基础颜色", Color) = (0.18,0.45,0.95,1)
        _CrystalSmoothness ("光滑度", Range(0.0, 1.0)) = 1.0
        _CrystalMetallic ("金属度", Range(0.0, 1.0)) = 0.0
        _CrystalOcclusion ("环境遮蔽", Range(0.0, 1.0)) = 1.0
        _CrystalNormalMap ("法线贴图", 2D) = "bump" {}
        _CrystalNormalScale ("法线缩放", Range(0.0, 4.0)) = 1.0
        _CrystalNormalStrength ("法线强度", Range(0.0, 2.0)) = 1.0
        _CrystalNormalSpherical ("球形法线混合", Range(0.0, 1.0)) = 0.5
        [LILFoldoutEnd]

        [LILFoldout(Volume Raymarch)]
        [NoScaleOffset] _CrystalVolumeNoise ("体积噪声 (RG)", 2D) = "gray" {}
        _CrystalStepLength ("步进长度", Range(0.0, 4.0)) = 1.0
        _CrystalRefraction ("折射强度", Range(0.05, 8.0)) = 1.0
        _CrystalVolumeNoiseScale ("体积噪声缩放", Range(0.001, 4.0)) = 0.25
        _CrystalVolumeNoiseExp ("主噪声指数", Range(0.05, 4.0)) = 0.8
        _CrystalVolumeNoiseMultiply ("主噪声倍率", Range(0.0, 16.0)) = 2.25
        _CrystalVolumeSecondaryExp ("次级噪声指数", Range(0.05, 4.0)) = 0.5
        _CrystalVolumeSecondaryMultiply ("次级噪声倍率", Range(0.0, 8.0)) = 0.125
        _CrystalVolumeSecondaryIntersect ("次级交叠强度", Range(0.0, 4.0)) = 1.0
        [Enum(World, 0, Local, 1, LocalOneToOne, 2)] _CrystalVolumeSpace ("体积空间", Int) = 1
        [LILVector3] _CrystalVolumeOffset ("体积偏移 XYZ", Vector) = (0,0,0,0)
        [LILFoldoutEnd]

        [LILFoldout(Linear Mask)]
        [LILVector3] _CrystalLinearMaskVector ("线性遮罩方向", Vector) = (0,1,0,0)
        [LILVector3] _CrystalLinearMaskWorldOffset ("线性遮罩世界偏移", Vector) = (0,0,0,0)
        _CrystalLinearMaskScale ("线性遮罩缩放", Float) = 1.0
        _CrystalLinearMaskOffset ("线性遮罩偏移", Float) = 0.0
        _CrystalLinearMaskNegate ("线性遮罩反转", Range(0.0, 1.0)) = 0.0
        [LILFoldoutEnd]

        [LILFoldout(Ramp Emission)]
        [NoScaleOffset] _CrystalRamp ("渐变贴图", 2D) = "white" {}
        [HDR] _CrystalRampTint ("渐变染色", Color) = (1,1,1,1)
        _CrystalRampExp ("渐变指数", Range(0.05, 8.0)) = 2.0
        _CrystalRampMainMaskExp ("渐变主遮罩指数", Range(0.05, 8.0)) = 2.0
        _CrystalRampFresnelExp ("渐变菲涅尔指数", Range(0.05, 8.0)) = 1.0
        _CrystalRampFresnelExp2 ("渐变菲涅尔指数 2", Range(0.05, 8.0)) = 2.0
        _CrystalRampFresnelAdd ("渐变菲涅尔叠加", Range(0.0, 2.0)) = 1.0
        _CrystalRampEmissionPower ("渐变发光强度", Range(0.0, 16.0)) = 4.0
        _CrystalFresnelPower ("菲涅尔强度", Range(0.05, 8.0)) = 1.0
        [LILFoldoutEnd]

        [LILFoldout(Mask And Edges)]
        _CrystalMask ("遮罩 (R 边缘 / G 厚度 / B 边缘)", 2D) = "white" {}
        _CrystalThicknessExp ("厚度指数", Range(0.05, 8.0)) = 1.0
        _CrystalThicknessNegate ("厚度反转", Range(0.0, 1.0)) = 0.75
        _CrystalThicknessNegateFresnel ("厚度反转菲涅尔", Range(0.0, 2.0)) = 0.0
        _CrystalThicknessEmission ("厚度发光", Range(0.0, 4.0)) = 1.0
        _CrystalEdgesEmission ("边缘发光", Range(0.0, 4.0)) = 0.25
        _CrystalEdgesParallax ("边缘视差", Range(0.0, 32.0)) = 16.0
        _CrystalEdgesStyle ("边缘样式", Range(0.0, 1.0)) = 0.0
        [ToggleUI] _CrystalEdgesUseThickness ("改用厚度作为边缘", Int) = 1
        _CrystalEdgesOnlyOnMasked ("边缘仅限遮罩区域", Range(0.0, 1.0)) = 0.0
        [LILFoldoutEnd]

        [LILFoldout(Refraction Noise)]
        [ToggleUI] _CrystalUseRefractionNoise ("启用折射表面噪声", Int) = 1
        _CrystalRefractionNoise ("折射表面噪声", 2D) = "white" {}
        _CrystalRefractionNoiseScale ("折射噪声缩放", Range(0.001, 8.0)) = 1.0
        _CrystalRefractionNoiseStrength ("折射噪声强度", Range(0.0, 1.0)) = 1.0
        _CrystalRefractionNoiseAdd ("折射噪声叠加", Range(0.0, 1.0)) = 0.0
        _CrystalRefractionNoiseParallax ("折射噪声视差", Range(0.0, 32.0)) = 5.0
        [LILFoldoutEnd]

        [LILFoldout(Desaturate)]
        _CrystalDesaturateAmount ("去饱和强度", Range(0.0, 1.0)) = 0.75
        _CrystalDesaturateFresnelExp ("去饱和菲涅尔指数", Range(0.05, 8.0)) = 1.0
        _CrystalDesaturateLighten ("去饱和提亮", Range(0.0, 4.0)) = 0.5
        _CrystalDesaturateThickness ("去饱和厚度影响", Range(0.0, 1.0)) = 1.0
        [LILFoldoutEnd]

        [LILFoldout(Lighting)]
        _CrystalReceiveShadowStrength ("接收阴影强度", Range(0.0, 1.0)) = 1.0
        _CrystalShadowMinLight ("阴影最小亮度", Range(0.0, 1.0)) = 0.0
        _CrystalShadowTint ("阴影染色", Color) = (0.16,0.22,0.36,1)
        _CrystalIndirectStrength ("间接光强度", Range(0.0, 4.0)) = 1.0
        _CrystalSpecularStrength ("高光强度", Range(0.0, 8.0)) = 1.0
        [HDR] _CrystalSpecularColor ("高光颜色", Color) = (1,1,1,1)
        [LILFoldoutEnd]

        [LILFoldout(Advanced)]
        [Enum(Off, 0, Front, 1, Back, 2)] _Cull ("剔除模式", Int) = 2
        [ToggleUI][LILFoldoutEnd] _ZWrite ("写入深度", Int) = 1
    }

    HLSLINCLUDE
    #pragma target 4.5
    #pragma multi_compile_instancing
    #pragma instancing_options renderinglayer

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    TEXTURE2D(_CrystalVolumeNoise); SAMPLER(sampler_CrystalVolumeNoise);
    TEXTURE2D(_CrystalRamp); SAMPLER(sampler_CrystalRamp);
    TEXTURE2D(_CrystalMask); SAMPLER(sampler_CrystalMask);
    TEXTURE2D(_CrystalNormalMap); SAMPLER(sampler_CrystalNormalMap);
    TEXTURE2D(_CrystalRefractionNoise); SAMPLER(sampler_CrystalRefractionNoise);

    CBUFFER_START(UnityPerMaterial)
        float4 _CrystalBaseColor;
        float _CrystalSmoothness;
        float _CrystalMetallic;
        float _CrystalOcclusion;
        float4 _CrystalNormalMap_ST;
        float _CrystalNormalScale;
        float _CrystalNormalStrength;
        float _CrystalNormalSpherical;
        float _CrystalStepLength;
        float _CrystalRefraction;
        float _CrystalVolumeNoiseScale;
        float _CrystalVolumeNoiseExp;
        float _CrystalVolumeNoiseMultiply;
        float _CrystalVolumeSecondaryExp;
        float _CrystalVolumeSecondaryMultiply;
        float _CrystalVolumeSecondaryIntersect;
        float _CrystalVolumeSpace;
        float4 _CrystalVolumeOffset;
        float4 _CrystalLinearMaskVector;
        float4 _CrystalLinearMaskWorldOffset;
        float _CrystalLinearMaskScale;
        float _CrystalLinearMaskOffset;
        float _CrystalLinearMaskNegate;
        float4 _CrystalRampTint;
        float _CrystalRampExp;
        float _CrystalRampMainMaskExp;
        float _CrystalRampFresnelExp;
        float _CrystalRampFresnelExp2;
        float _CrystalRampFresnelAdd;
        float _CrystalRampEmissionPower;
        float _CrystalFresnelPower;
        float4 _CrystalMask_ST;
        float _CrystalThicknessExp;
        float _CrystalThicknessNegate;
        float _CrystalThicknessNegateFresnel;
        float _CrystalThicknessEmission;
        float _CrystalEdgesEmission;
        float _CrystalEdgesParallax;
        float _CrystalEdgesStyle;
        uint _CrystalEdgesUseThickness;
        float _CrystalEdgesOnlyOnMasked;
        uint _CrystalUseRefractionNoise;
        float4 _CrystalRefractionNoise_ST;
        float _CrystalRefractionNoiseScale;
        float _CrystalRefractionNoiseStrength;
        float _CrystalRefractionNoiseAdd;
        float _CrystalRefractionNoiseParallax;
        float _CrystalDesaturateAmount;
        float _CrystalDesaturateFresnelExp;
        float _CrystalDesaturateLighten;
        float _CrystalDesaturateThickness;
        float _CrystalReceiveShadowStrength;
        float _CrystalShadowMinLight;
        float4 _CrystalShadowTint;
        float _CrystalIndirectStrength;
        float _CrystalSpecularStrength;
        float4 _CrystalSpecularColor;
    CBUFFER_END

    #include "crystal_raymarch.hlsl"
    #include "crystal_core.hlsl"
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
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex CrystalVert
            #pragma fragment CrystalFragForward
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
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
            #pragma vertex CrystalVertDepth
            #pragma fragment CrystalFragDepth
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex CrystalVertDepth
            #pragma fragment CrystalFragDepth
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }
            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex CrystalVertDepth
            #pragma fragment CrystalFragDepthNormals
            ENDHLSL
        }
    }

    Fallback Off
    CustomEditor "jp.lilxyzw.lilpbr.PBRShaderGUI"
}
