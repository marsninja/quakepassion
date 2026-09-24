"""Q2 gun turrets (g_turret.c). A turret_breach brush swings toward the angles
its driver asks for, at most `speed` degrees a second on each axis and within
its pitch and yaw limits; its turret_base turns with it in yaw. The
turret_driver, an infantry soldier riding behind the gun, spots the player,
aims the breach at their eyes and, once its reaction time has passed, fires a
rocket from the muzzle point the breach targets. A dead driver levels the gun
and leaves it idle."""
import math;
import from .world { World, Player }
import from .combat { Opponent, HasOpponent, Projectile, HasProjectile, notices, request_sound }
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }
import from ..math.orientation { quake_basis }

node TurretBase {
    has faces: list[int] = [],
        hulls: list[int] = [],
        origins: list[Vec3] = [],
        pivot: Vec3 = Vec3();
}

"""The breach. Angles are Quake degrees: pitch positive looking down."""
node Turret {
    has faces: list[int] = [],
        hulls: list[int] = [],
        origins: list[Vec3] = [],
        pivot: Vec3 = Vec3(),
        pitch: float = 0.0,
        yaw: float = 0.0,
        aim_pitch: float = 0.0,
        aim_yaw: float = 0.0,
        speed: float = 50.0,
        down_limit: float = 30.0,
        up_limit: float = -30.0,
        min_yaw: float = 0.0,
        max_yaw: float = 360.0,
        muzzle: Vec3 = Vec3(),
        driver_spawn: Vec3 | None = None,
        fire: bool = False;
}

"""A driver riding a breach: its offset from the breach as distance, bearing
and height (turret_driver_link's move_origin), and its targeting state."""
edge Mans: Opponent --> Turret {
    has distance: float = 0.0,
        bearing: float = 0.0,
        height: float = 0.0,
        spotted: bool = False,
        lost_sight: bool = False,
        trail_time: float = 0.0,
        attack_finished: float = 0.0;
}

edge HasTurret: World --> Turret {}
edge Mounts: Turret --> TurretBase {}

def turret_point(fields: dict[str, str]) -> Vec3 {
    parts = fields.get("origin", "0 0 0").split();
    if len(parts) != 3 {
        return Vec3();
    }
    return Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
}

def turret_field(fields: dict[str, str], key: str, fallback: float) -> float {
    value = float(fields.get(key, "0"));
    return value if value != 0.0 else fallback;
}

"""AnglesNormalize: into [0, 360)."""
def normalize_angle(angle: float) -> float {
    while angle >= 360.0 {
        angle -= 360.0;
    }
    while angle < 0.0 {
        angle += 360.0;
    }
    return angle;
}

def wrap_delta(delta: float) -> float {
    if delta < -180.0 {
        return delta + 360.0;
    }
    if delta > 180.0 {
        return delta - 360.0;
    }
    return delta;
}

"""SnapToEights: round to the nearest eighth of a unit."""
def snap_eighths(value: float) -> float {
    scaled = value * 8.0;
    scaled = scaled + 0.5 if scaled > 0.0 else scaled - 0.5;
    return 0.125 * float(int(scaled));
}

"""Q2 AngleVectors for pitch and yaw (no roll): forward, right, up."""
def turret_axes(pitch: float, yaw: float) -> list[Vec3] {
    p = math.radians(pitch);
    y = math.radians(yaw);
    forward = Vec3(x=math.cos(p) * math.cos(y), y=math.cos(p) * math.sin(y), z=-math.sin(p));
    right = Vec3(x=math.sin(y), y=-math.cos(y));
    up = Vec3(x=math.sin(p) * math.cos(y), y=math.sin(p) * math.sin(y), z=math.cos(p));
    return [forward, right, up];
}

def model_parts(bsp: Bsp, collision: CollisionMap, fields: dict[str, str]) -> list[list[int]] {
    reference = fields.get("model", "");
    if not reference.startswith("*") or not reference[1:].isdigit() {
        return [[], []];
    }
    model = int(reference[1:]);
    if model <= 0 or model >= len(bsp.models) {
        return [[], []];
    }
    record = bsp.models[model];
    faces = list(range(record.first_face, record.first_face + record.face_count));
    hulls: list[int] = [];
    for i in range(len(collision.models)) {
        if collision.models[i] == model {
            hulls.append(i);
            collision.allow_rotation(i);
        }
    }
    for face in faces {
        bsp.faces[face].moving_light = True;
    }
    return [faces, hulls];
}

