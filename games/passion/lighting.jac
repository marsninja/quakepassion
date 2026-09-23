"""Deterministic generated lightmaps and probes, cached by complete bake inputs.

Lamps come from the blueprint (room grids, corridor runs, objective accents).
A face only gathers lamps whose cluster can see one of the face's clusters and
whose range reaches the face, so bake cost grows with local density instead of
level size. Probe grids follow each cluster's bounds and are looked up through
the macro floor plan.
"""
import os;
import math;
import struct;
import hashlib;
import from engine.world.lighting {
    Lighting,
    Lamp,
    Emits,
    GatherLamps,
    ProbeRegion,
    Illumination,
    Occluder,
    shade
}
import from engine.world.level { Level }
import from engine.math.vec3 { Vec3 }
import from engine.formats.bsp { Face }
import from .blueprint { Blueprint }
import from .layout { Site, CELL }
import from .materials { LAMP_RGB }

glob BAKE_VERSION: bytes = b"passion-lighting-2-spacing32-pvs-columns-soft2-ambient012";

def axes(face: Face) -> list[Vec3] {
    u = face.vertices[1].sub(face.vertices[0]).normalized();
    v = face.vertices[-1].sub(face.vertices[0]).normalized();
    return [u, v];
}

def layout(level: Level) -> int {
    offset = 0;
    moving = level.bsp.models[1].first_face if len(level.bsp.models) > 1 else len(level.bsp.faces);
    for index in range(len(level.bsp.faces)) {
        face = level.bsp.faces[index];
        face.colors = [];
        face.light_uv = [];
        face.light_offset = -1;
        face.moving_light = index >= moving;
        if face.emission or face.moving_light {
            continue;
        }
        width = face.vertices[1].sub(face.vertices[0]).length();
        height = face.vertices[-1].sub(face.vertices[0]).length();
        face.light_width = int(math.ceil(width / 32.0)) + 1;
        face.light_height = int(math.ceil(height / 32.0)) + 1;
        face.light_offset = offset;
        face.styles = [0];
        basis = axes(face);
        for vertex in face.vertices {
            delta = vertex.sub(face.vertices[0]);
            face.light_uv.extend(
                [
                    delta.dot(basis[0]) / width * float(face.light_width - 1),
                    delta.dot(basis[1]) / height * float(face.light_height - 1)
                ]
            );
        }
        offset += face.light_width * face.light_height * 3;
    }
    level.bsp.light_channels = 3;
    return offset;
}

def cache_key(level: Level, lamps: list[Lamp]) -> str {
    digest = hashlib.sha256(BAKE_VERSION);
    digest.update(level.name.encode());
    for texture in level.bsp.textures {
        digest.update(texture.name.encode());
        digest.update(texture.rgba);
        digest.update(texture.encoded);
        digest.update(texture.pixels);
    }
    for face in level.bsp.faces {
        digest.update(str(face.texture).encode());
        for vertex in face.vertices {
            digest.update(struct.pack("<ddd", vertex.x, vertex.y, vertex.z));
        }
    }
    for lamp in lamps {
        digest.update(
            struct.pack(
                "<dddddddd",
                lamp.origin.x,
                lamp.origin.y,
                lamp.origin.z,
                lamp.color.x,
                lamp.color.y,
                lamp.color.z,
                lamp.radius,
                lamp.strength
            )
        );
    }
    digest.update(level.bsp.visibility);
    return digest.hexdigest();
}

def probe_count(lighting: Lighting) -> int {
    total = 0;
    for region in lighting.regions {
        total += region.counts[0] * region.counts[1] * region.counts[2];
    }
    return total;
}

def pack_probes(lighting: Lighting) -> bytes {
    data = bytearray();
    for region in lighting.regions {
        for i in range(region.counts[0] * region.counts[1] * region.counts[2]) {
            sample = region.samples[i];
            data.append(1 if region.valid[i] else 0);
            for vector in [sample.ambient, sample.directed, sample.direction] {
                data.extend(struct.pack("<fff", vector.x, vector.y, vector.z));
            }
        }
    }
    return bytes(data);
}

