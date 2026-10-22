"""Speech made by code: the words the games' announcers say ("Fight!",
"Excellent", "One", "You win"), spoken by a formant synthesizer.

A word is read from the sound's name and turned into phonemes (a small
dictionary of the games' words, then English letter rules). The phonemes
are laid out with their usual lengths and spoken as Klatt's synthesizer
speaks: a glottal pulse train whose closing edge carries the voice's upper
harmonics drives five resonances in cascade (so their levels come out as a
throat's do), with the upper ones also fed in parallel so vowels keep their
brightness; hissed sounds are noise through resonances placed where each
one hisses (high for s, lower for sh, flat for f); stops are a silence, a
burst and, when voiceless, a breath before the voice starts. Formants bend
toward a neighbour across each join, a vowel before a nasal turns nasal,
hiss fades out under a voice fading in, and the line's pitch rises to its
stress and falls to its end.

The levels and timings were tuned by having a speech recogniser transcribe
the words; the announcer's pitch is the games' (about 72 Hz)."""
import math;
import from games.passion.random { hash_label, mix32 }
import from .synth { Wave, peaked, echoed, fitted }

"""A band of noise a hissed sound or a burst is shaped into."""
obj Band {
    has hz: float,
        width: float,
        gain: float;
}

"""A phoneme: three formant targets and bandwidths (hertz), how voiced, hissed
and breathy it is, its usual length (ms), its kind (vowel "v", diphthong "d",
nasal "n", liquid or glide "l", hiss "f", stop "s", breath "h", pause "x"), a
diphthong's second targets, and where its hiss or burst sits."""
obj Phone {
    has f1: float,
        f2: float,
        f3: float,
        ms: float,
        kind: str,
        av: float = 1.0,
        af: float = 0.0,
        ah: float = 0.0,
        b1: float = 60.0,
        b2: float = 90.0,
        b3: float = 150.0,
        to1: float = 0.0,
        to2: float = 0.0,
        to3: float = 0.0,
        bands: list[Band] = [];

    def sonorant -> bool {
        return self.kind in ["v", "d", "n", "l"];
    }

    def vowel -> bool {
        return self.kind in ["v", "d"];
    }

    """The formant a diphthong ends on (its only one for anything else)."""
    def end_formant(k: int) -> float {
        if self.kind == "d" {
            return [self.to1, self.to2, self.to3][k];
        }
        return [self.f1, self.f2, self.f3][k];
    }
}

def:priv vowel(f1: float, f2: float, f3: float, ms: float) -> Phone {
    return Phone(f1=f1, f2=f2, f3=f3, ms=ms, kind="v");
}

def:priv glide_vowel(f1: float, f2: float, f3: float, ms: float, t1: float, t2: float, t3: float) -> Phone {
    return Phone(f1=f1, f2=f2, f3=f3, ms=ms, kind="d", to1=t1, to2=t2, to3=t3);
}

def:priv hiss(f1: float, f2: float, f3: float, ms: float, av: float, af: float, bands: list[Band]) -> Phone {
    return Phone(f1=f1, f2=f2, f3=f3, ms=ms, kind="f", av=av, af=af, bands=bands);
}

def:priv plosive(f1: float, f2: float, f3: float, ms: float, av: float, bands: list[Band]) -> Phone {
    return Phone(f1=f1, f2=f2, f3=f3, ms=ms, kind="s", av=av, bands=bands);
}

def:priv sonorant(f1: float, f2: float, f3: float, ms: float, kind: str, av: float, b1: float, b2: float, b3: float) -> Phone {
    return Phone(f1=f1, f2=f2, f3=f3, ms=ms, kind=kind, av=av, b1=b1, b2=b2, b3=b3);
}

