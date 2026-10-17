"""The manifest: every asset a game asks for, as a graph.

A `Manifest` holds a `Source` for each place names come from (an archive, a
map), and each source `Wants` the `AssetSlot`s it names. A slot is one name
the generator has to fill, with its kind and the facts about it the generator
may read: a texture's size, a sound's length and rate and where it loops,
a model's frames. Facts come from the files' headers; the pixels, samples
and vertices themselves are never read.

Most slots are simply the files a game's archives hold. Quake's wall
textures are not files: each map carries its own, so the manifest reads
each map's texture table and makes a slot for every texture named there."""
import struct;
import from engine.assets.library { AssetLibrary }
import from engine.formats.bsp { i32_at }
import from engine.formats.q1.bsp { parse_textures }
import from engine.formats.q2.bsp { texture_names }
import from editor.formats.image { image_size }

node Manifest {
    has game: str,
        pack: str,
        slot_count: int = 0;
}

"""Where names come from: an archive's listing, or a map."""
node Source {
    has name: str,
        kind: str = "archive";
}

"""One name to fill. `kind` is what it is (miptex, wal, image, sound,
mdl, md2, md3, spr, sp2, pcx, lmp, wad, music, film, shader, text, map,
other); `facts` what is known of it."""
node AssetSlot {
    has name: str,
        kind: str,
        facts: dict[str, float] = {},
        notes: dict[str, str] = {};

    def fact(key: str, fallback: float = 0.0) -> float {
        return self.facts.get(key, fallback);
    }
}

edge Holds: Manifest --> Source {}
edge Wants: Source --> AssetSlot {}

"""The slots of a kind (every slot when `kind` is empty)."""
walker CollectSlots {
    has kind: str = "",
        slots: list[AssetSlot] = [],
        seen: set[str] = set();

    can start with Manifest entry {
        visit [here->:Holds:->];
    }

    can source with Source entry {
        visit [here->:Wants:->];
    }

    can slot with AssetSlot entry {
        if (not self.kind or here.kind == self.kind) and here.name not in self.seen {
            self.seen.add(here.name);
            self.slots.append(here);
        }
    }
}

"""What a file is, by its name."""
def slot_kind(name: str, game: str) -> str {
    lower = name.lower();
    dot = lower.rfind(".");
    extension = lower[dot:] if dot >= 0 else "";
    if extension == ".wav" {
        if lower.startswith("music/") {
            return "music";
        }
        return "sound";
    }
    if extension == ".ogg" or extension == ".mp3" {
        return "music";
    }
    if extension in [".tga", ".jpg", ".jpeg", ".png"] {
        return "image";
    }
    kinds = {
        ".wal": "wal",
        ".pcx": "pcx",
        ".lmp": "lmp",
        ".wad": "wad",
        ".mdl": "mdl",
        ".md2": "md2",
        ".md3": "md3",
        ".spr": "spr",
        ".sp2": "sp2",
        ".cin": "film",
        ".roq": "film",
        ".shader": "shader",
        ".bsp": "map",
        ".skin": "text",
        ".cfg": "text",
        ".txt": "text",
        ".arena": "text",
        ".bot": "text",
        ".c": "text",
        ".h": "text"
    };
    return kinds.get(extension, "other");
}

def:priv u16(data: bytes, at: int) -> int {
    return int(data[at]) | (int(data[at + 1]) << 8);
}

