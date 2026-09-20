"""Shared translating proximity doors. Unsupported activation stays static."""
import math;
import from .world { World }
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
        dt: float;

    can start with World entry {
        if self.dt > 0.0 {
            visit [here->:HasDoor:->];
        }
    }

    can advance with Door entry {
        if self.dt <= 0.0 {
            return;
        }
        near = here.requested
            or (here.automatic and here.trigger.contains(self.player_origin));
        here.requested = False;
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
        # Validate the whole group before changing any render or collision state.
        for part in members {
            old_motion = part.travel.scale(here.position);
            motion = part.travel.scale(next_position);
            for j in range(len(part.hulls)) {
                index = part.hulls[j];
                query = self.collision.hulls[index] spawn Sweep(
                    start=self.player_origin.sub(part.origins[j].add(old_motion)),
                    finish=self.player_origin.sub(part.origins[j].add(motion))
                );
                if query.result.start_solid or query.result.fraction < 1.0 {
                    if here.state == "closing" {
                        here.state = "opening";
                    }
                    return;
                }
            }
        }
        for part in members {
            motion = part.travel.scale(next_position);
            part.position = next_position;
            for face in part.faces {
                self.bsp.faces[face].motion = motion;
            }
            for j in range(len(part.hulls)) {
                self.collision.offsets[part.hulls[j]] = part.origins[j].add(motion);
            }
        }
        if next_position == 1.0 {
            here.state = "open";
            here.remaining = here.hold_time;
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
        if fields.get("classname", "") != "func_door" {
            continue;
        }
        # Keep unsupported members in the graph so a locked half disables its group.
        flags = int(fields.get("spawnflags", "0"));
        allowed = 3840 if bsp.game == "q1" else (7936 if bsp.game == "q2" else 0);
        enabled = True;
        if flags & ~allowed
            or float(fields.get("health", "0")) != 0.0
            or fields.get("target", "")
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
        lip = float(fields.get("lip", "8"));
        if lip == 0.0 and bsp.game != "q3" {
            lip = 8.0;
        }
        distance = abs(direction.x) * size.x
            + abs(direction.y) * size.y
            + abs(direction.z) * size.z
            - lip;
        speed = float(fields.get("speed", "0"));
        hold_time = float(fields.get("wait", "0"));
        if speed == 0.0 {
            speed = 400.0 if bsp.game == "q3" else 100.0;
        }
        if hold_time == 0.0 {
            hold_time = 2.0 if bsp.game == "q3" else 3.0;
        }
        if distance <= 0.0 or speed <= 0.0 {
            enabled = False;
        }
        # Expand the proximity volume by the standing player extents as well.
        margin = Vec3(x=76.0, y=76.0, z=8.0);
        door = Door(
            model=model,
            enabled=enabled,
            automatic=not bool(fields.get("targetname", "")),
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
            linked = (
                first.linkable
                and second.linkable
                and overlaps(first.bounds, second.bounds)
            )
                if bsp.game == "q1"
                else (bool(first.team) and first.team == second.team);
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
                                x=min(0.0, delta.x),
                                y=min(0.0, delta.y),
                                z=min(0.0, delta.z)
                            )
                        ),
                        maxs=b.maxs.add(
                            Vec3(
                                x=max(0.0, delta.x),
                                y=max(0.0, delta.y),
                                z=max(0.0, delta.z)
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
