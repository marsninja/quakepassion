"""Quake 3 Area Awareness System files (maps/*.aas): the areas, reachabilities
and point-location tree the original bots navigate with (botlib be_aas_file.c,
version 5 with its XOR-scrambled header)."""
import struct;
import from .bsp { i32_at, u16_at, f32_at, vec_at, require_range }
import from ..math.vec3 { Vec3 }

# botlib aasfile.h travel types.
glob TRAVEL_INVALID: int = 1,
    TRAVEL_WALK: int = 2,
    TRAVEL_CROUCH: int = 3,
    TRAVEL_BARRIERJUMP: int = 4,
    TRAVEL_JUMP: int = 5,
    TRAVEL_LADDER: int = 6,
    TRAVEL_WALKOFFLEDGE: int = 7,
    TRAVEL_SWIM: int = 8,
    TRAVEL_WATERJUMP: int = 9,
    TRAVEL_TELEPORT: int = 10,
    TRAVEL_ELEVATOR: int = 11,
    TRAVEL_ROCKETJUMP: int = 12,
    TRAVEL_BFGJUMP: int = 13,
    TRAVEL_GRAPPLEHOOK: int = 14,
    TRAVEL_DOUBLEJUMP: int = 15,
    TRAVEL_RAMPJUMP: int = 16,
    TRAVEL_STRAFEJUMP: int = 17,
    TRAVEL_JUMPPAD: int = 18,
    TRAVEL_FUNCBOB: int = 19;

# be_aas.h travel flags: which travel types and area contents a route may use.
glob TFL_INVALID: int = 1,
    TFL_WALK: int = 2,
    TFL_CROUCH: int = 4,
    TFL_BARRIERJUMP: int = 8,
    TFL_JUMP: int = 16,
    TFL_LADDER: int = 32,
    TFL_WALKOFFLEDGE: int = 128,
    TFL_SWIM: int = 256,
    TFL_WATERJUMP: int = 512,
    TFL_TELEPORT: int = 1024,
    TFL_ELEVATOR: int = 2048,
    TFL_ROCKETJUMP: int = 4096,
    TFL_BFGJUMP: int = 8192,
    TFL_GRAPPLEHOOK: int = 16384,
    TFL_DOUBLEJUMP: int = 32768,
    TFL_RAMPJUMP: int = 65536,
    TFL_STRAFEJUMP: int = 131072,
    TFL_JUMPPAD: int = 262144,
    TFL_AIR: int = 524288,
    TFL_WATER: int = 1048576,
    TFL_SLIME: int = 2097152,
    TFL_LAVA: int = 4194304,
    TFL_DONOTENTER: int = 8388608,
    TFL_FUNCBOB: int = 16777216;

# be_aas.h TFL_DEFAULT: everything but rocket, BFG and weapon-assisted jumps,
# the grapple, lava, slime and do-not-enter areas.
glob TFL_DEFAULT: int = TFL_WALK
    | TFL_CROUCH
    | TFL_BARRIERJUMP
    | TFL_JUMP
    | TFL_LADDER
    | TFL_WALKOFFLEDGE
    | TFL_SWIM
    | TFL_WATERJUMP
    | TFL_TELEPORT
    | TFL_ELEVATOR
    | TFL_AIR
    | TFL_WATER
    | TFL_JUMPPAD
    | TFL_FUNCBOB;

# aasfile.h area contents.
glob AREACONTENTS_WATER: int = 1,
    AREACONTENTS_LAVA: int = 2,
    AREACONTENTS_SLIME: int = 4,
    AREACONTENTS_DONOTENTER: int = 256,
    AREACONTENTS_MOVER: int = 1024,
    AREACONTENTS_MODELNUMSHIFT: int = 24,
    AREACONTENTS_MAXMODELNUM: int = 255;

# aasfile.h presence types: which of the player's boxes fits in an area.
glob PRESENCE_NORMAL: int = 2,
    PRESENCE_CROUCH: int = 4;

# aasfile.h area flags.
glob AREA_GROUNDED: int = 1,
    AREA_LADDER: int = 2,
    AREA_LIQUID: int = 4,
    AREA_DISABLED: int = 8;

