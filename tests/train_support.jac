"""Shared authored train fixture without registering test cases."""
import from tests.door_support { DoorFixture }
import from engine.world.trains { load_trains }
import from engine.world.doors { connect_targets }
import from engine.formats.bsp { MapEntity }

def train_fixture(
    game: str = "q2", flags: int = 0, named: bool = False
) -> DoorFixture {
    fixture = DoorFixture();
    fixture.setup(
        game,
        {
            "classname": "func_train",
            "target": "a",
            "speed": "64",
            "targetname": "train" if named else "",
            "spawnflags": str(flags)
        }
    );
    fixture.bsp.entities.extend(
        [
            MapEntity(
                fields={
                    "classname": "path_corner",
                    "targetname": "a",
                    "target": "b",
                    "origin": "0 0 0"
                }
            ),
            MapEntity(
                fields={
                    "classname": "path_corner",
                    "targetname": "b",
                    "target": "a",
                    "origin": "0 0 64",
                    "wait": "0.25"
                }
            )
        ]
    );
    load_trains(fixture.world, fixture.bsp, fixture.collision);
    connect_targets(fixture.world, fixture.bsp);
    return fixture;
}
