"""Q1 and Q2 particles on the GPU.

A particle is spawned once (particle_field.jac) and never updated on the
CPU: its spawn record goes into a ring of instance records, and the vertex
shader works out where it is, what colour and how opaque at the effect time
from the same closed forms `particle_state` gives. The CPU only uploads the
records spawned since the last frame; a record stays in the ring until a
newer one takes its place, and shows only while its time lasts.

Q1 particles look as the software renderer drew them (d_part.c
D_DrawParticle): solid squares about 1.6 units across, never under a pixel
nor over four at 320 pixels wide, writing depth. Q2 particles are ref_gl's
(GL_DrawParticles): the round particle texture's dot in the corner of a
triangle 1.5 units a side from the particle, growing with distance (1 +
0.004 a unit past 20), blended by alpha without writing depth. Colours are
palette entries; Q1 fire and explosions run through r_part.c's ramps.
Sparks (Q3 and Passion impacts) are plain coloured squares."""
import struct;
import from .gpu {
    GpuMesh,
    GpuProgram,
    VertexAttribute,
    GL_FLOAT,
    view_projection,
    pack_floats
}
import from ..world.particle_field {
    Particle,
    ParticleField,
    PARTICLE_LIMIT,
    QUAKE_RAMP1,
    QUAKE_RAMP2,
    QUAKE_RAMP3
}
import from ..math.vec3 { Vec3, forward_from, right_from }
import from vendor.raylib {
    def rlLoadTexture(data: bytes, width: i32, height: i32, format: i32, mipmapCount: i32) -> u32;  def rlUnloadTexture(
        id: u32
    ) -> None;  def rlTextureParameters(id: u32, param: i32, value: i32) -> None;  def rlDrawRenderBatchActive -> None;  def BeginBlendMode(
        mode: i32
    ) -> None;  def EndBlendMode -> None;  def rlDisableDepthMask -> None;  def rlEnableDepthMask -> None;  def rlDisableBackfaceCulling -> None;  def rlEnableBackfaceCulling -> None;
}

# One particle record: origin, velocity and acceleration (9 floats), born,
# life, ramp and kind (4), colour, alpha and alpha rate (3).
glob PARTICLE_STRIDE: int = 64;

glob PARTICLE_VS: str = """#version 330
in vec2 corner;
in vec3 origin;
in vec3 velocity;
in vec3 accel;
in vec4 timing;
in vec3 look;
uniform mat4 mvp;
uniform float now;
uniform vec3 side;
uniform vec3 up;
uniform sampler2D palette;
uniform vec4 ramps[6];
out vec2 spot;
out vec4 shade;
flat out float rounded;
float ramp(int table, float at) {
    int i = table * 8 + int(at);
    return ramps[i / 4][i - (i / 4) * 4];
}
void main() {
    gl_Position = vec4(0.0, 0.0, -2.0, 1.0);
    spot = corner;
    shade = vec4(0.0);
    rounded = 0.0;
    float t = now - timing.x;
    int kind = int(timing.w + 0.5);
    if (t < 0.0 || t > timing.y) return;
    const float g = 40.0;
    vec3 p = origin + velocity * t;
    float index = look.x;
    float alpha = 1.0;
    if (kind == 1 || kind == 2) {
        p.z -= 0.5 * g * t * t;
    } else if (kind == 3) {
        p.z += 0.5 * g * t * t;
        float r = timing.z + 5.0 * t;
        if (r >= 6.0) return;
        index = ramp(2, r);
    } else if (kind == 4 || kind == 6) {
        float e = (exp(4.0 * t) - 1.0) / 4.0;
        p = origin + velocity * e;
        p.z += g / 4.0 * (t - e);
        if (kind == 4) {
            float r = timing.z + 10.0 * t;
            if (r >= 8.0) return;
            index = ramp(0, r);
        }
    } else if (kind == 5) {
        float s = 1.0 - exp(-t);
        p = origin + velocity * s;
        p.z += g * (s - t);
        float r = timing.z + 15.0 * t;
        if (r >= 8.0) return;
        index = ramp(1, r);
    } else if (kind == 7) {
        float s = (1.0 - exp(-4.0 * t)) / 4.0;
        p = vec3(origin.xy + velocity.xy * s, origin.z + velocity.z * t - 0.5 * g * t * t);
    } else if (kind >= 8) {
        p += accel * (t * t);
        alpha = look.y + look.z * t;
        if (alpha <= 0.0) return;
        alpha = min(alpha, 1.0);
    }
    vec3 color;
    if (kind == 9) {
        color = vec3(floor(index / 65536.0), mod(floor(index / 256.0), 256.0), mod(index, 256.0)) / 255.0;
    } else {
        color = texelFetch(palette, ivec2(int(index + 0.5), 0), 0).rgb;
    }
    float depth = (mvp * vec4(p, 1.0)).w;
    vec3 at;
    if (kind == 8) {
        float size = 1.5 * (depth < 20.0 ? 1.0 : 1.0 + depth * 0.004);
        at = p + (side * corner.x + up * corner.y) * size;
        rounded = 1.0;
    } else {
        float size = kind == 9 ? 1.2 : min(max(1.6, depth / 160.0), depth / 40.0);
        at = p + (side * (corner.x - 0.5) + up * (corner.y - 0.5)) * size;
    }
    shade = vec4(color, alpha);
    gl_Position = mvp * vec4(at, 1.0);
}
""",
     PARTICLE_FS: str = """#version 330
in vec2 spot;
in vec4 shade;
flat in float rounded;
out vec4 finalColor;
void main() {
    if (rounded > 0.5) {
        ivec2 texel = ivec2(spot * 8.0);
        bool edge = texel.x == 0 || texel.x == 3;
        if (texel.x > 3 || texel.y > 3 || (edge && (texel.y == 0 || texel.y == 3))) discard;
    }
    finalColor = shade;
}
""";

