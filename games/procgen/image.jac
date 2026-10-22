"""Colour pictures made from fields: three channels and a coverage, each from
0 to 1. A field becomes colour through a ramp (a list of colours it runs
along), pictures are laid over each other through a field used as a mask,
and light and dirt darken them through fields of their own."""
import from .field { Field }

"""A colour, each part from 0 to 1."""
obj Rgb {
    has r: float = 0.0,
        g: float = 0.0,
        b: float = 0.0;

    def scaled(k: float) -> Rgb {
        return Rgb(r=self.r * k, g=self.g * k, b=self.b * k);
    }

    def mixed(other: Rgb, t: float) -> Rgb {
        return Rgb(
            r=self.r + (other.r - self.r) * t, g=self.g + (other.g - self.g) * t, b=self.b + (other.b - self.b) * t
        );
    }
}

"""A colour from its bytes, as `hex_rgb("8a6d4f")`."""
def hex_rgb(text: str) -> Rgb {
    return Rgb(
        r=float(int(text[0:2], 16)) / 255.0, g=float(int(text[2:4], 16)) / 255.0, b=float(int(text[4:6], 16)) / 255.0
    );
}

obj Picture {
    has w: int,
        h: int,
        r: list[float] = [],
        g: list[float] = [],
        b: list[float] = [],
        a: list[float] = [];

    def postinit {
        count = self.w * self.h;
        if len(self.r) != count {
            self.r = [0.0] * count;
            self.g = [0.0] * count;
            self.b = [0.0] * count;
        }
        if len(self.a) != count {
            self.a = [1.0] * count;
        }
    }

    def colour(i: int) -> Rgb {
        return Rgb(r=self.r[i], g=self.g[i], b=self.b[i]);
    }

    def put(i: int, c: Rgb) {
        self.r[i] = c.r;
        self.g[i] = c.g;
        self.b[i] = c.b;
    }

    """Four bytes a texel, a row at a time from the top."""
    def rgba() -> bytes {
        made = bytearray(self.w * self.h * 4);
        for i in range(self.w * self.h) {
            made[i * 4] = channel_byte(self.r[i]);
            made[i * 4 + 1] = channel_byte(self.g[i]);
            made[i * 4 + 2] = channel_byte(self.b[i]);
            made[i * 4 + 3] = channel_byte(self.a[i]);
        }
        return bytes(made);
    }

    """Three bytes a texel."""
    def rgb_bytes() -> bytes {
        made = bytearray(self.w * self.h * 3);
        for i in range(self.w * self.h) {
            made[i * 3] = channel_byte(self.r[i]);
            made[i * 3 + 1] = channel_byte(self.g[i]);
            made[i * 3 + 2] = channel_byte(self.b[i]);
        }
        return bytes(made);
    }
}

def channel_byte(value: float) -> int {
    return max(0, min(255, int(value * 255.0 + 0.5)));
}

"""A picture of one colour."""
def filled(w: int, h: int, c: Rgb) -> Picture {
    count = w * h;
    return Picture(w=w, h=h, r=[c.r] * count, g=[c.g] * count, b=[c.b] * count);
}

"""The colour `t` (0 to 1) of the way along a ramp of evenly spaced colours."""
def along(ramp: list[Rgb], t: float) -> Rgb {
    if len(ramp) == 1 {
        return ramp[0];
    }
    at = max(0.0, min(1.0, t)) * float(len(ramp) - 1);
    low = min(len(ramp) - 2, int(at));
    return ramp[low].mixed(ramp[low + 1], at - float(low));
}

"""A field coloured along a ramp."""
def ramped(source: Field, ramp: list[Rgb]) -> Picture {
    made = Picture(w=source.w, h=source.h);
    for i in range(source.w * source.h) {
        made.put(i, along(ramp, source.v[i]));
    }
    return made;
}

"""`top` laid over `under` where `mask` is 1, blending where it is between."""
def masked(under: Picture, top: Picture, mask: Field) -> Picture {
    made = Picture(w=under.w, h=under.h);
    for i in range(under.w * under.h) {
        t = max(0.0, min(1.0, mask.v[i]));
        made.r[i] = under.r[i] + (top.r[i] - under.r[i]) * t;
        made.g[i] = under.g[i] + (top.g[i] - under.g[i]) * t;
        made.b[i] = under.b[i] + (top.b[i] - under.b[i]) * t;
        made.a[i] = under.a[i] + (top.a[i] - under.a[i]) * t;
    }
    return made;
}

