"""Original first-person assets and camera-space rendering acceptance."""
import from engine.render.renderer { Renderer }
import from engine.render.viewweapon { ViewWeapon }
import from engine.core.menu { game_directory }
import from engine.world.world { Player }
import from engine.world.combat { CombatState }
import from engine.world.lighting { Lighting }
import from games.viewweapons { view_weapons }

with entry {
    window = Renderer(width=960, height=540);
    window.open_window();
    view = ViewWeapon();
    player = Player();
    state = CombatState();
    for game in ["q1", "q2", "q3"] {
        rules = view_weapons(game);
        view.upload(game, game_directory(game), rules);
        assert len(view.assets) == len(rules);
        for rule in rules {
            state.weapon = rule.slot;
            for tick in range(5) {
                if tick == 3 {
                    state.shots += 1;
                }
                window.begin_frame(player.pos, player.yaw, player.pitch);
                view.draw(player, state, float(tick) * 0.2, Lighting());
                window.end_scene();
                window.draw_overlay([game + ": " + rule.model]);
                window.end_frame();
                if tick == 2 or tick == 4 {
                    window.screenshot(
                        "qp_view_"
                            + game
                            + "_"
                            + str(rule.slot)
                            + "_"
                            + str(tick)
                            + ".png"
                    );
                }
            }
            print("View weapon rendered:", game, rule.slot);
        }
        view.close();
        assert not view.assets;
    }
    window.close();
}
