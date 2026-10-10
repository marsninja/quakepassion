"""The player's own death: the world running on around the body, the body
touching nothing, how it lies and moves in each game, the buttons that bring
the player back, and the body's gibs with the head the player then rides."""
import math;
import from games.deaths { death_rule, prepare_death }
import from engine.world.demise {
    Mortality,
    HasMortality,
    LieDead,
    mortality_of,
    in_touch,
    stand_again,
    body_struck,
    body_gibbed
}
import from engine.world.world { World, Player, Area, move_to_area }
import from engine.world.gibs { Gib, HasGib, GibsInto }
import from engine.world.models { ModelResource }
import from engine.world.vitals { VoiceTick, q3_gibbed }
import from engine.world.body_queue { NoDropSpace, HasNoDrop, in_no_drop }
import from engine.world.reflection { HasBody, player_body, show_body, follow_body }
import from engine.world.player_rig { dress_rig, rig_clips }
import from engine.formats.animated { AnimatedModel }
import from engine.math.aabb { AABB }
import from engine.world.combat {
    CombatState,
    CombatTick,
    Opponent,
    HasOpponent,
    Projectile,
    HasProjectile,
    ProjectileTick,
    line_of_fire,
    blast_actors,
    brutal_toward,
    current_profile
}
import from games.enemies { enemy_rule }
import from engine.world.doors { Door, HasDoor, DoorTick }
import from engine.world.triggers { TouchTrigger, HasTrigger, TriggerTick }
import from engine.world.exits { LevelExit, HasExit, ExitTick }
import from engine.world.pickups { Pickup, HasPickup, PickupRule, PickupTick }
import from engine.world.traversal { Traversal, Destination, HasTraversal, ArrivesAt, TraversalTick }
import from engine.world.hazards { Hazard, HasHazard, HazardTick }
import from engine.world.inventory { quantity }
import from engine.world.damage { Damage }
import from engine.physics.collision { CollisionMap }
import from engine.physics.movement { movement_profile }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture }

glob TICK: float = 1.0 / 120.0;

"""A player with its game's death, standing (its origin) at `origin`."""
def mortal(game: str, origin: Vec3 = Vec3(z=24.0)) -> Player {
    player = Player(pos=origin.add(Vec3(z=movement_profile(game).stand_eye_height)));
    prepare_death(player, game);
    return player;
}

"""A floor whose top is at z = 0, under the player's box."""
def death_floor(game: str) -> CollisionMap {
    collision = CollisionMap(eye_height=movement_profile(game).stand_eye_height);
    collision.add_box(
        Vec3(x=-1000.0, y=-1000.0, z=-64.0),
        Vec3(x=1000.0, y=1000.0, z=0.0),
        Vec3(),
        Vec3(x=-16.0, y=-16.0, z=-24.0),
        Vec3(x=16.0, y=16.0, z=32.0)
    );
    collision.reindex();
    return collision;
}

def unit_box -> CollisionMap {
    volume = CollisionMap();
    volume.add_box(
        Vec3(x=-8.0, y=-8.0, z=-8.0), Vec3(x=8.0, y=8.0, z=8.0), Vec3(), Vec3(), Vec3()
    );
    volume.reindex();
    return volume;
}

"""Run the dead body for `seconds`."""
def lie(player: Player, collision: CollisionMap, game: str, seconds: float, weapon: str = "") {
    for tick in range(int(seconds / TICK + 0.5)) {
        player spawn LieDead(
            collision=collision, profile=movement_profile(game), dt=TICK, weapon=weapon
        );
    }
}

test "a door finishes its close over a dead player lying in its field" {
    for game in ["q1", "q2"] {
        fixture = DoorFixture();
        fixture.setup(game);
        door = [fixture.world->:HasDoor:->][?:Door][0];
        for i in range(25) {
            fixture.tick(Vec3(x=60.0, z=24.0));
        }
        assert door.state == "open";
        # Alive, the player standing there holds it open.
        for i in range(40) {
            fixture.tick(Vec3(x=60.0, z=24.0));
        }
        assert door.state == "open";
        fixture.player.health = 0;
        for i in range(40) {
            fixture.world spawn DoorTick(
                bsp=fixture.bsp,
                collision=fixture.collision,
                player_origin=Vec3(x=60.0, z=24.0),
                dt=0.05,
                touching=in_touch(fixture.player, True),
                player=fixture.player
            );
        }
        assert door.state == "closed" and door.position == 0.0;
    }
}