"""ARPAbet phonemes: male formants (Peterson and Barney) and Klatt's
durations."""
glob PHONES: dict[str, Phone] = {
    "IY": vowel(270.0, 2290.0, 3010.0, 150.0),
    "IH": vowel(390.0, 1990.0, 2550.0, 110.0),
    "EH": vowel(530.0, 1840.0, 2480.0, 130.0),
    "AE": vowel(660.0, 1720.0, 2410.0, 170.0),
    "AA": vowel(730.0, 1090.0, 2440.0, 170.0),
    "AO": vowel(570.0, 840.0, 2410.0, 170.0),
    "UH": vowel(440.0, 1020.0, 2240.0, 110.0),
    "UW": vowel(300.0, 870.0, 2240.0, 150.0),
    "AH": vowel(520.0, 1190.0, 2390.0, 100.0),
    "AX": vowel(500.0, 1400.0, 2400.0, 60.0),
    "ER": vowel(490.0, 1350.0, 1690.0, 160.0),
    "AY": glide_vowel(700.0, 1200.0, 2500.0, 220.0, 300.0, 2200.0, 2900.0),
    "EY": glide_vowel(480.0, 1950.0, 2550.0, 190.0, 300.0, 2250.0, 2900.0),
    "OW": glide_vowel(540.0, 950.0, 2400.0, 200.0, 330.0, 800.0, 2300.0),
    "AW": glide_vowel(720.0, 1250.0, 2500.0, 230.0, 330.0, 850.0, 2300.0),
    "OY": glide_vowel(550.0, 900.0, 2400.0, 230.0, 300.0, 2100.0, 2800.0),
    "M": sonorant(270.0, 1100.0, 2150.0, 70.0, "n", 0.7, 40.0, 200.0, 200.0),
    "N": sonorant(270.0, 1700.0, 2600.0, 60.0, "n", 0.7, 40.0, 200.0, 200.0),
    "NG": sonorant(270.0, 2300.0, 2750.0, 80.0, "n", 0.7, 40.0, 200.0, 200.0),
    "L": sonorant(330.0, 1050.0, 2800.0, 60.0, "l", 0.85, 50.0, 100.0, 280.0),
    "R": sonorant(310.0, 1060.0, 1380.0, 60.0, "l", 0.85, 70.0, 100.0, 120.0),
    "W": sonorant(290.0, 610.0, 2150.0, 60.0, "l", 0.85, 50.0, 80.0, 60.0),
    "Y": sonorant(260.0, 2070.0, 3020.0, 60.0, "l", 0.85, 40.0, 250.0, 500.0),
    "S": hiss(320.0, 1390.0, 2530.0, 105.0, 0.0, 1.0, [Band(hz=5500.0, width=900.0, gain=1.0), Band(hz=8000.0, width=1500.0, gain=0.5)]),
    "Z": hiss(320.0, 1390.0, 2530.0, 75.0, 0.5, 0.7, [Band(hz=5500.0, width=900.0, gain=1.0), Band(hz=8000.0, width=1500.0, gain=0.5)]),
    "SH": hiss(300.0, 1840.0, 2750.0, 105.0, 0.0, 1.0, [Band(hz=2600.0, width=400.0, gain=1.0), Band(hz=3800.0, width=600.0, gain=0.7), Band(hz=6000.0, width=1500.0, gain=0.3)]),
    "ZH": hiss(300.0, 1840.0, 2750.0, 70.0, 0.5, 0.7, [Band(hz=2600.0, width=400.0, gain=1.0), Band(hz=3800.0, width=600.0, gain=0.7)]),
    "F": hiss(340.0, 1100.0, 2080.0, 100.0, 0.0, 6.0, [Band(hz=7000.0, width=3000.0, gain=0.6), Band(hz=3500.0, width=2000.0, gain=0.3)]),
    "V": hiss(220.0, 1100.0, 2080.0, 60.0, 0.6, 0.3, [Band(hz=7000.0, width=3000.0, gain=0.6)]),
    "TH": hiss(320.0, 1290.0, 2540.0, 100.0, 0.0, 0.4, [Band(hz=6500.0, width=3000.0, gain=0.5), Band(hz=3000.0, width=1500.0, gain=0.2)]),
    "DH": hiss(270.0, 1290.0, 2540.0, 50.0, 0.6, 0.25, [Band(hz=6500.0, width=3000.0, gain=0.4)]),
    "HH": Phone(f1=500.0, f2=1500.0, f3=2500.0, ms=70.0, kind="h", av=0.0, ah=1.0),
    "P": plosive(400.0, 1100.0, 2150.0, 90.0, 0.0, [Band(hz=1100.0, width=1500.0, gain=0.5)]),
    "B": plosive(200.0, 1100.0, 2150.0, 70.0, 0.25, [Band(hz=1100.0, width=1500.0, gain=0.4)]),
    "T": plosive(400.0, 1600.0, 2600.0, 80.0, 0.0, [Band(hz=4500.0, width=1500.0, gain=1.0), Band(hz=3000.0, width=1000.0, gain=0.4)]),
    "D": plosive(200.0, 1600.0, 2600.0, 60.0, 0.25, [Band(hz=4500.0, width=1500.0, gain=0.8), Band(hz=3000.0, width=1000.0, gain=0.4)]),
    "K": plosive(300.0, 1990.0, 2850.0, 85.0, 0.0, [Band(hz=2200.0, width=600.0, gain=1.0), Band(hz=3300.0, width=900.0, gain=0.4)]),
    "G": plosive(200.0, 1990.0, 2850.0, 65.0, 0.25, [Band(hz=2200.0, width=600.0, gain=0.8), Band(hz=3300.0, width=900.0, gain=0.4)]),
    "CH": plosive(300.0, 1840.0, 2750.0, 70.0, 0.0, [Band(hz=2600.0, width=400.0, gain=1.0), Band(hz=3800.0, width=600.0, gain=0.7), Band(hz=6000.0, width=1500.0, gain=0.3)]),
    "JH": plosive(200.0, 1840.0, 2750.0, 60.0, 0.3, [Band(hz=2600.0, width=400.0, gain=0.8), Band(hz=3800.0, width=600.0, gain=0.6)]),
    "_": Phone(f1=500.0, f2=1500.0, f3=2500.0, ms=60.0, kind="x", av=0.0)
};

