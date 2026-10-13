"""A game played from the studio held still and stepped, and how the level
is built. Declarations live in studio.jac."""

impl Studio.play_command(args: list[str]) {
    name = args[0];
    app = self.app;
    if app is None {
        return;
    }
    if name == "ed_played" {
        if len(args) > 1 {
            print("STEP " + args[1]);
        }
        at = app.player.pos;
        built_now = self.live;
        print(
            "studio: play playing=" + ("1" if self.playing else "0") + " held=" + ("1" if self.holding else "0")
                + " owed=" + str(self.steps_owed) + " player=" + str(round(at.x, 1)) + "," + str(round(at.y, 1))
                + "," + str(round(at.z, 1)) + " made=" + str(built_now.brushes if built_now is not None else 0)
                + " drawn=" + str(app.last_drawn)
                + " doors=" + ",".join([door.state for door in [app.world->:HasDoor:->][?:Door]])
        );
        return;
    }
    if not self.playing {
        self.say(name + ": nothing is being played (F5 plays the scene)");
        return;
    }
    if name == "ed_fire" {
        wanted = args[1] if len(args) > 1 else "";
        # The level's entities of that name, and the signals that stand for them.
        entities = app.level.bsp.entities;
        named: list[int] = [];
        for index in range(len(entities)) {
            if wanted and entities[index].fields.get("targetname", "") == wanted {
                named.append(index);
            }
        }
        count = 0;
        for signal in [app.world->:HasSignal:->][?:Signal] {
            meant = False;
            for index in signal.entities {
                if index in named {
                    meant = True;
                }
            }
            if meant and not signal.killed {
                # As if something that targets it had gone off.
                signal spawn Fire(emit=False, inventory=app.player.inventory);
                count += 1;
            }
        }
        print("studio: fired " + wanted + " " + str(count));
        self.say("Fired " + wanted + " (" + str(count) + ")" if count else "ed_fire: nothing here is named " + wanted);
        return;
    }
    if name == "ed_pause" {
        on = not self.holding;
        if len(args) > 1 and args[1] in ["on", "off", "1", "0"] {
            on = args[1] in ["on", "1"];
        }
        self.holding = on;
        self.steps_owed = 0;
        app.show_notice("Held still - ed_tick moves time on, ed_pause lets it run" if on else "Running");
        return;
    }
    count = 1;
    if len(args) > 1 and args[1].isdigit() {
        count = max(1, min(600, int(args[1])));
    }
    if not self.holding {
        self.say("ed_tick: the game is running (ed_pause holds it still)");
        return;
    }
    self.steps_owed += count;
}

impl Studio.build_mode_command(scene: Scene, args: list[str]) -> bool {
    if args[0] == "ed_bake" {
        wanted = args[1] if len(args) > 1 else "256";
        if wanted == "off" {
            self.vis_cell = 0.0;
            self.say("The level is built as one, all of it drawn from anywhere");
        } elif wanted == "planes" {
            self.vis_cell = BAKE_BY_PLANES;
            self.say(
                "The level is cut by its brushes' own planes into leaves joined by portals, the outside filled and buried faces left out; each drawing what it can see"
            );
        } elif wanted.isdigit() and int(wanted) >= 32 {
            self.vis_cell = float(int(wanted));
            self.say("The level is cut into cells up to " + wanted + " wide, each drawing what it can see");
        } else {
            self.say("ed_bake [planes|cell|off]: a cell is 32 units wide or more");
            return True;
        }
        self.built_geometry = -1;
        return True;
    }
    if args[0] != "ed_build" {
        return False;
    }
    how = args[1] if len(args) > 1 else "";
    if how == "full" or how == "quick" {
        self.luxel = 16.0 if how == "full" else 32.0;
        self.lit = True;
        self.keep_settings();
    } elif how == "flat" {
        self.lit = False;
        self.keep_settings();
    } elif how == "fresh" {
        # Nothing built before is taken on trust.
        self.built_copies = [];
    } elif how == "background" {
        word = args[2] if len(args) > 2 else "";
        self.light_background = (not self.light_background) if word not in ["on", "off"] else word == "on";
        self.keep_settings();
        print("studio: build background=" + ("1" if self.light_background else "0"));
        self.say(
            "Light is baked a slice a frame while the studio goes on (the level is shown unlit until it is done)"
            if self.light_background
            else "Light is baked before the level is shown"
        );
        return True;
    } elif how == "cancel" {
        task = self.light_task;
        self.light_task = None;
        print("studio: build cancelled=" + ("1" if task is not None else "0"));
        self.say("The light under way was given up: the level stays unlit until it is built again" if task is not None else "No light is being baked");
        return True;
    } elif how {
        self.say("ed_build [full|quick|flat|fresh] | background [on|off] | cancel");
        return True;
    }
    # Built again whatever has changed.
    self.built_geometry = -1;
    self.say(
        "Building" + (" lit finely" if how == "full" else (" lit coarsely" if how == "quick" else (" without light" if how == "flat" else (" from nothing" if how == "fresh" else " again"))))
    );
    return True;
}
