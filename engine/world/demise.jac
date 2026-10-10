"""What becomes of the player's own body once its health is gone: how it lies
and moves, and when its buttons bring the player back. The world runs on
around it, and it touches nothing in it.

Q1 player.qc PlayerDie with client.qc PlayerDeathThink and sv_phys.c
SV_Physics_Toss; Q2 p_client.c player_die and ClientBeginServerFrame's dead
branch with pmove.c's PM_DEAD; Q3 g_combat.c player_die with bg_pmove.c
PM_DeadMove and g_active.c ClientThink_real."""
import from .world { Player }
import from ..physics.collision { CollisionMap }
import from ..physics.movement { MovementProfile, MovePlayer }
import from ..math.vec3 { Vec3 }

"""How a body occupies the world: how far its box's top is lowered, where its
eye sits from its origin, and how far the origin rises on taking this form."""
obj BodyForm {
    has top_drop: float = 0.0,
        eye_height: float = 22.0,
        lift: float = 0.0;
}

"""One game's rules for a dead player."""
obj DeathRule {
    # The body lying dead. Q1 PlayerDie keeps the box and puts the eye 8
    # below the origin (view_ofs); Q2 PM_DEAD is ducked (maxs 4, viewheight
    # -2); Q3 PM_CheckDuck gives it maxs -8 and DEAD_VIEWHEIGHT.
    has lying: BodyForm = BodyForm(eye_height=-8.0);
    # Its motion. Q1 tosses it (MOVETYPE_TOSS: it falls, and stops dead on
    # the first floor), lifted by up to `kick` if it was rising slower than
    # 10; Q2 and Q3 go on running the player's move with no command. On the
    # ground each move takes `drag` off its speed (PlayerDeathThink,
    # PM_DeadMove).
    has tossed: bool = False,
        kick: float = 0.0,
        drag: float = 20.0;
    # Coming back. The buttons count once the body has been dead `delay`
    # seconds (Q2 respawn_time, Q3 respawnTime) and, in Q1, one of its death
    # `sequences` has played out (deadflag DEAD_DEAD; `weapon_sequences`
    # names the one a weapon in hand picks, the axe's). Q1 then wants every
    # button let go before one pressed counts (DEAD_RESPAWNABLE); Q2 takes
    # any button going down, the delay included (latched_buttons); Q3 a
    # button held, and brings the player back by itself `forced` seconds on
    # (g_forcerespawn). `any_key` counts every key as a button (Q2
    # BUTTON_ANY). `looks` leaves the view to the mouse (Q1); Q2 and Q3 fix
    # it.
    has delay: float = 0.0,
        sequences: list[float] = [],
        weapon_sequences: dict[str, float] = {},
        release_first: bool = False,
        latches: bool = False,
        forced: float = 0.0,
        any_key: bool = False,
        looks: bool = False;
}

edge HasMortality: Player --> Mortality {}

"""The player's death: its game's rule, and how the body lies while dead.
`clock` counts the seconds dead and `ready` is when the buttons begin to
count."""
node Mortality {
    has rule: DeathRule = DeathRule(),
        dead: bool = False,
        clock: float = 0.0,
        ready: float = 0.0,
        held: bool = True,
        released: bool = False,
        latched: bool = False,
        roll: int = 1;

    """random(), from the body's own stream."""
    def random -> float {
        self.roll = (self.roll * 48271) % 2147483647;
        return float(self.roll) / 2147483647.0;
    }

    """This frame's buttons (`held`: any of them down). True once they bring
    the player back: Q1 PlayerDeathThink, Q2 ClientBeginServerFrame, Q3
    ClientThink_real."""
    def wants_back(held: bool) -> bool {
        if not self.dead {
            return False;
        }
        rule = self.rule;
        pressed = held and not self.held;
        self.held = held;
        if self.clock <= self.ready {
            if rule.latches and pressed {
                self.latched = True;
            }
            return False;
        }
        if rule.forced > 0.0 and self.clock - self.ready > rule.forced {
            return True;
        }
        if rule.release_first {
            if not self.released {
                self.released = not held;
                return False;
            }
            return held;
        }
        if rule.latches {
            return pressed or self.latched;
        }
        return held;
    }
}

"""Whether the player is in the world to touch things: walking it rather than
flying through it, not `away` at an intermission or finale camera, and alive.
The dead touch no trigger, item, exit, teleporter, hazard or door field: Q1
PlayerDie makes the body SOLID_NOT, and Q2 and Q3 G_TouchTriggers pass over
the dead ("dead things don't activate triggers")."""
def in_touch(player: Player, walking: bool, away: bool = False) -> bool {
    return walking and not away and player.health > 0;
}

