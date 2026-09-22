"""Original e1m7 encounter activation, electrodes, death output and persistence."""
import os;
import from engine.world.world { World, Player }
import from engine.world.level { load_level, spawn_player }
import from games.opponents { populate_opponents }
import from games.items { populate_pickups }
import from engine.world.combat { Opponent, HasOpponent, CombatState, damage_opponent }
import from engine.world.chthon { ChthonTick, LightningEvent, HasLightning, Electrode }
import from engine.world.doors { Door, DoorTick }
import from engine.world.signals { Fire }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/id1";
    world = World();
    level = load_level(world, directory, "e1m7", "q1");
    populate_opponents(world, level, directory);
    populate_pickups(world, level, directory);
    bosses = [
        enemy
        for enemy in [world->:HasOpponent:->][?:Opponent]
        if enemy.rule.script == "chthon"
    ];
    assert len(bosses) == 1;
    boss = bosses[0];
    assert boss.activation.enabled;
    events = [world->:HasLightning:->][?:LightningEvent];
    assert len(events) == 1;
    event = events[0];
    doors = [event->:Electrode:->][?:Door];
    assert len(doors) == 2 and all(door.enabled for door in doors);
    player = spawn_player(level);
    player.god_mode = True;
    state = CombatState();
    assert boss.dormant and not boss.visual.visible;
    boss.activation.pending = 1;
    for i in range(180) {
        world spawn ChthonTick(player=player, state=state, dt=0.01);
    }
    assert boss.boss_phase == 2 and boss.health == 3;
    assert damage_opponent(boss, 10000) == 0;
    for expected in [2, 1, 0] {
        for door in doors {
            door.requested = True;
        }
        for tick in range(500) {
            world spawn DoorTick(
                bsp=level.bsp,
                collision=level.collision,
                player_origin=Vec3(x=1.0e6, y=1.0e6, z=1.0e6),
                dt=0.01
            );
            world spawn ChthonTick(player=player, state=state, dt=0.01);
            if all(door.state == "open" for door in doors) {
                break;
            }
        }
        assert all(door.state == "open" for door in doors);
        assert boss.health == expected + 1;
        event.activation spawn Fire(emit=False);
        world spawn ChthonTick(player=player, state=state, dt=0.01);
        assert boss.health == expected and event.remaining > 0.0;
        saved = snapshot(world, level, player, state);
        restore(world, level, player, state, saved);
        assert boss.health == expected and boss.visual.visible;
        for i in range(250) {
            world spawn DoorTick(
                bsp=level.bsp,
                collision=level.collision,
                player_origin=Vec3(x=1.0e6, y=1.0e6, z=1.0e6),
                dt=0.01
            );
            world spawn ChthonTick(player=player, state=state, dt=0.01);
        }
        print("CHTHON STRIKE PASS", expected);
    }
    assert boss.boss_phase == 7 and not boss.visual.visible and state.kills == 1;
    print(
        "CHTHON PASS: original model, awakening, three electrode strikes, saved shocks, death output"
    );
}
