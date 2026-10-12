"""The studio's overlays for brushes that are not walls: the volumes that
set things off, and the brushes a player never sees. Declarations live in
studio.jac."""

impl Studio.overlay_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_overlay" {
        return False;
    }
    what = args[1] if len(args) > 1 else "";
    word = args[2] if len(args) > 2 else "";
    if what in ["triggers", "unseen"] and word in ["", "on", "off"] {
        was = self.show_triggers if what == "triggers" else self.show_unseen;
        now = (not was) if not word else word == "on";
        if what == "triggers" {
            self.show_triggers = now;
        } else {
            self.show_unseen = now;
        }
        self.outline_solids(scene);
    } elif what {
        self.say("ed_overlay [triggers|unseen] [on|off]: outline trigger volumes, or clip, hint and caulk brushes, in colours of their own");
        return True;
    }
    # How many brushes there are of each kind, whether shown apart or not.
    counts = {"trigger": 0, "clip": 0, "hint": 0};
    for brush in scene.solids() {
        holder = scene.owner_of(brush);
        purpose = brush_kind(holder.classname() if holder is not None else "", [side.material for side in brush.sides]);
        if purpose in counts {
            counts[purpose] += 1;
        }
    }
    tinted = len([seen for seen in self.looks if seen.tint in [kind_tint("trigger"), kind_tint("clip"), kind_tint("hint")]]);
    print(
        "studio: overlay triggers=" + ("1" if self.show_triggers else "0") + " unseen=" + ("1" if self.show_unseen else "0")
            + " trigger=" + str(counts["trigger"]) + " clip=" + str(counts["clip"]) + " hint=" + str(counts["hint"]) + " outlined="
            + str(tinted)
    );
    self.say(
        str(counts["trigger"]) + " trigger volumes (" + ("shown in yellow" if self.show_triggers else "not shown apart") + "), "
            + str(counts["clip"] + counts["hint"]) + " clip and hint brushes ("
            + ("shown in magenta and blue" if self.show_unseen else "not shown apart") + ")"
    );
    return True;
}
