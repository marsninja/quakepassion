"""Speech made by code: the words the games' announcers say ("Fight!",
"Excellent", "One", "You win"), spoken by a formant synthesizer.

A word is read from the sound's name, turned into phonemes by a handful of
English letter rules (enough for the games' words, not for English), and
each phoneme spoken as the throat and mouth would: a voice (a train of
glottal pulses at a pitch that falls through the line) shaped by three
resonances that glide from one phoneme's to the next; noise for the hissed
sounds; a stop and a burst for the plosives. It is robotic, as the issue
said it would be."""
import math;
import from games.passion.random { hash_label, mix32 }
import from .synth { Wave, peaked, echoed, fitted }

"""A phoneme: its three resonances (hertz), how voiced and how noisy it is,
how long it lasts (a part of a vowel's length), and whether it is a stop."""
obj Phone {
    has f1: float,
        f2: float,
        f3: float,
        voiced: float = 1.0,
        noise: float = 0.0,
        noise_band: float = 4000.0,
        length: float = 1.0,
        stop: bool = False;
}

glob PHONES: dict[str, Phone] = {
    "AA": Phone(f1=730.0, f2=1090.0, f3=2440.0),
    "AE": Phone(f1=660.0, f2=1720.0, f3=2410.0),
    "AH": Phone(f1=520.0, f2=1190.0, f3=2390.0),
    "AO": Phone(f1=570.0, f2=840.0, f3=2410.0),
    "EH": Phone(f1=530.0, f2=1840.0, f3=2480.0),
    "ER": Phone(f1=490.0, f2=1350.0, f3=1690.0),
    "IH": Phone(f1=390.0, f2=1990.0, f3=2550.0),
    "IY": Phone(f1=270.0, f2=2290.0, f3=3010.0),
    "UH": Phone(f1=440.0, f2=1020.0, f3=2240.0),
    "UW": Phone(f1=300.0, f2=870.0, f3=2240.0),
    "OW": Phone(f1=480.0, f2=900.0, f3=2400.0),
    "M": Phone(f1=280.0, f2=1000.0, f3=2200.0, voiced=0.6, length=0.6),
    "N": Phone(f1=280.0, f2=1500.0, f3=2500.0, voiced=0.6, length=0.6),
    "NG": Phone(f1=280.0, f2=2300.0, f3=2750.0, voiced=0.6, length=0.6),
    "L": Phone(f1=360.0, f2=1300.0, f3=2900.0, voiced=0.8, length=0.5),
    "R": Phone(f1=420.0, f2=1300.0, f3=1600.0, voiced=0.8, length=0.5),
    "W": Phone(f1=300.0, f2=610.0, f3=2200.0, voiced=0.8, length=0.45),
    "Y": Phone(f1=260.0, f2=2070.0, f3=3020.0, voiced=0.8, length=0.45),
    "S": Phone(f1=320.0, f2=1400.0, f3=2600.0, voiced=0.0, noise=0.7, noise_band=6000.0, length=0.7),
    "Z": Phone(f1=320.0, f2=1400.0, f3=2600.0, voiced=0.4, noise=0.5, noise_band=5500.0, length=0.6),
    "SH": Phone(f1=320.0, f2=1700.0, f3=2600.0, voiced=0.0, noise=0.7, noise_band=3000.0, length=0.7),
    "F": Phone(f1=320.0, f2=1400.0, f3=2600.0, voiced=0.0, noise=0.4, noise_band=7000.0, length=0.6),
    "V": Phone(f1=320.0, f2=1400.0, f3=2600.0, voiced=0.5, noise=0.3, noise_band=6000.0, length=0.5),
    "TH": Phone(f1=320.0, f2=1400.0, f3=2600.0, voiced=0.0, noise=0.35, noise_band=6500.0, length=0.55),
    "H": Phone(f1=500.0, f2=1500.0, f3=2500.0, voiced=0.0, noise=0.4, noise_band=2000.0, length=0.45),
    "P": Phone(f1=400.0, f2=1100.0, f3=2150.0, voiced=0.0, noise=0.6, noise_band=1500.0, length=0.4, stop=True),
    "B": Phone(f1=400.0, f2=1100.0, f3=2150.0, voiced=0.3, noise=0.4, noise_band=1200.0, length=0.35, stop=True),
    "T": Phone(f1=400.0, f2=1600.0, f3=2600.0, voiced=0.0, noise=0.7, noise_band=4500.0, length=0.4, stop=True),
    "D": Phone(f1=400.0, f2=1600.0, f3=2600.0, voiced=0.3, noise=0.5, noise_band=3500.0, length=0.35, stop=True),
    "K": Phone(f1=300.0, f2=1990.0, f3=2850.0, voiced=0.0, noise=0.6, noise_band=2500.0, length=0.4, stop=True),
    "G": Phone(f1=300.0, f2=1990.0, f3=2850.0, voiced=0.3, noise=0.4, noise_band=2000.0, length=0.35, stop=True),
    "CH": Phone(f1=320.0, f2=1700.0, f3=2600.0, voiced=0.0, noise=0.8, noise_band=3200.0, length=0.55, stop=True),
    "J": Phone(f1=320.0, f2=1700.0, f3=2600.0, voiced=0.4, noise=0.6, noise_band=3000.0, length=0.5, stop=True),
    "_": Phone(f1=500.0, f2=1500.0, f3=2500.0, voiced=0.0, noise=0.0, length=0.6)
};

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

