# Q1 Hell Knight

`monster_hell_knight` now loads its original model and uses the canonical
`magicc` ranged sequence: six 9-damage spikes, released from 0.5 to 1.0 seconds
with horizontal offsets from -12 to +18 degrees. Each shot has vertical scatter,
original attack audio and a registered original spike model. The shared engine
now accepts per-event projectile yaw offsets. Mid-volley saves preserve the event
cursor and random stream.

In melee range (CheckAttack's `RANGE_MELEE`, 120 units) the Hell Knight takes
the slice, the smash and the wide swing in turn, on one count shared by every
Hell Knight as QuakeC's global `hknight_type` is (kept in saves); each strike
lands with `ai_melee` within 60 units. From the first frame of its run cycle it
charges (`CheckForCharge`: target visible, attacks due, at least 80 away and
within 20 in height), running `char_a1-16` with `SUB_AttackFinished(2)`.
`char_b` has no caller in the QuakeC and is not used. Ordinary knights swing
close by (`knight_atk1`) and from 80 to 120 units make their running attack
(`knight_runatk`), striding at a point 30 units left of the target
(`ai_charge_side`) with sword1 or sword2. Charges refuse steps into the
target's box as `SV_movestep` does. Pain/death variations and gibs remain open.

Reference: id Software's [Hell Knight source](https://github.com/id-Software/Quake-Tools/blob/master/qcc/v101qc/hknight.qc).
Tests: `tests/hell_knight_tests.jac`, `scripts/attack_timing_smoke.jac`, and
`scripts/hell_knight_render_smoke.jac`.

Save format **14** rejects older snapshots because another original map opponent
and its emitters are now populated. Full original campaign and arena scope remains
unfinished; these are controlled implementation and acceptance increments.

Q1 dogs and ordinary knights now also use the original three-sample randomized
melee formulas (scales eight and three respectively), replacing fixed damage.
Knight hit range is 60 units. The shared integer-health model rounds each sampled
hit down; this is not exact fractional-health emulation of QuakeC.

The first full regression checkpoint passed **290 tests**. Original Hell Knight
attack/slice frames and sound files passed native asset checks, and its original
firing pose was captured and inspected in the native renderer. These visual checks
use a controlled actor placement, not a complete original-map encounter.
The subsequent focused combat run passed **10 tests** after the dog/knight damage
correction. The native harness also passed a six-projectile direction check and
loaded the original spike model. The rebuilt viewer completed smoke runs on Q1
`e2m3`, Q2 `bunk1`, and Q3 `q3dm1`. Validation uses the documented patched local
Jac compiler; released-toolchain and full-campaign acceptance remain separate.
