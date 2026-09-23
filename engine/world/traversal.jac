"""Shared swept-contact traversal, with map-defined destinations and launches."""
import math;
import from .world { World, Player }
import from .damage { Damage }
import from .finale { TeleportTrain, teleport_train_at, telefrag }
import from .triggers { trigger_volume }
import from .doors { door_direction }
import from .signals { Signal, HasSignal }
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
        hold_time: float = 0.0;
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
        window: float = 0.0;
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
        world: World | None = None;

    can begin with World entry {
        if self.dt <= 0.0 or not self.touching {
            return;
        }
        self.world = here;
        self.player.teleport_cooldown = max(
            0.0, self.player.teleport_cooldown - self.dt
        );
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
        } else {
            self.player.velocity = here.velocity.scale(1.0);
        }
        self.player.grounded = False;
        here.activations += 1;
        if here.once {
            here.enabled = False;
        }
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
        if flags & ~allowed or float(fields.get("delay", "0")) != 0.0 {
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
            continue;
        }
        target = fields.get("target", "");
        targets = [
            item
            for item in bsp.entities
            if target and item.fields.get("targetname", "") == target
        ];
        traversal = Traversal(
            volume=volume,
            kind="teleport" if kind == "trigger_teleport" or point_pad else "push",
            activation=Signal(entities=[entity_index]),
            gated=bsp.game == "q1"
                and kind == "trigger_teleport"
                and bool(fields.get("targetname", ""))
        );
        world +>:HasSignal:+> traversal.activation;
        if kind == "trigger_teleport" or point_pad {
            if (bsp.game == "q2" and not point_pad) or len(targets) != 1 {
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
