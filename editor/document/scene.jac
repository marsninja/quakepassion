"""The studio's document is a graph.

A Scene holds an Item for every entity of the map and points at the selected
ones with Selected edges. Every edit is a walker that travels from the scene
to the selection and writes down what it changed, so each edit undoes; the
journal keeps those steps. Nothing here knows about the window: the same
edits run from the interface, from the console and from tests."""
import from engine.formats.bsp { MapEntity, entity_text }
import from engine.math.vec3 { Vec3 }
import from ..geometry.brush {
    Side,
    Plane3,
    Mapping,
    brush_windings,
    windings_bounds,
    clip_sides,
    side_turned,
    turned_z
}
import math;
import from ..formats.map { MapItem, MapFile }
import from ..classes.registry { flag_put }
import from ..geometry.csg {
    carve_sides,
    common_sides,
    hollow_sides,
    merged_sides,
    corners_moved,
    brush_corners,
    joined_pieces
}
import from ..geometry.mapping {
    side_like,
    mapping_slid,
    mapping_sized,
    mapping_spun,
    mapping_flat,
    mapping_fitted,
    mapping_plain,
    mapping_same,
    side_stretched,
    side_spun,
    spun_about,
    axis_vector
}

edge Holds: Scene --> Item {}

"""An entity owns the brushes that make it: the world its walls, a door its
slab."""
edge Owns: Item --> Solid {}

edge Selected: Scene --> Item | Solid {}

"""An entity fires another: its `target` (or `killtarget`) is the other's
`targetname`. The edges are drawn from the fields (Scene.relink), so the
map's logic is a graph that walkers travel."""
edge Fires: Item --> Item {
    has key: str = "target";
}

"""One selected face: the brush it is a side of, and which side."""
edge Faced: Scene --> Solid {
    has side: int = -1;
}

"""One entity of the map: its key/value fields, as the map's entity lump
writes them. `serial` names it for the life of the document; `held` is false
once it has been deleted (the journal still knows it, so the delete undoes)."""
node Item {
    has serial: int = 0,
        fields: dict[str, str] = {},
        held: bool = True;

    def classname -> str {
        return self.fields.get("classname", "");
    }

    """Its `origin`, when it has one that reads as three numbers."""
    def origin -> Vec3 | None {
        return read_vector(self.fields.get("origin", ""));
    }

    """The map model it draws ("*3" is 3), or -1 for a point entity."""
    def model -> int {
        name = self.fields.get("model", "");
        if len(name) > 1 and name[0] == "*" and name[1:].isdigit() {
            return int(name[1:]);
        }
        return -1;
    }

    """What lists call it: its targetname when it has one."""
    def title -> str {
        name = self.fields.get("targetname", "");
        return self.classname() + (" (" + name + ")" if name else "");
    }
}

"""One brush of the document: the space behind its sides. A shipped map's
geometry is not in the document; these are the brushes made or opened in the
studio."""
node Solid {
    has serial: int = 0,
        sides: list[Side] = [],
        held: bool = True;

    """The outline of each side."""
    def outlines -> list[list[Vec3]] {
        return brush_windings(self.sides);
    }

    """The box around it: [low, high], or none when its sides enclose
    nothing."""
    def bounds -> list[Vec3] | None {
        return windings_bounds(self.outlines());
    }
}

"""A side moved by `delta`, its material staying where it lies on the face
(the mapping's shift takes up the move)."""
def side_moved(side: Side, delta: Vec3) -> Side {
    mapping = side.mapping;
    return Side(
        plane=side.plane.moved(delta),
        points=[point.add(delta) for point in side.points],
        material=side.material,
        mapping=Mapping(
            s_axis=mapping.s_axis,
            t_axis=mapping.t_axis,
            s_shift=mapping.s_shift - delta.dot(mapping.s_axis) / mapping.s_scale,
            t_shift=mapping.t_shift - delta.dot(mapping.t_axis) / mapping.t_scale,
            s_scale=mapping.s_scale,
            t_scale=mapping.t_scale,
            rotation=mapping.rotation
        ),
        contents=side.contents,
        flags=side.flags,
        value=side.value
    );
}

"""Whether sides enclose a brush: at least four of them keep an outline."""
def sides_enclose(sides: list[Side]) -> bool {
    kept = 0;
    for outline in brush_windings(sides) {
        if len(outline) >= 3 {
            kept += 1;
        }
    }
    return kept >= 4;
}

"""Three numbers from an entity field, or none."""
def read_vector(text: str) -> Vec3 | None {
    parts = text.split();
    if len(parts) != 3 {
        return None;
    }
    try {
        return Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
    } except ValueError {
        return None;
    }
}

"""A number as an entity field writes it: whole numbers without a point."""
def field_number(value: float) -> str {
    rounded = round(value);
    if abs(value - float(rounded)) < 0.0005 {
        return str(int(rounded));
    }
    text = str(round(value, 3));
    return text;
}

def write_vector(value: Vec3) -> str {
    return field_number(value.x) + " " + field_number(value.y) + " " + field_number(value.z);
}

"""Whether the level is built from a point entity itself, not only from
brushes: a linked prefab's contents, a light's light."""
def built_from(item: Item) -> bool {
    name = item.classname();
    # A group's fields may ask for copies of its brushes.
    return name == "misc_prefab" or name == "func_group" or name.startswith("light");
}

"""One reversible change."""
obj Change {
    def undo abst;
    def redo abst;
    """Whether it changes what the level is built from: its brushes, or an
    entity that owns some."""
    def reshapes -> bool abst;
}

