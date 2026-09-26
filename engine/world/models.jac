"""Visual components and shared model resources attached to world entities."""
import math;
import from .world { World, Area, Entity, In, Actor }
import from .powerups { Empowered, Powerup }
import from ..formats.animated { AnimatedModel, ModelTag }
import from ..formats.bsp { Texture }
import from ..math.vec3 { Vec3 }
import from ..math.orientation { Basis, quake_basis }

edge HasVisual: Entity --> Visual {}
edge UsesModel: Visual --> ModelResource {}
edge HasModelResource: World --> ModelResource {}

node ModelResource {
    has name: str,
        model: AnimatedModel,
        skins: list[Texture];
}

node Visual {
    has offset: Vec3 = Vec3(),
        first: int = 0,
        second: int = 0,
        blend: float = 0.0,
        visible: bool = True,
        spin: float = 0.0,
        bob: float = 0.0,
        bob_rate: float = 5.0,
        pitch: float = 0.0,
        roll: float = 0.0;
}

obj ModelDraw {
    has resource: ModelResource,
        origin: Vec3,
        yaw: float,
        first: int,
        second: int,
        blend: float,
        pitch: float = 0.0,
        roll: float = 0.0,
        basis: Basis | None = None,
        light_origin: Vec3 | None = None,
        shader: str = "",
        inflate: float = 0.0;
}

"""Q3 powerup shaders (cgs.media.quadShader and friends), registered as model
resources named "shader:<shader>", and how far each pushes the surface out
(its deformVertexes wave base). Bodies and weapons use different ones."""
glob POWERUP_BODY_SHELLS: dict[str, str] = {
    "quad": "powerups/quad",
    "regen": "powerups/regen",
    "battlesuit": "powerups/battleSuit"
};
glob POWERUP_WEAPON_SHELLS: dict[str, str] = {
    "quad": "powerups/quadWeapon",
    "battlesuit": "powerups/battleWeapon"
};
glob POWERUP_INVISIBLE: str = "powerups/invisibility";
glob POWERUP_INFLATE: dict[str, float] = {
    "powerups/quad": 3.0,
    "powerups/regen": 3.0,
    "powerups/battleSuit": 1.0,
    "powerups/quadWeapon": 0.5,
    "powerups/battleWeapon": 0.5,
    "powerups/invisibility": 0.0
};

"""CG_AddRefEntityWithPowerups (and CG_AddWeaponWithPowerups for a weapon):
the shaders one model is drawn with. An invisible player is only the
invisibility shader; otherwise the model itself ("") then a shell per
powerup, the regeneration one flashing a tenth of the time."""
def powerup_shaders(powers: list[str], seconds: float, weapon: bool = False) -> list[str] {
    if "invisibility" in powers {
        return [POWERUP_INVISIBLE];
    }
    shaders = [""];
    shells = POWERUP_WEAPON_SHELLS if weapon else POWERUP_BODY_SHELLS;
    for kind in ["quad", "regen", "battlesuit"] {
        if kind in powers and kind in shells {
            if kind == "regen" and int(seconds * 10.0) % 10 != 1 {
                continue;
            }
            shaders.append(shells[kind]);
        }
    }
    return shaders;
}

"""A Q3 animation.cfg sequence (cg_players.c animation_t): its frames, the
looping tail, seconds per frame, and whether it plays backwards."""
obj AnimationClip {
    has first: int = 0,
        count: int = 1,
        loop: int = 0,
        lerp: float = 0.05,
        reversed: bool = False;
}

"""cg_players.c lerpFrame_t: one body part's running sequence, the frames it
blends between, and the swing state of its yaw and pitch."""
obj LerpFrame {
    has animation: int = -1,
        toggle: int = 0,
        old_frame: int = 0,
        frame: int = 0,
        old_time: float = 0.0,
        frame_time: float = 0.0,
        start_time: float = 0.0,
        backlerp: float = 0.0,
        yaw: float = 0.0,
        yawing: bool = False,
        pitch: float = 0.0,
        pitching: bool = False;
}

