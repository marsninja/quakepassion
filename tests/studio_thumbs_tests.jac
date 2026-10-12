import from engine.math.vec3 { Vec3 }
import from editor.geometry.brush { box_sides }
import from editor.document.thumbs { sketch_edges, seen_from_corner, line_texels, sketch }

test "a line of texels runs from one end to the other without a gap" {
    assert line_texels(0, 0, 3, 0) == [(0, 0), (1, 0), (2, 0), (3, 0)];
    assert line_texels(2, 5, 2, 3) == [(2, 5), (2, 4), (2, 3)];
    slope = line_texels(0, 0, 6, 3);
    assert slope[0] == (0, 0) and slope[-1] == (6, 3) and len(slope) == 7;
    for at in range(1, len(slope)) {
        assert abs(slope[at][0] - slope[at - 1][0]) <= 1 and abs(slope[at][1] - slope[at - 1][1]) <= 1;
    }
    assert line_texels(4, 4, 4, 4) == [(4, 4)];
}

test "seen from above one corner, height goes up the picture and the floor spreads to both sides" {
    assert seen_from_corner(Vec3()) == (0.0, 0.0);
    assert seen_from_corner(Vec3(z=10.0))[1] < 0.0 and seen_from_corner(Vec3(z=10.0))[0] == 0.0;
    assert seen_from_corner(Vec3(x=10.0))[0] > 0.0 and seen_from_corner(Vec3(y=10.0))[0] < 0.0;
    assert seen_from_corner(Vec3(x=10.0))[1] == seen_from_corner(Vec3(y=10.0))[1];
}

"""How many texels of a picture are drawn."""
def drawn(picture: bytes) -> int {
    return len([at for at in range(3, len(picture), 4) if int(picture[at]) == 255]);
}

test "a box is sketched as its edges, fitted inside the picture" {
    edges = sketch_edges([box_sides(Vec3(), Vec3(x=64.0, y=64.0, z=64.0), "blockout")]);
    # Six sides of four edges each.
    assert len(edges) == 24;
    picture = sketch(edges, 64, 48, 255, 122, 24);
    assert len(picture) == 64 * 48 * 4 and drawn(picture) > 60;
    # Nothing on the margin, and what is drawn is the colour asked for.
    for x in range(64) {
        assert int(picture[(0 * 64 + x) * 4 + 3]) == 0 and int(picture[(47 * 64 + x) * 4 + 3]) == 0;
    }
    first = [at for at in range(0, len(picture), 4) if int(picture[at + 3]) == 255][0];
    assert int(picture[first]) == 255 and int(picture[first + 1]) == 122 and int(picture[first + 2]) == 24;
    # The same from left to right: a box seen from its corner.
    left = 0;
    for y in range(48) {
        for x in range(32) {
            if int(picture[(y * 64 + x) * 4 + 3]) == 255 {
                left += 1;
            }
        }
    }
    # (The two upright edges down its middle fall in one half or the other.)
    assert left > 20 and abs(drawn(picture) - 2 * left) <= 2 * 48;
}

test "nothing to draw, or no room, gives a clear picture" {
    assert drawn(sketch([], 64, 48, 255, 255, 255)) == 0 and len(sketch([], 64, 48, 255, 255, 255)) == 64 * 48 * 4;
    assert sketch([(Vec3(), Vec3(x=1.0))], 4, 4, 255, 255, 255) == bytes(64);
}