"""A field set, changed or removed (`None` is "not there")."""
obj FieldChange(Change) {
    has item: Item,
        key: str,
        before: str | None = None,
        after: str | None = None;

    def put(value: str | None) {
        if value is None {
            self.item.fields.pop(self.key, None);
        } else {
            self.item.fields[self.key] = value;
        }
    }

    def undo {
        self.put(self.before);
    }

    def redo {
        self.put(self.after);
    }

    def reshapes -> bool {
        # A linked prefab is built where its entity stands, and a light
        # lights what is round it.
        return built_from(self.item);
    }
}

"""An item entering or leaving the document."""
obj HoldChange(Change) {
    has item: Item,
        held: bool;

    def undo {
        self.item.held = not self.held;
    }

    def redo {
        self.item.held = self.held;
    }

    def reshapes -> bool {
        return bool([self.item->:Owns:->]) or built_from(self.item);
    }
}

"""A brush entering or leaving the document."""
obj SolidHold(Change) {
    has solid: Solid,
        held: bool;

    def undo {
        self.solid.held = not self.held;
    }

    def redo {
        self.solid.held = self.held;
    }

    def reshapes -> bool {
        return True;
    }
}

"""A brush's sides replaced: moved, resized, cut or retextured."""
obj SidesChange(Change) {
    has solid: Solid,
        before: list[Side],
        after: list[Side];

    def undo {
        self.solid.sides = self.before;
    }

    def redo {
        self.solid.sides = self.after;
    }

    def reshapes -> bool {
        return True;
    }
}

"""A brush handed from one entity to another."""
obj OwnChange(Change) {
    has solid: Solid,
        before: Item,
        after: Item;

    def hand(giver: Item, taker: Item) {
        if self.solid in [giver->:Owns:->][?:Solid] {
            giver del->:Owns:-> self.solid;
        }
        taker +>:Owns:+> self.solid;
    }

    def undo {
        self.hand(self.after, self.before);
    }

    def redo {
        self.hand(self.before, self.after);
    }

    def reshapes -> bool {
        return True;
    }
}

"""One edit as the journal keeps it: what to call it and what it changed."""
obj Step {
    has label: str,
        changes: list[Change] = [];

    def reshapes -> bool {
        for change in self.changes {
            if change.reshapes() {
                return True;
            }
        }
        return False;
    }
}

"""The edits made, newest last, and the ones undone since."""
obj Journal {
    has done: list[Step] = [],
        undone: list[Step] = [],
        limit: int = 1000;
}

"""Set a field on every selected item (`value` None removes it)."""
walker SetField {
    has key: str,
        value: str | None,
        step: Step;

    can start with Scene entry {
        visit [here->:Selected:->];
    }

    can apply with Item entry {
        before: str | None = here.fields.get(self.key);
        if before == self.value {
            return;
        }
        change = FieldChange(item=here, key=self.key, before=before, after=self.value);
        change.redo();
        self.step.changes.append(change);
    }
}

"""Take every selected item out of the document."""
walker Remove {
    has step: Step;

    can start with Scene entry {
        visit [here->:Selected:->];
    }

    can apply with Item entry {
        # The world is the map itself and stays.
        if not here.held or here.classname() == "worldspawn" {
            return;
        }
        change = HoldChange(item=here, held=False);
        change.redo();
        self.step.changes.append(change);
    }

    can cut with Solid entry {
        if not here.held {
            return;
        }
        change = SolidHold(solid=here, held=False);
        change.redo();
        self.step.changes.append(change);
    }
}

"""Move every selected item that has an origin, and every selected brush. An
entity made of brushes moves by moving them."""
walker Shift {
    has delta: Vec3,
        step: Step,
        # Brushes already moved, so one selected with its entity moves once.
        slid: list[Solid] = [];

    can start with Scene entry {
        visit [here->:Selected:->];
    }

    can apply with Item entry {
        at = here.origin();
        if at is None {
            visit [here->:Owns:->];
            return;
        }
        change = FieldChange(
            item=here, key="origin", before=here.fields.get("origin"), after=write_vector(at.add(self.delta))
        );
        change.redo();
        self.step.changes.append(change);
    }

    can slide with Solid entry {
        if not here.held or here in self.slid {
            return;
        }
        self.slid.append(here);
        change = SidesChange(
            solid=here, before=here.sides, after=[side_moved(side, self.delta) for side in here.sides]
        );
        change.redo();
        self.step.changes.append(change);
    }
}

"""Copy every selected entity, `offset` away from the original: a point
entity by its origin, an entity made of the scene's own brushes with copies
of them. A shipped map's brush entities are not copied: two cannot share a
map model."""
walker Clone {
    has offset: Vec3,
        step: Step,
        scene: Scene | None = None,
        made: list[Item] = [],
        made_solids: list[Solid] = [],
        # Brushes copied along with their entity.
        copied: list[Solid] = [];

    can start with Scene entry {
        self.scene = here;
        visit [here->:Selected:->];
    }

    can apply with Item entry {
        scene = self.scene;
        if scene is None or here.model() >= 0 or here.classname() == "worldspawn" {
            return;
        }
        owned = [solid for solid in [here->:Owns:->][?:Solid] if solid.held];
        if here.origin() is None and len(owned) == 0 {
            return;
        }
        copy = scene.add_item(dict(here.fields));
        at = copy.origin();
        if at is not None {
            copy.fields["origin"] = write_vector(at.add(self.offset));
        }
        self.step.changes.append(HoldChange(item=copy, held=True));
        self.made.append(copy);
        for solid in owned {
            twin = scene.add_solid(copy, [side_moved(side, self.offset) for side in solid.sides]);
            self.step.changes.append(SolidHold(solid=twin, held=True));
            self.copied.append(solid);
        }
    }

    can copy_solid with Solid entry {
        scene = self.scene;
        if scene is None or not here.held or here in self.copied {
            return;
        }
        owners = [here<-:Owns:<-][?:Item];
        if not owners {
            return;
        }
        copy = scene.add_solid(owners[0], [side_moved(side, self.offset) for side in here.sides]);
        self.step.changes.append(SolidHold(solid=copy, held=True));
        self.made_solids.append(copy);
    }
}

