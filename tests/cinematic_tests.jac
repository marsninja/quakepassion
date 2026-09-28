import os;
import struct;
import from engine.formats.q2.cin { open_cin, huff1_tree, huff1_decompress, CinDecoder }
import from engine.formats.wav { parse_wav_pcm }
import from engine.audio.streams {
    RawStream,
    BackgroundTrack,
    music_path,
    level_music,
    cd_track_names
}
import from engine.audio.feedback { Feedback }
import from engine.core.cinematic { CinematicPlayer, cinematic_rgba }
import from engine.assets.library { AssetLibrary }
import from engine.assets.pak { PakArchive, PakEntry }
import from engine.formats.bsp { Bsp, MapEntity }

"""A count row for every preceding value where only 1 and 2 occur: the tree
is node 256 with 1 on a 0 bit and 2 on a 1 bit."""
def two_symbol_rows() -> bytes {
    row = bytearray(256);
    row[1] = 1;
    row[2] = 1;
    return bytes(row) * 256;
}

"""A 2x2 film: header, trees, then `frames` frames of 1,2,2,1 pixels, each
carrying one 8-bit sample, the first with a palette."""
def tiny_film(frames: int) -> bytes {
    data = struct.pack("<5i", 2, 2, 14, 1, 1) + two_symbol_rows();
    for index in range(frames) {
        block = struct.pack("<i", 4) + bytes([6]);
        if index == 0 {
            palette = bytearray(768);
            palette[3] = 10;
            palette[6] = 20;
            data += struct.pack("<i", 1) + bytes(palette);
        } else {
            data += struct.pack("<i", 0);
        }
        data += struct.pack("<i", len(block)) + block + bytes([128 + index]);
    }
    return data + struct.pack("<i", 2);
}

test "Huff1TableInit pairs the lowest counts, earliest first" {
    row = bytearray(256);
    row[5] = 2;
    row[6] = 1;
    row[7] = 1;
    tree = huff1_tree(bytes(row));
    # Node 256 joins 6 and 7, node 257 joins 5 and 256; 257 is the root.
    assert tree[0] == 257;
    assert tree[1:5] == [6, 7, 5, 256];
    empty = huff1_tree(bytes(256));
    assert empty[0] == 255;
}

test "Huff1Decompress reads low bits first and switches trees per value" {
    nodes: list[int] = [];
    roots: list[int] = [];
    rows = two_symbol_rows();
    for previous in range(256) {
        tree = huff1_tree(rows[previous * 256:previous * 256 + 256]);
        roots.append(tree[0]);
        nodes.extend(tree[1:]);
    }
    assert roots[0] == 256;
    # Bits 0,1,1,0 (0b0110) decode to 1,2,2,1.
    assert huff1_decompress(nodes, roots, struct.pack("<i", 4) + bytes([6])) == bytes([1, 2, 2, 1]);
    # A block ending on a leaf may be read one byte past its end.
    assert huff1_decompress(nodes, roots, struct.pack("<i", 8) + bytes([0])) == bytes([1] * 8);
}

test "a film yields its frames, palette and sound slices, then ends" {
    decoder = open_cin(tiny_film(3));
    assert decoder.header.width == 2 and decoder.header.height == 2;
    assert decoder.header.sound_rate == 14 and decoder.header.sound_width == 1;
    first = decoder.next_frame();
    assert first is not None and first.pixels == bytes([1, 2, 2, 1]);
    assert first.palette[3] == 10 and first.samples == bytes([128]);
    second = decoder.next_frame();
    third = decoder.next_frame();
    assert second is not None and third is not None;
    assert third.index == 2 and third.samples == bytes([130]) and third.palette[6] == 20;
    assert decoder.next_frame() is None and decoder.finished;
    rgba = cinematic_rgba(bytes([1, 2]), first.palette);
    assert rgba == bytes([10, 0, 0, 255, 20, 0, 0, 255]);
}

test "SCR_RunCinematic shows each frame a frame late and runs out" {
    player = CinematicPlayer();
    audio = Feedback();
    player.play("tiny.cin", tiny_film(3), audio);
    assert player.active and player.frame == 1 and player.pic == bytes([1, 2, 2, 1]);
    # Frame 1 is read at 2/14 s (cin.pic becomes the empty pending picture).
    assert not player.advance(1.01 / 14.0, False, audio);
    assert player.frame == 1;
    assert not player.advance(1.01 / 14.0, False, audio);
    assert player.frame == 2 and player.pending;
    # A menu holds the clock where the frames read put it.
    assert not player.advance(5.0, True, audio);
    assert abs(player.elapsed - 2.0 / 14.0) < 0.000001;
    # A long step reads one frame and slows the film instead of dropping it.
    assert not player.advance(1.0, False, audio);
    assert player.frame == 3 and abs(player.elapsed - 2.0 / 14.0) < 0.000001;
    assert not player.advance(1.01 / 14.0, False, audio);
    assert player.advance(1.01 / 14.0, False, audio);
    # Held keys wait for a release; after a second any key finishes the film.
    player.elapsed = 1.5;
    assert not player.wants_skip(True);
    assert not player.wants_skip(False);
    assert player.wants_skip(True);
    player.stop(audio);
    assert not player.active;
}

