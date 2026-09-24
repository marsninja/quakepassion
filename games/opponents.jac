"""Campaign rosters and local arena training bots populated from map entities."""
import math;
import from .enemies { enemy_rule }
import from .gibs { gib_rule, link_gibs }
import from .patrols { patrol_speed }
import from engine.world.trains { TrackPoint, HasTrack }
import from engine.world.patrols { Patrols, Holds }
import from engine.world.opponent_rule { OpponentRule }
import from .arena_character { character_rig, CharacterRig, character_body, weapon_kits, Q3_HELD_WEAPONS }
import from .arenas { ArenaInfo, BotInfo, load_arenas, load_bots, find_arena, find_bot }
import from engine.world.arena { ArenaMatch, HasMatch, Competes, SpawnPoint, HasSpawn, ChooseSpawn }
import from engine.formats.bsp { MapEntity }
import from engine.world.world { World, move_to_area }
import from engine.world.level { Level, spawn_player }
import from engine.world.combat { Opponent, HasOpponent, ensure_profiles, arm_bot }
import from engine.world.bot_tactics { Q3_FIRE_SOUNDS, Arms, hold_weapon }
import from engine.world.models { WeaponKit, PlayerRig }
import from engine.world.player_rig { rig_sound_paths }

import from engine.world.bot_character { bot_skill, bot_handicap }
import from engine.world.turrets { link_turret_drivers }
import from engine.world.podium { Podium, HasPodium, Figure, Poses, Portrays, Wields, podium_figure }
import from engine.world.reflection { HasBody, Carries, player_body }
import from .botfiles { load_bot_character }
import from engine.world.finale { TeleportTrain, HasTeleportTrain }
import from engine.world.speakers { Speaker, HasSpeaker }
import from engine.world.signals { Signal, HasSignal }
import from engine.world.models { ModelResource, HasModelResource, UsesModel, HasVisual, attach_model }
import from engine.formats.animated { AnimationFrame }
import from engine.assets.catalog { AssetCatalog }
import from engine.assets.library { AssetLibrary }
import from engine.formats.aas { parse_aas }
import from engine.world.bot_routes { build_navmesh }
import from engine.math.vec3 { Vec3 }

def frame_indices(
    frames: list[AnimationFrame], names: list[str], path: str, label: str
) -> list[int] {
    result: list[int] = [];
    for name in names {
        found = -1;
        for i in range(len(frames)) {
            if frames[i].name == name {
                found = i;
                break;
            }
        }
        if found < 0 {
            raise ValueError("Missing " + label + " frame: " + path + ":" + name);
        }
        result.append(found);
    }
    return result;
}

# One positional speaker per distinct sound file an opponent can request.
def register_speaker(world: World, enemy: Opponent, path: str) -> Speaker | None {
    if not path {
        return None;
    }
    for i in range(len(enemy.speaker_paths)) {
        if enemy.speaker_paths[i] == path {
            return enemy.speakers[i];
        }
    }
    speaker = Speaker(path=path, origin=enemy.pos.add(Vec3()));
    world +>:HasSpeaker:+> speaker;
    enemy.speakers.append(speaker);
    enemy.speaker_paths.append(path);
    return speaker;
}

# The teleport train is a point entity with the original spiked ball model.
def populate_finale(world: World, level: Level, directory: str) -> int {
    trains = [world->:HasTeleportTrain:->][?:TeleportTrain];
    if not trains {
        return 0;
    }
    catalog = AssetCatalog(game=level.bsp.game, directory=directory);
    try {
        loaded = catalog.model("q1:progs/teleport.mdl");
        resource = ModelResource(
            name="q1:progs/teleport.mdl", model=loaded.model, skins=loaded.skins
        );
        world +>:HasModelResource:+> resource;
        for train in trains {
            train.visual = attach_model(train, resource);
            move_to_area(train, level.areas[level.locate(train.pos)]);
        }
    } finally {
        catalog.close();
    }
    return len(trains);
}