glob VOICELESS_STOPS: list[str] = ["P", "T", "K", "CH"];

"""The levels the recogniser's tuning settled on: the voice against the
hiss, a stop's burst, breath, the upper formants' branch, and how much the
output is brightened."""
glob VOICE_LEVEL: float = 3.0;
glob HISS_LEVEL: float = 0.25;
glob BURST_LEVEL: float = 2.5;
glob BREATH_LEVEL: float = 0.4;
glob UPPER_LEVEL: float = 5.0;
glob BRIGHTEN: float = 0.3;

"""The words a sound's name says: its file's name, its underscores spaces,
its digits words, a trailing variant letter (excellent_a) dropped."""
def words_of_sound(path: str) -> str {
    stem = path.lower().split("/")[-1].rsplit(".", 1)[0];
    parts = stem.replace("-", "_").split("_");
    if len(parts) > 1 and len(parts[-1]) == 1 and parts[-1].isalpha() {
        parts = parts[:-1];
    }
    numbers = {"0": "zero", "1": "one", "2": "two", "3": "three", "4": "four", "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine", "10": "ten"};
    made: list[str] = [];
    for part in parts {
        if part in numbers {
            made.append(numbers[part]);
        } elif part {
            made.append("".join([c for c in part if c.isalpha()]));
        }
    }
    return " ".join([w for w in made if w]);
}

"""The games' words, which the letter rules would get wrong."""
glob SPOKEN: dict[str, list[str]] = {
    "one": ["W", "AH", "N"], "two": ["T", "UW"], "three": ["TH", "R", "IY"], "four": ["F", "AO", "R"],
    "five": ["F", "AY", "V"], "six": ["S", "IH", "K", "S"], "seven": ["S", "EH", "V", "AX", "N"],
    "eight": ["EY", "T"], "nine": ["N", "AY", "N"], "ten": ["T", "EH", "N"], "zero": ["Z", "IY", "R", "OW"],
    "you": ["Y", "UW"], "the": ["DH", "AX"], "fight": ["F", "AY", "T"], "excellent": ["EH", "K", "S", "AX", "L", "AX", "N", "T"],
    "impressive": ["IH", "M", "P", "R", "EH", "S", "IH", "V"], "perfect": ["P", "ER", "F", "EH", "K", "T"],
    "lead": ["L", "IY", "D"], "minute": ["M", "IH", "N", "IH", "T"], "minutes": ["M", "IH", "N", "IH", "T", "S"],
    "prepare": ["P", "R", "IY", "P", "EH", "R"], "to": ["T", "AX"], "lose": ["L", "UW", "Z"], "win": ["W", "IH", "N"],
    "humiliation": ["HH", "Y", "UW", "M", "IH", "L", "IY", "EY", "SH", "AX", "N"], "accuracy": ["AE", "K", "Y", "ER", "AX", "S", "IY"],
    "gauntlet": ["G", "AO", "N", "T", "L", "AX", "T"], "frags": ["F", "R", "AE", "G", "Z"], "sudden": ["S", "AH", "D", "AX", "N"],
    "death": ["D", "EH", "TH"], "taken": ["T", "EY", "K", "AX", "N"], "tied": ["T", "AY", "D"], "lost": ["L", "AO", "S", "T"],
    "limit": ["L", "IH", "M", "IH", "T"], "remaining": ["R", "IY", "M", "EY", "N", "IH", "NG"], "left": ["L", "EH", "F", "T"],
    "assist": ["AX", "S", "IH", "S", "T"], "defense": ["D", "IH", "F", "EH", "N", "S"], "capture": ["K", "AE", "P", "CH", "ER"],
    "flag": ["F", "L", "AE", "G"], "red": ["R", "EH", "D"], "blue": ["B", "L", "UW"], "team": ["T", "IY", "M"],
    "scores": ["S", "K", "AO", "R", "Z"], "returned": ["R", "IH", "T", "ER", "N", "D"], "your": ["Y", "AO", "R"],
    "has": ["HH", "AE", "Z"], "denied": ["D", "IH", "N", "AY", "D"], "fraglimit": ["F", "R", "AE", "G", "L", "IH", "M", "IH", "T"],
    "timelimit": ["T", "AY", "M", "L", "IH", "M", "IH", "T"], "hit": ["HH", "IH", "T"], "laugh": ["L", "AE", "F"],
    "intro": ["IH", "N", "T", "R", "OW"], "go": ["G", "OW"], "game": ["G", "EY", "M"], "over": ["OW", "V", "ER"],
    "victory": ["V", "IH", "K", "T", "ER", "IY"], "holy": ["HH", "OW", "L", "IY"], "shit": ["SH", "IH", "T"]
};

