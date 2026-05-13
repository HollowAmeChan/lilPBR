# lilPBR Quality Roadmap

## 0.1 2026-05-14 Planar Reflection

- lilPBR shader adds a `Planar Reflection` material entry that samples `_LILPBRPlanarReflectionTexture` and blends it with environment reflection by smoothness, edge fade, and tint.
- The rendering side lives in `lilToon-URP-Extensions/Runtime/PlanarReflection/LILPlanarReflectionSurface.cs`.
- SSR remains a cheap fallback; flat mirror floors, polished floors, and water sheets should use Planar Reflection first.
- Pipeline code stays in the shared URP extensions package instead of the lilPBR material package.

> 目标：把 lilPBR 作为 PBR、场景材质和共享 URP 管线功能的主战场。lilToon 侧已经验证过的 Screen Space AO、Fake SSS、透明/OIT 方向，优先迁到 lilPBR，再把共享接口反向同步给 lilToon。

## 0. 2026-05-14 HTrace AO / SSGI 路线更新

HTrace AO 与 HTrace SSGI 已进入实际项目后，lilPBR 的近期重点需要调整：

- **P0：HTrace AO 接收端**。HTrace AO 的 SSAO / GTAO / RTAO 都输出为屏幕空间 AO，lilPBR 不关心算法名，只关心 `_HTraceBufferAO` 或 `_ScreenSpaceOcclusionTexture` 的采样和 PBR 混合语义。
- **P0：与 lilToon 同名参数**。`Screen Space AO` 的强度、direct/indirect、remap、contrast、mask 要与 lilToon 对齐，避免双仓 UI 漂移。
- **P1：AO 与 PBR 语义分层**。lilPBR 默认让 AO 主要影响 indirect diffuse、cavity 与可选 reflection occlusion；direct AO 默认为较低强度，避免直射区域变脏。
- **P1：SSGI 暂不进普通材质面板**。HTrace SSGI 是全屏间接光注入。当前优先在 HoUrp/HTrace pass 层解决 MSAA camera color 采样警告；lilPBR 后续只需要接收强度/金属 fallback 等轻量策略。

---

## 1. 仓库定位

lilPBR 当前不是 lilToon 的生成式架构。它直接维护：

- `Shaders/lilPBR.shader`
- `Shaders/lilPBR_Tessellation.shader`
- `Shaders/pbr_core.hlsl`
- `Shaders/pbr.hlsl`
- `Shaders/unity_urp.hlsl`
- `Shaders/unity_birp.hlsl`
- `Editor/PBRShaderGUI.cs`

因此后续新增功能不需要走 `.lilinternal/.lilblock` 生成链，适合快速做 PBR 和 URP Renderer Feature 实验。

---

## 2. 当前已有能力

- URP + Built-in 双管线 SubShader。
- Opaque / Cutout / Dither / Transparent。
- Packed / Separate PBR Map。
- Metallic、Occlusion、Height、Smoothness。
- Normal、POM、Vertex displacement。
- Emission、Subpixel emission。
- Anisotropy、Clear Coat、Cloth。
- Fake Translucent、Subsurface Scattering。
- Screening、4 层 Detail、Wetness / Rain。
- Wind、Distance Fade、VRChat 显隐。
- ShadowCaster、DepthOnly、DepthNormals、Meta、MotionVectors、XRMotionVectors。
- Tessellation 版本和 Water shader。

---

## 2.5 Blender / OpenPBR 输入标准化

目标不是把 lilPBR 内部 BSDF 改成 Blender 或 OpenPBR 的完整实现，而是在材质输入侧提供一个稳定的兼容层：

```text
Blender / OpenPBR / glTF / Substance / Unity MaskMap 输入
  -> lilPBR 输入规范化层
  -> 现有 lilPBR ShadingParams
     albedo / metallic / occlusion / smoothness / height / normal / emission
```

### 设计原则

- 保持旧材质语义：现有 `_TextureMode`、`_PBRMap`、`_MetallicChannel`、`_OcclusionChannel`、`_HeightChannel`、`_SmoothnessChannel`、`_Glossiness` 继续可用。
- 新增输入接口只做解释和转换，不直接改变 lighting core。
- 对外优先使用 Blender / OpenPBR 习惯的 `Roughness`，shader 内部再转成 lilPBR 现有 `Smoothness`。
- Packed map 必须有 preset，避免每个资产手动猜通道。
- 颜色贴图按 sRGB 导入，mask / ORM / roughness / metallic / AO / height 按 Linear 导入，normal 按 Normal Map 导入。
- 未实现完的接口允许先保留，但必须标记为 Reserved / Experimental，并默认不影响现有材质输出。

