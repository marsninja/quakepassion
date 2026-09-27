"""A fixed budget of transient combat lights; no extra simulation timers."""
import from .lighting { Lighting, FlashLight }
import from .world { World, Player }
import from .combat {
    Opponent,
    HasOpponent,
    CombatState,
    Projectile,
    HasProjectile,
    muzzle_flash_age
}
import from .particles { Explosion, HasExplosion }
import from .models { PlayerRig, WeaponKit, Holds, RIG_FLASH_TIME }
import from ..math.vec3 { Vec3, forward_from }

"""The light a missile carries in flight, by effect."""
def missile_glow(effect: str) -> Vec3 {
    if effect in ["q2_bolt", "q1_laser"] {
        return Vec3(x=0.8, y=0.8, z=0.0);
    }
    if effect in ["q2_rocket", "q1_rocket", "q3_rocket", "q1_lavaball"] {
        return Vec3(x=0.9, y=0.6, z=0.2);
    }
    if effect == "q3_plasma" {
        return Vec3(x=0.2, y=0.2, z=1.0);
    }
    if effect in ["q2_bfg", "q3_bfg"] {
        return Vec3(x=0.2, y=1.0, z=0.2);
    }
    return Vec3();
}

def combat_lights(
    lighting: Lighting, world: World, player: Player, state: CombatState
) {
    lighting.dynamic = [];
    if state.flash > 0.0 {
        lighting.dynamic.append(
            FlashLight(
                origin=player.pos.add(
                    forward_from(player.yaw, player.pitch).scale(18.0)
                ),
                color=Vec3(x=1.0, y=0.65, z=0.25).scale(min(1.0, state.flash / 0.04))
            )
        );
    }
    # Explosion lights fade with the burst (Q1 dlight decay, Q2 light*alpha).
    for blast in [world->:HasExplosion:->][?:Explosion] {
        if len(lighting.dynamic) >= 6 or blast.light_radius <= 0.0 {
            continue;
        }
        fade = max(0.0, 1.0 - blast.age / max(0.001, blast.lifetime));
        lighting.dynamic.append(
            FlashLight(
                origin=blast.pos,
                color=blast.light.scale(fade),
                radius=blast.light_radius * (0.5 + 0.5 * fade)
            )
        );
    }
    # Glowing missiles: Q2 EF_BLASTER/EF_ROCKET, Q3 rocket and plasma, Q1 EF_ROCKET.
    for projectile in [world->:HasProjectile:->][?:Projectile] {
        if len(lighting.dynamic) >= 7 {
            break;
        }
        glow = missile_glow(projectile.effect);
        if glow.length() > 0.0 and projectile.phase == 0 {
            lighting.dynamic.append(FlashLight(origin=projectile.pos, color=glow, radius=200.0));
        }
    }
    candidates: list[tuple[float, int]] = [];
    opponents = [world->:HasOpponent:->][?:Opponent];
    for i in range(len(opponents)) {
        enemy = opponents[i];
        rig = enemy.visual;
        if isinstance(rig, PlayerRig) {
            # CG_AddPlayerWeapon: a Q3 muzzle flash lights its surroundings in
            # the weapon's colour for as long as the flash shows.
            if enemy.health > 0 and rig.clock - rig.flash_time < RIG_FLASH_TIME * 2.0 {
                candidates.append((enemy.pos.sub(player.pos).length(), i));
            }
        } elif enemy.health > 0 and muzzle_flash_age(enemy) >= 0.0 {
            candidates.append((enemy.pos.sub(player.pos).length(), i));
        }
    }
    for candidate in sorted(candidates) {
        if len(lighting.dynamic) >= 8 {
            break;
        }
        enemy = opponents[candidate[1]];
        rig = enemy.visual;
        if isinstance(rig, PlayerRig) {
            kits = [rig->:Holds:->][?:WeaponKit];
            lighting.dynamic.append(
                FlashLight(
                    origin=enemy.pos.add(forward_from(enemy.yaw, enemy.pitch).scale(20.0)),
                    color=kits[0].light if kits else Vec3(x=1.0, y=1.0, z=0.0),
                    radius=300.0
                )
            );
            continue;
        }
        # A monster's shot lights its muzzle for a moment (Q1 EF_MUZZLEFLASH,
        # Q2 CL_ParseMuzzleFlash2's 200-231 unit light in the flash's colour).
        lighting.dynamic.append(
            FlashLight(origin=enemy.flash_origin, color=enemy.flash_color, radius=216.0)
        );
    }
}
