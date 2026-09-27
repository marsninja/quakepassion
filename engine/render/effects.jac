"""Camera-facing archive sprites with explicit GPU ownership and depth testing:
projectiles, explosions and weapon trails."""
import math;
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
import from ..math.vec3 { Vec3, forward_from, right_from }
import from .quake {
    QuakeRenderer,
    rlTextureParameters,
    rlLoadTexture,
    rlUnloadTexture,
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
    rlSetBlendFactors
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

    """One camera-facing quad of `sprite` at `center`, scaled and tinted."""
    def billboard(
        sprite: UploadedSprite,
        center: Vec3,
        side: Vec3,
        up: Vec3,
        scale: float = 1.0,
        shade: float = 1.0,
        alpha: float = 1.0,
        angle: float = 0.0,
        tint: Vec3 = Vec3(x=1.0, y=1.0, z=1.0)
    ) {
        frame = sprite.frame;
        corners = [
            (-float(frame.origin_x), -float(frame.origin_y), 0.0, 1.0),
            (-float(frame.origin_x), float(frame.height - frame.origin_y), 0.0, 0.0),
            (float(frame.width - frame.origin_x), float(frame.height - frame.origin_y), 1.0, 0.0),
            (float(frame.width - frame.origin_x), -float(frame.origin_y), 1.0, 1.0)
        ];
        cosine = math.cos(angle);
        sine = math.sin(angle);
        rlSetTexture(u32(sprite.texture));
        rlBegin(i32(7));
        rlColor4ub(
            u8(int(max(0.0, min(1.0, shade * tint.x)) * 255.0)),
            u8(int(max(0.0, min(1.0, shade * tint.y)) * 255.0)),
            u8(int(max(0.0, min(1.0, shade * tint.z)) * 255.0)),
            u8(int(max(0.0, min(1.0, alpha)) * 255.0))
        );
        for corner in corners {
            point = center.add(side.scale(corner[0] * scale)).add(up.scale(corner[1] * scale));
            u = corner[2] - 0.5;
            v = corner[3] - 0.5;
            rlTexCoord2f(f32(0.5 + u * cosine - v * sine), f32(0.5 + u * sine + v * cosine));
            rlVertex3f(f32(point.x), f32(point.y), f32(point.z));
        }
        rlEnd();
    }

    def draw(
        world: World,
        eye: Vec3,
        yaw: float,
        pitch: float,
        lighting: Lighting = Lighting()
    ) {
        side = right_from(yaw);
        up = side.cross(forward_from(yaw, pitch)).normalized();
        self.draw_marks(world, eye);
        self.draw_trails(world, eye, side, up);
        self.draw_blasts(world, eye, side, up);
        if not self.textures and not self.models {
            return;
        }
        all_projectiles = [world->:HasProjectile:->][?:Projectile];
        for projectile in all_projectiles {
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
                illumination=lighting.sample(projectile.pos),
                basis=model_basis(heading, elevation, spin)
            );
        }
        projectiles = [
            projectile
            for projectile in all_projectiles
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
        rlDrawRenderBatchActive();
        BeginBlendMode(i32(0));
        rlDisableDepthMask();
        rlDisableBackfaceCulling();
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
            BeginBlendMode(i32(1 if sprite.additive else 0));
            self.billboard(
                sprite,
                projectile.pos,
                side,
                up,
                angle=-sprite.rotate * projectile.age * math.pi / 180.0
            );
        }
        rlDrawRenderBatchActive();
        rlSetTexture(u32(0));
        rlEnableDepthMask();
        rlEnableBackfaceCulling();
        EndBlendMode();
    }

    """Explosions: Q1 s_explod.spr at 10 frames a second; Q2's r_explode
    model, full bright, changing skin and fading after its tenth frame
    (CL_AddExplosions); Q3's animated shader sprites cross-fading frame to
    frame while the sprite grows from 30 to 72 units (CG_AddSpriteExplosion)."""
    def draw_blasts(world: World, eye: Vec3, side: Vec3, up: Vec3) {
        blasts = [world->:HasExplosion:->][?:Explosion];
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
        rlDrawRenderBatchActive();
        rlDisableDepthMask();
        rlDisableBackfaceCulling();
        for ranked in order {
            blast = blasts[ranked[1]];
            frames = self.blast_frames.get(blast.kind, []);
            rule = self.rules.get(blast.kind, None);
            if not frames or rule is None {
                continue;
            }
            progress = blast.age * rule.fps;
            index = min(len(frames) - 1, int(progress));
            BeginBlendMode(i32(1 if rule.additive else 0));
            if rule.grow > 0.0 {
                # Q3: radius 30 growing by 42 over the life; each animmap
                # frame fades out as the next fades in.
                life = max(0.001, blast.lifetime);
                radius = float(rule.sprite_size) + rule.grow * min(1.0, blast.age / life);
                scale = radius * 2.0 / float(max(1, frames[index].frame.width));
                fraction = progress - float(int(progress));
                self.billboard(frames[index], blast.pos, side, up, scale, 1.0 - fraction);
                if index + 1 < len(frames) {
                    self.billboard(frames[index + 1], blast.pos, side, up, scale, fraction);
                }
            } else {
                self.billboard(frames[index], blast.pos, side, up);
            }
        }
        rlDrawRenderBatchActive();
        rlSetTexture(u32(0));
        rlEnableDepthMask();
        rlEnableBackfaceCulling();
        EndBlendMode();
    }

    """Q3 cg_marks.c CG_AddMarks: each mark's square on its wall, lifted off
    it a little (the shaders' polygonOffset) and fading over its last second.
    The bullet, burn and hole marks darken what is behind them (blendFunc
    GL_ZERO GL_ONE_MINUS_SRC_COLOR) and fade their colour; energy marks
    blend by alpha, their glow dying over three seconds."""
    def draw_marks(world: World, eye: Vec3) {
        marks = [world->:HasMark:->][?:ImpactMark];
        if not marks {
            return;
        }
        rlDrawRenderBatchActive();
        rlDisableDepthMask();
        rlDisableBackfaceCulling();
        for mark in marks {
            art = self.flight.get(mark.shader, []);
            if not art {
                continue;
            }
            fade = min(1.0, max(0.0, (MARK_TOTAL_TIME - mark.age) / MARK_FADE_TIME));
            shade = mark.color.scale(fade);
            alpha = 1.0;
            if mark.alpha_fade {
                glow = min(1.0, max(0.0, (450.0 - 450.0 * mark.age / 3.0) / 255.0));
                shade = mark.color.scale(glow);
                alpha = fade;
                BeginBlendMode(i32(0));
            } else {
                rlSetBlendFactors(i32(0), i32(769), i32(32774));
                BeginBlendMode(i32(6));
            }
            axes = mark_axes(mark.normal, mark.angle);
            # Depth precision falls with distance; so does the lift grow.
            lift = 0.3 + mark.pos.sub(eye).length() * 0.0005;
            center = mark.pos.add(mark.normal.scale(lift));
            rlSetTexture(u32(art[0].texture));
            rlBegin(i32(7));
            rlColor4ub(
                u8(int(max(0.0, min(1.0, shade.x)) * 255.0)),
                u8(int(max(0.0, min(1.0, shade.y)) * 255.0)),
                u8(int(max(0.0, min(1.0, shade.z)) * 255.0)),
                u8(int(max(0.0, min(1.0, alpha)) * 255.0))
            );
            for corner in [(-1.0, -1.0), (-1.0, 1.0), (1.0, 1.0), (1.0, -1.0)] {
                point = center.add(axes[0].scale(corner[0] * mark.radius)).add(
                    axes[1].scale(corner[1] * mark.radius)
                );
                rlTexCoord2f(f32(0.5 + 0.5 * corner[0]), f32(0.5 + 0.5 * corner[1]));
                rlVertex3f(f32(point.x), f32(point.y), f32(point.z));
            }
            rlEnd();
            rlDrawRenderBatchActive();
        }
        rlSetTexture(u32(0));
        rlEnableDepthMask();
        rlEnableBackfaceCulling();
        EndBlendMode();
    }

    """A textured ribbon from `start` to `finish`, turned to face the eye."""
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
        rlSetTexture(u32(texture));
        rlBegin(i32(7));
        rlColor4ub(
            u8(int(max(0.0, min(1.0, color.x)) * 255.0)),
            u8(int(max(0.0, min(1.0, color.y)) * 255.0)),
            u8(int(max(0.0, min(1.0, color.z)) * 255.0)),
            u8(255)
        );
        corners = [
            (start.sub(across), scroll, 1.0),
            (start.add(across), scroll, 0.0),
            (finish.add(across), scroll + repeat, 0.0),
            (finish.sub(across), scroll + repeat, 1.0)
        ];
        for corner in corners {
            rlTexCoord2f(f32(corner[1]), f32(corner[2]));
            rlVertex3f(f32(corner[0].x), f32(corner[0].y), f32(corner[0].z));
        }
        rlEnd();
    }

    """A small untextured additive square, the particle look of Q2 trails."""
    def speck(center: Vec3, side: Vec3, up: Vec3, size: float, color: Vec3, fade: float) {
        rlBegin(i32(7));
        rlColor4ub(
            u8(int(max(0.0, min(1.0, color.x * fade)) * 255.0)),
            u8(int(max(0.0, min(1.0, color.y * fade)) * 255.0)),
            u8(int(max(0.0, min(1.0, color.z * fade)) * 255.0)),
            u8(255)
        );
        for corner in [(-1.0, -1.0), (-1.0, 1.0), (1.0, 1.0), (1.0, -1.0)] {
            point = center.add(side.scale(corner[0] * size)).add(up.scale(corner[1] * size));
            rlVertex3f(f32(point.x), f32(point.y), f32(point.z));
        }
        rlEnd();
    }

    """Railgun and lightning trails. Q3 CG_RailTrail: a red railCore ribbon
    and a spiral of magenta railDisc rings drifting outward (the default
    color1 4 and color2 5); Q2 CL_RailTrail: a blue particle spiral around
    a grey core; Q1 CL_UpdateTEnts: bolt models every 30 units; Q3
    CG_LightningBolt: a scrolling lightning3 ribbon."""
    def draw_trails(world: World, eye: Vec3, side: Vec3, up: Vec3) {
        trails = [
            trail
            for trail in [world->:HasTrail:->][?:ShotTrail]
            if trail.kind in STYLED_TRAILS
        ];
        if not trails or not self.game {
            return;
        }
        rlDrawRenderBatchActive();
        rlDisableDepthMask();
        rlDisableBackfaceCulling();
        BeginBlendMode(i32(1));
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
                BeginBlendMode(i32(1));
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
                rlSetTexture(u32(0));
                spread = (1.0 - fade) * 6.0;
                distance = 0.0;
                while distance < length {
                    turn = distance * 0.1;
                    offset = ring_x.scale(math.cos(turn)).add(ring_y.scale(math.sin(turn)));
                    point = trail.start.add(axis.scale(distance)).add(offset.scale(3.0 + spread));
                    self.speck(point, side, up, 0.6, Vec3(x=0.3, y=0.45, z=1.0), fade);
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
                    scale = 2.2 / float(max(1, ring.frame.width));
                    self.billboard(
                        ring,
                        point,
                        side,
                        up,
                        scale,
                        ring_fade * 0.75,
                        tint=Vec3(x=1.0, y=0.0, z=1.0)
                    );
                }
                distance += 5.0;
                step += 1;
            }
        }
        rlDrawRenderBatchActive();
        rlSetTexture(u32(0));
        rlEnableDepthMask();
        rlEnableBackfaceCulling();
        EndBlendMode();
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
        EndBlendMode();
        rlEnableDepthMask();
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
        rlDisableDepthMask();
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
    }
}
