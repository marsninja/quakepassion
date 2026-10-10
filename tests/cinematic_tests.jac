import os;
import struct;
import zlib;
import from engine.formats.q2.cin { open_cin, huff1_tree, huff1_decompress, CinDecoder, cinematic_rgba }
import from engine.formats.q3.roq { open_roq, RoqDecoder }
import from engine.formats.film { Film }
import from games.arenas {
    parse_arenas,
    tier_completed,
    last_tier,
    postgame_film,
    tier_video_due,
    info_value,
    info_with
}
import from engine.formats.wav { parse_wav_pcm }
import from engine.audio.streams {
    RawStream,
    BackgroundTrack,
    music_path,
    level_music,
    cd_track_names
}
import from engine.audio.feedback { Feedback }
import from engine.core.cinematic { CinematicPlayer, open_film }
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

"""One RoQ chunk: its id, 24-bit size and argument, then the payload."""
def roq_chunk(kind: int, argument: int, payload: bytes) -> bytes {
    return struct.pack("<HIH", kind, len(payload), argument) + payload;
}

"""A 16x16 RoQ film of two pictures. The codebook has a white and a
near-black 2x2 cell and one 4x4 cell of them in a checker. Picture 1 takes
the doubled 4x4 cell for all four 8x8 quads. Picture 2 skips the first quad,
moves the second from four pixels to its left, splits the third (a 4x4
cell, four 2x2 cells, a 4x4 move from the same place, a skip) and takes the
8x8 cell again for the fourth. A third picture's chunk ends the file: with
an 8-byte first chunk, RoQInterrupt's count of bytes played reaches the
file's size one chunk early."""
def tiny_roq() -> bytes {
    codebook = bytes([255, 255, 255, 255, 128, 128, 0, 0, 0, 0, 128, 128]) + bytes([0, 1, 1, 0]);
    first = bytes([0x00, 0xAA, 0, 0, 0, 0]);
    second = bytes([0xD2, 0x1E, 0xC8, 0, 1, 1, 1, 1, 0x88, 0]);
    return struct.pack("<HIH", 0x1084, 0xFFFFFFFF, 30)
        + roq_chunk(0x1001, 0, struct.pack("<4H", 16, 16, 8, 4))
        + roq_chunk(0x1021, 0x1020, bytes([1, 129, 2, 130]))
        + roq_chunk(0x1002, 0x0201, codebook)
        + roq_chunk(0x1011, 0, first)
        + roq_chunk(0x1020, 16, bytes([3, 131]))
        + roq_chunk(0x1011, 0, second)
        + roq_chunk(0x1011, 0, first);
}

"""Whether a picture's pixel is the white cell's (else the near-black one's)."""
def roq_white(pixels: bytes, x: int, y: int) -> bool {
    at = (y * 16 + x) * 4;
    colour = pixels[at:at + 4];
    assert colour == bytes([255, 255, 255, 255]) or colour == bytes([1, 0, 1, 255]) , str(x) + "," + str(y);
    return colour[0] == 255;
}

