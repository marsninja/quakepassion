"""The BSP world as GPU-resident geometry, drawn the way ironwail, vkQuake
and ioq3's opengl2 renderer draw it: at level load every drawable face is
packed once into static vertex buffers (position, texture and lightmap
coordinates, vertex colour, normal and a few per-face parameters), in
chunks of at most 65535 vertices so 16-bit indices address them. Faces are
sorted into surface batches (a pass and a texture), and per frame the CPU
only chooses which faces are visible: their prebuilt 16-bit index runs are
concatenated per chunk and batch, rebuilt only when the visible set changes,
and each batch draws with one call per chunk. Brush models (doors, plats,
trains, rotators) keep their own index buffer and draw with a model matrix.

Shading (lightmaps, light styles, dynamic lights, liquid warp, the Q1 sky,
Q3 shader stages with their tcMods, colour and alpha generators, deforms,
and fog) runs in the shaders below. Every raylib call stays in the render
layer; this module holds the packing (testable without a window), the GLSL
and the index buffers.
"""
import math;
import struct;
import from vendor.raylib {
    def rlEnableVertexBufferElement(id: u32) -> None;  def rlLoadVertexBufferElement(
        buffer: bytes, size: i32, dynamic: bool
    ) -> u32;  def rlUpdateVertexBufferElements(
        id: u32, data: bytes, dataSize: i32, offset: i32
    ) -> None;  def rlUnloadVertexBuffer(vboId: u32) -> None;  def rlDisableVertexArray -> None;  def rlSetUniform(
        locIndex: i32, value: bytes, uniformType: i32, count: i32
    ) -> None;
}
import from .gpu { MESH_VERTEX_LIMIT, GpuProgram, UNIFORM_VEC2, UNIFORM_VEC3 }
import from ..formats.bsp { Face }
import from ..math.vec3 { Vec3 }
import from ..math.orientation { Basis, blend_basis }
import from ..math.interpolation { TickPose, TickBlend }
import from ..world.lighting { shift_light }

# One packed world vertex (WORLD_VERTEX_FORMAT, spelled out where packed:
# native code needs the struct format as a literal), 84 bytes:
#   0 position (3 floats)       12 texture st (2)      20 lightmap st (2)
#  28 colour (4 bytes)          32 normal (3 floats)
#  44 info (4 bytes: flags, autosprite corner, fog + 1, autosprite2 edge)
#  48 light styles (4 bytes, 255 = none)
#  52 aux A (4 floats)          68 aux B (4 floats)
# Aux A holds the Q1/Q2 light style layer stride, or an autosprite quad's
# centre and radius, or an autosprite2 vertex's own short-edge midpoint and
# half length; aux B the other short edge's midpoint.
glob WORLD_VERTEX_STRIDE: int = 84,
     WORLD_VERTEX_FORMAT: str = "<fffffffBBBBfffBBBBBBBBffffffff";

# Per-face flags in info.x.
glob SURFACE_LIGHTMAP: int = 1,
     SURFACE_ALPHA_SHIFT: int = 1,
     SURFACE_EMISSION: int = 8,
     SURFACE_VERTEX_COLOR: int = 16,
     SURFACE_QUAD: int = 32;

# Surface passes, in draw order within a game. Q1/Q2: lightmapped faces,
# the two-layer Q1 sky, opaque liquids, translucent faces. Q3: single-pass
# lightmapped faces, additive shaders, layered shaders stage by stage, then
# the fog pass over one-sided and two-sided fogged faces.
glob PASS_LIT: int = 1,
     PASS_SKY: int = 2,
     PASS_LIQUID: int = 3,
     PASS_TRANSLUCENT: int = 4,
     PASS_BASE: int = 5,
     PASS_ADDITIVE: int = 6,
     PASS_LAYERED: int = 7,
     PASS_FOG: int = 8,
     PASS_FOG_TWO_SIDED: int = 9;

# Q3 fog volumes the shaders hold at once.
glob WORLD_FOG_LIMIT: int = 16;

"""A run of indices in one chunk's index buffer."""
obj IndexSpan {
    has chunk: int = 0,
        first: int = 0,
        count: int = 0;
}

