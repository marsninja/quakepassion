"""Implementations for the App object: the game loop and its fly/render/smoke
steps. Declarations live in app.jac."""

impl App.run() {
    self.renderer.open_window();
    if self.level.active {
        self.quake.upload(self.level);
    }
    frame = 0;
    while not self.renderer.should_close() {
        dt = self.renderer.frame_time();
        intent = Intent() if self.smoke else sample_intent(dt);
        if intent.toggle_culling {
            self.culling = not self.culling;
        }
        if intent.toggle_overlay {
            self.overlay = not self.overlay;
        }

        ticks = self.clock.advance(dt);
        for i in range(ticks) {
            tp = self.world spawn ThinkPass(dt=self.clock.tick_rate);
            self.last_think = tp.entities_visited;
        }

        # phase-1 simplification: fly movement integrates per-frame for
        # smoothness; phase 3 moves real player physics into the ticks
        self.fly(intent, dt);
        self.render_frame();

        frame += 1;
        if self.smoke and self.smoke_step(frame) {
            break;
        }
    }
    if self.level.active {
        self.quake.close();
    }
    self.renderer.close();
}

impl App.fly(intent: Intent, dt: float) {
    p = self.player;
    p.yaw += intent.look_yaw;
    p.pitch += intent.look_pitch;
    if p.pitch > PITCH_LIMIT {
        p.pitch = PITCH_LIMIT;
    }
    if p.pitch < -PITCH_LIMIT {
        p.pitch = -PITCH_LIMIT;
    }

    fwd = forward_from(p.yaw, p.pitch);
    rgt = right_from(p.yaw);
    wish = fwd.scale(intent.move.y).add(rgt.scale(intent.move.x)).add(
        Vec3(z=intent.move.z)
    );
    if wish.length() > 0.001 {
        p.pos = p.pos.add(wish.normalized().scale(FLY_SPEED * dt));
    }

    # rewire the In edge when we cross into another area
    landed = self.level.areas[self.level.locate(p.pos)]
        if self.level.active
        else area_containing(self.world, p.pos);
    if landed is not None and landed is not area_of(p) {
        move_to_area(p, landed);
    }
}

impl App.render_frame() {
    p = self.player;
    if self.level.active {
        faces = self.level.visible(self.world, p.pos, self.culling);
        self.renderer.begin_frame(p.pos, p.yaw, p.pitch);
        self.last_drawn = self.quake.draw(self.level, faces, p.pos);
        self.renderer.end_scene();
        if self.overlay {
            self.renderer.draw_overlay(
                [
                    self.level.bsp.game.upper() + ": " + self.level.name,
                    "faces: "
                        + str(self.last_drawn)
                        + "/"
                        + str(len(self.level.bsp.faces)),
                    "BSP leaf: " + str(self.level.locate(p.pos)),
                    "PVS [C]: " + ("ON" if self.culling else "OFF"),
                    "WASD / Space / Shift: fly | Tab: mouse | F3: overlay"
                ]
            );
        }
        self.renderer.end_frame();
        return;
    }
    facing = forward_from(p.yaw, p.pitch);
    cur = area_of(p);
    all_areas = [self.world-->[?:Area]];

    if self.culling and cur is not None {
        vis = cur spawn VisPass(eye=p.pos, facing=facing);
        targets = vis.visible;
    } else {
        targets = all_areas;
    }

    self.renderer.begin_frame(p.pos, p.yaw, p.pitch);
    rp = self.world spawn RenderPass(targets=targets, renderer=self.renderer);
    self.last_drawn = rp.drawn;
    self.renderer.end_scene();

    if self.overlay {
        cur_name = cur.name if cur is not None else "the void";
        culling_state = "ON" if self.culling else "OFF";
        mouse_state = "captured [Tab releases]"
            if mouse_captured()
            else "free - click or Tab to look";
        self.renderer.draw_overlay(
            [
                "area: " + cur_name,
                "visible: " + str(len(targets)) + "/" + str(len(all_areas)) + " areas",
                "culling [C]: " + culling_state,
                "entities thinking: " + str(self.last_think),
                "mouse: " + mouse_state
            ]
        );
    }
    self.renderer.end_frame();
}

impl App.smoke_step(frame: int) -> bool {
    if self.level.active {
        if frame == 1 {
            self.overlay = False;
        }
        if frame == 40 {
            print(
                "PVS",
                self.level.name,
                "leaf",
                self.level.locate(self.player.pos),
                "faces",
                self.last_drawn
            );
            self.renderer.screenshot("qp_quake_pvs.png");
            self.culling = False;
        } elif frame == 80 {
            print("ALL", self.level.name, "faces", self.last_drawn);
            self.renderer.screenshot("qp_quake_all.png");
            self.player.yaw += 1.57079632679;
        } elif frame == 120 {
            self.renderer.screenshot("qp_quake_turn.png");
            self.player.yaw -= 1.57079632679;
            # Exercise the same free-flight integration used by WASD.
            self.fly(Intent(move=Vec3(y=1.0)), 2.0);
            self.culling = True;
        } elif frame == 160 {
            print(
                "MOVED",
                self.level.name,
                "leaf",
                self.level.locate(self.player.pos),
                "faces",
                self.last_drawn
            );
            self.renderer.screenshot("qp_quake_moved_pvs.png");
            self.culling = False;
        } elif frame == 200 {
            self.renderer.screenshot("qp_quake_moved_all.png");
            return True;
        }
        return False;
    }
    if frame == 40 {
        # facing the doorway: both rooms should be visible
        self.renderer.screenshot("qp_smoke_door.png");
        self.player.yaw = 3.14159;
    } elif frame == 80 {
        # facing away: culling should leave only the current room
        self.renderer.screenshot("qp_smoke_away.png");
        self.culling = False;
    } elif frame == 120 {
        # culling off: everything draws regardless of facing
        self.renderer.screenshot("qp_smoke_off.png");
        return True;
    }
    return False;
}
