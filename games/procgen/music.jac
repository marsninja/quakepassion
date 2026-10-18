"""Music made by code: a small sequencer playing synthesized instruments,
with a style for each game. Quake's tracks are dark ambient industrial
(drones, metal struck far off, slow swells, sparse heavy beats); Quake
II's are industrial metal (power chords on a plucked string pushed into
distortion, a driving kit); Quake III's are electronic (pads, arpeggios and
a steady beat).

A track is seeded by its name: its key, its scale, its tempo, its chords
and every part follow from that seed, so a track sounds the same each time.
A track is made to loop: it is a whole number of bars, its last bar leads
back into its first, and its tail is faded into its head."""
import math;
import from games.passion.random { hash_label, mix32 }
import from .synth { Wave, Voice, render, layered, driven, peaked, looped, fitted, muffled }

"""The notes of a scale above its root, in semitones."""
glob SCALES: dict[str, list[int]] = {
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
    "locrian": [0, 1, 3, 5, 6, 8, 10]
};

def hertz(midi: float) -> float {
    return 440.0 * math.pow(2.0, (midi - 69.0) / 12.0);
}

"""A mono buffer that notes are added into."""
obj Mix {
    has rate: int,
        samples: list[float] = [];

    def add(wave: Wave, start: float, gain: float) {
        begin = int(start * float(self.rate));
        source = wave.samples;
        for k in range(len(source)) {
            at = begin + k;
            if at >= len(self.samples) {
                break;
            }
            self.samples[at] += source[k] * gain;
        }
    }

    """Add a wave wrapping round the end (so a note held over the loop's end
    sounds again at its start)."""
    def add_wrapped(wave: Wave, start: float, gain: float) {
        begin = int(start * float(self.rate));
        count = len(self.samples);
        if count == 0 {
            return;
        }
        for k in range(len(wave.samples)) {
            self.samples[(begin + k) % count] += wave.samples[k] * gain;
        }
    }
}

"""A plucked string (Karplus-Strong): a burst of noise passed round a delay
the length of one period, softened each time round."""
def pluck(pitch: float, seconds: float, rate: int, seed: int, damping: float = 0.996) -> Wave {
    period = max(2, int(float(rate) / max(20.0, pitch)));
    line: list[float] = [];
    state = mix32(seed) | 1;
    for k in range(period) {
        state = (state * 1103515245 + 12345) & 2147483647;
        line.append(float(state) / 1073741824.0 - 1.0);
    }
    count = int(seconds * float(rate));
    samples: list[float] = [0.0] * count;
    at = 0;
    for n in range(count) {
        nxt = (at + 1) % period;
        value = line[at];
        line[at] = (line[at] + line[nxt]) * 0.5 * damping;
        samples[n] = value;
        at = nxt;
    }
    return Wave(rate=rate, samples=samples);
}

"""A room for a mix: four combs and an all-pass, as Schroeder's reverb."""
def reverb(source: list[float], rate: int, size: float, wet: float) -> list[float] {
    delays = [int(0.0297 * size * float(rate)), int(0.0371 * size * float(rate)), int(0.0411 * size * float(rate)), int(0.0437 * size * float(rate))];
    out: list[float] = [0.0] * len(source);
    for delay in delays {
        line: list[float] = [0.0] * max(1, delay);
        at = 0;
        for n in range(len(source)) {
            echo = line[at];
            line[at] = source[n] + echo * 0.78;
            out[n] += echo * 0.25;
            at = (at + 1) % len(line);
        }
    }
    pass_delay = max(1, int(0.005 * float(rate)));
    line2: list[float] = [0.0] * pass_delay;
    at2 = 0;
    mixed: list[float] = [0.0] * len(source);
    for n in range(len(source)) {
        held = line2[at2];
        value = out[n] + held * 0.5;
        line2[at2] = value;
        mixed[n] = source[n] * (1.0 - wet) + (held - value * 0.5) * wet;
        at2 = (at2 + 1) % pass_delay;
    }
    return mixed;
}

"""What a track plays from: its seed, key, scale, tempo and chords."""
obj Score {
    has seed: int,
        tonic: int,
        scale: list[int],
        tempo: float,
        bars: int,
        chords: list[int],
        rate: int;

    def beat -> float {
        return 60.0 / self.tempo;
    }

    def bar -> float {
        return self.beat() * 4.0;
    }

    """The note `degree` steps up the scale from the chord's root, in
    `octave`."""
    def note(chord: int, degree: int, octave: int) -> float {
        step = chord + degree;
        count = len(self.scale);
        shift = step // count;
        return float(self.tonic + 12 * (octave + shift) + self.scale[step % count]);
    }

    def unit(label: str, index: int) -> float {
        return float(mix32(self.seed ^ hash_label(index, label))) / 4294967296.0;
    }
}

