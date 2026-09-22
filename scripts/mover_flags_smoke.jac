"""Original campaign start-open and toggle door transform acceptance."""
import os;
import from engine.world.world { World }
import from engine.world.level { load_level }
import from engine.world.doors { Door, HasDoor, DoorMember, DoorTick }
import from engine.math.vec3 { Vec3 }

with entry {
    for game in ["q1", "q2"] {
        folder = "id1" if game == "q1" else "baseq2";
        directory = os.getenv("HOME", "") + "/quake-assets/" + folder;
        maps = ["e1m1", "e1m3", "e1m6"]
            if game == "q1"
            else ["biggun", "bunk1", "city2"];
        start_open = 0;
        toggles = 0;
        for name in maps {
            world = World();
            level = load_level(world, directory, name, game);
            for door in [world->:HasDoor:->][?:Door] {
                if not door.enabled
                    or door.kind != "door"
                    or (not door.toggle and door.rest.length() == 0.0) {
                    continue;
                }
                members = [door];
                members.extend([door->:DoorMember:->][?:Door]);
                for part in members {
                    for face in part.faces {
                        assert level.bsp.faces[face].motion.sub(part.rest).length()
                            < 0.00001;
                    }
                    for i in range(len(part.hulls)) {
                        assert level.collision.offsets[part.hulls[i]].sub(
                            part.origins[i]
                        ).sub(
                            part.rest
                        ).length()
                            < 0.00001;
                    }
                }
                door.requested = True;
                door spawn DoorTick(
                    bsp=level.bsp,
                    collision=level.collision,
                    player_origin=Vec3(x=1.0e6, y=1.0e6, z=1.0e6),
                    dt=door.travel.length() / door.speed + 0.01
                );
                assert door.state == "open" and door.position == 1.0;
                if door.rest.length() > 0.0 {
                    start_open += 1;
                }
                if door.toggle {
                    door spawn DoorTick(
                        bsp=level.bsp,
                        collision=level.collision,
                        player_origin=Vec3(x=1.0e6, y=1.0e6, z=1.0e6),
                        dt=10.0
                    );
                    assert door.state == "open";
                    door.requested = True;
                    door spawn DoorTick(
                        bsp=level.bsp,
                        collision=level.collision,
                        player_origin=Vec3(x=1.0e6, y=1.0e6, z=1.0e6),
                        dt=door.travel.length() / door.speed + 0.01
                    );
                    assert door.state == "closed" and door.position == 0.0;
                    toggles += 1;
                }
                print("MOVER FLAGS PASS", game, name, door.model);
            }
        }
        assert start_open > 0 and toggles > 0;
        print("MOVER FLAGS TOTAL", game, start_open, toggles);
    }
}
