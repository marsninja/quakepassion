"""Shared health and armor mutations, independent of input and rendering."""
import math;
import from .world { Actor, Player }
import from .powerups { effect, power_armor_save }
import from ..math.vec3 { Vec3 }

"""Apply one hit to an actor. `means` separates direct hits from "splash",
"environment" (liquids), "drown" and "fall" damage, which some powerups
ignore; `bypass_protection` marks telefrags and kill volumes."""
walker Damage {
    has amount: int,
        bypass_armor: bool = False,
        bypass_protection: bool = False,
        means: str = "",
        source: Vec3 | None = None,
        attacker: Actor | None = None,
        dealt: int = 0,
        absorbed: int = 0,
        shielded: int = 0,
        protected: bool = False,
        killed: bool = False,
        overkill: int = 0;

    can apply with Actor entry {
        if self.amount <= 0 or here.health <= 0 {
            return;
        }
        if isinstance(here, Player) and here.god_mode {
            return;
        }
        if not self.bypass_protection {
            shield = effect(here, "invulnerability");
            if shield is not None and shield.remaining > 0.0 {
                self.protected = True;
                shield.count += 1;
                return;
            }
            suit = effect(here, "battlesuit");
            if suit is not None and suit.remaining > 0.0 {
                self.protected = True;
                suit.count += 1;
                if self.means in ["splash", "fall", "environment", "drown"] {
                    return;
                }
                self.amount = max(1, self.amount // 2);
            }
        }
        if not self.bypass_armor {
            self.shielded = power_armor_save(here, self.amount, self.source);
            self.amount -= self.shielded;
            if self.amount <= 0 {
                return;
            }
        }
        if not self.bypass_armor {
            self.absorbed = min(
                here.armor,
                int(
                    math.ceil(float(self.amount) * max(0.0, min(1.0, here.armor_ratio)))
                )
            );
            here.armor -= self.absorbed;
        }
        self.dealt = min(here.health, self.amount - self.absorbed);
        # Health stops at zero; how far past it the hit went decides gibbing.
        self.overkill = self.amount - self.absorbed - self.dealt;
        here.health -= self.dealt;
        self.killed = here.health == 0;
        if self.killed {
            # Match scoring credits the attacker; None means a world death.
            here.killer = self.attacker;
            here.death_means = self.means;
        }
    }
}

walker Heal {
    has amount: int,
        cap: int = 0,
        restored: int = 0;

    can apply with Actor entry {
        if self.amount <= 0 or here.health <= 0 {
            return;
        }
        limit = here.max_health if self.cap <= 0 else self.cap;
        self.restored = min(self.amount, max(0, limit - here.health));
        here.health += self.restored;
    }
}


def blast_strength(
    game: str, amount: int, radius: float, distance: float, energy_burst: bool = False
) -> float {
    if amount <= 0 or radius <= 0.0 or distance >= radius {
        return 0.0;
    }
    distance = max(0.0, distance);
    if energy_burst {
        return float(amount) * (1.0 - math.sqrt(distance / radius));
    }
    if game == "q3" {
        return float(amount) * (1.0 - distance / radius);
    }
    return max(0.0, float(amount) - distance * 0.5);
}
