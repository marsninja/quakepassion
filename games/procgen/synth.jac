"""Sounds made from numbers, in the manner of the small effect synthesizers
(sfxr and its kin): one oscillator whose pitch slides and wobbles, shaped by
an envelope, passed through filters that can sweep, and then echoed,
distorted, layered and joined with others.

A `Wave` is one channel of samples from -1 to 1 at its own rate. Every
sound is a pure function of its numbers and seed."""
import math;
import from games.passion.random { mix32 }

obj Wave {
    has rate: int = 22050,
        samples: list[float] = [];

    def seconds -> float {
        return float(len(self.samples)) / float(max(1, self.rate));
    }
}

"""One synthesized voice: its waveform ("sine", "square", "saw", "triangle",
"noise", "pink", "metal"), its pitch and how the pitch moves, its envelope
and its filters. Times are in seconds, pitches in hertz; a slide is how many
octaves a second the pitch climbs (negative falls)."""
obj Voice {
    has wave: str = "square",
        pitch: float = 440.0,
        slide: float = 0.0,
        slide_accel: float = 0.0,
        floor_pitch: float = 20.0,
        vibrato_depth: float = 0.0,
        vibrato_rate: float = 6.0,
        duty: float = 0.5,
        duty_sweep: float = 0.0,
        attack: float = 0.0,
        sustain: float = 0.1,
        punch: float = 0.0,
        decay: float = 0.2,
        lowpass: float = 0.0,
        lowpass_sweep: float = 0.0,
        resonance: float = 0.0,
        highpass: float = 0.0,
        arp_time: float = 0.0,
        arp_ratio: float = 1.0,
        repeat: float = 0.0,
        volume: float = 0.8,
        seed: int = 1;

    def length -> float {
        return self.attack + self.sustain + self.decay;
    }
}

"""The envelope at time t: up over the attack, held (with a punch that
falls away) over the sustain, down over the decay."""
def:priv envelope(voice: Voice, t: float) -> float {
    if t < voice.attack {
        return t / max(1.0e-5, voice.attack);
    }
    t -= voice.attack;
    if t < voice.sustain {
        return 1.0 + voice.punch * (1.0 - t / max(1.0e-5, voice.sustain));
    }
    t -= voice.sustain;
    if t < voice.decay {
        k = 1.0 - t / max(1.0e-5, voice.decay);
        return k * k;
    }
    return 0.0;
}

"""A voice played at `rate` samples a second."""
def render(voice: Voice, rate: int = 22050) -> Wave {
    count = int(voice.length() * float(rate));
    samples: list[float] = [0.0] * count;
    phase = 0.0;
    state = mix32(voice.seed) | 1;
    noise_value = 0.0;
    pink_b0 = 0.0;
    pink_b1 = 0.0;
    pink_b2 = 0.0;
    # Filter states: a two-pole low pass (state variable) and a one-pole high pass.
    low = 0.0;
    band = 0.0;
    high_last_in = 0.0;
    high_out = 0.0;
    dt = 1.0 / float(rate);
    last_cycle = -1;
    for n in range(count) {
        t = float(n) * dt;
        local_t = t;
        if voice.repeat > 0.0 {
            local_t = t % voice.repeat;
        }
        octaves = voice.slide * local_t + 0.5 * voice.slide_accel * local_t * local_t;
        pitch = voice.pitch * math.pow(2.0, octaves);
        if voice.arp_time > 0.0 and local_t >= voice.arp_time {
            pitch *= voice.arp_ratio;
        }
        if voice.vibrato_depth > 0.0 {
            pitch *= 1.0 + voice.vibrato_depth * math.sin(2.0 * math.pi * voice.vibrato_rate * t);
        }
        pitch = max(voice.floor_pitch, min(float(rate) * 0.45, pitch));
        phase += pitch * dt;
        cycle = int(phase);
        frac = phase - math.floor(phase);
        if cycle != last_cycle {
            # A new cycle: noise takes a new value, as sfxr's did.
            state = (state * 1103515245 + 12345) & 2147483647;
            noise_value = float(state) / 1073741824.0 - 1.0;
            last_cycle = cycle;
        }
        sample = 0.0;
        if voice.wave == "sine" {
            sample = math.sin(2.0 * math.pi * frac);
        } elif voice.wave == "square" {
            duty = max(0.05, min(0.95, voice.duty + voice.duty_sweep * local_t));
            sample = 1.0 if frac < duty else -1.0;
        } elif voice.wave == "saw" {
            sample = 2.0 * frac - 1.0;
        } elif voice.wave == "triangle" {
            sample = 4.0 * frac - 1.0 if frac < 0.5 else 3.0 - 4.0 * frac;
        } elif voice.wave == "noise" {
            sample = noise_value;
        } elif voice.wave == "white" {
            state = (state * 1103515245 + 12345) & 2147483647;
            sample = float(state) / 1073741824.0 - 1.0;
        } elif voice.wave == "pink" {
            state = (state * 1103515245 + 12345) & 2147483647;
            white = float(state) / 1073741824.0 - 1.0;
            pink_b0 = 0.99765 * pink_b0 + white * 0.0990460;
            pink_b1 = 0.96300 * pink_b1 + white * 0.2965164;
            pink_b2 = 0.57000 * pink_b2 + white * 1.0526913;
            sample = (pink_b0 + pink_b1 + pink_b2 + white * 0.1848) * 0.25;
        } elif voice.wave == "metal" {
            # Inharmonic partials, as struck metal rings.
            sample = (
                math.sin(2.0 * math.pi * frac) + 0.6 * math.sin(2.0 * math.pi * phase * 2.76)
                    + 0.4 * math.sin(2.0 * math.pi * phase * 5.40) + 0.25 * math.sin(2.0 * math.pi * phase * 8.93)
            ) * 0.45;
        }
        if voice.lowpass > 0.0 {
            cutoff = max(20.0, voice.lowpass * math.pow(2.0, voice.lowpass_sweep * t));
            # The state-variable filter is stable only well below a sixth
            # of the rate; above that it is left open.
            if cutoff < float(rate) / 6.5 {
                f = 2.0 * math.sin(math.pi * cutoff / float(rate));
                q = 1.0 - max(0.0, min(0.95, voice.resonance));
                low += f * band;
                hp = sample - low - q * band;
                band += f * hp;
                sample = low;
            } else {
                low = sample;
                band = 0.0;
            }
        }
        if voice.highpass > 0.0 {
            k = 1.0 / (1.0 + 2.0 * math.pi * voice.highpass / float(rate));
            high_out = k * (high_out + sample - high_last_in);
            high_last_in = sample;
            sample = high_out;
        }
        samples[n] = sample * envelope(voice, t) * voice.volume;
    }
    return Wave(rate=rate, samples=samples);
}

