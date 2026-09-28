"""The BSP world renderer: textures, lightmaps and shader stages uploaded at
level load, and every frame the visible surfaces drawn from GPU-resident
vertex chunks by the shaders in world_mesh.jac. The sky box and Q3 portal
backdrops still go through raylib's rlgl batch."""
import math;
import struct;
import from vendor.raylib {
    obj Shader {
        has id: u32,
            locs: u64;
    }  def LoadShaderFromMemory(vs: str, fs: str) -> Shader;  def GetShaderLocation(
        shader: Shader, name: str
    ) -> i32;  def UnloadShader(shader: Shader) -> None;  def BeginShaderMode(
        shader: Shader
    ) -> None;  def EndShaderMode -> None;  def rlNormal3f(
        x: f32, y: f32, z: f32
    ) -> None;  def rlActiveTextureSlot(slot: i32) -> None;  def rlEnableTexture(
        id: u32
    ) -> None;  def rlDisableTexture -> None;  def rlEnableShader(id: u32) -> None;  def rlDisableShader -> None;  def rlSetUniform(
        loc: i32, value: bytes, kind: i32, count: i32
    ) -> None;
    # Opaque image data handle, matching the 64-bit desktop C ABI.
    obj Image {
        has data: u64,
            width: i32,
            height: i32,
            mipmaps: i32,
            format: i32;
    }  obj Texture2D {
        has id: u32,
            width: i32,
            height: i32,
            mipmaps: i32,
            format: i32;
    }  def rlDisableDepthMask -> None;  def rlEnableDepthMask -> None;  def rlDisableBackfaceCulling -> None;  def rlEnableBackfaceCulling -> None;  def LoadImageFromMemory(
        fileType: str, fileData: bytes, dataSize: i32
    ) -> Image;  def LoadTextureFromImage(image: Image) -> Texture2D;  def UnloadImage(
        image: Image
    ) -> None;  def rlLoadTexture(
        data: bytes, width: i32, height: i32, format: i32, mipmapCount: i32
    ) -> u32;  def rlUpdateTexture(
        id: u32, offsetX: i32, offsetY: i32, width: i32, height: i32, format: i32, data: bytes
    ) -> None;  def rlUnloadTexture(id: u32) -> None;  def rlTextureParameters(
        id: u32, param: i32, value: i32
    ) -> None;  def rlSetTexture(id: u32) -> None;  def rlBegin(mode: i32) -> None;  def rlEnd -> None;  def rlTexCoord2f(
        x: f32, y: f32
    ) -> None;  def rlVertex3f(x: f32, y: f32, z: f32) -> None;  def rlColor4ub(
        r: u8, g: u8, b: u8, a: u8
    ) -> None;  def rlDrawRenderBatchActive -> None;  def BeginBlendMode(
        mode: i32
    ) -> None;  def EndBlendMode -> None;  def rlSetBlendFactors(
        src: i32, dst: i32, equation: i32
    ) -> None;  def rlDrawVertexArrayElements(
        offset: i32, count: i32, buffer: u64
    ) -> None;  def rlDisableVertexArray -> None;
}
import from ..world.level { Level }
import from ..world.portals { surface_plane }
import from ..formats.bsp { Face, Texture, FogVolume }
import from ..formats.animated { ModelStage, Deform, TexMod, stage_frame }
import from ..math.vec3 { Vec3 }
import from ..world.lighting { Lighting, shift_light }
import from .gpu {
    GpuMesh,
    GpuProgram,
    VertexAttribute,
    Matrix,
    GL_FLOAT,
    GL_UNSIGNED_BYTE,
    view_projection,
    pack_floats
}
import from .world_mesh {
    IndexLists,
    IndexSpan,
    SurfaceBatch,
    VisibleIndices,
    ChunkIndices,
    BrushGroup,
    BrushModel,
    WORLD_VERTEX_STRIDE,
    WORLD_FOG_LIMIT,
    SURFACE_LIGHTMAP,
    SURFACE_ALPHA_SHIFT,
    SURFACE_EMISSION,
    SURFACE_VERTEX_COLOR,
    PASS_LIT,
    PASS_SKY,
    PASS_LIQUID,
    PASS_TRANSLUCENT,
    PASS_BASE,
    PASS_ADDITIVE,
    PASS_LAYERED,
    PASS_FOG,
    PASS_FOG_TWO_SIDED,
    LIT_VS,
    LIT_FS,
    WARP_VS,
    WARP_FS,
    SKY_VS,
    SKY_FS,
    BASE_VS,
    BASE_FS,
    STAGE_VS,
    STAGE_FS,
    FOG_VS,
    FOG_FS,
    batch_key,
    assign_chunks,
    face_index_bytes,
    gather_indices,
    pack_world_face,
    set_uniform_vec3,
    set_uniform_vec2,
    wave_code
}

obj LightRect {
    has x: int = 0,
        y: int = 0,
        layer: float = 0.0;
}

# The tint uniform for surfaces not lit per frame.
glob WHITE_TINT: bytes = b"\x00\x00\x80?\x00\x00\x80?\x00\x00\x80?\x00\x00\x80?";

"""One Q3 shader stage prepared at level load for the stage shader: its GL
state (as a key and its parts), its image frames, and every uniform that
does not change with time, packed once. Waves, scrolls and moves are
evaluated each frame (`tint`, `tcmods` or `deform_values` left empty)."""
obj StagePlan {
    has texture: int = 0,
        batch: SurfaceBatch = SurfaceBatch(),
        stage: ModelStage = ModelStage(),
        deforms: list[Deform] = [],
        key: str = "",
        blended: bool = False,
        source: int = 1,
        destination: int = 0,
        depth_write: bool = True,
        two_sided: bool = False,
        images: list[int] = [],
        light: bool = False,
        rgb_mode: int = 0,
        alpha_mode: int = 0,
        tc_gen: int = 0,
        fog_mode: int = 0,
        tint: bytes = b"",
        tcmods: list[bytes] = [],
        tc_steps: int = 0,
        deform_values: list[bytes] = [],
        deform_count: int = 0;
}