"""A surface batch: one pass over one texture. `sub` separates liquids that
need different warp uniforms (0 still, 1 flowing, 2 unwarped)."""
obj SurfaceBatch {
    has id: int = 0,
        kind: int = 0,
        texture: int = 0,
        sub: int = 0,
        two_sided: bool = False;
}

"""Per chunk, the index bytes of the chosen faces, batch after batch, and
where each batch's indices start: `spans` maps a batch id to its runs."""
obj IndexLists {
    has chunks: list[bytearray] = [],
        spans: dict[int, list[IndexSpan]] = {},
        faces: int = 0;
}

"""The batch key of a (pass, texture, sub) triple; keys sort in draw order."""
def batch_key(kind: int, texture: int, sub: int) -> int {
    return (kind * 65536 + texture) * 4 + sub;
}

"""Assign faces, in `order`, to chunks of at most `limit` vertices: returns
each face's chunk (-1 for faces not in `order`) and first vertex in it."""
def assign_chunks(counts: list[int], order: list[int], limit: int = MESH_VERTEX_LIMIT) -> tuple[list[int], list[int]] {
    chunk_of = [-1] * len(counts);
    base_of = [0] * len(counts);
    chunk = 0;
    used = 0;
    for f in order {
        count = counts[f];
        if count > limit {
            raise ValueError("World surface has more vertices than one chunk holds");
        }
        if used + count > limit {
            chunk += 1;
            used = 0;
        }
        chunk_of[f] = chunk;
        base_of[f] = used;
        used += count;
    }
    return (chunk_of, base_of);
}

"""A face's triangles as corner numbers: its own index list (Q3 meshes and
patches), else a fan wound as the renderer has always wound it."""
def face_triangles(face: Face) -> list[int] {
    if face.indices {
        return face.indices;
    }
    corners: list[int] = [];
    for corner in range(1, len(face.vertices) - 1) {
        corners.extend([0, corner + 1, corner]);
    }
    return corners;
}

"""A face's triangles as little-endian 16-bit indices from vertex `base`."""
def face_index_bytes(face: Face, base: int) -> bytes {
    corners = face_triangles(face);
    out = bytearray(len(corners) * 2);
    for i in range(len(corners)) {
        struct.pack_into("<H", out, i * 2, base + corners[i]);
    }
    return bytes(out);
}

