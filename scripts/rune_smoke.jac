"""Original rune assets and hub-gate progression; no boss-fight shortcut in gameplay."""
import os;
import from games.items { populate_pickups }
import from engine.world.world { World, Player }
import from engine.world.level { load_level }
import from engine.world.pickups { Pickup, HasPickup, PickupTick }
import from engine.world.inventory { quantity }
import from engine.world.gates { ApplyGates, CampaignGate, HasGate }
import from engine.core.savegame { snapshot, restore }
import from engine.world.combat { CombatState }
import from engine.world.doors { Door, HasDoor, DoorTick }
import from engine.math.vec3 { Vec3 }

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/id1";
    player = Player();
    expected = 0;
    for name in ["e1m7", "e2m6", "e3m6", "e4m7"] {
        world = World();
        level = load_level(world, directory, name, "q1");
        populate_pickups(world, level, directory);
        found = 0;
        for item in [world->:HasPickup:->][?:Pickup] {
            if item.rule.kind != "runes" {
                continue;
            }
            expected |= item.rule.bitmask;
            player.health = 100;
            world spawn PickupTick(
                player=player, start=item.pos, finish=item.pos, dt=0.1
            );
            assert not item.active and not item.visual.visible;
            found += 1;
        }
        assert found == 1 and quantity(player.inventory, "runes") == expected;
        print("RUNE PASS", name, expected);
    }
    assert expected == 15;
    world = World();
    level = load_level(world, directory, "start", "q1");
    gates = [world->:HasGate:->][?:CampaignGate];
    assert len(gates) == 5;
    world spawn ApplyGates(
        inventory=player.inventory, bsp=level.bsp, collision=level.collision
    );
    combat = CombatState();
    saved = snapshot(world, level, player, combat);
    fresh = Player();
    restore(world, level, fresh, combat, saved);
    assert quantity(fresh.inventory, "runes") == 15;
    for gate in gates {
        assert len(gate.hulls) > 0 and len(gate.faces) > 0;
        for hull in gate.hulls {
            assert (hull in level.collision.disabled) == gate.boss;
        }
        for face in gate.faces {
            assert level.bsp.faces[face].hidden == gate.boss;
        }
    }
    print(
        "RUNE HUB PASS: four completed episode gates, final gate clear, save restored"
    );
}
