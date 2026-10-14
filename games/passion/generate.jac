"""Generate a seeded Passion expedition.

A seed picks a niche (how much the expedition loops, how vertical it is,
how densely it is fought over, how big it is) and an objective archetype.
Several candidates are built toward it, each in full:

1. a mission graph of beats and links, cyclic and proven free of softlocks
   (`mission.jac`);
2. spaces for its beats, each an archetype with height and structure of
   its own, placed in three dimensions and joined by corridors routed
   through the massing (`spaces.jac`, `arrange.jac`);
3. dressing: trim, pilasters, lamps, railings, frames (`dress.jac`), in the
   materials of districts read off the original levels (`kits.jac`);
4. its cast: start, objectives, doors and what opens them, foes and
   supplies (`cast.jac`).

The critic scores each by how near its measures come to the original
games' levels (`critic.jac` against `corpus.jac`), and the best becomes a
map: brushes and entities, compiled by the studio's compiler with buried
faces cut away, and lit by its light bake, kept on disk once baked."""
import os;
import math;
import struct;
import hashlib;
import from .random { Stream, stream_for, mix32 }
import from .mission { Expedition, Beat, Link, beats_of, links_of, build_mission }
import from .arrange { Estate, Corridor, arrange, estate_spaces, estate_corridors, CORRIDOR_HIGH }
import from .massing { Massing, floor_reached }
import from .spaces { Space }
import from .dress { Dressing, dress, frame_doorway, corridor_lamps }
import from .cast { Casting, cast }
import from .critic { critic_measures, critic_score }
import from .brushwork { map_items }
import from .kits { KITS, kit_of }
import from editor.formats.map { MapItem, MapFile, write_map }
import from editor.document.scene { Scene, scene_from_map }
import from editor.compile.live { compile_scene, LiveLevel, Materials, SwatchMaterials }
import from editor.compile.light { light_job }
import from editor.assets.materials { ArchiveMaterials }
import from engine.formats.bsp { Bsp }
import from engine.math.vec3 { Vec3 }
import from engine.world.level { Level, prepare_level }
import from engine.world.world { World }
import from engine.world.exits { LevelExit, HasExit }
import from engine.world.signals { HasSignal }
import from engine.physics.collision { CollisionMap }

glob VERSION: str = "v3";
glob CANDIDATES: int = 4;
glob ARCHETYPES: list[str] = ["keys", "relays", "guardian", "mixed"];
glob BINS: list[float] = [0.15, 0.5, 0.85];
glob LUXEL: float = 32.0;
glob BAKE_VERSION: bytes = b"passion-v3-bake-1";

"""What a seed made: its niche and archetype, how many candidates were tried
and why any were turned down, the winner's mission, estate, massing,
dressing and cast, its map items, its measures and the critic's score."""
node Survey {
    has seed: int = 0,
        niche: list[int] = [],
        archetype: str = "",
        briefing: str = "",
        score: float = 0.0,
        candidates: int = 0,
        valid: int = 0,
        rejections: dict[str, int] = {},
        # What turned candidates down, in a line each (for tools and tests).
        notes: list[str] = [],
        measures: dict[str, float] = {},
        start: list[float] = [],
        plan: Expedition | None = None,
        estate: Estate | None = None,
        mass: Massing | None = None,
        dressing: Dressing | None = None,
        casting: Casting | None = None,
        items: list[MapItem] = [];
}

edge Surveys: World --> Survey {}

"""The seed an expedition's name stands for: `v3-<seed>`, the seed from 1
to 2147483646 without leading zeros."""
def seed_from(name: str) -> int {
    if not name.startswith(VERSION + "-") {
        raise ValueError("Expected expedition " + VERSION + "-SEED");
    }
    seed = int(name[len(VERSION) + 1:]);
    if seed < 1 or seed > 2147483646 or name != VERSION + "-" + str(seed) {
        raise ValueError("Seed must be 1..2147483646");
    }
    return seed;
}

