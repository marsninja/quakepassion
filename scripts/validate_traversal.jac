"""Asset-backed traversal contacts and destination checks."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.traversal {
    Traversal,
    Destination,
    HasTraversal,
    ArrivesAt,
    TraversalTick
}
import from engine.math.vec3 { Vec3 }

with entry {
    game = os.getenv("QP_GAME", "q3");
    folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
    directory = os.getenv(
        "QP_ASSETS", os.getenv("HOME", "") + "/quake-assets/" + folder
    );
    maps = ["start", "e1m1", "e1m2", "e1m3", "e2m1", "e3m1", "e4m1"];
    if game == "q2" {
        maps = ["base1", "base2", "base3", "bunk1", "ware1", "jail1", "space", "lab"];
    }
    if game == "q3" {
        maps = [
            "q3dm1",
            "q3dm2",
            "q3dm6",
            "q3dm7",
            "q3dm11",
            "q3dm17",
            "q3ctf1",
            "q3tourney4"
        ];
    }
    count = 0;
    for name in maps {
        world = World();
        level = load_level(world, directory, name, game);
        triggers = [world->:HasTraversal:->][?:Traversal];
        for trigger in triggers {
            # Find a point inside each exact trigger hull.
            # Q1 BSP hulls have no finite broad-phase bounds, so scan BSP vertices.
            candidates: list[Vec3] = [];
            for bounds in trigger.volume.bounds {
                candidates.append(bounds.center());
            }
            if game == "q1" {
                for face in level.bsp.faces {
                    if face.vertices {
                        candidates.append(face.vertices[0]);
                    }
                }
            }
            contact = Vec3();
            found = False;
            for candidate in candidates {
                if trigger.volume.trace(candidate, candidate).start_solid {
                    contact = candidate;
                    found = True;
                    break;
                }
            }
            assert found;
            player = Player(pos=contact.add(Vec3(z=level.collision.eye_height)));
            trigger spawn TraversalTick(
                player=player, collision=level.collision, start=contact, dt=0.01
            );
            if trigger.kind == "teleport" {
                destinations = [trigger->:ArrivesAt:->][?:Destination];
                assert not level.collision.trace(
                    destinations[0].origin, destinations[0].origin
                ).start_solid;
                assert player.pos.sub(
                    destinations[0].origin.add(Vec3(z=level.collision.eye_height))
                ).length()
                    < 0.0001;
            } else {
                assert player.velocity.sub(trigger.velocity).length() < 0.0001;
                assert trigger.velocity.length() > 0.0;
            }
            assert trigger.activations == 1;
            count += 1;
        }
        print(game, name, len(triggers), "traversal contacts passed");
    }
    if count == 0 {
        print("TRAVERSAL SKIP", game, "no supported entities in sample");
    } else {
        print("TRAVERSAL PASS", game, count);
    }
}