test "a monster's missile in flight lands after the player has died" {
    world = World();
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=200.0, y=-100.0, z=-100.0), Vec3(x=210.0, y=100.0, z=100.0), Vec3(), Vec3(), Vec3()
    );
    collision.reindex();
    # The Q1 body is SOLID_NOT: the nail flies on through where it lies.
    player = Player(pos=Vec3(x=100.0, z=22.0), health=0);
    state = CombatState(game="q1");
    nail = Projectile(pos=Vec3(z=22.0), velocity=Vec3(x=600.0), damage=9, hostile=True);
    world +>:HasProjectile:+> nail;
    furthest = 0.0;
    for tick in range(120) {
        world spawn ProjectileTick(player=player, collision=collision, state=state, dt=TICK);
        furthest = max(furthest, nail.pos.x);
    }
    assert not [world->:HasProjectile:->][?:Projectile] and len(state.impacts) == 1;
    assert furthest > 190.0 and furthest <= 200.0 and player.death_overkill == 0;
}

test "a monster whose enemy has died goes back to standing and takes no new one" {
    for game in ["q1", "q2"] {
        world = World();
        # Facing the player: idle monsters only notice what is in front of them.
        enemy = Opponent(pos=Vec3(x=300.0), attack_wait=10.0, yaw=3.14159, game=game);
        world +>:HasOpponent:+> enemy;
        player = Player();
        collision = CollisionMap();
        state = CombatState(game=game);
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
        assert enemy.alert > 0.0 and enemy.pursuing and enemy.steering.x < 0.0;
        player.health = 0;
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
        assert enemy.alert == 0.0 and not enemy.pursuing and not enemy.sighted;
        assert enemy.steering.length() == 0.0 and enemy.pose_name == "stand";
        # ai.qc / g_ai.c FindTarget: a dead client is nobody to get mad at.
        for tick in range(30) {
            world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
        }
        assert enemy.alert == 0.0 and not enemy.pursuing and enemy.pose_name == "stand";
        # An attack it was turning to make is called off.
        enemy.readied = 0;
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
        assert enemy.readied == -1 and enemy.attack_clock < 0.0;
    }
}

test "a dead player touches no trigger, item, exit, teleporter, hazard or door field" {
    for game in ["q1", "q2", "q3"] {
        alive = mortal(game);
        body = mortal(game);
        body spawn Damage(amount=500);
        assert in_touch(alive, True) and not in_touch(alive, False) and not in_touch(alive, True, True);
        assert body.health == 0 and not in_touch(body, True);
        for player in [body, alive] {
            touching = in_touch(player, True);
            world = World();
            # A trigger.
            trigger = TouchTrigger(model=1, volume=unit_box(), interval=0.2);
            world +>:HasTrigger:+> trigger;
            world spawn TriggerTick(
                start=Vec3(), finish=Vec3(), dt=0.01, touching=touching, player=player
            );
            assert trigger.activations == (1 if touching else 0);
            # A trigger_hurt.
            world +>:HasHazard:+> Hazard(volume=unit_box(), damage=10);
            before = player.health;
            burnt = world spawn HazardTick(
                player=player, start=Vec3(), finish=Vec3(), dt=0.01, touching=touching
            );
            assert burnt.dealt == (10 if touching else 0);
            player.health = before;
            # An item.
            item = Pickup(rule=PickupRule(kind="shells", amount=10, capacity=100, model=""));
            world +>:HasPickup:+> item;
            world spawn PickupTick(
                player=player, start=Vec3(), finish=Vec3(), dt=0.1, game=game, touching=touching
            );
            assert item.active == (not touching);
            assert quantity(player.inventory, "shells") == (10 if touching else 0);
            # An exit.
            world +>:HasExit:+> LevelExit(destination="next", contact=True, volume=unit_box());
            leaving = world spawn ExitTick(
                start=Vec3(x=-20.0), finish=Vec3(x=20.0), dt=0.01, touching=touching
            );
            assert leaving.request == ("next" if touching else "");
            # A teleporter.
            gate = Traversal(volume=unit_box(), kind="teleport");
            gate +>:ArrivesAt:+> Destination(origin=Vec3(x=500.0));
            world +>:HasTraversal:+> gate;
            where = player.pos.add(Vec3());
            player.pos = Vec3(z=22.0);
            world spawn TraversalTick(
                player=player, collision=CollisionMap(), start=Vec3(), dt=0.01, touching=touching
            );
            assert gate.activations == (1 if touching else 0);
            assert (player.pos.x == 500.0) == touching;
            player.pos = where;
        }
    }
}

