"""Essences: the level graphs of the original levels a Passion level is made
from.

An essence is an original level's graph (`engine/level/`): where a body can
go, what bars the way and what opens it, what stands where, and how the
level is progressed through. It is read from the player's own game files the
first time it is wanted (the original loaded as the game loads it, its
monsters, items and triggers spawned so its openers can be found), proven,
and kept on disk with its verdict, so it is read once a machine. Only an
essence that proves clean (it finishes, nothing strands a player) is ever
made into a level; the others are kept with their verdict and passed over.

A run picks its essences by its seed, none twice in a run, leaning deeper
into the run toward the ones whose fights cost the most health."""
import os;
import time;
import from engine.world.world { World }
import from engine.world.level { load_level }
import from engine.world.teardown { destroy_graph, collision_roots }
import from engine.assets.content { game_directory }
import from engine.level.graph { LevelGraph, Place, graph_places, write_graph, read_graph }
import from engine.level.extract { read_level_graph }
import from engine.level.prove { prove_level, prune_traps }
import from engine.level.budget { budget_route, start_kit }
import from games.items { populate_pickups }
import from games.opponents { populate_opponents }
import from .originals { all_originals }
import from .random { Stream, stream_for }

"""Where essences are kept: under QP_CONFIG_DIR (else the home folder),
never in the game's own folders."""
def essence_folder() -> str {
    configured = os.getenv("QP_CONFIG_DIR", "");
    return (configured if configured else os.path.expanduser("~")) + "/.quakepassion-essences";
}

"""The file an essence (`game:map`) is kept in."""
def essence_path(spec: str) -> str {
    return essence_folder() + "/" + spec.replace(":", "-") + ".graph";
}

"""Whether a kept essence was proven clean (its notes carry the verdict)."""
def essence_clean(atlas: LevelGraph) -> bool {
    for note in atlas.notes {
        if note.startswith("proof clean") {
            return True;
        }
    }
    return False;
}

"""A note of how hard an essence's fights are: the lowest health its
budgeted route fell to (kept in its notes)."""
def essence_lowest(atlas: LevelGraph) -> float {
    for note in atlas.notes {
        if note.startswith("lowest ") {
            return float(note[7:]);
        }
    }
    return 100.0;
}

"""Read an original (`game:map`) from the player's files: loaded at skill
1, its things spawned, its graph read and proven, and the verdict and
budget noted on it. Its own graph is torn down after."""
def read_essence(spec: str) -> LevelGraph {
    parts = spec.split(":");
    game = parts[0];
    began = time.time();
    world = World();
    directory = game_directory(game);
    level = load_level(world, directory, parts[1], game, 1);
    populate_pickups(world, level, directory);
    populate_opponents(world, level, directory);
    atlas = read_level_graph(world, level);
    proof = prove_level(atlas);
    if proof.finishes and proof.softlocks > 0 and prune_traps(atlas) > 0 {
        proof = prove_level(atlas);
    }
    ledger = budget_route(atlas, proof.route, level.collision, start_kit(game));
    clean = proof.finishes and proof.softlocks == 0;
    atlas.notes.append("proof " + ("clean" if clean else "failed") + ": finishes " + str(proof.finishes) + ", " + str(proof.softlocks) + " softlocks");
    atlas.notes.append("required " + " ".join(proof.required));
    atlas.notes.append("lowest " + str(round(ledger.lowest, 1)));
    atlas.notes.append("read in " + str(round(time.time() - began, 1)) + " s");
    destroy_graph(world, collision_roots(level.collision));
    return atlas;
}

"""An essence, from disk when it has been read before, else read now and
kept. None when the original is not among the player's files."""
def load_essence(spec: str) -> LevelGraph | None {
    kept = read_graph(essence_path(spec));
    if kept is not None {
        return kept;
    }
    try {
        atlas = read_essence(spec);
    } except Exception as failure {
        return None;
    }
    save_essence(atlas, spec);
    return atlas;
}

"""Keep an essence on disk: its graph, and beside it its notes alone (its
verdict, required tokens, budget), which picking from the pool reads
without reading the graph."""
def save_essence(atlas: LevelGraph, spec: str) {
    write_graph(atlas, essence_path(spec));
    with open(essence_path(spec) + ".verdict", "w") as handle {
        handle.write("\n".join(atlas.notes) + "\n");
    }
}

"""What a kept essence's notes say (its verdict file; a graph kept without
one is read once and given one), or None when none is kept."""
def kept_notes(spec: str) -> list[str] | None {
    path = essence_path(spec);
    if not os.path.exists(path) {
        return None;
    }
    if not os.path.exists(path + ".verdict") {
        kept = read_graph(path);
        if kept is None {
            return None;
        }
        save_essence(kept, spec);
        return kept.notes;
    }
    text = "";
    with open(path + ".verdict") as handle {
        text = handle.read();
    }
    return [line for line in text.split("\n") if line];
}

"""Whether notes carry a clean verdict."""
def notes_clean(notes: list[str]) -> bool {
    for note in notes {
        if note.startswith("proof clean") {
            return True;
        }
    }
    return False;
}

"""The essences a run may be made of, in the order its seed picks them:
every original, shuffled by the seed, those already known to have failed
their proof left out. Deeper levels lean toward hard ones by the order
`run_essences` gives."""
def essence_order(seed: int) -> list[str] {
    pool: list[str] = [];
    for spec in all_originals() {
        notes = kept_notes(spec);
        if notes is not None and not notes_clean(notes) {
            continue;
        }
        pool.append(spec);
    }
    order = stream_for(seed, "essences").order(len(pool));
    return [pool[index] for index in order];
}

"""The essence of a run's level `depth`: the seed's order walked from the
level's place in it, the first that proves clean; deeper in the run (from
the third level), the hardest of the next three that do (the lowest health
their fights leave). None when none does."""
def pick_essence(seed: int, depth: int) -> LevelGraph | None {
    order = essence_order(seed);
    found: list[LevelGraph] = [];
    for offset in range(len(order)) {
        spec = order[(depth - 1 + offset) % len(order)];
        atlas = load_essence(spec);
        if atlas is None or not essence_clean(atlas) {
            continue;
        }
        found.append(atlas);
        if depth < 3 or len(found) >= 3 {
            break;
        }
    }
    if not found {
        return None;
    }
    best = found[0];
    for atlas in found {
        if essence_lowest(atlas) < essence_lowest(best) {
            best = atlas;
        }
    }
    return best;
}

"""The essence of an original named outright (`game:map`), clean or not:
for playing one on purpose."""
def named_essence(spec: str) -> LevelGraph | None {
    return load_essence(spec);
}

"""A clean essence already kept on disk, but for `besides` (`game:map`),
picked by the dice: what a splice may take a piece of without reading an
original. None when there is none."""
def kept_donor(besides: str, dice: Stream) -> LevelGraph | None {
    clean: list[str] = [];
    for spec in all_originals() {
        if spec == besides {
            continue;
        }
        notes = kept_notes(spec);
        if notes is not None and notes_clean(notes) {
            clean.append(spec);
        }
    }
    if not clean {
        return None;
    }
    return read_graph(essence_path(clean[dice.below(len(clean))]));
}
