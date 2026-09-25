"""Shared swept-contact traversal, with map-defined destinations and launches."""
import math;
import from .world { World, Player }
import from .damage { Damage }
import from .finale { TeleportTrain, teleport_train_at, telefrag }
import from .combat {
    KillBox,
    CombatState,
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    damage_opponent
}
import from .triggers { trigger_volume }
import from .doors { door_direction }
import from .signals { Signal, HasSignal, note_chain }
import from .speakers { Speaker, HasSpeaker }
import from .particles { ImpactParticle, HasParticle }
import from ..formats.bsp { Bsp, MapEntity }
import from ..formats.q1.collision { build_collision }
import from ..formats.brush_collision { build_brush_collision }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3, forward_from }

edge HasTraversal: World --> Traversal {}
edge ArrivesAt: Traversal --> Destination {}
edge FollowsTrain: Traversal --> TeleportTrain {}

node Destination {
    has origin: Vec3,
        yaw: float = 0.0,
        pitch: float = 0.0,
        exit_speed: float = 300.0,
        hold_time: float = 0.0,
        speaker: Speaker | None = None;
}

node Traversal {
    has volume: CollisionMap,
        kind: str,
        velocity: Vec3 = Vec3(),
        once: bool = False,
        enabled: bool = True,
        activations: int = 0,
        nav_entry: Vec3 | None = None,
        nav_exit: Vec3 | None = None,
        activation: Signal = Signal(),
        gated: bool = False,
        window: float = 0.0,
        game: str = "",
        monsters: bool = False,
        in_contact: bool = False,
        sound_wait: float = 0.0;
}

"""Whether a body touches a trigger volume. Triggers touch by bounding boxes
(SV_TouchLinks, with SV_LinkEdict's one-unit margin on each box); the volume's
bounds are its brushes grown by the standing player box, so a body of another
size shifts them by the difference."""
def touches_volume(volume: CollisionMap, origin: Vec3, width: float = 16.0, top: float = 32.0) -> bool {
    for box in volume.bounds {
        lo = box.mins.add(Vec3(x=16.0 - width - 2.0, y=16.0 - width - 2.0, z=-2.0));
        hi = box.maxs.add(Vec3(x=width - 16.0 + 2.0, y=width - 16.0 + 2.0, z=top - 32.0 + 2.0));
        if lo.x <= origin.x and origin.x <= hi.x
            and lo.y <= origin.y and origin.y <= hi.y
            and lo.z <= origin.z and origin.z <= hi.z {
            return True;
        }
    }
    return False;
}

"""Whether a body's box, moving from `start` to `finish`, touches a trigger
volume anywhere on the way: the moving box against each volume box, as
touches_volume grows them, by the slab test."""
def sweeps_volume(
    volume: CollisionMap, start: Vec3, finish: Vec3, width: float = 16.0, top: float = 32.0
) -> bool {
    for box in volume.bounds {
        lo = box.mins.add(Vec3(x=16.0 - width - 2.0, y=16.0 - width - 2.0, z=-2.0));
        hi = box.maxs.add(Vec3(x=width - 16.0 + 2.0, y=width - 16.0 + 2.0, z=top - 32.0 + 2.0));
        origins = [start.x, start.y, start.z];
        deltas = [finish.x - start.x, finish.y - start.y, finish.z - start.z];
        mins = [lo.x, lo.y, lo.z];
        maxs = [hi.x, hi.y, hi.z];
        enter = 0.0;
        leave = 1.0;
        for axis in range(3) {
            if abs(deltas[axis]) < 0.000001 {
                if origins[axis] < mins[axis] or origins[axis] > maxs[axis] {
                    enter = 2.0;
                }
            } else {
                a = (mins[axis] - origins[axis]) / deltas[axis];
                b = (maxs[axis] - origins[axis]) / deltas[axis];
                enter = max(enter, min(a, b));
                leave = min(leave, max(a, b));
            }
        }
        if enter <= leave {
            return True;
        }
    }
    return False;
}

# A monster moving farther than this in one tick was placed, not moved.
glob MONSTER_SWEEP_LIMIT: float = 256.0;

