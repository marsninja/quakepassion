"""Q2 fly-bys (g_misc.c): misc_viper and misc_strogg_ship stay hidden until
used, then fly their path_corner chain like a func_train (300 units a second
by default), firing each corner's pathtarget. A misc_viper_bomb, when used,
drops with the viper's velocity and bursts on impact (BecomeExplosion2) for
its dmg in radius damage."""
import from .world { World, Entity, Player }
import from .signals { Signal, HasSignal, Fire }
import from .trains { TrackPoint, TrackNext, HasTrack }
import from .combat { CombatState, WeaponImpact, blast_actors }
import from .particles { explode }
import from .models { Visual }
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

node Flyer(Entity) {
    has model: str,
        speed: float = 300.0,
        target: str = "",
        running: bool = False,
        pause: float = 0.0,
        heading: Vec3 = Vec3(),
        visual: Visual = Visual(),
        activation: Signal = Signal();
}

node Bomb(Entity) {
    has damage: int = 1000,
        falling: bool = False,
        burst: bool = False,
        velocity: Vec3 = Vec3(),
        visual: Visual = Visual(),
        activation: Signal = Signal();
}

edge HasFlyer: World --> Flyer {}
edge HasBomb: World --> Bomb {}
edge Bound: Flyer --> TrackPoint {}

def:priv entity_point(fields: dict[str, str]) -> Vec3 {
    parts = fields.get("origin", "0 0 0").split();
    if len(parts) != 3 {
        return Vec3();
    }
    return Vec3(x=float(parts[0]), y=float(parts[1]), z=float(parts[2]));
}

"""Flyers and bombs join the signal graph before targets are connected; their
models are attached when the level is populated."""
def load_flyers(world: World, bsp: Bsp) {
    if bsp.game != "q2" {
        return;
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        kind = fields.get("classname", "");
        if kind in ["misc_viper", "misc_strogg_ship"] and fields.get("target", "") {
            flyer = Flyer(
                model="models/ships/viper/tris.md2" if kind == "misc_viper" else "models/ships/strogg1/tris.md2",
                pos=entity_point(fields),
                yaw=float(fields.get("angle", "0")) * 3.14159265 / 180.0,
                speed=float(fields.get("speed", "0")) or 300.0,
                target=fields.get("target", ""),
                activation=Signal(entities=[index])
            );
            flyer.visual.visible = False;
            world +>:HasFlyer:+> flyer;
            world +>:HasSignal:+> flyer.activation;
        } elif kind == "misc_viper_bomb" {
            bomb = Bomb(
                pos=entity_point(fields),
                damage=int(float(fields.get("dmg", "0"))) or 1000,
                activation=Signal(entities=[index])
            );
            bomb.visual.visible = False;
            world +>:HasBomb:+> bomb;
            world +>:HasSignal:+> bomb.activation;
        }
    }
}

walker FlyerTick {
    has player: Player,
        collision: CollisionMap,
        state: CombatState,
        dt: float,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        if self.dt > 0.0 {
            visit [here->:HasFlyer:->];
            visit [here->:HasBomb:->];
        }
    }

    can fly with Flyer entry {
        world = self.world;
        if world is None {
            return;
        }
        if here.activation.pending > 0 {
            here.activation.pending = 0;
            if not here.running {
                # misc_viper_use: appear, then train_use from the first corner.
                here.running = True;
                here.visual.visible = True;
                for corner in [world->:HasTrack:->][?:TrackPoint] {
                    if corner.name == here.target and not [here->:Bound:->] {
                        here.pos = corner.origin.add(Vec3());
                        here +>:Bound:+> corner;
                    }
                }
            }
        }
        if not here.running {
            return;
        }
        if here.pause > 0.0 {
            here.pause = max(0.0, here.pause - self.dt);
            return;
        }
        corners = [here->:Bound:->][?:TrackPoint];
        if not corners {
            return;
        }
        corner = corners[0];
        gap = corner.origin.sub(here.pos);
        step = here.speed * self.dt;
        if gap.length() > step {
            here.heading = gap.normalized();
            here.pos = here.pos.add(here.heading.scale(step));
            return;
        }
        here.pos = corner.origin.add(Vec3());
        corner.activation spawn Fire();
        for link in [edge here->:Bound:->] {
            del link;
        }
        following = [corner->:TrackNext:->][?:TrackPoint];
        if following {
            here +>:Bound:+> following[0];
            if corner.hold_time > 0.0 {
                here.pause = corner.hold_time;
            }
        } else {
            here.running = False;
        }
    }

    can drop with Bomb entry {
        world = self.world;
        if world is None or here.burst {
            return;
        }
        if here.activation.pending > 0 and not here.falling {
            here.activation.pending = 0;
            # misc_viper_bomb_use: fall with the viper's velocity.
            here.falling = True;
            here.visual.visible = True;
            for flyer in [world->:HasFlyer:->][?:Flyer] {
                if flyer.running {
                    here.velocity = flyer.heading.scale(flyer.speed);
                }
            }
        }
        if not here.falling {
            return;
        }
        here.velocity.z -= 800.0 * self.dt;
        finish = here.pos.add(here.velocity.scale(self.dt));
        hit = self.collision.trace_point(here.pos, finish);
        here.pos = here.pos.lerp(finish, hit.fraction);
        if hit.fraction < 1.0 or hit.start_solid {
            here.burst = True;
            here.falling = False;
            here.visual.visible = False;
            here.activation spawn Fire();
            blast_actors(world, here.pos, here.damage, float(here.damage + 40), True, self.player, self.collision, self.state);
            self.state.impacts.append(WeaponImpact(origin=here.pos, splash=here.damage, radius=float(here.damage + 40)));
            # misc_viper_bomb_touch: BecomeExplosion2, the grenade burst.
            explode(world, here.pos, "q2_grenade_explosion");
        }
    }
}
