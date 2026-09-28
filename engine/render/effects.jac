"""Camera-facing archive sprites with explicit GPU ownership and depth testing:
projectiles, explosions, weapon trails, wall marks and impact particles.

Every sprite, ribbon, mark and particle is one instance of a single unit
quad. Per frame the CPU packs one small record per quad (centre, axes,
extent, texture rectangle, tint, spin) and the vertex shader places the
corners; a record without axes of its own faces the camera along the view's
right and up vectors (r_part.c R_DrawParticles, tr_surface.c
RB_SurfaceSprite). Quads draw in the old order, one instanced draw per run
of the same texture and blend."""
import math;
import struct;
import from .models { ModelRenderer }
import from ..math.orientation { model_basis }
import from ..world.lighting { Lighting }
import from ..formats.bsp { Texture }
import from ..formats.sprite { SpriteFrame, EffectRule }
import from ..formats.q2.sprite { parse_sp2 }
import from ..formats.q2.model { parse_pcx }
import from ..formats.q1.sprite { parse_spr }
import from ..assets.library { AssetLibrary }
import from ..world.world { World }
import from ..world.combat { Projectile, HasProjectile }
import from ..world.particles {
    Explosion,
    HasExplosion,
    ShotTrail,
    HasTrail,
    ImpactMark,
    HasMark,
    ImpactParticle,
    HasParticle,
    mark_axes,
    MARK_TOTAL_TIME,
    MARK_FADE_TIME
}
import from ..math.vec3 { Vec3, forward_from, right_from }
import from .quake { QuakeRenderer }
import from .gpu {
    GpuMesh,
    GpuProgram,
    VertexAttribute,
    GL_FLOAT,
    GL_UNSIGNED_BYTE,
    view_projection,
    pack_floats
}
import from vendor.raylib {
    def rlTextureParameters(id: u32, param: i32, value: i32) -> None;  def rlLoadTexture(
        data: bytes, width: i32, height: i32, format: i32, mipmapCount: i32
    ) -> u32;  def rlUnloadTexture(id: u32) -> None;  def rlGetTextureIdDefault -> u32;  def rlDrawRenderBatchActive -> None;  def BeginBlendMode(
        mode: i32
    ) -> None;  def EndBlendMode -> None;  def rlSetBlendFactors(
        src: i32, dst: i32, equation: i32
    ) -> None;  def rlDisableDepthMask -> None;  def rlEnableDepthMask -> None;  def rlDisableBackfaceCulling -> None;  def rlEnableBackfaceCulling -> None;  def rlEnableVertexBuffer(
        id: u32
    ) -> None;  def rlSetVertexAttribute(
        index: u32, compSize: i32, kind: i32, normalized: bool, stride: i32, offset: i32
    ) -> None;  def rlUnloadVertexBuffer(vboId: u32) -> None;
}

# One quad instance: centre, two axes (zero: the camera's right and up),
# extent (x0 y0 x1 y1 along the axes), texture rectangle (u0 v0 u1 v1 at
# those corners), RGBA tint bytes and a texture spin in radians.
glob EFFECT_STRIDE: int = 76;

glob EFFECT_VS: str = """#version 330
in vec2 corner;
in vec3 center;
in vec3 axisU;
in vec3 axisV;
in vec4 extent;
in vec4 texRect;
in vec4 tint;
in float spin;
uniform mat4 mvp;
uniform vec4 side;
uniform vec4 up;
out vec2 uv;
out vec4 shade;
void main() {
    vec3 across = dot(axisU, axisU) > 0.0 ? axisU : side.xyz;
    vec3 along = dot(axisV, axisV) > 0.0 ? axisV : up.xyz;
    vec2 at = mix(extent.xy, extent.zw, corner);
    vec2 t = mix(texRect.xy, texRect.zw, corner) - 0.5;
    float c = cos(spin);
    float s = sin(spin);
    uv = vec2(0.5 + t.x * c - t.y * s, 0.5 + t.x * s + t.y * c);
    shade = tint;
    gl_Position = mvp * vec4(center + across * at.x + along * at.y, 1.0);
}
""",
     EFFECT_FS: str = """#version 330
in vec2 uv;
in vec4 shade;
uniform sampler2D art;
out vec4 finalColor;
void main() {
    finalColor = texture(art, uv) * shade;
}
""";

