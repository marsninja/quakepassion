"""Write a Passion expedition's map file, to open in the studio
(`./qp +edit +ed_open <file>`) or read as text, and say how its survey went.

    jac build scripts/passion_map.jac --native -o .jac/qp-passion-map
    QP_SEED=42 .jac/qp-passion-map out.map

QP_SEED picks the seed (default 42; QP_SEEDS a list of seeds to survey
without writing maps); the first argument names the file (default
passion_<seed>.map)."""
import os;
import sys;
import time;
import from games.passion.generate { survey, Survey }
import from games.passion.arrange { estate_spaces, estate_corridors }
import from editor.formats.map { write_map }

def:priv survey_words(record: Survey, seconds: float) -> str {
    rejected = " ".join([reason + "=" + str(count) for (reason, count) in record.rejections.items()]);
    estate = record.estate;
    rooms = 0;
    corridors = 0;
    teleports = 0;
    windows = 0;
    if estate is not None {
        windows = estate.windows;
        spaces = estate_spaces(estate);
        rooms = len([space for space in spaces if space.role != "corridor"]);
        corridors = len(spaces) - rooms;
        teleports = estate.teleports;
    }
    return "passion-map seed=" + str(record.seed) + " score=" + str(round(record.score, 2)) + " tried=" + str(record.candidates)
        + " valid=" + str(record.valid) + " rooms=" + str(rooms) + " corridors=" + str(corridors) + " teleports="
        + str(teleports) + " windows=" + str(windows) + " rejected=[" + rejected + "] seconds=" + str(round(seconds, 2));
}

with entry {
    seeds = (os.environ.get("QP_SEEDS", "")).split();
    if seeds {
        for word in seeds {
            began = time.time();
            try {
                record = survey(int(word));
                print(survey_words(record, time.time() - began));
                for note in record.notes {
                    print("  " + note);
                }
            } except ValueError as failure {
                print("passion-map seed=" + word + " failed: " + str(failure));
            }
        }
        return;
    }
    seed = int(os.environ.get("QP_SEED", "42"));
    path = sys.argv[1] if len(sys.argv) > 1 else "passion_" + str(seed) + ".map";
    began = time.time();
    record = survey(seed);
    with open(path, "w") as handle {
        handle.write(write_map(record.items));
    }
    print(survey_words(record, time.time() - began));
    print("briefing " + record.briefing);
    for (name, value) in record.measures.items() {
        print("measure " + name + "=" + str(round(value, 3)));
    }
    estate = record.estate;
    if estate is not None {
        for space in estate_spaces(estate) {
            if space.role != "corridor" {
                print(
                    "space " + str(space.id) + " " + space.role + " " + space.kind + " at " + str(space.x) + "," + str(space.y)
                        + "," + str(space.z) + " size " + str(space.w) + "x" + str(space.d) + "x" + str(space.h) + " levels "
                        + str(space.levels)
                );
            }
        }
    }
}
