# Combat feedback and movement

The shared combat simulation now emits debris at each hitscan wall impact and blood at each actor intersection. Effects use actual pellet endpoints and wall normals, have a 512-particle world budget, expire within half a second, and never consume weapon randomness or alter damage events. They are cosmetic and are not saved.

Supported modeled opponents play one original pain/death frame family. Pain briefly interrupts movement and attacks, with a cooldown to prevent permanent stun. Death holds the last frame; restored dead opponents use that pose. Turning is rate limited, steering includes local spacing, and grounded actors check support ahead. Ranged attack animations stop forward movement; authored melee sequences can charge. First-person weapons have small movement bob and shot recoil.

This is not yet original-game behavioral parity. Remaining work includes frame-timed attacks and each monster's authored movement distances, broader enemy rosters, path navigation and Q3 tactical/item decisions, game-specific impact textures/sounds and decals, muzzle flashes, gibs, and varied pain/death sequences. Local spacing is steering, not full actor collision. Particle gravity does not collide with subsequent surfaces. Blood/debris currently share a compact particle renderer across games.

Validation entry points: `tests/feedback_tests.jac`, existing combat tests, and native `scripts/feedback_render_smoke.jac` (requires Q1 assets in `~/quake-assets/id1` and an active display).

Validation on September 22, 2026: 255 tests passed after clearing stale Jac build cache artifacts. The native Q1 e1m1 feedback harness passed and captured visible wall spray, a blood hit on an original soldier model, and the final death pose. Validated with the local source compiler (`JAC_DEV_SOURCE=/Users/marsninja/repos/jaseci-wt/qp-lighting-validation/jac`, `JAC_COMPILER_LIB=off`); this does not establish parity with the released Jac compiler or original-game AI.

## Authored Q1 attack timelines

The soldier, dog, knight, and enforcer now use explicit 10 Hz attack poses and simulation-clock damage events. Dog bites occur at 0.3 s, knight strikes at 0.5/0.6/0.7 s, soldier pellets at 0.4 s, and enforcer bolts at 0.5/0.9 s. Pose lists preserve repeated frames in the enforcer sequence. Dog and knight charge distances are integrated across frame boundaries through shared stair/slide collision, with support and player-spacing checks.

Each event rechecks live range and visibility; pain/death cancel pending attacks. Soldier shots trace four spread pellets, aim behind player velocity, and emit wall feedback when they miss. Opponent randomness is separate from player weapon randomness. Save format 9 stores attack time, next event, melee selection, pain timers, and the opponent spread stream; format 8 saves are rejected.

These timings and frame names follow the original id Software [soldier](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/soldier.qc), [dog](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/dog.qc), [knight](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/knight.qc), and [enforcer](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/enforcer.qc) code. Original randomized melee damage, refire decisions, dog leaps, attack sounds, muzzle flashes, and other monsters' authored attack sequences remain unfinished. Q3 still uses the existing generic attack behavior; the subsequent Q2 work is described below.

Additional checks: `tests/attack_timing_tests.jac`, `tests/enemy_aim_tests.jac`, and `scripts/attack_timing_smoke.jac`. The native smoke checks every referenced attack frame against the supplied Q1 models.

Final attack-timeline regression run: **261 tests passed** with the local source compiler. This includes frame-boundary charge motion, blocked strikes, interruption, burst save/restore, soldier dodging, and existing gameplay regressions.

The standalone native attack smoke passed all four original model frame checks and the two-bolt timing check. `qp` was rebuilt, and native Q1 e1m1, Q2 base1, and Q3 q3dm1 smoke runs all exited successfully.

## Q2 ranged attack profiles

The three Q2 soldier variants now have distinct ranged behavior: light soldiers fire 5-damage blaster bolts after the initial windup; shotgun soldiers fire twelve 2-damage pellets; machine-gun soldiers fire held-frame bursts of 2-damage bullets. Infantry uses its longer windup and 3-damage gun burst. Horizontal and vertical spread are independent, and soldier aim jitter is applied once before the individual pellet spread.

Held bursts extend the attack timeline and hold the firing pose instead of cycling unrelated animations. Their lengths are sampled once, preserved in save format 10, and interrupted by the existing pain/death handling. End-of-burst frames resume after the hold. Save format 9 and earlier are rejected.

The source references are id Software's [Q2 soldier](https://github.com/id-Software/Quake-2/blob/master/game/m_soldier.c), [infantry](https://github.com/id-Software/Quake-2/blob/master/game/m_infantry.c), and [weapon](https://github.com/id-Software/Quake-2/blob/master/game/g_weapon.c) implementations. This covers the canonical ranged sequence, not complete Q2 AI: alternate attacks, infantry punches, dodge/duck, original muzzle attachment offsets, sounds, difficulty-dependent refires, and tactical selection remain unfinished. Native checks live in `scripts/q2_attack_smoke.jac`; regression checks live in `tests/q2_attack_tests.jac`.

Q2 ranged validation: **265 tests passed**. The standalone native smoke passed frame-name checks against all four original Q2 model/skin profiles and verified the held burst through completion.
The rebuilt viewer also completed native Q1 e1m1, Q2 base1, and Q3 q3dm1 smoke runs successfully after the Q2 ranged changes.

