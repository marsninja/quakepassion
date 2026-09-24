"""Campaign chain audit: load every Q1 and Q2 map headlessly and report, per
map, which exits load, which movers and triggers stay disabled, and which
targeted entities have no activation here. Drives and guards campaign flow.

QP_AUDIT_GAMES=q1,q2 (default) and QP_AUDIT_MAPS=e1m7,jail1 narrow the run."""
import os;
import from engine.core.menu { LevelMenu, game_directory }
import from engine.world.world { World }
import from engine.world.level { load_level }
import from engine.world.exits { LevelExit, HasExit }
import from engine.world.doors { Door, HasDoor, DoorMember }
import from engine.world.triggers { TouchTrigger, HasTrigger }
import from engine.world.traversal { Traversal, HasTraversal }
import from engine.world.trains { Train, HasTrain }
import from engine.world.signals { Signal, HasSignal, chain_notes }

glob AUDIT_MOVERS: list[str] = [
    "func_door", "func_button", "func_plat", "func_door_rotating", "func_water"
];
glob AUDIT_TRIGGERS: list[str] = [
    "trigger_once", "trigger_multiple", "trigger_onlyregistered"
];

glob AUDIT_PLACES: list[str] = [
    "turret_driver", "trigger_teleport", "misc_teleporter", "func_train",
    "misc_viper", "misc_strogg_ship", "misc_teleporttrain", "target_laser"
];

"""One map's findings."""
obj AuditRow {
    has game: str,
        name: str,
        exits_lump: int = 0,
        exits_loaded: int = 0,
        movers_lump: int = 0,
        movers_loaded: int = 0,
        triggers_lump: int = 0,
        triggers_loaded: int = 0,
        teleports_lump: int = 0,
        teleports_loaded: int = 0,
        trains_lump: int = 0,
        trains_loaded: int = 0,
        disabled_signals: int = 0,
        lines: list[str] = [],
        unsupported: dict[str, int] = {};
}

def audit_map(game: str, name: str) -> AuditRow {
    world = World();
    level = load_level(world, game_directory(game), name, game);
    bsp = level.bsp;
    row = AuditRow(game=game, name=name);
    notes: dict[int, str] = {};
    for note in chain_notes(world) {
        if note.entity not in notes {
            notes[note.entity] = note.reason;
        }
    }
    owners: dict[int, list[Signal]] = {};
    for signal in [world->:HasSignal:->][?:Signal] {
        for index in signal.entities {
            owners.setdefault(index, []).append(signal);
        }
    }
    models: set[int] = set();
    for leader in [world->:HasDoor:->][?:Door] {
        if leader.enabled {
            models.add(leader.model);
            for part in [leader->:DoorMember:->][?:Door] {
                models.add(part.model);
            }
        }
    }
    trigger_models: set[int] = set(
        [trigger.model for trigger in [world->:HasTrigger:->][?:TouchTrigger]]
    );
    row.exits_loaded = len([world->:HasExit:->][?:LevelExit]);
    teleports: set[int] = set();
    for item in [world->:HasTraversal:->][?:Traversal] {
        if item.kind != "push" {
            teleports.add(item.activation.entities[0]);
        }
    }
    row.teleports_loaded = len(teleports);
    trains: set[int] = set(
        [train.activation.entities[0] for train in [world->:HasTrain:->][?:Train]]
    );
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        kind = fields.get("classname", "");
        tag = kind + "#" + str(index)
            + (" '" + fields["targetname"] + "'" if fields.get("targetname", "") else "");
        why = notes.get(index, "");
        if (game == "q1" and kind == "trigger_changelevel")
            or (game == "q2" and kind == "target_changelevel") {
            row.exits_lump += 1;
        }
        if kind == "trigger_teleport" or (game == "q2" and kind == "misc_teleporter") {
            row.teleports_lump += 1;
            if index not in teleports {
                row.lines.append("  teleport missing " + tag + (": " + why if why else ""));
            }
        }
        if kind == "func_train" {
            row.trains_lump += 1;
            if index in trains {
                row.trains_loaded += 1;
            } else {
                row.lines.append("  train missing " + tag + (": " + why if why else ""));
            }
        }
        model = fields.get("model", "");
        if kind in AUDIT_MOVERS and model.startswith("*") {
            if kind in ["func_door_rotating", "func_water"] and game != "q2" {
                continue;
            }
            row.movers_lump += 1;
            if int(model[1:]) in models {
                row.movers_loaded += 1;
            } else {
                row.lines.append("  mover disabled " + tag + (": " + why if why else ""));
            }
        }
        if (kind in AUDIT_TRIGGERS or (game == "q1" and kind == "trigger_secret"))
            and model.startswith("*") {
            row.triggers_lump += 1;
            if int(model[1:]) in trigger_models {
                row.triggers_loaded += 1;
            } else {
                row.lines.append("  trigger missing " + tag + (": " + why if why else ""));
            }
        }
        for signal in owners.get(index, []) {
            if not signal.enabled and not signal.killed {
                row.disabled_signals += 1;
                row.lines.append("  signal disabled " + tag + (": " + why if why else ""));
                break;
            }
        }
        # Every recipient a use would reach should have an activation here.
        # Movers' and teleporters' targets are paths and destinations, not uses.
        links: list[str] = [];
        keys = ["killtarget", "deathtarget", "pathtarget"];
        if kind not in AUDIT_PLACES {
            keys.append("target");
        }
        for key in keys {
            if fields.get(key, "") {
                links.append(fields[key]);
            }
        }
        for recipient in range(len(bsp.entities)) {
            other = bsp.entities[recipient].fields;
            if not other.get("targetname", "") or other["targetname"] not in links {
                continue;
            }
            if recipient in owners {
                continue;
            }
            other_kind = other.get("classname", "");
            row.unsupported[other_kind] = row.unsupported.get(other_kind, 0) + 1;
            row.lines.append(
                "  unresolved " + tag + " -> " + other_kind + "#" + str(recipient)
                    + (": " + notes[recipient] if recipient in notes else "")
            );
        }
    }
    if row.exits_loaded < row.exits_lump {
        for index in range(len(bsp.entities)) {
            fields = bsp.entities[index].fields;
            kind = fields.get("classname", "");
            if kind in ["trigger_changelevel", "target_changelevel"] {
                row.lines.append(
                    "  exit " + kind + "#" + str(index) + " map=" + fields.get("map", "")
                        + (" note: " + notes[index] if index in notes else "")
                );
            }
        }
    }
    return row;
}

