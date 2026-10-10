"""Campaign monsters chasing through the real combat tick: steps blocked by
other bodies, stopping a step short of the enemy, Q2's pursuit of an enemy
out of sight, and the chase state in saves."""
import math;
import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat { CombatState, CombatTick, Opponent, HasOpponent }
import from engine.world.opponent_rule { OpponentRule }
import from engine.world.trail { TrailTick }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

"""A floor at z 0, as a point body stands on it (origin at its feet)."""
def chase_floor() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-4000.0, y=-4000.0, z=-64.0), Vec3(x=4000.0, y=4000.0, z=0.0), Vec3(), Vec3(), Vec3()
    );
    return collision;
}

def chaser(game: str, kind: str, pos: Vec3) -> Opponent {
    rule = enemy_rule(game, kind, 0);
    assert rule is not None;
    return Opponent(
        rule=rule,
        kind=kind,
        game=game,
        pos=pos,
        health=rule.health,
        max_health=rule.health,
        grounded=True,
        attack_wait=1000.0,
        animation=list(range(len(rule.run.frames)))
    );
}

def chase(world: World, player: Player, collision: CollisionMap, state: CombatState, seconds: float) {
    for tick in range(int(seconds * 120.0)) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
    }
}

test "monsters block each other in a corridor and a corpse does not" {
    collision = chase_floor();
    # Walls 40 units apart: too narrow to pass a 32 unit body in.
    collision.add_box(Vec3(x=-200.0, y=20.0, z=0.0), Vec3(x=2000.0, y=30.0, z=200.0), Vec3(), Vec3(), Vec3());
    collision.add_box(Vec3(x=-200.0, y=-30.0, z=0.0), Vec3(x=2000.0, y=-20.0, z=200.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    world = World();
    state = CombatState(game="q1");
    player = Player(pos=Vec3(x=600.0, z=22.0), health=100000, god_mode=True);
    grunt = chaser("q1", "monster_army", Vec3(z=22.0));
    grunt.alert = 8.0;
    grunt.last_seen = player.pos;
    # A guard standing in the way, 60 units ahead.
    guard = Opponent(
        rule=OpponentRule(movement="none"), game="q1", pos=Vec3(x=60.0, z=22.0), health=100,
        grounded=True, attack_wait=1000.0
    );
    world +>:HasOpponent:+> grunt;
    world +>:HasOpponent:+> guard;
    furthest = 0.0;
    for tick in range(600) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
        furthest = max(furthest, grunt.pos.x);
    }
    # Their boxes are 16 units either side: the grunt never comes nearer
    # than 32, and it did close up to the guard.
    assert furthest <= 28.0 and furthest >= 13.0 , str(furthest);
    assert abs(grunt.pos.y) <= 20.001 and guard.pos.x == 60.0;
    # Dead, the guard is a corpse (SOLID_NOT) and the grunt runs through.
    guard.health = 0;
    chase(world, player, collision, state, 3.0);
    assert grunt.pos.x > 150.0 , str(grunt.pos.x);
}

test "a monster runs at the player and stops where its next step would reach them" {
    collision = chase_floor();
    collision.reindex();
    world = World();
    state = CombatState(game="q1");
    player = Player(pos=Vec3(x=300.0, z=22.0), health=100000, god_mode=True);
    knight = chaser("q1", "monster_knight", Vec3(z=22.0));
    knight.alert = 8.0;
    knight.last_seen = player.pos;
    world +>:HasOpponent:+> knight;
    for tick in range(720) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
        # Never inside the player's box (SV_movestep's trace).
        assert knight.pos.x <= 268.0 , str(tick);
    }
    # knight_run1-8 step 16 20 13 7 16 20 14 6: within the longest of them,
    # and SV_CloseEnough's two units, of the player's box.
    assert knight.pos.x >= 268.0 - 22.0 , str(knight.pos.x);
    assert knight.pose_name == "run" and abs(knight.pos.y) < 0.001;
    # Running in place, it is not being carried anywhere.
    assert knight.stride_time == 0.0 or knight.standing().x == knight.pos.x;
}

