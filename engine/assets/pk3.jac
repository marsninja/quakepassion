"""PK3 archive precedence and static representatives of Q3 shader materials.

The viewer uses one image per material. Animated stages, blend stages, vertex
animation, fog, and skyboxes require the later material renderer.
"""
import os;
import from zipfile { ZipFile }
import from ..formats.q1.bsp { Texture }

obj Pk3Assets {
    has archives: list[ZipFile] = [],
        owners: dict[str, int] = {},
        shaders: dict[str, str] = {},
        alpha_tests: dict[str, int] = {},
        additive: dict[str, bool] = {},
        two_sided: dict[str, bool] = {};

    def open(directory: str) {
        for filename in sorted(os.listdir(directory)) {
            if filename.lower().endswith(".pk3") {
                archive = ZipFile(directory + "/" + filename);
                index = len(self.archives);
                self.archives.append(archive);
                for name in archive.namelist() {
                    self.owners[name] = index;
                }
            }
        }
        for name in sorted(self.owners.keys()) {
            if name.startswith("scripts/") and name.endswith(".shader") {
                self.parse_shaders(self.read(name).decode("utf-8"));
            }
        }
    }

    def read(name: str) -> bytes {
        if name not in self.owners {
            raise ValueError("Missing PK3 asset: " + name);
        }
        return self.archives[self.owners[name]].read(name);
    }

    def image_name(name: str) -> str {
        if name in self.owners {
            return name;
        }
        stem = name;
        if name.endswith(".tga") or name.endswith(".jpg") {
            stem = name[:-4];
        }
        for extension in [".tga", ".jpg", ".jpeg", ".png"] {
            if stem + extension in self.owners {
                return stem + extension;
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
                name = token;
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
        if texture.name in self.shaders {
            name = self.image_name(self.shaders[texture.name]);
            texture.alpha_test = self.alpha_tests.get(texture.name, 0);
            texture.additive = self.additive.get(texture.name, False);
            texture.two_sided = self.two_sided.get(texture.name, False);
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
        texture.extension = ".tga" if name.endswith(".tga") else ".jpg";
        if name.endswith(".png") {
            texture.extension = ".png";
        }
    }

    def close() {
        for archive in self.archives {
            archive.close();
        }
        self.archives = [];
        self.owners = {};
    }
}
