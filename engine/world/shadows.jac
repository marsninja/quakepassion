"""Q3 blob shadows (cg_players.c CG_PlayerShadow, cg_shadows 1).

Every frame each player drops a small box 128 units down through the world;
where it lands the markShadow shader is laid on the ground as a temporary
impact mark (CG_ImpactMark), 24 units in radius, turned with the legs and
fading with the height the player is at. `CastShadows` walks the world's
players, bots and bodies and collects those marks for the frame to draw;
nothing is kept."""
import math;
import from .world { World, Entity, Actor, Player }
import from .combat { Opponent, HasOpponent }
import from .body_queue { Corpse, HasCorpse }
import from .models { Visual, PlayerRig }
import from .powerups { Empowered, Powerup }
import from .particles { ImpactMark, mark_fragments }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }
import from ..math.interpolation { TickBlend }

# cg_players.c SHADOW_DISTANCE and the mark's radius; cg_main.c's shader.
glob SHADOW_DISTANCE: float = 128.0,
     SHADOW_RADIUS: float = 24.0,
     SHADOW_MARK: str = "markShadow";

"""A view of the level's collision that traces CG_PlayerShadow's box (mins
-15 -15 0, maxs 15 15 2) about a player's origin."""
def shadow_caster(collision: CollisionMap) -> CollisionMap {
    return collision.for_body(0.0, 0.0, Vec3(x=-15.0, y=-15.0, z=0.0), Vec3(x=15.0, y=15.0, z=2.0));
}

"""How dark a shadow is `fraction` of the way down its trace: it fades out
with height (CG_PlayerShadow's alpha)."""
def shadow_strength(fraction: float) -> float {
    return max(0.0, min(1.0, 1.0 - fraction));
}

walker CastShadows {
    has collision: CollisionMap,
        blend: TickBlend = TickBlend(),
        player: Player | None = None,
        player_height: float = 26.0,
        world: World | None = None,
        # Brush models (doors, plats): the original traces the world alone.
        movers: list[int] = [],
        marks: list[ImpactMark] = [];

    can begin with World entry {
        self.world = here;
        self.movers = [i for i in range(len(self.collision.models)) if self.collision.models[i] > 0];
        person = self.player;
        if person is not None {
            self.cast(person, self.player_height, person.yaw);
        }
        visit [here->:HasOpponent:->];
        visit [here->:HasCorpse:->];
    }

    can shade with Opponent entry {
        if here.arena and not here.dormant and here.visual.visible {
            self.cast(here, here.eye_height, self.legs_yaw(here.visual, here.yaw));
        }
    }

    can rest with Corpse entry {
        self.cast(here, here.eye_height, self.legs_yaw(here.body, here.yaw));
    }

    """The yaw the mark turns with: a rig's legs (cent->pe.legs.yawAngle), in
    radians."""
    def legs_yaw(visual: Visual, yaw: float) -> float {
        if isinstance(visual, PlayerRig) {
            return math.radians(visual.legs_angles.y);
        }
        return yaw;
    }

    """CG_PlayerShadow for one body whose eyes are `height` above its origin."""
    def cast(body: Entity, height: float, yaw: float) {
        world = self.world;
        if world is None {
            return;
        }
        # No shadows when invisible.
        if isinstance(body, Actor) {
            for power in [body->:Empowered:->][?:Powerup] {
                if power.kind == "invisibility" and power.remaining != 0.0 {
                    return;
                }
            }
        }
        origin = self.blend.place(body.tick_pose, body.pos).sub(Vec3(z=height));
        trace = self.collision.trace(origin, origin.sub(Vec3(z=SHADOW_DISTANCE)), exclude=self.movers);
        # No shadow if too high.
        if trace.fraction >= 1.0 or trace.start_solid {
            return;
        }
        fragments = mark_fragments(world, trace.end, trace.normal, yaw, SHADOW_RADIUS);
        if not fragments {
            return;
        }
        shade = shadow_strength(trace.fraction);
        self.marks.append(
            ImpactMark(
                pos=trace.end, normal=trace.normal, shader=SHADOW_MARK, radius=SHADOW_RADIUS, angle=yaw,
                color=Vec3(x=shade, y=shade, z=shade), fragments=fragments
            )
        );
    }
}