test "Quake II's films decode to their original frames" {
    video = os.getenv("HOME", "") + "/quake-assets/baseq2/video";
    if not os.path.exists(video + "/eou1_.cin") {
        return;
    }
    library = AssetLibrary(game="q2");
    library.directory = video[:-6];
    assert library.exists("video/eou1_.cin");
    decoder = open_cin(library.read("video/eou1_.cin"));
    assert decoder.header.width == 320 and decoder.header.height == 240;
    assert decoder.header.sound_rate == 11025;
    assert decoder.header.sound_width == 1 and decoder.header.sound_channels == 1;
    assert decoder.roots[0:4] == [276, 277, 295, 283];
    first = decoder.next_frame();
    second = decoder.next_frame();
    assert first is not None and second is not None;
    assert sum(first.pixels) == 7985299 and first.pixels[40000] == 104;
    assert len(first.samples) == 787 and sum(first.samples) == 98889;
    assert sum(second.pixels) == 7967593 and len(second.samples) == 788;
    assert sum(first.palette) == 17547;
    with open(video + "/ntro.cin", "rb") as handle {
        header = handle.read(20);
    }
    assert struct.unpack("<5i", header) == (320, 240, 22050, 2, 2);
}

test "wav chunks give the music's sample layout" {
    body = bytes([1, 0, 2, 0, 3, 0, 4, 0]);
    data = b"RIFF"
        + struct.pack("<I", 36 + len(body))
        + b"WAVE"
        + b"LIST"
        + struct.pack("<I", 3)
        + b"abc\x00"
        + b"fmt "
        + struct.pack("<IHHIIHH", 16, 1, 2, 22050, 88200, 4, 16)
        + b"data"
        + struct.pack("<I", len(body))
        + body;
    pcm = parse_wav_pcm(data);
    assert pcm.rate == 22050 and pcm.width == 2 and pcm.channels == 2;
    assert pcm.length == 8 and data[pcm.offset:pcm.offset + 2] == bytes([1, 0]);
    failed = False;
    try {
        parse_wav_pcm(b"RIFF\x00\x00\x00\x00WAVE");
    } except ValueError {
        failed = True;
    }
    assert failed;
}

"""A one-channel 8-bit wav of `count` samples valued `value`."""
def tone(count: int, value: int) -> bytes {
    return b"RIFF"
        + struct.pack("<I", 36 + count)
        + b"WAVE"
        + b"fmt "
        + struct.pack("<IHHIIHH", 16, 1, 1, 100, 100, 1, 8)
        + b"data"
        + struct.pack("<I", count)
        + bytes([value] * count);
}

test "S_StartBackgroundTrack plays the intro, then loops the loop track" {
    bsp = Bsp(
        game="q3",
        entities=[
            MapEntity(
                fields={
                    "classname": "worldspawn",
                    "music": "music/fla22k_04_intro.wav music/fla22k_04_loop.wav"
                }
            )
        ]
    );
    music = level_music(bsp);
    assert music.intro == "music/fla22k_04_intro.wav" and music.loop == "music/fla22k_04_loop.wav";
    assert music.cd_track == 0;
    # Quake and Quake II name a CD track in worldspawn's "sounds".
    disc = level_music(Bsp(game="q2", entities=[MapEntity(fields={"sounds": "4"})]));
    assert disc.cd_track == 4 and not disc.intro;
    assert level_music(Bsp(game="q1", entities=[MapEntity(fields={})])).cd_track == 0;
    assert cd_track_names(4) == ["music/track04.ogg", "music/track04.wav"];
    assert music_path("music\\sonic5.wav") == "music/sonic5.wav";
    assert music_path("music/win") == "music/win.wav";
    intro = tone(30, 1);
    loop = tone(10, 2);
    blob = intro + loop;
    library = AssetLibrary(game="q2");
    library.paks = [
        PakArchive(
            data=blob,
            entries=[
                PakEntry(name="music/intro.wav", offset=0, size=len(intro)),
                PakEntry(name="music/loop.wav", offset=len(intro), size=len(loop))
            ],
            index={"music/intro.wav": 0, "music/loop.wav": 1}
        )
    ];
    track = BackgroundTrack();
    channel = RawStream();
    track.start(library, "music/intro", "music/loop");
    assert track.playing and track.name == "music/intro.wav";
    # 0.5 s ahead at 100 Hz: the 30 intro samples, then 20 of the loop.
    track.update(library, channel, 0.5);
    assert channel.queued_frames() == 50;
    assert channel.queue[29] == 1 and channel.queue[30] == 2 and channel.queue[49] == 2;
    assert track.name == "music/loop.wav" and track.playing;
    # "music music/win": one play, no loop.
    track.start(library, "music/intro", once=True);
    channel.queue = b"";
    track.update(library, channel, 1.0);
    assert channel.queued_frames() == 30 and not track.playing;
    track.start(library, "music/missing");
    assert not track.playing;
}