"""What a WAV's header says: its rate, its width in bytes, its length in
seconds, and where a cue marks its loop (Quake's ambient sounds loop from
there), -1 when it does not loop."""
def wav_facts(data: bytes) -> dict[str, float] {
    facts: dict[str, float] = {"rate": 11025.0, "width": 1.0, "seconds": 0.0, "loop": -1.0, "channels": 1.0};
    if len(data) < 12 or data[0:4] != b"RIFF" or data[8:12] != b"WAVE" {
        return facts;
    }
    at = 12;
    frames = 0;
    while at + 8 <= len(data) {
        kind = data[at:at + 4];
        size = i32_at(data, at + 4);
        body = at + 8;
        if kind == b"fmt " and body + 16 <= len(data) {
            facts["channels"] = float(u16(data, body + 2));
            facts["rate"] = float(i32_at(data, body + 4));
            facts["width"] = float(u16(data, body + 14) // 8);
        } elif kind == b"data" {
            per = int(facts["width"] * facts["channels"]);
            frames = min(size, len(data) - body) // max(1, per);
            facts["seconds"] = float(frames) / max(1.0, facts["rate"]);
        } elif kind == b"cue " and body + 28 <= len(data) {
            facts["loop"] = float(i32_at(data, body + 24)) / max(1.0, facts["rate"]);
        }
        if size < 0 {
            break;
        }
        at = body + size + (size & 1);
    }
    return facts;
}

"""What a model's header says: frames, skins and the skin's size (MDL and
MD2), surfaces and tags (MD3)."""
def model_facts(data: bytes, kind: str) -> dict[str, float] {
    facts: dict[str, float] = {};
    if kind == "mdl" and len(data) >= 84 and data[0:4] == b"IDPO" {
        facts["skins"] = float(i32_at(data, 48));
        facts["skin_w"] = float(i32_at(data, 52));
        facts["skin_h"] = float(i32_at(data, 56));
        facts["vertices"] = float(i32_at(data, 60));
        facts["triangles"] = float(i32_at(data, 64));
        facts["frames"] = float(i32_at(data, 68));
    } elif kind == "md2" and len(data) >= 68 and data[0:4] == b"IDP2" {
        facts["skin_w"] = float(i32_at(data, 8));
        facts["skin_h"] = float(i32_at(data, 12));
        facts["skins"] = float(i32_at(data, 20));
        facts["vertices"] = float(i32_at(data, 24));
        facts["triangles"] = float(i32_at(data, 32));
        facts["frames"] = float(i32_at(data, 40));
    } elif kind == "md3" and len(data) >= 108 and data[0:4] == b"IDP3" {
        facts["frames"] = float(i32_at(data, 76));
        facts["tags"] = float(i32_at(data, 80));
        facts["surfaces"] = float(i32_at(data, 84));
    }
    return facts;
}

"""What a picture's header says: its size."""
def picture_facts(data: bytes, kind: str, name: str) -> dict[str, float] {
    facts: dict[str, float] = {};
    if kind == "wal" and len(data) >= 40 {
        facts["width"] = float(i32_at(data, 32));
        facts["height"] = float(i32_at(data, 36));
        if len(data) >= 100 {
            facts["flags"] = float(i32_at(data, 88));
            facts["contents"] = float(i32_at(data, 92));
            facts["value"] = float(i32_at(data, 96));
        }
    } elif kind == "lmp" and len(data) >= 8 and not name.lower().endswith("palette.lmp")
        and not name.lower().endswith("colormap.lmp") {
        facts["width"] = float(i32_at(data, 0));
        facts["height"] = float(i32_at(data, 4));
    } elif kind == "pcx" and len(data) >= 128 {
        facts["width"] = float(u16(data, 8) - u16(data, 4) + 1);
        facts["height"] = float(u16(data, 10) - u16(data, 6) + 1);
    } elif kind == "image" {
        dot = name.rfind(".");
        size = image_size(data, name[dot:] if dot >= 0 else "");
        facts["width"] = float(size[0]);
        facts["height"] = float(size[1]);
    }
    return facts;
}

"""How each image a set of Quake III shader scripts names is drawn: "alpha"
(cut out where its alpha is low), "blend" (laid over by its alpha), "add"
(added, so black is clear: glows and flames), "filter" (multiplied: detail
and light), "env" (an environment map's sheen), else "base"."""
def shader_roles(text: str) -> dict[str, str] {
    roles: dict[str, str] = {};
    depth = 0;
    images: list[str] = [];
    role = "base";
    for raw in text.replace("\r", "\n").split("\n") {
        line = raw.strip();
        cut = line.find("//");
        if cut >= 0 {
            line = line[:cut].strip();
        }
        if not line {
            continue;
        }
        for token in line.replace("{", " { ").replace("}", " } ").split() {
            if token == "{" {
                depth += 1;
                if depth == 2 {
                    images = [];
                    role = "base";
                }
            } elif token == "}" {
                if depth == 2 {
                    for image in images {
                        known = roles.get(image, "base");
                        if known == "base" {
                            roles[image] = role;
                        }
                    }
                }
                depth = max(0, depth - 1);
            }
        }
        if depth != 2 {
            continue;
        }
        words = line.replace("{", " ").replace("}", " ").split();
        if not words {
            continue;
        }
        key = words[0].lower();
        if key in ["map", "clampmap"] and len(words) > 1 and not words[1].startswith("$") {
            images.append(words[1].lower());
        } elif key == "animmap" and len(words) > 2 {
            for word in words[2:] {
                images.append(word.lower());
            }
        } elif key == "alphafunc" {
            role = "alpha";
        } elif key == "blendfunc" and role != "alpha" {
            joined = " ".join(words[1:]).lower();
            if joined == "add" or joined == "gl_one gl_one" {
                role = "add";
            } elif joined == "filter" or joined == "gl_dst_color gl_zero" or joined == "gl_zero gl_src_color" {
                role = "filter";
            } elif joined == "blend" or joined == "gl_src_alpha gl_one_minus_src_alpha" {
                role = "blend";
            }
        } elif key == "tcgen" and len(words) > 1 and words[1].lower() == "environment" and role == "base" {
            role = "env";
        }
    }
    return roles;
}

"""A Quake map's textures, read from its texture table alone."""
def q1_map_textures(data: bytes) -> list[tuple[str, int, int]] {
    found: list[tuple[str, int, int]] = [];
    if len(data) < 124 {
        return found;
    }
    offset = i32_at(data, 20);
    size = i32_at(data, 24);
    if offset < 0 or size <= 0 or offset + size > len(data) {
        return found;
    }
    for texture in parse_textures(data[offset:offset + size]) {
        if texture.name and texture.pixels {
            found.append((texture.name, texture.width, texture.height));
        }
    }
    return found;
}

obj ManifestBuilder {
    has manifest: Manifest,
        slots: dict[str, AssetSlot] = {};

    """The slot for `name`, made the first time it is named, and wanted by
    `source`."""
    def want(source: Source, name: str, kind: str, facts: dict[str, float] = {}) -> AssetSlot {
        key = kind + ":" + name.lower();
        if key not in self.slots {
            slot = AssetSlot(name=name, kind=kind, facts=dict(facts));
            self.slots[key] = slot;
            self.manifest.slot_count += 1;
        }
        found = self.slots[key];
        source +>:Wants:+> found;
        return found;
    }

    def source(name: str, kind: str) -> Source {
        made = Source(name=name, kind=kind);
        self.manifest +>:Holds:+> made;
        return made;
    }
}

"""The kinds whose facts are read from the file's header."""
def:priv wants_facts(kind: str) -> bool {
    return kind in ["sound", "music", "mdl", "md2", "md3", "wal", "lmp", "pcx", "image", "map"];
}

"""The manifest of a search path's archives, for `game` (q1, q2 or q3)."""
def build_manifest(game: str, pack: str, path: str) -> Manifest {
    library = AssetLibrary(game=game);
    library.open(path);
    builder = ManifestBuilder(manifest=Manifest(game=game, pack=pack));
    names: list[str] = [];
    seen: set[str] = set();
    if game == "q3" {
        for name in sorted(library.pk3.owners.keys()) {
            if name.endswith("/") {
                continue;
            }
            if name.lower() not in seen {
                seen.add(name.lower());
                names.append(name);
            }
        }
    } else {
        for archive in library.paks {
            for name in archive.names() {
                if name.lower() not in seen {
                    seen.add(name.lower());
                    names.append(name);
                }
            }
        }
    }
    listing = builder.source(path, "archive");
    roles: dict[str, str] = {};
    if game == "q3" {
        for name in names {
            if name.lower().startswith("scripts/") and name.lower().endswith(".shader") {
                for (image, role) in shader_roles(library.read(name).decode("latin-1")).items() {
                    if roles.get(image, "base") == "base" {
                        roles[image] = role;
                    }
                }
            }
        }
    }
    for name in names {
        kind = slot_kind(name, game);
        facts: dict[str, float] = {};
        if wants_facts(kind) {
            data = library.read(name);
            if kind == "sound" or kind == "music" {
                facts = wav_facts(data) if name.lower().endswith(".wav") else {};
            } elif kind in ["mdl", "md2", "md3"] {
                facts = model_facts(data, kind);
            } elif kind == "map" {
                if game == "q1" {
                    level = builder.source(name, "map");
                    for (texture, width, height) in q1_map_textures(data) {
                        builder.want(
                            level, texture, "miptex", {"width": float(width), "height": float(height)}
                        );
                    }
                } elif game == "q2" {
                    level = builder.source(name, "map");
                    for texture in texture_names(data) {
                        builder.want(level, "textures/" + texture + ".wal", "wal_ref");
                    }
                }
            } else {
                facts = picture_facts(data, kind, name);
            }
        }
        slot = builder.want(listing, name, kind, facts);
        if kind == "image" and roles {
            stem = name.lower().rsplit(".", 1)[0];
            for extension in [".tga", ".jpg"] {
                if stem + extension in roles {
                    slot.notes["role"] = roles[stem + extension];
                }
            }
        }
        if kind == "wal" and wants_facts(kind) {
            header = library.read(name);
            if len(header) >= 88 {
                cut = 56;
                while cut < 88 and header[cut] != 0 {
                    cut += 1;
                }
                slot.notes["next"] = header[56:cut].decode("latin-1");
            }
        }
    }
    library.close();
    return builder.manifest;
}

"""Every slot of a manifest of `kind`."""
def slots_of(manifest: Manifest, kind: str = "") -> list[AssetSlot] {
    collected = manifest spawn CollectSlots(kind=kind);
    return collected.slots;
}
