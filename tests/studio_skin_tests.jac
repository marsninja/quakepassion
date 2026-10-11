import from engine.math.vec3 { Vec3 }
import from editor.model.mesh { Mesh }
import from editor.model.skin {
    Skin,
    places_box,
    places_moved,
    places_scaled,
    places_turned,
    places_flipped,
    places_projected,
    skin_filled,
    skin_dab,
    place_under,
    skin_tga,
    tga_skin
}

def about(a: float, b: float, slack: float = 0.001) -> bool {
    return abs(a - b) < slack;
}

"""A square sheet 64 a side lying flat at z = 0, facing up: two triangles,
its skin laid straight on it."""
def sheet -> Mesh {
    return Mesh(
        points=[Vec3(), Vec3(x=64.0), Vec3(x=64.0, y=64.0), Vec3(y=64.0)],
        corners=[0, 1, 2, 0, 2, 3],
        uvs=[0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0]
    );
}

test "places on a skin are moved, stretched, turned and flipped about their own box" {
    uvs = [0.25, 0.25, 0.75, 0.25, 0.75, 0.5, 0.25, 0.5];
    assert places_box(uvs, []) == [0.25, 0.25, 0.75, 0.5] and places_box(uvs, [0, 1]) == [0.25, 0.25, 0.75, 0.25];
    assert places_box([], []) == [0.0, 0.0, 0.0, 0.0];
    moved = places_moved(uvs, [0, 3], 0.1, -0.05);
    assert about(moved[0], 0.35) and about(moved[1], 0.2) and moved[2] == 0.75 and about(moved[6], 0.35);
    # Stretched to half about the middle of the box (0.5, 0.375).
    small = places_scaled(uvs, [], 0.5, 0.5);
    assert about(small[0], 0.375) and about(small[1], 0.3125) and about(small[4], 0.625) and about(small[5], 0.4375);
    # A quarter turn about the middle carries the first corner to where the second's line was.
    turned = places_turned(uvs, [], 90.0);
    assert about(turned[0], 0.5 + 0.125) and about(turned[1], 0.375 - 0.25);
    box = places_box(turned, []);
    assert about(box[2] - box[0], 0.25) and about(box[3] - box[1], 0.5);
    across = places_flipped(uvs, [], "u");
    assert about(across[0], 0.75) and about(across[2], 0.25) and across[1] == 0.25;
    down = places_flipped(uvs, [], "v");
    assert about(down[1], 0.5) and about(down[5], 0.25) and down[0] == 0.25;
    # What was given is left alone.
    assert uvs[0] == 0.25 and uvs[5] == 0.5;
}

test "points are laid flat on the skin by looking along an axis" {
    wall = Mesh(points=[Vec3(), Vec3(x=128.0), Vec3(x=128.0, z=64.0), Vec3(z=64.0)], corners=[0, 1, 2, 0, 2, 3]);
    # Along y: across is x, up is z, and up the wall is up the picture.
    laid = places_projected(wall, [], 1);
    assert laid == [0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0];
    # Into a quarter of the skin.
    corner = places_projected(wall, [], 1, [0.5, 0.5, 1.0, 1.0]);
    assert about(corner[0], 0.5) and about(corner[1], 1.0) and about(corner[4], 1.0) and about(corner[5], 0.5);
    # Only the picked points are laid; the rest keep their places.
    half = places_projected(Mesh(points=wall.points, corners=wall.corners, uvs=[0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3]), [2, 3], 1);
    assert half[0] == 0.3 and half[1] == 0.3 and about(half[4], 1.0) and about(half[6], 0.0);
    flat = places_projected(sheet(), [], 2);
    assert about(flat[0], 0.0) and about(flat[1], 1.0) and about(flat[4], 1.0) and about(flat[5], 0.0);
}

test "a skin is filled, dabbed solid and soft, and kept as a TGA" {
    skin = skin_filled(32, 16, [10, 20, 30]);
    assert skin.at(0, 0) == [10, 20, 30, 255] and skin.at(31, 15) == [10, 20, 30, 255] and skin.at(32, 0) == [0, 0, 0, 0];
    touched = skin_dab(skin, 0.5, 0.5, 4.0, [200, 0, 0]);
    assert touched > 40 and touched < 60 and skin.at(16, 8) == [200, 0, 0, 255] and skin.at(0, 0) == [10, 20, 30, 255];
    # An airbrush: all of the colour at its middle, less toward its edge, none beyond.
    soft = skin_filled(32, 32, [0, 0, 0]);
    skin_dab(soft, 0.5, 0.5, 8.0, [255, 255, 255], True);
    middle = soft.at(16, 16)[0];
    rim = soft.at(22, 16)[0];
    assert middle > 200 and rim > 0 and rim < middle and soft.at(26, 16)[0] == 0;
    # Half strength lays half.
    faint = skin_filled(8, 8, [0, 0, 0]);
    skin_dab(faint, 0.5, 0.5, 2.0, [200, 100, 0], False, 0.5);
    assert faint.at(4, 4) == [100, 50, 0, 255];
    data = skin_tga(skin);
    assert len(data) == 18 + 32 * 16 * 4 and data[2] == 2 and data[16] == 32;
    back = tga_skin(data);
    assert back is not None and back.width == 32 and back.height == 16 and back.at(16, 8) == [200, 0, 0, 255] and back.at(0, 0) == [10, 20, 30, 255];
    assert tga_skin(b"short") is None;
}

test "painting through the model lands where the line of sight meets its skin" {
    mesh = sheet();
    # Straight down onto the sheet a quarter of the way along x and three quarters along y.
    place = place_under(mesh, Vec3(x=16.0, y=48.0, z=100.0), Vec3(z=-1.0));
    assert place is not None and about(place[0], 0.25, 0.01) and about(place[1], 0.25, 0.01);
    middle = place_under(mesh, Vec3(x=32.0, y=32.0, z=100.0), Vec3(z=-1.0));
    assert middle is not None and about(middle[0], 0.5, 0.01) and about(middle[1], 0.5, 0.01);
    # From underneath it faces away; off its edge there is nothing; with no skin laid there is no place.
    assert place_under(mesh, Vec3(x=16.0, y=48.0, z=-100.0), Vec3(z=1.0)) is None;
    assert place_under(mesh, Vec3(x=200.0, y=48.0, z=100.0), Vec3(z=-1.0)) is None;
    assert place_under(Mesh(points=mesh.points, corners=mesh.corners), Vec3(x=16.0, y=48.0, z=100.0), Vec3(z=-1.0)) is None;
    skin = skin_filled(64, 64, [0, 0, 0]);
    assert skin_dab(skin, place[0], place[1], 3.0, [0, 255, 0]) > 0 and skin.at(16, 16) == [0, 255, 0, 255] and skin.at(48, 48)[1] == 0;
}
