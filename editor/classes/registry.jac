"""What the studio knows about entity classes: which exist, whether they are
made of brushes, what each field means and what kind of value it takes, and
what the spawnflags' bits are called. The inspector and the class list are
built from this; a class it does not know is still editable field by field.

The table is text, a line a class:

    name | point or brush | games | what it is | fields | spawnflags

A field is `key:kind:default:choices`, with kinds n (number), t (text),
a (angle), v (three numbers), c (colour), l (the targetname it fires),
k (its own targetname) and o (one of `value=label;...`). Spawnflags are the
bits' names from 1 upward, an empty name for a bit not used."""

"""One field of a class."""
obj FieldInfo {
    has name: str,
        # "number", "text", "angle", "vector", "color", "link", "name", "choice" or "flags".
        kind: str = "text",
        preset: str = "",
        help: str = "",
        # For a choice: (value, label) pairs.
        choices: list[tuple[str, str]] = [];
}

"""One entity class."""
obj ClassInfo {
    has name: str,
        solid: bool = False,
        games: str = "",
        help: str = "",
        fields: list[FieldInfo] = [],
        flags: list[str] = [];

    def field(key: str) -> FieldInfo | None {
        for known in self.fields {
            if known.name == key {
                return known;
            }
        }
        return None;
    }
}

glob FIELD_KINDS: dict[str, str] = {
    "n": "number", "t": "text", "a": "angle", "v": "vector", "c": "color", "l": "link", "k": "name", "o": "choice"
};

"""What a field means wherever it appears, when a class does not say."""
glob COMMON_FIELDS: str = "origin:v::Where it is|angle:a::The way it faces, in degrees (-1 up, -2 down)|"
    + "angles:v::Pitch, yaw and roll|targetname:k::The name other entities fire it by|"
    + "target:l::The targetname it fires|killtarget:l::The targetname it removes when fired|"
    + "message:t::Words shown to the player|spawnflags:n::Its options, as one number|"
    + "delay:n::Seconds before it fires its target|wait:n::Seconds before it can be used again|"
    + "speed:n::How fast it moves|dmg:n::The damage it does|health:n::Shots it takes before it acts|"
    + "lip:n::How much of it stays in view when open|height:n::How far it travels|"
    + "sounds:n::Which set of sounds it uses|light:n:300:How bright it is|_color:c:1 1 1:Its colour|"
    + "style:n::The light style it flickers by|count:n::How many|map:t::The level it leads to|"
    + "model:t::The map model or file it draws|noise:t::The sound it plays|"
    + "_group_name:t::What the group is called|prefab:t::The prefab file it stands for";

glob DOOR_SOUNDS: str = "0=silent;1=stone;2=machine;3=stone chain;4=screechy metal";

