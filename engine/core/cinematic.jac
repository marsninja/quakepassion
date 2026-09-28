"""Quake II cinematics and end pictures on the screen (client/cl_cin.c).

A .cin film runs at 14 frames a second on the real clock. Like
SCR_RunCinematic, each step reads at most one frame ahead: the frame just
read waits as `pending` (its sound already queued, S_RawSamples) while the
one before it is shown, so the picture trails the sound by a frame, and a
slow step stretches the film rather than dropping frames. Menus pause it.
A .pcx picture (SCR_PlayCinematic's static image) stays until a key is
pressed. Pictures are stretched over the whole window (DrawStretchRaw)."""
import from ..formats.q2.cin { CinDecoder, CinFrame, open_cin, CIN_FRAME_RATE }
import from ..formats.q2.model { parse_pcx }
import from ..audio.feedback { Feedback }
import from vendor.raylib {
    def rlLoadTexture(
        data: bytes, width: i32, height: i32, format: i32, mipmapCount: i32
    ) -> u32;  def rlUpdateTexture(
        id: u32, offsetX: i32, offsetY: i32, width: i32, height: i32, format: i32, data: bytes
    ) -> None;  def rlUnloadTexture(id: u32) -> None;  def rlTextureParameters(
        id: u32, param: i32, value: i32
    ) -> None;  def rlSetTexture(id: u32) -> None;  def rlBegin(mode: i32) -> None;  def rlEnd -> None;  def rlTexCoord2f(
        x: f32, y: f32
    ) -> None;  def rlVertex2f(x: f32, y: f32) -> None;  def rlColor4ub(
        r: u8, g: u8, b: u8, a: u8
    ) -> None;
}

"""Palette indices to opaque RGBA through a 768-byte palette."""
def cinematic_rgba(pixels: bytes, palette: bytes) -> bytes {
    count = len(pixels);
    rgba = bytearray(count * 4);
    for index in range(count) {
        source = int(pixels[index]) * 3;
        target = index * 4;
        rgba[target] = palette[source];
        rgba[target + 1] = palette[source + 1];
        rgba[target + 2] = palette[source + 2];
        rgba[target + 3] = 255;
    }
    return bytes(rgba);
}