"""The player's death, with the default rule until its game's is given."""
def mortality_of(player: Player) -> Mortality {
    found = [player->:HasMortality:->][?:Mortality];
    if found {
        return found[0];
    }
    fallen = Mortality();
    player +>:HasMortality:+> fallen;
    return fallen;
}

"""Put the body in `form`, its origin where it was (raised by the form's
lift)."""
def take_form(body: Player, collision: CollisionMap, form: BodyForm) {
    origin = body.pos.sub(Vec3(z=collision.eye_height - form.lift));
    collision.top_drop = form.top_drop;
    collision.eye_height = form.eye_height;
    body.pos = origin.add(Vec3(z=form.eye_height));
}

"""The player is alive again (Q3 ClientSpawn): the death is over and the body
stands, its origin where it was."""
def stand_again(player: Player, collision: CollisionMap, profile: MovementProfile) {
    for fallen in [player->:HasMortality:->][?:Mortality] {
        fallen.dead = False;
        fallen.clock = 0.0;
    }
    player.crouched = False;
    take_form(player, collision, BodyForm(eye_height=profile.stand_eye_height));
}

"""One fixed step of the dead player's body. The first one is the death
itself (PlayerDie, player_die): the body takes its lying form, a Q1 body is
kicked off the ground and its death sequence chosen. Then it moves: tossed
(Q1) or by the player's move with no command (Q2, Q3). `weapon` is the
weapon in hand at death, `water_depth` and `current` what the body lies in
(Level.immersion). `died` reports that this step was the death."""
walker LieDead {
    has collision: CollisionMap,
        profile: MovementProfile,
        dt: float,
        weapon: str = "",
        water_depth: int = 0,
        current: Vec3 = Vec3(),
        died: bool = False;

    can lie with Player entry {
        if here.health > 0 or self.dt <= 0.0 {
            return;
        }
        fallen = mortality_of(here);
        if not fallen.dead {
            self.fall(here, fallen);
        }
        fallen.clock += self.dt;
        if fallen.rule.tossed {
            self.toss(here, fallen);
            return;
        }
        if here.grounded {
            self.drag(here, fallen.rule.drag);
        }
        here spawn MovePlayer(
            collision=self.collision,
            water_depth=self.water_depth,
            current=self.current,
            profile=self.profile,
            dt=self.dt
        );
    }

    """PlayerDie / player_die: the moment of death."""
    def fall(body: Player, fallen: Mortality) {
        rule = fallen.rule;
        self.died = True;
        fallen.dead = True;
        fallen.clock = 0.0;
        fallen.held = True;
        fallen.released = False;
        fallen.latched = False;
        take_form(body, self.collision, rule.lying);
        body.crouched = False;
        # Its random stream starts from where it fell, so deaths differ.
        fallen.roll = 1
            + (
                fallen.roll * 31
                    + int(abs(body.pos.x) * 8.0) * 7919
                    + int(abs(body.pos.y) * 8.0) * 104729
                    + int(abs(body.yaw) * 1000.0)
            )
                % 2147483646;
        fallen.random();
        if rule.tossed {
            # PlayerDie clears FL_ONGROUND and adds random() * 300 upward to
            # a body rising slower than 10.
            body.grounded = False;
            if body.velocity.z < 10.0 {
                body.velocity.z += fallen.random() * rule.kick;
            }
        }
        fallen.ready = rule.delay;
        # PlayerDead ends one of the death sequences, picked as PlayerDie
        # does.
        if rule.sequences {
            choice = min(len(rule.sequences) - 1, int(fallen.random() * float(len(rule.sequences))));
            fallen.ready += rule.weapon_sequences.get(self.weapon, rule.sequences[choice]);
        }
    }

    """PlayerDeathThink / PM_DeadMove: the extra friction of a body on the
    ground."""
    def drag(body: Player, amount: float) {
        speed = body.velocity.length() - amount;
        body.velocity = body.velocity.normalized().scale(speed) if speed > 0.0 else Vec3();
    }

    """SV_Physics_Toss: gravity, one straight move, and off whatever it hits
    with none of its speed into the surface. A floor stops it for good."""
    def toss(body: Player, fallen: Mortality) {
        if body.grounded {
            self.drag(body, fallen.rule.drag);
            return;
        }
        start = body.pos.sub(Vec3(z=self.collision.eye_height));
        body.velocity.z -= self.profile.gravity * self.dt;
        hit = self.collision.trace(start, start.add(body.velocity.scale(self.dt)));
        if hit.start_solid {
            body.velocity = Vec3();
            body.grounded = True;
            return;
        }
        body.pos = hit.end.add(Vec3(z=self.collision.eye_height));
        if hit.fraction >= 1.0 {
            return;
        }
        body.velocity = body.velocity.sub(hit.normal.scale(body.velocity.dot(hit.normal)));
        if hit.normal.z > 0.7 {
            body.velocity = Vec3();
            body.grounded = True;
        }
    }
}
