# lilPBR URP 专用瘦身计划

## 目标

把这个 `lilPBR` fork 收敛成专供 Hollow 本地 URP 渲染流程使用的项目包。

后续不再以通用 shader 包为目标。保留服务本地 URP Renderer、HoAOV、Planar Reflection、HoShadow、HTrace/SSAO、SSS 和项目材质流程的代码路径；删除会增加导入时间、`multi_compile` 数量、编辑器刷新成本和维护面的兼容分支。

执行顺序：

1. 裁掉或确认已经裁掉非 URP 支持。
2. 裁掉 VRChat 特殊支持。
3. 优化 `multi_compile`。

## 当前快照

- `README.md` 已经声明包是 URP-only。
- 当前 shader 入口只保留 `Shaders/lilPBR.shader`。
- `Shaders/lilPBR_Tessellation.shader`、`.meta`、`Shaders/tessellation.hlsl` 和 `.meta` 已删除。该曲面细分分支不再作为项目 RP 流程的一部分。
- `Shaders/lilPBR.shader` 使用 `RenderPipeline = UniversalPipeline`，并包含 `UniversalForward`、`UniversalGBuffer`、`ShadowCaster`、`DepthOnly`、`DepthNormals`、`Meta`、`MotionVectors`、`XRMotionVectors`、`HoAOV`、`HoCharacterCapture` 等 URP pass。
- VRChat 相关残留还在：
  - `Editor/jp.lilxyzw.lilpbr.asmdef`
  - `Scripts/jp.lilxyzw.lilpbr.runtime.asmdef`
  - `Editor/ShaderModifier.cs`
  - `Scripts/ShaderLayerSetter.cs`
  - `Scripts/VolumetricFog.cs`
  - `Shaders/platform_vrchat.hlsl`
  - `Shaders/pbr_core.hlsl`
  - `Shaders/lilPBR.shader`
  - `Editor/Localization/` 下的本地化字符串
- 编译压力主要来自 Forward pass 中完整的 URP `multi_compile` 组合，以及部分 pass 中重复出现但实际不需要的 Unity pass 级 `multi_compile`。
- `LILPBR_SHADER_COMPILE_OPTIMIZATION_PLAN.md` 里已有一份偏技术细节的 pass-by-pass 编译优化计划。本文档作为这条瘦身分支的总执行顺序。

## 第一阶段：裁掉非 URP 支持

### 目的

让 URP 成为唯一支持的渲染管线。这个阶段结束后，除 Unity 必须保留的无害 fallback 以外，不应该再有 Built-in Render Pipeline、HDRP、通用管线或历史平台兼容分支。

### 任务

1. 审计所有 shader 文件中的非 URP 入口。
   - 搜索：`BuiltIn`、`builtin`、`HDRP`、`HDRenderPipeline`、`RenderPipeline`、`LightMode`、`Fallback`、`UsePass`。
   - 确认所有有效 `SubShader` 都带有 `RenderPipeline = UniversalPipeline`。
   - 确认当前 URP block 下方没有隐藏的 Built-in 或 HDRP `SubShader`。

2. 删除非 URP include 和 define。
   - 保留 `Shaders/unity_urp.hlsl` 作为唯一 Unity 管线集成层。
   - 只有确认没有引用后再删除死 include。
   - 不要因为 `pbr_core.hlsl` 是管线无关文件就删除它，它仍然是材质核心逻辑。

3. 简化文档和包元数据。
   - 更新 `README.md`，明确这个 fork 是项目 URP-only 包，不追求上游 lilPBR 通用兼容。
   - 删除暗示 Built-in/HDRP 支持的安装或兼容说明。
   - 保留 `lilToon-URP-Extensions` 和本地 URP fork 的依赖说明。

4. 删除 Tessellation 分支。
   - 已删除 `Shaders/lilPBR_Tessellation.shader` 和 `.meta`。
   - 已删除 `Shaders/tessellation.hlsl` 和 `.meta`。
   - 已从 `Shaders/pbr_properties.hlsl` 删除 `_Tess*` uniform。
   - 已删除 README、路线图、阴影模块说明和本地化中的 Tessellation 引用。
   - 项目层仍需检查是否有材质引用旧 shader；如有，迁移到 `lilPBR.shader`，并把 displacement/tessellation 参数作为废弃数据处理。

