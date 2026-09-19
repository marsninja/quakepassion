# Quake II / Quake III: first level viewers validated

Both games now build and render with the local Jac binary and the upstream fixes
staged in `.jac/compiler`. Work is on `feature/quake2-quake3-rendering`.

```sh
JAC_COMPILER_LIB=off jac build main.jac --native -o qp
QP_GAME=q2 ./qp                         # base1
QP_GAME=q3 ./qp                         # q3dm1
QP_GAME=q3 QP_MAP=q3tourney2 ./qp
```

Default assets are `~/quake-assets/baseq2` and `~/quake-assets/baseq3`.
`QP_ASSETS` overrides the game directory. Controls and fresh-checkout setup are
in [README](../README.md). This is a static viewer with free-flight movement.

## Implemented

- Q2 BSP38 geometry, WAL textures, PCX palette, RGB lightmaps, cluster PVS,
  static brush entities, and six-image environment skyboxes.
- Case-insensitive PAK lookup handles mixed-case texture references in `base2`.
  Valid leaf-root brush models (negative BSP head indices) are accepted.
- Q3 PK3 archive precedence, BSP46 indexed surfaces, quadratic patch tessellation,
  interpolated vertex colors/UVs, shared RGB lightmap tiles, and cluster PVS.
- Q3 shader scripts select a static texture/frame. The selected stage's alpha
  test and additive blending are honored, along with two-sided culling. Opaque
  surfaces draw before additive surfaces, which do not write depth.
- Q3 textures and lightmaps render in one pass so alpha-tested surfaces retain
  their masks. Patch triangle winding is consistent with the surface normals.
- Raylib is built with JPG/TGA decoders enabled. The pinned prebuilt library did
  not support these original assets.
- Shared Jac BSP graphs and `Locate`/`CollectFaces` walkers support all three
  games. Q2/Q3 visibility handles cluster zero and leaf zero correctly.

## Validation

Native standalone build and graphical checks passed on macOS arm64, raylib 6.0,
and the local Jac 0.37.19 binary with staged compiler sources described below.

| Game / map | Spawn PVS faces | All faces | Moved PVS faces | Differing pixels, spawn / moved |
| --- | ---: | ---: | ---: | ---: |
| Q2 base1 | 1,015 | 4,102 | 926 | 0 / 0 |
| Q2 base2 | 1,239 | 5,130 | 1,246 | 0 / 0 |
| Q2 base3 | 1,401 | 5,068 | 958 | 0 / 0 |
| Q3 q3dm1 | 611 | 1,304 | 747 | 0 / 0 |
| Q3 q3dm7 | 561 | 3,414 | 581 | 0 / 0 |
| Q3 q3tourney2 | 786 | 2,084 | 535 | 0 / 0 |

Each map produced five nonblank 1280×720 captures: culling on/off at spawn,
a camera turn, and culling on/off after movement. Both comparisons use the same
camera and allow at most 16 differing pixels; all Q2/Q3 pairs matched exactly.
Screenshots were also inspected for geometry, textures, lighting, patches, and
sky. These are representative views, not exhaustive visual coverage or a
comparison against the original game's renderer.

The six-map Q1 regression (`e1m1`, `start`, `e1m2`, `e2m1`, `e3m1`, `e4m1`)
also passed with all twelve culling comparisons pixel-identical.

```sh
JAC_COMPILER_LIB=off jac test -j0
python3 scripts/validate_quake.py --game q2
python3 scripts/validate_quake.py --game q3
python3 scripts/validate_quake.py --game q1
```

All 38 unit tests pass. Captures and logs live under `.jac/screenshots/<game>/<map>/`. Unit coverage
includes WAL decoding/bounds, invalid BSP versions, leaf-root brush models,
patch interpolation/winding, cluster-zero visibility, PAK case handling, and
shader stage selection/material flags. Original assets remain outside git.

## Scope and limitations

- No collision, gameplay, monster/item/weapon models, or moving brush entities.
- Q2 water warp, translucent materials, sky rotation, texture animation, and
  animated lightstyles are not reproduced.
- Q3 uses static material representatives, not a complete shader interpreter.
  Animated/multiple stages, arbitrary blend modes, scrolling textures, fog,
  skyboxes, flares, and vertex deformation remain unimplemented. Additive
  effects use one static frame. Unsupported/missing images get a diagnostic
  texture; some maps contain a `noshader` reference.
- Patches use fixed eight-step tessellation per quadratic block. Lightmaps use
  a fixed 2048-square atlas and fixed brightness contributions.
- Validation covers the supplied maps and selected views on macOS, not all
  maps, materials, viewpoints, or platforms.

## Upstream compiler fixes staged locally

The installed binary and reference submodule are unchanged. The private compiler
uses ZIP-support commit `fb6940ddd52a76ea75790dda10736ef09926f0fd` plus the two
checked-in patches. Follow [README](../README.md) to reproduce staging; source
parser mode (`JAC_COMPILER_LIB=off`) avoids the old packaged parser ABI. Clear
project caches after replacing compiler sources before rebuilding.

- [Jac #9322](https://github.com/jaseci-labs/jac/pull/9322): native read-only ZIP
  support and context-manager/file ownership. Prior upstream validation read
  all 4,073 entries across the nine supplied PK3 archives.
- [Jac #9325](https://github.com/jaseci-labs/jac/pull/9325): checked native
  `bytearray.extend` from integer lists. The compiler previously attempted an
  invalid implicit i64-to-i8 narrowing. The fix validates before mutation and
  preserves ownership and alias behavior. Four new and 58 existing tests pass.
  Applied through `patches/jac-native-bytearray-extend.patch`.
- [Jac #9326](https://github.com/jaseci-labs/jac/pull/9326): bytes payload pointers
  in struct-returning C calls. Aggregate ABI lowering previously passed the
  internal object header to `LoadImageFromMemory`, rather than image bytes.
  `_codegen_clib_call` in `clib_abi.impl.jac` now applies `_bytes_data_ptr`, as
  ordinary foreign calls do. Two new tests fail before the fix and pass after;
  another 65 tests pass, with one Linux-specific skip on macOS. Applied through
  `patches/jac-native-aggregate-bytes.patch`.

These fixes are already included locally; rendering does not depend on waiting
for upstream merges. No engine workaround replaces the failing Jac idioms.

Asset-independent reproductions remain in
[native_bytearray_extend.jac](../scripts/repros/native_bytearray_extend.jac) and
[native_struct_bytes.jac](../scripts/repros/native_struct_bytes.jac), with its
[C fixture](../scripts/repros/native_struct_bytes.c). With the staged fixes:

```sh
JAC_COMPILER_LIB=off jac build scripts/repros/native_bytearray_extend.jac \
    --native -o .jac/bytearray_probe
.jac/bytearray_probe                    # prints 3

# macOS; Linux uses cc -shared -fPIC and a .so filename.
cc -dynamiclib scripts/repros/native_struct_bytes.c -o vendor/libqp_ffi_probe.dylib
JAC_COMPILER_LIB=off jac build scripts/repros/native_struct_bytes.jac \
    --native -o .jac/struct_bytes_probe
DYLD_LIBRARY_PATH="$PWD/vendor" .jac/struct_bytes_probe
# scalar 127
# struct 127 1 2
```