# Instance buffers rotate so a frame never refills one the GPU may still be
# drawing from: rlgl's buffer updates wait for it (see Renderer's batch).
glob EFFECT_RINGS: int = 16,
     EFFECT_FIRST_CAPACITY: int = 1024;

# How a run of quads blends: by alpha, added, or darkening what is behind
# (Q3 marks' blendFunc GL_ZERO GL_ONE_MINUS_SRC_COLOR).
glob EFFECT_BLEND_ALPHA: int = 0,
     EFFECT_BLEND_ADD: int = 1,
     EFFECT_BLEND_DARKEN: int = 2;

"""A colour channel in [0, 1] as a byte, as rlColor4ub was given it."""
def effect_byte(value: float) -> int {
    return int(max(0.0, min(1.0, value)) * 255.0);
}

"""Consecutive quads sharing a texture and blend: one instanced draw."""
obj SpriteRun {
    has texture: int,
        blend: int,
        first: int,
        count: int = 0;
}

"""The quads of one drawing pass, packed for the GPU, and the instanced
unit-quad meshes they are drawn with."""
obj EffectQuads {
    has program: GpuProgram = GpuProgram(),
        rings: list[GpuMesh] = [],
        capacities: list[int] = [],
        layout: list[VertexAttribute] = [],
        corner_location: int = -1,
        turn: int = 0,
        packed: bytearray = bytearray(),
        count: int = 0,
        runs: list[SpriteRun] = [],
        white: int = 0,
        side: Vec3 = Vec3(),
        up: Vec3 = Vec3();

    def open() {
        if self.program.id != 0 {
            return;
        }
        self.program.load(EFFECT_VS, EFFECT_FS);
        self.corner_location = self.program.attribute("corner");
        self.layout = [
            VertexAttribute(location=self.program.attribute("center"), components=3, kind=GL_FLOAT, offset=0),
            VertexAttribute(location=self.program.attribute("axisU"), components=3, kind=GL_FLOAT, offset=12),
            VertexAttribute(location=self.program.attribute("axisV"), components=3, kind=GL_FLOAT, offset=24),
            VertexAttribute(location=self.program.attribute("extent"), components=4, kind=GL_FLOAT, offset=36),
            VertexAttribute(location=self.program.attribute("texRect"), components=4, kind=GL_FLOAT, offset=52),
            VertexAttribute(location=self.program.attribute("tint"), components=4, kind=GL_UNSIGNED_BYTE, normalized=True, offset=68),
            VertexAttribute(location=self.program.attribute("spin"), components=1, kind=GL_FLOAT, offset=72)
        ];
        self.rings = [];
        self.capacities = [];
        for i in range(EFFECT_RINGS) {
            self.rings.append(GpuMesh());
            self.capacities.append(0);
        }
        self.white = int(rlGetTextureIdDefault());
        self.packed = bytearray(EFFECT_FIRST_CAPACITY * EFFECT_STRIDE);
        self.count = 0;
        self.runs = [];
    }

    """Queue one quad: `center` plus `across` and `along` (zero vectors: the
    camera's right and up) scaled over [x0, x1] and [y0, y1]; texture
    coordinates run from (u0, v0) at the first corner to (u1, v1) at the
    last, turned by `spin` about the texture's middle; `texture` 0 is plain
    white."""
    def add(
        texture: int,
        blend: int,
        center: Vec3,
        across: Vec3,
        along: Vec3,
        x0: float,
        y0: float,
        x1: float,
        y1: float,
        u0: float,
        v0: float,
        u1: float,
        v1: float,
        red: int,
        green: int,
        blue: int,
        alpha: int,
        spin: float = 0.0
    ) {
        art = texture if texture != 0 else self.white;
        if not self.runs or self.runs[-1].texture != art or self.runs[-1].blend != blend {
            self.runs.append(SpriteRun(texture=art, blend=blend, first=self.count));
        }
        self.runs[-1].count += 1;
        offset = self.count * EFFECT_STRIDE;
        if offset + EFFECT_STRIDE > len(self.packed) {
            self.packed.extend(bytes(max(len(self.packed), EFFECT_FIRST_CAPACITY * EFFECT_STRIDE)));
        }
        struct.pack_into(
            "<17f4Bf",
            self.packed,
            offset,
            center.x,
            center.y,
            center.z,
            across.x,
            across.y,
            across.z,
            along.x,
            along.y,
            along.z,
            x0,
            y0,
            x1,
            y1,
            u0,
            v0,
            u1,
            v1,
            red,
            green,
            blue,
            alpha,
            spin
        );
        self.count += 1;
    }

    """The next ring mesh, its instance buffer holding at least `count`."""
    def ring(count: int) -> GpuMesh {
        slot = self.turn;
        self.turn = (self.turn + 1) % EFFECT_RINGS;
        mesh = self.rings[slot];
        if mesh.vao == 0 {
            corners = pack_floats([0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0]);
            mesh.upload(
                corners,
                8,
                [VertexAttribute(location=self.corner_location, components=2, kind=GL_FLOAT)]
            );
        }
        if self.capacities[slot] < count {
            capacity = max(EFFECT_FIRST_CAPACITY, self.capacities[slot]);
            while capacity < count {
                capacity *= 2;
            }
            if mesh.instances != 0 {
                rlUnloadVertexBuffer(u32(mesh.instances));
            }
            mesh.upload_instances(capacity, EFFECT_STRIDE, self.layout);
            self.capacities[slot] = capacity;
        }
        return mesh;
    }

    """Point the instance attributes at record `first` (the mesh is bound):
    GL 3.3 has no base instance for instanced draws."""
    def point(mesh: GpuMesh, first: int) {
        rlEnableVertexBuffer(u32(mesh.instances));
        for attribute in self.layout {
            rlSetVertexAttribute(
                u32(attribute.location),
                i32(attribute.components),
                i32(attribute.kind),
                attribute.normalized,
                i32(EFFECT_STRIDE),
                i32(attribute.offset + first * EFFECT_STRIDE)
            );
        }
    }

    """Draw the queued quads, depth tested, both sides, and empty the queue.
    `depth_write` keeps them writing depth (particles); sprites do not."""
    def flush(depth_write: bool = False) {
        if self.count == 0 {
            return;
        }
        mesh = self.ring(self.count);
        mesh.set_instances(bytes(self.packed[0:self.count * EFFECT_STRIDE]));
        rlDrawRenderBatchActive();
        if not depth_write {
            rlDisableDepthMask();
        }
        rlDisableBackfaceCulling();
        mvp = view_projection();
        framing = pack_floats([self.side.x, self.side.y, self.side.z, 0.0]);
        rising = pack_floats([self.up.x, self.up.y, self.up.z, 0.0]);
        for run in self.runs {
            # A blend change flushes rlgl's batch, which unbinds any shader
            # and vertex array: set it before binding ours.
            if run.blend == EFFECT_BLEND_DARKEN {
                rlSetBlendFactors(i32(0), i32(769), i32(32774));
                BeginBlendMode(i32(6));
            } else {
                BeginBlendMode(i32(run.blend));
            }
            self.program.begin();
            self.program.set_matrix("mvp", mvp);
            self.program.set_vec4s("side", framing);
            self.program.set_vec4s("up", rising);
            self.program.set_texture("art", 0, run.texture);
            mesh.bind();
            self.point(mesh, run.first);
            mesh.draw_instances(0, 6, run.count);
            mesh.unbind();
            self.program.end();
        }
        rlEnableDepthMask();
        rlEnableBackfaceCulling();
        EndBlendMode();
        self.count = 0;
        self.runs = [];
    }

    def close() {
        for mesh in self.rings {
            mesh.close();
        }
        self.rings = [];
        self.capacities = [];
        self.program.close();
        self.count = 0;
        self.runs = [];
    }
}