"""A word's phonemes by letter rules."""
def word_phones(word: str) -> list[str] {
    if word in SPOKEN {
        return SPOKEN[word];
    }
    out: list[str] = [];
    w = word.lower();
    i = 0;
    pairs = {"th": ["TH"], "sh": ["SH"], "ch": ["CH"], "ng": ["NG"], "ee": ["IY"], "ea": ["IY"], "oo": ["UW"], "ou": ["AW"], "ow": ["OW"], "ai": ["EY"], "ay": ["EY"], "er": ["ER"], "ir": ["ER"], "ur": ["ER"], "ar": ["AA", "R"], "or": ["AO", "R"], "ph": ["F"], "ck": ["K"], "qu": ["K", "W"], "oa": ["OW"], "ie": ["IY"], "oi": ["OY"], "oy": ["OY"]};
    singles = {"a": ["AE"], "e": ["EH"], "i": ["IH"], "o": ["AA"], "u": ["AH"], "y": ["IY"], "b": ["B"], "c": ["K"], "d": ["D"], "f": ["F"], "g": ["G"], "h": ["HH"], "j": ["JH"], "k": ["K"], "l": ["L"], "m": ["M"], "n": ["N"], "p": ["P"], "q": ["K"], "r": ["R"], "s": ["S"], "t": ["T"], "v": ["V"], "w": ["W"], "x": ["K", "S"], "z": ["Z"]};
    while i < len(w) {
        if i + 1 < len(w) and w[i:i + 2] in pairs {
            out.extend(pairs[w[i:i + 2]]);
            i += 2;
            continue;
        }
        letter = w[i];
        # A silent e at the end of a word after a consonant.
        if letter == "e" and i == len(w) - 1 and i > 0 and w[i - 1] not in "aeiou" {
            i += 1;
            continue;
        }
        if letter == "y" and i == 0 {
            out.append("Y");
        } else {
            out.extend(singles.get(letter, []));
        }
        i += 1;
    }
    return out;
}

"""A two-pole resonator (Klatt's): unity gain at 0 Hz, which in cascade
gives each formant the level a throat would; `peak` scales it to unity at
its centre instead, for the parallel branches."""
obj Resonator {
    has a: float = 1.0,
        b: float = 0.0,
        c: float = 0.0,
        y1: float = 0.0,
        y2: float = 0.0;

    def tune(hz: float, width: float, rate: int, peak: bool = False) {
        r = math.exp(-math.pi * width / float(rate));
        self.c = -r * r;
        self.b = 2.0 * r * math.cos(2.0 * math.pi * hz / float(rate));
        if peak {
            w = 2.0 * math.pi * hz / float(rate);
            self.a = (1.0 - r) * math.sqrt(1.0 - 2.0 * r * math.cos(2.0 * w) + r * r);
        } else {
            self.a = 1.0 - self.b - self.c;
        }
    }

    def run(x: float) -> float {
        y = self.a * x + self.b * self.y1 + self.c * self.y2;
        self.y2 = self.y1;
        self.y1 = y;
        return y;
    }
}

