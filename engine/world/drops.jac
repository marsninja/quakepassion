"""g_combat.c TossClientItems: a Q3 player who dies throws down the weapon it
held (never the gauntlet or machine gun, and only with ammo left) and every
powerup it carried, with the time that was left on it. Dropped items do not
respawn and are gone after thirty seconds (LaunchItem)."""
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

"""Place one item a short toss from `actor` along `yaw`, on the floor."""
def drop_item(world: World, actor: Player, drop: ItemDrop, yaw: float, collision: CollisionMap, area: Area, eye_height: float) -> Pickup | None {
    models = [drop->:DropsAs:->][?:ModelResource];
    if not models {
        return None;
    }
    feet = actor.pos.sub(Vec3(z=eye_height - 16.0));
    toward = feet.add(Vec3(x=math.cos(yaw) * 48.0, y=math.sin(yaw) * 48.0));
    reach = collision.trace_point(feet, toward);
    landing = feet if reach.start_solid else feet.lerp(toward, max(0.0, reach.fraction - 0.1));
    floor = collision.trace_point(landing, landing.sub(Vec3(z=256.0)));
    if not floor.start_solid and floor.fraction < 1.0 {
        landing = landing.lerp(landing.sub(Vec3(z=256.0)), floor.fraction).add(Vec3(z=15.0));
    }
    item = Pickup(rule=drop.rule, pos=landing, yaw=yaw, dropped=True, lifetime=DROP_LIFETIME);
    item.visual = attach_model(item, models[0]);
    for extra in models[1:] {
        item.visual +>:UsesModel:+> extra;
    }
    item.visual.spin = drop.spin;
    item.visual.bob = drop.bob;
    move_to_area(item, area);
    world +>:HasPickup:+> item;
    world.item_serial += 1;
    return item;
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
