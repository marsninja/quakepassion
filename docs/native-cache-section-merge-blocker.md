# Native cache metadata can bless obsolete executable sections

This defect interrupted button/relay validation under AGENTS.md §3. A local
root-cause compiler fix now allows validation to resume; no engine workaround or
cache-clearing build step was added. The compiler worktree is
`/Users/marsninja/repos/jaseci-wt/qp-cache-sections/jac`.

The fix rejects merging old cache sections when their dependency records are
stale or incoming dependency metadata changes. Four new cache regression tests
and 24 existing interface-cache tests pass. The original relay test and the
full 82-test engine suite pass with this compiler. Upstream publication of this
additional fix is still pending (local commit `381b68dc3b`).

## Observed failure

`tests/signal_tests.jac` contains a cyclic relay graph and the ordinary
`here in self.seen` visit-once guard. Re-running that test hangs and allocates
memory continuously. Its identical source copied to a fresh test path passes
in 3.83 seconds. Standalone native compilation of the same guarded walker also
terminates correctly. The hanging processes were stopped.

Inspection of the two cached native bitcode sections establishes the discrepancy:

- The original test's `Fire.deliver` starts with `self.emit`, without either the
  current `here.enabled` check or the `seen` guard/append.
- The fresh test's handler contains the enabled check and visit-once guard.
- Both caches record the same current `signals.jac` body digest, and
  `ct_deps_fresh` returns true for both.

The artifacts and decoded LLVM are preserved under ignored
`.jac/diagnostics/signal-cache/`. The fresh test copy was removed; renaming tests
is not a solution. Simple CLI dependency/body-edit tests invalidate correctly,
so the complete CLI sequence responsible for the original artifact has not yet
been reduced to a portable reproduction.

## Minimal cache-layer reproduction

```sh
JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-layout-cache/jac \
JAC_COMPILER_LIB=off jac run repros/native_cache_section_merge.jac
```

The repro writes an opaque native payload with an imported-body digest, changes
that dependency, and performs a metadata-only cache refresh. It then observes:

```text
Metadata fresh: True Old native code retained: True
Error: Metadata refresh retained obsolete native code
```

It uses an opaque payload deliberately: this is a cache-writer regression and
requires no executable machine code. It reproduces the unsafe preservation rule
behind the observed stale-code/current-metadata combination.

## Upstream location and fix direction

In `jac/jaclang/compiler/driver/jir.jac`, `_mergeable_sections` (around line 1063)
checks source/environment keys but not the freshness of the old dependency
metadata. `write_module_cache` merges old executable sections with incoming
metadata, overwriting `SEC_CTDEPS` without requiring matching newly compiled code.

`InterfaceCache._persist_in_context` in `driver/ifacecache.jac` (around line 935)
can refresh dependency sections without generating native code. This is a likely
route to the inconsistent artifact; the exact CLI trigger still needs isolation.
The cache reader then sees fresh dependencies and restores `SEC_NATIVE_OBJ`.

The fix should reject preservation of executable sections when their recorded
dependencies are stale or their dependency provenance changes. New metadata must
not certify old code. Add regressions for metadata-only refreshes and unchanged
cache reuse, including native bitcode/LLVM, bytecode and interop consistency.

Reproduced with the local #9347 compiler (cf6b69ebd2). That patch addresses
recording/checking imported layout dependencies; it does not guard this cache
section merge. No claim is made here about an untested newer upstream revision.