### 验收

- `rg -n "BuiltIn|builtin|HDRP|HDRenderPipeline" Shaders Editor Scripts README.md package.json` 不再命中有效支持路径。
- `Shaders/lilPBR.shader` 在 URP 下仍能编译。
- 项目中不再有材质引用 `lilPBR_Tessellation.shader`。
- 项目材质不会静默 fallback 到 missing shader。

## 第二阶段：裁掉 VRChat 特殊支持

### 目的

删除 VRChat、Udon、VRCLightVolumes、LTCGI 相关行为。这个 fork 后续只使用普通 Unity/URP 属性名和项目自有 RendererFeature。

### 任务

1. 删除 asmdef 里的 version define。
   - 从 `Editor/jp.lilxyzw.lilpbr.asmdef` 删除 `LIL_VRCHAT`。
   - 从 `Editor/jp.lilxyzw.lilpbr.asmdef` 删除 `LIL_VRCLIGHTVOLUMES`，除非项目明确还使用 `red.sim.lightvolumes`。
   - 从 `Editor/jp.lilxyzw.lilpbr.asmdef` 删除 `LIL_LTCGI`，除非项目明确还使用 `at.pimaker.ltcgi`。
   - 从 `Scripts/jp.lilxyzw.lilpbr.runtime.asmdef` 删除 `LIL_VRCHAT`。

2. 移除 VRChat shader 设置生成。
   - 简化 `Editor/ShaderModifier.cs`，不再写入 `#include "platform_vrchat.hlsl"`。
   - 如果没有其他可选包 define 需要生成：
     - 要么让 `settings.hlsl` 成为静态空 include；
     - 要么删除 `ShaderModifier.cs`，保留稳定的 include 文件。
   - 优先选择不会在 Unity domain reload 时写文件的方案。

3. 删除 VRChat 平台 include。
   - 删除 `Shaders/platform_vrchat.hlsl` 和 `.meta`。
   - 删除 `Shaders/pbr_core.hlsl` 中的 `#ifdef LIL_VRCHAT` 路径。
   - VRChat camera/mirror 判断要么替换成项目普通相机行为，要么直接删除对应功能。

4. 统一 runtime 属性名。
   - `Scripts/ShaderLayerSetter.cs` 永远使用 `_HideShaderLayer`。
   - `Scripts/VolumetricFog.cs` 永远使用：
     - `_VFogNoise`
     - `_VFogDensity`
     - `_VFogScrollX`
     - `_VFogScrollZ`
     - `_VFogHeightScale`
     - `_VFogHeightOffset`
     - `_VFogHeightSharpness`
   - 删除 runtime 脚本里的所有 `#if LIL_VRCHAT` 分支。

5. 删除材质面板里的 VRChat 暴露项。
   - 从 `Shaders/lilPBR.shader` 删除 `VRChat` foldout 和相关属性。
   - 如果属性不再被采样，从 `Shaders/pbr_properties.hlsl` 删除对应字段。
   - 从 `Editor/Localization/*.po` 删除 `VRChat` 字符串。

6. 重新扫描。
   - 执行：`rg -n "VRChat|VRC|Udon|LIL_VRCHAT|LIL_VRCLIGHTVOLUMES|LIL_LTCGI|platform_vrchat" .`
   - 任何剩余命中都必须是历史说明或明确保留项。

### 验收

- Unity 项目即使安装 `com.vrchat.base`，也不会改变本包的 C# define 或 shader 输出。
- `settings.hlsl` 不会因为可选包存在而在项目打开时被反复重写。
- Runtime 脚本只暴露项目自有 shader global。
- Shader 不依赖 `platform_vrchat.hlsl` 也能编译。

## 第三阶段：优化 multi_compile

### 目的

降低编辑器启动 stall、shader import 时间和构建时 shader 变体数量。这里说的“编译变体”主线特指 `multi_compile`，尤其是 URP lighting、shadow、lightmap、debug、instancing、LOD、motion vector 等 Unity/URP 运行时关键字组合。

`shader_feature_local` 也会产生变体，但它更偏材质功能开关，且 Unity 可以基于实际材质使用情况做一定裁剪。本阶段不把它作为第一优先级，除非某个 pass 明确带了完全无用的材质功能关键字。

