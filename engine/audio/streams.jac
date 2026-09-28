"""Sound the engine decodes and feeds itself, sample block by sample block.

RawStream is the raw sample channel (snd_dma.c S_RawSamples): a cinematic
hands it each frame's samples as the frame is read, and Quake III's
background music streams into one (S_StartBackgroundTrack and
S_UpdateBackgroundTrack: an intro track, then a loop track played again and
again). The samples reach the device through a raylib audio stream, filled a
whole sub-buffer at a time."""
import from ..assets.library { AssetLibrary }
import from ..formats.wav { WavPcm, parse_wav_pcm }
import from ..formats.bsp { Bsp }
import from vendor.raylib {
    obj RawAudioStream {
        has buffer: u64,
            processor: u64,
            sampleRate: u32,
            sampleSize: u32,
            channels: u32;
    }  def LoadAudioStream(
        sampleRate: u32, sampleSize: u32, channels: u32
    ) -> RawAudioStream;  def IsAudioStreamValid(
        stream: RawAudioStream
    ) -> bool;  def UnloadAudioStream(stream: RawAudioStream) -> None;  def UpdateAudioStream(
        stream: RawAudioStream, data: bytes, frameCount: i32
    ) -> None;  def IsAudioStreamProcessed(stream: RawAudioStream) -> bool;  def PlayAudioStream(
        stream: RawAudioStream
    ) -> None;  def IsAudioStreamPlaying(stream: RawAudioStream) -> bool;  def StopAudioStream(
        stream: RawAudioStream
    ) -> None;  def SetAudioStreamVolume(
        stream: RawAudioStream, volume: f32
    ) -> None;  def SetAudioStreamBufferSizeDefault(size: i32) -> None;
}

