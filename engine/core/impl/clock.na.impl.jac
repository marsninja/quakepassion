"""Implementations for the Clock object. Declarations live in clock.na.jac."""

impl Clock.advance(frame_dt: float) -> int {
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

impl Clock.alpha() -> float {
    return self.accumulator / self.tick_rate;
}
