"""Generate a Passion level: an essence picked, and a level made for it.

A run is a seed. Each of its levels takes an essence, the level graph of
one of the original levels of the three games (`essence.jac`), picked by
the seed and the level's depth, and makes a new level of brushes for it:

1. the essence is transformed (mirrored and turned, its keys and switches
   moved to other places still reached before what they open);
2. a level is sculpted round its places (`sculpt.jac`) and cast from its
   graph (`cast.jac`): its gates, openers, teleporters and way out, and a
   population cast afresh to its budget;
3. the level is compiled, then its own level graph is read off it and
   proven: a level whose graph does not prove clean is never played. Up to
   four candidates are made (laid out anew, re-embedded or with a piece of
   another essence spliced in; transformed fully; turned only; as the
   essence lies); the first that proves is lit and played.

Names: `v4-<seed>` is a run's first level and `v4-<seed>-<n>` its level n;
`trace-<map>` makes a level from one original's essence named outright
(`trace-e1m1`, `trace-base1`, `trace-q3dm6`), and leads on into a run of
its own seed. Nothing but the essences is kept on disk."""
import os;
import time;
import from .random { Stream, stream_for, mix32, hash_label }
import from .massing { Massing }
import from .space { Space }
import from .dress { Dressing }
import from .kits { kit_of }
import from .brushwork { map_item_steps }
import from .sculpt { Sculpting, sculpt_steps }
import from .cast { Casting, cast_level }
import from .transform { transform_essence }
import from .essence { pick_essence, named_essence, kept_donor }
import from .embed { reembed, splice }
import from .verify { lost_moves }
import from .originals { all_originals }
import from engine.level.graph { LevelGraph, Move, graph_places }
import from engine.level.extract { read_level_graph }
import from engine.level.prove { prove_level, explain_proof }
import from engine.level.budget { budget_route, start_kit }
import from engine.world.teardown { destroy_graph, collision_roots }
import from games.items { populate_pickups }
import from games.opponents { populate_opponents }
import from editor.formats.map { MapItem, MapFile }
import from editor.document.scene { Scene, scene_from_map }
import from editor.compile.live { Compiling, compile_steps, LiveLevel, Materials, SwatchMaterials }
import from editor.compile.light { light_job_steps, Lighting, LightJob }
import from editor.assets.materials { ArchiveMaterials }
import from engine.math.vec3 { Vec3 }
import from engine.world.level { Level, prepare_level }
import from engine.world.world { World }
import from engine.world.exits { LevelExit, HasExit }
import from engine.world.signals { HasSignal }
import from engine.physics.collision { CollisionMap }

glob VERSION: str = "v4",
     TRACE_PREFIX: str = "trace-",
     CANDIDATES: int = 4,
     LUXEL: float = 32.0,
     # Faces lit between a bake's pauses.
     BAKE_SLICE: int = 8,
     DEPTH_LIMIT: int = 9999;

"""How a level was made: its run and depth, the essence it was made for,
the candidates tried and why any were turned down, what was cast, its map
items, and its proof."""
node Survey {
    has seed: int = 0,
        run: int = 0,
        depth: int = 1,
        essence: str = "",
        briefing: str = "",
        candidates: int = 0,
        notes: list[str] = [],
        start: list[float] = [],
        casting: Casting | None = None,
        items: list[MapItem] = [],
        # The level's own graph as read off it, and its proof's verdict.
        proven: bool = False,
        lowest: float = 0.0;
}

edge Surveys: World --> Survey {}

"""The original (`game:map`) a `trace-<map>` name makes a level of, or ""
for another name."""
def traced_essence(name: str) -> str {
    if not name.startswith(TRACE_PREFIX) {
        return "";
    }
    map = name[len(TRACE_PREFIX):];
    for spec in all_originals() {
        if spec.split(":")[1] == map {
            return spec;
        }
    }
    raise ValueError("No original level is called " + map);
}

