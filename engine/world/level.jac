"""BSP spatial graph and Quake 1 asset loading."""
import os;
import math;
import from ..assets.pak { open_pak, PakArchive }
import from ..formats.q1.bsp { parse_bsp }
import from ..formats.bsp { Bsp, Texture, decode_pvs, i32_at, require_range }
import from ..formats.q2.bsp { parse_q2, parse_wal, texture_names }
import from ..formats.q3.bsp { parse_q3 }
import from ..assets.pk3 { Pk3Assets }
import from ..physics.collision { CollisionMap }
import from ..formats.q1.collision { build_collision }
import from ..formats.brush_collision { build_brush_collision }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }
import from .doors { load_doors }
import from .triggers { load_triggers }
import from .traversal { load_traversal }
import from .liquids { LiquidSpace, SampleLiquid, Immersion, liquid_kind, load_liquids }
import from .world { World, Area, Player, move_to_area }

node Split {
    has normal: Vec3,
        distance: float;
}

node BspArea(Area) {
    has index: int = 0,
        faces: list[int] = [];
}

edge Front {}
edge Back {}
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
    has active: bool = False,
        collision: CollisionMap = CollisionMap(),
        name: str = "",
        bsp: Bsp = Bsp(),
        brush_faces: list[int] = [],
        palette: bytes = b"",
        areas: list[BspArea] = [],
        splits: list[Split] = [],
        liquids: LiquidSpace = LiquidSpace();

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

    def immersion(eye: Vec3) -> Immersion {
        result = Immersion();
        origin = eye.sub(Vec3(z=self.collision.eye_height));
        for height in [
            -23.0,
            (self.collision.eye_height - 24.0) * 0.5,
            self.collision.eye_height
        ] {
            kind = self.liquid_at(origin.add(Vec3(z=height)));
            if kind == 0 {
                break;
            }
            result.depth += 1;
            result.kind = max(result.kind, kind);
        }
        return result;
    }

    def visible(world: World, eye: Vec3, culling: bool) -> list[int] {
        leaf = self.locate(eye);
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
        return gather.faces;
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

def load_level(world: World, directory: str, map_name: str, game: str = "q1") -> Level {
    level = Level(active=True, name=map_name);
    if game == "q3" {
        assets = Pk3Assets();
        assets.open(directory);
        level.bsp = parse_q3(assets.read("maps/" + map_name + ".bsp"));
        for texture in level.bsp.textures {
            assets.texture(texture);
        }
        for face in level.bsp.faces {
            material = level.bsp.textures[face.texture];
            face.alpha_test = material.alpha_test;
            face.additive = material.additive;
            face.two_sided = material.two_sided;
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
    load_doors(world, level.bsp, level.collision);
    load_triggers(world, level.bsp);
    load_traversal(world, level.bsp);
    return level;
}

def spawn_player(level: Level) -> Player {
    for ent in level.bsp.entities {
        if ent.fields.get("classname", "")
            in ["info_player_start", "info_player_deathmatch"] {
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
    raise ValueError("Map has no info_player_start");
}
