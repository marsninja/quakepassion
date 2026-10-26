"""Read originals as blueprints and say how each splits: its grid, its
regions (cells, box, what they hold) and the doors between them.

    jac build scripts/passion_blueprint.jac --native -o .jac/qp-blueprint
    QP_BLUEPRINTS="q1:e1m1 q1:e1m2" DYLD_LIBRARY_PATH=vendor .jac/qp-blueprint"""
import os;
import time;
import from games.passion.blueprint { Blueprint, Region, Cut, read_blueprint, blueprint_regions, BP_AIR, BP_WATER, BP_SLIME, BP_LAVA, BP_SKY }
import from games.passion.derive { derived_library }

with entry {
    if os.getenv("QP_PIECES", "") {
        notes: list[str] = [];
        derived_library((os.getenv("QP_BLUEPRINTS") or "q1:e1m1").split(), notes);
        for note in notes {
            print("PIECE", note);
        }
        # The region on each side of a cell column: QP_COLUMN="spec x y".
    }
    for spec in (os.getenv("QP_BLUEPRINTS") or "q1:e1m1").split() {
        began = time.time();
        made = read_blueprint(spec);
        tally = [0, 0, 0, 0, 0, 0];
        for code in made.codes {
            tally[code] += 1;
        }
        print("BLUEPRINT", spec, made.nx, "x", made.ny, "x", made.nz, "cells in", round(time.time() - began, 1), "s; air", tally[BP_AIR], "water", tally[BP_WATER], "slime", tally[BP_SLIME], "lava", tally[BP_LAVA], "sky", tally[BP_SKY]);
        for region in blueprint_regions(made) {
            kinds: dict[str, int] = {};
            for number in region.things {
                kind = made.things[number].classname;
                kinds[kind] = kinds.get(kind, 0) + 1;
            }
            print(
                "REGION", spec, region.number, "cells", region.cells, "box", (region.x0 + made.ox) * 32, (region.y0 + made.oy) * 32, (region.z0 + made.oz) * 16,
                (region.x1 + made.ox) * 32, (region.y1 + made.oy) * 32, (region.z1 + made.oz) * 16, "start" if region.start else "", "exit" if region.way_out else "",
                sorted(kinds.items())
            );
            for cut in [edge region->:Cut:->] {
                for number in cut.doors {
                    door = made.things[number];
                    print("CUT", spec, region.number, "->", [region->:Cut:->][?:Region][0].number if False else "", "door", number, door.fields.get("targetname", "-"), "spawnflags", door.fields.get("spawnflags", "0"), "at", int(door.point.x), int(door.point.y), int(door.point.z));
                }
            }
        }
        for (number, thing) in enumerate(made.things) {
            if thing.classname == "func_door" {
                openers = [other.classname + "@" + str(other.region) for other in made.things if other.fields.get("target", "") and other.fields.get("target", "") == thing.fields.get("targetname", "")];
                print("DOOR", spec, number, "region", thing.region, "name", thing.fields.get("targetname", "-"), "flags", thing.fields.get("spawnflags", "0"), "openers", openers);
            }
        }
        for note in made.notes {
            print("NOTE", spec, note);
        }
    }
}
