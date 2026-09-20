"""Shared translating proximity doors. Unsupported activation stays static."""
import math;
import from .world { World, Player }
import from .signals { Signal, Fire, Targets, HasSignal }
import from ..formats.bsp { Bsp, MapEntity }
import from ..physics.collision { CollisionMap, Sweep }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

edge HasDoor {}
edge DoorLink {}
edge DoorMember {}

walker AssembleDoors {
    has members: list[Door] = [],
        ids: list[int] = [];

    can collect with Door entry {
        if here.model in self.ids {
            return;
        }
        self.ids.append(here.model);
        self.members.append(here);
        visit [here->:DoorLink:->];
    }
}

node Door {
    has model: int,
        trigger: AABB,
        travel: Vec3,
        speed: float,
        hold_time: float,
        kind: str = "door",
        rest: Vec3 = Vec3(),
        activation: Signal = Signal(),
        automatic: bool = True,
        requested: bool = False,
        names: list[str] = [],
        enabled: bool = True,
        team: str = "",
        linkable: bool = True,
        bounds: AABB = AABB(mins=Vec3(), maxs=Vec3()),
        faces: list[int] = [],
        hulls: list[int] = [],
        origins: list[Vec3] = [],
        position: float = 0.0,
        state: str = "closed",
        remaining: float = 0.0;
}

walker DoorTick {
    has bsp: Bsp,
        collision: CollisionMap,
        player_origin: Vec3,
        dt: float,
        touching: bool = True,
        player: Player | None = None;

    can start with World entry {
        if self.dt > 0.0 {
            visit [here->:HasDoor:->];
        }
    }

    can advance with Door entry {
        if self.dt <= 0.0 or not here.enabled {
            return;
        }
        origin = self.player_origin;
        if self.player is not None {
            origin = self.player.pos.sub(Vec3(z=self.collision.eye_height));
        }
        rider = False;
        if here.kind == "platform"
            and self.player is not None
            and self.player.velocity.z <= 0.0 {
            for index in here.hulls {
                local = origin.sub(self.collision.offsets[index]);
                support = self.collision.hulls[index] spawn Sweep(
                    top_drop=self.collision.top_drop,
                    start=local,
                    finish=local.add(Vec3(z=-0.25))
                );
                if not support.result.start_solid
                    and support.result.fraction < 1.0
                    and support.result.normal.z >= 0.7 {
                    rider = True;
                }
            }
        }
        contact = here.automatic and here.trigger.contains(origin);
        if here.kind == "platform" {
            contact = self.touching and (contact or (rider and here.state == "open"));
            if here.state == "closing" {
                contact = False;
            }
        }
        if here.kind == "button" {
            contact = False;
            if self.touching and here.automatic {
                for index in here.hulls {
                    for delta in [
                        Vec3(x=0.125),
                        Vec3(x=-0.125),
                        Vec3(y=0.125),
                        Vec3(y=-0.125),
                        Vec3(z=0.125),
                        Vec3(z=-0.125)
                    ] {
                        local = origin.sub(self.collision.offsets[index]);
                        probe = self.collision.hulls[index] spawn Sweep(
                            top_drop=self.collision.top_drop,
                            start=local,
                            finish=local.add(delta)
                        );
                        if probe.result.start_solid or probe.result.fraction < 1.0 {
                            contact = True;
                        }
                    }
                }
            }
        }
        near = here.requested or here.activation.pending > 0 or contact;
        here.requested = False;
        here.activation.pending = 0;
        if here.state == "locked" {
            if not near {
                return;
            }
            here.state = "closing";
            here.automatic = True;
            near = False;
        }
        if here.kind == "button" and here.state == "open" {
            near = False;
        }
        if near {
            if here.state == "closed" or here.state == "closing" {
                here.state = "opening";
            }
            here.remaining = here.hold_time;
        }
        if here.state == "open" {
            if not near and here.hold_time >= 0.0 {
                here.remaining -= self.dt;
                if here.remaining <= 0.0 {
                    here.state = "closing";
                }
            }
            return;
        }
        if here.state == "closed" {
            return;
        }
        direction = 1.0 if here.state == "opening" else -1.0;
        next_position = max(
            0.0,
            min(
                1.0,
                here.position + direction * here.speed * self.dt / here.travel.length()
            )
        );
        members = [here];
        members.extend([here->:DoorMember:->][?:Door]);
        carried = origin;
        if rider {
            carried = origin.add(here.travel.scale(next_position - here.position));
            path = self.collision.trace(origin, carried, exclude=here.hulls);
            if path.start_solid or path.fraction < 1.0 {
                here.state = "closing" if here.state == "opening" else "opening";
                return;
            }
        }
        # Validate the whole group before changing any render or collision state.
        for part in members {
            old_motion = part.rest.add(part.travel.scale(here.position));
            motion = part.rest.add(part.travel.scale(next_position));
            for j in range(len(part.hulls)) {
                index = part.hulls[j];
                query = self.collision.hulls[index] spawn Sweep(
                    top_drop=self.collision.top_drop,
                    start=origin.sub(part.origins[j].add(old_motion)),
                    finish=carried.sub(part.origins[j].add(motion))
                );
                if query.result.start_solid or query.result.fraction < 1.0 {
                    if here.kind == "platform" and here.state == "opening" {
                        here.state = "closing";
                    } elif here.state == "closing" {
                        here.state = "opening";
                    }
                    return;
                }
            }
        }
        for part in members {
            motion = part.rest.add(part.travel.scale(next_position));
            part.position = next_position;
            for face in part.faces {
                self.bsp.faces[face].motion = motion;
            }
            for j in range(len(part.hulls)) {
                self.collision.offsets[part.hulls[j]] = part.origins[j].add(motion);
            }
        }
        if rider and self.player is not None {
            self.player.pos = carried.add(Vec3(z=self.collision.eye_height));
            self.player.grounded = True;
        }
        if next_position == 1.0 {
            here.state = "open";
            here.remaining = here.hold_time;
            here.activation spawn Fire();
        } elif next_position == 0.0 {
            here.state = "closed";
        }
    }
}

