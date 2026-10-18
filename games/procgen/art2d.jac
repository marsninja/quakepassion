"""The 2D art: console fonts, the status bar's numbers and its backgrounds,
item, weapon and ammo icons, the status bar's face, plaques and menu
titles, crosshairs, level shots. Each picture is chosen from its name and
drawn at the size the game's own has.

Everything is drawn with the stroke font (games/procgen/glyphs.jac) and the
shapes of games/procgen/canvas.jac, cast in each game's colours: Quake's
bronze and rust, Quake II's green and amber, Quake III's chrome and red."""
import math;
import from games.passion.random { hash_label, mix32 }
import from .field { Field, fbm, lattice }
import from .image { Picture, Rgb, hex_rgb, filled, along }
import from .canvas { Look, cast, laid_over, stroke, polygon, disc, box, carved }
import from .glyphs { draw_glyph, draw_text, text_mask, text_width }
import from .textures { paint_named }
import from engine.render.arena_screens { PROP_MAP, PROP_HEIGHT }

def ramp_text(text: str) -> list[Rgb] {
    return [hex_rgb(word) for word in text.split(",")];
}

"""Each game's looks: its numbers, its alternate (warning) numbers, its
icons and its text."""
def look_of(game: str, kind: str) -> Look {
    if game == "q1" {
        if kind == "alt" {
            return Look(ramp=ramp_text("3b0b07,8b1b0b,d34b1b,ffab5b"), depth=3.0);
        }
        if kind == "text" {
            return Look(ramp=ramp_text("4b4b4b,9b9b9b,dbdbdb,ffffff"), depth=1.5, shadow=False, outline_width=0, soft=0);
        }
        if kind == "bronze" {
            return Look(ramp=ramp_text("2b1b07,7b4b17,c38b2b,f3cb6b"), depth=1.5, shadow=False, outline_width=0, soft=0);
        }
        return Look(ramp=ramp_text("2b1b07,7b4b17,c38b2b,f3cb6b"), depth=3.0);
    }
    if game == "q2" {
        if kind == "alt" {
            return Look(ramp=ramp_text("3b0b03,9b2b0b,e3631b,ffbb5b"), depth=2.5);
        }
        if kind == "text" {
            return Look(ramp=ramp_text("3b4b2b,7b9b5b,bbdb8b,f3ffcb"), depth=1.5, shadow=False, outline_width=0, soft=0);
        }
        return Look(ramp=ramp_text("1b2b0b,4b7b1b,9bc33b,e3ff8b"), depth=2.5);
    }
    if kind == "alt" {
        return Look(ramp=ramp_text("3b0303,9b0b0b,ff3b2b,ffbbab"), depth=3.0);
    }
    if kind == "text" {
        return Look(ramp=ramp_text("5b5b5b,ababab,ebebeb,ffffff"), depth=1.5, shadow=False, outline_width=0, soft=0);
    }
    return Look(ramp=ramp_text("2b2b33,6b6b7b,c3c3d3,ffffff"), depth=3.0);
}

"""A sheet of 16 by 16 characters, Quake's console font: the first half
the font, the second the same in its alternate colour. `transparent` is the
colour the game skips (Quake's black, a clear texel for Quake III)."""
def font_sheet(w: int, h: int, game: str) -> Picture {
    cell_w = float(w) / 16.0;
    cell_h = float(h) / 16.0;
    unit = min(cell_w / 5.5, cell_h / 7.5);
    width = max(1.0, unit * 1.0);
    low = Field(w=w, h=h);
    high = Field(w=w, h=h);
    for code in range(256) {
        column = code % 16;
        row = code // 16;
        base = code % 128;
        character = "";
        if base >= 32 and base < 127 {
            character = chr(base);
        } elif base >= 18 and base <= 27 {
            # Quake's small digits.
            character = chr(48 + base - 18);
        } elif base == 16 or base == 17 {
            character = "[" if base == 16 else "]";
        } elif base == 30 or base == 31 {
            character = "-";
        }
        if not character {
            continue;
        }
        x = float(column) * cell_w + (cell_w - unit * 4.0) * 0.5;
        y = float(row) * cell_h + (cell_h - unit * 6.0) * 0.5 - unit * 0.3;
        draw_glyph(high if code >= 128 or (base >= 18 and base <= 27) else low, character, x, y, unit, width);
    }
    first = cast(low, look_of(game, "text"));
    second = cast(high, look_of(game, "bronze"));
    return laid_over(first, second);
}

