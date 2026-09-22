# Native list search equality

The Q2 infantry render harness exposed a native compiler defect: a dynamically built frame name passed equality and list membership, but `names.index(name)` raised `ValueError`.

```jac
with entry {
    names = ["attak201", "attak202"];
    needle = "attak" + str(201);
    assert needle == names[0];
    assert needle in names;
    print(names.index(needle));
}
```

Root cause: `NativeListEmitter.emit_index`, `emit_count`, and `emit_remove` used integer/pointer comparisons on shared list storage. The fix restores the receiver's declared element layout, uses native value equality, and records the comparison's actual continuation block for loop PHIs. Type restoration matters for bytes and nested lists, whose storage pointers otherwise look like strings.

Upstream PR: [jaseci-labs/jac#9420](https://github.com/jaseci-labs/jac/pull/9420), based on upstream main. Regression coverage includes independently allocated strings, duplicate removal/counting, floats and signed zero, bytes containing zero bytes, nested lists, and missing-index errors. The new regression plus eight selected existing primitive cases pass; upstream type checking and pre-commit checks pass.

The patch is applied locally in `/Users/marsninja/repos/jaseci-wt/qp-lighting-validation`. The original Jac `names.index(...)` call remains in `scripts/infantry_render_smoke.jac`; its native render now passes. This source patch is required until an installed compiler includes the upstream fix.
