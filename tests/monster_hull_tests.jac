"""Monsters move with their own box: Q2 brush hulls shift their planes for
the monster's mins/maxs, and Q1 maps give wide monsters hull 2."""
import from engine.physics.collision { CollisionMap, HullCell, HullFront, HullBack }
import from engine.physics.movement { MovePlayer }
import from engine.world.combat { Opponent, monster_collision, monster_body_key }
import from engine.world.opponent_rule { OpponentRule }
import from engine.math.vec3 { Vec3 }

"""A floor at z 0 and two walls leaving an 80-unit gap across x, expanded
by the player's box as the Q2 loader does."""
def gap_room() -> CollisionMap {
    collision = CollisionMap();
    player_min = Vec3(x=-16.0, y=-16.0, z=-24.0);
    player_max = Vec3(x=16.0, y=16.0, z=32.0);
    collision.add_box(Vec3(x=-1000.0, y=-1000.0, z=-64.0), Vec3(x=1000.0, y=1000.0, z=0.0), Vec3(), player_min, player_max);
    collision.add_box(Vec3(x=-1000.0, y=-16.0, z=0.0), Vec3(x=-40.0, y=16.0, z=400.0), Vec3(), player_min, player_max);
    collision.add_box(Vec3(x=40.0, y=-16.0, z=0.0), Vec3(x=1000.0, y=16.0, z=400.0), Vec3(), player_min, player_max);
    collision.models = [0, 0, 0];
    collision.reindex();
    return collision;
}

def supertank() -> Opponent {
    return Opponent(
        own_hull=True,
        rule=OpponentRule(width=64.0, hull_bottom=0.0, hull_top=112.0)
    );
}

test "a boss's own box stands on the floor and cannot pass a narrow gap" {
    room = gap_room();
    boss = supertank();
    body = monster_collision(room, boss);
    # Q2 bosses have their origin at their feet (mins z 0).
    feet = Vec3(y=-200.0, z=0.0);
    assert not body.trace(feet, feet).start_solid;
    assert body.trace(feet.add(Vec3(z=1.0)), feet.sub(Vec3(z=1.0))).fraction < 1.0;
    assert room.trace(feet, feet).start_solid;
    # The player-sized soldier fits through the 80-unit gap; the boss does not.
    assert room.trace(Vec3(y=-200.0, z=24.0), Vec3(y=200.0, z=24.0)).fraction == 1.0;
    through = body.trace(feet.add(Vec3(z=1.0)), Vec3(y=200.0, z=1.0));
    assert through.fraction < 0.5 and through.normal.y < -0.9;
    # A monster away from its own game's maps keeps the player's box.
    boss.own_hull = False;
    assert monster_collision(room, boss).body is None;
    assert monster_body_key(boss) != monster_body_key(supertank());
}

test "a boss walking into a gap stops at its own edge" {
    room = gap_room();
    boss = supertank();
    boss.eye_height = 22.0;
    boss.pos = Vec3(y=-200.0, z=22.0);
    boss.walk_speed = 120.0;
    body = monster_collision(room, boss);
    for i in range(480) {
        boss spawn MovePlayer(collision=body, wish=Vec3(y=1.0), steady=True, dt=1.0 / 120.0);
    }
    # The wall's face is at y -16; the boss's front is 64 ahead of its origin.
    assert boss.grounded and abs(boss.pos.z - 22.0) < 0.05;
    assert boss.pos.y < -79.0 and boss.pos.y > -81.0;
}

test "Q1 maps give monsters wider than 32 units hull 2" {
    player_cell = HullCell(normal=Vec3(z=1.0), distance=24.0);
    player_cell +>:HullFront:+> HullCell(contents=-1);
    player_cell +>:HullBack:+> HullCell(contents=-2);
    large_cell = HullCell(normal=Vec3(z=1.0), distance=24.0);
    large_cell +>:HullFront:+> HullCell(contents=-1);
    large_cell +>:HullBack:+> HullCell(contents=-2);
    collision = CollisionMap(hulls=[player_cell], large_hulls=[large_cell], offsets=[Vec3()], models=[0]);
    ogre = Opponent(own_hull=True, rule=OpponentRule(width=32.0, hull_bottom=-24.0, hull_top=64.0));
    knight = Opponent(own_hull=True, rule=OpponentRule(width=16.0, hull_bottom=-24.0, hull_top=40.0));
    wide = monster_collision(collision, ogre);
    narrow = monster_collision(collision, knight);
    assert wide.hulls[0] is large_cell and wide.body is not None and not wide.body.planes;
    assert narrow.hulls[0] is player_cell and narrow.body is None;
}
