"""The studio's document is a graph.

A Scene holds an Item for every entity of the map and points at the selected
ones with Selected edges. Every edit is a walker that travels from the scene
to the selection and writes down what it changed, so each edit undoes; the
journal keeps those steps. Nothing here knows about the window: the same
edits run from the interface, from the console and from tests."""
import from engine.formats.bsp { MapEntity, entity_text }
import from engine.math.vec3 { Vec3 }
import from ..geometry.brush { Side, Plane3, Mapping, brush_windings, windings_bounds }
import from ..formats.map { MapItem, MapFile }

edge Holds: Scene --> Item {}

"""An entity owns the brushes that make it: the world its walls, a door its
slab."""
edge Owns: Item --> Solid {}

edge Selected: Scene --> Item | Solid {}

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

"""One reversible change."""
obj Change {
    def undo abst;
    def redo abst;
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
}

"""One edit as the journal keeps it: what to call it and what it changed."""
obj Step {
    has label: str,
        changes: list[Change] = [];
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

"""Copy every selected point entity, `offset` away from the original. Brush
entities are not copied: two cannot share a map model."""
walker Clone {
    has offset: Vec3,
        step: Step,
        scene: Scene | None = None,
        made: list[Item] = [],
        made_solids: list[Solid] = [];

    can start with Scene entry {
        self.scene = here;
        visit [here->:Selected:->];
    }

    can apply with Item entry {
        scene = self.scene;
        if scene is None or here.model() >= 0 or here.classname() == "worldspawn" {
            return;
        }
        copy = scene.add_item(dict(here.fields));
        at = copy.origin();
        if at is not None {
            copy.fields["origin"] = write_vector(at.add(self.offset));
        }
        self.step.changes.append(HoldChange(item=copy, held=True));
        self.made.append(copy);
    }

    can copy_solid with Solid entry {
        scene = self.scene;
        if scene is None or not here.held {
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

"""A map being edited. `revision` counts changes to its items and `picks`
changes to the selection, so panels know when to refresh."""
node Scene {
    has game: str = "",
        name: str = "",
        revision: int = 0,
        picks: int = 0,
        dirty: bool = False,
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
