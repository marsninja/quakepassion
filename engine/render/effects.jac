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
import from .models { ModelRenderer, upload_skin }
import from ..math.orientation { Basis, model_basis }
import from ..formats.animated { AnimatedModel, AnimatedSurface, ModelStage, stage_frame }
import from ..world.lighting { Lighting }
import from ..formats.bsp { Texture }
import from ..formats.sprite { SpriteFrame, EffectRule }
import from ..formats.q2.sprite { parse_sp2 }
import from ..formats.q2.model { parse_pcx }
import from ..formats.q1.sprite { parse_spr }
import from ..assets.library { AssetLibrary }
import from ..assets.catalog { AssetCatalog }
import from ..formats.sprite { effect_game }
import from ..world.world { World }
import from ..world.combat { Projectile, HasProjectile, Opponent, HasOpponent }
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
import from ..world.arena { ArenaMatch, HasMatch, Competes }
import from ..world.shadows { CastShadows, ShadowCut, ShadowSight, shadow_caster, SHADOW_MARK }
import from ..world.world { Player }
import from ..physics.collision { CollisionMap }
import from ..world.models { PLAYER_COLOR1, PLAYER_COLOR2 }
import from ..world.portals { perpendicular, rotate_about }
import from ..console.cvar { Cvar, CVAR_ARCHIVE }
import from ..console.shell { Shell }
import from .particles { ParticleRing }
import from .polygons { ScenePolygons, POLYGON_BLEND_ALPHA, POLYGON_BLEND_DARKEN }
import from ..math.vec3 { Vec3, forward_from, right_from }
import from ..math.interpolation { TickBlend }
import from .quake { QuakeRenderer, stage_color }
import from .gpu {
    GpuMesh,
    GpuProgram,
    VertexAttribute,
    GL_FLOAT,
    GL_UNSIGNED_BYTE,
    view_projection,
    projection_matrix,
    pack_floats
}
import from vendor.raylib {
    def rlTextureParameters(id: u32, param: i32, value: i32) -> None;  def rlLoadTexture(
        data: bytes, width: i32, height: i32, format: i32, mipmapCount: i32
    ) -> u32;  def rlUnloadTexture(id: u32) -> None;  def rlGetTextureIdDefault -> u32;  def rlDrawRenderBatchActive -> None;  def BeginBlendMode(
        mode: i32
    ) -> None;  def EndBlendMode -> None;  def rlSetBlendFactors(
        src: i32, dst: i32, equation: i32
    ) -> None;  def rlDisableDepthMask -> None;  def rlEnableDepthMask -> None;  def rlDisableDepthTest -> None;  def rlEnableDepthTest -> None;  def rlDisableBackfaceCulling -> None;  def rlEnableBackfaceCulling -> None;  def rlEnableVertexBuffer(
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

"""The cone round the view being drawn (rlgl's projection): from `eye` along
`forward` out to the corners of the screen."""
def view_cone(eye: Vec3, forward: Vec3) -> ShadowSight {
    projection = projection_matrix();
    tan_x = 1.0 / max(0.0001, abs(float(projection.m0)));
    tan_y = 1.0 / max(0.0001, abs(float(projection.m5)));
    return sight_cone(eye, forward, tan_x, tan_y);
}

"""A view's cone from the tangents of half its angles across and up."""
def sight_cone(eye: Vec3, forward: Vec3, tan_x: float, tan_y: float) -> ShadowSight {
    corner = math.sqrt(tan_x * tan_x + tan_y * tan_y);
    reach = math.sqrt(1.0 + corner * corner);
    return ShadowSight(eye=eye, forward=forward, sine=corner / reach, cosine=1.0 / reach);
}

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
    `depth_write` keeps them writing depth (particles); sprites do not.
    Without `depth_test` they draw over everything (flares)."""
    def flush(depth_write: bool = False, depth_test: bool = True) {
        if self.count == 0 {
            return;
        }
        mesh = self.ring(self.count);
        mesh.set_instances(bytes(self.packed[0:self.count * EFFECT_STRIDE]));
        rlDrawRenderBatchActive();
        if not depth_write {
            rlDisableDepthMask();
        }
        if not depth_test {
            rlDisableDepthTest();
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
        if not depth_test {
            rlEnableDepthTest();
        }
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

# cg_main.c's balloonShader, floated over a player typing a message, and the
# medal shaders floated over one just given an award.
glob BALLOON_SHADER: str = "sprites/balloon3";
glob AWARD_SHADERS: dict[str, str] = {
    "impressive": "medal_impressive",
    "excellent": "medal_excellent",
    "gauntlet": "medal_gauntlet"
};

"""A player wearing an award sprite (EF_AWARD_IMPRESSIVE and the like)."""
obj Awarded {
    has actor: Opponent,
        award: str;
}

"""The effects in a world, gathered in one walk over its effect edges, and,
with `balloons`, the Q3 players with a sprite over their heads
(CG_PlayerSprites): those typing a message (EF_TALK), else those just given
an award. The human's own sprite shows only in third person and mirrors
(RF_THIRD_PERSON), so only bots are gathered."""
walker GatherEffects {
    has marks: list[ImpactMark] = [],
        trails: list[ShotTrail] = [],
        blasts: list[Explosion] = [],
        projectiles: list[Projectile] = [],
        field: ParticleField | None = None,
        balloons: bool = False,
        talkers: list[Opponent] = [],
        awarded: list[Awarded] = [];

    can begin with World entry {
        visit [here->:HasParticles:->];
        visit [here->:HasMark:->];
        visit [here->:HasTrail:->];
        visit [here->:HasExplosion:->];
        visit [here->:HasProjectile:->];
        if self.balloons {
            visit [here->:HasOpponent:->];
            visit [here->:HasMatch:->];
        }
    }

    """The competitors wearing an award; talking comes first."""
    can honour with ArenaMatch entry {
        entries = [edge here->:Competes:->];
        actors = [here->:Competes:->];
        for i in range(min(len(entries), len(actors))) {
            actor = actors[i];
            if entries[i].award and isinstance(actor, Opponent) and not actor.dormant and actor.visual.visible
                and not actor.bot_state.talking {
                self.awarded.append(Awarded(actor=actor, award=entries[i].award));
            }
        }
    }

    """A bot holding its talk button while it types a chat line (the
    BUTTON_TALK that bg_pmove.c turns into EF_TALK)."""
    can talker with Opponent entry {
        if here.arena and not here.dormant and here.visual.visible and here.bot_state.talking {
            self.talkers.append(here);
        }
    }

    can particles with ParticleField entry {
        self.field = here;
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

"""One stage of a Q3 shader drawn as a sprite: its image frames on the GPU
and the stage (animMap rate, rgbGen, alphaGen, blend)."""
obj ShaderSprite {
    has source: ModelStage,
        frames: list[int] = [];
}

# Trails this scene draws itself; the line renderer leaves them alone.
glob STYLED_TRAILS: list[str] = [
    "rail",
    "q3_rail",
    "lightning",
    "player_lightning",
    "q1_lightning3",
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

"""The cvars the effects own (cg_main.c): whether a Q3 rail is its core
alone, how long the core shows, and the players' shadows."""
obj EffectCvars {
    has old_rail: Cvar = Cvar(
            name="cg_oldRail",
            reset_text="1",
            kind="bool",
            flags=CVAR_ARCHIVE,
            description="draw the railgun's core only, without the spiral of rings"
        ),
        rail_time: Cvar = Cvar(
            name="cg_railTrailTime",
            reset_text="400",
            kind="float",
            low=0.0,
            high=10000.0,
            flags=CVAR_ARCHIVE,
            description="milliseconds a railgun's core takes to fade"
        ),
        shadows: Cvar = Cvar(
            name="cg_shadows",
            reset_text="1",
            kind="int",
            low=0.0,
            high=3.0,
            flags=CVAR_ARCHIVE,
            description="player shadows: 0 none, 1 a blob on the ground (2 and 3, the original's stencil and projection shadows, draw none)"
        );
}

# cg_weapons.c CG_RailTrail: the spiral's RADIUS and SPACING, how far along
# the beam it starts, the first of the 36 perpendiculars it uses, each ring's
# sprite radius and drift, and the least a ring lives.
glob RAIL_SPIRAL_RADIUS: float = 4.0,
     RAIL_SPIRAL_SPACING: int = 5,
     RAIL_SPIRAL_START: float = 20.0,
     RAIL_SPIRAL_FIRST_AXIS: int = 18,
     RAIL_RING_RADIUS: float = 1.1,
     RAIL_RING_DRIFT: float = 6.0,
     RAIL_RING_LIFE: float = 0.6;

# The railDisc shader's tcMod rotate, degrees a second.
glob RAIL_RING_SPIN: float = -30.0;

"""One ring of a rail's spiral, where it is now."""
obj RailRing {
    has pos: Vec3,
        age: float;
}

"""CG_RailTrail's beam: the start drops 4 units, and with cg_oldRail both
ends of the core drop another 8 so it is not dead centre."""
def rail_core_ends(start: Vec3, finish: Vec3, old_rail: bool) -> list[Vec3] {
    nudge = 8.0 if old_rail else 0.0;
    return [start.sub(Vec3(z=4.0 + nudge)), finish.sub(Vec3(z=nudge))];
}

"""CG_RailTrail's spiral (cg_oldRail 0) `age` seconds after the shot: from 20
units along the lowered beam, every other 5-unit step leaves a ring 4 units
off the axis on a perpendicular that turns 10 degrees a step from the 18th
(so 20 degrees from ring to ring, 10 units apart), drifting outward 6 units
a second (LE_MOVE_SCALE_FADE, TR_LINEAR) and living 600 ms plus half its
distance in milliseconds."""
def rail_rings(start: Vec3, finish: Vec3, age: float) -> list[RailRing] {
    rings: list[RailRing] = [];
    low = start.sub(Vec3(z=4.0));
    along = finish.sub(low);
    length = along.length();
    if length < 0.001 {
        return rings;
    }
    axis = along.scale(1.0 / length);
    side = perpendicular(axis);
    move = low.add(axis.scale(RAIL_SPIRAL_START));
    turn = RAIL_SPIRAL_FIRST_AXIS;
    # The original's `skip`: a step that left a ring makes the next leave none.
    idle = -1;
    i = 0;
    while float(i) < length {
        if i != idle {
            idle = i + RAIL_SPIRAL_SPACING;
            if age < RAIL_RING_LIFE + float(i >> 1) / 1000.0 {
                out = rotate_about(side, axis, float(turn * 10));
                rings.append(RailRing(pos=move.add(out.scale(RAIL_SPIRAL_RADIUS + RAIL_RING_DRIFT * age)), age=age));
            }
        }
        move = move.add(axis.scale(float(RAIL_SPIRAL_SPACING)));
        turn = (turn + 1) % 36;
        i += RAIL_SPIRAL_SPACING;
    }
    return rings;
}

obj EffectScene {
    has cvars: EffectCvars = EffectCvars();
    # The level's collision the shadows were last cast on, and the box view
    # of it they are traced with.
    has shadow_source: CollisionMap | None = None,
        shadow_view: CollisionMap | None = None,
        # The marks the last frame's shadows were cut into (ShadowCut).
        shadow_cuts: list[ShadowCut] = [];
    has flight: dict[str, list[UploadedSprite]] = {},
        burst: dict[str, list[UploadedSprite]] = {},
        textures: list[int] = [],
        models: dict[str, ModelRenderer] = {},
        renderers: dict[str, ModelRenderer] = {},
        rules: dict[str, EffectRule] = {},
        blast_frames: dict[str, list[UploadedSprite]] = {},
        blast_models: dict[str, list[ModelRenderer]] = {},
        blast_shaders: dict[str, ModelRenderer] = {},
        blast_stages: dict[str, list[ShaderSprite]] = {},
        quads: EffectQuads = EffectQuads(),
        polygons: ScenePolygons = ScenePolygons(),
        particles: ParticleRing = ParticleRing(),
        palette: bytes = b"",
        lighting: Lighting = Lighting(),
        game: str = "";

    """Register the effects' cvars."""
    def declare(shell: Shell) {
        self.cvars.old_rail = shell.register(self.cvars.old_rail);
        self.cvars.rail_time = shell.register(self.cvars.rail_time);
        self.cvars.shadows = shell.register(self.cvars.shadows);
    }

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
        # Each effect from its own game's archive (a Passion level draws all
        # three games' missiles and blasts).
        catalog = AssetCatalog(game=game, directory=directory);
        try {
            library = catalog.source("q1" if game == "passion" else game);
            # The palette particle colours index: Q1 gfx/palette.lmp, Q2
            # the one pics/colormap.pcx carries. Q1 particles write depth;
            # a Passion level's particles are Quake's.
            palette = b"";
            if game in ["q1", "passion"] {
                palette = library.read("gfx/palette.lmp");
            } elif game == "q2" {
                colormap = library.read("pics/colormap.pcx");
                palette = colormap[len(colormap) - 768:] if len(colormap) >= 769 else b"";
            }
            self.particles.open(palette, game in ["q1", "passion"]);
            self.palette = palette;
            for rule in rules {
                library = catalog.source(effect_game(rule.key) if game == "passion" else game);
                self.rules[rule.key] = rule;
                model_path = rule.flight.lower().endswith((".mdl", ".md2", ".md3"));
                if rule.explosion and rule.shader {
                    self.upload_shader_blast(library, rule, model_path);
                    continue;
                }
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
                        self.blast_frames[rule.key] = self.frames(library, rule.flight, rule);
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
            catalog.close();
        }
    }

    """A Q3 explosion drawn with its shader (cg_weapons.c CG_MissileHitWall's
    customShader): the shader's stages over `rule.flight`'s model (the
    bullet, plasma and rail hits' LE_EXPLOSION), or as sprite stages (the
    rocket, grenade and BFG's LE_SPRITE_EXPLOSION, CG_Bleed's blood)."""
    def upload_shader_blast(library: AssetLibrary, rule: EffectRule, model_path: bool) {
        stages = library.pk3.model_stages(rule.shader);
        if not stages {
            raise ValueError("Missing effect shader: " + rule.shader);
        }
        if model_path {
            renderer = ModelRenderer();
            self.renderers[rule.flight] = renderer;
            loaded = library.model(rule.flight);
            renderer.upload(loaded.model, loaded.skins);
            self.blast_models[rule.key] = [renderer];
            shader = ModelRenderer();
            self.renderers["shader:" + rule.shader] = shader;
            shader.upload(AnimatedModel(surfaces=[AnimatedSurface(name=rule.shader, stages=stages)]), [stages[0].texture]);
            self.blast_shaders[rule.key] = shader;
            return;
        }
        sprites: list[ShaderSprite] = [];
        for stage in stages {
            textures: list[int] = [];
            for image in (stage.frames if stage.frames else [stage.texture]) {
                texture = upload_skin(image);
                self.textures.append(texture);
                if stage.clamp {
                    rlTextureParameters(u32(texture), i32(10242), i32(33071));
                    rlTextureParameters(u32(texture), i32(10243), i32(33071));
                }
                textures.append(texture);
            }
            sprites.append(ShaderSprite(source=stage, frames=textures));
        }
        self.blast_stages[rule.key] = sprites;
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
        blend: TickBlend = TickBlend(),
        collision: CollisionMap | None = None,
        player: Player | None = None
    ) {
        self.quads.open();
        side = right_from(yaw);
        up = side.cross(forward_from(yaw, pitch)).normalized();
        self.quads.side = side;
        self.quads.up = up;
        self.lighting = lighting;
        found = world spawn GatherEffects(balloons=BALLOON_SHADER in self.flight);
        field = found.field;
        now = field.clock if field is not None else 0.0;
        ahead = forward_from(yaw, pitch);
        self.draw_marks(found.marks + self.shadow_marks(world, collision, player, blend, view_cone(eye, ahead)), eye);
        self.draw_trails(found.trails, eye, now);
        self.draw_bfg_lasers(found.projectiles, blend);
        self.draw_blasts(found.blasts, eye);
        if field is not None {
            self.draw_puffs(field, eye);
        }
        floated = self.add_balloons(found.talkers, blend);
        if self.add_awards(found.awarded, blend) or floated {
            self.quads.flush();
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

    """cg_players.c CG_PlayerSprites: over each player typing a message, the
    talk balloon. True when any was added to the quads."""
    def add_balloons(talkers: list[Opponent], blend: TickBlend) -> bool {
        art = self.flight.get(BALLOON_SHADER, []);
        if not talkers or not art {
            return False;
        }
        for talker in talkers {
            self.float_sprite(talker, art[0], blend);
        }
        return True;
    }

    """CG_PlayerSprites: the medal of each player just given an award. True
    when any was added to the quads."""
    def add_awards(awarded: list[Awarded], blend: TickBlend) -> bool {
        added = False;
        for honour in awarded {
            art = self.flight.get(AWARD_SHADERS.get(honour.award, ""), []);
            if art {
                self.float_sprite(honour.actor, art[0], blend);
                added = True;
            }
        }
        return added;
    }

    """cg_players.c CG_PlayerFloatSprite: a sprite 10 units in radius 48 units
    above the player's origin."""
    def float_sprite(actor: Opponent, sprite: UploadedSprite, blend: TickBlend) {
        origin = blend.place(actor.tick_pose, actor.pos).sub(Vec3(z=actor.eye_height));
        self.billboard(
            sprite,
            origin.add(Vec3(z=48.0)),
            EFFECT_BLEND_ALPHA,
            scale=20.0 / float(max(1, sprite.frame.width))
        );
    }

    """cg_players.c CG_PlayerShadow with cg_shadows 1: this frame's blob marks
    under the players, when the level has the markShadow art (Q3). They are
    CG_ImpactMark's temporary marks: drawn this frame and not kept."""
    def shadow_marks(
        world: World, collision: CollisionMap | None, player: Player | None, blend: TickBlend,
        sight: ShadowSight | None = None
    ) -> list[ImpactMark] {
        if collision is None or self.cvars.shadows.integer != 1 or SHADOW_MARK not in self.flight {
            return [];
        }
        view = self.shadow_view;
        if view is None or self.shadow_source is not collision {
            view = shadow_caster(collision);
            self.shadow_source = collision;
            self.shadow_view = view;
        }
        cast = world spawn CastShadows(
            collision=view, blend=blend, player=player, player_height=collision.eye_height, sight=sight,
            kept=self.shadow_cuts
        );
        self.shadow_cuts = cast.cuts;
        return cast.marks;
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
    (CL_AddExplosions); Q3's local entities drawn with their shaders at the
    time since they began (refEntity shaderTime): a model facing the wall
    turned about it (CG_AddExplosion), or a sprite turned in the view, a
    blast growing from 30 to 72 units over its life (CG_AddSpriteExplosion)
    and blood 24 across (CG_Bleed)."""
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
            shader = self.blast_shaders.get(blast.kind, None);
            if shader is not None and rule.entity_fade {
                # CG_AddFadeRGB: on the world's axes, the entity colour its
                # shader takes fading with its life.
                left = max(0.0, min(1.0, (blast.lifetime - blast.age) / max(0.001, blast.lifetime)));
                variants[0].draw(
                    blast.pos, 0.0, eye=eye, seconds=blast.age, overlay=shader,
                    entity_color=[left, left, left, left]
                );
                continue;
            }
            if shader is not None {
                axes = mark_axes(blast.direction, blast.rotation * math.pi / 180.0);
                variants[0].draw(
                    blast.pos,
                    0.0,
                    eye=eye,
                    seconds=blast.age,
                    basis=Basis(forward=blast.direction, left=axes[0], up=axes[1]),
                    overlay=shader
                );
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
            rule = self.rules.get(blast.kind, None);
            if rule is None {
                continue;
            }
            stages = self.blast_stages.get(blast.kind, []);
            if stages {
                self.shader_sprite(stages, rule, blast);
                continue;
            }
            frames = self.blast_frames.get(blast.kind, []);
            if frames {
                index = min(len(frames) - 1, int(blast.age * rule.fps));
                self.billboard(frames[index], blast.pos, EFFECT_BLEND_ADD if rule.additive else EFFECT_BLEND_ALPHA);
            }
        }
        self.quads.flush();
    }

    """A Q3 sprite local entity (tr_surface.c RB_SurfaceSprite): each stage of
    its shader at the time since it began, a square `radius` from its centre
    turned `rotation` degrees in the view; a growing blast's radius is 30
    plus 42 of its life gone (CG_AddSpriteExplosion)."""
    def shader_sprite(stages: list[ShaderSprite], rule: EffectRule, blast: Explosion) {
        radius = float(rule.sprite_size);
        if rule.grow > 0.0 {
            left = min(1.0, (blast.lifetime - blast.age) / max(0.001, blast.lifetime));
            radius += rule.grow * (1.0 - left);
        }
        turn = blast.rotation * math.pi / 180.0;
        side = self.quads.side;
        up = self.quads.up;
        across = side.scale(math.cos(turn)).add(up.scale(math.sin(turn)));
        along = up.scale(math.cos(turn)).sub(side.scale(math.sin(turn)));
        for sprite in stages {
            stage = sprite.source;
            color = stage_color(stage, blast.age);
            self.quads.add(
                sprite.frames[stage_frame(blast.age, stage.frequency, len(sprite.frames))],
                EFFECT_BLEND_ADD if stage.blend == "add" else EFFECT_BLEND_ALPHA,
                blast.pos,
                across,
                along,
                -radius,
                -radius,
                radius,
                radius,
                0.0,
                1.0,
                1.0,
                0.0,
                effect_byte(color[0]),
                effect_byte(color[1]),
                effect_byte(color[2]),
                effect_byte(color[3])
            );
        }
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
            } elif kind == "q1_lightning3" {
                # Chthon's TE_LIGHTNING3 (CL_ParseBeam): bolt3.mdl every 30 units.
                self.draw_segments("q1_bolt3", trail.start, trail.finish, eye, trail.age, 30.0, False);
            } elif kind == "drain" {
                self.draw_segments("q2_segment", trail.start, trail.finish, eye, trail.age, 30.0, True);
            } elif kind.startswith("laser_") {
                self.laser_beam(trail.start, trail.finish, QUAKE2_LASER_COLORS.get(kind, [242, 242, 240, 240]), trail.width, trail.age);
            } elif kind == "q3_rail" {
                self.rail_core(trail.start, trail.finish, eye, trail.age);
                if not self.cvars.old_rail.on() {
                    self.rail_spiral(trail.start, trail.finish, trail.age);
                }
            } else {
                # A plain rail (Passion): a thin red core.
                self.beam_quad(0, EFFECT_BLEND_ADD, trail.start, trail.finish, self.beam_side(trail.start, trail.finish, eye), 0.75, Vec3(x=0.75).scale(fade));
            }
        }
        self.quads.flush();
    }

    """CG_RailTrail's core (RT_RAIL_CORE, tr_surface.c RB_SurfaceRailCore): the
    railCore shader's quad 12 units across (r_railCoreWidth 6 each side), its
    texture a repeat per 256 units scrolling back a repeat a second (tcMod
    scroll -1), in three quarters of the shooter's color1, fading over
    cg_railTrailTime (LE_FADE_RGB)."""
    def rail_core(start: Vec3, finish: Vec3, eye: Vec3, age: float) {
        life = self.cvars.rail_time.number / 1000.0;
        if life <= 0.0 or age >= life {
            return;
        }
        fade = 0.75 * (1.0 - age / life);
        art = self.flight.get("q3_railcore", []);
        ends = rail_core_ends(start, finish, self.cvars.old_rail.on());
        side = self.beam_side(ends[0], ends[1], eye);
        repeat = ends[1].sub(ends[0]).length() / 256.0;
        self.beam_quad(
            art[0].texture if art else 0,
            EFFECT_BLEND_ADD,
            ends[0],
            ends[1],
            side,
            6.0,
            Vec3(x=PLAYER_COLOR1[0] * fade, y=PLAYER_COLOR1[1] * fade, z=PLAYER_COLOR1[2] * fade),
            -age,
            repeat - age
        );
    }

    """CG_RailTrail's spiral: each ring a railDisc sprite 1.1 units in radius
    in the shooter's color2, its texture turning with the shader's tcMod
    rotate. The local entity fades only the sprite's alpha, which the
    additive shader's rgbGen vertex does not read, so a ring keeps its colour
    until it expires."""
    def rail_spiral(start: Vec3, finish: Vec3, age: float) {
        art = self.flight.get("q3_raildisc", []);
        if not art {
            return;
        }
        sprite = art[0];
        for ring in rail_rings(start, finish, age) {
            self.billboard(
                sprite,
                ring.pos,
                EFFECT_BLEND_ADD,
                scale=RAIL_RING_RADIUS * 2.0 / float(max(1, sprite.frame.width)),
                angle=-RAIL_RING_SPIN * age * math.pi / 180.0,
                tint=Vec3(x=PLAYER_COLOR2[0], y=PLAYER_COLOR2[1], z=PLAYER_COLOR2[2])
            );
        }
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
        self.blast_shaders = {};
        self.blast_stages = {};
        self.game = "";
        self.quads.close();
        self.polygons.close();
        self.particles.close();
    }
}
