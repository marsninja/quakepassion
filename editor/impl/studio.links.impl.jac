"""Faces linked to stay in one plane, two brushes cut to meet in a seam,
and corners merged. Declarations live in studio.jac."""

"""The numbers among a command's words, as far as they all are numbers."""
def:priv link_numbers(words: list[str]) -> list[float] {
    found: list[float] = [];
    for word in words {
        try {
            found.append(float(word));
        } except ValueError {
            return found;
        }
    }
    return found;
}

impl Studio.links_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    how = args[1] if len(args) > 1 else "";
    if name == "ed_facelink" {
        picked = scene.faces();
        brushes = scene.selected_solids();
        for item in scene.selection() {
            for solid in scene.solids_of(item) {
                brushes.append(solid);
            }
        }
        count = 0;
        if how == "clear" {
            # The picked faces, or every side of the selected brushes.
            for chosen_face in picked {
                count += scene.unlink_side(chosen_face.solid, chosen_face.side);
            }
            if len(picked) == 0 {
                for solid in brushes {
                    for index in range(len(solid.sides)) {
                        count += scene.unlink_side(solid, index);
                    }
                }
            }
            self.say("Took " + str(count) + " links away" if count else "Nothing picked or selected is linked");
        } elif how {
            self.say("ed_facelink [clear]: link the picked faces, or the selected brushes' faces that lie in one plane");
            return True;
        } elif len(picked) >= 2 {
            count = scene.link_faces();
            self.say(
                "Linked " + str(count) + " faces to the first picked: pushed, they go together"
                if count
                else "Those faces do not lie in one plane with the first picked (or are linked already)"
            );
        } elif len(brushes) >= 2 {
            count = scene.link_coplanar(brushes);
            self.say(
                "Linked " + str(count) + " pairs of faces that lie in one plane" if count else "No two of those brushes have faces in one plane, facing one way"
            );
        } else {
            self.say("Pick two or more faces, or select two or more brushes, to link");
            return True;
        }
        print("studio: linked " + str(count) + " total=" + str(scene.link_count()));
        return True;
    }
    if name == "ed_carve" and how == "link" {
        # Cut, and the faces the cut left in pieces stay one face.
        before = scene.solids();
        shapes_before = [solid.sides for solid in before];
        made = scene.carve_selection();
        if made == 0 {
            self.say("Select the brushes to cut out of the others");
            return True;
        }
        # The pieces: brushes that are new, and brushes the cut reshaped.
        pieces: list[Solid] = [];
        for solid in scene.solids() {
            fresh = True;
            for (place, old) in enumerate(before) {
                if old is solid and solid.sides is shapes_before[place] {
                    fresh = False;
                }
            }
            if fresh {
                pieces.append(solid);
            }
        }
        count = scene.link_coplanar(pieces);
        print("studio: carved pieces=" + str(len(pieces)) + " linked=" + str(count) + " total=" + str(scene.link_count()));
        self.say("Carved into " + str(len(pieces)) + " pieces, with " + str(count) + " links between faces the cut divided");
        return True;
    }
    if name == "ed_glue" and how == "face" and len(args) > 2 and args[2] == "link" {
        plane = self.tagged;
        picked = scene.faces();
        if plane is None or len(picked) != 1 {
            self.say("Tag a face (ed_tag) and pick one other to put in its plane and link to it");
            return True;
        }
        # In the plane first (it may be there already), then tied to what lies in it.
        scene.glue_face(plane);
        count = 0;
        for solid in scene.solids() {
            if solid is picked[0].solid {
                continue;
            }
            there = scene.side_in(solid, plane);
            if there >= 0 and solid.sides[there].plane.normal.dot(plane.normal) > 0.0
                and scene.link_sides(picked[0].solid, picked[0].side, solid, there) {
                count += 1;
            }
        }
        print("studio: linked " + str(count) + " total=" + str(scene.link_count()));
        self.say("In the plane of " + self.tagged_words + " and linked to " + str(count) + " faces there" if count else "In the plane, with nothing there to link to");
        return True;
    }
    if name == "ed_miter" {
        if not scene.miter_selection() {
            self.say("Select two brushes that overlap where they are to meet: each is cut on the plane that halves the angle between them");
        } else {
            self.say("The two meet in a seam now");
        }
        return True;
    }
    if name == "ed_merge" {
        spots = link_numbers(args[1:]);
        chosen = scene.selected_solids();
        if len(chosen) != 1 or len(spots) != 6 {
            self.say("ed_merge <x y z> <x y z>: move a corner of the one selected brush onto another of its corners");
            return True;
        }
        if not scene.merge_corners(
            chosen[0], Vec3(x=spots[0], y=spots[1], z=spots[2]), Vec3(x=spots[3], y=spots[4], z=spots[5])
        ) {
            self.say("That brush has no corner there, or nothing would be left of it");
        } else {
            self.say("One corner where two were");
        }
        return True;
    }
    return False;
}
