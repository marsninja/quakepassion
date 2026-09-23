import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.combat { CombatState, CombatTick, Opponent, HasOpponent }
import from engine.world.trains { TrackPoint, TrackNext, HasTrack }
import from engine.world.patrols { Patrols, Holds, PatrolTick }
import from engine.world.signals { Signal, Targets }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

def floor() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(Vec3(x=-2000.0, y=-2000.0, z=-64.0), Vec3(x=2000.0, y=2000.0, z=0.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    return collision;
}

def monster(game: str, kind: str, pos: Vec3) -> Opponent {
    rule = enemy_rule(game, kind, 0);
    assert rule is not None;
    return Opponent(
        rule=rule, kind=kind, game=game, pos=pos, health=rule.health, max_health=rule.health,
        walk_speed=rule.speed, patrol_speed=31.0, grounded=True, walk_animation=[1, 2, 3]
    );
}

def corner(world: World, entity: int, name: str, origin: Vec3, hold: float = 0.0) -> TrackPoint {
    point = TrackPoint(entity=entity, name=name, origin=origin, hold_time=hold, activation=Signal(entities=[entity]));
    world +>:HasTrack:+> point;
    return point;
}

def run(world: World, player: Player, collision: CollisionMap, state: CombatState, seconds: float) {
    for tick in range(int(seconds * 60.0)) {
        world spawn PatrolTick(dt=1.0 / 60.0);
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 60.0);
    }
}

test "idle monsters walk their path corner loop at walking pace" {
    world = World();
    collision = floor();
    state = CombatState();
    player = Player(pos=Vec3(x=-1900.0, y=1900.0, z=22.0));
    a = corner(world, 1, "a", Vec3(x=100.0));
    b = corner(world, 2, "b", Vec3(x=100.0, y=100.0));
    a +>:TrackNext:+> b;
    b +>:TrackNext:+> a;
    knight = monster("q1", "monster_knight", Vec3(z=22.0));
    world +>:HasOpponent:+> knight;
    knight +>:Patrols:+> a;
    run(world, player, collision, state, 1.0);
    assert knight.pos.x > 10.0 and knight.pos.x < 60.0;
    assert knight.walk_speed == 31.0 and knight.pose_name == "walk";
    run(world, player, collision, state, 4.0);
    assert [knight->:Patrols:->][?:TrackPoint][0] is b;
    run(world, player, collision, state, 4.0);
    assert [knight->:Patrols:->][?:TrackPoint][0] is a and knight.pos.y > 60.0;
    assert knight.alert == 0.0;
}

test "Q2 corners pause for their wait and fire their pathtarget" {
    world = World();
    collision = floor();
    state = CombatState();
    player = Player(pos=Vec3(x=-1900.0, y=1900.0, z=22.0));
    stop = corner(world, 1, "stop", Vec3(x=40.0), 2.0);
    go = corner(world, 2, "go", Vec3(x=200.0));
    stop +>:TrackNext:+> go;
    light = Signal(entities=[3]);
    stop.activation +>:Targets:+> light;
    guard = monster("q2", "monster_soldier", Vec3(z=22.0));
    world +>:HasOpponent:+> guard;
    guard +>:Patrols:+> stop;
    run(world, player, collision, state, 1.0);
    assert light.pending == 1 and guard.patrol_wait > 0.0;
    resting = guard.pos.x;
    run(world, player, collision, state, 0.5);
    assert abs(guard.pos.x - resting) < 1.0;
    run(world, player, collision, state, 3.0);
    assert guard.pos.x > resting + 20.0;
}

test "Q2 monsters run to their combat point before opening fire" {
    world = World();
    collision = floor();
    state = CombatState();
    player = Player(pos=Vec3(x=-300.0, z=22.0));
    post = corner(world, 1, "post", Vec3(x=200.0));
    post.combat = True;
    guard = monster("q2", "monster_soldier", Vec3(z=22.0));
    guard.yaw = 3.14159;
    world +>:HasOpponent:+> guard;
    guard +>:Holds:+> post;
    run(world, player, collision, state, 0.5);
    assert guard.alert > 0.0 and guard.holding and guard.attack_clock < 0.0;
    assert player.health == 100 and guard.pos.x > 5.0;
    run(world, player, collision, state, 6.0);
    assert not [guard->:Holds:->] and not guard.holding;
}

test "patrol progress survives a save" {
    world = World();
    a = corner(world, 1, "a", Vec3(x=100.0));
    b = corner(world, 2, "b", Vec3(x=100.0, y=100.0), 3.0);
    guard = monster("q2", "monster_soldier", Vec3(z=22.0));
    world +>:HasOpponent:+> guard;
    guard +>:Patrols:+> b;
    guard.patrol_wait = 1.5;
    level = Level();
    level.name = "test";
    player = Player();
    data = snapshot(world, level, player, CombatState());
    for stale in [edge guard->:Patrols:->] {
        del stale;
    }
    guard +>:Patrols:+> a;
    guard.patrol_wait = 0.0;
    restore(world, level, player, CombatState(), data);
    assert [guard->:Patrols:->][?:TrackPoint][0] is b and guard.patrol_wait == 1.5;
}
