"""Q3 player characters: their tagged part models, animation table and sounds,
and the weapons they hold, loaded as the original client registers them."""
import from engine.assets.library { AssetLibrary, ModelAsset }
import from engine.formats.q3.model { parse_md3 }
import from engine.formats.bsp { Texture }
import from engine.formats.animated { AnimatedModel, AnimatedSurface }
import from engine.world.world { World }
import from engine.world.models { ModelResource, HasModelResource, AnimationClip, WeaponKit, KitPart, PlayerRig }
import from engine.world.player_rig { rig_clips, dress_rig }
import from engine.math.vec3 { Vec3 }

# The world models each held weapon uses, and cg_weapons.c CG_RegisterWeapon's
# muzzle flash light colours.
glob Q3_HELD_WEAPONS: dict[str, str] = {
    "gauntlet": "models/weapons2/gauntlet/gauntlet.md3",
    "machinegun": "models/weapons2/machinegun/machinegun.md3",
    "shotgun": "models/weapons2/shotgun/shotgun.md3",
    "grenadelauncher": "models/weapons2/grenadel/grenadel.md3",
    "rocketlauncher": "models/weapons2/rocketl/rocketl.md3",
    "lightning": "models/weapons2/lightning/lightning.md3",
    "railgun": "models/weapons2/railgun/railgun.md3",
    "plasmagun": "models/weapons2/plasma/plasma.md3",
    "bfg": "models/weapons2/bfg/bfg.md3"
};
glob Q3_FLASH_LIGHTS: dict[str, Vec3] = {
    "gauntlet": Vec3(x=0.6, y=0.6, z=1.0),
    "machinegun": Vec3(x=1.0, y=1.0, z=0.0),
    "shotgun": Vec3(x=1.0, y=1.0, z=0.0),
    "grenadelauncher": Vec3(x=1.0, y=0.7, z=0.0),
    "rocketlauncher": Vec3(x=1.0, y=0.75, z=0.0),
    "lightning": Vec3(x=0.6, y=0.6, z=1.0),
    "railgun": Vec3(x=1.0, y=0.5, z=0.0),
    "plasmagun": Vec3(x=0.6, y=0.6, z=1.0),
    "bfg": Vec3(x=1.0, y=0.7, z=1.0)
};

def player_part(
    library: AssetLibrary, part: str, character: str = "sarge", skin: str = "default"
) -> ModelAsset {
    prefix = "models/players/" + character + "/";
    model = parse_md3(library.read(prefix + part + ".md3"));
    mappings: dict[str, str] = {};
    skin_file = prefix + part + "_" + skin + ".skin";
    if not library.exists(skin_file) {
        skin_file = prefix + part + "_default.skin";
    }
    for line in library.read(skin_file).decode("utf-8").splitlines() {
        fields = line.split(",");
        if len(fields) == 2 and fields[1].strip() {
            mappings[fields[0].strip()] = fields[1].strip();
        }
    }
    skins: list[Texture] = [];
    for surface in model.surfaces {
        if surface.name not in mappings { raise ValueError("Missing player surface skin: " + surface.name); }
        material = mappings[surface.name];
        texture = Texture(name=material);
        library.pk3.texture(texture);
        if not texture.encoded { raise ValueError("Missing player skin: " + material); }
        surface.stages = library.pk3.model_stages(material);
        skins.append(texture);
    }
    return ModelAsset(model=model, skins=skins);
}

"""A Q3 character as CG_ParseAnimationFile reads it: the three part models,
the animation table (`animations` rows are [first, count, fps] as listed; the
clips are the client's, with legs frames shifted past the torso-only ones),
and its footstep sound type."""
obj CharacterRig {
    has lower: ModelAsset,
        upper: ModelAsset,
        head: ModelAsset,
        animations: list[list[int]],
        clips: list[AnimationClip] = [],
        footsteps: str = "step",
        sex: str = "m",
        offset: int = 0;
}

# cg_main.c footstep sound names by animation.cfg footsteps type.
glob Q3_FOOTSTEP_NAMES: dict[str, str] = {
    "default": "step",
    "normal": "step",
    "boot": "boot",
    "flesh": "flesh",
    "mech": "mech",
    "energy": "energy"
};

