"""Measure the original games' levels with Passion's yardstick and say how
each uses its textures: the facts `games/passion/corpus.jac` is written
from.

    jac build scripts/passion_corpus.jac --native -o .jac/qp-corpus
    DYLD_LIBRARY_PATH=vendor .jac/qp-corpus > corpus.txt

QP_CORPUS_GAMES picks the games (default "q1 q2 q3"; "passion" measures
generated expeditions, v3-1 to v3-8, lit and kept under QP_LIGHT_CACHE),
QP_CORPUS_MAPS a list of maps to measure instead of each game's own, QP_ASSETS the folder that
holds id1, baseq2 and baseq3 (default ~/quake-assets). Each level prints a
`measure` line (every measure as name=value) and a `texture` line for each
texture its world shows: name, floor, wall and ceiling area, trim area,
faces, and flags (L light, W liquid, S sky)."""
import os;
import time;
import from engine.world.level { load_level }
import from engine.world.world { World }
import from games.passion.yardstick { MEASURES, measure_parts, texture_uses }
import from games.passion.generate { generate }

glob CORPUS_Q1: list[str] = [
         "start",
         "e1m1",
         "e1m2",
         "e1m3",
         "e1m4",
         "e1m5",
         "e1m6",
         "e1m7",
         "e1m8",
         "e2m1",
         "e2m2",
         "e2m3",
         "e2m4",
         "e2m5",
         "e2m6",
         "e2m7",
         "e3m1",
         "e3m2",
         "e3m3",
         "e3m4",
         "e3m5",
         "e3m6",
         "e3m7",
         "e4m1",
         "e4m2",
         "e4m3",
         "e4m4",
         "e4m5",
         "e4m6",
         "e4m7",
         "e4m8",
         "end",
         "dm1",
         "dm2",
         "dm3",
         "dm4",
         "dm5",
         "dm6"
     ];

glob CORPUS_Q2: list[str] = [
         "base1",
         "base2",
         "base3",
         "train",
         "bunk1",
         "ware1",
         "ware2",
         "jail1",
         "jail2",
         "jail3",
         "jail4",
         "jail5",
         "security",
         "mintro",
         "mine1",
         "mine2",
         "mine3",
         "mine4",
         "fact1",
         "fact2",
         "fact3",
         "power1",
         "power2",
         "cool1",
         "waste1",
         "waste2",
         "waste3",
         "biggun",
         "hangar1",
         "hangar2",
         "lab",
         "command",
         "strike",
         "space",
         "city1",
         "city2",
         "city3",
         "boss1",
         "boss2",
         "q2dm1",
         "q2dm2",
         "q2dm3",
         "q2dm4",
         "q2dm5",
         "q2dm6",
         "q2dm7",
         "q2dm8"
     ];

glob CORPUS_Q3: list[str] = [
         "q3dm0",
         "q3dm1",
         "q3dm2",
         "q3dm3",
         "q3dm4",
         "q3dm5",
         "q3dm6",
         "q3dm7",
         "q3dm8",
         "q3dm9",
         "q3dm10",
         "q3dm11",
         "q3dm12",
         "q3dm13",
         "q3dm14",
         "q3dm15",
         "q3dm16",
         "q3dm17",
         "q3dm18",
         "q3dm19",
         "q3tourney1",
         "q3tourney2",
         "q3tourney3",
         "q3tourney4",
         "q3tourney5",
         "q3tourney6",
         "q3ctf1",
         "q3ctf2",
         "q3ctf3",
         "q3ctf4"
     ];

def:priv corpus_number(value: float) -> str {
    return str(round(value, 4));
}

with entry {
    home = os.getenv("HOME") or "";
    assets = os.getenv("QP_ASSETS") or (home + "/quake-assets");
    games = (os.getenv("QP_CORPUS_GAMES") or "q1 q2 q3").split();
    chosen = (os.getenv("QP_CORPUS_MAPS") or "").split();
    for game in games {
        folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
        maps = CORPUS_Q1 if game == "q1" else (CORPUS_Q2 if game == "q2" else CORPUS_Q3);
        if game == "passion" {
            maps = ["v3-" + str(seed) for seed in range(1, 9)];
        }
        if chosen {
            maps = chosen;
        }
        for name in maps {
            began = time.time();
            try {
                if game == "passion" {
                    level = generate(World(), name, assets, os.environ.get("QP_LIGHT_CACHE", ""));
                } else {
                    level = load_level(World(), assets + "/" + folder, name, game);
                }
            } except Exception as failure {
                print("skipped " + game + " " + name + " " + str(failure));
                continue;
            }
            loaded = time.time();
            found = measure_parts(level.bsp, level.collision);
            words: list[str] = ["measure", game, name];
            for measure in MEASURES {
                words.append(measure + "=" + corpus_number(found[measure]));
            }
            words.append("seconds=" + corpus_number(time.time() - loaded));
            words.append("load=" + corpus_number(loaded - began));
            print(" ".join(words));
            for use in texture_uses(level.bsp) {
                flags = ("L" if use.light else "") + ("W" if use.liquid else "") + ("S" if use.sky else "");
                print(
                    "texture " + game + " " + name + " " + use.name + " " + corpus_number(use.floor) + " "
                        + corpus_number(use.wall) + " " + corpus_number(use.ceiling) + " " + corpus_number(use.trim) + " "
                        + str(use.faces) + " " + (flags if flags else "-")
                );
            }
        }
    }
}
