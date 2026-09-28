"""Archive-backed gameplay sound palette with explicit native audio ownership."""
import from ..assets.library { AssetLibrary }
import from ..world.world { World, Player }
import from ..world.speakers { Speaker, HasSpeaker }
import from ..world.combat { CombatState, Projectile, HasProjectile, selected_weapon }
import from ..math.vec3 { Vec3, right_from }
import from .streams { RawStream, BackgroundTrack, cd_track_names }
import from ..console.cvar { Cvar, CVAR_ARCHIVE }
import from ..console.shell { Shell }
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
    ) -> None;  def SetSoundVolume(sound: Sound, volume: f32) -> None;  def SetSoundPan(
        sound: Sound, pan: f32
    ) -> None;  def SetSoundPitch(
        sound: Sound, pitch: f32
    ) -> None;
}

"""The original engines' default master volumes (s_volume): Quake II's raw
cinematic samples and Quake III's music bypass it, so each is scaled by the
player's volume against that default to keep the original balance."""
glob Q2_DEFAULT_VOLUME: float = 0.7;
glob Q3_DEFAULT_VOLUME: float = 0.8;

"""How loud a positioned sound is heard `distance` units away, as each game
mixes it. Quake: SND_Spatialize, falling off by attenuation/1000 a unit
(static sounds are sent as attenuation*64 and read back the same).
Quake II: S_SpatializeOrigin, full volume within 80 units, then 0.0005 a
unit per attenuation (0.001 for ATTN_STATIC, 3) and 0.003 for looping
entity sounds. Quake III: full within 80, then 0.0008 a unit for all.
Attenuation 0 is heard everywhere at full volume."""
def sound_falloff(game: str, distance: float, attenuation: float, looping: bool) -> float {
    if attenuation <= 0.0 {
        return 1.0;
    }
    if game == "q2" {
        rate = 0.003 if looping or attenuation == 3.0 else attenuation * 0.0005;
        return max(0.0, 1.0 - max(0.0, distance - 80.0) * rate);
    }
    if game == "q3" {
        return max(0.0, 1.0 - max(0.0, distance - 80.0) * 0.0008);
    }
    return max(0.0, 1.0 - distance * attenuation / 1000.0);
}

obj EmitterAudio {
    has music: Music,
        data: bytes,
        paused: bool = False;
}

"""A missile's flight sound, looping for as long as the missile flies."""
obj FlightAudio {
    has projectile: Projectile,
        voice: EmitterAudio;
}

"""p_view.c G_SetClientSound: the Quake II player's own looping sound
(ent->s.sound) — frying in slime or lava, the railgun's and BFG's hum, or
the held weapon's (client->weapon_sound: the hyperblaster firing, the
chaingun spinning, a hand grenade cooking)."""
def q2_client_sound(player: Player, state: CombatState) -> str {
    if state.game != "q2" or player.health <= 0 {
        return "";
    }
    if player.water_depth > 0 and player.liquid_kind in [2, 3] {
        return "sound/player/fry.wav";
    }
    key = selected_weapon(state).key;
    if key == "railgun" {
        return "sound/weapons/rg_hum.wav";
    }
    if key == "bfg" {
        return "sound/weapons/bfg_hum.wav";
    }
    if key == "hyperblaster" and state.firing and state.cooldown > 0.0 {
        return "sound/weapons/hyprbl1a.wav";
    }
    if key == "chaingun" and state.spin > 0 {
        return "sound/weapons/chngnl1a.wav";
    }
    # Weapon_Grenade: from the pin's release (gunframe 11) to the throw.
    if key == "handgrenade" and state.grenade_phase in [2, 3] {
        return "sound/weapons/hgrenc1b.wav";
    }
    return "";
}