"""Give every selected brush a material: on every side, or on one."""
walker Paint {
    has material: str,
        step: Step,
        side: int = -1;

    can start with Scene entry {
        visit [here->:Selected:->];
    }

    can paint with Solid entry {
        changed = False;
        after: list[Side] = [];
        for (index, old) in enumerate(here.sides) {
            if (self.side < 0 or index == self.side) and old.material != self.material {
                after.append(
                    Side(
                        plane=old.plane,
                        points=old.points,
                        material=self.material,
                        mapping=old.mapping,
                        contents=old.contents,
                        flags=old.flags,
                        value=old.value
                    )
                );
                changed = True;
            } else {
                after.append(old);
            }
        }
        if changed {
            change = SidesChange(solid=here, before=here.sides, after=after);
            change.redo();
            self.step.changes.append(change);
        }
    }
}

"""Cut every selected brush along a plane, keeping what is behind it
("back"), in front of it ("front") or both as two brushes. A brush wholly on
the side not kept goes."""
walker Clip {
    has plane: Plane3,
        keep: str,
        step: Step,
        material: str = "",
        scene: Scene | None = None,
        made: list[Solid] = [];

    can start with Scene entry {
        self.scene = here;
        visit [here->:Selected:->];
    }

    can cut with Solid entry {
        scene = self.scene;
        if scene is None or not here.held {
            return;
        }
        parts = clip_sides(here.sides, self.plane, self.material);
        back = parts[0];
        front = parts[1];
        kept = front if self.keep == "front" else back;
        if not kept {
            if self.keep != "both" {
                gone = SolidHold(solid=here, held=False);
                gone.redo();
                self.step.changes.append(gone);
            }
            return;
        }
        if not back or not front {
            # The plane misses it and it is on the side kept.
            return;
        }
        change = SidesChange(solid=here, before=here.sides, after=kept);
        change.redo();
        self.step.changes.append(change);
        if self.keep == "both" {
            owners = [here<-:Owns:<-][?:Item];
            if owners {
                other = scene.add_solid(owners[0], front);
                self.step.changes.append(SolidHold(solid=other, held=True));
                self.made.append(other);
            }
        }
    }
}

"""Turn the selection about the vertical line through a pivot: brushes turn
with their materials, and point entities swing round it and face the new
way."""
walker Turn {
    has pivot: Vec3,
        angle: float,
        step: Step,
        # 0, 1 or 2: the x, y or vertical axis.
        axis: int = 2,
        turned: list[Solid] = [];

    can start with Scene entry {
        visit [here->:Selected:->];
    }

    can swing with Item entry {
        at = here.origin();
        if at is None {
            visit [here->:Owns:->];
            return;
        }
        moved = self.pivot.add(spun_about(at.sub(self.pivot), axis_vector(self.axis), self.angle));
        change = FieldChange(
            item=here, key="origin", before=here.fields.get("origin"), after=write_vector(moved)
        );
        change.redo();
        self.step.changes.append(change);
        facing = here.fields.get("angle");
        if facing is not None and self.axis == 2 {
            try {
                # Up (-1) and down (-2) are not directions to turn.
                if float(facing) >= 0.0 {
                    face = FieldChange(
                        item=here,
                        key="angle",
                        before=facing,
                        after=field_number((float(facing) + math.degrees(self.angle)) % 360.0)
                    );
                    face.redo();
                    self.step.changes.append(face);
                }
            } except ValueError {
                return;
            }
        }
    }

    can spin with Solid entry {
        if not here.held or here in self.turned {
            return;
        }
        self.turned.append(here);
        change = SidesChange(
            solid=here,
            before=here.sides,
            after=[
                (side_turned(side, self.pivot, self.angle) if self.axis == 2 else side_spun(
                    side, self.pivot, self.axis, self.angle
                ))
                for side in here.sides
            ]
        );
        change.redo();
        self.step.changes.append(change);
    }
}

"""What to do to a face: give it a material, or change how its material
lies. `sizes` gives the size in texels of each material a fit may meet."""
obj FaceEdit {
    has how: str,
        s: float = 0.0,
        t: float = 0.0,
        material: str = "",
        sizes: dict[str, list[int]] = {};

    """The side as the edit leaves it: the same side when it changes
    nothing."""
    def apply(side: Side, outline: list[Vec3]) -> Side {
        if self.how == "material" {
            return side if side.material == self.material else side_like(side, self.material);
        }
        old = side.mapping;
        fresh = old;
        if self.how == "shift" {
            fresh = mapping_slid(old, self.s, self.t);
        } elif self.how == "shift_to" {
            fresh = mapping_slid(old, self.s - old.s_shift, self.t - old.t_shift);
        } elif self.how == "turn_to" {
            fresh = mapping_spun(old, self.s - old.rotation);
        } elif self.how == "scale" {
            fresh = mapping_sized(old, self.s, self.t);
        } elif self.how == "turn" {
            fresh = mapping_spun(old, self.s);
        } elif self.how == "reset" {
            fresh = mapping_plain(side.plane.normal);
        } elif self.how == "flat" {
            fresh = mapping_flat(side.plane.normal);
        } elif self.how == "fit" {
            size = self.sizes.get(side.material, [64, 64]);
            fresh = mapping_fitted(
                old,
                outline,
                size[0],
                size[1],
                self.s if self.s > 0.0 else 1.0,
                self.t if self.t > 0.0 else 1.0
            );
        }
        if mapping_same(old, fresh) and abs(old.rotation - fresh.rotation) < 0.000001 {
            return side;
        }
        return side_like(side, None, fresh);
    }
}