"""SP_turret_breach, SP_turret_base and turret_breach_finish_init. Drivers
join once opponents are populated (link_turret_drivers)."""
def load_turrets(world: World, bsp: Bsp, collision: CollisionMap) {
    if bsp.game != "q2" {
        return;
    }
    points: dict[str, Vec3] = {};
    for entity in bsp.entities {
        name = entity.fields.get("targetname", "");
        if name {
            points[name] = turret_point(entity.fields);
        }
    }
    bases: dict[str, TurretBase] = {};
    for entity in bsp.entities {
        fields = entity.fields;
        if fields.get("classname", "") != "turret_base" {
            continue;
        }
        parts = model_parts(bsp, collision, fields);
        base = TurretBase(faces=parts[0], hulls=parts[1], pivot=turret_point(fields));
        for hull in base.hulls {
            base.origins.append(collision.offsets[hull]);
        }
        bases[fields.get("team", "")] = base;
    }
    for entity in bsp.entities {
        fields = entity.fields;
        if fields.get("classname", "") != "turret_breach" {
            continue;
        }
        parts = model_parts(bsp, collision, fields);
        origin = turret_point(fields);
        yaw = float(fields.get("angle", "0"));
        breach = Turret(
            faces=parts[0],
            hulls=parts[1],
            pivot=origin,
            yaw=yaw,
            aim_yaw=yaw,
            speed=turret_field(fields, "speed", 50.0),
            down_limit=-turret_field(fields, "minpitch", -30.0),
            up_limit=-turret_field(fields, "maxpitch", 30.0),
            min_yaw=float(fields.get("minyaw", "0")),
            max_yaw=turret_field(fields, "maxyaw", 360.0)
        );
        for hull in breach.hulls {
            breach.origins.append(collision.offsets[hull]);
        }
        # The muzzle offset is the world-space vector to the target, reused as
        # forward/right/up distances when firing, as the original does.
        target = fields.get("target", "");
        if target in points {
            breach.muzzle = points[target].sub(origin);
        }
        name = fields.get("targetname", "");
        for other in bsp.entities {
            if other.fields.get("classname", "") == "turret_driver"
                and name
                and other.fields.get("target", "") == name {
                breach.driver_spawn = turret_point(other.fields);
            }
        }
        world +>:HasTurret:+> breach;
        team = fields.get("team", "");
        if team in bases {
            breach +>:Mounts:+> bases[team];
        }
        pose_turret(breach, bsp, collision);
    }
}

"""turret_driver_link: a driver spawned at a breach's driver spot rides it."""
def link_turret_drivers(world: World) -> list[Opponent] {
    linked: list[Opponent] = [];
    for breach in [world->:HasTurret:->][?:Turret] {
        seat_spot = breach.driver_spawn;
        if seat_spot is None {
            continue;
        }
        for driver in [world->:HasOpponent:->][?:Opponent] {
            if driver.kind != "turret_driver" or [driver->:Mans:->] {
                continue;
            }
            origin = driver.home.sub(Vec3(z=driver.eye_height));
            if origin.sub(seat_spot).length() > 1.0 {
                continue;
            }
            level = seat_spot.sub(breach.pivot);
            level.z = 0.0;
            away = seat_spot.sub(breach.pivot);
            driver +>:Mans(
                distance=level.length(),
                bearing=normalize_angle(math.degrees(math.atan2(away.y, away.x))),
                height=seat_spot.z - breach.pivot.z
            ):+> breach;
            driver.yaw = math.radians(breach.yaw);
            linked.append(driver);
        }
    }
    return linked;
}

def pose_turret(breach: Turret, bsp: Bsp, collision: CollisionMap) {
    turn = quake_basis(Vec3(x=breach.pitch, y=breach.yaw));
    for face in breach.faces {
        bsp.faces[face].turn = turn;
        bsp.faces[face].pivot = breach.pivot;
    }
    for hull in breach.hulls {
        collision.set_turn(hull, turn);
    }
    swing = quake_basis(Vec3(y=breach.yaw));
    for base in [breach->:Mounts:->][?:TurretBase] {
        for face in base.faces {
            bsp.faces[face].turn = swing;
            bsp.faces[face].pivot = base.pivot;
        }
        for hull in base.hulls {
            collision.set_turn(hull, swing);
        }
    }
}

