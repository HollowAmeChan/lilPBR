#ifndef INCLUDED_LILPBR_HOCHARACTER_CAPTURE
#define INCLUDED_LILPBR_HOCHARACTER_CAPTURE

#define LIL_HO_CHARACTER_CAPTURE_HAS_AOV_PROPERTIES
#include "Packages/jp.lilxyzw.liltoon.urp.extensions/Runtime/CharacterSpecialization/Shaders/HoCharacterCaptureCommon.hlsl"

half4 HoCharacterCaptureResolveColor(v2f i, bool isFront)
{
    float2 uv_MainTex = i.uv01.xy * _MainTex_ST.xy + _MainTex_ST.zw;
    half4 color = _MainTex.Sample(sampler_trilinear_repeat, uv_MainTex) * _Color;

    #ifdef _BACKFACE_COLOR
    if (!isFront)
    {
        color = _BackfaceTex.Sample(sampler_trilinear_repeat, uv_MainTex) * _BackfaceColor;
    }
    #endif

    if (_VertexColorMode == 1)
    {
        color *= i.color;
    }

    #if defined(_CUTOUT)
        clip(color.a - _Cutoff);
        color.a = 1.0;
    #elif defined(_DITHER)
        half alpha = color.a;
        if (_DitherRandomize && IsPerspective())
        {
            alpha = alpha + ibuki(i.pos) * 0.1 - 0.05;
        }
        clip(alpha - (_DitherTex[uint2(i.pos.xy) % 4].r * 255 + 1) / (15 + 2));
        color.a = 1.0;
    #else
        clip(color.a - 0.001);
    #endif

    return color;
}

LilHoCharacterCaptureOutput HoCharacterCaptureFrag(v2f i, bool isFront)
{
    half4 color = HoCharacterCaptureResolveColor(i, isFront);
    return LilHoCharacterBuildCaptureOutput(
        color,
        i.pos.z,
        _HoCharacterCaptureOpacity);
}

#endif
