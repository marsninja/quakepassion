"""Native real-map door cycles: jac build scripts/validate_doors.jac --native."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World }
import from engine.world.doors { Door, HasDoor, DoorMember, DoorTick }
import from engine.math.vec3 { Vec3 }

with entry {
    game = os.getenv("QP_GAME", "q1");
    folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
    directory = os.getenv(
        "QP_ASSETS", os.getenv("HOME", "") + "/quake-assets/" + folder
    );
    maps = ["e1m1", "start", "e1m2", "e2m1", "e3m1", "e4m1"];
    if game == "q2" {
        maps = ["base1", "base2", "base3"];
    }
    if game == "q3" {
        maps = ["q3dm1", "q3dm2", "q3dm7", "q3ctf1", "q3tourney4"];
    }
    total = 0;
    for name in maps {
        world = World();
        level = load_level(world, directory, name, game);
        doors = [
            door
            for door in [world->:HasDoor:->][?:Door]
            if door.automatic
        ];
        for door in doors {
            # The expanded trigger's corner is outside the physical brush.
            near = door.trigger.mins.add(Vec3(x=1.0, y=1.0, z=1.0));
            world spawn DoorTick(
                bsp=level.bsp, collision=level.collision, player_origin=near, dt=0.001
            );
            assert door.state == "opening";
            far = Vec3(x=1.0e6, y=1.0e6, z=1.0e6);
            # Traverse this door independently so other nearby doors cannot reset it.
            door spawn DoorTick(
                bsp=level.bsp,
                collision=level.collision,
                player_origin=far,
                dt=door.travel.length() / door.speed + 0.01
            );
            assert door.state == "open" and door.position == 1.0;
            members = [door];
            members.extend([door->:DoorMember:->][?:Door]);
            for part in members {
                assert part.position == 1.0;
                for face in part.faces {
                    assert level.bsp.faces[face].motion.sub(part.travel).length()
                        < 0.00001;
                }
                for j in range(len(part.hulls)) {
                    offset = level.collision.offsets[part.hulls[j]];
                    assert offset.sub(part.origins[j]).sub(part.travel).length()
                        < 0.00001;
                }
            }
            if door.hold_time >= 0.0 {
                door spawn DoorTick(
                    bsp=level.bsp,
                    collision=level.collision,
                    player_origin=far,
                    dt=door.hold_time + 0.01
                );
                door spawn DoorTick(
                    bsp=level.bsp,
                    collision=level.collision,
                    player_origin=far,
                    dt=door.travel.length() / door.speed + 0.01
                );
                assert door.state == "closed" and door.position == 0.0;
                for face in door.faces {
                    assert level.bsp.faces[face].motion.length() == 0.0;
                }
            }
            total += 1;
        }
        print(game, name, len(doors), "proximity door cycles passed");
    }
    assert total > 0;
    print("DOORS PASS", game, total);
}
