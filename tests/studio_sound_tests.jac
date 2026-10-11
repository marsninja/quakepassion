import math;
import struct;
import from engine.formats.wav { parse_wav_pcm }
import from engine.formats.q2.bsp { parse_wal }
import from editor.formats.sound {
    Sound,
    sound_facts,
    read_sound,
    sound_at,
    sound_peak,
    sound_normalized,
    write_sound,
    converted_sound
}
import from editor.formats.wal { WalFacts, wal_facts, wal_with, flag_names, flag_named, quake_frames }

def about(a: float, b: float, slack: float = 0.01) -> bool {
    return abs(a - b) < slack;
}

"""A tone: so many cycles a second for so long, at half strength."""
def tone(rate: int, cycles: float, seconds: float) -> Sound {
    made = Sound(rate=rate);
    for index in range(int(float(rate) * seconds)) {
        made.samples.append(0.5 * math.sin(2.0 * math.pi * cycles * float(index) / float(rate)));
    }
    return made;
}

"""A WAV file of two channels, 16 bits, with a tone in the left and silence in the right."""
def stereo(rate: int, cycles: float, seconds: float) -> bytes {
    body = bytearray();
    for index in range(int(float(rate) * seconds)) {
        left = int(round(0.5 * math.sin(2.0 * math.pi * cycles * float(index) / float(rate)) * 32767.0));
        body.extend(struct.pack("<hh", left, 0));
    }
    out = bytearray();
    out.extend(b"RIFF");
    out.extend(struct.pack("<I", 36 + len(body)));
    out.extend(b"WAVEfmt ");
    out.extend(struct.pack("<IHHIIHH", 16, 1, 2, rate, rate * 4, 4, 16));
    out.extend(b"data");
    out.extend(struct.pack("<I", len(body)));
    out.extend(body);
    return bytes(out);
}

test "a sound is written as a WAV the engine reads, at either width" {
    sound = tone(22050, 440.0, 0.1);
    assert len(sound.samples) == 2205 and about(sound.seconds(), 0.1, 0.001) and about(sound_peak(sound), 0.5, 0.01);
    wide = write_sound(sound, 16);
    read = parse_wav_pcm(wide);
    assert read.rate == 22050 and read.width == 2 and read.channels == 1 and read.length == 2205 * 2;
    assert sound_facts(wide) == "22050 Hz, 16 bits, one channel, 0.1 s";
    back = read_sound(wide);
    assert back is not None and len(back.samples) == 2205;
    for index in [0, 7, 100, 2204] {
        assert about(back.samples[index], sound.samples[index], 0.001);
    }
    # Eight bits: an odd count of them is padded, and they come back nearly as they were.
    narrow = write_sound(sound, 8);
    small = parse_wav_pcm(narrow);
    assert small.width == 1 and small.length == 2205 and len(narrow) % 2 == 0;
    coarse = read_sound(narrow);
    assert coarse is not None and about(coarse.samples[7], sound.samples[7], 0.02);
    assert read_sound(b"not a sound") is None and "RIFF" in sound_facts(b"not a sound at all, by far");
}