"""be_aas_route.c AAS_TravelFlagForType: the travel flag a travel type needs."""
def travel_flag_for_type(kind: int) -> int {
    flags: dict[int, int] = {
        TRAVEL_INVALID: TFL_INVALID,
        TRAVEL_WALK: TFL_WALK,
        TRAVEL_CROUCH: TFL_CROUCH,
        TRAVEL_BARRIERJUMP: TFL_BARRIERJUMP,
        TRAVEL_JUMP: TFL_JUMP,
        TRAVEL_LADDER: TFL_LADDER,
        TRAVEL_WALKOFFLEDGE: TFL_WALKOFFLEDGE,
        TRAVEL_SWIM: TFL_SWIM,
        TRAVEL_WATERJUMP: TFL_WATERJUMP,
        TRAVEL_TELEPORT: TFL_TELEPORT,
        TRAVEL_ELEVATOR: TFL_ELEVATOR,
        TRAVEL_ROCKETJUMP: TFL_ROCKETJUMP,
        TRAVEL_BFGJUMP: TFL_BFGJUMP,
        TRAVEL_GRAPPLEHOOK: TFL_GRAPPLEHOOK,
        TRAVEL_DOUBLEJUMP: TFL_DOUBLEJUMP,
        TRAVEL_RAMPJUMP: TFL_RAMPJUMP,
        TRAVEL_STRAFEJUMP: TFL_STRAFEJUMP,
        TRAVEL_JUMPPAD: TFL_JUMPPAD,
        TRAVEL_FUNCBOB: TFL_FUNCBOB
    };
    return flags.get(kind, TFL_INVALID);
}

"""be_aas_route.c AAS_GetAreaContentsTravelFlags: entering an area also
needs the flag of its liquid (or air) and of do-not-enter contents."""
def area_contents_travel_flags(contents: int) -> int {
    flags = TFL_AIR;
    if contents & AREACONTENTS_WATER {
        flags = TFL_WATER;
    } elif contents & AREACONTENTS_SLIME {
        flags = TFL_SLIME;
    } elif contents & AREACONTENTS_LAVA {
        flags = TFL_LAVA;
    }
    if contents & AREACONTENTS_DONOTENTER {
        flags |= TFL_DONOTENTER;
    }
    return flags;
}

"""The BSP model of the mover an area lies in (AREACONTENTS_MOVER with its
AREACONTENTS_MODELNUM, bspc 2.1 and later), or 0."""
def area_mover_model(contents: int) -> int {
    if contents & AREACONTENTS_MOVER == 0 {
        return 0;
    }
    return (contents >> AREACONTENTS_MODELNUMSHIFT) & AREACONTENTS_MAXMODELNUM;
}

obj AasArea {
    has center: Vec3,
        mins: Vec3,
        maxs: Vec3,
        flags: int = 0,
        contents: int = 0,
        presence: int = 6,
        first_reach: int = 0,
        reach_count: int = 0;
}

"""A reachability. `face_num` and `edge_num` (facenum, edgenum) carry what the travel type needs
besides its two points: for elevators and bobbing platforms `face_num & 0xFFFF`
is the mover's BSP model, and a bobbing platform's `face_num >> 16` holds its
spawnflags and `edge_num` the axis positions of its two ends (be_aas_reach.c)."""
obj AasReach {
    has area: int,
        start: Vec3,
        finish: Vec3,
        kind: int,
        time: int,
        face_num: int = 0,
        edge_num: int = 0;
}

