"""Authored path graphs and translating train movers shared by the Quake games."""
import from .doors { Door, HasDoor, DoorMember, damage_mover }
import from .world { World, Player }
import from .combat { Opponent, HasOpponent, damage_opponent }
import from .signals { Signal, HasSignal, Fire }
import from .damage { Damage }
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap, Sweep }
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
        activation: Signal = Signal();
}

edge TrackNext: TrackPoint --> TrackPoint {}
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
        origins: list[Vec3] = [];
}

def train_position(train: Train, motion: Vec3, bsp: Bsp, collision: CollisionMap) {
    train.motion = motion;
    for face in train.faces {
        bsp.faces[face].motion = motion;
    }
    for i in range(len(train.hulls)) {
        collision.offsets[train.hulls[i]] = train.origins[i].add(motion);
    }
}

def load_trains(world: World, bsp: Bsp, collision: CollisionMap) {
    points: dict[str, TrackPoint] = {};
    for i in range(len(bsp.entities)) {
        f = bsp.entities[i].fields;
        if f.get("classname", "") != "path_corner" or not f.get("targetname", "") {
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
            teleport=bsp.game == "q2" and int(f.get("spawnflags", "0")) & 1 != 0,
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
        parts = f.get("origin", "0 0 0").split();
        if len(parts) != 3 {
            raise ValueError("Invalid train origin");
        }
        original = Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
        flags = int(f.get("spawnflags", "0"));
        speed = float(f.get("speed", "0"));
        if speed <= 0.0 {
            speed = 100.0;
        }
        train = Train(
            model=model,
            game=bsp.game,
            current=points[target],
            speed=speed,
            anchor=original if bsp.game == "q3" else record.mins.add(original),
            running=bsp.game == "q3"
                or not f.get("targetname", "")
                or (bsp.game == "q2" and flags & 1 != 0),
            toggle=bsp.game == "q2" and flags & 2 != 0,
            damage=0
                if bsp.game != "q1" and flags & 4
                else int(f.get("dmg", "100" if bsp.game == "q2" else "2")),
            activation=Signal(entities=[i]),
            faces=list(range(record.first_face, record.first_face + record.face_count))
        );
        attach_train(world, bsp, collision, train);
    }
    collision.reindex();
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

# Validate all affected actors before committing any mover or actor transform.
def move_train(
    train: Train, motion: Vec3, bsp: Bsp, collision: CollisionMap, actors: list[Player]
) -> bool {
    delta = motion.sub(train.motion);
    carried: list[Player] = [];
    for actor in actors {
        if actor.health <= 0 {
            continue;
        }
        height = actor.eye_height
            if isinstance(actor, Opponent)
            else collision.eye_height;
        origin = actor.pos.sub(Vec3(z=height));
        rider = False;
        intersects = False;
        for i in range(len(train.hulls)) {
            index = train.hulls[i];
            local = origin.sub(collision.offsets[index]);
            support = collision.hulls[index] spawn Sweep(
                start=local,
                finish=local.add(Vec3(z=-0.25)),
                top_drop=collision.top_drop if actor.crouched else 0.0
            );
            if actor.velocity.z <= 0.0
                and not support.result.start_solid
                and support.result.fraction < 1.0
                and support.result.normal.z >= 0.7 {
                rider = True;
            }
            hit = collision.hulls[index] spawn Sweep(
                start=local,
                finish=local.sub(delta),
                top_drop=collision.top_drop if actor.crouched else 0.0
            );
            if hit.result.start_solid or hit.result.fraction < 1.0 {
                intersects = True;
            }
        }
        if not rider and not intersects {
            continue;
        }
        path = collision.trace(
            origin,
            origin.add(delta),
            exclude=train.hulls,
            top_drop=collision.top_drop if actor.crouched else 0.0
        );
        if path.start_solid or path.fraction < 1.0 {
            if train.damage > 0 and train.damage_wait <= 0.0 {
                if isinstance(actor, Opponent) {
                    damage_opponent(actor, train.damage);
                } else {
                    actor spawn Damage(amount=train.damage);
                }
                train.damage_wait = 0.5;
            }
            return False;
        }
        carried.append(actor);
    }
    train_position(train, motion, bsp, collision);
    for actor in carried {
        actor.pos = actor.pos.add(delta);
    }
    return True;
}

walker TrainTick {
    has bsp: Bsp,
        collision: CollisionMap,
        dt: float,
        player: Player | None = None,
        actors: list[Player] = [];

    can begin with World entry {
        if self.dt <= 0.0 {
            return;
        }
        if self.player is not None {
            self.actors.append(self.player);
        }
        for enemy in [here->:HasOpponent:->][?:Opponent] {
            if not enemy.dormant {
                self.actors.append(enemy);
            }
        }
        visit [here->:HasTrain:->];
    }

    can advance with Train entry {
        here.damage_wait = max(0.0, here.damage_wait - self.dt);
        if here.activation.pending > 0 {
            if not here.running
                and (here.game != "q1" or not here.started)
                and (here.kind != "secret" or here.motion.length() < 0.00001) {
                here.running = True;
                here.remaining = 0.0;
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
        if not move_train(here, motion, self.bsp, self.collision, self.actors) {
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
