"""Archive-backed gameplay sound palette with explicit native audio ownership."""
import from ..assets.library { AssetLibrary }
import from ..world.world { World }
import from ..world.speakers { Speaker, HasSpeaker }
import from ..math.vec3 { Vec3, right_from }
import from vendor.raylib {
    obj Wave {
        has frameCount: u32,
            sampleRate: u32,
            sampleSize: u32,
            channels: u32,
            data: u64;
    }  obj AudioStream {
        has buffer: u64,
            processor: u64,
            sampleRate: u32,
            sampleSize: u32,
            channels: u32;
    }  obj Sound {
        has stream: AudioStream,
            frameCount: u32;
    }  obj Music {
        has stream: AudioStream,
            frameCount: u32,
            looping: bool,
            ctxType: i32,
            ctxData: u64;
    }  def LoadMusicStreamFromMemory(
        fileType: str, data: bytes, dataSize: i32
    ) -> Music;  def IsMusicValid(music: Music) -> bool;  def UnloadMusicStream(
        music: Music
    ) -> None;  def PlayMusicStream(music: Music) -> None;  def IsMusicStreamPlaying(
        music: Music
    ) -> bool;  def UpdateMusicStream(music: Music) -> None;  def StopMusicStream(
        music: Music
    ) -> None;  def PauseMusicStream(music: Music) -> None;  def ResumeMusicStream(
        music: Music
    ) -> None;  def SetMusicVolume(music: Music, volume: f32) -> None;  def SetMusicPan(
        music: Music, pan: f32
    ) -> None;  def InitAudioDevice -> None;  def IsAudioDeviceReady -> bool;  def CloseAudioDevice -> None;  def LoadWaveFromMemory(
        fileType: str, fileData: bytes, dataSize: i32
    ) -> Wave;  def LoadSoundFromWave(wave: Wave) -> Sound;  def UnloadWave(
        wave: Wave
    ) -> None;  def UnloadSound(sound: Sound) -> None;  def PlaySound(
        sound: Sound
    ) -> None;  def SetSoundVolume(sound: Sound, volume: f32) -> None;  def SetSoundPitch(
        sound: Sound, pitch: f32
    ) -> None;
}

obj EmitterAudio {
    has music: Music,
        data: bytes,
        paused: bool = False;
}

