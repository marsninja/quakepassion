import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { box_sides, brush_windings, Side, Plane3, Mapping }
import from editor.geometry.adjoin { outlines_adjoin, faces_beside, sides_used }

"""A level rectangle at a height: its corners in order."""
def tile(x0: float, y0: float, x1: float, y1: float, z: float = 0.0) -> list[Vec3] {
    return [Vec3(x=x0, y=y0, z=z), Vec3(x=x1, y=y0, z=z), Vec3(x=x1, y=y1, z=z), Vec3(x=x0, y=y1, z=z)];
}

test "outlines in one plane adjoin along an edge or over one another, not at a corner" {
    first = tile(0.0, 0.0, 64.0, 64.0);
    assert outlines_adjoin(first, tile(64.0, 0.0, 128.0, 64.0)) and outlines_adjoin(tile(64.0, 0.0, 128.0, 64.0), first);
    # Half an edge in common is enough; the other way round the room it is the same.
    assert outlines_adjoin(first, tile(64.0, 32.0, 128.0, 96.0)) and outlines_adjoin(first, tile(-64.0, 16.0, 0.0, 48.0));
    # A corner in common is not an edge; apart is apart.
    assert not outlines_adjoin(first, tile(64.0, 64.0, 128.0, 128.0)) and not outlines_adjoin(first, tile(80.0, 0.0, 128.0, 64.0));
    # One over part of the other, and one wholly inside the other.
    assert outlines_adjoin(first, tile(32.0, 32.0, 96.0, 96.0)) and outlines_adjoin(first, tile(16.0, 16.0, 48.0, 48.0));
    assert outlines_adjoin(tile(16.0, 16.0, 48.0, 48.0), first);
    assert not outlines_adjoin(first, []) and not outlines_adjoin([Vec3(), Vec3(x=1.0)], first);
}

test "the faces of a box beside one of them are the four round it" {
    outlines = brush_windings(box_sides(Vec3(), Vec3(x=64.0, y=32.0, z=16.0), "wall"));
    assert len(outlines) == 6 and sides_used(outlines) == [0, 1, 2, 3, 4, 5];
    for side in range(6) {
        beside = faces_beside(outlines, side);
        # Every face but itself and the one across from it.
        assert len(beside) == 4 and side not in beside , str(side) + " " + str(beside);
    }
    assert faces_beside(outlines, 9) == [] and faces_beside(outlines, -1) == [];
}

test "a side that cuts nothing off a brush makes no face" {
    sides = box_sides(Vec3(), Vec3(x=64.0, y=32.0, z=16.0), "wall");
    # A seventh side far outside the box, facing the way one of its own does.
    spare = Side(plane=Plane3(normal=Vec3(x=1.0), dist=500.0), material="wall", mapping=sides[0].mapping);
    outlines = brush_windings(sides + [spare]);
    assert len(outlines) == 7 and sides_used(outlines) == [0, 1, 2, 3, 4, 5] and faces_beside(outlines, 6) == [];
    assert sides_used([]) == [];
}
