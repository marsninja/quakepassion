"""The original status bars, drawn from each game's own 2D art.

Quake: sbar.c's 320-wide status and inventory bars (gfx.wad), with the face,
armor, health and ammo numbers, weapon and ammo inventory, keys, sigils and
powerups. Quake II: the single-player statusbar layout (g_spawn.c) with its
pics/*.pcx fields and icons. Quake III: cg_draw.c's status bar with 2D icons
(cg_draw3dIcons 0): ammo, health with the player's head icon, armor and the
crosshair. Each layout is scaled up by a whole factor and
centred, as source ports draw the original virtual screens."""
import math;
import from vendor.raylib {
    obj HudImage2 {
        has data: u64,
            width: i32,
            height: i32,
            mipmaps: i32,
            format: i32;
    }  obj HudTexture2 {
        has id: u32,
            width: i32,
            height: i32,
            mipmaps: i32,
            format: i32;
    }  def LoadImageFromMemory(
        fileType: str, fileData: bytes, dataSize: i32
    ) -> HudImage2;  def LoadTextureFromImage(image: HudImage2) -> HudTexture2;  def UnloadImage(
        image: HudImage2
    ) -> None;  def rlLoadTexture(
        data: bytes, width: i32, height: i32, format: i32, mipmapCount: i32
    ) -> u32;  def rlUnloadTexture(id: u32) -> None;  def rlTextureParameters(
        id: u32, param: i32, value: i32
    ) -> None;  def rlSetTexture(id: u32) -> None;  def rlBegin(mode: i32) -> None;  def rlEnd -> None;  def rlTexCoord2f(
        x: f32, y: f32
    ) -> None;  def rlVertex2f(x: f32, y: f32) -> None;  def rlColor4ub(
        r: u8, g: u8, b: u8, a: u8
    ) -> None;  def rlDrawRenderBatchActive -> None;
}
import from ..formats.bsp { Texture }

obj HudPic {
    has id: int = 0,
        width: int = 0,
        height: int = 0;
}

"""What the status bar shows, gathered by the game each frame."""
obj HudStatus {
    has game: str = "q1",
        health: int = 100,
        armor: int = 0,
        armor_ratio: float = 0.0,
        ammo: int = -1,
        ammo_kind: str = "",
        weapon: str = "",
        weapons: list[str] = [],
        ammo_counts: dict[str, int] = {},
        keys: list[str] = [],
        sigils: int = 0,
        powerups: list[str] = [],
        powerup_time: float = 0.0,
        pain: float = 0.0,
        head: str = "",
        firing: bool = False,
        score: int = 0,
        leader: int = 0,
        arena: bool = False,
        clock: float = 0.0;
}