glob CLASS_TABLE: list[str] = [
    "worldspawn|brush|q1 q2 q3|The level itself: its brushes are the world|message:t::The level's name,worldtype:o:0:0=medieval;1=metal;2=base,sounds:n::The CD track,wad:t::Texture files a compiler reads,sky:t::Quake II: the sky's name,gravity:n:800:|",
    "info_player_start|point|q1 q2 q3|Where the player begins|angle:a::|",
    "info_player_start2|point|q1|Where the player begins after the episode's rune|angle:a::|",
    "info_player_deathmatch|point|q1 q2 q3|A place players appear in deathmatch|angle:a::|",
    "info_player_coop|point|q1 q2|A place co-operative players begin|angle:a::|",
    "info_player_intermission|point|q2 q3|Where the camera rests between levels|angles:v::|",
    "info_intermission|point|q1|Where the camera rests between levels|mangle:v::Pitch yaw and roll of the view|",
    "info_teleport_destination|point|q1|Where a teleporter sends you|targetname:k::,angle:a::|",
    "info_null|point|q1 q2 q3|A point to aim at, removed when the level starts|targetname:k::|",
    "info_notnull|point|q1 q2 q3|A point to aim at that stays|targetname:k::|",
    "light|point|q1 q2 q3|A light|light:n:300:,_color:c:1 1 1:,style:o:0:0=steady;1=flicker;2=slow strong pulse;3=candle;4=fast strobe;5=gentle pulse;6=flicker 2;7=candle 2;8=candle 3;9=slow strobe;10=fluorescent flicker;11=slow pulse,targetname:k::A name lets it be switched,target:l::A point it shines toward|START_OFF",
    "light_fluoro|point|q1|A light with a hum|light:n:300:,style:n::|START_OFF",
    "light_fluorospark|point|q1|A sparking light|light:n:300:,style:n:10:|",
    "light_globe|point|q1|A globe of light|light:n:300:|",
    "light_torch_small_walltorch|point|q1|A wall torch|light:n:200:|",
    "light_flame_large_yellow|point|q1|A large flame|light:n:300:|",
    "light_flame_small_yellow|point|q1|A small flame|light:n:200:|",
    "light_flame_small_white|point|q1|A small white flame|light:n:200:|",
    "func_door|brush|q1 q2 q3|A door that slides open|angle:a::The way it opens,speed:n:100:,wait:n:3:Seconds open (-1 stays open),lip:n:8:,dmg:n:2:,health:n::Shot open when set,sounds:o:0:" + DOOR_SOUNDS + ",targetname:k::A name makes it open only when fired,target:l::,message:t::|START_OPEN,,DOOR_DONT_LINK,GOLD_KEY,SILVER_KEY,TOGGLE",
    "func_door_secret|brush|q1 q2|A door that moves back and then aside|angle:a::,t_width:n::,t_length:n::,wait:n:5:,dmg:n:2:,sounds:o:3:1=medieval;2=metal;3=base|OPEN_ONCE,FIRST_LEFT,FIRST_DOWN,NO_SHOOT,ALWAYS_SHOOT",
    "func_door_rotating|brush|q2|A door that swings on its origin brush|speed:n:100:,distance:n:90:Degrees it turns,wait:n:3:,dmg:n:2:,targetname:k::|START_OPEN,REVERSE,CRUSHER,NOMONSTER,ANIMATED,TOGGLE,X_AXIS,Y_AXIS",
    "func_button|brush|q1 q2 q3|A button that fires its target when pressed|angle:a::The way it moves,target:l::,speed:n:40:,wait:n:1:,lip:n:4:,health:n::Shot rather than touched when set,sounds:o:0:0=steam metal;1=wooden clunk;2=metallic click;3=in-out,delay:n::|",
    "func_plat|brush|q1 q2 q3|A lift that rises when stood on|speed:n:150:,height:n::,sounds:o:1:1=base fast;2=chain slow,targetname:k::|PLAT_LOW_TRIGGER",
    "func_train|brush|q1 q2 q3|A platform that follows path_corners|target:l::Its first path_corner,speed:n:100:,dmg:n:2:,sounds:o:0:0=silent;1=ratchet metal,targetname:k::|START_ON,TOGGLE,BLOCK_STOPS",
    "func_wall|brush|q1 q2|A wall that changes texture when fired|targetname:k::|",
    "func_illusionary|brush|q1|A wall you can walk through||",
    "func_static|brush|q3|Brushes that stay put but are their own model|targetname:k::|",
    "func_episodegate|brush|q1|A wall that appears once the episode is done||E1,E2,E3,E4",
    "func_bossgate|brush|q1|A wall that goes once every episode is done||",
    "func_rotating|brush|q2 q3|Brushes that turn for ever|speed:n:100:,dmg:n:2:,targetname:k::|START_ON,REVERSE,X_AXIS,Y_AXIS,TOUCH_PAIN,STOP,ANIMATED,ANIMATED_FAST",
    "func_explosive|brush|q2|Brushes that blow up when shot or fired|health:n:100:,dmg:n::,mass:n:75:,targetname:k::,target:l::|TRIGGER_SPAWN,ANIMATED,ANIMATED_FAST",
    "func_timer|point|q2|Fires its target again and again|wait:n:1:,random:n::,delay:n::,pausetime:n::,target:l::,targetname:k::|START_ON",
    "func_bobbing|brush|q3|Brushes that bob up and down|height:n:32:,speed:n:4:,phase:n::|X_AXIS,Y_AXIS",
    "func_pendulum|brush|q3|Brushes that swing|speed:n:30:,phase:n::|",
    "func_group|brush|q1 q2 q3|Brushes held together; part of the world when built|_group_name:t::|",
    "path_corner|point|q1 q2 q3|A stop on a train's or a monster's way|targetname:k::,target:l::The next stop,wait:n::Seconds to pause here|",
    "trigger_once|brush|q1 q2|Fires its target the first time it is touched|target:l::,targetname:k::,message:t::,delay:n::,health:n::,sounds:o:0:0=silent;1=secret;2=beep beep;3=large switch|NOTOUCH",
    "trigger_multiple|brush|q1 q2 q3|Fires its target every time it is touched|target:l::,wait:n:0.2:,targetname:k::,message:t::,delay:n::,health:n::,sounds:o:0:0=silent;1=secret;2=beep beep;3=large switch|NOTOUCH",
    "trigger_relay|point|q1 q2|Fires its target when it is fired|targetname:k::,target:l::,killtarget:l::,delay:n::,message:t::|",
    "trigger_counter|point|q1 q2|Fires its target once it has been fired enough times|targetname:k::,target:l::,count:n:2:,message:t::|NOMESSAGE",
    "trigger_always|point|q2 q3|Fires its target when the level starts|target:l::,delay:n::|",
    "trigger_teleport|brush|q1 q3|Sends what touches it to its target|target:l::An info_teleport_destination,targetname:k::A name makes it wait to be fired|PLAYER_ONLY,SILENT",
    "trigger_changelevel|brush|q1 q2|Ends the level|map:t::The level to go to,targetname:k::|NO_INTERMISSION",
    "trigger_hurt|brush|q1 q2 q3|Hurts what stands in it|dmg:n:5:,targetname:k::|START_OFF,TOGGLE,SILENT,NO_PROTECTION,SLOW",
    "trigger_push|brush|q1 q2 q3|Pushes what touches it|angle:a::The way it pushes,speed:n:1000:,target:l::Quake III: the point to throw toward|PUSH_ONCE",
    "trigger_secret|brush|q1|Counts as a secret found|message:t::,sounds:o:1:0=silent;1=secret;2=beep beep;3=large switch,target:l::|",
    "trigger_setskill|brush|q1|Sets the skill for the next level|message:o:1:0=easy;1=normal;2=hard;3=nightmare|",
    "trigger_onlyregistered|brush|q1|Fires its target only in the registered game|target:l::,message:t::|",
    "trigger_monsterjump|brush|q1|Makes a monster leap|angle:a::,speed:n:200:,height:n:200:|",
    "trigger_key|point|q2|Fires its target when the player carries a key|item:t::The key's classname,target:l::,targetname:k::|",
    "target_speaker|point|q2 q3|Plays a sound|noise:t::,volume:n:1:,attenuation:n:1:,targetname:k::|LOOPED_ON,LOOPED_OFF,RELIABLE",
    "target_explosion|point|q2|An explosion when fired|dmg:n::,delay:n::,targetname:k::|",
    "target_position|point|q3|A point to aim at|targetname:k::|",
    "target_relay|point|q3|Fires its target when it is fired|targetname:k::,target:l::|RED_ONLY,BLUE_ONLY,RANDOM",
    "target_delay|point|q3|Fires its target a while after it is fired|targetname:k::,target:l::,wait:n:1:,random:n::|",
    "misc_teleporter_dest|point|q2 q3|Where a teleporter sends you|targetname:k::,angle:a::|",
    "misc_teleporter|point|q2|A teleporter pad|target:l::|",
    "misc_explobox|point|q1|An exploding box||",
    "misc_explobox2|point|q1|A small exploding box||",
    "misc_fireball|point|q1|Lava balls that fly up|speed:n:1000:|",
    "misc_prefab|point|q1 q2 q3|A linked prefab: built as the file's contents where it stands|prefab:t::|",
    "ambient_drip|point|q1|The sound of dripping||",
    "ambient_drone|point|q1|A machine's drone||",
    "ambient_comp_hum|point|q1|A computer's hum||",
    "ambient_swamp1|point|q1|Frogs||",
    "ambient_suck_wind|point|q1|Wind||",
    "air_bubbles|point|q1|Bubbles rising through water||",
    "monster_army|point|q1|A grunt|angle:a::,targetname:k::,target:l::A path_corner to walk to|AMBUSH",
    "monster_dog|point|q1|A rottweiler|angle:a::,targetname:k::|AMBUSH",
    "monster_enforcer|point|q1|An enforcer|angle:a::,targetname:k::|AMBUSH",
    "monster_ogre|point|q1|An ogre|angle:a::,targetname:k::|AMBUSH",
    "monster_knight|point|q1|A knight|angle:a::,targetname:k::|AMBUSH",
    "monster_hell_knight|point|q1|A death knight|angle:a::,targetname:k::|AMBUSH",
    "monster_zombie|point|q1|A zombie|angle:a::,targetname:k::|CRUCIFIED,AMBUSH",
    "monster_wizard|point|q1|A scrag|angle:a::,targetname:k::|AMBUSH",
    "monster_demon1|point|q1|A fiend|angle:a::,targetname:k::|AMBUSH",
    "monster_shambler|point|q1|A shambler|angle:a::,targetname:k::|AMBUSH",
    "monster_shalrath|point|q1|A vore|angle:a::,targetname:k::|AMBUSH",
    "monster_tarbaby|point|q1|A spawn|angle:a::,targetname:k::|AMBUSH",
    "monster_fish|point|q1|A rotfish|angle:a::,targetname:k::|AMBUSH",
    "monster_boss|point|q1|Chthon||",
    "monster_oldone|point|q1|Shub-Niggurath||",
    "monster_soldier_light|point|q2|A light guard|angle:a::,targetname:k::,target:l::|AMBUSH,TRIGGER_SPAWN,SIGHT",
    "monster_soldier|point|q2|A shotgun guard|angle:a::,targetname:k::,target:l::|AMBUSH,TRIGGER_SPAWN,SIGHT",
    "monster_soldier_ss|point|q2|A machinegun guard|angle:a::,targetname:k::,target:l::|AMBUSH,TRIGGER_SPAWN,SIGHT",
    "monster_infantry|point|q2|An enforcer|angle:a::,targetname:k::,target:l::|AMBUSH,TRIGGER_SPAWN,SIGHT",
    "monster_gunner|point|q2|A gunner|angle:a::,targetname:k::,target:l::|AMBUSH,TRIGGER_SPAWN,SIGHT",
    "monster_berserk|point|q2|A berserker|angle:a::,targetname:k::,target:l::|AMBUSH,TRIGGER_SPAWN,SIGHT",
    "monster_gladiator|point|q2|A gladiator|angle:a::,targetname:k::,target:l::|AMBUSH,TRIGGER_SPAWN,SIGHT",
    "monster_tank|point|q2|A tank|angle:a::,targetname:k::,target:l::|AMBUSH,TRIGGER_SPAWN,SIGHT",
    "monster_tank_commander|point|q2|A tank commander|angle:a::,targetname:k::,target:l::|AMBUSH,TRIGGER_SPAWN,SIGHT",
    "item_health|point|q1 q2 q3|Health||ROTTEN,MEGA",
    "item_armor1|point|q1|Green armour||",
    "item_armor2|point|q1|Yellow armour||",
    "item_armorInv|point|q1|Red armour||",
    "item_shells|point|q1 q3|Shells||BIG",
    "item_spikes|point|q1|Nails||BIG",
    "item_rockets|point|q1 q3|Rockets||BIG",
    "item_cells|point|q1 q3|Cells||BIG",
    "item_key1|point|q1|The silver key||",
    "item_key2|point|q1|The gold key||",
    "item_sigil|point|q1|An episode's rune||E1,E2,E3,E4",
    "item_artifact_invulnerability|point|q1|The pentagram of protection||",
    "item_artifact_envirosuit|point|q1|The biosuit||",
    "item_artifact_invisibility|point|q1|The ring of shadows||",
    "item_artifact_super_damage|point|q1|Quad damage||",
    "item_armor_body|point|q2 q3|Body armour||",
    "item_armor_combat|point|q2 q3|Combat armour||",
    "item_armor_jacket|point|q2|Jacket armour||",
    "item_armor_shard|point|q2 q3|An armour shard||",
    "item_health_large|point|q2 q3|Large health||",
    "item_health_mega|point|q2 q3|Megahealth||",
    "item_quad|point|q2 q3|Quad damage||",
    "weapon_supershotgun|point|q1 q2|The double-barrelled shotgun||",
    "weapon_nailgun|point|q1|The nailgun||",
    "weapon_supernailgun|point|q1|The perforator||",
    "weapon_grenadelauncher|point|q1 q2 q3|The grenade launcher||",
    "weapon_rocketlauncher|point|q1 q2 q3|The rocket launcher||",
    "weapon_lightning|point|q1 q3|The thunderbolt||",
    "weapon_shotgun|point|q2 q3|The shotgun||",
    "weapon_machinegun|point|q2 q3|The machinegun||",
    "weapon_chaingun|point|q2|The chaingun||",
    "weapon_railgun|point|q2 q3|The railgun||",
    "weapon_hyperblaster|point|q2|The hyperblaster||",
    "weapon_bfg|point|q2 q3|The BFG||",
    "weapon_plasmagun|point|q3|The plasma gun||",
    "team_CTF_redflag|point|q3|The red flag||",
    "team_CTF_blueflag|point|q3|The blue flag||"
];

