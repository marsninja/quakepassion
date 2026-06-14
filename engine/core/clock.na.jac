"""Fixed-timestep accumulator. Simulation ticks at a fixed rate (Quake's
classic 20Hz) regardless of render framerate; rendering runs as fast as
vsync allows. advance() returns how many ticks the caller owes this frame."""


obj Clock {
    has tick_rate: float = 0.05,
        max_ticks_per_frame: int = 5,
        accumulator: float = 0.0;

    def advance(frame_dt: float) -> int {
        self.accumulator += frame_dt;
        ticks = 0;
        while self.accumulator >= self.tick_rate and ticks < self.max_ticks_per_frame {
            self.accumulator -= self.tick_rate;
            ticks += 1;
        }
        # spiral-of-death guard: if we are still behind after the cap, drop the debt
        if self.accumulator >= self.tick_rate {
            self.accumulator = 0.0;
        }
        return ticks;
    }

    def alpha() -> float {
        return self.accumulator / self.tick_rate;
    }
}
