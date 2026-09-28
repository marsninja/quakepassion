"""Brush movers pushing what they carry or run into: Q1 SV_PushMove, Q2 SV_Push
and Q3 G_MoverPush. A mover's hulls step from one pose to the next; every body
standing on them, or caught by them in their new place, goes along by the
mover's translation and its turn about the model origin. Bodies are traced in
their own boxes: the player's, each monster's own, and each item's. If one of
them cannot go, everything is put back and that body is handed to the mover,
which crushes, reverses or waits as its game's blocked function does."""
import math;
import from .world { World, Entity, Player }
import from .combat { Opponent, HasOpponent, Drops, monster_collision, monster_body_key }
import from .pickups { Pickup, HasPickup, remove_pickup, item_view, item_lift }
import from .drops { in_flight }
import from .particles { explode }
import from ..physics.collision { CollisionMap, Trace, hull_sweep }
import from ..math.vec3 { Vec3 }
import from ..math.orientation { Basis }
import from ..math.aabb { AABB }

"""How one mover hull moves this step: its offset (the model origin, which
it turns about) from and to, and its turn from and to. `yaw` is the step's
turn about the vertical in degrees (SV_Push's amove[YAW]), which a player
riding the mover turns with."""
obj HullStep {
    has index: int,
        offset_from: Vec3,
        offset_to: Vec3,
        turn_from: Basis | None = None,
        turn_to: Basis | None = None,
        yaw: float = 0.0,
        bounds: AABB | None = None;

    """Whether a box at `origin`, `margin` beyond the player's, can touch the
    hull in either pose: its tight `bounds` when the mover knows them (a
    train's route bounds are far larger), else the collision broad phase."""
    def near(view: CollisionMap, origin: Vec3, margin: float) -> bool {
        box = self.bounds;
        if box is None {
            return view.reaches(self.index, origin, margin);
        }
        return origin.x >= box.mins.x - margin
            and origin.x <= box.maxs.x + margin
            and origin.y >= box.mins.y - margin
            and origin.y <= box.maxs.y + margin
            and origin.z >= box.mins.z - margin
            and origin.z <= box.maxs.z + margin;
    }

    """Where a point held by this hull goes: SV_Push's move plus the change
    its amove makes to the point's place about the pusher's origin."""
    def carry(point: Vec3) -> Vec3 {
        local = point.sub(self.offset_from);
        if self.turn_from is not None {
            local = self.turn_from.inverse(local);
        }
        if self.turn_to is not None {
            local = self.turn_to.apply(local);
        }
        return self.offset_to.add(local);
    }
}

"""Something a mover may push: the entity, the collision view that traces its
own box, and its `lift`, the entity's position less its box origin. `solid`
bodies block a mover they cannot be pushed out of; the rest (Q1 items and
corpses, SOLID_TRIGGER and SOLID_NOT) are left where they were pushed."""
obj Pushable {
    has entity: Entity,
        view: CollisionMap,
        lift: Vec3 = Vec3(),
        solid: bool = True,
        client: bool = False;

    def origin() -> Vec3 {
        return self.entity.pos.sub(self.lift);
    }

    """Whether the body is falling or at rest, so it can stand on a mover."""
    def settled() -> bool {
        body = self.entity;
        if isinstance(body, Player) {
            return body.velocity.z <= 0.0;
        }
        return True;
    }
}

"""One hull of the view against a box at `start` swept to `finish`."""
def hull_contact(view: CollisionMap, index: int, start: Vec3, finish: Vec3) -> Trace {
    body = view.body;
    return hull_sweep(
        view.hulls[index],
        start,
        finish,
        view.offsets[index],
        view.top_drop,
        False,
        view.turns.get(index, None),
        body if body is not None and body.planes else None
    );
}

"""How much further than the player's box a view's box reaches (the hull
bounds are the player's), plus a unit of slack."""
def reach_margin(view: CollisionMap) -> float {
    body = view.body;
    if body is None {
        return 1.0;
    }
    return 1.0 + max(
        max(abs(body.lo.x), abs(body.lo.y)),
        max(abs(body.lo.z), max(max(abs(body.hi.x), abs(body.hi.y)), abs(body.hi.z)))
    );
}

"""Whether a body's box rests on the hull: a floor within a quarter unit."""
def stands_on(body: Pushable, step: HullStep) -> bool {
    origin = body.origin();
    if not step.near(body.view, origin, reach_margin(body.view)) {
        return False;
    }
    support = hull_contact(body.view, step.index, origin, origin.add(Vec3(z=-0.25)));
    return not support.start_solid and support.fraction < 1.0 and support.normal.z >= 0.7;
}

"""Whether a body's box is inside the hull where it now stands."""
def caught_by(body: Pushable, step: HullStep) -> bool {
    origin = body.origin();
    if not step.near(body.view, origin, reach_margin(body.view)) {
        return False;
    }
    return hull_contact(body.view, step.index, origin, origin).start_solid;
}

"""SV_TestEntityPosition: the body's box is clear of everything solid."""
def clear_at(body: Pushable, origin: Vec3) -> bool {
    return not body.view.trace(origin, origin).start_solid;
}

"""The step of the hull a body stands on before the mover moves (Q1
FL_ONGROUND on the pusher, Q2/Q3 groundentity), if any."""
def held_by(body: Pushable, steps: list[HullStep]) -> HullStep | None {
    if not body.settled() {
        return None;
    }
    for step in steps {
        if stands_on(body, step) {
            return step;
        }
    }
    return None;
}

