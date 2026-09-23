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
                    here.patterns[lamp.style] = "m" if lamp.on else "a";
                    flipped = True;
                }
                lamp.activation.pending = 0;
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
        if style < 32 or style > 62 {
            continue;
        }
        start_off = int(fields.get("spawnflags", "0")) & 1 != 0;
        lamp = LightSwitch(style=style, on=not start_off, activation=Signal(entities=[index]));
        styles.patterns[style] = "a" if start_off else "m";
        world +>:HasSignal:+> lamp.activation;
        styles +>:Switches:+> lamp;
    }
    styles.frame = 0;
    styles.refresh();
    world +>:HasLightStyles:+> styles;
    return styles;
}
