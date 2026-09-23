"""Generated solid geometry uses the same faces, brush hulls and spatial records."""
import from engine.formats.bsp { Bsp, Face, Brush, Plane, Branch, Model, Leaf }
import from engine.math.vec3 { Vec3 }

# Box faces in order: -z, +z, -y, +x, +y, -x.
glob BOX_POLYGONS: list[list[int]] = [
    [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]
];

obj Builder {
    has bsp: Bsp = Bsp(game="passion"), owner: int = 0;

    def panel(points: list[Vec3], material: int, model: int = 0) {
        normal = points[1].sub(points[0]).cross(points[2].sub(points[0])).normalized();
        self.bsp.leaves[self.owner].faces.append(len(self.bsp.faces));
        self.bsp.faces.append(
            Face(
                vertices=points,
                normal=normal,
                plane_dist=normal.dot(points[0]),
                texture=material,
                indices=[0, 1, 2, 0, 2, 3],
                uv=[0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0]
            )
        );
        self.bsp.models[model].face_count += 1;
    }

    def box(low: Vec3, high: Vec3, material: int, model: int = 0) {
        self.block_shared(
            low,
            high,
            [material for _ in range(6)],
            [True for _ in range(6)],
            [[self.owner] for _ in range(6)],
            1,
            model
        );
    }

    # A convex brush whose faces can be culled or textured individually. Hidden
    # faces still contribute planes, so collision stays exact. Each visible face
    # is listed in every leaf whose air it faces.
    def block_shared(
        low: Vec3,
        high: Vec3,
        materials: list[int],
        visible: list[bool],
        owners: list[list[int]],
        contents: int = 1,
        model: int = 0
    ) {
        vertices = corners(low, high);
        brush = Brush(contents=contents);
        for side in range(6) {
            points = [vertices[index] for index in BOX_POLYGONS[side]];
            normal = points[1].sub(points[0]).cross(points[2].sub(points[0])).normalized();
            brush.planes.append(len(self.bsp.planes));
            self.bsp.planes.append(Plane(normal=normal, distance=normal.dot(points[0])));
            if not visible[side] {
                continue;
            }
            face = Face(
                vertices=points,
                normal=normal,
                plane_dist=normal.dot(points[0]),
                texture=materials[side],
                indices=[0, 1, 2, 0, 2, 3]
            );
            for point in points {
                u = point.x if abs(normal.z) > 0.5 or abs(normal.y) > 0.5 else point.y;
                v = point.y if abs(normal.z) > 0.5 else point.z;
                face.uv.extend([u / 128.0, v / 128.0]);
                brightness = int(78.0 + 40.0 * max(0.0, normal.z) + 8.0 * abs(normal.x));
                face.colors.extend([brightness, brightness, brightness, 255]);
            }
            for leaf in owners[side] {
                self.bsp.leaves[leaf].faces.append(len(self.bsp.faces));
            }
            self.bsp.faces.append(face);
            self.bsp.models[model].face_count += 1;
        }
        self.bsp.models[model].brushes.append(len(self.bsp.brushes));
        self.bsp.brushes.append(brush);
    }

    # Trigger volumes have planes but no faces; they are never drawn.
    def volume(low: Vec3, high: Vec3, model: int) {
        vertices = corners(low, high);
        brush = Brush(contents=0);
        for side in range(6) {
            points = [vertices[index] for index in BOX_POLYGONS[side]];
            normal = points[1].sub(points[0]).cross(points[2].sub(points[0])).normalized();
            brush.planes.append(len(self.bsp.planes));
            self.bsp.planes.append(Plane(normal=normal, distance=normal.dot(points[0])));
        }
        self.bsp.models[model].brushes.append(len(self.bsp.brushes));
        self.bsp.brushes.append(brush);
    }
}

def corners(low: Vec3, high: Vec3) -> list[Vec3] {
    return [
        Vec3(x=low.x, y=low.y, z=low.z),
        Vec3(x=high.x, y=low.y, z=low.z),
        Vec3(x=high.x, y=high.y, z=low.z),
        Vec3(x=low.x, y=high.y, z=low.z),
        Vec3(x=low.x, y=low.y, z=high.z),
        Vec3(x=high.x, y=low.y, z=high.z),
        Vec3(x=high.x, y=high.y, z=high.z),
        Vec3(x=low.x, y=high.y, z=high.z)
    ];
}

# Axis-aligned partition of the macro grid into leaves of uniform ownership.
# Unowned (solid) cells adopt whatever leaf contains them, so they never force
# a split. Returns a branch index, or -(leaf + 1) for a single leaf.
def partition(
    bsp: Bsp,
    owners: list[int],
    columns: int,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    scale: float,
    leaf_owner: list[int]
) -> int {
    first = -1;
    uniform = True;
    for y in range(y0, y1) {
        for x in range(x0, x1) {
            owner = owners[y * columns + x];
            if owner < 0 {
                continue;
            }
            if first < 0 {
                first = owner;
            } elif owner != first {
                uniform = False;
            }
        }
    }
    if uniform {
        leaf = len(bsp.leaves);
        bsp.leaves.append(
            Leaf(
                contents=0,
                vis_offset=0,
                mins=Vec3(x=float(x0) * scale, y=float(y0) * scale, z=-4096.0),
                maxs=Vec3(x=float(x1) * scale, y=float(y1) * scale, z=8192.0)
            )
        );
        leaf_owner.append(first);
        return -(leaf + 1);
    }
    # Choose the ownership boundary nearest the middle of either axis.
    best_axis_x = True;
    best_at = -1;
    best_score = 1000000;
    for axis_x in [True, False] {
        low = x0 if axis_x else y0;
        high = x1 if axis_x else y1;
        middle = (low + high) // 2;
        for at in range(low + 1, high) {
            if not boundary(owners, columns, x0, y0, x1, y1, axis_x, at) {
                continue;
            }
            score = abs(at - middle) * 4 - (high - low);
            if score < best_score {
                best_score = score;
                best_axis_x = axis_x;
                best_at = at;
            }
        }
    }
    if best_at < 0 {
        best_axis_x = (x1 - x0) >= (y1 - y0);
        best_at = (x0 + x1) // 2 if best_axis_x else (y0 + y1) // 2;
    }
    normal = Vec3(x=1.0) if best_axis_x else Vec3(y=1.0);
    plane = len(bsp.planes);
    bsp.planes.append(Plane(normal=normal, distance=float(best_at) * scale));
    index = len(bsp.branches);
    bsp.branches.append(Branch(plane=plane, front=0, back=0));
    back = partition(
        bsp,
        owners,
        columns,
        x0,
        y0,
        best_at if best_axis_x else x1,
        y1 if best_axis_x else best_at,
        scale,
        leaf_owner
    );
    front = partition(
        bsp,
        owners,
        columns,
        best_at if best_axis_x else x0,
        y0 if best_axis_x else best_at,
        x1,
        y1,
        scale,
        leaf_owner
    );
    bsp.branches[index].front = front;
    bsp.branches[index].back = back;
    return index;
}

def boundary(
    owners: list[int],
    columns: int,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    axis_x: bool,
    at: int
) -> bool {
    if axis_x {
        for y in range(y0, y1) {
            a = owners[y * columns + at - 1];
            b = owners[y * columns + at];
            if a >= 0 and b >= 0 and a != b {
                return True;
            }
        }
        return False;
    }
    for x in range(x0, x1) {
        a = owners[(at - 1) * columns + x];
        b = owners[at * columns + x];
        if a >= 0 and b >= 0 and a != b {
            return True;
        }
    }
    return False;
}
