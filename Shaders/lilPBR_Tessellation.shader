Shader "lilPBR Tessellation"
{
    Properties
    {
        [LILRenderMode] _RenderingMode("Rendering Mode", Int) = 0
        [LILIf(_RenderingMode, 1)] _Cutoff ("Cutoff", Range(0.0, 1.0)) = 0.0
        [Enum(Off, 0, Front, 1, Back, 2)] _Cull ("Cull", Int) = 2
        [ToggleUI] _DitherRandomize ("Dither Randomize", Int) = 1
        [LILShaderLayerOne] _ShaderLayer ("Shader Layer", Int) = 0

        [LILFoldout(Base)]
        [LILPropertyCache] _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo", 2D) = "white" {}
        [Enum(Ignore, 0, Color, 1, Occlusion (A), 2)] _VertexColorMode ("Vertex Color Mode", Int) = 0
        [KeywordEnum(Default, Planar, Triplanar)] _UVMode ("UV Mode", Int) = 0
        [LILKeyword(_RANDOMIZE_UV)][ToggleUI] _RandomizeUV ("UV Randomize", Int) = 0
        [LILKeyword(_ATRASMASK)][NoScaleOffset] _AtrasMask ("Atras Mask", 2D) = "white" {}
        [LILPropertyCache] _BumpScale("Scale", Float) = 1.0
        [LILKeyword(_NORMALMAP)][NoScaleOffset][Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
        [LILBox]
        [LILKeyword(_BACKFACE_COLOR)][ToggleUI] _BackfaceOverride ("Backface Override", Int) = 0
        [LILPropertyCache] _BackfaceColor ("Color", Color) = (1,1,1,1)
        _BackfaceTex ("Albedo", 2D) = "white" {}
        [LILBoxEnd]
        [LILFoldoutEnd]

        [LILFoldout(PBR)]
        [LILKeyword(_TEXTUREMODE_SEPARATE)][Enum(Packed, 0, Separate, 1)] _TextureMode("Texture Mode", Int) = 0

        [LILBox]
        [LILIf(_TextureMode, 0)][NoScaleOffset] _PBRMap ("PBR Map", 2D) = "white" {}

        [LILPropertyCache][Gamma] _Metallic ("Metallic", Range(0.0, 1.0)) = 0.0
        [LILIf(_TextureMode, 1)][NoScaleOffset] _MetallicGlossMap ("Metallic", 2D) = "white" {}
        [LILIf(_TextureMode, 0)][Enum(R, 0, G, 1, B, 2, A, 3)] _MetallicChannel ("Metallic", Int) = 0

        [LILPropertyCache] _OcclusionStrength ("Occlusion", Range(0.0, 1.0)) = 1.0
        [LILIf(_TextureMode, 1)][NoScaleOffset] _OcclusionMap ("Occlusion", 2D) = "white" {}
        [LILIf(_TextureMode, 0)][Enum(R, 0, G, 1, B, 2, A, 3)] _OcclusionChannel ("Occlusion", Int) = 1

        [LILPropertyCache][LILKeyword(_PARALLAX)] _Parallax ("Height", Range (0, 1.0)) = 0.0
        [LILIf(_TextureMode, 1)][NoScaleOffset] _ParallaxMap ("Height", 2D) = "black" {}
        [LILIf(_TextureMode, 0)][Enum(R, 0, G, 1, B, 2, A, 3)] _HeightChannel ("Height", Int) = 2

        [LILPropertyCache] _Glossiness ("Smoothness", Range(0.0, 1.0)) = 0.5
        [LILIf(_TextureMode, 1)][NoScaleOffset] _SmoothnessMap ("Smoothness", 2D) = "white" {}
        [LILIf(_TextureMode, 0)][Enum(R, 0, G, 1, B, 2, A, 3)] _SmoothnessChannel ("Smoothness", Int) = 3
        [ToggleUI] _InvertSmoothness ("Invert Smoothness", Int) = 0
        [LILBoxEnd]
        [LILPropertyCacheClear]

        [KeywordEnum(None, Vertex, Pixel)] _ParallaxMode ("Displacement Mode", Int) = 0
        [LILIf(_ParallaxMode, 2)][IntRange] _ParallaxQuality ("Displacement Quality", Range(1,32)) = 16
        [LILIf(_ParallaxMode, 2)] _ParallaxRandomize ("Displacement Randomize", Range(0,1)) = 1
        [LILFoldoutEnd]

        [LILFoldout(Specular)]
        _Reflectance ("Reflectance", Range(0.0, 1.0)) = 0.04
        _SpecularStrength ("Strength", Range(0.0, 4.0)) = 1.0
        _GSAAStrength ("GSAA", Range(0.0, 1.0)) = 0.5
        [Enum(Probe And Skybox, 0, Skybox Only, 1, Off, 2)] _EnvironmentReflectionMode ("Environment Reflection Mode", Int) = 0
        _SpecularHighlightStrength ("Highlight Strength", Range(0.0, 16.0)) = 0.0
        _SpecularHighlightSmoothness ("Highlight Smoothness", Range(0.0, 1.0)) = 0.96
        _SpecularHighlightReflectance ("Highlight Reflectance", Range(0.0, 1.0)) = 0.35
        [HDR] _SpecularHighlightColor ("Highlight Color", Color) = (1,1,1,1)
        [LILFoldoutEnd]

        [LILFoldout(Screen Space AO)]
        [ToggleUI] _UseScreenSpaceAO ("Screen Space AO", Int) = 1
        [Enum(ScreenSpaceOcclusionTexture, 0, HTraceBufferAO, 1)] _ScreenSpaceAOSource ("AO RT", Int) = 0
        _SSAOStrength ("AO Strength", Range(0.0, 1.0)) = 1.0
        _SSAODirectStrength ("Direct AO Strength", Range(0.0, 1.0)) = 1.0
        _SSAOIndirectStrength ("Indirect AO Strength", Range(0.0, 1.0)) = 0.5
        [LILVector2] _SSAORemap ("AO Remap Min Max", Vector) = (0,1,0,0)
        _SSAOContrast ("AO Contrast", Range(0.0, 4.0)) = 1.0
        [NoScaleOffset] _SSAOMask ("AO Mask", 2D) = "white" {}
        [LILFoldoutEnd]

        [LILFoldout(HoAOV)]
        [HideInInspector] _HoAovMaskWeight ("HoAOV Mask Weight", Range(0, 1)) = 1
        [HideInInspector] _HoAovSystemWriteMask ("HoAOV System Write Mask", Float) = 3935
        [HideInInspector] _HoAovCustomWriteMask ("HoAOV Custom Write Mask", Float) = 0
        [HideInInspector] _HoAovCustomValues0 ("HoAOV Custom 0-3", Vector) = (0,0,0,0)
        [HideInInspector] _HoAovGroupId ("HoAOV Group ID", Float) = 0
        [HideInInspector] _HoAovObjectId ("HoAOV Object ID", Float) = 0
        [HideInInspector] _HoAovMaterialClass ("HoAOV Material Class", Float) = 0
        [HideInInspector] _HoAovFlags ("HoAOV Flags", Float) = 0
        [HideInInspector] _HoAovThickness ("HoAOV Thickness", Range(0, 1)) = 0
        [HideInInspector] _HoAovCurvature ("HoAOV Curvature", Range(-1, 1)) = 0
        [HideInInspector] _HoAovUtility ("HoAOV Utility", Range(0, 1)) = 0
        [HideInInspector] _HoAovObjectCustomMask ("HoAOV Object Custom Mask", Float) = 0
        [LILPropertyCache] _HoAovCustom0Color ("Custom 0", Color) = (0,0,0,0)
        [NoScaleOffset] _HoAovCustom0Tex ("Custom 0", 2D) = "white" {}
        [LILPropertyCacheClear]
        [LILPropertyCache] _HoAovCustom1Color ("Custom 1", Color) = (0,0,0,0)
        [NoScaleOffset] _HoAovCustom1Tex ("Custom 1", 2D) = "white" {}
        [LILPropertyCacheClear]
        [LILPropertyCache] _HoAovCustom2Color ("Custom 2", Color) = (0,0,0,0)
        [NoScaleOffset] _HoAovCustom2Tex ("Custom 2", 2D) = "white" {}
        [LILPropertyCacheClear]
        [LILPropertyCache] _HoAovCustom3Color ("Custom 3", Color) = (0,0,0,0)
        [NoScaleOffset] _HoAovCustom3Tex ("Custom 3", 2D) = "white" {}
        [LILPropertyCacheClear]
        _HoCharacterCaptureOpacity ("Character Capture Opacity", Range(0, 1)) = 1
        [LILFoldoutEnd]

        [LILFoldout(Screen Space Reflection)]
        [ToggleUI] _UseScreenSpaceReflection ("Screen Space Reflection", Int) = 0
        _SSRStrength ("SSR Strength", Range(0.0, 1.0)) = 1.0
        _SSRMaxDistance ("Max Distance", Range(0.1, 50.0)) = 10.0
        _SSRThickness ("Thickness", Range(0.001, 1.0)) = 0.15
        [IntRange] _SSRStepCount ("Steps", Range(4, 64)) = 32
        _SSRMinSmoothness ("Min Smoothness", Range(0.0, 1.0)) = 0.75
        _SSREdgeFade ("Edge Fade", Range(0.0, 32.0)) = 8.0
        [LILFoldoutEnd]

        [LILFoldout(Planar Reflection)]
        [ToggleUI] _UsePlanarReflection ("Planar Reflection", Int) = 0
        _PlanarReflectionStrength ("Strength", Range(0.0, 1.0)) = 1.0
        _PlanarReflectionMinSmoothness ("Min Smoothness", Range(0.0, 1.0)) = 0.75
        _PlanarReflectionEdgeFade ("Edge Fade", Range(0.0, 32.0)) = 0.0
        _PlanarReflectionFadeStart ("Fade Start", Float) = 0.0
        _PlanarReflectionFadeEnd ("Fade End", Float) = 0.0
        _PlanarReflectionTint ("Tint", Color) = (1,1,1,1)
        [ToggleUI] _PlanarReflectionFlipY ("Flip Y", Int) = 0
        [HideInInspector][NoScaleOffset] _LILPBRPlanarReflectionTexture ("Planar Reflection Texture", 2D) = "black" {}
        [LILFoldoutEnd]

        [LILFoldout(Emission)]
        [LILKeyword(_EMISSION)][LILPropertyCache][LILHDR] _EmissionColor ("Emission", Color) = (0,0,0)
        [NoScaleOffset] _EmissionMap ("Emission", 2D) = "white" {}
        [LILKeyword(_EMISSION_SUBPIXEL)] _EmissionSubpixel ("Subpixel Pattern", 2D) = "white" {}
        [LILFoldoutEnd]

        [LILFoldout(Anisotropy)]
        [LILKeyword(_ANISOTROPY)][NoScaleOffset] _AnisotropyDirection ("Anisotropy", 2D) = "bump" {}
        [LILPropertyCache] _Anisotropy ("Strength", Range(-1.0, 1.0)) = 1
        [NoScaleOffset] _AnisotropyMask ("Strength", 2D) = "white" {}
        [Enum(R, 0, G, 1, B, 2, A, 3)] _AnisotropyChannel ("Channel", Int) = 0
        [LILFoldoutEnd]

        [LILFoldout(Clear Coat)]
        [LILBox]
        [NoScaleOffset] _ClearCoatMask ("Clear Coat Map", 2D) = "white" {}
        [LILKeyword(_CLEARCOAT)][LILPropertyCache] _ClearCoat ("Smoothness", Range(0.0, 1.0)) = 0.0
        [Enum(R, 0, G, 1, B, 2, A, 3)] _ClearCoatChannel ("Clear Coat", Int) = 0
        [LILPropertyCache] _ClearCoatSmoothness ("Smoothness", Range(0.0, 1.0)) = 1.0
        [Enum(R, 0, G, 1, B, 2, A, 3)] _ClearCoatSmoothnessChannel ("Smoothness", Int) = 3
        [LILBoxEnd]
        _ClearCoatReflectance ("Reflectance", Range(0.0, 1.0)) = 0.04
        [LILPropertyCache] _ClearCoatBumpScale ("Scale", Float) = 1.0
        [LILKeyword(_CLEARCOAT_NORMALMAP)][NoScaleOffset][Normal] _ClearCoatBumpMap ("Normal Map", 2D) = "bump" {}
        _ClearCoatBaseBumpScale ("Base Normal Map", Range(0.0, 1.0)) = 0.0
        [LILFoldoutEnd]

        [LILFoldout(Cloth)]
        [LILKeyword(_CLOTH)][LILPropertyCache] _Cloth ("Strength", Range(0.0, 1.0)) = 0.0
        _ClothColor ("Color", Color) = (1,1,1,1)
        _ClothAlbedoBlend ("Albedo Blend", Range(0.0, 1.0)) = 0.0
        _ClothFuzz ("Fuzz", Range(0.0, 1.0)) = 0.5
        _ClothDark ("Dark", Range(0.0, 1.0)) = 0.9
        [LILFoldoutEnd]

        [LILFoldout(Fake Translucent)]
        [LILKeyword(_TRANSLUCENT)] _Translucent ("Translucent", Range(0.0, 1.0)) = 0.0
        _TranslucentColor ("Color", Color) = (1,1,1,1)
        _TranslucentAlbedoBlend ("Albedo Blend", Range(0.0, 1.0)) = 1.0
        _TranslucentRoughness ("Roughness", Range(0.0, 1.0)) = 1.0
        _TranslucentRoughnessBlend ("Roughness Blend", Range(0.0, 1.0)) = 1.0
        [LILFoldoutEnd]

        [LILFoldout(Subsurface Scattering)]
        [LILKeyword(_SUBSURFACE)][LILPropertyCache] _SubsurfaceScattering ("Strength", Range(0.0, 1.0)) = 0.0
        [NoScaleOffset] _SubsurfaceMap ("Strength", 2D) = "white" {}
        [Enum(R, 0, G, 1, B, 2, A, 3)] _SubsurfaceChannel ("Channel", Int) = 0
        [ToggleUI] _SubsurfaceInvert ("Invert Strength", Int) = 0
        _SubsurfacePower ("Power", Range(0.1, 8.0)) = 1.0
        _SubsurfaceThickness ("Thickness", Range(0.0, 1.0)) = 1.0
        _SubsurfaceRim ("Rim", Range(0.0, 1.0)) = 1.0
        [ToggleUI] _SubsurfaceReceiveShadow ("Receive Shadow", Int) = 1
        _SubsurfaceDirectStrength ("Direct Strength", Range(0.0, 4.0)) = 1.0
        _SubsurfaceEnvironmentStrength ("Environment Strength", Range(0.0, 4.0)) = 1.0
        _SubsurfaceWrap ("Wrap", Range(0.0, 1.0)) = 0.0
        _SubsurfaceColor ("Color", Color) = (1,1,1,1)
        _SubsurfaceAlbedoBlend ("Albedo Blend", Range(0.0, 1.0)) = 1.0
        _SubsurfaceAbsorptionColor ("Absorption Color", Color) = (1,1,1,1)
        _SubsurfaceAbsorptionStrength ("Absorption Strength", Range(0.0, 8.0)) = 0.0
        [LILFoldoutEnd]

        [LILFoldout(Screening)]
        [KeywordEnum(None, AM)] _ScreeningMode ("Screening Mode", Int) = 0
        _ScreeningScaleX ("Scale X", Float) = 1024
        _ScreeningScaleY ("Scale Y", Float) = 1024
        _ScreeningNoiseStrength ("Noise", Range(0,0.2)) = 0.1
        [LILFoldoutEnd]

        [LILFoldout(Details)]
        [NoScaleOffset] _DetailMask ("Detail Mask (RGBA)", 2D) = "white" {}

        [LILFoldout(Detail 1, _DETAIL1)]
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)] _DetailUVMode1 ("UV Mode", Int) = 0
        [LILPropertyCache] [Enum(Normal, 0, Add, 1, Screen, 2, Multiply, 3)] _DetailAlbedoBlend1 ("Albedo", Int) = 3
        _DetailTex1 ("Albedo", 2D) = "white" {}
        [LILPropertyCache] _DetailBumpScale1("Scale", Float) = 1.0
        [NoScaleOffset][Normal] _DetailBumpMap1 ("Normal Map", 2D) = "bump" {}
        [Enum(Add, 0, Override, 1)] _DetailBumpMapBlend1 ("Normal Map Blend", Int) = 0
        [LILVector3] _DetailProjection1 ("Projection", Vector) = (0,0,0,0)
        _DetailProjectionSharpness1 ("Projection Sharpness", Range(1,20)) = 10
        _DetailProjectionThreshold1 ("Projection Threshold", Range(-1,1)) = 0.6
        [LILFoldoutEnd]

        [LILFoldout(Detail 2, _DETAIL2)]
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)] _DetailUVMode2 ("UV Mode", Int) = 0
        [LILPropertyCache] [Enum(Normal, 0, Add, 1, Screen, 2, Multiply, 3)] _DetailAlbedoBlend2 ("Albedo", Int) = 3
        _DetailTex2 ("Albedo", 2D) = "white" {}
        [LILPropertyCache] _DetailBumpScale2("Scale", Float) = 1.0
        [NoScaleOffset][Normal] _DetailBumpMap2 ("Normal Map", 2D) = "bump" {}
        [Enum(Add, 0, Override, 1)] _DetailBumpMapBlend2 ("Normal Map Blend", Int) = 0
        [LILVector3] _DetailProjection2 ("Projection", Vector) = (0,0,0,0)
        _DetailProjectionSharpness2 ("Projection Sharpness", Range(1,20)) = 10
        _DetailProjectionThreshold2 ("Projection Threshold", Range(-1,1)) = 0.6
        [LILFoldoutEnd]

        [LILFoldout(Detail 3, _DETAIL3)]
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)] _DetailUVMode3 ("UV Mode", Int) = 0
        [LILPropertyCache] [Enum(Normal, 0, Add, 1, Screen, 2, Multiply, 3)] _DetailAlbedoBlend3 ("Albedo", Int) = 3
        _DetailTex3 ("Albedo", 2D) = "white" {}
        [LILPropertyCache] _DetailBumpScale3("Scale", Float) = 1.0
        [NoScaleOffset][Normal] _DetailBumpMap3 ("Normal Map", 2D) = "bump" {}
        [Enum(Add, 0, Override, 1)] _DetailBumpMapBlend3 ("Normal Map Blend", Int) = 0
        [LILVector3] _DetailProjection3 ("Projection", Vector) = (0,0,0,0)
        _DetailProjectionSharpness3 ("Projection Sharpness", Range(1,20)) = 10
        _DetailProjectionThreshold3 ("Projection Threshold", Range(-1,1)) = 0.6
        [LILFoldoutEnd]

        [LILFoldout(Detail 4, _DETAIL4)]
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)] _DetailUVMode4 ("UV Mode", Int) = 0
        [LILPropertyCache] [Enum(Normal, 0, Add, 1, Screen, 2, Multiply, 3)] _DetailAlbedoBlend4 ("Albedo", Int) = 3
        _DetailTex4 ("Albedo", 2D) = "white" {}
        [LILPropertyCache] _DetailBumpScale4("Scale", Float) = 1.0
        [NoScaleOffset][Normal] _DetailBumpMap4 ("Normal Map", 2D) = "bump" {}
        [Enum(Add, 0, Override, 1)] _DetailBumpMapBlend4 ("Normal Map Blend", Int) = 0
        [LILVector3] _DetailProjection4 ("Projection", Vector) = (0,0,0,0)
        _DetailProjectionSharpness4 ("Projection Sharpness", Range(1,20)) = 10
        _DetailProjectionThreshold4 ("Projection Threshold", Range(-1,1)) = 0.6
        [LILFoldoutEnd]
        [LILFoldoutEnd]

        [LILFoldout(Wetness)]
        [KeywordEnum(None, Wetness, Rain)] _WetnessMode ("Wetness Mode", Int) = 0
        [LILPropertyCache] [Enum(R, 0, G, 1, B, 2, A, 3)] _WetnessChannel ("Channel", Int) = 0
        [NoScaleOffset] _WetnessMask ("Mask", 2D) = "white" {}
        [LILPropertyCache] _WetnessBumpScale("Scale", Float) = 1.0
        [Normal] _WetnessBumpMap ("Normal Map", 2D) = "bump" {}
        _WetnessBumpScroll("Normal Scroll", Range(0,10)) = 1.0
        _WetnessDepth ("Depth", Range(0,2)) = 1.0
        _WetnessColor ("Color", Color) = (0.13, 0.34, 0.5, 1)
        [LILBox]
        _RainScale ("Rain Scale", Float) = 1
        _RainSpeed ("Rain Speed", Range(0,2)) = 1
        [IntRange] _RainLoop ("Rain Loop", Range(0,32)) = 8
        [LILBoxEnd]
        [LILFoldoutEnd]

        [LILFoldout(Tessellation)]
        _TessEdge ("Edge", Range(1,100)) = 30
        [IntRange] _TessFactorMax ("Maximum Division", Range(1,9)) = 5
        _TessShrink ("Shrink", Range(0,1)) = 0
        _TessStrength ("Smoothing", Range(0,1)) = 0.5
        [LILFoldoutEnd]

        [LILFoldout(Wind)]
        [KeywordEnum(None, Cloth, Tree, POM)] _WindMode ("Wind Mode", Int) = 0
        [LILVector3] _WindDirection ("Direction", Vector) = (0.5,0,1,0)
        [LILIf(_WindMode, 1)][Enum(Vertex Color (R), 0, Vertex Color (G), 1, Vertex Color (B), 2, Vertex Color (A), 3, UV1 X, 4, UV1 Y, 5)] _WindClothMode ("Mask Mode", Int) = 0
        [LILIf(_WindMode, 2)][Enum(Vertex Color, 0, Unity Tree, 1)] _WindTreeMode ("Mask Mode", Int) = 0
        [LILIf(_WindMode, 2)] _WindBranchSoftness ("Branch Softness", Range(0,1)) = 0.25
        [LILIf(_WindMode, 2)] _WindLeafSoftness ("Leaf Softness", Range(0,1)) = 0.25
        [LILFoldoutEnd]

        [LILFoldout(Distance Fade)]
        _DistanceFade ("Strength", Range(0,1)) = 0.0
        _DistanceFadeStart ("Start Distance", Float) = 0.1
        _DistanceFadeEnd ("End Distance", Float) = 0.01
        [LILFoldoutEnd]

        [LILFoldout(VRChat)]
        [ToggleUI] _HideInDesktop ("Hide In Desktop", Int) = 0
        [ToggleUI] _HideInVR ("Hide In VR", Int) = 0
        [ToggleUI] _HideInCamera ("Hide In Camera", Int) = 0
        [ToggleUI] _HideInScreenshot ("Hide In Screenshot", Int) = 0
        [ToggleUI] _HideInMirror ("Hide In Mirror", Int) = 0
        [ToggleUI] _HideInNotMirror ("Hide In Not Mirror", Int) = 0
        [LILFoldoutEnd]

        [LILFoldout(Advanced)]
        [ToggleUI] _ZWrite ("ZWrite", Int) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("SrcBlend", Int) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("DstBlend", Int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendAlpha ("SrcBlend", Int) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlendAlpha ("DstBlend", Int) = 0
        [ToggleUI] _AlphaToMask ("AlphaToMask", Int) = 0
        [NoScaleOffset] _DitherTex ("Dither (R)", 2D) = "black" {}
        [NoScaleOffset] _TransparencyLM ("Transmissive Texture", 2D) = "white" {}

        [LILBox]
        [IntRange]                                      _StencilRef         ("Ref", Range(0, 255)) = 0
        [IntRange]                                      _StencilReadMask    ("ReadMask", Range(0, 255)) = 255
        [IntRange]                                      _StencilWriteMask   ("WriteMask", Range(0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)]   _StencilComp        ("Comp", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)]         _StencilPass        ("Pass", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)]         _StencilFail        ("Fail", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)]         _StencilZFail       ("ZFail", Float) = 0
        [LILBoxEnd]

        [HideInInspector]_LTCGI("",Int) = 0
    }

    HLSLINCLUDE
    #pragma target 5.0
    #pragma vertex vertTess
    #pragma fragment frag
    #pragma hull hull
    #pragma domain domain
    #pragma require tesshw tessellation
    #include "settings.hlsl"

    bool IsGamma()
    {
        #ifdef UNITY_COLORSPACE_GAMMA
            return true;
        #else
            return false;
        #endif
    }
    #include "pbr.hlsl"
    #include "pbr_properties.hlsl"
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
            "DisableBatching" = "True"
        }

        Stencil
        {
            Ref [_StencilRef]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
            Comp [_StencilComp]
            Pass [_StencilPass]
            Fail [_StencilFail]
            ZFail [_StencilZFail]
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            Blend [_SrcBlend] [_DstBlend], [_SrcBlendAlpha] [_DstBlendAlpha]
            ZWrite [_ZWrite]
            Cull [_Cull]
            AlphaToMask [_AlphaToMask]

            HLSLPROGRAM
            #pragma target 5.0

            #pragma shader_feature_local _UVMODE_DEFAULT _UVMODE_PLANAR _UVMODE_TRIPLANAR
            #pragma shader_feature_local _ATRASMASK
            #pragma shader_feature_local_fragment _ _CUTOUT _DITHER _TRANSPARENT
            #pragma shader_feature_local _RANDOMIZE_UV
            #pragma shader_feature_local _TEXTUREMODE_SEPARATE
            #pragma shader_feature_local_vertex _PARALLAXMODE_VERTEX
            #pragma shader_feature_local_fragment _PARALLAXMODE_PIXEL
            #pragma shader_feature_local_fragment _NORMALMAP
            #pragma shader_feature_local_fragment _BACKFACE_COLOR
            #pragma shader_feature_local_fragment _ANISOTROPY
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _EMISSION_SUBPIXEL
            #pragma shader_feature_local_fragment _CLEARCOAT
            #pragma shader_feature_local_fragment _CLEARCOAT_NORMALMAP
            #pragma shader_feature_local_fragment _CLOTH
            #pragma shader_feature_local_fragment _TRANSLUCENT
            #pragma shader_feature_local_fragment _SUBSURFACE
            #pragma shader_feature_local_fragment _SCREENINGMODE_NONE _SCREENINGMODE_AM
            #pragma shader_feature_local_fragment _DETAIL1
            #pragma shader_feature_local_fragment _DETAIL2
            #pragma shader_feature_local_fragment _DETAIL3
            #pragma shader_feature_local_fragment _DETAIL4
            #pragma shader_feature_local_fragment _WETNESSMODE_NONE _WETNESSMODE_WETNESS _WETNESSMODE_RAIN
            #pragma shader_feature_local_vertex _WINDMODE_NONE _WINDMODE_CLOTH _WINDMODE_TREE
            #pragma shader_feature_local_fragment _WINDMODE_POM

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"


            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fragment _ LIGHTMAP_BICUBIC_SAMPLING
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ USE_LEGACY_LIGHTMAPS
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Fog.hlsl"
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
            struct v2f
            {
                POS_INTERPOLATION float4 pos : SV_POSITION;
                float4 uv01 : TEXCOORD0;
                float4 uv23 : TEXCOORD1;
                float4 normal : TEXCOORD2;
                float4 tangent : TEXCOORD3;
                float4 binormal : TEXCOORD4;
                float4 color : TEXCOORD5;
                float3 V : TEXCOORD6;
                float fogFactor : TEXCOORD7;
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    float4 shadowCoord : TEXCOORD8;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            #define SHADERPASS SHADERPASS_FORWARD
            #include "unity_urp.hlsl"
            #include "pbr_core.hlsl"

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                DoVertex(v, o.pos, o.uv01, o.uv23, o.normal, o.tangent, o.binormal, o.color, o.V);
                VertexPositionInputs vertexInput = GetVertexPositionInputs(float3(o.normal.w, o.tangent.w, o.binormal.w), o.pos);
                #if !defined(_FOG_FRAGMENT)
                    o.fogFactor = ComputeFogFactor(o.pos.z);
                #endif
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    o.shadowCoord = GetShadowCoord(vertexInput);
                #endif
                return o;
            }

            void frag (v2f i, bool isFront : SV_IsFrontFace DEPTH_OUT, out half4 outColor : SV_Target0
            #ifdef _WRITE_RENDERING_LAYERS
                , out uint outRenderingLayers : SV_Target1
            #endif
            )
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                #ifdef LOD_FADE_CROSSFADE
                LODFadeCrossFade(i.pos);
                #endif

                outColor = UnpackAndShading(i, i.normal, i.tangent, i.binormal, i.color, i.V, i.uv01, i.uv23, isFront, depth);
                #ifdef _WRITE_RENDERING_LAYERS
                outRenderingLayers = EncodeMeshRenderingLayer();
                #endif
            }

            #include "tessellation.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "GBuffer"
            Tags { "LightMode" = "UniversalGBuffer" }
            ZWrite [_ZWrite]
            Cull [_Cull]
            AlphaToMask [_AlphaToMask]

            HLSLPROGRAM
            #pragma target 5.0

            #pragma shader_feature_local _UVMODE_DEFAULT _UVMODE_PLANAR _UVMODE_TRIPLANAR
            #pragma shader_feature_local _ATRASMASK
            #pragma shader_feature_local_fragment _ _CUTOUT _DITHER _TRANSPARENT
            #pragma shader_feature_local _RANDOMIZE_UV
            #pragma shader_feature_local _TEXTUREMODE_SEPARATE
            #pragma shader_feature_local_vertex _PARALLAXMODE_VERTEX
            #pragma shader_feature_local_fragment _PARALLAXMODE_PIXEL
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _EMISSION_SUBPIXEL
            #pragma shader_feature_local_fragment _TRANSLUCENT
            #pragma shader_feature_local_vertex _WINDMODE_NONE _WINDMODE_CLOTH _WINDMODE_TREE
            #pragma shader_feature_local_fragment _WINDMODE_POM

            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GBufferOutput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            struct v2f
            {
                POS_INTERPOLATION float4 pos : SV_POSITION;
                float4 uv01 : TEXCOORD0;
                float4 uv23 : TEXCOORD1;
                float4 normal : TEXCOORD2;
                float4 tangent : TEXCOORD3;
                float4 binormal : TEXCOORD4;
                float4 color : TEXCOORD5;
                float3 V : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            #define SHADERPASS SHADERPASS_GBUFFER
            #include "unity_urp.hlsl"
            #include "pbr_core.hlsl"

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                DoVertex(v, o.pos, o.uv01, o.uv23, o.normal, o.tangent, o.binormal, o.color, o.V);
                return o;
            }

            GBufferFragOutput frag (v2f i, bool isFront : SV_IsFrontFace DEPTH_OUT)
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                #ifdef LOD_FADE_CROSSFADE
                LODFadeCrossFade(i.pos);
                #endif

                #ifdef _TRANSPARENT
                clip(-1.0);
                #endif

                UnpackAndShadingAlpha(i, i.normal, i.tangent, i.binormal, i.color, i.V, i.uv01, i.uv23, isFront, depth);

                float2 uv[4];
                uv[0] = i.uv01.xy;
                uv[1] = i.uv01.zw;
                uv[2] = i.uv23.xy;
                uv[3] = i.uv23.zw;
                ShadingParams p = ShadingMeta(i, i.pos, uv);

                InputData inputData = (InputData)0;
                inputData.positionWS = float3(i.normal.w, i.tangent.w, i.binormal.w);
                inputData.positionCS = i.pos;
                inputData.normalWS = NormalizeNormalPerPixel(i.normal.xyz);
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(inputData.positionWS);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.pos);
                inputData.bakedGI = SampleSH(inputData.normalWS);
                inputData.shadowMask = 1.0;

                SurfaceData surfaceData = GetSurfaceData(p, i);
                BRDFData brdfData;
                InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);
                half3 color = GlobalIllumination(brdfData, (BRDFData)0, 0,
                                                  inputData.bakedGI, surfaceData.occlusion, inputData.positionWS,
                                                  inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);
                return PackGBuffersBRDFData(brdfData, inputData, surfaceData.smoothness, surfaceData.emission + color, surfaceData.occlusion);
            }
            #include "tessellation.hlsl"
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
            #pragma target 5.0

            #pragma shader_feature_local _UVMODE_DEFAULT _UVMODE_PLANAR _UVMODE_TRIPLANAR
            #pragma shader_feature_local _ATRASMASK
            #pragma shader_feature_local_fragment _ _CUTOUT _DITHER _TRANSPARENT
            #pragma shader_feature_local _RANDOMIZE_UV
            #pragma shader_feature_local _TEXTUREMODE_SEPARATE
            #pragma shader_feature_local_vertex _PARALLAXMODE_VERTEX
            #pragma shader_feature_local_fragment _PARALLAXMODE_PIXEL
            #pragma shader_feature_local_fragment _TRANSLUCENT
            #pragma shader_feature_local_vertex _WINDMODE_NONE _WINDMODE_CLOTH _WINDMODE_TREE
            #pragma shader_feature_local_fragment _WINDMODE_POM

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            struct v2f
            {
                POS_INTERPOLATION float4 pos : SV_POSITION;
                float4 uv01 : TEXCOORD0;
                float4 uv23 : TEXCOORD1;
                float4 normal : TEXCOORD2;
                float4 tangent : TEXCOORD3;
                float4 binormal : TEXCOORD4;
                float4 color : TEXCOORD5;
                float3 V : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            #define SHADERPASS SHADERPASS_SHADOWCASTER
            #include "unity_urp.hlsl"
            #include "pbr_core.hlsl"

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                DoVertex(v, o.pos, o.uv01, o.uv23, o.normal, o.tangent, o.binormal, o.color, o.V);
                VertexPositionInputs vertexInput = GetVertexPositionInputs(float3(o.normal.w, o.tangent.w, o.binormal.w), o.pos);
                Attributes input = (Attributes)0;
                input.positionOS = v.vertex;
                input.normalOS = v.normal;
                input.texcoord = v.uv0;
                o.pos = GetShadowPositionHClip(input);
                return o;
            }

            half4 frag (v2f i, bool isFront : SV_IsFrontFace DEPTH_OUT) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                #ifdef LOD_FADE_CROSSFADE
                LODFadeCrossFade(i.pos);
                #endif
                UnpackAndShadingAlpha(i, i.normal, i.tangent, i.binormal, i.color, i.V, i.uv01, i.uv23, isFront, depth);
                return 0;
            }

            #include "tessellation.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask R
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 5.0

            #pragma shader_feature_local _UVMODE_DEFAULT _UVMODE_PLANAR _UVMODE_TRIPLANAR
            #pragma shader_feature_local _ATRASMASK
            #pragma shader_feature_local_fragment _ _CUTOUT _DITHER _TRANSPARENT
            #pragma shader_feature_local _RANDOMIZE_UV
            #pragma shader_feature_local _TEXTUREMODE_SEPARATE
            #pragma shader_feature_local_vertex _PARALLAXMODE_VERTEX
            #pragma shader_feature_local_fragment _PARALLAXMODE_PIXEL
            #pragma shader_feature_local_fragment _TRANSLUCENT
            #pragma shader_feature_local_vertex _WINDMODE_NONE _WINDMODE_CLOTH _WINDMODE_TREE
            #pragma shader_feature_local_fragment _WINDMODE_POM

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            struct v2f
            {
                POS_INTERPOLATION float4 pos : SV_POSITION;
                float4 uv01 : TEXCOORD0;
                float4 uv23 : TEXCOORD1;
                float4 normal : TEXCOORD2;
                float4 tangent : TEXCOORD3;
                float4 binormal : TEXCOORD4;
                float4 color : TEXCOORD5;
                float3 V : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            #define SHADERPASS SHADERPASS_DEPTHONLY
            #include "unity_urp.hlsl"
            #include "pbr_core.hlsl"

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                DoVertex(v, o.pos, o.uv01, o.uv23, o.normal, o.tangent, o.binormal, o.color, o.V);
                return o;
            }

            half4 frag (v2f i, bool isFront : SV_IsFrontFace DEPTH_OUT) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                #ifdef LOD_FADE_CROSSFADE
                LODFadeCrossFade(i.pos);
                #endif
                UnpackAndShadingAlpha(i, i.normal, i.tangent, i.binormal, i.color, i.V, i.uv01, i.uv23, isFront, depth);
                return i.pos.z;
            }

            #include "tessellation.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }
            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 5.0

            #pragma shader_feature_local _UVMODE_DEFAULT _UVMODE_PLANAR _UVMODE_TRIPLANAR
            #pragma shader_feature_local _ATRASMASK
            #pragma shader_feature_local_fragment _ _CUTOUT _DITHER _TRANSPARENT
            #pragma shader_feature_local _RANDOMIZE_UV
            #pragma shader_feature_local _TEXTUREMODE_SEPARATE
            #pragma shader_feature_local_vertex _PARALLAXMODE_VERTEX
            #pragma shader_feature_local_fragment _PARALLAXMODE_PIXEL
            #pragma shader_feature_local_fragment _TRANSLUCENT
            #pragma shader_feature_local_vertex _WINDMODE_NONE _WINDMODE_CLOTH _WINDMODE_TREE
            #pragma shader_feature_local_fragment _WINDMODE_POM

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // -------------------------------------
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            struct v2f
            {
                POS_INTERPOLATION float4 pos : SV_POSITION;
                float4 uv01 : TEXCOORD0;
                float4 uv23 : TEXCOORD1;
                float4 normal : TEXCOORD2;
                float4 tangent : TEXCOORD3;
                float4 binormal : TEXCOORD4;
                float4 color : TEXCOORD5;
                float3 V : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            #define SHADERPASS SHADERPASS_DEPTHNORMALSONLY
            #include "unity_urp.hlsl"
            #include "pbr_core.hlsl"

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                DoVertex(v, o.pos, o.uv01, o.uv23, o.normal, o.tangent, o.binormal, o.color, o.V);
                return o;
            }

            void frag (v2f i, bool isFront : SV_IsFrontFace DEPTH_OUT, out half4 outNormalWS : SV_Target0
            #ifdef _WRITE_RENDERING_LAYERS
                , out uint outRenderingLayers : SV_Target1
            #endif
            )
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                #ifdef LOD_FADE_CROSSFADE
                LODFadeCrossFade(i.pos);
                #endif
                UnpackAndShadingAlpha(i, i.normal, i.tangent, i.binormal, i.color, i.V, i.uv01, i.uv23, isFront, depth);
                outNormalWS = half4(i.normal.xyz, 0.0);

                #ifdef _WRITE_RENDERING_LAYERS
                outRenderingLayers = EncodeMeshRenderingLayer();
                #endif
            }

            #include "tessellation.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "HoAOV"
            Tags { "LightMode" = "HoAOV" }
            ZWrite On
            ZTest LEqual
            Cull [_Cull]
            AlphaToMask [_AlphaToMask]

            HLSLPROGRAM
            #pragma target 5.0

            #pragma shader_feature_local _UVMODE_DEFAULT _UVMODE_PLANAR _UVMODE_TRIPLANAR
            #pragma shader_feature_local _ATRASMASK
            #pragma shader_feature_local_fragment _ _CUTOUT _DITHER _TRANSPARENT
            #pragma shader_feature_local _RANDOMIZE_UV
            #pragma shader_feature_local _TEXTUREMODE_SEPARATE
            #pragma shader_feature_local_vertex _PARALLAXMODE_VERTEX
            #pragma shader_feature_local_fragment _PARALLAXMODE_PIXEL
            #pragma shader_feature_local_fragment _NORMALMAP
            #pragma shader_feature_local_fragment _SUBSURFACE
            #pragma shader_feature_local_fragment _TRANSLUCENT
            #pragma shader_feature_local_vertex _WINDMODE_NONE _WINDMODE_CLOTH _WINDMODE_TREE
            #pragma shader_feature_local_fragment _WINDMODE_POM

            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
            struct v2f
            {
                POS_INTERPOLATION float4 pos : SV_POSITION;
                float4 uv01 : TEXCOORD0;
                float4 uv23 : TEXCOORD1;
                float4 normal : TEXCOORD2;
                float4 tangent : TEXCOORD3;
                float4 binormal : TEXCOORD4;
                float4 color : TEXCOORD5;
                float3 V : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            #define SHADERPASS SHADERPASS_DEPTHNORMALSONLY
            #include "unity_urp.hlsl"
            #include "pbr_core.hlsl"
            #include "hoaov.hlsl"

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                DoVertex(v, o.pos, o.uv01, o.uv23, o.normal, o.tangent, o.binormal, o.color, o.V);
                return o;
            }

            HoAovOutput frag (v2f i, bool isFront : SV_IsFrontFace DEPTH_OUT)
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                #ifdef LOD_FADE_CROSSFADE
                LODFadeCrossFade(i.pos);
                #endif
                return HoAovFrag(i, isFront, depth);
            }

            #include "tessellation.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "HoCharacterCapture"
            Tags { "LightMode" = "HoCharacterCapture" }
            ZWrite On
            ZTest LEqual
            Cull [_Cull]
            Blend One OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma target 5.0

            #pragma shader_feature_local _UVMODE_DEFAULT _UVMODE_PLANAR _UVMODE_TRIPLANAR
            #pragma shader_feature_local _ATRASMASK
            #pragma shader_feature_local_fragment _ _CUTOUT _DITHER _TRANSPARENT
            #pragma shader_feature_local _RANDOMIZE_UV
            #pragma shader_feature_local _TEXTUREMODE_SEPARATE
            #pragma shader_feature_local_vertex _PARALLAXMODE_VERTEX
            #pragma shader_feature_local_fragment _PARALLAXMODE_PIXEL
            #pragma shader_feature_local_fragment _BACKFACE_COLOR
            #pragma shader_feature_local_fragment _TRANSLUCENT
            #pragma shader_feature_local_vertex _WINDMODE_NONE _WINDMODE_CLOTH _WINDMODE_TREE
            #pragma shader_feature_local_fragment _WINDMODE_POM

            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
            struct v2f
            {
                POS_INTERPOLATION float4 pos : SV_POSITION;
                float4 uv01 : TEXCOORD0;
                float4 uv23 : TEXCOORD1;
                float4 normal : TEXCOORD2;
                float4 tangent : TEXCOORD3;
                float4 binormal : TEXCOORD4;
                float4 color : TEXCOORD5;
                float3 V : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            #define SHADERPASS SHADERPASS_DEPTHNORMALSONLY
            #include "unity_urp.hlsl"
            #include "pbr_core.hlsl"
            #include "hocharacter_capture.hlsl"

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                DoVertex(v, o.pos, o.uv01, o.uv23, o.normal, o.tangent, o.binormal, o.color, o.V);
                return o;
            }

            LilHoCharacterCaptureOutput frag (v2f i, bool isFront : SV_IsFrontFace DEPTH_OUT)
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                #ifdef LOD_FADE_CROSSFADE
                LODFadeCrossFade(i.pos);
                #endif
                return HoCharacterCaptureFrag(i, isFront);
            }

            #include "tessellation.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "Meta"
            Tags { "LightMode" = "Meta" }
            Cull Off

            HLSLPROGRAM
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            float4 _BaseMap_ST; // Avoid Error
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UniversalMetaPass.hlsl"

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 uv01 : TEXCOORD0;
                float4 uv23 : TEXCOORD1;
                #ifdef EDITOR_VISUALIZATION
                float2 VizUV : TEXCOORD2;
                float4 LightCoord : TEXCOORD3;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            #define SHADERPASS SHADERPASS_META
            #include "unity_urp.hlsl"
            #include "pbr_core.hlsl"

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                float4 normal, tangent, binormal, color = 0;
                float3 V = 0;
                DoVertex(v, o.pos, o.uv01, o.uv23, normal, tangent, binormal, color, V);
                o.pos = UnityMetaVertexPosition(v.vertex.xyz, v.uv1.xy, v.uv2.xy);
                #ifdef EDITOR_VISUALIZATION
                UnityEditorVizData(v.vertex.xyz, v.uv0.xy, v.uv1.xy, v.uv2.xy, o.VizUV, o.LightCoord);
                #endif
                return o;
            }

            half4 frag (v2f i, bool isFront : SV_IsFrontFace) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float2 uv[4];
                uv[0] = i.uv01.xy;
                uv[1] = i.uv01.zw;
                uv[2] = i.uv23.xy;
                uv[3] = i.uv23.zw;
                ShadingParams p = ShadingMeta(i, i.pos, uv);

                MetaInput metaInput = (MetaInput)0;
                half roughness = (1 - p.smoothness) * (1 - p.smoothness);
                metaInput.Albedo = p.albedo + p.specular * roughness * 0.5;
                metaInput.Emission = p.emission;

                #ifdef EDITOR_VISUALIZATION
                    metaInput.VizUV = fragIn.VizUV;
                    metaInput.LightCoord = fragIn.LightCoord;
                #endif

                return UnityMetaFragment(metaInput);
            }

            #include "tessellation.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "MotionVectors"
            Tags { "LightMode" = "MotionVectors" }
            ColorMask RG
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 5.0

            #pragma shader_feature_local _UVMODE_DEFAULT _UVMODE_PLANAR _UVMODE_TRIPLANAR
            #pragma shader_feature_local _ATRASMASK
            #pragma shader_feature_local_fragment _ _CUTOUT _DITHER _TRANSPARENT
            #pragma shader_feature_local _RANDOMIZE_UV
            #pragma shader_feature_local _TEXTUREMODE_SEPARATE
            #pragma shader_feature_local_vertex _PARALLAXMODE_VERTEX
            #pragma shader_feature_local_fragment _PARALLAXMODE_PIXEL
            #pragma shader_feature_local_fragment _TRANSLUCENT
            #pragma shader_feature_local_vertex _WINDMODE_NONE _WINDMODE_CLOTH _WINDMODE_TREE
            #pragma shader_feature_local_fragment _WINDMODE_POM

            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma shader_feature_local_vertex _ADD_PRECOMPUTED_VELOCITY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            //-------------------------------------
            // Other pragmas
            #include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MotionVectorsCommon.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
            struct v2f
            {
                POS_INTERPOLATION float4 pos : SV_POSITION;
                float4 uv01 : TEXCOORD0;
                float4 uv23 : TEXCOORD1;
                float4 normal : TEXCOORD2;
                float4 tangent : TEXCOORD3;
                float4 binormal : TEXCOORD4;
                float4 color : TEXCOORD5;
                float3 V : TEXCOORD6;
                float4 positionCSNoJitter         : POSITION_CS_NO_JITTER;
                float4 previousPositionCSNoJitter : PREV_POSITION_CS_NO_JITTER;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            #define SHADERPASS SHADERPASS_MOTION_VECTORS
            #include "unity_urp.hlsl"
            #include "pbr_core.hlsl"

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                DoVertex(v, o.pos, o.uv01, o.uv23, o.normal, o.tangent, o.binormal, o.color, o.V);

                #if defined(APPLICATION_SPACE_WARP_MOTION)
                o.positionCSNoJitter = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, v.vertex));;
                o.pos = o.positionCSNoJitter;
                #else
                o.positionCSNoJitter = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, v.vertex));
                #endif

                float4 prevPos = (unity_MotionVectorsParams.x == 1) ? float4(v.positionOld, 1) : v.vertex;

                #if _ADD_PRECOMPUTED_VELOCITY
                prevPos = prevPos - float4(v.alembicMotionVector, 0);
                #endif

                o.previousPositionCSNoJitter = mul(_PrevViewProjMatrix, mul(UNITY_PREV_MATRIX_M, prevPos));
                return o;
            }

            half4 frag (v2f i, bool isFront : SV_IsFrontFace DEPTH_OUT) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                #ifdef LOD_FADE_CROSSFADE
                LODFadeCrossFade(i.pos);
                #endif
                UnpackAndShadingAlpha(i, i.normal, i.tangent, i.binormal, i.color, i.V, i.uv01, i.uv23, isFront, depth);

                #if defined(APPLICATION_SPACE_WARP_MOTION)
                return float4(CalcAswNdcMotionVectorFromCsPositions(i.positionCSNoJitter, i.previousPositionCSNoJitter), 1);
                #else
                return float4(CalcNdcMotionVectorFromCsPositions(i.positionCSNoJitter, i.previousPositionCSNoJitter), 0, 0);
                #endif
            }

            #include "tessellation.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "XRMotionVectors"
            Tags { "LightMode" = "XRMotionVectors" }
            Stencil
            {
                WriteMask 1
                Ref 1
                Comp Always
                Pass Replace
            }
            ColorMask RGBA
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 5.0

            #pragma shader_feature_local _UVMODE_DEFAULT _UVMODE_PLANAR _UVMODE_TRIPLANAR
            #pragma shader_feature_local _ATRASMASK
            #pragma shader_feature_local_fragment _ _CUTOUT _DITHER _TRANSPARENT
            #pragma shader_feature_local _RANDOMIZE_UV
            #pragma shader_feature_local _TEXTUREMODE_SEPARATE
            #pragma shader_feature_local_vertex _PARALLAXMODE_VERTEX
            #pragma shader_feature_local_fragment _PARALLAXMODE_PIXEL
            #pragma shader_feature_local_fragment _TRANSLUCENT
            #pragma shader_feature_local_vertex _WINDMODE_NONE _WINDMODE_CLOTH _WINDMODE_TREE
            #pragma shader_feature_local_fragment _WINDMODE_POM

            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma shader_feature_local_vertex _ADD_PRECOMPUTED_VELOCITY
            #define APPLICATION_SPACE_WARP_MOTION 1

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            //-------------------------------------
            // Other pragmas
            #include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MotionVectorsCommon.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
            struct v2f
            {
                POS_INTERPOLATION float4 pos : SV_POSITION;
                float4 uv01 : TEXCOORD0;
                float4 uv23 : TEXCOORD1;
                float4 normal : TEXCOORD2;
                float4 tangent : TEXCOORD3;
                float4 binormal : TEXCOORD4;
                float4 color : TEXCOORD5;
                float3 V : TEXCOORD6;
                float4 positionCSNoJitter         : POSITION_CS_NO_JITTER;
                float4 previousPositionCSNoJitter : PREV_POSITION_CS_NO_JITTER;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            #define SHADERPASS SHADERPASS_XR_MOTION_VECTORS
            #include "unity_urp.hlsl"
            #include "pbr_core.hlsl"

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                DoVertex(v, o.pos, o.uv01, o.uv23, o.normal, o.tangent, o.binormal, o.color, o.V);

                #if defined(APPLICATION_SPACE_WARP_MOTION)
                o.positionCSNoJitter = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, v.vertex));;
                o.pos = o.positionCSNoJitter;
                #else
                o.positionCSNoJitter = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, v.vertex));
                #endif

                float4 prevPos = (unity_MotionVectorsParams.x == 1) ? float4(v.positionOld, 1) : v.vertex;

                #if _ADD_PRECOMPUTED_VELOCITY
                prevPos = prevPos - float4(v.alembicMotionVector, 0);
                #endif

                o.previousPositionCSNoJitter = mul(_PrevViewProjMatrix, mul(UNITY_PREV_MATRIX_M, prevPos));
                return o;
            }

            half4 frag (v2f i, bool isFront : SV_IsFrontFace DEPTH_OUT) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                #ifdef LOD_FADE_CROSSFADE
                LODFadeCrossFade(i.pos);
                #endif
                UnpackAndShadingAlpha(i, i.normal, i.tangent, i.binormal, i.color, i.V, i.uv01, i.uv23, isFront, depth);

                #if defined(APPLICATION_SPACE_WARP_MOTION)
                return float4(CalcAswNdcMotionVectorFromCsPositions(i.positionCSNoJitter, i.previousPositionCSNoJitter), 1);
                #else
                return float4(CalcNdcMotionVectorFromCsPositions(i.positionCSNoJitter, i.previousPositionCSNoJitter), 0, 0);
                #endif
            }

            #include "tessellation.hlsl"
            ENDHLSL
        }
    }


    CustomEditor "jp.lilxyzw.lilpbr.PBRShaderGUI"
    //Fallback "lilPBR"
}
