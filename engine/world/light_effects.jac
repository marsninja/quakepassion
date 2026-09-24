"""A fixed budget of transient combat lights; no extra simulation timers."""
import from .lighting { Lighting, FlashLight }
import from .world { World, Player }
import from .combat { Opponent, HasOpponent, CombatState }
import from .models { PlayerRig, WeaponKit, Holds, RIG_FLASH_TIME }
import from ..math.vec3 { Vec3, forward_from }

def combat_lights(
    lighting: Lighting, world: World, player: Player, state: CombatState
) {
    lighting.dynamic = [];
    if not lighting.regions {
        return;
    }
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
        } elif enemy.health > 0 and enemy.attack_flash > 0.0 {
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
        lighting.dynamic.append(
            FlashLight(
                origin=enemy.pos,
                color=Vec3(x=1.0, y=0.5, z=0.2).scale(
                    min(1.0, enemy.attack_flash / 0.1)
                )
            )
        );
    }
}