"""Q3 spawn points become graph nodes; the arena's roster and frag limit come
from scripts/arenas.txt, with a three-bot skirmish for maps outside the ladder."""
def prepare_arena(
    world: World, level: Level, library: AssetLibrary, roster: list[BotInfo]
) -> ArenaMatch {
    for entity in level.bsp.entities {
        fields = entity.fields;
        if fields.get("classname", "") != "info_player_deathmatch" {
            continue;
        }
        parts = fields.get("origin", "0 0 0").split();
        if len(parts) != 3 {
            raise ValueError("Invalid spawn origin");
        }
        world +>:HasSpawn:+> SpawnPoint(
            pos=Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2])),
            yaw=float(fields.get("angle", "0")) * math.pi / 180.0
        );
    }
    arena = find_arena(load_arenas(library), level.name);
    bots = load_bots(library);
    names = arena.bots if arena is not None and arena.bots else ["sarge", "grunt", "major"];
    for name in names {
        roster.append(find_bot(bots, name));
    }
    # The bots' own navigation data (botlib AAS) drives map-wide routing.
    aas_path = "maps/" + level.name + ".aas";
    if library.exists(aas_path) {
        build_navmesh(world, parse_aas(library.read(aas_path)));
    }
    contest = ArenaMatch(
        fraglimit=arena.fraglimit if arena is not None else 20,
        title=arena.longname if arena is not None else level.name,
        warmup=4.0
    );
    world +>:HasMatch:+> contest;
    return contest;
}

def arena_entities(world: World, roster: list[BotInfo], player_start: Vec3) -> list[MapEntity] {
    placed: list[Vec3] = [player_start];
    result: list[MapEntity] = [];
    for index in range(len(roster)) {
        choice = world spawn ChooseSpawn(avoid=placed, seed=1 + index * 7919);
        spot = choice.pick();
        if spot is None {
            break;
        }
        placed.append(spot.pos);
        result.append(
            MapEntity(
                fields={
                    "classname": "arena_bot",
                    "origin": str(spot.pos.x) + " " + str(spot.pos.y) + " " + str(spot.pos.z),
                    "angle": str(spot.yaw * 180.0 / math.pi),
                    "bot": str(index)
                }
            )
        );
    }
    return result;
}

