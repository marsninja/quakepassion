# Campaign enemy expansion

Q1 soldiers, dogs, knights, enforcers and ogres now have separate definitions.
Dogs and knights close to melee distance; enforcers fire traveling laser bolts;
ogres throw bouncing grenades and use melee at close range. Q2's light soldier
fires traveling blaster bolts, and soldier variants use their original 0/2/4
skins and 20/30/40 health. Infantry has 100 health. Shared steering probes now
start at the actor's body origin rather than its eye position.

These are combat foundations, not complete original enemy behavior. Attack-frame
scheduling, randomized damage, dog leaps, chainsaw sweeps, double-shot enforcers,
pain/death/gib sequences, drops, infighting, exact actor hull sizes and navigation
remain open. The rest of both original rosters and bosses remain unsupported.
Enemy missiles currently target the player directly; splash can hurt other
opponents without granting player kill credit. Direct monster-on-monster missile
hits and attacker attribution require further work.

Hostile missiles use the shared projectile graph, world collision, damage,
explosions and visual effects. Their ownership survives snapshots. Enemy splash
does not receive the player's self-damage reduction. Melee and instant attacks
require fresh line of sight; traveling missiles must actually reach the player.

Save format **6** rejects older snapshots because adding enemies changes the
positional entity records. Map and campaign-envelope readers now share a single
format identifier. Saved Q2 hub records use the same version as the active map.

Focused tests cover melee range/occlusion, projectile flight and ownership after
save/load, walls, splash and God mode. Native asset checks pass all nine
supported Q1/Q2 definitions. Native combat checks pass Q1 e1m1 (23 enemies), Q2
base1 (17 enemies), the BFG phase sequence and the local Q3 ten-frag loop.

Sources:
- https://github.com/id-Software/Quake-Tools/tree/master/qcc/v101qc
- https://github.com/id-Software/Quake-2/blob/master/game/m_soldier.c

The full game regression suite passes **237 tests** with the locally patched
compiler, including a separate warm-cache culling rerun. The native campaign
harness passes Q2 hub revisits, cross-game save/load, carried grenade state,
rollback and unit reset, plus Q1 e1m2 key pickup/unlock and onward e1m3 loading.
The main native viewer builds successfully. Spawn filtering and shootable-button
checks also pass on Q2 base1; see [spawn rules](spawn-rules-status.md).

The test crash was a compiler-cache provenance defect, fixed in upstream
[Jac PR #9406](https://github.com/jaseci-labs/jac/pull/9406). Source compiler
patches are still required; these results do not certify the released binary.