"""A particle's instance record, packed once at upload."""
def pack_particle(out: bytearray, offset: int, particle: Particle) {
    o = particle.origin;
    v = particle.velocity;
    a = particle.accel;
    struct.pack_into(
        "<16f", out, offset,
        o.x, o.y, o.z,
        v.x, v.y, v.z,
        a.x, a.y, a.z,
        particle.born, particle.life, particle.ramp, float(particle.kind),
        float(particle.color), particle.alpha, particle.fade
    );
}

"""The ring of particle records on the GPU, the program that draws them and
the palette their colours index."""
obj ParticleRing {
    has program: GpuProgram = GpuProgram(),
        mesh: GpuMesh = GpuMesh(),
        palette: int = 0,
        cursor: int = 0,
        filled: int = 0,
        depth_write: bool = False;

    """Load the program, the ring and the game's 256-colour `palette` (768
    RGB bytes; empty for games without one). Q1 particles write depth."""
    def open(palette: bytes, depth_write: bool) {
        self.close();
        self.program.load(PARTICLE_VS, PARTICLE_FS);
        corner = self.program.attribute("corner");
        layout = [
            VertexAttribute(location=self.program.attribute("origin"), components=3, kind=GL_FLOAT, offset=0),
            VertexAttribute(location=self.program.attribute("velocity"), components=3, kind=GL_FLOAT, offset=12),
            VertexAttribute(location=self.program.attribute("accel"), components=3, kind=GL_FLOAT, offset=24),
            VertexAttribute(location=self.program.attribute("timing"), components=4, kind=GL_FLOAT, offset=36),
            VertexAttribute(location=self.program.attribute("look"), components=3, kind=GL_FLOAT, offset=52)
        ];
        self.mesh.upload(
            pack_floats([0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0]),
            8,
            [VertexAttribute(location=corner, components=2, kind=GL_FLOAT)]
        );
        self.mesh.upload_instances(PARTICLE_LIMIT, PARTICLE_STRIDE, layout);
        colors = bytearray(256 * 4);
        for i in range(256) {
            if len(palette) >= i * 3 + 3 {
                colors[i * 4] = palette[i * 3];
                colors[i * 4 + 1] = palette[i * 3 + 1];
                colors[i * 4 + 2] = palette[i * 3 + 2];
            }
            colors[i * 4 + 3] = 255;
        }
        self.palette = int(rlLoadTexture(bytes(colors), i32(256), i32(1), i32(7), i32(1)));
        rlTextureParameters(u32(self.palette), i32(10241), i32(9728));
        rlTextureParameters(u32(self.palette), i32(10240), i32(9728));
        self.cursor = 0;
        self.filled = 0;
        self.depth_write = depth_write;
    }

    """Take the particles spawned since the last frame into the ring."""
    def feed(field: ParticleField) {
        fresh = field.fresh;
        if not fresh or self.program.id == 0 {
            field.fresh = [];
            return;
        }
        field.fresh = [];
        if len(fresh) > PARTICLE_LIMIT {
            fresh = fresh[len(fresh) - PARTICLE_LIMIT:];
        }
        # Up to the ring's end, then on from its start.
        first = min(len(fresh), PARTICLE_LIMIT - self.cursor);
        head = bytearray(first * PARTICLE_STRIDE);
        for i in range(first) {
            pack_particle(head, i * PARTICLE_STRIDE, fresh[i]);
        }
        self.mesh.set_instances(bytes(head), self.cursor * PARTICLE_STRIDE);
        rest = len(fresh) - first;
        if rest > 0 {
            tail = bytearray(rest * PARTICLE_STRIDE);
            for i in range(rest) {
                pack_particle(tail, i * PARTICLE_STRIDE, fresh[first + i]);
            }
            self.mesh.set_instances(bytes(tail), 0);
        }
        self.cursor = (self.cursor + len(fresh)) % PARTICLE_LIMIT;
        self.filled = min(PARTICLE_LIMIT, self.filled + len(fresh));
    }

    """Draw every particle still showing at `now`, for a view turned `yaw`
    and `pitch`."""
    def draw(now: float, yaw: float, pitch: float) {
        if self.filled == 0 or self.program.id == 0 {
            return;
        }
        side = right_from(yaw);
        up = side.cross(forward_from(yaw, pitch)).normalized();
        ramps: list[float] = [];
        for table in [QUAKE_RAMP1, QUAKE_RAMP2, QUAKE_RAMP3] {
            for value in table {
                ramps.append(float(value));
            }
        }
        rlDrawRenderBatchActive();
        BeginBlendMode(i32(0));
        if not self.depth_write {
            rlDisableDepthMask();
        }
        rlDisableBackfaceCulling();
        self.program.begin();
        self.program.set_matrix("mvp", view_projection());
        self.program.set_float("now", now);
        self.program.set_vec4s("ramps", pack_floats(ramps));
        self.program.set_vec3("side", side);
        self.program.set_vec3("up", up);
        self.program.set_texture("palette", 0, self.palette);
        self.mesh.bind();
        self.mesh.draw_instances(0, 6, self.filled);
        self.mesh.unbind();
        self.program.end();
        rlEnableBackfaceCulling();
        rlEnableDepthMask();
        EndBlendMode();
    }

    def close() {
        self.mesh.close();
        self.program.close();
        if self.palette != 0 {
            rlUnloadTexture(u32(self.palette));
            self.palette = 0;
        }
        self.cursor = 0;
        self.filled = 0;
    }
}
