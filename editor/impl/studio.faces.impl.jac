"""The studio's edits by face: faces dropped and turned, brushes stood on
faces, side flags, detail and diggers. Declarations live in studio.jac."""

"""The contents bit that marks a brush as detail in Quake II and III."""
glob DETAIL_BIT: int = 134217728;

"""The numbers a command's words begin with (a form's field hands several
over as one word)."""
def:priv face_numbers(words: list[str]) -> list[float] {
    found: list[float] = [];
    for word in " ".join(words).split() {
        try {
            found.append(float(word));
        } except ValueError {
            return found;
        }
    }
    return found;
}

impl Studio.face_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name == "ed_face_delete" {
        count = scene.drop_faces();
        self.say(
            "Took " + str(count) + " faces off"
            if count
            else ("The brush does not close without that face" if scene.faces() else "Pick the faces to delete (2)")
        );
        return True;
    }
    if name == "ed_face_flip" {
        count = scene.flip_faces();
        self.say(
            "Turned " + str(count) + " faces round"
            if count
            else ("Nothing closes behind that face" if scene.faces() else "Pick one face of a brush to turn (2)")
        );
        return True;
    }
    if name == "ed_cone" or name == "ed_extrude" or name == "ed_walls" {
        sizes = face_numbers(args[1:]);
        size = sizes[0] if len(sizes) > 0 else 64.0;
        thick = sizes[1] if len(sizes) > 1 else 16.0;
        if size <= 0.0 or thick <= 0.0 {
            self.say(name + " [size]" + (" [thickness]" if name == "ed_walls" else ""));
            return True;
        }
        if not scene.faces() {
            self.say("Pick the faces to build on (2)");
            return True;
        }
        shape = "cone" if name == "ed_cone" else ("prism" if name == "ed_extrude" else "walls");
        count = scene.build_on_faces(shape, size, thick);
        if count > 0 {
            # What was made is selected, as brushes.
            self.mode = "brush";
        }
        self.say("Made " + str(count) + " brushes" if count else "Nothing could be stood on those faces");
        return True;
    }
    if name == "ed_sideflag" {
        keys = ["contents", "flags", "value"];
        if len(args) > 1 and args[1] == "all" {
            # The three at once, as the face's form has them.
            given = face_numbers(args[2:]);
            if len(given) < 3 {
                self.say("ed_sideflag all <contents> <flags> <value>");
                return True;
            }
            changed = 0;
            for index in range(3) {
                changed += scene.flag_sides(keys[index], int(given[index]), "put");
            }
            self.say("Changed " + str(changed) + " values" if changed else "They are as they were");
            return True;
        }
        number = face_numbers(args[2:3]);
        how = args[3] if len(args) > 3 else "set";
        if len(args) < 3 or args[1] not in keys or len(number) == 0 or how not in ["set", "clear", "put"] {
            self.say("ed_sideflag <contents|flags|value> <number> [set|clear|put]");
            return True;
        }
        count = scene.flag_sides(args[1], int(number[0]), how);
        self.say("Changed " + str(count) + " sides" if count else "No side changed (pick faces or select brushes)");
        return True;
    }
    if name == "ed_detail" {
        how = "set";
        if len(args) > 1 and args[1] in ["off", "0"] {
            how = "clear";
        }
        count = scene.flag_sides("contents", DETAIL_BIT, how);
        self.say(
            ("Detail: " if how == "set" else "Structural: ") + str(count) + " sides"
            if count
            else "Nothing selected changed"
        );
        return True;
    }
    if name == "ed_digger" {
        off = len(args) > 1 and args[1] in ["off", "0"];
        if scene.selected_solids() and not off {
            # Loose brushes become a group that digs.
            if scene.group_selection(scene.fresh_name("digger")) is None {
                self.say("Those brushes could not be grouped");
                return True;
            }
        }
        groups = [item for item in scene.selection() if item.classname() == "func_group"];
        if len(groups) == 0 {
            self.say("Select the brushes, or the group, that should be holes");
            return True;
        }
        scene.set_fields({DIGGER_KEY: None if off else "1"}, "Fill in" if off else "Dig");
        self.say(
            "Those brushes are solid again"
            if off
            else "Those brushes are holes: they cut what they touch when the level is built"
        );
        return True;
    }
    return False;
}
