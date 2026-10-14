"""The player bot's trace: what it decided and why, as JSON lines, for
reading a run back (scripts/autoplay_report.jac).

- Events: a level begun, an objective chosen (with the choices it had and
  what each would cost), an objective done or given up (and why), a route
  planned or not found (and why), a change of mode, a death (what killed
  it), a block.
- A black box: the last ten seconds at ten samples a second (where it was,
  how fast it went, what it asked for, what the travel said, its health
  and its enemy), written out when it dies, is blocked or gives up.

QP_AUTOPLAY_TRACE names the file; without it nothing is written."""
import from ..math.vec3 { Vec3 }

"""A string as a JSON string."""
def trace_text(value: str) -> str {
    out = value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ");
    return "\"" + out + "\"";
}

"""A number as JSON, rounded to `places`."""
def trace_number(value: float, places: int = 1) -> str {
    return str(round(value, places));
}

"""A point as a JSON list of whole units."""
def trace_point(point: Vec3) -> str {
    return "[" + str(int(point.x)) + ", " + str(int(point.y)) + ", " + str(int(point.z)) + "]";
}

obj BotTrace {
    has path: str = "",
        samples: list[str] = [],
        sample_wait: float = 0.0;

    def on -> bool {
        return self.path != "";
    }

    """Write one event: `kind` at `clock`, with `fields` already as JSON
    values (trace_text, trace_number or a JSON list)."""
    def event(kind: str, clock: float, fields: dict[str, str]) {
        if not self.path {
            return;
        }
        parts = ["\"kind\": " + trace_text(kind), "\"t\": " + trace_number(clock)];
        for key in fields.keys() {
            parts.append(trace_text(key) + ": " + fields[key]);
        }
        try {
            with open(self.path, "a") as out {
                out.write("{" + ", ".join(parts) + "}\n");
            }
        } except Exception as error {
            print("AUTOPLAY trace not written:", error);
            self.path = "";
        }
    }

    """Keep one sample of the black box (a JSON object), the last hundred."""
    def sample(clock: float, dt: float, line: str) {
        if not self.path {
            return;
        }
        self.sample_wait -= dt;
        if self.sample_wait > 0.0 {
            return;
        }
        self.sample_wait = 0.1;
        self.samples.append(line);
        if len(self.samples) > 100 {
            self.samples = self.samples[len(self.samples) - 100:];
        }
    }

    """Write the black box out, saying why."""
    def dump(reason: str, clock: float) {
        if not self.path or not self.samples {
            return;
        }
        self.event("blackbox", clock, {"reason": trace_text(reason), "samples": "[" + ", ".join(self.samples) + "]"});
    }
}
