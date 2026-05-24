# lilPBR Shader Compile Optimization Plan

## Background

Unity currently spends a long time in `Application.UpdateScene`, shader compilation, and scene refresh after opening the project or touching lilPBR shader files. This is no longer mainly a ShaderGUI issue. The remaining cost is mostly caused by shader variant count and repeated invalidation of shared shader includes.

The immediate safe-mode GUI change prevents custom material GUI initialization from blocking editor startup. The next optimization target is shader import and variant compilation.

## Current Findings

### lilPBR

- `lilPBR.shader` is a large handwritten shader.
- `lilPBR_Tessellation.shader` has been removed from this fork, so subsequent optimization work only targets the main shader.
- Multiple passes repeat the same material feature keywords:
  - `_UVMODE_DEFAULT/_UVMODE_PLANAR/_UVMODE_TRIPLANAR`
  - `_ATRASMASK`
  - `_CUTOUT/_DITHER/_TRANSPARENT`
  - `_RANDOMIZE_UV`
  - `_TEXTUREMODE_SEPARATE`
  - `_PARALLAXMODE_VERTEX/_PARALLAXMODE_PIXEL`
  - `_TRANSLUCENT`
  - `_WINDMODE_NONE/_WINDMODE_CLOTH/_WINDMODE_TREE`
  - `_WINDMODE_POM`
- Forward pass also carries the full URP lighting keyword set:
  - main light shadows
  - additional lights
  - additional light shadows
  - reflection probe variants
  - soft shadows
  - screen space occlusion
  - decals
  - light cookies
  - light layers
  - clustered light loop
  - lightmaps
  - debug display
- Shared includes such as `pbr_core.hlsl`, `unity_urp.hlsl`, `hoaov.hlsl`, and `settings.hlsl` are referenced by many passes. Changing one of them can invalidate many variants in the main shader.

### lilToon

lilToon uses a more scalable import pipeline:

- User-facing shaders are generated from `.lilcontainer` and `.lilblock` templates.
- Many user shaders use `UsePass` to reference shared hidden pass shaders instead of duplicating every pass.
- Each pass uses pass-specific placeholder pragmas:
  - `#pragma lil_multi_compile_forward`
  - `#pragma lil_multi_compile_shadowcaster`
  - `#pragma lil_multi_compile_depthonly`
  - `#pragma lil_multi_compile_depthnormals`
  - `#pragma lil_multi_compile_motionvectors`
  - `#pragma lil_multi_compile_meta`
- `lilShaderContainerImporter.cs` expands those placeholders according to the active render pipeline and URP version.
- `lilToonSetting` emits skip markers such as:
  - `#pragma lil_skip_variants_lightmaps`
  - `#pragma lil_skip_variants_decals`
  - `#pragma lil_skip_variants_addlight`
  - `#pragma lil_skip_variants_addlightshadows`
  - `#pragma lil_skip_variants_probevolumes`
  - `#pragma lil_skip_variants_ao`
  - `#pragma lil_skip_variants_reflections`
- Build optimization can scan scene-referenced materials and animation clips, then only enable features that are actually used.

## Goal

Reduce editor stalls caused by lilPBR shader recompilation without breaking material behavior.

The optimization should be incremental:

1. Stop accidental repeated asset writes.
2. Reduce keywords in non-Forward passes.
3. Add conservative URP skip variants.
4. Consider shared pass shaders or a template importer only after the low-risk work is stable.

## Phase 1: Stop Repeated Refresh Triggers

### Objective

Ensure lilPBR does not rewrite shader-related files during every Unity domain reload or project open.

### Tasks

- Keep `ShaderModifier.cs` content-diff writing for `settings.hlsl`.
- Check all editor scripts for:
  - `[InitializeOnLoadMethod]`
  - static constructors with editor side effects
  - `AssetPostprocessor`
  - unconditional `AssetDatabase.Refresh()`
  - unconditional `File.WriteAllText` or `StreamWriter`
- Add a concise debug log only when a shader-related file is actually written.
- Confirm `settings.hlsl` is not touched when its generated content is unchanged.

### Expected Result

Opening the project should not trigger shader reimport unless package files, defines, or render pipeline settings actually changed.

## Phase 2: Reduce Non-Forward Pass Keywords

### Objective

Cut variant count in passes that do not need full PBR shading.

### Priority Order

1. `ShadowCaster`
2. `DepthOnly`
3. `MotionVectors`
4. `DepthNormals`
5. `HoAOV`
6. `HoAOVSSS`
7. `HoCharacterCapture`
8. `GBuffer`

### ShadowCaster

Likely required:

- alpha mode keywords needed for cutout/dither/transparent rejection
- UV mode if alpha texture sampling depends on UV generation
- atlas mask if alpha masking depends on it
- randomize UV if alpha sampling depends on it
- texture mode if alpha sampling depends on packed/separate texture layout
- wind vertex keywords
- LOD crossfade
- instancing
- `_CASTING_PUNCTUAL_LIGHT_SHADOW`

Likely removable after verification:

- `_PARALLAXMODE_PIXEL`
- `_TRANSLUCENT`
- shading-only features
- emission
- clearcoat
- cloth
- wetness
- screen-space shading modes

### DepthOnly

Likely required:

- alpha/cutout/dither rejection path
- UV and texture sampling keywords needed for alpha
- wind vertex keywords
- LOD crossfade
- instancing

Likely removable after verification:

- `_PARALLAXMODE_PIXEL`
- `_TRANSLUCENT`
- lighting-only features
- normal-map-only features unless alpha path depends on them

### MotionVectors

Likely required:

- alpha rejection path
- UV and texture sampling keywords needed for alpha
- wind vertex keywords
- `_ADD_PRECOMPUTED_VELOCITY`
- LOD crossfade
- instancing

