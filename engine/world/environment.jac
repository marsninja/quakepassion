"""Liquid exposure runs on simulation time, independently of render frequency."""
import from .world { Player }
import from .damage { Damage }
import from .powerups { empowered }

walker EnvironmentTick {
    has game: str,
        dt: float,
        active: bool = True;

    can expose with Player entry {
        if self.dt <= 0.0 {
            return;
        }
        # Only Q2 goes on burning the dead. p_view.c P_WorldEffects asks for
        # health before it drowns a player, but not before lava or slime
        # sizzles one, so a body lying in either burns down to its gib
        # health. Q1's dead take no damage (Killed: DAMAGE_NO, and WaterMove
        # leaves below zero health); Q3's P_WorldEffects asks for health.
        dead = here.health <= 0;
        if dead and self.game != "q2" {
            return;
        }
        if not self.active {
            here.air_remaining = 12.0;
            here.drown_damage = 2;
            here.hazard_wait = 0.0;
            return;
        }
        suited = empowered(here, "suit") or empowered(here, "battlesuit");
        breathing = suited or empowered(here, "breather");
        if here.water_depth < 3 or breathing or dead {
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
                    amount=here.drown_damage,
                    bypass_armor=self.game != "q1",
                    means="drown"
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
        # Biosuit/environment suit rules follow Q1 client.qc and Q2 p_view.c.
        if suited and not lava and self.game != "q3" {
            return;
        }
        amount = 0;
        if self.game == "q1" {
            amount = 10 if lava else 4;
            here.hazard_wait = (1.0 if suited else 0.2) if lava else 1.0;
        } elif self.game == "q2" {
            amount = (1 if suited else 3) if lava else 1;
            here.hazard_wait = 0.1;
        } else {
            amount = 30 if lava else 10;
            here.hazard_wait = 0.7;
        }
        here spawn Damage(amount=amount * here.water_depth, means="environment");
    }
}
