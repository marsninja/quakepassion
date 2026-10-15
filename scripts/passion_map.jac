"""Write a Passion expedition's map file, to open in the studio
(`./qp +edit +ed_open <file>`) or read as text, and say how its survey went.

    jac build scripts/passion_map.jac --native -o .jac/qp-passion-map
    QP_SEED=42 .jac/qp-passion-map out.map

QP_SEED picks the seed (default 42; QP_SEEDS a list of seeds to survey
without writing maps); QP_THEME a theme by key (all for every theme, each
over QP_SEEDS), else the seed's own; the first argument names the file
(default passion_<seed>.map)."""
import os;
import sys;
import time;
import from games.passion.generate { survey, Survey }
import from games.passion.themes { THEMES }
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
    connectors = 0;
    gates = 0;
    kinds: list[str] = [];
    if estate is not None {
        connectors = estate.connectors;
        gates = estate.gates;
        kinds = sorted(list(set([space.kind for space in estate_spaces(estate) if space.role != "corridor"])));
        kinds.append("stack:" + str(estate.stack_tries) + "/" + str(estate.stack_placed) + "/" + str(estate.stack_joined));
    }
    return "passion-map seed=" + str(record.seed) + " theme=" + record.theme + " connectors=" + str(connectors) + " gates=" + str(gates)
        + " kinds=" + ",".join(kinds) + " score=" + str(round(record.score, 2)) + " tried=" + str(record.candidates)
        + " valid=" + str(record.valid) + " rooms=" + str(rooms) + " corridors=" + str(corridors) + " teleports="
        + str(teleports) + " windows=" + str(windows) + " rejected=[" + rejected + "] seconds=" + str(round(seconds, 2));
}

with entry {
    seeds = (os.environ.get("QP_SEEDS", "")).split();
    wanted = os.environ.get("QP_THEME", "");
    themes = [theme.key for theme in THEMES] if wanted == "all" else [wanted];
    if seeds {
        for theme_key in themes {
          for word in seeds {
            began = time.time();
            try {
                record = survey(int(word), [], 1, theme_key);
                print(survey_words(record, time.time() - began));
                for note in record.notes {
                    print("  " + note);
                }
                estate = record.estate;
                if estate is not None {
                    for note in estate.stack_notes {
                        print("  stack: " + note);
                    }
                }
            } except ValueError as failure {
                print("passion-map seed=" + word + " theme=" + theme_key + " failed: " + str(failure));
            }
          }
        }
        return;
    }
    seed = int(os.environ.get("QP_SEED", "42"));
    path = sys.argv[1] if len(sys.argv) > 1 else "passion_" + str(seed) + ".map";
    began = time.time();
    record = survey(seed, [], 1, wanted);
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
        for corridor in estate_corridors(estate) {
            if corridor.connector and len(corridor.column) == 2 {
                print(
                    "connector " + corridor.connector + " link " + str(corridor.link) + " at " + str((corridor.column[0] + 1) * 32) + ","
                        + str((corridor.column[1] + 1) * 32) + " from " + str(corridor.low * 16) + " to " + str(corridor.high * 16)
                        + (" landing " + str(corridor.landing) if corridor.landing else "")
                );
            }
        }
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
