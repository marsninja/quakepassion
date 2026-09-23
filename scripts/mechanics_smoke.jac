"""Original maps: rotating doors, periodic movers, traps, targets, triggers and
fixtures load, run and render."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { Level, load_level, spawn_player }
import from engine.world.world { World, Player }
import from engine.world.doors { Door, HasDoor, DoorTick, DoorMember }
import from engine.world.rotators { Rotator, HasRotator, RotatorTick }
import from engine.world.shooters { Shooter, HasShooter, ShooterTick }
import from engine.world.targets { TargetEvent, HasTarget, TargetTick }
import from engine.world.triggers { TouchTrigger, HasTrigger, MonsterJump, HasMonsterJump }
import from engine.world.fixtures { Fixture, HasFixture, FixtureTick }
import from engine.world.speakers { Speaker, HasSpeaker }
import from engine.world.signals { Signal, HasSignal, SignalTick }
import from engine.world.combat { CombatState, Projectile, HasProjectile, ProjectileTick }
import from games.items { populate_pickups }
import from games.opponents { populate_opponents }
import from games.fixtures { populate_fixtures }
import from engine.render.models { ModelScene }
import from engine.render.quake { QuakeRenderer }
import from engine.render.renderer { Renderer }
import from engine.math.vec3 { Vec3 }

def look_at(renderer: Renderer, drawing: QuakeRenderer, scene: ModelScene, level: Level, world: World, eye: Vec3, target: Vec3, name: str, seconds: float) {
    direction = target.sub(eye);
    yaw = math.atan2(direction.y, direction.x);
    pitch = math.atan2(direction.z, math.sqrt(direction.x * direction.x + direction.y * direction.y));
    for frame in range(3) {
        renderer.begin_frame(eye, yaw, pitch);
        drawing.draw(level, level.visible(world, eye, False), eye);
        scene.draw(world, eye, seconds);
        renderer.end_scene();
        renderer.end_frame();
    }
    renderer.screenshot(name);
}

def viewpoint(level: Level, target: Vec3) -> Vec3 {
    for reach in [96.0, 160.0, 240.0, 320.0] {
        for offset in [Vec3(x=1.0, z=0.3), Vec3(x=-1.0, z=0.3), Vec3(y=1.0, z=0.3), Vec3(y=-1.0, z=0.3), Vec3(x=0.7, y=0.7, z=0.5), Vec3(x=-0.7, y=-0.7, z=0.5)] {
            eye = target.add(offset.normalized().scale(reach));
            if level.collision.trace_point(eye, eye).start_solid {
                continue;
            }
            hit = level.collision.trace_point(eye, target);
            if hit.fraction > 0.9 {
                return eye;
            }
        }
    }
    return target.add(Vec3(z=64.0));
}

with entry {
    renderer = Renderer();
    renderer.open_window();
    cases: list[tuple[str, str]] = [("q1", "e2m6"), ("q1", "e1m6"), ("q2", "jail4"), ("q2", "security"), ("q3", "q3dm19"), ("q3", "q3dm15")];
    for scenario in cases {
        game = scenario[0];
        name = scenario[1];
        world = World();
        level = load_level(world, game_directory(game), name, game);
        populate_pickups(world, level, game_directory(game));
        populate_opponents(world, level, game_directory(game));
        fixtures = populate_fixtures(world, level, game_directory(game));
        scene = ModelScene();
        scene.upload(world);
        drawing = QuakeRenderer();
        drawing.upload(level);
        player = Player(health=100000, god_mode=True, pos=spawn_player(level).pos);
        state = CombatState(game=game);
        doors = [door for door in [world->:HasDoor:->][?:Door] if door.enabled];
        turning = [door for door in doors if door.rotation.length() > 0.0];
        movers = [world->:HasRotator:->][?:Rotator];
        shooters = [world->:HasShooter:->][?:Shooter];
        targets = [world->:HasTarget:->][?:TargetEvent];
        triggers = [world->:HasTrigger:->][?:TouchTrigger];
        loops = [speaker for speaker in [world->:HasSpeaker:->][?:Speaker] if speaker.looping];
        signals = [world->:HasSignal:->][?:Signal];
        live = [signal for signal in signals if signal.enabled];
        print("MECHANICS", game, name, "doors", len(doors), "rotating", len(turning), "movers", len(movers),
            "shooters", len(shooters), "targets", len(targets), "triggers", len(triggers),
            "fixtures", fixtures, "loops", len(loops), "signals", len(live), "/", len(signals));
        # Open every rotating door, fire every shooter and switch on every laser.
        for door in turning {
            door.requested = True;
        }
        for shooter in shooters {
            shooter.activation.pending += 1;
        }
        for event in targets {
            if event.kind == "laser" and not event.on {
                event.activation.pending += 1;
            }
        }
        launched = 0;
        for tick in range(120 * 3) {
            dt = 1.0 / 120.0;
            world spawn SignalTick(dt=dt, inventory=player.inventory);
            world spawn DoorTick(bsp=level.bsp, collision=level.collision, player_origin=Vec3(z=-100000.0), dt=dt, touching=False);
            world spawn RotatorTick(bsp=level.bsp, collision=level.collision, dt=dt);
            fired = world spawn ShooterTick(dt=dt);
            launched += fired.fired;
            world spawn TargetTick(player=player, collision=level.collision, state=state, dt=dt);
            world spawn ProjectileTick(player=player, collision=level.collision, state=state, dt=dt);
            world spawn FixtureTick(dt=dt);
        }
        if turning {
            opened = [door for door in turning if door.position > 0.0];
            assert opened;
            door = opened[0];
            face = level.bsp.faces[door.faces[0]];
            assert face.turn is not None;
            focus = door.bounds.center();
            look_at(renderer, drawing, scene, level, world, viewpoint(level, focus), focus, "qp_mechanics_" + name + "_door.png", 3.0);
        }
        if movers {
            moved = [mover for mover in movers if mover.clock > 0.0];
            assert moved;
            record = level.bsp.models[movers[0].model];
            focus = movers[0].pivot.add(record.mins.lerp(record.maxs, 0.5));
            look_at(renderer, drawing, scene, level, world, viewpoint(level, focus), focus, "qp_mechanics_" + name + "_mover.png", 3.0);
        }
        if shooters {
            assert launched > 0;
        }
        if game == "q1" and fixtures > 0 {
            torches = [fixture for fixture in [world->:HasFixture:->][?:Fixture] if fixture.frames];
            assert torches;
            look_at(renderer, drawing, scene, level, world, viewpoint(level, torches[0].pos), torches[0].pos, "qp_mechanics_" + name + "_torch.png", 3.0);
        }
        lasers = [event for event in targets if event.kind == "laser" and event.on];
        print("MECHANICS PASS", game, name, "launched", launched, "lasers on", len(lasers));
        scene.close();
        drawing.close();
    }
    renderer.close();
}
