"""Entities drawn as the game would show them: a pickup, a monster or a
fixture as the model its own game's rules give it, standing where the entity
is and facing the way it faces. Declarations live in studio.jac."""

impl Studio.entity_model_name(scene: Scene, item: Item) -> str {
    # By the game it is spawned by: its own in a scene of no one game.
    game = item.fields.get("asset_game", "") if scene.game == "passion" else scene.game;
    if game not in ["q1", "q2", "q3"] or item.origin() is None {
        return "";
    }
    kind = item.classname();
    path = "";
    try {
        flags = int(item.fields.get("spawnflags", "0")) if item.fields.get("spawnflags", "0").isdigit() else 0;
        if kind.startswith("monster_") {
            beast = enemy_rule(game, kind, flags);
            path = beast.model if beast is not None else "";
        } else {
            thing = pickup_rule(game, dict(item.fields), 0);
            if thing is not None {
                path = thing.model;
            } else {
                fixed = fixture_rule(game, dict(item.fields));
                path = fixed.model if fixed is not None else "";
            }
        }
    } except Exception {
        path = "";
    }
    return game + ":" + path if path and is_model(path) else "";
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
            if name {
                print("studio: model of " + item.classname() + " " + name + " edges=" + str(len(self.preview_edges(name))));
                known += 1;
            }
        }
        print("studio: models known=" + str(known));
        self.say(str(known) + " entities have a model of their game's");
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
