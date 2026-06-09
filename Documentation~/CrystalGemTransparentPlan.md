# Crystal Gem Transparent Basic URP Plan

## 目标

新增一个轻量透明宝石 shader。首版只做 URP 基础折射与色散，避免依赖复杂渲染管线功能。Built-in 版本暂不实现，只保留后续扩展余地。

核心功能：

- 透明混合。
- 背景颜色采样。
- 屏幕空间折射。
- RGB 色散。
- MatCap。
- Internal Field And Glow。
- Dynamic Fibers。
- 基础 Fresnel 反射。
- 简单高光。

明确不做：

- OIT。
- URP Renderer Feature。
- 自定义相机颜色拷贝 pass。
- 透明 depth prepass。
- 多层透明排序专项。
- receiver caustics，也就是投射到地面或其他物体上的焦散。
- 多次折返 ray tracing。
- 高成本粗糙折射模糊。
- 新增复杂内部 raymarch。现有内部场和絮状模块可以复用，但不在透明版里重写成更复杂的方案。

## 文件结构和代码风格

首版跟当前 `CrystalGemComposite.shader` 一样，保持一个 shader 入口加一个 core include，不提前做管线适配层或抽象框架。

- `Shaders/CrystalGemTransparent.shader`
  - Shader menu: `lilPBR/Crystal/Gem Transparent`
  - 统一 Properties。
  - 首版只包含 URP SubShader：`"RenderPipeline" = "UniversalPipeline"`。
  - 放 Properties、texture/sampler、CBUFFER、pass 声明。

- `Shaders/crystal_gem_transparent_core.hlsl`
  - 放 vertex、surface resolve、背景折射、色散、MatCap、内部场、动态絮状、反射/高光和最终 fragment。
  - 直接使用 URP helper，例如 `GetNormalizedScreenSpaceUV(...)`、`SampleSceneColor(...)` 或现有 `unity_urp.hlsl` helper。
  - 不创建 `common/urp` 两层 include。

暂不新增 Built-in include。等 URP 版本稳定后，再单独评估是否拆出共享 core。

代码风格要求：

- 函数拆分跟现有 shader 一样，一块视觉组分一个函数。
- 命名简单直白，不做复杂 interface、strategy、adapter 命名。
- 数据结构保持少量：`GemSurface`、`GemComponents` 这类直观结构即可。
- 组分合成用顺序代码表达，不做节点图式框架。
- 可复用 helper 才抽出来；只调用一次且很短的逻辑可以留在组分函数里。

推荐最终合成形态：

```hlsl
half3 color = CrystalRefraction(input, surface);
color = CrystalApplyMatCapBlend(color, components.matCap);
color += components.fieldGlow;
color += components.dynamicFibers;
color += CrystalReflection(input, surface);
color += CrystalHighlight(input, surface);
return half4(max(color, 0.0h), alpha);
```

这和现在的不透明版保持同一种阅读方式：先解析 surface，再算 components，最后逐项合成。

URP 首版依赖：

- 通过 `_CameraOpaqueTexture` / `SampleSceneColor` 采样背景。
- 需要项目开启 URP Opaque Texture。
- 不做额外 Renderer Feature。

## 渲染状态

首版统一使用普通透明混合。

```shaderlab
Tags
{
    "RenderType" = "Transparent"
    "Queue" = "Transparent-100"
    "IgnoreProjector" = "True"
}

ZWrite Off
Blend SrcAlpha OneMinusSrcAlpha
Cull [_Cull]
```

说明：

- `Transparent-100` 参考 lilToon Gem，让折射宝石比普通透明稍早绘制。
- `ZWrite Off` 保持普通透明行为，避免一开始引入 depth prepass 的排序副作用。
- 不做 ShadowCaster，避免透明宝石投出实心阴影。
- 不做 DepthOnly / DepthNormals，首版先保证折射和色散稳定。

## 参考 lilToon Gem

参考文件：

- `D:/Unity_Fork/lilToon/Assets/lilToon/Shader/lts_gem.shader`
- `D:/Unity_Fork/lilToon/Assets/lilToon/Shader/Includes/lil_pass_forward_gem.hlsl`
- `D:/Unity_Fork/lilToon/Assets/lilToon/Shader/Includes/lil_common_frag.hlsl`

只借鉴这些点：

