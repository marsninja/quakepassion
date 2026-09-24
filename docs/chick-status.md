# Q2 rocket enemy

`monster_chick` now uses its original model, 175 health, walk/run frame family,
rocket windup, slash and recovery poses. The canonical rocket sequence releases
a 500-unit/second projectile after 1.3 seconds, with 50 direct damage and the
original monster rocket's 50 splash damage / 70-unit radius. A close slash deals
10–15 damage at 0.4 seconds. Original prelaunch and slash cues use spatial speakers.

Both attack families can repeat their active section without replaying startup.
The repeat decision checks range, sight and the saved random stream. A failed
check proceeds into recovery. Existing saved clock/event state retains whether
a repeated shot has already fired; no unsaved callback state is needed.

The shared attack movement integrator now accepts signed distances, preserving
backward recovery while checking collision and support. Explicit run-frame lists
support models whose locomotion frames are named `walk` rather than `run`.

Reference: id Software's [chick behavior](https://github.com/id-Software/Quake-2/blob/master/game/m_chick.c)
and [monster projectile helpers](https://github.com/id-Software/Quake-2/blob/master/game/g_monster.c).
Coverage is in `tests/chick_tests.jac`, `scripts/q2_attack_smoke.jac`, and
`scripts/chick_render_smoke.jac`.

Current snapshot version is **13**, rejecting older saves because the additional
map opponents and sound emitters change positional entity records. Original muzzle offsets, wounded skins, varied pain/death, launch/reload sound
cues, gibs and global navigation remain unfinished. This increment is not a
certificate of complete campaign behavior.

Validation: **286 full-suite tests passed**, followed by seven focused tests
including repeated-slash save restoration and escape. The native asset harness
passed all seven supported Q2 profiles and the two-rocket refire/no-duplicate
check. The native visual harness rendered the original rocket firing pose.
The rebuilt `qp` completed smoke runs on Q1 `e1m2`, Q2 `bunk1`, and Q3 `q3dm1`.
These checks use the documented locally patched compiler; they do not establish
released-toolchain acceptance or a full campaign playthrough.
