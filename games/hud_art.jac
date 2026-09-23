"""Load each game's original status bar art into the HUD renderer."""
import from engine.render.hud { HudRenderer }
import from engine.formats.bsp { Texture }
import from engine.formats.q1.wad { wad_pictures }
import from engine.formats.q2.model { parse_pcx }
import from engine.assets.library { AssetLibrary }

glob Q2_WEAPON_PICS: dict[str, str] = {
    "blaster": "w_blaster",
    "shotgun": "w_shotgun",
    "supershotgun": "w_sshotgun",
    "machinegun": "w_machinegun",
    "chaingun": "w_chaingun",
    "grenadelauncher": "w_glauncher",
    "rocketlauncher": "w_rlauncher",
    "hyperblaster": "w_hyperblaster",
    "railgun": "w_railgun",
    "bfg": "w_bfg",
    "handgrenade": "w_hgrenade"
};

glob Q3_AMMO_ICONS: dict[str, str] = {
    "machinegun": "machinegun",
    "shotgun": "shotgun",
    "grenadelauncher": "grenade",
    "rocketlauncher": "rocket",
    "lightning": "lightning",
    "railgun": "railgun",
    "plasmagun": "plasma",
    "bfg": "bfg"
};

def encoded(library: AssetLibrary, path: str) -> Texture | None {
    if not library.exists(path) {
        return None;
    }
    extension = "." + path.rsplit(".", 1)[-1].lower();
    return Texture(name=path, encoded=library.read(path), extension=extension);
}

def load_q1_art(hud: HudRenderer, library: AssetLibrary) {
    if not library.exists("gfx.wad") {
        return;
    }
    pictures = wad_pictures(library.read("gfx.wad"), library.read("gfx/palette.lmp"));
    for (name, picture) in pictures.items() {
        hud.add(name, picture);
    }
    hud.ready = hud.has_pic("sbar") and hud.has_pic("num_0");
}

def load_q2_art(hud: HudRenderer, library: AssetLibrary) {
    names = ["i_health", "i_jacketarmor", "i_combatarmor", "i_bodyarmor", "a_shells", "a_bullets",
        "a_grenades", "a_rockets", "a_cells", "a_slugs", "p_quad", "p_invulnerability",
        "p_envirosuit", "p_rebreather"];
    for digit in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "minus"] {
        names.append("num_" + digit);
        names.append("anum_" + digit);
    }
    for name in names {
        path = "pics/" + name + ".pcx";
        if library.exists(path) {
            hud.add(name, parse_pcx(library.read(path), path, 255));
        }
    }
    for (key, pic) in Q2_WEAPON_PICS.items() {
        path = "pics/" + pic + ".pcx";
        if library.exists(path) {
            hud.add("w_" + key, parse_pcx(library.read(path), path, 255));
        }
    }
    hud.ready = hud.has_pic("num_0") and hud.has_pic("i_health");
}

def load_q3_art(hud: HudRenderer, library: AssetLibrary) {
    names = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "minus"];
    for name in names {
        art = encoded(library, "gfx/2d/numbers/" + name + "_32b.tga");
        if art is not None {
            hud.add(name, art);
        }
    }
    for (key, icon) in Q3_AMMO_ICONS.items() {
        art = encoded(library, "icons/icona_" + icon + ".tga");
        if art is not None {
            hud.add("ammo_" + key, art);
        }
    }
    for (name, path) in [
        ("armor", "icons/iconr_yellow.tga"),
        ("head", "models/players/sarge/icon_default.tga"),
        ("crosshair", "gfx/2d/crosshaire.tga")
    ] {
        art = encoded(library, path);
        if art is not None {
            hud.add(name, art);
        }
    }
    hud.ready = hud.has_pic("zero") and hud.has_pic("head");
}

"""Fill `hud` with the art of `game`; leaves it unready when the art is missing."""
def load_hud_art(hud: HudRenderer, library: AssetLibrary, game: str) {
    hud.close();
    hud.game = game;
    if game == "q1" {
        load_q1_art(hud, library);
    } elif game == "q2" {
        load_q2_art(hud, library);
    } elif game == "q3" {
        load_q3_art(hud, library);
    }
}
