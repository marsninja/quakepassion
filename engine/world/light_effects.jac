"""A fixed budget of transient combat lights; no extra simulation timers."""
import from .lighting { Lighting, FlashLight }
import from .world { World, Player }
import from .combat { Opponent, HasOpponent, CombatState }
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
        if enemy.health > 0 and enemy.attack_flash > 0.0 {
            candidates.append((enemy.pos.sub(player.pos).length(), i));
        }
    }
    for candidate in sorted(candidates) {
        if len(lighting.dynamic) >= 8 {
            break;
        }
        enemy = opponents[candidate[1]];
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
