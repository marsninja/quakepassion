import from engine.world.models { Placement }
import from engine.formats.animated { ModelTag }
import from engine.math.orientation { Basis }
import from engine.math.vec3 { Vec3 }

test "tag composition rotates directions and translates only positions" {
    tag = ModelTag(name="test", origin=Vec3(x=10.0, z=20.0),
        axes=[Vec3(y=1.0), Vec3(x=-1.0), Vec3(z=1.0)]);
    body = Placement(
        origin=Vec3(), basis=Basis(forward=Vec3(x=1.0), left=Vec3(y=1.0), up=Vec3(z=1.0))
    );
    child = body.on_tag(tag);
    point = child.origin.add(child.basis.apply(Vec3(x=2.0, y=3.0, z=4.0)));
    normal = child.basis.apply(Vec3(x=2.0));
    assert point.x == 7.0 and point.y == 2.0 and point.z == 24.0;
    assert normal.x == 0.0 and normal.y == 2.0 and normal.z == 0.0;
}
