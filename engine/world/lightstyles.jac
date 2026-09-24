"""Animated and switchable light styles (Q1 world.qc, Q2 g_spawn.c
SP_worldspawn). A style is a string of brightness letters played at 10 Hz, 'a'
for dark and 'm' for normal up to 'z'; lightmaps store one layer per style.
Lights a mapper made switchable (styles 32-62) toggle between 'm' and 'a' when
triggered, and start dark when flagged START_OFF."""
import from .world { World }
import from .signals { Signal, HasSignal }
import from ..formats.bsp { Bsp }

glob STYLE_PATTERNS: list[str] = [
    "m",
    "mmnmmommommnonmmonqnmmo",
    "abcdefghijklmnopqrstuvwxyzyxwvutsrqponmlkjihgfedcba",
    "mmmmmaaaaammmmmaaaaaabcdefgabcdefg",
    "mamamamamama",
    "jklmnopqrstuvwxyzyxwvutsrqponmlkj",
    "nmonqnmomnmomomno",
    "mmmaaaabcdefgmmmmaaaammmaamm",
    "mmmaaammmaaammmabcdefaaaammmmabcdefmmmaaaa",
    "aaaaaaaazzzzzzzz",
    "mmamammmmammamamaaamammma",
    "abcdefghijklmnopqrrqponmlkjihgfedcba"
];

"""A style letter's brightness relative to normal ('m'), as d_lightstylevalue
scales ('a' is 0, 'm' is 1, 'z' a little over 2)."""
def letter_scale(letter: str) -> float {
    return float(max(0, ord(letter) - 97)) / 12.0;
}

node LightStyles {
    has patterns: dict[int, str] = {},
        values: dict[int, float] = {},
        clock: float = 0.0,
        frame: int = -1,
        serial: int = 0;

    """Brightness of every animated or switched style at the current frame."""
    def refresh() {
        changed = False;
        for (style, pattern) in self.patterns.items() {
            value = letter_scale(pattern[self.frame % len(pattern)]) if pattern else 1.0;
            if style not in self.values or self.values[style] != value {
                self.values[style] = value;
                changed = True;
            }
        }
        if changed {
            self.serial += 1;
        }
    }
}

edge HasLightStyles: World --> LightStyles {}

node LightSwitch {
    has style: int,
        on: bool = True,
        activation: Signal = Signal();
}

edge Switches: LightStyles --> LightSwitch {}

"""Q2 g_target.c target_lightramp: when used, its target light's style runs
from the message's first letter to its second over `speed` seconds; flagged
TOGGLE, each later use runs it back."""
node LightRamp {
    has style: int,
        first: int,
        last: int,
        speed: float,
        toggle: bool = False,
        clock: float = -1.0,
        activation: Signal = Signal();
}

edge Ramps: LightStyles --> LightRamp {}

"""Advance every style at 10 Hz and flip switched lights that were triggered."""
walker LightStyleTick {
    has dt: float;

    can begin with World entry {
        visit [here->:HasLightStyles:->];
    }

    can play with LightStyles entry {
        here.clock += self.dt;
        flipped = False;
        for lamp in [here->:Switches:->][?:LightSwitch] {
            if lamp.activation.pending > 0 {
                # light_use toggles on every use.
                if lamp.activation.pending % 2 == 1 {
                    lamp.on = not lamp.on;
                    if lamp.style >= 0 {
                        here.patterns[lamp.style] = "m" if lamp.on else "a";
                        flipped = True;
                    }
                }
                lamp.activation.pending = 0;
            }
        }
        for ramp in [here->:Ramps:->][?:LightRamp] {
            if ramp.activation.pending > 0 {
                ramp.activation.pending = 0;
                if ramp.toggle and ramp.clock >= ramp.speed {
                    swap = ramp.first;
                    ramp.first = ramp.last;
                    ramp.last = swap;
                }
                ramp.clock = 0.0;
            }
            if ramp.clock >= 0.0 {
                ramp.clock = min(ramp.speed, ramp.clock + self.dt);
                share = ramp.clock / ramp.speed if ramp.speed > 0.0 else 1.0;
                letter = int(float(ramp.first) + float(ramp.last - ramp.first) * share + 0.5);
                here.patterns[ramp.style] = chr(97 + max(0, min(25, letter)));
                flipped = True;
            }
        }
        frame = int(here.clock * 10.0);
        if frame != here.frame or flipped {
            here.frame = frame;
            here.refresh();
        }
    }
}

"""The styles of a Q1 or Q2 map: the fixed animated set, plus a lamp for each
targetable light, joined to the level's signal graph by its entity index."""
def load_light_styles(world: World, bsp: Bsp) -> LightStyles | None {
    if bsp.game not in ["q1", "q2"] {
        return None;
    }
    styles = LightStyles();
    for index in range(len(STYLE_PATTERNS)) {
        styles.patterns[index] = STYLE_PATTERNS[index];
    }
    styles.patterns[63] = "a";
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if not fields.get("classname", "").startswith("light") or not fields.get("targetname", "") {
            continue;
        }
        style = int(float(fields.get("style", "0")));
        start_off = int(fields.get("spawnflags", "0")) & 1 != 0;
        # A named light without a switchable style still receives its uses,
        # so trigger chains through it resolve, but changes nothing.
        switchable = style >= 32 and style <= 62;
        lamp = LightSwitch(style=style if switchable else -1, on=not start_off, activation=Signal(entities=[index]));
        if switchable {
            styles.patterns[style] = "a" if start_off else "m";
        }
        world +>:HasSignal:+> lamp.activation;
        styles +>:Switches:+> lamp;
    }
    # target_lightramp drives the style of the light it targets.
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") != "target_lightramp" {
            continue;
        }
        message = fields.get("message", "");
        if len(message) != 2 or not message.isalpha() {
            continue;
        }
        target = fields.get("target", "");
        style = -1;
        for other in bsp.entities {
            if other.fields.get("targetname", "") == target and other.fields.get("classname", "").startswith("light") {
                style = int(float(other.fields.get("style", "0")));
            }
        }
        if style < 32 {
            continue;
        }
        ramp = LightRamp(
            style=style,
            first=ord(message[0].lower()) - 97,
            last=ord(message[1].lower()) - 97,
            speed=float(fields.get("speed", "1")),
            toggle=int(fields.get("spawnflags", "0")) & 1 != 0,
            activation=Signal(entities=[index])
        );
        world +>:HasSignal:+> ramp.activation;
        styles +>:Ramps:+> ramp;
    }
    styles.frame = 0;
    styles.refresh();
    world +>:HasLightStyles:+> styles;
    return styles;
}
