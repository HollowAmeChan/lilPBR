# Crystal Gem Shader 重构准备文档

## 目标

这次重构直接新开一个宝石 shader，但不把代码拆成很多文件。当前 shader 规模还不大，优先把结构理顺：

- 一个新 shader 入口。
- 少量文件。
- 每个视觉组分一个自己的函数。
- 每个参与最终合成的组分都有独立强度开关。
- 只有真正复用的逻辑才抽成 helper/interface 函数。
- 最终合成保持直白，不做复杂框架。

旧 `CrystalRaymarch8.shader` 已经删除。`CrystalMatCapParallaxGem8.shader` 也已在新 shader 验收后删除。

## 文件规划

推荐最小文件方案：

- `Shaders/CrystalGemComposite.shader`
  - 新 shader 入口。
  - Shader menu 建议：`lilPBR/Crystal/Gem Composite`
  - 包含 Properties、CBUFFER、pass 声明。
  - 第一阶段定位为不透明假宝石，不走真正透明队列。

- `Shaders/crystal_gem_composite_core.hlsl`
  - 新 shader 的主要实现。
  - 放 vertex、surface resolve、各组分函数、最终 fragment 合成。
  - 不再按 optics/internal/glow/fibers/matcap/lighting 拆多个 include。

已删除的旧文件：

- `Shaders/CrystalMatCapParallaxGem8.shader`
- `Shaders/crystal_core.hlsl`
- `Shaders/crystal_matcap_parallax_gem_core.hlsl`
- `Shaders/crystal_raymarch.hlsl`

原因：新 shader 已稳定验收，并且不再依赖旧 raymarch/include 链路。

如果后续确实出现复用，再拆出去。当前阶段不预设多文件架构。

## 渲染队列策略

第一阶段明确做“不透明假宝石”，不做真正透明队列。

当前旧入口 `CrystalMatCapParallaxGem8.shader` 是：

- `RenderType = TransparentCutout`
- `Queue = AlphaTest`
- `ZWrite` 默认可开
- 有 `ShadowCaster`、`DepthOnly`、`DepthNormals`

这不是真正透明。它更接近 cutout/opaque 路径：能稳定写深度、投影、参与 depth normals，排序问题少，适合角色或道具上的假宝石。

新 `CrystalGemComposite.shader` 第一版推荐默认：

```shaderlab
Tags
{
    "RenderPipeline" = "UniversalPipeline"
    "RenderType" = "Opaque"
    "Queue" = "Geometry"
    "IgnoreProjector" = "True"
}

ZWrite On
Blend Off
```

如果材质确实需要 alpha cutoff，可以保留 `_Cutoff`，但这仍然是 cutout/opaque 思路，不是透明混合。也可以后续加一个 cutout 入口或材质开关：

```shaderlab
"RenderType" = "TransparentCutout"
"Queue" = "AlphaTest"
```

第一阶段所有“折射、通透、内部反射”的感觉都通过这些假组分完成：

- `Internal Field & Glow`
- 标准 view-space `MatCap`
- `Highlight`
- `Reflection`

注意：这里的“折射”只存在于 `Internal Field & Glow` 的内部采样光路，不作为 Lighting 的最终输出组分。

真正透明宝石以后单独开入口，例如：

- `Shaders/CrystalGemTransparent.shader`
- Shader menu：`lilPBR/Crystal/Gem Transparent`

透明变体需要单独处理，不进入第一阶段：

- `RenderType = Transparent`
- `Queue = Transparent`
- `ZWrite` 默认 Off 或双 pass depth prepass
- `Blend SrcAlpha OneMinusSrcAlpha` 或 premultiply
- 透明排序问题
- 透明阴影策略
- depth normals 是否写入
- 屏幕空间折射或背景采样
- 焦散 caustics
- OIT 或项目已有透明方案

结论：先把不透明假宝石做好。透明宝石是另一个 shader，不在当前重构第一版里混做。

### 后续透明宝石专项

透明宝石版本再重新规划折射和焦散，不复用不透明版的 Lighting 输出结构。

透明版重点：

- 可见折射：背景采样或屏幕空间颜色缓冲扭曲。
- 透射颜色：厚度、吸收、内部色散。
- 焦散：独立 caustics mask、方向、强度、距离衰减，可以先做假 caustics，再考虑屏幕/光源相关方案。
- 深度策略：透明 depth prepass 或排序/OIT。
- 阴影策略：透明投影、半透阴影或只保留 opaque caster。

这部分等 `CrystalGemComposite.shader` 稳定后，单独在 `CrystalGemTransparent.shader` 里做。

## 命名规则

变量名尽量简单直白，不全部带 `Crystal`。

推荐：

- `surface`
- `viewDirWS`
- `normalWS`
- `edge`
- `thickness`
- `refractionNoise`
- `fieldMain`
- `fieldSecondary`
- `fieldMask`
- `glowMask`
- `fiberMask`
- `baseColor`
- `matcap`
- `glow`
- `fibers`
- `highlight`
- `reflection`

只有真正的宝石组分函数或组分结构带 `Crystal`，例如：

