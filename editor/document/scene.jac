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
    side_on,
    turned_z
}
import math;
import from ..formats.map { MapItem, MapFile }
import from ..classes.registry { flag_put }
import from ..geometry.terrain { terrain_brushes, flat_heights, heights_text, heights_from, sculpted, lifted }
import from ..geometry.touchup { corner_near, kin_corners, cells_corners, corners_lifted }
import from ..geometry.patch {
    patch_brushes,
    points_text,
    points_from,
    points_shifted,
    points_carried,
    points_reversed,
    grid_grown,
    grid_shrunk,
    places_text,
    places_from,
    patch_surface
}
import from ..geometry.csg { hull_sides }
import from ..geometry.faces { sides_dropped, side_flipped, cone_on, prism_on, walls_on, outline_width }
import from ..geometry.shapes { caulked }
import from ..geometry.csg {
    carve_sides,
    common_sides,
    hollow_sides,
    merged_sides,
    corners_moved,
    brush_corners,
    joined_pieces,
    pruned_sides
}
import from ..geometry.linear { Linear, point_remapped, sides_remapped }
import from ..geometry.mapping {
    side_like,
    mapping_place,
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
    axis_vector,
    mapping_min_fitted,
    mapping_wrapped,
    mapping_bad
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

"""An entity or a brush belongs to a named set: a selection kept with the
document, to pick again later."""
edge Member: Scene --> Item | Solid {
    has name: str = "";
}

"""A side of one brush is linked to a side of another: the two are kept in
one plane, so pushing either pushes both. `side` is which side of the brush
the edge leaves; the side it reaches is the one that lies in that plane."""
edge Linked: Solid --> Solid {
    has side: int = 0;
}

"""The field that keeps a document's linked faces in a map file."""
glob LINKS_KEY: str = "_links";

"""Whether two planes are one plane, facing the same way or opposite ways."""
def planes_meet(first: Plane3, second: Plane3) -> bool {
    lean = first.normal.dot(second.normal);
    if abs(lean) < 0.9999 {
        return False;
    }
    return abs(first.dist - (second.dist if lean > 0.0 else -second.dist)) < 0.05;
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
        held: bool = True,
        # Out of sight while editing: not drawn, picked or built, but saved
        # and played like the rest.
        hidden: bool = False;

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

    """What lists call it: its targetname when it has one, and a group by
    the name it was given."""
    def title -> str {
        name = self.fields.get("targetname", "");
        group = self.fields.get("_group_name", "");
        if group and not name and self.classname() == "func_group" {
            return group;
        }
        return self.classname() + (" (" + name + ")" if name else "");
    }
}

"""One brush of the document: the space behind its sides. A shipped map's
geometry is not in the document; these are the brushes made or opened in the
studio."""
node Solid {
    has serial: int = 0,
        sides: list[Side] = [],
        held: bool = True,
        hidden: bool = False;

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

"""The fields a group keeps its own switches in: how it shows in the views
("grey" for outlines only, "hidden" for nothing), whether clicks pass it
by, whether builds leave it out, and the colour of its outlines."""
glob VIEW_KEY: str = "_view",
     LOCK_KEY: str = "_locked",
     SKIP_KEY: str = "_skip",
     TINT_KEY: str = "_tint";

"""How an entity shows in the views: "", "grey" or "hidden"."""
def item_veil(item: Item) -> str {
    how = item.fields.get(VIEW_KEY, "");
    return how if how in ["grey", "hidden"] else "";
}

"""Whether an entity has one of its switches on."""
def item_switched(item: Item, key: str) -> bool {
    return item.fields.get(key, "0").strip() == "1";
}

"""What the fields that keep a document's sets in a map file begin with."""
glob SET_PREFIX: str = "_set_";

"""The field that keeps, in a map file, the names of the sets switched off
as layers."""
glob LAYERS_KEY: str = "_layers_off";

"""The field a group keeps its own pivot in: what it turns and stretches
about, in place of its middle."""
glob PIVOT_KEY: str = "_center";

"""A side as a change left it, with the material lying as it did before:
where it was in the world, the face having moved through it."""
def side_loose(after: Side, before: Side) -> Side {
    return Side(
        plane=after.plane,
        points=after.points,
        material=after.material,
        mapping=before.mapping,
        contents=after.contents,
        flags=after.flags,
        value=after.value
    );
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
        slid: list[Solid] = [],
        # Whether materials go with their faces, or stay where they lie in
        # the world while the faces move through them.
        locked: bool = True;

    can start with Scene entry {
        visit [here->:Selected:->];
    }

    can apply with Item entry {
        at = here.origin();
        if at is None {
            bent = here.fields.get("_points");
            if bent is not None {
                # A patch's control points go where its brushes go.
                carried = FieldChange(item=here, key="_points", before=bent, after=points_shifted(bent, self.delta));
                carried.redo();
                self.step.changes.append(carried);
            }
            hub = here.fields.get(PIVOT_KEY);
            if hub is not None {
                # A group's own pivot goes with the group.
                kept = FieldChange(item=here, key=PIVOT_KEY, before=hub, after=points_shifted(hub, self.delta));
                kept.redo();
                self.step.changes.append(kept);
            }
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
            solid=here,
            before=here.sides,
            after=[
                (side_moved(side, self.delta) if self.locked else side_loose(side_moved(side, self.delta), side))
                for side in here.sides
            ]
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
        # Each half without the sides the cut left behind it.
        back = pruned_sides(parts[0]);
        front = pruned_sides(parts[1]);
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
        turned: list[Solid] = [],
        locked: bool = True;

    can start with Scene entry {
        visit [here->:Selected:->];
    }

    can swing with Item entry {
        at = here.origin();
        if at is None {
            about = axis_vector(self.axis);
            for key in ["_points", PIVOT_KEY] {
                # A patch's control points, and a group's pivot, turn with it.
                held = here.fields.get(key);
                if held is not None {
                    carried = FieldChange(
                        item=here,
                        key=key,
                        before=held,
                        after=points_carried(
                            held,
                            self.pivot,
                            spun_about(Vec3(x=1.0), about, self.angle),
                            spun_about(Vec3(y=1.0), about, self.angle),
                            spun_about(Vec3(z=1.0), about, self.angle)
                        )
                    );
                    carried.redo();
                    self.step.changes.append(carried);
                }
            }
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
        spun = [
            (side_turned(side, self.pivot, self.angle) if self.axis == 2 else side_spun(
                side, self.pivot, self.axis, self.angle
            ))
            for side in here.sides
        ];
        if not self.locked {
            spun = [side_loose(spun[index], here.sides[index]) for index in range(len(spun))];
        }
        change = SidesChange(solid=here, before=here.sides, after=spun);
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
        sizes: dict[str, list[int]] = {},
        # The face a wrap or a projection takes its material and mapping from.
        source: Side | None = None;

    """The side as the edit leaves it: the same side when it changes
    nothing."""
    def apply(side: Side, outline: list[Vec3]) -> Side {
        if self.how == "material" {
            return side if side.material == self.material else side_like(side, self.material);
        }
        given = self.source;
        if (self.how == "wrap" or self.how == "project") and given is not None {
            # The tagged face's material, carried round the corner onto
            # this face, or laid on it just as it lies on that one.
            carried = given.mapping;
            if self.how == "wrap" {
                round_edge = mapping_wrapped(given.mapping, given.plane, side.plane);
                if round_edge is None {
                    return side;
                }
                carried = round_edge;
            }
            if side.material == given.material and mapping_same(side.mapping, carried) {
                return side;
            }
            return side_like(side, given.material, carried);
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
        } elif self.how == "minfit" {
            least = self.sizes.get(side.material, [64, 64]);
            fresh = mapping_min_fitted(old, outline, least[0], least[1]);
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
        seen: list[Solid] = [],
        locked: bool = True;

    can start with Scene entry {
        visit [here->:Selected:->];
    }

    can place with Item entry {
        at = here.origin();
        if at is None {
            for key in ["_points", PIVOT_KEY] {
                # A patch's control points, and a group's pivot, stretch with it.
                held = here.fields.get(key);
                if held is not None {
                    stretched = points_carried(
                        held, self.pivot, Vec3(x=self.factors.x), Vec3(y=self.factors.y), Vec3(z=self.factors.z)
                    );
                    lay = here.fields.get("_patch", "").split();
                    if key == "_points" and self.factors.x * self.factors.y * self.factors.z < 0.0
                        and len(lay) > 0 and lay[0].isdigit() {
                        # Mirrored, a patch built again would thicken toward its
                        # other side: its rows are turned end for end to keep it.
                        stretched = points_reversed(stretched, int(lay[0]));
                    }
                    carried = FieldChange(item=here, key=key, before=held, after=stretched);
                    carried.redo();
                    self.step.changes.append(carried);
                }
            }
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
        if not self.locked {
            after = [side_loose(after[index], here.sides[index]) for index in range(len(after))];
        }
        change = SidesChange(solid=here, before=here.sides, after=after);
        change.redo();
        self.step.changes.append(change);
    }
}

"""Carry the selection through a change of the world about a pivot (a turn,
a change of size, a shear, or any of them at once): brushes with their
materials, patches by their control points, point entities by where they
are and, when the change turns the floor under them, by the way they face."""
walker Remap {
    has pivot: Vec3,
        change: Linear,
        step: Step,
        seen: list[Solid] = [],
        locked: bool = True;

    can start with Scene entry {
        visit [here->:Selected:->];
    }

    can place with Item entry {
        at = here.origin();
        if at is None {
            for key in ["_points", PIVOT_KEY] {
                # A patch's control points, and a group's pivot, go through it too.
                held = here.fields.get(key);
                if held is not None {
                    remade = points_carried(held, self.pivot, self.change.x, self.change.y, self.change.z);
                    lay = here.fields.get("_patch", "").split();
                    if key == "_points" and self.change.volume() < 0.0 and len(lay) > 0 and lay[0].isdigit() {
                        # Mirrored, a patch built again would thicken toward its
                        # other side: its rows are turned end for end to keep it.
                        remade = points_reversed(remade, int(lay[0]));
                    }
                    carried = FieldChange(item=here, key=key, before=held, after=remade);
                    carried.redo();
                    self.step.changes.append(carried);
                }
            }
            visit [here->:Owns:->];
            return;
        }
        put = FieldChange(
            item=here,
            key="origin",
            before=here.fields.get("origin"),
            after=write_vector(point_remapped(at, self.pivot, self.change))
        );
        put.redo();
        self.step.changes.append(put);
        facing = here.fields.get("angle");
        if facing is None {
            return;
        }
        try {
            # Up (-1) and down (-2) are not directions to turn.
            way = float(facing);
            if way < 0.0 {
                return;
            }
            ahead = self.change.carry(Vec3(x=math.cos(math.radians(way)), y=math.sin(math.radians(way))));
            if abs(ahead.x) + abs(ahead.y) < 0.0001 {
                return;
            }
            faced = round(math.degrees(math.atan2(ahead.y, ahead.x)) % 360.0, 3) % 360.0;
            if abs(faced - way) > 0.001 {
                face = FieldChange(item=here, key="angle", before=facing, after=field_number(faced));
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
        after = sides_remapped(here.sides, self.pivot, self.change);
        if len(after) != len(here.sides) or not sides_enclose(after) {
            return;
        }
        if not self.locked {
            after = [side_loose(after[index], here.sides[index]) for index in range(len(after))];
        }
        reshaped = SidesChange(solid=here, before=here.sides, after=after);
        reshaped.redo();
        self.step.changes.append(reshaped);
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
            } else {
                # A sliver of a face on a brush that is not itself a sliver.
                slivers = 0;
                for outline in outlines {
                    if len(outline) >= 3 and outline_width(outline) < 1.0 {
                        slivers += 1;
                    }
                }
                if slivers > 0 {
                    self.findings.append(
                        Finding(words=label + " has " + str(slivers) + " faces thinner than a unit", solid=here)
                    );
                }
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
        smeared = 0;
        for side in here.sides {
            if mapping_bad(side.mapping) {
                smeared += 1;
            }
        }
        if smeared > 0 {
            self.findings.append(
                Finding(words=label + " has " + str(smeared) + " sides whose material is smeared into a line", solid=here)
            );
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
        journal: Journal = Journal(),
        # The names of the selections kept as sets, in the order made; and
        # those of them switched off as layers, their members hidden.
        set_names: list[str] = [],
        layers_off: list[str] = [];

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
    def stretch_selection(
        factors: Vec3, grid: float = 8.0, label: str = "Stretch", about: Vec3 | None = None, locked: bool = True
    ) -> bool;
    """Carry the selection through a change of the world (a turn, a change
    of size, a shear, or any of them at once) about a point: its own middle
    put on the grid when none is given."""
    def remap_selection(
        change: Linear, about: Vec3 | None = None, label: str = "Shear", grid: float = 8.0, locked: bool = True
    ) -> bool;
    # Faces dropped, turned and built on; side flags (impl/scene.faces.impl.jac)

    """Take the picked faces off their brushes, where the other sides close
    without them. Answers how many faces went."""
    def drop_faces -> int;
    """Turn each picked face to face the other way, where the other sides
    still close a brush. Answers how many turned."""
    def flip_faces -> int;
    """Stand a brush on each picked face: "cone" (to a point `size` out),
    "prism" (the face pushed out by `size`) or "walls" (round its edge,
    `size` out and `thickness` in). The new brushes are left selected.
    Answers how many were made."""
    def build_on_faces(shape: str, size: float, thickness: float = 16.0) -> int;
    """Build a patch again with another grid of control points, another
    fineness (prisms a curve) or another thickness; zero or less keeps what
    it has."""
    def remake_patch(
        item: Item, points: list[Vec3], width: int, height: int, steps: int = 0, thickness: float = 0.0,
        label: str = "Patch"
    ) -> bool;
    """One more curve across ("u") or up ("v") a patch, or one fewer."""
    def grow_patch(item: Item, way: str, more: bool = True) -> bool;
    """Where a patch's control points lie on its material, in texels, two
    numbers a point (none when it has not been told)."""
    def patch_places(item: Item) -> list[float];
    """Tell a patch where its control points lie on its material (none
    forgets them), and build it again so that its surface takes the
    material as they say."""
    def set_patch_places(item: Item, places: list[float], label: str = "Lay material") -> bool;
    """Where a patch's built surface has its material at its first corner
    and at its last, as its brushes' own faces say: four numbers, or none
    when a corner is pinched to a point."""
    def patch_lies(item: Item) -> list[float];
    """Lift (or lower) a terrain inside a rectangle of the world, with a
    falloff outside it."""
    def lift_terrain(item: Item, low: Vec3, high: Vec3, amount: float, falloff: float = 0.0) -> bool;
    """Split a terrain's cells along the same diagonal (""), the other
    ("other") or each in turn ("alt")."""
    def set_pattern(item: Item, pattern: str) -> bool;
    """Give the top of every prism of a terrain within `radius` of a point
    a material. Answers how many prisms changed."""
    def paint_terrain(item: Item, x: float, y: float, radius: float, material: str) -> int;
    """Where a terrain stands: the low corner of its brushes."""
    def terrain_origin(item: Item) -> Vec3;
    """Move the corner of a terrain's grid nearest a place, and the corners
    that go with it (joined to it along the grid, within `variance` of its
    height). Answers how many corners moved."""
    def touch_terrain(item: Item, x: float, y: float, amount: float, variance: float = 0.0) -> int;
    """Move the corners of some of a terrain's cells up or down."""
    def lift_cells(item: Item, cells: list[int], amount: float) -> bool;
    """Move a terrain's top (every height) or its bottom (the underside of
    its base, its top staying where it is)."""
    def move_terrain(item: Item, part: str, amount: float) -> bool;
    """Give an entity other brushes in place of its own, and set fields on
    it, as one step: a shape built again from other numbers."""
    def rebuild_item(item: Item, brushes: list[list[Side]], fields: dict[str, str | None], label: str) -> bool;
    """Give the faces of the selected brushes that another selected brush
    covers a material that is not drawn. Answers how many faces changed."""
    def caulk_selection(material: str = "caulk") -> int;
    """Give one side of a brush a material."""
    def paint_face(solid: Solid, index: int, material: str) -> bool;
    """Put the one picked face in a plane (facing as it does): its brush
    reaches to that plane, or back to it. False when that leaves nothing."""
    def glue_face(plane: Plane3) -> bool;
    """Go from the one picked face to the brush's next (or, with -1, the one
    before). False when it is not one face that is picked."""
    def step_face(pace: int = 1) -> bool;
    """Set (or clear, or replace) bits of the contents, the surface flags or
    the value of the picked faces, or of every side of the selected brushes.
    `how` is "set", "clear" or "put". Answers how many sides changed."""
    def flag_sides(key: str, bits: int, how: str = "set") -> int;

    # Entities by skill and mode, values replaced, the deeper audit (impl/scene.entities.impl.jac)

    """The entities a skill or mode leaves out: "easy", "normal", "hard" or
    "deathmatch" (the spawnflags every game shares, and Quake III's
    `notsingle` and `notfree`)."""
    def spawn_excluded(mode: str) -> list[Item];
    """Hide what a skill or mode leaves out, and show again what the last
    one hid. Answers what is hidden for it now."""
    def spawn_preview(mode: str, before: list[Item]) -> list[Item];
    """In a field of the selected entities (of every entity, when
    `everywhere`), put `fresh` where `old` stands. Answers how many changed."""
    def replace_values(key: str, old: str, fresh: str, everywhere: bool = False) -> int;
    """What the map's logic leaves hanging, beyond what `problems` reports:
    names nothing fires."""
    def audit -> list[Finding];

    # Groups' own switches and what a build is made from (impl/scene.select.impl.jac)

    """The document's groups, in map order."""
    def groups -> list[Item];
    """What a build is made from: without the groups that builds skip and,
    unless it is to be played, without what is hidden or shown as outlines
    only."""
    def built_map(play: bool) -> list[MapItem];
    """Whether `built_map` leaves anything of the document out."""
    def filtered(play: bool) -> bool;

    # Kept selections and wider picks (impl/scene.select.impl.jac)

    """Keep the selection as a set of that name, in place of any there was.
    Answers how many it holds."""
    def keep_set(name: str) -> int;
    """What a set holds that is still in the document."""
    def set_items(name: str) -> list[Item];
    def set_solids(name: str) -> list[Solid];
    """Select a set's members, alone or added. Answers how many."""
    def pick_set(name: str, add: bool = False) -> int;
    def drop_set(name: str) -> bool;
    """A set is a layer too: whether its members are shown."""
    def layer_shown(name: str) -> bool;
    """Show or hide a set's members as a layer. What another layer still
    hides stays hidden. Answers how many changed."""
    def show_layer(name: str, shown: bool) -> int;
    """Show one layer and hide every other. Answers how many changed."""
    def only_layer(name: str) -> int;
    """A set as words a map file keeps: an entity by its place in the map
    (`4`), a brush by its entity's place and its own (`0:12`)."""
    def set_words(name: str) -> str;
    """Make a set again from those words, over the entities in map order."""
    def restore_set(name: str, words: str, placed: list[Item]);
    """Step from the selection to its kin: "parent" (the entities that own
    the selected brushes), "child" (the selected entities' brushes), "next"
    or "prev" (the one selected thing's neighbour in the map). Answers how
    many are selected afterwards, or 0 when there is nowhere to step."""
    def select_kin(how: str) -> int;
    """Select a brush by its entity's place in the map and its own within
    it, as a compiler names them (the entity itself when `brush` is below 0)."""
    def select_numbered(entity: int, brush: int = -1) -> bool;
    """The two selected things change places."""
    def swap_selection -> bool;
    """The pivot the one selected group keeps for itself, when it keeps one."""
    def selection_pivot -> Vec3 | None;
    """Where the selection turns and stretches about when nothing says
    otherwise: its middle, put on the grid."""
    def selection_hub(grid: float = 8.0) -> Vec3 | None;
    """Give the one selected group a pivot of its own, or take it away."""
    def set_pivot(at: Vec3 | None) -> bool;
    """Push every side of the selected brushes out by a distance (in, when it
    is negative). Answers how many brushes changed."""
    def inflate_selection(amount: float) -> int;
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

    """Add a terrain: a group of two prisms a cell over a base, its heights
    kept in its fields. `origin` is the low corner of its underside."""
    def make_terrain(
        origin: Vec3, cols: int, rows: int, cell: float, material: str = "", base: float = 16.0
    ) -> Item | None;
    """A terrain's grid from its fields: [cols, rows, cell, base], or none
    when the entity is not a terrain."""
    def terrain_grid(item: Item) -> list[float] | None;
    """Give a terrain other heights and build its brushes again from them."""
    def set_heights(item: Item, heights: list[float], label: str = "Sculpt") -> bool;
    """A stroke of a sculpting brush on a terrain, centred at (x, y)."""
    def sculpt_terrain(item: Item, x: float, y: float, radius: float, amount: float, how: str = "raise") -> bool;

    """Give every side that has one material another: in the selected
    brushes, or in every brush. Answers how many sides changed."""
    def replace_material(old: str, fresh: str, everywhere: bool = False) -> int;
    """Put the corners of the selected brushes, and the origins of the
    selected entities, on a grid. Answers how many things moved."""
    def snap_selection(size: float = 8.0, whole: bool = False) -> int;
    """How many brushes have a corner, and entities an origin, off a grid."""
    def off_grid(size: float = 8.0) -> int;
    """Line the selected brushes up along an axis: their low sides, their
    high sides or their middles brought to the selection's own."""
    def align_selection(axis: int, how: str = "low") -> bool;
    """Every side of the brushes that have a picked face becomes picked."""
    def pick_all_faces -> int;
    """Within the brushes that have picked faces: the others, instead."""
    def invert_faces -> int;
    """Pick, in every brush of the document, the faces that lie in the
    plane of a picked face and face its way."""
    def extend_faces -> int;
    """Move the selected brushes so that the side of each that most nearly
    faces a plane lies on it (glued against the face that has that plane)."""
    def glue_selection(plane: Plane3) -> bool;
    """Counts of what the document holds: brushes, sides, entities by
    class, materials by how many sides have them."""
    def statistics -> list[str];

    """Add a patch: a group of thin prisms under the surface its control
    points bend, the points kept in its fields."""
    def make_patch(
        points: list[Vec3], width: int, height: int, material: str = "", steps: int = 4, thickness: float = 8.0
    ) -> Item | None;
    """A patch's grid from its fields: [width, height, steps, thickness], or
    none when the entity is not a patch."""
    def patch_grid(item: Item) -> list[float] | None;
    def patch_control(item: Item) -> list[Vec3] | None;
    """Give a patch other control points and build its prisms again."""
    def set_patch(item: Item, points: list[Vec3], label: str = "Bend") -> bool;
    def move_patch_point(item: Item, index: int, delta: Vec3) -> bool;

    """Put the selection out of sight (and out of the selection). Answers
    how many things were hidden."""
    def hide_selection -> int;
    """Hide everything but the selection."""
    def hide_others -> int;
    """Bring everything hidden back. Answers how many things were."""
    def show_all -> int;
    def hidden_count -> int;
    """The document as a map without what is hidden: what is built while
    editing."""
    def shown_map -> list[MapItem];
    """Select every entity whose field has a value. Answers how many."""
    def select_field(key: str, value: str) -> int;

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

    """Move one side of a brush along its normal, and with it every side
    linked to it."""
    def push_side(solid: Solid, index: int, distance: float) -> bool {
        if index < 0 or index >= len(solid.sides) or distance == 0.0 {
            return False;
        }
        delta = solid.sides[index].plane.normal.scale(distance);
        tied = self.linked_sides(solid, index);
        if len(tied) == 0 {
            after = list(solid.sides);
            after[index] = side_moved(solid.sides[index], delta);
            return self.reshape(solid, after, "Resize");
        }
        # All of them or none: a brush left with nothing inside stops the push.
        step = Step(label="Resize");
        for pick in [FacePick(solid=solid, side=index)] + tied {
            moved = list(pick.solid.sides);
            moved[pick.side] = side_moved(pick.solid.sides[pick.side], delta);
            if not sides_enclose(moved) {
                for earlier in step.changes {
                    earlier.undo();
                }
                return False;
            }
            change = SidesChange(solid=pick.solid, before=pick.solid.sides, after=moved);
            change.redo();
            step.changes.append(change);
        }
        return self.commit(step);
    }

    # Linked faces, mitred seams and merged corners (impl/scene.links.impl.jac)

    """The side of a brush that lies in a plane (-1 when none does)."""
    def side_in(solid: Solid, plane: Plane3) -> int;
    """Every side linked to a side, through however many links: each brush
    still in the document, with the side of it that is still in the plane."""
    def linked_sides(solid: Solid, index: int) -> list[FacePick];
    """Link a side of one brush to a side of another. They must lie in one
    plane. False when they do not, or are linked already."""
    def link_sides(first: Solid, index: int, second: Solid, other: int) -> bool;
    """Take a side out of every link it is in. Answers how many links went."""
    def unlink_side(solid: Solid, index: int) -> int;
    """Link the selected faces that lie in one plane with the first of them.
    Answers how many links were made."""
    def link_faces -> int;
    """Link every pair of sides, among these brushes, that lie in one plane
    facing the same way: the faces a cut left in several pieces. Answers
    how many links were made."""
    def link_coplanar(solids: list[Solid]) -> int;
    """How many links there are between brushes still in the document."""
    def link_count -> int;
    """The links as a map file keeps them, and back."""
    def links_words -> str;
    def restore_links(words: str, placed: list[Item]);
    """Cut the two selected brushes on the plane that halves the angle
    between them where they overlap, so that they meet in a seam."""
    def miter_selection -> bool;
    """Move one corner of a brush onto another, leaving one where two were."""
    def merge_corners(solid: Solid, first: Vec3, second: Vec3) -> bool;

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
    def turn_selection(
        degrees: float, grid: float = 8.0, axis: int = 2, about: Vec3 | None = None, locked: bool = True
    ) -> bool {
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
        if about is not None {
            pivot = about;
        }
        step = Step(label="Turn");
        self spawn Turn(pivot=pivot, angle=math.radians(degrees), step=step, axis=axis, locked=locked);
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

    def shift_selection(delta: Vec3, locked: bool = True) -> bool {
        step = Step(label="Move");
        self spawn Shift(delta=delta, step=step, locked=locked);
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
    written = [
        MapItem(fields=dict(item.fields), brushes=[solid.sides for solid in scene.solids_of(item)])
        for item in scene.items()
    ];
    if len(written) > 0 {
        # The kept selections ride in the first entity's fields.
        for name in scene.set_names {
            words = scene.set_words(name);
            if words {
                written[0].fields[SET_PREFIX + name] = words;
            }
        }
        if len(scene.layers_off) > 0 {
            written[0].fields[LAYERS_KEY] = " ".join(sorted(scene.layers_off));
        }
        linked = scene.links_words();
        if linked {
            written[0].fields[LINKS_KEY] = linked;
        }
    }
    return written;
}

"""A document of a map file's entities and brushes."""
def scene_from_map(game: str, name: str, found: MapFile) -> Scene {
    scene = Scene(game=game, name=name);
    placed: list[Item] = [];
    for read in found.items {
        item = scene.add_item(dict(read.fields));
        placed.append(item);
        for sides in read.brushes {
            scene.add_solid(item, sides);
        }
        # A curved patch of the map becomes a patch of the scene: a group
        # of its own, its control points in its fields.
        for bent in read.patches {
            prisms = patch_brushes(bent.points, bent.width, bent.height, 4, 8.0, bent.material);
            if len(prisms) == 0 {
                continue;
            }
            group = scene.add_item(
                {
                    "classname": "func_group",
                    "_group_name": "patch",
                    "_patch": str(bent.width) + " " + str(bent.height) + " 4 8",
                    "_points": points_text(bent.points)
                }
            );
            for sides in prisms {
                scene.add_solid(group, sides);
            }
        }
    }
    if len(placed) > 0 {
        # Kept selections come back as sets, and leave the fields.
        first = placed[0];
        for key in [key for key in first.fields.keys() if key.startswith(SET_PREFIX)] {
            scene.restore_set(key[len(SET_PREFIX):], first.fields[key], placed);
            first.fields.pop(key, None);
        }
        # And the layers that were off are off again.
        for name in first.fields.get(LAYERS_KEY, "").split() {
            scene.show_layer(name, False);
        }
        first.fields.pop(LAYERS_KEY, None);
        # And the faces that were linked are linked again.
        scene.restore_links(first.fields.get(LINKS_KEY, ""), placed);
        first.fields.pop(LINKS_KEY, None);
        scene.dirty = False;
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
