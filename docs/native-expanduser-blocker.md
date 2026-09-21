# Native home-directory expansion: original lighting blocker

Upstream fix: [jac PR #9391](https://github.com/jaseci-labs/jac/pull/9391),
branch `fix/native-expanduser`, commit `729c80142c`. The original repro now
builds and runs with that compiler. The native expansion matrix passes 350
comparisons against Python on macOS.

Lighting and graphical acceptance subsequently passed with the combined
compiler patches. See [current validation results](native-lighting-validation-blockers.md).
The remainder of this document records the original failure and draft status.

The lighting work on `feature/passion-lighting` is a draft, not a validated
release. Its cache path uses `os.path.expanduser("~/.cache/quakepassion/lighting")`.
The Python pathway accepts this, but native compilation rejects it with E5090:

```
Native pathway does not yet support os.path member 'expanduser'
```

Minimal reproduction: `repros/native_expanduser.jac`.

```
JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-merged-validation/jac JAC_COMPILER_LIB=off jac run repros/native_expanduser.jac
JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-merged-validation/jac JAC_COMPILER_LIB=off jac build repros/native_expanduser.jac --native -o .jac/repro-expanduser
```

Confirmed against the local compiler checkout used for Passion. This is a
missing native standard-library capability, rather than a bad call signature.
Upstream's own CLI uses this idiom in
`jaclang/cli/commands/impl/tools.impl.jac`.

The native dispatcher rejects the member at
`jaclang/compiler/backends/native/na_ir_gen_pass.impl/objects.impl.jac:2724`.
`NATIVE_OSPATH_FUNCS` in `na_constants.jac` lacks `expanduser`, as does
`jaclang/runtime/na_stdlib/os/path.jac`. The proper upstream extension should
provide the native library operation and support qualified, direct, and aliased
imports. Cover HOME overrides, unchanged non-tilde paths, bare tilde,
tilde/slash paths, named-user lookup, and unavailable home directories according
to the target platform's semantics; retain the na_stdlib approach.

Per AGENTS.md section 3, the engine has not been rewritten to avoid this call.
The complete native application build stops at this dependency. No new native
rendering, cache performance, or graphical acceptance results are claimed.

## Draft work completed before the blocker

- Room light fixtures, colored direct illumination, two-sample static shadows.
- Lightmap atlas integration, per-room interpolated directional model probes.
- Moving-door probe illumination; doors excluded from static shadow baking.
- Eight-light combat effect budget using existing flash timers.
- Versioned SHA-256 cache keys over geometry, materials, and lamp parameters;
  payload integrity checks and atomic cache writes.
- Three Python-path unit tests passed: blockers/normals/color, interpolation,
  and probe serialization/invalid data.

Still required after the upstream extension: native execution, visual tuning,
cache cold/warm/corruption acceptance, load-time and frame-time measurements,
all-game regression checks, and documentation of the final behavior. Lighting
currently uses an ambient floor plus direct light, not bounced-light radiosity.
Transient lights do not cast dynamic shadows.
