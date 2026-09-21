# Native splitlines adds a trailing empty record

The combined integration compiler uses upstream main `cef4810100` plus the code
fixes from #9354, #9357 and #9361. Its local checkout is
`/Users/marsninja/repos/jaseci-wt/qp-prototype-validation` (HEAD `41db5f4851`).

Combat, native save replacement, fresh-world quickload, malformed-save rollback,
and cross-game restoration now pass on Q1 `e1m1`, Q2 `base1`, and Q3 `q3dm1`.
Settings write successfully, but loading the valid two-line settings file raises
`ValueError("Invalid settings version")`.

## Minimal reproduction and cause

`repros/native_splitlines.jac` reproduces the mismatch independently of assets:

```sh
export JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-prototype-validation/jac
export JAC_COMPILER_LIB=off
jac build repros/native_splitlines.jac --native -o .jac/qp-splitlines
./.jac/qp-splitlines
jac run --backend python repros/native_splitlines.jac
```

Native execution prints `LINES 3`, including an extra empty record, and aborts on
the two-line assertion. Python prints `LINES 2` and `SPLITLINES PASS`.

In upstream `jac/jaclang/compiler/backends/native/impl/primitives_native.impl.jac`,
`NativeStrEmitter.emit_splitlines` (line 1230 at this revision) calls
`_codegen_str_split(target, "\n")`. That is not splitlines semantics: it adds a
trailing empty record, mishandles empty input and other line boundaries, and
ignores `keepends`. Existing `prim_str.jac` coverage uses `"a\nb\nc"`, which
does not expose the trailing-line defect.

The proper fix belongs in the native string implementation, with backend parity
tests for empty input, final separators, consecutive separators, CRLF/CR and
other supported line boundaries, and `keepends`. The engine parser remains
unchanged, per AGENTS.md section 3.

## App acceptance harness

`scripts/persistence_smoke.jac` exercises the actual App quicksave/quickload
methods, corrupt snapshot rejection, cross-game restoration and preferences.
It requires an isolated HOME, containing a link to the game assets:

```sh
jac build scripts/persistence_smoke.jac --native -o .jac/qp-persistence-validation
qp_validation_home=$(mktemp -d /tmp/qp-persistence.XXXXXX)
ln -s "$HOME/quake-assets" "$qp_validation_home/quake-assets"
HOME="$qp_validation_home" QP_VALIDATE_HOME="$qp_validation_home" \
DYLD_LIBRARY_PATH="$PWD/vendor" .jac/qp-persistence-validation
```

The macOS run prints `PERSISTENCE PASS` for all three games, then fails when
loading settings. `PREFERENCES PASS` and settings reset remain unvalidated.
`scripts/combat_smoke.jac` completes independently for all three games, including
archive sound loading/play calls and Q3 bot respawn. This is not a subjective
audio-quality check or full manual gameplay acceptance.
