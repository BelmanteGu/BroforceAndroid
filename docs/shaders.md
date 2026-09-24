# Shader inventory

The free AssetRipper exports shaders as **placeholders**: the `Properties` block is kept, but the pass just draws `_MainTex` as **opaque** (no alpha cutout, blending or effects). The originals are DirectX bytecode anyway, so every custom shader has to be rewritten in CG/HLSL that compiles for GLES3.

Built-in Unity shaders (materials pointing to `guid: 0000000000000000f000000000000000`) are **not** a problem: Unity compiles them for Android itself.

Counted from `m_Shader` in every `.mat` of the export (Steam build 12964083). 97 shader files are exported; 64 custom ones are used by at least one material.

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

## Approach

1. Rewrite each shader as a normal CG shader keeping the **same name and property names**, so existing materials pick it up without changes.
2. Start from the placeholder's `Properties` block (it's accurate) and the material values.
3. When the behavior isn't obvious from names and properties, disassemble the original DXBC from the game's `sharedassets*.assets` to recover the math.
4. Replace the placeholder file in the export via a script (like the patcher), so rewritten shaders live in this repo under `shaders/`.