def score_for(name: str, game: str, seconds: float, rate: int) -> Score {
    seed = hash_label(13, game + ":" + name.lower());
    scales = ["phrygian", "minor", "locrian"] if game == "q1" else (["minor", "phrygian", "harmonic"] if game == "q2" else ["minor", "dorian", "harmonic"]);
    scale = SCALES[scales[mix32(seed) % len(scales)]];
    tempo = [60.0, 72.0, 80.0][mix32(seed + 1) % 3] if game == "q1" else ([126.0, 138.0, 148.0][mix32(seed + 1) % 3] if game == "q2" else [104.0, 112.0, 124.0][mix32(seed + 1) % 3]);
    tonic = 33 + mix32(seed + 2) % 12;
    bar = 240.0 / tempo;
    bars = max(4, int(seconds / bar));
    # Four chords, as degrees of the scale, round which the track turns.
    progressions = [[0, 5, 3, 4], [0, 3, 5, 4], [0, 1, 0, 6], [0, 6, 5, 6], [0, 4, 3, 1]];
    chords = progressions[mix32(seed + 3) % len(progressions)];
    return Score(seed=seed, tonic=tonic, scale=scale, tempo=tempo, bars=bars, chords=chords, rate=rate);
}

def:priv kick(rate: int, seed: int) -> Wave {
    return render(Voice(wave="sine", pitch=110.0, slide=-4.0, attack=0.0, sustain=0.02, punch=0.6, decay=0.3, volume=1.0, seed=seed), rate);
}

def:priv snare(rate: int, seed: int) -> Wave {
    body = render(Voice(wave="triangle", pitch=190.0, slide=-1.0, attack=0.0, sustain=0.01, decay=0.12, volume=0.6, seed=seed), rate);
    rattle = render(Voice(wave="white", pitch=1000.0, attack=0.0, sustain=0.02, decay=0.18, highpass=1500.0, volume=0.7, seed=seed + 1), rate);
    return layered([body, rattle], [1.0, 1.0], [0.0, 0.0], rate);
}

def:priv hat(rate: int, seed: int, open_hat: bool) -> Wave {
    return render(Voice(wave="white", pitch=1000.0, attack=0.0, sustain=0.005, decay=0.25 if open_hat else 0.05, highpass=6000.0, volume=0.35, seed=seed), rate);
}

def:priv clang(rate: int, seed: int, pitch: float) -> Wave {
    return render(Voice(wave="metal", pitch=pitch, attack=0.0, sustain=0.02, decay=1.5, volume=0.6, seed=seed), rate);
}

"""Quake: drones under the chords, metal struck far off, swells, and a slow
heavy beat that comes and goes."""
def:priv dark_ambient(score: Score, mix: Mix) {
    bar = score.bar();
    for b in range(score.bars) {
        chord = score.chords[b % len(score.chords)];
        start = float(b) * bar;
        for (degree, octave, gain) in [(0, 0, 0.35), (4, 0, 0.18), (0, 1, 0.12)] {
            pad = Voice(
                wave="saw", pitch=hertz(score.note(chord, degree, octave)), vibrato_depth=0.003, vibrato_rate=0.3,
                attack=bar * 0.4, sustain=bar * 0.5, decay=bar * 0.6, lowpass=300.0 + 400.0 * score.unit("lp", b),
                resonance=0.3, volume=1.0, seed=score.seed + b * 7 + degree
            );
            mix.add_wrapped(render(pad, score.rate), start, gain);
        }
        if score.unit("clang", b) < 0.5 {
            mix.add_wrapped(clang(score.rate, score.seed + b, hertz(score.note(chord, 2, 2))), start + bar * score.unit("clangat", b), 0.25);
        }
        if b % 8 >= 4 {
            for beat in range(4) {
                if beat == 0 or beat == 2 {
                    mix.add_wrapped(kick(score.rate, score.seed + b * 4 + beat), start + float(beat) * score.beat(), 0.5);
                } else {
                    mix.add_wrapped(driven(snare(score.rate, score.seed + b * 4 + beat), 2.0), start + float(beat) * score.beat(), 0.25);
                }
            }
        }
        if b % 4 == 3 {
            swell = Voice(wave="pink", pitch=100.0, attack=bar * 0.9, sustain=0.05, decay=0.2, lowpass=1200.0, lowpass_sweep=2.0, volume=0.6, seed=score.seed + b);
            mix.add_wrapped(render(swell, score.rate), start, 0.3);
        }
    }
}

