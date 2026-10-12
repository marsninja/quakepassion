import from editor.model.skinpick { place_frame, frame_fit, place_pixel, pixel_place, place_at_pixel }

test "the frame holds the picture and every place, with a rim" {
    frame = place_frame([0.0, 0.0, 128.0, 64.0], 64.0, 64.0);
    assert frame == [-8.0, -8.0, 136.0, 72.0];
    assert place_frame([], 32.0, 32.0) == [-2.0, -2.0, 34.0, 34.0];
}

test "places and pixels go each to the other" {
    frame = [0.0, 0.0, 100.0, 50.0];
    fit = frame_fit(frame, 200, 200);
    assert fit == [0.0, 50.0, 2.0];
    assert place_pixel(frame, fit, 50.0, 25.0) == [100, 100];
    assert pixel_place(frame, fit, 100, 100) == [50.0, 25.0];
    places = [0.0, 0.0, 50.0, 25.0, 100.0, 50.0];
    assert place_at_pixel(frame, fit, places, 102, 99) == 1 and place_at_pixel(frame, fit, places, 150, 150) == -1;
}
