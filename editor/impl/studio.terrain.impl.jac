"""The studio's terrain: making one, the sculpting brush, and heights as
grey images. Declarations live in studio.jac."""

"""The numbers among a terrain command's words."""
def:priv terrain_numbers(words: list[str]) -> list[float] {
    found: list[float] = [];
    for word in words {
        try {
            found.append(float(word));
        } except ValueError {
            continue;
        }
    }
    return found;
}

impl Studio.terrain_now(scene: Scene) -> Item | None {
    for item in scene.selection() {
        if scene.terrain_grid(item) is not None {
            return item;
        }
    }
    found: Item | None = None;
    count = 0;
    for item in scene.items() {
        if scene.terrain_grid(item) is not None {
            found = item;
            count += 1;
        }
    }
    return found if count == 1 else None;
}

impl Studio.terrain_point(scene: Scene, x: int, y: int) -> Vec3 | None {
    # The nearest terrain brush the line of sight enters. A terrain is a
    # group, which a click takes whole; the brush needs the surface itself.
    line = self.camera.sight(self.view_area(), x, y);
    eye = line[0];
    along = line[1];
    nearest = 1000000.0;
    self.sculpt_land = -1;
    for seen in self.looks {
        if ray_enters_box(eye, along, seen.low, seen.high) < 0.0 {
            continue;
        }
        entered = ray_enters_brush(seen.solid.sides, eye, along);
        if entered[1] < 0 or entered[0] <= 0.0 or entered[0] >= nearest {
            continue;
        }
        holder = scene.owner_of(seen.solid);
        if holder is None or scene.terrain_grid(holder) is None {
            continue;
        }
        nearest = entered[0];
        self.sculpt_land = holder.serial;
    }
    if self.sculpt_land < 0 {
        return None;
    }
    return eye.add(along.scale(nearest));
}

impl Studio.dab(scene: Scene, x: int, y: int, lower: bool, smooth: bool) {
    stage = self.stage;
    spot = self.terrain_point(scene, x, y);
    if stage is None or spot is None {
        return;
    }
    how = "smooth" if smooth else ("lower" if lower else "raise");
    stage.emit(
        "ed_sculpt " + how + " " + str(int(self.brush_radius)) + " " + str(int(self.brush_amount)) + " at "
            + str(int(round(spot.x))) + " " + str(int(round(spot.y))) + " on " + str(self.sculpt_land)
    );
}

