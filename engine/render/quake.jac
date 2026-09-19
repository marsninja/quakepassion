"""Quake polygon rendering through raylib's rlgl batch API."""
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
    ) -> u32;  def rlUnloadTexture(id: u32) -> None;  def rlTextureParameters(
        id: u32, param: i32, value: i32
    ) -> None;  def rlSetTexture(id: u32) -> None;  def rlBegin(mode: i32) -> None;  def rlEnd -> None;  def rlTexCoord2f(
        x: f32, y: f32
    ) -> None;  def rlVertex3f(x: f32, y: f32, z: f32) -> None;  def rlColor4ub(
        r: u8, g: u8, b: u8, a: u8
    ) -> None;  def rlDrawRenderBatchActive -> None;  def BeginBlendMode(
        mode: i32
    ) -> None;  def EndBlendMode -> None;
}
import from ..world.level { Level }
import from ..formats.q1.bsp { Face, Texture }
import from ..math.vec3 { Vec3 }

obj LightRect {
    has x: int = 0,
        y: int = 0;
}

obj QuakeRenderer {
    has textures: list[int] = [],
        emissive: list[int] = [],
        sky: list[int] = [],
        single_pass: bool = False,
        shader: Shader = Shader(id=u32(0), locs=u64(0)),
        atlas: int = 0,
        atlas_size: int = 2048,
        rects: list[LightRect] = [];

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
        self.single_pass = level.bsp.game == "q3";
        if self.single_pass {
            # Baked lighting does not need a geometric normal. The batch's
            # normal attribute transports lightmap UV and an enable flag.
            self.shader = LoadShaderFromMemory(
                "#version 330\nin vec3 vertexPosition; in vec2 vertexTexCoord; in vec3 vertexNormal; in vec4 vertexColor;\n"
                    + "uniform mat4 mvp; out vec2 uv; out vec3 light; out vec4 color;\n"
                    + "void main(){ uv=vertexTexCoord; light=vertexNormal; color=vertexColor; gl_Position=mvp*vec4(vertexPosition,1.0); }\n",
                "#version 330\nin vec2 uv; in vec3 light; in vec4 color; out vec4 finalColor;\n"
                    + "uniform sampler2D texture0; uniform sampler2D bakedLight; uniform vec4 colDiffuse;\n"
                    + "void main(){ vec4 base=texture(texture0,uv); float mode=floor(light.z*0.5+0.1); if((mode==1.0&&base.a<=0.0)||(mode==2.0&&base.a<0.5)||(mode==3.0&&base.a>=0.5)) discard; vec3 lighting=mod(light.z,2.0)>0.5?texture(bakedLight,light.xy).rgb:vec3(1.0); finalColor=vec4(base.rgb*lighting,1.0)*color*colDiffuse; }\n"
            );
            location = GetShaderLocation(self.shader, "bakedLight");
            if int(location) < 0 {
                raise RuntimeError("Q3 lightmap shader failed");
            }
            rlEnableShader(self.shader.id);
            rlSetUniform(location, struct.pack("<i", 1), i32(4), i32(1));
            rlDisableShader();
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
    }

    def polygon(face: Face, rect: LightRect, light: bool) {
        rlBegin(i32(4));
        rlColor4ub(u8(255), u8(255), u8(255), u8(255));
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
                    rlNormal3f(f32(0.0), f32(0.0), f32(float(face.alpha_test * 2)));
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
            rlVertex3f(f32(v.x), f32(v.y), f32(v.z));
        }
        rlEnd();
    }

    def draw(level: Level, faces: list[int], eye: Vec3) -> int {
        self.draw_sky(eye);
        # BSP winding and normal consistently face the empty side of each plane.
        batches: list[list[int]] = [];
        for texture in self.textures {
            batches.append([]);
        }
        count = 0;
        for index in sorted(faces) {
            face = level.bsp.faces[index];
            if face.hidden
                or len(face.vertices) < 3
                or (
                    face.planar
                    and not face.two_sided
                    and face.normal.dot(eye) - face.plane_dist < -0.01
                ) {
                continue;
            }
            batches[face.texture].append(index);
            count += 1;
        }
        if self.single_pass {
            BeginShaderMode(self.shader);
            rlActiveTextureSlot(i32(1));
            rlEnableTexture(u32(self.atlas));
            rlActiveTextureSlot(i32(0));
        }
        for t in range(len(batches)) {
            if self.single_pass and level.bsp.textures[t].additive {
                continue;
            }
            # Flush only at culling-state boundaries: flushing every texture
            # serializes small GPU batches and severely reduces frame rate.
            if level.bsp.textures[t].two_sided {
                rlDrawRenderBatchActive();
                rlDisableBackfaceCulling();
            }
            rlSetTexture(u32(self.textures[t]));
            for index in batches[t] {
                self.polygon(level.bsp.faces[index], self.rects[index], False);
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
                if not level.bsp.textures[t].additive {
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
            return count;
        }
        # raylib BLEND_MULTIPLIED: destination color times lightmap intensity.
        BeginBlendMode(i32(2));
        rlSetTexture(u32(self.atlas));
        for batch in batches {
            for index in batch {
                face = level.bsp.faces[index];
                if face.light_offset >= 0 {
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
                self.polygon(level.bsp.faces[index], self.rects[index], False);
            }
        }
        rlDrawRenderBatchActive();
        rlSetTexture(u32(0));
        return count;
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
        self.textures = [];
        self.emissive = [];
        self.rects = [];
        self.atlas = 0;
    }
}