def populate_opponents(world: World, level: Level, directory: str) -> int {
    catalog = AssetCatalog(game=level.bsp.game, directory=directory);
    resources: dict[str, ModelResource] = {};
    rigs: dict[str, CharacterRig] = {};
    kits: dict[str, WeaponKit] = {};
    # Path corners and combat points by name; authored duplicates keep the first.
    corners: dict[str, TrackPoint] = {};
    for corner in [world->:HasTrack:->][?:TrackPoint] {
        if corner.name not in corners {
            corners[corner.name] = corner;
        }
    }
    count = 0;
    player_start = spawn_player(level).pos;
    entities = level.bsp.entities;
    roster: list[BotInfo] = [];
    contest: ArenaMatch | None = None;
    try {
        if level.bsp.game == "q3" {
            contest = prepare_arena(world, level, catalog.source("q3"), roster);
            entities = entities + arena_entities(world, roster, player_start);
        }
        for entity_index in range(len(entities)) {
            entity = entities[entity_index];
            fields = entity.fields;
            if level.bsp.game == "q2"
                and fields.get("classname", "") == "target_spawner"
                and fields.get("target", "").startswith("monster_") {
                # Spawned monsters wait, like TRIGGER_SPAWN ones, for the spawner.
                fields = {
                    "classname": fields["target"],
                    "origin": fields.get("origin", "0 0 0"),
                    "angle": fields.get("angle", "0"),
                    "spawnflags": "2"
                };
            }
            source = fields.get("asset_game", level.bsp.game);
            kind = fields.get("classname", "");
            flags = int(fields.get("spawnflags", "0"));
            path = "";
            arena = source == "q3";
            # Arena bots run at Q3's g_speed of 320 like any player.
            rule = OpponentRule(damage=6, speed=320.0);
            bot = BotInfo(name="Sarge");
            if arena {
                if kind == "arena_bot" {
                    bot = roster[int(fields.get("bot", "0"))];
                } elif level.bsp.game == "q3" or kind != "info_player_deathmatch" {
                    # Passion encounters still place Q3 characters at these spots.
                    continue;
                }
                path = "models/players/" + bot.model;
            } else {
                definition = enemy_rule(source, kind, flags);
                if definition is None {
                    continue;
                }
                rule = definition;
                path = rule.model;
            }
            parts = fields.get("origin", "0 0 0").split();
            if len(parts) != 3 {
                raise ValueError("Invalid opponent origin");
            }
            origin = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            # Q1 barrels are brush models spanning 0..32 from their origin.
            corner = source == "q1" and kind in ["misc_explobox", "misc_explobox2"];
            if corner {
                origin = origin.add(Vec3(x=16.0, y=16.0));
            }
            # Opponent movement uses the same eye/body contract as the player.
            position = origin.add(Vec3(z=level.collision.eye_height));
            handicap = bot_handicap(bot_skill(level.skill));
            if arena and position.sub(player_start).length() < 80.0 {
                continue;
            }
            enemy = Opponent(
                pos=position,
                eye_height=level.collision.eye_height,
                dormant=rule.script == "chthon"
                    or (
                        source == "q2"
                        and flags & 2 != 0
                        and not rule.decoration
                    ),
                home=position,
                shot_random=1 + count * 7919,
                arena=level.bsp.game == "q3",
                rule=rule,
                walk_speed=rule.speed,
                # G_AddBot's handicap is the bot's maximum health.
                health=handicap + 25 if kind == "arena_bot" else rule.health,
                max_health=handicap if kind == "arena_bot" else rule.health,
                decision_wait=float(count % 12) / 120.0,
                support_wait=float(count % 6) / 120.0,
                yaw=float(fields.get("angle", "0")) * math.pi / 180.0,
                game=source,
                skill=level.skill,
                ambush=source in ["q1", "q2"] and flags & 1 != 0 and kind != "arena_bot",
                kind=kind
            );
            ensure_profiles(enemy);
            if rule.attack_sound {
                enemy.attack_speaker = register_speaker(world, enemy, rule.attack_sound);
            }
            if rule.melee_sound {
                enemy.melee_speaker = register_speaker(world, enemy, rule.melee_sound);
            }
            for profile in enemy.profiles {
                register_speaker(world, enemy, profile.sound);
                register_speaker(world, enemy, profile.extra_sound);
            }
            register_speaker(world, enemy, rule.sight_sound);
            for pain_sound in rule.pain_sounds {
                register_speaker(world, enemy, pain_sound);
            }
            register_speaker(world, enemy, rule.death_sound);
            for signal in [world->:HasSignal:->][?:Signal] {
                if entity_index in signal.entities {
                    enemy.activation = signal;
                }
            }
            if path and arena {
                # CG_Player: a Q3 body is three tagged parts on their own
                # animations, holding one of the shared weapon kits.
                key = source + ":" + path + ":" + bot.skin;
                library = catalog.source(source);
                if key not in rigs {
                    rigs[key] = character_rig(library, bot.model, bot.skin);
                }
                kits = weapon_kits(world, library, resources, kits);
                body = character_body(world, resources, rigs[key], key, count + 1);
                body.offset = Vec3(z=-level.collision.eye_height);
                body.voice = player_voice(library, bot.model);
                body.footsteps = rigs[key].footsteps;
                enemy.visual = body;
                enemy +>:HasVisual:+> body;
                for (weapon, kit) in kits.items() {
                    enemy +>:Arms(key=weapon):+> kit;
                }
                hold_weapon(enemy, "machinegun");
                for sound in rig_sound_paths(body) {
                    if library.exists(sound) {
                        register_speaker(world, enemy, sound);
                    }
                }
                enemy.modeled = True;
            } elif path {
                key = source + ":" + path + ":" + str(rule.skin);
                if key not in resources {
                    library = catalog.source(source);
                    loaded = library.model(path, skin=rule.skin);
                    resource = ModelResource(
                        name=key, model=loaded.model, skins=loaded.skins
                    );
                    resources[key] = resource;
                    world +>:HasModelResource:+> resource;
                }
                enemy.visual = attach_model(enemy, resources[key]);
                enemy.visual.offset = Vec3(
                    x=-16.0 if corner else 0.0,
                    y=-16.0 if corner else 0.0,
                    z=-level.collision.eye_height
                );
                frames = resources[key].model.surfaces[0].frames;
                pain_family = "";
                death_family = "";
                pain_number = -1;
                death_number = -1;
                walk_family = "";
                walk_number = -1;
                for i in range(len(frames)) {
                    frame_name = frames[i].name;
                    family = frame_name.rstrip("0123456789");
                    suffix = frame_name[len(family):];
                    number = int(suffix) if suffix else 0;
                    if frame_name.startswith("pain") {
                        if not pain_family {
                            pain_family = family;
                            pain_number = number - 1;
                        }
                        if family == pain_family and number == pain_number + 1 {
                            pain_number = number;
                            enemy.pain_animation.append(i);
                        }
                    }
                    if frame_name.startswith("death") {
                        if not death_family {
                            death_family = family;
                            death_number = number - 1;
                        }
                        if family == death_family and number == death_number + 1 {
                            death_number = number;
                            enemy.death_animation.append(i);
                        }
                    }
                    if frame_name.startswith("run") {
                        enemy.animation.append(i);
                    }
                    if frame_name.startswith("walk") or frame_name.startswith("prowl_") {
                        if not walk_family {
                            walk_family = family;
                            walk_number = number - 1;
                        }
                        if family == walk_family and number == walk_number + 1 {
                            walk_number = number;
                            enemy.walk_animation.append(i);
                        }
                    }
                    if frame_name.startswith("stand") {
                        enemy.idle_animation.append(i);
                    }
                    if frame_name.startswith("attack")
                        or frame_name.startswith("attak")
                        or frame_name.startswith("shoot") {
                        enemy.attack_animation.append(i);
                    }
                }
                if rule.pain_frames {
                    enemy.pain_animation = frame_indices(
                        frames, rule.pain_frames, path, "pain"
                    );
                }
                for variant in rule.pain_variants {
                    enemy.pain_animations.append(
                        frame_indices(frames, variant, path, "pain")
                    );
                }
                if rule.knockdown_frames {
                    enemy.knockdown_animation = frame_indices(
                        frames, rule.knockdown_frames, path, "knockdown"
                    );
                }
                if rule.duck_frames {
                    enemy.duck_animation = frame_indices(
                        frames, rule.duck_frames, path, "duck"
                    );
                }
                if rule.run_frames {
                    enemy.animation = frame_indices(frames, rule.run_frames, path, "run");
                }
                if rule.idle_frames {
                    enemy.idle_animation = frame_indices(
                        frames, rule.idle_frames, path, "idle"
                    );
                }
                if rule.death_frames {
                    enemy.death_animation = frame_indices(
                        frames, rule.death_frames, path, "death"
                    );
                }
                if rule.attack_frames {
                    enemy.attack_animation = frame_indices(
                        frames, rule.attack_frames, path, "attack"
                    );
                }
                enemy.melee_animation = frame_indices(
                    frames, rule.melee_frames, path, "melee"
                );
                enemy.alternate_melee_animation = frame_indices(
                    frames, rule.alternate_melee_frames, path, "alternate melee"
                );
                for profile in enemy.profiles {
                    enemy.profile_animations.append(
                        frame_indices(frames, profile.frames, path, profile.name)
                    );
                }
                if not enemy.animation {
                    enemy.animation = enemy.idle_animation;
                }
                enemy.modeled = True;
            }
            if arena {
                # The bot's own botlib character, at the Q3 skill for this level.
                enemy.character = load_bot_character(
                    catalog.source("q3"), bot.aifile, bot_skill(level.skill)
                );
                arm_bot(enemy);
                for path in Q3_FIRE_SOUNDS {
                    register_speaker(world, enemy, path);
                }
            }
            if not arena {
                enemy.patrol_speed = patrol_speed(source, kind);
                walk_to = fields.get("target", "");
                if walk_to in corners and not corners[walk_to].combat {
                    enemy +>:Patrols:+> corners[walk_to];
                }
                hold_at = fields.get("combattarget", "");
                if source == "q2" and hold_at in corners and corners[hold_at].combat {
                    enemy +>:Holds:+> corners[hold_at];
                }
            }
            gibs = gib_rule(source, kind);
            if gibs is not None
                and link_gibs(world, enemy, gibs, catalog.source(source), source, resources) {
                enemy.gib_rule = gibs;
                register_speaker(world, enemy, gibs.sound);
            }
            enemy.visual.visible = not enemy.dormant;
            move_to_area(enemy, level.areas[level.locate(position)]);
            world +>:HasOpponent:+> enemy;
            if arena and contest is not None {
                contest +>:Competes:name=bot.name:+> enemy;
            }
            count += 1;
            if rule.successor {
                follower = enemy_rule(source, rule.successor, 0);
                if follower is None {
                    raise ValueError("Unknown successor: " + rule.successor);
                }
                heir = Opponent(
                    pos=position,
                    eye_height=level.collision.eye_height,
                    dormant=True,
                    home=position,
                    shot_random=1 + count * 7919,
                    rule=follower,
                    walk_speed=follower.speed,
                    health=follower.health,
                    max_health=follower.health,
                    yaw=enemy.yaw
                );
                ensure_profiles(heir);
                for profile in heir.profiles {
                    register_speaker(world, heir, profile.sound);
                    register_speaker(world, heir, profile.extra_sound);
                }
                register_speaker(world, heir, follower.sight_sound);
                for pain_sound in follower.pain_sounds {
                    register_speaker(world, heir, pain_sound);
                }
                register_speaker(world, heir, follower.death_sound);
                # The map's targets belong to the last form of the boss.
                heir.activation = enemy.activation;
                enemy.activation = Signal();
                enemy.successor = heir;
                heir_key = source + ":" + follower.model + ":" + str(follower.skin);
                if heir_key not in resources {
                    heir_loaded = catalog.source(source).model(
                        follower.model, skin=follower.skin
                    );
                    heir_resource = ModelResource(
                        name=heir_key, model=heir_loaded.model, skins=heir_loaded.skins
                    );
                    resources[heir_key] = heir_resource;
                    world +>:HasModelResource:+> heir_resource;
                }
                heir.visual = attach_model(heir, resources[heir_key]);
                heir.visual.offset = Vec3(z=-level.collision.eye_height);
                heir_frames = resources[heir_key].model.surfaces[0].frames;
                heir.idle_animation = frame_indices(
                    heir_frames, follower.idle_frames, follower.model, "idle"
                );
                heir.animation = frame_indices(
                    heir_frames, follower.run_frames, follower.model, "run"
                );
                heir.death_animation = frame_indices(
                    heir_frames, follower.death_frames, follower.model, "death"
                );
                heir.pain_animation = frame_indices(
                    heir_frames, follower.pain_frames, follower.model, "pain"
                );
                for variant in follower.pain_variants {
                    heir.pain_animations.append(
                        frame_indices(heir_frames, variant, follower.model, "pain")
                    );
                }
                for profile in heir.profiles {
                    heir.profile_animations.append(
                        frame_indices(heir_frames, profile.frames, follower.model, profile.name)
                    );
                }
                heir.modeled = True;
                heir.visual.visible = False;
                move_to_area(heir, level.areas[level.locate(position)]);
                world +>:HasOpponent:+> heir;
                count += 1;
            }
        }
        # Q3 single player: the podium and every competitor's stand-in.
        if contest is not None {
            prepare_podium(world, catalog.source("q3"), contest, resources, rigs, kits);
        }
    } finally {
        catalog.close();
    }
    # Q2 turret drivers ride their breach and fire its rockets.
    for driver in link_turret_drivers(world) {
        register_speaker(world, driver, "sound/weapons/rocklf1a.wav");
    }
    return count;
}

