"""Q3 botlib character files. A character file holds `skill N { KEY value }`
blocks for skills 1, 4 and 5; be_ai_char.c loads an exact block or interpolates
the float characteristics between 1 and 4 (or 4 and 5), and fills anything
missing from bots/default_c.c. Weapon weights come from the `#define W_*`
values in the character's weight file, as fw_weap.c uses them."""
import from engine.world.bot_character { BotCharacter }
import from engine.assets.library { AssetLibrary }

glob BOT_WEAPON_NAMES: dict[str, str] = {
    "GAUNTLET": "gauntlet",
    "MACHINEGUN": "machinegun",
    "SHOTGUN": "shotgun",
    "GRENADELAUNCHER": "grenadelauncher",
    "ROCKETLAUNCHER": "rocketlauncher",
    "LIGHTNING": "lightning",
    "RAILGUN": "railgun",
    "PLASMAGUN": "plasmagun",
    "BFG10K": "bfg"
};

def strip_comment(line: str) -> str {
    cut = line.find("//");
    return (line[:cut] if cut >= 0 else line).strip();
}

"""`skill N { KEY value }` blocks, keyed by skill."""
def skill_blocks(text: str) -> dict[int, dict[str, str]] {
    blocks: dict[int, dict[str, str]] = {};
    current: dict[str, str] | None = None;
    level = 0;
    for raw in text.splitlines() {
        line = strip_comment(raw);
        if not line or line.startswith("#") {
            continue;
        }
        if line.startswith("skill") {
            parts = line.split();
            if len(parts) >= 2 {
                level = int(float(parts[1]));
                current = {};
                blocks[level] = current;
            }
            continue;
        }
        if line in ["{", "}"] {
            continue;
        }
        if current is not None {
            parts = line.split(None, 1);
            if len(parts) == 2 {
                current[parts[0]] = parts[1].strip().strip('"');
            }
        }
    }
    return blocks;
}

def numeric(value: str) -> bool {
    try {
        float(value);
        return True;
    } except ValueError {
        return False;
    }
}

"""be_ai_char.c BotLoadCharacter: an exact skill block, or float values
interpolated between the neighbouring authored skills."""
def values_at(blocks: dict[int, dict[str, str]], skill: float) -> dict[str, str] {
    whole = int(skill);
    if float(whole) == skill and whole in blocks {
        return dict(blocks[whole]);
    }
    low = 1 if skill < 4.0 else 4;
    high = 4 if skill < 4.0 else 5;
    if low not in blocks or high not in blocks {
        best = -1;
        for level in blocks.keys() {
            if best < 0 or abs(float(level) - skill) < abs(float(best) - skill) {
                best = level;
            }
        }
        return dict(blocks[best]) if best >= 0 else {};
    }
    scale = (skill - float(low)) / float(high - low);
    result = dict(blocks[low]);
    for (key, value) in blocks[high].items() {
        if key in result and numeric(result[key]) and numeric(value) {
            first = float(result[key]);
            result[key] = str(first + (float(value) - first) * scale);
        } elif key not in result {
            result[key] = value;
        }
    }
    return result;
}

"""`#define W_NAME value` weights, with fw_weap.c's #ifndef defaults."""
def weapon_weights(text: str) -> dict[str, int] {
    weights: dict[str, int] = {};
    for raw in text.splitlines() {
        parts = strip_comment(raw).split();
        if len(parts) >= 3 and parts[0] == "#define" and parts[1].startswith("W_") {
            name = parts[1][2:];
            if name in BOT_WEAPON_NAMES and numeric(parts[2]) {
                weights[BOT_WEAPON_NAMES[name]] = int(float(parts[2]));
            }
        }
    }
    return weights;
}

def unit(values: dict[str, str], key: str, fallback: float) -> float {
    if key in values and numeric(values[key]) {
        return max(0.0, min(1.0, float(values[key])));
    }
    return fallback;
}

"""Build a bot's character from its aifile at a Q3 skill level (1-5)."""
def character_from(
    text: str, fallback_text: str, weights_text: str, skill: float
) -> BotCharacter {
    values = values_at(skill_blocks(text), skill);
    if fallback_text {
        for (key, value) in values_at(skill_blocks(fallback_text), skill).items() {
            if key not in values {
                values[key] = value;
            }
        }
    }
    character = BotCharacter(
        name=values.get("CHARACTERISTIC_NAME", ""),
        skill=skill,
        aim_skill=unit(values, "CHARACTERISTIC_AIM_SKILL", 0.5),
        aim_accuracy=unit(values, "CHARACTERISTIC_AIM_ACCURACY", 0.5),
        reaction=unit(values, "CHARACTERISTIC_REACTIONTIME", 0.5),
        fire_throttle=unit(values, "CHARACTERISTIC_FIRETHROTTLE", 1.0),
        view_factor=unit(values, "CHARACTERISTIC_VIEW_FACTOR", 0.8),
        view_maxchange=float(values.get("CHARACTERISTIC_VIEW_MAXCHANGE", "240"))
            if numeric(values.get("CHARACTERISTIC_VIEW_MAXCHANGE", "240"))
            else 240.0,
        attack_skill=unit(values, "CHARACTERISTIC_ATTACK_SKILL", 0.5),
        aggression=unit(values, "CHARACTERISTIC_AGGRESSION", 0.5),
        self_preservation=unit(values, "CHARACTERISTIC_SELFPRESERVATION", 0.5),
        jumper=unit(values, "CHARACTERISTIC_JUMPER", 0.0),
        croucher=unit(values, "CHARACTERISTIC_CROUCHER", 0.0),
        alertness=unit(values, "CHARACTERISTIC_ALERTNESS", 0.5),
        weights=weapon_weights(weights_text)
    );
    for (suffix, weapon) in BOT_WEAPON_NAMES.items() {
        accuracy = "CHARACTERISTIC_AIM_ACCURACY_" + suffix;
        if accuracy in values and numeric(values[accuracy]) {
            character.accuracy[weapon] = unit(values, accuracy, character.aim_accuracy);
        }
        leading = "CHARACTERISTIC_AIM_SKILL_" + suffix;
        if leading in values and numeric(values[leading]) {
            character.leading[weapon] = unit(values, leading, character.aim_skill);
        }
    }
    return character;
}

def load_bot_character(library: AssetLibrary, aifile: str, skill: float) -> BotCharacter {
    path = "botfiles/" + aifile;
    fallback_path = "botfiles/bots/default_c.c";
    text = library.read(path).decode("utf-8") if aifile and library.exists(path) else "";
    fallback = library.read(fallback_path).decode("utf-8")
        if library.exists(fallback_path)
        else "";
    blocks = skill_blocks(text) if text else skill_blocks(fallback);
    weights_path = "";
    for level in blocks.keys() {
        if "CHARACTERISTIC_WEAPONWEIGHTS" in blocks[level] {
            weights_path = "botfiles/" + blocks[level]["CHARACTERISTIC_WEAPONWEIGHTS"];
        }
    }
    weights_text = library.read(weights_path).decode("utf-8")
        if weights_path and library.exists(weights_path)
        else "";
    return character_from(text if text else fallback, fallback, weights_text, skill);
}