"""Quake III's proportional font (menu/art/font1_prop): each character drawn
in the box the game's table (PROP_MAP) gives it."""
def prop_font(w: int, h: int, game: str) -> Picture {
    mask = Field(w=w, h=h);
    sx = float(w) / 256.0;
    sy = float(h) / 256.0;
    for code in range(len(PROP_MAP)) {
        place = PROP_MAP[code];
        if place[2] <= 0 {
            continue;
        }
        character = chr(32 + code);
        unit = float(PROP_HEIGHT) * sy / 7.0;
        glyph_w = unit * 4.0;
        x = float(place[0]) * sx + (float(place[2]) * sx - glyph_w) * 0.5;
        y = float(place[1]) * sy + unit * 0.4;
        draw_glyph(mask, character.upper(), x, y, unit, max(1.0, unit * 0.7));
    }
    return cast(mask, Look(ramp=ramp_text("7b7b7b,c3c3c3,ffffff,ffffff"), depth=1.0, shadow=False, outline_width=0, soft=0));
}

"""One of the status bar's big characters: a digit, a minus, a colon or a
slash."""
def big_character(character: str, w: int, h: int, look: Look) -> Picture {
    mask = Field(w=w, h=h);
    unit = min(float(w) / 5.2, float(h) / 7.2);
    x = (float(w) - unit * 4.0) * 0.5;
    y = (float(h) - unit * 6.0) * 0.5;
    draw_glyph(mask, character, x, y, unit, max(1.5, unit * 1.3));
    return cast(mask, look);
}

