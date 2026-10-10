"""One renderer for adapted vertex-animated models, with explicit GPU ownership.

Models animate on the GPU, as modern ports do (ironwail's alias shader,
ioquake3 opengl2's vertex animation): at upload every surface's keyframes go
into one RGBA32F texture (position, and the normal packed into w) and every
triangle corner into a static vertex buffer holding its keyframe texel and
texture coordinates. Per draw the CPU sends only uniforms: the two frames and
their blend, the model's placement, its lighting and tint. The vertex shader
lerps position and normal, pushes a powerup shell out along the normal, maps
environment stages and computes the light grid (or Q1/Q2 shade) colour; the
fragment shader multiplies the skin by it. QP_RENDER_LEGACY=1 keeps the old
CPU pose and immediate-mode drawing for comparison."""
import math;
import os;
import struct;
import from ..math.orientation { Basis, model_basis }
import from ..formats.animated {
    AnimatedModel,
    AnimatedSurface,
    ModelStage,
    Deform,
    pose,
    stage_frame,
    frame_normals,
    SHADER_CULL_FRONT,
    SHADER_CULL_BACK,
    SHADER_CULL_NONE
}
import from ..formats.anorms { quake_vertex_normal }
import from ..formats.bsp { Texture }
import from ..math.vec3 { Vec3, forward_from, right_from }
import from ..world.lighting { Lighting, Illumination }
import from .gpu {
    GpuMesh,
    GpuProgram,
    VertexAttribute,
    GL_FLOAT,
    GL_UNSIGNED_BYTE,
    view_projection,
    upload_float_texture
}
import from .quake {
    QuakeRenderer,
    rlLoadTexture,
    rlUnloadTexture,
    rlTextureParameters,
    rlSetTexture,
    rlBegin,
    rlEnd,
    rlTexCoord2f,
    rlVertex3f,
    rlColor4ub,
    rlDrawRenderBatchActive,
    BeginBlendMode,
    EndBlendMode,
    rlDisableDepthMask,
    rlEnableDepthMask,
    rlDisableBackfaceCulling,
    rlEnableBackfaceCulling,
    fog_coords,
    packed_tcmods,
    apply_tcmods,
    stage_color,
    stage_blend,
    packed_deforms
}
import from .world_mesh { WORLD_WAVE_GLSL, SHADER_DEFORM_GLSL, SpriteQuad, sprite_quad }
import from ..formats.bsp { FogVolume }
import from vendor.raylib {
    def rlSetBlendFactors(src: i32, dst: i32, equation: i32) -> None;  def rlActiveTextureSlot(
        slot: i32
    ) -> None;  def rlEnableTexture(id: u32) -> None;  def rlDisableTexture -> None;  def rlEnableShader(
        id: u32
    ) -> None;  def rlSetCullFace(mode: i32) -> None;
}

# Keyframe texels per row of a model's frame texture: a surface's frames are
# laid out one after another and wrap at this width (GL_MAX_TEXTURE_SIZE is
# at least 4096 on every GL 3.3 target raylib supports).
glob MODEL_FRAME_ROW: int = 4096;

# Octahedral normal packing: 12 bits per axis, both held exactly in one float.
glob MODEL_NORMAL_STEPS: int = 4095;