### 先建立基线

动 `multi_compile` 之前先记录：

- Unity 版本和 URP fork 版本。
- 清理相关 shader cache 后的首次 shader import 时间，如果可操作。
- 修改以下文件后的重编译耗时：
  - `Shaders/pbr_core.hlsl`
  - `Shaders/unity_urp.hlsl`
  - `Shaders/lilPBR.shader`
- Editor.log 或 Unity shader variant log 中的当前变体数量。
- 项目 RendererFeature 和 URP Asset 中实际开启的功能。

### Phase 1：停止不必要的 reimport 触发

1. 确认没有 editor 脚本在内容不变时写 shader 文件。
2. VRC 删除后，优先让 `settings.hlsl` 静态化。
3. 搜索 editor 代码中的：
   - `[InitializeOnLoadMethod]`
   - `AssetDatabase.Refresh`
   - `File.WriteAllText`
   - `StreamWriter`
4. 删除 refresh loop 或无条件生成文件写入。

验收：

- 打开 Unity 不会 dirty 或重写包内 shader 文件。

### Phase 2：按 pass 裁剪 multi_compile

优先处理最安全的 pass。每次只改一个 pass，编译并验证视觉结果。

优先级：

1. `ShadowCaster`
2. `DepthOnly`
3. `MotionVectors`
4. `DepthNormals`
5. `HoAOV`
6. `HoAOVSSS`
7. `HoCharacterCapture`
8. `GBuffer`
9. `UniversalForward`

处理原则：

- `ShadowCaster` 只保留真正影响阴影写入的 `multi_compile`，例如 instancing、LOD crossfade、`_CASTING_PUNCTUAL_LIGHT_SHADOW`。
- `DepthOnly` 只保留深度写入需要的 `multi_compile`，例如 instancing、LOD crossfade。
- `MotionVectors` 只保留 motion vector 需要的 `multi_compile`，例如 instancing、LOD crossfade、`_ADD_PRECOMPUTED_VELOCITY`。
- `DepthNormals` 只保留 normal/depth 输出和 URP pass 需要的 `multi_compile`。
- `HoAOV`、`HoAOVSSS`、`HoCharacterCapture` 不应该继承 Forward 的完整 lighting `multi_compile`。
- `GBuffer` 只保留 deferred path 真正消费的 `multi_compile`，例如 `_GBUFFER_NORMALS_OCT`、instancing、LOD crossfade。
- `UniversalForward` 是最大头，但风险也最高；先用项目控制的 `skip_variants` 或条件化 `multi_compile`，不要一开始硬删主光阴影等核心路径。

非主线但可顺手确认：

- `shader_feature_local` 中如果有某个 pass 完全不会使用的材质功能，也可以删除。
- 这类删除要以 pass 代码是否真的采样/分支为准，不要为了数量盲删。

验收：

- opaque、cutout、dither、alpha、wind、triplanar 材质仍能写出正确 shadow/depth/motion 数据。
- `Shaders/lilPBR.shader` 没有编译错误。
- Editor.log 或 shader variant log 中能看到对应 pass 的变体数量下降。

### Phase 3：给 URP multi_compile 加项目级 skip 策略

给本 RP 流程不用的 URP 功能加明确的项目开关，再转成 `#pragma skip_variants` 或条件化的 `#pragma multi_compile`。

候选开关：

- `LILPBR_SKIP_DECALS`
- `LILPBR_SKIP_LIGHTMAPS`
- `LILPBR_SKIP_DYNAMIC_LIGHTMAPS`
- `LILPBR_SKIP_ADDITIONAL_LIGHT_SHADOWS`
- `LILPBR_SKIP_REFLECTION_PROBE_BLENDING`
- `LILPBR_SKIP_REFLECTION_PROBE_BOX_PROJECTION`
- `LILPBR_SKIP_DEBUG_DISPLAY`
- `LILPBR_SKIP_LIGHT_COOKIES`
- `LILPBR_SKIP_LIGHT_LAYERS`
- `LILPBR_SKIP_CLUSTER_LIGHT_LOOP`

规则：