- `CrystalSurface`
- `CrystalInternalField`
- `CrystalResolveSurface`
- `CrystalTraceInternalField`
- `CrystalGlow`
- `CrystalDynamicFibers`
- `CrystalMatCap`
- `CrystalHighlight`
- `CrystalEnvironment`
- `CrystalShadow`
- `CrystalReflection`
- `CrystalShade`

不要为了统一前缀把每个局部变量都写成 `_CrystalXXX` 或 `crystalXXX`。新 shader 第一版已经把材质属性迁移成短名，例如 `_BaseColor`、`_VolumeNoise`、`_MatCapTex`、`_FiberStrength`；只在真正的组分函数和结构名上保留 `Crystal`。

结构体字段也用单数简单名，例如 `surface.edge`、`surface.thickness`。旧 shader 里的 `edges` 可以在迁移时改掉。

## 现有组分判断

复查现有代码后，优先级应这样定：

- Dynamic Fibers 旧实现已经有独立内部射线、24 步 procedural 累积、flow、模式和调色，第一版不需要重写。
- MatCap、Highlight、Reflection 都是相对独立的 additive 组分，主要问题是 strength 和合成边界，不是算法本身。
- Internal Field & Glow 是最值得提升的部分。旧逻辑更像“8 步噪声 mask + ramp”，缺少宝石内部的深度、吸收、边缘能量和尖锐亮点层次。

所以本轮实现重点放在 `Internal Field & Glow` 的质量提升，其他组分先做清晰接入和强度合成。

## BetterCrystals 参考梳理

参考路径：

- `D:/Unity_Project/Break_HORP/Assets/SineVFX/BetterCrystals/AssetResources/Shaders/CrystalRayM_8Samples.hlsl`
- `D:/Unity_Project/Break_HORP/Assets/SineVFX/BetterCrystals/AssetResources/Shaders/Crystal_8Samples.shadergraph`

不需要先把 ShaderGraph 全量转 HLSL。核心 raymarch 已经在 `CrystalRayM_8Samples.hlsl` 里，ShaderGraph 主要负责把 raymarch 输出继续做 mask、ramp、thickness、edges、desaturation 和 blend。

已确认的参考链路：

- `Crystal_8Samples.shadergraph` 的 Custom Function 绑定 `CrystalRayM_8Samples.hlsl`，函数名是 `MyCustomRaymarching`。
- `MyCustomRaymarching` 输出 `float2 outputpom`：
  - `x` = main volume mask
  - `y` = secondary volume mask
- `outputpom` 后面进入 `Noise 2 Intersect`，再进入 `Ramp Emission And Power`，最后通过 `Desaturation/Blend` 接到 `SurfaceDescription.Emission`。
- BetterCrystals 的 `MyCustomRaymarching` 比当前旧版多了 `LinearMask*` 输入，这个线性 mask 会在每一步采样里乘到 main/secondary 累积上。它更像固定方向的风格化渐隐，不是宝石核心组分。
- ShaderGraph 里有明确的组：`Refraction Surface Noise`、`Noise 2 Intersect`、`Ramp Emission And Power`、`Thickness Emission`、`Edges Emission`、`Desaturation`、`Blending`。

参考实现里值得保留的点：

- 折射光路：`refract(normalize(ViewDirection), NormalVector, saturate(1 - (1 / Refraction * RefractionSurfaceNoise)))`。
- Triplanar 体积噪声不是加权混合，而是三个平面采样相乘。这会让内部结构更像交叠晶体噪声，而不是普通柔和噪声。
- 8 sample 每步距离是 `StepLength / 8`。
- main mask：`pow(saturate(pow(noise.x, NoisePow) * NoiseStrength * 1.45), 1.25) * saturate(1 - i / 20) * linearMask`。
- secondary mask：`pow(noise.y, VolumeNoise2Exp * 0.95) * VolumeNoise2Multiply * 2.0 * linearMask`。
- linear mask：`saturate(saturate((dot(sampledPosition - LinearMaskVectorWorldOffset, LinearMaskVector) + LinearMaskOffset) * LinearMaskScale) + LinearMaskNegate)`。
- `Volume Noise Offset.z` 会参与 `LinearMaskOffset` 的 subtract。这个行为保留在参考记录里，但新 shader 不必默认绑定这层关系。
- `Refraction Surface Noise` 是可开关 branch：启用时用采样值 + negate 后 clamp；关闭时走默认值。
- `Ramp Emission And Power` 不是简单 `fieldMask -> ramp`，还包括 ramp exp、main mask exp、fresnel exp、fresnel negate 和最终 emission power。

项目化简时不必照搬全部 ShaderGraph 节点，但要保留这些语义：

- `Linear Mask`：控制内部体积沿某个方向出现/消失。新 shader 只做可选风格化控制，默认不改变结果。
- `Noise 2 Intersect`：secondary 不只是相加，它要能和 main 做交叠/局部变化。
- `Thickness Emission`：厚度 mask 参与发光，不只是表面 tint。
- `Edges Emission`：边缘 mask 单独给发光能量。
- `Ramp Main Mask Exp` 和 `Ramp Fresnel Exp`：分别控制体积主 mask 和 Fresnel 对 ramp 坐标/强度的影响。
- `Ramp Color Tint` 和 `Ramp Emission Power`：仍然是最终 glow 输出的主要调色和强度控制。