def unpack_probes(data: bytes, lighting: Lighting) {
    if len(data) != probe_count(lighting) * 37 {
        raise ValueError("Invalid probe cache length");
    }
    offset = 0;
    for region in lighting.regions {
        region.samples = [];
        region.valid = [];
        for i in range(region.counts[0] * region.counts[1] * region.counts[2]) {
            if data[offset] > 1 {
                raise ValueError("Invalid probe validity");
            }
            region.valid.append(data[offset] == 1);
            offset += 1;
            vectors: list[Vec3] = [];
            for v in range(3) {
                components = struct.unpack("<fff", data[offset:offset + 12]);
                offset += 12;
                x = float(components[0]);
                y = float(components[1]);
                z = float(components[2]);
                if not math.isfinite(x)
                    or not math.isfinite(y)
                    or not math.isfinite(z)
                    or abs(x) > 16.0
                    or abs(y) > 16.0
                    or abs(z) > 16.0 {
                    raise ValueError("Invalid probe value");
                }
                vectors.append(Vec3(x=x, y=y, z=z));
            }
            region.samples.append(
                Illumination(
                    ambient=vectors[0], directed=vectors[1], direction=vectors[2]
                )
            );
        }
    }
}

def visible_row(level: Level, cluster: int) -> list[bool] {
    count = level.bsp.clusters;
    row = [False for _ in range(count)];
    if cluster < 0 or cluster >= count {
        return [True for _ in range(count)];
    }
    base = 8 + cluster * level.bsp.cluster_bytes;
    for target in range(count) {
        if int(level.bsp.visibility[base + target // 8]) & (1 << (target % 8)) {
            row[target] = True;
        }
    }
    return row;
}

obj Rig {
    has lamps: list[Lamp] = [], clusters: list[int] = [], rows: list[list[bool]] = [];

    # Lamps that can see any of the given clusters and reach the sphere.
    def near(clusters: list[int], center: Vec3, extent: float) -> list[Lamp] {
        result: list[Lamp] = [];
        for index in range(len(self.lamps)) {
            lamp = self.lamps[index];
            if lamp.origin.sub(center).length() > lamp.radius + extent {
                continue;
            }
            home = self.clusters[index];
            seen = home < 0 or not clusters;
            for cluster in clusters {
                if seen {
                    break;
                }
                if cluster < 0 or (0 <= home < len(self.rows) and self.rows[home][cluster]) {
                    seen = True;
                }
            }
            if seen {
                result.append(lamp);
            }
        }
        return result;
    }
}

# Exact shadow rays for a column heightfield: walk the columns a segment
# crosses (Amanatides-Woo) and require its height span inside each column's air.
obj ColumnOccluder(Occluder) {
    has bp: Blueprint;

    def clear(sx: float, sy: float, sz: float, ex: float, ey: float, ez: float) -> bool {
        bp = self.bp;
        x = int(math.floor(sx / 32.0));
        y = int(math.floor(sy / 32.0));
        end_x = int(math.floor(ex / 32.0));
        end_y = int(math.floor(ey / 32.0));
        dx = ex - sx;
        dy = ey - sy;
        step_x = 1 if dx > 0.0 else -1;
        step_y = 1 if dy > 0.0 else -1;
        next_x = 1000000.0;
        next_y = 1000000.0;
        delta_x = 1000000.0;
        delta_y = 1000000.0;
        if abs(dx) > 0.000001 {
            boundary = float(x + (1 if dx > 0.0 else 0)) * 32.0;
            next_x = (boundary - sx) / dx;
            delta_x = 32.0 / abs(dx);
        }
        if abs(dy) > 0.000001 {
            boundary = float(y + (1 if dy > 0.0 else 0)) * 32.0;
            next_y = (boundary - sy) / dy;
            delta_y = 32.0 / abs(dy);
        }
        t = 0.0;
        for guard in range(4096) {
            leave = min(1.0, min(next_x, next_y));
            if x < 0 or y < 0 or x >= bp.width or y >= bp.height {
                return False;
            }
            i = y * bp.width + x;
            if bp.region[i] < 0 {
                return False;
            }
            z0 = sz + (ez - sz) * t;
            z1 = sz + (ez - sz) * leave;
            if min(z0, z1) < float(bp.floor[i]) - 0.3 or max(z0, z1) > float(bp.ceiling[i]) + 0.3 {
                return False;
            }
            if (x == end_x and y == end_y) or leave >= 1.0 {
                return True;
            }
            t = leave;
            if next_x < next_y {
                x += step_x;
                next_x += delta_x;
            } else {
                y += step_y;
                next_y += delta_y;
            }
        }
        return True;
    }

    def visibility(point: Vec3, target: Vec3) -> float {
        if self.clear(point.x, point.y, point.z, target.x, target.y, target.z) {
            return 1.0;
        }
        result = 0.0;
        for offset in [-6.0, 6.0] {
            if self.clear(point.x, point.y, point.z, target.x + offset, target.y, target.z) {
                result += 0.5;
            }
        }
        return result;
    }
}

def cluster_at(bp: Blueprint, x: float, y: float) -> int {
    cx = int(x / 32.0);
    cy = int(y / 32.0);
    if cx < 0 or cy < 0 or cx >= bp.width or cy >= bp.height {
        return -1;
    }
    return bp.region[bp.index(cx, cy)];
}

def probe_regions(level: Level, bp: Blueprint, site: Site) -> Lighting {
    lighting = Lighting();
    count = len(bp.regions);
    low_x = [1000000 for _ in range(count)];
    low_y = [1000000 for _ in range(count)];
    high_x = [-1 for _ in range(count)];
    high_y = [-1 for _ in range(count)];
    low_z = [1000000 for _ in range(count)];
    high_z = [-1000000 for _ in range(count)];
    for y in range(bp.height) {
        for x in range(bp.width) {
            i = bp.index(x, y);
            if not bp.open(i) {
                continue;
            }
            r = bp.region[i];
            low_x[r] = min(low_x[r], x);
            low_y[r] = min(low_y[r], y);
            high_x[r] = max(high_x[r], x + 1);
            high_y[r] = max(high_y[r], y + 1);
            low_z[r] = min(low_z[r], bp.floor[i]);
            high_z[r] = max(high_z[r], bp.ceiling[i]);
        }
    }
    for r in range(count) {
        if high_x[r] < 0 {
            lighting.regions.append(ProbeRegion(origin=Vec3(), counts=[1, 1, 1]));
            continue;
        }
        width = float(high_x[r] - low_x[r]) * 32.0 - 32.0;
        depth = float(high_y[r] - low_y[r]) * 32.0 - 32.0;
        rise = float(high_z[r] - low_z[r]) - 48.0;
        nx = max(2, min(6, int(width / 160.0) + 2));
        ny = max(2, min(6, int(depth / 160.0) + 2));
        nz = max(2, min(4, int(rise / 96.0) + 2));
        lighting.regions.append(
            ProbeRegion(
                origin=Vec3(
                    x=float(low_x[r]) * 32.0 + 16.0,
                    y=float(low_y[r]) * 32.0 + 16.0,
                    z=float(low_z[r]) + 24.0
                ),
                spacing=Vec3(
                    x=max(1.0, width / float(nx - 1)),
                    y=max(1.0, depth / float(ny - 1)),
                    z=max(1.0, rise / float(nz - 1))
                ),
                counts=[nx, ny, nz]
            )
        );
    }
    # Floor-plan lookup: each macro cell uses the cluster owning most of it,
    # and wall-only cells borrow a neighbor so edge samples stay lit.
    columns = site.width;
    rows = site.height;
    lookup = [-1 for _ in range(columns * rows)];
    for my in range(rows) {
        for mx in range(columns) {
            counts: dict[int, int] = {};
            for dy in range(CELL) {
                for dx in range(CELL) {
                    x = mx * CELL + dx;
                    y = my * CELL + dy;
                    if x < bp.width and y < bp.height {
                        i = bp.index(x, y);
                        if bp.open(i) {
                            counts[bp.region[i]] = counts.get(bp.region[i], 0) + 1;
                        }
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
            lookup[my * columns + mx] = best;
        }
    }
    for sweep in range(4) {
        filled = list(lookup);
        for my in range(rows) {
            for mx in range(columns) {
                if lookup[my * columns + mx] >= 0 {
                    continue;
                }
                for delta in [[1, 0], [-1, 0], [0, 1], [0, -1]] {
                    nx = mx + delta[0];
                    ny = my + delta[1];
                    if 0 <= nx < columns and 0 <= ny < rows and lookup[ny * columns + nx] >= 0 {
                        filled[my * columns + mx] = lookup[ny * columns + nx];
                        break;
                    }
                }
            }
        }
        lookup = filled;
    }
    lighting.lookup = lookup;
    lighting.lookup_columns = columns;
    lighting.lookup_rows = rows;
    lighting.lookup_cell = float(CELL) * 32.0;
    return lighting;
}

def bake(level: Level, bp: Blueprint, site: Site, cache_directory: str = "") {
    lighting = probe_regions(level, bp, site);
    level.lighting = lighting;
    rig = Rig();
    for spec in bp.lamps {
        rgb = LAMP_RGB[spec.color % len(LAMP_RGB)];
        lamp = Lamp(
            origin=Vec3(x=spec.x, y=spec.y, z=spec.z),
            color=Vec3(x=rgb[0], y=rgb[1], z=rgb[2]),
            radius=spec.radius,
            strength=1.8 * spec.strength
        );
        lighting.rig +>:Emits:+> lamp;
    }
    lamps = (lighting.rig spawn GatherLamps()).lamps;
    rig.lamps = lamps;
    rig.clusters = [cluster_at(bp, lamp.origin.x, lamp.origin.y) for lamp in lamps];
    rig.rows = [visible_row(level, cluster) for cluster in range(level.bsp.clusters)];
    size = layout(level);
    path = "";
    if cache_directory {
        path = cache_directory + "/" + cache_key(level, lamps) + ".light";
        try {
            with open(path, "rb") as stream {
                data = stream.read();
            }
            if len(data) != 32 + size + probe_count(lighting) * 37
                or hashlib.sha256(data[32:]).digest() != data[:32] {
                raise ValueError("Invalid lighting cache");
            }
            unpack_probes(data[32 + size:], lighting);
            level.bsp.lighting = data[32:32 + size];
            lighting.cache_hit = True;
            print("LIGHTING cache hit", level.name);
            return;
        } except (OSError, ValueError) {}
    }
    # Doors are absent from static shadow rays; they are lit from probes as they move.
    occluder = ColumnOccluder(bp=bp);
    face_clusters: dict[int, list[int]] = {};
    for leaf in level.bsp.leaves {
        for index in leaf.faces {
            clusters = face_clusters.setdefault(index, []);
            if leaf.cluster not in clusters {
                clusters.append(leaf.cluster);
            }
        }
    }
    pixels = bytearray();
    print("LIGHTING baking", level.name, len(level.bsp.faces), "faces", len(lamps), "lamps");
    for index in range(len(level.bsp.faces)) {
        face = level.bsp.faces[index];
        if face.light_offset < 0 {
            continue;
        }
        start = face.vertices[0];
        u = face.vertices[1].sub(start);
        v = face.vertices[-1].sub(start);
        center = start.add(u.scale(0.5)).add(v.scale(0.5));
        extent = (u.length() + v.length()) * 0.5;
        nearby = rig.near(face_clusters.get(index, []), center, extent);
        for y in range(face.light_height) {
            for x in range(face.light_width) {
                # Inset boundary samples to avoid sampling inside the neighboring wall.
                s = max(
                    0.5 / u.length(),
                    min(1.0 - 0.5 / u.length(), float(x) / float(face.light_width - 1))
                );
                t = max(
                    0.5 / v.length(),
                    min(1.0 - 0.5 / v.length(), float(y) / float(face.light_height - 1))
                );
                point = start.add(u.scale(s)).add(v.scale(t)).add(
                    face.normal.scale(0.25)
                );
                sample = shade(point, face.normal, nearby, occluder);
                color = sample.ambient.add(sample.directed);
                for value in [color.x, color.y, color.z] {
                    pixels.append(int(max(0.0, min(127.0, value * 127.5))));
                }
            }
        }
        if index % 1000 == 0 {
            print("LIGHTING faces", index, "/", len(level.bsp.faces));
        }
    }
    level.bsp.lighting = bytes(pixels);
    for r in range(len(lighting.regions)) {
        region = lighting.regions[r];
        region.samples = [];
        region.valid = [];
        half = Vec3(
            x=region.spacing.x * float(region.counts[0] - 1) * 0.5,
            y=region.spacing.y * float(region.counts[1] - 1) * 0.5,
            z=region.spacing.z * float(region.counts[2] - 1) * 0.5
        );
        nearby = rig.near([r], region.origin.add(half), half.length());
        for z in range(region.counts[2]) {
            for y in range(region.counts[1]) {
                for x in range(region.counts[0]) {
                    point = region.origin.add(
                        Vec3(
                            x=float(x) * region.spacing.x,
                            y=float(y) * region.spacing.y,
                            z=float(z) * region.spacing.z
                        )
                    );
                    column = cluster_at(bp, point.x, point.y);
                    valid = column >= 0
                        and occluder.clear(point.x, point.y, point.z, point.x, point.y, point.z);
                    region.valid.append(valid);
                    region.samples.append(
                        shade(point, Vec3(), nearby, occluder, True)
                            if valid
                            else Illumination(ambient=Vec3())
                    );
                }
            }
        }
    }
    if path {
        try {
            os.makedirs(cache_directory, exist_ok=True);
            payload = level.bsp.lighting + pack_probes(lighting);
            temporary = path + "." + str(os.getpid()) + ".tmp";
            with open(temporary, "wb") as stream {
                stream.write(hashlib.sha256(payload).digest() + payload);
            }
            os.replace(temporary, path);
        } except OSError {
            print("LIGHTING cache unavailable; using completed bake");
        }
    }
    print("LIGHTING ready", len(pixels), "lightmap bytes,", probe_count(lighting), "probes");
}
