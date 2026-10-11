import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { Side, Mapping, box_sides }
import from editor.geometry.mapping { mapping_through, mapping_place }
import from editor.geometry.patch {
    patch_points,
    patch_brushes,
    patch_surface,
    places_text,
    places_from,
    places_even,
    places_projected_from,
    places_slid
}
import from editor.document.scene { Scene, Item }

def about(a: float, b: float, slack: float = 0.01) -> bool {
    return abs(a - b) < slack;
}

test "a material is laid on a plane so that three points have three places on it" {
    # A floor: sixty-four units of the world to sixty-four texels along x, and to thirty-two along y.
    laid = mapping_through([Vec3(), Vec3(x=64.0), Vec3(y=64.0)], [0.0, 0.0, 64.0, 0.0, 0.0, 32.0]);
    assert laid is not None and about(laid.s_scale, 1.0) and about(laid.t_scale, 2.0);
    assert about(laid.s_axis.x, 1.0) and about(laid.t_axis.y, 1.0);
    for (point, place) in [(Vec3(), [0.0, 0.0]), (Vec3(x=64.0), [64.0, 0.0]), (Vec3(y=64.0), [0.0, 32.0]), (Vec3(x=32.0, y=32.0), [32.0, 16.0])] {
        got = mapping_place(laid, point);
        assert about(got[0], place[0]) and about(got[1], place[1]);
    }
    # A slope, its places shifted: the three corners still come out where they were told.
    corners = [Vec3(x=10.0, y=0.0, z=5.0), Vec3(x=74.0, y=0.0, z=37.0), Vec3(x=10.0, y=64.0, z=5.0)];
    texels = [100.0, 20.0, 164.0, 20.0, 100.0, 84.0];
    sloped = mapping_through(corners, texels);
    assert sloped is not None;
    for index in range(3) {
        got = mapping_place(sloped, corners[index]);
        assert about(got[0], texels[index * 2]) and about(got[1], texels[index * 2 + 1]);
    }
    # Points in a line, or two with one place, lay nothing.
    assert mapping_through([Vec3(), Vec3(x=1.0), Vec3(x=2.0)], texels) is None;
    assert mapping_through(corners, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]) is None and mapping_through(corners, [1.0]) is None;
}

test "places are kept as a field, spread evenly, projected from a plane and slid by rows" {
    even = places_even(3, 3, 128.0, 64.0);
    assert even == [0.0, 0.0, 64.0, 0.0, 128.0, 0.0, 0.0, 32.0, 64.0, 32.0, 128.0, 32.0, 0.0, 64.0, 64.0, 64.0, 128.0, 64.0];
    assert places_text(even) == "0 0 64 0 128 0 0 32 64 32 128 32 0 64 64 64 128 64";
    assert places_from(places_text(even), 9) == even and places_from("1 2 3", 9) == [] and places_from("a b", 1) == [];
    assert places_text([0.5, 1.25]) == "0.5 1.25";
    row = places_slid(even, 3, 3, "row", 1, 8.0, -4.0);
    assert row[6] == 8.0 and row[7] == 28.0 and row[10] == 136.0 and row[0] == 0.0 and row[12] == 0.0;
    column = places_slid(even, 3, 3, "col", 2, 0.0, 16.0);
    assert column[5] == 16.0 and column[11] == 48.0 and column[3] == 0.0;
    assert places_slid(even, 3, 3, "all", -1, 1.0, 1.0)[17] == 65.0 and even[17] == 64.0;
    plain = Mapping(s_axis=Vec3(x=1.0), t_axis=Vec3(y=-1.0), s_shift=16.0, t_shift=0.0, s_scale=0.5, t_scale=0.5);
    cast = places_projected_from([Vec3(), Vec3(x=32.0, y=16.0, z=99.0)], plain);
    assert cast == [16.0, 0.0, 80.0, -32.0];
}

