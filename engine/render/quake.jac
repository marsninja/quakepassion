"""Quake polygon rendering through raylib's rlgl batch API."""
import from vendor.raylib {
    def rlLoadTexture(
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
import from ..formats.q1.bsp { Face }
import from ..math.vec3 { Vec3 }

obj LightRect {
    has x: int = 0,
        y: int = 0;
}
obj QuakeRenderer {
    has textures: list[int] = [],
        emissive: list[int] = [],
        atlas: int = 0,
        atlas_size: int = 2048,
        rects: list[LightRect] = [];

    def upload(level: Level) {
        for texture in level.bsp.textures {
            rgba = bytearray();
            glow = bytearray();
            has_glow = False;
            sky = texture.name.startswith("sky")
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
                lit = index >= 224 and not sky and not texture.name.startswith("*");
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
        for face in level.bsp.faces {
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
            rect.x = x;
            rect.y = y;
            for ly in range(-1, h + 1) {
                for lx in range(-1, w + 1) {
                    sample = min(max(ly, 0), h - 1) * w + min(max(lx, 0), w - 1);
                    brightness = 0;
                    for style in range(len(face.styles)) {
                        brightness += int(
                            level.bsp.lighting[
                                face.light_offset + style * w * h + sample
                            ]
                        )
                            * 2;
                    }
                    brightness = min(255, brightness);
                    p = ((y + ly) * self.atlas_size + x + lx) * 4;
                    pixels[p] = brightness;
                    pixels[p + 1] = brightness;
                    pixels[p + 2] = brightness;
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
        # Quake stores clockwise polygons; raylib culls clockwise triangles.
        for triangle in range(1, len(face.vertices) - 1) {
            for index in [0, triangle + 1, triangle] {
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
        }
        rlEnd();
    }

    def draw(level: Level, faces: list[int], eye: Vec3) -> int {
        # BSP winding and normal consistently face the empty side of each plane.
        batches: list[list[int]] = [];
        for texture in self.textures {
            batches.append([]);
        }
        count = 0;
        for index in sorted(faces) {
            face = level.bsp.faces[index];
            if face.normal.dot(eye) - face.plane_dist < -0.01 {
                continue;
            }
            batches[face.texture].append(index);
            count += 1;
        }
        for t in range(len(batches)) {
            rlSetTexture(u32(self.textures[t]));
            for index in batches[t] {
                self.polygon(level.bsp.faces[index], self.rects[index], False);
            }
        }
        rlDrawRenderBatchActive();
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