"""The effects in a world, gathered in one walk over its effect edges."""
walker GatherEffects {
    has particles: list[ImpactParticle] = [],
        marks: list[ImpactMark] = [],
        trails: list[ShotTrail] = [],
        blasts: list[Explosion] = [],
        projectiles: list[Projectile] = [],
        with_particles: bool = True,
        with_sprites: bool = True;

    can begin with World entry {
        if self.with_particles {
            visit [here->:HasParticle:->];
        }
        if self.with_sprites {
            visit [here->:HasMark:->];
            visit [here->:HasTrail:->];
            visit [here->:HasExplosion:->];
            visit [here->:HasProjectile:->];
        }
    }

    can particle with ImpactParticle entry {
        self.particles.append(here);
    }

    can mark with ImpactMark entry {
        self.marks.append(here);
    }

    can trail with ShotTrail entry {
        self.trails.append(here);
    }

    can blast with Explosion entry {
        self.blasts.append(here);
    }

    can projectile with Projectile entry {
        self.projectiles.append(here);
    }
}

obj UploadedSprite {
    has frame: SpriteFrame,
        texture: int,
        additive: bool = False,
        rotate: float = 0.0;
}

# Trails this scene draws itself; the line renderer leaves them alone.
glob STYLED_TRAILS: list[str] = ["rail", "q2_rail", "q3_rail", "lightning", "player_lightning"];

