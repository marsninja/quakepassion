"""What the cinematic player (engine/core/cinematic.jac) plays.

A film decoder hands the player one picture at a time, with the sound that
goes with it, and says how its game's client ran it: how many pictures a
second, whether the screen trails the reader by a picture, when a key may
end it and whether its last picture stays up. Quake II's .cin
(formats/q2/cin.jac) and Quake III's RoQ (formats/q3/roq.jac) are the two
decoders."""

"""One picture, rows from the top, and the sound read with it. With a
768-byte `palette` the pixels are indices into it (the palette is the
film's, in force from the moment it is read); without one they are RGBA.
The sound is in the layout S_RawSamples is handed: 8-bit unsigned or 16-bit
signed little-endian samples, mono or interleaved stereo."""
obj FilmPicture {
    has pixels: bytes = b"",
        palette: bytes = b"",
        samples: bytes = b"",
        sound_rate: int = 0,
        sound_width: int = 0,
        sound_channels: int = 0;
}

obj Film {
    has width: int = 0,
        height: int = 0,
        # Pictures a second on the real clock.
        frame_rate: int = 0,
        # Pictures read so far (Q2 cl.cinematicframe, Q3 numQuads).
        frame: int = 0,
        # Q2 SCR_RunCinematic shows each picture one read late and slows the
        # film when a frame runs long; Q3 CIN_RunCinematic shows what it
        # reads and reads on until it has caught the clock up.
        trails: bool = False,
        # Seconds before a key may end the film (Q2 CL_SendCmd waits a second;
        # Q3 CL_KeyEvent takes any key press).
        skip_after: float = 0.0,
        # Q3 turns every key into the one that stops a film, Escape included;
        # Q2's Escape opens the menu over it.
        escape_skips: bool = False,
        # Q3 CIN_hold: the last picture stays until a key (end.RoQ).
        holds: bool = False;

    """The next picture, or None once the film has run out. Abstract, so a
    call through a `Film` reaches the decoder's own module."""
    def next_picture() -> FilmPicture | None abst;
}
