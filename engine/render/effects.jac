"""Camera-facing archive sprites with explicit GPU ownership and depth testing."""
import from ..formats.sprite { SpriteFrame, EffectRule }
import from ..formats.q2.sprite { parse_sp2 }
import from ..formats.q2.model { parse_pcx }
import from ..assets.library { AssetLibrary }
import from ..world.world { World }
import from ..world.combat { Projectile, HasProjectile }
import from ..math.vec3 { Vec3, forward_from, right_from }
import from .quake {
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
        texture: int;
}

obj EffectScene {
    has flight: dict[str, list[UploadedSprite]] = {},
        burst: dict[str, list[UploadedSprite]] = {},
        textures: list[int] = [];

    def frames(library: AssetLibrary, path: str) -> list[UploadedSprite] {
        result: list[UploadedSprite] = [];
        if not path {
            return result;
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
            result.append(UploadedSprite(frame=frame, texture=texture));
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
                self.flight[rule.key] = self.frames(library, rule.flight);
                self.burst[rule.key] = self.frames(library, rule.burst);
            }
        } except Exception {
            self.close();
            raise;
        } finally {
            library.close();
        }
    }

    def draw(world: World, eye: Vec3, yaw: float, pitch: float) {
        if not self.textures {
            return;
        }
        projectiles = [
            projectile
            for projectile in [world->:HasProjectile:->][?:Projectile]
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
            rlSetTexture(u32(sprite.texture));
            rlBegin(i32(7));
            rlColor4ub(u8(255), u8(255), u8(255), u8(255));
            for corner in corners {
                point = projectile.pos.add(side.scale(corner[0])).add(
                    up.scale(corner[1])
                );
                rlTexCoord2f(f32(corner[2]), f32(corner[3]));
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
        self.textures = [];
        self.flight = {};
        self.burst = {};
    }
}
