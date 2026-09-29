"""Shared item contacts, inventory effects and arena respawn behavior."""
import from .world { World, Entity, Player, In }
import from .signals { Signal, HasSignal, Fire }
import from ..formats.bsp { Bsp }
import from .models { Visual }
import from .damage { Heal }
import from .inventory { Inventory, AdjustInventory, InventorySlot, ItemStack, quantity }
import from .powerups { GrantPowerup, Powerup, Empowered, effect, stored_kinds }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

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
        extra_model: str = "",
        message: str = "",
        icon: str = "",
        topup: bool = False,
        respawn_sound: str = "",
        classname: str = "";
    # The low corner of a Q1 item's box about its origin (items.qc setsize:
    # health and ammo '0 0 0', armor and weapons '-16 -16 0', keys, sigils
    # and artifacts '-16 -16 -24'); every one is the player hull's size. Q2
    # and Q3 items are 15 each way about their origin.
    has mins: Vec3 = Vec3();
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
"""An item. Q3 items may belong to a team, of which one member is present at a
time (`benched` marks the rest); `jitter` is Q3's `random` respawn spread;
`dropped` items were thrown by a dying player and vanish after `lifetime`."""
node Pickup(Entity) {
    has rule: PickupRule,
        visual: Visual = Visual(),
        active: bool = True,
        waiting_for_use: bool = False,
        activate_on_use: bool = False,
        reusable_use: bool = False,
        activation: Signal = Signal(),
        respawn: float = 0.0,
        remaining: float = 0.0,
        benched: bool = False,
        jitter: float = 0.0,
        seed: int = 1,
        dropped: bool = False,
        released: bool = False,
        lifetime: float = 0.0,
        duration: float = -1.0;
}

"""g_main.c G_FindTeams for items: every item with the same `team` key is in
one chain, and g_items.c RespawnItem brings back a random member of it."""
node ItemTeam {
    has name: str = "",
        seed: int = 1;

    """A random member (rand() % count)."""
    def pick(members: list[Pickup]) -> Pickup | None {
        if not members {
            return None;
        }
        self.seed = (self.seed * 48271) % 2147483647;
        return members[self.seed % len(members)];
    }
}

edge TeamMember: ItemTeam --> Pickup {}
edge InTeam: Pickup --> ItemTeam {}

"""The respawn wait after a pickup: g_items.c adds crandom() * random, at
least a second."""
def respawn_wait(item: Pickup) -> float {
    if item.jitter <= 0.0 {
        return item.respawn;
    }
    item.seed = (item.seed * 48271) % 2147483647;
    spread = (float(item.seed) / 2147483647.0 * 2.0 - 1.0) * item.jitter;
    return max(1.0, item.respawn + spread);
}

"""The view that traces an item's own box. Q1 items.qc gives every item
setsize('0 0 0', '32 32 56'), the player hull's size with its origin at the
box's low corner; Q2 droptofloor and Q3 ITEM_RADIUS make it 15 each way."""
def item_view(collision: CollisionMap, game: str) -> CollisionMap {
    if game == "q1" {
        return collision.for_body(0.0);
    }
    return collision.for_body(
        0.0, 0.0, Vec3(x=-15.0, y=-15.0, z=-15.0), Vec3(x=15.0, y=15.0, z=15.0)
    );
}

"""An item's position less the origin of the box its view traces. A Q1
item is traced in the player hull (SV_HullForEntity), whose origin sits at
the item's origin plus the hull's reach below it past its own low corner;
Q2 and Q3 boxes are centred."""
def item_lift(game: str, rule: PickupRule) -> Vec3 {
    if game == "q1" {
        return Vec3(x=-16.0 - rule.mins.x, y=-16.0 - rule.mins.y, z=-24.0 - rule.mins.z);
    }
    return Vec3();
}

"""Where a newly spawned item ends up."""
obj Landing {
    has kept: bool = True,
        falls: bool = False;
}