"""The table, read once."""
glob CLASS_CACHE: dict[str, ClassInfo] = {};

"""A field from its `key:kind:default:rest` words. `rest` is help, or for a
choice the `value=label;...` list."""
def read_field(words: str) -> FieldInfo {
    parts = words.split(":");
    name = parts[0].strip();
    kind = FIELD_KINDS.get(parts[1].strip(), "text") if len(parts) > 1 else "text";
    preset = parts[2].strip() if len(parts) > 2 else "";
    rest = ":".join(parts[3:]).strip() if len(parts) > 3 else "";
    found = FieldInfo(name=name, kind=kind, preset=preset);
    if kind == "choice" {
        for pair in rest.split(";") {
            halves = pair.split("=", 1);
            if len(halves) == 2 {
                found.choices.append((halves[0].strip(), halves[1].strip()));
            }
        }
    } else {
        found.help = rest;
    }
    return found;
}

"""What a field means when its class does not say (or is not known)."""
def common_field(key: str) -> FieldInfo {
    for words in COMMON_FIELDS.split("|") {
        if words.startswith(key + ":") {
            return read_field(words);
        }
    }
    return FieldInfo(name=key);
}

def classes -> dict[str, ClassInfo] {
    if len(CLASS_CACHE) > 0 {
        return CLASS_CACHE;
    }
    for line in CLASS_TABLE {
        parts = line.split("|");
        if len(parts) < 6 {
            continue;
        }
        known = ClassInfo(name=parts[0], solid=parts[1] == "brush", games=parts[2], help=parts[3]);
        for words in parts[4].split(",") {
            if not words.strip() {
                continue;
            }
            read = read_field(words);
            if not read.help and read.kind != "choice" {
                read.help = common_field(read.name).help;
            }
            known.fields.append(read);
        }
        if parts[5].strip() {
            known.flags = [name.strip() for name in parts[5].split(",")];
        }
        CLASS_CACHE[known.name] = known;
    }
    return CLASS_CACHE;
}

