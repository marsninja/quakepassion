"""Graphical menu regression using raylib input events; requires original assets."""
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.input.input { mouse_captured, _capture }
import from vendor.raylib {
    # AutomationEvent has frame, type, and four contiguous int parameters.
    obj AutomationEvent {
        has frame: u32,
            kind: u32,
            p0: i32,
            p1: i32,
            p2: i32,
            p3: i32;
    }  def PlayAutomationEvent(event: AutomationEvent) -> None;
}

def event(kind: int, a: int, b: int = 0) {
    PlayAutomationEvent(
        AutomationEvent(
            frame=u32(0), kind=u32(kind), p0=i32(a), p1=i32(b), p2=i32(0), p3=i32(0)
        )
    );
}

def key(app: App, code: int) {
    event(2, code);
    assert app.step();
    event(1, code);
    assert app.step();
}

def click(app: App, x: int, y: int) {
    event(7, x, y);
    event(6, 0);
    assert app.step();
    event(5, 0);
    assert app.step();
}

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
    app.renderer.open_window();
    try {
        app.quake.upload(level);
        for i in range(10) {
            assert app.step();
        }
        key(app, 256);
        click(app, 875, 98);
        assert app.menu.settings_open;
        click(app, 915, 174);
        assert app.walking;
        click(app, 840, 174);
        assert not app.walking;
        click(app, 915, 222);
        assert app.renderer.fov == 74.0;
        key(app, 263);
        assert app.renderer.fov == 72.0;
        key(app, 262);
        assert app.renderer.fov == 74.0;
        click(app, 915, 270);
        assert app.sensitivity > 0.0022;
        click(app, 915, 318);
        assert app.invert_y;
        click(app, 915, 366);
        assert app.fly_speed == 300.0;
        click(app, 915, 414);
        assert app.renderer.frame_limit == 30;
        click(app, 840, 414);
        assert app.renderer.frame_limit == 0;
        click(app, 915, 462);
        assert not app.culling;
        click(app, 915, 510);
        assert not app.overlay;
        app.renderer.screenshot("qp_menu_settings.png");
        key(app, 256);
        assert not app.menu.opened;
        key(app, 256);
        assert app.menu.settings_open and app.renderer.fov == 74.0;
        click(app, 875, 98);
        assert not app.menu.settings_open;
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
        assert app.walking;
        for i in range(120) {
            app.physics_clock.accumulator += app.physics_clock.tick_rate;
            assert app.step();
        }
        assert app.player.grounded;
        app.renderer.screenshot("qp_walk_q2.png");
        assert app.renderer.fov == 74.0 and app.invert_y and not app.overlay;
        app.renderer.screenshot("qp_menu_loaded_q2.png");
        key(app, 256);
        click(app, 820, 165);
        assert app.menu.game == 2 and "q3dm1" in app.menu.maps;
        app.renderer.screenshot("qp_menu_q3.png");
        select_map(app, "q3dm1");
        click(app, 400, 630);
        assert not app.menu.opened and app.level.bsp.game == "q3";
        assert app.walking;
        for i in range(120) {
            app.physics_clock.accumulator += app.physics_clock.tick_rate;
            assert app.step();
        }
        assert app.player.grounded;
        app.renderer.screenshot("qp_walk_q3.png");
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
        assert app.walking;
        key(app, 293);
        assert not app.walking;
        key(app, 256);
        click(app, 875, 98);
        assert app.menu.settings_open;
        click(app, 420, 630);
        assert app.renderer.fov == 72.0 and app.renderer.frame_limit == 0;
        assert app.sensitivity == 0.0022 and not app.invert_y;
        assert app.fly_speed == 240.0 and app.culling and app.overlay;
        assert app.walking;
        event(7, 850, 630);
        event(6, 0);
        assert not app.step();
        print(
            "MENU PASS: settings, reset defaults, walking toggle, grounding, Escape, capture, pause, scrolling, selection, Q1/Q2/Q3 switching, load failure, quit"
        );
    } finally {
        app.quake.close();
        app.renderer.close();
    }
}
