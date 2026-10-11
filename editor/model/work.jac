"""A model's work file: everything the editor knows of a model, as text a
line at a time. The games' files keep a model as a game draws it (points as
bytes or sixty-fourths, no bones, nothing of what was in hand); this keeps
the graph as it is, so work is taken up where it was left: the parts with
their poses to the last decimal, what is picked of each, the tags, the
bones with what they carry, and the frame and part in hand.

    qpmodel 1
    model <name>
    hand <frame> <part>
    part <name>
    skin <name>
    corners <numbers>
    uvs <numbers>
    picked points|faces <numbers>
    pose <name>
    points <x y z ...>
    tag <name>
    at <origin: x y z> <three axes: nine numbers>
    rig
    <the bones, as a .rig file has them>"""
import from engine.math.vec3 { Vec3 }
import from .document { ModelDoc, Part, Pose, Tag, HasPart, HasPose, HasTag }

def:priv work_number(value: float) -> str {
    near = round(value, 6);
    return str(int(near)) if near == float(int(near)) else str(near);
}

def:priv work_spots(points: list[Vec3]) -> str {
    words: list[str] = [];
    for point in points {
        words.append(work_number(point.x));
        words.append(work_number(point.y));
        words.append(work_number(point.z));
    }
    return " ".join(words);
}

"""A name as one line holds it: no ends of lines in it."""
def:priv work_name(name: str) -> str {
    return name.replace("\n", " ").replace("\r", " ").strip();
}

"""The model as its work file's text."""
def work_text(doc: ModelDoc) -> str {
    lines = ["qpmodel 1", "model " + work_name(doc.name), "hand " + str(doc.frame) + " " + str(doc.part_now)];
    for part in doc.parts() {
        lines.append("part " + work_name(part.name));
        for skin in part.skins {
            lines.append("skin " + work_name(skin));
        }
        lines.append("corners " + " ".join([str(corner) for corner in part.corners]));
        lines.append("uvs " + " ".join([work_number(place) for place in part.uvs]));
        if len(part.picked_points) > 0 {
            lines.append("picked points " + " ".join([str(index) for index in part.picked_points]));
        }
        if len(part.picked_faces) > 0 {
            lines.append("picked faces " + " ".join([str(index) for index in part.picked_faces]));
        }
        for pose in doc.poses(part) {
            lines.append("pose " + work_name(pose.name));
            lines.append("points " + work_spots(pose.points));
        }
    }
    for tag in doc.tags() {
        lines.append("tag " + work_name(tag.name));
        for index in range(min(len(tag.origins), len(tag.axes))) {
            lines.append("at " + work_spots([tag.origins[index]]) + " " + work_spots(tag.axes[index]));
        }
    }
    if len(doc.bones()) > 0 {
        lines.append("rig");
        lines.append(doc.rig_text().rstrip("\n"));
    }
    return "\n".join(lines) + "\n";
}

def:priv work_floats(words: list[str]) -> list[float] {
    return [float(word) for word in words if word];
}

def:priv work_ints(words: list[str]) -> list[int] {
    return [int(word) for word in words if word];
}

def:priv work_points(numbers: list[float]) -> list[Vec3] {
    return [Vec3(x=numbers[at * 3], y=numbers[at * 3 + 1], z=numbers[at * 3 + 2]) for at in range(len(numbers) // 3)];
}

"""A work file's text as a model again. None when it is not one, or a line
of it cannot be read; a part's numbers that point past its points make it
no model either."""
def doc_from_work(text: str) -> ModelDoc | None {
    lines = text.split("\n");
    if len(lines) == 0 or lines[0].strip() != "qpmodel 1" {
        return None;
    }
    doc = ModelDoc();
    reading: Part | None = None;
    stood: Pose | None = None;
    hung: Tag | None = None;
    in_hand = [0, 0];
    bones: list[str] = [];
    past_model = False;
    try {
        for raw in lines[1:] {
            if past_model {
                bones.append(raw);
                continue;
            }
            line = raw.strip();
            if not line or line.startswith("//") {
                continue;
            }
            word = line.split(" ")[0];
            rest = line[len(word):].strip();
            if word == "rig" {
                past_model = True;
            } elif word == "model" {
                doc.name = rest if rest else "model";
            } elif word == "hand" {
                numbers = work_ints(rest.split(" "));
                if len(numbers) >= 2 {
                    in_hand = [numbers[0], numbers[1]];
                }
            } elif word == "part" {
                reading = Part(name=rest if rest else "part");
                doc +>:HasPart(index=len(doc.parts())):+> reading;
                stood = None;
            } elif word == "tag" {
                hung = Tag(name=rest);
                doc +>:HasTag:+> hung;
            } elif word == "at" and hung is not None {
                spots = work_points(work_floats(rest.split(" ")));
                if len(spots) != 4 {
                    return None;
                }
                hung.origins.append(spots[0]);
                hung.axes.append(spots[1:]);
            } elif reading is None {
                return None;
            } elif word == "skin" {
                reading.skins.append(rest);
            } elif word == "corners" {
                reading.corners = work_ints(rest.split(" "));
            } elif word == "uvs" {
                reading.uvs = work_floats(rest.split(" "));
            } elif word == "picked" and rest.startswith("points") {
                reading.picked_points = work_ints(rest[6:].split(" "));
            } elif word == "picked" and rest.startswith("faces") {
                reading.picked_faces = work_ints(rest[5:].split(" "));
            } elif word == "pose" {
                stood = Pose(name=rest);
                reading +>:HasPose(index=len(doc.poses(reading))):+> stood;
            } elif word == "points" and stood is not None {
                stood.points = work_points(work_floats(rest.split(" ")));
            } else {
                return None;
            }
        }
    } except ValueError {
        return None;
    }
    if len(doc.parts()) == 0 {
        return None;
    }
    for part in doc.parts() {
        held = doc.poses(part);
        if len(held) == 0 or len(part.corners) % 3 != 0 {
            return None;
        }
        count = len(held[0].points);
        if len([corner for corner in part.corners if corner < 0 or corner >= count]) > 0 {
            return None;
        }
        if len([pose for pose in held if len(pose.points) != count]) > 0 {
            return None;
        }
        part.picked_points = [index for index in part.picked_points if index >= 0 and index < count];
        part.picked_faces = [index for index in part.picked_faces if index >= 0 and index < len(part.corners) // 3];
    }
    doc.frame = max(0, min(in_hand[0], doc.frames() - 1));
    doc.part_now = max(0, min(in_hand[1], len(doc.parts()) - 1));
    if len(bones) > 0 {
        doc.read_rig("\n".join(bones));
    }
    doc.dirty = False;
    return doc;
}