"""Every corner reads its two keyframes from the frame texture, lerps them
(position, and the normal when the format has one), runs the shader's
deformVertexes in model space (world_mesh.jac SHADER_DEFORM_GLSL: powerup
shells pushed out along the normal, waving flags and wings, sprites turned to
the viewer) and places the result with the model's axes. `quad` marks the
corners of autosprite surfaces (corner number, the other vertex of its short
edge, its sprite_quad code plus 1, and whether the surface is made of quads):
their quads are read whole from the frame texture each frame. u_draw: [0..2]
the forward/left/up axes with the origin in w, [3] frame A, frame B and blend,
[4] ambient and whether it glows (Q2 RF_GLOW, lighting.jac
glow_pulse, directed light following ambient), [5] directed and opacity,
[6] light direction (in world space) and the share of directed light on
faces turned away, [7] the eye in model space and the time. u_stage: the
texture coordinates (0 the model's, 1 tcGen environment, 2 tcGen vector by
u_tcv), the colour mode (0 the stage's colour, u_color, its rgbGen and
alphaGen at this time; 1 lit, rgbGen lightingDiffuse with u_color's alpha;
2 fog), whether the skin's alpha marks fullbright texels (Q1) rather than
opacity, and the number of texture steps. u_gen: whether alpha is alphaGen
lightingSpecular (tr_shade_calc.c RB_CalcSpecularAlpha, in model space as
there, with its fixed light origin) and the stage's alphaFunc (1 GT0, 2
GE128, 3 LT128), which the fragment shader tests. The steps
are the stage's tcMods at this time folded by quake.jac tcmod_steps: each an
affine map (u_tcS, u_tcT rows) then maybe a turb (u_turb: on, amplitude,
phase), which tr_shade_calc.c RB_CalcTurbulentTexCoords takes from the
model-space position. u_fog: tr_main.c fog texture coordinates as quake.jac
fog_coords computes them, and the fog colour."""
glob MODEL_VERTEX_SHADER: str = "#version 330\nin vec4 corner; in vec4 quad;\n"
    + "uniform mat4 mvp; uniform sampler2D frames; uniform vec4 u_draw[8]; uniform vec4 u_stage; uniform vec4 u_gen; uniform vec4 u_color; uniform vec4 u_tcv[2]; uniform vec4 u_tcS[4]; uniform vec4 u_tcT[4]; uniform vec4 u_turb[4]; uniform vec4 u_fog[4];\n"
    + WORLD_WAVE_GLSL
    + SHADER_DEFORM_GLSL
    + "out vec2 uv; out vec4 tint;\n"
    + "vec4 keyframe(float texel){ int t=int(texel+0.5); return texelFetch(frames, ivec2(t&4095, t>>12), 0); }\n"
    + "vec3 posed(float texel){ return mix(keyframe(texel+u_draw[3].x*corner.y).xyz,keyframe(texel+u_draw[3].y*corner.y).xyz,u_draw[3].z); }\n"
    + "vec3 unpackNormal(float code){ float hi=floor(code/4096.0); vec2 p=vec2(hi, code-hi*4096.0)*(2.0/4095.0)-1.0; vec3 n=vec3(p, 1.0-abs(p.x)-abs(p.y)); float t=max(-n.z,0.0); n.x+=n.x>=0.0?-t:t; n.y+=n.y>=0.0?-t:t; return normalize(n); }\n"
    + "void main(){\n"
    + " vec4 a=keyframe(corner.x+u_draw[3].x*corner.y); vec4 b=keyframe(corner.x+u_draw[3].y*corner.y); float f=u_draw[3].z;\n"
    + " vec3 local=mix(a.xyz,b.xyz,f); bool shaded=a.w>=0.0&&b.w>=0.0; vec3 n=vec3(0.0,0.0,1.0);\n"
    + " if(shaded){ n=normalize(mix(unpackNormal(a.w),unpackNormal(b.w),f)); }\n"
    + " mat3 axes=mat3(u_draw[0].xyz,u_draw[1].xyz,u_draw[2].xyz); vec2 st=corner.zw;\n"
    + " if(deformCount>0){ vec3 right; vec3 up; vec3 fw; viewAxes(mvp,right,up,fw); right=right*axes; up=up*axes; fw=fw*axes;\n"
    + "  vec4 q=vec4(0.0); vec4 e=vec4(0.0); int c=-1; int code=-1;\n"
    + "  if(quad.w>0.5){ c=int(quad.x+0.5); float first=corner.x-quad.x; vec3 v[4]; for(int k=0;k<4;k++){ v[k]=posed(first+float(k)); }\n"
    + "   vec3 mid=(v[0]+v[1]+v[2]+v[3])*0.25; q=vec4(mid,length(v[0]-mid)*0.707); int partner=int(quad.y+0.5); e=vec4((v[c]+v[partner])*0.5,length(v[c]-v[partner])*0.5); code=int(quad.z+0.5)-1; }\n"
    + "  deformVertex(local,n,st,u_draw[7].w,q,e,c,code,right,up,fw); }\n"
    + " vec3 world=vec3(u_draw[0].w,u_draw[1].w,u_draw[2].w)+axes*local;\n"
    + " gl_Position=mvp*vec4(world,1.0);\n"
    + " uv=st; vec3 viewer=normalize(u_draw[7].xyz-local);\n"
    + " if(u_stage.x>1.5){ uv=vec2(dot(local,u_tcv[0].xyz),dot(local,u_tcv[1].xyz)); }\n"
    + " else if(u_stage.x>0.5){ vec3 r=n*(2.0*dot(n,viewer))-viewer; uv=vec2(0.5+r.y*0.5,0.5-r.z*0.5); }\n"
    + " int steps=int(u_stage.w+0.5);\n"
    + " for(int i=0;i<4;i++){ if(i>=steps) break; uv=vec2(dot(u_tcS[i].xyz,vec3(uv,1.0)),dot(u_tcT[i].xyz,vec3(uv,1.0)));\n"
    + "  if(u_turb[i].x>0.5){ uv.x+=sin(((local.x+local.z)/128.0*0.125+u_turb[i].z)*6.283185307)*u_turb[i].y; uv.y+=sin((local.y/128.0*0.125+u_turb[i].z)*6.283185307)*u_turb[i].y; } }\n"
    + " tint=vec4(u_color.rgb,u_color.a*u_draw[5].w);\n"
    + " if(u_stage.y>1.5){ float t=31.0/32.0; if(u_fog[2].y>0.5){ float depth=dot(u_fog[1].xyz,world)+u_fog[1].w; float eyeT=u_fog[2].x;\n"
    + "   if(eyeT<0.0){ t=depth<1.0?1.0/32.0:1.0/32.0+30.0/32.0*depth/(depth-eyeT); } else { t=depth<0.0?1.0/32.0:31.0/32.0; } }\n"
    + "   uv=vec2(dot(u_fog[0].xyz,world)+u_fog[0].w,t); tint=u_fog[3]; }\n"
    + " else { if(u_stage.y>0.5){ float d=shaded?dot(axes*n,u_draw[6].xyz):0.5; if(d<0.0) d*=u_draw[6].w; vec3 amb=u_draw[4].xyz; vec3 dir=u_draw[5].xyz;\n"
    + "   if(u_draw[4].w>0.5){ amb=max(amb*0.8,amb+0.2*sin(u_draw[7].w*7.0)); dir=amb; }\n"
    + "   tint.rgb=clamp(amb+dir*d,0.0,1.0); }\n"
    + "  if(u_gen.x>0.5){ vec3 toward=normalize(vec3(-960.0,1980.0,96.0)-local); vec3 r=n*(2.0*dot(n,toward))-toward; float l=max(0.0,dot(r,viewer)); tint.a=min(1.0,l*l*l*l)*u_draw[5].w; } }\n"
    + "}\n",
     MODEL_FRAGMENT_SHADER: str = "#version 330\nin vec2 uv; in vec4 tint; uniform sampler2D skin; uniform vec4 u_stage; uniform vec4 u_gen; out vec4 finalColor;\n"
    + "void main(){ vec4 t=texture(skin,uv); vec4 c=u_stage.z>0.5?vec4(mix(t.rgb,t.rgb*tint.rgb,t.a),tint.a):t*tint;\n"
    + " int test=int(u_gen.y+0.5); if((test==1&&c.a<=0.0)||(test==2&&c.a<0.5)||(test==3&&c.a>=0.5)) discard; finalColor=c; }\n";

# The texture steps of a stage without tcMods: one identity map.
glob MODEL_PLAIN_STEPS: list[bytes] = [
    b"\x00\x00\x80?\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
    b"\x00\x00\x00\x00\x00\x00\x80?\x00\x00\x00\x00\x00\x00\x00\x00",
    b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
];

"""The shared model program, the pass state while one is open (a scene's
draws share one program bind) and the uniform scratch buffers."""
obj ModelGpu {
    has program: GpuProgram = GpuProgram(),
        corner: int = -1,
        quad: int = -1,
        loaded: bool = False,
        checked: bool = False,
        legacy: bool = False,
        active: bool = False,
        blend: int = -1,
        cull: int = 0,
        params: bytearray = bytearray(128),
        stage: bytearray = bytearray(16),
        fog: bytearray = bytearray(64);
}

glob MODEL_GPU: ModelGpu = ModelGpu();

"""QP_RENDER_LEGACY=1: pose on the CPU and draw through immediate mode."""
def models_legacy -> bool {
    gpu = MODEL_GPU;
    if not gpu.checked {
        gpu.legacy = os.getenv("QP_RENDER_LEGACY", "") == "1";
        gpu.checked = True;
    }
    return gpu.legacy;
}

def model_program -> ModelGpu {
    gpu = MODEL_GPU;
    if not gpu.loaded {
        gpu.program.load(MODEL_VERTEX_SHADER, MODEL_FRAGMENT_SHADER);
        gpu.corner = gpu.program.attribute("corner");
        gpu.quad = gpu.program.attribute("quad");
        if gpu.corner < 0 or gpu.quad < 0 {
            raise RuntimeError("Model shader lost a vertex attribute");
        }
        gpu.loaded = True;
    }
    return gpu;
}