test "the Q1 body is tossed: kicked up, falling, and stopped dead by the floor" {
    collision = death_floor("q1");
    player = mortal("q1");
    player.velocity = Vec3(x=120.0);
    player.grounded = True;
    player.health = 0;
    lie(player, collision, "q1", TICK);
    fallen = mortality_of(player);
    # PlayerDie: SOLID_NOT in its standing box, the eye 8 below the origin,
    # off the ground with up to 300 more upward speed.
    assert fallen.dead and collision.top_drop == 0.0 and collision.eye_height == -8.0;
    origin = player.pos.z - collision.eye_height;
    assert origin > 24.0 and origin < 26.0 and not player.grounded;
    assert player.velocity.z > 0.0 and player.velocity.z < 300.0 and player.velocity.x == 120.0;
    peak = player.pos.z;
    for tick in range(240) {
        lie(player, collision, "q1", TICK);
        peak = max(peak, player.pos.z);
    }
    # SV_Physics_Toss: it keeps its sideways speed in the air, and the first
    # floor stops it for good.
    assert peak > 17.0 and player.grounded and player.velocity.length() == 0.0;
    assert abs(player.pos.z - 16.0) < 0.2 and player.pos.x > 20.0;
    rest = player.pos.x;
    lie(player, collision, "q1", 0.5);
    assert player.pos.x == rest;
    # A body already rising faster than 10 gets no kick.
    flying = mortal("q1");
    flying.velocity = Vec3(z=50.0);
    flying.health = 0;
    air = death_floor("q1");
    flying spawn LieDead(collision=air, profile=movement_profile("q1"), dt=TICK);
    assert abs(flying.velocity.z - (50.0 - 800.0 * TICK)) < 0.0001;
}

test "Q2 and Q3 bodies lie in their dead boxes and slide to a stop by the player's move" {
    forms = {"q2": [28.0, -2.0], "q3": [40.0, -16.0]};
    for game in ["q2", "q3"] {
        collision = death_floor(game);
        player = mortal(game);
        player.grounded = True;
        player.velocity = Vec3(x=300.0);
        player.health = 0;
        lie(player, collision, game, TICK);
        # Q2 PM_DEAD is ducked (maxs 4, viewheight -2); Q3 PM_CheckDuck gives
        # maxs -8 and DEAD_VIEWHEIGHT.
        assert collision.top_drop == forms[game][0] and collision.eye_height == forms[game][1];
        assert abs(player.pos.z - (24.0 + forms[game][1])) < 0.3;
        # PM_DeadMove: 20 off the speed each move, besides the ground's friction.
        assert player.velocity.x < 280.0 and player.velocity.x > 250.0 and player.grounded;
        lie(player, collision, game, 0.5);
        assert player.velocity.length() == 0.0 and player.pos.x > 5.0 and player.pos.x < 40.0;
        # Dead in the air, it falls like the living.
        falling = mortal(game, Vec3(z=200.0));
        falling.health = 0;
        air = death_floor(game);
        lie(falling, air, game, 0.25);
        assert not falling.grounded and falling.velocity.z < -150.0;
        lie(falling, air, game, 1.0);
        assert falling.grounded and abs(falling.pos.z - (24.0 + forms[game][1])) < 0.3;
        # Q3 ClientSpawn: alive again, the body stands where it was.
        falling.health = 100;
        stand_again(falling, air, movement_profile(game));
        assert air.top_drop == 0.0 and air.eye_height == movement_profile(game).stand_eye_height;
        assert abs(falling.pos.z - (24.0 + air.eye_height)) < 0.3 and not mortality_of(falling).dead;
    }
}

