"""Authored path graphs and translating train movers shared by the Quake games."""
import from .doors { Door, HasDoor, DoorMember, damage_mover, mover_voices, mover_voice }
import from .speakers { Speaker }
import from .world { World, Player }
import from .combat { Opponent, HasOpponent, damage_opponent }
import from .signals { Signal, HasSignal, Fire, note_chain }
import from .damage { Damage, blast_strength }
import from ..formats.bsp { Bsp, model_bounds, mover_origin }
import from ..physics.collision { CollisionMap }
import from .pickups { Pickup }
import from .pusher { Pushable, HullStep, GatherPushables, push_move, clear_item }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

node TrackPoint {
    has entity: int,
        name: str,
        origin: Vec3,
        hold_time: float = 0.0,
        speed: float = 0.0,
        teleport: bool = False,
        stop: bool = False,
        combat: bool = False,
        activation: Signal = Signal();
}

edge TrackNext: TrackPoint --> TrackPoint {}
edge HasElevator: World --> Elevator {}
edge Lifts: Elevator --> Train {}

"""Q2 trigger_elevator: a use from a caller with a `pathtarget` sends the idle
train straight to that path corner (trigger_elevator_use, train_resume)."""
node Elevator {
    has activation: Signal = Signal();
}
edge HasTrack: World --> TrackPoint {}
edge HasTrain: World --> Train {}
walker TrainRoute {
    has points: list[TrackPoint] = [],
        seen: list[int] = [];

    can follow with TrackPoint entry {
        if here.entity in self.seen {
            return;
        }
        self.seen.append(here.entity);
        self.points.append(here);
        visit [here->:TrackNext:->];
    }
}

node Train {
    has model: int,
        game: str,
        anchor: Vec3,
        current: TrackPoint,
        kind: str = "train",
        shootable: bool = False,
        destination: TrackPoint | None = None,
        motion: Vec3 = Vec3(),
        speed: float = 100.0,
        running: bool = True,
        toggle: bool = False,
        started: bool = False,
        remaining: float = 0.1,
        damage: int = 2,
        damage_wait: float = 0.0,
        activation: Signal = Signal(),
        faces: list[int] = [],
        hulls: list[int] = [],
        origins: list[Vec3] = [],
        extents: list[AABB] = [],
        bounds: AABB = AABB(mins=Vec3(), maxs=Vec3()),
        touch_message: str = "",
        message_wait: float = 0.0,
        start_voice: Speaker | None = None,
        move_voice: Speaker | None = None,
        stop_voice: Speaker | None = None,
        was_moving: bool = False;
}

"""Give a train its start, moving and stop sounds at its brush centre."""
def voice_train(world: World, train: Train, voices: list[str]) {
    centre = train.bounds.center().add(train.motion);
    train.start_voice = mover_voice(world, train.game, voices[0], False, centre);
    train.move_voice = mover_voice(world, train.game, voices[1], True, centre);
    train.stop_voice = mover_voice(world, train.game, voices[2], False, centre);
}

def train_position(train: Train, motion: Vec3, bsp: Bsp, collision: CollisionMap) {
    train.motion = motion;
    for face in train.faces {
        bsp.faces[face].motion = motion;
    }
    for i in range(len(train.hulls)) {
        collision.set_offset(train.hulls[i], train.origins[i].add(motion));
    }
}

