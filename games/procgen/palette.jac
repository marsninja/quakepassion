"""Generated palettes: the 256 colours Quake and Quake II draw everything in.

A palette is laid out as the games' were, in rows of sixteen shades of one
family of colour, because the games' rules name colours by their place in
it: Quake's blood is drawn from its fifth row, its explosions climb its
seventh, a player's shirt and trousers are the second and seventh rows
recoloured, and the last thirty-two colours are drawn unlit (fullbright).
So each row here is a family chosen for that role, shaded from dark to
light (or light to dark where the games ran a row that way), and the colours
in the row come from a curve, not from the originals.

A picture is put into a palette by finding each texel's nearest colour among
those allowed; a table over a coarse cube of colours makes that quick."""
import math;
import from .image { Rgb, Picture, hex_rgb, channel_byte }

"""One row: its darkest and lightest colours, and whether it runs light to
dark."""
obj Family {
    has dark: Rgb,
        light: Rgb,
        falling: bool = False;
}

"""A ramp of sixteen shades from a family: a curve through its darkest and
lightest that bends toward warmth in the middle, as paint does."""
def family_shades(family: Family) -> list[Rgb] {
    made: list[Rgb] = [];
    for k in range(16) {
        t = float(k) / 15.0;
        # A gamma bend: more dark shades than light, as the games had.
        bent = math.pow(t, 1.15);
        shade = family.dark.mixed(family.light, bent);
        made.append(shade);
    }
    if family.falling {
        made.reverse();
    }
    return made;
}

"""The families of Quake's rows, in its order: greys, earth browns,
blue-greys, greens, reds, rust, golds, flesh, purples, crimsons, stone
tans, olive greens, yellows, blues, and two rows of fullbright fire and
light."""
def quake_families -> list[Family] {
    return [
        Family(dark=hex_rgb("000000"), light=hex_rgb("ebebeb")),
        Family(dark=hex_rgb("0f0b07"), light=hex_rgb("8f7a5c")),
        Family(dark=hex_rgb("0b0b0f"), light=hex_rgb("8b8bab")),
        Family(dark=hex_rgb("000000"), light=hex_rgb("6b7b4f")),
        Family(dark=hex_rgb("0f0000"), light=hex_rgb("c72b1b")),
        Family(dark=hex_rgb("130b07"), light=hex_rgb("b7733b")),
        Family(dark=hex_rgb("170f00"), light=hex_rgb("e3b337")),
        Family(dark=hex_rgb("0f0b07"), light=hex_rgb("dbab8f")),
        Family(dark=hex_rgb("0b0007"), light=hex_rgb("ab5b9b"), falling=True),
        Family(dark=hex_rgb("130707"), light=hex_rgb("c7636b"), falling=True),
        Family(dark=hex_rgb("170f0b"), light=hex_rgb("c7b39b"), falling=True),
        Family(dark=hex_rgb("070b00"), light=hex_rgb("8ba35b"), falling=True),
        Family(dark=hex_rgb("1b1300"), light=hex_rgb("fbfb4f"), falling=True),
        Family(dark=hex_rgb("00000b"), light=hex_rgb("5b7bdb"), falling=True)
    ];
}

"""Quake's thirty-two fullbright colours: fire from deep orange to white
heat, then reds, light blues, and last the colour a texture leaves clear."""
def quake_fullbrights -> list[Rgb] {
    made: list[Rgb] = [];
    for k in range(16) {
        t = float(k) / 15.0;
        made.append(hex_rgb("7f3b00").mixed(hex_rgb("ffff9b"), t));
    }
    for k in range(8) {
        t = float(k) / 7.0;
        made.append(hex_rgb("9b0000").mixed(hex_rgb("ff4f2f"), t));
    }
    for k in range(4) {
        t = float(k) / 3.0;
        made.append(hex_rgb("3b4fbb").mixed(hex_rgb("b7c7ff"), t));
    }
    made.append(hex_rgb("ffefd7"));
    made.append(hex_rgb("ffffff"));
    made.append(hex_rgb("ffd7a3"));
    # 255: what a "{" texture and a sprite leave transparent.
    made.append(hex_rgb("9f5b53"));
    return made;
}

"""Quake II's families. Its palette was laid out differently: no fullbright
rows, greys first, then families its particles name by place: the
railgun's blues at 0x74 (the eighth row), the BFG's greens at 0xd0 (the
fourteenth), and in the fifteenth the blaster's yellows (0xe0) and then
blood's reds (0xe8), half a row each."""
def quake2_families -> list[Family] {
    return [
        Family(dark=hex_rgb("000000"), light=hex_rgb("efefef")),
        Family(dark=hex_rgb("0b0700"), light=hex_rgb("9b8363")),
        Family(dark=hex_rgb("07070b"), light=hex_rgb("8f8f9f")),
        Family(dark=hex_rgb("070b03"), light=hex_rgb("7b8b53")),
        Family(dark=hex_rgb("130000"), light=hex_rgb("d3432b")),
        Family(dark=hex_rgb("130b03"), light=hex_rgb("c38343")),
        Family(dark=hex_rgb("170f00"), light=hex_rgb("e7c35b")),
        Family(dark=hex_rgb("00030f"), light=hex_rgb("6b9bef")),
        Family(dark=hex_rgb("0f0703"), light=hex_rgb("dfaf93")),
        Family(dark=hex_rgb("0b030b"), light=hex_rgb("a76ba7")),
        Family(dark=hex_rgb("130b07"), light=hex_rgb("c3af97")),
        Family(dark=hex_rgb("0b0b07"), light=hex_rgb("a7a383")),
        Family(dark=hex_rgb("00070b"), light=hex_rgb("5ba3b3")),
        Family(dark=hex_rgb("030b03"), light=hex_rgb("7bdf5b")),
        Family(dark=hex_rgb("3b2b00"), light=hex_rgb("ffff7f")),
        Family(dark=hex_rgb("0f1f2f"), light=hex_rgb("dff3ff"))
    ];
}

