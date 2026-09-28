import from engine.world.weapons {
    ViewWeaponRule,
    GunAnimation,
    grenade_frame,
    switch_frame
}
import from engine.world.combat { CombatState, change_weapon }
import from engine.world.world { Player }
import from engine.world.inventory { AdjustInventory }
import from games.viewweapons { view_weapons }
import from games.weapons { equip_player }

"""The frames shown at each tenth of a second from `start`, with the trigger
held for `held` steps and a shot on each of `shots`."""
def gun_frames(
    rule: ViewWeaponRule, animation: GunAnimation, start: float, count: int, held: int, shots: list[int]
) -> list[int] {
    seen: list[int] = [];
    for step in range(count) {
        now = start + 0.1 * float(step);
        if step in shots {
            animation.shot(rule, now);
        }
        animation.advance(rule, now, step < held);
        seen.append(animation.frame);
    }
    return seen;
}

test "Q1 weapons play their own player.qc frames" {
    rules = view_weapons("q1");
    shotgun = rules[1];
    gun = GunAnimation();
    gun.ready(shotgun, 0.0);
    assert gun_frames(shotgun, gun, 0.0, 8, 0, [0]) == [1, 2, 3, 4, 5, 6, 0, 0];
    # player_axe/axec swing 1-4, player_axeb/axed 5-8.
    axe = rules[0];
    swings: list[int] = [];
    axing = GunAnimation();
    axing.ready(axe, 0.0);
    for swing in range(12) {
        seen = gun_frames(axe, axing, float(swing), 6, 0, [0]);
        assert seen in [[1, 2, 3, 4, 0, 0], [5, 6, 7, 8, 0, 0]];
        swings.append(seen[0]);
    }
    assert 1 in swings and 5 in swings;
    # The nailguns cycle 1-8 while they fire, and are back at 0 once let go.
    nailgun = rules[3];
    nailing = GunAnimation();
    nailing.ready(nailgun, 0.0);
    assert gun_frames(nailgun, nailing, 0.0, 12, 10, list(range(10)))
        == [1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 0, 0];
    lightning = rules[7];
    zapping = GunAnimation();
    zapping.ready(lightning, 0.0);
    assert gun_frames(lightning, zapping, 0.0, 7, 6, list(range(6))) == [1, 2, 3, 4, 1, 2, 0];
    # Q1 shows frames as they are.
    assert zapping.share(lightning, 0.65) == 1.0;
}

test "Q2 continuous weapons loop while the trigger holds" {
    rules = view_weapons("q2");
    # Machinegun_Fire alternates 5 and 4, then steps on to idle frame 6.
    machinegun = rules[3];
    gun = GunAnimation();
    gun.ready(machinegun, 0.0);
    assert gun_frames(machinegun, gun, 0.0, 7, 5, list(range(5))) == [5, 4, 5, 4, 5, 6, 7];
    # Chaingun_Fire spins up 6-21, cycles 15-21, winds down through 31.
    chaingun = rules[4];
    spinning = GunAnimation();
    spinning.ready(chaingun, 0.0);
    seen = gun_frames(chaingun, spinning, 0.0, 30, 20, list(range(20)));
    assert seen[:16] == list(range(6, 22));
    assert seen[16:20] == [15, 16, 17, 18];
    assert seen[20:30] == list(range(19, 29));
    # Let go during the spin-up, it runs to 14 then jumps to idle 32.
    brief = GunAnimation();
    brief.ready(chaingun, 0.0);
    assert gun_frames(chaingun, brief, 0.0, 9, 3, [0, 1, 2]) == [6, 7, 8, 9, 10, 11, 12, 13, 14];
    assert gun_frames(chaingun, brief, 0.9, 2, 0, []) == [32, 33];
    # The hyperblaster turns its barrels 6-11, then winds down to 21.
    hyperblaster = rules[7];
    hyper = GunAnimation();
    hyper.ready(hyperblaster, 0.0);
    assert gun_frames(hyperblaster, hyper, 0.0, 8, 6, list(range(6))) == [7, 8, 9, 10, 11, 6, 7, 8];
}

