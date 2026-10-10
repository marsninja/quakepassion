"""A built level's brushes as a map: what makes a shipped Quake II or Quake
III level, or a generated one, editable.

Those formats keep each brush as its planes. A brush's sides get their
materials back from the faces the level draws on them, and each material's
lie from the face's own texture coordinates; a side no face is drawn on
takes a neighbour's material. Quake's own format keeps no brushes, so there
is nothing here for it."""
import from engine.formats.bsp { Bsp, Face, Brush, Model }
import from engine.math.vec3 { Vec3 }
import from .map { MapItem }
import from ..geometry.brush { Side, Plane3, Mapping, classic_mapping, brush_windings, windings_bounds }

"""A level texture's name as scenes name materials."""
def level_material(game: str, name: str) -> str {
    if not name or ":" in name {
        return name;
    }
    if game == "q2" or game == "q3" {
        return game + ":" + name;
    }
    return name;
}

"""Four unknowns from four equations, each row its coefficients and then its
right side. None when the equations do not pin them down."""
def:priv solved(rows: list[list[float]]) -> list[float] | None {
    for column in range(4) {
        best = column;
        for row in range(column + 1, 4) {
            if abs(rows[row][column]) > abs(rows[best][column]) {
                best = row;
            }
        }
        if abs(rows[best][column]) < 0.0000001 {
            return None;
        }
        held = rows[column];
        rows[column] = rows[best];
        rows[best] = held;
        for row in range(4) {
            if row == column {
                continue;
            }
            factor = rows[row][column] / rows[column][column];
            for k in range(column, 5) {
                rows[row][k] -= factor * rows[column][k];
            }
        }
    }
    return [rows[i][4] / rows[i][i] for i in range(4)];
}

"""How a face's material lies, from the texture coordinates of three of its
corners: the axes in the face's plane that reproduce them. None when the
face has no coordinates or its corners are in a line."""
def face_mapping(face: Face, width: int, height: int) -> Mapping | None {
    count = len(face.vertices);
    if count < 3 or len(face.uv) < count * 2 {
        return None;
    }
    # The corner furthest from the line through the first two.
    third = 2;
    reach = 0.0;
    along = face.vertices[1].sub(face.vertices[0]);
    for i in range(2, count) {
        out = along.cross(face.vertices[i].sub(face.vertices[0])).length();
        if out > reach {
            reach = out;
            third = i;
        }
    }
    if reach < 0.001 {
        return None;
    }
    picks = [0, 1, third];
    found: list[list[float]] = [];
    for part in range(2) {
        size = float(max(1, width if part == 0 else height));
        rows: list[list[float]] = [];
        for i in picks {
            corner = face.vertices[i];
            rows.append([corner.x, corner.y, corner.z, 1.0, face.uv[i * 2 + part] * size]);
        }
        rows.append([face.normal.x, face.normal.y, face.normal.z, 0.0, 0.0]);
        answer = solved(rows);
        if answer is None {
            return None;
        }
        found.append(answer);
    }
    s_long = Vec3(x=found[0][0], y=found[0][1], z=found[0][2]);
    t_long = Vec3(x=found[1][0], y=found[1][1], z=found[1][2]);
    if s_long.length() < 0.000001 or t_long.length() < 0.000001 {
        return None;
    }
    return Mapping(
        s_axis=s_long.normalized(),
        t_axis=t_long.normalized(),
        s_shift=found[0][3],
        t_shift=found[1][3],
        s_scale=1.0 / s_long.length(),
        t_scale=1.0 / t_long.length()
    );
}

