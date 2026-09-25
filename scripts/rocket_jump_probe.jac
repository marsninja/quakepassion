"""Headless rocket jump: on a real map the player looks straight down, jumps
and fires a rocket on the same tick, as players do; prints the apex above
the take-off height for Q1, Q2 and Q3."""
import math;
import from engine.core.menu { game_directory }
import from engine.world.level { load_level, spawn_player }
import from engine.world.world { World }
import from engine.world.combat {
    CombatState,
    CombatTick,
    ProjectileTick,
    weapon_input,
    select_weapon
}
import from engine.world.inventory { AdjustInventory }
import from engine.physics.movement { MovePlayer }
import from games.weapons { equip_player }
import from engine.math.vec3 { Vec3 }

with entry {
    for game in ["q1", "q2", "q3"] {
        name = "e1m1" if game == "q1" else ("base1" if game == "q2" else "q3dm1");
        world = World();
        level = load_level(world, game_directory(game), name, game);
        player = spawn_player(level);
        state = CombatState();
        equip_player(player, state, game);
        player.inventory spawn AdjustInventory(kind="weapon_rocketlauncher", amount=1);
        player.inventory spawn AdjustInventory(kind="rockets", amount=20, capacity=100);
        assert select_weapon(player, state, 7 if game != "q3" else 5);
        player.pitch = -1.45;
        # A placed entity (item, spawn, monster) with the most headroom.
        best = 0.0;
        for entity in level.bsp.entities {
            spot = entity.fields.get("origin", "");
            if not spot or entity.fields.get("classname", "").startswith("light") {
                continue;
            }
            parts = spot.split(" ");
            if len(parts) != 3 {
                continue;
            }
            base = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            body = base.add(Vec3(z=30.0));
            if level.collision.trace(body, body).start_solid {
                continue;
            }
            floor = level.collision.trace(body, body.sub(Vec3(z=96.0)));
            if floor.fraction >= 1.0 or floor.normal.z < 0.7 {
                continue;
            }
            room = level.collision.trace(floor.end, floor.end.add(Vec3(z=800.0))).fraction * 800.0;
            if room > best {
                best = room;
                player.pos = floor.end.add(Vec3(z=level.collision.eye_height));
            }
        }
        tick = 1.0 / 120.0;
        for settle in range(240) {
            player spawn MovePlayer(collision=level.collision, game=game, dt=tick);
        }
        assert player.grounded;
        start = player.pos.z;
        health = player.health;
        apex = 0.0;
        for step in range(240) {
            player spawn MovePlayer(
                collision=level.collision, jump=step == 0, game=game, dt=tick
            );
            weapon_input(world, player, level.collision, state, step == 0, tick);
            world spawn ProjectileTick(
                player=player, collision=level.collision, state=state, dt=tick
            );
            world spawn CombatTick(
                player=player, collision=level.collision, state=state, dt=tick, active=False
            );
            apex = max(apex, player.pos.z - start);
        }
        print("ROCKET JUMP", game, name, "apex", int(apex), "units (headroom", int(best), "), health", health, "->", player.health);
    }
}