## Internal Field & Glow 详细实现草案

这一节是后续实现和优化的直接依据。变量名按新 shader 的简化命名写，属性名使用短名。

### 数据结构

```hlsl
struct CrystalInternalField
{
    half fieldMain;
    half fieldSecondary;
    half fieldMask;
    half coreMask;
    half edgeMask;
    half styleFade;
    half glowMask;
};
```

如果后面要做 debug，可以临时扩展：

```hlsl
struct CrystalInternalFieldDebug
{
    half refractionNoise;
    half thicknessMask;
    half fresnelMask;
    half secondaryIntersect;
};
```

### Refraction Surface Noise

参考 ShaderGraph 的 `Refraction Surface Noise` 组：

```hlsl
half ResolveRefractionNoise(Varyings input, half3 viewDirWS)
{
    if (useRefractionNoise == 0)
    {
        return 1.0h;
    }

    half3x3 tangentToWorld = BuildTangentToWorld(input);
    half3 viewDirTS = mul(transpose(tangentToWorld), viewDirWS);

    float2 uv = input.uv * refractionNoiseST.xy + refractionNoiseST.zw;
    uv -= viewDirTS.xy / max(abs(viewDirTS.z), 0.25h) * refractionNoiseParallax * 0.002;

    half noise = SAMPLE_TEXTURE2D(refractionNoiseTex, samplerRefractionNoiseTex, uv * refractionNoiseScale).r;
    return saturate(noise + refractionNoiseNegate);
}
```

实现备注：

- 旧 `CrystalMatCapParallaxGem8.shader` 用的是 `lerp(1, noise + add, strength)`；BetterCrystals 是 enabled/negate/clamp 语义。
- 新 shader 可以合并两者：`enabled` 控制是否采样，`strength` 控制回到 1 的混合，`negate/add` 控制偏移。
- 最终建议：

```hlsl
half sampled = saturate(noise + refractionNoiseAdd);
return lerp(1.0h, sampled, refractionNoiseStrength);
```

### Volume Space

BetterCrystals 有 `World Or Local`、`Local One To One Scale`、`Volume Noise Offset` 分支。我们保留当前旧 shader 的三档空间即可：

- `World`
- `Local`
- `LocalOneToOne`

实现上继续输出：

```hlsl
float3 fieldPos;
float3 fieldNormal;
float3 fieldViewDir;
```

注意：

- `Volume Noise Offset` 要加到采样位置。
- `Volume Noise Offset.z` 在 BetterCrystals 里还参与 `LinearMaskOffset` 的 subtract。新 shader 默认不绑定这层关系；只有做 BetterCrystals 兼容模式时才恢复。

### Style Direction Fade

BetterCrystals 的 `LinearMask*` 本质是固定方向的体积渐隐。它对某些风格化水晶有用，但不应该成为宝石核心组分。新 shader 里把它改成简单、可选、默认无影响的 `Style Direction Fade`。

```hlsl
float StyleDirectionFade(float3 samplePos)
{
    if (styleFadeStrength <= 0.0)
    {
        return 1.0;
    }

    float3 dir = normalize(styleFadeDirection);
    float v = dot(samplePos - styleFadeOffset.xyz, dir);
    float fade = saturate((v + styleFadeOffset.w) * styleFadeScale + 0.5);
    fade = lerp(fade, 1.0 - fade, saturate(styleFadeInvert));
    return lerp(1.0, fade, saturate(styleFadeStrength));
}
```

实现备注：

- 默认 `styleFadeStrength = 0`，不影响宝石内部场。
- `styleFadeDirection` 默认 `(0, 1, 0)`。
- `styleFadeScale` 越大，过渡越硬。
- 这组参数放 Advanced 或 Internal Field & Glow 的末尾，不放在核心调参前面。
- 不沿用 BetterCrystals 的 `linearMaskNegate` 语义；新实现用更直观的 `styleFadeInvert`。

### Triplanar Volume Noise

BetterCrystals 的体积噪声是三平面相乘：

```hlsl
float2 SampleFieldNoise(float3 samplePos)
{
    float2 xy = SAMPLE_TEXTURE2D(fieldNoiseTex, samplerFieldNoiseTex, samplePos.xy * fieldScale).rg;
    float2 zy = SAMPLE_TEXTURE2D(fieldNoiseTex, samplerFieldNoiseTex, samplePos.zy * fieldScale + float2(144.23, 5444.12)).rg;
    float2 xz = SAMPLE_TEXTURE2D(fieldNoiseTex, samplerFieldNoiseTex, samplePos.xz * fieldScale + float2(3127.11, 1522.12)).rg;
    return xy * zy * xz;
}
```

实现备注：

- 旧 `crystal_raymarch.hlsl` 已改成按 normal 加权混合，这会更平滑，但少了参考实现的交叠晶体感。
- 新 shader 的第一版建议回到参考实现的乘法采样。
- 如果乘法太碎或太黑，再加一个 blend 参数：