test "Q1 comes back on a button pressed after its death frames and a release" {
    collision = death_floor("q1");
    player = mortal("q1");
    player.health = 0;
    fallen = mortality_of(player);
    # Nothing counts before the body has fallen.
    assert not fallen.wants_back(True);
    lie(player, collision, "q1", TICK, "axe");
    # player_die_ax1 to ax9: PlayerDead on the ninth frame, 0.8 s in.
    assert abs(fallen.ready - 0.8) < 0.0001;
    lie(player, collision, "q1", 0.7);
    assert not fallen.wants_back(False) and not fallen.wants_back(True);
    lie(player, collision, "q1", 0.2);
    # DEAD_DEAD: a button still held must be let go first (DEAD_RESPAWNABLE).
    assert not fallen.wants_back(True) and not fallen.wants_back(True);
    assert not fallen.wants_back(False);
    assert fallen.wants_back(True);
    # Without the axe one of player_diea1 to player_diee1 plays: 11, 9, 15, 9
    # or 9 frames.
    for seed in range(1, 40) {
        other = mortal("q1");
        mortality_of(other).roll = seed * 7919;
        other.health = 0;
        lie(other, death_floor("q1"), "q1", TICK, "shotgun");
        assert mortality_of(other).ready in [1.0, 0.8, 1.4];
    }
}

test "Q2 comes back on any button pressed, a second after dying at the earliest" {
    collision = death_floor("q2");
    player = mortal("q2");
    player.health = 0;
    lie(player, collision, "q2", TICK);
    fallen = mortality_of(player);
    assert fallen.ready == 1.0 and fallen.rule.any_key;
    # A button held since before the death is no press.
    lie(player, collision, "q2", 1.5);
    assert not fallen.wants_back(True) and not fallen.wants_back(True);
    assert not fallen.wants_back(False);
    assert fallen.wants_back(True);
    # latched_buttons: a press during the wait counts once it is over.
    again = mortal("q2");
    again.health = 0;
    lie(again, collision, "q2", 0.5);
    waiting = mortality_of(again);
    assert not waiting.wants_back(False) and not waiting.wants_back(True);
    assert not waiting.wants_back(False);
    lie(again, collision, "q2", 0.4);
    assert not waiting.wants_back(False);
    lie(again, collision, "q2", 0.2);
    assert waiting.wants_back(False);
}

test "Q3 comes back on a held button after 1.7 s, or by itself 20 s later" {
    collision = death_floor("q3");
    player = mortal("q3");
    player.health = 0;
    lie(player, collision, "q3", 1.6);
    fallen = mortality_of(player);
    assert abs(fallen.ready - 1.7) < 0.0001;
    assert not fallen.wants_back(True);
    lie(player, collision, "q3", 0.2);
    assert fallen.wants_back(True) and not fallen.wants_back(False);
    # g_forcerespawn 20.
    lie(player, collision, "q3", 19.8);
    assert not fallen.wants_back(False);
    lie(player, collision, "q3", 0.3);
    assert fallen.wants_back(False);
    # A new death waits again.
    player.health = 100;
    stand_again(player, collision, movement_profile("q3"));
    assert not fallen.wants_back(True);
    player.health = 0;
    lie(player, collision, "q3", TICK);
    assert fallen.dead and fallen.clock < 0.1 and not fallen.wants_back(True);
}

"""A room for the gibs to fly in, with the death floor under it."""
def gib_room(world: World) -> Area {
    area = Area(
        name="room",
        bounds=AABB(
            mins=Vec3(x=-1000.0, y=-1000.0, z=-1000.0), maxs=Vec3(x=1000.0, y=1000.0, z=1000.0)
        )
    );
    world ++> area;
    return area;
}

"""A player with its game's death, standing in `area` and linked to the
models its body bursts into."""
def gibbable(game: str, area: Area) -> Player {
    player = mortal(game);
    move_to_area(player, area);
    rule = mortality_of(player).rule.gibs;
    assert rule is not None;
    if rule.head {
        player +>:GibsInto:count=1, head=True:+> ModelResource(name="head", model=AnimatedModel(), skins=[]);
    }
    player +>:GibsInto:count=len(rule.pieces):+> ModelResource(name="piece", model=AnimatedModel(), skins=[]);
    return player;
}

