"""Faces laid through whole points again, and tilted to whole angles.
Declarations live in studio.jac."""

impl Studio.integral_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    if name != "ed_integral" and name != "ed_faceangle" {
        return False;
    }
    amount = 1.0 if name == "ed_integral" else max(1.0, self.angle_snap);
    if len(args) > 1 {
        try {
            amount = max(0.125, float(args[1]));
        } except ValueError {
            self.say("ed_integral [grid] | ed_faceangle [degrees]");
            return True;
        }
    }
    # The picked faces; or, to put a brush through whole points, every face of the selected brushes.
    brushes: list[Solid] = [];
    faces_of: list[list[int]] = [];
    for face in scene.faces() {
        if face.solid not in brushes {
            brushes.append(face.solid);
            faces_of.append([]);
        }
        faces_of[brushes.index(face.solid)].append(face.side);
    }
    if len(brushes) == 0 and name == "ed_integral" {
        whole = scene.selected_solids();
        for item in scene.selection() {
            for owned in scene.solids_of(item) {
                if owned not in whole {
                    whole.append(owned);
                }
            }
        }
        for solid in whole {
            brushes.append(solid);
            faces_of.append(list(range(len(solid.sides))));
        }
    }
    if len(brushes) == 0 {
        self.say(
            "Pick the faces to put through whole points (or select brushes, for all of theirs)" if name == "ed_integral"
            else "Pick the faces to tilt to whole angles"
        );
        return True;
    }
    changed = 0;
    refused = 0;
    worst = 0.0;
    for (place, solid) in enumerate(brushes) {
        if name == "ed_integral" {
            worst = max(worst, faces_astray(solid.sides, faces_of[place], amount));
        }
        fresh = sides_integral(solid.sides, faces_of[place], amount) if name == "ed_integral"
            else sides_angled(solid.sides, faces_of[place], amount);
        moved_faces = len([index for index in range(len(fresh)) if fresh[index] is not solid.sides[index]]);
        if moved_faces == 0 {
            continue;
        }
        if scene.reshape(solid, fresh, "Whole points" if name == "ed_integral" else "Whole angles") {
            changed += moved_faces;
        } else {
            refused += 1;
        }
    }
    if name == "ed_integral" {
        print("studio: integral faces=" + str(changed) + " astray=" + str(round(worst, 3)) + " refused=" + str(refused));
        self.say(
            "Laid " + str(changed) + " faces through whole points" if changed > 0
            else ("Those faces are on whole points already" if refused == 0 else "That would leave a brush with no inside")
        );
    } else {
        print("studio: faceangle faces=" + str(changed) + " step=" + str(round(amount, 2)) + " refused=" + str(refused));
        self.say(
            "Tilted " + str(changed) + " faces to whole steps of " + str(round(amount, 1)) + " degrees" if changed > 0
            else ("Those faces stand at whole angles already" if refused == 0 else "That would leave a brush with no inside")
        );
    }
    return True;
}
