"""BSP spatial graph and Quake 1 asset loading."""
import os;
import math;
import from ..assets.pak { open_pak, PakArchive }
import from ..formats.q1.bsp { parse_bsp }
import from ..formats.bsp { Bsp, Face, Texture, decode_pvs, i32_at, require_range, current_flow }
import from ..formats.q2.bsp { parse_q2, parse_wal, texture_names }
import from ..formats.q3.bsp { parse_q3 }
import from ..formats.animated { ModelStage, Deform }
import from ..assets.pk3 { Pk3Assets }
import from ..physics.collision { CollisionMap }
import from ..physics.movement { MovementProfile, movement_profile }
import from ..formats.q1.collision { build_collision }
import from ..formats.brush_collision { build_brush_collision }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }
import from .rotators { load_rotators }
import from .shooters { load_shooters }
import from .targets { load_targets }
import from .doors { load_doors, connect_targets, pose_doors, flood_doors }
import from .area_portals { load_area_portals }
import from .gates { load_gates }
import from .chthon { load_lightning, connect_electrodes }
import from .trains { load_trains }
import from .lightstyles { load_light_styles }
import from .particle_field { particle_field }
import from .particles { MarkSurfaces, HasMarkSurfaces }
import from .clocks { load_clocks }
import from .flyers { load_flyers }
import from .falling { load_falling_objects }
import from .turrets { load_turrets }
import from .portals { load_portals }
import from .finale { load_finale }
import from .hazards { load_hazards }
import from .speakers { load_speakers }
import from .brushes { load_brushes }
import from .spawns { active_entities }
import from .secret_doors { load_secret_doors }
import from .pickups { load_pickup_signals }
import from .combat { load_opponent_signals }
import from .triggers { load_triggers, load_monster_jumps }
import from .traversal { load_traversal }
import from .exits { load_exits }
import from .fixtures { load_fixture_uses }
import from .body_queue { load_no_drop }
import from .liquids {
    LiquidSpace, SampleLiquid, LiquidSample, Immersion, liquid_kind, load_liquids
}
import from .world { World, Area, Player, move_to_area }
import from .signals { Signal }
import from .lighting { Lighting, LightPointSource, LightSpot, load_light_grid }

node Split {
    has normal: Vec3,
        distance: float,
        first_face: int = 0,
        face_count: int = 0;
}

node BspArea(Area) {
    has index: int = 0,
        faces: list[int] = [];
}

edge Front: Split --> Split | BspArea {}
edge Back: Split --> Split | BspArea {}
walker Locate {
    has eye: Vec3,
        result: int = 0,
        remaining: int = 65536;

    can split with Split entry {
        self.remaining -= 1;
        if self.remaining <= 0 {
            raise ValueError("Cyclic BSP tree");
        }
        if here.normal.dot(self.eye) >= here.distance {
            visit [here->:Front:->];
        } else {
            visit [here->:Back:->];
        }
    }

    can leaf with BspArea entry {
        self.result = here.index;
    }
}