```hlsl
float2 multiplied = xy * zy * xz;
float2 blended = xy * weights.z + xz * weights.y + zy * weights.x;
return lerp(multiplied, blended, fieldTriplanarBlend);
```

### Field Trace 8

直接参考 `CrystalRayM_8Samples.hlsl`，但输出结构化结果：

```hlsl
CrystalInternalField CrystalTraceInternalField(Varyings input, CrystalSurface surface)
{
    CrystalInternalField field = (CrystalInternalField)0;

    if (fieldStrength <= 0.0h)
    {
        return field;
    }

    float3 fieldPos;
    float3 fieldNormal;
    float3 fieldViewDir;
    ResolveFieldSpace(input, surface, fieldPos, fieldNormal, fieldViewDir);

    half refractionNoise = ResolveRefractionNoise(input, surface.viewDirWS);
    float eta = saturate(1.0 - (1.0 / max(refractionStrength, 0.001)) * max(refractionNoise, 0.001));
    float3 ray = refract(normalize(fieldViewDir), normalize(fieldNormal), eta);

    float stepDistance = 0.0;
    float mainAccum = 0.0;
    float secondaryAccum = 0.0;
    float styleFadeAccum = 0.0;

    [unroll]
    for (int i = 0; i < 8; i++)
    {
        float3 samplePos = fieldPos + ray * stepDistance;
        float2 noise = SampleFieldNoise(samplePos);
        float styleFade = StyleDirectionFade(samplePos);

        float mainDensity = pow(
            saturate(pow(saturate(noise.r), fieldMainExp) * fieldMainStrength * 1.45),
            1.25
        ) * saturate(1.0 - (i / 20.0));

        float secondaryDensity = pow(
            saturate(noise.g),
            fieldSecondaryExp * 0.95
        ) * fieldSecondaryStrength * 2.0;

        mainAccum += mainDensity * styleFade;
        secondaryAccum += secondaryDensity * styleFade;
        styleFadeAccum += styleFade;

        stepDistance += fieldStepLength / 8.0;
    }

    field.fieldMain = saturate(mainAccum);
    field.fieldSecondary = saturate(secondaryAccum);
    field.styleFade = saturate(styleFadeAccum * 0.125);

    half secondaryIntersect = field.fieldSecondary * fieldSecondaryIntersect;
    field.fieldMask = saturate(field.fieldMain + secondaryIntersect) * fieldStrength;

    return field;
}
```

实现备注：

- `fieldMainStrength` 对应 BetterCrystals 的 `Volume Noise Multiply`。
- `fieldSecondaryStrength` 对应 `Volume Noise 2 Multiply`。
- 这里把 `fieldStepLength / 8.0` 写死为 8 sample 版本；如果之后做 3/8/12 quality，再把 sample count 参数化。
- 如果性能需要，可以先只做 8 unroll，不引入 loop count 属性。

### Noise 2 Intersect

BetterCrystals 有独立 `Noise 2 Intersect` 组。第一版用简化公式：

```hlsl
half ResolveFieldMask(half fieldMain, half fieldSecondary)
{
    half secondaryIntersect = fieldSecondary * fieldSecondaryIntersect;
    return saturate(fieldMain + secondaryIntersect) * fieldStrength;
}
```

如果需要更接近“交叠”而不是“相加”，第二版可以改成：

```hlsl
half secondaryIntersect = lerp(fieldSecondary, fieldMain * fieldSecondary, fieldSecondaryIntersect);
half fieldMask = saturate(fieldMain + secondaryIntersect);
```

优化判断：

- 如果内部太糊，用乘法交叠。
- 如果内部太空，用加法交叠。
- 如果 secondary 只想做细碎变化，用 `fieldMain * fieldSecondary`。

### Glow Mask

把 BetterCrystals 的 `Thickness Emission`、`Edges Emission`、`Ramp Emission And Power` 合并成一个函数：

```hlsl
CrystalInternalField CrystalBuildGlowMasks(CrystalSurface surface, CrystalInternalField field)
{
    half thicknessMask = lerp(1.0h, surface.thickness, saturate(thicknessWeight));

    half fresnelMask = pow(
        saturate(surface.fresnel + rampFresnelAdd),
        max(rampFresnelExp, 0.001h)
    ) * fresnelWeight;

    half edgeMask = surface.edge * edgeWeight;
    field.edgeMask = saturate(edgeMask + fresnelMask);

    field.coreMask = pow(saturate(field.fieldMask), max(rampMainMaskExp, 0.001h)) * thicknessMask;
    field.glowMask = ApplyContrast(saturate(field.coreMask + field.edgeMask), glowContrast);

    return field;
}
```

实现备注：

- `surface.edge` 来自 mask R。
- `surface.thickness` 来自 mask G。
- `Edges Use Thickness Instead`、`Edges Only On Masked`、`Thickness Invert` 这些 BetterCrystals 高级控制第一版不必全搬。
- 如果后面发现边缘和厚度表现差异大，再补：

```hlsl
half edgeSource = edgesUseThickness ? surface.thickness : surface.edge;
edgeSource *= lerp(1.0h, surface.thickness, edgesOnlyOnMasked);
```

### Glow Color