"""Concatenate the index runs of `faces` into `lists`, per chunk and batch:
each face adds its runs to every batch in `face_batches[f]` (a face may be
drawn by a pass and fogged by another). Batches keep ascending id order in
each chunk, so a batch's indices are one run per chunk. Returns the spans
added, by batch."""
def gather_indices(
    lists: IndexLists,
    faces: list[int],
    face_chunks: list[int],
    face_batches: list[list[int]],
    face_runs: list[bytes]
) -> dict[int, list[IndexSpan]] {
    chunk_count = len(lists.chunks);
    pending: dict[int, bytearray] = {};
    for f in faces {
        chunk = face_chunks[f];
        if chunk < 0 {
            continue;
        }
        for batch in face_batches[f] {
            key = batch * 4096 + chunk;
            if key not in pending {
                pending[key] = bytearray();
            }
            pending[key].extend(face_runs[f]);
        }
        lists.faces += 1;
    }
    added: dict[int, list[IndexSpan]] = {};
    for key in sorted(pending.keys()) {
        chunk = key % 4096;
        batch = key // 4096;
        run = pending[key];
        if chunk >= chunk_count {
            continue;
        }
        span = IndexSpan(chunk=chunk, first=len(lists.chunks[chunk]) // 2, count=len(run) // 2);
        lists.chunks[chunk].extend(run);
        if batch not in added {
            added[batch] = [];
        }
        added[batch].append(span);
        if batch not in lists.spans {
            lists.spans[batch] = [];
        }
        lists.spans[batch].append(span);
    }
    return added;
}

"""Pack one face's vertices into `out` from byte `offset`. `light_x`,
`light_y` place its lightmap in an `atlas_size` atlas; `layer` is the Q1/Q2
light style layer stride in atlas units. With `sprites` (Q3), a quad also
carries what autosprite and autosprite2 need. Q3 vertex colours go through
the overbright shift; their alpha stays raw for alphaGen vertex. Faces
without colours take white at `alpha` (Q2's translucent surfaces)."""
def pack_world_face(
    out: bytearray,
    offset: int,
    face: Face,
    light_x: int,
    light_y: int,
    atlas_size: int,
    layer: float,
    flags: int,
    fog: int,
    overbright: bool,
    sprites: bool = False,
    alpha: int = 255
) {
    count = len(face.vertices);
    inverse_atlas = 1.0 / float(atlas_size);
    lit = face.light_offset >= 0 and len(face.light_uv) >= count * 2;
    textured = len(face.uv) >= count * 2;
    colored = len(face.colors) >= count * 4;
    styles = [255, 255, 255, 255];
    for k in range(min(4, len(face.styles))) {
        styles[k] = max(0, min(254, face.styles[k]));
    }
    quad = sprites and count == 4;
    if quad {
        flags = flags | SURFACE_QUAD;
    }
    # Autosprite: the quad's centre and radius (tr_shade_calc.c
    # AutospriteDeform). Autosprite2: each vertex's short edge, by its
    # midpoint and half length, and which end of that edge it is.
    middle = Vec3();
    radius = 0.0;
    ends: list[Vec3] = [];
    halves: list[float] = [];
    edge_of = [0, 0, 0, 0];
    role_of = [0, 0, 0, 0];
    if quad {
        middle = face.vertices[0].add(face.vertices[1]).add(face.vertices[2]).add(face.vertices[3]).scale(0.25);
        radius = face.vertices[0].sub(middle).length() * 0.707;
        edges = [[0, 1], [1, 2], [2, 3], [3, 0]];
        first = 0;
        for e in range(4) {
            if face.vertices[edges[e][0]].sub(face.vertices[edges[e][1]]).length()
                < face.vertices[edges[first][0]].sub(face.vertices[edges[first][1]]).length() {
                first = e;
            }
        }
        shorts = [edges[first], edges[(first + 2) % 4]];
        for k in range(2) {
            a = shorts[k][0];
            b = shorts[k][1];
            ends.append(face.vertices[a].add(face.vertices[b]).scale(0.5));
            halves.append(face.vertices[a].sub(face.vertices[b]).length() * 0.5);
            edge_of[a] = k;
            edge_of[b] = k;
            role_of[a] = 0;
            role_of[b] = 1;
        }
    }
    normal = face.normal;
    for i in range(count) {
        v = face.vertices[i];
        s = face.uv[i * 2] if textured else 0.0;
        t = face.uv[i * 2 + 1] if textured else 0.0;
        ls = 0.0;
        lt = 0.0;
        if lit {
            ls = (face.light_uv[i * 2] + float(light_x) + 0.5) * inverse_atlas;
            lt = (face.light_uv[i * 2 + 1] + float(light_y) + 0.5) * inverse_atlas;
        }
        red = 255;
        green = 255;
        blue = 255;
        opacity = alpha;
        if colored {
            shade = shift_light(overbright, face.colors[i * 4], face.colors[i * 4 + 1], face.colors[i * 4 + 2]);
            red = shade[0];
            green = shade[1];
            blue = shade[2];
            opacity = face.colors[i * 4 + 3];
        }
        # Aux A: the style layer stride, or the quad's centre and radius.
        # Aux B: this vertex's short-edge midpoint and half length (the
        # other midpoint is the centre's mirror of it).
        ax = layer;
        ay = 0.0;
        az = 0.0;
        aw = 0.0;
        mx = 0.0;
        my = 0.0;
        mz = 0.0;
        mw = 0.0;
        corner = 0;
        edge_code = 0;
        if quad {
            end = ends[edge_of[i]];
            ax = middle.x;
            ay = middle.y;
            az = middle.z;
            aw = radius;
            mx = end.x;
            my = end.y;
            mz = end.z;
            mw = halves[edge_of[i]];
            corner = i;
            edge_code = edge_of[i] * 2 + role_of[i] + 4;
        }
        struct.pack_into(
            "<fffffffBBBBfffBBBBBBBBffffffff",
            out,
            offset + i * WORLD_VERTEX_STRIDE,
            v.x, v.y, v.z,
            s, t,
            ls, lt,
            red, green, blue, opacity,
            normal.x, normal.y, normal.z,
            flags, corner, fog + 1, edge_code,
            styles[0], styles[1], styles[2], styles[3],
            ax, ay, az, aw,
            mx, my, mz, mw
        );
    }
}

"""Index buffers for one set of index lists, one per chunk, grown as needed
and refilled when the lists change."""
obj ChunkIndices {
    has ids: list[int] = [],
        capacities: list[int] = [];

    def fill(lists: IndexLists) {
        rlDisableVertexArray();
        while len(self.ids) < len(lists.chunks) {
            self.ids.append(0);
            self.capacities.append(0);
        }
        for c in range(len(lists.chunks)) {
            data = bytes(lists.chunks[c]);
            if not data {
                continue;
            }
            if len(data) > self.capacities[c] {
                if self.ids[c] != 0 {
                    rlUnloadVertexBuffer(u32(self.ids[c]));
                }
                capacity = max(len(data), self.capacities[c] * 2);
                self.ids[c] = int(rlLoadVertexBufferElement(bytes(capacity), i32(capacity), True));
                self.capacities[c] = capacity;
            }
            rlUpdateVertexBufferElements(u32(self.ids[c]), data, i32(len(data)), i32(0));
        }
    }

    """Bind chunk `c`'s index buffer to the vertex array bound now."""
    def bind(c: int) {
        rlEnableVertexBufferElement(u32(self.ids[c]));
    }

    def close() {
        rlDisableVertexArray();
        for id in self.ids {
            if id != 0 {
                rlUnloadVertexBuffer(u32(id));
            }
        }
        self.ids = [];
        self.capacities = [];
    }
}

"""The index lists of one visible face set, kept while the set is reused (the
main view's and a portal view's sets alternate each frame), and the batches
with faces in it, by pass (`shown`)."""
obj VisibleIndices {
    has faces: list[int] = [],
        lists: IndexLists = IndexLists(),
        buffers: ChunkIndices = ChunkIndices(),
        portal_faces: dict[int, list[int]] = {},
        shown: dict[int, list[int]] = {},
        used: int = 0;
}

"""A group of brush model faces that share one placement this frame: static
models together (by entity frame, for animated textures), each moving
model alone, and faces lit per frame (`lamp`) one by one. `lead` is a
member face whose placement, frame and light stand for the group; `shown`
lists its batches by pass."""
obj BrushGroup {
    has lead: int = 0,
        faces: list[int] = [],
        spans: dict[int, list[IndexSpan]] = {},
        shown: dict[int, list[int]] = {},
        lamp: bool = False,
        tint: list[float] = [1.0, 1.0, 1.0, 1.0],
        tint_packed: bytes = b"";
    # The lead face's placement as the physics tick in progress began (its
    # motion as the pose's position), to draw a moving group between ticks.
    has was: TickPose = TickPose(),
        was_turn: Basis | None = None;

    """A physics tick begins: keep the lead face's placement."""
    def hold(lead: Face, tick: int) {
        self.was.capture(lead.motion, 0.0, 0.0, tick);
        self.was_turn = lead.turn;
    }

    """Where to draw the group: its lead face's placement `blend` of the way
    through the last physics tick."""
    def placed(lead: Face, blend: TickBlend) -> BrushPlacement {
        share = blend.share(self.was, lead.motion);
        if share >= 1.0 {
            return BrushPlacement(motion=lead.motion, turn=lead.turn);
        }
        return BrushPlacement(
            motion=self.was.pos.lerp(lead.motion, share),
            turn=blend_basis(self.was_turn, lead.turn, share)
        );
    }
}

"""A brush group's placement this frame: turned about its pivot, then moved."""
obj BrushPlacement {
    has motion: Vec3,
        turn: Basis | None = None;
}

"""One brush model's faces."""
obj BrushModel {
    has faces: list[int] = [];
}

# ---------------------------------------------------------------------------
# Shaders. Vertex inputs sit at fixed locations so every program shares the
# chunks' vertex arrays.

glob WORLD_INPUTS: str = "#version 330\nlayout(location=0) in vec3 inPosition; layout(location=1) in vec2 inTexCoord; layout(location=2) in vec2 inLightCoord; layout(location=3) in vec4 inColor; layout(location=4) in vec3 inNormal; layout(location=5) in vec4 inInfo; layout(location=6) in vec4 inStyles; layout(location=7) in vec4 inAuxA; layout(location=8) in vec4 inAuxB;\nuniform mat4 viewProjection; uniform mat4 model;\n";

# Q1/Q2 lightmapped surfaces in one pass (R_BuildLightMap, R_AddDynamicLights,
# fullbright texels): each light style layer scaled by its current value
# (d_lightstylevalue) and doubled, clamped as the 8-bit lightmap was; palette
# fullbrights (texture alpha 0) unlit. Dynamic lights add to the light before
# it is doubled, per pixel where the originals add per lightmap sample: a
# light's radius less its distance from the surface's plane is the most it
# gives there, falling off one for one with the distance across the plane,
# and nothing once that is below its minimum light (Q1 dl->minlight, Q2
# DLIGHT_CUTOFF). They light either side of a surface, as in Quake.
glob LIT_VS: str = WORLD_INPUTS
    + "uniform vec4 lightStyles[64]; out vec2 uv; out vec2 luv; out vec3 worldPosition; flat out vec4 styleScale; flat out float layerStride; flat out float lit;\n"
    + "float styleValue(float s){ int i=int(s+0.5); return lightStyles[i>>2][i&3]; }\n"
    + "void main(){ vec4 w=model*vec4(inPosition,1.0); worldPosition=w.xyz; uv=inTexCoord; luv=inLightCoord; styleScale=vec4(styleValue(inStyles.x),styleValue(inStyles.y),styleValue(inStyles.z),styleValue(inStyles.w)); layerStride=inAuxA.x; lit=mod(floor(inInfo.x+0.5),2.0); gl_Position=viewProjection*w; }\n",
     LIT_FS: str = "#version 330\nin vec2 uv; in vec2 luv; in vec3 worldPosition; flat in vec4 styleScale; flat in float layerStride; flat in float lit; out vec4 finalColor;\n"
    + "uniform sampler2D colorMap; uniform sampler2D lightMap; uniform vec4 flashPosition[8]; uniform vec4 flashColor[8];\n"
    + "void main(){ vec4 base=texture(colorMap,uv); vec3 c=base.rgb; if(lit>0.5){ vec3 light=texture(lightMap,luv).rgb*styleScale.x;"
    + " if(styleScale.y>0.0) light+=texture(lightMap,luv+vec2(layerStride,0.0)).rgb*styleScale.y;"
    + " if(styleScale.z>0.0) light+=texture(lightMap,luv+vec2(layerStride*2.0,0.0)).rgb*styleScale.z;"
    + " if(styleScale.w>0.0) light+=texture(lightMap,luv+vec2(layerStride*3.0,0.0)).rgb*styleScale.w;"
    + " vec3 n=normalize(cross(dFdx(worldPosition),dFdy(worldPosition)));"
    + " for(int i=0;i<8;i++){ if(flashPosition[i].w<=0.0) continue; vec3 delta=flashPosition[i].xyz-worldPosition; float plane=dot(delta,n); float rad=flashPosition[i].w-abs(plane); float cut=flashColor[i].w;"
    + " if(rad<cut) continue; float across=length(delta-n*plane); if(across<rad-cut) light+=flashColor[i].rgb*((rad-across)/255.0); }"
    + " c=base.rgb*min(light*2.0,vec3(1.0)); } c=mix(c,base.rgb,1.0-base.a); finalColor=vec4(c,1.0); }\n";

# Q1/Q2 liquids and translucent faces, unlit (gl_warp.c EmitWaterPolys: 8
# texels of sine sway at one radian a second; Q2 SURF_FLOWING scrolls).
glob WARP_VS: str = WORLD_INPUTS
    + "out vec2 uv; out vec4 color;\n"
    + "void main(){ uv=inTexCoord; color=inColor; gl_Position=viewProjection*(model*vec4(inPosition,1.0)); }\n",
     WARP_FS: str = "#version 330\nin vec2 uv; in vec4 color; out vec4 finalColor; uniform sampler2D colorMap; uniform float warpTime; uniform vec2 warpSize; uniform float warpScroll; uniform float warpAmount;\n"
    + "void main(){ vec2 st=uv*warpSize; vec2 w=warpAmount>0.5?vec2(st.x+8.0*sin(st.y*0.125+warpTime)+warpScroll, st.y+8.0*sin(st.x*0.125+warpTime))/warpSize:uv; finalColor=texture(colorMap,w)*color; }\n";

# gl_warp.c EmitSkyPolys: each vertex's direction from the eye onto a
# flattened sphere; the back layer scrolls at 8 units a second and the
# masked front layer at 16 over it.
glob SKY_VS: str = WORLD_INPUTS
    + "uniform vec3 eye; uniform float skyTime; out vec2 backUV; out vec2 frontUV;\n"
    + "void main(){ vec4 w=model*vec4(inPosition,1.0); vec3 d=w.xyz-eye; d.z*=3.0; float scale=6.0*63.0/max(0.001,length(d)); backUV=(vec2(skyTime*8.0)+d.xy*scale)/128.0; frontUV=(vec2(skyTime*16.0)+d.xy*scale)/128.0; gl_Position=viewProjection*w; }\n",
     SKY_FS: str = "#version 330\nin vec2 backUV; in vec2 frontUV; out vec4 finalColor; uniform sampler2D skyBack; uniform sampler2D skyFront;\n"
    + "void main(){ vec4 back=texture(skyBack,backUV); vec4 front=texture(skyFront,frontUV); finalColor=vec4(mix(back.rgb,front.rgb,front.a),1.0); }\n";

# Q3 single-pass surfaces: texture times lightmap (or vertex light), the
# shader's alphaFunc, and dynamic lights per pixel on all but emitters.
glob BASE_VS: str = WORLD_INPUTS
    + "uniform vec4 tint; out vec2 uv; out vec2 luv; out vec4 color; out vec3 worldPosition; flat out float flags;\n"
    + "void main(){ int f=int(inInfo.x+0.5); vec4 w=model*vec4(inPosition,1.0); worldPosition=w.xyz; uv=inTexCoord; luv=inLightCoord; flags=inInfo.x; color=(f&16)!=0?vec4(inColor.rgb,1.0):tint; gl_Position=viewProjection*w; }\n",
     BASE_FS: str = "#version 330\nin vec2 uv; in vec2 luv; in vec4 color; in vec3 worldPosition; flat in float flags; out vec4 finalColor;\n"
    + "uniform sampler2D colorMap; uniform sampler2D lightMap; uniform vec4 flashPosition[8]; uniform vec4 flashColor[8];\n"
    + "void main(){ int f=int(flags+0.5); vec4 base=texture(colorMap,uv); int mode=(f>>1)&3; if((mode==1&&base.a<=0.0)||(mode==2&&base.a<0.5)||(mode==3&&base.a>=0.5)) discard;"
    + " vec3 lighting=((f&1)!=0?texture(lightMap,luv).rgb:vec3(1.0))*color.rgb;"
    + " if((f&8)==0){ vec3 n=normalize(cross(dFdx(worldPosition),dFdy(worldPosition))); for(int i=0;i<8;i++){ if(flashPosition[i].w<=0.0) continue; vec3 delta=flashPosition[i].xyz-worldPosition; float distance=length(delta); float a=max(0.0,1.0-distance/flashPosition[i].w); lighting+=flashColor[i].rgb*a*a*max(0.0,dot(n,delta/max(distance,0.001))); }}"
    + " finalColor=vec4(base.rgb*lighting,color.a); }\n";

# Shared GLSL: Q3 waveforms (tr_shade_calc.c EvalWaveForm, with this
# renderer's noise) and fog (RB_CalcFogTexCoords, R_FogFactor).
glob WORLD_WAVE_GLSL: str = "float waveAt(float func, float base, float amplitude, float x){ float f=fract(x); float v=0.0;"
    + " if(func<0.5) v=sin(f*6.283185307); else if(func<1.5) v=f<0.25?4.0*f:(f<0.75?2.0-4.0*f:4.0*f-4.0); else if(func<2.5) v=f<0.5?1.0:-1.0;"
    + " else if(func<3.5) v=f; else if(func<4.5) v=1.0-f; else v=sin(x*12.9898)*0.5+sin(x*78.233)*0.5; return base+v*amplitude; }\n",
     WORLD_FOG_GLSL: str = "uniform vec3 eye; uniform vec3 viewForward; uniform vec4 fogPlane[16]; uniform vec4 fogColor[16];\n"
    + "vec2 fogCoords(int i, vec3 p){ float s=(dot(viewForward,p)-dot(viewForward,eye))/(fogColor[i].w*8.0)+1.0/512.0; if(fogPlane[i].w>=1.0e8) return vec2(s,31.0/32.0);"
    + " float eyeT=dot(fogPlane[i].xyz,eye)+fogPlane[i].w; float t=dot(fogPlane[i].xyz,p)+fogPlane[i].w;"
    + " if(eyeT<0.0) t=t<1.0?1.0/32.0:1.0/32.0+30.0/32.0*t/(t-eyeT); else t=t<0.0?1.0/32.0:31.0/32.0; return vec2(s,t); }\n"
    + "float fogDensity(vec2 st){ float s=st.x-1.0/512.0; float t=st.y; if(s<0.0||t<1.0/32.0) return 0.0; if(t<31.0/32.0) s*=(t-1.0/32.0)/(30.0/32.0); s=min(1.0,s*8.0); return sqrt(floor(s*255.0)/255.0); }\n";

# Q3 shader stages (tr_shade.c RB_StageIteratorGeneric, tr_shade_calc.c):
# deformVertexes, tcGen, the tcMods folded into affine steps split at each
# turb, rgbGen/alphaGen, and adjustColorsForFog, all per vertex.
glob STAGE_VS: str = WORLD_INPUTS
    + "uniform float time; uniform int deformCount; uniform vec4 deformInfo[4]; uniform vec4 deformWave[4]; uniform vec4 deformVector[4];\n"
    + "uniform int tcGen; uniform vec3 tcVectorS; uniform vec3 tcVectorT; uniform int tcSteps; uniform vec4 tcRowS[4]; uniform vec4 tcRowT[4]; uniform vec4 tcTurb[4]; uniform int turbFromNormal;\n"
    + "uniform vec4 tint; uniform int rgbMode; uniform int alphaMode; uniform float portalRange; uniform int fogMode; uniform int lightmapStage;\n"
    + WORLD_FOG_GLSL
    + WORLD_WAVE_GLSL
    + "out vec2 st; out vec4 shade;\n"
    + "void main(){ int f=int(inInfo.x+0.5); vec3 p=(model*vec4(inPosition,1.0)).xyz; vec2 base=inTexCoord; vec3 n=inNormal; bool quad=(f&32)!=0;\n"
    + " for(int i=0;i<4;i++){ if(i>=deformCount) break; float kind=deformInfo[i].x;\n"
    + "  if(kind<1.5){ float off=(p.x+p.y+p.z)*deformInfo[i].z; p+=n*waveAt(deformInfo[i].y,deformWave[i].x,deformWave[i].y,deformWave[i].z+off+time*deformWave[i].w); }\n"
    + "  else if(kind<2.5){ p+=deformVector[i].xyz; }\n"
    + "  else if(kind<3.5){ p+=n*(sin(0.785398163*base.x*deformVector[i].x+time*deformVector[i].z)*deformVector[i].y); }\n"
    + "  else if(kind<4.5&&quad){ vec3 mid=(model*vec4(inAuxA.xyz,1.0)).xyz; vec3 fw=normalize(mid-eye); vec3 right=cross(fw,vec3(0.0,0.0,1.0)); if(length(right)<0.001) right=vec3(1.0,0.0,0.0); right=normalize(right); vec3 up=normalize(cross(right,fw));"
    + " vec3 left=right*-inAuxA.w; vec3 upward=up*inAuxA.w; int c=int(inInfo.y+0.5);"
    + " if(c==0){ p=mid+left+upward; base=vec2(0.0,0.0); } else if(c==1){ p=mid-left+upward; base=vec2(1.0,0.0); } else if(c==2){ p=mid-left-upward; base=vec2(1.0,1.0); } else { p=mid+left-upward; base=vec2(0.0,1.0); } }\n"
    + "  else if(kind<5.5&&quad){ int code=int(inInfo.w+0.5)-4; int k=code/2; int role=code-k*2; vec3 mid=(model*vec4(inAuxA.xyz,1.0)).xyz; vec3 own=(model*vec4(inAuxB.xyz,1.0)).xyz; vec3 other=mid*2.0-own;"
    + " vec3 axis=k==0?other-own:own-other; vec3 across=normalize(cross(axis,mid-eye)); float d=dot(p-own,across); if(role==1) d=-d; float sgn=d>=0.0?1.0:-1.0; p=role==0?own+across*(inAuxB.w*sgn):own-across*(inAuxB.w*sgn); }\n"
    + " }\n"
    + " vec2 c2=base; if(tcGen==1) c2=inLightCoord; else if(tcGen==2){ vec3 viewer=normalize(eye-p); vec3 r=n*(2.0*dot(n,viewer))-viewer; c2=vec2(0.5+r.y*0.5,0.5-r.z*0.5); } else if(tcGen==3) c2=vec2(dot(p,tcVectorS),dot(p,tcVectorT));\n"
    + " vec3 tp=turbFromNormal==1?inNormal:p;\n"
    + " for(int i=0;i<4;i++){ if(i>=tcSteps) break; c2=vec2(dot(tcRowS[i].xyz,vec3(c2,1.0)),dot(tcRowT[i].xyz,vec3(c2,1.0)));"
    + " if(tcTurb[i].x>0.5){ c2.x+=sin(((tp.x+tp.z)/128.0*0.125+tcTurb[i].z)*6.283185307)*tcTurb[i].y; c2.y+=sin((tp.y/128.0*0.125+tcTurb[i].z)*6.283185307)*tcTurb[i].y; } }\n"
    + " vec4 c=tint; if(rgbMode==1) c.rgb=inColor.rgb; if(alphaMode==1) c.a=inColor.a; else if(alphaMode==2) c.a=clamp(length(p-eye)/portalRange,0.0,1.0);"
    + " else if(alphaMode==3){ vec3 toward=normalize(vec3(-960.0,1980.0,96.0)-p); vec3 r=n*(2.0*dot(n,toward))-toward; float shine=max(0.0,dot(r,normalize(eye-p))); c.a=min(1.0,shine*shine*shine*shine); }\n"
    + " int fi=int(inInfo.z+0.5)-1; if(fogMode>0&&fi>=0&&fi<16){ float clear=1.0-fogDensity(fogCoords(fi,p)); if(fogMode!=2) c.rgb*=clear; if(fogMode!=1) c.a*=clear; }\n"
    + " st=c2; shade=c; gl_Position=viewProjection*vec4(p,1.0); if(lightmapStage==1&&(f&1)==0) gl_Position=vec4(0.0,0.0,-2.0,1.0); }\n",
     STAGE_FS: str = "#version 330\nin vec2 st; in vec4 shade; out vec4 finalColor; uniform sampler2D stageMap;\nvoid main(){ finalColor=texture(stageMap,st)*shade; }\n";

# tr_shade.c RB_FogPass: the fog colour through the fog image's density.
glob FOG_VS: str = WORLD_INPUTS
    + WORLD_FOG_GLSL
    + "out vec2 st; out vec4 shade;\n"
    + "void main(){ vec3 p=(model*vec4(inPosition,1.0)).xyz; int fi=int(inInfo.z+0.5)-1; if(fi<0||fi>=16){ st=vec2(0.0); shade=vec4(0.0); gl_Position=vec4(0.0,0.0,-2.0,1.0); return; }"
    + " st=fogCoords(fi,p); shade=vec4(fogColor[fi].rgb,1.0); gl_Position=viewProjection*vec4(p,1.0); }\n",
     FOG_FS: str = "#version 330\nin vec2 st; in vec4 shade; out vec4 finalColor; uniform sampler2D fogMap;\nvoid main(){ finalColor=texture(fogMap,st)*shade; }\n";

"""Set a vec3 uniform of `program`."""
def set_uniform_vec3(program: GpuProgram, name: str, value: Vec3) {
    location = program.uniform(name);
    if location >= 0 {
        rlSetUniform(i32(location), struct.pack("<fff", value.x, value.y, value.z), i32(UNIFORM_VEC3), i32(1));
    }
}

"""Set a vec2 uniform of `program`."""
def set_uniform_vec2(program: GpuProgram, name: str, x: float, y: float) {
    location = program.uniform(name);
    if location >= 0 {
        rlSetUniform(i32(location), struct.pack("<ff", x, y), i32(UNIFORM_VEC2), i32(1));
    }
}

"""A Q3 waveform's function as the shaders number it."""
def wave_code(func: str) -> float {
    names = ["sin", "triangle", "square", "sawtooth", "inversesawtooth", "noise"];
    for i in range(len(names)) {
        if names[i] == func {
            return float(i);
        }
    }
    return 0.0;
}