with entry {
    games = os.getenv("QP_AUDIT_GAMES", "q1,q2").split(",");
    only = [item for item in os.getenv("QP_AUDIT_MAPS", "").split(",") if item];
    verbose = os.getenv("QP_AUDIT_VERBOSE", "1") == "1";
    totals: dict[str, int] = {};
    unsupported: dict[str, int] = {};
    failures: list[str] = [];
    for game in games {
        menu = LevelMenu();
        menu.game = 0 if game == "q1" else 1;
        menu.scan();
        for name in menu.maps {
            if only and name not in only {
                continue;
            }
            try {
                row = audit_map(game, name);
            } except Exception as error {
                failures.append(game + "/" + name + ": " + str(error));
                print("AUDIT FAIL", game, name, str(error));
                continue;
            }
            print(
                "AUDIT", game, name,
                "exits", str(row.exits_loaded) + "/" + str(row.exits_lump),
                "movers", str(row.movers_loaded) + "/" + str(row.movers_lump),
                "triggers", str(row.triggers_loaded) + "/" + str(row.triggers_lump),
                "teleports", str(row.teleports_loaded) + "/" + str(row.teleports_lump),
                "trains", str(row.trains_loaded) + "/" + str(row.trains_lump),
                "disabled_signals", row.disabled_signals,
                "unresolved", sum(row.unsupported.values())
            );
            if verbose {
                for line in row.lines {
                    print(line);
                }
            }
            for (key, value) in [
                ("exits_lump", row.exits_lump),
                ("exits_loaded", row.exits_loaded),
                ("movers_lump", row.movers_lump),
                ("movers_loaded", row.movers_loaded),
                ("triggers_lump", row.triggers_lump),
                ("triggers_loaded", row.triggers_loaded),
                ("teleports_lump", row.teleports_lump),
                ("teleports_loaded", row.teleports_loaded),
                ("trains_lump", row.trains_lump),
                ("trains_loaded", row.trains_loaded),
                ("disabled_signals", row.disabled_signals)
            ] {
                totals[game + " " + key] = totals.get(game + " " + key, 0) + value;
            }
            for (kind, count) in row.unsupported.items() {
                unsupported[game + " " + kind] = unsupported.get(game + " " + kind, 0) + count;
            }
        }
    }
    print("AUDIT TOTALS");
    for key in sorted(totals.keys()) {
        print("  ", key, totals[key]);
    }
    print("AUDIT UNRESOLVED TARGET CLASSES");
    for key in sorted(unsupported.keys()) {
        print("  ", key, unsupported[key]);
    }
    for failure in failures {
        print("AUDIT FAIL", failure);
    }
    assert not failures;
}