obj EffectScene {
    has flight: dict[str, list[UploadedSprite]] = {},
        burst: dict[str, list[UploadedSprite]] = {},
        textures: list[int] = [],
        models: dict[str, ModelRenderer] = {},
        renderers: dict[str, ModelRenderer] = {},
        rules: dict[str, EffectRule] = {},
        blast_frames: dict[str, list[UploadedSprite]] = {},
        blast_models: dict[str, list[ModelRenderer]] = {},
        quads: EffectQuads = EffectQuads(),
        game: str = "";

    def keys() -> list[str] {
        styled = [kind for kind in STYLED_TRAILS if self.game];
        return list(self.flight.keys()) + list(self.models.keys()) + styled;
    }

    def frames(
        library: AssetLibrary, path: str, rule: EffectRule
    ) -> list[UploadedSprite] {
        result: list[UploadedSprite] = [];
        if not path {
            return result;
        }
        if path.lower().endswith(".spr") {
            for picture in parse_spr(library.read(path), library.read("gfx/palette.lmp"), path) {
                texture = int(
                    rlLoadTexture(
                        picture.image.pixels,
                        i32(picture.image.width),
                        i32(picture.image.height),
                        i32(7),
                        i32(1)
                    )
                );
                if texture == 0 {
                    raise RuntimeError("Cannot upload sprite: " + path);
                }
                self.textures.append(texture);
                result.append(
                    UploadedSprite(frame=picture.frame, texture=texture, additive=rule.additive)
                );
            }
            return result;
        }
        if not path.lower().endswith(".sp2") {
            image = Texture(name=path);
            library.pk3.texture(image);
            if not image.encoded {
                raise ValueError("Missing effect image: " + path);
            }
            texture = QuakeRenderer().upload_image(image);
            self.textures.append(texture);
            rlTextureParameters(u32(texture), i32(10242), i32(33071));
            rlTextureParameters(u32(texture), i32(10243), i32(33071));
            frame = SpriteFrame(
                width=rule.sprite_size,
                height=rule.sprite_size,
                origin_x=rule.sprite_size // 2,
                origin_y=rule.sprite_size // 2,
                image=path
            );
            return [
                UploadedSprite(
                    frame=frame,
                    texture=texture,
                    additive=rule.additive,
                    rotate=rule.rotate
                )
            ];
        }
        for frame in parse_sp2(library.read(path)) {
            image = parse_pcx(library.read(frame.image), frame.image, transparent=255);
            texture = int(
                rlLoadTexture(
                    image.pixels, i32(image.width), i32(image.height), i32(7), i32(1)
                )
            );
            if texture == 0 {
                raise RuntimeError("Cannot upload sprite: " + frame.image);
            }
            self.textures.append(texture);
            result.append(
                UploadedSprite(
                    frame=frame,
                    texture=texture,
                    additive=rule.additive,
                    rotate=rule.rotate
                )
            );
        }
        return result;
    }

    def upload(game: str, directory: str, rules: list[EffectRule]) {
        self.close();
        self.game = game;
        if not rules {
            return;
        }
        library = AssetLibrary(game=game);
        try {
            library.open(directory);
            for rule in rules {
                self.rules[rule.key] = rule;
                model_path = rule.flight.lower().endswith((".mdl", ".md2", ".md3"));
                if rule.explosion {
                    if model_path {
                        # Q2 explosions change skin as they burn (CL_AddExplosions).
                        variants: list[ModelRenderer] = [];
                        for skin in range(max(1, rule.skins)) {
                            renderer = ModelRenderer();
                            loaded = library.model(rule.flight, skin=skin);
                            renderer.upload(loaded.model, loaded.skins);
                            variants.append(renderer);
                            self.renderers[rule.flight + "#" + str(skin)] = renderer;
                        }
                        self.blast_models[rule.key] = variants;
                    } else {
                        pictures: list[UploadedSprite] = [];
                        for image in (rule.images if rule.images else [rule.flight]) {
                            pictures.extend(self.frames(library, image, rule));
                        }
                        self.blast_frames[rule.key] = pictures;
                    }
                    continue;
                }
                if model_path {
                    if rule.flight not in self.renderers {
                        renderer = ModelRenderer();
                        self.renderers[rule.flight] = renderer;
                        loaded = library.model(rule.flight);
                        renderer.upload(loaded.model, loaded.skins);
                    }
                    self.models[rule.key] = self.renderers[rule.flight];
                } else {
                    self.flight[rule.key] = self.frames(library, rule.flight, rule);
                }
                self.burst[rule.key] = self.frames(library, rule.burst, rule);
            }
        } except Exception {
            self.close();
            raise;
        } finally {
            library.close();
        }
    }

    """One camera-facing quad of `sprite` at `center`, scaled and tinted,
    its texture turned by `angle`."""
    def billboard(
        sprite: UploadedSprite,
        center: Vec3,
        blend: int,
        scale: float = 1.0,
        shade: float = 1.0,
        alpha: float = 1.0,
        angle: float = 0.0,
        tint: Vec3 = Vec3(x=1.0, y=1.0, z=1.0)
    ) {
        frame = sprite.frame;
        self.quads.add(
            sprite.texture,
            blend,
            center,
            Vec3(),
            Vec3(),
            -float(frame.origin_x) * scale,
            -float(frame.origin_y) * scale,
            float(frame.width - frame.origin_x) * scale,
            float(frame.height - frame.origin_y) * scale,
            0.0,
            1.0,
            1.0,
            0.0,
            effect_byte(shade * tint.x),
            effect_byte(shade * tint.y),
            effect_byte(shade * tint.z),
            effect_byte(alpha),
            angle
        );
    }

    def draw(
        world: World,
        eye: Vec3,
        yaw: float,
        pitch: float,
        lighting: Lighting = Lighting()
    ) {
        self.quads.open();
        side = right_from(yaw);
        up = side.cross(forward_from(yaw, pitch)).normalized();
        self.quads.side = side;
        self.quads.up = up;
        found = world spawn GatherEffects(with_particles=False);
        self.draw_marks(found.marks, eye);
        self.draw_trails(found.trails, eye);
        self.draw_blasts(found.blasts, eye);
        if not self.textures and not self.models {
            return;
        }
        for projectile in found.projectiles {
            if projectile.phase != 0 or projectile.effect not in self.models {
                continue;
            }
            velocity = projectile.velocity;
            heading = math.atan2(velocity.y, velocity.x);
            elevation = math.atan2(
                velocity.z, math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
            );
            spin = self.rules[projectile.effect].spin * projectile.age;
            renderer = self.models[projectile.effect];
            model_frame = int(projectile.age * 10.0)
                % len(renderer.model.surfaces[0].frames);
            renderer.draw(
                projectile.pos,
                heading,
                first=model_frame,
                second=model_frame,
                eye=eye,
                seconds=projectile.age,
                illumination=lighting.light_model(projectile.pos, math.degrees(heading)),
                basis=model_basis(heading, elevation, spin)
            );
        }
        projectiles = [
            projectile
            for projectile in found.projectiles
            if projectile.effect in self.flight
        ];
        if not projectiles {
            return;
        }
        order = sorted(
            [
                (-projectiles[i].pos.sub(eye).length(), i)
                for i in range(len(projectiles))
            ]
        );
        for ranked in order {
            projectile = projectiles[ranked[1]];
            frames = self.flight.get(projectile.effect, [])
                if projectile.phase == 0
                else self.burst.get(projectile.effect, []);
            if not frames {
                continue;
            }
            frame_index = int(projectile.age * 10.0) % len(frames)
                if projectile.phase == 0
                else min(
                    len(frames) - 1, max(0, int((0.5 - projectile.remaining) * 10.0))
                );
            sprite = frames[frame_index];
            self.billboard(
                sprite,
                projectile.pos,
                EFFECT_BLEND_ADD if sprite.additive else EFFECT_BLEND_ALPHA,
                angle=-sprite.rotate * projectile.age * math.pi / 180.0
            );
        }
        self.quads.flush();
    }

    """Impact and explosion particles as small camera-facing squares, depth
    written like the cubes they replace (Q1 R_DrawParticles, Q2
    R_DrawParticles): blood red or dust fading out, and fire embers cooling
    from yellow through orange to red (Q1 ramp1/ramp2, Q2 0xe0)."""
    def draw_particles(world: World, yaw: float, pitch: float) {
        found = world spawn GatherEffects(with_sprites=False);
        if not found.particles {
            return;
        }
        self.quads.open();
        side = right_from(yaw);
        self.quads.side = side;
        self.quads.up = side.cross(forward_from(yaw, pitch)).normalized();
        origin = Vec3();
        for particle in found.particles {
            fade = max(0.0, particle.remaining / particle.lifetime);
            red = 170;
            green = 20;
            blue = 15;
            alpha = int(255.0 * fade);
            size = 0.4 + fade * 0.6;
            if particle.fire {
                red = 255;
                green = int(60.0 + 180.0 * fade);
                blue = int(20.0 + 60.0 * fade * fade);
                alpha = int(255.0 * min(1.0, fade * 1.5));
                size = 1.2 + fade * 1.2;
            } elif not particle.blood {
                red = 210;
                green = 185;
                blue = 145;
            }
            # A cube `size` across shows about 1.2 times that edge on screen.
            half = size * 0.6;
            self.quads.add(
                0,
                EFFECT_BLEND_ALPHA,
                particle.pos,
                origin,
                origin,
                -half,
                -half,
                half,
                half,
                0.0,
                0.0,
                1.0,
                1.0,
                red,
                green,
                blue,
                min(255, alpha)
            );
        }
        self.quads.flush(depth_write=True);
    }

    """Explosions: Q1 s_explod.spr at 10 frames a second; Q2's r_explode
    model, full bright, changing skin and fading after its tenth frame
    (CL_AddExplosions); Q3's animated shader sprites cross-fading frame to
    frame while the sprite grows from 30 to 72 units (CG_AddSpriteExplosion)."""
    def draw_blasts(blasts: list[Explosion], eye: Vec3) {
        if not blasts {
            return;
        }
        for blast in blasts {
            variants = self.blast_models.get(blast.kind, []);
            rule = self.rules.get(blast.kind, None);
            if not variants or rule is None {
                continue;
            }
            step = int(blast.age * rule.fps);
            base = rule.frames[blast.variant % len(rule.frames)] if rule.frames else 0;
            skin = min(len(variants) - 1, step // 2 if step < 10 else (5 if step < 13 else 6));
            renderer = variants[skin];
            count = len(renderer.model.surfaces[0].frames);
            first = min(count - 1, base + step);
            second = min(count - 1, first + 1);
            renderer.draw(
                blast.pos,
                float(blast.variant * 37 % 360) * math.pi / 180.0,
                first=first,
                second=second,
                blend=blast.age * rule.fps - float(step),
                eye=eye,
                seconds=blast.age,
                alpha=1.0 if step < 10 else max(0.0, (16.0 - float(step)) / 16.0)
            );
        }
        order = sorted(
            [(-blasts[i].pos.sub(eye).length(), i) for i in range(len(blasts))]
        );
        for ranked in order {
            blast = blasts[ranked[1]];
            frames = self.blast_frames.get(blast.kind, []);
            rule = self.rules.get(blast.kind, None);
            if not frames or rule is None {
                continue;
            }
            progress = blast.age * rule.fps;
            index = min(len(frames) - 1, int(progress));
            blend = EFFECT_BLEND_ADD if rule.additive else EFFECT_BLEND_ALPHA;
            if rule.grow > 0.0 {
                # Q3: radius 30 growing by 42 over the life; each animmap
                # frame fades out as the next fades in.
                life = max(0.001, blast.lifetime);
                radius = float(rule.sprite_size) + rule.grow * min(1.0, blast.age / life);
                scale = radius * 2.0 / float(max(1, frames[index].frame.width));
                fraction = progress - float(int(progress));
                self.billboard(frames[index], blast.pos, blend, scale, 1.0 - fraction);
                if index + 1 < len(frames) {
                    self.billboard(frames[index + 1], blast.pos, blend, scale, fraction);
                }
            } else {
                self.billboard(frames[index], blast.pos, blend);
            }
        }
        self.quads.flush();
    }

    """Q3 cg_marks.c CG_AddMarks: each mark's square on its wall, lifted off
    it a little (the shaders' polygonOffset) and fading over its last second.
    The bullet, burn and hole marks darken what is behind them (blendFunc
    GL_ZERO GL_ONE_MINUS_SRC_COLOR) and fade their colour; energy marks
    blend by alpha, their glow dying over three seconds."""
    def draw_marks(marks: list[ImpactMark], eye: Vec3) {
        if not marks {
            return;
        }
        for mark in marks {
            art = self.flight.get(mark.shader, []);
            if not art {
                continue;
            }
            fade = min(1.0, max(0.0, (MARK_TOTAL_TIME - mark.age) / MARK_FADE_TIME));
            shade = mark.color.scale(fade);
            alpha = 1.0;
            blend = EFFECT_BLEND_DARKEN;
            if mark.alpha_fade {
                glow = min(1.0, max(0.0, (450.0 - 450.0 * mark.age / 3.0) / 255.0));
                shade = mark.color.scale(glow);
                alpha = fade;
                blend = EFFECT_BLEND_ALPHA;
            }
            axes = mark_axes(mark.normal, mark.angle);
            # Depth precision falls with distance; so does the lift grow.
            lift = 0.3 + mark.pos.sub(eye).length() * 0.0005;
            self.quads.add(
                art[0].texture,
                blend,
                mark.pos.add(mark.normal.scale(lift)),
                axes[0],
                axes[1],
                -mark.radius,
                -mark.radius,
                mark.radius,
                mark.radius,
                0.0,
                0.0,
                1.0,
                1.0,
                effect_byte(shade.x),
                effect_byte(shade.y),
                effect_byte(shade.z),
                effect_byte(alpha)
            );
        }
        self.quads.flush();
    }

    """A textured ribbon from `start` to `finish`, turned to face the eye;
    its texture runs `repeat` times along it from `scroll`."""
    def ribbon(
        texture: int,
        start: Vec3,
        finish: Vec3,
        eye: Vec3,
        width: float,
        color: Vec3,
        scroll: float = 0.0,
        repeat: float = 1.0
    ) {
        along = finish.sub(start);
        if along.length() < 0.001 {
            return;
        }
        across = along.cross(eye.sub(start)).normalized().scale(width * 0.5);
        if across.length() < 0.0001 {
            return;
        }
        self.quads.add(
            texture,
            EFFECT_BLEND_ADD,
            start,
            along,
            across,
            0.0,
            -1.0,
            1.0,
            1.0,
            scroll,
            1.0,
            scroll + repeat,
            0.0,
            effect_byte(color.x),
            effect_byte(color.y),
            effect_byte(color.z),
            255
        );
    }

    """A small untextured additive square, the particle look of Q2 trails."""
    def speck(center: Vec3, size: float, color: Vec3, fade: float) {
        self.quads.add(
            0,
            EFFECT_BLEND_ADD,
            center,
            Vec3(),
            Vec3(),
            -size,
            -size,
            size,
            size,
            0.0,
            0.0,
            1.0,
            1.0,
            effect_byte(color.x * fade),
            effect_byte(color.y * fade),
            effect_byte(color.z * fade),
            255
        );
    }

    """Railgun and lightning trails. Q3 CG_RailTrail: a red railCore ribbon
    and a spiral of magenta railDisc rings drifting outward (the default
    color1 4 and color2 5); Q2 CL_RailTrail: a blue particle spiral around
    a grey core; Q1 CL_UpdateTEnts: bolt models every 30 units; Q3
    CG_LightningBolt: a scrolling lightning3 ribbon."""
    def draw_trails(all_trails: list[ShotTrail], eye: Vec3) {
        trails = [trail for trail in all_trails if trail.kind in STYLED_TRAILS];
        if not trails or not self.game {
            return;
        }
        for trail in trails {
            fade = max(0.0, min(1.0, trail.remaining / max(0.001, trail.lifetime)));
            along = trail.finish.sub(trail.start);
            length = along.length();
            if length < 1.0 {
                continue;
            }
            axis = along.scale(1.0 / length);
            lightning = trail.kind in ["lightning", "player_lightning"];
            if lightning and self.game == "q1" {
                self.draw_bolt(trail, axis, length, eye);
                continue;
            }
            if lightning {
                bolt = self.flight.get("q3_lightning", []);
                if bolt {
                    self.ribbon(
                        bolt[0].texture,
                        trail.start,
                        trail.finish,
                        eye,
                        8.0,
                        Vec3(x=fade, y=fade, z=fade),
                        -5.0 * trail.age,
                        length / 128.0
                    );
                } else {
                    self.ribbon(0, trail.start, trail.finish, eye, 2.0, Vec3(x=0.6, y=0.7, z=1.0).scale(fade));
                }
                continue;
            }
            # A perpendicular frame for the spiral (PerpendicularVector).
            helper = Vec3(z=1.0) if abs(axis.z) < 0.9 else Vec3(x=1.0);
            ring_x = axis.cross(helper).normalized();
            ring_y = axis.cross(ring_x).normalized();
            if self.game == "q2" {
                spread = (1.0 - fade) * 6.0;
                speck_color = Vec3(x=0.3, y=0.45, z=1.0);
                distance = 0.0;
                while distance < length {
                    turn = distance * 0.1;
                    offset = ring_x.scale(math.cos(turn)).add(ring_y.scale(math.sin(turn)));
                    point = trail.start.add(axis.scale(distance)).add(offset.scale(3.0 + spread));
                    self.speck(point, 0.6, speck_color, fade);
                    distance += 2.0;
                }
                core = max(0.0, fade * 1.4 - 0.4);
                if core > 0.0 {
                    self.ribbon(0, trail.start, trail.finish, eye, 1.2, Vec3(x=0.7, y=0.7, z=0.7).scale(core));
                }
                continue;
            }
            core_art = self.flight.get("q3_railcore", []);
            disc_art = self.flight.get("q3_raildisc", []);
            red = Vec3(x=0.75, y=0.0, z=0.0).scale(fade);
            if core_art {
                self.ribbon(core_art[0].texture, trail.start, trail.finish, eye, 6.0, red, -trail.age, length / 64.0);
            } else {
                self.ribbon(0, trail.start, trail.finish, eye, 1.5, red);
            }
            if not disc_art {
                continue;
            }
            ring = disc_art[0];
            magenta = Vec3(x=1.0, y=0.0, z=1.0);
            scale = 2.2 / float(max(1, ring.frame.width));
            distance = 20.0;
            step = 0;
            while distance < length {
                # Rings live 600 ms plus a millisecond per two units.
                ring_life = 0.6 + distance * 0.0005;
                ring_fade = max(0.0, 1.0 - trail.age / ring_life);
                if ring_fade > 0.0 {
                    turn = float(18 + step) * 10.0 * math.pi / 180.0;
                    offset = ring_x.scale(math.cos(turn)).add(ring_y.scale(math.sin(turn)));
                    point = trail.start.add(axis.scale(distance)).add(
                        offset.scale(4.0 + 6.0 * trail.age)
                    );
                    self.billboard(
                        ring,
                        point,
                        EFFECT_BLEND_ADD,
                        scale,
                        ring_fade * 0.75,
                        tint=magenta
                    );
                }
                distance += 5.0;
                step += 1;
            }
        }
        self.quads.flush();
    }

    """Q1 CL_UpdateTEnts: a beam model every 30 units, rolled at random;
    the player's Thunderbolt uses bolt2.mdl, the shambler bolt.mdl."""
    def draw_bolt(trail: ShotTrail, axis: Vec3, length: float, eye: Vec3) {
        key = "q1_bolt2" if trail.kind == "player_lightning" else "q1_bolt";
        renderer = self.models.get(key, None);
        if renderer is None {
            return;
        }
        rlDrawRenderBatchActive();
        rlDisableBackfaceCulling();
        heading = math.atan2(axis.y, axis.x);
        elevation = math.atan2(axis.z, math.sqrt(axis.x * axis.x + axis.y * axis.y));
        distance = 0.0;
        segment = 0;
        seed = int(trail.age * 20.0) * 7 + int(abs(trail.start.x));
        while distance < length {
            roll = float((seed + segment * 131) % 360) * math.pi / 180.0;
            renderer.draw(
                trail.start.add(axis.scale(distance)),
                heading,
                eye=eye,
                basis=model_basis(heading, elevation, roll)
            );
            distance += 30.0;
            segment += 1;
        }
        rlDrawRenderBatchActive();
        rlEnableBackfaceCulling();
    }

    def close() {
        if self.textures {
            rlDrawRenderBatchActive();
        }
        for texture in self.textures {
            rlUnloadTexture(u32(texture));
        }
        for renderer in self.renderers.values() {
            renderer.close();
        }
        self.models = {};
        self.renderers = {};
        self.rules = {};
        self.textures = [];
        self.flight = {};
        self.burst = {};
        self.blast_frames = {};
        self.blast_models = {};
        self.game = "";
        self.quads.close();
    }
}