"""RecursiveLightPoint (WinQuake r_light.c, Q2 ref_gl gl_light.c) through
the BSP graph: follow the segment `start` to `end` down the tree. Where it
crosses a node's plane, the near side is searched first (a nested trace up
to the crossing), then the node's own faces at the crossing, then the far
side on from it. The first face whose lightmap extents hold the crossing
(skipping surfaces drawn without one) is `spot`, with its sample under the
point; leaves hold no faces to strike."""
walker TraceLightPoint {
    has start: Vec3,
        end: Vec3,
        faces: list[Face] = [],
        spot: LightSpot = LightSpot(),
        struck: bool = False,
        remaining: int = 4096;

    can split with Split entry {
        self.remaining -= 1;
        if self.remaining <= 0 {
            raise ValueError("Cyclic BSP tree");
        }
        front = here.normal.dot(self.start) - here.distance;
        back = here.normal.dot(self.end) - here.distance;
        behind = front < 0.0;
        near = [here->:Back:->] if behind else [here->:Front:->];
        if (back < 0.0) == behind {
            visit near;
            return;
        }
        mid = self.start.lerp(self.end, front / (front - back));
        probe = near[0] spawn TraceLightPoint(start=self.start, end=mid, faces=self.faces, remaining=self.remaining);
        if probe.struck {
            self.spot = probe.spot;
            self.struck = True;
            disengage;
        }
        for index in range(here.first_face, here.first_face + here.face_count) {
            face = self.faces[index];
            info = face.texinfo;
            if face.tiled or info is None {
                continue;
            }
            # C truncates the texture coordinates to integers.
            s = int(mid.dot(info.s) + info.soff);
            t = int(mid.dot(info.t) + info.toff);
            ds = s - face.light_s * 16;
            dt = t - face.light_t * 16;
            if ds < 0 or dt < 0 or ds > (face.light_width - 1) * 16 or dt > (face.light_height - 1) * 16 {
                continue;
            }
            self.spot = LightSpot(face=index, sample=(dt >> 4) * face.light_width + (ds >> 4));
            self.struck = True;
            disengage;
        }
        self.start = mid;
        visit ([here->:Front:->] if behind else [here->:Back:->]);
    }
}

"""R_LightPoint for a Q1 or Q2 level: the trace runs 2048 units straight
down from the point through the world model's BSP graph from `head`."""
obj BspLightPoint(LightPointSource) {
    has head: Split | None = None;

    def trace(point: Vec3) -> LightSpot {
        head = self.head;
        if head is None {
            return LightSpot();
        }
        probe = head spawn TraceLightPoint(start=point, end=point.sub(Vec3(z=2048.0)), faces=self.faces);
        return probe.spot;
    }
}

"""R_BoxSurfaces_r through the BSP graph: every leaf a box between `mins`
and `maxs` reaches, down each side of the planes it straddles; `faces` are
the faces those leaves list."""
walker BoxSurfaces {
    has mins: Vec3,
        maxs: Vec3,
        faces: list[int] = [],
        seen: set[int] = set();

    can split with Split entry {
        n = here.normal;
        # BoxOnPlaneSide: the box's nearest and farthest corners.
        far = (n.x * (self.maxs.x if n.x >= 0.0 else self.mins.x))
            + (n.y * (self.maxs.y if n.y >= 0.0 else self.mins.y))
            + (n.z * (self.maxs.z if n.z >= 0.0 else self.mins.z));
        near = (n.x * (self.mins.x if n.x >= 0.0 else self.maxs.x))
            + (n.y * (self.mins.y if n.y >= 0.0 else self.maxs.y))
            + (n.z * (self.mins.z if n.z >= 0.0 else self.maxs.z));
        if far >= here.distance {
            visit [here->:Front:->];
        }
        if near < here.distance {
            visit [here->:Back:->];
        }
    }

    can leaf with BspArea entry {
        for face in here.faces {
            if face not in self.seen {
                self.seen.add(face);
                self.faces.append(face);
            }
        }
    }
}

