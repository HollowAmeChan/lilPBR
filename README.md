# lilPBR

`lilPBR` 是 Hollow 的 Unity 物理材质 shader 包。在这套工作区里，它是 `lilToon` 的场景/PBR 侧搭档：lilToon 负责角色和 NPR 表现，lilPBR 负责更接近物理材质的场景表面、环境材质、水体，以及共享的 URP 渲染实验。

## 在整套系统里的定位

`lilPBR` 与其他仓库的关系：

- `lilToon-URP-Extensions` 提供平面反射、HoAOV 等共享 RendererFeature。
- `lilToon-UnityGLTF-Extensions` 保存 glTF 材质契约，后续可映射成 lilPBR 材质。
- `lilToon` 与本包共享 HoAOV、AO、SSS、OIT 和材质契约语义。
- `HoUrp17.3.0` 是 URP pass 的目标运行时。

## 主要功能

- URP 和 Built-in Render Pipeline 双管线 SubShader。
- `lilPBR.shader` 与 `lilPBR_Tessellation.shader`。
- Packed / Separate PBR Map，支持 metallic、occlusion、height、smoothness。
- 默认、平面和三平面 UV 模式。
- Normal、Parallax/Height、顶点位移和 Tessellation。
- Emission、Subpixel Emission、Anisotropy、Clear Coat、Cloth、Fake Translucent、SSS、Detail、Wetness/Rain、Wind、Distance Fade。
- URP `ForwardLit`、`GBuffer`、`ShadowCaster`、`DepthOnly`、`DepthNormals`、`Meta`、`MotionVectors`、`XRMotionVectors`、`HoAOV`、`HoCharacterCapture` pass。
- Built-in `ForwardBase`、`ForwardAdd`、`ShadowCaster`、`Meta` 路径。
- Water shader 和水体相关 include。
- `Scripts/VolumetricFog.cs` 提供全局体积雾 shader 参数。

## 重要目录

- `Shaders/`：shader 源文件、HLSL include、水体文件和辅助贴图。
- `Editor/`：材质 Inspector、shader 修改器、本地化、项目设置、属性 drawer 和材质工具。
- `Scripts/`：runtime 组件和 asmdef。
- `Textures/`：可复用 shader 数据贴图。
- `LILPBR_QUALITY_ROADMAP.md`：AO、SSGI、平面反射、OpenPBR/glTF 映射和质量升级路线。

## 平面反射

shader 里有 `Planar Reflection` foldout，并采样 `_LILPBRPlanarReflectionTexture`。真正的反射运行时在：

```text
D:/Unity_Fork/lilToon-URP-Extensions/Runtime/PlanarReflection/LILPlanarReflectionSurface.cs
```

把 `LILPlanarReflectionSurface` 加到镜面、抛光地面或水面 mesh 上，再在 lilPBR 材质里开启平面反射即可。

## HoAOV 与角色捕获

`lilPBR` 包含 HoAOV 属性和 pass，因此场景/PBR 材质也能写入与 lilToon 一致的语义缓冲。HoPost、Shoost、HTrace 和角色特化效果会消费这些缓冲。

## 安装

```json
{
  "dependencies": {
    "jp.lilxyzw.lilpbr": "file:D:/Unity_Fork/lilPBR"
  }
}
```

如果使用完整本地渲染系统，还应同时加入 `lilToon`、`lilToon-URP-Extensions` 和本地 URP 包。