walker TurretTick {
    has bsp: Bsp,
        collision: CollisionMap,
        player: Player,
        dt: float,
        clock: float = 0.0,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        if self.dt > 0.0 {
            visit [here->:HasTurret:->];
        }
    }

    can swing with Turret entry {
        riders = [here<-:Mans:<-][?:Opponent];
        if riders and riders[0].health <= 0 {
            # turret_driver_die: level the gun and let go of it.
            here.aim_pitch = 0.0;
            for crew in [edge here<-:Mans:<-] {
                del crew;
            }
        }
        seats = [edge here<-:Mans:<-];
        riders = [here<-:Mans:<-][?:Opponent];
        if seats and riders {
            self.think(riders[0], seats[0], here);
        }
        self.turn(here);
        if seats and riders {
            self.carry(riders[0], seats[0], here);
        }
        pose_turret(here, self.bsp, self.collision);
    }

    """turret_driver_think: find the player, aim the breach at their eyes and
    ask it to fire once the reaction time has passed."""
    def think(driver: Opponent, seat: Mans, breach: Turret) {
        seat.attack_finished = max(0.0, seat.attack_finished - self.dt);
        player = self.player;
        eye = player.pos;
        delta = eye.sub(driver.pos);
        sight = self.collision.trace_point(driver.pos, eye);
        visible = player.health > 0 and not sight.start_solid and sight.fraction == 1.0;
        if not seat.spotted {
            if not visible or not notices(driver, eye, delta.length(), False) {
                return;
            }
            seat.spotted = True;
            seat.lost_sight = False;
            seat.trail_time = 0.0;
        } elif player.health <= 0 {
            seat.spotted = False;
            return;
        } elif visible {
            if seat.lost_sight {
                seat.trail_time = 0.0;
                seat.lost_sight = False;
            }
        } else {
            seat.lost_sight = True;
            return;
        }
        seat.trail_time += self.dt;
        aim = eye.sub(breach.pivot);
        flat = math.sqrt(aim.x * aim.x + aim.y * aim.y);
        breach.aim_yaw = normalize_angle(math.degrees(math.atan2(aim.y, aim.x)));
        breach.aim_pitch = normalize_angle(-math.degrees(math.atan2(aim.z, flat)));
        if seat.attack_finished > 0.0 {
            return;
        }
        reaction = float(3 - driver.skill);
        if seat.trail_time < reaction {
            return;
        }
        seat.attack_finished = reaction + 1.0;
        breach.fire = True;
    }

    """turret_breach_think: clamp the wanted angles, then turn toward them."""
    def turn(breach: Turret) {
        pitch = normalize_angle(breach.pitch);
        yaw = normalize_angle(breach.yaw);
        wanted_pitch = normalize_angle(breach.aim_pitch);
        wanted_yaw = normalize_angle(breach.aim_yaw);
        if wanted_pitch > 180.0 {
            wanted_pitch -= 360.0;
        }
        if wanted_pitch > breach.down_limit {
            wanted_pitch = breach.down_limit;
        } elif wanted_pitch < breach.up_limit {
            wanted_pitch = breach.up_limit;
        }
        if wanted_yaw < breach.min_yaw or wanted_yaw > breach.max_yaw {
            below = wrap_delta(abs(breach.min_yaw - wanted_yaw));
            above = wrap_delta(abs(breach.max_yaw - wanted_yaw));
            wanted_yaw = breach.min_yaw if abs(below) < abs(above) else breach.max_yaw;
        }
        step = breach.speed * self.dt;
        pitch_step = max(-step, min(step, wrap_delta(wanted_pitch - pitch)));
        yaw_step = max(-step, min(step, wrap_delta(wanted_yaw - yaw)));
        breach.pitch = pitch + pitch_step;
        breach.yaw = yaw + yaw_step;
    }

    """Keep the driver seated behind the gun, and fire when asked."""
    def carry(driver: Opponent, seat: Mans, breach: Turret) {
        angle = math.radians(breach.yaw + seat.bearing);
        x = snap_eighths(breach.pivot.x + math.cos(angle) * seat.distance);
        y = snap_eighths(breach.pivot.y + math.sin(angle) * seat.distance);
        z = snap_eighths(
            breach.pivot.z + seat.distance * math.tan(math.radians(breach.pitch)) + seat.height
        );
        driver.pos = Vec3(x=x, y=y, z=z + driver.eye_height);
        driver.velocity = Vec3();
        driver.yaw = math.radians(breach.yaw);
        world = self.world;
        if not breach.fire or world is None {
            return;
        }
        breach.fire = False;
        # turret_breach_fire: a 100-150 damage rocket at 550 + 50 per skill.
        axes = turret_axes(breach.pitch, breach.yaw);
        start = breach.pivot
            .add(axes[0].scale(breach.muzzle.x))
            .add(axes[1].scale(breach.muzzle.y))
            .add(axes[2].scale(breach.muzzle.z));
        driver.shot_random = (driver.shot_random * 48271) % 2147483647;
        damage = 100 + int(float(driver.shot_random) / 2147483647.0 * 50.0);
        world +>:HasProjectile:+> Projectile(
            pos=start,
            velocity=axes[0].scale(550.0 + 50.0 * float(driver.skill)),
            damage=damage,
            splash=damage,
            radius=150.0,
            effect="q2_rocket",
            hostile=True,
            owner=driver,
            quarry=self.player
        );
        request_sound(driver, "sound/weapons/rocklf1a.wav");
    }
}