"""A level's entities and brushes as a map's. `entities` are the level's
entities as fields; one whose `model` is "*n" gets model n's brushes, and
the world gets model 0's. No items when the level keeps no brushes."""
def bsp_items(bsp: Bsp, entities: list[dict[str, str]], fallback: str = "blockout") -> list[MapItem] {
    if len(bsp.brushes) == 0 {
        return [];
    }
    by_model: list[list[list[Side]]] = [];
    for model in bsp.models {
        brushes: list[list[Side]] = [];
        lows: list[Vec3] = [];
        highs: list[Vec3] = [];
        for index in model.brushes {
            if index < 0 or index >= len(bsp.brushes) {
                continue;
            }
            sides: list[Side] = [];
            for plane_index in bsp.brushes[index].planes {
                if plane_index < 0 or plane_index >= len(bsp.planes) {
                    continue;
                }
                record = bsp.planes[plane_index];
                sides.append(
                    Side(
                        plane=Plane3(normal=record.normal, dist=record.distance),
                        mapping=classic_mapping(record.normal, 0.0, 0.0, 0.0, 1.0, 1.0)
                    )
                );
            }
            # The sides that make a face; a level's extra bevel planes do not.
            outlines = brush_windings(sides);
            kept: list[Side] = [];
            for i in range(len(sides)) {
                if len(outlines[i]) >= 3 {
                    kept.append(sides[i]);
                }
            }
            box = windings_bounds(brush_windings(kept));
            if len(kept) < 4 or box is None {
                continue;
            }
            brushes.append(kept);
            lows.append(box[0]);
            highs.append(box[1]);
        }
        # Each face names the material of the side it is drawn on.
        last = min(len(bsp.faces), model.first_face + model.face_count);
        for face_index in range(max(0, model.first_face), last) {
            face = bsp.faces[face_index];
            if len(face.vertices) < 3 or face.patch {
                continue;
            }
            middle = Vec3();
            for vertex in face.vertices {
                middle = middle.add(vertex);
            }
            middle = middle.scale(1.0 / float(len(face.vertices)));
            image = bsp.textures[face.texture] if face.texture >= 0 and face.texture < len(bsp.textures) else None;
            name = level_material(bsp.game, image.name if image is not None else "");
            lie = face_mapping(face, image.width if image is not None else 64, image.height if image is not None else 64);
            for b in range(len(brushes)) {
                if middle.x < lows[b].x - 1.0 or middle.x > highs[b].x + 1.0 or middle.y < lows[b].y - 1.0
                    or middle.y > highs[b].y + 1.0 or middle.z < lows[b].z - 1.0 or middle.z > highs[b].z + 1.0 {
                    continue;
                }
                on = -1;
                inside = True;
                for (s, side) in enumerate(brushes[b]) {
                    away = side.plane.side(middle);
                    if away > 0.5 {
                        inside = False;
                        break;
                    }
                    if abs(away) < 0.5 and side.plane.normal.dot(face.normal) > 0.999 {
                        on = s;
                    }
                }
                if not inside or on < 0 or brushes[b][on].material {
                    continue;
                }
                old = brushes[b][on];
                brushes[b][on] = Side(
                    plane=old.plane, material=name, mapping=lie if lie is not None else old.mapping
                );
            }
        }
        # A side nothing is drawn on takes a neighbour's material.
        for brush in brushes {
            spare = "";
            for side in brush {
                if side.material {
                    spare = side.material;
                    break;
                }
            }
            if not spare {
                spare = "clip" if len(by_model) == 0 else fallback;
            }
            for (s, side) in enumerate(brush) {
                if not side.material {
                    brush[s] = Side(plane=side.plane, material=spare, mapping=side.mapping);
                }
            }
        }
        by_model.append(brushes);
    }
    items: list[MapItem] = [];
    world_seen = False;
    for fields in entities {
        kept_fields: dict[str, str] = dict(fields);
        name = kept_fields.get("classname", "");
        model_word = kept_fields.get("model", "");
        if name == "worldspawn" and not world_seen {
            world_seen = True;
            items.append(MapItem(fields=kept_fields, brushes=by_model[0] if len(by_model) > 0 else []));
        } elif len(model_word) > 1 and model_word[0] == "*" and model_word[1:].isdigit() {
            number = int(model_word[1:]);
            kept_fields.pop("model", None);
            items.append(MapItem(fields=kept_fields, brushes=by_model[number] if number < len(by_model) else []));
        } else {
            items.append(MapItem(fields=kept_fields));
        }
    }
    if not world_seen {
        items.insert(0, MapItem(fields={"classname": "worldspawn"}, brushes=by_model[0] if len(by_model) > 0 else []));
    }
    return items;
}
