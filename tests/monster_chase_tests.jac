"""Campaign monsters chasing through the real combat tick: steps blocked by
other bodies, stopping a step short of the enemy, Q2's pursuit of an enemy
out of sight, and the chase state in saves."""
import math;
import from games.enemies { enemy_rule }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat {
    CombatState,
    CombatTick,
    Opponent,
    HasOpponent,
    StepField,
    attack_charge,
    begin_attack,
    damage_opponent,
    ensure_profiles,
    pain_length,
    pain_stagger
}
import from engine.world.opponent_rule { OpponentRule }
import from engine.world.monster_move { sweep_entry }
import from engine.math.aabb { AABB }
import from engine.world.trail { TrailTick }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

"""A floor at z 0, as a point body stands on it (origin at its feet)."""
def chase_floor() -> CollisionMap {
    collision = CollisionMap();
    collision.add_box(
        Vec3(x=-4000.0, y=-4000.0, z=-64.0), Vec3(x=4000.0, y=4000.0, z=0.0), Vec3(), Vec3(), Vec3()
    );
    return collision;
}

def chaser(game: str, kind: str, pos: Vec3) -> Opponent {
    rule = enemy_rule(game, kind, 0);
    assert rule is not None;
    return Opponent(
        rule=rule,
        kind=kind,
        game=game,
        pos=pos,
        health=rule.health,
        max_health=rule.health,
        grounded=True,
        attack_wait=1000.0,
        animation=list(range(len(rule.run.frames)))
    );
}

def chase(world: World, player: Player, collision: CollisionMap, state: CombatState, seconds: float) {
    for tick in range(int(seconds * 120.0)) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
    }
}

test "monsters block each other in a corridor and a corpse does not" {
    collision = chase_floor();
    # Walls 40 units apart: too narrow to pass a 32 unit body in.
    collision.add_box(Vec3(x=-200.0, y=20.0, z=0.0), Vec3(x=2000.0, y=30.0, z=200.0), Vec3(), Vec3(), Vec3());
    collision.add_box(Vec3(x=-200.0, y=-30.0, z=0.0), Vec3(x=2000.0, y=-20.0, z=200.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    world = World();
    state = CombatState(game="q1");
    player = Player(pos=Vec3(x=600.0, z=22.0), health=100000, god_mode=True);
    grunt = chaser("q1", "monster_army", Vec3(z=22.0));
    grunt.alert = 8.0;
    grunt.last_seen = player.pos;
    # A guard standing in the way, 60 units ahead.
    guard = Opponent(
        rule=OpponentRule(movement="none"), game="q1", pos=Vec3(x=60.0, z=22.0), health=100,
        grounded=True, attack_wait=1000.0
    );
    world +>:HasOpponent:+> grunt;
    world +>:HasOpponent:+> guard;
    furthest = 0.0;
    for tick in range(600) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
        furthest = max(furthest, grunt.pos.x);
    }
    # Their boxes are 16 units either side: the grunt never comes nearer
    # than 32, and it did close up to the guard.
    assert furthest <= 28.0 and furthest >= 13.0 , str(furthest);
    assert abs(grunt.pos.y) <= 20.001 and guard.pos.x == 60.0;
    # Dead, the guard is a corpse (SOLID_NOT) and the grunt runs through.
    guard.health = 0;
    chase(world, player, collision, state, 3.0);
    assert grunt.pos.x > 150.0 , str(grunt.pos.x);
}

test "a monster runs at the player and stops where its next step would reach them" {
    collision = chase_floor();
    collision.reindex();
    world = World();
    state = CombatState(game="q1");
    player = Player(pos=Vec3(x=300.0, z=22.0), health=100000, god_mode=True);
    knight = chaser("q1", "monster_knight", Vec3(z=22.0));
    knight.alert = 8.0;
    knight.last_seen = player.pos;
    world +>:HasOpponent:+> knight;
    for tick in range(720) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
        # Never inside the player's box (SV_movestep's trace).
        assert knight.pos.x <= 268.0 , str(tick);
    }
    # knight_run1-8 step 16 20 13 7 16 20 14 6: within the longest of them,
    # and SV_CloseEnough's two units, of the player's box.
    assert knight.pos.x >= 268.0 - 22.0 , str(knight.pos.x);
    assert knight.pose_name == "run" and abs(knight.pos.y) < 0.001;
    # Running in place, it is not being carried anywhere.
    assert knight.stride_time == 0.0 or knight.standing().x == knight.pos.x;
}

