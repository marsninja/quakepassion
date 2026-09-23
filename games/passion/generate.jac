"""Generate a seeded Passion expedition by quality-diversity candidate search.

A seed selects a niche in a descriptor space (loopiness x verticality x combat
density x size) and an objective archetype. Several complete candidates are
generated toward that niche: mission grammar, spatial embedding, height
solving, interiors, corridors and the encounter director. Each candidate is
re-proven against its own geometry by the column playtester, measured, and
scored on quality and distance to the niche. The winner is compiled, given
cluster visibility, checked physically and baked.
"""
import math;
import from .random { Stream, stream_for, mix32 }
import from .mission { Expedition, Beat, Link, beats_of, links_of, build_mission }
import from .layout {
    Site,
    Room,
    embed,
    rooms_of,
    passages_of,
    target_heights,
    solve_heights,
    CELL
}
import from .blueprint {
    Blueprint,
    new_blueprint,
    carve_rooms,
    carve_corridors,
    carve_windows
}
import from .director { direct, Economy }
import from .compile { compile_blueprint, Compiled }
import from .visibility { cluster_visibility, visible_pairs }
import from .playtest { progress, Proof }
import from .lighting { bake }
import from .materials { DISTRICTS, DISTRICT_NAMES }
import from engine.formats.bsp { Texture }
import from engine.math.vec3 { Vec3 }
import from engine.world.level { Level, prepare_level }
import from engine.world.world { World }
import from engine.world.exits { LevelExit, HasExit }
import from engine.world.signals { HasSignal }
import from engine.physics.collision { CollisionMap }

glob VERSION: str = "v2";
glob CANDIDATES: int = 6;
glob ARCHETYPES: list[str] = ["keys", "relays", "guardian", "mixed"];
glob BINS: list[float] = [0.15, 0.5, 0.85];

node Survey {
    has seed: int = 0,
        niche: list[int] = [],
        target: list[float] = [],
        measured: list[float] = [],
        quality: float = 0.0,
        score: float = 0.0,
        candidates: int = 0,
        valid: int = 0,
        briefing: str = "",
        archetype: str = "",
        start: list[float] = [],
        plan: Expedition | None = None,
        site: Site | None = None,
        bp: Blueprint | None = None,
        economy: Economy | None = None,
        visible_pairs: int = 0,
        rejections: dict[str, int] = {};
}

edge Surveys: World --> Survey {}

def seed_from(name: str) -> int {
    if not name.startswith(VERSION + "-") {
        raise ValueError("Expected expedition " + VERSION + "-SEED");
    }
    seed = int(name[3:]);
    if seed < 1 or seed > 2147483646 or name != VERSION + "-" + str(seed) {
        raise ValueError("Seed must be 1..2147483646");
    }
    return seed;
}

