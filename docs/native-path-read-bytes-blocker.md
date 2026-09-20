# Native pathlib lacks Path.read_bytes

The model harness's new screenshot comparison imports `scripts/png_checks.jac`.
That helper type-checks successfully and passes its host-runtime fixtures, but
native compilation fails because native `pathlib.Path` has no `read_bytes` method.
This is a native standard-library coverage gap, not malformed PNG or asset data.

AGENTS.md §3 requires stopping and reporting a valid Jac idiom that fails in the
language/runtime. No replacement file-reading idiom was added to hide this gap.

## Minimal reproduction

`repros/native_path_read_bytes.jac` reads the repository's `jac.toml`:

```jac
import from pathlib { Path }
with entry {
    data = Path("jac.toml").read_bytes();
    assert data.startswith(b"[project]");
    print("PATH READ BYTES PASS", len(data));
}
```

Using the local `qp-cache-sections` compiler:

```sh
JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-cache-sections/jac \
JAC_COMPILER_LIB=off jac run repros/native_path_read_bytes.jac

JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-cache-sections/jac \
JAC_COMPILER_LIB=off jac build repros/native_path_read_bytes.jac --native \
  -o .jac/qp-path-read-bytes
```

The first command reports native demotion, runs in the server codespace, and prints
`PATH READ BYTES PASS 221`. The second fails with:

```text
error[E1030]: Type "Path" has no attribute "read_bytes"
```

`jac check scripts/png_checks.jac --print_errs` passes. Direct native compilation
of that module exposes the same E1030. Compiling its importer instead surfaces a
less useful `RuntimeError: Native dependency analysis failed: .../png_checks.jac`.

## Root location and proper next change

PR #9323 is no longer the intended direction, per the project owner's decision.
The proposal below targets the existing native runtime; no upstream implementation
has been made as part of the pickup work.

`jac/jaclang/runtime/na_stdlib/pathlib.jac` defines the native `Path` replacement,
but only exposes path construction, string/path operations, existence/directory
queries and resolution. Its definition also lacks `read_bytes` on
[upstream main](https://github.com/jaseci-labs/jac/blob/main/jac/jaclang/runtime/na_stdlib/pathlib.jac),
checked during this work.

Implement `Path.read_bytes() -> bytes` using the native file API, preserving binary
contents, closing the handle, and propagating file errors. Add native regression
coverage for empty/binary files and missing files. Then rebuild the PNG helper and
model harness; other unsupported APIs, if exposed next, must be addressed at their
actual runtime boundary rather than rewritten in the engine.

The dependency diagnostic also loses the underlying error in
`NaIRGenPass._ensure_dep_inference` in
`jac/jaclang/compiler/backends/native/na_ir_gen_pass.impl/core.impl.jac`.
Propagating the existing dependency diagnostics would make this failure actionable.

## Current project state

- Main executable builds successfully as `./qp`.
- All 133 engine/unit tests pass.
- Initial health/armor/shell pickup rendering and native application collection
  checks pass across all three games; this does not depend on the PNG helper.
- Native crouching, initial campaign transitions and health/death/restart checks pass.
- MDL/MD2/MD3 archive validation and model captures pass before adding the PNG
  comparison import; the Q3 armor capture shows the corrected material layers.
- The updated `scripts/alias_models_smoke.jac` cannot build natively until this gap
  is fixed. Its new time-separated pixel comparison has not run.
- Campaign/local-arena gameplay is unfinished. The agreed target is a playable
  prototype with a smaller combat roster, not complete original-game rosters.