"""The picture lit by a field: 0.5 leaves a texel as it is, 0 makes it
black, 1 twice as bright (clamped); `strength` scales the effect."""
def lit(source: Picture, light: Field, strength: float = 1.0) -> Picture {
    made = Picture(w=source.w, h=source.h, a=list(source.a));
    for i in range(source.w * source.h) {
        k = 1.0 + (light.v[i] * 2.0 - 1.0) * strength;
        made.r[i] = max(0.0, min(1.0, source.r[i] * k));
        made.g[i] = max(0.0, min(1.0, source.g[i] * k));
        made.b[i] = max(0.0, min(1.0, source.b[i] * k));
    }
    return made;
}

"""The picture darkened toward `tint` where `amount` is high (dirt, soot,
rust)."""
def stained(source: Picture, amount: Field, tint: Rgb, strength: float = 1.0) -> Picture {
    made = Picture(w=source.w, h=source.h, a=list(source.a));
    for i in range(source.w * source.h) {
        t = max(0.0, min(1.0, amount.v[i] * strength));
        made.r[i] = source.r[i] + (tint.r - source.r[i]) * t;
        made.g[i] = source.g[i] + (tint.g - source.g[i]) * t;
        made.b[i] = source.b[i] + (tint.b - source.b[i]) * t;
    }
    return made;
}