"""A few whole words the letter rules get wrong."""
glob SPOKEN: dict[str, list[str]] = {
    "one": ["W", "AH", "N"], "two": ["T", "UW"], "three": ["TH", "R", "IY"], "four": ["F", "AO", "R"],
    "five": ["F", "AA", "IY", "V"], "six": ["S", "IH", "K", "S"], "seven": ["S", "EH", "V", "AH", "N"],
    "eight": ["EH", "IY", "T"], "nine": ["N", "AA", "IY", "N"], "ten": ["T", "EH", "N"], "zero": ["Z", "IY", "R", "OW"],
    "you": ["Y", "UW"], "the": ["TH", "AH"], "fight": ["F", "AA", "IY", "T"], "excellent": ["EH", "K", "S", "EH", "L", "AH", "N", "T"],
    "impressive": ["IH", "M", "P", "R", "EH", "S", "IH", "V"], "perfect": ["P", "ER", "F", "EH", "K", "T"],
    "lead": ["L", "IY", "D"], "minute": ["M", "IH", "N", "IH", "T"], "minutes": ["M", "IH", "N", "IH", "T", "S"],
    "prepare": ["P", "R", "IY", "P", "EH", "R"], "to": ["T", "UW"], "lose": ["L", "UW", "Z"], "win": ["W", "IH", "N"],
    "humiliation": ["H", "Y", "UW", "M", "IH", "L", "IY", "EH", "IY", "SH", "AH", "N"], "accuracy": ["AE", "K", "Y", "ER", "AH", "S", "IY"],
    "gauntlet": ["G", "AO", "N", "T", "L", "EH", "T"], "frags": ["F", "R", "AE", "G", "Z"], "sudden": ["S", "AH", "D", "EH", "N"],
    "death": ["D", "EH", "TH"], "taken": ["T", "EH", "IY", "K", "EH", "N"], "tied": ["T", "AA", "IY", "D"], "lost": ["L", "AO", "S", "T"],
    "limit": ["L", "IH", "M", "IH", "T"], "remaining": ["R", "IY", "M", "EH", "IY", "N", "IH", "NG"], "left": ["L", "EH", "F", "T"]
};

