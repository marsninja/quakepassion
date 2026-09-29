# Jac native compiler fixes

QuakePassion builds as a native binary with Jac's native (LLVM) backend. When a
reasonable Jac idiom fails, the defect is fixed in jaseci-labs/jac rather than
worked around in the engine (AGENTS.md §3). This page records those defects and
their upstream fixes. It replaces the per-defect `*-blocker.md` notes, which
tracked the local patch stacks used while each fix was in review.

## Current compiler

The `jaseci` submodule pins the compiler source. It points at the `qp-pin`
branch of `marsninja/jac`: upstream main `842dbbc05` plus three fixes still in
review (below). `scripts/stage_compiler.sh` prepares that source (and the
typeshed stubs it needs) and prints the `JAC_DEV_SOURCE` to export, so the
released `jac` 0.37.23 binary compiles QuakePassion with the pinned source.
CI (`.github/workflows/jac-test.yml`) does the same and caches the native
compiler kernel per pin. No local patch stacks or compiler worktrees are needed.

## Open upstream

| Defect | Upstream PR | Found by |
| --- | --- | --- |
| Mach-O binaries dropped internal function names, so crash reports and `sample` profiles showed no frames | [#9635](https://github.com/jaseci-labs/jac/pull/9635) (open, in the pin) | Profiling model lighting |
| The native cycle collector's cost followed the live graph, not the garbage; it was most of a frame (e1m1 2.56 to 0.45 ms, base1 9.96 to 0.87 ms model lighting) | [#9636](https://github.com/jaseci-labs/jac/pull/9636) (open, in the pin) | `scripts/profile_model_lighting.jac` |
| A native module's Python side did not bind the C declarations it names (`Matrix` imports failed) | [#9638](https://github.com/jaseci-labs/jac/pull/9638) (open, in the pin; supersedes the closed #9627) | `tests/effect_quads_tests.jac` |
| `bytes.decode(..., errors="replace")` is rejected natively (E5092), and the native decode ignores its arguments | No PR yet | `scripts/audit_campaigns.jac`, `scripts/shoot_door_smoke.jac`; repro `repros/native_decode_errors.jac` |

The decode defect affects only those two audit harnesses, which run under
`jac run`; the game itself decodes with plain UTF-8. The pinned source's
`NativeBytesEmitter.emit_decode` still copies bytes without an error policy.

## Resolved (merged upstream)

| Defect | Upstream PR | Repro or first failure |
| --- | --- | --- |
| `visit [list[i]]` inside a walker loop emitted malformed IR, then double-freed the coerced list | [#9318](https://github.com/jaseci-labs/jac/pull/9318) | `repros/native_visit_list.jac` (run in CI) |
| Parent-relative imported types failed to resolve; region TLS linkage regression | [#9344](https://github.com/jaseci-labs/jac/pull/9344) | Engine build after the walking work |
| Cached consumers kept obsolete object layouts after an imported layout changed | [#9347](https://github.com/jaseci-labs/jac/pull/9347) | `repros/native_layout_cache.jac` |
| `Path.read_bytes()`, file errors and mutable zlib buffers not native | [#9354](https://github.com/jaseci-labs/jac/pull/9354) | `repros/native_path_read_bytes.jac`, PNG checks |
| Numeric iterable `min`/`max` | [#9357](https://github.com/jaseci-labs/jac/pull/9357) | PNG decoder |
| Reused extern declarations with conflicting address types (`read_bytes` + `os.listdir`) | [#9358](https://github.com/jaseci-labs/jac/pull/9358) | `repros/native_file_listdir.jac` |
| `os.replace` compiled to nothing | [#9361](https://github.com/jaseci-labs/jac/pull/9361) | `repros/native_os_replace.jac` (atomic saves and settings) |
| Bundled native `math`/`cmath` | [#9378](https://github.com/jaseci-labs/jac/pull/9378) | Lighting bake |
| `str.splitlines` added a trailing empty record and ignored `keepends` | [#9388](https://github.com/jaseci-labs/jac/pull/9388) | `repros/native_splitlines.jac` (settings reload) |
| `os.path.expanduser` not native | [#9391](https://github.com/jaseci-labs/jac/pull/9391) | `repros/native_expanduser.jac` (Passion light cache) |
| `set(bytes)` / `frozenset(bytes)` | [#9392](https://github.com/jaseci-labs/jac/pull/9392) | `repros/native_set_bytes.jac` |
| Monotonic clocks used Linux's clock ID on macOS | [#9393](https://github.com/jaseci-labs/jac/pull/9393) | `repros/native_monotonic_clock.jac` |
| Tuple exception handlers missed matching exceptions | [#9394](https://github.com/jaseci-labs/jac/pull/9394) | `repros/native_oserror_handler.jac` |
| Cache metadata refresh kept obsolete native sections and dropped the foreign-library manifest | [#9406](https://github.com/jaseci-labs/jac/pull/9406) | `repros/native_cache_section_merge.jac`, `tests/signal_tests.jac` hang |
| `list.index`/`count`/`remove` compared by address | [#9420](https://github.com/jaseci-labs/jac/pull/9420) | `scripts/infantry_render_smoke.jac` |
| User archetypes could shadow OSP kernel record names | [#9443](https://github.com/jaseci-labs/jac/pull/9443) | Passion generator (`obj Slot` in a walker) |
| Dict reads of tuple values lost their layout | [#9445](https://github.com/jaseci-labs/jac/pull/9445) | `games/items.jac` powerup tables |
| Typed edge connects dropped inline attributes | [#9446](https://github.com/jaseci-labs/jac/pull/9446) | `engine/world/arena.jac` competitor names |
| `round` halves and `ndigits` | [#9449](https://github.com/jaseci-labs/jac/pull/9449) | Passion generator |
| `any`/`all` over `and`/`or` comprehensions crashed | [#9451](https://github.com/jaseci-labs/jac/pull/9451) | `MatchTick` winner check |
| Checker: `with` alias typed through `__enter__` | [#9465](https://github.com/jaseci-labs/jac/pull/9465) | |
| User definitions named after C symbols (`floor`) collided with libc | [#9470](https://github.com/jaseci-labs/jac/pull/9470) | `engine/world/bot_routes.jac` |
| Same-named archetypes in different modules shared one identity | [#9472](https://github.com/jaseci-labs/jac/pull/9472) | Q3 AAS routing beside patrol edges |
| Dicts and nested containers compared by address | [#9475](https://github.com/jaseci-labs/jac/pull/9475) | `tests/bot_tactics_tests.jac` |
| `bytes.find` and the bytes search family not lowered | [#9478](https://github.com/jaseci-labs/jac/pull/9478) | `engine/formats/q1/wad.jac` |
| A JIT unit called a linked unit's Python-only functions on a cold cache | [#9480](https://github.com/jaseci-labs/jac/pull/9480) | `tests/lightstyle_tests.jac` segfault |
| Event abilities named `drop` treated as destructors | [#9486](https://github.com/jaseci-labs/jac/pull/9486) | `engine/world/flyers.jac` |
| `bytes(n)` / `bytearray` constructors not lowered | [#9492](https://github.com/jaseci-labs/jac/pull/9492) | `engine/render/portal.jac` |
| Cold builds dropped libm-named `math` functions from the native layout | [#9498](https://github.com/jaseci-labs/jac/pull/9498) | Any cold native build |
| A `window=` field was taken for the browser global under `jac run` | [#9500](https://github.com/jaseci-labs/jac/pull/9500) | `games/passion/layout.jac` under `scripts/map_sweep.jac` |
| C pointers, C-layout structs and pinned buffers for C interop | [#9506](https://github.com/jaseci-labs/jac/pull/9506) | `engine/render/renderer.jac` batches |
| OSP adjacency scanned the whole edge list per typed hop and unlink | [#9536](https://github.com/jaseci-labs/jac/pull/9536) | Q2 base1 frame 76-83 ms to 14 ms |
| A demotion verdict outlived the fix to the module that caused it | [#9537](https://github.com/jaseci-labs/jac/pull/9537) | `games/weapons.jac` stayed on the Python fallback |
| `with Node entry` did not match every node; Node-typed collections lost identity | [#9576](https://github.com/jaseci-labs/jac/pull/9576) | `tests/level_teardown_tests.jac` |
| Graph nodes and edges were immortal (never reclaimed) | [#9577](https://github.com/jaseci-labs/jac/pull/9577) | `tests/level_teardown_tests.jac`, level-change leak |
| Python-side imports of native-only modules; tuples in variadic slots | [#9593](https://github.com/jaseci-labs/jac/pull/9593) | |

Two PRs closed unmerged: #9323 (an alternative stdlib approach, not needed) and
#9533 (a guard against calling an extern no unit defines, from a
`tests/monster_tactics_tests.jac` segfault on a cached build). That test is part
of the suite CI runs; the segfault was not re-investigated for this record.

## Repros kept in the tree

`repros/` and `scripts/repros/` hold the minimal programs above. CI builds and
runs `repros/native_visit_list.jac`, `repros/native_quake_asset_ops.jac` and
`scripts/repros/native_sorted_set.jac` natively on every push.
