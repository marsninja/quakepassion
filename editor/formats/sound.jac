"""Sounds brought in and made what the games play. A sound is a WAV file of
plain samples; the games want one channel, 8 or 16 bits a sample, at 11025
or 22050 samples a second (Quake mixes at 11025, the later two at 22050).
A sound from elsewhere is mixed down to one channel, played at another rate
by measuring between its samples, and written at another width."""
import struct;
import from engine.formats.wav { WavPcm, parse_wav_pcm }

"""A sound as numbers: one channel, each sample from -1 to 1."""
obj Sound {
    has rate: int = 22050,
        samples: list[float] = [];

    def seconds -> float {
        return float(len(self.samples)) / float(self.rate) if self.rate > 0 else 0.0;
    }
}

"""What a WAV file says of itself: its rate, bits a sample, channels and
length in seconds, or why it is not one this reads."""
def sound_facts(data: bytes) -> str {
    try {
        found = parse_wav_pcm(data);
    } except ValueError as error {
        return str(error);
    }
    frames = found.length // max(1, found.frame_bytes());
    return str(found.rate) + " Hz, " + str(found.width * 8) + " bits, " + ("one channel" if found.channels == 1 else str(found.channels) + " channels")
        + ", " + str(round(float(frames) / float(max(1, found.rate)), 2)) + " s";
}

"""Read a WAV file's samples, its channels mixed into one. None when it is
not a WAV of plain samples 8, 16, 24 or 32 bits wide."""
def read_sound(data: bytes) -> Sound | None {
    try {
        found = parse_wav_pcm(data);
    } except ValueError {
        return None;
    }
    if found.width not in [1, 2, 3, 4] or found.channels < 1 or found.rate < 1 {
        return None;
    }
    made = Sound(rate=found.rate);
    step = found.frame_bytes();
    for frame in range(found.length // max(1, step)) {
        total = 0.0;
        for channel in range(found.channels) {
            at = found.offset + frame * step + channel * found.width;
            if found.width == 1 {
                # Eight bits are kept from 0 to 255, silence in the middle.
                total += (float(data[at]) - 128.0) / 128.0;
            } elif found.width == 2 {
                total += float(struct.unpack("<h", data[at:at + 2])[0]) / 32768.0;
            } elif found.width == 3 {
                whole = int(data[at]) | (int(data[at + 1]) << 8) | (int(data[at + 2]) << 16);
                total += float(whole - 16777216 if whole >= 8388608 else whole) / 8388608.0;
            } else {
                total += float(struct.unpack("<i", data[at:at + 4])[0]) / 2147483648.0;
            }
        }
        made.samples.append(total / float(found.channels));
    }
    return made;
}

"""The sound at another rate: each new sample measured between the two old
ones it falls between."""
def sound_at(sound: Sound, rate: int) -> Sound {
    if rate < 1 or sound.rate < 1 or rate == sound.rate or len(sound.samples) == 0 {
        return Sound(rate=sound.rate, samples=list(sound.samples));
    }
    made = Sound(rate=rate);
    count = max(1, int(round(float(len(sound.samples)) * float(rate) / float(sound.rate))));
    last = len(sound.samples) - 1;
    for index in range(count) {
        place = float(index) * float(sound.rate) / float(rate);
        low = min(last, int(place));
        high = min(last, low + 1);
        share = place - float(low);
        made.samples.append(sound.samples[low] * (1.0 - share) + sound.samples[high] * share);
    }
    return made;
}

"""The loudest a sound gets, from 0 to 1."""
def sound_peak(sound: Sound) -> float {
    peak = 0.0;
    for sample in sound.samples {
        peak = max(peak, abs(sample));
    }
    return peak;
}

"""The sound made as loud as it can be without clipping (a silent one is
left as it is)."""
def sound_normalized(sound: Sound) -> Sound {
    peak = sound_peak(sound);
    if peak < 0.0001 {
        return Sound(rate=sound.rate, samples=list(sound.samples));
    }
    return Sound(rate=sound.rate, samples=[sample / peak * 0.98 for sample in sound.samples]);
}

"""The sound as a WAV file: one channel, 8 or 16 bits a sample."""
def write_sound(sound: Sound, bits: int = 16) -> bytes {
    width = 1 if bits == 8 else 2;
    body = bytearray();
    for sample in sound.samples {
        held = max(-1.0, min(1.0, sample));
        if width == 1 {
            body.append(max(0, min(255, int(round(held * 127.0 + 128.0)))));
        } else {
            body.extend(struct.pack("<h", max(-32768, min(32767, int(round(held * 32767.0))))));
        }
    }
    if len(body) % 2 == 1 {
        # A chunk of odd length is padded to an even one.
        body.append(128 if width == 1 else 0);
    }
    out = bytearray();
    out.extend(b"RIFF");
    out.extend(struct.pack("<I", 36 + len(body)));
    out.extend(b"WAVEfmt ");
    out.extend(struct.pack("<IHHIIHH", 16, 1, 1, sound.rate, sound.rate * width, width, width * 8));
    out.extend(b"data");
    out.extend(struct.pack("<I", len(sound.samples) * width));
    out.extend(body);
    return bytes(out);
}

"""A WAV file made what a game plays: one channel at `rate` and `bits`.
Empty when it is not a WAV this reads."""
def converted_sound(data: bytes, rate: int = 22050, bits: int = 16, loud: bool = False) -> bytes {
    read = read_sound(data);
    if read is None {
        return b"";
    }
    made = sound_at(read, rate);
    if loud {
        made = sound_normalized(made);
    }
    return write_sound(made, bits);
}