"""Put a newly spawned item down as its game does. Q1 PlaceItem lifts it 6
units and droptofloor traces its box 256 down (SV_Move, which carries a box
starting partly in solid on out of it to the floor below); an item that
finds no floor there, or never gets out of the solid, fell out of the level
and goes. Q2 droptofloor traces 128 down and leaves the item wherever that
ends, to fall on from there (MOVETYPE_TOSS); one starting in solid goes. Q3
FinishSpawningItem traces 4096 down unless the item is SUSPENDED; starting
in solid, it goes."""
def drop_to_floor(item: Pickup, view: CollisionMap, game: str, suspended: bool) -> Landing {
    lift = item_lift(game, item.rule);
    if game == "q1" {
        item.pos = item.pos.add(Vec3(z=6.0));
    }
    if game == "q3" and suspended {
        return Landing();
    }
    reach = 256.0 if game == "q1" else (128.0 if game == "q2" else 4096.0);
    origin = item.pos.sub(lift);
    bottom = origin.sub(Vec3(z=reach));
    if game == "q1" {
        # PF_droptofloor: fraction 1 or allsolid fails; else the end.
        fall = view.trace(origin, bottom, escape=True);
        if fall.fraction >= 1.0 or fall.all_solid {
            return Landing(kept=False);
        }
        item.pos = fall.end.add(lift);
        return Landing();
    }
    trace = view.trace(origin, bottom);
    if trace.start_solid {
        return Landing(kept=False);
    }
    item.pos = trace.end.add(lift);
    return Landing(falls=game == "q2" and trace.fraction >= 1.0);
}

"""Take a dropped item out of the world."""
def remove_pickup(world: World, item: Pickup) {
    item.active = False;
    item.visual.visible = False;
    world del ->:HasPickup:-> item;
    for link in [edge item->:In:->] {
        del link;
    }
    world.item_serial += 1;
}

"""Where a player's origin can be, less an item's origin, for the player to
touch the item, by game (the player's box is `body_mins`..`body_maxs`):
- Q1 SV_TouchLinks: the player's box, a unit bigger all round (SV_LinkEdict),
  meets the item's (items.qc setsize from `mins`, 32 by 32 by 56), which
  FL_ITEM widens by 15 each way across so items come off shelves.
- Q2 G_TouchTriggers: both boxes, each a unit bigger all round, meet; the
  item's reaches 15 each way (droptofloor).
- Q3 G_TouchTriggers' BG_PlayerTouchesItem: the origins are within 44
  ahead and 50 behind across x, 36 either way across y and z, ducked or not.
Passion items touch as Q2's do."""
def touch_reach(game: str, rule: PickupRule, body_mins: Vec3, body_maxs: Vec3) -> AABB {
    if game == "q3" {
        return AABB(mins=Vec3(x=-50.0, y=-36.0, z=-36.0), maxs=Vec3(x=44.0, y=36.0, z=36.0));
    }
    low = Vec3(x=-16.0, y=-16.0, z=-16.0);
    high = Vec3(x=16.0, y=16.0, z=16.0);
    if game == "q1" {
        low = rule.mins.sub(Vec3(x=15.0, y=15.0));
        high = rule.mins.add(Vec3(x=47.0, y=47.0, z=56.0));
    }
    pad = Vec3(x=1.0, y=1.0, z=1.0);
    return AABB(mins=low.sub(body_maxs).sub(pad), maxs=high.sub(body_mins).add(pad));
}

