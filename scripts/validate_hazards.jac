"""Original-map damage volumes and persistence without rendering or save writes."""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.hazards { Hazard, HasHazard, HazardTick }
import from engine.world.combat { CombatState }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }

with entry {
    for game in ["q1", "q2", "q3"] {
        folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
        maps = ["end"]
            if game == "q1"
            else (["fact2", "power2"] if game == "q2" else ["q3dm17", "q3dm12"]);
        for name in maps {
            world = World();
            level = load_level(
                world, os.getenv("HOME", "") + "/quake-assets/" + folder, name, game
            );
            hazards = [world->:HasHazard:->][?:Hazard];
            assert len(hazards) > 0;
            checked = 0;
            for hazard in hazards {
                if hazard.damage <= 0 {
                    continue;
                }
                for box in hazard.volume.bounds {
                    origin = box.center();
                    if not hazard.volume.trace(origin, origin).start_solid {
                        continue;
                    }
                    player = Player(pos=origin.add(Vec3(z=level.collision.eye_height)));
                    hazard.enabled = True;
                    hazard.cooldown = 0.0;
                    hazard spawn HazardTick(
                        player=player, start=origin, finish=origin, dt=0.01
                    );
                    assert player.health < 100;
                    hazard spawn HazardTick(
                        player=player, start=origin, finish=origin, dt=0.01
                    );
                    assert hazard.cooldown > 0.0;
                    checked += 1;
                    break;
                }
            }
            assert checked > 0;
            player = Player();
            combat = CombatState();
            before = snapshot(world, level, player, combat);
            for hazard in hazards {
                hazard.enabled = not hazard.enabled;
                hazard.cooldown = 0.0;
            }
            restore(world, level, player, combat, before);
            assert snapshot(world, level, player, combat) == before;
            print(
                "HAZARDS PASS",
                game,
                name,
                len(hazards),
                "volumes",
                checked,
                "contact probes"
            );
        }
    }
}
