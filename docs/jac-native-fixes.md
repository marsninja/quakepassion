# Jac native compiler fixes

QuakePassion builds as a native binary with Jac's native (LLVM) backend. When a
reasonable Jac idiom fails, the defect is fixed in jaseci-labs/jac rather than
worked around in the engine (AGENTS.md §3). This page records those defects and
their upstream fixes. It replaces the per-defect `*-blocker.md` notes, which
tracked the local patch stacks used while each fix was in review.

## Current compiler

The `jaseci` submodule pins the compiler source. It points at the `qp-pin`
branch of `marsninja/jac`: upstream main `842dbbc05`, plus two fixes merged
upstream after it (#9565, #9633) and six still in review (#9634, #9635, #9636,
#9638, #9639, #9640; below). `scripts/stage_compiler.sh` prepares that source
(and the typeshed stubs it needs) and prints the `JAC_DEV_SOURCE` to export,
so the released `jac` 0.37.23 binary compiles QuakePassion with the pinned
source. CI (`.github/workflows/jac-test.yml`) does the same and caches the
native compiler kernel per pin. No local patch stacks or compiler worktrees
are needed.

## Open upstream

In the pin:

| Defect | Upstream PR | Found by |
| --- | --- | --- |
| A suffix string view (`s[k:]`) escaped as an interior pointer into its source into lists, sets, dicts and tuples; with no refcount header below it, the cycle collector wrote into the source (a string literal: SIGBUS) | [#9634](https://github.com/jaseci-labs/jac/pull/9634) | The Q3 arena SIGBUS/SIGSEGV: the item pickup walker's `rule.kind[7:]`; `scripts/q3dm12_live_player_crash_repro.jac` |
| Mach-O binaries dropped internal function names, so crash reports and `sample` profiles showed no frames | [#9635](https://github.com/jaseci-labs/jac/pull/9635) | Profiling model lighting |
| The native cycle collector's cost followed the live graph, not the garbage: acyclic objects were buffered as roots and every collection retraced the live graph, making frames 5-10x slower than without it (base1 rendered in 8.1 ms against 0.8 ms under the `rc` profile; model lighting e1m1 2.56 to 0.45 ms, base1 9.96 to 0.87 ms with the fix) | [#9636](https://github.com/jaseci-labs/jac/pull/9636) | `scripts/profile_model_lighting.jac` |
| A native module's Python side did not bind the C declarations it names (`Matrix` imports failed) | [#9638](https://github.com/jaseci-labs/jac/pull/9638) (supersedes the closed #9627) | `tests/effect_quads_tests.jac` |
| A cycle collection could start inside a destructor, while the dying container was still reachable, and trace elements already freed (heap corruption when a large list was dropped) | [#9639](https://github.com/jaseci-labs/jac/pull/9639) | The Q3 arena SIGBUS/SIGSEGV: closing the asset library (`self.archives = []`) |
| Native `bytes.decode` ignored its encoding and `errors` arguments (`errors=` was rejected with E5092) and raised no `UnicodeDecodeError` | [#9640](https://github.com/jaseci-labs/jac/pull/9640) | `scripts/audit_campaigns.jac`, `scripts/shoot_door_smoke.jac`; repro `repros/native_decode_errors.jac` |

Found in QuakePassion work but not needed by it (not in the pin):

| Defect | Upstream PR | Found by |
| --- | --- | --- |
| `bytes.join` had no native lowering, so a function joining bytes was demoted to Python | [#9625](https://github.com/jaseci-labs/jac/pull/9625) | A native build of the cinematic player |
| An override in another module of a base class compiled without a vtable was silently skipped by the base's own methods; the fix reports E5113 | [#9631](https://github.com/jaseci-labs/jac/pull/9631) | |

## Known open defect

Under the `nogc` memory mode, `except X as e { return "..." + str(e); }`
aborts with `malloc`'s "pointer being freed was not allocated" when the
exception message is a static literal (a plain `raise ValueError("boom")`).
It is why upstream's `test_native_user_exceptions` fails under `nogc`. No
upstream fix exists yet. QuakePassion builds with the default `managed` mode,
so the game is not affected. The released `jac` 0.37.21 reproduces it
(2026-09-29): the same program prints the message under `--memory managed`
and exits with SIGABRT under `--memory nogc`.

## Resolved (merged upstream)

| Defect | Upstream PR | Repro or first failure |
| --- | --- | --- |
| `visit [list[i]]` inside a walker loop emitted malformed IR, then double-freed the coerced list | [#9318](https://github.com/jaseci-labs/jac/pull/9318) | `repros/native_visit_list.jac` (run in CI) |
| `bytearray.extend` rejected integer lists (E5092) | [#9325](https://github.com/jaseci-labs/jac/pull/9325) | Q3 loader palette setup |
| A C function returning an integer was converted as a same-width imported C struct | [#9336](https://github.com/jaseci-labs/jac/pull/9336) | `int(GetMouseX())` beside raylib's `Color` |
| Native code calling a C library segfaulted when restored from the cache in a later process | [#9342](https://github.com/jaseci-labs/jac/pull/9342) | Second `jac test` run exited 139 |
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
| A boolean comprehension passed to `any`/`all` took pointer storage from its source and crashed | [#9441](https://github.com/jaseci-labs/jac/pull/9441) | Jump-routing tests |
| User archetypes could shadow OSP kernel record names | [#9443](https://github.com/jaseci-labs/jac/pull/9443) | Passion generator (`obj Slot` in a walker) |
| Dict reads of tuple values lost their layout | [#9445](https://github.com/jaseci-labs/jac/pull/9445) | `games/items.jac` powerup tables |
| Typed edge connects dropped inline attributes | [#9446](https://github.com/jaseci-labs/jac/pull/9446) | `engine/world/arena.jac` competitor names |
| `sum` accumulated outside the elements' and start value's numeric type | [#9447](https://github.com/jaseci-labs/jac/pull/9447) | Passion generator (float weights) |
| An imported `:priv` function took the importer's same-named public import | [#9448](https://github.com/jaseci-labs/jac/pull/9448) | Passion generator |
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
| A unit's layout dropped its own functions named after an imported C extern; cold builds demoted `Vec3.length` and about 190 callers | [#9495](https://github.com/jaseci-labs/jac/pull/9495) | Cold native build |
| Cold builds dropped libm-named `math` functions from the native layout | [#9498](https://github.com/jaseci-labs/jac/pull/9498) | Any cold native build |
| A `window=` field was taken for the browser global under `jac run` | [#9500](https://github.com/jaseci-labs/jac/pull/9500) | `games/passion/layout.jac` under `scripts/map_sweep.jac` |
| C pointers, C-layout structs and pinned buffers for C interop | [#9506](https://github.com/jaseci-labs/jac/pull/9506) | `engine/render/renderer.jac` batches |
| OSP adjacency scanned the whole edge list per typed hop and unlink | [#9536](https://github.com/jaseci-labs/jac/pull/9536) | Q2 base1 frame 76-83 ms to 14 ms |
| A demotion verdict outlived the fix to the module that caused it | [#9537](https://github.com/jaseci-labs/jac/pull/9537) | `games/weapons.jac` stayed on the Python fallback |
| Sorting tuples, bytes and lists compared the wrong values | [#9561](https://github.com/jaseci-labs/jac/pull/9561) | Collision BVH build, effect depth order, nearest-light choice |
| `isinstance` missed subclasses from modules the checker never imported | [#9562](https://github.com/jaseci-labs/jac/pull/9562) | Q3 bots' powerup shells; `repros/native_bot_powerup_shells.jac` |
| Exception frames armed with `setjmp`, a signal-mask syscall per walker spawn on macOS | [#9564](https://github.com/jaseci-labs/jac/pull/9564) | Profiles of walker spawns |
| `list[tuple[T, ...]]` stored fixed-arity tuples it read back as sequences (crash or garbage) | [#9565](https://github.com/jaseci-labs/jac/pull/9565) | |
| Optional objects stored into module globals were not retained, so reads saw freed memory | [#9566](https://github.com/jaseci-labs/jac/pull/9566) | Spurious "integer overflow" and division errors |
| Every `spawn` leaked its report list | [#9568](https://github.com/jaseci-labs/jac/pull/9568) | Walkers spawned each 120 Hz tick |
| `struct.unpack` leaked a temporary slice argument | [#9569](https://github.com/jaseci-labs/jac/pull/9569) | About 25 MB leaked per BSP load |
| A module's cycle collector could not trace other modules' objects, so cross-module cycles were never reclaimed | [#9573](https://github.com/jaseci-labs/jac/pull/9573) | Cross-module cycles in the engine's graph |
| `with Node entry` did not match every node; Node-typed collections lost identity | [#9576](https://github.com/jaseci-labs/jac/pull/9576) | `tests/level_teardown_tests.jac` |
| Graph nodes and edges were immortal (never reclaimed) | [#9577](https://github.com/jaseci-labs/jac/pull/9577) | `tests/level_teardown_tests.jac`, level-change leak |
| Python-side imports of native-only modules; tuples in variadic slots | [#9593](https://github.com/jaseci-labs/jac/pull/9593) | |
| A C-anchored module lost its Python side under `jac run`'s server default (#9375 with #9593) | [#9633](https://github.com/jaseci-labs/jac/pull/9633) | Upstream main CI |

Three PRs closed unmerged: #9323 (an alternative stdlib approach, not needed),
#9627 (replaced by #9638) and #9533 (a guard against calling an extern no unit defines, from a
`tests/monster_tactics_tests.jac` segfault on a cached build). That test is part
of the suite CI runs; the segfault was not re-investigated for this record.

## Repros kept in the tree

`repros/` and `scripts/repros/` hold the minimal programs above. CI builds and
runs `repros/native_visit_list.jac`, `repros/native_quake_asset_ops.jac` and
`scripts/repros/native_sorted_set.jac` natively on every push.
`scripts/q3dm12_live_player_crash_repro.jac` is the headless arena soak for
#9634 and #9639 (built natively, it should finish every map with exit 0).
