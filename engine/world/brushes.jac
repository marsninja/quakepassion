"""Q2 toggle walls and destructible brushes using shared geometry and damage."""
import from .world { World, Player }
import from .signals { Signal, HasSignal, Fire }
import from .combat { Opponent, HasOpponent, CombatState, damage_opponent }
import from .damage { Damage, blast_strength }
import from .doors { model_bounds }
import from ..formats.bsp { Bsp }
import from ..physics.collision { CollisionMap, Sweep }
import from ..math.vec3 { Vec3 }

edge HasBrush: World --> BrushObject {}
node BrushObject {
    has model: int,
        kind: str,
        center: Vec3,
        active: bool = True,
        destroyed: bool = False,
        health: int = 100,
        damage: int = 0,
        shootable: bool = False,
        toggle: bool = False,
        spawn_only: bool = False,
        usable: bool = True,
        faces: list[int] = [],
        hulls: list[int] = [],
        hidden: list[bool] = [],
        activation: Signal = Signal();
}

def show_brush(brush: BrushObject, active: bool, bsp: Bsp, collision: CollisionMap) {
    brush.active = active;
    for i in range(len(brush.faces)) {
        bsp.faces[brush.faces[i]].hidden = not active or brush.hidden[i];
    }
    for h in brush.hulls {
        if active {
            collision.set_disabled(h, False);
        } else {
            collision.set_disabled(h, True);
        }
    }
}

def load_brushes(world: World, bsp: Bsp, collision: CollisionMap) {
    if bsp.game != "q2" {
        return;
    }
    for index in range(len(bsp.entities)) {
        fields = bsp.entities[index].fields;
        kind = fields.get("classname", "");
        flags = int(fields.get("spawnflags", "0"));
        if kind != "func_explosive" and (kind != "func_wall" or flags & 7 == 0) {
            continue;
        }
        reference = fields.get("model", "");
        if not reference.startswith("*") {
            continue;
        }
        model = int(reference[1:]);
        if model <= 0 or model >= len(bsp.models) {
            raise ValueError("Invalid interactive brush model");
        }
        record = bsp.models[model];
        brush = BrushObject(
            model=model,
            kind=kind,
            center=model_bounds(bsp, model).center(),
            active=flags & 4 != 0 if kind == "func_wall" else flags & 1 == 0,
            toggle=kind == "func_wall" and flags & 6 != 0,
            spawn_only=kind == "func_explosive" and flags & 1 != 0,
            shootable=kind == "func_explosive"
                and (flags & 1 != 0 or not fields.get("targetname", "")),
            health=int(fields.get("health", "100")) or 100,
            damage=max(0, int(fields.get("dmg", "0"))),
            activation=Signal(entities=[index]),
            faces=list(range(record.first_face, record.first_face + record.face_count))
        );
        brush.hidden = [bsp.faces[face].hidden for face in brush.faces];
        brush.hulls = [
            h
            for h in range(len(collision.models))
            if collision.models[h] == model
        ];
        show_brush(brush, brush.active, bsp, collision);
        world +>:HasBrush:+> brush;
        world +>:HasSignal:+> brush.activation;
    }
}

# World traces exclude the removed brush before blast visibility is tested.
def destroy_brush(
    world: World,
    brush: BrushObject,
    bsp: Bsp,
    collision: CollisionMap,
    player: Player,
    state: CombatState,
    credit: bool
) {
    if brush.destroyed {
        return;
    }
    brush.destroyed = True;
    brush.health = 0;
    show_brush(brush, False, bsp, collision);
    if brush.damage > 0 {
        actors: list[Player] = [player];
        actors.extend(
            [
                enemy
                for enemy in [world->:HasOpponent:->][?:Opponent]
                if not enemy.dormant
            ]
        );
        for actor in actors {
            if actor.health <= 0 {
                continue;
            }
            center = actor.pos.sub(Vec3(z=collision.eye_height - 4.0));
            distance = center.sub(brush.center).length();
            if distance > float(brush.damage) + 40.0 {
                continue;
            }
            sight = collision.trace_point(brush.center, center);
            if sight.start_solid or sight.fraction < 1.0 {
                continue;
            }
            amount = int(max(0.0, float(brush.damage) - 0.5 * distance));
            if actor is player and credit {
                amount = int(float(amount) * 0.5);
            }
            if isinstance(actor, Opponent) {
                damage_opponent(
                    actor,
                    amount,
                    player.inventory if credit else None,
                    state if credit else None
                );
            } else {
                actor spawn Damage(amount=amount);
            }
        }
    }
    if brush.damage > 0 {
        for other in [world->:HasBrush:->][?:BrushObject] {
            if other.destroyed or not other.active or not other.shootable {
                continue;
            }
            distance = other.center.sub(brush.center).length();
            if distance > float(brush.damage) + 40.0 {
                continue;
            }
            sight = collision.trace(
                brush.center, other.center, exclude=other.hulls, point=True
            );
            if sight.start_solid or sight.fraction < 1.0 {
                continue;
            }
            other.health = max(
                0, other.health - int(max(0.0, float(brush.damage) - 0.5 * distance))
            );
            if other.health == 0 {
                destroy_brush(world, other, bsp, collision, player, state, credit);
            }
        }
    }
    brush.activation spawn Fire(inventory=player.inventory if credit else None);
}

