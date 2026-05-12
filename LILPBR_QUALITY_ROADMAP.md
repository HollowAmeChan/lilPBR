# lilPBR Quality Roadmap

> 目标：把 lilPBR 作为 PBR、场景材质和共享 URP 管线功能的主战场。lilToon 侧已经验证过的 SSAO、Fake SSS、透明/OIT 方向，优先迁到 lilPBR，再把共享接口反向同步给 lilToon。

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

## 3. P0 首要目标

| 功能 | 目标 | 同步到 lilToon |
| --- | --- | --- |
| SSAO Receiver / Toon Remap | 接 URP SSAO，并提供 NPR 友好的 min/max、threshold、direct/indirect strength | 同名参数和采样/remap 规则 |
| Fake SSS / Thickness SSS | 迁移 lilToon 已验证的 thickness/rim/shadow 经验，增强皮肤、蜡、薄物体 | thickness 贴图语义和 UI 命名 |
| Weighted OIT | 解决透明、玻璃、头发、衣料排序问题 | 共享 Renderer Feature 和材质 OIT mode |

推荐顺序：

```text
SSAO Receiver / Toon Remap
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

- 先定义共享语义：例如 `_UseSSAO`、AO remap、SSS thickness、OIT mode 的含义要一致。
- lilPBR 可以拥有更完整的 PBR 参数；lilToon 只同步角色确实需要的入口。
- 管线功能优先抽成共享 Renderer Feature 或保持同名设置，避免两边各写一套不可互通的实现。
- 每做一个 P0/P1 功能，都补一段“lilToon 同步点”和“lilPBR 私有点”。
- 不把 lilToon 的 `.lilinternal/.lilblock` 生成架构搬到 lilPBR。

---

## 7. 首轮实施切片

1. SSAO：在 lilPBR 的 `unity_urp.hlsl` / `pbr_core.hlsl` 接 `_ScreenSpaceOcclusionTexture`，加 Toon Remap 属性和 keyword。
2. SSS：梳理 lilToon Fake SSS workflow，把 thickness/rim/back light 逻辑落到 lilPBR 的现有 `_SUBSURFACE` 分支。
3. OIT：先设计共享 URP Renderer Feature 的 RT、pass、composite，再给 lilPBR transparent 输出接入。
4. 回同步：把 SSAO/OIT/SSS 的共享字段写回 lilToon roadmap，必要时再改 lilToon shader。
