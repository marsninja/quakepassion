"""Idle patrols and combat points. A monster whose `target` names a path_corner
walks the corner chain while idle (Q1 ai_walk/t_movetarget, Q2 ai_walk and
path_corner_touch); a Q2 monster with a `combattarget` runs to that
point_combat chain once it has an enemy, holding fire until it arrives. The
current goal is a Patrols or Holds edge, rewired at each corner."""
import from .world { World }
import from .combat { Opponent, HasOpponent }
import from .trains { TrackPoint, TrackNext, HasTrack }
import from .signals { Fire }
import from ..math.vec3 { Vec3 }

edge Patrols: Opponent --> TrackPoint {}
edge Holds: Opponent --> TrackPoint {}

"""Whether a monster's box (-24..40 about its origin) touches a corner's
-8..8 box, the original touch test."""
def touches_corner(enemy: Opponent, corner: TrackPoint) -> bool {
    origin = enemy.pos.sub(Vec3(z=enemy.eye_height));
    gap = corner.origin.sub(origin);
    reach = enemy.rule.width + 8.0;
    return abs(gap.x) < reach and abs(gap.y) < reach and gap.z > -32.0 and gap.z < 48.0;
}

"""Advance past a reached corner: fire its pathtarget (Q2), pause for its wait
(Q2) and aim for the next one. Returns the next corner, if any."""
def pass_corner(enemy: Opponent, corner: TrackPoint) -> TrackPoint | None {
    if enemy.game == "q2" {
        corner.activation spawn Fire();
        if corner.hold_time > 0.0 {
            enemy.patrol_wait = corner.hold_time;
        }
    }
    following = [corner->:TrackNext:->][?:TrackPoint];
    if following {
        return following[0];
    }
    return None;
}

walker PatrolTick {
    has dt: float;

    can begin with World entry {
        visit [here->:HasOpponent:->];
    }

    can walk with Opponent entry {
        here.patrol_goal = None;
        here.holding = False;
        if here.arena or here.health <= 0 or here.dormant or here.rule.decoration {
            return;
        }
        # Q2 AI_COMBAT_POINT: an alerted monster runs its combat point chain first.
        if here.alert > 0.0 {
            holds = [here->:Holds:->][?:TrackPoint];
            if not holds {
                return;
            }
            point = holds[0];
            if touches_corner(here, point) {
                for link in [edge here->:Holds:->] {
                    del link;
                }
                following = pass_corner(here, point);
                if following is not None {
                    here +>:Holds:+> following;
                }
                return;
            }
            here.patrol_goal = point.origin.add(Vec3(z=here.eye_height));
            here.holding = True;
            return;
        }
        corners = [here->:Patrols:->][?:TrackPoint];
        if not corners {
            return;
        }
        if here.patrol_wait > 0.0 {
            here.patrol_wait = max(0.0, here.patrol_wait - self.dt);
            return;
        }
        corner = corners[0];
        if touches_corner(here, corner) {
            for link in [edge here->:Patrols:->] {
                del link;
            }
            following = pass_corner(here, corner);
            if following is None {
                return;
            }
            here +>:Patrols:+> following;
            corner = following;
            if here.patrol_wait > 0.0 {
                return;
            }
        }
        here.patrol_goal = corner.origin.add(Vec3(z=here.eye_height));
    }
}
