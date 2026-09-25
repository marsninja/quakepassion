"""g_combat.c TossClientItems: a Q3 player who dies throws down the weapon it
held (never the gauntlet or machine gun, and only with ammo left) and every
powerup it carried, with the time that was left on it. Dropped items do not
respawn and are gone after thirty seconds (LaunchItem). Each is thrown from
the body (Drop_Item) and flies under gravity until it lands (G_RunItem)."""
import math;
import from .world { World, Player, Area, In, move_to_area }
import from .models { ModelResource, UsesModel, attach_model }
import from .pickups { Pickup, PickupRule, HasPickup }
import from .powerups { Empowered, Powerup }
import from .inventory { quantity }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

"""An item a dying player can drop: the rule it gives and how it is drawn
(its models by `DropsAs` edge, the first the main one)."""
node ItemDrop {
    has kind: str = "",
        rule: PickupRule = PickupRule(kind="", amount=0, capacity=0, model=""),
        spin: float = 0.0,
        bob: float = 0.0;
}

edge HasItemDrop: World --> ItemDrop {}
edge DropsAs: ItemDrop --> ModelResource {}

# g_items.c: dropped items are freed after 30 seconds.
glob DROP_LIFETIME: float = 30.0;

# The Q3 powerups TossClientItems throws, by effect name.
glob DROPPED_POWERUPS: list[str] = ["quad", "battlesuit", "haste", "invisibility", "regen", "flight"];

# bg_public.h ITEM_RADIUS: an item's box reaches 15 units each way.
glob ITEM_RADIUS: float = 15.0;

"""A dropped item in flight (LaunchItem's TR_GRAVITY trajectory), carrying
the item it throws."""
node Flight {
    has velocity: Vec3 = Vec3();
}

edge HasFlight: World --> Flight {}
edge Carries: Flight --> Pickup {}

"""The seeded crandom() behind a throw's lift (each drop moves the item
serial on, so every throw rolls anew)."""
def toss_crandom(world: World) -> float {
    roll = ((world.item_serial + 1) * 1103515245 + 12345) % 2147483647;
    return float(roll) / 2147483647.0 * 2.0 - 1.0;
}

"""Drop_Item: throw one item from `actor`'s origin along `yaw`, level, at
150 units a second with a 200 (±50) unit lift."""
def drop_item(world: World, actor: Player, drop: ItemDrop, yaw: float, collision: CollisionMap, area: Area, eye_height: float) -> Pickup | None {
    models = [drop->:DropsAs:->][?:ModelResource];
    if not models {
        return None;
    }
    origin = actor.pos.sub(Vec3(z=eye_height));
    velocity = Vec3(x=math.cos(yaw) * 150.0, y=math.sin(yaw) * 150.0, z=200.0 + toss_crandom(world) * 50.0);
    item = Pickup(rule=drop.rule, pos=origin, yaw=yaw, dropped=True, lifetime=DROP_LIFETIME);
    item.visual = attach_model(item, models[0]);
    for extra in models[1:] {
        item.visual +>:UsesModel:+> extra;
    }
    item.visual.spin = drop.spin;
    item.visual.bob = drop.bob;
    move_to_area(item, area);
    world +>:HasPickup:+> item;
    world.item_serial += 1;
    flight = Flight(velocity=velocity);
    world +>:HasFlight:+> flight;
    flight +>:Carries:+> item;
    return item;
}

"""G_RunItem for thrown items: gravity carries each along its arc, the
bottom of its box traced through the world. LaunchItem leaves a dropped
item's physicsBounce at 0, so G_BounceItem stops it dead at the first
surface: it rests on a floor, or falls straight down from a wall."""
walker TossTick {
    has collision: CollisionMap,
        dt: float,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        if self.dt > 0.0 {
            visit [here->:HasFlight:->];
        }
    }

    can fly with Flight entry {
        world = self.world;
        items = [here->:Carries:->][?:Pickup];
        if world is None {
            return;
        }
        if not items or not items[0].active {
            self.settle(world, here);
            return;
        }
        item = items[0];
        here.velocity.z -= 800.0 * self.dt;
        bottom = item.pos.sub(Vec3(z=ITEM_RADIUS));
        finish = bottom.add(here.velocity.scale(self.dt));
        trace = self.collision.trace_point(bottom, finish);
        if trace.start_solid {
            self.settle(world, here);
            return;
        }
        item.pos = bottom.lerp(finish, trace.fraction).add(Vec3(z=ITEM_RADIUS));
        world.item_serial += 1;
        if trace.fraction >= 1.0 {
            return;
        }
        if trace.normal.z > 0.0 {
            # Off the ground by a unit and at rest.
            item.pos = item.pos.add(Vec3(z=1.0));
            self.settle(world, here);
            return;
        }
        # A wall or ceiling takes all its speed; it drops from there.
        item.pos = item.pos.add(trace.normal);
        here.velocity = Vec3();
    }

    """The throw is over: the flight lets go of its item and leaves."""
    def settle(world: World, flight: Flight) {
        for link in [edge flight->:Carries:->] {
            del link;
        }
        world del --> flight;
    }
}

"""Whether an item is still being thrown."""
def in_flight(item: Pickup) -> bool {
    return bool([item<-:Carries:<-]);
}

"""TossClientItems for `actor`, which was holding `weapon`. Its powerups
are spent (player_die clears them). Returns the items dropped."""
def toss_items(world: World, actor: Player, weapon: str, collision: CollisionMap, eye_height: float) -> list[Pickup] {
    dropped: list[Pickup] = [];
    drops = [world->:HasItemDrop:->][?:ItemDrop];
    areas = [actor->:In:->][?:Area];
    if not drops or not areas {
        return dropped;
    }
    table: dict[str, ItemDrop] = {};
    for drop in drops {
        table[drop.kind] = drop;
    }
    key = "weapon_" + weapon;
    if weapon not in ["", "gauntlet", "machinegun"] and key in table {
        rule = table[key].rule;
        if not rule.ammo or quantity(actor.inventory, rule.ammo) > 0 {
            item = drop_item(world, actor, table[key], actor.yaw, collision, areas[0], eye_height);
            if item is not None {
                dropped.append(item);
            }
        }
    }
    angle = 45.0;
    for power in [actor->:Empowered:->][?:Powerup] {
        if power.kind not in DROPPED_POWERUPS or power.remaining <= 0.0 or power.kind not in table {
            continue;
        }
        item = drop_item(world, actor, table[power.kind], actor.yaw + math.radians(angle), collision, areas[0], eye_height);
        if item is not None {
            item.duration = max(1.0, float(int(power.remaining)));
            dropped.append(item);
        }
        angle += 45.0;
        power.remaining = 0.0;
    }
    return dropped;
}
