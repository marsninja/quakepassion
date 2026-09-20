"""Native asset-backed platform transforms and player carrying checks."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.doors { Door, HasDoor, DoorTick }
import from engine.math.vec3 { Vec3 }

with entry {
    game = os.getenv("QP_GAME", "q1");
    folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
    directory = os.getenv(
        "QP_ASSETS", os.getenv("HOME", "") + "/quake-assets/" + folder
    );
    maps = ["e1m1", "e1m2", "e1m3", "e2m1", "e3m1", "e4m1"];
    if game == "q2" {
        maps = ["base1", "base2", "base3", "bunk1", "ware1", "jail1"];
    }
    if game == "q3" {
        maps = ["q3dm2", "q3dm7", "q3dm11", "q3ctf1", "q3tourney4"];
    }
    total = 0;
    rides = 0;
    for name in maps {
        world = World();
        level = load_level(world, directory, name, game);
        platforms = [
            door
            for door in [world->:HasDoor:->][?:Door]
            if door.enabled and door.kind == "platform"
        ];
        for platform in platforms {
            far = Vec3(x=1.0e6, y=1.0e6, z=1.0e6);
            duration = platform.travel.length() / platform.speed + 0.01;
            if platform.state == "locked" {
                platform.activation.pending = 1;
                platform spawn DoorTick(
                    bsp=level.bsp,
                    collision=level.collision,
                    player_origin=far,
                    dt=duration
                );
            }
            assert platform.position == 0.0;
            # Probe several points because platform bounds can enclose empty space.
            ridden = False;
            for x in [0.25, 0.5, 0.75] {
                for y in [0.25, 0.5, 0.75] {
                    if ridden {
                        continue;
                    }
                    origin = Vec3(
                        x=platform.bounds.mins.x
                            + (platform.bounds.maxs.x - platform.bounds.mins.x) * x,
                        y=platform.bounds.mins.y
                            + (platform.bounds.maxs.y - platform.bounds.mins.y) * y,
                        z=platform.bounds.maxs.z + platform.rest.z + 24.03125
                    );
                    ground = level.collision.trace(origin, origin.add(Vec3(z=-0.25)));
                    if ground.start_solid
                        or ground.fraction == 1.0
                        or ground.normal.z < 0.7 {
                        continue;
                    }
                    player = Player(pos=origin.add(Vec3(z=level.collision.eye_height)));
                    platform.requested = True;
                    platform spawn DoorTick(
                        bsp=level.bsp,
                        collision=level.collision,
                        player_origin=origin,
                        player=player,
                        dt=0.01
                    );
                    if platform.position > 0.0 {
                        displacement = platform.travel.scale(platform.position);
                        assert player.pos.sub(
                            origin.add(Vec3(z=level.collision.eye_height))
                        ).sub(
                            displacement
                        ).length()
                            < 0.0001;
                        ridden = True;
                        rides += 1;
                    }
                }
            }
            platform.requested = True;
            platform spawn DoorTick(
                bsp=level.bsp, collision=level.collision, player_origin=far, dt=duration
            );
            assert platform.position == 1.0;
            for face in platform.faces {
                assert level.bsp.faces[face].motion.length() < 0.00001;
            }
            platform spawn DoorTick(
                bsp=level.bsp,
                collision=level.collision,
                player_origin=far,
                dt=platform.hold_time + 0.01
            );
            platform spawn DoorTick(
                bsp=level.bsp, collision=level.collision, player_origin=far, dt=duration
            );
            assert platform.position == 0.0;
            for face in platform.faces {
                assert level.bsp.faces[face].motion.sub(platform.rest).length()
                    < 0.00001;
            }
            total += 1;
        }
        print(game, name, len(platforms), "platforms checked");
    }
    if total == 0 and game == "q3" {
        print(
            "PLATFORMS SKIP q3: no func_plat in sampled maps; unit fixtures cover Q3 semantics"
        );
    } else {
        assert total > 0 and rides > 0;
        print("PLATFORMS PASS", game, total, "cycles", rides, "rides");
    }
}