test "a Q2 monster that loses its enemy makes for where it saw them, then along their trail" {
    collision = chase_floor();
    # A wall hides everything beyond x 300 from the guard's side.
    collision.add_box(Vec3(x=300.0, y=-4000.0, z=0.0), Vec3(x=310.0, y=-100.0, z=400.0), Vec3(), Vec3(), Vec3());
    collision.add_box(Vec3(x=300.0, y=100.0, z=0.0), Vec3(x=310.0, y=4000.0, z=400.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    world = World();
    state = CombatState(game="q2");
    player = Player(pos=Vec3(x=200.0, z=22.0), health=100000, god_mode=True);
    guard = chaser("q2", "monster_soldier", Vec3(z=22.0));
    guard.skill = 1;
    world +>:HasOpponent:+> guard;
    # Seen at x 200, the player then goes through the gap and round the
    # corner, out of sight, leaving crumbs.
    chase(world, player, collision, state, 0.3);
    assert guard.alert > 0.0 and guard.sighted and guard.pursuing and not guard.lost_sight;
    for spot in [Vec3(x=350.0, z=22.0), Vec3(x=400.0, y=300.0, z=22.0), Vec3(x=400.0, y=600.0, z=22.0)] {
        player.pos = spot;
        world spawn TrailTick(player=player, dt=0.6, collision=collision);
    }
    chase(world, player, collision, state, 0.5);
    assert not guard.pursuing and guard.lost_sight and guard.alert > 0.0;
    # It keeps its enemy for as long as it takes (ai_run never gives up),
    # going through the gap and up the trail.
    east = 0.0;
    north = 0.0;
    for tick in range(12 * 120) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
        east = max(east, guard.pos.x);
        north = max(north, guard.pos.y);
    }
    assert guard.alert > 0.0 and guard.pose_name == "run";
    assert east > 340.0 and north > 250.0 , str(east) + " " + str(north);
}

test "a Q2 monster with only a noise to go on stands its ground when it gets there" {
    collision = chase_floor();
    collision.reindex();
    world = World();
    state = CombatState(game="q2");
    # The player is out of reach of sight; the monster only heard something.
    player = Player(pos=Vec3(x=3000.0, z=22.0), health=100000, god_mode=True);
    guard = chaser("q2", "monster_soldier", Vec3(z=22.0));
    guard.alert = 6.0;
    guard.last_seen = Vec3(x=200.0, z=22.0);
    world +>:HasOpponent:+> guard;
    chase(world, player, collision, state, 4.0);
    # AI_SOUND_TARGET: within 64 units of the noise it stops and stands.
    gap = guard.pos.sub(Vec3(x=200.0, z=guard.pos.z)).length();
    assert gap < 64.0 and gap > 30.0 , str(gap);
    assert guard.pose_name == "stand" and not guard.sighted;
    chase(world, player, collision, state, 3.0);
    assert guard.alert == 0.0;
}

test "the chase survives a save" {
    world = World();
    level = Level();
    level.name = "test";
    player = Player();
    guard = chaser("q2", "monster_soldier", Vec3(x=10.0, z=22.0));
    world +>:HasOpponent:+> guard;
    idle = chaser("q1", "monster_army", Vec3(x=500.0, z=22.0));
    world +>:HasOpponent:+> idle;
    # Part-way through a step that ends 12 units on and 20 degrees round.
    start = guard.pos;
    guard.pos = Vec3(x=22.0, y=3.0, z=22.0);
    guard.turn_to = 20.0;
    guard.stride(start, 0.075);
    guard.advance(1.0 / 120.0);
    guard.ideal_yaw = 215.0;
    guard.step_random = 123456;
    guard.partial_ground = True;
    guard.sliding = True;
    guard.lefty = True;
    guard.lost_sight = True;
    guard.pursue_temp = True;
    guard.searching = True;
    guard.search_left = 17.5;
    guard.saved_goal = Vec3(x=1.0, y=2.0, z=3.0);
    left = guard.stride_time;
    drawn = guard.pos.x;
    data = snapshot(world, level, player, CombatState());
    fresh = World();
    loaded = chaser("q2", "monster_soldier", Vec3(z=22.0));
    fresh +>:HasOpponent:+> loaded;
    other = chaser("q1", "monster_army", Vec3(z=22.0));
    fresh +>:HasOpponent:+> other;
    restore(fresh, level, Player(), CombatState(), data);
    assert loaded.ideal_yaw == 215.0 and loaded.step_random == 123456;
    assert loaded.partial_ground and loaded.sliding and loaded.lefty;
    assert loaded.lost_sight and loaded.pursue_temp and loaded.searching;
    assert not loaded.pursue_next and not loaded.pursuit_last_seen;
    assert loaded.search_left == 17.5 and loaded.saved_goal.y == 2.0;
    # The step goes on from where the body was drawn and ends where it did.
    assert abs(loaded.pos.x - drawn) < 0.0001 and abs(loaded.stride_time - left) < 0.0001;
    assert abs(loaded.standing().x - 22.0) < 0.0001 and loaded.facing() == 20.0;
    for tick in range(12) {
        loaded.advance(1.0 / 120.0);
    }
    assert abs(loaded.pos.x - 22.0) < 0.0001 and abs(loaded.pos.y - 3.0) < 0.0001;
    assert abs(math.degrees(loaded.yaw) - 20.0) < 0.0001;
    # A monster that has never stepped writes nothing and loads untouched.
    assert other.step_random == 0 and other.stride_time == 0.0 and "STEP 1" not in data;
}

"""Begin the attack sequence `name` at `target`."""
def charge_with(enemy: Opponent, name: str, target: Vec3) {
    ensure_profiles(enemy);
    for i in range(len(enemy.profiles)) {
        if enemy.profiles[i].name == name {
            begin_attack(enemy, i, target);
            return;
        }
    }
    raise ValueError("No attack sequence " + name);
}

"""Play the attack a monster is in for `seconds`, in 20 Hz slices, carrying
each frame's step as the combat tick does."""
def charge_on(
    enemy: Opponent, player: Player, collision: CollisionMap, seconds: float, field: StepField | None = None
) {
    for slice in range(int(seconds * 20.0 + 0.5)) {
        attack_charge(enemy, player, collision, 0.05, field);
        enemy.advance(0.05);
        enemy.attack_clock += 0.05;
    }
}

test "a pain frame's step is a walkmove: whole, or not at all with a body in its way" {
    collision = chase_floor();
    collision.reindex();
    # mutant_move_pain2 throws it 24 back in its first frame.
    for scenario in ["clear", "guarded", "corpse"] {
        mutant = chaser("q2", "monster_mutant", Vec3(z=22.0));
        mutant.pain_variant = 2;
        mutant.pain_wait = pain_length(mutant);
        guard = chaser("q2", "monster_soldier", Vec3(x=-(mutant.rule.width + 16.0 + 10.0), z=22.0));
        if scenario == "corpse" {
            guard.health = 0;
        }
        field = StepField();
        if scenario != "clear" {
            field.file(guard);
        }
        pain_stagger(mutant, collision, 0.05, None, field);
        # A living soldier 10 units behind its box stops the step; nothing,
        # or a corpse, does not.
        assert mutant.standing().x == (0.0 if scenario == "guarded" else -24.0) , scenario;
        assert mutant.pos.x == 0.0;
    }
}

test "Q2 ai_charge walks along the monster's own facing, Q1's goes at the enemy" {
    collision = chase_floor();
    collision.reindex();
    player = Player(pos=Vec3(x=1500.0, z=22.0), health=100000, god_mode=True);
    # soldier_move_attack6: fourteen ai_charge distances, 168 by MODEL_SCALE
    # 1.2. Facing north with its enemy due east, it runs north
    # (M_walkmove(self, self->s.angles[YAW], dist)).
    soldier = chaser("q2", "monster_soldier_light", Vec3(z=22.0));
    soldier.yaw = math.pi / 2.0;
    soldier.attack_wait = 0.0;
    charge_with(soldier, "attack6", player.pos);
    charge_on(soldier, player, collision, 1.4);
    assert abs(soldier.pos.y - 168.0 * 1.2) < 0.01 and abs(soldier.pos.x) < 0.01;
    # hknight_char_a: ai_charge is ai_face and movetogoal. Facing its enemy
    # the hell knight runs at it, and takes no step that would reach its box
    # (SV_CloseEnough): it ends within its longest step of 25, and two
    # units, of the player's box, and never inside it.
    near = Player(pos=Vec3(x=300.0, z=22.0), health=100000, god_mode=True);
    knight = chaser("q1", "monster_hell_knight", Vec3(z=22.0));
    knight.attack_wait = 0.0;
    charge_with(knight, "charge", near.pos);
    furthest = 0.0;
    for slice in range(32) {
        attack_charge(knight, near, collision, 0.05);
        knight.advance(0.05);
        knight.attack_clock += 0.05;
        furthest = max(furthest, knight.pos.x);
    }
    assert furthest <= 268.0 and furthest >= 268.0 - 27.0 , str(furthest);
    assert abs(knight.pos.y) < 0.01 and knight.ideal_yaw == 0.0;
    # Facing square away from its enemy it turns before it steps: nothing
    # for two frames (SV_StepDirection), though the frames step 20 and 25.
    turned = chaser("q1", "monster_hell_knight", Vec3(z=22.0));
    turned.yaw = math.pi / 2.0;
    turned.attack_wait = 0.0;
    charge_with(turned, "charge", near.pos);
    charge_on(turned, near, collision, 0.2);
    assert turned.pos.x == 0.0 and turned.pos.y == 0.0;
    charge_on(turned, near, collision, 0.2);
    assert turned.pos.x > 15.0;
}

test "fliers take their attack frames' steps, backing off as they fire" {
    open_air = CollisionMap();
    player = Player(pos=Vec3(x=600.0, z=22.0), health=100000, god_mode=True);
    # flyer_frames_attack2: three frames, eight of -10 as it fires, six
    # more. Thirty-five units above its enemy's origin it keeps its height.
    flyer = chaser("q2", "monster_flyer", Vec3(z=22.0 + 35.0));
    flyer.grounded = False;
    flyer.alert = 8.0;
    flyer.attack_wait = 0.0;
    charge_with(flyer, "blasters", player.pos);
    charge_on(flyer, player, open_air, 0.3);
    assert flyer.pos.x == 0.0;
    charge_on(flyer, player, open_air, 1.4);
    assert abs(flyer.pos.x + 80.0) < 0.001 and abs(flyer.pos.z - 57.0) < 0.001;
    # Level with its enemy it also rises 8 units with each step
    # (SV_movestep's FL_FLY branch) until it is 30 above.
    low = chaser("q2", "monster_flyer", Vec3(z=22.0));
    low.grounded = False;
    low.alert = 8.0;
    low.attack_wait = 0.0;
    charge_with(low, "blasters", player.pos);
    charge_on(low, player, open_air, 1.7);
    assert abs(low.pos.x + 80.0) < 0.001 and abs(low.pos.z - (22.0 + 32.0)) < 0.001;
    # hover_frames_start_attack, attack1 and end_attack: 1 1 1 -10 -10 0 1 1.
    hover = chaser("q2", "monster_hover", Vec3(z=22.0 + 35.0));
    hover.grounded = False;
    hover.alert = 8.0;
    hover.attack_wait = 0.0;
    charge_with(hover, "blaster", player.pos);
    charge_on(hover, player, open_air, 0.3);
    assert abs(hover.pos.x - 3.0) < 0.001;
    charge_on(hover, player, open_air, 0.5);
    assert abs(hover.pos.x + 15.0) < 0.001;
    # The Hornet creeps forward 1 a frame and is thrown back 20 on the
    # frame its rockets leave (boss2_frames_attack_rocket's ai_move).
    hornet = chaser("q2", "monster_boss2", Vec3(z=22.0 + 35.0));
    hornet.grounded = False;
    hornet.alert = 8.0;
    hornet.attack_wait = 0.0;
    charge_with(hornet, "rockets", player.pos);
    charge_on(hornet, player, open_air, 1.15);
    assert abs(hornet.standing().x - 12.0) < 0.001;
    charge_on(hornet, player, open_air, 0.1);
    assert abs(hornet.standing().x + 8.0) < 0.001;
    charge_on(hornet, player, open_air, 0.8);
    assert abs(hornet.standing().x) < 0.001;
    # ai_move with no distance is an M_walkmove all the same: a flier in
    # pain, level with its enemy, goes on rising 8 a frame toward its
    # height over them and does not otherwise move.
    hurt = chaser("q2", "monster_flyer", Vec3(z=22.0));
    hurt.grounded = False;
    hurt.alert = 8.0;
    hurt.pain_variant = 1;
    hurt.pain_wait = pain_length(hurt);
    assert hurt.pain_wait >= 0.4;
    for part in range(8) {
        pain_stagger(hurt, open_air, 0.05, player);
        hurt.advance(0.05);
        hurt.pain_wait = max(0.0, hurt.pain_wait - 0.05);
    }
    assert abs(hurt.standing().z - 54.0) < 0.001 and hurt.standing().x == 0.0;
    # A walker in the air takes no step.
    falling = chaser("q2", "monster_soldier_light", Vec3(z=22.0));
    falling.grounded = False;
    falling.attack_wait = 0.0;
    charge_with(falling, "attack6", player.pos);
    charge_on(falling, player, open_air, 1.4);
    assert falling.pos.x == 0.0;
}

test "a monster in pain does not turn toward its enemy" {
    collision = chase_floor();
    collision.reindex();
    for game in ["q1", "q2"] {
        world = World();
        state = CombatState(game=game);
        # The player stands square behind it and shoots it in the back.
        player = Player(pos=Vec3(x=-300.0, z=22.0), health=100000, god_mode=True);
        victim = chaser(game, "monster_ogre" if game == "q1" else "monster_gunner", Vec3(z=22.0));
        victim.skill = 1;
        world +>:HasOpponent:+> victim;
        damage_opponent(victim, 20, attacker=player);
        assert victim.pain_wait > 0.2 and victim.alert > 0.0;
        ticks = 0;
        while victim.pain_wait > 1.0 / 120.0 {
            world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
            assert victim.yaw == 0.0 , game + " " + str(ticks);
            ticks += 1;
        }
        assert ticks > 20;
        # Out of pain it comes round on them.
        for tick in range(60) {
            world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
        }
        assert victim.yaw != 0.0;
    }
}

test "Q2's course correction is stopped by a body in the way as by a wall" {
    collision = chase_floor();
    collision.reindex();
    world = World();
    state = CombatState(game="q2");
    player = Player(pos=Vec3(x=3000.0, z=22.0), health=100000, god_mode=True);
    guard = chaser("q2", "monster_soldier", Vec3(z=22.0));
    guard.alert = 8.0;
    guard.sighted = True;
    guard.last_seen = Vec3(x=300.0, z=22.0);
    # Another soldier stands in the line to where the guard last saw its
    # enemy, a little to the right of it.
    other = chaser("q2", "monster_soldier", Vec3(x=150.0, y=-28.0, z=22.0));
    world +>:HasOpponent:+> guard;
    world +>:HasOpponent:+> other;
    tick = world spawn CombatTick(player=player, collision=collision, state=state, dt=0.0, active=False);
    target = player.pos.sub(Vec3(z=22.0));
    near = AABB(mins=target.sub(Vec3(x=16.0, y=16.0, z=24.0)), maxs=target.add(Vec3(x=16.0, y=16.0, z=32.0)));
    space = tick.field.space(guard, player, 10.0, collision.for_body(22.0));
    tick.pursue(guard, target, 10.0, space, near);
    # The box is stopped half-way down the line; 16 units to the left it
    # passes, so the guard makes for that side first (AI_PURSUE_TEMP) and
    # keeps the goal it put off.
    assert guard.lost_sight and guard.pursue_temp;
    assert guard.saved_goal.x == 300.0 and guard.saved_goal.y == 0.0;
    assert abs(guard.last_seen.y - 16.0) < 0.001 and guard.last_seen.x > 150.0 and guard.last_seen.x < 300.0;
    # A sweep that starts inside a body is not stopped by it; one that
    # meets it is, at the fraction where their boxes touch.
    box = AABB(mins=Vec3(x=84.0, y=-16.0, z=0.0), maxs=Vec3(x=116.0, y=16.0, z=56.0));
    mins = Vec3(x=-16.0, y=-16.0, z=-24.0);
    maxs = Vec3(x=16.0, y=16.0, z=32.0);
    assert abs(sweep_entry(Vec3(z=24.0), Vec3(x=200.0, z=24.0), mins, maxs, box) - 0.34) < 0.000001;
    assert sweep_entry(Vec3(x=90.0, z=24.0), Vec3(x=200.0, z=24.0), mins, maxs, box) == 1.0;
    assert sweep_entry(Vec3(z=24.0), Vec3(y=200.0, z=24.0), mins, maxs, box) == 1.0;
}

test "a knocked flier sheds its speed by SV_Physics_Step's friction" {
    world = World();
    state = CombatState(game="q2");
    player = Player(pos=Vec3(x=5000.0, z=22.0), health=100000, god_mode=True);
    flyer = chaser("q2", "monster_flyer", Vec3(z=222.0));
    flyer.grounded = False;
    flyer.velocity = Vec3(x=300.0, z=90.0);
    world +>:HasOpponent:+> flyer;
    dt = 1.0 / 120.0;
    world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=dt);
    # Level speed at sv_friction 6; rise at a third of it, on a control
    # speed never under sv_stopspeed 100.
    assert abs(flyer.velocity.x - (300.0 - dt * 300.0 * 6.0)) < 0.0001;
    assert abs(flyer.velocity.z - (90.0 - dt * 100.0 * 2.0)) < 0.0001;
    assert abs(flyer.pos.x - flyer.velocity.x * dt) < 0.0001;
    for tick in range(240) {
        world spawn CombatTick(player=player, collision=CollisionMap(), state=state, dt=dt);
    }
    assert flyer.velocity.length() == 0.0 and flyer.pos.x > 20.0;
}

