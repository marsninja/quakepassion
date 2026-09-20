"""BSP graph queries and visibility must respect the world model's leaf count."""
import from engine.world.world { World }
import from engine.world.level {
    Level,
    Split,
    BspArea,
    Front,
    Back,
    Locate,
    CollectFaces
}
import from engine.formats.bsp { Bsp, Model, Leaf }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

def test_area(index: int, faces: list[int]) -> BspArea {
    return BspArea(
        name=str(index), bounds=AABB(mins=Vec3(), maxs=Vec3()), index=index, faces=faces
    );
}

test "BSP plane traversal chooses front back and on-plane leaves" {
    split = Split(normal=Vec3(x=1.0), distance=10.0);
    front = test_area(1, [0]);
    back = test_area(2, [1]);
    split +>:Front:+> front;
    split +>:Back:+> back;
    assert (split spawn Locate(eye=Vec3(x=11.0))).result == 1;
    assert (split spawn Locate(eye=Vec3(x=9.0))).result == 2;
    assert (split spawn Locate(eye=Vec3(x=10.0))).result == 1;
}

test "face collection deduplicates shared leaf surfaces" {
    world = World();
    a = test_area(1, [0, 1]);
    b = test_area(2, [1, 2]);
    world ++> a;
    world ++> b;
    gather = world spawn CollectFaces(targets=[a, b]);
    assert gather.faces == [0, 1, 2];
}

test "visibility excludes appended brush leaves even with culling off" {
    world = World();
    split = Split(normal=Vec3(x=1.0), distance=0.0);
    areas = [
        test_area(0, []),
        test_area(1, [10]),
        test_area(2, [20]),
        test_area(3, [99])
    ];
    split +>:Front:+> areas[1];
    split +>:Back:+> areas[2];
    leaves: list[Leaf] = [];
    for i in range(4) {
        leaves.append(Leaf(contents=-1, vis_offset=0, mins=Vec3(), maxs=Vec3()));
    }
    bsp = Bsp(
        visibility=b"\x01",
        leaves=leaves,
        models=[Model(head=0, first_face=0, face_count=2, vis_leaf_count=2)]
    );
    level = Level(active=True, bsp=bsp, areas=areas, splits=[split], brush_faces=[30]);
    assert level.visible(world, Vec3(x=1.0), True) == [10, 30];
    assert level.visible(world, Vec3(x=1.0), False) == [10, 20, 30];
}
