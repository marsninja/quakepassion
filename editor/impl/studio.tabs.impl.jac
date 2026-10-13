"""Tabs beside the menu bar when more than one document is open (maps
and scenes, the model being edited, the shader script), and a list to
choose a field's file from. Declarations live in studio.jac."""

impl Studio.tabs_words -> str {
    current = self.scene;
    words = "";
    for key in self.doc_keys() {
        held = self.scenes[key];
        words += key + ("*" if held.dirty else "") + ("<" if held is current else "") + "|";
    }
    doc = self.model_doc;
    for slot in self.models_parked {
        words += "model:" + slot.doc.name + ("*" if slot.doc.dirty else "") + "|";
    }
    for held in self.shaders_parked {
        words += "shader:" + held.file + "|";
    }
    for held_key in self.textures_open {
        words += "texture:" + held_key + ("<" if held_key == self.texture_now else "") + "|";
    }
    return words + "model:" + (doc.name if doc is not None else "") + "|shader:" + self.shader_file + "|"
        + ("assets" if self.assets_shown else ("logic" if self.logic_shown else "views"));
}

impl Studio.tabs_count -> int {
    return len(self.scenes) + (1 if self.model_doc is not None else 0) + (1 if self.shader_file else 0)
        + len(self.models_parked) + len(self.shaders_parked) + len(self.textures_open);
}

impl Studio.fill_doc_strip(ui: StudioUi) {
    strip = ui.doc_strip;
    strip.clear();
    current = self.scene;
    on_views = not self.assets_shown;
    for key in self.doc_keys() {
        held = self.scenes[key];
        shown_name = held.name[7:] if held.name.startswith("studio:") else held.name;
        strip.adopt(
            PushButton(
                text=shown_name + (" *" if held.dirty else ""),
                command="ed_tab " + quote_command_word("doc:" + key),
                lit=held is current and on_views,
                hint="Go to " + held.game + " " + shown_name + (", which has changes not saved" if held.dirty else "")
            )
        );
    }
    doc = self.model_doc;
    if doc is not None {
        strip.adopt(
            PushButton(
                text="model " + doc.name + (" *" if doc.dirty else ""), command="ed_tab model", lit=self.assets_shown and not self.texture_now,
                hint="Go to the model being edited"
            )
        );
    }
    for (index, slot) in enumerate(self.models_parked) {
        strip.adopt(
            PushButton(
                text="model " + slot.doc.name + (" *" if slot.doc.dirty else ""), command="ed_tab model:" + str(index),
                hint="Take this model in hand"
            )
        );
    }
    if self.shader_file {
        strip.adopt(
            PushButton(
                text="shader " + os.path.basename(self.shader_file), command="ed_tab shader",
                hint="List the shader script's shaders"
            )
        );
    }
    for (index, held) in enumerate(self.shaders_parked) {
        strip.adopt(
            PushButton(text="shader " + os.path.basename(held.file), command="ed_tab shader:" + str(index), hint="Take this script in hand")
        );
    }
    for held_key in self.textures_open {
        strip.adopt(
            PushButton(
                text="texture " + held_key.split("/")[-1], command="ed_tab " + quote_command_word("texture:" + held_key),
                lit=held_key == self.texture_now and self.assets_shown, hint="Show " + held_key
            )
        );
    }
    strip.adopt(PushButton(glyph="cross", command="ed_close", size=22, hint="Close the document shown"));
}

impl Studio.keep_tabs(ui: StudioUi) {
    words = self.tabs_words();
    if words == self.tabs_for {
        return;
    }
    self.tabs_for = words;
    self.tabs_on = self.tabs_count() > 1;
    if self.tabs_on {
        self.fill_doc_strip(ui);
    } else {
        ui.doc_strip.clear();
    }
}

impl Studio.tabs_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    stage = self.stage;
    if name == "ed_tab" {
        word = args[1] if len(args) > 1 else "";
        if word.startswith("doc:") {
            if self.assets_shown or self.logic_shown {
                # Back to the level views first.
                self.assets_shown = False;
                self.logic_shown = False;
                self.arrange_views(self.layout);
            }
            if not self.show_doc(word[4:]) {
                self.say("That document is not open");
            }
        } elif word == "model" and self.model_doc is not None {
            # The model, not a texture, is what the explorer shows now.
            self.texture_now = "";
            self.show_model_doc(False);
            self.logic_shown = False;
            self.assets_shown = True;
            self.arrange_views(self.layout);
        } elif word.startswith("model:") and word[6:].isdigit() {
            if not self.unpark_model(int(word[6:])) {
                self.say("No such model is open");
            } else {
                self.texture_now = "";
                self.logic_shown = False;
                self.assets_shown = True;
                self.arrange_views(self.layout);
            }
        } elif word.startswith("shader:") and word[7:].isdigit() {
            if not self.unpark_shader(int(word[7:])) {
                self.say("No such shader script is open");
            } else {
                self.command(["ed_shader"]);
            }
        } elif word.startswith("texture:") and word[8:] in self.textures_open {
            self.show_texture_doc(word[8:]);
        } elif word == "shader" and self.shader_file {
            self.command(["ed_shader"]);
        } else {
            print("studio: tabs " + str(self.tabs_count()) + " shown=" + ("1" if self.tabs_on else "0"));
            self.say("ed_tab <doc:game/name|model|shader>: go to an open document");
        }
        return True;
    }
    if name != "ed_pickfile" {
        return False;
    }
    key = args[1] if len(args) > 1 else "";
    kind = file_field(key);
    chosen = scene.selection();
    if not kind or len(chosen) == 0 {
        self.say("ed_pickfile <noise|music|model|model2>: choose that field's file for the selected entities");
        return True;
    }
    game = scene.game if scene.game in ["q1", "q2", "q3"] else chosen[0].fields.get("asset_game", "");
    stock = self.archive;
    if game not in ["q1", "q2", "q3"] or stock is None {
        self.say("It carries no game whose files could be chosen from (ed_assetgame q1|q2|q3)");
        return True;
    }
    listing = self.asset_index;
    if listing is None {
        listing = AssetIndex(shelf=stock);
        self.asset_index = listing;
    }
    values = field_choices(game, kind, listing.names(game));
    print("studio: pickfile " + key + " game=" + game + " kind=" + kind + " choices=" + str(len(values)));
    if len(values) == 0 {
        self.say("That game's archives hold no " + kind + "s");
        return True;
    }
    if stage is not None {
        entries = [
            PaletteEntry(command="ed_set " + quote_command_word(key) + " " + quote_command_word(value), usage=value)
            for value in values
        ];
        chooser = Palette(entries=entries, prompt="Type to find a " + kind + " of " + game + "'s", choosing=True);
        chooser.open_in(stage);
    }
    return True;
}