### Reserved / Experimental 接口规则

改造期间允许先占位 Blender / OpenPBR 兼容接口，但要避免“面板上看起来可用，实际没有效果”的状态。

| 接口状态 | Shader 属性 | Inspector | 行为要求 |
| --- | --- | --- | --- |
| Stable | 正式属性名 | 正常显示 | 必须完整参与采样、转换、lighting 或后处理 |
| Experimental | 正式属性名 + Experimental 标记 | 可显示，但要有分组说明 | 可以只覆盖部分 pass，但必须有 fallback |
| Reserved | `_Reserved*` 或正式属性名但 `[HideInInspector]` | 默认隐藏 | 不参与输出，只用于材质序列化和未来迁移 |
| Deprecated | 旧属性名保留 | 可隐藏或只读迁移 | 读取旧材质，不再作为新工作流入口 |

Reserved 接口建议：

```text
_PBRInputPreset          // 输入 preset：Legacy / UnityMaskMap / ORM / MRA / Separate
_SmoothnessSource        // Smoothness 或 Roughness 语义
_RoughnessRemap          // roughness min/max 或 curve 预留
_IOR                    // OpenPBR / Blender IOR 输入，未来转换到 reflectance
_SpecularWeight          // OpenPBR specular weight 预留
_CoatRoughnessSource     // clear coat roughness/smoothness 语义
_EmissionStrength        // Blender emission strength 映射
_TransmissionWeight      // 未来玻璃/薄物体 transmission
_ThicknessMap            // 未来 SSS / transmission thickness
_CavityMap               // 未来 micro AO / cavity
_BentNormalMap           // 未来 reflection occlusion / bent normal
```

代码约束：

- Reserved 属性可以先进入 `.shader`，但默认值必须等价于旧材质行为。
- 如果属性还没有接进 `pbr_core.hlsl`，优先 `[HideInInspector]`，不要放在普通用户工作流区域。
- 真正生效前不要删除旧 `_PBRMap` packed 逻辑。
- 新增 HLSL helper 可以先落空实现，例如 `ApplyOpenPBRReservedInputs()`，但必须返回未修改的 `ShadingParams`。
- 每个 Reserved 接口转 Stable 时，要补材质迁移说明和一个 preset 验证场景。

### 推荐外部参数命名

| Blender / OpenPBR 概念 | lilPBR 内部字段 | 说明 |
| --- | --- | --- |
| Base Color / `base_color` | `_MainTex * _Color` / `p.albedo` | 作为 diffuse、metal、transmission 的主色 |
| Metallic / `base_metalness` | `_Metallic` / `p.metallic` | 金属度，旧 `_Metallic` 继续作为强度乘数 |
| Roughness / `specular_roughness` | `1 - p.smoothness` | 新接口以 Roughness 为外部语义，内部转换为 Smoothness |
| IOR / `specular_ior` | `_Reflectance` 或未来 `_IOR` | 当前 lilPBR 用 reflectance，后续可加 IOR 到 reflectance 转换 |
| Alpha / opacity | `p.alpha` / render mode | 与 Opaque、Cutout、Transparent、OIT 关联 |
| Normal | `_BumpMap` | 保持 Unity normal map 语义 |
| Emission | `_EmissionMap * _EmissionColor` | 与 Blender emission color/strength 可做 editor 映射 |
| Coat Weight / Coat Roughness | `_ClearCoat` / `_ClearCoatSmoothness` | 外部 roughness 输入需转换为 clear coat smoothness |
| Sheen / Fuzz | `_Cloth` 或未来 `_Fuzz` | 当前可近似到 Cloth，长期建议独立 Fuzz |

### Packed Map preset

| Preset | 通道语义 | lilPBR 转换 |
| --- | --- | --- |
| Legacy lilPBR / Unity MaskMap | R Metallic, G AO, B Height, A Smoothness | 直接进入现有通道 |
| glTF / Blender ORM | R AO, G Roughness, B Metallic | AO=R, Metallic=B, Smoothness=`1-G` |
| ARM | R AO, G Roughness, B Metallic | 同 ORM，只是命名不同 |
| MRA | R Metallic, G Roughness, B AO | Metallic=R, AO=B, Smoothness=`1-G` |
| Separate Roughness | Metallic/AO/Height/Roughness 分贴图 | Smoothness=`1-Roughness` |
| Separate Smoothness | Metallic/AO/Height/Smoothness 分贴图 | 保持旧逻辑 |

