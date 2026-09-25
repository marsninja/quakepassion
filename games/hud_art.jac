"""Load each game's original status bar art into the HUD renderer."""
import from engine.render.hud { HudRenderer }
import from engine.render.hud_models { HudModels }
import from engine.render.models { ModelRenderer }
import from .arena_character { player_part }
import from engine.formats.bsp { Texture }
import from engine.formats.q1.wad { wad_pictures, lump_picture }
import from engine.formats.q2.model { parse_pcx }
import from engine.assets.library { AssetLibrary }
import from .items { Q2_PICKUPS, Q3_PICKUPS }

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
    palette = library.read("gfx/palette.lmp");
    pictures = wad_pictures(library.read("gfx.wad"), palette);
    for (name, picture) in pictures.items() {
        hud.add(name, picture);
    }
    # Sbar_IntermissionOverlay's plaques live outside the WAD.
    for name in ["complete", "inter"] {
        path = "gfx/" + name + ".lmp";
        if library.exists(path) {
            hud.add(name, lump_picture(library.read(path), palette, name));
        }
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
    # Pickup and selected-item icons, and the console characters.
    for shown in Q2_PICKUPS.values() {
        names.append(shown[1]);
    }
    for extra in ["conchars", "p_quad", "p_silencer", "p_adrenaline", "p_bandolier"] {
        names.append(extra);
    }
    for name in names {
        path = "pics/" + name + ".pcx";
        if library.exists(path) and not hud.has_pic(name) {
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
    for shown in Q3_PICKUPS.values() {
        art = encoded(library, shown[1] + ".tga");
        if art is not None {
            hud.add(shown[1], art);
        }
    }
    for (name, path) in [
        ("conchars", "gfx/2d/bigchars.tga"),
        ("blood_screen", "gfx/damage/blood_screen.tga"),
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

# bg_misc.c ammo world models by weapon.
glob Q3_AMMO_MODELS: dict[str, str] = {
    "machinegun": "models/powerups/ammo/machinegunam.md3",
    "shotgun": "models/powerups/ammo/shotgunam.md3",
    "grenadelauncher": "models/powerups/ammo/grenadeam.md3",
    "rocketlauncher": "models/powerups/ammo/rocketam.md3",
    "lightning": "models/powerups/ammo/lightningam.md3",
    "railgun": "models/powerups/ammo/railgunam.md3",
    "plasmagun": "models/powerups/ammo/plasmaam.md3",
    "bfg": "models/powerups/ammo/bfgam.md3"
};

"""The models for Q3's 3D status bar icons: each weapon's ammo box, the yellow
armor (cgs.media.armorModel) and Sarge's head."""
def load_q3_models(models: HudModels, library: AssetLibrary) {
    models.close();
    for (weapon, path) in Q3_AMMO_MODELS.items() {
        if library.exists(path) {
            asset = library.model(path);
            renderer = ModelRenderer();
            renderer.upload(asset.model, asset.skins);
            models.ammo[weapon] = renderer;
        }
    }
    armor_path = "models/powerups/armor/armor_yel.md3";
    if library.exists(armor_path) {
        asset = library.model(armor_path);
        armor = ModelRenderer();
        armor.upload(asset.model, asset.skins);
        models.armor = armor;
    }
    if library.exists("models/players/sarge/head.md3") {
        part = player_part(library, "head", "sarge", "default");
        head = ModelRenderer();
        head.upload(part.model, part.skins);
        models.set_head(head);
    }
}