"""Q3 R_MarkFragments over a level's world faces: the polygon's edge planes
along the projection, and planes 32 units beyond and 20 before it, cut each
face that faces the projection (planar faces within 60 degrees of it,
patch triangles steeper than 0.1 or 0.05), leaving out SURF_NOIMPACT,
SURF_NOMARKS and fog surfaces and triangle soups."""
node BspMarkSurfaces(MarkSurfaces) {
    has head: Split | None = None,
        faces: list[Face] = [],
        textures: list[Texture] = [];

    def fragments(points: list[Vec3], projection: Vec3) -> list[list[Vec3]] {
        head = self.head;
        if head is None or len(points) < 3 {
            return [];
        }
        direction = projection.normalized();
        low = points[0].add(Vec3());
        high = points[0].add(Vec3());
        for point in points {
            for corner in [point, point.add(projection), point.sub(direction.scale(20.0))] {
                low = Vec3(x=min(low.x, corner.x), y=min(low.y, corner.y), z=min(low.z, corner.z));
                high = Vec3(x=max(high.x, corner.x), y=max(high.y, corner.y), z=max(high.z, corner.z));
            }
        }
        normals: list[Vec3] = [];
        dists: list[float] = [];
        for i in range(len(points)) {
            side = points[(i + 1) % len(points)].sub(points[i]);
            normal = side.cross(projection.scale(-1.0)).normalized();
            normals.append(normal);
            dists.append(normal.dot(points[i]));
        }
        normals.append(direction);
        dists.append(direction.dot(points[0]) - 32.0);
        normals.append(direction.scale(-1.0));
        dists.append(direction.scale(-1.0).dot(points[0]) - 20.0);
        found = head spawn BoxSurfaces(mins=low, maxs=high);
        result: list[list[Vec3]] = [];
        for index in found.faces {
            face = self.faces[index];
            material = self.textures[face.texture] if face.texture < len(self.textures) else Texture();
            # SURF_NOIMPACT (0x10), SURF_NOMARKS (0x20), CONTENTS_FOG (64).
            if material.flags & 48 != 0 or material.contents & 64 != 0 {
                continue;
            }
            if face.planar {
                if face.normal.dot(direction) > -0.5 or not mark_plane_crosses(face.normal, face.plane_dist, low, high) {
                    continue;
                }
            } elif not face.patch {
                continue;
            }
            for t in range(len(face.indices) // 3) {
                triangle = [face.vertices[face.indices[t * 3 + k]] for k in range(3)];
                if face.patch {
                    normal = triangle[0].sub(triangle[1]).cross(triangle[2].sub(triangle[1])).normalized();
                    if normal.dot(direction) >= -0.1 and normal.scale(-1.0).dot(direction) >= -0.1 {
                        continue;
                    }
                }
                piece = triangle;
                for p in range(len(normals)) {
                    piece = chop_behind_plane(piece, normals[p], dists[p], 0.5);
                    if not piece {
                        break;
                    }
                }
                if len(piece) >= 3 {
                    result.append(piece);
                }
            }
        }
        return result;
    }
}

"""Whether a plane passes through the box (BoxOnPlaneSide answers 3)."""
def mark_plane_crosses(normal: Vec3, distance: float, mins: Vec3, maxs: Vec3) -> bool {
    far = (normal.x * (maxs.x if normal.x >= 0.0 else mins.x))
        + (normal.y * (maxs.y if normal.y >= 0.0 else mins.y))
        + (normal.z * (maxs.z if normal.z >= 0.0 else mins.z));
    near = (normal.x * (mins.x if normal.x >= 0.0 else maxs.x))
        + (normal.y * (mins.y if normal.y >= 0.0 else maxs.y))
        + (normal.z * (mins.z if normal.z >= 0.0 else maxs.z));
    return far >= distance and near < distance;
}

"""R_ChopPolyBehindPlane: the part of `points` in front of the plane, points
within `epsilon` of it counting as on it; nothing when all are behind."""
def chop_behind_plane(points: list[Vec3], normal: Vec3, distance: float, epsilon: float) -> list[Vec3] {
    count = len(points);
    dists: list[float] = [];
    sides: list[int] = [];
    fronts = 0;
    backs = 0;
    for point in points {
        d = point.dot(normal) - distance;
        dists.append(d);
        side = 0 if d > epsilon else (1 if d < -epsilon else 2);
        sides.append(side);
        if side == 0 {
            fronts += 1;
        } elif side == 1 {
            backs += 1;
        }
    }
    if fronts == 0 {
        return [];
    }
    if backs == 0 {
        return points;
    }
    out: list[Vec3] = [];
    for i in range(count) {
        point = points[i];
        if sides[i] == 2 {
            out.append(point);
            continue;
        }
        if sides[i] == 0 {
            out.append(point);
        }
        following = sides[(i + 1) % count];
        if following == 2 or following == sides[i] {
            continue;
        }
        span = dists[i] - dists[(i + 1) % count];
        share = 0.0 if span == 0.0 else dists[i] / span;
        out.append(point.lerp(points[(i + 1) % count], share));
    }
    return out;
}