# Niche coordinates: loopiness, verticality, density and size in three bins
# each. Consecutive seeds land in unrelated niches.
def niche_for(seed: int) -> list[int] {
    code = mix32(seed * 2654435761 % 4294967296) % 81;
    return [code % 3, (code // 3) % 3, (code // 9) % 3, (code // 27) % 3];
}

obj Candidate {
    has plan: Expedition,
        site: Site,
        bp: Blueprint,
        economy: Economy,
        proof: Proof,
        measured: list[float] = [],
        quality: float = 0.0,
        score: float = 0.0;
}

def assign_districts(plan: Expedition, stream: Stream) {
    order = stream.order(DISTRICTS);
    count = min(DISTRICTS, max(2, plan.sections + stream.below(2)));
    plan.districts = order[:count];
    beats = beats_of(plan);
    for beat in beats {
        beat.district = plan.districts[beat.section % count];
    }
    # Optional rooms borrow their parent's district.
    for beat in beats {
        if beat.optional {
            for other in [beat<-:Link:<-][?:Beat] {
                beat.district = other.district;
            }
        }
    }
}

def measure(candidate: Candidate) -> list[float] {
    rooms = rooms_of(candidate.site);
    links = [
        link
        for link in links_of(candidate.plan)
        if link.mode != "window"
    ];
    cycles = len(links) - len(rooms) + 1;
    loop = min(1.0, float(max(0, cycles)) / max(1.0, 0.3 * float(len(rooms))));
    climb = 0.0;
    passages = [
        p
        for p in passages_of(candidate.site)
        if not p.teleport and not p.window
    ];
    for passage in passages {
        a = rooms[passage.tail];
        b = rooms[passage.head];
        climb += float(
            abs((a.z + passage.tail_socket.offset) - (b.z + passage.head_socket.offset))
        );
    }
    spread = float(max([room.z for room in rooms]) - min([room.z for room in rooms]));
    vertical = min(
        1.0, 0.5 * climb / max(1.0, float(len(passages))) / 96.0 + 0.5 * spread / 640.0
    );
    fights = len(
        [
            room
            for room in rooms
            if room.kind not in ["start", "goal", "recovery", "cache", "vista"]
        ]
    );
    density = min(
        1.0, float(candidate.economy.monsters) / max(1.0, float(fights)) / 5.0
    );
    size = max(0.0, min(1.0, float(len(rooms) - 12) / 26.0));
    return [loop, vertical, density, size];
}

def judge(candidate: Candidate) -> float {
    quality = 1.0;
    quality -= 0.08 * float(candidate.site.teleports);
    quality += min(0.12, 0.04 * float(candidate.site.windows));
    low = candidate.economy.low;
    if low < 15.0 {
        quality -= (15.0 - low) / 60.0;
    }
    recipes: list[str] = [];
    for beat in candidate.bp.interiors {
        recipe = candidate.bp.interiors[beat].recipe;
        if recipe not in recipes {
            recipes.append(recipe);
        }
    }
    rooms = rooms_of(candidate.site);
    quality += 0.25 * float(len(recipes)) / float(min(len(rooms), 11));
    secrets = len(
        [
            room
            for room in rooms
            if room.kind == "cache"
        ]
    );
    quality += 0.03 * float(min(secrets, 3));
    # Every mandatory room should be on the proven route.
    quality -= 0.05
        * float(
            len(
                [
                    room
                    for room in rooms
                    if room.beat not in candidate.proof.rooms and not room.optional
                ]
            )
        );
    return quality;
}

glob REJECTIONS: dict[str, int] = {};

# Everything one candidate attempt produced, and why it was rejected if it was.
obj Draft {
    has reason: str = "",
        plan: Expedition | None = None,
        site: Site | None = None,
        bp: Blueprint | None = None,
        economy: Economy | None = None,
        proof: Proof | None = None;
}

def assemble(seed: int, index: int, niche: list[int], archetype: str) -> Draft {
    stream = stream_for(seed, "candidate").child("k", index);
    draft = Draft();
    target_loop = BINS[niche[0]];
    target_vertical = BINS[niche[1]];
    target_density = [0.3, 0.55, 0.85][niche[2]];
    rooms = [16, 24, 32][niche[3]] + stream.between(-3, 3);
    loopiness = max(0.0, min(1.0, target_loop + stream.uniform(-0.15, 0.15)));
    verticality = max(0.0, min(1.0, target_vertical + stream.uniform(-0.15, 0.15)));
    density = max(0.15, min(1.0, target_density + stream.uniform(-0.1, 0.1)));
    sections = 1 + niche[3] + stream.below(2);
    objectives = 1 + stream.below(3);
    plan: Expedition | None = None;
    try {
        plan = build_mission(
            seed,
            stream.derive("mission"),
            archetype,
            objectives,
            sections,
            rooms,
            loopiness
        );
    } except (AssertionError, ValueError) {
        draft.reason = "mission";
        return draft;
    }
    if plan is None {
        draft.reason = "mission";
        return draft;
    }
    draft.plan = plan;
    plan.verticality = verticality;
    plan.density = density;
    plan.candidate = index;
    assign_districts(plan, stream.derive("districts"));
    site = embed(plan, stream.derive("layout"));
    draft.site = site;
    if site.failures {
        draft.reason = "layout " + site.failures;
        return draft;
    }
    target_heights(site, stream.derive("heights"), verticality);
    if not solve_heights(site) {
        draft.reason = "heights";
        return draft;
    }
    for room in rooms_of(site) {
        room.district = beats_of(plan)[room.beat].district;
    }
    bp = new_blueprint(site);
    draft.bp = bp;
    if not carve_rooms(bp, site, stream.derive("rooms"), verticality) {
        draft.reason = "interior";
        return draft;
    }
    if not carve_corridors(
        bp, site, plan, stream.derive("corridors"), beats_of(plan)
    ) {
        draft.reason = "corridor";
        return draft;
    }
    carve_windows(bp, site);
    if [
        door
        for door in bp.doors
        if door.kind == "invalid"
    ] {
        draft.reason = "doors";
        return draft;
    }
    draft.economy = direct(plan, site, bp, stream.derive("director"), density);
    starts = [
        mark
        for mark in bp.marks
        if mark.kind == "info_player_start"
    ];
    if not starts {
        draft.reason = "start";
        return draft;
    }
    proof = progress(plan, bp, site, starts[0].x, starts[0].y);
    draft.proof = proof;
    if not proof.reached_exit {
        draft.reason = "proof";
    }
    return draft;
}

def build_candidate(
    seed: int, index: int, niche: list[int], archetype: str
) -> Candidate | None {
    draft = assemble(seed, index, niche, archetype);
    if draft.reason {
        REJECTIONS[draft.reason] = REJECTIONS.get(draft.reason, 0) + 1;
        return None;
    }
    plan = draft.plan;
    site = draft.site;
    bp = draft.bp;
    economy = draft.economy;
    proof = draft.proof;
    if plan is None or site is None or bp is None or economy is None or proof is None {
        return None;
    }
    candidate = Candidate(plan=plan, site=site, bp=bp, economy=economy, proof=proof);
    candidate.measured = measure(candidate);
    candidate.quality = judge(candidate);
    return candidate;
}

def briefing_for(plan: Expedition) -> str {
    counts: dict[str, int] = {};
    for token in plan.objectives {
        kind = "keys"
            if token.startswith("key_")
            else ("relays" if token.startswith("relay:") else "guardians");
        counts[kind] = counts.get(kind, 0) + 1;
    }
    parts: list[str] = [];
    if counts.get("keys", 0) {
        parts.append(
            "recover "
                + str(counts["keys"])
                + (" keys" if counts["keys"] > 1 else " key")
        );
    }
    if counts.get("relays", 0) {
        parts.append(
            "throw "
                + str(counts["relays"])
                + (" relays" if counts["relays"] > 1 else " relay")
        );
    }
    if counts.get("guardians", 0) {
        parts.append(
            "slay "
                + str(counts["guardians"])
                + (" guardians" if counts["guardians"] > 1 else " guardian")
        );
    }
    route = " > ".join([DISTRICT_NAMES[d] for d in plan.districts]);
    return route + " | " + ", ".join(parts).capitalize() + ", reach extraction";
}

def survey(seed: int) -> Survey {
    niche = niche_for(seed);
    archetype = ARCHETYPES[mix32(seed + 7919) % len(ARCHETYPES)];
    target = [
        BINS[niche[0]],
        BINS[niche[1]],
        [0.3, 0.55, 0.85][niche[2]],
        [0.15, 0.5, 0.85][niche[3]]
    ];
    best: Candidate | None = None;
    result = Survey(seed=seed, niche=niche, target=target, archetype=archetype);
    for index in range(CANDIDATES * 3) {
        if index >= CANDIDATES and best is not None {
            break;
        }
        result.candidates += 1;
        candidate: Candidate | None = None;
        try {
            candidate = build_candidate(seed, index, niche, archetype);
        } except (AssertionError, ValueError) {
            candidate = None;
        }
        if candidate is None {
            continue;
        }
        result.valid += 1;
        distance = 0.0;
        for axis in range(4) {
            distance += (candidate.measured[axis] - target[axis])
                * (candidate.measured[axis] - target[axis]);
        }
        candidate.score = candidate.quality - 1.2 * math.sqrt(distance);
        if best is None or candidate.score > best.score {
            best = candidate;
        }
    }
    if best is None {
        raise ValueError("No valid expedition candidate for seed " + str(seed));
    }
    result.plan = best.plan;
    result.site = best.site;
    result.bp = best.bp;
    result.economy = best.economy;
    result.measured = best.measured;
    result.quality = best.quality;
    result.score = best.score;
    result.briefing = briefing_for(best.plan);
    starts = [
        mark
        for mark in best.bp.marks
        if mark.kind == "info_player_start"
    ];
    result.start = [starts[0].x, starts[0].y, starts[0].z];
    return result;
}

def generate(
    world: World, name: str, textures: list[Texture], cache_directory: str = ""
) -> Level {
    record = survey(seed_from(name));
    bp = record.bp;
    site = record.site;
    if bp is None or site is None {
        raise ValueError("Expedition survey is incomplete");
    }
    compiled = compile_blueprint(bp, site);
    bsp = compiled.bsp;
    bsp.textures = textures;
    bsp.clusters = len(bp.regions);
    bsp.cluster_bytes = (bsp.clusters + 7) // 8;
    bsp.visibility = cluster_visibility(bp);
    record.visible_pairs = visible_pairs(bp, bsp.visibility);
    level = Level(active=True, name=name, bsp=bsp);
    level.briefing = record.briefing;
    level.asset_manifest = "|".join([texture.name for texture in textures]);
    if textures {
        level.asset_manifest += "|"
            + "|".join(
                [
                    ent.fields.get("asset_game", "passion")
                        + ":"
                        + ent.fields.get("classname", "") for ent in bsp.entities
                ]
            );
    }
    prepare_level(world, level);
    world +>:Surveys:+> record;
    if compiled.exit_low {
        volume = CollisionMap();
        volume.add_box(
            Vec3(
                x=compiled.exit_low[0], y=compiled.exit_low[1], z=compiled.exit_low[2]
            ),
            Vec3(
                x=compiled.exit_high[0],
                y=compiled.exit_high[1],
                z=compiled.exit_high[2]
            ),
            Vec3(),
            Vec3(),
            Vec3()
        );
        extraction = LevelExit(
            destination="passion_complete", contact=True, volume=volume
        );
        world +>:HasExit:+> extraction;
        world +>:HasSignal:+> extraction.activation;
    }
    world +>:HasSignal:+> level.completion;
    validate_geometry(level, bp);
    if textures {
        bake(level, bp, site, cache_directory);
    }
    return level;
}

# Physical checks of the compiled world against the blueprint: floors support
# every corridor waypoint and standing hulls fit along every route.
def validate_geometry(level: Level, bp: Blueprint) {
    movers = [
        i
        for i in range(len(level.collision.models))
        if level.collision.models[i] != 0
    ];
    for link in bp.routes {
        for point in bp.routes[link] {
            top = Vec3(x=point[0], y=point[1], z=point[2] + 64.0);
            bottom = Vec3(x=point[0], y=point[1], z=point[2] - 8.0);
            floor = level.collision.trace_point(top, bottom, movers);
            if floor.start_solid or floor.fraction >= 1.0 {
                raise ValueError("Unsupported corridor waypoint on link " + str(link));
            }
            height = top.z + (bottom.z - top.z) * floor.fraction;
            if abs(height - point[2]) > 0.5 {
                raise ValueError("Corridor floor mismatch on link " + str(link));
            }
            standing = Vec3(x=point[0], y=point[1], z=height + 46.125);
            if level.collision.trace(standing, standing, movers).start_solid {
                raise ValueError("Blocked corridor waypoint on link " + str(link));
            }
        }
    }
}

def survey_of(world: World) -> Survey | None {
    found = [world->:Surveys:->][?:Survey];
    return found[0] if found else None;
}
