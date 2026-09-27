"""Instanced solid cubes: impact particles and plain projectile markers.

raylib's DrawCube sends 36 vertices through immediate mode for every cube;
here one static unit cube is drawn once per batch with a per-instance record
(centre, edge length, colour), so a spray of hundreds of particles costs one
buffer update and one draw. Colours and blending match DrawCube (raylib's
alpha blending, depth tested and written). QP_RENDER_LEGACY=1 keeps the
DrawCube calls for comparison."""
import os;
import struct;
import from .gpu {
    GpuMesh,
    GpuProgram,
    VertexAttribute,
    GL_FLOAT,
    GL_UNSIGNED_BYTE,
    view_projection,
    pack_floats
}

glob CUBE_VERTEX_SHADER: str = "#version 330\nin vec3 corner; in vec4 place; in vec4 shade; uniform mat4 mvp; out vec4 tint;\n"
    + "void main(){ tint=shade; gl_Position=mvp*vec4(place.xyz+corner*place.w,1.0); }\n",
     CUBE_FRAGMENT_SHADER: str = "#version 330\nin vec4 tint; out vec4 finalColor;\nvoid main(){ finalColor=tint; }\n";

# Instance records per draw: centre and edge (4 floats) and RGBA bytes.
glob CUBE_BATCH_CAPACITY: int = 1024,
     CUBE_RECORD_BYTES: int = 20;

"""The unit cube's 36 corners (edge 1, centred), each face wound
counter-clockwise seen from outside, as DrawCube winds them."""
def unit_cube_corners -> list[float] {
    # Each face: its outward axis and sign, then two in-plane axes whose
    # cross product points outward.
    axes = [0, 0, 1, 1, 2, 2];
    signs = [1.0, -1.0, 1.0, -1.0, 1.0, -1.0];
    firsts = [1, 2, 2, 0, 0, 1];
    seconds = [2, 1, 0, 2, 1, 0];
    quad = [-0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5];
    corners: list[float] = [];
    for face in range(6) {
        for point in range(6) {
            corner = [0.0, 0.0, 0.0];
            corner[axes[face]] = 0.5 * signs[face];
            corner[firsts[face]] = quad[point * 2];
            corner[seconds[face]] = quad[point * 2 + 1];
            corners.extend(corner);
        }
    }
    return corners;
}

obj CubeBatch {
    has program: GpuProgram = GpuProgram(),
        mesh: GpuMesh = GpuMesh(),
        records: bytearray = bytearray(0),
        count: int = 0,
        ready: bool = False,
        legacy: bool = False,
        checked: bool = False;

    """True when cubes go through DrawCube (QP_RENDER_LEGACY=1)."""
    def immediate() -> bool {
        if not self.checked {
            self.legacy = os.getenv("QP_RENDER_LEGACY", "") == "1";
            self.checked = True;
        }
        return self.legacy;
    }

    def prepare() {
        if self.ready {
            return;
        }
        self.program.load(CUBE_VERTEX_SHADER, CUBE_FRAGMENT_SHADER);
        self.mesh = GpuMesh();
        self.mesh.upload(
            pack_floats(unit_cube_corners()),
            12,
            [VertexAttribute(location=self.program.attribute("corner"), components=3, kind=GL_FLOAT)]
        );
        self.mesh.upload_instances(
            CUBE_BATCH_CAPACITY,
            CUBE_RECORD_BYTES,
            [
                VertexAttribute(location=self.program.attribute("place"), components=4, kind=GL_FLOAT),
                VertexAttribute(location=self.program.attribute("shade"), components=4, kind=GL_UNSIGNED_BYTE, normalized=True, offset=16)
            ]
        );
        self.records = bytearray(CUBE_BATCH_CAPACITY * CUBE_RECORD_BYTES);
        self.ready = True;
    }

    """Queue a cube of edge `size` centred on (x, y, z)."""
    def add(x: float, y: float, z: float, size: float, red: int, green: int, blue: int, alpha: int) {
        if not self.ready {
            self.prepare();
        }
        if self.count >= CUBE_BATCH_CAPACITY {
            self.draw();
        }
        struct.pack_into(
            "<ffffBBBB", self.records, self.count * CUBE_RECORD_BYTES, x, y, z, size,
            max(0, min(255, red)), max(0, min(255, green)), max(0, min(255, blue)), max(0, min(255, alpha))
        );
        self.count += 1;
    }

    """Draw the queued cubes (inside the 3D view) and empty the queue."""
    def draw() {
        if self.count == 0 {
            return;
        }
        self.mesh.set_instances(bytes(self.records[:self.count * CUBE_RECORD_BYTES]));
        self.program.begin();
        self.program.set_matrix("mvp", view_projection());
        self.mesh.bind();
        self.mesh.draw_instances(0, 36, self.count);
        self.mesh.unbind();
        self.program.end();
        self.count = 0;
    }

    def close() {
        self.mesh.close();
        self.program.close();
        self.ready = False;
        self.count = 0;
    }
}