test "a patch's surface takes its material where its control points say" {
    made = patch_points("sheet", Vec3(z=64.0), Vec3(x=128.0, y=128.0, z=64.0));
    assert made[0] == 3 and made[1] == 3;
    places = places_even(3, 3, 256.0, 256.0);
    prisms = patch_brushes(made[2], 3, 3, 2, 8.0, "tile", [], places);
    plain = patch_brushes(made[2], 3, 3, 2, 8.0, "tile");
    assert len(prisms) == len(plain) and len(prisms) == 8;
    # Every prism's top lies the material two texels to the unit, in step with its neighbours:
    # a point of the surface has one place whichever prism is asked.
    surface = patch_surface(made[2], 3, 3, 2)[2];
    skin = patch_surface([Vec3(x=places[index * 2], y=places[index * 2 + 1]) for index in range(9)], 3, 3, 2)[2];
    checked = 0;
    for prism in prisms {
        for side in prism {
            if side.plane.normal.z < 0.99 {
                continue;
            }
            assert about(side.mapping.s_scale, 0.5) and about(side.mapping.t_scale, 0.5);
            for (index, point) in enumerate(surface) {
                if abs(side.plane.side(point)) < 0.01 {
                    got = mapping_place(side.mapping, point);
                    assert about(got[0], skin[index].x, 0.05) and about(got[1], skin[index].y, 0.05);
                    checked += 1;
                }
            }
        }
    }
    assert checked >= 9 * 8;
    # Told nothing, or told for another grid, its tops are laid as any brush's.
    stale = patch_brushes(made[2], 3, 3, 2, 8.0, "tile", [], [0.0, 0.0]);
    assert about(stale[0][0].mapping.s_scale, plain[0][0].mapping.s_scale);
}

test "a patch of a scene keeps its places through bending, and loses them when its grid changes" {
    scene = Scene(game="passion", name="studio:test");
    scene.world();
    made = patch_points("sheet", Vec3(z=64.0), Vec3(x=128.0, y=128.0, z=64.0));
    patch = scene.make_patch(made[2], made[0], made[1], "tile");
    assert patch is not None and scene.patch_places(patch) == [];
    places = places_even(3, 3, 256.0, 256.0);
    assert scene.set_patch_places(patch, places) and "_st" in patch.fields and scene.patch_places(patch) == places;
    assert not scene.set_patch_places(patch, places) and not scene.set_patch_places(patch, [1.0, 2.0]);
    # Its brushes say so themselves: nothing at its first corner, the whole material at its last.
    lies = scene.patch_lies(patch);
    assert len(lies) == 4 and about(lies[0], 0.0, 0.01) and about(lies[1], 0.0, 0.01);
    assert about(lies[2], 256.0, 0.01) and about(lies[3], 256.0, 0.01);
    # One corner's place moved: the far corner, in the same plane, still says its own.
    nudged = list(places);
    nudged[0] = -32.0;
    nudged[1] = -16.0;
    assert scene.set_patch_places(patch, nudged, "Nudge");
    lies = scene.patch_lies(patch);
    assert about(lies[0], -32.0, 0.01) and about(lies[1], -16.0, 0.01) and about(lies[2], 256.0, 0.01) and about(lies[3], 256.0, 0.01);
    assert scene.undo() == "Nudge" and scene.patch_places(patch) == places;
    # Bent: the places go with the control points, so the middle of the sheet
    # (a quarter of the way up to the raised point) keeps its place.
    control = scene.patch_control(patch);
    assert control is not None;
    bent = [Vec3(x=point.x, y=point.y, z=point.z) for point in control];
    bent[4] = Vec3(x=bent[4].x, y=bent[4].y, z=bent[4].z + 32.0);
    assert scene.set_patch(patch, bent) and scene.patch_places(patch) == places;
    found = False;
    for solid in scene.solids_of(patch) {
        for side in solid.sides {
            if abs(side.plane.side(Vec3(x=64.0, y=64.0, z=72.0))) < 0.05 and side.plane.normal.z > 0.5 {
                got = mapping_place(side.mapping, Vec3(x=64.0, y=64.0, z=72.0));
                assert about(got[0], 128.0, 0.5) and about(got[1], 128.0, 0.5);
                found = True;
            }
        }
    }
    assert found;
    assert scene.undo() == "Bend" and scene.undo() == "Lay material" and "_st" not in patch.fields;
    assert scene.redo() == "Lay material" and scene.patch_places(patch) == places;
    # One more curve: nine places do not fit fifteen control points, and are let go.
    assert scene.grow_patch(patch, "u") and "_st" not in patch.fields and scene.patch_places(patch) == [];
    assert scene.undo() == "Grow patch" and scene.patch_places(patch) == places;
    assert scene.set_patch_places(patch, []) and "_st" not in patch.fields;
    # Forgotten, its faces lie plainly again: a unit of the world a texel, from the world's own middle.
    plain = scene.patch_lies(patch);
    assert len(plain) == 4 and about(plain[0], 0.0, 0.01) and about(abs(plain[1]), 0.0, 0.01);
    assert about(plain[2], 128.0, 0.01) and about(abs(plain[3]), 128.0, 0.01);
}