obj Aas {
    has checksum: int = 0,
        normals: list[Vec3] = [],
        dists: list[float] = [],
        node_planes: list[int] = [],
        front: list[int] = [],
        back: list[int] = [],
        areas: list[AasArea] = [],
        reaches: list[AasReach] = [];

    """be_aas_sample.c AAS_PointAreaNum: descend the node tree; negative children
    are areas and zero is solid."""
    def area_at(point: Vec3) -> int {
        branch = 1;
        steps = 0;
        while branch > 0 and branch < len(self.node_planes) and steps < 4096 {
            plane = self.node_planes[branch];
            normal = self.normals[plane];
            dist = point.dot(normal) - self.dists[plane];
            branch = self.front[branch] if dist > 0.0 else self.back[branch];
            steps += 1;
        }
        if branch >= 0 {
            return 0;
        }
        area = -branch;
        return area if area < len(self.areas) else 0;
    }

    """be_aas_sample.c AAS_TraceAreas: the areas a line passes through, in
    order from `start`, each with the point where the line enters it; at
    most `limit` of them."""
    def trace_areas(start: Vec3, finish: Vec3, limit: int = 10) -> list[tuple[int, Vec3]] {
        found: list[tuple[int, Vec3]] = [];
        stack: list[tuple[int, Vec3, Vec3]] = [(1, start, finish)];
        while stack and len(stack) < 127 {
            leg = stack.pop();
            branch = leg[0];
            if branch < 0 {
                if -branch < len(self.areas) {
                    found.append((-branch, leg[1]));
                    if len(found) >= limit {
                        return found;
                    }
                }
                continue;
            }
            if branch == 0 or branch >= len(self.node_planes) {
                continue;
            }
            plane = self.node_planes[branch];
            front = leg[1].dot(self.normals[plane]) - self.dists[plane];
            back = leg[2].dot(self.normals[plane]) - self.dists[plane];
            if front > 0.0 and back > 0.0 {
                stack.append((self.front[branch], leg[1], leg[2]));
            } elif front <= 0.0 and back <= 0.0 {
                stack.append((self.back[branch], leg[1], leg[2]));
            } else {
                middle = leg[1].lerp(leg[2], max(0.0, min(1.0, front / (front - back))));
                # The far side waits while the near side is walked first.
                if front < 0.0 {
                    stack.append((self.front[branch], middle, leg[2]));
                    stack.append((self.back[branch], leg[1], middle));
                } else {
                    stack.append((self.back[branch], middle, leg[2]));
                    stack.append((self.front[branch], leg[1], middle));
                }
            }
        }
        return found;
    }

    """be_aas_sample.c AAS_BBoxAreas: the areas a box touches, at most
    `limit` of them."""
    def box_areas(mins: Vec3, maxs: Vec3, limit: int = 64) -> list[int] {
        found: list[int] = [];
        stack: list[int] = [1];
        while stack {
            branch = stack.pop();
            if branch < 0 {
                if -branch < len(self.areas) and -branch not in found {
                    found.append(-branch);
                    if len(found) >= limit {
                        return found;
                    }
                }
                continue;
            }
            if branch == 0 or branch >= len(self.node_planes) {
                continue;
            }
            plane = self.node_planes[branch];
            normal = self.normals[plane];
            # AAS_BoxOnPlaneSide2: the box's corners nearest and furthest
            # along the plane's normal.
            near = Vec3(
                x=maxs.x if normal.x < 0.0 else mins.x,
                y=maxs.y if normal.y < 0.0 else mins.y,
                z=maxs.z if normal.z < 0.0 else mins.z
            );
            far = Vec3(
                x=mins.x if normal.x < 0.0 else maxs.x,
                y=mins.y if normal.y < 0.0 else maxs.y,
                z=mins.z if normal.z < 0.0 else maxs.z
            );
            if far.dot(normal) - self.dists[plane] >= 0.0 {
                stack.append(self.front[branch]);
            }
            if near.dot(normal) - self.dists[plane] < 0.0 {
                stack.append(self.back[branch]);
            }
        }
        return found;
    }
}

"""A header integer. Version 5 files hide their header: be_aas_file.c
AAS_DData XORs each byte after the version with its offset times 119.
Version 4 (AASVERSION_OLD, e.g. q3dm19) stores it plainly."""
def header_i32(data: bytes, p: int, hidden: bool = True) -> int {
    value = 0;
    for k in range(4) {
        mask = ((p + k - 8) * 119) & 255 if hidden else 0;
        value |= (data[p + k] ^ mask) << (8 * k);
    }
    return value - 4294967296 if value >= 2147483648 else value;
}

def lump(data: bytes, index: int, hidden: bool = True) -> tuple[int, int] {
    return (header_i32(data, 12 + index * 8, hidden), header_i32(data, 16 + index * 8, hidden));
}