"""Apply a face edit to every selected face, and to every side of every
selected brush."""
walker Reface {
    has change: FaceEdit,
        step: Step,
        scene: Scene | None = None,
        seen: list[Solid] = [];

    can start with Scene entry {
        self.scene = here;
        visit [here->:Faced:->];
        visit [here->:Selected:->];
    }

    can descend with Item entry {
        visit [here->:Owns:->];
    }

    can remap with Solid entry {
        scene = self.scene;
        if scene is None or not here.held or here in self.seen {
            return;
        }
        self.seen.append(here);
        picked = scene.face_sides(here);
        outlines = here.outlines();
        after: list[Side] = [];
        touched = False;
        for index in range(len(here.sides)) {
            old = here.sides[index];
            if len(picked) > 0 and index not in picked {
                after.append(old);
                continue;
            }
            fresh = self.change.apply(old, outlines[index]);
            if fresh is not old {
                touched = True;
            }
            after.append(fresh);
        }
        if touched {
            swap = SidesChange(solid=here, before=here.sides, after=after);
            swap.redo();
            self.step.changes.append(swap);
        }
    }
}

"""Stretch the selection about a pivot by a factor along each axis (-1
mirrors): brushes with their materials, point entities by where they are and,
mirrored, by the way they face."""
walker Stretch {
    has pivot: Vec3,
        factors: Vec3,
        step: Step,
        seen: list[Solid] = [];

    can start with Scene entry {
        visit [here->:Selected:->];
    }

    can place with Item entry {
        at = here.origin();
        if at is None {
            visit [here->:Owns:->];
            return;
        }
        away = at.sub(self.pivot);
        moved = self.pivot.add(
            Vec3(x=away.x * self.factors.x, y=away.y * self.factors.y, z=away.z * self.factors.z)
        );
        change = FieldChange(
            item=here, key="origin", before=here.fields.get("origin"), after=write_vector(moved)
        );
        change.redo();
        self.step.changes.append(change);
        facing = here.fields.get("angle");
        if facing is None or (self.factors.x > 0.0 and self.factors.y > 0.0) {
            return;
        }
        try {
            way = float(facing);
            if way >= 0.0 {
                if self.factors.x < 0.0 {
                    way = 180.0 - way;
                }
                if self.factors.y < 0.0 {
                    way = -way;
                }
                face = FieldChange(item=here, key="angle", before=facing, after=field_number(way % 360.0));
                face.redo();
                self.step.changes.append(face);
            }
        } except ValueError {
            return;
        }
    }

    can reshape with Solid entry {
        if not here.held or here in self.seen {
            return;
        }
        self.seen.append(here);
        after = [side_stretched(side, self.pivot, self.factors) for side in here.sides];
        if not sides_enclose(after) {
            return;
        }
        change = SidesChange(solid=here, before=here.sides, after=after);
        change.redo();
        self.step.changes.append(change);
    }
}

"""Cut the `cutters` out of every other brush of the document. A brush they
reach is left as the convex pieces outside them; one they swallow goes."""
walker Carve {
    has cutters: list[Solid],
        step: Step,
        lined: bool = False,
        scene: Scene | None = None,
        made: list[Solid] = [];

    can start with Scene entry {
        self.scene = here;
        visit [here->:Holds:->];
    }

    can descend with Item entry {
        if here.held {
            visit [here->:Owns:->];
        }
    }

    can cut with Solid entry {
        scene = self.scene;
        if scene is None or not here.held or here in self.cutters or here in self.made {
            return;
        }
        pieces: list[list[Side]] = [here.sides];
        touched = False;
        for cutter in self.cutters {
            left: list[list[Side]] = [];
            for piece in pieces {
                parts = carve_sides(piece, cutter.sides, self.lined);
                if parts is None {
                    left.append(piece);
                } else {
                    touched = True;
                    left.extend(parts);
                }
            }
            pieces = left;
        }
        if not touched {
            return;
        }
        pieces = joined_pieces(pieces);
        if len(pieces) == 0 {
            gone = SolidHold(solid=here, held=False);
            gone.redo();
            self.step.changes.append(gone);
            return;
        }
        change = SidesChange(solid=here, before=here.sides, after=pieces[0]);
        change.redo();
        self.step.changes.append(change);
        owners = [here<-:Owns:<-][?:Item];
        if not owners {
            return;
        }
        for piece in pieces[1:] {
            other = scene.add_solid(owners[0], piece);
            self.step.changes.append(SolidHold(solid=other, held=True));
            self.made.append(other);
        }
    }
}

"""Turn every selected brush into a shell of walls."""
walker Hollow {
    has thickness: float,
        step: Step,
        scene: Scene | None = None,
        made: list[Solid] = [];

    can start with Scene entry {
        self.scene = here;
        visit [here->:Selected:->];
    }

    can shell with Solid entry {
        scene = self.scene;
        if scene is None or not here.held or here in self.made {
            return;
        }
        walls = hollow_sides(here.sides, self.thickness);
        owners = [here<-:Owns:<-][?:Item];
        if len(walls) == 0 or not owners {
            return;
        }
        change = SidesChange(solid=here, before=here.sides, after=walls[0]);
        change.redo();
        self.step.changes.append(change);
        for wall in walls[1:] {
            other = scene.add_solid(owners[0], wall);
            self.step.changes.append(SolidHold(solid=other, held=True));
            self.made.append(other);
        }
    }
}