"""S_RawSamples' channel. Samples wait in `queue` until raylib has a
processed sub-buffer to fill; a change of rate, width or channel count
starts a new device stream, as the original resamples every format into
one buffer."""
obj RawStream {
    has stream: RawAudioStream | None = None,
        rate: int = 0,
        width: int = 0,
        channels: int = 0,
        block: int = 0,
        queue: bytes = b"",
        gain: float = 1.0;

    """Queue sample frames in the file's own layout: 8-bit unsigned or
    16-bit signed little-endian, mono or interleaved stereo."""
    def samples(rate: int, width: int, channels: int, data: bytes) {
        if rate <= 0 or width not in [1, 2] or channels not in [1, 2] {
            return;
        }
        if rate != self.rate or width != self.width or channels != self.channels {
            self.close();
            self.rate = rate;
            self.width = width;
            self.channels = channels;
            # 50 ms sub-buffers: short enough to follow a cinematic's frames.
            self.block = max(256, rate // 20) * width * channels;
        }
        whole = len(data) - len(data) % (width * channels);
        self.queue = self.queue + data[:whole];
    }

    """Sample frames waiting for the device."""
    def queued_frames() -> int {
        if self.width <= 0 or self.channels <= 0 {
            return 0;
        }
        return len(self.queue) // (self.width * self.channels);
    }

    """Hand the device every whole sub-buffer it has room for; `drain` also
    sends a final partial one (raylib pads it with silence). The device
    stream opens on the first samples of each format."""
    def pump(drain: bool = False) {
        if self.block <= 0 {
            return;
        }
        frame = self.width * self.channels;
        if self.stream is None {
            if not self.queue {
                return;
            }
            SetAudioStreamBufferSizeDefault(i32(self.block // frame));
            created = LoadAudioStream(u32(self.rate), u32(self.width * 8), u32(self.channels));
            SetAudioStreamBufferSizeDefault(i32(0));
            if not IsAudioStreamValid(created) {
                self.queue = b"";
                return;
            }
            self.stream = created;
        }
        stream = self.stream;
        if stream is None {
            return;
        }
        SetAudioStreamVolume(stream, f32(max(0.0, min(1.0, self.gain))));
        while self.queue and IsAudioStreamProcessed(stream) {
            if len(self.queue) < self.block and not drain {
                break;
            }
            chunk = self.queue[:self.block];
            self.queue = self.queue[self.block:];
            UpdateAudioStream(stream, chunk, i32(len(chunk) // frame));
            if not IsAudioStreamPlaying(stream) {
                PlayAudioStream(stream);
            }
        }
    }

    """Silence the channel and forget what was queued."""
    def clear() {
        self.queue = b"";
        stream = self.stream;
        if stream is not None {
            StopAudioStream(stream);
        }
    }

    def close() {
        stream = self.stream;
        if stream is not None {
            StopAudioStream(stream);
            UnloadAudioStream(stream);
        }
        self.stream = None;
        self.queue = b"";
        self.rate = 0;
        self.width = 0;
        self.channels = 0;
        self.block = 0;
    }
}

"""A music name as S_StartBackgroundTrack opens it: the default .wav
extension, and either slash (the file system treats them alike)."""
def music_path(name: str) -> str {
    path = name.replace("\\", "/");
    last = path.split("/")[-1];
    if "." not in last {
        path += ".wav";
    }
    return path;
}

"""A level's music: Quake III's streamed intro and loop tracks, or the CD
track Quake and Quake II play looping."""
obj LevelMusic {
    has intro: str = "",
        loop: str = "",
        cd_track: int = 0;
}

"""Quake III CG_StartMusic: worldspawn's `music` holds the intro track and an
optional loop track (COM_Parse's two tokens). Quake and Quake II take the
CD track from worldspawn's `sounds` (svc_cdtrack, CS_CDTRACK)."""
def level_music(bsp: Bsp) -> LevelMusic {
    found = LevelMusic();
    if not bsp.entities {
        return found;
    }
    fields = bsp.entities[0].fields;
    if bsp.game == "q3" {
        words = fields.get("music", "").split();
        if words {
            found.intro = words[0];
        }
        if len(words) > 1 {
            found.loop = words[1];
        }
    } elif bsp.game in ["q1", "q2"] {
        words = fields.get("sounds", "").split();
        if words and words[0].isdigit() {
            found.cd_track = int(words[0]);
        }
    }
    return found;
}

"""The files that stand in for a CD track: music/trackNN, as the re-released
games ship their soundtracks."""
def cd_track_names(track: int) -> list[str] {
    number = ("0" if track < 10 else "") + str(track);
    return ["music/track" + number + ".ogg", "music/track" + number + ".wav"];
}

"""Quake III's streamed music (s_backgroundFile): the track being read, how
far, and the track to go on with once it ends (s_backgroundLoop, empty to
stop)."""
obj BackgroundTrack {
    has name: str = "",
        loop: str = "",
        data: bytes = b"",
        pcm: WavPcm = WavPcm(),
        position: int = 0,
        playing: bool = False,
        warned: set[str] = set();

    """S_StartBackgroundTrack: open `intro`, keeping `loop` (the intro
    itself when empty) to follow it; `once` clears the loop as S_Music_f
    does for a single track. What the channel already holds plays out, as
    the original keeps s_rawend."""
    def start(library: AssetLibrary, intro: str, loop: str = "", once: bool = False) {
        if not loop {
            loop = intro;
        }
        self.playing = False;
        self.data = b"";
        if not intro {
            return;
        }
        self.loop = "" if once else loop;
        path = music_path(intro);
        try {
            data = library.read(path);
            pcm = parse_wav_pcm(data);
        } except Exception as error {
            if path not in self.warned {
                self.warned.add(path);
                print("WARNING: couldn't open music file", path, str(error));
            }
            return;
        }
        self.name = path;
        self.data = data;
        self.pcm = pcm;
        self.position = 0;
        self.playing = pcm.length > 0;
    }

    """S_StopBackgroundTrack."""
    def stop() {
        self.playing = False;
        self.data = b"";
        self.loop = "";
        self.name = "";
    }

    """S_UpdateBackgroundTrack: keep about `ahead` seconds of the track
    queued in `channel`, going on to the loop track at the end."""
    def update(library: AssetLibrary, channel: RawStream, ahead: float = 0.2) {
        guard = 0;
        while self.playing and guard < 4 {
            guard += 1;
            pcm = self.pcm;
            queued = channel.queued_frames() if channel.rate == pcm.rate else 0;
            wanted = int(float(pcm.rate) * ahead) - queued;
            if wanted <= 0 {
                return;
            }
            frame = pcm.frame_bytes();
            available = (pcm.length - self.position) // frame;
            count = min(wanted, available);
            if count > 0 {
                start = pcm.offset + self.position;
                channel.samples(
                    pcm.rate,
                    pcm.width,
                    pcm.channels,
                    self.data[start:start + count * frame]
                );
                self.position += count * frame;
            }
            if self.position >= pcm.length {
                if self.loop {
                    following = self.loop;
                    self.start(library, following, following);
                } else {
                    self.stop();
                }
            } elif count >= wanted {
                return;
            }
        }
    }
}