"""Open a model pass: one program bind and view-projection for the draws that
follow, until end_model_pass. Draws made outside a pass open their own."""
def begin_model_pass {
    gpu = model_program();
    gpu.program.begin();
    gpu.program.set_matrix("mvp", view_projection());
    gpu.program.set_int("skin", 0);
    gpu.program.set_int("frames", 1);
    gpu.active = True;
    gpu.blend = -1;
    gpu.cull = SHADER_CULL_FRONT;
}

"""Open a model pass unless models draw the legacy way; True when opened."""
def open_model_pass -> bool {
    if models_legacy() {
        return False;
    }
    begin_model_pass();
    return True;
}

"""Close the model pass, leaving raylib's alpha blending and texture slot 0."""
def end_model_pass {
    gpu = MODEL_GPU;
    if not gpu.active {
        return;
    }
    gpu.active = False;
    gpu.program.end();
    rlActiveTextureSlot(i32(1));
    rlDisableTexture();
    rlActiveTextureSlot(i32(0));
    rlDisableTexture();
    EndBlendMode();
}

"""Switch the GL blend factors inside a pass only when they change (opaque
stages replace, GL_ONE GL_ZERO). A change flushes raylib's batch, which
unbinds every program and vertex array, so the model program and `mesh` are
bound again."""
def model_blend(gpu: ModelGpu, source: int, destination: int, mesh: GpuMesh) {
    key = source * 1024 + destination;
    if gpu.blend != key {
        rlSetBlendFactors(i32(source), i32(destination), i32(32774));
        BeginBlendMode(i32(6));
        gpu.blend = key;
        rlEnableShader(u32(gpu.program.id));
        mesh.bind();
    }
}

"""Draw the side of the triangles a shader's cull names (tr_shade.c
GL_Cull): the front, the back alone, or both."""
def model_cull(gpu: ModelGpu, cull: int) {
    if gpu.cull == cull {
        return;
    }
    if cull == SHADER_CULL_NONE {
        rlDisableBackfaceCulling();
    } else {
        rlEnableBackfaceCulling();
        rlSetCullFace(i32(0 if cull == SHADER_CULL_BACK else 1));
    }
    gpu.cull = cull;
}

"""Pack a unit normal into one float: octahedral coordinates, 12 bits each.
-1 marks a vertex without a normal."""
def model_normal_code(n: Vec3) -> float {
    total = abs(n.x) + abs(n.y) + abs(n.z);
    if total <= 0.0 {
        return -1.0;
    }
    x = n.x / total;
    y = n.y / total;
    if n.z < 0.0 {
        folded_x = (1.0 - abs(y)) * (1.0 if x >= 0.0 else -1.0);
        folded_y = (1.0 - abs(x)) * (1.0 if y >= 0.0 else -1.0);
        x = folded_x;
        y = folded_y;
    }
    steps = float(MODEL_NORMAL_STEPS);
    ix = int((x * 0.5 + 0.5) * steps + 0.5);
    iy = int((y * 0.5 + 0.5) * steps + 0.5);
    return float(ix * 4096 + iy);
}

"""The normal a model_normal_code holds, as the vertex shader unpacks it."""
def model_normal_decode(code: float) -> Vec3 {
    hi = math.floor(code / 4096.0);
    x = hi * 2.0 / float(MODEL_NORMAL_STEPS) - 1.0;
    y = (code - hi * 4096.0) * 2.0 / float(MODEL_NORMAL_STEPS) - 1.0;
    z = 1.0 - abs(x) - abs(y);
    t = max(-z, 0.0);
    x += -t if x >= 0.0 else t;
    y += -t if y >= 0.0 else t;
    return Vec3(x=x, y=y, z=z).normalized();
}

"""A model's keyframes as texels: surface s's frame f vertex v sits at texel
bases[s] + f * vertices[s] + v, in rows of MODEL_FRAME_ROW. `frames` is the
frame count every drawn surface has."""
obj ModelKeyframes {
    has texels: bytes = b"",
        width: int = 0,
        height: int = 0,
        bases: list[int] = [],
        vertices: list[int] = [],
        frames: int = 0;
}

def pack_model_keyframes(model: AnimatedModel) -> ModelKeyframes {
    result = ModelKeyframes(bases=[], vertices=[]);
    total = 0;
    frames = -1;
    for surface in model.surfaces {
        count = len(surface.frames[0].vertices) if surface.frames else 0;
        result.bases.append(total);
        result.vertices.append(count);
        total += count * len(surface.frames);
        if surface.indices and surface.frames {
            frames = len(surface.frames) if frames < 0 else min(frames, len(surface.frames));
        }
    }
    result.frames = max(0, frames);
    if total == 0 {
        return result;
    }
    result.width = min(total, MODEL_FRAME_ROW);
    result.height = (total + result.width - 1) // result.width;
    out = bytearray(result.width * result.height * 16);
    # The packed code of each anorms.h normal, for frames that index them.
    quake_codes = [model_normal_code(quake_vertex_normal(i)) for i in range(162)];
    for s in range(len(model.surfaces)) {
        surface = model.surfaces[s];
        count = result.vertices[s];
        offset = result.bases[s] * 16;
        for frame in surface.frames {
            if len(frame.vertices) != count {
                raise ValueError("Animation vertex count changed");
            }
            normals = frame.normals;
            shaded = len(normals) == count;
            indexed = not shaded and len(frame.normal_indices) == count;
            for i in range(count) {
                v = frame.vertices[i];
                code = -1.0;
                if shaded {
                    code = model_normal_code(normals[i]);
                } elif indexed {
                    index = int(frame.normal_indices[i]);
                    code = quake_codes[index] if index < 162 else -1.0;
                }
                struct.pack_into("<ffff", out, offset, v.x, v.y, v.z, code);
                offset += 16;
            }
        }
    }
    result.texels = bytes(out);
    return result;
}

# One corner record: four floats, then the four `quad` bytes.
glob MODEL_CORNER_STRIDE: int = 20;

"""Every surface's triangle corners as vertex records: the corner's texel in
frame 0, the surface's vertices per frame (the stride to later frames), its
texture coordinates and, on a surface of quads an autosprite or autosprite2
shader turns (surface_sprite), its `quad` bytes. Alias model file triangles
wind clockwise; the records keep the immediate path's reversed (CCW) order.
An autosprite surface's quads are triangulated as tr_surface.c
RB_AddQuadStamp does. Surface s's corners are `counts[s]` records from
`firsts[s]`."""
obj ModelCorners {
    has records: bytes = b"",
        firsts: list[int] = [],
        counts: list[int] = [];
}