test "a knocked or falling monster is stopped by other bodies" {
    collision = chase_floor();
    collision.reindex();
    state = CombatState(game="q2");
    player = Player(pos=Vec3(x=5000.0, z=22.0), health=100000, god_mode=True);
    # SV_FlyMove clips to entities: a soldier knocked at another 8 units
    # off stops against it, and at a corpse does not.
    for scenario in ["living", "corpse"] {
        world = World();
        knocked = chaser("q2", "monster_soldier", Vec3(z=22.0));
        other = chaser("q2", "monster_soldier", Vec3(x=40.0, z=22.0));
        if scenario == "corpse" {
            other.health = 0;
        }
        world +>:HasOpponent:+> knocked;
        world +>:HasOpponent:+> other;
        knocked.velocity = Vec3(x=300.0);
        for tick in range(60) {
            world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
        }
        if scenario == "living" {
            assert knocked.pos.x == 8.0 and knocked.velocity.x == 0.0;
        } else {
            assert knocked.pos.x > 12.0;
        }
        assert other.pos.x == 40.0;
    }
    # Knocked past it at an angle, it slides along the other's side.
    world = World();
    glancing = chaser("q2", "monster_soldier", Vec3(z=22.0));
    other = chaser("q2", "monster_soldier", Vec3(x=40.0, z=22.0));
    world +>:HasOpponent:+> glancing;
    world +>:HasOpponent:+> other;
    glancing.velocity = Vec3(x=300.0, y=-300.0);
    for tick in range(60) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
    }
    assert glancing.pos.x == 8.0 and glancing.pos.y < -20.0 and glancing.velocity.x == 0.0;
    # One that falls on another comes to rest on its head, off the ground,
    # and falls on to the floor when the one below is gone.
    world = World();
    under = chaser("q2", "monster_soldier", Vec3(z=22.0));
    faller = chaser("q2", "monster_soldier", Vec3(z=22.0 + 100.0));
    faller.grounded = False;
    world +>:HasOpponent:+> under;
    world +>:HasOpponent:+> faller;
    for tick in range(120) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
    }
    assert faller.pos.z == under.pos.z + 56.0 and not faller.grounded;
    assert faller.velocity.z == 0.0;
    under.pos = Vec3(x=400.0, z=22.0);
    for tick in range(120) {
        world spawn CombatTick(player=player, collision=collision, state=state, dt=1.0 / 120.0);
    }
    assert faller.grounded and abs(faller.pos.z - 22.0) < 0.1;
}