obj Palette {
    has colours: list[Rgb] = [],
        # How many colours from the start a lit texel may be (Quake: 224).
        lit_count: int = 256,
        table: list[int] = [],
        table_count: int = 0;

    """The palette as 768 bytes."""
    def bytes768() -> bytes {
        made = bytearray(768);
        for i in range(256) {
            made[i * 3] = channel_byte(self.colours[i].r);
            made[i * 3 + 1] = channel_byte(self.colours[i].g);
            made[i * 3 + 2] = channel_byte(self.colours[i].b);
        }
        return bytes(made);
    }

    """The nearest of the first `count` colours to `c`."""
    def nearest(c: Rgb, count: int) -> int {
        best = 0;
        least = 1.0e9;
        for i in range(min(count, len(self.colours))) {
            p = self.colours[i];
            dr = (p.r - c.r) * 0.30;
            dg = (p.g - c.g) * 0.59;
            db = (p.b - c.b) * 0.11;
            off = dr * dr + dg * dg + db * db;
            if off < least {
                least = off;
                best = i;
            }
        }
        return best;
    }

    """The nearest lit colour, through a table over a cube of 32 steps a
    side, made the first time it is asked."""
    def index_of(c: Rgb) -> int {
        if self.table_count != self.lit_count {
            self.table = [];
            for ri in range(32) {
                for gi in range(32) {
                    for bi in range(32) {
                        self.table.append(
                            self.nearest(
                                Rgb(r=(float(ri) + 0.5) / 32.0, g=(float(gi) + 0.5) / 32.0, b=(float(bi) + 0.5) / 32.0),
                                self.lit_count
                            )
                        );
                    }
                }
            }
            self.table_count = self.lit_count;
        }
        ri = max(0, min(31, int(c.r * 32.0)));
        gi = max(0, min(31, int(c.g * 32.0)));
        bi = max(0, min(31, int(c.b * 32.0)));
        return self.table[(ri * 32 + gi) * 32 + bi];
    }

    """A picture as numbers into the palette, with a little ordered dither so
    that smooth ramps do not band. Where `glow` is given and over a half, the
    texel takes the nearest fullbright colour instead (Quake's lights); where
    the picture is clear, `clear_index`."""
    def indices(picture: Picture, glow: list[float] = [], clear_index: int = 255) -> bytes {
        made = bytearray(picture.w * picture.h);
        bayer = [0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0];
        for y in range(picture.h) {
            for x in range(picture.w) {
                i = y * picture.w + x;
                if picture.a[i] < 0.5 {
                    made[i] = clear_index;
                    continue;
                }
                d = (bayer[(y % 4) * 4 + (x % 4)] / 16.0 - 0.47) / 40.0;
                c = Rgb(r=picture.r[i] + d, g=picture.g[i] + d, b=picture.b[i] + d);
                if len(glow) > i and glow[i] > 0.5 {
                    best = self.lit_count;
                    least = 1.0e9;
                    for k in range(self.lit_count, 255) {
                        p = self.colours[k];
                        off = (p.r - c.r) ** 2 + (p.g - c.g) ** 2 + (p.b - c.b) ** 2;
                        if off < least {
                            least = off;
                            best = k;
                        }
                    }
                    made[i] = best;
                } else {
                    made[i] = self.index_of(c);
                }
            }
        }
        return bytes(made);
    }

    """Numbers into the palette back to a picture."""
    def picture_of(indices: bytes, w: int, h: int) -> Picture {
        made = Picture(w=w, h=h);
        for i in range(w * h) {
            made.put(i, self.colours[int(indices[i])]);
        }
        return made;
    }
}

"""Quake's palette, generated."""
def quake_palette -> Palette {
    colours: list[Rgb] = [];
    for family in quake_families() {
        colours.extend(family_shades(family));
    }
    colours.extend(quake_fullbrights());
    return Palette(colours=colours, lit_count=224);
}

"""Quake II's palette, generated: sixteen families (the fifteenth split into
yellows and reds), the last colour clear."""
def quake2_palette -> Palette {
    colours: list[Rgb] = [];
    for family in quake2_families() {
        colours.extend(family_shades(family));
    }
    for k in range(8) {
        t = float(k) / 7.0;
        colours[224 + k] = hex_rgb("ffff9b").mixed(hex_rgb("c78b0b"), t);
        colours[232 + k] = hex_rgb("ff4b2b").mixed(hex_rgb("5b0000"), t);
    }
    colours[255] = hex_rgb("9f5b53");
    return Palette(colours=colours, lit_count=255);
}

"""Quake's colormap.lmp: 64 rows of light, brightest first, each the 256
colours as they look at that light, put back into the palette; row 32 is
the colours themselves. The fullbright colours stay as they are in every
row. One more row (the 65th) follows, as the file has it."""
def quake_colormap(palette: Palette) -> bytes {
    made = bytearray();
    for level in range(64) {
        k = 2.0 - float(level) / 32.0;
        for i in range(256) {
            if i >= palette.lit_count {
                made.append(i);
                continue;
            }
            made.append(palette.index_of(palette.colours[i].scaled(k)));
        }
    }
    made.extend(bytes(range(256)));
    return bytes(made);
}
