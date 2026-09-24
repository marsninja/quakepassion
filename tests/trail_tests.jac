import from engine.world.trail { PlayerTrail, TrailMark, Crumb, TrailTick, trail_of, next_crumb }
import from engine.world.world { World, Player }
import from engine.world.combat { CombatState, CombatTick, Opponent, HasOpponent }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "the player leaves eight crumbs and Q2 monsters that lost sight follow them" {
    world = World();
    player = Player(health=100, pos=Vec3(z=22.0));
    for step in range(12) {
        player.pos = Vec3(x=float(step) * 64.0, z=22.0);
        world spawn TrailTick(player=player, dt=0.6);
    }
    trail = trail_of(world);
    marks = [trail->:Crumb:->][?:TrailMark];
    assert len(marks) == 8;
    first = next_crumb(world, 0.0);
    assert first is not None and first.pos.x == 256.0;
    # A wall hides the player; the monster stands where it last saw them.
    collision = CollisionMap();
    collision.add_box(Vec3(x=100.0, y=-500.0, z=-500.0), Vec3(x=120.0, y=500.0, z=500.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    guard = Opponent(game="q2", health=100, pos=Vec3(z=22.0), alert=8.0, last_seen=Vec3(z=22.0), attack_wait=10.0, trail_stamp=0.0);
    world +>:HasOpponent:+> guard;
    world spawn CombatTick(player=player, collision=collision, state=CombatState(), dt=0.01);
    assert guard.last_seen.x == 256.0 and guard.trail_stamp == first.stamp;
}
