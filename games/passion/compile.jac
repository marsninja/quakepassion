"""Compile a column blueprint into BSP geometry, brush models and entities.

Open columns become merged floor and ceiling pillars; solid columns beside open
space become walls. A face is kept only when it faces real air, so hidden
surfaces never cost lightmap texels. Every surface lists the leaves whose air
it faces, which is exactly what cluster visibility needs.
"""
import from engine.formats.bsp { Bsp, Model, MapEntity }
import from engine.math.vec3 { Vec3 }
import from .geometry { Builder, partition }
import from .layout { Site, CELL, UNIT }
import from .blueprint {
    Blueprint,
    STYLE_COVER,
    STYLE_STAIR,
    STYLE_PILLAR,
    STYLE_WINDOW
}
import from .materials {
    material,
    FLOOR,
    WALL_SLOT,
    CEILING,
    TRIM,
    ACCENT,
    MAT_WATER,
    MAT_SLIME,
    MAT_LAVA,
    MAT_TELEPORT,
    MAT_BUTTON,
    MAT_SHOOT,
    MAT_KEYDOOR,
    MAT_SIGN,
    MAT_LAMP
}



obj Compiled {
    has bsp: Bsp,
        leaf_of_macro: list[int] = [],
        exit_low: list[float] = [],
        exit_high: list[float] = [],
        faces_world: int = 0,
        brushes_world: int = 0;
}

obj Span {
    has x0: int, y0: int, x1: int, y1: int;
}

# Greedy rectangle merging over columns that share a key.
def merge(keys: list[str], width: int, height: int) -> list[Span] {
    used = [False for _ in range(width * height)];
    spans: list[Span] = [];
    for y in range(height) {
        for x in range(width) {
            i = y * width + x;
            if used[i] or not keys[i] {
                continue;
            }
            key = keys[i];
            x1 = x + 1;
            while x1 < width and not used[y * width + x1] and keys[y * width + x1] == key {
                x1 += 1;
            }
            y1 = y + 1;
            grow = True;
            while grow and y1 < height {
                for cx in range(x, x1) {
                    j = y1 * width + cx;
                    if used[j] or keys[j] != key {
                        grow = False;
                        break;
                    }
                }
                if grow {
                    y1 += 1;
                }
            }
            for cy in range(y, y1) {
                for cx in range(x, x1) {
                    used[cy * width + cx] = True;
                }
            }
            spans.append(Span(x0=x, y0=y, x1=x1, y1=y1));
        }
    }
    return spans;
}