"""Which sprite deform turns a surface's quads: "autosprite", "autosprite2" or
"" (tr_shade_calc.c takes every four vertices and six indices as a quad; a
surface that is not made that way is left as it is)."""
def surface_sprite(surface: AnimatedSurface) -> str {
    if not surface.stages or not surface.frames {
        return "";
    }
    count = len(surface.frames[0].vertices);
    if count == 0 or count % 4 != 0 or len(surface.indices) != (count // 4) * 6 {
        return "";
    }
    for deform in surface.stages[0].deforms {
        if deform.kind in ["autosprite", "autosprite2"] {
            return deform.kind;
        }
    }
    return "";
}

def pack_model_corners(model: AnimatedModel, keyframes: ModelKeyframes) -> ModelCorners {
    result = ModelCorners(firsts=[], counts=[]);
    total = 0;
    for s in range(len(model.surfaces)) {
        surface = model.surfaces[s];
        count = (len(surface.indices) // 3) * 3 if surface.frames else 0;
        result.firsts.append(total);
        result.counts.append(count);
        total += count;
    }
    out = bytearray(total * MODEL_CORNER_STRIDE);
    offset = 0;
    for s in range(len(model.surfaces)) {
        surface = model.surfaces[s];
        base = float(keyframes.bases[s]);
        stride = float(keyframes.vertices[s]);
        sprite = surface_sprite(surface);
        indices = surface.indices;
        shapes: list[SpriteQuad] = [];
        if sprite {
            rest = surface.frames[0].vertices;
            for q in range(len(rest) // 4) {
                order = [index - q * 4 for index in indices[q * 6:q * 6 + 6]];
                shapes.append(sprite_quad(rest[q * 4:q * 4 + 4], order));
            }
        }
        if sprite == "autosprite" {
            # RB_AddQuadStamp: corners 0 1 3 and 3 1 2 of each quad.
            indices = [];
            for q in range(len(shapes)) {
                indices.extend([q * 4, q * 4 + 1, q * 4 + 3, q * 4 + 3, q * 4 + 1, q * 4 + 2]);
            }
        }
        for triangle in range(result.counts[s] // 3) {
            for corner in [0, 2, 1] {
                index = triangle * 3 + corner;
                vertex = indices[index];
                role = [0, 0, 0, 0];
                if sprite {
                    shape = shapes[vertex // 4];
                    role = [vertex % 4, shape.partners[vertex % 4], shape.codes[vertex % 4] + 1, 1];
                }
                # A stamped quad's texture coordinates come from its corner.
                stamped = sprite == "autosprite";
                struct.pack_into(
                    "<ffffBBBB", out, offset, base + float(vertex), stride,
                    0.0 if stamped else surface.uv[index * 2], 0.0 if stamped else surface.uv[index * 2 + 1],
                    role[0], role[1], role[2], role[3]
                );
                offset += MODEL_CORNER_STRIDE;
            }
        }
    }
    result.records = bytes(out);
    return result;
}

"""One stage of a model surface on the GPU: its image frames and the stage
it came from (its tcMods and colour run per draw), with the GL state
tr_shader.c ParseStage gives it worked out once: blend factors, whether it
writes depth (unblended stages and `depthWrite` ones), which side it draws,
whether it is lit (rgbGen lightingDiffuse, and a skin without a script),
its u_gen and its shader's deformVertexes (packed once unless a move makes
them follow time). `fullbright`: the skin's alpha marks Q1 palette
fullbright texels, which light leaves alone."""
obj UploadedStage {
    has texture: int,
        surface: int,
        environment: bool,
        blend: str,
        source: ModelStage = ModelStage(),
        cull: int = 0,
        fullbright: bool = False,
        frames: list[int] = [],
        frequency: float = 0.0,
        blended: bool = False,
        gl_source: int = 1,
        gl_destination: int = 0,
        depth_write: bool = True,
        lit: bool = False,
        entity_tint: bool = False,
        tc_gen: float = 0.0,
        vectors: bytes = b"",
        gen: bytes = b"",
        fixed_tint: bytes = b"",
        deform_values: list[bytes] = [];

    """Work out the stage's GL state and fixed uniforms from its source."""
    def plan() {
        stage = self.source;
        blend = stage_blend(stage, 0);
        self.blended = blend[0] == 1;
        self.gl_source = blend[1];
        self.gl_destination = blend[2];
        self.depth_write = stage.depth_write or not self.blended;
        self.lit = stage.rgb == "diffuse";
        self.entity_tint = stage.rgb in ["entity", "oneminusentity"] or stage.alpha in ["entity", "oneminusentity"];
        self.tc_gen = 1.0 if stage.environment else (2.0 if len(stage.vectors) == 2 else 0.0);
        if len(stage.vectors) == 2 and not stage.environment {
            s = stage.vectors[0];
            t = stage.vectors[1];
            self.vectors = struct.pack("<ffffffff", s.x, s.y, s.z, 0.0, t.x, t.y, t.z, 0.0);
        }
        self.gen = struct.pack("<ffff", 1.0 if stage.alpha == "specular" else 0.0, float(stage.alpha_test), 0.0, 0.0);
        if stage.deforms and not any([deform.kind == "move" for deform in stage.deforms]) {
            self.deform_values = packed_deforms(stage.deforms, 0.0);
        }
        # A colour that neither waves nor follows the entity never changes.
        if not self.entity_tint and stage.rgb != "wave" and stage.alpha != "wave" {
            self.fixed_tint = self.tint(0.0, MODEL_ENTITY_COLOR);
        }
    }

    """u_color: the stage's colour at `seconds` (quake.jac stage_color), or
    the drawn entity's shaderRGBA for rgbGen and alphaGen entity
    (tr_shade_calc.c RB_CalcColorFromEntity and its OneMinus twin)."""
    def tint(seconds: float, entity: list[float]) -> bytes {
        if self.fixed_tint {
            return self.fixed_tint;
        }
        color = stage_color(self.source, seconds);
        if self.entity_tint {
            stage = self.source;
            if stage.rgb == "entity" {
                color = [entity[0], entity[1], entity[2], color[3]];
            } elif stage.rgb == "oneminusentity" {
                color = [1.0 - entity[0], 1.0 - entity[1], 1.0 - entity[2], color[3]];
            }
            if stage.alpha == "entity" {
                color[3] = entity[3];
            } elif stage.alpha == "oneminusentity" {
                color[3] = 1.0 - entity[3];
            }
        }
        return struct.pack("<ffff", color[0], color[1], color[2], color[3]);
    }
}

# u_gen of the fog pass: no specular alpha, no alphaFunc.
glob MODEL_NO_GEN: bytes = b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";

# A drawn entity's shaderRGBA when its caller sets none (refEntity_t is
# cleared: rgbGen entity stages draw black).
glob MODEL_ENTITY_COLOR: list[float] = [0.0, 0.0, 0.0, 0.0];

"""How far a shader's standing waves (deformVertexes wave with no frequency,
the powerup shells') push its vertices out along their normals."""
def steady_push(deforms: list[Deform]) -> float {
    push = 0.0;
    for deform in deforms {
        if deform.kind == "wave" and deform.wave.frequency == 0.0 {
            push += deform.wave.at(0.0);
        }
    }
    return push;
}

"""Upload a skin or stage image: an encoded picture from the archives, or
RGBA pixels (Q1 and Q2 skins, the white image)."""
def upload_skin(skin: Texture) -> int {
    if skin.encoded {
        return QuakeRenderer().upload_image(skin);
    }
    if len(skin.pixels) != skin.width * skin.height * 4 {
        raise ValueError("Model skin must be RGBA");
    }
    texture = int(rlLoadTexture(skin.pixels, i32(skin.width), i32(skin.height), i32(7), i32(1)));
    if texture == 0 {
        raise RuntimeError("Model skin upload failed");
    }
    return texture;
}

obj ModelRenderer {
    has model: AnimatedModel = AnimatedModel(),
        textures: list[int] = [],
        stages: list[UploadedStage] = [],
        radius: float = 0.0,
        mesh: GpuMesh = GpuMesh(),
        keyframes: int = 0,
        frame_count: int = 0,
        firsts: list[int] = [],
        counts: list[int] = [],
        opaque: list[bool] = [];

    def upload(model: AnimatedModel, skins: list[Texture]) {
        self.close();
        if len(skins) != len(model.surfaces) {
            raise ValueError("Every model surface needs a skin");
        }
        try {
            for s in range(len(skins)) {
                # A skin without a shader script is lit (tr_shader.c
                # R_FindShader's implicit rgbGen lightingDiffuse stage).
                stages = model.surfaces[s].stages;
                if not stages {
                    stages = [ModelStage(texture=skins[s], rgb="diffuse")];
                }
                for stage in stages {
                    skin = stage.texture;
                    uploaded: list[int] = [];
                    for skin in (stage.frames if stage.frames else [stage.texture]) {
                        texture = upload_skin(skin);
                        if stage.clamp {
                            # clampMap: GL_TEXTURE_WRAP_S/T to GL_CLAMP_TO_EDGE.
                            rlTextureParameters(u32(texture), i32(10242), i32(33071));
                            rlTextureParameters(u32(texture), i32(10243), i32(33071));
                        }
                        self.textures.append(texture);
                        uploaded.append(texture);
                    }
                    planned = UploadedStage(
                        texture=uploaded[0],
                        frames=uploaded,
                        frequency=stage.frequency,
                        surface=s,
                        environment=stage.environment,
                        source=stage,
                        blend=stage.blend,
                        cull=SHADER_CULL_NONE if skin.two_sided else stage.cull,
                        fullbright=skin.fullbright
                    );
                    planned.plan();
                    self.stages.append(planned);
                }
            }
            self.model = model;
            self.radius = 0.0;
            for surface in model.surfaces {
                for frame in surface.frames {
                    for vertex in frame.vertices {
                        self.radius = max(self.radius, vertex.length());
                    }
                }
            }
            if not models_legacy() {
                self.upload_frames(model);
            }
        } except Exception {
            self.close();
            raise;
        }
    }

    """Keep the model's keyframes and corners on the GPU (see the module doc)."""
    def upload_frames(model: AnimatedModel) {
        keyframes = pack_model_keyframes(model);
        self.frame_count = keyframes.frames;
        if not keyframes.texels {
            return;
        }
        corners = pack_model_corners(model, keyframes);
        self.firsts = corners.firsts;
        self.counts = corners.counts;
        self.opaque = [
            any([stage.surface == s and not stage.blended for stage in self.stages])
            for s in range(len(model.surfaces))
        ];
        gpu = model_program();
        self.keyframes = upload_float_texture(keyframes.texels, keyframes.width, keyframes.height);
        self.mesh = GpuMesh();
        self.mesh.upload(
            corners.records,
            MODEL_CORNER_STRIDE,
            [
                VertexAttribute(location=gpu.corner, components=4, kind=GL_FLOAT),
                VertexAttribute(location=gpu.quad, components=4, kind=GL_UNSIGNED_BYTE, offset=16)
            ]
        );
    }

    """Draw one pose of the model: frames `first` and `second` blended by
    `blend`, placed at `origin` turned by `yaw` (or the full `basis`), lit by
    `illumination`, and fogged, faded or drawn with an `overlay` shader
    (powerup shells, pushed out by their own deformVertexes).
    Each stage draws with its own GL state (tr_shade.c
    RB_StageIteratorGeneric); `entity_color` is the entity's shaderRGBA for
    rgbGen and alphaGen entity."""
    def draw(
        origin: Vec3,
        yaw: float,
        first: int = 0,
        second: int = 0,
        blend: float = 0.0,
        eye: Vec3 = Vec3(),
        seconds: float = 0.0,
        batched: bool = False,
        illumination: Illumination = Illumination(),
        basis: Basis | None = None,
        fog: FogVolume | None = None,
        fog_image: int = 0,
        forward: Vec3 = Vec3(x=1.0),
        alpha: float = 1.0,
        overlay: ModelRenderer | None = None,
        entity_color: list[float] = MODEL_ENTITY_COLOR
    ) {
        if not self.stages {
            return;
        }
        if self.keyframes == 0 {
            self.draw_immediate(
                origin, yaw, first, second, blend, eye, seconds, batched, illumination,
                basis, fog, fog_image, forward, alpha, overlay, entity_color
            );
            return;
        }
        if first < 0 or second < 0 or first >= self.frame_count or second >= self.frame_count {
            raise ValueError("Animation frame out of range");
        }
        fading = alpha < 0.999;
        stage_list = self.stages;
        if overlay is not None {
            stage_list = overlay.stages;
            fog = None;
        }
        axes = basis;
        if axes is None {
            cosine = math.cos(yaw);
            sine = math.sin(yaw);
            axes = Basis(
                forward=Vec3(x=cosine, y=sine), left=Vec3(x=-sine, y=cosine), up=Vec3(z=1.0)
            );
        }
        local_eye = axes.inverse(eye.sub(origin));
        gpu = MODEL_GPU;
        owned = not gpu.active;
        if owned {
            begin_model_pass();
        }
        params = gpu.params;
        struct.pack_into("<ffff", params, 0, axes.forward.x, axes.forward.y, axes.forward.z, origin.x);
        struct.pack_into("<ffff", params, 16, axes.left.x, axes.left.y, axes.left.z, origin.y);
        struct.pack_into("<ffff", params, 32, axes.up.x, axes.up.y, axes.up.z, origin.z);
        struct.pack_into(
            "<ffff", params, 48, float(first), float(second), max(0.0, min(1.0, blend)), 0.0
        );
        light = illumination.ambient;
        struct.pack_into("<ffff", params, 64, light.x, light.y, light.z, 1.0 if illumination.glow else 0.0);
        light = illumination.directed;
        struct.pack_into(
            "<ffff", params, 80, light.x, light.y, light.z,
            float(int(max(0.0, min(1.0, alpha)) * 255.0)) / 255.0
        );
        # A model-space direction (Q2's shade vector) turns with the model.
        light = illumination.direction;
        if illumination.model_space {
            struct.pack_into(
                "<ffff", params, 96,
                axes.forward.x * light.x + axes.left.x * light.y + axes.up.x * light.z,
                axes.forward.y * light.x + axes.left.y * light.y + axes.up.y * light.z,
                axes.forward.z * light.x + axes.left.z * light.y + axes.up.z * light.z,
                illumination.rear
            );
        } else {
            struct.pack_into("<ffff", params, 96, light.x, light.y, light.z, illumination.rear);
        }
        struct.pack_into("<ffff", params, 112, local_eye.x, local_eye.y, local_eye.z, seconds);
        program = gpu.program;
        program.set_vec4s("u_draw", bytes(params));
        rlActiveTextureSlot(i32(1));
        rlEnableTexture(u32(self.keyframes));
        rlActiveTextureSlot(i32(0));
        self.mesh.bind();
        fogged = fog is not None and fog_image != 0;
        for s in range(len(self.counts)) {
            count = self.counts[s];
            if count == 0 {
                continue;
            }
            for stage in stage_list {
                if overlay is None and stage.surface != s {
                    continue;
                }
                # A fading model (Q2 RF_TRANSLUCENT) blends its unblended stages.
                source = stage.gl_source;
                destination = stage.gl_destination;
                writes = stage.depth_write;
                if fading and not stage.blended {
                    source = 770;
                    destination = 771;
                    writes = False;
                }
                model_cull(gpu, stage.cull);
                model_blend(gpu, source, destination, self.mesh);
                if not writes {
                    rlDisableDepthMask();
                }
                steps = packed_tcmods(stage.source, seconds) if stage.source.mods else MODEL_PLAIN_STEPS;
                struct.pack_into(
                    "<ffff", gpu.stage, 0, stage.tc_gen,
                    1.0 if illumination.enabled and stage.lit else 0.0,
                    1.0 if stage.fullbright else 0.0,
                    float(len(steps[0]) // 16)
                );
                program.set_vec4s("u_stage", bytes(gpu.stage));
                program.set_vec4s("u_gen", stage.gen);
                program.set_vec4s("u_color", stage.tint(seconds, entity_color));
                deforms = stage.source.deforms;
                if deforms {
                    values = stage.deform_values if stage.deform_values else packed_deforms(deforms, seconds);
                    program.set_int("deformCount", len(values[0]) // 16);
                    program.set_vec4s("deformInfo", values[0]);
                    program.set_vec4s("deformWave", values[1]);
                    program.set_vec4s("deformVector", values[2]);
                } else {
                    program.set_int("deformCount", 0);
                }
                if stage.vectors {
                    program.set_vec4s("u_tcv", stage.vectors);
                }
                program.set_vec4s("u_tcS", steps[0]);
                program.set_vec4s("u_tcT", steps[1]);
                program.set_vec4s("u_turb", steps[2]);
                rlEnableTexture(
                    u32(stage.frames[stage_frame(seconds, stage.frequency, len(stage.frames))])
                );
                self.mesh.draw_vertices(self.firsts[s], count);
                if not writes {
                    rlEnableDepthMask();
                }
            }
            # RB_FogPass over the model's opaque surfaces inside a fog volume.
            if fogged and self.opaque[s] and fog is not None {
                model_cull(gpu, SHADER_CULL_FRONT);
                model_blend(gpu, 770, 771, self.mesh);
                rlDisableDepthMask();
                self.set_fog(gpu, fog, eye, forward);
                rlEnableTexture(u32(fog_image));
                self.mesh.draw_vertices(self.firsts[s], count);
                rlEnableDepthMask();
            }
        }
        model_cull(gpu, SHADER_CULL_FRONT);
        self.mesh.unbind();
        if owned {
            end_model_pass();
        }
    }

    """quake.jac fog_coords as u_fog: s runs along the view `forward` over
    eight fog depths, t across the fog surface (tr_main.c RB_CalcFogTexCoords)."""
    def set_fog(gpu: ModelGpu, fog: FogVolume, eye: Vec3, forward: Vec3) {
        scale = 1.0 / (fog.depth * 8.0);
        struct.pack_into(
            "<ffff", gpu.fog, 0, forward.x * scale, forward.y * scale, forward.z * scale,
            -forward.dot(eye) * scale + 1.0 / 512.0
        );
        struct.pack_into("<ffff", gpu.fog, 16, fog.inward.x, fog.inward.y, fog.inward.z, fog.offset);
        struct.pack_into(
            "<ffff", gpu.fog, 32, fog.inward.dot(eye) + fog.offset,
            1.0 if fog.has_surface else 0.0, 0.0, 0.0
        );
        struct.pack_into(
            "<ffff", gpu.fog, 48,
            float(min(255, int(fog.color.x * 255.0))) / 255.0,
            float(min(255, int(fog.color.y * 255.0))) / 255.0,
            float(min(255, int(fog.color.z * 255.0))) / 255.0,
            1.0
        );
        gpu.program.set_vec4s("u_fog", bytes(gpu.fog));
        struct.pack_into("<ffff", gpu.stage, 0, 0.0, 2.0, 0.0, 0.0);
        gpu.program.set_vec4s("u_stage", bytes(gpu.stage));
        gpu.program.set_vec4s("u_gen", MODEL_NO_GEN);
    }

    """The CPU path (QP_RENDER_LEGACY=1): pose every vertex and send it
    through raylib's immediate mode. It draws each stage's blend, culling,
    colour, light and tcMods, and a shell's steady push along the normals;
    alphaFunc, lightingSpecular and the other deforms need the model shader
    and are left out."""
    def draw_immediate(
        origin: Vec3,
        yaw: float,
        first: int = 0,
        second: int = 0,
        blend: float = 0.0,
        eye: Vec3 = Vec3(),
        seconds: float = 0.0,
        batched: bool = False,
        illumination: Illumination = Illumination(),
        basis: Basis | None = None,
        fog: FogVolume | None = None,
        fog_image: int = 0,
        forward: Vec3 = Vec3(x=1.0),
        alpha: float = 1.0,
        overlay: ModelRenderer | None = None,
        entity_color: list[float] = MODEL_ENTITY_COLOR
    ) {
        if not self.stages {
            return;
        }
        illumination = illumination.at(seconds);
        # A fading model (Q2 RF_TRANSLUCENT explosions) blends its opaque skins.
        fading = alpha < 0.999;
        opacity = u8(int(max(0.0, min(1.0, alpha)) * 255.0));
        # A custom shader (Q3 powerup shells, invisibility) replaces every
        # surface's stages, its vertices pushed out along their normals.
        stage_list = self.stages;
        if overlay is not None {
            stage_list = overlay.stages;
            fog = None;
        }
        cosine = math.cos(yaw);
        sine = math.sin(yaw);
        # A full model frame is applied component-wise, like the yaw rotation.
        fx = cosine;
        fy = sine;
        fz = 0.0;
        lx = -sine;
        ly = cosine;
        lz = 0.0;
        ux = 0.0;
        uy = 0.0;
        uz = 1.0;
        if basis is not None {
            fx = basis.forward.x;
            fy = basis.forward.y;
            fz = basis.forward.z;
            lx = basis.left.x;
            ly = basis.left.y;
            lz = basis.left.z;
            ux = basis.up.x;
            uy = basis.up.y;
            uz = basis.up.z;
        }
        view = eye.sub(origin);
        local_eye = Vec3(
            x=view.x * cosine + view.y * sine,
            y=-view.x * sine + view.y * cosine,
            z=view.z
        );
        if basis is not None {
            local_eye = basis.inverse(view);
        }
        for s in range(len(self.model.surfaces)) {
            surface = self.model.surfaces[s];
            vertices = pose(surface, first, second, blend);
            pushed = [stage for stage in stage_list if overlay is not None or stage.surface == s];
            inflate = steady_push(pushed[0].source.deforms) if pushed else 0.0;
            if inflate != 0.0 {
                a = frame_normals(surface.frames[first]);
                b = frame_normals(surface.frames[second]);
                if len(a) == len(vertices) and len(b) == len(vertices) {
                    fraction = max(0.0, min(1.0, blend));
                    vertices = [
                        vertices[i].add(a[i].lerp(b[i], fraction).scale(inflate))
                        for i in range(len(vertices))
                    ];
                }
            }
            colors: list[Vec3] = [];
            if illumination.enabled {
                normals = frame_normals(surface.frames[first]);
                next_normals = frame_normals(surface.frames[second]);
                for vertex in range(len(vertices)) {
                    color = illumination.ambient.add(illumination.directed.scale(0.5));
                    if len(normals) == len(vertices)
                        and len(next_normals) == len(vertices) {
                        n = normals[vertex].lerp(
                            next_normals[vertex], max(0.0, min(1.0, blend))
                        ).normalized();
                        normal = Vec3(
                            x=n.x * fx + n.y * lx + n.z * ux,
                            y=n.x * fy + n.y * ly + n.z * uy,
                            z=n.x * fz + n.y * lz + n.z * uz
                        );
                        color = illumination.shade(n if illumination.model_space else normal);
                    }
                    colors.append(color);
                }
            }
            for stage in stage_list {
                if overlay is None and stage.surface != s {
                    continue;
                }
                source = stage.gl_source;
                destination = stage.gl_destination;
                writes = stage.depth_write;
                if fading and not stage.blended {
                    source = 770;
                    destination = 771;
                    writes = False;
                }
                lit = illumination.enabled and stage.lit;
                rlDrawRenderBatchActive();
                if stage.cull == SHADER_CULL_NONE {
                    rlDisableBackfaceCulling();
                } elif stage.cull == SHADER_CULL_BACK {
                    rlSetCullFace(i32(0));
                }
                rlSetBlendFactors(i32(source), i32(destination), i32(32774));
                BeginBlendMode(i32(6));
                if not writes {
                    rlDisableDepthMask();
                }
                rlSetTexture(
                    u32(
                        stage.frames[
                            stage_frame(seconds, stage.frequency, len(stage.frames))
                        ]
                    )
                );
                rlBegin(i32(4));
                shade = struct.unpack("<ffff", stage.tint(seconds, entity_color));
                rlColor4ub(
                    u8(int(shade[0] * 255.0)),
                    u8(int(shade[1] * 255.0)),
                    u8(int(shade[2] * 255.0)),
                    u8(int(shade[3] * float(int(opacity))))
                );
                for triangle in range(len(surface.indices) // 3) {
                    # Alias model file triangles wind clockwise; rlgl expects CCW.
                    for corner in [0, 2, 1] {
                        index = triangle * 3 + corner;
                        v = vertices[surface.indices[index]];
                        if lit {
                            color = colors[surface.indices[index]];
                            rlColor4ub(
                                u8(int(min(255.0, max(0.0, color.x * 255.0)))),
                                u8(int(min(255.0, max(0.0, color.y * 255.0)))),
                                u8(int(min(255.0, max(0.0, color.z * 255.0)))),
                                u8(int(shade[3] * float(int(opacity))))
                            );
                        }
                        u = surface.uv[index * 2];
                        t = surface.uv[index * 2 + 1];
                        if stage.environment {
                            vertex = surface.indices[index];
                            a = frame_normals(surface.frames[first]);
                            b = frame_normals(surface.frames[second]);
                            if len(a) != len(vertices) or len(b) != len(vertices) {
                                raise ValueError(
                                    "Environment mapping needs model normals"
                                );
                            }
                            normal = a[vertex].lerp(
                                b[vertex], max(0.0, min(1.0, blend))
                            ).normalized();
                            viewer = local_eye.sub(v).normalized();
                            reflection = normal.scale(2.0 * normal.dot(viewer)).sub(
                                viewer
                            );
                            u = 0.5 + reflection.y * 0.5;
                            t = 0.5 - reflection.z * 0.5;
                        }
                        moved = apply_tcmods(stage.source, u, t, v, seconds);
                        rlTexCoord2f(f32(moved[0]), f32(moved[1]));
                        rlVertex3f(
                            f32(origin.x + v.x * fx + v.y * lx + v.z * ux),
                            f32(origin.y + v.x * fy + v.y * ly + v.z * uy),
                            f32(origin.z + v.x * fz + v.y * lz + v.z * uz)
                        );
                    }
                }
                rlEnd();
                rlDrawRenderBatchActive();
                if stage.cull == SHADER_CULL_NONE {
                    rlEnableBackfaceCulling();
                } elif stage.cull == SHADER_CULL_BACK {
                    rlSetCullFace(i32(1));
                }
                if not writes {
                    rlEnableDepthMask();
                }
                if stage.blended or fading or not batched {
                    EndBlendMode();
                }
            }
            # RB_FogPass over the model's opaque surfaces inside a fog volume.
            if fog is not None and fog_image != 0 and any([stage.surface == s and not stage.blended for stage in self.stages]) {
                rlDrawRenderBatchActive();
                BeginBlendMode(i32(0));
                rlDisableDepthMask();
                rlSetTexture(u32(fog_image));
                rlBegin(i32(4));
                rlColor4ub(
                    u8(min(255, int(fog.color.x * 255.0))),
                    u8(min(255, int(fog.color.y * 255.0))),
                    u8(min(255, int(fog.color.z * 255.0))),
                    u8(255)
                );
                for triangle in range(len(surface.indices) // 3) {
                    for corner in [0, 2, 1] {
                        v = vertices[surface.indices[triangle * 3 + corner]];
                        point = Vec3(
                            x=origin.x + v.x * fx + v.y * lx + v.z * ux,
                            y=origin.y + v.x * fy + v.y * ly + v.z * uy,
                            z=origin.z + v.x * fz + v.y * lz + v.z * uz
                        );
                        st = fog_coords(fog, point, eye, forward);
                        rlTexCoord2f(f32(st[0]), f32(st[1]));
                        rlVertex3f(f32(point.x), f32(point.y), f32(point.z));
                    }
                }
                rlEnd();
                rlDrawRenderBatchActive();
                rlEnableDepthMask();
                EndBlendMode();
            }
        }
        rlSetTexture(u32(0));
    }

    def close() {
        if self.textures {
            rlDrawRenderBatchActive();
        }
        for texture in self.textures {
            rlUnloadTexture(u32(texture));
        }
        self.textures = [];
        self.stages = [];
        self.model = AnimatedModel();
        self.mesh.close();
        if self.keyframes != 0 {
            rlUnloadTexture(u32(self.keyframes));
            self.keyframes = 0;
        }
        self.frame_count = 0;
        self.firsts = [];
        self.counts = [];
        self.opaque = [];
    }
}

import from ..world.world { World }
import from ..world.models { ModelResource, HasModelResource, GatherModels, ModelDraw }
import from ..math.interpolation { TickBlend }

"""tr_main.c R_ComputeFogNum: the first fog volume the model's bounding sphere
overlaps."""
def model_fog(fogs: list[FogVolume], origin: Vec3, radius: float) -> FogVolume | None {
    for fog in fogs {
        if origin.x - radius < fog.maxs.x and origin.x + radius > fog.mins.x
            and origin.y - radius < fog.maxs.y and origin.y + radius > fog.mins.y
            and origin.z - radius < fog.maxs.z and origin.z + radius > fog.mins.z {
            return fog;
        }
    }
    return None;
}

obj ModelScene {
    has resources: dict[str, ModelRenderer] = {};

    def upload(world: World) {
        self.close();
        try {
            for resource in [world->:HasModelResource:->][?:ModelResource] {
                if resource.name in self.resources {
                    continue;
                }
                drawing = ModelRenderer();
                drawing.upload(resource.model, resource.skins);
                self.resources[resource.name] = drawing;
            }
        } except Exception {
            self.close();
            raise;
        }
    }

    def draw(
        world: World,
        eye: Vec3 = Vec3(),
        seconds: float = 0.0,
        culling: bool = False,
        yaw: float = 0.0,
        pitch: float = 0.0,
        fov: float = 72.0,
        aspect: float = 1.7777777778,
        lighting: Lighting = Lighting(),
        fogs: list[FogVolume] = [],
        fog_image: int = 0,
        blend: TickBlend = TickBlend()
    ) {
        scene = world spawn GatherModels(seconds=seconds, blend=blend);
        forward = forward_from(yaw, pitch);
        # One program bind for every model (the legacy path draws immediately).
        gpu_pass = open_model_pass();
        try {
            self.draw_models(scene.draws, eye, seconds, culling, yaw, pitch, fov, aspect, lighting, fogs, fog_image, forward);
        } finally {
            if gpu_pass {
                end_model_pass();
            } else {
                EndBlendMode();
            }
        }
    }

    def draw_models(
        draws: list[ModelDraw],
        eye: Vec3,
        seconds: float,
        culling: bool,
        yaw: float,
        pitch: float,
        fov: float,
        aspect: float,
        lighting: Lighting,
        fogs: list[FogVolume],
        fog_image: int,
        forward: Vec3
    ) {
        # Draws are lit from their light_origin: an entity's simulation position,
        # or the one a rig's parts share (RF_LIGHTING_ORIGIN), lit once for all.
        shared_origin: Vec3 | None = None;
        shared_light = Illumination();
        for draw in draws {
            if draw.resource.name in self.resources {
                renderer = self.resources[draw.resource.name];
                if culling
                    and not sphere_in_view(
                        draw.origin.sub(eye), renderer.radius, yaw, pitch, fov, aspect
                    ) {
                    continue;
                }
                lit_from = draw.light_origin;
                illumination = shared_light;
                if renderer.model.baked_light {
                    illumination = Illumination();
                } elif lit_from is None {
                    illumination = lighting.light_model(draw.origin, math.degrees(draw.yaw), draw.light_flags, draw.light);
                } elif lit_from is not shared_origin {
                    shared_origin = lit_from;
                    shared_light = lighting.light_model(lit_from, math.degrees(draw.yaw), draw.light_flags, draw.light);
                    illumination = shared_light;
                }
                overlay: ModelRenderer | None = None;
                if draw.shader {
                    if draw.shader not in self.resources {
                        continue;
                    }
                    overlay = self.resources[draw.shader];
                }
                renderer.draw(
                    draw.origin,
                    draw.yaw,
                    draw.first,
                    draw.second,
                    draw.blend,
                    eye,
                    seconds,
                    batched=True,
                    overlay=overlay,
                    illumination=illumination,
                    basis=draw.basis
                        if draw.basis is not None
                        else (
                            model_basis(draw.yaw, draw.pitch, draw.roll)
                                if draw.pitch != 0.0 or draw.roll != 0.0
                                else None
                        ),
                    fog=model_fog(fogs, draw.origin, renderer.radius),
                    fog_image=fog_image,
                    forward=forward,
                    entity_color=draw.entity_color if draw.entity_color else MODEL_ENTITY_COLOR
                );
            }
        }
    }

    def close() {
        for name in self.resources.keys() {
            self.resources[name].close();
        }
        self.resources = {};
    }
}

def sphere_in_view(
    delta: Vec3, radius: float, yaw: float, pitch: float, fov: float, aspect: float
) -> bool {
    forward = forward_from(yaw, pitch);
    right = right_from(yaw);
    up = right.cross(forward);
    depth = delta.dot(forward);
    vertical = math.tan(fov * math.pi / 360.0);
    horizontal = vertical * aspect;
    return depth >= -radius
        and abs(delta.dot(right))
            <= depth * horizontal + radius * math.sqrt(1.0 + horizontal * horizontal)
        and abs(delta.dot(up))
            <= depth * vertical + radius * math.sqrt(1.0 + vertical * vertical);
}
