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
    self.play_clock += dt;
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
        self.fired_when[label] = self.play_clock;
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
    if name == "ed_trace" and len(args) > 1 and args[1] == "graph" {
        self.graph_over = (not self.graph_over) if len(args) < 3 or args[2] not in ["on", "off"] else args[2] == "on";
        print("studio: trace graph=" + ("1" if self.graph_over else "0"));
        self.say(
            "The scene's logic is drawn over a played game, lit as it fires" if self.graph_over else "Nothing is drawn over a played game"
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

impl Studio.draw_over_game(width: int, height: int) {
    scene = self.scene;
    if not self.graph_over or not self.playing or scene is None {
        return;
    }
    nodes = scene.logic_nodes();
    if len(nodes) == 0 {
        return;
    }
    canvas = self.canvas;
    canvas.unclip();
    theme = canvas.theme;
    wide = 112;
    tall = 18;
    laid = graph_places([[placed.column, placed.row] for placed in nodes[:48]], wide, tall, 6);
    room = laid[-1];
    panel = Rect(x=max(4, width - room[0] - 8), y=34, w=room[0], h=room[1] + 16);
    canvas.fill(panel, theme.panel.faded(200));
    canvas.outline(panel, theme.border);
    canvas.text("Logic" + ("  (held)" if self.holding else ""), panel.x + 6, panel.y + 2, theme.dim, theme.small);
    places: dict[int, list[int]] = {};
    for (index, placed) in enumerate(nodes[:48]) {
        places[placed.item.serial] = [panel.x + laid[index][0], panel.y + 16 + laid[index][1]];
    }
    # What fires what first, under the boxes.
    for placed in nodes[:48] {
        here_at = places[placed.item.serial];
        for aimed in scene.fires(placed.item) {
            there = places.get(aimed.serial);
            if there is not None {
                canvas.line(here_at[0] + wide, here_at[1] + tall // 2, there[0], there[1] + tall // 2, theme.dim);
            }
        }
    }
    for placed in nodes[:48] {
        at = places[placed.item.serial];
        label = self.signal_label(placed.item.fields);
        lit = flash_level(self.play_clock, self.fired_when.get(label, -1.0), 1.0);
        box = Rect(x=at[0], y=at[1], w=wide, h=tall);
        tone = theme.field;
        if lit > 0.0 {
            tone = ink(0xff7a18, 90 + int(165.0 * lit));
        } elif label in self.fired_names {
            tone = ink(0x3a5a3a);
        }
        canvas.fill(box, tone);
        canvas.outline(box, ink(0xe5484d) if label in self.breaks else theme.border);
        count = self.fired_names.get(label, 0);
        canvas.label(label + (" " + str(count) if count else ""), box, theme.text, -1, 4, theme.small);
    }
}