Likely removable after verification:

- fragment shading features
- translucent/subsurface features unless motion pass explicitly samples them

### DepthNormals

Likely required:

- alpha rejection path
- normal output path
- normal map if the pass should write normal-mapped depth normals
- UV and texture sampling keywords needed for alpha and normal map
- wind vertex keywords
- rendering layers
- LOD crossfade
- instancing

Likely removable after verification:

- emission
- clearcoat
- cloth
- wetness
- screen-space reflection/shading-only variants

### HoAOV and HoAOVSSS

Likely required:

- alpha rejection path
- UV and texture sampling keywords used by `hoaov.hlsl`
- normal map if AOV output uses it
- subsurface/translucent keywords if SSS output uses them
- wind vertex keywords
- LOD crossfade
- instancing

Likely removable after verification:

- unrelated lighting keywords
- emission
- clearcoat
- cloth
- wetness

### HoCharacterCapture

Likely required:

- alpha rejection path
- UV and texture sampling keywords used by capture output
- backface color if capture uses it
- wind vertex keywords
- LOD crossfade
- instancing

Likely removable after verification:

- unrelated lighting keywords
- parallax pixel if capture does not need depth modification
- translucent/subsurface if not used by capture output

## Phase 3: Add Conservative Skip Variants

### Objective

Reduce Forward pass URP variant multiplication for project features that are disabled or intentionally unsupported.

### Candidate Skips

Start with conservative, project-controlled switches:

- decals
- probe volumes
- screen space ambient occlusion
- additional light shadows
- reflection probe blending
- reflection probe box projection
- lightmaps
- debug display

### Implementation Approach

- Add lilPBR-specific settings macros in `settings.hlsl` or a new include.
- Convert selected URP feature groups into conditional pragmas or `#pragma skip_variants`.
- Keep defaults conservative. Do not strip a feature by default unless the project is known not to use it.
- Avoid putting skip pragmas in a global location that conflicts with pass-local multi_compile behavior on newer URP versions.

### Example Direction

```hlsl
#if defined(LILPBR_SKIP_DECALS)
    #pragma skip_variants _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
#endif

#if defined(LILPBR_SKIP_LIGHTMAPS)
    #pragma skip_variants LIGHTMAP_ON DIRLIGHTMAP_COMBINED DYNAMICLIGHTMAP_ON
#endif
```

Exact keyword lists must be verified against the Unity and URP version used by the project.

## Phase 4: Shared Pass Shader

### Objective

Reduce duplicated pass text inside the main shader.

### Approach

- Create hidden shared pass shaders for stable non-material-specific passes.
- Use `UsePass` from user-facing lilPBR shaders where safe.
- Start with stable non-Forward passes:
  - `ShadowCaster`
  - `DepthOnly`
  - `DepthNormals`
  - `HoAOV`
  - `HoCharacterCapture`
  - `MotionVectors`
  - `Meta`
- Keep Forward and GBuffer local until shared pass behavior is proven.

### Risks

- Unity `UsePass` can have edge cases with property dependencies.
- Shared pass shaders may still need separate sources if pass-local defines do not transfer cleanly.
- Some pass-local defines may not transfer cleanly.

This phase should only start after Phase 2 and Phase 3 are stable.

## Phase 5: Template Importer

### Objective

Move toward a lilToon-style scalable shader generation pipeline.

### Possible Design

- Define lilPBR pass templates.
- Define lilPBR placeholder pragmas:
  - `lilpbr_multi_compile_forward`
  - `lilpbr_multi_compile_shadowcaster`
  - `lilpbr_multi_compile_depthonly`
  - `lilpbr_multi_compile_depthnormals`
  - `lilpbr_multi_compile_motionvectors`
- Expand placeholders based on:
  - Unity version
  - URP version
  - project feature settings
  - package feature defines
- Optionally add build-time material scanning to disable unused lilPBR features.

### Recommendation

Do not start with this phase. It is the clean long-term architecture, but it is much more invasive than pass keyword trimming and skip variants.

## Verification Plan

### Compile Safety

- Open Unity and confirm there are no C# compile errors.
- Confirm `settings.hlsl` is not rewritten repeatedly.
- Confirm no repeated `AssetDatabase.Refresh()` loop happens on project open.

### Shader Behavior

For each optimized pass, test at least:

- opaque material
- cutout material
- dither/transparent material if supported by that pass
- planar UV
- triplanar UV
- atlas mask
- wind cloth/tree modes
- normal map for DepthNormals and HoAOV
- subsurface/translucent for HoAOVSSS
- motion vectors if enabled in URP
- deferred rendering if GBuffer is modified

### Performance Indicators

Track before and after:

- editor open time after clean Library shader cache
- time spent in shader compiler after touching `pbr_core.hlsl`
- number of shader compiler processes launched
- Editor.log shader import duration
- visible scene refresh stall duration

## Recommended Execution Order

1. Confirm no repeated file writes or refresh loops remain.
2. Trim `ShadowCaster`.
3. Trim `DepthOnly`.
4. Trim `MotionVectors`.
5. Trim `DepthNormals`.
6. Trim `HoAOV`, `HoAOVSSS`, and `HoCharacterCapture`.
7. Add first conservative skip variants.
8. Re-measure editor open and shader reimport time.
9. Decide whether shared pass shaders are worth the risk.
10. Defer template importer work until the shader surface is stable.

## Notes

- Reducing variant count is more important than micro-optimizing ShaderGUI.
- Safe material GUI should remain the default for project open.
- Any automatic shader-setting generation must avoid writing files when content is unchanged.
- Prefer small pass-by-pass changes with visual verification over one large shader rewrite.