obj QuakeRenderer {
    has lighting: Lighting = Lighting(),
        overbright: bool = False;
    has textures: list[int] = [],
        sky: list[int] = [],
        single_pass: bool = False,
        atlas: int = 0,
        atlas_size: int = 2048,
        rects: list[LightRect] = [],
        stage_images: dict[int, list[list[int]]] = {},
        sky_layers: dict[int, list[int]] = {},
        anim_frames: dict[int, list[int]] = {},
        anim_alternates: dict[int, list[int]] = {},
        world_faces: int = 0,
        cloud_images: list[list[int]] = [],
        white: int = 0,
        time: float = 0.0,
        fog_image: int = 0,
        view_forward: Vec3 = Vec3(x=1.0),
        cloud_offsets: list[Vec3] = [],
        cloud_points: list[Vec3] = [],
        cloud_coords: list[float] = [],
        cloud_height_cached: float = -1.0,
        stage_state: str = "",
        stage_blended: bool = False,
        portal_image: int = 0,
        portal_normal: Vec3 = Vec3(),
        portal_dist: float = 0.0,
        portal_width: float = 1.0,
        portal_height: float = 1.0,
        portal_shader: Shader = Shader(id=u32(0), locs=u64(0)),
        portal_size: int = -1;
    # The world in GPU buffers (world_mesh.jac): vertex chunks, each face's
    # chunk, batches and index run, the surface batches by pass, the index
    # lists of recent visible sets, and the brush models' groups.
    has chunks: list[GpuMesh] = [],
        face_chunks: list[int] = [],
        face_batches: list[list[int]] = [],
        face_runs: list[bytes] = [],
        brush_face: list[bool] = [],
        batches: list[SurfaceBatch] = [],
        batch_ids: dict[int, int] = {},
        pass_batches: dict[int, list[SurfaceBatch]] = {},
        views: list[VisibleIndices] = [],
        view_clock: int = 0,
        brush_models: list[BrushModel] = [],
        brush_groups: list[BrushGroup] = [],
        brush_matrices: list[Matrix] = [],
        brush_lists: IndexLists = IndexLists(),
        brush_buffers: ChunkIndices = ChunkIndices(),
        brush_signature: list[int] = [],
        brush_batches: dict[int, bool] = {},
        brush_count: int = 0,
        cloud_mesh: GpuMesh = GpuMesh(),
        cloud_vertices: int = 0;
    # Shader programs, the light style values the lit program reads
    # (d_lightstylevalue, 1 = 'm'), and what is bound now.
    has lit_program: GpuProgram = GpuProgram(),
        warp_program: GpuProgram = GpuProgram(),
        sky_program: GpuProgram = GpuProgram(),
        base_program: GpuProgram = GpuProgram(),
        stage_program: GpuProgram = GpuProgram(),
        fog_program: GpuProgram = GpuProgram(),
        style_values: list[float] = [],
        styles_dirty: bool = True,
        bound_chunk: int = -1,
        bound_buffer: int = -1,
        placed_group: int = -2,
        uniform_values: dict[int, dict[str, bytes]] = {},
        uniform_ints: dict[int, dict[str, int]] = {};
    # Q3 shader stages planned at load: by shader, and the draw orders of
    # draw_layered (opaque stages by stage number then GL state, translucent
    # shaders in texture order, portal shaders).
    has stage_plans: dict[int, list[StagePlan]] = {},
        opaque_plans: list[list[StagePlan]] = [],
        translucent_shaders: list[int] = [],
        portal_shaders: list[int] = [];

    def upload_image(texture: Texture) -> int {
        image = LoadImageFromMemory(
            texture.extension, texture.encoded, i32(len(texture.encoded))
        );
        if image.data == u64(0) {
            raise ValueError("Image decode failed: " + texture.name);
        }
        gpu = LoadTextureFromImage(image);
        UnloadImage(image);
        if gpu.id == u32(0) {
            raise RuntimeError("Image upload failed: " + texture.name);
        }
        return int(gpu.id);
    }

    """The six-sided sky box around the eye (gl_warp.c R_DrawSkyBox), turned
    `angle` degrees about `axis` when the level rotates its sky (Q2
    skyrotate: glRotatef by time times the rate)."""
    def draw_sky(eye: Vec3, angle: float = 0.0, axis: Vec3 = Vec3()) {
        if len(self.sky) != 6 {
            return;
        }
        spin = axis.length() > 0.0 and angle != 0.0;
        axes = [
            [3, -1, 2],
            [-3, 1, 2],
            [1, 3, 2],
            [-1, -3, 2],
            [-2, -1, 3],
            [2, -1, -3]
        ];
        rlDrawRenderBatchActive();
        rlDisableDepthMask();
        rlDisableBackfaceCulling();
        for side in range(6) {
            rlSetTexture(u32(self.sky[side]));
            rlBegin(i32(4));
            rlColor4ub(u8(255), u8(255), u8(255), u8(255));
            for corner in [0, 1, 2, 0, 2, 3] {
                s = -1.0 if corner < 2 else 1.0;
                t = -1.0 if corner == 0 or corner == 3 else 1.0;
                base = [s * 512.0, t * 512.0, 512.0];
                coords: list[float] = [];
                for component in axes[side] {
                    coords.append(base[abs(component) - 1] * (-1.0 if component < 0 else 1.0));
                }
                point = Vec3(x=coords[0], y=coords[1], z=coords[2]);
                if spin {
                    point = sky_turn(point, axis, angle);
                }
                rlTexCoord2f(f32((s + 1.0) * 0.5), f32((1.0 - t) * 0.5));
                rlVertex3f(
                    f32(eye.x + point.x),
                    f32(eye.y + point.y),
                    f32(eye.z + point.z)
                );
            }
            rlEnd();
        }
        rlDrawRenderBatchActive();
        rlEnableBackfaceCulling();
        rlEnableDepthMask();
    }

    def upload(level: Level) {
        if level.bsp.fogs and self.fog_image == 0 {
            self.fog_image = upload_fog_image();
        }
        self.single_pass = level.bsp.game in ["q3", "passion"];
        self.overbright = level.bsp.game == "q3";
        for texture in level.bsp.sky {
            image_id = self.upload_image(texture);
            self.sky.append(image_id);
            rlTextureParameters(u32(image_id), i32(10241), i32(9729));
            rlTextureParameters(u32(image_id), i32(10240), i32(9729));
            rlTextureParameters(u32(image_id), i32(10242), i32(33071));
            rlTextureParameters(u32(image_id), i32(10243), i32(33071));
        }
        for texture in level.bsp.textures {
            if texture.rgba {
                if len(texture.rgba) != texture.width * texture.height * 4 {
                    raise ValueError("Invalid RGBA texture: " + texture.name);
                }
                gpu = rlLoadTexture(
                    texture.rgba,
                    i32(texture.width),
                    i32(texture.height),
                    i32(7),
                    i32(1)
                );
                if gpu == u32(0) {
                    raise RuntimeError("Texture upload failed");
                }
                self.textures.append(int(gpu));
                rlTextureParameters(gpu, i32(10242), i32(10497));
                rlTextureParameters(gpu, i32(10243), i32(10497));
                continue;
            }
            if len(texture.encoded) > 0 {
                image_id = self.upload_image(texture);
                self.textures.append(image_id);
                rlTextureParameters(u32(image_id), i32(10241), i32(9729));
                rlTextureParameters(u32(image_id), i32(10240), i32(9729));
                rlTextureParameters(u32(image_id), i32(10242), i32(10497));
                rlTextureParameters(u32(image_id), i32(10243), i32(10497));
                continue;
            }
            rgba = bytearray();
            sky = level.bsp.game == "q1"
                and texture.name.startswith("sky")
                and texture.width == texture.height * 2;
            for i in range(texture.width * texture.height) {
                index = int(texture.pixels[i])
                    if len(texture.pixels) > 0
                    else (0 if (i % 16 < 8) == (i // 16 < 8) else 255);
                # A Quake sky contains a masked foreground and a background
                # side by side. Composite a static sky rather than exposing the
                # black mask; scrolling sky layers will come with animation.
                if sky {
                    sx = i % texture.width % texture.height;
                    sy = i // texture.width;
                    index = int(texture.pixels[sy * texture.width + sx]);
                    if index == 0 {
                        index = int(
                            texture.pixels[sy * texture.width + sx + texture.height]
                        );
                    }
                }
                rgba.extend(level.palette[index * 3:index * 3 + 3]);
                # Q1 palette fullbrights (the last 32 colours) ignore the
                # lightmap; alpha 0 marks them for the lit shader.
                lit = level.bsp.game == "q1"
                    and index >= 224
                    and not sky
                    and not texture.name.startswith("*");
                rgba.append(0 if lit else 255);
            }
            id = rlLoadTexture(
                bytes(rgba), i32(texture.width), i32(texture.height), i32(7), i32(1)
            );
            if id == 0 {
                raise RuntimeError("Texture upload failed");
            }
            self.textures.append(int(id));
            # Nearest sampling preserves the original palette texels; repeat UVs.
            rlTextureParameters(id, i32(10241), i32(9728));
            rlTextureParameters(id, i32(10240), i32(9728));
            rlTextureParameters(id, i32(10242), i32(10497));
            rlTextureParameters(id, i32(10243), i32(10497));
        }
        self.upload_lightmaps(level);
        self.upload_stages(level);
        self.load_programs(level);
        self.build_world(level);
    }

    """The lightmap atlas. Q3 stores each lightmap once, shifted for
    overbright. Q1 and Q2 keep every light style layer of a face side by
    side, raw, so the lit shader scales each by its style's current value
    (R_BuildLightMap) and animated or switched lights need no upload."""
    def upload_lightmaps(level: Level) {
        pixels = bytearray(b"\xff") * (self.atlas_size * self.atlas_size * 4);
        x = 1;
        y = 1;
        row_height = 0;
        shared: dict[int, LightRect] = {};
        layered = level.bsp.game in ["q1", "q2"];
        channels = level.bsp.light_channels;
        for face in level.bsp.faces {
            if level.bsp.game == "q3" and face.light_offset in shared {
                self.rects.append(shared[face.light_offset]);
                continue;
            }
            rect = LightRect();
            self.rects.append(rect);
            if face.light_offset < 0 {
                continue;
            }
            w = face.light_width;
            h = face.light_height;
            layers = max(1, len(face.styles)) if layered else 1;
            if x + layers * (w + 2) - 1 > self.atlas_size {
                x = 1;
                y += row_height + 2;
                row_height = 0;
            }
            if y + h + 1 > self.atlas_size {
                raise ValueError("Lightmap atlas capacity exceeded");
            }
            shared[face.light_offset] = rect;
            rect.x = x;
            rect.y = y;
            rect.layer = float(w + 2) / float(self.atlas_size);
            for layer in range(layers) {
                left = x + layer * (w + 2);
                for ly in range(-1, h + 1) {
                    for lx in range(-1, w + 1) {
                        sample = min(max(ly, 0), h - 1) * w + min(max(lx, 0), w - 1);
                        p = ((y + ly) * self.atlas_size + left + lx) * 4;
                        raw = [0, 0, 0];
                        for channel in range(3) {
                            if layered {
                                raw[channel] = int(
                                    level.bsp.lighting[
                                        face.light_offset
                                            + (layer * w * h + sample) * channels
                                            + (channel if channels == 3 else 0)
                                    ]
                                );
                                continue;
                            }
                            for style in range(len(face.styles)) {
                                raw[channel] += int(
                                    level.bsp.lighting[
                                        face.light_offset
                                            + (style * w * h + sample) * channels
                                            + (channel if channels == 3 else 0)
                                    ]
                                );
                            }
                        }
                        if not layered {
                            shade = shift_light(self.overbright, raw[0], raw[1], raw[2]);
                            raw = [shade[0], shade[1], shade[2]];
                        }
                        pixels[p] = raw[0];
                        pixels[p + 1] = raw[1];
                        pixels[p + 2] = raw[2];
                    }
                }
            }
            x += layers * (w + 2);
            row_height = max(row_height, h);
        }
        self.atlas = int(
            rlLoadTexture(
                bytes(pixels),
                i32(self.atlas_size),
                i32(self.atlas_size),
                i32(7),
                i32(1)
            )
        );
        if self.atlas == 0 {
            raise RuntimeError("Lightmap upload failed");
        }
        rlTextureParameters(u32(self.atlas), i32(10241), i32(9729));
        rlTextureParameters(u32(self.atlas), i32(10240), i32(9729));
        self.style_values = [1.0] * 256;
        self.style_values[255] = 0.0;
        self.styles_dirty = True;
    }

    """Compile the programs this game draws with and point their samplers at
    fixed texture slots."""
    def load_programs(level: Level) {
        self.uniform_values = {};
        self.uniform_ints = {};
        if self.single_pass {
            self.base_program.load(BASE_VS, BASE_FS);
            self.stage_program.load(STAGE_VS, STAGE_FS);
            self.fog_program.load(FOG_VS, FOG_FS);
            for program in [self.base_program] {
                program.begin();
                program.set_int("colorMap", 0);
                program.set_int("lightMap", 1);
                program.end();
            }
            self.stage_program.begin();
            self.stage_program.set_int("stageMap", 0);
            self.stage_program.end();
            self.fog_program.begin();
            self.fog_program.set_int("fogMap", 0);
            self.fog_program.end();
            return;
        }
        self.lit_program.load(LIT_VS, LIT_FS);
        self.warp_program.load(WARP_VS, WARP_FS);
        self.sky_program.load(SKY_VS, SKY_FS);
        self.lit_program.begin();
        self.lit_program.set_int("colorMap", 0);
        self.lit_program.set_int("lightMap", 1);
        self.lit_program.end();
        self.warp_program.begin();
        self.warp_program.set_int("colorMap", 0);
        self.warp_program.end();
        self.sky_program.begin();
        self.sky_program.set_int("skyBack", 0);
        self.sky_program.set_int("skyFront", 1);
        self.sky_program.end();
    }

    """Which surface batches draw face `index` (world_mesh.jac passes): none
    for faces that never draw, else its pass and texture, plus a Q3 fog
    batch when its fog volume fogs it."""
    def face_passes(level: Level, index: int) -> list[int] {
        face = level.bsp.faces[index];
        t = face.texture;
        keys: list[int] = [];
        if len(face.vertices) < 3 {
            return keys;
        }
        if not self.single_pass {
            if t in self.sky_layers {
                keys.append(batch_key(PASS_SKY, t, 0));
            } elif face.warp or face.opacity < 1.0 {
                sub = 2 if not face.warp else (1 if face.flowing else 0);
                keys.append(batch_key(PASS_TRANSLUCENT if face.opacity < 1.0 else PASS_LIQUID, t, sub));
            } else {
                keys.append(batch_key(PASS_LIT, t, 0));
            }
            return keys;
        }
        if not face.fog_only {
            if t in self.stage_images {
                keys.append(batch_key(PASS_LAYERED, t, 0));
            } elif level.bsp.textures[t].additive {
                keys.append(batch_key(PASS_ADDITIVE, t, 0));
            } else {
                keys.append(batch_key(PASS_BASE, t, 0));
            }
        }
        if 0 <= face.fog < min(len(level.bsp.fogs), WORLD_FOG_LIMIT) and self.fog_receiver(level, face) {
            keys.append(batch_key(PASS_FOG_TWO_SIDED if face.two_sided or face.fog_only else PASS_FOG, 0, 0));
        }
        return keys;
    }

    """Pack every drawable face of the world and its brush models into
    static vertex chunks, sorted by surface batch, with each face's index
    run; group the brush models' faces by model."""
    def build_world(level: Level) {
        faces = level.bsp.faces;
        count = len(faces);
        self.world_faces = level.bsp.models[0].face_count if level.bsp.models else count;
        brush_set: dict[int, bool] = {};
        for f in level.brush_faces {
            brush_set[f] = True;
        }
        self.brush_face = [f in brush_set for f in range(count)];
        keys_of: list[list[int]] = [];
        drawn: list[int] = [];
        all_keys: dict[int, bool] = {};
        for f in range(count) {
            keys = self.face_passes(level, f) if f < self.world_faces or f in brush_set else [];
            keys_of.append(keys);
            if keys {
                drawn.append(f);
                for key in keys {
                    all_keys[key] = True;
                }
            }
        }
        self.batches = [];
        self.batch_ids = {};
        self.pass_batches = {};
        for key in sorted(all_keys.keys()) {
            kind = key // 4 // 65536;
            t = key // 4 % 65536;
            batch = SurfaceBatch(id=len(self.batches), kind=kind, texture=t, sub=key % 4, two_sided=kind != PASS_FOG_TWO_SIDED and level.bsp.textures[t].two_sided);
            self.batch_ids[key] = batch.id;
            self.batches.append(batch);
            if kind not in self.pass_batches {
                self.pass_batches[kind] = [];
            }
            self.pass_batches[kind].append(batch);
        }
        self.face_batches = [[self.batch_ids[key] for key in keys] for keys in keys_of];
        # Faces sorted by their first batch, so a batch's faces share chunks.
        drawn = [key % 1048576 for key in sorted([keys_of[f][0] * 1048576 + f for f in drawn])];
        counts = [len(face.vertices) for face in faces];
        placed = assign_chunks(counts, drawn);
        self.face_chunks = placed[0];
        chunk_count = max(self.face_chunks) + 1 if drawn else 0;
        buffers: list[bytearray] = [];
        used: list[int] = [0] * chunk_count;
        for f in drawn {
            used[self.face_chunks[f]] += counts[f];
        }
        for c in range(chunk_count) {
            buffers.append(bytearray(used[c] * WORLD_VERTEX_STRIDE));
        }
        self.face_runs = [b""] * count;
        fogs = min(len(level.bsp.fogs), WORLD_FOG_LIMIT);
        for f in drawn {
            face = faces[f];
            rect = self.rects[f];
            flags = 0;
            lit = face.light_offset >= 0;
            if lit {
                flags = SURFACE_LIGHTMAP;
            }
            if self.single_pass {
                flags = flags | (face.alpha_test << SURFACE_ALPHA_SHIFT);
                if not lit and face.emission {
                    flags = flags | SURFACE_EMISSION;
                }
                if not lit and len(face.colors) >= len(face.vertices) * 4 {
                    flags = flags | SURFACE_VERTEX_COLOR;
                }
            }
            base = placed[1][f];
            pack_world_face(
                buffers[self.face_chunks[f]],
                base * WORLD_VERTEX_STRIDE,
                face,
                rect.x,
                rect.y,
                self.atlas_size,
                0.0 if self.single_pass else rect.layer,
                flags,
                face.fog if 0 <= face.fog < fogs else -1,
                self.overbright,
                sprites=self.single_pass,
                alpha=int(face.opacity * 255.0)
            );
            self.face_runs[f] = face_index_bytes(face, base);
        }
        self.chunks = [];
        for c in range(chunk_count) {
            mesh = GpuMesh();
            mesh.upload(bytes(buffers[c]), WORLD_VERTEX_STRIDE, world_attributes());
            self.chunks.append(mesh);
        }
        # Brush models: each entity model's drawn faces.
        self.brush_models = [];
        for m in range(1, len(level.bsp.models)) {
            model = level.bsp.models[m];
            members = [f for f in range(model.first_face, model.first_face + model.face_count) if f in brush_set and self.face_chunks[f] >= 0];
            if members {
                self.brush_models.append(BrushModel(faces=members));
            }
        }
        self.brush_signature = [-1];
        self.brush_lists = IndexLists();
        self.views = [];
        self.plan_stages(level);
    }

    """The index lists of a visible face set: reused while the same set comes
    back (Level.visible keeps its lists while the view stays in a leaf),
    rebuilt otherwise into the least recently used of three slots."""
    def visible_indices(level: Level, faces: list[int]) -> VisibleIndices {
        self.view_clock += 1;
        for view in self.views {
            if view.faces is faces {
                view.used = self.view_clock;
                return view;
            }
        }
        view = VisibleIndices();
        if len(self.views) < 3 {
            self.views.append(view);
        } else {
            oldest = 0;
            for i in range(len(self.views)) {
                if self.views[i].used < self.views[oldest].used {
                    oldest = i;
                }
            }
            view = self.views[oldest];
        }
        view.faces = faces;
        view.used = self.view_clock;
        view.portal_faces = {};
        lists = IndexLists(chunks=[bytearray() for c in range(len(self.chunks))], spans={});
        shown: list[int] = [];
        bsp_faces = level.bsp.faces;
        for f in faces {
            if f < len(self.brush_face) and not self.brush_face[f] and not bsp_faces[f].hidden {
                shown.append(f);
                t = bsp_faces[f].texture;
                if t in level.portal_ranges {
                    if t not in view.portal_faces {
                        view.portal_faces[t] = [];
                    }
                    view.portal_faces[t].append(f);
                }
            }
        }
        gather_indices(lists, shown, self.face_chunks, self.face_batches, self.face_runs);
        view.shown = self.batches_by_pass(lists.spans);
        view.lists = lists;
        view.buffers.fill(lists);
        return view;
    }

    """Group the brush models' faces by placement for this frame (world_mesh
    BrushGroup): models at rest together by entity frame, each moved model
    alone, and faces lit per frame or placed apart from their model one by
    one. The groups' index lists are rebuilt only when that grouping or a
    face's visibility changes; their placements are refreshed every frame."""
    def update_brushes(level: Level) {
        faces = level.bsp.faces;
        # Moving faces lit per frame (the passion movers): only the single-pass
        # shader takes their light; Q1 and Q2 samples are white.
        lamp = self.lighting.grid is None and self.single_pass;
        signature: list[int] = [];
        for m in range(len(self.brush_models)) {
            members = self.brush_models[m].faces;
            lead = faces[members[0]];
            state = 0;
            hidden = 0;
            for f in members {
                face = faces[f];
                if face.hidden {
                    hidden += 1;
                    continue;
                }
                if (face.moving_light and lamp) or not same_placement(face, lead) {
                    state = 2;
                }
            }
            if state == 0 and moved_face(lead) {
                state = 1;
            }
            signature.append(m * 4 + state);
            signature.append(lead.frame);
            if hidden > 0 {
                for f in members {
                    if faces[f].hidden {
                        signature.append(-1 - f);
                    }
                }
            }
        }
        if signature != self.brush_signature {
            self.brush_signature = signature;
            self.group_brushes(level);
        }
        # Placements (and per-frame light) follow each group's lead face.
        self.brush_matrices = [];
        for group in self.brush_groups {
            lead = faces[group.lead];
            self.brush_matrices.append(placement_matrix(lead));
            if group.lamp {
                center = lead.vertices[0].lerp(lead.vertices[2], 0.5);
                facing = lead.normal;
                turn = lead.turn;
                if turn is not None {
                    center = lead.pivot.add(turn.apply(center.sub(lead.pivot)));
                    facing = turn.apply(facing);
                }
                color = self.lighting.sample(center.add(lead.motion), False).shade(facing);
                group.tint = [
                    float(int(min(255.0, max(0.0, color.x * 255.0)))) / 255.0,
                    float(int(min(255.0, max(0.0, color.y * 255.0)))) / 255.0,
                    float(int(min(255.0, max(0.0, color.z * 255.0)))) / 255.0,
                    1.0
                ];
                group.tint_packed = pack_floats(group.tint);
            }
        }
    }

    def group_brushes(level: Level) {
        faces = level.bsp.faces;
        lamp = self.lighting.grid is None and self.single_pass;
        groups: list[BrushGroup] = [];
        resting: dict[int, BrushGroup] = {};
        for model in self.brush_models {
            shown = [f for f in model.faces if not faces[f].hidden];
            if not shown {
                continue;
            }
            lead = faces[shown[0]];
            apart = False;
            for f in shown {
                if (faces[f].moving_light and lamp) or not same_placement(faces[f], lead) {
                    apart = True;
                }
            }
            if apart {
                for f in shown {
                    groups.append(BrushGroup(lead=f, faces=[f], lamp=faces[f].moving_light and lamp));
                }
            } elif moved_face(lead) {
                groups.append(BrushGroup(lead=shown[0], faces=shown));
            } else {
                if lead.frame not in resting {
                    resting[lead.frame] = BrushGroup(lead=shown[0], faces=[]);
                    groups.append(resting[lead.frame]);
                }
                resting[lead.frame].faces.extend(shown);
            }
        }
        lists = IndexLists(chunks=[bytearray() for c in range(len(self.chunks))], spans={});
        self.brush_batches = {};
        self.brush_count = 0;
        for group in groups {
            group.spans = gather_indices(lists, group.faces, self.face_chunks, self.face_batches, self.face_runs);
            group.shown = self.batches_by_pass(group.spans);
            group.tint_packed = pack_floats(group.tint);
            for batch in group.spans.keys() {
                self.brush_batches[batch] = True;
            }
            self.brush_count += len(group.faces);
        }
        self.brush_groups = groups;
        self.brush_lists = lists;
        self.brush_buffers.fill(lists);
    }

    """Animated textures. Q1 (gl_model.c, R_TextureAnimation): '+0'..'+9'
    frames cycle every 0.2 s, and an entity with a frame shows the '+a'..'+j'
    alternates. Q2: nexttexinfo chains step at 2 frames a second in the world,
    and by an entity's own frame on brush models."""
    def build_animations(level: Level) {
        self.anim_frames = {};
        self.anim_alternates = {};
        self.world_faces = level.bsp.models[0].face_count if level.bsp.models else len(level.bsp.faces);
        if level.bsp.game == "q1" {
            primary: dict[str, dict[int, int]] = {};
            alternate: dict[str, dict[int, int]] = {};
            for t in range(len(level.bsp.textures)) {
                name = level.bsp.textures[t].name.lower();
                if len(name) < 3 or not name.startswith("+") {
                    continue;
                }
                key = name[2:];
                mark = name[1];
                if mark.isdigit() {
                    if key not in primary { primary[key] = {}; }
                    primary[key][int(mark)] = t;
                } elif mark >= "a" and mark <= "j" {
                    if key not in alternate { alternate[key] = {}; }
                    alternate[key][ord(mark) - 97] = t;
                }
            }
            for (key, frames) in primary.items() {
                sequence: list[int] = [];
                while len(sequence) in frames {
                    sequence.append(frames[len(sequence)]);
                }
                others: list[int] = [];
                if key in alternate {
                    while len(others) in alternate[key] {
                        others.append(alternate[key][len(others)]);
                    }
                }
                for t in sequence {
                    self.anim_frames[t] = sequence;
                    if others {
                        self.anim_alternates[t] = others;
                    }
                }
                for t in others {
                    self.anim_frames[t] = others;
                    self.anim_alternates[t] = sequence;
                }
            }
        } elif level.bsp.game == "q2" {
            for (t, following) in level.bsp.texture_next.items() {
                cycle = [t];
                step = following;
                while step != t and step in level.bsp.texture_next and len(cycle) < 32 {
                    cycle.append(step);
                    step = level.bsp.texture_next[step];
                }
                if step == t or step not in level.bsp.texture_next {
                    self.anim_frames[t] = cycle;
                }
            }
        }
    }

    """The texture a face shows now, after its animation."""
    def shown_texture(level: Level, t: int, index: int) -> int {
        if t not in self.anim_frames {
            return t;
        }
        return self.frame_texture(level, t, level.bsp.faces[index].frame, index < self.world_faces);
    }

    """The texture `t` shows now on world faces or on a brush model at
    entity frame `frame`."""
    def frame_texture(level: Level, t: int, frame: int, world: bool) -> int {
        if t not in self.anim_frames {
            return t;
        }
        sequence = self.anim_frames[t];
        if level.bsp.game == "q1" {
            if frame != 0 and t in self.anim_alternates {
                sequence = self.anim_alternates[t];
            }
            return sequence[int(self.time * 5.0) % len(sequence)];
        }
        step = int(self.time * 2.0) if world else frame;
        return sequence[step % len(sequence)];
    }

    """Q3 cloud layers on the sky dome (tr_sky.c): each box vertex's direction
    meets a cloud sphere cloudheight above a 4096-unit world, and s and t are
    the arccosines of that point's direction, before the stage's tcMods,
    which the stage shader applies (turb at the cloud sphere point)."""
    def draw_clouds(level: Level, eye: Vec3) {
        if not self.cloud_images or not level.sky_clouds {
            return;
        }
        if self.cloud_height_cached != level.cloud_height {
            self.build_cloud_dome(level.cloud_height);
        }
        program = self.stage_program;
        program.begin();
        program.set_matrix("viewProjection", view_projection());
        program.set_matrix("model", placement_matrix_at(eye));
        self.put_float(program, "time", self.time);
        set_uniform_vec3(program, "eye", eye);
        self.put_int(program, "deformCount", 0);
        self.put_int(program, "tcGen", 0);
        self.put_int(program, "turbFromNormal", 1);
        self.put_int(program, "rgbMode", 0);
        self.put_int(program, "alphaMode", 0);
        self.put_int(program, "fogMode", 0);
        self.put_int(program, "lightmapStage", 0);
        rlDisableDepthMask();
        rlDisableBackfaceCulling();
        self.cloud_mesh.bind();
        for k in range(min(len(level.sky_clouds), len(self.cloud_images))) {
            stage = level.sky_clouds[k];
            ids = self.cloud_images[k];
            if k > 0 or stage.blend != "opaque" {
                source = 1;
                destination = 1;
                if stage.blend == "alpha" {
                    source = 770;
                    destination = 771;
                } elif stage.blend == "multiply" {
                    source = 774;
                    destination = 0;
                } elif stage.blend == "custom" {
                    source = gl_factor(stage.blend_source);
                    destination = gl_factor(stage.blend_destination);
                }
                rlSetBlendFactors(i32(source), i32(destination), i32(32774));
                BeginBlendMode(i32(6));
                self.resume(program);
                self.cloud_mesh.bind();
            }
            rlActiveTextureSlot(i32(0));
            rlEnableTexture(u32(ids[stage_frame(self.time, stage.frequency, len(ids))]));
            shade = 255;
            if stage.rgb == "wave" {
                shade = int(max(0.0, min(1.0, stage.rgb_wave.at(self.time))) * 255.0);
            }
            level_value = float(shade) / 255.0;
            self.put_vec4s(program, "tint", pack_floats([level_value, level_value, level_value, 1.0]));
            self.set_tcmods(program, stage);
            self.cloud_mesh.draw_vertices(0, self.cloud_vertices);
            if k > 0 or stage.blend != "opaque" {
                EndBlendMode();
                self.resume(program);
                self.cloud_mesh.bind();
            }
        }
        self.cloud_mesh.unbind();
        self.put_int(program, "turbFromNormal", 0);
        rlDisableTexture();
        program.end();
        rlEnableBackfaceCulling();
        rlEnableDepthMask();
    }

    """The cloud dome's triangles around the eye, and each corner's point on
    the cloud sphere `height` above a 4096-unit world with its arccos texture
    coordinates (tr_sky.c MakeSkyVec); they only change with the height. The
    dome uploads as a vertex chunk: offsets from the eye, coordinates, and the
    sphere point in the normal for tcMod turb."""
    def build_cloud_dome(height: float) {
        world_radius = 4096.0;
        steps = 8;
        # The box sides and top, as (u axis, v axis, fixed axis) directions.
        sides = [
            [Vec3(y=1.0), Vec3(z=1.0), Vec3(x=1.0)],
            [Vec3(y=-1.0), Vec3(z=1.0), Vec3(x=-1.0)],
            [Vec3(x=-1.0), Vec3(z=1.0), Vec3(y=1.0)],
            [Vec3(x=1.0), Vec3(z=1.0), Vec3(y=-1.0)],
            [Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)]
        ];
        self.cloud_offsets = [];
        self.cloud_points = [];
        self.cloud_coords = [];
        for side in sides {
            for row in range(steps) {
                for column in range(steps) {
                    corners = [[column, row], [column + 1, row], [column + 1, row + 1], [column, row], [column + 1, row + 1], [column, row + 1]];
                    for corner in corners {
                        a = float(corner[0]) / float(steps) * 2.0 - 1.0;
                        b = float(corner[1]) / float(steps) * 2.0 - 1.0;
                        # The top's rows run across it; the sides' from the horizon down to up.
                        direction = side[2].add(side[0].scale(a)).add(side[1].scale(b));
                        sky = direction.normalized();
                        reach = (1.0 / (2.0 * sky.dot(sky))) * (
                            -2.0 * sky.z * world_radius
                                + 2.0 * math.sqrt(
                                    sky.z * sky.z * world_radius * world_radius
                                        + 2.0 * (sky.x * sky.x + sky.y * sky.y + sky.z * sky.z) * world_radius * height
                                        + (sky.x * sky.x + sky.y * sky.y + sky.z * sky.z) * height * height
                                )
                        );
                        point = sky.scale(reach).add(Vec3(z=world_radius)).normalized();
                        self.cloud_offsets.append(direction.scale(512.0));
                        self.cloud_points.append(point);
                        self.cloud_coords.append(math.acos(max(-1.0, min(1.0, point.x))));
                        self.cloud_coords.append(math.acos(max(-1.0, min(1.0, point.y))));
                    }
                }
            }
        }
        self.cloud_height_cached = height;
        count = len(self.cloud_offsets);
        vertices = bytearray(count * WORLD_VERTEX_STRIDE);
        for n in range(count) {
            offset = self.cloud_offsets[n];
            point = self.cloud_points[n];
            struct.pack_into(
                "<fffffffBBBBfffBBBBBBBBffffffff",
                vertices,
                n * WORLD_VERTEX_STRIDE,
                offset.x, offset.y, offset.z,
                self.cloud_coords[n * 2], self.cloud_coords[n * 2 + 1],
                0.0, 0.0,
                255, 255, 255, 255,
                point.x, point.y, point.z,
                0, 0, 0, 0,
                255, 255, 255, 255,
                0.0, 0.0, 0.0, 0.0,
                0.0, 0.0, 0.0, 0.0
            );
        }
        self.cloud_mesh.close();
        self.cloud_mesh = GpuMesh();
        self.cloud_mesh.upload(bytes(vertices), WORLD_VERTEX_STRIDE, world_attributes());
        self.cloud_vertices = count;
    }

    """Quake's sky textures hold a masked front layer (left half, index 0 clear)
    beside a solid back layer (right half); each becomes its own texture."""
    def upload_sky_layers(level: Level) {
        self.sky_layers = {};
        if level.bsp.game != "q1" {
            return;
        }
        for t in range(len(level.bsp.textures)) {
            texture = level.bsp.textures[t];
            if not texture.name.startswith("sky") or texture.width != texture.height * 2 or not texture.pixels {
                continue;
            }
            size = texture.height;
            back = bytearray();
            totals = [0, 0, 0];
            for y in range(size) {
                for x in range(size) {
                    solid = int(texture.pixels[y * texture.width + x + size]);
                    back.extend(level.palette[solid * 3:solid * 3 + 3]);
                    back.append(255);
                    for c in range(3) {
                        totals[c] += int(level.palette[solid * 3 + c]);
                    }
                }
            }
            # gl_warp.c R_InitSky: clear texels take the back layer's average
            # colour, so filtering leaves no dark fringe around the clouds.
            average = [totals[c] // (size * size) for c in range(3)];
            front = bytearray();
            for y in range(size) {
                for x in range(size) {
                    masked = int(texture.pixels[y * texture.width + x]);
                    if masked == 0 {
                        front.extend([average[0], average[1], average[2], 0]);
                    } else {
                        front.extend(level.palette[masked * 3:masked * 3 + 3]);
                        front.append(255);
                    }
                }
            }
            ids: list[int] = [];
            for layer in [back, front] {
                id = int(rlLoadTexture(bytes(layer), i32(size), i32(size), i32(7), i32(1)));
                rlTextureParameters(u32(id), i32(10241), i32(9729));
                rlTextureParameters(u32(id), i32(10240), i32(9729));
                rlTextureParameters(u32(id), i32(10242), i32(10497));
                rlTextureParameters(u32(id), i32(10243), i32(10497));
                ids.append(id);
            }
            self.sky_layers[t] = ids;
        }
    }

    """Upload every image of every layered Q3 surface shader stage. A lightmap
    stage records -1 (the atlas) and $whiteimage a shared white texture."""
    def upload_stages(level: Level) {
        self.upload_sky_layers(level);
        self.build_animations(level);
        self.cloud_images = [];
        for stage in level.sky_clouds {
            sources = stage.frames if stage.frames else [stage.texture];
            ids: list[int] = [];
            for source in sources {
                image = self.upload_image(source);
                rlTextureParameters(u32(image), i32(10241), i32(9729));
                rlTextureParameters(u32(image), i32(10240), i32(9729));
                rlTextureParameters(u32(image), i32(10242), i32(10497));
                rlTextureParameters(u32(image), i32(10243), i32(10497));
                ids.append(image);
            }
            self.cloud_images.append(ids);
        }
        self.stage_images = {};
        if not level.surface_stages {
            return;
        }
        if self.white == 0 {
            self.white = int(rlLoadTexture(b"\xff\xff\xff\xff", i32(1), i32(1), i32(7), i32(1)));
        }
        for (index, stages) in level.surface_stages.items() {
            images: list[list[int]] = [];
            for stage in stages {
                if stage.lightmap {
                    images.append([-1]);
                    continue;
                }
                if stage.white {
                    images.append([self.white]);
                    continue;
                }
                sources = stage.frames if stage.frames else [stage.texture];
                ids: list[int] = [];
                for source in sources {
                    image = self.upload_image(source);
                    rlTextureParameters(u32(image), i32(10241), i32(9729));
                    rlTextureParameters(u32(image), i32(10240), i32(9729));
                    rlTextureParameters(u32(image), i32(10242), i32(10497));
                    rlTextureParameters(u32(image), i32(10243), i32(10497));
                    ids.append(image);
                }
                images.append(ids);
            }
            self.stage_images[index] = images;
        }
    }

    """R_AnimateLight: the current brightness of every animated or switched
    light style. The lit shader scales each lightmap style layer by it, so
    nothing is relit on the CPU."""
    def animate_styles(level: Level, values: dict[int, float]) {
        if len(self.style_values) != 256 {
            self.style_values = [1.0] * 256;
            self.style_values[255] = 0.0;
        }
        for (style, value) in values.items() {
            if 0 <= style < 255 and self.style_values[style] != value {
                self.style_values[style] = value;
                self.styles_dirty = True;
            }
        }
    }

    """Bind chunk `c` with the index buffer of `buffers`, unless bound."""
    def bind_chunk(c: int, buffers: ChunkIndices) {
        buffer = buffers.ids[c];
        if c == self.bound_chunk and buffer == self.bound_buffer {
            return;
        }
        self.chunks[c].bind();
        buffers.bind(c);
        self.bound_chunk = c;
        self.bound_buffer = buffer;
    }

    """Start drawing world batches with `program`: nothing bound yet, the
    world placement unknown."""
    def begin_batches(program: GpuProgram) {
        program.begin();
        self.bound_chunk = -1;
        self.bound_buffer = -1;
        self.placed_group = -2;
    }

    """raylib's batch flush, run by every blend mode change and by
    rlDrawRenderBatchActive, unbinds the current program and vertex array:
    bind `program` again (its uniforms keep their values)."""
    def resume(program: GpuProgram) {
        rlEnableShader(u32(program.id));
        self.bound_chunk = -1;
        self.bound_buffer = -1;
    }

    def end_batches(program: GpuProgram) {
        rlDisableVertexArray();
        self.bound_chunk = -1;
        self.bound_buffer = -1;
        rlActiveTextureSlot(i32(1));
        rlDisableTexture();
        rlActiveTextureSlot(i32(0));
        rlDisableTexture();
        program.end();
    }

    """Place what draws next: the world as the map placed it (`group` -1) or
    brush group `group` at its placement; `tinted` programs also take the
    group's per-frame light."""
    def place(program: GpuProgram, group: int, tinted: bool) {
        if self.placed_group == group {
            return;
        }
        if group < 0 {
            program.set_matrix("model", placement_matrix_at(Vec3()));
            if tinted {
                self.put_vec4s(program, "tint", WHITE_TINT);
            }
        } else {
            program.set_matrix("model", self.brush_matrices[group]);
            if tinted {
                self.put_vec4s(program, "tint", self.brush_groups[group].tint_packed);
            }
        }
        self.placed_group = group;
    }

    """Draw index runs from the world's (`buffers` of a view) or the brush
    models' index buffers."""
    def draw_spans(spans: list[IndexSpan], buffers: ChunkIndices) {
        for span in spans {
            self.bind_chunk(span.chunk, buffers);
            rlDrawVertexArrayElements(i32(span.first), i32(span.count), u64(0));
        }
    }

    """The texture a batch shows for the world (`group` -1) or a brush group,
    after animation."""
    def batch_texture(level: Level, batch: SurfaceBatch, group: int) -> int {
        if batch.texture not in self.anim_frames {
            return self.textures[batch.texture];
        }
        if group < 0 {
            return self.textures[self.frame_texture(level, batch.texture, 0, True)];
        }
        lead = self.brush_groups[group].lead;
        return self.textures[self.frame_texture(level, batch.texture, level.bsp.faces[lead].frame, lead < self.world_faces)];
    }

    """Draw one surface batch: the visible world faces, then each brush group
    holding some, at its placement. With `textured`, each binds the batch's
    texture (after animation) to slot 0; `tinted` programs take a group's
    per-frame light. Passes whose order matters (blended ones, shader
    stages) draw batch by batch this way."""
    def draw_batch(program: GpuProgram, level: Level, batch: SurfaceBatch, view: VisibleIndices, textured: bool, tinted: bool = False) {
        if batch.id in view.lists.spans {
            self.place(program, -1, tinted);
            if textured {
                rlEnableTexture(u32(self.batch_texture(level, batch, -1)));
            }
            self.draw_spans(view.lists.spans[batch.id], view.buffers);
        }
        if batch.id not in self.brush_batches {
            return;
        }
        for g in range(len(self.brush_groups)) {
            group = self.brush_groups[g];
            if batch.id not in group.spans {
                continue;
            }
            self.place(program, g, tinted);
            if textured {
                rlEnableTexture(u32(self.batch_texture(level, batch, g)));
            }
            self.draw_spans(group.spans[batch.id], self.brush_buffers);
        }
    }

    """Draw an opaque pass: the world's batches, then each brush group's
    batches of the pass at its placement once, since depth testing makes
    the order free. Two-sided batches draw with culling off."""
    def draw_opaque_pass(program: GpuProgram, level: Level, kind: int, view: VisibleIndices) {
        if kind in view.shown {
            for id in view.shown[kind] {
                batch = self.batches[id];
                self.place(program, -1, True);
                if batch.two_sided {
                    rlDisableBackfaceCulling();
                }
                rlEnableTexture(u32(self.batch_texture(level, batch, -1)));
                self.draw_spans(view.lists.spans[id], view.buffers);
                if batch.two_sided {
                    rlEnableBackfaceCulling();
                }
            }
        }
        for g in range(len(self.brush_groups)) {
            group = self.brush_groups[g];
            if kind not in group.shown {
                continue;
            }
            for id in group.shown[kind] {
                batch = self.batches[id];
                self.place(program, g, True);
                if batch.two_sided {
                    rlDisableBackfaceCulling();
                }
                rlEnableTexture(u32(self.batch_texture(level, batch, g)));
                self.draw_spans(group.spans[id], self.brush_buffers);
                if batch.two_sided {
                    rlEnableBackfaceCulling();
                }
            }
        }
    }

    """The batches holding spans, by pass, in batch order."""
    def batches_by_pass(spans: dict[int, list[IndexSpan]]) -> dict[int, list[int]] {
        shown: dict[int, list[int]] = {};
        for id in sorted(spans.keys()) {
            kind = self.batches[id].kind;
            if kind not in shown {
                shown[kind] = [];
            }
            shown[kind].append(id);
        }
        return shown;
    }

    """Set uniforms only when their value changed: a program keeps its
    uniforms, so per-stage values that repeat cost no call."""
    def put_vec4s(program: GpuProgram, name: str, packed: bytes) {
        if program.id not in self.uniform_values {
            self.uniform_values[program.id] = {};
        }
        known = self.uniform_values[program.id];
        if name in known and known[name] == packed {
            return;
        }
        known[name] = packed;
        program.set_vec4s(name, packed);
    }

    def put_int(program: GpuProgram, name: str, value: int) {
        if program.id not in self.uniform_ints {
            self.uniform_ints[program.id] = {};
        }
        known = self.uniform_ints[program.id];
        if name in known and known[name] == value {
            return;
        }
        known[name] = value;
        program.set_int(name, value);
    }

    def put_float(program: GpuProgram, name: str, value: float) {
        if program.id not in self.uniform_values {
            self.uniform_values[program.id] = {};
        }
        known = self.uniform_values[program.id];
        packed = struct.pack("<f", value);
        if name in known and known[name] == packed {
            return;
        }
        known[name] = packed;
        program.set_float(name, value);
    }

    """Whether a batch has anything to draw this frame."""
    def batch_shown(batch: SurfaceBatch, view: VisibleIndices) -> bool {
        return batch.id in view.lists.spans or batch.id in self.brush_batches;
    }

    """The eight dynamic lights as the lit and base shaders read them: where,
    how far and what colour, and the light below which a Q1/Q2 surface takes
    none of it (Q1 dl->minlight, Q2 DLIGHT_CUTOFF 64)."""
    def set_dynamic_lights(program: GpuProgram, level: Level) {
        positions: list[float] = [];
        colors: list[float] = [];
        cutoff = level.bsp.game == "q2";
        for i in range(8) {
            if i < len(level.lighting.dynamic) {
                flash = level.lighting.dynamic[i];
                positions.extend([flash.origin.x, flash.origin.y, flash.origin.z, flash.radius]);
                colors.extend([flash.color.x, flash.color.y, flash.color.z, 64.0 if cutoff else flash.minlight]);
            } else {
                positions.extend([0.0, 0.0, 0.0, 0.0]);
                colors.extend([0.0, 0.0, 0.0, 0.0]);
            }
        }
        program.set_vec4s("flashPosition", pack_floats(positions));
        program.set_vec4s("flashColor", pack_floats(colors));
    }

    def draw(level: Level, faces: list[int], eye: Vec3) -> int {
        self.lighting = level.lighting;
        self.draw_sky(eye, level.sky_rotate * self.time, level.sky_axis);
        self.draw_clouds(level, eye);
        if not self.chunks {
            return 0;
        }
        view = self.visible_indices(level, faces);
        self.update_brushes(level);
        if self.single_pass {
            self.draw_single_pass(level, view, eye);
            self.draw_layered(level, view, eye);
            self.draw_fog(level, view, eye);
        } else {
            self.draw_lightmapped(level, view);
            self.draw_q1_sky(level, view, eye);
            self.draw_liquids(level, view);
        }
        return view.lists.faces + self.brush_count;
    }

    """Q1/Q2 lightmapped surfaces in one pass: texture, light styles, dynamic
    lights and fullbrights (world_mesh LIT_FS)."""
    def draw_lightmapped(level: Level, view: VisibleIndices) {
        if PASS_LIT not in self.pass_batches {
            return;
        }
        program = self.lit_program;
        self.begin_batches(program);
        program.set_matrix("viewProjection", view_projection());
        if self.styles_dirty {
            program.set_vec4s("lightStyles", pack_floats(self.style_values));
            self.styles_dirty = False;
        }
        self.set_dynamic_lights(program, level);
        rlActiveTextureSlot(i32(1));
        rlEnableTexture(u32(self.atlas));
        rlActiveTextureSlot(i32(0));
        self.draw_opaque_pass(program, level, PASS_LIT, view);
        self.end_batches(program);
    }

    """gl_warp.c EmitSkyPolys: both Q1 sky layers in one pass (world_mesh SKY_VS)."""
    def draw_q1_sky(level: Level, view: VisibleIndices, eye: Vec3) {
        if PASS_SKY not in self.pass_batches {
            return;
        }
        program = self.sky_program;
        self.begin_batches(program);
        program.set_matrix("viewProjection", view_projection());
        set_uniform_vec3(program, "eye", eye);
        program.set_float("skyTime", self.time);
        for batch in self.pass_batches[PASS_SKY] {
            if not self.batch_shown(batch, view) {
                continue;
            }
            layers = self.sky_layers[batch.texture];
            rlActiveTextureSlot(i32(1));
            rlEnableTexture(u32(layers[1]));
            rlActiveTextureSlot(i32(0));
            rlEnableTexture(u32(layers[0]));
            self.draw_batch(program, level, batch, view, False);
        }
        self.end_batches(program);
    }

    """Liquids and Q2's translucent surfaces, unlit as the originals draw them:
    gl_warp.c EmitWaterPolys turbulence per pixel (8 texels of sine sway at
    one radian per second), Q2 SURF_FLOWING's scroll, then the 33% and 66%
    translucent faces blended over the world."""
    def draw_liquids(level: Level, view: VisibleIndices) {
        # Q2 flowing surfaces scroll 64 texels every two seconds.
        drift = -64.0 * (self.time * 0.5 - float(int(self.time * 0.5)));
        program = self.warp_program;
        started = False;
        for kind in [PASS_LIQUID, PASS_TRANSLUCENT] {
            if kind not in self.pass_batches {
                continue;
            }
            if not started {
                self.begin_batches(program);
                program.set_matrix("viewProjection", view_projection());
                program.set_float("warpTime", self.time);
                started = True;
            }
            if kind == PASS_TRANSLUCENT {
                BeginBlendMode(i32(0));
                self.resume(program);
                rlDisableDepthMask();
            }
            for batch in self.pass_batches[kind] {
                if not self.batch_shown(batch, view) {
                    continue;
                }
                texture = level.bsp.textures[batch.texture];
                set_uniform_vec2(program, "warpSize", float(texture.width), float(texture.height));
                self.put_float(program, "warpScroll", drift if batch.sub == 1 else 0.0);
                self.put_float(program, "warpAmount", 1.0 if batch.sub < 2 else 0.0);
                self.draw_batch(program, level, batch, view, True);
            }
            if kind == PASS_TRANSLUCENT {
                rlEnableDepthMask();
                EndBlendMode();
                self.resume(program);
            }
        }
        if started {
            self.end_batches(program);
        }
    }

    """Q3 single-pass surfaces (lightmap or vertex light, alphaFunc, dynamic
    lights), then additive shaders over them without depth writes."""
    def draw_single_pass(level: Level, view: VisibleIndices, eye: Vec3) {
        program = self.base_program;
        self.begin_batches(program);
        program.set_matrix("viewProjection", view_projection());
        self.set_dynamic_lights(program, level);
        rlActiveTextureSlot(i32(1));
        rlEnableTexture(u32(self.atlas));
        rlActiveTextureSlot(i32(0));
        self.draw_opaque_pass(program, level, PASS_BASE, view);
        for kind in [PASS_ADDITIVE] {
            if kind not in self.pass_batches {
                continue;
            }
            if kind == PASS_ADDITIVE {
                BeginBlendMode(i32(1));
                self.resume(program);
                rlDisableDepthMask();
            }
            for batch in self.pass_batches[kind] {
                if not self.batch_shown(batch, view) {
                    continue;
                }
                if batch.two_sided {
                    rlDisableBackfaceCulling();
                }
                self.draw_batch(program, level, batch, view, True, tinted=True);
                if batch.two_sided {
                    rlEnableBackfaceCulling();
                }
            }
            if kind == PASS_ADDITIVE {
                rlEnableDepthMask();
                EndBlendMode();
                self.resume(program);
            }
        }
        self.end_batches(program);
    }

    """The shared view and fog uniforms of the stage and fog programs."""
    def set_view_uniforms(program: GpuProgram, level: Level, eye: Vec3) {
        program.set_matrix("viewProjection", view_projection());
        set_uniform_vec3(program, "eye", eye);
        set_uniform_vec3(program, "viewForward", self.view_forward);
        if not level.bsp.fogs {
            return;
        }
        planes: list[float] = [];
        colors: list[float] = [];
        for fog in level.bsp.fogs[:WORLD_FOG_LIMIT] {
            if fog.has_surface {
                planes.extend([fog.inward.x, fog.inward.y, fog.inward.z, fog.offset]);
            } else {
                planes.extend([0.0, 0.0, 0.0, 1.0e9]);
            }
            colors.extend([
                float(min(255, int(fog.color.x * 255.0))) / 255.0,
                float(min(255, int(fog.color.y * 255.0))) / 255.0,
                float(min(255, int(fog.color.z * 255.0))) / 255.0,
                fog.depth
            ]);
        }
        program.set_vec4s("fogPlane", pack_floats(planes));
        program.set_vec4s("fogColor", pack_floats(colors));
    }

    """Plan every Q3 shader stage for the stage shader (StagePlan) and the
    orders draw_layered walks them in."""
    def plan_stages(level: Level) {
        self.stage_plans = {};
        self.opaque_plans = [];
        self.translucent_shaders = [];
        self.portal_shaders = [];
        if PASS_LAYERED not in self.pass_batches {
            return;
        }
        keyed: list[list[tuple[str, int]]] = [];
        for batch in self.pass_batches[PASS_LAYERED] {
            t = batch.texture;
            if t not in level.surface_stages or t not in self.stage_images {
                continue;
            }
            stages = level.surface_stages[t];
            deforms = level.surface_deforms[t] if t in level.surface_deforms else [];
            plans: list[StagePlan] = [];
            for k in range(self.stage_count(level, t)) {
                plans.append(self.plan_stage(level, t, k, batch, stages, deforms));
            }
            self.stage_plans[t] = plans;
            if t in level.portal_ranges {
                self.portal_shaders.append(t);
            } elif stages[0].blend == "opaque" {
                for k in range(len(plans)) {
                    while len(keyed) <= k {
                        keyed.append([]);
                    }
                    keyed[k].append((plans[k].key, t));
                }
            } else {
                self.translucent_shaders.append(t);
            }
        }
        for k in range(len(keyed)) {
            self.opaque_plans.append([self.stage_plans[pair[1]][k] for pair in sorted(keyed[k])]);
        }
    }

    def plan_stage(level: Level, t: int, k: int, batch: SurfaceBatch, stages: list[ModelStage], deforms: list[Deform]) -> StagePlan {
        stage = stages[k];
        blend = stage_blend(stage, k);
        plan = StagePlan(
            texture=t,
            batch=batch,
            stage=stage,
            deforms=deforms,
            key=self.stage_key(level, t, k),
            blended=blend[0] == 1,
            source=blend[1],
            destination=blend[2],
            depth_write=stage.depth_write or blend[0] == 0,
            two_sided=level.bsp.textures[t].two_sided or t in level.surface_deforms,
            images=self.stage_images[t][k],
            light=self.stage_images[t][k][0] < 0,
            rgb_mode=1 if stage.rgb == "vertex" else 0,
            fog_mode=fog_adjustment(stages[0], stage) if level.bsp.fogs else 0
        );
        if stage.alpha == "vertex" {
            plan.alpha_mode = 1;
        } elif stage.alpha == "portal" {
            plan.alpha_mode = 2;
        } elif stage.alpha == "specular" {
            plan.alpha_mode = 3;
        }
        if plan.light {
            plan.tc_gen = 1;
        } elif stage.environment {
            plan.tc_gen = 2;
        } elif stage.vectors {
            plan.tc_gen = 3;
        }
        if stage.rgb != "wave" and stage.alpha != "wave" {
            plan.tint = stage_tint(stage, 0.0);
        }
        if all([mod.kind in ["scale", "transform"] for mod in stage.mods]) {
            plan.tcmods = packed_tcmods(stage, 0.0);
            plan.tc_steps = len(tcmod_steps(stage, 0.0));
        }
        if not any([deform.kind == "move" for deform in deforms]) {
            plan.deform_values = packed_deforms(deforms, 0.0);
            plan.deform_count = len(plan.deform_values[0]) // 16 if plan.deform_values else 0;
        }
        return plan;
    }

    """Q3 layered surfaces, stage by stage (tr_shade.c RB_StageIteratorGeneric):
    each stage's image or animMap frame, blend, colour and alpha generators,
    texture modifiers and environment mapping, in the stage shader, in the
    orders plan_stages worked out."""
    def draw_layered(level: Level, view: VisibleIndices, eye: Vec3) {
        if not self.stage_plans {
            return;
        }
        shown: dict[int, bool] = {};
        for (t, plans) in self.stage_plans.items() {
            if self.batch_shown(plans[0].batch, view) {
                shown[t] = True;
            }
        }
        if not shown {
            return;
        }
        program = self.stage_program;
        self.stage_state = "";
        # Portal shaders sort first (SS_PORTAL), over the view rendered through them.
        for t in self.portal_shaders {
            if t in shown {
                self.use_stage_state("backdrop", False, 1, 0, True, True);
                deforms = level.surface_deforms[t] if t in level.surface_deforms else [];
                self.draw_portal_backdrop(level, view.portal_faces[t] if t in view.portal_faces else [], deforms, eye);
                self.stage_state = "";
                self.begin_stages(program, level, eye);
                for plan in self.stage_plans[t] {
                    self.draw_stage(program, level, plan, view);
                }
                self.end_batches(program);
            }
        }
        self.begin_stages(program, level, eye);
        # Opaque shaders next, stage by stage across all of them and grouped by
        # blend state: each later stage only touches pixels where its own
        # surface won the depth test, so the order between shaders does not
        # matter, and every state change costs a batch flush.
        for plans in self.opaque_plans {
            for plan in plans {
                if plan.texture in shown {
                    self.draw_stage(program, level, plan, view);
                }
            }
        }
        # Translucent shaders last, each stage in order.
        for t in self.translucent_shaders {
            if t in shown {
                for plan in self.stage_plans[t] {
                    self.draw_stage(program, level, plan, view);
                }
            }
        }
        self.use_stage_state("", False, 1, 0, True, False);
        self.end_batches(program);
    }

    def begin_stages(program: GpuProgram, level: Level, eye: Vec3) {
        self.begin_batches(program);
        self.set_view_uniforms(program, level, eye);
        self.put_float(program, "time", self.time);
        self.put_int(program, "turbFromNormal", 0);
    }

    def stage_count(level: Level, t: int) -> int {
        return min(len(level.surface_stages[t]), len(self.stage_images[t]));
    }

    """The GL state a stage needs, as a key: blended or not, the blend
    factors, depth writes and culling."""
    def stage_key(level: Level, t: int, k: int) -> str {
        blend = stage_blend(level.surface_stages[t][k], k);
        two_sided = level.bsp.textures[t].two_sided or t in level.surface_deforms;
        writes = level.surface_stages[t][k].depth_write or blend[0] == 0;
        return str(blend[0]) + ":" + str(blend[1]) + ":" + str(blend[2]) + ":" + str(writes) + ":" + str(two_sided);
    }

    """Switch GL state only when it differs from the current one; returns
    whether it switched (and so flushed raylib's batch)."""
    def use_stage_state(key: str, blended: bool, source: int, destination: int, depth_write: bool, two_sided: bool) -> bool {
        if key == self.stage_state {
            return False;
        }
        rlDrawRenderBatchActive();
        if self.stage_blended {
            EndBlendMode();
        }
        rlEnableDepthMask();
        rlEnableBackfaceCulling();
        self.stage_blended = False;
        if blended {
            rlSetBlendFactors(i32(source), i32(destination), i32(32774));
            BeginBlendMode(i32(6));
            self.stage_blended = True;
        }
        if not depth_write {
            rlDisableDepthMask();
        }
        if two_sided {
            rlDisableBackfaceCulling();
        }
        self.stage_state = key;
        return True;
    }

    """A stage's tcMods at this moment as the stage shader's affine steps."""
    def set_tcmods(program: GpuProgram, stage: ModelStage) {
        packed = packed_tcmods(stage, self.time);
        self.put_int(program, "tcSteps", len(packed[0]) // 16);
        self.put_vec4s(program, "tcRowS", packed[0]);
        self.put_vec4s(program, "tcRowT", packed[1]);
        self.put_vec4s(program, "tcTurb", packed[2]);
    }

    """A shader's deformVertexes as the stage shader reads them."""
    def set_deforms(program: GpuProgram, values: list[bytes]) {
        self.put_int(program, "deformCount", len(values[0]) // 16 if values else 0);
        if values and values[0] {
            self.put_vec4s(program, "deformInfo", values[0]);
            self.put_vec4s(program, "deformWave", values[1]);
            self.put_vec4s(program, "deformVector", values[2]);
        }
    }

    """One planned stage of one shader over its visible faces."""
    def draw_stage(program: GpuProgram, level: Level, plan: StagePlan, view: VisibleIndices) {
        if self.use_stage_state(plan.key, plan.blended, plan.source, plan.destination, plan.depth_write, plan.two_sided) {
            self.resume(program);
        }
        stage = plan.stage;
        images = plan.images;
        rlEnableTexture(u32(self.atlas if plan.light else (images[0] if len(images) == 1 else images[stage_frame(self.time, stage.frequency, len(images))])));
        self.put_vec4s(program, "tint", plan.tint if plan.tint else stage_tint(stage, self.time));
        self.put_int(program, "rgbMode", plan.rgb_mode);
        self.put_int(program, "alphaMode", plan.alpha_mode);
        if plan.alpha_mode == 2 {
            self.put_float(program, "portalRange", max(1.0, stage.alpha_const));
        }
        self.put_int(program, "tcGen", plan.tc_gen);
        if plan.tc_gen == 3 {
            set_uniform_vec3(program, "tcVectorS", stage.vectors[0]);
            set_uniform_vec3(program, "tcVectorT", stage.vectors[1]);
        }
        self.put_int(program, "lightmapStage", 1 if plan.light else 0);
        self.put_int(program, "fogMode", plan.fog_mode);
        if plan.tcmods {
            self.put_int(program, "tcSteps", plan.tc_steps);
            self.put_vec4s(program, "tcRowS", plan.tcmods[0]);
            self.put_vec4s(program, "tcRowT", plan.tcmods[1]);
            self.put_vec4s(program, "tcTurb", plan.tcmods[2]);
        } else {
            self.set_tcmods(program, stage);
        }
        self.set_deforms(program, plan.deform_values if plan.deform_values or not plan.deforms else packed_deforms(plan.deforms, self.time));
        self.draw_batch(program, level, plan.batch, view, False);
    }

    """What lies behind a portal surface before its stages blend over it: the
    view rendered through it this frame, sampled in screen space, or black
    for a portal whose view was not rendered. Portal surfaces are few, so
    they still go through raylib's batch."""
    def draw_portal_backdrop(level: Level, faces: list[int], deforms: list[Deform], eye: Vec3) {
        if self.portal_image != 0 and self.portal_shader.id == u32(0) {
            self.portal_shader = LoadShaderFromMemory(
                "#version 330\nin vec3 vertexPosition; uniform mat4 mvp;\n"
                    + "void main(){ gl_Position=mvp*vec4(vertexPosition,1.0); }\n",
                "#version 330\nout vec4 finalColor; uniform sampler2D texture0; uniform vec2 screenSize;\n"
                    + "void main(){ finalColor=vec4(texture(texture0, gl_FragCoord.xy/screenSize).rgb, 1.0); }\n"
            );
            self.portal_size = int(GetShaderLocation(self.portal_shader, "screenSize"));
        }
        for index in faces {
            face = level.bsp.faces[index];
            # Only the side facing the eye: a mirror's own surface lies on the
            # clip plane of the view rendered through it.
            if face.planar
                and not face.two_sided
                and face.turn is None
                and face.normal.dot(eye.sub(face.motion)) - face.plane_dist < -0.01 {
                continue;
            }
            plane = surface_plane(face);
            shown = self.portal_image != 0
                and plane[0].dot(self.portal_normal) > 0.999
                and abs(plane[1].x - self.portal_dist) < 1.0;
            shape = deform_face(face, deforms, eye, self.time) if deforms else None;
            if shown {
                rlDrawRenderBatchActive();
                rlEnableShader(self.portal_shader.id);
                rlSetUniform(i32(self.portal_size), struct.pack("<ff", self.portal_width, self.portal_height), i32(1), i32(1));
                rlDisableShader();
                BeginShaderMode(self.portal_shader);
                rlSetTexture(u32(self.portal_image));
            } else {
                rlSetTexture(u32(self.white));
            }
            indices = face.indices;
            if not indices {
                indices = [];
                for corner in range(1, len(face.vertices) - 1) {
                    indices.extend([0, corner + 1, corner]);
                }
            }
            rlBegin(i32(4));
            level_color = 255 if shown else 0;
            rlColor4ub(u8(level_color), u8(level_color), u8(level_color), u8(255));
            for corner in indices {
                v = shape.points[corner] if shape is not None else face.vertices[corner];
                rlTexCoord2f(f32(0.0), f32(0.0));
                rlVertex3f(f32(v.x), f32(v.y), f32(v.z));
            }
            rlEnd();
            rlDrawRenderBatchActive();
            if shown {
                EndShaderMode();
            }
        }
        rlSetTexture(u32(0));
    }

    """tr_shade.c RB_FogPass over every opaque surface inside a fog volume, and
    over the fog volumes' own surfaces: the fog colour blended by the fog
    image's density at RB_CalcFogTexCoords' coordinates (world_mesh FOG_VS),
    one-sided surfaces first, then two-sided ones with culling off."""
    def draw_fog(level: Level, view: VisibleIndices, eye: Vec3) {
        if not level.bsp.fogs {
            return;
        }
        kinds = [kind for kind in [PASS_FOG, PASS_FOG_TWO_SIDED] if kind in self.pass_batches];
        if not kinds {
            return;
        }
        if self.fog_image == 0 {
            self.fog_image = upload_fog_image();
        }
        program = self.fog_program;
        self.begin_batches(program);
        self.set_view_uniforms(program, level, eye);
        BeginBlendMode(i32(0));
        self.resume(program);
        rlDisableDepthMask();
        rlEnableTexture(u32(self.fog_image));
        for kind in kinds {
            if kind == PASS_FOG_TWO_SIDED {
                rlDisableBackfaceCulling();
            }
            for batch in self.pass_batches[kind] {
                if self.batch_shown(batch, view) {
                    self.draw_batch(program, level, batch, view, False);
                }
            }
            if kind == PASS_FOG_TWO_SIDED {
                rlEnableBackfaceCulling();
            }
        }
        rlEnableDepthMask();
        EndBlendMode();
        self.end_batches(program);
    }

    """Which surfaces take the fog pass (tr_shader.c FinishShader): opaque ones
    (FP_EQUAL) and fog shaders' own (FP_LE); translucent and sky shaders do not.
    Deformed surfaces are left out rather than fogged in their rest pose."""
    def fog_receiver(level: Level, face: Face) -> bool {
        if face.fog_only {
            return True;
        }
        t = face.texture;
        texture = level.bsp.textures[t];
        if face.additive or texture.additive or texture.flags & 4 != 0 or t in self.sky_layers {
            return False;
        }
        if t in level.surface_deforms {
            return False;
        }
        if t in level.surface_stages {
            stages = level.surface_stages[t];
            return bool(stages) and stages[0].blend == "opaque";
        }
        return True;
    }

    def close() {
        self.uniform_values = {};
        self.uniform_ints = {};
        self.stage_plans = {};
        self.opaque_plans = [];
        for program in [self.lit_program, self.warp_program, self.sky_program, self.base_program, self.stage_program, self.fog_program] {
            program.close();
        }
        for mesh in self.chunks {
            mesh.close();
        }
        self.chunks = [];
        for view in self.views {
            view.buffers.close();
        }
        self.views = [];
        self.brush_buffers.close();
        self.brush_groups = [];
        self.brush_signature = [];
        self.cloud_mesh.close();
        self.cloud_height_cached = -1.0;
        self.single_pass = False;
        for id in self.sky {
            rlUnloadTexture(u32(id));
        }
        self.sky = [];
        for id in self.textures {
            rlUnloadTexture(u32(id));
        }
        if self.atlas != 0 {
            rlUnloadTexture(u32(self.atlas));
        }
        for (index, images) in self.stage_images.items() {
            for ids in images {
                for id in ids {
                    if id > 0 and id != self.white {
                        rlUnloadTexture(u32(id));
                    }
                }
            }
        }
        self.stage_images = {};
        for (index, layers) in self.sky_layers.items() {
            for id in layers {
                rlUnloadTexture(u32(id));
            }
        }
        self.sky_layers = {};
        for ids in self.cloud_images {
            for id in ids {
                rlUnloadTexture(u32(id));
            }
        }
        self.cloud_images = [];
        if self.fog_image != 0 {
            rlUnloadTexture(u32(self.fog_image));
            self.fog_image = 0;
        }
        if self.portal_shader.id != u32(0) {
            UnloadShader(self.portal_shader);
            self.portal_shader = Shader(id=u32(0), locs=u64(0));
        }
        if self.white != 0 {
            rlUnloadTexture(u32(self.white));
            self.white = 0;
        }
        self.textures = [];
        self.rects = [];
        self.atlas = 0;
    }
}

"""glRotatef's turn of `point` by `degrees` counter-clockwise about `axis`
(Rodrigues' formula), as R_DrawSkyBox turns a rotating sky."""
def sky_turn(point: Vec3, axis: Vec3, degrees: float) -> Vec3 {
    k = axis.normalized();
    c = math.cos(math.radians(degrees));
    n = math.sin(math.radians(degrees));
    return point.scale(c).add(k.cross(point).scale(n)).add(k.scale(k.dot(point) * (1.0 - c)));
}

"""The vertex attributes of a world chunk (world_mesh WORLD_VERTEX_FORMAT) at
the shaders' fixed locations."""
def world_attributes() -> list[VertexAttribute] {
    return [
        VertexAttribute(location=0, components=3, kind=GL_FLOAT, offset=0),
        VertexAttribute(location=1, components=2, kind=GL_FLOAT, offset=12),
        VertexAttribute(location=2, components=2, kind=GL_FLOAT, offset=20),
        VertexAttribute(location=3, components=4, kind=GL_UNSIGNED_BYTE, normalized=True, offset=28),
        VertexAttribute(location=4, components=3, kind=GL_FLOAT, offset=32),
        VertexAttribute(location=5, components=4, kind=GL_UNSIGNED_BYTE, offset=44),
        VertexAttribute(location=6, components=4, kind=GL_UNSIGNED_BYTE, offset=48),
        VertexAttribute(location=7, components=4, kind=GL_FLOAT, offset=52),
        VertexAttribute(location=8, components=4, kind=GL_FLOAT, offset=68)
    ];
}

"""Whether two faces of a brush model share a placement and entity frame."""
def same_placement(face: Face, lead: Face) -> bool {
    if face.turn is not lead.turn or face.frame != lead.frame {
        return False;
    }
    if face.motion is not lead.motion
        and (face.motion.x != lead.motion.x or face.motion.y != lead.motion.y or face.motion.z != lead.motion.z) {
        return False;
    }
    if face.turn is not None and face.pivot is not lead.pivot
        and (face.pivot.x != lead.pivot.x or face.pivot.y != lead.pivot.y or face.pivot.z != lead.pivot.z) {
        return False;
    }
    return True;
}

"""Whether a brush face is away from where the map placed it."""
def moved_face(face: Face) -> bool {
    return face.turn is not None or face.motion.x != 0.0 or face.motion.y != 0.0 or face.motion.z != 0.0;
}

"""A brush face's placement as a model matrix: turned about its pivot (the
entity origin), then moved: pivot + turn(v - pivot) + motion."""
def placement_matrix(face: Face) -> Matrix {
    turn = face.turn;
    if turn is None {
        return placement_matrix_at(face.motion);
    }
    p = face.pivot;
    turned = turn.apply(p);
    x = p.x - turned.x + face.motion.x;
    y = p.y - turned.y + face.motion.y;
    z = p.z - turned.z + face.motion.z;
    f = turn.forward;
    l = turn.left;
    u = turn.up;
    return Matrix(
        m0=f32(f.x), m4=f32(l.x), m8=f32(u.x), m12=f32(x),
        m1=f32(f.y), m5=f32(l.y), m9=f32(u.y), m13=f32(y),
        m2=f32(f.z), m6=f32(l.z), m10=f32(u.z), m14=f32(z),
        m3=f32(0.0), m7=f32(0.0), m11=f32(0.0), m15=f32(1.0)
    );
}

"""A translation as a model matrix."""
def placement_matrix_at(offset: Vec3) -> Matrix {
    return Matrix(
        m0=f32(1.0), m4=f32(0.0), m8=f32(0.0), m12=f32(offset.x),
        m1=f32(0.0), m5=f32(1.0), m9=f32(0.0), m13=f32(offset.y),
        m2=f32(0.0), m6=f32(0.0), m10=f32(1.0), m14=f32(offset.z),
        m3=f32(0.0), m7=f32(0.0), m11=f32(0.0), m15=f32(1.0)
    );
}

"""A stage's rgbGen and alphaGen colour at time `seconds` (identity, wave or
const; vertex and the per-vertex alphas come from the shader), quantized to
bytes as the vertex colours were, packed as a vec4."""
def stage_tint(stage: ModelStage, seconds: float) -> bytes {
    red = 1.0;
    green = 1.0;
    blue = 1.0;
    if stage.rgb == "wave" {
        level_value = float(int(max(0.0, min(1.0, stage.rgb_wave.at(seconds))) * 255.0)) / 255.0;
        red = level_value;
        green = level_value;
        blue = level_value;
    } elif stage.rgb == "const" {
        red = float(int(max(0.0, min(1.0, stage.rgb_const[0])) * 255.0)) / 255.0;
        green = float(int(max(0.0, min(1.0, stage.rgb_const[1])) * 255.0)) / 255.0;
        blue = float(int(max(0.0, min(1.0, stage.rgb_const[2])) * 255.0)) / 255.0;
    }
    alpha = 1.0;
    if stage.alpha == "wave" {
        alpha = float(int(max(0.0, min(1.0, stage.alpha_wave.at(seconds))) * 255.0)) / 255.0;
    } elif stage.alpha == "const" {
        alpha = float(int(max(0.0, min(1.0, stage.alpha_const)) * 255.0)) / 255.0;
    }
    return pack_floats([red, green, blue, alpha]);
}

"""A stage's tcmod_steps packed for the stage shader: the s rows, the t rows
and the turbs, each a vec4 per step."""
def packed_tcmods(stage: ModelStage, seconds: float) -> list[bytes] {
    rows_s: list[float] = [];
    rows_t: list[float] = [];
    turbs: list[float] = [];
    for step in tcmod_steps(stage, seconds) {
        rows_s.extend([step[0], step[1], step[2], 0.0]);
        rows_t.extend([step[3], step[4], step[5], 0.0]);
        turbs.extend([step[6], step[7], step[8], 0.0]);
    }
    return [pack_floats(rows_s), pack_floats(rows_t), pack_floats(turbs)];
}

"""A shader's deformVertexes packed for the stage shader (at most four):
kind, waveform and spread; the wave; and move's push at time `seconds` or
bulge's width, height and speed."""
def packed_deforms(deforms: list[Deform], seconds: float) -> list[bytes] {
    kinds = {"wave": 1.0, "move": 2.0, "bulge": 3.0, "autosprite": 4.0, "autosprite2": 5.0};
    infos: list[float] = [];
    waves: list[float] = [];
    vectors: list[float] = [];
    for deform in deforms {
        if deform.kind not in kinds or len(infos) >= 16 {
            continue;
        }
        infos.extend([kinds[deform.kind], wave_code(deform.wave.func), deform.spread, 0.0]);
        waves.extend([deform.wave.base, deform.wave.amplitude, deform.wave.phase, deform.wave.frequency]);
        if deform.kind == "move" {
            push = deform.vector.scale(deform.wave.at(seconds));
            vectors.extend([push.x, push.y, push.z, 0.0]);
        } else {
            vectors.extend([deform.width, deform.height, deform.speed, 0.0]);
        }
    }
    return [pack_floats(infos), pack_floats(waves), pack_floats(vectors)];
}

"""tr_image.c R_CreateFogImage: 256x32 white texels whose alpha is R_FogFactor,
the density along s thinned by how much of t lies inside the fog, through the
square-root fog table."""
def fog_density(s: float, t: float) -> float {
    s -= 1.0 / 512.0;
    if s < 0.0 or t < 1.0 / 32.0 {
        return 0.0;
    }
    if t < 31.0 / 32.0 {
        s *= (t - 1.0 / 32.0) / (30.0 / 32.0);
    }
    s = min(1.0, s * 8.0);
    return math.pow(float(int(s * 255.0)) / 255.0, 0.5);
}


"""A stage's blending as [blended, source factor, destination factor]. The
first stage of an opaque shader writes without blending."""
def stage_blend(stage: ModelStage, k: int) -> list[int] {
    if k == 0 and stage.blend == "opaque" {
        return [0, 1, 0];
    }
    if stage.blend == "alpha" {
        return [1, 770, 771];
    }
    if stage.blend == "multiply" {
        return [1, 774, 0];
    }
    if stage.blend == "opaque" {
        return [1, 1, 0];
    }
    if stage.blend == "custom" {
        return [1, gl_factor(stage.blend_source), gl_factor(stage.blend_destination)];
    }
    return [1, 1, 1];
}

"""One tcMod at time `seconds` as an affine map of (s, t): [a, b, c, d, e, f]
with s' = a*s + b*t + c and t' = d*s + e*t + f (tr_shade_calc.c
RB_CalcScrollTexCoords, RB_CalcScaleTexCoords, RB_CalcRotateTexCoords,
RB_CalcStretchTexCoords, RB_CalcTransformTexCoords). Turb is not affine."""
def tcmod_affine(mod: TexMod, seconds: float) -> list[float] {
    if mod.kind == "scroll" {
        return [1.0, 0.0, mod.a * seconds, 0.0, 1.0, mod.b * seconds];
    }
    if mod.kind == "scale" {
        return [mod.a, 0.0, 0.0, 0.0, mod.b, 0.0];
    }
    if mod.kind == "rotate" {
        angle = -mod.a * seconds * math.pi / 180.0;
        c = math.cos(angle);
        n = math.sin(angle);
        return [c, -n, 0.5 - 0.5 * c + 0.5 * n, n, c, 0.5 - 0.5 * n - 0.5 * c];
    }
    if mod.kind == "stretch" {
        value = mod.wave.at(seconds);
        if abs(value) > 0.0001 {
            p = 1.0 / value;
            return [p, 0.0, 0.5 - 0.5 * p, 0.0, p, 0.5 - 0.5 * p];
        }
    } elif mod.kind == "transform" and len(mod.matrix) == 6 {
        return [mod.matrix[0], mod.matrix[2], mod.matrix[4], mod.matrix[1], mod.matrix[3], mod.matrix[5]];
    }
    return [1.0, 0.0, 0.0, 0.0, 1.0, 0.0];
}

"""Apply affine `o` after affine `m`."""
def compose_affine(o: list[float], m: list[float]) -> list[float] {
    return [
        o[0] * m[0] + o[1] * m[3],
        o[0] * m[1] + o[1] * m[4],
        o[0] * m[2] + o[1] * m[5] + o[2],
        o[3] * m[0] + o[4] * m[3],
        o[3] * m[1] + o[4] * m[4],
        o[3] * m[2] + o[4] * m[5] + o[5]
    ];
}

"""A stage's tcMods at time `seconds` folded into one affine map of (s, t):
[a, b, c, d, e, f] with s' = a*s + b*t + c and t' = d*s + e*t + f. Empty
when a tcMod turb makes the result depend on the vertex position."""
def stage_affine(stage: ModelStage, seconds: float) -> list[float] {
    m = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0];
    for mod in stage.mods {
        if mod.kind == "turb" {
            return [];
        }
        m = compose_affine(tcmod_affine(mod, seconds), m);
    }
    return m;
}

"""A stage's tcMods at time `seconds` as the stage shader's steps: each an
affine map (as stage_affine) followed by a turb or not, as [a, b, c, d, e,
f, turb, amplitude, phase + time * frequency]. At most four steps; turbs
beyond the third are dropped."""
def tcmod_steps(stage: ModelStage, seconds: float) -> list[list[float]] {
    steps: list[list[float]] = [];
    m = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0];
    for mod in stage.mods {
        if mod.kind == "turb" {
            if len(steps) < 3 {
                steps.append(m + [1.0, mod.wave.amplitude, mod.wave.phase + seconds * mod.wave.frequency]);
            }
            m = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0];
            continue;
        }
        m = compose_affine(tcmod_affine(mod, seconds), m);
    }
    steps.append(m + [0.0, 0.0, 0.0]);
    return steps;
}

"""tr_shader.c FinishShader adjustColorsForFog: for a translucent shader, 1
fades a stage's colour (GL_ONE GL_ONE, GL_ZERO GL_ONE_MINUS_SRC_COLOR), 2 its
alpha (GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA) and 3 both (GL_ONE
GL_ONE_MINUS_SRC_ALPHA); 0 leaves it alone."""
def fog_adjustment(first: ModelStage, stage: ModelStage) -> int {
    if first.blend == "opaque" or stage.blend == "opaque" {
        return 0;
    }
    source = stage.blend_source.lower();
    destination = stage.blend_destination.lower();
    if stage.blend == "add" or (source == "gl_one" and destination == "gl_one")
        or (source == "gl_zero" and destination == "gl_one_minus_src_color") {
        return 1;
    }
    if stage.blend == "alpha" or (source == "gl_src_alpha" and destination == "gl_one_minus_src_alpha") {
        return 2;
    }
    if source == "gl_one" and destination == "gl_one_minus_src_alpha" {
        return 3;
    }
    return 0;
}

"""tr_shade_calc.c RB_CalcFogTexCoords for one world point."""
def fog_coords(fog: FogVolume, point: Vec3, eye: Vec3, forward: Vec3) -> list[float] {
    s = (forward.dot(point) - forward.dot(eye)) / (fog.depth * 8.0) + 1.0 / 512.0;
    if not fog.has_surface {
        return [s, 31.0 / 32.0];
    }
    eye_t = fog.inward.dot(eye) + fog.offset;
    t = fog.inward.dot(point) + fog.offset;
    if eye_t < 0.0 {
        t = 1.0 / 32.0 if t < 1.0 else 1.0 / 32.0 + 30.0 / 32.0 * t / (t - eye_t);
    } else {
        t = 1.0 / 32.0 if t < 0.0 else 31.0 / 32.0;
    }
    return [s, t];
}

def upload_fog_image() -> int {
    pixels = bytearray();
    for y in range(32) {
        for x in range(256) {
            density = fog_density((float(x) + 0.5) / 256.0, (float(y) + 0.5) / 32.0);
            pixels.extend(bytes([255, 255, 255, int(255.0 * density)]));
        }
    }
    image = rlLoadTexture(bytes(pixels), i32(256), i32(32), i32(7), i32(1));
    if image == u32(0) {
        raise RuntimeError("Fog image upload failed");
    }
    rlTextureParameters(image, i32(10241), i32(9729));
    rlTextureParameters(image, i32(10240), i32(9729));
    rlTextureParameters(image, i32(10242), i32(33071));
    rlTextureParameters(image, i32(10243), i32(33071));
    return int(image);
}

"""An OpenGL blend factor from its Q3 shader spelling."""
def gl_factor(name: str) -> int {
    factors: dict[str, int] = {
        "gl_zero": 0,
        "gl_one": 1,
        "gl_src_color": 768,
        "gl_one_minus_src_color": 769,
        "gl_src_alpha": 770,
        "gl_one_minus_src_alpha": 771,
        "gl_dst_alpha": 772,
        "gl_one_minus_dst_alpha": 773,
        "gl_dst_color": 774,
        "gl_one_minus_dst_color": 775
    };
    return factors[name] if name in factors else 1;
}

obj DeformedShape {
    has points: list[Vec3] = [],
        coords: list[float] = [];
}

"""tr_shade_calc.c RB_CalcDeformVertexes and the autosprite deforms, applied to
a face's placed vertices for this frame."""
def deform_face(face: Face, deforms: list[Deform], eye: Vec3, seconds: float) -> DeformedShape {
    shape = DeformedShape(coords=list(face.uv));
    for v in face.vertices {
        placed = v;
        if face.turn is not None {
            placed = face.pivot.add(face.turn.apply(v.sub(face.pivot)));
        }
        shape.points.append(placed.add(face.motion));
    }
    normal = face.normal;
    for deform in deforms {
        if deform.kind == "wave" {
            for i in range(len(shape.points)) {
                p = shape.points[i];
                offset = (p.x + p.y + p.z) * deform.spread;
                shape.points[i] = p.add(normal.scale(deform.wave.shifted(seconds, offset)));
            }
        } elif deform.kind == "move" {
            push = deform.vector.scale(deform.wave.at(seconds));
            for i in range(len(shape.points)) {
                shape.points[i] = shape.points[i].add(push);
            }
        } elif deform.kind == "bulge" {
            for i in range(len(shape.points)) {
                swell = math.sin(math.pi * 0.25 * shape.coords[i * 2] * deform.width + seconds * deform.speed) * deform.height;
                shape.points[i] = shape.points[i].add(normal.scale(swell));
            }
        } elif deform.kind in ["autosprite", "autosprite2"] and len(shape.points) == 4 {
            middle = shape.points[0].add(shape.points[1]).add(shape.points[2]).add(shape.points[3]).scale(0.25);
            forward = middle.sub(eye).normalized();
            right = forward.cross(Vec3(z=1.0));
            if right.length() < 0.001 {
                right = Vec3(x=1.0);
            }
            right = right.normalized();
            up = right.cross(forward).normalized();
            if deform.kind == "autosprite" {
                # A square billboard of the quad's size with fresh corners.
                radius = shape.points[0].sub(middle).length() * 0.707;
                left = right.scale(-radius);
                upward = up.scale(radius);
                shape.points = [
                    middle.add(left).add(upward),
                    middle.sub(left).add(upward),
                    middle.sub(left).sub(upward),
                    middle.add(left).sub(upward)
                ];
                shape.coords = [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0];
            } else {
                # Keep the long axis; turn the short edges toward the viewer.
                edges = [[0, 1], [1, 2], [2, 3], [3, 0]];
                first = 0;
                for e in range(4) {
                    if shape.points[edges[e][0]].sub(shape.points[edges[e][1]]).length()
                        < shape.points[edges[first][0]].sub(shape.points[edges[first][1]]).length() {
                        first = e;
                    }
                }
                shorts = [edges[first], edges[(first + 2) % 4]];
                ends = [
                    shape.points[shorts[0][0]].add(shape.points[shorts[0][1]]).scale(0.5),
                    shape.points[shorts[1][0]].add(shape.points[shorts[1][1]]).scale(0.5)
                ];
                axis = ends[1].sub(ends[0]);
                across = axis.cross(middle.sub(eye)).normalized();
                moved = list(shape.points);
                for k in range(2) {
                    a = shorts[k][0];
                    b = shorts[k][1];
                    half = shape.points[a].sub(shape.points[b]).length() * 0.5;
                    sign = 1.0 if shape.points[a].sub(ends[k]).dot(across) >= 0.0 else -1.0;
                    moved[a] = ends[k].add(across.scale(half * sign));
                    moved[b] = ends[k].sub(across.scale(half * sign));
                }
                shape.points = moved;
            }
        }
    }
    return shape;
}

"""A stage's tcMods applied in order to (s, t) at a point (tr_shade_calc.c)."""
def apply_tcmods(stage: ModelStage, s: float, t: float, point: Vec3, seconds: float) -> list[float] {
    for mod in stage.mods {
        if mod.kind == "scroll" {
            s += mod.a * seconds;
            t += mod.b * seconds;
        } elif mod.kind == "scale" {
            s *= mod.a;
            t *= mod.b;
        } elif mod.kind == "rotate" {
            angle = -mod.a * seconds * math.pi / 180.0;
            c = math.cos(angle);
            n = math.sin(angle);
            s0 = s - 0.5;
            t0 = t - 0.5;
            s = s0 * c - t0 * n + 0.5;
            t = s0 * n + t0 * c + 0.5;
        } elif mod.kind == "turb" {
            now = mod.wave.phase + seconds * mod.wave.frequency;
            s += math.sin(((point.x + point.z) / 128.0 * 0.125 + now) * 2.0 * math.pi) * mod.wave.amplitude;
            t += math.sin((point.y / 128.0 * 0.125 + now) * 2.0 * math.pi) * mod.wave.amplitude;
        } elif mod.kind == "stretch" {
            value = mod.wave.at(seconds);
            if abs(value) > 0.0001 {
                p = 1.0 / value;
                s = (s - 0.5) * p + 0.5;
                t = (t - 0.5) * p + 0.5;
            }
        } elif mod.kind == "transform" and len(mod.matrix) == 6 {
            # RB_CalcTransformTexCoords: [s t] * [[m00 m01] [m10 m11]] + [t0 t1].
            m = mod.matrix;
            before = s;
            s = before * m[0] + t * m[2] + m[4];
            t = before * m[1] + t * m[3] + m[5];
        }
    }
    return [s, t];
}
