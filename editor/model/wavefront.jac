"""Meshes written out and read in as Wavefront OBJ text, the form every
modelling program trades in: a `v` line a point, a `vt` line a place on the
skin, an `f` line a face. Quake's z is up and OBJ's y is, so points are
turned on the way out and back on the way in."""
import from engine.math.vec3 { Vec3 }
import from .mesh { Mesh }

"""A number as a file has it: no more places than it needs."""
def:priv plain(value: float) -> str {
    words = str(round(value, 5));
    if "." in words {
        words = words.rstrip("0").rstrip(".");
    }
    return "0" if words in ["-0", ""] else words;
}

def mesh_obj(mesh: Mesh, name: str = "model") -> str {
    lines = ["# Written by the QuakePassion studio.", "o " + (name if name else "model")];
    for point in mesh.points {
        lines.append("v " + plain(point.x) + " " + plain(point.z) + " " + plain(-point.y));
    }
    skinned = len(mesh.uvs) == len(mesh.points) * 2 and len(mesh.uvs) > 0;
    if skinned {
        for index in range(len(mesh.points)) {
            # OBJ counts up the skin; a skin's own rows run down it.
            lines.append("vt " + plain(mesh.uvs[index * 2]) + " " + plain(1.0 - mesh.uvs[index * 2 + 1]));
        }
    }
    for index in range(mesh.triangles()) {
        words = "f";
        for k in range(3) {
            place = str(mesh.corners[index * 3 + k] + 1);
            words += " " + (place + "/" + place if skinned else place);
        }
        lines.append(words);
    }
    return "\n".join(lines) + "\n";
}

"""Read OBJ text. A face of more than three corners is cut into a fan of
triangles; a point used with more than one place on the skin is doubled, so
that each point has one."""
def obj_mesh(text: str) -> Mesh {
    spots: list[Vec3] = [];
    places: list[float] = [];
    made = Mesh();
    known: dict[str, int] = {};
    faces: list[list[str]] = [];
    for raw in text.split("\n") {
        words = raw.strip().split();
        if len(words) < 3 {
            continue;
        }
        try {
            if words[0] == "v" and len(words) >= 4 {
                spots.append(Vec3(x=float(words[1]), y=-float(words[3]), z=float(words[2])));
            } elif words[0] == "vt" {
                places.append(float(words[1]));
                places.append(1.0 - float(words[2]));
            } elif words[0] == "f" and len(words) >= 4 {
                faces.append(words[1:]);
            }
        } except ValueError {
            continue;
        }
    }
    skinned = len(places) > 0;
    # A file that gives every point one place on the skin, or none, keeps
    # its points as they are numbered.
    as_numbered = not skinned or len(places) == len(spots) * 2;
    for face in faces {
        for word in face {
            parts = word.split("/");
            if not parts[0].isdigit() or int(parts[0]) < 1 or int(parts[0]) > len(spots)
                or (len(parts) > 1 and parts[1] != "" and parts[1] != parts[0]) or (skinned and len(parts) < 2) {
                as_numbered = False;
            }
        }
    }
    if as_numbered {
        made.points = spots;
        made.uvs = places;
        for face in faces {
            for index in range(1, len(face) - 1) {
                made.corners.extend(
                    [int(face[0].split("/")[0]) - 1, int(face[index].split("/")[0]) - 1, int(face[index + 1].split("/")[0]) - 1]
                );
            }
        }
        return made;
    }
    for face in faces {
        corners: list[int] = [];
        for word in face {
            parts = word.split("/");
            at = int(parts[0]) if parts[0].lstrip("-").isdigit() else 0;
            # A number below zero counts back from the last point read.
            at = at - 1 if at > 0 else len(spots) + at;
            on_skin = -1;
            if len(parts) > 1 and parts[1].lstrip("-").isdigit() {
                on_skin = int(parts[1]);
                on_skin = on_skin - 1 if on_skin > 0 else len(places) // 2 + on_skin;
            }
            if at < 0 or at >= len(spots) {
                corners = [];
                break;
            }
            key = str(at) + "/" + str(on_skin);
            if key not in known {
                made.points.append(spots[at]);
                if skinned {
                    held = on_skin if on_skin >= 0 and on_skin * 2 + 1 < len(places) else -1;
                    made.uvs.append(places[held * 2] if held >= 0 else 0.0);
                    made.uvs.append(places[held * 2 + 1] if held >= 0 else 0.0);
                }
                known[key] = len(made.points) - 1;
            }
            corners.append(known[key]);
        }
        for index in range(1, len(corners) - 1) {
            made.corners.extend([corners[0], corners[index], corners[index + 1]]);
        }
    }
    return made;
}