### 首轮落地切片

1. Shader 属性：新增 `_PBRInputPreset`、`_SmoothnessSource` 或 `_InvertSmoothness`，默认保持旧行为。
2. `pbr_core.hlsl`：把 PBR map 采样集中成 `SamplePBRInputs()`，统一处理 roughness-to-smoothness。
3. `PBRShaderGUI.cs`：增加 Blender/OpenPBR/glTF/Unity MaskMap preset 按钮。
4. Editor 工具：按文件名自动接贴图，例如 `_BaseColor`、`_Normal`、`_ORM`、`_Roughness`、`_Metallic`、`_AO`、`_Height`。
5. 导入检查：提示 ORM/Roughness/AO/Metallic/Height 贴图关闭 sRGB，Normal 设为 normal map。

---

## 3. P0 首要目标

| 功能 | 目标 | 同步到 lilToon |
| --- | --- | --- |
| HTrace / URP Screen Space AO Receiver | 接 `_HTraceBufferAO` 与 `_ScreenSpaceOcclusionTexture`，并提供 NPR/PBR 友好的 min/max、threshold、direct/indirect strength | 同名参数和采样/remap 规则 |
| Fake SSS / Thickness SSS | 迁移 lilToon 已验证的 thickness/rim/shadow 经验，增强皮肤、蜡、薄物体 | thickness 贴图语义和 UI 命名 |
| Weighted OIT | 解决透明、玻璃、头发、衣料排序问题 | 共享 Renderer Feature 和材质 OIT mode |

推荐顺序：

```text
HTrace / URP Screen Space AO Receiver
Fake SSS / Thickness SSS
Weighted OIT
```

---

## 4. P1 质量提升

| 功能 | 目标 |
| --- | --- |
| Glass / Mirror | Thickness、absorption、rough refraction、planar/probe reflection override |
| Stylized Reflection / SSR | reflection remap、roughness remap、SSR fallback 到 probe |
| Contact / Micro Shadow | AO/curvature/detail mask 控制的微阴影，之后再接 screen-space contact shadow |
| NPR Shadow / AO Remap | 让 PBR 场景能和 lilToon 角色有统一阴影色调 |

---

## 5. P2 场景生态

| 功能 | 目标 |
| --- | --- |
| NPR Decal / Dirt Layer | 污渍、划痕、贴纸、边缘磨损 |
| Detail AO / Bent Normal | 提升间接光、反射遮蔽和场景细节可信度 |
| Shadow Ramp Atlas | 统一角色和场景的 shadow ramp 风格 |
| Lighting Volume | 按区域控制 AO、shadow、reflection、fog、SSS 等参数 |

---

## 6. 双仓同步规则

- 先定义共享语义：例如 `_UseScreenSpaceAO`、AO remap、SSS thickness、OIT mode 的含义要一致；旧 `_UseSSAO` 不再作为入口。
- lilPBR 可以拥有更完整的 PBR 参数；lilToon 只同步角色确实需要的入口。
- 管线功能优先抽成共享 Renderer Feature 或保持同名设置，避免两边各写一套不可互通的实现。
- 每做一个 P0/P1 功能，都补一段“lilToon 同步点”和“lilPBR 私有点”。
- 不把 lilToon 的 `.lilinternal/.lilblock` 生成架构搬到 lilPBR。

---

## 7. 首轮实施切片

1. Screen Space AO：在 lilPBR 的 `unity_urp.hlsl` / `pbr_core.hlsl` 同时接 `_HTraceBufferAO` 与 `_ScreenSpaceOcclusionTexture`，加 remap 属性和 keyword。
2. SSS：梳理 lilToon Fake SSS workflow，把 thickness/rim/back light 逻辑落到 lilPBR 的现有 `_SUBSURFACE` 分支。
3. OIT：先设计共享 URP Renderer Feature 的 RT、pass、composite，再给 lilPBR transparent 输出接入。
4. 回同步：把 Screen Space AO/OIT/SSS 的共享字段写回 lilToon roadmap，必要时再改 lilToon shader。
