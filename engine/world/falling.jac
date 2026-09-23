"""Q2 func_object (g_misc.c): a brush that falls under gravity (MOVETYPE_TOSS)
shortly after spawning, or, flagged TRIGGER_SPAWN, stays hidden and drops when
used. It lands on the first floor below its footprint and crushes whatever it
falls onto for its dmg (100 by default)."""
import from .world { World, Player }
import from .signals { Signal, HasSignal }
import from .combat { Opponent, HasOpponent, CombatState, damage_opponent }
import from .damage { Damage }
import from .doors { model_bounds }
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }
import from ..math.aabb { AABB }

node FallingObject {
    has model: int,
        faces: list[int] = [],
        hulls: list[int] = [],
        origins: list[Vec3] = [],
        bounds: AABB = AABB(mins=Vec3(), maxs=Vec3()),
        damage: int = 100,
        drop: float = 0.0,
        velocity: float = 0.0,
        falling: bool = False,
        landed: bool = False,
        hidden: bool = False,
        release: float = 0.2,
        activation: Signal = Signal();
}

edge HasFallingObject: World --> FallingObject {}

def load_falling_objects(world: World, bsp: Bsp, collision: CollisionMap) {
    if bsp.game != "q2" {
        return;
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        reference = fields.get("model", "");
        if fields.get("classname", "") != "func_object" or not reference.startswith("*") or not reference[1:].isdigit() {
            continue;
        }
        model = int(reference[1:]);
        if model <= 0 or model >= len(bsp.models) {
            continue;
        }
        record = bsp.models[model];
        piece = FallingObject(
            model=model,
            faces=list(range(record.first_face, record.first_face + record.face_count)),
            bounds=model_bounds(bsp, model),
            damage=int(float(fields.get("dmg", "0"))) or 100,
            hidden=int(fields.get("spawnflags", "0")) & 1 != 0,
            activation=Signal(entities=[index])
        );
        for i in range(len(collision.models)) {
            if collision.models[i] == model {
                piece.hulls.append(i);
                piece.origins.append(collision.offsets[i]);
            }
        }
        for face in piece.faces {
            bsp.faces[face].hidden = piece.hidden;
        }
        # SOLID_NOT until used: park the hidden object's hulls out of reach.
        if piece.hidden {
            for j in range(len(piece.hulls)) {
                collision.set_offset(piece.hulls[j], piece.origins[j].add(Vec3(z=-1000000.0)));
            }
        }
        world +>:HasFallingObject:+> piece;
        world +>:HasSignal:+> piece.activation;
    }
}

walker FallingTick {
    has bsp: Bsp,
        collision: CollisionMap,
        player: Player,
        state: CombatState,
        dt: float,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        if self.dt > 0.0 {
            visit [here->:HasFallingObject:->];
        }
    }

    """The floor under the object's footprint: the shortest drop from its
    corners and middle, ignoring its own brushes."""
    def floor_gap(piece: FallingObject) -> float {
        box = piece.bounds;
        lo = box.mins;
        hi = box.maxs;
        points = [
            Vec3(x=lo.x + 1.0, y=lo.y + 1.0, z=lo.z + piece.drop),
            Vec3(x=hi.x - 1.0, y=lo.y + 1.0, z=lo.z + piece.drop),
            Vec3(x=lo.x + 1.0, y=hi.y - 1.0, z=lo.z + piece.drop),
            Vec3(x=hi.x - 1.0, y=hi.y - 1.0, z=lo.z + piece.drop),
            Vec3(x=(lo.x + hi.x) * 0.5, y=(lo.y + hi.y) * 0.5, z=lo.z + piece.drop)
        ];
        gap = 4096.0;
        for point in points {
            hit = self.collision.trace_point(point, point.sub(Vec3(z=4096.0)), piece.hulls);
            if not hit.start_solid {
                gap = min(gap, hit.fraction * 4096.0);
            }
        }
        return gap;
    }

    can fall with FallingObject entry {
        if here.landed {
            return;
        }
        if here.activation.pending > 0 and here.hidden {
            # func_object_use: appear and drop.
            here.activation.pending = 0;
            here.hidden = False;
            for face in here.faces {
                self.bsp.faces[face].hidden = False;
            }
            for j in range(len(here.hulls)) {
                self.collision.set_offset(here.hulls[j], here.origins[j]);
            }
            here.falling = True;
        }
        if here.hidden {
            return;
        }
        if not here.falling {
            # func_object_release two frames after spawning.
            here.release -= self.dt;
            if here.release > 0.0 {
                return;
            }
            here.falling = True;
        }
        here.velocity = min(here.velocity + 800.0 * self.dt, 2000.0);
        step = here.velocity * self.dt;
        gap = self.floor_gap(here);
        if step >= gap {
            step = gap;
            here.landed = True;
        }
        here.drop -= step;
        motion = Vec3(z=here.drop);
        for face in here.faces {
            self.bsp.faces[face].motion = motion;
        }
        for j in range(len(here.hulls)) {
            self.collision.set_offset(here.hulls[j], here.origins[j].add(motion));
        }
        if here.landed and self.world is not None {
            self.crush(here);
        }
    }

    """func_object_touch: squash whatever the object came down on."""
    def crush(piece: FallingObject) {
        world = self.world;
        if world is None {
            return;
        }
        lo = piece.bounds.mins.add(Vec3(z=piece.drop));
        hi = piece.bounds.maxs.add(Vec3(z=piece.drop));
        actors: list[Player] = [self.player];
        actors.extend([enemy for enemy in [world->:HasOpponent:->][?:Opponent] if enemy.health > 0 and not enemy.dormant]);
        for actor in actors {
            height = actor.eye_height if isinstance(actor, Opponent) else self.collision.eye_height;
            origin = actor.pos.sub(Vec3(z=height));
            under = origin.x + 16.0 > lo.x and origin.x - 16.0 < hi.x
                and origin.y + 16.0 > lo.y and origin.y - 16.0 < hi.y
                and origin.z + 32.0 >= lo.z - 8.0 and origin.z - 24.0 < hi.z;
            if not under {
                continue;
            }
            if isinstance(actor, Opponent) {
                damage_opponent(actor, piece.damage, means="crush", tally=self.state);
            } else {
                actor spawn Damage(amount=piece.damage, means="crush");
            }
        }
    }
}
