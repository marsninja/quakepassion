"""Visual check of monster muzzle flashes: a Q1 grunt in e1m1 and a Q2
soldier in base1 fire from their muzzles, captured before and during the
flash. Also reports base1's areas and area portals."""
import math;
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.world.world { World }
import from engine.world.level { load_level, spawn_player }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    ensure_profiles,
    begin_attack,
    advance_attack,
    muzzle_flash_age
}
import from engine.world.area_portals { AreaPortal, HasAreaPortal, OpensPortal }
import from engine.world.doors { Door }
import from games.opponents { populate_opponents }
import from engine.math.vec3 { Vec3 }

with entry {
    renderer = Renderer(width=960, height=540);
    renderer.open_window();
    for scene in [("q1", "e1m1"), ("q2", "base1")] {
        game = scene[0];
        world = World();
        level = load_level(world, game_directory(game), scene[1], game);
        player = spawn_player(level);
        player.god_mode = True;
        if game == "q2" {
            portals = [world->:HasAreaPortal:->][?:AreaPortal];
            held = [portal for portal in portals if [portal<-:OpensPortal:<-][?:Door]];
            print("base1 areas:", len(level.bsp.areas), "portals:", len(portals), "held by doors:", len(held));
            assert len(level.bsp.areas) > 1 and portals and held;
        }
        app = App(
            world=world,
            player=player,
            level=level,
            renderer=renderer,
            clock=Clock(),
            smoke=True,
            culling=False
        );
        app.quake.upload(level);
        populate_opponents(world, level, game_directory(game));
        app.models.upload(world);
        # A monster of the kind seen from 180 units with a clear line.
        shooter: Opponent | None = None;
        for candidate in [world->:HasOpponent:->][?:Opponent] {
            if shooter is not None or candidate.dormant {
                continue;
            }
            rule = candidate.rule;
            if not rule.muzzles {
                continue;
            }
            for i in range(16) {
                angle = float(i) * math.pi / 8.0;
                vantage = candidate.pos.add(Vec3(x=math.cos(angle) * 180.0, y=math.sin(angle) * 180.0));
                ray = level.collision.trace_point(vantage, candidate.pos);
                if not ray.start_solid and ray.fraction == 1.0 {
                    player.pos = vantage;
                    player.yaw = angle + math.pi;
                    player.pitch = 0.1;
                    candidate.yaw = angle;
                    shooter = candidate;
                    break;
                }
            }
        }
        assert shooter is not None;
        print(game, "shooter:", shooter.rule.model);
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_muzzle_" + game + "_before.png");
        ensure_profiles(shooter);
        ranged = [i for i in range(len(shooter.profiles)) if shooter.profiles[i].kind == "ranged"];
        begin_attack(shooter, ranged[0], player.pos);
        flashed = False;
        for step in range(40) {
            advance_attack(world, shooter, player, level.collision, 0.025);
            shooter.yaw = math.atan2(player.pos.y - shooter.pos.y, player.pos.x - shooter.pos.x);
            if muzzle_flash_age(shooter) >= 0.0 {
                flashed = True;
                break;
            }
        }
        assert flashed;
        print(game, "flash at", shooter.flash_origin.x, shooter.flash_origin.y, shooter.flash_origin.z, "eye", shooter.pos.z);
        for i in range(3) {
            app.render_frame();
        }
        renderer.screenshot("qp_muzzle_" + game + "_flash.png");
        app.models.close();
        app.quake.close();
    }
    renderer.close();
    print("MUZZLE FLASH RENDER PASS");
}
