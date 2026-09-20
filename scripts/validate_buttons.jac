"""Native asset-backed translating button and signal dispatch checks."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World }
import from engine.world.doors { Door, HasDoor, DoorTick }
import from engine.world.signals { Signal, HasSignal }
import from engine.math.vec3 { Vec3 }

with entry {
    game = os.getenv("QP_GAME", "q1");
    folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
    directory = os.getenv("QP_ASSETS", os.getenv("HOME", "") + "/quake-assets/" + folder);
    maps = ["e1m1", "e1m2", "e1m3", "e2m1", "e3m1", "e4m1"];
    if game == "q2" { maps = ["base1", "base2", "base3", "bunk1", "ware1", "jail1"]; }
    if game == "q3" { maps = ["q3dm2", "q3dm7", "q3dm11", "q3ctf1", "q3tourney4"]; }
    total = 0;
    for name in maps {
        world = World();
        level = load_level(world, directory, name, game);
        buttons = [door for door in [world->:HasDoor:->][?:Door]
            if door.enabled and door.kind == "button"];
        signals = [world->:HasSignal:->][?:Signal];
        for button in buttons {
            for signal in signals { signal.pending = 0; }
            button.requested = True;
            button spawn DoorTick(bsp=level.bsp, collision=level.collision,
                player_origin=Vec3(x=1.0e6, y=1.0e6, z=1.0e6),
                dt=button.travel.length() / button.speed + 0.01);
            assert button.position == 1.0 and button.state == "open";
            for face in button.faces {
                assert level.bsp.faces[face].motion.sub(button.travel).length() < 0.00001;
            }
            expected = False;
            for entity in button.activation.entities {
                expected = expected or bool(level.bsp.entities[entity].fields.get("target", ""));
            }
            if expected {
                assert len([signal for signal in signals if signal.pending > 0]) > 0;
            }
            total += 1;
        }
        print(game, name, len(buttons), "buttons passed");
    }
    print("BUTTONS PASS", game, total);
    assert total > 0;
}
