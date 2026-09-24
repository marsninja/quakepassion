# Native compiler dependencies for Passion lighting

The lighting acceptance checks now pass with a local source compiler. The
released binary and CI have not been validated against this patch set.

| Defect | Upstream fix | QuakePassion repro |
| --- | --- | --- |
| Native POSIX `expanduser` unavailable | [#9391](https://github.com/jaseci-labs/jac/pull/9391) | `repros/native_expanduser.jac` |
| `set(bytes)` fails lowering | [#9392](https://github.com/jaseci-labs/jac/pull/9392) | `repros/native_set_bytes.jac` |
| Tuple exception handlers miss matching exceptions | [#9394](https://github.com/jaseci-labs/jac/pull/9394) | `repros/native_oserror_handler.jac` |
| Native monotonic clocks use Linux's clock ID on macOS | [#9393](https://github.com/jaseci-labs/jac/pull/9393) (existing upstream PR) | `repros/native_monotonic_clock.jac` |
| Cached code can lose its foreign-library manifest | [#9406](https://github.com/jaseci-labs/jac/pull/9406) | See the upstream cache regressions |
| Native splitlines semantics affect persistence | [#9388](https://github.com/jaseci-labs/jac/pull/9388) | See the upstream regression |
| Function-local dicts with tuple values return corrupted lookups | [#9445](https://github.com/jaseci-labs/jac/pull/9445) | `games/items.jac` `special_rule` (powerup tables) |
| Typed edge connects drop inline attributes (`+>:E:name=n:+>`) | [#9446](https://github.com/jaseci-labs/jac/pull/9446) | `engine/world/arena.jac` competitor names |
| `any`/`all` over `and`/`or` comprehensions crash (untyped `any` arguments) | [#9451](https://github.com/jaseci-labs/jac/pull/9451) | `engine/world/arena.jac` `MatchTick` winner check |
| A user `floor` (and other C symbol names) collided with libc | [#9470](https://github.com/jaseci-labs/jac/pull/9470) (merged) | `engine/world/bot_routes.jac` |
| Same-named archetypes in different modules (`Passage`, `Holds`) share one identity | [#9472](https://github.com/jaseci-labs/jac/pull/9472) | Q3 AAS routing beside patrol edges |
| Native `dict ==` and nested containers compared by address | [#9475](https://github.com/jaseci-labs/jac/pull/9475) (merged) | `tests/bot_tactics_tests.jac` |
| `bytes.find` and the bytes search family not lowered | [#9478](https://github.com/jaseci-labs/jac/pull/9478) | `engine/formats/q1/wad.jac` status bar art |
| A JIT unit calls a linked unit's Python-only functions natively on a cold cache | [#9480](https://github.com/jaseci-labs/jac/pull/9480) | `tests/lightstyle_tests.jac` segfault |
| Event abilities named `drop` treated as destructor hooks | [#9486](https://github.com/jaseci-labs/jac/pull/9486) | `engine/world/flyers.jac` `FlyerTick` |
| `bytes(n)` and related bytes/bytearray constructors not lowered | [#9492](https://github.com/jaseci-labs/jac/pull/9492) | `engine/render/portal.jac` framebuffer textures |
| Cold builds drop libm-named `math` functions from the native layout (`sqrt`, `sin`, `cos` demoted) | [#9498](https://github.com/jaseci-labs/jac/pull/9498) | Any cold native build: 177 demotions |
| `jac run` treats a `window=` edge field as the browser global and moves modules to client code | [#9500](https://github.com/jaseci-labs/jac/pull/9500) | `games/passion/layout.jac` under `scripts/map_sweep.jac` |
| No pointers to C structs: out-params, retained pointers and C-owned buffers (new C interop surface) | [#9506](https://github.com/jaseci-labs/jac/pull/9506) | `engine/render/renderer.jac` pinned multi-buffered batch |

The Q3 bot, presentation and loose-ends milestones validate with upstream main
`245f3ab813` plus #9443, #9445–#9449, #9451, #9465, #9470, #9472, #9475, #9478,
#9480, #9486, #9492, #9498, #9500 and #9506, applied as patches (worktree
`/Users/marsninja/repos/jaseci-wt/qp-combined`). Earlier remaining-scope
milestones used upstream main `767d19193d` plus #9445, #9446 and #9451
(worktree `/Users/marsninja/repos/jaseci-wt/qp-scope-validation`). The open clock fix #9393
is not included: on this base it conflicts with the bundled native `math` module
from #9378, and the game only needs wall-clock time. Delete the project's `.jac/`
cache after changing compiler sources; a stale cache can make `math` fail to
lower.

The local compiler worktree is
`/Users/marsninja/repos/jaseci-wt/qp-lighting-validation`, branch
`validation/passion-lighting`, combining upstream main `2d533b666f` with these
five patches plus the cache-provenance fix in #9406. Set `JAC_DEV_SOURCE` to its `jac` directory and
`JAC_COMPILER_LIB=off`. No engine workaround replaces a failing Jac idiom.

## Regression evidence

The set/frozenset and tuple-handler fixes each pass Python/native identity under
nogc, rc, and gc. All 13 existing native set-hash tests and both nogc raises tests
pass. The tuple fix covers both native exception mechanisms and ownership
analysis. Both new PRs include release notes and pass local pre-commit checks.

The monotonic repro fails before #9393 and passes with it on this Mac. The
previous compiler used clock ID 1; the Darwin SDK defines `CLOCK_MONOTONIC` as
6. The existing upstream PR supplies the correct platform-specific ID. Its wider
time API has not been fully validated here. Earlier zero-second bake timing
reports are invalid and must not be used as performance evidence.

## Passion validation

- Native lighting-cache acceptance: 322,002 lightmap bytes and 1,280 probes;
  cold bake, byte-identical warm reload, probe round-trip, material cache-key
  invalidation, and corrupt-cache recovery pass.
- With #9393, one local run measured a 19.59 s cold bake and 28.56 ms warm load.
- Full graphical acceptance passes mixed assets, objective traversal,
  extraction, save/reload from Q1, replay, menu seed selection, and rollback.
- Theme and flash captures inspected. The flash test detects 15,142 brightened
  pixels above the HUD.
- Four-game gameplay profiling completes; Q3 `q3dm1` image validation has zero
  PVS/all-visible pixel differences at spawn and after movement.

These are local source-compiler results, not a claim that released-compiler CI
is green. See `docs/passion.md` for the lighting behavior and remaining limits.
