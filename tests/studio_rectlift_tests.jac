import from engine.math.vec3 { Vec3 }
import from editor.geometry.terrain { flat_heights, lifted, falloff_of }

test "a falloff is so many units, or a share of the rectangle's shorter side" {
    assert falloff_of("64", 256.0, 128.0) == 64.0 and falloff_of("0", 256.0, 128.0) == 0.0;
    assert falloff_of("50%", 256.0, 128.0) == 64.0 and falloff_of("50%", 128.0, 256.0) == 64.0;
    # Drawn either way round, it is the same rectangle.
    assert falloff_of("25%", -256.0, -128.0) == 32.0 and falloff_of("100%", 64.0, 64.0) == 64.0;
    assert falloff_of("", 256.0, 128.0) == 0.0 and falloff_of("wide", 256.0, 128.0) == 0.0 and falloff_of("-5", 1.0, 1.0) == 0.0;
    assert falloff_of("%", 256.0, 128.0) == 0.0 and falloff_of(" 12.5 ", 1.0, 1.0) == 12.5;
}

test "a rectangle lifted with a falloff by share lifts its neighbours by less" {
    # Eight cells of 32 each way: corners at 0, 32 ... 256.
    flat = flat_heights(8, 8, 16.0);
    low = Vec3(x=96.0, y=96.0);
    high = Vec3(x=160.0, y=160.0);
    # Half of the rectangle's 64 is 32 units: the ring of corners 32 away is at the edge of it, and stays.
    fades = falloff_of("50%", high.x - low.x, high.y - low.y);
    assert fades == 32.0;
    raised = lifted(flat, Vec3(), 8, 8, 32.0, low, high, 40.0, fades);
    def at(heights: list[float], col: int, row: int) -> float {
        return heights[row * 9 + col];
    }
    assert at(raised, 3, 3) == 56.0 and at(raised, 5, 5) == 56.0 and at(raised, 4, 4) == 56.0;
    assert at(raised, 2, 3) == 16.0 and at(raised, 6, 6) == 16.0 and at(raised, 0, 0) == 16.0;
    # All of it, 64 units: the corners 32 away are lifted by half.
    wider = lifted(flat, Vec3(), 8, 8, 32.0, low, high, 40.0, falloff_of("100%", 64.0, 64.0));
    assert at(wider, 4, 4) == 56.0 and at(wider, 2, 3) == 36.0 and at(wider, 3, 6) == 36.0 and at(wider, 1, 3) == 16.0;
    # Lowered the same way; nothing goes below the ground.
    sunk = lifted(wider, Vec3(), 8, 8, 32.0, low, high, -100.0, 64.0);
    assert at(sunk, 4, 4) == 0.0 and at(sunk, 2, 3) == 0.0 and at(sunk, 1, 3) == 16.0;
}