test "a blow far enough past zero throws the player's own gibs, at each game's health" {
    # GibPlayer gib1 to gib3; player_die four sm_meat; CG_GibPlayer the skull
    # and ten pieces.
    pieces = {"q1": 3, "q2": 4, "q3": 11};
    for game in ["q1", "q2", "q3"] {
        world = World();
        area = gib_room(world);
        # Q1 and Q2 gib below -40 health, Q3 at GIB_HEALTH (-40).
        edge_case = gibbable(game, area);
        edge_case spawn Damage(amount=140, bypass_armor=True);
        first = edge_case spawn LieDead(
            collision=death_floor(game), profile=movement_profile(game), dt=TICK, world=world
        );
        assert first.died and first.burst == (game == "q3");
        assert mortality_of(edge_case).gibbed == (game == "q3");
        for gib in [world->:HasGib:->][?:Gib] {
            world del --> gib;
        }
        player = gibbable(game, area);
        player.velocity = Vec3(x=120.0);
        player spawn Damage(amount=141, bypass_armor=True);
        assert player.health == 0 and player.death_overkill == 41;
        tick = player spawn LieDead(
            collision=death_floor(game), profile=movement_profile(game), dt=TICK, world=world
        );
        assert tick.died and tick.burst and tick.thrown == pieces[game];
        assert len([world->:HasGib:->][?:Gib]) == pieces[game];
        assert mortality_of(player).gibbed and body_gibbed(player) and not body_struck(player);
        # A body that has burst bursts no more.
        player spawn Damage(amount=500);
        again = player spawn LieDead(
            collision=death_floor(game), profile=movement_profile(game), dt=TICK, world=world
        );
        assert not again.burst and len([world->:HasGib:->][?:Gib]) == pieces[game];
    }
}

test "the Q1 player is the head: thrown anew, bouncing, the eye 8 above its foot" {
    world = World();
    area = gib_room(world);
    collision = death_floor("q1");
    player = gibbable("q1", area);
    player.velocity = Vec3(x=120.0);
    player spawn Damage(amount=160, bypass_armor=True);
    player spawn LieDead(collision=collision, profile=movement_profile("q1"), dt=TICK, world=world);
    fallen = mortality_of(player);
    # ThrowHead: the box as it stood (-16 -16 0 to 16 16 56 about an origin
    # 24 lower), view_ofs 8 above it, and VelocityForDamage in place of the
    # speed it had: -60 health doubles it.
    assert collision.top_drop == 0.0 and collision.eye_height == -16.0;
    assert abs(player.velocity.x) <= 200.0 and abs(player.velocity.y) <= 200.0;
    assert player.velocity.z > 380.0 and player.velocity.z <= 600.0 and not player.grounded;
    # GibPlayer: deadflag DEAD_DEAD at once, with no death frames to wait out.
    assert fallen.ready == 0.0;
    assert not fallen.wants_back(False) and fallen.wants_back(True);
    # MOVETYPE_BOUNCE: off the floor again with half its speed, until it
    # leaves it slower than 60.
    bounces = 0;
    peak = 0.0;
    for tick in range(120 * 8) {
        falling = player.velocity.z < 0.0;
        player spawn LieDead(collision=collision, profile=movement_profile("q1"), dt=TICK, world=world);
        if falling and player.velocity.z > 0.0 {
            bounces += 1;
        }
        peak = max(peak, player.pos.z);
    }
    assert bounces >= 2 and peak > 80.0;
    assert player.grounded and player.velocity.length() == 0.0;
    # At rest the camera is 8 units off the floor.
    assert abs(player.pos.z - 8.0) < 0.3;
}

test "the Q2 player rides its head as PM_GIB: 32 up, a 16 unit box, the eye 8 above" {
    world = World();
    area = gib_room(world);
    collision = death_floor("q2");
    player = gibbable("q2", area);
    player.velocity = Vec3(x=100.0);
    player.grounded = True;
    player spawn Damage(amount=160, bypass_armor=True);
    before = player.pos.z - collision.eye_height;
    player spawn LieDead(collision=collision, profile=movement_profile("q2"), dt=TICK, world=world);
    # ThrowClientHead: origin 32 higher with mins 0 0 0 and maxs 16 16 16
    # (the box's foot 56 above where the body's was), viewheight 8, and
    # VelocityForDamage added to its speed: 60 past zero is the 1.2 scale.
    assert collision.top_drop == 40.0 and collision.eye_height == -16.0;
    foot = player.pos.z - collision.eye_height - 24.0;
    assert abs(foot - (before + 32.0)) < 6.0 and not player.grounded;
    assert player.velocity.z > 200.0 and player.velocity.z <= 360.0;
    assert player.velocity.x > 100.0 - 121.0 and player.velocity.x < 100.0 + 121.0;
    peak = 0.0;
    for tick in range(120 * 4) {
        player spawn LieDead(collision=collision, profile=movement_profile("q2"), dt=TICK, world=world);
        peak = max(peak, player.pos.z);
    }
    # It lands on the floor and the ground's friction stops it; the eye is 8
    # above the head's origin, which rests on the floor.
    assert peak > 80.0 and player.grounded;
    assert Vec3(x=player.velocity.x, y=player.velocity.y).length() == 0.0;
    assert abs(player.pos.z - 8.0) < 0.3;
}

