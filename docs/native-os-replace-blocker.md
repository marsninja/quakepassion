# Native atomic file replacement silently does nothing

Prototype save/load and persistent settings use the standard atomic-write pattern:
write a sibling temporary file, close it, then `os.replace(temporary, destination)`.
The current native compiler accepts that call but emits no file replacement.

## Reproduction

`repros/native_os_replace.jac` writes `new` to a source file and `old` to an existing
destination, replaces the destination, then checks both file contents and source
removal. With the local integration compiler (main `3ad0e0104b` plus fixes from
upstream #9354, #9357 and #9358):

```sh
JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-gameplay-local/jac \
JAC_COMPILER_LIB=off jac build repros/native_os_replace.jac --native \
  -o .jac/qp-replace
./.jac/qp-replace
```

The build succeeds; execution aborts on `assert not os.path.exists(source)`.
Both files remain, and the destination still contains `old`. The native binary
imports `fopen` and `fwrite`, but no `rename` or replacement routine.

The same source passes with `jac run --backend python
repros/native_os_replace.jac` (`NATIVE REPLACE PASS`). Automatic `jac run` selects
the native path here and fails like the standalone binary.

The integrated combat/save harness leaves `.jac/combat-save-q1.txt.tmp` and then
fails with `No such file or directory` when it tries to read the intended final
save file. No existing save was overwritten in this validation.

## Root locations and proper fix

Within `jac/jaclang/compiler/backends/native/`:

- `na_constants.jac`: `NATIVE_OS_FUNCS` includes `rename` but not `replace`.
- `na_ir_gen_pass.impl/objects.impl.jac`: native `os` dispatch only routes names
  in that set to `_emit_os_call`.
- `na_ir_gen_pass.impl/os.impl.jac`: the rename emitter exists, but no replace
  implementation exists. The rename emitter also discards its error return.
- An unsupported call used as a statement reaches a successful native build
  without a lowering diagnostic. The compiler must reject missing implementations
  instead of silently dropping side effects.

The proper upstream change should implement replacement through `na_stdlib` with
platform-correct replacement and error propagation, and reject unsupported native
calls. Regressions should cover replacing an existing destination, creating a new
one, absent sources, invalid destination paths, and both call import styles.

## Project boundary

The upstream fix is available in [PR #9361](https://github.com/jaseci-labs/jac/pull/9361)
on branch `fix/native-os-replace`. It implements string-path replacement through
`na_stdlib`, preserves native OS intrinsics, and rejects unsupported OS calls.
The original standalone reproducer passes with that compiler. Its focused tests
pass (7 tests), as does the native code generation suite (225 passed, 3 skipped).
The combined gameplay compiler now passes the integrated combat/save/audio
harness on all three games, plus app-level save restoration and corrupt-save
rejection. Settings reload exposes a separate [splitlines defect](native-splitlines-blocker.md).
The results below describe the earlier run.

The full regression run passes 148 collected tests. Combat's four focused tests and snapshot serialization's two tests pass. Before
adding save I/O, the native combat harness passed Q1/Q2/Q3 shooting, killing and
Q3 respawn checks, with desktop captures inspected. The expanded harness builds
and initializes Q1 archive-backed audio but cannot complete its save/load stage.
Persistent settings use the same blocked atomic-write helper.

No direct overwrite, alternate rename API, shell command, or Python fallback was
added. Per AGENTS.md §3, gameplay expansion pauses for the upstream defect. The
full prototype is not complete: persistence validation, campaign progression and
broader gameplay acceptance still remain.