```hlsl
half3 CrystalGlow(CrystalSurface surface, CrystalInternalField field)
{
    if (glowStrength <= 0.0h || glowPower <= 0.0h)
    {
        return half3(0.0h, 0.0h, 0.0h);
    }

    half rampCoord = saturate(field.glowMask);
    half3 rampColor = SAMPLE_TEXTURE2D(glowRamp, samplerGlowRamp, float2(rampCoord, 0.5)).rgb;
    rampColor *= glowTint.rgb;

    return rampColor * field.glowMask * glowPower;
}
```

最终合成处再乘 `glowStrength`：

```hlsl
color += glow * glowStrength;
```

### 当前实现与参考实现差异

当前旧实现：

```hlsl
volumeMask = saturate(surface.volumeMain + surface.volumeSecondary * _VolumeSecondaryIntersect);
glowMask = contrast(volumeMask * thickness + edge + fresnel);
glow = ramp(glowMask) * glowMask * power;
```

新实现应该变成：

```hlsl
field = trace 8 samples with refraction noise + optional style direction fade;
fieldMask = resolve main/secondary/noise2Intersect;
coreMask = pow(fieldMask, rampMainMaskExp) * thickness;
edgeMask = edge emission + fresnel ramp shaping;
glowMask = contrast(coreMask + edgeMask);
glow = ramp(glowMask) * tint * glowMask * power;
```

这条链路比旧版多出来的优化抓手：

- `styleFade` 可选控制内部结构沿固定方向渐隐，默认不参与。
- `noise2Intersect` 控制 secondary 和 main 的关系。
- `rampMainMaskExp` 控制内部结构锐度。
- `rampFresnelExp/add` 控制边缘发光。
- `thicknessWeight` 控制内部深度感。
- `edgeWeight` 控制切面/边缘能量。

### 后续优化检查点

实现后优先按这些点调：

- 内部太平：提高 `rampMainMaskExp`，或把 triplanar 采样从 weighted blend 改回 multiply。
- 内部太碎：降低 `fieldMainExp`，降低 `fieldMainStrength`，或加入 `fieldTriplanarBlend` 混回 weighted blend。
- 内部亮度满屏：先降低 `fieldStrength`；如果需要风格化裁切，再提高 `styleFadeStrength` 或 `styleFadeScale`。
- 边缘不亮：提高 `edgeWeight` 或降低 `rampFresnelExp`。
- 边缘糊成一圈：提高 `rampFresnelExp`，降低 `rampFresnelAdd`。
- 厚度感弱：提高 `thicknessWeight`，确认 mask G 有有效数据。
- secondary 没贡献：提高 `fieldSecondaryStrength` 或 `fieldSecondaryIntersect`。
- secondary 太脏：用 `fieldMain * fieldSecondary` 替代直接相加。

## Inspector 分组

### Surface

负责表面输入和基础预处理：

- Base Color
- Main Tex
- Cutoff
- Mask：R = edge，G = thickness
- Normal Map
- Normal Strength
- Spherical Normal Blend
- Outer Tint
- Inner Tint
- Edge Tint
- Fresnel Tint

这组只产出表面颜色、法线、边缘、厚度、Fresnel。

### Internal Field & Glow

合并旧的 `Refraction Scattering`、`Internal Impurities 2` 和 `Gem Glow`。

这个组负责宝石内部的基础光路、静态密度场和基于密度场的发光。Inspector 里用空行分段即可，不需要拆成两个 foldout。

折射/光路：

- Refraction Strength
- Refraction Noise Tex
- Refraction Noise Scale
- Refraction Noise Strength
- Refraction Noise Add
- Refraction Noise Parallax

静态内部场：

- Field Strength
- Field Noise Tex
- Field Step Length
- Field Scale
- Field Offset
- Field Main Exp
- Field Main Strength
- Field Secondary Exp
- Field Secondary Strength
- Field Secondary Intersect
- Field Space

发光输出：

- Glow Strength
- Glow Ramp
- Glow Tint
- Glow Strength
- Glow Contrast
- Thickness Weight
- Edge Weight
- Fresnel Weight
- Ramp Main Mask Exp
- Ramp Fresnel Exp
- Ramp Fresnel Add

风格化方向渐隐，可放在本组末尾或 Advanced：

- Style Fade Strength
- Style Fade Direction
- Style Fade Offset
- Style Fade Scale
- Style Fade Invert

代码里仍然建议把“场采样”和“颜色输出”分成两个函数，因为它们职责不同：

- `fieldMain`
- `fieldSecondary`
- `fieldMask`
- `coreMask`
- `edgeMask`
- `styleFade`
- `glowMask`
- `glow`

建议取消旧的独立 `Ramp Mask Parallax`，因为视差应该由 Internal Field & Glow 的折射光路统一控制。否则调参时会出现两套不一致的内部偏移。

Internal Field & Glow 是这次主要优化对象。旧实现只保留了 BetterCrystals 自定义 raymarch 的一部分，然后直接把 `volumeMain + volumeSecondary` 喂给 glow ramp；ShaderGraph 后半段里的 noise 2 intersect、thickness emission、edges emission、ramp exp/fresnel 关系没有完整移过来。LinearMask 属于风格化方向渐隐，保留为可选项即可。

