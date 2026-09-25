"""Versioned text snapshots, restored only into a newly loaded world."""
import from .save_format { SNAPSHOT_HEADER }
import from engine.world.gibs { Gib, HasGib }
import from engine.world.patrols { Patrols, Holds }
import from engine.world.gates { ApplyGates }
import from engine.world.chthon { LightningEvent, HasLightning, boss_pose }
import from engine.world.trains {
    Train,
    HasTrain,
    TrackPoint,
    HasTrack,
    train_position
}
import from engine.world.hazards { Hazard, HasHazard }
import from engine.world.finale {
    TeleportTrain,
    HasTeleportTrain,
    Finale,
    HasFinale,
    SHUB_TEXT
}
import from engine.world.speakers { Speaker, HasSpeaker }
import from engine.world.brushes { BrushObject, HasBrush, show_brush }
import math;
import os;
import from engine.world.world { World, Player, In, move_to_area }
import from engine.world.level { Level }
import from engine.world.combat {
    attack_duration,
    attack_event_count,
    current_profile,
    ensure_profiles,
    pain_length,
    select_profile,
    CombatState,
    Opponent,
    HasOpponent,
    Drops,
    show_wounds,
    Projectile,
    HasProjectile
}
import from engine.world.pickups { Pickup, HasPickup }
import from engine.world.doors { Door, HasDoor, DoorMember, apply_pose }
import from engine.world.rotators { Rotator, HasRotator, place }
import from engine.world.shooters { Shooter, HasShooter }
import from engine.world.powerups { Powerup, Empowered }
import from engine.world.arena { Competes, match_of }
import from engine.world.inventory {
    Inventory,
    ItemStack,
    InventorySlot,
    AdjustInventory
}
import from engine.world.triggers { TouchTrigger, HasTrigger }
import from engine.world.traversal { Traversal, HasTraversal }
import from engine.world.signals {
    Signal,
    HasSignal,
    DelayedUse,
    HasProgress,
    Progress
}
import from engine.math.vec3 { Vec3 }