test "Q2 fire frames start past the frame fired on and blend frame to frame" {
    blaster = view_weapons("q2")[0];
    gun = GunAnimation();
    gun.ready(blaster, 0.0);
    # Weapon_Blaster: FRAME_FIRE_FIRST 5 fires; 6-8 show, then idle from 9.
    assert gun_frames(blaster, gun, 0.0, 5, 0, [0]) == [6, 7, 8, 9, 10];
    assert gun.previous == 9 and abs(gun.share(blaster, 0.45) - 0.5) < 0.00001;
}

test "Q2 idles through its frames with random fidget pauses" {
    blaster = view_weapons("q2")[0];
    gun = GunAnimation();
    gun.ready(blaster, 0.0);
    seen = gun_frames(blaster, gun, 0.0, 400, 0, []);
    # It never skips a frame, holds on its pause frames 19 and 32 (fifteen
    # times in sixteen each step), and wraps from 52 back to 9.
    held_frames: list[int] = [];
    for i in range(1, len(seen)) {
        if seen[i] == seen[i - 1] {
            held_frames.append(seen[i]);
        } else {
            assert seen[i] == seen[i - 1] + 1 or (seen[i - 1] == 52 and seen[i] == 9);
        }
    }
    assert held_frames and all([frame in [19, 32] for frame in held_frames]);
    assert 52 in seen and 33 in seen;
}

test "Q2 hand grenade frames follow its cook and throw" {
    assert grenade_frame(1, 0.5, 10.0) == 6;
    assert grenade_frame(2, 0.0, 10.0) == 11;
    assert grenade_frame(3, 0.0, 10.0) == 12;
    assert grenade_frame(0, 0.0, 0.2) == 14;
    assert grenade_frame(0, 0.0, 0.35) == 15;
    assert grenade_frame(0, 0.0, 0.6) == -1;
    grenade = view_weapons("q2")[10];
    assert grenade.idle_first == 16 and grenade.idle_last == 48 and 48 in grenade.pause_frames;
}

test "switching lowers the old weapon and raises the new one per game" {
    # Q2 blaster: deactivate frames 53-55, activate 0-4, ten a second.
    blaster = view_weapons("q2")[0];
    assert switch_frame(blaster, 56, True, 0.0) == 53;
    assert switch_frame(blaster, 56, True, 0.25) == 55;
    assert switch_frame(blaster, 56, True, 0.9) == 55;
    assert switch_frame(blaster, 56, False, 0.0) == 0;
    assert switch_frame(blaster, 56, False, 0.35) == 3;
    # The hand grenade changes at once.
    assert switch_frame(view_weapons("q2")[10], 49, True, 0.1) == -1;
    # Q3: the hand's TORSO_DROP frames 6-10 and TORSO_RAISE 11-14 at 20 fps.
    shotgun = view_weapons("q3")[2];
    assert switch_frame(shotgun, 15, True, 0.0) == 6;
    assert switch_frame(shotgun, 15, True, 0.19) == 9;
    assert switch_frame(shotgun, 15, False, 0.12) == 13;
    assert switch_frame(shotgun, 15, False, 0.24) == 14;
    # Q1 has none.
    assert switch_frame(view_weapons("q1")[1], 8, True, 0.1) == -1;
}

test "a weapon change tells the view what it puts away and for how long" {
    player = Player();
    state = CombatState();
    equip_player(player, state, "q2");
    player.inventory spawn AdjustInventory(kind="weapon_shotgun", amount=1, capacity=1);
    player.inventory spawn AdjustInventory(kind="shells", amount=10, capacity=100);
    assert change_weapon(player, state, 2);
    assert state.holstered == 1 and state.weapon == 2 and state.switches == 1;
    assert state.lowering == 0.3 and state.raising == 0.7;
    assert abs(state.cooldown - 1.0) < 0.0001;
}