def class_info(name: str) -> ClassInfo | None {
    return classes().get(name);
}

"""How a field of a class is edited: the class's own word on it, else what
the field means everywhere. `spawnflags` is flags when the class names its
bits."""
def field_of(classname: str, key: str) -> FieldInfo {
    known = class_info(classname);
    if known is not None {
        if key == "spawnflags" and len(known.flags) > 0 {
            return FieldInfo(name=key, kind="flags", help="Its options");
        }
        said = known.field(key);
        if said is not None {
            return said;
        }
    }
    return common_field(key);
}

"""The classes a game has ("" for every game), by name."""
def class_names(game: str = "") -> list[str] {
    found: list[str] = [];
    for (name, known) in classes().items() {
        if not game or game == "passion" or game in known.games.split() {
            found.append(name);
        }
    }
    return sorted(found);
}

"""The family a class belongs to: the word before its first underscore."""
def class_family(name: str) -> str {
    return name.split("_")[0] if "_" in name else name;
}

"""Whether a bit of a spawnflags value is set (bit 0 is the value 1)."""
def flag_set(value: str, bit: int) -> bool {
    try {
        return (int(float(value)) >> bit) & 1 == 1;
    } except ValueError {
        return False;
    }
}

"""A spawnflags value with a bit set or cleared ("" when none are left)."""
def flag_put(value: str, bit: int, on: bool) -> str {
    number = 0;
    try {
        number = int(float(value)) if value.strip() else 0;
    } except ValueError {
        number = 0;
    }
    if on {
        number = number | (1 << bit);
    } else {
        number = number & ~(1 << bit);
    }
    return str(number);
}