obj HudRenderer {
    has pics: dict[str, HudPic] = {},
        game: str = "",
        ready: bool = False;

    def add(name: str, texture: Texture) {
        id = 0;
        width = texture.width;
        height = texture.height;
        if texture.encoded {
            image = LoadImageFromMemory(texture.extension, texture.encoded, i32(len(texture.encoded)));
            if image.data == u64(0) {
                return;
            }
            gpu = LoadTextureFromImage(image);
            UnloadImage(image);
            id = int(gpu.id);
            width = int(gpu.width);
            height = int(gpu.height);
        } elif texture.pixels {
            id = int(rlLoadTexture(texture.pixels, i32(texture.width), i32(texture.height), i32(7), i32(1)));
        }
        if id == 0 {
            return;
        }
        # Nearest filtering keeps the original pixel art crisp when scaled.
        rlTextureParameters(u32(id), i32(10241), i32(9728));
        rlTextureParameters(u32(id), i32(10240), i32(9728));
        self.pics[name] = HudPic(id=id, width=width, height=height);
    }

    def has_pic(name: str) -> bool {
        return name in self.pics;
    }

    def close() {
        for name in self.pics.keys() {
            rlUnloadTexture(u32(self.pics[name].id));
        }
        self.pics = {};
        self.ready = False;
    }

    """Draw a picture region at screen position and size, with a tint."""
    def blit(
        name: str,
        x: float,
        y: float,
        w: float,
        h: float,
        tint: list[int] = [255, 255, 255, 255],
        u0: float = 0.0,
        v0: float = 0.0,
        u1: float = 1.0,
        v1: float = 1.0
    ) {
        if name not in self.pics {
            return;
        }
        pic = self.pics[name];
        rlSetTexture(u32(pic.id));
        rlBegin(i32(7));
        rlColor4ub(u8(tint[0]), u8(tint[1]), u8(tint[2]), u8(tint[3]));
        rlTexCoord2f(f32(u0), f32(v0));
        rlVertex2f(f32(x), f32(y));
        rlTexCoord2f(f32(u0), f32(v1));
        rlVertex2f(f32(x), f32(y + h));
        rlTexCoord2f(f32(u1), f32(v1));
        rlVertex2f(f32(x + w), f32(y + h));
        rlTexCoord2f(f32(u1), f32(v0));
        rlVertex2f(f32(x + w), f32(y));
        rlEnd();
        rlSetTexture(u32(0));
    }

    """A picture at its own size in virtual units."""
    def pic(name: str, x: float, y: float, scale: float, tint: list[int] = [255, 255, 255, 255]) {
        if name in self.pics {
            p = self.pics[name];
            self.blit(name, x, y, float(p.width) * scale, float(p.height) * scale, tint);
        }
    }

    def draw(status: HudStatus, width: int, height: int) {
        if not self.ready {
            return;
        }
        if status.game == "q1" {
            self.draw_q1(status, width, height);
        } elif status.game == "q2" {
            self.draw_q2(status, width, height);
        } elif status.game == "q3" {
            self.draw_q3(status, width, height);
        }
        rlDrawRenderBatchActive();
    }

    # ---- Quake (sbar.c) ----

    """Sbar_DrawNum: right-aligned big digits, 24 units each; the alternate
    (red) set when `alt`."""
    def q1_number(value: int, digits: int, x: float, y: float, scale: float, alt: bool) {
        text = str(value);
        if len(text) > digits {
            text = text[len(text) - digits:];
        }
        x += float(digits - len(text)) * 24.0 * scale;
        prefix = "anum_" if alt else "num_";
        for c in text {
            self.pic(prefix + ("minus" if c == "-" else c), x, y, scale);
            x += 24.0 * scale;
        }
    }

    """A conchars character (8x8 cell of the 16x16 sheet)."""
    def q1_char(code: int, x: float, y: float, scale: float) {
        column = float(code % 16) / 16.0;
        row = float(code // 16) / 16.0;
        self.blit("conchars", x, y, 8.0 * scale, 8.0 * scale, [255, 255, 255, 255], column, row, column + 1.0 / 16.0, row + 1.0 / 16.0);
    }

    def draw_q1(status: HudStatus, width: int, height: int) {
        scale = float(max(1, int(min(float(width) / 320.0, float(height) / 240.0))));
        left = (float(width) - 320.0 * scale) * 0.5;
        bar = float(height) - 24.0 * scale;
        inventory = bar - 24.0 * scale;
        self.pic("ibar", left, inventory, scale);
        # Weapons: selected in the bright set, owned in the normal set.
        weapons = ["shotgun", "sshotgun", "nailgun", "snailgun", "rlaunch", "srlaunch", "lightng"];
        keys = ["shotgun", "supershotgun", "nailgun", "supernailgun", "grenadelauncher", "rocketlauncher", "lightning"];
        for i in range(len(weapons)) {
            if keys[i] in status.weapons {
                prefix = "inv2_" if keys[i] == status.weapon else "inv_";
                self.pic(prefix + weapons[i], left + float(i * 24) * scale, inventory + 8.0 * scale, scale);
            }
        }
        # Ammo counts in the small yellow digits (conchars 18-27).
        ammo_kinds = ["shells", "nails", "rockets", "cells"];
        for i in range(4) {
            count = min(999, status.ammo_counts.get(ammo_kinds[i], 0));
            text = str(count);
            while len(text) < 3 {
                text = " " + text;
            }
            for j in range(3) {
                if text[j] != " " {
                    self.q1_char(18 + int(text[j]), left + (float((6 * i + 1) * 8 - 2) + float(j * 8)) * scale, inventory, scale);
                }
            }
        }
        # Keys, powerups and sigils along the right of the inventory bar.
        items = ["key1", "key2", "invisibility", "invulnerability", "suit", "quad"];
        icons = ["sb_key1", "sb_key2", "sb_invis", "sb_invuln", "sb_suit", "sb_quad"];
        for i in range(len(items)) {
            if items[i] in status.keys or items[i] in status.powerups {
                self.pic(icons[i], left + float(192 + i * 16) * scale, inventory + 8.0 * scale, scale);
            }
        }
        for i in range(4) {
            if status.sigils & (1 << i) {
                self.pic("sb_sigil" + str(i + 1), left + float(320 - 32 + i * 8) * scale, inventory + 8.0 * scale, scale);
            }
        }
        self.pic("sbar", left, bar, scale);
        if "invulnerability" in status.powerups {
            self.q1_number(666, 3, left + 24.0 * scale, bar, scale, True);
            self.pic("disc", left, bar, scale);
        } elif status.armor > 0 {
            self.q1_number(status.armor, 3, left + 24.0 * scale, bar, scale, status.armor <= 25);
            armor = "sb_armor3" if status.armor_ratio >= 0.8 else ("sb_armor2" if status.armor_ratio >= 0.6 else "sb_armor1");
            self.pic(armor, left, bar, scale);
        }
        # Sbar_DrawFace: health bands, pain frames and powerup faces.
        face = "face" + str(5 - min(4, max(0, status.health) // 20));
        if status.pain > 0.0 {
            face = "face_p" + str(5 - min(4, max(0, status.health) // 20));
        }
        if "invisibility" in status.powerups and "invulnerability" in status.powerups {
            face = "face_inv2";
        } elif "quad" in status.powerups {
            face = "face_quad";
        } elif "invisibility" in status.powerups {
            face = "face_invis";
        } elif "invulnerability" in status.powerups {
            face = "face_invul2";
        }
        self.pic(face, left + 112.0 * scale, bar, scale);
        self.q1_number(status.health, 3, left + 136.0 * scale, bar, scale, status.health <= 25);
        ammo_icons: dict[str, str] = {"shells": "sb_shells", "nails": "sb_nails", "rockets": "sb_rocket", "cells": "sb_cells"};
        if status.ammo_kind in ammo_icons {
            self.pic(ammo_icons[status.ammo_kind], left + 224.0 * scale, bar, scale);
        }
        if status.ammo >= 0 {
            self.q1_number(status.ammo, 3, left + 248.0 * scale, bar, scale, status.ammo <= 10);
        }
    }

    # ---- Quake II (single_statusbar) ----

    """SCR_DrawField: right-aligned 16-unit digits of num_ (or anum_)."""
    def q2_field(value: int, digits: int, x: float, y: float, scale: float, alt: bool) {
        text = str(value);
        if len(text) > digits {
            text = text[len(text) - digits:];
        }
        x += (2.0 + 16.0 * float(digits - len(text))) * scale;
        prefix = "anum_" if alt else "num_";
        for c in text {
            self.pic(prefix + ("minus" if c == "-" else c), x, y, scale);
            x += 16.0 * scale;
        }
    }

    def draw_q2(status: HudStatus, width: int, height: int) {
        scale = float(max(1, int(float(height) / 360.0)));
        left = float(width) * 0.5 - 160.0 * scale;
        low = float(height) - 24.0 * scale;
        blink = int(status.clock * 5.0) % 2 == 1;
        # Health: flashes in the alternate digits at 25 or less.
        self.q2_field(status.health, 3, left, low, scale, status.health <= 25 and blink);
        self.pic("i_health", left + 50.0 * scale, low, scale);
        ammo_icons: dict[str, str] = {
            "shells": "a_shells", "bullets": "a_bullets", "grenades": "a_grenades",
            "rockets": "a_rockets", "cells": "a_cells", "slugs": "a_slugs"
        };
        if status.ammo >= 0 and status.ammo_kind in ammo_icons {
            self.q2_field(status.ammo, 3, left + 100.0 * scale, low, scale, status.ammo <= 5 and blink);
            self.pic(ammo_icons[status.ammo_kind], left + 150.0 * scale, low, scale);
        }
        if status.armor > 0 {
            self.q2_field(status.armor, 3, left + 200.0 * scale, low, scale, False);
            armor = "i_bodyarmor" if status.armor_ratio >= 0.8 else ("i_combatarmor" if status.armor_ratio >= 0.6 else "i_jacketarmor");
            self.pic(armor, left + 250.0 * scale, low, scale);
        }
        # The selected weapon's icon sits in the help-icon slot.
        if status.weapon and self.has_pic("w_" + status.weapon) {
            self.pic("w_" + status.weapon, left + 148.0 * scale, float(height) - 50.0 * scale, scale);
        }
        # A running powerup shows its seconds left and icon (the timer field).
        timers: dict[str, str] = {
            "quad": "p_quad", "invulnerability": "p_invulnerability",
            "suit": "p_envirosuit", "breather": "p_rebreather"
        };
        for power in status.powerups {
            if power in timers and status.powerup_time > 0.0 {
                self.q2_field(int(status.powerup_time), 2, left + 262.0 * scale, float(height) - 50.0 * scale, scale, False);
                self.pic(timers[power], left + 296.0 * scale, float(height) - 50.0 * scale, scale);
                break;
            }
        }
    }

    # ---- Quake III (cg_draw.c CG_DrawStatusBar, 2D icons) ----

    """CG_DrawField: right-aligned 32x48 digits in the given colour."""
    def q3_field(value: int, digits: int, x: float, y: float, scale: float, tint: list[int]) {
        text = str(value);
        if len(text) > digits {
            text = text[len(text) - digits:];
        }
        names = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"];
        x += (2.0 + 32.0 * float(digits - len(text))) * scale;
        for c in text {
            name = "minus" if c == "-" else names[int(c)];
            self.blit(name, x, y, 32.0 * scale, 48.0 * scale, tint);
            x += 32.0 * scale;
        }
    }

    def draw_q3(status: HudStatus, width: int, height: int) {
        scale = float(height) / 480.0;
        left = (float(width) - 640.0 * scale) * 0.5;
        y = float(height) - 48.0 * scale;
        normal = [255, 176, 0, 255];
        low = [255, 51, 51, 255];
        grey = [128, 128, 128, 255];
        white = [255, 255, 255, 255];
        if status.ammo >= 0 {
            self.q3_field(status.ammo, 3, left, y, scale, grey if status.firing else normal);
            icon = "ammo_" + status.weapon;
            if self.has_pic(icon) {
                self.blit(icon, left + 100.0 * scale, y, 48.0 * scale, 48.0 * scale);
            }
        }
        tint = white if status.health > 100 else (normal if status.health > 25 else (low if int(status.clock * 4.0) % 2 == 0 else normal));
        self.q3_field(status.health, 3, left + 185.0 * scale, y, scale, tint);
        if self.has_pic("head") {
            self.blit("head", left + 285.0 * scale, y, 48.0 * scale, 48.0 * scale);
        }
        if status.armor > 0 {
            self.q3_field(status.armor, 3, left + 370.0 * scale, y, scale, white if status.armor > 100 else normal);
            self.blit("armor", left + 470.0 * scale, y, 48.0 * scale, 48.0 * scale);
        }
        # The default crosshair (cg_drawCrosshair 4), 24 units square.
        if self.has_pic("crosshair") {
            size = 24.0 * scale;
            self.blit("crosshair", float(width) * 0.5 - size * 0.5, float(height) * 0.5 - size * 0.5, size, size);
        }
    }
}
