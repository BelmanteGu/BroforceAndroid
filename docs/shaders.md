# Shader inventory

The free AssetRipper exports shaders as **placeholders**: the `Properties` block is kept, but the pass just draws `_MainTex` as **opaque** (no alpha cutout, blending or effects). The originals are DirectX bytecode anyway, so every custom shader has to be rewritten in CG/HLSL that compiles for GLES3.

Built-in Unity shaders (materials pointing to `guid: 0000000000000000f000000000000000`) are **not** a problem: Unity compiles them for Android itself.

Counted from `m_Shader` in every `.mat` of the export (Steam build 12964083). 97 shader files are exported; 55 distinct custom shaders are used by at least one material.

## Priority 1: covers ~75% of materials

| Shader | Materials | Notes |
|---|---|---|
| `Unlit/Depth Cutout With Image` | 1453 | Terrain, props, characters. Alpha-tested and writes depth |
| `Unlit/Depth Cutout With ColouredImage` | 341 | Same with a tint colour |

Getting these two right should make most of the game look correct.

## Priority 2: common or gameplay-visible

| Shader | Materials |
|---|---|
| `Unlit/Depth Cutout With Image Parallax` | 41 |
| `Custom Shaders/Two Texture Mask` | 28 |
| `Unlit/PixelExplosion` | 11 |
| `Custom/DistortedFlagMasked` | 10 |
| `Unlit/Textured-NoFog` | 5 |
| `Custom/Fake3D` (+ `No Lightmap`, `Tree`, `spec`, `spec No Lightmap`, `Transition`) | 13 |
| `Custom Shaders/Alpha Masked Seperate` | 4 |
| `Custom/3DText` | 4 |

## Priority 3: effects, one-offs (1 to 3 materials each)

`Custom/HeatHaze`, `Custom/ScrollingMultiplyTransparent`, `Custom/ScrollingTextureTransQueue`, `Custom/ScrollingTexture`, `Particles/Sandstorm-Rolling`, `Unlit/TransparentScrolling`, `Custom/DistortedFlag`, `Custom/MapBorder`, `Unlit/Depth Cutout With ColouredImage No Fog`, `Custom/Tombstone`, `Custom/Starfield`, `Blend 2 Textures`, `Custom/BurningMasked`, `Custom/Laserbeam`, `Unlit/Sandstorm-Foreground`, `Unlit/Sandstorm-Background`, `Unlit/Sandstorm-Deathstorm`, `Image Effects/Free Lives Refraction`, `Image Effects/Free Lives Lighting Overlay`, `Custom/backgroundTransparent`, `Projector/Multiply`, `Custom/wavingFlag`, `Custom/Explosion`, `Custom/GeneralUI`, `Custom/PixelWater`, `Custom/ScrollingTendrils`, `Custom/ScrollingTendrils2`, `Custom/DistortedFlagUI`, `Custom/WorldWaterParticle`, `Custom/CloudTendrils`, `Shader Forge/Hologram`, `Custom/Spritesheet-2layer`, `Unlit/FluidDisplay`, `Custom/SatanForcefield`, `Custom/PortalGlow`, `Custom/PortalDistort`, `Custom Shaders/Distortion`, `Unlit/Depth Cutout Zwrite Off`, `Unlit/Depth Cutout With ColouredLookup`, `Custom/TransparentGrass`

## Built-in shaders in use

About 430 materials use built-in shaders (`fileID` 200, 202, 203, 207, 7, 30, 46, 10101, 107xx, e.g. the legacy `Particles/*` and `Sprites/Default` family). No work needed beyond checking they look right.

## Not covered by this count

- Shaders picked from code with `Shader.Find("...")`
- Renderers with no material file (default sprite material)
- Image effects on cameras (`Image Effects/*` above are the ones with materials)

## Method

Rewrites live in [`shaders/`](../shaders) and keep the original's **exact shader name and property names**. `scripts/patch.ps1` copies each one over every exported placeholder with the same name (most shaders are exported twice, once from the main data and once from the bundles), keeping the placeholders' `.meta` so materials still reference them by GUID.

The math comes from the original compiled shaders, not guesswork:

```powershell
./scripts/export.ps1 -ShaderMode Yaml -Name unity-shaderyaml
python scripts/shader-dump.py export/unity-shaderyaml/ExportedProject/Assets export/shader-reference
```

`shader-dump.py` writes one Markdown file per shader (to `export/`, never committed) with:

- properties, queue, and per-pass render state (blend, ZTest/ZWrite, cull, color mask), decoded from the serialized shader
- the D3D11 disassembly of every program, produced by Windows' own `d3dcompiler_47.dll` after LZ4-decompressing Unity's program blob
- which register holds which property (`cb0[3].y = _WorldToPixel`, `t1 = _Ramp`), recovered from Unity's parameter tables because shipped shaders have no reflection data

Rules for rewrites:

- Reproduce constants, thresholds and factors exactly (e.g. the main sprite shader discards at alpha <= 0.2; the tinted one doubles its output).
- Match render state and queue per pass.
- Lighting-based surface shaders are rendered unlit (albedo/emission path): the 2D scenes don't light these objects dynamically. Real-time shadow maps are dropped.
- Keep to GLES2/GLES3-safe CG (`sampler2D`/`tex2D`, constant loop bounds, ≤ 8 interpolators).

## Status

All 55 custom shaders used by materials have been rewritten; none are verified in Unity yet (tracked in #10 until they compile and look right on device).

The Standard Assets image effects (bloom, vignetting, SSAO, DOF, ...) are disabled on Android by the `image-effects` patch instead of being rewritten. The game's own effects (`Image Effects/Free Lives Lighting Overlay` and `Refraction`, `Custom/HeatHaze`) are rewritten. Amplify Color's hidden shaders are still placeholders, which effectively pass the image through without color grading.
