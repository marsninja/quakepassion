import from engine.world.navigation { NavigationGraph, RouteSearch }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "collision revisions invalidate cached support after a shared hull view moves it" {
    collision = CollisionMap();
    collision.add_box(Vec3(x=-100.0, y=-100.0, z=-40.0), Vec3(x=200.0, y=100.0), Vec3(), Vec3(), Vec3());
    network = NavigationGraph();
    network.refresh(collision);
    route = RouteSearch(start=Vec3(z=0.03125), finish=Vec3(x=96.0, z=0.03125), collision=collision, network=network);
    while not route.done { route.advance(); }
    assert route.result and network.connections;
    revision = collision.revision.serial;
    view = collision.for_body(26.0);
    view.set_offset(0, Vec3(z=-100.0));
    assert collision.revision.serial > revision;
    network.refresh(collision);
    assert not network.connections;
    invalid = RouteSearch(start=Vec3(z=0.03125), finish=Vec3(x=96.0, z=0.03125), collision=collision, network=network, budget=8);
    while not invalid.done { invalid.advance(); }
    assert not invalid.result;
    revision = collision.revision.serial;
    view.set_offset(0, Vec3(z=-100.0));
    assert collision.revision.serial == revision;
    collision.set_disabled(0, True);
    assert view.disabled == collision.disabled and collision.revision.serial > revision;
}
