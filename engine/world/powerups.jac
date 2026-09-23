"""Timed powerups and lasting actor effects, attached to actors as graph nodes.

Each active effect is a `Powerup` node hanging off its actor through an
`Empowered` edge. Walkers grant, advance, use and query those nodes; damage,
movement, weapons and AI consult them rather than keeping parallel flags."""
import from .world { Actor }
import from .inventory { Inventory, InventorySlot, ItemStack, AdjustInventory, quantity }
import from ..math.vec3 { Vec3, forward_from }

edge Empowered: Actor --> Powerup {}
node Powerup {
    has kind: str,
        remaining: float = 0.0,
        clock: float = 0.0,
        count: int = 0;
}

obj PowerupRule {
    has kind: str,
        name: str,
        duration: float = 30.0,
        additive: bool = False,
        pickup_sound: str = "",
        warning_sound: str = "",
        warning_message: str = "",
        tint: list[int] = [];
}

# Durations, cues and screen blends follow each game's original client code:
# Q1 items.qc/client.qc/view.c, Q2 g_items.c/p_view.c, Q3 bg_misc.c/cg_view.c.
def powerup_rules(game: str) -> list[PowerupRule] {
    if game == "q1" {
        return [
            PowerupRule(
                kind="quad",
                name="Quad Damage",
                pickup_sound="sound/items/damage.wav",
                warning_sound="sound/items/damage2.wav",
                warning_message="Quad Damage is wearing off",
                tint=[0, 0, 255, 30]
            ),
            PowerupRule(
                kind="invulnerability",
                name="Pentagram of Protection",
                pickup_sound="sound/items/protect.wav",
                warning_sound="sound/items/protect2.wav",
                warning_message="Protection is almost burned out",
                tint=[255, 255, 0, 30]
            ),
            PowerupRule(
                kind="invisibility",
                name="Ring of Shadows",
                pickup_sound="sound/items/inv1.wav",
                warning_sound="sound/items/inv2.wav",
                warning_message="Ring of Shadows magic is fading",
                tint=[100, 100, 100, 100]
            ),
            PowerupRule(
                kind="suit",
                name="Biosuit",
                pickup_sound="sound/items/suit.wav",
                warning_sound="sound/items/suit2.wav",
                warning_message="Air supply in Biosuit expiring",
                tint=[0, 255, 0, 20]
            )
        ];
    }
    if game == "q2" {
        return [
            PowerupRule(
                kind="quad",
                name="Quad Damage",
                additive=True,
                pickup_sound="sound/items/damage.wav",
                warning_sound="sound/items/damage2.wav",
                tint=[0, 0, 255, 20]
            ),
            PowerupRule(
                kind="invulnerability",
                name="Invulnerability",
                additive=True,
                pickup_sound="sound/items/protect.wav",
                warning_sound="sound/items/protect2.wav",
                tint=[255, 255, 0, 20]
            ),
            PowerupRule(
                kind="breather",
                name="Rebreather",
                additive=True,
                pickup_sound="sound/items/damage.wav",
                warning_sound="sound/items/airout.wav",
                tint=[102, 255, 102, 10]
            ),
            PowerupRule(
                kind="suit",
                name="Environment Suit",
                additive=True,
                pickup_sound="sound/items/damage.wav",
                warning_sound="sound/items/airout.wav",
                tint=[0, 255, 0, 20]
            ),
            PowerupRule(
                kind="silencer", name="Silencer", duration=0.0, additive=True
            )
        ];
    }
    if game == "q3" {
        return [
            PowerupRule(
                kind="quad",
                name="Quad Damage",
                additive=True,
                pickup_sound="sound/items/quaddamage.wav",
                warning_sound="sound/items/wearoff.wav"
            ),
            PowerupRule(
                kind="battlesuit",
                name="Battle Suit",
                additive=True,
                pickup_sound="sound/items/protect.wav",
                warning_sound="sound/items/wearoff.wav"
            ),
            PowerupRule(
                kind="haste",
                name="Speed",
                additive=True,
                pickup_sound="sound/items/haste.wav",
                warning_sound="sound/items/wearoff.wav"
            ),
            PowerupRule(
                kind="invisibility",
                name="Invisibility",
                additive=True,
                pickup_sound="sound/items/invisibility.wav",
                warning_sound="sound/items/wearoff.wav"
            ),
            PowerupRule(
                kind="regen",
                name="Regeneration",
                additive=True,
                pickup_sound="sound/items/regeneration.wav",
                warning_sound="sound/items/wearoff.wav"
            ),
            PowerupRule(
                kind="flight",
                name="Flight",
                duration=60.0,
                additive=True,
                pickup_sound="sound/items/flight.wav",
                warning_sound="sound/items/wearoff.wav"
            )
        ];
    }
    return [];
}

def powerup_rule(game: str, kind: str) -> PowerupRule | None {
    for rule in powerup_rules(game) {
        if rule.kind == kind {
            return rule;
        }
    }
    return None;
}

