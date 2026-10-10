"""What becomes of the player's own body once its health is gone: how it lies
and moves, when its buttons bring the player back, and when it bursts. The
world runs on around it, and it touches nothing in it.

Q1 player.qc PlayerDie, GibPlayer and ThrowHead with client.qc
PlayerDeathThink and sv_phys.c SV_Physics_Toss; Q2 p_client.c player_die,
ThrowClientHead and ClientBeginServerFrame's dead branch with pmove.c's
PM_DEAD and PM_GIB; Q3 g_combat.c player_die, body_die and GibEntity with
bg_pmove.c PM_DeadMove and g_active.c ClientThink_real."""
import from .world { World, Player }
import from .gibs { GibRule, GibDice, gibs_at, gib_velocity, throw_gibs }
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
    # Bursting. `gibs` names the pieces and the health that throws them; a
    # `shootable` body is still hit once dead (Q2 player_die leaves it
    # DAMAGE_YES, Q3 body_die) and bursts when that takes it there. The
    # player then rides what is left in the `head` form. Q1 ThrowHead throws
    # the player as the head: a new velocity, MOVETYPE_BOUNCE keeping
    # `head_bounce` of its speed off each surface, the eye 8 above the box's
    # foot. Q2 ThrowClientHead adds the throw to its speed and moves it as
    # PM_GIB: a 16 unit box resting on an origin 32 higher, the eye 8 above
    # that, without the dead drag. Q3 GibEntity only hides the body.
    has gibs: GibRule | None = None,
        shootable: bool = False,
        head: BodyForm = BodyForm(eye_height=-8.0),
        head_thrown: bool = False,
        head_keeps_speed: bool = False,
        head_bounce: float = 0.0,
        head_drags: bool = True;
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
        gibbed: bool = False,
        held: bool = True,
        released: bool = False,
        latched: bool = False,
        roll: int = 1;

    """random(), from the body's own stream."""
    def random -> float {
        self.roll = (self.roll * 48271) % 2147483647;
        return float(self.roll) / 2147483647.0;
    }

    """Whether shots still strike the body."""
    def struck -> bool {
        return self.dead and self.rule.shootable and not self.gibbed;
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

"""Whether the player lies dead where shots still strike the body."""
def body_struck(player: Player) -> bool {
    for fallen in [player->:HasMortality:->][?:Mortality] {
        if fallen.struck() {
            return True;
        }
    }
    return False;
}

"""Whether the player's body has burst."""
def body_gibbed(player: Player) -> bool {
    for fallen in [player->:HasMortality:->][?:Mortality] {
        if fallen.dead and fallen.gibbed {
            return True;
        }
    }
    return False;
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
        fallen.gibbed = False;
        fallen.clock = 0.0;
    }
    player.crouched = False;
    take_form(player, collision, BodyForm(eye_height=profile.stand_eye_height));
}

"""Q1 and Q2 VelocityForDamage as ThrowHead and ThrowClientHead use it for
the player; Q2's is not held to a gib's limits (ClipGibVelocity)."""
def head_velocity(style: str, overkill: int, dice: GibDice) -> Vec3 {
    if style != "q2" {
        return gib_velocity(style, overkill, dice);
    }
    return Vec3(
        x=100.0 * dice.signed(), y=100.0 * dice.signed(), z=200.0 + 100.0 * dice.roll()
    ).scale(0.7 if overkill < 50 else 1.2);
}

"""One fixed step of the dead player's body. The first one is the death
itself (PlayerDie, player_die): the body takes its lying form, a Q1 body is
kicked off the ground and its death sequence chosen. A killing blow past the
gib health bursts it there, as does later damage to a body still shootable:
the pieces fly into `world` and the player rides the head. Then it moves:
tossed (Q1) or by the player's move with no command (Q2, Q3). `weapon` is
the weapon in hand at death, `water_depth` and `current` what the body lies
in (Level.immersion). `died` and `burst` report this step's death and
gibbing, `thrown` the pieces thrown."""
walker LieDead {
    has collision: CollisionMap,
        profile: MovementProfile,
        dt: float,
        world: World | None = None,
        weapon: str = "",
        water_depth: int = 0,
        current: Vec3 = Vec3(),
        died: bool = False,
        burst: bool = False,
        thrown: int = 0;

    can lie with Player entry {
        if here.health > 0 or self.dt <= 0.0 {
            return;
        }
        fallen = mortality_of(here);
        rule = fallen.rule;
        if not fallen.dead {
            self.fall(here, fallen);
        }
        fallen.clock += self.dt;
        if not fallen.gibbed
            and (self.died or rule.shootable)
            and gibs_at(rule.gibs, -here.death_overkill) {
            self.burst_body(here, fallen);
        }
        if rule.tossed {
            self.toss(here, fallen);
            return;
        }
        if here.grounded and (rule.head_drags or not fallen.gibbed) {
            self.drag(here, rule.drag);
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
        fallen.gibbed = False;
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
        # GibPlayer is DEAD_DEAD at once; otherwise PlayerDead ends one of
        # the death sequences, picked as PlayerDie does.
        if rule.sequences and not gibs_at(rule.gibs, -body.death_overkill) {
            choice = min(len(rule.sequences) - 1, int(fallen.random() * float(len(rule.sequences))));
            fallen.ready += rule.weapon_sequences.get(self.weapon, rule.sequences[choice]);
        }
    }

    """GibPlayer, player_die's gib branch and GibEntity: the pieces fly and
    the player rides the head."""
    def burst_body(body: Player, fallen: Mortality) {
        rule = fallen.rule;
        gibs = rule.gibs;
        if gibs is None {
            return;
        }
        world = self.world;
        seed = int(fallen.random() * 2147483646.0) + 1;
        if world is not None {
            self.thrown = throw_gibs(
                world,
                body,
                gibs,
                body.pos.sub(Vec3(z=self.collision.eye_height)),
                body.death_overkill,
                seed,
                body.velocity
            );
        }
        fallen.gibbed = True;
        self.burst = True;
        if rule.head_thrown {
            flung = head_velocity(
                gibs.style,
                body.death_overkill,
                GibDice(seed=int(fallen.random() * 2147483646.0) + 1)
            );
            body.velocity = body.velocity.add(flung) if rule.head_keeps_speed else flung;
            body.grounded = False;
        }
        take_form(body, self.collision, rule.head);
    }

    """PlayerDeathThink / PM_DeadMove: the extra friction of a body on the
    ground."""
    def drag(body: Player, amount: float) {
        speed = body.velocity.length() - amount;
        body.velocity = body.velocity.normalized().scale(speed) if speed > 0.0 else Vec3();
    }

    """SV_Physics_Toss: gravity, one straight move, and off whatever it hits
    (MOVETYPE_TOSS keeps none of its speed into the surface, the bouncing
    head `head_bounce` of it). A floor stops the body for good, and the head
    once it leaves it slower than 60."""
    def toss(body: Player, fallen: Mortality) {
        if body.grounded {
            self.drag(body, fallen.rule.drag);
            return;
        }
        bounce = fallen.rule.head_bounce if fallen.gibbed else 0.0;
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
        body.velocity = body.velocity.sub(
            hit.normal.scale(body.velocity.dot(hit.normal) * (1.0 + bounce))
        );
        if hit.normal.z > 0.7 and (bounce <= 0.0 or body.velocity.z < 60.0) {
            body.velocity = Vec3();
            body.grounded = True;
        }
    }
}