"""Quake II: palm-muted power chords on a distorted plucked string, a bass
under them and a driving kit."""
def:priv industrial_metal(score: Score, mix: Mix) {
    bar = score.bar();
    eighth = score.beat() * 0.5;
    riff: list[int] = [];
    for k in range(8) {
        riff.append(1 if score.unit("riff", k) < 0.65 or k == 0 else 0);
    }
    for b in range(score.bars) {
        chord = score.chords[b % len(score.chords)];
        start = float(b) * bar;
        for k in range(8) {
            if riff[k] == 0 {
                continue;
            }
            at = start + float(k) * eighth;
            base = hertz(score.note(chord, 0, 1));
            low = pluck(base, eighth * 0.9, score.rate, score.seed + b * 8 + k, 0.99);
            fifth = pluck(base * 1.4983, eighth * 0.9, score.rate, score.seed + b * 8 + k + 1000, 0.99);
            chug = driven(layered([low, fifth], [1.0, 0.8], [0.0, 0.0], score.rate), 6.0);
            mix.add_wrapped(muffled(chug, 3500.0), at, 0.22);
            bass = Voice(wave="saw", pitch=base * 0.5, attack=0.0, sustain=eighth * 0.6, decay=eighth * 0.3, lowpass=500.0, volume=1.0, seed=score.seed + k);
            mix.add_wrapped(render(bass, score.rate), at, 0.25);
        }
        for k in range(8) {
            at = start + float(k) * eighth;
            if k % 4 == 0 or (k == 7 and b % 2 == 1) {
                mix.add_wrapped(kick(score.rate, score.seed + k), at, 0.7);
            }
            if k % 4 == 2 {
                mix.add_wrapped(snare(score.rate, score.seed + k + b), at, 0.5);
            }
            mix.add_wrapped(hat(score.rate, score.seed + k * 3 + b, k % 2 == 1 and b % 4 == 3), at, 0.4);
        }
    }
}

"""Quake III: pads holding the chords, an arpeggio running over them, a
bass line and a four-to-the-floor beat."""
def:priv electronic(score: Score, mix: Mix) {
    bar = score.bar();
    sixteenth = score.beat() * 0.25;
    for b in range(score.bars) {
        chord = score.chords[b % len(score.chords)];
        start = float(b) * bar;
        for degree in [0, 2, 4] {
            pad = Voice(wave="saw", pitch=hertz(score.note(chord, degree, 1)), vibrato_depth=0.004, vibrato_rate=5.0, attack=bar * 0.2, sustain=bar * 0.7, decay=bar * 0.3, lowpass=1400.0, resonance=0.2, volume=1.0, seed=score.seed + degree + b);
            mix.add_wrapped(render(pad, score.rate), start, 0.12);
        }
        for k in range(16) {
            degree = [0, 2, 4, 7, 4, 2, 0, 4][k % 8];
            arp = Voice(wave="square", pitch=hertz(score.note(chord, degree, 2)), duty=0.3, attack=0.002, sustain=sixteenth * 0.4, decay=sixteenth * 0.8, lowpass=2500.0 + 1500.0 * math.sin(float(b * 16 + k) * 0.1), volume=1.0, seed=score.seed + k);
            mix.add_wrapped(render(arp, score.rate), start + float(k) * sixteenth, 0.08 if b >= 2 else 0.0);
        }
        for beat in range(4) {
            at = start + float(beat) * score.beat();
            mix.add_wrapped(kick(score.rate, score.seed + beat), at, 0.6);
            mix.add_wrapped(hat(score.rate, score.seed + beat + b, True), at + score.beat() * 0.5, 0.3);
            if beat % 2 == 1 {
                mix.add_wrapped(snare(score.rate, score.seed + beat + b), at, 0.35);
            }
            bass = Voice(wave="saw", pitch=hertz(score.note(chord, 0, 0)), attack=0.005, sustain=score.beat() * 0.3, decay=score.beat() * 0.3, lowpass=700.0, resonance=0.4, volume=1.0, seed=score.seed + beat);
            mix.add_wrapped(render(bass, score.rate), at + score.beat() * 0.5, 0.3);
        }
    }
}

"""A track called `name` for `game`, about `seconds` long (a whole number of
bars), looping."""
def make_track(name: str, game: str, seconds: float, rate: int = 22050) -> Wave {
    score = score_for(name, game, seconds, rate);
    length = float(score.bars) * score.bar();
    mix = Mix(rate=rate, samples=[0.0] * int(length * float(rate)));
    if game == "q1" {
        dark_ambient(score, mix);
        mix.samples = reverb(mix.samples, rate, 2.5, 0.45);
    } elif game == "q2" {
        industrial_metal(score, mix);
        mix.samples = reverb(mix.samples, rate, 1.0, 0.15);
    } else {
        electronic(score, mix);
        mix.samples = reverb(mix.samples, rate, 1.5, 0.25);
    }
    return peaked(Wave(rate=rate, samples=mix.samples), 0.85);
}