新实现应该先把 BetterCrystals 的关键链路补回来：

- 每步采样可选乘 `styleFade`，但默认不影响体积。
- main/secondary 保持 8 sample 的公式和权重，再在 field 后处理里做 `Noise 2 Intersect`。
- `coreMask` 来自 main + secondary intersect。
- `edgeMask` 来自 mask 边缘和 Fresnel，而不是混在 fieldMain 里。
- thickness 参与 glow mask，提供内部深度感。
- ramp 坐标和强度由 `Ramp Main Mask Exp`、`Ramp Fresnel Exp`、`Ramp Fresnel Add` 共同控制。

详细 HLSL 草案见上文 `Internal Field & Glow 详细实现草案`。这里的 Inspector 参数和实现草案保持同一套语义：`Field Strength` 影响静态内部场输出，`Glow Strength` 只影响最终发光输出。

### Dynamic Fibers

替代旧 `Gem Internal Impurities`。

这组先沿用现有 `CrystalGemInternalVolume` 的思路，不作为本轮主要重做对象。旧实现已经有内部射线、24 步 procedural 累积、flow、fractal/marble/veins 模式和颜色变化；第一版重构只负责把它接到新的 `Internal Field & Glow` 结果上，并让它只做动态絮状部分，不再承担静态内部场和 glow。

- Fiber Strength
- Fiber Scale
- Fiber Depth
- Fiber Contrast
- Fiber Flow Speed
- Fiber Flow Strength
- Fiber Flow Phase
- Fiber Fresnel
- Fiber Color
- Fiber Secondary Color
- Fiber Color Variation

如果为了兼容旧材质，第一版可以保留现有 `Fractal / Marble / Veins` 模式，但 UI 文案要从“内部杂质整体”改成“动态絮状模式”。不要在这一步为了纯净结构重写 Dynamic Fibers。

### MatCap

MatCap 需要改采样逻辑。旧实现用 view-space normal：

```hlsl
matcapUV = mul((float3x3)UNITY_MATRIX_V, normalize(surface.normalWS)).xy * 0.5 + 0.5;
```

当前新 shader 改回标准 view-space MatCap，保留传统 MatCap 的视角响应；固定方向和 front/back 混合不进入第一版。

- MatCap Strength
- MatCap Tex
- MatCap Color
- MatCap Fresnel
- MatCap Space：World / Local
- MatCap Direction
- MatCap Up
- MatCap Back Blend

推荐实现：

```hlsl
half2 FixedMatCapUV(half3 normalWS)
{
    half3 forward = normalize(matcapDirectionWS);
    half3 up = normalize(matcapUpWS);
    half3 right = normalize(cross(up, forward));
    up = normalize(cross(forward, right));

    half2 uv;
    uv.x = dot(normalWS, right);
    uv.y = dot(normalWS, up);
    return uv * 0.5h + 0.5h;
}

half3 CrystalMatCap(Varyings input, CrystalSurface surface)
{
    half3 normalWS = normalize(surface.normalWS);
    half2 frontUV = FixedMatCapUV(normalWS);
    half2 backUV = FixedMatCapUV(-normalWS);

    half3 front = SAMPLE_TEXTURE2D(matcapTex, samplerMatcapTex, frontUV).rgb;
    half3 back = SAMPLE_TEXTURE2D(matcapTex, samplerMatcapTex, backUV).rgb;

    half backWeight = saturate(matcapBackBlend);
    half3 matcap = lerp(front, back, backWeight);
    half fresnelWeight = lerp(1.0h, surface.fresnel, saturate(matcapFresnel));
    return matcap * matcapColor.rgb * fresnelWeight;
}
```

实现备注：

- `MatCap Direction` 默认可以是世界空间 `(0, 0, 1)` 或项目主光/角色前方。
- `MatCap Up` 默认 `(0, 1, 0)`。
- 如果选择 Local 空间，就把 `Direction/Up` 从 object 转到 world，或者直接把 normal 转到 object 空间后采样。
- 正面/背面混合比直接用 view-space MatCap 更稳定，适合宝石内部折射感。
- 如果背面太糊，`MatCap Back Blend` 默认设低一些，例如 `0.25`。

### Lighting

Lighting 依然需要拆清楚。Inspector 可以放在一个 `Lighting` foldout 里，但用空行分段：

环境：

- Environment Strength
- Direct Light Strength
- Indirect Strength
- SSAO Strength
- SSAO Tint

阴影：

- Shadow Strength
- Shadow Border
- Shadow Blur
- Shadow Receive Offset
- Shadow Cast Strength
- Shadow Caster Offset
- Shadow Ramp

高光：

- Highlight Strength
- Highlight Sharpness
- Highlight Color

反射：

- Reflection Strength
- Reflection Fresnel
- Reflection Roughness

注意：不透明假宝石阶段，Lighting 不做折射输出。折射只作为 `Internal Field & Glow` 的内部 raymarch 采样方向存在。真正的可见折射、背景扭曲、透射和焦散放到后续 `CrystalGemTransparent.shader`。