- `Queue = Transparent-100`。
- `_RefractionStrength` 控制背景采样偏移。
- `_RefractionFresnelPower` 控制边缘折射增强。
- `_GemChromaticAberration` 的 RGB 分离采样思路。
- `_GemEnvContrast` / `_GemEnvColor` 对折射背景和反射做简单强化。

不照搬：

- lilToon 的宏系统。
- toon lighting、rim、outline、完整 MatCap 栈。
- refraction blur 多采样。
- gem particle 复杂内部亮点。

## 折射与色散

首版使用屏幕空间折射，不做真实多次折返。

core 里的核心逻辑：

```hlsl
float3 viewDirWS = normalize(_WorldSpaceCameraPos - positionWS);
float eta = 1.0 / max(_IOR, 1.001);
float3 refractDirWS = refract(-viewDirWS, normalWS, eta);
float2 refractOffset = mul((float3x3)UNITY_MATRIX_V, refractDirWS).xy;
float fresnel = pow(saturate(1.0 - dot(normalWS, viewDirWS)), _RefractionFresnelPower);
float2 offset = refractOffset * _RefractionStrength * fresnel;
```

RGB 色散：

```hlsl
float2 uvR = screenUV + offset;
float2 uvG = screenUV + offset * (1.0 + _ChromaticAberration * 0.5);
float2 uvB = screenUV + offset * (1.0 + _ChromaticAberration);

half3 refracted;
refracted.r = SampleSceneColor(uvR).r;
refracted.g = SampleSceneColor(uvG).g;
refracted.b = SampleSceneColor(uvB).b;
```

参数：

- `_Opacity`
- `_IOR`
- `_RefractionStrength`
- `_RefractionFresnelPower`
- `_ChromaticAberration`
- `_RefractionTint`
- `_RefractionContrast`

默认值建议：

- `_Opacity = 0.45`
- `_IOR = 1.45`
- `_RefractionStrength = 0.04`
- `_RefractionFresnelPower = 1.0`
- `_ChromaticAberration = 0.015`
- `_RefractionContrast = 1.2`

## 表面与反射

透明版的表面颜色只做弱 tint，主要视觉来自背景折射和 Fresnel 反射。

保留基础属性：

- `_BaseColor`
- `_MainTex`
- `_MaskTex`
- `_NormalMap`
- `_NormalStrength`
- `_SphericalNormalBlend`
- `_FresnelPower`

新增透明版属性：

- `_BaseTintStrength`
- `_Smoothness`
- `_ReflectionStrength`
- `_ReflectionTint`
- `_HighlightStrength`
- `_HighlightSharpness`

合成方向：

```hlsl
half3 color = refracted * _RefractionTint.rgb;
color = GemApplyContrast(color, _RefractionContrast);
color = lerp(color, color * baseColor.rgb, _BaseTintStrength);
color += reflection * fresnel * _ReflectionStrength;
color += highlight * _HighlightStrength;

half alpha = saturate(_Opacity * baseAlpha);
return half4(color, alpha);
```

反射实现保持简单：首版优先用当前 URP helper 或 reflection probe。若接入成本偏高，可以先做 Fresnel tint，让高光和折射先跑通。

## 组分合成顺序

透明版最终合成保持直白，不做复杂混合系统。

建议顺序：

1. `CrystalRefraction(...)` 得到背景折射色，作为主色。
2. `_BaseColor` 和 `_MainTex` 只做弱 tint。
3. `CrystalApplyMatCapBlend(...)` 叠 MatCap。
4. `CrystalResolveFieldGlow(...)` 输出的 field/glow 直接加到内部。
5. `CrystalDynamicFibers(...)` 作为内部絮状加到内部。
6. `CrystalReflection(...)` 加 Fresnel 环境反射。
7. `CrystalHighlight(...)` 加简单高光。

不要为每个组分再做统一权重表、blend graph 或 node-style dispatcher。每个组分自己的 strength 参数就是开关和权重。

伪代码：

```hlsl
GemComponents components = CrystalGemResolveComponents(input, surface);

half3 color = CrystalRefraction(input, surface);
color = lerp(color, color * surface.baseColor, saturate(_BaseTintStrength));
color = CrystalApplyMatCapBlend(color, components.matCap);
color += components.fieldGlow;
color += components.dynamicFibers;
color += CrystalReflection(input, surface);
color += CrystalHighlight(input, surface);

return half4(max(color, 0.0h), surface.alpha * _Opacity);
```