obj Context {
    has bp: Blueprint, builder: Builder, leaf_of_macro: list[int], macro_width: int;

    def leaf_at(x: int, y: int) -> int {
        mx = min(self.macro_width - 1, max(0, x // CELL));
        my = max(0, y // CELL);
        index = my * self.macro_width + mx;
        if index >= len(self.leaf_of_macro) {
            index = len(self.leaf_of_macro) - 1;
        }
        return self.leaf_of_macro[index];
    }

    def air(x: int, y: int) -> list[int] {
        bp = self.bp;
        if x < 0 or y < 0 or x >= bp.width or y >= bp.height {
            return [];
        }
        i = bp.index(x, y);
        if not bp.open(i) {
            return [];
        }
        return [bp.floor[i], bp.ceiling[i]];
    }
}

# Which leaves see a box side: the air columns along that side overlapping it.
def side_owners(ctx: Context, span: Span, side: int, low: int, high: int) -> list[int] {
    cells: list[list[int]] = [];
    if side == 0 or side == 1 {
        for y in range(span.y0, span.y1) {
            for x in range(span.x0, span.x1) {
                cells.append([x, y]);
            }
        }
        owners: list[int] = [];
        for cell in cells {
            leaf = ctx.leaf_at(cell[0], cell[1]);
            if leaf not in owners {
                owners.append(leaf);
            }
        }
        return owners;
    }
    if side == 2 {
        for x in range(span.x0, span.x1) {
            cells.append([x, span.y0 - 1]);
        }
    } elif side == 3 {
        for y in range(span.y0, span.y1) {
            cells.append([span.x1, y]);
        }
    } elif side == 4 {
        for x in range(span.x0, span.x1) {
            cells.append([x, span.y1]);
        }
    } else {
        for y in range(span.y0, span.y1) {
            cells.append([span.x0 - 1, y]);
        }
    }
    owners: list[int] = [];
    for cell in cells {
        interval = ctx.air(cell[0], cell[1]);
        if not interval {
            continue;
        }
        if interval[0] < high and interval[1] > low {
            leaf = ctx.leaf_at(cell[0], cell[1]);
            if leaf not in owners {
                owners.append(leaf);
            }
        }
    }
    return owners;
}

def emit(
    ctx: Context,
    span: Span,
    low: int,
    high: int,
    materials: list[int],
    faces_up: bool,
    faces_down: bool,
    contents: int = 1
) {
    owners: list[list[int]] = [];
    visible: list[bool] = [];
    for side in range(6) {
        found: list[int] = [];
        if side == 0 {
            found = side_owners(ctx, span, 0, low, high) if faces_down else [];
        } elif side == 1 {
            found = side_owners(ctx, span, 1, low, high) if faces_up else [];
        } else {
            found = side_owners(ctx, span, side, low, high);
        }
        owners.append(found);
        visible.append(len(found) > 0);
    }
    ctx.builder.block_shared(
        Vec3(x=float(span.x0) * UNIT, y=float(span.y0) * UNIT, z=float(low)),
        Vec3(x=float(span.x1) * UNIT, y=float(span.y1) * UNIT, z=float(high)),
        materials,
        visible,
        owners,
        contents
    );
}

def neighbor_range(bp: Blueprint, x: int, y: int) -> list[int] {
    # [lowest floor, highest ceiling] among open 4-neighbors (empty if none).
    low = 1000000;
    high = -1000000;
    for delta in [[1, 0], [-1, 0], [0, 1], [0, -1]] {
        nx = x + delta[0];
        ny = y + delta[1];
        if nx < 0 or ny < 0 or nx >= bp.width or ny >= bp.height {
            continue;
        }
        j = bp.index(nx, ny);
        if bp.open(j) {
            low = min(low, bp.floor[j]);
            high = max(high, bp.ceiling[j]);
        }
    }
    if low > high {
        return [];
    }
    return [low, high];
}

def neighbor_zone(bp: Blueprint, x: int, y: int) -> int {
    for delta in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]] {
        nx = x + delta[0];
        ny = y + delta[1];
        if nx < 0 or ny < 0 or nx >= bp.width or ny >= bp.height {
            continue;
        }
        j = bp.index(nx, ny);
        if bp.open(j) {
            return bp.zone[j];
        }
    }
    return bp.zone[bp.index(x, y)];
}

def build_world(ctx: Context) {
    bp = ctx.bp;
    count = bp.width * bp.height;
    floor_keys = ["" for _ in range(count)];
    ceiling_keys = ["" for _ in range(count)];
    wall_keys = ["" for _ in range(count)];
    floor_low = [0 for _ in range(count)];
    ceiling_high = [0 for _ in range(count)];
    wall_low = [0 for _ in range(count)];
    wall_high = [0 for _ in range(count)];
    for y in range(bp.height) {
        for x in range(bp.width) {
            i = bp.index(x, y);
            around = neighbor_range(bp, x, y);
            if bp.open(i) {
                bottom = bp.floor[i] - 16;
                top = bp.ceiling[i] + 16;
                if around {
                    bottom = min(bottom, around[0] - 16);
                    top = max(top, around[1] + 16);
                }
                floor_low[i] = bottom;
                ceiling_high[i] = top;
                zone = bp.zone[i];
                style = bp.style[i];
                top_material = material(zone, FLOOR);
                side_material = material(zone, TRIM);
                if style == STYLE_COVER {
                    top_material = material(zone, ACCENT);
                    side_material = material(zone, ACCENT);
                } elif style == STYLE_STAIR {
                    side_material = material(zone, TRIM);
                } elif style == STYLE_WINDOW {
                    side_material = material(zone, WALL_SLOT);
                    top_material = material(zone, TRIM);
                }
                floor_keys[i] = str(bp.floor[i]) + "|" + str(bottom) + "|" + str(top_material) + "|" + str(side_material) + "|" + str(bp.region[i]);
                ceiling_keys[i] = str(bp.ceiling[i]) + "|" + str(top) + "|" + str(zone) + "|" + str(bp.region[i]) + "|" + str(style == STYLE_WINDOW);
            } elif around {
                wall_low[i] = around[0] - 16;
                wall_high[i] = around[1] + 16;
                zone = neighbor_zone(bp, x, y);
                slot = TRIM if bp.style[i] == STYLE_PILLAR else WALL_SLOT;
                wall_keys[i] = str(wall_low[i]) + "|" + str(wall_high[i]) + "|" + str(material(zone, slot));
            }
        }
    }
    for span in merge(floor_keys, bp.width, bp.height) {
        i = bp.index(span.x0, span.y0);
        parts = floor_keys[i].split("|");
        top_material = int(parts[2]);
        side_material = int(parts[3]);
        emit(
            ctx,
            span,
            floor_low[i],
            bp.floor[i],
            [side_material, top_material, side_material, side_material, side_material, side_material],
            True,
            False
        );
    }
    for span in merge(ceiling_keys, bp.width, bp.height) {
        i = bp.index(span.x0, span.y0);
        zone = bp.zone[i];
        side = material(zone, WALL_SLOT) if bp.style[i] != STYLE_WINDOW else material(zone, TRIM);
        emit(
            ctx,
            span,
            bp.ceiling[i],
            ceiling_high[i],
            [material(zone, CEILING), side, side, side, side, side],
            False,
            True
        );
    }
    for span in merge(wall_keys, bp.width, bp.height) {
        i = bp.index(span.x0, span.y0);
        chosen = int(wall_keys[i].split("|")[2]);
        emit(ctx, span, wall_low[i], wall_high[i], [chosen for _ in range(6)], False, False);
    }
}

def build_liquids(ctx: Context) {
    bp = ctx.bp;
    count = bp.width * bp.height;
    keys = ["" for _ in range(count)];
    for i in range(count) {
        if bp.open(i) and bp.liquid[i] != 0 and bp.surface[i] > bp.floor[i] {
            keys[i] = str(bp.liquid[i]) + "|" + str(bp.floor[i]) + "|" + str(bp.surface[i]);
        }
    }
    for span in merge(keys, bp.width, bp.height) {
        i = bp.index(span.x0, span.y0);
        kind = bp.liquid[i];
        texture = MAT_WATER if kind == 32 else (MAT_SLIME if kind == 16 else MAT_LAVA);
        first_face = len(ctx.builder.bsp.faces);
        owners = side_owners(ctx, span, 1, bp.floor[i], bp.surface[i]);
        ctx.builder.block_shared(
            Vec3(x=float(span.x0) * UNIT, y=float(span.y0) * UNIT, z=float(bp.floor[i])),
            Vec3(x=float(span.x1) * UNIT, y=float(span.y1) * UNIT, z=float(bp.surface[i])),
            [texture for _ in range(6)],
            [False, True, False, False, False, False],
            [[], owners, [], [], [], []],
            kind
        );
        for face in ctx.builder.bsp.faces[first_face:] {
            face.two_sided = True;
        }
    }
}

def build_plates(ctx: Context) {
    for plate in ctx.bp.plates {
        texture = MAT_SIGN if plate.material == -1 else MAT_TELEPORT;
        low = Vec3(x=plate.low[0], y=plate.low[1], z=plate.low[2]);
        high = Vec3(x=plate.high[0], y=plate.high[1], z=plate.high[2]);
        leaf = ctx.leaf_at(int(plate.low[0] / UNIT) + 1, int(plate.low[1] / UNIT) + 1);
        ctx.builder.block_shared(
            low,
            high,
            [texture for _ in range(6)],
            [False, True, True, True, True, True],
            [[leaf] for _ in range(6)],
            1
        );
    }
}

# Emissive fixtures sit just under the ceiling above every ceiling lamp.
def build_fixtures(ctx: Context) {
    bp = ctx.bp;
    for lamp in bp.lamps {
        x = int(lamp.x / UNIT);
        y = int(lamp.y / UNIT);
        if x < 0 or y < 0 or x >= bp.width or y >= bp.height {
            continue;
        }
        i = bp.index(x, y);
        if not bp.open(i) or abs(float(bp.ceiling[i]) - (lamp.z + 8.0)) > 1.0 {
            continue;
        }
        z = float(bp.ceiling[i]) - 0.5;
        leaf = ctx.leaf_at(x, y);
        ctx.builder.owner = leaf;
        ctx.builder.panel(
            [
                Vec3(x=lamp.x - 20.0, y=lamp.y - 10.0, z=z),
                Vec3(x=lamp.x - 20.0, y=lamp.y + 10.0, z=z),
                Vec3(x=lamp.x + 20.0, y=lamp.y + 10.0, z=z),
                Vec3(x=lamp.x + 20.0, y=lamp.y - 10.0, z=z)
            ],
            MAT_LAMP + lamp.color
        );
        ctx.builder.bsp.faces[-1].emission = True;
    }
}

def origin_text(x: float, y: float, z: float) -> str {
    return str(x) + " " + str(y) + " " + str(z);
}

def:priv add_model(bsp: Bsp) -> int {
    bsp.models.append(Model(head=0, first_face=len(bsp.faces), face_count=0));
    return len(bsp.models) - 1;
}

def build_movers(ctx: Context) -> list[float] {
    bp = ctx.bp;
    bsp = ctx.builder.bsp;
    exit_box: list[float] = [];
    for door in bp.doors {
        if door.kind == "invalid" or not door.cells {
            continue;
        }
        xs = [cell % bp.width for cell in door.cells];
        ys = [cell // bp.width for cell in door.cells];
        low = Vec3();
        high = Vec3();
        if door.across_x {
            low = Vec3(x=float(min(xs)) * UNIT, y=float(ys[0]) * UNIT + 8.0, z=float(door.floor));
            high = Vec3(x=float(max(xs) + 1) * UNIT, y=float(ys[0]) * UNIT + 24.0, z=float(door.ceiling));
        } else {
            low = Vec3(x=float(xs[0]) * UNIT + 8.0, y=float(min(ys)) * UNIT, z=float(door.floor));
            high = Vec3(x=float(xs[0]) * UNIT + 24.0, y=float(max(ys) + 1) * UNIT, z=float(door.ceiling));
        }
        texture = material(door.material, ACCENT);
        if door.kind == "key" {
            texture = MAT_KEYDOOR;
        } elif door.kind == "secret" {
            texture = material(door.material, WALL_SLOT);
        } elif door.kind in ["remote", "guardian"] {
            texture = material(door.material, TRIM);
        }
        model = add_model(bsp);
        leaf = ctx.leaf_at(xs[0], ys[0]);
        ctx.builder.owner = leaf;
        ctx.builder.block_shared(low, high, [texture for _ in range(6)], [True for _ in range(6)], [[leaf] for _ in range(6)], 1, model);
        fields: dict[str, str] = {
            "classname": "func_door",
            "model": "*" + str(model),
            "angle": "-1",
            "speed": "60" if door.kind == "secret" else "160",
            "wait": "-1",
            "lip": "8"
        };
        if door.kind == "key" {
            fields["key"] = " ".join(door.keys);
        } else {
            fields["targetname"] = door.name;
        }
        bsp.entities.append(MapEntity(fields=fields));
    }
    for volume in bp.volumes {
        low = Vec3(x=volume.low[0], y=volume.low[1], z=volume.low[2]);
        high = Vec3(x=volume.high[0], y=volume.high[1], z=volume.high[2]);
        if volume.kind == "exit" {
            exit_box = volume.low + volume.high;
            continue;
        }
        model = add_model(bsp);
        leaf = ctx.leaf_at(int(volume.low[0] / UNIT), int(volume.low[1] / UNIT));
        ctx.builder.owner = leaf;
        fields: dict[str, str] = {"model": "*" + str(model)};
        if volume.kind in ["button", "shootable"] {
            texture = MAT_BUTTON if volume.kind == "button" else MAT_SHOOT;
            ctx.builder.block_shared(low, high, [texture for _ in range(6)], [True for _ in range(6)], [[leaf] for _ in range(6)], 1, model);
            fields["classname"] = "func_button";
            fields["angle"] = "-2" if volume.kind == "button" else "-1";
            fields["target"] = volume.target;
            fields["wait"] = "-1";
            if volume.kind == "shootable" {
                fields["health"] = "1";
            }
        } else {
            ctx.builder.volume(low, high, model);
            fields["classname"] = "trigger_once" if volume.kind == "once" else "trigger_teleport";
            fields["target"] = volume.target;
            if volume.kind == "once" {
                fields["wait"] = "-1";
            }
        }
        bsp.entities.append(MapEntity(fields=fields));
    }
    return exit_box;
}

def build_entities(ctx: Context) {
    bsp = ctx.builder.bsp;
    for mark in ctx.bp.marks {
        fields: dict[str, str] = {
            "classname": mark.kind,
            "origin": origin_text(mark.x, mark.y, mark.z),
            "asset_game": mark.source
        };
        if mark.angle != 0.0 {
            fields["angle"] = str(int(mark.angle));
        }
        for key in mark.fields {
            fields[key] = mark.fields[key];
        }
        bsp.entities.append(MapEntity(fields=fields));
    }
}

def macro_owners(bp: Blueprint, site: Site) -> list[int] {
    owners = [-1 for _ in range(site.width * site.height)];
    for my in range(site.height) {
        for mx in range(site.width) {
            counts: dict[int, int] = {};
            for dy in range(CELL) {
                for dx in range(CELL) {
                    x = mx * CELL + dx;
                    y = my * CELL + dy;
                    if x >= bp.width or y >= bp.height {
                        continue;
                    }
                    i = bp.index(x, y);
                    if bp.open(i) {
                        counts[bp.region[i]] = counts.get(bp.region[i], 0) + 1;
                    }
                }
            }
            best = -1;
            best_count = 0;
            for region in counts {
                if counts[region] > best_count {
                    best = region;
                    best_count = counts[region];
                }
            }
            owners[my * site.width + mx] = best;
        }
    }
    return owners;
}

def compile_blueprint(bp: Blueprint, site: Site) -> Compiled {
    builder = Builder();
    bsp = builder.bsp;
    bsp.models.append(Model(head=0, first_face=0, face_count=0));
    owners = macro_owners(bp, site);
    leaf_owner: list[int] = [];
    head = partition(bsp, owners, site.width, 0, 0, site.width, site.height, float(CELL) * UNIT, leaf_owner);
    bsp.models[0].head = head;
    bsp.models[0].vis_leaf_count = len(bsp.leaves) - 1;
    leaf_of_macro = [0 for _ in range(site.width * site.height)];
    for leaf_index in range(len(bsp.leaves)) {
        leaf = bsp.leaves[leaf_index];
        leaf.cluster = leaf_owner[leaf_index];
        x0 = int(leaf.mins.x / (float(CELL) * UNIT) + 0.5);
        y0 = int(leaf.mins.y / (float(CELL) * UNIT) + 0.5);
        x1 = int(leaf.maxs.x / (float(CELL) * UNIT) + 0.5);
        y1 = int(leaf.maxs.y / (float(CELL) * UNIT) + 0.5);
        for my in range(y0, y1) {
            for mx in range(x0, x1) {
                leaf_of_macro[my * site.width + mx] = leaf_index;
            }
        }
    }
    ctx = Context(bp=bp, builder=builder, leaf_of_macro=leaf_of_macro, macro_width=site.width);
    build_world(ctx);
    build_liquids(ctx);
    build_plates(ctx);
    build_fixtures(ctx);
    world_faces = len(bsp.faces);
    world_brushes = len(bsp.brushes);
    bsp.entities.append(MapEntity(fields={"classname": "worldspawn", "generator": "passion-v2"}));
    exit_box = build_movers(ctx);
    build_entities(ctx);
    if len(bsp.models) < 2 {
        # Lighting treats faces from models[1] onward as moving; keep one sentinel.
        add_model(bsp);
    }
    result = Compiled(bsp=bsp, leaf_of_macro=leaf_of_macro, faces_world=world_faces, brushes_world=world_brushes);
    if exit_box {
        result.exit_low = exit_box[0:3];
        result.exit_high = exit_box[3:6];
    }
    return result;
}
