"""Camera-facing archive sprites with explicit GPU ownership and depth testing."""
import math;
import from .models { ModelRenderer }
import from ..math.orientation { model_basis }
import from ..world.lighting { Lighting }
import from ..formats.bsp { Texture }
import from ..formats.sprite { SpriteFrame, EffectRule }
import from ..formats.q2.sprite { parse_sp2 }
import from ..formats.q2.model { parse_pcx }
import from ..assets.library { AssetLibrary }
import from ..world.world { World }
import from ..world.combat { Projectile, HasProjectile }
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
    rlEnableBackfaceCulling
}

obj UploadedSprite {
    has frame: SpriteFrame,
        texture: int,
        additive: bool = False,
        rotate: float = 0.0;
}

obj EffectScene {
    has flight: dict[str, list[UploadedSprite]] = {},
        burst: dict[str, list[UploadedSprite]] = {},
        textures: list[int] = [],
        models: dict[str, ModelRenderer] = {},
        renderers: dict[str, ModelRenderer] = {},
        rules: dict[str, EffectRule] = {};

    def keys() -> list[str] {
        return list(self.flight.keys()) + list(self.models.keys());
    }

    def frames(
        library: AssetLibrary, path: str, rule: EffectRule
    ) -> list[UploadedSprite] {
        result: list[UploadedSprite] = [];
        if not path {
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
        if not rules {
            return;
        }
        library = AssetLibrary(game=game);
        try {
            library.open(directory);
            for rule in rules {
                self.rules[rule.key] = rule;
                if rule.flight.lower().endswith((".mdl", ".md2", ".md3")) {
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

    def draw(
        world: World,
        eye: Vec3,
        yaw: float,
        pitch: float,
        lighting: Lighting = Lighting()
    ) {
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
        side = right_from(yaw);
        up = side.cross(forward_from(yaw, pitch)).normalized();
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
            frame = sprite.frame;
            corners = [
                (-float(frame.origin_x), -float(frame.origin_y), 0.0, 1.0),
                (
                    -float(frame.origin_x),
                    float(frame.height - frame.origin_y),
                    0.0,
                    0.0
                ),
                (
                    float(frame.width - frame.origin_x),
                    float(frame.height - frame.origin_y),
                    1.0,
                    0.0
                ),
                (float(frame.width - frame.origin_x), -float(frame.origin_y), 1.0, 1.0)
            ];
            BeginBlendMode(i32(1 if sprite.additive else 0));
            angle = -sprite.rotate * projectile.age * math.pi / 180.0;
            cosine = math.cos(angle);
            sine = math.sin(angle);
            rlSetTexture(u32(sprite.texture));
            rlBegin(i32(7));
            rlColor4ub(u8(255), u8(255), u8(255), u8(255));
            for corner in corners {
                point = projectile.pos.add(side.scale(corner[0])).add(
                    up.scale(corner[1])
                );
                u = corner[2] - 0.5;
                v = corner[3] - 0.5;
                rlTexCoord2f(
                    f32(0.5 + u * cosine - v * sine), f32(0.5 + u * sine + v * cosine)
                );
                rlVertex3f(f32(point.x), f32(point.y), f32(point.z));
            }
            rlEnd();
        }
        rlDrawRenderBatchActive();
        rlSetTexture(u32(0));
        rlEnableDepthMask();
        rlEnableBackfaceCulling();
        EndBlendMode();
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
    }
}
