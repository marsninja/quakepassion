"""Shared item contacts, inventory effects and arena respawn behavior."""
import from .world { World, Entity, Player }
import from .signals { Signal, HasSignal, Fire }
import from ..formats.bsp { Bsp }
import from .models { Visual }
import from .damage { Heal }
import from .inventory { Inventory, AdjustInventory, InventorySlot, ItemStack, quantity }
import from .powerups { GrantPowerup, Powerup, Empowered, effect, stored_kinds }
import from ..math.vec3 { Vec3 }

obj PickupRule {
    has kind: str,
        amount: int,
        capacity: int,
        model: str,
        ammo: str = "",
        ammo_amount: int = 0,
        ammo_capacity: int = 0,
        skin: int = 0,
        bitmask: int = 0,
        armor_mode: str = "replace",
        armor_ratio: float = 0.0,
        powerup: str = "",
        duration: float = 0.0,
        additive: bool = False,
        rot: bool = False,
        max_health_bonus: int = 0,
        capacities: dict[str, int] = {},
        grants: dict[str, int] = {},
        sound: str = "",
        label: str = "",
        extra_model: str = "";
}

# Raise an ammunition limit without granting ammunition (Q2 bandolier/pack).
walker RaiseCapacity {
    has kind: str, capacity: int;

    can begin with Inventory entry {
        slots = [
            slot
            for slot in [here->:InventorySlot:->][?:ItemStack]
            if slot.kind == self.kind
        ];
        if not slots {
            slot = ItemStack(kind=self.kind, capacity=self.capacity);
            here +>:InventorySlot:+> slot;
            return;
        }
        for slot in slots {
            slot.capacity = max(slot.capacity, self.capacity);
        }
    }
}

edge HasPickup: World --> Pickup {}
node Pickup(Entity) {
    has rule: PickupRule,
        visual: Visual = Visual(),
        active: bool = True,
        waiting_for_use: bool = False,
        activate_on_use: bool = False,
        reusable_use: bool = False,
        activation: Signal = Signal(),
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
        advance_time: bool = True,
        kinds: list[str] = [],
        targets: list[Pickup] = [],
        selected_only: bool = False,
        forced: bool = False,
        sounds: list[str] = [],
        messages: list[str] = [],
        collected: int = 0;

    can begin with World entry {
        if self.dt > 0.0 {
            if self.selected_only { visit self.targets; }
            else { visit [here->:HasPickup:->]; }
        }
    }

    can collect with Pickup entry {
        if self.kinds and here.rule.kind not in self.kinds { return; }
        if here.activation.killed {
            here.active = False;
            here.waiting_for_use = True;
            here.visual.visible = False;
            return;
        }
        if here.activation.pending > 0 {
            here.activation.pending = 0;
            if here.activate_on_use {
                here.active = True;
                here.waiting_for_use = False;
                here.visual.visible = True;
                here.remaining = 0.0;
                here.activate_on_use = here.reusable_use;
            }
        }
        # Q3 target_give hands items over directly, without placing them.
        if here.waiting_for_use and not self.forced {
            return;
        }
        if not here.active and not self.forced {
            if not self.advance_time { return; }
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
        if not self.forced
            and (
                not self.touching
                    or self.player.health <= 0
                    or not pickup_contact(self.start, self.finish, here.pos, self.top_drop)
            ) {
            return;
        }
        accepted = 0;
        rule = here.rule;
        if rule.kind == "powerup" {
            grant = self.player spawn GrantPowerup(
                kind=rule.powerup, duration=rule.duration, additive=rule.additive
            );
            accepted = 1 if grant.granted is not None else 0;
        } elif rule.kind.startswith("holdable_") {
            # Q3 carries one holdable item at a time.
            if not any(
                [quantity(self.player.inventory, kind) > 0 for kind in stored_kinds("q3")]
            ) {
                change = self.player.inventory spawn AdjustInventory(
                    kind=rule.kind, amount=1, capacity=1
                );
                accepted = change.accepted;
            }
        } elif rule.max_health_bonus > 0 {
            # Q2 adrenaline also heals to the new maximum; the ancient head does not.
            self.player.max_health += rule.max_health_bonus;
            if rule.kind == "adrenaline" and self.player.health < self.player.max_health {
                self.player.health = self.player.max_health;
            }
            accepted = 1;
        } elif rule.capacities or rule.grants {
            for kind in rule.capacities {
                self.player.inventory spawn RaiseCapacity(
                    kind=kind, capacity=rule.capacities[kind]
                );
            }
            for kind in rule.grants {
                self.player.inventory spawn AdjustInventory(
                    kind=kind,
                    amount=rule.grants[kind],
                    capacity=rule.capacities.get(kind, 200)
                );
            }
            accepted = 1;
        } elif rule.bitmask > 0 {
            old = quantity(self.player.inventory, rule.kind);
            self.player.inventory spawn AdjustInventory(
                kind=rule.kind,
                amount=(old | rule.bitmask) - old,
                capacity=rule.capacity
            );
            accepted = 1;
        } elif rule.kind == "health" {
            # Q3 Pickup_Health caps at the handicapped maximum (or twice it).
            cap = rule.capacity
                if self.player.max_health >= 100
                else rule.capacity * self.player.max_health // 100;
            heal = self.player spawn Heal(amount=rule.amount, cap=cap);
            accepted = heal.restored;
            if rule.rot and heal.restored > 0 {
                rot = effect(self.player, "megahealth");
                if rot is None {
                    rot = Powerup(kind="megahealth", remaining=-1.0);
                    self.player +>:Empowered:+> rot;
                }
                rot.clock = -4.0;
            }
        } elif rule.kind == "armor" {
            old = self.player.armor;
            if rule.armor_mode == "shard" {
                self.player.armor = min(rule.capacity, old + rule.amount)
                    if rule.capacity > 0
                    else old + rule.amount;
                if self.player.armor_ratio <= 0.0 {
                    self.player.armor_ratio = rule.armor_ratio;
                    self.player.armor_capacity = max(
                        self.player.armor_capacity, rule.amount
                    );
                }
                accepted = self.player.armor - old;
            } elif rule.armor_mode == "add" {
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
            if rule.ammo and rule.ammo_amount > 0 {
                ammo = self.player.inventory spawn AdjustInventory(
                    kind=rule.ammo, amount=rule.ammo_amount, capacity=rule.ammo_capacity
                );
                accepted += ammo.accepted;
            }
        }
        if accepted > 0 {
            here.active = False;
            here.remaining = here.respawn;
            here.visual.visible = False;
            self.collected += 1;
            if rule.sound {
                self.sounds.append(rule.sound);
            }
            if rule.label {
                self.messages.append("You got the " + rule.label);
            }
            here.activation spawn Fire(inventory=self.player.inventory);
        }
    }
}


def load_pickup_signals(world: World, bsp: Bsp) {
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        kind = fields.get("classname", "");
        # target_spawner (Q2) creates its item or monster when used.
        if kind.startswith("item_")
            or kind.startswith("key_")
            or kind.startswith("ammo_")
            or kind.startswith("weapon_")
            or (bsp.game == "q2" and kind == "target_spawner") {
            world +>:HasSignal:+> Signal(entities=[index]);
        }
    }
}
