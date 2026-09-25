"""Visual check of the weapon switch: Q2's deactivate and activate frames and
Q3's lowering and raising hand, captured mid-way through each."""
import from engine.render.renderer { Renderer }
import from engine.render.viewweapon { ViewWeapon }
import from engine.core.menu { game_directory }
import from engine.world.world { Player }
import from engine.world.combat { CombatState, change_weapon, weapon_rule }
import from engine.world.inventory { AdjustInventory }
import from engine.world.lighting { Lighting }
import from games.viewweapons { view_weapons }
import from games.weapons { equip_player }

with entry {
    window = Renderer(width=960, height=540);
    window.open_window();
    view = ViewWeapon();
    for game in ["q2", "q3"] {
        player = Player();
        state = CombatState();
        equip_player(player, state, game);
        view.upload(game, game_directory(game), view_weapons(game));
        target = 2 if game == "q2" else 3;
        rule = weapon_rule(state, target);
        assert rule is not None;
        player.inventory spawn AdjustInventory(kind="weapon_" + rule.key, amount=1, capacity=1);
        player.inventory spawn AdjustInventory(kind=rule.ammo, amount=10, capacity=100);
        old = weapon_rule(state, state.weapon);
        assert old is not None;
        # Settle on the starting weapon, then change.
        window.begin_frame(player.pos, player.yaw, player.pitch);
        view.draw(player, state, 0.0, Lighting());
        window.end_scene();
        window.end_frame();
        assert change_weapon(player, state, target);
        moments = [
            ("start", 1.0),
            ("lowering", 1.0 + old.lower_time * 0.6),
            ("raising", 1.0 + old.lower_time + rule.raise_time * 0.4),
            ("ready", 1.0 + old.lower_time + rule.raise_time + 0.5)
        ];
        for moment in moments {
            # Twice, so the capture holds this moment's frame.
            for repeat in range(2) {
                window.begin_frame(player.pos, player.yaw, player.pitch);
                view.draw(player, state, moment[1], Lighting());
                window.end_scene();
                window.draw_overlay([game + ": " + old.key + " -> " + rule.key + " " + moment[0]]);
                window.end_frame();
            }
            if moment[0] != "start" {
                window.screenshot("qp_switch_" + game + "_" + moment[0] + ".png");
            }
        }
        print("Weapon switch rendered:", game, old.key, "->", rule.key);
        view.close();
    }
    window.close();
}
