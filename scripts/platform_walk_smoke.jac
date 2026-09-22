"""Native original-map regression for riders sinking into Q1 platform hulls."""
import from engine.world.level { load_level }
import from engine.world.world { World, Player }
import from engine.world.doors { Door, HasDoor, DoorTick }
import from engine.physics.movement { MovePlayer }
import from engine.core.menu { game_directory }
import from engine.math.vec3 { Vec3 }
with entry {
    for game in ["q1", "q2"] {
        world = World();
        level = load_level(
            world, game_directory(game), "e1m1" if game == "q1" else "base3", game
        );
        for platform in [world->:HasDoor:->][?:Door] {
            if platform.kind != "platform" or not platform.enabled {
                continue;
            }
            origin = Vec3(
                x=(platform.bounds.mins.x + platform.bounds.maxs.x) / 2.0,
                y=(platform.bounds.mins.y + platform.bounds.maxs.y) / 2.0,
                z=platform.bounds.maxs.z + platform.rest.z + 24.03125
            );
            if level.collision.trace(origin, origin).start_solid {
                continue;
            }
            player = Player(pos=origin.add(Vec3(z=level.collision.eye_height)));
            for tick in range(1200) {
                world spawn DoorTick(
                    bsp=level.bsp,
                    collision=level.collision,
                    player_origin=origin,
                    player=player,
                    dt=1.0 / 120.0
                );
                player spawn MovePlayer(
                    collision=level.collision,
                    dt=1.0 / 120.0,
                    wish=Vec3(x=1.0) if tick >= 600 else Vec3()
                );
                pos = player.pos.sub(Vec3(z=level.collision.eye_height));

                assert not level.collision.trace(pos, pos).start_solid;
                if tick == 599 {
                    assert platform.position == 1.0;
                    assert abs(
                        player.pos.z
                            - origin.z
                            - level.collision.eye_height
                            - platform.travel.z
                    )
                        < 0.1;
                }
                if tick == 1199 {
                    assert player.pos.x - origin.x > 1.0;
                    print("Platform ride and walk passed:", game, platform.model);
                }
            }
        }
    }
}
