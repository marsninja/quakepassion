"""More than one document of each kind open at once: the models being
edited, the shader scripts and the textures. The one in hand is where it
always was (the model in `model_doc`, the script in `shader_file` and the
rest); the others are parked beside it, each with what is its own, and a
tab takes one in hand by parking the one that was. Declarations live in
studio.jac."""

impl Studio.park_model {
    doc = self.model_doc;
    if doc is None {
        return;
    }
    for slot in self.models_parked {
        if slot.doc is doc {
            return;
        }
    }
    self.models_parked.append(ModelSlot(doc=doc, skin=self.model_skin, bone_now=self.bone_now));
    self.model_skin = None;
    self.skin_dabs = 0;
}

impl Studio.unpark_model(index: int) -> bool {
    if index < 0 {
        index = len(self.models_parked) + index;
    }
    if index < 0 or index >= len(self.models_parked) {
        return False;
    }
    slot = self.models_parked.pop(index);
    self.park_model();
    self.model_doc = slot.doc;
    self.model_skin = slot.skin;
    self.skin_stale = slot.skin is not None;
    self.bone_now = slot.bone_now;
    self.show_model_doc(True);
    return True;
}

impl Studio.park_shader {
    if not self.shader_file {
        return;
    }
    for slot in self.shaders_parked {
        if slot.file == self.shader_file {
            return;
        }
    }
    self.shaders_parked.append(
        ShaderSlot(file=self.shader_file, shaders=self.shader_list, now=self.shader_now, broken=self.shader_broken, dirty=self.shader_dirty)
    );
}

impl Studio.unpark_shader(index: int) -> bool {
    if index < 0 {
        index = len(self.shaders_parked) + index;
    }
    if index < 0 or index >= len(self.shaders_parked) {
        return False;
    }
    slot = self.shaders_parked.pop(index);
    self.park_shader();
    self.shader_file = slot.file;
    self.shader_list = slot.shaders;
    self.shader_now = slot.now;
    self.shader_broken = slot.broken;
    self.shader_dirty = slot.dirty;
    return True;
}

impl Studio.docset_words -> str {
    return "studio: documents models=" + str(len(self.models_parked) + (1 if self.model_doc is not None else 0)) + " shaders="
        + str(len(self.shaders_parked) + (1 if self.shader_file else 0)) + " textures=" + str(len(self.textures_open))
        + " model=" + (self.model_doc.name if self.model_doc is not None else "-") + " shader="
        + (os.path.basename(self.shader_file) if self.shader_file else "-") + " texture=" + (self.texture_now if self.texture_now else "-");
}

impl Studio.docset_command(scene: Scene, args: list[str]) -> bool {
    name = args[0];
    how = args[1] if len(args) > 1 else "";
    if name == "ed_texture" {
        key = args[2] if len(args) > 2 else "";
        if how == "open" and ":" in key {
            # A picture of a game's archives or of the project's own ("own:"), open as a document.
            if key not in self.textures_open {
                self.textures_open.append(key);
            }
            self.show_texture_doc(key);
        } elif how == "close" {
            gone = key if key else self.texture_now;
            if gone not in self.textures_open {
                self.say("ed_texture close [game:file]: no such texture is open");
                return True;
            }
            self.textures_open = [held for held in self.textures_open if held != gone];
            if self.texture_now == gone {
                self.texture_now = "";
                if len(self.textures_open) > 0 {
                    self.show_texture_doc(self.textures_open[-1]);
                }
            }
            self.say("Closed " + gone);
        } elif how {
            self.say("ed_texture open <game:file> | close [game:file]: a picture open as a document of its own, with a tab");
            return True;
        }
        print(self.docset_words());
        return True;
    }
    if name != "ed_documents" {
        return False;
    }
    for (index, slot) in enumerate(self.models_parked) {
        print("studio: parked model " + str(index) + " " + slot.doc.name + (" *" if slot.doc.dirty else ""));
    }
    for (index, held) in enumerate(self.shaders_parked) {
        print("studio: parked shader " + str(index) + " " + os.path.basename(held.file) + (" *" if held.dirty else ""));
    }
    for held_key in self.textures_open {
        print("studio: open texture " + held_key);
    }
    print(self.docset_words());
    return True;
}

impl Studio.show_texture_doc(key: str) {
    self.texture_now = key;
    # Shown as the explorer shows a file: its picture and what there is to know of it.
    self.command(["ed_asset", "file:" + key]);
    if not self.assets_shown {
        self.assets_shown = True;
        self.logic_shown = False;
        self.arrange_views(self.layout);
    }
}
