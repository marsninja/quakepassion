"""What clicks pick, and editing kept to the selection. Declarations live in
studio.jac."""

impl Studio.restrict_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_pickmode" {
        word = args[1] if len(args) > 1 else "";
        if word not in ["all", "brushes", "entities"] {
            self.say("ed_pickmode <all|brushes|entities>: what a click in a view picks (" + self.pick_kind + " now)");
            return True;
        }
        self.pick_kind = word;
        self.say(
            "A click picks brushes and entities" if word == "all"
            else ("A click picks brushes, and passes entities" if word == "brushes" else "A click picks entities, and passes brushes")
        );
        return True;
    }
    if name != "ed_restrict" {
        return False;
    }
    word = args[1] if len(args) > 1 else ("off" if len(self.kept_out_items) + len(self.kept_out_solids) > 0 else "on");
    if word == "on" {
        if len(self.kept_out_items) + len(self.kept_out_solids) > 0 {
            self.say("Editing is kept to a selection already (ed_restrict off)");
            return True;
        }
        hidden_items = [item for item in scene.items() if item.hidden];
        hidden_solids = [solid for solid in scene.solids() if solid.hidden];
        if scene.hide_others() == 0 {
            self.say("Select what to keep editing first");
            return True;
        }
        # What this hid, and nothing that was hidden before, comes back when it is let go.
        self.kept_out_items = [item for item in scene.items() if item.hidden and item not in hidden_items];
        self.kept_out_solids = [solid for solid in scene.solids() if solid.hidden and solid not in hidden_solids];
        self.say(
            "Editing is kept to the selection: " + str(len(self.kept_out_items) + len(self.kept_out_solids))
                + " other things are put away (ed_restrict off)"
        );
        return True;
    }
    if word == "off" {
        back = 0;
        for item in self.kept_out_items {
            if item.hidden {
                item.hidden = False;
                back += 1;
            }
        }
        for solid in self.kept_out_solids {
            if solid.hidden {
                solid.hidden = False;
                back += 1;
            }
        }
        self.kept_out_items = [];
        self.kept_out_solids = [];
        if back > 0 {
            scene.geometry += 1;
            scene.revision += 1;
        }
        self.say("Brought back " + str(back) if back > 0 else "Editing was not kept to a selection");
        return True;
    }
    self.say("ed_restrict [on|off]");
    return True;
}
