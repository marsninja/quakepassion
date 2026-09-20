import from engine.world.liquids {
    LiquidSpace,
    LiquidVolume,
    HasLiquid,
    SampleLiquid,
    liquid_kind,
    load_liquids
}
import from engine.world.level { Level }
import from engine.world.world { Player }
import from engine.formats.bsp { Bsp, Model, Leaf, Brush, Plane }
import from engine.physics.collision { CollisionMap }
import from engine.physics.movement { MovePlayer }
import from engine.math.vec3 { Vec3 }


def pool() -> Level {
    volume = CollisionMap();
    volume.add_box(
        Vec3(x=-100.0, y=-100.0, z=-100.0),
        Vec3(x=100.0, y=100.0, z=0.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    space = LiquidSpace();
    space +>:HasLiquid:+> LiquidVolume(kind=1, volume=volume);
    return Level(active=True, bsp=Bsp(game="q3"), liquids=space);
}

test "point contents distinguish dry feet waist and submerged eyes" {
    level = pool();
    assert level.immersion(Vec3(z=50.0)).depth == 0;
    assert level.immersion(Vec3(z=40.0)).depth == 1;
    assert level.immersion(Vec3(z=10.0)).depth == 2;
    state = level.immersion(Vec3(z=-10.0));
    assert state.depth == 3 and state.kind == 1;
    assert level.immersion(Vec3(x=101.0, z=-10.0)).depth == 0;
}

test "Q1 immersion uses BSP leaf contents and ignores solid and sky" {
    for contents in [-1, -2, -3, -4, -5, -6] {
        level = Level(
            active=True,
            bsp=Bsp(
                game="q1",
                models=[Model(head=-1, first_face=0, face_count=0)],
                leaves=[
                    Leaf(contents=contents, vis_offset=-1, mins=Vec3(), maxs=Vec3())
                ]
            )
        );
        state = level.immersion(Vec3());
        wet = contents >= -5 and contents <= -3;
        assert state.depth == (3 if wet else 0);
        assert state.kind == (-contents - 2 if wet else 0);
    }
}

test "Q2 Q3 liquid brushes retain oblique planes and prioritize lava" {
    for game in ["q2", "q3"] {
        bsp = Bsp(
            game=game,
            models=[Model(head=-1, first_face=0, face_count=0, brushes=[0, 1])]
        );
        for n in [
            Vec3(x=1.0),
            Vec3(x=-1.0),
            Vec3(y=1.0),
            Vec3(y=-1.0),
            Vec3(z=1.0),
            Vec3(z=-1.0)
        ] {
            bsp.planes.append(Plane(normal=n, distance=10.0));
        }
        bsp.planes.append(Plane(normal=Vec3(x=1.0, y=1.0).normalized(), distance=0.0));
        bsp.brushes = [
            Brush(planes=[0, 1, 2, 3, 4, 5, 6], contents=32),
            Brush(planes=[0, 1, 2, 3, 4, 5, 6], contents=8)
        ];
        space = load_liquids(bsp);
        wet = space spawn SampleLiquid(point=Vec3(x=-5.0, y=-5.0));
        dry = space spawn SampleLiquid(point=Vec3(x=5.0, y=5.0));
        assert wet.result == 3 and dry.result == 0;
        assert liquid_kind(16, game) == 2;
    }
}

test "swimming supports ascent descent drag and a bounded input speed" {
    player = Player(pos=Vec3(z=22.0));
    for i in range(120) {
        player spawn MovePlayer(
            collision=CollisionMap(), water_depth=3, swim_wish=Vec3(z=1.0)
        );
    }
    assert player.pos.z > 100.0
        and player.velocity.z > 0.0
        and player.velocity.length() <= 160.0001;
    for i in range(120) {
        player spawn MovePlayer(
            collision=CollisionMap(), water_depth=3, swim_wish=Vec3(z=-1.0)
        );
    }
    assert player.velocity.z < 0.0;
    drifting = Player(velocity=Vec3(x=300.0));
    drifting spawn MovePlayer(collision=CollisionMap(), water_depth=3, dt=0.05);
    assert drifting.velocity.x < 300.0 and drifting.velocity.z < 0.0;
}

test "swimming keeps solid collision and pause while exiting restores gravity" {
    wall = CollisionMap();
    wall.add_box(
        Vec3(x=10.0, y=-100.0, z=-100.0),
        Vec3(x=20.0, y=100.0, z=100.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    player = Player(pos=Vec3(z=22.0));
    for i in range(120) {
        player spawn MovePlayer(collision=wall, water_depth=3, swim_wish=Vec3(x=1.0));
    }
    assert player.pos.x < 10.0 and player.pos.x > 9.0;
    before = player.pos.x;
    player spawn MovePlayer(
        collision=wall, water_depth=3, swim_wish=Vec3(x=-1.0), dt=0.0
    );
    assert player.pos.x == before;
    player.velocity = Vec3();
    player spawn MovePlayer(collision=CollisionMap(), water_depth=0, dt=0.05);
    assert player.velocity.z == -40.0;
}
