import from engine.world.level { unstick }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "a player start embedded a unit in the floor is lifted free, as SV_CheckStuck does" {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-256.0, y=-256.0, z=-64.0),
        Vec3(x=256.0, y=256.0, z=0.0),
        Vec3(),
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0)
    );
    collision.reindex();
    # The player box reaches 24 below its origin, so an origin at 23 is embedded.
    embedded = Vec3(z=23.0);
    assert collision.trace(embedded, embedded).start_solid;
    freed = unstick(collision, embedded);
    assert not collision.trace(freed, freed).start_solid;
    assert freed.z >= 24.0 and freed.z <= 40.0;
    # A free start is left alone.
    clear = Vec3(z=40.0);
    assert unstick(collision, clear).z == 40.0;
}
