"""Fixed-timestep accumulator. Simulation ticks at a fixed rate (Quake's
classic 20Hz) regardless of render framerate; rendering runs as fast as
vsync allows. advance() returns how many ticks the caller owes this frame.

Method bodies live in impl/clock.na.impl.jac."""


obj Clock {
    has tick_rate: float = 0.05,
        max_ticks_per_frame: int = 5,
        accumulator: float = 0.0;

    def advance(frame_dt: float) -> int;
    def alpha() -> float;
}
