"""Films and end pictures on the screen (Quake II client/cl_cin.c, Quake III
code/client/cl_cin.c).

One player runs every film. The decoder (engine/formats/film.jac `Film`)
supplies the pictures and sound and the rules its client ran it by:

- A Quake II .cin runs at 14 frames a second on the real clock. Like
  SCR_RunCinematic, each step reads at most one frame ahead: the frame just
  read waits as `pending` (its sound already queued, S_RawSamples) while the
  one before it is shown, so the picture trails the sound by a frame, and a
  slow step stretches the film rather than dropping frames. A key finishes
  it after its first second.
- A Quake III RoQ runs at 30. CIN_RunCinematic reads pictures until as many
  are decoded as the clock asks for and shows the newest, so a slow step is
  caught up at once. Any key press finishes it; one played with CIN_hold
  (end.RoQ) keeps its last picture up until then.

Menus pause a film. A .pcx picture (SCR_PlayCinematic's static image) stays
until a key is pressed. Pictures are stretched over the whole window
(DrawStretchRaw)."""
import from ..formats.film { Film, FilmPicture }
import from ..formats.q2.cin { open_cin, cinematic_rgba }
import from ..formats.q3.roq { open_roq }
import from ..formats.q2.model { parse_pcx }
import from games.procgen.film { is_film_recipe, open_generated_film }
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

# CL_PlayCinematic_f: these two are played with CIN_hold.
glob HELD_FILMS: list[str] = ["end.roq", "demoend.roq"];

"""The decoder for a film file, chosen by its extension: Quake II's .cin
or Quake III's .RoQ."""
def open_film(name: str, data: bytes) -> Film {
    lowered = name.lower();
    # A generated film (games/procgen/film.jac) is its recipe, under the
    # film's own name.
    if is_film_recipe(data) {
        return open_generated_film(data);
    }
    if lowered.endswith(".roq") {
        return open_roq(data, lowered.split("/")[-1] in HELD_FILMS);
    }
    return open_cin(data);
}

obj CinematicPlayer {
    has name: str = "",
        active: bool = False,
        film: Film | None = None,
        width: int = 0,
        height: int = 0,
        # The picture on screen (cin.pic, cin.buf), the one read ahead of it
        # (cin.pic_pending) and the palette in force (cl.cinematicpalette;
        # empty when the pictures are RGBA).
        pic: bytes = b"",
        pending: bytes = b"",
        palette: bytes = b"",
        # Pictures read so far (cl.cinematicframe, numQuads), -1 for a still.
        frame: int = 0,
        # Real seconds since the film began (cls.realtime - cl.cinematictime).
        elapsed: float = 0.0,
        # FMV_IDLE: a held film has run out and waits on its last picture.
        idle: bool = False,
        texture: int = 0,
        texture_width: int = 0,
        texture_height: int = 0,
        stale: bool = False,
        # Keys already held when the picture came up must be let go first.
        armed: bool = False;

    """SCR_PlayCinematic and CL_PlayCinematic_f for a film: open its decoder
    and show the first picture at once."""
    def play(name: str, data: bytes, audio: Feedback) {
        self.stop(audio);
        film = open_film(name, data);
        self.name = name;
        self.film = film;
        self.frame = 0;
        self.elapsed = 0.0;
        self.active = True;
        self.armed = False;
        first = self.read(audio);
        if first is None {
            self.active = False;
            return;
        }
        self.width = film.width;
        self.height = film.height;
        self.pic = first.pixels;
        self.stale = True;
        if not film.trails {
            # CL_PlayCinematic_f waits for the first picture, which
            # CIN_RunCinematic decodes once the clock asks for one.
            self.elapsed = float(self.frame) / float(film.frame_rate);
        }
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

    """SCR_ReadNextFrame and RoQInterrupt: decode a picture and queue its
    sound."""
    def read(audio: Feedback) -> FilmPicture | None {
        film = self.film;
        if film is None {
            return None;
        }
        found = film.next_picture();
        if found is None {
            return None;
        }
        if found.samples {
            audio.cinematic_samples(
                found.sound_rate, found.sound_width, found.sound_channels, found.samples
            );
        }
        if found.palette != self.palette {
            self.palette = found.palette;
            self.stale = True;
        }
        self.frame = film.frame;
        return found;
    }

    """SCR_RunCinematic and CIN_RunCinematic: advance by `dt` real seconds.
    True once the film has run out (SCR_FinishCinematic's moment, FMV_EOF)."""
    def advance(dt: float, paused: bool, audio: Feedback) -> bool {
        film = self.film;
        if not self.active or film is None or self.frame == -1 or self.idle {
            return False;
        }
        rate = float(film.frame_rate);
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
        if not film.trails {
            while self.frame < target {
                found = self.read(audio);
                if found is None {
                    self.idle = film.holds;
                    return not film.holds;
                }
                self.pic = found.pixels;
                self.stale = True;
            }
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

    """Whether a key ends what is showing. Quake II's cl_input.c CL_SendCmd:
    any held key or button (BUTTON_ANY) finishes a film after its first
    second, and a still picture at once. Quake III's CL_KeyEvent: any key
    press. A key still held from before the picture came up counts once it
    has been let go, so walking or firing into an exit does not skip the
    film."""
    def wants_skip(held: bool) -> bool {
        if not held {
            self.armed = True;
            return False;
        }
        film = self.film;
        after = film.skip_after if film is not None else 0.0;
        return self.active and self.armed and self.elapsed > after;
    }

    """Whether Escape ends the film as any other key does (Quake III), where
    Quake II's opens the menu over it."""
    def escape_skips -> bool {
        film = self.film;
        return self.active and film is not None and film.escape_skips;
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
        # Stills and RoQ pictures arrive as RGBA; .cin frames are palette
        # indices.
        rgba = cinematic_rgba(self.pic, self.palette) if self.palette else self.pic;
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
        if self.film is not None {
            audio.end_cinematic();
        }
        self.active = False;
        self.film = None;
        self.idle = False;
        self.pic = b"";
        self.pending = b"";
        self.palette = b"";
        self.name = "";
        self.frame = 0;
        self.elapsed = 0.0;
    }

    def close(audio: Feedback) {
        self.stop(audio);
        self.release();
    }
}