"""An icon, drawn from what its name says it shows."""
def icon(name: str, w: int, h: int, game: str) -> Picture {
    lower = name.lower();
    mask = Field(w=w, h=h);
    fw = float(w);
    fh = float(h);
    cx = fw * 0.5;
    cy = fh * 0.5;
    s = min(fw, fh);
    look = look_of(game, "icon");
    if "health" in lower or "medkit" in lower or "medipak" in lower or "stimpack" in lower {
        box(mask, cx - s * 0.12, cy - s * 0.38, cx + s * 0.12, cy + s * 0.38, s * 0.04);
        box(mask, cx - s * 0.38, cy - s * 0.12, cx + s * 0.38, cy + s * 0.12, s * 0.04);
        look = Look(ramp=ramp_text("3b0303,9b0b0b,e33b2b,ffcbbb"), depth=3.0);
    } elif "armor" in lower or "shield" in lower or "screen" in lower {
        polygon(mask, [(cx - s * 0.38, cy - s * 0.36), (cx + s * 0.38, cy - s * 0.36), (cx + s * 0.34, cy + s * 0.05), (cx, cy + s * 0.42), (cx - s * 0.34, cy + s * 0.05)]);
        if "body" in lower or "red" in lower or "3" in lower {
            look = Look(ramp=ramp_text("3b0303,8b1b0b,d35b2b,ffbb8b"), depth=3.0);
        } elif "combat" in lower or "yellow" in lower or "2" in lower {
            look = Look(ramp=ramp_text("2b2303,8b6b0b,d3b32b,ffeb8b"), depth=3.0);
        } else {
            look = Look(ramp=ramp_text("032b03,0b6b1b,3bb34b,bbffbb"), depth=3.0);
        }
    } elif "shell" in lower {
        for k in range(3) {
            x = cx + (float(k) - 1.0) * s * 0.24;
            box(mask, x - s * 0.09, cy - s * 0.32, x + s * 0.09, cy + s * 0.32, s * 0.05);
        }
        look = Look(ramp=ramp_text("3b0303,8b1b0b,c34b2b,f39b6b"), depth=2.5);
    } elif "bullet" in lower or "ammo" in lower {
        for k in range(4) {
            x = cx + (float(k) - 1.5) * s * 0.2;
            polygon(mask, [(x - s * 0.07, cy + s * 0.32), (x - s * 0.07, cy - s * 0.15), (x, cy - s * 0.35), (x + s * 0.07, cy - s * 0.15), (x + s * 0.07, cy + s * 0.32)]);
        }
    } elif "nail" in lower or "spike" in lower or "flechette" in lower {
        for k in range(5) {
            x = cx + (float(k) - 2.0) * s * 0.16;
            stroke(mask, [[(x, cy - s * 0.35), (x, cy + s * 0.3)]], s * 0.07);
            box(mask, x - s * 0.06, cy + s * 0.25, x + s * 0.06, cy + s * 0.35);
        }
    } elif "rocket" in lower or "missile" in lower {
        polygon(mask, [(cx - s * 0.1, cy + s * 0.3), (cx - s * 0.1, cy - s * 0.2), (cx, cy - s * 0.4), (cx + s * 0.1, cy - s * 0.2), (cx + s * 0.1, cy + s * 0.3)]);
        polygon(mask, [(cx - s * 0.1, cy + s * 0.1), (cx - s * 0.25, cy + s * 0.38), (cx - s * 0.1, cy + s * 0.3)]);
        polygon(mask, [(cx + s * 0.1, cy + s * 0.1), (cx + s * 0.25, cy + s * 0.38), (cx + s * 0.1, cy + s * 0.3)]);
    } elif "cell" in lower or "battery" in lower or "power" in lower or "lightng" in lower {
        box(mask, cx - s * 0.3, cy - s * 0.3, cx + s * 0.3, cy + s * 0.34, s * 0.06);
        bolt = Field(w=w, h=h);
        polygon(bolt, [(cx + s * 0.05, cy - s * 0.25), (cx - s * 0.15, cy + s * 0.05), (cx, cy + s * 0.05), (cx - s * 0.05, cy + s * 0.28), (cx + s * 0.16, cy - s * 0.04), (cx + s * 0.01, cy - s * 0.04)]);
        mask = carved(mask, bolt);
        look = Look(ramp=ramp_text("03132b,0b3b8b,3b8be3,cbe3ff"), depth=3.0);
    } elif "grenade" in lower {
        disc(mask, cx, cy + s * 0.06, s * 0.3);
        box(mask, cx - s * 0.08, cy - s * 0.38, cx + s * 0.08, cy - s * 0.2);
    } elif "slug" in lower {
        for k in range(3) {
            x = cx + (float(k) - 1.0) * s * 0.22;
            box(mask, x - s * 0.06, cy - s * 0.36, x + s * 0.06, cy + s * 0.36, s * 0.05);
        }
    } elif "key" in lower or "pass" in lower or "card" in lower {
        ring = Field(w=w, h=h);
        disc(mask, cx - s * 0.2, cy, s * 0.18);
        disc(ring, cx - s * 0.2, cy, s * 0.08);
        mask = carved(mask, ring);
        box(mask, cx - s * 0.05, cy - s * 0.05, cx + s * 0.4, cy + s * 0.05);
        box(mask, cx + s * 0.22, cy, cx + s * 0.28, cy + s * 0.18);
        box(mask, cx + s * 0.32, cy, cx + s * 0.38, cy + s * 0.14);
        look = Look(ramp=ramp_text("2b2303,8b6b0b,d3b32b,ffeb8b") if "gold" in lower or "key2" in lower else ramp_text("2b2b33,6b6b7b,c3c3d3,ffffff"), depth=3.0);
    } elif "quad" in lower {
        disc(mask, cx, cy, s * 0.4);
        hole = Field(w=w, h=h);
        draw_glyph(hole, "Q", cx - s * 0.2, cy - s * 0.3, s * 0.1, s * 0.09);
        mask = carved(mask, hole);
        look = Look(ramp=ramp_text("03032b,1b1b8b,4b6bff,cbdbff"), depth=3.0);
    } elif "invul" in lower or "invuln" in lower or "pent" in lower {
        points: list[tuple[float, float]] = [];
        for k in range(6) {
            angle = -math.pi / 2.0 + float(k * 2) * math.pi * 2.0 / 5.0;
            points.append((cx + math.cos(angle) * s * 0.4, cy + math.sin(angle) * s * 0.4));
        }
        stroke(mask, [points], s * 0.08);
        look = Look(ramp=ramp_text("2b0303,8b0b0b,e32b1b,ffab8b"), depth=3.0);
    } elif "invis" in lower or "ring" in lower or "eye" in lower {
        polygon(mask, [(cx - s * 0.42, cy), (cx - s * 0.2, cy - s * 0.2), (cx + s * 0.2, cy - s * 0.2), (cx + s * 0.42, cy), (cx + s * 0.2, cy + s * 0.2), (cx - s * 0.2, cy + s * 0.2)]);
        pupil = Field(w=w, h=h);
        disc(pupil, cx, cy, s * 0.1);
        mask = carved(mask, pupil);
        look = Look(ramp=ramp_text("2b2b03,6b6b0b,c3c33b,ffffbb"), depth=3.0);
    } elif "suit" in lower or "enviro" in lower or "rebreath" in lower or "mask" in lower {
        disc(mask, cx, cy - s * 0.05, s * 0.32);
        visor = Field(w=w, h=h);
        box(visor, cx - s * 0.2, cy - s * 0.15, cx + s * 0.2, cy + s * 0.02, s * 0.05);
        mask = carved(mask, visor);
        box(mask, cx - s * 0.25, cy + s * 0.22, cx + s * 0.25, cy + s * 0.38, s * 0.05);
        look = Look(ramp=ramp_text("032b0b,0b6b2b,3bc36b,cbffdb"), depth=3.0);
    } elif "sigil" in lower or "rune" in lower or "tech" in lower or "silencer" in lower or "adrenal" in lower or "bandolier" in lower or "pack" in lower {
        seed = hash_label(4, lower);
        strokes: list[list[tuple[float, float]]] = [];
        for k in range(4) {
            a = float(mix32(seed + k) % 628) / 100.0;
            b = float(mix32(seed + k + 50) % 628) / 100.0;
            strokes.append([(cx + math.cos(a) * s * 0.35, cy + math.sin(a) * s * 0.35), (cx + math.cos(b) * s * 0.35, cy + math.sin(b) * s * 0.35)]);
        }
        stroke(mask, strokes, s * 0.08);
        ring2 = Field(w=w, h=h);
        disc(ring2, cx, cy, s * 0.42);
        inner = Field(w=w, h=h);
        disc(inner, cx, cy, s * 0.36);
        rim = carved(ring2, inner);
        for i in range(w * h) {
            mask.v[i] = max(mask.v[i], rim.v[i]);
        }
    } elif "disc" in lower {
        disc(mask, cx, cy, s * 0.42);
        hole2 = Field(w=w, h=h);
        disc(hole2, cx, cy, s * 0.1);
        mask = carved(mask, hole2);
    } elif "turtle" in lower or "net" in lower or "ram" in lower or "lag" in lower {
        box(mask, cx - s * 0.35, cy - s * 0.25, cx + s * 0.35, cy + s * 0.25, s * 0.06);
        hole3 = text_mask(lower[:3].upper(), w, h, 0.5);
        mask = carved(mask, hole3);
    } else {
        return weapon_icon(lower, w, h, game);
    }
    return cast(mask, look);
}

