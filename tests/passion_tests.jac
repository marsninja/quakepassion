"""Passion's generator: the massing seals what it carves, every archetype
gives doorways and a stage, arrangements are deterministic and their
corridors join the doorways they were routed between, the cast keeps its
promises (a start, an exit, a door for each lock), the critic and the light
cache work, and a compiled expedition can be walked from its start to its
exit by the yardstick's traversal of its real collision."""
import from engine.math.vec3 { Vec3 }
import from engine.formats.bsp { Bsp, Face }
import from engine.formats.brush_collision { build_brush_collision }
import from games.passion.random { stream_for }
import from games.passion.mission { build_mission, beats_of, links_of, validate_mission }
import from games.passion.massing { Massing, CELL, LIFT, floor_reached }
import from games.passion.spaces { Space, ARCHETYPES, shape_space, space_size }
import from games.passion.arrange { arrange, estate_spaces, estate_corridors, doorway_block, Estate, CORRIDOR_HIGH }
import from games.passion.generate { seed_from, survey, pack_light, unpack_light, VERSION }
import from games.passion.critic { critic_measures, critic_score }
import from games.passion.yardstick { traverse, Spread, level_start }
import from editor.formats.map { MapFile }
import from editor.document.scene { scene_from_map }
import from editor.compile.live { compile_scene, SwatchMaterials }

test "the massing's shell seals every cell of air" {
    mass = Massing(nx=12, ny=12, nz=12);
    mass.carve(2, 2, 2, 6, 7, 8, 0);
    mass.carve(6, 4, 2, 9, 5, 5, 1);
    covered: dict[int, bool] = {};
    for box in mass.shell() {
        for z in range(box.z0, box.z1) {
            for y in range(box.y0, box.y1) {
                for x in range(box.x0, box.x1) {
                    assert not mass.air(x, y, z);
                    covered[(z * 12 + y) * 12 + x] = True;
                }
            }
        }
    }
    for z in range(12) {
        for y in range(12) {
            for x in range(12) {
                if not mass.air(x, y, z) {
                    continue;
                }
                for dz in [-1, 0, 1] {
                    for dy in [-1, 0, 1] {
                        for dx in [-1, 0, 1] {
                            nx = x + dx;
                            ny = y + dy;
                            nz = z + dz;
                            assert mass.air(nx, ny, nz) or ((nz * 12 + ny) * 12 + nx) in covered;
                        }
                    }
                }
            }
        }
    }
}

test "every archetype carves a stage to stand on and doorways" {
    dice = stream_for(5, "test");
    for (index, kind) in enumerate(ARCHETYPES) {
        dims = space_size(kind, 1, dice);
        mass = Massing(nx=dims[0] + 8, ny=dims[1] + 8, nz=dims[2] + 8);
        space = Space(id=0, kind=kind, x=4, y=4, z=4, w=dims[0], d=dims[1], h=dims[2]);
        shape_space(space, mass, dice.child("shape", index));
        assert len(space.stage) == 3 , kind;
        assert mass.standing(space.stage[0], space.stage[1], space.stage[2]) , kind + " has no floor at its stage";
        assert len([door for door in space.sockets if door.floored]) > 0 , kind + " has no doorway";
        reached = floor_reached(mass, space.stage[0], space.stage[1], space.stage[2]);
        for level in space.levels {
            found = False;
            for cy in range(space.y, space.y + space.d) {
                for cx in range(space.x, space.x + space.w) {
                    if ((level * mass.ny + cy) * mass.nx + cx) in reached {
                        found = True;
                    }
                }
            }
            assert found , kind + " cannot be walked to its floor at " + str(level);
        }
    }
}

def:priv layout_of(seed: int) -> list[any] {
    stream = stream_for(seed, "candidate").child("k", 0);
    plan = build_mission(seed, stream.derive("mission"), "keys", 2, 2, 16, 0.5);
    return [plan, arrange(plan, stream.derive("layout"))];
}

