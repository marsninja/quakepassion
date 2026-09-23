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

The remaining-scope milestones validate with upstream main `767d19193d` plus
#9445, #9446 and #9451, applied as patches (worktree
`/Users/marsninja/repos/jaseci-wt/qp-scope-validation`). The open clock fix #9393
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
