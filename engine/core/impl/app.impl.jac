"""Implementations for the App object: the game loop and its fly/render/smoke
steps. Declarations live in app.jac."""

impl App.run() {
    if not self.smoke {
        preferences = Preferences();
        try {
            preferences.load();
        } except Exception as error {
            self.notice = "Settings: " + str(error);
            self.notice_wait = 5.0;
        }
        self.renderer.fov = preferences.fov;
        self.renderer.frame_limit = preferences.frame_limit;
        self.sensitivity = preferences.sensitivity;
        self.invert_y = preferences.invert_y;
        self.god_mode = preferences.god_mode;
        self.player.god_mode = self.god_mode;
        self.fly_speed = preferences.fly_speed;
        self.culling = preferences.culling;
        self.overlay = preferences.overlay;
        self.audio.volume = preferences.volume;
        if self.level.active {
            self.audio.open(
                self.level.bsp.game,
                game_directory(self.level.bsp.game),
                weapon_sounds(self.level.bsp.game)
            );
        }
    }
    self.renderer.open_window();

    if self.level.active {
        equip_player(self.player, self.combat, self.level.bsp.game);
        populate_pickups(self.world, self.level, game_directory(self.level.bsp.game));
        populate_opponents(self.world, self.level, game_directory(self.level.bsp.game));
        self.models.upload(self.world);
        self.effects.upload(
            self.level.bsp.game,
            game_directory(self.level.bsp.game),
            weapon_effects(self.level.bsp.game)
        );
        self.viewweapon.upload(
            self.level.bsp.game,
            game_directory(self.level.bsp.game),
            view_weapons(self.level.bsp.game)
        );
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
        self.models.close();
        self.effects.close();
        self.viewweapon.close();
        self.quake.close();
    }
    self.audio.close();
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
    self.audio.update(self.world, p.pos, p.yaw, paused=self.menu.opened);
    if self.level.active {
        faces = self.level.visible(self.world, p.pos, self.culling);
        combat_lights(self.level.lighting, self.world, p, self.combat);
        self.renderer.begin_frame(p.pos, p.yaw, p.pitch);
        self.last_drawn = self.quake.draw(self.level, faces, p.pos);
        self.models.draw(
            self.world,
            p.pos,
            self.simulation_time,
            culling=self.culling,
            yaw=p.yaw,
            pitch=p.pitch,
            fov=self.renderer.fov,
            aspect=float(self.renderer.width) / float(self.renderer.height),
            lighting=self.level.lighting
        );
        self.renderer.draw_opponents(self.world, self.level.collision.eye_height);
        self.renderer.draw_projectiles(self.world, hidden_effects=self.effects.keys());
        self.effects.draw(
            self.world, p.pos, p.yaw, p.pitch, lighting=self.level.lighting
        );
        if not self.smoke {
            self.viewweapon.draw(
                p, self.combat, self.simulation_time, self.level.lighting
            );
        }
        self.renderer.end_scene();
        if not self.smoke {
            self.renderer.draw_status(
                p.health, p.armor, quantity(p.inventory, "shells")
            );
            rule = selected_weapon(self.combat);
            self.renderer.draw_combat(
                self.combat,
                self.level.bsp.game == "q3",
                ammo=quantity(p.inventory, rule.ammo) if rule.ammo else -1
            );
            self.renderer.draw_keys(
                " | ".join(
                    [
                        text
                        for text in [
                            key_summary(p.inventory),
                            progress_summary(self.world)
                        ]
                        if text
                    ]
                )
            );
            if self.level.bsp.game == "passion" {
                if self.notice_wait <= 0.0 {
                    self.renderer.draw_message(
                        "PASSION "
                            + self.level.name
                            + " | Find both keys, reach extraction"
                    );
                }
                if self.expedition_complete {
                    self.renderer.draw_terminal(
                        "Expedition complete! Enter: replay | Esc: new seed"
                    );
                }
            }
            if self.notice_wait > 0.0 {
                self.renderer.draw_message(self.notice);
            }
        }
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
    self.load_destination(
        self.menu.games[self.menu.game], self.menu.maps[self.menu.selected]
    );
}

impl App.load_destination(
    game: str,
    name: str,
    spawnpoint: str = "",
    carry: bool = False,
    saved: str = "",
    new_unit: bool = False,
    session: Campaign | None = None
) {
    if game == "passion" {
        self.renderer.draw_loading(name);
    }
    next_renderer = QuakeRenderer();
    next_models = ModelScene();
    next_effects = EffectScene();
    next_viewweapon = ViewWeapon();
    try {
        world = World();
        level = open_level(world, game_directory(game), name, game);
        player = spawn_player(level, spawnpoint);
        carrying = carry and self.player.health > 0 and game == self.level.bsp.game;
        if carrying {
            player.health = self.player.health;
            player.max_health = self.player.max_health;
            player.armor = self.player.armor;
            player.armor_capacity = self.player.armor_capacity;
            player.armor_ratio = self.player.armor_ratio;
            copied = self.player.inventory spawn CopyInventory(
                skip_keys=game == "q1" or new_unit
            );
            player.inventory = copied.result;
        }
        populate_pickups(world, level, game_directory(game));
        populate_opponents(world, level, game_directory(game));
        combat = CombatState();
        equip_player(player, combat, game, fresh=not carrying);
        if carrying {
            select_weapon(player, combat, self.combat.weapon);
            combat.cooldown = self.combat.cooldown;
            combat.random_state = self.combat.random_state;
            combat.grenade_phase = self.combat.grenade_phase;
            combat.grenade_clock = self.combat.grenade_clock;
            combat.grenade_remaining = self.combat.grenade_remaining;
            if combat.grenade_phase > 0 {
                combat.weapon = self.combat.weapon;
            }
        }
        next_campaign = session
            if session is not None
            else (
                self.campaign
                    if carry
                        and game == "q2"
                        and self.level.bsp.game == "q2"
                        and not new_unit
                    else Campaign()
            );
        departed = "";
        if carry and game == "q2" and self.level.bsp.game == "q2" and not new_unit {
            departed = snapshot(self.world, self.level, self.player, self.combat);
            recalled = next_campaign spawn Recall(name=name);
            if recalled.data {
                height = level.collision.eye_height;
                top = level.collision.top_drop;
                restore(world, level, Player(), CombatState(), recalled.data);
                level.collision.eye_height = height;
                level.collision.top_drop = top;
            }
        }
        if saved {
            restore(world, level, player, combat, saved);
        }
        next_models.upload(world);
        next_effects.upload(game, game_directory(game), weapon_effects(game));
        next_viewweapon.upload(game, game_directory(game), view_weapons(game));
        next_renderer.upload(level);
        if self.level.active {
            self.models.close();
            self.effects.close();
            self.viewweapon.close();
            self.quake.close();
        }
        if departed {
            next_campaign spawn Remember(name=self.level.name, data=departed);
        }
        self.campaign = next_campaign;
        self.world = world;
        self.level = level;
        self.player = player;
        self.player.god_mode = self.god_mode;
        self.quake = next_renderer;
        self.models = next_models;
        self.effects = next_effects;
        self.viewweapon = next_viewweapon;
        if self.audio.ready {
            self.audio.close();
            try {
                self.audio.open(game, game_directory(game), weapon_sounds(game));
            } except Exception as error {
                self.notice = "Audio: " + str(error);
                self.notice_wait = 4.0;
                self.audio.close();
            }
        }
        self.simulation_time = 0.0;
        self.combat = combat;
        self.expedition_complete = level.completion.pending > 0;
        self.clock = Clock();
        self.skip_time = True;
        self.walking = False;
        self.jump_pending = False;
        self.physics_clock.accumulator = 0.0;
        self.movement_status = "F4: walk / fly";
        if saved {
            self.walking = True;
            self.movement_status = "WALK | F4: fly";
        } elif not self.smoke {
            self.toggle_movement();
        }
        self.menu.opened = False;
        if self.menu.restore_mouse {
            _capture();
        }
    } except Exception as error {
        next_models.close();
        next_effects.close();
        next_viewweapon.close();
        next_renderer.close();
        self.menu.message = "Cannot load level: " + str(error);
        self.menu.opened = True;
        _release();
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
            for i in range(len(self.menu.games)) {
                if self.menu.games[i] == self.level.bsp.game {
                    self.menu.game = i;
                }
            }
            self.menu.scan();
            if self.level.bsp.game == "passion"
                and self.level.name not in self.menu.maps {
                self.menu.maps = [self.level.name] + self.menu.maps;
            }
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
    if self.level.active and not self.smoke {
        if IsKeyPressed(i32(294)) {
            self.quicksave();
        }
        if IsKeyPressed(i32(298)) {
            self.quickload();
            self.render_frame();
            return True;
        }
    }
    if self.level.active
        and (
            self.player.health <= 0
            or self.expedition_complete
            or (self.level.bsp.game == "q3" and self.combat.kills >= 10)
        ) {
        self.jump_pending = False;
        self.physics_clock.accumulator = 0.0;
        if IsKeyPressed(i32(257)) {
            self.load_destination(
                self.level.bsp.game, self.level.name, session=self.campaign
            );
        }
        self.render_frame();
        return True;
    }
    intent = Intent()
        if self.smoke
        else sample_intent(dt, self.sensitivity, self.invert_y);
    if intent.weapon > 0 {
        select_weapon(self.player, self.combat, intent.weapon);
    }
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
        self.simulation_time += self.physics_clock.tick_rate;
        self.notice_wait = max(0.0, self.notice_wait - self.physics_clock.tick_rate);
        if self.walking and self.level.active {
            self.player spawn SetStance(
                collision=self.level.collision,
                game=self.level.bsp.game,
                crouch=intent.crouch,
                dt=self.physics_clock.tick_rate
            );
        }
        previous_origin = self.player.pos.sub(Vec3(z=self.level.collision.eye_height));
        if self.level.active and not self.smoke {
            events = self.world spawn SignalTick(dt=self.physics_clock.tick_rate);
            self.world spawn SpeakerTick();
            self.world spawn BrushTick(
                bsp=self.level.bsp,
                collision=self.level.collision,
                player=self.player,
                state=self.combat
            );
            if events.message {
                self.notice = events.message;
                self.notice_wait = 3.0;
            }
            self.world spawn TrainTick(
                bsp=self.level.bsp,
                collision=self.level.collision,
                dt=self.physics_clock.tick_rate,
                player=self.player if self.walking else None
            );
            doors = self.world spawn DoorTick(
                bsp=self.level.bsp,
                collision=self.level.collision,
                player_origin=self.player.pos.sub(
                    Vec3(z=self.level.collision.eye_height)
                ),
                dt=self.physics_clock.tick_rate,
                touching=self.walking,
                player=self.player if self.walking else None
            );
            if doors.message {
                self.notice = doors.message;
                self.notice_wait = 3.0;
            }
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
            immersed = self.level.immersion(self.player.pos);
            self.player.water_depth = immersed.depth;
            self.player.liquid_kind = immersed.kind;
            self.player spawn EnvironmentTick(
                game=self.level.bsp.game,
                dt=self.physics_clock.tick_rate,
                active=self.walking
            );
            if self.player.health <= 0 {
                self.player.velocity = Vec3();
                self.jump_pending = False;
                break;
            }
            old_health = self.player.health;
            self.world spawn CombatTick(
                player=self.player,
                collision=self.level.collision,
                state=self.combat,
                dt=self.physics_clock.tick_rate,
                active=self.walking
            );
            if self.player.health < old_health {
                self.audio.play(1);
            }
            if weapon_input(
                self.world,
                self.player,
                self.level.collision,
                self.combat,
                held=intent.fire,
                dt=self.physics_clock.tick_rate
            ) {
                self.audio.play(2 + self.combat.weapon if self.combat.rules else 0);
            }
            self.world spawn ProjectileTick(
                player=self.player,
                collision=self.level.collision,
                state=self.combat,
                dt=self.physics_clock.tick_rate
            );
            for impact in self.combat.impacts {
                if impact.model >= 0 {
                    self.world spawn ShootMover(
                        model=impact.model, amount=impact.amount
                    );
                    self.world spawn ShootBrush(
                        model=impact.model,
                        amount=impact.amount,
                        bsp=self.level.bsp,
                        collision=self.level.collision,
                        player=self.player,
                        state=self.combat
                    );
                }
                if impact.splash > 0 {
                    self.world spawn BlastMover(
                        origin=impact.origin,
                        amount=impact.splash,
                        radius=impact.radius,
                        game=self.level.bsp.game,
                        collision=self.level.collision,
                        player=self.player,
                        energy_burst=impact.energy_burst
                    );
                    self.world spawn BlastBrush(
                        origin=impact.origin,
                        amount=impact.splash,
                        radius=impact.radius,
                        energy_burst=impact.energy_burst,
                        bsp=self.level.bsp,
                        collision=self.level.collision,
                        player=self.player,
                        state=self.combat
                    );
                }
            }
            self.combat.impacts = [];
            pickup_result = self.world spawn PickupTick(
                player=self.player,
                start=previous_origin,
                finish=self.player.pos.sub(Vec3(z=self.level.collision.eye_height)),
                dt=self.physics_clock.tick_rate,
                top_drop=self.level.collision.top_drop,
                touching=self.walking
            );
            if pickup_result.collected > 0 {
                self.audio.play(2);
            }
            triggers = self.world spawn TriggerTick(
                player=self.player,
                start=previous_origin,
                finish=self.player.pos.sub(Vec3(z=self.level.collision.eye_height)),
                dt=self.physics_clock.tick_rate,
                top_drop=self.level.collision.top_drop,
                touching=self.walking
            );
            if triggers.message {
                self.notice = triggers.message;
                self.notice_wait = 3.0;
            }
            self.world spawn HazardTick(
                player=self.player,
                start=previous_origin,
                eye_height=self.level.collision.eye_height,
                finish=self.player.pos.sub(Vec3(z=self.level.collision.eye_height)),
                dt=self.physics_clock.tick_rate,
                top_drop=self.level.collision.top_drop,
                touching=self.walking
            );
            exit_request = self.world spawn ExitTick(
                start=previous_origin,
                finish=self.player.pos.sub(Vec3(z=self.level.collision.eye_height)),
                dt=self.physics_clock.tick_rate,
                touching=self.walking
            );
            if exit_request.request {
                if self.level.bsp.game == "passion"
                    and exit_request.request == "passion_complete" {
                    self.expedition_complete = True;
                    self.level.completion.pending = 1;
                    break;
                }
                self.load_destination(
                    self.level.bsp.game,
                    exit_map(exit_request.request),
                    exit_spawn(exit_request.request),
                    carry=True,
                    new_unit=exit_request.request.startswith("*")
                );
                break;
            }
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
        "Diagnostic overlay: " + ("On" if self.overlay else "Off"),
        "Sound volume: " + str(int(self.audio.volume * 100.0)) + "%",
        "God mode: " + ("On" if self.god_mode else "Off")
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
    } elif row == 8 {
        self.audio.volume = max(
            0.0, min(1.0, self.audio.volume + float(direction) * 0.05)
        );
    } elif row == 9 {
        self.god_mode = not self.god_mode;
        self.player.god_mode = self.god_mode;
    }
    self.save_preferences();
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
    self.god_mode = False;
    self.player.god_mode = False;
    self.fly_speed = 240.0;
    self.culling = True;
    self.overlay = True;
    self.audio.volume = 0.25;
    self.save_preferences();
}

impl App.quicksave() {
    if self.player.health <= 0 or not self.walking {
        self.notice = "Save while alive in walk mode";
    } else {
        try {
            write_save(
                (self.save_path or os.getenv("HOME", ".") + "/.quakepassion-save.txt"),
                pack_campaign(
                    self.campaign,
                    snapshot(self.world, self.level, self.player, self.combat)
                )
            );
            self.notice = "Saved - F9 to load";
        } except Exception as error {
            self.notice = "Save failed: " + str(error);
        }
    }
    self.notice_wait = 4.0;
}

impl App.quickload() {
    try {
        data = read_save(
            (self.save_path or os.getenv("HOME", ".") + "/.quakepassion-save.txt")
        );
        session = unpack_campaign(data);
        data = session.active;
        lines = data.splitlines();
        if len(lines) < 4
            or lines[0] != SNAPSHOT_HEADER
            or lines[1] not in ["q1", "q2", "q3", "passion"] {
            raise ValueError("Invalid save header");
        }
        self.load_destination(
            lines[1], exit_map(lines[2]), saved=data, session=session
        );
        self.notice = "Loaded" if not self.menu.opened else self.menu.message;
    } except Exception as error {
        self.notice = "Load failed: " + str(error);
    }
    self.notice_wait = 4.0;
}

impl App.save_preferences() {
    try {
        Preferences(
            fov=self.renderer.fov,
            sensitivity=self.sensitivity,
            invert_y=self.invert_y,
            fly_speed=self.fly_speed,
            frame_limit=self.renderer.frame_limit,
            culling=self.culling,
            overlay=self.overlay,
            volume=self.audio.volume,
            god_mode=self.god_mode
        ).save();
        self.menu.message = "Settings saved";
    } except Exception as error {
        self.menu.message = "Settings save failed: " + str(error);
    }
}