def model_bounds(bsp: Bsp, model: int) -> AABB {
    record = bsp.models[model];
    lo = Vec3(x=1.0e30, y=1.0e30, z=1.0e30);
    hi = Vec3(x=-1.0e30, y=-1.0e30, z=-1.0e30);
    for i in range(record.first_face, record.first_face + record.face_count) {
        for v in bsp.faces[i].vertices {
            lo = Vec3(x=min(lo.x, v.x), y=min(lo.y, v.y), z=min(lo.z, v.z));
            hi = Vec3(x=max(hi.x, v.x), y=max(hi.y, v.y), z=max(hi.z, v.z));
        }
    }
    return AABB(mins=lo, maxs=hi);
}

def overlaps(a: AABB, b: AABB) -> bool {
    return a.mins.x <= b.maxs.x
        and a.maxs.x >= b.mins.x
        and a.mins.y <= b.maxs.y
        and a.maxs.y >= b.mins.y
        and a.mins.z <= b.maxs.z
        and a.maxs.z >= b.mins.z;
}

def door_direction(entity: MapEntity) -> Vec3 {
    yaw = float(entity.fields.get("angle", "0"));
    pitch = 0.0;
    if entity.fields.get("angles", "") {
        angles = entity.fields["angles"].split();
        if len(angles) != 3 {
            raise ValueError("Invalid door angles");
        }
        pitch = float(angles[0]);
        yaw = float(angles[1]);
    }
    if yaw == -1.0 {
        return Vec3(z=1.0);
    }
    if yaw == -2.0 {
        return Vec3(z=-1.0);
    }
    yaw *= math.pi / 180.0;
    pitch *= math.pi / 180.0;
    return Vec3(
        x=math.cos(pitch) * math.cos(yaw),
        y=math.cos(pitch) * math.sin(yaw),
        z=-math.sin(pitch)
    );
}

