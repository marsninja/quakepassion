import from engine.world.world { World, Area, Actor, move_to_area }
import from engine.world.models { ModelResource, attach_model, GatherModels }
import from engine.formats.animated { AnimatedModel }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }

test "world model gathering follows spatial actors and shared resource edges" {
    world = World();
    first = Area(name="first", bounds=AABB(mins=Vec3(), maxs=Vec3(x=10.0)));
    second = Area(name="second", bounds=AABB(mins=Vec3(x=10.0), maxs=Vec3(x=20.0)));
    world ++> first;
    world ++> second;
    resource = ModelResource(name="shared", model=AnimatedModel(), skins=[]);
    a = Actor(pos=Vec3(x=2.0));
    b = Actor(pos=Vec3(x=12.0));
    move_to_area(a, first);
    move_to_area(b, second);
    av = attach_model(a, resource);
    bv = attach_model(b, resource);
    scene = world spawn GatherModels();
    assert len(scene.draws) == 2;
    assert scene.draws[0].resource is scene.draws[1].resource;
    av.visible = False;
    move_to_area(b, first);
    b.pos = Vec3(x=3.0);
    bv.first = 2;
    scene = world spawn GatherModels();
    assert len(scene.draws) == 1 and scene.draws[0].origin.x == 3.0;
    assert scene.draws[0].first == 2;
}