"""A weapon's silhouette, side on: a stock, a body and a barrel whose length
and bulk the weapon's name decides."""
def weapon_icon(lower: str, w: int, h: int, game: str) -> Picture {
    mask = Field(w=w, h=h);
    fw = float(w);
    fh = float(h);
    cy = fh * 0.5;
    length = 0.5;
    bulk = 0.18;
    barrels = 1;
    if "super" in lower or "sshot" in lower or "ssg" in lower or "snail" in lower or "chain" in lower {
        barrels = 2;
    }
    if "shot" in lower or "sg" in lower {
        length = 0.62;
        bulk = 0.12;
    } elif "nail" in lower or "machine" in lower or "mg" in lower or "chain" in lower or "hyper" in lower {
        length = 0.5;
        bulk = 0.2;
    } elif "rocket" in lower or "rl" in lower or "launch" in lower {
        length = 0.6;
        bulk = 0.3;
    } elif "grenade" in lower or "gl" in lower {
        length = 0.35;
        bulk = 0.3;
    } elif "light" in lower or "lg" in lower {
        length = 0.55;
        bulk = 0.22;
    } elif "rail" in lower {
        length = 0.7;
        bulk = 0.14;
    } elif "bfg" in lower {
        length = 0.45;
        bulk = 0.42;
    } elif "plasma" in lower or "blaster" in lower {
        length = 0.4;
        bulk = 0.25;
    } elif "gauntlet" in lower or "axe" in lower or "fist" in lower {
        length = 0.3;
        bulk = 0.3;
    }
    left = fw * 0.1;
    body_end = left + fw * (0.85 - length);
    box(mask, left, cy - fh * bulk * 0.5, body_end + fw * 0.05, cy + fh * bulk * 0.5, fh * 0.04);
    polygon(mask, [(left + fw * 0.05, cy), (left + fw * 0.18, cy), (left + fw * 0.14, cy + fh * 0.38), (left + fw * 0.02, cy + fh * 0.38)]);
    for k in range(barrels) {
        offset = (float(k) - float(barrels - 1) * 0.5) * fh * bulk * 0.45;
        box(mask, body_end, cy + offset - fh * bulk * 0.22, fw * 0.92, cy + offset + fh * bulk * 0.22, fh * 0.02);
    }
    return cast(mask, look_of(game, "alt" if "inva" in lower or "_s" in lower[-2:] else "icon"));
}