"""Something wrong with the document, and what it is wrong with."""
obj Finding {
    has words: str,
        item: Item | None = None,
        solid: Solid | None = None,
        # Whether the map will not play as it is.
        grave: bool = False;
}

"""Look over the whole document for what would stop it playing or is likely
a mistake."""
walker Inspect {
    has findings: list[Finding] = [],
        names: list[str] = [],
        aims: list[tuple[Item, str, str]] = [],
        starts: int = 0,
        worlds: int = 0;

    can start with Scene entry {
        visit [here->:Holds:->];
    }

    can look with Item entry {
        if not here.held {
            return;
        }
        classname = here.classname();
        if not classname {
            self.findings.append(Finding(words="An entity has no classname", item=here, grave=True));
        }
        if classname == "worldspawn" {
            self.worlds += 1;
        }
        if classname.startswith("info_player_") {
            self.starts += 1;
        }
        name = here.fields.get("targetname", "");
        if name {
            self.names.append(name);
        }
        for key in ["target", "killtarget"] {
            aim = here.fields.get(key, "");
            if aim {
                self.aims.append((here, key, aim));
            }
        }
        if "origin" in here.fields and here.origin() is None {
            self.findings.append(
                Finding(words=here.title() + " has an origin that is not three numbers", item=here, grave=True)
            );
        }
        owned = [solid for solid in [here->:Owns:->][?:Solid] if solid.held];
        if len(owned) == 0 and here.model() < 0 and classname != "worldspawn"
            and (classname.startswith("func_") or classname.startswith("trigger_")) and "origin" not in here.fields {
            self.findings.append(Finding(words=here.title() + " has no brushes", item=here));
        }
        visit [here->:Owns:->];
    }

    can measure with Solid entry {
        if not here.held {
            return;
        }
        outlines = here.outlines();
        kept = 0;
        for outline in outlines {
            if len(outline) >= 3 {
                kept += 1;
            }
        }
        label = "Brush #" + str(here.serial);
        if kept < 4 {
            self.findings.append(Finding(words=label + " encloses nothing", solid=here, grave=True));
            return;
        }
        if kept < len(here.sides) {
            self.findings.append(
                Finding(words=label + " has " + str(len(here.sides) - kept) + " sides that make no face", solid=here)
            );
        }
        box = windings_bounds(outlines);
        if box is not None {
            size = box[1].sub(box[0]);
            if min(size.x, min(size.y, size.z)) < 1.0 {
                self.findings.append(Finding(words=label + " is thinner than a unit", solid=here));
            }
        }
        whole = True;
        for outline in outlines {
            for point in outline {
                if abs(point.x - float(round(point.x))) > 0.01 or abs(point.y - float(round(point.y))) > 0.01
                    or abs(point.z - float(round(point.z))) > 0.01 {
                    whole = False;
                }
            }
        }
        if not whole {
            self.findings.append(Finding(words=label + " has corners off the unit grid", solid=here));
        }
    }
}

"""Everything an entity fires, and everything those fire in turn."""
walker Reach {
    has seen: list[Item] = [];

    can follow with Item entry {
        if here in self.seen or not here.held {
            return;
        }
        self.seen.append(here);
        visit [here->:Fires:->];
    }
}

"""Where an entity stands in the logic graph: how many firings from a
source, and which place down that column."""
obj LogicNode {
    has item: Item,
        column: int = 0,
        row: int = 0;
}

walker FindSolid {
    has serial: int,
        found: Solid | None = None;

    can start with Scene entry {
        visit [here->:Holds:->];
    }

    can descend with Item entry {
        if here.held {
            visit [here->:Owns:->];
        }
    }

    can check with Solid entry {
        if here.serial == self.serial {
            self.found = here;
            disengage;
        }
    }
}

walker FindItem {
    has serial: int,
        found: Item | None = None;

    can start with Scene entry {
        visit [here->:Holds:->];
    }

    can check with Item entry {
        if here.serial == self.serial {
            self.found = here;
            disengage;
        }
    }
}

"""A face of a brush, by the brush and the number of its side."""
obj FacePick {
    has solid: Solid,
        side: int;
}

