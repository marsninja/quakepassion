"""Versioned text snapshots, restored only into a newly loaded world."""
import math;
import os;
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat { CombatState, Opponent, HasOpponent }
import from engine.world.pickups { Pickup, HasPickup }
import from engine.world.doors { Door, HasDoor, DoorMember }
import from engine.world.inventory {
    Inventory,
    ItemStack,
    InventorySlot,
    AdjustInventory
}
import from engine.world.triggers { TouchTrigger, HasTrigger }
import from engine.world.traversal { Traversal, HasTraversal }
import from engine.world.signals { Signal, HasSignal }
import from engine.math.vec3 { Vec3 }

# Deliberately simple data-only format: no code evaluation or graph deserialization.
def numbers(values: list[float]) -> str {
    return " ".join([str(value) for value in values]);
}

def values(line: str, count: int) -> list[float] {
    result = [float(word) for word in line.split()];
    if len(result) != count {
        raise ValueError("Invalid save record length");
    }
    for value in result {
        if not math.isfinite(value) {
            raise ValueError("Invalid save number");
        }
    }
    return result;
}

def snapshot(world: World, level: Level, player: Player, combat: CombatState) -> str {
    lines = [
        "QUAKEPASSION 2",
        level.bsp.game,
        level.name,
        numbers(
            [
                player.pos.x,
                player.pos.y,
                player.pos.z,
                player.yaw,
                player.pitch,
                float(player.health),
                float(player.armor),
                player.armor_ratio,
                float(player.max_health),
                float(player.armor_capacity),
                float(combat.weapon),
                float(combat.kills),
                player.air_remaining,
                float(player.drown_damage),
                player.hazard_wait,
                player.velocity.x,
                player.velocity.y,
                player.velocity.z,
                1.0 if player.crouched else 0.0,
                level.collision.eye_height,
                level.collision.top_drop,
                player.teleport_cooldown,
                player.teleport_hold,
                combat.cooldown
            ]
        )
    ];
    for item in [player.inventory->:InventorySlot:->][?:ItemStack] {
        lines.append(
            "I " + item.kind + " " + str(item.quantity) + " " + str(item.capacity)
        );
    }
    for enemy in [world->:HasOpponent:->][?:Opponent] {
        lines.append(
            "E "
                + numbers(
                    [
                        enemy.pos.x,
                        enemy.pos.y,
                        enemy.pos.z,
                        float(enemy.health),
                        enemy.yaw,
                        enemy.attack_wait,
                        enemy.respawn_wait
                    ]
                )
        );
    }
    for pickup in [world->:HasPickup:->][?:Pickup] {
        lines.append("P " + numbers([1.0 if pickup.active else 0.0, pickup.remaining]));
    }
    for door in [world->:HasDoor:->][?:Door] {
        lines.append(
            "D "
                + door.state
                + " "
                + numbers(
                    [
                        door.position,
                        door.remaining,
                        1.0 if door.automatic else 0.0,
                        float(door.activation.pending),
                        1.0 if door.unlocked else 0.0
                    ]
                )
        );
    }
    for signal in [world->:HasSignal:->][?:Signal] {
        lines.append(
            "S " + numbers([1.0 if signal.enabled else 0.0, float(signal.pending), float(signal.remaining)])
        );
    }
    for trigger in [world->:HasTrigger:->][?:TouchTrigger] {
        lines.append(
            "T "
                + numbers(
                    [
                        1.0 if trigger.enabled else 0.0,
                        trigger.cooldown,
                        float(trigger.activations)
                    ]
                )
        );
    }
    for traversal in [world->:HasTraversal:->][?:Traversal] {
        lines.append(
            "V "
                + numbers(
                    [1.0 if traversal.enabled else 0.0, float(traversal.activations)]
                )
        );
    }
    return "\n".join(lines) + "\n";
}

