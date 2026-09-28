"""Q3 botlib bot files (botfiles/ in the game's pk3s). A character file holds
`skill N { KEY value }` blocks for skills 1, 4 and 5; be_ai_char.c loads an
exact block or interpolates the float characteristics between 1 and 4 (or 4
and 5), and fills anything missing from bots/default_c.c. The character
names its item and weapon weight files and its chat file, which, like items.c,
weapons.c and rnd.c, go through botlib's precompiler (engine/formats)."""
import from engine.world.bot_character { BotCharacter }
import from engine.assets.library { AssetLibrary }
import from engine.formats.botscript { ScriptToken, precompile, script_includes }
import from engine.formats.botconfig {
    WeightConfig,
    ItemInfo,
    ChatMessage,
    read_weight_config,
    read_item_config,
    read_weapon_names,
    read_initial_chat,
    read_random_strings
}

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

"""The botfiles folder of the game's assets, and what has been read from it:
script texts by path (relative to botfiles/, as botlib's PC_SetBaseFolder
makes them), weight configs by path, the item and weapon configs, the
random strings and chats. Without a `library` only `texts` are known."""
obj BotFiles {
    has library: AssetLibrary | None = None,
        texts: dict[str, str] = {},
        weights: dict[str, WeightConfig] = {},
        items: list[ItemInfo] = [],
        items_read: bool = False,
        weapons: dict[int, str] = {},
        weapons_read: bool = False,
        randoms: dict[str, list[ChatMessage]] = {},
        randoms_read: bool = False,
        chats: dict[str, dict[str, list[ChatMessage]]] = {};

    """A script's text, "" when there is none."""
    def text(path: str) -> str {
        if path in self.texts {
            return self.texts[path];
        }
        library = self.library;
        found = "";
        if library is not None and library.exists("botfiles/" + path) {
            found = library.read("botfiles/" + path).decode("latin-1");
        }
        self.texts[path] = found;
        return found;
    }

    """A script and everything it includes, by path."""
    def sources(path: str) -> dict[str, str] {
        files: dict[str, str] = {};
        waiting = [path];
        while waiting {
            name = waiting.pop();
            if name in files {
                continue;
            }
            text = self.text(name);
            if not text {
                raise ValueError("Missing bot file botfiles/" + name);
            }
            files[name] = text;
            for included in script_includes(text) {
                if included not in files {
                    waiting.append(included);
                }
            }
        }
        return files;
    }

    def tokens(path: str) -> list[ScriptToken] {
        return precompile(path, self.sources(path));
    }

    """ReadWeightConfig, once per file."""
    def weight_config(path: str) -> WeightConfig {
        if path not in self.weights {
            self.weights[path] = read_weight_config(self.tokens(path));
        }
        return self.weights[path];
    }

    """LoadItemConfig("items.c")."""
    def item_config() -> list[ItemInfo] {
        if not self.items_read {
            self.items_read = True;
            self.items = read_item_config(self.tokens("items.c"));
        }
        return self.items;
    }

    """LoadWeaponConfig("weapons.c")'s names by weapon number."""
    def weapon_names() -> dict[int, str] {
        if not self.weapons_read {
            self.weapons_read = True;
            self.weapons = read_weapon_names(self.tokens("weapons.c"));
        }
        return self.weapons;
    }

    """BotLoadRandomStrings("rnd.c")."""
    def random_strings() -> dict[str, list[ChatMessage]] {
        if not self.randoms_read {
            self.randoms_read = True;
            self.randoms = read_random_strings(self.tokens("rnd.c"));
        }
        return self.randoms;
    }

    """BotLoadInitialChat: the chat `name`'s types in a chat file. Each bot
    keeps its own copy, as it marks the messages it has used."""
    def initial_chat(path: str, name: str) -> dict[str, list[ChatMessage]] {
        key = path + ":" + name.lower();
        if key not in self.chats {
            self.chats[key] = read_initial_chat(self.tokens(path), name);
        }
        copy: dict[str, list[ChatMessage]] = {};
        for (kind, messages) in self.chats[key].items() {
            copy[kind] = [ChatMessage(parts=message.parts) for message in messages];
        }
        return copy;
    }
}

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

"""be_ai_char.c Characteristic_BFloat: a float characteristic kept within
[`low`, `high`], or `fallback` when missing."""
def bounded(values: dict[str, str], key: str, fallback: float, low: float, high: float) -> float {
    if key in values and numeric(values[key]) {
        return max(low, min(high, float(values[key])));
    }
    return fallback;
}