"""Waves laid over each other, each `gains[i]` loud and starting
`starts[i]` seconds in."""
def layered(waves: list[Wave], gains: list[float], starts: list[float], rate: int = 22050) -> Wave {
    length = 0;
    for i in range(len(waves)) {
        begin = int((starts[i] if i < len(starts) else 0.0) * float(rate));
        length = max(length, begin + len(waves[i].samples));
    }
    samples: list[float] = [0.0] * length;
    for i in range(len(waves)) {
        begin = int((starts[i] if i < len(starts) else 0.0) * float(rate));
        gain = gains[i] if i < len(gains) else 1.0;
        source = waves[i].samples;
        for k in range(len(source)) {
            samples[begin + k] += source[k] * gain;
        }
    }
    return Wave(rate=rate, samples=samples);
}

"""The wave with echoes: each `delay` seconds later and `feedback` as loud
as the one before, for `count` of them."""
def echoed(source: Wave, delay: float, feedback: float, count: int) -> Wave {
    step = int(delay * float(source.rate));
    length = len(source.samples) + step * count;
    samples: list[float] = [0.0] * length;
    gain = 1.0;
    for e in range(count + 1) {
        begin = step * e;
        for k in range(len(source.samples)) {
            samples[begin + k] += source.samples[k] * gain;
        }
        gain *= feedback;
    }
    return Wave(rate=source.rate, samples=samples);
}

"""The wave driven into soft clipping: `drive` 1 leaves it nearly as it was,
more squares it off (as a gun's report or a growl is)."""
def driven(source: Wave, drive: float) -> Wave {
    norm = math.tanh(max(0.1, drive));
    return Wave(rate=source.rate, samples=[math.tanh(sample * drive) / norm for sample in source.samples]);
}

"""The wave scaled so its loudest sample is `peak`."""
def peaked(source: Wave, peak: float = 0.95) -> Wave {
    loudest = 0.0;
    for sample in source.samples {
        loudest = max(loudest, abs(sample));
    }
    if loudest <= 1.0e-6 {
        return source;
    }
    k = peak / loudest;
    return Wave(rate=source.rate, samples=[sample * k for sample in source.samples]);
}

"""The wave made to loop: its end faded into its beginning over `fade`
seconds, so the join is not heard."""
def looped(source: Wave, fade: float) -> Wave {
    span = min(len(source.samples) // 2, int(fade * float(source.rate)));
    if span <= 0 {
        return source;
    }
    body = len(source.samples) - span;
    samples = source.samples[:body];
    for k in range(span) {
        t = float(k) / float(span);
        samples[k] = samples[k] * t + source.samples[body + k] * (1.0 - t);
    }
    return Wave(rate=source.rate, samples=samples);
}

"""The wave cut or padded with silence to `seconds` long."""
def fitted(source: Wave, seconds: float) -> Wave {
    count = max(1, int(seconds * float(source.rate)));
    if len(source.samples) >= count {
        return Wave(rate=source.rate, samples=source.samples[:count]);
    }
    return Wave(rate=source.rate, samples=source.samples + [0.0] * (count - len(source.samples)));
}

"""The wave at another rate, read between its samples."""
def resampled(source: Wave, rate: int) -> Wave {
    if rate == source.rate or not source.samples {
        return source;
    }
    count = int(float(len(source.samples)) * float(rate) / float(source.rate));
    step = float(source.rate) / float(rate);
    samples: list[float] = [0.0] * count;
    last = len(source.samples) - 1;
    for k in range(count) {
        at = float(k) * step;
        i = min(last, int(at));
        j = min(last, i + 1);
        t = at - float(i);
        samples[k] = source.samples[i] * (1.0 - t) + source.samples[j] * t;
    }
    return Wave(rate=rate, samples=samples);
}

"""A one-pole low pass over a whole wave (`cutoff` hertz)."""
def muffled(source: Wave, cutoff: float) -> Wave {
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / float(source.rate));
    held = 0.0;
    samples: list[float] = [0.0] * len(source.samples);
    for k in range(len(source.samples)) {
        held += (source.samples[k] - held) * a;
        samples[k] = held;
    }
    return Wave(rate=source.rate, samples=samples);
}