"""A word's phonemes by letter rules."""
def word_phones(word: str) -> list[str] {
    if word in SPOKEN {
        return SPOKEN[word];
    }
    out: list[str] = [];
    w = word.lower();
    i = 0;
    pairs = {"th": ["TH"], "sh": ["SH"], "ch": ["CH"], "ng": ["NG"], "ee": ["IY"], "ea": ["IY"], "oo": ["UW"], "ou": ["AA", "UW"], "ow": ["AA", "UW"], "ai": ["EH", "IY"], "ay": ["EH", "IY"], "er": ["ER"], "ir": ["ER"], "ur": ["ER"], "ar": ["AA", "R"], "or": ["AO", "R"], "ph": ["F"], "ck": ["K"], "qu": ["K", "W"], "oa": ["OW"], "ie": ["IY"]};
    singles = {"a": ["AE"], "e": ["EH"], "i": ["IH"], "o": ["AO"], "u": ["AH"], "y": ["IY"], "b": ["B"], "c": ["K"], "d": ["D"], "f": ["F"], "g": ["G"], "h": ["H"], "j": ["J"], "k": ["K"], "l": ["L"], "m": ["M"], "n": ["N"], "p": ["P"], "q": ["K"], "r": ["R"], "s": ["S"], "t": ["T"], "v": ["V"], "w": ["W"], "x": ["K", "S"], "z": ["Z"]};
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

"""A two-pole resonator's coefficients for a centre and a bandwidth."""
def:priv resonator(freq: float, band: float, rate: int) -> tuple[float, float, float] {
    r = math.exp(-math.pi * band / float(rate));
    c = -r * r;
    b = 2.0 * r * math.cos(2.0 * math.pi * freq / float(rate));
    a = 1.0 - b - c;
    return (a, b, c);
}

"""Speak `text`: phonemes laid end to end, `seconds` long in all, a voice at
`pitch` hertz falling through the line."""
def speak(text: str, seconds: float, rate: int, pitch: float, seed: int) -> Wave {
    phones: list[str] = [];
    for word in text.split() {
        if phones {
            phones.append("_");
        }
        phones.extend(word_phones(word));
    }
    if not phones {
        return Wave(rate=rate, samples=[0.0] * max(1, int(seconds * float(rate))));
    }
    units = 0.0;
    for name in phones {
        units += PHONES.get(name, PHONES["_"]).length;
    }
    speaking = max(0.2, seconds * 0.85);
    unit = speaking / max(0.5, units);
    count = int(seconds * float(rate));
    samples: list[float] = [0.0] * count;
    # Each phoneme's start and end, in samples.
    starts: list[int] = [];
    ends: list[int] = [];
    at = int(seconds * 0.05 * float(rate));
    for name in phones {
        length = int(PHONES.get(name, PHONES["_"]).length * unit * float(rate));
        starts.append(at);
        ends.append(min(count, at + length));
        at += length;
    }
    state = mix32(seed) | 1;
    phase = 0.0;
    y1 = [0.0, 0.0, 0.0];
    y2 = [0.0, 0.0, 0.0];
    n1 = 0.0;
    n2 = 0.0;
    which = 0;
    for n in range(count) {
        while which < len(phones) - 1 and n >= ends[which] {
            which += 1;
        }
        if n < starts[0] or n >= ends[len(phones) - 1] {
            continue;
        }
        phone = PHONES.get(phones[which], PHONES["_"]);
        span = max(1, ends[which] - starts[which]);
        t = float(n - starts[which]) / float(span);
        # Glide toward the next phoneme over the last third of this one.
        following = PHONES.get(phones[which + 1], phone) if which + 1 < len(phones) else phone;
        glide = max(0.0, (t - 0.66) / 0.34);
        f = [
            phone.f1 + (following.f1 - phone.f1) * glide, phone.f2 + (following.f2 - phone.f2) * glide,
            phone.f3 + (following.f3 - phone.f3) * glide
        ];
        line_t = float(n) / float(count);
        f0 = pitch * (1.15 - 0.3 * line_t) * (1.0 + 0.01 * math.sin(float(n) * 0.002));
        phase += f0 / float(rate);
        # A glottal pulse: a sharp rise and a slow fall each period.
        frac = phase - math.floor(phase);
        source = (frac * 2.0 - 1.0) if frac < 0.9 else (1.0 - (frac - 0.9) * 20.0);
        voiced = source * phone.voiced;
        state = (state * 1103515245 + 12345) & 2147483647;
        white = float(state) / 1073741824.0 - 1.0;
        # Noise in the hissed sounds, a burst at the start of a stop.
        noise = white * phone.noise;
        if phone.stop {
            noise = noise * (1.0 if t > 0.55 else 0.0) * max(0.0, 1.0 - (t - 0.55) * 3.0);
            voiced = voiced * (0.2 if t < 0.55 else 0.6);
        }
        a = 1.0 - math.exp(-2.0 * math.pi * phone.noise_band / float(rate));
        n1 += (noise - n1) * a;
        n2 += (n1 - n2) * a;
        hiss = noise - n2 * 0.5;
        sample = 0.0;
        for k in range(3) {
            (ca, cb, cc) = resonator(f[k], 60.0 + 40.0 * float(k), rate);
            out = ca * voiced + cb * y1[k] + cc * y2[k];
            y2[k] = y1[k];
            y1[k] = out;
            sample += out * [1.0, 0.6, 0.35][k];
        }
        # Fade each phoneme in and out a little so the joins do not click.
        taper = min(1.0, min(t, 1.0 - t) * 12.0 + 0.3);
        samples[n] = (sample * 0.4 + hiss * 0.6) * taper;
    }
    return Wave(rate=rate, samples=samples);
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

"""The spoken line for a sound path: its words, as long as `seconds`."""
def spoken_line(path: str, seconds: float, rate: int) -> Wave {
    seed = hash_label(16, path.lower());
    text = words_of_sound(path);
    voice = speak(text, max(0.3, seconds), rate, 95.0, seed);
    return peaked(fitted(echoed(voice, 0.09, 0.25, 3), max(0.3, seconds)), 0.9);
}