### Advanced

- Cull
- ZWrite
- 可选 debug mode：Field、Glow、Fibers

## 强度开关规则

所有参与最终合成的组分必须有独立强度开关。第一版使用普通数值属性，不引入 shader keyword，避免增加变体。

建议范围：

- `Field Strength`：`0..4`，控制静态内部场输出强度。
- `Glow Strength`：`0..8`，控制发光输出，可保留 HDR 余量。
- `Fiber Strength`：`0..1` 或 `0..4`，控制动态絮状输出。
- `MatCap Strength`：`0..4`。
- `Environment Strength`：`0..4`。
- `Shadow Strength`：`0..1`。
- `Highlight Strength`：`0..8`。
- `Reflection Strength`：`0..1`。

合成强度尽量在 `CrystalShade` 附近显式体现。组分函数可以内部早退优化，例如 strength <= 0 时返回 0，但最终合成处仍应一眼看得出每层贡献。

## 组分函数规划

主实现文件里按这个顺序写函数。每个组分一个函数，函数之间只传必要的数据。

```hlsl
CrystalSurface CrystalResolveSurface(Varyings input, half4 mainTex);
CrystalInternalField CrystalTraceInternalField(Varyings input, CrystalSurface surface);
half3 CrystalGlow(CrystalSurface surface, CrystalInternalField field);
half3 CrystalDynamicFibers(Varyings input, CrystalSurface surface, CrystalInternalField field);
half3 CrystalMatCap(Varyings input, CrystalSurface surface);
half3 CrystalEnvironment(Varyings input, CrystalSurface surface, LightingData lighting);
half CrystalShadow(Varyings input, CrystalSurface surface, LightingData lighting);
half3 CrystalHighlight(Varyings input, CrystalSurface surface, LightingData lighting);
half3 CrystalReflection(Varyings input, CrystalSurface surface);
half3 CrystalShade(Varyings input, CrystalSurface surface);
```

只在确实复用时抽 helper，例如：

- `Fresnel(...)`
- `Rotate2(...)`
- `ClampRange(...)`
- `ResolveRefractionNoise(...)`

如果某段逻辑只被一个组分使用，就放在该组分函数内部，不提前抽接口。

## 合成方式

最终合成保持简单，尽量一眼看懂。

推荐逻辑：

```hlsl
CrystalInternalField field = CrystalTraceInternalField(input, surface);

half3 environment = CrystalEnvironment(input, surface, lighting);
half shadow = CrystalShadow(input, surface, lighting);
half3 litBase = ShadeBaseLighting(input, surface, lighting) * shadow;

half3 matcap = CrystalMatCap(input, surface);
half3 glow = CrystalGlow(surface, field);
half3 fibers = CrystalDynamicFibers(input, surface, field);
half3 highlight = CrystalHighlight(input, surface, lighting);
half3 reflection = CrystalReflection(input, surface);

half3 color = litBase;
color += environment * environmentStrength;
color += matcap * matcapStrength;
color += glow * glowStrength;
color += fibers * fiberStrength;
color += highlight * highlightStrength;
color += reflection * reflectionStrength;
return max(color, 0);
```

如果某个组分需要受基础内部场约束，就在组分内部直接乘：

```hlsl
fibers *= field.fieldMask;
glow *= glowMask;
```

不需要建立复杂的 component graph，也不需要专门做一堆接口层。

## 三块功能的合并结论

建议把 `Refraction Scattering`、`Internal Impurities 2`、`Gem Glow` 合成一个 Inspector 组：`Internal Field & Glow`。

具体做法：

- `Refraction Scattering` 改成 `Internal Field & Glow` 里的光路参数。
- `Internal Impurities 2` 改成 `Internal Field & Glow` 的静态密度采样。
- `Gem Glow` 改成同一组里的发光输出参数，只用 `fieldMask` 加 thickness、edge、Fresnel 算 glow mask。
- `Gem Internal Impurities` 改成 `Dynamic Fibers`，沿用旧动态内部体积算法，只做动态絮状层。

这样调参关系更清楚：

- 调 Internal Field & Glow 的前半段：改变内部静态结构和 glow 遮罩来源。
- 调 Internal Field & Glow 的后半段：只改变发光颜色、强度、对比。
- 调 Dynamic Fibers：只改变动态絮状杂质。

## 代码实现步骤

### Step 1：建立新 shader 骨架

- 新增 `CrystalGemComposite.shader`。
- 新增 `crystal_gem_composite_core.hlsl`。
- 默认使用 `RenderType = Opaque`、`Queue = Geometry`、`ZWrite On`、`Blend Off`。
- 先实现 Surface、ShadowCaster、DepthOnly、DepthNormals。
- 新 shader 验收后删除旧 `CrystalMatCapParallaxGem8.shader`。

### Step 2：搬 Surface

- 从旧 shader 迁移主贴图、mask、normal、tint、Fresnel。
- 内部变量用简单名。
- 确认 alpha cutoff 和正反面 normal 正确。

### Step 3：做 Internal Field & Glow

