"""BSP spatial graph and Quake 1 asset loading."""
import os;
import math;
import from ..assets.pak { open_pak, PakArchive }
import from ..formats.q1.bsp { Bsp, parse_bsp, decode_pvs }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }
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
        name: str = "",
        bsp: Bsp = Bsp(),
        brush_faces: list[int] = [],
        palette: bytes = b"",
        areas: list[BspArea] = [],
        splits: list[Split] = [];

    def locate(eye: Vec3) -> int {
        head = self.bsp.models[0].head;
        if head < 0 {
            return -head - 1;
        }
        query = self.splits[head] spawn Locate(eye=eye);
        return query.result;
    }

    def visible(world: World, eye: Vec3, culling: bool) -> list[int] {
        leaf = self.locate(eye);
        targets: list[BspArea] = [];
        if culling and leaf > 0 {
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

def load_level(world: World, directory: str, map_name: str) -> Level {
    paks: list[PakArchive] = [];
    for filename in sorted(os.listdir(directory)) {
        if filename.lower().endswith(".pak") {
            paks.append(open_pak(directory + "/" + filename));
        }
    }
    level = Level(
        active=True,
        name=map_name,
        bsp=parse_bsp(asset(paks, "maps/" + map_name + ".bsp")),
        palette=asset(paks, "gfx/palette.lmp")
    );
    if len(level.palette) != 768 {
        raise ValueError("Quake palette must contain 256 RGB colors");
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
    return level;
}

def spawn_player(level: Level) -> Player {
    for ent in level.bsp.entities {
        if ent.fields.get("classname", "") == "info_player_start" {
            coords = ent.fields.get("origin", "0 0 0").split();
            if len(coords) != 3 {
                raise ValueError("Invalid player spawn origin");
            }
            player = Player(
                pos=Vec3(
                    x=float(coords[0]), y=float(coords[1]), z=float(coords[2]) + 22.0
                ),
                yaw=float(ent.fields.get("angle", "0")) * math.pi / 180.0
            );
            move_to_area(player, level.areas[level.locate(player.pos)]);
            return player;
        }
    }
    raise ValueError("Map has no info_player_start");
}
