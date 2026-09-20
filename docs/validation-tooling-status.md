# Jac validation tooling

The maintained validation runners are now `scripts/validate_quake.jac` and
`scripts/validate_menu.jac`. Their Python predecessors are removed. The menu
runner builds `scripts/menu_smoke.jac`, the existing native input-event harness.
The runners use Jac's hosted execution with standard-library imports; the viewer
and menu harness remain native executables.

`scripts/png_checks.jac` shares PNG decoding and pixel comparisons. Four unit
tests cover all five PNG filters for RGB/RGBA, counting pixels rather than
channels, blank-image rejection, and unsupported filters. Camera movement is
checked using decoded pixels, and the menu runner checks each screenshot.

## Verified locally

- Six Q1, three Q2, and three Q3 maps passed through the Jac runner.
- All 24 spawn/moved visibility comparisons had zero differing pixels.
- The complete native menu input and game-switching sequence passed through
  the Jac wrapper, including all six screenshot checks.
- All 44 unit tests passed on the first run with the released Jac 0.37.21
  binary (26.75 seconds), with no source override or compiler patches.
- The four image tests also passed independently with a populated cache;
  the nine existing phase-one tests passed independently as well.

## Unresolved compiler crash on repeated full-suite runs

The issue first appeared with the staged 0.37.19 compiler and persists with
the released macOS ARM64 Jac 0.37.21 binary. Its SHA-256 was verified against
the release checksum. The first full-suite run passed; the next exited 139.
The repository no longer selects `.jac/compiler` and no parser override is set.
The reproduction sequence is:

```sh
jac clean --cache --force
jac test -j0
jac test -j0
```

The failure is exit 139 before test results. On the prior staged compiler it
also reproduced with graphical validation stopped and with
`PYTHONFAULTHANDLER=1`. This is a repository-level reproduction; it has not yet
been reduced to a single failing Jac expression. Clearing the cache was a
diagnostic step, not an added prerequisite or workaround in CI or the runners.

The earlier staged-compiler macOS crash report includes `SHA256_Final`, `ossl_blake2s_final`, and
`EVP_DigestFinal_ex`. The compiler's cache/content hashing in
`jaclang/compiler/driver/jir.jac` and cached module loading in
`jaclang/compiler/driver/impl/compiler.impl.jac` are starting points for
investigation; the stack alone does not establish the root cause.

Local release evidence: `/tmp/qp-release-tests.log` and
`/tmp/qp-release-tests-warm.log`. Earlier staged-compiler evidence:
`/tmp/qp-validators-all-tests-clean.log`,
`/tmp/qp-validators-warm-tests.log`, `/tmp/qp-validators-crash-trace.log`, and
`~/Library/Logs/DiagnosticReports/jac-2026-09-19-213540.ips`.

The Python staging helper and six temporary patches have been removed because
all seven upstream fixes are included in Jac 0.37.21. Native visit, asset,
sorting, bytearray, and aggregate C ABI reproductions pass with the released
binary. CI now uses that binary and runs the full suite twice to exercise cache
reuse. The repeated-run crash remains unresolved; no engine or test idiom has
been rewritten to bypass it.