"""A map being edited. `revision` counts changes to its items and `picks`
changes to the selection, so panels know when to refresh."""
node Scene {
    has game: str = "",
        name: str = "",
        # Where the scene is kept, when it is a file of its own.
        path: str = "",
        revision: int = 0,
        # Counts changes to what the level is built from.
        geometry: int = 0,
        picks: int = 0,
        dirty: bool = False,
        # The revision the Fires edges were drawn at.
        linked: int = -1,
        next_serial: int = 0,
        journal: Journal = Journal();

    """Every item in the document, in map order."""
    def items -> list[Item] {
        return [item for item in [self->:Holds:->][?:Item] if item.held];
    }

    def selection -> list[Item] {
        return [item for item in [self->:Selected:->][?:Item] if item.held];
    }

    """The selected brushes."""
    def selected_solids -> list[Solid] {
        return [solid for solid in [self->:Selected:->][?:Solid] if solid.held];
    }

    """An entity's brushes."""
    def solids_of(item: Item) -> list[Solid] {
        return [solid for solid in [item->:Owns:->][?:Solid] if solid.held];
    }

    """Every brush in the document."""
    def solids -> list[Solid] {
        found: list[Solid] = [];
        for item in self.items() {
            found.extend(self.solids_of(item));
        }
        return found;
    }

    """The entity that owns a brush."""
    def owner_of(solid: Solid) -> Item | None {
        owners = [solid<-:Owns:<-][?:Item];
        return owners[0] if owners else None;
    }

    """The world entity, made when the document has none."""
    def world -> Item {
        for item in self.items() {
            if item.classname() == "worldspawn" {
                return item;
            }
        }
        return self.add_item({"classname": "worldspawn"});
    }

    def find_solid(serial: int) -> Solid | None {
        search = self spawn FindSolid(serial=serial);
        found = search.found;
        return found if found is not None and found.held else None;
    }

    """Add a brush without journalling it (loading, and Clone's copies)."""
    def add_solid(owner: Item, sides: list[Side]) -> Solid {
        solid = Solid(serial=self.next_serial, sides=sides);
        self.next_serial += 1;
        owner +>:Owns:+> solid;
        return solid;
    }

    """Add a brush to an entity (the world when none is named) and select
    it. None when the sides enclose nothing."""
    def create_solid(sides: list[Side], owner: Item | None = None) -> Solid | None {
        if not sides_enclose(sides) {
            return None;
        }
        solid = self.add_solid(owner if owner is not None else self.world(), sides);
        self.commit(Step(label="New brush", changes=[SolidHold(solid=solid, held=True)]));
        self.clear_selection();
        self +>:Selected:+> solid;
        self.picks += 1;
        return solid;
    }

    def is_solid_selected(solid: Solid) -> bool {
        return solid in [self->:Selected:->][?:Solid];
    }

    """The selected faces."""
    def faces -> list[FacePick];
    """Which sides of a brush are selected as faces."""
    def face_sides(solid: Solid) -> list[int];
    def is_face_selected(solid: Solid, index: int) -> bool;
    """Select a face: alone, or added to (or dropped from) the faces."""
    def select_face(solid: Solid, index: int, add: bool = False);
    def clear_faces;
    """Apply a face edit to the selected faces and brushes."""
    def reface(change: FaceEdit, label: str) -> bool;
    """Select every entity and brush ("entities" or "brushes" for one
    kind). Answers how many."""
    def select_all(kind: str = "") -> int;
    """Select what is not selected and drop what is."""
    def invert_selection -> int;
    """Select every brush with a side of a material."""
    def select_material(material: str) -> int;
    """Stretch the selection about its middle by a factor along each axis
    (-1 mirrors)."""
    def stretch_selection(factors: Vec3, grid: float = 8.0, label: str = "Stretch") -> bool;
    """Cut the selected brushes out of every other. Answers how many brushes
    changed."""
    def carve_selection(lined: bool = False) -> int;
    """Replace the selected brushes with what they all share."""
    def intersect_selection -> bool;
    """Turn the selected brushes into shells of walls."""
    def hollow_selection(thickness: float) -> bool;
    """Join the selected brushes into one, when together they are convex."""
    def merge_selection -> bool;
    """Move the corners of a brush nearest `spots`."""
    def move_corners(solid: Solid, spots: list[Vec3], delta: Vec3) -> bool;
    """What is wrong with the document."""
    def problems -> list[Finding];

    """Set several fields on the selection as one step (None removes one)."""
    def set_fields(pairs: dict[str, str | None], label: str = "Set fields") -> bool;
    """Add brushes to an entity as one step (a duplicator's images made real)."""
    def add_brushes(owner: Item, brushes: list[list[Side]], label: str = "Add brushes") -> bool;

    """Set or clear one bit of the selection's spawnflags (bit 0 is 1)."""
    def flag_selection(bit: int, on: bool) -> bool;
    """Add to a number field of every selected item: one that has it, or
    every one when `fill`. `wrap` keeps it under that many (an angle's 360)."""
    def bump_selection(key: str, delta: float, wrap: float = 0.0, fill: bool = False) -> bool;
    """Select every entity with a targetname. Answers how many."""
    def select_named(name: str) -> int;

    """Draw the Fires edges again from the entities' fields."""
    def relink;
    """Bring the Fires edges in line with the document when it has changed."""
    def links;
    def fires(item: Item) -> list[Item];
    def fired_by(item: Item) -> list[Item];
    """Everything an entity sets off, directly or through others."""
    def reach(item: Item) -> list[Item];
    """A targetname no entity has yet."""
    def fresh_name(stem: str = "t") -> str;
    """Make one entity fire another: the second gets a targetname when it
    has none, and the first's target becomes it."""
    def link(source: Item, dest: Item) -> bool;
    """Stop an entity firing another (or anything, when none is named)."""
    def unlink(source: Item, dest: Item | None = None) -> bool;
    """The entities that fire or are fired, placed in columns by how far
    from a source they are."""
    def logic_nodes -> list[LogicNode];
    """The entities that set themselves off through others."""
    def loops -> list[Item];

    """The selection as a map: selected brushes as a world's, selected
    entities with theirs."""
    def selection_map -> list[MapItem];
    """Add a map's entities and brushes to the document, moved by `offset`,
    and select them. A world's brushes join this world, or a new func_group
    named `group` when one is given."""
    def insert_map(found: list[MapItem], offset: Vec3, label: str = "Paste", group: str = "") -> bool;
    """Hand the selected brushes to a new func_group: brushes that stay
    part of the world but are picked and moved as one."""
    def group_selection(name: str) -> Item | None;

    """Select a brush: alone, or added to (or dropped from) the selection."""
    def select_solid(solid: Solid | None, add: bool = False) {
        if not add {
            self.clear_selection();
        }
        if solid is not None {
            if self.is_solid_selected(solid) {
                if add {
                    self del->:Selected:-> solid;
                }
            } else {
                self +>:Selected:+> solid;
            }
        }
        self.picks += 1;
    }

    """Replace a brush's sides (a resize, a cut). Refused when the new sides
    enclose nothing."""
    def reshape(solid: Solid, sides: list[Side], label: str = "Reshape") -> bool {
        if not sides_enclose(sides) {
            return False;
        }
        change = SidesChange(solid=solid, before=solid.sides, after=sides);
        change.redo();
        return self.commit(Step(label=label, changes=[change]));
    }

    """Move one side of a brush along its normal."""
    def push_side(solid: Solid, index: int, distance: float) -> bool {
        if index < 0 or index >= len(solid.sides) or distance == 0.0 {
            return False;
        }
        after = list(solid.sides);
        after[index] = side_moved(solid.sides[index], solid.sides[index].plane.normal.scale(distance));
        return self.reshape(solid, after, "Resize");
    }

    """Cut the selected brushes along a plane, keeping "back", "front" or
    "both"; with both, the new halves join the selection."""
    def clip_selection(plane: Plane3, keep: str = "both", material: str = "") -> bool {
        step = Step(label="Clip");
        cutter = self spawn Clip(plane=plane, keep=keep, step=step, material=material);
        if not self.commit(step) {
            return False;
        }
        for half in cutter.made {
            self +>:Selected:+> half;
        }
        self.picks += 1;
        return True;
    }

    """The middle of the selection: of its brushes' boxes and its entities'
    origins. None when nothing selected is anywhere."""
    def selection_middle -> Vec3 | None {
        low = Vec3(x=1000000.0, y=1000000.0, z=1000000.0);
        high = Vec3(x=-1000000.0, y=-1000000.0, z=-1000000.0);
        seen = False;
        spots: list[Vec3] = [];
        for solid in self.selected_solids() {
            box = solid.bounds();
            if box is not None {
                spots.append(box[0]);
                spots.append(box[1]);
            }
        }
        for item in self.selection() {
            at = item.origin();
            if at is not None {
                spots.append(at);
            } else {
                for solid in self.solids_of(item) {
                    box = solid.bounds();
                    if box is not None {
                        spots.append(box[0]);
                        spots.append(box[1]);
                    }
                }
            }
        }
        for spot in spots {
            low = Vec3(x=min(low.x, spot.x), y=min(low.y, spot.y), z=min(low.z, spot.z));
            high = Vec3(x=max(high.x, spot.x), y=max(high.y, spot.y), z=max(high.z, spot.z));
            seen = True;
        }
        return low.add(high).scale(0.5) if seen else None;
    }

    """Turn the selection by an angle in degrees about the vertical line
    through its middle (snapped to `grid`, so quarter turns stay on it)."""
    def turn_selection(degrees: float, grid: float = 8.0, axis: int = 2) -> bool {
        middle = self.selection_middle();
        if middle is None or degrees == 0.0 {
            return False;
        }
        step_size = grid if grid > 0.0 else 1.0;
        pivot = Vec3(
            x=float(round(middle.x / step_size)) * step_size,
            y=float(round(middle.y / step_size)) * step_size,
            z=middle.z if axis == 2 else float(round(middle.z / step_size)) * step_size
        );
        step = Step(label="Turn");
        self spawn Turn(pivot=pivot, angle=math.radians(degrees), step=step, axis=axis);
        return self.commit(step);
    }

    """Hand the selected brushes to an entity: a new one of `classname`, or
    the world when it is empty. Answers the entity that took them."""
    def tie_selection(classname: str) -> Item | None {
        chosen = self.selected_solids();
        if not chosen {
            return None;
        }
        step = Step(label="Tie to " + classname if classname else "Move to world");
        taker = self.world();
        if classname and classname != "worldspawn" {
            taker = self.add_item({"classname": classname});
            step.changes.append(HoldChange(item=taker, held=True));
        }
        for solid in chosen {
            giver = self.owner_of(solid);
            if giver is None or giver is taker {
                continue;
            }
            change = OwnChange(solid=solid, before=giver, after=taker);
            change.redo();
            step.changes.append(change);
        }
        if not self.commit(step) {
            return None;
        }
        return taker;
    }

    """Give the selected brushes a material (on one side when `side` names
    it)."""
    def paint_selection(material: str, side: int = -1) -> bool {
        step = Step(label="Set material");
        self spawn Paint(material=material, step=step, side=side);
        return self.commit(step);
    }

    def find(serial: int) -> Item | None {
        search = self spawn FindItem(serial=serial);
        found = search.found;
        return found if found is not None and found.held else None;
    }

    """Add an item without journalling it (loading, and Clone's copies)."""
    def add_item(fields: dict[str, str]) -> Item {
        item = Item(serial=self.next_serial, fields=fields);
        self.next_serial += 1;
        self +>:Holds:+> item;
        return item;
    }

    def is_selected(item: Item) -> bool {
        return item in [self->:Selected:->][?:Item];
    }

    """Select an item: alone, or added to (or dropped from) the selection."""
    def select(item: Item | None, add: bool = False) {
        if not add {
            self.clear_selection();
        }
        if item is not None {
            if self.is_selected(item) {
                if add {
                    self del->:Selected:-> item;
                }
            } else {
                self +>:Selected:+> item;
            }
        }
        self.picks += 1;
    }

    def clear_selection {
        for item in [self->:Selected:->][?:Item] {
            self del->:Selected:-> item;
        }
        for solid in [self->:Selected:->][?:Solid] {
            self del->:Selected:-> solid;
        }
        for solid in [self->:Faced:->] {
            self del->:Faced:-> solid;
        }
        self.picks += 1;
    }

    """Keep a finished step: it becomes the newest thing to undo."""
    def commit(step: Step) -> bool {
        if not step.changes {
            return False;
        }
        journal = self.journal;
        journal.done.append(step);
        if len(journal.done) > journal.limit {
            journal.done.pop(0);
        }
        journal.undone = [];
        if step.reshapes() {
            self.geometry += 1;
        }
        self.changed();
        return True;
    }

    def changed {
        self.revision += 1;
        self.dirty = True;
        # Deleted items and brushes leave the selection.
        for item in [self->:Selected:->][?:Item] {
            if not item.held {
                self del->:Selected:-> item;
                self.picks += 1;
            }
        }
        for solid in [self->:Selected:->][?:Solid] {
            if not solid.held {
                self del->:Selected:-> solid;
                self.picks += 1;
            }
        }
        # A face picked on a brush that has gone, or has fewer sides now.
        for solid in [self->:Faced:->] {
            if not solid.held {
                self del->:Faced:-> solid;
                self.picks += 1;
            } else {
                limit = len(solid.sides);
                if solid in [self->:Faced:side >= limit:->] {
                    self del->:Faced:side >= limit:-> solid;
                    self.picks += 1;
                }
            }
        }
    }

    """Why a field cannot take a value ("" when it can). An origin that is
    not three numbers leaves an entity nowhere, and a map whose player start
    is nowhere does not load."""
    def refuses(key: str, value: str) -> str {
        if not key.strip() {
            return "A field needs a name";
        }
        if key == "origin" and read_vector(value) is None {
            return "origin takes three numbers";
        }
        if key == "classname" and not value.strip() {
            return "classname cannot be empty";
        }
        return "";
    }

    """Set a field on the selection."""
    def set_field(key: str, value: str) -> bool {
        if self.refuses(key, value) {
            return False;
        }
        step = Step(label="Set " + key);
        self spawn SetField(key=key, value=value, step=step);
        return self.commit(step);
    }

    def unset_field(key: str) -> bool {
        # An entity without a class is not an entity.
        if key == "classname" {
            return False;
        }
        step = Step(label="Remove " + key);
        self spawn SetField(key=key, value=None, step=step);
        return self.commit(step);
    }

    def remove_selection -> bool {
        step = Step(label="Delete");
        self spawn Remove(step=step);
        return self.commit(step);
    }

    def shift_selection(delta: Vec3) -> bool {
        step = Step(label="Move");
        self spawn Shift(delta=delta, step=step);
        return self.commit(step);
    }

    """Copy the selection; the copies become the selection."""
    def clone_selection(offset: Vec3) -> bool {
        step = Step(label="Duplicate");
        copier = self spawn Clone(offset=offset, step=step);
        if not self.commit(step) {
            return False;
        }
        self.clear_selection();
        for copy in copier.made {
            self +>:Selected:+> copy;
        }
        for copy in copier.made_solids {
            self +>:Selected:+> copy;
        }
        return True;
    }

    """Add a new entity and select it."""
    def create(classname: str, at: Vec3 | None = None) -> Item {
        fields: dict[str, str] = {"classname": classname};
        if at is not None {
            fields["origin"] = write_vector(at);
        }
        item = self.add_item(fields);
        self.commit(Step(label="New " + classname, changes=[HoldChange(item=item, held=True)]));
        self.select(item);
        return item;
    }

    """Undo the newest step. Answers its label ("" when there was none)."""
    def undo -> str {
        journal = self.journal;
        if not journal.done {
            return "";
        }
        step = journal.done.pop();
        for i in range(len(step.changes) - 1, -1, -1) {
            step.changes[i].undo();
        }
        journal.undone.append(step);
        if step.reshapes() {
            self.geometry += 1;
        }
        self.changed();
        return step.label;
    }

    def redo -> str {
        journal = self.journal;
        if not journal.undone {
            return "";
        }
        step = journal.undone.pop();
        for change in step.changes {
            change.redo();
        }
        journal.done.append(step);
        if step.reshapes() {
            self.geometry += 1;
        }
        self.changed();
        return step.label;
    }

    """The document as the map's entities."""
    def entities -> list[MapEntity] {
        return [MapEntity(fields=dict(item.fields)) for item in self.items()];
    }

    """The document as an entity lump."""
    def text -> str {
        return entity_text(self.entities());
    }
}

"""The document as a map: every entity with its brushes."""
def scene_map(scene: Scene) -> list[MapItem] {
    return [
        MapItem(fields=dict(item.fields), brushes=[solid.sides for solid in scene.solids_of(item)])
        for item in scene.items()
    ];
}

"""A document of a map file's entities and brushes."""
def scene_from_map(game: str, name: str, found: MapFile) -> Scene {
    scene = Scene(game=game, name=name);
    for read in found.items {
        item = scene.add_item(dict(read.fields));
        for sides in read.brushes {
            scene.add_solid(item, sides);
        }
    }
    return scene;
}

"""A document of a map's entities."""
def scene_of(game: str, name: str, entities: list[MapEntity]) -> Scene {
    scene = Scene(game=game, name=name);
    for entity in entities {
        scene.add_item(dict(entity.fields));
    }
    return scene;
}