test "a RoQ film's codebook, quad tree, motion and sound decode as cl_cin.c's" {
    decoder = open_roq(tiny_roq());
    assert isinstance(decoder, RoqDecoder) and decoder.frame_rate == 30 and not decoder.trails;
    first = decoder.next_picture();
    assert first is not None and decoder.width == 16 and decoder.height == 16;
    assert len(decoder.quads) == 20 and decoder.quads[:6] == [0, 0, 16, 256, 272, 32];
    assert len(first.pixels) == 16 * 16 * 4;
    # The doubled 4x4 cell: a checker of four-pixel squares.
    for y in range(16) {
        for x in range(16) {
            assert roq_white(first.pixels, x, y) == ((x // 4 + y // 4) % 2 == 0);
        }
    }
    # RllDecodeStereoToStereo: the argument's bytes start the two channels.
    assert first.sound_rate == 22050 and first.sound_width == 2 and first.sound_channels == 2;
    assert first.samples == bytes([0x01, 0x10, 0xFF, 0x1F, 0x05, 0x10, 0xFB, 0x1F]);
    second = decoder.next_picture();
    assert second is not None and decoder.frame == 2;
    for y in range(8) {
        for x in range(8) {
            # Skipped: as the picture before. Moved: from four pixels left.
            assert roq_white(second.pixels, x, y) == roq_white(first.pixels, x, y);
            assert roq_white(second.pixels, 8 + x, y) == roq_white(first.pixels, 4 + x, y);
            # The 8x8 cell again.
            assert roq_white(second.pixels, 8 + x, 8 + y) == roq_white(first.pixels, 8 + x, 8 + y);
        }
    }
    for y in range(4) {
        for x in range(4) {
            # The 4x4 cell itself: a checker of two-pixel squares.
            assert roq_white(second.pixels, x, 8 + y) == ((x // 2 + y // 2) % 2 == 0);
            # Four 2x2 cells, all the near-black one.
            assert not roq_white(second.pixels, 4 + x, 8 + y);
            # A 4x4 move from the same place, and a skipped 4x4.
            assert roq_white(second.pixels, x, 12 + y) == roq_white(first.pixels, x, 12 + y);
            assert roq_white(second.pixels, 4 + x, 12 + y) == roq_white(first.pixels, 4 + x, 12 + y);
        }
    }
    # RoQInterrupt hands S_RawSamples the doubled mono buffer as `size`
    # mono samples: the chunk's first half, each sample twice.
    assert second.sound_channels == 1 and second.samples == bytes([25, 0, 25, 0]);
    # The last chunk is never run.
    assert decoder.next_picture() is None and decoder.finished and decoder.frame == 2;
    failed = False;
    try {
        open_roq(b"not a film, whatever it says");
    } except ValueError {
        failed = True;
    }
    assert failed;
}

test "the player runs a RoQ to the clock, on any key, holding end.RoQ" {
    player = CinematicPlayer();
    audio = Feedback();
    film: Film = open_film("video/tier1.RoQ", tiny_roq());
    assert not film.holds and film.escape_skips and film.skip_after == 0.0;
    assert open_film("end.RoQ", tiny_roq()).holds and open_film("demoEnd.roq", tiny_roq()).holds;
    assert open_film("eou1_.cin", tiny_film(1)).trails and not open_film("eou1_.cin", tiny_film(1)).escape_skips;
    player.play("tier1.RoQ", tiny_roq(), audio);
    # CL_PlayCinematic_f waits for the first picture, due a thirtieth in.
    assert player.active and player.frame == 1 and player.width == 16 and not player.palette;
    assert abs(player.elapsed - 1.0 / 30.0) < 0.000001 and player.escape_skips();
    shown = player.pic;
    assert not player.advance(0.5 / 30.0, False, audio) and player.frame == 1;
    # The next picture shows as soon as it is read; nothing waits a frame.
    assert not player.advance(0.6 / 30.0, False, audio);
    assert player.frame == 2 and player.pic != shown and not player.pending;
    # Any key press ends it, without Quake II's second of grace.
    assert not player.wants_skip(False);
    assert player.wants_skip(True);
    assert player.advance(1.0, False, audio);
    # CIN_hold: end.RoQ runs out onto its last picture and waits for a key.
    player.play("end.RoQ", tiny_roq(), audio);
    assert not player.advance(1.0, False, audio);
    assert player.idle and player.active and player.frame == 2;
    assert not player.advance(5.0, False, audio);
    assert not player.wants_skip(False) and player.wants_skip(True);
    player.stop(audio);
    assert not player.active and not player.idle;
}

test "Quake III's films decode to their original pictures" {
    directory = os.getenv("HOME", "") + "/quake-assets/baseq3";
    if not os.path.exists(directory + "/pak0.pk3") {
        return;
    }
    library = AssetLibrary(game="q3");
    library.open(directory);
    for name in ["idlogo", "intro", "tier1", "tier2", "tier3", "tier4", "tier5", "tier6", "tier7", "end"] {
        assert library.exists("video/" + name + ".RoQ") , name;
    }
    decoder = open_roq(library.read("video/idlogo.RoQ"));
    library.close();
    first = decoder.next_picture();
    second = decoder.next_picture();
    assert first is not None and second is not None;
    assert decoder.width == 512 and decoder.height == 256 and decoder.frame == 2;
    assert zlib.crc32(first.pixels) == 408929545 and zlib.crc32(second.pixels) == 1258248192;
    # 14912 bytes of stereo sound lead the first picture; 1472 go with each.
    assert first.sound_channels == 2 and len(first.samples) == 29824 and len(second.samples) == 2944;
}

test "UI_TierCompleted and the postgame's films" {
    text = "";
    for name in ["dm0", "dm1", "dm2", "dm3", "dm4", "dm5", "dm6", "dm7", "dm8", "dm9", "final"] {
        text += "{\nmap " + name + "\ntype \"ffa single\"\n";
        if name == "dm0" {
            text += "special training\n";
        }
        if name == "final" {
            text += "special final\n";
        }
        text += "}\n";
    }
    arenas = parse_arenas(text + "{\nmap ctf1\ntype ctf\n}\n");
    # Nine tier arenas: one is left over from two whole tiers.
    assert last_tier(arenas) == 3;
    assert tier_completed(arenas, {"dm0": 1}, "dm0") == 0;
    assert tier_completed(arenas, {"dm1": 1, "dm2": 1, "dm3": 1}, "dm3") == -1;
    assert tier_completed(arenas, {"dm1": 1, "dm2": 1, "dm3": 1, "dm4": 2}, "dm3") == -1;
    assert tier_completed(arenas, {"dm1": 1, "dm2": 1, "dm3": 1, "dm4": 1}, "dm2") == 1;
    assert tier_completed(arenas, {"dm5": 1, "dm6": 1, "dm7": 1, "dm8": 1}, "dm8") == 2;
    assert tier_completed(arenas, {"dm9": 1}, "dm9") == -1;
    assert tier_completed(arenas, {"final": 1}, "final") == 3;
    assert tier_completed(arenas, {"ctf1": 1}, "ctf1") == -1;
    # The training arena plays tier1.RoQ, a tier the next one's film, the
    # final arena end.RoQ with nothing to follow.
    assert postgame_film(0, 3) == ("tier1.RoQ", "levelselect");
    assert postgame_film(2, 3) == ("tier3.RoQ", "levelselect");
    assert postgame_film(3, 3) == ("end.RoQ", "");
    # UI_ShowTierVideo: once each, kept in g_spVideos' info string.
    assert tier_video_due("", 1) and not tier_video_due("", 0);
    videos = info_with("", "tier1", "1");
    assert videos == "\\tier1\\1" and info_value(videos, "TIER1") == "1";
    videos = info_with(info_with(videos, "tier3", "1"), "tier1", "1");
    assert videos == "\\tier3\\1\\tier1\\1";
    assert not tier_video_due(videos, 1) and tier_video_due(videos, 2) and not tier_video_due(videos, 3);
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