"""g_arenas.c SpawnPodium and SpawnModelOnVictoryPad need the podium model and a
body for every competitor. Bots' stand-ins share their bodies; the human's is
Sarge, with every weapon it might be holding, and the same body follows the
player to be seen in mirrors."""
def prepare_podium(
    world: World,
    library: AssetLibrary,
    contest: ArenaMatch,
    resources: dict[str, ModelResource],
    rigs: dict[str, CharacterRig],
    kits: dict[str, WeaponKit]
) {
    podium_path = "models/mapobjects/podium/podium4.md3";
    if not library.exists(podium_path) {
        return;
    }
    loaded = library.model(podium_path);
    stage = ModelResource(name="q3:" + podium_path, model=loaded.model, skins=loaded.skins);
    world +>:HasModelResource:+> stage;
    podium = Podium();
    podium.visual = attach_model(podium, stage);
    podium.visual.visible = False;
    world +>:HasPodium:+> podium;
    entries = [edge contest->:Competes:->];
    actors = [contest->:Competes:->];
    for i in range(min(len(entries), len(actors))) {
        bot = actors[i];
        if not isinstance(bot, Opponent) or not isinstance(bot.visual, PlayerRig) {
            continue;
        }
        key = bot.visual.character;
        if key not in rigs {
            continue;
        }
        # Keys are "q3:models/players/<model>:<skin>".
        model = key.split(":")[1].split("/")[-1];
        figure = podium_figure(character_body(world, resources, rigs[key], key), "sound/player/" + model + "/taunt.wav");
        figure +>:Portrays:+> bot;
        podium +>:Poses(name=entries[i].name):+> figure;
    }
    key = "q3:models/players/sarge:default";
    if key not in rigs {
        rigs[key] = character_rig(library, "sarge", "default");
    }
    kits = weapon_kits(world, library, resources, kits);
    human = podium_figure(character_body(world, resources, rigs[key], key), "sound/player/sarge/taunt.wav");
    # The player's own body, seen only in mirrors and portals.
    reflection = player_body(character_body(world, resources, rigs[key], key));
    world +>:HasBody:+> reflection;
    for (weapon, kit) in kits.items() {
        human +>:Wields(key=weapon):+> kit;
        reflection +>:Carries(key=weapon):+> kit;
    }
    podium +>:Poses(human=True):+> human;
}

"""The directory of a model's player sounds; models without their own use
Sarge's, as CG_LoadClientInfo falls back to the default model."""
def player_voice(library: AssetLibrary, model: str) -> str {
    voice = "sound/player/" + model + "/";
    return voice if library.exists(voice + "pain100_1.wav") else "sound/player/sarge/";
}