# Deliberately simple data-only format: no code evaluation or graph deserialization.
glob POWERUP_KINDS: list[str] = [
    "quad",
    "invulnerability",
    "invisibility",
    "suit",
    "breather",
    "silencer",
    "battlesuit",
    "haste",
    "regen",
    "flight",
    "megahealth",
    "vitality",
    "power_screen",
    "power_shield"
];

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
        SNAPSHOT_HEADER,
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
                combat.cooldown,
                float(combat.random_state),
                float(combat.grenade_phase),
                combat.grenade_clock,
                combat.grenade_remaining
            ]
        )
    ];
    # Missiles keep their owner (never hit) and homing target as opponent indices.
    owners = [world->:HasOpponent:->][?:Opponent];
    for projectile in [world->:HasProjectile:->][?:Projectile] {
        owner_index = -1;
        quarry_index = -1;
        for index in range(len(owners)) {
            if owners[index] is projectile.owner {
                owner_index = index;
            }
            if owners[index] is projectile.quarry {
                quarry_index = index;
            }
        }
        lines.append(
            ("TRAP " if projectile.trap else ("X " if projectile.hostile else "J "))
                + (projectile.effect or "-")
                + " "
                + numbers(
                    [
                        projectile.pos.x,
                        projectile.pos.y,
                        projectile.pos.z,
                        projectile.velocity.x,
                        projectile.velocity.y,
                        projectile.velocity.z,
                        float(projectile.damage),
                        float(projectile.splash),
                        projectile.radius,
                        1.0 if projectile.gravity else 0.0,
                        projectile.remaining,
                        float(projectile.beam_damage),
                        projectile.beam_radius,
                        float(projectile.burst_damage),
                        projectile.burst_radius,
                        projectile.beam_wait,
                        projectile.burst_wait,
                        float(projectile.phase),
                        projectile.age,
                        projectile.homing,
                        projectile.homing_wait,
                        float(owner_index),
                        float(quarry_index)
                    ]
                )
        );
    }
    if level.asset_manifest {
        lines.append("M " + level.asset_manifest);
    }
    # Loading must rebuild the entity set of the skill that was saved.
    lines.append("SKILL " + str(level.skill));
    for item in [player.inventory->:InventorySlot:->][?:ItemStack] {
        lines.append(
            "I " + item.kind + " " + str(item.quantity) + " " + str(item.capacity)
        );
    }
    for shooter in [world->:HasShooter:->][?:Shooter] {
        lines.append("SHOOTER " + numbers([shooter.clock, float(shooter.random_state)]));
    }
    for mover in [world->:HasRotator:->][?:Rotator] {
        lines.append(
            "MOVER " + numbers([mover.clock, 1.0 if mover.active else 0.0, mover.crush_wait])
        );
    }
    contest = match_of(world);
    if contest is not None {
        lines.append(
            "MATCH "
                + numbers(
                    [
                        float(contest.fraglimit),
                        contest.elapsed,
                        contest.warmup,
                        1.0 if contest.finished else 0.0,
                        float(contest.lead),
                        float(contest.frags_called)
                    ]
                )
        );
        for score in [edge contest->:Competes:->] {
            lines.append(
                "SCORE "
                    + numbers(
                        [
                            float(score.frags),
                            float(score.deaths),
                            1.0 if score.down else 0.0
                        ]
                    )
            );
        }
    }
    for power in [player->:Empowered:->][?:Powerup] {
        lines.append(
            "POWER "
                + power.kind
                + " "
                + numbers([power.remaining, power.clock, float(power.count)])
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
                        enemy.respawn_wait,
                        1.0 if enemy.dormant else 0.0,
                        enemy.spawn_wait,
                        float(enemy.boss_phase),
                        enemy.boss_time,
                        enemy.attack_clock,
                        float(enemy.attack_event),
                        float(enemy.attack_profile),
                        enemy.pain_wait,
                        enemy.pain_cooldown,
                        float(enemy.shot_random),
                        float(enemy.burst_count),
                        1.0 if enemy.leaping else 0.0,
                        enemy.attack_target.x,
                        enemy.attack_target.y,
                        enemy.attack_target.z,
                        1.0 if enemy.pain_down else 0.0,
                        float(enemy.pain_variant),
                        enemy.velocity.x,
                        enemy.velocity.y,
                        enemy.velocity.z,
                        1.0 if enemy.grounded else 0.0,
                        float(enemy.armor),
                        float(enemy.armor_capacity),
                        enemy.armor_ratio
                    ]
                )
        );
    }
    # Where each campaign monster is walking: its patrol corner, pause and Q2
    # combat point, as indices into the path graph (-1 for none).
    corners = [world->:HasTrack:->][?:TrackPoint];
    walkers = [world->:HasOpponent:->][?:Opponent];
    for index in range(len(walkers)) {
        walker_node = walkers[index];
        if walker_node.arena {
            continue;
        }
        heading = -1;
        holding = -1;
        for slot in range(len(corners)) {
            if corners[slot] in [walker_node->:Patrols:->] {
                heading = slot;
            }
            if corners[slot] in [walker_node->:Holds:->] {
                holding = slot;
            }
        }
        lines.append(
            "PATROL " + str(index) + " " + str(heading) + " " + str(holding) + " " + str(walker_node.patrol_wait)
        );
    }
    # Corpse health and gibbing, for Q2/Q3 corpses that can still be blown apart.
    corpses = [world->:HasOpponent:->][?:Opponent];
    # Arena bots keep their weapon, ammo and holdables: one BOTITEM per stack.
    for index in range(len(corpses)) {
        armed = corpses[index];
        if armed.character is None {
            continue;
        }
        lines.append("BOTARM " + str(index) + " " + str(armed.weapon_slot));
        for stack in [armed.inventory->:InventorySlot:->][?:ItemStack] {
            lines.append(
                "BOTITEM " + str(index) + " " + stack.kind + " " + str(stack.quantity) + " " + str(stack.capacity)
            );
        }
    }
    # A power screen's remaining cells, and whether a medic raised the monster
    # (a raised monster's targets are cleared).
    for index in range(len(corpses)) {
        if corpses[index].power_cells >= 0
            or corpses[index].revived
            or corpses[index].wounded {
            lines.append(
                "TACTIC "
                    + str(index)
                    + " "
                    + str(corpses[index].power_cells)
                    + " "
                    + ("1" if corpses[index].revived else "0")
                    + " "
                    + ("1" if corpses[index].wounded else "0")
            );
        }
    }
    for index in range(len(corpses)) {
        if corpses[index].health <= 0 {
            lines.append(
                "CORPSE "
                    + str(index)
                    + " "
                    + str(corpses[index].remains)
                    + " "
                    + ("1" if corpses[index].gibbed else "0")
            );
        }
    }
    for pickup in [world->:HasPickup:->][?:Pickup] {
        lines.append(
            "P "
                + numbers(
                    [
                        1.0 if pickup.active else 0.0,
                        pickup.remaining,
                        1.0 if pickup.waiting_for_use else 0.0,
                        1.0 if pickup.activate_on_use else 0.0,
                        1.0 if pickup.dropped else 0.0,
                        pickup.pos.x,
                        pickup.pos.y,
                        pickup.pos.z
                    ]
                )
        );
    }
    for door in [world->:HasDoor:->][?:Door] {
        member_health = [float(part.health) for part in [door->:DoorMember:->][?:Door]];
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
                        1.0 if door.unlocked else 0.0,
                        float(door.health),
                        door.contact_remaining
                    ]
                        + member_health
                )
        );
    }
    for train in [world->:HasTrain:->][?:Train] {
        lines.append(
            "R "
                + numbers(
                    [
                        float(train.model),
                        float(train.current.entity),
                        float(train.destination.entity)
                            if train.destination is not None
                            else -1.0,
                        train.motion.x,
                        train.motion.y,
                        train.motion.z,
                        train.remaining,
                        train.damage_wait,
                        1.0 if train.running else 0.0,
                        1.0 if train.started else 0.0
                    ]
                )
        );
    }
    for signal in [world->:HasSignal:->][?:Signal] {
        lines.append(
            "S "
                + numbers(
                    [
                        1.0 if signal.enabled else 0.0,
                        float(signal.pending),
                        float(signal.remaining),
                        float(signal.random_state),
                        1.0 if signal.timer_running else 0.0,
                        signal.timer_remaining,
                        1.0 if signal.timer_inventory is not None else 0.0
                    ]
                )
        );
    }
    saved_signals = [world->:HasSignal:->][?:Signal];
    for index in range(len(saved_signals)) {
        for event in saved_signals[index].queued {
            lines.append(
                "Q "
                    + numbers(
                        [
                            float(index),
                            event.remaining,
                            1.0 if event.inventory is not None else 0.0
                        ]
                    )
            );
        }
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
    for brush in [world->:HasBrush:->][?:BrushObject] {
        lines.append(
            "B "
                + numbers(
                    [
                        float(brush.model),
                        1.0 if brush.active else 0.0,
                        1.0 if brush.destroyed else 0.0,
                        float(brush.health),
                        1.0 if brush.usable else 0.0
                    ]
                )
        );
    }
    for speaker in [world->:HasSpeaker:->][?:Speaker] {
        lines.append(
            "A " + numbers([1.0 if speaker.playing else 0.0, float(speaker.requests)])
        );
    }
    for progress in [world->:HasProgress:->][?:Progress] {
        lines.append("O " + numbers([float(progress.secrets), float(progress.goals)]));
    }
    for hazard in [world->:HasHazard:->][?:Hazard] {
        lines.append("H " + numbers([1.0 if hazard.enabled else 0.0, hazard.cooldown]));
    }
    for traversal in [world->:HasTraversal:->][?:Traversal] {
        lines.append(
            "V "
                + numbers(
                    [1.0 if traversal.enabled else 0.0, float(traversal.activations)]
                )
        );
    }
    for event in [world->:HasLightning:->][?:LightningEvent] {
        lines.append("L " + str(event.remaining));
    }
    for ball in [world->:HasTeleportTrain:->][?:TeleportTrain] {
        lines.append(
            "K "
                + numbers(
                    [
                        float(ball.current.entity),
                        float(ball.destination.entity)
                            if ball.destination is not None
                            else -1.0,
                        ball.pos.x,
                        ball.pos.y,
                        ball.pos.z,
                        ball.yaw
                    ]
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
        or lines[0] != SNAPSHOT_HEADER
        or lines[1] != level.bsp.game
        or lines[2] != level.name {
        raise ValueError("Save version or level mismatch");
    }
    stats = values(lines[3], 28);
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
    if player.health < 0
        or player.health > 10000
        or combat.weapon < 1
        or combat.weapon
            > {"q1": 8, "q2": 11, "q3": 9, "passion": 2}.get(level.bsp.game, 2)
        or stats[10] != float(combat.weapon) {
        raise ValueError("Invalid saved player");
    }
    player.velocity = Vec3(x=stats[15], y=stats[16], z=stats[17]);
    player.crouched = stats[18] != 0.0;
    level.collision.eye_height = stats[19];
    level.collision.top_drop = stats[20];
    player.teleport_cooldown = stats[21];
    player.teleport_hold = stats[22];
    combat.cooldown = stats[23];
    if stats[24] < 1.0
        or stats[24] >= 2147483647.0
        or stats[24] != float(int(stats[24])) {
        raise ValueError("Invalid weapon random state");
    }
    combat.random_state = int(stats[24]);
    if stats[25] not in [0.0, 1.0, 2.0, 3.0, 4.0]
        or stats[26] < 0.0
        or stats[26] > 1.0
        or stats[27] < 0.0
        or stats[27] > 3.2
        or (stats[25] > 0.0 and (level.bsp.game != "q2" or combat.weapon != 11)) {
        raise ValueError("Invalid saved grenade state");
    }
    combat.grenade_phase = int(stats[25]);
    combat.grenade_clock = stats[26];
    combat.grenade_remaining = stats[27];
    combat.impacts = [];
    for projectile in [world->:HasProjectile:->][?:Projectile] {
        world del --> projectile;
    }
    player.inventory = Inventory();
    for power in [player->:Empowered:->][?:Powerup] {
        player del --> power;
    }
    # Flying gibs belong to the moment that was left; the saved one has none.
    for gib in [world->:HasGib:->][?:Gib] {
        for placement in [edge gib->:In:->] {
            del placement;
        }
        world del --> gib;
    }
    enemies = [world->:HasOpponent:->][?:Opponent];
    scores: list[Competes] = [];
    ranked = 0;
    rotators = [world->:HasRotator:->][?:Rotator];
    spun = 0;
    shooters = [world->:HasShooter:->][?:Shooter];
    fired = 0;
    lightning = [world->:HasLightning:->][?:LightningEvent];
    l = 0;
    teleport_trains = [world->:HasTeleportTrain:->][?:TeleportTrain];
    k = 0;
    pickups = [world->:HasPickup:->][?:Pickup];
    doors = [world->:HasDoor:->][?:Door];
    signals = [world->:HasSignal:->][?:Signal];
    for signal in signals {
        signal.queued = [];
    }
    triggers = [world->:HasTrigger:->][?:TouchTrigger];
    traversal = [world->:HasTraversal:->][?:Traversal];
    hazards = [world->:HasHazard:->][?:Hazard];
    h = 0;
    brushes = [world->:HasBrush:->][?:BrushObject];
    b = 0;
    speakers = [world->:HasSpeaker:->][?:Speaker];
    a = 0;
    progress_records = [world->:HasProgress:->][?:Progress];
    o = 0;
    trains = [world->:HasTrain:->][?:Train];
    tracks = [world->:HasTrack:->][?:TrackPoint];
    r = 0;
    e = 0;
    p = 0;
    d = 0;
    s = 0;
    t = 0;
    v = 0;
    manifest_seen = False;
    for line in lines[4:] {
        words = line.split();
        if not words {
            continue;
        }
        if words[0] == "M"
            and len(words) == 2
            and not manifest_seen
            and level.asset_manifest {
            if words[1] != level.asset_manifest {
                raise ValueError("Save asset manifest mismatch");
            }
            manifest_seen = True;
        } elif words[0] in ["J", "X", "TRAP"] {
            row = values(" ".join(words[2:]), 23);
            effect = "" if words[1] == "-" else words[1];
            if row[21] < -1.0 or row[21] >= float(len(enemies))
                or row[22] < -1.0 or row[22] >= float(len(enemies)) {
                raise ValueError("Invalid saved projectile owner");
            }
            if len(effect) > 64
                or not all(c.isalnum() or c == "_" for c in effect)
                or row[18] < 0.0
                or row[18] > 60.0 {
                raise ValueError("Invalid saved projectile effect");
            }
            if row[6] < 0.0
                or row[6] > 10000.0
                or row[6] != float(int(row[6]))
                or row[7] < 0.0
                or row[7] > 10000.0
                or row[7] != float(int(row[7]))
                or row[8] < 0.0
                or row[8] > 10000.0
                or row[9] not in [0.0, 1.0]
                or row[10] <= 0.0
                or row[10] > 60.0 {
                raise ValueError("Invalid saved projectile");
            }
            if row[11] < 0.0
                or row[11] > 10000.0
                or row[11] != float(int(row[11]))
                or row[12] < 0.0
                or row[12] > 10000.0
                or row[13] < 0.0
                or row[13] > 10000.0
                or row[13] != float(int(row[13]))
                or row[14] < 0.0
                or row[14] > 10000.0
                or row[15] < 0.0
                or row[15] > 0.1
                or row[16] < 0.0
                or row[16] > 0.1
                or row[17] not in [0.0, 1.0, 2.0] {
                raise ValueError("Invalid saved projectile phase");
            }
            if row[19] < 0.0
                or row[19] > 10000.0
                or row[20] < 0.0
                or row[20] > 0.2
                or (row[19] > 0.0 and words[0] != "X") {
                raise ValueError("Invalid saved projectile homing");
            }
            world +>:HasProjectile:+> Projectile(
                pos=Vec3(x=row[0], y=row[1], z=row[2]),
                velocity=Vec3(x=row[3], y=row[4], z=row[5]),
                damage=int(row[6]),
                splash=int(row[7]),
                radius=row[8],
                gravity=row[9] != 0.0,
                remaining=row[10],
                beam_damage=int(row[11]),
                beam_radius=row[12],
                burst_damage=int(row[13]),
                burst_radius=row[14],
                beam_wait=row[15],
                burst_wait=row[16],
                phase=int(row[17]),
                effect=effect,
                age=row[18],
                homing=row[19],
                homing_wait=row[20],
                hostile=words[0] in ["X", "TRAP"],
                trap=words[0] == "TRAP",
                owner=enemies[int(row[21])] if row[21] >= 0.0 else None,
                quarry=enemies[int(row[22])] if row[22] >= 0.0 else None
            );
        } elif words[0] == "I" and len(words) == 4 {
            amount = int(words[2]);
            capacity = int(words[3]);
            if amount < 0 or capacity < amount or capacity > 10000 {
                raise ValueError("Invalid saved inventory");
            }
            player.inventory spawn AdjustInventory(
                kind=words[1], amount=amount, capacity=capacity
            );
        } elif words[0] == "SHOOTER" and len(words) == 3 and fired < len(shooters) {
            row = values(" ".join(words[1:]), 2);
            if row[1] < 1.0 or row[1] >= 2147483647.0 {
                raise ValueError("Invalid saved shooter");
            }
            shooters[fired].clock = row[0];
            shooters[fired].random_state = int(row[1]);
            fired += 1;
        } elif words[0] == "MOVER" and len(words) == 4 and spun < len(rotators) {
            row = values(" ".join(words[1:]), 3);
            if row[0] < 0.0 or row[2] < 0.0 {
                raise ValueError("Invalid saved mover");
            }
            rotators[spun].clock = row[0];
            rotators[spun].active = row[1] != 0.0;
            rotators[spun].crush_wait = row[2];
            place(rotators[spun], row[0], level.bsp, level.collision);
            spun += 1;
        } elif words[0] == "PATROL" and len(words) == 5 {
            index = int(words[1]);
            heading = int(words[2]);
            holding = int(words[3]);
            corners = [world->:HasTrack:->][?:TrackPoint];
            if index < 0 or index >= len(enemies)
                or heading < -1 or heading >= len(corners)
                or holding < -1 or holding >= len(corners)
                or float(words[4]) < 0.0 {
                raise ValueError("Invalid saved patrol");
            }
            walker_node = enemies[index];
            for route_edge in [edge walker_node->:Patrols:->] {
                del route_edge;
            }
            for hold_edge in [edge walker_node->:Holds:->] {
                del hold_edge;
            }
            if heading >= 0 {
                walker_node +>:Patrols:+> corners[heading];
            }
            if holding >= 0 {
                walker_node +>:Holds:+> corners[holding];
            }
            walker_node.patrol_wait = float(words[4]);
        } elif words[0] == "BOTARM" and len(words) == 3 {
            index = int(words[1]);
            slot = int(words[2]);
            if index < 0 or index >= len(enemies) or slot < 1 or slot > 9 {
                raise ValueError("Invalid saved bot arms");
            }
            enemies[index].inventory = Inventory();
            enemies[index].weapon_slot = slot;
        } elif words[0] == "BOTITEM" and len(words) == 5 {
            index = int(words[1]);
            amount = int(words[3]);
            capacity = int(words[4]);
            if index < 0 or index >= len(enemies) or amount < 0 or capacity < amount or capacity > 10000 {
                raise ValueError("Invalid saved bot item");
            }
            enemies[index].inventory spawn AdjustInventory(
                kind=words[2], amount=amount, capacity=capacity
            );
        } elif words[0] == "CORPSE" and len(words) == 4 {
            index = int(words[1]);
            if index < 0 or index >= len(enemies) or words[3] not in ["0", "1"] {
                raise ValueError("Invalid saved corpse");
            }
            corpse = enemies[index];
            corpse.remains = int(words[2]);
            corpse.gibbed = words[3] == "1";
            if corpse.gibbed {
                corpse.visual.visible = False;
            }
        } elif words[0] == "TACTIC" and len(words) == 5 {
            index = int(words[1]);
            if index < 0
                or index >= len(enemies)
                or words[3] not in ["0", "1"]
                or words[4] not in ["0", "1"] {
                raise ValueError("Invalid saved monster tactics");
            }
            enemies[index].power_cells = int(words[2]);
            enemies[index].revived = words[3] == "1";
            show_wounds(enemies[index], words[4] == "1");
        } elif words[0] == "SKILL" and len(words) == 2 {
            if int(words[1]) != level.skill {
                raise ValueError("Save was made on another skill");
            }
        } elif words[0] == "MATCH" and len(words) == 7 {
            row = values(" ".join(words[1:]), 6);
            contest = match_of(world);
            if contest is None or row[0] < 1.0 or row[2] < 0.0 or row[2] > 10.0 {
                raise ValueError("Invalid saved match");
            }
            contest.fraglimit = int(row[0]);
            contest.elapsed = row[1];
            contest.warmup = row[2];
            contest.finished = row[3] != 0.0;
            contest.lead = int(row[4]);
            contest.frags_called = int(row[5]);
            scores = [edge contest->:Competes:->];
            ranked = 0;
        } elif words[0] == "SCORE" and len(words) == 4 and ranked < len(scores) {
            row = values(" ".join(words[1:]), 3);
            scores[ranked].frags = int(row[0]);
            scores[ranked].deaths = int(row[1]);
            scores[ranked].down = row[2] != 0.0;
            ranked += 1;
        } elif words[0] == "POWER" and len(words) == 5 {
            row = values(" ".join(words[2:]), 3);
            if words[1] not in POWERUP_KINDS
                or row[0] > 10000.0
                or row[2] < 0.0
                or row[2] > 10000.0
                or row[2] != float(int(row[2])) {
                raise ValueError("Invalid saved powerup");
            }
            player +>:Empowered:+> Powerup(
                kind=words[1], remaining=row[0], clock=row[1], count=int(row[2])
            );
        } elif words[0] == "K" and k < len(teleport_trains) {
            row = values(" ".join(words[1:]), 6);
            ball = teleport_trains[k];
            k += 1;
            ball_current = [
                point
                for point in tracks
                if float(point.entity) == row[0]
            ];
            ball_destination = [
                point
                for point in tracks
                if float(point.entity) == row[1]
            ];
            if len(ball_current) != 1
                or (row[1] != -1.0 and len(ball_destination) != 1) {
                raise ValueError("Invalid saved teleport train path");
            }
            ball.current = ball_current[0];
            ball.destination = ball_destination[0] if ball_destination else None;
            ball.pos = Vec3(x=row[2], y=row[3], z=row[4]);
            ball.yaw = row[5];
        } elif words[0] == "L" and l < len(lightning) {
            row = values(" ".join(words[1:]), 1);
            if row[0] < 0.0 or row[0] > 1.0 {
                raise ValueError("Invalid saved lightning");
            }
            lightning[l].remaining = row[0];
            l += 1;
        } elif words[0] == "E" and e < len(enemies) {
            row = values(" ".join(words[1:]), 31);
            enemy = enemies[e];
            e += 1;
            if row[27] not in [0.0, 1.0] {
                raise ValueError("Invalid saved opponent ground state");
            }
            ensure_profiles(enemy);
            enemy.velocity = Vec3(x=row[24], y=row[25], z=row[26]);
            enemy.grounded = row[27] != 0.0;
            if row[28] < 0.0 or row[28] != float(int(row[28]))
                or row[29] < row[28] or row[29] != float(int(row[29]))
                or row[30] < 0.0 or row[30] > 1.0 {
                raise ValueError("Invalid saved opponent armor");
            }
            enemy.armor = int(row[28]);
            enemy.armor_capacity = int(row[29]);
            enemy.armor_ratio = row[30];
            enemy.pos = Vec3(x=row[0], y=row[1], z=row[2]);
            enemy.health = int(row[3]);
            enemy.yaw = row[4];
            enemy.attack_wait = row[5];
            enemy.respawn_wait = row[6];
            if row[7] not in [0.0, 1.0] or row[8] < -1.0 {
                raise ValueError("Invalid saved opponent activation");
            }
            enemy.dormant = row[7] != 0.0;
            enemy.spawn_wait = row[8];
            if row[9] < 0.0
                or row[9] > 7.0
                or row[9] != float(int(row[9]))
                or row[10] < 0.0
                or row[10] > 60.0 {
                raise ValueError("Invalid saved boss state");
            }
            enemy.boss_phase = int(row[9]);
            enemy.boss_time = row[10];
            enemy.visual.visible = (enemy.health > 0 or bool(enemy.death_animation))
                and not enemy.dormant
                and not (enemy.health <= 0 and enemy.rule.vanish_on_death);
            if row[13] < -1.0
                or row[13] != float(int(row[13]))
                or int(row[13]) >= len(enemy.profiles)
                or (row[11] >= 0.0 and row[13] < 0.0) {
                raise ValueError("Invalid saved attack selection");
            }
            select_profile(enemy, int(row[13]));
            profile = current_profile(enemy);
            if row[17] < 1.0
                or row[17] > float(max(1, profile.burst_max))
                or row[17] != float(int(row[17]))
                or (row[17] > 1.0 and enemy.attack_melee) {
                raise ValueError("Invalid saved burst length");
            }
            enemy.burst_count = int(row[17]);
            if row[18] not in [0.0, 1.0] {
                raise ValueError("Invalid saved leap state");
            }
            enemy.leaping = row[18] != 0.0;
            enemy.attack_target = Vec3(x=row[19], y=row[20], z=row[21]);
            if row[22] not in [0.0, 1.0]
                or (row[22] != 0.0 and enemy.rule.knockdown_duration <= 0.0)
                or row[23] < 0.0
                or row[23] != float(int(row[23]))
                or int(row[23]) > len(enemy.rule.pain_variants) {
                raise ValueError("Invalid saved pain state");
            }
            enemy.pain_down = row[22] != 0.0;
            enemy.pain_variant = int(row[23]);
            enemy.route = [];
            enemy.route_launches = [];
            enemy.arena_goal = None;
            enemy.arena_goal_wait = 0.0;
            if enemy.route_search is not None {
                enemy.route_search.cancelled = True;
                enemy.route_search = None;
            }
            enemy.route_wait = 0.0;
            enemy.navigation_needed = False;
            if row[11] < -1.0
                or row[11] > attack_duration(enemy)
                or row[12] < 0.0
                or row[12] > float(attack_event_count(enemy))
                or row[12] != float(int(row[12]))
                or row[14] < 0.0
                or row[14] > pain_length(enemy) + 0.000001
                or row[15] < 0.0
                or row[15]
                    > max(enemy.rule.pain_interval, enemy.rule.knockdown_duration) {
                raise ValueError("Invalid saved attack state");
            }
            if row[16] < 1.0
                or row[16] >= 2147483647.0
                or row[16] != float(int(row[16])) {
                raise ValueError("Invalid saved opponent spread");
            }
            enemy.shot_random = int(row[16]);
            enemy.attack_clock = row[11];
            enemy.attack_event = int(row[12]);
            enemy.attack_flash = max(0.0, attack_duration(enemy) - enemy.attack_clock)
                if enemy.attack_clock >= 0.0
                else 0.0;
            enemy.pain_wait = row[14];
            enemy.pain_cooldown = row[15];
            if enemy.health <= 0 and enemy.death_animation {
                enemy.animation_time = float(len(enemy.death_animation));
                enemy.visual.first = enemy.death_animation[-1];
                enemy.visual.second = enemy.visual.first;
                enemy.visual.blend = 0.0;
            }
            if enemy.rule.script == "chthon" {
                enemy.visual.visible = enemy.boss_phase > 0 and enemy.boss_phase < 7;
                boss_pose(enemy);
            }
        } elif words[0] == "P" and p < len(pickups) {
            row = values(" ".join(words[1:]), 8);
            if row[0] not in [0.0, 1.0]
                or row[1] < 0.0
                or row[2] not in [0.0, 1.0]
                or row[3] not in [0.0, 1.0]
                or row[4] not in [0.0, 1.0]
                or (row[0] != 0.0 and row[2] != 0.0) {
                raise ValueError("Invalid saved pickup");
            }
            item = pickups[p];
            p += 1;
            item.active = row[0] != 0.0;
            item.remaining = row[1];
            item.waiting_for_use = row[2] != 0.0;
            item.activate_on_use = row[3] != 0.0;
            item.visual.visible = item.active;
            # An item a dead monster already dropped stays where it fell.
            if row[4] != 0.0 {
                item.dropped = True;
                item.pos = Vec3(x=row[5], y=row[6], z=row[7]);
                for owner in [item<-:Drops:<-][?:Opponent] {
                    owner del --> item;
                }
                move_to_area(item, level.areas[level.locate(item.pos)]);
            }
        } elif words[0] == "D" and d < len(doors) {
            door = doors[d];
            parts = [door->:DoorMember:->][?:Door];
            row = values(" ".join(words[2:]), 7 + len(parts));
            d += 1;
            if words[1] not in ["closed", "opening", "open", "closing", "locked"]
                or row[0] < 0.0
                or row[0] > 1.0
                or row[5] < 0.0
                or row[5] > float(door.max_health)
                or row[6] < 0.0
                or row[6] > 1.0 {
                raise ValueError("Invalid saved door");
            }
            door.state = words[1];
            door.position = row[0];
            door.remaining = row[1];
            door.automatic = row[2] != 0.0;
            door.activation.pending = int(row[3]);
            door.unlocked = row[4] != 0.0;
            door.health = int(row[5]);
            door.contact_remaining = row[6];
            for index in range(len(parts)) {
                if row[7 + index] < 0.0
                    or row[7 + index] > float(parts[index].max_health) {
                    raise ValueError("Invalid saved door member health");
                }
                parts[index].health = int(row[7 + index]);
            }
            if door.unlocked and door.keys {
                door.hold_time = -1.0;
            }
            members = [door];
            members.extend([door->:DoorMember:->][?:Door]);
            for part in members {
                part.position = door.position;
                apply_pose(part, door.position, level.bsp, level.collision);
            }
        } elif words[0] == "R" and r < len(trains) {
            row = values(" ".join(words[1:]), 10);
            train = trains[r];
            r += 1;
            if row[0] != float(train.model)
                or row[6] < 0.0
                or row[7] < 0.0
                or row[8] not in [0.0, 1.0]
                or row[9] not in [0.0, 1.0] {
                raise ValueError("Invalid saved train");
            }
            current = [
                point
                for point in tracks
                if float(point.entity) == row[1]
            ];
            destination = [
                point
                for point in tracks
                if float(point.entity) == row[2]
            ];
            if len(current) != 1 or (row[2] != -1.0 and len(destination) != 1) {
                raise ValueError("Invalid saved train path");
            }
            train.current = current[0];
            train.destination = destination[0] if destination else None;
            train.remaining = row[6];
            train.damage_wait = row[7];
            train.running = row[8] != 0.0;
            train.started = row[9] != 0.0;
            train_position(
                train, Vec3(x=row[3], y=row[4], z=row[5]), level.bsp, level.collision
            );
        } elif words[0] == "S" and s < len(signals) {
            row = values(" ".join(words[1:]), 7);
            signal = signals[s];
            s += 1;
            signal.enabled = row[0] != 0.0;
            signal.pending = int(row[1]);
            signal.remaining = int(row[2]);
            if row[3] < 1.0 or row[3] >= 2147483647.0 or row[3] != float(int(row[3])) {
                raise ValueError("Invalid saved signal random state");
            }
            signal.random_state = int(row[3]);
            if row[4] not in [0.0, 1.0] or row[5] < 0.0 or row[6] not in [0.0, 1.0] {
                raise ValueError("Invalid saved timer");
            }
            signal.timer_running = row[4] != 0.0;
            signal.timer_remaining = row[5];
            signal.timer_inventory = player.inventory if row[6] != 0.0 else None;
        } elif words[0] == "Q" {
            row = values(" ".join(words[1:]), 3);
            index = int(row[0]);
            if row[0] != float(index)
                or index < 0
                or index >= len(signals)
                or row[1] < 0.0
                or row[2] not in [0.0, 1.0] {
                raise ValueError("Invalid delayed signal");
            }
            signals[index].queued.append(
                DelayedUse(
                    remaining=row[1],
                    inventory=player.inventory if row[2] != 0.0 else None
                )
            );
        } elif words[0] == "T" and t < len(triggers) {
            row = values(" ".join(words[1:]), 3);
            trigger = triggers[t];
            t += 1;
            trigger.enabled = row[0] != 0.0;
            trigger.cooldown = row[1];
            trigger.activations = int(row[2]);
        } elif words[0] == "B" and b < len(brushes) {
            row = values(" ".join(words[1:]), 5);
            brush = brushes[b];
            b += 1;
            if row[0] != float(brush.model)
                or row[1] not in [0.0, 1.0]
                or row[2] not in [0.0, 1.0]
                or row[3] < 0.0
                or row[3] != float(int(row[3]))
                or row[4] not in [0.0, 1.0]
                or (row[2] != 0.0 and (row[1] != 0.0 or row[3] != 0.0)) {
                raise ValueError("Invalid saved brush");
            }
            brush.destroyed = row[2] != 0.0;
            brush.health = int(row[3]);
            brush.usable = row[4] != 0.0;
            show_brush(brush, row[1] != 0.0, level.bsp, level.collision);
        } elif words[0] == "A" and a < len(speakers) {
            row = values(" ".join(words[1:]), 2);
            if row[0] not in [0.0, 1.0]
                or row[1] < 0.0
                or row[1] != float(int(row[1])) {
                raise ValueError("Invalid saved speaker");
            }
            speakers[a].playing = row[0] != 0.0;
            speakers[a].requests = int(row[1]);
            a += 1;
        } elif words[0] == "O" and o < len(progress_records) {
            row = values(" ".join(words[1:]), 2);
            record = progress_records[o];
            o += 1;
            if row[0] < 0.0
                or row[0] > float(record.total_secrets)
                or row[0] != float(int(row[0]))
                or row[1] < 0.0
                or row[1] > float(record.total_goals)
                or row[1] != float(int(row[1])) {
                raise ValueError("Invalid saved campaign progress");
            }
            record.secrets = int(row[0]);
            record.goals = int(row[1]);
        } elif words[0] == "H" and h < len(hazards) {
            row = values(" ".join(words[1:]), 2);
            if row[0] not in [0.0, 1.0] or row[1] < 0.0 {
                raise ValueError("Invalid saved hazard");
            }
            hazards[h].enabled = row[0] != 0.0;
            hazards[h].cooldown = row[1];
            h += 1;
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
    if (bool(level.asset_manifest) != manifest_seen)
        or e != len(enemies)
        or p != len(pickups)
        or d != len(doors)
        or s != len(signals)
        or t != len(triggers)
        or v != len(traversal)
        or r != len(trains)
        or h != len(hazards)
        or o != len(progress_records)
        or a != len(speakers)
        or b != len(brushes)
        or l != len(lightning)
        or k != len(teleport_trains)
        or ranked != len(scores)
        or spun != len(rotators)
        or fired != len(shooters) {
        raise ValueError("Save does not match this map's entities");
    }
    for finale in [world->:HasFinale:->][?:Finale] {
        finale.camera = False;
        finale.text = "";
        for boss in enemies {
            if boss.rule.script == "shub" and boss.boss_phase >= 1 {
                finale.camera = True;
                if boss.boss_phase >= 3 {
                    finale.text = SHUB_TEXT;
                    boss.visual.visible = False;
                }
            }
        }
    }
    world spawn ApplyGates(
        inventory=player.inventory, bsp=level.bsp, collision=level.collision
    );
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
