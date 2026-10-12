"""Entities drawn as the game would show them: a pickup, a monster or a
fixture as the model its own game's rules give it, standing where the entity
is and facing the way it faces. Declarations live in studio.jac."""

impl Studio.entity_look(scene: Scene, item: Item) -> EntityLook | None {
    # By the game it is spawned by: its own in a scene of no one game.
    game = item.fields.get("asset_game", "") if scene.game == "passion" else scene.game;
    if game not in ["q1", "q2", "q3"] or item.origin() is None {
        return None;
    }
    kind = item.classname();
    path = "";
    skin = 0;
    spawned_at = 0;
    try {
        flags = int(item.fields.get("spawnflags", "0")) if item.fields.get("spawnflags", "0").isdigit() else 0;
        if kind.startswith("monster_") {
            beast = enemy_rule(game, kind, flags);
            if beast is not None {
                path = beast.model;
                skin = beast.skin;
            }
        } else {
            thing = pickup_rule(game, dict(item.fields), 0);
            if thing is not None {
                path = thing.model;
                skin = thing.skin;
            } else {
                fixed = fixture_rule(game, dict(item.fields));
                if fixed is not None {
                    path = fixed.model;
                    skin = fixed.skin;
                    # The first of the frames it plays is the one it is spawned at.
                    spawned_at = fixed.frames[0] if len(fixed.frames) > 0 else 0;
                }
            }
        }
    } except Exception {
        path = "";
    }
    if not path {
        path = class_sprite(game, kind);
    }
    if not path or not (is_model(path) or is_sprite(path)) {
        return None;
    }
    return EntityLook(game=game, path=path, skin=max(0, skin), frame=max(0, spawned_at));
}

impl Studio.entity_model_name(scene: Scene, item: Item) -> str {
    look = self.entity_look(scene, item);
    return look.game + ":" + look.path if look is not None and is_model(look.path) else "";
}

impl Studio.preview_look(look: EntityLook) -> PreviewLook {
    key = look.key();
    if key in self.preview_looks {
        return self.preview_looks[key];
    }
    made = PreviewLook();
    stock = self.archive;
    if stock is not None {
        try {
            if look.sprite() {
                listing = self.asset_index;
                if listing is None {
                    listing = AssetIndex(shelf=stock);
                    self.asset_index = listing;
                }
                data = listing.read(look.game, look.path);
                reel = listing.sprite_reel(look.game, look.path, data) if data is not None else None;
                if reel is not None and len(reel.frames) > 0 {
                    still = reel.frames[frame_shown(look.frame, len(reel.frames))];
                    texels = texture_rgba(still);
                    if len(texels) > 0 {
                        self.canvas.keep_picture("pv:" + key, still.width, still.height, texels);
                        made.picture = "pv:" + key;
                        # A texel of a sprite is a unit of the world.
                        made.wide = float(still.width);
                        made.tall = float(still.height);
                    }
                }
            } else {
                asset = stock.reader().catalog.source(look.game).model(look.path, look.skin);
                made.model = asset.model;
                for (index, skin) in enumerate(asset.skins) {
                    colours = texture_rgba(skin);
                    name = "";
                    if len(colours) > 0 {
                        name = "pv:" + key + ":" + str(index);
                        self.canvas.keep_picture(name, skin.width, skin.height, colours);
                    }
                    made.pictures.append(name);
                }
            }
        } except Exception {
            # It does not read: it is shown as edges, or as its box.
            made = PreviewLook();
        }
    }
    # Kept, read or not: a look that does not read is not asked for again.
    self.preview_looks[key] = made;
    return made;
}

impl Studio.draw_entity_skins(scene: Scene) {
    self.skins_drawn = 0;
    if not self.models_shown or not self.models_skinned or self.camera.span > 0.0 {
        return;
    }
    eye = self.main.eye;
    across = self.camera.right();
    upward = self.camera.up();
    budget = 60000;
    # A model's triangles are wound as its own game winds them: both sides are drawn.
    rlDrawRenderBatchActive();
    rlDisableBackfaceCulling();
    for shape in self.shapes {
        if budget <= 0 {
            break;
        }
        at = shape.item.origin();
        if at is None or at.sub(eye).length() > 2048.0 {
            continue;
        }
        look = self.entity_look(scene, shape.item);
        if look is None {
            continue;
        }
        shown = self.preview_look(look);
        if not shown.skinned() {
            continue;
        }
        # What is selected is a little warmer than the rest.
        picked = scene.is_selected(shape.item);
        if shown.picture {
            corners = sprite_corners(at, across, upward, shown.wide, shown.tall);
            places = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0];
            rlSetTexture(u32(self.canvas.pictures.get(shown.picture, 0)));
            rlBegin(i32(4));
            rlColor4ub(u8(255), u8(215 if picked else 255), u8(170 if picked else 255), u8(255));
            for corner in [0, 1, 2, 0, 2, 3] {
                rlTexCoord2f(f32(places[corner * 2]), f32(places[corner * 2 + 1]));
                rlVertex3f(f32(corners[corner].x), f32(corners[corner].y), f32(corners[corner].z));
            }
            rlEnd();
            budget -= 2;
            self.skins_drawn += 1;
            continue;
        }
        figure = shown.model;
        if figure is None {
            continue;
        }
        turn = 0.0;
        try {
            turn = math.radians(float(shape.item.fields.get("angle", "0")));
        } except ValueError {
            turn = 0.0;
        }
        cosine = math.cos(turn);
        sine = math.sin(turn);
        for (index, surface) in enumerate(figure.surfaces) {
            name = shown.pictures[index] if index < len(shown.pictures) else "";
            picture = self.canvas.pictures.get(name, 0) if name else 0;
            if picture == 0 or len(surface.frames) == 0 or len(surface.uv) < len(surface.indices) * 2 {
                continue;
            }
            points = surface.frames[frame_shown(look.frame, len(surface.frames))].vertices;
            rlSetTexture(u32(picture));
            rlBegin(i32(4));
            rlColor4ub(u8(255), u8(215 if picked else 255), u8(170 if picked else 255), u8(255));
            for (place, vertex) in enumerate(surface.indices) {
                if vertex < 0 or vertex >= len(points) {
                    # A triangle is three corners: one that is not there is put at the entity.
                    rlTexCoord2f(f32(0.0), f32(0.0));
                    rlVertex3f(f32(at.x), f32(at.y), f32(at.z));
                    continue;
                }
                spot = stood_at(points[vertex], at, cosine, sine);
                rlTexCoord2f(f32(surface.uv[place * 2]), f32(surface.uv[place * 2 + 1]));
                rlVertex3f(f32(spot.x), f32(spot.y), f32(spot.z));
            }
            rlEnd();
            budget -= len(surface.indices) // 3;
        }
        self.skins_drawn += 1;
    }
    rlSetTexture(u32(0));
    rlDrawRenderBatchActive();
    rlEnableBackfaceCulling();
}

