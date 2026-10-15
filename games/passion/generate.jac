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
faces cut away, and lit by its light bake.

A level is made a step at a time by a `Forge`: the game makes the next
level of a run while the current one is played, and the studio shows one
being made. Nothing is kept on disk.

A run is a seed: `v3-<seed>` is its first level and `v3-<seed>-<n>` its
level n, each seeded from the run's seed and its depth, a little harder
the deeper it lies."""
import time;
import from .random { Stream, stream_for, mix32 }
import from .mission { Expedition, Beat, Link, beats_of, links_of, build_mission }
import from .arrange { Estate, Corridor, Layout, arrange_steps, estate_spaces, estate_corridors, CORRIDOR_HIGH }
import from .massing { Massing, floor_reached, CELL, LIFT }
import from .spaces { Space }
import from .dress { Dressing, dress_steps, frame_doorway, corridor_lamps, box_brush }
import from .cast { Casting, cast }
import from .critic { critic_measures, critic_score }
import from .brushwork { map_item_steps }
import from .kits { KITS, kit_of, kit_water }
import from .themes { Theme, THEMES, theme_for, theme_named }
import from editor.formats.map { MapItem, MapFile }
import from editor.document.scene { Scene, scene_from_map }
import from editor.compile.live { Compiling, compile_steps, LiveLevel, Materials, SwatchMaterials }
import from editor.compile.light { light_job_steps, Lighting, LightJob }
import from editor.assets.materials { ArchiveMaterials }
import from engine.formats.bsp { Bsp }
import from engine.math.vec3 { Vec3 }
import from engine.world.level { Level, prepare_level }
import from engine.world.world { World }
import from engine.world.exits { LevelExit, HasExit }
import from engine.world.signals { HasSignal }
import from engine.physics.collision { CollisionMap }

glob VERSION: str = "v4";
glob CANDIDATES: int = 4;
glob ARCHETYPES: list[str] = ["keys", "relays", "guardian", "mixed"];
glob BINS: list[float] = [0.15, 0.5, 0.85];
glob LUXEL: float = 32.0;
# Faces lit between a bake's pauses.
glob BAKE_SLICE: int = 8;
glob DEPTH_LIMIT: int = 9999;

"""What a seed made: its niche and archetype, how many candidates were tried
and why any were turned down, the winner's mission, estate, massing,
dressing and cast, its map items, its measures and the critic's score."""
node Survey {
    has seed: int = 0,
        # The theme the level was made in, by key.
        theme: str = "",
        # The run it belongs to and how deep in it it lies.
        run: int = 0,
        depth: int = 1,
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

"""The run and depth an expedition's name stands for: `v3-<run>` is the
first level of the run seeded `run` (1 to 2147483646, without leading
zeros), `v3-<run>-<depth>` its level `depth` (2 to 9999)."""
def run_of(name: str) -> list[int] {
    if not name.startswith(VERSION + "-") {
        raise ValueError("Expected expedition " + VERSION + "-SEED");
    }
    words = name[len(VERSION) + 1:].split("-");
    if len(words) > 2 {
        raise ValueError("Expected expedition " + VERSION + "-SEED or " + VERSION + "-SEED-LEVEL");
    }
    run = int(words[0]);
    depth = int(words[1]) if len(words) == 2 else 1;
    if run < 1 or run > 2147483646 or depth < 1 or depth > DEPTH_LIMIT or name != level_name(run, depth) {
        raise ValueError("Seed must be 1..2147483646 and level 2.." + str(DEPTH_LIMIT));
    }
    return [run, depth];
}

"""The name of a run's level."""
def level_name(run: int, depth: int) -> str {
    return VERSION + "-" + str(run) + ("-" + str(depth) if depth > 1 else "");
}

"""The level after one in its run."""
def next_level(name: str) -> str {
    found = run_of(name);
    return level_name(found[0], min(DEPTH_LIMIT, found[1] + 1));
}

"""The seed a run's level is made from: the run's own for its first, and
for each after it a seed of its own drawn from the two."""
def level_seed(run: int, depth: int) -> int {
    if depth <= 1 {
        return run;
    }
    return mix32((run * 2654435761 + depth * 40503) % 4294967296) % 2147483646 + 1;
}

"""The seed an expedition's name stands for."""
def seed_from(name: str) -> int {
    found = run_of(name);
    return level_seed(found[0], found[1]);
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
        # The arrangement while it is made.
        layout: Layout | None = None,
        estate: Estate | None = None,
        mass: Massing | None = None,
        dressing: Dressing | None = None,
        casting: Casting | None = None,
        measures: dict[str, float] = {},
        score: float = 0.0;
}

"""Districts for a plan: two or three kits, a section each in turn."""
def choose_districts(plan: Expedition, stream: Stream, theme: Theme | None = None) {
    order = stream.order(len(KITS));
    # A theme's own districts first, in its order of liking (one shuffled to
    # the front now and then).
    if theme is not None and theme.kits {
        liked: list[int] = [];
        for name in theme.kits {
            for (index, kit) in enumerate(KITS) {
                if kit.name == name and index not in liked {
                    liked.append(index);
                }
            }
        }
        if len(liked) > 1 and stream.chance(0.5) {
            first = liked.pop(stream.below(len(liked)));
            liked.insert(0, first);
        }
        order = liked + [index for index in order if index not in liked];
    }
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
        # Up a lift, a flooded shaft or a jump pad (down is a fall through the
        # column, which the floors already know).
        if corridor.connector in ["lift", "water", "jumppad"] and len(corridor.column) == 2 {
            up = [corridor.column[0] - 1, corridor.column[1], corridor.high];
            if corridor.connector == "jumppad" and len(corridor.landing) == 2 {
                up = [corridor.landing[0], corridor.landing[1], corridor.high];
            }
            links.append([corridor.column[0], corridor.column[1], corridor.low] + up);
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
        if corridor.connector {
            upper = corridor.head if corridor.lower == corridor.tail else corridor.tail;
            used_levels.setdefault(corridor.lower, []).append(corridor.low);
            used_levels.setdefault(upper, []).append(corridor.high);
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
def build_draft(seed: int, index: int, niche: list[int], archetype: str, depth: int = 1, theme_key: str = "") -> Draft {
    made = Draft();
    theme = theme_named(theme_key);
    if theme is None {
        theme = theme_for(seed);
    }
    for label in draft_steps(seed, index, niche, archetype, depth, made, theme) {
        continue;
    }
    return made;
}

"""`build_draft` a step at a time, into `draft`. A level deeper in its run
is fought over more densely and has a room or two more."""
def draft_steps(seed: int, index: int, niche: list[int], archetype: str, depth: int, draft: Draft, theme: Theme) -> Iterator[str] {
    stream = stream_for(seed, "candidate").child("k", index);
    deeper = min(10, depth - 1);
    loopiness = max(0.0, min(1.0, BINS[niche[0]] + stream.uniform(-0.15, 0.15) + theme.loop));
    verticality = max(0.2, min(1.0, BINS[niche[1]] + 0.15 + stream.uniform(-0.1, 0.1) + theme.vertical));
    density = max(0.25, min(1.0, [0.35, 0.55, 0.8][niche[2]] + stream.uniform(-0.1, 0.1) + 0.04 * float(deeper) + theme.dense));
    rooms = max(8, [12, 16, 21][niche[3]] + stream.between(-2, 2) + deeper // 3 + theme.rooms);
    sections = 1 + niche[3] // 2 + stream.below(2);
    objectives = 1 + stream.below(2);
    try {
        plan = build_mission(seed, stream.derive("mission"), archetype, objectives, sections, rooms, loopiness);
    } except (AssertionError, ValueError) {
        draft.reason = "mission";
        return;
    }
    plan.verticality = verticality;
    plan.density = density;
    plan.candidate = index;
    plan.theme = theme.key;
    choose_districts(plan, stream.derive("districts"), theme);
    draft.plan = plan;
    yield "mission";
    layout = Layout();
    draft.layout = layout;
    yield from arrange_steps(plan, stream.derive("layout"), layout);
    estate = layout.estate;
    mass = layout.mass;
    if estate is None or mass is None {
        draft.reason = "layout";
        return;
    }
    draft.estate = estate;
    draft.mass = mass;
    if estate.failures {
        draft.reason = "layout";
        return;
    }
    links = len(links_of(plan));
    if estate.teleports > max(2, links // 4) {
        draft.reason = "routing";
        draft.detail = str(estate.teleports) + " of " + str(links) + " links by teleporter";
        return;
    }
    spaces = estate_spaces(estate);
    by_id: dict[int, Space] = {};
    for space in spaces {
        by_id[space.id] = space;
    }
    flood_pits(estate, by_id, stream.derive("pits"));
    missed = stages_missed(estate, mass, by_id);
    yield "reach";
    if missed {
        draft.reason = "unreachable";
        draft.detail = ", ".join([str(space.id) + " " + space.kind + " (" + space.role + ")" for space in missed]);
        return;
    }
    dressing = Dressing();
    yield from dress_steps(mass, spaces, stream.derive("dress"), dressing);
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
    # Flooded shafts: water from the lower room's floor to just under the
    # upper's, swum up or dropped down.
    for corridor in estate_corridors(estate) {
        if corridor.connector == "water" and len(corridor.column) == 2 and corridor.air in by_id {
            kit = kit_of(by_id[corridor.air].district);
            material = kit_water(kit);
            low = Vec3(x=float(corridor.column[0]) * CELL, y=float(corridor.column[1]) * CELL, z=float(corridor.low) * LIFT);
            high = Vec3(x=float(corridor.column[0] + 2) * CELL, y=float(corridor.column[1] + 2) * CELL, z=float(corridor.high) * LIFT - 6.0);
            shaft = box_brush(low, high, [material, material, material, material, material, material], 1.0);
            for side in shaft {
                side.contents = 32;
            }
            dressing.brushes.append(shaft);
        }
    }
    draft.dressing = dressing;
    yield "frames";
    casting = cast(estate, mass, plan, stream.derive("cast"), density);
    draft.casting = casting;
    yield "cast";
    if not casting.start {
        draft.reason = "start";
        return;
    }
    if not casting.exit_low {
        draft.reason = "exit";
        return;
    }
    supplies = casting.placed_health + casting.placed_armor + casting.placed_shells;
    draft.measures = critic_measures(mass, dressing.lamps, casting.monsters, supplies);
    draft.score = critic_score(draft.measures);
    yield "critic";
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
    theme = theme_named(plan.theme);
    if theme is not None {
        route = theme.title + ": " + route;
    }
    return route + " | " + ", ".join(parts).capitalize() + ", reach extraction";
}

"""Survey a seed: build candidates toward its niche and keep the one the
critic likes best."""
def survey(seed: int, wanted: list[int] = [], depth: int = 1, theme_key: str = "") -> Survey {
    forge = Forge();
    for label in survey_steps(seed, wanted, depth, forge, theme_key) {
        continue;
    }
    record = forge.survey;
    if record is None {
        raise ValueError("No expedition could be built for seed " + str(seed));
    }
    return record;
}

"""`survey` a step at a time: the survey, and the candidate being built,
are the forge's to show while it goes."""
def survey_steps(seed: int, wanted: list[int], depth: int, forge: Forge, theme_key: str = "") -> Iterator[str] {
    niche = niche_for(seed) if not wanted else wanted;
    theme = theme_named(theme_key);
    if theme is None {
        theme = theme_for(seed);
    }
    archetype = ARCHETYPES[mix32(seed + 977) % len(ARCHETYPES)];
    if theme.missions {
        archetype = theme.missions[mix32(seed + 1301) % len(theme.missions)];
    }
    record = Survey(seed=seed, niche=niche, archetype=archetype, depth=depth, theme=theme.key);
    forge.survey = record;
    best: Draft | None = None;
    attempt = 0;
    while attempt < CANDIDATES * 3 and record.valid < CANDIDATES {
        draft = Draft();
        forge.draft = draft;
        yield from draft_steps(seed, attempt, niche, archetype, depth, draft, theme);
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
    forge.draft = best;
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
    yield "chosen";
    if plan is not None and mass is not None and estate is not None and dressing is not None and casting is not None {
        record.briefing = briefing_for(plan);
        record.start = casting.start;
        items: list[MapItem] = [];
        yield from map_item_steps(mass, estate_spaces(estate), dressing, casting.items, record.briefing, items);
        record.items = items;
    }
    yield "brushwork";
}

"""A level being made a step at a time, so that one is made while another
is played, or watched as it is made: what it has made so far (the survey
and the candidate being built, then the scene, its compile and its light),
and how far it has got."""
obj Forge {
    has name: str = "",
        directory: str = "",
        # The materials to build with: one set kept through a run reads the
        # games' archives once and each texture once.
        materials: Materials | None = None,
        # The stage it is at (survey, map, compile, bake, ready) and the
        # step it last took within it.
        stage: str = "",
        step: str = "",
        survey: Survey | None = None,
        draft: Draft | None = None,
        scene: Scene | None = None,
        compiling: Compiling | None = None,
        made: LiveLevel | None = None,
        job: LightJob | None = None,
        steps: Iterator[str] | None = None,
        finished: bool = False,
        failure: str = "",
        # How it went: the steps taken, the seconds they took, and the
        # longest of them and where it was.
        taken: int = 0,
        spent: float = 0.0,
        longest: float = 0.0,
        longest_step: str = "";

    """Go on for up to `budget` seconds (a step at least). True once the
    level is made, or could not be (`failure` says why)."""
    def advance(budget: float) -> bool {
        if self.finished {
            return True;
        }
        if self.steps is None {
            self.steps = forge_steps(self);
        }
        steps = self.steps;
        if steps is None {
            return True;
        }
        began = time.time();
        while True {
            before = time.time();
            label = "";
            try {
                label = next(steps, "");
            } except Exception as error {
                self.failure = str(error) if str(error) else "The expedition could not be made";
            }
            took = time.time() - before;
            self.taken += 1;
            self.spent += took;
            if took > self.longest {
                self.longest = took;
                self.longest_step = self.stage + "/" + label;
            }
            if not label {
                self.finished = True;
                self.steps = None;
                return True;
            }
            self.step = label;
            if time.time() - began >= budget {
                return False;
            }
        }
        return False;
    }

    """Make the rest at once."""
    def complete {
        while not self.advance(60.0) {
            continue;
        }
    }

    """How far it has got, from 0 to 1: the survey's candidates, then the
    compile's brushes, then the bake."""
    def share -> float {
        if self.finished {
            return 1.0;
        }
        if self.stage == "survey" {
            record = self.survey;
            tried = float(record.candidates) if record is not None else 0.0;
            return 0.35 * min(1.0, tried / float(CANDIDATES + 1));
        }
        if self.stage == "map" {
            return 0.35;
        }
        compiling = self.compiling;
        if self.stage == "compile" and compiling is not None {
            return 0.35 + 0.1 * float(compiling.done) / float(max(1, compiling.total));
        }
        job = self.job;
        if self.stage == "bake" and job is not None {
            return 0.45 + 0.55 * job.share();
        }
        return 0.45 if self.stage == "bake" else 0.0;
    }
}

"""The steps of a forge: the survey, the map, its compile and its bake."""
def forge_steps(forge: Forge) -> Iterator[str] {
    found = run_of(forge.name);
    forge.stage = "survey";
    yield from survey_steps(level_seed(found[0], found[1]), [], found[1], forge);
    record = forge.survey;
    if record is None or not record.items or record.casting is None {
        raise ValueError("Expedition survey is incomplete");
    }
    record.run = found[0];
    forge.stage = "map";
    scene = scene_from_map("passion", forge.name, MapFile(items=record.items));
    forge.scene = scene;
    yield "map";
    materials = forge.materials;
    if materials is None {
        materials = ArchiveMaterials(directory=forge.directory) if forge.directory else SwatchMaterials();
        forge.materials = materials;
    }
    forge.stage = "compile";
    compiling = Compiling();
    forge.compiling = compiling;
    yield from compile_steps(scene, materials, True, compiling);
    compiler = compiling.compiler;
    if compiler is None {
        raise ValueError("The expedition was not compiled");
    }
    made = compiler.result;
    forge.made = made;
    if forge.directory {
        forge.stage = "bake";
        held = Lighting();
        yield from light_job_steps(scene, made, LUXEL, 4000000, held);
        job = held.job;
        if job is not None {
            forge.job = job;
            yield from job.work_steps(BAKE_SLICE);
            yield from job.finish_steps();
            yield "lit";
        }
    }
    forge.stage = "ready";
    yield "ready";
}

"""Generate the expedition a name stands for, as a level of `world`: from
`forged` when that forge has made this level, else made now, its materials
read from the games under `directory`."""
def generate(world: World, name: str, directory: str, forged: Forge | None = None) -> Level {
    forge = forged if forged is not None and forged.name == name and forged.finished and not forged.failure else None;
    if forge is None {
        forge = Forge(name=name, directory=directory);
        forge.complete();
    }
    return open_forged(world, forge);
}

"""Open what a forge made as a level of `world`: its compiled level, the
survey kept beside it, and the way out."""
def open_forged(world: World, forge: Forge) -> Level {
    if forge.failure {
        raise ValueError(forge.failure);
    }
    record = forge.survey;
    made = forge.made;
    if record is None or made is None {
        raise ValueError("Expedition " + forge.name + " is not made yet");
    }
    casting = record.casting;
    if casting is None or not casting.exit_low {
        raise ValueError("Expedition survey is incomplete");
    }
    bsp = made.bsp;
    level = Level(active=True, name=forge.name, bsp=bsp);
    level.briefing = record.briefing;
    level.asset_manifest = "|".join([texture.name for texture in bsp.textures]) + "|"
        + "|".join([entity.fields.get("asset_game", "passion") + ":" + entity.fields.get("classname", "") for entity in bsp.entities]);
    prepare_level(world, level);
    # A level begun again after a death reopens its forge: its survey leaves
    # the world it was in (torn down when the new one opens) first.
    for held in [record<-:Surveys:<-][?:World] {
        held del --> record;
    }
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
