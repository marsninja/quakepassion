import from engine.world.trail { PlayerTrail, TrailMark, Crumb, TrailTick, trail_of, next_crumb }
import from engine.world.world { World, Player }
import from engine.world.combat { CombatState, CombatTick, Opponent, HasOpponent }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "the player drops a crumb when the last goes out of sight, and Q2 monsters follow them" {
    world = World();
    player = Player(health=100, pos=Vec3(z=22.0));
    # Screens across the way every 64 units: each step forward hides where
    # the player stood before.
    collision = CollisionMap();
    for step in range(12) {
        collision.add_box(
            Vec3(x=float(step) * 64.0 + 30.0, y=-500.0, z=-500.0),
            Vec3(x=float(step) * 64.0 + 34.0, y=500.0, z=500.0),
            Vec3(), Vec3(), Vec3()
        );
    }
    collision.reindex();
    for step in range(12) {
        player.pos = Vec3(x=float(step) * 64.0, z=22.0);
        world spawn TrailTick(player=player, dt=0.6, collision=collision);
    }
    trail = trail_of(world);
    marks = [trail->:Crumb:->][?:TrailMark];
    # Each step hid the last crumb, so each dropped one where the player
    # stood (ClientBeginServerFrame). Eight are kept: 256 to 704.
    assert len(marks) == 8;
    assert min([mark.pos.x for mark in marks]) == 256.0;
    assert max([mark.pos.x for mark in marks]) == 704.0;
    # Standing still with the last one in sight, no more are dropped.
    for pause in range(20) {
        world spawn TrailTick(player=player, dt=0.1, collision=collision);
    }
    marks = [trail->:Crumb:->][?:TrailMark];
    assert len(marks) == 8 and min([mark.pos.x for mark in marks]) == 256.0;
    first = next_crumb(world, 0.0);
    assert first is not None and first.pos.x == 256.0 and first.yaw == 0.0;
    # Server frames are a tenth of a second: ticks between them do nothing.
    quick = World();
    quick spawn TrailTick(player=player, dt=0.01, collision=collision);
    assert len([trail_of(quick)->:Crumb:->][?:TrailMark]) == 1;
    player.pos = Vec3(x=768.0, z=22.0);
    for tick in range(8) {
        quick spawn TrailTick(player=player, dt=0.01, collision=collision);
    }
    assert len([trail_of(quick)->:Crumb:->][?:TrailMark]) == 1;
    for tick in range(3) {
        quick spawn TrailTick(player=player, dt=0.01, collision=collision);
    }
    laid = [trail_of(quick)->:Crumb:->][?:TrailMark];
    assert len(laid) == 2 and max([mark.pos.x for mark in laid]) == 768.0;
    # With the last crumb in sight a step drops none, however far it is.
    player.pos = Vec3(x=768.0, y=400.0, z=22.0);
    for tick in range(30) {
        quick spawn TrailTick(player=player, dt=0.01, collision=collision);
    }
    assert len([trail_of(quick)->:Crumb:->][?:TrailMark]) == 2;
    # A dead player leaves none.
    player.health = 0;
    player.pos = Vec3(x=896.0, z=22.0);
    for tick in range(30) {
        quick spawn TrailTick(player=player, dt=0.01, collision=collision);
    }
    assert len([trail_of(quick)->:Crumb:->][?:TrailMark]) == 2;
    player.health = 100;
    player.pos = Vec3(x=704.0, z=22.0);
    # The monster stands where it last saw them.
    guard = Opponent(
        game="q2", health=100, pos=Vec3(z=22.0), alert=8.0, sighted=True,
        last_seen=Vec3(z=22.0), attack_wait=10.0, trail_stamp=0.0
    );
    world +>:HasOpponent:+> guard;
    state = CombatState();
    # Its first frame out of sight makes for where it saw the player
    # (AI_PURSUIT_LAST_SEEN); already there, the next takes the first crumb
    # (PlayerTrail_PickFirst) and turns to the heading it was laid on.
    for tick in range(5) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    }
    assert guard.lost_sight and guard.pursue_next and guard.last_seen.x == 0.0;
    for tick in range(10) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    }
    assert guard.last_seen.x == 256.0 and guard.trail_stamp == first.stamp;
    assert guard.ideal_yaw == 0.0;
    # With no crumb newer the ring comes round to its oldest again.
    newest = next_crumb(world, 1000.0);
    assert newest is not None and newest.pos.x == 256.0;
}
