"""Textured polygons added to the scene one at a time (Q3 RE_AddPolyToScene):
each a convex polygon of world points with texture coordinates and one
colour, fanned into triangles. A frame's polygons are packed into one
dynamic vertex buffer and drawn in runs of the same texture and blend, depth
tested without writing depth, both sides."""
import struct;
import from .gpu {
    GpuMesh,
    GpuProgram,
    VertexAttribute,
    GL_FLOAT,
    GL_UNSIGNED_BYTE,
    view_projection
}
import from ..math.vec3 { Vec3 }
import from vendor.raylib {
    def rlGetTextureIdDefault -> u32;  def rlDrawRenderBatchActive -> None;  def BeginBlendMode(
        mode: i32
    ) -> None;  def EndBlendMode -> None;  def rlSetBlendFactors(
        src: i32, dst: i32, equation: i32
    ) -> None;  def rlDisableDepthMask -> None;  def rlEnableDepthMask -> None;  def rlDisableBackfaceCulling -> None;  def rlEnableBackfaceCulling -> None;
}

# One polygon vertex: position (3 floats), texture st (2), RGBA bytes.
glob POLYGON_STRIDE: int = 24;

# How a run blends: by alpha, added, or darkening what is behind
# (GL_ZERO GL_ONE_MINUS_SRC_COLOR), as the effect quads do.
glob POLYGON_BLEND_ALPHA: int = 0,
     POLYGON_BLEND_ADD: int = 1,
     POLYGON_BLEND_DARKEN: int = 2;

glob POLYGON_VS: str = """#version 330
in vec3 position;
in vec2 texcoord;
in vec4 color;
uniform mat4 mvp;
out vec2 uv;
out vec4 shade;
void main() {
    uv = texcoord;
    shade = color;
    gl_Position = mvp * vec4(position, 1.0);
}
""",
     POLYGON_FS: str = """#version 330
in vec2 uv;
in vec4 shade;
uniform sampler2D art;
out vec4 finalColor;
void main() {
    finalColor = texture(art, uv) * shade;
}
""";

"""Consecutive triangles sharing a texture and blend: one draw."""
obj PolygonRun {
    has texture: int,
        blend: int,
        first: int,
        count: int = 0;
}

obj ScenePolygons {
    has program: GpuProgram = GpuProgram(),
        mesh: GpuMesh = GpuMesh(),
        capacity: int = 0,
        packed: bytearray = bytearray(),
        count: int = 0,
        runs: list[PolygonRun] = [],
        white: int = 0,
        layout: list[VertexAttribute] = [];

    def open() {
        if self.program.id != 0 {
            return;
        }
        self.program.load(POLYGON_VS, POLYGON_FS);
        self.layout = [
            VertexAttribute(location=self.program.attribute("position"), components=3, kind=GL_FLOAT, offset=0),
            VertexAttribute(location=self.program.attribute("texcoord"), components=2, kind=GL_FLOAT, offset=12),
            VertexAttribute(location=self.program.attribute("color"), components=4, kind=GL_UNSIGNED_BYTE, normalized=True, offset=20)
        ];
        self.white = int(rlGetTextureIdDefault());
        self.count = 0;
        self.runs = [];
    }

    """Queue a convex polygon: `points` with texture coordinates `st` (two per
    point), coloured `red` `green` `blue` `alpha`; `texture` 0 is white."""
    def add(texture: int, blend: int, points: list[Vec3], st: list[float], red: int, green: int, blue: int, alpha: int) {
        if len(points) < 3 or len(st) < len(points) * 2 {
            return;
        }
        art = texture if texture != 0 else self.white;
        if not self.runs or self.runs[-1].texture != art or self.runs[-1].blend != blend {
            self.runs.append(PolygonRun(texture=art, blend=blend, first=self.count));
        }
        triangles = len(points) - 2;
        needed = (self.count + triangles * 3) * POLYGON_STRIDE;
        if needed > len(self.packed) {
            self.packed.extend(bytes(max(needed - len(self.packed), len(self.packed))));
        }
        for t in range(triangles) {
            for corner in [0, t + 1, t + 2] {
                p = points[corner];
                struct.pack_into(
                    "<5f4B", self.packed, self.count * POLYGON_STRIDE,
                    p.x, p.y, p.z, st[corner * 2], st[corner * 2 + 1], red, green, blue, alpha
                );
                self.count += 1;
            }
        }
        self.runs[-1].count += triangles * 3;
    }

    """Draw the queued polygons and empty the queue."""
    def flush() {
        if self.count == 0 {
            return;
        }
        if self.count > self.capacity {
            self.mesh.close();
            self.capacity = max(1024, self.count * 2);
            self.mesh.upload(bytes(self.capacity * POLYGON_STRIDE), POLYGON_STRIDE, self.layout, dynamic=True);
        }
        self.mesh.set_vertices(bytes(self.packed[0:self.count * POLYGON_STRIDE]));
        rlDrawRenderBatchActive();
        rlDisableDepthMask();
        rlDisableBackfaceCulling();
        mvp = view_projection();
        for run in self.runs {
            # A blend change flushes rlgl's batch, which unbinds our program.
            if run.blend == POLYGON_BLEND_DARKEN {
                rlSetBlendFactors(i32(0), i32(769), i32(32774));
                BeginBlendMode(i32(6));
            } else {
                BeginBlendMode(i32(run.blend));
            }
            self.program.begin();
            self.program.set_matrix("mvp", mvp);
            self.program.set_texture("art", 0, run.texture);
            self.mesh.bind();
            self.mesh.draw_vertices(run.first, run.count);
            self.mesh.unbind();
            self.program.end();
        }
        rlEnableDepthMask();
        rlEnableBackfaceCulling();
        EndBlendMode();
        self.count = 0;
        self.runs = [];
    }

    def close() {
        self.mesh.close();
        self.program.close();
        self.capacity = 0;
        self.count = 0;
        self.runs = [];
    }
}
