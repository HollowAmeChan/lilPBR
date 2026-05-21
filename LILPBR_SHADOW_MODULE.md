# lilPBR Shadow Module

## Goal

The Shadow module adds material-level art direction for realtime shadows. lilPBR previously multiplied URP shadow attenuation and HoShadowCast attenuation directly into light intensity, which allowed character skin shadows to fall to pure black. That is physically plausible in some scenes but poor for stylized skin and avatar rendering.

This module remaps realtime shadow attenuation before it reaches diffuse/specular lighting and SSS.

## Controls

- `Shadow Strength`: Overall realtime shadow influence. `1` preserves normal shadowing, `0` ignores realtime shadow attenuation.
- `Shadow Min Light`: The darkest allowed remapped shadow value. Raise this to keep skin shadows from becoming black.
- `Shadow Contrast`: Curve applied to the raw shadow. Values below `1` soften shadows, values above `1` make shadows more contrasty.
- `Shadow Tint`: Color used to warm or stylize the shadow-side diffuse response.
- `Shadow Tint Strength`: Amount of shadow-side tint. `0` disables tint.
- `HoShadow Strength`: Strength of HoShadowCast attenuation before remapping. `1` preserves existing HoShadowCast behavior, `0` ignores HoShadowCast for this material.

Default values preserve the old look:

```text
Shadow Strength      = 1
Shadow Min Light     = 0
Shadow Contrast      = 1
Shadow Tint Strength = 0
HoShadow Strength    = 1
```

## Shader Model

URP shadow attenuation and HoShadowCast attenuation are combined, curved, then remapped:

```hlsl
rawShadow = urpShadow * lerp(1, hoShadow, HoShadowStrength);
curvedShadow = pow(rawShadow, ShadowContrast);
remappedShadow = lerp(ShadowMinLight, 1, curvedShadow);
finalShadow = lerp(1, remappedShadow, ShadowStrength);
```

The final shadow value is used by:

- Main light diffuse/specular.
- Additional light diffuse/specular.
- Subsurface scattering direct light.

Shadow tint is added only in the shadowed portion of direct diffuse lighting:

```hlsl
shadowArea = 1 - finalShadow;
diffuse += diffuseTerm * lightColor * ShadowTint * ShadowTintStrength * shadowArea;
```

This avoids globally brightening the final color and keeps highlights/reflections physically plausible.

## Skin Starting Points

For skin, start with:

```text
Shadow Strength      = 0.70 - 0.85
Shadow Min Light     = 0.20 - 0.35
Shadow Contrast      = 0.80 - 1.20
Shadow Tint          = warm red/orange-pink
Shadow Tint Strength = 0.10 - 0.35
HoShadow Strength    = 0.50 - 1.00
```

If shadows still look dirty, reduce `Screen Space AO > Direct AO Strength` before raising `Shadow Min Light` too high. AO should describe contact occlusion, not act as a second character shadow layer.

## Implementation Notes

- Properties are declared in `lilPBR.shader` and `lilPBR_Tessellation.shader` under the `Shadow` foldout.
- Uniform declarations live in `Shaders/pbr_properties.hlsl`.
- URP lighting integration lives in `Shaders/unity_urp.hlsl`.
- The module does not add shader keywords or variants.