"""The face on Quake's status bar: grim and whole at full health (face1),
bloodied and bruised as health falls (to face5), a grimace in pain
(face_p*), and the powerups' faces."""
def face(name: str, w: int, h: int) -> Picture {
    lower = name.lower();
    hurt = 0;
    for k in range(1, 6) {
        if lower.endswith(str(k)) {
            # Quake's face1 is the healthiest (Sbar_Init: sb_faces[4 - i] is face(i + 1)).
            hurt = k - 1;
        }
    }
    made = Picture(w=w, h=h);
    head = Field(w=w, h=h);
    fw = float(w);
    fh = float(h);
    polygon(head, [(fw * 0.2, fh * 0.15), (fw * 0.8, fh * 0.15), (fw * 0.88, fh * 0.45), (fw * 0.7, fh * 0.95), (fw * 0.3, fh * 0.95), (fw * 0.12, fh * 0.45)]);
    skin = "2b1307,6b3b1b,b37b4b,e3b38b";
    if "invis" in lower {
        skin = "0b0b0b,2b2b2b,4b4b4b,6b6b6b";
    } elif "quad" in lower {
        skin = "07072b,1b2b6b,4b6bc3,9bb3ff";
    } elif "invul" in lower {
        skin = "2b0303,6b0b0b,b32b1b,ff7b5b";
    }
    lit = cast(head, Look(ramp=ramp_text(skin), depth=2.0, outline_width=0, shadow=False));
    marks = Field(w=w, h=h);
    pain = "_p" in lower;
    # Eyes, brows and a mouth.
    eye_y = fh * 0.45;
    stroke(marks, [[(fw * 0.28, eye_y - fh * 0.08), (fw * 0.45, eye_y - fh * 0.04)], [(fw * 0.72, eye_y - fh * 0.08), (fw * 0.55, eye_y - fh * 0.04)]], max(1.0, fw * 0.06));
    disc(marks, fw * 0.37, eye_y, max(0.8, fw * 0.05));
    disc(marks, fw * 0.63, eye_y, max(0.8, fw * 0.05));
    mouth_y = fh * (0.76 if not pain else 0.74);
    if pain {
        box(marks, fw * 0.38, mouth_y - fh * 0.05, fw * 0.62, mouth_y + fh * 0.06, fw * 0.03);
    } else {
        stroke(marks, [[(fw * 0.36, mouth_y), (fw * 0.64, mouth_y + fh * 0.02 * float(hurt))]], max(1.0, fw * 0.05));
    }
    for i in range(w * h) {
        if marks.v[i] > 0.0 {
            lit.put(i, lit.colour(i).mixed(Rgb(r=0.08, g=0.03, b=0.02), marks.v[i]));
        }
    }
    # Blood, more the more hurt.
    if hurt > 0 {
        blood = fbm(w, h, 3, 4, 0.6, hash_label(6, lower));
        level = 0.75 - float(hurt) * 0.1;
        for i in range(w * h) {
            if blood.v[i] > level and head.v[i] > 0.5 {
                lit.put(i, lit.colour(i).mixed(Rgb(r=0.55, g=0.02, b=0.0), min(1.0, (blood.v[i] - level) * 6.0)));
            }
        }
    }
    background = filled(w, h, Rgb(r=0.12, g=0.09, b=0.06));
    return laid_over(background, lit);
}