def load_doors(world: World, bsp: Bsp, collision: CollisionMap) {
    candidates: list[Door] = [];
    for entity in bsp.entities {
        fields = entity.fields;
        kind = fields.get("classname", "");
        if kind not in ["func_door", "func_button", "func_plat"] {
            continue;
        }
        # Keep unsupported members in the graph so a locked half disables its group.
        flags = int(fields.get("spawnflags", "0"));
        allowed = 3840 if bsp.game == "q1" else (7936 if bsp.game == "q2" else 0);
        if kind == "func_plat" and bsp.game != "q3" {
            allowed |= 1;
        }
        enabled = True;
        if flags & ~allowed
            or float(fields.get("health", "0")) != 0.0
            or float(fields.get("delay", "0")) != 0.0
            or fields.get("killtarget", "")
            or fields.get("accel", "")
            or fields.get("decel", "") {
            enabled = False;
        }
        name = fields.get("model", "");
        if not name.startswith("*") {
            continue;
        }
        model = int(name[1:]);
        if model <= 0 or model >= len(bsp.models) {
            raise ValueError("Invalid door model");
        }
        bounds = model_bounds(bsp, model);
        direction = door_direction(entity);
        size = bounds.size();
        lip = float(fields.get("lip", "4" if kind == "func_button" else "8"));
        if lip == 0.0 and bsp.game != "q3" {
            lip = 4.0 if kind == "func_button" else 8.0;
        }
        distance = abs(direction.x) * size.x
            + abs(direction.y) * size.y
            + abs(direction.z) * size.z
            - lip;
        if kind == "func_plat" {
            direction = Vec3(z=1.0);
            distance = float(fields.get("height", "0"));
            if distance == 0.0 {
                distance = size.z - lip;
            }
        }
        speed = float(fields.get("speed", "0"));
        hold_time = float(fields.get("wait", "0"));
        if speed == 0.0 {
            speed = 40.0
                if kind == "func_button"
                else (400.0 if bsp.game == "q3" else 100.0);
        }
        if hold_time == 0.0 {
            hold_time = 1.0
                if kind == "func_button"
                else (2.0 if bsp.game == "q3" else 3.0);
        }
        if kind == "func_plat" {
            if float(fields.get("speed", "0")) == 0.0 {
                speed = 150.0 if bsp.game == "q1" else 200.0;
            }
            hold_time = 1.0 if bsp.game == "q3" else 3.0;
        }
        if distance <= 0.0 or speed <= 0.0 {
            enabled = False;
        }
        # Expand the proximity volume by the standing player extents as well.
        margin = Vec3(x=76.0, y=76.0, z=8.0);
        if kind == "func_button" {
            width = 15.0 if bsp.game == "q3" else 16.0;
            margin = Vec3(x=width + 0.125, y=width + 0.125, z=0.125);
        }
        door = Door(
            model=model,
            kind="platform"
                if kind == "func_plat"
                else ("button" if kind == "func_button" else "door"),
            rest=Vec3(z=-distance) if kind == "func_plat" else Vec3(),
            enabled=enabled,
            automatic=kind == "func_button" or not bool(fields.get("targetname", "")),
            names=[fields["targetname"]] if fields.get("targetname", "") else [],
            team=fields.get("team", ""),
            linkable=flags & 4 == 0,
            bounds=bounds,
            travel=direction.scale(distance),
            speed=speed,
            hold_time=hold_time,
            trigger=AABB(
                mins=bounds.mins.sub(margin).sub(Vec3(z=32.0)),
                maxs=bounds.maxs.add(margin).add(Vec3(z=24.0))
            )
        );
        if kind == "func_plat" {
            inset = 33.0 if bsp.game == "q3" else 25.0;
            lo = bounds.mins.add(Vec3(x=inset, y=inset));
            hi = bounds.maxs.sub(Vec3(x=inset, y=inset));
            if lo.x >= hi.x {
                lo.x = bounds.center().x;
                hi.x = lo.x + 1.0;
            }
            if lo.y >= hi.y {
                lo.y = bounds.center().y;
                hi.y = lo.y + 1.0;
            }
            lo.z = bounds.maxs.z - distance;
            hi.z = bounds.maxs.z + 8.0;
            if bsp.game == "q3" {
                lo.z = bounds.mins.z - distance;
                hi.z -= distance;
            }
            if flags & 1 {
                hi.z = lo.z + 8.0;
            }
            width = 15.0 if bsp.game == "q3" else 16.0;
            door.trigger = AABB(
                mins=lo.sub(Vec3(x=width, y=width, z=32.0)),
                maxs=hi.add(Vec3(x=width, y=width, z=24.0))
            );
            if not door.automatic and bsp.game != "q3" {
                door.position = 1.0;
                door.state = "locked";
            }
        }
        record = bsp.models[model];
        door.faces = list(
            range(record.first_face, record.first_face + record.face_count)
        );
        for i in range(len(collision.models)) {
            if collision.models[i] != model {
                continue;
            }
            door.hulls.append(i);
            door.origins.append(collision.offsets[i]);
        }
        door.enabled = door.enabled and bool(door.hulls);
        candidates.append(door);
    }
    for i in range(len(candidates)) {
        first = candidates[i];
        for j in range(i + 1, len(candidates)) {
            second = candidates[j];
            linked = first.kind == "door"
                and second.kind == "door"
                and (
                    first.linkable
                    and second.linkable
                    and overlaps(first.bounds, second.bounds)
                )
                if bsp.game == "q1"
                else (
                    first.kind == "door"
                    and second.kind == "door"
                    and bool(first.team)
                    and first.team == second.team
                );
            if linked {
                first +>:DoorLink:+> second;
                second +>:DoorLink:+> first;
            }
        }
    }
    grouped: list[int] = [];
    for leader in candidates {
        if leader.model in grouped {
            continue;
        }
        assembly = leader spawn AssembleDoors();
        grouped.extend(assembly.ids);
        enabled = True;
        duration = 0.0;
        bounds = leader.trigger;
        for part in assembly.members {
            enabled = enabled and part.enabled;
            if part.speed > 0.0 {
                duration = max(duration, part.travel.length() / part.speed);
            }
            bounds = union_bounds(bounds, part.trigger);
            # A team containing another mover class cannot be animated partially.
            if part.team and bsp.game != "q1" {
                for ent in bsp.entities {
                    if ent.fields.get("team", "") == part.team
                        and ent.fields.get("classname", "") != "func_door" {
                        enabled = False;
                    }
                }
            }
        }
        if not enabled or duration <= 0.0 {
            continue;
        }
        for part in assembly.members {
            leader.automatic = leader.automatic and part.automatic;
            for name in part.names {
                if name not in leader.names {
                    leader.names.append(name);
                }
            }
        }
        leader.trigger = bounds;
        leader.speed = leader.travel.length() / duration;
        for part in assembly.members {
            for index in part.hulls {
                if len(collision.bounds) == len(collision.hulls) {
                    b = collision.bounds[index];
                    delta = part.travel;
                    collision.bounds[index] = AABB(
                        mins=b.mins.add(
                            Vec3(
                                x=min(part.rest.x, part.rest.x + delta.x),
                                y=min(part.rest.y, part.rest.y + delta.y),
                                z=min(part.rest.z, part.rest.z + delta.z)
                            )
                        ),
                        maxs=b.maxs.add(
                            Vec3(
                                x=max(part.rest.x, part.rest.x + delta.x),
                                y=max(part.rest.y, part.rest.y + delta.y),
                                z=max(part.rest.z, part.rest.z + delta.z)
                            )
                        )
                    );
                }
            }
            if part.model != leader.model {
                leader +>:DoorMember:+> part;
            }
        }
        world +>:HasDoor:+> leader;
    }
    collision.reindex();
    connect_targets(world, bsp);
    for mover in [world->:HasDoor:->][?:Door] {
        if mover.enabled and mover.kind == "platform" {
            motion = mover.rest.add(mover.travel.scale(mover.position));
            for face in mover.faces {
                bsp.faces[face].motion = motion;
            }
            for j in range(len(mover.hulls)) {
                collision.offsets[mover.hulls[j]] = mover.origins[j].add(motion);
            }
        }
    }
}