test "Q2 and Q3 bodies are still shot, and burst when that takes them past the gib health" {
    for game in ["q1", "q2", "q3"] {
        world = World();
        area = gib_room(world);
        collision = death_floor(game);
        state = CombatState(game=game);
        player = gibbable(game, area);
        player spawn Damage(amount=120, bypass_armor=True);
        voice = player spawn VoiceTick(game=game, dt=TICK);
        player spawn LieDead(collision=collision, profile=movement_profile(game), dt=TICK, world=world);
        fallen = mortality_of(player);
        assert fallen.dead and not fallen.gibbed and player.death_overkill == 20;
        # Q1 PlayerDie makes the body SOLID_NOT; Q2 player_die leaves it
        # DAMAGE_YES and Q3 "can still be gibbed".
        assert body_struck(player) == (game != "q1");
        # A nail in flight: through the Q1 body, into the others.
        nail = Projectile(
            pos=player.pos.add(Vec3(x=-60.0)), velocity=Vec3(x=600.0), damage=9, hostile=True
        );
        world +>:HasProjectile:+> nail;
        for tick in range(30) {
            world spawn ProjectileTick(player=player, collision=collision, state=state, dt=TICK);
        }
        assert player.health == 0 and player.death_overkill == (20 if game == "q1" else 29);
        # A monster's line of fire stops at a body shots still strike.
        shooter = Opponent(pos=player.pos.add(Vec3(x=-200.0)), game=game);
        aim = line_of_fire(
            world, shooter, player, shooter.pos, player.pos.add(Vec3(x=200.0)), collision, 1.0
        );
        assert (aim.actor is player) == (game != "q1");
        # A weak blast on it.
        blast_actors(world, player.pos.add(Vec3()), 8, 120.0, True, player, collision, state);
        soaked = player.death_overkill;
        assert (soaked > 29) == (game != "q1") and soaked < 40;
        step = player spawn LieDead(collision=collision, profile=movement_profile(game), dt=TICK, world=world);
        assert not step.burst and not fallen.gibbed;
        if game == "q1" {
            assert soaked == 20;
            continue;
        }
        # Past the gib health the body bursts then, with the gib sound.
        player spawn VoiceTick(game=game, dt=TICK);
        player spawn Damage(amount=30);
        step = player spawn LieDead(collision=collision, profile=movement_profile(game), dt=TICK, world=world);
        assert step.burst and not step.died and fallen.gibbed and step.thrown > 0;
        loud = player spawn VoiceTick(game=game, dt=TICK);
        sound = "sound/misc/udeath.wav" if game == "q2" else "sound/player/gibsplt1.wav";
        assert sound not in voice.cues and sound in loud.cues;
        assert sound not in (player spawn VoiceTick(game=game, dt=TICK)).cues;
        # Burst, it is struck no more.
        left = player.death_overkill;
        player spawn Damage(amount=50);
        assert player.death_overkill == left and not body_struck(player);
    }
}