## 现有模块复用判断

当前 `CrystalGemComposite.shader` 里有几块可以直接复用，透明版不需要重写。

### MatCap

可直接搬，属于最稳的一块。

需要带上的内容：

- `_MatCapTex`
- `_MatCapColor`
- `_MatCapStrength`
- `_MatCapFresnel`
- `_MatCapBlendMode`
- `CrystalMatCap(...)`
- `CrystalApplyMatCapBlend(...)`

透明版里的改动：

- 输入仍然是 `GemSurface`。
- UV 仍用 view-space normal。
- 合成对象从不透明 base color 改为折射后的 `color`。
- 默认建议使用 Add 或 Screen。Multiply 对透明折射背景容易变脏，但可以保留给调参。

### Internal Field And Glow

可以大部分直接搬，但要把它当作透明体积里的内部亮度层，而不是表面颜色处理。

需要带上的内容：

- `_VolumeNoise`
- `_GlowRamp`
- `_SurfaceNoise`
- `_FieldStrength`
- `_GlowStrength`
- `_VolumeSpace`
- `_VolumeOffset`
- `_StepLength`
- `_VolumeNoiseScale`
- `_VolumeMainPower`
- `_VolumeMainMultiply`
- `_VolumeSecondaryPower`
- `_VolumeSecondaryMultiply`
- `_VolumeSecondaryIntersect`
- `_FieldMaskPower`
- `_FieldStepFade`
- `_InternalRayBend`
- `_UseSurfaceNoise`
- `_SurfaceNoiseScale`
- `_SurfaceNoiseStrength`
- `_SurfaceNoiseParallax`
- `_GlowTint`
- `_GlowContrast`
- `_GlowThicknessWeight`
- `_GlowEdgeWeight`
- `_GlowFresnelWeight`
- `GemResolveVolumeSpace(...)`
- `GemRefractionSurfaceNoise(...)`
- `CrystalInternalField(...)`
- `CrystalGlowMask(...)`
- `CrystalResolveFieldGlow(...)`

透明版里的改动：

- `GemResolveSurface(...)` 仍然计算 `fieldMain`、`fieldSecondary`、`fieldMask`、`edges`、`thickness`。
- `fieldGlow.field + fieldGlow.glow` 在透明合成中作为 additive internal contribution。
- 可以乘一个透明版权重，例如 `lerp(1, surface.thickness, _InternalThicknessWeight)`，但首版可以先直接使用现有 `_FieldStrength` 和 `_GlowStrength`。
- `Refraction And Surface Noise` 这组参数可以继续保留，因为内部场和动态絮状都在用它。

### Dynamic Fibers

可以直接搬核心算法，代价是保留现有 24 步循环。这个模块已经是独立体积层，不依赖不透明直射光。

需要带上的内容：

- `_FiberStrength`
- `_FiberBrightness`
- `_FiberFresnel`
- `_FiberFlowSpeed`
- `_FiberFlowStrength`
- `_FiberFlowPhase`
- `_FiberSpace`
- `_FiberOffset`
- `_FiberMode`
- `_FiberScale`
- `_FiberDepth`
- `_FiberSharpness`
- `_FiberMainColor`
- `_FiberSecondaryColor`
- `_FiberColorVariation`
- `FiberResolveSamplePosition(...)`
- `FiberBuildRay(...)`
- `CrystalDynamicFibers(...)`
- 以及它下面的 fiber noise / phase / density helper。

透明版里的改动：

- 输入仍然是 `GemVaryings` 和 `GemSurface`。
- 输出作为 additive internal contribution 加到折射背景之后。
- 需要保留 `_FiberStrength = 0` 的早退，默认材质可以把它关掉来节省成本。
- 后续如果要做性能档位，可以给 fiber 加 quality 开关；首版先保持和现有不透明版一致。

### 暂不迁移

这些模块先不搬：

- `Direct Light And Shadow`
- 表面颜色预处理
- Built-in SubShader / GrabPass 适配

原因：

- MatCap、内部场、絮状已经相对独立，可以复用。
- 直射光/阴影和表面颜色处理更偏不透明版。
- 共享核心越小，后续补 Built-in 时维护成本越低。