def load_trains(world: World, bsp: Bsp, collision: CollisionMap) {
    points: dict[str, TrackPoint] = {};
    for i in range(len(bsp.entities)) {
        f = bsp.entities[i].fields;
        kind = f.get("classname", "");
        # Q2 point_combat chains share the graph; monsters hold at them.
        if kind not in ["path_corner", "point_combat"] or not f.get("targetname", "") {
            continue;
        }
        parts = f.get("origin", "0 0 0").split();
        if len(parts) != 3 {
            raise ValueError("Invalid train path origin");
        }
        point = TrackPoint(
            entity=i,
            name=f["targetname"],
            origin=Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2])),
            hold_time=float(f.get("wait", "0")),
            speed=float(f.get("speed", "0")),
            teleport=kind == "path_corner" and bsp.game == "q2" and int(f.get("spawnflags", "0")) & 1 != 0,
            combat=kind == "point_combat",
            activation=Signal(entities=[i])
        );
        # Authored duplicate names select the first path corner deterministically.
        if point.name not in points {
            points[point.name] = point;
        }
        world +>:HasTrack:+> point;
        world +>:HasSignal:+> point.activation;
    }
    for point in [world->:HasTrack:->][?:TrackPoint] {
        name = bsp.entities[point.entity].fields.get("target", "");
        if name in points {
            point +>:TrackNext:+> points[name];
        }
    }
    for i in range(len(bsp.entities)) {
        f = bsp.entities[i].fields;
        if f.get("classname", "") != "func_train" {
            continue;
        }
        reference = f.get("model", "");
        target = f.get("target", "");
        if not reference.startswith("*") or target not in points {
            continue;
        }
        model = int(reference[1:]);
        if model <= 0 or model >= len(bsp.models) {
            raise ValueError("Invalid train model");
        }
        record = bsp.models[model];
        original = mover_origin(f);
        flags = int(f.get("spawnflags", "0"));
        speed = float(f.get("speed", "0"));
        if speed <= 0.0 {
            speed = 100.0;
        }
        # Q1 train_next / Q2 train_resume put the train's mins (SetModel's
        # spread bounds) at each corner; Q3 its origin.
        placed = model_bounds(bsp, model, original);
        train = Train(
            model=model,
            game=bsp.game,
            current=points[target],
            speed=speed,
            anchor=original if bsp.game == "q3" else placed.mins,
            running=bsp.game == "q3"
                or not f.get("targetname", "")
                or (bsp.game == "q2" and flags & 1 != 0),
            toggle=bsp.game == "q2" and flags & 2 != 0,
            damage=0
                if bsp.game != "q1" and flags & 4
                else int(f.get("dmg", "100" if bsp.game == "q2" else "2")),
            activation=Signal(entities=[i]),
            faces=list(range(record.first_face, record.first_face + record.face_count)),
            bounds=placed
        );
        attach_train(world, bsp, collision, train);
        voice_train(world, train, mover_voices(bsp.game, "func_train", f));
    }
    collision.reindex();
    load_elevators(world, bsp);
}

"""g_func.c trigger_elevator_init: the elevator's target must name a func_train."""
def load_elevators(world: World, bsp: Bsp) {
    if bsp.game != "q2" {
        return;
    }
    trains = [world->:HasTrain:->][?:Train];
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") != "trigger_elevator" {
            continue;
        }
        target = fields.get("target", "");
        lifted: Train | None = None;
        for train in trains {
            if target
                and bsp.entities[train.activation.entities[0]].fields.get("targetname", "")
                    == target {
                lifted = train;
                break;
            }
        }
        if lifted is None {
            note_chain(world, index, "elevator without a func_train " + target);
            continue;
        }
        elevator = Elevator(activation=Signal(entities=[index], routed=True));
        elevator +>:Lifts:+> lifted;
        world +>:HasElevator:+> elevator;
        world +>:HasSignal:+> elevator.activation;
    }
}