test "a Q3 player killed in a nodrop void falls on whole, until a later hit bursts it" {
    world = World();
    area = gib_room(world);
    # CONTENTS_NODROP below z = -500, as the void around q3dm17.
    void = NoDropSpace();
    void.volume.add_box(
        Vec3(x=-5000.0, y=-5000.0, z=-9000.0), Vec3(x=5000.0, y=5000.0, z=-500.0), Vec3(), Vec3(), Vec3()
    );
    void.volume.reindex();
    world +>:HasNoDrop:+> void;
    collision = death_floor("q3");
    # The player's own rig, as the death view shows it.
    rows: list[list[float]] = [];
    for i in range(25) {
        rows.append([float(i * 12), 11.0, 11.0, 21.0]);
    }
    part = ModelResource(name="sarge", model=AnimatedModel(), skins=[]);
    rig = dress_rig(rig_clips(rows), part, part, part);
    world +>:HasBody:+> player_body(rig);
    player = gibbable("q3", area);
    player.pos = Vec3(z=-700.0);
    player.grounded = True;
    follow_body(world, player, 26.0, "", 0.0);
    assert in_no_drop(world, player.pos.sub(Vec3(z=26.0)));
    # The void's trigger_hurt: far past GIB_HEALTH.
    player spawn Damage(amount=1000, bypass_armor=True, bypass_protection=True);
    assert player.health == 0 and player.death_overkill == 900;
    # Until the body has taken its death nothing is decided: no gib sound,
    # and the rig is not yet dying.
    early = player spawn VoiceTick(game="q3", dt=TICK);
    show_body(world, player, 26.0, "", 0.01, True);
    assert not q3_gibbed(player) and rig.alive and rig.visible;
    assert "sound/player/gibsplt1.wav" not in early.cues;
    step = player spawn LieDead(
        collision=collision, profile=movement_profile("q3"), dt=TICK, world=world
    );
    fallen = mortality_of(player);
    # player_die: "never gib in a nodrop". The body dies whole, with its cry.
    assert step.died and not step.burst and step.thrown == 0;
    assert fallen.dead and not fallen.gibbed and fallen.spared == 900;
    assert not [world->:HasGib:->][?:Gib] and not q3_gibbed(player);
    voice = player spawn VoiceTick(game="q3", dt=TICK);
    assert "sound/player/gibsplt1.wav" not in voice.cues;
    show_body(world, player, collision.eye_height, "", 0.02, True);
    assert rig.visible and not rig.alive;
    cues = follow_body(world, player, collision.eye_height, "", 0.03);
    assert [cue for cue in cues if "death" in cue];
    # It falls on as it is.
    for tick in range(60) {
        player spawn LieDead(collision=collision, profile=movement_profile("q3"), dt=TICK, world=world);
    }
    assert not fallen.gibbed and player.velocity.z < -300.0 and body_struck(player);
    # body_die: any later hit finds it at GIB_HEALTH and bursts it.
    player spawn Damage(amount=1);
    late = player spawn LieDead(
        collision=collision, profile=movement_profile("q3"), dt=TICK, world=world
    );
    assert late.burst and late.thrown == 11 and fallen.gibbed and q3_gibbed(player);
    sound = player spawn VoiceTick(game="q3", dt=TICK);
    assert "sound/player/gibsplt1.wav" in sound.cues;
    show_body(world, player, collision.eye_height, "", 0.6, True);
    assert not rig.visible;
    # Out of the void the same blow gibs at once.
    above = gibbable("q3", area);
    above spawn Damage(amount=1000, bypass_armor=True, bypass_protection=True);
    direct = above spawn LieDead(
        collision=death_floor("q3"), profile=movement_profile("q3"), dt=TICK, world=world
    );
    assert direct.died and direct.burst and mortality_of(above).spared == -1;
    # Q1 and Q2 know no such void.
    for game in ["q1", "q2"] {
        other = gibbable(game, area);
        other.pos = Vec3(z=-700.0);
        other spawn Damage(amount=1000, bypass_armor=True, bypass_protection=True);
        gone = other spawn LieDead(
            collision=death_floor(game), profile=movement_profile(game), dt=TICK, world=world
        );
        assert gone.burst and mortality_of(other).gibbed;
    }
}

"""A Q2 monster of `kind` standing on the death floor at `origin`, facing
the level's origin."""
def q2_monster(kind: str, origin: Vec3) -> Opponent {
    rule = enemy_rule("q2", kind);
    assert rule is not None;
    return Opponent(
        rule=rule,
        kind=kind,
        game="q2",
        health=rule.health,
        max_health=rule.health,
        pos=origin.add(Vec3(z=22.0)),
        yaw=math.atan2(-origin.y, -origin.x),
        attack_wait=1000.0
    );
}