test "a Q2 monster that loses its enemy makes for where it saw them, then along their trail" {
    collision = chase_floor();
    # A wall hides everything beyond x 300 from the guard's side.
    collision.add_box(Vec3(x=300.0, y=-4000.0, z=0.0), Vec3(x=310.0, y=-100.0, z=400.0), Vec3(), Vec3(), Vec3());
    collision.add_box(Vec3(x=300.0, y=100.0, z=0.0), Vec3(x=310.0, y=4000.0, z=400.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    world = World();
    state = CombatState(game="q2");
    player = Player(pos=Vec3(x=200.0, z=22.0), health=100000, god_mode=True);
    guard = chaser("q2", "monster_soldier", Vec3(z=22.0));
    guard.skill = 1;
    world +>:HasOpponent:+> guard;
    # Seen at x 200, the player then goes through the gap and round the
    # corner, out of sight, leaving crumbs.
    chase(world, player, collision, state, 0.3);
    assert guard.alert > 0.0 and guard.sighted and guard.pursuing and not guard.lost_sight;
    for spot in [Vec3(x=350.0, z=22.0), Vec3(x=400.0, y=300.0, z=22.0), Vec3(x=400.0, y=600.0, z=22.0)] {
        player.pos = spot;
        world spawn TrailTick(player=player, dt=0.6);
    }
    chase(world, player, collision, state, 0.5);
    assert not guard.pursuing and guard.lost_sight and guard.alert > 0.0;
    # It keeps its enemy for as long as it takes (ai_run never gives up),
    # going through the gap and up the trail.
    east = 0.0;
    north = 0.0;
    for tick in range(12 * 120) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
        east = max(east, guard.pos.x);
        north = max(north, guard.pos.y);
    }
    assert guard.alert > 0.0 and guard.pose_name == "run";
    assert east > 340.0 and north > 250.0 , str(east) + " " + str(north);
}

test "a Q2 monster with only a noise to go on stands its ground when it gets there" {
    collision = chase_floor();
    collision.reindex();
    world = World();
    state = CombatState(game="q2");
    # The player is out of reach of sight; the monster only heard something.
    player = Player(pos=Vec3(x=3000.0, z=22.0), health=100000, god_mode=True);
    guard = chaser("q2", "monster_soldier", Vec3(z=22.0));
    guard.alert = 6.0;
    guard.last_seen = Vec3(x=200.0, z=22.0);
    world +>:HasOpponent:+> guard;
    chase(world, player, collision, state, 4.0);
    # AI_SOUND_TARGET: within 64 units of the noise it stops and stands.
    gap = guard.pos.sub(Vec3(x=200.0, z=guard.pos.z)).length();
    assert gap < 64.0 and gap > 30.0 , str(gap);
    assert guard.pose_name == "stand" and not guard.sighted;
    chase(world, player, collision, state, 3.0);
    assert guard.alert == 0.0;
}

test "the chase survives a save" {
    world = World();
    level = Level();
    level.name = "test";
    player = Player();
    guard = chaser("q2", "monster_soldier", Vec3(x=10.0, z=22.0));
    world +>:HasOpponent:+> guard;
    idle = chaser("q1", "monster_army", Vec3(x=500.0, z=22.0));
    world +>:HasOpponent:+> idle;
    # Part-way through a step that ends 12 units on and 20 degrees round.
    start = guard.pos;
    guard.pos = Vec3(x=22.0, y=3.0, z=22.0);
    guard.turn_to = 20.0;
    guard.stride(start, 0.075);
    guard.advance(1.0 / 120.0);
    guard.ideal_yaw = 215.0;
    guard.step_random = 123456;
    guard.partial_ground = True;
    guard.sliding = True;
    guard.lefty = True;
    guard.lost_sight = True;
    guard.pursue_temp = True;
    guard.searching = True;
    guard.search_left = 17.5;
    guard.saved_goal = Vec3(x=1.0, y=2.0, z=3.0);
    left = guard.stride_time;
    drawn = guard.pos.x;
    data = snapshot(world, level, player, CombatState());
    fresh = World();
    loaded = chaser("q2", "monster_soldier", Vec3(z=22.0));
    fresh +>:HasOpponent:+> loaded;
    other = chaser("q1", "monster_army", Vec3(z=22.0));
    fresh +>:HasOpponent:+> other;
    restore(fresh, level, Player(), CombatState(), data);
    assert loaded.ideal_yaw == 215.0 and loaded.step_random == 123456;
    assert loaded.partial_ground and loaded.sliding and loaded.lefty;
    assert loaded.lost_sight and loaded.pursue_temp and loaded.searching;
    assert not loaded.pursue_next and not loaded.pursuit_last_seen;
    assert loaded.search_left == 17.5 and loaded.saved_goal.y == 2.0;
    # The step goes on from where the body was drawn and ends where it did.
    assert abs(loaded.pos.x - drawn) < 0.0001 and abs(loaded.stride_time - left) < 0.0001;
    assert abs(loaded.standing().x - 22.0) < 0.0001 and loaded.facing() == 20.0;
    for tick in range(12) {
        loaded.advance(1.0 / 120.0);
    }
    assert abs(loaded.pos.x - 22.0) < 0.0001 and abs(loaded.pos.y - 3.0) < 0.0001;
    assert abs(math.degrees(loaded.yaw) - 20.0) < 0.0001;
    # A monster that has never stepped writes nothing and loads untouched.
    assert other.step_random == 0 and other.stride_time == 0.0 and "STEP 1" not in data;
}