"""The picture at another size, by nearest texel (a generated picture is made
at its own size; this fits one to a slot that asks for another)."""
def resized(source: Picture, w: int, h: int) -> Picture {
    made = Picture(w=w, h=h);
    for y in range(h) {
        sy = min(source.h - 1, y * source.h // max(1, h));
        for x in range(w) {
            sx = min(source.w - 1, x * source.w // max(1, w));
            j = sy * source.w + sx;
            i = y * w + x;
            made.r[i] = source.r[j];
            made.g[i] = source.g[j];
            made.b[i] = source.b[j];
            made.a[i] = source.a[j];
        }
    }
    return made;
}

"""The picture at another size, sampled smoothly and wrapping at its edges,
so a picture that tiles still tiles when enlarged."""
def enlarged(source: Picture, w: int, h: int) -> Picture {
    made = Picture(w=w, h=h);
    for y in range(h) {
        fy = (float(y) + 0.5) * float(source.h) / float(h) - 0.5;
        y0 = int(fy + float(source.h)) - source.h;
        ty = fy - float(y0);
        r0 = (y0 % source.h + source.h) % source.h;
        r1 = (r0 + 1) % source.h;
        for x in range(w) {
            fx = (float(x) + 0.5) * float(source.w) / float(w) - 0.5;
            x0 = int(fx + float(source.w)) - source.w;
            tx = fx - float(x0);
            c0 = (x0 % source.w + source.w) % source.w;
            c1 = (c0 + 1) % source.w;
            a = r0 * source.w + c0;
            b = r0 * source.w + c1;
            c = r1 * source.w + c0;
            d = r1 * source.w + c1;
            i = y * w + x;
            made.r[i] = (source.r[a] * (1.0 - tx) + source.r[b] * tx) * (1.0 - ty) + (source.r[c] * (1.0 - tx) + source.r[d] * tx) * ty;
            made.g[i] = (source.g[a] * (1.0 - tx) + source.g[b] * tx) * (1.0 - ty) + (source.g[c] * (1.0 - tx) + source.g[d] * tx) * ty;
            made.b[i] = (source.b[a] * (1.0 - tx) + source.b[b] * tx) * (1.0 - ty) + (source.b[c] * (1.0 - tx) + source.b[d] * tx) * ty;
            made.a[i] = (source.a[a] * (1.0 - tx) + source.a[b] * tx) * (1.0 - ty) + (source.a[c] * (1.0 - tx) + source.a[d] * tx) * ty;
        }
    }
    return made;
}

"""The picture graded toward a tone (red, green, blue, spread, saturation;
games/procgen/tones.jac): its mean colour moved to the tone's, its lightness
spread about that mean scaled to the tone's spread and its colours' distance
from grey scaled to the tone's saturation, each by `strength` (1 all the
way). Measured over the texels it shows (coverage of a half or more); its
coverage is kept."""
def graded(source: Picture, tone: list[float], strength: float = 0.8) -> Picture {
    count = source.w * source.h;
    if len(tone) < 5 or count == 0 {
        return source;
    }
    shown = 0;
    mr = 0.0;
    mg = 0.0;
    mb = 0.0;
    for i in range(count) {
        if source.a[i] >= 0.5 {
            shown += 1;
            mr += source.r[i];
            mg += source.g[i];
            mb += source.b[i];
        }
    }
    every = shown < 4;
    if every {
        shown = count;
        mr = sum(source.r);
        mg = sum(source.g);
        mb = sum(source.b);
    }
    mr /= float(shown);
    mg /= float(shown);
    mb /= float(shown);
    mean_luma = 0.299 * mr + 0.587 * mg + 0.114 * mb;
    spread = 0.0;
    saturation = 0.0;
    for i in range(count) {
        if every or source.a[i] >= 0.5 {
            luma = 0.299 * source.r[i] + 0.587 * source.g[i] + 0.114 * source.b[i];
            spread += (luma - mean_luma) * (luma - mean_luma);
            saturation += (abs(source.r[i] - luma - (mr - mean_luma)) + abs(source.g[i] - luma - (mg - mean_luma)) + abs(source.b[i] - luma - (mb - mean_luma))) / 3.0;
        }
    }
    spread = (spread / float(shown)) ** 0.5;
    saturation /= float(shown);
    k = 1.0 + (tone[3] / max(spread, 0.001) - 1.0) * strength;
    ks = 1.0 + (tone[4] / max(saturation, 0.001) - 1.0) * strength;
    tr = mr + (tone[0] - mr) * strength;
    tg = mg + (tone[1] - mg) * strength;
    tb = mb + (tone[2] - mb) * strength;
    made = Picture(w=source.w, h=source.h, a=list(source.a));
    for i in range(count) {
        luma = 0.299 * source.r[i] + 0.587 * source.g[i] + 0.114 * source.b[i];
        lift = (luma - mean_luma) * k;
        made.r[i] = max(0.0, min(1.0, tr + lift + (source.r[i] - luma - (mr - mean_luma)) * ks));
        made.g[i] = max(0.0, min(1.0, tg + lift + (source.g[i] - luma - (mg - mean_luma)) * ks));
        made.b[i] = max(0.0, min(1.0, tb + lift + (source.b[i] - luma - (mb - mean_luma)) * ks));
    }
    return made;
}

"""A glow (a picture added over what is behind it) brought to a mean
brightness and saturation by a gain alone, so its black stays black:
`luma` the mean the picture should have, `saturation` its mean distance
from grey."""
def glowed(source: Picture, luma: float, saturation: float) -> Picture {
    count = source.w * source.h;
    if count == 0 {
        return source;
    }
    mean = 0.0;
    spread = 0.0;
    for i in range(count) {
        y = 0.299 * source.r[i] + 0.587 * source.g[i] + 0.114 * source.b[i];
        mean += y;
        spread += (abs(source.r[i] - y) + abs(source.g[i] - y) + abs(source.b[i] - y)) / 3.0;
    }
    mean /= float(count);
    spread /= float(count);
    if mean <= 1.0e-4 {
        return source;
    }
    k = max(0.25, min(2.0, luma / mean));
    c = max(0.2, min(2.0, saturation / max(1.0e-4, spread * k)));
    made = Picture(w=source.w, h=source.h, a=list(source.a));
    for i in range(count) {
        y = 0.299 * source.r[i] + 0.587 * source.g[i] + 0.114 * source.b[i];
        made.r[i] = max(0.0, min(1.0, k * (y + (source.r[i] - y) * c)));
        made.g[i] = max(0.0, min(1.0, k * (y + (source.g[i] - y) * c)));
        made.b[i] = max(0.0, min(1.0, k * (y + (source.b[i] - y) * c)));
    }
    return made;
}