test "a Q2 tank keeps after the player it killed, strikes over the body once and lets it go" {
    collision = death_floor("q2");
    state = CombatState(game="q2");
    world = World();
    tank = q2_monster("monster_tank", Vec3(x=300.0, z=24.0));
    soldier = Opponent(
        pos=Vec3(x=300.0, y=200.0, z=46.0),
        yaw=math.atan2(-200.0, -300.0),
        game="q2",
        attack_wait=1000.0
    );
    # tank_run sets AI_BRUTAL; no other monster of the game has it.
    assert tank.rule.brutal_health == -80 and soldier.rule.brutal_health == 0;
    for kind in ["monster_tank_commander", "monster_soldier", "monster_gladiator", "monster_supertank"] {
        other = enemy_rule("q2", kind);
        assert other is not None;
        assert other.brutal_health == (-80 if kind == "monster_tank_commander" else 0);
    }
    world +>:HasOpponent:+> tank;
    world +>:HasOpponent:+> soldier;
    player = mortal("q2");
    for tick in range(20) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    }
    assert tank.alert > 0.0 and soldier.alert > 0.0;
    # Dead at -10 health: ai_checkattack gives a brutal monster's enemy up
    # only at -80, and only a player is its prey (tank_run: enemy->client).
    player spawn Damage(amount=player.health + 10, bypass_armor=True);
    lie(player, collision, "q2", TICK);
    assert player.death_overkill == 10;
    assert brutal_toward(tank, player) and not brutal_toward(soldier, player);
    assert not brutal_toward(tank, soldier);
    for tick in range(20) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    }
    assert tank.alert > 0.0 and tank.pursuing;
    assert soldier.alert == 0.0 and not soldier.pursuing;
    # tank_attack: over an enemy below zero health, tank_move_attack_strike
    # and none of its weapons.
    tank.attack_wait = 0.0;
    started = False;
    for tick in range(3000) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
        if tank.attack_clock >= 0.0 {
            started = True;
            break;
        }
    }
    assert started and current_profile(tank).name == "strike";
    assert not [world->:HasProjectile:->][?:Projectile] and player.death_overkill == 10;
    # TankStrike is a sound and no more; tank_poststrike lets the enemy go.
    for tick in range(600) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    }
    assert tank.attack_clock < 0.0 and tank.alert == 0.0 and not tank.pursuing;
    assert not brutal_toward(tank, player) and player.death_overkill == 10;
    for tick in range(300) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    }
    assert tank.attack_clock < 0.0 and tank.alert == 0.0 and tank.pose_name == "stand";
    # A body at -80 or lower it lets go at once.
    over = World();
    second = q2_monster("monster_tank", Vec3(x=300.0, z=24.0));
    over +>:HasOpponent:+> second;
    gone = mortal("q2");
    for tick in range(20) {
        over spawn CombatTick(player=gone, collision=collision, state=state, dt=0.01);
    }
    assert second.alert > 0.0;
    gone spawn Damage(amount=gone.health + 80, bypass_armor=True);
    assert gone.death_overkill == 80 and not brutal_toward(second, gone);
    over spawn CombatTick(player=gone, collision=collision, state=state, dt=0.01);
    assert second.alert == 0.0 and not second.pursuing;
    # One dead at exactly zero it fires on at with its weapons.
    even = World();
    third = q2_monster("monster_tank", Vec3(x=300.0, z=24.0));
    even +>:HasOpponent:+> third;
    level = mortal("q2");
    for tick in range(20) {
        even spawn CombatTick(player=level, collision=collision, state=state, dt=0.01);
    }
    level spawn Damage(amount=level.health, bypass_armor=True);
    lie(level, collision, "q2", TICK);
    assert level.health == 0 and level.death_overkill == 0 and brutal_toward(third, level);
    third.attack_wait = 0.0;
    fired = False;
    for tick in range(3000) {
        even spawn CombatTick(player=level, collision=collision, state=state, dt=0.01);
        if third.attack_clock >= 0.0 {
            fired = True;
            break;
        }
    }
    assert fired and current_profile(third).trigger == "";
    # It takes no dead player for a new enemy (FindTarget).
    late = World();
    fourth = q2_monster("monster_tank", Vec3(x=300.0, z=24.0));
    fourth.attack_wait = 0.0;
    late +>:HasOpponent:+> fourth;
    for tick in range(100) {
        late spawn CombatTick(player=player, collision=collision, state=state, dt=0.01);
    }
    assert fourth.alert == 0.0 and not fourth.pursuing and fourth.attack_clock < 0.0;
}
