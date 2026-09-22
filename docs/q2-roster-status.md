# Q2 berserker and gladiator

`monster_berserk` and `monster_gladiator` now populate original maps using their
original models, health values, and shared graph combat/movement. Berserkers
choose between a short spike windup and a slower club swing, with distinct
random damage ranges. Gladiators use two cleaver strikes at close range and a
charged rail shot at distance.

Gladiator aim locks when the windup begins. Dodging changes whether the trace
hits; the gun does not retarget at the firing frame. A bounded, short-lived graph
effect renders the rail trail, clipped against the world. Locked aim persists in
save format **12**, which rejects earlier snapshots. Trails are cosmetic and
are not serialized.

Behavior references: id Software's [berserker implementation](https://github.com/id-Software/Quake-2/blob/master/game/m_berserk.c)
and [gladiator implementation](https://github.com/id-Software/Quake-2/blob/master/game/m_gladiator.c).
Tests cover windups, damage ranges, variant selection, escape during melee,
locked-aim evasion, world occlusion and save restoration. Native asset checks
cover all named poses in `scripts/q2_attack_smoke.jac`.

This is roster expansion, not full original behavior. Original muzzle offsets,
rail penetration through other monsters, directional melee contact impulses,
pain/death sounds, wounded skins, randomized pain/death selections, gibs and drops remain
open. Shared local steering is still not global navigation. The average original
run speed is used rather than per-frame locomotion distances.


Original railgun charge, berserker swing, and gladiator cleaver-swing sounds
use the existing positional speaker graph and archive-backed audio system.
Cues follow the attack clock, including both cleaver swings, and saved attack
progress does not replay an already-consumed cue. The gladiator approaches
through its railgun safe zone instead of stopping outside melee range.

Validation: the full regression suite passed **279 tests** after the roster,
locked aim, positional cue and save changes. Seven focused roster/cue tests also
passed after adding Q1 cues and a floating-point boundary regression. Native
berserker spike/club and gladiator rail harnesses passed in Q2 `base1`; original
model captures were inspected. These are controlled encounters, not campaign
playthroughs. Validation uses the documented locally patched Jac compiler.

Final native acceptance: all Q1/Q2 named attack frames and configured sound files
passed archive checks. The rebuilt `qp` completed viewer smoke runs for Q1
`e1m2`, Q2 `bunk1`, and Q3 `q3dm1`. Visual and file checks do not constitute
listening acceptance for audio mixing or uninterrupted campaign playthroughs.
