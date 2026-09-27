"""Idle entities stay cheap: settled monsters, far riders and out-of-reach
volumes skip their collision work without changing what happens."""
import from engine.world.combat { CombatState, CombatTick, Opponent, HasOpponent }
import from engine.world.trains { Train, HasTrain, TrainTick }
import from engine.world.triggers { MonsterJump, HasMonsterJump, MonsterJumpTick }
import from engine.world.targets { TargetEvent, HasTarget, TargetTick }
import from engine.world.world { World, Player }
import from engine.physics.collision { CollisionMap, Sweep, HullCell, HullFront, HullBack }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from tests.train_support { train_fixture }

def:priv floor_map() -> CollisionMap {
    collision = CollisionMap();
    # A floor slab (hull 0) and a far-away block (hull 1), player-expanded.
    collision.add_box(
        Vec3(x=-256.0, y=-256.0, z=-16.0),
        Vec3(x=256.0, y=256.0, z=0.0),
        Vec3(),
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0)
    );
    collision.add_box(
        Vec3(x=3000.0, y=3000.0, z=0.0),
        Vec3(x=3064.0, y=3064.0, z=64.0),
        Vec3(),
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0)
    );
    collision.models = [0, 2];
    collision.reindex();
    return collision;
}

def:priv run_ticks(world: World, player: Player, collision: CollisionMap, state: CombatState, count: int) {
    for i in range(count) {
        world spawn CombatTick(
            player=player, collision=collision, state=state, dt=1.0 / 120.0
        );
    }
}

test "settled monsters rest until a mover near them changes" {
    world = World();
    collision = floor_map();
    enemy = Opponent(pos=Vec3(z=70.0), health=50);
    world +>:HasOpponent:+> enemy;
    player = Player(pos=Vec3(x=5000.0, z=22.0));
    state = CombatState();
    run_ticks(world, player, collision, state, 240);
    assert enemy.grounded and enemy.rest_serial >= 0;
    rest = enemy.pos.add(Vec3());
    run_ticks(world, player, collision, state, 30);
    assert enemy.pos.z == rest.z and enemy.rest_serial >= 0;
    # A change far away leaves it settled.
    collision.set_offset(1, Vec3(z=8.0));
    run_ticks(world, player, collision, state, 12);
    assert enemy.rest_serial == collision.revision.serial and enemy.pos.z == rest.z;
    # Its floor going away drops it within one support check.
    collision.set_disabled(0, True);
    run_ticks(world, player, collision, state, 12);
    assert not enemy.grounded and enemy.pos.z < rest.z;
}

test "settled monsters resume moving when moved or pushed" {
    world = World();
    collision = floor_map();
    enemy = Opponent(pos=Vec3(z=70.0), health=50);
    world +>:HasOpponent:+> enemy;
    player = Player(pos=Vec3(x=5000.0, z=22.0));
    state = CombatState();
    run_ticks(world, player, collision, state, 240);
    assert enemy.rest_serial >= 0;
    enemy.velocity = Vec3(x=200.0);
    run_ticks(world, player, collision, state, 2);
    assert enemy.pos.x > 0.0;
    run_ticks(world, player, collision, state, 240);
    assert enemy.rest_serial >= 0;
    # Carried or teleported elsewhere, it checks its new footing.
    enemy.pos = enemy.pos.add(Vec3(x=64.0, z=30.0));
    lifted = enemy.pos.z;
    run_ticks(world, player, collision, state, 12);
    assert enemy.pos.z < lifted;
}

test "trains carry nearby riders and ignore far actors" {
    f = train_fixture();
    train = [f.world->:HasTrain:->][?:Train][0];
    assert len(train.extents) == len(train.hulls);
    rider = Opponent(pos=Vec3(z=120.03125 + 22.0), health=50, eye_height=22.0);
    far = Opponent(pos=Vec3(x=4000.0, z=120.03125 + 22.0), health=50, eye_height=22.0);
    for actor in [rider, far] {
        f.world +>:HasOpponent:+> actor;
    }
    for i in range(120) {
        f.world spawn TrainTick(bsp=f.bsp, collision=f.collision, dt=1.0 / 120.0);
    }
    assert train.motion.z > 55.0;
    assert abs(rider.pos.z - 120.03125 - 22.0 - train.motion.z) < 0.0001;
    assert far.pos.z == 120.03125 + 22.0;
}

test "monster jump volumes only test monsters inside their bounds" {
    world = World();
    volume = CollisionMap();
    volume.add_box(
        Vec3(x=-32.0, y=-32.0, z=-32.0),
        Vec3(x=32.0, y=32.0, z=32.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    volume.reindex();
    jump = MonsterJump(volume=volume, push=Vec3(x=300.0), height=250.0);
    jump.reach = volume.groups[0].bounds;
    world +>:HasMonsterJump:+> jump;
    inside = Opponent(health=50, grounded=True, pos=Vec3(z=22.0), eye_height=22.0);
    outside = Opponent(health=50, grounded=True, pos=Vec3(x=100.0, z=22.0), eye_height=22.0);
    world +>:HasOpponent:+> inside;
    world +>:HasOpponent:+> outside;
    result = world spawn MonsterJumpTick();
    assert result.launched == 1 and inside.velocity.z == 250.0;
    assert outside.grounded and outside.velocity.length() == 0.0;
}

test "lasers trace and burn on their tenth-second think" {
    world = World();
    player = Player(health=100, pos=Vec3(x=64.0, z=22.0));
    beam = TargetEvent(kind="laser", origin=Vec3(x=-200.0, z=22.0), direction=Vec3(x=1.0), damage=5, on=True);
    world +>:HasTarget:+> beam;
    state = CombatState(game="q2");
    for i in range(24) {
        world spawn TargetTick(player=player, collision=CollisionMap(), state=state, dt=1.0 / 120.0);
    }
    # Burns at the first think and again after each tenth of a second.
    assert player.health == 100 - 5 * 2;
}

test "bsp sweeps keep the earliest hit and start-solid across split spans" {
    # A two-plane BSP: solid where x > 64 and, behind a z split, where z < 0.
    top = HullCell(normal=Vec3(x=1.0), distance=64.0);
    solid = HullCell(contents=-2);
    empty = HullCell(contents=-1);
    floor = HullCell(normal=Vec3(z=1.0), distance=0.0);
    top +>:HullFront:+> solid;
    top +>:HullBack:+> floor;
    floor +>:HullFront:+> empty;
    floor +>:HullBack:+> solid;
    wall = top spawn Sweep(start=Vec3(z=10.0), finish=Vec3(x=128.0, z=10.0));
    assert abs(wall.result.fraction - 0.5) < 0.000001 and wall.result.normal.x == -1.0;
    assert not wall.result.start_solid;
    down = top spawn Sweep(start=Vec3(z=10.0), finish=Vec3(x=128.0, z=-30.0));
    assert abs(down.result.fraction - 0.25) < 0.000001 and down.result.normal.z == 1.0;
    inside = top spawn Sweep(start=Vec3(z=-10.0), finish=Vec3(z=10.0));
    assert inside.result.start_solid and inside.result.fraction == 0.0;
    clear = top spawn Sweep(start=Vec3(z=10.0), finish=Vec3(x=32.0, z=20.0));
    assert clear.result.fraction == 1.0 and not clear.result.start_solid;
}