def parse_aas(data: bytes) -> Aas {
    require_range(data, 0, 124);
    version = i32_at(data, 4);
    if data[0:4] != b"EAAS" or version not in [4, 5] {
        raise ValueError("Unsupported AAS file");
    }
    hidden = version == 5;
    result = Aas(checksum=header_i32(data, 8, hidden));
    planes = lump(data, 2, hidden);
    require_range(data, planes[0], planes[1]);
    for i in range(planes[1] // 20) {
        p = planes[0] + i * 20;
        result.normals.append(vec_at(data, p));
        result.dists.append(f32_at(data, p + 12));
    }
    nodes = lump(data, 10, hidden);
    require_range(data, nodes[0], nodes[1]);
    for i in range(nodes[1] // 12) {
        p = nodes[0] + i * 12;
        plane = i32_at(data, p);
        if plane < 0 or plane >= len(result.normals) {
            raise ValueError("AAS node plane out of range");
        }
        result.node_planes.append(plane);
        result.front.append(i32_at(data, p + 4));
        result.back.append(i32_at(data, p + 8));
    }
    areas = lump(data, 7, hidden);
    settings = lump(data, 8, hidden);
    require_range(data, areas[0], areas[1]);
    require_range(data, settings[0], settings[1]);
    count = areas[1] // 48;
    if settings[1] // 28 != count {
        raise ValueError("AAS area settings do not match areas");
    }
    for i in range(count) {
        p = areas[0] + i * 48;
        s = settings[0] + i * 28;
        result.areas.append(
            AasArea(
                mins=vec_at(data, p + 12),
                maxs=vec_at(data, p + 24),
                center=vec_at(data, p + 36),
                contents=i32_at(data, s),
                flags=i32_at(data, s + 4),
                presence=i32_at(data, s + 8),
                reach_count=i32_at(data, s + 20),
                first_reach=i32_at(data, s + 24)
            )
        );
    }
    reaches = lump(data, 9, hidden);
    require_range(data, reaches[0], reaches[1]);
    for i in range(reaches[1] // 44) {
        p = reaches[0] + i * 44;
        target = i32_at(data, p);
        if target < 0 or target >= count {
            raise ValueError("AAS reachability area out of range");
        }
        result.reaches.append(
            AasReach(
                area=target,
                start=vec_at(data, p + 12),
                finish=vec_at(data, p + 24),
                kind=i32_at(data, p + 36) & 16777215,
                time=u16_at(data, p + 40),
                face_num=i32_at(data, p + 4),
                edge_num=i32_at(data, p + 8)
            )
        );
    }
    for area in result.areas {
        if area.reach_count < 0
            or area.first_reach < 0
            or area.first_reach + area.reach_count > len(result.reaches) {
            raise ValueError("AAS area reachabilities out of range");
        }
    }
    return result;
}

"""A navigation's data as an arena's file: Quake III's AAS (version 5, its
header hidden as be_aas_file.c hides it), with the lumps a router reads:
the tree's planes and nodes, the areas with their settings, and the ways
between them. The others (faces, edges, portals, clusters) are empty."""
def aas_bytes(aas: Aas) -> bytes {
    planes = bytearray();
    for (index, normal) in enumerate(aas.normals) {
        planes.extend(struct.pack("<ffffi", normal.x, normal.y, normal.z, aas.dists[index] if index < len(aas.dists) else 0.0, 0));
    }
    nodes = bytearray();
    for index in range(len(aas.node_planes)) {
        nodes.extend(struct.pack("<iii", aas.node_planes[index], aas.front[index], aas.back[index]));
    }
    areas = bytearray();
    settings = bytearray();
    for (index, area) in enumerate(aas.areas) {
        areas.extend(
            struct.pack(
                "<iiifffffffff", index, 0, 0, area.mins.x, area.mins.y, area.mins.z, area.maxs.x, area.maxs.y, area.maxs.z,
                area.center.x, area.center.y, area.center.z
            )
        );
        settings.extend(struct.pack("<iiiiiii", area.contents, area.flags, area.presence, 0, 0, area.reach_count, area.first_reach));
    }
    reaches = bytearray();
    for reach in aas.reaches {
        reaches.extend(
            struct.pack(
                "<iiiffffffiHH", reach.area, reach.face_num, reach.edge_num, reach.start.x, reach.start.y, reach.start.z,
                reach.finish.x, reach.finish.y, reach.finish.z, reach.kind, reach.time & 65535, 0
            )
        );
    }
    lumps: list[bytes] = [b"" for index in range(14)];
    lumps[2] = bytes(planes);
    lumps[7] = bytes(areas);
    lumps[8] = bytes(settings);
    lumps[9] = bytes(reaches);
    lumps[10] = bytes(nodes);
    header = bytearray(struct.pack("<ii", aas.checksum, 0)[:4]);
    at = 8 + 4 + 14 * 8;
    for piece in lumps {
        header.extend(struct.pack("<ii", at, len(piece)));
        at += len(piece);
    }
    # be_aas_file.c AAS_DData: each header byte after the version XORed with its offset times 119.
    for k in range(len(header)) {
        header[k] = header[k] ^ ((k * 119) & 255);
    }
    made = bytearray(b"EAAS") + bytearray(struct.pack("<i", 5)) + header;
    for piece in lumps {
        made.extend(piece);
    }
    return bytes(made);
}