## Q2 infantry melee

Infantry now selects a separate close-range punch sequence: eight original `attak201`–`attak208` poses, a strike at 0.5 seconds, per-frame approach distances, 5–9 damage, and knockback. Once chosen, the attack stays melee even if the player retreats; range and cover are rechecked at the strike. A later attack can select the machine gun again. God mode prevents both punch damage and knockback.

Melee and ranged profiles use the same combat walker, collision integration, and event clock. Existing saved melee selection and random state preserve a swing in progress, so the file format remains 10. Restoring now selects the saved attack mode before validating its duration and event count. The implementation follows the infantry melee sequence in the original [Q2 infantry source](https://github.com/id-Software/Quake-2/blob/master/game/m_infantry.c).

Coverage: `tests/infantry_melee_tests.jac` and `scripts/infantry_render_smoke.jac`. Dodge/duck, alternate ranged choices, original sound feedback, difficulty behaviors, and broader navigation remain incomplete.

Infantry melee validation: 269 gameplay tests passed. The native visual harness passed and its original-model windup/strike captures were inspected. It exposed a native `list.index` equality defect, fixed locally and submitted as [upstream #9420](https://github.com/jaseci-labs/jac/pull/9420); see `docs/native-list-search-equality-blocker.md`. The playable binary has been rebuilt with that compiler fix.
A second full regression run with the patched compiler also passed all 269 tests. Native Q1, Q2, and Q3 viewer smoke runs completed successfully with the rebuilt binary.

## Q1 ogre attack sequences

Ogres and `monster_ogre_marksman` now use the original seven-pose grenade windup
(including the repeated `shoot2` pose), releasing the grenade at 0.3 seconds.
Monster grenades use 40 splash damage with an 80-unit effective damage radius,
rather than the player grenade's damage. They retain the shared bouncing flight,
200-unit upward launch velocity and 2.5-second fuse.

Close attacks choose between the original fourteen-frame chainsaw sweep and
smash. The sweep checks damage seven times from 0.4 to 1.0 seconds; the smash
checks six times from 0.5 to 1.0 seconds. Each strike rechecks range and cover.
Authored approach distances use shared collision, and damage samples three
independent random values with the original scale of four. The chosen variant
and random stream survive save/load in **format 11**; older snapshots are rejected.

The timing and damage reference is id Software's
[ogre code](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/ogre.qc).
Random smash recovery extension, swing yaw offsets, sounds, meat spray, drops,
original ogre hull dimensions and full monster navigation remain unfinished.
This is not acceptance of the complete campaign scope.

Coverage: `tests/ogre_attack_tests.jac`, original frame validation in
`scripts/attack_timing_smoke.jac`, and visual sweep/smash capture in
`scripts/ogre_render_smoke.jac`.

Native visual acceptance passed in Q1 `e1m2`, with inspected captures of the
chainsaw sweep and overhead smash. These are controlled encounter fixtures using
original assets, not a full-map playthrough. The focused combat/save suite passed
10 tests after adding alternate-attack persistence. Validation uses the documented
local compiler with the list-search equality fix.
The final regression suite passed **273 tests** with alternate attacks enabled.
The rebuilt `qp` completed native viewer smoke runs for Q1 `e1m2`, Q2 `base1`,
and Q3 `q3dm1` successfully. These establish startup/rendering acceptance,
not campaign completion or original-game behavioral parity.

## Positional enemy attack cues

The common attack clock now triggers original dog bites, knight swings,
enforcer bolt shots, and ogre grenade/chainsaw sounds through shared graph
speakers. Q2 berserker and gladiator attacks use the same mechanism; see
[Q2 roster expansion](q2-roster-status.md). Cues are bounded by authored timeline
crossings, including floating-point frame boundaries, and attack save restoration
does not replay earlier sounds. This covers attack cues; full enemy sight,
pain/death audio and environmental hit feedback remain open.

## Q2 pain recovery

Supported Q2 enemies now use explicit original pain frames and recovery lengths:
soldiers and chicks take 0.5 seconds, berserkers 0.4, gladiators 0.6, and infantry
1.0. Their pain reactions have a three-second cooldown; hits during that cooldown
still deal damage without continually restarting recovery. Pain poses advance at
10 Hz and hold the last pose instead of wrapping.

The pose derives from the remaining recovery timer, so the first simulation tick
after loading resumes the saved reaction. Snapshot format remains **14**. Paused
rendering immediately after restore is not covered by this acceptance check.

Validation: **293 tests passed**, all seven supported Q2 model profiles passed
native frame-name checks, and `scripts/pain_render_smoke.jac` passed with inspected
original-model captures before and after save restoration. Validation uses the
local source compiler with the documented list-search equality fix.

The playable `qp` was rebuilt and completed graphical startup smoke runs for
Q1 `e2m3`, Q2 `bunk1`, and Q3 `q3dm1` with exit status zero.

This implements the short pain sequences. Damage-dependent/random alternatives,
airborne reactions, nightmare suppression, authored pain movement, wounded skins,
and pain audio remain unfinished. These checks do not establish campaign parity.