test "a sound from elsewhere is mixed to one channel and played at the games' rate" {
    data = stereo(44100, 441.0, 0.2);
    assert sound_facts(data) == "44100 Hz, 16 bits, 2 channels, 0.2 s";
    read = read_sound(data);
    # Left and right mixed: half the left's strength.
    assert read is not None and read.rate == 44100 and len(read.samples) == 8820 and about(sound_peak(read), 0.25, 0.01);
    half = sound_at(read, 22050);
    assert half.rate == 22050 and len(half.samples) == 4410 and about(half.seconds(), 0.2, 0.001);
    # The same tone: a quarter of the way round its cycle at the same moment.
    assert about(half.samples[25], read.samples[50], 0.01) and about(half.samples[1000], read.samples[2000], 0.01);
    # Up to a rate between: more samples, the same length of time, no louder.
    more = sound_at(half, 32000);
    assert len(more.samples) == 6400 and sound_peak(more) <= sound_peak(half) + 0.001;
    assert len(sound_at(read, 44100).samples) == 8820 and len(sound_at(Sound(rate=8000), 22050).samples) == 0;
    loud = sound_normalized(half);
    assert about(sound_peak(loud), 0.98, 0.001) and about(sound_peak(sound_normalized(Sound(rate=8000, samples=[0.0, 0.0]))), 0.0);
    # All at once: what Quake plays.
    made = converted_sound(data, 11025, 8, True);
    facts = parse_wav_pcm(made);
    assert facts.rate == 11025 and facts.width == 1 and facts.channels == 1 and facts.length == 2205;
    assert sound_facts(made) == "11025 Hz, 8 bits, one channel, 0.2 s" and converted_sound(b"nothing") == b"";
}

"""A WAL of a size: a name, four sizes of picture one after another, and no facts."""
def wal(name: str, wide: int, tall: int) -> bytes {
    raw = name.encode("utf-8");
    out = bytearray(raw + bytes(32 - len(raw)));
    out.extend(struct.pack("<II", wide, tall));
    at = 100;
    for level in range(4) {
        out.extend(struct.pack("<I", at));
        at += (wide >> level) * (tall >> level);
    }
    out.extend(bytes(32));
    out.extend(struct.pack("<iii", 0, 0, 0));
    for level in range(4) {
        out.extend(bytes([level + 1 for index in range((wide >> level) * (tall >> level))]));
    }
    return bytes(out);
}

test "a wall texture's flags, contents and value are read, changed and written back" {
    data = wal("e1u1/metal3_2", 64, 32);
    facts = wal_facts(data);
    assert facts is not None and facts.name == "e1u1/metal3_2" and facts.width == 64 and facts.height == 32;
    assert facts.flags == 0 and facts.contents == 0 and facts.value == 0 and facts.next_name == "";
    lit = flag_named(flag_named(0, "light", True), "warp", True);
    assert lit == 9 and flag_names(lit) == ["light", "warp"] and flag_named(lit, "LIGHT", False) == 8 and flag_named(lit, "glow", True) == 9;
    changed = wal_with(data, lit, 32, 400, "e1u1/metal3_3");
    assert len(changed) == len(data);
    again = wal_facts(changed);
    assert again is not None and again.flags == 9 and again.contents == 32 and again.value == 400 and again.next_name == "e1u1/metal3_3";
    assert again.name == "e1u1/metal3_2" and again.width == 64;
    # Its pictures are not touched: the engine reads the same texture.
    before = parse_wal(data, "x");
    after = parse_wal(changed, "x");
    assert after.width == 64 and after.height == 32 and after.pixels == before.pixels;
    # The chain ends when the next name is taken away.
    ended = wal_facts(wal_with(changed, 0, 0, 0, ""));
    assert ended is not None and ended.next_name == "";
    assert wal_facts(b"short") is None and wal_with(b"short", 1, 1, 1, "") == b"";
}

test "a Quake texture that is one of an animation is followed by the rest of its row" {
    names = ["e1m1/+0slip", "e1m1/+1slip", "e1m1/+2slip", "e1m1/+aslip", "e1m1/+0button", "e1m1/wall", "e1m2/+3slip"];
    assert quake_frames(names, "e1m1/+1slip") == ["e1m1/+0slip", "e1m1/+1slip", "e1m1/+2slip"];
    # The frames shown while it is pressed are a row of their own.
    assert quake_frames(names, "e1m1/+aslip") == ["e1m1/+aslip"];
    assert quake_frames(names, "e1m1/+0button") == ["e1m1/+0button"] and quake_frames(names, "e1m1/wall") == ["e1m1/wall"];
    assert quake_frames(names, "e1m9/+0lost") == ["e1m9/+0lost"] and quake_frames([], "+") == ["+"];
}
