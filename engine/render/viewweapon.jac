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
import from ..formats.animated { AnimatedModel, AnimatedSurface }
import from ..world.models { powerup_shaders, POWERUP_INFLATE, POWERUP_INVISIBLE }
import from ..world.powerups { Empowered, Powerup }
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
        flash: ModelRenderer = ModelRenderer(),
        hand: AnimatedModel = AnimatedModel();
}

obj ViewWeapon {
    has assets: dict[int, ViewAsset] = {},
        selected: int = -1,
        shots: int = -1,
        fired_at: float = -100.0,
        switched_at: float = -100.0,
        shells: dict[str, ModelRenderer] = {},
        barrel_angle: float = 0.0,
        barrel_time: float = 0.0,
        barrel_spinning: bool = False,
        flash_roll: float = 0.0;

    def upload(game: str, directory: str, rules: list[ViewWeaponRule]) {
        self.close();
        if not rules {
            return;
        }
        library = AssetLibrary(game=game);
        try {
            library.open(directory);
            if game == "q3" {
                # The powerup shaders the gun may be drawn with.
                for shader in [POWERUP_INVISIBLE, "powerups/quadWeapon", "powerups/battleWeapon"] {
                    stages = library.pk3.model_stages(shader, True);
                    if stages {
                        shell = ModelRenderer();
                        shell.upload(AnimatedModel(surfaces=[AnimatedSurface(name=shader, stages=stages)]), [stages[0].texture]);
                        self.shells[shader] = shell;
                    }
                }
            }
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
                    flash_path = rule.model[:-4] + "_flash.md3";
                    if flash_path.lower() in library.pk3.canonical_names {
                        flash = library.model(flash_path);
                        asset.flash.upload(flash.model, flash.skins);
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

    """`lift` raises the weapon by that fraction of the screen height, so a
    weapon drawn at the bottom of the view sits above an opaque status bar."""
    def draw(player: Player, state: CombatState, seconds: float, lighting: Lighting, lift: float = 0.0) {
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
            # CG_AddPlayerWeapon turns each flash a random few degrees.
            self.flash_roll = math.sin(seconds * 7919.0) * 10.0;
        }
        # cg_weapons.c CG_MachinegunSpinAngle: 0.9 degrees a millisecond while
        # firing, coasting to a stop over a second.
        firing = seconds - self.fired_at < 0.2;
        delta = max(0.0, seconds - self.barrel_time) * 1000.0;
        spin = self.barrel_angle + delta * 0.9;
        if not self.barrel_spinning {
            coast = min(delta, 1000.0);
            spin = self.barrel_angle + coast * 0.5 * (0.9 + (1000.0 - coast) / 1000.0);
        }
        if self.barrel_spinning != firing {
            self.barrel_time = seconds;
            self.barrel_angle = spin % 360.0;
            self.barrel_spinning = firing;
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
        # Shift clip-space y by the lift (in NDC, twice the screen fraction).
        if lift > 0.0 {
            shift = 2.0 * lift;
            weapon_projection.m1 = f32(float(projection.m1) + shift * float(projection.m3));
            weapon_projection.m5 = f32(float(projection.m5) + shift * float(projection.m7));
            weapon_projection.m9 = f32(float(projection.m9) + shift * float(projection.m11));
            weapon_projection.m13 = f32(float(projection.m13) + shift * float(projection.m15));
        }
        rlSetMatrixProjection(weapon_projection);
        illumination = lighting.sample(player.pos);
        illumination.ambient = Vec3(
            x=max(0.1, illumination.ambient.x),
            y=max(0.1, illumination.ambient.y),
            z=max(0.1, illumination.ambient.z)
        );
        try {
            # CG_AddWeaponWithPowerups: invisible, or plain plus powerup shells.
            powers = [power.kind for power in [player->:Empowered:->][?:Powerup] if power.remaining != 0.0];
            shaders = powerup_shaders(powers, seconds, True);
            for shader in shaders {
                shell = self.shells[shader] if shader in self.shells else None;
                if shader and shell is None {
                    continue;
                }
                asset.drawing.draw(
                    origin,
                    player.yaw,
                    first=model_frame,
                    second=model_frame,
                    eye=player.pos,
                    seconds=seconds,
                    illumination=illumination,
                    basis=basis,
                    overlay=shell,
                    inflate=POWERUP_INFLATE.get(shader, 0.0)
                );
            }
            if asset.barrel.stages and asset.drawing.model.tags {
                for tag in asset.drawing.model.tags[0].tags {
                    if tag.name == "tag_barrel" {
                        turned = model_basis(0.0, 0.0, math.radians(spin % 360.0));
                        mount = Basis(forward=tag.axes[0], left=tag.axes[1], up=tag.axes[2]);
                        barrel_basis = Basis(
                            forward=basis.apply(mount.apply(turned.forward)),
                            left=basis.apply(mount.apply(turned.left)),
                            up=basis.apply(mount.apply(turned.up))
                        );
                        for shader in shaders {
                            shell = self.shells[shader] if shader in self.shells else None;
                            if shader and shell is None {
                                continue;
                            }
                            asset.barrel.draw(
                                origin.add(basis.apply(tag.origin)),
                                player.yaw,
                                eye=player.pos,
                                seconds=seconds,
                                illumination=illumination,
                                basis=barrel_basis,
                                overlay=shell,
                                inflate=POWERUP_INFLATE.get(shader, 0.0)
                            );
                        }
                        break;
                    }
                }
            }
            # The muzzle flash on tag_flash: MUZZLE_FLASH_TIME after a shot,
            # or all the while the lightning gun or gauntlet fires.
            continuous = state.weapon in [1, 6] and firing;
            if asset.flash.stages and asset.drawing.model.tags
                and (seconds - self.fired_at < 0.03 or continuous) {
                for tag in asset.drawing.model.tags[0].tags {
                    if tag.name == "tag_flash" {
                        turned = model_basis(0.0, 0.0, math.radians(self.flash_roll));
                        mount = Basis(forward=tag.axes[0], left=tag.axes[1], up=tag.axes[2]);
                        asset.flash.draw(
                            origin.add(basis.apply(tag.origin)),
                            player.yaw,
                            eye=player.pos,
                            seconds=seconds,
                            basis=Basis(
                                forward=basis.apply(mount.apply(turned.forward)),
                                left=basis.apply(mount.apply(turned.left)),
                                up=basis.apply(mount.apply(turned.up))
                            )
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
            asset.flash.close();
        }
        for shell in self.shells.values() {
            shell.close();
        }
        self.shells = {};
        self.assets = {};
        self.selected = -1;
        self.shots = -1;
    }
}
