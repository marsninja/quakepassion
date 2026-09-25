import from engine.world.weapons { ViewWeaponRule, view_frame, switch_frame }
import from engine.world.combat { CombatState, change_weapon }
import from engine.world.world { Player }
import from engine.world.inventory { AdjustInventory }
import from games.viewweapons { view_weapons }
import from games.weapons { equip_player }

test "view animation samples firing and idle without advancing simulation" {
    rule = ViewWeaponRule(
        slot=1, model="test", fire_first=2, fire_last=4, idle_first=5, idle_last=7
    );
    assert view_frame(rule, 8, 0.0, 0.0) == 2;
    assert view_frame(rule, 8, 0.15, 0.0) == 3;
    assert view_frame(rule, 8, 0.25, 0.0) == 4;
    assert view_frame(rule, 8, 0.4, 0.1) == 6;
    assert view_frame(rule, 8, -1.0, 0.2) == 7;
    assert view_frame(rule, 8, 0.15, 0.0) == 3;
}

test "view frame range bounds and grenade hold release do not restart priming" {
    rule = view_weapons("q2")[10];
    assert view_frame(rule, 49, 10.0, 0.0, True, 1, 0.5) == 6;
    assert view_frame(rule, 49, 10.0, 0.0, True, 2, 0.0) == 11;
    assert view_frame(rule, 49, 10.0, 0.0, True, 3, 0.0) == 12;
    assert view_frame(rule, 49, 0.2, 0.0, True) == 14;
    assert view_frame(rule, 49, 0.6, 0.0, True) == 16;
    assert view_frame(rule, 1, 0.2, 0.0, True) == 0;
    assert view_frame(ViewWeaponRule(slot=1, model="test", fire_first=1), 6, 0.4, 0.0)
        == 5;
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
