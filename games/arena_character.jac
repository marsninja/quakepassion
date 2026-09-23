"""Adapt Q3's tagged player parts to the engine's shared animated model format."""
import from engine.assets.library { AssetLibrary, ModelAsset }
import from engine.formats.q3.model { parse_md3 }
import from engine.formats.animated { AnimatedModel, AnimatedSurface, AnimationFrame, ModelTag }
import from engine.formats.bsp { Texture }
import from engine.math.vec3 { Vec3 }


def tag_at(model: AnimatedModel, frame: int, name: str) -> ModelTag {
    if frame < 0 or frame >= len(model.tags) { raise ValueError("Invalid player tag frame"); }
    for tag in model.tags[frame].tags { if tag.name == name { return tag; } }
    raise ValueError("Missing player attachment: " + name);
}

def transform(tag: ModelTag, vector: Vec3, normal: bool = False) -> Vec3 {
    result = tag.axes[0].scale(vector.x).add(tag.axes[1].scale(vector.y)).add(tag.axes[2].scale(vector.z));
    return result if normal else result.add(tag.origin);
}

def player_part(
    library: AssetLibrary, part: str, character: str = "sarge", skin: str = "default"
) -> ModelAsset {
    prefix = "models/players/" + character + "/";
    model = parse_md3(library.read(prefix + part + ".md3"));
    mappings: dict[str, str] = {};
    skin_file = prefix + part + "_" + skin + ".skin";
    if not library.exists(skin_file) {
        skin_file = prefix + part + "_default.skin";
    }
    for line in library.read(skin_file).decode("utf-8").splitlines() {
        fields = line.split(",");
        if len(fields) == 2 and fields[1].strip() {
            mappings[fields[0].strip()] = fields[1].strip();
        }
    }
    skins: list[Texture] = [];
    for surface in model.surfaces {
        if surface.name not in mappings { raise ValueError("Missing player surface skin: " + surface.name); }
        material = mappings[surface.name];
        texture = Texture(name=material);
        library.pk3.texture(texture);
        if not texture.encoded { raise ValueError("Missing player skin: " + material); }
        surface.stages = library.pk3.model_stages(material);
        skins.append(texture);
    }
    return ModelAsset(model=model, skins=skins);
}

"""Bake a Q3 player (legs, torso, head and held weapon joined through their MD3
tags) into single-surface poses: stand, run, attack and BOTH_DEATH1."""
def load_character(
    library: AssetLibrary, character: str = "sarge", skin: str = "default"
) -> ModelAsset {
    animations: list[list[int]] = [];
    config = "models/players/" + character + "/animation.cfg";
    for line in library.read(config).decode("utf-8").splitlines() {
        fields = line.split("//")[0].split();
        if len(fields) >= 4 and fields[0] and fields[0][0] in "0123456789" {
            animations.append([int(fields[0]), int(fields[1])]);
        }
    }
    if len(animations) < 25 { raise ValueError("Incomplete player animations"); }
    lower = player_part(library, "lower", character, skin);
    upper = player_part(library, "upper", character, skin);
    head = player_part(library, "head", character, skin);
    offset = animations[13][0] - animations[6][0];
    model = AnimatedModel();
    skins: list[Texture] = [];
    parts = [lower, upper, head, library.model("models/weapons2/machinegun/machinegun.md3")];
    for part in range(4) {
        source = parts[part];
        for surface in source.model.surfaces {
            output = AnimatedSurface(name=surface.name, indices=surface.indices, uv=surface.uv, stages=surface.stages);
            for action in ["stand", "run", "attack", "death"] {
                legs = 15 if action == "run" else 22;
                torso = 7 if action == "attack" else 11;
                count = abs(animations[legs][1]) if action == "run" else (
                    abs(animations[torso][1]) if action == "attack" else 1
                );
                if action == "death" {
                    count = abs(animations[0][1]);
                }
                for frame in range(count) {
                    leg_frame = animations[legs][0] - offset + (frame if action == "run" else 0);
                    torso_frame = animations[torso][0] + (frame if action == "attack" else 0);
                    # BOTH_* sequences share frame numbers across legs and torso.
                    if action == "death" {
                        leg_frame = animations[0][0] + frame;
                        torso_frame = leg_frame;
                    }
                    index = leg_frame if part == 0 else (torso_frame if part == 1 else 0);
                    if index < 0 or index >= len(surface.frames) { raise ValueError("Player animation out of range"); }
                    original = surface.frames[index];
                    pose = AnimationFrame(name=action + str(frame));
                    torso_tag = tag_at(lower.model, leg_frame, "tag_torso");
                    head_tag = tag_at(upper.model, torso_frame, "tag_weapon" if part == 3 else "tag_head");
                    for vertex in original.vertices {
                        point = transform(head_tag, vertex) if part >= 2 else vertex;
                        pose.vertices.append(transform(torso_tag, point) if part > 0 else point);
                    }
                    for normal in original.normals {
                        point = transform(head_tag, normal, True) if part >= 2 else normal;
                        pose.normals.append(transform(torso_tag, point, True) if part > 0 else point);
                    }
                    output.frames.append(pose);
                }
            }
            model.surfaces.append(output);
        }
        skins.extend(source.skins);
    }
    return ModelAsset(model=model, skins=skins);
}
