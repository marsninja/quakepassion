import from engine.world.triggers { TriggerTick }
import from engine.formats.bsp { Brush, Plane, Model, MapEntity }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture }


def trigger_fixture(game: str = "q2", once: bool = False) -> DoorFixture {
    fixture = DoorFixture();
    fixture.setup(game, {"targetname": "gate"});
    fixture.bsp.models.append(Model(head=0, first_face=1, face_count=0, brushes=[0]));
    for normal in [
        Vec3(x=1.0),
        Vec3(x=-1.0),
        Vec3(y=1.0),
        Vec3(y=-1.0),
        Vec3(z=1.0),
        Vec3(z=-1.0)
    ] {
        fixture.bsp.planes.append(Plane(normal=normal, distance=8.0));
    }
    fixture.bsp.planes.append(
        Plane(normal=Vec3(x=1.0, y=1.0).normalized(), distance=0.0)
    );
    fixture.bsp.brushes.append(
        Brush(planes=[0, 1, 2, 3, 4, 5, 6], contents=1073741824)
    );
    fixture.bsp.entities.append(
        MapEntity(
            fields={
                "classname": "trigger_once" if once else "trigger_multiple",
                "model": "*2",
                "origin": "200 0 0",
                "target": "gate",
                "wait": "0.2"
            }
        )
    );
    return fixture;
}


def touch(
    fixture: DoorFixture,
    start: Vec3,
    finish: Vec3,
    dt: float = 0.01,
    touching: bool = True
) {
    fixture.world spawn TriggerTick(
        start=start, finish=finish, dt=dt, touching=touching
    );
}
