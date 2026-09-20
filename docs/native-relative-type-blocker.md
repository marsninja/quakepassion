# Native parent-relative imported type blocker

## Upstream fix

[Jac PR #9344](https://github.com/jaseci-labs/jac/pull/9344) fixes native
parent-relative resolution and a region TLS linkage regression discovered
while testing against current upstream. The original reproduction now builds
and prints `42`; 38 targeted compiler tests and precommit checks pass.
QuakePassion's current source also builds with this patched compiler, and its
Q1 graphical smoke run completes. The follow-up shared walking milestone now
passes movement checks on 12 Q1/Q2/Q3 maps and graphical menu checks in all
three games; see [movement status](player-movement-status.md) for limitations.
The blocker description below records the behavior before this fix.

The Q2/Q3 walking extension adds brush parsing, player-hull expansion and an
OSP broadphase to the shared collision layer. Extracting common BSP
records into `engine/formats/bsp.jac` exposed this compiler failure. No engine
import workaround has been applied.

## Minimal reproduction

Create these three files in an otherwise empty directory:

`formats/bsp.jac`:

```jac
obj Bsp { has value: int = 42; }
```

`formats/q1/bsp.jac`:

```jac
import from ..bsp { Bsp }
def parse() -> Bsp { return Bsp(); }
```

`main.jac`:

```jac
import from formats.q1.bsp { parse }
with entry { print(parse().value); }
```

Run from the directory containing `main.jac`:

```sh
jac check main.jac
jac build main.jac --native -o probe
```

The check passes, but the build demotes `parse` with
`Native lowering failed for signature type 'Bsp'`, followed by E5092 when
the native caller invokes it. Expected behavior: the executable prints `42`.

Confirmed with the local Jac 0.37.21 binary and with compiler source at
`f4ccd9d85749eedb050c097c393860ef7d384aed` (which includes the earlier cache
fix). This does not establish whether a newer upstream commit fixes it.

Diagnostic controls:

- Renaming the parent module to `records.jac` and importing `..records`
  still fails: equal module filenames are not required.
- Changing only that import to `formats.records` makes the native build
  succeed and print `42`.

These controls were isolated outside the engine. Upstream's
`jac/tests/compiler/backends/native/test_walkup_imports.jac` explicitly
tests native transitive relative imports, supporting that this is intended
syntax rather than an unsupported import idiom.

## Investigation starting point

In the upstream compiler, inspect parent-relative dependency/type binding
before native signature lowering. The failure surfaces in
`jac/jaclang/compiler/backends/native/na_ir_gen_pass.impl/types.impl.jac`,
especially `_resolve_sig_type`, `_resolve_jac_type`, and
`_emit_unlowerable_type`. The exact root cause is not yet established.

The previous Q1 movement validation results describe the earlier working snapshot;
the shared-format refactor requires the compiler fix above to build natively.
Q3 tessellated patch collision is now implemented; see the movement status for
its remaining fidelity limits.
