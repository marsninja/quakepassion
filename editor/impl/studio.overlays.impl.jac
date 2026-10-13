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
    } elif what == "overdraw" {
        self.overdraw = (not self.overdraw) if word not in ["on", "off"] else word == "on";
        print("studio: overlay overdraw=" + ("1" if self.overdraw else "0"));
        self.say(
            "The 3D view shows how many faces the renderer draws over each place: the brighter, the more"
            if self.overdraw
            else "The 3D view shows the level"
        );
        return True;
    } elif what in ["portals", "leaves"] and word in ["", "on", "off"] {
        # A bake's portal and leaf outlines (ed_portals, ed_cells).
        if what == "portals" {
            self.portals_command(scene, ["ed_portals"] + ([word] if word else []));
        } else {
            self.step_command(scene, ["ed_cells"] + ([word] if word else []));
        }
        return True;
    } elif what == "width" {
        if not word.isdigit() or int(word) < 1 or int(word) > WIDEST_LINE {
            self.say("ed_overlay width <1.." + str(WIDEST_LINE) + ">: how many pixels wide the studio's lines are drawn (now " + str(self.line_width) + ")");
            return True;
        }
        self.line_width = int(word);
        self.keep_settings();
        print("studio: overlay width=" + str(self.line_width));
        self.say("Lines are drawn " + str(self.line_width) + " wide");
        return True;
    } elif what {
        self.say("ed_overlay [triggers|unseen|portals|leaves] [on|off] | width <1.." + str(WIDEST_LINE) + ">: outline trigger volumes, or clip, hint and caulk brushes, in colours of their own, or a bake's portals or leaves; or how wide lines are drawn");
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

impl Studio.draw_overdraw(view: SceneView) -> int {
    app = self.app;
    if app is None {
        return 0;
    }
    faces = app.level.visible(app.world, view.eye, app.culling());
    bsp = app.level.bsp;
    rlDrawRenderBatchActive();
    rlDisableDepthTest();
    rlDisableBackfaceCulling();
    # Additive: each face adds a little of the colour where it lies.
    BeginBlendMode(i32(1));
    rlSetTexture(u32(0));
    rlBegin(i32(4));
    drawn = 0;
    for index in faces {
        if index < 0 or index >= len(bsp.faces) {
            continue;
        }
        corners = bsp.faces[index].vertices;
        if len(corners) < 3 {
            continue;
        }
        drawn += 1;
        for k in range(1, len(corners) - 1) {
            for spot in [corners[0], corners[k], corners[k + 1]] {
                rlColor4ub(u8(46), u8(22), u8(8), u8(255));
                rlVertex3f(f32(spot.x), f32(spot.y), f32(spot.z));
            }
        }
    }
    rlEnd();
    rlDrawRenderBatchActive();
    EndBlendMode();
    rlEnableBackfaceCulling();
    rlEnableDepthTest();
    return drawn;
}
