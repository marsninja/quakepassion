"""The studio's figures: a Quake III body put together from its legs,
torso and head as the game joins them, and a weapon as it is held in view,
each shown as one model. Declarations live in studio.jac."""

"""What a body's sequences are called, by their numbers in animation.cfg."""
glob LEGS_SEQUENCES: dict[str, int] = {
    "walkcr": 13, "walk": 14, "run": 15, "back": 16, "swim": 17, "jump": 18, "land": 19, "jumpb": 20, "landb": 21,
    "idle": 22, "idlecr": 23, "turn": 24
};

glob TORSO_SEQUENCES: dict[str, int] = {
    "gesture": 6, "attack": 7, "attack2": 8, "drop": 9, "raise": 10, "stand": 11, "stand2": 12
};

impl Studio.show_figure(game: str, name: str, model: AnimatedModel, words: str, from_eye: bool) -> bool {
    shown = ModelLook(game=game, name=name, model=model);
    for surface in model.surfaces {
        shown.frames = max(shown.frames, len(surface.frames));
        shown.triangles += len(surface.indices) // 3;
        if len(surface.frames) > 0 {
            shown.vertices += len(surface.frames[0].vertices);
        }
    }
    if shown.frames == 0 {
        return False;
    }
    self.asset_now = AssetLook(game=game, name=name, kind="figure", note=words);
    self.model_now = shown;
    self.model_playing = False;
    box = shown.bounds(0);
    if from_eye {
        # As the player sees it: from where the model's own origin is, along x.
        self.model_yaw = 0.0;
        self.model_pitch = 0.0;
        self.model_reach = 32.0;
        self.model_middle = Vec3(x=32.0);
    } else {
        self.model_yaw = 0.6;
        self.model_pitch = -0.25;
        self.model_middle = box[0].add(box[1]).scale(0.5);
        self.model_reach = max(32.0, box[1].sub(box[0]).length() * 1.2);
    }
    self.set_frame(0);
    self.folds += 1;
    ui = self.ui;
    if ui is not None {
        self.show_asset(ui);
    }
    return True;
}

impl Studio.figure_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name != "ed_body" and name != "ed_viewweapon" {
        return False;
    }
    stock = self.archive;
    if stock is None {
        self.say("No game archives were found");
        return True;
    }
    if name == "ed_body" {
        character = args[1] if len(args) > 1 else "sarge";
        if character == "list" {
            known = self.asset_index;
            if known is None {
                known = AssetIndex(shelf=stock);
                self.asset_index = known;
            }
            found: list[str] = [];
            for path in known.names("q3") {
                parts = path.lower().split("/");
                if len(parts) == 4 and parts[0] == "models" and parts[1] == "players" and parts[3] == "lower.md3" {
                    found.append(parts[2]);
                }
            }
            print("studio: bodies " + " ".join(sorted(found)));
            self.say(str(len(found)) + " bodies: " + " ".join(sorted(found)) if len(found) > 0 else "Quake III's players were not found");
            return True;
        }
        held = "machinegun";
        legs_word = "idle";
        torso_word = "stand";
        place = 2;
        while place < len(args) {
            if args[place] == "legs" and place + 1 < len(args) {
                legs_word = args[place + 1];
                place += 2;
            } elif args[place] == "torso" and place + 1 < len(args) {
                torso_word = args[place + 1];
                place += 2;
            } else {
                held = args[place];
                place += 1;
            }
        }
        if legs_word not in LEGS_SEQUENCES or torso_word not in TORSO_SEQUENCES {
            self.say(
                "ed_body [character|list] [weapon|none] [legs " + "|".join(LEGS_SEQUENCES.keys()) + "] [torso "
                    + "|".join(TORSO_SEQUENCES.keys()) + "]"
            );
            return True;
        }
        try {
            library = stock.reader().catalog.source("q3");
            rig = character_rig(library, character);
            weapon: AnimatedModel | None = None;
            if held != "none" {
                weapon = library.model("models/weapons2/" + held + "/" + held + ".md3").model;
            }
            legs = clip_frames(rig.clips[LEGS_SEQUENCES[legs_word]]);
            torso = clip_frames(rig.clips[TORSO_SEQUENCES[torso_word]]);
            body = body_model(rig.lower.model, rig.upper.model, rig.head.model, weapon, legs, torso);
            label = "body/" + character + "/" + legs_word + "+" + torso_word + ("+" + held if held != "none" else "");
            said_of = character + ": legs " + legs_word + ", torso " + torso_word + (", holding a " + held if held != "none" else "");
            if not self.show_figure("q3", label, body, said_of, False) {
                self.say("That body has nothing to show");
                return True;
            }
            print(
                "studio: body " + character + " legs=" + legs_word + ":" + str(legs[0]) + "+" + str(len(legs)) + " torso="
                    + torso_word + ":" + str(torso[0]) + "+" + str(len(torso)) + " weapon=" + held + " surfaces="
                    + str(len(body.surfaces))
            );
            self.say("The body of " + said_of);
        } except Exception {
            self.say("ed_body: Quake III has no such body or weapon (" + character + ", " + held + "); ed_body list names the bodies");
        }
        return True;
    }
    game = args[1] if len(args) > 1 else "";
    if game not in ["q1", "q2", "q3"] {
        self.say("ed_viewweapon <q1|q2|q3> [slot] [out]: a game's weapon as it is held in view (from outside, with out)");
        return True;
    }
    rules = view_weapons(game);
    slot = int(args[2]) if len(args) > 2 and args[2].isdigit() else (rules[0].slot if len(rules) > 0 else -1);
    chosen: ViewWeaponRule | None = None;
    for rule in rules {
        if rule.slot == slot {
            chosen = rule;
        }
    }
    if chosen is None {
        print("studio: viewweapons " + game + " " + " ".join([str(rule.slot) for rule in rules]));
        self.say("ed_viewweapon " + game + ": the slots are " + " ".join([str(rule.slot) for rule in rules]));
        return True;
    }
    try {
        library = stock.reader().catalog.source(game);
        gun = library.model(chosen.model).model;
        hand: AnimatedModel | None = None;
        barrel: AnimatedModel | None = None;
        count = len(gun.surfaces[0].frames) if len(gun.surfaces) > 0 else 0;
        if chosen.hand {
            # As the engine's own view weapon does: a weapon with no hand of its own takes the shotgun's.
            hand_path = chosen.hand if library.exists(chosen.hand) else "models/weapons2/shotgun/shotgun_hand.md3";
            hand = library.model(hand_path).model;
            count = len(hand.tags);
            barrel_path = chosen.model[:-4] + "_barrel.md3";
            if library.exists(barrel_path) {
                barrel = library.model(barrel_path).model;
            }
        }
        frames = rule_frames(chosen, count);
        figure = held_model(gun, hand, frames, barrel);
        from_outside = len(args) > 3 and args[3] == "out";
        said_of = "as held in view: " + str(len(frames)) + " frames, at rest and through a shot"
            + (", on its hand" if hand is not None else "");
        if not self.show_figure(game, "held/" + chosen.model, figure, said_of, not from_outside) {
            self.say("That weapon has nothing to show");
            return True;
        }
        print(
            "studio: viewweapon " + game + " slot=" + str(chosen.slot) + " model=" + chosen.model + " frames=" + str(len(frames))
                + " hand=" + ("1" if hand is not None else "0") + " barrel=" + ("1" if barrel is not None else "0") + " surfaces="
                + str(len(figure.surfaces))
        );
        self.say(chosen.model + " " + said_of);
    } except Exception {
        self.say("ed_viewweapon: " + chosen.model + " could not be read");
    }
    return True;
}
