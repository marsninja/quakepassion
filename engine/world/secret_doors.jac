"""Q1 and Q2 two-stage secret doors built on the shared translating mover
graph: a door steps aside, waits a second, slides back along its arrow, holds,
and returns the same way (Q1 doors.qc fd_secret_use to fd_secret_done, Q2
g_func.c door_secret_use to door_secret_done)."""
import math;
import from .world { World }
import from .trains { Train, TrackPoint, TrackNext, HasTrack, attach_train, voice_train }
import from .signals { Signal }
import from .doors { door_direction, mover_voices }
import from ..formats.bsp { Bsp, model_bounds, mover_origin }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3, right_from }

def load_secret_doors(world: World, bsp: Bsp, collision: CollisionMap) {
    if bsp.game not in ["q1", "q2"] {
        return;
    }
    q1 = bsp.game == "q1";
    for index in range(len(bsp.entities)) {
        entity = bsp.entities[index];
        fields = entity.fields;
        if fields.get("classname", "") != "func_door_secret" {
            continue;
        }
        reference = fields.get("model", "");
        if not reference.startswith("*") {
            continue;
        }
        model = int(reference[1:]);
        if model <= 0 or model >= len(bsp.models) {
            raise ValueError("Invalid secret door model");
        }
        record = bsp.models[model];
        flags = int(fields.get("spawnflags", "0"));
        forward = door_direction(entity);
        angles = fields.get("angles", "0 " + fields.get("angle", "0") + " 0").split();
        if len(angles) != 3 {
            raise ValueError("Invalid secret door angles");
        }
        right = right_from(float(angles[1]) * math.pi / 180.0);
        up = right.cross(forward);
        roll = float(angles[2]) * math.pi / 180.0;
        tilted_right = right.scale(math.cos(roll)).sub(up.scale(math.sin(roll)));
        up = up.scale(math.cos(roll)).add(right.scale(math.sin(roll)));
        right = tilted_right;
        # Mod_LoadSubmodels spreads a brush model's stored bounds by a unit on
        # each side, so `size` is the brush's full extent: the door steps
        # clear of its opening instead of leaving a two-unit sliver in it.
        bounds = model_bounds(bsp, model, mover_origin(fields));
        size = bounds.maxs.sub(bounds.mins);
        # Only Q1 lets the map override the two distances.
        width = float(fields.get("t_width", "0")) if q1 else 0.0;
        length = float(fields.get("t_length", "0")) if q1 else 0.0;
        if width == 0.0 {
            width = abs((up if flags & 4 else right).dot(size));
        }
        if length == 0.0 {
            length = abs(forward.dot(size));
        }
        first = up.scale(-width)
            if flags & 4
            else right.scale(-width if flags & 2 else width);
        second = first.add(forward.scale(length));
        hold_time = float(fields.get("wait", "5"));
        if hold_time == 0.0 {
            hold_time = 5.0;
        }
        # The door stays open for good with Q1's OPEN_ONCE (1) or Q2's wait
        # of -1 (door_secret_move3). Q2's flag 1 is ALWAYS_SHOOT instead, and
        # Q1's NO_SHOOT (8) and YES_SHOOT (16) are bits Q2 does not read.
        stays = flags & 1 != 0 if q1 else hold_time == -1.0;
        named = bool(fields.get("targetname", ""));
        shootable = (not named or flags & 16 != 0) and flags & 8 == 0
            if q1
            else (not named or flags & 1 != 0);
        # Q1 secret_touch prints any message; Q2 gives door_touch only to a
        # targeted door with one.
        message = fields.get("message", "");
        if not q1 and not named {
            message = "";
        }
        offsets = [Vec3(), first, second, first];
        points: list[TrackPoint] = [];
        for step in range(4) {
            point = TrackPoint(
                entity=len(bsp.entities) + index * 4 + step,
                name="secret",
                origin=offsets[step],
                hold_time=max(0.0, hold_time) if step == 2 else 1.0,
                stop=step == 0 or (step == 2 and stays)
            );
            world +>:HasTrack:+> point;
            points.append(point);
        }
        for step in range(4) {
            points[step] +>:TrackNext:+> points[(step + 1) % 4];
        }
        train = Train(
            kind="secret",
            model=model,
            game=bsp.game,
            anchor=Vec3(),
            current=points[0],
            running=False,
            speed=50.0,
            damage=int(float(fields.get("dmg", "0"))) or 2,
            shootable=shootable,
            activation=Signal(entities=[index]),
            faces=list(range(record.first_face, record.first_face + record.face_count)),
            bounds=bounds,
            touch_message=message
        );
        attach_train(world, bsp, collision, train);
        # Q1 func_door_secret: `sounds` 0 means 3. SP_func_door_secret indexes
        # Q2's door sounds but nothing in door_secret_* plays them.
        voice_train(world, train, mover_voices(bsp.game, "func_door_secret", fields));
    }
    collision.reindex();
}