"""An antiresonator: the zero a nasal's side branch puts in the spectrum."""
obj Antiresonator {
    has a: float = 1.0,
        b: float = 0.0,
        c: float = 0.0,
        x1: float = 0.0,
        x2: float = 0.0;

    def tune(hz: float, width: float, rate: int) {
        r = math.exp(-math.pi * width / float(rate));
        c = -r * r;
        b = 2.0 * r * math.cos(2.0 * math.pi * hz / float(rate));
        a = 1.0 - b - c;
        self.a = 1.0 / a;
        self.b = -b / a;
        self.c = -c / a;
    }

    def run(x: float) -> float {
        y = self.a * x + self.b * self.x1 + self.c * self.x2;
        self.x2 = self.x1;
        self.x1 = x;
        return y;
    }
}

"""A phoneme laid out in the line: its name and its samples."""
obj Segment {
    has name: str,
        start: int,
        end: int;

    def phone -> Phone {
        return PHONES.get(self.name, PHONES["_"]);
    }
}

"""What the synthesizer does over one 5 ms frame."""
obj Frame {
    has f: list[float],
        b: list[float],
        av: float = 0.0,
        af: float = 0.0,
        ah: float = 0.0,
        nasal: float = 0.0,
        f0: float = 100.0,
        bands: list[Band] = [];
}

"""Whether the phoneme at `i` ends its word."""
def:priv word_final(phones: list[str], i: int) -> bool {
    return i == len(phones) - 1 or phones[i + 1] == "_";
}

"""The phonemes laid end to end, at their usual lengths times `pace`: a
word's first hiss held longer, its last sonorant or hiss drawn out, the
line's last vowel lengthened, a word-final voiceless stop given time for
its release."""
def:priv lay_out(phones: list[str], rate: int, pace: float) -> list[Segment] {
    made: list[Segment] = [];
    at = int(0.02 * float(rate));
    last_vowel = -1;
    for (i, name) in enumerate(phones) {
        if PHONES.get(name, PHONES["_"]).vowel() {
            last_vowel = i;
        }
    }
    for (i, name) in enumerate(phones) {
        p = PHONES.get(name, PHONES["_"]);
        ms = p.ms * pace;
        if i == last_vowel {
            ms *= 1.4;
        }
        if p.kind in ["n", "l", "f"] and word_final(phones, i) {
            ms *= 2.5;
        }
        if p.kind == "f" and (i == 0 or phones[i - 1] == "_") {
            ms *= 1.5;
        }
        if name in VOICELESS_STOPS and word_final(phones, i) {
            ms += 50.0;
        }
        count = int(ms / 1000.0 * float(rate));
        made.append(Segment(name=name, start=at, end=at + count));
        at += count;
    }
    return made;
}