"""A monster's own touch box: Q1/Q2 walkers are 32 wide up to 32 above their
origin; the large hull (and anything wider) reaches 64. The box is swept from
where the monster was last checked, so a fast monster (a leaping fiend, a
charging mutant) cannot pass through a thin trigger between two ticks."""
def monster_touches(volume: CollisionMap, actor: Opponent) -> bool {
    width = max(16.0, actor.rule.width);
    top = 64.0 if width > 16.0 else 32.0;
    origin = actor.pos.sub(Vec3(z=actor.eye_height));
    start = actor.touch_origin;
    if start is not None and start.sub(origin).length() <= MONSTER_SWEEP_LIMIT {
        return sweeps_volume(volume, start, origin, width, top);
    }
    return touches_volume(volume, origin, width, top);
}

"""A short teleport flash (Q1 R_TeleportSplash, Q2 CL_TeleportParticles, Q3
CG_SpawnEffect): sparks thrown outward from the arrival point."""
def teleport_flash(world: World, origin: Vec3) {
    count = len([world->:HasParticle:->]);
    for i in range(min(24, max(0, 512 - count))) {
        angle = float(i) * 0.785398 + float(i // 8) * 0.39;
        rise = float(i % 3) - 1.0;
        velocity = Vec3(
            x=math.cos(angle) * 60.0, y=math.sin(angle) * 60.0, z=40.0 + rise * 30.0
        );
        life = 0.3 + float(i % 5) * 0.04;
        world +>:HasParticle:+> ImpactParticle(
            pos=origin.add(Vec3(z=float(i % 4) * 12.0 - 8.0)),
            velocity=velocity,
            remaining=life,
            lifetime=life
        );
    }
}

walker TraversalTick {
    has player: Player,
        collision: CollisionMap,
        start: Vec3,
        dt: float,
        touching: bool = True,
        relocated: bool = False,
        targets: list[Traversal] = [],
        selected_only: bool = False,
        bystander: Player | None = None,
        bystander_height: float = 22.0,
        tally: CombatState | None = None,
        world: World | None = None,
        cues: list[str] = [];

    # Uses open named teleporters even while the player flies, so monster
    # teleport-ins keep working.
    can begin with World entry {
        if self.dt <= 0.0 {
            return;
        }
        self.world = here;
        if self.touching {
            self.player.teleport_cooldown = max(
                0.0, self.player.teleport_cooldown - self.dt
            );
        }
        if self.selected_only { visit self.targets; }
        else { visit [here->:HasTraversal:->]; }
    }

    can touch with Traversal entry {
        if here.activation.killed {
            here.enabled = False;
        }
        # Q1 tele_touch: a named teleporter only works just after it is used.
        if here.activation.pending > 0 {
            here.activation.pending = 0;
            here.window = 0.2;
        }
        here.window = max(0.0, here.window - self.dt);
        here.sound_wait = max(0.0, here.sound_wait - self.dt);
        contact = here.in_contact;
        here.in_contact = False;
        if here.gated and here.window <= 0.0 {
            return;
        }
        if self.dt <= 0.0 or not self.touching or not here.enabled or self.relocated {
            return;
        }
        finish = self.player.pos.sub(Vec3(z=self.collision.eye_height));
        hit = here.volume.trace(self.start, finish, top_drop=self.collision.top_drop);
        if not hit.start_solid and hit.fraction == 1.0 {
            return;
        }
        here.in_contact = True;
        if here.kind == "teleport_train" {
            if self.player.teleport_cooldown > 0.0 or self.world is None {
                return;
            }
            trains = [here->:FollowsTrain:->][?:TeleportTrain];
            if len(trains) != 1 {
                return;
            }
            point = trains[0].pos.add(Vec3());
            self.player.pos = point.add(Vec3(z=self.collision.eye_height));
            self.player.velocity = Vec3();
            self.player.teleport_cooldown = 0.2;
            self.relocated = True;
            here.activations += 1;
            # Whatever occupies the ball's spot is telefragged: the boss, or the
            # player inside solid rock.
            if not telefrag(self.world, self.player, point, self.collision.eye_height)
                and self.collision.trace(point, point).start_solid {
                self.player spawn Damage(
                    amount=100000, bypass_armor=True, bypass_protection=True
                );
            }
            return;
        }
        if here.kind == "teleport" {
            if self.player.teleport_cooldown > 0.0 {
                return;
            }
            destinations = [here->:ArrivesAt:->][?:Destination];
            if len(destinations) != 1 {
                return;
            }
            destination = destinations[0];
            if self.collision.trace(
                destination.origin, destination.origin
            ).start_solid {
                return;
            }
            self.player.pos = destination.origin.add(Vec3(z=self.collision.eye_height));
            self.player.yaw = destination.yaw;
            self.player.pitch = destination.pitch;
            self.player.velocity = forward_from(
                destination.yaw, destination.pitch
            ).scale(
                destination.exit_speed
            );
            self.player.teleport_cooldown = 0.2;
            self.player.teleport_hold = destination.hold_time;
            self.relocated = True;
            # Q1 spawn_tfog, Q2 EV_PLAYER_TELEPORT, Q3 TELEPORT_OUT and _IN.
            if here.game == "q3" {
                self.cues.append("sound/world/teleout.wav");
                self.cues.append("sound/world/telein.wav");
            } elif here.game == "q2" {
                self.cues.append("sound/misc/tele1.wav");
            }
            speaker = destination.speaker;
            if speaker is not None {
                speaker.requests += 1;
            }
            if self.world is not None {
                teleport_flash(self.world, destination.origin);
            }
            # Whoever already stands at the destination is telefragged.
            world = self.world;
            if world is not None {
                world spawn KillBox(
                    mover=self.player,
                    origin=destination.origin,
                    game=here.game,
                    bystander=self.bystander,
                    bystander_height=self.bystander_height,
                    tally=self.tally
                );
            }
        } else {
            self.player.velocity = here.velocity.scale(1.0);
            # Q3 BG_TouchJumpPad: the boing and the jump grunt once per contact;
            # Q1/Q2 trigger_push_touch: windfly at most every 1.5 seconds.
            if here.game == "q3" and not contact {
                self.cues.append("sound/world/jumppad.wav");
                self.cues.append("sound/player/sarge/jump1.wav");
            } elif here.game != "q3" and here.sound_wait <= 0.0 {
                here.sound_wait = 1.5;
                self.cues.append(
                    "sound/ambience/windfly.wav" if here.game == "q1" else "sound/misc/windfly.wav"
                );
            }
        }
        self.player.grounded = False;
        here.activations += 1;
        if here.once {
            here.enabled = False;
        }
    }
}

"""Monsters in teleporters and pushes. Q1 teleport_touch sends any living
monster (unless PLAYER_ONLY) to the destination facing its angle, alert state
kept; a named teleporter works only just after its use, when teleport_use's
force_retouch catches monsters already waiting inside. spawn_tdeath: arriving on
the player kills the monster itself, other monsters there are telefragged.
trigger_push_touch (Q1, Q2) launches monsters and grenades as it does players."""
walker TeleportMonsters {
    has collision: CollisionMap,
        dt: float,
        player: Player | None = None,
        player_height: float = 22.0,
        tally: CombatState | None = None,
        movers: list[Opponent] = [],
        grenades: list[Projectile] = [],
        world: World | None = None,
        arrivals: int = 0,
        launches: int = 0;

    can begin with World entry {
        if self.dt <= 0.0 {
            return;
        }
        self.world = here;
        for actor in [here->:HasOpponent:->][?:Opponent] {
            actor.teleport_cooldown = max(0.0, actor.teleport_cooldown - self.dt);
            if actor.health > 0
                and not actor.dormant
                and not actor.arena
                and not actor.rule.inert
                and not actor.rule.decoration
                and not actor.rule.script {
                self.movers.append(actor);
            }
        }
        self.grenades = [
            shot for shot in [here->:HasProjectile:->][?:Projectile] if shot.gravity
        ];
        if self.movers or self.grenades {
            visit [
                item
                for item in [here->:HasTraversal:->][?:Traversal]
                if item.monsters and item.enabled and (not item.gated or item.window > 0.0)
            ];
        }
    }

    # Where each monster stands now starts its next sweep.
    can settle with World exit {
        for actor in [here->:HasOpponent:->][?:Opponent] {
            actor.touch_origin = actor.pos.sub(Vec3(z=actor.eye_height));
        }
    }

    can touch with Traversal entry {
        if here.kind == "push" {
            for actor in self.movers {
                if monster_touches(here.volume, actor) {
                    actor.velocity = here.velocity.scale(1.0);
                    actor.grounded = False;
                    self.launches += 1;
                }
            }
            for shot in self.grenades {
                if touches_volume(here.volume, shot.pos, 1.0, 1.0) {
                    shot.velocity = here.velocity.scale(1.0);
                    self.launches += 1;
                }
            }
            if here.once and self.launches > 0 {
                here.enabled = False;
            }
            return;
        }
        if here.kind != "teleport" {
            return;
        }
        destinations = [here->:ArrivesAt:->][?:Destination];
        if len(destinations) != 1 {
            return;
        }
        destination = destinations[0];
        for actor in self.movers {
            if actor.health <= 0 or actor.teleport_cooldown > 0.0 {
                continue;
            }
            if not monster_touches(here.volume, actor) {
                continue;
            }
            self.arrive(actor, destination);
        }
    }

    def arrive(actor: Opponent, destination: Destination) {
        world = self.world;
        if world is None {
            return;
        }
        actor.pos = destination.origin.add(Vec3(z=actor.eye_height));
        actor.yaw = destination.yaw;
        actor.velocity = Vec3();
        actor.grounded = False;
        actor.teleport_cooldown = 0.2;
        actor.route = [];
        actor.route_wait = 0.0;
        self.arrivals += 1;
        speaker = destination.speaker;
        if speaker is not None {
            speaker.requests += 1;
        }
        teleport_flash(world, destination.origin);
        # tdeath_touch: a monster teleporting onto the player explodes itself.
        person = self.player;
        if person is not None and person.health > 0 {
            body = person.pos.sub(Vec3(z=self.player_height));
            if abs(body.x - destination.origin.x) < 33.0
                and abs(body.y - destination.origin.y) < 33.0
                and abs(body.z - destination.origin.z) < 57.0 {
                damage_opponent(
                    actor, 50000, bypass_armor=True, means="telefrag", tally=self.tally
                );
                return;
            }
        }
        world spawn KillBox(
            mover=actor, origin=destination.origin, game="q1", tally=self.tally
        );
    }
}

def entity_origin(entity: MapEntity) -> Vec3 {
    coords = entity.fields.get("origin", "0 0 0").split();
    if len(coords) != 3 {
        raise ValueError("Invalid traversal origin");
    }
    return Vec3(x=float(coords[0]), y=float(coords[1]), z=float(coords[2]));
}

def load_traversal(world: World, bsp: Bsp) {
    volumes = build_collision(bsp, triggers=True)
        if bsp.game == "q1"
        else build_brush_collision(bsp, triggers=True);
    for entity_index in range(len(bsp.entities)) {
        entity = bsp.entities[entity_index];
        fields = entity.fields;
        kind = fields.get("classname", "");
        point_pad = bsp.game == "q2" and kind == "misc_teleporter";
        if not point_pad and kind not in ["trigger_teleport", "trigger_push"] {
            continue;
        }
        flags = int(fields.get("spawnflags", "0"));
        allowed = 3840 if bsp.game == "q1" else (7936 if bsp.game == "q2" else 0);
        if bsp.game != "q3" and not point_pad {
            allowed |= 3 if kind == "trigger_teleport" else 1;
        }
        # A teleporter's `delay` only delays its own targets (SUB_UseTargets).
        if flags & ~allowed {
            note_chain(world, entity_index, "traversal spawnflags " + str(flags & ~allowed));
            continue;
        }
        model = 0;
        volume = CollisionMap();
        if point_pad {
            volume.add_box(
                Vec3(x=-8.0, y=-8.0, z=8.0),
                Vec3(x=8.0, y=8.0, z=24.0),
                entity_origin(entity),
                Vec3(x=-16.0, y=-16.0, z=-24.0),
                Vec3(x=16.0, y=16.0, z=32.0)
            );
            volume.reindex();
        } else {
            model_name = fields.get("model", "");
            if not model_name.startswith("*") {
                continue;
            }
            model = int(model_name[1:]);
            if model <= 0 or model >= len(bsp.models) {
                raise ValueError("Invalid traversal model");
            }
            volume = trigger_volume(volumes, model);
        }
        if not volume.hulls {
            note_chain(world, entity_index, "traversal without a trigger volume");
            continue;
        }
        target = fields.get("target", "");
        targets = [
            item
            for item in bsp.entities
            if target and item.fields.get("targetname", "") == target
        ];
        traversal = Traversal(
            game=bsp.game,
            volume=volume,
            kind="teleport" if kind == "trigger_teleport" or point_pad else "push",
            activation=Signal(entities=[entity_index]),
            gated=bsp.game == "q1"
                and kind == "trigger_teleport"
                and bool(fields.get("targetname", "")),
            # Q1 teleporters take monsters unless PLAYER_ONLY; Q1/Q2 pushes take
            # anything alive. Q2 teleporter_touch and Q3 are players-only here.
            monsters=(bsp.game == "q1" and kind == "trigger_teleport" and flags & 1 == 0)
                or (bsp.game in ["q1", "q2"] and kind == "trigger_push")
        );
        world +>:HasSignal:+> traversal.activation;
        if kind == "trigger_teleport" or point_pad {
            if (bsp.game == "q2" and not point_pad) or len(targets) != 1 {
                note_chain(world, entity_index, "teleporter without one destination");
                continue;
            }
            destination = targets[0];
            if destination.fields.get("classname", "") == "misc_teleporttrain" {
                train_index = -1;
                for i in range(len(bsp.entities)) {
                    if bsp.entities[i] is destination {
                        train_index = i;
                    }
                }
                train = teleport_train_at(world, train_index);
                if train is None {
                    continue;
                }
                traversal.kind = "teleport_train";
                traversal +>:FollowsTrain:+> train;
                world +>:HasTraversal:+> traversal;
                continue;
            }
            supported = ["info_teleport_destination"]
                if bsp.game == "q1"
                else ["target_position", "misc_teleporter_dest", "info_notnull"];
            if point_pad {
                supported = ["misc_teleporter_dest"];
            }
            if destination.fields.get("classname", "") not in supported {
                note_chain(
                    world,
                    entity_index,
                    "teleport destination " + destination.fields.get("classname", "")
                );
                continue;
            }
            angles = destination.fields.get(
                "angles", "0 " + destination.fields.get("angle", "0") + " 0"
            ).split();
            if len(angles) != 3 {
                raise ValueError("Invalid teleport angles");
            }
            point = Destination(
                origin=entity_origin(destination).add(
                    Vec3(z=27.0 if bsp.game == "q1" else (10.0 if point_pad else 1.0))
                ),
                exit_speed=0.0 if point_pad else (400.0 if bsp.game == "q3" else 300.0),
                hold_time=0.16 if point_pad else 0.0,
                yaw=float(angles[1]) * math.pi / 180.0,
                pitch=-float(angles[0]) * math.pi / 180.0
            );
            # Q1 play_teleport: one of five r_tele sounds at the arrival.
            if bsp.game == "q1" {
                point.speaker = Speaker(
                    path="sound/misc/r_tele" + str(1 + entity_index % 5) + ".wav",
                    origin=point.origin
                );
                world +>:HasSpeaker:+> point.speaker;
            }
            traversal +>:ArrivesAt:+> point;
        } elif bsp.game == "q3" {
            if len(targets) != 1 {
                continue;
            }
            model_data = bsp.models[model];
            center = model_data.mins.add(model_data.maxs).scale(0.5).add(
                entity_origin(entity)
            );
            delta = entity_origin(targets[0]).sub(center);
            if delta.z <= 0.0 {
                continue;
            }
            duration = math.sqrt(delta.z / 400.0);
            traversal.velocity = Vec3(
                x=delta.x / duration, y=delta.y / duration, z=800.0 * duration
            );
        } else {
            if target {
                continue;
            }
            speed = float(fields.get("speed", "0"));
            if speed == 0.0 {
                speed = 1000.0;
            }
            if speed < 0.0 {
                continue;
            }
            traversal.velocity = door_direction(entity).scale(speed * 10.0);
            traversal.once = bool(flags & 1);
        }
        world +>:HasTraversal:+> traversal;
    }
}
