"""Items over clip brushes on the original maps. Q2 droptofloor and Q3
FinishSpawningItem put an item down with MASK_SOLID, which no clip brush
stops, so an item whose box stands in player clip is kept and can be picked
up (every item of q3dm19 sits over a thin clip brush). For each map: how
many items the level keeps, how many of them were placed inside a clip
brush, and that the player collects one of those by walking onto it.

    jac build scripts/validate_item_clip.jac --native -o .jac/validate_item_clip
    QP_MAPS=q3:q3dm19,q2:city3 DYLD_LIBRARY_PATH=vendor .jac/validate_item_clip
"""
import os;
import from engine.core.menu { game_directory }
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.pickups { Pickup, HasPickup, PickupTick }
import from games.items { populate_pickups, pickup_rule }
import from engine.math.vec3 { Vec3 }

with entry {
    clipped = 0;
    for entry_name in os.getenv("QP_MAPS", "q3:q3dm19,q3:q3tourney2,q2:city3,q2:ware1").split(",") {
        game = entry_name.split(":")[0];
        name = entry_name.split(":")[1];
        world = World();
        level = load_level(world, game_directory(game), name, game);
        kept = populate_pickups(world, level, game_directory(game));
        low = Vec3(x=-15.0, y=-15.0, z=-15.0);
        high = Vec3(x=15.0, y=15.0, z=15.0);
        as_player = level.collision.for_body(0.0, 0.0, low, high);
        as_item = level.collision.for_body(0.0, 0.0, low, high, "solid");
        # The item entities placed where a player's mask is in solid and
        # MASK_SOLID is not: inside a clip brush.
        ruled = 0;
        over_clip: list[Vec3] = [];
        for record in level.bsp.entities {
            if pickup_rule(game, record.fields, 0) is None {
                continue;
            }
            ruled += 1;
            parts = record.fields.get("origin", "0 0 0").split();
            spot = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            if as_player.trace(spot, spot).start_solid and not as_item.trace(spot, spot).start_solid {
                over_clip.append(spot);
            }
        }
        # One of them, where it was put down, is there to be taken.
        taken = 0;
        items = [world->:HasPickup:->][?:Pickup];
        for spot in over_clip {
            for item in items {
                if item.active
                    and abs(item.pos.x - spot.x) < 1.0
                    and abs(item.pos.y - spot.y) < 1.0
                    and item.pos.z <= spot.z + 1.0 {
                    # Standing on the floor the item lies on.
                    player = Player(health=50, pos=item.pos.add(Vec3(z=level.collision.eye_height + 8.0)));
                    world spawn PickupTick(
                        player=player, start=player.pos, finish=player.pos, dt=0.1, game=game
                    );
                    if not item.active {
                        taken += 1;
                    }
                    break;
                }
            }
            if taken > 0 {
                break;
            }
        }
        print(
            "ITEM CLIP", game, name, "items kept", kept, "of", ruled, "item entities |",
            "placed in a clip brush", len(over_clip), "| one of those taken", taken == 1
        );
        assert kept > 0 , name;
        assert not over_clip or taken == 1 , name;
        clipped += len(over_clip);
    }
    assert clipped > 0;
    print("ITEM CLIP PASS");
}
