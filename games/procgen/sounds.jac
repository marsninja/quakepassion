"""Sound effects: a recipe for each family of sound (gunshots, explosions,
pickups, doors, lifts, buttons, ambient loops, splashes, footsteps,
teleports, creature voices...), chosen from the sound's path by the same
walk over family nodes the textures use.

A sound is made as long as the one it stands in for, at its rate, and a
sound that loops (Quake marks its loop with a cue) is made to loop: its end
faded into its beginning. Creatures' voices are pitched by the size of the
creature their folder names: a shambler growls low, a dog yelps high."""
import math;
import from games.passion.random { hash_label, mix32 }
import from .families { Families, families_of, choose_family }
import from .synth {
    Wave, Voice, render, layered, echoed, driven, peaked, looped, fitted, resampled, muffled, made_loud
}

"""What a sound may vary on, from its name."""
obj Tone {
    has seed: int,
        seconds: float,
        rate: int,
        words: str = "";

    def pick(count: int, label: str) -> int {
        return mix32(self.seed ^ hash_label(41, label)) % max(1, count);
    }

    def amount(label: str, low: float, high: float) -> float {
        t = float(mix32(self.seed ^ hash_label(43, label))) / 4294967296.0;
        return low + (high - low) * t;
    }

    def voice_seed(label: str) -> int {
        return mix32(self.seed ^ hash_label(47, label));
    }
}

obj SoundBook {
    has shelf: Families | None = None;

    def families -> Families {
        found = self.shelf;
        if found is not None {
            return found;
        }
        made = families_of(
            [
                ("explosion", ["exp", "explod", "blast", "boom", "r_exp", "bfg__x", "x1"]),
                ("gunshot", ["sgun", "shotg", "shotgn", "gun", "mach", "chain", "fire", "shoot", "bullet", "ssg", "railg", "sg_", "mg_"]),
                ("launch", ["rocket", "grenade", "gren", "launch", "rocklf", "rlaunch", "glaunch"]),
                ("spike", ["spike", "nail", "spik", "needle"]),
                ("lightning", ["lstart", "lhit", "lightn", "lgun", "thunder", "electr", "zap", "spark", "lbolt", "lg_"]),
                ("energy", ["plasma", "laser", "blaster", "hyprb", "bfg"]),
                ("ricochet", ["ric", "tink", "bounce", "clank", "ping", "metal"]),
                ("melee", ["ax1", "axhit", "punch", "swing", "claw", "bite", "melee", "smack", "slash", "gaunt", "whip", "chop"]),
                ("pickup", ["items/", "pkup", "pickup", "health", "armor", "ammo", "item", "powerup", "quad", "protect", "inv", "key", "medkey", "runekey", "rune", "s_health", "n_health", "m_health", "l_health", "ar1", "ar2", "ar3", "wpkup", "weapon"]),
                ("mover", ["doors/", "door", "plats/", "plat", "train", "elevat", "lift", "hydro", "winch", "stone", "latch", "motor", "drclos", "doormv", "move", "bmodels"]),
                ("button", ["buttons/", "switch", "button", "butn", "lever", "click", "airbut"]),
                ("ambient", ["ambience/", "ambient", "hum", "drone", "wind", "drip", "swamp", "buzz", "comp", "fl_hum", "suck", "world/", "amb"]),
                ("water", ["h2o", "water", "splash", "inh2o", "outwater", "gurp", "drown", "gasp", "watr", "under", "bubble", "wade"]),
                ("step", ["land", "step", "foot", "jump", "plyrjmp", "fall", "walk", "boot", "flesh"]),
                ("teleport", ["tele", "r_tele", "teleport", "respawn", "spawn", "telein", "telout", "portal"]),
                ("interface", ["menu", "talk", "secret", "beep", "null", "hit.wav", "message", "chat", "count", "fight", "feedback/", "mnu", "misc/"]),
                ("creature", ["pain", "death", "die", "idle", "sight", "alert", "growl", "udeath", "attack", "idle", "search", "scream", "roar", "howl", "moan", "jump1", "gurgle", "taunt", "fall1", "player/", "monsters/", "voice"]),
                ("gore", ["gib", "squish", "splat", "tornoff", "gibsplt", "gibimp", "bodyimp"]),
                ("fire", ["burn", "flame", "lava", "fire1", "torch", "lburn", "inlava"])
            ]
        );
        self.shelf = made;
        return made;
    }

    def choose(path: str) -> str {
        found = choose_family(self.families(), path.lower());
        return found if found else "interface";
    }
}