def attach_train(world: World, bsp: Bsp, collision: CollisionMap, train: Train) {
    for h in range(len(collision.models)) {
        if collision.models[h] == train.model {
            train.hulls.append(h);
            train.origins.append(collision.offsets[h]);
        }
    }
    # The collision broad phase must cover the entire authored route.
    route = train.current spawn TrainRoute();
    for h in train.hulls {
        if len(collision.bounds) != len(collision.hulls) {
            continue;
        }
        original_bounds = collision.bounds[h];
        # The hull's own reach, relative to its offset, for rider checks.
        train.extents.append(
            AABB(
                mins=original_bounds.mins.sub(collision.offsets[h]),
                maxs=original_bounds.maxs.sub(collision.offsets[h])
            )
        );
        lo = original_bounds.mins;
        hi = original_bounds.maxs;
        for point in route.points {
            offset = point.origin.sub(train.anchor);
            a = original_bounds.mins.add(offset);
            b = original_bounds.maxs.add(offset);
            lo = Vec3(x=min(lo.x, a.x), y=min(lo.y, a.y), z=min(lo.z, a.z));
            hi = Vec3(x=max(hi.x, b.x), y=max(hi.y, b.y), z=max(hi.z, b.z));
        }
        collision.bounds[h] = AABB(mins=lo, maxs=hi);
    }
    train_position(train, train.current.origin.sub(train.anchor), bsp, collision);
    if bsp.game == "q3" {
        train.remaining = max(0.0, train.current.hold_time);
    }
    world +>:HasTrain:+> train;
    world +>:HasSignal:+> train.activation;
}

"""Step a train to `motion`, taking along or pushing everyone in its way
(SV_PushMove, SV_Push, G_MoverPush), or not moving at all. A blocked train
waits; Q1 and Q2 trains and secret doors hurt what blocks them at most every
half second (train_blocked, secret_blocked, door_secret_blocked), and Q2's
clear an item out of the way instead."""
def move_train(
    train: Train,
    motion: Vec3,
    bsp: Bsp,
    collision: CollisionMap,
    bodies: list[Pushable],
    world: World | None = None
) -> bool {
    steps: list[HullStep] = [];
    for i in range(len(train.hulls)) {
        before = train.origins[i].add(train.motion);
        after = train.origins[i].add(motion);
        step = HullStep(index=train.hulls[i], offset_from=before, offset_to=after);
        # The hull's own reach over this step, not its whole route's.
        if len(train.extents) == len(train.hulls) {
            low = Vec3(x=min(before.x, after.x), y=min(before.y, after.y), z=min(before.z, after.z));
            high = Vec3(x=max(before.x, after.x), y=max(before.y, after.y), z=max(before.z, after.z));
            step.bounds = AABB(
                mins=train.extents[i].mins.add(low), maxs=train.extents[i].maxs.add(high)
            );
        }
        steps.append(step);
    }
    obstacle = push_move(collision, steps, bodies, train.game);
    if obstacle is None {
        train_position(train, motion, bsp, collision);
        return True;
    }
    victim = obstacle.entity;
    if isinstance(victim, Pickup) {
        if world is not None and train.game == "q2" {
            clear_item(world, victim, train.game);
        }
        return False;
    }
    if isinstance(victim, Player)
        and train.game != "q3"
        and train.damage > 0
        and train.damage_wait <= 0.0 {
        if isinstance(victim, Opponent) {
            damage_opponent(victim, train.damage);
        } else {
            victim spawn Damage(amount=train.damage);
        }
        train.damage_wait = 0.5;
    }
    return False;
}

