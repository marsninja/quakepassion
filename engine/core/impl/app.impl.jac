"""Implementations for the App object: the game loop and its fly/render/smoke
steps. Declarations live in app.jac."""

impl App.run() {
    self.renderer.open_window();
    if self.level.active {
        self.quake.upload(self.level);
    }
    frame = 0;
    while not self.renderer.should_close() {
        if not self.step() {
            break;
        }

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
        p.pos = p.pos.add(wish.normalized().scale(self.fly_speed * dt));
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
    if self.menu.opened {
        self.refresh_settings();
    }
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
                    (
                        "WASD: walk | Space: jump"
                            if self.walking
                            else "WASD / Space / Shift: fly"
                    )
                        + " | Tab: mouse | F3: overlay",
                    self.movement_status
                ]
            );
        }
        if self.menu.opened {
            self.menu.draw();
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
    if self.menu.opened {
        self.menu.draw();
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

impl App.switch_level() {
    next_renderer = QuakeRenderer();
    try {
        game = self.menu.games[self.menu.game];
        world = World();
        level = load_level(
            world, game_directory(game), self.menu.maps[self.menu.selected], game
        );
        player = spawn_player(level);
        next_renderer.upload(level);
        if self.level.active {
            self.quake.close();
        }
        self.world = world;
        self.level = level;
        self.player = player;
        self.quake = next_renderer;
        self.clock = Clock();
        self.skip_time = True;
        self.walking = False;
        self.jump_pending = False;
        self.physics_clock.accumulator = 0.0;
        self.movement_status = "F4: walk / fly";
        if not self.smoke {
            self.toggle_movement();
        }
        self.menu.opened = False;
        if self.menu.restore_mouse {
            _capture();
        }
    } except Exception as error {
        next_renderer.close();
        self.menu.message = "Cannot load level: " + str(error);
    }
}

impl App.step() -> bool {
    dt = 0.0 if self.skip_time else self.renderer.frame_time();
    self.skip_time = False;
    if not self.smoke and IsKeyPressed(i32(256)) {
        self.menu.opened = not self.menu.opened;
        if self.menu.opened {
            self.jump_pending = False;
            self.physics_clock.accumulator = 0.0;
            self.menu.restore_mouse = mouse_captured();
            _release();
            for i in range(3) {
                if self.menu.games[i] == self.level.bsp.game {
                    self.menu.game = i;
                }
            }
            self.menu.scan();
            for i in range(len(self.menu.maps)) {
                if self.menu.maps[i] == self.level.name {
                    self.menu.selected = i;
                    self.menu.offset = max(0, min(i, len(self.menu.maps) - 11));
                }
            }
        } elif self.menu.restore_mouse {
            _capture();
        }
        self.render_frame();
        return True;
    }
    if self.menu.opened {
        action = self.menu.update();
        if action == "quit" {
            return False;
        }
        if action == "setting_left" or action == "setting_right" {
            self.adjust_setting(-1 if action == "setting_left" else 1);
        }
        if action == "settings_reset" {
            self.reset_settings();
        }
        if action == "load" {
            self.switch_level();
        }
        self.render_frame();
        return True;
    }
    intent = Intent()
        if self.smoke
        else sample_intent(dt, self.sensitivity, self.invert_y);
    if intent.toggle_culling {
        self.culling = not self.culling;
    }
    if intent.toggle_overlay {
        self.overlay = not self.overlay;
    }

    if intent.toggle_walk {
        self.toggle_movement();
    }
    ticks = self.clock.advance(dt);
    for i in range(ticks) {
        tp = self.world spawn ThinkPass(dt=self.clock.tick_rate);
        self.last_think = tp.entities_visited;
    }

    if self.walking {
        self.fly(intent, 0.0);
        self.jump_pending = self.jump_pending or intent.jump;
    }
    steps = self.physics_clock.advance(min(dt, 0.25));
    wish = forward_from(self.player.yaw, 0.0).scale(intent.move.y).add(
        right_from(self.player.yaw).scale(intent.move.x)
    );
    for i in range(steps) {
        previous_origin = self.player.pos.sub(Vec3(z=self.level.collision.eye_height));
        if self.level.active and not self.smoke {
            self.world spawn DoorTick(
                bsp=self.level.bsp,
                collision=self.level.collision,
                player_origin=self.player.pos.sub(
                    Vec3(z=self.level.collision.eye_height)
                ),
                dt=self.physics_clock.tick_rate,
                touching=self.walking,
                player=self.player if self.walking else None
            );
        }
        if self.walking {
            immersed = self.level.immersion(self.player.pos);
            self.player.water_depth = immersed.depth;
            self.player.liquid_kind = immersed.kind;
            swim = forward_from(self.player.yaw, self.player.pitch).scale(
                intent.move.y
            ).add(
                right_from(self.player.yaw).scale(intent.move.x)
            ).add(
                Vec3(z=intent.move.z)
            );
            self.player spawn MovePlayer(
                collision=self.level.collision,
                wish=wish,
                jump=self.jump_pending,
                water_depth=immersed.depth,
                swim_wish=swim,
                dt=self.physics_clock.tick_rate
            );
            self.jump_pending = False;
        }
        if self.level.active and not self.smoke {
            self.world spawn TriggerTick(
                start=previous_origin,
                finish=self.player.pos.sub(Vec3(z=self.level.collision.eye_height)),
                dt=self.physics_clock.tick_rate,
                touching=self.walking
            );
            self.world spawn TraversalTick(
                player=self.player,
                collision=self.level.collision,
                start=previous_origin,
                dt=self.physics_clock.tick_rate,
                touching=self.walking
            );
        }
    }
    if self.walking {
        immersed = self.level.immersion(self.player.pos);
        self.player.water_depth = immersed.depth;
        self.player.liquid_kind = immersed.kind;
        self.fly(Intent(), 0.0);
    } else {
        self.fly(intent, dt);
    }
    self.render_frame();
    return True;
}

impl App.toggle_movement() {
    if self.walking {
        self.walking = False;
        self.movement_status = "FLY | F4: walk";
    } elif not self.level.active or not self.level.collision.hulls {
        self.movement_status = "Walking needs a loaded collision map | F4";
    } else {
        origin = self.player.pos.sub(Vec3(z=self.level.collision.eye_height));
        if self.level.collision.trace(origin, origin).start_solid {
            self.movement_status = "Fly into open space before enabling walking | F4";
            return;
        }
        self.walking = True;
        self.movement_status = "WALK | F4: fly | proximity doors active";
    }
    self.player.velocity = Vec3();
    self.player.grounded = False;
    self.jump_pending = False;
    self.physics_clock.accumulator = 0.0;
}

impl App.refresh_settings() {
    self.menu.settings_labels = [
        "Movement: " + ("Walk" if self.walking else "Fly"),
        "Field of view (vertical): " + str(int(self.renderer.fov)),
        "Mouse sensitivity: " + str(int(self.sensitivity / 0.0022 * 100.0 + 0.5)) + "%",
        "Invert mouse Y: " + ("On" if self.invert_y else "Off"),
        "Fly speed: " + str(int(self.fly_speed)),
        "Frame limit: "
            + (
                str(self.renderer.frame_limit)
                    if self.renderer.frame_limit > 0
                    else "Uncapped"
            ),
        "Visibility culling: " + ("On" if self.culling else "Off"),
        "Diagnostic overlay: " + ("On" if self.overlay else "Off")
    ];
}

impl App.adjust_setting(direction: int) {
    row = self.menu.setting_selected;
    self.menu.message = "";
    if row == 0 {
        self.toggle_movement();
        self.menu.message = self.movement_status;
    } elif row == 1 {
        self.renderer.fov = max(
            40.0, min(110.0, self.renderer.fov + float(direction) * 2.0)
        );
    } elif row == 2 {
        self.sensitivity = max(
            0.00022, min(0.011, self.sensitivity + float(direction) * 0.00022)
        );
    } elif row == 3 {
        self.invert_y = not self.invert_y;
    } elif row == 4 {
        self.fly_speed = max(
            60.0, min(1920.0, self.fly_speed + float(direction) * 60.0)
        );
    } elif row == 5 {
        limits = [0, 30, 60, 120, 144, 240];
        index = 0;
        for i in range(len(limits)) {
            if limits[i] == self.renderer.frame_limit {
                index = i;
            }
        }
        self.renderer.set_frame_limit(
            limits[(index + direction + len(limits)) % len(limits)]
        );
    } elif row == 6 {
        self.culling = not self.culling;
    } elif row == 7 {
        self.overlay = not self.overlay;
    }
}

impl App.reset_settings() {
    self.menu.message = "";
    if not self.walking {
        self.toggle_movement();
    }
    self.renderer.fov = 72.0;
    self.renderer.set_frame_limit(0);
    self.sensitivity = 0.0022;
    self.invert_y = False;
    self.fly_speed = 240.0;
    self.culling = True;
    self.overlay = True;
}