walker CollectFaces {
    has targets: list[BspArea] = [],
        faces: list[int] = [],
        seen: set[int] = set();

    can start with World entry {
        visit self.targets;
    }

    can collect with BspArea entry {
        for face in here.faces {
            if face not in self.seen {
                self.seen.add(face);
                self.faces.append(face);
            }
        }
    }
}

"""Quake's server clock when a level's first player frame runs: sv.time
starts at 1 and SV_SpawnServer runs two 0.1 s settling frames. The status
bar's scoreboard and the intermission plaque read that clock (cl.time,
cl.completed_time)."""
glob Q1_SERVER_START: float = 1.2;

obj Level {
    has lighting: Lighting = Lighting();
    # Seconds the level has run (Q1 sv.time less its start, Q2 level.time),
    # kept in its saves.
    has clock: float = 0.0;
    has asset_manifest: str = "",
        briefing: str = "",
        completion: Signal = Signal();

    has active: bool = False,
        skill: int = 1,
        collision: CollisionMap = CollisionMap(),
        movement: MovementProfile = MovementProfile(),
        name: str = "",
        bsp: Bsp = Bsp(),
        brush_faces: list[int] = [],
        palette: bytes = b"",
        areas: list[BspArea] = [],
        splits: list[Split] = [],
        liquids: LiquidSpace = LiquidSpace(),
        visible_leaf: int = -2,
        visible_game: str = "",
        visible_culling: bool = False,
        visible_faces: list[int] = [],
        visible_recent: dict[int, list[int]] = {},
        surface_stages: dict[int, list[ModelStage]] = {},
        surface_deforms: dict[int, list[Deform]] = {},
        sky_clouds: list[ModelStage] = [],
        cloud_height: float = 128.0,
        sky_rotate: float = 0.0,
        sky_axis: Vec3 = Vec3(),
        portal_ranges: dict[int, float] = {};

    def locate(eye: Vec3) -> int {
        head = self.bsp.models[0].head;
        if head < 0 {
            return -head - 1;
        }
        query = self.splits[head] spawn Locate(eye=eye);
        return query.result;
    }

    def liquid_at(point: Vec3) -> int {
        return self.sample_liquid(point).kind;
    }

    """The liquid at a point and its Q2 current bits (CM_PointContents)."""
    def sample_liquid(point: Vec3) -> LiquidSample {
        if not self.active {
            return LiquidSample();
        }
        if self.bsp.game == "q1" {
            return LiquidSample(
                kind=liquid_kind(self.bsp.leaves[self.locate(point)].contents, "q1")
            );
        }
        sample = self.liquids spawn SampleLiquid(point=point);
        return LiquidSample(kind=sample.result, currents=sample.currents);
    }

    """Sample the feet, the waist and the eye (the player's own view height
    unless another body's is given). Q2 PM_CatagorizePosition and Q3
    PM_SetWaterLevel take the waist at half the view height; Q1
    SV_CheckWater at the middle of the box, 4 units up the player's -24..32.
    The current is the feet's (pm->watertype)."""
    def immersion(eye: Vec3, eye_height: float = -1.0) -> Immersion {
        result = Immersion();
        player = eye_height < 0.0;
        if player {
            eye_height = self.collision.eye_height;
        }
        origin = eye.sub(Vec3(z=eye_height));
        waist = 4.0
            if player and self.bsp.game == "q1"
            else (eye_height - 24.0) * 0.5;
        for height in [-23.0, waist, eye_height] {
            sample = self.sample_liquid(origin.add(Vec3(z=height)));
            if sample.kind == 0 {
                break;
            }
            if result.depth == 0 {
                direction = current_flow(sample.currents);
                if direction is not None {
                    result.current = direction;
                }
            }
            result.depth += 1;
            result.kind = max(result.kind, sample.kind);
        }
        return result;
    }

    """Q2 PHS: the clusters that can hear a sound made at `eye`, from the
    potentially hearable set compiled into the map (PlayerNoise / gi.inPHS).
    Other games return no clusters."""
    def hearable(eye: Vec3) -> set[int] {
        clusters: set[int] = set();
        if self.bsp.game != "q2" or self.bsp.clusters <= 0 {
            return clusters;
        }
        cluster = self.bsp.leaves[self.locate(eye)].cluster;
        if cluster < 0 {
            return clusters;
        }
        check = i32_at(self.bsp.visibility, 8 + cluster * 8);
        for bit in decode_pvs(self.bsp.visibility, check, self.bsp.clusters + 1) {
            clusters.add(bit - 1);
        }
        clusters.add(cluster);
        return clusters;
    }

    def visible(world: World, eye: Vec3, culling: bool) -> list[int] {
        leaf = self.locate(eye);
        # Map topology/PVS are immutable for a loaded Level. Movers update face
        # transforms, not membership; their faces are always included below.
        if leaf == self.visible_leaf
            and culling == self.visible_culling
            and self.visible_game == self.bsp.game {
            return self.visible_faces;
        }
        # A few recent sets are kept, so a portal view and the main view
        # alternating each frame keep their lists (and the renderer the index
        # lists it built for them).
        key = leaf * 2 + (1 if culling else 0);
        if self.visible_game == self.bsp.game and key in self.visible_recent {
            self.visible_leaf = leaf;
            self.visible_culling = culling;
            self.visible_faces = self.visible_recent[key];
            return self.visible_faces;
        }
        targets: list[BspArea] = [];
        if self.bsp.game != "q1" {
            cluster = self.bsp.leaves[leaf].cluster;
            clusters: set[int] = set();
            if culling and cluster >= 0 and self.bsp.clusters > 0 {
                if self.bsp.game == "q2" {
                    check = i32_at(self.bsp.visibility, 4 + cluster * 8);
                    for bit in decode_pvs(
                        self.bsp.visibility, check, self.bsp.clusters + 1
                    ) {
                        clusters.add(bit - 1);
                    }
                } else {
                    offset = 8 + cluster * self.bsp.cluster_bytes;
                    require_range(self.bsp.visibility, offset, self.bsp.cluster_bytes);
                    for bit in range(self.bsp.clusters) {
                        if int(self.bsp.visibility[offset + bit // 8])
                            & (1 << (bit % 8))
                            != 0 {
                            clusters.add(bit);
                        }
                    }
                }
                clusters.add(cluster);
            }
            for i in range(len(self.areas)) {
                if not culling
                    or cluster < 0
                    or self.bsp.clusters == 0
                    or self.bsp.leaves[i].cluster in clusters {
                    targets.append(self.areas[i]);
                }
            }
        } elif culling and leaf > 0 {
            indices = decode_pvs(
                self.bsp.visibility,
                self.bsp.leaves[leaf].vis_offset,
                self.bsp.models[0].vis_leaf_count + 1
            );
            for i in indices {
                targets.append(self.areas[i]);
            }
        } else {
            targets = self.areas[1:self.bsp.models[0].vis_leaf_count + 1];
        }
        gather = world spawn CollectFaces(targets=targets);
        for f in self.brush_faces {
            if f not in gather.seen {
                gather.faces.append(f);
                gather.seen.add(f);
            }
        }
        if self.visible_game != self.bsp.game or len(self.visible_recent) >= 4 {
            self.visible_recent = {};
        }
        self.visible_leaf = leaf;
        self.visible_culling = culling;
        self.visible_game = self.bsp.game;
        self.visible_faces = gather.faces;
        self.visible_recent[key] = gather.faces;
        return self.visible_faces;
    }
}

def asset(paks: list[PakArchive], name: str) -> bytes {
    for pak in reversed(paks) {
        if pak.has_file(name) {
            return pak.read_file(name);
        }
    }
    raise ValueError("Missing Quake asset: " + name);
}

def load_level(
    world: World, directory: str, map_name: str, game: str = "q1", skill: int = 1
) -> Level {
    level = Level(active=True, name=map_name, skill=skill);
    if game == "q3" {
        assets = Pk3Assets();
        assets.open(directory);
        level.bsp = parse_q3(assets.read("maps/" + map_name + ".bsp"));
        # Models are lit from the light grid (worldspawn "gridsize").
        spacing = Vec3(x=64.0, y=64.0, z=128.0);
        for entity in level.bsp.entities[:1] {
            parts = entity.fields.get("gridsize", "").split();
            if len(parts) == 3 {
                spacing = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
            }
        }
        world_model = level.bsp.models[0];
        level.lighting.grid = load_light_grid(level.bsp.light_grid, world_model.mins, world_model.maxs, spacing);
        for texture in level.bsp.textures {
            assets.texture(texture);
        }
        # The sky: its far box and cloud layers, from the first sky surface.
        for texture in level.bsp.textures {
            if texture.flags & 4 != 0 {
                sky = assets.sky_parts(texture.name);
                level.bsp.sky = sky.farbox;
                level.sky_clouds = sky.clouds;
                level.cloud_height = sky.cloud_height;
                break;
            }
        }
        # Shaders with animated, moving or layered stages draw stage by stage.
        for index in range(len(level.bsp.textures)) {
            stages = assets.surface_stages(level.bsp.textures[index].name);
            if stages {
                level.surface_stages[index] = stages;
                deforms = assets.surface_deforms(level.bsp.textures[index].name);
                if deforms {
                    level.surface_deforms[index] = deforms;
                }
            }
        }
        # Fog volumes take their colour and thickness from their shader; fog
        # shaders' own surfaces draw nothing but the fog pass.
        for fog in level.bsp.fogs {
            parms = assets.fog_parms(fog.shader);
            if parms {
                fog.color = Vec3(x=parms[0], y=parms[1], z=parms[2]);
                fog.depth = parms[3];
            }
        }
        for index in range(len(level.bsp.textures)) {
            reach = assets.portal_range(level.bsp.textures[index].name);
            if reach >= 0.0 {
                level.portal_ranges[index] = reach;
            }
        }
        fog_shaders: list[int] = [];
        for index in range(len(level.bsp.textures)) {
            if assets.fog_parms(level.bsp.textures[index].name) {
                fog_shaders.append(index);
            }
        }
        for face in level.bsp.faces {
            material = level.bsp.textures[face.texture];
            face.alpha_test = material.alpha_test;
            face.additive = material.additive;
            face.two_sided = material.two_sided;
            face.fog_only = face.texture in fog_shaders;
        }
        assets.close();
        # Palette used only for the diagnostic checkerboard on missing images.
        colors = bytearray();
        for i in range(256) {
            colors.extend([u8(i), u8(0), u8(i)]);
        }
        level.palette = bytes(colors);
    } elif game == "q1" or game == "q2" {
        paks: list[PakArchive] = [];
        for filename in sorted(os.listdir(directory)) {
            if filename.lower().endswith(".pak") {
                paks.append(open_pak(directory + "/" + filename));
            }
        }
        data = asset(paks, "maps/" + map_name + ".bsp");
        if game == "q2" {
            textures: list[Texture] = [];
            for name in texture_names(data) {
                textures.append(
                    parse_wal(asset(paks, "textures/" + name + ".wal"), name)
                );
            }
            level.bsp = parse_q2(data, textures);
            sky_name = "unit1_";
            for entity in level.bsp.entities {
                if entity.fields.get("classname", "") == "worldspawn" {
                    sky_name = entity.fields.get("sky", "unit1_");
                    # SP_worldspawn CS_SKYROTATE and CS_SKYAXIS: the sky box
                    # turns `skyrotate` degrees a second about `skyaxis`.
                    level.sky_rotate = float(entity.fields.get("skyrotate", "0") or "0");
                    axis = entity.fields.get("skyaxis", "").split();
                    if len(axis) == 3 {
                        level.sky_axis = Vec3(x=float(axis[0]), y=float(axis[1]), z=float(axis[2]));
                    }
                }
            }
            for suffix in ["rt", "lf", "bk", "ft", "up", "dn"] {
                name = "env/" + sky_name + suffix + ".tga";
                level.bsp.sky.append(
                    Texture(name=name, encoded=asset(paks, name), extension=".tga")
                );
            }
            pcx = asset(paks, "pics/colormap.pcx");
            if len(pcx) < 769 or pcx[len(pcx) - 769] != 12 {
                raise ValueError("Missing PCX palette");
            }
            level.palette = pcx[len(pcx) - 768:];
        } else {
            level.bsp = parse_bsp(data);
            level.palette = asset(paks, "gfx/palette.lmp");
        }
        if len(level.palette) != 768 {
            raise ValueError("Palette must contain 256 RGB colors");
        }
    } else {
        raise ValueError("QP_GAME must be q1, q2, or q3");
    }
    prepare_level(world, level);
    return level;
}

def prepare_level(world: World, level: Level) {
    game = level.bsp.game;
    level.movement = movement_profile(game);
    level.bsp.entities = active_entities(game, level.bsp.entities, level.skill);
    for i in range(len(level.bsp.leaves)) {
        leaf = level.bsp.leaves[i];
        area = BspArea(
            name="leaf " + str(i),
            bounds=AABB(mins=leaf.mins, maxs=leaf.maxs),
            index=i,
            faces=leaf.faces
        );
        if i <= level.bsp.models[0].vis_leaf_count {
            world ++> area;
        }
        level.areas.append(area);
    }
    for branch in level.bsp.branches {
        plane = level.bsp.planes[branch.plane];
        level.splits.append(
            Split(normal=plane.normal, distance=plane.distance, first_face=branch.first_face, face_count=branch.face_count)
        );
    }
    for i in range(len(level.bsp.branches)) {
        branch = level.bsp.branches[i];
        if branch.front >= 0 {
            level.splits[i] +>:Front:+> level.splits[branch.front];
        } else {
            level.splits[i] +>:Front:+> level.areas[-branch.front - 1];
        }
        if branch.back >= 0 {
            level.splits[i] +>:Back:+> level.splits[branch.back];
        } else {
            level.splits[i] +>:Back:+> level.areas[-branch.back - 1];
        }
    }
    if game == "q1" {
        level.collision = build_collision(level.bsp);
    } else {
        level.collision = build_brush_collision(level.bsp);
    }
    # Trigger volumes have BSP models but are not visible geometry.
    for ent in level.bsp.entities {
        model_name = ent.fields.get("model", "");
        if not model_name.startswith("*")
            or ent.fields.get("classname", "").startswith("trigger_") {
            continue;
        }
        model_index = int(model_name[1:]);
        if model_index <= 0 or model_index >= len(level.bsp.models) {
            raise ValueError("Invalid brush entity model");
        }
        coords = ent.fields.get("origin", "0 0 0").split();
        if len(coords) != 3 {
            raise ValueError("Invalid brush entity origin");
        }
        offset = Vec3(x=float(coords[0]), y=float(coords[1]), z=float(coords[2]));
        model = level.bsp.models[model_index];
        for f in range(model.first_face, model.first_face + model.face_count) {
            face = level.bsp.faces[f];
            translated: list[Vec3] = [];
            for v in face.vertices {
                translated.append(v.add(offset));
            }
            face.vertices = translated;
            face.plane_dist += face.normal.dot(offset);
            level.brush_faces.append(f);
        }
    }
    level.liquids = load_liquids(level.bsp);
    load_no_drop(world, level.bsp);
    load_gates(world, level.bsp, level.collision);
    load_pickup_signals(world, level.bsp);
    load_opponent_signals(world, level.bsp);
    load_exits(world, level.bsp);
    load_trains(world, level.bsp, level.collision);
    # The particles and puffs the level's effects spawn, in this game's kinds.
    particle_field(world, game);
    # Q3 marks are cut to the world's faces (R_MarkFragments).
    if game == "q3" {
        head = level.bsp.models[0].head if level.bsp.models else -1;
        world +>:HasMarkSurfaces:+> BspMarkSurfaces(
            head=level.splits[head] if 0 <= head < len(level.splits) else None,
            faces=level.bsp.faces,
            textures=level.bsp.textures
        );
    }
    styles = load_light_styles(world, level.bsp);
    if game in ["q1", "q2"] {
        # Models take the light of the lightmaps below them (R_LightPoint),
        # under the same animated styles as the world.
        head = level.bsp.models[0].head if level.bsp.models else -1;
        level.lighting.game = game;
        level.lighting.point = BspLightPoint(
            faces=level.bsp.faces,
            lightmaps=level.bsp.lighting,
            channels=level.bsp.light_channels,
            head=level.splits[head] if 0 <= head < len(level.splits) else None
        );
        if styles is not None {
            level.lighting.styles = styles.values;
            level.lighting.style_source = styles;
        }
    }
    load_clocks(world, level.bsp);
    load_flyers(world, level.bsp);
    load_falling_objects(world, level.bsp, level.collision);
    load_finale(world, level.bsp);
    load_hazards(world, level.bsp);
    load_speakers(world, level.bsp);
    load_secret_doors(world, level.bsp, level.collision);
    load_brushes(world, level.bsp, level.collision);
    load_lightning(world, level.bsp);
    load_doors(world, level.bsp, level.collision, connect=False);
    flood_doors(world, level.liquids);
    load_rotators(world, level.bsp, level.collision);
    load_turrets(world, level.bsp, level.collision);
    load_portals(world, level.bsp);
    load_shooters(world, level.bsp);
    load_targets(world, level.bsp);
    load_traversal(world, level.bsp);
    load_fixture_uses(world, level.bsp);
    load_area_portals(world, level.bsp);
    # Resolve every activation chain once all activatable entities exist.
    connect_targets(world, level.bsp);
    pose_doors(world, level.bsp, level.collision);
    connect_electrodes(world, level.bsp);
    load_triggers(world, level.bsp, level.collision);
    load_monster_jumps(world, level.bsp);
}

"""Q1 SV_CheckStuck: a start embedded in the floor or a wall by a unit or
two (Q1 e2m7's is) is moved up to 17 units up and one unit sideways to the
first free spot, as the original does for a stuck player."""
def unstick(collision: CollisionMap, origin: Vec3) -> Vec3 {
    if not collision.trace(origin, origin).start_solid {
        return origin;
    }
    for rise in range(18) {
        for dx in [0.0, -1.0, 1.0] {
            for dy in [0.0, -1.0, 1.0] {
                spot = origin.add(Vec3(x=dx, y=dy, z=float(rise)));
                if not collision.trace(spot, spot).start_solid {
                    return spot;
                }
            }
        }
    }
    return origin;
}

def spawn_player(level: Level, spawnpoint: str = "", returning: bool = False) -> Player {
    # Q1 SelectSpawnPoint: with any rune held, the start map uses its second start.
    kind = "info_player_start";
    if returning
        and level.bsp.game == "q1"
        and any([entity.fields.get("classname", "") == "info_player_start2" for entity in level.bsp.entities]) {
        kind = "info_player_start2";
    }
    starts = [
        entity
        for entity in level.bsp.entities
        if entity.fields.get("classname", "") == kind
    ];
    if not starts {
        starts = [
            entity
            for entity in level.bsp.entities
            if entity.fields.get("classname", "") == "info_player_deathmatch"
        ];
    }
    unnamed = [
        entity
        for entity in starts
        if not entity.fields.get("targetname", "")
    ];
    if not spawnpoint and unnamed {
        starts = unnamed;
    }
    for ent in starts {
        if spawnpoint and ent.fields.get("targetname", "") != spawnpoint {
            continue;
        }
        if ent.fields.get("classname", "")
            in ["info_player_start", "info_player_start2", "info_player_deathmatch"] {
            coords = ent.fields.get("origin", "0 0 0").split();
            if len(coords) != 3 {
                raise ValueError("Invalid player spawn origin");
            }
            origin = unstick(
                level.collision,
                Vec3(x=float(coords[0]), y=float(coords[1]), z=float(coords[2]))
            );
            player = Player(
                pos=origin.add(Vec3(z=level.collision.eye_height)),
                yaw=float(ent.fields.get("angle", "0")) * math.pi / 180.0
            );
            move_to_area(player, level.areas[level.locate(player.pos)]);
            return player;
        }
    }
    raise ValueError("Map has no matching player spawn: " + spawnpoint);
}