glob _sound_book: SoundBook = SoundBook();

def sound_family(path: str) -> str {
    return _sound_book.choose(path);
}

"""How big the creature a sound's path names is: 0 a small one (a dog, a
fish), 1 a giant (a shambler, a tank, a boss); a half when it says nothing."""
def creature_size(path: str) -> float {
    lower = path.lower();
    sizes: list[tuple[str, float]] = [
        ("boss", 1.0), ("shub", 1.0), ("chthon", 1.0), ("shambler", 0.95), ("tank", 0.95), ("makron", 1.0),
        ("jorg", 1.0), ("ogre", 0.85), ("gladiator", 0.8), ("mutant", 0.7), ("berserk", 0.75), ("hknight", 0.7),
        ("knight", 0.6), ("demon", 0.7), ("fiend", 0.7), ("zombie", 0.55), ("medic", 0.6), ("brain", 0.65),
        ("soldier", 0.45), ("enforcer", 0.5), ("infantry", 0.5), ("gunner", 0.55), ("chick", 0.35),
        ("bitch", 0.35), ("wizard", 0.3), ("scrag", 0.3), ("flyer", 0.2), ("shalrath", 0.6), ("vore", 0.6),
        ("dog", 0.2), ("fish", 0.15), ("parasite", 0.25), ("floater", 0.4), ("hover", 0.35), ("tarbaby", 0.25),
        ("player", 0.45), ("female", 0.3), ("male", 0.45), ("cyborg", 0.55), ("crakhor", 0.5)
    ];
    for (word, size) in sizes {
        if word in lower {
            return size;
        }
    }
    return 0.5;
}

def:priv explosion(tone: Tone) -> Wave {
    length = max(0.4, tone.seconds);
    blast = Voice(
        wave="white", pitch=1000.0, attack=0.002, sustain=length * 0.1, punch=0.8, decay=length * 0.9,
        lowpass=tone.amount("cut", 1800.0, 3600.0), lowpass_sweep=-2.5, resonance=0.1, volume=0.9,
        seed=tone.voice_seed("blast")
    );
    thump = Voice(
        wave="sine", pitch=tone.amount("thump", 70.0, 110.0), slide=-1.5, attack=0.001, sustain=0.05, decay=0.5,
        volume=1.0, seed=tone.voice_seed("thump")
    );
    rumble = Voice(
        wave="pink", pitch=100.0, attack=0.01, sustain=length * 0.2, decay=length * 0.8, lowpass=300.0, volume=0.9,
        seed=tone.voice_seed("rumble")
    );
    mixed = layered([render(blast, tone.rate), render(thump, tone.rate), render(rumble, tone.rate)], [1.0, 0.9, 0.8], [0.0, 0.0, 0.0], tone.rate);
    return driven(mixed, 1.8);
}

def:priv gunshot(tone: Tone) -> Wave {
    big = "shot" in tone.words or "sgun" in tone.words or "ssg" in tone.words;
    length = min(max(0.15, tone.seconds), 0.9);
    crack = Voice(
        wave="white", pitch=1000.0, attack=0.0005, sustain=0.01, punch=1.0, decay=length * (0.6 if big else 0.4),
        lowpass=tone.amount("cut", 2500.0, 6000.0), lowpass_sweep=-3.0, volume=1.0, seed=tone.voice_seed("crack")
    );
    body = Voice(
        wave="square", pitch=tone.amount("body", 90.0, 160.0), slide=-3.0, duty=0.3, attack=0.0005, sustain=0.02,
        decay=0.12 if big else 0.06, lowpass=900.0, volume=0.7, seed=tone.voice_seed("body")
    );
    shot = layered([render(crack, tone.rate), render(body, tone.rate)], [1.0, 0.8], [0.0, 0.0], tone.rate);
    if tone.seconds > 0.5 and "cock" not in tone.words {
        # A longer report rings off the walls.
        shot = echoed(shot, 0.07, 0.3, 3);
    }
    if "cock" in tone.words or "load" in tone.words {
        clack = Voice(wave="metal", pitch=1400.0, attack=0.0, sustain=0.005, decay=0.05, volume=0.6, seed=tone.voice_seed("a"));
        clack2 = Voice(wave="metal", pitch=1100.0, attack=0.0, sustain=0.005, decay=0.06, volume=0.6, seed=tone.voice_seed("b"));
        return layered([render(clack, tone.rate), render(clack2, tone.rate)], [1.0, 1.0], [0.0, max(0.08, tone.seconds * 0.5)], tone.rate);
    }
    return driven(shot, 1.6);
}

