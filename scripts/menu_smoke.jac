"""Graphical menu, console and bindings regression using raylib input events;
requires original assets. It writes settings and bindings: run it through
validate_menu.jac (a disposable HOME) or with QP_CONFIG_DIR set."""
import os;
import from engine.core.app { App }
import from engine.core.preferences { Preferences }
import from engine.core.savegame { write_save, read_save }
import from engine.world.damage { Damage }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.input.input { mouse_captured, _capture }
import from scripts.input_events { event, key, click }

def select_map(app: App, name: str) {
    target = -1;
    for i in range(len(app.menu.maps)) {
        if app.menu.maps[i] == name {
            target = i;
        }
    }
    assert target >= 0;
    while app.menu.selected < target {
        key(app, 264);
    }
    while app.menu.selected > target {
        key(app, 265);
    }
    click(app, 400, 219 + (target - app.menu.offset) * 30);
}

"""Click a settings row's right (or left) arrow where the centred menu is."""
def setting(app: App, row: int, right: bool = True) {
    click(app, (915 if right else 840) + app.menu.ox, 164 + row * 30 + app.menu.oy);
}

with entry {
    world = World();
    level = load_level(world, game_directory("q1"), "e1m1", "q1");
    app = App(
        world=world,
        level=level,
        player=spawn_player(level),
        renderer=Renderer(),
        clock=Clock()
    );
    app.configure();
    app.renderer.open_window();
    render = app.renderer.cvars;
    look = app.controls.cvars;
    try {
        app.quake.upload(level);
        for i in range(10) {
            assert app.step();
        }
        # Quake's own default.cfg and QuakePassion's layer are bound.
        assert app.keyboard.keys_for("+jump") == ["ENTER", "SPACE"], app.keyboard.keys_for("+jump");
        assert "w" in app.keyboard.keys_for("+forward") and "UPARROW" in app.keyboard.keys_for("+forward");
        # The console drops with the console key, runs a line and goes away.
        key(app, 96);
        assert app.console.active and not mouse_captured();
        app.console.type_text("god");
        key(app, 257);
        assert app.host.god.on() and app.player.god_mode;
        assert "godmode ON" in app.shell.log.lines;
        app.console.type_text("sensitivity 7");
        key(app, 257);
        assert look.sensitivity.number == 7.0;
        for i in range(20) {
            assert app.step();
        }
        app.renderer.screenshot("qp_console_q1.png");
        key(app, 96);
        assert not app.console.active;
        app.shell.add_text("god; sensitivity 5");
        assert app.step();
        assert not app.host.god.on() and look.sensitivity.number == 5.0;
        # Settings are cvars.
        key(app, 256);
        click(app, 875, 98);
        assert app.menu.settings_open;
        setting(app, 0);
        assert app.walking;
        setting(app, 0, False);
        assert not app.walking;
        setting(app, 1);
        assert render.fov.number == 95.0;
        key(app, 263);
        assert render.fov.number == 90.0;
        key(app, 262);
        assert render.fov.number == 95.0;
        setting(app, 2);
        assert look.sensitivity.number == 5.5;
        setting(app, 3);
        assert look.m_pitch.number < 0.0;
        setting(app, 5);
        assert app.host.flyspeed.number == 300.0;
        setting(app, 6);
        assert render.maxfps.integer == 30;
        setting(app, 6, False);
        assert render.maxfps.integer == 0;
        setting(app, 9);
        assert not app.culling();
        setting(app, 10);
        assert not app.host.overlay.on();
        setting(app, 12);
        assert app.audio.volume.number > 0.25;
        setting(app, 13);
        assert app.host.god.on() and app.player.god_mode;
        assert "seta qp_god \"1\"" in read_save(Preferences().path());
        health = app.player.health;
        armor = app.player.armor;
        hit = app.player spawn Damage(amount=1000, bypass_armor=True);
        assert app.player.health == health
            and app.player.armor == armor
            and not hit.killed;
        app.renderer.screenshot("qp_menu_settings.png");
        # A window size from the menu resizes the window and the layout follows.
        setting(app, 8);
        assert render.width.integer == 1280 and render.height.integer == 960;
        for i in range(3) {
            assert app.step();
        }
        assert app.renderer.height == 960 and app.menu.oy == 120;
        app.renderer.screenshot("qp_menu_resized.png");
        setting(app, 8, False);
        for i in range(3) {
            assert app.step();
        }
        assert app.renderer.width == 1280 and app.renderer.height == 720;
        key(app, 256);
        assert not app.menu.opened;
        key(app, 256);
        assert app.menu.settings_open and render.fov.number == 95.0;
        click(app, 875, 98);
        assert not app.menu.settings_open;
        # The controls page rebinds an action and clears it.
        click(app, 710, 98);
        assert app.menu.controls_open;
        app.renderer.screenshot("qp_menu_controls.png");
        key(app, 257);
        assert app.menu.grabbing;
        key(app, 70);
        assert not app.menu.grabbing and "f" in app.keyboard.keys_for("+attack");
        assert "bind f \"+attack\"" in read_save(Preferences().bindings_path("q1"));
        key(app, 259);
        assert app.keyboard.keys_for("+attack") == [];
        click(app, 420, 630);
        assert app.keyboard.keys_for("+attack") == ["CTRL", "MOUSE1"], app.keyboard.keys_for("+attack");
        assert not os.path.exists(Preferences().bindings_path("q1"));
        click(app, 710, 98);
        assert not app.menu.controls_open;
        key(app, 256);
        key(app, 293);
        assert app.walking;
        for i in range(120) {
            app.physics_clock.accumulator += app.physics_clock.tick_rate;
            assert app.step();
        }
        assert app.player.grounded;
        app.renderer.screenshot("qp_walk_q1.png");
        _capture();
        key(app, 256);
        assert app.menu.opened and not mouse_captured();
        assert "b_bh100" not in app.menu.maps and "e1m1" in app.menu.maps;
        app.renderer.screenshot("qp_menu_q1.png");
        pos = app.player.pos;
        key(app, 87);
        assert app.walking;
        assert app.player.pos.x == pos.x
            and app.player.pos.y == pos.y
            and app.player.pos.z == pos.z;
        key(app, 256);
        assert not app.menu.opened and mouse_captured();
        key(app, 256);
        event(8, 0, -100);
        assert app.step();
        assert app.menu.offset == max(0, len(app.menu.maps) - 11);
        event(8, 0, 100);
        assert app.step();
        assert app.menu.offset == 0;
        click(app, 400, 219);
        assert app.menu.selected == 0;
        select_map(app, "start");
        click(app, 400, 630);
        assert not app.menu.opened and app.level.name == "start" and mouse_captured();
        key(app, 256);
        click(app, 600, 165);
        assert app.menu.game == 1 and "base1" in app.menu.maps;
        app.renderer.screenshot("qp_menu_q2.png");
        select_map(app, "base1");
        key(app, 257);
        assert not app.menu.opened and app.level.bsp.game == "q2";
        # Quake II's default.cfg binds its inventory keys.
        assert app.configured_game == "q2" and app.keyboard.keys_for("inven") == ["TAB"];
        assert app.walking;
        for i in range(120) {
            app.physics_clock.accumulator += app.physics_clock.tick_rate;
            assert app.step();
        }
        assert app.player.grounded;
        app.renderer.screenshot("qp_walk_q2.png");
        assert render.fov.number == 95.0 and look.m_pitch.number < 0.0 and not app.host.overlay.on();
        key(app, 96);
        for i in range(20) {
            assert app.step();
        }
        app.renderer.screenshot("qp_console_q2.png");
        key(app, 96);
        app.renderer.screenshot("qp_menu_loaded_q2.png");
        key(app, 256);
        click(app, 700, 165);
        assert app.menu.game == 2 and "q3dm1" in app.menu.maps;
        app.renderer.screenshot("qp_menu_q3.png");
        select_map(app, "q3dm1");
        click(app, 400, 630);
        assert not app.menu.opened and app.level.bsp.game == "q3";
        assert app.keyboard.keys_for("weapon 5") == ["5"];
        assert app.walking;
        for i in range(120) {
            app.physics_clock.accumulator += app.physics_clock.tick_rate;
            assert app.step();
        }
        assert app.player.grounded;
        app.renderer.screenshot("qp_walk_q3.png");
        key(app, 96);
        for i in range(20) {
            assert app.step();
        }
        app.renderer.screenshot("qp_console_q3.png");
        key(app, 96);
        app.renderer.screenshot("qp_menu_loaded_q3.png");
        key(app, 256);
        app.menu.maps.append("__missing_level__");
        app.menu.selected = len(app.menu.maps) - 1;
        key(app, 257);
        assert app.menu.opened and app.menu.message.startswith("Cannot load level:");
        assert app.level.bsp.game == "q3" and app.level.name == "q3dm1";
        click(app, 400, 165);
        select_map(app, "e1m1");
        click(app, 400, 630);
        assert not app.menu.opened and app.level.bsp.game == "q1";
        app.renderer.screenshot("qp_menu_return_q1.png");
        assert app.walking and app.player.god_mode;
        key(app, 293);
        assert not app.walking;
        key(app, 256);
        click(app, 875, 98);
        assert app.menu.settings_open;
        click(app, 420, 630);
        assert render.fov.number == 90.0 and render.maxfps.integer == 0;
        assert look.sensitivity.number == 5.0 and look.m_pitch.number > 0.0;
        assert app.host.flyspeed.number == 240.0 and app.culling() and app.host.overlay.on();
        assert not app.host.god.on() and not app.player.god_mode;
        preferences = Preferences();
        assert "seta qp_god \"0\"" in read_save(preferences.path());
        # The numeric settings of earlier versions read as the cvars that
        # replaced them, keeping the view and the mouse as they were.
        write_save(
            preferences.path(), "QUAKEPASSION SETTINGS 1\n72 0.0022 0 240 0 1 1 0.25\n"
        );
        assert not preferences.current();
        migrated = preferences.settings_text();
        assert "seta fov 88.2" in migrated and "seta sensitivity 5.73" in migrated;
        assert "seta r_novis 0" in migrated and "seta qp_god" not in migrated;
        assert app.walking;
        event(7, 850, 630);
        event(6, 0);
        assert not app.step();
        print(
            "MENU PASS: console, bindings, controls, settings cvars, window size, reset defaults, walking toggle, grounding, Escape, capture, pause, scrolling, selection, Q1/Q2/Q3 switching, load failure, quit"
        );
    } finally {
        app.quake.close();
        app.renderer.close();
    }
}
