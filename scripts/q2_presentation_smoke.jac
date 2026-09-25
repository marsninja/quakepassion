"""Quake II's 2D presentation through the real game loop, with screenshots in
.jac/screenshots/q2hud/: the help computer (help.pcx layout), the blinking
help icon, Tab's inventory screen, the power armor status bar with its damage
flash, the ch1 crosshair and the unit summary."""
import os;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.render.renderer { Renderer }
import from engine.world.world { World, Player }
import from engine.world.targets { help_for }
import from engine.world.inventory { AdjustInventory }
import from engine.world.powerups { Powerup, Empowered }
import from engine.world.damage { Damage }
import from engine.input.input { Intent }

def shoot(app: App, name: str) {
    for i in range(3) {
        app.render_frame();
    }
    app.renderer.screenshot(".jac/screenshots/q2hud/" + name);
    print("Q2HUD SHOT", name);
}

def tick(app: App) {
    app.physics_clock.accumulator = app.physics_clock.tick_rate;
    app.skip_time = True;
    assert app.step();
}

with entry {
    os.makedirs(".jac/screenshots/q2hud", exist_ok=True);
    renderer = Renderer();
    renderer.open_window();
    app = App(
        world=World(),
        player=Player(),
        renderer=renderer,
        clock=Clock(),
        save_path=".jac/q2-presentation-save.txt"
    );
    app.load_destination("q2", "base1");
    assert app.hud.ready and app.hud.has_pic("help") and app.hud.has_pic("ch1");
    assert app.hud.has_pic("inventory") and app.hud.has_pic("i_help");
    computer = help_for(app.world);
    computer.primary = "Establish communication\nlink to command ship.";
    computer.secondary = "Locate base installation\nelevator.";
    computer.unread = 2;
    # level.framenum & 8: the icon shows for frames 8-15 of every 16.
    app.simulation_time = 0.85;
    status = app.hud_status();
    assert status.help_unread;
    shoot(app, "q2_help_icon.png");
    # F1 opens the computer and reads the news.
    app.scripted = Intent(help=True);
    tick(app);
    app.scripted = None;
    assert app.help_open and computer.unread == 0;
    assert not app.hud_status().help_unread;
    shoot(app, "q2_help_computer.png");
    # Tab swaps the help for the inventory.
    for (kind, amount, capacity) in [
        ("weapon_shotgun", 1, 1),
        ("weapon_machinegun", 1, 1),
        ("weapon_railgun", 1, 1),
        ("shells", 24, 100),
        ("bullets", 150, 200),
        ("slugs", 10, 50),
        ("cells", 75, 200),
        ("grenades", 5, 50),
        ("power_shield", 1, 1),
        ("powerup_quad", 1, 2),
        ("key_data_cd", 1, 1)
    ] {
        app.player.inventory spawn AdjustInventory(kind=kind, amount=amount, capacity=capacity);
    }
    app.player.armor = 50;
    app.player.armor_ratio = 0.6;
    app.scripted = Intent(inventory=True);
    tick(app);
    app.scripted = None;
    assert app.inventory_open and not app.help_open;
    shoot(app, "q2_inventory.png");
    app.scripted = Intent(inventory=True);
    tick(app);
    app.scripted = None;
    assert not app.inventory_open;
    # Power armor: the cells and i_powershield take turns with the worn
    # armor, and a hit flashes the field behind the number.
    app.player +>:Empowered:+> Powerup(kind="power_shield", remaining=-1.0);
    app.simulation_time = 0.85;
    status = app.hud_status();
    assert status.armor == 75 and status.armor_icon == "i_powershield";
    app.simulation_time = 0.25;
    status = app.hud_status();
    assert status.armor == 50 and status.armor_icon == "";
    app.simulation_time = 0.85;
    app.player spawn Damage(amount=12);
    app.render_frame();
    assert app.view.status_flashes() & 2;
    shoot(app, "q2_power_armor.png");
    # The unit summary on the help computer's frame.
    app.combat.kills = 12;
    app.begin_stats("bunk1", "start", True, "");
    app.completed_time = 312.0;
    shoot(app, "q2_unit_summary.png");
    app.stats_wait = 0.0;
    shoot(app, "q2_unit_summary_ready.png");
    renderer.close();
    print("Q2 PRESENTATION SMOKE PASS");
}