- 默认值要跟项目实际 Renderer/URP Asset 设置一致，不跟通用 Unity 默认值走。
- 主光阴影先保留，除非 RP 流程明确不使用。
- 如果 HTrace/URP SSAO 仍是 lilPBR 外观的一部分，先保留 `_SCREEN_SPACE_OCCLUSION`。
- 添加 `skip_variants` 前，必须按当前 URP fork 核对关键字名。

验收：

- Editor.log 或 shader variant log 中 Forward pass 变体数量下降。
- 定义 RP 流程的测试场景和基线画面一致。

### Phase 4：减少重复 pragma 块

如果手动裁剪后的 pragma 维护成本仍然高，再处理结构问题。

可选方案：

1. 把重复 `multi_compile` 组合收敛成本包局部约定，保证每个 pass 的列表可读、可 diff。
2. 如果 Unity 当前 shader 语境允许，尝试用 include 片段承载重复 pragma。
3. 对稳定 pass 拆 hidden shared pass shader，再用 `UsePass` 复用。
4. Forward 和 GBuffer 先留在主 shader，等低风险 pass 稳定后再考虑共享。

验收：

- shader 源码更容易 diff。
- pass tag、材质属性访问和渲染结果不丢失。

### Phase 5：暂缓模板导入器

lilToon 风格的 container/importer 系统长期更干净，但侵入性很高。

不要把它作为第一刀。只有满足以下条件后再考虑：

- 非 URP 和 VRC 删除完成；
- `multi_compile` 裁剪已经有可测收益；
- 项目专用 feature set 稳定。

## 验证矩阵

最低材质用例：

- opaque
- cutout
- dither
- transparent，如果保留
- normal map
- packed PBR map
- separate metallic/occlusion/height/smoothness maps
- planar UV
- triplanar UV
- atlas mask
- wind cloth/tree
- HoAOV output
- HoCharacterCapture output
- planar reflection material
- SSAO/HTrace receiver

最低 pass 覆盖：

- Forward
- GBuffer，如果 deferred 仍在范围内
- ShadowCaster
- DepthOnly
- DepthNormals
- MotionVectors
- XRMotionVectors，如果 XR 仍在范围内
- Meta，如果 baked lighting 仍在范围内
- HoAOV
- HoAOVSSS
- HoCharacterCapture

## 里程碑

### Milestone 1：URP-only 声明完成

- 完成非 URP 审计。
- 更新文档，明确这是项目 URP-only fork。
- 删除 Tessellation shader 分支，并迁移或确认不存在旧材质引用。
- 记录 deferred、XR motion vectors、Meta pass 是否继续支持。

### Milestone 2：VRC-free 包

- 删除 asmdef version define。
- 删除 `platform_vrchat.hlsl`。
- 删除 VRC shader 属性和本地化。
- 删除 C# `LIL_VRCHAT` 分支。
- 让 `settings.hlsl` 稳定不重写。

### Milestone 3：第一轮 multi_compile 降量

- 裁剪 `ShadowCaster`、`DepthOnly`、`MotionVectors`。
- 记录 before/after 数字。
- 如果出现视觉回归，按 pass 隔离，不继续扩大改动。

### Milestone 4：Forward URP skip 策略

- 决定本 RP 流程明确不支持哪些 URP 功能。
- 添加显式 skip 开关。
- 测量 Forward pass 变体数量下降。

### Milestone 5：维护清理

- 删除 `pbr_properties.hlsl` 里的死属性。
- 删除未使用的 texture/include。
- 已删除 Tessellation 专用 shader/include 残留。
- 更新 README 和 package notes。
- 决定是否把旧的 `LILPBR_SHADER_COMPILE_OPTIMIZATION_PLAN.md` 合并进本文档。

## 非目标

- 不保留上游 lilPBR 的通用包兼容性。
- 不保留自动 VRChat 行为。
- 不把 shader template importer 作为第一步。
- 除非 RP 流程明确丢弃，否则不删除 HoAOV、HTrace/SSAO、Planar Reflection、HoCharacterCapture 等项目功能。

## 工作规则

每次只改一个类别，并在进入下一类前验证：

1. 兼容性裁剪。
2. VRC 裁剪。
3. `multi_compile` 降量。
4. 结构清理。

这样 shader 编译失败和画面回归都能归因到较小的改动集。
