import math;
import from engine.world.world { World }
import from engine.world.portals { PortalSurface, HasPortal, portal_view, perpendicular, load_portals }
import from engine.formats.bsp { Bsp, Face, MapEntity }
import from engine.world.world { Player }
import from engine.world.reflection { PlayerBody, HasBody, Carries, player_body, show_body }
import from engine.world.models { ModelResource, UsesModel }
import from engine.formats.animated { AnimatedModel, AnimatedSurface, AnimationFrame }
import from engine.math.vec3 { Vec3 }

def close(a: Vec3, b: Vec3) -> bool {
    return a.sub(b).length() < 0.001;
}

test "mirrors reflect the view and portals look out of their camera" {
    world = World();
    wall = Face(normal=Vec3(x=1.0), plane_dist=0.0, vertices=[Vec3(), Vec3(y=64.0), Vec3(y=64.0, z=64.0)]);
    eye = Vec3(x=100.0, z=50.0);
    forward = Vec3(x=-1.0);
    left = Vec3(y=-1.0);
    up = Vec3(z=1.0);
    assert portal_view(world, wall, eye, forward, left, up, 0.0) is None;
    world +>:HasPortal:+> PortalSurface(pos=Vec3(x=8.0));
    mirrored = portal_view(world, wall, eye, forward, left, up, 0.0);
    assert mirrored is not None and mirrored.mirror;
    # The eye reflects through the wall and looks back out; left stays left.
    assert close(mirrored.origin, Vec3(x=-100.0, z=50.0)) and close(mirrored.forward, Vec3(x=1.0));
    assert close(mirrored.left, Vec3(y=-1.0)) and close(mirrored.up, Vec3(z=1.0));
    # Nothing behind the mirror plane is drawn.
    assert close(mirrored.clip_normal, Vec3(x=1.0)) and abs(mirrored.clip_dist) < 0.001;
    # A camera portal: misc_portal_camera at (1000, 0, 0) aimed along +y.
    other = World();
    bsp = Bsp(game="q3");
    bsp.entities = [
        MapEntity(fields={"classname": "misc_portal_surface", "origin": "8 0 0", "target": "cam"}),
        MapEntity(fields={"classname": "misc_portal_camera", "origin": "1000 0 0", "targetname": "cam", "angle": "90"})
    ];
    load_portals(other, bsp);
    portal = [other->:HasPortal:->][?:PortalSurface][0];
    assert not portal.mirror and close(portal.aim, Vec3(y=1.0)) and portal.sway;
    through = portal_view(other, wall, eye, forward, left, up, 0.0);
    assert through is not None and not through.mirror;
    # Looking into the portal looks along the camera's aim, offset as the eye is.
    assert close(through.forward, Vec3(y=1.0)) and close(through.origin, Vec3(x=1000.0, y=-100.0, z=50.0));
    assert close(through.pvs, Vec3(x=1000.0));
    # The default sway swings the camera up to four degrees about its aim.
    swung = portal_view(other, wall, eye, forward, left, up, math.pi / 6.0);
    assert swung is not None and abs(math.degrees(math.acos(swung.up.dot(through.up))) - 4.0) < 0.01;
    assert close(perpendicular(Vec3(z=1.0)), Vec3(x=1.0));
}

test "the player's body follows them into portal views only" {
    world = World();
    surface = AnimatedSurface(name="body");
    for pose in ["stand0", "run0", "run1", "run2", "attack0"] {
        surface.frames.append(AnimationFrame(name=pose));
    }
    model = ModelResource(name="sarge", model=AnimatedModel(surfaces=[surface]), skins=[]);
    rail = ModelResource(name="rail", model=AnimatedModel(), skins=[]);
    body = player_body(model, 10.0);
    body +>:Carries(key="railgun"):+> rail;
    world +>:HasBody:+> body;
    assert not body.body.visible and body.run_frames == [1, 2, 3];
    player = Player(health=100, pos=Vec3(x=10.0, z=26.0), yaw=1.0);
    show_body(world, player, 26.0, "railgun", 0.0, True);
    assert body.body.visible and body.weapon.visible and body.pos.z == 0.0 and body.yaw == 1.0;
    assert body.body.first == 0 and [body.weapon->:UsesModel:->][?:ModelResource] == [rail];
    # Running plays the leg cycle at its rate.
    player.velocity = Vec3(x=320.0);
    show_body(world, player, 26.0, "railgun", 0.15, True);
    assert body.body.first == 2 and body.body.second == 3 and body.weapon.first == 2;
    show_body(world, player, 26.0, "railgun", 0.15, False);
    assert not body.body.visible and not body.weapon.visible;
}
