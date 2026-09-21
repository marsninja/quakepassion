"""Archive-backed gameplay sound palette with explicit native audio ownership."""
import from ..assets.library { AssetLibrary }
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
    }  def InitAudioDevice -> None;  def IsAudioDeviceReady -> bool;  def CloseAudioDevice -> None;  def LoadWaveFromMemory(
        fileType: str, fileData: bytes, dataSize: i32
    ) -> Wave;  def LoadSoundFromWave(wave: Wave) -> Sound;  def UnloadWave(
        wave: Wave
    ) -> None;  def UnloadSound(sound: Sound) -> None;  def PlaySound(
        sound: Sound
    ) -> None;  def SetSoundVolume(sound: Sound, volume: f32) -> None;  def SetSoundPitch(
        sound: Sound, pitch: f32
    ) -> None;
}

obj Feedback {
    has ready: bool = False,
        sounds: list[Sound] = [],
        volume: float = 0.25;

    def open(game: str, directory: str) {
        InitAudioDevice();
        self.ready = IsAudioDeviceReady();
        if not self.ready {
            return;
        }
        library = AssetLibrary(game="q1" if game == "passion" else game);
        library.open(directory + "/id1" if game == "passion" else directory);
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
        } finally {
            library.close();
        }
    }

    def play(kind: int) {
        if not self.ready or kind < 0 or kind >= len(self.sounds) {
            return;
        }
        sound = self.sounds[kind];
        SetSoundVolume(sound, f32(self.volume));
        SetSoundPitch(sound, f32(1.8 if kind == 2 else 1.0));
        PlaySound(sound);
    }

    def close() {
        if not self.ready {
            return;
        }
        for sound in self.sounds {
            UnloadSound(sound);
        }
        self.sounds = [];
        CloseAudioDevice();
        self.ready = False;
    }
}
