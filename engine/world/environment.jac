"""Liquid exposure runs on simulation time, independently of render frequency."""
import from .world { Player }
import from .damage { Damage }

walker EnvironmentTick {
    has game: str,
        dt: float,
        active: bool = True;

    can expose with Player entry {
        if self.dt <= 0.0 or here.health <= 0 {
            return;
        }
        if not self.active {
            here.air_remaining = 12.0;
            here.drown_damage = 2;
            here.hazard_wait = 0.0;
            return;
        }
        if here.water_depth < 3 {
            here.air_remaining = 12.0;
            here.drown_damage = 2;
        } else {
            here.air_remaining -= self.dt;
            while here.air_remaining < -0.000001 and here.health > 0 {
                here.drown_damage += 2;
                if here.drown_damage > 15 {
                    here.drown_damage = 10 if self.game == "q1" else 15;
                }
                here spawn Damage(
                    amount=here.drown_damage, bypass_armor=self.game != "q1"
                );
                here.air_remaining += 1.0;
            }
        }
        here.hazard_wait = max(0.0, here.hazard_wait - self.dt);
        if here.water_depth == 0 or here.liquid_kind < 2 {
            return;
        }
        if here.hazard_wait > 0.000001 {
            return;
        }
        lava = here.liquid_kind == 3;
        amount = 0;
        if self.game == "q1" {
            amount = 10 if lava else 4;
            here.hazard_wait = 0.2 if lava else 1.0;
        } elif self.game == "q2" {
            amount = 3 if lava else 1;
            here.hazard_wait = 0.1;
        } else {
            amount = 30 if lava else 10;
            here.hazard_wait = 0.7;
        }
        here spawn Damage(amount=amount * here.water_depth);
    }
}