def unit(values: dict[str, str], key: str, fallback: float) -> float {
    return bounded(values, key, fallback, 0.0, 1.0);
}

"""Build a bot's character from its aifile at a Q3 skill level (1-5); with
`files`, its fuzzy weights and chats too (ai_main.c BotAISetupClient)."""
def character_from(
    text: str, fallback_text: str, skill: float, files: BotFiles | None = None
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
        gender=values.get("CHARACTERISTIC_GENDER", "male"),
        skill=skill,
        aim_skill=unit(values, "CHARACTERISTIC_AIM_SKILL", 0.5),
        aim_accuracy=unit(values, "CHARACTERISTIC_AIM_ACCURACY", 0.5),
        reaction=unit(values, "CHARACTERISTIC_REACTIONTIME", 0.5),
        fire_throttle=unit(values, "CHARACTERISTIC_FIRETHROTTLE", 1.0),
        view_factor=bounded(values, "CHARACTERISTIC_VIEW_FACTOR", 0.8, 0.01, 1.0),
        view_maxchange=bounded(values, "CHARACTERISTIC_VIEW_MAXCHANGE", 240.0, 1.0, 1800.0),
        attack_skill=unit(values, "CHARACTERISTIC_ATTACK_SKILL", 0.5),
        aggression=unit(values, "CHARACTERISTIC_AGGRESSION", 0.5),
        self_preservation=unit(values, "CHARACTERISTIC_SELFPRESERVATION", 0.5),
        jumper=unit(values, "CHARACTERISTIC_JUMPER", 0.0),
        croucher=unit(values, "CHARACTERISTIC_CROUCHER", 0.0),
        weapon_jumping=unit(values, "CHARACTERISTIC_WEAPONJUMPING", 0.0),
        alertness=unit(values, "CHARACTERISTIC_ALERTNESS", 0.5),
        chat_insult=unit(values, "CHARACTERISTIC_CHAT_INSULT", 0.0),
        chat_misc=unit(values, "CHARACTERISTIC_CHAT_MISC", 0.0),
        chat_start_end_level=unit(values, "CHARACTERISTIC_CHAT_STARTENDLEVEL", 0.0),
        chat_enter_exit_game=unit(values, "CHARACTERISTIC_CHAT_ENTEREXITGAME", 0.0),
        chat_kill=unit(values, "CHARACTERISTIC_CHAT_KILL", 0.0),
        chat_death=unit(values, "CHARACTERISTIC_CHAT_DEATH", 0.0),
        chat_enemy_suicide=unit(values, "CHARACTERISTIC_CHAT_ENEMYSUICIDE", 0.0),
        chat_hit_talking=unit(values, "CHARACTERISTIC_CHAT_HITTALKING", 0.0),
        chat_hit_no_death=unit(values, "CHARACTERISTIC_CHAT_HITNODEATH", 0.0),
        chat_hit_no_kill=unit(values, "CHARACTERISTIC_CHAT_HITNOKILL", 0.0),
        chat_random=unit(values, "CHARACTERISTIC_CHAT_RANDOM", 0.0)
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
    if files is not None {
        attach_bot_files(character, values, files);
    }
    return character;
}

"""The character's weights and chats (BotLoadItemWeights with
ItemWeightIndex, BotLoadWeaponWeights with WeaponWeightIndex,
BotLoadChatFile)."""
def attach_bot_files(character: BotCharacter, values: dict[str, str], files: BotFiles) {
    weapon_path = values.get("CHARACTERISTIC_WEAPONWEIGHTS", "");
    if weapon_path {
        character.weapon_weights = files.weight_config(weapon_path);
        for (number, name) in files.weapon_names().items() {
            character.weapon_numbers[number] = character.weapon_weights.find(name);
        }
    }
    item_path = values.get("CHARACTERISTIC_ITEMWEIGHTS", "");
    if item_path {
        character.item_weights = files.weight_config(item_path);
        for info in files.item_config() {
            character.item_numbers[info.classname] = character.item_weights.find(info.classname);
        }
    }
    chat_path = values.get("CHARACTERISTIC_CHAT_FILE", "");
    chat_name = values.get("CHARACTERISTIC_CHAT_NAME", "");
    if chat_path and chat_name and files.text(chat_path) {
        character.chats = files.initial_chat(chat_path, chat_name);
        character.random_strings = files.random_strings();
    }
}

def load_bot_character(files: BotFiles, aifile: str, skill: float) -> BotCharacter {
    text = files.text(aifile) if aifile else "";
    fallback = files.text("bots/default_c.c");
    return character_from(text if text else fallback, fallback, skill, files);
}