"""A background for a bar or a screen: a surface of the game's own kind,
framed by a raised border."""
def panel(name: str, w: int, h: int, game: str) -> Picture {
    family_word = "metal" if game != "q1" else ["wbrick", "metal", "rock"][mix32(hash_label(8, name)) % 3];
    if "back" in name.lower() or "tile" in name.lower() {
        family_word = "rock";
    }
    tw = max(16, (w + 15) // 16 * 16);
    th = max(16, (h + 15) // 16 * 16);
    painted = paint_named(family_word + "_" + name, tw, th, game, "stone" if family_word == "rock" else ("metal" if family_word == "metal" else "brick"));
    made = Picture(w=w, h=h);
    for y in range(h) {
        for x in range(w) {
            colour = painted.picture.colour(y * tw + x).scaled(0.8);
            rim = min(min(x, w - 1 - x), min(y, h - 1 - y));
            if rim < 2 {
                colour = colour.scaled(1.4 if (x < 2 or y < 2) else 0.5);
            }
            made.put(y * w + x, colour);
        }
    }
    return made;
}

"""A screen the game draws behind its help or inventory: a dark glass in a
frame, with faint lines."""
def screen(name: str, w: int, h: int, game: str) -> Picture {
    made = panel(name, w, h, game);
    tint = Rgb(r=0.02, g=0.08, b=0.04) if game == "q2" else Rgb(r=0.03, g=0.03, b=0.06);
    border = max(4, min(w, h) // 16);
    for y in range(border, h - border) {
        for x in range(border, w - border) {
            line = 0.15 if y % 4 == 0 else 0.0;
            made.put(y * w + x, tint.mixed(Rgb(r=0.1, g=0.3, b=0.12), line));
        }
    }
    return made;
}

"""A plaque of words, cast in the game's colours, over clear."""
def plaque(words: str, w: int, h: int, game: str) -> Picture {
    lines = [line for line in words.split("|") if line];
    mask = Field(w=w, h=h);
    if not lines {
        return cast(mask, look_of(game, "icon"));
    }
    line_h = float(h) / float(len(lines));
    smallest = 1.0e9;
    for k in range(len(lines)) {
        line = lines[k];
        unit = min(float(w) * 0.9 / max(1.0, float(len(line)) * 6.0 - 2.0), line_h * 0.8 / 7.0);
        smallest = min(smallest, unit);
        x = (float(w) - text_width(line, unit)) * 0.5;
        y = line_h * float(k) + (line_h - unit * 6.0) * 0.5;
        # Small letters are drawn thin, or their strokes run together.
        draw_text(mask, line, x, y, unit, max(1.0, unit * (1.2 if unit >= 6.0 else 0.55)));
    }
    return cast(mask, look_of(game, "icon" if smallest >= 6.0 else "text"));
}

"""A crosshair: a cross, a ring, a dot or brackets, by its letter."""
def crosshair(name: str, w: int, h: int) -> Picture {
    mask = Field(w=w, h=h);
    fw = float(w);
    fh = float(h);
    cx = fw * 0.5;
    cy = fh * 0.5;
    kind = mix32(hash_label(10, name.lower())) % 4;
    if kind == 0 {
        stroke(mask, [[(cx, fh * 0.15), (cx, fh * 0.4)], [(cx, fh * 0.6), (cx, fh * 0.85)], [(fw * 0.15, cy), (fw * 0.4, cy)], [(fw * 0.6, cy), (fw * 0.85, cy)]], max(1.0, fw * 0.06));
    } elif kind == 1 {
        disc(mask, cx, cy, fw * 0.3);
        hole = Field(w=w, h=h);
        disc(hole, cx, cy, fw * 0.24);
        mask = carved(mask, hole);
    } elif kind == 2 {
        disc(mask, cx, cy, max(1.0, fw * 0.08));
    } else {
        stroke(mask, [[(fw * 0.3, fh * 0.2), (fw * 0.2, fh * 0.2), (fw * 0.2, fh * 0.8), (fw * 0.3, fh * 0.8)], [(fw * 0.7, fh * 0.2), (fw * 0.8, fh * 0.2), (fw * 0.8, fh * 0.8), (fw * 0.7, fh * 0.8)]], max(1.0, fw * 0.05));
    }
    made = Picture(w=w, h=h, a=[0.0] * (w * h));
    for i in range(w * h) {
        made.put(i, Rgb(r=1.0, g=1.0, b=1.0));
        made.a[i] = mask.v[i];
    }
    return made;
}

"""A level shot: the level's name over a view made of its seed, a sky over
rising shapes."""
def level_shot(name: str, w: int, h: int) -> Picture {
    seed = hash_label(11, name.lower());
    hills = fbm(w, 1, 4, 5, 0.55, seed);
    sky = fbm(w, h, 3, 5, 0.6, seed + 1);
    made = Picture(w=w, h=h);
    top = Rgb(r=0.1, g=0.08, b=0.2);
    low = Rgb(r=0.6, g=0.35, b=0.2);
    for y in range(h) {
        for x in range(w) {
            t = float(y) / float(h);
            colour = top.mixed(low, t).mixed(Rgb(r=0.8, g=0.7, b=0.6), sky.v[y * w + x] * 0.3);
            if t > 0.45 + hills.v[x] * 0.35 {
                colour = Rgb(r=0.08, g=0.07, b=0.06).mixed(Rgb(r=0.2, g=0.16, b=0.12), lattice(seed, x // 8, y // 8));
            }
            made.put(y * w + x, colour);
        }
    }
    caption = text_mask(name.split("/")[-1].rsplit(".", 1)[0].upper(), w, h // 4, 0.8);
    label = cast(caption, look_of("q3", "icon"));
    shown = Picture(w=w, h=h, a=[0.0] * (w * h));
    for y in range(h // 4) {
        for x in range(w) {
            i = (h - h // 4 + y) * w + x;
            shown.put(i, label.colour(y * w + x));
            shown.a[i] = label.a[y * w + x];
        }
    }
    return laid_over(made, shown);
}

"""Words a picture shows, from its name: a menu title's word, a plaque's."""
def words_of(name: str) -> str {
    stem = name.lower().split("/")[-1].rsplit(".", 1)[0];
    known = {
        "complete": "COMPLETED",
        "inter": "TIME|SECRETS|KILLS",
        "loading": "LOADING",
        "pause": "PAUSED",
        "finale": "THE END",
        "mainmenu": "SINGLE PLAYER|MULTIPLAYER|OPTIONS|HELP|QUIT",
        "sp_menu": "NEW GAME|LOAD|SAVE",
        "qplaque": "Q",
        "ranking": "RANKING",
        "vidmodes": "VIDEO",
        "dim_drct": "DIRECT CONNECT",
        "dim_ipx": "IPX",
        "dim_modm": "MODEM",
        "dim_mult": "MULTIPLAYER",
        "netmen1": "NETWORK",
        "help0": "HELP"
    };
    if stem in known {
        return known[stem];
    }
    for prefix in ["ttl_", "p_", "m_main_", "m_banner_", "m_", "menu_", "dim_"] {
        if stem.startswith(prefix) {
            stem = stem[len(prefix):];
            break;
        }
    }
    cut = stem.rfind("_");
    if cut > 0 and stem[cut + 1:] in ["0", "1", "2"] {
        stem = stem[:cut];
    }
    return stem.replace("_", " ").upper();
}

"""What a 2D picture called `name` (a path or a WAD lump's name) shows,
drawn at its size for `game`; None when it is not 2D art this draws."""
def picture_2d(name: str, w: int, h: int, game: str) -> Picture | None {
    lower = name.lower();
    stem = lower.split("/")[-1].rsplit(".", 1)[0];
    if w <= 0 or h <= 0 {
        return None;
    }
    if stem == "conchars" or stem == "bigchars" {
        return font_sheet(w, h, game);
    }
    if stem.startswith("font1_prop") or stem.startswith("font2_prop") {
        return prop_font(w, h, game);
    }
    digits = {"zero": "0", "one": "1", "two": "2", "three": "3", "four": "4", "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9", "minus": "-", "colon": ":", "slash": "/"};
    if stem.startswith("num_") or stem.startswith("anum_") {
        key = stem.split("_", 1)[1];
        character = digits.get(key, key[:1]);
        return big_character(character, w, h, look_of(game, "alt" if stem.startswith("anum_") else "icon"));
    }
    if "/numbers/" in lower {
        key = stem.split("_")[0];
        return big_character(digits.get(key, "0"), w, h, look_of(game, "icon"));
    }
    if stem.startswith("face") {
        return face(stem, w, h);
    }
    if stem in ["sbar", "ibar", "scorebar", "backtile", "field_3", "tile", "statusbar"] {
        return panel(stem, w, h, game);
    }
    if stem in ["help", "inventory", "conback", "console01", "console02", "conback2"] {
        made = screen(stem, w, h, game);
        if stem.startswith("con") {
            title = plaque("QUAKEPASSION", w, max(8, h // 6), game);
            for y in range(title.h) {
                for x in range(w) {
                    i = (h - title.h - h // 20 + y) * w + x;
                    if i >= 0 and i < w * h {
                        made.put(i, made.colour(i).mixed(title.colour(y * w + x), title.a[y * w + x]));
                    }
                }
            }
        }
        return made;
    }
    if stem.startswith("crosshair") or stem in ["ch1", "ch2", "ch3"] {
        return crosshair(stem, w, h);
    }
    if lower.startswith("levelshots/") {
        return level_shot(stem, w, h);
    }
    icon_words = ["sb_", "inv_", "inva", "inv2_", "i_", "a_", "w_", "k_", "icon", "disc", "turtle", "net", "ram", "pickup", "weapon"];
    for word in icon_words {
        if stem.startswith(word) or "/icons/" in lower or lower.startswith("icons/") {
            return icon(stem, w, h, game);
        }
    }
    if game == "q2" and stem.startswith("p_") {
        return icon(stem, w, h, game);
    }
    if lower.startswith("gfx/") or lower.startswith("pics/") or lower.startswith("menu/") or lower.startswith("ui/") {
        return plaque(words_of(lower), w, h, game);
    }
    return None;
}