def restore(
    world: World, level: Level, player: Player, combat: CombatState, data: str
) {
    lines = data.splitlines();
    if len(lines) < 4
        or lines[0] != "QUAKEPASSION 2"
        or lines[1] != level.bsp.game
        or lines[2] != level.name {
        raise ValueError("Save version or level mismatch");
    }
    stats = values(lines[3], 24);
    player.pos = Vec3(x=stats[0], y=stats[1], z=stats[2]);
    player.yaw = stats[3];
    player.pitch = stats[4];
    player.health = int(stats[5]);
    player.armor = int(stats[6]);
    player.armor_ratio = stats[7];
    player.max_health = int(stats[8]);
    player.armor_capacity = int(stats[9]);
    combat.weapon = int(stats[10]);
    combat.kills = int(stats[11]);
    player.air_remaining = stats[12];
    player.drown_damage = int(stats[13]);
    player.hazard_wait = stats[14];
    if player.health < 0 or player.health > 10000 or combat.weapon not in [1, 2] {
        raise ValueError("Invalid saved player");
    }
    player.velocity = Vec3(x=stats[15], y=stats[16], z=stats[17]);
    player.crouched = stats[18] != 0.0;
    level.collision.eye_height = stats[19];
    level.collision.top_drop = stats[20];
    player.teleport_cooldown = stats[21];
    player.teleport_hold = stats[22];
    combat.cooldown = stats[23];
    player.inventory = Inventory();
    enemies = [world->:HasOpponent:->][?:Opponent];
    pickups = [world->:HasPickup:->][?:Pickup];
    doors = [world->:HasDoor:->][?:Door];
    signals = [world->:HasSignal:->][?:Signal];
    triggers = [world->:HasTrigger:->][?:TouchTrigger];
    traversal = [world->:HasTraversal:->][?:Traversal];
    e = 0;
    p = 0;
    d = 0;
    s = 0;
    t = 0;
    v = 0;
    for line in lines[4:] {
        words = line.split();
        if not words {
            continue;
        }
        if words[0] == "I" and len(words) == 4 {
            amount = int(words[2]);
            capacity = int(words[3]);
            if amount < 0 or capacity < amount or capacity > 10000 {
                raise ValueError("Invalid saved inventory");
            }
            player.inventory spawn AdjustInventory(
                kind=words[1], amount=amount, capacity=capacity
            );
        } elif words[0] == "E" and e < len(enemies) {
            row = values(" ".join(words[1:]), 7);
            enemy = enemies[e];
            e += 1;
            enemy.pos = Vec3(x=row[0], y=row[1], z=row[2]);
            enemy.health = int(row[3]);
            enemy.yaw = row[4];
            enemy.attack_wait = row[5];
            enemy.respawn_wait = row[6];
            enemy.visual.visible = enemy.health > 0;
        } elif words[0] == "P" and p < len(pickups) {
            row = values(" ".join(words[1:]), 2);
            item = pickups[p];
            p += 1;
            item.active = row[0] != 0.0;
            item.remaining = row[1];
            item.visual.visible = item.active;
        } elif words[0] == "D" and d < len(doors) {
            row = values(" ".join(words[2:]), 5);
            door = doors[d];
            d += 1;
            if words[1] not in ["closed", "opening", "open", "closing", "locked"]
                or row[0] < 0.0
                or row[0] > 1.0 {
                raise ValueError("Invalid saved door");
            }
            door.state = words[1];
            door.position = row[0];
            door.remaining = row[1];
            door.automatic = row[2] != 0.0;
            door.activation.pending = int(row[3]);
            door.unlocked = row[4] != 0.0;
            if door.unlocked and door.keys { door.hold_time = -1.0; }
            members = [door];
            members.extend([door->:DoorMember:->][?:Door]);
            for part in members {
                part.position = door.position;
                motion = part.rest.add(part.travel.scale(door.position));
                for face in part.faces {
                    level.bsp.faces[face].motion = motion;
                }
                for i in range(len(part.hulls)) {
                    level.collision.offsets[part.hulls[i]] = part.origins[i].add(
                        motion
                    );
                }
            }
        } elif words[0] == "S" and s < len(signals) {
            row = values(" ".join(words[1:]), 3);
            signal = signals[s];
            s += 1;
            signal.enabled = row[0] != 0.0;
            signal.pending = int(row[1]);
            signal.remaining = int(row[2]);
        } elif words[0] == "T" and t < len(triggers) {
            row = values(" ".join(words[1:]), 3);
            trigger = triggers[t];
            t += 1;
            trigger.enabled = row[0] != 0.0;
            trigger.cooldown = row[1];
            trigger.activations = int(row[2]);
        } elif words[0] == "V" and v < len(traversal) {
            row = values(" ".join(words[1:]), 2);
            link = traversal[v];
            v += 1;
            link.enabled = row[0] != 0.0;
            link.activations = int(row[1]);
        } else {
            raise ValueError("Invalid save record");
        }
    }
    if e != len(enemies)
        or p != len(pickups)
        or d != len(doors)
        or s != len(signals)
        or t != len(triggers)
        or v != len(traversal) {
        raise ValueError("Save does not match this map's entities");
    }
}

def write_save(path: str, data: str) {
    with open(path + ".tmp", "w") as stream {
        stream.write(data);
    }
    os.replace(path + ".tmp", path);
}

def read_save(path: str) -> str {
    with open(path, "r") as stream {
        return stream.read();
    }
}