impl Studio.preview_edges(name: str) -> list[list[Vec3]] {
    if name in self.preview_models {
        return self.preview_models[name];
    }
    found: list[list[Vec3]] = [];
    stock = self.archive;
    parts = name.split(":", 1);
    if stock is not None and len(parts) == 2 {
        figure = load_model(stock, parts[0], parts[1]);
        if figure is not None {
            found = figure.edges(0);
        }
    }
    # Kept, empty or not: a model that does not read is not asked for again.
    self.preview_models[name] = found;
    return found;
}

impl Studio.draw_entity_models(scene: Scene) {
    if not self.models_shown or self.camera.span > 0.0 {
        # In the 3D view only: an axis view keeps its boxes.
        return;
    }
    eye = self.main.eye;
    budget = 60000;
    self.models_drawn = 0;
    for shape in self.shapes {
        if budget <= 0 {
            break;
        }
        at = shape.item.origin();
        if at is None or at.sub(eye).length() > 2048.0 {
            continue;
        }
        name = self.entity_model_name(scene, shape.item);
        if not name {
            continue;
        }
        look = self.entity_look(scene, shape.item);
        if self.models_skinned and look is not None and self.preview_look(look).skinned() and not scene.is_selected(shape.item) {
            # Drawn with its skin already: only what is selected has its edges over that.
            self.models_drawn += 1;
            continue;
        }
        edges = self.preview_edges(name);
        if len(edges) == 0 {
            continue;
        }
        turn = 0.0;
        try {
            turn = math.radians(float(shape.item.fields.get("angle", "0")));
        } except ValueError {
            turn = 0.0;
        }
        cosine = math.cos(turn);
        sine = math.sin(turn);
        tone = ink(0xffffff, 230) if scene.is_selected(shape.item) else shape.tone.faded(210);
        for pair in edges {
            first = pair[0];
            second = pair[1];
            wire_line(
                Vec3(x=at.x + first.x * cosine - first.y * sine, y=at.y + first.x * sine + first.y * cosine, z=at.z + first.z),
                Vec3(x=at.x + second.x * cosine - second.y * sine, y=at.y + second.x * sine + second.y * cosine, z=at.z + second.z),
                tone
            );
        }
        budget -= len(edges);
        self.models_drawn += 1;
    }
}

impl Studio.preview_command(scene: Scene, args: list[str]) -> bool {
    if args[0] != "ed_models" {
        return False;
    }
    how = args[1] if len(args) > 1 else "";
    if how == "list" {
        # What each entity would be shown as, whether or not models are drawn.
        known = 0;
        for item in scene.items() {
            name = self.entity_model_name(scene, item);
            look = self.entity_look(scene, item);
            if name and look is not None {
                print(
                    "studio: model of " + item.classname() + " " + name + " edges=" + str(len(self.preview_edges(name)))
                        + " skin=" + str(look.skin) + " frame=" + str(look.frame) + " skinned="
                        + ("1" if self.preview_look(look).skinned() else "0")
                );
                known += 1;
            } elif look is not None {
                seen = self.preview_look(look);
                print(
                    "studio: sprite of " + item.classname() + " " + look.game + ":" + look.path + " frame=" + str(look.frame)
                        + " size=" + str(int(seen.wide)) + "x" + str(int(seen.tall))
                );
                known += 1;
            }
        }
        print("studio: models known=" + str(known));
        self.say(str(known) + " entities have a model or a sprite of their game's");
        return True;
    }
    if how == "skins" {
        self.models_skinned = (not self.models_skinned) if len(args) < 3 or args[2] not in ["on", "off"] else args[2] == "on";
        self.keep_settings();
        print("studio: models skins=" + ("1" if self.models_skinned else "0"));
        self.say(
            "Entities' models are drawn with their skins, and sprites as their pictures"
            if self.models_skinned
            else "Entities' models are drawn as their edges"
        );
        return True;
    }
    self.models_shown = not self.models_shown;
    if how in ["on", "off"] {
        self.models_shown = how == "on";
    }
    self.keep_settings();
    self.say(
        "Entities are drawn as their game's models in the 3D view" if self.models_shown else "Entities are drawn as boxes"
    );
    return True;
}
