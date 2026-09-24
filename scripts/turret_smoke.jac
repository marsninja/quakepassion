"""Original maps: the jail1 and strike turrets swing toward the player, fire
rockets from their muzzles and fall idle when their driver dies."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level }
import from engine.world.world { World, Player }
import from engine.world.combat { Opponent, HasOpponent, Projectile, HasProjectile, damage_opponent }
import from engine.world.turrets { Turret, HasTurret, TurretBase, Mounts, Mans, TurretTick, turret_axes }
import from games.opponents { populate_opponents }
import from engine.render.models { ModelScene }
import from engine.render.quake { QuakeRenderer }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3 }

def look_at(renderer: Renderer, drawing: QuakeRenderer, scene: ModelScene, level: Level, world: World, eye: Vec3, target: Vec3, name: str) {
    direction = target.sub(eye);
    yaw = math.atan2(direction.y, direction.x);
    pitch = math.atan2(direction.z, math.sqrt(direction.x * direction.x + direction.y * direction.y));
    for frame in range(3) {
        renderer.begin_frame(eye, yaw, pitch);
        drawing.draw(level, level.visible(world, eye, False), eye);
        scene.draw(world, eye, 1.0);
        renderer.end_scene();
        renderer.end_frame();
    }
    renderer.screenshot(name);
}

"""A standing spot in front of the gun with a clear line to its muzzle."""
def firing_spot(level: Level, breach: Turret) -> Vec3 | None {
    ahead = turret_axes(0.0, breach.yaw)[0];
    muzzle = breach.pivot.add(ahead.scale(breach.muzzle.x));
    for reach in [320.0, 256.0, 192.0, 400.0, 480.0] {
        for side in [0.0, 30.0, -30.0, 60.0, -60.0] {
            heading = turret_axes(0.0, breach.yaw + side)[0];
            spot = muzzle.add(heading.scale(reach));
            if level.collision.trace_point(spot, spot).start_solid {
                continue;
            }
            if level.collision.trace_point(muzzle, spot).fraction == 1.0 {
                return spot;
            }
        }
    }
    return None;
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    for name in ["jail1", "strike"] {
        world = World();
        level = load_level(world, game_directory("q2"), name, "q2");
        populate_opponents(world, level, game_directory("q2"));
        scene = ModelScene();
        scene.upload(world);
        drawing = QuakeRenderer();
        drawing.upload(level);
        breaches = [world->:HasTurret:->][?:Turret];
        assert len(breaches) == 1;
        breach = breaches[0];
        bases = [breach->:Mounts:->][?:TurretBase];
        drivers = [breach<-:Mans:<-][?:Opponent];
        print("TURRET", name, "faces", len(breach.faces), "hulls", len(breach.hulls), "base faces", len(bases[0].faces) if bases else 0, "drivers", len(drivers), "yaw", breach.yaw, "muzzle", breach.muzzle.x, breach.muzzle.y, breach.muzzle.z);
        assert breach.faces and bases and bases[0].faces and len(drivers) == 1;
        driver = drivers[0];
        spot = firing_spot(level, breach);
        assert spot is not None;
        player = Player(health=100000, god_mode=True, pos=spot);
        start_yaw = breach.yaw;
        side = turret_axes(0.0, breach.yaw)[1];
        player.pos = spot.add(side.scale(96.0));
        if level.collision.trace_point(player.pos, player.pos).start_solid {
            player.pos = spot;
        }
        eye = player.pos.add(Vec3(z=24.0));
        look_at(renderer, drawing, scene, level, world, eye, breach.pivot, "turret_" + name + "_rest.png");
        rockets = 0;
        for tick in range(400) {
            world spawn TurretTick(bsp=level.bsp, collision=level.collision, player=player, dt=0.01);
            rockets = len([world->:HasProjectile:->][?:Projectile]);
        }
        wanted = math.degrees(math.atan2(player.pos.y - breach.pivot.y, player.pos.x - breach.pivot.x));
        print("TURRET", name, "yaw", start_yaw, "->", breach.yaw, "wanted", wanted, "pitch", breach.pitch, "rockets", rockets, "driver", driver.pos.x, driver.pos.y, driver.pos.z);
        assert rockets >= 1;
        look_at(renderer, drawing, scene, level, world, eye, breach.pivot, "turret_" + name + "_aimed.png");
        damage_opponent(driver, driver.health + 1);
        for tick in range(100) {
            world spawn TurretTick(bsp=level.bsp, collision=level.collision, player=player, dt=0.01);
        }
        assert not [breach<-:Mans:<-];
        print("TURRET PASS", name);
    }
    renderer.close();
}
