"""Quake 3 Area Awareness System files (maps/*.aas): the areas, reachabilities
and point-location tree the original bots navigate with (botlib be_aas_file.c,
version 5 with its XOR-scrambled header)."""
import from .bsp { i32_at, u16_at, f32_at, vec_at, require_range }
import from ..math.vec3 { Vec3 }

# botlib aasfile.h travel types.
glob TRAVEL_WALK: int = 2,
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
    TRAVEL_JUMPPAD: int = 18,
    TRAVEL_FUNCBOB: int = 19;

# aasfile.h area flags.
glob AREA_GROUNDED: int = 1,
    AREA_DISABLED: int = 8;

obj AasArea {
    has center: Vec3,
        mins: Vec3,
        maxs: Vec3,
        flags: int = 0,
        contents: int = 0,
        first_reach: int = 0,
        reach_count: int = 0;
}

obj AasReach {
    has area: int,
        start: Vec3,
        finish: Vec3,
        kind: int,
        time: int;
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
}

"""A header integer; be_aas_file.c AAS_DData XORs each header byte after the
version with its offset times 119."""
def header_i32(data: bytes, p: int) -> int {
    value = 0;
    for k in range(4) {
        value |= (data[p + k] ^ (((p + k - 8) * 119) & 255)) << (8 * k);
    }
    return value - 4294967296 if value >= 2147483648 else value;
}

def lump(data: bytes, index: int) -> tuple[int, int] {
    return (header_i32(data, 12 + index * 8), header_i32(data, 16 + index * 8));
}

def parse_aas(data: bytes) -> Aas {
    require_range(data, 0, 124);
    if data[0:4] != b"EAAS" or i32_at(data, 4) != 5 {
        raise ValueError("Unsupported AAS file");
    }
    result = Aas(checksum=header_i32(data, 8));
    planes = lump(data, 2);
    require_range(data, planes[0], planes[1]);
    for i in range(planes[1] // 20) {
        p = planes[0] + i * 20;
        result.normals.append(vec_at(data, p));
        result.dists.append(f32_at(data, p + 12));
    }
    nodes = lump(data, 10);
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
    areas = lump(data, 7);
    settings = lump(data, 8);
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
                reach_count=i32_at(data, s + 20),
                first_reach=i32_at(data, s + 24)
            )
        );
    }
    reaches = lump(data, 9);
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
                time=u16_at(data, p + 40)
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