walker TrainTick {
    has bsp: Bsp,
        collision: CollisionMap,
        dt: float,
        player: Player | None = None,
        tracks: list[TrackPoint] = [],
        message: str = "",
        cues: list[str] = [],
        world: World | None = None,
        bodies: list[Pushable] = [],
        gathered: bool = False;

    """Everything a train could push this tick, gathered once when needed."""
    def pushables() -> list[Pushable] {
        world = self.world;
        if not self.gathered and world is not None {
            self.gathered = True;
            found = world spawn GatherPushables(
                collision=self.collision, game=self.bsp.game, player=self.player
            );
            self.bodies = found.bodies;
        }
        return self.bodies;
    }

    """Q1 train_next/train_wait and Q2 train_next/train_wait: the moving loop
    runs while the train travels and the stop sound marks each pause. Secret
    doors add their start sound when they leave their closed position."""
    def voice(train: Train) {
        moving = train.running
            and (train.destination is not None or train.remaining <= 0.11);
        centre = train.bounds.center().add(train.motion);
        for speaker in [train.start_voice, train.move_voice, train.stop_voice] {
            if speaker is not None {
                speaker.origin = centre;
            }
        }
        if moving and not train.was_moving {
            start = train.start_voice;
            if start is not None and train.motion.length() < 0.001 {
                start.requests += 1;
            }
            loop = train.move_voice;
            if loop is not None {
                loop.playing = True;
            }
        } elif train.was_moving and not moving {
            loop = train.move_voice;
            if loop is not None {
                loop.playing = False;
            }
            stop = train.stop_voice;
            if stop is not None {
                stop.requests += 1;
            }
        }
        train.was_moving = moving;
    }

    """Q1 secret_touch: a secret door's message to the player touching it,
    every two seconds, until the door is first used."""
    def touch_note(train: Train) {
        person = self.player;
        train.message_wait = max(0.0, train.message_wait - self.dt);
        if not train.touch_message
            or train.message_wait > 0.0
            or person is None
            or person.health <= 0 {
            return;
        }
        origin = person.pos.sub(Vec3(z=self.collision.eye_height));
        lo = train.bounds.mins.add(train.motion);
        hi = train.bounds.maxs.add(train.motion);
        if origin.x + 17.0 >= lo.x and origin.x - 17.0 <= hi.x
            and origin.y + 17.0 >= lo.y and origin.y - 17.0 <= hi.y
            and origin.z + 33.0 >= lo.z and origin.z - 25.0 <= hi.z {
            self.message = train.touch_message;
            self.cues.append("sound/misc/talk.wav");
            train.message_wait = 2.0;
        }
    }

    can begin with World entry {
        if self.dt <= 0.0 {
            return;
        }
        self.world = here;
        self.tracks = [here->:HasTrack:->][?:TrackPoint];
        visit [here->:HasElevator:->];
        visit [here->:HasTrain:->];
    }

    # An idle train answers the latest call whose path corner exists; a busy
    # (moving or waiting) one ignores it, as trigger_elevator_use does.
    can call with Elevator entry {
        calls = here.activation.calls;
        here.activation.calls = [];
        here.activation.pending = 0;
        for train in [here->:Lifts:->][?:Train] {
            if train.running or train.activation.killed {
                continue;
            }
            for name in calls {
                for point in self.tracks {
                    if point.name == name {
                        train.destination = point;
                        train.running = True;
                        train.remaining = 0.0;
                        train.started = True;
                        break;
                    }
                }
                if train.running {
                    break;
                }
            }
        }
    }

    can advance with Train entry {
        here.damage_wait = max(0.0, here.damage_wait - self.dt);
        self.voice(here);
        self.touch_note(here);
        if here.activation.killed {
            if here.faces or here.hulls {
                for face in here.faces {
                    self.bsp.faces[face].hidden = True;
                }
                for index in here.hulls {
                    self.collision.set_disabled(index, True);
                }
                here.faces = [];
                here.hulls = [];
            }
            here.running = False;
            return;
        }
        if here.activation.pending > 0 {
            if not here.running
                and (here.game != "q1" or not here.started)
                and (here.kind != "secret" or here.motion.length() < 0.00001) {
                here.running = True;
                here.remaining = 0.0;
                # fd_secret_use: no more message once the door is used.
                here.touch_message = "";
                if here.kind == "secret" {
                    here.activation spawn Fire(
                        inventory=self.player.inventory
                            if self.player is not None
                            else None
                    );
                }
            } elif here.running and here.toggle {
                here.running = False;
            }
            here.activation.pending = 0;
        }
        if not here.running {
            return;
        }
        if here.game == "q3" and not here.started {
            here.current.activation spawn Fire();
            here.started = True;
        }
        if here.remaining > 0.0 {
            here.remaining = max(0.0, here.remaining - self.dt);
            if here.remaining > 0.0 {
                return;
            }
        }
        if here.destination is None {
            options = [here.current->:TrackNext:->][?:TrackPoint];
            if not options {
                here.running = False;
                return;
            }
            here.destination = options[0];
            here.started = True;
        }
        destination = here.destination;
        if destination is None {
            return;
        }
        goal = destination.origin.sub(here.anchor);
        if destination.teleport {
            train_position(here, goal, self.bsp, self.collision);
            here.current = destination;
            here.destination = None;
            return;
        }
        speed = here.current.speed
            if here.game == "q3" and here.current.speed > 0.0
            else here.speed;
        delta = goal.sub(here.motion);
        distance = delta.length();
        motion = goal
            if distance <= speed * self.dt
            else here.motion.add(delta.scale(speed * self.dt / distance));
        if not move_train(
            here, motion, self.bsp, self.collision, self.pushables(), self.world
        ) {
            return;
        }
        if distance <= speed * self.dt {
            here.current = destination;
            here.destination = None;
            if here.game in ["q2", "q3"] {
                destination.activation spawn Fire(
                    inventory=self.player.inventory if self.player is not None else None
                );
            }
            here.remaining = max(
                0.1 if here.game == "q1" else 0.0, destination.hold_time
            );
            if destination.stop
                or (destination.hold_time < 0.0 and here.game == "q2") {
                here.running = False;
                if here.kind == "secret" and here.motion.length() < 0.00001 {
                    here.started = False;
                }
            }
        }
    }
}