def union_bounds(a: AABB, b: AABB) -> AABB {
    return AABB(
        mins=Vec3(
            x=min(a.mins.x, b.mins.x),
            y=min(a.mins.y, b.mins.y),
            z=min(a.mins.z, b.mins.z)
        ),
        maxs=Vec3(
            x=max(a.maxs.x, b.maxs.x),
            y=max(a.maxs.y, b.maxs.y),
            z=max(a.maxs.z, b.maxs.z)
        )
    );
}


def connect_targets(world: World, bsp: Bsp) {
    signals: list[Signal] = [world->:HasSignal:->][?:Signal];
    leaders = [world->:HasDoor:->][?:Door];
    for leader in leaders {
        members = [leader];
        members.extend([leader->:DoorMember:->][?:Door]);
        for part in members {
            part.activation = leader.activation;
            for index in range(len(bsp.entities)) {
                fields = bsp.entities[index].fields;
                if fields.get("model", "") == "*" + str(part.model) {
                    leader.activation.entities.append(index);
                }
            }
        }
        signals.append(leader.activation);
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        if fields.get("classname", "") in ["trigger_relay", "target_relay"]
            and int(fields.get("spawnflags", "0")) == 0
            and float(fields.get("delay", "0")) == 0.0
            and not fields.get("killtarget", "") {
            signals.append(Signal(relay=True, entities=[index]));
        }
    }
    registered = [world->:HasSignal:->][?:Signal];
    for signal in signals {
        if signal not in registered {
            world +>:HasSignal:+> signal;
        }
    }
    # Resolve every recipient, then propagate unsupported downstream fan-outs.
    for signal in signals {
        for index in signal.entities {
            target = bsp.entities[index].fields.get("target", "");
            if not target {
                continue;
            }
            found = False;
            for recipient in range(len(bsp.entities)) {
                if bsp.entities[recipient].fields.get("targetname", "") != target {
                    continue;
                }
                found = True;
                resolved = False;
                for destination in signals {
                    if recipient in destination.entities {
                        signal +>:Targets:+> destination;
                        resolved = True;
                        break;
                    }
                }
                if not resolved {
                    signal.enabled = False;
                }
            }
            if not found {
                signal.enabled = False;
            }
        }
    }
    for iteration in range(len(signals)) {
        changed = False;
        for signal in signals {
            for destination in [signal->:Targets:->][?:Signal] {
                if signal.enabled and not destination.enabled {
                    signal.enabled = False;
                    changed = True;
                }
            }
        }
        if not changed {
            break;
        }
    }
    for leader in leaders {
        leader.enabled = leader.enabled and leader.activation.enabled;
    }
}


def resolve_targets(world: World, bsp: Bsp, target: str) -> list[Signal] {
    result: list[Signal] = [];
    signals = [world->:HasSignal:->][?:Signal];
    for index in range(len(bsp.entities)) {
        if bsp.entities[index].fields.get("targetname", "") != target {
            continue;
        }
        found = False;
        for signal in signals {
            if signal.enabled and index in signal.entities {
                result.append(signal);
                found = True;
                break;
            }
        }
        if not found {
            return [];
        }
    }
    return result;
}
