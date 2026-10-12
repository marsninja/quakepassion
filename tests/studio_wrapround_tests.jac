import from engine.math.vec3 { Vec3 }
import from editor.document.scene { Scene, Solid }
import from editor.geometry.brush { box_sides, brush_windings, Side, Mapping }
import from editor.geometry.adjoin { faces_beside }

def about(a: float, b: float, slack: float = 0.01) -> bool {
    return abs(a - b) < slack;
}

"""Whether two faces of a brush have the same texel at both ends of the edge they share."""
def meet(solid: Solid, first: int, second: int) -> bool {
    outlines = solid.outlines();
    shared = [corner for corner in outlines[first] if len([other for other in outlines[second] if other.sub(corner).length() < 0.01]) > 0];
    if len(shared) != 2 {
        return False;
    }
    for corner in shared {
        one = solid.sides[first].mapping.texel(corner);
        two = solid.sides[second].mapping.texel(corner);
        if not about(one[0], two[0]) or not about(one[1], two[1]) {
            return False;
        }
    }
    return True;
}

test "a material goes round a brush from one face, each face taking it from the one beside it" {
    scene = Scene(game="passion", name="studio:test");
    world = scene.world();
    sides = box_sides(Vec3(), Vec3(x=96.0, y=64.0, z=128.0), "plain");
    # One wall in another material, slid and stretched.
    walls = [index for (index, side) in enumerate(sides) if abs(side.plane.normal.z) < 0.5];
    assert len(walls) == 4;
    start = walls[0];
    lay = Mapping(
        s_axis=sides[start].mapping.s_axis, t_axis=sides[start].mapping.t_axis, s_shift=5.0, t_shift=-3.0, s_scale=0.5, t_scale=2.0
    );
    sides[start] = Side(plane=sides[start].plane, material="brick", mapping=lay);
    pillar = scene.add_solid(world, sides);
    # Nothing picked: nothing to go round.
    assert scene.wrap_round(pillar, start) == 0;
    for wall in walls {
        scene.select_face(pillar, wall, True);
    }
    assert scene.wrap_round(pillar, start) == 3;
    assert [pillar.sides[wall].material for wall in walls] == ["brick", "brick", "brick", "brick"];
    assert len([side for side in pillar.sides if side.material == "plain"]) == 2;
    # The two walls beside the first meet it without a break, and the far wall meets the one it
    # was reached through; the stretch is the first wall's on every one.
    beside = [wall for wall in faces_beside(pillar.outlines(), start) if wall in walls];
    far = [wall for wall in walls if wall != start and wall not in beside][0];
    assert len(beside) == 2 and meet(pillar, start, beside[0]) and meet(pillar, start, beside[1]);
    assert meet(pillar, beside[0], far) or meet(pillar, beside[1], far);
    for wall in walls {
        assert about(pillar.sides[wall].mapping.s_scale, 0.5) and about(pillar.sides[wall].mapping.t_scale, 2.0);
    }
    # Done already, it is no edit; undone, the walls are plain again.
    assert scene.wrap_round(pillar, start) == 0;
    assert scene.undo() == "Wrap material round" and pillar.sides[far].material == "plain" and pillar.sides[start].material == "brick";
    # Only the picked faces take it: with one wall beside the first picked, one does.
    scene.clear_faces();
    scene.select_face(pillar, beside[0], True);
    assert scene.wrap_round(pillar, start) == 1 and pillar.sides[beside[1]].material == "plain";
    # A face that is not there is nothing to start from.
    assert scene.wrap_round(pillar, 9) == 0 and scene.wrap_round(pillar, -1) == 0;
}
