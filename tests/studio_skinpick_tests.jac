import from editor.model.skinpick { skin_rect, skin_place, place_nearest, triangle_at }

test "a picture is drawn as large as fits, in the middle of its box" {
    assert skin_rect(168, 168, 64, 64) == [4, 4, 160, 160];
    assert skin_rect(168, 168, 128, 64) == [4, 44, 160, 80];
    assert skin_rect(168, 88, 64, 64) == [44, 4, 80, 80];
    assert skin_rect(8, 8, 64, 64) == [0, 0, 0, 0] and skin_rect(168, 168, 0, 64) == [0, 0, 0, 0];
}

test "a pixel on the picture is a place on the skin, and off it is none" {
    rect = [4, 44, 160, 80];
    assert skin_place(rect, 4, 44) == [0.0, 0.0] and skin_place(rect, 84, 84) == [0.5, 0.5];
    assert skin_place(rect, 3, 50) == [] and skin_place(rect, 84, 130) == [];
}

test "the nearest point's place is found within reach, and a triangle by what it holds" {
    uvs = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0];
    assert place_nearest(uvs, 0.95, 0.97, 0.1) == 2 and place_nearest(uvs, 0.5, 0.5, 0.1) == -1 and place_nearest([], 0.0, 0.0, 1.0) == -1;
    corners = [0, 1, 2, 0, 2, 3];
    assert triangle_at(corners, uvs, 0.8, 0.2) == 0 and triangle_at(corners, uvs, 0.2, 0.8) == 1;
    assert triangle_at(corners, uvs, 1.5, 0.5) == -1 and triangle_at(corners, [0.0, 0.0], 0.1, 0.1) == -1;
}
