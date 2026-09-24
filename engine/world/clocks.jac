"""Q2 digital clocks (g_misc.c). A func_clock counts up or down each second and
writes its time into a target_string, which spreads the text over its team of
target_character brushes by switching each one's texture frame: digits 0-9,
'-' 10, ':' 11, anything else 12. When a timer runs out the clock fires its
pathtarget, and restarts if flagged MULTI_USE."""
import from .world { World }
import from .signals { Signal, HasSignal, Fire }
import from ..formats.bsp { Bsp }

node Readout {
    has message: str = "";
}

node Glyph {
    has position: int,
        faces: list[int] = [];
}

edge Spells: Readout --> Glyph {}

node Clock {
    has counting_up: bool = False,
        counting_down: bool = False,
        style: int = 0,
        count: int = 0,
        value: int = 0,
        limit: int = 0,
        running: bool = False,
        multi_use: bool = False,
        start_off: bool = False,
        clock: float = 0.0,
        activation: Signal = Signal();
}

edge Shows: Clock --> Readout {}
edge HasClock: World --> Clock {}

"""func_clock_format_countdown: "%2i", "%2i:%02i" or "%2i:%02i:%02i"."""
def clock_text(style: int, value: int) -> str {
    if style == 1 {
        return right_align(value // 60) + ":" + zero_pad(value % 60);
    }
    if style == 2 {
        return right_align(value // 3600) + ":" + zero_pad((value % 3600) // 60) + ":" + zero_pad(value % 60);
    }
    return right_align(value);
}

def right_align(value: int) -> str {
    text = str(value);
    return (" " + text) if len(text) < 2 else text;
}

def zero_pad(value: int) -> str {
    text = str(value);
    return ("0" + text) if len(text) < 2 else text;
}

"""target_string_use: each glyph shows the message character at its count."""
def glyph_frame(message: str, position: int) -> int {
    if position < 1 or position > len(message) {
        return 12;
    }
    c = message[position - 1];
    if c >= "0" and c <= "9" {
        return ord(c) - 48;
    }
    if c == "-" {
        return 10;
    }
    if c == ":" {
        return 11;
    }
    return 12;
}

walker ClockTick {
    has bsp: Bsp,
        dt: float;

    can begin with World entry {
        if self.dt > 0.0 {
            visit [here->:HasClock:->];
        }
    }

    can count with Clock entry {
        if here.activation.pending > 0 {
            here.activation.pending = 0;
            if not here.running {
                here.running = True;
                here.clock = 1.0;
            }
        }
        if not here.running {
            return;
        }
        here.clock -= self.dt;
        if here.clock > 0.0 {
            return;
        }
        here.clock += 1.0;
        message = clock_text(here.style, here.value);
        for readout in [here->:Shows:->][?:Readout] {
            readout.message = message;
            for glyph in [readout->:Spells:->][?:Glyph] {
                frame = glyph_frame(message, glyph.position);
                for face in glyph.faces {
                    self.bsp.faces[face].frame = frame;
                }
            }
        }
        if here.counting_up {
            here.value += 1;
        } elif here.counting_down {
            here.value -= 1;
        }
        expired = (here.counting_up and here.value > here.limit)
            or (here.counting_down and here.value < here.limit);
        if expired {
            here.activation spawn Fire();
            if not here.multi_use {
                here.running = False;
                return;
            }
            here.value = 0 if here.counting_up else here.count;
            if here.start_off {
                here.running = False;
            }
        }
    }
}

"""Build clocks, readouts and glyphs from a Q2 map's entities."""
def load_clocks(world: World, bsp: Bsp) {
    if bsp.game != "q2" {
        return;
    }
    readouts: dict[str, Readout] = {};
    glyph_teams: dict[str, list[Glyph]] = {};
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        kind = fields.get("classname", "");
        if kind == "target_character" {
            reference = fields.get("model", "");
            if not reference.startswith("*") or not reference[1:].isdigit() {
                continue;
            }
            model = int(reference[1:]);
            if model <= 0 or model >= len(bsp.models) {
                continue;
            }
            record = bsp.models[model];
            glyph = Glyph(
                position=int(float(fields.get("count", "0"))),
                faces=list(range(record.first_face, record.first_face + record.face_count))
            );
            team = fields.get("team", "");
            if team not in glyph_teams {
                glyph_teams[team] = [];
            }
            glyph_teams[team].append(glyph);
        } elif kind == "target_string" {
            readout = Readout(message=fields.get("message", ""));
            name = fields.get("targetname", "");
            if name {
                readouts[name] = readout;
            }
            for glyph in glyph_teams.get(fields.get("team", ""), []) {
                readout +>:Spells:+> glyph;
            }
        }
    }
    # Glyphs may follow their string in the entity list; join them by team.
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") == "target_string" {
            name = fields.get("targetname", "");
            if name in readouts {
                linked = [readouts[name]->:Spells:->][?:Glyph];
                for glyph in glyph_teams.get(fields.get("team", ""), []) {
                    if glyph not in linked {
                        readouts[name] +>:Spells:+> glyph;
                    }
                }
            }
        }
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") != "func_clock" {
            continue;
        }
        flags = int(fields.get("spawnflags", "0"));
        count = int(float(fields.get("count", "0")));
        clock = Clock(
            counting_up=flags & 1 != 0,
            counting_down=flags & 2 != 0,
            style=int(float(fields.get("style", "0"))),
            count=count,
            multi_use=flags & 8 != 0,
            start_off=flags & 4 != 0,
            activation=Signal(entities=[index])
        );
        # func_clock_reset: up from 0 to count, or down from count to 0.
        clock.value = count if clock.counting_down else 0;
        clock.limit = 0 if clock.counting_down else count;
        clock.running = not clock.start_off;
        clock.clock = 1.0;
        target = fields.get("target", "");
        if target in readouts {
            clock +>:Shows:+> readouts[target];
        }
        world +>:HasClock:+> clock;
        world +>:HasSignal:+> clock.activation;
    }
}