# Q1/Q2 warn once three seconds before expiry; Q3 ticks each of the last five.
def warning_marks(game: str) -> list[float] {
    return [5.0, 4.0, 3.0, 2.0, 1.0] if game == "q3" else [3.0];
}

def protection_sound(game: str, kind: str) -> str {
    if kind == "invulnerability" {
        return "sound/items/protect4.wav" if game == "q2" else "sound/items/protect3.wav";
    }
    if kind == "battlesuit" {
        return "sound/items/protect3.wav";
    }
    return "";
}

def effect(actor: Actor, kind: str) -> Powerup | None {
    for power in [actor->:Empowered:->][?:Powerup] {
        if power.kind == kind {
            return power;
        }
    }
    return None;
}

def powerup_left(actor: Actor, kind: str) -> float {
    power = effect(actor, kind);
    return power.remaining if power is not None and power.remaining > 0.0 else 0.0;
}

def empowered(actor: Actor, kind: str) -> bool {
    return powerup_left(actor, kind) > 0.0;
}

def damage_scale(actor: Actor, game: str) -> float {
    if not empowered(actor, "quad") {
        return 1.0;
    }
    return 3.0 if game == "q3" else 4.0;
}

def fire_interval_scale(actor: Actor) -> float {
    return 1.0 / 1.3 if empowered(actor, "haste") else 1.0;
}

def speed_scale(actor: Actor) -> float {
    return 1.3 if empowered(actor, "haste") else 1.0;
}

walker GrantPowerup {
    has kind: str,
        duration: float,
        additive: bool = False,
        granted: Powerup | None = None;

    can grant with Actor entry {
        if self.duration <= 0.0 {
            return;
        }
        power = effect(here, self.kind);
        if power is None {
            power = Powerup(kind=self.kind);
            here +>:Empowered:+> power;
        }
        if self.additive and power.remaining > 0.0 {
            power.remaining += self.duration;
        } else {
            power.remaining = max(power.remaining, self.duration);
        }
        self.granted = power;
    }
}

"""Advance an actor's effects on the fixed simulation clock.

Timers count down, expiry cues fire at the original marks, and the lasting
health rules (Q1/Q2 megahealth rot, Q3 regeneration and overcharge decay) run
from their own one-second clocks."""
walker PowerupTick {
    has game: str,
        dt: float,
        cues: list[str] = [],
        messages: list[str] = [],
        healed: int = 0,
        expired: list[str] = [],
        actor: Actor | None = None;

    can begin with Actor entry {
        if self.dt <= 0.0 {
            return;
        }
        self.actor = here;
        if here.health <= 0 {
            for power in [here->:Empowered:->][?:Powerup] {
                here del --> power;
            }
            return;
        }
        if self.game == "q3" and effect(here, "vitality") is None {
            here +>:Empowered:+> Powerup(kind="vitality", remaining=-1.0);
        }
        visit [here->:Empowered:->];
    }

    can advance with Powerup entry {
        actor = self.actor;
        if actor is None {
            return;
        }
        if here.kind == "megahealth" {
            # Rot starts five seconds after pickup, then drains one point a second.
            if actor.health <= actor.max_health {
                actor del --> here;
                return;
            }
            here.clock += self.dt;
            while here.clock >= 1.0 and actor.health > actor.max_health {
                here.clock -= 1.0;
                actor.health -= 1;
            }
            if actor.health <= actor.max_health {
                actor del --> here;
            }
            return;
        }
        if here.kind == "vitality" {
            here.clock += self.dt;
            while here.clock >= 1.0 {
                here.clock -= 1.0;
                self.vitality_second(actor);
            }
            return;
        }
        if here.kind in ["power_screen", "power_shield"] {
            return;
        }
        if here.kind == "silencer" {
            if here.count <= 0 {
                actor del --> here;
            }
            return;
        }
        # Protected hits sound at most once a second (Q1 every two seconds).
        here.clock = max(0.0, here.clock - self.dt);
        if here.count > 0 and here.clock <= 0.0 {
            sound = protection_sound(self.game, here.kind);
            if sound {
                self.cues.append(sound);
                here.clock = 2.0 if self.game == "q1" else 1.0;
            }
        }
        here.count = 0;
        before = here.remaining;
        here.remaining = max(0.0, here.remaining - self.dt);
        rule = powerup_rule(self.game, here.kind);
        if rule is not None and rule.warning_sound {
            for mark in warning_marks(self.game) {
                if before > mark and here.remaining <= mark {
                    self.cues.append(rule.warning_sound);
                    if rule.warning_message {
                        self.messages.append(rule.warning_message);
                    }
                }
            }
        }
        if here.remaining <= 0.0 {
            self.expired.append(here.kind);
            actor del --> here;
        }
    }

    # Q3 ClientTimerActions: regeneration, otherwise health/armor overcharge decay.
    def vitality_second(actor: Actor) {
        if empowered(actor, "regen") {
            before = actor.health;
            if actor.health < actor.max_health {
                actor.health = min(
                    actor.health + 15, int(float(actor.max_health) * 1.1)
                );
            } elif actor.health < actor.max_health * 2 {
                actor.health = min(actor.health + 5, actor.max_health * 2);
            }
            if actor.health > before {
                self.healed += actor.health - before;
                self.cues.append("sound/items/regen.wav");
            }
        } elif actor.health > actor.max_health {
            actor.health -= 1;
        }
        if actor.armor > actor.max_health {
            actor.armor -= 1;
        }
    }
}

