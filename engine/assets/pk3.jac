"""PK3 archive precedence and static representatives of Q3 shader materials.

The viewer uses one image per material. Animated stages, blend stages, vertex
animation, fog, and skyboxes require the later material renderer.
"""
import os;
import from zipfile { ZipFile }
import from ..formats.bsp { Texture }
import from .materials { ModelMaterial, model_materials, material_name }
import from ..formats.animated { ModelStage, Deform }

obj Pk3Assets {
    has archives: list[ZipFile] = [],
        owners: dict[str, int] = {},
        canonical_names: dict[str, str] = {},
        shaders: dict[str, str] = {},
        alpha_tests: dict[str, int] = {},
        additive: dict[str, bool] = {},
        two_sided: dict[str, bool] = {},
        model_shaders: dict[str, ModelMaterial] = {};

    def open(directory: str) {
        for filename in sorted(os.listdir(directory)) {
            if filename.lower().endswith(".pk3") {
                archive = ZipFile(directory + "/" + filename);
                index = len(self.archives);
                self.archives.append(archive);
                for name in archive.namelist() {
                    self.owners[name] = index;
                    self.canonical_names[name.lower()] = name;
                }
            }
        }
        for name in sorted(self.owners.keys()) {
            if name.startswith("scripts/") and name.endswith(".shader") {
                self.parse_shaders(self.read(name).decode("utf-8"));
            }
        }
    }

    def exists(name: str) -> bool {
        return self.canonical_names.get(name.lower(), name) in self.owners;
    }

    def read(name: str) -> bytes {
        name = self.canonical_names.get(name.lower(), name);
        if name not in self.owners {
            raise ValueError("Missing PK3 asset: " + name);
        }
        return self.archives[self.owners[name]].read(name);
    }

    def image_name(name: str) -> str {
        name = self.canonical_names.get(name.lower(), name);
        if name in self.owners {
            return name;
        }
        stem = name;
        if name.lower().endswith(".tga") or name.lower().endswith(".jpg") {
            stem = name[:-4];
        }
        for extension in [".tga", ".jpg", ".jpeg", ".png"] {
            candidate = self.canonical_names.get(
                (stem + extension).lower(), stem + extension
            );
            if candidate in self.owners {
                return candidate;
            }
        }
        return "";
    }

    def parse_shaders(source: str) {
        # Discard comments before tokenizing braces, preserving line-based directives.
        clean = "";
        in_comment = False;
        for line in source.splitlines() {
            i = 0;
            while i < len(line) {
                pair = line[i:i + 2];
                if in_comment {
                    if pair == "*/" {
                        in_comment = False;
                        i += 2;
                    } else {
                        i += 1;
                    }
                } elif pair == "/*" {
                    in_comment = True;
                    i += 2;
                } elif pair == "//" {
                    break;
                } else {
                    clean += line[i];
                    i += 1;
                }
            }
            clean += "\n";
        }
        parsed = model_materials(clean);
        for key in parsed.keys() {
            self.model_shaders[key] = parsed[key];
        }
        tokens = clean.replace("{", " { ").replace("}", " } ").split();
        depth = 0;
        name = "";
        candidate = "";
        fallback = "";
        stage_additive = False;
        selected_additive = False;
        two_sided = False;
        stage = 0;
        selected_stage = -1;
        stage_alpha = 0;
        selected_alpha = 0;
        i = 0;
        while i < len(tokens) {
            token = tokens[i];
            lower = token.lower();
            if token == "{" {
                depth += 1;
                if depth == 2 {
                    stage += 1;
                    stage_alpha = 0;
                    stage_additive = False;
                }
            } elif token == "}" {
                depth -= 1;
                if depth == 0 and name != "" {
                    self.shaders[name] = candidate if candidate != "" else fallback;
                    self.alpha_tests[name] = selected_alpha;
                    self.additive[name] = selected_additive;
                    self.two_sided[name] = two_sided;
                    selected_additive = False;
                    two_sided = False;
                    selected_stage = -1;
                    selected_alpha = 0;
                    name = "";
                    candidate = "";
                    fallback = "";
                }
            } elif depth == 0 {
                name = material_name(token);
            } elif i + 1 < len(tokens) {
                if lower == "map" or lower == "clampmap" {
                    value = tokens[i + 1];
                    if candidate == "" and not value.startswith("$") {
                        candidate = value;
                        selected_stage = stage;
                        selected_alpha = stage_alpha;
                        selected_additive = stage_additive;
                    }
                    i += 1;
                } elif lower == "animmap" and i + 2 < len(tokens) {
                    if candidate == "" {
                        candidate = tokens[i + 2];
                        selected_stage = stage;
                        selected_alpha = stage_alpha;
                        selected_additive = stage_additive;
                    }
                    i += 2;
                } elif lower == "blendfunc" {
                    mode = tokens[i + 1].lower();
                    stage_additive = mode == "add";
                    if i + 2 < len(tokens) and mode == "gl_one" {
                        stage_additive = tokens[i + 2].lower() == "gl_one";
                    }
                    if selected_stage == stage {
                        selected_additive = stage_additive;
                    }
                    i += 1;
                } elif lower == "cull" and depth == 1 {
                    two_sided = tokens[i + 1].lower()
                        in ["none", "disable", "twosided"];
                    i += 1;
                } elif lower == "alphafunc" {
                    mode = tokens[i + 1].lower();
                    stage_alpha = 1
                        if mode == "gt0"
                        else (2 if mode == "ge128" else (3 if mode == "lt128" else 0));
                    if selected_stage == stage {
                        selected_alpha = stage_alpha;
                    }
                    i += 1;
                } elif lower == "qer_editorimage" {
                    fallback = tokens[i + 1];
                    i += 1;
                }
            }
            i += 1;
        }
    }

    def texture(texture: Texture) {
        name = "";
        key = material_name(texture.name);
        if key in self.shaders {
            name = self.image_name(self.shaders[key]);
            texture.alpha_test = self.alpha_tests.get(key, 0);
            texture.additive = self.additive.get(key, False);
            texture.two_sided = self.two_sided.get(key, False);
        }
        if name == "" {
            name = self.image_name(texture.name);
        }
        if name == "" {
            if (texture.flags & 128) == 0 {
                print("Missing material image:", texture.name);
            }
            return;
        }
        texture.encoded = self.read(name);
        texture.extension = ".tga" if name.lower().endswith(".tga") else ".jpg";
        if name.lower().endswith(".png") {
            texture.extension = ".png";
        }
    }

    def model_stages(name: str) -> list[ModelStage] {
        key = material_name(name);
        if key not in self.model_shaders {
            return [];
        }
        material = self.model_shaders[key];
        if material.unsupported {
            print("Partial model material:", name, material.unsupported);
            return [];
        }
        # Surface-only stage features keep models on their plain skin.
        if material.advanced {
            return [];
        }
        result: list[ModelStage] = [];
        for stage in material.stages {
            texture = self.model_image(stage.texture.name, material.two_sided);
            frames = [
                self.model_image(frame.name, material.two_sided)
                for frame in stage.frames
            ];
            result.append(
                ModelStage(
                    texture=texture,
                    frames=frames,
                    frequency=stage.frequency,
                    environment=stage.environment,
                    blend=stage.blend,
                    scroll_u=stage.scroll_u,
                    scroll_v=stage.scroll_v
                )
            );
        }
        return result;
    }

    """The ordered stages of a BSP surface shader, images loaded, when the
    shader needs more than the one-pass base-times-lightmap drawing: animated
    maps, texture modifiers, waves, extra blended layers or vertex colour."""
    def surface_stages(name: str) -> list[ModelStage] {
        key = material_name(name);
        if key not in self.model_shaders {
            return [];
        }
        material = self.model_shaders[key];
        # Skies keep their sky-box drawing; their cloud layers belong on the dome.
        if material.sky or material.unsupported or not material.stages or not layered_material(material) {
            return [];
        }
        result: list[ModelStage] = [];
        for stage in material.stages {
            if not stage.lightmap and not stage.white {
                image = self.image_name(stage.texture.name);
                if not image {
                    return [];
                }
                stage.texture = Texture(name=image, encoded=self.read(image), extension=image_extension(image));
                frames: list[Texture] = [];
                for frame in stage.frames {
                    picture = self.image_name(frame.name);
                    if not picture {
                        return [];
                    }
                    frames.append(Texture(name=picture, encoded=self.read(picture), extension=image_extension(picture)));
                }
                stage.frames = frames;
            }
            result.append(stage);
        }
        return result;
    }

    """The deformVertexes of a layered surface shader."""
    def surface_deforms(name: str) -> list[Deform] {
        key = material_name(name);
        if key not in self.model_shaders {
            return [];
        }
        return self.model_shaders[key].deforms;
    }

    def model_image(name: str, two_sided: bool) -> Texture {
        image = self.image_name(name);
        if not image {
            raise ValueError("Missing model shader image: " + name);
        }
        texture = Texture(
            name=image,
            encoded=self.read(image),
            two_sided=two_sided,
            extension=".tga" if image.lower().endswith(".tga") else ".jpg"
        );
        if image.lower().endswith(".png") {
            texture.extension = ".png";
        }
        return texture;
    }

    def close() {
        for archive in self.archives {
            archive.close();
        }
        self.archives = [];
        self.owners = {};
        self.canonical_names = {};
        self.model_shaders = {};
        self.shaders = {};
        self.alpha_tests = {};
        self.additive = {};
        self.two_sided = {};
    }
}

def image_extension(path: str) -> str {
    lower = path.lower();
    if lower.endswith(".tga") {
        return ".tga";
    }
    if lower.endswith(".png") {
        return ".png";
    }
    return ".jpg";
}

"""Whether a surface shader needs layered drawing: anything beyond one base
stage, alone or multiplied with the lightmap, with no motion or colour."""
def layered_material(material: ModelMaterial) -> bool {
    if material.deforms {
        return True;
    }
    for stage in material.stages {
        if stage.frames or stage.mods or stage.environment or stage.rgb != "identity" or stage.alpha != "identity" {
            return True;
        }
    }
    count = len(material.stages);
    if count == 1 {
        return material.stages[0].blend not in ["opaque", "alpha"] or material.stages[0].lightmap;
    }
    if count == 2 {
        first = material.stages[0];
        second = material.stages[1];
        plain = (first.lightmap and not second.lightmap and second.blend == "multiply")
            or (second.lightmap and not first.lightmap and second.blend == "multiply");
        return not plain;
    }
    return True;
}