"""A seed's niche: loopiness, verticality, density and size, three bins
each; consecutive seeds land in unrelated niches."""
def niche_for(seed: int) -> list[int] {
    code = mix32(seed * 2654435761 % 4294967296) % 81;
    return [code % 3, (code // 3) % 3, (code // 9) % 3, (code // 27) % 3];
}

"""A candidate: what was made, or why it was turned down."""
obj Draft {
    has reason: str = "",
        detail: str = "",
        plan: Expedition | None = None,
        estate: Estate | None = None,
        mass: Massing | None = None,
        dressing: Dressing | None = None,
        casting: Casting | None = None,
        measures: dict[str, float] = {},
        score: float = 0.0;
}

"""Districts for a plan: two or three kits, a section each in turn."""
def choose_districts(plan: Expedition, stream: Stream) {
    order = stream.order(len(KITS));
    count = min(len(KITS), max(2, min(3, plan.sections + stream.below(2))));
    plan.districts = order[:count];
    beats = beats_of(plan);
    for beat in beats {
        beat.district = plan.districts[beat.section % count];
    }
    for beat in beats {
        if beat.optional {
            for other in [beat<-:Link:<-][?:Beat] {
                beat.district = other.district;
            }
        }
    }
}

"""The rooms whose stage cannot be walked to from the start's, the doors
all open (teleporters taken as ways from stage to stage); every room when
there is no start."""
def stages_missed(estate: Estate, mass: Massing, by_id: dict[int, Space]) -> list[Space] {
    start: Space | None = None;
    for space in by_id.values() {
        if space.role == "start" {
            start = space;
        }
    }
    rooms = [space for space in by_id.values() if space.role != "corridor" and space.stage];
    if start is None or not start.stage {
        return rooms;
    }
    links: list[list[int]] = [];
    for corridor in estate_corridors(estate) {
        if corridor.teleport and corridor.tail in by_id and corridor.head in by_id {
            tail = by_id[corridor.tail];
            head = by_id[corridor.head];
            links.append(tail.stage + head.stage);
            if corridor.mode != "valve" {
                links.append(head.stage + tail.stage);
            }
        }
    }
    reached = floor_reached(mass, start.stage[0], start.stage[1], start.stage[2], links);
    missed: list[Space] = [];
    for space in rooms {
        if ((space.stage[2] * mass.ny + space.stage[1]) * mass.nx + space.stage[0]) not in reached {
            missed.append(space);
        }
    }
    return missed;
}

"""Flood the pits of chasms: deep with the district's own liquid where
nothing needs the pit floor (no doorway opens there and the objective is
on the bridge), else a lift of water to wade through."""
def flood_pits(estate: Estate, by_id: dict[int, Space], dice: Stream) {
    used_levels: dict[int, list[int]] = {};
    for corridor in estate_corridors(estate) {
        if corridor.out_door is not None {
            used_levels.setdefault(corridor.tail, []).append(corridor.out_door.level);
        }
        if corridor.in_door is not None {
            used_levels.setdefault(corridor.head, []).append(corridor.in_door.level);
        }
        if corridor.teleport {
            used_levels.setdefault(corridor.tail, []).append(-1);
            used_levels.setdefault(corridor.head, []).append(-1);
        }
    }
    for space in by_id.values() {
        if space.kind != "chasm" or not dice.chance(0.8) {
            continue;
        }
        levels = used_levels.get(space.id, []);
        floor_used = space.z in levels or -1 in levels or (space.stage and space.stage[2] == space.z);
        space.deadly = not floor_used;
        space.flood = 3 if space.deadly else 1;
    }
}

"""Build one candidate in full."""
def build_draft(seed: int, index: int, niche: list[int], archetype: str) -> Draft {
    stream = stream_for(seed, "candidate").child("k", index);
    draft = Draft();
    loopiness = max(0.0, min(1.0, BINS[niche[0]] + stream.uniform(-0.15, 0.15)));
    verticality = max(0.2, min(1.0, BINS[niche[1]] + 0.15 + stream.uniform(-0.1, 0.1)));
    density = max(0.25, min(1.0, [0.35, 0.55, 0.8][niche[2]] + stream.uniform(-0.1, 0.1)));
    rooms = [12, 16, 21][niche[3]] + stream.between(-2, 2);
    sections = 1 + niche[3] // 2 + stream.below(2);
    objectives = 1 + stream.below(2);
    try {
        plan = build_mission(seed, stream.derive("mission"), archetype, objectives, sections, rooms, loopiness);
    } except (AssertionError, ValueError) {
        draft.reason = "mission";
        return draft;
    }
    plan.verticality = verticality;
    plan.density = density;
    plan.candidate = index;
    choose_districts(plan, stream.derive("districts"));
    draft.plan = plan;
    made = arrange(plan, stream.derive("layout"));
    estate: Estate = made[0];
    mass: Massing = made[1];
    draft.estate = estate;
    draft.mass = mass;
    if estate.failures {
        draft.reason = "layout";
        return draft;
    }
    links = len(links_of(plan));
    if estate.teleports > max(2, links // 4) {
        draft.reason = "routing";
        draft.detail = str(estate.teleports) + " of " + str(links) + " links by teleporter";
        return draft;
    }
    spaces = estate_spaces(estate);
    by_id: dict[int, Space] = {};
    for space in spaces {
        by_id[space.id] = space;
    }
    flood_pits(estate, by_id, stream.derive("pits"));
    missed = stages_missed(estate, mass, by_id);
    if missed {
        draft.reason = "unreachable";
        draft.detail = ", ".join([str(space.id) + " " + space.kind + " (" + space.role + ")" for space in missed]);
        return draft;
    }
    dressing = dress(mass, spaces, stream.derive("dress"));
    for corridor in estate_corridors(estate) {
        if corridor.air in by_id and corridor.blocks {
            corridor_lamps(dressing, by_id[corridor.air], corridor.blocks, CORRIDOR_HIGH);
        }
        if corridor.out_door is not None and corridor.tail in by_id {
            frame_doorway(dressing, by_id[corridor.tail], corridor.out_door, CORRIDOR_HIGH);
        }
        if corridor.in_door is not None and corridor.head in by_id and corridor.in_door.floored {
            frame_doorway(dressing, by_id[corridor.head], corridor.in_door, CORRIDOR_HIGH);
        }
    }
    draft.dressing = dressing;
    casting = cast(estate, mass, plan, stream.derive("cast"), density);
    draft.casting = casting;
    if not casting.start {
        draft.reason = "start";
        return draft;
    }
    if not casting.exit_low {
        draft.reason = "exit";
        return draft;
    }
    supplies = casting.placed_health + casting.placed_armor + casting.placed_shells;
    draft.measures = critic_measures(mass, dressing.lamps, casting.monsters, supplies);
    draft.score = critic_score(draft.measures);
    return draft;
}

"""The banner for an expedition: the districts its route crosses and what
it asks."""
def briefing_for(plan: Expedition) -> str {
    counts: dict[str, int] = {};
    for token in plan.objectives {
        kind = "keys" if token.startswith("key_") else ("relays" if token.startswith("relay:") else "guardians");
        counts[kind] = counts.get(kind, 0) + 1;
    }
    parts: list[str] = [];
    if counts.get("keys", 0) {
        parts.append("recover " + str(counts["keys"]) + (" keys" if counts["keys"] > 1 else " key"));
    }
    if counts.get("relays", 0) {
        parts.append("throw " + str(counts["relays"]) + (" relays" if counts["relays"] > 1 else " relay"));
    }
    if counts.get("guardians", 0) {
        parts.append("slay " + str(counts["guardians"]) + (" guardians" if counts["guardians"] > 1 else " guardian"));
    }
    route = " > ".join([kit_of(district).name for district in plan.districts]);
    return route + " | " + ", ".join(parts).capitalize() + ", reach extraction";
}

"""Survey a seed: build candidates toward its niche and keep the one the
critic likes best."""
def survey(seed: int, wanted: list[int] = []) -> Survey {
    niche = niche_for(seed) if not wanted else wanted;
    archetype = ARCHETYPES[mix32(seed + 977) % len(ARCHETYPES)];
    record = Survey(seed=seed, niche=niche, archetype=archetype);
    best: Draft | None = None;
    attempt = 0;
    while attempt < CANDIDATES * 3 and record.valid < CANDIDATES {
        draft = build_draft(seed, attempt, niche, archetype);
        attempt += 1;
        record.candidates += 1;
        if draft.reason {
            record.rejections[draft.reason] = record.rejections.get(draft.reason, 0) + 1;
            record.notes.append(draft.reason + ": " + draft.detail);
            continue;
        }
        record.valid += 1;
        if best is None or draft.score > best.score {
            best = draft;
        }
    }
    if best is None {
        raise ValueError("No expedition could be built for seed " + str(seed) + ": " + " | ".join(record.notes));
    }
    record.plan = best.plan;
    record.estate = best.estate;
    record.mass = best.mass;
    record.dressing = best.dressing;
    record.casting = best.casting;
    record.measures = best.measures;
    record.score = best.score;
    plan = best.plan;
    mass = best.mass;
    estate = best.estate;
    dressing = best.dressing;
    casting = best.casting;
    if plan is not None and mass is not None and estate is not None and dressing is not None and casting is not None {
        record.briefing = briefing_for(plan);
        record.start = casting.start;
        record.items = map_items(mass, estate_spaces(estate), dressing, casting.items, record.briefing);
    }
    return record;
}

"""Where an expedition's light is kept: a file named by the hash of its
map, the bake's settings and the bake's own version."""
def light_cache_path(directory: str, text: str) -> str {
    digest = hashlib.sha256(BAKE_VERSION);
    digest.update(str(LUXEL).encode());
    digest.update(text.encode());
    return directory + "/" + digest.hexdigest() + ".light";
}

"""A baked level's light as bytes: each face's lightmap place and layers,
the corners of what moves, the lightmaps and the grid for models."""
def pack_light(bsp: Bsp) -> bytes {
    data = bytearray(b"QPL3");
    data.extend(struct.pack("<IIII", len(bsp.faces), len(bsp.lighting), len(bsp.light_grid), bsp.light_channels));
    for face in bsp.faces {
        data.extend(struct.pack("<iHHB", face.light_offset, face.light_width, face.light_height, len(face.styles)));
        for style in face.styles {
            data.append(style & 255);
        }
        data.extend(struct.pack("<H", len(face.light_uv)));
        for value in face.light_uv {
            data.extend(struct.pack("<f", value));
        }
        data.extend(struct.pack("<H", len(face.colors)));
        for value in face.colors {
            data.append(max(0, min(255, value)));
        }
    }
    data.extend(bsp.lighting);
    data.extend(bsp.light_grid);
    return bytes(data);
}

"""Put light read back from bytes onto a freshly compiled level; False (and
the level untouched) when the bytes do not fit it."""
def unpack_light(data: bytes, bsp: Bsp) -> bool {
    if len(data) < 20 or data[:4] != b"QPL3" {
        return False;
    }
    head = struct.unpack("<IIII", data[4:20]);
    if int(head[0]) != len(bsp.faces) {
        return False;
    }
    offset = 20;
    faces: list[list[any]] = [];
    for index in range(len(bsp.faces)) {
        if offset + 9 > len(data) {
            return False;
        }
        fixed = struct.unpack("<iHHB", data[offset:offset + 9]);
        offset += 9;
        styles: list[int] = [];
        for step in range(int(fixed[3])) {
            styles.append(int(data[offset]));
            offset += 1;
        }
        count = int(struct.unpack("<H", data[offset:offset + 2])[0]);
        offset += 2;
        uv: list[float] = [];
        for step in range(count) {
            uv.append(float(struct.unpack("<f", data[offset:offset + 4])[0]));
            offset += 4;
        }
        count = int(struct.unpack("<H", data[offset:offset + 2])[0]);
        offset += 2;
        colors: list[int] = [int(value) for value in data[offset:offset + count]];
        offset += count;
        faces.append([int(fixed[0]), int(fixed[1]), int(fixed[2]), styles, uv, colors]);
    }
    if offset + int(head[1]) + int(head[2]) != len(data) {
        return False;
    }
    for (index, face) in enumerate(bsp.faces) {
        kept = faces[index];
        face.light_offset = kept[0];
        face.light_width = kept[1];
        face.light_height = kept[2];
        face.styles = kept[3];
        face.light_uv = kept[4];
        face.colors = kept[5];
    }
    bsp.lighting = data[offset:offset + int(head[1])];
    bsp.light_grid = data[offset + int(head[1]):offset + int(head[1]) + int(head[2])];
    bsp.light_channels = int(head[3]);
    return True;
}

"""Light a compiled expedition: from the cache when it holds this map's
light, else baked (and kept there)."""
def light_level(scene_text: str, made: LiveLevel, scene: Scene, cache_directory: str) -> bool {
    path = light_cache_path(cache_directory, scene_text) if cache_directory else "";
    if path and os.path.isfile(path) {
        data = b"";
        with open(path, "rb") as handle {
            data = handle.read();
        }
        if unpack_light(data, made.bsp) {
            return True;
        }
    }
    job = light_job(scene, made, LUXEL, 4000000);
    if job is None {
        return False;
    }
    while not job.step(200) {
        continue;
    }
    job.finish();
    if path {
        os.makedirs(cache_directory, exist_ok=True);
        partial = path + ".part";
        with open(partial, "wb") as handle {
            handle.write(pack_light(made.bsp));
        }
        os.replace(partial, path);
    }
    return True;
}

"""Generate the expedition a name stands for, as a level of `world`: its
materials read from the games under `directory`, its light kept under
`cache_directory` ("" to bake every time)."""
def generate(world: World, name: str, directory: str, cache_directory: str = "") -> Level {
    record = survey(seed_from(name));
    casting = record.casting;
    if not record.items or casting is None {
        raise ValueError("Expedition survey is incomplete");
    }
    text = write_map(record.items);
    scene = scene_from_map("passion", name, MapFile(items=record.items));
    materials: Materials = ArchiveMaterials(directory=directory) if directory else SwatchMaterials();
    made = compile_scene(scene, materials, True);
    if directory {
        light_level(text, made, scene, cache_directory);
    }
    bsp = made.bsp;
    level = Level(active=True, name=name, bsp=bsp);
    level.briefing = record.briefing;
    level.asset_manifest = "|".join([texture.name for texture in bsp.textures]) + "|"
        + "|".join([entity.fields.get("asset_game", "passion") + ":" + entity.fields.get("classname", "") for entity in bsp.entities]);
    prepare_level(world, level);
    world +>:Surveys:+> record;
    volume = CollisionMap();
    volume.add_box(
        Vec3(x=casting.exit_low[0], y=casting.exit_low[1], z=casting.exit_low[2]),
        Vec3(x=casting.exit_high[0], y=casting.exit_high[1], z=casting.exit_high[2]),
        Vec3(),
        Vec3(),
        Vec3()
    );
    extraction = LevelExit(destination="passion_complete", contact=True, volume=volume);
    world +>:HasExit:+> extraction;
    world +>:HasSignal:+> extraction.activation;
    world +>:HasSignal:+> level.completion;
    return level;
}

"""The survey a world's expedition was made from."""
def survey_of(world: World) -> Survey | None {
    found = [world->:Surveys:->][?:Survey];
    return found[0] if found else None;
}