"""Q2 stored powerups and Q3 holdables live in the ordinary inventory until used."""
def stored_kinds(game: str) -> list[str] {
    if game == "q2" {
        return [
            "powerup_quad",
            "powerup_invulnerability",
            "powerup_breather",
            "powerup_suit",
            "powerup_silencer",
            "power_screen",
            "power_shield"
        ];
    }
    if game == "q3" {
        return ["holdable_medkit", "holdable_teleporter"];
    }
    return [];
}

def item_label(kind: str) -> str {
    return {
        "powerup_quad": "Quad Damage",
        "powerup_invulnerability": "Invulnerability",
        "powerup_breather": "Rebreather",
        "powerup_suit": "Environment Suit",
        "powerup_silencer": "Silencer",
        "power_screen": "Power Screen",
        "power_shield": "Power Shield",
        "holdable_medkit": "Medkit",
        "holdable_teleporter": "Personal Teleporter"
    }.get(kind, kind);
}

def owned_items(inventory: Inventory, game: str) -> list[str] {
    return [kind for kind in stored_kinds(game) if quantity(inventory, kind) > 0];
}

"""Activate one stored item. `teleport` is filled for the caller to place the
actor, because choosing a destination needs the level's spawn points."""
walker UseItem {
    has game: str,
        kind: str,
        used: bool = False,
        cue: str = "",
        message: str = "",
        teleport: bool = False;

    can apply with Actor entry {
        if here.health <= 0 or quantity(here.inventory, self.kind) <= 0 {
            return;
        }
        if self.kind in ["power_screen", "power_shield"] {
            active = effect(here, self.kind);
            if active is not None {
                here del --> active;
                self.message = item_label(self.kind) + " off";
                self.cue = "sound/misc/power2.wav";
            } else {
                if quantity(here.inventory, "cells") <= 0 {
                    self.message = "No cells for " + item_label(self.kind);
                    return;
                }
                for other in ["power_screen", "power_shield"] {
                    existing = effect(here, other);
                    if existing is not None {
                        here del --> existing;
                    }
                }
                here +>:Empowered:+> Powerup(kind=self.kind, remaining=-1.0);
                self.message = item_label(self.kind) + " on";
                self.cue = "sound/misc/power1.wav";
            }
            self.used = True;
            return;
        }
        if self.kind == "holdable_medkit" {
            here.health = here.max_health + 25;
            self.cue = "sound/items/use_medkit.wav";
        } elif self.kind == "holdable_teleporter" {
            self.teleport = True;
        } elif self.kind == "powerup_silencer" {
            power = effect(here, "silencer");
            if power is None {
                power = Powerup(kind="silencer", remaining=-1.0);
                here +>:Empowered:+> power;
            }
            power.count += 30;
        } else {
            kind = self.kind[len("powerup_"):];
            rule = powerup_rule(self.game, kind);
            if rule is None {
                return;
            }
            here spawn GrantPowerup(
                kind=kind, duration=rule.duration, additive=rule.additive
            );
            self.cue = rule.pickup_sound;
        }
        here.inventory spawn AdjustInventory(kind=self.kind, amount=-1);
        self.used = True;
    }
}

"""Q2 power armor (g_combat.c CheckPowerArmor): cells absorb part of each hit.

The screen only covers attacks from the front; the shield covers every side at
twice the cell cost. Returns the damage saved and spends the matching cells."""
def power_armor_save(actor: Actor, amount: int, source: Vec3 | None) -> int {
    screen = effect(actor, "power_screen");
    shield = effect(actor, "power_shield");
    if (screen is None and shield is None) or amount <= 0 {
        return 0;
    }
    cells = quantity(actor.inventory, "cells");
    if cells <= 0 {
        return 0;
    }
    per_cell = 2;
    limit = (2 * amount) // 3;
    if screen is not None {
        if source is None {
            return 0;
        }
        toward = source.sub(actor.pos);
        toward.z = 0.0;
        if toward.length() < 0.001
            or toward.normalized().dot(forward_from(actor.yaw, 0.0)) <= 0.3 {
            return 0;
        }
        per_cell = 1;
        limit = amount // 3;
    }
    save = min(cells * per_cell, limit);
    if save <= 0 {
        return 0;
    }
    used = max(1, save // per_cell);
    actor.inventory spawn AdjustInventory(kind="cells", amount=-used);
    return save;
}