walker BrushTick {
    has bsp: Bsp,
        collision: CollisionMap,
        player: Player,
        state: CombatState,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        visit [here->:HasBrush:->];
    }

    can use with BrushObject entry {
        world = self.world;
        # killtarget removes the brush without any explosion.
        if here.activation.killed and not here.destroyed {
            here.destroyed = True;
            show_brush(here, False, self.bsp, self.collision);
        }
        if world is None or here.destroyed or not here.usable {
            here.activation.pending = 0;
            return;
        }
        requests = here.activation.pending;
        here.activation.pending = 0;
        for i in range(requests) {
            if here.destroyed or not here.usable {
                break;
            }
            if here.kind == "func_wall" or here.spawn_only {
                show_brush(here, not here.active, self.bsp, self.collision);
                if not here.toggle {
                    here.usable = False;
                }
                if here.active {
                    origin = self.player.pos.sub(Vec3(z=self.collision.eye_height));
                    for h in here.hulls {
                        local = origin.sub(self.collision.offsets[h]);
                        hit = self.collision.hulls[h] spawn Sweep(
                            start=local, finish=local
                        );
                        if hit.result.start_solid {
                            self.player spawn Damage(
                                amount=100000,
                                bypass_armor=True,
                                bypass_protection=True
                            );
                            break;
                        }
                    }
                }
            } else {
                destroy_brush(
                    world,
                    here,
                    self.bsp,
                    self.collision,
                    self.player,
                    self.state,
                    False
                );
            }
        }
    }
}

walker ShootBrush {
    has model: int,
        amount: int,
        bsp: Bsp,
        collision: CollisionMap,
        player: Player,
        state: CombatState,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        visit [here->:HasBrush:->];
    }

    can hit with BrushObject entry {
        world = self.world;
        if world is None
            or here.model != self.model
            or not here.active
            or here.destroyed
            or not here.shootable {
            return;
        }
        here.health = max(0, here.health - max(0, self.amount));
        if here.health == 0 {
            destroy_brush(
                world, here, self.bsp, self.collision, self.player, self.state, True
            );
        }
    }
}

# Projectile splash reaches brushes only when there is a clear path to them.
walker BlastBrush {
    has origin: Vec3,
        amount: int,
        radius: float,
        bsp: Bsp,
        collision: CollisionMap,
        player: Player,
        state: CombatState,
        energy_burst: bool = False,
        world: World | None = None;

    can begin with World entry {
        self.world = here;
        visit [here->:HasBrush:->];
    }

    can hit with BrushObject entry {
        world = self.world;
        if world is None or not here.active or here.destroyed or not here.shootable {
            return;
        }
        distance = here.center.sub(self.origin).length();
        if distance >= self.radius {
            return;
        }
        trace = self.collision.trace(
            self.origin, here.center, exclude=here.hulls, point=True
        );
        if trace.start_solid or trace.fraction < 1.0 {
            return;
        }
        if self.energy_burst {
            owner_sight = self.collision.trace(
                self.player.pos, here.center, exclude=here.hulls, point=True
            );
            if owner_sight.start_solid or owner_sight.fraction < 1.0 {
                return;
            }
        }
        strength = blast_strength(
            self.bsp.game, self.amount, self.radius, distance, self.energy_burst
        );
        here.health = max(0, here.health - int(strength));
        if here.health == 0 {
            destroy_brush(
                world, here, self.bsp, self.collision, self.player, self.state, True
            );
        }
    }
}
