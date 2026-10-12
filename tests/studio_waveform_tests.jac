import from editor.document.thumbs { waveform }

def lit(picture: bytes, width: int, x: int, y: int) -> bool {
    return picture[(y * width + x) * 4 + 3] == 255;
}

test "a sound's shape is a line from its quietest to its loudest in each column" {
    # Eight-bit: silence in the first half, full swings in the second.
    samples = bytes([128] * 50 + [0, 255] * 25);
    picture = waveform(samples, 1, 1, 10, 21, 255, 255, 255);
    assert len(picture) == 10 * 21 * 4;
    # Silence: only the middle row.
    assert lit(picture, 10, 0, 10) and not lit(picture, 10, 0, 2) and not lit(picture, 10, 0, 18);
    # Swings: top to bottom.
    assert lit(picture, 10, 9, 2) and lit(picture, 10, 9, 19) and not lit(picture, 10, 9, 0);
    # Sixteen-bit, stereo: the first channel is drawn.
    loud = bytes([0xff, 0x7f, 0, 0] * 20);
    assert lit(waveform(loud, 2, 2, 4, 21, 1, 2, 3), 4, 0, 2);
    assert waveform(b"", 1, 1, 4, 4, 1, 1, 1) == bytes(64) and waveform(samples, 3, 1, 4, 4, 1, 1, 1) == bytes(64);
}
