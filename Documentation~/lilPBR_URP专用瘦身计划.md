# lilPBR URP 专用瘦身计划

## 目标

把这个 `lilPBR` fork 收敛成专供 Hollow 本地 URP 渲染流程使用的项目包。

后续不再以通用 shader 包为目标。保留服务本地 URP Renderer、HoAOV、Planar Reflection、HoShadow、HTrace/SSAO、SSS 和项目材质流程的代码路径；删除会增加导入时间、`multi_compile` 数量、编辑器刷新成本和维护面的兼容分支。

执行顺序：

1. 非 URP 支持已完成清理。
2. VRChat 特殊支持已完成清理。
3. 优化 `multi_compile`。

## 当前快照

- `README.md` 已经声明包是 URP-only。
- 当前 shader 入口只保留 `Shaders/lilPBR.shader`。
- `Shaders/lilPBR_Tessellation.shader`、`.meta`、`Shaders/tessellation.hlsl` 和 `.meta` 已删除。该曲面细分分支不再作为项目 RP 流程的一部分。
- `Shaders/lilPBR.shader` 使用 `RenderPipeline = UniversalPipeline`，并包含 `UniversalForward`、`UniversalGBuffer`、`ShadowCaster`、`DepthOnly`、`DepthNormals`、`Meta`、`MotionVectors`、`XRMotionVectors`、`HoAOV`、`HoCharacterCapture` 等 URP pass。
- VRChat、Udon、VRCLightVolumes、LTCGI 相关支持已删除。
- 编译压力主要来自 Forward pass 中完整的 URP `multi_compile` 组合，以及部分 pass 中重复出现但实际不需要的 Unity pass 级 `multi_compile`。
- `LILPBR_SHADER_COMPILE_OPTIMIZATION_PLAN.md` 里已有一份偏技术细节的 pass-by-pass 编译优化计划。本文档作为这条瘦身分支的总执行顺序。

## 第一阶段：非 URP 支持清理

### 状态

已完成。

当前代码状态：

- `Shaders/lilPBR.shader` 是唯一 shader 入口。
- 唯一有效 `SubShader` 带有 `RenderPipeline = UniversalPipeline`。
- 所有 pass 都是 URP pass 或项目自定义 URP pass：`UniversalForward`、`UniversalGBuffer`、`ShadowCaster`、`DepthOnly`、`DepthNormals`、`Meta`、`MotionVectors`、`XRMotionVectors`、`HoAOV`、`HoMetadataBufferSurfaceColor`、`HoCharacterCapture`。
- 没有 Built-in/HDRP/LWRP include、Surface Shader、`CGPROGRAM`、`UsePass` 或非 `UniversalPipeline` 的 `SubShader`。
- `Shaders/unity_urp.hlsl` 是唯一 Unity 管线集成层。
- README 已改为项目专用 URP-only 说明。
- `Shaders/lilPBR_Tessellation.shader`、`.meta`、`Shaders/tessellation.hlsl` 和 `.meta` 已删除。
- `Shaders/pbr_properties.hlsl` 中的 `_Tess*` uniform 已删除。

### 验收

- `rg -n "BuiltIn|builtin|HDRP|HDRenderPipeline|LightweightPipeline|LWRP" Shaders Editor Scripts package.json` 不再命中有效支持路径。
- `Shaders/lilPBR.shader` 在 URP 下仍能编译。
- 项目中不再有材质引用 `lilPBR_Tessellation.shader`。
- 项目材质不会静默 fallback 到 missing shader。

## 第二阶段：VRChat 特殊支持清理

### 状态

已完成。这个 fork 后续只使用普通 Unity/URP 属性名和项目自有 RendererFeature。

当前代码状态：

- `Editor/jp.lilxyzw.lilpbr.asmdef` 的 `versionDefines` 已清空。
- `Scripts/jp.lilxyzw.lilpbr.runtime.asmdef` 的 `versionDefines` 已清空。
- `Editor/ShaderModifier.cs` 和 `.meta` 已删除，`settings.hlsl` 变成静态空 include。
- `Shaders/platform_vrchat.hlsl` 和 `.meta` 已删除。
- `Shaders/pbr_core.hlsl` 中的 `LIL_VRCHAT` camera/mirror 显隐分支已删除。
- `Scripts/ShaderLayerSetter.cs` 固定使用 `_HideShaderLayer`。
- `Scripts/VolumetricFog.cs` 固定使用 `_VFog*` 全局属性。
- `Shaders/lilPBR.shader` 中的 `VRChat` foldout 和 `_LTCGI` 占位属性已删除。
- 中文本地化中的 `VRChat` 字符串已删除。

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
2. `settings.hlsl` 已静态化。
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
6. `HoMetadataBufferSurfaceColor`
7. `HoCharacterCapture`
8. `GBuffer`
9. `UniversalForward`

处理原则：

- `ShadowCaster` 只保留真正影响阴影写入的 `multi_compile`，例如 instancing、LOD crossfade、`_CASTING_PUNCTUAL_LIGHT_SHADOW`。
- `DepthOnly` 只保留深度写入需要的 `multi_compile`，例如 instancing、LOD crossfade。
- `MotionVectors` 只保留 motion vector 需要的 `multi_compile`，例如 instancing、LOD crossfade、`_ADD_PRECOMPUTED_VELOCITY`。
- `DepthNormals` 只保留 normal/depth 输出和 URP pass 需要的 `multi_compile`。
- `HoAOV`、`HoMetadataBufferSurfaceColor`、`HoCharacterCapture` 不应该继承 Forward 的完整 lighting `multi_compile`。
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

- VRC 删除已完成；
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
- HoMetadataBufferSurfaceColor
- HoCharacterCapture

## 里程碑

### Milestone 1：URP-only 声明完成

- 已完成非 URP 审计。
- 已更新文档，明确这是项目 URP-only fork。
- 已删除 Tessellation shader 分支；项目层仍需确认不存在旧材质引用。
- 记录 deferred、XR motion vectors、Meta pass 是否继续支持。

### Milestone 2：VRC-free 包

- 已删除 asmdef version define。
- 已删除 `platform_vrchat.hlsl`。
- 已删除 VRC shader 属性和本地化。
- 已删除 C# `LIL_VRCHAT` 分支。
- `settings.hlsl` 已稳定不重写。

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