obj Feedback {
    has ready: bool = False,
        sounds: list[Sound] = [],
        volume: float = 0.25,
        library: AssetLibrary | None = None,
        emitters: dict[int, EmitterAudio] = {},
        missing: set[int] = set(),
        named: dict[str, Sound] = {},
        unavailable: set[str] = set(),
        clips: dict[str, bytes] = {},
        ambience: dict[str, EmitterAudio] = {},
        ambient_levels: dict[str, float] = {};

    def open(game: str, directory: str, weapons: list[str] = []) {
        InitAudioDevice();
        self.ready = IsAudioDeviceReady();
        if not self.ready {
            return;
        }
        library = AssetLibrary(game="q1" if game == "passion" else game);
        library.open(directory + "/id1" if game == "passion" else directory);
        self.library = library;
        names = [
            "sound/weapons/shotgn2.wav",
            "sound/player/pain1.wav",
            "sound/items/itembk2.wav"
        ];
        if game == "q2" {
            names = [
                "sound/weapons/Sshotf1b.wav",
                "sound/player/male/pain100_1.wav",
                "sound/items/pkup.wav"
            ];
        }
        if game == "q3" {
            names = [
                "sound/weapons/shotgun/sshotf1b.wav",
                "sound/player/sarge/pain25_1.wav",
                "sound/items/n_health.wav"
            ];
        }
        names.extend(weapons);
        try {
            for name in names {
                data = library.read(name);
                wave = LoadWaveFromMemory(".wav", data, i32(len(data)));
                if wave.data == u64(0) {
                    raise ValueError("Cannot decode sound: " + name);
                }
                self.sounds.append(LoadSoundFromWave(wave));
                UnloadWave(wave);
            }
        } except Exception {
            self.close();
            raise;
        }
    }

    def play(kind: int, gain: float = 1.0) {
        if not self.ready or kind < 0 or kind >= len(self.sounds) {
            return;
        }
        sound = self.sounds[kind];
        SetSoundVolume(sound, f32(self.volume * gain));
        SetSoundPitch(sound, f32(1.8 if kind == 2 else 1.0));
        PlaySound(sound);
    }

    # Archive sounds requested by path are decoded once and cached per game.
    def play_path(path: str, gain: float = 1.0) {
        library = self.library;
        if not self.ready or library is None or not path or path in self.unavailable {
            return;
        }
        if path not in self.named {
            try {
                data = library.read(path);
                wave = LoadWaveFromMemory(".wav", data, i32(len(data)));
                if wave.data == u64(0) {
                    raise ValueError("Cannot decode sound: " + path);
                }
                self.named[path] = LoadSoundFromWave(wave);
                UnloadWave(wave);
            } except Exception as error {
                print("Sound unavailable:", path, str(error));
                self.unavailable.add(path);
                return;
            }
        }
        sound = self.named[path];
        SetSoundVolume(sound, f32(self.volume * max(0.0, min(1.0, gain))));
        SetSoundPitch(sound, f32(1.0));
        PlaySound(sound);
    }

    """Q1 S_UpdateAmbientSounds: water and sky loops follow the listener's BSP
    leaf levels, ramping at 100 volume units a second, silent below 8."""
    def ambient(path: str, level: int, dt: float, paused: bool = False) {
        library = self.library;
        if not self.ready or library is None or path in self.unavailable {
            return;
        }
        target = float(level) * 0.3;
        if target < 8.0 {
            target = 0.0;
        }
        current = self.ambient_levels.get(path, 0.0);
        step = 100.0 * dt;
        current = min(target, current + step) if current < target else max(target, current - step);
        self.ambient_levels[path] = current;
        if path not in self.ambience {
            if current <= 0.0 {
                return;
            }
            try {
                data = library.read(path);
                music = LoadMusicStreamFromMemory(".wav", data, i32(len(data)));
                if not IsMusicValid(music) {
                    raise ValueError("Cannot decode ambience: " + path);
                }
                music.looping = True;
                self.ambience[path] = EmitterAudio(music=music, data=data);
            } except Exception as error {
                print("Ambient audio unavailable:", path, str(error));
                self.unavailable.add(path);
                return;
            }
        }
        voice = self.ambience[path];
        if paused {
            if IsMusicStreamPlaying(voice.music) {
                PauseMusicStream(voice.music);
                voice.paused = True;
            }
            return;
        }
        SetMusicVolume(voice.music, f32(self.volume * current / 255.0));
        if voice.paused {
            ResumeMusicStream(voice.music);
            voice.paused = False;
        }
        if current > 0.0 and not IsMusicStreamPlaying(voice.music) {
            PlayMusicStream(voice.music);
        }
        UpdateMusicStream(voice.music);
    }

    def update(world: World, eye: Vec3, yaw: float, paused: bool = False) {
        library = self.library;
        if not self.ready or library is None {
            return;
        }
        speakers = [world->:HasSpeaker:->][?:Speaker];
        for index in range(len(speakers)) {
            speaker = speakers[index];
            if index in self.missing {
                speaker.requests = 0;
                continue;
            }
            # Distant looping emitters (hundreds of Q1 torches) hold no stream.
            if speaker.looping and not speaker.global_sound and not speaker.activator_sound {
                reach = speaker.origin.sub(eye).length() * 0.0008 * speaker.attenuation;
                if reach >= 1.0 {
                    if index in self.emitters {
                        StopMusicStream(self.emitters[index].music);
                        UnloadMusicStream(self.emitters[index].music);
                        self.emitters.pop(index);
                    }
                    continue;
                }
            }
            if index not in self.emitters {
                if paused or (not speaker.playing and speaker.requests == 0) {
                    continue;
                }
                try {
                    if speaker.path not in self.clips {
                        self.clips[speaker.path] = library.read(speaker.path);
                    }
                    data = self.clips[speaker.path];
                    music = LoadMusicStreamFromMemory(".wav", data, i32(len(data)));
                    if not IsMusicValid(music) {
                        raise ValueError("Cannot decode speaker: " + speaker.path);
                    }
                    music.looping = speaker.looping;
                    self.emitters[index] = EmitterAudio(music=music, data=data);
                } except Exception as error {
                    print("Speaker audio unavailable:", speaker.path, str(error));
                    self.missing.add(index);
                    speaker.requests = 0;
                    continue;
                }
            }
            voice = self.emitters[index];
            music = voice.music;
            if paused {
                if IsMusicStreamPlaying(music) {
                    PauseMusicStream(music);
                    voice.paused = True;
                }
                continue;
            }
            relative = speaker.origin.sub(eye);
            spatial = not speaker.global_sound
                and not speaker.activator_sound
                and speaker.attenuation > 0.0;
            gain = max(0.0, 1.0 - relative.length() * 0.0008 * speaker.attenuation)
                if spatial
                else 1.0;
            pan = right_from(yaw).dot(relative.normalized()) if spatial else 0.0;
            SetMusicVolume(music, f32(self.volume * speaker.volume * gain));
            SetMusicPan(music, f32(max(-1.0, min(1.0, pan))));
            if voice.paused {
                ResumeMusicStream(music);
                voice.paused = False;
            }
            if speaker.looping {
                if speaker.playing and not IsMusicStreamPlaying(music) {
                    PlayMusicStream(music);
                } elif not speaker.playing and IsMusicStreamPlaying(music) {
                    StopMusicStream(music);
                }
            } elif speaker.requests > 0 {
                StopMusicStream(music);
                PlayMusicStream(music);
                speaker.requests = 0;
            }
            UpdateMusicStream(music);
        }
    }

    def close() {
        if not self.ready {
            return;
        }
        for voice in self.emitters.values() {
            UnloadMusicStream(voice.music);
        }
        self.emitters = {};
        self.missing = set();
        for voice in self.ambience.values() {
            UnloadMusicStream(voice.music);
        }
        self.ambience = {};
        self.ambient_levels = {};
        self.clips = {};
        library = self.library;
        if library is not None {
            library.close();
            self.library = None;
        }
        for sound in self.sounds {
            UnloadSound(sound);
        }
        self.sounds = [];
        for sound in self.named.values() {
            UnloadSound(sound);
        }
        self.named = {};
        self.unavailable = set();
        CloseAudioDevice();
        self.ready = False;
    }
}