def:priv launch(tone: Tone) -> Wave {
    length = max(0.3, tone.seconds);
    whoosh = Voice(
        wave="white", pitch=1000.0, attack=0.01, sustain=length * 0.3, decay=length * 0.7, lowpass=800.0,
        lowpass_sweep=1.5, resonance=0.5, volume=0.8, seed=tone.voice_seed("whoosh")
    );
    thunk = Voice(
        wave="sine", pitch=tone.amount("thunk", 120.0, 180.0), slide=-2.0, attack=0.001, sustain=0.03, decay=0.2,
        volume=1.0, seed=tone.voice_seed("thunk")
    );
    if "fly" in tone.words or "rocket1i" in tone.words or "lf" in tone.words {
        # A rocket in flight: a steady roar that loops.
        roar = Voice(
            wave="pink", pitch=100.0, attack=0.0, sustain=length, decay=0.0, lowpass=1200.0, resonance=0.3,
            volume=0.8, seed=tone.voice_seed("roar")
        );
        return render(roar, tone.rate);
    }
    return driven(layered([render(whoosh, tone.rate), render(thunk, tone.rate)], [1.0, 1.0], [0.0, 0.0], tone.rate), 1.3);
}

def:priv spike(tone: Tone) -> Wave {
    zip = Voice(
        wave="square", pitch=tone.amount("zip", 900.0, 1500.0), slide=-6.0, duty=0.25, attack=0.0, sustain=0.02,
        decay=0.08, lowpass=4000.0, volume=0.7, seed=tone.voice_seed("zip")
    );
    click = Voice(wave="white", pitch=1000.0, attack=0.0, sustain=0.005, decay=0.03, lowpass=6000.0, volume=0.6, seed=tone.voice_seed("click"));
    return layered([render(zip, tone.rate), render(click, tone.rate)], [1.0, 1.0], [0.0, 0.0], tone.rate);
}

def:priv lightning(tone: Tone) -> Wave {
    length = max(0.2, tone.seconds);
    buzz = Voice(
        wave="saw", pitch=tone.amount("buzz", 70.0, 140.0), vibrato_depth=0.3, vibrato_rate=37.0, attack=0.005,
        sustain=length * 0.8, decay=length * 0.2, lowpass=2400.0, resonance=0.4, volume=0.7, seed=tone.voice_seed("buzz")
    );
    crackle = Voice(
        wave="noise", pitch=tone.amount("crackle", 2000.0, 5000.0), attack=0.0, sustain=length * 0.8,
        decay=length * 0.2, volume=0.5, seed=tone.voice_seed("crackle")
    );
    if "plasma" in tone.words or "laser" in tone.words or "blaster" in tone.words or "bfg" in tone.words {
        bolt = Voice(
            wave="square", pitch=tone.amount("bolt", 500.0, 900.0), slide=-3.0, duty=0.4, duty_sweep=0.5,
            attack=0.0, sustain=0.03, decay=min(0.4, length), lowpass=3000.0, volume=0.7, seed=tone.voice_seed("bolt")
        );
        return render(bolt, tone.rate);
    }
    return driven(layered([render(buzz, tone.rate), render(crackle, tone.rate)], [1.0, 0.7], [0.0, 0.0], tone.rate), 2.0);
}

def:priv ricochet(tone: Tone) -> Wave {
    ping = Voice(
        wave="metal", pitch=tone.amount("ping", 1500.0, 3500.0), slide=tone.amount("slide", -2.0, -0.5),
        attack=0.0, sustain=0.01, decay=min(0.6, max(0.1, tone.seconds)), volume=0.6, seed=tone.voice_seed("ping")
    );
    tick = Voice(wave="white", pitch=1000.0, attack=0.0, sustain=0.003, decay=0.02, lowpass=7000.0, volume=0.6, seed=tone.voice_seed("tick"));
    return layered([render(tick, tone.rate), render(ping, tone.rate)], [1.0, 0.8], [0.0, 0.004], tone.rate);
}