"""Each 5 ms frame of the line: formants bent toward the neighbours, the
sources' levels, nasality and pitch."""
def:priv frames_of(segments: list[Segment], total: int, rate: int, pitch: float, stress_at: float) -> list[Frame] {
    step = int(0.005 * float(rate));
    made: list[Frame] = [];
    which = 0;
    blend = int(0.045 * float(rate));
    overlap = 0.05 * float(rate);
    for k in range(total // step + 2) {
        n = k * step;
        while which < len(segments) - 1 and n >= segments[which].end {
            which += 1;
        }
        seg = segments[which];
        p = seg.phone();
        before = segments[which - 1].phone() if which > 0 else PHONES["_"];
        after = segments[which + 1].phone() if which + 1 < len(segments) else PHONES["_"];
        before_name = segments[which - 1].name if which > 0 else "_";
        span = max(1, seg.end - seg.start);
        t = float(n - seg.start) / float(span);
        f = [p.f1, p.f2, p.f3];
        if p.kind == "d" {
            glide = min(1.0, max(0.0, (t - 0.25) / 0.6));
            for i in range(3) {
                f[i] = f[i] + (p.end_formant(i) - f[i]) * glide;
            }
        }
        # Halfway toward a neighbour's formants across each join.
        if which > 0 and n - seg.start < blend and before.kind != "x" {
            w = 1.0 - float(n - seg.start) / float(blend);
            for i in range(3) {
                f[i] = f[i] + (before.end_formant(i) - f[i]) * 0.5 * w;
            }
        }
        if which + 1 < len(segments) and seg.end - n < blend and after.kind != "x" {
            w = 1.0 - float(seg.end - n) / float(blend);
            nf = [after.f1, after.f2, after.f3];
            for i in range(3) {
                f[i] = f[i] + (nf[i] - f[i]) * 0.5 * w;
            }
        }
        av = p.av;
        af = p.af * HISS_LEVEL;
        ah = p.ah;
        bands = p.bands;
        nasal = 1.0 if p.kind == "n" else 0.0;
        if p.vowel() and after.kind == "n" and t > 0.5 {
            nasal = (t - 0.5) * 2.0;
        }
        if p.kind == "s" {
            # A closure, a burst, and (a word's last voiceless stop) a breath
            # through the mouth's last shape.
            burst = int(0.015 * float(rate));
            release = 0;
            if seg.name in VOICELESS_STOPS and (which == len(segments) - 1 or after.kind == "x") {
                release = int(0.05 * float(rate));
            }
            closed = seg.end - burst - release;
            if n < closed {
                af = 0.0;
            } elif n < closed + burst {
                af = BURST_LEVEL;
                av = 0.0;
            } else {
                af = 0.0;
                av = 0.0;
                ah = 0.8 * (1.0 - float(n - closed - burst) / float(max(1, release)));
            }
        }
        if before_name in VOICELESS_STOPS and p.kind in ["v", "d", "l"] and float(n - seg.start) < 0.05 * float(rate) {
            # The voice starts late after an aspirated stop, breath first.
            ah = 0.7;
            av = av * float(n - seg.start) / (0.05 * float(rate));
        }
        if p.sonorant() and before.kind == "f" and float(n - seg.start) < overlap {
            # The hiss fades out under a voice fading in.
            w = float(n - seg.start) / overlap;
            av = av * w;
            af = before.af * HISS_LEVEL * (1.0 - w);
            bands = before.bands;
        }
        if p.sonorant() and after.kind == "f" and float(seg.end - n) < overlap {
            av = av * (0.3 + 0.7 * float(seg.end - n) / overlap);
        }
        if p.kind == "f" and (which == 0 or before.kind == "x") {
            # A word's first hiss rises out of silence.
            af = af * min(1.0, float(n - seg.start) / (0.04 * float(rate))) if n >= seg.start else 0.0;
        }
        if p.sonorant() {
            nearness = float(min(n - seg.start, seg.end - n)) / (0.012 * float(rate));
            av = av * min(1.0, 0.35 + nearness);
        }
        # The pitch rises to the stress and falls to the end of the line.
        line_t = float(n) / float(max(1, total));
        f0 = pitch * (1.0 + 0.25 * line_t / max(0.01, stress_at));
        if line_t >= stress_at {
            f0 = pitch * (1.25 - 0.45 * (line_t - stress_at) / max(0.01, 1.0 - stress_at));
        }
        made.append(Frame(f=f, b=[p.b1, p.b2, p.b3], av=av, af=af, ah=ah, nasal=nasal, f0=f0, bands=bands));
    }
    return made;
}

