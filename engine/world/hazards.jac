"""Authored damage volumes, activation, and game-specific contact intervals."""
import from .world { World, Player }
import from .signals { Signal, HasSignal }
import from .damage { Damage }
import from .combat { Opponent, HasOpponent, damage_opponent }
import from .triggers { trigger_volume }
import from ..formats.bsp { Bsp }
import from ..formats.q1.collision { build_collision }
import from ..formats.brush_collision { build_brush_collision }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

edge HasHazard: World --> Hazard {}
node Hazard {
    has volume: CollisionMap,
        damage: int = 5,
        interval: float = 0.1,
        enabled: bool = True,
        toggle: bool = False,
        bypass_armor: bool = False,
        cooldown: float = 0.0,
        activation: Signal = Signal();
}

walker HazardTick {
    has player: Player,
        start: Vec3,
        finish: Vec3,
        dt: float,
        touching: bool = True,
        top_drop: float = 0.0,
        dealt: int = 0,
        eye_height: float = 22.0,
        opponents: list[Opponent] = [];

    can begin with World entry {
        if self.dt > 0.0 {
            self.opponents = [
                enemy
                for enemy in [here->:HasOpponent:->][?:Opponent]
                if not enemy.dormant and enemy.health > 0
            ];
            visit [here->:HasHazard:->];
        }
    }

    can contact with Hazard entry {
        if here.activation.pending > 0 {
            if here.toggle and here.activation.pending % 2 != 0 {
                here.enabled = not here.enabled;
            }
            here.activation.pending = 0;
        }
        here.cooldown = max(0.0, here.cooldown - self.dt);
        if not here.enabled or here.cooldown > 0.000001 {
            return;
        }
        if self.touching and self.player.health > 0 {
            hit = here.volume.trace(self.start, self.finish, top_drop=self.top_drop);
            if hit.start_solid or hit.fraction < 1.0 {
                damage = self.player spawn Damage(
                    amount=here.damage, bypass_armor=here.bypass_armor
                );
                self.dealt += damage.dealt;
                here.cooldown = here.interval;
                return;
            }
        }
        for enemy in self.opponents {
            if enemy.health <= 0 {
                continue;
            }
            origin = enemy.pos.sub(Vec3(z=self.eye_height));
            hit = here.volume.trace(origin, origin, top_drop=0.0);
            if hit.start_solid {
                damage_opponent(enemy,here.damage,bypass_armor=here.bypass_armor);
                here.cooldown = here.interval;
                return;
            }
        }
    }
}

def load_hazards(world: World, bsp: Bsp) {
    if not any(
        entity.fields.get("classname", "") == "trigger_hurt" for entity in bsp.entities
    ) {
        return;
    }
    volumes = build_collision(bsp, triggers=True)
        if bsp.game == "q1"
        else build_brush_collision(bsp, triggers=True);
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") != "trigger_hurt" {
            continue;
        }
        model = fields.get("model", "");
        if not model.startswith("*") {
            continue;
        }
        volume = trigger_volume(volumes, int(model[1:]));
        if not volume.hulls {
            continue;
        }
        flags = int(fields.get("spawnflags", "0"));
        amount = int(fields.get("dmg", "5"));
        if amount == 0 {
            amount = 5;
        }
        hazard = Hazard(
            volume=volume,
            damage=max(0, amount),
            interval=1.0 if bsp.game == "q1" or flags & 16 != 0 else 0.1,
            enabled=bsp.game == "q1" or flags & 1 == 0,
            toggle=bsp.game != "q1" and flags & 2 != 0,
            bypass_armor=bsp.game != "q1" and flags & 8 != 0,
            activation=Signal(entities=[index])
        );
        world +>:HasHazard:+> hazard;
        if hazard.toggle {
            world +>:HasSignal:+> hazard.activation;
        }
    }
}