"""One weapon's world models (cg_weapons.c weaponInfo_t): the gun, its
optional spinning barrel and muzzle flash, the flash's light colour, and
whether it flashes for as long as it fires (lightning gun, gauntlet)."""
node WeaponKit {
    has key: str = "",
        light: Vec3 = Vec3(),
        continuous: bool = False;
}

"""A kit's models by role: "weapon", "barrel" or "flash"."""
edge KitPart: WeaponKit --> ModelResource {
    has role: str = "";
}

"""A Q3 player body drawn the way CG_Player does: legs, torso and head are
separate MD3 models, each running its own animation, joined every frame
through tag_torso and tag_head, with the held weapon on tag_weapon, its barrel
on tag_barrel and the muzzle flash on tag_flash. Angles are Quake degrees
[pitch, yaw, roll]: the legs' are absolute, the torso's relative to the legs
and the head's relative to the torso (CG_PlayerAngles)."""
node PlayerRig(Visual) {
    has clips: list[AnimationClip] = [],
        clock: float = 0.0,
        legs: LerpFrame = LerpFrame(),
        torso: LerpFrame = LerpFrame(),
        legs_angles: Vec3 = Vec3(),
        torso_angles: Vec3 = Vec3(),
        head_angles: Vec3 = Vec3(),
        legs_anim: int = 22,
        legs_toggle: int = 0,
        torso_anim: int = 11,
        torso_toggle: int = 0,
        legs_timer: float = 0.0,
        torso_timer: float = 0.0,
        move_dir: int = 0,
        backwards_jump: bool = False,
        grounded: bool = True,
        airborne: float = 0.0,
        fall_speed: float = 0.0,
        underwater: bool = False,
        alive: bool = True,
        deaths: int = 0,
        weapon: str = "",
        switching: str = "",
        shots: int = 0,
        seen_shots: int = 0,
        firing: bool = False,
        flash_time: float = -10.0,
        flash_roll: float = 0.0,
        barrel_angle: float = 0.0,
        barrel_time: float = 0.0,
        barrel_spinning: bool = False,
        barrel_roll: float = 0.0,
        pain_time: float = -10.0,
        pain_left: bool = False,
        step_cycle: float = 0.0,
        hurt: bool = False,
        random: int = 1,
        character: str = "",
        voice: str = "sound/player/sarge/",
        footsteps: str = "step",
        head_offset: Vec3 = Vec3(),
        fixed_legs: bool = False,
        fixed_torso: bool = False;
}

"""A rig's part models by role: "lower", "upper" and "head"."""
edge Wears: PlayerRig --> ModelResource {
    has role: str = "";
}

"""The weapon a rig holds."""
edge Holds: PlayerRig --> WeaponKit {}

# cg_weapons.c MUZZLE_FLASH_TIME, a little longer so a frame always shows it.
glob RIG_FLASH_TIME: float = 0.03;

"""R_LerpTag: a tag between two frames. Axes are blended, not renormalized."""
def lerp_tag(model: AnimatedModel, first: int, second: int, blend: float, name: str) -> ModelTag | None {
    count = len(model.tags);
    if count == 0 {
        return None;
    }
    a = model.tags[max(0, min(first, count - 1))].tags;
    b = model.tags[max(0, min(second, count - 1))].tags;
    for i in range(min(len(a), len(b))) {
        if a[i].name == name {
            return ModelTag(
                name=name,
                origin=a[i].origin.lerp(b[i].origin, blend),
                axes=[a[i].axes[k].lerp(b[i].axes[k], blend) for k in range(3)]
            );
        }
    }
    return None;
}

