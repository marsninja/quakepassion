import from games.weapons {
    weapon_rules,
    equip_player,
    lead_game,
    passion_start,
    fire_sound,
    weapon_effects,
    missile_sounds,
    PASSION_ROLES,
    PASSION_AMMO_CAPS
}
import from games.viewweapons { view_weapons }
import from games.items { pickup_rule, passion_pickup }
import from engine.world.weapons { owned_kind, passion_slot }
import from engine.world.combat { CombatState, change_weapon, cycle_weapon, owns_weapon, selected_weapon, shot_game, weapon_cue }
import from engine.world.world { Player }
import from engine.world.inventory { AdjustInventory, quantity }
import from engine.audio.feedback { named_game, unnamed }

def held(player: Player, kinds: list[str]) {
    for kind in kinds {
        player.inventory spawn AdjustInventory(kind=kind, amount=1, capacity=1);
    }
}

test "a Passion arsenal holds every game's weapons, numbered apart and held by name" {
    arsenal = weapon_rules("passion");
    assert len(arsenal) == len(PASSION_ROLES) and len(arsenal) == 28;
    slots = [rule.slot for rule in arsenal];
    assert len(set(slots)) == len(slots);
    for rule in arsenal {
        assert rule.game in ["q1", "q2", "q3"] and 1 <= rule.role <= 9;
        assert rule.slot == passion_slot(rule.game, rule.game_slot);
        assert owned_kind(rule) == "weapon_" + rule.game + ":" + rule.key;
        if rule.ammo {
            assert rule.capacity == PASSION_AMMO_CAPS[rule.ammo];
        }
    }
    # A game's own table is as it was, each rule knowing its game.
    quake = weapon_rules("q1");
    assert [rule.slot for rule in quake] == [1, 2, 3, 4, 5, 6, 7, 8];
    assert all([rule.game == "q1" and rule.game_slot == rule.slot and owned_kind(rule) == "weapon_" + rule.key for rule in quake]);
}

test "the player starts armed for the game the level draws on most" {
    assert lead_game(["q2", "q2", "q1", "", "q3"]) == "q2" and lead_game([]) == "q1" and lead_game(["q3"]) == "q3";
    assert passion_start("q1").weapons == ["weapon_q1:axe", "weapon_q1:shotgun"];
    assert passion_start("q2").weapons == ["weapon_q2:blaster"] and passion_start("q2").ammo == "";
    assert passion_start("q3").held == passion_slot("q3", 2);
    player = Player();
    state = CombatState();
    equip_player(player, state, "passion", lead="q3");
    assert state.weapon == passion_slot("q3", 2) and selected_weapon(state).key == "machinegun";
    assert quantity(player.inventory, "weapon_q3:gauntlet") == 1 and quantity(player.inventory, "bullets") == 100;
    assert shot_game(state, selected_weapon(state)) == "q3";
    # Out of ammunition the strongest held weapon is taken first: the BFGs lead.
    assert state.fallback[0] in [passion_slot("q2", 10), passion_slot("q3", 9)];
}

test "a number key takes up its role's weapons in turn" {
    player = Player();
    state = CombatState();
    equip_player(player, state, "passion", lead="q1");
    held(player, ["weapon_q2:shotgun", "weapon_q3:shotgun", "weapon_q2:supershotgun"]);
    player.inventory spawn AdjustInventory(kind="shells", amount=50, capacity=100);
    assert selected_weapon(state).game == "q1" and selected_weapon(state).key == "shotgun";
    seen: list[str] = [];
    for i in range(4) {
        assert change_weapon(player, state, 3);
        seen.append(selected_weapon(state).game + ":" + selected_weapon(state).key);
        state.cooldown = 0.0;
    }
    assert seen == ["q2:shotgun", "q3:shotgun", "q2:supershotgun", "q1:shotgun"];
    # The rockets' key with no launcher held changes nothing.
    assert not change_weapon(player, state, 6);
    # Quake's shotgun is not Quake II's.
    fresh = Player();
    held(fresh, ["weapon_q2:shotgun"]);
    rules = weapon_rules("passion");
    assert len([rule for rule in rules if owns_weapon(fresh, rule)]) == 1;
    assert cycle_weapon(player, state, 1);
}

test "a Passion level's pickups, sounds, models and effects come from their own game" {
    rule = pickup_rule("q2", {"classname": "weapon_supershotgun"}, 0);
    assert rule is not None;
    passion_pickup(rule, "q2");
    assert rule.kind == "weapon_q2:supershotgun" and rule.ammo_capacity == PASSION_AMMO_CAPS["shells"];
    assert rule.sound.startswith("q2:");
    box = pickup_rule("q3", {"classname": "ammo_rockets"}, 0);
    assert box is not None;
    passion_pickup(box, "q3");
    assert box.kind == "rockets" and box.capacity == PASSION_AMMO_CAPS["rockets"];
    # Shots and hums from the weapon's own archive.
    for weapon in weapon_rules("passion") {
        sound = fire_sound(weapon);
        assert sound == "" or sound.startswith(weapon.game + ":sound/");
    }
    assert weapon_cue(CombatState(game="passion"), "q2", "sound/weapons/noammo.wav") == "q2:sound/weapons/noammo.wav";
    assert weapon_cue(CombatState(game="q2"), "q2", "sound/weapons/noammo.wav") == "sound/weapons/noammo.wav";
    assert named_game("q3:sound/x.wav") == "q3" and unnamed("q3:sound/x.wav") == "sound/x.wav" and named_game("sound/x.wav") == "";
    # Every arsenal weapon has its gun in view.
    view = [rule.slot for rule in view_weapons("passion")];
    for weapon in weapon_rules("passion") {
        assert weapon.slot in view;
    }
    keys = [effect.key for effect in weapon_effects("passion")];
    assert "q1_rocket" in keys and "q2_bolt" in keys and "q3_plasma" in keys;
    assert all([":" in path for path in missile_sounds("passion").values()]);
}
