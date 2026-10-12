import from engine.math.vec3 { Vec3 }
import from editor.geometry.patchpreview { lattice_edges, patch_takes, render_rows, collide_rows }

"""An arch three points across and three along: up over a crown and down."""
def arch -> list[Vec3] {
    points: list[Vec3] = [];
    for y in [0.0, 64.0, 128.0] {
        for (x, z) in [(0.0, 0.0), (64.0, 128.0), (128.0, 0.0)] {
            points.append(Vec3(x=x, y=y, z=z));
        }
    }
    return points;
}

test "a grid of points has its edges along its rows and down its columns" {
    rows = [[Vec3(), Vec3(x=1.0), Vec3(x=2.0)], [Vec3(y=1.0), Vec3(x=1.0, y=1.0), Vec3(x=2.0, y=1.0)]];
    assert len(lattice_edges(rows)) == 2 * 2 + 3;
    assert lattice_edges([]) == [];
}

test "the games' code takes odd grids of three or more" {
    assert patch_takes(3, 3, arch()) and not patch_takes(4, 3, arch()) and not patch_takes(3, 3, arch()[:8]);
}

test "the renderer and the collision both bend a curved patch into more points than it has" {
    drawn = render_rows(3, 3, arch());
    # The flat way across needs only its two edges; the curved way, many more points.
    assert len(drawn) == 2 and len(drawn[0]) > 3;
    # Finer subdivision: at least as many points along the curve.
    finer = render_rows(3, 3, arch(), 1.0);
    assert len(finer[0]) >= len(drawn[0]);
    # The curve's crown is half the control point's height, on both.
    crown = max([point.z for point in drawn[0]]);
    assert abs(crown - 64.0) < 1.0;
    hit = collide_rows(3, 3, arch());
    assert len(hit) >= 2 and max([len(column) for column in hit]) > 3;
    assert render_rows(4, 3, arch()) == [] and collide_rows(3, 2, arch()[:6]) == [];
}