"""CG_PositionEntityOnTag (no `local`) and CG_PositionRotatedEntityOnTag: a
child placed on its parent's tag, optionally turned first by its own axes."""
obj Placement {
    has origin: Vec3,
        basis: Basis;

    def on_tag(tag: ModelTag, local: Basis | None = None) -> Placement {
        mount = Basis(forward=tag.axes[0], left=tag.axes[1], up=tag.axes[2]);
        if local is not None {
            mount = Basis(
                forward=mount.apply(local.forward),
                left=mount.apply(local.left),
                up=mount.apply(local.up)
            );
        }
        return Placement(
            origin=self.origin.add(self.basis.apply(tag.origin)),
            basis=Basis(
                forward=self.basis.apply(mount.forward),
                left=self.basis.apply(mount.left),
                up=self.basis.apply(mount.up)
            )
        );
    }
}

"""Collect visible models. Items spin on the shared world clock and may bob,
as every client did (Q1/Q2 autorotate, Q3 cg.autoAngles and item bobbing)."""
walker GatherModels {
    has draws: list[ModelDraw] = [],
        seconds: float = 0.0;

    can begin with World entry {
        visit [here-->[?:Area]];
    }

    can area with Area entry {
        visit [here<-:In:<-];
    }

    """One model draw per powerup shader."""
    def add_part(draw: ModelDraw, shaders: list[str]) {
        for shader in shaders {
            if not shader {
                self.draws.append(draw);
                continue;
            }
            self.draws.append(
                ModelDraw(resource=draw.resource, origin=draw.origin, yaw=draw.yaw, first=draw.first,
                    second=draw.second, blend=draw.blend, basis=draw.basis, light_origin=draw.light_origin,
                    shader="shader:" + shader, inflate=POWERUP_INFLATE.get(shader, 0.0))
            );
        }
    }

    """CG_Player: legs, torso, head, gun, barrel and flash for one rig, each
    with its carrier's powerup shaders."""
    def add_rig(rig: PlayerRig, origin: Vec3, powers: list[str] = []) {
        body = powerup_shaders(powers, self.seconds) if powers else [""];
        arms = powerup_shaders(powers, self.seconds, True) if powers else [""];
        links = [edge rig->:Wears:->];
        models = [rig->:Wears:->][?:ModelResource];
        lower: ModelResource | None = None;
        upper: ModelResource | None = None;
        head: ModelResource | None = None;
        for i in range(min(len(links), len(models))) {
            role = links[i].role;
            if role == "lower" {
                lower = models[i];
            } elif role == "upper" {
                upper = models[i];
            } elif role == "head" {
                head = models[i];
            }
        }
        if lower is None or upper is None {
            return;
        }
        legs = Placement(origin=origin, basis=quake_basis(rig.legs_angles));
        legs_blend = 1.0 - rig.legs.backlerp;
        torso_blend = 1.0 - rig.torso.backlerp;
        self.add_part(
            ModelDraw(resource=lower, origin=legs.origin, yaw=0.0, first=rig.legs.old_frame,
                second=rig.legs.frame, blend=legs_blend, basis=legs.basis, light_origin=origin),
            body
        );
        mount = lerp_tag(lower.model, rig.legs.old_frame, rig.legs.frame, legs_blend, "tag_torso");
        if mount is None {
            return;
        }
        torso = legs.on_tag(mount, quake_basis(rig.torso_angles));
        self.add_part(
            ModelDraw(resource=upper, origin=torso.origin, yaw=0.0, first=rig.torso.old_frame,
                second=rig.torso.frame, blend=torso_blend, basis=torso.basis, light_origin=origin),
            body
        );
        if head is not None {
            neck = lerp_tag(upper.model, rig.torso.old_frame, rig.torso.frame, torso_blend, "tag_head");
            if neck is not None {
                top = torso.on_tag(neck, quake_basis(rig.head_angles));
                self.add_part(
                    ModelDraw(resource=head, origin=top.origin, yaw=0.0, first=0, second=0,
                        blend=0.0, basis=top.basis, light_origin=origin),
                    body
                );
            }
        }
        # Dead players hold nothing (player_die drops the weapon).
        kits = [rig->:Holds:->][?:WeaponKit] if rig.alive else [];
        if not kits {
            return;
        }
        hand = lerp_tag(upper.model, rig.torso.old_frame, rig.torso.frame, torso_blend, "tag_weapon");
        if hand is None {
            return;
        }
        parts = [edge kits[0]->:KitPart:->];
        pieces = [kits[0]->:KitPart:->][?:ModelResource];
        gun: ModelResource | None = None;
        barrel: ModelResource | None = None;
        flash: ModelResource | None = None;
        for i in range(min(len(parts), len(pieces))) {
            if parts[i].role == "weapon" {
                gun = pieces[i];
            } elif parts[i].role == "barrel" {
                barrel = pieces[i];
            } elif parts[i].role == "flash" {
                flash = pieces[i];
            }
        }
        if gun is None {
            return;
        }
        held = torso.on_tag(hand);
        self.add_part(
            ModelDraw(resource=gun, origin=held.origin, yaw=0.0, first=0, second=0, blend=0.0,
                basis=held.basis, light_origin=origin),
            arms
        );
        if barrel is not None {
            spindle = lerp_tag(gun.model, 0, 0, 0.0, "tag_barrel");
            if spindle is not None {
                spun = held.on_tag(spindle, quake_basis(Vec3(z=rig.barrel_roll)));
                self.add_part(
                    ModelDraw(resource=barrel, origin=spun.origin, yaw=0.0, first=0, second=0,
                        blend=0.0, basis=spun.basis, light_origin=origin),
                    arms
                );
            }
        }
        # Impulse flashes last MUZZLE_FLASH_TIME; the lightning gun and
        # gauntlet flash for as long as they fire.
        if flash is not None and (rig.clock - rig.flash_time < RIG_FLASH_TIME or (rig.firing and kits[0].continuous)) {
            muzzle = lerp_tag(gun.model, 0, 0, 0.0, "tag_flash");
            if muzzle is not None {
                lit = held.on_tag(muzzle, quake_basis(Vec3(z=rig.flash_roll)));
                self.draws.append(
                    ModelDraw(resource=flash, origin=lit.origin, yaw=0.0, first=0, second=0,
                        blend=0.0, basis=lit.basis, light_origin=origin)
                );
            }
        }
    }

    can entity with Entity entry {
        for visual in [here->:HasVisual:->][?:Visual] {
            if not visual.visible {
                continue;
            }
            origin = here.pos.add(visual.offset);
            if isinstance(visual, PlayerRig) {
                powers: list[str] = [];
                if isinstance(here, Actor) {
                    powers = [power.kind for power in [here->:Empowered:->][?:Powerup] if power.remaining != 0.0];
                }
                self.add_rig(visual, origin, powers);
                continue;
            }
            yaw = here.yaw;
            if visual.spin != 0.0 {
                yaw = math.radians((visual.spin * self.seconds) % 360.0);
            }
            if visual.bob != 0.0 {
                origin = origin.add(
                    Vec3(
                        z=visual.bob
                            + math.cos((self.seconds + 1.0) * visual.bob_rate) * visual.bob
                    )
                );
            }
            for resource in [visual->:UsesModel:->][?:ModelResource] {
                self.draws.append(
                    ModelDraw(
                        resource=resource,
                        origin=origin,
                        yaw=yaw,
                        first=visual.first,
                        second=visual.second,
                        blend=visual.blend,
                        pitch=visual.pitch,
                        roll=visual.roll
                    )
                );
            }
        }
    }
}


def attach_model(entity: Entity, resource: ModelResource) -> Visual {
    visual = Visual();
    entity +>:HasVisual:+> visual;
    visual +>:UsesModel:+> resource;
    return visual;
}
