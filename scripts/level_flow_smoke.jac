"""Level flow through the real game loop, with screenshots: Q1 e1m7's exit
shows the intermission plaque, then the episode text, then loads start; the
Q1 solo scoreboard and the Q2 help computer show kills, goals and secrets; a
Q2 unit exit pauses on its stats; and dying restarts a level with the state
the player entered it with (Q1 parms, Q2 autosave with keys and unit flags)."""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.exits { LevelExit, HasExit }
import from engine.world.inventory { quantity, AdjustInventory }
import from engine.input.input { Intent }
import from engine.math.vec3 { Vec3 }

def tick(app: App) {
    app.physics_clock.accumulator = app.physics_clock.tick_rate;
    app.skip_time = True;
    assert app.step();
}

def shoot(app: App, name: str) {
    for i in range(3) {
        app.render_frame();
    }
    app.renderer.screenshot(".jac/screenshots/flow/" + name);
    print("FLOW SHOT", name);
}

"""Stand the player inside the level's first exit volume."""
def enter_exit(app: App) {
    exits = [app.world->:HasExit:->][?:LevelExit];
    assert exits;
    box = exits[0].volume.bounds[0];
    centre = box.mins.lerp(box.maxs, 0.5);
    app.player.pos = centre.add(Vec3(z=app.level.collision.eye_height));
    app.player.velocity = Vec3();
}

with entry {
    os.makedirs(".jac/screenshots/flow", exist_ok=True);
    renderer = Renderer();
    renderer.open_window();
    app = App(
        world=World(),
        player=Player(),
        renderer=renderer,
        clock=Clock(),
        save_path=".jac/level-flow-save.txt"
    );
    # Q1 e1m7: the exit's stats, the episode text, then start.
    app.load_destination("q1", "e1m7");
    assert app.level.name == "e1m7" and app.walking;
    assert app.total_monsters > 0 and app.entry_save;
    app.combat.kills = 3;
    app.show_scores = True;
    app.simulation_time = 125.0;
    app.render_frame();
    shoot(app, "q1_solo_scoreboard.png");
    enter_exit(app);
    tick(app);
    assert app.stats_screen and app.pending_map == "start" and app.pending_text;
    shoot(app, "q1_intermission.png");
    # IntermissionThink: keys do nothing during the enforced wait.
    app.scripted = Intent(fire=True);
    tick(app);
    assert app.stats_screen;
    app.stats_wait = 0.0;
    tick(app);
    assert not app.stats_screen and app.intermission_text;
    shoot(app, "q1_episode_text.png");
    tick(app);
    app.scripted = None;
    assert app.level.name == "start";
    print("FLOW Q1 e1m7 -> stats -> text -> start");

    # Q1 death restart: the level entry state comes back, not a fresh loadout.
    app.load_destination("q1", "e1m1");
    app.player.inventory spawn AdjustInventory(kind="nails", amount=57, capacity=200);
    app.player.health = 83;
    app.record_entry();
    nails = quantity(app.player.inventory, "nails");
    app.player.inventory spawn AdjustInventory(kind="nails", amount=-nails);
    app.player.health = 0;
    app.restart_level();
    assert app.level.name == "e1m1";
    assert app.player.health == 83 and quantity(app.player.inventory, "nails") == nails;
    print("FLOW Q1 restart keeps", nails, "nails and 83 health");

    # Q2: keys and unit flags survive a death restart; the help computer tallies.
    app.load_destination("q2", "base1");
    app.player.inventory spawn AdjustInventory(kind="key_data_cd", amount=1);
    app.player.inventory spawn AdjustInventory(kind="unit_flags", amount=3, capacity=255);
    app.record_entry();
    app.player.inventory spawn AdjustInventory(kind="key_data_cd", amount=-1);
    app.player.health = 0;
    app.restart_level();
    assert quantity(app.player.inventory, "key_data_cd") == 1;
    assert quantity(app.player.inventory, "unit_flags") == 3;
    print("FLOW Q2 restart keeps the data CD and unit flags");
    app.help_open = True;
    shoot(app, "q2_help_computer.png");
    app.help_open = False;
    # A unit exit pauses on the unit's stats and keeps the keys.
    app.begin_stats("bunk1", "start", True, "");
    shoot(app, "q2_unit_stats.png");
    app.stats_wait = 0.0;
    app.finish_stats();
    assert app.level.name == "bunk1";
    assert quantity(app.player.inventory, "key_data_cd") == 1;
    assert quantity(app.player.inventory, "unit_flags") == 0;
    print("FLOW Q2 unit exit keeps keys and clears unit flags");
    renderer.close();
    print("LEVEL FLOW SMOKE PASS");
}