walker ShootMover {
    has model: int,
        amount: int = 1;

    can begin with World entry {
        if self.amount > 0 {
            visit [here->:HasTrain:->];
            visit [here->:HasDoor:->];
        }
    }

    can door with Door entry {
        members = [here];
        members.extend([here->:DoorMember:->][?:Door]);
        for part in members {
            if part.model == self.model {
                damage_mover(here, part, self.amount);
                return;
            }
        }
    }

    can hit with Train entry {
        if here.model == self.model and here.shootable and not here.running {
            here.activation.pending += 1;
        }
    }
}

"""Splash damage to shootable movers: campaign doors, buttons and secret doors."""
walker BlastMover {
    has origin: Vec3,
        amount: int,
        radius: float,
        game: str,
        collision: CollisionMap,
        player: Player,
        energy_burst: bool = False;

    can begin with World entry {
        visit [here->:HasTrain:->];
        visit [here->:HasDoor:->];
    }

    # T_RadiusDamage reaches a shootable secret door like any shot does, and
    # fd_secret_use opens it on the first point of damage it takes.
    can train with Train entry {
        if not here.shootable or here.running or here.activation.killed {
            return;
        }
        center = here.bounds.center().add(here.motion);
        strength = blast_strength(
            self.game,
            self.amount,
            self.radius,
            center.sub(self.origin).length(),
            self.energy_burst
        );
        if strength <= 0.0 {
            return;
        }
        # CanDamage: a pusher is hit when the line to its middle is clear.
        sight = self.collision.trace(
            self.origin, center, exclude=here.hulls, point=True
        );
        if sight.start_solid or sight.fraction < 1.0 {
            return;
        }
        here.activation.pending += 1;
    }

    can hit with Door entry {
        if not here.enabled {
            return;
        }
        members = [here];
        members.extend([here->:DoorMember:->][?:Door]);
        for part in members {
            if part.max_health <= 0
                and not (here.shared_health and here.max_health > 0) {
                continue;
            }
            center = part.bounds.center().add(part.rest).add(
                part.travel.scale(here.position)
            );
            strength = blast_strength(
                self.game,
                self.amount,
                self.radius,
                center.sub(self.origin).length(),
                self.energy_burst
            );
            if strength <= 0.0 {
                continue;
            }
            sight = self.collision.trace(
                self.origin, center, exclude=part.hulls, point=True
            );
            if sight.start_solid or sight.fraction < 1.0 {
                continue;
            }
            if self.energy_burst {
                sight = self.collision.trace(
                    self.player.pos, center, exclude=part.hulls, point=True
                );
                if sight.start_solid or sight.fraction < 1.0 {
                    continue;
                }
            }
            damage_mover(here, part, int(strength));
        }
    }
}
