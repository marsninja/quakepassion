"""Read a player bot run back from its decision trace and say, level by
level, how it went: time taken, deaths and what caused them, objectives
chosen and how each ended, routes not found and why, blocks, and what the
bot was doing in the seconds before each death or give-up.

    jac run scripts/autoplay_report.jac [.jac/autoplay-trace.jsonl]"""
import sys;
import json;

"""One level's part of a run."""
obj LevelRun {
    has map: str,
        start: float,
        end: float = 0.0,
        restarts: int = 0,
        deaths: list[dict[str, any]] = [],
        chosen: int = 0,
        ended: list[dict[str, any]] = [],
        no_route: dict[str, int] = {},
        blocked: int = 0,
        boxes: list[dict[str, any]] = [];
}

with entry {
    path = sys.argv[1] if len(sys.argv) > 1 else ".jac/autoplay-trace.jsonl";
    levels: list[LevelRun] = [];
    current: LevelRun | None = None;
    with open(path) as source {
        for line in source {
            text = line.strip();
            if not text {
                continue;
            }
            e: dict[str, any] = json.loads(text);
            kind = str(e["kind"]);
            moment = float(e["t"]);
            if kind == "level" {
                if current is not None and current.map == str(e["map"]) {
                    # A restart after a death: the same level again.
                    current.restarts += 1;
                    continue;
                }
                current = LevelRun(map=str(e["map"]), start=moment, end=moment);
                levels.append(current);
                continue;
            }
            if current is None {
                continue;
            }
            current.end = moment;
            if kind == "death" {
                current.deaths.append(e);
            } elif kind == "choose" {
                current.chosen += 1;
            } elif kind == "objective_end" {
                current.ended.append(e);
            } elif kind == "no_route" {
                key = str(e["reason"]).split(" (")[0];
                current.no_route[key] = current.no_route.get(key, 0) + 1;
            } elif kind == "blocked" {
                current.blocked += 1;
            } elif kind == "blackbox" {
                current.boxes.append(e);
            }
        }
    }
    for index in range(len(levels)) {
        level = levels[index];
        finished = index + 1 < len(levels);
        print(
            "==", level.map, "|", round(level.end - level.start), "s |", "finished" if finished else "not finished",
            "| deaths", len(level.deaths), "| blocked", level.blocked
        );
        for death in level.deaths {
            print(
                "   death at t", death["t"], death["at"], "by", death["killer"] or "-", "(" + str(death["means"]) + ")",
                "in water" if int(death["water"]) >= 2 else "", "| doing:", death["stack"] or death["goal"]
            );
        }
        given = [e for e in level.ended if e["result"] != "done"];
        print("   objectives:", level.chosen, "chosen,", len(level.ended) - len(given), "done,", len(given), "given up");
        for e in given {
            print("     given up:", e["objective"], "-", e["result"], "after", e["seconds"], "s");
        }
        if level.no_route {
            print("   no route:", ", ".join([k + " x" + str(v) for (k, v) in level.no_route.items()]));
        }
        for box in level.boxes {
            samples: list[dict[str, any]] = box["samples"];
            if not samples {
                continue;
            }
            still = len([s for s in samples if abs(s["vel"][0]) + abs(s["vel"][1]) < 30]);
            print(
                "   before", box["reason"], "(t", box["t"], "): from", samples[0]["at"], "to", samples[-1]["at"], "| hp",
                samples[0]["hp"], "->", samples[-1]["hp"], "| still", still, "of", len(samples), "| modes",
                sorted(set([str(s["mode"]) for s in samples])), "| legs", sorted(set([int(s["leg"]) for s in samples]))
            );
        }
    }
}