def character_rig(library: AssetLibrary, character: str = "sarge", skin: str = "default") -> CharacterRig {
    animations: list[list[int]] = [];
    rows: list[list[float]] = [];
    footsteps = "step";
    sex = "m";
    config = "models/players/" + character + "/animation.cfg";
    for line in library.read(config).decode("utf-8").splitlines() {
        fields = line.split("//")[0].split();
        if not fields {
            continue;
        }
        keyword = fields[0].lower();
        if keyword == "footsteps" and len(fields) >= 2 {
            footsteps = Q3_FOOTSTEP_NAMES.get(fields[1].lower(), "step");
        } elif keyword == "sex" and len(fields) >= 2 {
            sex = fields[1].lower()[:1];
        } elif len(fields) >= 4 and fields[0][0] in "0123456789" and len(rows) < 25 {
            animations.append([int(fields[0]), int(fields[1]), int(fields[3])]);
            rows.append([float(fields[0]), float(fields[1]), float(fields[2]), float(fields[3])]);
        }
    }
    if len(rows) < 25 { raise ValueError("Incomplete player animations"); }
    # Legs-only sequences skip the torso-only frames lower.md3 lacks.
    offset = animations[13][0] - animations[6][0];
    for i in range(13, 25) {
        rows[i][0] = rows[i][0] - float(offset);
    }
    return CharacterRig(
        lower=player_part(library, "lower", character, skin),
        upper=player_part(library, "upper", character, skin),
        head=player_part(library, "head", character, skin),
        animations=animations,
        clips=rig_clips(rows),
        footsteps=footsteps,
        sex=sex,
        offset=offset
    );
}

"""The world's shared model resource for `key`, registered once."""
def shared_resource(world: World, resources: dict[str, ModelResource], key: str, asset: ModelAsset) -> ModelResource {
    if key not in resources {
        resources[key] = ModelResource(name=key, model=asset.model, skins=asset.skins);
        world +>:HasModelResource:+> resources[key];
    }
    return resources[key];
}

"""A body for one character, wearing its shared part models. `key` is
"q3:models/players/<model>:<skin>"; each part adds ":lower", ":upper" or
":head"."""
def character_body(
    world: World,
    resources: dict[str, ModelResource],
    rig: CharacterRig,
    key: str,
    seed: int = 1
) -> PlayerRig {
    body = dress_rig(
        rig.clips,
        shared_resource(world, resources, key + ":lower", rig.lower),
        shared_resource(world, resources, key + ":upper", rig.upper),
        shared_resource(world, resources, key + ":head", rig.head),
        seed
    );
    body.character = key;
    body.footsteps = rig.footsteps;
    return body;
}

"""Every weapon's world models (cg_weapons.c CG_RegisterWeapon: the gun, and
its _barrel and _flash models where they exist), shared by every body."""
def weapon_kits(
    world: World,
    library: AssetLibrary,
    resources: dict[str, ModelResource],
    kits: dict[str, WeaponKit]
) -> dict[str, WeaponKit] {
    for (weapon, path) in Q3_HELD_WEAPONS.items() {
        if weapon in kits or not library.exists(path) {
            continue;
        }
        kit = WeaponKit(
            key=weapon,
            light=Q3_FLASH_LIGHTS.get(weapon, Vec3(x=1.0, y=1.0, z=1.0)),
            continuous=weapon in ["lightning", "gauntlet"]
        );
        kit +>:KitPart(role="weapon"):+> shared_resource(world, resources, "q3:" + path, library.model(path));
        for role in ["barrel", "flash"] {
            extra = path[:-4] + "_" + role + ".md3";
            if library.exists(extra) {
                kit +>:KitPart(role=role):+> shared_resource(world, resources, "q3:" + extra, library.model(extra));
            }
        }
        kits[weapon] = kit;
    }
    return kits;
}

"""Q3's powerup shaders (quad, regeneration and battle suit shells and the
invisibility shader, cg_main.c CG_RegisterGraphics) as model resources the
renderer draws bodies and weapons with."""
def powerup_shells(world: World, library: AssetLibrary, resources: dict[str, ModelResource]) {
    for shader in [
        "powerups/quad", "powerups/regen", "powerups/battleSuit", "powerups/invisibility",
        "powerups/quadWeapon", "powerups/battleWeapon"
    ] {
        key = "shader:" + shader;
        if key in resources {
            continue;
        }
        stages = library.pk3.model_stages(shader, True);
        if not stages {
            continue;
        }
        model = AnimatedModel(surfaces=[AnimatedSurface(name=shader, stages=stages)]);
        resources[key] = ModelResource(name=key, model=model, skins=[stages[0].texture]);
        world +>:HasModelResource:+> resources[key];
    }
}