"""The run and depth a level's name stands for: `v4-<run>` is the first
level of the run seeded `run` (1 to 2147483646, without leading zeros),
`v4-<run>-<depth>` its level `depth` (2 to 9999); a traced level is the
first of a run of its own."""
def run_of(name: str) -> list[int] {
    spec = traced_essence(name);
    if spec {
        return [hash_label(7, spec) % 2147483646 + 1, 1];
    }
    if not name.startswith(VERSION + "-") {
        raise ValueError("Expected " + VERSION + "-SEED");
    }
    words = name[len(VERSION) + 1:].split("-");
    if len(words) > 2 {
        raise ValueError("Expected " + VERSION + "-SEED or " + VERSION + "-SEED-LEVEL");
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

"""The seed a level's name stands for."""
def seed_from(name: str) -> int {
    found = run_of(name);
    return level_seed(found[0], found[1]);
}

"""A level being made a step at a time, so that one can be made while
another waits on it or the studio watches: what it has made so far (the
survey, the scene, its compile and its light), and how far it has got."""
obj Forge {
    has name: str = "",
        directory: str = "",
        # The materials to build with: one set kept through a run reads the
        # games' archives once and each texture once.
        materials: Materials | None = None,
        # The stage it is at (essence, sculpt, compile, prove, bake, ready)
        # and the step it last took within it.
        stage: str = "",
        step: str = "",
        survey: Survey | None = None,
        sculpting: Sculpting | None = None,
        scene: Scene | None = None,
        compiling: Compiling | None = None,
        made: LiveLevel | None = None,
        job: LightJob | None = None,
        steps: Iterator[str] | None = None,
        finished: bool = False,
        failure: str = "",
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
                self.failure = str(error) if str(error) else "The level could not be made";
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

    """How far it has got, from 0 to 1."""
    def share -> float {
        if self.finished {
            return 1.0;
        }
        shares = {"essence": 0.05, "sculpt": 0.2, "compile": 0.35, "prove": 0.45, "bake": 0.6};
        base = shares.get(self.stage, 0.0);
        job = self.job;
        if self.stage == "bake" and job is not None {
            return base + 0.4 * job.share();
        }
        return base;
    }
}

"""A line on how a level is being made, appended to the file QP_FORGE_LOG
names (when it names one) and closed at once."""
def forge_note(line: str) {
    path = os.getenv("QP_FORGE_LOG", "");
    if not path {
        return;
    }
    with open(path, "a") as handle {
        handle.write(str(round(time.time(), 1)) + " " + line + "\n");
    }
}

"""The steps of a forge: the essence, then candidates (sculpted, cast,
compiled, proven) until one proves clean, then its light."""
def forge_steps(forge: Forge) -> Iterator[str] {
    found = run_of(forge.name);
    seed = level_seed(found[0], found[1]);
    record = Survey(seed=seed, run=found[0], depth=found[1]);
    forge.survey = record;
    forge.stage = "essence";
    yield "essence";
    traced = traced_essence(forge.name);
    # A run's level that no candidate of its essence proves for goes on to
    # the next essence in its seed's order (a named one has only itself).
    for essence_try in range(1 if traced else 3) {
        atlas = named_essence(traced) if traced else pick_essence(seed, found[1] + essence_try);
        if atlas is None {
            raise ValueError("No essence could be read: are the original games' files where Passion looks for them?");
        }
        made_one = False;
        yield from essence_steps(forge, record, atlas, seed);
        if record.proven or (record.casting is not None and os.getenv("QP_PASSION_UNPROVEN", "")) {
            made_one = True;
        }
        if made_one {
            break;
        }
    }
    if not record.proven and not (record.casting is not None and os.getenv("QP_PASSION_UNPROVEN", "")) {
        raise ValueError("No level made for " + record.essence + " proved: " + " | ".join(record.notes[-6:]));
    }
    made_level = forge.made;
    lit_scene = forge.scene;
    if forge.directory and made_level is not None and lit_scene is not None {
        forge.stage = "bake";
        held = Lighting();
        yield from light_job_steps(lit_scene, made_level, LUXEL, 4000000, held);
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

"""The candidates for one essence, into the forge's survey: transformed,
sculpted, cast, compiled and proven, the first that proves kept."""
def essence_steps(forge: Forge, record: Survey, atlas: LevelGraph, seed: int) -> Iterator[str] {
    record.essence = atlas.game + ":" + atlas.name;
    forge_note(forge.name + " takes the essence of " + record.essence + " (" + str(len(graph_places(atlas))) + " places)");
    yield "picked";
    materials = forge.materials;
    if materials is None {
        materials = ArchiveMaterials(directory=forge.directory) if forge.directory else SwatchMaterials();
        forge.materials = materials;
    }
    dice = stream_for(seed, "level");
    chosen = False;
    for attempt in range(CANDIDATES) {
        record.candidates += 1;
        trial = dice.child("candidate", attempt);
        forge.stage = "sculpt";
        forge_note(forge.name + " candidate " + str(attempt) + " begins");
        # The first candidate is laid out anew (re-embedded, or with a piece
        # of another essence spliced in); then the essence transformed in
        # full, turned only, and as it lies.
        essence = transform_essence(atlas, trial.derive("transform"), attempt < 3, attempt < 2);
        if attempt == 0 {
            laid: LevelGraph | None = None;
            if trial.chance(0.5) {
                donor = kept_donor(record.essence, trial.derive("donor"));
                if donor is not None {
                    laid = splice(essence, donor, trial.derive("splice"), record.notes);
                }
            }
            if laid is None {
                laid = reembed(essence, trial.derive("embed"), record.notes);
            }
            if laid is None {
                record.notes.append("candidate 0: could not be laid out anew");
                continue;
            }
            essence = laid;
        }
        made = Sculpting();
        forge.sculpting = made;
        forge_note(forge.name + " candidate " + str(attempt) + " sculpts " + str(len(graph_places(essence))) + " places");
        yield from sculpt_steps(essence, trial.derive("sculpt"), made);
        forge_note(forge.name + " candidate " + str(attempt) + " sculpted");
        mass = made.mass;
        dressing = made.dressing;
        if mass is None or dressing is None {
            record.notes.append("candidate " + str(attempt) + ": not sculpted");
            continue;
        }
        casting = cast_level(essence, made, trial.derive("cast"));
        if not casting.start or not casting.exit_low {
            record.notes.append("candidate " + str(attempt) + ": no start or way out");
            continue;
        }
        names = ", ".join(sorted(set([kit_of(space.district).name for space in made.spaces])));
        briefing = names + " | Reach the way out";
        items: list[MapItem] = [];
        yield from map_item_steps(mass, made.spaces, dressing, casting.items, briefing, items);
        if items {
            for brush in made.liquids + casting.solids {
                items[0].brushes.append(brush);
            }
        }
        yield "brushwork";
        forge.stage = "compile";
        scene = scene_from_map("passion", forge.name, MapFile(items=items));
        compiling = Compiling();
        forge.compiling = compiling;
        yield from compile_steps(scene, materials, True, compiling);
        compiler = compiling.compiler;
        if compiler is None {
            record.notes.append("candidate " + str(attempt) + ": not compiled");
            continue;
        }
        forge.stage = "prove";
        forge_note(forge.name + " candidate " + str(attempt) + " compiled, proving");
        verdict = prove_made(forge, compiler.result, casting, briefing, essence, made);
        yield "proven";
        record.notes.append("candidate " + str(attempt) + ": " + verdict[1]);
        forge_note(forge.name + " candidate " + str(attempt) + ": " + verdict[1][:160]);
        # QP_PASSION_UNPROVEN=1 plays the last candidate when none proves
        # (to look at what the proof found).
        last = attempt == CANDIDATES - 1 and os.getenv("QP_PASSION_UNPROVEN", "") != "";
        if not verdict[0] and not last {
            continue;
        }
        record.proven = verdict[0];
        record.casting = casting;
        record.items = items;
        record.briefing = briefing;
        record.start = casting.start;
        forge.scene = scene;
        forge.made = compiler.result;
        chosen = True;
        break;
    }
    if chosen {
        yield "chosen";
    }
}

"""Prove a level as made: opened in a world of its own as the game opens
it, its things spawned, its own graph read off it and proven, its budget
walked. Answers whether it proves clean, and a line on how it went."""
def prove_made(forge: Forge, made: LiveLevel, casting: Casting, briefing: str, essence: LevelGraph, sculpting: Sculpting) -> tuple[bool, str] {
    began = time.time();
    world = World();
    level = open_made(world, forge.name, made, casting, briefing);
    if forge.directory {
        populate_pickups(world, level, forge.directory);
        populate_opponents(world, level, forge.directory);
    }
    atlas = read_level_graph(world, level);
    proof = prove_level(atlas, False);
    games: dict[str, int] = {};
    for item in casting.items {
        source = item.fields.get("asset_game", "");
        if source {
            games[source] = games.get(source, 0) + 1;
        }
    }
    lead = "q1";
    for (game, count) in games.items() {
        if count > games.get(lead, 0) {
            lead = game;
        }
    }
    ledger = budget_route(atlas, proof.route, level.collision, start_kit(lead));
    clean = proof.finishes and proof.softlocks == 0;
    survey = forge.survey;
    if survey is not None {
        survey.lowest = ledger.lowest;
    }
    line = ("proves clean" if clean else "does not prove (finishes " + str(proof.finishes) + ", " + str(proof.softlocks) + " softlocks)")
        + ": " + str(len(graph_places(atlas))) + " places, budget lowest "
        + str(int(ledger.lowest)) + ", in " + str(round(time.time() - began, 1)) + " s";
    if not clean {
        outside = outside_places(atlas, sculpting);
        if outside {
            line += " | " + " | ".join(outside);
        }
    }
    destroy_graph(world, collision_roots(level.collision));
    if not clean {
        kinds: dict[int, int] = {};
        for place in graph_places(atlas) {
            for move in [edge place->:Move:->] {
                kinds[move.kind] = kinds.get(move.kind, 0) + 1;
            }
        }
        line += " | moves " + " ".join([str(kind) + ":" + str(kinds[kind]) for kind in sorted(kinds.keys())]) + " | " + " | ".join(atlas.notes) + " | " + " | ".join(explain_proof(atlas, proof)) + " | " + " | ".join(lost_moves(essence, atlas, sculpting));
    }
    return (clean, line);
}

"""Places of a made level where the sculpture has no air (a body got
outside the walls): how many, and a few of the moves that lead there from
inside."""
def outside_places(atlas: LevelGraph, sculpting: Sculpting) -> list[str] {
    mass = sculpting.mass;
    if mass is None {
        return [];
    }
    out: dict[int, bool] = {};
    for place in graph_places(atlas) {
        cx = int(place.center.x // 32.0);
        cy = int(place.center.y // 32.0);
        cz = int((place.floor + 8.0) // 16.0);
        if not mass.air(cx, cy, cz) {
            out[place.area] = True;
        }
    }
    lines: list[str] = ["outside the walls: " + str(len(out)) + " places"];
    shown = 0;
    for place in graph_places(atlas) {
        if place.area in out and shown < 3 {
            shown += 1;
            lines.append(
                "  outside " + str(place.area) + " at " + str(int(place.center.x)) + "," + str(int(place.center.y)) + "," + str(int(place.floor))
                    + (" start" if place.start else "") + (" way out" if place.way_out else "") + " moves " + str(len([edge place->:Move:->]))
            );
        }
    }
    for place in graph_places(atlas) {
        if place.area in out {
            continue;
        }
        for move in [edge place->:Move:->] {
            if move.to in out and len(lines) < 6 {
                lines.append(
                    "  out by " + str(place.area) + " -> " + str(move.to) + " kind " + str(move.kind) + (" sure" if move.must else " possible") + " at "
                        + str(int(move.start.x)) + "," + str(int(move.start.y)) + "," + str(int(move.start.z)) + " to " + str(int(move.finish.x))
                        + "," + str(int(move.finish.y)) + "," + str(int(move.finish.z))
                );
            }
        }
    }
    return lines if out else [];
}

"""A made level opened as a level of `world`: its compiled BSP, and the way
out as a contact exit over the gate cast for it."""
def open_made(world: World, name: str, made: LiveLevel, casting: Casting, briefing: str) -> Level {
    bsp = made.bsp;
    level = Level(active=True, name=name, bsp=bsp);
    level.briefing = briefing;
    level.asset_manifest = "|".join([texture.name for texture in bsp.textures]) + "|"
        + "|".join([entity.fields.get("asset_game", "passion") + ":" + entity.fields.get("classname", "") for entity in bsp.entities]);
    prepare_level(world, level);
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

"""Generate the level a name stands for, as a level of `world`: from
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
        raise ValueError("Level " + forge.name + " is not made yet");
    }
    casting = record.casting;
    if casting is None or not casting.exit_low {
        raise ValueError("Level " + forge.name + " has no way out");
    }
    level = open_made(world, forge.name, made, casting, record.briefing);
    # A level begun again after a death reopens its forge: its survey leaves
    # the world it was in (torn down when the new one opens) first.
    for held in [record<-:Surveys:<-][?:World] {
        held del --> record;
    }
    world +>:Surveys:+> record;
    return level;
}

"""The survey a world's level was made from."""
def survey_of(world: World) -> Survey | None {
    found = [world->:Surveys:->][?:Survey];
    return found[0] if found else None;
}