"""Speak `phones` at `pitch` hertz, `pace` times their usual lengths."""
def speak_phones(phones: list[str], rate: int, pitch: float, pace: float, seed: int) -> Wave {
    if not phones {
        return Wave(rate=rate, samples=[0.0]);
    }
    segments = lay_out(phones, rate, pace);
    total = segments[-1].end + int(0.05 * float(rate));
    frames = frames_of(segments, total, rate, pitch, 0.3);
    step = int(0.005 * float(rate));
    cascade = [Resonator(), Resonator(), Resonator(), Resonator(), Resonator()];
    nasal_pole = Resonator();
    nasal_zero = Antiresonator();
    hisses = [Resonator(), Resonator(), Resonator()];
    # The upper formants again in parallel, fed the source's edges, so the
    # vowels keep their energy above 3 kHz.
    upper = [Resonator(), Resonator(), Resonator()];
    upper[0].tune(3500.0, 300.0, rate, True);
    upper[1].tune(4500.0, 400.0, rate, True);
    upper[2].tune(5500.0, 600.0, rate, True);
    state = mix32(seed) | 1;
    phase = 0.0;
    flow_before = 0.0;
    source_before = 0.0;
    samples: list[float] = [0.0] * total;
    for n in range(total) {
        frame = frames[min(len(frames) - 1, n // step)];
        if n % step == 0 {
            for i in range(3) {
                cascade[i].tune(frame.f[i], frame.b[i], rate);
            }
            cascade[3].tune(3300.0, 250.0, rate);
            cascade[4].tune(3750.0, 200.0, rate);
            nasal_pole.tune(270.0, 100.0, rate);
            nasal_zero.tune(270.0 + 780.0 * frame.nasal, 100.0, rate);
            for (i, band) in enumerate(frame.bands) {
                if i < 3 {
                    hisses[i].tune(band.hz, band.width, rate, True);
                }
            }
        }
        # The glottis (KLGLOTT88): open for 60% of each period, its flow's
        # slope (the radiation at the lips) the source.
        f0 = frame.f0 * (1.0 + 0.004 * math.sin(float(n) * 2.0 * math.pi * 5.0 / float(rate)));
        phase += f0 / float(rate);
        if phase >= 1.0 {
            phase -= 1.0;
        }
        airflow = 0.0;
        if phase < 0.6 {
            x = phase / 0.6;
            airflow = 6.75 * x * x * (1.0 - x);
        }
        source = (airflow - flow_before) * float(rate) / f0 * 0.05 * frame.av;
        flow_before = airflow;
        state = (state * 1103515245 + 12345) & 2147483647;
        white = float(state) / 1073741824.0 - 1.0;
        # Breath, stronger while the glottis is open.
        breath = white * (frame.ah + 0.05 * frame.av) * (1.0 if phase < 0.6 else 0.5) * BREATH_LEVEL;
        voice = nasal_zero.run(nasal_pole.run(source * VOICE_LEVEL + breath));
        for resonance in cascade {
            voice = resonance.run(voice);
        }
        rising = source - source_before;
        source_before = source;
        voice += UPPER_LEVEL * (upper[0].run(rising) - upper[1].run(rising) * 0.7 + upper[2].run(rising) * 0.4);
        hissed = 0.0;
        if frame.af > 0.0 {
            for (i, band) in enumerate(frame.bands) {
                if i < 3 {
                    hissed += hisses[i].run(white) * band.gain * (1.0 if i % 2 == 0 else -1.0);
                }
            }
            hissed = hissed * frame.af;
        }
        samples[n] = voice + hissed;
    }
    # A little brightening, as a microphone close to the mouth gives.
    for n in range(total - 1, 0, -1) {
        samples[n] = samples[n] - BRIGHTEN * samples[n - 1];
    }
    return Wave(rate=rate, samples=samples);
}

"""The phonemes of `text`, words parted by a short pause."""
def phones_of(text: str) -> list[str] {
    phones: list[str] = [];
    for word in text.split() {
        if phones {
            phones.append("_");
        }
        phones.extend(word_phones(word));
    }
    return phones;
}

"""Speak `text` in about `seconds`: at its natural pace when that fits,
slowed a little (never more than 1.1 times) to fill a longer line, quickened
to fit a shorter one."""
def speak(text: str, seconds: float, rate: int, pitch: float, seed: int) -> Wave {
    phones = phones_of(text);
    if not phones {
        return Wave(rate=rate, samples=[0.0] * max(1, int(seconds * float(rate))));
    }
    natural = speak_phones(phones, rate, pitch, 1.0, seed);
    room = seconds * 0.8;
    pace = min(1.1, max(0.5, room / max(0.05, natural.seconds())));
    if abs(pace - 1.0) < 0.05 {
        return natural;
    }
    return speak_phones(phones, rate, pitch, pace, seed);
}

"""Whether a sound's path is a line spoken by an announcer or a voice."""
def spoken(path: str) -> bool {
    lower = path.lower();
    if "/feedback/" in lower {
        leaf = lower.split("/")[-1];
        for noise in ["hit", "beep", "accuracy_", "tick"] {
            if leaf.startswith(noise) {
                return False;
            }
        }
        return True;
    }
    return "/announce/" in lower or "/teamplay/voc_" in lower or "/vo/" in lower;
}

"""The spoken line for a sound path: its words, as long as `seconds`, in
the announcer's deep voice and the hall it speaks in."""
def spoken_line(path: str, seconds: float, rate: int) -> Wave {
    seed = hash_label(16, path.lower());
    text = words_of_sound(path);
    voice = speak(text, max(0.3, seconds), rate, 72.0, seed);
    return peaked(fitted(echoed(voice, 0.09, 0.25, 3), max(0.3, seconds)), 0.9);
}
