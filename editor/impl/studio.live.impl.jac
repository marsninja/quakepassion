"""A game played from the studio, watched: which of its signals fire and in
what order, firings that hold the game still, and the live player and
signals looked at and changed while it is held. Declarations live in
studio.jac."""

impl Studio.signal_label(fields: dict[str, str]) -> str {
    # What fires it by, when it has a name; else what it is and what it fires.
    named = fields.get("targetname", "");
    if named {
        return named;
    }
    aimed = fields.get("target", "");
    kind = fields.get("classname", "");
    return kind + "->" + aimed if aimed else kind;
}

impl Studio.played(dt: float) {
    app = self.app;
    if not self.playing or app is None {
        return;
    }
    # The tools are given the frame while a game is played too: a script
    # attached to what fires is theirs to run.
    for tool in self.tools {
        tool.tick(self.host(), dt);
    }
    signals = [app.world->:HasSignal:->][?:Signal];
    if len(self.fired_seen) != len(signals) {
        # The level has only now been loaded: from here on is what counts.
        self.fired_seen = [signal.fired for signal in signals];
        return;
    }
    entities = app.level.bsp.entities;
    for (index, signal) in enumerate(signals) {
        if signal.fired <= self.fired_seen[index] {
            continue;
        }
        more = signal.fired - self.fired_seen[index];
        self.fired_seen[index] = signal.fired;
        label = signal.name;
        if len(signal.entities) > 0 and signal.entities[0] >= 0 and signal.entities[0] < len(entities) {
            label = self.signal_label(entities[signal.entities[0]].fields);
        }
        if not label {
            continue;
        }
        self.fired_names[label] = self.fired_names.get(label, 0) + more;
        if len(self.fire_log) < 400 {
            self.fire_log.append(label);
        }
        if self.tracing {
            app.show_notice(label + " fired");
        }
        if label in self.breaks and not self.holding {
            # A firing to stop at: the game is held as it stands.
            self.holding = True;
            self.steps_owed = 0;
            app.show_notice("Held: " + label + " fired (ed_pause lets it run)");
            print("studio: break " + label);
        }
    }
}

impl Studio.live_command(args: list[str]) -> bool {
    name = args[0];
    app = self.app;
    if app is None {
        return True;
    }
    if name == "ed_break" {
        label = args[1] if len(args) > 1 else "";
        if label == "clear" {
            self.breaks = [];
        } elif label and label in self.breaks {
            self.breaks.remove(label);
        } elif label {
            self.breaks.append(label);
        }
        print("studio: breaks " + (",".join(sorted(self.breaks)) if self.breaks else "none"));
        self.say(
            "A played game is held when one of these fires: " + ", ".join(sorted(self.breaks))
            if self.breaks
            else "No firing holds a played game (ed_break <targetname>)"
        );
        return True;
    }
    if name == "ed_trace" {
        self.tracing = not self.tracing;
        if len(args) > 1 and args[1] in ["on", "off"] {
            self.tracing = args[1] == "on";
        }
        self.say("Each firing in a played game is named as it happens" if self.tracing else "Firings are counted in silence");
        return True;
    }
    if name == "ed_fired" {
        if len(args) > 1 {
            print("STEP " + args[1]);
        }
        counted = [each + "=" + str(self.fired_names[each]) for each in sorted(self.fired_names.keys())];
        print("studio: signals " + (" ".join(counted) if counted else "none"));
        print("studio: order " + (",".join(self.fire_log[:40]) if self.fire_log else "none"));
        self.say("Fired: " + ", ".join(counted) if counted else "Nothing has fired in the game played from here");
        self.seen_revision = -1;
        return True;
    }
    if name != "ed_live" {
        return False;
    }
    if not self.playing {
        self.say("ed_live: nothing is being played (F5 plays the scene)");
        return True;
    }
    what = args[1] if len(args) > 1 else "";
    if what in ["opponents", "doors", "pickups", "opponent", "door", "pickup"] {
        return self.live_others(args);
    }
    player = app.player;
    signals = [app.world->:HasSignal:->][?:Signal];
    entities = app.level.bsp.entities;
    if what == "player" and len(args) > 3 and args[2] == "health" and args[3].lstrip("-").isdigit() {
        player.health = max(1, min(999, int(args[3])));
    } elif what == "player" and len(args) > 5 and args[2] == "at" {
        try {
            player.pos = Vec3(x=float(args[3]), y=float(args[4]), z=float(args[5]));
            player.velocity = Vec3();
        } except ValueError {
            self.say("ed_live player at <x> <y> <z>");
            return True;
        }
    } elif what == "signal" and len(args) > 3 and args[3] in ["on", "off"] {
        changed = 0;
        for signal in signals {
            if len(signal.entities) > 0 and signal.entities[0] < len(entities)
                and self.signal_label(entities[signal.entities[0]].fields) == args[2] and not signal.killed {
                signal.enabled = args[3] == "on";
                changed += 1;
            }
        }
        if changed == 0 {
            self.say("ed_live signal <name> on|off: nothing live is named " + args[2]);
            return True;
        }
    } elif what {
        self.say("ed_live [player health <n> | player at <x y z> | signal <name> on|off | opponents | doors | pickups | opponent|door|pickup <number> ...]");
        return True;
    }
    # How the live game stands: the player, and every signal that has a name.
    at = player.pos;
    print(
        "studio: live player at=" + str(int(round(at.x))) + "," + str(int(round(at.y))) + "," + str(int(round(at.z)))
            + " health=" + str(player.health) + " held=" + ("1" if self.holding else "0")
    );
    print(
        "studio: live pickups=" + str(len([app.world->:HasPickup:->][?:Pickup])) + " opponents="
            + str(len([app.world->:HasOpponent:->][?:Opponent]))
    );
    shown = 0;
    for signal in signals {
        if len(signal.entities) == 0 or signal.entities[0] >= len(entities) or shown >= 60 {
            continue;
        }
        fields = entities[signal.entities[0]].fields;
        print(
            "studio: live signal " + self.signal_label(fields) + " class=" + fields.get("classname", "") + " enabled="
                + ("1" if signal.enabled and not signal.killed else "0") + " fired=" + str(signal.fired)
        );
        shown += 1;
    }
    self.say("Live: the player at " + str(int(round(at.x))) + " " + str(int(round(at.y))) + " " + str(int(round(at.z)))
        + " with " + str(player.health) + " health, " + str(shown) + " signals");
    return True;
}