"""The bodies standing on any of these hulls."""
def riders_of(hulls: list[int], bodies: list[Pushable]) -> list[Pushable] {
    steps = [HullStep(index=index, offset_from=Vec3(), offset_to=Vec3()) for index in hulls];
    return [body for body in bodies if held_by(body, steps) is not None];
}

"""Put the hulls in their `to` pose (or back in their `from` pose)."""
def place_steps(collision: CollisionMap, steps: list[HullStep], forward: bool) {
    for step in steps {
        collision.set_offset(step.index, step.offset_to if forward else step.offset_from);
        turn = step.turn_to if forward else step.turn_from;
        if turn is not None or step.index in collision.turns {
            collision.set_turn(step.index, turn);
        }
    }
}

"""Move the mover's hulls by `steps` and push the bodies. Returns None once
everything has moved, or the body that could not go, with the mover and
every body back where they were."""
def push_move(
    collision: CollisionMap, steps: list[HullStep], bodies: list[Pushable], game: str
) -> Pushable | None {
    holds = [held_by(body, steps) for body in bodies];
    place_steps(collision, steps, True);
    moved: list[Pushable] = [];
    places: list[Vec3] = [];
    carriers: list[HullStep] = [];
    indices = [step.index for step in steps];
    for i in range(len(bodies)) {
        body = bodies[i];
        step = holds[i];
        rider = step is not None;
        if step is None {
            for candidate in steps {
                if caught_by(body, candidate) {
                    step = candidate;
                    break;
                }
            }
        }
        if step is None {
            continue;
        }
        origin = body.origin();
        destination = step.carry(origin);
        if game == "q1" {
            # SV_PushEntity: the body travels as far as the world lets it,
            # with the pusher out of the way.
            path = body.view.trace(origin, destination, exclude=indices);
            destination = path.end if not path.start_solid else origin;
        }
        if clear_at(body, destination) {
            moved.append(body);
            places.append(destination);
            carriers.append(step);
            continue;
        }
        # Q2 SV_Push / Q3 G_TryPushingEntity: a rider that can stay where it
        # was is left behind (a sliding trapdoor).
        if game != "q1" and rider and clear_at(body, origin) {
            continue;
        }
        # Q1 SV_PushMove: a trigger or corpse is squashed where it was pushed.
        if not body.solid {
            moved.append(body);
            places.append(destination);
            carriers.append(step);
            continue;
        }
        place_steps(collision, steps, False);
        return body;
    }
    for i in range(len(moved)) {
        body = moved[i];
        entity = body.entity;
        entity.pos = places[i].add(body.lift);
        if not isinstance(entity, Player) {
            continue;
        }
        if held_step(body, bodies, holds) is not None {
            entity.grounded = True;
        }
        # Q2 delta_angles / Q3 ps.delta_angles: a player's view turns with
        # the mover that moves it; Q1 turns nobody, and monsters keep facing.
        if body.client and game != "q1" and carriers[i].yaw != 0.0 {
            entity.yaw += math.radians(carriers[i].yaw);
        }
        if isinstance(entity, Opponent) {
            entity.route = [];
            entity.route_wait = 0.0;
        }
    }
    return None;
}

def held_step(body: Pushable, bodies: list[Pushable], holds: list[HullStep | None]) -> HullStep | None {
    for i in range(len(bodies)) {
        if bodies[i] is body {
            return holds[i];
        }
    }
    return None;
}

"""What a Q2/Q3 mover does with an item in its way (door_blocked,
plat_blocked, train_blocked, Q3 Blocked_Door): the item goes, with Q2's
BecomeExplosion1; Q1 items never block."""
def clear_item(world: World, item: Pickup, game: str) {
    if game == "q2" {
        explode(world, item.pos, "q2_explosion");
    }
    remove_pickup(world, item);
}

"""Gather everything a mover can push this tick, each with the view that
traces its own box: the player; living monsters and corpses (Q1's and
Q2's MOVETYPE_STEP bodies; bosses and figures that never move stay put);
and items (MOVETYPE_TOSS in Q1/Q2, riding movers by groundEntityNum in
Q3), except those still carried or thrown."""
walker GatherPushables {
    has collision: CollisionMap,
        game: str = "",
        player: Player | None = None,
        bodies: list[Pushable] = [],
        views: dict[str, CollisionMap] = {};

    can begin with World entry {
        person = self.player;
        if person is not None {
            self.bodies.append(
                Pushable(
                    entity=person,
                    view=self.collision,
                    lift=Vec3(z=self.collision.eye_height),
                    solid=person.health > 0,
                    client=True
                )
            );
        }
        visit [here->:HasOpponent:->];
        visit [here->:HasPickup:->];
    }

    can monster with Opponent entry {
        rule = here.rule;
        if here.dormant
            or rule.script
            or rule.decoration
            or rule.movement == "none"
            or (rule.inert and self.game == "q1")
            or (here.health <= 0 and (here.gibbed or not here.visual.visible)) {
            return;
        }
        key = "monster:" + monster_body_key(here);
        if key not in self.views {
            self.views[key] = monster_collision(self.collision, here);
        }
        self.bodies.append(
            Pushable(
                entity=here,
                view=self.views[key],
                lift=Vec3(z=here.eye_height),
                solid=here.health > 0,
                client=here.arena
            )
        );
    }

    can item with Pickup entry {
        if [here<-:Drops:<-] or in_flight(here) {
            return;
        }
        key = "item:" + self.game;
        if key not in self.views {
            self.views[key] = item_view(self.collision, self.game);
        }
        self.bodies.append(
            Pushable(
                entity=here,
                view=self.views[key],
                lift=item_lift(self.game),
                solid=self.game != "q1" and here.active
            )
        );
    }
}
