"""Shared health and armor mutations, independent of input and rendering."""
import math;
import from .world { Actor }

walker Damage {
    has amount: int,
        bypass_armor: bool = False,
        dealt: int = 0,
        absorbed: int = 0,
        killed: bool = False;

    can apply with Actor entry {
        if self.amount <= 0 or here.health <= 0 {
            return;
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
        here.health -= self.dealt;
        self.killed = here.health == 0;
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
