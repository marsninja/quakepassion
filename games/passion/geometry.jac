"""Generated solid geometry uses the same faces, brush hulls and spatial records."""
import from engine.formats.bsp { Bsp, Face, Brush, Plane, Branch, Model, Leaf }
import from engine.math.vec3 { Vec3 }

obj Builder {
    has bsp: Bsp = Bsp(game="passion"), owner: int = 0;
    def panel(points: list[Vec3], material: int, model: int = 0) {
        normal = points[1].sub(points[0]).cross(points[2].sub(points[0])).normalized();
        self.bsp.leaves[self.owner].faces.append(len(self.bsp.faces));
        self.bsp.faces.append(Face(vertices=points, normal=normal, plane_dist=normal.dot(points[0]),
            texture=material, indices=[0,1,2,0,2,3],uv=[0.0,1.0,0.0,0.0,1.0,0.0,1.0,1.0]));
        self.bsp.models[model].face_count += 1;
    }
    def box(low: Vec3, high: Vec3, material: int, model: int = 0) {
        vertices = [Vec3(x=low.x, y=low.y, z=low.z), Vec3(x=high.x, y=low.y, z=low.z),
            Vec3(x=high.x, y=high.y, z=low.z), Vec3(x=low.x, y=high.y, z=low.z),
            Vec3(x=low.x, y=low.y, z=high.z), Vec3(x=high.x, y=low.y, z=high.z),
            Vec3(x=high.x, y=high.y, z=high.z), Vec3(x=low.x, y=high.y, z=high.z)];
        polygons = [[0,3,2,1], [4,5,6,7], [0,1,5,4], [1,2,6,5], [2,3,7,6], [3,0,4,7]];
        brush = Brush(contents=1);
        for polygon in polygons {
            points = [vertices[index] for index in polygon];
            normal = points[1].sub(points[0]).cross(points[2].sub(points[0])).normalized();
            face = Face(vertices=points, normal=normal, plane_dist=normal.dot(points[0]),
                texture=material, indices=[0,1,2,0,2,3]);
            for point in points {
                u = point.x if abs(normal.z) > 0.5 or abs(normal.y) > 0.5 else point.y;
                v = point.y if abs(normal.z) > 0.5 else point.z;
                face.uv.extend([u / 128.0, v / 128.0]);
                brightness = int(78.0 + 40.0 * max(0.0, normal.z) + 8.0 * abs(normal.x));
                face.colors.extend([brightness, brightness, brightness, 255]);
            }
            brush.planes.append(len(self.bsp.planes));
            self.bsp.planes.append(Plane(normal=normal, distance=face.plane_dist));
            self.bsp.leaves[self.owner].faces.append(len(self.bsp.faces));
            self.bsp.faces.append(face);
        }
        self.bsp.models[model].brushes.append(len(self.bsp.brushes));
        self.bsp.brushes.append(brush);
        self.bsp.models[model].face_count += 6;
    }
}

# Balanced partitions divide the authored room regions. Outside space maps to
# an edge room; solid enclosing walls keep ordinary movement inside the world.
def partition(bsp: Bsp, x: int, y: int, width: int, height: int) -> int {
    if width == 1 and height == 1 { return -(y * 5 + x) - 1; }
    axis_x = width >= height;
    half = (width if axis_x else height) // 2;
    normal = Vec3(x=1.0) if axis_x else Vec3(y=1.0);
    distance = float((x if axis_x else y) + half) * 640.0;
    plane = len(bsp.planes);
    bsp.planes.append(Plane(normal=normal, distance=distance));
    index = len(bsp.branches);
    bsp.branches.append(Branch(plane=plane, front=0, back=0));
    back = partition(bsp, x, y, half if axis_x else width, height if axis_x else half);
    front = partition(bsp, x + half if axis_x else x, y if axis_x else y + half,
        width - half if axis_x else width, height if axis_x else height - half);
    bsp.branches[index].front = front;
    bsp.branches[index].back = back;
    return index;
}
