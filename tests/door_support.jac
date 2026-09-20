import from engine.world.doors { load_doors, DoorTick }
import from engine.world.world { World }
import from engine.formats.bsp { Bsp, Face, Model, MapEntity }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
obj DoorFixture {
    has world: World = World(),
        bsp: Bsp = Bsp(),
        collision: CollisionMap = CollisionMap();

    def setup(game: str = "q2", fields: dict[str, str] = {}) {
        self.bsp = Bsp(
            game=game,
            models=[
                Model(head=0, first_face=0, face_count=0),
                Model(head=0, first_face=0, face_count=1)
            ],
            faces=[
                Face(
                    vertices=[Vec3(x=-8.0, y=-32.0, z=0.0), Vec3(x=8.0, y=32.0, z=96.0)]
                )
            ],
            entities=[
                MapEntity(
                    fields={
                        "classname": "func_door",
                        "model": "*1",
                        "angle": "-1",
                        "speed": "88",
                        "wait": "0.1"
                    }
                )
            ]
        );
        for key in fields {
            self.bsp.entities[0].fields[key] = fields[key];
        }
        self.collision.add_brush(
            [
                Vec3(x=1.0),
                Vec3(x=-1.0),
                Vec3(y=1.0),
                Vec3(y=-1.0),
                Vec3(z=1.0),
                Vec3(z=-1.0)
            ],
            [8.0, 8.0, 32.0, 32.0, 96.0, 0.0],
            Vec3(x=-16.0, y=-16.0, z=-24.0),
            Vec3(x=16.0, y=16.0, z=32.0),
            Vec3()
        );
        self.collision.models = [1];
        load_doors(self.world, self.bsp, self.collision);
    }

    def tick(origin: Vec3, dt: float = 0.05) {
        self.world spawn DoorTick(
            bsp=self.bsp, collision=self.collision, player_origin=origin, dt=dt
        );
    }
}

def pair_fixture(game: str, locked: bool = False) -> DoorFixture {
    fixture = DoorFixture();
    fixture.setup(game);
    fixture.world = World();
    fixture.bsp.models.append(Model(head=0, first_face=1, face_count=1));
    fixture.bsp.faces.append(
        Face(vertices=[Vec3(x=-8.0, y=32.0), Vec3(x=8.0, y=96.0, z=96.0)])
    );
    fixture.bsp.entities[0].fields["team"] = "pair";
    fixture.bsp.entities.append(
        MapEntity(
            fields={
                "classname": "func_door",
                "model": "*2",
                "team": "pair",
                "angle": "-2",
                "speed": "44",
                "wait": "0.1",
                "targetname": "key" if locked else ""
            }
        )
    );
    fixture.collision.add_brush(
        [
            Vec3(x=1.0),
            Vec3(x=-1.0),
            Vec3(y=1.0),
            Vec3(y=-1.0),
            Vec3(z=1.0),
            Vec3(z=-1.0)
        ],
        [8.0, 8.0, 32.0, 32.0, 96.0, 0.0],
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0),
        Vec3(y=64.0)
    );
    fixture.collision.models.append(2);
    load_doors(fixture.world, fixture.bsp, fixture.collision);
    return fixture;
}
