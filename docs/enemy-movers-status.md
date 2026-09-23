# Enemy interaction with doors and platforms

Shared door simulation now includes living, non-dormant opponents. Automatic
proximity doors can open for enemies without the player nearby. Named or
shoot-activated doors retain their existing activation rules; enemy contact
cannot unlock a key door. Q2 `NOMONSTER` (spawnflag 8) is supported, including
linked groups, and still permits player activation.

Moving doors check enemies as well as the player before committing collision or
render transforms. Closing doors reverse when an enemy obstructs their sweep.
Broad-phase bounds skip distant actors before testing the detailed hull.

Platforms detect enemy riders, carry them up and down, and remain raised while
occupied. All rider paths and mover sweeps are validated before anyone moves;
a blocked enemy rider cannot leave the player or geometry partially advanced.
Riding invalidates the enemy's cached ground route so it replans at its new
height. Jumping actors are not treated as riders.

Coverage is in `tests/enemy_door_tests.jac`, existing door/platform tests, and
`scripts/enemy_mover_smoke.jac`. This implements interaction when an enemy reaches
a mover. Choosing elevators as part of a global route, operating remote switches,
original crusher damage rules, corpse handling, and navigation onto train routes
remain separate work. It is not full campaign traversal acceptance.

Validation: **307 tests passed** with the documented local source compiler.
The native enemy-mover harness passed all three game configurations. The rebuilt
viewer completed graphical startup smoke runs for Q1 `e1m1`, Q2 `base1`, and
Q3 `q3dm1`. These checks do not establish end-to-end campaign completion.