- 以 `CrystalRayM_8Samples.hlsl` 为参考，把 8 步 raymarch 搬进 `CrystalTraceInternalField`。
- 把 BetterCrystals 的 `LinearMask*` 简化成可选 `Style Fade`，默认关闭，不作为核心宝石组分。
- 保持 main/secondary 的参考公式和权重，先不要改成完全自拟的 field 算法。
- 在 raymarch 后补 `Noise 2 Intersect`，输出 `fieldMain`、`fieldSecondary`、`fieldMask`、`coreMask`。
- 把 refraction surface noise 采样放进这个函数，语义按 BetterCrystals 的 enabled/negate/clamp。
- `CrystalGlow(surface, field)` 只消费 field。
- Glow mask = core mask * thickness 权重 + edges emission + Fresnel ramp shaping。
- Glow ramp、tint、power、contrast、ramp main mask exp、ramp fresnel exp 只影响 glow 输出。

### Step 4：接入 Dynamic Fibers

- 沿用旧内部杂质代码里的内部射线、flow 和 procedural 累积。
- 不把 Dynamic Fibers 作为本轮主要重写对象。
- 用 `field.fieldMask` 限制显示范围。

### Step 5：MatCap、Lighting 细分和最终合成

- 每个组分一个函数。
- MatCap 使用标准 view-space normal 采样，不再做固定 world/local 方向和 front/back 双采样混合。
- Lighting 内部至少拆成 `CrystalEnvironment`、`CrystalShadow`、`CrystalHighlight`、`CrystalReflection`。
- 每个进入最终合成的组分都有独立 strength，且在 `CrystalShade` 附近能看到相乘关系。
- `CrystalShade` 里直接加加加。
- 只保留必要的 clamp/saturate。

## 验收标准

- 新 shader 能在 Unity 导入并编译。
- 新 shader 第一版是不透明假宝石：`Opaque/Geometry/ZWrite On/Blend Off`。
- 不引入真正透明队列、透明混合或透明排序依赖。
- 旧 `CrystalMatCapParallaxGem8.shader` 和专属 include 已删除；新 shader 不依赖旧 raymarch/include 链路。
- `Internal Field & Glow`、`Dynamic Fibers` 两组调参互不污染。
- Dynamic Fibers 第一版不重写算法，只接入新的最终 additive 合成。
- `Fiber Strength = 0` 时没有动态絮状。
- `Glow Strength = 0` 时没有发光，但 Internal Field 仍可单独显示；Dynamic Fibers 与 Field/Glow 不互相污染。

## 当前落地实现

第一版已经按低文件数方案落地：

- `Shaders/CrystalGemComposite.shader`
- `Shaders/crystal_gem_composite_core.hlsl`

当前 shader 菜单为 `lilPBR/Crystal/Gem Composite`。SubShader 明确使用不透明队列：

```shaderlab
"RenderType" = "Opaque"
"Queue" = "Geometry"
Blend Off
ZWrite On
```

当前没有 include `crystal_raymarch.hlsl`，也没有调用 `CrystalRaymarch8`。`Internal Ray Bend` 只影响内部场采样方向，不做可见背景折射输出。

实现函数对应关系：

- Surface：`GemResolveSurface`
- Internal Field：`CrystalInternalField`
- Field + Glow 输出：`CrystalResolveFieldGlow`
- MatCap：`CrystalMatCap`
- Dynamic Fibers：`CrystalDynamicFibers`
- Environment：`CrystalEnvironment`
- Shadow 合成：`CrystalShadow`
- Highlight：`CrystalHighlight`
- Reflection：`CrystalReflection`
- 最终合成：`CrystalGemComposite`

最终合成当前保持直接加法：

```hlsl
color += CrystalEnvironment(surface, components.baseLayer, lighting);
color += GemDirectLights(input, surface, components.baseLayer, lighting);
color = CrystalApplyMatCapBlend(color, components.matCap);
color += components.fieldGlow;
color += components.dynamicFibers;
color += CrystalHighlight(input, surface, lighting);
color += CrystalReflection(input, surface);
```

MatCap 叠加模式当前支持 `Add / Multiply / Screen`。

强度开关当前对应：

- Internal Field：`_FieldStrength`
- Glow：`_GlowStrength`
- MatCap：`_MatCapStrength`
- Dynamic Fibers：`_FiberStrength` 与 `_FiberBrightness`
- Environment：`_EnvironmentStrength`
- Direct Light：`_DirectLightStrength`
- Shadow：`_ShadowStrength` / `_ShadowCastStrength`
- Highlight：`_HighlightStrength`
- Reflection：`_ReflectionStrength`
- 每个组分的 Strength = 0 时，该组分没有最终贡献。
- Field 采样参数改变静态内部结构，也同步影响 glow mask；`Field Strength` 与 `Glow Strength` 分别控制最终输出。
- `Internal Field & Glow` 至少能分出 noise 2 intersect、thickness emission、edges emission、ramp/fresnel shaping，不再只是单层噪声 ramp。
- `Style Fade Strength = 0` 时，方向渐隐完全不影响默认宝石效果。
- MatCap 使用标准 view-space normal 采样，支持 `Add / Multiply / Screen`，不保留固定方向或 front/back 混合。
- 最终合成代码保持短而直白。