obj CinematicPlayer {
    has name: str = "",
        active: bool = False,
        decoder: CinDecoder | None = None,
        width: int = 0,
        height: int = 0,
        # cin.pic, cin.pic_pending and cl.cinematicpalette.
        pic: bytes = b"",
        pending: bytes = b"",
        palette: bytes = b"",
        # cl.cinematicframe: frames read so far, -1 for a still picture.
        frame: int = 0,
        # cls.realtime - cl.cinematictime, in seconds.
        elapsed: float = 0.0,
        texture: int = 0,
        texture_width: int = 0,
        texture_height: int = 0,
        stale: bool = False,
        # Keys already held when the picture came up must be let go first.
        armed: bool = False;

    """SCR_PlayCinematic for a film: the header and trees, then the first
    frame at once."""
    def play(name: str, data: bytes, audio: Feedback) {
        self.stop(audio);
        decoder = open_cin(data);
        self.name = name;
        self.decoder = decoder;
        self.width = decoder.header.width;
        self.height = decoder.header.height;
        self.frame = 0;
        self.elapsed = 0.0;
        self.active = True;
        self.armed = False;
        first = self.read(audio);
        if first is None {
            self.active = False;
            return;
        }
        self.pic = first.pixels;
        self.stale = True;
    }

    """SCR_PlayCinematic for a .pcx: a still picture with its palette."""
    def show(name: str, data: bytes, audio: Feedback) {
        self.stop(audio);
        image = parse_pcx(data, name);
        self.name = name;
        self.width = image.width;
        self.height = image.height;
        self.frame = -1;
        # cl.cinematictime = 1: a key may leave it at once.
        self.elapsed = 1000000.0;
        self.pic = image.pixels;
        self.palette = b"";
        self.active = True;
        self.armed = False;
        self.stale = True;
    }

    """SCR_ReadNextFrame: decode a frame and queue its sound."""
    def read(audio: Feedback) -> CinFrame | None {
        decoder = self.decoder;
        if decoder is None {
            return None;
        }
        found = decoder.next_frame();
        if found is None {
            return None;
        }
        header = decoder.header;
        if found.samples {
            audio.cinematic_samples(
                header.sound_rate, header.sound_width, header.sound_channels, found.samples
            );
        }
        if found.palette != self.palette {
            self.palette = found.palette;
            self.stale = True;
        }
        self.frame = decoder.frame;
        return found;
    }

    """SCR_RunCinematic: advance by `dt` real seconds. True once the film has
    run out (SCR_FinishCinematic's moment)."""
    def advance(dt: float, paused: bool, audio: Feedback) -> bool {
        if not self.active or self.frame == -1 {
            return False;
        }
        rate = float(CIN_FRAME_RATE);
        if paused {
            # The clock is held where the frames read so far put it.
            self.elapsed = float(self.frame) / rate;
            return False;
        }
        self.elapsed += dt;
        target = int(self.elapsed * rate);
        if target <= self.frame {
            return False;
        }
        if target > self.frame + 1 {
            # A dropped frame: the film slows rather than skipping.
            self.elapsed = float(self.frame) / rate;
        }
        if self.pending {
            self.pic = self.pending;
            self.stale = True;
        }
        self.pending = b"";
        following = self.read(audio);
        if following is None {
            return True;
        }
        self.pending = following.pixels;
        return False;
    }

    """cl_input.c CL_SendCmd: any held key or button (BUTTON_ANY) finishes a
    film after its first second, and a still picture at once. A key still
    held from before the picture came up counts once it has been let go, so
    walking or firing into an exit does not skip the film."""
    def wants_skip(held: bool) -> bool {
        if not held {
            self.armed = True;
            return False;
        }
        return self.active and self.armed and self.elapsed > 1.0;
    }

    """SCR_DrawCinematic: the current picture stretched over the window."""
    def draw(width: int, height: int) {
        if not self.active or not self.pic {
            return;
        }
        if self.stale {
            self.upload();
        }
        if self.texture == 0 {
            return;
        }
        rlSetTexture(u32(self.texture));
        rlBegin(i32(7));
        rlColor4ub(u8(255), u8(255), u8(255), u8(255));
        rlTexCoord2f(f32(0.0), f32(0.0));
        rlVertex2f(f32(0.0), f32(0.0));
        rlTexCoord2f(f32(0.0), f32(1.0));
        rlVertex2f(f32(0.0), f32(height));
        rlTexCoord2f(f32(1.0), f32(1.0));
        rlVertex2f(f32(width), f32(height));
        rlTexCoord2f(f32(1.0), f32(0.0));
        rlVertex2f(f32(width), f32(0.0));
        rlEnd();
        rlSetTexture(u32(0));
    }

    def upload() {
        self.stale = False;
        # A still picture arrives as RGBA; film frames are palette indices.
        rgba = self.pic if self.frame == -1 else cinematic_rgba(self.pic, self.palette);
        if len(rgba) != self.width * self.height * 4 {
            return;
        }
        if self.texture != 0
            and self.texture_width == self.width
            and self.texture_height == self.height {
            rlUpdateTexture(
                u32(self.texture), i32(0), i32(0), i32(self.width), i32(self.height), i32(7), rgba
            );
            return;
        }
        self.release();
        self.texture = int(rlLoadTexture(rgba, i32(self.width), i32(self.height), i32(7), i32(1)));
        self.texture_width = self.width;
        self.texture_height = self.height;
        if self.texture != 0 {
            # Linear filtering, as the GL renderer stretches cinematics.
            rlTextureParameters(u32(self.texture), i32(10241), i32(9729));
            rlTextureParameters(u32(self.texture), i32(10240), i32(9729));
        }
    }

    def release() {
        if self.texture != 0 {
            rlUnloadTexture(u32(self.texture));
        }
        self.texture = 0;
        self.texture_width = 0;
        self.texture_height = 0;
    }

    """SCR_StopCinematic: drop the film and its queued sound."""
    def stop(audio: Feedback) {
        if self.decoder is not None {
            audio.end_cinematic();
        }
        self.active = False;
        self.decoder = None;
        self.pic = b"";
        self.pending = b"";
        self.name = "";
        self.frame = 0;
        self.elapsed = 0.0;
    }

    def close(audio: Feedback) {
        self.stop(audio);
        self.release();
    }
}
