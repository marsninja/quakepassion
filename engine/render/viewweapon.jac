"""Camera-relative original weapons using the shared animated model renderer."""
import math;
import from vendor.raylib {
    obj Matrix {
        has m0: f32,
            m4: f32,
            m8: f32,
            m12: f32,
            m1: f32,
            m5: f32,
            m9: f32,
            m13: f32,
            m2: f32,
            m6: f32,
            m10: f32,
            m14: f32,
            m3: f32,
            m7: f32,
            m11: f32,
            m15: f32;
    }  def rlGetMatrixProjection() -> Matrix;  def rlSetMatrixProjection(
        matrix: Matrix
    ) -> None;
}
import from .quake { rlDrawRenderBatchActive }
import from .models { ModelRenderer }
import from ..assets.library { AssetLibrary }
import from ..formats.animated { AnimatedModel }
import from ..math.vec3 { Vec3 }
import from ..math.orientation { Basis, model_basis }
import from ..world.world { Player }
import from ..world.combat { CombatState }
import from ..world.weapons { ViewWeaponRule, view_frame }
import from ..world.lighting { Lighting }

obj ViewAsset {
    has rule: ViewWeaponRule,
        drawing: ModelRenderer,
        barrel: ModelRenderer = ModelRenderer(),
        hand: AnimatedModel = AnimatedModel();
}

obj ViewWeapon {
    has assets: dict[int, ViewAsset] = {},
        selected: int = -1,
        shots: int = -1,
        fired_at: float = -100.0,
        switched_at: float = -100.0;

    def upload(game: str, directory: str, rules: list[ViewWeaponRule]) {
        self.close();
        if not rules {
            return;
        }
        library = AssetLibrary(game=game);
        try {
            library.open(directory);
            for rule in rules {
                renderer = ModelRenderer();
                asset = ViewAsset(rule=rule, drawing=renderer);
                self.assets[rule.slot] = asset;
                loaded = library.model(rule.model);
                renderer.upload(loaded.model, loaded.skins);
                if rule.hand {
                    path = rule.hand;
                    if path.lower() not in library.pk3.canonical_names {
                        path = "models/weapons2/shotgun/shotgun_hand.md3";
                    }
                    asset.hand = library.model(path).model;
                    assert asset.hand.tags;
                    barrel_path = rule.model[:-4] + "_barrel.md3";
                    if barrel_path.lower() in library.pk3.canonical_names {
                        barrel = library.model(barrel_path);
                        asset.barrel.upload(barrel.model, barrel.skins);
                    }
                }
            }
        } except Exception {
            self.close();
            raise;
        } finally {
            library.close();
        }
    }

    def draw(player: Player, state: CombatState, seconds: float, lighting: Lighting) {
        if player.health <= 0 or state.weapon not in self.assets {
            return;
        }
        if self.selected != state.weapon {
            self.selected = state.weapon;
            self.shots = state.shots;
            self.fired_at = -100.0;
            self.switched_at = seconds;
        }
        if self.shots != state.shots {
            self.shots = state.shots;
            self.fired_at = seconds;
        }
        asset = self.assets[state.weapon];
        frames = len(asset.hand.tags)
            if asset.hand.tags
            else len(asset.drawing.model.surfaces[0].frames);
        frame = view_frame(
            asset.rule,
            frames,
            seconds - self.fired_at,
            seconds - self.switched_at,
            hand_grenade=state.game == "q2" and state.weapon == 11,
            grenade_phase=state.grenade_phase,
            grenade_clock=state.grenade_clock
        );
        basis = model_basis(player.yaw, player.pitch);
        origin = player.pos.sub(
            basis.up.scale(10.0 * max(0.0, 1.0 - (seconds - self.switched_at) / 0.2))
        );
        speed = min(
            1.0, Vec3(x=player.velocity.x, y=player.velocity.y).length() / 320.0
        );
        if player.grounded {
            origin = origin.add(
                basis.left.scale(math.sin(seconds * 8.0) * speed * 0.5)
            );
            origin = origin.add(
                basis.up.scale(abs(math.cos(seconds * 8.0)) * speed * 0.5)
            );
        }
        recoil = max(0.0, 1.0 - (seconds - self.fired_at) / 0.16);
        origin = origin.sub(basis.forward.scale(recoil * 1.5));
        model_frame = frame;
        if asset.hand.tags {
            for tag in asset.hand.tags[frame].tags {
                if tag.name == "tag_weapon" {
                    origin = origin.add(basis.apply(tag.origin));
                    basis = Basis(
                        forward=basis.apply(tag.axes[0]),
                        left=basis.apply(tag.axes[1]),
                        up=basis.apply(tag.axes[2])
                    );
                    break;
                }
            }
            model_frame = 0;
        }
        # Compress clip-space depth to the near 30%, preserving self-occlusion.
        # Flush on both sides so the world and HUD retain their own projection.
        rlDrawRenderBatchActive();
        projection = rlGetMatrixProjection();
        weapon_projection = rlGetMatrixProjection();
        weapon_projection.m2 = f32(
            0.3 * float(projection.m2) - 0.7 * float(projection.m3)
        );
        weapon_projection.m6 = f32(
            0.3 * float(projection.m6) - 0.7 * float(projection.m7)
        );
        weapon_projection.m10 = f32(
            0.3 * float(projection.m10) - 0.7 * float(projection.m11)
        );
        weapon_projection.m14 = f32(
            0.3 * float(projection.m14) - 0.7 * float(projection.m15)
        );
        rlSetMatrixProjection(weapon_projection);
        illumination = lighting.sample(player.pos);
        illumination.ambient = Vec3(
            x=max(0.1, illumination.ambient.x),
            y=max(0.1, illumination.ambient.y),
            z=max(0.1, illumination.ambient.z)
        );
        try {
            asset.drawing.draw(
                origin,
                player.yaw,
                first=model_frame,
                second=model_frame,
                eye=player.pos,
                seconds=seconds,
                illumination=illumination,
                basis=basis
            );
            if asset.barrel.stages and asset.drawing.model.tags {
                for tag in asset.drawing.model.tags[0].tags {
                    if tag.name == "tag_barrel" {
                        barrel_basis = Basis(
                            forward=basis.apply(tag.axes[0]),
                            left=basis.apply(tag.axes[1]),
                            up=basis.apply(tag.axes[2])
                        );
                        asset.barrel.draw(
                            origin.add(basis.apply(tag.origin)),
                            player.yaw,
                            eye=player.pos,
                            seconds=seconds,
                            illumination=illumination,
                            basis=barrel_basis
                        );
                        break;
                    }
                }
            }
            rlDrawRenderBatchActive();
        } finally {
            rlSetMatrixProjection(projection);
        }
    }

    def close() {
        for asset in self.assets.values() {
            asset.drawing.close();
            asset.barrel.close();
        }
        self.assets = {};
        self.selected = -1;
        self.shots = -1;
    }
}
