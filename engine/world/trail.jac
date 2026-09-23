"""Q2's player trail (p_trail.c): the player leaves up to eight breadcrumbs,
one whenever they have moved on from the last, and a monster that has lost
sight of them follows the crumbs laid since it last saw them, oldest first."""
import from .world { World, Player }
import from ..math.vec3 { Vec3 }

glob TRAIL_LENGTH: int = 8;

node PlayerTrail {
    has clock: float = 0.0;
}

node TrailMark {
    has pos: Vec3,
        stamp: float;
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
        trail +>:Crumb:+> TrailMark(pos=self.player.pos.add(Vec3()), stamp=trail.clock);
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

"""PlayerTrail_PickFirst/PickNext: the oldest crumb laid after `since`."""
def next_crumb(world: World, since: float) -> TrailMark | None {
    found = [world->:HasTrail:->][?:PlayerTrail];
    if not found {
        return None;
    }
    best: TrailMark | None = None;
    for mark in [found[0]->:Crumb:->][?:TrailMark] {
        if mark.stamp > since and (best is None or mark.stamp < best.stamp) {
            best = mark;
        }
    }
    return best;
}

def trail_clock(world: World) -> float {
    found = [world->:HasTrail:->][?:PlayerTrail];
    return found[0].clock if found else 0.0;
}