def:priv melee(tone: Tone) -> Wave {
    if "hit" in tone.words or "smack" in tone.words or "punch" in tone.words or "bite" in tone.words {
        thud = Voice(wave="white", pitch=1000.0, attack=0.0, sustain=0.01, punch=0.5, decay=0.15, lowpass=900.0, volume=1.0, seed=tone.voice_seed("thud"));
        body = Voice(wave="sine", pitch=120.0, slide=-2.0, attack=0.0, sustain=0.01, decay=0.12, volume=0.9, seed=tone.voice_seed("body"));
        return driven(layered([render(thud, tone.rate), render(body, tone.rate)], [1.0, 1.0], [0.0, 0.0], tone.rate), 1.5);
    }
    swing = Voice(
        wave="white", pitch=1000.0, attack=max(0.02, tone.seconds * 0.3), sustain=0.02, decay=max(0.05, tone.seconds * 0.5),
        lowpass=600.0, lowpass_sweep=2.0, resonance=0.6, volume=0.8, seed=tone.voice_seed("swing")
    );
    return render(swing, tone.rate);
}

def:priv pickup(tone: Tone) -> Wave {
    steps = 2 + tone.pick(3, "steps");
    base = tone.amount("base", 300.0, 700.0);
    waves: list[Wave] = [];
    starts: list[float] = [];
    ratios = [1.0, 1.25, 1.5, 2.0, 2.5];
    if "armor" in tone.words or "ar" in tone.words.split("/")[-1][:2] {
        clang = Voice(wave="metal", pitch=base * 0.6, attack=0.0, sustain=0.02, decay=0.5, volume=0.8, seed=tone.voice_seed("clang"));
        return render(clang, tone.rate);
    }
    if "ammo" in tone.words or "lock" in tone.words or "weapon" in tone.words or "wpkup" in tone.words {
        clack = Voice(wave="metal", pitch=900.0, attack=0.0, sustain=0.005, decay=0.06, volume=0.7, seed=tone.voice_seed("clack"));
        clack2 = Voice(wave="metal", pitch=700.0, attack=0.0, sustain=0.005, decay=0.08, volume=0.7, seed=tone.voice_seed("clack2"));
        return layered([render(clack, tone.rate), render(clack2, tone.rate)], [1.0, 1.0], [0.0, 0.07], tone.rate);
    }
    long_one = "protect" in tone.words or "quad" in tone.words or "inv" in tone.words or "power" in tone.words or "rune" in tone.words;
    note = 0.07 if not long_one else 0.12;
    for k in range(steps + (2 if long_one else 0)) {
        v = Voice(
            wave="square" if not long_one else "triangle", pitch=base * ratios[k % len(ratios)] * (1.0 + float(k // 5)),
            duty=0.4, attack=0.002, sustain=note * 0.6, decay=note * 1.5, vibrato_depth=0.01 if long_one else 0.0,
            vibrato_rate=8.0, volume=0.5, seed=tone.voice_seed("n" + str(k))
        );
        waves.append(render(v, tone.rate));
        starts.append(float(k) * note);
    }
    mixed = layered(waves, [1.0] * len(waves), starts, tone.rate);
    return echoed(mixed, 0.09, 0.25, 2) if long_one else mixed;
}

def:priv mover(tone: Tone) -> Wave {
    length = max(0.2, tone.seconds);
    if length < 0.6 or "clos" in tone.words or "stop" in tone.words or "2.wav" in tone.words or "latch" in tone.words {
        # A stop: a clunk.
        clunk = Voice(wave="white", pitch=1000.0, attack=0.0, sustain=0.01, punch=0.5, decay=min(length, 0.4), lowpass=700.0, volume=1.0, seed=tone.voice_seed("clunk"));
        ring = Voice(wave="metal", pitch=tone.amount("ring", 150.0, 300.0), attack=0.0, sustain=0.01, decay=min(length, 0.5), volume=0.5, seed=tone.voice_seed("ring"));
        return layered([render(clunk, tone.rate), render(ring, tone.rate)], [1.0, 0.7], [0.0, 0.0], tone.rate);
    }
    motor = Voice(
        wave="saw", pitch=tone.amount("motor", 45.0, 90.0), vibrato_depth=0.02, vibrato_rate=tone.amount("wobble", 3.0, 9.0),
        attack=0.05, sustain=length * 0.85, decay=length * 0.1, lowpass=500.0, resonance=0.3, volume=0.7,
        seed=tone.voice_seed("motor")
    );
    grind = Voice(
        wave="pink", pitch=100.0, attack=0.05, sustain=length * 0.85, decay=length * 0.1, lowpass=tone.amount("grind", 400.0, 1500.0),
        volume=0.6, seed=tone.voice_seed("grind")
    );
    return layered([render(motor, tone.rate), render(grind, tone.rate)], [1.0, 0.8], [0.0, 0.0], tone.rate);
}

def:priv button(tone: Tone) -> Wave {
    click = Voice(wave="white", pitch=1000.0, attack=0.0, sustain=0.004, decay=0.03, lowpass=5000.0, volume=0.8, seed=tone.voice_seed("click"));
    beep = Voice(wave="square", pitch=tone.amount("beep", 500.0, 1200.0), duty=0.5, attack=0.002, sustain=0.06, decay=0.08, volume=0.4, seed=tone.voice_seed("beep"));
    return layered([render(click, tone.rate), render(beep, tone.rate)], [1.0, 1.0], [0.0, 0.03], tone.rate);
}

"""An ambient loop: wind, hum, a drone, drips, bubbling water, buzzing or a
computer's chatter, as the name says."""
def:priv ambient(tone: Tone) -> Wave {
    length = max(1.0, tone.seconds);
    w = tone.words;
    if "wind" in w or "suck" in w {
        gust = Voice(
            wave="pink", pitch=100.0, attack=0.0, sustain=length, decay=0.0, lowpass=tone.amount("cut", 300.0, 900.0),
            lowpass_sweep=0.0, resonance=0.7, vibrato_depth=0.0, volume=0.9, seed=tone.voice_seed("gust")
        );
        return render(gust, tone.rate);
    }
    if "drip" in w {
        waves: list[Wave] = [];
        starts: list[float] = [];
        count = max(2, int(length * 1.5));
        for k in range(count) {
            plink = Voice(wave="sine", pitch=tone.amount("p" + str(k), 900.0, 1600.0), slide=1.5, attack=0.0, sustain=0.005, decay=0.12, volume=0.6, seed=tone.voice_seed("d" + str(k)));
            waves.append(render(plink, tone.rate));
            starts.append(tone.amount("t" + str(k), 0.0, max(0.1, length - 0.2)));
        }
        return fitted(layered(waves, [1.0] * len(waves), starts, tone.rate), length);
    }
    if "comp" in w {
        waves2: list[Wave] = [];
        starts2: list[float] = [];
        count2 = max(4, int(length * 6.0));
        for k in range(count2) {
            blip = Voice(wave="square", pitch=tone.amount("c" + str(k), 400.0, 2000.0), duty=0.5, attack=0.0, sustain=0.03, decay=0.03, volume=0.25, seed=tone.voice_seed("c" + str(k)));
            waves2.append(render(blip, tone.rate));
            starts2.append(float(k) * length / float(count2));
        }
        return fitted(layered(waves2, [1.0] * len(waves2), starts2, tone.rate), length);
    }
    if "water" in w or "swamp" in w {
        stream = Voice(wave="pink", pitch=100.0, attack=0.0, sustain=length, decay=0.0, lowpass=700.0, resonance=0.5, volume=0.8, seed=tone.voice_seed("flow"));
        return render(stream, tone.rate);
    }
    if "buzz" in w or "fl_hum" in w {
        hum = Voice(wave="square", pitch=120.0, duty=0.3, attack=0.0, sustain=length, decay=0.0, lowpass=1200.0, volume=0.4, seed=tone.voice_seed("buzz"));
        return render(hum, tone.rate);
    }
    if "drone" in w or "hum" in w {
        low = Voice(wave="saw", pitch=tone.amount("drone", 40.0, 70.0), vibrato_depth=0.004, vibrato_rate=0.5, attack=0.0, sustain=length, decay=0.0, lowpass=300.0, volume=0.6, seed=tone.voice_seed("low"));
        high = Voice(wave="sine", pitch=tone.amount("drone", 40.0, 70.0) * 3.01, attack=0.0, sustain=length, decay=0.0, volume=0.25, seed=tone.voice_seed("high"));
        return layered([render(low, tone.rate), render(high, tone.rate)], [1.0, 1.0], [0.0, 0.0], tone.rate);
    }
    if "fire" in w or "torch" in w {
        return fire(tone);
    }
    air = Voice(wave="pink", pitch=100.0, attack=0.0, sustain=length, decay=0.0, lowpass=tone.amount("air", 200.0, 600.0), volume=0.7, seed=tone.voice_seed("air"));
    return render(air, tone.rate);
}

def:priv water(tone: Tone) -> Wave {
    length = max(0.2, min(1.5, tone.seconds));
    splash = Voice(
        wave="white", pitch=1000.0, attack=0.002, sustain=0.03, punch=0.5, decay=length * 0.8, lowpass=2500.0,
        lowpass_sweep=-1.5, volume=0.8, seed=tone.voice_seed("splash")
    );
    waves = [render(splash, tone.rate)];
    starts = [0.0];
    for k in range(3 + tone.pick(4, "bubbles")) {
        bubble = Voice(wave="sine", pitch=tone.amount("b" + str(k), 300.0, 900.0), slide=3.0, attack=0.0, sustain=0.01, decay=0.06, volume=0.35, seed=tone.voice_seed("b" + str(k)));
        waves.append(render(bubble, tone.rate));
        starts.append(tone.amount("bt" + str(k), 0.02, length * 0.8));
    }
    return layered(waves, [1.0] * len(waves), starts, tone.rate);
}

def:priv step(tone: Tone) -> Wave {
    thud = Voice(wave="white", pitch=1000.0, attack=0.0, sustain=0.01, decay=min(0.2, max(0.06, tone.seconds)), lowpass=tone.amount("cut", 400.0, 900.0), volume=0.9, seed=tone.voice_seed("thud"));
    body = Voice(wave="sine", pitch=tone.amount("body", 70.0, 110.0), slide=-1.0, attack=0.0, sustain=0.01, decay=0.1, volume=0.8, seed=tone.voice_seed("body"));
    if "jump" in tone.words or "plyrjmp" in tone.words {
        return creature(tone);
    }
    return layered([render(thud, tone.rate), render(body, tone.rate)], [1.0, 1.0], [0.0, 0.0], tone.rate);
}

def:priv teleport(tone: Tone) -> Wave {
    length = max(0.4, tone.seconds);
    sweep = Voice(
        wave="triangle", pitch=tone.amount("from", 150.0, 300.0), slide=2.5 / length, vibrato_depth=0.05,
        vibrato_rate=18.0, attack=0.02, sustain=length * 0.5, decay=length * 0.5, volume=0.6, seed=tone.voice_seed("sweep")
    );
    shimmer = Voice(
        wave="noise", pitch=tone.amount("shimmer", 3000.0, 6000.0), attack=0.05, sustain=length * 0.4,
        decay=length * 0.5, highpass=2000.0, volume=0.3, seed=tone.voice_seed("shimmer")
    );
    return echoed(layered([render(sweep, tone.rate), render(shimmer, tone.rate)], [1.0, 1.0], [0.0, 0.0], tone.rate), 0.08, 0.3, 3);
}

def:priv interface(tone: Tone) -> Wave {
    if "null" in tone.words {
        return Wave(rate=tone.rate, samples=[0.0] * max(1, int(tone.seconds * float(tone.rate))));
    }
    if "secret" in tone.words or "talk" in tone.words or "message" in tone.words {
        first = Voice(wave="triangle", pitch=660.0, attack=0.005, sustain=0.08, decay=0.2, volume=0.5, seed=tone.voice_seed("a"));
        second = Voice(wave="triangle", pitch=990.0, attack=0.005, sustain=0.08, decay=0.3, volume=0.5, seed=tone.voice_seed("b"));
        return layered([render(first, tone.rate), render(second, tone.rate)], [1.0, 1.0], [0.0, 0.1], tone.rate);
    }
    blip = Voice(wave="square", pitch=tone.amount("blip", 500.0, 1400.0), duty=0.5, slide=tone.amount("slide", -1.0, 1.0), attack=0.0, sustain=0.03, decay=min(0.25, max(0.05, tone.seconds)), volume=0.4, seed=tone.voice_seed("blip"));
    return render(blip, tone.rate);
}

"""A creature's cry: a buzzing throat (a saw under a low pass that sweeps
like a mouth opening and closing), breath, and a pitch set by the
creature's size that rises for a sight, falls for a death and wavers in
pain."""
def:priv creature(tone: Tone) -> Wave {
    size = creature_size(tone.words);
    w = tone.words;
    length = max(0.2, tone.seconds);
    base = 400.0 * math.pow(0.12, size) * tone.amount("pitch", 0.85, 1.2) + 40.0;
    slide = 0.0;
    vibrato = 0.02;
    if "death" in w or "die" in w {
        slide = -1.2 / length;
    } elif "sight" in w or "alert" in w or "search" in w {
        slide = 0.6 / length;
    } elif "pain" in w {
        vibrato = 0.08;
        slide = tone.amount("painslide", -0.8, 0.8);
    } elif "idle" in w {
        vibrato = 0.01;
    }
    throat = Voice(
        wave="saw", pitch=base, slide=slide, vibrato_depth=vibrato, vibrato_rate=tone.amount("vib", 5.0, 11.0),
        attack=min(0.05, length * 0.2), sustain=length * 0.5, punch=0.3, decay=length * 0.45,
        lowpass=base * tone.amount("mouth", 4.0, 9.0), lowpass_sweep=tone.amount("mouthsweep", -1.5, 0.5),
        resonance=0.75, volume=0.8, seed=tone.voice_seed("throat")
    );
    breath = Voice(
        wave="white", pitch=1000.0, attack=min(0.05, length * 0.2), sustain=length * 0.5, decay=length * 0.45,
        lowpass=base * 10.0, resonance=0.4, volume=0.25 + 0.3 * size, seed=tone.voice_seed("breath")
    );
    cry = layered([render(throat, tone.rate), render(breath, tone.rate)], [1.0, 1.0], [0.0, 0.0], tone.rate);
    return driven(cry, 1.5 + 2.0 * size);
}

def:priv gore(tone: Tone) -> Wave {
    waves: list[Wave] = [];
    starts: list[float] = [];
    for k in range(2 + tone.pick(3, "splats")) {
        splat = Voice(wave="white", pitch=1000.0, attack=0.0, sustain=0.01, punch=0.4, decay=tone.amount("d" + str(k), 0.1, 0.3), lowpass=tone.amount("c" + str(k), 400.0, 1400.0), resonance=0.5, volume=0.8, seed=tone.voice_seed("s" + str(k)));
        waves.append(render(splat, tone.rate));
        starts.append(tone.amount("t" + str(k), 0.0, max(0.05, tone.seconds * 0.5)));
    }
    return driven(layered(waves, [1.0] * len(waves), starts, tone.rate), 1.5);
}

def:priv fire(tone: Tone) -> Wave {
    length = max(0.3, tone.seconds);
    roar = Voice(wave="pink", pitch=100.0, attack=0.02, sustain=length * 0.8, decay=length * 0.2, lowpass=800.0, volume=0.7, seed=tone.voice_seed("roar"));
    crackle = Voice(wave="noise", pitch=tone.amount("crackle", 30.0, 90.0), attack=0.02, sustain=length * 0.8, decay=length * 0.2, highpass=1500.0, volume=0.6, seed=tone.voice_seed("crackle"));
    return layered([render(roar, tone.rate), render(crackle, tone.rate)], [1.0, 0.8], [0.0, 0.0], tone.rate);
}

"""Make the sound a game names `path`, as long as `seconds`, at `rate`;
looping (its end joined to its beginning) when `loops`."""
def make_sound(path: str, seconds: float, rate: int, loops: bool, game: str, loudness: float = 0.0) -> Wave {
    tone = Tone(seed=hash_label(3, game + ":" + path.lower()), seconds=max(0.05, seconds), rate=rate, words=path.lower());
    family = sound_family(path);
    made = Wave(rate=rate);
    if family == "explosion" {
        made = explosion(tone);
    } elif family == "gunshot" {
        made = gunshot(tone);
    } elif family == "launch" {
        made = launch(tone);
    } elif family == "spike" {
        made = spike(tone);
    } elif family == "lightning" or family == "energy" {
        # The energy weapons' bolts are made by the lightning's recipe (its
        # zap), but are coloured and levelled as a family of their own.
        made = lightning(tone);
    } elif family == "ricochet" {
        made = ricochet(tone);
    } elif family == "melee" {
        made = melee(tone);
    } elif family == "pickup" {
        made = pickup(tone);
    } elif family == "mover" {
        made = mover(tone);
    } elif family == "button" {
        made = button(tone);
    } elif family == "ambient" {
        made = ambient(tone);
    } elif family == "water" {
        made = water(tone);
    } elif family == "step" {
        made = step(tone);
    } elif family == "teleport" {
        made = teleport(tone);
    } elif family == "creature" {
        made = creature(tone);
    } elif family == "gore" {
        made = gore(tone);
    } elif family == "fire" {
        made = fire(tone);
    } else {
        made = interface(tone);
    }
    (tilt, level) = sound_calibration(game, family);
    made = tilted(made, tilt);
    if loops {
        # Made a little long, then its tail faded into its head.
        fade = min(0.25, tone.seconds * 0.2);
        made = looped(fitted(made, tone.seconds + fade), fade);
    } else {
        made = fitted(made, tone.seconds);
    }
    if loudness > 0.0 {
        # As loud as the sound it stands in for.
        return made_loud(made, loudness);
    }
    return peaked(made, 0.9 * math.pow(10.0, level / 20.0));
}

"""How each family of a game's sounds is coloured and how loud it is,
against the game's own: a tilt (above 0 darker, a one-pole low-pass keeping
1 - tilt of each step; below 0 brighter, each sample less -tilt of the one
before) and a level in decibels below full. Each was found by matching the
median brightness and loudness of the family's generated sounds to the
median of the game's own sounds of that family (none fitted to a single
sound, and only for families of four sounds or more); a family the game
plays louder than its generated sounds can go is left at full level."""
def sound_calibration(game: str, family: str) -> tuple[float, float] {
    tables: dict[str, dict[str, tuple[float, float]]] = {
        "q1": {"ambient": (-0.9, -7.2), "button": (0.97, 0.0), "creature": (0.702, -5.7), "interface": (0.736, -4.0), "melee": (0.602, 0.0), "mover": (-0.65, 0.0), "pickup": (0.769, -2.7), "step": (-0.1, 0.0), "teleport": (-0.05, -6.8), "water": (0.937, -4.8)},
        "q2": {"ambient": (-0.85, -1.6), "creature": (-0.15, -4.8), "gunshot": (0.87, 0.0), "interface": (0.87, -3.2), "melee": (-0.6, 0.0), "mover": (-0.1, -0.4), "pickup": (0.636, 0.0), "step": (-0.45, 0.0)},
        "q3": {
            "ambient": (-0.85, -4.3), "button": (0.937, -4.9), "creature": (-0.25, -3.1), "gore": (-0.8, 0.0),
            "gunshot": (0.736, 0.0), "interface": (0.97, 0.0), "launch": (-0.8, 0.0), "lightning": (-0.75, 0.0),
            "mover": (-0.35, -2.5), "pickup": (0.803, -3.2), "step": (-0.55, -12.1), "teleport": (0.903, -2.2),
            "water": (0.97, -1.8)
        }
    };
    return tables.get(game, {}).get(family, (0.0, 0.0));
}

"""A sound made darker (tilt above 0) or brighter (below 0)."""
def tilted(source: Wave, tilt: float) -> Wave {
    if abs(tilt) < 1.0e-6 or not source.samples {
        return source;
    }
    made: list[float] = [0.0] * len(source.samples);
    if tilt > 0.0 {
        keep = 1.0 - tilt;
        held = 0.0;
        for (i, sample) in enumerate(source.samples) {
            held += keep * (sample - held);
            made[i] = held;
        }
    } else {
        before = 0.0;
        for (i, sample) in enumerate(source.samples) {
            made[i] = sample + tilt * before;
            before = sample;
        }
    }
    return Wave(rate=source.rate, samples=made);
}
