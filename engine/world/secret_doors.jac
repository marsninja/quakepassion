"""Q1 two-stage secret doors built on the shared translating mover graph."""
import math;
import from .world { World }
import from .trains { Train, TrackPoint, TrackNext, HasTrack, attach_train }
import from .signals { Signal }
import from .doors { door_direction }
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3, right_from }

def load_secret_doors(world: World, bsp: Bsp, collision: CollisionMap) {
    if bsp.game != "q1" {
        return;
    }
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
        size = record.maxs.sub(record.mins);
        width = float(fields.get("t_width", "0"));
        length = float(fields.get("t_length", "0"));
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
        offsets = [Vec3(), first, second, first];
        points: list[TrackPoint] = [];
        for step in range(4) {
            point = TrackPoint(
                entity=len(bsp.entities) + index * 4 + step,
                name="secret",
                origin=offsets[step],
                hold_time=max(0.0, hold_time) if step == 2 else 1.0,
                stop=step == 0 or (step == 2 and flags & 1 != 0)
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
            damage=int(fields.get("dmg", "2")),
            shootable=(not fields.get("targetname", "") or flags & 16 != 0)
                and flags & 8 == 0,
            activation=Signal(entities=[index]),
            faces=list(range(record.first_face, record.first_face + record.face_count))
        );
        attach_train(world, bsp, collision, train);
    }
    collision.reindex();
}
