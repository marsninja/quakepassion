"""Films made by code: the games' cinematics (Quake II's .cin, Quake III's
.RoQ) stood in for by a title card that plays like a film: a slow drift of
nebula behind the film's title, with a low drone under it.

What the bake writes for a film is not pictures but the film's recipe, a
few lines of text under the film's own name: a signature, the title, how
long it runs and its seed. The cinematic player (engine/core/cinematic.jac)
knows the signature and plays it with `GeneratedFilm`, which draws each
picture as it is asked for."""
import math;
import struct;
import from games.passion.random { hash_label, mix32 }
import from engine.formats.film { Film, FilmPicture }
import from .field { fbm3 }
import from .image { Picture, Rgb }
import from .glyphs { text_mask }
import from .canvas { Look, cast }

glob FILM_SIGNATURE: bytes = b"QPFILM1\n",
     FILM_WIDTH: int = 320,
     FILM_HEIGHT: int = 240,
     FILM_RATE: int = 15,
     FILM_SOUND_RATE: int = 22050;

"""What a film's name says it shows, as a title."""
def film_title(name: str) -> str {
    stem = name.lower().split("/")[-1].rsplit(".", 1)[0];
    known = {
        "ntro": "QUAKE II", "idlogo": "QUAKEPASSION", "intro": "QUAKE III ARENA", "end": "THE END",
        "demoend": "THE END", "idlog": "QUAKEPASSION"
    };
    if stem in known {
        return known[stem];
    }
    if stem.startswith("eou") {
        return "UNIT " + stem[3:].rstrip("_") + " COMPLETE";
    }
    if stem.startswith("tier") {
        return "TIER " + stem[4:];
    }
    return stem.replace("_", " ").upper();
}

"""The recipe the bake writes in a film's place."""
def film_recipe(name: str, seconds: float) -> bytes {
    text = film_title(name) + "\n" + str(round(max(3.0, min(20.0, seconds)), 2)) + "\n" + str(hash_label(17, name.lower())) + "\n";
    return FILM_SIGNATURE + text.encode("ascii", "replace");
}

def is_film_recipe(data: bytes) -> bool {
    return data[:len(FILM_SIGNATURE)] == FILM_SIGNATURE;
}

"""A title card that plays as a film."""
obj GeneratedFilm(Film) {
    has title: str = "",
        seconds: float = 6.0,
        seed: int = 0,
        title_pixels: Picture | None = None;

    def postinit {
        self.width = FILM_WIDTH;
        self.height = FILM_HEIGHT;
        self.frame_rate = FILM_RATE;
        self.skip_after = 1.0;
        self.escape_skips = True;
    }

    def next_picture() -> FilmPicture | None {
        if float(self.frame) >= self.seconds * float(FILM_RATE) {
            return None;
        }
        t = float(self.frame) / float(FILM_RATE);
        self.frame += 1;
        if self.title_pixels is None {
            mask = text_mask(self.title, FILM_WIDTH, FILM_HEIGHT // 4, 0.8);
            self.title_pixels = cast(mask, Look(ramp=[Rgb(r=0.25, g=0.15, b=0.05), Rgb(r=0.75, g=0.5, b=0.2), Rgb(r=1.0, g=0.85, b=0.5)], depth=2.0));
        }
        # A small nebula drawn at a quarter size and stretched, moving slowly.
        small_w = FILM_WIDTH // 4;
        small_h = FILM_HEIGHT // 4;
        cloud: list[float] = [];
        for y in range(small_h) {
            for x in range(small_w) {
                cloud.append(fbm3(float(x) * 0.06 + t * 0.05, float(y) * 0.06, t * 0.03, 4, 0.55, self.seed));
            }
        }
        fade = min(1.0, t / 1.0, (self.seconds - t) / 1.0);
        pixels = bytearray(FILM_WIDTH * FILM_HEIGHT * 4);
        title = self.title_pixels;
        top = FILM_HEIGHT * 3 // 8;
        for y in range(FILM_HEIGHT) {
            for x in range(FILM_WIDTH) {
                c = cloud[(y // 4) * small_w + (x // 4)];
                glow = max(0.0, c - 0.45) * 2.2;
                r = 0.05 + glow * 0.6;
                g = 0.03 + glow * 0.3;
                b = 0.08 + glow * 0.5;
                if title is not None and y >= top and y < top + title.h {
                    k = (y - top) * FILM_WIDTH + x;
                    a = title.a[k];
                    r = r + (title.r[k] - r) * a;
                    g = g + (title.g[k] - g) * a;
                    b = b + (title.b[k] - b) * a;
                }
                i = (y * FILM_WIDTH + x) * 4;
                pixels[i] = max(0, min(255, int(r * fade * 255.0)));
                pixels[i + 1] = max(0, min(255, int(g * fade * 255.0)));
                pixels[i + 2] = max(0, min(255, int(b * fade * 255.0)));
                pixels[i + 3] = 255;
            }
        }
        # A drone under it: two low tones a fifth apart, fading with the picture.
        count = FILM_SOUND_RATE // FILM_RATE;
        sound = bytearray();
        base = 55.0 * (1.0 + float(mix32(self.seed) % 5) / 10.0);
        for n in range(count) {
            s = (t + float(n) / float(FILM_SOUND_RATE));
            v = 0.2 * fade * (math.sin(2.0 * math.pi * base * s) + 0.6 * math.sin(2.0 * math.pi * base * 1.5 * s));
            sound.extend(struct.pack("<h", max(-32768, min(32767, int(v * 32767.0)))));
        }
        return FilmPicture(
            pixels=bytes(pixels), samples=bytes(sound), sound_rate=FILM_SOUND_RATE, sound_width=2, sound_channels=1
        );
    }
}

"""The film a recipe describes."""
def open_generated_film(data: bytes) -> GeneratedFilm {
    lines = data[len(FILM_SIGNATURE):].decode("ascii", "replace").split("\n");
    title = lines[0] if lines else "";
    seconds = float(lines[1]) if len(lines) > 1 and lines[1] else 6.0;
    seed = int(lines[2]) if len(lines) > 2 and lines[2] else 1;
    return GeneratedFilm(title=title, seconds=seconds, seed=seed);
}