"""Whether a player's origin moving from `start` to `finish` passes through
`reach` (a touch_reach placed at the item); a fast crossing still counts."""
def pickup_contact(start: Vec3, finish: Vec3, reach: AABB) -> bool {
    a = [start.x, start.y, start.z];
    b = [finish.x, finish.y, finish.z];
    mins = [reach.mins.x, reach.mins.y, reach.mins.z];
    maxs = [reach.maxs.x, reach.maxs.y, reach.maxs.z];
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

"""Items touched, taken, respawned and timed out this tick. `start` and
`finish` are the player's origin (its box's) before and after its move;
`body_mins`/`body_maxs` its standing box, `top_drop` lower when crouched."""
walker PickupTick {
    has player: Player,
        start: Vec3,
        finish: Vec3,
        dt: float,
        game: str = "",
        body_mins: Vec3 = Vec3(x=-16.0, y=-16.0, z=-24.0),
        body_maxs: Vec3 = Vec3(x=16.0, y=16.0, z=32.0),
        top_drop: float = 0.0,
        touching: bool = True,
        advance_time: bool = True,
        kinds: list[str] = [],
        targets: list[Pickup] = [],
        selected_only: bool = False,
        forced: bool = False,
        sounds: list[str] = [],
        messages: list[str] = [],
        picked: list[PickupRule] = [],
        weapons: list[str] = [],
        fresh_weapons: list[str] = [],
        collected: int = 0,
        world: World | None = None;

    """Whether the player's move touches the item, in its game's way."""
    def touches(item: Pickup) -> bool {
        reach = touch_reach(
            self.game, item.rule, self.body_mins, self.body_maxs.sub(Vec3(z=self.top_drop))
        );
        return pickup_contact(
            self.start,
            self.finish,
            AABB(mins=item.pos.add(reach.mins), maxs=item.pos.add(reach.maxs))
        );
    }

    can begin with World entry {
        self.world = here;
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
        # LaunchItem: dropped items are freed after thirty seconds.
        if here.dropped and self.advance_time {
            here.lifetime -= self.dt;
            world = self.world;
            if here.lifetime <= 0.0 and world is not None {
                remove_pickup(world, here);
                return;
            }
        }
        if not here.active and not self.forced {
            if not self.advance_time or here.benched { return; }
            if here.respawn <= 0.0 {
                return;
            }
            here.remaining = max(0.0, here.remaining - self.dt);
            if here.remaining > 0.0 {
                return;
            }
            # RespawnItem: a team brings back one member at random.
            teams = [here->:InTeam:->][?:ItemTeam];
            if teams {
                chosen = teams[0].pick([teams[0]->:TeamMember:->][?:Pickup]);
                if chosen is not None and chosen is not here {
                    here.benched = True;
                    chosen.benched = False;
                    chosen.active = True;
                    chosen.remaining = 0.0;
                    chosen.visual.visible = True;
                    return;
                }
            }
            here.active = True;
            here.visual.visible = True;
            # g_items.c RespawnItem: EV_ITEM_RESPAWN, poweruprespawn for powerups.
            if here.rule.respawn_sound {
                self.sounds.append(here.rule.respawn_sound);
            }
        }
        if not self.forced
            and (
                not self.touching
                    or self.player.health <= 0
                    or not self.touches(here)
            ) {
            return;
        }
        accepted = 0;
        rule = here.rule;
        if rule.kind == "powerup" {
            # A dropped powerup keeps the time its carrier had left.
            grant = self.player spawn GrantPowerup(
                kind=rule.powerup,
                duration=here.duration if here.duration > 0.0 else rule.duration,
                additive=rule.additive
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
            owned = quantity(self.player.inventory, rule.kind);
            change = self.player.inventory spawn AdjustInventory(
                kind=rule.kind, amount=rule.amount, capacity=rule.capacity
            );
            accepted = change.accepted;
            if rule.ammo and rule.ammo_amount > 0 {
                amount = rule.ammo_amount;
                if rule.topup {
                    # Q3 Pickup_Weapon: top up to the pickup's count, or one
                    # shot when already above it; the weapon is always taken.
                    amount = max(1, rule.ammo_amount - quantity(self.player.inventory, rule.ammo));
                    accepted = 1;
                }
                ammo = self.player.inventory spawn AdjustInventory(
                    kind=rule.ammo, amount=amount, capacity=rule.ammo_capacity
                );
                accepted += ammo.accepted;
            }
            if accepted > 0 and rule.kind.startswith("weapon_") {
                self.weapons.append(rule.kind[7:]);
                if owned == 0 {
                    self.fresh_weapons.append(rule.kind[7:]);
                }
            }
        }
        if accepted > 0 {
            here.active = False;
            here.remaining = respawn_wait(here);
            here.visual.visible = False;
            world = self.world;
            if here.dropped and world is not None {
                remove_pickup(world, here);
            }
            self.collected += 1;
            if rule.sound {
                self.sounds.append(rule.sound);
            }
            if rule.message {
                self.messages.append(rule.message);
            } elif rule.label {
                self.messages.append("You got the " + rule.label);
            }
            self.picked.append(rule);
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
