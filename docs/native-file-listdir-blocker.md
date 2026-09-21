# Native file reads conflict with directory enumeration

After combining upstream PRs [#9354](https://github.com/jaseci-labs/jac/pull/9354)
and [#9357](https://github.com/jaseci-labs/jac/pull/9357), the unchanged PNG helper
builds natively and decodes the saved Q1/Q2/Q3 1280×720 captures successfully.
The full model capture harness exposes a separate native ABI conflict.

## Reproduction

`repros/native_file_listdir.jac` calls `Path("jac.toml").read_bytes()` and
`os.listdir(".")` in the same native program.

```sh
JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-gameplay-local/jac \
JAC_COMPILER_LIB=off jac build repros/native_file_listdir.jac --native \
  -o .jac/qp-file-listdir
```

On macOS ARM64 this fails during code generation:

```text
TypeError: cannot load from value of type i64
('%".36" = call i64 @"__error"()'): not a pointer
```

The local integration compiler is upstream main `3ad0e0104b` plus the min/max
fix `4fd78e9311` and native file/zlib fix (cherry-picked as `183f16f890`).
Neither upstream PR was modified for this reproduction.

## Root cause

- `runtime/na_stdlib/_errno_platform.darwin.jac` declares libc `__error` as
  returning `int`, a native address represented as LLVM `i64`.
- `compiler/backends/native/na_ir_gen_pass.impl/os.impl.jac`, in
  `_emit_os_call("listdir")`, requests the same symbol returning `i32*`, then
  loads from its result.
- `_get_or_declare_extern` in `na_ir_gen_pass.impl/builtins.impl.jac` reuses a
  declaration by symbol name without reconciling the requested function type.
  When the native stdlib declaration exists first, the load sees an integer.
- Linux uses `__errno_location` through analogous declarations; the macOS failure
  is reproduced, while Linux remains untested.

The proper fix belongs at the native foreign-function ABI boundary: native
stdlib address declarations and compiler-generated calls must agree, and reuse
of an extern declaration must not silently hand a caller an incompatible type.
Regression coverage should compose file reads and directory enumeration in both
source orders, with successful and failing operations, in a standalone binary.

## Resolution and scope

Upstream [PR #9358](https://github.com/jaseci-labs/jac/pull/9358) reconciles
compatible native address representations when reusing extern declarations and
rejects incompatible signatures. With that fix applied to the combined local
compiler, the standalone file/listdir repro builds and passes. The full native
`scripts/alias_models_smoke.jac` also builds and passes, including the
time-separated Q3 material comparison. Gameplay work can continue locally while
the upstream changes are reviewed. No engine workaround was added.

Current Jac also requires edge endpoint declarations (E2086). The engine's edges
now declare their actual source/destination types, including BSP and collision
trees, inventory, models, movers, triggers, traversal and signals. This resolves
the earlier opaque `Native dependency analysis failed: .../level.jac` failure.

## Regression verification

With the combined local compiler and typed edge declarations,
`jac test -j0` passes all 133 engine/unit tests (141.94 seconds). This is separate
from the native graphical harness, which now also passes with PR #9358 applied.
