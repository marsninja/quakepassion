"""BSP spatial graph and Quake 1 asset loading."""
import os;
import math;
import from ..assets.pak { open_pak, PakArchive }
import from ..formats.q1.bsp { parse_bsp }
import from ..formats.bsp { Bsp, Texture, decode_pvs, i32_at, require_range }
import from ..formats.q2.bsp { parse_q2, parse_wal, texture_names }
import from ..formats.q3.bsp { parse_q3 }
import from ..formats.animated { ModelStage, Deform }
import from ..assets.pk3 { Pk3Assets }
import from ..physics.collision { CollisionMap }
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
import from .liquids { LiquidSpace, SampleLiquid, Immersion, liquid_kind, load_liquids }
import from .world { World, Area, Player, move_to_area }
import from .signals { Signal }
import from .lighting { Lighting }

node Split {
    has normal: Vec3,
        distance: float;
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

obj Level {
    has lighting: Lighting = Lighting();
    has asset_manifest: str = "",
        briefing: str = "",
        completion: Signal = Signal();

    has active: bool = False,
        skill: int = 1,
        collision: CollisionMap = CollisionMap(),
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
        surface_stages: dict[int, list[ModelStage]] = {},
        surface_deforms: dict[int, list[Deform]] = {},
        sky_clouds: list[ModelStage] = [],
        cloud_height: float = 128.0,
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
        if not self.active {
            return 0;
        }
        if self.bsp.game == "q1" {
            return liquid_kind(self.bsp.leaves[self.locate(point)].contents, "q1");
        }
        sample = self.liquids spawn SampleLiquid(point=point);
        return sample.result;
    }

    def immersion(eye: Vec3, eye_height: float = -1.0) -> Immersion {
        result = Immersion();
        if eye_height < 0.0 {
            eye_height = self.collision.eye_height;
        }
        origin = eye.sub(Vec3(z=eye_height));
        for height in [-23.0, (eye_height - 24.0) * 0.5, eye_height] {
            kind = self.liquid_at(origin.add(Vec3(z=height)));
            if kind == 0 {
                break;
            }
            result.depth += 1;
            result.kind = max(result.kind, kind);
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
        self.visible_leaf = leaf;
        self.visible_culling = culling;
        self.visible_game = self.bsp.game;
        self.visible_faces = gather.faces;
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
        level.splits.append(Split(normal=plane.normal, distance=plane.distance));
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
    load_gates(world, level.bsp, level.collision);
    load_pickup_signals(world, level.bsp);
    load_opponent_signals(world, level.bsp);
    load_exits(world, level.bsp);
    load_trains(world, level.bsp, level.collision);
    load_light_styles(world, level.bsp);
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
            player = Player(
                pos=Vec3(
                    x=float(coords[0]),
                    y=float(coords[1]),
                    z=float(coords[2]) + level.collision.eye_height
                ),
                yaw=float(ent.fields.get("angle", "0")) * math.pi / 180.0
            );
            move_to_area(player, level.areas[level.locate(player.pos)]);
            return player;
        }
    }
    raise ValueError("Map has no matching player spawn: " + spawnpoint);
}
