"""QP_FRAME_LOG=<file.csv>: one row per frame of play, what each frame spent and
where, written when the game exits. QP_FRAME_SECONDS=<n> exits after that long,
for runs nobody is at the keyboard for. scripts/frame_report.py reads the file."""


glob FRAME_COLUMNS: list[str] = [
    "at", "frame", "ticks", "dt", "before", "sim", "visible", "portal", "world", "models", "effects", "weapon", "hud", "present"
];


obj FrameLog {
    has path: str = "",
        limit: float = 0.0,
        first: float = 0.0,
        last: float = 0.0,
        rows: list[float] = [];

    """Note a frame that ended at `now`, in order FRAME_COLUMNS; answers whether
    the run has gone on long enough."""
    def note(now: float, ticks: int, dt: float, times: list[float]) -> bool {
        if self.first == 0.0 {
            self.first = now;
            self.last = now;
            return False;
        }
        self.rows.append(now - self.first);
        self.rows.append((now - self.last) * 1000.0);
        self.rows.append(float(ticks));
        self.rows.append(dt * 1000.0);
        self.rows.extend(times);
        self.last = now;
        return self.limit > 0.0 and now - self.first >= self.limit;
    }

    def save {
        width = len(FRAME_COLUMNS);
        with open(self.path, "w") as out {
            out.write(",".join(FRAME_COLUMNS) + "\n");
            for start in range(0, len(self.rows), width) {
                out.write(",".join([str(round(value, 3)) for value in self.rows[start:start + width]]) + "\n");
            }
        }
    }
}
