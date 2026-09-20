# Native dependency cache reuses obsolete object layouts

The first door implementation exposed this compiler defect. Work paused under
AGENTS.md §3 until a root-cause compiler fix was available; no engine workaround
or automatic cache deletion was added. Development has resumed using the local
patched compiler. See [the completed door milestone](doors-status.md) for current
behavior and validation.

The root-cause compiler fix is now [upstream PR #9347](https://github.com/jaseci-labs/jac/pull/9347),
commit `cf6b69ebd2`, based on upstream main. It records the resolved native import
closure, including implementation annexes, as compile-time dependencies and
validates those dependencies before reusing cached demotion verdicts. Existing
JIR and dependency-IR freshness checks invalidate obsolete consumers; unchanged
builds still reuse their native cache.

The patched compiler is at `/Users/marsninja/repos/jaseci-wt/qp-layout-cache/jac`.
All three new object/node/inheritance regressions fail on unmodified main and
pass with the fix. Targeted upstream suites passed 248 tests (3 skipped);
QuakePassion passed all 71 tests, and the warm-cache reproducer returns `42` both
before and after the layout edit. Subsequent linked-door work is documented in the door milestone.

## Reproduce

On the local source compiler at `e481b77b5b` (the PR #9344 worktree):

```sh
JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-relative-types/jac \
JAC_COMPILER_LIB=off jac run repros/native_layout_cache.jac
```

The reproducer builds three temporary modules:

```jac
# record.jac
obj Record { has value: int = 42; }

# reader.jac
import from .record { Record }
def read(record: Record) -> int { return record.value; }

# main.jac
import from .record { Record }
import from .reader { read }
with entry { print(read(Record(value=42))); }
```

The first binary prints `42`. Change only `record.jac` to:

```jac
obj Record { has padding: int = 99, value: int = 42; }
```

Rebuild the same entry with the native cache retained. Expected: `42`.
Actual: **`99`**. The reader still accesses field slot zero. The reproducer
asserts the correct result, so it fails on the affected compiler. Recompiling the
reader without its old IR cache returns `42` again.

## Likely upstream location

`jac/jaclang/compiler/backends/native/impl/na_compile_pass.impl.jac`:

- `native_dep_cache_paths` keys dependency IR by the dependency's own source and
  compiler/options identity.
- `NativeCompilePass._compile_and_link_native_imports` accepts cached IR after checking recorded
  compile-time dependencies and options, but the imported type layout is not
  represented in this reader's freshness checks.
- `DepClibMeta` lists transitive dependency paths but does not attach their ABI
  fingerprints to this cache entry.

The proper fix is dependency-aware invalidation for ABI/layout changes, with a
warm-cache regression that edits a provider while leaving its consumer unchanged.
The existing interface/dependency fingerprint machinery should be investigated
before adding another cache identity mechanism. Cover objects, nodes, inherited
fields, and transitive imports as applicable.

## QuakePassion impact and remaining work

Adding `Face.motion` and `CollisionMap.models` left existing native consumers
reading obsolete layouts. The Q2 validator crashed; Q3 reported an out-of-range
list access. A diagnostic rebuild without the old native cache removed those
failures. This cache clear is evidence, not a shipped solution.

The provisional door implementation updates visible faces and collision offsets
together, handles timed return and obstructed motion, and reserves full movement
bounds in the collision index. Collision is also built before inline face origin
translation, avoiding a second origin translation for Q3 patch collision.

At initial discovery, five isolated door tests passed but the full suite had a
crashed patch-collision worker. With PR #9347's compiler, that suite passed all
71 tests. Subsequent linked-door work raises the suite to 74 passing tests and
validates 17 door groups across all three games, including graphical and
standing-player passage checks. Special activation and riding movers remain
future work, as detailed in [the door milestone](doors-status.md).