impl Studio.terrain_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    app = self.app;
    if app is None {
        return False;
    }
    if name == "ed_brush" {
        numbers = terrain_numbers(args[1:]);
        if len(numbers) < 2 {
            self.say("ed_brush <radius> <amount>");
            return True;
        }
        self.brush_radius = max(8.0, min(2048.0, numbers[0]));
        self.brush_amount = max(1.0, min(512.0, numbers[1]));
        self.say("Brush " + str(int(self.brush_radius)) + " wide, " + str(int(self.brush_amount)) + " strong");
        self.keep_settings();
        return True;
    }
    if name == "ed_terrain" {
        how = args[1] if len(args) > 1 else "";
        if how == "lift" or how == "pattern" or how == "free" {
            ground = self.terrain_now(scene);
            if ground is None or scene.terrain_grid(ground) is None {
                self.say("Select the terrain to change");
                return True;
            }
            if how == "free" {
                # Left as the plain brushes it is made of.
                scene.select(ground);
                scene.set_fields({"_terrain": None, "_heights": None, "_pattern": None}, "Free terrain");
                self.say("That terrain is plain brushes now");
                return True;
            }
            if how == "pattern" {
                wanted = args[2] if len(args) > 2 else "";
                if wanted not in ["same", "alt", "other"] {
                    self.say("ed_terrain pattern <same|alt|other>: which way each cell is split");
                } elif not scene.set_pattern(ground, "" if wanted == "same" else wanted) {
                    self.say("The terrain is split that way already");
                }
                return True;
            }
            lift_box = terrain_numbers(args[2:]);
            if len(lift_box) < 5 {
                self.say("ed_terrain lift <x0> <y0> <x1> <y1> <amount> [falloff]");
                return True;
            }
            if not scene.lift_terrain(
                ground,
                Vec3(x=min(lift_box[0], lift_box[2]), y=min(lift_box[1], lift_box[3])),
                Vec3(x=max(lift_box[0], lift_box[2]), y=max(lift_box[1], lift_box[3])),
                lift_box[4],
                lift_box[5] if len(lift_box) > 5 else 0.0
            ) {
                self.say("No corner of the terrain is in that rectangle");
            }
            return True;
        }
        if how == "export" or how == "import" {
            if len(args) < 3 {
                self.say("ed_terrain " + how + " <file.pgm>");
                return True;
            }
            land = self.terrain_now(scene);
            if how == "export" {
                shape_now = scene.terrain_grid(land) if land is not None else None;
                if land is None or shape_now is None {
                    self.say("Select the terrain to write");
                    return True;
                }
                heights = heights_from(land.fields.get("_heights", ""), int(shape_now[0]), int(shape_now[1]));
                if heights is None {
                    self.say("That terrain's heights do not read");
                    return True;
                }
                folder = os.path.dirname(args[2]);
                if folder {
                    os.makedirs(folder, exist_ok=True);
                }
                with open(args[2], "w") as file {
                    file.write(heights_image(heights, int(shape_now[0]), int(shape_now[1])));
                }
                self.say("Wrote " + args[2]);
                return True;
            }
            if not os.path.isfile(args[2]) {
                self.say("ed_terrain import: no such file " + args[2]);
                return True;
            }
            data = b"";
            with open(args[2], "rb") as file {
                data = file.read();
            }
            limits = terrain_numbers(args[3:]);
            read = image_heights(data, limits[0] if len(limits) > 0 else 256.0);
            if read is None {
                self.say("That is not a grey image this reads (a PGM)");
                return True;
            }
            shape_now = scene.terrain_grid(land) if land is not None else None;
            if land is None or shape_now is None or int(shape_now[0]) != read[0] or int(shape_now[1]) != read[1] {
                self.say(
                    "Select a terrain of " + str(read[0]) + " by " + str(read[1])
                        + " cells to take that image (ed_terrain " + str(read[0]) + " " + str(read[1]) + " <cell>)"
                );
                return True;
            }
            if not scene.set_heights(land, read[2], "Heights from an image") {
                self.say("The terrain already has those heights");
            }
            return True;
        }
        if not self.is_built_scene() {
            self.say("A shipped map cannot take new brushes: start a scene (ed_scene)");
            return True;
        }
        numbers = terrain_numbers(args[1:]);
        cols = int(numbers[0]) if len(numbers) > 0 else 8;
        rows = int(numbers[1]) if len(numbers) > 1 else cols;
        cell = numbers[2] if len(numbers) > 2 else 64.0;
        eye = self.main.eye;
        ahead = self.main.forward();
        trace = app.level.collision.trace_point(eye, eye.add(ahead.scale(2048.0)));
        spot = eye.add(ahead.scale(512.0));
        if trace.fraction < 1.0 and not trace.start_solid {
            spot = eye.add(ahead.scale(2048.0 * trace.fraction));
        }
        snap = 16.0;
        origin = Vec3(
            x=float(round((spot.x - float(cols) * cell * 0.5) / snap)) * snap,
            y=float(round((spot.y - float(rows) * cell * 0.5) / snap)) * snap,
            z=float(round(spot.z / snap)) * snap
        );
        made = scene.make_terrain(origin, cols, rows, cell, self.material);
        if made is None {
            self.say("ed_terrain [cols rows cell]: up to 64 cells a side");
        } else {
            self.say("Added a terrain of " + str(cols) + " by " + str(rows) + " cells");
        }
        return True;
    }
    if name == "ed_sculpt" {
        how = args[1] if len(args) > 1 else "";
        if how not in ["raise", "lower", "smooth", "flatten", "noise", "erode", "paint"] {
            self.say("ed_sculpt <raise|lower|smooth|flatten|noise|erode|paint> [radius] [amount] [at <x> <y>]");
            return True;
        }
        # Words up to "at" are the brush; after it, the point; after "on", the terrain.
        brush_words: list[str] = [];
        point_words: list[str] = [];
        target_word = "";
        part = 0;
        for word in args[2:] {
            if word == "at" {
                part = 1;
            } elif word == "on" {
                part = 2;
            } elif part == 0 {
                brush_words.append(word);
            } elif part == 1 {
                point_words.append(word);
            } else {
                target_word = word;
            }
        }
        sizes = terrain_numbers(brush_words);
        radius = sizes[0] if len(sizes) > 0 else self.brush_radius;
        amount = sizes[1] if len(sizes) > 1 else self.brush_amount;
        land = scene.find(int(target_word)) if target_word.isdigit() else self.terrain_now(scene);
        if land is None or scene.terrain_grid(land) is None {
            self.say("Select the terrain to sculpt");
            return True;
        }
        where = terrain_numbers(point_words);
        x = 0.0;
        y = 0.0;
        if len(where) >= 2 {
            x = where[0];
            y = where[1];
        } else {
            eye = self.main.eye;
            ahead = self.main.forward();
            trace = app.level.collision.trace_point(eye, eye.add(ahead.scale(4096.0)));
            x = eye.x + ahead.x * 4096.0 * trace.fraction;
            y = eye.y + ahead.y * 4096.0 * trace.fraction;
        }
        if how == "paint" {
            # The material new brushes get, on the tops within the brush.
            painted = scene.paint_terrain(land, x, y, radius, self.material);
            self.say("Painted " + str(painted) + " cells' halves" if painted else "Nothing there to paint (or it has that material)");
            return True;
        }
        strength = amount;
        kind = how;
        if how == "lower" {
            kind = "raise";
            strength = -amount;
        } elif how == "smooth" {
            strength = 1.0;
        } elif how == "flatten" and len(sizes) < 2 {
            strength = 0.0;
        }
        if not scene.sculpt_terrain(land, x, y, radius, strength, kind) {
            self.say("The brush changed nothing there");
        }
        return True;
    }
    return False;
}