test "arrangements are deterministic and corridors join their doorways" {
    first = layout_of(11);
    second = layout_of(11);
    estate_a: Estate = first[1][0];
    estate_b: Estate = second[1][0];
    spaces_a = estate_spaces(estate_a);
    spaces_b = estate_spaces(estate_b);
    assert len(spaces_a) == len(spaces_b);
    for index in range(len(spaces_a)) {
        assert spaces_a[index].x == spaces_b[index].x and spaces_a[index].z == spaces_b[index].z;
        assert spaces_a[index].kind == spaces_b[index].kind;
    }
    by_id: dict[int, Space] = {};
    for space in spaces_a {
        by_id[space.id] = space;
    }
    mass: Massing = first[1][1];
    routed = 0;
    for corridor in estate_corridors(estate_a) {
        if corridor.teleport or corridor.window {
            continue;
        }
        routed += 1;
        assert corridor.out_door is not None and corridor.in_door is not None;
        assert corridor.blocks[0] == doorway_block(by_id[corridor.tail], corridor.out_door);
        goal = doorway_block(by_id[corridor.head], corridor.in_door);
        if len(corridor.blocks) == 1 {
            # Wall to wall: one doorway through both walls, stepped where the
            # floors differ by a lift or two.
            assert corridor.blocks[0][0] == goal[0] and corridor.blocks[0][1] == goal[1];
            assert abs(corridor.blocks[0][2] - goal[2]) <= 2;
            assert mass.air(goal[0], goal[1], max(corridor.blocks[0][2], goal[2]));
            continue;
        }
        assert corridor.blocks[-1] == goal;
        for index in range(1, len(corridor.blocks)) {
            a = corridor.blocks[index - 1];
            b = corridor.blocks[index];
            assert abs(a[0] - b[0]) + abs(a[1] - b[1]) == 1 and abs(a[2] - b[2]) <= 1;
        }
        for block in corridor.blocks {
            assert mass.air(block[0], block[1], block[2]);
        }
    }
    assert routed > 0;
}

test "expedition names parse strictly" {
    assert seed_from(VERSION + "-42") == 42;
    for bad in ["v2-42", VERSION + "-042", VERSION + "-0", VERSION + "-2147483647", "42"] {
        refused = False;
        try {
            seed_from(bad);
        } except ValueError {
            refused = True;
        }
        assert refused , bad;
    }
}

test "a survey keeps its promises: start, exit, a door for every lock, a fair score" {
    record = survey(7);
    casting = record.casting;
    plan = record.plan;
    estate = record.estate;
    assert casting is not None and plan is not None and estate is not None;
    validate_mission(plan);
    assert len(casting.start) == 3 and len(casting.exit_low) == 3;
    locks = len([link for link in links_of(plan) if link.needs]);
    assert casting.doors >= min(1, locks);
    assert record.items and record.items[0].fields["classname"] == "worldspawn";
    assert len(record.items[0].brushes) > 500;
    assert record.score > -60.0 , str(record.score);
    assert record.measures["levels"] >= 2.0;
    again = survey(7);
    assert again.score == record.score and len(again.items) == len(record.items);
}

test "a level's light is kept and read back whole" {
    bsp = Bsp(game="passion");
    for index in range(3) {
        face = Face(vertices=[Vec3(), Vec3(x=1.0), Vec3(y=1.0)]);
        face.light_offset = index * 12;
        face.light_width = 2;
        face.light_height = 2;
        face.styles = [0, 33] if index == 1 else [0];
        face.light_uv = [0.0, 0.5, 1.0, 1.5, 0.25, 0.75];
        face.colors = [10, 20, 30, 255] if index == 2 else [];
        bsp.faces.append(face);
    }
    bsp.lighting = bytes([index % 128 for index in range(36)]);
    bsp.light_grid = bytes([1, 2, 3, 4, 5, 6, 7, 8]);
    bsp.light_channels = 3;
    data = pack_light(bsp);
    fresh = Bsp(game="passion");
    for index in range(3) {
        fresh.faces.append(Face(vertices=[Vec3(), Vec3(x=1.0), Vec3(y=1.0)]));
    }
    assert unpack_light(data, fresh);
    assert fresh.faces[1].styles == [0, 33] and fresh.faces[2].colors == [10, 20, 30, 255];
    assert fresh.faces[0].light_uv[3] == 1.5 and fresh.lighting == bsp.lighting and fresh.light_grid == bsp.light_grid;
    fresh.faces.append(Face());
    assert not unpack_light(data, fresh);
    assert not unpack_light(data[:-1], fresh);
}

test "a compiled expedition is walked from its start to its exit" {
    record = survey(3);
    casting = record.casting;
    assert casting is not None;
    scene = scene_from_map("passion", "v3-3", MapFile(items=record.items));
    made = compile_scene(scene, SwatchMaterials(), True);
    collision = build_brush_collision(made.bsp);
    walk = traverse(made.bsp, collision, 32.0);
    start = level_start(made.bsp);
    assert start is not None;
    first = walk.nearest(start);
    assert first >= 0;
    walk.areas[walk.places[first].area] spawn Spread();
    goal = Vec3(
        x=(casting.exit_low[0] + casting.exit_high[0]) * 0.5,
        y=(casting.exit_low[1] + casting.exit_high[1]) * 0.5,
        z=casting.exit_low[2] + 24.0
    );
    last = walk.nearest(goal, 160.0);
    assert last >= 0 , "nowhere to stand at the exit";
    assert walk.areas[walk.places[last].area].reached , "the exit cannot be reached from the start";
}
