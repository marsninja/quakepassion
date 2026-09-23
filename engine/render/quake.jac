"""Quake polygon rendering through raylib's rlgl batch API."""
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
    ) -> None;
}
import from ..world.level { Level }
import from ..formats.bsp { Face, Texture, FogVolume }
import from ..formats.animated { ModelStage, Deform, stage_frame }
import from ..math.vec3 { Vec3 }
import from ..world.lighting { Lighting }

obj LightRect {
    has x: int = 0,
        y: int = 0;
}

obj QuakeRenderer {
    has lighting: Lighting = Lighting(),
        dynamic_positions: int = -1,
        dynamic_colors: int = -1;
    has textures: list[int] = [],
        emissive: list[int] = [],
        sky: list[int] = [],
        single_pass: bool = False,
        shader: Shader = Shader(id=u32(0), locs=u64(0)),
        atlas: int = 0,
        atlas_size: int = 2048,
        rects: list[LightRect] = [],
        styled: list[int] = [],
        stage_images: dict[int, list[list[int]]] = {},
        sky_layers: dict[int, list[int]] = {},
        anim_frames: dict[int, list[int]] = {},
        anim_alternates: dict[int, list[int]] = {},
        world_faces: int = 0,
        cloud_images: list[list[int]] = [],
        warp_shader: Shader = Shader(id=u32(0), locs=u64(0)),
        warp_time: int = -1,
        warp_size: int = -1,
        warp_scroll: int = -1,
        white: int = 0,
        time: float = 0.0,
        fog_image: int = 0,
        view_forward: Vec3 = Vec3(x=1.0);

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

    def draw_sky(eye: Vec3) {
        if len(self.sky) != 6 {
            return;
        }
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
                for axis in axes[side] {
                    coords.append(base[abs(axis) - 1] * (-1.0 if axis < 0 else 1.0));
                }
                rlTexCoord2f(f32((s + 1.0) * 0.5), f32((1.0 - t) * 0.5));
                rlVertex3f(
                    f32(eye.x + coords[0]),
                    f32(eye.y + coords[1]),
                    f32(eye.z + coords[2])
                );
            }
            rlEnd();
        }
        rlDrawRenderBatchActive();
        rlEnableBackfaceCulling();
        rlEnableDepthMask();
    }

    def upload(level: Level) {
        self.single_pass = level.bsp.game in ["q3", "passion"];
        if self.single_pass {
            # Baked lighting does not need a geometric normal. The batch's
            # normal attribute transports lightmap UV and an enable flag.
            self.shader = LoadShaderFromMemory(
                "#version 330\nin vec3 vertexPosition; in vec2 vertexTexCoord; in vec3 vertexNormal; in vec4 vertexColor;\n"
                    + "uniform mat4 mvp; out vec2 uv; out vec3 light; out vec4 color; out vec3 worldPosition;\n"
                    + "void main(){ uv=vertexTexCoord; light=vertexNormal; color=vertexColor; worldPosition=vertexPosition; gl_Position=mvp*vec4(vertexPosition,1.0); }\n",
                "#version 330\nin vec2 uv; in vec3 light; in vec4 color; in vec3 worldPosition; out vec4 finalColor;\n"
                    + "uniform sampler2D texture0; uniform sampler2D bakedLight; uniform vec4 colDiffuse; uniform vec4 flashPosition[8]; uniform vec4 flashColor[8];\n"
                    + "void main(){ vec4 base=texture(texture0,uv); float mode=floor(mod(light.z,16.0)*0.5+0.1); if((mode==1.0&&base.a<=0.0)||(mode==2.0&&base.a<0.5)||(mode==3.0&&base.a>=0.5)) discard; vec3 lighting=(mod(light.z,2.0)>0.5?texture(bakedLight,light.xy).rgb:vec3(1.0))*color.rgb; if(light.z<16.0){ vec3 n=normalize(cross(dFdx(worldPosition),dFdy(worldPosition))); for(int i=0;i<8;i++){ if(flashPosition[i].w<=0.0) continue; vec3 delta=flashPosition[i].xyz-worldPosition; float distance=length(delta); float a=max(0.0,1.0-distance/flashPosition[i].w); lighting+=flashColor[i].rgb*a*a*max(0.0,dot(n,delta/max(distance,0.001))); }} finalColor=vec4(base.rgb*lighting,color.a)*colDiffuse; }\n"
            );
            location = GetShaderLocation(self.shader, "bakedLight");
            if int(location) < 0 {
                raise RuntimeError("Q3 lightmap shader failed");
            }
            rlEnableShader(self.shader.id);
            rlSetUniform(location, struct.pack("<i", 1), i32(4), i32(1));
            rlDisableShader();
            self.dynamic_positions = int(
                GetShaderLocation(self.shader, "flashPosition[0]")
            );
            self.dynamic_colors = int(GetShaderLocation(self.shader, "flashColor[0]"));
        }
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
                self.emissive.append(0);
                rlTextureParameters(gpu, i32(10242), i32(10497));
                rlTextureParameters(gpu, i32(10243), i32(10497));
                continue;
            }
            if len(texture.encoded) > 0 {
                image_id = self.upload_image(texture);
                self.textures.append(image_id);
                self.emissive.append(0);
                rlTextureParameters(u32(image_id), i32(10241), i32(9729));
                rlTextureParameters(u32(image_id), i32(10240), i32(9729));
                rlTextureParameters(u32(image_id), i32(10242), i32(10497));
                rlTextureParameters(u32(image_id), i32(10243), i32(10497));
                continue;
            }
            rgba = bytearray();
            glow = bytearray();
            has_glow = False;
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
                rgba.append(255);
                lit = level.bsp.game == "q1"
                    and index >= 224
                    and not sky
                    and not texture.name.startswith("*");
                glow.extend(level.palette[index * 3:index * 3 + 3]);
                glow.append(255 if lit else 0);
                has_glow = has_glow or lit;
            }
            id = rlLoadTexture(
                bytes(rgba), i32(texture.width), i32(texture.height), i32(7), i32(1)
            );
            if id == 0 {
                raise RuntimeError("Texture upload failed");
            }
            self.textures.append(int(id));
            glow_id = 0;
            if has_glow {
                glow_id = int(
                    rlLoadTexture(
                        bytes(glow),
                        i32(texture.width),
                        i32(texture.height),
                        i32(7),
                        i32(1)
                    )
                );
                if glow_id == 0 {
                    raise RuntimeError("Fullbright texture upload failed");
                }
                rlTextureParameters(u32(glow_id), i32(10241), i32(9728));
                rlTextureParameters(u32(glow_id), i32(10240), i32(9728));
                rlTextureParameters(u32(glow_id), i32(10242), i32(10497));
                rlTextureParameters(u32(glow_id), i32(10243), i32(10497));
            }
            self.emissive.append(glow_id);
            # Nearest sampling preserves the original palette texels; repeat UVs.
            rlTextureParameters(id, i32(10241), i32(9728));
            rlTextureParameters(id, i32(10240), i32(9728));
            rlTextureParameters(id, i32(10242), i32(10497));
            rlTextureParameters(id, i32(10243), i32(10497));
        }
        pixels = bytearray(b"\xff") * (self.atlas_size * self.atlas_size * 4);
        x = 1;
        y = 1;
        row_height = 0;
        shared: dict[int, LightRect] = {};
        self.styled = [];
        face_index = -1;
        for face in level.bsp.faces {
            face_index += 1;
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
            if x + w + 1 > self.atlas_size {
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
            # Faces lit by an animated or switchable style are relit each frame.
            if any([style != 0 for style in face.styles]) {
                self.styled.append(face_index);
            }
            for ly in range(-1, h + 1) {
                for lx in range(-1, w + 1) {
                    sample = min(max(ly, 0), h - 1) * w + min(max(lx, 0), w - 1);
                    p = ((y + ly) * self.atlas_size + x + lx) * 4;
                    channels = level.bsp.light_channels;
                    for channel in range(3) {
                        brightness = 0;
                        for style in range(len(face.styles)) {
                            brightness += int(
                                level.bsp.lighting[
                                    face.light_offset
                                        + (style * w * h + sample) * channels
                                        + (channel if channels == 3 else 0)
                                ]
                            )
                                * 2;
                        }
                        pixels[p + channel] = min(255, brightness);
                    }
                }
            }
            x += w + 2;
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
        self.upload_stages(level);
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
        face = level.bsp.faces[index];
        sequence = self.anim_frames[t];
        if level.bsp.game == "q1" {
            if face.frame != 0 and t in self.anim_alternates {
                sequence = self.anim_alternates[t];
            }
            return sequence[int(self.time * 5.0) % len(sequence)];
        }
        step = face.frame if index >= self.world_faces else int(self.time * 2.0);
        return sequence[step % len(sequence)];
    }

    """Q3 cloud layers on the sky dome (tr_sky.c): each box vertex's direction
    meets a cloud sphere cloudheight above a 4096-unit world, and s and t are
    the arccosines of that point's direction, before the stage's tcMods."""
    def draw_clouds(level: Level, eye: Vec3) {
        if not self.cloud_images or not level.sky_clouds {
            return;
        }
        rlDrawRenderBatchActive();
        rlDisableDepthMask();
        rlDisableBackfaceCulling();
        world_radius = 4096.0;
        height = level.cloud_height;
        steps = 8;
        # The box sides and top, as (u axis, v axis, fixed axis) directions.
        sides = [
            [Vec3(y=1.0), Vec3(z=1.0), Vec3(x=1.0)],
            [Vec3(y=-1.0), Vec3(z=1.0), Vec3(x=-1.0)],
            [Vec3(x=-1.0), Vec3(z=1.0), Vec3(y=1.0)],
            [Vec3(x=1.0), Vec3(z=1.0), Vec3(y=-1.0)],
            [Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)]
        ];
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
            }
            rlSetTexture(u32(ids[stage_frame(self.time, stage.frequency, len(ids))]));
            shade = 255;
            if stage.rgb == "wave" {
                shade = int(max(0.0, min(1.0, stage.rgb_wave.at(self.time))) * 255.0);
            }
            rlBegin(i32(4));
            rlColor4ub(u8(shade), u8(shade), u8(shade), u8(255));
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
                            coords = apply_tcmods(stage, math.acos(max(-1.0, min(1.0, point.x))), math.acos(max(-1.0, min(1.0, point.y))), point, self.time);
                            rlTexCoord2f(f32(coords[0]), f32(coords[1]));
                            v = eye.add(direction.scale(512.0));
                            rlVertex3f(f32(v.x), f32(v.y), f32(v.z));
                        }
                    }
                }
            }
            rlEnd();
            rlDrawRenderBatchActive();
            if k > 0 or stage.blend != "opaque" {
                EndBlendMode();
            }
        }
        rlEnableBackfaceCulling();
        rlEnableDepthMask();
        rlSetTexture(u32(0));
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

    """gl_warp.c EmitSkyPolys: each sky vertex maps by its direction from the
    eye onto a flattened sphere; the back layer scrolls at 8 units a second and
    the masked front layer at 16, blended over it."""
    def draw_q1_sky(level: Level, batches: list[list[int]], eye: Vec3) {
        for (t, layers) in self.sky_layers.items() {
            if t >= len(batches) or not batches[t] {
                continue;
            }
            for layer in range(2) {
                speed = self.time * (8.0 if layer == 0 else 16.0);
                if layer == 1 {
                    BeginBlendMode(i32(0));
                }
                rlSetTexture(u32(layers[layer]));
                for index in batches[t] {
                    face = level.bsp.faces[index];
                    indices = face.indices;
                    if len(indices) == 0 {
                        indices = [];
                        for triangle in range(1, len(face.vertices) - 1) {
                            indices.extend([0, triangle + 1, triangle]);
                        }
                    }
                    rlBegin(i32(4));
                    rlColor4ub(u8(255), u8(255), u8(255), u8(255));
                    for vertex in indices {
                        v = face.vertices[vertex].add(face.motion);
                        direction = v.sub(eye);
                        direction.z *= 3.0;
                        length = direction.length();
                        scale = 6.0 * 63.0 / max(0.001, length);
                        rlTexCoord2f(f32((speed + direction.x * scale) / 128.0), f32((speed + direction.y * scale) / 128.0));
                        rlVertex3f(f32(v.x), f32(v.y), f32(v.z));
                    }
                    rlEnd();
                }
                rlDrawRenderBatchActive();
                if layer == 1 {
                    EndBlendMode();
                }
            }
        }
        rlSetTexture(u32(0));
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

    """Relight faces whose lightmaps use animated or switched styles, as
    R_AnimateLight and R_BuildLightMap do: each style layer is scaled by its
    current brightness before the layers are added."""
    def animate_styles(level: Level, values: dict[int, float]) {
        if self.atlas == 0 {
            return;
        }
        channels = level.bsp.light_channels;
        for index in self.styled {
            face = level.bsp.faces[index];
            rect = self.rects[index];
            w = face.light_width;
            h = face.light_height;
            pixels = bytearray(b"\xff") * ((w + 2) * (h + 2) * 4);
            scales = [values[style] if style in values else 1.0 for style in face.styles];
            for ly in range(-1, h + 1) {
                for lx in range(-1, w + 1) {
                    sample = min(max(ly, 0), h - 1) * w + min(max(lx, 0), w - 1);
                    p = ((ly + 1) * (w + 2) + lx + 1) * 4;
                    for channel in range(3) {
                        brightness = 0.0;
                        for style in range(len(face.styles)) {
                            brightness += float(
                                int(
                                    level.bsp.lighting[
                                        face.light_offset
                                            + (style * w * h + sample) * channels
                                            + (channel if channels == 3 else 0)
                                    ]
                                )
                            )
                                * 2.0
                                * scales[style];
                        }
                        pixels[p + channel] = min(255, int(brightness));
                    }
                }
            }
            rlUpdateTexture(
                u32(self.atlas),
                i32(rect.x - 1),
                i32(rect.y - 1),
                i32(w + 2),
                i32(h + 2),
                i32(7),
                bytes(pixels)
            );
        }
    }

    """Q3 layered surfaces, stage by stage (tr_shade.c RB_StageIteratorGeneric):
    each stage's image or animMap frame, blend, colour and alpha generators,
    texture modifiers and environment mapping."""
    def draw_layered(level: Level, batches: list[list[int]], eye: Vec3) {
        if not self.stage_images {
            return;
        }
        for (t, images) in self.stage_images.items() {
            if t >= len(batches) or not batches[t] or t not in level.surface_stages {
                continue;
            }
            stages = level.surface_stages[t];
            deforms = level.surface_deforms[t] if t in level.surface_deforms else [];
            two_sided = level.bsp.textures[t].two_sided or bool(deforms);
            if two_sided {
                rlDisableBackfaceCulling();
            }
            for k in range(min(len(stages), len(images))) {
                stage = stages[k];
                ids = images[k];
                texture = self.atlas if ids[0] < 0 else ids[stage_frame(self.time, stage.frequency, len(ids))];
                blended = not (k == 0 and stage.blend == "opaque");
                if blended {
                    source = 1;
                    destination = 1;
                    if stage.blend == "alpha" {
                        source = 770;
                        destination = 771;
                    } elif stage.blend == "multiply" {
                        source = 774;
                        destination = 0;
                    } elif stage.blend == "opaque" {
                        source = 1;
                        destination = 0;
                    } elif stage.blend == "custom" {
                        source = gl_factor(stage.blend_source);
                        destination = gl_factor(stage.blend_destination);
                    }
                    rlSetBlendFactors(i32(source), i32(destination), i32(32774));
                    BeginBlendMode(i32(6));
                    if not stage.depth_write {
                        rlDisableDepthMask();
                    }
                }
                rlSetTexture(u32(texture));
                red = 255;
                green = 255;
                blue = 255;
                if stage.rgb == "wave" {
                    level_value = int(max(0.0, min(1.0, stage.rgb_wave.at(self.time))) * 255.0);
                    red = level_value;
                    green = level_value;
                    blue = level_value;
                } elif stage.rgb == "const" {
                    red = int(max(0.0, min(1.0, stage.rgb_const[0])) * 255.0);
                    green = int(max(0.0, min(1.0, stage.rgb_const[1])) * 255.0);
                    blue = int(max(0.0, min(1.0, stage.rgb_const[2])) * 255.0);
                }
                alpha = 255;
                if stage.alpha == "wave" {
                    alpha = int(max(0.0, min(1.0, stage.alpha_wave.at(self.time))) * 255.0);
                } elif stage.alpha == "const" {
                    alpha = int(max(0.0, min(1.0, stage.alpha_const)) * 255.0);
                }
                for index in batches[t] {
                    face = level.bsp.faces[index];
                    if ids[0] < 0 and face.light_offset < 0 {
                        continue;
                    }
                    shape = deform_face(face, deforms, eye, self.time) if deforms else None;
                    self.stage_polygon(face, self.rects[index], stage, ids[0] < 0, eye, [red, green, blue, alpha], shape);
                }
                rlDrawRenderBatchActive();
                if blended {
                    EndBlendMode();
                    rlEnableDepthMask();
                }
            }
            if two_sided {
                rlEnableBackfaceCulling();
            }
        }
        rlSetTexture(u32(0));
    }

    """One face for one stage: tcGen, then each tcMod in order (tr_shade_calc.c)."""
    def stage_polygon(face: Face, rect: LightRect, stage: ModelStage, light: bool, eye: Vec3, tint: list[int], shape: DeformedShape | None = None) {
        indices = face.indices;
        if len(indices) == 0 {
            indices = [];
            for triangle in range(1, len(face.vertices) - 1) {
                indices.extend([0, triangle + 1, triangle]);
            }
        }
        rlBegin(i32(4));
        for index in indices {
            v = face.vertices[index];
            if shape is not None {
                v = shape.points[index];
            }
            s = 0.0;
            t = 0.0;
            if light {
                s = (face.light_uv[index * 2] + float(rect.x) + 0.5) / float(self.atlas_size);
                t = (face.light_uv[index * 2 + 1] + float(rect.y) + 0.5) / float(self.atlas_size);
            } elif stage.environment {
                viewer = eye.sub(v).normalized();
                d = face.normal.dot(viewer);
                reflected = face.normal.scale(2.0 * d).sub(viewer);
                s = 0.5 + reflected.y * 0.5;
                t = 0.5 - reflected.z * 0.5;
            } elif stage.vectors {
                # tcGen vector: texture axes projected from world position.
                s = v.dot(stage.vectors[0]);
                t = v.dot(stage.vectors[1]);
            } elif shape is not None {
                s = shape.coords[index * 2];
                t = shape.coords[index * 2 + 1];
            } else {
                s = face.uv[index * 2];
                t = face.uv[index * 2 + 1];
            }
            coords = apply_tcmods(stage, s, t, v, self.time);
            s = coords[0];
            t = coords[1];
            red = tint[0];
            green = tint[1];
            blue = tint[2];
            alpha = tint[3];
            if (stage.rgb == "vertex" or stage.alpha == "vertex") and len(face.colors) > index * 4 + 3 {
                if stage.rgb == "vertex" {
                    red = min(255, face.colors[index * 4] * 2);
                    green = min(255, face.colors[index * 4 + 1] * 2);
                    blue = min(255, face.colors[index * 4 + 2] * 2);
                }
                if stage.alpha == "vertex" {
                    alpha = face.colors[index * 4 + 3];
                }
            }
            # tr_shade_calc.c RB_CalcSpecularAlpha: a fixed light at
            # (-960, 1980, 96) reflected toward the viewer, to the 4th power.
            if stage.alpha == "specular" {
                toward = Vec3(x=-960.0, y=1980.0, z=96.0).sub(v).normalized();
                reflected = face.normal.scale(2.0 * face.normal.dot(toward)).sub(toward);
                shine = max(0.0, reflected.dot(eye.sub(v).normalized()));
                alpha = int(min(255.0, shine * shine * shine * shine * 255.0));
            }
            rlColor4ub(u8(red), u8(green), u8(blue), u8(alpha));
            rlTexCoord2f(f32(s), f32(t));
            if face.turn is not None and shape is None {
                v = face.pivot.add(face.turn.apply(v.sub(face.pivot)));
            }
            if shape is None {
                v = v.add(face.motion);
            }
            rlVertex3f(f32(v.x), f32(v.y), f32(v.z));
        }
        rlEnd();
    }

    def polygon(face: Face, rect: LightRect, light: bool) {
        rlBegin(i32(4));
        rlColor4ub(u8(255), u8(255), u8(255), u8(255));
        if face.moving_light {
            center = face.vertices[0].lerp(face.vertices[2], 0.5);
            facing = face.normal;
            turn = face.turn;
            if turn is not None {
                center = face.pivot.add(turn.apply(center.sub(face.pivot)));
                facing = turn.apply(facing);
            }
            color = self.lighting.sample(center.add(face.motion), False).shade(facing);
            rlColor4ub(
                u8(int(min(255.0, max(0.0, color.x * 255.0)))),
                u8(int(min(255.0, max(0.0, color.y * 255.0)))),
                u8(int(min(255.0, max(0.0, color.z * 255.0)))),
                u8(255)
            );
        }
        indices = face.indices;
        if len(indices) == 0 {
            indices = [];
            for triangle in range(1, len(face.vertices) - 1) {
                indices.extend([0, triangle + 1, triangle]);
            }
        }
        for index in indices {
            if self.single_pass {
                if face.light_offset >= 0 {
                    rlNormal3f(
                        f32(
                            (face.light_uv[index * 2] + float(rect.x) + 0.5)
                                / float(self.atlas_size)
                        ),
                        f32(
                            (face.light_uv[index * 2 + 1] + float(rect.y) + 0.5)
                                / float(self.atlas_size)
                        ),
                        f32(1.0 + float(face.alpha_test * 2))
                    );
                } else {
                    rlNormal3f(
                        f32(0.0),
                        f32(0.0),
                        f32(float(face.alpha_test * 2 + (16 if face.emission else 0)))
                    );
                }
            }
            if not light and face.light_offset < 0 and len(face.colors) > 0 {
                rlColor4ub(
                    u8(min(255, face.colors[index * 4] * 2)),
                    u8(min(255, face.colors[index * 4 + 1] * 2)),
                    u8(min(255, face.colors[index * 4 + 2] * 2)),
                    u8(255)
                );
            }
            if light {
                rlTexCoord2f(
                    f32(
                        (face.light_uv[index * 2] + float(rect.x) + 0.5)
                            / float(self.atlas_size)
                    ),
                    f32(
                        (face.light_uv[index * 2 + 1] + float(rect.y) + 0.5)
                            / float(self.atlas_size)
                    )
                );
            } else {
                rlTexCoord2f(f32(face.uv[index * 2]), f32(face.uv[index * 2 + 1]));
            }
            v = face.vertices[index];
            turn = face.turn;
            if turn is not None {
                # Rotating brush models turn about their entity origin.
                v = face.pivot.add(turn.apply(v.sub(face.pivot)));
            }
            rlVertex3f(
                f32(v.x + face.motion.x),
                f32(v.y + face.motion.y),
                f32(v.z + face.motion.z)
            );
        }
        rlEnd();
    }

    def draw(level: Level, faces: list[int], eye: Vec3) -> int {
        self.lighting = level.lighting;
        self.draw_sky(eye);
        self.draw_clouds(level, eye);
        # BSP winding and normal consistently face the empty side of each plane.
        batches: list[list[int]] = [];
        for texture in self.textures {
            batches.append([]);
        }
        count = 0;
        fogged: list[int] = [];
        for index in sorted(faces) {
            face = level.bsp.faces[index];
            # Turned faces skip plane culling; their stored plane is unrotated.
            if face.hidden
                or len(face.vertices) < 3
                or (
                    face.planar
                    and not face.two_sided
                    and face.turn is None
                    and face.normal.dot(eye.sub(face.motion)) - face.plane_dist < -0.01
                ) {
                continue;
            }
            if face.fog_only {
                fogged.append(index);
                continue;
            }
            batches[face.texture].append(index);
            if face.fog >= 0 {
                fogged.append(index);
            }
            count += 1;
        }
        if self.single_pass {
            positions = bytearray();
            colors = bytearray();
            for i in range(8) {
                if i < len(level.lighting.dynamic) {
                    flash = level.lighting.dynamic[i];
                    positions.extend(
                        struct.pack(
                            "<ffff",
                            flash.origin.x,
                            flash.origin.y,
                            flash.origin.z,
                            flash.radius
                        )
                    );
                    colors.extend(
                        struct.pack(
                            "<ffff", flash.color.x, flash.color.y, flash.color.z, 0.0
                        )
                    );
                } else {
                    positions.extend(struct.pack("<ffff", 0.0, 0.0, 0.0, 0.0));
                    colors.extend(struct.pack("<ffff", 0.0, 0.0, 0.0, 0.0));
                }
            }
            rlEnableShader(self.shader.id);
            rlSetUniform(i32(self.dynamic_positions), bytes(positions), i32(3), i32(8));
            rlSetUniform(i32(self.dynamic_colors), bytes(colors), i32(3), i32(8));
            rlDisableShader();
            BeginShaderMode(self.shader);
            rlActiveTextureSlot(i32(1));
            rlEnableTexture(u32(self.atlas));
            rlActiveTextureSlot(i32(0));
        }
        for t in range(len(batches)) {
            if self.single_pass and level.bsp.textures[t].additive {
                continue;
            }
            if t in self.stage_images or t in self.sky_layers {
                continue;
            }
            # Flush only at culling-state boundaries: flushing every texture
            # serializes small GPU batches and severely reduces frame rate.
            if level.bsp.textures[t].two_sided {
                rlDrawRenderBatchActive();
                rlDisableBackfaceCulling();
            }
            rlSetTexture(u32(self.textures[t]));
            animated = t in self.anim_frames;
            bound = t;
            for index in batches[t] {
                face = level.bsp.faces[index];
                if face.warp or face.opacity < 1.0 {
                    continue;
                }
                if animated {
                    shown = self.shown_texture(level, t, index);
                    if shown != bound {
                        bound = shown;
                        rlSetTexture(u32(self.textures[shown]));
                    }
                }
                self.polygon(face, self.rects[index], False);
            }
            if level.bsp.textures[t].two_sided {
                rlDrawRenderBatchActive();
                rlEnableBackfaceCulling();
            }
        }
        rlDrawRenderBatchActive();
        if self.single_pass {
            BeginBlendMode(i32(1));
            rlDisableDepthMask();
            for t in range(len(batches)) {
                if not level.bsp.textures[t].additive or t in self.stage_images {
                    continue;
                }
                if level.bsp.textures[t].two_sided {
                    rlDisableBackfaceCulling();
                }
                rlSetTexture(u32(self.textures[t]));
                for index in batches[t] {
                    self.polygon(level.bsp.faces[index], self.rects[index], False);
                }
                rlDrawRenderBatchActive();
                rlEnableBackfaceCulling();
            }
            rlEnableDepthMask();
            EndBlendMode();
            EndShaderMode();
            rlActiveTextureSlot(i32(1));
            rlDisableTexture();
            rlActiveTextureSlot(i32(0));
            rlSetTexture(u32(0));
            self.draw_layered(level, batches, eye);
            self.draw_fog(level, fogged, eye);
            return count;
        }
        self.draw_q1_sky(level, batches, eye);
        # raylib BLEND_MULTIPLIED: destination color times lightmap intensity.
        BeginBlendMode(i32(2));
        rlSetTexture(u32(self.atlas));
        for batch in batches {
            for index in batch {
                face = level.bsp.faces[index];
                if face.light_offset >= 0 and not face.warp and face.opacity >= 1.0 {
                    self.polygon(face, self.rects[index], True);
                }
            }
        }
        rlDrawRenderBatchActive();
        EndBlendMode();
        # Restore palette fullbrights after lightmap multiplication.
        for t in range(len(batches)) {
            if self.emissive[t] == 0 {
                continue;
            }
            rlSetTexture(u32(self.emissive[t]));
            for index in batches[t] {
                face = level.bsp.faces[index];
                if not face.warp and face.opacity >= 1.0 {
                    shown = self.shown_texture(level, t, index);
                    if shown != t {
                        if self.emissive[shown] == 0 {
                            continue;
                        }
                        rlSetTexture(u32(self.emissive[shown]));
                    }
                    self.polygon(face, self.rects[index], False);
                    if shown != t {
                        rlSetTexture(u32(self.emissive[t]));
                    }
                }
            }
        }
        rlDrawRenderBatchActive();
        rlSetTexture(u32(0));
        self.draw_liquids(level, batches);
        return count;
    }

    """tr_shade.c RB_FogPass over every opaque surface inside a fog volume, and
    over the fog volumes' own surfaces: the fog colour blended by the fog
    image's density at RB_CalcFogTexCoords' coordinates. s is the depth along
    the view scaled by 1 / (8 * distanceToOpaque); t clips the fog at its
    visible surface, cutting the distance where the eye is outside it."""
    def draw_fog(level: Level, fogged: list[int], eye: Vec3) {
        if not fogged or not level.bsp.fogs {
            return;
        }
        if self.fog_image == 0 {
            self.fog_image = upload_fog_image();
        }
        rlDrawRenderBatchActive();
        BeginBlendMode(i32(0));
        rlDisableDepthMask();
        rlSetTexture(u32(self.fog_image));
        forward = self.view_forward;
        for index in fogged {
            face = level.bsp.faces[index];
            fog = level.bsp.fogs[face.fog] if face.fog >= 0 else None;
            if fog is None or face.hidden or not self.fog_receiver(level, face) {
                continue;
            }
            indices = face.indices;
            if not indices {
                indices = [];
                for corner in range(1, len(face.vertices) - 1) {
                    indices.extend([0, corner + 1, corner]);
                }
            }
            if face.two_sided or face.fog_only {
                rlDrawRenderBatchActive();
                rlDisableBackfaceCulling();
            }
            rlBegin(i32(4));
            rlColor4ub(
                u8(min(255, int(fog.color.x * 255.0))),
                u8(min(255, int(fog.color.y * 255.0))),
                u8(min(255, int(fog.color.z * 255.0))),
                u8(255)
            );
            for corner in indices {
                v = face.vertices[corner];
                if face.turn is not None {
                    v = face.pivot.add(face.turn.apply(v.sub(face.pivot)));
                }
                v = v.add(face.motion);
                st = fog_coords(fog, v, eye, forward);
                rlTexCoord2f(f32(st[0]), f32(st[1]));
                rlVertex3f(f32(v.x), f32(v.y), f32(v.z));
            }
            rlEnd();
            if face.two_sided or face.fog_only {
                rlDrawRenderBatchActive();
                rlEnableBackfaceCulling();
            }
        }
        rlDrawRenderBatchActive();
        rlSetTexture(u32(0));
        rlEnableDepthMask();
        EndBlendMode();
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

    """Liquids and Q2's translucent surfaces, unlit as the originals draw them:
    gl_warp.c EmitWaterPolys turbulence per pixel (8 texels of sine sway at
    one radian per second), Q2 SURF_FLOWING's scroll, then the 33% and 66%
    translucent faces blended over the world."""
    def draw_liquids(level: Level, batches: list[list[int]]) {
        if level.bsp.game not in ["q1", "q2"] {
            return;
        }
        if self.warp_shader.id == u32(0) {
            self.warp_shader = LoadShaderFromMemory(
                "#version 330\nin vec3 vertexPosition; in vec2 vertexTexCoord; in vec4 vertexColor; uniform mat4 mvp; out vec2 uv; out vec4 color;\n"
                    + "void main(){ uv=vertexTexCoord; color=vertexColor; gl_Position=mvp*vec4(vertexPosition,1.0); }\n",
                "#version 330\nin vec2 uv; in vec4 color; out vec4 finalColor; uniform sampler2D texture0; uniform vec4 colDiffuse; uniform float warpTime; uniform vec2 warpSize; uniform float warpScroll;\n"
                    + "void main(){ vec2 st=uv*warpSize; vec2 w=vec2(st.x+8.0*sin(st.y*0.125+warpTime)+warpScroll, st.y+8.0*sin(st.x*0.125+warpTime))/warpSize; finalColor=texture(texture0,w)*color*colDiffuse; }\n"
            );
            self.warp_time = int(GetShaderLocation(self.warp_shader, "warpTime"));
            self.warp_size = int(GetShaderLocation(self.warp_shader, "warpSize"));
            self.warp_scroll = int(GetShaderLocation(self.warp_shader, "warpScroll"));
        }
        # Q2 flowing surfaces scroll 64 texels every two seconds.
        drift = -64.0 * (self.time * 0.5 - float(int(self.time * 0.5)));
        for pass_index in range(2) {
            translucent = pass_index == 1;
            if translucent {
                BeginBlendMode(i32(0));
                rlDisableDepthMask();
            }
            for t in range(len(batches)) {
                picked = [
                    index
                    for index in batches[t]
                    if (level.bsp.faces[index].warp or level.bsp.faces[index].opacity < 1.0)
                        and (level.bsp.faces[index].opacity < 1.0) == translucent
                ];
                if not picked {
                    continue;
                }
                texture = level.bsp.textures[t];
                for index in picked {
                    face = level.bsp.faces[index];
                    alpha = int(face.opacity * 255.0);
                    if face.warp {
                        # Uniforms go to the program bound now, not at the flush.
                        rlEnableShader(self.warp_shader.id);
                        rlSetUniform(i32(self.warp_time), struct.pack("<f", self.time), i32(0), i32(1));
                        rlSetUniform(i32(self.warp_size), struct.pack("<ff", float(texture.width), float(texture.height)), i32(1), i32(1));
                        rlSetUniform(i32(self.warp_scroll), struct.pack("<f", drift if face.flowing else 0.0), i32(0), i32(1));
                        rlDisableShader();
                        BeginShaderMode(self.warp_shader);
                    }
                    rlSetTexture(u32(self.textures[t]));
                    self.plain_polygon(face, alpha);
                    rlDrawRenderBatchActive();
                    if face.warp {
                        EndShaderMode();
                    }
                }
            }
            if translucent {
                rlEnableDepthMask();
                EndBlendMode();
            }
        }
        rlSetTexture(u32(0));
    }

    """A face with its base texture only, at the given opacity."""
    def plain_polygon(face: Face, alpha: int) {
        indices = face.indices;
        if len(indices) == 0 {
            indices = [];
            for triangle in range(1, len(face.vertices) - 1) {
                indices.extend([0, triangle + 1, triangle]);
            }
        }
        rlBegin(i32(4));
        rlColor4ub(u8(255), u8(255), u8(255), u8(alpha));
        for index in indices {
            rlTexCoord2f(f32(face.uv[index * 2]), f32(face.uv[index * 2 + 1]));
            v = face.vertices[index];
            if face.turn is not None {
                v = face.pivot.add(face.turn.apply(v.sub(face.pivot)));
            }
            v = v.add(face.motion);
            rlVertex3f(f32(v.x), f32(v.y), f32(v.z));
        }
        rlEnd();
    }

    def close() {
        if self.single_pass {
            UnloadShader(self.shader);
        }
        self.single_pass = False;
        for id in self.sky {
            rlUnloadTexture(u32(id));
        }
        self.sky = [];
        for id in self.textures {
            rlUnloadTexture(u32(id));
        }
        for id in self.emissive {
            if id != 0 {
                rlUnloadTexture(u32(id));
            }
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
        if self.warp_shader.id != u32(0) {
            UnloadShader(self.warp_shader);
            self.warp_shader = Shader(id=u32(0), locs=u64(0));
        }
        if self.fog_image != 0 {
            rlUnloadTexture(u32(self.fog_image));
            self.fog_image = 0;
        }
        if self.white != 0 {
            rlUnloadTexture(u32(self.white));
            self.white = 0;
        }
        self.textures = [];
        self.emissive = [];
        self.rects = [];
        self.atlas = 0;
    }
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