obj Feedback {
    has ready: bool = False,
        sounds: list[Sound] = [],
        # S_Init's volume (Q3 s_volume).
        volume: Cvar = Cvar(
            name="volume",
            reset_text="0.25",
            kind="float",
            low=0.0,
            high=1.0,
            flags=CVAR_ARCHIVE,
            aliases=["s_volume"],
            description="sound effects volume"
        ),
        library: AssetLibrary | None = None,
        emitters: dict[int, EmitterAudio] = {},
        missing: set[int] = set(),
        named: dict[str, Sound] = {},
        unavailable: set[str] = set(),
        clips: dict[str, bytes] = {},
        ambience: dict[str, EmitterAudio] = {},
        ambient_levels: dict[str, float] = {},
        game: str = "",
        # Missile effects' flight sounds, the missiles heard, and the
        # player's own looping sound and its path.
        missiles: dict[str, str] = {},
        flights: list[FlightAudio] = [],
        client_voice: EmitterAudio | None = None,
        client_path: str = "",
        # CDAudio_Play's track, played from a file standing in for the disc.
        cd: EmitterAudio | None = None,
        cd_track: int = 0,
        # s_musicvolume, and the streamed music and cinematic sound channels.
        music_volume: Cvar = Cvar(
            name="bgmvolume",
            reset_text="0.25",
            kind="float",
            low=0.0,
            high=1.0,
            flags=CVAR_ARCHIVE,
            aliases=["s_musicvolume"],
            description="music volume"
        ),
        music: BackgroundTrack = BackgroundTrack(),
        music_channel: RawStream = RawStream(),
        cinematic_channel: RawStream = RawStream();

    def declare(shell: Shell) {
        self.volume = shell.register(self.volume);
        self.music_volume = shell.register(self.music_volume);
    }

    def open(
        game: str,
        directory: str,
        weapons: list[str] = [],
        missiles: dict[str, str] = {}
    ) {
        InitAudioDevice();
        self.ready = IsAudioDeviceReady();
        if not self.ready {
            return;
        }
        library = AssetLibrary(game="q1" if game == "passion" else game);
        library.open(directory + "/id1" if game == "passion" else directory);
        self.library = library;
        self.game = game;
        self.missiles = missiles;
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
        SetSoundVolume(sound, f32(self.volume.number * gain));
        SetSoundPitch(sound, f32(1.8 if kind == 2 else 1.0));
        PlaySound(sound);
    }

    # Archive sounds requested by path are decoded once and cached per game.
    def play_path(path: str, gain: float = 1.0, pan: float = 0.0) {
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
        SetSoundVolume(sound, f32(self.volume.number * max(0.0, min(1.0, gain))));
        SetSoundPan(sound, f32(max(-1.0, min(1.0, pan))));
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
        SetMusicVolume(voice.music, f32(self.volume.number * current / 255.0));
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
        self.update_streams();
        self.update_flights(world, eye, yaw, paused);
        speakers = [world->:HasSpeaker:->][?:Speaker];
        for index in range(len(speakers)) {
            speaker = speakers[index];
            if index in self.missing {
                speaker.requests = 0;
                continue;
            }
            relative = speaker.origin.sub(eye);
            spatial = not speaker.global_sound and not speaker.activator_sound;
            gain = sound_falloff(self.game, relative.length(), speaker.attenuation, speaker.looping)
                if spatial
                else 1.0;
            # Distant looping emitters (hundreds of Q1 torches) hold no stream.
            if speaker.looping and gain <= 0.0 {
                speaker.requests = 0;
                if index in self.emitters {
                    StopMusicStream(self.emitters[index].music);
                    UnloadMusicStream(self.emitters[index].music);
                    self.emitters.pop(index);
                }
                continue;
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
            pan = right_from(yaw).dot(relative.normalized())
                if spatial and speaker.attenuation > 0.0
                else 0.0;
            SetMusicVolume(music, f32(self.volume.number * speaker.volume * gain));
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
                # CG_Speaker's automatic plays sound over a Q3 speaker's loop.
                if speaker.requests > 0 {
                    self.play_path(speaker.path, speaker.volume * gain, pan);
                    speaker.requests = 0;
                }
            } elif speaker.requests > 0 {
                StopMusicStream(music);
                PlayMusicStream(music);
                speaker.requests = 0;
            }
            UpdateMusicStream(music);
        }
    }

    """A looping clip as a stream of its own, from the clip cache."""
    def loop_voice(path: str) -> EmitterAudio | None {
        library = self.library;
        if library is None or path in self.unavailable {
            return None;
        }
        try {
            if path not in self.clips {
                self.clips[path] = library.read(path);
            }
            data = self.clips[path];
            music = LoadMusicStreamFromMemory(".wav", data, i32(len(data)));
            if not IsMusicValid(music) {
                raise ValueError("Cannot decode loop: " + path);
            }
            music.looping = True;
            return EmitterAudio(music=music, data=data);
        } except Exception as error {
            print("Looping sound unavailable:", path, str(error));
            self.unavailable.add(path);
        }
        return None;
    }

    """Keep a looping voice going at `gain` and `pan`, or held while paused."""
    def run_loop(voice: EmitterAudio, gain: float, pan: float, paused: bool) {
        music = voice.music;
        if paused {
            if IsMusicStreamPlaying(music) {
                PauseMusicStream(music);
                voice.paused = True;
            }
            return;
        }
        SetMusicVolume(music, f32(self.volume.number * max(0.0, min(1.0, gain))));
        SetMusicPan(music, f32(max(-1.0, min(1.0, pan))));
        if voice.paused {
            ResumeMusicStream(music);
            voice.paused = False;
        }
        if not IsMusicStreamPlaying(music) {
            PlayMusicStream(music);
        }
        UpdateMusicStream(music);
    }

    """The listener's own looping sound (the view entity's s.sound), heard
    at full volume; an empty path silences it."""
    def client_loop(path: str, paused: bool = False) {
        if not self.ready {
            return;
        }
        if path != self.client_path {
            voice = self.client_voice;
            if voice is not None {
                StopMusicStream(voice.music);
                UnloadMusicStream(voice.music);
            }
            self.client_voice = self.loop_voice(path) if path else None;
            self.client_path = path;
        }
        voice = self.client_voice;
        if voice is not None {
            self.run_loop(voice, 1.0, 0.0, paused);
        }
    }

    """Missiles' flight sounds (S_AddLoopSounds over entities with a sound),
    each following its missile until it is gone."""
    def update_flights(world: World, eye: Vec3, yaw: float, paused: bool) {
        projectiles = [world->:HasProjectile:->][?:Projectile] if self.missiles else [];
        kept: list[FlightAudio] = [];
        for flight in self.flights {
            alive = False;
            for projectile in projectiles {
                if projectile is flight.projectile {
                    alive = True;
                }
            }
            if alive {
                kept.append(flight);
            } else {
                StopMusicStream(flight.voice.music);
                UnloadMusicStream(flight.voice.music);
            }
        }
        self.flights = kept;
        for projectile in projectiles {
            path = self.missiles.get(projectile.effect, "");
            if not path {
                continue;
            }
            found: FlightAudio | None = None;
            for flight in self.flights {
                if flight.projectile is projectile {
                    found = flight;
                }
            }
            if found is None {
                if paused {
                    continue;
                }
                voice = self.loop_voice(path);
                if voice is None {
                    continue;
                }
                found = FlightAudio(projectile=projectile, voice=voice);
                self.flights.append(found);
            }
            relative = projectile.pos.sub(eye);
            gain = sound_falloff(self.game, relative.length(), 3.0, True);
            self.run_loop(
                found.voice, gain, right_from(yaw).dot(relative.normalized()), paused
            );
        }
    }

    """CDAudio_Play(track, looping): Quake and Quake II music came off the
    CD. A music/trackNN file stands in for it when the game has one; without
    it the level is silent, as without a disc. Track 0 stops the music."""
    def play_cd_track(track: int) {
        if not self.ready or (track == self.cd_track and self.cd is not None) {
            return;
        }
        self.stop_cd();
        self.cd_track = track;
        library = self.library;
        if track <= 0 or library is None {
            return;
        }
        for name in cd_track_names(track) {
            if name in self.unavailable or not library.exists(name) {
                continue;
            }
            try {
                data = library.read(name);
                music = LoadMusicStreamFromMemory(
                    "." + name.split(".")[-1], data, i32(len(data))
                );
                if not IsMusicValid(music) {
                    raise ValueError("Cannot decode music: " + name);
                }
                music.looping = True;
                self.cd = EmitterAudio(music=music, data=data);
                return;
            } except Exception as error {
                print("Music unavailable:", name, str(error));
                self.unavailable.add(name);
            }
        }
    }

    def stop_cd() {
        voice = self.cd;
        if voice is not None {
            StopMusicStream(voice.music);
            UnloadMusicStream(voice.music);
        }
        self.cd = None;
        self.cd_track = 0;
    }

    """S_StartBackgroundTrack (the `music` command with `once`)."""
    def start_music(intro: str, loop: str = "", once: bool = False) {
        library = self.library;
        if not self.ready or library is None {
            return;
        }
        self.music.start(library, intro, loop, once);
        self.update_streams();
    }

    def stop_music() {
        self.music.stop();
        self.music_channel.clear();
        self.stop_cd();
    }

    """S_RawSamples for a cinematic frame's sound."""
    def cinematic_samples(rate: int, width: int, channels: int, data: bytes) {
        if self.ready {
            self.cinematic_channel.samples(rate, width, channels, data);
        }
    }

    """Silence a cinematic's sound (SCR_StopCinematic)."""
    def end_cinematic() {
        self.cinematic_channel.clear();
    }

    """Keep the streamed channels fed: S_UpdateBackgroundTrack reads on
    while menus are up, and cinematic samples go out as they arrive."""
    def update_streams() {
        library = self.library;
        if not self.ready or library is None {
            return;
        }
        # snd_dma.c: the music's level settles at two thirds of s_musicvolume.
        self.music_channel.gain = self.music_volume.number * 2.0 / 3.0 * self.volume.number / Q3_DEFAULT_VOLUME;
        self.music.update(library, self.music_channel);
        self.music_channel.pump();
        self.cinematic_channel.gain = self.volume.number / Q2_DEFAULT_VOLUME;
        self.cinematic_channel.pump();
        # The CD plays at full volume beside the effects' default level.
        voice = self.cd;
        if voice is not None {
            self.run_loop(voice, 1.0 / Q2_DEFAULT_VOLUME, 0.0, False);
        }
    }

    def close() {
        if not self.ready {
            return;
        }
        self.music.stop();
        self.music_channel.close();
        self.cinematic_channel.close();
        self.stop_cd();
        for flight in self.flights {
            UnloadMusicStream(flight.voice.music);
        }
        self.flights = [];
        held = self.client_voice;
        if held is not None {
            UnloadMusicStream(held.music);
        }
        self.client_voice = None;
        self.client_path = "";
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
