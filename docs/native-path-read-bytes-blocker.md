# Native binary-file and PNG validation status

The native stdlib implementation is proposed in upstream
[PR #9354](https://github.com/jaseci-labs/jac/pull/9354): `Path.read_bytes()`,
file-error handling, and mutable-buffer zlib input. The PNG decoder also required
numeric iterable `min`, covered separately by
[PR #9357](https://github.com/jaseci-labs/jac/pull/9357).
The approach retains `na_stdlib`; PR #9323 is not required.

## Validated locally

Both fixes are combined in the local compiler checkout
`/Users/marsninja/repos/jaseci-wt/qp-gameplay-local/jac` (integration commit
`183f16f890`). A standalone native probe imports the unchanged
`scripts/png_checks.jac`, decodes each saved pickup capture twice, checks its
1280×720 dimensions and color diversity, and asserts zero differing pixels
between identical images. All three games pass:

```text
NATIVE PNG PASS q1 1280 720
NATIVE PNG PASS q2 1280 720
NATIVE PNG PASS q3 1280 720
```

This validates decoding existing captures, not a new graphical capture session.
The original `repros/native_path_read_bytes.jac` additionally uses
`bytes.startswith`, which is still unsupported in the native bytes emitter.
It must not be reported as passing solely because file reads now work.

## Integration resolution

The full `scripts/alias_models_smoke.jac` harness also enumerates asset
folders. Combining native file reads and `os.listdir` exposes incompatible
LLVM declarations for libc's errno accessor. The fix in
[PR #9358](https://github.com/jaseci-labs/jac/pull/9358) is applied locally. See
[native-file-listdir-blocker.md](native-file-listdir-blocker.md) for the small
reproduction and root locations. The full native harness now passes, including
the time-separated Q3 material pixel comparison.

Current Jac requires typed edge endpoints. Engine edges now declare their
source/destination node types; this resolves the previous opaque dependency
analysis failure on `engine/world/level.jac`.

No engine workaround was introduced for either compiler defect.
