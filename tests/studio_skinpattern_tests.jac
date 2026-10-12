import from editor.model.pattern { SKIN_PATTERNS, pattern_covers }

def covered(pattern: str, grain: int, wide: int, tall: int) -> int {
    count = 0;
    for y in range(tall) {
        for x in range(wide) {
            if pattern_covers(pattern, x, y, grain) {
                count += 1;
            }
        }
    }
    return count;
}

test "a pattern covers some texels and leaves others" {
    assert covered("solid", 4, 16, 16) == 256 and covered("nothing known", 4, 16, 16) == 256;
    # Half of the picture, by squares, by rows and by columns.
    assert covered("checks", 4, 16, 16) == 128 and covered("stripes", 4, 16, 16) == 128 and covered("bars", 4, 16, 16) == 128;
    assert pattern_covers("checks", 0, 0, 4) and not pattern_covers("checks", 4, 0, 4) and pattern_covers("checks", 4, 4, 4);
    assert pattern_covers("stripes", 9, 0, 4) and not pattern_covers("stripes", 9, 4, 4);
    assert pattern_covers("bars", 0, 9, 4) and not pattern_covers("bars", 4, 9, 4);
    # A dot in the middle of each square of twice the grain: its middle is covered, its corners are not.
    assert pattern_covers("dots", 4, 4, 4) and not pattern_covers("dots", 0, 0, 4) and pattern_covers("dots", 12, 4, 4);
    dotted = covered("dots", 4, 16, 16);
    assert dotted > 32 and dotted < 96;
    # A grain of nothing is a grain of one.
    assert covered("checks", 0, 4, 4) == 8;
    assert "solid" in SKIN_PATTERNS and "dots" in SKIN_PATTERNS;
}
