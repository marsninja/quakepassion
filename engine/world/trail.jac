"""Q2's player trail (p_trail.c): the player leaves up to eight breadcrumbs,
one whenever they have moved on from the last, and a monster that has lost
sight of them follows the crumbs laid since it last saw them, oldest first."""
import math;
import from .world { World, Player }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

glob TRAIL_LENGTH: int = 8;

node PlayerTrail {
    has clock: float = 0.0;
}

"""One crumb: where the player was, when, and the heading (degrees) they
came to it on from the crumb before (PlayerTrail_Add's vectoyaw), which a
monster taking the crumb turns to."""
node TrailMark {
    has pos: Vec3,
        stamp: float,
        yaw: float = 0.0;
}

edge HasTrail: World --> PlayerTrail {}
edge Crumb: PlayerTrail --> TrailMark {}

def trail_of(world: World) -> PlayerTrail {
    found = [world->:HasTrail:->][?:PlayerTrail];
    if found {
        return found[0];
    }
    trail = PlayerTrail();
    world +>:HasTrail:+> trail;
    return trail;
}

"""Drop a crumb every half second the player has moved 32 units from the last."""
walker TrailTick {
    has player: Player,
        dt: float;

    can begin with World entry {
        self.lay(trail_of(here));
    }

    """Spawned on the trail itself, the tick skips the search through the
    world's edges."""
    can follow with PlayerTrail entry {
        self.lay(here);
    }

    def lay(trail: PlayerTrail) {
        trail.clock += self.dt;
        if self.player.health <= 0 {
            return;
        }
        marks = [trail->:Crumb:->][?:TrailMark];
        newest: TrailMark | None = None;
        for mark in marks {
            if newest is None or mark.stamp > newest.stamp {
                newest = mark;
            }
        }
        if newest is not None
            and (trail.clock - newest.stamp < 0.5 or newest.pos.sub(self.player.pos).length() < 32.0) {
            return;
        }
        heading = 0.0;
        if newest is not None {
            came = self.player.pos.sub(newest.pos);
            if came.x != 0.0 or came.y != 0.0 {
                heading = float(int(math.degrees(math.atan2(came.y, came.x))));
                if heading < 0.0 {
                    heading += 360.0;
                }
            }
        }
        trail +>:Crumb:+> TrailMark(
            pos=self.player.pos.add(Vec3()), stamp=trail.clock, yaw=heading
        );
        if len(marks) + 1 > TRAIL_LENGTH {
            oldest = marks[0];
            for mark in marks {
                if mark.stamp < oldest.stamp {
                    oldest = mark;
                }
            }
            trail del --> oldest;
        }
    }
}

"""PlayerTrail_PickNext: the oldest crumb laid after `since`; with none
newer the ring comes round to its oldest crumb again."""
def next_crumb(world: World, since: float) -> TrailMark | None {
    found = [world->:HasTrail:->][?:PlayerTrail];
    if not found {
        return None;
    }
    best: TrailMark | None = None;
    oldest: TrailMark | None = None;
    for mark in [found[0]->:Crumb:->][?:TrailMark] {
        if mark.stamp > since and (best is None or mark.stamp < best.stamp) {
            best = mark;
        }
        if oldest is None or mark.stamp < oldest.stamp {
            oldest = mark;
        }
    }
    return best if best is not None else oldest;
}

"""PlayerTrail_PickFirst: the crumb a monster that has just lost the player
starts on. The oldest laid after `since` if `eye` can see it; else the one
before it, if that is in sight; else the first all the same."""
def first_crumb(
    world: World, since: float, eye: Vec3, collision: CollisionMap
) -> TrailMark | None {
    marker = next_crumb(world, since);
    if marker is None {
        return None;
    }
    if collision.trace_point(eye, marker.pos).fraction == 1.0 {
        return marker;
    }
    # The crumb before it in the ring: the newest older one, or, before the
    # oldest, the newest of all.
    previous: TrailMark | None = None;
    newest: TrailMark | None = None;
    for mark in [trail_of(world)->:Crumb:->][?:TrailMark] {
        if mark.stamp < marker.stamp and (previous is None or mark.stamp > previous.stamp) {
            previous = mark;
        }
        if mark is not marker and (newest is None or mark.stamp > newest.stamp) {
            newest = mark;
        }
    }
    if previous is None {
        previous = newest;
    }
    if previous is not None and collision.trace_point(eye, previous.pos).fraction == 1.0 {
        return previous;
    }
    return marker;
}

def trail_clock(world: World) -> float {
    found = [world->:HasTrail:->][?:PlayerTrail];
    return found[0].clock if found else 0.0;
}
