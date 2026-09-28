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
    mark_axes,
    MARK_TOTAL_TIME,
    MARK_FADE_TIME
}
import from ..world.particle_field { ParticleField, HasParticles, puff_state }
import from ..world.missile_trails { EmitTrails }
import from .particles { ParticleRing }
import from .polygons { ScenePolygons, POLYGON_BLEND_ALPHA, POLYGON_BLEND_DARKEN }
import from ..world.chthon { LightningEvent, HasLightning, Electrode, electrode_point }
import from ..world.doors { Door }
import from ..math.vec3 { Vec3, forward_from, right_from }
import from ..math.interpolation { TickBlend }
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
    has marks: list[ImpactMark] = [],
        trails: list[ShotTrail] = [],
        blasts: list[Explosion] = [],
        projectiles: list[Projectile] = [],
        lightning: list[LightningEvent] = [],
        field: ParticleField | None = None;

    can begin with World entry {
        visit [here->:HasParticles:->];
        visit [here->:HasLightning:->];
        visit [here->:HasMark:->];
        visit [here->:HasTrail:->];
        visit [here->:HasExplosion:->];
        visit [here->:HasProjectile:->];
    }

    can particles with ParticleField entry {
        self.field = here;
    }

    can electrodes with LightningEvent entry {
        self.lightning.append(here);
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
glob STYLED_TRAILS: list[str] = [
    "rail",
    "q3_rail",
    "lightning",
    "player_lightning",
    "drain",
    "laser_red",
    "laser_green",
    "laser_blue",
    "laser_yellow",
    "laser_orange"
];

"""Q2 target_laser_start's beam colours: four palette entries each, packed
in its skinnum (red 0xf2f2f0f0, green 0xd0d1d2d3, blue 0xf3f3f1f1, yellow
0xdcdddedf, orange 0xe0e1e2e3); the BFG's lasers are green."""
glob QUAKE2_LASER_COLORS: dict[str, list[int]] = {
    "laser_red": [240, 240, 242, 242],
    "laser_green": [211, 210, 209, 208],
    "laser_blue": [241, 241, 243, 243],
    "laser_yellow": [223, 222, 221, 220],
    "laser_orange": [227, 226, 225, 224]
};

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
        polygons: ScenePolygons = ScenePolygons(),
        particles: ParticleRing = ParticleRing(),
        palette: bytes = b"",
        lighting: Lighting = Lighting(),
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
            # The palette particle colours index: Q1 gfx/palette.lmp, Q2
            # the one pics/colormap.pcx carries. Q1 particles write depth.
            palette = b"";
            if game == "q1" {
                palette = library.read("gfx/palette.lmp");
            } elif game == "q2" {
                colormap = library.read("pics/colormap.pcx");
                palette = colormap[len(colormap) - 768:] if len(colormap) >= 769 else b"";
            }
            self.particles.open(palette, game == "q1");
            self.palette = palette;
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
        lighting: Lighting = Lighting(),
        blend: TickBlend = TickBlend()
    ) {
        self.quads.open();
        side = right_from(yaw);
        up = side.cross(forward_from(yaw, pitch)).normalized();
        self.quads.side = side;
        self.quads.up = up;
        self.lighting = lighting;
        found = world spawn GatherEffects();
        field = found.field;
        now = field.clock if field is not None else 0.0;
        self.draw_marks(found.marks, eye);
        self.draw_trails(found.trails, eye, now);
        self.draw_electrodes(found.lightning, eye);
        self.draw_bfg_lasers(found.projectiles, blend);
        self.draw_blasts(found.blasts, eye);
        if field is not None {
            self.draw_puffs(field, eye);
        }
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
            at = blend.place(projectile.tick_pose, projectile.pos);
            renderer.draw(
                at,
                heading,
                first=model_frame,
                second=model_frame,
                eye=eye,
                seconds=projectile.age,
                illumination=lighting.light_model(at, math.degrees(heading)),
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
                blend.place(projectile.tick_pose, projectile.pos),
                EFFECT_BLEND_ADD if sprite.additive else EFFECT_BLEND_ALPHA,
                angle=-sprite.rotate * projectile.age * math.pi / 180.0
            );
        }
        self.quads.flush();
    }

    """Chthon's lightning (boss.qc lightning_fire, TE_LIGHTNING3): bolt3.mdl
    from 16 below one electrode toward the other, the far end pulled back
    100 units for the bolt's length, every tenth of a second it lasts."""
    def draw_electrodes(events: list[LightningEvent], eye: Vec3) {
        for event in events {
            doors = [event->:Electrode:->][?:Door];
            if event.remaining <= 0.0 or len(doors) != 2 {
                continue;
            }
            start = electrode_point(doors[0]);
            finish = electrode_point(doors[1]);
            finish = finish.sub(finish.sub(start).normalized().scale(100.0));
            if finish.sub(start).length() >= 1.0 {
                self.draw_segments("q1_bolt3", start, finish, eye, event.remaining, 30.0, False);
            }
        }
    }

    """The BFG ball's lasers to whatever it sees (TE_BFG_LASER): green RF_BEAM
    tubes four across, redrawn as long as they last."""
    def draw_bfg_lasers(projectiles: list[Projectile], blend: TickBlend) {
        drawn = False;
        for projectile in projectiles {
            if projectile.effect != "q2_bfg" or not projectile.beams {
                continue;
            }
            at = blend.place(projectile.tick_pose, projectile.pos);
            for finish in projectile.beams {
                self.laser_beam(at, finish, QUAKE2_LASER_COLORS["laser_green"], 4.0, projectile.age);
                drawn = True;
            }
        }
        if drawn {
            self.quads.flush();
        }
    }

    """Lay the missiles' and gibs' trails up to where the frame shows them
    (`blend`), then draw every Q1/Q2 particle still showing (particles.jac
    ParticleRing)."""
    def draw_particles(world: World, yaw: float, pitch: float, blend: TickBlend = TickBlend()) {
        emitted = world spawn EmitTrails(blend=blend);
        field = emitted.field;
        if field is None {
            return;
        }
        self.particles.feed(field);
        self.particles.draw(field.clock, yaw, pitch);
    }

    """Q3's smoke and blood puffs (cg_localents.c CG_AddScaleFade and
    CG_AddFallScaleFade): each a turned sprite of its shader, blended by the
    alpha it fades by."""
    def draw_puffs(field: ParticleField, eye: Vec3) {
        if not field.puffs {
            return;
        }
        for puff in field.puffs {
            art = self.flight.get(puff.shader, []);
            if not art {
                continue;
            }
            state = puff_state(puff, field.clock, eye);
            if not state.alive {
                continue;
            }
            sprite = art[0];
            self.billboard(
                sprite,
                state.position,
                EFFECT_BLEND_ALPHA,
                scale=state.radius * 2.0 / float(max(1, sprite.frame.width)),
                alpha=state.alpha,
                angle=puff.rotation * math.pi / 180.0,
                tint=puff.color
            );
        }
        self.quads.flush();
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

    """Q3 cg_marks.c CG_AddMarks: each mark's pieces on the faces it was cut
    to (CG_ImpactMark's R_MarkFragments), textured from the mark's own
    square, lifted off the wall a little (the shaders' polygonOffset) and
    fading over its last second. The bullet, burn and hole marks darken
    what is behind them (blendFunc GL_ZERO GL_ONE_MINUS_SRC_COLOR) and fade
    their colour; energy marks blend by alpha, their glow dying over three
    seconds."""
    def draw_marks(marks: list[ImpactMark], eye: Vec3) {
        if not marks {
            return;
        }
        self.polygons.open();
        for mark in marks {
            art = self.flight.get(mark.shader, []);
            if not art {
                continue;
            }
            fade = min(1.0, max(0.0, (MARK_TOTAL_TIME - mark.age) / MARK_FADE_TIME));
            shade = mark.color.scale(fade);
            alpha = 1.0;
            blend = POLYGON_BLEND_DARKEN;
            if mark.alpha_fade {
                glow = min(1.0, max(0.0, (450.0 - 450.0 * mark.age / 3.0) / 255.0));
                shade = mark.color.scale(glow);
                alpha = fade;
                blend = POLYGON_BLEND_ALPHA;
            }
            axes = mark_axes(mark.normal, mark.angle);
            scale = 0.5 / mark.radius;
            # Depth precision falls with distance; so does the lift grow.
            lift = mark.normal.scale(0.3 + mark.pos.sub(eye).length() * 0.0005);
            for fragment in mark.fragments {
                points: list[Vec3] = [];
                st: list[float] = [];
                for point in fragment {
                    delta = point.sub(mark.pos);
                    points.append(point.add(lift));
                    st.extend([0.5 + delta.dot(axes[1]) * scale, 0.5 + delta.dot(axes[0]) * scale]);
                }
                self.polygons.add(
                    art[0].texture, blend, points, st,
                    effect_byte(shade.x), effect_byte(shade.y), effect_byte(shade.z), effect_byte(alpha)
                );
            }
        }
        self.polygons.flush();
    }

    """A quad from `start` to `finish`, `width` across along `across`, its
    texture running from (u0, v0) at the start's first edge to (u1, v1) at
    the finish's other edge (tr_surface.c DoRailCore)."""
    def beam_quad(
        texture: int,
        blend: int,
        start: Vec3,
        finish: Vec3,
        across: Vec3,
        width: float,
        color: Vec3,
        u0: float = 0.0,
        u1: float = 1.0,
        v0: float = 0.0,
        v1: float = 1.0,
        alpha: float = 1.0
    ) {
        along = finish.sub(start);
        if along.length() < 0.001 or across.length() < 0.0001 {
            return;
        }
        self.quads.add(
            texture,
            blend,
            start,
            along,
            across.normalized().scale(width),
            0.0,
            -1.0,
            1.0,
            1.0,
            u0,
            v0,
            u1,
            v1,
            effect_byte(color.x),
            effect_byte(color.y),
            effect_byte(color.z),
            effect_byte(alpha)
        );
    }

    """RB_SurfaceRailCore's side vector: square to the beam and both ends'
    lines of sight."""
    def beam_side(start: Vec3, finish: Vec3, eye: Vec3) -> Vec3 {
        return start.sub(eye).normalized().cross(finish.sub(eye).normalized()).normalized();
    }

    """Beams and rails. Q1 CL_UpdateTEnts: a beam model every 30 units (the
    player's bolt2.mdl, monsters' bolt.mdl, Chthon's bolt3.mdl); Q2
    CL_AddBeams' parasite segments, R_DrawBeam's tubes (target_laser, the
    BFG's lasers); Q3 CG_LightningBolt and CG_RailTrail (cg_oldRail's core)."""
    def draw_trails(all_trails: list[ShotTrail], eye: Vec3, now: float) {
        trails = [trail for trail in all_trails if trail.kind in STYLED_TRAILS or trail.kind.startswith("laser_")];
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
            kind = trail.kind;
            if kind in ["lightning", "player_lightning"] {
                if self.game == "q1" {
                    self.draw_segments("q1_bolt2" if kind == "player_lightning" else "q1_bolt", trail.start, trail.finish, eye, trail.age, 30.0, False);
                } else {
                    self.lightning_bolt(trail.start, trail.finish, eye, now);
                }
            } elif kind == "drain" {
                self.draw_segments("q2_segment", trail.start, trail.finish, eye, trail.age, 30.0, True);
            } elif kind.startswith("laser_") {
                self.laser_beam(trail.start, trail.finish, QUAKE2_LASER_COLORS.get(kind, [242, 242, 240, 240]), trail.width, trail.age);
            } elif kind == "q3_rail" {
                self.rail_core(trail.start, trail.finish, eye, fade, trail.age);
            } else {
                # A plain rail (Passion): a thin red core.
                self.beam_quad(0, EFFECT_BLEND_ADD, trail.start, trail.finish, self.beam_side(trail.start, trail.finish, eye), 0.75, Vec3(x=0.75).scale(fade));
            }
        }
        self.quads.flush();
    }

    """CG_RailTrail with cg_oldRail (the default): the railCore shader's quad
    12 units across (r_railCoreWidth 6 each side), its texture a quarter
    repeat per 64 units scrolling back a repeat a second (tcMod scroll -1),
    lowered 8 units, in the shooter's color1 (red) at three quarters,
    fading over cg_railTrailTime."""
    def rail_core(start: Vec3, finish: Vec3, eye: Vec3, fade: float, age: float) {
        art = self.flight.get("q3_railcore", []);
        low_start = start.sub(Vec3(z=12.0));
        low_finish = finish.sub(Vec3(z=8.0));
        side = self.beam_side(low_start, low_finish, eye);
        repeat = low_finish.sub(low_start).length() / 256.0;
        self.beam_quad(
            art[0].texture if art else 0,
            EFFECT_BLEND_ADD,
            low_start,
            low_finish,
            side,
            6.0,
            Vec3(x=0.75 * fade),
            -age,
            repeat - age
        );
    }

    """CG_LightningBolt's beam (RB_SurfaceLightningBolt): four quads 16
    across turned 45 degrees apart about the beam, drawn with each stage of
    lightningBoltNew: the lightning3new image a repeat per 256 units, scaled
    by 2 and scrolling -5, then by -1.3 (and flipped across) scrolling
    -7.2, each added at its wave's brightness (1 + 0.5 sin 7.1 Hz, 1 + 0.8
    sin 8.1 Hz, held to full)."""
    def lightning_bolt(start: Vec3, finish: Vec3, eye: Vec3, now: float) {
        art = self.flight.get("q3_lightning", []);
        texture = art[0].texture if art else 0;
        axis = finish.sub(start).normalized();
        side = self.beam_side(start, finish, eye);
        span = finish.sub(start).length() / 256.0;
        stages = [
            (2.0, 1.0, -5.0, min(1.0, 1.0 + 0.5 * math.sin(now * 7.1 * 2.0 * math.pi))),
            (-1.3, -1.0, -7.2, min(1.0, 1.0 + 0.8 * math.sin(now * 8.1 * 2.0 * math.pi)))
        ];
        for stage in stages {
            turn = side;
            for k in range(4) {
                scroll = stage[2] * now;
                self.beam_quad(
                    texture,
                    EFFECT_BLEND_ADD,
                    start,
                    finish,
                    turn,
                    8.0,
                    Vec3(x=stage[3], y=stage[3], z=stage[3]),
                    scroll,
                    span * stage[0] + scroll,
                    0.0,
                    stage[1]
                );
                # RotatePointAroundVector by 45 degrees about the beam.
                c = math.cos(math.pi / 4.0);
                n = math.sin(math.pi / 4.0);
                turn = turn.scale(c).add(axis.cross(turn).scale(n)).add(axis.scale(axis.dot(turn) * (1.0 - c)));
            }
        }
    }

    """R_DrawBeam (RF_BEAM, alpha 0.30): a six-sided tube `diameter` across
    in one of the four palette colours packed in its skin, picked afresh
    each frame (CL_AddPacketEntities' rand()%4)."""
    def laser_beam(start: Vec3, finish: Vec3, colors: list[int], diameter: float, age: float) {
        axis = finish.sub(start);
        if axis.length() < 0.001 {
            return;
        }
        normal = axis.normalized();
        helper = Vec3(z=1.0) if abs(normal.z) < 0.9 else Vec3(x=1.0);
        perpendicular = normal.cross(helper).normalized().scale(diameter / 2.0);
        pick = colors[int(age * 97.0 + finish.x) % len(colors)];
        color = self.palette_color(pick);
        points: list[Vec3] = [];
        for i in range(6) {
            angle = float(i) * math.pi / 3.0;
            points.append(
                perpendicular.scale(math.cos(angle)).add(normal.cross(perpendicular).scale(math.sin(angle)))
            );
        }
        for i in range(6) {
            edge_start = start.add(points[i]);
            across = points[(i + 1) % 6].sub(points[i]);
            self.quads.add(
                0, EFFECT_BLEND_ALPHA, edge_start, across, axis,
                0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0,
                int(color.x * 255.0), int(color.y * 255.0), int(color.z * 255.0), 76
            );
        }
    }

    """A palette entry's colour (white without a palette)."""
    def palette_color(index: int) -> Vec3 {
        if len(self.palette) < index * 3 + 3 {
            return Vec3(x=1.0, y=1.0, z=1.0);
        }
        return Vec3(
            x=float(self.palette[index * 3]) / 255.0,
            y=float(self.palette[index * 3 + 1]) / 255.0,
            z=float(self.palette[index * 3 + 2]) / 255.0
        );
    }

    """Beam models along a beam (Q1 CL_UpdateTEnts, Q2 CL_AddBeams): one
    every `step` units, pitched and turned along it and rolled at random,
    lit where each lies. Q2 spaces them evenly over the whole length."""
    def draw_segments(key: str, start: Vec3, finish: Vec3, eye: Vec3, age: float, step: float, even: bool) {
        renderer = self.models.get(key, None);
        if renderer is None {
            return;
        }
        along = finish.sub(start);
        length = along.length();
        axis = along.scale(1.0 / length);
        heading = math.atan2(axis.y, axis.x);
        elevation = math.atan2(axis.z, math.sqrt(axis.x * axis.x + axis.y * axis.y));
        spacing = step;
        if even {
            count = int(math.ceil(length / step));
            spacing = (length - step) / float(count - 1) if count > 1 else step;
        }
        rlDrawRenderBatchActive();
        rlDisableBackfaceCulling();
        seed = int(age * 20.0) * 7 + int(abs(start.x));
        left = length;
        point = start.add(Vec3());
        segment = 0;
        while left > 0.0 {
            roll = float((seed + segment * 131) % 360) * math.pi / 180.0;
            renderer.draw(
                point,
                heading,
                eye=eye,
                illumination=self.lighting.light_model(point, math.degrees(heading)),
                basis=model_basis(heading, elevation, roll)
            );
            point = point.add(axis.scale(spacing));
            left -= step;
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
        self.polygons.close();
        self.particles.close();
    }
}
