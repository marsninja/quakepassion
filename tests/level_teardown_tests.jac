"""Level teardown destroys the last level's whole graph: the world, whatever
is connected to it in either direction, and the collision trees beside it."""
import from engine.world.world { World }
import from engine.world.level { Split, BspArea, Front, Back }
import from engine.world.teardown { Teardown, destroy_graph, collision_roots }
import from engine.physics.collision { HullCell, HullFront, HullBack, CollisionMap }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

def area(index: int) -> BspArea {
    return BspArea(
        name=str(index), bounds=AABB(mins=Vec3(), maxs=Vec3()), index=index
    );
}

def hull_tree -> HullCell {
    cell = HullCell(normal=Vec3(z=1.0), distance=0.0);
    cell +>:HullFront:+> HullCell(contents=-1);
    cell +>:HullBack:+> HullCell(contents=-2);
    return cell;
}

test "teardown gathers everything connected to the world and its roots" {
    world = World();
    first = area(0);
    second = area(1);
    world ++> first;
    world ++> second;
    # Splits only point at areas: reached backwards from them.
    split = Split(normal=Vec3(x=1.0), distance=0.0);
    split +>:Front:+> first;
    split +>:Back:+> second;
    collision = CollisionMap(hulls=[hull_tree()], offsets=[Vec3()]);
    sweep = world spawn Teardown(roots=collision_roots(collision));
    assert len(sweep.doomed) == 7 , str(len(sweep.doomed));
}

test "destroying the graph disconnects every node" {
    world = World();
    first = area(0);
    world ++> first;
    tree = hull_tree();
    destroyed = destroy_graph(world, [tree]);
    assert destroyed == 5 , str(destroyed);
    assert len([world-->]) == 0;
    assert len([first<--]) == 0;
    assert len([tree-->]) == 0;
}