## Inspector 分组

建议分组：

- `Surface`
  - `_BaseColor`
  - `_MainTex`
  - `_MaskTex`
  - `_NormalMap`
- `Surface Normals`
  - `_NormalStrength`
  - `_SphericalNormalBlend`
  - `_FresnelPower`
- `Transparency And Refraction`
  - `_Opacity`
  - `_IOR`
  - `_RefractionStrength`
  - `_RefractionFresnelPower`
  - `_RefractionTint`
  - `_RefractionContrast`
- `Dispersion`
  - `_ChromaticAberration`
- `Reflection And Highlight`
  - `_BaseTintStrength`
  - `_Smoothness`
  - `_ReflectionStrength`
  - `_ReflectionTint`
  - `_HighlightStrength`
  - `_HighlightSharpness`
- `MatCap`
  - 沿用当前 MatCap 参数。
- `Internal Field And Glow`
  - 沿用当前二级折叠结构。
- `Dynamic Fibers`
  - 沿用当前二级折叠结构。
- `Advanced`
  - `_Cull`
  - Debug mode。

## 不透明版本保留

`CrystalGemComposite.shader` 继续保留 `Surface Preprocess` 里的表面颜色处理。透明版不搬这组参数和函数，因为透明版的表面颜色只做弱 tint，主要视觉来自背景折射、内部场、MatCap、絮状、反射和高光。

透明版不新增/不迁移：

- `_ColorProcessStrength`
- `_OuterTint`
- `_InnerTint`
- `_ThicknessTintStrength`
- `_EdgeTint`
- `_EdgeTintStrength`
- `_FresnelTintStrength`
- `_FresnelTintPower`
- `GemApplyBaseColorProcess(...)`
- `GemResolveSurface(...)` 里的 `GemApplyBaseColorProcess(masks, surface);`

这只是透明版的取舍，不要求修改不透明版。

## 实施阶段

### Phase 0: 明确模块边界

- 不透明版保留 `Surface Preprocess`。
- 透明版不搬表面颜色处理相关属性、CBUFFER 字段和 HLSL 函数。
- 保持现有 cutout alpha clip 行为。
- 统一 CRLF，避免 Unity 混合换行警告。

### Phase 1: 新建透明版入口和 core

- 新建 `CrystalGemTransparent.shader`。
- 新建 `crystal_gem_transparent_core.hlsl`。
- 先把 vertex、surface resolve、normal、Fresnel 和透明 fragment 跑通。

### Phase 2: 折射和色散

- 接入 `_CameraOpaqueTexture`。
- 实现透明混合和背景折射。
- 实现 RGB 色散。
- 如果 Opaque Texture 没开，fallback 到基础 tint/反射。

### Phase 3: 复用现有视觉模块

- 搬 MatCap。
- 搬 Internal Field And Glow。
- 搬 Dynamic Fibers。
- 透明版只调整合成顺序，不重写这些模块算法。

### Phase 4: 反射和高光

- 加 Fresnel reflection。
- 加简单 highlight。
- 直射光/阴影模块暂不搬。

### Later: Built-in SubShader

- 等 URP 版本稳定后再做。
- 优先用 `GrabPass { "_LilPBRGemBackground" }` 实现背景采样。
- 到时再决定是否把折射和色散核心抽成共享 include。
- 保持属性和 UI 与 URP 一致。

## 验收标准

首版透明宝石应满足：

- URP 下开启 Opaque Texture 后，背景能被宝石明显扭曲。
- `_IOR` 和 `_RefractionStrength` 有清楚可见的折射变化。
- `_ChromaticAberration` 能产生可控 RGB 色散。
- normal map 会改变折射方向。
- `_Opacity` 能控制不透明度。
- 不引入 OIT、Renderer Feature、depth prepass 或额外透明排序系统。
- 首版不包含 Built-in SubShader。
- 不破坏现有 `CrystalGemComposite.shader`。
- Shader 文件不出现混合换行。

## 风险

- URP 的 `_CameraOpaqueTexture` 只包含不透明物体。
- 屏幕空间折射看不到屏幕外内容。
- 多层透明宝石仍会有普通透明排序限制。
- 不做真实焦散，因此不会把光斑投射到地面或其他物体上。
- Built-in 后续需要单独补背景采样适配。

