"""Shared item contacts, inventory effects and arena respawn behavior."""
import from .world { World, Entity, Player }
import from .models { Visual }
import from .damage { Heal }
import from .inventory { AdjustInventory }
import from ..math.vec3 { Vec3 }

obj PickupRule {
    has kind: str,
        amount: int,
        capacity: int,
        model: str,
        skin: int = 0,
        armor_mode: str = "replace",
        armor_ratio: float = 0.0;
}

edge HasPickup {}
node Pickup(Entity) {
    has rule: PickupRule,
        visual: Visual = Visual(),
        active: bool = True,
        respawn: float = 0.0,
        remaining: float = 0.0;
}

# Segment against an item box expanded by the player body; preserves fast crossings.
def pickup_contact(start: Vec3, finish: Vec3, origin: Vec3, top_drop: float) -> bool {
    low = origin.sub(Vec3(x=32.0, y=32.0, z=48.0 - top_drop));
    high = origin.add(Vec3(x=32.0, y=32.0, z=40.0));
    a = [start.x, start.y, start.z];
    b = [finish.x, finish.y, finish.z];
    mins = [low.x, low.y, low.z];
    maxs = [high.x, high.y, high.z];
    enter = 0.0;
    leave = 1.0;
    for axis in range(3) {
        delta = b[axis] - a[axis];
        if abs(delta) < 0.000001 {
            if a[axis] < mins[axis] or a[axis] > maxs[axis] {
                return False;
            }
        } else {
            first = (mins[axis] - a[axis]) / delta;
            second = (maxs[axis] - a[axis]) / delta;
            enter = max(enter, min(first, second));
            leave = min(leave, max(first, second));
            if enter > leave {
                return False;
            }
        }
    }
    return True;
}

walker PickupTick {
    has player: Player,
        start: Vec3,
        finish: Vec3,
        dt: float,
        top_drop: float = 0.0,
        touching: bool = True,
        collected: int = 0;

    can begin with World entry {
        if self.dt > 0.0 {
            visit [here->:HasPickup:->];
        }
    }

    can collect with Pickup entry {
        if not here.active {
            if here.respawn <= 0.0 {
                return;
            }
            here.remaining = max(0.0, here.remaining - self.dt);
            if here.remaining > 0.0 {
                return;
            }
            here.active = True;
            here.visual.visible = True;
        }
        if not self.touching
            or self.player.health <= 0
            or not pickup_contact(self.start, self.finish, here.pos, self.top_drop) {
            return;
        }
        accepted = 0;
        rule = here.rule;
        if rule.kind == "health" {
            heal = self.player spawn Heal(amount=rule.amount, cap=rule.capacity);
            accepted = heal.restored;
        } elif rule.kind == "armor" {
            old = self.player.armor;
            if rule.armor_mode == "add" {
                self.player.armor = min(rule.capacity, old + rule.amount);
                self.player.armor_capacity = rule.capacity;
                self.player.armor_ratio = rule.armor_ratio;
                accepted = self.player.armor - old;
            } elif rule.armor_mode == "salvage" {
                if old == 0 or rule.armor_ratio > self.player.armor_ratio {
                    salvage = int(
                        float(old) * self.player.armor_ratio / rule.armor_ratio
                    );
                    self.player.armor = min(rule.capacity, rule.amount + salvage);
                    self.player.armor_capacity = rule.capacity;
                    self.player.armor_ratio = rule.armor_ratio;
                    accepted = 1;
                } elif self.player.armor_ratio > 0.0 {
                    salvage = int(
                        float(rule.amount) * rule.armor_ratio / self.player.armor_ratio
                    );
                    self.player.armor = min(self.player.armor_capacity, old + salvage);
                    accepted = self.player.armor - old;
                }
            } elif rule.amount * rule.armor_ratio
                > self.player.armor * self.player.armor_ratio {
                self.player.armor = rule.amount;
                self.player.armor_capacity = rule.capacity;
                self.player.armor_ratio = rule.armor_ratio;
                accepted = 1;
            }
        } else {
            change = self.player.inventory spawn AdjustInventory(
                kind=rule.kind, amount=rule.amount, capacity=rule.capacity
            );
            accepted = change.accepted;
        }
        if accepted > 0 {
            here.active = False;
            here.remaining = here.respawn;
            here.visual.visible = False;
            self.collected += 1;
        }
    }
}
